import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Deep obsidian luxury palette
  static const Color background = Color(0xFF090C10);
  static const Color surface = Color(0xFF111620);
  static const Color surfaceLight = Color(0xFF171D2A);
  static const Color border = Color(0xFF1E2636);
  static const Color borderLight = Color(0xFF2B3547);

  // High-contrast accent colors
  static const Color primary = Color(0xFF38BDF8); // Electric Sky
  static const Color success = Color(0xFF00E676); // Mint Emerald
  static const Color successBg = Color(0x1A00E676);
  static const Color error = Color(0xFFFF5252);   // Crimson
  static const Color errorBg = Color(0x1AFF5252);
  static const Color warning = Color(0xFFFBBF24); // Warm Amber
  static const Color warningBg = Color(0x1AFBBF24);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        surface: surface,
        error: error,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
          displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
          titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
          bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
          labelSmall: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
