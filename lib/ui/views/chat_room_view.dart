import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/word_utils.dart';
import '../../models/chat_message.dart';
import '../../models/room.dart';
import '../../services/backend/game_backend.dart';
import '../../services/deep_link_service.dart';
import '../../services/sound_service.dart';
import '../../state/app_session.dart';
import '../../state/chat_controller.dart';
import '../../state/unread_tracker.dart';
import '../room_launcher.dart';
import '../widgets/character_avatar.dart';

const _quickReplies = ['🔥', '😂', 'Hint?'];

/// Dedicated Full-Screen Chat View matching reference Screenshot 3:
/// - Top bar with Back button, Avatar, Partner Name, "Online", Options button (...)
/// - System banner pill for game outcomes (e.g. Gamepad icon, "Round 2: OASIS vs CAMEL — no match")
/// - Vibrant Lime user bubbles with double-check status
/// - Frosted Navy partner bubbles
/// - Quick reaction chips row (🔥, 😂, Hint?)
/// - Rounded capsule message input with circular send button
class ChatRoomView extends StatefulWidget {
  const ChatRoomView({
    super.key,
    required this.roomCode,
    required this.opponentId,
    required this.opponentName,
    this.room,
    this.initialDraft,
    this.insideRoom = false,
  });

  /// The room this chat was opened from. Used for the game actions in the
  /// options sheet (join, share invite); the messages themselves belong
  /// to the pair conversation with [opponentId], not to this room.
  final String roomCode;
  final String opponentId;
  final String opponentName;
  final Room? room;

  /// Text waiting in the composer when the chat opens, ready to send.
  /// The lobby uses it to drop a room invite into a friend's chat.
  final String? initialDraft;

  /// True when this chat was opened from inside the room's own pages
  /// (the game, the lobby), so the game banner's tap pops back to the
  /// game instead of opening the room afresh.
  final bool insideRoom;

