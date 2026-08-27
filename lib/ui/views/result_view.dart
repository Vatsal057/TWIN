import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/word_utils.dart';
import '../../models/room.dart';
import '../../state/app_session.dart';
import '../../state/game_controller.dart';
import '../app_theme.dart';
import '../layout.dart';
import '../room_launcher.dart';
import '../widgets/round_history.dart';
import '../widgets/section_label.dart';

/// The sync screen.
///
/// Collaborative, so there is no winner and no score breakdown. Either the two
/// of you landed on the same word or you didn't, and the number that matters is
/// how many rounds it took — a result you share.
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
              ),
              const SizedBox(height: 24),
              _Players(game: game, room: room),
              const SizedBox(height: 28),
              const SectionLabel('Every round'),
              const SizedBox(height: 12),
              RoundHistory(
                rounds: room.rounds,
                p1Id: room.p1Id,
                localPlayerId: game.localPlayerId,
              ),
              const SizedBox(height: 32),
              _Actions(game: game, room: room),
            ],
          ),
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
  });

  final bool converged;
  final bool abandoned;
  final String? word;
  final int rounds;

  @override
  Widget build(BuildContext context) {
    final color = converged
        ? AppTheme.converged
        : (abandoned
              ? AppTheme.parchment.withValues(alpha: 0.5)
              : AppTheme.seed);

    final title = converged
        ? 'Twinning!'
        : (abandoned ? 'Game abandoned' : 'Out of rounds');

    final subtitle = converged
        ? 'You both said the same word.'
        : (abandoned
              ? 'Someone left before you twinned.'
              : 'You ran out of rounds before twinning.');

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
              textAlign: TextAlign.center,
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
              color: AppTheme.parchment.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.ink.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              rounds == 1 ? 'in 1 round' : 'in $rounds rounds',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppTheme.parchment.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Both names side by side. No numbers — the result belongs to the pair.
class _Players extends StatelessWidget {
  const _Players({required this.game, required this.room});

  final GameController game;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final localIsP1 = game.localPlayerId == room.p1Id;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            game.localName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.colorForSlot(localIsP1),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '+',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.parchment.withValues(alpha: 0.5),
            ),
          ),
        ),
        Flexible(
          child: Text(
            game.opponentName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.colorForSlot(!localIsP1),
            ),
          ),
        ),
      ],
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
            label: const Text('Play again'),
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
    final buffer = StringBuffer('TWIN — ');
    if (room.converged && last != null) {
      buffer.writeln(
        '${game.localName} and ${game.opponentName} twinned on '
        '"${titleCaseWord(last.p1Word)}" in ${room.rounds.length} rounds.',
      );
    } else {
      buffer.writeln(
        '${game.localName} and ${game.opponentName} played '
        '${room.rounds.length} rounds without twinning.',
      );
    }
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
