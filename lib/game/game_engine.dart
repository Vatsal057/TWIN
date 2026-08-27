import '../core/word_utils.dart';
import '../models/game_round.dart';
import '../models/room.dart';

/// Everything that changes on the room document when a round resolves.
class RoundResolution {
  const RoundResolution({
    required this.round,
    required this.status,
    required this.nextRound,
    this.finishReason,
  });

  final GameRound round;
  final RoomStatus status;
  final FinishReason? finishReason;

  /// Round number that will await submissions next. Equals [round.index] when
  /// the game is over.
  final int nextRound;

  bool get gameOver => status == RoomStatus.finished;
}

/// What the local player should be doing right now. Derived purely from the
/// room snapshot, so both clients agree without extra messages.
enum GamePhase {
  waitingForPlayers,
  composing,
  waitingForOpponent,
  resolving,
  finished,
}

/// Pure state machine for TWIN.
///
/// No Firebase, no Flutter, no word lists: given a room snapshot and the two
/// submitted words it decides whether the pair converged and whether the game
/// is over. That is the whole rule set, which is why both clients can resolve a
/// round independently and always agree.
class GameEngine {
  const GameEngine();

  GamePhase phaseFor(Room room, String localPlayerId) {
    if (room.status == RoomStatus.finished) return GamePhase.finished;
    if (!room.isFull) return GamePhase.waitingForPlayers;
    if (room.isReadyToReveal) return GamePhase.resolving;
    if (room.hasSubmitted(localPlayerId)) return GamePhase.waitingForOpponent;
    return GamePhase.composing;
  }

  /// Resolve round [roundIndex] from the two submitted words.
  ///
  /// The words match, or they don't. Round 1 is no different from any other
  /// round — it just happens to be the one that sets the starting pair.
  RoundResolution resolveRound({
    required Room room,
    required int roundIndex,
    required String p1RawWord,
    required String p2RawWord,
    DateTime? revealedAt,
  }) {
    final p1Word = normalizeWord(p1RawWord);
    final p2Word = normalizeWord(p2RawWord);
    final matched = p1Word == p2Word && p1Word.isNotEmpty;

    final round = GameRound(
      index: roundIndex,
      p1Word: p1Word,
      p2Word: p2Word,
      matched: matched,
      revealedAt: revealedAt ?? DateTime.now().toUtc(),
    );

    // An unlimited game still stops at GameConfig.hardCeiling, so the room
    // document can never outgrow Firestore's 1 MiB limit.
    final hitRoundLimit = roundIndex >= room.config.effectiveLimit;
    final finished = matched || hitRoundLimit;

    return RoundResolution(
      round: round,
      status: finished ? RoomStatus.finished : RoomStatus.active,
      finishReason: matched
          ? FinishReason.converged
          : (hitRoundLimit ? FinishReason.maxRounds : null),
      nextRound: finished ? roundIndex : roundIndex + 1,
    );
  }
}
