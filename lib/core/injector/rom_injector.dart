import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import '../../platforms/platform_registry.dart';
import 'package:path/path.dart' as p;
import '../metadata/screenscraper_service.dart';
import '../lutris/rom_cache_repository.dart';
import '../metadata/hash_service.dart';

class RomInjector {
  final Map<String, String?> lutrisPaths;
  final String platformKey;
  final String? emulatorId; // ID del emulador seleccionado
  final String romFolder;
  final List<String>? customExtensions;
  final Function(String message, double? progress)? progressCallback;

  late final PlatformInfo platformInfo;
  late final EmulatorInfo emulatorInfo;
  late final String dbPath;
  late final String configDir;
  late final String runner;
  late final List<String> extensions;
  late final String platformName;
  late final bool disableRuntime;
  late final String? screenScraperId;
  late final RomCacheRepository _romCache;

  RomInjector({
    required this.lutrisPaths,
    required this.platformKey,
    this.emulatorId,
    required this.romFolder,
    this.customExtensions,
    this.progressCallback,
  }) {
    final info = PlatformRegistry.getPlatform(platformKey);
    if (info == null) throw Exception("Platform not supported: $platformKey");
    platformInfo = info;

    // Seleccionar el emulador (por defecto el primero si no se especifica)
    if (emulatorId != null) {
      emulatorInfo = platformInfo.emulators.firstWhere(
        (e) => e.id == emulatorId,
        orElse: () => platformInfo.emulators.first,
      );
    } else {
      emulatorInfo = platformInfo.emulators.first;
    }

    dbPath = lutrisPaths['db_path']!;
    configDir = lutrisPaths['config_dir_main']!;
    runner = emulatorInfo.runner;
    extensions = customExtensions ?? emulatorInfo.extensions;
    platformName = platformInfo.platformName;
    disableRuntime = emulatorInfo.disableRuntime;
    screenScraperId = platformInfo.screenScraperId;
    _romCache = RomCacheRepository();
  }

  void _log(String message, [double? progress]) {
    if (progressCallback != null) {
      progressCallback!(message, progress);
    } else {
      print(message);
    }
  }

  /// Valida si un archivo necesita procesamiento de hash
  /// Retorna true si necesita hash, false si puede reutilizar cache
  bool _shouldCalculateHash(
    String filePath, {
    bool reuseIdentification = true,
  }) {
    if (!reuseIdentification) return true;

    // Early exit por extensión - verificar que sea válida antes de hacer hash
    final ext = p.extension(filePath).toLowerCase();
    if (!extensions.contains(ext)) {
      _log("⏩ Extensión no válida para $platformName: $ext");
      return false;
    }

    final cached = _romCache.shouldProcessRom(filePath);
    if (cached != null && cached.isIdentified) {
      _log(
        "📦 Usando identificación previa: ${cached.identifiedName ?? p.basenameWithoutExtension(filePath)}",
      );
      return false;
    }

    return true;
  }

