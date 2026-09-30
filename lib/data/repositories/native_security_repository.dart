import 'package:flutter/services.dart';

import '../../domain/repositories/security_repository.dart';
import '../bridge/native_bridge.dart';

/// [SecurityRepository] backed by the Android authentication layer.
class NativeSecurityRepository implements SecurityRepository {
  const NativeSecurityRepository([this._bridge = const NativeBridge()]);

  final NativeBridge _bridge;

  @override
  Future<SecurityStatus> loadStatus() async {
    final raw = await _guard(
      _bridge.getSecurityStatus,
      'Could not check your PIN settings.',
    );

    return _toStatus(raw);
  }

  @override
  Future<SecurityStatus> setBiometricEnabled(bool enabled) async {
    final raw = await _guard(
      () => _bridge.setBiometricEnabled(enabled),
      'Could not change the fingerprint setting.',
    );
    return _toStatus(raw);
  }

  @override
  Future<SecurityStatus> setNotificationPrivacyEnabled(bool enabled) async {
    final raw = await _guard(
      () => _bridge.setNotificationPrivacyEnabled(enabled),
      'Could not change notification privacy.',
    );
    return _toStatus(raw);
  }

  @override
  Future<bool> openNotificationAccess() {
    return _guard(
      _bridge.openNotificationAccess,
      'Could not open notification access settings.',
    );
  }

  @override
  Future<SecurityStatus> setDiagnosticsEnabled(bool enabled) async {
    final raw = await _guard(
      () => _bridge.setDiagnosticsEnabled(enabled),
      'Could not change troubleshooting logs.',
    );
    return _toStatus(raw);
  }

  @override
  Future<List<PopupWarning>> loadPopupWarnings() async {
    final raw = await _guard(
      _bridge.getPopupWarnings,
      'Could not check notification pop-up settings.',
    );

    return raw
        .map(
          (entry) => PopupWarning(
            packageName: entry['packageName'] as String? ?? '',
            appName: entry['appName'] as String? ?? '',
            channelId: entry['channelId'] as String? ?? '',
          ),
        )
        .where((warning) => warning.packageName.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<bool> openChannelSettings({
    required String packageName,
    required String channelId,
  }) {
    return _guard(
      () => _bridge.openChannelSettings(
        packageName: packageName,
        channelId: channelId,
      ),
      'Could not open notification settings for that app.',
    );
  }

  SecurityStatus _toStatus(Map<String, Object?> raw) {
    final diagnostics =
        (raw['notificationPrivacyDiagnostics'] as Map?)?.cast<Object?, Object?>();

    return SecurityStatus(
      hasPin: raw['hasPin'] as bool? ?? false,
      biometric: BiometricAvailability.fromWireName(raw['biometric'] as String?),
      isBiometricEnabled: raw['biometricEnabled'] as bool? ?? true,
      freeAttempts: raw['freeAttempts'] as int? ?? 0,
      failedAttempts: raw['failedAttempts'] as int? ?? 0,
      isNotificationPrivacyEnabled:
          raw['notificationPrivacyEnabled'] as bool? ?? false,
      isNotificationAccessGranted:
          raw['notificationAccessGranted'] as bool? ?? false,
      notificationPrivacyBlocker: NotificationPrivacyBlocker.fromWireName(
        raw['notificationPrivacyBlocker'] as String?,
      ),
      notificationsSeen: diagnostics?['seen'] as int? ?? 0,
      notificationsHidden: diagnostics?['hidden'] as int? ?? 0,
      isDiagnosticsEnabled: raw['diagnosticsEnabled'] as bool? ?? false,
    );
  }

  @override
  Future<bool> openPinSetup() {
    return _guard(
      _bridge.openPinSetup,
      'Could not open the PIN screen.',
    );
  }

  Future<T> _guard<T>(Future<T> Function() call, String message) async {
    try {
      return await call();
    } on MissingPluginException {
      throw const SecurityException(
        'The native layer is unavailable. Samir Lock only runs on Android.',
      );
    } on PlatformException catch (error) {
      throw SecurityException(error.message ?? message);
    }
  }
}
