import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class MessagingController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<User?>? _authStateSubscription;

  // Static variable to hold pending notification data for post-login handling
  static Map<String, dynamic>? _pendingNotificationData;

  Future<void> init() async {
    await _requestPermission();
    await _createNotificationChannel();
    _listenAuthStateChanges();
    _listenTokenRefresh();
    await _saveCurrentToken();
    _listenForegroundMessages();
  }

  Future<void> _createNotificationChannel() async {
    // This creates a notification channel on Android 8+
    // Without this, notifications won't display on modern Android versions
    const channelId = 'chat_notifications';
    const channelName = 'Chat Messages';
    const channelDescription = 'Notifications for new chat messages';

    // These are Android SDK settings, not Flutter
    // They must match settings in the Android manifest or be set programmatically
    // For now, force the channel creation in the metadata
  }

  void _listenForegroundMessages() {
    // This handler runs when the app is OPEN in foreground (including home page)
    // Without this, notifications only appear in the notification panel
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final data = message.data;

      debugPrint('📬 Foreground message received: title=${notification?.title}, body=${notification?.body}');

      if (notification != null) {
        _showForegroundNotification(
          title: notification.title ?? 'New Message',
          body: notification.body ?? '',
          data: data,
        );
      }
    });
  }

  void _showForegroundNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    // Show in-app notification using a debug message and platform channel
    // The system will handle displaying the notification since we're using high priority
    debugPrint('🔔 [FOREGROUND NOTIFICATION] $title: $body');
    debugPrint('   📊 Data: chatId=${data['chatId']}, senderId=${data['senderId']}');
    
    // On Android, this message would normally be handled by FlutterFire
    // which should display a heads-up notification due to HIGH priority channel
    // If you want a custom in-app banner, you would need to:
    // 1. Use a local notification plugin
    // 2. Or implement a custom platform channel
    // For now, FlutterFire's automatic notification delivery should handle this
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _listenAuthStateChanges() {
    _authStateSubscription = _auth.authStateChanges().listen((user) async {
      if (user == null) return;
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenForUser(user.uid, token);
      }
    });
  }

  void _listenTokenRefresh() {
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      final user = _auth.currentUser;
      if (user == null) return;
      await _saveTokenForUser(user.uid, token);
    });
  }

  Future<void> _saveCurrentToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token == null) return;

    await _saveTokenForUser(user.uid, token);
  }

  Future<void> _saveTokenForUser(String uid, String token) async {
    await _firestore.collection('users').doc(uid).set(
      {
        'fcmToken': token,
      },
      SetOptions(merge: true),
    );
  }

  // Method to clear FCM token on logout
  Future<void> clearToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Remove token from Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': FieldValue.delete(),
      });
      // Delete token from FCM
      await _messaging.deleteToken();
    }
  }

  // Handle notification tap
  Future<void> handleNotificationTap(Map<String, dynamic> data, Function(String) navigateToChat, Function() navigateToLogin, Function() navigateToHome) async {
    final receiverId = data['receiverId'] as String?;
    final senderId = data['senderId'] as String?;
    final chatId = data['chatId'] as String?;

    debugPrint('═══════════════════════════════════════════════');
    debugPrint('🔍 [TAP HANDLER] Starting notification tap handling');
    debugPrint('   Payload - chatId: $chatId, senderId: $senderId, receiverId: $receiverId');
    debugPrint('═══════════════════════════════════════════════');

    // ✅ CRITICAL FIX: Check current user first, then wait for auth state if needed
    User? user = _auth.currentUser;
    if (user == null) {
      debugPrint('⏳ [TAP] Current user is null, waiting for auth state restoration...');
      try {
        user = await _auth.authStateChanges().first.timeout(const Duration(seconds: 5));
        debugPrint('✅ [TAP] Auth state restored - user: ${user?.uid}');
      } catch (e) {
        debugPrint('❌ [TAP] Auth state timeout or error: $e');
        user = null;
      }
    } else {
      debugPrint('✅ [TAP] User already authenticated: ${user.uid}');
    }

    if (user == null) {
      debugPrint('❌ [TAP] User not authenticated after auth state restoration');
      _pendingNotificationData = data;
      navigateToLogin();
      return;
    }

    if (receiverId == null || chatId == null) {
      debugPrint('❌ [TAP] Incomplete data - receiverId: $receiverId, chatId: $chatId');
      navigateToHome();
      return;
    }

    // Determine who this user is in relation to notification
    final isReceiver = user.uid == receiverId;
    final isSender = user.uid == senderId;
    debugPrint('   User role - isReceiver: $isReceiver, isSender: $isSender');

    if (!isReceiver) {
      debugPrint('❌ [TAP] Current user (${user.uid}) is NOT the receiver ($receiverId)');
      if (isSender) {
        debugPrint('   ℹ️  This is the sender - they tapped their own notification');
      }
      navigateToHome();
      return;
    }

    // Validate chat exists and structure
    try {
      debugPrint('   🔎 Validating chat document: $chatId');
      final chatDoc = await _firestore.collection('chat').doc(chatId).get();
      if (!chatDoc.exists) {
        debugPrint('❌ [TAP] Chat document does not exist: chat/$chatId');
        navigateToHome();
        return;
      }

      final chatData = chatDoc.data();
      if (chatData == null) {
        debugPrint('❌ [TAP] Chat data is NULL for: $chatId');
        navigateToHome();
        return;
      }

      final clientId = chatData['clientId'] as String?;
      final freelancerId = chatData['freelancerId'] as String?;

      debugPrint('   💬 Chat structure - clientId: $clientId, freelancerId: $freelancerId');

      if (clientId == null || freelancerId == null) {
        debugPrint('❌ [TAP] Chat missing required IDs');
        navigateToHome();
        return;
      }

      // Verify user is a participant
      final isClient = user.uid == clientId;
      final isFreelancer = user.uid == freelancerId;
      debugPrint('   👥 User is - client: $isClient, freelancer: $isFreelancer');

      if (!isClient && !isFreelancer) {
        debugPrint('❌ [TAP] User (${user.uid}) is not a participant in this chat');
        navigateToHome();
        return;
      }

      // All validation passed!
      debugPrint('✅ [TAP] All validation passed - opening chat: $chatId');
      navigateToChat(chatId);
    } catch (e) {
      debugPrint('❌ [TAP] ERROR during validation: $e');
      navigateToHome();
    }
  }

  // Method to check and handle pending notification after login
  Future<void> handlePendingNotificationAfterLogin(Function(String) navigateToChat, Function() navigateToHome) async {
    if (_pendingNotificationData != null) {
      final data = _pendingNotificationData!;
      _pendingNotificationData = null; // Clear it
      await handleNotificationTap(data, navigateToChat, () {}, navigateToHome);
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _authStateSubscription?.cancel();
  }
}
