import 'package:path/path.dart' as p;

class LutrisPaths {
  final String mode;
  final String dbPath;
  final String coversDir;
  final String bannersDir;
  final String lutrisIconsDir;
  final String configDirMain;
  final String systemIconsDir;

  const LutrisPaths({
    required this.mode,
    required this.dbPath,
    required this.coversDir,
    required this.bannersDir,
    required this.lutrisIconsDir,
    required this.configDirMain,
    required this.systemIconsDir,
  });

  factory LutrisPaths.fromMap(Map<String, String?> map) {
    String requiredValue(String key) {
      final value = map[key]?.trim();
      if (value == null || value.isEmpty) {
        throw StateError('Lutris path missing: $key');
      }
      return value;
    }

    return LutrisPaths(
      mode: map['mode']?.trim() ?? 'UNKNOWN',
      dbPath: requiredValue('db_path'),
      coversDir: requiredValue('covers_dir'),
      bannersDir: requiredValue('banners_dir'),
      lutrisIconsDir: requiredValue('lutris_icons_dir'),
      configDirMain: requiredValue('config_dir_main'),
      systemIconsDir: requiredValue('system_icons_dir'),
    );
  }

  String coverPath(String slug) => p.join(coversDir, '$slug.jpg');

  String bannerPath(String slug) => p.join(bannersDir, '$slug.jpg');

  String lutrisIconPath(String slug) => p.join(lutrisIconsDir, '$slug.png');

  String systemIconPath(String slug) =>
      p.join(systemIconsDir, 'lutris_$slug.png');

  String resolveConfigPath(String configPath) {
    final normalized = configPath.trim();
    if (normalized.isEmpty) return normalized;
    if (normalized.startsWith('/') || normalized.endsWith('.yml')) {
      return normalized;
    }
    return p.join(configDirMain, '$normalized.yml');
  }
}
