import 'dart:async';
import 'dart:math';

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
import '../services/sound_service.dart';
import '../ui/twin_palette.dart';
import 'unread_tracker.dart';

enum SessionStatus { loading, ready, failed }

/// App-wide singletons: the sync backend and the game engine.
class AppSession extends ChangeNotifier {
  AppSession();

  static const _nameKey = 'display_name';
  static const _emojiKey = 'profile_emoji';
  static const _avatarKey = 'profile_avatar_id';
  static const _themeKey = 'theme_id';
  static const _usernameKey = 'username';
  static const _onboardingKey = 'onboarding_done';

  SessionStatus status = SessionStatus.loading;
  String? errorMessage;

  GameBackend? _backend;
  UnreadTracker? _unread;

  /// Stateless and cheap — the rules need no data to apply.
  final GameEngine engine = const GameEngine();

  String _displayName = 'Player';
  String _profileEmoji = '🙂';
  String _profileAvatarId = AppAvatars.fallback;

  /// The chrome theme the player picked (Navy by default). The
  /// brand stage (boot, reveal, twinning, the shared card) ignores
  /// this and stays navy.
  String _themeId = 'navy';
  String get themeId => _themeId;
  TwinPalette get palette => TwinPalette.byId(_themeId);

  /// Whether the player has ever confirmed a name / picked an avatar.
  /// Until both are true, the create and join flows suggest setting the
  /// profile up first.
  bool _hasPlayerName = false;
  bool _hasPlayerAvatar = false;

  /// The player's unique username, without the @ (e.g. vatsal.42).
  /// Minted from the display name and claimed against the registry.
  /// The display name can change freely afterwards; this only moves
  /// when the player edits it in Settings.
  String? _username;

  /// First-run onboarding: intro slides plus the name and face step.
  /// Existing players (profile already set up) never see it.
  bool _onboardingDone = false;
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

  bool get onboardingDone => _onboardingDone;

  /// The player's username, without the @. Falls back to the base
  /// derived from the display name for display only; the claimed,
  /// persisted value is set in [initialize] or [completeOnboarding].
  String get username => _username ?? usernameBase(_displayName);

  /// The base a username is built from: lowercase, spaces and symbols
  /// dropped (Rahul Sharma -> rahulsharma), capped at 16 characters.
  static String usernameBase(String name) {
    var base = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    if (base.isEmpty) base = 'player';
    if (base.length > 16) base = base.substring(0, 16);
    return base;
  }

  /// Username shape: 3 to 20 characters of letters and digits, with
  /// single dots or underscores between them, never at either end.
  static bool isValidUsername(String value) {
    if (value.length < 3 || value.length > 20) return false;
    return RegExp(r'^[a-z0-9]+([._][a-z0-9]+)*$').hasMatch(value);
  }

  /// Finds a username for [name] that is free right now: the plain
  /// base when it is open (@vatsal), otherwise the base with a short
  /// number (@vatsal.42, then @vatsal.4821). Pass [avoid] to force a
  /// different one than the suggestion already on screen (refresh).
  /// This only looks; claiming happens in [claimUsername].
  Future<String> suggestUsername(String name, {String? avoid}) async {
    final base = usernameBase(name);
    final backend = _backend;
    if (backend == null) return base;
    if (base != avoid && await backend.isUsernameAvailable(base)) {
      return base;
    }
    final rand = Random();
    for (var i = 0; i < 6; i++) {
      final candidate = '$base.${10 + rand.nextInt(90)}';
      if (candidate != avoid &&
          await backend.isUsernameAvailable(candidate)) {
        return candidate;
      }
    }
    for (var i = 0; i < 8; i++) {
      final candidate = '$base.${1000 + rand.nextInt(9000)}';
      if (candidate != avoid &&
          await backend.isUsernameAvailable(candidate)) {
        return candidate;
      }
    }
    return '$base.${10000 + rand.nextInt(89999)}';
  }

  /// Claims [candidate] for this player and saves it, releasing the
  /// old username when there was one. On a lost race it falls back to
  /// the next free variation of the same name. Returns the username
  /// actually held afterwards.
  Future<String> claimUsername(
    String candidate, {
    required String nameForFallback,
  }) async {
    final backend = _backend;
    if (backend == null) return username;
    var held = candidate;
    var ok = await backend.claimUsername(candidate);
    if (!ok) {
      held = await suggestUsername(nameForFallback, avoid: candidate);
      ok = await backend.claimUsername(held);
    }
    if (!ok) return username;
    final old = _username;
    _username = held;
    if (old != null && old != held) {
      await backend.releaseUsername(old);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, held);
    notifyListeners();
    return held;
  }

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
      _themeId = prefs.getString(_themeKey) ?? 'navy';
      await SoundService.instance.load();
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
      _onboardingDone =
          (prefs.getBool(_onboardingKey) ?? false) || profileIsSetUp;
      _username = prefs.getString(_usernameKey);

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

      if (_username == null && profileIsSetUp) {
        // Players from before usernames existed get theirs claimed
        // from the name they already play under. Cosmetic, like the
        // profile sync above: a failure never blocks the boot.
        try {
          final suggestion = await suggestUsername(_displayName);
          await claimUsername(suggestion, nameForFallback: _displayName);
        } catch (error) {
          debugPrint('Username claim failed, continuing without it: $error');
        }
      }

      _unread = UnreadTracker(_backend!, prefs: prefs)..follow();

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
    _onboardingDone = true;
    _username ??= usernameBase(_displayName);
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

  Future<void> setThemeId(String id) async {
    if (id == _themeId) return;
    _themeId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, id);
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

  /// Finishes first-run onboarding: saves the name and face the
  /// player picked, claims the exact username the onboarding screen
  /// showed them, and marks onboarding done so it never shows again.
  Future<void> completeOnboarding({
    required String name,
    required String avatarId,
    required String username,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) await setDisplayName(trimmed);
    await setProfileAvatarId(avatarId);
    // If the shown username was taken in the meantime, this lands on
    // the next free variation of the same name instead of failing.
    await claimUsername(username, nameForFallback: _displayName);
    _onboardingDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
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
