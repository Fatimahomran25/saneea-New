import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color kReportFlagColor = Color(0xFFC75A5A);

const List<Map<String, String>> kReportReasonOptions = [
  {'value': 'spam', 'label': 'Spam'},
  {'value': 'inappropriate_content', 'label': 'Inappropriate content'},
  {'value': 'abuse_or_manipulation', 'label': 'Abuse or manipulation'},
  {'value': 'general_issue', 'label': 'General issue'},
];

String reportReasonLabel(String reasonType) {
  switch (reasonType.trim().toLowerCase()) {
    case 'no_response':
      return 'No response';
    case 'delivery_dispute':
      return 'Delivery dispute';
    case 'inappropriate_content':
      return 'Inappropriate content';
    case 'abuse_or_manipulation':
      return 'Abuse or manipulation';
    case 'general_issue':
    default:
      return 'General issue';
  }
}

class ReportFlagButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  final String tooltip;

  const ReportFlagButton({
    super.key,
    required this.onPressed,
    this.padding = const EdgeInsets.only(right: 8),
    this.tooltip = 'Report Issue',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: const Icon(
            Icons.outlined_flag,
            color: kReportFlagColor,
            size: 24,
          ),
        ),
      ),
    );
  }
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

Future<void> showReportIssueDialog({
  required BuildContext context,
  required String source,
  required String reportedUserId,
  required String reportedUserName,
  String? reportedUserRole,
  String? chatId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final reporter = FirebaseAuth.instance.currentUser;

  if (reporter == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('You need to be signed in to report')),
    );
    return;
  }

  final normalizedReportedUserId = reportedUserId.trim();
  if (normalizedReportedUserId.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('User information is not available')),
    );
    return;
  }

  if (normalizedReportedUserId == reporter.uid) {
    messenger.showSnackBar(
      const SnackBar(content: Text('You cannot report your own account')),
    );
    return;
  }

  final selectedReason = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Report Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose the reason for this report.'),
            const SizedBox(height: 12),
            ...kReportReasonOptions.map((option) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(option['value']),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5A3E9E),
                      side: const BorderSide(color: Color(0x335A3E9E)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      alignment: Alignment.centerLeft,
                    ),
                    child: Text(
                      option['label']!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );

  if (selectedReason == null || selectedReason.trim().isEmpty) {
    return;
  }

  final reasonText = reportReasonLabel(selectedReason);

  try {
    final reporterDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(reporter.uid)
        .get();
    final reporterData = reporterDoc.data() ?? <String, dynamic>{};

    final reporterName = _displayName(reporterData, 'User');

    await FirebaseFirestore.instance.collection('general_reports').add({
      'source': source.trim(),
      'chatId': (chatId ?? '').trim(),
      'reportedUserId': normalizedReportedUserId,
      'targetUserId': normalizedReportedUserId,
      'reportedUserName': reportedUserName.trim(),
      'reportedUserRole': (reportedUserRole ?? '').toString().trim(),
      'reporterId': reporter.uid,
      'reporterName': reporterName,
      'reporterUserId': reporter.uid,
      'reporterUserName': reporterName,
      'reporterUserRole': (reporterData['accountType'] ?? '').toString().trim(),
      'reason': reasonText,
      'reasonType': selectedReason,
      'reasonText': reasonText,
      'details': '',
      'status': 'submitted',
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'general_report',
    });

    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Report submitted successfully')),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Failed to submit report: $e')),
    );
  }
}
