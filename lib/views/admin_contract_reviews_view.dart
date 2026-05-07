import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../controlles/admin_reports_controller.dart';
import 'admin_contract_review_details_view.dart';
import 'admin_ui.dart';

class AdminContractReviewsView extends StatefulWidget {
  const AdminContractReviewsView({super.key});

  @override
  State<AdminContractReviewsView> createState() =>
      _AdminContractReviewsViewState();
}

class _AdminContractReviewsViewState extends State<AdminContractReviewsView> {
  String _selectedFilter = 'All';

  static const List<String> _filters = [
    'All',
    'Requested',
    'Under Review',
    'Resolved',
    'Dismissed',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminBackground,
      appBar: AppBar(
        title: const Text('Contract Reviews'),
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
                    .collection('contract_reports')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AdminLoadingState();
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const AdminEmptyState(
                      icon: Icons.fact_check_outlined,
                      title: 'No contract reviews yet.',
                      subtitle: 'Contract review requests will appear here.',
                    );
                  }

                  final reviews = snapshot.data!.docs
                      .map((doc) => _ContractReviewCardData.fromDoc(doc))
                      .where((review) => !review.isDeleted)
                      .where(_matchesFilter)
                      .toList();

                  if (reviews.isEmpty) {
                    return const AdminEmptyState(
                      icon: Icons.filter_alt_off_rounded,
                      title: 'No matching contract reviews.',
                      subtitle: 'Try switching filters.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemBuilder: (context, index) {
                      final review = reviews[index];
                      return _ContractReviewListCard(review: review);
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: reviews.length,
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
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

  bool _matchesFilter(_ContractReviewCardData review) {
    switch (_selectedFilter) {
      case 'Requested':
        return review.normalizedStatus == 'requested';
      case 'Under Review':
        return review.normalizedStatus == 'under_review';
      case 'Resolved':
        return review.normalizedStatus == 'resolved';
      case 'Dismissed':
        return review.normalizedStatus == 'dismissed';
      case 'All':
      default:
        return true;
    }
  }
}

class _ContractReviewListCard extends StatelessWidget {
  const _ContractReviewListCard({required this.review});

  final _ContractReviewCardData review;

  @override
  Widget build(BuildContext context) {
    return AdminModerationListCard(
      icon: Icons.fact_check_outlined,
      title: review.reporterName,
      subtitle: 'Other party: ${review.otherPartyName}',
      reason: review.reasonLabel,
      status: review.normalizedStatus,
      statusLabel: review.statusLabel,
      createdAtLabel: review.createdAtLabel,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminContractReviewDetailsView(reviewId: review.id),
          ),
        );
      },
      onRemove: () => _removeContractReview(context, review.id),
    );
  }
}

class _ContractReviewCardData {
  const _ContractReviewCardData({
    required this.id,
    required this.reporterName,
    required this.otherPartyName,
    required this.reasonLabel,
    required this.statusLabel,
    required this.normalizedStatus,
    required this.createdAtLabel,
    required this.isDeleted,
  });

  final String id;
  final String reporterName;
  final String otherPartyName;
  final String reasonLabel;
  final String statusLabel;
  final String normalizedStatus;
  final String createdAtLabel;
  final bool isDeleted;

  factory _ContractReviewCardData.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final rawStatus = _firstFilled([data['status'], 'requested']);

    return _ContractReviewCardData(
      id: doc.id,
      reporterName: _firstFilled([
        data['reporterName'],
        data['reporterUserName'],
        'Unknown Reporter',
      ]),
      otherPartyName: _firstFilled([
        data['otherPartyName'],
        data['otherUserName'],
        data['reportedUserName'],
        'Unknown User',
      ]),
      reasonLabel: _firstFilled([
        data['reasonLabel'],
        data['reason'],
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

Future<void> _removeContractReview(
  BuildContext context,
  String reviewId,
) async {
  final shouldRemove = await _showRemoveReportDialog(context);
  if (!context.mounted || !shouldRemove) return;

  try {
    await AdminReportsController().softDeleteContractReview(reviewId: reviewId);
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
