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

/// Why notification hiding is not doing anything, as reported by the native
/// layer.
///
/// Hiding has several preconditions and every one of them used to fail in
/// silence; this is what lets the settings screen say which one is unmet.
enum NotificationPrivacyBlocker {
  none('none'),
  noAccess('noAccess'),
  off('off'),
  protectionOff('protectionOff'),
  noLockedApps('noLockedApps');

  const NotificationPrivacyBlocker(this.wireName);

  final String wireName;

  static NotificationPrivacyBlocker fromWireName(String? value) {
    for (final blocker in NotificationPrivacyBlocker.values) {
      if (blocker.wireName == value) return blocker;
    }
    return NotificationPrivacyBlocker.noAccess;
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
    required this.isBiometricEnabled,
    required this.freeAttempts,
    required this.failedAttempts,
    required this.isNotificationPrivacyEnabled,
    required this.isNotificationAccessGranted,
    required this.notificationPrivacyBlocker,
    this.notificationsSeen = 0,
    this.notificationsHidden = 0,
    this.isDiagnosticsEnabled = false,
  });

  const SecurityStatus.unknown()
      : hasPin = false,
        biometric = BiometricAvailability.unavailable,
        isBiometricEnabled = true,
        freeAttempts = 0,
        failedAttempts = 0,
        isNotificationPrivacyEnabled = false,
        isNotificationAccessGranted = false,
        notificationPrivacyBlocker = NotificationPrivacyBlocker.noAccess,
        notificationsSeen = 0,
        notificationsHidden = 0,
        isDiagnosticsEnabled = false;

  final bool hasPin;
  final BiometricAvailability biometric;

  /// Whether the user wants the lock screen to offer biometrics.
  ///
  /// A preference only: the PIN is required either way, and the lock screen
  /// reads this natively rather than being told what to do from here.
  final bool isBiometricEnabled;

  /// Wrong PIN attempts allowed before delays begin.
  final int freeAttempts;

  /// Consecutive wrong attempts recorded so far.
  final int failedAttempts;

  /// Notifications from locked apps are hidden while those apps are locked.
  final bool isNotificationPrivacyEnabled;

  /// Android notification access has been granted, without which hiding
  /// notifications is impossible.
  final bool isNotificationAccessGranted;

  /// What is stopping notification hiding from working, if anything.
  final NotificationPrivacyBlocker notificationPrivacyBlocker;

  /// Notifications the listener has been handed since it last started.
  ///
  /// Counts only. Nothing about what a notification said reaches this layer.
  final int notificationsSeen;

  /// Notifications it has actually taken down and replaced.
  final int notificationsHidden;

  /// Verbose logging is switched on for troubleshooting.
  ///
  /// A release build is otherwise silent, which leaves a problem that only
  /// happens on a real phone impossible to see. Off unless the user asks.
  final bool isDiagnosticsEnabled;

  /// Notifications from locked apps are actually being hidden right now.
  bool get isNotificationPrivacyActive =>
      notificationPrivacyBlocker == NotificationPrivacyBlocker.none;

  /// The device can do biometrics right now.
  bool get canUseBiometrics => biometric == BiometricAvailability.available;

  /// Biometrics are possible and the user has them switched on.
  bool get biometricsActive => canUseBiometrics && isBiometricEnabled;
}

/// Reads authentication status and opens the native PIN setup screen.
abstract interface class SecurityRepository {
  Future<SecurityStatus> loadStatus();

  /// Opens the native PIN screen.
  ///
  /// The PIN is typed there and handed straight to Keystore-backed storage; it
  /// never passes through Dart. Returns false if the screen could not be opened.
  Future<bool> openPinSetup();

  /// Turns the biometric option on or off, returning the resulting status.
  Future<SecurityStatus> setBiometricEnabled(bool enabled);

  /// Turns notification hiding on or off, returning the resulting status.
  ///
  /// Turning it on only takes effect once notification access is granted; the
  /// returned status says whether it did.
  Future<SecurityStatus> setNotificationPrivacyEnabled(bool enabled);

  /// Opens the Android screen where notification access is granted.
  Future<bool> openNotificationAccess();

  /// Turns troubleshooting logs on or off, returning the resulting status.
  Future<SecurityStatus> setDiagnosticsEnabled(bool enabled);
}

/// Raised when the native layer cannot satisfy a security request.
class SecurityException implements Exception {
  const SecurityException(this.message);

  final String message;

  @override
  String toString() => 'SecurityException: $message';
}
