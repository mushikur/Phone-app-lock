/// The phone makers whose power management needs its own instruction.
///
/// Used only to word guidance correctly. Samir Lock never behaves differently
/// on a given brand, and never tries to work around a restriction.
enum DeviceVendor {
  samsung('samsung'),
  xiaomi('xiaomi'),
  oppo('oppo'),
  oneplus('oneplus'),
  vivo('vivo'),
  realme('realme'),
  huawei('huawei'),
  motorola('motorola'),
  google('google'),
  other('other');

  const DeviceVendor(this.wireName);

  final String wireName;

  static DeviceVendor fromWireName(String? value) {
    for (final vendor in DeviceVendor.values) {
      if (vendor.wireName == value) return vendor;
    }
    return DeviceVendor.other;
  }
}

/// What this phone is likely to do to a background service.
class DeviceCompatibility {
  const DeviceCompatibility({
    required this.vendor,
    required this.sdkInt,
    required this.androidRelease,
    required this.isBackgroundRestricted,
    required this.isIgnoringBatteryOptimizations,
    required this.needsBackgroundGuidance,
  });

  const DeviceCompatibility.unknown()
      : vendor = DeviceVendor.other,
        sdkInt = 0,
        androidRelease = '',
        isBackgroundRestricted = false,
        isIgnoringBatteryOptimizations = false,
        needsBackgroundGuidance = false;

  final DeviceVendor vendor;
  final int sdkInt;
  final String androidRelease;

  /// Android says this app cannot run freely in the background.
  final bool isBackgroundRestricted;

  final bool isIgnoringBatteryOptimizations;

  /// Whether battery guidance is worth showing on this phone at all.
  final bool needsBackgroundGuidance;

  /// Android 13 and later ask for notification permission at runtime.
  bool get needsNotificationPermission => sdkInt >= 33;
}

/// Reads what the phone itself will allow.
abstract interface class DeviceRepository {
  Future<DeviceCompatibility> loadCompatibility();
}
