import 'package:samir_lock/domain/repositories/device_repository.dart';

/// In-memory stand-in for what the phone reports about itself.
class FakeDeviceRepository implements DeviceRepository {
  FakeDeviceRepository({
    this.vendor = DeviceVendor.google,
    this.sdkInt = 34,
    this.isBackgroundRestricted = false,
    this.isIgnoringBatteryOptimizations = true,
    this.needsBackgroundGuidance = false,
  });

  final DeviceVendor vendor;
  final int sdkInt;
  final bool isBackgroundRestricted;
  final bool isIgnoringBatteryOptimizations;
  final bool needsBackgroundGuidance;

  /// A phone whose power management stops background services.
  factory FakeDeviceRepository.restrictive({
    DeviceVendor vendor = DeviceVendor.xiaomi,
  }) {
    return FakeDeviceRepository(
      vendor: vendor,
      isIgnoringBatteryOptimizations: false,
      needsBackgroundGuidance: true,
    );
  }

  @override
  Future<DeviceCompatibility> loadCompatibility() async {
    return DeviceCompatibility(
      vendor: vendor,
      sdkInt: sdkInt,
      androidRelease: '$sdkInt',
      isBackgroundRestricted: isBackgroundRestricted,
      isIgnoringBatteryOptimizations: isIgnoringBatteryOptimizations,
      needsBackgroundGuidance: needsBackgroundGuidance,
    );
  }
}
