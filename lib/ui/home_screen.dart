import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/game_config.dart';
import '../models/friend.dart';
import '../models/game_invite.dart';
import '../services/daily_twin_service.dart';
import '../services/room_code.dart';
import '../state/app_session.dart';
import 'app_theme.dart';
import 'layout.dart';
import 'room_launcher.dart';
import 'widgets/brand_mark.dart';
import 'widgets/create_room_sheet.dart';
import 'widgets/duo_chemistry_sheet.dart';
import 'widgets/lifetime_stats_sheet.dart';
import 'widgets/section_label.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();

    return Scaffold(
      body: SafeArea(
        child: PageShell(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
            children: [
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const BrandMark(),
                  IconButton(
                    tooltip: 'Lifetime Stats',
                    icon: const Icon(
                      Icons.insights_rounded,
                      color: AppTheme.seed,
                    ),
                    onPressed: () => LifetimeStatsSheet.show(context),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _PlayerProfileTile(session: session),
              if (session.backendFallbackReason != null) ...[
                const SizedBox(height: 16),
                _OfflineNotice(message: session.backendFallbackReason!),
              ],
              const SizedBox(height: 20),
              _DailyTwinCard(session: session),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final config = await CreateRoomSheet.show(context);
                        if (config == null || !context.mounted) return;
                        await RoomLauncher.createAndOpen(
                          context,
                          session,
                          config: config,
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Create room'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showJoinSheet(context, session),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('Join room'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _InviteList(session: session),
              _FriendList(session: session),
              const SizedBox(height: 24),
              const _HowItWorks(),
            ],
          ),
        ),
      ),
    );
  }

  static void _showJoinSheet(BuildContext context, AppSession session) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.inkRaised,
      constraints: const BoxConstraints(maxWidth: Layout.contentMaxWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _JoinSheet(session: session),
    );
  }
}

class _PlayerProfileTile extends StatelessWidget {
  const _PlayerProfileTile({required this.session});

  final AppSession session;

