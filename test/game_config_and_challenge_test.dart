import 'package:flutter_test/flutter_test.dart';
import 'package:twin/core/game_config.dart';
import 'package:twin/models/room.dart';
import 'package:twin/services/deep_link_service.dart';

void main() {
  group('GameConfig Custom Challenge Tests', () {
    test('defaults have no custom start or theme', () {
      const config = GameConfig.defaults;
      expect(config.hasCustomStart, isFalse);
      expect(config.hasTheme, isFalse);
      expect(config.isUnlimited, isTrue);
    });

    test('custom start words work and serialize cleanly', () {
      const config = GameConfig(
        maxRounds: 10,
        startWordA: 'Coffee',
        startWordB: 'Sleep',
        theme: 'Everyday Life',
      );

      expect(config.hasCustomStart, isTrue);
      expect(config.hasTheme, isTrue);
      expect(config.startWordA, 'Coffee');
      expect(config.startWordB, 'Sleep');
      expect(config.theme, 'Everyday Life');

      final map = config.toMap();
      final restored = GameConfig.fromMap(map);

      expect(restored, equals(config));
      expect(restored.startWordA, 'Coffee');
      expect(restored.startWordB, 'Sleep');
      expect(restored.theme, 'Everyday Life');
      expect(restored.maxRounds, 10);
    });

    test('copyWith updates start words and theme', () {
      const initial = GameConfig(maxRounds: 5);
      final updated = initial.copyWith(
        startWordA: 'Sun',
        startWordB: 'Moon',
        theme: 'Nature',
      );

      expect(updated.startWordA, 'Sun');
      expect(updated.startWordB, 'Moon');
      expect(updated.theme, 'Nature');
      expect(updated.maxRounds, 5);
      expect(updated.hasCustomStart, isTrue);
    });
  });

  group('DeepLinkService Share Message Tests', () {
    test('formats default challenge', () {
      final msg = DeepLinkService.shareMessage('ABCDE', fromName: 'Alice');
      expect(msg, contains('Alice challenged you to TWIN!'));
      expect(msg, contains('Can you think of the same word?'));
      expect(msg, contains('ABCDE'));
    });

    test('formats custom word challenge', () {
      const config = GameConfig(startWordA: 'Batman', startWordB: 'Joker');
      final msg = DeepLinkService.shareMessage(
        'ABCDE',
        fromName: 'Bob',
        config: config,
      );

      expect(msg, contains('Bob challenged you to TWIN!'));
      expect(msg, contains('Can you bridge "Batman" and "Joker"?'));
      expect(msg, contains('ABCDE'));
    });

    test('formats themed challenge', () {
      const config = GameConfig(theme: 'Food & Drink');
      final msg = DeepLinkService.shareMessage(
        'ABCDE',
        fromName: 'Charlie',
        config: config,
      );

      expect(msg, contains('Charlie challenged you to a Food & Drink TWIN!'));
      expect(msg, contains('ABCDE'));
    });
  });

  group('Room Nudge and Rematch Lifecycle Tests', () {
    test('Room serializes and deserializes lastNudge cleanly', () {
      final now = DateTime.now();
      final room = Room(
        code: 'TEST1',
        hostId: 'user1',
        players: ['user1'],
        playerNames: {'user1': 'Alice'},
        status: RoomStatus.waiting,
        config: GameConfig.defaults,
        currentRound: 1,
        submittedBy: const [],
        rounds: const [],
        lastNudgeBy: 'user1',
        lastNudgeAt: now,
      );

      final map = room.toMap();
      expect(map['lastNudgeBy'], 'user1');
      expect(map['lastNudgeAt'], isNotNull);

      final revived = Room.fromMap('TEST1', map);
      expect(revived.lastNudgeBy, 'user1');
      expect(revived.lastNudgeAt, isNotNull);
    });

    test('Room copyWith updates rematchRoomCode and nudge', () {
      final room = Room(
        code: 'TEST1',
        hostId: 'user1',
        players: ['user1'],
        playerNames: {'user1': 'Alice'},
        status: RoomStatus.waiting,
        config: GameConfig.defaults,
        currentRound: 1,
        submittedBy: const [],
        rounds: const [],
      );

      final updated = room.copyWith(
        rematchRoomCode: 'NEXT1',
        lastNudgeBy: 'user2',
      );
      expect(updated.rematchRoomCode, 'NEXT1');
      expect(updated.lastNudgeBy, 'user2');
    });
  });
}
