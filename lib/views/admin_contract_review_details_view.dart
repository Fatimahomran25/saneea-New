import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controlles/admin_reports_controller.dart';
import '../models/contract_model.dart';
import 'admin_ui.dart';
import 'chat_view.dart';
import 'client_profile.dart';
import 'contract_details_screen.dart';
import 'freelancer_profile.dart';

class AdminContractReviewDetailsView extends StatefulWidget {
  const AdminContractReviewDetailsView({super.key, required this.reviewId});

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
    final firestore = FirebaseFirestore.instance;

    final reviewDoc = await firestore
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

    final reviewContractId = _firstFilled([reviewData['contractId']]);

    final reviewRequestId = _firstFilled([reviewData['requestId']]);

    final reviewChatId = _firstFilled([reviewData['chatId']]);

    final reviewClientId = _firstFilled([reviewData['clientId']]);

    final reviewFreelancerId = _firstFilled([reviewData['freelancerId']]);

    final userCache = <String, Map<String, dynamic>?>{};

    final reporterProfile = await _loadUserProfile(
      firestore: firestore,
      userId: reporterId,
      cache: userCache,
    );

    final otherPartyProfile = await _loadUserProfile(
      firestore: firestore,
      userId: otherPartyId,
      cache: userCache,
    );

    final contractDoc = reviewContractId.isEmpty
        ? null
        : await firestore.collection('contracts').doc(reviewContractId).get();

    final contractDocData = contractDoc?.data();

    final linkedRequestId = _firstFilled([
      reviewRequestId,
      contractDocData?['requestId'],
    ]);

    final requestLookup = await _findRelatedRequestDoc(
      firestore: firestore,
      contractId: reviewContractId,
      requestId: linkedRequestId,
    );

    final requestData = requestLookup?.data;
    final resolvedRequestId = requestLookup?.id ?? linkedRequestId;

    final resolvedChatId = _firstFilled([
      reviewChatId,
      requestData?['chatId'],
      contractDocData?['chatId'],
    ]);

    final chatDoc = resolvedChatId.isEmpty
        ? null
        : await firestore.collection('chat').doc(resolvedChatId).get();

    final chatData = chatDoc?.data();

    final contractData = _firstNonEmptyMap([
      reviewData['contractData'],
      requestData?['contractData'],
      chatData?['contractData'],
      contractDocData?['contractData'],
      _looksLikeContractData(contractDocData) ? contractDocData : null,
    ]);

    final contractMeta = _asMap(contractData?['meta']);
    final contractPayment = _asMap(contractData?['payment']);

    final resolvedContractId = _firstFilled([
      reviewContractId,
      requestData?['contractId'],
      contractData?['contractId'],
      contractMeta['contractId'],
    ]);

    final resolvedClientId = _firstFilled([
      reviewClientId,
      requestData?['clientId'],
      chatData?['clientId'],
      contractDocData?['clientId'],
    ]);

    final resolvedFreelancerId = _firstFilled([
      reviewFreelancerId,
      requestData?['freelancerId'],
      chatData?['freelancerId'],
      contractDocData?['freelancerId'],
    ]);

    final clientProfile = await _loadUserProfile(
      firestore: firestore,
      userId: resolvedClientId,
      cache: userCache,
    );

    final freelancerProfile = await _loadUserProfile(
      firestore: firestore,
      userId: resolvedFreelancerId,
      cache: userCache,
    );

    final clientName = _firstFilled([
      contractData?['clientName'],
      _asMap(contractData?['parties'])['clientName'],
      requestData?['clientName'],
      _displayName(clientProfile),
    ]);

    final freelancerName = _firstFilled([
      contractData?['freelancerName'],
      _asMap(contractData?['parties'])['freelancerName'],
      requestData?['freelancerName'],
      _displayName(freelancerProfile),
    ]);

    final synthesizedRequestData = _buildContractRequestData(
      contractId: resolvedContractId,
      requestId: resolvedRequestId,
      chatId: resolvedChatId,
      reviewData: reviewData,
      requestData: requestData,
      contractData: contractData,
      clientId: resolvedClientId,
      freelancerId: resolvedFreelancerId,
      clientName: clientName,
      freelancerName: freelancerName,
    );

