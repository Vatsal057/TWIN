import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/chat_controller.dart';
import '../app_theme.dart';
import 'chat_message_list.dart';

/// Collapsible chat for narrow screens, anchored to the bottom of the game.
///
/// Deliberately plain: a message stream and a text field. No read receipts, no
/// typing indicators, no media, no reactions. It lives inside the game screen
/// rather than a separate tab so nobody has to leave the round to talk.
///
/// On wide screens `ChatSidePanel` is used instead — there is space to keep chat
/// open permanently, so hiding it behind a tap would be pointless.
class ChatPanel extends StatelessWidget {
  const ChatPanel({super.key, required this.opponentName});

  final String opponentName;

  /// Total height of the collapsed bar, border included.
  static const collapsedHeight = 56.0;

  static const _borderWidth = 1.0;

  /// Floor for the expanded area so the composer always has room, even on a
  /// short screen.
  static const _minBodyHeight = 150.0;

  /// Space taken by the system navigation bar / gesture pill under the panel.
  ///
  /// The panel is pinned to the bottom of the window, so without this its
  /// contents sit *behind* the Android navigation bar. When the keyboard is up
  /// it covers the navigation bar, so the inset must not be double-counted.
  static double systemBottomInset(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return 0;
    return MediaQuery.viewPaddingOf(context).bottom;
  }

  /// Vertical space a scrolling sibling should leave free so the collapsed bar
  /// never covers its last item.
  static double reservedHeight(BuildContext context) =>
      collapsedHeight + systemBottomInset(context);

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    final screenHeight = MediaQuery.sizeOf(context).height;
    final safeBottom = systemBottomInset(context);
    final bodyHeight = math.max(
      _minBodyHeight,
      screenHeight * 0.55 - collapsedHeight - safeBottom,
    );

    // AnimatedSize (rather than an animated height) is deliberate: the expanded
    // contents have a fixed minimum height, so a growing box would overflow for
    // the first frames of the animation. AnimatedSize clips instead.
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.inkRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(
            top: BorderSide(
              color: AppTheme.parchment.withValues(alpha: 0.08),
              width: _borderWidth,
            ),
          ),
        ),
        // Padding inside the decoration, so the panel's background still runs
        // to the screen edge while its contents clear the navigation bar.
        child: Padding(
          padding: EdgeInsets.only(bottom: safeBottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The border counts towards the container's height, so the bar is
              // a hair shorter or the collapsed panel overflows by exactly 1px.
              _Handle(
                chat: chat,
                opponentName: opponentName,
                height: collapsedHeight - _borderWidth,
              ),
              if (chat.isOpen)
                SizedBox(
                  height: bodyHeight,
                  child: Column(
                    children: [
                      const Divider(height: 1),
                      Expanded(child: ChatMessageList(chat: chat)),
                      ChatComposer(chat: chat),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.chat,
    required this.opponentName,
    required this.height,
  });

  final ChatController chat;
  final String opponentName;
  final double height;

  @override
  Widget build(BuildContext context) {
    final unread = chat.unreadCount;
    return InkWell(
      onTap: chat.togglePanel,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(
                Icons.forum_outlined,
                size: 18,
                color: AppTheme.parchment.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),
              Text(
                chat.isOpen ? 'Chat' : 'Chat with $opponentName',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.parchment.withValues(alpha: 0.8),
                ),
              ),
              if (!chat.isOpen && unread > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.seed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              AnimatedRotation(
                duration: const Duration(milliseconds: 220),
                turns: chat.isOpen ? 0.5 : 0,
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: AppTheme.parchment.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
