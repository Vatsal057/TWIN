import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_session.dart';
import '../state/game_controller.dart';
import 'views/game_view.dart';
import 'views/lobby_view.dart';
import 'views/result_view.dart';

/// Owns the room's game controller for the whole lifetime of the session, and
/// swaps between lobby, game and result as the shared room document advances.
///
/// One listener, one lifecycle: the round history survives the transitions
/// instead of being torn down between screens. Chat lives outside the room
/// now (one conversation per pair of players), so it is not owned here.
class RoomPage extends StatefulWidget {
  const RoomPage({super.key, required this.roomCode});

  final String roomCode;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  late final GameController _game;

  @override
  void initState() {
    super.initState();
    final session = context.read<AppSession>();
    _game = GameController(
      backend: session.backend,
      engine: session.engine,
      roomCode: widget.roomCode,
    )..start();
  }

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    final room = _game.room;
    if (room == null || _game.stage == ViewStage.finished) return true;
    // Still waiting for the second player: backing out is not leaving.
    // The room stays open under Active games and the code keeps
    // working; closing it for good is the lobby's own close action
    // (see _closeRoom).
    if (!room.isFull) return true;

    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.read<AppSession>().palette.sheet,
        title: const Text('Leave this game?'),
        content: const Text(
          'The round in progress ends and your opponent is told the '
          'game was abandoned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true) {
      await _game.leave();
      return true;
    }
    return false;
  }

  /// The lobby's close (X) action: the one destructive exit from a
  /// waiting room. Confirms here, closes the room, then pops; the pop
  /// itself passes freely because the room is no longer in play.
  Future<void> _closeRoom() async {
    if (_game.room == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final close = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.read<AppSession>().palette.sheet,
        title: const Text('Close this room?'),
        content: const Text(
          'This room will be closed, and the code will stop working.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep waiting'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Close room'),
          ),
        ],
      ),
    );
    if (close == true && mounted) {
      await _game.leave();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider<GameController>.value(value: _game)],
      child: Consumer<GameController>(
        builder: (context, game, _) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              if (await _confirmLeave() && mounted) {
                if (!context.mounted) return;
                Navigator.of(context).pop();
              }
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: switch (game.stage) {
                ViewStage.connecting => const _ConnectingView(),
                ViewStage.waitingForPlayers => LobbyView(
                  key: const ValueKey('lobby'),
                  onCloseRoom: _closeRoom,
                ),
                ViewStage.finished => ResultView(key: const ValueKey('result')),
                _ => GameView(key: const ValueKey('game')),
              },
            ),
          );
        },
      ),
    );
  }
}

class _ConnectingView extends StatelessWidget {
  const _ConnectingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
