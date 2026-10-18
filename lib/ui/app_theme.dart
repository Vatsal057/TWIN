import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'twin_palette.dart';

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

  static ThemeData dark() => fromPalette(TwinPalette.navy);

  /// The Material theme for one palette. Widgets mostly colour
  /// themselves from the palette directly; this covers the parts
  /// Material draws (fields, buttons, dialogs, app bars).
  static ThemeData fromPalette(TwinPalette p) {
    final textTheme = GoogleFonts.outfitTextTheme().apply(
      bodyColor: p.text,
      displayColor: p.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: p.bg,
      colorScheme:
          (p.isDark ? const ColorScheme.dark() : const ColorScheme.light())
              .copyWith(
                surface: p.sheet,
                primary: p.accent,
                onPrimary: p.onAccent,
                secondary: p.accent2,
                onSurface: p.text,
              ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.text,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.sheet,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: p.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.field,
        hintStyle: TextStyle(color: p.muted, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: p.accent, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
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
          foregroundColor: p.text,
          side: BorderSide(color: p.text.withValues(alpha: 0.14)),
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
        color: p.text.withValues(alpha: 0.06),
        space: 1,
        thickness: 1,
      ),
    );
  }

  static Color colorForSlot(bool isPlayerOne) =>
      isPlayerOne ? playerOne : playerTwo;
}
