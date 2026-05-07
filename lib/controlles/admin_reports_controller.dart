import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'app_notification_service.dart';

class AdminReportsController {
  AdminReportsController({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _notificationService = AppNotificationService(
        firestore: firestore ?? FirebaseFirestore.instance,
      );

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AppNotificationService _notificationService;

  Future<void> dismissGeneralReport({required String reportId}) async {
    await _firestore.collection('general_reports').doc(reportId).set({
      'status': 'dismissed',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> reopenGeneralReport({required String reportId}) async {
    await _firestore.collection('general_reports').doc(reportId).set({
      'status': 'open',
      'handledAt': FieldValue.delete(),
      'handledBy': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markGeneralReportValid({
    required String reportId,
    required String reportedUserId,
    required String warningReason,
  }) async {
    final trimmedReportedUserId = reportedUserId.trim();
    if (trimmedReportedUserId.isEmpty) {
      throw Exception('Reported user ID is missing.');
    }

    final reportRef = _firestore.collection('general_reports').doc(reportId);
    final userRef = _firestore.collection('users').doc(trimmedReportedUserId);

    final warningOutcome = await _firestore
        .runTransaction<Map<String, dynamic>>((transaction) async {
          final reportSnapshot = await transaction.get(reportRef);
          final reportData = reportSnapshot.data();

          if (!reportSnapshot.exists || reportData == null) {
            throw Exception('Report not found.');
          }

          final userSnapshot = await transaction.get(userRef);
          final userData = userSnapshot.data() ?? <String, dynamic>{};
          final currentWarningCount = _intValue(userData['warningCount']);
          final warningAlreadyApplied = reportData['warningApplied'] == true;
          final nextWarningCount = warningAlreadyApplied
              ? currentWarningCount
              : currentWarningCount + 1;

          if (!warningAlreadyApplied) {
            transaction.set(userRef, {
              'warningCount': nextWarningCount,
              'lastWarningAt': FieldValue.serverTimestamp(),
              'lastWarningReason': warningReason.trim().isEmpty
                  ? 'General report violation'
                  : warningReason.trim(),
              'lastWarningReportId': reportId,
            }, SetOptions(merge: true));
          }

          transaction.set(reportRef, {
            'status': 'valid',
            'warningApplied': true,
            'warningReason': warningReason.trim(),
            'warningIssuedAt': FieldValue.serverTimestamp(),
            'warningCountAfterAction': nextWarningCount,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          return {
            'didApplyWarning': !warningAlreadyApplied,
            'warningCount': nextWarningCount,
          };
        });

    final didApplyWarning = warningOutcome['didApplyWarning'] == true;
    final nextWarningCount = _intValue(warningOutcome['warningCount']);

    if (!didApplyWarning) return;

    try {
      await _notificationService.createAdminWarningNotification(
        targetUserId: trimmedReportedUserId,
        reportId: reportId,
        warningCount: nextWarningCount,
      );
    } catch (error) {
      debugPrint('Create admin warning notification error: $error');
    }
  }

  Future<void> blockReportedUser({
    required String reportedUserId,
    required String blockedReason,
  }) async {
    final trimmedReportedUserId = reportedUserId.trim();
    if (trimmedReportedUserId.isEmpty) {
      throw Exception('Reported user ID is missing.');
    }

    await _firestore.collection('users').doc(trimmedReportedUserId).set({
      'isBlocked': true,
      'blockedAt': FieldValue.serverTimestamp(),
      'blockedReason': blockedReason.trim().isEmpty
          ? 'Repeated violations'
          : blockedReason.trim(),
    }, SetOptions(merge: true));
  }

  Future<void> unblockReportedUser({required String reportedUserId}) async {
    final trimmedReportedUserId = reportedUserId.trim();
    if (trimmedReportedUserId.isEmpty) {
      throw Exception('Reported user ID is missing.');
    }

    await _firestore.collection('users').doc(trimmedReportedUserId).set({
      'isBlocked': false,
      'unblockedAt': FieldValue.serverTimestamp(),
      'blockedAt': FieldValue.delete(),
      'blockedReason': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  Future<void> adminTerminateContractReview({
    required String reviewId,
    String adminDecisionNote = '',
  }) async {
    final adminUid = (_auth.currentUser?.uid ?? '').trim();
    if (adminUid.isEmpty) {
      throw Exception('Admin user is not available.');
    }

    final reviewRef = _firestore.collection('contract_reports').doc(reviewId);
    final reviewSnapshot = await reviewRef.get();
    final reviewData = reviewSnapshot.data();

    if (!reviewSnapshot.exists || reviewData == null) {
      throw Exception('Contract review not found.');
    }

    final requestRef = await _findRelatedRequestRef(
      requestId: (reviewData['requestId'] ?? '').toString().trim(),
      contractId: (reviewData['contractId'] ?? '').toString().trim(),
    );

    await _firestore.runTransaction((transaction) async {
      if (requestRef != null) {
        final requestSnapshot = await transaction.get(requestRef);
        final requestData = requestSnapshot.data() ?? <String, dynamic>{};
        final contractData = _asMap(requestData['contractData']);
        final approval = _asMap(contractData['approval']);

        approval['contractStatus'] = 'admin_terminated';
        contractData['approval'] = approval;
        contractData['contractStatus'] = 'admin_terminated';
        contractData['adminDecision'] = 'admin_terminated';
        contractData['adminDecisionNote'] = adminDecisionNote.trim();
        contractData['adminTerminatedAt'] = FieldValue.serverTimestamp();
        contractData['adminTerminatedBy'] = adminUid;

        transaction.set(requestRef, {
          'contractData': contractData,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      transaction.set(reviewRef, {
        'status': 'resolved',
        'contractStatus': 'admin_terminated',
        'adminDecision': 'admin_terminated',
        'adminDecisionNote': adminDecisionNote.trim(),
        'adminTerminatedAt': FieldValue.serverTimestamp(),
        'adminTerminatedBy': adminUid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<DocumentReference<Map<String, dynamic>>?> _findRelatedRequestRef({
    required String requestId,
    required String contractId,
  }) async {
    if (requestId.isNotEmpty) {
      final requestRef = _firestore.collection('requests').doc(requestId);
      final requestDoc = await requestRef.get();
      if (requestDoc.exists) {
        return requestRef;
      }
    }

    if (contractId.isEmpty) return null;

    final queryFields = [
      'contractId',
      'contractData.contractId',
      'contractData.meta.contractId',
    ];

    for (final field in queryFields) {
      final snapshot = await _firestore
          .collection('requests')
          .where(field, isEqualTo: contractId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.reference;
      }
    }

    return null;
  }
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString().trim()) ?? 0;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}
