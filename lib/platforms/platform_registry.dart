class EmulatorInfo {
  final String id;
  final String name; // Nombre legible (ej. "Citra", "Azahar")
  final String runner; // ID del runner en Lutris
  final String? libretroCore; // Nombre del core si el runner es libretro
  final List<String> extensions;
  final List<String>? extensionPriority;
  final bool disableRuntime;
  final Map<String, dynamic>? specialConfig; // Nuevo: Configuración extra para el YAML

  const EmulatorInfo({
    required this.id,
    required this.name,
    required this.runner,
    required this.extensions,
    this.libretroCore,
    this.extensionPriority,
    this.disableRuntime = true,
    this.specialConfig,
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
  final bool hideFromInjector; // Nuevo: Ocultar de la vista de inyección

  const PlatformInfo({
    required this.platformId,
    required this.platformName,
    required this.emulators,
    this.hasSpecialFeatures = false,
    this.screenScraperId,
    this.hideFromInjector = false,
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
    Map<String, dynamic>? specialConfig,
    bool hideFromInjector = false,
  }) {
    return PlatformInfo(
      platformId: platformId,
      platformName: platformName,
      hasSpecialFeatures: hasSpecialFeatures,
      screenScraperId: screenScraperId,
      hideFromInjector: hideFromInjector,
      emulators: [
        EmulatorInfo(
          id: 'default',
          name: 'Default',
          runner: runner,
          extensions: extensions,
          extensionPriority: extensionPriority,
          disableRuntime: disableRuntime,
          specialConfig: specialConfig,
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
      disableRuntime: true,
    );
    
    _platforms['ps2'] = PlatformInfo.single(
      platformId: 'ps2',
      platformName: 'Sony PlayStation 2',
      runner: 'pcsx2',
      extensions: ['.iso', '.chd'],
      extensionPriority: ['.iso', '.chd'],
      screenScraperId: '58',
      disableRuntime: true,
    );
    
    _platforms['gamecube'] = PlatformInfo.single(
      platformId: 'gamecube',
      platformName: 'Nintendo GameCube',
      runner: 'dolphin',
      extensions: ['.iso', '.gcz', '.rvz'],
      extensionPriority: ['.iso', '.gcz', '.rvz'],
      screenScraperId: '13',
      specialConfig: {'platform': '0'}, // 0 = GameCube
    );
    
    _platforms['wii'] = PlatformInfo.single(
      platformId: 'wii',
      platformName: 'Nintendo Wii',
      runner: 'dolphin',
      extensions: ['.iso', '.wbfs', '.rvz'],
      extensionPriority: ['.iso', '.wbfs', '.rvz'],
      screenScraperId: '16',
      specialConfig: {'platform': '1'}, // 1 = Wii
    );
    
    _platforms['wii_u'] = PlatformInfo.single(
      platformId: 'wii_u',
      platformName: 'Nintendo Wii U',
      runner: 'cemu',
      extensions: ['.wud', '.wux', '.rpx', '.wua'],
      extensionPriority: ['.wua', '.rpx', '.wud', '.wux'],
      disableRuntime: true,
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
          disableRuntime: true,
        ),
        EmulatorInfo(
          id: 'citra',
          name: 'Citra',
          runner: 'citra',
          extensions: ['.3ds', '.cia', '.cci'],
          extensionPriority: ['.3ds', '.cia', '.cci'],
          disableRuntime: true,
        ),
      ],
    );

    _platforms['psp'] = const PlatformInfo(
      platformId: 'psp',
      platformName: 'Sony PSP',
      screenScraperId: '61',
      emulators: [
        EmulatorInfo(
          id: 'ppsspp_standalone',
          name: 'PPSSPP (Standalone)',
          runner: 'ppsspp',
          extensions: ['.iso', '.cso', '.pbp'],
          extensionPriority: ['.iso', '.cso', '.pbp'],
        ),
        EmulatorInfo(
          id: 'ppsspp_libretro',
          name: 'PPSSPP (Libretro)',
          runner: 'libretro',
          libretroCore: 'ppsspp',
          extensions: ['.iso', '.cso', '.pbp'],
          extensionPriority: ['.iso', '.cso', '.pbp'],
        ),
      ],
    );

    _platforms['dreamcast'] = const PlatformInfo(
      platformId: 'dreamcast',
      platformName: 'Sega Dreamcast',
      screenScraperId: '23',
      emulators: [
        EmulatorInfo(
          id: 'flycast',
          name: 'Flycast (Libretro)',
          runner: 'libretro',
          libretroCore: 'flycast',
          extensions: ['.chd', '.gdi', '.cdi'],
          extensionPriority: ['.chd', '.gdi', '.cdi'],
        ),
        EmulatorInfo(
          id: 'redream',
          name: 'Redream',
          runner: 'redream',
          extensions: ['.chd', '.gdi', '.cdi'],
          extensionPriority: ['.chd', '.gdi', '.cdi'],
        ),
        EmulatorInfo(
          id: 'reicast',
          name: 'Reicast',
          runner: 'reicast',
          extensions: ['.chd', '.gdi', '.cdi'],
          extensionPriority: ['.chd', '.gdi', '.cdi'],
        ),
      ],
    );

    _platforms['switch'] = const PlatformInfo(
      platformId: 'switch',
      platformName: 'Nintendo Switch',
      screenScraperId: '157',
      emulators: [
        EmulatorInfo(
          id: 'yuzu',
          name: 'Yuzu',
          runner: 'yuzu',
          extensions: ['.nsp', '.xci', '.nca', '.nso'],
          extensionPriority: ['.nsp', '.xci', '.nca', '.nso'],
        ),
        EmulatorInfo(
          id: 'ryujinx',
          name: 'Ryujinx',
          runner: 'ryujinx',
          extensions: ['.nsp', '.xci', '.nca', '.nso'],
          extensionPriority: ['.nsp', '.xci', '.nca', '.nso'],
        ),
      ],
    );

    _platforms['ds'] = const PlatformInfo(
      platformId: 'ds',
      platformName: 'Nintendo DS',
      screenScraperId: '15',
      emulators: [
        EmulatorInfo(
          id: 'desmume_standalone',
          name: 'DeSmuME (Standalone)',
          runner: 'desmume',
          extensions: ['.nds', '.ds'],
          extensionPriority: ['.nds', '.ds'],
        ),
        EmulatorInfo(
          id: 'melonds_standalone',
          name: 'melonDS (Standalone)',
          runner: 'melonds',
          extensions: ['.nds', '.ds'],
          extensionPriority: ['.nds', '.ds'],
        ),
        EmulatorInfo(
          id: 'desmume_libretro',
          name: 'DeSmuME (Libretro)',
          runner: 'libretro',
          libretroCore: 'desmume',
          extensions: ['.nds', '.ds'],
          extensionPriority: ['.nds', '.ds'],
        ),
      ],
    );

    _platforms['gba'] = PlatformInfo.single(
      platformId: 'gba',
      platformName: 'Nintendo Game Boy Advance',
      runner: 'mgba',
      extensions: ['.gba'],
      extensionPriority: ['.gba'],
      screenScraperId: '24',
    );

    _platforms['vita'] = PlatformInfo.single(
      platformId: 'vita',
      platformName: 'Sony PS Vita',
      runner: 'vita3k',
      extensions: ['.vpk', '.zip'],
      extensionPriority: ['.vpk', '.zip'],
      screenScraperId: '63',
      disableRuntime: true,
    );

    _platforms['xbox'] = PlatformInfo.single(
      platformId: 'xbox',
      platformName: 'Microsoft Xbox',
      runner: 'xemu',
      extensions: ['.iso', '.xiso'],
      extensionPriority: ['.iso', '.xiso'],
      screenScraperId: '32',
      disableRuntime: true,
    );

    _platforms['windows'] = PlatformInfo.single(
      platformId: 'windows',
      platformName: 'Windows',
      runner: 'wine',
      extensions: ['.exe'],
      screenScraperId: '1',
      hideFromInjector: true,
    );
  }

  static PlatformInfo? getPlatform(String id) {
    return _platforms[id];
  }

  static List<PlatformInfo> getAllPlatforms() {
    return _platforms.values.toList();
  }

  static List<PlatformInfo> getInjectorPlatforms() {
    return _platforms.values.where((p) => !p.hideFromInjector).toList();
  }
}
