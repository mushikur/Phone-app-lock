import 'package:samir_lock/domain/repositories/protection_repository.dart';

/// In-memory stand-in for the native guard service.
class FakeProtectionRepository implements ProtectionRepository {
  FakeProtectionRepository({
    this.isEnabled = false,
    this.canRun = true,
    this.failOnLoad = false,
    this.failOnWrite = false,
  });

  bool isEnabled;

  /// Whether the permissions protection depends on are granted.
  bool canRun;
  final bool failOnLoad;
  final bool failOnWrite;

  /// Every requested state change, in order.
  final List<bool> setEnabledCalls = [];

  @override
  Future<ProtectionStatus> loadStatus() async {
    if (failOnLoad) {
      throw const ProtectionException('Could not check protection.');
    }
    return _status();
  }

  @override
  Future<ProtectionStatus> setEnabled(bool enabled) async {
    setEnabledCalls.add(enabled);
    if (failOnWrite) {
      throw const ProtectionException('Could not change protection.');
    }
    // Mirrors the native side: enabling only sticks when it is allowed to run.
    isEnabled = enabled && canRun;
    return _status();
  }

  ProtectionStatus _status() => ProtectionStatus(
        isEnabled: isEnabled,
        isRunning: isEnabled,
        canRun: canRun,
      );
}
