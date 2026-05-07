import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controlles/app_notification_service.dart';

const Color kReportFlagColor = Color(0xFFC75A5A);
const Color kReportPrimaryColor = Color(0xFF5A3E9E);
const Color kReportSoftSurface = Color(0xFFF6F2FB);

const List<Map<String, String>> kReportReasonOptions = [
  {
    'value': 'harassment_or_abusive_behavior',
    'label': 'Harassment or abusive behavior',
  },
  {'value': 'inappropriate_content', 'label': 'Inappropriate content'},
  {'value': 'spam_or_scam', 'label': 'Spam or scam'},
  {'value': 'general_issue', 'label': 'General issue'},
];

String reportReasonLabel(String reasonType) {
  switch (reasonType.trim().toLowerCase()) {
    case 'harassment_or_abusive_behavior':
    case 'abuse_or_manipulation':
      return 'Harassment or abusive behavior';
    case 'inappropriate_content':
      return 'Inappropriate content';
    case 'spam_or_scam':
    case 'spam':
      return 'Spam or scam';
    case 'general_issue':
    default:
      return 'General issue';
  }
}

IconData _reportReasonIcon(String value) {
  switch (value.trim().toLowerCase()) {
    case 'harassment_or_abusive_behavior':
      return Icons.gpp_bad_rounded;
    case 'inappropriate_content':
      return Icons.block_rounded;
    case 'spam_or_scam':
      return Icons.report_gmailerrorred_rounded;
    case 'general_issue':
    default:
      return Icons.edit_note_rounded;
  }
}

String _reportReasonSubtitle(String value) {
  switch (value.trim().toLowerCase()) {
    case 'harassment_or_abusive_behavior':
      return 'Abuse, harassment, or harmful behavior';
    case 'inappropriate_content':
      return 'Content that violates app standards';
    case 'spam_or_scam':
      return 'Spam, fraud, or suspicious behavior';
    case 'general_issue':
    default:
      return 'Describe another issue briefly';
  }
}

class _ReportIssueDialogResult {
  const _ReportIssueDialogResult({
    required this.reasonType,
    this.generalIssueDetails = '',
  });

  final String reasonType;
  final String generalIssueDetails;
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

  final generalIssueController = TextEditingController();

  String dialogSelectedReason = '';
  bool attemptedSubmit = false;

  final reportSelection = await showDialog<_ReportIssueDialogResult>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final requiresGeneralIssueDetails =
              dialogSelectedReason == 'general_issue';

          final trimmedGeneralIssueDetails = generalIssueController.text.trim();

