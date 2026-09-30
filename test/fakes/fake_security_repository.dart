import 'package:samir_lock/domain/repositories/security_repository.dart';

/// In-memory stand-in for the native authentication layer.
///
/// Note what it cannot do, because the real interface cannot either: there is no
/// way to submit a PIN, read a PIN, or release a lock from Dart.
class FakeSecurityRepository implements SecurityRepository {
  FakeSecurityRepository({
    this.hasPin = false,
    this.biometric = BiometricAvailability.available,
    this.isBiometricEnabled = true,
    this.failedAttempts = 0,
    this.isNotificationPrivacyEnabled = false,
    this.isNotificationAccessGranted = true,
    this.isProtectionOn = true,
    this.lockedAppCount = 2,
    this.failOnLoad = false,
    this.pinSetupOpens = true,
    this.failOnWrite = false,
    this.popupWarnings = const [],
  });

  bool hasPin;
  BiometricAvailability biometric;
  bool isBiometricEnabled;
  int failedAttempts;
  bool isNotificationPrivacyEnabled;
  bool isNotificationAccessGranted;

  /// Stand-ins for the other two preconditions the native layer checks.
  bool isProtectionOn;
  int lockedAppCount;
  final bool failOnLoad;
  final bool pinSetupOpens;
  final bool failOnWrite;

  /// Locked apps the native layer reports as still able to pop up.
  final List<PopupWarning> popupWarnings;

  int pinSetupRequests = 0;

  /// Every requested biometric preference change, in order.
  final List<bool> biometricCalls = [];

  /// Every requested notification privacy change, in order.
  final List<bool> notificationPrivacyCalls = [];

  int notificationAccessRequests = 0;

  /// Every requested diagnostics change, in order.
  final List<bool> diagnosticsCalls = [];
  bool isDiagnosticsEnabled = false;

  @override
  Future<SecurityStatus> loadStatus() async {
    if (failOnLoad) {
      throw const SecurityException('Could not check your PIN settings.');
    }
    return _status();
  }

  @override
  Future<SecurityStatus> setBiometricEnabled(bool enabled) async {
    biometricCalls.add(enabled);
    if (failOnWrite) {
      throw const SecurityException('Could not change the fingerprint setting.');
    }
    isBiometricEnabled = enabled;
    return _status();
  }

  @override
  Future<SecurityStatus> setNotificationPrivacyEnabled(bool enabled) async {
    notificationPrivacyCalls.add(enabled);
    if (failOnWrite) {
      throw const SecurityException('Could not change notification privacy.');
    }
    // Mirrors the native side: turning it on only sticks with access granted.
    isNotificationPrivacyEnabled = enabled && isNotificationAccessGranted;
    return _status();
  }

  @override
  Future<bool> openNotificationAccess() async {
    notificationAccessRequests++;
    return true;
  }

  @override
  Future<SecurityStatus> setDiagnosticsEnabled(bool enabled) async {
    diagnosticsCalls.add(enabled);
    isDiagnosticsEnabled = enabled;
    return _status();
  }

  /// Every channel settings page opened, in order.
  final List<String> channelSettingsOpened = [];

  @override
  Future<List<PopupWarning>> loadPopupWarnings() async => popupWarnings;

  @override
  Future<bool> openChannelSettings({
    required String packageName,
    required String channelId,
  }) async {
    channelSettingsOpened.add(packageName);
    return true;
  }

  /// Mirrors the native precondition order.
  NotificationPrivacyBlocker get _blocker {
    if (!isNotificationAccessGranted) return NotificationPrivacyBlocker.noAccess;
    if (!isNotificationPrivacyEnabled) return NotificationPrivacyBlocker.off;
    if (!isProtectionOn) return NotificationPrivacyBlocker.protectionOff;
    if (lockedAppCount == 0) return NotificationPrivacyBlocker.noLockedApps;
    return NotificationPrivacyBlocker.none;
  }

  SecurityStatus _status() => SecurityStatus(
        hasPin: hasPin,
        biometric: biometric,
        isBiometricEnabled: isBiometricEnabled,
        freeAttempts: 4,
        failedAttempts: failedAttempts,
        isNotificationPrivacyEnabled: isNotificationPrivacyEnabled,
        isNotificationAccessGranted: isNotificationAccessGranted,
        notificationPrivacyBlocker: _blocker,
        isDiagnosticsEnabled: isDiagnosticsEnabled,
      );

  @override
  Future<bool> openPinSetup() async {
    pinSetupRequests++;
    return pinSetupOpens;
  }
}
