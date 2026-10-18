import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/chat_message.dart';
import '../../state/chat_controller.dart';
import '../app_theme.dart';

const _quickReplies = ['🔥', '😂', 'Hint?', 'Your turn!'];

/// Redesigned ChatMessageList matching reference Screenshot 3:
/// - Rounded lime bubble for user messages
/// - Dark navy card bubble for partner messages
/// - Quick reaction chips bar at bottom
class ChatMessageList extends StatelessWidget {
  const ChatMessageList({super.key, required this.chat});

  final ChatController chat;

  @override
  Widget build(BuildContext context) {
    final messages = chat.messages;
    if (messages.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        return _Bubble(
          message: message,
          isMine: message.senderId == chat.localPlayerId,
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 270),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.lime : AppTheme.navy800,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMine ? 20 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: isMine ? FontWeight.w800 : FontWeight.w600,
                color: isMine ? AppTheme.navy950 : Colors.white,
                height: 1.3,
              ),
            ),
            if (isMine) ...[
              const SizedBox(height: 3),
              const Icon(Icons.done_all_rounded, size: 13, color: AppTheme.navy950),
            ],
          ],
        ),
      ),
    );
  }
}

/// Composer with quick reply pills and pill input
class ChatComposer extends StatefulWidget {
  const ChatComposer({super.key, required this.chat});

  final ChatController chat;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    _controller.clear();
    widget.chat.send(text);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick reaction chips row matching reference Screenshot 3
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _quickReplies.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final chip = _quickReplies[i];
              return InkWell(
                onTap: () => _send(chip),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    chip,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Rounded input capsule
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    textInputAction: TextInputAction.send,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (val) => _send(val),
                    style: GoogleFonts.outfit(fontSize: 15, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Message…',
                      hintStyle: GoogleFonts.outfit(color: AppTheme.mist, fontSize: 14),
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppTheme.lime,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => _send(_controller.text),
                  tooltip: 'Send',
                  icon: const Icon(Icons.send_rounded, size: 18, color: AppTheme.navy950),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
