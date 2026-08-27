import 'dart:typed_data';

/// Result of looking a word up in the embedding table.
enum LookupKind {
  /// Exact hit on the normalized token.
  exact,

  /// Matched after a light morphological/subword fallback.
  approximate,

  /// Not in vocabulary at all — similarity is treated as 0.
  outOfVocabulary,
}

class WordVectorLookup {
  const WordVectorLookup(this.kind, this.matchedToken, this.vector);

  const WordVectorLookup.oov(this.matchedToken)
    : kind = LookupKind.outOfVocabulary,
      vector = null;

  final LookupKind kind;

  /// The vocabulary entry that was actually used (may differ from the query
  /// when [kind] is [LookupKind.approximate]).
  final String matchedToken;

  /// Unit-length vector, or null when out of vocabulary.
  final Float32List? vector;

  bool get resolved => vector != null;
}

/// Similarity scoring contract used by [GameEngine]. Kept abstract so the
/// engine stays pure and deterministic under test.
abstract class WordSimilarity {
  /// Cosine similarity of [word] against the midpoint of [a] and [b].
  ///
  /// Returns 0 when the word cannot be resolved to a vector, per the
  /// out-of-vocabulary rule.
  double midpointSimilarity(String word, String a, String b);

  WordVectorLookup lookup(String word);

  /// Plain pairwise cosine similarity, used for the convergence read-out.
  double pairSimilarity(String a, String b);
}

/// Optional capability: suggest vocabulary words near a pair's midpoint.
/// Separate from [WordSimilarity] so the engine keeps working with a scorer
/// that cannot enumerate its vocabulary.
abstract class HintCapable {
  List<String> nearestToMidpoint(
    String a,
    String b, {
    int count,
    Set<String> exclude,
    int searchRows,
  });
}
