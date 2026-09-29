import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:samir_lock/app.dart';

void main() {
  testWidgets('app shell renders the Samir Lock landing screen', (tester) async {
    await tester.pumpWidget(const SamirLockApp());

    expect(find.text('Samir Lock'), findsWidgets);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}
