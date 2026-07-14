import 'dart:convert';

import 'package:flutter/material.dart';

import '../app_state.dart';
import 'wordmark.dart';

/// The logged-in member's club logo (uploaded by the system admin at
/// onboarding), falling back to the club's own wordmark lockup ("Rotary" +
/// club line + wheel) when no logo is uploaded — never another club's
/// bundled artwork.
class ClubLogoImage extends StatelessWidget {
  final AppState state;
  final double height;
  const ClubLogoImage({super.key, required this.state, required this.height});

  Widget _fallback() => SizedBox(
        height: height,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Wordmark(state: state),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final logo = state.clubLogo;
    // Logos now come from R2 as https URLs; data URLs still appear from
    // clubs onboarded before that (or a backend running without R2).
    if (logo != null && logo.startsWith('http')) {
      return Image.network(
        logo,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stackTrace) => _fallback(),
      );
    }
    if (logo != null && logo.contains(',')) {
      return Image.memory(
        base64Decode(logo.split(',').last),
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stackTrace) => _fallback(),
      );
    }
    return _fallback();
  }
}
