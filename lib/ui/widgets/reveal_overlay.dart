import 'package:flutter/material.dart';

import '../../models/game_round.dart';
import '../app_theme.dart';
import '../layout.dart';
import 'twinning_burst.dart';

/// The simultaneous reveal. Both words slide in from opposite edges and meet in
/// the middle, which is the visual promise of the whole game.
class RevealOverlay extends StatefulWidget {
  const RevealOverlay({
    super.key,
    required this.round,
    required this.p1Name,
    required this.p2Name,
    required this.onDismiss,
  });

  final GameRound round;
  final String p1Name;
  final String p2Name;
  final VoidCallback onDismiss;

  @override
  State<RevealOverlay> createState() => _RevealOverlayState();
}

class _RevealOverlayState extends State<RevealOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _slide = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  late final Animation<double> _verdict = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.55, 1, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final round = widget.round;
    final matched = round.matched;

    return Semantics(
      liveRegion: true,
      label: _semanticSummary(),
      child: GestureDetector(
        onTap: widget.onDismiss,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: AppTheme.ink.withValues(alpha: 0.96),
          child: Stack(
            fit: StackFit.expand,
            children: [
              SafeArea(
                child: PageShell(
                  alignment: Alignment.center,
                  maxWidth: 520,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ROUND ${round.index}',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.parchment.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 40),
                        AnimatedBuilder(
                          animation: _slide,
                          builder: (context, _) {
                            final t = _slide.value;
                            return Column(
                              children: [
                                Transform.translate(
                                  offset: Offset(-120 * (1 - t), 0),
                                  child: Opacity(
                                    opacity: t,
                                    child: _RevealWord(
                                      name: widget.p1Name,
                                      word: round.displayP1Word,
                                      color: matched
                                          ? AppTheme.converged
                                          : AppTheme.playerOne,
                                      align: CrossAxisAlignment.start,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 26),
                                Transform.translate(
                                  offset: Offset(120 * (1 - t), 0),
                                  child: Opacity(
                                    opacity: t,
                                    child: _RevealWord(
                                      name: widget.p2Name,
                                      word: round.displayP2Word,
                                      color: matched
                                          ? AppTheme.converged
                                          : AppTheme.playerTwo,
                                      align: CrossAxisAlignment.end,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        // On a match the burst supplies the verdict and the
                        // dismiss hint, so this tail is the miss case only.
                        if (!matched) ...[
                          const SizedBox(height: 44),
                          FadeTransition(
                            opacity: _verdict,
                            child: _Banner(
                              icon: Icons.arrow_forward_rounded,
                              color: AppTheme.seed,
                              text: 'Not yet — aim for the middle',
                            ),
                          ),
                          const SizedBox(height: 40),
                          FadeTransition(
                            opacity: _verdict,
                            child: Text(
                              'tap to continue',
                              style: TextStyle(
                                fontSize: 11.5,
                                letterSpacing: 1.6,
                                color: AppTheme.parchment.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (matched) TwinningBurst(word: round.displayP1Word),
            ],
          ),
        ),
      ),
    );
  }

  String _semanticSummary() {
    final r = widget.round;
    final base =
        'Round ${r.index}. ${widget.p1Name} played ${r.displayP1Word}. '
        '${widget.p2Name} played ${r.displayP2Word}.';
    return r.matched
        ? '$base Twinning! You both said ${r.displayP1Word}.'
        : '$base No match yet.';
  }
}

class _RevealWord extends StatelessWidget {
  const _RevealWord({
    required this.name,
    required this.word,
    required this.color,
    required this.align,
  });

  final String name;
  final String word;
  final Color color;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          name.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: color.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          word,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w600,
            height: 1.1,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
