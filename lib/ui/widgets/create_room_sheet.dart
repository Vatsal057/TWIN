import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/game_config.dart';
import '../app_theme.dart';
import '../layout.dart';
import 'section_label.dart';

enum _PlayStyle { classic, themed, custom }

/// Host-side game settings, asked once before the room exists.
///
/// Lets the host set the game (classic free play, themed categories, or custom
/// starter pairs) and round limits.
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
  _PlayStyle _style = _PlayStyle.classic;
  String? _selectedTheme;
  late final TextEditingController _wordAController;
  late final TextEditingController _wordBController;
  String? _customError;

  static const _themes = GameConfig.curatedCategories;

  static const _surprisePairs = <(String, String)>[
    ('Coffee', 'Sleep'),
    ('Sun', 'Moon'),
    ('Pizza', 'Burger'),
    ('Fire', 'Water'),
    ('Doctor', 'Alien'),
    ('Batman', 'Spider-Man'),
    ('Summer', 'Winter'),
    ('Music', 'Silence'),
    ('Cat', 'Dog'),
    ('Sword', 'Shield'),
    ...GameConfig.abstractPairs,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initial.hasCustomStart) {
      _style = _PlayStyle.custom;
      _wordAController = TextEditingController(
        text: widget.initial.startWordA ?? '',
      );
      _wordBController = TextEditingController(
        text: widget.initial.startWordB ?? '',
      );
    } else if (widget.initial.hasTheme) {
      _style = _PlayStyle.themed;
      _selectedTheme = widget.initial.theme;
      _wordAController = TextEditingController();
      _wordBController = TextEditingController();
    } else {
      _style = _PlayStyle.classic;
      _wordAController = TextEditingController();
      _wordBController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _wordAController.dispose();
    _wordBController.dispose();
    super.dispose();
  }

  void _pickSurprisePair() {
    final random = Random();
    final pair = _surprisePairs[random.nextInt(_surprisePairs.length)];
    setState(() {
      _wordAController.text = pair.$1;
      _wordBController.text = pair.$2;
      _customError = null;
    });
  }

  void _submit() {
    String? startA;
    String? startB;
    String? theme;

    if (_style == _PlayStyle.custom) {
      final a = _wordAController.text.trim();
      final b = _wordBController.text.trim();
      if (a.isEmpty || b.isEmpty) {
        setState(() {
          _customError = 'Enter both words for the challenge.';
        });
        return;
      }
      if (a.toLowerCase() == b.toLowerCase()) {
        setState(() {
          _customError = 'Words cannot be identical.';
        });
        return;
      }
      startA = a;
      startB = b;
    } else if (_style == _PlayStyle.themed) {
      theme = _selectedTheme ?? _themes.first;
      if (theme == 'Abstract / Hardcore') {
        final pair = GameConfig.abstractPairs[
          Random().nextInt(GameConfig.abstractPairs.length)
        ];
        startA = pair.$1;
        startB = pair.$2;
      }
    }

    final config = widget.initial.copyWith(
      maxRounds: _limit,
      startWordA: startA,
      startWordB: startB,
      theme: theme,
    );

    Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomInset),
        child: SingleChildScrollView(
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
              const SizedBox(height: 20),
              const SectionLabel('Mode'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ModeChip(
                      label: 'Classic',
                      icon: Icons.all_inclusive_rounded,
                      selected: _style == _PlayStyle.classic,
                      onTap: () => setState(() {
                        _style = _PlayStyle.classic;
                        _customError = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModeChip(
                      label: 'Category',
                      icon: Icons.grid_view_rounded,
                      selected: _style == _PlayStyle.themed,
                      onTap: () => setState(() {
                        _style = _PlayStyle.themed;
                        _selectedTheme ??= _themes.first;
                        _customError = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModeChip(
                      label: 'Custom Pair',
                      icon: Icons.compare_arrows_rounded,
                      selected: _style == _PlayStyle.custom,
                      onTap: () {
                        setState(() => _style = _PlayStyle.custom);
                        if (_wordAController.text.isEmpty &&
                            _wordBController.text.isEmpty) {
                          _pickSurprisePair();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_style == _PlayStyle.themed) ...[
                const SectionLabel('Category'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final theme in _themes)
                      _Choice(
                        label: theme,
                        selected: _selectedTheme == theme,
                        onTap: () => setState(() => _selectedTheme = theme),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ] else if (_style == _PlayStyle.custom) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SectionLabel('Starting pair'),
                    TextButton.icon(
                      onPressed: _pickSurprisePair,
                      icon: const Icon(Icons.shuffle_rounded, size: 16),
                      label: const Text('Surprise pair'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _wordAController,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 25,
                        decoration: const InputDecoration(
                          hintText: 'Word 1',
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '·',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.parchment.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _wordBController,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 25,
                        decoration: const InputDecoration(
                          hintText: 'Word 2',
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_customError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _customError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.seed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
              ],
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
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.rocket_launch_rounded),
                label: const Text('Start challenge'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.seed.withValues(alpha: 0.18)
          : AppTheme.inkCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppTheme.seed
                  : AppTheme.parchment.withValues(alpha: 0.12),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? AppTheme.seed
                    : AppTheme.parchment.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppTheme.seed
                      : AppTheme.parchment.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              fontSize: 13,
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
