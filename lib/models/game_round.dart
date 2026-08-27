import '../core/word_utils.dart';

/// Who banked the point for a round.
enum RoundScoreKind {
  /// Round 1 establishes the starting pair and is deliberately not scored.
  unscored,

  /// One player was closer to the previous midpoint.
  player,

  /// Similarity delta under the tie threshold, resolved as "both score".
  both,

  /// Similarity delta under the tie threshold, resolved as "nobody scores".
  none,
}

/// One completed round: the pair of words revealed together plus the scoring
/// verdict. Immutable — rounds are append-only history.
class GameRound {
  const GameRound({
    required this.index,
    required this.p1Word,
    required this.p2Word,
    required this.matched,
    required this.scoreKind,
    this.scoreWinner,
    this.p1Similarity,
    this.p2Similarity,
    this.revealedAt,
  });

  /// 1-based round number.
  final int index;
  final String p1Word;
  final String p2Word;

  /// The two words converged; the game ends on this round.
  final bool matched;

  final RoundScoreKind scoreKind;

  /// Player id when [scoreKind] is [RoundScoreKind.player], else null.
  final String? scoreWinner;

  /// Cosine similarity of [p1Word] to the previous round's midpoint vector.
  /// Null for round 1 (no previous pair to measure against).
  final double? p1Similarity;
  final double? p2Similarity;

  final DateTime? revealedAt;

  bool get isScored => scoreKind != RoundScoreKind.unscored;

  double? get similarityDelta {
    final a = p1Similarity;
    final b = p2Similarity;
    if (a == null || b == null) return null;
    return (a - b).abs();
  }

  /// Did [playerId] earn a point on this round?
  bool didScore(String playerId) => switch (scoreKind) {
    RoundScoreKind.unscored => false,
    RoundScoreKind.none => false,
    RoundScoreKind.both => true,
    RoundScoreKind.player => scoreWinner == playerId,
  };

  String wordFor(String playerId, {required String p1Id}) =>
      playerId == p1Id ? p1Word : p2Word;

  double? similarityFor(String playerId, {required String p1Id}) =>
      playerId == p1Id ? p1Similarity : p2Similarity;

  String get displayP1Word => titleCaseWord(p1Word);
  String get displayP2Word => titleCaseWord(p2Word);

  Map<String, Object?> toMap() => {
    'index': index,
    'p1Word': p1Word,
    'p2Word': p2Word,
    'matched': matched,
    'scoreKind': scoreKind.name,
    'scoreWinner': scoreWinner,
    'p1Sim': p1Similarity,
    'p2Sim': p2Similarity,
    'revealedAt': revealedAt?.toUtc().toIso8601String(),
  };

  factory GameRound.fromMap(Map<String, Object?> map) {
    return GameRound(
      index: (map['index'] as num?)?.toInt() ?? 0,
      p1Word: (map['p1Word'] as String?) ?? '',
      p2Word: (map['p2Word'] as String?) ?? '',
      matched: (map['matched'] as bool?) ?? false,
      scoreKind: RoundScoreKind.values.firstWhere(
        (k) => k.name == map['scoreKind'],
        orElse: () => RoundScoreKind.unscored,
      ),
      scoreWinner: map['scoreWinner'] as String?,
      p1Similarity: (map['p1Sim'] as num?)?.toDouble(),
      p2Similarity: (map['p2Sim'] as num?)?.toDouble(),
      revealedAt: switch (map['revealedAt']) {
        final String s => DateTime.tryParse(s),
        _ => null,
      },
    );
  }

  @override
  String toString() =>
      'GameRound($index, $p1Word/$p2Word, matched: $matched, $scoreKind)';
}
