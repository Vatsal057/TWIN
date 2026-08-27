import '../core/word_utils.dart';

/// One completed round: the pair of words revealed together, and whether they
/// converged. Immutable — rounds are append-only history.
///
/// There is deliberately no score here. TWIN is collaborative: the only
/// outcome that matters is whether the two words met, and how many rounds it
/// took to get there.
class GameRound {
  const GameRound({
    required this.index,
    required this.p1Word,
    required this.p2Word,
    required this.matched,
    this.revealedAt,
  });

  /// 1-based round number.
  final int index;
  final String p1Word;
  final String p2Word;

  /// The two words converged; the game ends on this round.
  final bool matched;

  final DateTime? revealedAt;

  String wordFor(String playerId, {required String p1Id}) =>
      playerId == p1Id ? p1Word : p2Word;

  String get displayP1Word => titleCaseWord(p1Word);
  String get displayP2Word => titleCaseWord(p2Word);

  Map<String, Object?> toMap() => {
    'index': index,
    'p1Word': p1Word,
    'p2Word': p2Word,
    'matched': matched,
    'revealedAt': revealedAt?.toUtc().toIso8601String(),
  };

  factory GameRound.fromMap(Map<String, Object?> map) {
    return GameRound(
      index: (map['index'] as num?)?.toInt() ?? 0,
      p1Word: (map['p1Word'] as String?) ?? '',
      p2Word: (map['p2Word'] as String?) ?? '',
      matched: (map['matched'] as bool?) ?? false,
      revealedAt: switch (map['revealedAt']) {
        final String s => DateTime.tryParse(s),
        _ => null,
      },
    );
  }

  @override
  String toString() => 'GameRound($index, $p1Word/$p2Word, matched: $matched)';
}
