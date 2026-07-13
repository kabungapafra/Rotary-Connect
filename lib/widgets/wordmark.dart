import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';

/// "Rotary" + a dynamic second line (either "Connect" pre-login or the
/// member's real club, e.g. "Club of Mbalwa") next to the Rotary wheel.
/// Shared by the splash screen (spinning) and the login screen (static),
/// so branding matches across the whole pre-login flow.
class Wordmark extends StatelessWidget {
  final AppState state;
  final Animation<double>? spin; // null = static wheel, no rotation
  final double scale;

  /// 0→1 "prints" the text left-to-right (visual clip only — layout keeps
  /// its full size so the wheel's position never shifts). Null = fully
  /// printed. Drives the splash entrance where the flying wheel writes
  /// the words as it travels.
  final Animation<double>? reveal;

  /// The splash hides this wheel (opacity, not layout) while its own
  /// flying wheel is mid-flight, then shows it the instant they overlap.
  final bool showWheel;

  /// Lets the splash measure where the wheel slot landed, to aim the flight.
  final Key? wheelKey;

  const Wordmark({
    super.key,
    required this.state,
    this.spin,
    this.scale = 1.0,
    this.reveal,
    this.showWheel = true,
    this.wheelKey,
  });

  @override
  Widget build(BuildContext context) {
    final isRotaract = state.clubType == 'rotaract';
    Widget wheel =
        Image.asset('assets/images/rotary_wheel_spin.png', height: 55 * scale);
    if (isRotaract) {
      wheel = ColorFiltered(
        colorFilter: ColorFilter.mode(RCColors.blue, BlendMode.srcIn),
        child: wheel,
      );
    }
    Widget text = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 230 * scale),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Per the official logo lockup: the club line's last letter
        // sits flush under the final "y" of "Rotary", so both lines
        // share a RIGHT edge (the club line extends further left).
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            isRotaract ? 'Rotaract' : 'Rotary',
            style: TextStyle(
              color: RCColors.blue,
              fontSize: 30 * scale,
              fontWeight: FontWeight.w800,
              // A tight height multiplier clips descenders (the "y" in
              // "Rotary") — 1.25 gives the glyph room below the baseline.
              height: 1.25,
              letterSpacing: -.5,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              state.wordmarkClubLine,
              maxLines: 1,
              style: TextStyle(
                color: RCColors.blue,
                fontSize: 17 * scale,
                // The official lockup sets the club name in a regular
                // weight — only "Rotary" is bold.
                fontWeight: FontWeight.w400,
                height: 1.3,
                letterSpacing: .2,
              ),
            ),
          ),
        ],
      ),
    );
    if (reveal != null) {
      final anim = reveal!;
      text = AnimatedBuilder(
        animation: anim,
        builder: (context, child) => ClipRect(
          clipper: _PrintClipper(anim.value),
          child: child,
        ),
        child: text,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        text,
        SizedBox(width: 8 * scale),
        KeyedSubtree(
          key: wheelKey,
          child: Opacity(
            opacity: showWheel ? 1 : 0,
            child:
                spin == null ? wheel : RotationTransition(turns: spin!, child: wheel),
          ),
        ),
      ],
    );
  }
}

/// Clips to the leading fraction of the width — the "printing" effect.
/// Purely visual: layout keeps its full size.
class _PrintClipper extends CustomClipper<Rect> {
  final double fraction;
  const _PrintClipper(this.fraction);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_PrintClipper oldClipper) => oldClipper.fraction != fraction;
}
