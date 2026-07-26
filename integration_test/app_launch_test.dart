import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rotary_connect/main.dart';
import 'package:rotary_connect/screens/splash_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches to the splash screen without crashing',
      (tester) async {
    // Pumps the real app widget rather than calling main() — this still
    // exercises the actual native launch path (AppDelegate/SceneDelegate/
    // FlutterViewController, where the ProMotion VSyncClient crash this
    // suite guards against actually happened) plus the real widget tree,
    // but skips main()'s Firebase.initializeApp()/Sentry.init() calls so
    // the test has no backend or network dependency in a CI sandbox.
    // AppState's own startup work (session restore, backend warm-up) is
    // already local-only or fire-and-forget/error-swallowed by design
    // (see AppState._restoreSession and ApiClient.warmUp), and
    // RotaryMbalwaApp's push-notification setup is wrapped in a try/catch
    // specifically because Firebase may not be initialized here — so none
    // of that needs mocking for this smoke test.
    await tester.pumpWidget(const RotaryMbalwaApp());

    // SplashScreen runs continuously-looping animations (the wheel spin
    // and the gold-dash pulse both use `..repeat()`), so pumpAndSettle()
    // would never settle and would time out. A few bounded pumps are
    // enough to prove the app rendered a real frame without crashing.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
