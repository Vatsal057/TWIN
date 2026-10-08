import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/word_utils.dart';
import '../../models/game_round.dart';
import '../../models/room.dart';
import '../../services/deep_link_service.dart';
import '../app_theme.dart';
import 'convergence_hero.dart';

/// 9:16 Story-format victory card designed for 1080 × 1920 export
/// to Instagram Stories, WhatsApp Status, and camera rolls.
class VictoryCard extends StatelessWidget {
  const VictoryCard({
    super.key,
    required this.room,
    required this.localName,
    required this.opponentName,
    required this.localIsP1,
  });

  final Room room;
  final String localName;
  final String opponentName;
  final bool localIsP1;

  // Strict Design Tokens from Design Definition
  static const colorBg = Color(0xFF14120F);
  static const colorContainer = Color(0xFF1B1814);
  static const colorBorder = Color(0xFF302A23);
  static const colorParchment = Color(0xFFF2EDE3);
  static const colorMuted = Color(0xFFB7AEA1);
  static const colorAccent = Color(0xFF9AD8A9);
  static const colorMint = Color(0xFFD9F5DC);
  static const colorBadgeBorder = Color(0xFF3C6F4D);
  static const colorAlice = Color(0xFFD9A441);
  static const colorBob = Color(0xFF6EC5D9);
  static const colorCta = Color(0xFFB8E8C1);

  @override
  Widget build(BuildContext context) {
    final p1Name = localIsP1 ? localName : opponentName;
    final p2Name = localIsP1 ? opponentName : localName;
    final converged = room.converged;
    final lastRound = room.lastRound;

    return Container(
      width: 360,
      height: 640,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
      decoration: BoxDecoration(
        color: colorBg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 03 — Header: Editorial serif wordmark (No room code)
          Row(
            children: const [
              Text(
                'TWIN',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: colorParchment,
                ),
              ),
            ],
          ),

          const Spacer(flex: 3),

          // 04 — Players: Restrained pills around ALICE × BOB
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PlayerPill(name: p1Name, color: colorAlice),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '×',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                      color: colorParchment.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                _PlayerPill(name: p2Name, color: colorBob),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 05 — Victory Statement (Emotional Centerpiece)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  converged ? 'YOU BOTH SAID' : 'STOPPED AT',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                    color: colorMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  converged && lastRound != null
                      ? titleCaseWord(lastRound.p1Word).toUpperCase()
                      : '${room.rounds.length} ROUNDS',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: colorMint,
                  ),
                ),
                const SizedBox(height: 14),

