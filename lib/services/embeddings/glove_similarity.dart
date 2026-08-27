import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../core/word_utils.dart';
import '../../game/word_similarity.dart';
import 'embedding_table.dart';

/// Offline similarity scoring backed by the bundled GloVe table.
///
/// Everything runs locally: no network call per round, so scoring is instant
/// and free. Both clients load the identical asset, which is what makes it safe
/// for either client to resolve a round and write the result.
class GloveSimilarity implements WordSimilarity, HintCapable {
  GloveSimilarity._(this._table);

  static const assetPath = 'assets/embeddings/glove50.nkem';

  final EmbeddingTable _table;

  int get vocabSize => _table.length;
  int get dimensions => _table.dim;

  /// Cache so repeated lookups within a game (history rendering, live preview)
  /// don't redo the fallback chain.
  final Map<String, WordVectorLookup> _cache = {};

  static GloveSimilarity? _instance;
  static Future<GloveSimilarity>? _loading;

  static GloveSimilarity? get instanceOrNull => _instance;

  /// Loads and parses the asset once. Safe to await from multiple call sites.
  static Future<GloveSimilarity> load({AssetBundle? bundle}) {
    final existing = _instance;
    if (existing != null) return Future.value(existing);
    return _loading ??= _doLoad(bundle ?? rootBundle);
  }

  static Future<GloveSimilarity> _doLoad(AssetBundle bundle) async {
    try {
      final data = await bundle.load(assetPath);
      final table = EmbeddingTable.parse(data);
      final service = GloveSimilarity._(table);
      _instance = service;
      return service;
    } finally {
      _loading = null;
    }
  }

  @override
  WordVectorLookup lookup(String word) {
    final key = normalizeWord(word);
    final cached = _cache[key];
    if (cached != null) return cached;
    final result = _resolve(key);
    _cache[key] = result;
    return result;
  }

  WordVectorLookup _resolve(String normalized) {
    if (normalized.isEmpty) return WordVectorLookup.oov(normalized);

    // 1. Exact hit.
    final exact = _table.vectorOf(normalized);
    if (exact != null) {
      return WordVectorLookup(LookupKind.exact, normalized, exact);
    }

    // 2. Multi-token input: average the parts that do resolve. "ice cream"
    //    becomes the centroid of "ice" and "cream".
    if (normalized.contains(' ') || normalized.contains('-')) {
      final parts = normalized
          .split(RegExp(r'[\s\-]+'))
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.length > 1) {
        final vectors = <Float32List>[];
        for (final part in parts) {
          final v = _resolveSingle(part);
          if (v != null) vectors.add(v);
        }
        if (vectors.isNotEmpty) {
          final centroid = _normalize(_mean(vectors, _table.dim));
          if (centroid != null) {
            return WordVectorLookup(
              LookupKind.approximate,
              parts.join(' '),
              centroid,
            );
          }
        }
      }
      final glued = normalized.replaceAll(RegExp(r'[\s\-]+'), '');
      final gluedVec = _table.vectorOf(glued);
      if (gluedVec != null) {
        return WordVectorLookup(LookupKind.approximate, glued, gluedVec);
      }
    }

    // 3. Punctuation-stripped form.
    final stripped = normalized.replaceAll(RegExp(r"[^a-z]"), '');
    if (stripped != normalized && stripped.isNotEmpty) {
      final v = _table.vectorOf(stripped);
      if (v != null) {
        return WordVectorLookup(LookupKind.approximate, stripped, v);
      }
    }

    // 4. Light suffix stripping (plurals, common inflections).
    for (final candidate in _morphologicalVariants(stripped)) {
      final v = _table.vectorOf(candidate);
      if (v != null) {
        return WordVectorLookup(LookupKind.approximate, candidate, v);
      }
    }

    // 5. Longest shared-prefix neighbour.
    final prefixMatch = _table.nearestByPrefix(stripped);
    if (prefixMatch != null) {
      final v = _table.vectorOf(prefixMatch);
      if (v != null) {
        return WordVectorLookup(LookupKind.approximate, prefixMatch, v);
      }
    }

