import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_avatars.dart';
import '../../core/game_config.dart';
import '../../core/word_utils.dart';
import '../../models/chat_message.dart';
import '../../models/friend.dart';
import '../../models/game_invite.dart';
import '../../models/game_round.dart';
import '../../models/room.dart';
import '../room_code.dart';
import '../stats_service.dart';
import 'game_backend.dart';

/// Single-device backend used when Firebase is not configured.
///
/// It implements the same [GameBackend] contract as [FirestoreBackend] and
/// stands in for the second player, so the full round loop — private
/// submissions, simultaneous reveal, convergence — is
/// playable and inspectable without any cloud setup. It does **not** sync
/// across devices; real two-player games need the Firestore backend.
class LocalBackend implements GameBackend {
  LocalBackend({String displayName = 'You', String avatarId = AppAvatars.fallback})
    : _displayName = displayName,
      _avatarId = avatarId;

  static const botId = 'local-bot';
  static const botName = 'Practice Bot';

  static const _seedWords = [
    'river',
    'mountain',
    'silence',
    'engine',
    'harvest',
    'lantern',
    'winter',
    'market',
    'thunder',
    'garden',
    'compass',
    'shadow',
  ];

  final _random = Random();

  String _displayName;
  String _avatarId;
  String _uid = 'local-player';

  final Map<String, Room> _rooms = {};
  final Map<String, StreamController<Room>> _roomStreams = {};
  final StreamController<List<Room>> _myRoomsStream =
      StreamController<List<Room>>.broadcast();
  final Map<String, Map<int, Map<String, String>>> _submissions = {};
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, StreamController<List<ChatMessage>>> _messageStreams = {};
  final Map<String, Friend> _friends = {};
  final StreamController<List<Friend>> _friendStream =
      StreamController<List<Friend>>.broadcast();
  final Set<Timer> _timers = {};

  SharedPreferences? _prefs;

  @override
  String get localPlayerId => _uid;

  @override
  bool get isNetworked => false;

  @override
  String get label => 'Offline practice';

  @override
  String get displayName => _displayName;

  @override
  String get avatarId => _avatarId;

  @override
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    // Keep the id comfortably inside nextInt's range on every platform
    // (web compiles ints to JS doubles, where `1 << 32` overflows to 0).
    _uid = _prefs?.getString('local_uid') ??
        'local-${_random.nextInt(0x7FFFFFFF).toRadixString(36)}';
    await _prefs?.setString('local_uid', _uid);

