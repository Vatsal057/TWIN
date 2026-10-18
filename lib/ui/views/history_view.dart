import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/friend.dart';
import '../../models/room.dart';
import '../../services/stats_service.dart';
import '../../state/app_session.dart';
import '../app_theme.dart';
import '../layout.dart';
import '../room_launcher.dart';
import '../widgets/character_avatar.dart';
import '../widgets/create_room_sheet.dart';
import '../widgets/duo_chemistry_sheet.dart';
import '../widgets/lifetime_stats_sheet.dart';

/// Full-screen History Tab matching react_app:
/// - 2x2 Lifetime Stats Grid
/// - Friends section with avatar, game counts & best scores
/// - Past games section with match results
class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy950,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'History',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: PageShell(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: const [
              _YourGamesSection(),
              SizedBox(height: 28),
              _StatsSection(),
              SizedBox(height: 28),
              _FriendsSection(),
              SizedBox(height: 28),
              _PastGamesSection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 2x2 lifetime stats grid, driven by [StatsService].
class _StatsSection extends StatelessWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StatsService.instance,
      builder: (context, _) {
        return FutureBuilder<LifetimeStats>(
          future: StatsService.instance.getStats(),
          initialData: StatsService.instance.cached,
          builder: (context, snapshot) {
            final stats = snapshot.data ?? StatsService.instance.cached;
            final bestRounds = stats?.fastestConvergenceRounds?.toString() ?? '—';
            final gamesCount = '${stats?.totalGamesPlayed ?? 0}';
            final twinnedCount = '${stats?.totalGamesTwinned ?? 0}';
            final avgRounds = stats != null && stats.totalGamesPlayed > 0
                ? stats.averageRounds.toStringAsFixed(1)
                : '—';

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => LifetimeStatsSheet.show(context),
                borderRadius: BorderRadius.circular(26),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            color: AppTheme.lime,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'LIFETIME STATS',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: AppTheme.mist,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'DETAILS',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: AppTheme.lime,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: AppTheme.lime,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              value: bestRounds,
                              valueColor: AppTheme.lime,
                              label: 'BEST ROUNDS',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              value: gamesCount,
                              valueColor: Colors.white,
                              label: 'GAMES PLAYED',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              value: twinnedCount,
                              valueColor: AppTheme.coral,
                              label: 'TWINNED',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              value: avgRounds,
                              valueColor: Colors.white,
                              label: 'AVG ROUNDS',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Friends list with Duo Chemistry counts, from the backend.
class _FriendsSection extends StatelessWidget {
  const _FriendsSection();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.people_alt_rounded, color: AppTheme.lime, size: 18),
            const SizedBox(width: 8),
            Text(
              'Friends',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Friend>>(
          stream: session.friends,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const SizedBox(
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final friends = snapshot.data ?? const <Friend>[];
            if (friends.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Text(
                  'No friends yet — finish a game and the pairing is remembered.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mist,
                  ),
                ),
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: [
                    for (var i = 0; i < friends.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      _FriendHistoryRow(
                        friend: friends[i],
                        subtitle: _friendSubtitle(friends[i]),
                        onTap: () => DuoChemistrySheet.show(
                          context,
                          friend: friends[i],
                          session: session,
                        ),
                        onLongPress: () => _confirmForget(
                          context,
                          session,
                          friends[i],
                        ),
                        onPlay: () async {
                          final config = await CreateRoomSheet.show(context);
                          if (config == null || !context.mounted) return;
                          RoomLauncher.inviteFriendAndOpen(
                            context,
                            session,
                            friends[i].id,
                            config: config,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  static String _friendSubtitle(Friend friend) {
    final games = '${friend.gamesPlayed} ${friend.gamesPlayed == 1 ? 'game' : 'games'}';
    if (friend.bestSyncRounds == null) return games;
    final rounds = '${friend.bestSyncRounds} ${friend.bestSyncRounds == 1 ? 'round' : 'rounds'}';
    return '$games · best $rounds';
  }

  void _confirmForget(BuildContext context, AppSession session, Friend friend) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.navy900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: Text(
          'Remove ${friend.name}?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: Text(
          'You will need a room code to play together again.',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AppTheme.mist,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppTheme.mist),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.coral,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              session.backend.forgetFriend(friend.id);
              Navigator.of(dialogContext).pop();
            },
            child: Text(
              'Remove',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Active games, moved here from the Play tab: tap one to jump back in.
class _YourGamesSection extends StatelessWidget {
  const _YourGamesSection();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.sports_esports_rounded,
              color: AppTheme.lime,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Your games',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Room>>(
          stream: session.myRooms,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const SizedBox(
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final active = (snapshot.data ?? const <Room>[])
                .where((r) => r.status != RoomStatus.finished)
                .toList();
            if (active.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Text(
                  'No active games. Start one from the Play tab.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mist,
                  ),
                ),
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: [
                    for (var i = 0; i < active.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      _PastGameRow(
                        name: _PastGamesSection._opponentName(
                          active[i],
                          session.localPlayerId,
                        ),
                        avatarId: active[i].avatarOf(
                          active[i].opponentOf(session.localPlayerId),
                        ),
                        result: _statusFor(active[i], session.localPlayerId),
                        converged: _isYourTurn(active[i], session.localPlayerId),
                        date: '',
                        onTap: () => RoomLauncher.open(context, active[i].code),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  static bool _isYourTurn(Room room, String localId) {
    final hasOpponent = room.players.any((p) => p != localId);
    return hasOpponent && !room.hasSubmitted(localId);
  }

  static String _statusFor(Room room, String localId) {
    final opponentId = room.players.firstWhere(
      (p) => p != localId,
      orElse: () => '',
    );
    if (opponentId.isEmpty) return 'Waiting for a friend to join';
    final name = room.playerNames[opponentId] ?? 'Player';
    if (room.hasSubmitted(localId)) {
      return 'Round ${room.currentRound} · Waiting for $name';
    }
    return 'Round ${room.currentRound} · Your turn';
  }
}

/// Finished games, newest first, from the live rooms feed.
class _PastGamesSection extends StatelessWidget {
  const _PastGamesSection();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded, color: AppTheme.lime, size: 18),
            const SizedBox(width: 8),
            Text(
              'Past games',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Room>>(
          stream: session.myRooms,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('session.myRooms stream error: ${snapshot.error}');
            }
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const SizedBox(
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final finished = (snapshot.data ?? const <Room>[])
                .where((r) => r.status == RoomStatus.finished)
                .toList();
            if (finished.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Text(
                  'No finished games yet.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mist,
                  ),
                ),
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: [
                    for (var i = 0; i < finished.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      _PastGameRow(
                        name: _opponentName(finished[i], session.localPlayerId),
                        avatarId: finished[i].avatarOf(
                          finished[i].opponentOf(session.localPlayerId),
                        ),
                        result: finished[i].finishReason == FinishReason.converged
                            ? 'matched in ${pluralRounds(finished[i].rounds.length)}'
                            : 'no match in ${pluralRounds(finished[i].rounds.length)}',
                        converged:
                            finished[i].finishReason == FinishReason.converged,
                        date: _relativeDay(finished[i].updatedAt),
                        onTap: () =>
                            RoomLauncher.open(context, finished[i].code),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  static String _opponentName(Room room, String localId) {
    final opponentId = room.players.firstWhere(
      (p) => p != localId,
      orElse: () => '',
    );
    if (opponentId.isEmpty) return 'Practice partner';
    return room.playerNames[opponentId] ?? 'Player';
  }

  static String _relativeDay(DateTime? when) {
    if (when == null) return '';
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(when.year, when.month, when.day))
        .inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '${days}d ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[when.month - 1]} ${when.day}';
  }
}

String pluralRounds(int n) => '$n ${n == 1 ? 'round' : 'rounds'}';

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.valueColor,
    required this.label,
  });

  final String value;
  final Color valueColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppTheme.mist,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendHistoryRow extends StatelessWidget {
  const _FriendHistoryRow({
    required this.friend,
    required this.subtitle,
    required this.onTap,
    required this.onLongPress,
    required this.onPlay,
  });

  final Friend friend;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CharacterAvatar(name: friend.name, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.mist,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.play_arrow_rounded,
                color: AppTheme.lime,
                size: 24,
              ),
              tooltip: 'Play with ${friend.name}',
              onPressed: onPlay,
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.mist,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _PastGameRow extends StatelessWidget {
  const _PastGameRow({
    required this.name,
    required this.result,
    required this.converged,
    required this.date,
    required this.onTap,
    this.avatarId,
  });

  final String name;
  final String result;
  final bool converged;
  final String date;
  final VoidCallback onTap;
  final String? avatarId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CharacterAvatar(name: name, size: 44, avatarId: avatarId),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: converged ? FontWeight.w700 : FontWeight.w500,
                      color: converged ? AppTheme.lime : AppTheme.mist,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              date,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.mist,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.mist,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
