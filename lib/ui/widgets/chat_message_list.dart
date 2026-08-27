import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../state/chat_controller.dart';
import '../app_theme.dart';
import '../layout.dart';

/// The message stream. Shared by the bottom sheet on phones and the docked side
/// panel on wide screens, so the two layouts can never drift apart.
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
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.parchment.withValues(alpha: 0.6),
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isMine
              ? AppTheme.seed.withValues(alpha: 0.18)
              : AppTheme.inkCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: AppTheme.parchment.withValues(
              alpha: message.pending ? 0.55 : 0.92,
            ),
          ),
        ),
      ),
    );
  }
}

/// Text field plus send button.
///
/// On desktop Enter sends and Shift+Enter is not needed, because messages here
/// are one-liners. The field keeps focus after sending so a back-and-forth does
/// not need a click between each message.
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

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    widget.chat.send(text);
    // Desktop users expect to keep typing; mobile users expect the keyboard to
    // stay up too, so this is the same either way.
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final compact = Layout.isCompact(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.send,
              maxLength: 500,
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => _send(),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: compact ? 'Message' : 'Message, Enter to send',
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _send,
            tooltip: 'Send',
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.seed,
              foregroundColor: AppTheme.ink,
              minimumSize: const Size(46, 46),
            ),
            icon: const Icon(Icons.arrow_upward_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
