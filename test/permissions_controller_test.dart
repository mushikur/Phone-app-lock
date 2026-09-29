import 'package:flutter_test/flutter_test.dart';
import 'package:samir_lock/application/permissions_controller.dart';
import 'package:samir_lock/domain/entities/app_permission.dart';

import 'fakes/fake_permission_repository.dart';

void main() {
  group('PermissionSnapshot', () {
    test('only usage access and overlay are required', () {
      expect(AppPermission.usageAccess.isRequired, isTrue);
      expect(AppPermission.displayOverOtherApps.isRequired, isTrue);
      expect(AppPermission.notifications.isRequired, isFalse);
      expect(AppPermission.batteryOptimization.isRequired, isFalse);
    });

    test('is ready once the required permissions are satisfied', () {
      const snapshot = PermissionSnapshot({
        AppPermission.usageAccess: PermissionStatus.granted,
        AppPermission.displayOverOtherApps: PermissionStatus.granted,
        AppPermission.notifications: PermissionStatus.denied,
        AppPermission.batteryOptimization: PermissionStatus.denied,
      });

      expect(snapshot.isReady, isTrue);
      expect(snapshot.missingRequired, isEmpty);
      expect(snapshot.missingRecommended, hasLength(2));
    });

    test('an unsupported permission counts as satisfied', () {
      const snapshot = PermissionSnapshot({
        AppPermission.notifications: PermissionStatus.unsupported,
      });

      expect(snapshot.isSatisfied(AppPermission.notifications), isTrue);
      expect(snapshot.missingRecommended, [AppPermission.batteryOptimization]);
    });

    test('an unknown status defaults to denied', () {
      const snapshot = PermissionSnapshot.unknown();

      expect(snapshot.statusOf(AppPermission.usageAccess),
          PermissionStatus.denied);
      expect(snapshot.isReady, isFalse);
    });
  });

  group('PermissionsController', () {
    test('loads every permission status', () async {
      final controller =
          PermissionsController(FakePermissionRepository.requiredOnly());

      await controller.refresh();

      expect(controller.state.status, PermissionsStatus.ready);
      expect(controller.state.snapshot.isReady, isTrue);
      expect(controller.state.isReady, isTrue);
    });

    test('reports an error state when the native layer fails', () async {
      final controller =
          PermissionsController(FakePermissionRepository(failOnLoad: true));

      await controller.refresh();

      expect(controller.state.status, PermissionsStatus.error);
      expect(controller.state.errorMessage, isNotNull);
    });

    test('granting a settings-based permission opens its page', () async {
      final repository = FakePermissionRepository();
      final controller = PermissionsController(repository);
      await controller.refresh();

      final error = await controller.grant(AppPermission.usageAccess);

      expect(error, isNull);
      expect(repository.openedSettings, [AppPermission.usageAccess]);
      expect(controller.state.pending, isNull);
    });

    test('explains itself when no settings page exists on the device', () async {
      final repository = FakePermissionRepository(settingsPageExists: false);
      final controller = PermissionsController(repository);
      await controller.refresh();

      final error = await controller.grant(AppPermission.displayOverOtherApps);

      expect(error, isNotNull);
    });

    test('notifications use the system prompt first', () async {
      final repository = FakePermissionRepository();
      final controller = PermissionsController(repository);
      await controller.refresh();

      final error = await controller.grant(AppPermission.notifications);

      expect(error, isNull);
      expect(repository.notificationPrompts, 1);
      expect(repository.openedSettings, isEmpty);
      expect(
        controller.state.snapshot.statusOf(AppPermission.notifications),
        PermissionStatus.granted,
      );
    });

    test('a dismissed notification prompt falls back to settings', () async {
      final repository =
          FakePermissionRepository(notificationPromptGrants: false);
      final controller = PermissionsController(repository);
      await controller.refresh();

      final error = await controller.grant(AppPermission.notifications);

      expect(error, isNull);
      expect(repository.notificationPrompts, 1);
      expect(repository.openedSettings, [AppPermission.notifications]);
    });
  });
}
