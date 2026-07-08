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
    final dataUrl = state.clubLogo;
    if (dataUrl != null && dataUrl.contains(',')) {
      return Image.memory(
        base64Decode(dataUrl.split(',').last),
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stackTrace) =>
            Image.asset('assets/images/rotary_mbalwa_logo.png', height: height),
      );
    }
    return Image.asset('assets/images/rotary_mbalwa_logo.png', height: height);
  }
}