  static Future<void> open(
    BuildContext context, {
    required String roomCode,
    required String opponentId,
    required String opponentName,
    Room? room,
    String? initialDraft,
    bool insideRoom = false,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomView(
          roomCode: roomCode,
          opponentId: opponentId,
          opponentName: opponentName,
          room: room,
          initialDraft: initialDraft,
          insideRoom: insideRoom,
        ),
      ),
    );
  }

  @override
  State<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<ChatRoomView> {
  late final ChatController _chat;
  late final String _conversationId;
  late final UnreadTracker _unread;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  int _lastMessageCount = 0;
  bool _scrollQueued = false;
  bool? _finishedWhenOpened;
  bool _wasMyTurn = false;

  @override
  void initState() {
    super.initState();
    final session = context.read<AppSession>();
    _conversationId = pairConversationId(
      session.localPlayerId,
      widget.opponentId,
    );
    _chat = ChatController(
      backend: session.backend,
      conversationId: _conversationId,
    )..start();
    _unread = session.unread;
    _unread.setChatOpen(_conversationId, true);
    final draft = widget.initialDraft;
    if (draft != null && draft.isNotEmpty) {
      _textController.text = draft;
    }
  }

  @override
  void dispose() {
    _unread.setChatOpen(_conversationId, false);
    _chat.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage([String? customText]) {
    final text = (customText ?? _textController.text).trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _chat.send(text);
    SoundService.instance.send();
    if (customText == null) {
      _textController.clear();
    }
    // Keep the cursor in the field, ready for the next message. On
    // web the tap on the send button blurs the field on its own.
    _focusNode.requestFocus();
  }

  /// Keeps the newest message in view. The first batch of messages
  /// lands at the bottom instantly; later arrivals scroll down
  /// gently, but only when the new message is the reader's own or
  /// they are already near the bottom, so someone reading history
  /// is never yanked away from it.
  void _followMessages(List<ChatMessage> messages) {
    final count = messages.length;
    if (count == _lastMessageCount) return;
    final firstLoad = _lastMessageCount == 0;
    _lastMessageCount = count;
    if (_scrollQueued || count == 0) return;
    final mine = messages.last.senderId == _chat.localPlayerId;
    if (!firstLoad && !mine) SoundService.instance.receive();
    final nearBottom =
        !_scrollController.hasClients ||
        _scrollController.position.maxScrollExtent -
                _scrollController.offset <=
            160;
    if (!firstLoad && !mine && !nearBottom) return;
    _scrollQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollQueued = false;
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (firstLoad) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// The game banner: while the player is in here chatting, the game
  /// goes on without them. This watches the room live and speaks up
  /// at the top of the chat when the opponent has locked in and is
  /// waiting on them, or when the game ends while they are here.
  /// Tapping it goes back to the game.
  Widget _gameBanner(AppSession session) {
    return StreamBuilder<Room>(
      stream: session.backend.watchRoom(widget.roomCode),
      builder: (context, snap) {
        final live = snap.data;
        if (live == null) return const SizedBox.shrink();
        _finishedWhenOpened ??= live.isFinished;
        final myTurn =
            live.isFull &&
            !live.isFinished &&
            live.hasSubmitted(widget.opponentId) &&
            !live.hasSubmitted(session.localPlayerId);
        if (myTurn && !_wasMyTurn) {
          _wasMyTurn = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              HapticFeedback.mediumImpact();
              SoundService.instance.partnerDing();
            }
          });
        } else if (!myTurn) {
          _wasMyTurn = false;
        }
        final ended = live.isFinished && _finishedWhenOpened == false;
        if (!myTurn && !ended) return const SizedBox.shrink();
        return InkWell(
          onTap: () {
            if (widget.insideRoom) {
              Navigator.of(context).maybePop();
            } else {
              RoomLauncher.open(context, widget.roomCode);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: session.palette.accent.withValues(alpha: 0.14),
              border: Border(
                bottom: BorderSide(
                  color: session.palette.accent.withValues(alpha: 0.35),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, color: session.palette.accentInk, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    myTurn
                        ? '${widget.opponentName} locked in. Your turn.'
                        : 'This game just ended. See the result.',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: session.palette.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: session.palette.accentInk,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Sends a rematch request into this chat. The rematch room itself is
  /// created up front (same settings as the finished game) and its code
  /// rides along on the request card; nothing starts until the other
  /// player accepts on their side. Declining also lands in the thread,
  /// so both players see the same state on the card.
  Future<void> _requestRematch(BuildContext context, AppSession session) async {
    final messenger = ScaffoldMessenger.of(context);
    Room room;
    try {
      room = await session.backend
          .watchRoom(widget.roomCode)
          .first
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      SoundService.instance.error();
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not load that game.')),
      );
      return;
    }
    if (!room.isFinished) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('This game is still on. Rematch unlocks when it ends.'),
        ),
      );
      return;
    }

    var code = room.rematchRoomCode;
    if (code == null) {
      try {
        final fresh = await session.backend.startRematch(room);
        code = fresh.code;
      } catch (_) {
        SoundService.instance.error();
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not start the rematch.')),
        );
        return;
      }
    } else {
      final alreadyAsked = _chat.messages.any(
        (m) => m.kind == ChatMessage.kindRematch && m.roomCode == code,
      );
      final wasDeclined = _chat.messages.any(
        (m) => m.kind == ChatMessage.kindRematchDeclined && m.roomCode == code,
      );
      if (alreadyAsked && !wasDeclined) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Request already sent. Waiting for ${widget.opponentName}.'),
          ),
        );
        return;
      }
    }

    await _chat.send(
      'Rematch request',
      kind: ChatMessage.kindRematch,
      roomCode: code,
    );
    SoundService.instance.send();
    messenger.showSnackBar(
      SnackBar(content: Text('Rematch request sent to ${widget.opponentName}.')),
    );
  }

  void _showOptionsSheet(BuildContext context, AppSession session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: session.palette.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: session.palette.text.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.opponentName,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: session.palette.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: session.palette.surface,
                  foregroundColor: session.palette.text,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () {
                  Navigator.of(bottomSheetContext).pop();
                  RoomLauncher.joinAndOpen(context, session, widget.roomCode);
                },
                child: const Text('View game', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: session.palette.accent,
                  foregroundColor: session.palette.onAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () async {
                  Navigator.of(bottomSheetContext).pop();
                  await _requestRematch(context, session);
                },
                child: const Text('Request a rematch', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: session.palette.text,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: session.palette.text.withValues(alpha: 0.15)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () {
                  Navigator.of(bottomSheetContext).pop();
                  final link = DeepLinkService.webJoinUri(widget.roomCode).toString();
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite link copied')),
                  );
                },
                child: const Text('Copy invite link', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();

    return ChangeNotifierProvider<ChatController>.value(
      value: _chat,
      child: Consumer<ChatController>(
        builder: (context, chat, _) {
          final messages = chat.messages;
          _followMessages(messages);
          final declinedRematchCodes = <String>{
            for (final m in messages)
              if (m.kind == ChatMessage.kindRematchDeclined && m.roomCode != null)
                m.roomCode!,
          };

          return Scaffold(
            backgroundColor: session.palette.bg,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: session.palette.text.withValues(alpha: 0.03),
              elevation: 0,
              titleSpacing: 16,
              title: Row(
                children: [
                  // Circular frosted back button
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: session.palette.text.withValues(alpha: 0.08),
                        border: Border.all(color: session.palette.text.withValues(alpha: 0.12)),
                      ),
                      child: Icon(Icons.chevron_left_rounded, color: session.palette.text, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Partner avatar: her current face, live from her
                  // profile, so a change shows here the moment she
                  // saves it. The room's copy is the fallback while the
                  // profile loads (and for rooms from before profiles).
                  StreamBuilder<String?>(
                    stream: session.backend.watchAvatarId(widget.opponentId),
                    builder: (context, avatarSnap) => CharacterAvatar(
                      name: widget.opponentName,
                      size: 42,
                      status: 'online',
                      avatarId:
                          avatarSnap.data ??
                          widget.room?.avatarOf(
                            widget.room?.opponentOf(session.localPlayerId),
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Partner Name & Online status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.opponentName,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: session.palette.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                // Circular frosted options button (...)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: InkWell(
                    onTap: () => _showOptionsSheet(context, session),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: session.palette.text.withValues(alpha: 0.08),
                        border: Border.all(color: session.palette.text.withValues(alpha: 0.12)),
                      ),
                      child: Icon(Icons.more_horiz_rounded, color: session.palette.muted, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  _gameBanner(session),

                  // Message feed
                  Expanded(
                    child: messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Say something. Messages stay between you two.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: session.palette.muted,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              if (msg.kind == ChatMessage.kindRematchDeclined) {
                                return const SizedBox.shrink();
                              }
                              if (msg.kind == ChatMessage.kindRematch &&
                                  msg.roomCode != null) {
                                return _RematchCard(
                                  code: msg.roomCode!,
                                  isMine: msg.senderId == chat.localPlayerId,
                                  opponentName: widget.opponentName,
                                  declined:
                                      declinedRematchCodes.contains(msg.roomCode),
                                  session: session,
                                  onDecline: () => _chat.send(
                                    'Rematch declined',
                                    kind: ChatMessage.kindRematchDeclined,
                                    roomCode: msg.roomCode,
                                  ),
                                );
                              }
                              if (msg.system) {
                                return _SystemBanner(message: msg);
                              }
                              final isMine = msg.senderId == chat.localPlayerId;
                              return _ChatBubble(message: msg, isMine: isMine);
                            },
                          ),
                  ),

                  // Quick reaction chips bar
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _quickReplies.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final chip = _quickReplies[i];
                        return InkWell(
                          onTap: () => _sendMessage(chip),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            decoration: BoxDecoration(
                              color: session.palette.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: session.palette.border),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              chip,
                              style: GoogleFonts.outfit(
                                fontSize: chip.contains('?') ? 15 : 22,
                                fontWeight: FontWeight.w700,
                                color: session.palette.text,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Capsule message input
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: session.palette.text.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(color: session.palette.border),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _sendMessage(),
                              textInputAction: TextInputAction.send,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                color: session.palette.text,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Message ${widget.opponentName}',
                                // Off, or the theme's navy800 fill paints a
                                // square rectangle inside this capsule.
                                filled: false,
                                hintStyle: GoogleFonts.outfit(
                                  fontSize: 15,
                                  color: session.palette.muted.withValues(alpha: 0.7),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _textController,
                            builder: (context, value, _) {
                              final hasText = value.text.trim().isNotEmpty;
                              return InkWell(
                                onTap: hasText ? () => _sendMessage() : null,
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: hasText ? session.palette.accent : session.palette.muted.withValues(alpha: 0.45),
                                  ),
                                  child: Icon(
                                    Icons.send_rounded,
                                    size: 19,
                                    color: hasText ? session.palette.onAccent : session.palette.text,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// System game event banner pill matching Screenshot 3:
/// Gamepad icon + "Round 2: OASIS vs CAMEL — no match"
class _SystemBanner extends StatelessWidget {
  const _SystemBanner({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppSession>().palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            Icon(Icons.sports_esports_rounded, color: p.text, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(fontSize: 14, color: p.text),
                  children: [
                    if (message.round != null)
                      TextSpan(
                        text: 'Round ${message.round}: ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    if (message.wordA != null)
                      TextSpan(
                        text: '${titleCaseWord(message.wordA!)} ',
                        style: TextStyle(
                          color: p.accentInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    if (message.wordA != null && message.wordB != null)
                      TextSpan(
                        text: 'vs ',
                        style: TextStyle(color: p.muted),
                      ),
                    if (message.wordB != null)
                      TextSpan(
                        text: '${titleCaseWord(message.wordB!)} ',
                        style: TextStyle(
                          color: p.accent2Ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    TextSpan(
                      text: '— ${message.matched == true ? 'twin!' : 'no match'}',
                      style: TextStyle(color: p.muted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat Bubble matching Screenshot 3
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppSession>().palette;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMine ? p.accent : p.bubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMine ? 20 : 6),
                  bottomRight: Radius.circular(isMine ? 6 : 20),
                ),
              ),
              child: Text(
                message.text,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: isMine ? FontWeight.w800 : FontWeight.w600,
                  color: isMine ? p.onAccent : p.text,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.sentAt != null)
                  Text(
                    _formatTime(message.sentAt),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: p.muted,
                    ),
                  ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.done_all_rounded, size: 14, color: p.accentInk),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A rematch request inside the chat thread. Both players see the same
/// card and the same live state: waiting, declined, or both in (the
/// rematch room filled). Only the player who was asked gets the Join
/// and Not now buttons; the asker can open the room and wait there.
class _RematchCard extends StatelessWidget {
  const _RematchCard({
    required this.code,
    required this.isMine,
    required this.opponentName,
    required this.declined,
    required this.session,
    required this.onDecline,
  });

  final String code;
  final bool isMine;
  final String opponentName;
  final bool declined;
  final AppSession session;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final p = session.palette;
    return StreamBuilder<Room>(
      stream: session.backend.watchRoom(code),
      builder: (context, snap) {
        final room = snap.data;
        final bothIn = room != null && room.isFull;

        final String title;
        final String subtitle;
        if (declined) {
          title = 'Rematch declined';
          subtitle = isMine
              ? '$opponentName is not up for another game right now.'
              : 'You turned this one down.';
        } else if (bothIn) {
          title = 'Rematch is on';
          subtitle = 'You are both in room $code.';
        } else if (isMine) {
          title = 'Rematch requested';
          subtitle = 'Waiting for $opponentName to reply.';
        } else {
          title = '$opponentName wants a rematch';
          subtitle = 'A new room with the same settings as your last game.';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 22,
                  color: declined ? p.muted : p.accentInk,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 12.5, color: p.muted),
                ),
                if (!declined && bothIn) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => RoomLauncher.open(context, code),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.accent,
                      foregroundColor: p.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Open game',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ] else if (!declined && isMine) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => RoomLauncher.open(context, code),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.text,
                      side: BorderSide(color: p.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Open the room',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ] else if (!declined) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onDecline,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: p.text,
                            side: BorderSide(color: p.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Not now',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              RoomLauncher.joinAndOpen(context, session, code),
                          style: FilledButton.styleFrom(
                            backgroundColor: p.accent,
                            foregroundColor: p.onAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Join rematch',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
