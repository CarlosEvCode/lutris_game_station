import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:collection';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'hash_service.dart';
import '../lutris/config_manager.dart';
import 'package:path/path.dart' as p;

// ============================================================================
// EXCEPCIONES PERSONALIZADAS PARA SCREENSCRAPER
// ============================================================================

/// Excepción base para errores de ScreenScraper
class ScreenScraperException implements Exception {
  final String message;
  final int? statusCode;
  final bool isRetryable;

  ScreenScraperException(
    this.message, {
    this.statusCode,
    this.isRetryable = false,
  });

  @override
  String toString() => 'ScreenScraperException: $message (code: $statusCode)';
}

/// Error 401/423: API cerrada o caída - reintentar más tarde
class ApiUnavailableException extends ScreenScraperException {
  ApiUnavailableException(String message, {int? statusCode})
    : super(message, statusCode: statusCode, isRetryable: true);
}

/// Error 403: Credenciales incorrectas - no reintentar
class AuthenticationException extends ScreenScraperException {
  AuthenticationException(String message)
    : super(message, statusCode: 403, isRetryable: false);
}

/// Error 426: App bloqueada (blacklist) - CRÍTICO
class AppBlockedException extends ScreenScraperException {
  AppBlockedException()
    : super(
        'Tu aplicación ha sido bloqueada por ScreenScraper. Contacta con soporte.',
        statusCode: 426,
        isRetryable: false,
      );
}

/// Error 429: Demasiados threads/requests simultáneos
class TooManyRequestsException extends ScreenScraperException {
  TooManyRequestsException()
    : super(
        'Demasiadas peticiones simultáneas. Reduciendo velocidad...',
        statusCode: 429,
        isRetryable: true,
      );
}

/// Error 430: Quota diaria excedida
class QuotaExceededException extends ScreenScraperException {
  QuotaExceededException()
    : super(
        'Has excedido tu límite diario de peticiones. Intenta mañana.',
        statusCode: 430,
        isRetryable: false,
      );
}

/// Error 431: Demasiadas ROMs inválidas
class TooManyInvalidRomsException extends ScreenScraperException {
  TooManyInvalidRomsException()
    : super(
        'Demasiadas ROMs no reconocidas. Verifica tus archivos.',
        statusCode: 431,
        isRetryable: false,
      );
}

// ============================================================================
// RATE LIMITER - Control de velocidad de requests
// ============================================================================

/// Controla la velocidad de requests para no exceder los límites de la API
class RateLimiter {
  final int maxRequestsPerMinute;
  final Queue<DateTime> _requestTimes = Queue<DateTime>();

  RateLimiter({required this.maxRequestsPerMinute});

  /// Espera si es necesario antes de permitir un nuevo request
  Future<void> acquire() async {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

    // Limpiar requests antiguos (más de 1 minuto)
    while (_requestTimes.isNotEmpty &&
        _requestTimes.first.isBefore(oneMinuteAgo)) {
      _requestTimes.removeFirst();
    }

    // Si hemos alcanzado el límite, esperar
    if (_requestTimes.length >= maxRequestsPerMinute) {
      final oldestRequest = _requestTimes.first;
      final waitTime = oldestRequest
          .add(const Duration(minutes: 1))
          .difference(now);
      if (waitTime.isNegative == false && waitTime.inMilliseconds > 0) {
        await Future.delayed(waitTime + const Duration(milliseconds: 100));
      }
      // Limpiar de nuevo después de esperar
      final newNow = DateTime.now();
      final newOneMinuteAgo = newNow.subtract(const Duration(minutes: 1));
      while (_requestTimes.isNotEmpty &&
          _requestTimes.first.isBefore(newOneMinuteAgo)) {
        _requestTimes.removeFirst();
      }
    }

    // Registrar este request
    _requestTimes.addLast(DateTime.now());
  }

  /// Número de requests disponibles en este momento
  int get availableRequests {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

    // Contar requests en el último minuto
    int recentRequests = 0;
    for (final time in _requestTimes) {
      if (time.isAfter(oneMinuteAgo)) {
        recentRequests++;
      }
    }

    return maxRequestsPerMinute - recentRequests;
  }
}

// ============================================================================
// CACHE DE RESPUESTAS - Evita requests duplicados
// ============================================================================

/// Cache en memoria para respuestas de la API
class ResponseCache {
  final Map<String, _CacheEntry> _cache = {};
  final Duration maxAge;

  ResponseCache({this.maxAge = const Duration(hours: 1)});

