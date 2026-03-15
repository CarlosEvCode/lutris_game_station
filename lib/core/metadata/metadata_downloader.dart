import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;
import 'steamgriddb_service.dart';
import 'package:http/http.dart' as http;

class MetadataDownloader {
  final Map<String, String?> lutrisPaths;
  final String apiKey;
  final String runner;
  final Function(String message, double? progress)? progressCallback;

  late final String dbPath;
  late final String coversDir;
  late final String bannersDir;
  late final String lutrisIconsDir;
  late final String systemIconsDir;
  late final SteamGridDBService _api;

  static const _manualFixes = {
    "BloodyRoarII": "Bloody Roar 2",
    "kof2002": "The King of Fighters 2002",
    "MarvelVsCapcom": "Marvel vs. Capcom: Clash of Super Heroes"
  };

  MetadataDownloader({
    required this.lutrisPaths,
    required this.apiKey,
    required this.runner,
    this.progressCallback,
  }) {
    dbPath = lutrisPaths['db_path']!;
    coversDir = lutrisPaths['covers_dir']!;
    bannersDir = lutrisPaths['banners_dir']!;
    lutrisIconsDir = lutrisPaths['lutris_icons_dir']!;
    systemIconsDir = lutrisPaths['system_icons_dir']!;
    _api = SteamGridDBService(apiKey: apiKey);
  }

  void _log(String message, [double? progress]) {
    if (progressCallback != null) {
      progressCallback!(message, progress);
    }
  }

  void _ensureDirectories() {
    for (final d in [coversDir, bannersDir, lutrisIconsDir, systemIconsDir]) {
      final dir = Directory(d);
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (e) {
          _log("⚠️ Error creando directorio $d: $e");
        }
      }
    }
  }

  String _cleanName(String name) {
    String clean = name;
    clean = clean.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    clean = clean.replaceAllMapped(RegExp(r'(\D)(\d)'), (m) => '${m[1]} ${m[2]}');
    clean = clean.replaceAll(RegExp(r'\..+$'), ''); 
    clean = clean.replaceAll('_', ' ').replaceAll('.', ' ');
    clean = clean.replaceAll(RegExp(r'\(.*?\)'), '');
    clean = clean.replaceAll(RegExp(r'\[.*?\]'), '');
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean;
  }

  Future<bool> _downloadFile(String url, String path) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        File(path).writeAsBytesSync(res.bodyBytes);
        return true;
      }
    } catch (e) {
      _log("⚠️ Error descargando $url: $e");
    }
    return false;
  }

  Future<void> downloadMetadata({bool skipExisting = true}) async {
    if (apiKey.isEmpty) {
      _log("❌ No hay API Key configurada");
      return;
    }

    _ensureDirectories();
    final db = sqlite3.open(dbPath);

    _log("🎨 Descargando metadatos para: $runner");

    final results = db.select("SELECT id, slug, name FROM games WHERE runner = ? AND installed = 1", [runner]);
    if (results.isEmpty) {
      _log("⚠️ No se encontraron juegos instalados para $runner");
      db.dispose();
      return;
    }

    final totalGames = results.length;

    for (int i = 0; i < totalGames; i++) {
      final row = results[i];
      final gameId = row['id'] as int;
      final slug = row['slug'] as String;
      final rawName = row['name'] as String;

      final pCover = p.join(coversDir, "$slug.jpg");
      final pBanner = p.join(bannersDir, "$slug.jpg");
      final pIconLutris = p.join(lutrisIconsDir, "$slug.png");
      final pIconSystem = p.join(systemIconsDir, "lutris_$slug.png");

      if (skipExisting && File(pCover).existsSync() && File(pBanner).existsSync() && File(pIconSystem).existsSync()) {
        _log("⏩ Saltando $slug (Ya existe)", (i + 1) / totalGames);
        continue;
      }

      _log("🔍 Procesando: $slug", (i + 1) / totalGames);

      final cleanName = _cleanName(rawName);
      final candidates = <String>[];
      if (_manualFixes.containsKey(slug)) candidates.add(_manualFixes[slug]!);
      if (!candidates.contains(cleanName)) candidates.add(cleanName);
      if (!candidates.contains(rawName)) candidates.add(rawName);

      Map<String, dynamic>? foundGame;
      for (var candidate in candidates) {
        final results = await _api.searchGames(candidate);
        if (results.isNotEmpty) {
          foundGame = results.first;
          _log("   ✅ Encontrado: ${foundGame['name']}");
          break;
        }
      }

      if (foundGame != null) {
        final int sgdbId = foundGame['id'];
        final String sgdbName = foundGame['name'];

        // Fetch all types in parallel
        final imgResults = await Future.wait([
          _api.getImages(sgdbId, 'cover'),
          _api.getImages(sgdbId, 'banner'),
          _api.getImages(sgdbId, 'icon'),
        ]);

        final covers = imgResults[0];
        final banners = imgResults[1];
        final icons = imgResults[2];

        bool updated = false;

        if (covers.isNotEmpty && !File(pCover).existsSync()) {
          if (await _downloadFile(covers.first['url'], pCover)) updated = true;
        }
        if (banners.isNotEmpty && !File(pBanner).existsSync()) {
          if (await _downloadFile(banners.first['url'], pBanner)) updated = true;
        }
        if (icons.isNotEmpty && !File(pIconSystem).existsSync()) {
          if (await _downloadFile(icons.first['url'], pIconLutris)) {
            File(pIconLutris).copySync(pIconSystem);
            updated = true;
          }
        }

        if (updated) {
          db.execute('''
            UPDATE games
            SET name=?, sortname=?, 
                has_custom_banner=1, has_custom_icon=1, has_custom_coverart_big=1
            WHERE id=?
          ''', [sgdbName, sgdbName, gameId]);
        }
      } else {
        _log("   ❌ No se encontró en SteamGridDB");
      }
    }
    
    db.dispose();
    _log("🎉 ¡Completado!", 1.0);
  }
}
