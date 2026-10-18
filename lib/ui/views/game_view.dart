import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/room.dart';
import '../../state/app_session.dart';
import '../../state/chat_controller.dart';
import '../../state/game_controller.dart';
import '../app_theme.dart';
import '../widgets/anchor_pair.dart';
import '../widgets/reference_round_header.dart';
import '../widgets/reveal_overlay.dart';
import '../widgets/round_history.dart';
import '../widgets/word_composer.dart';
import 'chat_room_view.dart';

/// Full-screen Game View matching reference Screenshot 2:
/// - Custom header: Close (X) button on left, "Round X" / "Find the bridge word" center, Chat button with badge on right
/// - Player slots: "You" with live turn dot vs Partner with locked/thinking status
/// - Big tilted word stickers (OCEAN & DESERT) with organic dotted bead chain
/// - Previous round history in pill rows
/// - Capsule word input & neon lime "Lock in" button
class GameView extends StatelessWidget {
  const GameView({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final room = game.room;
    if (room == null) return const SizedBox.shrink();

    final localIsP1 = game.localPlayerId == room.p1Id;
    final reveal = game.revealingRound;

    final nudgeAlert = game.consumeNudgeAlert();
    if (nudgeAlert != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nudgeAlert),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.navy950,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Custom Top Header matching Screenshot 2
                _GameHeader(game: game, room: room),

                // Category theme pill if set
                if (room.config.theme case final theme?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        theme.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppTheme.mist,
                        ),
                      ),
                    ),
                  ),

                // Main Content: Reveal Preview if both words entered, else Gameplay
                Expanded(
                  child: reveal != null
                      ? RevealOverlay(
                          round: reveal,
                          p1Name: room.nameOf(room.p1Id),
                          p2Name: room.nameOf(room.p2Id),
                          localIsP1: localIsP1,
                          onDismiss: () => game.dismissReveal(),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                          children: [
                            // Player Slots (You vs Opponent)
                            ReferenceRoundHeader(
                              localName: game.localName,
                              opponentName: game.opponentName,
                              localIsPlayerOne: localIsP1,
                              round: room.currentRound,
                              maxRounds: room.config.maxRounds,
                              localSubmitted: room.hasSubmitted(game.localPlayerId),
                              opponentSubmitted: game.opponentId != null &&
                                  room.hasSubmitted(game.opponentId!),
                              localAvatarId: context.read<AppSession>().profileAvatarId,
                              opponentAvatarId: room.avatarOf(game.opponentId),
                            ),

                            const SizedBox(height: 28),

                            // Tilted Word Stickers & Dotted Bead Bridge
                            _PromptSection(game: game, localIsP1: localIsP1),

                            const SizedBox(height: 28),

                            // Input or Committed State
                            _TurnSection(game: game),

                            if (game.errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Center(
                                child: Text(
                                  game.errorMessage!,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: AppTheme.coral,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],

                            // Previous rounds history
                            if (room.rounds.isNotEmpty) ...[
                              const SizedBox(height: 32),
                              RoundHistory(
                                rounds: room.rounds,
                                p1Id: room.p1Id,
                                localPlayerId: game.localPlayerId,
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header matching Screenshot 2:
/// Left: Frosted circle X button
/// Center: Round number & "Find the bridge word"
/// Right: Frosted circle Chat button with live unread badge
class _GameHeader extends StatelessWidget {
  const _GameHeader({required this.game, required this.room});

  final GameController game;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController?>();
    final unread = chat?.unreadCount ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button (X)
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            ),
          ),

          // Center Round info
          Column(
            children: [
              Text(
                room.config.maxRounds != null
                    ? 'Round ${room.currentRound} / ${room.config.maxRounds}'
                    : 'Round ${room.currentRound}',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Find the bridge word',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mist,
                ),
              ),
            ],
          ),

          // Chat button with red badge
          InkWell(
            onTap: () {
              ChatRoomView.open(
                context,
                roomCode: game.roomCode,
                opponentName: game.opponentName,
                room: room,
              );
            },
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 20),
                ),
                if (unread > 0)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppTheme.coral,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Word sticker pair & Dotted bridge matching Screenshot 2
class _PromptSection extends StatelessWidget {
  const _PromptSection({required this.game, required this.localIsP1});

  final GameController game;
  final bool localIsP1;

  @override
  Widget build(BuildContext context) {
    final anchor = game.anchorRound;
    final config = game.room?.config;

    if (anchor == null) {
      if (config != null && config.hasCustomStart) {
        return AnchorPair(
          leftWord: config.startWordA!,
          rightWord: config.startWordB!,
          leftIsPlayerOne: true,
        );
      }

      final isThemed = config != null && config.hasTheme;

      return CustomPaint(
        painter: _DottedBoxPainter(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          child: Column(
            children: [
              Text(
                isThemed ? 'Category: ${config.theme}' : 'Name anything',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isThemed
                    ? 'Name something in ${config.theme}. Round 2 starts from wherever you both land.'
                    : 'Round one sets the starting pair. Neither of you sees the other word until you have both committed.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mist,
                  height: 1.4,
                ),
              ),
            ],
          ),
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

/// Composer or Waiting/Locked state
class _TurnSection extends StatelessWidget {
  const _TurnSection({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    if (game.stage == ViewStage.waitingForPlayers) {
      return const _WaitingForOpponentToJoin();
    }
    if (game.stage == ViewStage.waitingForOpponent) {
      return _LockedState(game: game);
    }

    return WordComposer(
      enabled: true,
      isSubmitting: game.isSubmitting,
      onSubmit: game.submitWord,
    );
  }
}

class _WaitingForOpponentToJoin extends StatelessWidget {
  const _WaitingForOpponentToJoin();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.lime,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Your opponent left the room. Waiting for them to come back.',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                height: 1.4,
                color: AppTheme.mist,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Locked in state matching Screenshot 2 and react_app
class _LockedState extends StatefulWidget {
  const _LockedState({required this.game});

  final GameController game;

  @override
  State<_LockedState> createState() => _LockedStateState();
}

class _LockedStateState extends State<_LockedState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Disabled input showing locked state
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Text(
                'You are locked in',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mist.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              const Icon(Icons.lock_rounded, size: 16, color: AppTheme.mist),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Waiting for partner card with 3 waiting dots and Nudge CTA
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final t = (_controller.value - (i * 0.2)) % 1.0;
                          final alpha = 0.25 + (0.75 * (1.0 - (t - 0.5).abs() * 2).clamp(0.0, 1.0));
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppTheme.mist.withValues(alpha: alpha),
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Waiting for ${game.opponentName} to lock in…',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mist,
                    ),
                  ),
                ],
              ),
              if (game.canNudge) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    game.sendNudge();
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.notifications_active_rounded, size: 14, color: AppTheme.mist),
                        const SizedBox(width: 6),
                        Text(
                          'NUDGE',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (game.isNudgeCooldown) ...[
                const SizedBox(height: 12),
                Text(
                  'Nudged ${game.opponentName}',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.mist.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DottedBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(24),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      const dashLength = 8.0;
      const dashSpace = 6.0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        canvas.drawPath(
          metric.extractPath(distance, next > metric.length ? metric.length : next),
          paint,
        );
        distance += dashLength + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

