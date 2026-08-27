/// A direct invite dropped into a friend's inbox.
///
/// This is what makes a persisted pairing worth something: once two people have
/// played, either can start a game without copying a code around again.
class GameInvite {
  const GameInvite({
    required this.roomCode,
    required this.fromId,
    required this.fromName,
    this.createdAt,
  });

  final String roomCode;
  final String fromId;
  final String fromName;
  final DateTime? createdAt;

  Map<String, Object?> toMap() => {
    'roomCode': roomCode,
    'fromId': fromId,
    'fromName': fromName,
  };

  factory GameInvite.fromMap(String roomCode, Map<String, Object?> map) {
    return GameInvite(
      roomCode: roomCode,
      fromId: (map['fromId'] as String?) ?? '',
      fromName: (map['fromName'] as String?) ?? 'Player',
      createdAt: switch (map['createdAt']) {
        final DateTime d => d,
        final String s => DateTime.tryParse(s),
        _ => null,
      },
    );
  }
}
