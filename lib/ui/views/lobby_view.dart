import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/game_config.dart';
import '../../services/deep_link_service.dart';
import '../../state/app_session.dart';
import '../../state/game_controller.dart';
import '../app_theme.dart';
import '../widgets/bouncy_tap.dart';

/// Waiting room: shows the room code once, one share-invite action,
/// category badges, and the waiting pulse indicator.
class LobbyView extends StatefulWidget {
  const LobbyView({super.key});

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

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final session = context.read<AppSession>();
    final code = game.roomCode;
    final config = game.room?.config;

    return Scaffold(
      backgroundColor: AppTheme.navy950,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
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
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: const Icon(Icons.person_add_rounded, color: AppTheme.lime, size: 36),
                ),
                const SizedBox(height: 20),

                Text(
                  'Waiting for a friend',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
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
                      color: AppTheme.mist,
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
                        color: AppTheme.lime.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.lime.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Starting pair: ${config.startWordA} · ${config.startWordB}',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.lime,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else if (config.hasTheme) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.coral.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.coral.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Category: ${config.theme}',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.coral,
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
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.copy_rounded, color: AppTheme.mist, size: 20),
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
                      color: AppTheme.lime,
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
                    backgroundColor: AppTheme.lime,
                    foregroundColor: AppTheme.navy950,
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                ),

                const SizedBox(height: 28),

                // Pulsing dots waiting indicator
                const _WaitingIndicator(),

                const SizedBox(height: 28),

                // Back to games button
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
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
            color: AppTheme.mist,
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
        color: AppTheme.lime.withValues(alpha: 0.25 + wave * 0.75),
      ),
    );
  }
}
