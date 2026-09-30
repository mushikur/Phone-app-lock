import 'package:flutter_test/flutter_test.dart';
import 'package:samir_lock/application/setup_controller.dart';
import 'package:samir_lock/domain/entities/app_permission.dart';
import 'package:samir_lock/domain/entities/setup_item.dart';
import 'package:samir_lock/domain/repositories/device_repository.dart';
import 'package:samir_lock/domain/repositories/security_repository.dart';

import 'fakes/fake_device_repository.dart';
import 'fakes/fake_permission_repository.dart';
import 'fakes/fake_security_repository.dart';

void main() {
  SetupController build({
    FakePermissionRepository? permissions,
    FakeSecurityRepository? security,
    FakeDeviceRepository? device,
  }) {
    return SetupController(
      permissions: permissions ?? FakePermissionRepository.allGranted(),
      security: security ?? FakeSecurityRepository(hasPin: true),
      device: device ?? FakeDeviceRepository(),
    );
  }

  SetupItem itemOf(SetupController controller, SetupItemId id) =>
      controller.state.items.firstWhere((item) => item.id == id);

  group('required items', () {
    test('a fresh install needs usage access and the overlay', () async {
      final controller = build(permissions: FakePermissionRepository());

      await controller.refresh();

      expect(controller.state.isReady, isFalse);
      expect(controller.state.requiredItems, hasLength(2));
      expect(
        controller.state.requiredItems.every((item) => item.needsAction),
        isTrue,
      );
    });

    test('is ready once the required items are granted', () async {
      final controller = build(
        permissions: FakePermissionRepository.requiredOnly(),
      );

      await controller.refresh();

      expect(controller.state.isReady, isTrue);
    });

    test('an outstanding optional item does not block readiness', () async {
      // Recommended items must never say "action required": that trains people
      // to ignore the warning that matters.
      final controller = build(
        permissions: FakePermissionRepository.requiredOnly(),
        device: FakeDeviceRepository.restrictive(),
      );

      await controller.refresh();

      expect(controller.state.isReady, isTrue);
      expect(controller.state.outstandingCount, greaterThan(0));
    });
  });

  group('items that only apply sometimes', () {
    test('notification permission is not asked for below Android 13', () async {
      final controller = build(
        permissions: FakePermissionRepository(),
        device: FakeDeviceRepository(sdkInt: 31),
      );

      await controller.refresh();

      expect(
        itemOf(controller, SetupItemId.notifications).status,
        SetupItemStatus.notApplicable,
      );
    });

    test('notification permission applies on Android 13 and later', () async {
      final controller = build(
        permissions: FakePermissionRepository(),
        device: FakeDeviceRepository(sdkInt: 33),
      );

      await controller.refresh();

      expect(
        itemOf(controller, SetupItemId.notifications).status,
        SetupItemStatus.actionNeeded,
      );
    });

    test('notification access is hidden until the user wants hiding', () async {
      final controller = build(
        security: FakeSecurityRepository(
          hasPin: true,
          isNotificationAccessGranted: false,
        ),
      );

      await controller.refresh();

      expect(
        itemOf(controller, SetupItemId.notificationAccess).status,
        SetupItemStatus.notApplicable,
      );
    });

    test('notification access is asked for once hiding is wanted', () async {
      final controller = build(
        security: FakeSecurityRepository(
          hasPin: true,
          isNotificationPrivacyEnabled: true,
          isNotificationAccessGranted: false,
        ),
      );

      await controller.refresh();

      expect(
        itemOf(controller, SetupItemId.notificationAccess).status,
        SetupItemStatus.actionNeeded,
      );
    });

    test('pop-up configuration only appears for apps that can pop up', () async {
      final without = build();
      await without.refresh();
      expect(
        itemOf(without, SetupItemId.notificationPopups).status,
        SetupItemStatus.notApplicable,
      );

      final with_ = build(
        security: FakeSecurityRepository(
          hasPin: true,
          popupWarnings: const [
            PopupWarning(
              packageName: 'com.example.chat',
              appName: 'Chat',
              channelId: 'messages',
            ),
          ],
        ),
      );
      await with_.refresh();
      final item = itemOf(with_, SetupItemId.notificationPopups);
      expect(item.status, SetupItemStatus.actionNeeded);
      expect(item.detail, contains('Chat'));
    });
  });

  group('background guidance', () {
    test('is not shown on a phone that does not need it', () async {
      final controller = build(device: FakeDeviceRepository());

      await controller.refresh();

      expect(
        itemOf(controller, SetupItemId.background).status,
        SetupItemStatus.notApplicable,
      );
    });

    test('is shown where power management gets in the way', () async {
      final controller = build(
        permissions: FakePermissionRepository.requiredOnly(),
        device: FakeDeviceRepository.restrictive(),
      );

      await controller.refresh();

      expect(
        itemOf(controller, SetupItemId.background).status,
        SetupItemStatus.actionNeeded,
      );
    });

    test('says something different when Android reports a restriction', () async {
      final controller = build(
        permissions: FakePermissionRepository.requiredOnly(),
        device: FakeDeviceRepository(
          vendor: DeviceVendor.samsung,
          isBackgroundRestricted: true,
          isIgnoringBatteryOptimizations: false,
          needsBackgroundGuidance: true,
        ),
      );

      await controller.refresh();

      expect(
        itemOf(controller, SetupItemId.background).description,
        contains('currently stopping'),
      );
    });

    test('the hint names the right place for each phone', () async {
      final cases = {
        DeviceVendor.samsung: 'Never sleeping apps',
        DeviceVendor.xiaomi: 'Autostart',
        DeviceVendor.oppo: 'background activity',
        DeviceVendor.vivo: 'Autostart',
        DeviceVendor.huawei: 'App launch',
        DeviceVendor.google: 'Unrestricted',
      };

      for (final entry in cases.entries) {
        final controller = build(
          device: FakeDeviceRepository.restrictive(vendor: entry.key),
        );
        await controller.refresh();

        expect(
          controller.backgroundHint(),
          contains(entry.value),
          reason: 'for ${entry.key}',
        );
      }
    });
  });

  group('recovery', () {
    test('a permission revoked later comes back as an action', () async {
      final permissions = FakePermissionRepository.requiredOnly();
      final controller = build(permissions: permissions);
      await controller.refresh();
      expect(controller.state.isReady, isTrue);

      // The user turns it off in Android settings.
      permissions.statuses[AppPermission.usageAccess] = PermissionStatus.denied;
      await controller.refresh(showSpinner: false);

      expect(controller.state.isReady, isFalse);
      expect(itemOf(controller, SetupItemId.usageAccess).needsAction, isTrue);
    });

    test('a failing native layer does not throw or wipe what is known', () async {
      final controller = build(permissions: FakePermissionRepository());
      await controller.refresh();
      final before = controller.state.items.length;

      final failing = build(
        permissions: FakePermissionRepository(failOnLoad: true),
      );
      await failing.refresh();

      expect(failing.state.isLoading, isFalse);
      expect(before, greaterThan(0));
    });
  });
}
