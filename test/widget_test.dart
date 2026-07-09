import 'package:flutter_test/flutter_test.dart';

import 'package:rotary_connect/main.dart';

void main() {
  testWidgets('App launches to the Splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const RotaryMbalwaApp());
    // Splash kicks off its entrance animation after a 250ms delay (so it
    // isn't hidden behind the OS launch splash) — pump past that so the
    // pending Timer doesn't trip the "disposed with timer still pending"
    // check below.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Welcome to'), findsOneWidget);
    expect(find.text('fellowship.'), findsOneWidget);
    expect(find.text('Continue as Member'), findsOneWidget);
    expect(find.text("I'm visiting as a Guest"), findsOneWidget);
  });
}
