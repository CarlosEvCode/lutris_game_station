import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SteamDependenciesDialog extends StatelessWidget {
  const SteamDependenciesDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const SteamDependenciesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Text('Requerimientos de Steam Export'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para exportar tus juegos a Steam se necesitan dependencias adicionales en tu sistema:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildDependencyItem(
                context,
                'Python 3',
                'Motor para ejecutar los scripts de sincronización.',
              ),
              _buildDependencyItem(
                context,
                'Librería vdf',
                'Permite leer y escribir el formato de archivos de Steam.',
              ),
              _buildDependencyItem(
                context,
                'Librería Pillow (PIL)',
                'Necesaria para procesar y convertir las imágenes de carátulas.',
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Comandos de instalación por distribución:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _buildInstallSection(
                context,
                'Debian / Ubuntu / Mint',
                'sudo apt install python3-vdf python3-pil',
              ),
              const SizedBox(height: 12),
              _buildInstallSection(
                context,
                'Arch Linux / Manjaro',
                'sudo pacman -S python-vdf python-pillow',
              ),
              const SizedBox(height: 12),
              _buildInstallSection(
                context,
                'Fedora / Red Hat',
                'sudo dnf install python3-vdf python3-pillow',
              ),
              const SizedBox(height: 16),
              const Text(
                'Nota: Actualmente solo se detecta la versión Nativa de Steam. Si usas Steam vía Flatpak, el soporte se añadirá próximamente.',
                style: TextStyle(fontSize: 11, color: Colors.white54, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    );
  }

  Widget _buildDependencyItem(BuildContext context, String name, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.white),
                children: [
                  TextSpan(
                    text: '$name: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: desc,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallSection(BuildContext context, String distro, String command) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(distro, style: const TextStyle(fontSize: 12, color: Colors.white60)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  command,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 14, color: Colors.white54),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: command));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comando copiado'), duration: Duration(seconds: 1)),
                  );
                },
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
