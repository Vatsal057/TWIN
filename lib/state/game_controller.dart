import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/word_utils.dart';
import '../game/game_engine.dart';
import '../models/game_round.dart';
import '../models/room.dart';
import '../services/backend/game_backend.dart';

/// What the game screen should render right now.
enum ViewStage {
  connecting,
  waitingForPlayers,
  composing,
  waitingForOpponent,
  revealing,
  finished,
}

/// Drives one room: mirrors the live room document, resolves rounds and exposes
/// a single [stage] for the UI to switch on.
///
/// Round resolution is deliberately client-side and idempotent. Both clients
/// notice `submittedBy.length == 2`, both compute the same outcome from the same
/// bundled embeddings, and the backend's transaction lets exactly one write
/// land. No server code needed, no trust placed in one device.
class GameController extends ChangeNotifier {
  GameController({
    required GameBackend backend,
    required GameEngine engine,
    required String roomCode,
  }) : _backend = backend,
       _engine = engine,
       _roomCode = roomCode;

  static const revealDuration = Duration(milliseconds: 2600);

  final GameBackend _backend;
  final GameEngine _engine;
  final String _roomCode;

  StreamSubscription<Room>? _roomSub;
  Timer? _revealTimer;

  Room? _room;
  String? _errorMessage;
  bool _committing = false;
  bool _submitting = false;
  bool _pairingRemembered = false;

  /// Round currently being shown in the reveal overlay.
  GameRound? _revealing;

  /// The word this player locked in for the current round, kept locally so the
  /// waiting state can show it without breaking submission privacy.
  String? _myPendingWord;

  int _seenRoundCount = 0;

  String get roomCode => _roomCode;
  Room? get room => _room;
  String get localPlayerId => _backend.localPlayerId;
  String? get errorMessage => _errorMessage;
  GameRound? get revealingRound => _revealing;
  String? get myPendingWord => _myPendingWord;
  bool get isSubmitting => _submitting;
  bool get isHost => _room?.hostId == localPlayerId;

  List<GameRound> get history => _room?.rounds ?? const [];

  String? get opponentId => _room?.opponentOf(localPlayerId);
  String get opponentName => _room?.nameOf(opponentId) ?? 'Opponent';
  String get localName => _room?.nameOf(localPlayerId) ?? 'You';

  int get myScore => _room?.scoreOf(localPlayerId) ?? 0;
  int get opponentScore {
    final id = opponentId;
    return id == null ? 0 : (_room?.scoreOf(id) ?? 0);
  }

  /// 1-based round the player is composing for.
  int get currentRound => _room?.currentRound ?? 1;
  /// Null when the game is unlimited.
  int? get maxRounds => _room?.config.maxRounds;

  /// The pair to converge on. Null during round 1, which has no anchor.
  GameRound? get anchorRound {
    final rounds = _room?.rounds;
    if (rounds == null || rounds.isEmpty) return null;
    return rounds.last;
  }

  bool get isFirstRound => (_room?.rounds.isEmpty ?? true);

  ViewStage get stage {
    final room = _room;
    if (room == null) return ViewStage.connecting;
    if (_revealing != null) return ViewStage.revealing;
    return switch (_engine.phaseFor(room, localPlayerId)) {
      GamePhase.finished => ViewStage.finished,
      GamePhase.waitingForPlayers => ViewStage.waitingForPlayers,
      GamePhase.composing => ViewStage.composing,
      GamePhase.waitingForOpponent => ViewStage.waitingForOpponent,
      GamePhase.resolving => ViewStage.waitingForOpponent,
    };
  }

  void start() {
    _roomSub = _backend
        .watchRoom(_roomCode)
        .listen(_onRoom, onError: _onStreamError);
  }

  void _onStreamError(Object error) {
    _errorMessage = error is BackendException
        ? error.message
        : 'Lost contact with the room.';
    notifyListeners();
  }

  void _onRoom(Room room) {
    final previous = _room;
    _room = room;

    if (room.rounds.length > _seenRoundCount) {
      _beginReveal(room.rounds.last);
      _seenRoundCount = room.rounds.length;
      _myPendingWord = null;
    }

    // Both players are in for the first time: persist the pairing.
    if (!_pairingRemembered && room.isFull) {
      _pairingRemembered = true;
      final other = room.opponentOf(localPlayerId);
      if (other != null) {
        _backend
            .rememberPairing(friendId: other, friendName: room.nameOf(other))
            .catchError((Object e) => debugPrint('rememberPairing failed: $e'));
      }
    }

    if (previous?.status != room.status && room.status == RoomStatus.active) {
      _errorMessage = null;
    }

    _maybeCommitRound(room);
    notifyListeners();
  }

  /// Attempt to resolve the round once both words are in. Safe to call
  /// repeatedly; the backend drops duplicate commits.
  void _maybeCommitRound(Room room) {
    if (_committing || !room.isReadyToReveal) return;
    _committing = true;
    final roundIndex = room.currentRound;
    _backend
        .commitRound(
          code: _roomCode,
          roundIndex: roundIndex,
          resolve: (fresh, p1Word, p2Word) => _engine.resolveRound(
            room: fresh,
            roundIndex: roundIndex,
            p1RawWord: p1Word,
            p2RawWord: p2Word,
          ),
        )
        .catchError((Object error) {
          debugPrint('commitRound failed: $error');
        })
        .whenComplete(() {
          _committing = false;
        });
  }

  Future<bool> submitWord(String raw) async {
    final room = _room;
    if (room == null || _submitting) return false;

    final word = normalizeWord(sanitizeWordInput(raw));
    if (word.isEmpty) {
      _errorMessage = 'Type a word first.';
      notifyListeners();
      return false;
    }
    if (word.length > 40) {
      _errorMessage = 'Keep it under 40 characters.';
      notifyListeners();
      return false;
    }

    _submitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _backend.submitWord(
        code: _roomCode,
        roundIndex: room.currentRound,
        word: word,
      );
      _myPendingWord = word;
      return true;
    } on BackendException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Could not send your word. Check your connection.';
      debugPrint('submitWord failed: $e');
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  void _beginReveal(GameRound round) {
    _revealing = round;
    _revealTimer?.cancel();
    _revealTimer = Timer(revealDuration, dismissReveal);
  }

  /// Ends the reveal overlay early (tap-through).
  void dismissReveal() {
    if (_revealing == null) return;
    _revealTimer?.cancel();
    _revealTimer = null;
    _revealing = null;
    notifyListeners();
  }

  Future<Room?> startRematch() async {
    final room = _room;
    if (room == null) return null;
    try {
      return await _backend.startRematch(room);
    } on BackendException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> leave() => _backend.leaveRoom(_roomCode);

  /// Every word played so far, used to keep post-game suggestions fresh.
  Set<String> get playedWords => {
    for (final r in history) ...[r.p1Word, r.p2Word],
  };

  double get convergence => _room == null ? 0 : _engine.convergenceScore(_room!);

  @override
  void dispose() {
    _revealTimer?.cancel();
    _roomSub?.cancel();
    super.dispose();
  }
}

