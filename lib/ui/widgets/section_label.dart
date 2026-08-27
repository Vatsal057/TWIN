import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Small all-caps heading used to separate blocks without drawing boxes.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: AppTheme.parchment.withValues(alpha: 0.6),
      ),
    );
    if (trailing == null) return label;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [label, trailing!],
    );
  }
}
