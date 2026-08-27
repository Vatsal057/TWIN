import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Wordmark. Two glyphs drifting towards each other, which is the whole game.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spacing = compact ? 4.0 : 8.0;

    return Column(
      children: [
        // letterSpacing trails the final glyph too, which pulls a mark this
        // short visibly left of the dots below it. Nudge it back by the same
        // amount so both rows share one centre line.
        Padding(
          padding: EdgeInsets.only(left: spacing),
          child: Text(
            'TWIN',
            style: TextStyle(
              fontSize: compact ? 18 : 30,
              fontWeight: FontWeight.w300,
              letterSpacing: spacing,
              color: AppTheme.parchment,
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Dot(color: AppTheme.playerOne),
              Container(
                width: 46,
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: AppTheme.parchment.withValues(alpha: 0.25),
              ),
              _Dot(color: AppTheme.playerTwo),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'two minds, one word',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 2.4,
              color: AppTheme.parchment.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
