import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/chat_controller.dart';
import '../app_theme.dart';
import 'chat_message_list.dart';

/// Chat docked beside the game on wide screens.
///
/// On a desktop browser there is no reason to hide chat behind a tap: the space
/// is already there. So it sits open permanently, and the collapse control is
/// dropped entirely — nothing to discover, nothing to toggle.
class ChatSidePanel extends StatefulWidget {
  const ChatSidePanel({super.key, required this.opponentName});

  final String opponentName;

  @override
  State<ChatSidePanel> createState() => _ChatSidePanelState();
}

class _ChatSidePanelState extends State<ChatSidePanel> {
  @override
  void initState() {
    super.initState();
    // The panel is visible from the moment it mounts, so messages are read on
    // arrival and the unread badge never applies here. Deferred to after the
    // frame because this notifies listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ChatController>().setPanelOpen(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.inkRaised,
        border: Border(
          left: BorderSide(color: AppTheme.parchment.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        children: [
          _Header(opponentName: widget.opponentName),
          const Divider(height: 1),
          Expanded(child: ChatMessageList(chat: chat)),
          ChatComposer(chat: chat),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.opponentName});

  final String opponentName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            Icon(
              Icons.forum_outlined,
              size: 17,
              color: AppTheme.parchment.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                opponentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.parchment.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
