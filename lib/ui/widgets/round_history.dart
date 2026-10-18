import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/word_utils.dart';
import '../../models/game_round.dart';
import '../../state/app_session.dart';

/// Round history card container matching reference Screenshot 2:
/// - Rounded card with subtle border and dividers
/// - Each row: "Round X" on the left, pill for Word 1, "/" separator, pill for Word 2
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
    final p = context.watch<AppSession>().palette;
    if (rounds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Newest round first: the latest pair sits at the top,
            // right under the stickers it produced, and the game
            // reads back down to round 1.
            for (int i = rounds.length - 1; i >= 0; i--) ...[
              if (i < rounds.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: p.text.withValues(alpha: 0.07),
                ),
              _RoundRow(round: rounds[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundRow extends StatelessWidget {
  const _RoundRow({required this.round});

  final GameRound round;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppSession>().palette;
    final matched = round.matched;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Round label (e.g. Round 1)
          SizedBox(
            width: 72,
            child: Text(
              'Round ${round.index}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: p.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Word 1 Pill
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: p.raised,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                titleCaseWord(round.p1Word).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: matched ? p.accentInk : p.text,
                ),
              ),
            ),
          ),

          // Slash separator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '/',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: p.muted,
              ),
            ),
          ),

          // Word 2 Pill
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: p.raised,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                titleCaseWord(round.p2Word).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: matched ? p.accentInk : p.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
