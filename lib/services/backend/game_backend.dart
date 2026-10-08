import '../../core/game_config.dart';
import '../../game/game_engine.dart';
import '../../models/chat_message.dart';
import '../../models/friend.dart';
import '../../models/game_invite.dart';
import '../../models/room.dart';

/// Thrown for failures we want to surface to the player verbatim.
class BackendException implements Exception {
  const BackendException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'BackendException($code): $message';
}

/// Computes a round outcome from the two revealed words. Supplied by the game
/// controller so the backend never needs to know the rules.
typedef RoundResolver =
    RoundResolution Function(Room room, String p1Word, String p2Word);

/// The sync layer contract.
///
/// [FirestoreBackend] is the real implementation — Firestore itself is the
/// transport between the two clients, so there is no custom server. The
/// interface exists so the game logic never talks to Firestore directly, and so
/// the app stays runnable (see `LocalBackend`) before Firebase is configured.
abstract class GameBackend {
  /// Stable id for the signed-in player.
  String get localPlayerId;

  /// True when this backend actually syncs across devices.
  bool get isNetworked;

  /// Human-readable label for the debug banner.
  String get label;

  Future<void> initialize();

  Future<void> setDisplayName(String name);
  String get displayName;

  // ---- rooms ----

  /// Creates a room with a unique short code and `status: waiting`.
  Future<Room> createRoom({
    GameConfig config = GameConfig.defaults,
    String? rematchOf,
  });

  /// Joins an existing waiting room and flips it to `status: active`.
  Future<Room> joinRoom(String code);

  /// Live view of the room document. Emits null if the room disappears.
  Stream<Room> watchRoom(String code);

  Future<Room?> fetchRoom(String code);

  /// Writes this player's word for [roundIndex] to a private per-player doc and
  /// adds them to `submittedBy`.
  Future<void> submitWord({
    required String code,
    required int roundIndex,
    required String word,
  });

  /// Reads both words for [roundIndex]. Only succeeds once both players have
  /// submitted — enforced by the security rules, not just by convention.
  Future<({String p1Word, String p2Word})?> readSubmissions({
    required String code,
    required int roundIndex,
  });

  /// Appends the resolved round to history and advances or ends
  /// the game. Idempotent: safe for both clients to call for the same round.
  Future<void> commitRound({
    required String code,
    required int roundIndex,
    required RoundResolver resolve,
  });

  /// Marks the room finished as abandoned if it was still in progress.
  Future<void> leaveRoom(String code);

  /// Creates a fresh room and points [code] at it so the opponent can follow.
  Future<Room> startRematch(Room room);

  /// Pings the opponent in [code] when waiting for their turn.
  Future<void> nudgeRoom(String code);

  // ---- chat ----

  Stream<List<ChatMessage>> watchMessages(String code);

  Future<void> sendMessage({required String code, required String text});

  // ---- friends ----

  Stream<List<Friend>> watchFriends();

  /// Records the pairing on both sides after a successful connection.
  Future<void> rememberPairing({
    required String friendId,
    required String friendName,
  });

  Future<void> forgetFriend(String friendId);

  /// Creates a room and drops an invite in [friendId]'s inbox, so an
  /// established pairing never needs the code handshake again.
  Future<Room> inviteFriend({
    required String friendId,
    GameConfig config = GameConfig.defaults,
  });

  /// Updates Duo Chemistry metrics (games played, rounds, best sync, memory bank)
  /// between the local player and [friendId] after a game finishes.
  Future<void> recordGameCompletion({
    required String friendId,
    required String friendName,
    required int roundsCount,
    required bool converged,
    String? convergedWord,
  });

  /// Invites addressed to the local player.
  Stream<List<GameInvite>> watchInvites();

  Future<void> dismissInvite(String roomCode);

  void dispose();
}
