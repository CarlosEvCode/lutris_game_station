class PlatformInfo {
  final String platformId;
  final String platformName;
  final String runner;
  final List<String> extensions;
  final bool disableRuntime;
  final bool hasSpecialFeatures;
  final String? screenScraperId; // ID del sistema en ScreenScraper API

  /// Extensiones ordenadas por prioridad (la primera tiene mayor prioridad)
  /// Usado para evitar duplicados cuando hay múltiples formatos del mismo juego
  /// Ejemplo: si hay game.bin y game.cue, se prefiere .bin
  final List<String>? extensionPriority;

  const PlatformInfo({
    required this.platformId,
    required this.platformName,
    required this.runner,
    required this.extensions,
    this.disableRuntime = true,
    this.hasSpecialFeatures = false,
    this.screenScraperId,
    this.extensionPriority,
  });

  /// Obtiene la prioridad de una extensión (menor número = mayor prioridad)
  /// Retorna un número alto si la extensión no está en la lista de prioridad
  int getExtensionPriority(String extension) {
    final ext = extension.toLowerCase();
    if (extensionPriority == null) return 0;
    final index = extensionPriority!.indexOf(ext);
    return index == -1 ? extensionPriority!.length : index;
  }
}

class PlatformRegistry {
  static final Map<String, PlatformInfo> _platforms = {};

  static void initialize() {
    if (_platforms.isNotEmpty) return;

    _platforms['ps1'] = const PlatformInfo(
      platformId: 'ps1',
      platformName: 'Sony PlayStation',
      runner: 'duckstation',
      extensions: ['.bin', '.chd', '.pbp', '.cue'],
      // Prioridad: .bin > .chd > .pbp > .cue
      // Si existe game.bin y game.cue, se usa .bin (el .cue es solo metadata)
      extensionPriority: ['.bin', '.chd', '.pbp', '.cue'],
      screenScraperId: '57',
    );
    _platforms['ps2'] = const PlatformInfo(
      platformId: 'ps2',
      platformName: 'Sony PlayStation 2',
      runner: 'pcsx2',
      extensions: ['.iso', '.chd'],
      extensionPriority: ['.iso', '.chd'],
      screenScraperId: '58',
    );
    _platforms['gamecube'] = const PlatformInfo(
      platformId: 'gamecube',
      platformName: 'Nintendo GameCube',
      runner: 'dolphin',
      extensions: ['.iso', '.gcz', '.rvz'],
      extensionPriority: ['.iso', '.gcz', '.rvz'],
      screenScraperId: '13',
    );
    _platforms['wii'] = const PlatformInfo(
      platformId: 'wii',
      platformName: 'Nintendo Wii',
      runner: 'dolphin',
      extensions: ['.iso', '.wbfs', '.rvz'],
      extensionPriority: ['.iso', '.wbfs', '.rvz'],
      screenScraperId: '16',
    );
    _platforms['wii_u'] = const PlatformInfo(
      platformId: 'wii_u',
      platformName: 'Nintendo Wii U',
      runner: 'cemu',
      extensions: ['.wud', '.wux', '.rpx'],
      disableRuntime: false,
      screenScraperId: '18',
    );
    _platforms['mame'] = const PlatformInfo(
      platformId: 'mame',
      platformName: 'Arcade (MAME)',
      runner: 'mame',
      extensions: ['.zip', '.7z'],
      extensionPriority: ['.zip', '.7z'],
      hasSpecialFeatures: true,
      disableRuntime: false,
      screenScraperId: '75',
    );
    _platforms['3ds'] = const PlatformInfo(
      platformId: '3ds',
      platformName: 'Nintendo 3DS',
      runner: 'citra',
      extensions: ['.3ds', '.cia', '.cci'],
      extensionPriority: ['.3ds', '.cia', '.cci'],
      screenScraperId: '17',
    );
  }

  static PlatformInfo? getPlatform(String id) {
    return _platforms[id];
  }

  static List<PlatformInfo> getAllPlatforms() {
    return _platforms.values.toList();
  }
}
