import '../entities/app_permission.dart';

/// Read permission state and hand the user off to the right Settings page.
///
/// Every implementation is expected to be fully offline.
abstract interface class PermissionRepository {
  /// Current status of every permission Samir Lock asks for.
  Future<PermissionSnapshot> loadStatuses();

  /// Opens the Android Settings page for [permission].
  ///
  /// Returns false when no settings page could be opened on this device, so the
  /// UI can say so instead of appearing to do nothing.
  Future<bool> openSettings(AppPermission permission);

  /// Shows the system notification prompt where it exists, returning the
  /// resulting status.
  Future<PermissionStatus> requestNotificationPermission();
}

/// Raised when the native layer cannot satisfy a permission request.
class PermissionException implements Exception {
  const PermissionException(this.message);

  final String message;

  @override
  String toString() => 'PermissionException: $message';
}
