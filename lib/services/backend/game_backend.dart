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

/// The one conversation shared by a pair of players. Chat belongs to the
/// pair, not to any single room: every game between the same two players,
/// the in-game chat and the Chats tab all read and write this conversation,
/// so a thread survives the game it started in. Player ids never contain
/// an underscore, so the joined form is unambiguous.
String pairConversationId(String a, String b) =>
    a.compareTo(b) <= 0 ? '${a}_$b' : '${b}_$a';

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

  /// Publishes the player's chosen avatar so it lands in their rooms and
  /// the other player's screen shows the face they actually picked.
  Future<void> setAvatarId(String avatarId);
  String get avatarId;

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

  /// Every room the local player is part of, newest activity first.
  ///
  /// This is what powers the "Your games" list: active games to jump back into
  /// and finished ones for history.
  Stream<List<Room>> watchMyRooms();

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

  /// The pair conversation's messages, oldest first. [conversationId] comes
  /// from [pairConversationId]; it is deliberately not a room code.
  Stream<List<ChatMessage>> watchMessages(String conversationId);

  Future<void> sendMessage({
    required String conversationId,
    required String text,
  });

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

  /// Fills the empty second seat of a waiting room with the built-in practice
  /// partner, so a solo player can try the full loop without a second device.
  ///
  /// The default throws because only backends that can stand in for a player
  /// (the local one) support it.
  Future<void> addPracticePartner(String code) async {
    throw UnsupportedError('$runtimeType cannot add a practice partner');
  }

  /// Invites addressed to the local player.
  Stream<List<GameInvite>> watchInvites();

  Future<void> dismissInvite(String roomCode);

  void dispose();
}
