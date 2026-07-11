import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/pressable.dart';

// wa.me expects the full international number, digits only (no "+").
// 0776157477 (Uganda local format) -> 256776157477 (country code 256).
const String _supportWhatsAppNumber = '256776157477';

/// Shown instead of the normal app whenever the signed-in member's club has
/// been suspended by the system admin — checked at login and opportunistically
/// on every AppState.loadSummary() call, so it also catches a club suspended
/// while a member is already mid-session. The only action available is
/// reaching support on WhatsApp; there is nothing else to do here until the
/// club is reinstated.
class ClubSuspendedScreen extends StatefulWidget {
  final AppState state;
  const ClubSuspendedScreen({super.key, required this.state});

  @override
  State<ClubSuspendedScreen> createState() => _ClubSuspendedScreenState();
}

class _ClubSuspendedScreenState extends State<ClubSuspendedScreen>
    with TickerProviderStateMixin {
  // The wheel falls from above and settles with a soft overshoot...
  late final AnimationController _drop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
  late final Animation<double> _dropCurve =
      CurvedAnimation(parent: _drop, curve: Curves.easeOutBack);
  // ...then spins continuously once it's landed.
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));
  // Headline + body text fade/slide in, staggered slightly behind the drop.
  late final AnimationController _words = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));

  Animation<double> _wordSlice(double begin, double end) => CurvedAnimation(
      parent: _words, curve: Interval(begin, end, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drop.forward().whenComplete(() {
        if (mounted) _spin.repeat();
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _words.forward();
      });
    });
  }

  @override
  void dispose() {
    _drop.dispose();
    _spin.dispose();
    _words.dispose();
    super.dispose();
  }

  void _contactSupport() {
    launchUrl(
      Uri.parse('https://wa.me/$_supportWhatsAppNumber'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    Widget wheel =
        Image.asset('assets/images/rotary_wheel_spin.png', height: 120);
    if (state.clubType == 'rotaract') {
      wheel = ColorFiltered(
        colorFilter: ColorFilter.mode(RCColors.blue, BlendMode.srcIn),
        child: wheel,
      );
    }
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              AnimatedBuilder(
                animation: Listenable.merge([_dropCurve, _spin]),
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, -220 * (1 - _dropCurve.value)),
                  child: RotationTransition(turns: _spin, child: child),
                ),
                child: wheel,
              ),
              const SizedBox(height: 28),
              _FadeSlideIn(
                progress: _wordSlice(0.0, 0.75),
                child: const Text(
                  'Club Suspended',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: RCColors.textDark,
                    letterSpacing: -.3,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _FadeSlideIn(
                progress: _wordSlice(0.25, 1.0),
                child: Text(
                  '${state.displayClubName} has been suspended by the system admin. '
                  "You won't be able to use the app until your club is "
                  'reinstated — contact support for details.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: RCColors.textMuted,
                    height: 1.5,
                  ),
                ),
              ),
              const Spacer(flex: 4),
              PressableScale(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _contactSupport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RCColors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(17),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Contact Support',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fade + slight upward slide, driven by a slice of the word-entrance
/// timeline. Mirrors splash_screen.dart's private helper of the same name.
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
