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
import 'package:url_launcher/url_launcher.dart';

String _friendlyErrorMessage(Object error) {
  final rawError = error.toString().replaceFirst('Exception: ', '').trim();
  final normalizedError = rawError.toLowerCase();
  final statusCode = error is int ? error : int.tryParse(rawError);

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
  List<File> _selectedImages = [];
  String? _otherUserPhotoUrl;
  final ImagePicker _picker = ImagePicker();
  final ChatController _controller = ChatController();
  final TextEditingController _messageController = TextEditingController();
  final GlobalKey<FormState> _contractFormKey = GlobalKey<FormState>();
  Map<String, dynamic>? _contractData;
  bool _isGeneratingContract = false;
  bool _isSavingContract = false;
  bool _isApprovingContract = false;
  bool _isTerminatingContract = false;
  bool _isEditingContract = false;
  bool _isAddingClause = false;
  String? _contractError;
  String _editableServiceDescription = '';
  String _editableAmount = '';
  String _editableDeadline = '';
  List<Map<String, String>> _pendingCustomClauses = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _requestContractSubscription;
  final TextEditingController _clauseTitleController = TextEditingController();
  final TextEditingController _clauseContentController =
      TextEditingController();
  final ScrollController _contractPreviewScrollController = ScrollController();
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 300), () {
      _controller.markMessagesAsRead(widget.chatId);
    });
    _loadOtherUserPhoto();
    _listenToRequestContract();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(jump: true);
    });
  }

  Future<void> _showErrorDialog(String message) {
    return _showErrorDialogForContext(context, message);
  }

  String _extractRequestId(Map<String, dynamic>? chatData) {
    final requestId = (chatData?['requestId'] ?? '').toString().trim();

    if (requestId.isEmpty) {
      throw Exception('requestId is missing in chat document');
    }

    return requestId;
  }

  Future<void> _listenToRequestContract() async {
    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chat')
          .doc(widget.chatId)
          .get();

      final chatData = chatDoc.data();
      final requestId = _extractRequestId(chatData);
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
          _contractData = hasContractData
              ? Map<String, dynamic>.from(rawContractData as Map)
              : null;
        });
      });
    } catch (e) {
      debugPrint('Error listening to request contract: $e');

      if (!mounted) return;
      setState(() {
        _contractData = null;
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
    _contractPreviewScrollController.dispose();
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
    final timeline =
        (_contractData?['timeline'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final contractDeadline = (timeline['deadline'] ?? '').toString();
    final hideTerminateButton = _hasContractDeadlinePassed(contractDeadline);
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
        decoration: BoxDecoration(
          color: const Color(0xFFF6F2FB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primary.withOpacity(0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cardTitleText,
              style: const TextStyle(
                color: primary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
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
            if (message.contractTitle.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                message.contractTitle.trim(),
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (previewText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                previewText,
                style: const TextStyle(color: Colors.black87, height: 1.4),
              ),
            ],
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
                  if (!hideTerminateButton) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isTerminatingContract
                            ? null
                            : _requestTermination,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC75A5A),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Terminate'),
                      ),
                    ),
                  ],
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

            final response = await http.post(
              Uri.parse(
                '${ApiConfig.baseUrl}/generate-contract-from-request-id',
              ),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(requestBody),
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

  Widget _buildContractSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
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
            title,
            style: const TextStyle(
              color: primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
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
      final formState = _contractFormKey.currentState;
      if (formState != null && !formState.validate()) {
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

        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/update-contract'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'requestId': requestId,
            'role': _currentUserRole(),
            'contractData': updatedContractData,
          }),
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
        fillColor: const Color(0xFFF8F6FC),
        suffixIcon: suffixIcon,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary.withOpacity(0.12)),
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

  String _currentUserRole() {
    final otherRole = widget.otherUserRole.trim().toLowerCase();
    if (otherRole == 'client') return 'freelancer';
    return 'client';
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
      }
    } catch (e) {
      debugPrint('Create contract notification error: $e');
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

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/approve-contract'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requestId': requestId,
          'role': _currentUserRole(),
          'signatureData': signatureData,
        }),
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

  Future<void> _requestTermination() async {
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

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/request-termination'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestId': requestId, 'role': _currentUserRole()}),
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
          type: 'contract_termination_requested',
          actionText: 'requested to terminate the contract',
          requestId: requestId,
          chatData: chatData,
          contractData: normalizedContractData,
        );

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Termination requested')));
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

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/approve-termination'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestId': requestId, 'role': _currentUserRole()}),
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

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/cancel-termination'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestId': requestId, 'role': _currentUserRole()}),
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
      final url = Uri.parse(
        "${ApiConfig.baseUrl}/download-contract-pdf?requestId=$requestId",
      );

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

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/cancel-approval'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestId': requestId, 'role': _currentUserRole()}),
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

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/disapprove-contract'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestId': requestId, 'role': _currentUserRole()}),
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

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/$endpointPath'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
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

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/update-contract'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requestId': requestId,
          'role': _currentUserRole(),
          'contractData': updatedContractData,
        }),
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

    final currentUserRole = _currentUserRole();
    final currentUserRequestedTermination =
        terminationRequestedBy == currentUserRole;

    final showTerminateButton =
        contractStatus == 'approved' && !terminationRequested;

    final showApproveTerminationButton =
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
    final contractTitle = (meta['title'] ?? '').toString();

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

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6FC),
        borderRadius: BorderRadius.circular(16),
      ),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        contractTitle.trim().isEmpty
                            ? 'Generated Contract'
                            : contractTitle,
                        style: const TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (canEditContract && contractStatus != 'draft') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusChipBackgroundColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusChipIcon,
                              size: 14,
                              color: statusChipTextColor,
                            ),
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
                      const SizedBox(width: 8),
                    ],
                    if (canEditContract)
                      ElevatedButton.icon(
                        onPressed: (_isSavingContract || _isApprovingContract)
                            ? null
                            : _toggleContractEdit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          _isEditingContract ? Icons.check : Icons.edit,
                        ),
                        label: Text(_isEditingContract ? 'Save' : 'Edit'),
                      ),
                    if (!canEditContract) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusChipBackgroundColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusChipIcon,
                              size: 14,
                              color: statusChipTextColor,
                            ),
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
                ),
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
                        ? Form(
                            key: _contractFormKey,
                            child: _buildContractInput(
                              initialValue: _editableServiceDescription,
                              maxLength: 150,
                              maxLines: 3,
                              validator: _validateContractDescription,
                              onChanged: (value) {
                                _editableServiceDescription = value;
                              },
                            ),
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
                if (showTerminateButton) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isTerminatingContract
                          ? null
                          : _requestTermination,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC75A5A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Terminate'),
                    ),
                  ),
                ],
                if (showApproveTerminationButton) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
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
        _contractData == null ||
        previewContractStatus == 'terminated' ||
        previewContractStatus == 'cancelled' ||
        previewContractStatus == 'canceled';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
        leading: const BackButton(),
        titleSpacing: 0,
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
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _controller.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load messages: ${snapshot.error}'),
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
          ),

          SafeArea(
            top: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
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

                      if (showGenerateContractButton) ...[
                        _buildGenerateButton(),
                        const SizedBox(height: 10),
                      ],

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
