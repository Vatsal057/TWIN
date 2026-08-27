/// A persisted pairing. Written for both sides after a room first goes active,
/// so future games between the same two people skip the code handshake.
class Friend {
  const Friend({
    required this.id,
    required this.name,
    this.lastPlayedAt,
    this.gamesPlayed = 0,
  });

  final String id;
  final String name;
  final DateTime? lastPlayedAt;
  final int gamesPlayed;

  Map<String, Object?> toMap() => {
    'friendId': id,
    'name': name,
    'gamesPlayed': gamesPlayed,
  };

  factory Friend.fromMap(String id, Map<String, Object?> map) {
    return Friend(
      id: id,
      name: (map['name'] as String?) ?? 'Player',
      lastPlayedAt: switch (map['lastPlayedAt']) {
        final DateTime d => d,
        final String s => DateTime.tryParse(s),
        _ => null,
      },
      gamesPlayed: (map['gamesPlayed'] as num?)?.toInt() ?? 0,
    );
  }
}
