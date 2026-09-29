import 'package:flutter_test/flutter_test.dart';
import 'package:samir_lock/application/protection_controller.dart';

import 'fakes/fake_protection_repository.dart';

void main() {
  group('ProtectionController', () {
    test('loads the current protection status', () async {
      final controller = ProtectionController(
        FakeProtectionRepository(isEnabled: true),
      );

      await controller.refresh();

      expect(controller.state.loadStatus, ProtectionLoadStatus.ready);
      expect(controller.state.isEnabled, isTrue);
      expect(controller.state.isActive, isTrue);
    });

    test('reports an error state when the native layer fails', () async {
      final controller = ProtectionController(
        FakeProtectionRepository(failOnLoad: true),
      );

      await controller.refresh();

      expect(controller.state.loadStatus, ProtectionLoadStatus.error);
      expect(controller.state.errorMessage, isNotNull);
    });

    test('enabling protection starts the guard', () async {
      final repository = FakeProtectionRepository();
      final controller = ProtectionController(repository);
      await controller.refresh();

      final error = await controller.setEnabled(true);

      expect(error, isNull);
      expect(repository.setEnabledCalls, [true]);
      expect(controller.state.isEnabled, isTrue);
      expect(controller.state.isBusy, isFalse);
    });

    test('disabling protection stops the guard', () async {
      final repository = FakeProtectionRepository(isEnabled: true);
      final controller = ProtectionController(repository);
      await controller.refresh();

      final error = await controller.setEnabled(false);

      expect(error, isNull);
      expect(repository.setEnabledCalls, [false]);
      expect(controller.state.isEnabled, isFalse);
    });

    test('explains itself when permissions are missing', () async {
      final repository = FakeProtectionRepository(canRun: false);
      final controller = ProtectionController(repository);
      await controller.refresh();

      final error = await controller.setEnabled(true);

      expect(error, isNotNull);
      expect(error, contains('permission'));
      // Never reports protection as on when the guard could not start.
      expect(controller.state.isEnabled, isFalse);
    });

    test('is never shown as on when the guard cannot run', () async {
      // Regression: the stored flag said enabled while the guard was not
      // running, and the card reported protection as on with nothing watching.
      final controller = ProtectionController(
        FakeProtectionRepository(isEnabled: true, canRun: false),
      );

      await controller.refresh();

      expect(controller.state.isEnabled, isTrue);
      expect(controller.state.isOn, isFalse);
    });

    test('cannot be turned on without a PIN', () async {
      final repository = FakeProtectionRepository(hasPin: false);
      final controller = ProtectionController(repository);
      await controller.refresh();

      final error = await controller.setEnabled(true);

      expect(error, isNotNull);
      expect(error, contains('PIN'));
      expect(controller.state.isEnabled, isFalse);
      expect(controller.state.isOn, isFalse);
    });

    test('is not shown as on when the PIN has gone away', () async {
      final controller = ProtectionController(
        FakeProtectionRepository(isEnabled: true, hasPin: false),
      );

      await controller.refresh();

      expect(controller.state.isOn, isFalse);
    });

    test('surfaces a native failure and clears the busy flag', () async {
      final repository = FakeProtectionRepository(failOnWrite: true);
      final controller = ProtectionController(repository);
      await controller.refresh();

      final error = await controller.setEnabled(true);

      expect(error, isNotNull);
      expect(controller.state.isBusy, isFalse);
    });
  });
}
