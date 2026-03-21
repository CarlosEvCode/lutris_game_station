import 'dart:io';
import 'package:path/path.dart' as p;

class SteamDetector {
  final String _homeDir = Platform.environment['HOME'] ?? '';

  String? detectSteamBasePath() {
    final native = p.join(_homeDir, '.local', 'share', 'Steam');
    if (Directory(native).existsSync()) return native;

    final legacy = p.join(_homeDir, '.steam', 'steam');
    if (Directory(legacy).existsSync()) return legacy;

    return null;
  }

  String? detectSteamUserId(String steamBasePath) {
    final userdataDir = Directory(p.join(steamBasePath, 'userdata'));
    if (!userdataDir.existsSync()) return null;

    final candidates =
        userdataDir
            .listSync()
            .whereType<Directory>()
            .where((d) => RegExp(r'^\d+$').hasMatch(p.basename(d.path)))
            .toList()
          ..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
          );

    for (final userDir in candidates) {
      final shortcuts = File(p.join(userDir.path, 'config', 'shortcuts.vdf'));
      if (shortcuts.existsSync()) {
        return p.basename(userDir.path);
      }
    }

    if (candidates.isNotEmpty) {
      return p.basename(candidates.first.path);
    }

    return null;
  }

  String? shortcutsPath() {
    final base = detectSteamBasePath();
    if (base == null) return null;
    final userId = detectSteamUserId(base);
    if (userId == null) return null;
    return p.join(base, 'userdata', userId, 'config', 'shortcuts.vdf');
  }

  String? gridPath() {
    final base = detectSteamBasePath();
    if (base == null) return null;
    final userId = detectSteamUserId(base);
    if (userId == null) return null;
    return p.join(base, 'userdata', userId, 'config', 'grid');
  }
}
