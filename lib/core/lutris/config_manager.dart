import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class ConfigManager {
  static final String _homeDir = Platform.environment['HOME'] ?? '';
  static final String _configDirPath = p.join(_homeDir, '.config', 'lutris_game_station');
  static final String _configFilePath = p.join(_configDirPath, 'config.json');

  static String get configFilePath => _configFilePath;

  static Future<void> _ensureDirectoryExists() async {
    final dir = Directory(_configDirPath);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  static Future<Map<String, dynamic>> _readConfig() async {
    final file = File(_configFilePath);
    if (!file.existsSync()) return {};
    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print("Error leyendo configuración: $e");
      return {};
    }
  }

  static Future<void> _writeConfig(Map<String, dynamic> config) async {
    await _ensureDirectoryExists();
    final file = File(_configFilePath);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(config));
  }

  // Métodos específicos para la API Key
  static Future<String> getApiKey() async {
    final config = await _readConfig();
    return config['api_key'] as String? ?? '';
  }

  static Future<void> saveApiKey(String apiKey) async {
    final config = await _readConfig();
    config['api_key'] = apiKey;
    await _writeConfig(config);
  }

  // ScreenScraper Credentials
  static Future<String> getSSUser() async {
    final config = await _readConfig();
    return config['ss_user'] as String? ?? '';
  }

  static Future<String> getSSPassword() async {
    final config = await _readConfig();
    return config['ss_password'] as String? ?? '';
  }

  static Future<void> saveSSCredentials(String user, String password) async {
    final config = await _readConfig();
    config['ss_user'] = user;
    config['ss_password'] = password;
    await _writeConfig(config);
  }

  // Developer Credentials (API Keys)
  static Future<String> getDevId() async {
    final config = await _readConfig();
    return config['dev_id'] as String? ?? '';
  }

  static Future<String> getDevPassword() async {
    final config = await _readConfig();
    return config['dev_password'] as String? ?? '';
  }

  static Future<void> saveDevCredentials(String devId, String devPassword) async {
    final config = await _readConfig();
    config['dev_id'] = devId;
    config['dev_password'] = devPassword;
    await _writeConfig(config);
  }

  // Puedes añadir más configuraciones aquí en el futuro
}
