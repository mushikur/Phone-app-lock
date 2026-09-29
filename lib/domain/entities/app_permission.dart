/// Permissions Samir Lock asks the user for.
///
/// The wire names must match `PermissionIds` in the Android layer.
enum AppPermission {
  usageAccess('usageAccess'),
  displayOverOtherApps('displayOverOtherApps'),
  notifications('notifications'),
  batteryOptimization('batteryOptimization');

  const AppPermission(this.wireName);

  final String wireName;

  /// Whether protection cannot work at all without this permission.
  bool get isRequired =>
      this == AppPermission.usageAccess ||
      this == AppPermission.displayOverOtherApps;

  static AppPermission? fromWireName(String value) {
    for (final permission in AppPermission.values) {
      if (permission.wireName == value) return permission;
    }
    return null;
  }
}

/// State of a single permission.
///
/// Mirrors `PermissionStatuses` in the Android layer.
enum PermissionStatus {
  granted('granted'),

  /// Not granted yet, and grantable on this device.
  denied('denied'),

  /// Nothing to grant on this Android version.
  unsupported('unsupported');

  const PermissionStatus(this.wireName);

  final String wireName;

  /// True when there is nothing left for the user to do.
  bool get isSatisfied =>
      this == PermissionStatus.granted || this == PermissionStatus.unsupported;

  static PermissionStatus fromWireName(String? value) {
    for (final status in PermissionStatus.values) {
      if (status.wireName == value) return status;
    }
    return PermissionStatus.denied;
  }
}

/// Immutable view of every permission's status at one point in time.
class PermissionSnapshot {
  const PermissionSnapshot(this.statuses);

  const PermissionSnapshot.unknown() : statuses = const {};

  final Map<AppPermission, PermissionStatus> statuses;

  PermissionStatus statusOf(AppPermission permission) =>
      statuses[permission] ?? PermissionStatus.denied;

  bool isSatisfied(AppPermission permission) => statusOf(permission).isSatisfied;

  /// Permissions without which protection cannot run, and which are still missing.
  List<AppPermission> get missingRequired => AppPermission.values
      .where((permission) => permission.isRequired && !isSatisfied(permission))
      .toList(growable: false);

  /// True when every required permission has been granted.
  bool get isReady => missingRequired.isEmpty;

  /// Permissions that improve reliability but are not blocking.
  List<AppPermission> get missingRecommended => AppPermission.values
      .where((permission) => !permission.isRequired && !isSatisfied(permission))
      .toList(growable: false);

  int get grantedCount => AppPermission.values
      .where((permission) => statusOf(permission) == PermissionStatus.granted)
      .length;
}
