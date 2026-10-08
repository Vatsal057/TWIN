import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:twin/core/game_config.dart';
import 'package:twin/game/game_engine.dart';
import 'package:twin/models/chat_message.dart';
import 'package:twin/models/friend.dart';
import 'package:twin/models/game_invite.dart';
import 'package:twin/models/game_round.dart';
import 'package:twin/models/room.dart';
import 'package:twin/services/backend/game_backend.dart';
import 'package:twin/state/game_controller.dart';

class MockBackend implements GameBackend {
  MockBackend({required this.playerId});

  final String playerId;
  final StreamController<Room> roomController = StreamController<Room>.broadcast();
  int commitRoundCalls = 0;
  int fetchRoomCalls = 0;
  Room? roomToFetch;

  @override
  String get localPlayerId => playerId;

  @override
  String get displayName => 'Player';

  @override
  bool get isNetworked => true;

  @override
  String get label => 'MockBackend';

  @override
  void dispose() {
    roomController.close();
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setDisplayName(String name) async {}

  @override
  Future<Room> createRoom({
    GameConfig config = GameConfig.defaults,
    String? rematchOf,
    bool isPublic = false,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Room> joinRoom(String code) async {
    throw UnimplementedError();
  }

  @override
  Future<Room?> fetchRoom(String code) async {
    fetchRoomCalls++;
    return roomToFetch;
  }

  @override
  Stream<Room> watchRoom(String code) => roomController.stream;

  @override
  Future<void> submitWord({required String code, required int roundIndex, required String word}) async {}

  @override
  Future<({String p1Word, String p2Word})?> readSubmissions({required String code, required int roundIndex}) async {
    return (p1Word: 'apple', p2Word: 'banana');
  }

  @override
  Future<void> commitRound({
    required String code,
    required int roundIndex,
    required RoundResolver resolve,
  }) async {
    commitRoundCalls++;
  }

  @override
  Future<void> leaveRoom(String code) async {}

  @override
  Future<Room> startRematch(Room room) async {
    throw UnimplementedError();
  }

  @override
  Future<void> nudgeRoom(String code) async {}

  @override
  Stream<List<ChatMessage>> watchMessages(String code) => const Stream.empty();

  @override
  Future<void> sendMessage({required String code, required String text}) async {}

  @override
  Stream<List<Friend>> watchFriends() => const Stream.empty();

  @override
  Future<void> rememberPairing({required String friendId, required String friendName}) async {}

  @override
  Future<void> forgetFriend(String friendId) async {}

  @override
  Future<Room> inviteFriend({required String friendId, GameConfig config = GameConfig.defaults}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> recordGameCompletion({
    required String friendId,
    required String friendName,
    required int roundsCount,
    required bool converged,
    String? convergedWord,
  }) async {}

  @override
  Future<Room> findOrCreateQuickPlayRoom({
    GameConfig config = GameConfig.defaults,
  }) async => throw UnimplementedError();

  @override
  Stream<List<GameInvite>> watchInvites() => const Stream.empty();

  @override
  Future<void> dismissInvite(String roomCode) async {}
}

void main() {
  group('GameController Primary/Guest Resolver & Sync Tests', () {
    late GameEngine engine;

    setUp(() {
      engine = const GameEngine();
    });

    test('Host resolves immediately when room isReadyToReveal', () async {
      final backend = MockBackend(playerId: 'host-123');
      final controller = GameController(
        backend: backend,
        engine: engine,
        roomCode: 'TEST1',
      )..start();

      final room = Room(
        code: 'TEST1',
        hostId: 'host-123',
        players: ['host-123', 'guest-456'],
        playerNames: {'host-123': 'Host', 'guest-456': 'Guest'},
        status: RoomStatus.active,
        config: GameConfig.defaults,
        currentRound: 1,
        submittedBy: ['host-123', 'guest-456'],
        rounds: [],
      );

      backend.roomController.add(room);
      await pumpEventQueue();

      expect(backend.commitRoundCalls, equals(1));
      controller.dispose();
    });

    test('Guest delays resolution to let host commit first without conflict', () async {
      final backend = MockBackend(playerId: 'guest-456');
      final controller = GameController(
        backend: backend,
        engine: engine,
        roomCode: 'TEST1',
      )..start();

      final room = Room(
        code: 'TEST1',
        hostId: 'host-123',
        players: ['host-123', 'guest-456'],
        playerNames: {'host-123': 'Host', 'guest-456': 'Guest'},
        status: RoomStatus.active,
        config: GameConfig.defaults,
        currentRound: 1,
        submittedBy: ['host-123', 'guest-456'],
        rounds: [],
      );

      backend.roomController.add(room);
      await pumpEventQueue();

      // Immediately upon receipt, guest has NOT committed yet
      expect(backend.commitRoundCalls, equals(0));

      controller.dispose();
    });

    test('Waiting for opponent activates recovery poll to catch desynced round resolution', () async {
      final backend = MockBackend(playerId: 'host-123');
      final controller = GameController(
        backend: backend,
        engine: engine,
        roomCode: 'TEST1',
      )..start();

      // Host has submitted, guest has not yet
      final room = Room(
        code: 'TEST1',
        hostId: 'host-123',
        players: ['host-123', 'guest-456'],
        playerNames: {'host-123': 'Host', 'guest-456': 'Guest'},
        status: RoomStatus.active,
        config: GameConfig.defaults,
        currentRound: 1,
        submittedBy: ['host-123'],
        rounds: [],
      );

      // Room to fetch has the round already resolved by another client or server
      backend.roomToFetch = Room(
        code: 'TEST1',
        hostId: 'host-123',
        players: ['host-123', 'guest-456'],
        playerNames: {'host-123': 'Host', 'guest-456': 'Guest'},
        status: RoomStatus.active,
        config: GameConfig.defaults,
        currentRound: 2,
        submittedBy: [],
        rounds: [
          const GameRound(
            index: 1,
            p1Word: 'sun',
            p2Word: 'moon',
            matched: false,
          ),
        ],
      );

      backend.roomController.add(room);
      await pumpEventQueue();

      expect(controller.stage, equals(ViewStage.waitingForOpponent));

      // Wait for recovery poll timer (2s)
      await Future<void>.delayed(const Duration(milliseconds: 2200));

      expect(backend.fetchRoomCalls, greaterThanOrEqualTo(1));
      expect(controller.stage, equals(ViewStage.revealing));

      controller.dispose();
    });
  });
}
