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

  Future<String?> getExistingChatIdForRequest(String requestId) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) return null;

    final directChatDoc = await _firestore
        .collection(_chatCollection)
        .doc(normalizedRequestId)
        .get();

    if (directChatDoc.exists) {
      return directChatDoc.id;
    }

    final chatByRequest = await _firestore
        .collection(_chatCollection)
        .where('requestId', isEqualTo: normalizedRequestId)
        .limit(1)
        .get();

    if (chatByRequest.docs.isEmpty) return null;
    return chatByRequest.docs.first.id;
  }

  Stream<String?> watchChatIdForRequest(String requestId) {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) {
      return Stream.value(null);
    }

    return _firestore
        .collection('requests')
        .doc(normalizedRequestId)
        .snapshots()
        .asyncMap((requestDoc) async {
          final requestData = requestDoc.data() ?? {};
          final storedChatId = (requestData['chatId'] ?? '').toString().trim();

          if (storedChatId.isNotEmpty) {
            return storedChatId;
          }

          return await getExistingChatIdForRequest(normalizedRequestId);
        });
  }

  Future<String> createChatForRequest({
    required String requestId,
    required String clientId,
    required String freelancerId,
  }) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) {
      throw Exception('requestId is required to create chat.');
    }

    final existingChatId = await getExistingChatIdForRequest(
      normalizedRequestId,
    );
    if (existingChatId != null && existingChatId.isNotEmpty) {
      await _firestore.collection('requests').doc(normalizedRequestId).set({
        'chatId': existingChatId,
      }, SetOptions(merge: true));
      return existingChatId;
    }

    final chatRef = _firestore
        .collection(_chatCollection)
        .doc(normalizedRequestId);
    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      await chatRef.set({
        'clientId': clientId,
        'freelancerId': freelancerId,
        'requestId': normalizedRequestId,
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCountClient': 0,
        'unreadCountFreelancer': 0,
      });
    }

    await _firestore.collection('requests').doc(normalizedRequestId).set({
      'chatId': chatRef.id,
    }, SetOptions(merge: true));

    return chatRef.id;
  }

  Future<String> createOrGetChat({
    required String requestId,
    required String clientId,
    required String freelancerId,
  }) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) {
      throw Exception('requestId is required to open chat.');
    }

    final existingChatId = await getExistingChatIdForRequest(
      normalizedRequestId,
    );
    if (existingChatId != null) return existingChatId;

    final chatRef = _firestore
        .collection(_chatCollection)
        .doc(normalizedRequestId);
    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      await chatRef.set({
        'clientId': clientId,
        'freelancerId': freelancerId,
        'requestId': normalizedRequestId,
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCountClient': 0,
        'unreadCountFreelancer': 0,
      });
    }

    await _firestore.collection('requests').doc(normalizedRequestId).set({
      'chatId': chatRef.id,
    }, SetOptions(merge: true));

    return chatRef.id;
  }

  int _safeUnreadCount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    final text = value?.toString().trim() ?? '';
    return int.tryParse(text) ?? 0;
  }

  Future<String> createOrGetAnnouncementProposalChat({
    required String announcementId,
    required String proposalId,
    required String clientId,
    required String freelancerId,
    String? initialChatId,
  }) async {
    final normalizedAnnouncementId = announcementId.trim();
    final normalizedProposalId = proposalId.trim();
    final normalizedInitialChatId = (initialChatId ?? '').trim();

    if (normalizedAnnouncementId.isEmpty) {
      throw Exception(
        'announcementId is required to open announcement proposal chat.',
      );
    }

    if (normalizedProposalId.isEmpty) {
      throw Exception(
        'proposalId is required to open announcement proposal chat.',
      );
    }

    final proposalRef = _firestore
        .collection('announcement_requests')
        .doc(normalizedProposalId);
    final proposalDoc = await proposalRef.get();
    final proposalData = proposalDoc.data() ?? <String, dynamic>{};
    final storedChatId = (proposalData['chatId'] ?? '').toString().trim();

    final chatId = normalizedInitialChatId.isNotEmpty
        ? normalizedInitialChatId
        : storedChatId.isNotEmpty
        ? storedChatId
        : normalizedProposalId;

    final chatRef = _firestore.collection(_chatCollection).doc(chatId);
    final chatDoc = await chatRef.get();
    final chatData = chatDoc.data() ?? <String, dynamic>{};

    await chatRef.set({
      'clientId': clientId,
      'freelancerId': freelancerId,
      'requestId': normalizedAnnouncementId,
      'announcementId': normalizedAnnouncementId,
      'proposalId': normalizedProposalId,
      'lastMessage': (chatData['lastMessage'] ?? '').toString(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCountClient': _safeUnreadCount(chatData['unreadCountClient']),
      'unreadCountFreelancer': _safeUnreadCount(
        chatData['unreadCountFreelancer'],
      ),
    }, SetOptions(merge: true));

    await proposalRef.set({
      'chatId': chatRef.id,
      'announcementId': normalizedAnnouncementId,
      'proposalId': normalizedProposalId,
    }, SetOptions(merge: true));

    return chatRef.id;
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

  Future<List<Map<String, String>>> uploadDeliveryImages({
    required String chatId,
    required List<File> imageFiles,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No logged in user found.');
    }

    final List<Map<String, String>> imageItems = [];

    for (final imageFile in imageFiles) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${imageItems.length}';
      final previewRef = _storage
        .ref()
        .child('delivery_previews')
        .child(chatId)
        .child('$fileName.jpg');
      final storageRef = _storage
          .ref()
          .child('delivery_files')
          .child(chatId)
          .child('$fileName.jpg');

      await previewRef.putFile(imageFile);
      await storageRef.putFile(imageFile);
      final previewUrl = await previewRef.getDownloadURL();

      imageItems.add({
        'fileName': '$fileName.jpg',
        'previewUrl': previewUrl,
        'storagePath': storageRef.fullPath,
      });
    }

    return imageItems;
  }

  Future<Map<String, String>> uploadDeliveryFile({
    required String chatId,
    required File file,
    required String fileName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No logged in user found.');
    }

    final normalizedName = fileName.trim().isEmpty
        ? 'attachment'
        : fileName.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final storageRef = _storage
        .ref()
        .child('delivery_files')
        .child(chatId)
        .child('${DateTime.now().millisecondsSinceEpoch}_$normalizedName');

    await storageRef.putFile(file);
    return {'name': normalizedName, 'storagePath': storageRef.fullPath};
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

    final unreadMessages = await chatRef
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in unreadMessages.docs) {
      final data = doc.data();
      final senderId = (data['senderId'] ?? '').toString();

      if (senderId != user.uid) {
        await doc.reference.update({'isRead': true});
      }
    }

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

            final isClientUser = user.uid == clientId;
            final isFreelancerUser = user.uid == freelancerId;

            String otherUserId;
            String otherUserRole;

            if (isClientUser) {
              otherUserId = freelancerId;
              otherUserRole = 'freelancer';
            } else if (isFreelancerUser) {
              otherUserId = clientId;
              otherUserRole = 'client';
            } else {
              otherUserId = freelancerId.isNotEmpty ? freelancerId : clientId;
              otherUserRole = 'unknown';
            }

            final chatPreviewText = _chatPreviewText(data);

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
                'lastMessage': chatPreviewText,
                'updatedAt': data['updatedAt'] != null
                    ? (data['updatedAt'] as Timestamp).toDate()
                    : null,
                'unreadCount': isClientUser
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
              'lastMessage': chatPreviewText,
              'updatedAt': data['updatedAt'] != null
                  ? (data['updatedAt'] as Timestamp).toDate()
                  : null,
              'unreadCount': isClientUser
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

  Map<String, dynamic> _asMap(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  String _chatPreviewText(Map<String, dynamic> chatData) {
    final contractData = _asMap(chatData['contractData']);
    if (contractData.isNotEmpty) {
      final approval = _asMap(contractData['approval']);
      final deliveryData = _asMap(contractData['deliveryData']);
      final paymentData = _asMap(contractData['paymentData']);
      final contractStatus = (approval['contractStatus'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final deliveryStatus = (deliveryData['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final paymentStatus = (paymentData['paymentStatus'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (contractStatus == 'completed' ||
          deliveryStatus == 'paid_delivered' ||
          paymentStatus == 'paid' ||
          paymentStatus == 'completed') {
        return 'Completed Contract';
      }

      if (contractStatus == 'termination_pending') {
        return 'Termination Pending';
      }

      if (contractStatus == 'terminated') {
        return 'Terminated Contract';
      }

      if (deliveryStatus == 'approved_awaiting_payment') {
        return 'Awaiting Payment';
      }

      if (deliveryStatus == 'submitted') {
        return 'Work Submitted';
      }

      if (deliveryStatus == 'changes_requested') {
        return 'Changes Requested';
      }

      if (contractStatus == 'approved') {
        return 'Approved Contract';
      }
    }

    return (chatData['lastMessage'] ?? '').toString();
  }
}
