import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum WordTone { lime, coral, neutral }

/// Word Sticker matching reference Screenshot 2:
/// High-contrast tilted card with bold black uppercase text, high radius, and drop shadow.
class WordSticker extends StatelessWidget {
  const WordSticker({
    super.key,
    required this.word,
    this.tone = WordTone.lime,
    this.rotate = -10.0,
    this.isLarge = true,
  });

  final String word;
  final WordTone tone;
  final double rotate;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    // Card colours sampled from the reference image itself (OCEAN / DESERT):
    // lime (203, 245, 110) and coral (236, 113, 93). These are softer than
    // the AppTheme accents, so the stickers carry their own colours.
    final bg = switch (tone) {
      WordTone.lime => const Color(0xFFCBF56E),
      WordTone.coral => const Color(0xFFEC715D),
      WordTone.neutral => const Color(0xFF2E3060),
    };

    final textColor = tone == WordTone.neutral ? Colors.white : const Color(0xFF151434);
    // Long words scale down instead of wrapping, so a sticker never breaks
    // "COFFEE" into two lines when two of them share a row.
    // One size for both words in a pair: in the reference OCEAN (5 letters)
    // and DESERT (6 letters) are set at the same size, so the size only
    // steps down for genuinely long words.
    final double fontSize;
    if (!isLarge) {
      fontSize = 14.0;
    } else if (word.length >= 9) {
      fontSize = 21.0;
    } else if (word.length >= 7) {
      fontSize = 25.0;
    } else {
      fontSize = 30.0;
    }

    return Transform.rotate(
      angle: rotate * math.pi / 180,
      child: Container(
        // Fixed height for the large pair, so both cards are always the
        // same height like the reference (about 72 tall against a 30 font).
        height: isLarge ? 72 : null,
        constraints: BoxConstraints(
          minWidth: isLarge ? 140 : 64,
        ),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: isLarge ? 22 : 14,
          vertical: isLarge ? 0 : 8,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(isLarge ? 18 : 12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B0B22).withValues(alpha: 0.60),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Text(
          word.toUpperCase(),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: GoogleFonts.outfit(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

/// Bead chain bridge connecting the two active words (OCEAN and DESERT).
/// Traced from the reference image: 6 beads in two staggered columns
/// (one centred on top, two on the left, three on the right) stepping
/// down from the lime card to the coral card. The cluster is 42x60 at
/// full size, against 72-tall cards; bead positions, radii and colours
/// below are the reference pixels scaled into that box.
class DottedChainBridge extends StatelessWidget {
  const DottedChainBridge({super.key, this.scale = 1.0});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42 * scale,
      height: 60 * scale,
      child: CustomPaint(
        painter: _ChainBridgePainter(scale),
      ),
    );
  }
}

class _ChainBridgePainter extends CustomPainter {
  const _ChainBridgePainter(this.scale);

  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    // (x, y, radius, colour) in the 42x60 box, top bead first.
    const beads = [
      (17.6, 5.0, 5.0, Color(0xFF796B5B)),
      (7.5, 16.1, 3.9, Color(0xFF6E6356)),
      (27.0, 22.3, 5.2, Color(0xFF846D5C)),
      (5.0, 29.7, 4.9, Color(0xFF7B6451)),
      (28.8, 39.6, 5.0, Color(0xFF956555)),
      (37.0, 55.1, 5.2, Color(0xFF9C6355)),
    ];

    for (final (x, y, r, c) in beads) {
      final paint = Paint()..color = c;
      canvas.drawCircle(Offset(x * scale, y * scale), r * scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
