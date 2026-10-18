/// A chat message in a player pair's conversation. Supports regular player
/// text as well as system round outcome announcements (matching reference
/// Screenshot 3).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.sentAt,
    this.pending = false,
    this.system = false,
    this.round,
    this.wordA,
    this.wordB,
    this.matched,
    this.kind,
    this.roomCode,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime? sentAt;

  /// True while the write is still in flight (Firestore local echo).
  final bool pending;

  /// True for system event cards like "Round 2: OASIS vs CAMEL — no match"
  final bool system;
  final int? round;
  final String? wordA;
  final String? wordB;
  final bool? matched;

  /// Special message kinds, rendered as cards instead of text bubbles.
  /// [kindRematch] is a rematch request carrying the new room's code in
  /// [roomCode]; [kindRematchDeclined] is the reply that turns it down.
  /// Null means an ordinary message.
  static const kindRematch = 'rematch';
  static const kindRematchDeclined = 'rematch-declined';

  final String? kind;
  final String? roomCode;

  Map<String, Object?> toMap() => {
    'senderId': senderId,
    'text': text,
    'system': system,
    if (round != null) 'round': round,
    if (wordA != null) 'wordA': wordA,
    if (wordB != null) 'wordB': wordB,
    if (matched != null) 'matched': matched,
    if (kind != null) 'kind': kind,
    if (roomCode != null) 'roomCode': roomCode,
    if (sentAt != null) 'sentAt': sentAt!.toIso8601String(),
  };

  factory ChatMessage.fromMap(
    String id,
    Map<String, Object?> map, {
    bool pending = false,
  }) {
    return ChatMessage(
      id: id,
      senderId: (map['senderId'] as String?) ?? '',
      text: (map['text'] as String?) ?? '',
      sentAt: switch (map['sentAt']) {
        final DateTime d => d,
        final String s => DateTime.tryParse(s),
        _ => null,
      },
      pending: pending,
      system: map['system'] == true,
      round: (map['round'] as num?)?.toInt(),
      wordA: map['wordA'] as String?,
      wordB: map['wordB'] as String?,
      matched: map['matched'] as bool?,
      kind: map['kind'] as String?,
      roomCode: map['roomCode'] as String?,
    );
  }
}

