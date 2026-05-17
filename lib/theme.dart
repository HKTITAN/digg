import 'package:flutter/material.dart';

/// Digg brand palette. Green accent on a near-black surface to match the
/// look of the digg.com web app.
class DiggColors {
  DiggColors._();

  static const green = Color(0xFF00BA7C);
  static const greenSoft = Color(0x1F00BA7C); // ~12% alpha
  static const greenRing = Color(0x5900BA7C); // ~35% alpha

  // Background scale
  static const bg = Color(0xFF000000);
  static const bgSoft = Color(0xFF16181C);
  static const bgRaised = Color(0xFF1E2125);

  // Text
  static const fg = Color(0xFFE7E9EA);
  static const fgSoft = Color(0xFF71767B);

  // Borders
  static const border = Color(0xFF2F3336);

  // Sentiment
  static const sentimentPositive = Color(0xFF00BA7C);
  static const sentimentNeutral = Color(0xFF71767B);
  static const sentimentNegative = Color(0xFFF4212E);

  // Metric tile accents
  static const metricViews = Color(0xFF00BA7C);
  static const metricComments = Color(0xFF1D9BF0);
  static const metricReposts = Color(0xFF7856FF);
  static const metricBookmarks = Color(0xFFFFB800);
}

ThemeData buildDiggTheme() {
  const fontFamily = 'Inter';
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: DiggColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: DiggColors.green,
      secondary: DiggColors.green,
      surface: DiggColors.bg,
      surfaceContainerHighest: DiggColors.bgSoft,
      onSurface: DiggColors.fg,
      onPrimary: Colors.black,
      error: DiggColors.sentimentNegative,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: DiggColors.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: DiggColors.fg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: DiggColors.fg,
        fontWeight: FontWeight.w800,
        fontSize: 18,
        fontFamily: fontFamily,
      ),
    ),
    dividerTheme: const DividerThemeData(color: DiggColors.border, thickness: 1, space: 1),
    textTheme: base.textTheme.apply(
      bodyColor: DiggColors.fg,
      displayColor: DiggColors.fg,
      fontFamily: fontFamily,
    ),
    iconTheme: const IconThemeData(color: DiggColors.fg),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: DiggColors.bg,
      selectedItemColor: DiggColors.green,
      unselectedItemColor: DiggColors.fgSoft,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    cardTheme: CardThemeData(
      color: DiggColors.bgSoft,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: DiggColors.border, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DiggColors.bgSoft,
      hintStyle: const TextStyle(color: DiggColors.fgSoft),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9999),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9999),
        borderSide: const BorderSide(color: DiggColors.green, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: DiggColors.green,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontFamily: fontFamily),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
      ),
    ),
  );
}