    final raw = _prefs?.getString('local_friends');
    if (raw != null) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final entry in decoded.whereType<Map>()) {
          final map = entry.cast<String, Object?>();
          final id = map['friendId'] as String?;
          if (id == null) continue;
          _friends[id] = Friend.fromMap(id, map);
        }
      }
    }
    final rawRooms = _prefs?.getString('local_rooms');
    if (rawRooms != null) {
      try {
        final decoded = jsonDecode(rawRooms);
        if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            final map = item.cast<String, Object?>();
            final code = map['code'] as String?;
            if (code != null && code.isNotEmpty) {
              _rooms[code] = Room.fromMap(code, map);
            }
          }
        }
      } catch (e) {
        debugPrint('Error restoring local rooms: $e');
      }
    }
    if (_rooms.isEmpty) {
      _seedDemoState();
    }
    await _seedDemoStats();
    _emitFriends();
    _emitMyRooms();
  }

  /// The seeded finished games (T2WQN, H5JRD) belong in the lifetime stats
  /// too, otherwise History shows past games with an empty stats card.
  Future<void> _seedDemoStats() async {
    final stats = StatsService.instance;
    final snapshot = await stats.getStats();
    if (snapshot.totalGamesPlayed > 0) return;
    await stats.recordGameResult(converged: false, rounds: 5);
    await stats.recordGameResult(converged: true, rounds: 3, twinnedWord: 'dusk');
    await stats.recordGameResult(converged: true, rounds: 5, twinnedWord: 'brunch');
  }

  List<Room> _mineRoomsList() {
    final mine = _rooms.values
        .where((r) => r.players.contains(_uid))
        .toList()
      ..sort((a, b) {
        final aAt = a.updatedAt ?? a.createdAt ?? DateTime(0);
        final bAt = b.updatedAt ?? b.createdAt ?? DateTime(0);
        return bAt.compareTo(aAt);
      });
    return List.unmodifiable(mine);
  }

  @override
  Stream<List<Room>> watchMyRooms() async* {
    yield _mineRoomsList();
    yield* _myRoomsStream.stream;
  }

  void _emitMyRooms() {
    if (_myRoomsStream.isClosed) return;
    _myRoomsStream.add(_mineRoomsList());
  }

  Future<void> _persistRooms() async {
    try {
      final list = _rooms.values.map((r) => r.toMap()).toList();
      await _prefs?.setString('local_rooms', jsonEncode(list));
    } catch (e) {
      debugPrint('Error persisting local rooms: $e');
    }
  }


  @override
  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _displayName = trimmed;
    for (final code in _rooms.keys.toList()) {
      final room = _rooms[code]!;
      _publish(
        room.copyWith(playerNames: {...room.playerNames, _uid: trimmed}),
      );
    }
  }

  @override
  Future<void> setAvatarId(String avatarId) async {
    if (!AppAvatars.isValid(avatarId)) return;
    _avatarId = avatarId;
    for (final code in _rooms.keys.toList()) {
      final room = _rooms[code]!;
      _publish(
        room.copyWith(playerAvatars: {...room.playerAvatars, _uid: avatarId}),
      );
    }
  }

  // ---------------------------------------------------------------- rooms

  @override
  Future<Room> createRoom({
    GameConfig config = GameConfig.defaults,
    String? rematchOf,
  }) async {
    var code = RoomCode.generate();
    while (_rooms.containsKey(code)) {
      code = RoomCode.generate();
    }
    final room = Room(
      code: code,
      hostId: _uid,
      players: [_uid],
      playerNames: {_uid: _displayName},
      playerAvatars: {_uid: _avatarId},
      status: RoomStatus.waiting,
      config: config,
      currentRound: 1,
      submittedBy: const [],
      rounds: const [],
      rematchOf: rematchOf,
      createdAt: DateTime.now(),
    );
    _rooms[code] = room;
    _submissions[code] = {};
    _messages[code] = [];
    _emitMyRooms();
    _persistRooms();

    // Stand in for the second player joining from another device.
    _schedule(const Duration(milliseconds: 1200), () => _botJoin(code));
    return room;
  }

  @override
  Future<Room> joinRoom(String rawCode) async {
    final code = RoomCode.normalize(rawCode);
    final existing = _rooms[code];
    if (existing == null) {
      throw const BackendException(
        'Offline practice mode cannot see rooms from other devices. '
        'Configure Firebase to play over the internet.',
      );
    }
    if (existing.players.contains(_uid)) {
      if (!existing.isFull) {
        throw const BackendException(
          'This is your own room. Send the code to the other player — you '
          'cannot be both players.',
          code: 'own-room',
        );
      }
      return existing;
    }
    if (existing.isFull) {
      throw const BackendException('That room already has two players.');
    }
    final joined = existing.copyWith(
      players: [...existing.players, _uid],
      playerNames: {...existing.playerNames, _uid: _displayName},
      playerAvatars: {...existing.playerAvatars, _uid: _avatarId},
      status: RoomStatus.active,
    );
    _publish(joined);
    return joined;
  }

  @override
  Stream<Room> watchRoom(String code) {
    final controller = _roomStreams.putIfAbsent(
      code,
      () => StreamController<Room>.broadcast(),
    );
    final current = _rooms[code];
    if (current != null) {
      _schedule(Duration.zero, () => controller.add(current));
    }
    return controller.stream;
  }

  @override
  Future<Room?> fetchRoom(String code) async =>
      _rooms[RoomCode.normalize(code)];

  @override
  Future<void> submitWord({
    required String code,
    required int roundIndex,
    required String word,
  }) async {
    final room = _rooms[code];
    if (room == null) return;
    (_submissions[code] ??= {}).putIfAbsent(roundIndex, () => {})[_uid] = word;
    _publish(room.copyWith(submittedBy: {...room.submittedBy, _uid}.toList()));

    // The partner answers after a beat so the "waiting for opponent" state is real.
    final opponentId = room.players.firstWhere((p) => p != _uid, orElse: () => '');
    if (opponentId.isNotEmpty) {
      _schedule(
        Duration(milliseconds: 700 + _random.nextInt(900)),
        () => _botSubmitPlayer(code, roundIndex, opponentId),
      );
    }
  }


  @override
  Future<({String p1Word, String p2Word})?> readSubmissions({
    required String code,
    required int roundIndex,
  }) async {
    final room = _rooms[code];
    final p2 = room?.p2Id;
    if (room == null || p2 == null) return null;
    final round = _submissions[code]?[roundIndex];
    final p1Word = round?[room.p1Id];
    final p2Word = round?[p2];
    if (p1Word == null || p2Word == null) return null;
    return (p1Word: p1Word, p2Word: p2Word);
  }

  @override
  Future<void> commitRound({
    required String code,
    required int roundIndex,
    required RoundResolver resolve,
  }) async {
    final room = _rooms[code];
    if (room == null) return;
    if (room.rounds.length >= roundIndex) return;
    final words = await readSubmissions(code: code, roundIndex: roundIndex);
    if (words == null) return;

    final resolution = resolve(room, words.p1Word, words.p2Word);
    _publish(
      room.copyWith(
        rounds: [...room.rounds, resolution.round],
        status: resolution.status,
        currentRound: resolution.nextRound,
        submittedBy: const [],
        finishReason: resolution.finishReason,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> leaveRoom(String code) async {
    final room = _rooms[code];
    if (room == null || room.status == RoomStatus.finished) return;
    _publish(
      room.copyWith(
        status: RoomStatus.finished,
        finishReason: FinishReason.abandoned,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Room> startRematch(Room room) async {
    final fresh = await createRoom(config: room.config, rematchOf: room.code);
    final old = _rooms[room.code];
    if (old != null) _publish(old.copyWith(rematchRoomCode: fresh.code));
    return fresh;
  }

  @override
  Future<void> nudgeRoom(String code) async {
    final room = _rooms[code];
    if (room == null) return;
    _publish(room.copyWith(lastNudgeBy: _uid, lastNudgeAt: DateTime.now()));
  }

  // ----------------------------------------------------------------- chat

  @override
  Stream<List<ChatMessage>> watchMessages(String code) {
    final controller = _messageStreams.putIfAbsent(
      code,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    _schedule(Duration.zero, () => controller.add([...?_messages[code]]));
    return controller.stream;
  }

  @override
  Future<void> sendMessage({required String code, required String text}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _appendMessage(code, senderId: _uid, text: trimmed);

    final room = _rooms[code];
    final opponentId = room?.players.firstWhere((p) => p != _uid, orElse: () => '');
    if (opponentId != null && opponentId.isNotEmpty) {
      _schedule(
        Duration(milliseconds: 1000 + _random.nextInt(800)),
        () => _appendMessage(code, senderId: opponentId, text: _botChatReply(trimmed)),
      );
    }
  }


  void _appendMessage(
    String code, {
    required String senderId,
    required String text,
  }) {
    final list = _messages.putIfAbsent(code, () => []);
    list.add(
      ChatMessage(
        id: 'm${list.length}-${DateTime.now().microsecondsSinceEpoch}',
        senderId: senderId,
        text: text,
        sentAt: DateTime.now(),
      ),
    );
    _messageStreams[code]?.add([...list]);
  }

  // -------------------------------------------------------------- friends

  List<Friend> _friendsList() {
    final list = _friends.values.toList()
      ..sort(
        (a, b) => (b.lastPlayedAt ?? DateTime(0)).compareTo(
          a.lastPlayedAt ?? DateTime(0),
        ),
      );
    return List.unmodifiable(list);
  }

  @override
  Stream<List<Friend>> watchFriends() async* {
    yield _friendsList();
    yield* _friendStream.stream;
  }

  @override
  Future<void> rememberPairing({
    required String friendId,
    required String friendName,
  }) async {
    if (friendId.isEmpty || friendId == _uid) return;
    final existing = _friends[friendId];
    _friends[friendId] = Friend(
      id: friendId,
      name: friendName,
      lastPlayedAt: DateTime.now(),
      gamesPlayed: (existing?.gamesPlayed ?? 0) + 1,
    );
    await _persistFriends();
    _emitFriends();
  }

  @override
  Future<void> recordGameCompletion({
    required String friendId,
    required String friendName,
    required int roundsCount,
    required bool converged,
    String? convergedWord,
  }) async {
    if (friendId.isEmpty || friendId == _uid) return;
    final existing = _friends[friendId];
    final currentGames = (existing?.gamesPlayed ?? 0) + 1;
    final currentTotalRounds = (existing?.totalRounds ?? 0) + roundsCount;
    int? bestRounds = existing?.bestSyncRounds;
    String? bestWord = existing?.bestSyncWord;
    final memoryBank = List<String>.from(existing?.memoryBank ?? const []);

    if (converged) {
      if (bestRounds == null || roundsCount < bestRounds) {
        bestRounds = roundsCount;
        bestWord = convergedWord;
      }
      if (convergedWord != null && convergedWord.trim().isNotEmpty) {
        final norm = convergedWord.trim().toLowerCase();
        if (!memoryBank.contains(norm)) {
          memoryBank.add(norm);
        }
      }
    }

    _friends[friendId] = Friend(
      id: friendId,
      name: friendName,
      lastPlayedAt: DateTime.now(),
      gamesPlayed: currentGames,
      totalRounds: currentTotalRounds,
      bestSyncRounds: bestRounds,
      bestSyncWord: bestWord,
      memoryBank: memoryBank,
    );
    await _persistFriends();
    _emitFriends();
  }

  @override
  Future<void> forgetFriend(String friendId) async {
    _friends.remove(friendId);
    await _persistFriends();
    _emitFriends();
  }

  @override
  Future<Room> inviteFriend({
    required String friendId,
    GameConfig config = GameConfig.defaults,
  }) => createRoom(config: config);

  @override
  Stream<List<GameInvite>> watchInvites() => Stream.value(const []);

  @override
  Future<void> dismissInvite(String roomCode) async {}

  Future<void> _persistFriends() async {
    final encoded = jsonEncode(
      _friends.values
          .map(
            (f) => {
              ...f.toMap(),
              'lastPlayedAt': f.lastPlayedAt?.toIso8601String(),
            },
          )
          .toList(),
    );
    await _prefs?.setString('local_friends', encoded);
  }

  void _emitFriends() {
    if (_friendStream.isClosed) return;
    final list = _friends.values.toList()
      ..sort(
        (a, b) => (b.lastPlayedAt ?? DateTime(0)).compareTo(
          a.lastPlayedAt ?? DateTime(0),
        ),
      );
    _friendStream.add(list);
  }

  // ------------------------------------------------------------------ bot

  void _botJoin(String code) {
    final room = _rooms[code];
    if (room == null || room.isFull) return;
    _publish(
      room.copyWith(
        players: [...room.players, botId],
        playerNames: {...room.playerNames, botId: botName},
        playerAvatars: {
          ...room.playerAvatars,
          botId: AppAvatars.forName(botName),
        },
        status: RoomStatus.active,
      ),
    );
    _schedule(
      const Duration(milliseconds: 900),
      () => _appendMessage(code, senderId: botId, text: 'Ready when you are.'),
    );
  }


  void _botSubmitPlayer(String code, int roundIndex, String botPlayerId) {
    final room = _rooms[code];
    if (room == null || room.status == RoomStatus.finished) return;
    if (room.currentRound != roundIndex) return;
    if (room.hasSubmitted(botPlayerId)) return;
    if (!room.players.contains(botPlayerId)) return;

    final word = _botWord(room, humanId: _uid);
    (_submissions[code] ??= {}).putIfAbsent(roundIndex, () => {})[botPlayerId] = word;
    _publish(room.copyWith(submittedBy: {...room.submittedBy, botPlayerId}.toList()));
  }

  String _botChatReply(String userText) {
    final text = userText.toLowerCase();
    if (text.contains('hint')) return 'hint: think where those two overlap 🌉';
    if (text.contains('twin')) return 'twin!! 🎉';
    if (text.endsWith('?')) {
      final q = ['hmm good question 🤔', 'no idea, you?', 'maybe... 🤫'];
      return q[_random.nextInt(q.length)];
    }
    const banter = [
      "haha same, don't tell me!",
      "we're so close",
      'ok I think I see where you are going',
      '😂😂',
      'this one is tricky',
      'I had something completely different lol',
      'say more, I need a hint 👀',
    ];
    return banter[_random.nextInt(banter.length)];
  }

  void _seedDemoState() {
    const ivy = 'partner-ivy';
    const leo = 'partner-leo';
    const zoe = 'partner-zoe';
    const maya = 'partner-maya';
    const sam = 'partner-sam';

    _friends.putIfAbsent(
      ivy,
      () => Friend(
        id: ivy,
        name: 'Ivy',
        lastPlayedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        gamesPlayed: 1,
        totalRounds: 1,
        bestSyncRounds: null,
        bestSyncWord: null,
        memoryBank: const [],
      ),
    );
    _friends.putIfAbsent(
      leo,
      () => Friend(
        id: leo,
        name: 'Leo',
        lastPlayedAt: DateTime.now().subtract(const Duration(minutes: 8)),
        gamesPlayed: 4,
        totalRounds: 14,
        bestSyncRounds: 3,
        bestSyncWord: 'bridge',
        memoryBank: const ['bridge'],
      ),
    );
    _friends.putIfAbsent(
      zoe,
      () => Friend(
        id: zoe,
        name: 'Zoe',
        lastPlayedAt: DateTime.now().subtract(const Duration(minutes: 18)),
        gamesPlayed: 2,
        totalRounds: 6,
        bestSyncRounds: 4,
        bestSyncWord: 'oasis',
        memoryBank: const ['oasis'],
      ),
    );
    _friends.putIfAbsent(
      maya,
      () => Friend(
        id: maya,
        name: 'Maya',
        lastPlayedAt: DateTime.now().subtract(const Duration(minutes: 28)),
        gamesPlayed: 3,
        totalRounds: 10,
        bestSyncRounds: 3,
        bestSyncWord: 'dusk',
        memoryBank: const ['dusk'],
      ),
    );

    // ROOM 1: Leo — Round 4, active ("Your turn", Leo locked in)
    // Rounds: Round 1 (HI / MIDNIGHT), Round 2 (BRIDGE / HOME), Round 3 (WATER / BRIDGE)
    // Active stickers: WATER (Lime) & BRIDGE (Coral)
    final rLeo4 = Room(
      code: 'LEO04',
      hostId: _uid,
      players: [_uid, leo],
      playerNames: {_uid: _displayName, leo: 'Leo'},
      playerAvatars: {_uid: _avatarId, leo: AppAvatars.forName('Leo')},
      status: RoomStatus.active,
      config: const GameConfig(),
      currentRound: 4,
      submittedBy: [leo],
      rounds: [
        GameRound(
          index: 1,
          p1Word: 'hi',
          p2Word: 'midnight',
          matched: false,
          revealedAt: DateTime.now().subtract(const Duration(minutes: 40)),
        ),
        GameRound(
          index: 2,
          p1Word: 'bridge',
          p2Word: 'home',
          matched: false,
          revealedAt: DateTime.now().subtract(const Duration(minutes: 25)),
        ),
        GameRound(
          index: 3,
          p1Word: 'water',
          p2Word: 'bridge',
          matched: false,
          revealedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(minutes: 50)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
    );
    _rooms['LEO04'] = rLeo4;
    _submissions['LEO04'] = {
      1: {_uid: 'hi', leo: 'midnight'},
      2: {_uid: 'bridge', leo: 'home'},
      3: {_uid: 'water', leo: 'bridge'},
      4: {leo: 'island'},
    };
    _messages['LEO04'] = [
      ChatMessage(
        id: 'sys-leo-1',
        senderId: 'system',
        text: 'hint: think where those two overlap 🌉',
        sentAt: DateTime.now().subtract(const Duration(minutes: 11)),
      ),
      ChatMessage(
        id: 'sys-leo-2',
        senderId: 'system',
        text: 'Round 2: BRIDGE vs HOME — no match',
        sentAt: DateTime.now().subtract(const Duration(minutes: 10)),
        system: true,
        round: 2,
        wordA: 'bridge',
        wordB: 'home',
        matched: false,
      ),
      ChatMessage(
        id: 'msg-leo-1',
        senderId: leo,
        text: 'different this time for sure',
        sentAt: DateTime.now().subtract(const Duration(minutes: 9)),
      ),
      ChatMessage(
        id: 'sys-leo-3',
        senderId: 'system',
        text: 'Round 3: WATER vs BRIDGE — no match',
        sentAt: DateTime.now().subtract(const Duration(minutes: 8)),
        system: true,
        round: 3,
        wordA: 'water',
        wordB: 'bridge',
        matched: false,
      ),
      ChatMessage(
        id: 'msg-leo-2',
        senderId: leo,
        text: 'no match 😅 let us go again',
        sentAt: DateTime.now().subtract(const Duration(minutes: 7)),
      ),
      ChatMessage(
        id: 'msg-leo-3',
        senderId: _uid,
        text: 'Hint?',
        sentAt: DateTime.now().subtract(const Duration(minutes: 6)),
      ),
      ChatMessage(
        id: 'msg-leo-4',
        senderId: leo,
        text: 'hint: think where those two overlap\n🌉',
        sentAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ];

    // ROOM 2: Zoe — Round 3, active ("Your turn", unread badge: 1)
    final rZoe3 = Room(
      code: 'ZOE03',
      hostId: _uid,
      players: [_uid, zoe],
      playerNames: {_uid: _displayName, zoe: 'Zoe'},
      playerAvatars: {_uid: _avatarId, zoe: AppAvatars.forName('Zoe')},
      status: RoomStatus.active,
      config: const GameConfig(),
      currentRound: 3,
      submittedBy: const [],
      rounds: [
        GameRound(
          index: 1,
          p1Word: 'sun',
          p2Word: 'moon',
          matched: false,
          revealedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
        GameRound(
          index: 2,
          p1Word: 'ocean',
          p2Word: 'desert',
          matched: false,
          revealedAt: DateTime.now().subtract(const Duration(minutes: 18)),
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 18)),
    );
    _rooms['ZOE03'] = rZoe3;
    _submissions['ZOE03'] = {
      1: {_uid: 'sun', zoe: 'moon'},
      2: {_uid: 'ocean', zoe: 'desert'},
    };
    _messages['ZOE03'] = [
      ChatMessage(
        id: 'msg-zoe-1',
        senderId: zoe,
        text: "oasis would be great for round 3!",
        sentAt: DateTime.now().subtract(const Duration(minutes: 17)),
      ),
    ];

    // ROOM 3: Maya — Round 2, active ("Your turn")
    final rMaya2 = Room(
      code: 'MAY02',
      hostId: _uid,
      players: [_uid, maya],
      playerNames: {_uid: _displayName, maya: 'Maya'},
      playerAvatars: {_uid: _avatarId, maya: AppAvatars.forName('Maya')},
      status: RoomStatus.active,
      config: const GameConfig(),
      currentRound: 2,
      submittedBy: const [],
      rounds: [
        GameRound(
          index: 1,
          p1Word: 'coffee',
          p2Word: 'tea',
          matched: false,
          revealedAt: DateTime.now().subtract(const Duration(minutes: 28)),
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(minutes: 32)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 28)),
    );
    _rooms['MAY02'] = rMaya2;
    _submissions['MAY02'] = {
      1: {_uid: 'coffee', maya: 'tea'},
    };
    _messages['MAY02'] = [
      ChatMessage(
        id: 'sys-may-1',
        senderId: 'system',
        text: 'Round 1: COFFEE vs TEA — no match',
        sentAt: DateTime.now().subtract(const Duration(minutes: 28)),
        system: true,
        round: 1,
        wordA: 'coffee',
        wordB: 'tea',
        matched: false,
      ),
    ];

    // ROOM 4: Leo — Round 3, active ("Your turn", unread badge: 1)
    final rLeo3 = Room(
      code: 'LEO03',
      hostId: _uid,
      players: [_uid, leo],
      playerNames: {_uid: _displayName, leo: 'Leo'},
      playerAvatars: {_uid: _avatarId, leo: AppAvatars.forName('Leo')},
      status: RoomStatus.active,
      config: const GameConfig(),
      currentRound: 3,
      submittedBy: const [],
      rounds: [
        GameRound(
          index: 1,
          p1Word: 'fire',
          p2Word: 'water',
          matched: false,
          revealedAt: DateTime.now().subtract(const Duration(minutes: 50)),
        ),
        GameRound(
          index: 2,
          p1Word: 'steam',
          p2Word: 'cloud',
          matched: false,
          revealedAt: DateTime.now().subtract(const Duration(minutes: 20)),
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(minutes: 60)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
    );
    _rooms['LEO03'] = rLeo3;
    _submissions['LEO03'] = {
      1: {_uid: 'fire', leo: 'water'},
      2: {_uid: 'steam', leo: 'cloud'},
    };
    _messages['LEO03'] = [
      ChatMessage(
        id: 'msg-leo-3b',
        senderId: leo,
        text: 'think rain!',
        sentAt: DateTime.now().subtract(const Duration(minutes: 19)),
      ),
    ];

    // ROOM 5: Ivy — Round 1 ("Your turn", Ivy locked in) matching Screenshot 2026-10-14 at 19.09.10
    final rIvy1 = Room(
      code: 'IVY01',
      hostId: _uid,
      players: [_uid, ivy],
      playerNames: {_uid: _displayName, ivy: 'Ivy'},
      playerAvatars: {_uid: _avatarId, ivy: AppAvatars.forName('Ivy')},
      status: RoomStatus.active,
      config: const GameConfig(),
      currentRound: 1,
      submittedBy: [ivy],
      rounds: const [],
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    _rooms['IVY01'] = rIvy1;
    _submissions['IVY01'] = {
      1: {ivy: 'apple'},
    };
    _messages['IVY01'] = [
      ChatMessage(
        id: 'msg-ivy-1',
        senderId: ivy,
        text: 'hey! let us match words!',
        sentAt: DateTime.now().subtract(const Duration(minutes: 4)),
      ),
    ];

    // Finished game records for History
    _rooms['T2WQN'] = Room(
      code: 'T2WQN',
      hostId: _uid,
      players: [_uid, maya],
      playerNames: {_uid: _displayName, maya: 'Maya'},
      playerAvatars: {_uid: _avatarId, maya: AppAvatars.forName('Maya')},
      status: RoomStatus.finished,
      finishReason: FinishReason.converged,
      config: const GameConfig(),
      currentRound: 3,
      submittedBy: const [],
      rounds: const [
        GameRound(index: 1, p1Word: 'night', p2Word: 'day', matched: false),
        GameRound(index: 2, p1Word: 'dark', p2Word: 'light', matched: false),
        GameRound(index: 3, p1Word: 'dusk', p2Word: 'dusk', matched: true),
      ],
      createdAt: DateTime.now().subtract(const Duration(hours: 10)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 9)),
    );

    _rooms['H5JRD'] = Room(
      code: 'H5JRD',
      hostId: _uid,
      players: [_uid, leo],
      playerNames: {_uid: _displayName, leo: 'Leo'},
      playerAvatars: {_uid: _avatarId, leo: AppAvatars.forName('Leo')},
      status: RoomStatus.finished,
      finishReason: FinishReason.converged,
      config: const GameConfig(),
      currentRound: 5,
      submittedBy: const [],
      rounds: const [
        GameRound(index: 1, p1Word: 'bread', p2Word: 'butter', matched: false),
        GameRound(index: 2, p1Word: 'toast', p2Word: 'jam', matched: false),
        GameRound(index: 3, p1Word: 'morning', p2Word: 'breakfast', matched: false),
        GameRound(index: 4, p1Word: 'kitchen', p2Word: 'cafe', matched: false),
        GameRound(index: 5, p1Word: 'brunch', p2Word: 'brunch', matched: true),
      ],
      createdAt: DateTime.now().subtract(const Duration(hours: 33)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 32)),
    );

    _rooms['D9CKL'] = Room(
      code: 'D9CKL',
      hostId: _uid,
      players: [_uid, sam],
      playerNames: {_uid: _displayName, sam: 'Sam'},
      playerAvatars: {_uid: _avatarId, sam: AppAvatars.forName('Sam')},
      status: RoomStatus.finished,
      finishReason: FinishReason.maxRounds,
      config: const GameConfig(maxRounds: 5),
      currentRound: 5,
      submittedBy: const [],
      rounds: const [
        GameRound(index: 1, p1Word: 'entropy', p2Word: 'silence', matched: false),
        GameRound(index: 2, p1Word: 'gravity', p2Word: 'nostalgia', matched: false),
        GameRound(index: 3, p1Word: 'memory', p2Word: 'infinity', matched: false),
        GameRound(index: 4, p1Word: 'chaos', p2Word: 'geometry', matched: false),
        GameRound(index: 5, p1Word: 'solitude', p2Word: 'echo', matched: false),
      ],
      createdAt: DateTime.now().subtract(const Duration(hours: 50)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 49)),
    );
  }


  /// A plausible partner, not a clever one.
  ///
  /// Round 1 is a random seed word. After that the bot behaves like a
  /// cooperative human: with a chance that grows every round it plays back the
  /// word *you* just used, trying to meet you where you are. So if you hold a
  /// word steady, the game converges. Otherwise it offers another seed word.
  ///
  /// There is no cleverness available here by design — the app ships no word
  /// list or meaning model, so a bot cannot reason about which words are
  /// "between" two others. This is practice mode; real games are against people.
  String _botWord(Room room, {required String humanId}) {
    final previous = room.lastRound;
    if (previous == null) {
      return _seedWords[_random.nextInt(_seedWords.length)];
    }

    final yourLastWord = previous.wordFor(humanId, p1Id: room.p1Id);

    // Round 2: 1 in 3. Round 5: 2 in 3. Converges without being instant.
    final convergePressure = min(0.85, 0.15 * room.rounds.length + 0.15);
    if (yourLastWord.isNotEmpty && _random.nextDouble() < convergePressure) {
      return normalizeWord(yourLastWord);
    }

    final used = <String>{
      for (final r in room.rounds) ...[r.p1Word, r.p2Word],
    };
    final fresh = _seedWords.where((w) => !used.contains(w)).toList();
    return fresh.isEmpty
        ? normalizeWord(yourLastWord.isEmpty ? _seedWords.first : yourLastWord)
        : fresh[_random.nextInt(fresh.length)];
  }

  // -------------------------------------------------------------- plumbing

  void _publish(Room room) {
    _rooms[room.code] = room;
    _roomStreams[room.code]?.add(room);
    _emitMyRooms();
    _persistRooms();
  }

  @override
  Future<void> addPracticePartner(String code) async {
    final room = _rooms[code];
    if (room == null) {
      throw const BackendException('That room no longer exists.');
    }
    if (room.isFull) return;
    _botJoin(code);
  }

  void _schedule(Duration delay, void Function() action) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      action();
    });
    _timers.add(timer);
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    for (final c in _roomStreams.values) {
      c.close();
    }
    for (final c in _messageStreams.values) {
      c.close();
    }
    _friendStream.close();
    _myRoomsStream.close();
  }
}