          final showGeneralIssueError =
              attemptedSubmit &&
              requiresGeneralIssueDetails &&
              trimmedGeneralIssueDetails.isEmpty;
          final canSubmitReport =
              dialogSelectedReason.isNotEmpty &&
              (!requiresGeneralIssueDetails ||
                  trimmedGeneralIssueDetails.isNotEmpty);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 460,
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.88,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: kReportSoftSurface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFE3D8F6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE5FB),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.outlined_flag_rounded,
                              color: kReportPrimaryColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Report Issue',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1F1B2D),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Choose the reason for this report.',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    color: Color(0xFF6A637C),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.of(dialogContext).pop(),
                              child: const Padding(
                                padding: EdgeInsets.all(10),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Color(0xFF6F6784),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ...kReportReasonOptions.map((option) {
                        final optionValue = option['value']!;
                        final optionLabel = option['label']!;
                        final optionSubtitle = _reportReasonSubtitle(
                          optionValue,
                        );
                        final isSelected = dialogSelectedReason == optionValue;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              setDialogState(() {
                                dialogSelectedReason = optionValue;
                                attemptedSubmit = false;

                                if (optionValue != 'general_issue') {
                                  generalIssueController.clear();
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFF1EAFE)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? kReportPrimaryColor
                                      : const Color(0xFFD8C9F2),
                                  width: isSelected ? 1.6 : 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFE9DEFB)
                                          : const Color(0xFFF5F1FC),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      _reportReasonIcon(optionValue),
                                      color: isSelected
                                          ? kReportPrimaryColor
                                          : const Color(0xFF7B709A),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          optionLabel,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? kReportPrimaryColor
                                                : const Color(0xFF342E43),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          optionSubtitle,
                                          style: const TextStyle(
                                            fontSize: 13.2,
                                            color: Color(0xFF6E6780),
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? const Color(0xFFE9DEFB)
                                          : Colors.white,
                                      border: Border.all(
                                        color: isSelected
                                            ? kReportPrimaryColor
                                            : const Color(0xFFC4B3E5),
                                        width: 1.8,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Center(
                                            child: Icon(
                                              Icons.circle,
                                              size: 10,
                                              color: kReportPrimaryColor,
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      if (requiresGeneralIssueDetails) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: showGeneralIssueError
                                  ? kReportFlagColor
                                  : const Color(0xFFD8C9F2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'General issue details',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF352F45),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Add a brief note so we understand the issue.',
                                style: TextStyle(
                                  fontSize: 12.8,
                                  color: Color(0xFF6E6780),
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: generalIssueController,
                                maxLength: 50,
                                maxLines: 2,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(50),
                                ],
                                onChanged: (_) {
                                  setDialogState(() {});
                                },
                                decoration: InputDecoration(
                                  labelText: 'Briefly describe the issue',
                                  hintText: 'Required for general issue',
                                  alignLabelWithHint: true,
                                  filled: true,
                                  fillColor: const Color(0xFFF9F6FD),
                                  errorText: showGeneralIssueError
                                      ? 'Please enter brief details'
                                      : null,
                                  contentPadding: const EdgeInsets.all(14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFDCCFF3),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFDCCFF3),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: kReportPrimaryColor,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: kReportFlagColor,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: kReportFlagColor,
                                    ),
                                  ),
                                ),
                                buildCounter:
                                    (
                                      BuildContext context, {
                                      required int currentLength,
                                      required bool isFocused,
                                      required int? maxLength,
                                    }) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          '$currentLength/${maxLength ?? 50}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF7B748D),
                                          ),
                                        ),
                                      );
                                    },
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                FocusScope.of(dialogContext).unfocus();
                                Navigator.of(dialogContext).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kReportPrimaryColor,
                                side: const BorderSide(
                                  color: Color(0xFFCDB9F0),
                                ),
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: canSubmitReport
                                  ? () {
                                      final trimmedDetails =
                                          generalIssueController.text.trim();

                                      if (dialogSelectedReason ==
                                              'general_issue' &&
                                          trimmedDetails.isEmpty) {
                                        setDialogState(() {
                                          attemptedSubmit = true;
                                        });
                                        return;
                                      }

                                      FocusScope.of(dialogContext).unfocus();
                                      Navigator.of(dialogContext).pop(
                                        _ReportIssueDialogResult(
                                          reasonType: dialogSelectedReason,
                                          generalIssueDetails:
                                              dialogSelectedReason ==
                                                  'general_issue'
                                              ? trimmedDetails
                                              : '',
                                        ),
                                      );
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kReportPrimaryColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(
                                  0xFFE4DEEF,
                                ),
                                disabledForegroundColor: const Color(
                                  0xFF8D859C,
                                ),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Submit',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  Future<void>.delayed(const Duration(milliseconds: 350), () {
    generalIssueController.dispose();
  });

  if (reportSelection == null || reportSelection.reasonType.trim().isEmpty) {
    return;
  }

  final selectedReason = reportSelection.reasonType.trim();
  final generalIssueDetails = reportSelection.generalIssueDetails.trim();
  final reasonText = reportReasonLabel(selectedReason);
  final notificationService = AppNotificationService();

  try {
    final reporterDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(reporter.uid)
        .get();

    final reporterData = reporterDoc.data() ?? <String, dynamic>{};
    final reporterName = _displayName(reporterData, 'User');
    final reportRef = FirebaseFirestore.instance
        .collection('general_reports')
        .doc();

    await reportRef.set({
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

      // Important:
      // Admin details pages usually read "details" or "description",
      // so save the General issue text there too.
      'generalIssueDetails': generalIssueDetails,
      'details': generalIssueDetails,
      'description': generalIssueDetails,

      'status': 'submitted',
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'general_report',
    });

    try {
      await notificationService.createAdminGeneralReportNotification(
        reportId: reportRef.id,
        reporterId: reporter.uid,
        reporterName: reporterName,
        reportedUserName: reportedUserName.trim(),
        reasonText: reasonText,
      );
    } catch (error) {
      debugPrint('Create admin general report notification error: $error');
    }

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
