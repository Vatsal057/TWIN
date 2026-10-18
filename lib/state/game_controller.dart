import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/word_utils.dart';
import '../game/game_engine.dart';
import '../models/game_round.dart';
import '../models/room.dart';
import '../services/backend/game_backend.dart';
import '../services/stats_service.dart';

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
/// notice `submittedBy.length == 2`, both compare the two words, and the
/// backend's transaction lets exactly one write land. Since the rule is string
/// equality the two can never disagree, so no server is needed to referee.
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
  Timer? _fallbackCommitTimer;
  Timer? _recoveryPollingTimer;

  Room? _room;
  String? _errorMessage;
  bool _committing = false;
  bool _submitting = false;
  bool _pairingRemembered = false;
  bool _gameCompletionRecorded = false;
  bool _firstSnapshotSeen = false;

  /// Round currently being shown in the reveal overlay.
  GameRound? _revealing;

  /// The word this player locked in for the current round, kept locally so the
  /// waiting state can show it without breaking submission privacy.
  String? _myPendingWord;

  DateTime? _lastNudgeSent;
  DateTime? _lastNudgeReceivedHandled;
  String? _incomingNudgeAlert;

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

  bool get canNudge {
    if (stage != ViewStage.waitingForOpponent) return false;
    final last = _lastNudgeSent;
    return last == null || DateTime.now().difference(last).inSeconds >= 15;
  }

  bool get isNudgeCooldown {
    final last = _lastNudgeSent;
    return last != null && DateTime.now().difference(last).inSeconds < 15;
  }

  String? consumeNudgeAlert() {
    final alert = _incomingNudgeAlert;
    _incomingNudgeAlert = null;
    return alert;
  }

  Future<void> sendNudge() async {
    if (!canNudge) return;
    _lastNudgeSent = DateTime.now();
    notifyListeners();
    try {
      await _backend.nudgeRoom(_roomCode);
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('nudge error: $e');
    }
  }

  void _onRoom(Room room) {
    final previous = _room;
    _room = room;

    if (!_firstSnapshotSeen) {
      // A room opened from History arrives already finished, with its
      // rounds in place. Seed the counters from that first snapshot so
      // opening it neither replays the reveal nor records the old game
      // as newly played.
      _firstSnapshotSeen = true;
      _seenRoundCount = room.rounds.length;
      if (room.isFinished) {
        _gameCompletionRecorded = true;
        _pairingRemembered = true;
      }
    }

    if (room.rounds.length > _seenRoundCount) {
      _beginReveal(room.rounds.last);
      _seenRoundCount = room.rounds.length;
      _myPendingWord = null;
    }

    // React to incoming nudges from opponent
    if (room.lastNudgeBy != null &&
        room.lastNudgeBy != localPlayerId &&
        room.lastNudgeAt != null) {
      final handled = _lastNudgeReceivedHandled;
      if (handled == null || room.lastNudgeAt!.isAfter(handled)) {
        _lastNudgeReceivedHandled = room.lastNudgeAt;
        _incomingNudgeAlert = '$opponentName gave you a nudge!';
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.alert);
      }
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

    // Record game completion metrics, chemistry & lifetime stats
    if (!_gameCompletionRecorded && room.isFinished) {
      _gameCompletionRecorded = true;
      final other = room.opponentOf(localPlayerId);
      final twinnedWord = room.converged ? room.lastRound?.p1Word : null;
      if (other != null) {
        _backend
            .recordGameCompletion(
              friendId: other,
              friendName: room.nameOf(other),
              roundsCount: room.rounds.length,
              converged: room.converged,
              convergedWord: twinnedWord,
            )
            .catchError(
              (Object e) => debugPrint('recordGameCompletion failed: $e'),
            );
      }
      StatsService.instance.recordGameResult(
        converged: room.converged,
        rounds: room.rounds.length,
        twinnedWord: twinnedWord,
      );
    }

    if (previous?.status != room.status && room.status == RoomStatus.active) {
      _errorMessage = null;
    }

    if (stage == ViewStage.waitingForOpponent) {
      _startRecoveryPollingIfNeeded();
    } else {
      _stopRecoveryPolling();
    }

    _maybeCommitRound(room);
    notifyListeners();
  }

  /// Attempt to resolve the round once both words are in.
  ///
  /// The host acts as the primary resolver and commits immediately.
  /// The guest waits 2.5s as a fallback so both clients never fight for
  /// the same transaction, preventing Firestore transaction retry storms and
  /// write pipeline lockups.
  void _maybeCommitRound(Room room) {
    if (!room.isReadyToReveal) {
      _fallbackCommitTimer?.cancel();
      _fallbackCommitTimer = null;
      return;
    }

    final roundIndex = room.currentRound;
    if (room.rounds.length >= roundIndex) return;

    if (isHost) {
      _executeCommit(roundIndex);
    } else {
      _fallbackCommitTimer?.cancel();
      _fallbackCommitTimer = Timer(const Duration(milliseconds: 2500), () {
        final currentRoom = _room;
        if (currentRoom != null &&
            currentRoom.isReadyToReveal &&
            currentRoom.rounds.length < roundIndex) {
          _executeCommit(roundIndex);
        }
      });
    }
  }

  void _executeCommit(int roundIndex) {
    if (_committing) return;
    _committing = true;
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
          _errorMessage = 'Could not save that round. Check your connection.';
          notifyListeners();
        })
        .whenComplete(() {
          _committing = false;
        });
  }

  void _startRecoveryPollingIfNeeded() {
    if (_recoveryPollingTimer != null && _recoveryPollingTimer!.isActive) return;
    _recoveryPollingTimer = Timer.periodic(
      const Duration(milliseconds: 2000),
      (_) async {
        if (stage != ViewStage.waitingForOpponent) {
          _stopRecoveryPolling();
          return;
        }
        try {
          final fresh = await _backend.fetchRoom(_roomCode);
          if (fresh != null) {
            if (fresh.rounds.length > _seenRoundCount || fresh.isReadyToReveal) {
              _onRoom(fresh);
            }
          }
        } catch (e) {
          debugPrint('Recovery poll error: $e');
        }
      },
    );
  }

  void _stopRecoveryPolling() {
    _recoveryPollingTimer?.cancel();
    _recoveryPollingTimer = null;
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
      StatsService.instance.recordRoundWord(word);
      _myPendingWord = word;
      _startRecoveryPollingIfNeeded();
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

  Future<void> leave() async {
    final current = _room;
    if (!_gameCompletionRecorded && current != null && current.isFull) {
      _gameCompletionRecorded = true;
      final other = current.opponentOf(localPlayerId);
      if (other != null) {
        _backend
            .recordGameCompletion(
              friendId: other,
              friendName: current.nameOf(other),
              roundsCount: current.rounds.length,
              converged: false,
            )
            .catchError(
              (Object e) => debugPrint('recordGameCompletion failed: $e'),
            );
      }
      StatsService.instance.recordGameResult(
        converged: false,
        rounds: current.rounds.length,
      );
    }
    await _backend.leaveRoom(_roomCode);
  }

  /// Number of rounds it took, which is the only "score" a collaborative game
  /// has: fewer is better, and it belongs to both players.
  int get roundsPlayed => history.length;

  @override
  void dispose() {
    _revealTimer?.cancel();
    _roomSub?.cancel();
    _fallbackCommitTimer?.cancel();
    _stopRecoveryPolling();
    super.dispose();
  }
}
