import 'package:flutter/material.dart';

import '../../models/game_round.dart';
import '../app_theme.dart';

/// Full round-by-round record: both words and who took the point.
/// Newest first, because that is the row people actually look at.
class RoundHistory extends StatelessWidget {
  const RoundHistory({
    super.key,
    required this.rounds,
    required this.p1Id,
    required this.localPlayerId,
    this.showSimilarity = true,
  });

  final List<GameRound> rounds;
  final String p1Id;
  final String localPlayerId;
  final bool showSimilarity;

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

    final localIsP1 = localPlayerId == p1Id;
    final ordered = rounds.reversed.toList();

    return Column(
      children: [
        for (final round in ordered)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RoundHistoryTile(
              round: round,
              p1Id: p1Id,
              localIsPlayerOne: localIsP1,
              showSimilarity: showSimilarity,
            ),
          ),
      ],
    );
  }
}

class RoundHistoryTile extends StatelessWidget {
  const RoundHistoryTile({
    super.key,
    required this.round,
    required this.p1Id,
    required this.localIsPlayerOne,
    this.showSimilarity = true,
  });

  final GameRound round;
  final String p1Id;
  final bool localIsPlayerOne;
  final bool showSimilarity;

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
        crossAxisAlignment: CrossAxisAlignment.center,
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
            child: _WordCell(
              word: round.displayP1Word,
              similarity: showSimilarity ? round.p1Similarity : null,
              color: AppTheme.playerOne,
              scored: round.scoreKind == RoundScoreKind.player
                  ? round.scoreWinner == p1Id
                  : round.scoreKind == RoundScoreKind.both,
              align: CrossAxisAlignment.start,
            ),
          ),
          _Verdict(round: round),
          Expanded(
            child: _WordCell(
              word: round.displayP2Word,
              similarity: showSimilarity ? round.p2Similarity : null,
              color: AppTheme.playerTwo,
              scored: round.scoreKind == RoundScoreKind.player
                  ? (round.scoreWinner != null && round.scoreWinner != p1Id)
                  : round.scoreKind == RoundScoreKind.both,
              align: CrossAxisAlignment.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _WordCell extends StatelessWidget {
  const _WordCell({
    required this.word,
    required this.similarity,
    required this.color,
    required this.scored,
    required this.align,
  });

  final String word;
  final double? similarity;
  final Color color;
  final bool scored;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final sim = similarity;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          word,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align == CrossAxisAlignment.end
              ? TextAlign.right
              : TextAlign.left,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: scored ? FontWeight.w700 : FontWeight.w500,
            color: scored ? color : AppTheme.parchment.withValues(alpha: 0.78),
          ),
        ),
        if (sim != null) ...[
          const SizedBox(height: 2),
          Text(
            _percent(sim),
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.3,
              color: AppTheme.parchment.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }

  static String _percent(double similarity) {
    final pct = (similarity.clamp(0.0, 1.0) * 100).round();
    return '$pct% to midpoint';
  }
}

/// The small mark between the two words explaining the round's outcome.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.round});

  final GameRound round;

  @override
  Widget build(BuildContext context) {
    final (icon, color, tooltip) = switch (round) {
      GameRound(matched: true) => (
        Icons.check_circle,
        AppTheme.converged,
        'Converged',
      ),
      GameRound(scoreKind: RoundScoreKind.unscored) => (
        Icons.remove_circle_outline,
        AppTheme.parchment.withValues(alpha: 0.5),
        'Opening round, not scored',
      ),
      GameRound(scoreKind: RoundScoreKind.both) => (
        Icons.balance_rounded,
        AppTheme.parchment.withValues(alpha: 0.55),
        'Too close to call, both scored',
      ),
      GameRound(scoreKind: RoundScoreKind.none) => (
        Icons.balance_rounded,
        AppTheme.parchment.withValues(alpha: 0.55),
        'Too close to call, nobody scored',
      ),
      _ => (
        Icons.arrow_back_ios_new_rounded,
        AppTheme.parchment.withValues(alpha: 0.5),
        'Closer word takes the point',
      ),
    };

    // Point the arrow at whoever won.
    final flip =
        round.scoreKind == RoundScoreKind.player &&
        round.scoreWinner != null &&
        round.p1Similarity != null &&
        round.p2Similarity != null &&
        round.p2Similarity! > round.p1Similarity!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Tooltip(
        message: tooltip,
        child: Transform.rotate(
          angle: flip ? 3.14159 : 0,
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}
