import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../../services/daily_twin_service.dart';
import '../../state/app_session.dart';
import '../../core/game_config.dart';
import '../room_launcher.dart';

/// Redesigned DailyTwinCard matching reference UI:
/// Frosted glass background, glowing lime streak pill, start words box, and action button.
class ReferenceDailyTwinCard extends StatefulWidget {
  const ReferenceDailyTwinCard({super.key, required this.session});

  final AppSession session;

  @override
  State<ReferenceDailyTwinCard> createState() => _ReferenceDailyTwinCardState();
}

class _ReferenceDailyTwinCardState extends State<ReferenceDailyTwinCard> {
  DailyTwinStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await DailyTwinService.instance.getStatus();
    if (mounted) {
      setState(() => _status = status);
    }
  }

  void _playDaily(DailyTwinPuzzle puzzle) {
    RoomLauncher.createAndOpen(
      context,
      widget.session,
      config: GameConfig(
        theme: 'Daily Twin #${puzzle.puzzleNumber}',
        startWordA: puzzle.startWordA,
        startWordB: puzzle.startWordB,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) return const SizedBox.shrink();

    final puzzle = status.puzzle;
    final hours = puzzle.timeRemaining.inHours;
    final minutes = puzzle.timeRemaining.inMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.navy900,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.lime.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row: Sun Icon + Title + Streak Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.lime.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.wb_sunny_rounded,
                      size: 18,
                      color: AppTheme.lime,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The Daily Twin #${puzzle.puzzleNumber}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Global 24h challenge',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.mist,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.lime.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.lime.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 14,
                      color: AppTheme.lime,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${status.currentStreak}d streak',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.lime,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Words Box: OCEAN ··· DESERT + Reset Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.navy950,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.lime,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        puzzle.startWordA.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.navy950,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '···',
                        style: TextStyle(
                          color: AppTheme.mist,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.coral,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        puzzle.startWordB.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.navy950,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${hours}h ${minutes}m left',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mist,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Footer Row: Status desc + Action button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  status.isCompletedToday
                      ? 'Completed today! Back tomorrow.'
                      : 'Find the converging word.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mist,
                  ),
                ),
              ),
              if (status.isCompletedToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.lime.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_rounded, size: 14, color: AppTheme.lime),
                      const SizedBox(width: 4),
                      Text(
                        'Twinned',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.lime,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _playDaily(puzzle),
                  icon: const Icon(Icons.auto_awesome, size: 13, color: AppTheme.navy950),
                  label: Text(
                    'Play today',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.navy950,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.lime,
                    foregroundColor: AppTheme.navy950,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
