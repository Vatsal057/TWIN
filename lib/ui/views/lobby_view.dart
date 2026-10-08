import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/game_config.dart';
import '../../services/deep_link_service.dart';
import '../../state/app_session.dart';
import '../../state/game_controller.dart';
import '../app_theme.dart';
import '../layout.dart';
import '../widgets/section_label.dart';

/// Waiting room. The code handshake happens outside the app — WhatsApp, SMS,
/// whatever — so this screen's only job is to make the code effortless to pass
/// along, then get out of the way the instant the second player lands.
class LobbyView extends StatelessWidget {
  const LobbyView({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final session = context.read<AppSession>();
    final code = game.roomCode;

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Lobby')),
      body: SafeArea(
        child: PageShell(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const SectionLabel('Room code'),
                const SizedBox(height: 16),
                _CodeCard(code: code),
                if (game.room?.config case final config?) ...[
                  if (config.hasCustomStart) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.seed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.seed.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Starting pair: ${config.startWordA} · ${config.startWordB}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: AppTheme.parchment,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ] else if (config.hasTheme) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.converged.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.converged.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Category: ${config.theme}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: AppTheme.parchment,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copy(context, code),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _share(
                          code,
                          session.displayName,
                          config: game.room?.config,
                        ),
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () => _shareWhatsApp(
                    code,
                    session.displayName,
                    config: game.room?.config,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text(
                    'Invite via WhatsApp',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 14),
                _LinkRow(code: code),
                const SizedBox(height: 36),
                const _WaitingIndicator(),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.inkRaised,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Send the code or the link. When they join, you both drop '
                    'into round one at the same moment.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: AppTheme.parchment.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _copy(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copied $code')));
  }

  static Future<void> _share(
    String code,
    String fromName, {
    GameConfig? config,
  }) {
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

  static Future<void> _shareWhatsApp(
    String code,
    String fromName, {
    GameConfig? config,
  }) async {
    final text = DeepLinkService.shareMessage(
      code,
      fromName: fromName,
      config: config,
    );
    final encoded = Uri.encodeComponent(text);
    final url = Uri.parse('https://api.whatsapp.com/send?text=$encoded');
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await SharePlus.instance.share(ShareParams(text: text));
      }
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: text));
    }
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppTheme.inkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.seed.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final char in code.split(''))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                char,
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.seed,
                  height: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final link = DeepLinkService.webJoinUri(code).toString();
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Clipboard.setData(ClipboardData(text: link));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Join link copied')));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              Icons.link_rounded,
              size: 16,
              color: AppTheme.parchment.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                link,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.parchment.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
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
          height: 26,
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
        const SizedBox(height: 14),
        Text(
          'Waiting for your opponent',
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 0.3,
            color: AppTheme.parchment.withValues(alpha: 0.7),
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
    // Ease in and out of full brightness once per cycle.
    final wave = (1 - (progress * 2 - 1).abs()).clamp(0.0, 1.0);
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.seed.withValues(alpha: 0.25 + wave * 0.75),
      ),
    );
  }
}
