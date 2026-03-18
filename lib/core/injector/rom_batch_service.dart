import 'dart:io';
import 'package:path/path.dart' as p;
import '../../platforms/platform_registry.dart';
import '../lutris/rom_cache_repository.dart';
import '../metadata/screenscraper_service.dart';

/// Modelo para un archivo ROM seleccionado para procesamiento
class RomBatchItem {
  final String filePath;
  final String platformKey;
  final bool isSelected;
  final String? customName;
  final bool needsIdentification;

  RomBatchItem({
    required this.filePath,
    required this.platformKey,
    this.isSelected = true,
    this.customName,
    this.needsIdentification = false,
  });

  String get displayName {
    return customName ?? p.basenameWithoutExtension(filePath);
  }

  String get fileName => p.basename(filePath);
  String get extension => p.extension(filePath);

  RomBatchItem copyWith({
    String? filePath,
    String? platformKey,
    bool? isSelected,
    String? customName,
    bool? needsIdentification,
  }) {
    return RomBatchItem(
      filePath: filePath ?? this.filePath,
      platformKey: platformKey ?? this.platformKey,
      isSelected: isSelected ?? this.isSelected,
      customName: customName ?? this.customName,
      needsIdentification: needsIdentification ?? this.needsIdentification,
    );
  }
}

/// Estadísticas de procesamiento en batch
class BatchProcessStats {
  final int totalItems;
  final int processed;
  final int identified;
  final int cached;
  final int failed;
  final int skipped;

  BatchProcessStats({
    required this.totalItems,
    required this.processed,
    required this.identified,
    required this.cached,
    required this.failed,
    required this.skipped,
  });

  double get progressPercent => totalItems > 0 ? processed / totalItems : 0.0;

  @override
  String toString() {
    return 'Procesados: $processed/$totalItems | '
        'Identificados: $identified | '
        'Cache hits: $cached | '
        'Errores: $failed | '
        'Saltados: $skipped';
  }
}

/// Servicio para operaciones en batch con ROMs
class RomBatchService {
  final RomCacheRepository _cache;
  final void Function(String message, double? progress)? _progressCallback;

  RomBatchService({
    void Function(String message, double? progress)? progressCallback,
  }) : _cache = RomCacheRepository(),
       _progressCallback = progressCallback;

  void _log(String message, [double? progress]) {
    if (_progressCallback != null) {
      _progressCallback!(message, progress);
    } else {
      print(message);
    }
  }

  /// Escanea múltiples carpetas y devuelve items batch
  List<RomBatchItem> scanFolders(Map<String, String> foldersByPlatform) {
    final List<RomBatchItem> items = [];

    for (final entry in foldersByPlatform.entries) {
      final platformKey = entry.key;
      final folderPath = entry.value;

      final platformInfo = PlatformRegistry.getPlatform(platformKey);
      if (platformInfo == null) {
        _log("⚠️ Plataforma no soportada: $platformKey");
        continue;
      }

      final folder = Directory(folderPath);
      if (!folder.existsSync()) {
        _log("⚠️ Carpeta no existe: $folderPath");
        continue;
      }

      final files = folder.listSync().whereType<File>().where((f) {
        final ext = p.extension(f.path).toLowerCase();
        return platformInfo.extensions.contains(ext);
      }).toList();

      for (final file in files) {
        // Verificar si necesita identificación (no está en cache o cache expiró)
        final cached = _cache.shouldProcessRom(file.path);
        final needsId = cached == null || !cached.isIdentified;

        items.add(
          RomBatchItem(
            filePath: file.path,
            platformKey: platformKey,
            needsIdentification: needsId,
            customName: cached?.identifiedName,
          ),
        );
      }
    }

    _log(
      "📦 Encontrados ${items.length} ROMs en ${foldersByPlatform.length} plataformas",
    );
    return items;
  }

  /// Filtra items duplicados por plataforma manteniendo solo el de mayor prioridad
  List<RomBatchItem> filterDuplicates(List<RomBatchItem> items) {
    final Map<String, List<RomBatchItem>> groupedByPlatform = {};

    // Agrupar por plataforma
    for (final item in items) {
      groupedByPlatform.putIfAbsent(item.platformKey, () => []).add(item);
    }

    final List<RomBatchItem> filtered = [];

    for (final entry in groupedByPlatform.entries) {
      final platformKey = entry.key;
      final platformItems = entry.value;
      final platformInfo = PlatformRegistry.getPlatform(platformKey);

      if (platformInfo == null) continue;

      // Agrupar por nombre base (sin extensión)
      final Map<String, List<RomBatchItem>> groupedByName = {};
      for (final item in platformItems) {
        final baseName = p.basenameWithoutExtension(item.filePath);
        groupedByName.putIfAbsent(baseName, () => []).add(item);
      }

      // Para cada grupo de archivos con el mismo nombre, elegir el de mayor prioridad
      for (final nameGroup in groupedByName.values) {
        if (nameGroup.length == 1) {
          filtered.add(nameGroup.first);
        } else {
          nameGroup.sort((a, b) {
            final extA = p.extension(a.filePath).toLowerCase();
            final extB = p.extension(b.filePath).toLowerCase();
            final priorityA = platformInfo.getExtensionPriority(extA);
            final priorityB = platformInfo.getExtensionPriority(extB);
            return priorityA.compareTo(priorityB);
          });

          filtered.add(nameGroup.first);
          _log(
            "📁 ${p.basenameWithoutExtension(nameGroup.first.filePath)}: "
            "usando ${nameGroup.first.extension} "
            "(ignorando: ${nameGroup.skip(1).map((i) => i.extension).join(', ')})",
          );
        }
      }
    }

    return filtered;
  }

