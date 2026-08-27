import 'package:flutter/material.dart';

import '../../core/game_config.dart';
import '../app_theme.dart';
import '../layout.dart';
import 'section_label.dart';

/// Host-side game settings, asked once before the room exists.
///
/// The config is written onto the room document, so the guest inherits it and
/// both clients resolve rounds under identical rules.
class CreateRoomSheet extends StatefulWidget {
  const CreateRoomSheet({super.key, this.initial = GameConfig.defaults});

  final GameConfig initial;

  /// Returns the chosen config, or null if dismissed.
  static Future<GameConfig?> show(
    BuildContext context, {
    GameConfig initial = GameConfig.defaults,
  }) {
    return showModalBottomSheet<GameConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.inkRaised,
      // Without this the sheet spans a full desktop monitor.
      constraints: const BoxConstraints(maxWidth: Layout.contentMaxWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CreateRoomSheet(initial: initial),
    );
  }

  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  late int? _limit = widget.initial.maxRounds;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.parchment.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Round limit'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in GameConfig.presetLimits)
                  _Choice(
                    label: GameConfig.labelForLimit(preset),
                    selected: _limit == preset,
                    onTap: () => setState(() => _limit = preset),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _limit == null
                  ? 'Play until you converge. Games only end when you both say '
                        'the same word.'
                  : 'The game ends after $_limit rounds even if you have not '
                        'converged.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppTheme.parchment.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 30),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(widget.initial.copyWith(maxRounds: _limit)),
              child: const Text('Create room'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.seed.withValues(alpha: 0.18)
          : AppTheme.inkCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppTheme.seed
                  : AppTheme.parchment.withValues(alpha: 0.12),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? AppTheme.seed
                  : AppTheme.parchment.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}
