import 'package:flutter/material.dart';

import '../../models/game_round.dart';
import '../app_theme.dart';

/// Round-by-round record: the two words, and whether they met.
/// Newest first, because that is the row people actually look at.
class RoundHistory extends StatelessWidget {
  const RoundHistory({
    super.key,
    required this.rounds,
    required this.p1Id,
    required this.localPlayerId,
  });

  final List<GameRound> rounds;
  final String p1Id;
  final String localPlayerId;

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          'No rounds yet.',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.parchment.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final round in rounds.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RoundHistoryTile(round: round),
          ),
      ],
    );
  }
}

class RoundHistoryTile extends StatelessWidget {
  const RoundHistoryTile({super.key, required this.round});

  final GameRound round;

  @override
  Widget build(BuildContext context) {
    final matched = round.matched;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: matched
            ? AppTheme.converged.withValues(alpha: 0.12)
            : AppTheme.inkRaised,
        borderRadius: BorderRadius.circular(14),
        border: matched
            ? Border.all(color: AppTheme.converged.withValues(alpha: 0.45))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${round.index}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.parchment.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              round.displayP1Word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: matched
                    ? AppTheme.converged
                    : AppTheme.playerOne.withValues(alpha: 0.95),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(
              matched ? Icons.check_circle : Icons.swap_horiz_rounded,
              size: 15,
              color: matched
                  ? AppTheme.converged
                  : AppTheme.parchment.withValues(alpha: 0.35),
            ),
          ),
          Expanded(
            child: Text(
              round.displayP2Word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: matched
                    ? AppTheme.converged
                    : AppTheme.playerTwo.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
