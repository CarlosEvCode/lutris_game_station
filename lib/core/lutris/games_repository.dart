import 'package:sqlite3/sqlite3.dart';
import 'dart:io';

class Game {
  final int id;
  final String slug;
  final String name;
  final String platform;
  final String configPath;
  final bool hasCover;
  final bool hasBanner;
  final bool hasIcon;

  Game({
    required this.id,
    required this.slug,
    required this.name,
    required this.platform,
    required this.configPath,
    required this.hasCover,
    required this.hasBanner,
    required this.hasIcon,
  });

  factory Game.fromMap(Map<String, dynamic> map) {
    return Game(
      id: map['id'] as int,
      slug: map['slug'] as String,
      name: map['name'] as String,
      platform: map['platform'] as String,
      configPath: map['configpath'] as String? ?? '',
      hasCover: (map['has_custom_coverart_big'] as int? ?? 0) == 1,
      hasBanner: (map['has_custom_banner'] as int? ?? 0) == 1,
      hasIcon: (map['has_custom_icon'] as int? ?? 0) == 1,
    );
  }
}

class GameMediaStats {
  final int total;
  final int missingCover;
  final int missingBanner;
  final int missingIcon;

  const GameMediaStats({
    required this.total,
    required this.missingCover,
    required this.missingBanner,
    required this.missingIcon,
  });
}

class GamesRepository {
  final String dbPath;

  GamesRepository(this.dbPath);

  List<String> getRunners() {
    final db = sqlite3.open(dbPath);
    try {
      final results = db.select('''
        SELECT DISTINCT runner 
        FROM games 
        WHERE installed = 1 AND runner IS NOT NULL
        ORDER BY runner
      ''');
      return results.map((r) => r['runner'] as String).toList();
    } finally {
      db.dispose();
    }
  }

  /// Helper para generar clausula IN (?, ?, ?)
  String _inClause(int count) => "(${List.filled(count, '?').join(', ')})";