  /// Genera una clave única para el cache basada en los hashes
  String _generateKey(String? crc, String? md5, String? sha1, String systemId) {
    return '${systemId}_${crc ?? ''}_${md5 ?? ''}_${sha1 ?? ''}';
  }

  /// Obtiene una respuesta del cache si existe y no ha expirado
  ScreenScraperGame? get(
    String? crc,
    String? md5,
    String? sha1,
    String systemId,
  ) {
    final key = _generateKey(crc, md5, sha1, systemId);
    final entry = _cache[key];

    if (entry == null) return null;

    if (DateTime.now().difference(entry.timestamp) > maxAge) {
      _cache.remove(key);
      return null;
    }

    return entry.game;
  }

  /// Guarda una respuesta en el cache
  void set(
    String? crc,
    String? md5,
    String? sha1,
    String systemId,
    ScreenScraperGame? game,
  ) {
    final key = _generateKey(crc, md5, sha1, systemId);
    _cache[key] = _CacheEntry(game: game, timestamp: DateTime.now());
  }

  /// Verifica si existe en cache (incluyendo resultados null/no encontrado)
  bool contains(String? crc, String? md5, String? sha1, String systemId) {
    final key = _generateKey(crc, md5, sha1, systemId);
    final entry = _cache[key];

    if (entry == null) return false;

    if (DateTime.now().difference(entry.timestamp) > maxAge) {
      _cache.remove(key);
      return false;
    }

    return true;
  }

  /// Limpia el cache
  void clear() => _cache.clear();

  /// Número de entradas en cache
  int get size => _cache.length;
}

class _CacheEntry {
  final ScreenScraperGame? game;
  final DateTime timestamp;

  _CacheEntry({required this.game, required this.timestamp});
}

// ============================================================================
// MODELOS DE DATOS
// ============================================================================

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
      throw ScreenScraperException(
        'Game not found in ScreenScraper',
        statusCode: 404,
      );
    }

    final jeu = response['jeu'];

    // 1. Identificación de Nombre (Preferencia: ss -> us -> eu -> wor -> first)
    String? officialName;
    if (jeu['noms'] != null && jeu['noms'] is List) {
      final noms = jeu['noms'] as List;
      final ssName = noms.firstWhere(
        (n) => n['region'] == 'ss',
        orElse: () => null,
      );
      final usName = noms.firstWhere(
        (n) => n['region'] == 'us',
        orElse: () => null,
      );
      final euName = noms.firstWhere(
        (n) => n['region'] == 'eu',
        orElse: () => null,
      );
      final worName = noms.firstWhere(
        (n) => n['region'] == 'wor',
        orElse: () => null,
      );
      officialName =
          (ssName ??
          usName ??
          euName ??
          worName ??
          (noms.isNotEmpty ? noms.first : {'text': 'Unknown'}))['text'];
    }

    // 2. Sinopsis (Preferencia: ES -> EN -> first)
    String? synopsis;
    if (jeu['synopsis'] != null && jeu['synopsis'] is List) {
      final syns = jeu['synopsis'] as List;
      final esSyn = syns.firstWhere(
        (s) => s['langue'] == 'es',
        orElse: () => null,
      );
      final enSyn = syns.firstWhere(
        (s) => s['langue'] == 'en',
        orElse: () => null,
      );
      synopsis =
          (esSyn ??
          enSyn ??
          (syns.isNotEmpty ? syns.first : {'text': ''}))['text'];
    }

    // 3. Media (imágenes)
    final Map<String, String> mediaUrls = {};
    if (jeu['medias'] != null && jeu['medias'] is List) {
      final List medias = jeu['medias'];

      final box2d = medias.firstWhere(
        (m) => m['type'] == 'box-2D',
        orElse: () => null,
      );
      if (box2d != null) mediaUrls['cover'] = box2d['url'];

      final box3d = medias.firstWhere(
        (m) => m['type'] == 'box-3D',
        orElse: () => null,
      );
      if (box3d != null) mediaUrls['cover_3d'] = box3d['url'];

      final fanart = medias.firstWhere(
        (m) => m['type'] == 'fanart',
        orElse: () => null,
      );
      if (fanart != null) mediaUrls['banner'] = fanart['url'];

      final wheel = medias.firstWhere(
        (m) => m['type'] == 'wheel',
        orElse: () => null,
      );
      if (wheel != null) mediaUrls['logo'] = wheel['url'];
    }

    // 4. Fecha de lanzamiento
    String? releaseDate;
    if (jeu['dates'] != null && jeu['dates'] is List) {
      final dates = jeu['dates'] as List;
      final usDate = dates.firstWhere(
        (d) => d['region'] == 'us',
        orElse: () => null,
      );
      final euDate = dates.firstWhere(
        (d) => d['region'] == 'eu',
        orElse: () => null,
      );
      releaseDate =
          (usDate ??
          euDate ??
          (dates.isNotEmpty ? dates.first : null))?['text'];
    }

    // 5. Desarrollador
    String? developer;
    if (jeu['developpeur'] != null && jeu['developpeur'] is Map) {
      developer = jeu['developpeur']['text'];
    }

    return ScreenScraperGame(
      name: officialName,
      system: jeu['systeme']?['text'],
      region: null,
      synopsis: synopsis,
      releaseDate: releaseDate,
      developer: developer,
      media: mediaUrls,
    );
  }
}

