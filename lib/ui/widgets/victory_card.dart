import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/word_utils.dart';
import '../../models/game_round.dart';
import '../../models/room.dart';
import '../../services/deep_link_service.dart';
import '../app_theme.dart';
import 'character_avatar.dart';

/// Colours sampled from the word stickers, shared by the victory card
/// and the result screen so the two always match.
const slabLime = Color(0xFFCBF56E);
const stickerCoral = Color(0xFFEC715D);
const coralText = Color(0xFFFF7A63);
const nameColor = Color(0xFFEDEDF4);

/// 9:16 Story-format victory card designed for 1080 x 1920 export
/// to Instagram Stories, WhatsApp Status, and camera rolls.
///
/// The locked design: soft radial rays and sparse confetti over navy,
/// the two players' faces with dash pairs on their rims and the rings
/// glyph between them, a heavy TWINNING headline, the matched word on
/// a compact lime slab, and a guesses panel holding the journey
/// (first pair, last pair, matched pair) with a wave chain between
/// unmatched words and a straight dotted line between the matched
/// ones. Footer is the rings wordmark and the "Think you can twin?"
/// call to action.
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

  String _localWord(GameRound round) => localIsP1 ? round.p1Word : round.p2Word;
  String _opponentWord(GameRound round) =>
      localIsP1 ? round.p2Word : round.p1Word;

  /// The card never shows more than the bookends of the journey plus
  /// the matched pair; the full list lives on the result screen.
  List<GameRound> get _cardRounds {
    final rounds = room.rounds;
    if (rounds.isEmpty) return const [];
    if (room.converged) {
      if (rounds.length <= 2) return rounds;
      return [rounds.first, rounds[rounds.length - 2], rounds.last];
    }
    if (rounds.length == 1) return rounds;
    return [rounds.first, rounds.last];
  }

  @override
  Widget build(BuildContext context) {
    final converged = room.converged;
    final abandoned = room.finishReason == FinishReason.abandoned;
    final lastRound = room.lastRound;
    final roundsCount = room.rounds.length;
    final localId = localIsP1 ? room.p1Id : room.p2Id;
    final opponentId = localIsP1 ? room.p2Id : room.p1Id;
    final cardRounds = _cardRounds;

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
              child: CustomPaint(painter: TwinRaysPainter()),
            ),
            const Positioned.fill(
              child: CustomPaint(painter: TwinConfettiPainter()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  TwinFacesHeader(
                    localName: localName,
                    opponentName: opponentName,
                    localAvatarId: room.avatarOf(localId),
                    opponentAvatarId: room.avatarOf(opponentId),
                  ),
                  const SizedBox(height: 10),
                  TwinHeadline(converged: converged),
                  const SizedBox(height: 7),
                  const TwinTagline(),
                  if (converged && lastRound != null) ...[
                    const SizedBox(height: 14),
                    TwinHeroSlab(word: lastRound.p1Word),
                  ],
                  const SizedBox(height: 12),
                  TwinRoundsCaption(
                    converged: converged,
                    abandoned: abandoned,
                    rounds: roundsCount,
                  ),
                  if (cardRounds.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    GuessesPanelShell(
                      localName: localName,
                      opponentName: opponentName,
                      child: Column(
                        children: [
                          for (var i = 0; i < cardRounds.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            GuessRow(
                              localWord: _localWord(cardRounds[i]),
                              opponentWord: _opponentWord(cardRounds[i]),
                              matched: cardRounds[i].matched,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  const _CardFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardFooter extends StatelessWidget {
  const _CardFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const TwinRingsGlyph(width: 30),
        const SizedBox(height: 5),
        Text(
          'TWIN',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 5,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 7),
        RichText(
          text: TextSpan(
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.mist,
            ),
            children: [
              const TextSpan(text: 'Think you can twin? '),
              TextSpan(
                text: '→',
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.lime,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Text(
            'twinnn.web.app',
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: const Color(0xFFA6ABC0),
            ),
          ),
        ),
      ],
    );
  }
}

/// The two players' faces with their names underneath, the rings
/// glyph floating between them, and a pair of dash bursts sitting on
/// each face's upper outer rim, lime for the local player, coral for
/// the opponent. Positions follow the reference card: face centres at
/// 29.5% and 70.5% of the available width.
class TwinFacesHeader extends StatelessWidget {
  const TwinFacesHeader({
    super.key,
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
      height: 86,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final c1 = w * 0.295;
          final c2 = w * 0.705;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              _person(c1, localName, localAvatarId),
              _person(c2, opponentName, opponentAvatarId),
              _dash(c1 - 40.7, 32 - 25, 20, AppTheme.lime),
              _dash(c1 - 33.2, 32 - 35.6, 53, AppTheme.lime),
              _dash(c2 + 40.5, 32 - 26.6, -25, stickerCoral),
              _dash(c2 + 32.5, 32 - 36.4, -55, stickerCoral),
              Positioned(
                left: w / 2 - 16,
                top: 21,
                child: const TwinRingsGlyph(width: 32),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _person(double center, String name, String? avatarId) {
    return Positioned(
      left: center - 32,
      top: 0,
      width: 64,
      child: Column(
        children: [
          CharacterAvatar(name: name, size: 64, avatarId: avatarId),
          const SizedBox(height: 7),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: nameColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dash(double cx, double cy, double degrees, Color color) {
    return Positioned(
      left: cx - 7,
      top: cy - 1.75,
      child: Transform.rotate(
        angle: degrees * math.pi / 180,
        child: Container(
          width: 14,
          height: 3.5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// The converge motif: two lime rings overlapping, the shared lens
/// filled. Drawn as outlines, unlike [ConvergeIcon] which is solid.
class TwinRingsGlyph extends StatelessWidget {
  const TwinRingsGlyph({super.key, this.width = 32});

  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * 24 / 34),
      painter: const _RingsPainter(),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 34;
    final c1 = Offset(13 * s, 12 * s);
    final c2 = Offset(21 * s, 12 * s);
    final r = 8 * s;
    final lens = Path.combine(
      PathOperation.intersect,
      Path()..addOval(Rect.fromCircle(center: c1, radius: r)),
      Path()..addOval(Rect.fromCircle(center: c2, radius: r)),
    );
    canvas.drawPath(
      lens,
      Paint()..color = AppTheme.lime.withValues(alpha: 0.85),
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * s
      ..color = AppTheme.lime;
    canvas.drawCircle(c1, r, stroke);
    canvas.drawCircle(c2, r, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The heavy headline. Outfit Black alone is not as thick as the
/// design, so a stroked copy sits under the filled one.
class TwinHeadline extends StatelessWidget {
  const TwinHeadline({super.key, required this.converged});

  final bool converged;

  @override
  Widget build(BuildContext context) {
    final text = converged ? 'TWINNING' : 'SO CLOSE';
    final fill = GoogleFonts.outfit(
      fontSize: 48,
      fontWeight: FontWeight.w900,
      letterSpacing: 1,
      height: 1.0,
      color: Colors.white,
    );
    final stroke = GoogleFonts.outfit(
      fontSize: 48,
      fontWeight: FontWeight.w900,
      letterSpacing: 1,
      height: 1.0,
    ).copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Sparkle(color: AppTheme.lime),
        const SizedBox(width: 10),
        Stack(children: [Text(text, style: stroke), Text(text, style: fill)]),
        const SizedBox(width: 10),
        const _Sparkle(color: AppTheme.coral),
      ],
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(15, 15),
      painter: _SparklePainter(color),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.61, h * 0.39)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.61, h * 0.61)
      ..lineTo(w * 0.5, h)
      ..lineTo(w * 0.39, h * 0.61)
      ..lineTo(0, h * 0.5)
      ..lineTo(w * 0.39, h * 0.39)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// "TWO MINDS. ONE WORD." letterspaced under the headline.
class TwinTagline extends StatelessWidget {
  const TwinTagline({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'TWO MINDS. ONE WORD.',
      style: GoogleFonts.outfit(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 3.6,
        color: AppTheme.mist,
      ),
    );
  }
}

/// The matched word on its compact lime slab, tilted a touch, with a
/// pair of lime dashes pointing in at it from each side.
class TwinHeroSlab extends StatelessWidget {
  const TwinHeroSlab({super.key, required this.word});

  final String word;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _HeroTicks(left: true),
        const SizedBox(width: 12),
        Transform.rotate(
          angle: -2 * math.pi / 180,
          child: Container(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: slabLime,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.lime.withValues(alpha: 0.28),
                  blurRadius: 26,
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                titleCaseWord(word).toUpperCase(),
                maxLines: 1,
                style: GoogleFonts.outfit(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  height: 1.05,
                  color: AppTheme.navy950,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const _HeroTicks(left: false),
      ],
    );
  }
}

class _HeroTicks extends StatelessWidget {
  const _HeroTicks({required this.left});

  final bool left;

  @override
  Widget build(BuildContext context) {
    final top = left ? 40.0 : -40.0;
    final bottom = -top;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tick(top),
        const SizedBox(height: 8),
        _tick(bottom),
      ],
    );
  }

  Widget _tick(double degrees) {
    return Transform.rotate(
      angle: degrees * math.pi / 180,
      child: Container(
        width: 13,
        height: 3.5,
        decoration: BoxDecoration(
          color: AppTheme.lime,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// "MATCHED IN 15 ROUNDS" with the count picked out in lime.
class TwinRoundsCaption extends StatelessWidget {
  const TwinRoundsCaption({
    super.key,
    required this.converged,
    required this.abandoned,
    required this.rounds,
  });

  final bool converged;
  final bool abandoned;
  final int rounds;

  @override
  Widget build(BuildContext context) {
    final lead = converged
        ? 'MATCHED IN '
        : abandoned
        ? 'ENDED IN '
        : 'NO MATCH IN ';
    final base = GoogleFonts.outfit(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 3,
      color: AppTheme.mist,
    );
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: lead),
          TextSpan(
            text: '$rounds',
            style: base.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.lime,
            ),
          ),
          TextSpan(text: rounds == 1 ? ' ROUND' : ' ROUNDS'),
        ],
      ),
    );
  }
}

enum GuessPillKind { local, opponent, win }

/// One word in the guesses panel. Unmatched words sit on a dim tint
/// of their player's colour; the matched pair is solid lime.
class GuessPill extends StatelessWidget {
  const GuessPill({super.key, required this.word, required this.kind});

  final String word;
  final GuessPillKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, glow) = switch (kind) {
      GuessPillKind.local => (
        slabLime.withValues(alpha: 0.15),
        slabLime,
        false,
      ),
      GuessPillKind.opponent => (
        stickerCoral.withValues(alpha: 0.16),
        coralText,
        false,
      ),
      GuessPillKind.win => (slabLime, AppTheme.navy900, true),
    };
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: AppTheme.lime.withValues(alpha: 0.35),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          titleCaseWord(word).toUpperCase(),
          maxLines: 1,
          style: GoogleFonts.outfit(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// A pair of guesses: pill, connector, pill. Unmatched pairs are
/// joined by the little wave of beads; the matched pair by a straight
/// dotted line.
class GuessRow extends StatelessWidget {
  const GuessRow({
    super.key,
    required this.localWord,
    required this.opponentWord,
    required this.matched,
  });

  final String localWord;
  final String opponentWord;
  final bool matched;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GuessPill(
            word: localWord,
            kind: matched ? GuessPillKind.win : GuessPillKind.local,
          ),
        ),
        const SizedBox(width: 10),
        matched ? const StraightBeads() : const WaveChain(),
        const SizedBox(width: 10),
        Expanded(
          child: GuessPill(
            word: opponentWord,
            kind: matched ? GuessPillKind.win : GuessPillKind.opponent,
          ),
        ),
      ],
    );
  }
}

/// The bead wave between unmatched words, in the chain's earthy
/// colours, bent into a shallow ~.
class WaveChain extends StatelessWidget {
  const WaveChain({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(36, 17),
      painter: _WaveChainPainter(),
    );
  }
}

class _WaveChainPainter extends CustomPainter {
  const _WaveChainPainter();

  static const _beads = [
    (3.5, 8.5, 2.6, Color(0xFF796B5B)),
    (10.8, 4.6, 2.1, Color(0xFF766556)),
    (18.0, 8.5, 2.8, Color(0xFF846D5C)),
    (25.3, 12.4, 2.4, Color(0xFF8A6755)),
    (32.5, 8.5, 2.9, Color(0xFF9C6355)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, r, color) in _beads) {
      canvas.drawCircle(Offset(x, y), r, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The bead chain laid out straight, for the matched pair: the
/// wave chain's own beads (same spots, same sizes), all on the
/// centre line, in the win colour.
class StraightBeads extends StatelessWidget {
  const StraightBeads({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(36, 17),
      painter: _StraightBeadsPainter(),
    );
  }
}

class _StraightBeadsPainter extends CustomPainter {
  const _StraightBeadsPainter();

  static const _beads = [
    (3.5, 2.6),
    (10.8, 2.1),
    (18.0, 2.8),
    (25.3, 2.4),
    (32.5, 2.9),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.lime;
    for (final (x, r) in _beads) {
      canvas.drawCircle(Offset(x, size.height / 2), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The frosted panel that holds the guesses, with the two players'
/// names as column headers. [child] is the rows: a fixed column on
/// the card, a scrollable list on the result screen.
class GuessesPanelShell extends StatelessWidget {
  const GuessesPanelShell({
    super.key,
    required this.localName,
    required this.opponentName,
    required this.child,
  });

  final String localName;
  final String opponentName;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final headerStyle = GoogleFonts.outfit(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppTheme.mist,
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "$localName's guesses",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: headerStyle,
                ),
              ),
              Expanded(
                child: Text(
                  "$opponentName's guesses",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: headerStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Soft radial rays fanning down from behind the faces, as on the
/// reference card: alternate wedges of very faint lime.
class TwinRaysPainter extends CustomPainter {
  const TwinRaysPainter({this.focal, this.fullBurst = false});

  /// Where the rays pour out of. Null keeps the card's design point
  /// (centred, 16% down the surface). The result screen passes the
  /// measured centre of the rings glyph between the faces instead, so
  /// on the screen the rays start at the twinning icon itself.
  final Offset? focal;

  /// False fans the rays downward only, as on the card. True runs the
  /// same wedges the full way around the focal point, upward included.
  final bool fullBurst;

  @override
  void paint(Canvas canvas, Size size) {
    final focal = this.focal ?? Offset(size.width / 2, size.height * 0.16);
    final paint = Paint()..color = AppTheme.lime.withValues(alpha: 0.05);
    final wedges = fullBurst ? 30 : 12;
    final startDeg = fullBurst ? 0.0 : 18.0;
    final endDeg = fullBurst ? 360.0 : 162.0;
    final radius = size.height * 1.15;

    for (var i = 0; i < wedges; i += 2) {
      final a1 = (startDeg + (endDeg - startDeg) * i / wedges) * math.pi / 180;
      final a2 =
          (startDeg + (endDeg - startDeg) * (i + 1) / wedges) * math.pi / 180;
      final path = Path()
        ..moveTo(focal.dx, focal.dy)
        ..lineTo(
          focal.dx + radius * math.cos(a1),
          focal.dy + radius * math.sin(a1),
        )
        ..lineTo(
          focal.dx + radius * math.cos(a2),
          focal.dy + radius * math.sin(a2),
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant TwinRaysPainter oldDelegate) =>
      oldDelegate.focal != focal || oldDelegate.fullBurst != fullBurst;
}

/// Sparse confetti pieces, placed from the locked card design and
/// kept clear of the faces. Positions are fixed so every export of
/// the same card looks identical.
class TwinConfettiPainter extends CustomPainter {
  const TwinConfettiPainter({
    this.burst = 1,
    this.burstOrigin,
    this.floatPhase = 0,
    this.drift = 0,
  });

  /// Entrance flight, 0 to 1: each piece travels from [burstOrigin]
  /// out to its own spot, slightly staggered per piece. 1 (the
  /// default) is fully settled, which is how the card uses it, so
  /// card exports never move.
  final double burst;
  final Offset? burstOrigin;

  /// The endless drift, in whole turns. Only applied when [drift] is
  /// above 0; the result screen passes 1, the card leaves it at 0 and
  /// its pieces sit exactly on their locked spots.
  final double floatPhase;
  final double drift;

  @override
  void paint(Canvas canvas, Size size) {
    // (x, y as fractions of the surface, width, rotation in degrees, colour)
    const pieces = [
      (0.050, 0.138, 12.0, -32.0, AppTheme.lime),
      (0.931, 0.058, 12.0, 24.0, AppTheme.coral),
      (0.950, 0.147, 12.0, -30.0, AppTheme.coral),
      (0.044, 0.459, 12.0, 38.0, AppTheme.lime),
      (0.925, 0.450, 12.0, -28.0, AppTheme.coral),
      (0.061, 0.886, 12.0, 44.0, AppTheme.coral),
      (0.919, 0.900, 12.0, -32.0, AppTheme.lime),
      (0.158, 0.966, 12.0, -24.0, AppTheme.lime),
      (0.836, 0.966, 12.0, 30.0, AppTheme.coral),
    ];

    final origin = burstOrigin ?? Offset(size.width / 2, size.height * 0.36);
    var i = 0;
    for (final (fx, fy, w, rot, color) in pieces) {
      // Per-piece flight progress, staggered so the pieces do not all
      // land at once, eased out so they arrive gently.
      final raw = ((burst - i * 0.04) / 0.68).clamp(0.0, 1.0);
      final u = 1 - raw;
      final fly = 1 - u * u * u;
      final phase = i * 2.4;
      final sway =
          Offset(
            math.sin(floatPhase * 2 * math.pi + phase) * 5,
            math.cos(floatPhase * 2 * math.pi * 0.85 + phase * 1.3) * 6,
          ) *
          drift;
      final spot = Offset(fx * size.width, fy * size.height) + sway;
      final center = Offset.lerp(origin, spot, fly)!;
      final wobble =
          math.sin(floatPhase * 2 * math.pi + i * 1.7) * 10 * drift;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((rot + wobble) * math.pi / 180);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.45),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = color.withValues(alpha: fly.clamp(0.0, 1.0)),
      );
      canvas.restore();
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant TwinConfettiPainter oldDelegate) =>
      oldDelegate.burst != burst ||
      oldDelegate.burstOrigin != burstOrigin ||
      oldDelegate.floatPhase != floatPhase ||
      oldDelegate.drift != drift;
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
                style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.mist),
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
