import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Filled settings cog icon matching the reference screenshot:
/// A solid silhouette with smooth outer teeth and a clear center hole.
class FilledSettingsCog extends StatelessWidget {
  const FilledSettingsCog({super.key, this.size = 22, this.color = const Color(0xFFC6C9E8)});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SettingsCogPainter(color: color),
      ),
    );
  }
}

class _SettingsCogPainter extends CustomPainter {
  _SettingsCogPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width * 0.48;
    final innerRadius = size.width * 0.36;
    final holeRadius = size.width * 0.17;
    const teeth = 8;

    final path = Path();
    for (int i = 0; i < teeth; i++) {
      final angle1 = (i * 2 * math.pi / teeth) - (math.pi / teeth / 2);
      final angle2 = angle1 + (math.pi / teeth * 0.35);
      final angle3 = angle1 + (math.pi / teeth * 0.65);
      final angle4 = (i + 1) * 2 * math.pi / teeth - (math.pi / teeth / 2);

      final p1 = center + Offset(math.cos(angle1) * innerRadius, math.sin(angle1) * innerRadius);
      final p2 = center + Offset(math.cos(angle2) * outerRadius, math.sin(angle2) * outerRadius);
      final p3 = center + Offset(math.cos(angle3) * outerRadius, math.sin(angle3) * outerRadius);
      final p4 = center + Offset(math.cos(angle4) * innerRadius, math.sin(angle4) * innerRadius);

      if (i == 0) {
        path.moveTo(p1.dx, p1.dy);
      } else {
        path.lineTo(p1.dx, p1.dy);
      }
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(p3.dx, p3.dy);
      path.lineTo(p4.dx, p4.dy);
    }
    path.close();

    // Center circular hole using difference
    final hole = Path()
      ..addOval(Rect.fromCircle(center: center, radius: holeRadius));
    final combined = Path.combine(PathOperation.difference, path, hole);

    canvas.drawPath(combined, paint);
  }

  @override
  bool shouldRepaint(covariant _SettingsCogPainter oldDelegate) => oldDelegate.color != color;
}

/// Create-game glyph: two circles fused into each other, the
/// overlap punched out in lime. Two words becoming one word,
/// which is the whole game, in a single shape.
class ConvergeIcon extends StatelessWidget {
  const ConvergeIcon({super.key, this.size = 46});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ConvergeIconPainter(),
      ),
    );
  }
}

class _ConvergeIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48.0;
    const dark = Color(0xFF151434);
    final darkPaint = Paint()..color = dark;

    final circleA = Path()
      ..addOval(Rect.fromCircle(center: Offset(17 * s, 24 * s), radius: 12 * s));
    final circleB = Path()
      ..addOval(Rect.fromCircle(center: Offset(31 * s, 24 * s), radius: 12 * s));

    canvas.drawPath(circleA, darkPaint);
    canvas.drawPath(circleB, darkPaint);

    // The overlap of the two circles, in lime
    final lens = Path.combine(PathOperation.intersect, circleA, circleB);
    canvas.drawPath(lens, Paint()..color = AppTheme.lime);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
