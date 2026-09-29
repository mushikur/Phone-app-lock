import 'package:flutter/services.dart';

import '../../domain/repositories/protection_repository.dart';
import '../bridge/native_bridge.dart';

/// [ProtectionRepository] backed by the Android guard service.
class NativeProtectionRepository implements ProtectionRepository {
  const NativeProtectionRepository([this._bridge = const NativeBridge()]);

  final NativeBridge _bridge;

  @override
  Future<ProtectionStatus> loadStatus() async {
    final raw = await _guard(
      _bridge.getProtectionStatus,
      'Could not check whether protection is running.',
    );
    return _toStatus(raw);
  }

  @override
  Future<ProtectionStatus> setEnabled(bool enabled) async {
    final raw = await _guard(
      () => _bridge.setProtectionEnabled(enabled),
      'Could not change protection.',
    );
    return _toStatus(raw);
  }

  ProtectionStatus _toStatus(Map<String, Object?> raw) {
    return ProtectionStatus(
      isEnabled: raw['enabled'] as bool? ?? false,
      isRunning: raw['running'] as bool? ?? false,
      canRun: raw['canRun'] as bool? ?? false,
      hasPin: raw['hasPin'] as bool? ?? false,
    );
  }

  Future<T> _guard<T>(Future<T> Function() call, String message) async {
    try {
      return await call();
    } on MissingPluginException {
      throw const ProtectionException(
        'The native layer is unavailable. Samir Lock only runs on Android.',
      );
    } on PlatformException catch (error) {
      throw ProtectionException(error.message ?? message);
    }
  }
}
