import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../controlles/admin_reports_controller.dart';
import 'admin_ui.dart';

class AdminGeneralReportDetailsView extends StatefulWidget {
  const AdminGeneralReportDetailsView({
    super.key,
    required this.reportId,
  });

  final String reportId;

  @override
  State<AdminGeneralReportDetailsView> createState() =>
      _AdminGeneralReportDetailsViewState();
}

class _AdminGeneralReportDetailsViewState
    extends State<AdminGeneralReportDetailsView> {
  final AdminReportsController _controller = AdminReportsController();

  late Future<_GeneralReportDetailsData> _detailsFuture;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadDetails();
  }

  Future<_GeneralReportDetailsData> _loadDetails() async {
    final reportSnapshot = await FirebaseFirestore.instance
        .collection('general_reports')
        .doc(widget.reportId)
        .get();

    if (!reportSnapshot.exists) {
      throw Exception('This report was not found.');
    }

    final reportData = reportSnapshot.data() ?? <String, dynamic>{};
    final reporterId = (reportData['reporterId'] ?? '').toString().trim();
    final reportedUserId =
        (reportData['reportedUserId'] ?? '').toString().trim();

    Map<String, dynamic>? reporterData;
    Map<String, dynamic>? reportedUserData;

    if (reporterId.isNotEmpty) {
      final reporterSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(reporterId)
          .get();
      reporterData = reporterSnapshot.data();
    }

    if (reportedUserId.isNotEmpty) {
      final reportedUserSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(reportedUserId)
          .get();
      reportedUserData = reportedUserSnapshot.data();
    }

    return _GeneralReportDetailsData(
      reportSnapshot: reportSnapshot,
      reporterData: reporterData,
      reportedUserData: reportedUserData,
    );
  }

  Future<void> _dismissReport() async {
    setState(() => _isUpdatingStatus = true);
    try {
      await _controller.dismissGeneralReport(reportId: widget.reportId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report dismissed successfully.')),
      );
      setState(() {
        _detailsFuture = _loadDetails();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<void> _markValidAndGiveWarning({
    required String reportedUserId,
    required String warningReason,
  }) async {
    setState(() => _isUpdatingStatus = true);
    try {
      await _controller.markGeneralReportValid(
        reportId: widget.reportId,
        reportedUserId: reportedUserId,
        warningReason: warningReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report marked valid and warning saved.')),
      );
      setState(() {
        _detailsFuture = _loadDetails();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<void> _blockReportedUser({
    required String reportedUserId,
    required String blockedReason,
  }) async {
    setState(() => _isUpdatingStatus = true);
    try {
      await _controller.blockReportedUser(
        reportedUserId: reportedUserId,
        blockedReason: blockedReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User blocked successfully.')),
      );
      setState(() {
        _detailsFuture = _loadDetails();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<void> _showAdminActionsSheet({
    required String reportedUserId,
    required String warningReason,
    required int warningCount,
    required bool isUserBlocked,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kAdminBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Admin Actions',
                  style: TextStyle(
                    color: kAdminPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose how you want to handle this report.',
                  style: TextStyle(
                    color: kAdminTextSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                AdminActionSheetTile(
                  icon: Icons.close_rounded,
                  iconColor: kAdminPrimary,
                  title: 'Dismiss Report',
                  subtitle: 'Close this report without further action.',
                  enabled: !_isUpdatingStatus,
                  onTap: _isUpdatingStatus
                      ? null
                      : () {
                          Navigator.pop(sheetContext);
                          _dismissReport();
                        },
                ),
                const Divider(height: 20, color: kAdminBorder),
                AdminActionSheetTile(
                  icon: Icons.warning_amber_rounded,
                  iconColor: kAdminWarning,
                  title: 'Mark Valid / Give Warning',
                  subtitle: 'Keep the report valid and save a warning.',
                  enabled: !_isUpdatingStatus && reportedUserId.isNotEmpty,
                  onTap: _isUpdatingStatus || reportedUserId.isEmpty
                      ? null
                      : () {
                          Navigator.pop(sheetContext);
                          _markValidAndGiveWarning(
                            reportedUserId: reportedUserId,
                            warningReason: warningReason,
                          );
                        },
                ),
                if (!isUserBlocked && warningCount >= 3) ...[
                  const Divider(height: 20, color: kAdminBorder),
                  AdminActionSheetTile(
                    icon: Icons.block_rounded,
                    iconColor: kAdminDanger,
                    title: 'Block User',
                    subtitle: 'Block the reported user after repeated warnings.',
                    enabled: !_isUpdatingStatus && reportedUserId.isNotEmpty,
                    onTap: _isUpdatingStatus || reportedUserId.isEmpty
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            _blockReportedUser(
                              reportedUserId: reportedUserId,
                              blockedReason: warningReason,
                            );
                          },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _openUserProfile({
    required String title,
    required String name,
    required String email,
    required String accountType,
    required String photoUrl,
    int? warningCount,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserProfilePage(
          title: title,
          name: name,
          email: email,
          accountType: accountType,
          photoUrl: photoUrl,
          secondaryPillLabel:
              warningCount != null ? 'Warnings: $warningCount' : '',
          secondaryPillIcon: warningCount != null
              ? Icons.warning_amber_rounded
              : null,
          secondaryPillColor: kAdminWarning,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'General Report Details',
          style: TextStyle(
            color: kAdminPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: kAdminPrimary),
      ),
      body: FutureBuilder<_GeneralReportDetailsData>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AdminLoadingState();
          }

          if (snapshot.hasError) {
            return AdminEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load this report.',
              subtitle: _friendlyError(snapshot.error),
            );
          }

          final details = snapshot.data;
          if (details == null) {
            return const SizedBox.shrink();
          }

          final reportData = details.reportSnapshot.data() ?? <String, dynamic>{};
          final reporterData = details.reporterData;
          final reportedUserData = details.reportedUserData;

          final rawReporterId = (reportData['reporterId'] ?? '').toString().trim();
          final rawReportedUserId =
              (reportData['reportedUserId'] ?? '').toString().trim();

          final reporterName = _displayName(
            reporterData,
            fallbackName: (reportData['reporterName'] ?? '').toString().trim(),
            fallbackId: rawReporterId,
          );

          final reportedUserName = _displayName(
            reportedUserData,
            fallbackName:
                (reportData['reportedUserName'] ?? '').toString().trim(),
            fallbackId: rawReportedUserId,
          );

          final reporterEmail = (reporterData?['email'] ?? '').toString().trim();
          final reporterAccountType =
              (reporterData?['accountType'] ?? '').toString().trim();
          final reporterAccountTypeLabel = reporterAccountType.isEmpty
              ? ''
              : adminStatusLabel(reporterAccountType);
          final reporterPhotoUrl =
              (reporterData?['photoUrl'] ?? '').toString().trim();

          final reportedUserEmail =
              (reportedUserData?['email'] ?? '').toString().trim();
          final reportedUserAccountType =
              (reportedUserData?['accountType'] ?? '').toString().trim();
          final reportedUserAccountTypeLabel = reportedUserAccountType.isEmpty
              ? ''
              : adminStatusLabel(reportedUserAccountType);
          final reportedUserPhotoUrl =
              (reportedUserData?['photoUrl'] ?? '').toString().trim();

          final reason = (reportData['reason'] ?? '').toString().trim();
          final description =
              _firstFilled(<String?>[
                reportData['description']?.toString(),
                reportData['details']?.toString(),
              ]) ??
              '';
          final reportedContent =
              _firstFilled(<String?>[
                reportData['reportedContent']?.toString(),
                reportData['reportedItem']?.toString(),
                reportData['evidence']?.toString(),
              ]) ??
              '';
          final status = (reportData['status'] ?? 'open').toString().trim();
          final createdAt = reportData['createdAt'];
          final warningCount = _intValue(
            reportedUserData?['warningCount'] ?? reportData['warningCount'],
          );
          final isUserBlocked =
              reportData['isBlocked'] == true || reportedUserData?['isBlocked'] == true;
          final warningReason = reason.isEmpty ? 'Repeated violations' : reason;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isUpdatingStatus)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: const LinearProgressIndicator(
                        minHeight: 5,
                        color: kAdminPrimary,
                        backgroundColor: kAdminBorder,
                      ),
                    ),
                  ),
                AdminSectionCard(
                  title: 'Report Summary',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdminInfoPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reason',
                              style: TextStyle(
                                color: kAdminPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              reason.isEmpty ? 'No reason provided' : reason,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: kAdminTextPrimary,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          AdminStatusChip(status: status),
                          AdminMetaPill(
                            label: _formatDateTime(createdAt),
                            icon: Icons.schedule_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Details',
                        style: TextStyle(
                          color: kAdminPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _BodyTextCard(
                        text: description.isEmpty
                            ? 'No additional details were provided for this report.'
                            : description,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Reporter',
                  child: AdminProfilePreviewCard(
                    name: reporterName,
                    email: reporterEmail,
                    accountType: reporterAccountTypeLabel,
                    photoUrl: reporterPhotoUrl,
                    onTap: () => _openUserProfile(
                      title: 'Reporter Profile',
                      name: reporterName,
                      email: reporterEmail,
                      accountType: reporterAccountTypeLabel,
                      photoUrl: reporterPhotoUrl,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Reported User',
                  child: AdminProfilePreviewCard(
                    name: reportedUserName,
                    email: reportedUserEmail,
                    accountType: reportedUserAccountTypeLabel,
                    photoUrl: reportedUserPhotoUrl,
                    secondaryPillLabel:
                        warningCount > 0 ? 'Warnings: $warningCount' : '',
                    secondaryPillIcon: warningCount > 0
                        ? Icons.warning_amber_rounded
                        : null,
                    secondaryPillColor: kAdminWarning,
                    onTap: () => _openUserProfile(
                      title: 'Reported User Profile',
                      name: reportedUserName,
                      email: reportedUserEmail,
                      accountType: reportedUserAccountTypeLabel,
                      photoUrl: reportedUserPhotoUrl,
                      warningCount: warningCount > 0 ? warningCount : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Reported Content / Evidence',
                  child: reportedContent.isNotEmpty
                      ? _BodyTextCard(text: reportedContent)
                      : const AdminInfoPanel(
                          child: Text(
                            'No reported content or evidence was attached to this report.',
                            style: TextStyle(
                              color: kAdminTextSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Admin Actions',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Open the action menu to manage this report.',
                        style: TextStyle(
                          color: kAdminTextSecondary,
                          height: 1.45,
                        ),
                      ),
                      if (isUserBlocked) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: kAdminDanger.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kAdminDanger.withOpacity(0.14),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.block_rounded, color: kAdminDanger, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'User already blocked',
                                style: TextStyle(
                                  color: kAdminDanger,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      AdminActionMenuButton(
                        label: 'Admin Actions',
                        onPressed: _isUpdatingStatus
                            ? null
                            : () => _showAdminActionsSheet(
                                  reportedUserId: rawReportedUserId,
                                  warningReason: warningReason,
                                  warningCount: warningCount,
                                  isUserBlocked: isUserBlocked,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BodyTextCard extends StatelessWidget {
  const _BodyTextCard({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return AdminInfoPanel(
      child: Text(
        text,
        style: const TextStyle(
          color: kAdminTextPrimary,
          fontSize: 13.5,
          height: 1.55,
        ),
      ),
    );
  }
}

class _GeneralReportDetailsData {
  const _GeneralReportDetailsData({
    required this.reportSnapshot,
    required this.reporterData,
    required this.reportedUserData,
  });

  final DocumentSnapshot<Map<String, dynamic>> reportSnapshot;
  final Map<String, dynamic>? reporterData;
  final Map<String, dynamic>? reportedUserData;
}

String? _firstFilled(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

String _displayName(
  Map<String, dynamic>? userData, {
  required String fallbackName,
  required String fallbackId,
}) {
  final first = (userData?['firstName'] ?? '').toString().trim();
  final last = (userData?['lastName'] ?? '').toString().trim();
  final fullName = ([first, last]..removeWhere((item) => item.isEmpty))
      .join(' ')
      .trim();

  if (fullName.isNotEmpty) {
    return fullName;
  }
  if (fallbackName.isNotEmpty) {
    return fallbackName;
  }
  if (fallbackId.isNotEmpty) {
    return fallbackId;
  }
  return 'Unknown user';
}

String _formatDateTime(dynamic value) {
  if (value is Timestamp) {
    final dateTime = value.toDate();
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day $hour:$minute';
  }

  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? 'Not available' : text;
}

String _friendlyError(Object? error) {
  final text = error?.toString().trim() ?? '';
  if (text.isEmpty) {
    return 'Something went wrong while loading this report.';
  }

  const prefixes = <String>[
    'Exception: ',
    'FirebaseException: ',
  ];

  for (final prefix in prefixes) {
    if (text.startsWith(prefix)) {
      return text.substring(prefix.length).trim();
    }
  }

  return text;
}

int _intValue(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
