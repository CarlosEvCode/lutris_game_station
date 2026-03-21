import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../core/lutris/games_repository.dart';
import '../core/lutris/rom_cache_repository.dart';
import '../core/steam/steam_export_service.dart';
import 'steamgriddb_visual_selector.dart';

/// Pantalla de detalle del juego que muestra información completa
/// antes de permitir editar metadata visual
class GameDetailScreen extends StatefulWidget {
  final Game game;
  final Map<String, String?> lutrisPaths;
  final String apiKey;
  final VoidCallback onGameUpdated;

  const GameDetailScreen({
    super.key,
    required this.game,
    required this.lutrisPaths,
    required this.apiKey,
    required this.onGameUpdated,
  });

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();

  /// Método estático para mostrar la pantalla como modal
  static Future<void> show(
    BuildContext context,
    Game game,
    Map<String, String?> lutrisPaths,
    String apiKey,
    VoidCallback onGameUpdated,
  ) {
    return showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: GameDetailScreen(
          game: game,
          lutrisPaths: lutrisPaths,
          apiKey: apiKey,
          onGameUpdated: onGameUpdated,
        ),
      ),
    );
  }
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  final RomCacheRepository _romCache = RomCacheRepository();
  final SteamExportService _steamExportService = SteamExportService();
  late final GamesRepository _gamesRepository;
  RomCacheEntry? _screenScraperInfo;
  bool _isLoading = true;
  int _imageVersion = 0;
  late String _currentGameName;

  @override
  void initState() {
    super.initState();
    _gamesRepository = GamesRepository(widget.lutrisPaths['db_path']!);
    _currentGameName = widget.game.name;
    _loadScreenScraperInfo();
  }

  @override
  void dispose() {
    _romCache.dispose();
    super.dispose();
  }

  Future<void> _loadScreenScraperInfo() async {
    setState(() => _isLoading = true);

    try {
      // Buscar información de ScreenScraper en el cache por nombre del juego
      final screenScraperInfo = _romCache.findByGameName(_currentGameName);

      setState(() {
        _isLoading = false;
        _screenScraperInfo = screenScraperInfo;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Rutas de las imágenes del juego
  String get _coverPath =>
      p.join(widget.lutrisPaths['covers_dir']!, '${widget.game.slug}.jpg');

  String get _bannerPath =>
      p.join(widget.lutrisPaths['banners_dir']!, '${widget.game.slug}.jpg');

  String get _iconPath => p.join(
    widget.lutrisPaths['lutris_icons_dir']!,
    '${widget.game.slug}.png',
  );

  // Obtener la ruta del ROM desde el configPath
  String? get _romPath {
    try {
      final configFile = File(_resolveConfigFilePath(widget.game.configPath));
      if (configFile.existsSync()) {
        final content = configFile.readAsStringSync();
        final lines = content.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('main_file:') ||
              trimmed.startsWith('path:') ||
              trimmed.startsWith('rom:')) {
            var value = trimmed.split(':').skip(1).join(':').trim();
            if ((value.startsWith('"') && value.endsWith('"')) ||
                (value.startsWith("'") && value.endsWith("'"))) {
              value = value.substring(1, value.length - 1);
            }
            if (value.isNotEmpty) return value;
          }
        }
      }
    } catch (e) {
      // Ignorar errores de lectura
    }
    return null;
  }

  String _resolveConfigFilePath(String configPath) {
    final normalized = configPath.trim();
    if (normalized.isEmpty) return normalized;

    if (normalized.endsWith('.yml') || normalized.startsWith('/')) {
      return normalized;
    }

    return p.join(widget.lutrisPaths['config_dir_main']!, '$normalized.yml');
  }

  String? get _romFileName {
    final fullPath = _romPath;
    if (fullPath == null || fullPath.isEmpty) return null;
    return p.basename(fullPath);
  }

  String? get _romExtension {
    final fileName = _romFileName;
    if (fileName == null || fileName.isEmpty) return null;
    final ext = p.extension(fileName);
    if (ext.isEmpty) return null;
    return ext;
  }

  String? get _romDirectory {
    final fullPath = _romPath;
    if (fullPath == null || fullPath.isEmpty) return null;
    return p.dirname(fullPath);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxWidth = size.width > 1320 ? 1240.0 : size.width * 0.97;
    final maxHeight = size.height > 980 ? 920.0 : size.height * 0.97;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          minWidth: 320,
          minHeight: 480,
        ),
        child: Material(
          color: const Color(0xFF11151A),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildBody(),
              ),
              _buildFooterActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final identified = _screenScraperInfo?.isIdentified == true;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1B222B), const Color(0xFF141A21)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detalle del Juego',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentGameName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip(
                      widget.game.platform.toUpperCase(),
                      const Color(0xFF2C7BE5),
                    ),
                    _buildChip(
                      identified
                          ? 'Identificado por ScreenScraper'
                          : 'Sin identificacion ScreenScraper',
                      identified ? const Color(0xFF2DA56A) : Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Cerrar (Esc)',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.42)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 980;
        final isTablet = constraints.maxWidth >= 720;

        if (!isTablet) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildMediaPanel(compact: true),
                const SizedBox(height: 12),
                _buildInfoPanel(),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: isDesktop ? 7 : 5,
                child: _buildMediaPanel(compact: !isDesktop),
              ),
              const SizedBox(width: 14),
              Expanded(flex: 3, child: _buildInfoPanel()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaPanel({required bool compact}) {
    final hasScraperMedia =
        _screenScraperInfo != null &&
        (_screenScraperInfo!.coverUrl != null ||
            _screenScraperInfo!.bannerUrl != null ||
            _screenScraperInfo!.cover3dUrl != null ||
            _screenScraperInfo!.logoUrl != null);
    final tabCount = hasScraperMedia ? 2 : 1;

    return _buildPanel(
      title: 'Media',
      child: DefaultTabController(
        length: tabCount,
        child: Column(
          children: [
            TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: const Color(0xFF4BA7FF),
              tabs: [
                const Tab(text: 'Actual en Lutris'),
                if (hasScraperMedia) const Tab(text: 'ScreenScraper'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  SingleChildScrollView(
                    child: _buildCurrentMediaContent(compact),
                  ),
                  if (hasScraperMedia)
                    SingleChildScrollView(child: _buildScreenScraperInfo()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentMediaContent(bool compact) {
    final coverExists = File(_coverPath).existsSync();
    final bannerExists = File(_bannerPath).existsSync();
    final iconExists = File(_iconPath).existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        compact
            ? Column(
                children: [
                  _buildMediaItem(
                    'Cover',
                    _coverPath,
                    Icons.image,
                    mediaType: 'cover',
                    aspectRatio: 0.75,
                  ),
                  const SizedBox(height: 12),
                  _buildMediaItem(
                    'Banner',
                    _bannerPath,
                    Icons.panorama,
                    mediaType: 'banner',
                    aspectRatio: 3.0,
                  ),
                  const SizedBox(height: 12),
                  _buildMediaItem(
                    'Icono',
                    _iconPath,
                    Icons.apps,
                    mediaType: 'icon',
                    aspectRatio: 1.0,
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildMediaItem(
                      'Cover',
                      _coverPath,
                      Icons.image,
                      mediaType: 'cover',
                      aspectRatio: 0.75,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final iconWidth = constraints.maxWidth > 260
                            ? 220.0
                            : constraints.maxWidth * 0.72;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMediaItem(
                              'Banner',
                              _bannerPath,
                              Icons.panorama,
                              mediaType: 'banner',
                              aspectRatio: 3.0,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: iconWidth,
                              child: _buildMediaItem(
                                'Icono',
                                _iconPath,
                                Icons.apps,
                                mediaType: 'icon',
                                aspectRatio: 1.0,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatusChip('Cover', coverExists),
            _buildStatusChip('Banner', bannerExists),
            _buildStatusChip('Icono', iconExists),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, bool ok) {
    final color = ok ? const Color(0xFF2DA56A) : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withOpacity(0.16),
        border: Border.all(color: color.withOpacity(0.42)),
      ),
      child: Text(
        ok ? '$label disponible' : '$label faltante',
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return _buildPanel(
      title: 'Informacion',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              title: 'Correccion de juego',
              children: [_buildEditActions()],
            ),
            const SizedBox(height: 10),
            _buildInfoCard(
              title: 'Archivo y origen',
              children: [
                if (_romFileName != null)
                  _buildInfoRow('Archivo ROM', _romFileName!),
                if (_romExtension != null)
                  _buildInfoRow('Extension', _romExtension!),
                if (_romDirectory != null)
                  _buildInfoRow('Ubicacion', _romDirectory!),
                _buildInfoRow('Slug', widget.game.slug),
                _buildInfoRow('ID', widget.game.id.toString()),
                if (_romPath != null) ...[
                  const SizedBox(height: 6),
                  _buildRomPathBlock(_romPath!),
                ],
              ],
            ),
            const SizedBox(height: 10),
            _buildInfoCard(
              title: 'ScreenScraper',
              children: [
                _buildInfoRow(
                  'Estado',
                  _screenScraperInfo?.isIdentified == true
                      ? 'Identificado'
                      : 'Sin datos disponibles',
                ),
                if (_screenScraperInfo?.developer != null)
                  _buildInfoRow(
                    'Desarrollador',
                    _screenScraperInfo!.developer!,
                  ),
                if (_screenScraperInfo?.releaseDate != null)
                  _buildInfoRow(
                    'Lanzamiento',
                    _screenScraperInfo!.releaseDate!,
                  ),
              ],
            ),
            if (_screenScraperInfo?.synopsis != null &&
                _screenScraperInfo!.synopsis!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildInfoCard(
                title: 'Sinopsis',
                children: [
                  Text(
                    _screenScraperInfo!.synopsis!,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildEditActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _correctGame,
              icon: const Icon(Icons.manage_search, size: 16),
              label: const Text('Corregir juego'),
            ),
            OutlinedButton.icon(
              onPressed: _exportToSteam,
              icon: const Icon(Icons.sports_esports, size: 16),
              label: const Text('Exportar a Steam'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Abre SteamGridDB en modo busqueda para corregir coincidencia y actualizar automaticamente el nombre en Lutris al seleccionar un juego.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPanel({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: Padding(padding: const EdgeInsets.all(12), child: child),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRomPathBlock(String fullPath) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_open, size: 14, color: Colors.white60),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Ruta exacta del ROM',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copiar ruta',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy, size: 14, color: Colors.white70),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: fullPath));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ruta copiada al portapapeles.'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            fullPath,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaItem(
    String label,
    String path,
    IconData fallbackIcon, {
    required String mediaType,
    double aspectRatio = 1.0,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: aspectRatio,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
              color: Colors.black.withOpacity(0.12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  File(path).existsSync()
                      ? Image.file(
                          File(path),
                          key: ValueKey('$path-$_imageVersion'),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholderImage(label, fallbackIcon),
                        )
                      : _buildPlaceholderImage(label, fallbackIcon),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withOpacity(0.58),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _openVisualSelectorForType(mediaType),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderImage(String label, IconData icon) {
    return Container(
      color: Colors.white.withOpacity(0.04),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white30, size: 32),
          const SizedBox(height: 4),
          Text(
            'Sin $label',
            style: const TextStyle(color: Colors.white30, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScreenScraperInfo() {
    if (_screenScraperInfo == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Media disponible en ScreenScraper',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            if (_screenScraperInfo!.coverUrl != null)
              Expanded(
                child: _buildScreenScraperImagePreview(
                  'Cover ScreenScraper',
                  _screenScraperInfo!.coverUrl!,
                ),
              ),
            if (_screenScraperInfo!.coverUrl != null &&
                _screenScraperInfo!.bannerUrl != null)
              const SizedBox(width: 12),
            if (_screenScraperInfo!.bannerUrl != null)
              Expanded(
                child: _buildScreenScraperImagePreview(
                  'Banner ScreenScraper',
                  _screenScraperInfo!.bannerUrl!,
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        if (_screenScraperInfo!.coverUrl != null)
          _buildMediaUrlRow('Cover (2D)', _screenScraperInfo!.coverUrl!),
        if (_screenScraperInfo!.cover3dUrl != null)
          _buildMediaUrlRow('Cover (3D)', _screenScraperInfo!.cover3dUrl!),
        if (_screenScraperInfo!.bannerUrl != null)
          _buildMediaUrlRow('Banner/Fanart', _screenScraperInfo!.bannerUrl!),
        if (_screenScraperInfo!.logoUrl != null)
          _buildMediaUrlRow('Logo/Wheel', _screenScraperInfo!.logoUrl!),
      ],
    );
  }

  Widget _buildScreenScraperImagePreview(String label, String imageUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.green,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _showImagePreview(imageUrl, label),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.white.withOpacity(0.05),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.white.withOpacity(0.05),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          color: Colors.white30,
                          size: 24,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Error al cargar',
                          style: TextStyle(color: Colors.white30, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaUrlRow(String type, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.link, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              type,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 16),
            onPressed: () => _showImagePreview(url, type),
            tooltip: 'Ver imagen',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  void _showImagePreview(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black87,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Image
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                          size: 48,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Error al cargar la imagen',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F141A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Tip: usa el icono de editar en Cover/Banner/Icono para cambiar cada media.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.drive_file_rename_outline, size: 16),
            label: const Text('Selector desde media'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white38,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  void _openVisualSelectorForType(String mediaType) {
    _openVisualSelectorInternal(initialMediaType: mediaType);
  }

  Future<void> _openVisualSelectorInternal({String? initialMediaType}) async {
    final changed = await SteamGridDBVisualSelector.show(
      context,
      widget.game,
      widget.lutrisPaths,
      widget.apiKey,
      widget.onGameUpdated,
      initialMediaType: initialMediaType,
      initialQuery: _currentGameName,
    );

    if (!mounted) return;

    if (changed) {
      await _loadScreenScraperInfo();
      if (!mounted) return;
      setState(() {
        _imageVersion++;
      });
      widget.onGameUpdated();
    }
  }

  Future<void> _correctGame() async {
    final controller = TextEditingController(text: _currentGameName);

    final query = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Corregir juego en SteamGridDB'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Texto de busqueda',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Buscar'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (query == null || query.isEmpty) return;

    String? pendingNameFromMatch;

    final changed = await SteamGridDBVisualSelector.show(
      context,
      widget.game,
      widget.lutrisPaths,
      widget.apiKey,
      widget.onGameUpdated,
      initialQuery: query,
      autoSelectFirstResult: false,
      onGameMatched: (matchedName) {
        pendingNameFromMatch = matchedName;
      },
    );

    if (!mounted) return;

    if (changed &&
        pendingNameFromMatch != null &&
        pendingNameFromMatch!.isNotEmpty &&
        pendingNameFromMatch != _currentGameName) {
      _gamesRepository.updateGameName(widget.game.id, pendingNameFromMatch!);
      setState(() {
        _currentGameName = pendingNameFromMatch!;
      });
      widget.onGameUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Nombre corregido a "$pendingNameFromMatch".'),
        ),
      );
    }

    if (changed) {
      await _loadScreenScraperInfo();
      if (!mounted) return;
      setState(() {
        _imageVersion++;
      });
      widget.onGameUpdated();
    }
  }

  Future<void> _exportToSteam() async {
    final gameToExport = Game(
      id: widget.game.id,
      slug: widget.game.slug,
      name: _currentGameName,
      platform: widget.game.platform,
      configPath: widget.game.configPath,
      hasCover: widget.game.hasCover,
      hasBanner: widget.game.hasBanner,
      hasIcon: widget.game.hasIcon,
    );

    final result = await _steamExportService.exportGame(
      gameToExport,
      widget.lutrisPaths,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }
}
