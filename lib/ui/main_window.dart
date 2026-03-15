import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../platforms/platform_registry.dart';
import '../core/lutris/lutris_detector.dart';
import '../core/injector/rom_injector.dart';
import '../core/metadata/metadata_downloader.dart';
import 'visual_manager_screen.dart';

class MainWindow extends StatefulWidget {
  const MainWindow({Key? key}) : super(key: key);

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  int _currentIndex = 0;
  LutrisDetector? _detector;
  Map<String, String?>? _lutrisPaths;
  
  PlatformInfo? _selectedPlatform;
  List<String> _selectedExtensions = [];
  String _romFolder = '';
  String _apiKey = '';
  
  bool _cleanOldGames = true;
  bool _isProcessing = false;
  
  String _logText = 'Listo. Selecciona plataforma y carpeta de ROMs.\n';
  double _progress = 0.0;
  
  final ScrollController _logScrollController = ScrollController();
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _detectLutris();
    final platforms = PlatformRegistry.getAllPlatforms();
    if (platforms.isNotEmpty) {
      _onPlatformChanged(platforms.first);
    }
  }

  void _onPlatformChanged(PlatformInfo? val) {
    setState(() {
      _selectedPlatform = val;
      if (val != null) {
        // Inicializamos con todas las extensiones por defecto
        _selectedExtensions = List.from(val.extensions);
      }
    });
  }

  void _detectLutris() {
    try {
      _detector = LutrisDetector(interactive: false);
      _lutrisPaths = _detector?.getPaths();
      if (_lutrisPaths?['mode'] == null || _lutrisPaths!['mode']!.isEmpty) {
        _log("⚠️ No se detectó ninguna instalación de Lutris.");
      } else {
        _log("✅ Detectado Lutris: ${_lutrisPaths!['mode']}");
      }
    } catch (e) {
      _log("❌ Error detectando Lutris: $e");
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
          duration: const Duration(milliseconds: 300),
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

  Future<void> _browseFolder() async {
    final String? folderPath = await getDirectoryPath();
    if (folderPath != null) {
      setState(() {
        _romFolder = folderPath;
      });
    }
  }

  void _showConfigDialog() {
    _apiKeyController.text = _apiKey;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.blue),
              SizedBox(width: 12),
              Text('Configuración'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SteamGridDB API Key:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Pega tu API Key aquí...',
                  prefixIcon: const Icon(Icons.vpn_key),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Obtén tu API Key en steamgriddb.com/profile/api',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _apiKey = _apiKeyController.text.trim();
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API Key guardada.')),
                );
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
      _log("❌ Rutas de Lutris no detectadas.");
      return;
    }
    if (_selectedPlatform == null) {
      _log("❌ Selecciona una plataforma.");
      return;
    }
    if ((action == 'inject' || action == 'full') && _romFolder.isEmpty) {
      _log("❌ Selecciona una carpeta de ROMs.");
      return;
    }
    if ((action == 'inject' || action == 'full') && _selectedExtensions.isEmpty) {
      _log("❌ Debes seleccionar al menos una extensión para inyectar.");
      return;
    }
    if ((action == 'metadata' || action == 'full') && _apiKey.isEmpty) {
      _log("❌ Configura la API Key de SteamGridDB.");
      _showConfigDialog();
      return;
    }

    setState(() {
      _isProcessing = true;
      _clearLog();
    });

    try {
      if (action == 'inject' || action == 'full') {
        final injector = RomInjector(
          lutrisPaths: _lutrisPaths!,
          platformKey: _selectedPlatform!.platformId,
          romFolder: _romFolder,
          customExtensions: _selectedExtensions, // Pasamos las extensiones filtradas
          progressCallback: (msg, prog) {
            _log(msg, prog);
          },
        );
        await injector.injectRoms(cleanOld: _cleanOldGames);
      }
      
      if (action == 'metadata' || action == 'full') {
        final downloader = MetadataDownloader(
          lutrisPaths: _lutrisPaths!,
          apiKey: _apiKey,
          runner: _selectedPlatform!.runner,
          progressCallback: (msg, prog) {
            _log(msg, prog);
          },
        );
        await downloader.downloadMetadata(skipExisting: true);
      }
    } catch (e) {
      _log("❌ Error fatal: $e");
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
        title: const Text('Lutris Game Station', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.computer, size: 16, color: _lutrisPaths != null ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Text(
                  _lutrisPaths != null ? _lutrisPaths!['mode']! : "No detectado",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showConfigDialog,
            tooltip: 'Configuración',
          ),
        ],
      ),
      body: _currentIndex == 0 ? _buildInjectorView() : _buildVisualManagerView(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.flash_on), label: 'Inyector Automático'),
          NavigationDestination(icon: Icon(Icons.grid_view), label: 'Gestor Visual'),
        ],
      ),
    );
  }

  Widget _buildVisualManagerView() {
    if (_lutrisPaths == null) {
      return const Center(child: Text("Rutas de Lutris no detectadas."));
    }
    return VisualManagerScreen(
      lutrisPaths: _lutrisPaths!,
      apiKey: _apiKey,
    );
  }

  Widget _buildInjectorView() {
    final platforms = PlatformRegistry.getAllPlatforms();
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step 1: Platform
          _buildStepCard(
            title: '1. Selección de Plataforma',
            icon: Icons.gamepad,
            child: DropdownButtonFormField<PlatformInfo>(
              value: _selectedPlatform,
              items: platforms.map((p) => DropdownMenuItem(
                value: p,
                child: Text(p.platformName),
              )).toList(),
              onChanged: _isProcessing ? null : _onPlatformChanged,
              decoration: InputDecoration(
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.sports_esports),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Step 2: ROMs Folder & Extensions
          _buildStepCard(
            title: '2. Ubicación y Filtros de ROMs',
            icon: Icons.folder,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        controller: TextEditingController(text: _romFolder),
                        decoration: InputDecoration(
                          hintText: 'Selecciona la carpeta con tus ROMs...',
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.folder_open),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonal(
                      onPressed: _isProcessing ? null : _browseFolder,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Buscar'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Extensiones Permitidas:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_selectedPlatform != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 0,
                    children: _selectedPlatform!.extensions.map((ext) {
                      final isSelected = _selectedExtensions.contains(ext);
                      return FilterChip(
                        label: Text(ext, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        selected: isSelected,
                        onSelected: _isProcessing ? null : (selected) {
                          setState(() {
                            if (selected) {
                              _selectedExtensions.add(ext);
                            } else {
                              _selectedExtensions.remove(ext);
                            }
                          });
                        },
                        selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                        checkmarkColor: theme.colorScheme.primary,
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Limpiar juegos existentes', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Borra entradas previas de este runner en Lutris', style: TextStyle(fontSize: 12)),
                  value: _cleanOldGames,
                  onChanged: _isProcessing ? null : (val) {
                    setState(() { _cleanOldGames = val; });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Step 3: Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'Solo Inyectar',
                  icon: Icons.add_to_photos,
                  color: Colors.blueGrey,
                  onPressed: () => _startProcess('inject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  label: 'Metadatos',
                  icon: Icons.download,
                  color: Colors.indigo,
                  onPressed: () => _startProcess('metadata'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            label: 'Proceso Completo (Inyectar + Metadatos)',
            icon: Icons.auto_awesome,
            color: Colors.green.shade700,
            isPrimary: true,
            onPressed: () => _startProcess('full'),
          ),
          
          const SizedBox(height: 32),
          
          // Progress and Log
          const Text('Actividad y Progreso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progress, 
              minHeight: 12,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: ListView(
              controller: _logScrollController,
              children: [
                Text(
                  _logText,
                  style: const TextStyle(
                    fontFamily: 'monospace', 
                    fontSize: 13, 
                    color: Colors.greenAccent,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({required String title, required IconData icon, required Widget child}) {
    return Card(
      elevation: 0,
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label, 
    required IconData icon, 
    required Color color, 
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    final style = isPrimary 
      ? FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 24),
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        )
      : FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        );

    return FilledButton.icon(
      onPressed: _isProcessing ? null : onPressed,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      style: style,
    );
  }
}
