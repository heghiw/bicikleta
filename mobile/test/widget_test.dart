import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pedalshare/main.dart';

void main() {
  testWidgets('application shell builds', (tester) async {
    await tester.pumpWidget(const PedalShareApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
