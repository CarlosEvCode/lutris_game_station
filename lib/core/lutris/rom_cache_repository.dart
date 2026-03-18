import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Modelo para información de ROM identificada y cacheada
class RomCacheEntry {
  final String filePath;
  final int fileSize;
  final String? sha1;
  final String? md5;
  final String? crc32;
  final String? identifiedName;
  final String? systemId;
  final DateTime lastModified;
  final DateTime cacheTime;
  final bool isIdentified;

  RomCacheEntry({
    required this.filePath,
    required this.fileSize,
    this.sha1,
    this.md5,
    this.crc32,
    this.identifiedName,
    this.systemId,
    required this.lastModified,
    required this.cacheTime,
    required this.isIdentified,
  });

  factory RomCacheEntry.fromMap(Map<String, dynamic> map) {
    return RomCacheEntry(
      filePath: map['file_path'] as String,
      fileSize: map['file_size'] as int,
      sha1: map['sha1'] as String?,
      md5: map['md5'] as String?,
      crc32: map['crc32'] as String?,
      identifiedName: map['identified_name'] as String?,
      systemId: map['system_id'] as String?,
      lastModified: DateTime.fromMillisecondsSinceEpoch(
        map['last_modified'] as int,
      ),
      cacheTime: DateTime.fromMillisecondsSinceEpoch(map['cache_time'] as int),
      isIdentified: (map['is_identified'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'file_path': filePath,
      'file_size': fileSize,
      'sha1': sha1,
      'md5': md5,
      'crc32': crc32,
      'identified_name': identifiedName,
      'system_id': systemId,
      'last_modified': lastModified.millisecondsSinceEpoch,
      'cache_time': cacheTime.millisecondsSinceEpoch,
      'is_identified': isIdentified ? 1 : 0,
    };
  }
}

/// Repositorio para cachear información de ROMs identificadas
class RomCacheRepository {
  static const Duration _cacheTtl = Duration(
    days: 7,
  ); // Cache válido por 7 días
  late final Database _db;

  RomCacheRepository() {
    _initDatabase();
  }

  String get _dbPath {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    final cacheDir = Directory(p.join(home, '.cache', 'lutris_game_station'));
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    return p.join(cacheDir.path, 'rom_cache.db');
  }

  void _initDatabase() {
    _db = sqlite3.open(_dbPath);

    // Crear tabla si no existe
    _db.execute('''
      CREATE TABLE IF NOT EXISTS rom_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT NOT NULL UNIQUE,
        file_size INTEGER NOT NULL,
        sha1 TEXT,
        md5 TEXT,
        crc32 TEXT,
        identified_name TEXT,
        system_id TEXT,
        last_modified INTEGER NOT NULL,
        cache_time INTEGER NOT NULL,
        is_identified INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Crear índices separadamente
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_file_path ON rom_cache(file_path)',
    );
    _db.execute('CREATE INDEX IF NOT EXISTS idx_sha1 ON rom_cache(sha1)');
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_last_modified ON rom_cache(last_modified)',
    );

    // Limpiar entradas expiradas
    _cleanExpiredEntries();
  }

  void _cleanExpiredEntries() {
    final cutoff = DateTime.now().subtract(_cacheTtl).millisecondsSinceEpoch;
    _db.execute('DELETE FROM rom_cache WHERE cache_time < ?', [cutoff]);
  }

  /// Verifica si una ROM necesita ser procesada
  /// Retorna null si necesita procesado, o RomCacheEntry si ya está cacheada
  RomCacheEntry? shouldProcessRom(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;

      final stat = file.statSync();
      final fileSize = stat.size;
      final lastModified = stat.modified;

      final result = _db.select('SELECT * FROM rom_cache WHERE file_path = ?', [
        filePath,
      ]);

      if (result.isEmpty) return null; // No está cacheado

      final cached = RomCacheEntry.fromMap(result.first);

      // Verificar si el archivo cambió
      if (cached.fileSize != fileSize ||
          cached.lastModified.difference(lastModified).abs().inSeconds > 1) {
        // Archivo cambió, eliminar cache
        _db.execute('DELETE FROM rom_cache WHERE file_path = ?', [filePath]);
        return null;
      }

      // Verificar si el cache expiró
      if (DateTime.now().difference(cached.cacheTime) > _cacheTtl) {
        _db.execute('DELETE FROM rom_cache WHERE file_path = ?', [filePath]);
        return null;
      }

      return cached; // Cache válido
    } catch (e) {
      print('⚠️ Error verificando cache ROM: $e');
      return null;
    }
  }

  /// Guarda información de ROM en cache
  void cacheRomInfo({
    required String filePath,
    required int fileSize,
    required DateTime lastModified,
    String? sha1,
    String? md5,
    String? crc32,
    String? identifiedName,
    String? systemId,
    bool isIdentified = false,
  }) {
    try {
      final entry = RomCacheEntry(
        filePath: filePath,
        fileSize: fileSize,
        sha1: sha1,
        md5: md5,
        crc32: crc32,
        identifiedName: identifiedName,
        systemId: systemId,
        lastModified: lastModified,
        cacheTime: DateTime.now(),
        isIdentified: isIdentified,
      );

      _db.execute(
        '''
        INSERT OR REPLACE INTO rom_cache (
          file_path, file_size, sha1, md5, crc32, identified_name,
          system_id, last_modified, cache_time, is_identified
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
        [
          entry.filePath,
          entry.fileSize,
          entry.sha1,
          entry.md5,
          entry.crc32,
          entry.identifiedName,
          entry.systemId,
          entry.lastModified.millisecondsSinceEpoch,
          entry.cacheTime.millisecondsSinceEpoch,
          entry.isIdentified ? 1 : 0,
        ],
      );
    } catch (e) {
      print('⚠️ Error guardando cache ROM: $e');
    }
  }

  /// Obtiene estadísticas del cache
  Map<String, dynamic> getStats() {
    try {
      final totalResult = _db.select('SELECT COUNT(*) as count FROM rom_cache');
      final identifiedResult = _db.select(
        'SELECT COUNT(*) as count FROM rom_cache WHERE is_identified = 1',
      );

      return {
        'totalEntries': totalResult.first['count'] as int,
        'identifiedEntries': identifiedResult.first['count'] as int,
      };
    } catch (e) {
      return {'totalEntries': 0, 'identifiedEntries': 0};
    }
  }

  /// Limpia todo el cache
  void clearCache() {
    try {
      _db.execute('DELETE FROM rom_cache');
    } catch (e) {
      print('⚠️ Error limpiando cache ROM: $e');
    }
  }

  /// Cierra la base de datos
  void dispose() {
    try {
      _db.dispose();
    } catch (e) {
      // Ignorar errores al cerrar
    }
  }
}
