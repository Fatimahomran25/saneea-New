import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../controlles/admin_reports_controller.dart';
import 'admin_ui.dart';

class AdminContractReviewDetailsView extends StatefulWidget {
  const AdminContractReviewDetailsView({
    super.key,
    required this.reviewId,
  });

  final String reviewId;

  @override
  State<AdminContractReviewDetailsView> createState() =>
      _AdminContractReviewDetailsViewState();
}

class _AdminContractReviewDetailsViewState
    extends State<AdminContractReviewDetailsView> {
  final AdminReportsController _reportsController = AdminReportsController();
  late Future<_ContractReviewDetailsData> _detailsFuture;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadDetails();
  }

  Future<_ContractReviewDetailsData> _loadDetails() async {
    final reviewDoc = await FirebaseFirestore.instance
        .collection('contract_reports')
        .doc(widget.reviewId)
        .get();

    final reviewData = reviewDoc.data();
    if (!reviewDoc.exists || reviewData == null) {
      throw Exception('Contract review not found.');
    }

    final reporterId = _firstFilled([
      reviewData['reporterId'],
      reviewData['reporterUserId'],
    ]);
    final otherPartyId = _firstFilled([
      reviewData['otherPartyId'],
      reviewData['otherUserId'],
      reviewData['reportedUserId'],
    ]);

    Map<String, dynamic>? reporterProfile;
    Map<String, dynamic>? otherPartyProfile;

    if (reporterId.isNotEmpty) {
      final reporterDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(reporterId)
          .get();
      reporterProfile = reporterDoc.data();
    }

    if (otherPartyId.isNotEmpty) {
      final otherPartyDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherPartyId)
          .get();
      otherPartyProfile = otherPartyDoc.data();
    }

    return _ContractReviewDetailsData(
      reviewId: reviewDoc.id,
      reviewData: reviewData,
      reporterProfile: reporterProfile,
      otherPartyProfile: otherPartyProfile,
    );
  }

  void _refresh() {
    setState(() {
      _detailsFuture = _loadDetails();
    });
  }

  Future<void> _updateStatus(String status) async {
    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('contract_reports')
          .doc(widget.reviewId)
          .set({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'under_review'
                ? 'Contract review marked under review.'
                : status == 'dismissed'
                ? 'Contract review marked dismissed.'
                : 'Contract review marked resolved.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isUpdatingStatus = false;
      });
    }
  }

  Future<void> _showAdminTerminateContractDialog() async {
    final noteController = TextEditingController();
    final note = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Admin Terminate Contract'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will administratively end the contract without using any termination payment flow.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Optional admin decision note',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: kAdminSoftSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(color: kAdminBorder),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(color: kAdminPrimary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, noteController.text.trim());
              },
              child: const Text(
                'Confirm Termination',
                style: TextStyle(color: kAdminDanger),
              ),
            ),
          ],
        );
      },
    );
    noteController.dispose();

    if (note == null) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      await _reportsController.adminTerminateContractReview(
        reviewId: widget.reviewId,
        adminDecisionNote: note,
      );

      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Contract was admin terminated without using payment flow.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isUpdatingStatus = false;
      });
    }
  }


