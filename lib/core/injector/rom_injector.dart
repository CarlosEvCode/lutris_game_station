import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import '../../platforms/platform_registry.dart';
import 'package:path/path.dart' as p;

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
  }

  void _log(String message, [double? progress]) {
    if (progressCallback != null) {
      progressCallback!(message, progress);
    } else {
      print(message);
    }
  }

  String _createLutrisYaml(String gameSlug, String romPath, int timestamp, {Map<String, dynamic>? specialConfig}) {
    final baseName = "$gameSlug-$timestamp";
    final filenameReal = "$baseName.yml";
    final fullYamlPath = p.join(configDir, filenameReal);

    String yamlContent;

    if (runner == "mame" && specialConfig != null && specialConfig['working_dir'] != null) {
      final romDir = p.dirname(romPath);
      yamlContent = '''
game:
  main_file: "$romPath"
  working_dir: "$romDir"
system:
  disable_runtime: ${disableRuntime.toString().toLowerCase()}
  prefer_system_libs: true
''';
    } else {
      final disableRuntimeStr = disableRuntime ? "true" : "false";
      yamlContent = '''
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
      final results = db.select("SELECT configpath FROM games WHERE runner = ?", [runner]);
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

  Future<void> injectRoms({bool cleanOld = true, Map<String, dynamic>? specialConfig}) async {
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

    final files = folder.listSync().whereType<File>().toList();
    final romFiles = files.where((f) {
      final ext = p.extension(f.path).toLowerCase();
      return extensions.contains(ext);
    }).toList();

    final totalFiles = romFiles.length;
    if (totalFiles == 0) {
      _log("⚠️ No se encontraron archivos con extensiones ${extensions.join(', ')}");
      db.dispose();
      return;
    }

    _log("🚀 Inyectando $totalFiles juegos desde: $romFolder");

    for (int i = 0; i < romFiles.length; i++) {
      final f = romFiles[i];
      final filename = p.basename(f.path);
      final gameSlug = p.basenameWithoutExtension(f.path);
      final gameName = gameSlug;
      final fullRomPath = f.path;

      final uniqueTime = currentTime + count;

      final configId = _createLutrisYaml(gameSlug, fullRomPath, uniqueTime, specialConfig: specialConfig);

      try {
        db.execute('''
          INSERT INTO games (
              name, slug, runner, executable, directory, configpath, 
              installed, installed_at, platform, lastplayed,
              has_custom_banner, has_custom_icon, has_custom_coverart_big, playtime
          )
          VALUES (?, ?, ?, NULL, NULL, ?, 1, ?, ?, 0, 0, 0, 0, 0)
        ''', [gameName, gameSlug, runner, configId, uniqueTime, platformName]);

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

    _log("🎉 ¡Inyección completa! $count/$totalFiles juegos agregados.", 1.0);

    if (errors.isNotEmpty) {
      _log("Se encontraron ${errors.length} errores.");
    }
  }
}
