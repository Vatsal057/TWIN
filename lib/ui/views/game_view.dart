import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/word_utils.dart';
import '../../models/game_round.dart';
import '../../models/room.dart';
import '../../state/chat_controller.dart';
import '../../state/game_controller.dart';
import '../app_theme.dart';
import '../layout.dart';
import '../widgets/anchor_pair.dart';
import '../widgets/chat_panel.dart';
import '../widgets/chat_side_panel.dart';
import '../widgets/reveal_overlay.dart';
import '../widgets/round_history.dart';
import '../widgets/round_header.dart';
import '../widgets/section_label.dart';
import '../widgets/word_composer.dart';

/// The main screen: what to aim at, where to type, what has happened so far,
/// and chat, all in one place.
class GameView extends StatelessWidget {
  const GameView({super.key});

  /// "Final round" / "3 left", or null when the game is unlimited or the end is
  /// still far off.
  static String? _endgameLabel(Room room) {
    final remaining = room.roundsRemaining;
    if (remaining == null || remaining > 3) return null;
    if (remaining <= 1) return 'Final round';
    return '$remaining left';
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final room = game.room;
    if (room == null) return const SizedBox.shrink();

    final localIsP1 = game.localPlayerId == room.p1Id;
    final reveal = game.revealingRound;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Room ${game.roomCode}'),
        actions: [
          // Only warn near the end, and only when there is an end.
          if (_endgameLabel(room) case final label?)
            if (game.stage != ViewStage.finished)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.seed.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
        ],
      ),
      body: Layout.hasRoomForSideChat(context)
          ? _WideLayout(
              game: game,
              room: room,
              localIsP1: localIsP1,
              reveal: reveal,
            )
          : _NarrowLayout(
              game: game,
              room: room,
              localIsP1: localIsP1,
              reveal: reveal,
            ),
    );
  }
}

/// Desktop browsers: game on the left, chat docked on the right and always open.
class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.game,
    required this.room,
    required this.localIsP1,
    required this.reveal,
  });

  final GameController game;
  final Room room;
  final bool localIsP1;
  final GameRound? reveal;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SafeArea(
                  child: PageShell(
                    child: _GameColumn(
                      game: game,
                      room: room,
                      localIsP1: localIsP1,
                      bottomPadding: 32,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: Layout.chatPanelWidth,
                child: SafeArea(
                  left: false,
                  child: ChatSidePanel(opponentName: game.opponentName),
                ),
              ),
            ],
          ),
        ),
        if (reveal != null)
          Positioned.fill(
            child: _Reveal(game: game, room: room, round: reveal!),
          ),
      ],
    );
  }
}

/// Phones and narrow windows: single column with chat as a bottom sheet.
class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.game,
    required this.room,
    required this.localIsP1,
    required this.reveal,
  });

  final GameController game;
  final Room room;
  final bool localIsP1;
  final GameRound? reveal;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: SafeArea(
            bottom: false,
            child: PageShell(
              child: _GameColumn(
                game: game,
                room: room,
                localIsP1: localIsP1,
                bottomPadding: ChatPanel.reservedHeight(context) + 28,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ChatPanel(opponentName: game.opponentName),
        ),
        if (reveal != null)
          Positioned.fill(
            child: _Reveal(game: game, room: room, round: reveal!),
          ),
      ],
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.game, required this.room, required this.round});

  final GameController game;
  final Room room;
  final GameRound round;

  @override
  Widget build(BuildContext context) {
    return RevealOverlay(
      round: round,
      p1Name: room.nameOf(room.p1Id),
      p2Name: room.nameOf(room.p2Id),
      onDismiss: () {
        // Only the bottom sheet can be closed; the docked panel stays open.
        if (!Layout.hasRoomForSideChat(context)) {
          context.read<ChatController>().setPanelOpen(false);
        }
        game.dismissReveal();
      },
    );
  }
}

/// The scrolling game content, identical in both layouts.
class _GameColumn extends StatelessWidget {
  const _GameColumn({
    required this.game,
    required this.room,
    required this.localIsP1,
    required this.bottomPadding,
  });

