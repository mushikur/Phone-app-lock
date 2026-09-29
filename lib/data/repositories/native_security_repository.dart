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

    return SecurityStatus(
      hasPin: raw['hasPin'] as bool? ?? false,
      biometric: BiometricAvailability.fromWireName(raw['biometric'] as String?),
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
