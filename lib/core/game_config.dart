/// How a round is scored when the two players' words are effectively
/// equidistant from the previous round's midpoint.
enum TieRule {
  /// Both players get a point.
  bothScore,

  /// Nobody gets a point.
  noScore,
}

extension TieRuleCodec on TieRule {
  String get wireName => switch (this) {
    TieRule.bothScore => 'bothScore',
    TieRule.noScore => 'noScore',
  };

  String get label => switch (this) {
    TieRule.bothScore => 'Tie: both score',
    TieRule.noScore => 'Tie: nobody scores',
  };

  static TieRule fromWire(Object? value) => switch (value) {
    'noScore' => TieRule.noScore,
    _ => TieRule.bothScore,
  };
}

/// Tunable rules for a single game. Persisted on the room document so both
/// clients resolve rounds identically.
class GameConfig {
  const GameConfig({
    this.maxRounds,
    this.tieThreshold = 0.02,
    this.tieRule = TieRule.bothScore,
  });

  /// Absolute stop, even for an unlimited game.
  ///
  /// The full round history lives in an array on the room document, and
  /// Firestore caps a document at 1 MiB. A round costs roughly 200 bytes, so
  /// this leaves a wide margin while guaranteeing the write never starts
  /// failing mid-game. No real game of "keep converging" gets near it.
  static const hardCeiling = 500;

  /// Round cap, or null for an unlimited game (bounded only by [hardCeiling]).
  ///
  /// Round 1 counts towards this budget even though it is unscored.
  final int? maxRounds;

  bool get isUnlimited => maxRounds == null;

  /// The round at which the game stops no matter what.
  int get effectiveLimit => maxRounds == null
      ? hardCeiling
      : (maxRounds! < hardCeiling ? maxRounds! : hardCeiling);

  /// Preset caps offered when creating a room.
  static const presetLimits = <int?>[null, 5, 10, 15, 25];

  static String labelForLimit(int? limit) =>
      limit == null ? 'No limit' : '$limit rounds';

  /// Similarity delta below which the round is treated as a tie.
  final double tieThreshold;

  final TieRule tieRule;

  static const GameConfig defaults = GameConfig();

  /// [maxRounds] is passed explicitly rather than defaulted, because null is a
  /// meaningful value here (unlimited) and `??` would make it unsettable.
  GameConfig copyWith({
    Object? maxRounds = _unset,
    double? tieThreshold,
    TieRule? tieRule,
  }) {
    return GameConfig(
      maxRounds: maxRounds == _unset ? this.maxRounds : maxRounds as int?,
      tieThreshold: tieThreshold ?? this.tieThreshold,
      tieRule: tieRule ?? this.tieRule,
    );
  }

  static const _unset = Object();

  Map<String, Object?> toMap() => {
    'maxRounds': maxRounds,
    'tieThreshold': tieThreshold,
    'tieRule': tieRule.wireName,
  };

  factory GameConfig.fromMap(Map<String, Object?>? map) {
    if (map == null) return defaults;
    return GameConfig(
      // Absent or null both mean unlimited.
      maxRounds: (map['maxRounds'] as num?)?.toInt(),
      tieThreshold: (map['tieThreshold'] as num?)?.toDouble() ?? 0.02,
      tieRule: TieRuleCodec.fromWire(map['tieRule']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameConfig &&
      other.maxRounds == maxRounds &&
      other.tieThreshold == tieThreshold &&
      other.tieRule == tieRule;

  @override
  int get hashCode => Object.hash(maxRounds, tieThreshold, tieRule);
}
