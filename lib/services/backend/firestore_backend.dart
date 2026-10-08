import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/game_config.dart';
import '../../models/chat_message.dart';
import '../../models/friend.dart';
import '../../models/game_invite.dart';
import '../../models/room.dart';
import '../room_code.dart';
import 'game_backend.dart';

/// Firestore is the whole backend: no custom server, no sockets. Both clients
/// hold a live listener on `/rooms/{code}` and react to document changes, which
/// is what makes the two-player transitions feel instant.
class FirestoreBackend implements GameBackend {
  FirestoreBackend({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String displayName = 'Player',
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _displayName = displayName;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String _displayName;
  String _uid = '';

  @override
  String get localPlayerId => _uid;

  @override
  bool get isNetworked => true;

  @override
  String get label => 'Firestore';

  @override
  String get displayName => _displayName;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('rooms');

  DocumentReference<Map<String, dynamic>> _room(String code) =>
      _rooms.doc(code);

  CollectionReference<Map<String, dynamic>> _submissions(String code) =>
      _room(code).collection('submissions');

  CollectionReference<Map<String, dynamic>> _messages(String code) =>
      _room(code).collection('messages');

  CollectionReference<Map<String, dynamic>> get _friends =>
      _db.collection('users').doc(_uid).collection('friends');

  static String submissionId(int roundIndex, String playerId) =>
      '${roundIndex}_$playerId';

  /// Turns a raw [FirebaseException] into something a player can act on.
  ///
  /// Without this the UI falls back to a generic "could not do that", which
  /// hides the difference between a network blip, an expired session, and rules
  /// that were never deployed — three problems with three different fixes.
  static BackendException _translate(Object error, String fallback) {
    if (error is BackendException) return error;
    if (error is FirebaseException) {
      final message = switch (error.code) {
        'permission-denied' =>
          'The server refused that write. If this project was just set up, '
              'deploy the rules: firebase deploy --only firestore:rules',
        'unauthenticated' => 'Your session expired. Restart the app.',
        'unavailable' || 'deadline-exceeded' =>
          'Could not reach the server. Check your connection and try again.',
        'not-found' => 'That room no longer exists.',
        'already-exists' => 'That already exists. Try again.',
        'resource-exhausted' =>
          'The project hit its Firestore quota for today.',
        'failed-precondition' =>
          'Firestore is not ready for this request. It may still be '
              'provisioning, or an index is missing.',
        // Keep the plugin's own text: for anything unrecognised it is the only
        // clue about what actually went wrong.
        _ => [
          fallback,
          if (error.message != null && error.message!.isNotEmpty) error.message,
          '(${error.code})',
        ].join(' '),
      };
      return BackendException(message, code: error.code);
    }
    return BackendException(fallback);
  }

  /// Runs [operation], surfacing failures as readable [BackendException]s.
  static Future<T> _guard<T>(
    Future<T> Function() operation,
    String fallback,
  ) async {
    try {
      return await operation();
    } catch (error, stack) {
      debugPrint('FirestoreBackend: $fallback -> $error\n$stack');
      throw _translate(error, fallback);
    }
  }

  @override
  Future<void> initialize() async {
    // Anonymous auth gives every device a stable uid, which is what the
    // security rules key off. No sign-up friction for the player.
    var user = _auth.currentUser;
    user ??= (await _auth.signInAnonymously()).user;
    if (user == null) {
      throw const BackendException('Could not sign in anonymously');
    }
    _uid = user.uid;
  }

  @override
  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _displayName = trimmed;
    if (_uid.isEmpty) return;
    await _db.collection('users').doc(_uid).set({
      'displayName': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------- rooms

  @override
  Future<Room> createRoom({
    GameConfig config = GameConfig.defaults,
    String? rematchOf,
  }) async {
    _requireAuth();

    // Uniqueness is enforced by the datastore, not by hoping: the transaction
    // only writes when the code document does not already exist. Note this
    // means the rules must permit reading a room doc that does not exist yet.
    for (var attempt = 0; attempt < 8; attempt++) {
      final code = RoomCode.generate();
      final ref = _room(code);
      final created = await _guard(
        () => _db.runTransaction<bool>((tx) async {
          final snap = await tx.get(ref);
          if (snap.exists) return false;
          tx.set(ref, {
            'code': code,
            'hostId': _uid,
            'players': [_uid],
            'playerNames': {_uid: _displayName},
            'status': RoomStatus.waiting.wireName,
            'config': config.toMap(),
            'currentRound': 1,
            'submittedBy': <String>[],
            'rounds': <Map<String, Object?>>[],
            'finishReason': null,
            'rematchOf': rematchOf,
            'rematchRoomCode': null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return true;
        }),
        'Could not create a room.',
      );

      if (created) {
        final room = await fetchRoom(code);
        if (room != null) return room;
      }
    }
    throw const BackendException(
      'Could not reserve a room code. Please try again.',
    );
  }

  @override
  Future<Room> joinRoom(String rawCode) async {
    _requireAuth();
    final code = RoomCode.normalize(rawCode);
    if (!RoomCode.isValid(code)) {
      throw const BackendException('That room code does not look right.');
    }

    final ref = _room(code);

    // Every reason a join can legitimately fail is checked here, on a plain
    // read, *before* the transaction.
    //
    // This is not just tidiness. Anything thrown inside `runTransaction` gets
    // wrapped by the plugin — cloud_firestore_web runs the handler through
    // convertWebExceptions — so a BackendException raised in there comes back
    // out as an opaque FirebaseException. Every specific message below used to
    // reach the player as a useless "Could not join that room."
    final snapshot = await _guard(
      () => ref.get(),
      'Could not reach that room.',
    );
    if (!snapshot.exists) {
      throw const BackendException(
        'No room with that code. Check the letters and try again.',
        code: 'not-found',
      );
    }
    final room = Room.fromMap(code, snapshot.data()!);

    if (room.players.contains(_uid)) {
      // Reconnecting to a game already in progress is fine. Typing your own
      // code into "Join room" is not.
      //
      // Two tabs of one browser share the same anonymous id, so this is exactly
      // what happens when someone tries to play both sides alone.
      if (!room.isFull) {
        throw const BackendException(
          'This is your own room. Send the code to the other player — you '
          'cannot be both players.',
          code: 'own-room',
        );
      }
      await _guard(
        () => ref.update({
          'playerNames.$_uid': _displayName,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        'Could not rejoin that room.',
      );
      final rejoined = await fetchRoom(code);
      if (rejoined == null) {
        throw const BackendException('Could not load that room.');
      }
      return rejoined;
    }

    if (room.isFull) {
      throw const BackendException(
        'That room already has two players.',
        code: 'full',
      );
    }
    if (room.status == RoomStatus.finished) {
      throw const BackendException(
        'That game has already finished. Ask for a new code.',
        code: 'finished',
      );
    }

    // The transaction now only guards against two people racing for the last
    // seat, and deliberately raises nothing of its own.
    await _guard(
      () => _db.runTransaction((tx) async {
        final fresh = await tx.get(ref);
        if (!fresh.exists) return;
        final current = Room.fromMap(code, fresh.data()!);
        if (current.players.contains(_uid) || current.isFull) return;

        tx.update(ref, {
          'players': FieldValue.arrayUnion([_uid]),
          'playerNames.$_uid': _displayName,
          // Both clients are listening; this is the flip that moves them into
          // the game at the same moment.
          'status': RoomStatus.active.wireName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }),
      'Could not join that room.',
    );

    final joined = await fetchRoom(code);
    if (joined == null) {
      throw const BackendException('Could not load that room.');
    }
    if (!joined.players.contains(_uid)) {
      // Lost the race for the second seat.
      throw const BackendException(
        'Someone else just took the second seat in that room.',
        code: 'full',
      );
    }
    return joined;
  }

  @override
  Stream<Room> watchRoom(String code) {
    return _room(code).snapshots().where((s) => s.exists).map((snap) {
      return Room.fromMap(code, snap.data()!);
    });
  }

  @override
  Future<Room?> fetchRoom(String code) async {
    final snap = await _room(code).get();
    if (!snap.exists) return null;
    return Room.fromMap(code, snap.data()!);
  }

  @override
  Future<void> submitWord({
    required String code,
    required int roundIndex,
    required String word,
  }) async {
    _requireAuth();
    final batch = _db.batch();

    // The word lands in a per-player doc that the opponent cannot read until
    // both are in — that is what keeps round 1 genuinely private.
    batch.set(_submissions(code).doc(submissionId(roundIndex, _uid)), {
      'playerId': _uid,
      'roundIndex': roundIndex,
      'word': word,
      'submittedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_room(code), {
      'submittedBy': FieldValue.arrayUnion([_uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _guard(batch.commit, 'Could not send your word.');
  }

  @override
  Future<({String p1Word, String p2Word})?> readSubmissions({
    required String code,
    required int roundIndex,
  }) async {
    final room = await fetchRoom(code);
    if (room == null || !room.isFull) return null;
    return _readSubmissionsFor(room, roundIndex);
  }

  Future<({String p1Word, String p2Word})?> _readSubmissionsFor(
    Room room,
    int roundIndex,
  ) async {
    final p2 = room.p2Id;
    if (p2 == null) return null;
    final results = await Future.wait([
      _submissions(room.code).doc(submissionId(roundIndex, room.p1Id)).get(),
      _submissions(room.code).doc(submissionId(roundIndex, p2)).get(),
    ]);
    if (!results[0].exists || !results[1].exists) return null;
    final p1Word = (results[0].data()?['word'] as String?) ?? '';
    final p2Word = (results[1].data()?['word'] as String?) ?? '';
    if (p1Word.isEmpty || p2Word.isEmpty) return null;
    return (p1Word: p1Word, p2Word: p2Word);
  }

  @override
  Future<void> commitRound({
    required String code,
    required int roundIndex,
    required RoundResolver resolve,
  }) async {
    _requireAuth();

    final room = await fetchRoom(code);
    if (room == null) return;
    if (room.rounds.length >= roundIndex) return; // already resolved

    final words = await _readSubmissionsFor(room, roundIndex);
    if (words == null) return; // opponent has not landed yet

    final ref = _room(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final fresh = Room.fromMap(code, snap.data()!);

      // Both clients race to commit; whoever loses sees the round already
      // present and backs out. The outcome is plain string equality, so either
      // winner writes identical history.
      if (fresh.rounds.length >= roundIndex) return;

      final resolution = resolve(fresh, words.p1Word, words.p2Word);
      final history = [
        ...fresh.rounds.map((r) => r.toMap()),
        resolution.round.toMap(),
      ];

      tx.update(ref, {
        'rounds': history,
        'status': resolution.status.wireName,
        'currentRound': resolution.nextRound,
        'submittedBy': <String>[],
        'finishReason': resolution.finishReason?.wireName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> leaveRoom(String code) async {
    if (_uid.isEmpty) return;
    final ref = _room(code);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final room = Room.fromMap(code, snap.data()!);
        if (room.status == RoomStatus.finished) return;
        tx.update(ref, {
          'status': RoomStatus.finished.wireName,
          'finishReason': FinishReason.abandoned.wireName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException {
      // Leaving is best-effort; never block the player from backing out.
    }
  }

  @override
  Future<Room> startRematch(Room room) async {
    final fresh = await createRoom(config: room.config, rematchOf: room.code);
    try {
      await _room(room.code).update({
        'rematchRoomCode': fresh.code,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      // The opponent can still join by code if the pointer write fails.
    }
    return fresh;
  }

  // ----------------------------------------------------------------- chat

  @override
  Stream<List<ChatMessage>> watchMessages(String code) {
    return _messages(code).orderBy('sentAt').limit(500).snapshots().map((snap) {
      final messages = snap.docs.map((doc) {
        final data = doc.data();
        return ChatMessage(
          id: doc.id,
          senderId: (data['senderId'] as String?) ?? '',
          text: (data['text'] as String?) ?? '',
          sentAt: _toDate(data['sentAt']) ?? _toDate(data['clientSentAt']),
          pending: doc.metadata.hasPendingWrites,
        );
      }).toList();

      // Messages awaiting a server timestamp fall back to the client clock
      // so the stream never jumps around as writes settle.
      messages.sort((a, b) {
        final at = a.sentAt;
        final bt = b.sentAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return at.compareTo(bt);
      });
      return messages;
    });
  }

  @override
  Future<void> sendMessage({required String code, required String text}) async {
    _requireAuth();
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _guard(
      () => _messages(code).add({
        'senderId': _uid,
        'text': trimmed.length > 500 ? trimmed.substring(0, 500) : trimmed,
        'sentAt': FieldValue.serverTimestamp(),
        'clientSentAt': Timestamp.now(),
      }),
      'Message did not send.',
    );
  }

  // -------------------------------------------------------------- friends

  @override
  Stream<List<Friend>> watchFriends() {
    if (_uid.isEmpty) return Stream.value(const []);
    return _friends.snapshots().map((snap) {
      final friends = snap.docs
          .map(
            (doc) => Friend(
              id: doc.id,
              name: (doc.data()['name'] as String?) ?? 'Player',
              gamesPlayed: (doc.data()['gamesPlayed'] as num?)?.toInt() ?? 0,
              lastPlayedAt: _toDate(doc.data()['lastPlayedAt']),
            ),
          )
          .toList();
      friends.sort((a, b) {
        final at = a.lastPlayedAt;
        final bt = b.lastPlayedAt;
        if (at == null && bt == null) return a.name.compareTo(b.name);
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
      return friends;
    });
  }

  @override
  Future<void> rememberPairing({
    required String friendId,
    required String friendName,
  }) async {
    if (_uid.isEmpty || friendId.isEmpty || friendId == _uid) return;
    // Each client writes only its own friends subcollection, so the security
    // rules stay a simple "owner only" check.
    await _friends.doc(friendId).set({
      'friendId': friendId,
      'name': friendName,
      'lastPlayedAt': FieldValue.serverTimestamp(),
      'gamesPlayed': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> forgetFriend(String friendId) async {
    if (_uid.isEmpty) return;
    await _friends.doc(friendId).delete();
  }

  @override
  Future<Room> inviteFriend({
    required String friendId,
    GameConfig config = GameConfig.defaults,
  }) async {
    _requireAuth();
    final room = await createRoom(config: config);
    await _db
        .collection('users')
        .doc(friendId)
        .collection('invites')
        .doc(room.code)
        .set({
          'roomCode': room.code,
          'fromId': _uid,
          'fromName': _displayName,
          'createdAt': FieldValue.serverTimestamp(),
        });
    return room;
  }

  @override
  Stream<List<GameInvite>> watchInvites() {
    if (_uid.isEmpty) return Stream.value(const []);
    return _db
        .collection('users')
        .doc(_uid)
        .collection('invites')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => GameInvite.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> dismissInvite(String roomCode) async {
    if (_uid.isEmpty) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('invites')
        .doc(roomCode)
        .delete();
  }

  @override
  void dispose() {}

  void _requireAuth() {
    if (_uid.isEmpty) {
      throw const BackendException('Not signed in yet.');
    }
  }

  static DateTime? _toDate(Object? value) => switch (value) {
    final Timestamp t => t.toDate(),
    final DateTime d => d,
    final String s => DateTime.tryParse(s),
    _ => null,
  };
}
