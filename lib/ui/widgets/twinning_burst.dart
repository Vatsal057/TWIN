import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';

/// Radians of peak wobble on a letter as it lands.
const _wobbleAmplitude = 0.20;

/// Oscillations a letter makes while settling. Higher reads as more frantic.
const _wobbleCycles = 3.0;

/// Normalised delay between consecutive letters starting their pop.
const _letterStagger = 0.05;

/// Normalised duration of a single letter's pop.
const _letterPop = 0.30;

/// Base glyph size, and the ceiling on large screens.
///
/// [FittedBox] only ever scales *down*, so on a phone this value is irrelevant —
/// the mark is fit to the available width regardless. It matters on desktop,
/// where the natural size is what you get. Sized so a wide window still fills
/// edge to edge rather than stranding the mark at two thirds of the screen.
const _glyphSize = 160.0;

/// The payoff. When both players land on the same word, this slams over the
/// entire screen.
///
/// The wobble deliberately *decays* instead of repeating. A sustained
/// left-right shake is the platform gesture for rejection — wrong password,
/// failed validation — so holding it would read as an error at the exact moment
/// the player succeeded. Damping keeps the impact and drops the connotation.
/// The constants above are the whole feel of this; tune those rather than
/// [build].
class TwinningBurst extends StatefulWidget {
  const TwinningBurst({
    super.key,
    required this.word,
    this.delay = const Duration(milliseconds: 640),
  });

  /// The word both players landed on, already display-cased.
  final String word;

  /// How long to hold before slamming in, so the two revealed words have time
  /// to meet in the middle first.
  final Duration delay;

  @override
  State<TwinningBurst> createState() => _TwinningBurstState();
}

class _TwinningBurstState extends State<TwinningBurst>
    with SingleTickerProviderStateMixin {
  static const _letters = ['T', 'W', 'I', 'N', 'N', 'I', 'N', 'G', '!'];

  /// Created eagerly in [initState], never as a lazy `late final`. [build]
  /// returns early before the slam and so never touches it, which would leave
  /// `dispose` as the first access — and constructing a controller there runs
  /// `createTicker` against an already-deactivated element, which throws. That
  /// is the real path where the reveal is dismissed during [TwinningBurst.delay].
  late final AnimationController _controller;

  Timer? _start;

  /// Nothing paints until the slam. Without this the flash term, which is at
  /// full strength when the controller sits at zero, would wash the reveal green
  /// for the whole of [widget.delay].
  bool _launched = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _start = Timer(widget.delay, _launch);
  }

  void _launch() {
    if (!mounted) return;
    // Fires on the slam, not on the match, so the buzz lands with the letters.
    HapticFeedback.heavyImpact();
    setState(() => _launched = true);
    _controller.forward();
  }

  @override
  void dispose() {
    _start?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_launched) return const SizedBox.shrink();

    // The letters would otherwise be spelled out one glyph at a time. The
    // parent reveal already announces the outcome as a live region.
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // Honour "reduce motion" by presenting the settled frame outright.
          // Read here rather than cached, because build is the only place an
          // inherited lookup is unconditionally safe.
          final t = MediaQuery.disableAnimationsOf(context)
              ? 1.0
              : _controller.value;
          final backdrop = (t / 0.12).clamp(0.0, 1.0);
          final flash = (1 - (t / 0.20).clamp(0.0, 1.0)) * 0.4;
          final tail = ((t - 0.55) / 0.25).clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: AppTheme.ink.withValues(alpha: 0.9 * backdrop),
              ),
              if (flash > 0.001)
                ColoredBox(
                  color: AppTheme.convergedBright.withValues(alpha: flash),
                ),
              Center(
                child: Padding(
                  // Vertical room for the rotated glyphs to swing into.
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < _letters.length; i++)
                              _Glyph(
                                character: _letters[i],
                                progress: _letterProgress(t, i),
                                // The bang picks up marigold so the mark still
                                // carries both player colours at the moment
                                // they stop being two.
                                color: _letters[i] == '!'
                                    ? AppTheme.seed
                                    : AppTheme.converged,
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 30 * tail),
                      Opacity(opacity: tail, child: _MatchedWord(widget.word)),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Opacity(
                      opacity: tail,
                      child: Text(
                        'tap to continue',
                        style: TextStyle(
                          fontSize: 11.5,
                          letterSpacing: 1.6,
                          color: AppTheme.parchment.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Where letter [index] is in its own 0..1 pop, given overall progress [t].
  double _letterProgress(double t, int index) =>
      ((t - index * _letterStagger) / _letterPop).clamp(0.0, 1.0);
}

class _Glyph extends StatelessWidget {
  const _Glyph({
    required this.character,
    required this.progress,
    required this.color,
  });

  final String character;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // elasticOut overshoots past its target and rings back, which is what makes
    // the letter feel thrown at the screen rather than faded in.
    final pop = Curves.elasticOut.transform(progress);
    final wobble =
        math.sin(progress * 2 * math.pi * _wobbleCycles) *
        _wobbleAmplitude *
        (1 - progress);

    // Transforms do not affect layout, so the row keeps a constant width and
    // the FittedBox above it never rescales mid-animation.
    return Opacity(
      opacity: (progress * 4).clamp(0.0, 1.0),
      child: Transform.rotate(
        angle: wobble,
        child: Transform.scale(
          scale: 0.3 + 0.7 * pop,
          child: Text(
            character,
            style: TextStyle(
              fontSize: _glyphSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -3,
              height: 1,
              color: color,
              shadows: [
                Shadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 40,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchedWord extends StatelessWidget {
  const _MatchedWord(this.word);

  final String word;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'YOU BOTH SAID',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
            color: AppTheme.parchment.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          word.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w300,
            letterSpacing: 4,
            color: AppTheme.parchment,
          ),
        ),
      ],
    );
  }
}
