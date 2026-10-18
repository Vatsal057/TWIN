import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_avatars.dart';
import '../firebase_bootstrap.dart';
import '../game/game_engine.dart';
import '../models/friend.dart';
import '../models/room.dart';
import '../services/backend/firestore_backend.dart';
import '../services/backend/game_backend.dart';
import '../services/backend/local_backend.dart';
import 'unread_tracker.dart';

enum SessionStatus { loading, ready, failed }

/// App-wide singletons: the sync backend and the game engine.
class AppSession extends ChangeNotifier {
  AppSession();

  static const _nameKey = 'display_name';
  static const _emojiKey = 'profile_emoji';
  static const _avatarKey = 'profile_avatar_id';

  SessionStatus status = SessionStatus.loading;
  String? errorMessage;

  GameBackend? _backend;
  UnreadTracker? _unread;

  /// Stateless and cheap — the rules need no data to apply.
  final GameEngine engine = const GameEngine();

  String _displayName = 'Player';
  String _profileEmoji = '🙂';
  String _profileAvatarId = AppAvatars.fallback;

  /// Whether the player has ever confirmed a name / picked an avatar.
  /// Until both are true, the create and join flows suggest setting the
  /// profile up first.
  bool _hasPlayerName = false;
  bool _hasPlayerAvatar = false;
  String _loadingStep = 'Starting up';

  /// Set when Firebase could not be initialised and we fell back to offline
  /// practice, so the UI can say so plainly instead of pretending to be online.
  String? backendFallbackReason;

  GameBackend get backend {
    final b = _backend;
    if (b == null) throw StateError('AppSession not initialised');
    return b;
  }

  String get displayName => _displayName;

  /// Emoji shown on the local player's avatar.
  String get profileEmoji => _profileEmoji;

  /// ID of the illustrated avatar chosen in Settings ('a1'..'a8').
  String get profileAvatarId => _profileAvatarId;

  bool get hasPlayerName => _hasPlayerName;
  bool get hasPlayerAvatar => _hasPlayerAvatar;
  bool get profileIsSetUp => _hasPlayerName && _hasPlayerAvatar;

  String get loadingStep => _loadingStep;
  String get localPlayerId => _backend?.localPlayerId ?? '';
  bool get isNetworked => _backend?.isNetworked ?? false;

  Stream<List<Friend>> get friends =>
      _backend?.watchFriends() ?? Stream.value(const []);

  /// Live "Your games" feed: every room this player is in, newest first.
  Stream<List<Room>> get myRooms =>
      _backend?.watchMyRooms() ?? Stream.value(const []);

  /// Unread chat badges per room. Never null once the session is ready.
  UnreadTracker get unread {
    final tracker = _unread;
    if (tracker != null) return tracker;
    final backend = _backend;
    if (backend == null) throw StateError('AppSession not initialised');
    return _unread = UnreadTracker(backend)..follow();
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _displayName = prefs.getString(_nameKey) ?? 'Player';
      _profileEmoji = prefs.getString(_emojiKey) ?? '🙂';
      // Illustrated avatar choice; older installs only have the emoji
      // pick saved, so map that across once.
      _profileAvatarId = prefs.getString(_avatarKey) ??
          AppAvatars.fromLegacyEmoji(_profileEmoji);
      // A stored pick that is not in the current set (an old build, a
      // retired face) lands on the default face instead of breaking.
      if (!AppAvatars.isValid(_profileAvatarId)) {
        _profileAvatarId = AppAvatars.fallback;
      }
      _hasPlayerName = prefs.containsKey(_nameKey);
      // The legacy emoji pick counts as an avatar choice too: those
      // players picked a face, it was mapped across above.
      _hasPlayerAvatar =
          prefs.containsKey(_avatarKey) || prefs.containsKey(_emojiKey);

      _setStep('Connecting');
      _backend = await _createBackend();
      await _backend!.initialize();
      // Syncing the profile (name, avatar) is cosmetic. It must never be
      // able to fail the boot: a Firestore hiccup here once surfaced as
      // a "Could not start" screen, so failures are logged and skipped.
      try {
        await _backend!.setDisplayName(_displayName);
        await _backend!.setAvatarId(_profileAvatarId);
      } catch (error) {
        debugPrint('Profile sync failed, continuing without it: $error');
      }

      _unread = UnreadTracker(_backend!)..follow();

      status = SessionStatus.ready;
    } catch (error, stack) {
      debugPrint('AppSession init failed: $error\n$stack');
      status = SessionStatus.failed;
      errorMessage = '$error';
    }
    notifyListeners();
  }

  /// Boots the session around an already-built backend. Used by tests that
  /// drive the real UI against [LocalBackend].
  @visibleForTesting
  Future<void> initializeWith(GameBackend backend) async {
    _backend = backend;
    // Test sessions are built around a deliberate profile.
    _hasPlayerName = true;
    _hasPlayerAvatar = true;
    await backend.initialize();
    await backend.setDisplayName(_displayName);
    await backend.setAvatarId(_profileAvatarId);
    _unread = UnreadTracker(backend)..follow();
    status = SessionStatus.ready;
    notifyListeners();
  }

  Future<GameBackend> _createBackend() async {
    // Debug escape hatch: `--dart-define=TWIN_FORCE_LOCAL_BACKEND=true`
    // always uses the offline backend with its seeded demo rooms.
    const forceLocal =
        bool.hasEnvironment('TWIN_FORCE_LOCAL_BACKEND') &&
            bool.fromEnvironment('TWIN_FORCE_LOCAL_BACKEND');
    if (forceLocal) {
      return LocalBackend(displayName: _displayName, avatarId: _profileAvatarId);
    }
    try {
      await Firebase.initializeApp(options: resolveFirebaseOptions());
      final backend = FirestoreBackend(
        displayName: _displayName,
        avatarId: _profileAvatarId,
      );
      backendFallbackReason = null;
      return backend;
    } catch (error) {
      // No Firebase project wired up yet. Rather than dead-ending on a crash,
      // drop into offline practice and say why.
      debugPrint('Firebase unavailable, using offline practice: $error');
      backendFallbackReason =
          'Firebase is not configured on this build, so games are local only. '
          'See README.md to connect a project.';
      return LocalBackend(displayName: _displayName, avatarId: _profileAvatarId);
    }
  }

  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (trimmed == _displayName && _hasPlayerName) return;
    _displayName = trimmed;
    _hasPlayerName = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, trimmed);
    await _backend?.setDisplayName(trimmed);
    notifyListeners();
  }

  Future<void> setProfileEmoji(String emoji) async {
    if (emoji.isEmpty || emoji == _profileEmoji) return;
    _profileEmoji = emoji;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emojiKey, emoji);
    notifyListeners();
  }

  Future<void> setProfileAvatarId(String id) async {
    if (!AppAvatars.isValid(id)) return;
    if (id == _profileAvatarId && _hasPlayerAvatar) return;
    _profileAvatarId = id;
    _hasPlayerAvatar = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarKey, id);
    // Publish it so the other player's screen shows the new face too.
    await _backend?.setAvatarId(id);
    notifyListeners();
  }

  void _setStep(String step) {
    _loadingStep = step;
    notifyListeners();
  }

  @override
  void dispose() {
    _backend?.dispose();
    _unread?.dispose();
    super.dispose();
  }
}
