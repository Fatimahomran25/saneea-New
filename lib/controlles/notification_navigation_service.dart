import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/contract_model.dart';
import '../views/admin_contract_review_details_view.dart';
import '../views/admin_general_report_details_view.dart';
import '../views/announcement_requests_view.dart';
import '../views/chat_view.dart';
import '../views/client_home_screen.dart' show AllServiceRequestsView;
import '../views/contract_details_screen.dart';
import '../views/freelancer_incoming_requests_view.dart';
import '../views/my_announcement_requests_view.dart';
import '../views/my_requests_view.dart';
import '../views/warning_notice_view.dart';
import 'request_notifications_controller.dart';

Future<void> handleNotificationTap({
  required BuildContext context,
  required RequestNotificationItem notification,
}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  final type = _clean(notification.type).toLowerCase();
  final requestId = _clean(notification.requestId);
  final proposalId = _clean(notification.proposalId);
  final chatId = _clean(notification.chatId);
  final contractId = _clean(notification.contractId);
  final announcementId = _clean(notification.announcementId);

  try {
    await _markNotificationAsRead(
      firestore: firestore,
      auth: auth,
      notification: notification,
    );

    if (_isChatNotification(type)) {
      final opened = await _tryOpenChat(
        navigator: navigator,
        firestore: firestore,
        auth: auth,
        chatId: chatId,
      );
      if (!opened) {
        await _openSafeFallback(
          navigator: navigator,
          firestore: firestore,
          auth: auth,
          messenger: messenger,
        );
      }
      return;
    }

    if (_isContractNotification(type)) {
      final opened = await _openContract(
        navigator: navigator,
        firestore: firestore,
        auth: auth,
        notification: notification,
      );
      if (!opened) {
        await _openSafeFallback(
          navigator: navigator,
          firestore: firestore,
          auth: auth,
          messenger: messenger,
        );
      }
      return;
    }

    if (type == 'admin_warning') {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => WarningNoticeView(
            title: notification.title,
            message: notification.message,
            warningCount: notification.warningCount,
            maxWarnings: notification.maxWarnings,
          ),
        ),
      );
      return;
    }

    if (type == 'new_general_report') {
      final reportId = _firstFilled([
        notification.relatedReportId,
        notification.requestId,
      ]);

      if (reportId.isNotEmpty) {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => AdminGeneralReportDetailsView(reportId: reportId),
          ),
        );
        return;
      }
    }

    if (type == 'new_contract_report') {
      final reviewId = _clean(notification.reviewId);
      if (reviewId.isNotEmpty) {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => AdminContractReviewDetailsView(reviewId: reviewId),
          ),
        );
        return;
      }
    }

    final currentUser = auth.currentUser;
    if (currentUser == null) {
      await _openSafeFallback(
        navigator: navigator,
        firestore: firestore,
        auth: auth,
        messenger: messenger,
      );
      return;
    }

    final userRole = await _resolveCurrentUserRole(
      firestore: firestore,
      uid: currentUser.uid,
    );

    if (_isProposalNotification(type)) {
      final opened = await _openAnnouncementRequest(
        navigator: navigator,
        firestore: firestore,
        notification: notification,
        userRole: userRole,
      );
      if (!opened) {
        await _openSafeFallback(
          navigator: navigator,
          firestore: firestore,
          auth: auth,
          messenger: messenger,
        );
      }
      return;
    }

    if (type == 'request_accepted') {
      final openedChat = await _tryOpenChat(
        navigator: navigator,
        firestore: firestore,
        auth: auth,
        chatId: chatId,
      );
      if (openedChat) return;

      final opened = _openServiceRequest(
        navigator: navigator,
        notification: notification,
        userRole: userRole,
      );
      if (!opened) {
        await _openSafeFallback(
          navigator: navigator,
          firestore: firestore,
          auth: auth,
          messenger: messenger,
        );
      }
      return;
    }

    if (_isRequestNotification(type)) {
      final opened = _openServiceRequest(
        navigator: navigator,
        notification: notification,
        userRole: userRole,
      );
      if (!opened) {
        await _openSafeFallback(
          navigator: navigator,
          firestore: firestore,
          auth: auth,
          messenger: messenger,
        );
      }
      return;
    }

    if (chatId.isNotEmpty) {
      final opened = await _tryOpenChat(
        navigator: navigator,
        firestore: firestore,
        auth: auth,
        chatId: chatId,
      );
      if (!opened) {
        await _openSafeFallback(
          navigator: navigator,
          firestore: firestore,
          auth: auth,
          messenger: messenger,
        );
      }
      return;
    }

    if (contractId.isNotEmpty) {
      final opened = await _openContract(
        navigator: navigator,
        firestore: firestore,
        auth: auth,
        notification: notification,
      );
      if (!opened) {
        await _openSafeFallback(
          navigator: navigator,
          firestore: firestore,
          auth: auth,
          messenger: messenger,
        );
      }
      return;
    }

    if (proposalId.isNotEmpty || announcementId.isNotEmpty) {
      final opened = await _openAnnouncementRequest(
        navigator: navigator,
        firestore: firestore,
        notification: notification,
        userRole: userRole,
      );
      if (!opened) {
        await _openSafeFallback(
          navigator: navigator,
          firestore: firestore,
          auth: auth,
          messenger: messenger,
        );
      }
      return;
    }

    if (requestId.isNotEmpty) {
      final opened = _openServiceRequest(
        navigator: navigator,
        notification: notification,
        userRole: userRole,
      );
      if (!opened) {
        await _openSafeFallback(
          navigator: navigator,
          firestore: firestore,
          auth: auth,
          messenger: messenger,
        );
      }
      return;
    }

    await _openSafeFallback(
      navigator: navigator,
      firestore: firestore,
      auth: auth,
      messenger: messenger,
    );
  } catch (_) {
    await _openSafeFallback(
      navigator: navigator,
      firestore: firestore,
      auth: auth,
      messenger: messenger,
    );
  }
}

