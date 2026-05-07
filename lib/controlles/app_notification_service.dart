import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationService {
  AppNotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int maxWarnings = 3;

  Future<void> createAdminWarningNotification({
    required String targetUserId,
    required String reportId,
    required int warningCount,
  }) async {
    final trimmedTargetUserId = targetUserId.trim();
    final trimmedReportId = reportId.trim();
    if (trimmedTargetUserId.isEmpty || trimmedReportId.isEmpty) return;

    final title = 'Admin Warning';
    final message = warningCount >= maxWarnings
        ? 'You have reached 3 warnings. Your account may be blocked by the admin.'
        : 'You received a warning from the admin. Warning count: $warningCount/$maxWarnings. After the third warning, your account may be blocked.';

    await _createUserNotification(
      receiverId: trimmedTargetUserId,
      documentId: 'admin_warning_$trimmedReportId',
      payload: {
        'type': 'admin_warning',
        'senderId': 'admin',
        'senderName': 'Admin',
        'senderProfileUrl': '',
        'receiverId': trimmedTargetUserId,
        'title': title,
        'message': message,
        'actionText': message,
        'snippet': 'Tap to review your warning details.',
        'warningCount': warningCount,
        'maxWarnings': maxWarnings,
        'relatedReportId': trimmedReportId,
        'reportId': trimmedReportId,
        'targetUserId': trimmedTargetUserId,
      },
    );
  }

  Future<void> createAdminGeneralReportNotification({
    required String reportId,
    required String reporterId,
    required String reporterName,
    required String reportedUserName,
    required String reasonText,
  }) async {
    final trimmedReportId = reportId.trim();
    if (trimmedReportId.isEmpty) return;

    final safeReporterName = reporterName.trim().isEmpty
        ? 'A user'
        : reporterName.trim();
    final safeReportedUserName = reportedUserName.trim().isEmpty
        ? 'another user'
        : reportedUserName.trim();
    final safeReasonText = reasonText.trim().isEmpty
        ? 'an issue'
        : reasonText.trim();

    final message =
        '$safeReporterName reported $safeReportedUserName for $safeReasonText.';

    await _createNotificationForAdmins(
      documentId: 'new_general_report_$trimmedReportId',
      payload: {
        'type': 'new_general_report',
        'senderId': reporterId.trim(),
        'senderName': safeReporterName,
        'senderProfileUrl': '',
        'title': 'New Report Received',
        'message': message,
        'actionText': message,
        'snippet': 'Open to review the report details.',
        'relatedReportId': trimmedReportId,
        'reportId': trimmedReportId,
      },
    );
  }

  Future<void> createAdminContractReportNotification({
    required String reviewId,
  }) async {
    final trimmedReviewId = reviewId.trim();
    if (trimmedReviewId.isEmpty) return;

    const message = 'A new contract review request needs admin attention.';

    await _createNotificationForAdmins(
      documentId: 'new_contract_report_$trimmedReviewId',
      payload: {
        'type': 'new_contract_report',
        'senderId': 'system',
        'senderName': 'System',
        'senderProfileUrl': '',
        'title': 'New Contract Review Request',
        'message': message,
        'actionText': message,
        'snippet': 'Open to review the contract issue.',
        'reviewId': trimmedReviewId,
      },
    );
  }

  Future<void> createBlockedUserAppealNotification({
    required String appealId,
    required String userId,
    required String userName,
  }) async {
    final trimmedAppealId = appealId.trim();
    final trimmedUserId = userId.trim();
    if (trimmedAppealId.isEmpty || trimmedUserId.isEmpty) return;

    final safeUserName = userName.trim().isEmpty
        ? 'A blocked user'
        : userName.trim();
    final message =
        '$safeUserName submitted a request to review their blocked account.';

    await _createNotificationForAdmins(
      documentId: 'blocked_user_appeal_$trimmedAppealId',
      payload: {
        'type': 'blocked_user_appeal',
        'senderId': trimmedUserId,
        'senderName': safeUserName,
        'senderProfileUrl': '',
        'title': 'Blocked User Review Request',
        'message': message,
        'actionText': message,
        'snippet': 'Open to review the blocked account appeal.',
        'appealId': trimmedAppealId,
        'userId': trimmedUserId,
        'targetRole': 'admin',
      },
    );
  }

  Future<void> createBlockedUserAppealDecisionNotification({
    required String appealId,
    required String userId,
    required bool approved,
  }) async {
    final trimmedAppealId = appealId.trim();
    final trimmedUserId = userId.trim();
    if (trimmedAppealId.isEmpty || trimmedUserId.isEmpty) return;

    final type = approved ? 'appeal_approved' : 'appeal_rejected';
    final title = approved
        ? 'Account Restriction Lifted'
        : 'Review Request Rejected';
    final message = approved
        ? 'Your review request was approved. You can use your account again.'
        : 'Your account restriction remains active after admin review.';

    await _createUserNotification(
      receiverId: trimmedUserId,
      documentId: '${type}_$trimmedAppealId',
      payload: {
        'type': type,
        'senderId': 'admin',
        'senderName': 'Admin',
        'senderProfileUrl': '',
        'title': title,
        'message': message,
        'actionText': message,
        'snippet': message,
        'appealId': trimmedAppealId,
        'userId': trimmedUserId,
      },
    );
  }

  Future<void> _createNotificationForAdmins({
    required String documentId,
    required Map<String, dynamic> payload,
  }) async {
    final adminSnapshot = await _firestore
        .collection('users')
        .where('accountType', isEqualTo: 'admin')
        .get();

    if (adminSnapshot.docs.isEmpty) return;

    for (final adminDoc in adminSnapshot.docs) {
      final adminId = adminDoc.id.trim();
      if (adminId.isEmpty) continue;

      await _createUserNotification(
        receiverId: adminId,
        documentId: documentId,
        payload: {
          ...payload,
          'receiverId': adminId,
        },
      );
    }
  }

  Future<void> _createUserNotification({
    required String receiverId,
    required String documentId,
    required Map<String, dynamic> payload,
  }) async {
    final trimmedReceiverId = receiverId.trim();
    final trimmedDocumentId = documentId.trim();
    if (trimmedReceiverId.isEmpty || trimmedDocumentId.isEmpty) return;

    final notificationRef = _firestore
        .collection('users')
        .doc(trimmedReceiverId)
        .collection('notifications')
        .doc(trimmedDocumentId);

    await _createIfMissing(notificationRef, {
      ...payload,
      'receiverId': trimmedReceiverId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _createIfMissing(
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic> data,
  ) async {
    final snapshot = await reference.get();
    if (snapshot.exists) return;
    await reference.set(data);
  }
}
