import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/word_utils.dart';
import '../../models/game_round.dart';
import '../../models/room.dart';
import '../../services/embeddings/glove_similarity.dart';
import '../../state/app_session.dart';
import '../../state/game_controller.dart';
import '../app_theme.dart';
import '../room_launcher.dart';
import '../widgets/round_history.dart';
import '../widgets/section_label.dart';

/// The sync screen. Leads with whether the two of you landed on the same word,
/// then the round count and the score breakdown, then the full history.
class ResultView extends StatelessWidget {
  const ResultView({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final room = game.room;
    if (room == null) return const SizedBox.shrink();

    final converged = room.converged;
    final abandoned = room.finishReason == FinishReason.abandoned;
    final finalRound = room.lastRound;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Result'),
      ),
      body: SafeArea(
        child: PageShell(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _Headline(
              converged: converged,
              abandoned: abandoned,
              word: converged ? finalRound?.p1Word : null,
              rounds: room.rounds.length,
              convergence: game.convergence,
            ),
            const SizedBox(height: 28),
            const SectionLabel('Score'),
            const SizedBox(height: 12),
            _ScoreBreakdown(game: game, room: room),
            const SizedBox(height: 28),
            const SectionLabel('Every round'),
            const SizedBox(height: 12),
            RoundHistory(
              rounds: room.rounds,
              p1Id: room.p1Id,
              localPlayerId: game.localPlayerId,
            ),
            if (!converged && finalRound != null) ...[
              const SizedBox(height: 24),
              _NearMiss(
                round: finalRound,
                played: game.playedWords,
                similarity: context.read<AppSession>().similarity,
              ),
            ],
            const SizedBox(height: 32),
            _Actions(game: game, room: room),
          ],
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({
    required this.converged,
    required this.abandoned,
    required this.word,
    required this.rounds,
    required this.convergence,
  });

  final bool converged;
  final bool abandoned;
  final String? word;
  final int rounds;
  final double convergence;

  @override
  Widget build(BuildContext context) {
    final color = converged
        ? AppTheme.converged
        : (abandoned ? AppTheme.parchment.withValues(alpha: 0.5) : AppTheme.seed);

    final title = converged
        ? 'In sync'
        : (abandoned ? 'Game abandoned' : 'Out of rounds');

    final subtitle = converged
        ? 'You both said the same word.'
        : (abandoned
              ? 'Someone left before you converged.'
              : 'You closed the gap to ${(convergence * 100).round()}%.');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(
            converged
                ? Icons.auto_awesome_rounded
                : (abandoned
                      ? Icons.exit_to_app_rounded
                      : Icons.hourglass_bottom_rounded),
            color: color,
            size: 30,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: color,
            ),
          ),
          if (word != null) ...[
            const SizedBox(height: 14),
            Text(
              titleCaseWord(word!),
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.5,
                color: AppTheme.parchment,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppTheme.parchment.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.ink.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              rounds == 1 ? '1 round' : '$rounds rounds',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppTheme.parchment.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBreakdown extends StatelessWidget {
  const _ScoreBreakdown({required this.game, required this.room});

  final GameController game;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final localIsP1 = game.localPlayerId == room.p1Id;
    final mine = game.myScore;
    final theirs = game.opponentScore;
    final scoredRounds = room.rounds.where((r) => r.isScored).length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ScoreCard(
                name: game.localName,
                score: mine,
                color: AppTheme.colorForSlot(localIsP1),
                leading: mine > theirs,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ScoreCard(
                name: game.opponentName,
                score: theirs,
                color: AppTheme.colorForSlot(!localIsP1),
                leading: theirs > mine,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          scoredRounds == 0
              ? 'No scored rounds — round one is always a free opening.'
              : '$scoredRounds scored ${scoredRounds == 1 ? 'round' : 'rounds'} '
                    '(round one is never scored).',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.parchment.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.name,
    required this.score,
    required this.color,
    required this.leading,
  });

  final String name;
  final int score;
  final Color color;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.inkCard,
        borderRadius: BorderRadius.circular(16),
        border: leading
            ? Border.all(color: color.withValues(alpha: 0.45))
            : null,
      ),
      child: Column(
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.parchment.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Post-game insight: the words that actually sat closest to the final
/// midpoint. Only shown here, never during play.
class _NearMiss extends StatelessWidget {
  const _NearMiss({
    required this.round,
    required this.played,
    required this.similarity,
  });

  final GameRound round;
  final Set<String> played;
  final GloveSimilarity similarity;

  @override
  Widget build(BuildContext context) {
    final closest = similarity.nearestToMidpoint(
      round.p1Word,
      round.p2Word,
      count: 3,
      exclude: played,
    );
    if (closest.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.inkRaised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Where you were heading'),
          const SizedBox(height: 12),
          Text(
            'Closest words to your final midpoint: '
            '${closest.map(titleCaseWord).join(', ')}.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppTheme.parchment.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.game, required this.room});

  final GameController game;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final pendingRematch = room.rematchRoomCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pendingRematch != null)
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              RoomLauncher.joinAndOpen(
                context,
                context.read<AppSession>(),
                pendingRematch,
              );
            },
            icon: const Icon(Icons.replay_rounded),
            label: Text('Join rematch $pendingRematch'),
          )
        else
          FilledButton.icon(
            onPressed: () async {
              final fresh = await game.startRematch();
              if (fresh == null || !context.mounted) return;
              Navigator.of(context).pop();
              RoomLauncher.open(context, fresh.code);
            },
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Rematch'),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _shareResult(game, room),
          icon: const Icon(Icons.ios_share_rounded, size: 18),
          label: const Text('Share result'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to home'),
        ),
      ],
    );
  }

  static Future<void> _shareResult(GameController game, Room room) {
    final last = room.lastRound;
    final buffer = StringBuffer('Naamkaran — ');
    if (room.converged && last != null) {
      buffer.writeln(
        'we converged on "${titleCaseWord(last.p1Word)}" '
        'in ${room.rounds.length} rounds.',
      );
    } else {
      buffer.writeln('${room.rounds.length} rounds, no convergence.');
    }
    buffer.writeln('${game.localName} ${game.myScore} — '
        '${game.opponentScore} ${game.opponentName}');
    buffer.writeln();
    for (final round in room.rounds) {
      buffer.writeln(
        '${round.index}. ${titleCaseWord(round.p1Word)} / '
        '${titleCaseWord(round.p2Word)}',
      );
    }
    return SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }
}
