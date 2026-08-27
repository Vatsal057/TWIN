import 'dart:math';

/// Short, human-readable room codes.
///
/// The alphabet drops characters that get misread when a code is dictated over
/// the phone or retyped from a screenshot: I/1, L, O/0, and digits 0-1.
class RoomCode {
  RoomCode._();

  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const length = 5;

  static final _random = Random.secure();

  static String generate() {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(alphabet[_random.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  /// Tidies pasted input (lowercase, spaces, dashes) without guessing at
  /// mistyped characters — a wrong code should fail loudly, not silently join
  /// a stranger's room.
  static String normalize(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool isValid(String code) {
    if (code.length != length) return false;
    return code.split('').every(alphabet.contains);
  }

  /// Explains why a code was rejected, for inline form validation.
  static String? validationError(String raw) {
    final code = normalize(raw);
    if (code.isEmpty) return 'Enter the room code';
    if (code.length < length) return 'Room codes are $length characters';
    if (code.length > length) return 'That is too long for a room code';
    if (!isValid(code)) return 'That code contains characters we never use';
    return null;
  }
}
