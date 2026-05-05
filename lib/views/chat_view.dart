import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../controlles/chat_controller.dart';
import '../models/message_model.dart';
import 'freelancer_client_profile_view.dart';
import 'freelancer_profile.dart';
import 'report_flag_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moyasar/moyasar.dart';

String _friendlyErrorMessage(Object error) {
  final rawError = error.toString().replaceFirst('Exception: ', '').trim();
  final normalizedError = rawError.toLowerCase();
  final statusCode = error is int ? error : int.tryParse(rawError);

  if (error is TimeoutException ||
      normalizedError.contains('timeout') ||
      normalizedError.contains('timed out')) {
    return 'Check your internet or server';
  }

  if (error is SocketException ||
      normalizedError.contains('socketexception') ||
      normalizedError.contains('failed host lookup') ||
      normalizedError.contains('connection reset') ||
      normalizedError.contains('connection refused') ||
      normalizedError.contains('network')) {
    return 'Check your internet or server';
  }

  if (statusCode == 401 ||
      statusCode == 403 ||
      normalizedError.contains('permission') ||
      normalizedError.contains('not allowed') ||
      normalizedError.contains('access denied')) {
    return 'You are not allowed to do this';
  }

  if (statusCode == 404 ||
      normalizedError.contains('not found') ||
      normalizedError.contains('missing') ||
      normalizedError.contains('requestid is missing')) {
    return 'Data not found';
  }

  return 'Something went wrong';
}

