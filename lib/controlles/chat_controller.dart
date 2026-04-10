import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final String _chatCollection = 'chat';
  String? get currentUserId => _auth.currentUser?.uid;

  final FirebaseStorage _storage = FirebaseStorage.instance;
  Future<void> sendImageMessage({
    required String chatId,
    required File imageFile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No logged in user found.');
    }

    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final storageRef = _storage
        .ref()
        .child('chat_images')
        .child(chatId)
        .child('$fileName.jpg');

    await storageRef.putFile(imageFile);
    final imageUrl = await storageRef.getDownloadURL();

    final chatRef = _firestore.collection(_chatCollection).doc(chatId);
    final messagesRef = chatRef.collection('messages');

    final chatDoc = await chatRef.get();
    final chatData = chatDoc.data() ?? {};

    final clientId = (chatData['clientId'] ?? '').toString();
    final isClientSender = user.uid == clientId;

    await messagesRef.add({
      'senderId': user.uid,
      'text': '',
      'type': 'image',
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await chatRef.set({
      'lastMessage': '📷 Photo',
      'updatedAt': FieldValue.serverTimestamp(),
      if (isClientSender)
        'unreadCountFreelancer': FieldValue.increment(1)
      else
        'unreadCountClient': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<String> createOrGetChat({
    required String requestId,
    required String clientId,
    required String freelancerId,
  }) async {
    final chatRef = _firestore.collection(_chatCollection).doc(requestId);
    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      await chatRef.set({
        'clientId': clientId,
        'freelancerId': freelancerId,
        'requestId': requestId,
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCountClient': 0,
        'unreadCountFreelancer': 0,
      });
    }

    return requestId;
  }

  Future<void> sendCombinedMessage({
    required String chatId,
    required String text,
    required List<File> imageFiles,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No logged in user found.');
    }

    final trimmedText = text.trim();

    final containsLink = RegExp(
      r'(http|https|www\.|\.com|\.net|\.org|\.sa)',
      caseSensitive: false,
    ).hasMatch(trimmedText);

    if (containsLink) {
      throw Exception('Links are not allowed.');
    }

    final chatRef = _firestore.collection(_chatCollection).doc(chatId);
    final messagesRef = chatRef.collection('messages');

    final chatDoc = await chatRef.get();
    final chatData = chatDoc.data() ?? {};

    final clientId = (chatData['clientId'] ?? '').toString();
    final isClientSender = user.uid == clientId;

    final List<String> imageUrls = [];

    for (final imageFile in imageFiles) {
      final fileName =
          DateTime.now().millisecondsSinceEpoch.toString() +
          '_${imageUrls.length}';

      final storageRef = _storage
          .ref()
          .child('chat_images')
          .child(chatId)
          .child('$fileName.jpg');

      await storageRef.putFile(imageFile);
      final imageUrl = await storageRef.getDownloadURL();
      imageUrls.add(imageUrl);
    }

    await messagesRef.add({
      'senderId': user.uid,
      'text': trimmedText,
      'type': imageUrls.isNotEmpty ? 'mixed' : 'text',
      'imageUrls': imageUrls,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    String lastMessage;
    if (trimmedText.isNotEmpty && imageUrls.isNotEmpty) {
      lastMessage = '📷 Photo + message';
    } else if (imageUrls.isNotEmpty) {
      lastMessage = imageUrls.length == 1
          ? '📷 Photo'
          : '📷 ${imageUrls.length} Photos';
    } else {
      lastMessage = trimmedText;
    }

    await chatRef.set({
      'lastMessage': lastMessage,
      'updatedAt': FieldValue.serverTimestamp(),
      if (isClientSender)
        'unreadCountFreelancer': FieldValue.increment(1)
      else
        'unreadCountClient': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection(_chatCollection)
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No logged in user found.');
    }

    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      throw Exception('Message cannot be empty.');
    }

    final containsLink = RegExp(
      r'(http|https|www\.|\.com|\.net|\.org|\.sa)',
      caseSensitive: false,
    ).hasMatch(trimmedText);

    if (containsLink) {
      throw Exception('Links are not allowed.');
    }

    final chatRef = _firestore.collection(_chatCollection).doc(chatId);
    final messagesRef = chatRef.collection('messages');

    final chatDoc = await chatRef.get();
    final chatData = chatDoc.data() ?? {};

    final clientId = (chatData['clientId'] ?? '').toString();
    final isClientSender = user.uid == clientId;

    await messagesRef.add({
      'senderId': user.uid,
      'text': trimmedText,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await chatRef.set({
      'lastMessage': trimmedText,
      'updatedAt': FieldValue.serverTimestamp(),
      if (isClientSender)
        'unreadCountFreelancer': FieldValue.increment(1)
      else
        'unreadCountClient': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> markMessagesAsRead(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final chatRef = _firestore.collection(_chatCollection).doc(chatId);

    // ✅ 1. نجيب الرسائل غير المقروءة
    final unreadMessages = await chatRef
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .get();

    // ✅ 2. نحدثها كمقروءة (لكن فقط اللي مو من نفس المستخدم)
    for (final doc in unreadMessages.docs) {
      final data = doc.data();
      final senderId = (data['senderId'] ?? '').toString();

      if (senderId != user.uid) {
        await doc.reference.update({'isRead': true});
      }
    }

    // ✅ 3. نجيب بيانات الشات
    final chatDoc = await chatRef.get();
    final chatData = chatDoc.data() ?? {};

    final clientId = (chatData['clientId'] ?? '').toString();

    if (user.uid == clientId) {
      await chatRef.set({'unreadCountClient': 0}, SetOptions(merge: true));
    } else {
      await chatRef.set({'unreadCountFreelancer': 0}, SetOptions(merge: true));
    }
  }

  Stream<int> getTotalUnreadCount() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection(_chatCollection)
        .where(
          Filter.or(
            Filter('clientId', isEqualTo: user.uid),
            Filter('freelancerId', isEqualTo: user.uid),
          ),
        )
        .snapshots()
        .map((snapshot) {
          int total = 0;

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final clientId = (data['clientId'] ?? '').toString();

            final isClient = user.uid == clientId;

            if (isClient) {
              total += ((data['unreadCountClient'] ?? 0) as num).toInt();
            } else {
              total += ((data['unreadCountFreelancer'] ?? 0) as num).toInt();
            }
          }

          return total;
        });
  }

  Stream<List<Map<String, dynamic>>> getMyChatsWithUserData() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection(_chatCollection)
        .where(
          Filter.or(
            Filter('clientId', isEqualTo: user.uid),
            Filter('freelancerId', isEqualTo: user.uid),
          ),
        )
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final List<Map<String, dynamic>> chats = [];

          for (final doc in snapshot.docs) {
            final data = doc.data();

            final clientId = (data['clientId'] ?? '').toString();
            final freelancerId = (data['freelancerId'] ?? '').toString();

            final isClient = user.uid == clientId;
            final otherUserId = isClient ? freelancerId : clientId;
            final otherUserRole = isClient ? 'freelancer' : 'client';

            final userDoc = await _firestore
                .collection('users')
                .doc(otherUserId)
                .get();

            if (!userDoc.exists) {
              chats.add({
                'chatId': doc.id,
                'otherUserId': otherUserId,
                'otherUserRole': otherUserRole,
                'otherUserName': 'Unknown user',
                'otherUserPhoto': '',
                'lastMessage': data['lastMessage'] ?? '',
                'updatedAt': data['updatedAt'] != null
                    ? (data['updatedAt'] as Timestamp).toDate()
                    : null,
                'unreadCount': isClient
                    ? (data['unreadCountClient'] ?? 0)
                    : (data['unreadCountFreelancer'] ?? 0),
              });
              continue;
            }

            final userData = userDoc.data() ?? {};

            final firstName = (userData['firstName'] ?? '').toString().trim();
            final lastName = (userData['lastName'] ?? '').toString().trim();
            final fullName = '$firstName $lastName'.trim();

            final otherUserName =
                (userData['name'] ?? fullName).toString().trim().isEmpty
                ? 'User'
                : (userData['name'] ?? fullName).toString().trim();

            final otherUserPhoto =
                (userData['photoUrl'] ?? userData['profile'] ?? '').toString();

            chats.add({
              'chatId': doc.id,
              'otherUserId': otherUserId,
              'otherUserRole': otherUserRole,
              'otherUserName': otherUserName,
              'otherUserPhoto': otherUserPhoto,
              'lastMessage': data['lastMessage'] ?? '',
              'updatedAt': data['updatedAt'] != null
                  ? (data['updatedAt'] as Timestamp).toDate()
                  : null,
              'unreadCount': isClient
                  ? (data['unreadCountClient'] ?? 0)
                  : (data['unreadCountFreelancer'] ?? 0),
            });
          }

          final Map<String, Map<String, dynamic>> latestByUser = {};

          for (final chat in chats) {
            final otherUserId = (chat['otherUserId'] ?? '').toString();
            final currentTime = chat['updatedAt'] as DateTime?;

            if (!latestByUser.containsKey(otherUserId)) {
              latestByUser[otherUserId] = chat;
            } else {
              final existingTime =
                  latestByUser[otherUserId]!['updatedAt'] as DateTime?;

              if (existingTime == null ||
                  (currentTime != null && currentTime.isAfter(existingTime))) {
                latestByUser[otherUserId] = chat;
              }
            }
          }

          final uniqueChats = latestByUser.values.toList();

          uniqueChats.sort((a, b) {
            final aTime = a['updatedAt'] as DateTime?;
            final bTime = b['updatedAt'] as DateTime?;

            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;

            return bTime.compareTo(aTime);
          });

          return uniqueChats;
        });
  }
}