                // 06 — Achievement badge (dynamic round count)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(90, 190, 125, 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorBadgeBorder, width: 1),
                  ),
                  child: Text(
                    converged
                        ? (room.rounds.length == 1
                            ? 'TWINNED IN 1 ROUND'
                            : 'TWINNED IN ${room.rounds.length} ROUNDS')
                        : 'PLAYED ${room.rounds.length} ROUNDS',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: colorAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 07 — Convergence Trail (Proof)
          if (room.rounds.isNotEmpty)
            _ConvergenceCard(rounds: room.rounds),

          const Spacer(flex: 5),

          // 08 — CTA (Invitation / Viral hook)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Think you can twin? →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorCta,
                  letterSpacing: -0.1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'twinnn.web.app',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: colorMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerPill extends StatelessWidget {
  const _PlayerPill({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _TrajectoryStep {
  final String text1;
  final String text2;
  final bool matched;
  final bool isEllipsis;

  const _TrajectoryStep({
    this.text1 = '',
    this.text2 = '',
    this.matched = false,
    this.isEllipsis = false,
  });
}

class _ConvergenceCard extends StatelessWidget {
  const _ConvergenceCard({required this.rounds});

  final List<GameRound> rounds;

  List<_TrajectoryStep> _buildTrajectory() {
    if (rounds.length <= 5) {
      return rounds
          .map((r) => _TrajectoryStep(
                text1: r.p1Word,
                text2: r.p2Word,
                matched: r.matched,
              ))
          .toList();
    }

    // Dynamic trajectory scaling: first 2 -> ellipsis -> last 2
    return [
      _TrajectoryStep(
        text1: rounds[0].p1Word,
        text2: rounds[0].p2Word,
        matched: rounds[0].matched,
      ),
      _TrajectoryStep(
        text1: rounds[1].p1Word,
        text2: rounds[1].p2Word,
        matched: rounds[1].matched,
      ),
      const _TrajectoryStep(isEllipsis: true),
      _TrajectoryStep(
        text1: rounds[rounds.length - 2].p1Word,
        text2: rounds[rounds.length - 2].p2Word,
        matched: rounds[rounds.length - 2].matched,
      ),
      _TrajectoryStep(
        text1: rounds[rounds.length - 1].p1Word,
        text2: rounds[rounds.length - 1].p2Word,
        matched: rounds[rounds.length - 1].matched,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildTrajectory();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: VictoryCard.colorContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VictoryCard.colorBorder, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.5),
              child: step.isEllipsis
                  ? Text(
                      '⋮',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.0,
                        color: VictoryCard.colorMuted.withValues(alpha: 0.6),
                      ),
                    )
                  : step.matched
                      ? Text(
                          titleCaseWord(step.text1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: VictoryCard.colorAccent,
                          ),
                        )
                      : Text(
                          '${titleCaseWord(step.text1)} · ${titleCaseWord(step.text2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: VictoryCard.colorParchment,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
            ),
        ],
      ),
    );
  }
}

/// Modal sheet that renders the victory card in a RepaintBoundary and exports
/// a 3x resolution PNG to system share.
class VictoryCardSheet extends StatefulWidget {
  const VictoryCardSheet({
    super.key,
    required this.room,
    required this.localName,
    required this.opponentName,
    required this.localIsP1,
  });

  final Room room;
  final String localName;
  final String opponentName;
  final bool localIsP1;

  static Future<void> show(
    BuildContext context, {
    required Room room,
    required String localName,
    required String opponentName,
    required bool localIsP1,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.inkRaised,
      constraints: const BoxConstraints(maxWidth: 480),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => VictoryCardSheet(
        room: room,
        localName: localName,
        opponentName: opponentName,
        localIsP1: localIsP1,
      ),
    );
  }

  @override
  State<VictoryCardSheet> createState() => _VictoryCardSheetState();
}

class _VictoryCardSheetState extends State<VictoryCardSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isExporting = false;

  Future<void> _shareImage() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    HapticFeedback.lightImpact();

    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final finalWord = widget.room.lastRound?.p1Word ?? 'TWIN';
      final score = calcResonanceScore(
        widget.room.rounds.length,
        widget.room.converged,
      );

      final xFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: 'twin_victory_${widget.room.code}.png',
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          subject: widget.room.converged
              ? 'We twinned on "${titleCaseWord(finalWord)}"!'
              : 'Our TWIN game results',
          text: widget.room.converged
              ? '${widget.localName} & ${widget.opponentName} scored $score% Resonance on "${titleCaseWord(finalWord).toUpperCase()}"!\nPlay: https://${DeepLinkService.webHost}'
              : '${widget.localName} & ${widget.opponentName} played ${widget.room.rounds.length} rounds on TWIN!\nPlay: https://${DeepLinkService.webHost}',
        ),
      );
    } catch (e) {
      debugPrint('Error sharing victory card: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate shareable image.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.parchment.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Victory Card',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.parchment,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Snapshotted for Instagram Stories, Twitter & camera roll.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.parchment.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 20),

              // The boundary that gets captured
              RepaintBoundary(
                key: _cardKey,
                child: VictoryCard(
                  room: widget.room,
                  localName: widget.localName,
                  opponentName: widget.opponentName,
                  localIsP1: widget.localIsP1,
                ),
              ),
              const SizedBox(height: 24),

              // Action button
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _isExporting ? null : _shareImage,
                icon: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.ink,
                        ),
                      )
                    : const Icon(Icons.share_rounded, size: 20),
                label: Text(
                  _isExporting ? 'Generating image…' : 'Share Victory Image',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
