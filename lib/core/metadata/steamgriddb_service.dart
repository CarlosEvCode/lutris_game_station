import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class SteamGridDBService {
  final String apiKey;
  final String baseUrl = "https://www.steamgriddb.com/api/v2";

  // Configuración de Nintendo (Paridad con Python)
  // Muchos juegos de Nintendo en SGDB tienen avisos legales como primeras imágenes
  static const List<String> nintendoRunners = ['dolphin', 'citra', 'cemu', 'yuzu', 'ryujinx'];
  static const Map<String, int> skipCounts = {
    'cover': 2,
    'banner': 1,
    'icon': 1,
  };

  static final List<String> _userAgents = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0"
  ];

  SteamGridDBService({required this.apiKey});

  String _getRandomUserAgent() {
    return _userAgents[Random().nextInt(_userAgents.length)];
  }

  Future<http.Response> _makeRequest(String url, {int retries = 3}) async {
    int attempt = 0;
    while (attempt <= retries) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'User-Agent': _getRandomUserAgent(),
          },
        );

        if (response.statusCode == 200) {
          return response;
        } else if (response.statusCode == 429) {
          // Rate limit
          final waitTime = pow(2, attempt).toInt();
          await Future.delayed(Duration(seconds: waitTime));
        } else if (response.statusCode >= 500) {
          // Server error
          await Future.delayed(const Duration(seconds: 1));
        } else {
          return response;
        }
      } catch (e) {
        if (attempt == retries) rethrow;
        await Future.delayed(const Duration(seconds: 1));
      }
      attempt++;
    }
    throw Exception("Max retries exceeded for $url");
  }

  Future<List<Map<String, dynamic>>> searchGames(String query) async {
    final url = "$baseUrl/search/autocomplete/${Uri.encodeComponent(query)}";
    try {
      final response = await _makeRequest(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      print("Error searching games: $e");
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getImages(int gameId, String type, {String? runner}) async {
    String endpoint;
    String params = "";

    switch (type) {
      case 'cover':
        endpoint = "grids";
        params = "?dimensions=600x900&styles=alternate,material";
        break;
      case 'banner':
        endpoint = "heroes";
        break;
      case 'icon':
        endpoint = "icons";
        break;
      default:
        return [];
    }

    final url = "$baseUrl/$endpoint/game/$gameId$params";
    try {
      final response = await _makeRequest(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          List<Map<String, dynamic>> images = List<Map<String, dynamic>>.from(data['data']);
          
          // Aplicar salto de avisos de Nintendo si aplica
          if (runner != null && nintendoRunners.contains(runner.toLowerCase())) {
            final skip = skipCounts[type] ?? 0;
            if (images.length > skip) {
              images = images.sublist(skip);
            }
          }
          
          return images;
        }
      }
    } catch (e) {
      print("Error fetching images: $e");
    }
    return [];
  }
}