Future<bool> _tryOpenChat({
  required NavigatorState navigator,
  required FirebaseFirestore firestore,
  required FirebaseAuth auth,
  required String chatId,
}) async {
  if (chatId.isEmpty) return false;

  return _openChat(
    navigator: navigator,
    firestore: firestore,
    auth: auth,
    chatId: chatId,
  );
}

Future<bool> _openChat({
  required NavigatorState navigator,
  required FirebaseFirestore firestore,
  required FirebaseAuth auth,
  required String chatId,
}) async {
  final currentUser = auth.currentUser;
  if (currentUser == null) return false;

  final chatDoc = await firestore.collection('chat').doc(chatId).get();
  final chatData = chatDoc.data();
  if (chatData == null) return false;

  final clientId = _clean(chatData['clientId']);
  final freelancerId = _clean(chatData['freelancerId']);

  String otherUserId;
  String otherUserRole;
  if (currentUser.uid == clientId) {
    otherUserId = freelancerId;
    otherUserRole = 'freelancer';
  } else if (currentUser.uid == freelancerId) {
    otherUserId = clientId;
    otherUserRole = 'client';
  } else {
    return false;
  }

  if (otherUserId.isEmpty) return false;

  final otherUserData = await _fetchUserData(firestore, otherUserId);
  final otherUserName = _nameFromUserData(otherUserData);

  navigator.push(
    MaterialPageRoute(
      builder: (_) => ChatView(
        chatId: chatId,
        otherUserName: otherUserName,
        otherUserId: otherUserId,
        otherUserRole: otherUserRole,
      ),
    ),
  );
  return true;
}

Future<bool> _openContract({
  required NavigatorState navigator,
  required FirebaseFirestore firestore,
  required FirebaseAuth auth,
  required RequestNotificationItem notification,
}) async {
  final currentUser = auth.currentUser;
  if (currentUser == null) return false;

  final requestDoc = await _findContractRequest(
    firestore: firestore,
    contractId: _clean(notification.contractId),
    requestId: _clean(notification.requestId),
  );
  if (requestDoc == null) return false;

  final requestData = requestDoc.data;
  if (!GeneratedContract.hasContractData(requestData)) return false;

  final clientId = _clean(requestData['clientId']);
  final freelancerId = _clean(requestData['freelancerId']);
  final userRole = currentUser.uid == clientId
      ? 'client'
      : currentUser.uid == freelancerId
      ? 'freelancer'
      : await _resolveCurrentUserRole(
          firestore: firestore,
          uid: currentUser.uid,
        );

  final otherUserId = userRole == 'client' ? freelancerId : clientId;
  final otherUserData = otherUserId.isEmpty
      ? null
      : await _fetchUserData(firestore, otherUserId);

  final contract = GeneratedContract.fromRequest(
    requestId: requestDoc.id,
    requestData: requestData,
    userRole: userRole,
    otherUserData: otherUserData,
  );

  navigator.push(
    MaterialPageRoute(
      builder: (_) => ContractDetailsScreen(contract: contract),
    ),
  );
  return true;
}

