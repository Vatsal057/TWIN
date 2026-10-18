import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/game_config.dart';
import '../app_theme.dart';
import '../layout.dart';

enum _PlayMode { classic, category, customPair }

/// Strictly 2-player match creator matching the redesigned dark aesthetic.
///
/// Lets the host configure the match mode (Classic, Category, or Custom Pair)
/// and round limits, then creates a real multiplayer room with an invite link.
class CreateRoomSheet extends StatefulWidget {
  const CreateRoomSheet({super.key, this.initial = GameConfig.defaults});

  final GameConfig initial;

  /// Returns the chosen [GameConfig], or null if dismissed.
  static Future<GameConfig?> show(
    BuildContext context, {
    GameConfig initial = GameConfig.defaults,
  }) {
    return showModalBottomSheet<GameConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.navy900,
      constraints: const BoxConstraints(maxWidth: Layout.contentMaxWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => CreateRoomSheet(initial: initial),
    );
  }

  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  late _PlayMode _mode;
  late int? _limit;
  String _selectedTheme = GameConfig.curatedCategories.first;

  late final TextEditingController _wordAController;
  late final TextEditingController _wordBController;
  String? _customError;

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
    _limit = widget.initial.maxRounds;

    if (widget.initial.hasCustomStart) {
      _mode = _PlayMode.customPair;
      _wordAController = TextEditingController(text: widget.initial.startWordA ?? '');
      _wordBController = TextEditingController(text: widget.initial.startWordB ?? '');
    } else if (widget.initial.hasTheme) {
      _mode = _PlayMode.category;
      _selectedTheme = widget.initial.theme ?? GameConfig.curatedCategories.first;
      _wordAController = TextEditingController();
      _wordBController = TextEditingController();
    } else {
      _mode = _PlayMode.classic;
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
    HapticFeedback.lightImpact();
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

    if (_mode == _PlayMode.customPair) {
      final a = _wordAController.text.trim();
      final b = _wordBController.text.trim();
      if (a.isEmpty || b.isEmpty) {
        setState(() {
          _customError = 'Enter both starting words to challenge your friend.';
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
    } else if (_mode == _PlayMode.category) {
      theme = _selectedTheme;
      if (theme == 'Abstract / Hardcore') {
        final pair = GameConfig.abstractPairs[
          Random().nextInt(GameConfig.abstractPairs.length)
        ];
        startA = pair.$1;
        startB = pair.$2;
      }
    }

    HapticFeedback.mediumImpact();
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
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pull handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title row with close icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Start new match',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Mode Section
              Text(
                'GAME MODE',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: AppTheme.mist,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ModeSelectionCard(
                      title: 'Classic',
                      subtitle: 'Open play',
                      icon: Icons.all_inclusive_rounded,
                      selected: _mode == _PlayMode.classic,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _mode = _PlayMode.classic;
                          _customError = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModeSelectionCard(
                      title: 'Category',
                      subtitle: 'Themed',
                      icon: Icons.category_rounded,
                      selected: _mode == _PlayMode.category,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _mode = _PlayMode.category;
                          _customError = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModeSelectionCard(
                      title: 'Custom',
                      subtitle: 'Set words',
                      icon: Icons.compare_arrows_rounded,
                      selected: _mode == _PlayMode.customPair,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _mode = _PlayMode.customPair;
                          if (_wordAController.text.isEmpty && _wordBController.text.isEmpty) {
                            _pickSurprisePair();
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Dynamic mode body
              if (_mode == _PlayMode.classic) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppTheme.lime, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Anything goes! You and your friend both type any secret word in Round 1 to start.',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mist,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_mode == _PlayMode.category) ...[
                Text(
                  'CATEGORY THEME',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                    color: AppTheme.mist,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final theme in GameConfig.curatedCategories)
                      _PillChip(
                        label: theme,
                        selected: _selectedTheme == theme,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTheme = theme);
                        },
                      ),
                  ],
                ),
              ] else if (_mode == _PlayMode.customPair) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'STARTING WORDS',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        color: AppTheme.mist,
                      ),
                    ),
                    InkWell(
                      onTap: _pickSurprisePair,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.lime.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.lime.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shuffle_rounded, size: 13, color: AppTheme.lime),
                            const SizedBox(width: 5),
                            Text(
                              'Surprise pair',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.lime,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _wordAController,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Word A',
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mist.withValues(alpha: 0.6),
                          ),
                          filled: true,
                          fillColor: AppTheme.navy950,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppTheme.lime.withValues(alpha: 0.6), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'vs',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.mist,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _wordBController,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Word B',
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mist.withValues(alpha: 0.6),
                          ),
                          filled: true,
                          fillColor: AppTheme.navy950,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppTheme.coral.withValues(alpha: 0.6), width: 1.5),
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
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.coral,
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 24),

              // Round limit Section
              Text(
                'ROUND LIMIT',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: AppTheme.mist,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final limit in GameConfig.presetLimits)
                    _PillChip(
                      label: GameConfig.labelForLimit(limit),
                      selected: _limit == limit,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _limit = limit);
                      },
                    ),
                ],
              ),

              const SizedBox(height: 28),

              // Submit Button: strictly 2 players invite flow
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.lime,
                  foregroundColor: AppTheme.navy950,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.link_rounded, size: 22, color: AppTheme.navy950),
                    const SizedBox(width: 8),
                    Text(
                      'Create match & invite friend',
                      style: GoogleFonts.outfit(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.navy950,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Generates an invite link and 5-letter room code for your friend.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mist.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeSelectionCard extends StatelessWidget {
  const _ModeSelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.lime.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.lime : Colors.white.withValues(alpha: 0.10),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? AppTheme.lime : Colors.white70,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: selected ? AppTheme.lime : Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: selected ? AppTheme.lime.withValues(alpha: 0.8) : AppTheme.mist,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.lime : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.lime : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: selected ? AppTheme.navy950 : AppTheme.mist,
          ),
        ),
      ),
    );
  }
}
