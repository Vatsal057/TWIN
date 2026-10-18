import 'package:flutter/material.dart';

/// One selectable look for the app's chrome: tabs, lists, sheets,
/// the game screen's surroundings. Screens read these tokens from
/// the session instead of naming colours directly, so a new theme
/// is just a new palette.
///
/// The brand stage is NOT themed: the boot screen, the reveal, the
/// twinning screen and the shared victory card stay midnight navy
/// in every theme, because the card is the image friends receive.
class TwinPalette {
  const TwinPalette({
    required this.id,
    required this.name,
    required this.isDark,
    required this.bg,
    required this.sheet,
    required this.surface,
    required this.raised,
    required this.field,
    required this.bubble,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accentInk,
    required this.accentSoft,
    required this.accent2,
    required this.accent2Ink,
    required this.accent2Soft,
    required this.barA,
    required this.barB,
  });

  final String id;
  final String name;
  final bool isDark;

  /// Scaffold backdrop.
  final Color bg;

  /// Modal sheets and the app bars' solid moments (navy900 today).
  final Color sheet;

  /// Card fill sitting on [bg].
  final Color surface;

  /// Pills, chips and other raised pieces.
  final Color raised;

  /// Text field fill.
  final Color field;

  /// The other player's chat bubble.
  final Color bubble;

  final Color border;
  final Color text;
  final Color muted;

  /// Primary action colour (lime / tangerine).
  final Color accent;

  /// Text drawn on top of [accent].
  final Color onAccent;

  /// [accent] used as text or icon colour on [bg] / [surface],
  /// darkened where the accent itself is too light to read.
  final Color accentInk;

  /// Translucent [accent] fill for soft chips and highlights.
  final Color accentSoft;

  /// The second player colour (coral / rose).
  final Color accent2;
  final Color accent2Ink;
  final Color accent2Soft;

  /// The floating tab bar's glass gradient, top to bottom.
  final Color barA;
  final Color barB;

  static const navy = TwinPalette(
    id: 'navy',
    name: 'Navy',
    isDark: true,
    bg: Color(0xFF0B0B22),
    sheet: Color(0xFF151434),
    surface: Color(0x0DFFFFFF),
    raised: Color(0xFF2E3060),
    field: Color(0xFF1E1E42),
    bubble: Color(0xFF23234A),
    border: Color(0x1AFFFFFF),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFF8D92AA),
    accent: Color(0xFFC3F959),
    onAccent: Color(0xFF0B0B22),
    accentInk: Color(0xFFC3F959),
    accentSoft: Color(0x26C3F959),
    accent2: Color(0xFFFF6855),
    accent2Ink: Color(0xFFFF7A63),
    accent2Soft: Color(0x29FF6855),
    barA: Color(0x731B1E38),
    barB: Color(0x8C0F1126),
  );

  static const pastelWarm = TwinPalette(
    id: 'pastel',
    name: 'Pastel Warm',
    isDark: false,
    bg: Color(0xFFFAF1E3),
    sheet: Color(0xFFFFF8EC),
    surface: Color(0xFFFFF8EC),
    raised: Color(0xFFF6E3C8),
    field: Color(0xFFFFFDF8),
    bubble: Color(0xFFF3E4CE),
    border: Color(0x1F784814),
    text: Color(0xFF43302B),
    muted: Color(0xFFA08B7D),
    accent: Color(0xFFFF9E6B),
    onAccent: Color(0xFF4A2410),
    accentInk: Color(0xFFD96F43),
    accentSoft: Color(0x29FF9E6B),
    accent2: Color(0xFFF2A0A5),
    accent2Ink: Color(0xFFC05A5E),
    accent2Soft: Color(0x2EF2A0A5),
    barA: Color(0xD9FFF8EC),
    barB: Color(0xE6F6E3C8),
  );

  static const all = [navy, pastelWarm];

  static TwinPalette byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => navy);
}
