import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'hash_service.dart';
import '../lutris/config_manager.dart';

class ScreenScraperGame {
  final String? name;
  final String? system;
  final String? region;
  final String? synopsis;
  final String? releaseDate;
  final String? developer;
  final Map<String, String> media;

  ScreenScraperGame({
    this.name,
    this.system,
    this.region,
    this.synopsis,
    this.releaseDate,
    this.developer,
    required this.media,
  });

  factory ScreenScraperGame.fromJson(Map<String, dynamic> json) {
    final response = json['response'];
    if (response == null || response['jeu'] == null) {
      throw Exception('Game not found in ScreenScraper');
    }

    final jeu = response['jeu'];
    
    String? officialName;
    if (jeu['noms'] != null && jeu['noms'] is List) {
      final noms = jeu['noms'] as List;
      officialName = noms.firstWhere(
        (n) => n['langue'] == 'en' || n['langue'] == 'es',
        orElse: () => noms.isNotEmpty ? noms.first : {'nom': 'Unknown'},
      )['nom'];
    }

    return ScreenScraperGame(
      name: officialName,
      system: jeu['systemename'],
      region: jeu['region'],
      synopsis: jeu['synopsis'],
      releaseDate: jeu['dates']?['date_u_e'],
      developer: jeu['developpeur'],
      media: {}, 
    );
  }
}

class ScreenScraperService {
  static const String _baseUrl = 'https://www.screenscraper.fr/api2/jeuInfos.php';
  static const String _userBaseUrl = 'https://www.screenscraper.fr/api2/ssuserInfos.php';
  
  // Nombre de tu aplicación (se configura en el foro de ScreenScraper)
  static const String _softName = 'LutrisGameStation';

  static Map<String, String> get _headers => {
    'User-Agent': 'Skraper', 
    'Accept': 'application/json',
  };

  static Future<bool> validateCredentials() async {
    final ssid = await ConfigManager.getSSUser();
    final sspassword = await ConfigManager.getSSPassword();
    final devid = await ConfigManager.getDevId();
    final devpassword = await ConfigManager.getDevPassword();

    if (ssid.isEmpty || sspassword.isEmpty || devid.isEmpty || devpassword.isEmpty) {
      print('❌ Faltan credenciales de usuario o de desarrollador.');
      return false;
    }

    final url = '$_userBaseUrl?devid=$devid&devpassword=$devpassword&softname=$_softName&ssid=$ssid&sspassword=$sspassword&output=json';
    
    try {
      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['response']?['ssuser'] != null;
      } else {
        print('DEBUG: HTTP ${response.statusCode}');
        print('DEBUG: Body: ${response.body}');
      }
      return false;
    } catch (e) {
      print('❌ Validation failed: $e');
      return false;
    }
  }

  static Future<ScreenScraperGame?> identifyGameByHash({
    String? crc,
    String? md5,
    String? sha1,
    int? fileSize,
    String systemId = '57', 
  }) async {
    final ssid = await ConfigManager.getSSUser();
    final sspassword = await ConfigManager.getSSPassword();
    final devid = await ConfigManager.getDevId();
    final devpassword = await ConfigManager.getDevPassword();

    if (devid.isEmpty) throw Exception('DevID de ScreenScraper no configurado.');

    var url = '$_baseUrl?devid=$devid&devpassword=$devpassword&softname=$_softName&ssid=$ssid&sspassword=$sspassword&output=json&romtype=rom&systemeid=$systemId';

    if (crc != null) url += '&crc=${crc.toLowerCase()}';
    if (md5 != null) url += '&md5=$md5';
    if (sha1 != null) url += '&sha1=$sha1';
    if (fileSize != null) url += '&romtaille=$fileSize';

    try {
      final response = await http.get(Uri.parse(url), headers: _headers);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ScreenScraperGame.fromJson(data);
      } else if (response.statusCode == 403) {
        throw Exception('Error 403: Verifica tus credenciales de desarrollador.');
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('ScreenScraper error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ ScreenScraper identification failed: $e');
      rethrow;
    }
  }

  static Future<ScreenScraperGame?> identifyFile(String filePath) async {
    try {
      final file = File(filePath);
      final size = await file.length();
      final hashes = await HashService.calculateHashes(filePath);
      
      return await identifyGameByHash(sha1: hashes.sha1, fileSize: size) ?? 
             await identifyGameByHash(crc: hashes.crc32, fileSize: size);
    } catch (e) {
      print('❌ Error identifying file $filePath: $e');
      rethrow;
    }
  }
}
