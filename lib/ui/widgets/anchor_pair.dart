import 'package:flutter/material.dart';

import '../../core/word_utils.dart';
import '../app_theme.dart';

/// The two words from the previous round with the target sitting between them.
/// This is the whole instruction for the round, so it gets the most space.
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.inkCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _Word(
                  word: leftWord,
                  color: AppTheme.colorForSlot(leftIsPlayerOne),
                  align: TextAlign.left,
                ),
              ),
              const _Midpoint(),
              Expanded(
                child: _Word(
                  word: rightWord,
                  color: AppTheme.colorForSlot(!leftIsPlayerOne),
                  align: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'now both aim for something in between',
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 1.4,
              color: AppTheme.parchment.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({required this.word, required this.color, required this.align});

  final String word;
  final Color color;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      titleCaseWord(word),
      textAlign: align,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color,
      ),
    );
  }
}

class _Midpoint extends StatelessWidget {
  const _Midpoint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 1,
            color: AppTheme.parchment.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 6),
          Icon(
            Icons.adjust_rounded,
            size: 16,
            color: AppTheme.parchment.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 6),
          Container(
            width: 34,
            height: 1,
            color: AppTheme.parchment.withValues(alpha: 0.18),
          ),
        ],
      ),
    );
  }
}
