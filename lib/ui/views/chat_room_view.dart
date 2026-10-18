import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/word_utils.dart';
import '../../models/chat_message.dart';
import '../../models/room.dart';
import '../../services/deep_link_service.dart';
import '../../state/app_session.dart';
import '../../state/chat_controller.dart';
import '../app_theme.dart';
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
    required this.opponentName,
    this.room,
  });

  final String roomCode;
  final String opponentName;
  final Room? room;

  static Future<void> open(
    BuildContext context, {
    required String roomCode,
    required String opponentName,
    Room? room,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomView(
          roomCode: roomCode,
          opponentName: opponentName,
          room: room,
        ),
      ),
    );
  }

  @override
  State<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<ChatRoomView> {
  late final ChatController _chat;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final session = context.read<AppSession>();
    _chat = ChatController(
      backend: session.backend,
      roomCode: widget.roomCode,
    )..start();
  }

  @override
  void dispose() {
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
    if (customText == null) {
      _textController.clear();
    }
  }

  void _showOptionsSheet(BuildContext context, AppSession session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navy900,
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
                    color: Colors.white.withValues(alpha: 0.25),
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
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  foregroundColor: Colors.white,
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
                  backgroundColor: AppTheme.lime,
                  foregroundColor: AppTheme.navy950,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () async {
                  Navigator.of(bottomSheetContext).pop();
                  await RoomLauncher.createAndOpen(context, session);
                },
                child: const Text('Start a rematch', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
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

          return Scaffold(
            backgroundColor: AppTheme.navy950,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.white.withValues(alpha: 0.03),
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
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Partner avatar
                  CharacterAvatar(
                    name: widget.opponentName,
                    size: 42,
                    status: 'online',
                    avatarId: widget.room?.avatarOf(
                      widget.room?.opponentOf(session.localPlayerId),
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
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Online',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mist,
                          ),
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
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: const Icon(Icons.more_horiz_rounded, color: AppTheme.mist, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  // Message feed
                  Expanded(
                    child: messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Say something. Messages stay in this room.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: AppTheme.mist,
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
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              chip,
                              style: GoogleFonts.outfit(
                                fontSize: chip.contains('?') ? 15 : 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
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
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Message ${widget.opponentName}',
                                // Off, or the theme's navy800 fill paints a
                                // square rectangle inside this capsule.
                                filled: false,
                                hintStyle: GoogleFonts.outfit(
                                  fontSize: 15,
                                  color: AppTheme.mist.withValues(alpha: 0.7),
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
                                    color: hasText ? AppTheme.lime : const Color(0xFF71739F),
                                  ),
                                  child: Icon(
                                    Icons.send_rounded,
                                    size: 19,
                                    color: hasText ? const Color(0xFF151434) : Colors.white,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(fontSize: 14, color: Colors.white),
                  children: [
                    if (message.round != null)
                      TextSpan(
                        text: 'Round ${message.round}: ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    if (message.wordA != null)
                      TextSpan(
                        text: '${titleCaseWord(message.wordA!)} ',
                        style: const TextStyle(
                          color: AppTheme.lime,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    if (message.wordA != null && message.wordB != null)
                      const TextSpan(
                        text: 'vs ',
                        style: TextStyle(color: AppTheme.mist),
                      ),
                    if (message.wordB != null)
                      TextSpan(
                        text: '${titleCaseWord(message.wordB!)} ',
                        style: const TextStyle(
                          color: AppTheme.coral,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    TextSpan(
                      text: '— ${message.matched == true ? 'twin!' : 'no match'}',
                      style: const TextStyle(color: AppTheme.mist),
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
                color: isMine ? AppTheme.lime : Colors.white.withValues(alpha: 0.09),
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
                  color: isMine ? AppTheme.navy950 : Colors.white,
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
                      color: AppTheme.mist,
                    ),
                  ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all_rounded, size: 14, color: AppTheme.lime),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
