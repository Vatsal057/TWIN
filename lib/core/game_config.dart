/// Tunable rules for a single game. Persisted on the room document so both
/// clients apply identical rules.
class GameConfig {
  const GameConfig({
    this.maxRounds,
    this.startWordA,
    this.startWordB,
    this.theme,
  });

  /// Absolute stop, even for an unlimited game.
  ///
  /// The full round history lives in an array on the room document, and
  /// Firestore caps a document at 1 MiB. A round costs roughly 100 bytes, so
  /// this leaves a wide margin while guaranteeing the write never starts
  /// failing mid-game. No real game of "keep converging" gets near it.
  static const hardCeiling = 500;

  /// Round cap, or null for an unlimited game (bounded only by [hardCeiling]).
  final int? maxRounds;

  /// Optional host-configured starting anchor words for round 1.
  final String? startWordA;
  final String? startWordB;

  /// Optional theme or category label for the game.
  final String? theme;

  bool get isUnlimited => maxRounds == null;

  bool get hasCustomStart =>
      startWordA != null &&
      startWordB != null &&
      startWordA!.trim().isNotEmpty &&
      startWordB!.trim().isNotEmpty;

  bool get hasTheme => theme != null && theme!.trim().isNotEmpty;

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
  GameConfig copyWith({
    Object? maxRounds = _unset,
    Object? startWordA = _unset,
    Object? startWordB = _unset,
    Object? theme = _unset,
  }) {
    return GameConfig(
      maxRounds: maxRounds == _unset ? this.maxRounds : maxRounds as int?,
      startWordA: startWordA == _unset
          ? this.startWordA
          : startWordA as String?,
      startWordB: startWordB == _unset
          ? this.startWordB
          : startWordB as String?,
      theme: theme == _unset ? this.theme : theme as String?,
    );
  }

  static const _unset = Object();

  Map<String, Object?> toMap() => {
    'maxRounds': maxRounds,
    if (startWordA != null) 'startWordA': startWordA,
    if (startWordB != null) 'startWordB': startWordB,
    if (theme != null) 'theme': theme,
  };

  factory GameConfig.fromMap(Map<String, Object?>? map) {
    if (map == null) return defaults;
    return GameConfig(
      maxRounds: (map['maxRounds'] as num?)?.toInt(),
      startWordA: map['startWordA'] as String?,
      startWordB: map['startWordB'] as String?,
      theme: map['theme'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameConfig &&
      other.maxRounds == maxRounds &&
      other.startWordA == startWordA &&
      other.startWordB == startWordB &&
      other.theme == theme;

  @override
  int get hashCode => Object.hash(maxRounds, startWordA, startWordB, theme);
}
