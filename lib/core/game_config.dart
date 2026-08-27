/// Tunable rules for a single game. Persisted on the room document so both
/// clients apply identical rules.
class GameConfig {
  const GameConfig({this.maxRounds});

  /// Absolute stop, even for an unlimited game.
  ///
  /// The full round history lives in an array on the room document, and
  /// Firestore caps a document at 1 MiB. A round costs roughly 100 bytes, so
  /// this leaves a wide margin while guaranteeing the write never starts
  /// failing mid-game. No real game of "keep converging" gets near it.
  static const hardCeiling = 500;

  /// Round cap, or null for an unlimited game (bounded only by [hardCeiling]).
  final int? maxRounds;

  bool get isUnlimited => maxRounds == null;

  /// The round at which the game stops no matter what.
  int get effectiveLimit => maxRounds == null
      ? hardCeiling
      : (maxRounds! < hardCeiling ? maxRounds! : hardCeiling);

  /// Caps offered when creating a room.
  static const presetLimits = <int?>[null, 5, 10, 15, 25];

  static String labelForLimit(int? limit) =>
      limit == null ? 'No limit' : '$limit rounds';

  static const GameConfig defaults = GameConfig();

  /// [maxRounds] is passed explicitly rather than defaulted, because null is a
  /// meaningful value here (unlimited) and `??` would make it unsettable.
  GameConfig copyWith({Object? maxRounds = _unset}) {
    return GameConfig(
      maxRounds: maxRounds == _unset ? this.maxRounds : maxRounds as int?,
    );
  }

  static const _unset = Object();

  Map<String, Object?> toMap() => {'maxRounds': maxRounds};

  factory GameConfig.fromMap(Map<String, Object?>? map) {
    if (map == null) return defaults;
    // Absent or null both mean unlimited.
    return GameConfig(maxRounds: (map['maxRounds'] as num?)?.toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is GameConfig && other.maxRounds == maxRounds;

  @override
  int get hashCode => maxRounds.hashCode;
}
