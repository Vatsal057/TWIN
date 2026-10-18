import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twin/core/game_config.dart';
import 'package:twin/game/game_engine.dart';
import 'package:twin/models/room.dart';
import 'package:twin/services/backend/local_backend.dart';
import 'package:twin/services/stats_service.dart';
import 'package:twin/state/app_session.dart';
import 'package:twin/state/game_controller.dart';
import 'package:twin/ui/views/history_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('StatsService reactivity and game recording', () {
    test('StatsService notifies listeners on recordGameResult', () async {
      final stats = StatsService.instance;
      var notifications = 0;
      void listener() => notifications++;
      stats.addListener(listener);

      final before = await stats.getStats();
      expect(before.totalGamesPlayed, equals(0));

      await stats.recordGameResult(
        converged: true,
        rounds: 3,
        twinnedWord: 'sunset',
      );

      expect(notifications, greaterThanOrEqualTo(1));
      final after = await stats.getStats();
      expect(after.totalGamesPlayed, equals(1));
      expect(after.totalGamesTwinned, equals(1));
      expect(after.fastestConvergenceRounds, equals(3));
      expect(stats.cached?.totalGamesPlayed, equals(1));

      stats.removeListener(listener);
    });

    test('GameController leave() records played game even when leaving early', () async {
      final backend = LocalBackend(displayName: 'TestPlayer', avatarId: 'a1');
      await backend.initialize();
      final stats = StatsService.instance;
      final before = (await stats.getStats()).totalGamesPlayed;

      final room = await backend.createRoom();
      final controller = GameController(
        backend: backend,
        engine: const GameEngine(),
        roomCode: room.code,
      )..start();

      // Wait a moment for room stream
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await controller.leave();

      final after = (await stats.getStats()).totalGamesPlayed;
      expect(after, equals(before + 1));

      controller.dispose();
      backend.dispose();
    });

    test('LocalBackend watchMyRooms emits immediately and includes finished rooms', () async {
      final backend = LocalBackend(displayName: 'Player1', avatarId: 'a1');
      await backend.initialize();

      // Initial rooms include seeded finished rooms
      final initialRooms = await backend.watchMyRooms().first;
      final initialFinished = initialRooms.where((r) => r.status == RoomStatus.finished).toList();
      expect(initialFinished, isNotEmpty, reason: 'Seeded finished games must be in watchMyRooms');

      // Create a room and leave it
      final room = await backend.createRoom(config: const GameConfig());
      await backend.leaveRoom(room.code);

      final updatedRooms = await backend.watchMyRooms().first;
      final match = updatedRooms.firstWhere((r) => r.code == room.code);
      expect(match.status, equals(RoomStatus.finished));
      expect(match.finishReason, equals(FinishReason.abandoned));

      backend.dispose();
    });

    testWidgets('HistoryView stats update dynamically when game is recorded', (tester) async {
      final backend = LocalBackend(displayName: 'Player1', avatarId: 'a1');
      await backend.initialize();
      final session = AppSession();
      await session.initializeWith(backend);

      // Clean stats to 0
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('stats_games_played', 0);
      await prefs.setInt('stats_games_twinned', 0);
      await StatsService.instance.reload();

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _MockAssetBundle(),
          child: ChangeNotifierProvider<AppSession>.value(
            value: session,
            child: const MaterialApp(
              home: HistoryView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Look for GAMES PLAYED
      expect(find.text('GAMES PLAYED'), findsOneWidget);
      expect(find.text('0'), findsAtLeastNWidgets(1));

      // Now record a game
      await StatsService.instance.recordGameResult(
        converged: true,
        rounds: 3,
        twinnedWord: 'bridge',
      );
      await tester.pumpAndSettle();

      // After recording, count of 1 should appear
      expect(find.text('1'), findsAtLeastNWidgets(1));

      backend.dispose();
    });
  });
}

const _transparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
];

class _MockAssetBundle extends Fake implements AssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.view(Uint8List.fromList(_transparentImage).buffer);

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) async =>
      ui.ImmutableBuffer.fromUint8List(Uint8List.fromList(_transparentImage));

  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) async =>
      parser('');

  @override
  Future<T> loadStructuredBinaryData<T>(String key, FutureOr<T> Function(ByteData data) parser) async {
    final emptyManifest = const StandardMessageCodec().encodeMessage(<String, Object?>{})!;
    return parser(emptyManifest);
  }
}

