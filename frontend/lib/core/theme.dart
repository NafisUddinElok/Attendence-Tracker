import 'package:flutter/material.dart';

/// App color palette — Flat minimalist utility theme
class AppColors {
  static const schoolBlue = Colors.blue;
  static const schoolNavy = Colors.blue;
  static const background = Color(0xFFF9F9F9);
  static const surface = Colors.white;
  static const border = Color(0xFFE0E0E0);
  static const lightBorder = Color(0xFFEEEEEE);
  static const softBlue = Color(0xFFE3F2FD);

  // Status colors
  static const presentGreen = Colors.green;
  static const absentRed = Colors.red;
  static const warningAmber = Colors.orange;

  // Typography
  static const textPrimary = Colors.black87;
  static const textSecondary = Colors.black54;
  static const textMuted = Colors.grey;

  // Aliases for compatibility
  static const deepNavy = Colors.blue;
  static const neonCyan = Colors.blue;
  static const electricPurple = Colors.blue;
  static const glassWhite = Colors.white;
  static const glassBorder = Color(0xFFE0E0E0);
  static const slateBlue = Colors.white;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: false,
      primarySwatch: Colors.blue,
      scaffoldBackgroundColor: const Color(0xFFF9F9F9),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          side: const BorderSide(color: Color(0xFFBDBDBD)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Colors.blue),
        ),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
