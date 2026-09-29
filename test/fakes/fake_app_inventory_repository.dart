import 'package:samir_lock/domain/entities/installed_app.dart';
import 'package:samir_lock/domain/repositories/app_inventory_repository.dart';

/// In-memory stand-in for the Android native layer.
class FakeAppInventoryRepository implements AppInventoryRepository {
  FakeAppInventoryRepository({
    List<InstalledApp>? apps,
    Set<String>? lockedPackages,
    this.failOnLoad = false,
    this.failOnWrite = false,
  })  : apps = apps ?? defaultApps,
        lockedPackages = lockedPackages ?? <String>{};

  static const List<InstalledApp> defaultApps = [
    InstalledApp(
      packageName: 'com.example.chat',
      appName: 'Chat',
      isSystemApp: false,
    ),
    InstalledApp(
      packageName: 'com.example.gallery',
      appName: 'Gallery',
      isSystemApp: false,
    ),
    InstalledApp(
      packageName: 'com.android.settings',
      appName: 'Settings',
      isSystemApp: true,
    ),
  ];

  final List<InstalledApp> apps;
  final Set<String> lockedPackages;
  final bool failOnLoad;
  final bool failOnWrite;

  @override
  Future<List<InstalledApp>> loadInstalledApps() async {
    if (failOnLoad) {
      throw const AppInventoryException('Could not read installed apps.');
    }
    return apps;
  }

  @override
  Future<Set<String>> loadLockedPackages() async {
    if (failOnLoad) {
      throw const AppInventoryException('Could not read locked apps.');
    }
    return lockedPackages;
  }

  @override
  Future<bool> setLocked({
    required String packageName,
    required bool locked,
  }) async {
    if (failOnWrite) {
      throw const AppInventoryException('Could not update that app.');
    }
    if (locked) {
      lockedPackages.add(packageName);
    } else {
      lockedPackages.remove(packageName);
    }
    return locked;
  }
}
