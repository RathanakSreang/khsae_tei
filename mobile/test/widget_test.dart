import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:khsae_tei/main.dart';

void main() {
  testWidgets('App boots to the Home dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const KhsaeTeiApp());
    await tester.pump();

    expect(find.text('ខ្សែតី KHSAE TEI'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Connect'), findsNothing);
  });

  testWidgets('Settings tab shows connection config and Test Whip', (WidgetTester tester) async {
    await tester.pumpWidget(const KhsaeTeiApp());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Test Whip'), findsOneWidget);
  });
}