bool _openServiceRequest({
  required NavigatorState navigator,
  required RequestNotificationItem notification,
  required String userRole,
}) {
  final requestId = _clean(notification.requestId);

  if (userRole == 'client') {
    navigator.push(
      MaterialPageRoute(
        builder: (_) => MyRequestsView(
          initialRequestId: requestId.isEmpty ? null : requestId,
        ),
      ),
    );
    return true;
  }

  if (userRole == 'freelancer' && requestId.isNotEmpty) {
    navigator.push(
      MaterialPageRoute(
        builder: (_) =>
            FreelancerIncomingRequestsView(initialRequestId: requestId),
      ),
    );
    return true;
  }

  return false;
}

Future<bool> _openAnnouncementRequest({
  required NavigatorState navigator,
  required FirebaseFirestore firestore,
  required RequestNotificationItem notification,
  required String userRole,
}) async {
  final proposalId = _clean(notification.proposalId);
  final proposal = await _fetchProposalData(
    firestore: firestore,
    proposalId: proposalId,
  );

  if (userRole == 'client') {
    final announcementId = _firstFilled([
      notification.announcementId,
      proposal?['announcementId'],
    ]);

    if (announcementId.isNotEmpty) {
      final description = _firstFilled([
        notification.announcementDescription,
        await _fetchAnnouncementDescription(
          firestore: firestore,
          proposal: proposal,
          announcementId: announcementId,
          clientIdFallback: notification.receiverId,
        ),
      ]);

      navigator.push(
        MaterialPageRoute(
          builder: (_) => AnnouncementRequestsView(
            announcementId: announcementId,
            announcementDescription: description,
          ),
        ),
      );
      return true;
    }

    navigator.push(
      MaterialPageRoute(builder: (_) => const AllServiceRequestsView()),
    );
    return true;
  }

  if (userRole == 'freelancer') {
    navigator.push(
      MaterialPageRoute(
        builder: (_) => MyAnnouncementRequestsView(
          initialProposalId: proposalId.isEmpty ? null : proposalId,
        ),
      ),
    );
    return true;
  }

  return false;
}

Future<void> _openSafeFallback({
  required NavigatorState navigator,
  required FirebaseFirestore firestore,
  required FirebaseAuth auth,
  required ScaffoldMessengerState? messenger,
}) async {
  try {
    _showMissingTarget(messenger);
  } catch (_) {
    // A missing or disposed messenger should not block fallback navigation.
  }

  try {
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      navigator.pushNamed('/login');
      return;
    }

    final userRole = await _resolveCurrentUserRole(
      firestore: firestore,
      uid: currentUser.uid,
    );

    if (userRole == 'client') {
      navigator.pushNamed('/clientHome');
      return;
    }

    if (userRole == 'admin') {
      navigator.pushNamed('/adminHome');
      return;
    }

    if (userRole == 'freelancer') {
      navigator.pushNamed('/freelancerHome');
      return;
    }

    navigator.pushNamed('/intro');
  } catch (_) {
    // Keep notification taps safe even if the fallback route is unavailable.
  }
}

