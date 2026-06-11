import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aigen/main.dart';

void main() {
  testWidgets('Aigen app starts', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AigenApp());
    await tester.pump();

    expect(find.byType(AigenApp), findsOneWidget);
  });
}
