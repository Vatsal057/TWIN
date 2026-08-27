import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Round counter plus both scores. Colour identifies the player slot and is
/// reused everywhere else (history, reveal), so the mapping stays learnable.
class ScoreHeader extends StatelessWidget {
  const ScoreHeader({
    super.key,
    required this.localName,
    required this.opponentName,
    required this.localScore,
    required this.opponentScore,
    required this.localIsPlayerOne,
    required this.round,
    required this.maxRounds,
    this.opponentSubmitted = false,
    this.localSubmitted = false,
  });

  final String localName;
  final String opponentName;
  final int localScore;
  final int opponentScore;
  final bool localIsPlayerOne;
  final int round;

  /// Null for an unlimited game, which shows a bare round number.
  final int? maxRounds;
  final bool opponentSubmitted;
  final bool localSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.inkRaised,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Side(
              name: localName,
              score: localScore,
              color: AppTheme.colorForSlot(localIsPlayerOne),
              locked: localSubmitted,
              alignEnd: false,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                Text(
                  'ROUND',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.parchment.withValues(alpha: 0.38),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  maxRounds == null ? '$round' : '$round/$maxRounds',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _Side(
              name: opponentName,
              score: opponentScore,
              color: AppTheme.colorForSlot(!localIsPlayerOne),
              locked: opponentSubmitted,
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.name,
    required this.score,
    required this.color,
    required this.locked,
    required this.alignEnd,
  });

  final String name;
  final int score;
  final Color color;
  final bool locked;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final nameRow = Row(
      mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!alignEnd) _dot(),
        if (!alignEnd) const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.parchment.withValues(alpha: 0.7),
            ),
          ),
        ),
        if (alignEnd) const SizedBox(width: 6),
        if (alignEnd) _dot(),
      ],
    );

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        nameRow,
        const SizedBox(height: 2),
        Text(
          '$score',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _dot() {
    // Filled once that player has locked a word in for this round. It reveals
    // readiness, never the word itself.
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: locked ? color : Colors.transparent,
        border: Border.all(color: color.withValues(alpha: locked ? 1 : 0.45)),
      ),
    );
  }
}
