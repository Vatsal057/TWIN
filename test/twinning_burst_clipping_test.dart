import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twin/ui/widgets/twinning_burst.dart';
import 'package:twin/ui/widgets/reveal_overlay.dart';
import 'package:twin/models/game_round.dart';

void main() {
  testWidgets('TwinningBurst has no clipping SizedBox and uses Clip.none', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TwinningBurst(
            word: 'bridge',
            delay: Duration.zero,
          ),
        ),
      ),
    );

    // Pump past the launch and into the animation
    await tester.pump(const Duration(milliseconds: 300));

    // Verify there is no SizedBox(320, 320) bounding box clipping the animation
    final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
    for (final box in sizedBoxes) {
      expect(box.width == 320.0 && box.height == 320.0, isFalse,
          reason: 'SizedBox(320, 320) invisible clipping square must not exist');
    }

    // Verify Stacks within TwinningBurst use Clip.none
    final stacks = tester.widgetList<Stack>(find.descendant(
      of: find.byType(TwinningBurst),
      matching: find.byType(Stack),
    ));
    for (final stack in stacks) {
      expect(stack.clipBehavior, Clip.none,
          reason: 'TwinningBurst stack must have Clip.none so glow does not clip');
    }
  });

  testWidgets('RevealOverlay Stack uses Clip.none so burst expands beyond borders', (tester) async {
    final round = GameRound(
      index: 1,
      p1Word: 'COFFEE',
      p2Word: 'COFFEE',
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

    final overlayStacks = tester.widgetList<Stack>(find.descendant(
      of: find.byType(RevealOverlay),
      matching: find.byType(Stack),
    ));
    expect(overlayStacks.any((s) => s.clipBehavior == Clip.none), isTrue,
        reason: 'RevealOverlay stack must not clip');
  });

  testWidgets('RevealOverlay and TwinningBurst fill full screen and do not shrink-wrap into square', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final round = GameRound(
      index: 1,
      p1Word: 'COFFEE',
      p2Word: 'COFFEE',
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

    final burstFinder = find.byType(TwinningBurst);
    expect(burstFinder, findsOneWidget);
    final burstSize = tester.getSize(burstFinder);
    expect(burstSize.width, 500.0, reason: 'TwinningBurst must fill screen width');
    expect(burstSize.height, 900.0, reason: 'TwinningBurst must fill screen height');
  });
}