class ScreenScraperQuota {
  final int maxRequestsPerDay;
  final int requestsToday;
  final int maxRequestsPerMin;
  final int maxThreads;
  final int requestsKoToday; // Requests fallidos hoy

  ScreenScraperQuota({
    required this.maxRequestsPerDay,
    required this.requestsToday,
    required this.maxRequestsPerMin,
    required this.maxThreads,
    this.requestsKoToday = 0,
  });

  /// Requests disponibles hoy
  int get remainingToday => maxRequestsPerDay - requestsToday;

  /// Porcentaje de quota usada
  double get usagePercent => (requestsToday / maxRequestsPerDay) * 100;

  /// ¿Se puede hacer más requests hoy?
  bool get canMakeRequests => remainingToday > 0;

  factory ScreenScraperQuota.fromJson(Map<String, dynamic> json) {
    final user = json['response']?['ssuser'];
    if (user == null) throw ScreenScraperException('Invalid quota data');

    return ScreenScraperQuota(
      maxRequestsPerDay: int.parse(
        user['maxrequestsperday']?.toString() ?? '0',
      ),
      requestsToday: int.parse(user['requeststoday']?.toString() ?? '0'),
      maxRequestsPerMin: int.parse(
        user['maxrequestspermin']?.toString() ?? '0',
      ),
      maxThreads: int.parse(user['maxthreads']?.toString() ?? '1'),
      requestsKoToday: int.parse(user['requestskotoday']?.toString() ?? '0'),
    );
  }
}

// ============================================================================
// SERVICIO PRINCIPAL DE SCREENSCRAPER
// ============================================================================

class ScreenScraperService {
  static const String _baseUrl =
      'https://www.screenscraper.fr/api2/jeuInfos.php';
  static const String _userBaseUrl =
      'https://www.screenscraper.fr/api2/ssuserInfos.php';

  // Credenciales de desarrollador desde .env
  static String get _softName =>
      dotenv.env['SS_SOFT_NAME'] ?? 'LutrisGameStation';
  static String get _devId => dotenv.env['SS_DEV_ID'] ?? '';
  static String get _devPassword => dotenv.env['SS_DEV_PASSWORD'] ?? '';

  // Rate limiter y cache (singleton)
  static RateLimiter? _rateLimiter;
  static final ResponseCache _cache = ResponseCache();
  static ScreenScraperQuota? _lastKnownQuota;

