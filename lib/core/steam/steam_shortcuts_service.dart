import 'dart:convert';
import 'dart:io';

import 'models/steam_shortcut_entry.dart';

class SteamShortcutsService {
  Future<bool> isPythonModuleAvailable(String moduleName) async {
    final result = await Process.run('python3', [
      '-c',
      'import importlib.util; print("1" if importlib.util.find_spec("$moduleName") else "0")',
    ]);
    return result.exitCode == 0 &&
        result.stdout.toString().trim().toLowerCase() == '1';
  }

  Future<bool> isPythonVdfAvailable() async {
    return isPythonModuleAvailable('vdf');
  }

  Future<bool> isPillowAvailable() async {
    return isPythonModuleAvailable('PIL');
  }

  Future<void> upsertShortcut({
    required String vdfPath,
    required int lutrisGameId,
    required SteamShortcutEntry entry,
  }) async {
    final payload = jsonEncode({
      'vdfPath': vdfPath,
      'lutrisGameId': lutrisGameId,
      'appIdSigned': entry.appIdSigned,
      'appName': entry.appName,
      'exe': entry.exe,
      'startDir': entry.startDir,
      'icon': entry.icon,
      'launchOptions': entry.launchOptions,
      'tags': entry.tags,
    });

    const script = r'''
import json
import os
import shutil
import sys

import vdf

raw = sys.stdin.read()
args = json.loads(raw)

vdf_path = args['vdfPath']
game_id = str(args['lutrisGameId'])
app_id_signed = int(args['appIdSigned'])
app_name = args['appName']
exe = args['exe']
start_dir = args['startDir']
icon = args.get('icon', '')
launch_options = args.get('launchOptions', '')
tags = args.get('tags', [])

os.makedirs(os.path.dirname(vdf_path), exist_ok=True)

if os.path.exists(vdf_path):
    shutil.copy2(vdf_path, vdf_path + '.bak')
    with open(vdf_path, 'rb') as f:
        data = vdf.binary_loads(f.read())
else:
    data = {'shortcuts': {}}

shortcuts = data.get('shortcuts', {})
if not isinstance(shortcuts, dict):
    shortcuts = {}

needle = f'lutris:rungameid/{game_id}'
target_index = None

for idx, sc in shortcuts.items():
    lo = str(sc.get('LaunchOptions', ''))
    if needle in lo:
        target_index = idx
        break

if target_index is None:
    numeric = [int(k) for k in shortcuts.keys() if str(k).isdigit()]
    target_index = str(max(numeric) + 1 if numeric else 0)

shortcut = {
    'appid': app_id_signed,
    'AppName': app_name,
    'Exe': exe,
    'StartDir': start_dir,
    'icon': icon,
    'LaunchOptions': launch_options,
    'IsHidden': 0,
    'AllowDesktopConfig': 1,
    'AllowOverlay': 1,
    'OpenVR': 0,
    'Devkit': 0,
    'DevkitOverrideAppID': 0,
    'LastPlayTime': 0,
    'tags': {str(i): str(tag) for i, tag in enumerate(tags)},
}

shortcuts[str(target_index)] = shortcut
data['shortcuts'] = shortcuts

with open(vdf_path, 'wb') as f:
    f.write(vdf.binary_dumps(data))

print(json.dumps({'ok': True, 'index': str(target_index)}))
''';

    final process = await Process.start('python3', [
      '-c',
      script,
    ], runInShell: false);
    process.stdin.write(payload);
    await process.stdin.flush();
    await process.stdin.close();

    final stdoutText = await utf8.decodeStream(process.stdout);
    final stderrText = await utf8.decodeStream(process.stderr);
    final code = await process.exitCode;

    if (code != 0) {
      throw Exception('No se pudo actualizar shortcuts.vdf: $stderrText');
    }

    if (stdoutText.trim().isEmpty) {
      throw Exception('No hubo respuesta al actualizar shortcuts.vdf.');
    }
  }