  List<Game> getGamesByRunners(
    List<String> runners, {
    int? limit,
    int offset = 0,
    String? filterMode,
    String? searchQuery,
  }) {
    if (runners.isEmpty) return [];
    
    final db = sqlite3.open(dbPath);
    try {
      String whereClause = "WHERE runner IN ${_inClause(runners.length)} AND installed = 1";

      if (filterMode == 'missingCover') {
        whereClause +=
            " AND (has_custom_coverart_big = 0 OR has_custom_coverart_big IS NULL)";
      } else if (filterMode == 'missingBanner') {
        whereClause +=
            " AND (has_custom_banner = 0 OR has_custom_banner IS NULL)";
      } else if (filterMode == 'missingIcon') {
        whereClause += " AND (has_custom_icon = 0 OR has_custom_icon IS NULL)";
      }

      final params = <dynamic>[...runners];

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        whereClause += " AND (LOWER(name) LIKE ? OR LOWER(slug) LIKE ?)";
        final likeQuery = '%${searchQuery.toLowerCase()}%';
        params.addAll([likeQuery, likeQuery]);
      }

      String query =
          '''
        SELECT id, slug, name, platform, configpath,
               has_custom_coverart_big, has_custom_banner, has_custom_icon
        FROM games 
        $whereClause
        ORDER BY name
      ''';

      if (limit != null) {
        query += " LIMIT ? OFFSET ?";
        params.addAll([limit, offset]);
      }

      final results = db.select(query, params);
      return results.map((r) => Game.fromMap(r)).toList();
    } finally {
      db.dispose();
    }
  }

  GameMediaStats getMediaStatsByRunners(List<String> runners, {String? searchQuery}) {
    if (runners.isEmpty) return const GameMediaStats(total: 0, missingCover: 0, missingBanner: 0, missingIcon: 0);

    final db = sqlite3.open(dbPath);
    try {
      String whereClause = "WHERE runner IN ${_inClause(runners.length)} AND installed = 1";
      final params = <dynamic>[...runners];

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        whereClause += " AND (LOWER(name) LIKE ? OR LOWER(slug) LIKE ?)";
        final likeQuery = '%${searchQuery.toLowerCase()}%';
        params.addAll([likeQuery, likeQuery]);
      }

      final result = db.select('''
        SELECT COUNT(*) as total,
               SUM(CASE WHEN has_custom_coverart_big = 0 OR has_custom_coverart_big IS NULL THEN 1 ELSE 0 END) as missingCover,
               SUM(CASE WHEN has_custom_banner = 0 OR has_custom_banner IS NULL THEN 1 ELSE 0 END) as missingBanner,
               SUM(CASE WHEN has_custom_icon = 0 OR has_custom_icon IS NULL THEN 1 ELSE 0 END) as missingIcon
        FROM games
        $whereClause
      ''', params).first;

      return GameMediaStats(
        total: (result['total'] as int?) ?? 0,
        missingCover: (result['missingCover'] as int?) ?? 0,
        missingBanner: (result['missingBanner'] as int?) ?? 0,
        missingIcon: (result['missingIcon'] as int?) ?? 0,
      );
    } finally {
      db.dispose();
    }
  }

  void syncMetadataWithDiskByRunners({
    required List<String> runners,
    required String coversDir,
    required String bannersDir,
    required String iconsDir,
  }) {
    if (runners.isEmpty) return;

    final db = sqlite3.open(dbPath);
    try {
      final results = db.select(
        "SELECT id, slug, has_custom_coverart_big, has_custom_banner, has_custom_icon FROM games WHERE runner IN ${_inClause(runners.length)} AND installed = 1",
        [...runners],
      );

      for (final row in results) {
        final int id = row['id'];
        final String slug = row['slug'];

        final hasCoverFile = File("$coversDir$slug.jpg").existsSync();
        final hasBannerFile = File("$bannersDir$slug.jpg").existsSync();
        final hasIconFile = File("${iconsDir}lutris_$slug.png").existsSync();

        if ((hasCoverFile && row['has_custom_coverart_big'] == 0) ||
            (hasBannerFile && row['has_custom_banner'] == 0) ||
            (hasIconFile && row['has_custom_icon'] == 0)) {
          db.execute(
            '''
            UPDATE games 
            SET has_custom_coverart_big = ?, 
                has_custom_banner = ?, 
                has_custom_icon = ? 
            WHERE id = ?
          ''',
            [
              hasCoverFile ? 1 : 0,
              hasBannerFile ? 1 : 0,
              hasIconFile ? 1 : 0,
              id,
            ],
          );
        }
      }
    } finally {
      db.dispose();
    }
  }

  // Métodos antiguos mantenidos por compatibilidad si es necesario, 
  // pero ahora llaman a los nuevos por debajo con una lista de un solo elemento.
  List<Game> getGamesByRunner(String runner, {int? limit, int offset = 0, String? filterMode, String? searchQuery}) {
    return getGamesByRunners([runner], limit: limit, offset: offset, filterMode: filterMode, searchQuery: searchQuery);
  }

  GameMediaStats getMediaStats(String runner, {String? searchQuery}) {
    return getMediaStatsByRunners([runner], searchQuery: searchQuery);
  }

  void syncMetadataWithDisk({required String runner, required String coversDir, required String bannersDir, required String iconsDir}) {
    syncMetadataWithDiskByRunners(runners: [runner], coversDir: coversDir, bannersDir: bannersDir, iconsDir: iconsDir);
  }

  int getGamesCount(String runner) {
    final db = sqlite3.open(dbPath);
    try {
      final results = db.select('SELECT COUNT(*) as count FROM games WHERE runner = ? AND installed = 1', [runner]);
      return results.first['count'] as int;
    } finally {
      db.dispose();
    }
  }

  bool gameExists(int gameId) {
    final db = sqlite3.open(dbPath);
    try {
      final rows = db.select('SELECT 1 FROM games WHERE id = ? LIMIT 1', [gameId]);
      return rows.isNotEmpty;
    } finally {
      db.dispose();
    }
  }

  bool isGameInRunner(int gameId, String runner) {
    final db = sqlite3.open(dbPath);
    try {
      final rows = db.select('SELECT 1 FROM games WHERE id = ? AND runner = ? AND installed = 1 LIMIT 1', [gameId, runner]);
      return rows.isNotEmpty;
    } finally {
      db.dispose();
    }
  }

  bool isGameInPlatform(int gameId, String platformId) {
    final db = sqlite3.open(dbPath);
    try {
      final rows = db.select('SELECT 1 FROM games WHERE id = ? AND platform = ? AND installed = 1 LIMIT 1', [gameId, platformId]);
      return rows.isNotEmpty;
    } finally {
      db.dispose();
    }
  }

  bool isGameInPlatformName(int gameId, String platformName) {
    final db = sqlite3.open(dbPath);
    try {
      final rows = db.select('SELECT 1 FROM games WHERE id = ? AND LOWER(platform) = LOWER(?) AND installed = 1 LIMIT 1', [gameId, platformName]);
      return rows.isNotEmpty;
    } finally {
      db.dispose();
    }
  }

  String? getGamePlatformName(int gameId) {
    final db = sqlite3.open(dbPath);
    try {
      final rows = db.select('SELECT platform FROM games WHERE id = ? AND installed = 1 LIMIT 1', [gameId]);
      if (rows.isEmpty) return null;
      return rows.first['platform']?.toString();
    } finally {
      db.dispose();
    }
  }

  void updateGameName(int gameId, String newName) {
    final db = sqlite3.open(dbPath);
    try {
      db.execute('UPDATE games SET name=?, sortname=? WHERE id=?', [newName, newName, gameId]);
    } finally {
      db.dispose();
    }
  }

  void markImagesAsCustom(int gameId, String gameName) {
    final db = sqlite3.open(dbPath);
    try {
      db.execute('UPDATE games SET has_custom_banner=1, has_custom_icon=1, has_custom_coverart_big=1, name=?, sortname=? WHERE id=?', [gameName, gameName, gameId]);
    } finally {
      db.dispose();
    }
  }
}
