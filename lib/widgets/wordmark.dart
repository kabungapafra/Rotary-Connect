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
  const Wordmark({super.key, required this.state, this.spin, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final wheel =
        Image.asset('assets/images/rotary_wheel_spin.png', height: 55 * scale);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 230 * scale),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Rotary',
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
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    letterSpacing: .2,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8 * scale),
        spin == null ? wheel : RotationTransition(turns: spin!, child: wheel),
      ],
    );
  }
}
