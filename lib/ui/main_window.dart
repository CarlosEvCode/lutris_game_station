import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../platforms/platform_registry.dart';
import '../core/lutris/lutris_detector.dart';
import '../core/injector/rom_injector.dart';
import '../core/metadata/metadata_downloader.dart';
import '../core/metadata/screenscraper_service.dart';
import '../core/lutris/config_manager.dart';
import '../core/lutris/rom_cache_repository.dart';
import 'visual_manager_screen.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class InjectionItem {
  final String filePath;
  String displayName;
  bool isSelected;
  bool wasManuallyEdited;

  InjectionItem({
    required this.filePath,
    required this.displayName,
    this.isSelected = true,
    this.wasManuallyEdited = false,
  });
}

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  int _currentIndex = 0;
  LutrisDetector? _detector;
  Map<String, String?>? _lutrisPaths;
  List<String> _availableLutrisModes = [];

  PlatformInfo? _selectedPlatform;
  List<String> _selectedExtensions = [];
  String _romFolder = '';
  String _apiKey = '';
  String _ssUser = '';
  String _ssPassword = '';

  List<InjectionItem> _previewItems = [];
  bool _isScanning = false;
  bool _cleanOldGames = true;
  bool _useHighPrecision = false;
  bool _reuseIdentification =
      true; // Nuevo toggle para reutilizar identificación
  bool _isRecursive = false;
  bool _isProcessing = false;

  // Estadísticas de API (para widget discreto)
  bool _showApiStats = false;
  Map<String, dynamic>? _apiStats;

  String _logText = '';
  double _progress = 0.0;

  final ScrollController _logScrollController = ScrollController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _ssUserController = TextEditingController();
  final TextEditingController _ssPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _detectLutris();
    _loadPersistedConfig();
    final platforms = PlatformRegistry.getAllPlatforms();
    if (platforms.isNotEmpty) {
      _onPlatformChanged(platforms.first);
    }
  }

  Future<void> _loadPersistedConfig() async {
    final key = await ConfigManager.getApiKey();
    final ssUser = await ConfigManager.getSSUser();
    final ssPass = await ConfigManager.getSSPassword();

    setState(() {
      _apiKey = key;
      _apiKeyController.text = key;
      _ssUser = ssUser;
      _ssUserController.text = ssUser;
      _ssPassword = ssPass;
      _ssPasswordController.text = ssPass;
    });

    if (key.isNotEmpty) _log("API Key cargada.");
    if (ssUser.isNotEmpty) _log("ScreenScraper configurado.");
  }

  void _onPlatformChanged(PlatformInfo? val) async {
    setState(() {
      _selectedPlatform = val;
      if (val != null) {
        _selectedExtensions = List.from(val.extensions);
        _previewItems = [];
      }
    });

    if (val != null) {
      final savedPath = await ConfigManager.getPlatformPath(val.platformId);
      if (savedPath.isNotEmpty) {
        setState(() {
          _romFolder = savedPath;
        });
        _scanFolder();
      }
    }
  }

  void _detectLutris() {
    try {
      _detector = LutrisDetector(interactive: false);
      _lutrisPaths = _detector?.getPaths();
      _availableLutrisModes = _detector?.getAvailableModes() ?? [];

      if (_lutrisPaths?['mode'] == null || _lutrisPaths!['mode']!.isEmpty) {
        _log("No se detectó Lutris instalado.");
      } else {
        _log("Lutris detectado: ${_lutrisPaths!['mode']}");
      }
    } catch (e) {
      _log("Error detectando Lutris: $e");
    }
  }

  void _log(String message, [double? progress]) {
    setState(() {
      _logText += "$message\n";
      if (progress != null) {
        _progress = progress;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearLog() {
    setState(() {
      _logText = '';
      _progress = 0.0;
    });
  }

  void _switchLutrisMode(String newMode) {
    if (_detector == null || _lutrisPaths?['mode'] == newMode) return;

    setState(() {
      _detector!.setMode(newMode);
      _lutrisPaths = _detector!.getPaths();
    });

    _log("Cambiado a: $newMode");
  }

  void _editItemName(InjectionItem item) {
    final controller = TextEditingController(text: item.displayName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Nombre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre en Lutris',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                item.displayName = controller.text.trim();
                item.wasManuallyEdited = true;
              });
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showQuotaWarningDialog(int available, int total) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text('Quota Limitada', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Solo tienes $available requests para $total ROMs.\n\n'
          'Las primeras $available serán identificadas por ScreenScraper.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _browseFolder() async {
    final String? folderPath = await getDirectoryPath();
    if (folderPath != null) {
      setState(() {
        _romFolder = folderPath;
        _previewItems = [];
      });
      if (_selectedPlatform != null) {
        await ConfigManager.savePlatformPath(
          _selectedPlatform!.platformId,
          folderPath,
        );
      }
      _scanFolder();
    }
  }

  Future<void> _scanFolder() async {
    if (_romFolder.isEmpty || _selectedPlatform == null) return;

    setState(() {
      _isScanning = true;
      _previewItems = [];
    });

    try {
      final dir = Directory(_romFolder);
      final entities = await dir.list(recursive: _isRecursive).toList();

      final List<File> matchingFiles = [];
      for (var entity in entities) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (_selectedExtensions.contains(ext)) {
            matchingFiles.add(entity);
          }
        }
      }

      final filteredFiles = RomInjector.filterDuplicatesByPriority(
        matchingFiles,
        _selectedPlatform!,
        (msg, [progress]) => _log(msg),
      );

      final List<InjectionItem> detected = [];
      for (var file in filteredFiles) {
        detected.add(
          InjectionItem(
            filePath: file.path,
            displayName: p.basenameWithoutExtension(file.path),
          ),
        );
      }

      setState(() {
        _previewItems = detected;
      });
      _log("${detected.length} juegos encontrados.");
    } catch (e) {
      _log("Error: $e");
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  DateTime? _lastQuotaFetch;
  static const Duration _quotaCacheDuration = Duration(minutes: 5);

  Future<void> _refreshApiStats({bool force = false}) async {
    final stats = ScreenScraperService.getStats();

    // Obtener estadísticas del cache ROM
    Map<String, dynamic> romCacheStats = {};
    try {
      final romCache = RomCacheRepository();
      romCacheStats = romCache.getStats();
      romCache.dispose();
    } catch (e) {
      romCacheStats = {'totalEntries': 0, 'identifiedEntries': 0};
    }

    ScreenScraperQuota? quota;
    final now = DateTime.now();
    final shouldFetchQuota =
        force ||
        _lastQuotaFetch == null ||
        now.difference(_lastQuotaFetch!) > _quotaCacheDuration;

    if (shouldFetchQuota) {
      quota = await ScreenScraperService.getQuota();
      _lastQuotaFetch = DateTime.now();
    } else {
      quota = ScreenScraperService.currentQuota;
    }

    setState(() {
      _apiStats = {
        ...stats,
        ...romCacheStats,
        'requestsToday':
            quota?.requestsToday ?? stats['lastKnownQuota']?['requestsToday'],
        'maxRequestsPerDay':
            quota?.maxRequestsPerDay ?? stats['lastKnownQuota']?['maxPerDay'],
        'remainingToday':
            quota?.remainingToday ?? stats['lastKnownQuota']?['remaining'],
        'lastQuotaFetch': _lastQuotaFetch?.toIso8601String(),
      };
    });
  }

  void _showConfigDialog() {
    _apiKeyController.text = _apiKey;
    _ssUserController.text = _ssUser;
    _ssPasswordController.text = _ssPassword;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text('Configuración', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SteamGridDB API Key:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'API Key...',
                      isDense: true,
                      prefixIcon: const Icon(Icons.vpn_key, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ScreenScraper:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _ssUserController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Usuario',
                      isDense: true,
                      prefixIcon: const Icon(Icons.person, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ssPasswordController,
                    obscureText: true,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Contraseña',
                      isDense: true,
                      prefixIcon: const Icon(Icons.lock, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        await ConfigManager.saveSSCredentials(
                          _ssUserController.text.trim(),
                          _ssPasswordController.text,
                        );
                        final isValid =
                            await ScreenScraperService.validateCredentials();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isValid
                                    ? 'Credenciales válidas'
                                    : 'Credenciales incorrectas',
                              ),
                              backgroundColor: isValid
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.verified_user, size: 16),
                      label: const Text(
                        'Validar',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final newKey = _apiKeyController.text.trim();
                final newUser = _ssUserController.text.trim();
                final newPass = _ssPasswordController.text;

                setState(() {
                  _apiKey = newKey;
                  _ssUser = newUser;
                  _ssPassword = newPass;
                });

                await ConfigManager.saveApiKey(newKey);
                await ConfigManager.saveSSCredentials(newUser, newPass);

                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startProcess(String action) async {
    if (_isProcessing) return;
    if (_lutrisPaths == null) {
      _log("Rutas de Lutris no detectadas.");
      return;
    }
    if (_selectedPlatform == null) {
      _log("Selecciona una plataforma.");
      return;
    }
    if ((action == 'inject' || action == 'full') && _romFolder.isEmpty) {
      _log("Selecciona una carpeta de ROMs.");
      return;
    }
    if ((action == 'inject' || action == 'full') &&
        _selectedExtensions.isEmpty) {
      _log("Selecciona al menos una extensión.");
      return;
    }
    if ((action == 'metadata' || action == 'full') && _apiKey.isEmpty) {
      _log("Configura la API Key de SteamGridDB.");
      _showConfigDialog();
      return;
    }

    // Verificar quota si Alta Precisión está activada
    if (_useHighPrecision && (action == 'inject' || action == 'full')) {
      final selectedCount = _previewItems.where((i) => i.isSelected).length;

      if (_ssUser.isEmpty || _ssPassword.isEmpty) {
        _log("Alta Precisión requiere credenciales de ScreenScraper.");
        _showConfigDialog();
        return;
      }

      _log("Verificando quota...");
      final quotaCheck = await ScreenScraperService.canStartMassiveScan(
        selectedCount,
      );

      if (!quotaCheck.canProceed) {
        _log("Error: ${quotaCheck.message}");
        return;
      }

      if (quotaCheck.remainingRequests != null &&
          quotaCheck.remainingRequests! < selectedCount) {
        _log("Advertencia: ${quotaCheck.message}");

        final shouldContinue = await _showQuotaWarningDialog(
          quotaCheck.remainingRequests!,
          selectedCount,
        );

        if (!shouldContinue) {
          _log("Operación cancelada.");
          return;
        }
      } else {
        _log("Quota OK: ${quotaCheck.remainingRequests} disponibles");
      }
    }

    setState(() {
      _isProcessing = true;
      _clearLog();
    });

    try {
      if (action == 'inject' || action == 'full') {
        final selectedFiles = _previewItems
            .where((item) => item.isSelected)
            .map((item) => File(item.filePath))
            .toList();

        final Map<String, String> customNames = {
          for (var item in _previewItems.where(
            (i) => i.isSelected && i.wasManuallyEdited,
          ))
            item.filePath: item.displayName,
        };

        if (selectedFiles.isEmpty && _previewItems.isNotEmpty) {
          _log("No hay archivos seleccionados.");
          setState(() => _isProcessing = false);
          return;
        }

        final injector = RomInjector(
          lutrisPaths: _lutrisPaths!,
          platformKey: _selectedPlatform!.platformId,
          romFolder: _romFolder,
          customExtensions: _selectedExtensions,
          progressCallback: (msg, prog) => _log(msg, prog),
        );

        await injector.injectRoms(
          cleanOld: _cleanOldGames,
          useHighPrecision: _useHighPrecision,
          reuseIdentification: _reuseIdentification,
          customFiles: selectedFiles.isNotEmpty ? selectedFiles : null,
          customNames: customNames,
        );
      }

      if (action == 'metadata' || action == 'full') {
        final downloader = MetadataDownloader(
          lutrisPaths: _lutrisPaths!,
          apiKey: _apiKey,
          runner: _selectedPlatform!.runner,
          progressCallback: (msg, prog) => _log(msg, prog),
        );
        await downloader.downloadMetadata(skipExisting: true);
      }

      // Actualizar estadísticas después de procesar
      await _refreshApiStats();
    } catch (e) {
      _log("Error: $e");
    } finally {
      setState(() {
        _isProcessing = false;
        _progress = 1.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lutris Game Station',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        toolbarHeight: 48,
        actions: [
          _buildLutrisSelector(),
          IconButton(
            icon: const Icon(Icons.settings, size: 20),
            onPressed: _showConfigDialog,
            tooltip: 'Configuración',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        height: 56,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.flash_on, size: 20),
            label: 'Inyector',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view, size: 20),
            label: 'Gestor Visual',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildInjectorView();
      case 1:
        return _buildVisualManagerView();
      default:
        return _buildInjectorView();
    }
  }

  Widget _buildLutrisSelector() {
    final currentMode = _lutrisPaths != null
        ? _lutrisPaths!['mode']!
        : "No detectado";
    final isDetected = _lutrisPaths != null;

    if (_availableLutrisModes.length <= 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.computer,
              size: 14,
              color: isDetected ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 6),
            Text(
              currentMode,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Cambiar versión de Lutris',
      onSelected: _switchLutrisMode,
      offset: const Offset(0, 40),
      itemBuilder: (context) => _availableLutrisModes
          .map(
            (mode) => PopupMenuItem(
              value: mode,
              child: Row(
                children: [
                  Icon(
                    Icons.check,
                    size: 16,
                    color: currentMode == mode
                        ? Colors.green
                        : Colors.transparent,
                  ),
                  const SizedBox(width: 8),
                  Text(mode, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_horiz, size: 14, color: Colors.blue),
            const SizedBox(width: 6),
            Text(
              currentMode,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 14, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualManagerView() {
    if (_lutrisPaths == null) {
      return const Center(child: Text("Lutris no detectado."));
    }
    return VisualManagerScreen(
      lutrisPaths: _lutrisPaths!,
      apiKey: _apiKey,
      initialPlatformId: _selectedPlatform?.platformId,
    );
  }

  // ============================================================================
  // NUEVO DISEÑO: Layout de 2 columnas para escritorio
  // ============================================================================

  Widget _buildInjectorView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Si la pantalla es muy angosta, usar layout vertical
        if (constraints.maxWidth < 800) {
          return _buildInjectorViewMobile();
        }
        return _buildInjectorViewDesktop();
      },
    );
  }

  Widget _buildInjectorViewDesktop() {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ===== COLUMNA IZQUIERDA: Configuración =====
        SizedBox(
          width: 320,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildConfigSection(),
                  const SizedBox(height: 16),
                  _buildApiStatsWidget(),
                ],
              ),
            ),
          ),
        ),

        // ===== COLUMNA DERECHA: Preview + Log + Acciones =====
        Expanded(
          child: Column(
            children: [
              // Lista de ROMs (expandible)
              Expanded(flex: 3, child: _buildPreviewPanel()),
              // Log y progreso
              Expanded(flex: 2, child: _buildLogPanel()),
              // Botones de acción
              _buildActionBar(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInjectorViewMobile() {
    // Fallback para pantallas pequeñas (tablet/móvil)
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildConfigSection(),
          const SizedBox(height: 16),
          SizedBox(height: 300, child: _buildPreviewPanel()),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: _buildLogPanel()),
          const SizedBox(height: 16),
          _buildActionBar(),
        ],
      ),
    );
  }

  // ============================================================================
  // SECCIÓN DE CONFIGURACIÓN (Columna izquierda)
  // ============================================================================

  Widget _buildConfigSection() {
    final platforms = PlatformRegistry.getAllPlatforms();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Plataforma
        const Text(
          'Plataforma',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<PlatformInfo>(
          value: _selectedPlatform,
          items: platforms
              .map(
                (p) => DropdownMenuItem(
                  value: p,
                  child: Text(
                    p.platformName,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              )
              .toList(),
          onChanged: _isProcessing ? null : _onPlatformChanged,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.sports_esports, size: 18),
          ),
        ),

        const SizedBox(height: 16),

        // Carpeta de ROMs
        const Text(
          'Carpeta de ROMs',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Text(
                  _romFolder.isEmpty ? 'Sin seleccionar...' : _romFolder,
                  style: TextStyle(
                    fontSize: 11,
                    color: _romFolder.isEmpty ? Colors.grey : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isProcessing ? null : _browseFolder,
              icon: const Icon(Icons.folder_open, size: 18),
              tooltip: 'Buscar carpeta',
              style: IconButton.styleFrom(
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Extensiones (compactas)
        const Text(
          'Extensiones',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(height: 6),
        if (_selectedPlatform != null)
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _selectedPlatform!.extensions.map((ext) {
              final isSelected = _selectedExtensions.contains(ext);
              return FilterChip(
                label: Text(ext, style: const TextStyle(fontSize: 10)),
                selected: isSelected,
                onSelected: _isProcessing
                    ? null
                    : (selected) {
                        setState(() {
                          if (selected) {
                            _selectedExtensions.add(ext);
                          } else {
                            _selectedExtensions.remove(ext);
                          }
                        });
                      },
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        // Opciones (checkboxes compactos)
        _buildCompactCheckbox(
          'Limpiar juegos existentes',
          'Borra entradas previas de este runner',
          _cleanOldGames,
          (val) => setState(() => _cleanOldGames = val ?? false),
        ),
        _buildCompactCheckbox(
          'Alta Precisión',
          'Identificar por hash (ScreenScraper)',
          _useHighPrecision,
          (val) => setState(() => _useHighPrecision = val ?? false),
          icon: Icons.fingerprint,
          iconColor: _useHighPrecision ? Colors.teal : null,
        ),
        if (_useHighPrecision)
          _buildCompactCheckbox(
            'Reutilizar identificación previa',
            'Evitar recalcular hashes ya identificados',
            _reuseIdentification,
            (val) => setState(() => _reuseIdentification = val ?? false),
            icon: Icons.cached,
            iconColor: _reuseIdentification ? Colors.orange : null,
          ),
        _buildCompactCheckbox(
          'Escaneo recursivo',
          'Incluir subcarpetas',
          _isRecursive,
          (val) {
            setState(() => _isRecursive = val ?? false);
            _scanFolder();
          },
          icon: Icons.folder_copy,
          iconColor: _isRecursive ? Colors.blue : null,
        ),
      ],
    );
  }

  Widget _buildCompactCheckbox(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool?> onChanged, {
    IconData? icon,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: _isProcessing ? null : () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: value,
                onChanged: _isProcessing ? null : onChanged,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor ?? Colors.grey),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // WIDGET DE ESTADÍSTICAS DE API (discreto, expandible)
  // ============================================================================

  Widget _buildApiStatsWidget() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () async {
          if (!_showApiStats) {
            await _refreshApiStats();
          }
          setState(() => _showApiStats = !_showApiStats);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _showApiStats ? Icons.analytics : Icons.analytics_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        const Text(
                          'API Stats',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        if (_showApiStats)
                          IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              size: 14,
                              color: Colors.grey,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            tooltip: 'Actualizar cuota',
                            onPressed: () => _refreshApiStats(force: true),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _showApiStats ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
              if (_showApiStats && _apiStats != null) ...[
                const SizedBox(height: 12),
                _buildStatRow(
                  'Requests hoy',
                  '${_apiStats!['requestsToday'] ?? '?'}/${_apiStats!['maxRequestsPerDay'] ?? '?'}',
                ),
                if (_apiStats!['lastQuotaFetch'] != null)
                  _buildStatRow(
                    'Quota actualizada',
                    _apiStats!['lastQuotaFetch']!
                        .toString()
                        .replaceFirst('T', ' ')
                        .split('.')
                        .first,
                  ),
                _buildStatRow(
                  'Cache RAM hits',
                  '${_apiStats!['memoryCacheHits'] ?? 0}',
                ),
                _buildStatRow(
                  'Cache disco hits',
                  '${_apiStats!['diskCacheHits'] ?? 0}',
                ),
                _buildStatRow(
                  'Fallos registrados',
                  '${_apiStats!['failedLookups'] ?? 0}',
                ),
                _buildStatRow(
                  'Cache RAM size',
                  '${_apiStats!['cacheSize'] ?? 0}',
                ),
                _buildStatRow(
                  'Entradas disco',
                  '${_apiStats!['diskCacheEntries'] ?? 0}',
                ),
                _buildStatRow(
                  'Requests/min disponibles',
                  '${_apiStats!['availableRequestsNow'] ?? 0}',
                ),
                const Divider(height: 16, color: Colors.grey),
                _buildStatRow(
                  'ROMs en cache',
                  '${_apiStats!['totalEntries'] ?? 0}',
                ),
                _buildStatRow(
                  'ROMs identificadas',
                  '${_apiStats!['identifiedEntries'] ?? 0}',
                ),
              ],
              if (_showApiStats && _apiStats == null) ...[
                const SizedBox(height: 8),
                const Text(
                  'No hay datos disponibles',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // PANEL DE PREVIEW (Lista de ROMs)
  // ============================================================================

  Widget _buildPreviewPanel() {
    final selectedCount = _previewItems.where((i) => i.isSelected).length;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.list, size: 16),
                const SizedBox(width: 8),
                Text(
                  'ROMs detectadas',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '$selectedCount/${_previewItems.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                _buildMiniButton('Todos', () {
                  setState(() {
                    for (var item in _previewItems) {
                      item.isSelected = true;
                    }
                  });
                }),
                const SizedBox(width: 4),
                _buildMiniButton('Ninguno', () {
                  setState(() {
                    for (var item in _previewItems) {
                      item.isSelected = false;
                    }
                  });
                }),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: _isScanning ? null : _scanFolder,
                  tooltip: 'Re-escanear',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
          ),
          // Lista
          Expanded(
            child: _isScanning
                ? const Center(child: CircularProgressIndicator())
                : _previewItems.isEmpty
                ? Center(
                    child: Text(
                      _romFolder.isEmpty
                          ? 'Selecciona una carpeta de ROMs'
                          : 'No se encontraron ROMs',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _previewItems.length,
                    itemBuilder: (context, index) {
                      final item = _previewItems[index];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: Checkbox(
                          value: item.isSelected,
                          onChanged: (val) =>
                              setState(() => item.isSelected = val ?? false),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        title: Text(
                          item.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: item.wasManuallyEdited ? Colors.amber : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          p.basename(item.filePath),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 14),
                          onPressed: () => _editItemName(item),
                          tooltip: 'Editar nombre',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                        onTap: () =>
                            setState(() => item.isSelected = !item.isSelected),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniButton(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 10),
      ),
      child: Text(label),
    );
  }

  // ============================================================================
  // PANEL DE LOG
  // ============================================================================

  Widget _buildLogPanel() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 4,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
          // Log content
          Expanded(
            child: ListView(
              controller: _logScrollController,
              padding: const EdgeInsets.all(12),
              children: [
                Text(
                  _logText.isEmpty ? 'Listo.' : _logText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.greenAccent,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // BARRA DE ACCIONES
  // ============================================================================

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // Botones secundarios
          OutlinedButton.icon(
            onPressed: _isProcessing ? null : () => _startProcess('inject'),
            icon: const Icon(Icons.add_to_photos, size: 16),
            label: const Text('Inyectar'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _isProcessing ? null : () => _startProcess('metadata'),
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Metadatos'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          const Spacer(),
          // Botón principal
          FilledButton.icon(
            onPressed: _isProcessing ? null : () => _startProcess('full'),
            icon: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow, size: 18),
            label: Text(_isProcessing ? 'Procesando...' : 'Ejecutar'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
