import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../core/lutris/games_repository.dart';
import '../core/lutris/rom_cache_repository.dart';
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
  RomCacheEntry? _screenScraperInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
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
      final screenScraperInfo = _romCache.findByGameName(widget.game.name);

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
      final configFile = File(widget.game.configPath);
      if (configFile.existsSync()) {
        final content = configFile.readAsStringSync();
        // Buscar la línea que contiene la ruta del ROM
        final lines = content.split('\n');
        for (final line in lines) {
          if (line.trim().startsWith('path:')) {
            return line.split(':').skip(1).join(':').trim();
          }
        }
      }
    } catch (e) {
      // Ignorar errores de lectura
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: Text('Detalles del Juego', style: const TextStyle(fontSize: 18)),
        backgroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con imagen de cover y información básica
          _buildHeader(),

          const SizedBox(height: 24),

          // Información del juego
          _buildGameInfo(),

          const SizedBox(height: 24),

          // Preview de media actual
          _buildMediaPreview(),

          const SizedBox(height: 24),

          // Información de ScreenScraper (si está disponible)
          if (_screenScraperInfo != null) ...[
            _buildScreenScraperInfo(),
            const SizedBox(height: 24),
          ],

          // Botones de acción
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover image
        Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: File(_coverPath).existsSync()
                ? Image.file(
                    File(_coverPath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholderImage('Cover', Icons.image),
                  )
                : _buildPlaceholderImage('Cover', Icons.image),
          ),
        ),

        const SizedBox(width: 20),

        // Game info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre del juego
              Text(
                widget.game.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 8),

              // Platform
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Text(
                  widget.game.platform.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Información de ScreenScraper si está disponible
              if (_screenScraperInfo?.isIdentified == true) ...[
                Row(
                  children: [
                    const Icon(Icons.verified, color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'Identificado por ScreenScraper',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Información adicional de ScreenScraper
              if (_screenScraperInfo?.developer != null) ...[
                Text(
                  'Desarrollador: ${_screenScraperInfo!.developer}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
              ],

              if (_screenScraperInfo?.releaseDate != null) ...[
                Text(
                  'Fecha: ${_screenScraperInfo!.releaseDate}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Información del Archivo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),

        // ROM path si está disponible
        if (_romPath != null) ...[
          _buildInfoRow('Ubicación del ROM', _romPath!),
          const SizedBox(height: 8),
        ],

        _buildInfoRow('Slug', widget.game.slug),
        const SizedBox(height: 8),

        _buildInfoRow('ID', widget.game.id.toString()),

        // Sinopsis de ScreenScraper si está disponible
        if (_screenScraperInfo?.synopsis != null &&
            _screenScraperInfo!.synopsis!.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Sinopsis',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              _screenScraperInfo!.synopsis!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Media Actual',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            // Banner
            Expanded(
              flex: 2,
              child: _buildMediaItem(
                'Banner',
                _bannerPath,
                widget.game.hasBanner,
                Icons.panorama,
                aspectRatio: 3.0,
              ),
            ),

            const SizedBox(width: 12),

            // Icon
            Expanded(
              flex: 1,
              child: _buildMediaItem(
                'Icono',
                _iconPath,
                widget.game.hasIcon,
                Icons.apps,
                aspectRatio: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaItem(
    String label,
    String path,
    bool exists, // Mantenemos el parámetro pero no lo usamos
    IconData fallbackIcon, {
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
              border: Border.all(color: Colors.white24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: File(path).existsSync()
                  ? Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildPlaceholderImage(label, fallbackIcon),
                    )
                  : _buildPlaceholderImage(label, fallbackIcon),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderImage(String label, IconData icon) {
    return Container(
      color: Colors.white.withOpacity(0.05),
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
        Row(
          children: [
            const Icon(Icons.public, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Media Disponible en ScreenScraper',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Preview de imágenes de ScreenScraper
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

        // URLs de media disponibles
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
        Container(
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
                      Icon(Icons.broken_image, color: Colors.white30, size: 24),
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

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Botón principal para cambiar nombre/buscar/cambiar media
        ElevatedButton.icon(
          onPressed: _openVisualSelector,
          icon: const Icon(Icons.edit),
          label: const Text('Cambiar Nombre y Media'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),

        const SizedBox(height: 12),

        // Botón secundario para solo cambiar media
        OutlinedButton.icon(
          onPressed: _openVisualSelectorDirect,
          icon: const Icon(Icons.image),
          label: const Text('Solo Cambiar Media'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white30),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  void _openVisualSelector() {
    Navigator.of(context).pop();
    SteamGridDBVisualSelector.show(
      context,
      widget.game,
      widget.lutrisPaths,
      widget.apiKey,
      widget.onGameUpdated,
    );
  }

  void _openVisualSelectorDirect() {
    // Implementar una versión que vaya directo a la selección de media
    // sin pasar por la búsqueda de nombre
    _openVisualSelector(); // Por ahora usa el mismo flujo
  }
}
