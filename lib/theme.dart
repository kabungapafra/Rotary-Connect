import 'package:flutter/material.dart';

/// Colors and text styles lifted directly from the Rotary Mbalwa design.
class RCColors {
  // Rotary is the default brand; a Rotaract club's members set this once,
  // right after login/session-restore (see AppState.clubType), and every
  // reference below picks it up on the next rebuild.
  static bool _isRotaract = false;
  static void setClubType(String clubType) =>
      _isRotaract = clubType.toLowerCase() == 'rotaract';

  static Color get blue =>
      _isRotaract ? const Color(0xFFD41367) : const Color(0xFF17458F);
  static const blueDark = Color(0xFF0C2F66);
  // Gold's Rotaract color is the brand magenta, not white — nearly every
  // gold usage sits on a white/light background (splash screen text, stat
  // values, card borders), where white would be invisible. See
  // [scanAccent] for the one family of usages (the dark scan screen) where
  // a light accent is actually correct.
  static Color get gold =>
      _isRotaract ? const Color(0xFFD41367) : const Color(0xFFF7A81B);
  // The scan screen's own dark background (scanBg/scanCard) is the
  // exception to gold's rule above — an accent needs to stay light there
  // for contrast, so Rotaract gets white instead of the magenta that would
  // otherwise vanish the same way it once vanished on white pages.
  static Color get scanAccent => _isRotaract ? Colors.white : gold;
  // A lighter tint of [blue], used for muted text/overlays on top of a blue
  // card — derived so it always matches whichever brand color is active.
  static Color get blueMuted => Color.lerp(blue, Colors.white, 0.55)!;
  // The bottom-nav scan launcher needs its icon to contrast against
  // whichever color its background lands on (gold for Rotary, magenta for
  // Rotaract) — a dedicated pair instead of a fixed icon color.
  static Color get scanLauncherBg => _isRotaract ? blue : gold;
  static Color get scanLauncherIcon => _isRotaract ? Colors.white : blue;
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
  static Color get cardShadow => blue.withAlpha(0x0F);

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
