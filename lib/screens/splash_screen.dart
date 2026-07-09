import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/pressable.dart';
import '../widgets/wordmark.dart';

class SplashScreen extends StatefulWidget {
  final AppState state;
  const SplashScreen({super.key, required this.state});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Continuous slow spin for the Rotary wheel.
  late final AnimationController _wheelSpin =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat();

  // Staggered entrance for the welcome text, its decorative dashes, and
  // the motto. Starts shortly after the first frame (so it isn't hidden
  // behind the OS launch splash) and runs slowly enough to be seen.
  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600));

  // Gentle continuous breathing on the gold dashes so the screen stays
  // subtly alive after the entrance settles.
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _intro.forward();
      });
    });
  }

  Animation<double> _slice(double begin, double end) => CurvedAnimation(
      parent: _intro, curve: Interval(begin, end, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _wheelSpin.dispose();
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White splash needs dark status-bar icons; the rest of the app uses light.
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Container(
        color: Colors.white,
        child: Stack(
          children: [
            // Pale circle in the top-right corner, per the design:
            // 320px solid #f4f6fa circle plus a thin outline ring scaled 1.18.
            Positioned(
              top: -140,
              right: -140,
              child: Container(
                width: 320,
                height: 320,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: RCColors.scaffoldBg,
                ),
              ),
            ),
            Positioned(
              top: -168.8,
              right: -168.8,
              child: Container(
                width: 377.6,
                height: 377.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: RCColors.blue.withValues(alpha: .08), width: 1.5),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(flex: 2),
                          Wordmark(state: state, spin: _wheelSpin),
                          const SizedBox(height: 24),
                          // The gold dash grows out from the left as the
                          // welcome text arrives, then keeps breathing.
                          _GrowingDash(
                            progress: _slice(0.0, 0.30),
                            pulse: _pulse,
                            width: 44,
                            height: 5,
                            radius: 3,
                          ),
                          const SizedBox(height: 24),
                          // The welcome text gets its own signature entrance:
                          // each line rises with a soft overshoot, staggered.
                          _WelcomeLine(
                            progress: CurvedAnimation(
                                parent: _intro,
                                curve: const Interval(0.10, 0.50,
                                    curve: Curves.easeOutBack)),
                            fade: _slice(0.10, 0.40),
                            text: 'Welcome to',
                          ),
                          _WelcomeLine(
                            progress: CurvedAnimation(
                                parent: _intro,
                                curve: const Interval(0.22, 0.62,
                                    curve: Curves.easeOutBack)),
                            fade: _slice(0.22, 0.52),
                            text: 'fellowship.',
                          ),
                          const SizedBox(height: 12),
                          _FadeSlideIn(
                            progress: _slice(0.30, 0.70),
                            child: Text(
                              state.splashSubtitle,
                              style: const TextStyle(
                                color: RCColors.textMuted,
                                fontSize: 14.5,
                                height: 1.55,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _FadeSlideIn(
                            progress: _slice(0.45, 0.90),
                            child: Row(
                              children: [
                                _GrowingDash(
                                  progress: _slice(0.55, 1.0),
                                  pulse: _pulse,
                                  width: 22,
                                  height: 1.5,
                                  radius: 0,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'SERVICE ABOVE SELF',
                                  style: TextStyle(
                                    color: RCColors.gold,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(flex: 3),
                        ],
                      ),
                    ),
                    // box-shadow: 0 8px 20px rgba(23,69,143,.28)
                    PressableScale(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: RCColors.blue.withValues(alpha: .28),
                              offset: const Offset(0, 8),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: state.enterMember,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RCColors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(17),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: const Text('Continue as Member',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PressableScale(
                      child: OutlinedButton(
                        onPressed: state.enterGuest,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: RCColors.blue,
                          side: const BorderSide(
                              color: Color(0xFFD4DBE8), width: 1.5),
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text("I'm visiting as a Guest",
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line of the welcome headline: rises from below with a soft
/// overshoot (easeOutBack) while fading in — clipped to its own height so
/// each line appears to emerge from an invisible baseline.
class _WelcomeLine extends StatelessWidget {
  final Animation<double> progress;
  final Animation<double> fade;
  final String text;
  const _WelcomeLine(
      {required this.progress, required this.fade, required this.text});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: Listenable.merge([progress, fade]),
        builder: (context, _) => Opacity(
          opacity: fade.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 46 * (1 - progress.value)),
            child: Text(
              text,
              style: const TextStyle(
                color: RCColors.blue,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fade + slight upward slide, driven by a slice of the intro timeline.
class _FadeSlideIn extends StatelessWidget {
  final Animation<double> progress;
  final Widget child;
  const _FadeSlideIn({required this.progress, required this.child});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: progress,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .18), end: Offset.zero)
            .animate(progress),
        child: child,
      ),
    );
  }
}

/// A decorative gold dash that grows out from the left to its final width,
/// then keeps a gentle breathing pulse so the screen stays subtly alive.
class _GrowingDash extends StatelessWidget {
  final Animation<double> progress;
  final Animation<double> pulse;
  final double width;
  final double height;
  final double radius;
  const _GrowingDash({
    required this.progress,
    required this.pulse,
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([progress, pulse]),
      builder: (context, _) => Opacity(
        opacity: 0.75 + 0.25 * pulse.value,
        child: Container(
          width: width * progress.value,
          height: height,
          decoration: BoxDecoration(
            color: RCColors.gold,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}
