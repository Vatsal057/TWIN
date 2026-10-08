/// A persisted pairing with Duo Chemistry metrics and Memory Bank.
class Friend {
  const Friend({
    required this.id,
    required this.name,
    this.lastPlayedAt,
    this.gamesPlayed = 0,
    this.bestSyncRounds,
    this.bestSyncWord,
    this.totalRounds = 0,
    this.memoryBank = const [],
  });

  final String id;
  final String name;
  final DateTime? lastPlayedAt;
  final int gamesPlayed;
  final int? bestSyncRounds;
  final String? bestSyncWord;
  final int totalRounds;
  final List<String> memoryBank;

  double? get averageRounds =>
      (gamesPlayed > 0 && totalRounds > 0) ? (totalRounds / gamesPlayed) : null;

  int get twinnedCount => memoryBank.length;

  Map<String, Object?> toMap() => {
    'friendId': id,
    'name': name,
    'gamesPlayed': gamesPlayed,
    'totalRounds': totalRounds,
    if (bestSyncRounds != null) 'bestSyncRounds': bestSyncRounds,
    if (bestSyncWord != null) 'bestSyncWord': bestSyncWord,
    'memoryBank': memoryBank,
    if (lastPlayedAt != null) 'lastPlayedAt': lastPlayedAt!.toIso8601String(),
  };

  factory Friend.fromMap(String id, Map<String, Object?> map) {
    final rawBank = (map['memoryBank'] as List?) ?? const [];
    return Friend(
      id: id,
      name: (map['name'] as String?) ?? 'Player',
      lastPlayedAt: switch (map['lastPlayedAt']) {
        final DateTime d => d,
        final String s => DateTime.tryParse(s),
        _ => null,
      },
      gamesPlayed: (map['gamesPlayed'] as num?)?.toInt() ?? 0,
      bestSyncRounds: (map['bestSyncRounds'] as num?)?.toInt(),
      bestSyncWord: map['bestSyncWord'] as String?,
      totalRounds: (map['totalRounds'] as num?)?.toInt() ?? 0,
      memoryBank: rawBank.whereType<String>().toList(growable: false),
    );
  }
}
