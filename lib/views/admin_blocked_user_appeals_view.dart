import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controlles/app_notification_service.dart';
import 'admin_ui.dart';

class AdminBlockedUserAppealsView extends StatefulWidget {
  const AdminBlockedUserAppealsView({super.key});

  @override
  State<AdminBlockedUserAppealsView> createState() =>
      _AdminBlockedUserAppealsViewState();
}

class _AdminBlockedUserAppealsViewState
    extends State<AdminBlockedUserAppealsView> {
  String _selectedFilter = 'All';

  static const List<String> _filters = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminBackground,
      appBar: AppBar(
        title: const Text('Blocked User Appeals'),
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
                    .collection('blocked_user_appeals')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AdminLoadingState();
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const AdminEmptyState(
                      icon: Icons.shield_outlined,
                      title: 'No blocked user appeals yet.',
                      subtitle: 'Blocked account review requests will appear here.',
                    );
                  }

                  final appeals = snapshot.data!.docs
                      .map((doc) => _BlockedUserAppealCardData.fromDoc(doc))
                      .where(_matchesFilter)
                      .toList();

                  if (appeals.isEmpty) {
                    return const AdminEmptyState(
                      icon: Icons.filter_alt_off_rounded,
                      title: 'No matching appeals.',
                      subtitle: 'Try switching the selected status filter.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemBuilder: (context, index) {
                      final appeal = appeals[index];
                      return _BlockedUserAppealListCard(appeal: appeal);
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: appeals.length,
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

  bool _matchesFilter(_BlockedUserAppealCardData appeal) {
    switch (_selectedFilter) {
      case 'Pending':
        return appeal.normalizedStatus == 'pending';
      case 'Approved':
        return appeal.normalizedStatus == 'approved';
      case 'Rejected':
        return appeal.normalizedStatus == 'rejected';
      case 'All':
      default:
        return true;
    }
  }
}

class _BlockedUserAppealListCard extends StatelessWidget {
  const _BlockedUserAppealListCard({required this.appeal});

  final _BlockedUserAppealCardData appeal;

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
                  AdminBlockedUserAppealDetailsView(appealId: appeal.id),
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: kAdminSoftSurface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: kAdminPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            appeal.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: kAdminTextPrimary,
                              fontSize: 15.8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        AdminStatusChip(
                          status: appeal.normalizedStatus,
                          label: appeal.statusLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appeal.userEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kAdminTextSecondary,
                        fontSize: 13.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: kAdminSoftSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        appeal.messagePreview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kAdminTextPrimary,
                          fontSize: 13.2,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (appeal.blockedReason.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: kAdminDanger.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: kAdminDanger.withOpacity(0.14),
                          ),
                        ),
                        child: Text(
                          'Blocked reason: ${appeal.blockedReason}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kAdminDanger,
                            fontSize: 12.8,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AdminMetaPill(
                          label: appeal.createdAtLabel,
                          icon: Icons.schedule_rounded,
                        ),
                        if (appeal.warningCount != null)
                          AdminMetaPill(
                            label: 'Warnings: ${appeal.warningCount}',
                            icon: Icons.warning_amber_rounded,
                            color: kAdminWarning,
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

class AdminBlockedUserAppealDetailsView extends StatefulWidget {
  const AdminBlockedUserAppealDetailsView({
    super.key,
    required this.appealId,
  });

  final String appealId;

  @override
  State<AdminBlockedUserAppealDetailsView> createState() =>
      _AdminBlockedUserAppealDetailsViewState();
}

class _AdminBlockedUserAppealDetailsViewState
    extends State<AdminBlockedUserAppealDetailsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AppNotificationService _notificationService = AppNotificationService();

  bool _isUpdating = false;

  Future<void> _reviewAppeal({
    required String userId,
    required bool approveAppeal,
  }) async {
    final trimmedUserId = userId.trim();
    if (_isUpdating) return;

    if (trimmedUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This appeal is missing a user ID.')),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    final adminUid = (_auth.currentUser?.uid ?? '').trim();
    final appealRef = _firestore
        .collection('blocked_user_appeals')
        .doc(widget.appealId);
    final userRef = _firestore.collection('users').doc(trimmedUserId);

    try {
      final batch = _firestore.batch();

      if (approveAppeal) {
        batch.set(userRef, {
          'isBlocked': false,
          'warningCount': 0,
          'unblockedAt': FieldValue.serverTimestamp(),
          if (adminUid.isNotEmpty) 'unblockedBy': adminUid,
        }, SetOptions(merge: true));
      } else {
        batch.set(userRef, {
          'isBlocked': true,
        }, SetOptions(merge: true));
      }

      batch.set(appealRef, {
        'status': approveAppeal ? 'approved' : 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isReadByAdmin': true,
        if (adminUid.isNotEmpty) 'reviewedBy': adminUid,
      }, SetOptions(merge: true));

      await batch.commit();

      try {
        await _notificationService.createBlockedUserAppealDecisionNotification(
          appealId: widget.appealId,
          userId: trimmedUserId,
          approved: approveAppeal,
        );
      } catch (error) {
        debugPrint('Blocked user appeal decision notification error: $error');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              approveAppeal
                  ? 'Appeal approved and user unblocked.'
                  : 'Appeal rejected. User remains blocked.',
            ),
          ),
        );
    } catch (error) {
      debugPrint('Blocked user appeal review error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Failed to update the appeal.')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminBackground,
      appBar: AppBar(
        title: const Text('Appeal Details'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: kAdminPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('blocked_user_appeals')
              .doc(widget.appealId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AdminLoadingState();
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const AdminEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Appeal not found.',
                subtitle: 'This blocked user appeal is no longer available.',
              );
            }

            final appeal = _BlockedUserAppealDetailsData.fromDoc(snapshot.data!);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isUpdating)
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
                    title: 'Appeal Summary',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            AdminStatusChip(
                              status: appeal.normalizedStatus,
                              label: appeal.statusLabel,
                            ),
                            AdminMetaPill(
                              label: appeal.createdAtLabel,
                              icon: Icons.schedule_rounded,
                            ),
                            if (appeal.warningCount != null)
                              AdminMetaPill(
                                label: 'Warnings: ${appeal.warningCount}',
                                icon: Icons.warning_amber_rounded,
                                color: kAdminWarning,
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AdminInfoPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AdminKeyValueRow(
                                label: 'Status',
                                value: appeal.statusLabel,
                              ),
                              AdminKeyValueRow(
                                label: 'Created',
                                value: appeal.createdAtLabel,
                              ),
                              AdminKeyValueRow(
                                label: 'Warning Count',
                                value: appeal.warningCount?.toString() ?? '-',
                              ),
                              AdminKeyValueRow(
                                label: 'Updated',
                                value: appeal.updatedAtLabel,
                              ),
                              AdminKeyValueRow(
                                label: 'Read by Admin',
                                value: appeal.isReadByAdmin ? 'Yes' : 'No',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AdminSectionCard(
                    title: 'User Details',
                    child: AdminInfoPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdminKeyValueRow(
                            label: 'Name',
                            value: appeal.userName,
                          ),
                          AdminKeyValueRow(
                            label: 'Email',
                            value: appeal.userEmail,
                          ),
                          AdminKeyValueRow(
                            label: 'User ID',
                            value: appeal.userId,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AdminSectionCard(
                    title: 'Blocked Reason',
                    child: AdminInfoPanel(
                      child: Text(
                        appeal.blockedReason.isEmpty
                            ? 'No blocked reason recorded.'
                            : appeal.blockedReason,
                        style: const TextStyle(
                          color: kAdminTextPrimary,
                          fontSize: 13.5,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AdminSectionCard(
                    title: 'Appeal Message',
                    child: AdminInfoPanel(
                      child: Text(
                        appeal.message,
                        style: const TextStyle(
                          color: kAdminTextPrimary,
                          fontSize: 13.5,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AdminSectionCard(
                    title: 'Actions',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (appeal.normalizedStatus != 'pending')
                          AdminInfoPanel(
                            child: Text(
                              appeal.normalizedStatus == 'approved'
                                  ? 'This appeal has already been approved and the user has been unblocked.'
                                  : 'This appeal has already been rejected and the user remains blocked.',
                              style: const TextStyle(
                                color: kAdminTextSecondary,
                                height: 1.45,
                              ),
                            ),
                          )
                        else
                          const Text(
                            'Review this appeal and decide whether the user should remain blocked or be unblocked.',
                            style: TextStyle(
                              color: kAdminTextSecondary,
                              height: 1.45,
                            ),
                          ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                _isUpdating || appeal.normalizedStatus != 'pending'
                                ? null
                                : () => _reviewAppeal(
                                    userId: appeal.userId,
                                    approveAppeal: false,
                                  ),
                            style: adminOutlinedButtonStyle(color: kAdminDanger),
                            icon: const Icon(Icons.block_rounded, size: 18),
                            label: const Text(
                              'Keep Blocked / Reject Appeal',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _isUpdating || appeal.normalizedStatus != 'pending'
                                ? null
                                : () => _reviewAppeal(
                                    userId: appeal.userId,
                                    approveAppeal: true,
                                  ),
                            style: adminFilledButtonStyle(
                              backgroundColor: kAdminSuccess,
                            ),
                            icon: const Icon(Icons.lock_open_rounded, size: 18),
                            label: const Text(
                              'Unblock User / Approve Appeal',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
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
      ),
    );
  }
}

class _BlockedUserAppealCardData {
  const _BlockedUserAppealCardData({
    required this.id,
    required this.userName,
    required this.userEmail,
    required this.messagePreview,
    required this.statusLabel,
    required this.normalizedStatus,
    required this.createdAtLabel,
    required this.warningCount,
    required this.blockedReason,
  });

  final String id;
  final String userName;
  final String userEmail;
  final String messagePreview;
  final String statusLabel;
  final String normalizedStatus;
  final String createdAtLabel;
  final int? warningCount;
  final String blockedReason;

  factory _BlockedUserAppealCardData.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawStatus = _firstFilled([data['status'], 'pending']);

    return _BlockedUserAppealCardData(
      id: doc.id,
      userName: _firstFilled([data['userName'], 'Unknown User']),
      userEmail: _firstFilled([data['userEmail'], '-']),
      messagePreview: _firstFilled([
        data['message'],
        'No appeal message provided.',
      ]),
      statusLabel: adminStatusLabel(rawStatus),
      normalizedStatus: rawStatus.toLowerCase().replaceAll(' ', '_'),
      createdAtLabel: _formatCreatedAt(data['createdAt']),
      warningCount: _intOrNull(data['warningCount']),
      blockedReason: _firstFilled([data['blockedReason']]),
    );
  }
}

class _BlockedUserAppealDetailsData {
  const _BlockedUserAppealDetailsData({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.message,
    required this.statusLabel,
    required this.normalizedStatus,
    required this.createdAtLabel,
    required this.updatedAtLabel,
    required this.warningCount,
    required this.blockedReason,
    required this.isReadByAdmin,
  });

  final String userId;
  final String userName;
  final String userEmail;
  final String message;
  final String statusLabel;
  final String normalizedStatus;
  final String createdAtLabel;
  final String updatedAtLabel;
  final int? warningCount;
  final String blockedReason;
  final bool isReadByAdmin;

  factory _BlockedUserAppealDetailsData.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawStatus = _firstFilled([data['status'], 'pending']);

    return _BlockedUserAppealDetailsData(
      userId: _firstFilled([data['userId'], '-']),
      userName: _firstFilled([data['userName'], 'Unknown User']),
      userEmail: _firstFilled([data['userEmail'], '-']),
      message: _firstFilled([data['message'], 'No appeal message provided.']),
      statusLabel: adminStatusLabel(rawStatus),
      normalizedStatus: rawStatus.toLowerCase().replaceAll(' ', '_'),
      createdAtLabel: _formatCreatedAt(data['createdAt']),
      updatedAtLabel: _formatCreatedAt(data['updatedAt']),
      warningCount: _intOrNull(data['warningCount']),
      blockedReason: _firstFilled([data['blockedReason']]),
      isReadByAdmin: data['isReadByAdmin'] == true,
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

int? _intOrNull(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString().trim());
}
