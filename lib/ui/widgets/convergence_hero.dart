import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/word_utils.dart';
import '../app_theme.dart';

/// Animated convergence hero.
///
/// Draws two signal arcs that sweep toward each other and meet when both
/// players land on the same word.
class ConvergenceHero extends StatefulWidget {
  const ConvergenceHero({
    super.key,
    required this.converged,
    required this.abandoned,
    required this.word,
    required this.rounds,
  });

  final bool converged;
  final bool abandoned;
  final String? word;
  final int rounds;

  @override
  State<ConvergenceHero> createState() => _ConvergenceHeroState();
}

class _ConvergenceHeroState extends State<ConvergenceHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final Animation<double> _sweep = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  late final Animation<double> _contentFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
  );

  late final Animation<Offset> _contentSlide =
      Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
        ),
      );

  @override
  void initState() {
    super.initState();
    _controller.forward().then((_) {
      if (mounted && widget.converged) {
        HapticFeedback.lightImpact();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final converged = widget.converged;
    final abandoned = widget.abandoned;
    final rounds = widget.rounds;

    final borderColor = converged
        ? AppTheme.lime.withValues(alpha: 0.35)
        : (abandoned
              ? Colors.white.withValues(alpha: 0.10)
              : AppTheme.coral.withValues(alpha: 0.25));

    final title = converged
        ? 'TWINNING'
        : (abandoned ? 'GAME ABANDONED' : 'OUT OF ROUNDS');

    final subtitle = converged
        ? (rounds == 1
              ? 'You both said the same word in 1 round.'
              : 'You both said the same word in $rounds rounds.')
        : (abandoned
              ? 'Someone left before you converged.'
              : 'Ran out of rounds before converging.');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppTheme.navy900,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (converged)
            BoxShadow(
              color: AppTheme.lime.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        children: [
          // Animated dual-arc gauge: the two arcs meet on a win
          AnimatedBuilder(
            animation: _sweep,
            builder: (context, _) {
              final t = _sweep.value;

              return SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _ResonanceDialPainter(
                    progress: t,
                    converged: converged,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$rounds',
                          style: GoogleFonts.outfit(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'ROUNDS',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                            color: AppTheme.mist,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // Word & summary
          SlideTransition(
            position: _contentSlide,
            child: FadeTransition(
              opacity: _contentFade,
              child: Column(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                      color: converged
                          ? AppTheme.lime
                          : (abandoned ? AppTheme.mist : AppTheme.coral),
                    ),
                  ),
                  if (widget.word case final word?) ...[
                    const SizedBox(height: 10),
                    Text(
                      titleCaseWord(word),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      height: 1.45,
                      color: AppTheme.mist,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResonanceDialPainter extends CustomPainter {
  const _ResonanceDialPainter({
    required this.progress,
    required this.converged,
  });

  final double progress;
  final bool converged;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const strokeWidth = 4.5;

    // Subtle track
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (!converged) {
      // A short coral arc that never closes: the two sides did not meet.
      final failPaint = Paint()
        ..color = AppTheme.coral.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * 0.35 * progress,
        false,
        failPaint,
      );
      return;
    }

    // Each player's arc sweeps half the circle, so they meet exactly as the
    // animation completes.
    final sweepAngle = math.pi * progress;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Player 1 arc (marigold): sweeps clockwise from the top
    final p1Paint = Paint()
      ..color = AppTheme.playerOne
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, p1Paint);

    // Player 2 arc (cyan): sweeps clockwise from the bottom
    final p2Paint = Paint()
      ..color = AppTheme.playerTwo
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi / 2, sweepAngle, false, p2Paint);

    // When approaching convergence, draw the unified converged green overlay
    final blendT = ((progress - 0.70) / 0.30).clamp(0.0, 1.0);
    if (blendT > 0) {
      final blendPaint = Paint()
        ..color = AppTheme.converged.withValues(alpha: blendT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 0.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        blendPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ResonanceDialPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.converged != converged;
}
