import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/game_round.dart';
import '../app_theme.dart';
import 'reference_word_sticker.dart';
import 'twinning_burst.dart';

/// Full-screen Round Revealed Preview matching reference .mov Frame 22 and react_app:
/// When both players submit their word for a round, this view takes the screen:
/// - "ROUND X REVEALED" header tracking
/// - Giant tilted WordStickers (You vs Opponent) with organic dotted bead chain
/// - Large bold verdict ("No match" or "Twin!")
/// - Guiding subtitle ("aim between these two next round")
/// - Frosted capsule "Next round >" button
class RevealOverlay extends StatefulWidget {
  const RevealOverlay({
    super.key,
    required this.round,
    required this.p1Name,
    required this.p2Name,
    required this.onDismiss,
    this.localIsP1 = true,
  });

  final GameRound round;
  final String p1Name;
  final String p2Name;
  final bool localIsP1;
  final VoidCallback onDismiss;

  @override
  State<RevealOverlay> createState() => _RevealOverlayState();
}

class _RevealOverlayState extends State<RevealOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _scaleAnimation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );

  late final Animation<double> _fadeAnimation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final round = widget.round;
    final matched = round.matched;

    // Determine left (local) and right (opponent) word & name
    final leftWord = widget.localIsP1 ? round.displayP1Word : round.displayP2Word;
    final rightWord = widget.localIsP1 ? round.displayP2Word : round.displayP1Word;
    final leftName = 'You';
    final rightName = widget.localIsP1 ? widget.p2Name : widget.p1Name;

    return Semantics(
      liveRegion: true,
      label: 'Round ${round.index} revealed: $leftWord and $rightWord. ${matched ? "Twin!" : "No match"}',
      child: GestureDetector(
        onTap: widget.onDismiss,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: ColoredBox(
            color: AppTheme.navy950,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final scale = _scaleAnimation.value;
                      final opacity = _fadeAnimation.value;

                      return Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: 0.8 + 0.2 * scale,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // "ROUND X REVEALED" label
                              Text(
                                'ROUND ${round.index} REVEALED',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3.5,
                                  color: AppTheme.mist,
                                ),
                              ),
                              const SizedBox(height: 36),

                              // Two giant word stickers with bead chain.
                              // Packed together in the centre exactly like the
                              // game screen (AnchorPair): no Expanded, which
                              // was pushing each chip to the middle of its own
                              // half and leaving a wide gap around the bridge.
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                  // Left Word (You)
                                  Transform.translate(
                                      offset: const Offset(0, -6),
                                      child: Column(
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: WordSticker(
                                              word: leftWord,
                                              tone: WordTone.lime,
                                              rotate: -10.0,
                                              isLarge: true,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            leftName,
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.mist,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ),

                                  // Dotted Bridge, raised so the cluster sits in
                                  // the upper gap between the cards, as in the
                                  // reference (see anchor_pair.dart)
                                  Transform.translate(
                                    offset: const Offset(0, -20),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 2),
                                      child: DottedChainBridge(),
                                    ),
                                  ),

                                  // Right Word (Opponent)
                                  Transform.translate(
                                      offset: const Offset(0, 17),
                                      child: Column(
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: WordSticker(
                                              word: rightWord,
                                              tone: matched ? WordTone.lime : WordTone.coral,
                                              rotate: 10.0,
                                              isLarge: true,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            rightName,
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.mist,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Verdict
                              if (matched)
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: GoogleFonts.outfit(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                    children: const [
                                      TextSpan(text: 'Twin'),
                                      TextSpan(text: '!', style: TextStyle(color: AppTheme.lime)),
                                    ],
                                  ),
                                )
                              else
                                Text(
                                  'No match',
                                  style: GoogleFonts.outfit(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),

                              const SizedBox(height: 8),

                              // Subtitle
                              Text(
                                matched
                                    ? 'matched in ${round.index} rounds'
                                    : 'aim between these two next round',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.mist,
                                ),
                              ),

                              const SizedBox(height: 38),

                              // "Next round >" Capsule Button
                              InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  widget.onDismiss();
                                },
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        matched ? 'View results' : 'Next round',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (matched)
                Positioned.fill(
                  child: IgnorePointer(
                    child: TwinningBurst(word: leftWord),
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

