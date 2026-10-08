import 'package:flutter/material.dart';

import '../../core/word_utils.dart';
import '../../services/stats_service.dart';
import '../app_theme.dart';
import '../layout.dart';
import 'section_label.dart';

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
      backgroundColor: AppTheme.inkRaised,
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
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.seed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: AppTheme.seed,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lifetime Telepathy Stats',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.parchment,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Convergence history & conceptual hubs',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.seed,
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
                      label: 'Total Twins',
                      value: '${stats.totalGamesTwinned}',
                      detail: '$winPercent sync rate',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Fastest Sync',
                      value: fastestStr,
                      detail: 'fewest rounds',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Avg Rounds',
                      value: avgRoundsStr,
                      detail: '${stats.totalGamesPlayed} games',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const SectionLabel('Frequent Bridge Words'),
              const SizedBox(height: 6),
              Text(
                'Your go-to conceptual bridges across all rounds played.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.parchment.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 14),
              if (stats.topBridgeWords.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.inkCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.parchment.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    'No words recorded yet.\nPlay a few games to see your semantic hubs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.parchment.withValues(alpha: 0.45),
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
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.inkCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.parchment.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              titleCaseWord(entry.key),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.parchment,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.seed.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${entry.value}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.seed,
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
        color: AppTheme.inkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.parchment.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.parchment.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.parchment,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.seed,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
