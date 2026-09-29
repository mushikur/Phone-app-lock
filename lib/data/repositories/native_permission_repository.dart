import 'package:flutter/services.dart';

import '../../domain/entities/app_permission.dart';
import '../../domain/repositories/permission_repository.dart';
import '../bridge/native_bridge.dart';

/// [PermissionRepository] backed by the Android native layer.
class NativePermissionRepository implements PermissionRepository {
  const NativePermissionRepository([this._bridge = const NativeBridge()]);

  final NativeBridge _bridge;

  @override
  Future<PermissionSnapshot> loadStatuses() async {
    final raw = await _guard(
      _bridge.getPermissionStatuses,
      'Could not check your permissions.',
    );

    final statuses = <AppPermission, PermissionStatus>{};
    for (final entry in raw.entries) {
      final permission = AppPermission.fromWireName(entry.key);
      if (permission == null) continue;
      statuses[permission] = PermissionStatus.fromWireName(entry.value);
    }
    return PermissionSnapshot(statuses);
  }

  @override
  Future<bool> openSettings(AppPermission permission) {
    return _guard(
      () => _bridge.openPermissionSettings(permission.wireName),
      'Could not open Android settings.',
    );
  }

  @override
  Future<PermissionStatus> requestNotificationPermission() async {
    final status = await _guard(
      _bridge.requestNotificationPermission,
      'Could not ask for notification access.',
    );
    return PermissionStatus.fromWireName(status);
  }

  Future<T> _guard<T>(Future<T> Function() call, String message) async {
    try {
      return await call();
    } on MissingPluginException {
      throw const PermissionException(
        'The native layer is unavailable. Samir Lock only runs on Android.',
      );
    } on PlatformException catch (error) {
      throw PermissionException(error.message ?? message);
    }
  }
}
