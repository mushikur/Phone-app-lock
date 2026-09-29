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
    this.failOnLoad = false,
    this.pinSetupOpens = true,
    this.failOnWrite = false,
  });

  bool hasPin;
  BiometricAvailability biometric;
  bool isBiometricEnabled;
  int failedAttempts;
  bool isNotificationPrivacyEnabled;
  bool isNotificationAccessGranted;
  final bool failOnLoad;
  final bool pinSetupOpens;
  final bool failOnWrite;

  int pinSetupRequests = 0;

  /// Every requested biometric preference change, in order.
  final List<bool> biometricCalls = [];

  /// Every requested notification privacy change, in order.
  final List<bool> notificationPrivacyCalls = [];

  int notificationAccessRequests = 0;

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

  SecurityStatus _status() => SecurityStatus(
        hasPin: hasPin,
        biometric: biometric,
        isBiometricEnabled: isBiometricEnabled,
        freeAttempts: 4,
        failedAttempts: failedAttempts,
        isNotificationPrivacyEnabled: isNotificationPrivacyEnabled,
        isNotificationAccessGranted: isNotificationAccessGranted,
      );

  @override
  Future<bool> openPinSetup() async {
    pinSetupRequests++;
    return pinSetupOpens;
  }
}
