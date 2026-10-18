import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/word_utils.dart';
import '../../services/stats_service.dart';
import '../app_theme.dart';
import '../layout.dart';

/// Modal bottom sheet displaying personal lifetime stats and frequent bridge words.
class LifetimeStatsSheet extends StatelessWidget {
  const LifetimeStatsSheet({super.key, required this.stats});

  final LifetimeStats stats;

  static Future<void> show(BuildContext context) async {
    final stats = await StatsService.instance.getStats();
    if (!context.mounted) return;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.navy900,
      constraints: const BoxConstraints(maxWidth: Layout.contentMaxWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LifetimeStatsSheet(stats: stats),
    );
  }

  @override
  Widget build(BuildContext context) {
    final winPercent = stats.totalGamesPlayed > 0
        ? '${(stats.convergenceRate * 100).round()}%'
        : '—';
    final avgRoundsStr = stats.totalGamesPlayed > 0
        ? stats.averageRounds.toStringAsFixed(1)
        : '—';
    final fastestStr = stats.fastestConvergenceRounds != null
        ? '${stats.fastestConvergenceRounds} ${stats.fastestConvergenceRounds == 1 ? "round" : "rounds"}'
        : '—';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.lime.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: AppTheme.lime,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lifetime Telepathy Stats',
                          style: GoogleFonts.outfit(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Convergence history & conceptual hubs',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.lime,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'TOTAL TWINS',
                      value: '${stats.totalGamesTwinned}',
                      detail: '$winPercent sync rate',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'FASTEST SYNC',
                      value: fastestStr,
                      detail: 'fewest rounds',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'AVG ROUNDS',
                      value: avgRoundsStr,
                      detail: '${stats.totalGamesPlayed} games',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                'FREQUENT BRIDGE WORDS',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: AppTheme.mist,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your go-to conceptual bridges across all rounds played.',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppTheme.mist,
                ),
              ),
              const SizedBox(height: 14),
              if (stats.topBridgeWords.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.navy950,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    'No words recorded yet.\nPlay a few games to see your semantic hubs.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.mist,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in stats.topBridgeWords)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.navy950,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.lime.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              titleCaseWord(entry.key),
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.lime.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${entry.value}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.lime,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.navy950,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.mist,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.lime,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