  /// Obtiene el nombre identificado desde cache o calcula uno nuevo
  Future<String> _getIdentifiedName(
    String filePath,
    String fallbackName, {
    bool useHighPrecision = false,
    bool reuseIdentification = true,
  }) async {
    final cached = reuseIdentification
        ? _romCache.shouldProcessRom(filePath)
        : null;

    // Si tenemos cache válido, usarlo
    if (cached != null && cached.identifiedName != null) {
      return cached.identifiedName!;
    }

    // Si no queremos alta precisión o no tenemos systemId, usar nombre de archivo
    if (!useHighPrecision || screenScraperId == null) {
      // Guardar en cache como no identificado
      if (reuseIdentification) {
        final file = File(filePath);
        if (file.existsSync()) {
          final stat = file.statSync();
          _romCache.cacheRomInfo(
            filePath: filePath,
            fileSize: stat.size,
            lastModified: stat.modified,
            identifiedName: fallbackName,
            systemId: screenScraperId,
            isIdentified: false,
          );
        }
      }
      return fallbackName;
    }

    // Calcular hash e identificar con ScreenScraper
    try {
      _log("🔍 Identificando con alta precisión: $fallbackName...");

      final file = File(filePath);
      final stat = file.statSync();
      final hashes = await HashService.calculateHashes(filePath);

      final identified = await ScreenScraperService.identifyGameByHash(
        sha1: hashes.sha1,
        md5: hashes.md5,
        crc: hashes.crc32,
        fileSize: stat.size,
        fileName: p.basename(filePath),
        systemId: screenScraperId!,
      );

      String finalName;
      bool wasIdentified = false;

      if (identified != null && identified.name != null) {
        finalName = identified.name!;
        wasIdentified = true;
        _log("✨ Identificado: $finalName");
      } else {
        finalName = fallbackName;
        _log("⚠️ No identificado, usando nombre de archivo");
      }

      // Guardar en cache
      if (reuseIdentification) {
        _romCache.cacheRomInfo(
          filePath: filePath,
          fileSize: stat.size,
          lastModified: stat.modified,
          sha1: hashes.sha1,
          md5: hashes.md5,
          crc32: hashes.crc32,
          identifiedName: finalName,
          systemId: screenScraperId,
          isIdentified: wasIdentified,
          // URLs de media de ScreenScraper
          coverUrl: identified?.media['cover'],
          cover3dUrl: identified?.media['cover_3d'],
          bannerUrl: identified?.media['banner'],
          logoUrl: identified?.media['logo'],
          synopsis: identified?.synopsis,
          releaseDate: identified?.releaseDate,
          developer: identified?.developer,
        );
      }

      return finalName;
    } catch (e) {
      _log("⚠️ Error de identificación: $e");

      // Guardar error en cache para evitar reintentar
      if (reuseIdentification) {
        final file = File(filePath);
        if (file.existsSync()) {
          final stat = file.statSync();
          _romCache.cacheRomInfo(
            filePath: filePath,
            fileSize: stat.size,
            lastModified: stat.modified,
            identifiedName: fallbackName,
            systemId: screenScraperId,
            isIdentified: false,
          );
        }
      }

      return fallbackName;
    }
  }

  /// Filtra archivos duplicados manteniendo solo el de mayor prioridad.
  List<File> _filterDuplicatesByPriority(List<File> files) {
    return filterDuplicatesByPriority(files, emulatorInfo, _log);
  }

  /// Versión estática para usar desde otros lugares (como main_window)
  static List<File> filterDuplicatesByPriority(
    List<File> files,
    EmulatorInfo emulatorInfo, [
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
          final priorityA = emulatorInfo.getExtensionPriority(extA);
          final priorityB = emulatorInfo.getExtensionPriority(extB);
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
    bool reuseIdentification = true,
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

    // Set para evitar duplicados en la misma sesión
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

    _log("🚀 Inyectando juegos desde: $romFolder (Runner: $runner)");

    for (int i = 0; i < romFiles.length; i++) {
      final f = romFiles[i];
      String gameSlug = p.basenameWithoutExtension(f.path);
      String gameName = customNames?[f.path] ?? gameSlug;
      final fullRomPath = f.path;

      // Early exit si la extensión no es válida para la plataforma
      final ext = p.extension(f.path).toLowerCase();
      if (!extensions.contains(ext)) {
        _log("⏩ Extensión no válida para $platformName ($runner): $ext");
        continue;
      }

      if (useHighPrecision &&
          (customNames == null || !customNames.containsKey(fullRomPath))) {
        if (_shouldCalculateHash(
          fullRomPath,
          reuseIdentification: reuseIdentification,
        )) {
          gameName = await _getIdentifiedName(
            fullRomPath,
            gameSlug,
            useHighPrecision: useHighPrecision,
            reuseIdentification: reuseIdentification,
          );
        } else {
          final cached = _romCache.shouldProcessRom(fullRomPath);
          if (cached?.identifiedName != null) {
            gameName = cached!.identifiedName!;
          }
        }
      }

      if (processedSlugs.contains(gameSlug)) {
        _log(
          "⏩ Saltando formato duplicado: $gameSlug (${p.extension(f.path)})",
        );
        continue;
      }
      processedSlugs.add(gameSlug);

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
    _romCache.dispose();

    _log("🎉 ¡Inyección completa! $count juegos nuevos agregados.", 1.0);

    if (errors.isNotEmpty) {
      _log("Se encontraron ${errors.length} errores.");
    }
  }

  Map<String, dynamic> getCacheStats() {
    return _romCache.getStats();
  }

  void clearCache() {
    _romCache.clearCache();
  }

  void dispose() {
    _romCache.dispose();
  }
}
