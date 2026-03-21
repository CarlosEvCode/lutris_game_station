class SteamShortcutEntry {
  final int appIdSigned;
  final String appName;
  final String exe;
  final String startDir;
  final String icon;
  final String launchOptions;
  final List<String> tags;

  const SteamShortcutEntry({
    required this.appIdSigned,
    required this.appName,
    required this.exe,
    required this.startDir,
    required this.icon,
    required this.launchOptions,
    this.tags = const [],
  });
}
