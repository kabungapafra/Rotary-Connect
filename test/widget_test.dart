import 'package:flutter_test/flutter_test.dart';

import 'package:rotary_connect/main.dart';

void main() {
  testWidgets('App launches to the Splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const RotaryMbalwaApp());

    expect(find.text('Welcome to\nRotary Club of Mbalwa'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
  });
}
