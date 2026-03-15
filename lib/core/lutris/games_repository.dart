import 'package:sqlite3/sqlite3.dart';

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

  List<Game> getGamesByRunner(String runner, {int? limit, int offset = 0}) {
    final db = sqlite3.open(dbPath);
    try {
      String query = '''
        SELECT id, slug, name, platform, configpath,
               has_custom_coverart_big, has_custom_banner, has_custom_icon
        FROM games 
        WHERE runner = ? AND installed = 1
        ORDER BY name
      ''';
      
      List<dynamic> params = [runner];
      
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

  int getGamesCount(String runner) {
    final db = sqlite3.open(dbPath);
    try {
      final results = db.select('''
        SELECT COUNT(*) as count 
        FROM games 
        WHERE runner = ? AND installed = 1
      ''', [runner]);
      return results.first['count'] as int;
    } finally {
      db.dispose();
    }
  }

  void updateGameName(int gameId, String newName) {
    final db = sqlite3.open(dbPath);
    try {
      db.execute('''
        UPDATE games
        SET name=?, sortname=?
        WHERE id=?
      ''', [newName, newName, gameId]);
    } finally {
      db.dispose();
    }
  }
  
  void markImagesAsCustom(int gameId, String gameName) {
    final db = sqlite3.open(dbPath);
    try {
      db.execute('''
        UPDATE games
        SET has_custom_banner=1, 
            has_custom_icon=1, 
            has_custom_coverart_big=1,
            name=?,
            sortname=?
        WHERE id=?
      ''', [gameName, gameName, gameId]);
    } finally {
      db.dispose();
    }
  }
}
