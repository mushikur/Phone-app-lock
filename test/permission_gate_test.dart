import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samir_lock/app.dart';
import 'package:samir_lock/domain/entities/app_permission.dart';
import 'package:samir_lock/presentation/screens/setup_screen.dart';

import 'fakes/fake_app_inventory_repository.dart';
import 'fakes/fake_device_repository.dart';
import 'fakes/fake_permission_repository.dart';
import 'fakes/fake_protection_repository.dart';
import 'fakes/fake_security_repository.dart';

void main() {
  /// The setup list does not fit the default 800px test viewport, and a lazily
  /// built ListView never creates the rows below the fold.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildApp({
    required FakePermissionRepository permissions,
    FakeAppInventoryRepository? inventory,
    FakeSecurityRepository? security,
    FakeDeviceRepository? device,
  }) {
    return SamirLockApp(
      inventoryRepository: inventory ?? FakeAppInventoryRepository(),
      permissionRepository: permissions,
      protectionRepository: FakeProtectionRepository(),
      securityRepository: security ?? FakeSecurityRepository(hasPin: true),
      deviceRepository: device ?? FakeDeviceRepository(),
    );
  }

  testWidgets('a fresh install opens on setup, not the app list', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp(permissions: FakePermissionRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Lock your private apps'), findsOneWidget);
    expect(find.text('See which app is open'), findsOneWidget);
    expect(find.text('Show the lock screen'), findsOneWidget);
  });

  testWidgets('says how many actions remain', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp(permissions: FakePermissionRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('actions required'), findsOneWidget);
  });

  testWidgets('required and optional items are separated and labelled', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp(permissions: FakePermissionRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsWidgets);
    // Status is readable as words, not just colour.
    expect(find.text('Required'), findsWidgets);
  });

  testWidgets('Continue is disabled until the required items are granted', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildApp(permissions: FakePermissionRepository()));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(SetupScreen.continueKey),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('to continue'), findsOneWidget);
  });

  testWidgets('granted items read Enabled and say Ready', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      buildApp(permissions: FakePermissionRepository.allGranted()),
    );
    await tester.pumpAndSettle();

    // Required permissions were already satisfied on the first read, so the
    // gate goes straight to the dashboard.
    expect(find.text('Samir Lock'), findsWidgets);
    expect(find.text('Lock your private apps'), findsNothing);
  });

  testWidgets('tapping an action hands off to Android settings', (tester) async {
    useTallSurface(tester);
    final permissions = FakePermissionRepository();

    await tester.pumpWidget(buildApp(permissions: permissions));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('setup-action-usageAccess')));
    await tester.pumpAndSettle();

    expect(permissions.openedSettings, contains(AppPermission.usageAccess));
  });

  testWidgets('a revoked permission reappears as an action', (tester) async {
    useTallSurface(tester);
    final permissions = FakePermissionRepository.requiredOnly();

    await tester.pumpWidget(buildApp(permissions: permissions));
    await tester.pumpAndSettle();
    // Everything required was granted, so the app list opened.
    expect(find.text('Samir Lock'), findsWidgets);

    // The user turns usage access off in Android settings and returns.
    permissions.statuses[AppPermission.usageAccess] = PermissionStatus.denied;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // The dashboard surfaces it rather than silently carrying on.
    expect(find.textContaining('missing a permission'), findsOneWidget);
  });

  testWidgets('background guidance is shown only where it is needed', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      buildApp(
        permissions: FakePermissionRepository(),
        device: FakeDeviceRepository.restrictive(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keep running in the background'), findsOneWidget);
    expect(find.textContaining('Autostart'), findsOneWidget);
  });

  testWidgets('background guidance is absent on a phone that does not need it', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      buildApp(
        permissions: FakePermissionRepository(),
        device: FakeDeviceRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keep running in the background'), findsNothing);
  });
}
