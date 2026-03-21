import 'dart:io';

import '../lutris/games_repository.dart';
import '../lutris/lutris_paths.dart';
import 'models/steam_export_result.dart';
import 'models/steam_shortcut_entry.dart';
import 'steam_artwork_service.dart';
import 'steam_collections_service.dart';
import 'steam_detector.dart';
import 'steam_shortcuts_service.dart';

class SteamExportService {
  final SteamDetector _detector;
  final SteamShortcutsService _shortcuts;
  final SteamArtworkService _artwork;
  final SteamCollectionsService _collections;

  SteamExportService({
    SteamDetector? detector,
    SteamShortcutsService? shortcuts,
    SteamArtworkService? artwork,
    SteamCollectionsService? collections,
  }) : _detector = detector ?? SteamDetector(),
       _shortcuts = shortcuts ?? SteamShortcutsService(),
       _artwork = artwork ?? SteamArtworkService(),
       _collections = collections ?? SteamCollectionsService();

  Future<bool> canExportToSteam() async {
    final shortcutsPath = _detector.shortcutsPath();
    final gridPath = _detector.gridPath();
    if (shortcutsPath == null || gridPath == null) return false;

    final hasVdf = await _shortcuts.isPythonVdfAvailable();
    final hasPillow = await _shortcuts.isPillowAvailable();
    return hasVdf && hasPillow;
  }

  Future<SteamExportResult> exportGame(
    Game game,
    Map<String, String?> lutrisPaths,
  ) async {
    final lp = LutrisPaths.fromMap(lutrisPaths);
    final shortcutsPath = _detector.shortcutsPath();
    final gridPath = _detector.gridPath();

    if (shortcutsPath == null || gridPath == null) {
      return SteamExportResult.error(
        'No se detecto una instalacion valida de Steam.',
      );
    }

    final hasPythonVdf = await _shortcuts.isPythonVdfAvailable();
    if (!hasPythonVdf) {
      return SteamExportResult.error(
        'Falta dependencia python-vdf. Instala con: pip install vdf',
      );
    }

    final hasPillow = await _shortcuts.isPillowAvailable();
    if (!hasPillow) {
      return SteamExportResult.error(
        'Falta dependencia Pillow. Instala con: pip install pillow',
      );
    }

    try {
      final launch = _buildLaunchCommand(game, lp);
      final lutrisIconPath = lp.lutrisIconPath(game.slug);
      final systemIconPath = lp.systemIconPath(game.slug);
      final resolvedIconPath = File(lutrisIconPath).existsSync()
          ? lutrisIconPath
          : (File(systemIconPath).existsSync() ? systemIconPath : '');

      final appId = _artwork.calculateNonSteamAppId(launch.exe, game.name);

      final entry = SteamShortcutEntry(
        appIdSigned: _toSigned32(appId),
        appName: game.name,
        exe: launch.exe,
        startDir: launch.startDir,
        icon: resolvedIconPath,
        launchOptions: launch.launchOptions,
        tags: _buildSteamTags(game.platform),
      );

      await _shortcuts.upsertShortcut(
        vdfPath: shortcutsPath,
        lutrisGameId: game.id,
        entry: entry,
      );

      final coverPath = lp.coverPath(game.slug);
      final heroPath = lp.bannerPath(game.slug);
      final logoPath = lp.lutrisIconPath(game.slug);

      await _artwork.copyArtworkToGrid(
        gridPath: gridPath,
        appId: appId,
        coverPath: File(coverPath).existsSync() ? coverPath : null,
        heroPath: File(heroPath).existsSync() ? heroPath : null,
        iconPath: resolvedIconPath.isNotEmpty ? resolvedIconPath : null,
        logoPath: File(logoPath).existsSync() ? logoPath : null,
      );

      final namespace1Path = _detector.cloudNamespace1Path();
      final collectionName = _normalizePlatformTag(game.platform);
      if (namespace1Path != null && collectionName.trim().isNotEmpty) {
        await _collections.addAppToSimpleCollection(
          namespace1Path: namespace1Path,
          collectionName: collectionName,
          appId: appId,
        );
      }

      return SteamExportResult.ok(
        'Exportado a Steam: ${game.name}',
        appId: appId,
      );
    } catch (e) {
      return SteamExportResult.error('Error exportando ${game.name}: $e');
    }
  }

