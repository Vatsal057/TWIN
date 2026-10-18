import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

/// Reference UI Top Right Decorative Sticker cluster:
/// SAME? (Lime sticker rotated -11deg) + Dotted Arc Bridge + WORD? (Coral sticker rotated 9deg)
class ReferenceBrandMark extends StatelessWidget {
  const ReferenceBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 90,
      child: Stack(
        children: [
          // SAME? (Lime)
          Positioned(
            top: 4,
            left: 0,
            child: Transform.rotate(
              angle: -11 * math.pi / 180,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.lime,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  'SAME?',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.navy950,
                  ),
                ),
              ),
            ),
          ),
          // Dotted Bridge Arc
          Positioned.fill(
            child: CustomPaint(
              painter: _ArcBridgePainter(),
            ),
          ),
          // WORD? (Coral)
          Positioned(
            bottom: 4,
            right: 0,
            child: Transform.rotate(
              angle: 9 * math.pi / 180,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.coral,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  'WORD?',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.navy950,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcBridgePainter extends CustomPainter {
  const _ArcBridgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Beads arcing from the lime sticker to the coral one, in the muted
    // palette so the logo reads on navy.
    const beads = [
      (100.0, 22.0),
      (108.0, 28.0),
      (114.0, 36.0),
      (116.0, 44.0),
      (44.0, 44.0),
      (48.0, 52.0),
      (56.0, 58.0),
    ];

    final paint = Paint()..color = AppTheme.mist;
    for (final (x, y) in beads) {
      canvas.drawCircle(Offset(x, y), 2.8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
