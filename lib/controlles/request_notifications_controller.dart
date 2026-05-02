import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RequestNotificationItem {
  final String id;
  final String type;
  final String senderId;
  final String senderName;
  final String senderProfileUrl;
  final String actionText;
  final String snippet;
  final String receiverId;
  final String? requestId;
  final String? proposalId;
  final String? contractId;
  final String? chatId;
  final String? announcementId;
  final String? announcementDescription;
  final bool isRead;
  final DateTime? createdAt;

  const RequestNotificationItem({
    required this.id,
    required this.type,
    required this.senderId,
    required this.senderName,
    required this.senderProfileUrl,
    required this.actionText,
    required this.snippet,
    required this.receiverId,
    required this.requestId,
    required this.proposalId,
    required this.contractId,
    required this.chatId,
    required this.announcementId,
    required this.announcementDescription,
    required this.isRead,
    required this.createdAt,
  });

  factory RequestNotificationItem.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final type = _clean(data['type']);
    final actionText = _actionTextForType(
      type: type,
      rawActionText: data['actionText'],
    );
    final snippet = _snippetForType(
      type: type,
      rawSnippet: data['snippet'],
    );

    return RequestNotificationItem(
      id: doc.id,
      type: type,
      senderId: _clean(data['senderId']),
      senderName: _clean(data['senderName']),
      senderProfileUrl: _clean(data['senderProfileUrl']),
      actionText: actionText,
      snippet: snippet,
      receiverId: _clean(data['receiverId']),
      requestId: data['requestId']?.toString(),
      proposalId: data['proposalId']?.toString(),
      contractId: data['contractId']?.toString(),
      chatId: data['chatId']?.toString(),
      announcementId: data['announcementId']?.toString(),
      announcementDescription: data['announcementDescription']?.toString(),
      isRead: data['isRead'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static String _clean(dynamic value) {
    return (value ?? '').toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _actionTextForType({
    required String type,
    required dynamic rawActionText,
  }) {
    final actionText = _clean(rawActionText);
    if (actionText.isNotEmpty) return actionText;

    switch (type) {
      case 'contract_generated':
        return 'generated a contract draft';
      case 'contract_approved':
        return 'approved your contract';
      case 'contract_disapproved':
        return 'rejected your contract';
      case 'contract_termination_requested':
        return 'requested to terminate the contract';
      case 'contract_termination_approved':
        return 'approved your termination request';
      case 'contract_termination_rejected':
        return 'rejected your termination request';
      case 'contract_payment_completed':
        return 'completed the contract payment';
      default:
        return '';
    }
  }

  static String _snippetForType({
    required String type,
    required dynamic rawSnippet,
  }) {
    final snippet = _clean(rawSnippet);
    if (snippet.isNotEmpty) return snippet;

    switch (type) {
      case 'contract_generated':
      case 'contract_approved':
      case 'contract_disapproved':
      case 'contract_termination_requested':
      case 'contract_termination_approved':
      case 'contract_termination_rejected':
      case 'contract_payment_completed':
        return 'Contract Agreement';
      default:
        return '';
    }
  }
}

class RequestNotificationsController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> notificationsStream() {
    final uid = currentUserId;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<int> unreadCountStream() {
    return notificationsStream().map((snapshot) {
      var count = 0;
      for (final doc in snapshot.docs) {
        if (doc.data()['isRead'] != true) {
          count++;
        }
      }
      return count;
    });
  }

  Future<void> markAsRead(String notificationId) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .set({'isRead': true}, SetOptions(merge: true));
  }

  Future<void> markAllAsRead() async {
    final uid = currentUserId;
    if (uid == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.set(doc.reference, {'isRead': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';

    final d = dateTime.day.toString().padLeft(2, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    final y = dateTime.year;
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }
}
