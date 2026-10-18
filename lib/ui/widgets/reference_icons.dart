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

/// Filled invite icon matching reference Screenshot 1 on the Start new match card:
/// A solid person silhouette, a badge circle with a lime plus, and a small sparkle.
class FilledInviteIcon extends StatelessWidget {
  const FilledInviteIcon({super.key, this.size = 46});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _InviteIconPainter(),
      ),
    );
  }
}

class _InviteIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48.0;

    const dark = Color(0xFF151434);
    const lime = AppTheme.lime;

    final darkPaint = Paint()..color = dark;
    final limeStroke = Paint()
      ..color = lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8 * s
      ..strokeCap = StrokeCap.round;

    // Person head
    canvas.drawCircle(Offset(14 * s, 11 * s), 7 * s, darkPaint);

    // Person body (shoulders & torso)
    final bodyPath = Path()
      ..moveTo(1 * s, 42 * s)
      ..lineTo(1 * s, 40 * s)
      ..cubicTo(1 * s, 32.3 * s, 6.9 * s, 26 * s, 14 * s, 26 * s)
      ..cubicTo(21.1 * s, 26 * s, 27 * s, 32.3 * s, 27 * s, 40 * s)
      ..lineTo(27 * s, 42 * s)
      ..close();
    canvas.drawPath(bodyPath, darkPaint);

    // Plus badge circle
    final badgeCenter = Offset(31 * s, 31 * s);
    final badgeRadius = 10.5 * s;
    canvas.drawCircle(badgeCenter, badgeRadius, darkPaint);
    final badgeRing = Paint()
      ..color = lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * s;
    canvas.drawCircle(badgeCenter, badgeRadius, badgeRing);

    // Plus symbol
    canvas.drawLine(
      Offset(31 * s, 26 * s),
      Offset(31 * s, 36 * s),
      limeStroke,
    );
    canvas.drawLine(
      Offset(26 * s, 31 * s),
      Offset(36 * s, 31 * s),
      limeStroke,
    );

    // Small sparkle star on top right
    final starCenter = Offset(34 * s, 6 * s);
    final starPath = Path()
      ..moveTo(starCenter.dx, starCenter.dy - 5 * s)
      ..quadraticBezierTo(starCenter.dx, starCenter.dy, starCenter.dx + 5 * s, starCenter.dy)
      ..quadraticBezierTo(starCenter.dx, starCenter.dy, starCenter.dx, starCenter.dy + 5 * s)
      ..quadraticBezierTo(starCenter.dx, starCenter.dy, starCenter.dx - 5 * s, starCenter.dy)
      ..quadraticBezierTo(starCenter.dx, starCenter.dy, starCenter.dx, starCenter.dy - 5 * s)
      ..close();
    canvas.drawPath(starPath, darkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

/// Gamepad glyph matching reference Screenshot 3 system banner
class GamepadGlyph extends StatelessWidget {
  const GamepadGlyph({super.key, this.size = 20, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.sports_esports_rounded, size: size, color: color);
  }
}
