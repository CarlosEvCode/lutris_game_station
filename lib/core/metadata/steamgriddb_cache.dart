import 'dart:convert';
import 'dart:io';

class SteamGridDBCache {
  static final SteamGridDBCache _instance = SteamGridDBCache._internal();

  factory SteamGridDBCache() => _instance;

  final Duration ttl;
  final Map<String, _CacheEntry> _entries = {};
  final File _cacheFile;

  SteamGridDBCache._internal({this.ttl = const Duration(hours: 12)})
    : _cacheFile = File(_resolveCacheFilePath()) {
    _ensureFile();
    _loadFromDisk();
  }

  static String _resolveCacheFilePath() {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final baseDir = home != null
        ? Directory(home)
        : Directory(Directory.systemTemp.path);
    final cacheDir = Directory('${baseDir.path}/.cache/lutris_game_station');
    cacheDir.createSync(recursive: true);
    return '${cacheDir.path}/steamgriddb_cache.json';
  }

  void _ensureFile() {
    if (!_cacheFile.existsSync()) {
      _cacheFile.writeAsStringSync('{}');
    }
  }

  void _loadFromDisk() {
    try {
      final content = _cacheFile.readAsStringSync();
      if (content.isEmpty) return;
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      decoded.forEach((key, value) {
        final data = value as Map<String, dynamic>;
        final timestamp = DateTime.fromMillisecondsSinceEpoch(
          data['timestamp'] as int,
        );
        _entries[key] = _CacheEntry(timestamp: timestamp, data: data['data']);
      });
    } catch (_) {
      _entries.clear();
      _cacheFile.writeAsStringSync('{}');
    }
  }

  void _persist() {
    try {
      final map = <String, dynamic>{};
      final now = DateTime.now();
      final expiredKeys = <String>[];

      _entries.forEach((key, entry) {
        if (now.difference(entry.timestamp) > ttl) {
          expiredKeys.add(key);
          return;
        }
        map[key] = {
          'timestamp': entry.timestamp.millisecondsSinceEpoch,
          'data': entry.data,
        };
      });

      for (final key in expiredKeys) {
        _entries.remove(key);
      }

      _cacheFile.writeAsStringSync(jsonEncode(map));
    } catch (_) {
      // Ignorar fallos de disco para no interrumpir el flujo principal.
    }
  }

  bool _isExpired(DateTime timestamp) =>
      DateTime.now().difference(timestamp) > ttl;

  List<Map<String, dynamic>>? _getList(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (_isExpired(entry.timestamp)) {
      _entries.remove(key);
      _persist();
      return null;
    }
    final rawList = entry.data;
    if (rawList is List) {
      return rawList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
    }
    return null;
  }

  void _setList(String key, List<Map<String, dynamic>> value) {
    _entries[key] = _CacheEntry(
      timestamp: DateTime.now(),
      data: value
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false),
    );
    _persist();
  }

  List<Map<String, dynamic>>? getSearch(String term) =>
      _getList('search:$term');

  void setSearch(String term, List<Map<String, dynamic>> data) =>
      _setList('search:$term', data);

  List<Map<String, dynamic>>? getImages(int gameId, String type) =>
      _getList('images:$type:$gameId');

  void setImages(int gameId, String type, List<Map<String, dynamic>> data) =>
      _setList('images:$type:$gameId', data);

  void clear() {
    _entries.clear();
    _persist();
  }
}

class _CacheEntry {
  final DateTime timestamp;
  final dynamic data;

  _CacheEntry({required this.timestamp, required this.data});
}
