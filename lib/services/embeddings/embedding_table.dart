import 'dart:typed_data';

/// In-memory view over the bundled `.nkem` asset.
///
/// Vectors are stored unit-normalized and int16-quantized, so cosine
/// similarity is a dot product and the whole 50k x 50d table costs ~5 MB.
class EmbeddingTable {
  EmbeddingTable._({
    required this.dim,
    required this.tokens,
    required Map<String, int> index,
    required Uint32List sortedIndex,
    required Int16List matrix,
    required double scale,
  }) : _index = index,
       _sortedIndex = sortedIndex,
       _matrix = matrix,
       _scale = scale;

  static const _magic = 0x4D454B4E; // "NKEM" little-endian
  static const _qMax = 32767.0;
  static const _version = 2;

  final int dim;

  /// Vocabulary in descending frequency order: row 0 is the most common word.
  /// That ordering is what makes "search the top N words" meaningful.
  final List<String> tokens;

  final Map<String, int> _index;

  /// Rows ordered lexicographically, for binary search in the prefix fallback.
  final Uint32List _sortedIndex;

  final Int16List _matrix;
  final double _scale;

  int get length => tokens.length;

  /// Parses the asset. Synchronous and CPU-bound (~100 ms for 50k tokens), so
  /// callers should run it off the first frame or behind a loading gate.
  factory EmbeddingTable.parse(ByteData data) {
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final header = ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.length,
    );

    if (bytes.length < 20) {
      throw const FormatException('embedding asset truncated');
    }
    final magic = header.getUint32(0, Endian.little);
    if (magic != _magic) {
      throw const FormatException('embedding asset has bad magic');
    }
    final version = header.getUint16(4, Endian.little);
    if (version != _version) {
      throw FormatException(
        'unsupported embedding asset version $version, expected $_version — '
        'regenerate with tools/build_embeddings.py',
      );
    }
    final dim = header.getUint16(6, Endian.little);
    final count = header.getUint32(8, Endian.little);
    final scale = header.getFloat32(12, Endian.little);
    final vocabBytes = header.getUint32(16, Endian.little);

    const headerSize = 20;
    final vocabStart = headerSize;
    final sortedStart = vocabStart + vocabBytes;
    final matrixStart = sortedStart + count * 4;
    final expected = matrixStart + count * dim * 2;
    if (bytes.length < expected) {
      throw FormatException(
        'embedding asset truncated: expected $expected bytes, got ${bytes.length}',
      );
    }

    final tokens = List<String>.filled(count, '', growable: false);
    final index = <String, int>{};
    var cursor = vocabStart;
    for (var i = 0; i < count; i++) {
      final len = bytes[cursor];
      cursor += 1;
      // Vocabulary is ASCII by construction (see tools/build_embeddings.py),
      // so the fast path is safe and avoids a UTF-8 decoder per token.
      final token = String.fromCharCodes(bytes, cursor, cursor + len);
      cursor += len;
      tokens[i] = token;
      index[token] = i;
    }

    // Copy into aligned typed lists; the asset offset is not guaranteed to be
    // 2- or 4-byte aligned when it comes out of the asset bundle.
    final sortedIndex = Uint32List(count);
    final sortedView = ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes + sortedStart,
      count * 4,
    );
    for (var i = 0; i < count; i++) {
      sortedIndex[i] = sortedView.getUint32(i * 4, Endian.little);
    }

    final matrix = Int16List(count * dim);
    final matrixView = ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes + matrixStart,
      count * dim * 2,
    );
    for (var i = 0; i < matrix.length; i++) {
      matrix[i] = matrixView.getInt16(i * 2, Endian.little);
    }

    return EmbeddingTable._(
      dim: dim,
      tokens: tokens,
      index: index,
      sortedIndex: sortedIndex,
      matrix: matrix,
      scale: scale,
    );
  }

  bool contains(String token) => _index.containsKey(token);

  int? indexOf(String token) => _index[token];

  /// Dequantized unit vector for [token], or null if absent.
  Float32List? vectorOf(String token) {
    final i = _index[token];
    if (i == null) return null;
    return vectorAt(i);
  }

  Float32List vectorAt(int row) {
    final out = Float32List(dim);
    final base = row * dim;
    final k = _scale / _qMax;
    for (var d = 0; d < dim; d++) {
      out[d] = _matrix[base + d] * k;
    }
    return out;
  }

  /// Highest-cosine rows against a unit-length [query].
  ///
  /// Scores straight off the quantized matrix, so no per-row Float32List is
  /// allocated. Returns rows sorted best-first. Because rows are in frequency
  /// order, [searchRows] restricts the scan to the most common words.
  List<({int row, double score})> topMatches(
    Float32List query, {
    int k = 5,
    Set<int> excludeRows = const {},
    int? searchRows,
  }) {
    final limit = searchRows == null
        ? tokens.length
        : searchRows.clamp(1, tokens.length);
    final kq = _scale / _qMax;
    final best = <({int row, double score})>[];
    var worst = -2.0;

    for (var row = 0; row < limit; row++) {
      if (excludeRows.contains(row)) continue;
      final base = row * dim;
      var sum = 0.0;
      for (var d = 0; d < dim; d++) {
        sum += _matrix[base + d] * query[d];
      }
      final score = sum * kq;
      if (best.length < k) {
        best.add((row: row, score: score));
        best.sort((a, b) => b.score.compareTo(a.score));
        worst = best.last.score;
      } else if (score > worst) {
        best[best.length - 1] = (row: row, score: score);
        best.sort((a, b) => b.score.compareTo(a.score));
        worst = best.last.score;
      }
    }
    return best;
  }

  /// Longest shared-prefix neighbour, used as the out-of-vocabulary fallback.
  ///
  /// Requires at least [minPrefix] shared leading characters. Among the
  /// candidates sharing the longest prefix, the shortest token wins — that
  /// favours "run" over "runnymede" for a query like "runn".
  String? nearestByPrefix(String query, {int minPrefix = 4}) {
    if (query.length < minPrefix || tokens.isEmpty) return null;

    // Binary search the lexicographic view, not the frequency-ordered rows.
    var lo = 0;
    var hi = tokens.length - 1;
    var insertion = tokens.length;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_sortedTokenAt(mid).compareTo(query) < 0) {
        lo = mid + 1;
      } else {
        insertion = mid;
        hi = mid - 1;
      }
    }

    String? best;
    var bestShared = 0;
    // Walk a small window either side of the insertion point; in sorted order
    // the longest shared prefix is always adjacent.
    for (var offset = -24; offset <= 24; offset++) {
      final i = insertion + offset;
      if (i < 0 || i >= tokens.length) continue;
      final candidate = _sortedTokenAt(i);
      final shared = _sharedPrefixLength(query, candidate);
      if (shared < minPrefix) continue;
      if (shared > bestShared ||
          (shared == bestShared &&
              best != null &&
              candidate.length < best.length)) {
        bestShared = shared;
        best = candidate;
      }
    }
    return best;
  }

  String _sortedTokenAt(int sortedPosition) =>
      tokens[_sortedIndex[sortedPosition]];

  static int _sharedPrefixLength(String a, String b) {
    final n = a.length < b.length ? a.length : b.length;
    var i = 0;
    while (i < n && a.codeUnitAt(i) == b.codeUnitAt(i)) {
      i++;
    }
    return i;
  }
}
