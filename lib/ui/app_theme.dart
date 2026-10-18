import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TWIN Reference Aesthetic — Midnight Navy, Neon Lime, and Punchy Coral.
/// iOS-style frosted glass surfaces, high-radius capsule curves, and
/// heavy display typography.
class AppTheme {
  AppTheme._();

  // Reference UI Colors
  static const navy950 = Color(0xFF0B0B22); // Main backdrop
  static const navy900 = Color(0xFF151434); // Card / surface base
  static const navy800 = Color(0xFF1E1E42); // Elevated chip / pill
  static const navy700 = Color(0xFF282856);

  static const lime = Color(0xFFC3F959);     // Hero brand accent / P1
  static const coral = Color(0xFFFF6855);    // P2 / Twinning contrast
  static const mist = Color(0xFF8D92AA);     // Muted secondary text
  static const white = Color(0xFFFFFFFF);

  static const playerOne = lime;
  static const playerTwo = coral;
  static const converged = lime;
  static const convergedBright = Color(0xFFE2FFA8);

  // Backward-compatibility aliases for legacy widgets
  static const ink = navy950;
  static const inkCard = navy900;
  static const inkRaised = navy800;
  static const parchment = white;
  static const seed = lime;

  static ThemeData dark() {
    final textTheme = GoogleFonts.outfitTextTheme().apply(
      bodyColor: white,
      displayColor: white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navy950,
      colorScheme: const ColorScheme.dark(
        surface: navy900,
        primary: lime,
        secondary: coral,
        onSurface: white,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        color: navy900,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: navy800,
        hintStyle: const TextStyle(color: mist, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: lime, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: lime,
          foregroundColor: navy950,
          elevation: 0,
          textStyle: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        space: 1,
        thickness: 1,
      ),
    );
  }

  static Color colorForSlot(bool isPlayerOne) =>
      isPlayerOne ? playerOne : playerTwo;
}
