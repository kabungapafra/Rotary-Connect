import 'dart:convert';

import 'package:flutter/material.dart';

import '../app_state.dart';

/// The logged-in member's club logo (uploaded by the system admin at
/// onboarding), falling back to the bundled Mbalwa artwork when the club
/// has no uploaded logo — which keeps the pre-login screens unchanged.
class ClubLogoImage extends StatelessWidget {
  final AppState state;
  final double height;
  const ClubLogoImage({super.key, required this.state, required this.height});

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
        errorBuilder: (_, error, stackTrace) =>
            Image.asset('assets/images/rotary_mbalwa_logo.png', height: height),
      );
    }
    if (logo != null && logo.contains(',')) {
      return Image.memory(
        base64Decode(logo.split(',').last),
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stackTrace) =>
            Image.asset('assets/images/rotary_mbalwa_logo.png', height: height),
      );
    }
    return Image.asset('assets/images/rotary_mbalwa_logo.png', height: height);
  }
}
