import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/friend.dart';
import '../models/game_invite.dart';
import '../services/room_code.dart';
import '../state/app_session.dart';
import 'app_theme.dart';
import 'layout.dart';
import 'room_launcher.dart';
import 'widgets/brand_mark.dart';
import 'widgets/create_room_sheet.dart';
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
              const BrandMark(),
              const SizedBox(height: 36),
              _PlayerNameField(session: session),
              if (session.backendFallbackReason != null) ...[
                const SizedBox(height: 16),
                _OfflineNotice(message: session.backendFallbackReason!),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () async {
                  final config = await CreateRoomSheet.show(context);
                  if (config == null || !context.mounted) return;
                  await RoomLauncher.createAndOpen(
                    context,
                    session,
                    config: config,
                  );
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Create room'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showJoinSheet(context, session),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Join room'),
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

class _PlayerNameField extends StatefulWidget {
  const _PlayerNameField({required this.session});

  final AppSession session;

  @override
  State<_PlayerNameField> createState() => _PlayerNameFieldState();
}

class _PlayerNameFieldState extends State<_PlayerNameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.session.displayName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      maxLength: 20,
      onSubmitted: widget.session.setDisplayName,
      onTapOutside: (_) {
        FocusScope.of(context).unfocus();
        widget.session.setDisplayName(_controller.text);
      },
      decoration: const InputDecoration(
        labelText: 'Your name',
        counterText: '',
        prefixIcon: Icon(Icons.person_outline),
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
    final games = friend.gamesPlayed;
    final plural = games == 1 ? 'game' : 'games';
    final last = friend.lastPlayedAt;
    if (last == null) return '$games $plural';
    return '$games $plural · last ${_relative(last)}';
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
