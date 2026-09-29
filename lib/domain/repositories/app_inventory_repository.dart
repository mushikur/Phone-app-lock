import '../entities/installed_app.dart';

/// Read/write access to the installed-app inventory and the locked-app set.
///
/// Every implementation is expected to be fully offline.
abstract interface class AppInventoryRepository {
  /// Launchable apps installed on the device, sorted by display name.
  Future<List<InstalledApp>> loadInstalledApps();

  /// Packages the user has marked as locked.
  Future<Set<String>> loadLockedPackages();

  /// Locks or unlocks [packageName] and returns the resulting state.
  Future<bool> setLocked({required String packageName, required bool locked});
}

/// Raised when the native layer cannot satisfy an inventory request.
class AppInventoryException implements Exception {
  const AppInventoryException(this.message);

  final String message;

  @override
  String toString() => 'AppInventoryException: $message';
}
