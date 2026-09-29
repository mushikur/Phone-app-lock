import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samir_lock/app.dart';

import 'fakes/fake_app_inventory_repository.dart';
import 'fakes/fake_permission_repository.dart';

void main() {
  /// The app list sits behind the permission gate, so these tests start from a
  /// device where the required permissions are already granted.
  Widget buildApp(FakeAppInventoryRepository inventory) {
    return SamirLockApp(
      inventoryRepository: inventory,
      permissionRepository: FakePermissionRepository.allGranted(),
    );
  }

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

    await tester.tap(find.byType(Switch).first);
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
}
