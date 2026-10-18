import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/word_utils.dart';
import '../../state/app_session.dart';
import 'reference_word_sticker.dart';

/// The two words with giant tilted stickers and the organic bead chain bridge,
/// exactly matching reference Screenshot 2 (e.g. OCEAN & DESERT with dotted bridge).
class AnchorPair extends StatelessWidget {
  const AnchorPair({
    super.key,
    required this.leftWord,
    required this.rightWord,
    required this.leftIsPlayerOne,
  });

  final String leftWord;
  final String rightWord;
  final bool leftIsPlayerOne;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppSession>().palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Scale the whole row down on narrow phones instead of letting
          // the cards overflow or squeeze, so the proportions stay exactly
          // as designed at any screen width.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              // Left Word Sticker (Lime, tilted -10deg as in the reference)
              Transform.translate(
                offset: const Offset(0, -8),
                child: WordSticker(
                  word: titleCaseWord(leftWord),
                  tone: WordTone.lime,
                  rotate: -10,
                  isLarge: true,
                ),
              ),

              // Dotted Bead Chain Bridge, raised so the bead cluster sits
              // in the upper gap between the cards like the reference: the
              // first bead is level with the lime card's top edge and the
              // last bead lands at the coral card's middle.
              Transform.translate(
                offset: const Offset(0, -18),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: DottedChainBridge(),
                ),
              ),

              // Right Word Sticker (Coral, tilted 10deg, centre 23 below
              // the lime card's centre as in the reference)
              Transform.translate(
                offset: const Offset(0, 15),
                child: WordSticker(
                  word: titleCaseWord(rightWord),
                  tone: WordTone.coral,
                  rotate: 10,
                  isLarge: true,
                ),
              ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'Find the word between them',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: p.muted,
            ),
          ),
        ],
      ),
    );
  }
}
