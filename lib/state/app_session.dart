import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_bootstrap.dart';
import '../game/game_engine.dart';
import '../models/friend.dart';
import '../services/backend/firestore_backend.dart';
import '../services/backend/game_backend.dart';
import '../services/backend/local_backend.dart';
import '../services/embeddings/glove_similarity.dart';

enum SessionStatus { loading, ready, failed }

/// App-wide singletons: the sync backend, the embedding table and the game
/// engine that ties them together.
class AppSession extends ChangeNotifier {
  AppSession();

  static const _nameKey = 'display_name';

  SessionStatus status = SessionStatus.loading;
  String? errorMessage;

  GameBackend? _backend;
  GloveSimilarity? _similarity;
  GameEngine? _engine;

  String _displayName = 'Player';
  String _loadingStep = 'Starting up';

  /// Set when Firebase could not be initialised and we fell back to offline
  /// practice, so the UI can say so plainly instead of pretending to be online.
  String? backendFallbackReason;

  GameBackend get backend {
    final b = _backend;
    if (b == null) throw StateError('AppSession not initialised');
    return b;
  }

  GloveSimilarity get similarity {
    final s = _similarity;
    if (s == null) throw StateError('AppSession not initialised');
    return s;
  }

  GameEngine get engine {
    final e = _engine;
    if (e == null) throw StateError('AppSession not initialised');
    return e;
  }

  String get displayName => _displayName;
  String get loadingStep => _loadingStep;
  String get localPlayerId => _backend?.localPlayerId ?? '';
  bool get isNetworked => _backend?.isNetworked ?? false;

  Stream<List<Friend>> get friends =>
      _backend?.watchFriends() ?? Stream.value(const []);

  Future<void> initialize() async {
    try {
      _setStep('Loading word vectors');
      _similarity = await GloveSimilarity.load();
      _engine = GameEngine(_similarity!);

      final prefs = await SharedPreferences.getInstance();
      _displayName = prefs.getString(_nameKey) ?? 'Player';

      _setStep('Connecting');
      _backend = await _createBackend();
      await _backend!.initialize();
      await _backend!.setDisplayName(_displayName);

      status = SessionStatus.ready;
    } catch (error, stack) {
      debugPrint('AppSession init failed: $error\n$stack');
      status = SessionStatus.failed;
      errorMessage = '$error';
    }
    notifyListeners();
  }

  Future<GameBackend> _createBackend() async {
    try {
      await Firebase.initializeApp(options: resolveFirebaseOptions());
      final backend = FirestoreBackend(displayName: _displayName);
      backendFallbackReason = null;
      return backend;
    } catch (error) {
      // No Firebase project wired up yet. Rather than dead-ending on a crash,
      // drop into offline practice and say why.
      debugPrint('Firebase unavailable, using offline practice: $error');
      backendFallbackReason =
          'Firebase is not configured on this build, so games are local only. '
          'See README.md to connect a project.';
      return LocalBackend(
        similarity: similarity,
        displayName: _displayName,
      );
    }
  }

  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == _displayName) return;
    _displayName = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, trimmed);
    await _backend?.setDisplayName(trimmed);
    notifyListeners();
  }

  void _setStep(String step) {
    _loadingStep = step;
    notifyListeners();
  }

  @override
  void dispose() {
    _backend?.dispose();
    super.dispose();
  }
}