    // 6. Genuinely unknown — similarity will be 0.
    return WordVectorLookup.oov(normalized);
  }

  Float32List? _resolveSingle(String token) {
    final direct = _table.vectorOf(token);
    if (direct != null) return direct;
    for (final candidate in _morphologicalVariants(token)) {
      final v = _table.vectorOf(candidate);
      if (v != null) return v;
    }
    return null;
  }

  static Iterable<String> _morphologicalVariants(String word) {
    if (word.length < 4) return const [];
    final out = <String>[];
    void add(String? s) {
      if (s != null && s.length >= 2 && !out.contains(s)) out.add(s);
    }

    if (word.endsWith('ies')) add('${word.substring(0, word.length - 3)}y');
    if (word.endsWith('es')) add(word.substring(0, word.length - 2));
    if (word.endsWith('s')) add(word.substring(0, word.length - 1));
    if (word.endsWith('ing')) {
      final stem = word.substring(0, word.length - 3);
      add(stem);
      add('${stem}e');
      if (stem.length > 2 && stem[stem.length - 1] == stem[stem.length - 2]) {
        add(stem.substring(0, stem.length - 1));
      }
    }
    if (word.endsWith('ed')) {
      final stem = word.substring(0, word.length - 2);
      add(stem);
      add('${stem}e');
      if (stem.length > 2 && stem[stem.length - 1] == stem[stem.length - 2]) {
        add(stem.substring(0, stem.length - 1));
      }
    }
    if (word.endsWith('ly')) add(word.substring(0, word.length - 2));
    if (word.endsWith('er')) add(word.substring(0, word.length - 2));
    if (word.endsWith('est')) add(word.substring(0, word.length - 3));
    return out;
  }

  @override
  double midpointSimilarity(String word, String a, String b) {
    final target = lookup(word).vector;
    if (target == null) return 0;

    // One anchor unknown: _midpointVector falls back to whichever resolved,
    // rather than throwing the whole round away.
    final mid = _midpointVector(a, b);
    if (mid == null) return 0;

    return _dot(target, mid).clamp(-1.0, 1.0);
  }

  /// Function words and other tokens nobody would play. They sit near the
  /// centre of the embedding space, so without this filter they win almost
  /// every midpoint search and the suggestions read like glue.
  static const _unplayable = {
    'a', 'an', 'the', 'and', 'or', 'but', 'if', 'then', 'than', 'as', 'at',
    'by', 'for', 'from', 'in', 'into', 'of', 'off', 'on', 'onto', 'out',
    'over', 'to', 'up', 'with', 'without', 'within', 'about', 'above',
    'across', 'after', 'against', 'along', 'among', 'around', 'before',
    'behind', 'below', 'beneath', 'beside', 'between', 'beyond', 'during',
    'near', 'since', 'through', 'throughout', 'toward', 'towards', 'under',
    'until', 'upon', 'be', 'been', 'being', 'am', 'is', 'are', 'was', 'were',
    'do', 'does', 'did', 'done', 'have', 'has', 'had', 'having', 'can',
    'could', 'may', 'might', 'must', 'shall', 'should', 'will', 'would',
    'i', 'me', 'my', 'we', 'us', 'our', 'you', 'your', 'he', 'him', 'his',
    'she', 'her', 'it', 'its', 'they', 'them', 'their', 'this', 'that',
    'these', 'those', 'who', 'whom', 'whose', 'which', 'what', 'when',
    'where', 'why', 'how', 'all', 'any', 'both', 'each', 'few', 'more',
    'most', 'other', 'some', 'such', 'no', 'nor', 'not', 'only', 'own',
    'same', 'so', 'too', 'very', 'just', 'also', 'well', 'even', 'still',
    'back', 'there', 'here', 'now', 'one', 'two', 'first', 'last', 'new',
    'old', 'said', 'says', 'like', 'get', 'got', 'go', 'going', 'went',
    'make', 'made', 'take', 'took', 'come', 'came', 'see', 'saw', 'know',
    'known', 'time', 'year', 'years', 'day', 'days', 'per', 'via', 'mr',
    'mrs', 'ms', 'dr',
  };

  /// Vocabulary words closest to the midpoint of [a] and [b].
  ///
  /// Powers the offline practice opponent and the post-game read-out.
  /// [searchRows] caps the scan to the most frequent slice of the vocabulary
  /// (rows are stored in frequency order), which keeps suggestions to words
  /// people actually use.
  @override
  List<String> nearestToMidpoint(
    String a,
    String b, {
    int count = 5,
    Set<String> exclude = const {},
    int searchRows = 15000,
  }) {
    final mid = _midpointVector(a, b);
    if (mid == null) return const [];

    final excludeRows = <int>{};
    for (final word in {
      ...exclude,
      ..._unplayable,
      normalizeWord(a),
      normalizeWord(b),
    }) {
      final row = _table.indexOf(normalizeWord(word));
      if (row != null) excludeRows.add(row);
    }

    final matches = _table.topMatches(
      mid,
      k: count + 4,
      excludeRows: excludeRows,
      searchRows: searchRows,
    );
    return matches
        .map((m) => _table.tokens[m.row])
        .where((w) => w.length >= 3)
        .take(count)
        .toList();
  }

  Float32List? _midpointVector(String a, String b) {
    final va = lookup(a).vector;
    final vb = lookup(b).vector;
    if (va != null && vb != null) {
      return _normalize(_mean([va, vb], _table.dim));
    }
    final only = va ?? vb;
    return only == null ? null : _normalize(Float32List.fromList(only));
  }

  @override
  double pairSimilarity(String a, String b) {
    final va = lookup(a).vector;
    final vb = lookup(b).vector;
    if (va == null || vb == null) return 0;
    return _dot(va, vb).clamp(-1.0, 1.0);
  }

  static Float32List _mean(List<Float32List> vectors, int dim) {
    final out = Float32List(dim);
    for (final v in vectors) {
      for (var d = 0; d < dim; d++) {
        out[d] += v[d];
      }
    }
    final n = vectors.length;
    for (var d = 0; d < dim; d++) {
      out[d] /= n;
    }
    return out;
  }

  static Float32List? _normalize(Float32List v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    if (sum <= 0) return null;
    final inv = 1.0 / math.sqrt(sum);
    for (var d = 0; d < v.length; d++) {
      v[d] *= inv;
    }
    return v;
  }

  static double _dot(Float32List a, Float32List b) {
    var sum = 0.0;
    final n = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }
}
