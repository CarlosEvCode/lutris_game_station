import 'dart:convert';
import 'dart:io';

import 'models/steam_shortcut_entry.dart';

class SteamShortcutsService {
  Future<bool> isPythonVdfAvailable() async {
    final result = await Process.run('python3', [
      '-c',
      'import importlib.util; print("1" if importlib.util.find_spec("vdf") else "0")',
    ]);
    return result.exitCode == 0 &&
        result.stdout.toString().trim().toLowerCase() == '1';
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
}
