import 'package:flutter/material.dart';

class AppColors {
  static const bgTop = Color(0xFF2A1458);
  static const bgMid = Color(0xFF150C35);
  static const bgBottom = Color(0xFF0B0720);
  static const accent = Color(0xFFB9A7FF);
  static const success = Color(0xFF22D37A);
  static const danger = Color(0xFFFF5C6C);
  static const warning = Color(0xFFFFB84D);
  static const textSoft = Color(0xFFC9C0E6);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7C5CFF),
    brightness: Brightness.dark,
  ).copyWith(surface: AppColors.bgMid);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0D0824),
      indicatorColor: const Color(0xFF4A3C7A),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.transparent,
        selectedBackgroundColor: Colors.white.withValues(alpha: 0.18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
      ),
    ),
  );
}
