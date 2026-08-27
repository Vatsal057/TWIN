/// A plain-text chat line scoped to a room. No read receipts, no typing
/// indicators, no media, no reactions — just sender, text and time.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.sentAt,
    this.pending = false,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime? sentAt;

  /// True while the write is still in flight (Firestore local echo).
  final bool pending;

  Map<String, Object?> toMap() => {'senderId': senderId, 'text': text};

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
    );
  }
}
