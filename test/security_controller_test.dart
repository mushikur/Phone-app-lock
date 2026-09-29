import 'package:flutter_test/flutter_test.dart';
import 'package:samir_lock/application/security_controller.dart';
import 'package:samir_lock/domain/repositories/security_repository.dart';

import 'fakes/fake_security_repository.dart';

void main() {
  group('SecurityController', () {
    test('reports whether a PIN exists', () async {
      final controller = SecurityController(
        FakeSecurityRepository(hasPin: true),
      );

      await controller.refresh();

      expect(controller.state.loadStatus, SecurityLoadStatus.ready);
      expect(controller.state.hasPin, isTrue);
    });

    test('reports an error state when the native layer fails', () async {
      final controller = SecurityController(
        FakeSecurityRepository(failOnLoad: true),
      );

      await controller.refresh();

      expect(controller.state.loadStatus, SecurityLoadStatus.error);
      expect(controller.state.errorMessage, isNotNull);
    });

    test('only biometrics reported as available count as usable', () async {
      for (final availability in BiometricAvailability.values) {
        final controller = SecurityController(
          FakeSecurityRepository(hasPin: true, biometric: availability),
        );
        await controller.refresh();

        expect(
          controller.state.canUseBiometrics,
          availability == BiometricAvailability.available,
          reason: 'for $availability',
        );
      }
    });

    test('an unknown biometric value falls back to unavailable', () {
      expect(
        BiometricAvailability.fromWireName('SOMETHING_NEW'),
        BiometricAvailability.unavailable,
      );
      expect(
        BiometricAvailability.fromWireName(null),
        BiometricAvailability.unavailable,
      );
    });

    test('asks the native layer to open PIN setup', () async {
      final repository = FakeSecurityRepository();
      final controller = SecurityController(repository);

      final error = await controller.openPinSetup();

      expect(error, isNull);
      expect(repository.pinSetupRequests, 1);
    });

    test('notification hiding does not stick without access', () async {
      final repository = FakeSecurityRepository(
        isNotificationAccessGranted: false,
      );
      final controller = SecurityController(repository);
      await controller.refresh();

      final error = await controller.setNotificationPrivacyEnabled(true);

      expect(error, isNotNull);
      expect(error, contains('notification access'));
      expect(controller.state.status.isNotificationPrivacyEnabled, isFalse);
    });

    test('notification hiding turns on when access is granted', () async {
      final repository = FakeSecurityRepository();
      final controller = SecurityController(repository);
      await controller.refresh();

      final error = await controller.setNotificationPrivacyEnabled(true);

      expect(error, isNull);
      expect(controller.state.status.isNotificationPrivacyEnabled, isTrue);
    });

    test('reports when the PIN screen could not be opened', () async {
      final controller = SecurityController(
        FakeSecurityRepository(pinSetupOpens: false),
      );

      expect(await controller.openPinSetup(), isNotNull);
    });
  });
}
