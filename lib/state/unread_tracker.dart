import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/room.dart';
import '../services/backend/game_backend.dart';

/// Per-conversation unread chat counts and last-message previews, keyed by
/// pair conversation id (see [pairConversationId]).
///
/// The React port keeps this in its store. Here it is one small ChangeNotifier
/// so the home and chat-list screens can show live badges without each opening
/// its own message listeners.
///
/// A message counts as unread when it comes from the other player (system round
/// cards are not messages) and arrived after the conversation was last read.
class UnreadTracker extends ChangeNotifier {
  UnreadTracker(this._backend);

  final GameBackend _backend;
  final Map<String, StreamSubscription<List<ChatMessage>>> _subs = {};
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, int> _baseline = {};
  final Map<String, int> _unread = {};
  final Set<String> _openChats = {};
  StreamSubscription<List<Room>>? _roomsSub;

  int unreadFor(String conversationId) => _unread[conversationId] ?? 0;

  int get totalUnread => _unread.values.fold(0, (sum, n) => sum + n);

  ChatMessage? lastMessageFor(String conversationId) {
    final list = _messages[conversationId];
    if (list == null || list.isEmpty) return null;
    return list.last;
  }

  /// Follows the rooms the local player is in, deriving the pair
  /// conversation to watch from each full room. Safe to call more than once.
  void follow() {
    if (_roomsSub != null) return;
    _roomsSub = _backend.watchMyRooms().listen(
      _syncRooms,
      onError: (Object error) {
        debugPrint('unread tracker rooms stream error: $error');
      },
    );
  }

  void _syncRooms(List<Room> rooms) {
    final localId = _backend.localPlayerId;
    final conversationIds = <String>{};
    for (final room in rooms) {
      if (!room.isFull) continue;
      final opponentId = room.opponentOf(localId);
      if (opponentId == null || opponentId.isEmpty) continue;
      conversationIds.add(pairConversationId(localId, opponentId));
    }
    for (final id in _subs.keys.toList()) {
      if (conversationIds.contains(id)) continue;
      _subs.remove(id)?.cancel();
      _messages.remove(id);
      _unread.remove(id);
      _baseline.remove(id);
    }
    for (final id in conversationIds) {
      if (!_subs.containsKey(id)) {
        _subs[id] = _backend.watchMessages(id).listen(
          (messages) {
            _messages[id] = messages;
            _recompute(id);
          },
          onError: (Object error) {
            debugPrint('unread tracker messages stream error: $error');
          },
        );
      }
    }
    notifyListeners();
  }

  void _recompute(String conversationId) {
    final list = _messages[conversationId];
    if (list == null) return;
    final incoming = list.where(_isIncoming).length;
    final base = _baseline[conversationId] ?? 0;
    final next = _openChats.contains(conversationId)
        ? 0
        : (incoming > base ? incoming - base : 0);
    if (next != (_unread[conversationId] ?? 0)) {
      _unread[conversationId] = next;
      notifyListeners();
    }
  }

  bool _isIncoming(ChatMessage m) =>
      m.system != true && m.senderId != _backend.localPlayerId;

  /// Marks a conversation as read up to whatever has arrived so far.
  void markRead(String conversationId) {
    final list = _messages[conversationId];
    _baseline[conversationId] = list?.where(_isIncoming).length ?? 0;
    if ((_unread[conversationId] ?? 0) != 0) {
      _unread[conversationId] = 0;
      notifyListeners();
    }
  }

  void setChatOpen(String conversationId, bool open) {
    if (open) {
      _openChats.add(conversationId);
      markRead(conversationId);
    } else {
      _openChats.remove(conversationId);
      // Everything that arrived while the chat was open has been seen;
      // advance the baseline instead of letting it resurface as unread.
      markRead(conversationId);
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
