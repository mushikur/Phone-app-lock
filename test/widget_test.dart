import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samir_lock/app.dart';
import 'package:samir_lock/presentation/widgets/app_list_tile.dart';
import 'package:samir_lock/presentation/widgets/protection_card.dart';
import 'package:samir_lock/presentation/widgets/security_card.dart';

import 'fakes/fake_app_inventory_repository.dart';
import 'fakes/fake_permission_repository.dart';
import 'fakes/fake_protection_repository.dart';
import 'fakes/fake_security_repository.dart';

void main() {
  /// The app list sits behind the permission gate, so these tests start from a
  /// device where the required permissions are already granted.
  Widget buildApp(
    FakeAppInventoryRepository inventory, {
    FakeProtectionRepository? protection,
    FakeSecurityRepository? security,
  }) {
    return SamirLockApp(
      inventoryRepository: inventory,
      permissionRepository: FakePermissionRepository.allGranted(),
      protectionRepository: protection ?? FakeProtectionRepository(),
      securityRepository: security ?? FakeSecurityRepository(hasPin: true),
    );
  }

  /// The lock toggle inside the first app row, as opposed to the protection
  /// master switch that also lives on this screen.
  Finder firstAppSwitch() => find.descendant(
        of: find.byType(AppListTile).first,
        matching: find.byType(Switch),
      );

  testWidgets('renders the installed apps with their lock state', (
    tester,
  ) async {
    final repository = FakeAppInventoryRepository(
      lockedPackages: {'com.example.chat'},
    );

    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('1 of 3 locked'), findsOneWidget);
  });

  testWidgets('toggling an app updates the summary and persists it', (
    tester,
  ) async {
    final repository = FakeAppInventoryRepository();

    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('0 of 3 locked'), findsOneWidget);

    await tester.tap(firstAppSwitch());
    await tester.pumpAndSettle();

    expect(find.text('1 of 3 locked'), findsOneWidget);
    expect(repository.lockedPackages, hasLength(1));
  });

  testWidgets('searching narrows the list', (tester) async {
    await tester.pumpWidget(buildApp(FakeAppInventoryRepository()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'gall');
    await tester.pumpAndSettle();

    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Chat'), findsNothing);
  });

  testWidgets('shows an error state with a retry action', (tester) async {
    await tester.pumpWidget(
      buildApp(FakeAppInventoryRepository(failOnLoad: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  group('security card', () {
    testWidgets('prompts for a PIN when none is set', (tester) async {
      await tester.pumpWidget(
        buildApp(
          FakeAppInventoryRepository(),
          security: FakeSecurityRepository(hasPin: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No PIN yet'), findsOneWidget);
      expect(find.text('Set up'), findsOneWidget);
    });

    testWidgets('opens the native PIN screen', (tester) async {
      final security = FakeSecurityRepository(hasPin: false);

      await tester.pumpWidget(
        buildApp(FakeAppInventoryRepository(), security: security),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(SecurityCard.actionKey));
      await tester.pumpAndSettle();

      expect(security.pinSetupRequests, 1);
    });

    testWidgets('offers to change an existing PIN', (tester) async {
      await tester.pumpWidget(
        buildApp(
          FakeAppInventoryRepository(),
          security: FakeSecurityRepository(hasPin: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unlock PIN'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });
  });

  group('protection card', () {
    testWidgets('starts the guard when switched on', (tester) async {
      final protection = FakeProtectionRepository();

      await tester.pumpWidget(
        buildApp(FakeAppInventoryRepository(), protection: protection),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protection is off'), findsOneWidget);

      await tester.tap(find.byKey(ProtectionCard.switchKey));
      await tester.pumpAndSettle();

      expect(protection.setEnabledCalls, [true]);
      expect(find.text('Protection is on'), findsOneWidget);
    });

    testWidgets('reports how many apps are being watched', (tester) async {
      await tester.pumpWidget(
        buildApp(
          FakeAppInventoryRepository(lockedPackages: {'com.example.chat'}),
          protection: FakeProtectionRepository(isEnabled: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Watching 1 app. It will ask to be unlocked when opened.'),
        findsOneWidget,
      );
    });

    testWidgets('does not claim to be on when the guard cannot run', (
      tester,
    ) async {
      // Regression: protection stayed switched on in storage while the service
      // was not running, and the card said "Protection is on" regardless.
      await tester.pumpWidget(
        buildApp(
          FakeAppInventoryRepository(),
          protection: FakeProtectionRepository(isEnabled: true, canRun: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protection is off'), findsOneWidget);
      expect(find.text('Protection is on'), findsNothing);
    });

    testWidgets('cannot be switched on without a PIN', (tester) async {
      await tester.pumpWidget(
        buildApp(
          FakeAppInventoryRepository(),
          protection: FakeProtectionRepository(hasPin: false),
          security: FakeSecurityRepository(hasPin: false),
        ),
      );
      await tester.pumpAndSettle();

      final toggle = tester.widget<Switch>(
        find.byKey(ProtectionCard.switchKey),
      );
      expect(toggle.onChanged, isNull);
      expect(
        find.text('Create a PIN above to turn protection on.'),
        findsOneWidget,
      );
    });

    testWidgets('cannot be switched on without permission', (tester) async {
      final protection = FakeProtectionRepository(canRun: false);

      await tester.pumpWidget(
        buildApp(FakeAppInventoryRepository(), protection: protection),
      );
      await tester.pumpAndSettle();

      final toggle = tester.widget<Switch>(
        find.byKey(ProtectionCard.switchKey),
      );
      expect(toggle.onChanged, isNull);
      expect(
        find.text(
          'Needs permission to watch your apps and show the lock screen.',
        ),
        findsOneWidget,
      );
    });
  });
}
