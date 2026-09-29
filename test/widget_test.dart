import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samir_lock/app.dart';
import 'package:samir_lock/domain/repositories/security_repository.dart';
import 'package:samir_lock/presentation/screens/security_settings_screen.dart';
import 'package:samir_lock/presentation/widgets/app_list_tile.dart';
import 'package:samir_lock/presentation/widgets/status_hero_card.dart';

import 'fakes/fake_app_inventory_repository.dart';
import 'fakes/fake_permission_repository.dart';
import 'fakes/fake_protection_repository.dart';
import 'fakes/fake_security_repository.dart';

void main() {
  /// The dashboard and settings are taller than the default test viewport, and
  /// a lazily built list never creates what is below the fold.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// The app opens past the permission gate, on the dashboard.
  Widget buildApp({
    FakeAppInventoryRepository? inventory,
    FakeProtectionRepository? protection,
    FakeSecurityRepository? security,
  }) {
    return SamirLockApp(
      inventoryRepository: inventory ?? FakeAppInventoryRepository(),
      permissionRepository: FakePermissionRepository.allGranted(),
      protectionRepository: protection ?? FakeProtectionRepository(),
      securityRepository: security ?? FakeSecurityRepository(hasPin: true),
    );
  }

  Future<void> goToTab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(NavigationDestination, label));
    await tester.pumpAndSettle();
  }

  Finder firstAppSwitch() => find.descendant(
        of: find.byType(AppListTile).first,
        matching: find.byType(Switch),
      );

  group('dashboard', () {
    testWidgets('opens on the dashboard with the three tabs', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Samir Lock'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Apps'), findsOneWidget);
      expect(
        find.widgetWithText(NavigationDestination, 'Security'),
        findsOneWidget,
      );
    });

    testWidgets('reports whether protection is running', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        buildApp(protection: FakeProtectionRepository(isEnabled: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protected'), findsOneWidget);
    });

    testWidgets('says it is not protected when the guard is off', (
      tester,
    ) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Not protected'), findsOneWidget);
    });

    testWidgets('shows the locked apps and the counts', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        buildApp(
          inventory: FakeAppInventoryRepository(
            lockedPackages: {'com.example.chat'},
          ),
          protection: FakeProtectionRepository(isEnabled: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 locked app'), findsOneWidget);
      expect(
        find.text('1 app asks to be unlocked when opened.'),
        findsOneWidget,
      );
    });

    testWidgets('invites the user to lock something when nothing is', (
      tester,
    ) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('No apps locked yet'), findsOneWidget);
    });

    testWidgets('a quick action moves to the apps tab', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage locked apps'));
      await tester.pumpAndSettle();

      expect(find.byType(AppListTile), findsWidgets);
    });
  });

  group('protection switch', () {
    testWidgets('turning it on needs no confirmation', (tester) async {
      useTallSurface(tester);
      final protection = FakeProtectionRepository();

      await tester.pumpWidget(buildApp(protection: protection));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(StatusHeroCard.switchKey));
      await tester.pumpAndSettle();

      expect(protection.setEnabledCalls, [true]);
      expect(find.text('Protected'), findsOneWidget);
    });

    testWidgets('turning it off asks first, and can be cancelled', (
      tester,
    ) async {
      useTallSurface(tester);
      final protection = FakeProtectionRepository(isEnabled: true);

      await tester.pumpWidget(buildApp(protection: protection));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(StatusHeroCard.switchKey));
      await tester.pumpAndSettle();

      expect(find.text('Turn protection off?'), findsOneWidget);

      await tester.tap(find.text('Keep it on'));
      await tester.pumpAndSettle();

      expect(protection.setEnabledCalls, isEmpty);
      expect(find.text('Protected'), findsOneWidget);
    });

    testWidgets('confirming the warning turns it off', (tester) async {
      useTallSurface(tester);
      final protection = FakeProtectionRepository(isEnabled: true);

      await tester.pumpWidget(buildApp(protection: protection));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(StatusHeroCard.switchKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn off'));
      await tester.pumpAndSettle();

      expect(protection.setEnabledCalls, [false]);
      expect(find.text('Not protected'), findsOneWidget);
    });

    testWidgets('cannot be switched on without a PIN', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        buildApp(
          protection: FakeProtectionRepository(hasPin: false),
          security: FakeSecurityRepository(hasPin: false),
        ),
      );
      await tester.pumpAndSettle();

      final toggle = tester.widget<Switch>(
        find.byKey(StatusHeroCard.switchKey),
      );
      expect(toggle.onChanged, isNull);
      expect(find.text('Create a PIN to turn protection on.'), findsOneWidget);
    });
  });

  group('apps tab', () {
    testWidgets('renders the installed apps with their lock state', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          inventory: FakeAppInventoryRepository(
            lockedPackages: {'com.example.chat'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await goToTab(tester, 'Apps');

      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Locked (1)'), findsOneWidget);
    });

    testWidgets('toggling an app persists it', (tester) async {
      final repository = FakeAppInventoryRepository();

      await tester.pumpWidget(buildApp(inventory: repository));
      await tester.pumpAndSettle();
      await goToTab(tester, 'Apps');

      await tester.tap(firstAppSwitch());
      await tester.pumpAndSettle();

      expect(repository.lockedPackages, hasLength(1));
      expect(find.text('Locked (1)'), findsOneWidget);
    });

    testWidgets('searching narrows the list', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await goToTab(tester, 'Apps');

      await tester.enterText(find.byType(TextField), 'gall');
      await tester.pumpAndSettle();

      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Chat'), findsNothing);
    });

    testWidgets('shows an error state with a retry action', (tester) async {
      await tester.pumpWidget(
        buildApp(inventory: FakeAppInventoryRepository(failOnLoad: true)),
      );
      await tester.pumpAndSettle();
      await goToTab(tester, 'Apps');

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('security tab', () {
    testWidgets('offers to create a PIN when there is none', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        buildApp(security: FakeSecurityRepository(hasPin: false)),
      );
      await tester.pumpAndSettle();
      await goToTab(tester, 'Security');

      expect(find.text('Create a PIN'), findsOneWidget);
    });

    testWidgets('opens the native PIN screen', (tester) async {
      useTallSurface(tester);
      final security = FakeSecurityRepository(hasPin: true);

      await tester.pumpWidget(buildApp(security: security));
      await tester.pumpAndSettle();
      await goToTab(tester, 'Security');

      expect(find.text('Change PIN'), findsOneWidget);
      await tester.tap(find.byKey(SecuritySettingsScreen.changePinKey));
      await tester.pumpAndSettle();

      expect(security.pinSetupRequests, 1);
    });

    testWidgets('the biometric toggle reaches the native layer', (
      tester,
    ) async {
      useTallSurface(tester);
      final security = FakeSecurityRepository(hasPin: true);

      await tester.pumpWidget(buildApp(security: security));
      await tester.pumpAndSettle();
      await goToTab(tester, 'Security');

      await tester.tap(find.byKey(SecuritySettingsScreen.biometricSwitchKey));
      await tester.pumpAndSettle();

      expect(security.biometricCalls, [false]);
      expect(security.isBiometricEnabled, isFalse);
    });

    testWidgets('the biometric toggle is disabled without a sensor', (
      tester,
    ) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        buildApp(
          security: FakeSecurityRepository(
            hasPin: true,
            biometric: BiometricAvailability.unavailable,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await goToTab(tester, 'Security');

      final toggle = tester.widget<Switch>(
        find.byKey(SecuritySettingsScreen.biometricSwitchKey),
      );
      expect(toggle.onChanged, isNull);
      expect(
        find.text('This device does not support fingerprint unlock.'),
        findsOneWidget,
      );
    });

    testWidgets('hiding notifications needs notification access first', (
      tester,
    ) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        buildApp(
          security: FakeSecurityRepository(
            hasPin: true,
            isNotificationAccessGranted: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await goToTab(tester, 'Security');

      final toggle = tester.widget<Switch>(
        find.byKey(SecuritySettingsScreen.notificationPrivacyKey),
      );
      expect(toggle.onChanged, isNull);
      expect(find.text('Grant notification access'), findsOneWidget);
    });

    testWidgets('opens the notification access screen', (tester) async {
      useTallSurface(tester);
      final security = FakeSecurityRepository(
        hasPin: true,
        isNotificationAccessGranted: false,
      );

      await tester.pumpWidget(buildApp(security: security));
      await tester.pumpAndSettle();
      await goToTab(tester, 'Security');

      await tester.tap(find.byKey(SecuritySettingsScreen.notificationAccessKey));
      await tester.pumpAndSettle();

      expect(security.notificationAccessRequests, 1);
    });

    testWidgets('turning notification hiding on reaches the native layer', (
      tester,
    ) async {
      useTallSurface(tester);
      final security = FakeSecurityRepository(hasPin: true);

      await tester.pumpWidget(buildApp(security: security));
      await tester.pumpAndSettle();
      await goToTab(tester, 'Security');

      await tester.tap(
        find.byKey(SecuritySettingsScreen.notificationPrivacyKey),
      );
      await tester.pumpAndSettle();

      expect(security.notificationPrivacyCalls, [true]);
      expect(security.isNotificationPrivacyEnabled, isTrue);
      expect(find.text('Grant notification access'), findsNothing);
    });

    testWidgets('explains the wrong-PIN protection', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        buildApp(security: FakeSecurityRepository(hasPin: true)),
      );
      await tester.pumpAndSettle();
      await goToTab(tester, 'Security');

      expect(find.text('Wrong PIN protection'), findsOneWidget);
      expect(find.textContaining('After 4 wrong attempts'), findsOneWidget);
    });
  });
}
