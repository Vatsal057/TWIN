import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/word_utils.dart';
import '../../models/room.dart';
import '../../services/deep_link_service.dart';
import '../../state/app_session.dart';
import '../../state/game_controller.dart';
import '../app_theme.dart';
import '../room_launcher.dart';
import '../widgets/character_avatar.dart';
import '../widgets/convergence_hero.dart';
import '../widgets/reference_word_sticker.dart';
import '../widgets/round_history.dart';
import '../widgets/victory_card.dart';

/// Victory / Game Over view matching the unified dark aesthetic:
/// - ConvergenceHero animated dual-arc dial
/// - Both character avatars with '&'
/// - Word stickers from final round
/// - Rematch acceptance banner when requested by opponent
/// - Rematch / Join Rematch CTA
/// - 9:16 Story Victory Card export
/// - Text recap share
/// - Back to games button
class ResultView extends StatelessWidget {
  const ResultView({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final room = game.room;
    if (room == null) return const SizedBox.shrink();

    final converged = room.converged;
    final abandoned = room.finishReason == FinishReason.abandoned;
    final lastRound = room.lastRound;
    final roundsCount = room.rounds.length;

    return Scaffold(
      backgroundColor: AppTheme.navy950,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated resonance dial, orbits, and score
                ConvergenceHero(
                  converged: converged,
                  abandoned: abandoned,
                  word: converged ? lastRound?.p1Word : null,
                  rounds: roundsCount,
                ),

                // Rematch request banner from opponent
                if (room.rematchRoomCode case final rematchCode?) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.lime.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppTheme.lime.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.replay_rounded,
                          color: AppTheme.lime,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${game.opponentName} wants a rematch!',
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            RoomLauncher.joinAndOpen(
                              context,
                              context.read<AppSession>(),
                              rematchCode,
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.lime,
                            foregroundColor: AppTheme.navy950,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Accept',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Avatars row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CharacterAvatar(
                      name: game.localName,
                      size: 52,
                      avatarId: context.read<AppSession>().profileAvatarId,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        '&',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.lime,
                        ),
                      ),
                    ),
                    CharacterAvatar(
                      name: game.opponentName,
                      size: 52,
                      avatarId: room.avatarOf(game.opponentId),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Final round stickers
                if (lastRound != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -4),
                        child: WordSticker(
                          word: titleCaseWord(lastRound.p1Word),
                          tone: WordTone.lime,
                          rotate: -7,
                          isLarge: false,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: DottedChainBridge(scale: 0.55),
                      ),
                      Transform.translate(
                        offset: const Offset(0, 14),
                        child: WordSticker(
                          word: titleCaseWord(lastRound.p2Word),
                          tone: converged ? WordTone.lime : WordTone.coral,
                          rotate: 7,
                          isLarge: false,
                        ),
                      ),
                    ],
                  ),

                // Full progression of all rounds played
                if (room.rounds.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history_rounded, size: 16, color: AppTheme.lime),
                            const SizedBox(width: 8),
                            Text(
                              'Every round',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${room.rounds.length} ${room.rounds.length == 1 ? "round" : "rounds"}',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.mist,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        RoundHistory(
                          rounds: room.rounds,
                          p1Id: room.p1Id,
                          localPlayerId: game.localPlayerId,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Rematch CTA
                if (room.rematchRoomCode case final rematchCode?)
                  FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).pop();
                      RoomLauncher.joinAndOpen(
                        context,
                        context.read<AppSession>(),
                        rematchCode,
                      );
                    },
                    icon: const Icon(Icons.replay_rounded),
                    label: Text(
                      'Join rematch $rematchCode',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.lime,
                      foregroundColor: AppTheme.navy950,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final fresh = await game.startRematch();
                      if (fresh == null || !context.mounted) return;
                      Navigator.of(context).pop();
                      RoomLauncher.open(context, fresh.code);
                    },
                    icon: const Icon(Icons.replay_rounded),
                    label: Text(
                      'Rematch',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.lime,
                      foregroundColor: AppTheme.navy950,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Share Victory Card (9:16 export)
                FilledButton.tonalIcon(
                  onPressed: () => VictoryCardSheet.show(
                    context,
                    room: room,
                    localName: game.localName,
                    opponentName: game.opponentName,
                    localIsP1: game.localPlayerId == room.p1Id,
                  ),
                  icon: const Icon(
                    Icons.photo_camera_back_outlined,
                    size: 20,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Share Victory Card',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.navy900,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Share text recap
                OutlinedButton.icon(
                  onPressed: () => _shareResult(game, room),
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: AppTheme.mist,
                  ),
                  label: Text(
                    'Share text recap',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mist,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Back to games button
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(
                    'Back to games',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mist,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _shareResult(GameController game, Room room) {
    final last = room.lastRound;
    final buffer = StringBuffer('TWIN\n');

    if (room.converged && last != null) {
      buffer.writeln(
        '${game.localName} and ${game.opponentName} twinned on "${titleCaseWord(last.p1Word).toUpperCase()}"!',
      );
      buffer.writeln(
        'Twinned in ${room.rounds.length} ${room.rounds.length == 1 ? "round" : "rounds"}.',
      );
    } else {
      buffer.writeln(
        '${game.localName} and ${game.opponentName} played '
        '${room.rounds.length} rounds without twinning.',
      );
    }
    buffer.writeln();

    for (final round in room.rounds) {
      if (round.matched) {
        buffer.writeln('${round.index}. ${titleCaseWord(round.p1Word)} [TWIN]');
      } else {
        buffer.writeln(
          '${round.index}. ${titleCaseWord(round.p1Word)} · ${titleCaseWord(round.p2Word)}',
        );
      }
    }

    buffer.writeln();
    buffer.writeln('Think you can twin faster?');
    buffer.write('Play: https://${DeepLinkService.webHost}');

    return SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: room.converged ? 'We twinned on TWIN!' : 'Play TWIN with me',
      ),
    );
  }
}
