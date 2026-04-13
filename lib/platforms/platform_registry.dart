class EmulatorInfo {
  final String id;
  final String name; // Nombre legible (ej. "Citra", "Azahar")
  final String runner; // ID del runner en Lutris
  final List<String> extensions;
  final List<String>? extensionPriority;
  final bool disableRuntime;

  const EmulatorInfo({
    required this.id,
    required this.name,
    required this.runner,
    required this.extensions,
    this.extensionPriority,
    this.disableRuntime = true,
  });

  /// Obtiene la prioridad de una extensión (menor número = mayor prioridad)
  int getExtensionPriority(String extension) {
    final ext = extension.toLowerCase();
    if (extensionPriority == null) return 0;
    final index = extensionPriority!.indexOf(ext);
    return index == -1 ? extensionPriority!.length : index;
  }
}

class PlatformInfo {
  final String platformId;
  final String platformName;
  final List<EmulatorInfo> emulators;
  final bool hasSpecialFeatures;
  final String? screenScraperId; // ID del sistema en ScreenScraper API

  const PlatformInfo({
    required this.platformId,
    required this.platformName,
    required this.emulators,
    this.hasSpecialFeatures = false,
    this.screenScraperId,
  });

  /// Constructor de conveniencia para plataformas con un solo emulador
  factory PlatformInfo.single({
    required String platformId,
    required String platformName,
    required String runner,
    required List<String> extensions,
    List<String>? extensionPriority,
    bool disableRuntime = true,
    bool hasSpecialFeatures = false,
    String? screenScraperId,
  }) {
    return PlatformInfo(
      platformId: platformId,
      platformName: platformName,
      hasSpecialFeatures: hasSpecialFeatures,
      screenScraperId: screenScraperId,
      emulators: [
        EmulatorInfo(
          id: 'default',
          name: 'Default',
          runner: runner,
          extensions: extensions,
          extensionPriority: extensionPriority,
          disableRuntime: disableRuntime,
        ),
      ],
    );
  }
}

class PlatformRegistry {
  static final Map<String, PlatformInfo> _platforms = {};

  static void initialize() {
    if (_platforms.isNotEmpty) return;

    _platforms['ps1'] = PlatformInfo.single(
      platformId: 'ps1',
      platformName: 'Sony PlayStation',
      runner: 'duckstation',
      extensions: ['.bin', '.chd', '.pbp', '.cue'],
      extensionPriority: ['.bin', '.chd', '.pbp', '.cue'],
      screenScraperId: '57',
    );
    
    _platforms['ps2'] = PlatformInfo.single(
      platformId: 'ps2',
      platformName: 'Sony PlayStation 2',
      runner: 'pcsx2',
      extensions: ['.iso', '.chd'],
      extensionPriority: ['.iso', '.chd'],
      screenScraperId: '58',
    );
    
    _platforms['gamecube'] = PlatformInfo.single(
      platformId: 'gamecube',
      platformName: 'Nintendo GameCube',
      runner: 'dolphin',
      extensions: ['.iso', '.gcz', '.rvz'],
      extensionPriority: ['.iso', '.gcz', '.rvz'],
      screenScraperId: '13',
    );
    
    _platforms['wii'] = PlatformInfo.single(
      platformId: 'wii',
      platformName: 'Nintendo Wii',
      runner: 'dolphin',
      extensions: ['.iso', '.wbfs', '.rvz'],
      extensionPriority: ['.iso', '.wbfs', '.rvz'],
      screenScraperId: '16',
    );
    
    _platforms['wii_u'] = PlatformInfo.single(
      platformId: 'wii_u',
      platformName: 'Nintendo Wii U',
      runner: 'cemu',
      extensions: ['.wud', '.wux', '.rpx'],
      disableRuntime: false,
      screenScraperId: '18',
    );
    
    _platforms['mame'] = PlatformInfo.single(
      platformId: 'mame',
      platformName: 'Arcade (MAME)',
      runner: 'mame',
      extensions: ['.zip', '.7z'],
      extensionPriority: ['.zip', '.7z'],
      hasSpecialFeatures: true,
      disableRuntime: false,
      screenScraperId: '75',
    );

    // Nintendo 3DS con múltiples emuladores
    _platforms['3ds'] = const PlatformInfo(
      platformId: '3ds',
      platformName: 'Nintendo 3DS',
      screenScraperId: '17',
      emulators: [
        EmulatorInfo(
          id: 'azahar',
          name: 'Azahar',
          runner: 'azahar',
          extensions: ['.cci'],
          extensionPriority: ['.cci'],
        ),
        EmulatorInfo(
          id: 'citra',
          name: 'Citra',
          runner: 'citra',
          extensions: ['.3ds', '.cia', '.cci'],
          extensionPriority: ['.3ds', '.cia', '.cci'],
        ),
      ],
    );
  }

  static PlatformInfo? getPlatform(String id) {
    return _platforms[id];
  }

  static List<PlatformInfo> getAllPlatforms() {
    return _platforms.values.toList();
  }
}
