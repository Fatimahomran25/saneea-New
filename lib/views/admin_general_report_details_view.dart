import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../controlles/admin_reports_controller.dart';
import 'admin_ui.dart';
import 'client_profile.dart';
import 'freelancer_profile.dart';

class AdminGeneralReportDetailsView extends StatefulWidget {
  const AdminGeneralReportDetailsView({super.key, required this.reportId});

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
    final reportedUserId = (reportData['reportedUserId'] ?? '')
        .toString()
        .trim();

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

  void _refresh() {
    setState(() {
      _detailsFuture = _loadDetails();
    });
  }

  Future<void> _updateReportStatus(String status) async {
    setState(() => _isUpdatingStatus = true);
    try {
      await _controller.updateGeneralReportStatus(
        reportId: widget.reportId,
        status: status,
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'under_review'
                ? 'Report marked under review.'
                : 'Report marked resolved.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<void> _dismissReport() async {
    setState(() => _isUpdatingStatus = true);
    try {
      await _controller.dismissGeneralReport(reportId: widget.reportId);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report dismissed successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
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
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Warning saved and report resolved successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<void> _reopenReport() async {
    setState(() => _isUpdatingStatus = true);
    try {
      await _controller.reopenGeneralReport(reportId: widget.reportId);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report reopened successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
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
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User blocked successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<void> _unblockReportedUser({required String reportedUserId}) async {
    setState(() => _isUpdatingStatus = true);
    try {
      await _controller.unblockReportedUser(reportedUserId: reportedUserId);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User unblocked successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<void> _removeReport() async {
    final shouldRemove = await _showRemoveReportDialog();
    if (!shouldRemove || !mounted) return;

    setState(() => _isUpdatingStatus = true);
    try {
      await _controller.softDeleteGeneralReport(reportId: widget.reportId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report removed from admin list.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<bool> _showRemoveReportDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Report?'),
          content: const Text(
            "This will remove the report from the admin list only. The user's warning count and block status will not be changed.",
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            AdminDialogActionRow(
              cancelLabel: 'Cancel',
              confirmLabel: 'Remove',
              confirmColor: kAdminDanger,
              onCancel: () => Navigator.pop(dialogContext, false),
              onConfirm: () => Navigator.pop(dialogContext, true),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showReportStatusSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.48,
            minChildSize: 0.32,
            maxChildSize: 0.70,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                        'Update Report Status',
                        style: TextStyle(
                          color: kAdminPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Choose a new status for this general report.',
                        style: TextStyle(
                          color: kAdminTextSecondary,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AdminActionSheetTile(
                        icon: Icons.visibility_outlined,
                        iconColor: kAdminWarning,
                        title: 'Mark as Under Review',
                        subtitle: 'Move this report into active review.',
                        enabled: !_isUpdatingStatus,
                        onTap: _isUpdatingStatus
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                _updateReportStatus('under_review');
                              },
                      ),
                      const Divider(height: 20, color: kAdminBorder),
                      AdminActionSheetTile(
                        icon: Icons.task_alt_rounded,
                        iconColor: kAdminSuccess,
                        title: 'Mark as Resolved',
                        subtitle: 'Resolve this report after review.',
                        enabled: !_isUpdatingStatus,
                        onTap: _isUpdatingStatus
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                _updateReportStatus('resolved');
                              },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showAdminActionsSheet({
    required String status,
    required String reportedUserId,
    required String warningReason,
    required int warningCount,
    required bool isUserBlocked,
  }) async {
    if (!_showsStandardAdminActions(status)) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.58,
            minChildSize: 0.34,
            maxChildSize: 0.80,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                        'Choose how you want to manage this general report.',
                        style: TextStyle(
                          color: kAdminTextSecondary,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AdminActionSheetTile(
                        icon: Icons.do_disturb_alt_outlined,
                        iconColor: kAdminMuted,
                        title: 'Dismiss / Invalid',
                        subtitle: 'Close this report as dismissed or invalid.',
                        enabled: !_isUpdatingStatus,
                        onTap: _isUpdatingStatus
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                _dismissReport();
                              },
                      ),
                      if (_canShowGiveWarningAction(
                        warningCount: warningCount,
                        isUserBlocked: isUserBlocked,
                      )) ...[
                        const Divider(height: 20, color: kAdminBorder),
                        AdminActionSheetTile(
                          icon: Icons.warning_amber_rounded,
                          iconColor: kAdminWarning,
                          title: 'Mark Valid / Give Warning',
                          subtitle:
                              'Resolve this report and save a warning for the user.',
                          enabled:
                              !_isUpdatingStatus && reportedUserId.isNotEmpty,
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
                      ],
                      if (_canShowBlockUserAction(
                        warningCount: warningCount,
                        isUserBlocked: isUserBlocked,
                      )) ...[
                        const Divider(height: 20, color: kAdminBorder),
                        AdminActionSheetTile(
                          icon: Icons.block_rounded,
                          iconColor: kAdminDanger,
                          title: 'Block User',
                          subtitle:
                              'Block the reported user after repeated warnings.',
                          enabled:
                              !_isUpdatingStatus && reportedUserId.isNotEmpty,
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
                      if (_canShowUnblockUserAction(
                        status: status,
                        isUserBlocked: isUserBlocked,
                      )) ...[
                        const Divider(height: 20, color: kAdminBorder),
                        AdminActionSheetTile(
                          icon: Icons.lock_open_rounded,
                          iconColor: kAdminSuccess,
                          title: 'Unblock User',
                          subtitle:
                              'Lift the user restriction and reset warnings so future actions start fresh.',
                          enabled:
                              !_isUpdatingStatus && reportedUserId.isNotEmpty,
                          onTap: _isUpdatingStatus || reportedUserId.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(sheetContext);
                                  _unblockReportedUser(
                                    reportedUserId: reportedUserId,
                                  );
                                },
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  bool _showsStandardAdminActions(String status) {
    switch (status.trim().toLowerCase()) {
      case 'dismissed':
      case 'invalid':
      case 'valid':
      case 'warning':
      case 'warning_given':
      case 'resolved':
        return false;
      default:
        return true;
    }
  }

  bool _canReopenReport(String status) {
    switch (status.trim().toLowerCase()) {
      case 'dismissed':
      case 'invalid':
      case 'valid':
      case 'warning':
      case 'warning_given':
      case 'resolved':
        return true;
      default:
        return false;
    }
  }

  bool _isOpenOrReopenedStatus(String status) {
    switch (status.trim().toLowerCase()) {
      case 'submitted':
      case 'open':
      case 'pending':
      case 'reopened':
        return true;
      default:
        return false;
    }
  }

  bool _canShowUnblockUserAction({
    required String status,
    required bool isUserBlocked,
  }) {
    return isUserBlocked && _isOpenOrReopenedStatus(status);
  }

  bool _canShowGiveWarningAction({
    required int warningCount,
    required bool isUserBlocked,
  }) {
    return !isUserBlocked && warningCount < AdminReportsController.maxWarnings;
  }

  bool _canShowBlockUserAction({
    required int warningCount,
    required bool isUserBlocked,
  }) {
    return !isUserBlocked && warningCount >= AdminReportsController.maxWarnings;
  }

  String? _handledAdminMessage({
    required String status,
    required bool warningApplied,
  }) {
    switch (status.trim().toLowerCase()) {
      case 'dismissed':
      case 'invalid':
        return 'This report has already been dismissed.';
      case 'valid':
      case 'warning':
      case 'warning_given':
        return 'This report has already been reviewed and a warning was issued.';
      case 'resolved':
        return warningApplied
            ? 'This report has been resolved and a warning was issued.'
            : 'This report has already been reviewed by the admin.';
      default:
        return null;
    }
  }

  void _openUserProfile({
    required String title,
    required String userId,
    required String name,
    required String email,
    required String accountType,
    required String accountTypeLabel,
    required String photoUrl,
    int? warningCount,
    bool isBlocked = false,
  }) {
    final normalizedUserId = userId.trim();
    final normalizedAccountType = accountType.trim().toLowerCase();

    if (normalizedUserId.isEmpty) {
      _showProfileFallbackMessage('This user profile is missing a user ID.');
      _openAdminProfileFallback(
        title: title,
        name: name,
        email: email,
        accountTypeLabel: accountTypeLabel,
        photoUrl: photoUrl,
        warningCount: warningCount,
        isBlocked: isBlocked,
      );
      return;
    }

    if (normalizedAccountType.isEmpty) {
      _showProfileFallbackMessage(
        'This user profile is missing an account type.',
      );
      _openAdminProfileFallback(
        title: title,
        name: name,
        email: email,
        accountTypeLabel: accountTypeLabel,
        photoUrl: photoUrl,
        warningCount: warningCount,
        isBlocked: isBlocked,
      );
      return;
    }

    Widget? destination;
    switch (normalizedAccountType) {
      case 'freelancer':
        destination = FreelancerProfileView(
          userId: normalizedUserId,
          readOnlyMode: true,
        );
        break;
      case 'client':
        destination = ClientProfile(
          userId: normalizedUserId,
          readOnlyMode: true,
        );
        break;
    }

    if (destination == null) {
      final unsupportedLabel = accountTypeLabel.isEmpty
          ? accountType
          : accountTypeLabel;
      _showProfileFallbackMessage(
        'Unsupported account type "$unsupportedLabel". Showing the summary view instead.',
      );
      _openAdminProfileFallback(
        title: title,
        name: name,
        email: email,
        accountTypeLabel: accountTypeLabel,
        photoUrl: photoUrl,
        warningCount: warningCount,
        isBlocked: isBlocked,
      );
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => destination!));
  }

  void _openAdminProfileFallback({
    required String title,
    required String name,
    required String email,
    required String accountTypeLabel,
    required String photoUrl,
    int? warningCount,
    bool isBlocked = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserProfilePage(
          title: title,
          name: name,
          email: email,
          accountType: accountTypeLabel,
          photoUrl: photoUrl,
          secondaryPillLabel: isBlocked
              ? 'Blocked'
              : warningCount != null
              ? 'Warnings: $warningCount'
              : '',
          secondaryPillIcon: isBlocked
              ? Icons.block_rounded
              : warningCount != null
              ? Icons.warning_amber_rounded
              : null,
          secondaryPillColor: isBlocked ? kAdminDanger : kAdminWarning,
        ),
      ),
    );
  }

  void _showProfileFallbackMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminBackground,
      appBar: AppBar(
        title: const Text(
          'General Report Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: kAdminPrimary,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: _isUpdatingStatus ? null : _showReportStatusSheet,
            tooltip: 'Update Report Status',
            icon: const Icon(Icons.edit_note_rounded),
          ),
          IconButton(
            onPressed: _isUpdatingStatus ? null : _removeReport,
            tooltip: 'Remove Report',
            icon: Icon(
              Icons.delete_outline_rounded,
              color: _isUpdatingStatus ? kAdminMuted : kAdminDanger,
            ),
          ),
        ],
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

          final reportData =
              details.reportSnapshot.data() ?? <String, dynamic>{};
          final reporterData = details.reporterData;
          final reportedUserData = details.reportedUserData;

          final rawReporterId = (reportData['reporterId'] ?? '')
              .toString()
              .trim();
          final rawReportedUserId = (reportData['reportedUserId'] ?? '')
              .toString()
              .trim();

          final reporterName = _displayName(
            reporterData,
            fallbackName: (reportData['reporterName'] ?? '').toString().trim(),
            fallbackId: rawReporterId,
          );

          final reportedUserName = _displayName(
            reportedUserData,
            fallbackName: (reportData['reportedUserName'] ?? '')
                .toString()
                .trim(),
            fallbackId: rawReportedUserId,
          );

          final reporterEmail = (reporterData?['email'] ?? '')
              .toString()
              .trim();
          final reporterAccountType = (reporterData?['accountType'] ?? '')
              .toString()
              .trim();
          final reporterAccountTypeLabel = reporterAccountType.isEmpty
              ? ''
              : adminStatusLabel(reporterAccountType);
          final reporterPhotoUrl =
              _firstFilled(<String?>[
                reporterData?['photoUrl']?.toString(),
                reporterData?['profile']?.toString(),
              ]) ??
              '';

          final reportedUserEmail = (reportedUserData?['email'] ?? '')
              .toString()
              .trim();
          final reportedUserAccountType =
              (reportedUserData?['accountType'] ?? '').toString().trim();
          final reportedUserAccountTypeLabel = reportedUserAccountType.isEmpty
              ? ''
              : adminStatusLabel(reportedUserAccountType);
          final reportedUserPhotoUrl =
              _firstFilled(<String?>[
                reportedUserData?['photoUrl']?.toString(),
                reportedUserData?['profile']?.toString(),
              ]) ??
              '';

          final reason = (reportData['reason'] ?? '').toString().trim();
          final description =
              _firstFilled(<String?>[
                reportData['description']?.toString(),
                reportData['generalIssueDetails']?.toString(),
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
          final normalizedStatus = status.toLowerCase();
          final createdAt = reportData['createdAt'];
          final warningCountValue =
              reportedUserData?['warningCount'] ?? reportData['warningCount'];
          final warningCount = _intValue(warningCountValue);
          final hasWarningCount = warningCountValue != null;
          final isUserBlocked = reportedUserData != null
              ? reportedUserData['isBlocked'] == true
              : reportData['isBlocked'] == true;
          final warningApplied = reportData['warningApplied'] == true;
          final warningReason = reason.isEmpty ? 'Repeated violations' : reason;
          final handledAdminMessage = _handledAdminMessage(
            status: normalizedStatus,
            warningApplied: warningApplied,
          );
          final showsStandardAdminActions = _showsStandardAdminActions(
            normalizedStatus,
          );
          final canReopenReport = _canReopenReport(normalizedStatus);

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
                      AdminInfoPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AdminKeyValueRow(
                              label: 'Status',
                              value: adminStatusLabel(status),
                            ),
                            AdminKeyValueRow(
                              label: 'Created',
                              value: _formatDateTime(createdAt),
                            ),
                            if (hasWarningCount)
                              AdminKeyValueRow(
                                label: 'Warnings',
                                value: warningCount.toString(),
                              ),
                          ],
                        ),
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
                      userId: rawReporterId,
                      name: reporterName,
                      email: reporterEmail,
                      accountType: reporterAccountType,
                      accountTypeLabel: reporterAccountTypeLabel,
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
                    secondaryPillLabel: isUserBlocked ? 'Blocked' : null,
                    secondaryPillIcon: isUserBlocked
                        ? Icons.block_rounded
                        : null,
                    secondaryPillColor: kAdminDanger,
                    onTap: () => _openUserProfile(
                      title: 'Reported User Profile',
                      userId: rawReportedUserId,
                      name: reportedUserName,
                      email: reportedUserEmail,
                      accountType: reportedUserAccountType,
                      accountTypeLabel: reportedUserAccountTypeLabel,
                      photoUrl: reportedUserPhotoUrl,
                      warningCount: warningCount > 0 ? warningCount : null,
                      isBlocked: isUserBlocked,
                    ),
                  ),
                ),
                if (reportedContent.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AdminSectionCard(
                    title: 'Reported Content',
                    child: _BodyTextCard(text: reportedContent),
                  ),
                ],
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Admin Actions',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (handledAdminMessage != null)
                        AdminInfoPanel(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: kAdminSoftSurface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  normalizedStatus == 'dismissed' ||
                                          normalizedStatus == 'invalid'
                                      ? Icons.close_rounded
                                      : Icons.verified_rounded,
                                  color: normalizedStatus == 'dismissed' ||
                                          normalizedStatus == 'invalid'
                                      ? kAdminMuted
                                      : kAdminSuccess,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  handledAdminMessage,
                                  style: const TextStyle(
                                    color: kAdminTextSecondary,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
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
                              Icon(
                                Icons.block_rounded,
                                color: kAdminDanger,
                                size: 18,
                              ),
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
                      if (showsStandardAdminActions) ...[
                        const SizedBox(height: 14),
                        AdminActionMenuButton(
                          label: 'Admin Actions',
                          onPressed: _isUpdatingStatus
                              ? null
                              : () => _showAdminActionsSheet(
                                  status: normalizedStatus,
                                  reportedUserId: rawReportedUserId,
                                  warningReason: warningReason,
                                  warningCount: warningCount,
                                  isUserBlocked: isUserBlocked,
                                ),
                        ),
                      ] else ...[
                        if (canReopenReport) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isUpdatingStatus
                                  ? null
                                  : _reopenReport,
                              style: adminFilledButtonStyle(),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text(
                                'Reopen Report',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ],
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
  const _BodyTextCard({required this.text});

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
  final fullName = ([
    first,
    last,
  ]..removeWhere((item) => item.isEmpty)).join(' ').trim();

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

  const prefixes = <String>['Exception: ', 'FirebaseException: '];

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