Future<void> _markNotificationAsRead({
  required FirebaseFirestore firestore,
  required FirebaseAuth auth,
  required RequestNotificationItem notification,
}) async {
  final notificationId = _clean(notification.id);
  final receiverId = _firstFilled([
    notification.receiverId,
    auth.currentUser?.uid,
  ]);

  if (notificationId.isEmpty || receiverId.isEmpty) return;

  try {
    await firestore
        .collection('users')
        .doc(receiverId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  } catch (_) {
    // The tap should still navigate even if this notification was removed.
  }
}

Future<_ContractRequestDoc?> _findContractRequest({
  required FirebaseFirestore firestore,
  required String contractId,
  required String requestId,
}) async {
  final candidateIds = <String>[
    contractId,
    requestId,
  ].where((id) => id.isNotEmpty).toSet();

  for (final id in candidateIds) {
    final doc = await firestore.collection('requests').doc(id).get();
    final data = doc.data();
    if (data != null) {
      return _ContractRequestDoc(id: doc.id, data: data);
    }
  }

  if (contractId.isEmpty) return null;

  final requestByContractId = await firestore
      .collection('requests')
      .where('contractId', isEqualTo: contractId)
      .limit(1)
      .get();

  if (requestByContractId.docs.isNotEmpty) {
    final doc = requestByContractId.docs.first;
    return _ContractRequestDoc(id: doc.id, data: doc.data());
  }

  final contractDoc = await firestore
      .collection('contracts')
      .doc(contractId)
      .get();
  final contractData = contractDoc.data();
  final linkedRequestId = _clean(contractData?['requestId']);
  if (linkedRequestId.isEmpty || candidateIds.contains(linkedRequestId)) {
    return null;
  }

  final linkedRequestDoc = await firestore
      .collection('requests')
      .doc(linkedRequestId)
      .get();
  final linkedRequestData = linkedRequestDoc.data();
  if (linkedRequestData == null) return null;

  return _ContractRequestDoc(id: linkedRequestDoc.id, data: linkedRequestData);
}

Future<Map<String, dynamic>?> _fetchProposalData({
  required FirebaseFirestore firestore,
  required String proposalId,
}) async {
  if (proposalId.isEmpty) return null;

  final doc = await firestore
      .collection('announcement_requests')
      .doc(proposalId)
      .get();

  return doc.data();
}

Future<String> _fetchAnnouncementDescription({
  required FirebaseFirestore firestore,
  required Map<String, dynamic>? proposal,
  required String announcementId,
  required String clientIdFallback,
}) async {
  final clientId = _firstFilled([proposal?['clientId'], clientIdFallback]);
  if (clientId.isEmpty || announcementId.isEmpty) return '';

  final doc = await firestore
      .collection('users')
      .doc(clientId)
      .collection('announcements')
      .doc(announcementId)
      .get();

  return _clean(doc.data()?['description']);
}

Future<Map<String, dynamic>?> _fetchUserData(
  FirebaseFirestore firestore,
  String uid,
) async {
  if (uid.isEmpty) return null;

  final doc = await firestore.collection('users').doc(uid).get();
  return doc.data();
}

Future<String> _resolveCurrentUserRole({
  required FirebaseFirestore firestore,
  required String uid,
}) async {
  final userDoc = await firestore.collection('users').doc(uid).get();
  final accountType = _clean(userDoc.data()?['accountType']).toLowerCase();

  if (accountType == 'client' ||
      accountType == 'freelancer' ||
      accountType == 'admin') {
    return accountType;
  }

  return '';
}

String _nameFromUserData(Map<String, dynamic>? userData) {
  final firstName = _clean(userData?['firstName']);
  final lastName = _clean(userData?['lastName']);
  final fullName = '$firstName $lastName'.trim();

  return _firstFilled([userData?['name'], fullName, 'User']);
}

String _firstFilled(List<dynamic> values) {
  for (final value in values) {
    final text = _clean(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _clean(dynamic value) {
  return (value ?? '').toString().trim();
}

bool _isChatNotification(String type) {
  return type == 'chat_message' || type == 'new_message';
}

bool _isContractNotification(String type) {
  return type == 'contract' ||
      type == 'contract_generated' ||
      type == 'contract_approved' ||
      type == 'contract_disapproved' ||
      type == 'contract_termination_requested' ||
      type == 'contract_termination_approved' ||
      type == 'contract_termination_rejected' ||
      type == 'contract_terminated' ||
      type == 'contract_payment_completed';
}

bool _isProposalNotification(String type) {
  return type == 'announcement_request' ||
      type == 'proposal_received' ||
      type == 'proposal_accepted' ||
      type == 'proposal_rejected';
}

bool _isRequestNotification(String type) {
  return type == 'service_request' ||
      type == 'request_accepted' ||
      type == 'request_deleted' ||
      type == 'request_rejected';
}

void _showMissingTarget(ScaffoldMessengerState? messenger) {
  messenger?.showSnackBar(
    const SnackBar(
      content: Text('Notification target is no longer available.'),
    ),
  );
}

class _ContractRequestDoc {
  final String id;
  final Map<String, dynamic> data;

  const _ContractRequestDoc({required this.id, required this.data});
}
