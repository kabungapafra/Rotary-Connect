import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../theme.dart';

class SplashScreen extends StatefulWidget {
  final AppState state;
  const SplashScreen({super.key, required this.state});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Continuous slow spin for the Rotary wheel.
  late final AnimationController _wheelSpin =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat();

  @override
  void dispose() {
    _wheelSpin.dispose();
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
                          _AnimatedWordmark(spin: _wheelSpin),
                          const SizedBox(height: 24),
                          Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: RCColors.gold,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Welcome to\nfellowship.',
                            style: TextStyle(
                              color: RCColors.blue,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              letterSpacing: -.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Check in, follow projects, and stay connected with the Rotary Club of Mbalwa.',
                            style: TextStyle(
                              color: RCColors.textMuted,
                              fontSize: 14.5,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Container(
                                  width: 22, height: 1.5, color: RCColors.gold),
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
                          const Spacer(flex: 3),
                        ],
                      ),
                    ),
                    // box-shadow: 0 8px 20px rgba(23,69,143,.28)
                    DecoratedBox(
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
                    const SizedBox(height: 12),
                    OutlinedButton(
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

/// The real logo, split into two images so the wheel can spin: the words are
/// the untouched pixels cropped from rotary_mbalwa_logo.png, and the wheel is
/// the same artwork with the ® masked out so it doesn't orbit while rotating.
/// Sizes keep the original logo's proportions (wheel ≈ 1.21× the words' height).
class _AnimatedWordmark extends StatelessWidget {
  final Animation<double> spin;
  const _AnimatedWordmark({required this.spin});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset('assets/images/rotary_mbalwa_words.png', height: 46),
        const SizedBox(width: 8),
        RotationTransition(
          turns: spin,
          child: Image.asset('assets/images/rotary_wheel_spin.png', height: 55),
        ),
      ],
    );
  }
}
