import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Manages Android FCM token registration and notification routing.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;

  /// Initializes push notifications on supported mobile platforms (Android).
  Future<void> initialize({
    required String uid,
    required FirebaseFirestore firestore,
    void Function(String roomCode)? onOpenRoom,
  }) async {
    // Web and desktop bypass native FCM registration to keep zero friction.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // Request alert and sound permissions on modern Android versions (API 33+).
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('NotificationService: push permissions denied');
        return;
      }

      // Retrieve device token and persist to user profile for Cloud Functions.
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveToken(firestore, uid, token);
      }

      // Handle token rotation.
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
        _saveToken(firestore, uid, newToken);
      });

      // Handle notification interaction when app was in background.
      _messageOpenedSub?.cancel();
      _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final roomCode = message.data['roomCode'] as String?;
        if (roomCode != null && roomCode.isNotEmpty && onOpenRoom != null) {
          onOpenRoom(roomCode);
        }
      });

      // Handle cold boot from notification tap.
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        final roomCode = initialMessage.data['roomCode'] as String?;
        if (roomCode != null && roomCode.isNotEmpty && onOpenRoom != null) {
          onOpenRoom(roomCode);
        }
      }
    } catch (e, stack) {
      debugPrint('NotificationService init failed: $e\n$stack');
    }
  }

  Future<void> _saveToken(
    FirebaseFirestore firestore,
    String uid,
    String token,
  ) async {
    try {
      await firestore.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastFcmUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _messageOpenedSub?.cancel();
  }
}
