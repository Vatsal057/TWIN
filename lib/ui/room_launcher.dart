import 'package:flutter/material.dart';

import '../core/game_config.dart';
import '../models/room.dart';
import '../services/backend/game_backend.dart';
import '../services/room_code.dart';
import '../state/app_session.dart';
import 'app_theme.dart';
import 'room_page.dart';

/// Create/join plumbing shared by the home screen, the friends list and
/// incoming deep links, so all three enter a room the same way.
class RoomLauncher {
  RoomLauncher._();

  static Future<void> createAndOpen(
    BuildContext context,
    AppSession session, {
    GameConfig config = GameConfig.defaults,
  }) async {
    await _run(
      context,
      () => session.backend.createRoom(config: config),
      onError: 'Could not create a room.',
    );
  }

  static Future<void> quickPlayAndOpen(
    BuildContext context,
    AppSession session, {
    GameConfig config = GameConfig.defaults,
  }) async {
    await _run(
      context,
      () => session.backend.findOrCreateQuickPlayRoom(config: config),
      onError: 'Could not matchmake a game.',
    );
  }

  static Future<void> joinAndOpen(
    BuildContext context,
    AppSession session,
    String rawCode,
  ) async {
    final code = RoomCode.normalize(rawCode);
    final problem = RoomCode.validationError(code);
    if (problem != null) {
      _toast(context, problem);
      return;
    }

    await _ensureDisplayName(context, session);
    if (!context.mounted) return;

    await _run(
      context,
      () => session.backend.joinRoom(code),
      onError: 'Could not join that room.',
    );
  }

  static Future<void> _ensureDisplayName(
    BuildContext context,
    AppSession session,
  ) async {
    if (session.displayName != 'Player') return;

    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.inkRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Join TWIN Challenge',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.parchment,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'What should your friend call you?',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.parchment.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                maxLength: 24,
                decoration: const InputDecoration(
                  hintText: 'Your name',
                  counterText: '',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                onSubmitted: (val) {
                  final trimmed = val.trim();
                  if (trimmed.isNotEmpty) {
                    session.setDisplayName(trimmed);
                  }
                  Navigator.of(sheetContext).pop();
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Play as Guest'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final trimmed = controller.text.trim();
                        if (trimmed.isNotEmpty) {
                          session.setDisplayName(trimmed);
                        }
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> inviteFriendAndOpen(
    BuildContext context,
    AppSession session,
    String friendId, {
    GameConfig config = GameConfig.defaults,
  }) async {
    await _run(
      context,
      () => session.backend.inviteFriend(friendId: friendId, config: config),
      onError: 'Could not send that invite.',
    );
  }

  static void open(BuildContext context, String code) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RoomPage(roomCode: code)));
  }

  static Future<void> _run(
    BuildContext context,
    Future<Room> Function() action, {
    required String onError,
  }) async {
    final navigator = Navigator.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    // The barrier is not dismissible, so exactly one pop closes it and we never
    // risk popping the page underneath.
    var barrierOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );

    void closeBarrier() {
      if (!barrierOpen) return;
      barrierOpen = false;
      rootNavigator.pop();
    }

    try {
      final room = await action();
      closeBarrier();
      navigator.push(
        MaterialPageRoute(builder: (_) => RoomPage(roomCode: room.code)),
      );
    } catch (error) {
      closeBarrier();
      // Show what actually went wrong. A bare "could not create a room" hides
      // whether it was the network, the session, or undeployed rules.
      final message = error is BackendException
          ? error.message
          : '$onError\n$error';
      messenger.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
      );
    }
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
