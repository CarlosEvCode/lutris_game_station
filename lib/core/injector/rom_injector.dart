import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import '../../platforms/platform_registry.dart';
import 'package:path/path.dart' as p;
import '../metadata/screenscraper_service.dart';

class RomInjector {
  final Map<String, String?> lutrisPaths;
  final String platformKey;
  final String romFolder;
  final List<String>? customExtensions;
  final Function(String message, double? progress)? progressCallback;

  late final PlatformInfo platformInfo;
  late final String dbPath;
  late final String configDir;
  late final String runner;
  late final List<String> extensions;
  late final String platformName;
  late final bool disableRuntime;
  late final String? screenScraperId;

  RomInjector({
    required this.lutrisPaths,
    required this.platformKey,
    required this.romFolder,
    this.customExtensions,
    this.progressCallback,
  }) {
    final info = PlatformRegistry.getPlatform(platformKey);
    if (info == null) throw Exception("Platform not supported: $platformKey");
    platformInfo = info;

    dbPath = lutrisPaths['db_path']!;
    configDir = lutrisPaths['config_dir_main']!;
    runner = platformInfo.runner;
    extensions = customExtensions ?? platformInfo.extensions;
    platformName = platformInfo.platformName;
    disableRuntime = platformInfo.disableRuntime;
    screenScraperId = platformInfo.screenScraperId;
  }

  void _log(String message, [double? progress]) {
    if (progressCallback != null) {
      progressCallback!(message, progress);
    } else {
      print(message);
    }
  }

  /// Filtra archivos duplicados manteniendo solo el de mayor prioridad.
  /// Por ejemplo, si hay game.bin y game.cue, solo mantiene game.bin
  List<File> _filterDuplicatesByPriority(List<File> files) {
    return filterDuplicatesByPriority(files, platformInfo, _log);
  }

  /// Versión estática para usar desde otros lugares (como main_window)
  /// [logCallback] es opcional para logging
  static List<File> filterDuplicatesByPriority(
    List<File> files,
    PlatformInfo platformInfo, [
    void Function(String message, [double? progress])? logCallback,
  ]) {
    // Agrupar archivos por nombre base (sin extensión)
    final Map<String, List<File>> groupedByName = {};

    for (final file in files) {
      final baseName = p.basenameWithoutExtension(file.path);
      groupedByName.putIfAbsent(baseName, () => []).add(file);
    }

    final List<File> result = [];

    for (final entry in groupedByName.entries) {
      final filesWithSameName = entry.value;

      if (filesWithSameName.length == 1) {
        // Solo hay un archivo con este nombre, lo agregamos directamente
        result.add(filesWithSameName.first);
      } else {
        // Hay múltiples archivos con el mismo nombre, elegimos el de mayor prioridad
        filesWithSameName.sort((a, b) {
          final extA = p.extension(a.path).toLowerCase();
          final extB = p.extension(b.path).toLowerCase();
          final priorityA = platformInfo.getExtensionPriority(extA);
          final priorityB = platformInfo.getExtensionPriority(extB);
          return priorityA.compareTo(priorityB);
        });

        final selected = filesWithSameName.first;
        final skipped = filesWithSameName
            .skip(1)
            .map((f) => p.extension(f.path))
            .join(', ');
        logCallback?.call(
          "📁 ${entry.key}: usando ${p.extension(selected.path)} (ignorando: $skipped)",
        );
        result.add(selected);
      }
    }

    return result;
  }

