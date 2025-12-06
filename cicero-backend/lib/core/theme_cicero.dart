import 'package:flutter/material.dart';

class CiceroTheme {
  // Apple-style Blue (from your _layout.jsx)
  static const Color primaryLight = Color(0xFF007AFF);
  static const Color primaryDark = Color(0xFF0A84FF);

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF2F2F7); // iOS Grey
  static const Color backgroundDark = Color(0xFF000000);

  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1C1C1E);

  // Category Pastels (from examples.jsx)
  static const Color pastelPurple = Color(0xFFE7D8FF);
  static const Color pastelBlue = Color(0xFFCDECF8);
  static const Color pastelRed = Color(0xFFFBD1D4);
  static const Color pastelOrange = Color(0xFFFFE5D8);

  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      primaryColor: primaryLight,
      cardColor: surfaceLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceLight,
        selectedItemColor: primaryLight,
        unselectedItemColor: Color(0xFF6B6B6B),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: primaryDark,
      cardColor: surfaceDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primaryDark,
        unselectedItemColor: Color(0xFF8E8E93),
      ),
    );
  }
}
