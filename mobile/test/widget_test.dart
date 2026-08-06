import 'package:flutter_test/flutter_test.dart';

import 'package:khsae_tei/main.dart';

void main() {
  testWidgets('App boots to pairing screen', (WidgetTester tester) async {
    await tester.pumpWidget(const KhsaeTeiApp());

    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Test Whip'), findsOneWidget);
  });
}
