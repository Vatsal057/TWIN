import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/game_config.dart';
import '../models/room.dart';
import '../services/backend/game_backend.dart';
import '../services/room_code.dart';
import '../services/stats_service.dart';
import '../state/app_session.dart';
import 'app_theme.dart';
import 'room_page.dart';
import 'widgets/settings_sheet.dart';

/// Create/join plumbing shared by the home screen, the friends list and
/// incoming deep links, so all three enter a room the same way.
class RoomLauncher {
  RoomLauncher._();

  /// Guards against a double-tap firing create/join twice while one
  /// launch action is still running. Held only for the action itself,
  /// never for the room page's lifetime: the rematch flow pops the old
  /// page and launches the new room in the same tap.
  static bool _launching = false;

  /// Room code whose page is currently open via [open], so a double-tap
  /// on a History row cannot stack two pages for the same room.
  static String? _openCode;

  static Future<void> createAndOpen(
    BuildContext context,
    AppSession session, {
    GameConfig config = GameConfig.defaults,
  }) async {
    final proceed = await _ensureProfile(context, session);
    if (!proceed || !context.mounted) return;

    await _run(
      context,
      () => session.backend.createRoom(config: config),
      onError: 'Could not create a room.',
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

    final proceed = await _ensureProfile(context, session);
    if (!proceed || !context.mounted) return;

    await _run(
      context,
      () => session.backend.joinRoom(code),
      onError: 'Could not join that room.',
    );
  }

  /// Every create and join lands here first. A player who has never set
  /// a name or picked an avatar is suggested to set the profile up before
  /// the game starts, because that name and face are what their friend
  /// sees. It is a suggestion, not a wall: "Continue anyway" proceeds
  /// with the defaults, and dismissing the sheet cancels the launch.
  /// Returns true when the launch should go ahead.
  static Future<bool> _ensureProfile(
    BuildContext context,
    AppSession session,
  ) async {
    if (session.profileIsSetUp) return true;

    final missing = <String>[
      if (!session.hasPlayerName) 'a name',
      if (!session.hasPlayerAvatar) 'an avatar',
    ];
    var proceed = false;
    var openSettings = false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.navy900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set up your profile first?',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You have not picked ${missing.join(' and ')} yet. '
                'Your friend sees them during the game, so pick yours '
                'before you start.',
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  color: AppTheme.mist,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        proceed = true;
                        Navigator.of(sheetContext).pop();
                      },
                      child: Text(
                        'Continue anyway',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.mist,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.lime,
                        foregroundColor: AppTheme.navy950,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: () {
                        proceed = true;
                        openSettings = true;
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Set up profile'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (openSettings && context.mounted) {
      await SettingsSheet.show(context, session);
    }
    return proceed;
  }

  static Future<void> inviteFriendAndOpen(
    BuildContext context,
    AppSession session,
    String friendId, {
    GameConfig config = GameConfig.defaults,
  }) async {
    final proceed = await _ensureProfile(context, session);
    if (!proceed || !context.mounted) return;

    await _run(
      context,
      () => session.backend.inviteFriend(friendId: friendId, config: config),
      onError: 'Could not send that invite.',
    );
  }

  static Future<void> open(BuildContext context, String code) async {
    if (_openCode == code) return;
    _openCode = code;
    try {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => RoomPage(roomCode: code)));
      StatsService.instance.reload();
    } finally {
      if (_openCode == code) _openCode = null;
    }
  }

  static Future<void> _run(
    BuildContext context,
    Future<Room> Function() action, {
    required String onError,
  }) async {
    if (_launching) return;
    _launching = true;
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
      _launching = false;
      await navigator.push(
        MaterialPageRoute(builder: (_) => RoomPage(roomCode: room.code)),
      );
      StatsService.instance.reload();
    } catch (error) {
      closeBarrier();
      _launching = false;
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
