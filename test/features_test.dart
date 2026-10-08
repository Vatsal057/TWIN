import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twin/core/game_config.dart';
import 'package:twin/models/friend.dart';
import 'package:twin/models/room.dart';
import 'package:twin/services/backend/local_backend.dart';
import 'package:twin/services/daily_twin_service.dart';
import 'package:twin/services/stats_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FEAT-19: Hardcore / Abstract Mode Deck', () {
    test('curatedCategories contains Abstract / Hardcore', () {
      expect(GameConfig.curatedCategories.contains('Abstract / Hardcore'), isTrue);
    });

    test('isAbstractDeck returns true when theme is Abstract / Hardcore', () {
      const config = GameConfig(theme: 'Abstract / Hardcore');
      expect(config.isAbstractDeck, isTrue);
      expect(GameConfig.abstractPairs.isNotEmpty, isTrue);
    });

    test('isAbstractDeck returns false for classic or other themes', () {
      const config = GameConfig(theme: 'Food & Drink');
      expect(config.isAbstractDeck, isFalse);
    });
  });

  group('FEAT-13: Duo Chemistry Stats & Memory Bank', () {
    test('Friend serializes and deserializes duo chemistry metrics cleanly', () {
      final friend = Friend(
        id: 'user-123',
        name: 'Alex',
        gamesPlayed: 5,
        totalRounds: 20,
        bestSyncRounds: 3,
        bestSyncWord: 'caffeine',
        memoryBank: const ['caffeine', 'sunset'],
        lastPlayedAt: DateTime(2026, 10, 8, 12, 0),
      );

      final map = friend.toMap();
      final roundTrip = Friend.fromMap('user-123', map);

      expect(roundTrip.id, 'user-123');
      expect(roundTrip.name, 'Alex');
      expect(roundTrip.gamesPlayed, 5);
      expect(roundTrip.totalRounds, 20);
      expect(roundTrip.bestSyncRounds, 3);
      expect(roundTrip.bestSyncWord, 'caffeine');
      expect(roundTrip.memoryBank, ['caffeine', 'sunset']);
      expect(roundTrip.averageRounds, 4.0);
      expect(roundTrip.twinnedCount, 2);
    });

    test('LocalBackend recordGameCompletion updates duo metrics and memory bank', () async {
      final backend = LocalBackend(displayName: 'TestPlayer');
      await backend.initialize();

      await backend.recordGameCompletion(
        friendId: 'f1',
        friendName: 'Sam',
        roundsCount: 4,
        converged: true,
        convergedWord: 'espresso',
      );

      final friends = await backend.watchFriends().first;
      final f = friends.firstWhere((x) => x.id == 'f1');
      expect(f.gamesPlayed, 1);
      expect(f.totalRounds, 4);
      expect(f.bestSyncRounds, 4);
      expect(f.bestSyncWord, 'espresso');
      expect(f.memoryBank, ['espresso']);

      // Record a second game with better sync
      await backend.recordGameCompletion(
        friendId: 'f1',
        friendName: 'Sam',
        roundsCount: 2,
        converged: true,
        convergedWord: 'mocha',
      );

      final friends2 = await backend.watchFriends().first;
      final f2 = friends2.firstWhere((x) => x.id == 'f1');
      expect(f2.gamesPlayed, 2);
      expect(f2.totalRounds, 6);
      expect(f2.bestSyncRounds, 2); // updated to better sync
      expect(f2.bestSyncWord, 'mocha');
      expect(f2.memoryBank, containsAll(['espresso', 'mocha']));
      expect(f2.averageRounds, 3.0);
    });
  });

  group('FEAT-14: Personal Lifetime Stats & Bridge Words', () {
    test('StatsService records bridge words and aggregates top hubs', () async {
      final statsService = StatsService.instance;

      await statsService.recordRoundWord('planet');
      await statsService.recordRoundWord('planet');
      await statsService.recordRoundWord('gravity');

      final stats = await statsService.getStats();
      expect(stats.topBridgeWords.first.key, 'planet');
      expect(stats.topBridgeWords.first.value, 2);
      expect(stats.topBridgeWords[1].key, 'gravity');
      expect(stats.topBridgeWords[1].value, 1);
    });

    test('StatsService records game outcomes and fastest convergence', () async {
      final statsService = StatsService.instance;

      await statsService.recordGameResult(
        converged: true,
        rounds: 4,
        twinnedWord: 'telepathy',
      );
      await statsService.recordGameResult(
        converged: false,
        rounds: 5,
      );

      final stats = await statsService.getStats();
      expect(stats.totalGamesPlayed, 2);
      expect(stats.totalGamesTwinned, 1);
      expect(stats.totalRoundsPlayed, 9);
      expect(stats.fastestConvergenceRounds, 4);
      expect(stats.convergenceRate, 0.5);
    });
  });

  group('FEAT-15: The Daily Twin (Global 24h Puzzle)', () {
    test('DailyTwinService yields deterministic daily puzzle', () {
      final service = DailyTwinService.instance;
      final puzzle1 = service.getTodayPuzzle();
      final puzzle2 = service.getTodayPuzzle();

      expect(puzzle1.puzzleNumber, puzzle2.puzzleNumber);
      expect(puzzle1.startWordA, puzzle2.startWordA);
      expect(puzzle1.startWordB, puzzle2.startWordB);
      expect(puzzle1.dateString, service.todayUtcString);
    });

    test('DailyTwinService tracks streaks and completion status', () async {
      final service = DailyTwinService.instance;
      var status = await service.getStatus();
      expect(status.isCompletedToday, isFalse);
      expect(status.currentStreak, 0);

      await service.recordDailyCompletion();
      status = await service.getStatus();
      expect(status.isCompletedToday, isTrue);
      expect(status.currentStreak, 1);
      expect(status.bestStreak, 1);
    });
  });

  group('FEAT-17: Public 1v1 Matchmaking (Quick Play)', () {
    test('Room serializes and deserializes isPublic flag', () {
      const room = Room(
        code: 'TESTQ',
        hostId: 'h1',
        players: ['h1'],
        playerNames: {'h1': 'Host'},
        status: RoomStatus.waiting,
        config: GameConfig.defaults,
        currentRound: 1,
        submittedBy: [],
        rounds: [],
        isPublic: true,
      );

      final map = room.toMap();
      expect(map['isPublic'], isTrue);

      final roundTrip = Room.fromMap('TESTQ', map);
      expect(roundTrip.isPublic, isTrue);
    });

    test('LocalBackend findOrCreateQuickPlayRoom creates public room', () async {
      final backend = LocalBackend(displayName: 'QuickPlayer');
      await backend.initialize();

      final room = await backend.findOrCreateQuickPlayRoom();
      expect(room.isPublic, isTrue);
      expect(room.status, RoomStatus.waiting);
    });
  });
}
