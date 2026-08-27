import '../core/game_config.dart';
import '../core/word_utils.dart';
import '../models/game_round.dart';
import '../models/room.dart';
import 'word_similarity.dart';

/// Everything that changes on the room document when a round resolves.
class RoundResolution {
  const RoundResolution({
    required this.round,
    required this.scores,
    required this.status,
    required this.nextRound,
    this.finishReason,
  });

  final GameRound round;

  /// Cumulative scores after applying [round].
  final Map<String, int> scores;

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

/// Pure state machine for Naamkaran. No Firebase, no Flutter — given a room
/// snapshot and two words it produces the round outcome deterministically, so
/// both clients compute identical results from the same bundled embeddings.
class GameEngine {
  const GameEngine(this.similarity);

  final WordSimilarity similarity;

  GamePhase phaseFor(Room room, String localPlayerId) {
    if (room.status == RoomStatus.finished) return GamePhase.finished;
    if (!room.isFull) return GamePhase.waitingForPlayers;
    if (room.isReadyToReveal) return GamePhase.resolving;
    if (room.hasSubmitted(localPlayerId)) return GamePhase.waitingForOpponent;
    return GamePhase.composing;
  }

  /// Resolve round [roundIndex] from the two submitted words.
  ///
  /// Round 1 is unscored: it only establishes the starting pair. From round 2
  /// each word is measured against the previous round's midpoint vector and
  /// the closer word takes the point.
  RoundResolution resolveRound({
    required Room room,
    required int roundIndex,
    required String p1RawWord,
    required String p2RawWord,
    DateTime? revealedAt,
  }) {
    final config = room.config;
    final p1Word = normalizeWord(p1RawWord);
    final p2Word = normalizeWord(p2RawWord);
    final matched = p1Word == p2Word && p1Word.isNotEmpty;

    final previous = roundIndex >= 2 && room.rounds.isNotEmpty
        ? room.rounds.last
        : null;

    double? p1Sim;
    double? p2Sim;
    var scoreKind = RoundScoreKind.unscored;
    String? scoreWinner;

    if (previous != null) {
      p1Sim = similarity.midpointSimilarity(
        p1Word,
        previous.p1Word,
        previous.p2Word,
      );
      p2Sim = similarity.midpointSimilarity(
        p2Word,
        previous.p1Word,
        previous.p2Word,
      );

      final delta = (p1Sim - p2Sim).abs();
      if (delta < config.tieThreshold) {
        scoreKind = switch (config.tieRule) {
          TieRule.bothScore => RoundScoreKind.both,
          TieRule.noScore => RoundScoreKind.none,
        };
      } else {
        scoreKind = RoundScoreKind.player;
        scoreWinner = p1Sim > p2Sim ? room.p1Id : room.p2Id;
        // Defensive: a half-populated room should never reach here, but if it
        // does, don't invent a winner.
        if (scoreWinner == null) scoreKind = RoundScoreKind.none;
      }
    }

    final round = GameRound(
      index: roundIndex,
      p1Word: p1Word,
      p2Word: p2Word,
      matched: matched,
      scoreKind: scoreKind,
      scoreWinner: scoreWinner,
      p1Similarity: p1Sim,
      p2Similarity: p2Sim,
      revealedAt: revealedAt ?? DateTime.now().toUtc(),
    );

    final scores = Map<String, int>.from(room.scores);
    for (final id in room.players) {
      scores.putIfAbsent(id, () => 0);
      if (round.didScore(id)) {
        scores[id] = (scores[id] ?? 0) + 1;
      }
    }

    // An unlimited game still stops at GameConfig.hardCeiling, so the room
    // document can never outgrow Firestore's 1 MiB limit.
    final hitRoundLimit = roundIndex >= config.effectiveLimit;
    final finished = matched || hitRoundLimit;

    return RoundResolution(
      round: round,
      scores: scores,
      status: finished ? RoomStatus.finished : RoomStatus.active,
      finishReason: matched
          ? FinishReason.converged
          : (hitRoundLimit ? FinishReason.maxRounds : null),
      nextRound: finished ? roundIndex : roundIndex + 1,
    );
  }

  /// How close the two final words ended up, for the result screen read-out.
  double convergenceScore(Room room) {
    final last = room.lastRound;
    if (last == null) return 0;
    if (last.matched) return 1;
    return similarity.pairSimilarity(last.p1Word, last.p2Word).clamp(0.0, 1.0);
  }
}
