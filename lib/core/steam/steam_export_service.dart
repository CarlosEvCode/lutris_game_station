import 'dart:io';
import 'package:path/path.dart' as p;

import '../lutris/games_repository.dart';
import 'models/steam_export_result.dart';
import 'models/steam_shortcut_entry.dart';
import 'steam_artwork_service.dart';
import 'steam_detector.dart';
import 'steam_shortcuts_service.dart';

class SteamExportService {
  final SteamDetector _detector;
  final SteamShortcutsService _shortcuts;
  final SteamArtworkService _artwork;

  SteamExportService({
    SteamDetector? detector,
    SteamShortcutsService? shortcuts,
    SteamArtworkService? artwork,
  }) : _detector = detector ?? SteamDetector(),
       _shortcuts = shortcuts ?? SteamShortcutsService(),
       _artwork = artwork ?? SteamArtworkService();

  Future<SteamExportResult> exportGame(
    Game game,
    Map<String, String?> lutrisPaths,
  ) async {
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

    try {
      final launch = _buildLaunchCommand(game, lutrisPaths);
      final lutrisIconPath = p.join(
        lutrisPaths['lutris_icons_dir']!,
        '${game.slug}.png',
      );
      final systemIconPath = p.join(
        lutrisPaths['system_icons_dir']!,
        'lutris_${game.slug}.png',
      );
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
        tags: [game.platform],
      );

      await _shortcuts.upsertShortcut(
        vdfPath: shortcutsPath,
        lutrisGameId: game.id,
        entry: entry,
      );

      final coverPath = p.join(lutrisPaths['covers_dir']!, '${game.slug}.jpg');
      final heroPath = p.join(lutrisPaths['banners_dir']!, '${game.slug}.jpg');
      final logoPath = p.join(
        lutrisPaths['lutris_icons_dir']!,
        '${game.slug}.png',
      );

      await _artwork.copyArtworkToGrid(
        gridPath: gridPath,
        appId: appId,
        coverPath: File(coverPath).existsSync() ? coverPath : null,
        heroPath: File(heroPath).existsSync() ? heroPath : null,
        iconPath: resolvedIconPath.isNotEmpty ? resolvedIconPath : null,
        logoPath: File(logoPath).existsSync() ? logoPath : null,
      );

      return SteamExportResult.ok(
        'Exportado a Steam: ${game.name}',
        appId: appId,
      );
    } catch (e) {
      return SteamExportResult.error('Error exportando ${game.name}: $e');
    }
  }

  _SteamLaunchCommand _buildLaunchCommand(
    Game game,
    Map<String, String?> lutrisPaths,
  ) {
    final home = Platform.environment['HOME'] ?? '/';
    final quotedUri = "'lutris:rungameid/${game.id}'";
    final isFlatpak = (lutrisPaths['mode'] ?? '').toUpperCase() == 'FLATPAK';
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
