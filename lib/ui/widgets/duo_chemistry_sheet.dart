import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/word_utils.dart';
import '../../models/friend.dart';
import '../../models/room.dart';
import '../../state/app_session.dart';
import '../layout.dart';
import '../room_launcher.dart';
import 'character_avatar.dart';
import 'create_room_sheet.dart';

/// Modal bottom sheet displaying Duo Chemistry stats and the shared Memory Bank
/// of twinned words between two players.
class DuoChemistrySheet extends StatelessWidget {
  const DuoChemistrySheet({
    super.key,
    required this.friend,
    required this.session,
  });

  final Friend friend;
  final AppSession session;

  static Future<void> show(
    BuildContext context, {
    required Friend friend,
    required AppSession session,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: session.palette.sheet,
      constraints: const BoxConstraints(maxWidth: Layout.contentMaxWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DuoChemistrySheet(friend: friend, session: session),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = session.palette;
    final avg = friend.averageRounds;
    final avgStr = avg != null ? avg.toStringAsFixed(1) : '—';
    final bestStr = friend.bestSyncRounds != null
        ? '${friend.bestSyncRounds} ${friend.bestSyncRounds == 1 ? "round" : "rounds"}'
        : '—';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.text.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CharacterAvatar(name: friend.name, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.name,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: p.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Duo Chemistry & Memory Bank',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: p.accentInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'BEST SYNC',
                      value: bestStr,
                      detail: friend.bestSyncWord != null
                          ? titleCaseWord(friend.bestSyncWord!)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      label: 'AVG ROUNDS',
                      value: avgStr,
                      detail: '${friend.gamesPlayed} games',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      label: 'TWINNED',
                      value: '${friend.twinnedCount}',
                      detail: 'total syncs',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'MEMORY BANK',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Words you and ${friend.name} converged on together.',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 14),
              if (friend.memoryBank.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: p.border,
                    ),
                  ),
                  child: Text(
                    'No shared memories yet.\nPlay a game to log your first sync.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      height: 1.5,
                      color: p.muted,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final word in friend.memoryBank)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: p.bg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: p.accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.all_inclusive_rounded,
                              size: 14,
                              color: p.accentInk,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              titleCaseWord(word),
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: p.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 24),
              Text(
                'PAST GAMES',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Matches you and ${friend.name} played together.',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 14),
              StreamBuilder<List<Room>>(
                stream: session.myRooms,
                builder: (context, snapshot) {
                  final games = (snapshot.data ?? const <Room>[])
                      .where((r) =>
                          r.status == RoomStatus.finished &&
                          (r.players.contains(friend.id) ||
                              r.opponentOf(session.localPlayerId) == friend.id ||
                              r.nameOf(r.opponentOf(session.localPlayerId)).toLowerCase() ==
                                  friend.name.toLowerCase()))
                      .toList();

                  if (games.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: p.border,
                        ),
                      ),
                      child: Text(
                        'No finished games with ${friend.name} yet.',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: p.muted,
                        ),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: p.bg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: p.border,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Column(
                        children: [
                          for (var i = 0; i < games.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                color: p.text.withValues(alpha: 0.07),
                              ),
                            InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                RoomLauncher.open(context, games[i].code);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: games[i].finishReason ==
                                                FinishReason.converged
                                            ? p.accent
                                                .withValues(alpha: 0.15)
                                            : p.text
                                                .withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        games[i].finishReason ==
                                                FinishReason.converged
                                            ? Icons.check_rounded
                                            : Icons.close_rounded,
                                        size: 18,
                                        color: games[i].finishReason ==
                                                FinishReason.converged
                                            ? p.accentInk
                                            : p.muted,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            games[i].finishReason ==
                                                    FinishReason.converged
                                                ? (games[i].lastRound?.p1Word !=
                                                        null
                                                    ? 'Matched on "${titleCaseWord(games[i].lastRound!.p1Word)}"'
                                                    : 'Twinned')
                                                : 'No match in ${games[i].rounds.length} rounds',
                                            style: GoogleFonts.outfit(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                              color: p.text,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${games[i].rounds.length} ${games[i].rounds.length == 1 ? "round" : "rounds"} · Room ${games[i].code}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: p.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: p.muted,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final config = await CreateRoomSheet.show(context);
                  if (config == null || !context.mounted) return;
                  RoomLauncher.inviteFriendAndOpen(
                    context,
                    session,
                    friend.id,
                    config: config,
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  'Play with ${friend.name}',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppSession>().palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: p.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: p.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: p.text,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: p.accentInk,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
