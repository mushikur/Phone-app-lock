import 'package:flutter/services.dart';

import '../../domain/entities/installed_app.dart';
import '../../domain/repositories/app_inventory_repository.dart';
import '../bridge/native_bridge.dart';

/// [AppInventoryRepository] backed by the Android native layer.
class NativeAppInventoryRepository implements AppInventoryRepository {
  const NativeAppInventoryRepository([this._bridge = const NativeBridge()]);

  final NativeBridge _bridge;

  @override
  Future<List<InstalledApp>> loadInstalledApps() async {
    final payload = await _guard(
      _bridge.getInstalledApps,
      'Could not read the list of installed apps.',
    );
    return payload.map(_toInstalledApp).toList(growable: false);
  }

  @override
  Future<Set<String>> loadLockedPackages() async {
    final packages = await _guard(
      _bridge.getLockedPackages,
      'Could not read your locked apps.',
    );
    return packages.toSet();
  }

  @override
  Future<bool> setLocked({
    required String packageName,
    required bool locked,
  }) {
    return _guard(
      () => _bridge.setAppLocked(packageName: packageName, locked: locked),
      'Could not update that app.',
    );
  }

  InstalledApp _toInstalledApp(Map<Object?, Object?> raw) {
    return InstalledApp(
      packageName: raw['packageName'] as String? ?? '',
      appName: raw['appName'] as String? ?? '',
      isSystemApp: raw['isSystemApp'] as bool? ?? false,
      icon: raw['icon'] as Uint8List?,
    );
  }

  Future<T> _guard<T>(Future<T> Function() call, String message) async {
    try {
      return await call();
    } on MissingPluginException {
      throw const AppInventoryException(
        'The native layer is unavailable. Samir Lock only runs on Android.',
      );
    } on PlatformException catch (error) {
      throw AppInventoryException(error.message ?? message);
    }
  }
}
