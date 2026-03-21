import 'dart:convert';
import 'dart:io';
import 'dart:math';

class SteamCollectionsService {
  Future<void> addAppToSimpleCollection({
    required String namespace1Path,
    required String collectionName,
    required int appId,
  }) async {
    final file = File(namespace1Path);
    if (!file.existsSync()) {
      final dir = file.parent;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      file.writeAsStringSync('[]');
    }

    final raw = file.readAsStringSync();
    final decoded = jsonDecode(raw);

    if (decoded is! List) {
      throw Exception('Formato inesperado en cloud-storage-namespace-1.json');
    }

    final records = decoded;
    final existing = _findCollectionRecord(records, collectionName);

    if (existing == null) {
      final id = _generateCollectionId();
      final value = {
        'id': id,
        'name': collectionName,
        'added': [appId],
        'removed': <int>[],
      };

      records.add([
        'user-collections.$id',
        {
          'key': 'user-collections.$id',
          'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'value': jsonEncode(value),
          'version': '1',
        },
      ]);
    } else {
      final metadata = existing[1] as Map<String, dynamic>;
      final valueRaw = metadata['value']?.toString() ?? '{}';
      final valueDecoded = jsonDecode(valueRaw);
      if (valueDecoded is! Map<String, dynamic>) {
        throw Exception('Coleccion con formato invalido: $collectionName');
      }

      final added = (valueDecoded['added'] as List?)?.cast<dynamic>() ?? [];
      final removed = (valueDecoded['removed'] as List?)?.cast<dynamic>() ?? [];

      if (!added.contains(appId)) {
        added.add(appId);
      }
      removed.remove(appId);

      valueDecoded['added'] = added;
      valueDecoded['removed'] = removed;

      metadata['timestamp'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      metadata['value'] = jsonEncode(valueDecoded);
      final currentVersion =
          int.tryParse(metadata['version']?.toString() ?? '1') ?? 1;
      metadata['version'] = (currentVersion + 1).toString();
    }

    file.writeAsStringSync(jsonEncode(records));
  }

  List<dynamic>? _findCollectionRecord(
    List<dynamic> records,
    String collectionName,
  ) {
    for (final item in records) {
      if (item is! List || item.length < 2) continue;
      final key = item[0]?.toString() ?? '';
      if (!key.startsWith('user-collections.')) continue;
      final metadata = item[1];
      if (metadata is! Map) continue;
      final valueRaw = metadata['value']?.toString() ?? '{}';
      try {
        final valueDecoded = jsonDecode(valueRaw);
        if (valueDecoded is Map<String, dynamic> &&
            valueDecoded['name']?.toString().toLowerCase() ==
                collectionName.toLowerCase()) {
          return item;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  String _generateCollectionId() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789*+-';
    final random = Random.secure();
    final buffer = StringBuffer('uc-');
    for (var i = 0; i < 13; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }
}