  // Configuración de retry
  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 2);

  /// Verifica si las credenciales de desarrollador están configuradas
  static bool get hasDevCredentials =>
      _devId.isNotEmpty && _devPassword.isNotEmpty;

  /// Obtiene la quota actual (cacheada)
  static ScreenScraperQuota? get currentQuota => _lastKnownQuota;

  /// Headers para las peticiones
  static Map<String, String> get _headers => {
    'User-Agent': '$_softName/1.0 (Linux; Desktop)',
    'Accept': 'application/json',
  };

  /// Inicializa el rate limiter basado en la quota del usuario
  static Future<void> _ensureRateLimiter() async {
    if (_rateLimiter != null) return;

    // Obtener quota para configurar el rate limiter
    final quota = await getQuota();
    if (quota != null) {
      // Usar el 80% del máximo para tener margen de seguridad
      final safeLimit = (quota.maxRequestsPerMin * 0.8).floor();
      _rateLimiter = RateLimiter(
        maxRequestsPerMinute: safeLimit > 0 ? safeLimit : 1,
      );
      _lastKnownQuota = quota;
    } else {
      // Fallback conservador si no podemos obtener quota
      _rateLimiter = RateLimiter(maxRequestsPerMinute: 5);
    }
  }

  /// Obtiene información de quota del usuario
  static Future<ScreenScraperQuota?> getQuota() async {
    if (!hasDevCredentials) {
      print(
        '⚠️ ScreenScraper: Credenciales de desarrollador no configuradas en .env',
      );
      return null;
    }

    final ssid = await ConfigManager.getSSUser();
    final sspassword = await ConfigManager.getSSPassword();

    if (ssid.isEmpty || sspassword.isEmpty) return null;

    final uri = Uri.parse(_userBaseUrl).replace(
      queryParameters: {
        'devid': _devId,
        'devpassword': _devPassword,
        'softname': _softName,
        'ssid': ssid,
        'sspassword': sspassword,
        'output': 'json',
      },
    );

    try {
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['response']?['ssuser'] != null) {
          final quota = ScreenScraperQuota.fromJson(data);
          _lastKnownQuota = quota;
          return quota;
        }
      }

      _handleErrorResponse(response.statusCode, response.body);
      return null;
    } catch (e) {
      if (e is ScreenScraperException) rethrow;
      print('❌ Error obteniendo quota: $e');
      return null;
    }
  }

  /// Valida las credenciales del usuario
  static Future<bool> validateCredentials() async {
    if (!hasDevCredentials) return false;
    final quota = await getQuota();
    return quota != null;
  }

  /// Verifica si se puede iniciar un escaneo masivo
  static Future<({bool canProceed, String message, int? remainingRequests})>
  canStartMassiveScan(int numberOfRoms) async {
    if (!hasDevCredentials) {
      return (
        canProceed: false,
        message: 'Credenciales de desarrollador no configuradas',
        remainingRequests: null,
      );
    }

    final quota = await getQuota();
    if (quota == null) {
      return (
        canProceed: false,
        message: 'No se pudo verificar tu quota. Verifica tus credenciales.',
        remainingRequests: null,
      );
    }

    if (!quota.canMakeRequests) {
      return (
        canProceed: false,
        message:
            'Has excedido tu límite diario (${quota.requestsToday}/${quota.maxRequestsPerDay})',
        remainingRequests: 0,
      );
    }

    if (quota.remainingToday < numberOfRoms) {
      return (
        canProceed: true, // Permitir pero con advertencia
        message:
            'Solo tienes ${quota.remainingToday} requests disponibles para $numberOfRoms ROMs. Algunas no serán identificadas.',
        remainingRequests: quota.remainingToday,
      );
    }

    return (
      canProceed: true,
      message: 'OK - ${quota.remainingToday} requests disponibles',
      remainingRequests: quota.remainingToday,
    );
  }

  /// Maneja los códigos de error de la API
  static void _handleErrorResponse(int statusCode, String body) {
    switch (statusCode) {
      case 400:
        throw ScreenScraperException(
          'Petición inválida. Verifica los parámetros.',
          statusCode: 400,
        );
      case 401:
        throw ApiUnavailableException(
          'API temporalmente cerrada por saturación del servidor.',
          statusCode: 401,
        );
      case 403:
        throw AuthenticationException(
          'Credenciales incorrectas. Verifica tu usuario y contraseña.',
        );
      case 404:
        // No es un error, simplemente no se encontró
        return;
      case 423:
        throw ApiUnavailableException(
          'API caída temporalmente. Intenta más tarde.',
          statusCode: 423,
        );
      case 426:
        throw AppBlockedException();
      case 429:
        throw TooManyRequestsException();
      case 430:
        throw QuotaExceededException();
      case 431:
        throw TooManyInvalidRomsException();
      default:
        if (statusCode >= 500) {
          throw ApiUnavailableException(
            'Error del servidor ScreenScraper ($statusCode)',
            statusCode: statusCode,
          );
        }
        throw ScreenScraperException(
          'Error desconocido: $statusCode',
          statusCode: statusCode,
        );
    }
  }

  /// Realiza un request con retry y backoff exponencial
  static Future<http.Response> _requestWithRetry(Uri uri) async {
    await _ensureRateLimiter();

    int attempt = 0;
    Duration delay = _initialRetryDelay;

    while (true) {
      attempt++;

      // Esperar por el rate limiter
      await _rateLimiter!.acquire();

      try {
        final response = await http.get(uri, headers: _headers);

        // Si es exitoso o es un error no reintentable, retornar
        if (response.statusCode == 200 || response.statusCode == 404) {
          return response;
        }

        // Verificar si debemos reintentar
        if (attempt >= _maxRetries) {
          return response; // Retornar la respuesta para que se maneje el error
        }

        // Solo reintentar en errores específicos
        if (response.statusCode == 429 ||
            response.statusCode == 401 ||
            response.statusCode == 423 ||
            response.statusCode >= 500) {
          print(
            '⚠️ Error ${response.statusCode}, reintentando en ${delay.inSeconds}s (intento $attempt/$_maxRetries)',
          );
          await Future.delayed(delay);
          delay *= 2; // Backoff exponencial
          continue;
        }

        return response;
      } catch (e) {
        if (e is SocketException || e is TimeoutException) {
          if (attempt >= _maxRetries) rethrow;
          print(
            '⚠️ Error de conexión, reintentando en ${delay.inSeconds}s (intento $attempt/$_maxRetries)',
          );
          await Future.delayed(delay);
          delay *= 2;
          continue;
        }
        rethrow;
      }
    }
  }

  /// Identifica un juego por sus hashes
  static Future<ScreenScraperGame?> identifyGameByHash({
    String? crc,
    String? md5,
    String? sha1,
    int? fileSize,
    String? fileName,
    String systemId = '57',
  }) async {
    // Verificar credenciales
    if (!hasDevCredentials) {
      throw AuthenticationException(
        'Credenciales de desarrollador no configuradas. Verifica el archivo .env',
      );
    }

    // Verificar cache primero
    if (_cache.contains(crc, md5, sha1, systemId)) {
      final cached = _cache.get(crc, md5, sha1, systemId);
      print('📦 Cache hit para ${fileName ?? 'ROM'}');
      return cached;
    }

    final ssid = await ConfigManager.getSSUser();
    final sspassword = await ConfigManager.getSSPassword();

    final queryParams = {
      'devid': _devId,
      'devpassword': _devPassword,
      'softname': _softName,
      'ssid': ssid,
      'sspassword': sspassword,
      'output': 'json',
      'romtype': 'rom',
      'systemeid': systemId,
    };

    // Enviar los 3 hashes como recomienda la documentación
    if (crc != null) queryParams['crc'] = crc.toLowerCase();
    if (md5 != null) queryParams['md5'] = md5.toLowerCase();
    if (sha1 != null) queryParams['sha1'] = sha1.toLowerCase();
    if (fileSize != null) queryParams['romtaille'] = fileSize.toString();
    if (fileName != null) queryParams['romnom'] = fileName;

    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

    try {
      final response = await _requestWithRetry(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final game = ScreenScraperGame.fromJson(data);

        // Guardar en cache
        _cache.set(crc, md5, sha1, systemId, game);

        return game;
      } else if (response.statusCode == 404) {
        // Guardar en cache que no se encontró (evita búsquedas repetidas)
        _cache.set(crc, md5, sha1, systemId, null);
        return null;
      } else {
        _handleErrorResponse(response.statusCode, response.body);
        return null;
      }
    } on ScreenScraperException {
      rethrow;
    } catch (e) {
      print('❌ Error identificando juego: $e');
      rethrow;
    }
  }

  /// Identifica un archivo ROM
  static Future<ScreenScraperGame?> identifyFile(
    String filePath, {
    String? systemId,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw ScreenScraperException('Archivo no encontrado: $filePath');
      }

      final size = await file.length();
      final name = p.basename(filePath);
      final hashes = await HashService.calculateHashes(filePath);

      return await identifyGameByHash(
        sha1: hashes.sha1,
        md5: hashes.md5,
        crc: hashes.crc32,
        fileSize: size,
        fileName: name,
        systemId: systemId ?? '57',
      );
    } catch (e) {
      print('❌ Error identificando archivo $filePath: $e');
      rethrow;
    }
  }

  /// Limpia el cache de respuestas
  static void clearCache() {
    _cache.clear();
    print('🗑️ Cache de ScreenScraper limpiado');
  }

  /// Resetea el rate limiter (útil si cambia la quota)
  static void resetRateLimiter() {
    _rateLimiter = null;
  }

  /// Obtiene estadísticas del servicio
  static Map<String, dynamic> getStats() {
    return {
      'cacheSize': _cache.size,
      'rateLimiterConfigured': _rateLimiter != null,
      'availableRequestsNow': _rateLimiter?.availableRequests ?? 0,
      'lastKnownQuota': _lastKnownQuota != null
          ? {
              'requestsToday': _lastKnownQuota!.requestsToday,
              'maxPerDay': _lastKnownQuota!.maxRequestsPerDay,
              'remaining': _lastKnownQuota!.remainingToday,
              'usagePercent': _lastKnownQuota!.usagePercent.toStringAsFixed(1),
            }
          : null,
    };
  }
}