  String _createLutrisYaml(
    String gameSlug,
    String romPath,
    int timestamp, {
    Map<String, dynamic>? specialConfig,
  }) {
    final baseName = "$gameSlug-$timestamp";
    final filenameReal = "$baseName.yml";
    final fullYamlPath = p.join(configDir, filenameReal);

    String yamlContent;

    if (runner == "mame" &&
        specialConfig != null &&
        specialConfig['working_dir'] != null) {
      final romDir = p.dirname(romPath);
      yamlContent =
          '''
game:
  main_file: "$romPath"
  working_dir: "$romDir"
system:
  disable_runtime: ${disableRuntime.toString().toLowerCase()}
  prefer_system_libs: true
''';
    } else {
      final disableRuntimeStr = disableRuntime ? "true" : "false";
      yamlContent =
          '''
game:
  main_file: $romPath
system:
  disable_runtime: $disableRuntimeStr
  prefer_system_libs: true
''';
    }

    final dir = Directory(configDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    File(fullYamlPath).writeAsStringSync(yamlContent.trim());
    return baseName;
  }

  void _cleanOldGames() {
    _log("🧹 Limpiando juegos antiguos de $runner...");

    final db = sqlite3.open(dbPath);
    try {
      final results = db.select(
        "SELECT configpath FROM games WHERE runner = ?",
        [runner],
      );
      for (final row in results) {
        final String? configId = row['configpath'] as String?;
        if (configId != null && configId.isNotEmpty) {
          final yamlPath = p.join(configDir, "$configId.yml");
          final file = File(yamlPath);
          if (file.existsSync()) {
            try {
              file.deleteSync();
            } catch (e) {
              _log("⚠️ No se pudo borrar $yamlPath: $e");
            }
          }
        }
      }
      db.execute("DELETE FROM games WHERE runner = ?", [runner]);
    } finally {
      db.dispose();
    }
  }

  Future<void> injectRoms({
    bool cleanOld = true,
    Map<String, dynamic>? specialConfig,
    bool useHighPrecision = false,
    List<File>? customFiles,
    Map<String, String>? customNames,
  }) async {
    final folder = Directory(romFolder);
    if (!folder.existsSync()) {
      _log("❌ No existe la carpeta: $romFolder");
      return;
    }

    if (cleanOld) {
      _cleanOldGames();
    }

    final db = sqlite3.open(dbPath);
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int count = 0;
    List<String> errors = [];

    // Usar archivos específicos o escanear carpeta
    List<File> romFiles;
    if (customFiles != null) {
      romFiles = _filterDuplicatesByPriority(customFiles);
    } else {
      final files = folder.listSync().whereType<File>().toList();
      final matchingFiles = files.where((f) {
        final ext = p.extension(f.path).toLowerCase();
        return extensions.contains(ext);
      }).toList();
      // Filtrar duplicados por prioridad de extensión
      romFiles = _filterDuplicatesByPriority(matchingFiles);
    }

    final totalFiles = romFiles.length;
    if (totalFiles == 0) {
      _log("⚠️ No se encontraron archivos con las extensiones seleccionadas.");
      db.dispose();
      return;
    }

    // Set para evitar duplicados en la misma sesión (ej: Game.chd y Game.pbp)
    Set<String> processedSlugs = {};

    // Obtener juegos existentes en DB para evitar duplicados si cleanOld es false
    Set<String> existingSlugs = {};
    if (!cleanOld) {
      final rows = db.select("SELECT slug FROM games WHERE runner = ?", [
        runner,
      ]);
      for (final row in rows) {
        existingSlugs.add(row['slug'] as String);
      }
    }

    _log("🚀 Inyectando juegos desde: $romFolder");

    for (int i = 0; i < romFiles.length; i++) {
      final f = romFiles[i];
      String gameSlug = p.basenameWithoutExtension(f.path);
      String gameName = customNames?[f.path] ?? gameSlug;
      final fullRomPath = f.path;

      // --- ALTA PRECISIÓN (HASH) ---
      // Solo buscamos si el usuario no ha editado el nombre manualmente
      if (useHighPrecision &&
          (customNames == null || !customNames.containsKey(fullRomPath))) {
        _log("🔍 Calculando hash: $gameSlug...");
        try {
          final identified = await ScreenScraperService.identifyFile(
            fullRomPath,
            systemId: screenScraperId,
          );
          if (identified != null && identified.name != null) {
            gameName = identified.name!;
            _log("✨ Identificado: $gameName");
          } else {
            _log("⚠️ No identificado, usando nombre de archivo.");
          }
        } catch (e) {
          _log("⚠️ Error de identificación: $e");
        }
      }

      // 1. Evitar duplicados de formato en la misma carpeta
      if (processedSlugs.contains(gameSlug)) {
        _log(
          "⏩ Saltando formato duplicado: $gameSlug (${p.extension(f.path)})",
        );
        continue;
      }
      processedSlugs.add(gameSlug);

      // 2. Evitar duplicados con juegos ya inyectados en Lutris (si no se limpió antes)
      if (!cleanOld && existingSlugs.contains(gameSlug)) {
        _log("⏩ Juego ya existe en Lutris: $gameSlug");
        continue;
      }

      final uniqueTime = currentTime + count;
      final configId = _createLutrisYaml(
        gameSlug,
        fullRomPath,
        uniqueTime,
        specialConfig: specialConfig,
      );

      try {
        db.execute(
          '''
          INSERT INTO games (
              name, slug, runner, executable, directory, configpath, 
              installed, installed_at, platform, lastplayed,
              has_custom_banner, has_custom_icon, has_custom_coverart_big, playtime
          )
          VALUES (?, ?, ?, NULL, NULL, ?, 1, ?, ?, 0, 0, 0, 0, 0)
        ''',
          [gameName, gameSlug, runner, configId, uniqueTime, platformName],
        );

        count++;
        final progress = (i + 1) / totalFiles;
        _log("✅ Agregado: $gameName", progress);
      } catch (e) {
        final errorMsg = "⚠️ Error con $gameName: $e";
        errors.add(errorMsg);
        _log(errorMsg);
      }
    }

    db.dispose();

    _log("🎉 ¡Inyección completa! $count juegos nuevos agregados.", 1.0);

    if (errors.isNotEmpty) {
      _log("Se encontraron ${errors.length} errores.");
    }
  }
}
