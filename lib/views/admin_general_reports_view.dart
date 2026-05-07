import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../controlles/admin_reports_controller.dart';
import 'admin_general_report_details_view.dart';
import 'admin_ui.dart';

class AdminGeneralReportsView extends StatefulWidget {
  const AdminGeneralReportsView({super.key});

  @override
  State<AdminGeneralReportsView> createState() =>
      _AdminGeneralReportsViewState();
}

class _AdminGeneralReportsViewState extends State<AdminGeneralReportsView> {
  String _selectedFilter = 'All';

  static const List<String> _filters = [
    'All',
    'Open',
    'Under Review',
    'Resolved',
    'Dismissed',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminBackground,
      appBar: AppBar(
        title: const Text('General Reports'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: kAdminPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 14),
            _buildFilterChips(),
            const SizedBox(height: 14),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('general_reports')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AdminLoadingState();
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const AdminEmptyState(
                      icon: Icons.outlined_flag_rounded,
                      title: 'No general reports yet.',
                      subtitle: 'New general reports will appear here.',
                    );
                  }

                  final reports = snapshot.data!.docs
                      .map((doc) => _GeneralReportCardData.fromDoc(doc))
                      .where((report) => !report.isDeleted)
                      .where(_matchesFilters)
                      .toList();

                  if (reports.isEmpty) {
                    return const AdminEmptyState(
                      icon: Icons.filter_alt_off_rounded,
                      title: 'No matching reports.',
                      subtitle: 'Try changing your filter.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return _GeneralReportListCard(report: report);
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: reports.length,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final filter = _filters[index];

          return AdminFilterChip(
            label: filter,
            selected: filter == _selectedFilter,
            onSelected: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _filters.length,
      ),
    );
  }

  bool _matchesFilters(_GeneralReportCardData report) {
    switch (_selectedFilter) {
      case 'Open':
        return report.normalizedStatus == 'open' ||
            report.normalizedStatus == 'submitted' ||
            report.normalizedStatus == 'pending';
      case 'Under Review':
        return report.normalizedStatus == 'under_review';
      case 'Resolved':
        return report.normalizedStatus == 'resolved';
      case 'Dismissed':
        return report.normalizedStatus == 'dismissed' ||
            report.normalizedStatus == 'invalid';
      case 'All':
      default:
        return true;
    }
  }
}

class _GeneralReportListCard extends StatelessWidget {
  const _GeneralReportListCard({required this.report});

  final _GeneralReportCardData report;

  @override
  Widget build(BuildContext context) {
    return AdminModerationListCard(
      icon: Icons.person_search_rounded,
      title: report.reporterName,
      subtitle: 'Reported user: ${report.reportedUserName}',
      reason: report.reason,
      status: report.normalizedStatus,
      statusLabel: report.statusLabel,
      createdAtLabel: report.createdAtLabel,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminGeneralReportDetailsView(reportId: report.id),
          ),
        );
      },
      onRemove: () => _removeGeneralReport(context, report.id),
    );
  }
}

class _GeneralReportCardData {
  const _GeneralReportCardData({
    required this.id,
    required this.reporterName,
    required this.reportedUserName,
    required this.reason,
    required this.statusLabel,
    required this.normalizedStatus,
    required this.createdAtLabel,
    required this.isDeleted,
  });

  final String id;
  final String reporterName;
  final String reportedUserName;
  final String reason;
  final String statusLabel;
  final String normalizedStatus;
  final String createdAtLabel;
  final bool isDeleted;

  factory _GeneralReportCardData.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawStatus = _firstFilled([
      data['status'],
      'Open',
    ]);

    return _GeneralReportCardData(
      id: doc.id,
      reporterName: _firstFilled([
        data['reporterName'],
        data['reporterUserName'],
        'Unknown Reporter',
      ]),
      reportedUserName: _firstFilled([
        data['reportedUserName'],
        'Unknown User',
      ]),
      reason: _firstFilled([
        data['reason'],
        data['reasonText'],
        data['reasonType'],
        'No reason provided',
      ]),
      statusLabel: adminStatusLabel(rawStatus),
      normalizedStatus: rawStatus.toLowerCase().replaceAll(' ', '_'),
      createdAtLabel: _formatCreatedAt(data['createdAt']),
      isDeleted: data['isDeleted'] == true,
    );
  }
}

Future<void> _removeGeneralReport(BuildContext context, String reportId) async {
  final shouldRemove = await _showRemoveReportDialog(context);
  if (!context.mounted || !shouldRemove) return;

  try {
    await AdminReportsController().softDeleteGeneralReport(reportId: reportId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report removed from admin list.')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
  }
}

Future<bool> _showRemoveReportDialog(BuildContext context) async {
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

String _friendlyError(Object error) {
  final message = error.toString().trim();
  if (message.startsWith('Exception: ')) {
    return message.substring('Exception: '.length);
  }
  return 'Something went wrong. Please try again.';
}

String _firstFilled(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _formatCreatedAt(dynamic value) {
  DateTime? dateTime;

  if (value is Timestamp) {
    dateTime = value.toDate();
  } else if (value is DateTime) {
    dateTime = value;
  } else if (value is String) {
    dateTime = DateTime.tryParse(value);
  }

  if (dateTime == null) return 'Unknown date';

  final year = dateTime.year.toString().padLeft(4, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');

  return '$year-$month-$day $hour:$minute';
}
