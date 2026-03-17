import 'dart:io';

class LutrisDetector {
  final bool interactive;
  String? _forcedMode;

  String? mode;
  String? dbPath;
  String? coversDir;
  String? bannersDir;
  String? lutrisIconsDir;
  String? configDirMain;
  String? systemIconsDir;

  static final String _homeDir = Platform.environment['HOME'] ?? '';
  static final String pathNativeDb = '$_homeDir/.local/share/lutris/pga.db';
  static final String pathFlatpakDb = '$_homeDir/.var/app/net.lutris.Lutris/data/lutris/pga.db';

  LutrisDetector({this.interactive = true, String? forceMode}) {
    _forcedMode = forceMode;
    _detectAndConfigure();
  }

  /// Returns a list of available Lutris installation modes detected on the system.
  List<String> getAvailableModes() {
    List<String> modes = [];
    if (File(pathNativeDb).existsSync()) modes.add("NATIVO");
    if (File(pathFlatpakDb).existsSync()) modes.add("FLATPAK");
    return modes;
  }

  void setMode(String newMode) {
    _forcedMode = newMode;
    _detectAndConfigure();
  }

  void _detectAndConfigure() {
    final nativeExists = File(pathNativeDb).existsSync();
    final flatpakExists = File(pathFlatpakDb).existsSync();

    if (_forcedMode != null) {
      if (_forcedMode!.toUpperCase() == "FLATPAK" && flatpakExists) {
        _configureFlatpak();
        return;
      } else if (_forcedMode!.toUpperCase() == "NATIVO" && nativeExists) {
        _configureNative();
        return;
      }
    }

    // Default priority logic if no mode is forced
    if (flatpakExists) {
      _configureFlatpak();
    } else if (nativeExists) {
      _configureNative();
    } else {
      _configureNativeDefault();
    }
  }

  void _configureFlatpak() {
    mode = "FLATPAK";
    
    final baseLutris = File(pathFlatpakDb).parent.path;
    final baseFlatpak = File(baseLutris).parent.parent.path;

    dbPath = '$baseLutris/pga.db';
    coversDir = '$baseLutris/coverart/';
    bannersDir = '$baseLutris/banners/';
    lutrisIconsDir = '$baseLutris/icons/';
    configDirMain = '$baseLutris/games/';
    systemIconsDir = '$baseFlatpak/data/icons/hicolor/128x128/apps/';
  }

  void _configureNative() {
    mode = "NATIVO";
    
    final baseData = File(pathNativeDb).parent.path;
    final baseConfig = '$_homeDir/.config/lutris';

    dbPath = '$baseData/pga.db';
    coversDir = '$baseData/coverart/';
    bannersDir = '$baseData/banners/';
    lutrisIconsDir = '$baseData/icons/';
    configDirMain = '$baseConfig/games/';
    systemIconsDir = '$_homeDir/.local/share/icons/hicolor/128x128/apps/';
  }

  void _configureNativeDefault() {
    mode = "NATIVO_DEFAULT";
    
    final baseData = '$_homeDir/.local/share/lutris';
    final baseConfig = '$_homeDir/.config/lutris';

    dbPath = '$baseData/pga.db';
    coversDir = '$baseData/coverart/';
    bannersDir = '$baseData/banners/';
    lutrisIconsDir = '$baseData/icons/';
    configDirMain = '$baseConfig/games/';
    systemIconsDir = '$_homeDir/.local/share/icons/hicolor/128x128/apps/';
  }

  Map<String, String?> getPaths() {
    return {
      'mode': mode,
      'db_path': dbPath,
      'covers_dir': coversDir,
      'banners_dir': bannersDir,
      'lutris_icons_dir': lutrisIconsDir,
      'config_dir_main': configDirMain,
      'system_icons_dir': systemIconsDir,
    };
  }
}
