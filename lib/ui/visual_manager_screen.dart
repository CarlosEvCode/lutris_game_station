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
  bool _isLoading = false;
  bool _hasMore = true; // Controlar si quedan más juegos por cargar
  bool _isGridView = true; // Nuevo estado para alternar vistas
  
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Para forzar el refresco de imágenes
  int _imageVersion = 0;

  @override
  void initState() {
    super.initState();
    _repo = GamesRepository(widget.lutrisPaths['db_path']!);
    _scrollController.addListener(_onScroll);
    _loadPlatforms();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      if (!_isLoading && _hasMore) {
        _loadMoreGames();
      }
    }
  }

  @override
  void didUpdateWidget(covariant VisualManagerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lutrisPaths['db_path'] != widget.lutrisPaths['db_path']) {
      _repo = GamesRepository(widget.lutrisPaths['db_path']!);
      _imageVersion++;
      _refreshList();
    }
  }

  void _loadPlatforms() {
    _platforms = PlatformRegistry.getAllPlatforms();
    if (_platforms.isNotEmpty) {
      _selectedPlatform = _platforms.first;
      _refreshList();
    }
  }

  void _refreshList() {
    setState(() {
      _page = 0;
      _games = [];
      _hasMore = true;
    });
    _loadMoreGames();
  }

  void _loadMoreGames() async {
    if (_selectedPlatform == null || _isLoading || !_hasMore) return;
    
    setState(() => _isLoading = true);
    
    // Pequeño delay para suavizar la UI si la carga es muy rápida
    await Future.delayed(const Duration(milliseconds: 50));
    
    final offset = _page * _limit;
    final fetchedGames = _repo.getGamesByRunner(_selectedPlatform!.runner, limit: _limit, offset: offset);
    
    setState(() {
      _isLoading = false;
      if (fetchedGames.length < _limit) {
        _hasMore = false;
      }
      _games.addAll(fetchedGames);
      _page++;
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
        _refreshList();
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
                        setState(() => _selectedPlatform = val);
                        _refreshList();
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
                    _refreshList();
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar juego...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _refreshList();
                        })
                      : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Selector de Vista
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                  tooltip: _isGridView ? 'Cambiar a Vista de Lista' : 'Cambiar a Vista de Cuadrícula',
                ),
              ),
              const SizedBox(width: 16),
              IconButton.filledTonal(
                icon: const Icon(Icons.refresh), 
                onPressed: _refreshList,
                tooltip: 'Refrescar',
              ),
            ],
          ),
        ),
        
        // Grid o Lista de Juegos
        Expanded(
          child: _games.isEmpty && _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _games.isEmpty
              ? _buildEmptyState(theme)
              : _isGridView ? _buildGridView() : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: theme.disabledColor),
          const SizedBox(height: 16),
          Text("No se encontraron juegos", style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        childAspectRatio: 0.72,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: _games.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < _games.length) {
          return _buildGameCard(_games[index]);
        } else {
          return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));
        }
      },
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      itemCount: _games.length + (_hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index < _games.length) {
          return _buildGameListTile(_games[index]);
        } else {
          return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));
        }
      },
    );
  }

  Widget _buildGameListTile(Game game) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () => _editMetadata(game),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Icono miniatura
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withOpacity(0.05),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildImagePreview(game, 'icon'),
              ),
              const SizedBox(width: 16),
              // Nombre y Plataforma
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      game.slug,
                      style: TextStyle(color: theme.hintColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Banner miniatura
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 120,
                  height: 40,
                  child: _buildImagePreview(game, 'banner'),
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
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
