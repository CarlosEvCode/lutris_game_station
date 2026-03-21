import 'dart:io';
import 'package:convert/convert.dart';
import 'package:crclib/crclib.dart';
import 'package:crclib/catalog.dart';
import 'package:path/path.dart' as p;

class SteamArtworkService {
  int calculateNonSteamAppId(String exe, String appName) {
    final input = '$exe$appName';
    final acc = AccumulatorSink<CrcValue>();
    final sink = Crc32().startChunkedConversion(acc);
    sink.add(input.codeUnits);
    sink.close();
    final crc = acc.events.single;
    final crcInt = int.parse(crc.toRadixString(16), radix: 16);
    return (crcInt | 0x80000000) & 0xFFFFFFFF;
  }

  Future<void> copyArtworkToGrid({
    required String gridPath,
    required int appId,
    String? coverPath,
    String? heroPath,
    String? iconPath,
    String? logoPath,
    String? widePath,
  }) async {
    final gridDir = Directory(gridPath);
    if (!gridDir.existsSync()) {
      await gridDir.create(recursive: true);
    }

    void removeIfExists(String fileName) {
      final f = File(p.join(gridPath, fileName));
      if (f.existsSync()) {
        f.deleteSync();
      }
    }

    for (final ext in ['.jpg', '.png', '.ico']) {
      removeIfExists('${appId}p$ext');
      removeIfExists('${appId}_hero$ext');
      removeIfExists('${appId}_logo$ext');
      removeIfExists('${appId}_icon$ext');
      removeIfExists('$appId$ext');
    }

    await _writeSteamImage(
      srcPath: coverPath,
      destPath: p.join(gridPath, '${appId}p.jpg'),
      format: 'jpg',
    );
    await _writeSteamImage(
      srcPath: heroPath,
      destPath: p.join(gridPath, '${appId}_hero.jpg'),
      format: 'jpg',
    );
    await _writeSteamImage(
      srcPath: iconPath,
      destPath: p.join(gridPath, '${appId}_icon.jpg'),
      format: 'jpg',
    );

    final resolvedWide = widePath ?? coverPath;
    await _writeSteamImage(
      srcPath: resolvedWide,
      destPath: p.join(gridPath, '$appId.jpg'),
      format: 'jpg',
    );

    await _writeSteamImage(
      srcPath: logoPath,
      destPath: p.join(gridPath, '${appId}_logo.png'),
      format: 'png',
    );
  }

  Future<void> _writeSteamImage({
    required String? srcPath,
    required String destPath,
    required String format,
  }) async {
    if (srcPath == null || srcPath.isEmpty) return;

    final src = File(srcPath);
    if (!src.existsSync()) return;

    final converted = await _convertWithPython(
      srcPath: srcPath,
      destPath: destPath,
      format: format,
    );

    if (!converted) {
      await src.copy(destPath);
    }
  }

  Future<bool> _convertWithPython({
    required String srcPath,
    required String destPath,
    required String format,
  }) async {
    const script = r'''
import sys
from PIL import Image

src, dst, fmt = sys.argv[1], sys.argv[2], sys.argv[3].lower()

img = Image.open(src)
if fmt == 'jpg':
    if img.mode not in ('RGB', 'L'):
        img = img.convert('RGB')
    img.save(dst, format='JPEG', quality=95)
elif fmt == 'png':
    if img.mode not in ('RGBA', 'RGB', 'L'):
        img = img.convert('RGBA')
    img.save(dst, format='PNG')
else:
    raise ValueError('unsupported format')
''';

    try {
      final result = await Process.run('python3', [
        '-c',
        script,
        srcPath,
        destPath,
        format,
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
