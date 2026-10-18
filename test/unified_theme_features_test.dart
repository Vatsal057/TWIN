import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twin/models/game_round.dart';
import 'package:twin/services/backend/local_backend.dart';
import 'package:twin/state/app_session.dart';
import 'package:twin/state/game_controller.dart';
import 'package:twin/ui/views/result_view.dart';
import 'package:twin/ui/widgets/convergence_hero.dart';
import 'package:twin/ui/widgets/join_sheet.dart';
import 'package:twin/ui/widgets/reference_daily_twin_card.dart';
import 'package:twin/ui/widgets/reveal_overlay.dart';
import 'package:twin/ui/widgets/twinning_burst.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('RevealOverlay renders TwinningBurst when round is matched',
      (tester) async {
    final round = GameRound(
      index: 1,
      p1Word: 'TWIN',
      p2Word: 'TWIN',
      matched: true,
      revealedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RevealOverlay(
            round: round,
            p1Name: 'Alice',
            p2Name: 'Bob',
            localIsP1: true,
            onDismiss: () {},
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(TwinningBurst), findsOneWidget);
    expect(find.text('ROUND 1 REVEALED'), findsOneWidget);
    expect(find.text('matched in 1 rounds'), findsOneWidget);
  });

  testWidgets('RevealOverlay does not render TwinningBurst when not matched',
      (tester) async {
    final round = GameRound(
      index: 1,
      p1Word: 'COFFEE',
      p2Word: 'TEA',
      matched: false,
      revealedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RevealOverlay(
            round: round,
            p1Name: 'Alice',
            p2Name: 'Bob',
            localIsP1: true,
            onDismiss: () {},
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(TwinningBurst), findsNothing);
    expect(find.text('No match'), findsOneWidget);
    expect(find.text('aim between these two next round'), findsOneWidget);
  });

  testWidgets('ReferenceDailyTwinCard renders challenge details',
      (tester) async {
    final backend = LocalBackend(displayName: 'TestUser');
    await backend.initialize();
    final session = AppSession();
    await session.initializeWith(backend);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppSession>.value(
        value: session,
        child: MaterialApp(
          home: Scaffold(
            body: ReferenceDailyTwinCard(session: session),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ReferenceDailyTwinCard), findsOneWidget);
    expect(find.text('Global 24h challenge'), findsOneWidget);
  });

  testWidgets('ResultView includes ConvergenceHero and all share actions',
      (tester) async {
    final backend = LocalBackend(displayName: 'Alice');
    await backend.initialize();
    final session = AppSession();
    await session.initializeWith(backend);

    // Use seeded finished room 'T2WQN'
    final game = GameController(
      backend: backend,
      engine: session.engine,
      roomCode: 'T2WQN',
    )..start();
    addTearDown(game.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSession>.value(value: session),
          ChangeNotifierProvider<GameController>.value(value: game),
        ],
        child: const MaterialApp(home: ResultView()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 4));

    expect(find.byType(ConvergenceHero), findsOneWidget);
    expect(find.text('Share Victory Card'), findsOneWidget);
    expect(find.text('Share text recap'), findsOneWidget);
    expect(find.text('Rematch'), findsOneWidget);
    expect(find.text('Back to games'), findsOneWidget);
  });

  testWidgets('JoinSheet displays 5 boxes and pops with 5-character code',
      (tester) async {
    String? enteredCode;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                enteredCode = await JoinSheet.show(context);
              },
              child: const Text('Open Join'),
            ),
          ),
        ),
      ),
    );

    // Tap to open sheet
    await tester.tap(find.text('Open Join'));
    await tester.pumpAndSettle();

    expect(find.text('Join a match'), findsOneWidget);
    expect(find.text('Enter the 5-character code shared by your friend.'), findsOneWidget);

    // Find the hidden TextField
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    // Enter a valid 5-character room code with letters and numbers (e.g. 'T2WQN')
    await tester.enterText(textFieldFinder, 't2wqn');
    await tester.pumpAndSettle();

    // Sheet should auto-submit and pop with 'T2WQN'
    expect(enteredCode, 'T2WQN');
  });
}

