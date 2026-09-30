import 'package:flutter/services.dart';

import '../../domain/repositories/device_repository.dart';
import '../bridge/native_bridge.dart';

/// [DeviceRepository] backed by the Android layer.
class NativeDeviceRepository implements DeviceRepository {
  const NativeDeviceRepository([this._bridge = const NativeBridge()]);

  final NativeBridge _bridge;

  @override
  Future<DeviceCompatibility> loadCompatibility() async {
    try {
      final raw = await _bridge.getDeviceCompatibility();
      return DeviceCompatibility(
        vendor: DeviceVendor.fromWireName(raw['vendor'] as String?),
        sdkInt: raw['sdkInt'] as int? ?? 0,
        androidRelease: raw['androidRelease'] as String? ?? '',
        isBackgroundRestricted: raw['isBackgroundRestricted'] as bool? ?? false,
        isIgnoringBatteryOptimizations:
            raw['isIgnoringBatteryOptimizations'] as bool? ?? false,
        needsBackgroundGuidance: raw['needsBackgroundGuidance'] as bool? ?? false,
      );
    } on MissingPluginException {
      // Not Android, or the native layer is unavailable. Reporting nothing is
      // better than reporting a guess about the phone.
      return const DeviceCompatibility.unknown();
    } on PlatformException {
      return const DeviceCompatibility.unknown();
    }
  }
}
