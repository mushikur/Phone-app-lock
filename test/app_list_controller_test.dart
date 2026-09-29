import 'package:flutter_test/flutter_test.dart';
import 'package:samir_lock/application/app_list_controller.dart';

import 'fakes/fake_app_inventory_repository.dart';

void main() {
  group('AppListController', () {
    test('loads the inventory and the persisted locked set', () async {
      final repository = FakeAppInventoryRepository(
        lockedPackages: {'com.example.chat'},
      );
      final controller = AppListController(repository);

      await controller.load();

      expect(controller.state.status, AppListStatus.ready);
      expect(controller.state.totalCount, 3);
      expect(controller.state.lockedCount, 1);
    });

    test('reports an error state when the native layer fails', () async {
      final controller =
          AppListController(FakeAppInventoryRepository(failOnLoad: true));

      await controller.load();

      expect(controller.state.status, AppListStatus.error);
      expect(controller.state.errorMessage, isNotNull);
    });

    test('filters by name and by package name', () async {
      final controller = AppListController(FakeAppInventoryRepository());
      await controller.load();

      controller.setQuery('gall');
      expect(controller.state.visibleApps.single.appName, 'Gallery');

      controller.setQuery('com.android');
      expect(controller.state.visibleApps.single.appName, 'Settings');

      controller.setQuery('');
      expect(controller.state.visibleApps, hasLength(3));
    });

    test('the locked filter shows only locked apps', () async {
      final repository = FakeAppInventoryRepository(
        lockedPackages: {'com.example.gallery'},
      );
      final controller = AppListController(repository);
      await controller.load();

      controller.setFilter(AppFilter.locked);

      expect(controller.state.visibleApps.single.appName, 'Gallery');
    });

    test('toggling persists through the repository', () async {
      final repository = FakeAppInventoryRepository();
      final controller = AppListController(repository);
      await controller.load();
      final app = controller.state.apps.first;

      final error = await controller.toggleLock(app);

      expect(error, isNull);
      expect(repository.lockedPackages, contains(app.packageName));
      expect(controller.state.lockedCount, 1);

      await controller.toggleLock(app);
      expect(repository.lockedPackages, isEmpty);
      expect(controller.state.lockedCount, 0);
    });

    test('a failed toggle rolls back the optimistic update', () async {
      final repository = FakeAppInventoryRepository(failOnWrite: true);
      final controller = AppListController(repository);
      await controller.load();

      final error = await controller.toggleLock(controller.state.apps.first);

      expect(error, isNotNull);
      expect(controller.state.lockedCount, 0);
    });

    test('hasNoMatches is true only when a filter hides everything', () async {
      final controller = AppListController(FakeAppInventoryRepository());
      await controller.load();

      expect(controller.state.hasNoMatches, isFalse);

      controller.setQuery('no-such-app');
      expect(controller.state.hasNoMatches, isTrue);
    });
  });
}
