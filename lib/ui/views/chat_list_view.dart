import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/word_utils.dart';
import '../../models/chat_message.dart';
import '../../models/game_invite.dart';
import '../../models/room.dart';
import '../../services/backend/game_backend.dart';
import '../../state/app_session.dart';
import '../layout.dart';
import '../room_launcher.dart';
import '../widgets/bouncy_tap.dart';
import '../widgets/character_avatar.dart';
import 'chat_room_view.dart';

/// Full-screen Chats Tab matching react_app:
/// - Match invitations from the backend
/// - One conversation per player, fed by every game with them
/// - Live unread badge counters
/// - Tapping a conversation opens the dedicated ChatRoomView
class ChatListView extends StatelessWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();

    return StreamBuilder<List<GameInvite>>(
      stream: session.backend.watchInvites(),
      builder: (context, inviteSnap) {
        final invites = inviteSnap.data ?? const <GameInvite>[];

        return ListenableBuilder(
          listenable: session.unread,
          builder: (context, _) {
            final unreadTotal = session.unread.totalUnread;

            return Scaffold(
              backgroundColor: session.palette.bg,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: Text(
                  'Chats',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 18),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: session.palette.text.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: session.palette.text.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      unreadTotal > 0 ? '$unreadTotal unread' : 'All caught up',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: unreadTotal > 0
                            ? session.palette.accentInk
                            : session.palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
              body: SafeArea(
                child: PageShell(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    children: [
                      if (invites.isNotEmpty) ...[
                        Text(
                          'MATCH INVITATIONS',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: session.palette.muted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final inv in invites)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _InviteCard(
                              fromName: inv.fromName,
                              roomCode: inv.roomCode,
                              onAccept: () => RoomLauncher.joinAndOpen(
                                context,
                                session,
                                inv.roomCode,
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                      ],

                      Text(
                        'CONVERSATIONS',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: session.palette.muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _ConversationsList(),
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

/// One tile per active game thread, rebuilt whenever unread state changes.
class _ConversationsList extends StatelessWidget {
  const _ConversationsList();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();

    return ListenableBuilder(
      listenable: session.unread,
      builder: (context, _) {
        return StreamBuilder<List<Room>>(
          stream: session.myRooms,
          builder: (context, roomSnap) {
            final rooms = (roomSnap.data ?? const <Room>[])
                .where((r) => r.isFull)
                .toList();

            // One conversation per player: every game with the same opponent
            // feeds a single thread, finished games included, so a chat never
            // vanishes when its game ends.
            String conversationOf(Room r) {
              final opp = r.opponentOf(session.localPlayerId);
              return opp == null
                  ? ''
                  : pairConversationId(session.localPlayerId, opp);
            }

            DateTime activityOf(Room r) =>
                session.unread.lastMessageFor(conversationOf(r))?.sentAt ??
                r.updatedAt ??
                r.createdAt ??
                DateTime(0);

            final byOpponent = <String, List<Room>>{};
            for (final room in rooms) {
              final opponentId = room.players.firstWhere(
                (p) => p != session.localPlayerId,
                orElse: () => '',
              );
              if (opponentId.isEmpty) continue;
              byOpponent.putIfAbsent(opponentId, () => []).add(room);
            }

            final repRooms = <Room>[];
            final unreadByOpponent = <String, int>{};
            for (final entry in byOpponent.entries) {
              var latest = entry.value.first;
              for (final r in entry.value) {
                if (activityOf(r).isAfter(activityOf(latest))) latest = r;
              }
              repRooms.add(latest);
              unreadByOpponent[entry.key] =
                  session.unread.unreadFor(conversationOf(latest));
            }
            repRooms.sort((a, b) => activityOf(b).compareTo(activityOf(a)));

            if (repRooms.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  color: session.palette.sheet,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: session.palette.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        color: session.palette.muted, size: 26),
                    const SizedBox(height: 10),
                    Text(
                      'No chats yet',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: session.palette.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start a match and the chat opens with it.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: session.palette.muted,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                for (var i = 0; i < repRooms.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  // The face follows the friend's profile live, so an
                  // avatar change shows here at once; the room's copy
                  // is the fallback while the profile loads.
                  StreamBuilder<String?>(
                    stream:
                        repRooms[i].opponentOf(session.localPlayerId) == null
                        ? null
                        : session.backend.watchAvatarId(
                            repRooms[i].opponentOf(session.localPlayerId)!,
                          ),
                    builder: (context, avatarSnap) {
                      final room = repRooms[i];
                      final oppId = room.opponentOf(session.localPlayerId);
                      return _FriendChatTile(
                        name: _opponentName(room, session.localPlayerId),
                        avatarId: avatarSnap.data ?? room.avatarOf(oppId),
                        preview: _previewFor(session, room),
                        timestamp: _timestampFor(session, room),
                        unreadCount: unreadByOpponent[oppId] ?? 0,
                        onTap: () {
                          if (oppId == null) return;
                          session.unread.markRead(conversationOf(room));
                          ChatRoomView.open(
                            context,
                            roomCode: room.code,
                            opponentId: oppId,
                            opponentName: _opponentName(
                              room,
                              session.localPlayerId,
                            ),
                            room: room,
                          );
                        },
                      );
                    },
                  ),
                ],
              ],
            );
          },
        );
      },
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

String _conversationOf(AppSession session, Room room) {
  final opp = room.opponentOf(session.localPlayerId);
  return opp == null ? '' : pairConversationId(session.localPlayerId, opp);
}

String _previewFor(AppSession session, Room room) {
  final last = session.unread.lastMessageFor(_conversationOf(session, room));
  if (last == null) return 'No messages yet';
  if (last.system == true) {
    final a = last.wordA == null ? '' : titleCaseWord(last.wordA!);
    final b = last.wordB == null ? '' : titleCaseWord(last.wordB!);
    if (a.isEmpty && b.isEmpty) return last.text;
    return 'Round ${last.round}: $a vs $b'
        '${last.matched == true ? ' — twin!' : ' — no match'}';
  }
  final who = last.senderId == session.localPlayerId
      ? 'You'
      : _opponentName(room, session.localPlayerId);
  if (last.kind == ChatMessage.kindRematch) return '$who: wants a rematch';
  if (last.kind == ChatMessage.kindRematchDeclined) {
    return '$who: declined the rematch';
  }
  return '$who: ${last.text}';
}

String _timestampFor(AppSession session, Room room) {
  final at = session.unread.lastMessageFor(_conversationOf(session, room))?.sentAt ??
      room.updatedAt ??
      room.createdAt;
  if (at == null) return '';
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays == 1) return 'yesterday';
  return '${diff.inDays}d';
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.fromName,
    required this.roomCode,
    required this.onAccept,
  });

  final String fromName;
  final String roomCode;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppSession>().palette;
    return BouncyTap(
      onTap: onAccept,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.sheet,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            CharacterAvatar(name: fromName, size: 48, status: 'turn'),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fromName,
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Invited you to twin!',
                    style: TextStyle(
                      fontSize: 13,
                      color: p.accentInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: p.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Accept',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: p.onAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendChatTile extends StatelessWidget {
  const _FriendChatTile({
    required this.name,
    required this.preview,
    required this.unreadCount,
    required this.onTap,
    this.timestamp = '',
    this.avatarId,
  });

  final String name;
  final String preview;
  final String timestamp;
  final int unreadCount;
  final VoidCallback onTap;
  final String? avatarId;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppSession>().palette;
    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: p.sheet,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            CharacterAvatar(
              name: name,
              size: 50,
              status: 'online',
              avatarId: avatarId,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timestamp,
                        style: TextStyle(
                          fontSize: 12,
                          color: p.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: p.accent2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: p.muted,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
