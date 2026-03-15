import 'package:flutter/material.dart';
import 'dart:io';
import '../core/lutris/games_repository.dart';
import '../platforms/platform_registry.dart';
import 'steamgriddb_visual_selector.dart';

class VisualManagerScreen extends StatefulWidget {
  final Map<String, String?> lutrisPaths;
  final String apiKey;

  const VisualManagerScreen({
    Key? key,
    required this.lutrisPaths,
    required this.apiKey,
  }) : super(key: key);

  @override
  State<VisualManagerScreen> createState() => _VisualManagerScreenState();
}

class _VisualManagerScreenState extends State<VisualManagerScreen> {
  late GamesRepository _repo;
  List<PlatformInfo> _platforms = [];
  PlatformInfo? _selectedPlatform;
  List<Game> _games = [];
  
  int _page = 0;
  final int _limit = 24;
  int _totalGames = 0;
  bool _isLoading = false;
  
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // Para forzar el refresco de imágenes
  int _imageVersion = 0;

  @override
  void initState() {
    super.initState();
    _repo = GamesRepository(widget.lutrisPaths['db_path']!);
    _loadPlatforms();
  }

  void _loadPlatforms() {
    _platforms = PlatformRegistry.getAllPlatforms();
    if (_platforms.isNotEmpty) {
      _selectedPlatform = _platforms.first;
      _loadGames();
    }
  }

  void _loadGames() async {
    if (_selectedPlatform == null) return;
    setState(() => _isLoading = true);
    
    // Simular ligero delay
    await Future.delayed(const Duration(milliseconds: 100));
    
    // En una implementación real, el repositorio debería filtrar por búsqueda.
    // Por simplicidad en este paso, filtramos la lista obtenida si hay búsqueda.
    // Pero lo ideal es que el repo soporte LIKE.
    
    _totalGames = _repo.getGamesCount(_selectedPlatform!.runner);
    final offset = _page * _limit;
    var fetchedGames = _repo.getGamesByRunner(_selectedPlatform!.runner, limit: _limit, offset: offset);
    
    if (_searchQuery.isNotEmpty) {
      fetchedGames = fetchedGames.where((g) => 
        g.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
        g.slug.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    setState(() {
      _games = fetchedGames;
      _isLoading = false;
    });
  }

  Widget _buildImagePreview(Game game, String type) {
    String? path;
    BoxFit fit = BoxFit.cover;
    
    if (type == 'cover') {
      path = "${widget.lutrisPaths['covers_dir']}${game.slug}.jpg";
    } else if (type == 'banner') {
      path = "${widget.lutrisPaths['banners_dir']}${game.slug}.jpg";
    } else if (type == 'icon') {
      path = "${widget.lutrisPaths['system_icons_dir']}lutris_${game.slug}.png";
      fit = BoxFit.contain;
    }

    if (path != null && File(path).existsSync()) {
      return Image.file(
        File(path),
        key: ValueKey("$path-$_imageVersion"), // Forzar recarga si cambia la versión
        fit: fit,
        errorBuilder: (ctx, _, __) => _buildPlaceholder(type),
      );
    }
    return _buildPlaceholder(type);
  }

  Widget _buildPlaceholder(String type) {
    return Container(
      color: Colors.white.withOpacity(0.05),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'cover' ? Icons.book : (type == 'banner' ? Icons.view_day : Icons.api),
              color: Colors.white24, 
              size: type == 'icon' ? 20 : 40
            ),
            if (type != 'icon') ...[
              const SizedBox(height: 8),
              Text('Sin ${type}', style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ]
          ],
        ),
      ),
    );
  }

  void _editMetadata(Game game) {
    SteamGridDBVisualSelector.show(
      context,
      game,
      widget.lutrisPaths,
      widget.apiKey,
      () => setState(() {
        _imageVersion++; // Evict cache
        _loadGames();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        // Barra de Filtros y Búsqueda
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
          ),
          child: Row(
            children: [
              // Selector de Plataforma
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PlatformInfo>(
                    value: _selectedPlatform,
                    items: _platforms.map((p) => DropdownMenuItem(
                      value: p, 
                      child: Text(p.platformName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedPlatform = val;
                          _page = 0;
                        });
                        _loadGames();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Barra de Búsqueda
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _loadGames();
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar juego...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadGames();
                        })
                      : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton.filledTonal(
                icon: const Icon(Icons.refresh), 
                onPressed: _loadGames,
                tooltip: 'Refrescar',
              ),
            ],
          ),
        ),
        
        // Grid de Juegos
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _games.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: theme.disabledColor),
                      const SizedBox(height: 16),
                      Text("No se encontraron juegos", style: theme.textTheme.titleMedium),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                  ),
                  itemCount: _games.length,
                  itemBuilder: (context, index) {
                    final game = _games[index];
                    return _buildGameCard(game);
                  },
                ),
        ),
        
        // Paginación
        if (_totalGames > _limit && _searchQuery.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: -1, icon: const Icon(Icons.chevron_left), enabled: _page > 0),
                    ButtonSegment(value: _page, label: Text('Página ${_page + 1}')),
                    ButtonSegment(value: 1, icon: const Icon(Icons.chevron_right), enabled: (_page + 1) * _limit < _totalGames),
                  ],
                  selected: {_page},
                  onSelectionChanged: (Set<int> newSelection) {
                    final val = newSelection.first;
                    if (val == -1) setState(() => _page--);
                    else if (val == 1) setState(() => _page++);
                    _loadGames();
                  },
                ),
              ],
            ),
          )
      ],
    );
  }

  Widget _buildGameCard(Game game) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () => _editMetadata(game),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover Art
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImagePreview(game, 'cover'),
                  // Overlay de edición al hacer hover (o siempre en mobile)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const IconButton(
                        icon: Icon(Icons.edit, color: Colors.white, size: 18),
                        onPressed: null, // El InkWell padre maneja el tap
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.name, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 30,
                            child: _buildImagePreview(game, 'banner'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.white.withOpacity(0.05),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildImagePreview(game, 'icon'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
