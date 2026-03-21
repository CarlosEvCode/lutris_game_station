import 'dart:io';

import 'package:flutter/material.dart';

import '../core/lutris/games_repository.dart';
import '../core/steam/steam_detector.dart';
import '../core/steam/steam_export_service.dart';
import '../platforms/platform_registry.dart';
import 'game_detail_screen.dart';

class VisualManagerScreen extends StatefulWidget {
  final Map<String, String?> lutrisPaths;
  final String apiKey;
  final String? initialPlatformId;

  const VisualManagerScreen({
    super.key,
    required this.lutrisPaths,
    required this.apiKey,
    this.initialPlatformId,
  });

  @override
  State<VisualManagerScreen> createState() => _VisualManagerScreenState();
}

class _VisualManagerScreenState extends State<VisualManagerScreen> {
  late GamesRepository _repo;
  final SteamExportService _steamExportService = SteamExportService();
  List<PlatformInfo> _platforms = [];
  PlatformInfo? _selectedPlatform;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Game> _games = [];
  bool _isLoading = false;
  bool _isSteamAvailable = false;
  bool _hasMore = true;
  bool _isGridView = true;
  bool _selectionMode = false;

  int _page = 0;
  final int _limit = 30;
  String _searchQuery = '';
  String _filterMode = 'all';
  int _imageVersion = 0;

  GameMediaStats _stats = const GameMediaStats(
    total: 0,
    missingCover: 0,
    missingBanner: 0,
    missingIcon: 0,
  );

  final Set<int> _selectedGameIds = {};

  @override
  void initState() {
    super.initState();
    _repo = GamesRepository(widget.lutrisPaths['db_path']!);
    _initSteamAvailability();
    _scrollController.addListener(_onScroll);
    _loadPlatforms();
  }

  Future<void> _initSteamAvailability() async {
    final available = await _detectSteamAvailability();
    if (!mounted) return;
    setState(() {
      _isSteamAvailable = available;
    });
  }

  Future<bool> _detectSteamAvailability() async {
    final detector = SteamDetector();
    final steamPathsOk =
        detector.shortcutsPath() != null && detector.gridPath() != null;
    if (!steamPathsOk) return false;

    return _steamExportService.canExportToSteam();
  }

  @override
  void didUpdateWidget(covariant VisualManagerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lutrisPaths['db_path'] != widget.lutrisPaths['db_path']) {
      _repo = GamesRepository(widget.lutrisPaths['db_path']!);
      _imageVersion++;
      _refreshList();
    }

    if (oldWidget.initialPlatformId != widget.initialPlatformId &&
        widget.initialPlatformId != null) {
      final target = _platforms
          .where((p) => p.platformId == widget.initialPlatformId)
          .firstOrNull;
      if (target != null &&
          target.platformId != _selectedPlatform?.platformId) {
        setState(() {
          _selectedPlatform = target;
          _games = [];
          _page = 0;
          _hasMore = true;
          _selectedGameIds.clear();
        });
        _refreshList();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 600) {
      if (!_isLoading && _hasMore) {
        _loadMoreGames();
      }
    }
  }

  Future<void> _loadPlatforms() async {
    final platforms = PlatformRegistry.getAllPlatforms();
    setState(() => _platforms = platforms);
    if (platforms.isNotEmpty) {
      final preferred = platforms
          .where((p) => p.platformId == widget.initialPlatformId)
          .firstOrNull;
      setState(() => _selectedPlatform = preferred ?? platforms.first);
      _refreshList();
    }
  }

  Future<void> _refreshList() async {
    if (_selectedPlatform == null) return;
    if (!_selectionMode) _selectedGameIds.clear();

    await _syncMetadata();

    setState(() {
      _page = 0;
      _games = [];
      _hasMore = true;
      _stats = _repo.getMediaStats(
        _selectedPlatform!.runner,
        searchQuery: _searchQuery,
      );
    });

    _loadMoreGames();
  }

  Future<void> _syncMetadata() async {
    if (_selectedPlatform == null) return;
    await Future.microtask(() {
      _repo.syncMetadataWithDisk(
        runner: _selectedPlatform!.runner,
        coversDir: widget.lutrisPaths['covers_dir']!,
        bannersDir: widget.lutrisPaths['banners_dir']!,
        iconsDir: widget.lutrisPaths['system_icons_dir']!,
      );
    });
  }

