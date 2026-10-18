import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/friend.dart';
import '../../models/room.dart';
import '../../state/app_session.dart';
import '../app_theme.dart';
import '../layout.dart';
import '../room_launcher.dart';
import '../widgets/character_avatar.dart';
import '../widgets/duo_chemistry_sheet.dart';

/// Full-screen History Tab:
/// - Active games, shown only while at least one game is live
/// - Friends as a slim avatar row (tap for Duo Chemistry, long-press to
///   forget the pairing)
/// - Past games in their own scrollable box
///
/// Lifetime stats are not here anymore: they live on the Play tab, whose
/// stats strip opens the same Lifetime Stats sheet.
class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();

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
          child: StreamBuilder<List<Room>>(
            stream: session.myRooms,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('session.myRooms stream error: ${snapshot.error}');
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final rooms = snapshot.data ?? const <Room>[];
              if (rooms.isEmpty) {
                return _EmptyOrFriends(session: session);
              }
              final active = rooms
                  .where((r) => r.status != RoomStatus.finished)
                  .toList();
              final finished = rooms
                  .where((r) => r.status == RoomStatus.finished)
                  .toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  if (active.isNotEmpty) ...[
                    _ActiveGamesSection(rooms: active),
                    const SizedBox(height: 28),
                  ],
                  const _FriendsSection(),
                  const SizedBox(height: 28),
                  _PastGamesSection(rooms: finished),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Shown when the player has no rooms at all: the whole-tab empty state,
/// unless friends exist without rooms, in which case just the Friends
/// section shows.
class _EmptyOrFriends extends StatelessWidget {
  const _EmptyOrFriends({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Friend>>(
      stream: session.friends,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final friends = snapshot.data ?? const <Friend>[];
        if (friends.isEmpty) {
          return const _WholeTabEmpty();
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: const [_FriendsSection()],
        );
      },
    );
  }
}

class _WholeTabEmpty extends StatelessWidget {
  const _WholeTabEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: const Icon(
                Icons.sports_esports_rounded,
                color: AppTheme.lime,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No games yet',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Games you play show up here. Start one from the Play tab.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.mist,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Games still in progress: tap one to jump back in. The section only
/// exists while at least one game is live; with none it disappears
/// completely instead of showing an empty box.
class _ActiveGamesSection extends StatelessWidget {
  const _ActiveGamesSection({required this.rooms});

  final List<Room> rooms;

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
              'Active games',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: [
                for (var i = 0; i < rooms.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  _PastGameRow(
                    name: _opponentName(rooms[i], session.localPlayerId),
                    avatarId: rooms[i].avatarOf(
                      rooms[i].opponentOf(session.localPlayerId),
                    ),
                    result: _statusFor(rooms[i], session.localPlayerId),
                    converged: _isYourTurn(rooms[i], session.localPlayerId),
                    date: '',
                    onTap: () => RoomLauncher.open(context, rooms[i].code),
                  ),
                ],
              ],
            ),
          ),
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

/// Friends as a slim horizontal row of faces. Tap opens Duo Chemistry;
/// long-press offers to forget the pairing.
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
            return SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: friends.length,
                separatorBuilder: (_, __) => const SizedBox(width: 18),
                itemBuilder: (context, i) {
                  final friend = friends[i];
                  return InkWell(
                    onTap: () => DuoChemistrySheet.show(
                      context,
                      friend: friend,
                      session: session,
                    ),
                    onLongPress: () => _confirmForget(context, session, friend),
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 68,
                      child: Column(
                        children: [
                          CharacterAvatar(name: friend.name, size: 56),
                          const SizedBox(height: 8),
                          Text(
                            friend.name.split(' ').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
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
            onPressed: () async {
              try {
                await session.backend.forgetFriend(friend.id);
              } catch (e) {
                debugPrint('forgetFriend failed: $e');
              }
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
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

/// Finished games, newest first, in a box that scrolls on its own so the
/// tab itself stays one fixed screen.
class _PastGamesSection extends StatelessWidget {
  const _PastGamesSection({required this.rooms});

  final List<Room> rooms;

  @override
  Widget build(BuildContext context) {
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
        if (rooms.isEmpty)
          Container(
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
          )
        else
          _ScrollablePastGames(rooms: rooms),
      ],
    );
  }
}

class _ScrollablePastGames extends StatefulWidget {
  const _ScrollablePastGames({required this.rooms});

  final List<Room> rooms;

  @override
  State<_ScrollablePastGames> createState() => _ScrollablePastGamesState();
}

class _ScrollablePastGamesState extends State<_ScrollablePastGames> {
  final _scrollController = ScrollController();

  /// One row is 72 high (44 avatar + 14 top/bottom padding); the box shows
  /// about four and a half rows before it starts scrolling.
  static const double _rowExtent = 73;
  static const double _maxHeight = _rowExtent * 4.5;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final rooms = widget.rooms;
    final contentHeight = rooms.length * _rowExtent;
    final scrollable = contentHeight > _maxHeight;
    final height = scrollable ? _maxHeight : contentHeight;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Scrollbar(
                controller: _scrollController,
                thumbVisibility: scrollable,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  itemCount: rooms.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                  itemBuilder: (context, i) => _PastGameRow(
                    name: _opponentName(rooms[i], session.localPlayerId),
                    avatarId: rooms[i].avatarOf(
                      rooms[i].opponentOf(session.localPlayerId),
                    ),
                    result: rooms[i].finishReason == FinishReason.converged
                        ? 'matched in ${pluralRounds(rooms[i].rounds.length)}'
                        : 'no match in ${pluralRounds(rooms[i].rounds.length)}',
                    converged:
                        rooms[i].finishReason == FinishReason.converged,
                    date: _relativeDay(rooms[i].updatedAt),
                    onTap: () => RoomLauncher.open(context, rooms[i].code),
                  ),
                ),
              ),
              if (scrollable)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 36,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.navy950.withValues(alpha: 0),
                            AppTheme.navy950.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
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

String _opponentName(Room room, String localId) {
  final opponentId = room.players.firstWhere(
    (p) => p != localId,
    orElse: () => '',
  );
  if (opponentId.isEmpty) return 'Practice partner';
  return room.playerNames[opponentId] ?? 'Player';
}

String _relativeDay(DateTime? when) {
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

String pluralRounds(int n) => '$n ${n == 1 ? 'round' : 'rounds'}';

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