Future<void> _showAdminActionsSheet({
  required bool isAdminTerminated,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true, // FIX
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.90,
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
                      'Choose how you want to manage this contract review.',
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
                      title: 'Mark Under Review',
                      subtitle: 'Move the case into active review.',
                      enabled: !_isUpdatingStatus,
                      onTap: _isUpdatingStatus
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              _updateStatus('under_review');
                            },
                    ),
                    const Divider(height: 20, color: kAdminBorder),
                    AdminActionSheetTile(
                      icon: Icons.do_disturb_alt_outlined,
                      iconColor: kAdminMuted,
                      title: 'Dismiss / Invalid',
                      subtitle: 'Close this review as dismissed or invalid.',
                      enabled: !_isUpdatingStatus,
                      onTap: _isUpdatingStatus
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              _updateStatus('dismissed');
                            },
                    ),
                    const Divider(height: 20, color: kAdminBorder),
                    AdminActionSheetTile(
                      icon: Icons.task_alt_rounded,
                      iconColor: kAdminSuccess,
                      title: 'Mark Resolved',
                      subtitle: 'Resolve the contract review case.',
                      enabled: !_isUpdatingStatus,
                      onTap: _isUpdatingStatus
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              _updateStatus('resolved');
                            },
                    ),
                    const Divider(height: 20, color: kAdminBorder),
                    AdminActionSheetTile(
                      icon: Icons.gavel_rounded,
                      iconColor: kAdminDanger,
                      title: isAdminTerminated
                          ? 'Contract Admin Terminated'
                          : 'Admin Terminate Contract',
                      subtitle: isAdminTerminated
                          ? 'This contract has already been admin terminated.'
                          : 'End the contract without using the payment flow.',
                      enabled: !_isUpdatingStatus && !isAdminTerminated,
                      onTap: _isUpdatingStatus || isAdminTerminated
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              _showAdminTerminateContractDialog();
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



  void _openUserProfile({
    required String title,
    required String name,
    required String email,
    required String accountType,
    required String photoUrl,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminBackground,
      appBar: AppBar(
        title: const Text(
          'Contract Review Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: kAdminPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: FutureBuilder<_ContractReviewDetailsData>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AdminLoadingState();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const AdminEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Failed to load contract review details.',
              subtitle: 'Please try again to view this contract review.',
            );
          }

          final details = snapshot.data!;
          final review = details.reviewData;

          final reporterName = _firstFilled([
            review['reporterName'],
            review['reporterUserName'],
            _displayName(details.reporterProfile),
            'Unknown Reporter',
          ]);
          final otherPartyName = _firstFilled([
            review['otherPartyName'],
            review['otherUserName'],
            review['reportedUserName'],
            _displayName(details.otherPartyProfile),
            'Unknown User',
          ]);
          final reporterEmail = _firstFilled([
            details.reporterProfile?['email'],
          ]);
          final otherPartyEmail = _firstFilled([
            details.otherPartyProfile?['email'],
          ]);
          final reporterAccountType = _firstFilled([
            details.reporterProfile?['accountType'],
          ]);
          final otherPartyAccountType = _firstFilled([
            details.otherPartyProfile?['accountType'],
          ]);
          final reporterAccountTypeLabel = reporterAccountType.isEmpty
              ? ''
              : adminStatusLabel(reporterAccountType);
          final otherPartyAccountTypeLabel = otherPartyAccountType.isEmpty
              ? ''
              : adminStatusLabel(otherPartyAccountType);
          final reporterPhotoUrl = _firstFilled([
            details.reporterProfile?['photoUrl'],
            details.reporterProfile?['profile'],
          ]);
          final otherPartyPhotoUrl = _firstFilled([
            details.otherPartyProfile?['photoUrl'],
            details.otherPartyProfile?['profile'],
          ]);
          final reasonLabel = _firstFilled([
            review['reasonLabel'],
            review['reason'],
            review['reasonType'],
            'No reason provided',
          ]);
          final reasonType = _firstFilled([
            review['reasonType'],
          ]);
          final description = _firstFilled([
            review['details'],
            review['description'],
            review['text'],
            'No details provided.',
          ]);
          final statusRaw = _firstFilled([
            review['status'],
            'requested',
          ]);
          final contractStatusRaw = _firstFilled([
            review['contractStatus'],
          ]);
          final createdAt = _formatDateTime(review['createdAt']);
          final amount = _firstFilled([
            review['amount'],
            review['contractAmount'],
            review['paymentAmount'],
            review['price'],
            review['budget'],
            review['totalAmount'],
          ]);
          final deadline = _firstFormattedValue([
            review['deadline'],
            review['dueDate'],
            review['deliveryDeadline'],
            review['contractDeadline'],
            review['endDate'],
          ]);
          final serviceDescription = _firstFilled([
            review['serviceDescription'],
            review['serviceTitle'],
            review['requestDescription'],
            review['requestTitle'],
            review['serviceName'],
            review['gigTitle'],
          ]);
          final deliveredItems = _extractPreviewItems([
            review['deliveredWork'],
            review['deliveredFiles'],
            review['deliveryFiles'],
            review['deliveredImages'],
            review['attachments'],
            review['files'],
            review['imageUrls'],
            review['workFiles'],
            review['workLinks'],
            review['deliveryUrls'],
          ]);
          final chatPreview = _extractChatPreview([
            review['chatMessages'],
            review['messages'],
            review['chatPreview'],
            review['messagePreview'],
            review['chatMessagesPreview'],
          ]);
          final hasContractInformation =
              _firstFilled([review['requestId']]).isNotEmpty ||
              _firstFilled([review['contractId']]).isNotEmpty;
          final hasChatAvailable = _firstFilled([review['chatId']]).isNotEmpty;
          final isAdminTerminated =
              contractStatusRaw.trim().toLowerCase() == 'admin_terminated';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isUpdatingStatus)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: const LinearProgressIndicator(
                        minHeight: 4,
                        color: kAdminPrimary,
                        backgroundColor: kAdminBorder,
                      ),
                    ),
                  ),
                AdminSectionCard(
                  title: 'Review Summary',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryReasonCard(
                        title: reasonLabel,
                        reasonType: reasonType,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          AdminStatusChip(status: statusRaw),
                          if (contractStatusRaw.isNotEmpty)
                            AdminStatusChip(
                              status: contractStatusRaw,
                              label:
                                  'Contract: ${adminStatusLabel(contractStatusRaw)}',
                            ),
                          AdminMetaPill(
                            label: createdAt,
                            icon: Icons.schedule_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ContentBlock(
                        title: 'Details',
                        child: Text(
                          description,
                          style: const TextStyle(
                            color: kAdminTextPrimary,
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                        ),
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
                  title: 'Other Party',
                  child: AdminProfilePreviewCard(
                    name: otherPartyName,
                    email: otherPartyEmail,
                    accountType: otherPartyAccountTypeLabel,
                    photoUrl: otherPartyPhotoUrl,
                    onTap: () => _openUserProfile(
                      title: 'Other Party Profile',
                      name: otherPartyName,
                      email: otherPartyEmail,
                      accountType: otherPartyAccountTypeLabel,
                      photoUrl: otherPartyPhotoUrl,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Contract Summary',
                  child: amount.isEmpty &&
                          deadline.isEmpty &&
                          serviceDescription.isEmpty
                      ? _EmptyPreviewCard(
                          icon: Icons.description_outlined,
                          title: hasContractInformation
                              ? 'Contract information available.'
                              : 'No contract summary details.',
                          description: hasContractInformation
                              ? 'Relevant contract references exist internally, but only readable summary fields are shown here.'
                              : 'No additional contract summary details are available for this review.',
                        )
                      : AdminInfoPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (amount.isNotEmpty)
                                AdminKeyValueRow(label: 'Amount', value: amount),
                              if (deadline.isNotEmpty)
                                AdminKeyValueRow(
                                  label: 'Deadline',
                                  value: deadline,
                                ),
                              if (serviceDescription.isNotEmpty)
                                AdminKeyValueRow(
                                  label: 'Service',
                                  value: serviceDescription,
                                ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Delivered Work',
                  child: deliveredItems.isEmpty
                      ? const _EmptyPreviewCard(
                          icon: Icons.inventory_2_outlined,
                          title: 'No delivered work yet.',
                          description:
                              'Delivered work will appear here when files, links, or images are available.',
                        )
                      : Column(
                          children: deliveredItems
                              .take(6)
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _PreviewItemTile(
                                    icon: _previewIconForValue(item),
                                    text: item,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Chat Preview',
                  child: chatPreview.isEmpty
                      ? _EmptyPreviewCard(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: hasChatAvailable
                              ? 'Chat available.'
                              : 'No chat preview yet.',
                          description: hasChatAvailable
                              ? 'Chat data exists internally, but preview messages are not shown in this summary.'
                              : 'Messages will appear here if they are included with the review data.',
                        )
                      : Column(
                          children: chatPreview
                              .take(4)
                              .map(
                                (message) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _PreviewItemTile(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    text: message,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Admin Actions',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Open the action menu to manage this contract review.',
                        style: TextStyle(
                          color: kAdminTextSecondary,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      AdminActionMenuButton(
                        label: 'Admin Actions',
                        onPressed: _isUpdatingStatus
                            ? null
                            : () => _showAdminActionsSheet(
                                  isAdminTerminated: isAdminTerminated,
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

class _PreviewItemTile extends StatelessWidget {
  const _PreviewItemTile({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAdminSoftSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: kAdminPrimary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: kAdminTextPrimary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryReasonCard extends StatelessWidget {
  const _SummaryReasonCard({
    required this.title,
    required this.reasonType,
  });

  final String title;
  final String reasonType;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSoftSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
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
            title,
            style: const TextStyle(
              color: kAdminTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          if (reasonType.isNotEmpty) ...[
            const SizedBox(height: 12),
            AdminMetaPill(
              label: adminStatusLabel(reasonType),
              icon: Icons.label_outline_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class _ContentBlock extends StatelessWidget {
  const _ContentBlock({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: kAdminPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        AdminInfoPanel(child: child),
      ],
    );
  }
}

class _EmptyPreviewCard extends StatelessWidget {
  const _EmptyPreviewCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSoftSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: kAdminPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: kAdminTextPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: kAdminTextSecondary,
                    fontSize: 12.8,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractReviewDetailsData {
  const _ContractReviewDetailsData({
    required this.reviewId,
    required this.reviewData,
    required this.reporterProfile,
    required this.otherPartyProfile,
  });

  final String reviewId;
  final Map<String, dynamic> reviewData;
  final Map<String, dynamic>? reporterProfile;
  final Map<String, dynamic>? otherPartyProfile;
}

String _firstFilled(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _displayName(Map<String, dynamic>? data) {
  if (data == null) return '';

  final firstName = (data['firstName'] ?? '').toString().trim();
  final lastName = (data['lastName'] ?? '').toString().trim();
  final fullName = '$firstName $lastName'.trim();

  return _firstFilled([
    data['name'],
    fullName,
  ]);
}

String _formatDateTime(dynamic value) {
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

String _firstFormattedValue(List<dynamic> values) {
  for (final value in values) {
    final text = _formatFlexibleValue(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _formatFlexibleValue(dynamic value) {
  if (value == null) return '';

  if (value is Timestamp || value is DateTime) {
    return _formatDateTime(value);
  }

  final text = value.toString().trim();
  if (text.isEmpty) return '';

  final parsed = DateTime.tryParse(text);
  if (parsed != null) {
    return _formatDateTime(parsed);
  }

  return text;
}

List<String> _extractPreviewItems(List<dynamic> sources) {
  final results = <String>[];

  void addValue(dynamic value) {
    if (value == null) return;

    if (value is Iterable) {
      for (final item in value) {
        addValue(item);
      }
      return;
    }

    if (value is Map) {
      final text = _firstFilled([
        value['name'],
        value['fileName'],
        value['title'],
        value['label'],
        value['url'],
        value['downloadUrl'],
        value['path'],
        value['message'],
        value['text'],
      ]);
      if (text.isNotEmpty) {
        results.add(text);
      }
      return;
    }

    final text = value.toString().trim();
    if (text.isNotEmpty) {
      results.add(text);
    }
  }

  for (final source in sources) {
    addValue(source);
  }

  return _dedupeStrings(results);
}

List<String> _extractChatPreview(List<dynamic> sources) {
  final results = <String>[];

  void addValue(dynamic value) {
    if (value == null) return;

    if (value is Iterable) {
      for (final item in value) {
        addValue(item);
      }
      return;
    }

    if (value is Map) {
      final sender = _firstFilled([
        value['senderName'],
        value['userName'],
        value['name'],
        value['role'],
      ]);
      final body = _firstFilled([
        value['message'],
        value['text'],
        value['content'],
        value['body'],
      ]);
      final text = sender.isNotEmpty && body.isNotEmpty
          ? '$sender: $body'
          : _firstFilled([
              body,
              sender,
              value['preview'],
            ]);

      if (text.isNotEmpty) {
        results.add(text);
      }
      return;
    }

    final text = value.toString().trim();
    if (text.isNotEmpty) {
      results.add(text);
    }
  }

  for (final source in sources) {
    addValue(source);
  }

  return _dedupeStrings(results);
}

List<String> _dedupeStrings(List<String> values) {
  final seen = <String>{};
  final result = <String>[];

  for (final value in values) {
    if (seen.add(value)) {
      result.add(value);
    }
  }

  return result;
}

IconData _previewIconForValue(String value) {
  final lower = value.toLowerCase();

  if (lower.contains('.png') ||
      lower.contains('.jpg') ||
      lower.contains('.jpeg') ||
      lower.contains('.gif') ||
      lower.contains('.webp')) {
    return Icons.image_outlined;
  }

  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return Icons.link_rounded;
  }

  return Icons.attach_file_rounded;
}

String _friendlyError(Object error) {
  return error.toString().replaceFirst('Exception: ', '').trim();
}
