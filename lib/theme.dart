import 'package:flutter/material.dart';

/// Colors and text styles lifted directly from the Rotary Mbalwa design.
class RCColors {
  static const blue = Color(0xFF17458F);
  static const blueDark = Color(0xFF0C2F66);
  static const gold = Color(0xFFF7A81B);
  static const scaffoldBg = Color(0xFFF4F6FA);
  static const cardBg = Colors.white;
  static const textDark = Color(0xFF1A2437);
  static const textMuted = Color(0xFF6B7688);
  static const divider = Color(0xFFEEF1F6);
  static const divider2 = Color(0xFFE6EAF1);
  static const chipBg = Color(0xFFEEF2F9);
  static const green = Color(0xFF1F9D55);
  static const red = Color(0xFFC0392B);
  static const amber = Color(0xFFB57708);
  static const amberBg = Color(0xFFFFF5E0);
  static const cardShadow = Color(0x0F17458F);

  // scan / dark screen
  static const scanBg = Color(0xFF0E1524);
  static const scanCard = Color(0xFF141D31);
  static const scanBorder = Color(0xFF2A3854);
  static const scanMuted = Color(0xFF8FA0C0);

  static const avatarPalette = [
    Color(0xFF17458F),
    Color(0xFF2B5FB0),
    Color(0xFF0C3C7C),
    Color(0xFFB57708),
    Color(0xFF3A6EA5),
  ];

  static Color avatarColor(int i) => avatarPalette[i % avatarPalette.length];
}

ThemeData buildRCTheme() {
  // Poppins is bundled in assets/fonts with its real 400–800 faces, so bold
  // headings (w700/w800) resolve to actual Bold/ExtraBold glyphs instead of
  // falling back to the regular face.
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: RCColors.scaffoldBg,
    fontFamily: 'Poppins',
    textTheme: ThemeData.light().textTheme.apply(
          fontFamily: 'Poppins',
          bodyColor: RCColors.textDark,
          displayColor: RCColors.textDark,
        ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: RCColors.blue,
      primary: RCColors.blue,
      secondary: RCColors.gold,
    ),
  );
}
