import 'package:flutter/material.dart';

import '../../models/game_round.dart';
import '../app_theme.dart';

/// The simultaneous reveal. Both words slide in from opposite edges and meet in
/// the middle, which is the visual promise of the whole game.
class RevealOverlay extends StatefulWidget {
  const RevealOverlay({
    super.key,
    required this.round,
    required this.p1Id,
    required this.p1Name,
    required this.p2Name,
    required this.localPlayerId,
    required this.onDismiss,
  });

  final GameRound round;
  final String p1Id;
  final String p1Name;
  final String p2Name;
  final String localPlayerId;
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

    return Semantics(
      liveRegion: true,
      label: _semanticSummary(),
      child: GestureDetector(
        onTap: widget.onDismiss,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: AppTheme.ink.withValues(alpha: 0.96),
          child: SafeArea(
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
                                similarity: round.p1Similarity,
                                color: AppTheme.playerOne,
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
                                similarity: round.p2Similarity,
                                color: AppTheme.playerTwo,
                                align: CrossAxisAlignment.end,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 44),
                  FadeTransition(
                    opacity: _verdict,
                    child: _Verdict(
                      round: round,
                      p1Id: widget.p1Id,
                      p1Name: widget.p1Name,
                      p2Name: widget.p2Name,
                      localPlayerId: widget.localPlayerId,
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
                        color: AppTheme.parchment.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    if (r.matched) return '$base The words converged.';
    return switch (r.scoreKind) {
      RoundScoreKind.unscored => '$base Opening round, no points.',
      RoundScoreKind.both => '$base Too close to call, both scored.',
      RoundScoreKind.none => '$base Too close to call, no points.',
      RoundScoreKind.player =>
        '$base ${r.scoreWinner == widget.p1Id ? widget.p1Name : widget.p2Name} '
            'was closer and scored.',
    };
  }
}

class _RevealWord extends StatelessWidget {
  const _RevealWord({
    required this.name,
    required this.word,
    required this.similarity,
    required this.color,
    required this.align,
  });

  final String name;
  final String word;
  final double? similarity;
  final Color color;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final sim = similarity;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          name.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: color.withValues(alpha: 0.7),
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
        if (sim != null) ...[
          const SizedBox(height: 4),
          Text(
            '${(sim.clamp(0.0, 1.0) * 100).round()}% to midpoint',
            style: TextStyle(
              fontSize: 11.5,
              color: AppTheme.parchment.withValues(alpha: 0.62),
            ),
          ),
        ],
      ],
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.round,
    required this.p1Id,
    required this.p1Name,
    required this.p2Name,
    required this.localPlayerId,
  });

  final GameRound round;
  final String p1Id;
  final String p1Name;
  final String p2Name;
  final String localPlayerId;

  @override
  Widget build(BuildContext context) {
    if (round.matched) {
      return _Banner(
        icon: Icons.auto_awesome_rounded,
        color: AppTheme.converged,
        text: 'Same word. You are in sync.',
      );
    }

    return switch (round.scoreKind) {
      RoundScoreKind.unscored => _Banner(
        icon: Icons.flag_outlined,
        color: AppTheme.parchment.withValues(alpha: 0.6),
        text: 'Opening pair set. No points this round.',
      ),
      RoundScoreKind.both => _Banner(
        icon: Icons.balance_rounded,
        color: AppTheme.seed,
        text: 'Dead heat. A point each.',
      ),
      RoundScoreKind.none => _Banner(
        icon: Icons.balance_rounded,
        color: AppTheme.parchment.withValues(alpha: 0.6),
        text: 'Dead heat. No points.',
      ),
      RoundScoreKind.player => _Banner(
        icon: Icons.add_circle_outline_rounded,
        color: round.scoreWinner == p1Id
            ? AppTheme.playerOne
            : AppTheme.playerTwo,
        text: round.scoreWinner == localPlayerId
            ? 'You were closer. +1'
            : '${round.scoreWinner == p1Id ? p1Name : p2Name} was closer. +1',
      ),
    };
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
