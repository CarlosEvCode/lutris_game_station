class SteamExportResult {
  final bool success;
  final String message;
  final int? appId;

  const SteamExportResult({
    required this.success,
    required this.message,
    this.appId,
  });

  factory SteamExportResult.ok(String message, {int? appId}) {
    return SteamExportResult(success: true, message: message, appId: appId);
  }

  factory SteamExportResult.error(String message) {
    return SteamExportResult(success: false, message: message);
  }
}
