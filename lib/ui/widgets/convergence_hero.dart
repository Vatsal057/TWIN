import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/word_utils.dart';
import '../app_theme.dart';

int calcResonanceScore(int rounds, bool converged) {
  if (!converged) return 0;
  return switch (rounds) {
    1 => 100,
    2 => 95,
    3 => 88,
    4 => 78,
    5 => 68,
    _ => (100 - (rounds * 7)).clamp(20, 60),
  };
}

String calcResonanceLabel(int score) {
  if (score >= 98) return 'Instant resonance';
  if (score >= 90) return 'Synchronized';
  if (score >= 80) return 'Harmonious';
  if (score >= 65) return 'Aligned';
  return 'Converged';
}

/// Animated convergence hero.
///
/// Draws two converging signal arcs that sweep toward each other and lock into
/// unison when both players land on the same word, paired with an ease-out
/// resonance counter.
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
    final score = calcResonanceScore(rounds, converged);
    final label = calcResonanceLabel(score);

    final borderColor = converged
        ? AppTheme.converged.withValues(alpha: 0.3)
        : (abandoned
              ? AppTheme.parchment.withValues(alpha: 0.15)
              : AppTheme.seed.withValues(alpha: 0.25));

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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppTheme.inkCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // Animated dual-arc resonance gauge
          AnimatedBuilder(
            animation: _sweep,
            builder: (context, _) {
              final t = _sweep.value;
              final displayScore = (score * t).round();

              return SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _ResonanceDialPainter(
                    progress: t,
                    score: score,
                    converged: converged,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          converged ? '$displayScore%' : '$rounds',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -0.5,
                            color: AppTheme.parchment,
                          ),
                        ),
                        Text(
                          converged ? 'RESONANCE' : 'ROUNDS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                            color: AppTheme.parchment.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Word & summary
          SlideTransition(
            position: _contentSlide,
            child: FadeTransition(
              opacity: _contentFade,
              child: Column(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.4,
                      color: converged
                          ? AppTheme.converged
                          : (abandoned
                                ? AppTheme.parchment.withValues(alpha: 0.5)
                                : AppTheme.seed),
                    ),
                  ),
                  if (widget.word case final word?) ...[
                    const SizedBox(height: 12),
                    Text(
                      titleCaseWord(word),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 2.8,
                        color: AppTheme.parchment,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppTheme.parchment.withValues(alpha: 0.65),
                    ),
                  ),
                  if (converged) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.converged.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.converged.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        label.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          color: AppTheme.converged,
                        ),
                      ),
                    ),
                  ],
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
    required this.score,
    required this.converged,
  });

  final double progress;
  final int score;
  final bool converged;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const strokeWidth = 4.5;

    // Subtle track
    final trackPaint = Paint()
      ..color = AppTheme.parchment.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (!converged) {
      final failPaint = Paint()
        ..color = AppTheme.seed.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * (score / 100) * progress,
        false,
        failPaint,
      );
      return;
    }

    final sweepAngle = (math.pi * (score / 100)) * progress;
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
        math.pi * 2 * (score / 100) * progress,
        false,
        blendPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ResonanceDialPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.score != score ||
      oldDelegate.converged != converged;
}
