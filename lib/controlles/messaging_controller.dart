import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef ForegroundMessageCallback =
    void Function(String title, String body, Map<String, dynamic> data);

class MessagingController {
  static const Set<String> _requestNotificationTypes = {
    'service_request',
    'announcement_request',
    'proposal_accepted',
    'proposal_rejected',
    'request_accepted',
    'request_deleted',
    'request_rejected',
    'proposal_received',
    'contract',
    'contract_generated',
    'contract_approved',
    'contract_disapproved',
    'contract_termination_requested',
    'contract_termination_approved',
    'contract_termination_rejected',
    'contract_terminated',
    'contract_payment_completed',
  };

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<User?>? _authStateSubscription;

  // Static variable to hold pending notification data for post-login handling
  static Map<String, dynamic>? _pendingNotificationData;
  ForegroundMessageCallback? _onForegroundMessage;

  Future<void> init({ForegroundMessageCallback? onForegroundMessage}) async {
    _onForegroundMessage = onForegroundMessage;
    await _requestPermission();
    await _createNotificationChannel();
    _listenAuthStateChanges();
    _listenTokenRefresh();
    await _saveCurrentToken();
    _listenForegroundMessages();
  }

  Future<void> _createNotificationChannel() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'chat_notifications',
            'Chat Messages',
            description: 'Notifications for new chat messages',
            importance: Importance.high,
          ),
        );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'request_notifications',
            'Request Notifications',
            description: 'Notifications for service requests and proposals',
            importance: Importance.high,
          ),
        );

    if (kDebugMode) {
      debugPrint('✅ Notification channels created (chat + request)');
    }
  }

  void _listenForegroundMessages() {
    // This handler runs when the app is OPEN in foreground (including home page)
    // Without this, notifications only appear in the notification panel
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      final data = message.data;
      final origin = (data['notificationOrigin'] ?? '').toString().trim();

      debugPrint(
        '📬 Foreground message received: title=${notification?.title}, body=${notification?.body}',
      );

      if (origin == 'firestore_contract_notification') {
        debugPrint('ℹ️ Skipping duplicate foreground contract push banner');
        return;
      }

      if (notification != null) {
        final title = notification.title ?? 'New Message';
        final body = notification.body ?? '';
        final type = (data['type'] ?? '').toString().trim().toLowerCase();
        final channelId = _requestNotificationTypes.contains(type)
            ? 'request_notifications'
            : 'chat_notifications';

        await _localNotifications.show(
          notification.hashCode,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              channelId == 'request_notifications'
                  ? 'Request Notifications'
                  : 'Chat Messages',
              importance: Importance.max,
              priority: Priority.high,
              ticker: 'ticker',
            ),
          ),
        );

        _showForegroundNotification(title: title, body: body, data: data);
      }
    });
  }

  void _showForegroundNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    debugPrint('🔔 [FOREGROUND NOTIFICATION] $title: $body');
    debugPrint(
      '   📊 Data: chatId=${data['chatId']}, senderId=${data['senderId']}',
    );

    _onForegroundMessage?.call(title, body, data);
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
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
    await _firestore.collection('users').doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
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
  Future<void> handleNotificationTap(
    Map<String, dynamic> data,
    Function(String) navigateToChat,
    Function() navigateToLogin,
    Function() navigateToHome,
  ) async {
    final receiverId = data['receiverId'] as String?;
    final senderId = data['senderId'] as String?;
    final chatId = data['chatId'] as String?;

    debugPrint('═══════════════════════════════════════════════');
    debugPrint('🔍 [TAP HANDLER] Starting notification tap handling');
    debugPrint(
      '   Payload - chatId: $chatId, senderId: $senderId, receiverId: $receiverId',
    );
    debugPrint('═══════════════════════════════════════════════');

    // ✅ CRITICAL FIX: Check current user first, then wait for auth state if needed
    User? user = _auth.currentUser;
    if (user == null) {
      debugPrint(
        '⏳ [TAP] Current user is null, waiting for auth state restoration...',
      );
      try {
        user = await _auth.authStateChanges().first.timeout(
          const Duration(seconds: 5),
        );
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
      debugPrint(
        '❌ [TAP] Incomplete data - receiverId: $receiverId, chatId: $chatId',
      );
      navigateToHome();
      return;
    }

    // Determine who this user is in relation to notification
    final isReceiver = user.uid == receiverId;
    final isSender = user.uid == senderId;
    debugPrint('   User role - isReceiver: $isReceiver, isSender: $isSender');

    if (!isReceiver) {
      debugPrint(
        '❌ [TAP] Current user (${user.uid}) is NOT the receiver ($receiverId)',
      );
      if (isSender) {
        debugPrint(
          '   ℹ️  This is the sender - they tapped their own notification',
        );
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

      debugPrint(
        '   💬 Chat structure - clientId: $clientId, freelancerId: $freelancerId',
      );

      if (clientId == null || freelancerId == null) {
        debugPrint('❌ [TAP] Chat missing required IDs');
        navigateToHome();
        return;
      }

      // Verify user is a participant
      final isClient = user.uid == clientId;
      final isFreelancer = user.uid == freelancerId;
      debugPrint(
        '   👥 User is - client: $isClient, freelancer: $isFreelancer',
      );

      if (!isClient && !isFreelancer) {
        debugPrint(
          '❌ [TAP] User (${user.uid}) is not a participant in this chat',
        );
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
  Future<void> handlePendingNotificationAfterLogin(
    Function(String) navigateToChat,
    Function() navigateToHome,
  ) async {
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