  Future<List<SteamShortcutRecord>> listLutrisShortcuts({
    required String vdfPath,
  }) async {
    final payload = jsonEncode({'vdfPath': vdfPath});

    const script = r'''
import json
import os
import re
import sys

import vdf

raw = sys.stdin.read()
args = json.loads(raw)
vdf_path = args['vdfPath']

if not os.path.exists(vdf_path):
    print('[]')
    raise SystemExit(0)

with open(vdf_path, 'rb') as f:
    data = vdf.binary_loads(f.read())

shortcuts = data.get('shortcuts', {})
result = []
for idx, sc in shortcuts.items():
    lo = str(sc.get('LaunchOptions', ''))
    m = re.search(r'lutris:rungameid/(\d+)', lo)
    if not m:
        continue

    app_name = str(sc.get('AppName', ''))
    exe = str(sc.get('Exe', ''))
    appid = sc.get('appid')

    result.append({
        'index': str(idx),
        'gameId': int(m.group(1)),
        'appName': app_name,
        'exe': exe,
        'appIdSigned': int(appid) if appid is not None else None,
    })

print(json.dumps(result))
''';

    final process = await Process.start('python3', ['-c', script]);
    process.stdin.write(payload);
    await process.stdin.flush();
    await process.stdin.close();

    final stdoutText = await utf8.decodeStream(process.stdout);
    final stderrText = await utf8.decodeStream(process.stderr);
    final code = await process.exitCode;

    if (code != 0) {
      throw Exception('No se pudo leer shortcuts.vdf: $stderrText');
    }

    final decoded = jsonDecode(stdoutText);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => SteamShortcutRecord(
            index: item['index']?.toString() ?? '',
            gameId: int.tryParse(item['gameId']?.toString() ?? '') ?? 0,
            appName: item['appName']?.toString() ?? '',
            exe: item['exe']?.toString() ?? '',
            appIdSigned: item['appIdSigned'] == null
                ? null
                : int.tryParse(item['appIdSigned'].toString()),
          ),
        )
        .toList();
  }

  Future<void> removeShortcutsByIndex({
    required String vdfPath,
    required List<String> indexes,
  }) async {
    if (indexes.isEmpty) return;

    final payload = jsonEncode({'vdfPath': vdfPath, 'indexes': indexes});

    const script = r'''
import json
import os
import shutil
import sys

import vdf

raw = sys.stdin.read()
args = json.loads(raw)
vdf_path = args['vdfPath']
indexes = set(str(x) for x in args.get('indexes', []))

if not os.path.exists(vdf_path):
    print(json.dumps({'ok': True, 'removed': 0}))
    raise SystemExit(0)

shutil.copy2(vdf_path, vdf_path + '.bak')

with open(vdf_path, 'rb') as f:
    data = vdf.binary_loads(f.read())

shortcuts = data.get('shortcuts', {})
ordered = []
removed = 0
for k in sorted(shortcuts.keys(), key=lambda x: int(x) if str(x).isdigit() else 10**9):
    if str(k) in indexes:
        removed += 1
        continue
    ordered.append(shortcuts[k])

data['shortcuts'] = {str(i): sc for i, sc in enumerate(ordered)}

with open(vdf_path, 'wb') as f:
    f.write(vdf.binary_dumps(data))

print(json.dumps({'ok': True, 'removed': removed}))
''';

    final process = await Process.start('python3', ['-c', script]);
    process.stdin.write(payload);
    await process.stdin.flush();
    await process.stdin.close();

    final stderrText = await utf8.decodeStream(process.stderr);
    final code = await process.exitCode;
    if (code != 0) {
      throw Exception('No se pudo depurar shortcuts.vdf: $stderrText');
    }
  }

  int calculateNonSteamAppId(String exe, String appName) {
    final input = utf8.encode('$exe$appName');
    final crc = _crc32(input);
    return (crc | 0x80000000) & 0xFFFFFFFF;
  }

  int _crc32(List<int> data) {
    var crc = 0xFFFFFFFF;
    for (final b in data) {
      var x = (crc ^ b) & 0xFF;
      for (var i = 0; i < 8; i++) {
        if ((x & 1) != 0) {
          x = (x >> 1) ^ 0xEDB88320;
        } else {
          x >>= 1;
        }
      }
      crc = (crc >> 8) ^ x;
    }
    return crc ^ 0xFFFFFFFF;
  }
}

class SteamShortcutRecord {
  final String index;
  final int gameId;
  final String appName;
  final String exe;
  final int? appIdSigned;

  const SteamShortcutRecord({
    required this.index,
    required this.gameId,
    required this.appName,
    required this.exe,
    required this.appIdSigned,
  });

  int get appIdUnsigned {
    if (appIdSigned != null) {
      if (appIdSigned! < 0) return appIdSigned! + 0x100000000;
      return appIdSigned!;
    }
    return 0;
  }
}