  final GameController game;
  final Room room;
  final bool localIsP1;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final opponentId = game.opponentId;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding),
      children: [
        RoundHeader(
          localName: game.localName,
          opponentName: game.opponentName,
          localIsPlayerOne: localIsP1,
          round: room.currentRound,
          maxRounds: room.config.maxRounds,
          localSubmitted: room.hasSubmitted(game.localPlayerId),
          opponentSubmitted:
              opponentId != null && room.hasSubmitted(opponentId),
        ),
        const SizedBox(height: 22),
        _Prompt(game: game, localIsP1: localIsP1),
        const SizedBox(height: 22),
        _Turn(game: game),
        if (game.errorMessage != null) ...[
          const SizedBox(height: 14),
          _ErrorNote(message: game.errorMessage!),
        ],
        if (room.rounds.isNotEmpty) ...[
          const SizedBox(height: 34),
          const SectionLabel('Round history'),
          const SizedBox(height: 12),
          RoundHistory(
            rounds: room.rounds,
            p1Id: room.p1Id,
            localPlayerId: game.localPlayerId,
          ),
        ],
      ],
    );
  }
}

/// What the player is aiming at this round.
class _Prompt extends StatelessWidget {
  const _Prompt({required this.game, required this.localIsP1});

  final GameController game;
  final bool localIsP1;

  @override
  Widget build(BuildContext context) {
    final anchor = game.anchorRound;
    final config = game.room?.config;

    if (anchor == null) {
      if (config != null && config.hasCustomStart) {
        return Column(
          children: [
            AnchorPair(
              leftWord: config.startWordA!,
              rightWord: config.startWordB!,
              leftIsPlayerOne: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.seed.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.seed.withValues(alpha: 0.28),
                ),
              ),
              child: const Text(
                'Starting pair: aim for the word in between',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.seed,
                ),
              ),
            ),
          ],
        );
      }

      final isThemed = config != null && config.hasTheme;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        decoration: BoxDecoration(
          color: AppTheme.inkCard,
          borderRadius: BorderRadius.circular(20),
          border: isThemed
              ? Border.all(color: AppTheme.converged.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          children: [
            if (isThemed) ...[
              Text(
                'CATEGORY: ${config.theme!.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppTheme.converged,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              isThemed ? 'Name something in category' : 'Name anything',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppTheme.parchment.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isThemed
                  ? 'Round one sets the starting pair in ${config.theme}. '
                        'Both enter in private.'
                  : 'Round one sets the starting pair. Neither '
                        'sees the other word until both commit.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppTheme.parchment.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return AnchorPair(
      leftWord: anchor.p1Word,
      rightWord: anchor.p2Word,
      leftIsPlayerOne: true,
    );
  }
}

/// Composer, or the waiting state once this player has committed.
class _Turn extends StatelessWidget {
  const _Turn({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return switch (game.stage) {
      ViewStage.waitingForPlayers => const _WaitingForOpponentToJoin(),
      ViewStage.waitingForOpponent => _Committed(game: game),
      _ => WordComposer(
        enabled: true,
        isSubmitting: game.isSubmitting,
        onSubmit: game.submitWord,
      ),
    };
  }
}

class _Committed extends StatelessWidget {
  const _Committed({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    final word = game.myPendingWord;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.inkRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.seed.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          if (word != null) ...[
            Text(
              'YOU PLAYED',
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w700,
                color: AppTheme.parchment.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              titleCaseWord(word),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: AppTheme.seed,
              ),
            ),
            const SizedBox(height: 18),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.8),
              ),
              const SizedBox(width: 12),
              Text(
                'Waiting for ${game.opponentName}',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.parchment.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaitingForOpponentToJoin extends StatelessWidget {
  const _WaitingForOpponentToJoin();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.inkRaised,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.8),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Your opponent left the room. Waiting for them to come back.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppTheme.parchment.withValues(alpha: 0.65),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
