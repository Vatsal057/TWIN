import '../core/game_config.dart';
import 'game_round.dart';

enum RoomStatus { waiting, active, finished }

extension RoomStatusCodec on RoomStatus {
  String get wireName => name;

  static RoomStatus fromWire(Object? value) => switch (value) {
    'active' => RoomStatus.active,
    'finished' => RoomStatus.finished,
    _ => RoomStatus.waiting,
  };
}

enum FinishReason {
  /// Both players submitted the same word.
  converged,

  /// Hit [GameConfig.maxRounds] without converging.
  maxRounds,

  /// A player left before the game resolved.
  abandoned,
}

extension FinishReasonCodec on FinishReason {
  String get wireName => name;

  static FinishReason? fromWire(Object? value) => switch (value) {
    'converged' => FinishReason.converged,
    'maxRounds' => FinishReason.maxRounds,
    'abandoned' => FinishReason.abandoned,
    _ => null,
  };
}

/// The shared room document. This is the single source of truth that both
/// clients observe via a live Firestore listener.
class Room {
  const Room({
    required this.code,
    required this.hostId,
    required this.players,
    required this.playerNames,
    required this.status,
    required this.config,
    required this.currentRound,
    required this.submittedBy,
    required this.rounds,
    this.finishReason,
    this.createdAt,
    this.updatedAt,
    this.rematchOf,
    this.rematchRoomCode,
  });

  final String code;

  /// Player who created the room. Always `players[0]`, i.e. "p1".
  final String hostId;

  /// Ordered: index 0 is p1, index 1 is p2. Order is stable for the whole game
  /// so that `p1Word`/`p2Word` in history never swap meaning.
  final List<String> players;

  final Map<String, String> playerNames;
  final RoomStatus status;
  final GameConfig config;

  /// 1-based index of the round currently awaiting submissions.
  final int currentRound;

  /// Player ids that have locked in a word for [currentRound]. Used as the
  /// "both are in, reveal now" signal, and by the security rules to decide
  /// when the private submission docs become readable.
  final List<String> submittedBy;

  final List<GameRound> rounds;
  final FinishReason? finishReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Room code this room was spawned from, if it is a rematch.
  final String? rematchOf;

  /// Set once one player starts a rematch, so the other can follow.
  final String? rematchRoomCode;

  String get p1Id => players.isNotEmpty ? players[0] : '';
  String? get p2Id => players.length > 1 ? players[1] : null;

  bool get isFull => players.length >= 2;
  bool get isFinished => status == RoomStatus.finished;
  bool get converged => finishReason == FinishReason.converged;

  GameRound? get lastRound => rounds.isEmpty ? null : rounds.last;

  /// The pair players are trying to converge on this round. Null on round 1.
  GameRound? get previousRound => rounds.isEmpty ? null : rounds.last;

  bool hasSubmitted(String playerId) => submittedBy.contains(playerId);

  String? opponentOf(String playerId) {
    for (final p in players) {
      if (p != playerId) return p;
    }
    return null;
  }

  String nameOf(String? playerId) {
    if (playerId == null) return 'Player';
    return playerNames[playerId] ?? 'Player';
  }

  /// True once the current round has both submissions and is ready to resolve.
  bool get isReadyToReveal =>
      isFull && submittedBy.length >= 2 && rounds.length < currentRound;

  /// Null when the game is unlimited: there is no "rounds remaining".
  int? get roundsRemaining {
    final limit = config.maxRounds;
    if (limit == null) return null;
    final left = limit - currentRound + 1;
    return left < 0 ? 0 : left;
  }

  bool get isLastRound {
    final limit = config.maxRounds;
    return limit != null && currentRound >= limit;
  }

  Map<String, Object?> toMap() => {
    'code': code,
    'hostId': hostId,
    'players': players,
    'playerNames': playerNames,
    'status': status.wireName,
    'config': config.toMap(),
    'currentRound': currentRound,
    'submittedBy': submittedBy,
    'rounds': rounds.map((r) => r.toMap()).toList(),
    'finishReason': finishReason?.wireName,
    'rematchOf': rematchOf,
    'rematchRoomCode': rematchRoomCode,
  };

  factory Room.fromMap(String code, Map<String, Object?> map) {
    return Room(
      code: code,
      hostId: (map['hostId'] as String?) ?? '',
      players: ((map['players'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
      playerNames: ((map['playerNames'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k.toString(), v?.toString() ?? 'Player'),
      ),
      status: RoomStatusCodec.fromWire(map['status']),
      config: GameConfig.fromMap(
        (map['config'] as Map?)?.cast<String, Object?>(),
      ),
      currentRound: (map['currentRound'] as num?)?.toInt() ?? 1,
      submittedBy: ((map['submittedBy'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
      rounds: ((map['rounds'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => GameRound.fromMap(m.cast<String, Object?>()))
          .toList(growable: false),
      finishReason: FinishReasonCodec.fromWire(map['finishReason']),
      rematchOf: map['rematchOf'] as String?,
      rematchRoomCode: map['rematchRoomCode'] as String?,
    );
  }

  Room copyWith({
    List<String>? players,
    Map<String, String>? playerNames,
    RoomStatus? status,
    GameConfig? config,
    int? currentRound,
    List<String>? submittedBy,
    List<GameRound>? rounds,
    FinishReason? finishReason,
    String? rematchRoomCode,
  }) {
    return Room(
      code: code,
      hostId: hostId,
      players: players ?? this.players,
      playerNames: playerNames ?? this.playerNames,
      status: status ?? this.status,
      config: config ?? this.config,
      currentRound: currentRound ?? this.currentRound,
      submittedBy: submittedBy ?? this.submittedBy,
      rounds: rounds ?? this.rounds,
      finishReason: finishReason ?? this.finishReason,
      createdAt: createdAt,
      updatedAt: updatedAt,
      rematchOf: rematchOf,
      rematchRoomCode: rematchRoomCode ?? this.rematchRoomCode,
    );
  }
}
