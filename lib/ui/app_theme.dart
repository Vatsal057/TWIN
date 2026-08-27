import 'package:flutter/material.dart';

/// Warm ink-and-marigold palette. The game is about words, so type carries the
/// design: generous letter spacing, few borders, colour used only to mean
/// something (whose word is whose, whether you converged).
class AppTheme {
  AppTheme._();

  static const seed = Color(0xFFE0A93B);
  static const ink = Color(0xFF14120F);
  static const inkRaised = Color(0xFF1F1B16);
  static const inkCard = Color(0xFF272219);
  static const parchment = Color(0xFFF3EADA);

  static const playerOne = Color(0xFFE0A93B);
  static const playerTwo = Color(0xFF6FB3C6);
  static const converged = Color(0xFF7FC08A);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(surface: ink, onSurface: parchment);

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: ink,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: parchment,
        displayColor: parchment,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: parchment,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: inkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inkRaised,
        hintStyle: TextStyle(color: parchment.withValues(alpha: 0.55)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: parchment.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: seed, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: seed,
          foregroundColor: ink,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: parchment,
          side: BorderSide(color: parchment.withValues(alpha: 0.22)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: inkCard,
        contentTextStyle: const TextStyle(color: parchment),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: parchment.withValues(alpha: 0.08),
        space: 1,
        thickness: 1,
      ),
    );
  }

  /// Stable colour per player slot so history is readable at a glance.
  static Color colorForSlot(bool isPlayerOne) =>
      isPlayerOne ? playerOne : playerTwo;
}
