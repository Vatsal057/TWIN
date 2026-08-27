import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Who is playing, which round it is, and who has locked a word in.
///
/// There are no scores: the game is collaborative, so the only number that
/// matters is the round count, and it belongs to both players equally.
class RoundHeader extends StatelessWidget {
  const RoundHeader({
    super.key,
    required this.localName,
    required this.opponentName,
    required this.localIsPlayerOne,
    required this.round,
    required this.maxRounds,
    this.opponentSubmitted = false,
    this.localSubmitted = false,
  });

  final String localName;
  final String opponentName;
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
      child: Column(
        children: [
          Text(
            maxRounds == null ? 'ROUND $round' : 'ROUND $round OF $maxRounds',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: AppTheme.parchment.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Side(
                  name: localName,
                  color: AppTheme.colorForSlot(localIsPlayerOne),
                  locked: localSubmitted,
                  alignEnd: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.add_rounded,
                  size: 14,
                  color: AppTheme.parchment.withValues(alpha: 0.35),
                ),
              ),
              Expanded(
                child: _Side(
                  name: opponentName,
                  color: AppTheme.colorForSlot(!localIsPlayerOne),
                  locked: opponentSubmitted,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.name,
    required this.color,
    required this.locked,
    required this.alignEnd,
  });

  final String name;
  final Color color;
  final bool locked;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (!alignEnd) ...[_dot(), const SizedBox(width: 8)],
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        if (alignEnd) ...[const SizedBox(width: 8), _dot()],
      ],
    );
  }

  Widget _dot() {
    // Filled once that player has locked a word in for this round. It reveals
    // readiness, never the word itself.
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: locked ? color : Colors.transparent,
        border: Border.all(color: color.withValues(alpha: locked ? 1 : 0.45)),
      ),
    );
  }
}