Future<void> _showErrorDialogForContext(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

class ChatView extends StatefulWidget {
  final String chatId;
  final String otherUserName;

  final String otherUserId;
  final String otherUserRole;

  const ChatView({
    super.key,
    required this.chatId,
    required this.otherUserName,
    required this.otherUserId,
    required this.otherUserRole,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  static const Color primary = Color(0xFF5A3E9E);
  static const String contractDisplayTitle = 'Freelancer Service Agreement';
  static const String moyasarPublishableKey =
      'pk_test_tP63K4Te6zdS9egGFnhNy3TYtkZJHPKkMPGcK7Gx';
  static const Duration _contractRequestTimeout = Duration(seconds: 25);
  static const Duration _panelSwitchDuration = Duration(milliseconds: 220);
  static const double _pinnedPanelHeaderMinHeight = 92;
  static const double _chatPanelRadius = 16;
  static const double _chatPanelInnerRadius = 14;
  static const Color _chatPanelShellBackground = Color(0xFFF6F3FB);
  static const Color _chatPanelBackground = Colors.white;
  static const Color _chatPanelSurface = Color(0xFFF8F4FD);
  static const Color _chatPanelBorder = Color(0xFFE7DFF4);
  List<File> _selectedImages = [];
  String? _otherUserPhotoUrl;
  final ImagePicker _picker = ImagePicker();
  final ChatController _controller = ChatController();
  final TextEditingController _messageController = TextEditingController();
  Map<String, dynamic>? _contractData;
  Map<String, dynamic>? _currentUserReviewData;
  bool _isGeneratingContract = false;
  bool _isSavingContract = false;
  bool _isApprovingContract = false;
  bool _isTerminatingContract = false;
  bool _isEditingContract = false;
  bool _isLoadingReviewData = false;
  bool _isSavingReview = false;
  bool _isApprovedContractPanelExpanded = false;
  bool _isFreelancerProgressPanelExpanded = false;
  bool _isWorkProgressSheetOpen = false;
  bool _isSwitchingPanels = false;
  bool _isLoadingContractData = true;
  bool _isContractPreviewExpanded = true;
  bool _isAddingClause = false;
  int _selectedApprovedPanelTab = 0;
  Timer? _terminationCountdownTimer;
  String? _contractError;
  String _editableServiceDescription = '';
  String _editableAmount = '';
  String _editableDeadline = '';
  String? _requestId;
  List<Map<String, String>> _pendingCustomClauses = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _requestContractSubscription;
  final TextEditingController _clauseTitleController = TextEditingController();
  final TextEditingController _clauseContentController =
      TextEditingController();
  final ScrollController _contractPreviewScrollController = ScrollController();
  final ScrollController _contractMessageCardScrollController =
      ScrollController();
  final ScrollController _approvedContractPanelScrollController =
      ScrollController();
  final ScrollController _freelancerProgressPanelScrollController =
      ScrollController();
  @override
  void initState() {
    super.initState();
    _isApprovedContractPanelExpanded = false;
    _isFreelancerProgressPanelExpanded = false;

    Future.delayed(const Duration(milliseconds: 300), () {
      _controller.markMessagesAsRead(widget.chatId);
    });
    _loadOtherUserPhoto();
    _listenToRequestContract();
    _terminationCountdownTimer = Timer.periodic(const Duration(minutes: 1), (
      _,
    ) {
      if (!mounted) return;
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(jump: true);
    });
  }

  Future<void> _showErrorDialog(String message) {
    return _showErrorDialogForContext(context, message);
  }

  Uri _backendUri(String endpointPath, {Map<String, String>? queryParameters}) {
    final normalizedBaseUrl = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    final uri = Uri.parse('$normalizedBaseUrl/$endpointPath');

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: queryParameters);
  }

  Future<http.Response> _postContractApi({
    required String endpointPath,
    required Map<String, dynamic> body,
    required String logLabel,
    Duration? timeout,
  }) async {
    final uri = _backendUri(endpointPath);
    final encodedBody = jsonEncode(body);

    debugPrint('$logLabel request URL: $uri');
    debugPrint('$logLabel request body: $encodedBody');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: encodedBody,
          )
          .timeout(timeout ?? _contractRequestTimeout);

      debugPrint('$logLabel status code: ${response.statusCode}');
      debugPrint('$logLabel response body: ${response.body}');
      return response;
    } on TimeoutException catch (error) {
      debugPrint('$logLabel request URL: $uri');
      debugPrint('$logLabel exception: $error');
      rethrow;
    } catch (error) {
      debugPrint('$logLabel request URL: $uri');
      debugPrint('$logLabel exception: $error');
      rethrow;
    }
  }

  Future<void> _openDeliveryPreviewImage(String imageUrl) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(imageUrl, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openFinalWorkGallery(List<String> imageUrls) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 0),
                child: Row(
                  children: [
                    Text(
                      'Final Work (${imageUrls.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 380,
                child: PageView.builder(
                  itemCount: imageUrls.length,
                  itemBuilder: (context, index) {
                    final imageUrl = imageUrls[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) {
                              return const Center(
                                child: Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.white),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _extractRequestId(Map<String, dynamic>? chatData) {
    final requestId = (chatData?['requestId'] ?? '').toString().trim();

    if (requestId.isEmpty) {
      throw Exception('requestId is missing in chat document');
    }

    return requestId;
  }

  Future<void> _listenToRequestContract() async {
    if (mounted) {
      setState(() {
        _isLoadingContractData = true;
      });
    }

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chat')
          .doc(widget.chatId)
          .get();

      final chatData = chatDoc.data();
      final requestId = _extractRequestId(chatData);
      _requestId = requestId;
      final announcementId = (chatData?['announcementId'] ?? '')
          .toString()
          .trim();
      final proposalId = (chatData?['proposalId'] ?? '').toString().trim();
      debugPrint('requestId: $requestId');
      debugPrint('CHAT ID: ${widget.chatId}');
      debugPrint('REQUEST ID: $requestId');
      debugPrint('ANNOUNCEMENT ID: $announcementId');
      debugPrint('PROPOSAL ID: $proposalId');

      await _requestContractSubscription?.cancel();

      final isAnnouncementProposalChat = proposalId.isNotEmpty;
      final sourceCollection = isAnnouncementProposalChat
          ? 'announcement_requests'
          : 'requests';
      final sourceDocumentId = isAnnouncementProposalChat
          ? proposalId
          : requestId;

      debugPrint('Listening source: $sourceCollection');
      debugPrint('Listening document id: $sourceDocumentId');

      final sourceStream = FirebaseFirestore.instance
          .collection(sourceCollection)
          .doc(sourceDocumentId)
          .snapshots();

      _requestContractSubscription = sourceStream.listen((sourceDoc) {
        final rawContractData = sourceDoc.data()?['contractData'];
        final hasContractData =
            rawContractData is Map && rawContractData.isNotEmpty;

        debugPrint('Listening source: $sourceCollection');
        debugPrint('Listening document id: $sourceDocumentId');
        debugPrint('contractData exists: $hasContractData');

        if (!mounted) return;

        setState(() {
          _isLoadingContractData = false;
          _contractData = hasContractData
              ? Map<String, dynamic>.from(rawContractData as Map)
              : null;
        });

        unawaited(_refreshCurrentUserReviewState());
      });
    } catch (e) {
      debugPrint('Error listening to request contract: $e');

      if (!mounted) return;
      setState(() {
        _isLoadingContractData = false;
        _contractData = null;
        _currentUserReviewData = null;
        _isLoadingReviewData = false;
      });
    }
  }

  Future<void> _refreshContractDataFromSource() async {
    final chatDoc = await FirebaseFirestore.instance
        .collection('chat')
        .doc(widget.chatId)
        .get();

    final chatData = chatDoc.data();
    final requestId = _extractRequestId(chatData);
    final proposalId = (chatData?['proposalId'] ?? '').toString().trim();
    final isAnnouncementProposalChat = proposalId.isNotEmpty;
    final sourceCollection = isAnnouncementProposalChat
        ? 'announcement_requests'
        : 'requests';
    final sourceDocumentId = isAnnouncementProposalChat
        ? proposalId
        : requestId;

    final sourceDoc = await FirebaseFirestore.instance
        .collection(sourceCollection)
        .doc(sourceDocumentId)
        .get();

    final rawContractData = sourceDoc.data()?['contractData'];
    final hasContractData =
        rawContractData is Map && rawContractData.isNotEmpty;

    if (!mounted) return;

    setState(() {
      _contractData = hasContractData
          ? Map<String, dynamic>.from(rawContractData as Map)
          : _contractData;
    });
  }

  String _reviewDocumentId({
    required String requestId,
    required String reviewerId,
  }) {
    return '${requestId}_$reviewerId';
  }

  String _reviewedUserRole() {
    final role = widget.otherUserRole.trim().toLowerCase();
    if (role == 'client' || role == 'freelancer') {
      return role;
    }
    return _currentUserRole() == 'client' ? 'freelancer' : 'client';
  }

  bool _isContractCompletedForReview(Map<String, dynamic>? contractData) {
    if (contractData == null) return false;

    final approval = _asMap(contractData['approval']);
    final contractStatus = (approval['contractStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return contractStatus == 'completed';
  }

  Future<Map<String, dynamic>> _loadCurrentUserProfileData() async {
    final currentUserId = _controller.currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      throw Exception('Current user not found');
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();

    if (!userDoc.exists) {
      throw Exception('Current user profile not found');
    }

    return userDoc.data() ?? <String, dynamic>{};
  }

  Future<void> _refreshReviewedUserRatingSummary(String reviewedUserId) async {
    final reviewsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(reviewedUserId)
        .collection('reviews')
        .get();

    final docs = reviewsSnapshot.docs;
    final count = docs.length;
    double average = 0;

    if (count > 0) {
      final total = docs.fold<double>(0, (sum, doc) {
        final rawRating = doc.data()['rating'];
        final rating = rawRating is num ? rawRating.toDouble() : 0.0;
        return sum + rating;
      });
      average = double.parse((total / count).toStringAsFixed(1));
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(reviewedUserId)
        .set({
          'rating': average,
          'reviewsCount': count,
        }, SetOptions(merge: true));
  }

  Future<void> _refreshCurrentUserReviewState() async {
    final currentUserId = _controller.currentUserId;
    final reviewedUserId = widget.otherUserId.trim();
    final requestId = (_requestId ?? '').trim();

    if (currentUserId == null ||
        currentUserId.isEmpty ||
        reviewedUserId.isEmpty ||
        requestId.isEmpty ||
        !_isContractCompletedForReview(_contractData)) {
      if (!mounted) return;
      setState(() {
        _currentUserReviewData = null;
        _isLoadingReviewData = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingReviewData = true;
      });
    }

    try {
      final reviewDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(reviewedUserId)
          .collection('reviews')
          .doc(
            _reviewDocumentId(requestId: requestId, reviewerId: currentUserId),
          )
          .get();

      if (!mounted) return;
      setState(() {
        _currentUserReviewData = reviewDoc.exists
            ? <String, dynamic>{'reviewId': reviewDoc.id, ...?reviewDoc.data()}
            : null;
        _isLoadingReviewData = false;
      });
    } catch (e) {
      debugPrint('Refresh review state error: $e');
      if (!mounted) return;
      setState(() {
        _currentUserReviewData = null;
        _isLoadingReviewData = false;
      });
    }
  }

  Future<void> _createReviewNotification({
    required String receiverId,
    required String requestId,
    required String contractId,
    required String actionText,
    required String snippet,
    required Map<String, dynamic> senderData,
  }) async {
    try {
      final senderId = _controller.currentUserId;
      if (senderId == null || senderId.trim().isEmpty) return;

      final senderName = _displayName(senderData, 'User');
      final senderProfileUrl = _firstFilled([
        senderData['photoUrl'],
        senderData['profile'],
      ]);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .collection('notifications')
          .add({
            'type': 'rating_review',
            'senderId': senderId,
            'senderName': senderName,
            'senderProfileUrl': senderProfileUrl,
            'senderProfileImage': senderProfileUrl,
            'receiverId': receiverId,
            'title': senderName.isEmpty ? 'New Review' : senderName,
            'message': actionText,
            'actionText': actionText,
            'snippet': snippet,
            'requestId': requestId,
            'contractId': contractId,
            'chatId': widget.chatId,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Create review notification error: $e');
    }
  }

  Future<void> _submitOrUpdateReview({
    required int rating,
    required String reviewText,
  }) async {
    final currentUserId = _controller.currentUserId;
    final reviewedUserId = widget.otherUserId.trim();
    final requestId = (_requestId ?? '').trim();
    final contractData = _contractData;

    if (currentUserId == null || currentUserId.isEmpty) {
      throw Exception('Current user not found');
    }
    if (reviewedUserId.isEmpty || requestId.isEmpty) {
      throw Exception('Review target not found');
    }
    if (!_isContractCompletedForReview(contractData)) {
      throw Exception('Reviews are only available after completion');
    }

    final currentUserData = await _loadCurrentUserProfileData();
    final reviewerName = _displayName(currentUserData, 'User');
    final reviewDocId = _reviewDocumentId(
      requestId: requestId,
      reviewerId: currentUserId,
    );
    final contractId =
        (_asMap(contractData?['meta'])['contractId'] ?? requestId)
            .toString()
            .trim();

    final reviewRef = FirebaseFirestore.instance
        .collection('users')
        .doc(reviewedUserId)
        .collection('reviews')
        .doc(reviewDocId);

    final existingReviewDoc = await reviewRef.get();
    final isNewReview = !existingReviewDoc.exists;
    final trimmedText = reviewText.trim();
    final now = FieldValue.serverTimestamp();
    final reviewerProfileUrl = _firstFilled([
      currentUserData['photoUrl'],
      currentUserData['profile'],
    ]);

    final reviewPayload = <String, dynamic>{
      'reviewId': reviewDocId,
      'requestId': requestId,
      'contractId': contractId.isEmpty ? requestId : contractId,
      'reviewerId': currentUserId,
      'reviewerName': reviewerName,
      'reviewerRole': _currentUserRole(),
      'reviewedUserId': reviewedUserId,
      'reviewedUserRole': _reviewedUserRole(),
      'reviewerProfileUrl': reviewerProfileUrl,
      'rating': rating,
      'reviewText': trimmedText,
      'text': trimmedText,
      'updatedAt': now,
    };

    if (existingReviewDoc.exists) {
      final existingReviewerId = (existingReviewDoc.data()?['reviewerId'] ?? '')
          .toString()
          .trim();
      if (existingReviewerId.isNotEmpty &&
          existingReviewerId != currentUserId) {
        throw Exception('You can only edit your own review');
      }

      await reviewRef.set(reviewPayload, SetOptions(merge: true));
    } else {
      await reviewRef.set({...reviewPayload, 'createdAt': now});
    }

    if (isNewReview) {
      final actionText = _currentUserRole() == 'client'
          ? 'The client has rated and reviewed your completed service.'
          : 'The freelancer has rated and reviewed you for the completed service.';
      final notificationSnippet = _firstFilled([
        (_asMap(contractData?['meta'])['title'] ?? '').toString().trim(),
        contractDisplayTitle,
      ]);

      await _createReviewNotification(
        receiverId: reviewedUserId,
        requestId: requestId,
        contractId: contractId.isEmpty ? requestId : contractId,
        actionText: actionText,
        snippet: notificationSnippet,
        senderData: currentUserData,
      );
    }

    await _refreshReviewedUserRatingSummary(reviewedUserId);
    await _refreshCurrentUserReviewState();
  }

  Future<void> _deleteCurrentUserReview() async {
    final currentUserId = _controller.currentUserId;
    final reviewedUserId = widget.otherUserId.trim();
    final requestId = (_requestId ?? '').trim();

    if (currentUserId == null || currentUserId.isEmpty) {
      throw Exception('Current user not found');
    }
    if (reviewedUserId.isEmpty || requestId.isEmpty) {
      throw Exception('Review target not found');
    }

    final reviewRef = FirebaseFirestore.instance
        .collection('users')
        .doc(reviewedUserId)
        .collection('reviews')
        .doc(
          _reviewDocumentId(requestId: requestId, reviewerId: currentUserId),
        );

    final reviewDoc = await reviewRef.get();
    if (!reviewDoc.exists) return;

    final reviewerId = (reviewDoc.data()?['reviewerId'] ?? '')
        .toString()
        .trim();
    if (reviewerId.isNotEmpty && reviewerId != currentUserId) {
      throw Exception('You can only delete your own review');
    }

    await reviewRef.delete();
    await _refreshReviewedUserRatingSummary(reviewedUserId);
    await _refreshCurrentUserReviewState();
  }

  Future<void> _openReviewEditor({bool isEditing = false}) async {
    final existingReview = _currentUserReviewData;
    final initialRating = isEditing
        ? (() {
            final rawRating = existingReview?['rating'];
            final parsedRating = rawRating is num ? rawRating.toInt() : 0;
            return parsedRating.clamp(0, 5);
          })()
        : 0;
    final initialText =
        (existingReview?['reviewText'] ?? existingReview?['text'] ?? '')
            .toString();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewEditorSheet(
        primary: primary,
        isEditing: isEditing,
        initialRating: initialRating,
        initialText: initialText,
        reviewedUserName: widget.otherUserName,
        onSubmit: (rating, reviewText) async {
          if (mounted) {
            setState(() {
              _isSavingReview = true;
            });
          }

          try {
            await _submitOrUpdateReview(rating: rating, reviewText: reviewText);
            if (!mounted) return true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isEditing
                      ? 'Review updated successfully'
                      : 'Review submitted successfully',
                ),
              ),
            );
            return true;
          } finally {
            if (mounted) {
              setState(() {
                _isSavingReview = false;
              });
            }
          }
        },
      ),
    );

    if (submitted == true) {
      await _refreshCurrentUserReviewState();
    }
  }

  Future<void> _confirmDeleteReview() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Review'),
          content: const Text(
            'Do you want to delete your rating and review for this completed service?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC75A5A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() {
      _isSavingReview = true;
    });

    try {
      await _deleteCurrentUserReview();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Delete review error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingReview = false;
      });
    }
  }

  Future<void> _loadOtherUserPhoto() async {
    try {
      if (widget.otherUserId.isEmpty) {
        debugPrint('⚠️  Cannot load photo: otherUserId is empty');
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();

      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final photo = (data['photoUrl'] ?? data['profile'] ?? '').toString();

      if (!mounted) return;

      setState(() {
        _otherUserPhotoUrl = photo;
      });
    } catch (e) {
      debugPrint('❌ Error loading photo: $e');
    }
  }

  Future<void> _openOtherUserProfile() async {
    if (widget.otherUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User information not available')),
      );
      return;
    }

    var otherRole = widget.otherUserRole.trim().toLowerCase();

    if (otherRole != 'client' && otherRole != 'freelancer') {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.otherUserId)
            .get();

        final accountType = (doc.data()?['accountType'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (accountType == 'client' || accountType == 'freelancer') {
          otherRole = accountType;
        }
      } catch (e) {
        debugPrint('⚠️ Could not resolve other user role: $e');
      }
    }

    if (!mounted) return;

    if (otherRole == 'client') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FreelancerClientProfileView(
            clientId: widget.otherUserId,
            fromChat: true,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              FreelancerProfileView(userId: widget.otherUserId, fromChat: true),
        ),
      );
    }
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) return;

    final bottom = _scrollController.position.maxScrollExtent;

    if (jump) {
      _scrollController.jumpTo(bottom);
    } else {
      _scrollController.animateTo(
        bottom,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) return;

      setState(() {
        _selectedImages.addAll(pickedFiles.map((e) => File(e.path)));
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Pick images error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    }
  }

  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _clauseTitleController.dispose();
    _clauseContentController.dispose();
    _requestContractSubscription?.cancel();
    _terminationCountdownTimer?.cancel();
    _contractPreviewScrollController.dispose();
    _contractMessageCardScrollController.dispose();
    _approvedContractPanelScrollController.dispose();
    _freelancerProgressPanelScrollController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty && _selectedImages.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      await _controller.sendCombinedMessage(
        chatId: widget.chatId,
        text: text,
        imageFiles: _selectedImages,
      );

      _messageController.clear();
      _selectedImages.clear();

      await Future.delayed(const Duration(milliseconds: 100));

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Send message error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Widget _buildMessageBubble(MessageModel message) {
    if (message.type == 'contract') {
      final currentContractStatus =
          ((_contractData?['approval']
                      as Map<String, dynamic>?)?['contractStatus']
                  as Object?)
              ?.toString()
              .trim()
              .toLowerCase();
      if (currentContractStatus == 'approved') {
        return const SizedBox.shrink();
      }
      return _buildContractMessageCard(message);
    }

    final isMe = message.senderId == _controller.currentUserId;

    final hasImages =
        message.imageUrls.isNotEmpty || message.imageUrl.isNotEmpty;

    final displayImages = message.imageUrls.isNotEmpty
        ? message.imageUrls
        : (message.imageUrl.isNotEmpty ? [message.imageUrl] : []);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: hasImages
              ? const Color(0xFFF6F2FB)
              : (isMe ? primary : const Color(0xFFF1F1F1)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.text.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: hasImages ? 8 : 0),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: hasImages
                        ? Colors.black87
                        : (isMe ? Colors.white : Colors.black87),
                    fontSize: 14,
                  ),
                ),
              ),

            if (displayImages.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: displayImages.map((url) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            backgroundColor: Colors.black,
                            body: Center(
                              child: Image.network(
                                url,
                                errorBuilder: (_, error, stackTrace) {
                                  debugPrint(
                                    'Failed to load chat image from Firebase Storage: $error',
                                  );
                                  return const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'Failed to load image',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        url,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return const SizedBox(
                            width: 110,
                            height: 110,
                            child: Center(child: Text('Failed')),
                          );
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),

            if (isMe) ...[
              const SizedBox(height: 4),
              Icon(
                Icons.done_all,
                size: 16,
                color: message.isRead
                    ? Colors.lightBlueAccent
                    : (hasImages ? Colors.grey : Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }

  DateTime? _parseContractDeadline(String rawDeadline) {
    final deadline = rawDeadline.trim();
    if (deadline.isEmpty) return null;

    final parsedIsoDate = DateTime.tryParse(deadline);
    if (parsedIsoDate != null) {
      return DateTime(
        parsedIsoDate.year,
        parsedIsoDate.month,
        parsedIsoDate.day,
      );
    }

    final normalizedDeadline = deadline
        .replaceAll('-', '/')
        .replaceAll('.', '/');
    final parts = normalizedDeadline
        .split('/')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length != 3) return null;

    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    final third = int.tryParse(parts[2]);

    if (first == null || second == null || third == null) return null;

    try {
      if (parts[0].length == 4) {
        return DateTime(first, second, third);
      }

      if (parts[2].length == 4) {
        return DateTime(third, second, first);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> _pickContractDeadline() async {
    final parsedDeadline = _parseContractDeadline(_editableDeadline);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialDate =
        parsedDeadline != null && !parsedDeadline.isBefore(today)
        ? parsedDeadline
        : now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return;

    _editableDeadline =
        '${pickedDate.year.toString().padLeft(4, '0')}-'
        '${pickedDate.month.toString().padLeft(2, '0')}-'
        '${pickedDate.day.toString().padLeft(2, '0')}';

    setState(() {});
  }

  String? _validateContractInputs() {
    final amountText = _editableAmount.trim();
    if (amountText.isEmpty) {
      return 'Amount must not be empty';
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      return 'Amount must be a valid positive number';
    }

    final deadlineText = _editableDeadline.trim();
    if (deadlineText.isEmpty) {
      return 'Deadline must not be empty';
    }
    if (_parseContractDeadline(deadlineText) == null) {
      return 'Deadline is invalid';
    }

    for (final clause in _pendingCustomClauses) {
      final title = (clause['title'] ?? '').trim();
      final content = (clause['content'] ?? '').trim();

      if (title.isEmpty && content.isEmpty) {
        continue;
      }
      if (title.isEmpty || content.isEmpty) {
        return 'Every pending custom clause must have title and content';
      }
      if (title.length > 80) {
        return 'Clause title must be 80 characters or less';
      }
      if (content.length > 500) {
        return 'Clause content must be 500 characters or less';
      }
    }

    return null;
  }

  String? _validateContractDescription(String? value) {
    final serviceDescription = (value ?? '').trim();
    if (serviceDescription.isEmpty) {
      return 'Service description must not be empty';
    }
    if (RegExp(
      r'(https?:\/\/|www\.)',
      caseSensitive: false,
    ).hasMatch(serviceDescription)) {
      return 'Service description must not contain links';
    }
    if (RegExp(r'^\d+$').hasMatch(serviceDescription)) {
      return 'Service description must not contain only digits';
    }
    if (serviceDescription.length > 150) {
      return 'Service description must be 150 characters or less';
    }

    return null;
  }

  bool _hasContractDeadlinePassed(String rawDeadline) {
    final parsedDeadline = _parseContractDeadline(rawDeadline);
    if (parsedDeadline == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return today.isAfter(parsedDeadline);
  }

  Widget _buildContractMessageCard(MessageModel message) {
    final currentContractStatus =
        ((_contractData?['approval']
                    as Map<String, dynamic>?)?['contractStatus']
                as Object?)
            ?.toString()
            .trim()
            .toLowerCase();
    if (currentContractStatus != 'approved') {
      return const SizedBox.shrink();
    }

    final requestId = message.requestId.trim().isNotEmpty
        ? message.requestId.trim()
        : widget.chatId;
    final isApprovedContract = currentContractStatus == 'approved';
    final cardTitleText = currentContractStatus == 'approved'
        ? 'Approved Contract'
        : currentContractStatus == 'rejected'
        ? 'Rejected Contract'
        : currentContractStatus == 'termination_pending'
        ? 'Contract'
        : 'Generated Contract';
    final statusChipText = currentContractStatus == 'approved'
        ? 'Approved'
        : currentContractStatus == 'rejected'
        ? 'Rejected'
        : currentContractStatus == 'termination_pending'
        ? 'Termination Pending'
        : 'Waiting';
    final statusChipBackgroundColor = currentContractStatus == 'approved'
        ? const Color(0xFFE8F5E9)
        : currentContractStatus == 'rejected'
        ? const Color(0xFFFFEBEE)
        : currentContractStatus == 'termination_pending'
        ? const Color(0xFFFFF4E5)
        : const Color(0xFFFFF4E5);
    final statusChipTextColor = currentContractStatus == 'approved'
        ? const Color(0xFF2E7D32)
        : currentContractStatus == 'rejected'
        ? Colors.redAccent
        : currentContractStatus == 'termination_pending'
        ? const Color(0xFFEF6C00)
        : const Color(0xFFEF6C00);
    final summaryLines = message.contractSummary
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(2)
        .toList();
    final fallbackText = message.contractText.trim();
    final previewText = summaryLines.isNotEmpty
        ? summaryLines.join('\n')
        : (fallbackText.length > 180
              ? '${fallbackText.substring(0, 180)}...'
              : fallbackText);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _chatPanelDecoration(
          backgroundColor: _chatPanelBackground,
          borderColor: primary.withOpacity(0.16),
          showShadow: false,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cardTitleText,
              style: _chatPanelTitleStyle.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusChipBackgroundColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusChipText,
                style: TextStyle(
                  color: statusChipTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              contractDisplayTitle,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (previewText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                previewText,
                style: const TextStyle(color: Colors.black87, height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            _buildContractProgressSection(
              contractStatus: currentContractStatus ?? '',
              currentUserRole: _currentUserRole(),
            ),
            if (isApprovedContract) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => downloadContract(requestId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(
                          color: primary.withOpacity(0.22),
                          width: 1,
                        ),
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download Contract'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          setState(() {
            _isGeneratingContract = true;
            _contractError = null;
            _contractData = null;
          });

          try {
            final chatDoc = await FirebaseFirestore.instance
                .collection('chat')
                .doc(widget.chatId)
                .get();

            final chatData = chatDoc.data();
            final requestId = _extractRequestId(chatData);
            final proposalId = (chatData?['proposalId'] ?? '')
                .toString()
                .trim();
            final announcementId = (chatData?['announcementId'] ?? '')
                .toString()
                .trim();
            final requestBody = <String, dynamic>{'requestId': requestId};
            if (proposalId.isNotEmpty) {
              requestBody['proposalId'] = proposalId;
            }
            debugPrint('Generate Contract requestId: $requestId');
            debugPrint('Generate Contract proposalId: $proposalId');
            debugPrint('Generate Contract announcementId: $announcementId');

            final response = await _postContractApi(
              endpointPath: 'generate-contract-from-request-id',
              body: requestBody,
              logLabel: 'Generate contract',
            );

            if (response.statusCode >= 200 && response.statusCode < 300) {
              final data = jsonDecode(response.body) as Map<String, dynamic>;
              debugPrint('API response: $data');

              final rawContractData = data['contractData'];
              Map<String, dynamic>? freshContractData;

              if (rawContractData is Map) {
                freshContractData = Map<String, dynamic>.from(rawContractData);

                final approval = Map<String, dynamic>.from(
                  (freshContractData['approval'] as Map?) ?? const {},
                );
                final freshStatus = (approval['contractStatus'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();

                approval['clientApproved'] = false;
                approval['freelancerApproved'] = false;
                approval['contractStatus'] = freshStatus == 'pending_approval'
                    ? 'pending_approval'
                    : 'draft';
                approval.remove('termination');

                freshContractData['approval'] = approval;
                freshContractData['signatures'] = {
                  'clientSignature': null,
                  'freelancerSignature': null,
                };
              }

              if (!mounted) return;

              setState(() {
                _contractData = freshContractData;
              });

              if (freshContractData != null) {
                await _createContractNotification(
                  type: 'contract_generated',
                  actionText: 'generated a contract draft',
                  requestId: requestId,
                  chatData: chatData,
                  contractData: freshContractData,
                  notifyBothUsers: true,
                );
              }

              debugPrint('Stored contract data: $_contractData');

              if (_contractData == null) {
                const message =
                    'We could not generate the contract right now. Please try again.';
                setState(() {
                  _contractError = message;
                });
                unawaited(_showErrorDialog(message));
              }
            } else {
              final message = _friendlyErrorMessage(response.statusCode);
              debugPrint(
                'Generate contract failed: '
                '${response.statusCode} ${response.body}',
              );

              if (!mounted) return;
              setState(() {
                _contractError = message;
              });

              unawaited(_showErrorDialog(message));
            }
          } catch (e) {
            debugPrint('Generate contract error: $e');
            if (!mounted) return;
            final message = _friendlyErrorMessage(e);
            setState(() {
              _contractError = message;
            });
            unawaited(_showErrorDialog(message));
          } finally {
            if (!mounted) return;
            setState(() {
              _isGeneratingContract = false;
            });
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Generate Contract',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildGenerateContractSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _buildGenerateButton(),
    );
  }

  List<BoxShadow> get _chatPanelShadow => [
    BoxShadow(
      color: const Color(0xFF22113C).withOpacity(0.05),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  TextStyle get _chatPanelTitleStyle => const TextStyle(
    color: primary,
    fontWeight: FontWeight.w700,
    fontSize: 14.5,
  );

  TextStyle get _chatPanelSubtitleStyle => const TextStyle(
    color: Colors.black54,
    fontSize: 12.5,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );

  TextStyle get _chatPanelBodyStyle =>
      const TextStyle(color: Colors.black87, fontSize: 12.5, height: 1.4);

  BoxDecoration _chatPanelDecoration({
    Color? backgroundColor,
    Color? borderColor,
    double radius = _chatPanelRadius,
    bool showShadow = true,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? _chatPanelBackground,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? _chatPanelBorder),
      boxShadow: showShadow ? _chatPanelShadow : const [],
    );
  }

  Widget _buildChatPanelContainer({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    EdgeInsetsGeometry? margin,
    Color? backgroundColor,
    Color? borderColor,
    double radius = _chatPanelRadius,
    bool showShadow = true,
  }) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: _chatPanelDecoration(
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        radius: radius,
        showShadow: showShadow,
      ),
      child: child,
    );
  }

  Widget _buildChatPanelSurface({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
    EdgeInsetsGeometry? margin,
    Color? backgroundColor,
    Color? borderColor,
    double radius = _chatPanelInnerRadius,
  }) {
    return _buildChatPanelContainer(
      padding: padding,
      margin: margin,
      backgroundColor: backgroundColor ?? _chatPanelSurface,
      borderColor: borderColor ?? primary.withOpacity(0.10),
      radius: radius,
      showShadow: false,
      child: child,
    );
  }

  Widget _buildChatPanelHeader({required String title, String? subtitle}) {
    final normalizedSubtitle = (subtitle ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _chatPanelTitleStyle),
        if (normalizedSubtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(normalizedSubtitle, style: _chatPanelSubtitleStyle),
        ],
      ],
    );
  }

  Widget _buildContractSection({
    required String title,
    required List<Widget> children,
  }) {
    return _buildChatPanelContainer(
      padding: const EdgeInsets.all(14),
      showShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _chatPanelTitleStyle.copyWith(fontSize: 14)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Future<void> _toggleContractEdit() async {
    final contractData = _contractData;
    if (contractData == null) return;

    final service =
        (contractData['service'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final payment =
        (contractData['payment'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final timeline =
        (contractData['timeline'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    if (_isEditingContract) {
      final descriptionValidationError = _validateContractDescription(
        _editableServiceDescription,
      );
      if (descriptionValidationError != null) {
        _showErrorDialog(descriptionValidationError);
        return;
      }

      final validationError = _validateContractInputs();

      if (validationError != null) {
        _showErrorDialog(validationError);
        return;
      }

      final updatedContractData = Map<String, dynamic>.from(contractData);
      final updatedService = Map<String, dynamic>.from(service);
      final updatedPayment = Map<String, dynamic>.from(payment);
      final updatedTimeline = Map<String, dynamic>.from(timeline);
      final existingCustomClauses =
          (contractData['customClauses'] as List?)?.toList() ?? [];
      final filledPendingClauses = _pendingCustomClauses
          .where(
            (clause) =>
                (clause['title'] ?? '').trim().isNotEmpty &&
                (clause['content'] ?? '').trim().isNotEmpty,
          )
          .map((clause) {
            return {
              'title': (clause['title'] ?? '').trim(),
              'content': (clause['content'] ?? '').trim(),
            };
          })
          .toList();

      updatedService['description'] = _editableServiceDescription.trim();
      updatedPayment['amount'] = _editableAmount.trim();
      updatedTimeline['deadline'] = _editableDeadline.trim();

      updatedContractData['service'] = updatedService;
      updatedContractData['payment'] = updatedPayment;
      updatedContractData['timeline'] = updatedTimeline;
      updatedContractData['customClauses'] = [
        ...existingCustomClauses,
        ...filledPendingClauses,
      ];

      setState(() {
        _isSavingContract = true;
      });

      try {
        final chatDoc = await FirebaseFirestore.instance
            .collection('chat')
            .doc(widget.chatId)
            .get();

        final requestId = _extractRequestId(chatDoc.data());

        final response = await _postContractApi(
          endpointPath: 'update-contract',
          body: {
            'requestId': requestId,
            'role': _currentUserRole(),
            'contractData': updatedContractData,
          },
          logLabel: 'Update contract',
        );

        if (!mounted) return;

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final savedContractData = data['contractData'];

          setState(() {
            if (savedContractData is Map) {
              _contractData = Map<String, dynamic>.from(savedContractData);
            }
            _isEditingContract = false;
            _isAddingClause = false;
            _pendingCustomClauses = [];
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contract updated successfully')),
          );
        } else {
          unawaited(
            _showErrorDialog(_friendlyErrorMessage(response.statusCode)),
          );
        }
      } catch (e) {
        if (!mounted) return;
        debugPrint('Update contract error: $e');
        unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
      } finally {
        if (!mounted) return;

        setState(() {
          _isSavingContract = false;
        });
      }

      return;
    }

    setState(() {
      _editableServiceDescription = (service['description'] ?? '').toString();
      _editableAmount = (payment['amount'] ?? '').toString();
      _editableDeadline = (timeline['deadline'] ?? '').toString();
      _isEditingContract = true;
      _isAddingClause = false;
      _pendingCustomClauses = [];
    });
  }

  Widget _buildContractInput({
    required String initialValue,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      maxLines: maxLines,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      validator: validator,
      autovalidateMode: validator == null
          ? AutovalidateMode.disabled
          : AutovalidateMode.onUserInteraction,
      style: const TextStyle(color: Colors.black87, height: 1.4),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: _chatPanelSurface,
        suffixIcon: suffixIcon,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _chatPanelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _chatPanelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary),
        ),
      ),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _firstFilled(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _singleLineSnippet(String rawText) {
    return rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
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

  DateTime? _parseContractDateTime(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;

    try {
      return DateTime.parse(text);
    } catch (_) {
      final parts = text.split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    }

    return null;
  }

  bool _isWithinTerminationGracePeriod() {
    final contractData = _contractData;
    if (contractData == null) return false;

    final meta = _asMap(contractData['meta']);
    final explicitDeadline = _parseContractDateTime(
      meta['terminationEligibleUntil'],
    );
    if (explicitDeadline != null) {
      return DateTime.now().isBefore(explicitDeadline) ||
          DateTime.now().isAtSameMomentAs(explicitDeadline);
    }

    final createdAt = _parseContractDateTime(
      meta['createdAtIso'] ?? meta['createdAt'],
    );
    if (createdAt == null) return false;

    final deadline = createdAt.add(const Duration(minutes: 3));
    return DateTime.now().isBefore(deadline) ||
        DateTime.now().isAtSameMomentAs(deadline);
  }

  Map<String, dynamic>? _terminationGracePeriodData() {
    final contractData = _contractData;
    if (contractData == null) return null;

    final approval = _asMap(contractData['approval']);
    final contractStatus = (approval['contractStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (contractStatus != 'approved') return null;

    final meta = _asMap(contractData['meta']);
    final startedAt = _parseContractDateTime(
      meta['createdAtIso'] ?? meta['approvedAt'] ?? meta['createdAt'],
    );
    final explicitDeadline = _parseContractDateTime(
      meta['terminationEligibleUntil'],
    );
    final effectiveDeadline =
        explicitDeadline ??
        (startedAt != null ? startedAt.add(const Duration(minutes: 3)) : null);
    if (effectiveDeadline == null) return null;

    final now = DateTime.now();
    final isExpired = now.isAfter(effectiveDeadline);
    final totalDuration = startedAt != null
        ? effectiveDeadline.difference(startedAt)
        : null;
    final remainingDuration = effectiveDeadline.difference(now);
    final remainingMinutes = remainingDuration.inMinutes.clamp(0, 1000000);
    final hours = remainingMinutes ~/ 60;
    final minutes = remainingMinutes % 60;

    String label;
    if (isExpired) {
      label = 'Expired';
    } else if (hours > 0) {
      label = '${hours}h ${minutes}m';
    } else {
      label = '${minutes}m';
    }

    double progress = 0;
    if (!isExpired && totalDuration != null && totalDuration.inSeconds > 0) {
      progress = (remainingDuration.inSeconds / totalDuration.inSeconds).clamp(
        0.0,
        1.0,
      );
    }

    Color indicatorColor;
    if (isExpired) {
      indicatorColor = const Color(0xFFC75A5A);
    } else if (progress > 0.5) {
      indicatorColor = const Color(0xFF43A047);
    } else if (progress > 0.2) {
      indicatorColor = const Color(0xFFEF6C00);
    } else {
      indicatorColor = const Color(0xFFC75A5A);
    }

    return {
      'label': label,
      'progress': progress,
      'isExpired': isExpired,
      'indicatorColor': indicatorColor,
      'subtitle': isExpired
          ? 'Free termination period has ended.'
          : 'Free termination window',
    };
  }

  String _terminationCompensationText() {
    final contractData = _contractData;
    if (contractData == null) return '20% of the contract amount';

    final payment = _asMap(contractData['payment']);
    final amountText = (payment['amount'] ?? '').toString().trim();
    final currency = (payment['currency'] ?? 'SAR').toString().trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      return '20% of the contract amount';
    }

    final compensation = amount * 0.20;
    final formattedCompensation = compensation == compensation.roundToDouble()
        ? compensation.toInt().toString()
        : compensation.toStringAsFixed(2);
    return '$formattedCompensation $currency';
  }

  double? _terminationCompensationAmount() {
    final contractData = _contractData;
    if (contractData == null) return null;

    final payment = _asMap(contractData['payment']);
    final amountText = (payment['amount'] ?? '').toString().trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return null;
    return amount * 0.20;
  }

  String _currentUserRole() {
    final otherRole = widget.otherUserRole.trim().toLowerCase();
    if (otherRole == 'client') return 'freelancer';
    return 'client';
  }

  String _normalizeContractProgressStage(dynamic value) {
    final normalized = (value ?? '').toString().trim().toLowerCase();
    switch (normalized) {
      case 'processing':
      case 'under_review':
      case 'completed':
        return normalized;
      case 'started':
      default:
        return 'started';
    }
  }

  List<String> get _contractProgressStages => const [
    'started',
    'processing',
    'under_review',
    'completed',
  ];

  int _contractProgressIndex(String stage) {
    return _contractProgressStages.indexOf(
      _normalizeContractProgressStage(stage),
    );
  }

  String _contractProgressLabel(String stage) {
    switch (_normalizeContractProgressStage(stage)) {
      case 'processing':
        return 'Processing';
      case 'under_review':
        return 'Under Review';
      case 'completed':
        return 'Completed';
      case 'started':
      default:
        return 'Started';
    }
  }

  Future<void> _switchPanels({
    required bool openApprovedContract,
    required bool openFreelancerProgress,
    required bool openWorkProgressSheet,
  }) async {
    if (!mounted || _isSwitchingPanels) return;

    final shouldCloseFirst =
        (openApprovedContract &&
            (_isFreelancerProgressPanelExpanded || _isWorkProgressSheetOpen)) ||
        (openFreelancerProgress &&
            (_isApprovedContractPanelExpanded || _isWorkProgressSheetOpen)) ||
        (openWorkProgressSheet &&
            (_isApprovedContractPanelExpanded ||
                _isFreelancerProgressPanelExpanded));

    if (shouldCloseFirst) {
      setState(() {
        _isSwitchingPanels = true;
        _isApprovedContractPanelExpanded = false;
        _isFreelancerProgressPanelExpanded = false;
        _isWorkProgressSheetOpen = false;
      });

      await Future.delayed(_panelSwitchDuration);
      if (!mounted) return;
    }

    setState(() {
      _isApprovedContractPanelExpanded = openApprovedContract;
      _isFreelancerProgressPanelExpanded = openFreelancerProgress;
      _isWorkProgressSheetOpen = openWorkProgressSheet;
      _isSwitchingPanels = false;
    });
  }

  Future<void> _toggleApprovedContractPanelSize() {
    final nextExpanded = !_isApprovedContractPanelExpanded;
    return _switchPanels(
      openApprovedContract: nextExpanded,
      openFreelancerProgress: false,
      openWorkProgressSheet: false,
    );
  }

  Future<void> _toggleFreelancerProgressPanel() {
    final nextExpanded = !_isFreelancerProgressPanelExpanded;
    return _switchPanels(
      openApprovedContract: false,
      openFreelancerProgress: nextExpanded,
      openWorkProgressSheet: false,
    );
  }

  bool _shouldShowWorkProgressAction() {
    final contractData = _contractData;
    if (contractData == null) return false;

    final approval = _asMap(contractData['approval']);
    final contractStatus = (approval['contractStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    return contractStatus == 'approved' ||
        contractStatus == 'completed' ||
        contractStatus == 'termination_pending' ||
        contractStatus == 'terminated';
  }

  Future<void> _openWorkProgressSheet() {
    final contractData = _contractData;
    if (contractData == null) {
      return Future.value();
    }

    if (!_shouldShowWorkProgressAction()) {
      return Future.value();
    }

    final nextOpen = !_isWorkProgressSheetOpen;
    return _switchPanels(
      openApprovedContract: false,
      openFreelancerProgress: false,
      openWorkProgressSheet: nextOpen,
    );
  }

  Widget _buildReviewActionSection() {
    if (!_isContractCompletedForReview(_contractData)) {
      return const SizedBox.shrink();
    }

    final existingReview = _currentUserReviewData;
    final hasSubmittedReview = existingReview != null;
    final existingRating = (() {
      final rawRating = existingReview?['rating'];
      return rawRating is num ? rawRating.toInt().clamp(0, 5) : 0;
    })();
    final existingText =
        (existingReview?['reviewText'] ?? existingReview?['text'] ?? '')
            .toString()
            .trim();

    if (hasSubmittedReview && !_isLoadingReviewData) {
      return _buildChatPanelContainer(
        padding: const EdgeInsets.all(14),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rating & Review',
                    style: _chatPanelTitleStyle.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  if (existingText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(existingText, style: _chatPanelBodyStyle),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < existingRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 18,
                      );
                    }),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'Edit Review',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                onPressed: _isSavingReview
                    ? null
                    : () => _openReviewEditor(isEditing: true),
                icon: const Icon(Icons.edit_outlined, color: primary, size: 22),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: IconButton(
                tooltip: 'Delete Review',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                onPressed: _isSavingReview ? null : _confirmDeleteReview,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFC75A5A),
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildChatPanelContainer(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rating & Review',
            style: _chatPanelTitleStyle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            hasSubmittedReview
                ? 'You already reviewed this completed service. You can edit or delete your review.'
                : 'This service is completed. You can now rate and review the other user.',
            style: _chatPanelSubtitleStyle.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_isLoadingReviewData) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primary,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Loading review status.',
                  style: TextStyle(color: primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ] else if (!hasSubmittedReview) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSavingReview ? null : () => _openReviewEditor(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.star_rounded),
                label: const Text('Rate & Review'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _contractProgressColor(String stage) {
    switch (_normalizeContractProgressStage(stage)) {
      case 'processing':
        return const Color(0xFF1565C0);
      case 'under_review':
        return const Color(0xFFEF6C00);
      case 'completed':
        return const Color(0xFF2E7D32);
      case 'started':
      default:
        return const Color(0xFF9575CD);
    }
  }

  String _normalizeDeliveryStatus(dynamic value) {
    final normalized = (value ?? '').toString().trim().toLowerCase();
    switch (normalized) {
      case 'submitted':
      case 'changes_requested':
      case 'approved_awaiting_payment':
      case 'paid_delivered':
        return normalized;
      case 'not_submitted':
      default:
        return 'not_submitted';
    }
  }

  String _deliveryStatusLabel(String status) {
    switch (_normalizeDeliveryStatus(status)) {
      case 'submitted':
        return 'Submitted';
      case 'changes_requested':
        return 'Changes Requested';
      case 'approved_awaiting_payment':
        return 'Approved Awaiting Payment';
      case 'paid_delivered':
        return 'Paid Delivered';
      case 'not_submitted':
      default:
        return 'Not Submitted';
    }
  }

  String _deliveryStatusMessage({
    required String status,
    required bool isClientView,
    required bool canSubmit,
  }) {
    switch (_normalizeDeliveryStatus(status)) {
      case 'submitted':
        return isClientView
            ? 'The freelancer submitted work and it is ready for your review.'
            : 'The submitted work is waiting for client review.';
      case 'changes_requested':
        return isClientView
            ? 'Changes have been requested. Waiting for an updated submission.'
            : 'Changes were requested. Review the feedback and resubmit when ready.';
      case 'approved_awaiting_payment':
        return isClientView
            ? 'Delivery is approved. Complete payment to unlock the final work.'
            : 'Delivery is approved and waiting for the client to complete payment.';
      case 'paid_delivered':
        return 'The final work is available to access and download.';
      case 'not_submitted':
      default:
        return canSubmit
            ? 'No work has been submitted yet. You can upload the completed work for review.'
            : 'No work has been submitted yet.';
    }
  }

  String _normalizeAdminReviewStatus(dynamic value) {
    final normalized = (value ?? '').toString().trim().toLowerCase();
    switch (normalized) {
      case 'requested':
      case 'under_review':
      case 'resolved':
        return normalized;
      case 'none':
      default:
        return 'none';
    }
  }

  String _adminReviewReasonLabel(String reasonType) {
    switch ((reasonType).trim().toLowerCase()) {
      case 'no_response':
        return 'No response';
      case 'delivery_dispute':
        return 'Delivery dispute';
      case 'inappropriate_content':
        return 'Inappropriate content';
      case 'abuse_or_manipulation':
        return 'Abuse or manipulation';
      case 'general_issue':
        return 'General issue';
      default:
        return 'General issue';
    }
  }

  String _contractReviewReasonLabel(String reasonType) {
    switch ((reasonType).trim().toLowerCase()) {
      case 'no_response':
        return 'No response from the other party';
      case 'mismatched_delivery':
        return 'Delivered work does not match the agreement';
      case 'party_disagreement':
        return 'Disagreement between both parties';
      case 'payment_delivery_issue':
        return 'Payment or delivery issue';
      case 'other_contract_issue':
      default:
        return 'Other contract issue';
    }
  }

  bool _canFreelancerSubmitWork(String contractStatus) {
    if (_currentUserRole() != 'freelancer') return false;
    if (contractStatus != 'approved') return false;

    final contractData = _contractData;
    if (contractData == null) return false;
    final progressData = _asMap(contractData['progressData']);
    final currentStage = _normalizeContractProgressStage(progressData['stage']);
    final deliveryData = _asMap(contractData['deliveryData']);
    final paymentData = _asMap(contractData['paymentData']);
    final deliveryStatus = _normalizeDeliveryStatus(deliveryData['status']);
    final paymentStatus = (paymentData['paymentStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final isPaidDelivered =
        deliveryStatus == 'paid_delivered' || paymentStatus == 'paid';
    final isLocked = isPaidDelivered || contractStatus == 'completed';

    if (isPaidDelivered || contractStatus == 'completed') return false;

    return currentStage == 'completed' &&
        (deliveryStatus == 'not_submitted' ||
            deliveryStatus == 'changes_requested');
  }

  Future<void> _saveWorkflowContractData(
    Map<String, dynamic> updatedContractData,
  ) async {
    final chatDoc = await FirebaseFirestore.instance
        .collection('chat')
        .doc(widget.chatId)
        .get();
    final requestId = _extractRequestId(chatDoc.data());

    final response = await _postContractApi(
      endpointPath: 'update-contract',
      body: {
        'requestId': requestId,
        'role': _currentUserRole(),
        'contractData': updatedContractData,
      },
      logLabel: 'Save workflow contract',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_friendlyErrorMessage(response.statusCode));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final savedContractData = data['contractData'];

    if (savedContractData is Map) {
      _contractData = Map<String, dynamic>.from(savedContractData);
    }
  }

  Future<void> _submitDeliveryWork() async {
    final contractData = _contractData;
    if (contractData == null) return;

    try {
      final deliveryFiles = await _pickDeliveryImagesForSubmission();
      if (deliveryFiles == null || deliveryFiles.isEmpty) return;

      setState(() {
        _isSavingContract = true;
      });

      final uploadedUrls = await _controller.uploadDeliveryImages(
        chatId: widget.chatId,
        imageFiles: deliveryFiles,
      );

      final updatedContractData = Map<String, dynamic>.from(contractData);
      final deliveryData = _asMap(updatedContractData['deliveryData']);
      deliveryData['status'] = 'submitted';
      deliveryData['previewImageUrls'] = uploadedUrls;
      deliveryData['submittedBy'] = _currentUserRole();
      deliveryData['submittedAt'] = DateTime.now().toIso8601String();
      deliveryData['changesRequestedBy'] = '';
      deliveryData['changesRequestedAt'] = '';
      deliveryData['approvedBy'] = '';
      deliveryData['approvedAt'] = '';
      deliveryData['finalWorkUrls'] = <String>[];
      deliveryData['finalWorkUploadedBy'] = '';
      deliveryData['finalWorkUploadedAt'] = '';
      updatedContractData['deliveryData'] = deliveryData;

      await _saveWorkflowContractData(updatedContractData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work submitted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Submit delivery error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingContract = false;
      });
    }
  }

  Future<void> _requestDeliveryChanges() async {
    final contractData = _contractData;
    if (contractData == null) return;

    setState(() {
      _isSavingContract = true;
    });

    try {
      final updatedContractData = Map<String, dynamic>.from(contractData);
      final deliveryData = _asMap(updatedContractData['deliveryData']);
      deliveryData['status'] = 'changes_requested';
      deliveryData['changesRequestedBy'] = _currentUserRole();
      deliveryData['changesRequestedAt'] = DateTime.now().toIso8601String();
      updatedContractData['deliveryData'] = deliveryData;

      await _saveWorkflowContractData(updatedContractData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes requested successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Request delivery changes error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingContract = false;
      });
    }
  }

  Future<void> _approveDeliveryForPayment() async {
    final contractData = _contractData;
    if (contractData == null) return;

    setState(() {
      _isSavingContract = true;
    });

    try {
      final updatedContractData = Map<String, dynamic>.from(contractData);
      final deliveryData = _asMap(updatedContractData['deliveryData']);
      deliveryData['status'] = 'approved_awaiting_payment';
      deliveryData['approvedBy'] = _currentUserRole();
      deliveryData['approvedAt'] = DateTime.now().toIso8601String();
      updatedContractData['deliveryData'] = deliveryData;

      await _saveWorkflowContractData(updatedContractData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery approved. Waiting for payment')),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Approve delivery error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingContract = false;
      });
    }
  }

  Future<void> _withdrawDeliverySubmission() async {
    final contractData = _contractData;
    if (contractData == null) return;

    final shouldWithdraw = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Withdraw Submission'),
          content: const Text(
            'Do you want to withdraw the submitted work and return it to draft state?',
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC75A5A),
                backgroundColor: Colors.transparent,
                side: const BorderSide(color: Color(0xFFC75A5A), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                backgroundColor: Colors.transparent,
                side: BorderSide(color: primary, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Withdraw'),
            ),
          ],
        );
      },
    );

    if (shouldWithdraw != true || !mounted) return;

    setState(() {
      _isSavingContract = true;
    });

    try {
      final updatedContractData = Map<String, dynamic>.from(contractData);
      final deliveryData = _asMap(updatedContractData['deliveryData']);
      deliveryData['status'] = 'not_submitted';
      deliveryData['previewImageUrls'] = <String>[];
      deliveryData['submittedBy'] = '';
      deliveryData['submittedAt'] = '';
      deliveryData['changesRequestedBy'] = '';
      deliveryData['changesRequestedAt'] = '';
      deliveryData['approvedBy'] = '';
      deliveryData['approvedAt'] = '';
      updatedContractData['deliveryData'] = deliveryData;

      await _saveWorkflowContractData(updatedContractData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submitted work withdrawn successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Withdraw delivery submission error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingContract = false;
      });
    }
  }

  Future<void> _requestAdminReview() async {
    final contractData = _contractData;
    if (contractData == null) return;

    const options = <Map<String, String>>[
      {'value': 'delivery_dispute', 'label': 'Delivery dispute'},
      {'value': 'inappropriate_content', 'label': 'Inappropriate content'},
      {'value': 'abuse_or_manipulation', 'label': 'Abuse or manipulation'},
      {'value': 'general_issue', 'label': 'General issue'},
    ];

    final selectedReason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Request Admin Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose the reason for requesting admin review.'),
              const SizedBox(height: 12),
              ...options.map((option) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(option['value']),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(color: primary.withOpacity(0.22)),
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
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC75A5A),
                side: const BorderSide(color: Color(0xFFC75A5A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selectedReason == null || !mounted) return;

    setState(() {
      _isSavingContract = true;
    });

    try {
      final updatedContractData = Map<String, dynamic>.from(contractData);
      final adminReview = _asMap(updatedContractData['adminReview']);
      adminReview['status'] = 'requested';
      adminReview['requestedBy'] = _currentUserRole();
      adminReview['requestedAt'] = DateTime.now().toIso8601String();
      adminReview['reasonType'] = selectedReason;
      adminReview['reasonText'] = _adminReviewReasonLabel(selectedReason);
      adminReview['relatedArea'] = 'chat_delivery';
      updatedContractData['adminReview'] = adminReview;

      await _saveWorkflowContractData(updatedContractData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin review requested successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Request admin review error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingContract = false;
      });
    }
  }

  Future<void> _withdrawAdminReview() async {
    final contractData = _contractData;
    if (contractData == null) return;

    final shouldWithdraw = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Withdraw Complaint'),
          content: const Text(
            'Do you want to withdraw this admin review request?',
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC75A5A),
                backgroundColor: Colors.transparent,
                side: const BorderSide(color: Color(0xFFC75A5A), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                backgroundColor: Colors.transparent,
                side: BorderSide(color: primary, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Withdraw'),
            ),
          ],
        );
      },
    );

    if (shouldWithdraw != true || !mounted) return;

    setState(() {
      _isSavingContract = true;
    });

    try {
      final updatedContractData = Map<String, dynamic>.from(contractData);
      updatedContractData['adminReview'] = {
        'status': 'none',
        'requestedBy': '',
        'requestedAt': '',
        'reasonType': '',
        'reasonText': '',
        'relatedArea': '',
      };

      await _saveWorkflowContractData(updatedContractData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint withdrawn successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Withdraw admin review error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingContract = false;
      });
    }
  }

  Future<String> _resolveRequestIdForContractReview() async {
    final cachedRequestId = (_requestId ?? '').trim();
    if (cachedRequestId.isNotEmpty) {
      return cachedRequestId;
    }

    final chatDoc = await FirebaseFirestore.instance
        .collection('chat')
        .doc(widget.chatId)
        .get();
    final requestId = _extractRequestId(chatDoc.data());
    _requestId = requestId;
    return requestId;
  }

  String _contractTerminationReportDocumentId({
    required String requestId,
    required String reporterId,
  }) {
    return 'termination_${requestId}_$reporterId';
  }

  String _terminationAdminReviewReasonLabel(String reasonType) {
    switch (reasonType.trim().toLowerCase()) {
      case 'no_response':
        return 'No response from the other party';
      case 'mismatched_delivery':
        return 'Delivered work does not match the agreement';
      case 'party_disagreement':
        return 'Disagreement between both parties';
      default:
        return 'Contract review';
    }
  }

  Future<void> _openContractTerminationAdminReviewSheet() async {
    final currentUserId = (_controller.currentUserId ?? '').trim();
    final otherPartyId = widget.otherUserId.trim();

    if (currentUserId.isEmpty || otherPartyId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User information is not available for this review.'),
        ),
      );
      return;
    }

    final detailsController = TextEditingController();
    final messenger = ScaffoldMessenger.maybeOf(context);
    String? selectedReason;
    bool isSubmitting = false;
    bool isSheetActive = true;

    const reasonOptions = <Map<String, String>>[
      {
        'value': 'no_response',
        'label': 'No response from the other party',
      },
      {
        'value': 'mismatched_delivery',
        'label': 'Delivered work does not match the agreement',
      },
      {
        'value': 'party_disagreement',
        'label': 'Disagreement between both parties',
      },
    ];

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Future<void> submitReview() async {
                if (selectedReason == null || selectedReason!.trim().isEmpty) {
                  messenger
                    ?..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Choose a reason before submitting'),
                      ),
                    );
                  return;
                }

                if (isSheetActive) {
                  setSheetState(() {
                    isSubmitting = true;
                  });
                }

                try {
                  final requestId = await _resolveRequestIdForContractReview();
                  final contractData = _contractData;
                  final meta = _asMap(contractData?['meta']);
                  final approval = _asMap(contractData?['approval']);
                  final contractId = (meta['contractId'] ?? requestId)
                      .toString()
                      .trim();
                  final contractStatus = (approval['contractStatus'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase();

                  final currentUserDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId)
                      .get();
                  final currentUserData =
                      currentUserDoc.data() ?? <String, dynamic>{};
                  final reporterName = _displayName(currentUserData, 'User');
                  final otherPartyName = widget.otherUserName.trim().isEmpty
                      ? 'User'
                      : widget.otherUserName.trim();

                  final reviewRef = FirebaseFirestore.instance
                      .collection('contract_reports')
                      .doc(
                        _contractTerminationReportDocumentId(
                          requestId: requestId,
                          reporterId: currentUserId,
                        ),
                      );

                  await reviewRef.set({
                    'type': 'contract_review',
                    'reasonType': selectedReason,
                    'reasonLabel': _terminationAdminReviewReasonLabel(
                      selectedReason!,
                    ),
                    'details': detailsController.text.trim(),
                    'requestId': requestId,
                    'contractId': contractId.isEmpty ? requestId : contractId,
                    'chatId': widget.chatId,
                    'reporterId': currentUserId,
                    'reporterName': reporterName,
                    'otherPartyId': otherPartyId,
                    'otherPartyName': otherPartyName,
                    'otherUserId': otherPartyId,
                    'contractStatus': contractStatus,
                    'status': 'requested',
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));

                  isSheetActive = false;
                  if (Navigator.of(sheetContext).canPop()) {
                    Navigator.of(sheetContext).pop();
                  }

                  if (!mounted) return;
                  messenger
                    ?..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Contract review request submitted'),
                      ),
                    );
                } catch (e) {
                  if (!mounted) return;
                  debugPrint('Termination contract review error: $e');
                  messenger
                    ?..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to submit contract review: ${_friendlyErrorMessage(e)}',
                        ),
                      ),
                    );
                } finally {
                  if (isSheetActive) {
                    setSheetState(() {
                      isSubmitting = false;
                    });
                  }
                }
              }

              return SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom:
                        MediaQuery.of(sheetContext).viewInsets.bottom + 12,
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Request Admin Review',
                          style: TextStyle(
                            color: primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Choose the reason for requesting admin review.',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...reasonOptions.map((option) {
                          final value = option['value']!;
                          final label = option['label']!;
                          final isSelected = selectedReason == value;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: isSubmitting
                                  ? null
                                  : () {
                                      setSheetState(() {
                                        selectedReason = value;
                                      });
                                    },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFF2EAFB)
                                      : const Color(0xFFF8F6FC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? primary
                                        : primary.withOpacity(0.12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      color: primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                        TextField(
                          controller: detailsController,
                          maxLines: 4,
                          enabled: !isSubmitting,
                          decoration: InputDecoration(
                            labelText: 'Add details for the admin',
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: const Color(0xFFF8F6FC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: primary.withOpacity(0.12),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: primary.withOpacity(0.12),
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(16),
                              ),
                              borderSide: BorderSide(color: primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () {
                                        isSheetActive = false;
                                        Navigator.of(sheetContext).pop();
                                      },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primary,
                                  side: BorderSide(
                                    color: primary.withOpacity(0.20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isSubmitting ? null : submitReview,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Submit'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      detailsController.dispose();
    }
  }

  Future<Map<String, dynamic>?> _loadTerminationContractReview() async {
    final reporterId = (_controller.currentUserId ?? '').trim();
    if (reporterId.isEmpty) return null;

    final requestId = await _resolveRequestIdForContractReview();
    final reviewDoc = await FirebaseFirestore.instance
        .collection('contract_reports')
        .doc(
          _contractTerminationReportDocumentId(
            requestId: requestId,
            reporterId: reporterId,
          ),
        )
        .get();

    if (!reviewDoc.exists) return null;

    return <String, dynamic>{'reviewId': reviewDoc.id, ...?reviewDoc.data()};
  }

  Future<void> _showTerminationContractReviewStatusDialog(
    Map<String, dynamic> reviewData,
  ) {
    final normalizedStatus = (reviewData['status'] ?? 'requested')
        .toString()
        .trim()
        .toLowerCase();
    final reasonLabel =
        (reviewData['reasonLabel'] ??
                _contractReviewReasonLabel(
                  (reviewData['reasonType'] ?? '').toString(),
                ))
            .toString();
    final details = (reviewData['details'] ?? '').toString().trim();
    final statusTitle = normalizedStatus == 'resolved'
        ? 'Contract Review Resolved'
        : normalizedStatus == 'under_review'
        ? 'Contract Review In Progress'
        : 'Contract Review Requested';

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(statusTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                normalizedStatus == 'resolved'
                    ? 'This contract review has already been resolved.'
                    : 'Your contract review request has already been submitted.',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Reason: $reasonLabel',
                style: const TextStyle(color: Colors.black87, fontSize: 12.5),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Details: $details',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary.withOpacity(0.24)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openTerminationContractReviewSheet() async {
    final currentUserId = (_controller.currentUserId ?? '').trim();
    if (currentUserId.isEmpty) {
      await _showErrorDialog('Current user not found');
      return;
    }

    final normalizedOtherUserId = widget.otherUserId.trim();
    if (normalizedOtherUserId.isEmpty) {
      await _showErrorDialog('The other user is not available');
      return;
    }

    const options = <Map<String, String>>[
      {'value': 'no_response', 'label': 'No response from the other party'},
      {
        'value': 'mismatched_delivery',
        'label': 'Delivered work does not match the agreement',
      },
      {
        'value': 'party_disagreement',
        'label': 'Disagreement between both parties',
      },
    ];

    final detailsController = TextEditingController();
    final messenger = ScaffoldMessenger.maybeOf(context);
    String selectedReason = '';
    bool isSubmitting = false;
    bool isSheetActive = true;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetBodyContext, setSheetState) {
              final bottomInset = MediaQuery.of(
                sheetBodyContext,
              ).viewInsets.bottom;

              Future<void> submitReviewRequest() async {
                if (selectedReason.trim().isEmpty) {
                  messenger
                    ?..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Choose a reason before submitting'),
                      ),
                    );
                  return;
                }

                if (isSheetActive) {
                  setSheetState(() {
                    isSubmitting = true;
                  });
                }

                try {
                  final requestId = await _resolveRequestIdForContractReview();
                  final contractData = _contractData;
                  final meta = _asMap(contractData?['meta']);
                  final approval = _asMap(contractData?['approval']);
                  final contractId = (meta['contractId'] ?? requestId)
                      .toString()
                      .trim();
                  final contractStatus = (approval['contractStatus'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase();
                  final reviewRef = FirebaseFirestore.instance
                      .collection('contract_reports')
                      .doc(
                        _contractTerminationReportDocumentId(
                          requestId: requestId,
                          reporterId: currentUserId,
                        ),
                      );
                  final existingReview = await reviewRef.get();

                  final payload = <String, dynamic>{
                    'type': 'contract_review',
                    'source': 'contract_termination',
                    'reasonType': selectedReason,
                    'reasonLabel': _contractReviewReasonLabel(selectedReason),
                    'details': detailsController.text.trim(),
                    'requestId': requestId,
                    'contractId': contractId.isEmpty ? requestId : contractId,
                    'chatId': widget.chatId,
                    'reporterId': currentUserId,
                    'reportedUserId': normalizedOtherUserId,
                    'otherUserId': normalizedOtherUserId,
                    'contractStatus': contractStatus,
                    'status': 'requested',
                    'updatedAt': FieldValue.serverTimestamp(),
                  };

                  if (!existingReview.exists) {
                    payload['createdAt'] = FieldValue.serverTimestamp();
                  }

                  await reviewRef.set(payload, SetOptions(merge: true));

                  if (!mounted) return;
                  isSheetActive = false;
                  if (Navigator.of(sheetContext).canPop()) {
                    Navigator.of(sheetContext).pop();
                  }
                  if (!mounted) return;
                  messenger
                    ?..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Contract review request submitted'),
                      ),
                    );
                } catch (e) {
                  if (!mounted) return;
                  debugPrint('Termination contract review error: $e');
                  messenger
                    ?..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to submit contract review: ${_friendlyErrorMessage(e)}',
                        ),
                      ),
                    );
                } finally {
                  if (isSheetActive) {
                    setSheetState(() {
                      isSubmitting = false;
                    });
                  }
                }
              }

              return SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomInset),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD8D3E5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Request Admin Review',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Choose the reason for requesting admin review.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...options.map((option) {
                          final value = option['value']!;
                          final label = option['label']!;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selectedReason == value
                                    ? primary.withOpacity(0.26)
                                    : _chatPanelBorder,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: isSubmitting
                                  ? null
                                  : () {
                                      setSheetState(() {
                                        selectedReason = value;
                                      });
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Radio<String>(
                                      value: value,
                                      groupValue: selectedReason,
                                      onChanged: isSubmitting
                                          ? null
                                          : (nextValue) {
                                              setSheetState(() {
                                                selectedReason =
                                                    nextValue ?? '';
                                              });
                                            },
                                      activeColor: primary,
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.support_agent_outlined,
                                      size: 18,
                                      color: primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        TextField(
                          controller: detailsController,
                          maxLines: 4,
                          minLines: 3,
                          enabled: !isSubmitting,
                          decoration: InputDecoration(
                            labelText: 'Add details for the admin',
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: _chatPanelSurface,
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: _chatPanelBorder,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: _chatPanelBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : submitReviewRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Submit Review Request'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ).whenComplete(() {
        isSheetActive = false;
      });
    } finally {
      detailsController.dispose();
    }
  }

  Future<void> _handleTerminationContractAdminReviewAction() async {
    try {
      final existingReview = await _loadTerminationContractReview();

      if (existingReview != null) {
        await _showTerminationContractReviewStatusDialog(existingReview);
        return;
      }

      await _openTerminationContractReviewSheet();
    } catch (e) {
      if (!mounted) return;
      debugPrint('Handle termination contract review action error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    }
  }

  IconData _contractProgressIcon(String stage) {
    switch (_normalizeContractProgressStage(stage)) {
      case 'processing':
        return Icons.sync_rounded;
      case 'under_review':
        return Icons.rate_review_rounded;
      case 'completed':
        return Icons.task_alt_rounded;
      case 'started':
      default:
        return Icons.play_circle_outline_rounded;
    }
  }

  Future<void> _updateContractProgress(String stage) async {
    final contractData = _contractData;
    if (contractData == null) return;

    final normalizedStage = _normalizeContractProgressStage(stage);
    final currentProgress = _asMap(contractData['progressData']);
    if (_normalizeContractProgressStage(currentProgress['stage']) ==
        normalizedStage) {
      return;
    }

    setState(() {
      _isSavingContract = true;
    });

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chat')
          .doc(widget.chatId)
          .get();

      final chatData = chatDoc.data();
      final requestId = _extractRequestId(chatData);
      final updatedContractData = Map<String, dynamic>.from(contractData);
      final updatedProgressData = _asMap(updatedContractData['progressData']);

      updatedProgressData['stage'] = normalizedStage;
      updatedProgressData['updatedAt'] = DateTime.now().toIso8601String();
      updatedProgressData['updatedBy'] = _currentUserRole();
      updatedContractData['progressData'] = updatedProgressData;

      final response = await _postContractApi(
        endpointPath: 'update-contract',
        body: {
          'requestId': requestId,
          'role': _currentUserRole(),
          'contractData': updatedContractData,
        },
        logLabel: 'Update contract progress',
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final savedContractData = data['contractData'];

        setState(() {
          if (savedContractData is Map) {
            _contractData = Map<String, dynamic>.from(savedContractData);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Progress updated to ${_contractProgressLabel(normalizedStage)}',
            ),
          ),
        );
      } else {
        unawaited(_showErrorDialog(_friendlyErrorMessage(response.statusCode)));
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Update progress error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (!mounted) return;

      setState(() {
        _isSavingContract = false;
      });
    }
  }

  Widget _buildContractProgressSection({
    required String contractStatus,
    required String currentUserRole,
    bool showSectionTitle = true,
    Color? surfaceColor,
  }) {
    final contractData = _contractData;
    if (contractData == null) return const SizedBox.shrink();

    final shouldShowProgress =
        contractStatus == 'approved' ||
        contractStatus == 'completed' ||
        contractStatus == 'termination_pending' ||
        contractStatus == 'terminated';

    if (!shouldShowProgress) return const SizedBox.shrink();

    final progressData = _asMap(contractData['progressData']);
    final currentStage = _normalizeContractProgressStage(progressData['stage']);
    final currentStageIndex = _contractProgressIndex(currentStage);
    final currentStageColor = _contractProgressColor(currentStage);
    final showClientTimeline = currentUserRole == 'client';
    final deliveryData = _asMap(contractData['deliveryData']);
    final paymentData = _asMap(contractData['paymentData']);
    final deliveryStatus = _normalizeDeliveryStatus(deliveryData['status']);
    final paymentStatus = (paymentData['paymentStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final isPaidDelivered =
        deliveryStatus == 'paid_delivered' || paymentStatus == 'paid';
    final isLocked = isPaidDelivered || contractStatus == 'completed';

    final progressContent = _buildChatPanelSurface(
      padding: const EdgeInsets.all(12),
      backgroundColor: surfaceColor ?? _chatPanelSurface,
      borderColor: currentStageColor.withOpacity(0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showClientTimeline)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _contractProgressStages.asMap().entries.map((
                      entry,
                    ) {
                      final index = entry.key;
                      final stage = entry.value;
                      final isCurrent = index == currentStageIndex;
                      final isPassed = index < currentStageIndex;
                      final isReached = index <= currentStageIndex;
                      final completedLineColor = const Color(0xFF66BB6A);
                      final circleColor = isReached
                          ? completedLineColor
                          : const Color(0xFFE6E6E6);
                      final textColor = isCurrent
                          ? Colors.black87
                          : isPassed
                          ? Colors.black87
                          : Colors.black54;

                      return Expanded(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                if (index > 0)
                                  Expanded(
                                    child: Container(
                                      height: 3,
                                      color: isReached
                                          ? completedLineColor
                                          : const Color(0xFFE6E6E6),
                                    ),
                                  ),
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: circleColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isReached
                                          ? circleColor
                                          : const Color(0xFFD6D6D6),
                                    ),
                                  ),
                                  child: isReached
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 11,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                if (index < _contractProgressStages.length - 1)
                                  Expanded(
                                    child: Container(
                                      height: 3,
                                      color: isPassed
                                          ? completedLineColor
                                          : const Color(0xFFE6E6E6),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _contractProgressLabel(stage),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            )
          else
            Column(
              children: _contractProgressStages.asMap().entries.map((entry) {
                final stage = entry.value;
                final stageIndex = entry.key;
                final isCurrent = stage == currentStage;
                final isCompleted = stageIndex <= currentStageIndex;
                final completedCheckColor = const Color(0xFF66BB6A);

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: stageIndex == _contractProgressStages.length - 1
                        ? 0
                        : 10,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: (_isSavingContract || isLocked)
                        ? null
                        : () => _updateContractProgress(stage),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      decoration: BoxDecoration(
                        color: _chatPanelBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xFFBDBDBD)
                              : const Color(0xFFE0E0E0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? completedCheckColor
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isCompleted
                                    ? completedCheckColor
                                    : const Color(0xFFBDBDBD),
                              ),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: isCompleted
                                  ? Colors.white
                                  : const Color(0xFFBDBDBD),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _contractProgressLabel(stage),
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );

    if (!showSectionTitle) {
      return progressContent;
    }

    return _buildContractSection(
      title: 'Work Progress',
      children: [progressContent],
    );
  }

  Widget _buildInlineWorkProgressHeader() {
    final progressData = _asMap(_contractData?['progressData']);
    final currentStage = _normalizeContractProgressStage(progressData['stage']);

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _chatPanelSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _chatPanelBorder),
          ),
          child: const Icon(Icons.timeline_rounded, size: 18, color: primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Work Progress',
                style: TextStyle(
                  color: primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _contractProgressLabel(currentStage),
                style: TextStyle(
                  color: Colors.black.withOpacity(0.62),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinnedApprovedContractCard({
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(12, 8, 12, 8),
    double? expandedBodyMaxHeight,
    bool fillAvailableHeight = false,
  }) {
    final contractData = _contractData;
    if (contractData == null) return const SizedBox.shrink();

    final approval = _asMap(contractData['approval']);
    final contractStatus = (approval['contractStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final deliveryData = _asMap(contractData['deliveryData']);
    final paymentData = _asMap(contractData['paymentData']);
    final deliveryStatus = _normalizeDeliveryStatus(deliveryData['status']);
    final paymentStatus = (paymentData['paymentStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final isPaidDelivered =
        deliveryStatus == 'paid_delivered' || paymentStatus == 'paid';

    if (contractStatus != 'approved' &&
        contractStatus != 'completed' &&
        !isPaidDelivered) {
      return const SizedBox.shrink();
    }

    final meta = _asMap(contractData['meta']);
    final service = _asMap(contractData['service']);
    final payment = _asMap(contractData['payment']);
    final timeline = _asMap(contractData['timeline']);
    final description = (service['description'] ?? '').toString().trim();
    final amount = (payment['amount'] ?? '').toString().trim();
    final deadline = (timeline['deadline'] ?? '').toString().trim();

    final isCompleted = contractStatus == 'completed' || isPaidDelivered;
    final canDownloadFinalWork =
        deliveryStatus == 'paid_delivered' ||
        contractStatus == 'completed' ||
        paymentStatus == 'paid';
    final isLocked = isPaidDelivered || contractStatus == 'completed';
    final isClientView = _currentUserRole() == 'client';
    final approvedPanelBody = Column(
      mainAxisSize: fillAvailableHeight ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: _buildApprovedPanelTabs(),
        ),
        const SizedBox(height: 12),
        if (fillAvailableHeight)
          Expanded(
            child: _buildApprovedPanelTabContent(
              expandedBodyMaxHeight: expandedBodyMaxHeight ?? 320,
            ),
          )
        else
          _buildApprovedPanelTabContent(
            expandedBodyMaxHeight: expandedBodyMaxHeight ?? 320,
          ),
      ],
    );
    return Container(
      width: double.infinity,
      margin: margin,
      decoration: _chatPanelDecoration(
        backgroundColor: _chatPanelShellBackground,
        borderColor: _chatPanelBorder,
        radius: 18,
      ),
      child: Column(
        mainAxisSize: fillAvailableHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: _pinnedPanelHeaderMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Workspace',
                          style: TextStyle(
                            color: primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFF7C3AED).withOpacity(0.12)
                                : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isCompleted ? 'Completed' : 'Approved',
                            style: TextStyle(
                              color: isCompleted
                                  ? const Color(0xFF7C3AED)
                                  : const Color(0xFF2E7D32),
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: _chatPanelDecoration(
                      backgroundColor: _chatPanelSurface,
                      borderColor: _chatPanelBorder,
                      radius: 999,
                      showShadow: false,
                    ),
                    child: IconButton(
                      onPressed: _isSwitchingPanels
                          ? null
                          : _toggleApprovedContractPanelSize,
                      icon: Icon(
                        _isApprovedContractPanelExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                      ),
                      color: primary,
                      tooltip: _isApprovedContractPanelExpanded
                          ? 'Collapse'
                          : 'Expand',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isApprovedContractPanelExpanded) ...[
            Divider(height: 1, color: primary.withOpacity(0.08)),
            if (fillAvailableHeight)
              Expanded(child: approvedPanelBody)
            else
              approvedPanelBody,
          ],
        ],
      ),
    );
  }

  Widget _buildPinnedFreelancerProgressCard({
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(12, 0, 12, 8),
    double? expandedBodyMaxHeight,
  }) {
    final contractData = _contractData;
    if (contractData == null) return const SizedBox.shrink();
    if (_currentUserRole() != 'freelancer') {
      return const SizedBox.shrink();
    }

    final approval = _asMap(contractData['approval']);
    final contractStatus = (approval['contractStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (contractStatus != 'approved' && contractStatus != 'completed') {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: margin,
      decoration: _chatPanelDecoration(
        backgroundColor: _chatPanelShellBackground,
        borderColor: _chatPanelBorder,
        radius: 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: _pinnedPanelHeaderMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Text(
                      'Work Progress',
                      style: TextStyle(
                        color: primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    decoration: _chatPanelDecoration(
                      backgroundColor: _chatPanelSurface,
                      borderColor: _chatPanelBorder,
                      radius: 999,
                      showShadow: false,
                    ),
                    child: IconButton(
                      onPressed: _isSwitchingPanels
                          ? null
                          : _toggleFreelancerProgressPanel,
                      icon: Icon(
                        _isFreelancerProgressPanelExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                      ),
                      color: primary,
                      tooltip: _isFreelancerProgressPanelExpanded
                          ? 'Collapse'
                          : 'Expand',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isFreelancerProgressPanelExpanded) ...[
            Divider(height: 1, color: primary.withOpacity(0.08)),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: expandedBodyMaxHeight ?? double.infinity,
              ),
              child: Scrollbar(
                controller: _freelancerProgressPanelScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _freelancerProgressPanelScrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildContractProgressSection(
                      contractStatus: contractStatus,
                      currentUserRole: _currentUserRole(),
                      showSectionTitle: false,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPinnedFreelancerPanelsRow() {
    final maxExpandedBodyHeight = MediaQuery.of(context).size.height * 0.28;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildPinnedApprovedContractCard(
              margin: EdgeInsets.zero,
              expandedBodyMaxHeight: maxExpandedBodyHeight,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildPinnedFreelancerProgressCard(
              margin: EdgeInsets.zero,
              expandedBodyMaxHeight: maxExpandedBodyHeight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedApprovedContractScrollable({
    bool overlayExpandedPanel = false,
  }) {
    if (!overlayExpandedPanel) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: _buildPinnedApprovedContractCard(margin: EdgeInsets.zero),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.of(context).size.height;
        final availableHeight = constraints.maxHeight;
        final cappedPanelHeight = availableHeight > screenHeight * 0.95
            ? screenHeight * 0.95
            : availableHeight;
        final maxPanelHeight = cappedPanelHeight > 8
            ? cappedPanelHeight - 8
            : cappedPanelHeight;
        final maxExpandedBodyHeight =
            maxPanelHeight - _pinnedPanelHeaderMinHeight - 18;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: maxPanelHeight,
              child: _buildPinnedApprovedContractCard(
                margin: EdgeInsets.zero,
                expandedBodyMaxHeight: maxExpandedBodyHeight,
                fillAvailableHeight: true,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMoyasarPayment() async {
    final contractData = _contractData;
    if (contractData == null) return;

    final payment = _asMap(contractData['payment']);
    final amountText = (payment['amount'] ?? '').toString().trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      await _showErrorDialog('Invalid payment amount');
      return;
    }

    final amountInHalalas = (amount * 100).round();

    final paymentConfig = PaymentConfig(
      publishableApiKey: moyasarPublishableKey,
      amount: amountInHalalas,
      description: 'Contract Payment',
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Payment')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CreditCard(
              config: paymentConfig,
              onPaymentResult: (result) async {
                if (result is PaymentResponse &&
                    result.status == PaymentStatus.paid) {
                  try {
                    await _verifyPayment(result.id);

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payment completed successfully'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      await _showErrorDialog(_friendlyErrorMessage(e));
                    }
                  }
                } else {
                  await _showErrorDialog('Payment failed');
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTerminationCompensationPayment() async {
    final compensationAmount = _terminationCompensationAmount();
    if (compensationAmount == null || compensationAmount <= 0) {
      await _showErrorDialog('Invalid compensation amount');
      return;
    }

    final amountInHalalas = (compensationAmount * 100).round();
    final paymentConfig = PaymentConfig(
      publishableApiKey: moyasarPublishableKey,
      amount: amountInHalalas,
      description: 'Termination Compensation (20%)',
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Termination Payment')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD54F)),
                  ),
                  child: Text(
                    'Termination with 20% compensation: ${_terminationCompensationText()}',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: CreditCard(
                    config: paymentConfig,
                    onPaymentResult: (result) async {
                      if (result is PaymentResponse &&
                          result.status == PaymentStatus.paid) {
                        try {
                          await _verifyTerminationCompensationPayment(
                            result.id,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Termination payment completed successfully',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            await _showErrorDialog(_friendlyErrorMessage(e));
                          }
                        }
                      } else {
                        await _showErrorDialog('Payment failed');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _verifyPayment(String paymentId) async {
    final chatDoc = await FirebaseFirestore.instance
        .collection('chat')
        .doc(widget.chatId)
        .get();

    final chatData = chatDoc.data();
    final requestId = _extractRequestId(chatData);

    debugPrint('Verify payment paymentId: $paymentId');
    debugPrint('Verify payment requestId: $requestId');

    final response = await _postContractApi(
      endpointPath: 'verify-payment',
      body: {
        'paymentId': paymentId,
        'requestId': requestId,
        'paidBy': _controller.currentUserId,
      },
      logLabel: 'Verify payment',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final errorMessage = (decoded['error'] ?? 'Payment verification failed')
          .toString();
      throw Exception(errorMessage);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final returnedContractData = decoded['contractData'];
    if (returnedContractData is Map) {
      setState(() {
        _contractData = Map<String, dynamic>.from(returnedContractData);
      });
    }

    await _createContractNotification(
      type: 'contract_payment_completed',
      actionText: 'The client completed the payment successfully',
      requestId: requestId,
      chatData: chatData,
      contractData: returnedContractData is Map
          ? Map<String, dynamic>.from(returnedContractData)
          : null,
    );

    await _refreshContractDataFromSource();
  }

  Future<void> _verifyTerminationCompensationPayment(String paymentId) async {
    final chatDoc = await FirebaseFirestore.instance
        .collection('chat')
        .doc(widget.chatId)
        .get();

    final chatData = chatDoc.data();
    final requestId = _extractRequestId(chatData);

    final response = await _postContractApi(
      endpointPath: 'verify-termination-payment',
      body: {
        'paymentId': paymentId,
        'requestId': requestId,
        'paidBy': _currentUserRole(),
      },
      logLabel: 'Verify termination payment',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final errorMessage =
          (decoded['error'] ?? 'Termination payment verification failed')
              .toString();
      throw Exception(errorMessage);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final updatedContractData = decoded['contractData'];
    final normalizedContractData = updatedContractData is Map
        ? Map<String, dynamic>.from(updatedContractData)
        : null;

    if (normalizedContractData != null && mounted) {
      setState(() {
        _contractData = normalizedContractData;
      });
    }

    await _createContractNotification(
      type: 'contract_terminated',
      actionText: 'terminated the contract with 20% compensation',
      requestId: requestId,
      chatData: chatData,
      contractData: normalizedContractData,
    );

    await _refreshContractDataFromSource();
  }

  Widget _buildDeliverySection(String contractStatus) {
    final contractData = _contractData;
    if (contractData == null) return const SizedBox.shrink();
    if (contractStatus != 'approved') return const SizedBox.shrink();

    final deliveryData = _asMap(contractData['deliveryData']);
    final progressData = _asMap(contractData['progressData']);
    final currentStage = _normalizeContractProgressStage(progressData['stage']);
    final deliveryStatus = _normalizeDeliveryStatus(deliveryData['status']);
    final previewImageUrls =
        (deliveryData['previewImageUrls'] as List?)
            ?.map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList() ??
        const <String>[];
    final isClient = _currentUserRole() == 'client';
    final isFreelancer = _currentUserRole() == 'freelancer';
    final canSubmit = _canFreelancerSubmitWork(contractStatus);
    final showEmptyState =
        deliveryStatus == 'not_submitted' && previewImageUrls.isEmpty;

    return _buildChatPanelContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Submitted Work',
            style: _chatPanelTitleStyle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 10),
          if (showEmptyState) ...[
            const Text(
              'No work has been submitted yet.',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (isFreelancer &&
              !canSubmit &&
              (deliveryStatus == 'not_submitted' ||
                  deliveryStatus == 'changes_requested')) ...[
            Text(
              currentStage == 'completed'
                  ? 'Work delivery will be available now.'
                  : 'Work delivery will be enabled when progress reaches Completed.',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: primary.withOpacity(0.35),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(
                  deliveryStatus == 'changes_requested'
                      ? 'Resubmit Work'
                      : 'Submit Work',
                ),
              ),
            ),
          ],
          if (canSubmit) ...[
            const Text(
              'You can now submit the completed work for client review.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSavingContract ? null : _submitDeliveryWork,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(
                  deliveryStatus == 'changes_requested'
                      ? 'Resubmit Work'
                      : 'Submit Work',
                ),
              ),
            ),
          ],
          if (previewImageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: previewImageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final imageUrl = previewImageUrls[index];

                  return GestureDetector(
                    onTap: isClient
                        ? () => _openDeliveryPreviewImage(imageUrl)
                        : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Preview only. Full access will be handled after payment.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          if (deliveryStatus == 'submitted' && isClient) ...[
            const SizedBox(height: 12),
            const Text(
              'Are you satisfied with the delivered work?',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSavingContract
                        ? null
                        : _requestDeliveryChanges,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(color: primary.withOpacity(0.24)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Request Changes'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSavingContract
                        ? null
                        : _approveDeliveryForPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
          if (deliveryStatus == 'submitted' && !isClient) ...[
            const SizedBox(height: 12),
            const Text(
              'Waiting for the client to review the submitted work.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSavingContract
                    ? null
                    : _withdrawDeliverySubmission,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC75A5A),
                  side: const BorderSide(color: Color(0xFFC75A5A), width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.undo_rounded),
                label: const Text('Withdraw Submission'),
              ),
            ),
          ],
          if (deliveryStatus == 'changes_requested') ...[
            const SizedBox(height: 12),
            const Text(
              'The client requested changes. Please review the chat and resubmit when ready.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
          if (deliveryStatus == 'approved_awaiting_payment' && isClient) ...[
            const SizedBox(height: 12),
            _buildChatPanelSurface(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment',
                    style: _chatPanelTitleStyle.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Delivery approved. Payment is required to unlock the final delivery.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSavingContract
                          ? null
                          : () {
                              debugPrint('PAY NOW CLICKED');
                              _openMoyasarPayment();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: primary.withOpacity(0.55),
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      label: const Text('Pay Now'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (deliveryStatus == 'approved_awaiting_payment' && !isClient) ...[
            const SizedBox(height: 12),
            _buildChatPanelSurface(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Final Work Release',
                    style: _chatPanelTitleStyle.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The client must complete payment before the final work can be released.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showWorkReleaseAfterPaymentDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(color: primary.withOpacity(0.24)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.lock_outline_rounded),
                      label: const Text('Download Work'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatHeaderAdminReviewAction({
    EdgeInsetsGeometry padding = const EdgeInsets.only(right: 8),
  }) {
    return ReportFlagButton(
      padding: padding,
      onPressed: () {
        unawaited(
          showReportIssueDialog(
            context: context,
            source: 'chat',
            reportedUserId: widget.otherUserId,
            reportedUserName: widget.otherUserName,
            reportedUserRole: widget.otherUserRole,
            chatId: widget.chatId,
          ),
        );
      },
    );
  }

  Widget _buildAdminReviewSection(String contractStatus) {
    final contractData = _contractData;
    if (contractData == null) return const SizedBox.shrink();
    if (contractStatus != 'approved') return const SizedBox.shrink();

    final deliveryData = _asMap(contractData['deliveryData']);
    final deliveryStatus = _normalizeDeliveryStatus(deliveryData['status']);
    final adminReview = _asMap(contractData['adminReview']);
    final adminReviewStatus = _normalizeAdminReviewStatus(
      adminReview['status'],
    );
    final adminReviewReason = _adminReviewReasonLabel(
      (adminReview['reasonType'] ?? '').toString(),
    );
    final adminReviewRequestedBy = (adminReview['requestedBy'] ?? '')
        .toString()
        .trim();
    final canWithdrawAdminReview =
        adminReviewStatus != 'resolved' &&
        adminReviewRequestedBy == _currentUserRole();

    return _buildChatPanelContainer(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Review',
            style: _chatPanelTitleStyle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 10),
          if (adminReviewStatus != 'none') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD54F)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Under Admin Review',
                    style: TextStyle(
                      color: Color(0xFF8D6E00),
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reason: $adminReviewReason',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 12.5,
                    ),
                  ),
                  if (adminReviewRequestedBy.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Requested by: $adminReviewRequestedBy',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (canWithdrawAdminReview) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isSavingContract
                            ? null
                            : _withdrawAdminReview,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          backgroundColor: Colors.transparent,
                          side: BorderSide(color: primary.withOpacity(0.32)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 20,
                          ),
                        ),
                        child: const Text(
                          'Withdraw Complaint',
                          textAlign: TextAlign.center,
                          style: TextStyle(height: 1.3),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (deliveryStatus != 'paid_delivered') ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSavingContract ? null : _requestAdminReview,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary.withOpacity(0.24)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Request Admin Review'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPinnedContractMetaChip({
    required IconData icon,
    required String label,
    required String value,
    bool expand = false,
  }) {
    return Container(
      width: expand ? double.infinity : null,
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _chatPanelDecoration(
        backgroundColor: _chatPanelSurface,
        borderColor: _chatPanelBorder,
        radius: 14,
        showShadow: false,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: primary.withOpacity(0.82)),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedPanelContentCard({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    final normalizedSubtitle = (subtitle ?? '').trim();

    return _buildChatPanelContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChatPanelHeader(title: title, subtitle: normalizedSubtitle),
          if (children.isNotEmpty) ...[const SizedBox(height: 12), ...children],
        ],
      ),
    );
  }

  Widget _buildApprovedPanelTabs() {
    const tabs = <String>['Contract', 'Deliverables', 'Review & Rate'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedApprovedPanelTab == index;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 2,
                right: index == tabs.length - 1 ? 0 : 2,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (_selectedApprovedPanelTab == index) return;
                    setState(() {
                      _selectedApprovedPanelTab = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tabs[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildApprovedPanelTabContent({
    required double expandedBodyMaxHeight,
  }) {
    switch (_selectedApprovedPanelTab) {
      case 0:
        return _buildApprovedContractTab(
          expandedBodyMaxHeight: expandedBodyMaxHeight,
        );
      case 1:
        return _buildApprovedWorkProgressTab();
      case 2:
        return _buildApprovedReviewTab();
      default:
        return _buildApprovedContractTab(
          expandedBodyMaxHeight: expandedBodyMaxHeight,
        );
    }
  }

  Widget _buildApprovedContractTab({required double expandedBodyMaxHeight}) {
    final contractData = _contractData;
    if (contractData == null) return const SizedBox.shrink();

    final service = _asMap(contractData['service']);
    final payment = _asMap(contractData['payment']);
    final timeline = _asMap(contractData['timeline']);
    final description = (service['description'] ?? '').toString().trim();
    final amount = (payment['amount'] ?? '').toString().trim();
    final deadline = (timeline['deadline'] ?? '').toString().trim();
    final terminationSection = _buildContractTerminationSection();
    final hasTerminationSection = terminationSection is! SizedBox;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : expandedBodyMaxHeight;

        return _buildContractScrollShell(
          controller: _approvedContractPanelScrollController,
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
          maxHeight: contentHeight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChatPanelContainer(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      contractDisplayTitle,
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (amount.isNotEmpty || deadline.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, metaConstraints) {
                          final showInlineCards =
                              amount.isNotEmpty &&
                              deadline.isNotEmpty &&
                              metaConstraints.maxWidth >= 300;

                          if (showInlineCards) {
                            return Row(
                              children: [
                                Expanded(
                                  child: _buildPinnedContractMetaChip(
                                    icon: Icons.payments_outlined,
                                    label: 'Amount',
                                    value: '$amount SAR',
                                    expand: true,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildPinnedContractMetaChip(
                                    icon: Icons.event_outlined,
                                    label: 'Deadline',
                                    value: deadline,
                                    expand: true,
                                  ),
                                ),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              if (amount.isNotEmpty)
                                _buildPinnedContractMetaChip(
                                  icon: Icons.payments_outlined,
                                  label: 'Amount',
                                  value: '$amount SAR',
                                  expand: true,
                                ),
                              if (amount.isNotEmpty && deadline.isNotEmpty)
                                const SizedBox(height: 10),
                              if (deadline.isNotEmpty)
                                _buildPinnedContractMetaChip(
                                  icon: Icons.event_outlined,
                                  label: 'Deadline',
                                  value: deadline,
                                  expand: true,
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _downloadCurrentContract,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: BorderSide(
                            color: primary.withOpacity(0.22),
                            width: 1,
                          ),
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Download Contract'),
                      ),
                    ),
                  ],
                ),
              ),

              if (hasTerminationSection) ...[
                const SizedBox(height: 14),
                _buildChatPanelContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contract Termination',
                        style: _chatPanelTitleStyle.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      terminationSection,
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildContractTerminationSection() {
    final contractData = _contractData;
    if (contractData == null) return const SizedBox.shrink();

    final approval = _asMap(contractData['approval']);
    final contractStatus = (approval['contractStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final termination =
        (approval['termination'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final paymentData = _asMap(contractData['paymentData']);
    final deliveryData = _asMap(contractData['deliveryData']);
    final paymentStatus = (paymentData['paymentStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final deliveryStatus = _normalizeDeliveryStatus(deliveryData['status']);
    final isPaidDelivered =
        deliveryStatus == 'paid_delivered' || paymentStatus == 'paid';
    final isCompleted = contractStatus == 'completed' || isPaidDelivered;
    final showTerminateButton = !isCompleted;
    final terminationGraceData = _terminationGracePeriodData();
    final terminationRequested = termination['requested'] == true;
    final terminationRequestedBy = (termination['requestedBy'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final terminationRejected = termination['rejected'] == true;
    final terminationRejectedBy = (termination['rejectedBy'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final terminationMode = (termination['mode'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final currentUserRole = _currentUserRole();
    final otherPartyLabel = currentUserRole == 'client'
        ? 'freelancer'
        : 'client';
    final requesterLabel = terminationRequestedBy == 'client'
        ? 'client'
        : terminationRequestedBy == 'freelancer'
        ? 'freelancer'
        : 'other party';
    final currentUserRequestedTermination =
        terminationRequestedBy == currentUserRole;
    final currentUserMutualRequestRejected =
        contractStatus == 'approved' &&
        terminationRejected &&
        terminationMode == 'mutual_rejected' &&
        terminationRequestedBy == currentUserRole &&
        terminationRejectedBy.isNotEmpty &&
        terminationRejectedBy != currentUserRole;
    final showApproveTerminationButton =
        contractStatus == 'termination_pending' &&
        terminationRequested &&
        !currentUserRequestedTermination;
    final showRejectTerminationButton =
        contractStatus == 'termination_pending' &&
        terminationRequested &&
        !currentUserRequestedTermination;
    final showCancelTerminationButton =
        contractStatus == 'termination_pending' &&
        terminationRequested &&
        currentUserRequestedTermination;
    final terminationIndicatorColor =
        (terminationGraceData?['indicatorColor'] as Color?) ??
        const Color(0xFF43A047);
    final isTerminationGraceExpired =
        (terminationGraceData?['isExpired'] as bool?) ?? false;
    final terminationCountdownLabel = (terminationGraceData?['label'] ?? '')
        .toString();
    final terminationGraceSubtitle =
        (terminationGraceData?['subtitle'] ??
                'Direct termination is available during this period.')
            .toString();
    Future<void> handleAdminReviewOptionTap() async {
      await _openContractTerminationAdminReviewSheet();
    }

    Widget buildTerminationOptionSheetTile({
      required IconData icon,
      required String title,
      required String subtitle,
      required Future<void> Function()? onTap,
      bool enabled = true,
      Color accentColor = const Color(0xFFC75A5A),
    }) {
      final action = onTap;
      final canTap = enabled && action != null;

      return ListTile(
        enabled: canTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: canTap ? Colors.black87 : Colors.black45,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: TextStyle(
              color: canTap ? Colors.black54 : Colors.black38,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: accentColor.withOpacity(canTap ? 0.9 : 0.4),
          size: 22,
        ),
        onTap: canTap
            ? () {
                unawaited(action!());
              }
            : null,
      );
    }

    Future<void> openTerminationOptionsSheet() {
      final canOpenPaymentOption =
          !_isTerminatingContract && !_isSavingContract;
      final canOpenMutualOption = !_isTerminatingContract && !_isSavingContract;
      final canOpenAdminReviewOption = !_isSavingContract;

      return showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          Future<void> runSheetAction(Future<void> Function() action) async {
            Navigator.of(sheetContext).pop();
            await action();
          }

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8D3E5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Termination Options',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose how you want to proceed with this contract.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  buildTerminationOptionSheetTile(
                    icon: Icons.payments_outlined,
                    title: 'Terminate with Payment',
                    subtitle: 'Pay the required fee to end the contract.',
                    onTap: canOpenPaymentOption
                        ? () => runSheetAction(
                            _openTerminationCompensationPayment,
                          )
                        : null,
                  ),
                  Divider(height: 1, color: primary.withOpacity(0.08)),
                  buildTerminationOptionSheetTile(
                    icon: Icons.handshake_outlined,
                    title: 'Mutual Agreement',
                    subtitle:
                        'Send a termination request for the other party to approve.',
                    onTap: canOpenMutualOption
                        ? () => runSheetAction(
                            () => _requestTermination(forcePaidMode: 'mutual'),
                          )
                        : null,
                    accentColor: const Color(0xFFB86A4A),
                  ),
                  Divider(height: 1, color: primary.withOpacity(0.08)),
                  buildTerminationOptionSheetTile(
                    icon: Icons.support_agent_outlined,
                    title: 'Request Admin Review',
                    subtitle: 'Ask the admin to review the contract issue.',
                    onTap: canOpenAdminReviewOption
                        ? () => runSheetAction(handleAdminReviewOptionTap)
                        : null,
                    accentColor: const Color(0xFFB45A4F),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    Widget buildTerminateActionTrigger() {
      final isEnabled = !_isTerminatingContract;

      return Tooltip(
        message: 'Terminate Contract',
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 2),
        waitDuration: Duration.zero,
        preferBelow: false,
        child: Opacity(
          opacity: isEnabled ? 1 : 0.58,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isEnabled ? _requestTermination : null,
              customBorder: const CircleBorder(),
              child: Ink(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFC75A5A).withOpacity(0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFC75A5A).withOpacity(0.22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC75A5A).withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFFC75A5A),
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget buildExpiredTerminationUi() {
      return Column(
        key: const ValueKey('termination_expired_ui'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Free Window Ended',
                style: TextStyle(
                  color: Color(0xFFC75A5A),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(
                    255,
                    223,
                    41,
                    16,
                  ).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color.fromARGB(
                      255,
                      223,
                      41,
                      16,
                    ).withOpacity(0.22),
                  ),
                ),
                child: const Text(
                  'Fee Required',
                  style: TextStyle(
                    color: Color.fromARGB(255, 223, 41, 16),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'The free termination period has ended.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          if (showTerminateButton) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: (_isTerminatingContract || _isSavingContract)
                  ? null
                  : () {
                      unawaited(openTerminationOptionsSheet());
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC75A5A),
                backgroundColor: Colors.transparent,
                side: BorderSide(
                  color: const Color(0xFFC75A5A).withOpacity(0.24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                minimumSize: const Size(0, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              label: const Text('Choose termination option'),
            ),
          ],
        ],
      );
    }

    Widget buildActiveTerminationUi() {
      return Column(
        key: const ValueKey('termination_active_ui'),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Free Termination Window',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: terminationIndicatorColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: terminationIndicatorColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: terminationIndicatorColor.withOpacity(0.26),
              ),
              boxShadow: [
                BoxShadow(
                  color: terminationIndicatorColor.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    color: terminationIndicatorColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 1,
                    color: terminationIndicatorColor.withOpacity(0.20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    terminationCountdownLabel,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  if (terminationCountdownLabel.trim().toLowerCase() !=
                      'expired') ...[
                    const SizedBox(width: 8),
                    Text(
                      'left',
                      style: TextStyle(
                        color: terminationIndicatorColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            terminationGraceSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          if (showTerminateButton) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: buildTerminateActionTrigger(),
            ),
          ],
        ],
      );
    }

    Widget buildTerminationGraceCard() {
      if (isTerminationGraceExpired) {
        return Container(
          key: const ValueKey('termination_expired_card'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6F6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFC75A5A).withOpacity(0.18),
            ),
            boxShadow: _chatPanelShadow,
          ),
          child: buildExpiredTerminationUi(),
        );
      }

      return Container(
        key: const ValueKey('termination_active_card'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF6FBF7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: terminationIndicatorColor.withOpacity(0.32),
          ),
          boxShadow: _chatPanelShadow,
        ),
        child: buildActiveTerminationUi(),
      );
    }

    final hasTerminationUi =
        terminationGraceData != null ||
        showTerminateButton ||
        currentUserMutualRequestRejected ||
        showApproveTerminationButton ||
        showCancelTerminationButton;

    if (!hasTerminationUi) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (terminationGraceData != null) ...[buildTerminationGraceCard()],
        if (showTerminateButton && terminationGraceData == null) ...[
          Align(
            alignment: Alignment.centerRight,
            child: buildTerminateActionTrigger(),
          ),
        ],
        if (currentUserMutualRequestRejected) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD54F)),
            ),
            child: Text(
              'The $otherPartyLabel rejected your mutual termination request. You can continue with paid termination (20%).',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!isTerminationGraceExpired) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isTerminatingContract
                    ? null
                    : _openTerminationCompensationPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC75A5A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Terminate with 20%'),
              ),
            ),
          ],
        ],
        if (showApproveTerminationButton) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD54F)),
            ),
            child: Text(
              'The $requesterLabel requested termination for this contract. You can approve or reject this request.',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (showCancelTerminationButton) ...[
          const SizedBox(height: 12),
          _buildChatPanelSurface(
            padding: const EdgeInsets.all(12),
            borderColor: primary.withOpacity(0.16),
            child: Text(
              'You requested termination for this contract. Please wait for the $otherPartyLabel to respond.',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (showApproveTerminationButton) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isTerminatingContract
                      ? null
                      : _approveTermination,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC75A5A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Approve Termination'),
                ),
              ),
              if (showRejectTerminationButton) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTerminatingContract
                        ? null
                        : _rejectTermination,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (showCancelTerminationButton) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isTerminatingContract ? null : _cancelTermination,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Cancel Termination'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildApprovedWorkProgressTab() {
    final contractData = _contractData;
    if (contractData == null) return const SizedBox.shrink();

    final approval = _asMap(contractData['approval']);
    final contractStatus = (approval['contractStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final deliveryData = _asMap(contractData['deliveryData']);
    final paymentData = _asMap(contractData['paymentData']);
    final deliveryStatus = _normalizeDeliveryStatus(deliveryData['status']);
    final paymentStatus = (paymentData['paymentStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final canDownloadFinalWork =
        deliveryStatus == 'paid_delivered' ||
        contractStatus == 'completed' ||
        paymentStatus == 'paid';
    final isClientView = _currentUserRole() == 'client';
    final shouldShowWorkProgress = _shouldShowWorkProgressAction();
    final canSubmit = _canFreelancerSubmitWork(contractStatus);

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 320.0;

        return _buildContractScrollShell(
          controller: _approvedContractPanelScrollController,
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
          maxHeight: contentHeight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: shouldShowWorkProgress
                ? [
                    _buildApprovedPanelContentCard(
                      title: 'Delivery Status',
                      subtitle: _deliveryStatusLabel(deliveryStatus),
                      children: [
                        Text(
                          _deliveryStatusMessage(
                            status: deliveryStatus,
                            isClientView: isClientView,
                            canSubmit: canSubmit,
                          ),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildDeliverySection(contractStatus),
                    if (canDownloadFinalWork) ...[
                      const SizedBox(height: 14),
                      _buildApprovedPanelContentCard(
                        title: 'Final Delivery',
                        subtitle: isClientView
                            ? 'Access the delivered files here.'
                            : 'Open or upload the delivered files here.',
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: isClientView
                                  ? _downloadDeliveredWork
                                  : _handleFinalWorkAction,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primary,
                                side: BorderSide(
                                  color: primary.withOpacity(0.22),
                                  width: 1,
                                ),
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.file_download_outlined),
                              label: const Text('Download Work'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ]
                : [
                    _buildApprovedPanelContentCard(
                      title: 'Work Delivery',
                      children: [
                        const Text(
                          'No work has been submitted yet.',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
          ),
        );
      },
    );
  }

  Widget _buildApprovedReviewTab() {
    final contractData = _contractData;
    if (contractData == null) return const SizedBox.shrink();

    final reviewAvailable = _isContractCompletedForReview(_contractData);

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 320.0;

        return _buildContractScrollShell(
          controller: _approvedContractPanelScrollController,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          maxHeight: contentHeight,
          child: reviewAvailable
              ? _buildReviewActionSection()
              : _buildChatPanelContainer(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: _chatPanelBackground,
                  child: const Text(
                    'Review will be available after the service is completed.',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildVisibleContractScrollbar({
    required ScrollController controller,
    required Widget child,
  }) {
    return RawScrollbar(
      controller: controller,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      thickness: 5,
      radius: const Radius.circular(999),
      thumbColor: primary.withOpacity(0.55),
      trackColor: primary.withOpacity(0.10),
      trackBorderColor: Colors.transparent,
      child: child,
    );
  }

  Widget _buildSelectedNavIcon(IconData icon, {double size = 28}) {
    return Icon(icon, color: primary, size: size);
  }

  Widget _buildUnselectedNavIcon(IconData icon, {double size = 27}) {
    return Icon(icon, color: const Color(0xFF9A92B8), size: size);
  }

  Widget _buildContractScrollShell({
    required ScrollController controller,
    required EdgeInsetsGeometry padding,
    required Widget child,
    double maxHeight = 250,
  }) {
    return SizedBox(
      height: maxHeight,
      child: _buildContractScrollArea(
        controller: controller,
        child: SizedBox.expand(
          child: SingleChildScrollView(
            controller: controller,
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildContractScrollArea({
    required ScrollController controller,
    required Widget child,
  }) {
    return Stack(
      children: [
        _buildVisibleContractScrollbar(controller: controller, child: child),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              height: 26,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _chatPanelShellBackground.withOpacity(0.0),
                    _chatPanelShellBackground.withOpacity(0.92),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadCurrentContract() async {
    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chat')
          .doc(widget.chatId)
          .get();
      final requestId = _extractRequestId(chatDoc.data());
      await downloadContract(requestId);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Resolve contract download error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    }
  }

  Future<void> _downloadDeliveredWork() async {
    try {
      final deliveryData = _asMap(_contractData?['deliveryData']);
      final deliveredUrls =
          (deliveryData['finalWorkUrls'] as List?)
              ?.map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList() ??
          const <String>[];

      if (deliveredUrls.isEmpty) {
        final waitingMessage = _currentUserRole() == 'client'
            ? 'Please wait for the freelancer to upload the final work.'
            : 'Final work is not available yet';
        unawaited(_showErrorDialog(waitingMessage));
        return;
      }

      await _openFinalWorkGallery(deliveredUrls);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Download delivered work error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    }
  }

  Future<void> _showWorkReleaseAfterPaymentDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Payment Required'),
          content: const Text(
            'The final work can only be released after the client completes the payment.',
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary.withOpacity(0.24)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<List<File>?> _pickDeliveryImagesForSubmission() async {
    final pickedFiles = await _picker.pickMultiImage(imageQuality: 85);
    if (pickedFiles.isEmpty) return null;

    final selectedFiles = pickedFiles.map((file) => File(file.path)).toList();

    if (!mounted) return null;

    return showDialog<List<File>>(
      context: context,
      builder: (dialogContext) {
        final files = List<File>.from(selectedFiles);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Review Work Images'),
              content: SizedBox(
                width: double.maxFinite,
                child: files.isEmpty
                    ? const Text('No images selected.')
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Remove any image you do not want before submitting.',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 92,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: files.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        files[index],
                                        width: 92,
                                        height: 92,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            files.removeAt(index);
                                          });
                                        },
                                        child: const CircleAvatar(
                                          radius: 11,
                                          backgroundColor: Colors.black54,
                                          child: Icon(
                                            Icons.close,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC75A5A),
                    side: const BorderSide(color: Color(0xFFC75A5A)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: files.isEmpty
                      ? null
                      : () => Navigator.of(dialogContext).pop(files),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Submit Work'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleFinalWorkAction() async {
    final contractData = _contractData;
    if (contractData == null) return;

    final deliveryData = _asMap(contractData['deliveryData']);
    final finalWorkUrls =
        (deliveryData['finalWorkUrls'] as List?)
            ?.map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList() ??
        const <String>[];

    if (_currentUserRole() == 'freelancer' && finalWorkUrls.isEmpty) {
      try {
        final selectedFiles = await _pickDeliveryImagesForSubmission();
        if (selectedFiles == null || selectedFiles.isEmpty) return;

        setState(() {
          _isSavingContract = true;
        });

        final uploadedUrls = await _controller.uploadDeliveryImages(
          chatId: widget.chatId,
          imageFiles: selectedFiles,
        );

        final updatedContractData = Map<String, dynamic>.from(contractData);
        final updatedDeliveryData = _asMap(updatedContractData['deliveryData']);
        updatedDeliveryData['finalWorkUrls'] = uploadedUrls;
        updatedDeliveryData['finalWorkUploadedBy'] = _currentUserRole();
        updatedDeliveryData['finalWorkUploadedAt'] = DateTime.now()
            .toIso8601String();
        updatedContractData['deliveryData'] = updatedDeliveryData;

        await _saveWorkflowContractData(updatedContractData);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Final work uploaded successfully')),
        );
      } catch (e) {
        if (!mounted) return;
        debugPrint('Upload final work error: $e');
        unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
      } finally {
        if (!mounted) return;
        setState(() {
          _isSavingContract = false;
        });
      }
      return;
    }

    await _downloadDeliveredWork();
  }

  String _contractNotificationSnippet(Map<String, dynamic>? contractData) {
    final normalizedContractData = contractData ?? _contractData;
    final service = _asMap(normalizedContractData?['service']);
    final meta = _asMap(normalizedContractData?['meta']);

    final snippet = _singleLineSnippet(
      _firstFilled([
        service['description'],
        meta['title'],
        'Contract Agreement',
      ]),
    );

    return snippet.isEmpty ? 'Contract Agreement' : snippet;
  }

  String _contractNotificationId({
    required Map<String, dynamic>? contractData,
    required String requestId,
  }) {
    final normalizedContractData = contractData ?? _contractData;
    final meta = _asMap(normalizedContractData?['meta']);

    return _firstFilled([
      normalizedContractData?['contractId'],
      meta['contractId'],
      requestId,
    ]);
  }

  Future<void> _createContractNotification({
    required String type,
    required String actionText,
    required String requestId,
    required Map<String, dynamic>? chatData,
    required Map<String, dynamic>? contractData,
    bool notifyBothUsers = false,
  }) async {
    try {
      final normalizedChatData = chatData ?? <String, dynamic>{};
      final clientId = (normalizedChatData['clientId'] ?? '').toString().trim();
      final freelancerId = (normalizedChatData['freelancerId'] ?? '')
          .toString()
          .trim();
      final currentUserRole = _currentUserRole();
      final normalizedType = type.trim();
      final normalizedActionText = actionText.trim();
      final normalizedRequestId = requestId.trim();
      final senderId = currentUserRole == 'client' ? clientId : freelancerId;
      final receiverIds =
          (notifyBothUsers
                  ? <String>{clientId, freelancerId}
                  : <String>{
                      currentUserRole == 'client' ? freelancerId : clientId,
                    })
              .where((id) => id.trim().isNotEmpty)
              .toSet();

      if (senderId.isEmpty ||
          normalizedType.isEmpty ||
          normalizedActionText.isEmpty ||
          receiverIds.isEmpty) {
        return;
      }

      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .get();
      final senderData = senderDoc.data() ?? <String, dynamic>{};
      final senderName = _displayName(
        senderData,
        currentUserRole == 'client' ? 'Client' : 'Freelancer',
      );
      final senderProfileUrl = _firstFilled([
        senderData['photoUrl'],
        senderData['profile'],
      ]);
      final contractId = _contractNotificationId(
        contractData: contractData,
        requestId: requestId,
      );
      final snippet = _contractNotificationSnippet(contractData);

      for (final receiverId in receiverIds) {
        if (receiverId.trim().isEmpty) continue;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(receiverId)
            .collection('notifications')
            .add({
              'type': normalizedType,
              'senderId': senderId,
              'senderName': senderName,
              'senderProfileUrl': senderProfileUrl,
              'receiverId': receiverId,
              'actionText': normalizedActionText,
              'snippet': snippet,
              'requestId': normalizedRequestId,
              'contractId': contractId,
              'chatId': widget.chatId,
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            });

        await _sendNotificationPush(
          receiverId: receiverId,
          title: senderName.isEmpty ? 'Contract Update' : senderName,
          body: normalizedActionText,
          data: {
            'type': normalizedType,
            'senderId': senderId,
            'receiverId': receiverId,
            'requestId': normalizedRequestId,
            'contractId': contractId,
            'chatId': widget.chatId,
            'notificationOrigin': 'firestore_contract_notification',
          },
        );
      }
    } catch (e) {
      debugPrint('Create contract notification error: $e');
    }
  }

  Future<void> _sendNotificationPush({
    required String receiverId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _postContractApi(
        endpointPath: 'send-notification-push',
        body: {
          'receiverId': receiverId,
          'title': title,
          'body': body,
          'data': data,
        },
        logLabel: 'Send notification push',
      );
    } catch (e) {
      debugPrint('Send notification push error: $e');
    }
  }

  bool _approvalFlag(Map<String, dynamic> approval, List<String> keys) {
    for (final key in keys) {
      final normalizedKey = key.toLowerCase();
      final keyLooksApproved =
          normalizedKey.contains('approved') ||
          normalizedKey.contains('approval') ||
          normalizedKey.contains('signed') ||
          normalizedKey.contains('accepted');
      final value = approval[key];
      if (value == true && keyLooksApproved) return true;

      final text = value?.toString().trim().toLowerCase() ?? '';
      if ((text == 'true' && keyLooksApproved) ||
          text == 'approved' ||
          text == 'accepted' ||
          text == 'signed') {
        return true;
      }
    }

    return false;
  }

  bool _rejectionFlag(Map<String, dynamic> approval, List<String> keys) {
    for (final key in keys) {
      final normalizedKey = key.toLowerCase();
      final keyLooksRejected =
          normalizedKey.contains('reject') ||
          normalizedKey.contains('disapprove') ||
          normalizedKey.contains('decline');
      final value = approval[key];
      if (value == true && keyLooksRejected) return true;

      final text = value?.toString().trim().toLowerCase() ?? '';
      if ((text == 'true' && keyLooksRejected) ||
          text == 'rejected' ||
          text == 'disapproved' ||
          text == 'declined') {
        return true;
      }
    }

    return false;
  }

  Future<void> _openSignatureAndApprove() async {
    final contractData = _contractData;
    if (contractData == null) return;

    final signatureData = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (_) => const _SignatureSheet(primary: primary),
    );

    if (!mounted || signatureData == null || signatureData.isEmpty) return;

    await _approveContract(signatureData);
  }

  Future<void> _approveContract(String signatureData) async {
    final contractData = _contractData;
    if (contractData == null) return;

    setState(() {
      _isApprovingContract = true;
    });

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chat')
          .doc(widget.chatId)
          .get();

      final chatData = chatDoc.data();
      final requestId = _extractRequestId(chatData);

      final response = await _postContractApi(
        endpointPath: 'approve-contract',
        body: {
          'requestId': requestId,
          'role': _currentUserRole(),
          'signatureData': signatureData,
        },
        logLabel: 'Approve contract',
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final updatedContractData = data['contractData'];
        final selfTerminated = data['selfTerminated'] == true;
        final normalizedContractData = updatedContractData is Map
            ? Map<String, dynamic>.from(updatedContractData)
            : null;

        setState(() {
          if (normalizedContractData != null) {
            _contractData = normalizedContractData;
          }
        });

        await _createContractNotification(
          type: 'contract_approved',
          actionText: 'approved your contract',
          requestId: requestId,
          chatData: chatData,
          contractData: normalizedContractData,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract approved successfully')),
        );
      } else {
        unawaited(_showErrorDialog(_friendlyErrorMessage(response.statusCode)));
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Approve contract error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (!mounted) return;

      setState(() {
        _isApprovingContract = false;
      });
    }
  }

  Future<void> _requestTermination({String? forcePaidMode}) async {
    String? terminationMode = forcePaidMode;

    if ((terminationMode ?? '').isEmpty && _isWithinTerminationGracePeriod()) {
      final shouldTerminate = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Terminate Contract'),
            content: const Text(
              'Are you sure you want to terminate this contract?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  'Terminate',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          );
        },
      );

      if (shouldTerminate != true || !mounted) return;
    } else if ((terminationMode ?? '').isEmpty) {
      terminationMode = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          final compensationText = _terminationCompensationText();
          return AlertDialog(
            title: const Text('Terminate Contract'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose how you want to terminate this contract.\n\n'
                  'Direct termination with compensation: you pay $compensationText to the other party.\n\n'
                  'Mutual termination: the other party must approve, with no payment required.',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop('mutual'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(color: primary.withOpacity(0.22)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Mutual Termination'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop('paid'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC75A5A),
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(
                        color: Color(0xFFC75A5A),
                        width: 1,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Terminate with 20%'),
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC75A5A),
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(color: Color(0xFFC75A5A)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );

      if ((terminationMode ?? '').isEmpty || !mounted) return;
    }

    if ((terminationMode ?? '').trim().toLowerCase() == 'paid' &&
        !_isWithinTerminationGracePeriod()) {
      await _openTerminationCompensationPayment();
      return;
    }

    setState(() {
      _isTerminatingContract = true;
    });

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chat')
          .doc(widget.chatId)
          .get();

      final chatData = chatDoc.data();
      final requestId = _extractRequestId(chatData);

      final response = await _postContractApi(
        endpointPath: 'request-termination',
        body: {
          'requestId': requestId,
          'role': _currentUserRole(),
          if ((terminationMode ?? '').isNotEmpty)
            'terminationMode': terminationMode,
        },
        logLabel: 'Request termination',
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final updatedContractData = data['contractData'];
        final selfTerminated = data['selfTerminated'] == true;
        final terminationModeResponse = (data['terminationMode'] ?? '')
            .toString()
            .trim();
        final normalizedContractData = updatedContractData is Map
            ? Map<String, dynamic>.from(updatedContractData)
            : null;

        setState(() {
          if (normalizedContractData != null) {
            _contractData = normalizedContractData;
          }
        });

        await _createContractNotification(
          type: selfTerminated
              ? 'contract_terminated'
              : 'contract_termination_requested',
          actionText: selfTerminated
              ? terminationModeResponse == 'paid_compensation'
                    ? 'terminated the contract with 20% compensation'
                    : 'terminated the contract'
              : 'requested to terminate the contract',
          requestId: requestId,
          chatData: chatData,
          contractData: normalizedContractData,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selfTerminated
                  ? terminationModeResponse == 'paid_compensation'
                        ? 'Contract terminated successfully with 20% compensation'
                        : 'Contract terminated successfully'
                  : 'Termination requested',
            ),
          ),
        );
      } else {
        debugPrint(
          'request-termination failed: '
          'status=${response.statusCode}, body=${response.body}',
        );
        unawaited(_showErrorDialog(_friendlyErrorMessage(response.statusCode)));
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('request-termination exception: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (!mounted) return;
      setState(() {
        _isTerminatingContract = false;
      });
    }
  }

  Future<void> _approveTermination() async {
    setState(() {
      _isTerminatingContract = true;
    });

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chat')
          .doc(widget.chatId)
          .get();

      final requestId = _extractRequestId(chatDoc.data());

      final response = await _postContractApi(
        endpointPath: 'approve-termination',
        body: {'requestId': requestId, 'role': _currentUserRole()},
        logLabel: 'Approve termination',
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final updatedContractData = data['contractData'];

        setState(() {
          if (updatedContractData is Map) {
            _contractData = Map<String, dynamic>.from(updatedContractData);
          }
        });

        final chatDocData =
            (await FirebaseFirestore.instance
                    .collection('chat')
                    .doc(widget.chatId)
                    .get())
                .data();
        final requestId = _extractRequestId(chatDocData);
        await _createContractNotification(
          type: 'contract_termination_approved',
          actionText: 'approved your termination request',
          requestId: requestId,
          chatData: chatDocData,
          contractData: updatedContractData is Map
              ? Map<String, dynamic>.from(updatedContractData)
              : null,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract terminated successfully')),
        );
      } else {
        unawaited(_showErrorDialog(_friendlyErrorMessage(response.statusCode)));
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Approve termination error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (!mounted) return;
      setState(() {
        _isTerminatingContract = false;
      });
    }
  }

  Future<void> _rejectTermination() async {
    setState(() {
      _isTerminatingContract = true;
    });

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chat')
          .doc(widget.chatId)
          .get();

      final chatData = chatDoc.data();
      final requestId = _extractRequestId(chatData);

      final response = await _postContractApi(
        endpointPath: 'reject-termination',
        body: {'requestId': requestId, 'role': _currentUserRole()},
        logLabel: 'Reject termination',
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final updatedContractData = data['contractData'];
        final normalizedContractData = updatedContractData is Map
            ? Map<String, dynamic>.from(updatedContractData)
            : null;

        setState(() {
          if (normalizedContractData != null) {
            _contractData = normalizedContractData;
          }
        });

        await _createContractNotification(
          type: 'contract_termination_rejected',
          actionText: 'rejected your termination request',
          requestId: requestId,
          chatData: chatData,
          contractData: normalizedContractData,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Termination request rejected')),
        );
      } else {
        unawaited(_showErrorDialog(_friendlyErrorMessage(response.statusCode)));
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Reject termination error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (!mounted) return;
      setState(() {
        _isTerminatingContract = false;
      });
    }
  }

  Future<void> _cancelTermination() async {
    setState(() {
      _isTerminatingContract = true;
    });

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chat')
          .doc(widget.chatId)
          .get();

      final requestId = _extractRequestId(chatDoc.data());

      final response = await _postContractApi(
        endpointPath: 'cancel-termination',
        body: {'requestId': requestId, 'role': _currentUserRole()},
        logLabel: 'Cancel termination',
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final updatedContractData = data['contractData'];

        setState(() {
          if (updatedContractData is Map) {
            _contractData = Map<String, dynamic>.from(updatedContractData);
          }
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Termination cancelled')));
      } else {
        unawaited(_showErrorDialog(_friendlyErrorMessage(response.statusCode)));
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Cancel termination error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (!mounted) return;
      setState(() {
        _isTerminatingContract = false;
      });
    }
  }

  Future<void> downloadContract(String requestId) async {
    try {
      final url = _backendUri(
        'download-contract-pdf',
        queryParameters: {'requestId': requestId},
      );
      debugPrint('Download contract URL: $url');

      final opened = await launchUrl(url);

      if (!opened) {
        if (!mounted) return;
        unawaited(
          _showErrorDialog(_friendlyErrorMessage('Could not open PDF')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Download contract error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    }
  }

  Future<void> _callCancelApproval() async {
    final contractData = _contractData;
    if (contractData == null) return;

    setState(() {
      _isApprovingContract = true;
    });

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chat')
          .doc(widget.chatId)
          .get();

      final chatData = chatDoc.data();
      final requestId = _extractRequestId(chatData);

      final response = await _postContractApi(
        endpointPath: 'cancel-approval',
        body: {'requestId': requestId, 'role': _currentUserRole()},
        logLabel: 'Cancel approval',
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final updatedContractData = data['contractData'];

        setState(() {
          if (updatedContractData is Map) {
            _contractData = Map<String, dynamic>.from(updatedContractData);
          }
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Approval cancelled')));
      } else {
        unawaited(_showErrorDialog(_friendlyErrorMessage(response.statusCode)));
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Cancel approval error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (!mounted) return;

      setState(() {
        _isApprovingContract = false;
      });
    }
  }

  Future<void> _disapproveContract() async {
    final contractData = _contractData;
    if (contractData == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Disapprove Contract'),
          content: const Text('Are you sure you want to reject this contract?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chat')
          .doc(widget.chatId)
          .get();

      final chatData = chatDoc.data();
      final requestId = _extractRequestId(chatData);

      final response = await _postContractApi(
        endpointPath: 'disapprove-contract',
        body: {'requestId': requestId, 'role': _currentUserRole()},
        logLabel: 'Disapprove contract',
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final updatedContractData = data['contractData'];
        final normalizedContractData = updatedContractData is Map
            ? Map<String, dynamic>.from(updatedContractData)
            : null;

        setState(() {
          if (normalizedContractData != null) {
            _contractData = normalizedContractData;
          }
        });

        await _createContractNotification(
          type: 'contract_disapproved',
          actionText: 'rejected your contract',
          requestId: requestId,
          chatData: chatData,
          contractData: normalizedContractData,
        );

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Contract rejected')));
      } else {
        unawaited(_showErrorDialog(_friendlyErrorMessage(response.statusCode)));
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Reject contract error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    }
  }

  Future<void> _deleteContract() async {
    await _removeGeneratedContract(
      endpointPath: 'delete-contract',
      dialogTitle: 'Delete Contract',
      dialogMessage: 'Are you sure you want to delete this contract?',
      dismissLabel: 'Cancel',
      confirmLabel: 'Delete',
      successMessage: 'Contract deleted',
      logLabel: 'Delete contract',
      clearContractData: true,
    );
  }

  Future<void> _cancelContract() async {
    await _removeGeneratedContract(
      endpointPath: 'cancel-contract',
      dialogTitle: 'Cancel Contract',
      dialogMessage: 'Are you sure you want to cancel this contract?',
      dismissLabel: 'No',
      confirmLabel: 'Yes, Cancel',
      successMessage: 'Contract cancelled',
      logLabel: 'Cancel contract',
      clearContractData: false,
      includeRole: true,
    );
  }

  Future<void> _removeGeneratedContract({
    required String endpointPath,
    required String dialogTitle,
    required String dialogMessage,
    required String dismissLabel,
    required String confirmLabel,
    required String successMessage,
    required String logLabel,
    required bool clearContractData,
    bool includeRole = false,
  }) async {
    final contractData = _contractData;
    if (contractData == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(dialogTitle),
          content: Text(dialogMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(dismissLabel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isSavingContract = true;
    });

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chat')
          .doc(widget.chatId)
          .get();

      final requestId = _extractRequestId(chatDoc.data());
      final body = <String, dynamic>{'requestId': requestId};
      if (includeRole) {
        body['role'] = _currentUserRole();
      }

      final response = await _postContractApi(
        endpointPath: endpointPath,
        body: body,
        logLabel: logLabel,
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final updatedContractData = data['contractData'];

        setState(() {
          if (clearContractData) {
            _contractData = null;
          } else if (updatedContractData is Map) {
            _contractData = Map<String, dynamic>.from(updatedContractData);
          } else {
            _contractData = null;
          }
          _isEditingContract = false;
          _isAddingClause = false;
          _isApprovingContract = false;
          _isTerminatingContract = false;
          _pendingCustomClauses = [];
          _contractError = null;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      } else {
        unawaited(_showErrorDialog(_friendlyErrorMessage(response.statusCode)));
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('$logLabel error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (!mounted) return;

      setState(() {
        _isSavingContract = false;
      });
    }
  }

  void _handleAddClause() {
    if (_isSavingContract) return;

    final contractData = _contractData;
    if (contractData == null) return;

    final existingClauses =
        (contractData['customClauses'] as List?)?.toList() ?? [];
    final existingUserClauses = existingClauses.where((clause) {
      if (clause is! Map) return false;

      final source = (clause['source'] ?? '').toString().trim().toLowerCase();
      return source == 'user';
    }).length;
    final totalClauses = existingUserClauses + _pendingCustomClauses.length;

    if (totalClauses >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 clauses allowed')),
      );
      return;
    }

    setState(() {
      _isAddingClause = true;
      _pendingCustomClauses.add({'title': '', 'content': ''});
    });
  }

  Future<void> _deleteClause(int index) async {
    if (_isSavingContract) return;

    final contractData = _contractData;
    if (contractData == null) return;

    final updatedContractData = Map<String, dynamic>.from(contractData);
    final currentClauses =
        (updatedContractData['customClauses'] as List?)?.toList() ?? [];

    if (index < 0 || index >= currentClauses.length) return;

    currentClauses.removeAt(index);
    updatedContractData['customClauses'] = currentClauses;

    setState(() {
      _contractData = updatedContractData;
      _isSavingContract = true;
    });

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chat')
          .doc(widget.chatId)
          .get();

      final requestId = _extractRequestId(chatDoc.data());

      final response = await _postContractApi(
        endpointPath: 'update-contract',
        body: {
          'requestId': requestId,
          'role': _currentUserRole(),
          'contractData': updatedContractData,
        },
        logLabel: 'Delete clause update',
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final savedContractData = data['contractData'];

        setState(() {
          if (savedContractData is Map) {
            _contractData = Map<String, dynamic>.from(savedContractData);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract updated successfully')),
        );
      } else {
        unawaited(_showErrorDialog(_friendlyErrorMessage(response.statusCode)));
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Delete clause update error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
    } finally {
      if (!mounted) return;

      setState(() {
        _isSavingContract = false;
      });
    }
  }

  Widget _buildContractPreview() {
    final contractData = _contractData;
    if (contractData == null) return const SizedBox.shrink();

    final mediaQuery = MediaQuery.of(context);
    final keyboardOpen = mediaQuery.viewInsets.bottom > 0;
    final maxPreviewHeight = keyboardOpen
        ? mediaQuery.size.height * 0.38
        : mediaQuery.size.height * 0.55;

    final parties =
        (contractData['parties'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final service =
        (contractData['service'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final payment =
        (contractData['payment'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final timeline =
        (contractData['timeline'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    final approval =
        (contractData['approval'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    final contractStatus = (approval['contractStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (contractStatus == 'approved' ||
        contractStatus == 'completed' ||
        contractStatus == 'terminated' ||
        contractStatus == 'cancelled' ||
        contractStatus == 'canceled') {
      return const SizedBox.shrink();
    }

    final termination =
        (approval['termination'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    final terminationRequested = termination['requested'] == true;
    final terminationRequestedBy = (termination['requestedBy'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final terminationRejected = termination['rejected'] == true;
    final terminationRejectedBy = (termination['rejectedBy'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final terminationMode = (termination['mode'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final currentUserRole = _currentUserRole();
    final otherPartyLabel = currentUserRole == 'client'
        ? 'freelancer'
        : 'client';
    final requesterLabel = terminationRequestedBy == 'client'
        ? 'client'
        : terminationRequestedBy == 'freelancer'
        ? 'freelancer'
        : 'other party';
    final currentUserRequestedTermination =
        terminationRequestedBy == currentUserRole;
    final currentUserMutualRequestRejected =
        contractStatus == 'approved' &&
        terminationRejected &&
        terminationMode == 'mutual_rejected' &&
        terminationRequestedBy == currentUserRole &&
        terminationRejectedBy.isNotEmpty &&
        terminationRejectedBy != currentUserRole;

    final showApproveTerminationButton =
        contractStatus == 'termination_pending' &&
        terminationRequested &&
        !currentUserRequestedTermination;

    final showRejectTerminationButton =
        contractStatus == 'termination_pending' &&
        terminationRequested &&
        !currentUserRequestedTermination;

    final showCancelTerminationButton =
        contractStatus == 'termination_pending' &&
        terminationRequested &&
        currentUserRequestedTermination;

    final customClauses = (contractData['customClauses'] as List?) ?? const [];
    final userCustomClauseEntries = customClauses.asMap().entries.where((
      entry,
    ) {
      final clause = entry.value;
      if (clause is! Map) return false;

      final source = (clause['source'] ?? '').toString().trim().toLowerCase();
      return source == 'user';
    }).toList();

    final meta =
        (contractData['meta'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    final List<dynamic> summary = const [];

    final clientApproved = _approvalFlag(approval, const [
      'clientApproved',
      'clientApproval',
      'clientApprovalStatus',
      'clientDecision',
      'clientStatus',
      'clientSigned',
    ]);

    final freelancerApproved = _approvalFlag(approval, const [
      'freelancerApproved',
      'freelancerApproval',
      'freelancerApprovalStatus',
      'freelancerDecision',
      'freelancerStatus',
      'freelancerSigned',
    ]);

    final bothPartiesApproved = clientApproved && freelancerApproved;

    final clientRejected = _rejectionFlag(approval, const [
      'clientRejected',
      'clientRejection',
      'clientRejectionStatus',
      'clientDisapproved',
      'clientDecision',
      'clientStatus',
    ]);

    final freelancerRejected = _rejectionFlag(approval, const [
      'freelancerRejected',
      'freelancerRejection',
      'freelancerRejectionStatus',
      'freelancerDisapproved',
      'freelancerDecision',
      'freelancerStatus',
    ]);

    final bothPartiesRejected =
        (clientRejected && freelancerRejected) || contractStatus == 'rejected';

    final hasPendingDecisionStatus =
        contractStatus.isEmpty ||
        contractStatus == 'draft' ||
        contractStatus == 'edited' ||
        contractStatus == 'pending_approval';

    final hasPendingPartyDecision = !clientApproved || !freelancerApproved;

    final contractNeedsDecision =
        !bothPartiesApproved &&
        !bothPartiesRejected &&
        !terminationRequested &&
        hasPendingDecisionStatus &&
        hasPendingPartyDecision;

    final currentUserApproved = currentUserRole == 'client'
        ? clientApproved
        : freelancerApproved;

    final otherPartyApproved = currentUserRole == 'client'
        ? freelancerApproved
        : clientApproved;

    final showApproveActions =
        !_isEditingContract &&
        !currentUserApproved &&
        contractStatus != 'approved' &&
        contractStatus != 'rejected' &&
        contractStatus != 'termination_pending' &&
        contractStatus != 'terminated';

    final showWaitingForOtherPartySignature =
        !_isEditingContract &&
        currentUserApproved &&
        !otherPartyApproved &&
        contractStatus == 'pending_approval';

    final showCancelApproval =
        !_isEditingContract &&
        currentUserApproved &&
        !otherPartyApproved &&
        contractStatus == 'pending_approval';

    final showCancelContractButton =
        !_isEditingContract && contractNeedsDecision;

    final canEditContract =
        contractStatus == 'draft' ||
        contractStatus == 'edited' ||
        (contractStatus == 'pending_approval' &&
            !currentUserApproved &&
            otherPartyApproved);

    final statusChipText = contractStatus == 'approved'
        ? 'Approved'
        : contractStatus == 'rejected'
        ? 'Rejected'
        : contractStatus == 'edited'
        ? 'Edited'
        : contractStatus == 'pending_approval'
        ? 'Waiting'
        : contractStatus == 'termination_pending'
        ? 'Termination Pending'
        : contractStatus == 'terminated'
        ? 'Terminated'
        : 'Draft';

    final statusChipBackgroundColor = contractStatus == 'approved'
        ? const Color(0xFFE8F5E9)
        : contractStatus == 'rejected'
        ? const Color(0xFFFFEBEE)
        : contractStatus == 'edited'
        ? const Color(0xFFEEE8FB)
        : contractStatus == 'pending_approval'
        ? const Color(0xFFFFF4E5)
        : contractStatus == 'termination_pending'
        ? const Color(0xFFFFF4E5)
        : contractStatus == 'terminated'
        ? const Color(0xFFF3E5F5)
        : const Color(0xFFF1F3F4);

    final statusChipTextColor = contractStatus == 'approved'
        ? const Color(0xFF2E7D32)
        : contractStatus == 'rejected'
        ? Colors.redAccent
        : contractStatus == 'edited'
        ? primary
        : contractStatus == 'pending_approval'
        ? const Color(0xFFEF6C00)
        : contractStatus == 'termination_pending'
        ? const Color(0xFFEF6C00)
        : contractStatus == 'terminated'
        ? const Color(0xFF6A1B9A)
        : Colors.black54;

    final statusChipIcon = contractStatus == 'approved'
        ? Icons.check_circle_rounded
        : contractStatus == 'rejected'
        ? Icons.cancel_rounded
        : contractStatus == 'edited'
        ? Icons.edit_note_rounded
        : contractStatus == 'pending_approval'
        ? Icons.hourglass_top_rounded
        : contractStatus == 'termination_pending'
        ? Icons.warning_amber_rounded
        : contractStatus == 'terminated'
        ? Icons.block_rounded
        : Icons.description_outlined;

    final amount = (payment['amount'] ?? '').toString().trim();
    final paymentText = amount.isEmpty ? '-' : '$amount SAR';
    final header = Row(
      children: [
        Expanded(
          child: const Text(
            contractDisplayTitle,
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        Material(
          color: const Color(0xFFF4F1FA),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              setState(() {
                _isContractPreviewExpanded = !_isContractPreviewExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                _isContractPreviewExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: primary,
                size: 20,
              ),
            ),
          ),
        ),
        if (canEditContract && contractStatus != 'draft') ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusChipBackgroundColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusChipIcon, size: 14, color: statusChipTextColor),
                const SizedBox(width: 6),
                Text(
                  statusChipText,
                  style: TextStyle(
                    color: statusChipTextColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (canEditContract) ...[
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: (_isSavingContract || _isApprovingContract)
                ? null
                : _toggleContractEdit,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(_isEditingContract ? Icons.check : Icons.edit),
            label: Text(_isEditingContract ? 'Save' : 'Edit'),
          ),
        ],
        if (!canEditContract) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusChipBackgroundColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusChipIcon, size: 14, color: statusChipTextColor),
                const SizedBox(width: 6),
                Text(
                  statusChipText,
                  style: TextStyle(
                    color: statusChipTextColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    if (!_isContractPreviewExpanded) {
      return _buildChatPanelContainer(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        backgroundColor: _chatPanelSurface,
        borderColor: _chatPanelBorder,
        showShadow: false,
        child: header,
      );
    }

    return _buildChatPanelContainer(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      backgroundColor: _chatPanelSurface,
      borderColor: _chatPanelBorder,
      showShadow: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxPreviewHeight),
        child: Scrollbar(
          controller: _contractPreviewScrollController,
          thumbVisibility: true,
          thickness: 2.5,
          radius: const Radius.circular(999),
          child: SingleChildScrollView(
            controller: _contractPreviewScrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                if (contractStatus == 'edited') ...[
                  const SizedBox(height: 8),
                  const Text(
                    'This contract was edited and requires fresh approval from both parties.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _buildContractSection(
                  title: 'Client name',
                  children: [
                    Text(
                      (parties['clientName'] ?? '').toString(),
                      style: const TextStyle(
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildContractSection(
                  title: 'Freelancer name',
                  children: [
                    Text(
                      (parties['freelancerName'] ?? '').toString(),
                      style: const TextStyle(
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildContractSection(
                  title: 'Service description',
                  children: [
                    _isEditingContract
                        ? _buildContractInput(
                            initialValue: _editableServiceDescription,
                            maxLength: 150,
                            maxLines: 3,
                            validator: _validateContractDescription,
                            onChanged: (value) {
                              _editableServiceDescription = value;
                            },
                          )
                        : Text(
                            (service['description'] ?? '')
                                    .toString()
                                    .trim()
                                    .isEmpty
                                ? '-'
                                : (service['description'] ?? '').toString(),
                            style: const TextStyle(
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                  ],
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildContractSection(
                    title: 'Summary',
                    children: [
                      ...summary.map<Widget>((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            "• ${item.toString()}",
                            style: const TextStyle(
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                _buildContractSection(
                  title: 'Amount',
                  children: [
                    _isEditingContract
                        ? Row(
                            children: [
                              Expanded(
                                child: _buildContractInput(
                                  initialValue: _editableAmount,
                                  maxLength: 10,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.]'),
                                    ),
                                    TextInputFormatter.withFunction((
                                      oldValue,
                                      newValue,
                                    ) {
                                      final text = newValue.text;
                                      if (text.isEmpty) {
                                        return newValue;
                                      }

                                      if (!RegExp(
                                        r'^\d*\.?\d{0,2}$',
                                      ).hasMatch(text)) {
                                        return oldValue;
                                      }

                                      return newValue;
                                    }),
                                  ],
                                  onChanged: (value) {
                                    _editableAmount = value;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'SAR',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            paymentText,
                            style: const TextStyle(
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildContractSection(
                  title: 'Deadline',
                  children: [
                    _isEditingContract
                        ? GestureDetector(
                            onTap: _pickContractDeadline,
                            child: AbsorbPointer(
                              child: _buildContractInput(
                                initialValue: _editableDeadline,
                                readOnly: true,
                                suffixIcon: const Icon(
                                  Icons.calendar_today_outlined,
                                ),
                                onChanged: (value) {
                                  _editableDeadline = value;
                                },
                              ),
                            ),
                          )
                        : Text(
                            (timeline['deadline'] ?? '')
                                    .toString()
                                    .trim()
                                    .isEmpty
                                ? '-'
                                : (timeline['deadline'] ?? '').toString(),
                            style: const TextStyle(
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                  ],
                ),
                if (_isEditingContract) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleAddClause,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Clause'),
                    ),
                  ),
                ],
                if (_isEditingContract && _pendingCustomClauses.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ..._pendingCustomClauses.asMap().entries.map((entry) {
                    final index = entry.key;
                    final clause = entry.value;

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primary.withOpacity(0.12)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            initialValue: clause['title'] ?? '',
                            maxLength: 20,
                            maxLines: 1,
                            onChanged: (value) {
                              _pendingCustomClauses[index]['title'] = value;
                            },
                            decoration: InputDecoration(
                              hintText: 'Clause title',
                              counterText: '',
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8F6FC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: primary.withOpacity(0.12),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: primary.withOpacity(0.12),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            initialValue: clause['content'] ?? '',
                            maxLength: 100,
                            minLines: 2,
                            maxLines: 4,
                            onChanged: (value) {
                              _pendingCustomClauses[index]['content'] = value;
                            },
                            decoration: InputDecoration(
                              hintText: 'Clause content',
                              counterText: '',
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8F6FC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: primary.withOpacity(0.12),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: primary.withOpacity(0.12),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
                if (userCustomClauseEntries.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...userCustomClauseEntries.map((entry) {
                    final index = entry.key;
                    final clause = entry.value as Map;

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primary.withOpacity(0.12)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (clause['title'] ?? '').toString().trim().isEmpty
                                ? 'Clause'
                                : (clause['title'] ?? '').toString(),
                            style: const TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (clause['content'] ?? '').toString().trim().isEmpty
                                ? '-'
                                : (clause['content'] ?? '').toString(),
                            style: const TextStyle(
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                          if (_isEditingContract) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _deleteClause(index),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ],
                if (showApproveActions) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isApprovingContract
                              ? null
                              : _openSignatureAndApprove,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Approve'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isApprovingContract
                              ? null
                              : _disapproveContract,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Disapprove'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (showWaitingForOtherPartySignature) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Waiting for the other party approval.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
                if (showCancelApproval) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isApprovingContract
                          ? null
                          : _callCancelApproval,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Cancel Approval'),
                    ),
                  ),
                ],
                if (showCancelContractButton) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSavingContract ? null : _cancelContract,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Cancel Contract'),
                    ),
                  ),
                ],
                if (currentUserMutualRequestRejected) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD54F)),
                    ),
                    child: Text(
                      'The $otherPartyLabel rejected your mutual termination request. You can continue with paid termination (20%).',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isTerminatingContract
                          ? null
                          : _openTerminationCompensationPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC75A5A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Terminate with 20%'),
                    ),
                  ),
                ],
                if (showApproveTerminationButton) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD54F)),
                    ),
                    child: Text(
                      'The $requesterLabel requested termination for this contract. You can approve or reject this request.',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (showCancelTerminationButton) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primary.withOpacity(0.22)),
                    ),
                    child: Text(
                      'You requested termination for this contract. Please wait for the $otherPartyLabel to respond.',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (showApproveTerminationButton) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isTerminatingContract
                              ? null
                              : _approveTermination,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC75A5A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Approve Termination'),
                        ),
                      ),
                      if (showRejectTerminationButton) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isTerminatingContract
                                ? null
                                : _rejectTermination,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Reject'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                if (showCancelTerminationButton) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isTerminatingContract
                          ? null
                          : _cancelTermination,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Cancel Termination'),
                    ),
                  ),
                ],
                if (contractStatus == 'rejected') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSavingContract ? null : _deleteContract,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete Contract'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewContractStatus =
        ((_contractData?['approval']
                    as Map<String, dynamic>?)?['contractStatus']
                as Object?)
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    final showGenerateContractButton =
        !_isLoadingContractData &&
        (_contractData == null ||
            previewContractStatus == 'terminated' ||
            previewContractStatus == 'cancelled' ||
            previewContractStatus == 'canceled');
    final showPinnedApprovedContract =
        previewContractStatus == 'approved' ||
        previewContractStatus == 'completed';
    final showWorkProgressAction = _shouldShowWorkProgressAction();
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final workProgressContractStatus =
        ((_contractData?['approval']
                    as Map<String, dynamic>?)?['contractStatus']
                as Object?)
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
        leading: const BackButton(),
        titleSpacing: 0,
        actions: [
          if (showWorkProgressAction)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Material(
                  color: _isWorkProgressSheetOpen
                      ? primary.withOpacity(0.16)
                      : const Color(0xFFF6F2FB),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _isSwitchingPanels ? null : _openWorkProgressSheet,
                    customBorder: const CircleBorder(),
                    splashColor: primary.withOpacity(0.12),
                    highlightColor: primary.withOpacity(0.08),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isWorkProgressSheetOpen
                              ? primary.withOpacity(0.28)
                              : primary.withOpacity(0.10),
                        ),
                      ),
                      child: Icon(
                        Icons.timeline_rounded,
                        color: _isWorkProgressSheetOpen
                            ? primary
                            : primary.withOpacity(0.92),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          _buildChatHeaderAdminReviewAction(
            padding: const EdgeInsets.only(right: 12),
          ),
        ],
        title: GestureDetector(
          onTap: _openOtherUserProfile,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFF6F2FB),
                onBackgroundImageError:
                    _otherUserPhotoUrl != null && _otherUserPhotoUrl!.isNotEmpty
                    ? (error, stackTrace) {
                        debugPrint(
                          'Failed to load chat avatar from Firebase Storage: $error',
                        );
                        if (!mounted) return;
                        setState(() {
                          _otherUserPhotoUrl = null;
                        });
                      }
                    : null,
                backgroundImage:
                    _otherUserPhotoUrl != null && _otherUserPhotoUrl!.isNotEmpty
                    ? NetworkImage(_otherUserPhotoUrl!)
                    : null,
                child:
                    (_otherUserPhotoUrl == null || _otherUserPhotoUrl!.isEmpty)
                    ? const Icon(Icons.person, color: primary, size: 20)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.otherUserName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child:
                (!isKeyboardOpen &&
                    showWorkProgressAction &&
                    _isWorkProgressSheetOpen)
                ? Container(
                    key: const ValueKey('work_progress_inline_panel'),
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Material(
                          color: Colors.white,
                          elevation: 2,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F2FB),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: primary.withOpacity(0.12),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInlineWorkProgressHeader(),
                                const SizedBox(height: 12),
                                _buildContractProgressSection(
                                  contractStatus: workProgressContractStatus,
                                  currentUserRole: _currentUserRole(),
                                  showSectionTitle: false,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('work_progress_hidden')),
          ),
          Expanded(
            child: Stack(
              children: [
                StreamBuilder<List<MessageModel>>(
                  stream: _controller.getMessages(widget.chatId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load messages: ${snapshot.error}',
                        ),
                      );
                    }

                    final messages = snapshot.data ?? [];
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom(jump: true);
                    });

                    if (messages.isEmpty) {
                      return const Center(
                        child: Text(
                          'No messages yet.',
                          style: TextStyle(fontSize: 15),
                        ),
                      );
                    }

                    return Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(messages[index]);
                        },
                      ),
                    );
                  },
                ),
                if (!isKeyboardOpen &&
                    showPinnedApprovedContract &&
                    _isApprovedContractPanelExpanded)
                  _buildPinnedApprovedContractScrollable(
                    overlayExpandedPanel: true,
                  ),
              ],
            ),
          ),
          if (!isKeyboardOpen &&
              showPinnedApprovedContract &&
              !_isApprovedContractPanelExpanded)
            _buildPinnedApprovedContractScrollable(),

          SafeArea(
            top: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              // The Scaffold already shifts content for the keyboard via
              // resizeToAvoidBottomInset, so adding viewInsets here causes the
              // bottom area to be pushed twice on real devices.
              padding: const EdgeInsets.only(bottom: 0),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedImages.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F2FB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primary.withOpacity(0.20),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.image_outlined,
                                    color: primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_selectedImages.length} image(s) selected',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 90,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _selectedImages.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    return Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Image.file(
                                            _selectedImages[index],
                                            width: 90,
                                            height: 90,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _selectedImages.removeAt(index);
                                              });
                                            },
                                            child: const CircleAvatar(
                                              radius: 11,
                                              backgroundColor: Colors.black54,
                                              child: Icon(
                                                Icons.close,
                                                size: 13,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'You can send these images with or without text.',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_isGeneratingContract)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primary,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Generating contract.',
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_isSavingContract)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primary,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Saving contract.',
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_contractError != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _contractError!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),

                      _buildContractPreview(),

                      if (showGenerateContractButton)
                        _buildGenerateContractSection(),

                      Row(
                        children: [
                          IconButton(
                            onPressed: _isSending ? null : _pickImages,
                            icon: const Icon(
                              Icons.image_outlined,
                              color: primary,
                            ),
                            tooltip: 'Send image',
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'Write a message.',
                                filled: true,
                                fillColor: const Color(0xFFF6F2FB),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: primary,
                            child: _isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : IconButton(
                                    onPressed: _sendMessage,
                                    icon: const Icon(
                                      Icons.send,
                                      color: Colors.white,
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
          ),
        ],
      ),
    );
  }
}

class _SignatureSheet extends StatefulWidget {
  final Color primary;

  const _SignatureSheet({required this.primary});

  @override
  State<_SignatureSheet> createState() => _SignatureSheetState();
}

class _SignatureSheetState extends State<_SignatureSheet> {
  final GlobalKey _signatureKey = GlobalKey();
  final List<Offset?> _points = [];
  bool _isConfirming = false;

  bool get _hasSignature => _points.any((point) => point != null);

  Future<void> _showErrorDialog(String message) {
    return _showErrorDialogForContext(context, message);
  }

  void _clearSignature() {
    setState(() {
      _points.clear();
    });
  }

  Future<void> _confirmSignature() async {
    if (!_hasSignature || _isConfirming) return;

    setState(() {
      _isConfirming = true;
    });

    try {
      final boundary =
          _signatureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('Signature pad is not ready');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to convert signature to image');
      }

      if (!mounted) return;

      Navigator.of(context).pop(base64Encode(byteData.buffer.asUint8List()));
    } catch (e) {
      if (!mounted) return;
      debugPrint('Signature capture error: $e');
      unawaited(_showErrorDialog(_friendlyErrorMessage(e)));
      setState(() {
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sign Contract',
                        style: TextStyle(
                          color: widget.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isConfirming
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Draw your signature below, then confirm to approve the contract.',
                  style: TextStyle(color: Colors.black54, height: 1.4),
                ),
                const SizedBox(height: 16),
                RepaintBoundary(
                  key: _signatureKey,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) {
                      setState(() {
                        _points.add(details.localPosition);
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _points.add(details.localPosition);
                      });
                    },
                    onPanEnd: (_) {
                      setState(() {
                        _points.add(null);
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.primary.withOpacity(0.2),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CustomPaint(
                          painter: _SignaturePainter(points: _points),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: (_isConfirming || !_hasSignature)
                            ? null
                            : _clearSignature,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: widget.primary,
                          side: BorderSide(
                            color: widget.primary.withOpacity(0.22),
                          ),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_isConfirming || !_hasSignature)
                            ? null
                            : _confirmSignature,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isConfirming
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Confirm'),
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
  }
}

class _ReviewEditorSheet extends StatefulWidget {
  final Color primary;
  final bool isEditing;
  final int initialRating;
  final String initialText;
  final String reviewedUserName;
  final Future<bool> Function(int rating, String reviewText) onSubmit;

  const _ReviewEditorSheet({
    required this.primary,
    required this.isEditing,
    required this.initialRating,
    required this.initialText,
    required this.reviewedUserName,
    required this.onSubmit,
  });

  @override
  State<_ReviewEditorSheet> createState() => _ReviewEditorSheetState();
}

class _ReviewEditorSheetState extends State<_ReviewEditorSheet> {
  late final TextEditingController _textController;
  late int _rating;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating.clamp(0, 5);
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reviewText = _textController.text.trim();

    if (_rating < 1 || _rating > 5) {
      await _showErrorDialogForContext(context, 'Please select a rating');
      return;
    }

    if (reviewText.isEmpty) {
      await _showErrorDialogForContext(context, 'Please enter your review');
      return;
    }

    if (reviewText.length > 100) {
      await _showErrorDialogForContext(
        context,
        'Review must be 100 characters or less',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await widget.onSubmit(_rating, reviewText);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialogForContext(context, _friendlyErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.isEditing ? 'Edit Review' : 'Rate & Review',
                        style: TextStyle(
                          color: widget.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  'Review for ${widget.reviewedUserName}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your rating',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (index) {
                    final starValue = index + 1;
                    return IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _rating = starValue;
                              });
                            },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      icon: Icon(
                        starValue <= _rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 30,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your review',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _textController,
                  minLines: 4,
                  maxLines: 6,
                  maxLength: 100,
                  textInputAction: TextInputAction.newline,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  decoration: InputDecoration(
                    hintText:
                        'Share your experience with this completed service.',
                    filled: true,
                    fillColor: const Color(0xFFF6F2FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      widget.isEditing ? 'Save Review' : 'Submit Review',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  const _SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = i + 1 < points.length ? points[i + 1] : null;

      if (current == null) continue;

      if (next != null) {
        canvas.drawLine(current, next, paint);
      } else {
        canvas.drawCircle(
          current,
          paint.strokeWidth / 2,
          Paint()..color = paint.color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return true;
  }
}
