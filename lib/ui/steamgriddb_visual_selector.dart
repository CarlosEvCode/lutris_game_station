import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/lutris/games_repository.dart';
import '../core/metadata/steamgriddb_service.dart';
import 'package:path/path.dart' as p;

class SteamGridDBVisualSelector extends StatefulWidget {
  final Game game;
  final Map<String, String?> lutrisPaths;
  final String apiKey;
  final VoidCallback onUpdated;
  final String? initialMediaType;

  const SteamGridDBVisualSelector({
    Key? key,
    required this.game,
    required this.lutrisPaths,
    required this.apiKey,
    required this.onUpdated,
    this.initialMediaType,
  }) : super(key: key);

  static Future<bool> show(
    BuildContext context,
    Game game,
    Map<String, String?> lutrisPaths,
    String apiKey,
    VoidCallback onUpdated, {
    String? initialMediaType,
  }) {
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura tu API Key primero.')),
      );
      return Future.value(false);
    }

    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 1000,
          height: 800,
          child: SteamGridDBVisualSelector(
            game: game,
            lutrisPaths: lutrisPaths,
            apiKey: apiKey,
            onUpdated: onUpdated,
            initialMediaType: initialMediaType,
          ),
        ),
      ),
    ).then((value) => value ?? false);
  }

  @override
  State<SteamGridDBVisualSelector> createState() =>
      _SteamGridDBVisualSelectorState();
}

class _SteamGridDBVisualSelectorState extends State<SteamGridDBVisualSelector>
    with SingleTickerProviderStateMixin {
  late SteamGridDBService _api;
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedSgdbGame;

  bool _isLoadingImages = false;
  bool _isApplying = false;
  bool _hasAppliedChanges = false;
  List<Map<String, dynamic>> _covers = [];
  List<Map<String, dynamic>> _banners = [];
  List<Map<String, dynamic>> _icons = [];
  String? _statusMessage;
  Color _statusColor = Colors.blue;
  IconData _statusIcon = Icons.info_outline;

  @override
  void initState() {
    super.initState();
    _api = SteamGridDBService(apiKey: widget.apiKey);
    _tabController = TabController(length: 4, vsync: this);
    _searchCtrl.text = widget.game.name;
    _initialSearch();
  }

  void _initialSearch() async {
    await _search();
    if (_searchResults.isNotEmpty) {
      _selectSgdbGame(_searchResults.first);
    }
  }

  int _tabIndexForMediaType(String? mediaType) {
    switch (mediaType) {
      case 'cover':
        return 1;
      case 'banner':
        return 2;
      case 'icon':
        return 3;
      default:
        return 1;
    }
  }

  void _setStatus(String message, Color color, IconData icon) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusColor = color;
      _statusIcon = icon;
    });
  }

  Future<void> _evictFileFromImageCache(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return;
    final provider = FileImage(file);
    await provider.evict();
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
      _selectedSgdbGame = null;
    });

    final results = await _api.searchGames(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _selectSgdbGame(Map<String, dynamic> game) async {
    setState(() {
      _selectedSgdbGame = game;
      _isLoadingImages = true;
      _covers = [];
      _banners = [];
      _icons = [];
    });

    final int gameId = game['id'];

    // Fetch all types in parallel
    final results = await Future.wait([
      _api.getImages(gameId, 'cover', runner: widget.game.platform),
      _api.getImages(gameId, 'banner', runner: widget.game.platform),
      _api.getImages(gameId, 'icon', runner: widget.game.platform),
    ]);

    setState(() {
      _covers = results[0];
      _banners = results[1];
      _icons = results[2];
      _isLoadingImages = false;
      _tabController.animateTo(_tabIndexForMediaType(widget.initialMediaType));
    });
  }

  Future<void> _downloadAndApply(String url, String type) async {
    if (_isApplying) return;

    final slug = widget.game.slug;
    String targetPath;

    if (type == 'cover') {
      targetPath = p.join(widget.lutrisPaths['covers_dir']!, "$slug.jpg");
    } else if (type == 'banner') {
      targetPath = p.join(widget.lutrisPaths['banners_dir']!, "$slug.jpg");
    } else {
      // icon
      targetPath = p.join(widget.lutrisPaths['lutris_icons_dir']!, "$slug.png");
    }

    setState(() => _isApplying = true);
    _setStatus('Descargando y aplicando $type...', Colors.blue, Icons.download);

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final file = File(targetPath);
        await file.writeAsBytes(res.bodyBytes);
        await _evictFileFromImageCache(targetPath);

        if (type == 'icon') {
          final systemIconPath = p.join(
            widget.lutrisPaths['system_icons_dir']!,
            "lutris_$slug.png",
          );
          await file.copy(systemIconPath);
          await _evictFileFromImageCache(systemIconPath);
        }

        _hasAppliedChanges = true;
        _setStatus(
          '${type[0].toUpperCase()}${type.substring(1)} aplicado correctamente en Lutris.',
          Colors.green,
          Icons.check_circle,
        );

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('✅ $type actualizado.')));
        widget.onUpdated();
      } else {
        _setStatus(
          'No se pudo descargar $type (HTTP ${res.statusCode}).',
          Colors.red,
          Icons.error_outline,
        );
      }
    } catch (e) {
      _setStatus('Error aplicando $type: $e', Colors.red, Icons.error_outline);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.grid_view),
                  const SizedBox(width: 12),
                  Text(
                    'Gestor Visual para: ${widget.game.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context, _hasAppliedChanges),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '1. Buscar Juego', icon: Icon(Icons.search)),
                  Tab(text: '2. Covers', icon: Icon(Icons.image)),
                  Tab(text: '3. Banners', icon: Icon(Icons.view_carousel)),
                  Tab(text: '4. Iconos', icon: Icon(Icons.blur_on)),
                ],
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _statusColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(_statusIcon, size: 16, color: _statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(color: _statusColor, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_isApplying) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 3),
              ],
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSearchView(),
              _buildImageGrid(_covers, 'cover'),
              _buildImageGrid(_banners, 'banner'),
              _buildImageGrid(_icons, 'icon'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del juego en SteamGridDB',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isSearching ? null : _search,
                icon: const Icon(Icons.search),
                label: const Text('Buscar'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isSearching)
            const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!_isSearching)
            Expanded(
              child: _searchResults.isEmpty
                  ? const Center(child: Text('No hay resultados.'))
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final res = _searchResults[index];
                        final isSelected =
                            _selectedSgdbGame?['id'] == res['id'];
                        return ListTile(
                          title: Text(
                            res['name'],
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text('ID: ${res['id']}'),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : const Icon(Icons.chevron_right),
                          selected: isSelected,
                          onTap: () => _selectSgdbGame(res),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(List<Map<String, dynamic>> images, String type) {
    if (_selectedSgdbGame == null) {
      return const Center(
        child: Text('Primero selecciona un juego en la pestaña de búsqueda.'),
      );
    }
    if (_isLoadingImages) {
      return const Center(child: CircularProgressIndicator());
    }
    if (images.isEmpty) {
      return const Center(
        child: Text('No se encontraron imágenes para este tipo.'),
      );
    }

    double ratio = 1.0;
    if (type == 'cover') ratio = 600 / 900;
    if (type == 'banner') ratio = 1920 / 620;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: type == 'icon' ? 150 : 300,
        childAspectRatio: ratio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final img = images[index];
        final thumb = img['thumb'] ?? img['url'];

        return InkWell(
          onTap: _isApplying ? null : () => _downloadAndApply(img['url'], type),
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  thumb,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.file_download,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
