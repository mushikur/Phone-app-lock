/// Whether the device can use biometrics, as reported by Android.
enum BiometricAvailability {
  available('AVAILABLE'),
  notEnrolled('NOT_ENROLLED'),
  temporarilyUnavailable('TEMPORARILY_UNAVAILABLE'),
  unavailable('UNAVAILABLE');

  const BiometricAvailability(this.wireName);

  final String wireName;

  static BiometricAvailability fromWireName(String? value) {
    for (final availability in BiometricAvailability.values) {
      if (availability.wireName == value) return availability;
    }
    return BiometricAvailability.unavailable;
  }
}

/// What the Flutter layer is allowed to know about authentication.
///
/// Deliberately only two facts. The PIN, its hash and the decision to release a
/// lock all stay in the native layer.
class SecurityStatus {
  const SecurityStatus({
    required this.hasPin,
    required this.biometric,
  });

  const SecurityStatus.unknown()
      : hasPin = false,
        biometric = BiometricAvailability.unavailable;

  final bool hasPin;
  final BiometricAvailability biometric;

  bool get canUseBiometrics => biometric == BiometricAvailability.available;
}

/// Reads authentication status and opens the native PIN setup screen.
abstract interface class SecurityRepository {
  Future<SecurityStatus> loadStatus();

  /// Opens the native PIN screen.
  ///
  /// The PIN is typed there and handed straight to Keystore-backed storage; it
  /// never passes through Dart. Returns false if the screen could not be opened.
  Future<bool> openPinSetup();
}

/// Raised when the native layer cannot satisfy a security request.
class SecurityException implements Exception {
  const SecurityException(this.message);

  final String message;

  @override
  String toString() => 'SecurityException: $message';
}
