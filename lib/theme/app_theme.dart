import 'package:flutter/material.dart';

class AppTheme {
  // Light Theme Colors
  static const Color _lightPrimary = Color(0xFF6200EE);
  static const Color _lightSecondary = Color(0xFF03DAC6);
  static const Color _lightBackground = Color(0xFFF5F5F5);
  static const Color _lightSurface = Colors.white;
  static const Color _lightError = Color(0xFFB00020);
  static const Color _lightOnPrimary = Colors.white;
  static const Color _lightOnSecondary = Colors.black;
  static const Color _lightOnBackground = Colors.black;
  static const Color _lightOnSurface = Colors.black;
  static const Color _lightOnError = Colors.white;

  // Dark Theme Colors
  static const Color _darkPrimary = Color(0xFFBB86FC);
  static const Color _darkSecondary = Color(0xFF03DAC6);
  static const Color _darkBackground = Color(0xFF121212);
  static const Color _darkSurface = Color(0xFF1E1E1E);
  static const Color _darkError = Color(0xFFCF6679);
  static const Color _darkOnPrimary = Colors.black;
  static const Color _darkOnSecondary = Colors.black;
  static const Color _darkOnBackground = Colors.white;
  static const Color _darkOnSurface = Colors.white;
  static const Color _darkOnError = Colors.black;

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: _lightPrimary,
        onPrimary: _lightOnPrimary,
        secondary: _lightSecondary,
        onSecondary: _lightOnSecondary,
        error: _lightError,
        onError: _lightOnError,
        background: _lightBackground,
        onBackground: _lightOnBackground,
        surface: _lightSurface,
        onSurface: _lightOnSurface,
      ),
      scaffoldBackgroundColor: _lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightSurface,
        foregroundColor: _lightOnSurface,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightPrimary,
          foregroundColor: _lightOnPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          elevation: 2,
        ),
      ),
      textTheme: ThemeData.light().textTheme.apply(
            fontFamily: 'NotoSansKR',
            bodyColor: _lightOnBackground,
            displayColor: _lightOnBackground,
          ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: _darkPrimary,
        onPrimary: _darkOnPrimary,
        secondary: _darkSecondary,
        onSecondary: _darkOnSecondary,
        error: _darkError,
        onError: _darkOnError,
        background: _darkBackground,
        onBackground: _darkOnBackground,
        surface: _darkSurface,
        onSurface: _darkOnSurface,
      ),
      scaffoldBackgroundColor: _darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: _darkOnSurface,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: _darkOnPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          elevation: 2,
        ),
      ),
      textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: 'NotoSansKR',
            bodyColor: _darkOnBackground,
            displayColor: _darkOnBackground,
          ),
      sliderTheme: SliderThemeData(
        activeTrackColor: _darkPrimary,
        inactiveTrackColor: _darkPrimary.withOpacity(0.3),
        thumbColor: _darkSecondary,
      ),
    );
  }
}
