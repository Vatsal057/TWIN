import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_session.dart';
import '../state/chat_controller.dart';
import '../state/game_controller.dart';
import 'app_theme.dart';
import 'views/game_view.dart';
import 'views/lobby_view.dart';
import 'views/result_view.dart';

/// Owns the room's controllers for the whole lifetime of the session, and swaps
/// between lobby, game and result as the shared room document advances.
///
/// One listener, one lifecycle: the chat stream and the round history survive
/// the transitions instead of being torn down between screens.
class RoomPage extends StatefulWidget {
  const RoomPage({super.key, required this.roomCode});

  final String roomCode;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  late final GameController _game;
  late final ChatController _chat;

  @override
  void initState() {
    super.initState();
    final session = context.read<AppSession>();
    _game = GameController(
      backend: session.backend,
      engine: session.engine,
      roomCode: widget.roomCode,
    )..start();
    _chat = ChatController(backend: session.backend, roomCode: widget.roomCode)
      ..start();
  }

  @override
  void dispose() {
    _game.dispose();
    _chat.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    final room = _game.room;
    if (room == null || _game.stage == ViewStage.finished) return true;

    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.inkCard,
        title: const Text('Leave this game?'),
        content: const Text(
          'The round in progress ends and your opponent is told the game was '
          'abandoned.',
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

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GameController>.value(value: _game),
        ChangeNotifierProvider<ChatController>.value(value: _chat),
      ],
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
