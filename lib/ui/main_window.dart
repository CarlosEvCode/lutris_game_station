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
  EmulatorInfo? _selectedEmulator; // Nuevo
  List<String> _selectedExtensions = [];
  String _romFolder = '';
  String _apiKey = '';
  String _ssUser = '';
  String _ssPassword = '';

  List<InjectionItem> _previewItems = [];
  bool _isScanning = false;
  bool _cleanOldGames = true;
  bool _useHighPrecision = false;
  bool _reuseIdentification = true;
  bool _isRecursive = false;
  bool _isProcessing = false;

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
        _selectedEmulator = val.emulators.first;
        _selectedExtensions = List.from(_selectedEmulator!.extensions);
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

  void _onEmulatorChanged(EmulatorInfo? val) {
    if (val == null) return;
    setState(() {
      _selectedEmulator = val;
      _selectedExtensions = List.from(val.extensions);
      _previewItems = [];
    });
    _scanFolder();
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
    if (_romFolder.isEmpty || _selectedPlatform == null || _selectedEmulator == null) return;

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
        _selectedEmulator!,
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

  Future<void> _refreshApiStats({bool force = false}) async {
    final stats = ScreenScraperService.getStats();
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
    final shouldFetchQuota = force || _lastQuotaFetch == null || now.difference(_lastQuotaFetch!) > Duration(minutes: 5);

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
        'requestsToday': quota?.requestsToday ?? stats['lastKnownQuota']?['requestsToday'],
        'maxRequestsPerDay': quota?.maxRequestsPerDay ?? stats['lastKnownQuota']?['maxPerDay'],
        'remainingToday': quota?.remainingToday ?? stats['lastKnownQuota']?['remaining'],
        'lastQuotaFetch': _lastQuotaFetch?.toIso8601String(),
      };
    });
  }

  DateTime? _lastQuotaFetch;

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
                  const Text('SteamGridDB API Key:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'API Key...',
                      isDense: true,
                      prefixIcon: const Icon(Icons.vpn_key, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('ScreenScraper:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _ssUserController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Usuario',
                      isDense: true,
                      prefixIcon: const Icon(Icons.person, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
    if (_selectedPlatform == null || _selectedEmulator == null) {
      _log("Selecciona plataforma y emulador.");
      return;
    }
    if ((action == 'inject' || action == 'full') && _romFolder.isEmpty) {
      _log("Selecciona una carpeta de ROMs.");
      return;
    }
    if ((action == 'inject' || action == 'full') && _selectedExtensions.isEmpty) {
      _log("Selecciona al menos una extensión.");
      return;
    }
    if ((action == 'metadata' || action == 'full') && _apiKey.isEmpty) {
      _log("Configura la API Key de SteamGridDB.");
      _showConfigDialog();
      return;
    }

    if (_useHighPrecision && (action == 'inject' || action == 'full')) {
      final selectedCount = _previewItems.where((i) => i.isSelected).length;
      if (_ssUser.isEmpty || _ssPassword.isEmpty) {
        _log("Alta Precisión requiere credenciales de ScreenScraper.");
        _showConfigDialog();
        return;
      }

      _log("Verificando quota...");
      final quotaCheck = await ScreenScraperService.canStartMassiveScan(selectedCount);
      if (!quotaCheck.canProceed) {
        _log("Error: ${quotaCheck.message}");
        return;
      }
      if (quotaCheck.remainingRequests != null && quotaCheck.remainingRequests! < selectedCount) {
        final shouldContinue = await _showQuotaWarningDialog(quotaCheck.remainingRequests!, selectedCount);
        if (!shouldContinue) return;
      }
    }

    setState(() {
      _isProcessing = true;
      _clearLog();
    });

    try {
      if (action == 'inject' || action == 'full') {
        final selectedFiles = _previewItems.where((item) => item.isSelected).map((item) => File(item.filePath)).toList();
        final Map<String, String> customNames = {
          for (var item in _previewItems.where((i) => i.isSelected && i.wasManuallyEdited))
            item.filePath: item.displayName,
        };

        final injector = RomInjector(
          lutrisPaths: _lutrisPaths!,
          platformKey: _selectedPlatform!.platformId,
          emulatorId: _selectedEmulator!.id,
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
          runner: _selectedEmulator!.runner,
          progressCallback: (msg, prog) => _log(msg, prog),
        );
        await downloader.downloadMetadata(skipExisting: true);
      }
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
        title: const Text('Lutris Game Station', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
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
        destinations: const [
          NavigationDestination(icon: Icon(Icons.flash_on, size: 20), label: 'Inyector'),
          NavigationDestination(icon: Icon(Icons.grid_view, size: 20), label: 'Gestor Visual'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return _currentIndex == 0 ? _buildInjectorView() : _buildVisualManagerView();
  }

  Widget _buildLutrisSelector() {
    final currentMode = _lutrisPaths != null ? _lutrisPaths!['mode']! : "No detectado";
    if (_availableLutrisModes.length <= 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16)),
        child: Text(currentMode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      );
    }
    return PopupMenuButton<String>(
      onSelected: _switchLutrisMode,
      itemBuilder: (context) => _availableLutrisModes.map((mode) => PopupMenuItem(value: mode, child: Text(mode))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
        child: Text(currentMode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue)),
      ),
    );
  }

  Widget _buildVisualManagerView() {
    return _lutrisPaths == null ? const Center(child: Text("Lutris no detectado.")) : VisualManagerScreen(
      lutrisPaths: _lutrisPaths!,
      apiKey: _apiKey,
      initialPlatformId: _selectedPlatform?.platformId,
    );
  }

  Widget _buildInjectorView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) return _buildInjectorViewMobile();
        return _buildInjectorViewDesktop();
      },
    );
  }

  Widget _buildInjectorViewDesktop() {
    return Row(
      children: [
        SizedBox(width: 320, child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildConfigSection())),
        Expanded(
          child: Column(
            children: [
              Expanded(flex: 3, child: _buildPreviewPanel()),
              Expanded(flex: 2, child: _buildLogPanel()),
              _buildActionBar(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInjectorViewMobile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
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

  Widget _buildConfigSection() {
    final platforms = PlatformRegistry.getAllPlatforms();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Plataforma', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 6),
        DropdownButtonFormField<PlatformInfo>(
          value: _selectedPlatform,
          items: platforms.map((p) => DropdownMenuItem(value: p, child: Text(p.platformName, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: _isProcessing ? null : _onPlatformChanged,
          decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.all(10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        ),
        if (_selectedPlatform != null && _selectedPlatform!.emulators.length > 1) ...[
          const SizedBox(height: 16),
          const Text('Emulador', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          DropdownButtonFormField<EmulatorInfo>(
            value: _selectedEmulator,
            items: _selectedPlatform!.emulators.map((e) => DropdownMenuItem(value: e, child: Text(e.name, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: _isProcessing ? null : _onEmulatorChanged,
            decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.all(10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ],
        const SizedBox(height: 16),
        const Text('Carpeta de ROMs', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)), child: Text(_romFolder.isEmpty ? 'Sin seleccionar...' : _romFolder, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _isProcessing ? null : _browseFolder, icon: const Icon(Icons.folder_open, size: 18)),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Extensiones', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 6),
        if (_selectedEmulator != null)
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _selectedEmulator!.extensions.map((ext) {
              final isSelected = _selectedExtensions.contains(ext);
              return FilterChip(
                label: Text(ext, style: const TextStyle(fontSize: 10)),
                selected: isSelected,
                onSelected: _isProcessing ? null : (selected) {
                  setState(() {
                    if (selected) {
                      _selectedExtensions.add(ext);
                    } else {
                      _selectedExtensions.remove(ext);
                    }
                  });
                  _scanFolder();
                },
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
        _buildCompactCheckbox('Limpiar juegos', 'Borra entradas previas', _cleanOldGames, (val) => setState(() => _cleanOldGames = val ?? false)),
        _buildCompactCheckbox('Alta Precisión', 'Hash (ScreenScraper)', _useHighPrecision, (val) => setState(() => _useHighPrecision = val ?? false)),
        _buildCompactCheckbox('Escaneo recursivo', 'Subcarpetas', _isRecursive, (val) {
          setState(() => _isRecursive = val ?? false);
          _scanFolder();
        }),
      ],
    );
  }

  Widget _buildCompactCheckbox(String title, String subtitle, bool value, ValueChanged<bool?> onChanged) {
    return InkWell(
      onTap: _isProcessing ? null : () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Checkbox(value: value, onChanged: _isProcessing ? null : onChanged, visualDensity: VisualDensity.compact),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPanel() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(children: [
              const Icon(Icons.list, size: 16),
              const SizedBox(width: 8),
              const Text('ROMs detectadas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${_previewItems.where((i) => i.isSelected).length}/${_previewItems.length}', style: TextStyle(fontSize: 11, color: theme.colorScheme.primary)),
            ]),
          ),
          Expanded(child: _isScanning ? const Center(child: CircularProgressIndicator()) : ListView.builder(
            itemCount: _previewItems.length,
            itemBuilder: (context, index) {
              final item = _previewItems[index];
              return ListTile(
                dense: true,
                leading: Checkbox(value: item.isSelected, onChanged: (val) => setState(() => item.isSelected = val ?? false)),
                title: Text(item.displayName, style: const TextStyle(fontSize: 12)),
                trailing: IconButton(icon: const Icon(Icons.edit, size: 14), onPressed: () => _editItemName(item)),
              );
            },
          )),
        ],
      ),
    );
  }

  Widget _buildLogPanel() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          LinearProgressIndicator(value: _progress, minHeight: 4),
          Expanded(child: ListView(controller: _logScrollController, padding: const EdgeInsets.all(12), children: [
            Text(_logText.isEmpty ? 'Listo.' : _logText, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent)),
          ])),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest),
      child: Row(
        children: [
          OutlinedButton.icon(onPressed: _isProcessing ? null : () => _startProcess('inject'), icon: const Icon(Icons.add_to_photos, size: 16), label: const Text('Inyectar')),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: _isProcessing ? null : () => _startProcess('metadata'), icon: const Icon(Icons.download, size: 16), label: const Text('Metadatos')),
          const Spacer(),
          FilledButton.icon(onPressed: _isProcessing ? null : () => _startProcess('full'), icon: const Icon(Icons.play_arrow, size: 18), label: Text(_isProcessing ? 'Procesando...' : 'Ejecutar')),
        ],
      ),
    );
  }
}
