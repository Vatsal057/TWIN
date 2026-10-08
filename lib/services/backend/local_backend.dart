import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/game_config.dart';
import '../../core/word_utils.dart';
import '../../models/chat_message.dart';
import '../../models/friend.dart';
import '../../models/game_invite.dart';
import '../../models/room.dart';
import '../room_code.dart';
import 'game_backend.dart';

/// Single-device backend used when Firebase is not configured.
///
/// It implements the same [GameBackend] contract as [FirestoreBackend] and
/// stands in for the second player, so the full round loop — private
/// submissions, simultaneous reveal, convergence — is
/// playable and inspectable without any cloud setup. It does **not** sync
/// across devices; real two-player games need the Firestore backend.
class LocalBackend implements GameBackend {
  LocalBackend({String displayName = 'You'}) : _displayName = displayName;

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
  String _uid = 'local-player';

  final Map<String, Room> _rooms = {};
  final Map<String, StreamController<Room>> _roomStreams = {};
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
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _uid =
        _prefs?.getString('local_uid') ?? 'local-${_random.nextInt(1 << 32)}';
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
    _emitFriends();
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

  // ---------------------------------------------------------------- rooms

  @override
  Future<Room> createRoom({
    GameConfig config = GameConfig.defaults,
    String? rematchOf,
    bool isPublic = false,
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
      status: RoomStatus.waiting,
      config: config,
      currentRound: 1,
      submittedBy: const [],
      rounds: const [],
      rematchOf: rematchOf,
      createdAt: DateTime.now(),
      isPublic: isPublic,
    );
    _rooms[code] = room;
    _submissions[code] = {};
    _messages[code] = [];

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

    // The bot answers after a beat so the "waiting for opponent" state is real.
    _schedule(
      Duration(milliseconds: 700 + _random.nextInt(900)),
      () => _botSubmit(code, roundIndex),
    );
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

  @override
  Stream<List<Friend>> watchFriends() {
    _schedule(Duration.zero, _emitFriends);
    return _friendStream.stream;
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
  Future<Room> findOrCreateQuickPlayRoom({
    GameConfig config = GameConfig.defaults,
  }) => createRoom(config: config, isPublic: true);

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
        status: RoomStatus.active,
      ),
    );
    _schedule(
      const Duration(milliseconds: 900),
      () => _appendMessage(code, senderId: botId, text: 'Ready when you are.'),
    );
  }

  void _botSubmit(String code, int roundIndex) {
    final room = _rooms[code];
    if (room == null || room.status == RoomStatus.finished) return;
    if (room.currentRound != roundIndex) return;
    if (room.hasSubmitted(botId)) return;
    if (!room.players.contains(botId)) return;

    final word = _botWord(room, humanId: _uid);
    (_submissions[code] ??= {}).putIfAbsent(roundIndex, () => {})[botId] = word;
    _publish(room.copyWith(submittedBy: {...room.submittedBy, botId}.toList()));
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
  }
}
