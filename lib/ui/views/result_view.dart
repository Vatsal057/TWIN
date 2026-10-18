import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/room.dart';
import '../../state/app_session.dart';
import '../../state/game_controller.dart';
import '../app_theme.dart';
import '../room_launcher.dart';
import '../widgets/victory_card.dart';

/// Victory / Game Over screen, wearing the same design as the
/// victory card: rays and confetti over navy, the two players' faces
/// with the rings glyph between them, the heavy TWINNING headline,
/// the matched word on the lime slab, and the guesses panel holding
/// every round (it scrolls; the card shows only the bookends).
/// Actions are Rematch and Share Victory Card, plus the close icon;
/// the text recap and Back to games are gone.
class ResultView extends StatefulWidget {
  const ResultView({super.key});

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView>
    with TickerProviderStateMixin {
  final _facesKey = GlobalKey();
  final _raysKey = GlobalKey();
  final _scrollController = ScrollController();
  Offset? _ringsFocal;
  bool _measureQueued = false;

  /// The confetti pieces fly out of the rings icon when the screen
  /// opens, then keep drifting gently for as long as it stays open.
  late final AnimationController _confettiBurst;
  late final AnimationController _confettiFloat;
  bool _burstStarted = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_queueMeasure);
    _confettiBurst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _confettiFloat = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reduceMotion = MediaQuery.of(context).disableAnimations;
      if (_reduceMotion) {
        _confettiBurst.value = 1;
        _burstStarted = true;
      } else {
        _confettiFloat.repeat();
        // Safety net: if the rings measurement has not landed within
        // half a second, fly the pieces out from the fallback point.
        Future.delayed(const Duration(milliseconds: 500), _startBurst);
      }
    });
  }

  @override
  void dispose() {
    _confettiBurst.dispose();
    _confettiFloat.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startBurst() {
    if (_burstStarted || !mounted) return;
    _burstStarted = true;
    if (_reduceMotion) {
      _confettiBurst.value = 1;
    } else {
      _confettiBurst.forward();
    }
  }

  void _queueMeasure() {
    if (_measureQueued) return;
    _measureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureQueued = false;
      _measureRings();
    });
  }

  /// The background rays pour out of the rings glyph between the faces.
  /// The content column is centred, so where the rings land depends on
  /// the screen height, the rematch banner and how tall the guesses
  /// panel is; measure the faces header after layout and hand its
  /// centre to the painter instead of guessing a fixed point.
  void _measureRings() {
    if (!mounted) return;
    final faces = _facesKey.currentContext?.findRenderObject();
    final rays = _raysKey.currentContext?.findRenderObject();
    if (faces is! RenderBox || rays is! RenderBox) return;
    if (!faces.hasSize || !rays.hasSize) return;
    // Centre of the rings glyph in header coordinates: horizontally
    // centred, 32.3 down, level with the middle of the 64px avatars.
    final ringsGlobal = faces.localToGlobal(
      Offset(faces.size.width / 2, 32.3),
    );
    final focal = rays.globalToLocal(ringsGlobal);
    if (_ringsFocal == null || (focal - _ringsFocal!).distance > 0.5) {
      setState(() => _ringsFocal = focal);
    }
    _startBurst();
  }

  @override
  Widget build(BuildContext context) {
    _queueMeasure();
    final game = context.watch<GameController>();
    final room = game.room;
    if (room == null) return const SizedBox.shrink();

    final converged = room.converged;
    final abandoned = room.finishReason == FinishReason.abandoned;
    final lastRound = room.lastRound;
    final roundsCount = room.rounds.length;
    final localIsP1 = game.localPlayerId == room.p1Id;

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
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              key: _raysKey,
              painter: TwinRaysPainter(focal: _ringsFocal, fullBurst: true),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_confettiBurst, _confettiFloat]),
              builder: (context, _) => CustomPaint(
                painter: TwinConfettiPainter(
                  burst: _confettiBurst.value,
                  burstOrigin: _ringsFocal,
                  floatPhase: _confettiFloat.value,
                  drift: 1,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Rematch request banner from opponent
                      if (room.rematchRoomCode case final rematchCode?) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.lime.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppTheme.lime.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.replay_rounded,
                                color: AppTheme.lime,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${game.opponentName} wants a rematch!',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              FilledButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  RoomLauncher.joinAndOpen(
                                    context,
                                    context.read<AppSession>(),
                                    rematchCode,
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.lime,
                                  foregroundColor: AppTheme.navy950,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  'Accept',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Faces, headline, matched word
                      TwinFacesHeader(
                        key: _facesKey,
                        localName: game.localName,
                        opponentName: game.opponentName,
                        localAvatarId:
                            context.read<AppSession>().profileAvatarId,
                        opponentAvatarId: room.avatarOf(game.opponentId),
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

                      // Every round, scrollable inside the panel
                      if (room.rounds.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        GuessesPanelShell(
                          localName: game.localName,
                          opponentName: game.opponentName,
                          child: _ScrollableRounds(
                            room: room,
                            localIsP1: localIsP1,
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),

                      // Rematch CTA
                      if (room.rematchRoomCode case final rematchCode?)
                        FilledButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).pop();
                            RoomLauncher.joinAndOpen(
                              context,
                              context.read<AppSession>(),
                              rematchCode,
                            );
                          },
                          icon: const Icon(Icons.replay_rounded, size: 19),
                          label: Text(
                            'Join rematch $rematchCode',
                            style: GoogleFonts.outfit(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.lime,
                            foregroundColor: AppTheme.navy950,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                        )
                      else
                        FilledButton.icon(
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            final fresh = await game.startRematch();
                            if (fresh == null || !context.mounted) return;
                            Navigator.of(context).pop();
                            RoomLauncher.open(context, fresh.code);
                          },
                          icon: const Icon(Icons.replay_rounded, size: 19),
                          label: Text(
                            'Rematch',
                            style: GoogleFonts.outfit(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.lime,
                            foregroundColor: AppTheme.navy950,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                        ),

                      const SizedBox(height: 11),

                      // Share Victory Card (9:16 export)
                      FilledButton.tonalIcon(
                        onPressed: () => VictoryCardSheet.show(
                          context,
                          room: room,
                          localName: game.localName,
                          opponentName: game.opponentName,
                          localIsP1: localIsP1,
                        ),
                        icon: const Icon(
                          Icons.image_outlined,
                          size: 20,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Share Victory Card',
                          style: GoogleFonts.outfit(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF171733),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The full round list inside the guesses panel. Capped at about
/// four rows tall; longer games scroll, with a fade at the bottom
/// edge and the matched row waiting at the end of the scroll.
class _ScrollableRounds extends StatefulWidget {
  const _ScrollableRounds({required this.room, required this.localIsP1});

  final Room room;
  final bool localIsP1;

  @override
  State<_ScrollableRounds> createState() => _ScrollableRoundsState();
}

class _ScrollableRoundsState extends State<_ScrollableRounds> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rounds = widget.room.rounds;
    final localIsP1 = widget.localIsP1;
    final contentHeight = rounds.length * 34.0 + (rounds.length - 1) * 8.0;
    final scrollable = contentHeight > 184;
    final height = scrollable ? 184.0 : contentHeight;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Scrollbar(
            controller: _controller,
            thumbVisibility: scrollable,
            child: ListView.separated(
              controller: _controller,
              itemCount: rounds.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final round = rounds[index];
                return GuessRow(
                  localWord: localIsP1 ? round.p1Word : round.p2Word,
                  opponentWord: localIsP1 ? round.p2Word : round.p1Word,
                  matched: round.matched,
                );
              },
            ),
          ),
          if (scrollable)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.navy950.withValues(alpha: 0),
                        AppTheme.navy950.withValues(alpha: 0.96),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
