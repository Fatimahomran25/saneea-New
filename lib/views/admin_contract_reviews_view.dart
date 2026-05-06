import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AdminContractReviewDetailsView(reviewId: review.id),
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: adminCardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kAdminSoftSurface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: kAdminPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            review.reporterName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: kAdminTextPrimary,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AdminStatusChip(
                          status: review.normalizedStatus,
                          label: review.statusLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Other party: ${review.otherPartyName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kAdminTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: kAdminSoftSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        review.reasonLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kAdminTextPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (review.contractStatusRaw.isNotEmpty)
                          AdminStatusChip(
                            status: review.contractStatusRaw,
                            label: review.contractStatusLabel,
                          ),
                        AdminMetaPill(
                          label: review.createdAtLabel,
                          icon: Icons.schedule_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
    required this.contractStatusRaw,
    required this.contractStatusLabel,
    required this.createdAtLabel,
  });

  final String id;
  final String reporterName;
  final String otherPartyName;
  final String reasonLabel;
  final String statusLabel;
  final String normalizedStatus;
  final String contractStatusRaw;
  final String contractStatusLabel;
  final String createdAtLabel;

  factory _ContractReviewCardData.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final rawStatus = _firstFilled([data['status'], 'requested']);

    final rawContractStatus = _firstFilled([data['contractStatus']]);

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
      contractStatusRaw: rawContractStatus,
      contractStatusLabel: adminStatusLabel(rawContractStatus),
      createdAtLabel: _formatCreatedAt(data['createdAt']),
    );
  }
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
