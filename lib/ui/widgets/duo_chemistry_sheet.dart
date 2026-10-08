import 'package:flutter/material.dart';

import '../../core/word_utils.dart';
import '../../models/friend.dart';
import '../../state/app_session.dart';
import '../app_theme.dart';
import '../layout.dart';
import '../room_launcher.dart';
import 'create_room_sheet.dart';
import 'section_label.dart';

/// Modal bottom sheet displaying Duo Chemistry stats and the shared Memory Bank
/// of twinned words between two players.
class DuoChemistrySheet extends StatelessWidget {
  const DuoChemistrySheet({
    super.key,
    required this.friend,
    required this.session,
  });

  final Friend friend;
  final AppSession session;

  static Future<void> show(
    BuildContext context, {
    required Friend friend,
    required AppSession session,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.inkRaised,
      constraints: const BoxConstraints(maxWidth: Layout.contentMaxWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DuoChemistrySheet(friend: friend, session: session),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avg = friend.averageRounds;
    final avgStr = avg != null ? avg.toStringAsFixed(1) : '—';
    final bestStr = friend.bestSyncRounds != null
        ? '${friend.bestSyncRounds} ${friend.bestSyncRounds == 1 ? "round" : "rounds"}'
        : '—';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
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
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.seed.withValues(alpha: 0.16),
                    child: Text(
                      friend.name.isEmpty ? '?' : friend.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        color: AppTheme.seed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.parchment,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Duo Chemistry & Memory Bank',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.seed,
                            fontWeight: FontWeight.w500,
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
                    child: _MetricCard(
                      label: 'Best Sync',
                      value: bestStr,
                      detail: friend.bestSyncWord != null
                          ? titleCaseWord(friend.bestSyncWord!)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      label: 'Avg Rounds',
                      value: avgStr,
                      detail: '${friend.gamesPlayed} games',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      label: 'Twinned',
                      value: '${friend.twinnedCount}',
                      detail: 'total syncs',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionLabel('Memory Bank'),
              const SizedBox(height: 8),
              Text(
                'Words you and ${friend.name} converged on together.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.parchment.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 14),
              if (friend.memoryBank.isEmpty)
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
                    'No shared memories yet.\nPlay a game to log your first sync.',
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
                    for (final word in friend.memoryBank)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.inkCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.converged.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.all_inclusive_rounded,
                              size: 13,
                              color: AppTheme.converged,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              titleCaseWord(word),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.parchment,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final config = await CreateRoomSheet.show(context);
                  if (config == null || !context.mounted) return;
                  RoomLauncher.inviteFriendAndOpen(
                    context,
                    session,
                    friend.id,
                    config: config,
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Play with ${friend.name}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
