import 'dart:typed_data';

/// A launchable application installed on the device.
///
/// Lock state deliberately lives outside this entity: the locked set is owned by
/// the native layer and mirrored in [AppListState], so the inventory stays a
/// plain description of what is installed.
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.appName,
    required this.isSystemApp,
    this.icon,
  });

  final String packageName;
  final String appName;
  final bool isSystemApp;

  /// PNG bytes of the launcher icon, or null when it could not be rasterised.
  final Uint8List? icon;

  /// Whether [query] matches the display name or the package name.
  bool matches(String query) {
    if (query.isEmpty) return true;
    final needle = query.toLowerCase();
    return appName.toLowerCase().contains(needle) ||
        packageName.toLowerCase().contains(needle);
  }
}
