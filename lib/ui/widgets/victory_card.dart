import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/word_utils.dart';
import '../../models/room.dart';
import '../../services/deep_link_service.dart';
import '../app_theme.dart';
import 'character_avatar.dart';

/// 9:16 Story-format victory card designed for 1080 x 1920 export
/// to Instagram Stories, WhatsApp Status, and camera rolls.
///
/// The look follows the reference win card: a TWINNING headline over
/// soft radial rays and scattered confetti, the two players' avatar
/// faces side by side with a heart badge on the seam, the matched word
/// in lime underneath (sized to be read, not to shout), then the round
/// count and the perfect-match stat side by side.
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

  static const colorBg = AppTheme.navy950;
  static const colorMuted = AppTheme.mist;
  static const colorAccent = AppTheme.lime;

  @override
  Widget build(BuildContext context) {
    final converged = room.converged;
    final lastRound = room.lastRound;
    final roundsCount = room.rounds.length;
    final localId = localIsP1 ? room.p1Id : room.p2Id;
    final opponentId = localIsP1 ? room.p2Id : room.p1Id;

    return Container(
      width: 360,
      height: 640,
      decoration: BoxDecoration(
        color: colorBg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _RaysPainter()),
            ),
            const Positioned.fill(
              child: CustomPaint(painter: _ConfettiPainter()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 38, 24, 30),
              child: Column(
                children: [
                  // Headline
                  Text(
                    converged ? 'TWINNING' : 'SO CLOSE',
                    style: GoogleFonts.outfit(
                      fontSize: 37,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // The pair: real avatar faces, heart badge on the seam
                  _AvatarPair(
                    localName: localName,
                    opponentName: opponentName,
                    localAvatarId: room.avatarOf(localId),
                    opponentAvatarId: room.avatarOf(opponentId),
                  ),

                  const SizedBox(height: 28),

                  // The matched word, kept readable rather than huge
                  if (converged && lastRound != null) ...[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        titleCaseWord(lastRound.p1Word).toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: GoogleFonts.outfit(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: colorAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$localName + $opponentName',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorMuted,
                      ),
                    ),
                  ] else ...[
                    Text(
                      roundsCount == 1 ? '1 ROUND' : '$roundsCount ROUNDS',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$localName + $opponentName',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorMuted,
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Stats: rounds | perfect match
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$roundsCount',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ROUNDS',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                              color: colorMuted,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 46,
                        margin: const EdgeInsets.symmetric(horizontal: 28),
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            converged
                                ? Icons.emoji_events_rounded
                                : Icons.favorite_rounded,
                            size: 27,
                            color: colorAccent,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            converged ? 'PERFECT\nMATCH' : 'GOOD\nRUN',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                              height: 1.5,
                              color: colorMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Wordmark
                  Text(
                    'Twin',
                    style: GoogleFonts.outfit(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'twinnn.web.app',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: colorMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two players as their chosen avatar faces, side by side, with a
/// small heart badge bridging the gap. This stands in for the old
/// overlapping initial circles, which read as a Venn diagram; faces say
/// "the two of us" much better, and they are the actual faces each
/// player picked (synced through the room).
class _AvatarPair extends StatelessWidget {
  const _AvatarPair({
    required this.localName,
    required this.opponentName,
    required this.localAvatarId,
    required this.opponentAvatarId,
  });

  final String localName;
  final String opponentName;
  final String? localAvatarId;
  final String? opponentAvatarId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CharacterAvatar(
                name: localName,
                size: 88,
                avatarId: localAvatarId,
              ),
              CharacterAvatar(
                name: opponentName,
                size: 88,
                avatarId: opponentAvatarId,
              ),
            ],
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.navy900,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.navy950, width: 2.5),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              size: 16,
              color: AppTheme.lime,
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft radial rays fanning down from behind the headline, as on the
/// reference card: alternate wedges of very faint lime.
class _RaysPainter extends CustomPainter {
  const _RaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final focal = Offset(size.width / 2, size.height * 0.16);
    final paint = Paint()..color = AppTheme.lime.withValues(alpha: 0.05);
    const wedges = 12;
    const startDeg = 18.0;
    const endDeg = 162.0;
    final radius = size.height * 1.15;

    for (var i = 0; i < wedges; i += 2) {
      final a1 = (startDeg + (endDeg - startDeg) * i / wedges) * math.pi / 180;
      final a2 =
          (startDeg + (endDeg - startDeg) * (i + 1) / wedges) * math.pi / 180;
      final path = Path()
        ..moveTo(focal.dx, focal.dy)
        ..lineTo(focal.dx + radius * math.cos(a1), focal.dy + radius * math.sin(a1))
        ..lineTo(focal.dx + radius * math.cos(a2), focal.dy + radius * math.sin(a2))
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Scattered confetti pieces around the card edges, kept clear of the
/// centre column where the content sits. Positions are fixed so every
/// export of the same card looks identical.
class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // (x, y as fractions of the card, width, rotation in degrees, colour)
    const pieces = [
      (0.07, 0.09, 15.0, -32.0, AppTheme.lime),
      (0.18, 0.045, 12.0, 24.0, AppTheme.coral),
      (0.84, 0.06, 15.0, 38.0, AppTheme.lime),
      (0.95, 0.15, 12.0, -18.0, AppTheme.coral),
      (0.91, 0.30, 14.0, 52.0, AppTheme.lime),
      (0.05, 0.31, 13.0, -44.0, AppTheme.coral),
      (0.09, 0.52, 12.0, 30.0, AppTheme.lime),
      (0.94, 0.54, 13.0, -26.0, AppTheme.lime),
      (0.06, 0.75, 14.0, 44.0, AppTheme.coral),
      (0.92, 0.77, 15.0, -38.0, AppTheme.lime),
      (0.22, 0.93, 13.0, -20.0, AppTheme.lime),
      (0.76, 0.94, 12.0, 28.0, AppTheme.coral),
      (0.33, 0.03, 11.0, 60.0, AppTheme.lime),
      (0.64, 0.035, 12.0, -52.0, AppTheme.coral),
      (0.97, 0.42, 11.0, 18.0, AppTheme.coral),
      (0.03, 0.45, 11.0, -60.0, AppTheme.lime),
    ];

    for (final (fx, fy, w, rot, color) in pieces) {
      canvas.save();
      canvas.translate(fx * size.width, fy * size.height);
      canvas.rotate(rot * math.pi / 180);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.45),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      backgroundColor: AppTheme.navy900,
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
      final roundsCount = widget.room.rounds.length;

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
              ? '${widget.localName} & ${widget.opponentName} twinned on "${titleCaseWord(finalWord).toUpperCase()}" in $roundsCount ${roundsCount == 1 ? 'round' : 'rounds'}!\nPlay: https://${DeepLinkService.webHost}'
              : '${widget.localName} & ${widget.opponentName} played $roundsCount rounds on TWIN!\nPlay: https://${DeepLinkService.webHost}',
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
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Victory Card',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Snapshotted for Instagram Stories, Twitter & camera roll.',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppTheme.mist,
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
                  backgroundColor: AppTheme.lime,
                  foregroundColor: AppTheme.navy950,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: _isExporting ? null : _shareImage,
                icon: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.navy950,
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
