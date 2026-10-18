import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/room.dart';
import '../services/backend/game_backend.dart';

/// Per-room unread chat counts and last-message previews.
///
/// The React port keeps this in its store. Here it is one small ChangeNotifier
/// so the home and chat-list screens can show live badges without each opening
/// its own message listeners.
///
/// A message counts as unread when it comes from the other player (system round
/// cards are not messages) and arrived after the room's chat was last read.
class UnreadTracker extends ChangeNotifier {
  UnreadTracker(this._backend);

  final GameBackend _backend;
  final Map<String, StreamSubscription<List<ChatMessage>>> _subs = {};
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, int> _baseline = {};
  final Map<String, int> _unread = {};
  final Set<String> _openChats = {};
  StreamSubscription<List<Room>>? _roomsSub;

  int unreadFor(String code) => _unread[code] ?? 0;

  int get totalUnread => _unread.values.fold(0, (sum, n) => sum + n);

  ChatMessage? lastMessageFor(String code) {
    final list = _messages[code];
    if (list == null || list.isEmpty) return null;
    return list.last;
  }

  /// Follows the rooms the local player is in. Safe to call more than once.
  void follow() {
    if (_roomsSub != null) return;
    _roomsSub = _backend.watchMyRooms().listen(_syncRooms);
  }

  void _syncRooms(List<Room> rooms) {
    final codes = rooms.map((r) => r.code).toSet();
    for (final code in _subs.keys.toList()) {
      if (codes.contains(code)) continue;
      _subs.remove(code)?.cancel();
      _messages.remove(code);
      _unread.remove(code);
      _baseline.remove(code);
    }
    for (final room in rooms) {
      if (!_subs.containsKey(room.code)) {
        _subs[room.code] =
            _backend.watchMessages(room.code).listen((messages) {
          _messages[room.code] = messages;
          _recompute(room.code);
        });
      }
    }
    notifyListeners();
  }

  void _recompute(String code) {
    final list = _messages[code];
    if (list == null) return;
    final incoming = list.where(_isIncoming).length;
    final base = _baseline[code] ?? 0;
    final next = _openChats.contains(code)
        ? 0
        : (incoming > base ? incoming - base : 0);
    if (next != (_unread[code] ?? 0)) {
      _unread[code] = next;
      notifyListeners();
    }
  }

  bool _isIncoming(ChatMessage m) =>
      m.system != true && m.senderId != _backend.localPlayerId;

  /// Marks a room's chat as read up to whatever has arrived so far.
  void markRead(String code) {
    final list = _messages[code];
    _baseline[code] = list?.where(_isIncoming).length ?? 0;
    if ((_unread[code] ?? 0) != 0) {
      _unread[code] = 0;
      notifyListeners();
    }
  }

  void setChatOpen(String code, bool open) {
    if (open) {
      _openChats.add(code);
      markRead(code);
    } else {
      _openChats.remove(code);
      _recompute(code);
    }
  }

  @override
  void dispose() {
    _roomsSub?.cancel();
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
    super.dispose();
  }
}
