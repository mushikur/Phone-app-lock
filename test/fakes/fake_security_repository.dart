import 'package:samir_lock/domain/repositories/security_repository.dart';

/// In-memory stand-in for the native authentication layer.
///
/// Note what it cannot do, because the real interface cannot either: there is no
/// way to submit a PIN, read a PIN, or release a lock from Dart.
class FakeSecurityRepository implements SecurityRepository {
  FakeSecurityRepository({
    this.hasPin = false,
    this.biometric = BiometricAvailability.available,
    this.failOnLoad = false,
    this.pinSetupOpens = true,
  });

  bool hasPin;
  BiometricAvailability biometric;
  final bool failOnLoad;
  final bool pinSetupOpens;

  int pinSetupRequests = 0;

  @override
  Future<SecurityStatus> loadStatus() async {
    if (failOnLoad) {
      throw const SecurityException('Could not check your PIN settings.');
    }
    return SecurityStatus(hasPin: hasPin, biometric: biometric);
  }

  @override
  Future<bool> openPinSetup() async {
    pinSetupRequests++;
    return pinSetupOpens;
  }
}