  Future<void> _loadMoreGames() async {
    if (_selectedPlatform == null || _isLoading || !_hasMore) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 80));

    final offset = _page * _limit;
    final fetchedGames = _repo.getGamesByRunner(
      _selectedPlatform!.runner,
      limit: _limit,
      offset: offset,
      filterMode: _filterMode != 'all' ? _filterMode : null,
      searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
    );

    setState(() {
      _isLoading = false;
      if (fetchedGames.length < _limit) {
        _hasMore = false;
      }
      _games.addAll(fetchedGames);
      _page++;
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedGameIds.clear();
      }
    });
  }

  void _toggleGameSelection(Game game) {
    if (!_selectionMode) return;
    setState(() {
      if (_selectedGameIds.contains(game.id)) {
        _selectedGameIds.remove(game.id);
      } else {
        _selectedGameIds.add(game.id);
      }
    });
  }

  bool _isGameSelected(Game game) => _selectedGameIds.contains(game.id);

  Future<void> _confirmAndExportToSteam({required bool selectedOnly}) async {
    if (_selectedPlatform == null) return;

    final selectedGames = _games
        .where((g) => _selectedGameIds.contains(g.id))
        .toList();
    final allPlatformGames = _repo.getGamesByRunner(_selectedPlatform!.runner);
    final targetGames = selectedOnly ? selectedGames : allPlatformGames;

    if (targetGames.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay juegos para exportar.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exportar a Steam'),
        content: Text(
          selectedOnly
              ? 'Se exportaran ${targetGames.length} juegos seleccionados a Steam.\n\nSe crearan/actualizaran shortcuts, artwork y colecciones por plataforma.'
              : 'Se exportaran ${targetGames.length} juegos de ${_selectedPlatform!.platformName} a Steam.\n\nSe crearan/actualizaran shortcuts, artwork y colecciones por plataforma.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exportar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _runSteamBatchExport(targetGames);
  }

  Future<void> _runSteamBatchExport(List<Game> games) async {
    var started = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        var done = 0;
        var ok = 0;
        var failed = 0;
        String current = '';

        return StatefulBuilder(
          builder: (context, setLocalState) {
            if (!started) {
              started = true;
              Future.microtask(() async {
                for (final game in games) {
                  setLocalState(() {
                    current = game.name;
                  });

                  final result = await _steamExportService.exportGame(
                    game,
                    widget.lutrisPaths,
                  );

                  setLocalState(() {
                    done++;
                    if (result.success) {
                      ok++;
                    } else {
                      failed++;
                    }
                  });
                }

                if (context.mounted) {
                  Navigator.of(context).pop();
                }

                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Exportacion completada. OK: $ok | Fallidos: $failed | Total: ${games.length}',
                    ),
                    backgroundColor: failed == 0 ? Colors.green : Colors.orange,
                  ),
                );
              });
            }

            final progress = games.isEmpty ? 0.0 : done / games.length;
            return AlertDialog(
              title: const Text('Exportando a Steam...'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 12),
                    Text('Procesando: $done/${games.length}'),
                    const SizedBox(height: 6),
                    Text('Correctos: $ok | Fallidos: $failed'),
                    if (current.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Actual: $current',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLibrarySummary() {
    final theme = Theme.of(context);
    final total = _stats.total;

    Widget buildChip(String label, int missing, IconData icon, Color color) {
      return Tooltip(
        message: label,
        child: InkWell(
          onTap: missing == 0
              ? null
              : () {
                  setState(
                    () => _filterMode = label == 'Sin portada'
                        ? 'missingCover'
                        : label == 'Sin banner'
                        ? 'missingBanner'
                        : 'missingIcon',
                  );
                  _refreshList();
                },
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.25),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: missing > 0
                    ? color.withOpacity(0.6)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: missing > 0 ? color : Colors.white30,
                ),
                const SizedBox(width: 6),
                Text(
                  '$missing',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: missing > 0 ? color : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Biblioteca',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                color: Colors.white70,
              ),
            ),
            const Spacer(),
            Text(
              '$total juegos',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            buildChip(
              'Sin portada',
              _stats.missingCover,
              Icons.photo_library,
              Colors.pinkAccent,
            ),
            buildChip(
              'Sin banner',
              _stats.missingBanner,
              Icons.panorama_horizontal,
              Colors.amberAccent,
            ),
            buildChip(
              'Sin icono',
              _stats.missingIcon,
              Icons.apps,
              Colors.lightBlueAccent,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildFiltersSection(),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filtros rápidos',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todos', style: TextStyle(fontSize: 11)),
              selected: _filterMode == 'all',
              onSelected: (val) {
                if (val) {
                  setState(() => _filterMode = 'all');
                  _refreshList();
                }
              },
            ),
            ChoiceChip(
              label: const Text('Sin portada', style: TextStyle(fontSize: 11)),
              selected: _filterMode == 'missingCover',
              onSelected: (val) {
                if (val) {
                  setState(() => _filterMode = 'missingCover');
                  _refreshList();
                }
              },
            ),
            ChoiceChip(
              label: const Text('Sin banner', style: TextStyle(fontSize: 11)),
              selected: _filterMode == 'missingBanner',
              onSelected: (val) {
                if (val) {
                  setState(() => _filterMode = 'missingBanner');
                  _refreshList();
                }
              },
            ),
            ChoiceChip(
              label: const Text('Sin icono', style: TextStyle(fontSize: 11)),
              selected: _filterMode == 'missingIcon',
              onSelected: (val) {
                if (val) {
                  setState(() => _filterMode = 'missingIcon');
                  _refreshList();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Herramientas',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            _buildSideActionButton(
              icon: Icons.select_all,
              label: _selectionMode
                  ? 'Cancelar selección multiple'
                  : 'Selección multiple',
              onPressed: _toggleSelectionMode,
              isActive: _selectionMode,
            ),
            const SizedBox(height: 8),
            _buildSideActionButton(
              icon: Icons.refresh,
              label: 'Forzar sincronización',
              onPressed: _refreshList,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSideActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withOpacity(0.15)
              : theme.colorScheme.surfaceVariant.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? theme.colorScheme.primary : Colors.white70,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? theme.colorScheme.primary : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // Platform dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<PlatformInfo>(
                value: _selectedPlatform,
                items: _platforms.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text(
                      p.platformName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  );
                }).toList(),
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
          // Search bar
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value.trim());
                _refreshList();
              },
              decoration: InputDecoration(
                hintText: 'Buscar juego o slug...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _refreshList();
                        },
                      )
                    : null,
                filled: true,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // View toggle
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ToggleButtons(
              borderRadius: BorderRadius.circular(12),
              isSelected: [_isGridView, !_isGridView],
              onPressed: (index) {
                setState(() => _isGridView = index == 0);
              },
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.grid_view, size: 18),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.view_list, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.tonalIcon(
            onPressed: _refreshList,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refrescar'),
          ),
          if (_isSteamAvailable) ...[
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: () => _confirmAndExportToSteam(selectedOnly: false),
              icon: const Icon(Icons.cloud_upload, size: 18),
              label: const Text('Exportar plataforma a Steam'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidePanel() {
    final theme = Theme.of(context);
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.7),
        border: Border(
          right: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buildLibrarySummary()],
        ),
      ),
    );
  }

  Widget _buildGameGrid() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        childAspectRatio: 0.68,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: _games.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < _games.length) {
          return _buildGameCard(_games[index]);
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget _buildGameList() {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      itemCount: _games.length + (_hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index < _games.length) {
          return _buildGameListTile(_games[index]);
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget _buildGameListTile(Game game) {
    final theme = Theme.of(context);
    final isSelected = _isGameSelected(game);
    return InkWell(
      onTap: () =>
          _selectionMode ? _toggleGameSelection(game) : _editMetadata(game),
      onLongPress: () {
        if (!_selectionMode) {
          _toggleSelectionMode();
          _toggleGameSelection(game);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withOpacity(0.6)
                : theme.dividerColor.withValues(alpha: 0.1),
          ),
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.08)
              : theme.colorScheme.surfaceVariant.withOpacity(0.2),
        ),
        child: Row(
          children: [
            if (_selectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.white38,
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: _buildImagePreview(game, 'cover', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.platform,
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _buildMediaStatus(game),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.edit),
              color: Colors.white60,
              onPressed: () => _editMetadata(game),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaStatus(Game game) {
    Widget buildDot(bool hasAsset, IconData icon) {
      return Icon(
        icon,
        size: 16,
        color: hasAsset ? Colors.greenAccent : Colors.orangeAccent,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildDot(game.hasCover, Icons.photo_library),
        const SizedBox(width: 6),
        buildDot(game.hasBanner, Icons.panorama_horizontal),
        const SizedBox(width: 6),
        buildDot(game.hasIcon, Icons.apps),
      ],
    );
  }

  Widget _buildGameCard(Game game) {
    final theme = Theme.of(context);
    final missingCover = !game.hasCover;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () =>
            _selectionMode ? _toggleGameSelection(game) : _editMetadata(game),
        onLongPress: () {
          if (!_selectionMode) {
            _toggleSelectionMode();
            _toggleGameSelection(game);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isGameSelected(game)
                  ? theme.colorScheme.primary.withOpacity(0.7)
                  : theme.dividerColor.withValues(alpha: 0.05),
            ),
            color: missingCover
                ? theme.colorScheme.errorContainer.withOpacity(0.1)
                : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
            boxShadow: _isGameSelected(game)
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImagePreview(game, 'cover', fit: BoxFit.cover),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Column(
                          children: [
                            if (!game.hasCover)
                              _buildBadge('Cover')
                            else if (!game.hasBanner)
                              _buildBadge('Banner')
                            else if (!game.hasIcon)
                              _buildBadge('Icon'),
                          ],
                        ),
                      ),
                      if (_selectionMode)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              _isGameSelected(game)
                                  ? Icons.check
                                  : Icons.radio_button_unchecked,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: IconButton.filled(
                          icon: const Icon(Icons.edit, size: 16),
                          onPressed: () => _editMetadata(game),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(34, 34),
                            backgroundColor: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              height: 28,
                              child: _buildImagePreview(
                                game,
                                'banner',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: _buildImagePreview(
                              game,
                              'icon',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withOpacity(0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildImagePreview(
    Game game,
    String type, {
    BoxFit fit = BoxFit.cover,
  }) {
    String? path;

    if (type == 'cover') {
      path = "${widget.lutrisPaths['covers_dir']}${game.slug}.jpg";
    } else if (type == 'banner') {
      path = "${widget.lutrisPaths['banners_dir']}${game.slug}.jpg";
    } else if (type == 'icon') {
      path = "${widget.lutrisPaths['system_icons_dir']}lutris_${game.slug}.png";
    }

    if (path != null && File(path).existsSync()) {
      return Image.file(
        File(path),
        key: ValueKey("$path-$_imageVersion"),
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(type),
      );
    }

    return _buildPlaceholder(type);
  }

  Widget _buildPlaceholder(String type) {
    final icon = type == 'cover'
        ? Icons.photo_library
        : type == 'banner'
        ? Icons.panorama_horizontal
        : Icons.apps;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white12,
          size: type == 'icon' ? 18 : 36,
        ),
      ),
    );
  }

  void _editMetadata(Game game) {
    GameDetailScreen.show(context, game, widget.lutrisPaths, widget.apiKey, () {
      setState(() => _imageVersion++);
      _refreshList();
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.white30),
          const SizedBox(height: 12),
          Text(
            'No se encontraron juegos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajusta tus filtros o verifica que tengas juegos instalados en esta plataforma.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea() {
    if (_isLoading && _games.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_games.isEmpty) {
      return _buildEmptyState();
    }

    return _isGridView ? _buildGameGrid() : _buildGameList();
  }

  Widget _buildSelectionBar() {
    if (!_selectionMode) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.9),
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedGameIds.length} seleccionados',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: _selectedGameIds.length == _games.length
                ? null
                : () {
                    setState(() {
                      _selectedGameIds
                        ..clear()
                        ..addAll(_games.map((g) => g.id));
                    });
                  },
            icon: const Icon(Icons.select_all, size: 18),
            label: const Text('Seleccionar visibles'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _selectedGameIds.clear(),
            icon: const Icon(Icons.clear),
            label: const Text('Limpiar'),
          ),
          const Spacer(),
          if (_isSteamAvailable)
            FilledButton.icon(
              onPressed: _selectedGameIds.isEmpty
                  ? null
                  : () => _confirmAndExportToSteam(selectedOnly: true),
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Exportar seleccionados a Steam'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Row(
            children: [
              _buildSidePanel(),
              Expanded(child: _buildContentArea()),
            ],
          ),
        ),
        _buildSelectionBar(),
      ],
    );
  }
}
