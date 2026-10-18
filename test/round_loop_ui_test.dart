import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twin/services/backend/local_backend.dart';
import 'package:twin/state/app_session.dart';
import 'package:twin/state/chat_controller.dart';
import 'package:twin/state/game_controller.dart';
import 'package:twin/ui/views/game_view.dart';

/// Drives the real UI against the real local backend: open a seeded game,
/// dismiss the catch-up reveal, lock a word in, and let the practice partner
/// answer — the round loop the canvas-based web screenshots cannot express.
void main() {
  testWidgets('game view plays a full round against the practice partner',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    final backend = LocalBackend(displayName: 'You');
    await backend.initialize();

    final session = AppSession();
    await session.initializeWith(backend);

    final chat = ChatController(backend: backend, roomCode: 'MAY02')..start();
    addTearDown(chat.dispose);

    final game = GameController(
      backend: backend,
      engine: session.engine,
      roomCode: 'MAY02',
    )..start();
    addTearDown(game.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSession>.value(value: session),
          ChangeNotifierProvider<ChatController>.value(value: chat),
          ChangeNotifierProvider<GameController>.value(value: game),
        ],
        child: const MaterialApp(home: GameView()),
      ),
    );
    await tester.pumpAndSettle();

    // Let the room stream deliver the seeded room.
    await tester.pump(const Duration(milliseconds: 200));
    debugPrint('TEST room=${game.room?.code} stage=${game.stage} revealing=${game.revealingRound?.index}');
    expect(game.room, isNotNull, reason: 'game controller loaded the room');

    // Dismiss the catch-up reveal for round 1 (COFFEE / TEA) if it is up.
    game.dismissReveal();
    await tester.pump(const Duration(milliseconds: 300));

    // Composing state for round 2.
    expect(find.text('Type your word'), findsOneWidget);
    expect(find.text('Lock it in'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'kettle');
    await tester.pump();
    await tester.tap(find.text('Lock it in'));
    await tester.pump();

    // Give the practice partner time to answer and let the reveal timer elapse.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 3));

    final room = await backend.fetchRoom('MAY02');
    expect(room, isNotNull);
    expect(room!.rounds.length, 2, reason: 'round 2 resolved against the bot');

    final resolved = room.rounds.last;
    expect(resolved.index, 2);
    expect(resolved.p1Word, 'kettle');
    expect(resolved.p2Word, isNotEmpty);

    // Either it converged, or round 3 is open for us.
    if (room.status.name == 'finished') {
      expect(room.finishReason?.name, 'converged');
    } else {
      expect(room.currentRound, 3);
    }
  });
}
