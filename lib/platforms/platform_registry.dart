class PlatformInfo {
  final String platformId;
  final String platformName;
  final String runner;
  final List<String> extensions;
  final bool disableRuntime;
  final bool hasSpecialFeatures;

  const PlatformInfo({
    required this.platformId,
    required this.platformName,
    required this.runner,
    required this.extensions,
    this.disableRuntime = true,
    this.hasSpecialFeatures = false,
  });
}

class PlatformRegistry {
  static final Map<String, PlatformInfo> _platforms = {};

  static void initialize() {
    if (_platforms.isNotEmpty) return;

    _platforms['ps1'] = const PlatformInfo(
      platformId: 'ps1',
      platformName: 'Sony PlayStation',
      runner: 'duckstation',
      extensions: ['.cue', '.chd', '.iso', '.m3u'],
    );
    _platforms['ps2'] = const PlatformInfo(
      platformId: 'ps2',
      platformName: 'Sony PlayStation 2',
      runner: 'pcsx2',
      extensions: ['.iso', '.chd', '.gz', '.cso'],
    );
    _platforms['gamecube'] = const PlatformInfo(
      platformId: 'gamecube',
      platformName: 'Nintendo GameCube',
      runner: 'dolphin',
      extensions: ['.iso', '.gcm', '.rvz'],
    );
    _platforms['wii'] = const PlatformInfo(
      platformId: 'wii',
      platformName: 'Nintendo Wii',
      runner: 'dolphin',
      extensions: ['.iso', '.wbfs', '.rvz'],
    );
    _platforms['wii_u'] = const PlatformInfo(
      platformId: 'wii_u',
      platformName: 'Nintendo Wii U',
      runner: 'cemu',
      extensions: ['.wud', '.wux', '.rpx'],
      disableRuntime: false,
    );
    _platforms['mame'] = const PlatformInfo(
      platformId: 'mame',
      platformName: 'Arcade (MAME)',
      runner: 'mame',
      extensions: ['.zip', '.7z'],
      hasSpecialFeatures: true,
      disableRuntime: false,
    );
    _platforms['3ds'] = const PlatformInfo(
      platformId: '3ds',
      platformName: 'Nintendo 3DS',
      runner: 'citra',
      extensions: ['.cci', '.3ds', '.3dsx'],
    );
  }

  static PlatformInfo? getPlatform(String id) {
    return _platforms[id];
  }

  static List<PlatformInfo> getAllPlatforms() {
    return _platforms.values.toList();
  }
}
