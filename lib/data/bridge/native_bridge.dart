import 'package:flutter/services.dart';

/// Thin typed wrapper over the single MethodChannel shared with the Android layer.
///
/// Keeping the channel name and method names in one place means the rest of the
/// Dart code never touches [MethodChannel] directly.
class NativeBridge {
  const NativeBridge([this.channel = _defaultChannel]);

  static const MethodChannel _defaultChannel =
      MethodChannel('com.samirlock.app/bridge');

  final MethodChannel channel;

  Future<List<Map<Object?, Object?>>> getInstalledApps() async {
    final apps = await channel.invokeListMethod<Map<Object?, Object?>>(
      'getInstalledApps',
    );
    return apps ?? const [];
  }

  Future<List<String>> getLockedPackages() async {
    final packages = await channel.invokeListMethod<String>('getLockedPackages');
    return packages ?? const [];
  }

  Future<bool> setAppLocked({
    required String packageName,
    required bool locked,
  }) async {
    final result = await channel.invokeMethod<bool>('setAppLocked', {
      'packageName': packageName,
      'locked': locked,
    });
    return result ?? locked;
  }

  Future<Map<String, String>> getPermissionStatuses() async {
    final statuses = await channel.invokeMapMethod<String, String>(
      'getPermissionStatuses',
    );
    return statuses ?? const {};
  }

  Future<bool> openPermissionSettings(String permission) async {
    final opened = await channel.invokeMethod<bool>('openPermissionSettings', {
      'permission': permission,
    });
    return opened ?? false;
  }

  Future<String?> requestNotificationPermission() {
    return channel.invokeMethod<String>('requestNotificationPermission');
  }

  Future<Map<String, Object?>> getProtectionStatus() async {
    final status = await channel.invokeMapMethod<String, Object?>(
      'getProtectionStatus',
    );
    return status ?? const {};
  }

  Future<Map<String, Object?>> getSecurityStatus() async {
    final status = await channel.invokeMapMethod<String, Object?>(
      'getSecurityStatus',
    );
    return status ?? const {};
  }

  /// Opens the native PIN screen. The PIN itself never comes back across here.
  Future<bool> openPinSetup() async {
    final opened = await channel.invokeMethod<bool>('openPinSetup');
    return opened ?? false;
  }

  Future<Map<String, Object?>> setBiometricEnabled(bool enabled) async {
    final status = await channel.invokeMapMethod<String, Object?>(
      'setBiometricEnabled',
      {'enabled': enabled},
    );
    return status ?? const {};
  }

  Future<Map<String, Object?>> setNotificationPrivacyEnabled(bool enabled) async {
    final status = await channel.invokeMapMethod<String, Object?>(
      'setNotificationPrivacyEnabled',
      {'enabled': enabled},
    );
    return status ?? const {};
  }

  Future<bool> openNotificationAccess() async {
    final opened = await channel.invokeMethod<bool>('openNotificationAccess');
    return opened ?? false;
  }

  Future<Map<String, Object?>> setDiagnosticsEnabled(bool enabled) async {
    final status = await channel.invokeMapMethod<String, Object?>(
      'setDiagnosticsEnabled',
      {'enabled': enabled},
    );
    return status ?? const {};
  }

  Future<List<Map<Object?, Object?>>> getPopupWarnings() async {
    final warnings = await channel.invokeListMethod<Map<Object?, Object?>>(
      'getPopupWarnings',
    );
    return warnings ?? const [];
  }

  Future<bool> openChannelSettings({
    required String packageName,
    required String channelId,
  }) async {
    final opened = await channel.invokeMethod<bool>('openChannelSettings', {
      'packageName': packageName,
      'channelId': channelId,
    });
    return opened ?? false;
  }

  Future<Map<String, Object?>> setProtectionEnabled(bool enabled) async {
    final status = await channel.invokeMapMethod<String, Object?>(
      'setProtectionEnabled',
      {'enabled': enabled},
    );
    return status ?? const {};
  }
}