  Future<SteamPlatformSyncResult> syncPlatformToSteam({
    required List<Game> platformGames,
    required String platformName,
    required Map<String, String?> lutrisPaths,
  }) async {
    final lp = LutrisPaths.fromMap(lutrisPaths);
    final repo = GamesRepository(lp.dbPath);
    final shortcutsPath = _detector.shortcutsPath();
    final gridPath = _detector.gridPath();
    final namespace1Path = _detector.cloudNamespace1Path();

    if (shortcutsPath == null || gridPath == null) {
      return const SteamPlatformSyncResult(
        exportedOk: 0,
        exportedFailed: 0,
        removedShortcuts: 0,
        removedArtworkEntries: 0,
      );
    }

    var ok = 0;
    var failed = 0;
    for (final game in platformGames) {
      final result = await exportGame(game, lutrisPaths);
      if (result.success) {
        ok++;
      } else {
        failed++;
      }
    }

    final allLutrisShortcuts = await _shortcuts.listLutrisShortcuts(
      vdfPath: shortcutsPath,
    );
    final targetIds = platformGames.map((g) => g.id).toSet();

    bool belongsToCurrentPlatform(SteamShortcutRecord s) {
      final gamePlatform = repo.getGamePlatformName(s.gameId);
      if (gamePlatform == null) {
        return false;
      }
      return gamePlatform.toLowerCase() == platformName.toLowerCase();
    }

    final stale = allLutrisShortcuts
        .where(
          (s) => belongsToCurrentPlatform(s) && !targetIds.contains(s.gameId),
        )
        .toList();

    final staleIndexes = stale.map((s) => s.index).toList();
    if (staleIndexes.isNotEmpty) {
      await _shortcuts.removeShortcutsByIndex(
        vdfPath: shortcutsPath,
        indexes: staleIndexes,
      );
    }

    final staleAppIds = stale
        .map((s) {
          if (s.appIdUnsigned > 0) return s.appIdUnsigned;
          return _shortcuts.calculateNonSteamAppId(s.exe, s.appName);
        })
        .where((id) => id > 0)
        .toSet()
        .toList();

    if (staleAppIds.isNotEmpty) {
      await _artwork.removeArtworkForAppIds(
        gridPath: gridPath,
        appIds: staleAppIds,
      );
    }

    final collectionName = _normalizePlatformTag(
      platformGames.isNotEmpty ? platformGames.first.platform : platformName,
    );
    if (namespace1Path != null && collectionName.trim().isNotEmpty) {
      final currentAppIds = <int>[];
      for (final game in platformGames) {
        final launch = _buildLaunchCommand(game, lp);
        currentAppIds.add(
          _artwork.calculateNonSteamAppId(launch.exe, game.name),
        );
      }
      await _collections.replaceCollectionApps(
        namespace1Path: namespace1Path,
        collectionName: collectionName,
        appIds: currentAppIds,
      );
    }

    return SteamPlatformSyncResult(
      exportedOk: ok,
      exportedFailed: failed,
      removedShortcuts: staleIndexes.length,
      removedArtworkEntries: staleAppIds.length,
    );
  }

  _SteamLaunchCommand _buildLaunchCommand(Game game, LutrisPaths lutrisPaths) {
    final home = Platform.environment['HOME'] ?? '/';
    final quotedUri = "'lutris:rungameid/${game.id}'";
    final isFlatpak = lutrisPaths.mode.toUpperCase() == 'FLATPAK';
    if (isFlatpak) {
      return _SteamLaunchCommand(
        exe: '"/usr/bin/flatpak"',
        startDir: '"$home"',
        launchOptions: 'run net.lutris.Lutris $quotedUri',
      );
    }

    final lutrisPath = File('/usr/bin/lutris').existsSync()
        ? '"/usr/bin/lutris"'
        : '"lutris"';
    return _SteamLaunchCommand(
      exe: lutrisPath,
      startDir: '"$home"',
      launchOptions: quotedUri,
    );
  }

  int _toSigned32(int value) {
    if (value > 0x7FFFFFFF) {
      return value - 0x100000000;
    }
    return value;
  }

  List<String> _buildSteamTags(String platform) {
    final normalized = _normalizePlatformTag(platform);
    if (normalized.trim().isEmpty) {
      return const ['Lutris'];
    }
    return ['Lutris', normalized];
  }

  String _normalizePlatformTag(String platform) {
    final p = platform.trim().toLowerCase();
    const aliases = {
      'sony playstation': 'PS1',
      'ps1': 'PS1',
      'sony playstation 2': 'PS2',
      'ps2': 'PS2',
      'nintendo gamecube': 'GameCube',
      'gamecube': 'GameCube',
      'nintendo wii': 'Wii',
      'wii': 'Wii',
      'nintendo wii u': 'Wii U',
      'wii_u': 'Wii U',
      'nintendo 3ds': '3DS',
      '3ds': '3DS',
      'arcade (mame)': 'MAME',
      'mame': 'MAME',
    };
    return aliases[p] ?? platform;
  }
}

class SteamPlatformSyncResult {
  final int exportedOk;
  final int exportedFailed;
  final int removedShortcuts;
  final int removedArtworkEntries;

  const SteamPlatformSyncResult({
    required this.exportedOk,
    required this.exportedFailed,
    required this.removedShortcuts,
    required this.removedArtworkEntries,
  });
}

class _SteamLaunchCommand {
  final String exe;
  final String startDir;
  final String launchOptions;

  const _SteamLaunchCommand({
    required this.exe,
    required this.startDir,
    required this.launchOptions,
  });
}
