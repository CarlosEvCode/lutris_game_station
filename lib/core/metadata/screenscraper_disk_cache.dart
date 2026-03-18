import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ScreenScraperDiskCache {
  final Duration ttl;
  final Map<String, _DiskEntry> _entries = {};
  File? _cacheFile;

  ScreenScraperDiskCache({this.ttl = const Duration(days: 3)});

  File _initFile() {
    final dir = Directory(_resolveCacheDir());
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File(p.join(dir.path, 'screenscraper_cache.json'));
    if (!file.existsSync()) {
      file.writeAsStringSync('{}');
    }
    _cacheFile = file;
    return file;
  }

  String _resolveCacheDir() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    return p.join(home, '.cache', 'lutris_game_station', 'screenscraper');
  }

  void _load() {
    if (_cacheFile == null) {
      _initFile();
    }
    try {
      final content = _cacheFile!.readAsStringSync();
      if (content.isEmpty) return;
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      decoded.forEach((key, value) {
        final map = value as Map<String, dynamic>;
        final timestamp = DateTime.fromMillisecondsSinceEpoch(
          map['timestamp'] as int,
        );
        final isMiss = map['isMiss'] as bool? ?? false;
        final raw = map['data'];
        _entries[key] = _DiskEntry(
          timestamp: timestamp,
          isMiss: isMiss,
          data: raw == null ? null : Map<String, dynamic>.from(raw as Map),
        );
      });
    } catch (_) {
      _entries.clear();
      _cacheFile?.writeAsStringSync('{}');
    }
  }

  bool _isExpired(DateTime timestamp) =>
      DateTime.now().difference(timestamp) > ttl;

  DiskCacheEntry? get(String? crc, String? md5, String? sha1, String systemId) {
    if (_cacheFile == null) {
      _load();
    }
    final key = _key(crc, md5, sha1, systemId);
    final entry = _entries[key];
    if (entry == null) return null;
    if (_isExpired(entry.timestamp)) {
      _entries.remove(key);
      _persist();
      return null;
    }
    return DiskCacheEntry(
      isMiss: entry.isMiss,
      data: entry.data == null ? null : Map<String, dynamic>.from(entry.data!),
    );
  }

  void set(
    String? crc,
    String? md5,
    String? sha1,
    String systemId,
    Map<String, dynamic>? data, {
    bool isMiss = false,
  }) {
    if (_cacheFile == null) {
      _initFile();
    }
    final key = _key(crc, md5, sha1, systemId);
    _entries[key] = _DiskEntry(
      timestamp: DateTime.now(),
      isMiss: isMiss,
      data: data == null ? null : Map<String, dynamic>.from(data),
    );
    _persist();
  }

  void delete(String? crc, String? md5, String? sha1, String systemId) {
    if (_cacheFile == null) {
      _load();
    }
    final key = _key(crc, md5, sha1, systemId);
    if (_entries.remove(key) != null) {
      _persist();
    }
  }

  void clear() {
    _entries.clear();
    _persist();
  }

  int get entryCount => _entries.length;

  String _key(String? crc, String? md5, String? sha1, String systemId) {
    return '${systemId}_${crc ?? ''}_${md5 ?? ''}_${sha1 ?? ''}';
  }

  void _persist() {
    if (_cacheFile == null) {
      _initFile();
    }
    try {
      final map = <String, dynamic>{};
      final now = DateTime.now();
      final keysToRemove = <String>[];
      _entries.forEach((key, entry) {
        if (now.difference(entry.timestamp) > ttl) {
          keysToRemove.add(key);
          return;
        }
        map[key] = {
          'timestamp': entry.timestamp.millisecondsSinceEpoch,
          'isMiss': entry.isMiss,
          'data': entry.data,
        };
      });
      for (final key in keysToRemove) {
        _entries.remove(key);
      }
      _cacheFile?.writeAsStringSync(jsonEncode(map));
    } catch (_) {
      // Ignorar errores de disco.
    }
  }
}

class DiskCacheEntry {
  final bool isMiss;
  final Map<String, dynamic>? data;

  DiskCacheEntry({required this.isMiss, this.data});
}

class _DiskEntry {
  final DateTime timestamp;
  final bool isMiss;
  final Map<String, dynamic>? data;

  _DiskEntry({
    required this.timestamp,
    required this.isMiss,
    required this.data,
  });
}
