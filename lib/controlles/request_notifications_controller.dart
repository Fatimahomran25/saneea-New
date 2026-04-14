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
    required this.announcementId,
    required this.announcementDescription,
    required this.isRead,
    required this.createdAt,
  });

  factory RequestNotificationItem.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return RequestNotificationItem(
      id: doc.id,
      type: (data['type'] ?? '').toString(),
      senderId: (data['senderId'] ?? '').toString(),
      senderName: (data['senderName'] ?? '').toString(),
      senderProfileUrl: (data['senderProfileUrl'] ?? '').toString(),
      actionText: (data['actionText'] ?? '').toString(),
      snippet: (data['snippet'] ?? '').toString(),
      receiverId: (data['receiverId'] ?? '').toString(),
      requestId: data['requestId']?.toString(),
      announcementId: data['announcementId']?.toString(),
      announcementDescription: data['announcementDescription']?.toString(),
      isRead: data['isRead'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
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