  static void _showEditName(BuildContext context, AppSession session) {
    final controller = TextEditingController(text: session.displayName);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.inkRaised,
      constraints: const BoxConstraints(maxWidth: Layout.contentMaxWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Your display name'),
            const SizedBox(height: 8),
            Text(
              'How your name appears to friends and on shared results.',
              style: TextStyle(
                color: AppTheme.parchment.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              maxLength: 20,
              onSubmitted: (val) {
                final trimmed = val.trim();
                if (trimmed.isNotEmpty) {
                  session.setDisplayName(trimmed);
                }
                Navigator.of(sheetContext).pop();
              },
              decoration: const InputDecoration(
                hintText: 'Your name',
                counterText: '',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isNotEmpty) {
                  session.setDisplayName(trimmed);
                }
                Navigator.of(sheetContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = session.displayName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return InkWell(
      onTap: () => _showEditName(context, session),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.inkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.seed.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.seed.withValues(alpha: 0.16),
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppTheme.seed,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.parchment,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Tap to edit display name',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.parchment.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_outlined,
              size: 16,
              color: AppTheme.parchment.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.inkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.seed.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: AppTheme.seed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppTheme.parchment.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinSheet extends StatefulWidget {
  const _JoinSheet({required this.session});

  final AppSession session;

  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final problem = RoomCode.validationError(_controller.text);
    setState(() => _error = problem);
    if (problem != null) return;
    Navigator.of(context).pop();
    RoomLauncher.joinAndOpen(context, widget.session, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Join a room'),
          const SizedBox(height: 8),
          Text(
            'Enter the ${RoomCode.length}-character code your friend shared.',
            style: TextStyle(
              color: AppTheme.parchment.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            maxLength: RoomCode.length,
            style: const TextStyle(
              fontSize: 30,
              letterSpacing: 12,
              fontWeight: FontWeight.w600,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              _UpperCaseFormatter(),
            ],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              counterText: '',
              hintText: '- - - - -',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _submit, child: const Text('Join')),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _InviteList extends StatelessWidget {
  const _InviteList({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GameInvite>>(
      stream: session.backend.watchInvites(),
      builder: (context, snapshot) {
        final invites = snapshot.data ?? const <GameInvite>[];
        if (invites.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Waiting for you'),
            const SizedBox(height: 12),
            for (final invite in invites)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: const Icon(
                      Icons.mark_email_unread_outlined,
                      color: AppTheme.seed,
                    ),
                    title: Text('${invite.fromName} started a game'),
                    subtitle: Text(
                      'Room ${invite.roomCode}',
                      style: TextStyle(
                        color: AppTheme.parchment.withValues(alpha: 0.55),
                      ),
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Dismiss',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              session.backend.dismissInvite(invite.roomCode),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(64, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          onPressed: () {
                            session.backend.dismissInvite(invite.roomCode);
                            RoomLauncher.joinAndOpen(
                              context,
                              session,
                              invite.roomCode,
                            );
                          },
                          child: const Text('Play'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _FriendList extends StatelessWidget {
  const _FriendList({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Friend>>(
      stream: session.friends,
      builder: (context, snapshot) {
        final friends = snapshot.data ?? const <Friend>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Friends'),
            const SizedBox(height: 12),
            if (friends.isEmpty)
              Text(
                'Anyone you finish a connection with shows up here, so the next '
                'game needs no code.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppTheme.parchment.withValues(alpha: 0.5),
                ),
              )
            else
              for (final friend in friends)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      onTap: () => DuoChemistrySheet.show(
                        context,
                        friend: friend,
                        session: session,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.seed.withValues(alpha: 0.16),
                        child: Text(
                          friend.name.isEmpty
                              ? '?'
                              : friend.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.seed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(friend.name),
                      subtitle: Text(
                        _subtitleFor(friend),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.parchment.withValues(alpha: 0.5),
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Start a game',
                        icon: const Icon(Icons.play_arrow_rounded),
                        onPressed: () async {
                          final config = await CreateRoomSheet.show(context);
                          if (config == null || !context.mounted) return;
                          RoomLauncher.inviteFriendAndOpen(
                            context,
                            session,
                            friend.id,
                            config: config,
                          );
                        },
                      ),
                      onLongPress: () => _confirmForget(context, friend),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  String _subtitleFor(Friend friend) {
    final parts = <String>[];
    final games = friend.gamesPlayed;
    parts.add('$games ${games == 1 ? "game" : "games"}');
    if (friend.bestSyncRounds != null) {
      parts.add('Best: ${friend.bestSyncRounds}r');
    }
    if (friend.averageRounds != null) {
      parts.add('Avg: ${friend.averageRounds!.toStringAsFixed(1)}r');
    }
    if (friend.memoryBank.isNotEmpty) {
      parts.add('${friend.memoryBank.length} twinned');
    }
    if (friend.lastPlayedAt != null) {
      parts.add(_relative(friend.lastPlayedAt!));
    }
    return parts.join(' · ');
  }

  static String _relative(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  void _confirmForget(BuildContext context, Friend friend) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.inkCard,
        title: Text('Remove ${friend.name}?'),
        content: const Text(
          'You will need a room code to play together again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              session.backend.forgetFriend(friend.id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      'You both type a word in private.',
      'Both words are revealed at the same time.',
      'Now aim for a word in between the two. So do they.',
      'Keep going until you both type the same word. Then you have won '
          'together.',
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.inkRaised,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('How it works'),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: AppTheme.seed.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppTheme.parchment.withValues(alpha: 0.62),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DailyTwinCard extends StatefulWidget {
  const _DailyTwinCard({required this.session});

  final AppSession session;

  @override
  State<_DailyTwinCard> createState() => _DailyTwinCardState();
}

class _DailyTwinCardState extends State<_DailyTwinCard> {
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

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) {
      return const SizedBox.shrink();
    }

    final puzzle = status.puzzle;
    final hours = puzzle.timeRemaining.inHours;
    final minutes = puzzle.timeRemaining.inMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.inkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: status.isCompletedToday
              ? AppTheme.converged.withValues(alpha: 0.35)
              : AppTheme.seed.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.seed.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.wb_sunny_rounded,
                      size: 16,
                      color: AppTheme.seed,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'The Daily Twin #${puzzle.puzzleNumber}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.parchment,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.seed.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 14,
                      color: AppTheme.seed,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${status.currentStreak} day streak',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.seed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            status.isCompletedToday
                ? 'Completed today! Resets in ${hours}h ${minutes}m.'
                : 'Can you bridge today\'s global anchor pair? Resets in ${hours}h ${minutes}m.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppTheme.parchment.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: status.isCompletedToday
                  ? AppTheme.inkRaised
                  : AppTheme.seed,
              foregroundColor: status.isCompletedToday
                  ? AppTheme.parchment.withValues(alpha: 0.8)
                  : AppTheme.ink,
            ),
            onPressed: () async {
              final config = GameConfig(
                startWordA: puzzle.startWordA,
                startWordB: puzzle.startWordB,
                theme: 'The Daily Twin',
              );
              await RoomLauncher.createAndOpen(
                context,
                widget.session,
                config: config,
              );
              _load();
            },
            icon: Icon(
              status.isCompletedToday
                  ? Icons.check_circle_outline_rounded
                  : Icons.play_arrow_rounded,
              size: 18,
            ),
            label: Text(
              status.isCompletedToday
                  ? 'Play again (${puzzle.startWordA} ↔ ${puzzle.startWordB})'
                  : 'Play Daily Challenge',
            ),
          ),
        ],
      ),
    );
  }
}

