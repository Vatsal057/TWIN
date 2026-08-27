import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../services/backend/game_backend.dart';

/// Room-scoped chat. Plain text only — no receipts, no typing indicators, no
/// media. Lives as long as the room does.
class ChatController extends ChangeNotifier {
  ChatController({required GameBackend backend, required String roomCode})
    : _backend = backend,
      _roomCode = roomCode;

  final GameBackend _backend;
  final String _roomCode;

  StreamSubscription<List<ChatMessage>>? _sub;

  List<ChatMessage> _messages = const [];
  bool _panelOpen = false;
  int _readCount = 0;
  String? _errorMessage;

  List<ChatMessage> get messages => _messages;
  bool get isOpen => _panelOpen;
  String? get errorMessage => _errorMessage;
  String get localPlayerId => _backend.localPlayerId;

  /// Messages from the opponent that arrived while the panel was closed.
  int get unreadCount {
    final unseen = _messages.length - _readCount;
    return unseen < 0 ? 0 : unseen;
  }

  void start() {
    _sub = _backend.watchMessages(_roomCode).listen(
      (messages) {
        _messages = messages;
        if (_panelOpen) _readCount = _messages.length;
        notifyListeners();
      },
      onError: (Object error) {
        debugPrint('chat stream error: $error');
      },
    );
  }

  void togglePanel() => setPanelOpen(!_panelOpen);

  void setPanelOpen(bool open) {
    if (_panelOpen == open) return;
    _panelOpen = open;
    if (open) _readCount = _messages.length;
    notifyListeners();
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _errorMessage = null;
    try {
      await _backend.sendMessage(code: _roomCode, text: trimmed);
    } on BackendException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Message did not send.';
      debugPrint('sendMessage failed: $e');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
