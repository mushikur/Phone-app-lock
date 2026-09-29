/// Whether background protection is on, and whether it is able to run.
class ProtectionStatus {
  const ProtectionStatus({
    required this.isEnabled,
    required this.isRunning,
    required this.canRun,
  });

  const ProtectionStatus.unknown()
      : isEnabled = false,
        isRunning = false,
        canRun = false;

  /// The user switched protection on.
  final bool isEnabled;

  /// The guard service is currently up.
  final bool isRunning;

  /// The permissions protection depends on are granted.
  final bool canRun;
}

/// Starts and stops the native guard, and reports its state.
abstract interface class ProtectionRepository {
  Future<ProtectionStatus> loadStatus();

  /// Switches protection on or off, returning the resulting status.
  Future<ProtectionStatus> setEnabled(bool enabled);
}

/// Raised when the native layer cannot satisfy a protection request.
class ProtectionException implements Exception {
  const ProtectionException(this.message);

  final String message;

  @override
  String toString() => 'ProtectionException: $message';
}
