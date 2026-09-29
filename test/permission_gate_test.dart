import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samir_lock/app.dart';
import 'package:samir_lock/domain/entities/app_permission.dart';

import 'fakes/fake_app_inventory_repository.dart';
import 'fakes/fake_permission_repository.dart';
import 'fakes/fake_protection_repository.dart';
import 'fakes/fake_security_repository.dart';

void main() {
  /// The four permission tiles do not fit the default 800px test viewport, and a
  /// lazily built ListView never creates the ones below the fold. Tests that
  /// count tiles need every one of them rendered.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildApp({
    required FakePermissionRepository permissions,
    FakeAppInventoryRepository? inventory,
  }) {
    return SamirLockApp(
      inventoryRepository: inventory ?? FakeAppInventoryRepository(),
      permissionRepository: permissions,
      protectionRepository: FakeProtectionRepository(),
      securityRepository: FakeSecurityRepository(hasPin: true),
    );
  }

  testWidgets('shows setup while a required permission is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(permissions: FakePermissionRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Let us set up protection'), findsOneWidget);
    expect(find.text('See which app is open'), findsOneWidget);
    expect(find.text('Show the lock screen'), findsOneWidget);
  });

  testWidgets('required permissions read Required, others Recommended', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      buildApp(permissions: FakePermissionRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsNWidgets(2));
    expect(find.text('Recommended'), findsNWidgets(2));
    expect(find.text('Granted'), findsNothing);
  });

  testWidgets('Continue is disabled until the required permissions are granted',
      (tester) async {
    await tester.pumpWidget(
      buildApp(permissions: FakePermissionRepository()),
    );
    await tester.pumpAndSettle();

    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(continueButton.onPressed, isNull);
    expect(find.text('2 permissions still needed.'), findsOneWidget);
  });

  testWidgets('skips setup when the required permissions are already granted', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        permissions: FakePermissionRepository(
          statuses: {
            AppPermission.usageAccess: PermissionStatus.granted,
            AppPermission.displayOverOtherApps: PermissionStatus.granted,
            AppPermission.notifications: PermissionStatus.denied,
            AppPermission.batteryOptimization: PermissionStatus.denied,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Required permissions were already satisfied on the first read, so the gate
    // goes straight to the dashboard rather than showing setup.
    expect(find.text('Samir Lock'), findsWidgets);
    expect(find.text('Let us set up protection'), findsNothing);
  });

  testWidgets('granted permissions are shown as granted', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      buildApp(
        permissions: FakePermissionRepository(
          statuses: {
            AppPermission.usageAccess: PermissionStatus.denied,
            AppPermission.displayOverOtherApps: PermissionStatus.granted,
            AppPermission.notifications: PermissionStatus.unsupported,
            AppPermission.batteryOptimization: PermissionStatus.granted,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Granted'), findsNWidgets(2));
    expect(find.text('Not needed'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('One more permission to go.'), findsOneWidget);
  });

  testWidgets('tapping Allow hands off to Android settings', (tester) async {
    final permissions = FakePermissionRepository();
    await tester.pumpWidget(buildApp(permissions: permissions));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Allow').first);
    await tester.pumpAndSettle();

    expect(permissions.openedSettings, [AppPermission.usageAccess]);
  });

  testWidgets('shows an error state when permissions cannot be read', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(permissions: FakePermissionRepository(failOnLoad: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not check permissions'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