    final contractViewData = synthesizedRequestData == null
        ? null
        : GeneratedContract.fromRequest(
            requestId: resolvedRequestId.isEmpty
                ? widget.reviewId
                : resolvedRequestId,
            requestData: synthesizedRequestData,
            userRole: resolvedClientId.isNotEmpty ? 'client' : 'freelancer',
            otherUserData: resolvedClientId.isNotEmpty
                ? freelancerProfile
                : clientProfile,
          );

    final contractFileUrl = _firstFilled([
      reviewData['contractFileUrl'],
      reviewData['contractUrl'],
      reviewData['pdfUrl'],
      requestData?['contractFileUrl'],
      requestData?['contractUrl'],
      requestData?['pdfUrl'],
      contractDocData?['contractFileUrl'],
      contractDocData?['contractUrl'],
      contractDocData?['pdfUrl'],
      contractData?['contractFileUrl'],
      contractData?['contractUrl'],
      contractData?['pdfUrl'],
      contractMeta['contractFileUrl'],
      contractMeta['contractUrl'],
      contractMeta['pdfUrl'],
      contractPayment['invoiceUrl'],
      contractPayment['receiptUrl'],
    ]);

    return _ContractReviewDetailsData(
      reviewId: reviewDoc.id,
      reviewData: reviewData,
      reporterUserId: reporterId,
      otherPartyUserId: otherPartyId,
      reporterProfile: reporterProfile,
      otherPartyProfile: otherPartyProfile,
      contractId: resolvedContractId,
      requestId: resolvedRequestId,
      chatId: resolvedChatId,
      clientUserId: resolvedClientId,
      freelancerUserId: resolvedFreelancerId,
      clientProfile: clientProfile,
      freelancerProfile: freelancerProfile,
      requestData: requestData,
      contractData: contractData,
      chatData: chatData,
      contractFileUrl: contractFileUrl,
      contractViewData: contractViewData,
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    } finally {
      if (!mounted) return;

      setState(() {
        _isUpdatingStatus = false;
      });
    }
  }

  Future<void> _removeReport() async {
    final shouldRemove = await _showRemoveReportDialog();
    if (!shouldRemove || !mounted) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      await _reportsController.softDeleteContractReview(reviewId: widget.reviewId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report removed from admin list.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    } finally {
      if (!mounted) return;

      setState(() {
        _isUpdatingStatus = false;
      });
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    } finally {
      if (!mounted) return;

      setState(() {
        _isUpdatingStatus = false;
      });
    }
  }

  Future<void> _showReviewStatusSheet() async {
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
                        'Update Review Status',
                        style: TextStyle(
                          color: kAdminPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Choose a new status for this contract review.',
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
                        icon: Icons.task_alt_rounded,
                        iconColor: kAdminSuccess,
                        title: 'Mark as Resolved',
                        subtitle: 'Resolve the contract review case.',
                        enabled: !_isUpdatingStatus,
                        onTap: _isUpdatingStatus
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                _updateStatus('resolved');
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

  Future<void> _showAdminActionsSheet({required bool isAdminTerminated}) async {
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
            initialChildSize: 0.54,
            minChildSize: 0.34,
            maxChildSize: 0.78,
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
                      const Text(
                        'Review Actions',
                        style: TextStyle(
                          color: kAdminTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
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
                      const Divider(height: 28, color: kAdminBorder),
                      const Text(
                        'Contract Actions',
                        style: TextStyle(
                          color: kAdminTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
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
    required String userId,
    required String name,
    required String email,
    required String accountType,
    required String accountTypeLabel,
    required String photoUrl,
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

  Future<Map<String, dynamic>?> _loadUserProfile({
    required FirebaseFirestore firestore,
    required String userId,
    required Map<String, Map<String, dynamic>?> cache,
  }) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return null;
    }

    if (cache.containsKey(normalizedUserId)) {
      return cache[normalizedUserId];
    }

    final doc = await firestore.collection('users').doc(normalizedUserId).get();
    final data = doc.data();

    cache[normalizedUserId] = data;

    return data;
  }

  Future<_ContractRequestDoc?> _findRelatedRequestDoc({
    required FirebaseFirestore firestore,
    required String contractId,
    required String requestId,
  }) async {
    final candidateIds = <String>[
      contractId,
      requestId,
    ].where((id) => id.trim().isNotEmpty).toSet();

    for (final id in candidateIds) {
      final doc = await firestore.collection('requests').doc(id).get();
      final data = doc.data();

      if (data != null) {
        return _ContractRequestDoc(id: doc.id, data: data);
      }
    }

    if (contractId.trim().isEmpty) {
      return null;
    }

    for (final field in const [
      'contractId',
      'contractData.contractId',
      'contractData.meta.contractId',
    ]) {
      final snapshot = await firestore
          .collection('requests')
          .where(field, isEqualTo: contractId.trim())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return _ContractRequestDoc(id: doc.id, data: doc.data());
      }
    }

    return null;
  }

  Map<String, dynamic>? _buildContractRequestData({
    required String contractId,
    required String requestId,
    required String chatId,
    required Map<String, dynamic> reviewData,
    required Map<String, dynamic>? requestData,
    required Map<String, dynamic>? contractData,
    required String clientId,
    required String freelancerId,
    required String clientName,
    required String freelancerName,
  }) {
    final hasBaseData =
        contractId.trim().isNotEmpty ||
        requestId.trim().isNotEmpty ||
        chatId.trim().isNotEmpty ||
        (requestData?.isNotEmpty ?? false) ||
        (contractData?.isNotEmpty ?? false);

    if (!hasBaseData) {
      return null;
    }

    final synthesized = <String, dynamic>{
      ...?requestData,
      'clientId': clientId,
      'freelancerId': freelancerId,
      'clientName': clientName,
      'freelancerName': freelancerName,
    };

    if (chatId.trim().isNotEmpty) {
      synthesized['chatId'] = chatId.trim();
    }

    if (contractId.trim().isNotEmpty) {
      synthesized['contractId'] = contractId.trim();
    }

    if (contractData != null && contractData.isNotEmpty) {
      synthesized['contractData'] = contractData;
    }

    final mergedDescription = _firstFilled([
      reviewData['serviceDescription'],
      reviewData['serviceTitle'],
      requestData?['description'],
      _asMap(contractData?['service'])['description'],
    ]);

    if (mergedDescription.isNotEmpty) {
      synthesized['description'] = mergedDescription;
    }

    final mergedBudget = _firstFilled([
      reviewData['amount'],
      reviewData['contractAmount'],
      requestData?['budget'],
      _asMap(contractData?['payment'])['amount'],
    ]);

    if (mergedBudget.isNotEmpty) {
      synthesized['budget'] = mergedBudget;
    }

    final mergedCurrency = _firstFilled([
      requestData?['currency'],
      _asMap(contractData?['payment'])['currency'],
      'SAR',
    ]);

    if (mergedCurrency.isNotEmpty) {
      synthesized['currency'] = mergedCurrency;
    }

    final createdAt = _firstNonNull([
      requestData?['createdAt'],
      reviewData['createdAt'],
      _asMap(contractData?['meta'])['createdAt'],
      _asMap(contractData?['meta'])['createdAtIso'],
      contractData?['createdAt'],
    ]);

    if (createdAt != null) {
      synthesized['createdAt'] = createdAt;
    }

    final updatedAt = _firstNonNull([
      requestData?['updatedAt'],
      reviewData['updatedAt'],
      contractData?['updatedAt'],
    ]);

    if (updatedAt != null) {
      synthesized['updatedAt'] = updatedAt;
    }

    return synthesized;
  }

  Future<void> _openContractFileOrViewer(
    _ContractReviewDetailsData details,
  ) async {
    final contractFileUrl = details.contractFileUrl.trim();

    if (contractFileUrl.isNotEmpty) {
      await _launchExternalUrl(
        contractFileUrl,
        unavailableMessage: 'Contract file is not available.',
      );
      return;
    }

    final contract = details.contractViewData;

    if (contract != null) {
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ContractDetailsScreen(contract: contract, readOnlyMode: true),
        ),
      );
      return;
    }

    _showPageMessage('Contract file is not available.');
  }

  void _openReadOnlyChat(_ContractReviewDetailsData details) {
    if (details.chatId.trim().isEmpty) {
      _showPageMessage('No chat is available for this contract.');
      return;
    }

    final clientName = _firstFilled([
      details.contractViewData?.clientName,
      _displayName(details.clientProfile),
      'Client',
    ]);

    final freelancerName = _firstFilled([
      details.contractViewData?.freelancerName,
      _displayName(details.freelancerProfile),
      'Freelancer',
    ]);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatView(
          chatId: details.chatId,
          otherUserName: '',
          otherUserId: '',
          otherUserRole: '',
          adminReadOnlyMode: true,
          adminClientId: details.clientUserId,
          adminClientName: clientName,
          adminFreelancerId: details.freelancerUserId,
          adminFreelancerName: freelancerName,
        ),
      ),
    );
  }

  Future<void> _launchExternalUrl(
    String rawUrl, {
    required String unavailableMessage,
  }) async {
    final normalizedUrl = rawUrl.trim();
    final uri = Uri.tryParse(normalizedUrl);

    if (uri == null || (!uri.hasScheme && !normalizedUrl.startsWith('www.'))) {
      _showPageMessage(unavailableMessage);
      return;
    }

    final launchUri = uri.hasScheme ? uri : Uri.parse('https://$normalizedUrl');

    try {
      final opened = await launchUrl(launchUri);

      if (!opened) {
        _showPageMessage(unavailableMessage);
      }
    } catch (_) {
      _showPageMessage(unavailableMessage);
    }
  }

  void _showPageMessage(String message) {
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
          'Contract Review Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: kAdminPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isUpdatingStatus ? null : _showReviewStatusSheet,
            tooltip: 'Update Review Status',
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

          final reporterUserId = details.reporterUserId;
          final otherPartyUserId = details.otherPartyUserId;

          final reasonLabel = _firstFilled([
            review['reasonLabel'],
            review['reason'],
            review['reasonType'],
            'No reason provided',
          ]);

          final description = _firstFilled([
            review['details'],
            review['description'],
            review['text'],
            'No details provided.',
          ]);

          final statusRaw = _firstFilled([review['status'], 'requested']);

          final contractStatusRaw = _firstFilled([review['contractStatus']]);

          final createdAt = _formatDateTime(review['createdAt']);

          final contractViewData = details.contractViewData;
          final contractData = details.contractData;

          final contractMeta = _asMap(contractData?['meta']);
          final contractParties = _asMap(contractData?['parties']);
          final contractService = _asMap(contractData?['service']);
          final contractPayment = _asMap(contractData?['payment']);
          final contractApproval = _asMap(contractData?['approval']);
          final deliveryData = _asMap(contractData?['deliveryData']);

          final clientName = _firstFilled([
            contractViewData?.clientName,
            contractParties['clientName'],
            review['clientName'],
            _displayName(details.clientProfile),
            'Client',
          ]);

          final freelancerName = _firstFilled([
            contractViewData?.freelancerName,
            contractParties['freelancerName'],
            review['freelancerName'],
            _displayName(details.freelancerProfile),
            'Freelancer',
          ]);

          final contractTitle = _firstFilled([
            contractViewData?.title,
            contractMeta['title'],
            review['contractTitle'],
            review['serviceTitle'],
            review['requestTitle'],
            contractService['description'],
          ]);

          final serviceDescription = _firstFilled([
            contractViewData?.description,
            contractService['description'],
            review['serviceDescription'],
            review['requestDescription'],
            review['serviceName'],
            review['gigTitle'],
          ]);

          final contractAmount = contractViewData != null
              ? contractViewData.amountLabel
              : _displayOrDash(
                  _firstFilled([
                    review['amount'],
                    review['contractAmount'],
                    review['paymentAmount'],
                    review['price'],
                    review['budget'],
                    review['totalAmount'],
                    contractPayment['amount'],
                  ]),
                );

          final contractDeadline = contractViewData != null
              ? _displayOrDash(contractViewData.deadlineText)
              : _displayOrDash(
                  _firstFormattedValue([
                    review['deadline'],
                    review['dueDate'],
                    review['deliveryDeadline'],
                    review['contractDeadline'],
                    review['endDate'],
                    contractData?['deadline'],
                    _asMap(contractData?['timeline'])['deadline'],
                  ]),
                );

          final contractStatusLabel = contractViewData != null
              ? contractViewData.statusLabel
              : _displayOrDash(
                  _firstFilled([adminStatusLabel(contractStatusRaw)]),
                );

          final contractCreatedDate = contractViewData != null
              ? _displayOrDash(contractViewData.createdAtText)
              : _displayOrDash(
                  _firstFormattedValue([
                    contractMeta['createdAt'],
                    contractMeta['createdAtIso'],
                    details.requestData?['createdAt'],
                    review['createdAt'],
                  ]),
                );

          final clientApproved =
              contractViewData?.clientApproved ??
              _approvalFlag(contractApproval, const [
                'clientApproved',
                'clientApproval',
                'clientApprovalStatus',
                'clientDecision',
                'clientStatus',
                'clientSigned',
              ]);

          final freelancerApproved =
              contractViewData?.freelancerApproved ??
              _approvalFlag(contractApproval, const [
                'freelancerApproved',
                'freelancerApproval',
                'freelancerApprovalStatus',
                'freelancerDecision',
                'freelancerStatus',
                'freelancerSigned',
              ]);

          final deliveredWorkItems = _extractDeliveredWorkItems(
            review: review,
            deliveryData: deliveryData,
          );

          final deliveryStatusLabel = _displayOrDash(
            adminStatusLabel(
              _firstFilled([deliveryData['status'], review['deliveryStatus']]),
            ),
          );

          final deliverySubmittedAt = _firstFormattedValue([
            deliveryData['submittedAt'],
            review['submittedAt'],
          ]);

          final deliveryApprovedAt = _firstFormattedValue([
            deliveryData['approvedAt'],
            review['approvedAt'],
          ]);

          final finalWorkUploadedAt = _firstFormattedValue([
            deliveryData['finalWorkUploadedAt'],
          ]);

          final chatPreview = _extractChatPreview([
            review['chatMessages'],
            review['messages'],
            review['chatPreview'],
            review['messagePreview'],
            review['chatMessagesPreview'],
          ]);

          final hasContractInformation =
              contractViewData != null ||
              details.contractId.trim().isNotEmpty ||
              details.requestId.trim().isNotEmpty ||
              (contractData?.isNotEmpty ?? false);

          final hasChatAvailable = details.chatId.trim().isNotEmpty;

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
                      _SummaryReasonCard(title: reasonLabel),
                      const SizedBox(height: 12),
                      AdminInfoPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AdminKeyValueRow(
                              label: 'Status',
                              value: adminStatusLabel(statusRaw),
                            ),
                            if (contractStatusRaw.isNotEmpty)
                              AdminKeyValueRow(
                                label: 'Contract Status',
                                value: adminStatusLabel(contractStatusRaw),
                              ),
                            AdminKeyValueRow(
                              label: 'Created',
                              value: createdAt,
                            ),
                          ],
                        ),
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
                      userId: reporterUserId,
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
                  title: 'Other Party',
                  child: AdminProfilePreviewCard(
                    name: otherPartyName,
                    email: otherPartyEmail,
                    accountType: otherPartyAccountTypeLabel,
                    photoUrl: otherPartyPhotoUrl,
                    onTap: () => _openUserProfile(
                      title: 'Other Party Profile',
                      userId: otherPartyUserId,
                      name: otherPartyName,
                      email: otherPartyEmail,
                      accountType: otherPartyAccountType,
                      accountTypeLabel: otherPartyAccountTypeLabel,
                      photoUrl: otherPartyPhotoUrl,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                AdminSectionCard(
                  title: 'Contract Summary',
                  child: !hasContractInformation
                      ? _EmptyPreviewCard(
                          icon: Icons.description_outlined,
                          title: 'Contract details are not available.',
                          description:
                              'No contract document or readable contract data was found for this review.',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AdminInfoPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AdminKeyValueRow(
                                    label: 'Title',
                                    value: _displayOrDash(contractTitle),
                                  ),
                                  if (serviceDescription.isNotEmpty &&
                                      serviceDescription != contractTitle)
                                    AdminKeyValueRow(
                                      label: 'Service',
                                      value: serviceDescription,
                                    ),
                                  AdminKeyValueRow(
                                    label: 'Client',
                                    value: _displayOrDash(clientName),
                                  ),
                                  AdminKeyValueRow(
                                    label: 'Freelancer',
                                    value: _displayOrDash(freelancerName),
                                  ),
                                  AdminKeyValueRow(
                                    label: 'Amount',
                                    value: contractAmount,
                                  ),
                                  AdminKeyValueRow(
                                    label: 'Deadline',
                                    value: contractDeadline,
                                  ),
                                  AdminKeyValueRow(
                                    label: 'Status',
                                    value: contractStatusLabel,
                                  ),
                                  AdminKeyValueRow(
                                    label: 'Created',
                                    value: contractCreatedDate,
                                  ),
                                  AdminKeyValueRow(
                                    label: 'Client Approval',
                                    value: clientApproved
                                        ? 'Approved'
                                        : 'Pending',
                                  ),
                                  AdminKeyValueRow(
                                    label: 'Freelancer Approval',
                                    value: freelancerApproved
                                        ? 'Approved'
                                        : 'Pending',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _openContractFileOrViewer(details),
                                style: adminOutlinedButtonStyle(),
                                icon: Icon(
                                  details.contractFileUrl.trim().isNotEmpty
                                      ? Icons.picture_as_pdf_outlined
                                      : Icons.description_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  details.contractFileUrl.trim().isNotEmpty
                                      ? 'View Contract File'
                                      : 'Open Contract',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 16),

                AdminSectionCard(
                  title: 'Delivered Work',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (deliveryStatusLabel != '-' ||
                          deliverySubmittedAt.isNotEmpty ||
                          deliveryApprovedAt.isNotEmpty ||
                          finalWorkUploadedAt.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AdminInfoPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (deliveryStatusLabel != '-')
                                  AdminKeyValueRow(
                                    label: 'Delivery Status',
                                    value: deliveryStatusLabel,
                                  ),
                                if (deliverySubmittedAt.isNotEmpty)
                                  AdminKeyValueRow(
                                    label: 'Submitted At',
                                    value: deliverySubmittedAt,
                                  ),
                                if (deliveryApprovedAt.isNotEmpty)
                                  AdminKeyValueRow(
                                    label: 'Approved At',
                                    value: deliveryApprovedAt,
                                  ),
                                if (finalWorkUploadedAt.isNotEmpty)
                                  AdminKeyValueRow(
                                    label: 'Final Work',
                                    value: finalWorkUploadedAt,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (deliveredWorkItems.isEmpty)
                        const _EmptyPreviewCard(
                          icon: Icons.inventory_2_outlined,
                          title: 'No delivered work has been submitted yet.',
                          description:
                              'No files, images, links, or notes were found for this contract.',
                        )
                      else
                        Column(
                          children: deliveredWorkItems
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _DeliveredWorkTile(
                                    item: item,
                                    onOpen: item.url.isEmpty
                                        ? null
                                        : () => _launchExternalUrl(
                                            item.url,
                                            unavailableMessage:
                                                'This delivered item is not available.',
                                          ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                AdminSectionCard(
                  title: 'Chat Preview',
                  child: !hasChatAvailable
                      ? _EmptyPreviewCard(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'No chat is available for this contract.',
                          description:
                              'A related chat thread could not be found for this review.',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (chatPreview.isNotEmpty) ...[
                              ...chatPreview
                                  .take(2)
                                  .map(
                                    (message) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _PreviewItemTile(
                                        icon: Icons.chat_bubble_outline_rounded,
                                        text: message,
                                      ),
                                    ),
                                  ),
                              const SizedBox(height: 2),
                            ],
                            const AdminInfoPanel(
                              child: Text(
                                'Open the conversation between the client and freelancer in admin read-only mode.',
                                style: TextStyle(
                                  color: kAdminTextSecondary,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _openReadOnlyChat(details),
                                style: adminOutlinedButtonStyle(),
                                icon: const Icon(Icons.chat_rounded, size: 18),
                                label: const Text(
                                  'View Chat',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
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
  const _PreviewItemTile({required this.icon, required this.text});

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

class _DeliveredWorkTile extends StatelessWidget {
  const _DeliveredWorkTile({required this.item, this.onOpen});

  final _DeliveredWorkItem item;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final canOpen = onOpen != null && item.url.trim().isNotEmpty;
    final isImage = item.kind == _DeliveredWorkKind.image;

    final accentColor = switch (item.kind) {
      _DeliveredWorkKind.image => kAdminPrimary,
      _DeliveredWorkKind.file => kAdminWarning,
      _DeliveredWorkKind.link => kAdminSuccess,
      _DeliveredWorkKind.note => kAdminTextSecondary,
    };

    final icon = switch (item.kind) {
      _DeliveredWorkKind.image => Icons.image_outlined,
      _DeliveredWorkKind.file => Icons.attach_file_rounded,
      _DeliveredWorkKind.link => Icons.link_rounded,
      _DeliveredWorkKind.note => Icons.notes_rounded,
    };

    final kindLabel = switch (item.kind) {
      _DeliveredWorkKind.image => 'Image',
      _DeliveredWorkKind.file => 'File',
      _DeliveredWorkKind.link => 'Link',
      _DeliveredWorkKind.note => 'Note',
    };

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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kAdminBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: isImage && item.url.trim().isNotEmpty
                ? Image.network(
                    item.url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(icon, color: accentColor, size: 24),
                  )
                : Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        kindLabel,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (canOpen) ...[
                      const Spacer(),
                      TextButton.icon(
                        onPressed: onOpen,
                        style: TextButton.styleFrom(
                          foregroundColor: kAdminPrimary,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text(
                          'Open',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  style: const TextStyle(
                    color: kAdminTextPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                if (item.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    style: const TextStyle(
                      color: kAdminTextSecondary,
                      fontSize: 12.8,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryReasonCard extends StatelessWidget {
  const _SummaryReasonCard({required this.title});

  final String title;

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
        ],
      ),
    );
  }
}

class _ContentBlock extends StatelessWidget {
  const _ContentBlock({required this.title, required this.child});

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
    required this.reporterUserId,
    required this.otherPartyUserId,
    required this.reporterProfile,
    required this.otherPartyProfile,
    required this.contractId,
    required this.requestId,
    required this.chatId,
    required this.clientUserId,
    required this.freelancerUserId,
    required this.clientProfile,
    required this.freelancerProfile,
    required this.requestData,
    required this.contractData,
    required this.chatData,
    required this.contractFileUrl,
    required this.contractViewData,
  });

  final String reviewId;
  final Map<String, dynamic> reviewData;
  final String reporterUserId;
  final String otherPartyUserId;
  final Map<String, dynamic>? reporterProfile;
  final Map<String, dynamic>? otherPartyProfile;
  final String contractId;
  final String requestId;
  final String chatId;
  final String clientUserId;
  final String freelancerUserId;
  final Map<String, dynamic>? clientProfile;
  final Map<String, dynamic>? freelancerProfile;
  final Map<String, dynamic>? requestData;
  final Map<String, dynamic>? contractData;
  final Map<String, dynamic>? chatData;
  final String contractFileUrl;
  final GeneratedContract? contractViewData;
}

class _ContractRequestDoc {
  const _ContractRequestDoc({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

enum _DeliveredWorkKind { image, file, link, note }

class _DeliveredWorkItem {
  const _DeliveredWorkItem({
    required this.kind,
    required this.label,
    this.url = '',
    this.description = '',
  });

  final _DeliveredWorkKind kind;
  final String label;
  final String url;
  final String description;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

dynamic _firstNonNull(List<dynamic> values) {
  for (final value in values) {
    if (value != null) {
      return value;
    }
  }

  return null;
}

Map<String, dynamic>? _firstNonEmptyMap(List<dynamic> values) {
  for (final value in values) {
    final map = _asMap(value);

    if (map.isNotEmpty) {
      return map;
    }
  }

  return null;
}

bool _looksLikeContractData(Map<String, dynamic>? data) {
  if (data == null || data.isEmpty) return false;

  const keys = <String>{
    'meta',
    'parties',
    'service',
    'payment',
    'timeline',
    'approval',
    'contractText',
    'contractId',
  };

  return data.keys.any(keys.contains);
}

String _displayOrDash(String value) {
  final trimmed = value.trim();

  return trimmed.isEmpty ? '-' : trimmed;
}

bool _approvalFlag(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];

    if (value == true) return true;

    final normalized = (value ?? '').toString().trim().toLowerCase();

    if (normalized == 'true' ||
        normalized == 'approved' ||
        normalized == 'signed' ||
        normalized == 'accepted') {
      return true;
    }
  }

  return false;
}

List<_DeliveredWorkItem> _extractDeliveredWorkItems({
  required Map<String, dynamic> review,
  required Map<String, dynamic> deliveryData,
}) {
  final results = <_DeliveredWorkItem>[];
  final seen = <String>{};

  void addItem(_DeliveredWorkItem item) {
    final normalizedLabel = item.label.trim();

    if (normalizedLabel.isEmpty) return;

    final key =
        '${item.kind.name}|${normalizedLabel.toLowerCase()}|${item.url.trim().toLowerCase()}';

    if (!seen.add(key)) return;

    results.add(item);
  }

  void addValue(dynamic value) {
    if (value == null) return;

    if (value is Iterable) {
      for (final item in value) {
        addValue(item);
      }
      return;
    }

    if (value is Map) {
      final map = _asMap(value);

      final url = _firstFilled([
        map['url'],
        map['downloadUrl'],
        map['fileUrl'],
        map['imageUrl'],
        map['link'],
        map['path'],
      ]);

      final label = _firstFilled([
        map['name'],
        map['fileName'],
        map['title'],
        map['label'],
        map['message'],
        map['text'],
        map['note'],
        map['comment'],
        url,
      ]);

      final description = _firstFilled([
        map['description'],
        map['caption'],
        map['details'],
      ]);

      if (url.isNotEmpty) {
        addItem(
          _DeliveredWorkItem(
            kind: _kindFromUrl(url),
            label: label,
            url: url,
            description: description,
          ),
        );
        return;
      }

      if (label.isNotEmpty) {
        addItem(
          _DeliveredWorkItem(
            kind: _DeliveredWorkKind.note,
            label: label,
            description: description,
          ),
        );
      }

      return;
    }

    final text = value.toString().trim();

    if (text.isEmpty) return;

    if (_isLikelyUrl(text)) {
      addItem(
        _DeliveredWorkItem(kind: _kindFromUrl(text), label: text, url: text),
      );
      return;
    }

    addItem(_DeliveredWorkItem(kind: _DeliveredWorkKind.note, label: text));
  }

  addValue(deliveryData['previewImageUrls']);
  addValue(deliveryData['finalWorkUrls']);
  addValue(review['deliveredWork']);
  addValue(review['deliveredFiles']);
  addValue(review['deliveryFiles']);
  addValue(review['deliveredImages']);
  addValue(review['attachments']);
  addValue(review['files']);
  addValue(review['imageUrls']);
  addValue(review['workFiles']);
  addValue(review['workLinks']);
  addValue(review['deliveryUrls']);

  for (final note in [
    review['deliveryNote'],
    review['deliveredWorkNote'],
    review['deliveryComment'],
    review['comment'],
    review['note'],
  ]) {
    final text = (note ?? '').toString().trim();

    if (text.isNotEmpty) {
      addItem(_DeliveredWorkItem(kind: _DeliveredWorkKind.note, label: text));
    }
  }

  return results;
}

bool _isLikelyUrl(String value) {
  final lower = value.trim().toLowerCase();

  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('www.');
}

bool _isImageUrl(String value) {
  final lower = value.trim().toLowerCase();

  return lower.contains('.png') ||
      lower.contains('.jpg') ||
      lower.contains('.jpeg') ||
      lower.contains('.gif') ||
      lower.contains('.webp');
}

_DeliveredWorkKind _kindFromUrl(String value) {
  if (_isImageUrl(value)) {
    return _DeliveredWorkKind.image;
  }

  if (_isLikelyUrl(value)) {
    return _DeliveredWorkKind.link;
  }

  return _DeliveredWorkKind.file;
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

  return _firstFilled([data['name'], fullName]);
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
          : _firstFilled([body, sender, value['preview']]);

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

String _friendlyError(Object error) {
  return error.toString().replaceFirst('Exception: ', '').trim();
}
