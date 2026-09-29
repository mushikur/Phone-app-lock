import 'package:samir_lock/domain/entities/app_permission.dart';
import 'package:samir_lock/domain/repositories/permission_repository.dart';

/// In-memory stand-in for the Android permission layer.
class FakePermissionRepository implements PermissionRepository {
  FakePermissionRepository({
    Map<AppPermission, PermissionStatus>? statuses,
    this.failOnLoad = false,
    this.settingsPageExists = true,
    this.notificationPromptGrants = true,
  }) : statuses = statuses ?? _allDenied();

  /// Every permission granted — the usual starting point for app-list tests.
  factory FakePermissionRepository.allGranted() {
    return FakePermissionRepository(
      statuses: {
        for (final permission in AppPermission.values)
          permission: PermissionStatus.granted,
      },
    );
  }

  /// Required permissions granted, recommended ones still outstanding.
  factory FakePermissionRepository.requiredOnly() {
    return FakePermissionRepository(
      statuses: {
        for (final permission in AppPermission.values)
          permission: permission.isRequired
              ? PermissionStatus.granted
              : PermissionStatus.denied,
      },
    );
  }

  static Map<AppPermission, PermissionStatus> _allDenied() => {
        for (final permission in AppPermission.values)
          permission: PermissionStatus.denied,
      };

  final Map<AppPermission, PermissionStatus> statuses;
  final bool failOnLoad;
  final bool settingsPageExists;
  final bool notificationPromptGrants;

  /// Permissions whose settings page was opened, in order.
  final List<AppPermission> openedSettings = [];

  int notificationPrompts = 0;

  @override
  Future<PermissionSnapshot> loadStatuses() async {
    if (failOnLoad) {
      throw const PermissionException('Could not check your permissions.');
    }
    return PermissionSnapshot(Map.of(statuses));
  }

  @override
  Future<bool> openSettings(AppPermission permission) async {
    openedSettings.add(permission);
    return settingsPageExists;
  }

  @override
  Future<PermissionStatus> requestNotificationPermission() async {
    notificationPrompts++;
    if (!notificationPromptGrants) return PermissionStatus.denied;
    statuses[AppPermission.notifications] = PermissionStatus.granted;
    return PermissionStatus.granted;
  }
}