  /// Verifica quota disponible antes de iniciar procesamiento en batch
  Future<({bool canProceed, String message, int? remainingRequests})>
  checkQuotaForBatch(List<RomBatchItem> selectedItems) async {
    final itemsNeedingIdentification = selectedItems
        .where((item) => item.isSelected && item.needsIdentification)
        .length;

    if (itemsNeedingIdentification == 0) {
      return (
        canProceed: true,
        message: 'Ningún item requiere identificación - usando solo cache',
        remainingRequests: null,
      );
    }

    return await ScreenScraperService.canStartMassiveScan(
      itemsNeedingIdentification,
    );
  }

  /// Procesa múltiples ROMs en batch con identificación
  Future<BatchProcessStats> processBatch(
    List<RomBatchItem> items, {
    bool useHighPrecision = false,
    bool reuseIdentification = true,
  }) async {
    final selectedItems = items.where((item) => item.isSelected).toList();
    final totalItems = selectedItems.length;

    if (totalItems == 0) {
      _log("⚠️ No hay items seleccionados para procesar");
      return BatchProcessStats(
        totalItems: 0,
        processed: 0,
        identified: 0,
        cached: 0,
        failed: 0,
        skipped: 0,
      );
    }

    _log("🚀 Procesando $totalItems ROMs en batch...");

    int processed = 0;
    int identified = 0;
    int cached = 0;
    int failed = 0;
    int skipped = 0;

    for (int i = 0; i < selectedItems.length; i++) {
      final item = selectedItems[i];
      final progress = (i + 1) / totalItems;

      try {
        // Verificar si el archivo existe
        final file = File(item.filePath);
        if (!file.existsSync()) {
          _log("⏩ Archivo no existe: ${item.fileName}");
          skipped++;
          processed++;
          _log("Progreso: ${(progress * 100).toInt()}%", progress);
          continue;
        }

        final platformInfo = PlatformRegistry.getPlatform(item.platformKey);
        final screenScraperId = platformInfo?.screenScraperId;
        if (screenScraperId == null) {
          _log("⏩ Plataforma sin soporte ScreenScraper: ${item.platformKey}");
          skipped++;
          processed++;
          _log("Progreso: ${(progress * 100).toInt()}%", progress);
          continue;
        }

        // Verificar cache
        final cachedEntry = reuseIdentification
            ? _cache.shouldProcessRom(item.filePath)
            : null;

        if (cachedEntry != null && cachedEntry.isIdentified) {
          _log(
            "📦 Cache hit: ${cachedEntry.identifiedName ?? item.displayName}",
          );
          cached++;
          processed++;
          _log("Progreso: ${(progress * 100).toInt()}%", progress);
          continue;
        }

        // Identificar con ScreenScraper si se requiere alta precisión
        if (useHighPrecision) {
          _log("🔍 Identificando: ${item.displayName}...");

          final stat = file.statSync();
          final identifiedGame = await ScreenScraperService.identifyFile(
            item.filePath,
            systemId: screenScraperId,
          );

          String finalName = item.displayName;
          bool wasIdentified = false;

          if (identifiedGame?.name != null) {
            finalName = identifiedGame!.name!;
            wasIdentified = true;
            identified++;
            _log("✨ Identificado: $finalName");
          } else {
            _log("⚠️ No identificado: ${item.displayName}");
          }

          // Guardar en cache
          if (reuseIdentification) {
            _cache.cacheRomInfo(
              filePath: item.filePath,
              fileSize: stat.size,
              lastModified: stat.modified,
              identifiedName: finalName,
              systemId: screenScraperId,
              isIdentified: wasIdentified,
            );
          }
        } else {
          // Solo guardar en cache como no identificado
          if (reuseIdentification) {
            final stat = file.statSync();
            _cache.cacheRomInfo(
              filePath: item.filePath,
              fileSize: stat.size,
              lastModified: stat.modified,
              identifiedName: item.displayName,
              systemId: screenScraperId,
              isIdentified: false,
            );
          }
        }

        processed++;
      } catch (e) {
        _log("❌ Error procesando ${item.displayName}: $e");
        failed++;
        processed++;
      }

      _log("Progreso: ${(progress * 100).toInt()}%", progress);
    }

    final stats = BatchProcessStats(
      totalItems: totalItems,
      processed: processed,
      identified: identified,
      cached: cached,
      failed: failed,
      skipped: skipped,
    );

    _log("🎉 Procesamiento batch completado: $stats", 1.0);
    return stats;
  }

  /// Obtiene estadísticas del cache
  Map<String, dynamic> getCacheStats() => _cache.getStats();

  /// Limpia el cache
  void clearCache() => _cache.clearCache();

  /// Cierra recursos
  void dispose() => _cache.dispose();
}
