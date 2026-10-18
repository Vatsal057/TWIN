import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/game_config.dart';
import '../../models/friend.dart';
import '../../services/deep_link_service.dart';
import '../../state/app_session.dart';
import '../../state/game_controller.dart';
import '../widgets/bouncy_tap.dart';
import '../widgets/character_avatar.dart';
import 'chat_room_view.dart';

/// Waiting room: shows the room code once, one share-invite action,
/// category badges, and the waiting pulse indicator.
class LobbyView extends StatefulWidget {
  const LobbyView({super.key, this.onCloseRoom});

  /// The close (X) action: the destructive exit, owned by the room
  /// page, which confirms and closes the room. Backing out any other
  /// way simply leaves the room waiting.
  final VoidCallback? onCloseRoom;

  @override
  State<LobbyView> createState() => _LobbyViewState();
}

class _LobbyViewState extends State<LobbyView> {
  bool _copied = false;

  void _copy(String code) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _share(String code, String fromName, {GameConfig? config}) {
    HapticFeedback.lightImpact();
    return SharePlus.instance.share(
      ShareParams(
        text: DeepLinkService.shareMessage(
          code,
          fromName: fromName,
          config: config,
        ),
        subject: config != null && config.hasCustomStart
            ? 'TWIN Challenge: ${config.startWordA} ↔ ${config.startWordB}'
            : 'Play TWIN with me',
      ),
    );
  }

  /// Friend picker for "Send code in chat": opens the pair's chat with
  /// the invite text waiting in the composer, the room still open
  /// underneath. Sending stays the player's own tap.
  void _showFriendPicker({
    required AppSession session,
    required List<Friend> friends,
    required String code,
    required GameConfig? config,
  }) {
    HapticFeedback.lightImpact();
    final room = context.read<GameController>().room;
    showModalBottomSheet(
      context: context,
      backgroundColor: session.palette.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
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
                'Send the code to',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: session.palette.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final friend in friends)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: StreamBuilder<String?>(
                            stream: session.backend.watchAvatarId(friend.id),
                            builder: (context, avatarSnap) => CharacterAvatar(
                              name: friend.name,
                              size: 44,
                              avatarId: avatarSnap.data,
                            ),
                          ),
                          title: Text(
                            friend.name,
                            style: GoogleFonts.outfit(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: session.palette.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            ChatRoomView.open(
                              context,
                              roomCode: code,
                              opponentId: friend.id,
                              opponentName: friend.name,
                              room: room,
                              insideRoom: true,
                              initialDraft: DeepLinkService.shareMessage(
                                code,
                                fromName: session.displayName,
                                config: config,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final session = context.watch<AppSession>();
    final code = game.roomCode;
    final config = game.room?.config;

    return Scaffold(
      backgroundColor: session.palette.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: session.palette.text),
          onPressed:
              widget.onCloseRoom ?? () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated icon
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: session.palette.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: session.palette.border),
                  ),
                  child: Icon(Icons.person_add_rounded, color: session.palette.accentInk, size: 36),
                ),
                const SizedBox(height: 20),

                Text(
                  'Waiting for a friend',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: session.palette.text,
                  ),
                ),
                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Send your friend the invite link. They join from their own device, no accounts needed.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: session.palette.muted,
                      height: 1.5,
                    ),
                  ),
                ),

                // Custom Start or Category pill if configured
                if (config != null) ...[
                  if (config.hasCustomStart) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: session.palette.accentSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: session.palette.accent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Starting pair: ${config.startWordA} · ${config.startWordB}',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: session.palette.accentInk,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else if (config.hasTheme) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: session.palette.accent2Soft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: session.palette.accent2.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Category: ${config.theme}',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: session.palette.accent2Ink,
                        ),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 24),

                // Large code capsule button with copy
                BouncyTap(
                  onTap: () => _copy(code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    decoration: BoxDecoration(
                      color: session.palette.surface,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: session.palette.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          code,
                          style: GoogleFonts.outfit(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                            color: session.palette.text,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.copy_rounded, color: session.palette.muted, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                AnimatedOpacity(
                  opacity: _copied ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    'Code copied to clipboard',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: session.palette.accentInk,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // The one share action: the system share sheet carries the
                // invite text with the link and the code, WhatsApp included.
                FilledButton.icon(
                  onPressed: () => _share(code, session.displayName, config: config),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text(
                    'Share invite',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: session.palette.accent,
                    foregroundColor: session.palette.onAccent,
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                ),

                // Or send the invite inside an existing TWIN chat: opens
                // the pair's conversation with the invite text waiting
                // in the composer. Only offered once there is a friend
                // to send it to. The room stays open underneath either
                // way; nothing here leaves or closes it.
                StreamBuilder<List<Friend>>(
                  stream: session.friends,
                  builder: (context, friendsSnap) {
                    final friends = friendsSnap.data ?? const <Friend>[];
                    if (friends.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: [
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _showFriendPicker(
                            session: session,
                            friends: friends,
                            code: code,
                            config: config,
                          ),
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            'Send code in chat',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: session.palette.text,
                            minimumSize: const Size.fromHeight(52),
                            side: BorderSide(
                              color: session.palette.text.withValues(alpha: 0.12),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 28),

                // Pulsing dots waiting indicator
                const _WaitingIndicator(),

                const SizedBox(height: 28),

                // Back to games button
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: session.palette.text,
                    minimumSize: const Size.fromHeight(52),
                    side: BorderSide(color: session.palette.text.withValues(alpha: 0.12)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  child: Text(
                    'Back to games',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitingIndicator extends StatefulWidget {
  const _WaitingIndicator();

  @override
  State<_WaitingIndicator> createState() => _WaitingIndicatorState();
}

class _WaitingIndicatorState extends State<_WaitingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 20,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    _PulseDot(progress: (_controller.value - i * 0.18) % 1.0),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Waiting for your opponent',
          style: GoogleFonts.outfit(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: context.watch<AppSession>().palette.muted,
          ),
        ),
      ],
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final wave = (1 - (progress * 2 - 1).abs()).clamp(0.0, 1.0);
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.watch<AppSession>().palette.accent.withValues(alpha: 0.25 + wave * 0.75),
      ),
    );
  }
}
