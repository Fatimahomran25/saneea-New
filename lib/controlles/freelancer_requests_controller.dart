import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_controller.dart';

class FreelancerRequestsController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _singleLineSnippet(String rawText) {
    final text = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '';
    return text;
  }

  String _displayName(Map<String, dynamic> data, String fallback) {
    final firstName = (data['firstName'] ?? '').toString().trim();
    final lastName = (data['lastName'] ?? '').toString().trim();
    final fullName = '$firstName $lastName'.trim();
    final name = (data['name'] ?? '').toString().trim();

    if (fullName.isNotEmpty) return fullName;
    if (name.isNotEmpty) return name;
    return fallback;
  }

  Future<void> _createRequestNotification({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String senderProfileUrl,
    required String actionText,
    required String type,
    required String snippet,
    String? requestId,
    String? chatId,
  }) async {
    await _firestore
        .collection('users')
        .doc(receiverId)
        .collection('notifications')
        .add({
          'type': type,
          'senderId': senderId,
          'senderName': senderName,
          'senderProfileUrl': senderProfileUrl,
          'receiverId': receiverId,
          'actionText': actionText,
          'snippet': snippet,
          'requestId': requestId,
          'chatId': chatId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getIncomingRequests() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No logged in freelancer found.');
    }

    final snapshot = await _firestore
        .collection('requests')
        .where('freelancerId', isEqualTo: user.uid)
        .where('status', whereIn: ['pending', 'accepted'])
        .get();

    return snapshot.docs;
  }

  Future<void> acceptRequest(String requestId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No logged in freelancer found.');
    }

    final requestRef = _firestore.collection('requests').doc(requestId);
    final requestDoc = await requestRef.get();
    final data = requestDoc.data();

    if (data == null) {
      throw Exception('Request not found.');
    }

    final clientId = (data['clientId'] ?? '').toString();
    final freelancerId = (data['freelancerId'] ?? '').toString();

    if (clientId.isEmpty || freelancerId.isEmpty) {
      throw Exception('Request is missing participant data.');
    }

    if (freelancerId != user.uid) {
      throw Exception('This request does not belong to this freelancer.');
    }

    final chatId = await ChatController().createOrGetChat(
      requestId: requestId,
      clientId: clientId,
      freelancerId: freelancerId,
    );
    final previousStatus = (data['status'] ?? '').toString().toLowerCase();

    await requestRef.set({
      'status': 'accepted',
      'chatId': chatId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (previousStatus != 'accepted') {
      final freelancerDoc = await _firestore
          .collection('users')
          .doc(freelancerId)
          .get();
      final freelancerData = freelancerDoc.data() ?? <String, dynamic>{};
      final senderName = _displayName(
        freelancerData,
        (data['freelancerName'] ?? 'Freelancer').toString(),
      );
      final senderProfileUrl =
          (freelancerData['profile'] ?? freelancerData['photoUrl'] ?? '')
              .toString();

      await _createRequestNotification(
        receiverId: clientId,
        senderId: freelancerId,
        senderName: senderName,
        senderProfileUrl: senderProfileUrl,
        actionText: 'accepted your service request',
        type: 'request_accepted',
        snippet: _singleLineSnippet((data['description'] ?? '').toString()),
        requestId: requestId,
        chatId: chatId,
      );
    }
  }

  Future<void> rejectRequest(String requestId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No logged in freelancer found.');
    }

    final requestRef = _firestore.collection('requests').doc(requestId);
    final requestDoc = await requestRef.get();
    final data = requestDoc.data();

    if (data == null) {
      throw Exception('Request not found.');
    }

    final clientId = (data['clientId'] ?? '').toString();
    final freelancerId = (data['freelancerId'] ?? '').toString();

    if (clientId.isEmpty || freelancerId.isEmpty) {
      throw Exception('Request is missing participant data.');
    }

    if (freelancerId != user.uid) {
      throw Exception('This request does not belong to this freelancer.');
    }

    final previousStatus = (data['status'] ?? '').toString().toLowerCase();

    await requestRef.set({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (previousStatus != 'rejected') {
      final freelancerDoc = await _firestore
          .collection('users')
          .doc(freelancerId)
          .get();
      final freelancerData = freelancerDoc.data() ?? <String, dynamic>{};

      final senderName = _displayName(
        freelancerData,
        (data['freelancerName'] ?? 'Freelancer').toString(),
      );

      final senderProfileUrl =
          (freelancerData['profile'] ?? freelancerData['photoUrl'] ?? '')
              .toString();

      await _createRequestNotification(
        receiverId: clientId,
        senderId: freelancerId,
        senderName: senderName,
        senderProfileUrl: senderProfileUrl,
        actionText: 'rejected your service request',
        type: 'request_rejected',
        snippet: _singleLineSnippet((data['description'] ?? '').toString()),
        requestId: requestId,
      );
    }
  }
}
