import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
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

Future<void> _showErrorDialogForContext(
  BuildContext context,
  String message,
) {
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

      final requestId = _extractRequestId(chatDoc.data());
      debugPrint('requestId: $requestId');
      debugPrint('CHAT ID: ${widget.chatId}');
      debugPrint('REQUEST ID: $requestId');

      await _requestContractSubscription?.cancel();

      _requestContractSubscription = FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .snapshots()
          .listen((requestDoc) {
            final rawContractData = requestDoc.data()?['contractData'];
            final hasContractData =
                rawContractData is Map && rawContractData.isNotEmpty;

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
      unawaited(
        _showErrorDialog(
          _friendlyErrorMessage(e),
        ),
      );
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
      unawaited(
        _showErrorDialog(
          _friendlyErrorMessage(e),
        ),
      );
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
            .toLowerCase() ??
        message.contractStatus.trim().toLowerCase();
    if (currentContractStatus == 'terminated') {
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
    final isApprovedContract =
        message.contractStatus.trim().toLowerCase() == 'approved';
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
            const Text(
              'Approved Contract',
              style: TextStyle(
                color: primary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Approved',
                style: TextStyle(
                  color: Color(0xFF2E7D32),
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

            final requestId = _extractRequestId(chatDoc.data());

            final requestDoc = await FirebaseFirestore.instance
                .collection('requests')
                .doc(requestId)
                .get();

            final existingContractData = requestDoc.data()?['contractData'];

            if (existingContractData != null && mounted) {
              setState(() {
                _contractData = Map<String, dynamic>.from(
                  existingContractData as Map,
                );
              });
            }

            final response = await http.post(
              Uri.parse(
                'http://10.0.2.2:5001/generate-contract-from-request-id',
              ),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'requestId': requestId}),
            );

            if (response.statusCode >= 200 && response.statusCode < 300) {
              final data = jsonDecode(response.body) as Map<String, dynamic>;
              debugPrint('API response: $data');

              final rawContractData = data['contractData'];

              if (!mounted) return;

              setState(() {
                _contractData = rawContractData != null
                    ? Map<String, dynamic>.from(rawContractData as Map)
                    : null;
              });

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
          Uri.parse('http://10.0.2.2:5001/update-contract'),
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
            _showErrorDialog(
              _friendlyErrorMessage(response.statusCode),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        debugPrint('Update contract error: $e');
        unawaited(
          _showErrorDialog(
            _friendlyErrorMessage(e),
          ),
        );
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
  }) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black87, height: 1.4),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8F6FC),
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

  String _currentUserRole() {
    final otherRole = widget.otherUserRole.trim().toLowerCase();
    if (otherRole == 'client') return 'freelancer';
    return 'client';
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

      final requestId = _extractRequestId(chatDoc.data());

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5001/approve-contract'),
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

        setState(() {
          if (updatedContractData is Map) {
            _contractData = Map<String, dynamic>.from(updatedContractData);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract approved successfully')),
        );
      } else {
        unawaited(
          _showErrorDialog(
            _friendlyErrorMessage(response.statusCode),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Approve contract error: $e');
      unawaited(
        _showErrorDialog(
          _friendlyErrorMessage(e),
        ),
      );
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

      final requestId = _extractRequestId(chatDoc.data());

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5001/request-termination'),
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
        ).showSnackBar(const SnackBar(content: Text('Termination requested')));
      } else {
        debugPrint(
          'request-termination failed: '
          'status=${response.statusCode}, body=${response.body}',
        );
        unawaited(
          _showErrorDialog(
            _friendlyErrorMessage(response.statusCode),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('request-termination exception: $e');
      unawaited(
        _showErrorDialog(
          _friendlyErrorMessage(e),
        ),
      );
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
        Uri.parse('http://10.0.2.2:5001/approve-termination'),
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
        unawaited(
          _showErrorDialog(
            _friendlyErrorMessage(response.statusCode),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Approve termination error: $e');
      unawaited(
        _showErrorDialog(
          _friendlyErrorMessage(e),
        ),
      );
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
        Uri.parse('http://10.0.2.2:5001/cancel-termination'),
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
        unawaited(
          _showErrorDialog(
            _friendlyErrorMessage(response.statusCode),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Cancel termination error: $e');
      unawaited(
        _showErrorDialog(
          _friendlyErrorMessage(e),
        ),
      );
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
        "http://10.0.2.2:5001/download-contract-pdf?requestId=$requestId",
      );

      final opened = await launchUrl(url);

      if (!opened) {
        if (!mounted) return;
        unawaited(
          _showErrorDialog(
            _friendlyErrorMessage('Could not open PDF'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Download contract error: $e');
      unawaited(
        _showErrorDialog(
          _friendlyErrorMessage(e),
        ),
      );
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

      final requestId = _extractRequestId(chatDoc.data());

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5001/cancel-approval'),
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
        unawaited(
          _showErrorDialog(
            _friendlyErrorMessage(response.statusCode),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Cancel approval error: $e');
      unawaited(
        _showErrorDialog(
          _friendlyErrorMessage(e),
        ),
      );
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

      final requestId = _extractRequestId(chatDoc.data());

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5001/disapprove-contract'),
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
        ).showSnackBar(const SnackBar(content: Text('Contract rejected')));
      } else {
        unawaited(
          _showErrorDialog(
            _friendlyErrorMessage(response.statusCode),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Reject contract error: $e');
      unawaited(
        _showErrorDialog(
          _friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _deleteContract() async {
    final contractData = _contractData;
    if (contractData == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Contract'),
          content: const Text(
            'Are you sure you want to delete this rejected contract?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
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

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5001/delete-contract'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestId': requestId}),
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _contractData = null;
          _isEditingContract = false;
          _isAddingClause = false;
          _pendingCustomClauses = [];
          _contractError = null;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Contract deleted')));
      } else {
        unawaited(
          _showErrorDialog(
            _friendlyErrorMessage(response.statusCode),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Delete contract error: $e');
      unawaited(
        _showErrorDialog(
          _friendlyErrorMessage(e),
        ),
      );
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
    final totalClauses = existingClauses.length + _pendingCustomClauses.length;

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
        Uri.parse('http://10.0.2.2:5001/update-contract'),
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
          unawaited(
            _showErrorDialog(
              _friendlyErrorMessage(response.statusCode),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        debugPrint('Delete clause update error: $e');
        unawaited(
          _showErrorDialog(
            _friendlyErrorMessage(e),
          ),
        );
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

    if (contractStatus == 'approved' || contractStatus == 'terminated') {
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

    final clientApproved = approval['clientApproved'] == true;
    final freelancerApproved = approval['freelancerApproved'] == true;

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

    final amount = (payment['amount'] ?? '').toString();
    final currency = (payment['currency'] ?? '').toString();
    final paymentText = [
      amount,
      currency,
    ].where((part) => part.trim().isNotEmpty).join(' ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.45,
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: double.infinity,
                child: Scrollbar(
                  controller: _contractPreviewScrollController,
                  thumbVisibility: true,
                  thickness: 2.5,
                  radius: const Radius.circular(999),
                  child: SingleChildScrollView(
                    controller: _contractPreviewScrollController,
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
                            if (canEditContract &&
                                contractStatus != 'draft') ...[
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
                                onPressed:
                                    (_isSavingContract || _isApprovingContract)
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
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: Icon(
                                  _isEditingContract ? Icons.check : Icons.edit,
                                ),
                                label: Text(
                                  _isEditingContract ? 'Save' : 'Edit',
                                ),
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
                                ? _buildContractInput(
                                    initialValue: _editableServiceDescription,
                                    maxLines: 3,
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
                                        : (service['description'] ?? '')
                                              .toString(),
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
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          onChanged: (value) {
                                            _editableAmount = value;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        currency.trim().isEmpty
                                            ? '-'
                                            : currency,
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    paymentText.isEmpty ? '-' : paymentText,
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
                                ? _buildContractInput(
                                    initialValue: _editableDeadline,
                                    onChanged: (value) {
                                      _editableDeadline = value;
                                    },
                                  )
                                : Text(
                                    (timeline['deadline'] ?? '')
                                            .toString()
                                            .trim()
                                            .isEmpty
                                        ? '-'
                                        : (timeline['deadline'] ?? '')
                                              .toString(),
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Clause'),
                            ),
                          ),
                        ],
                        if (_isEditingContract && _isAddingClause) ...[
                          const SizedBox(height: 10),
                          ..._pendingCustomClauses.asMap().entries.map((entry) {
                            final index = entry.key;
                            final clause = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: primary.withOpacity(0.12),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      initialValue: clause['title'] ?? '',
                                      onChanged: (value) {
                                        _pendingCustomClauses[index]['title'] =
                                            value;
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Clause title',
                                        isDense: true,
                                        filled: true,
                                        fillColor: const Color(0xFFF8F6FC),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 10,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: primary.withOpacity(0.12),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      initialValue: clause['content'] ?? '',
                                      minLines: 2,
                                      maxLines: 4,
                                      onChanged: (value) {
                                        _pendingCustomClauses[index]['content'] =
                                            value;
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Clause content',
                                        isDense: true,
                                        filled: true,
                                        fillColor: const Color(0xFFF8F6FC),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 10,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: primary.withOpacity(0.12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                        if (userCustomClauseEntries.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ...userCustomClauseEntries.map((entry) {
                            final index = entry.key;
                            final clause = entry.value;
                            final clauseMap = clause is Map
                                ? Map<String, dynamic>.from(clause)
                                : <String, dynamic>{};
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: primary.withOpacity(0.12),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            (clauseMap['title'] ??
                                                    'Custom Clause')
                                                .toString(),
                                            style: const TextStyle(
                                              color: primary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (_isEditingContract)
                                          IconButton(
                                            onPressed: _isSavingContract
                                                ? null
                                                : () => _deleteClause(index),
                                            icon: const Icon(Icons.delete),
                                            color: Colors.redAccent,
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      (clauseMap['content'] ?? '')
                                              .toString()
                                              .trim()
                                              .isEmpty
                                          ? '-'
                                          : (clauseMap['content'] ?? '')
                                                .toString(),
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                        if (showWaitingForOtherPartySignature) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Waiting for other party signature',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                        if (showCancelApproval) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  (_isApprovingContract || _isSavingContract)
                                  ? null
                                  : _callCancelApproval,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE57373),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: _isApprovingContract
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.undo_rounded),
                              label: const Text('Cancel Approval'),
                            ),
                          ),
                        ],
                        if (contractStatus == 'rejected') ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSavingContract
                                  ? null
                                  : _deleteContract,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE57373),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: _isSavingContract
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.delete),
                              label: const Text('Delete Contract'),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.gpp_bad_rounded),
                              label: const Text('Request Termination'),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Approve Termination'),
                            ),
                          ),
                        ],

                        if (showCancelTerminationButton) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isTerminatingContract
                                  ? null
                                  : _cancelTermination,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE57373),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.undo_rounded),
                              label: const Text('Cancel Termination'),
                            ),
                          ),
                        ],

                        if (showCancelTerminationButton) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Termination request sent. Waiting for the other party to approve.',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],

                        if (contractStatus == 'terminated') ...[
                          const SizedBox(height: 8),
                          const Text(
                            'This contract has been terminated.',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],

                        if (contractStatus == 'approved') ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Approved',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],

                        if (showApproveActions) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      (_isApprovingContract ||
                                          _isSavingContract)
                                      ? null
                                      : _openSignatureAndApprove,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    minimumSize: const Size(0, 44),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  child: _isApprovingContract
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Approve & Sign'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      (_isApprovingContract ||
                                          _isSavingContract)
                                      ? null
                                      : _disapproveContract,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFC75A5A),
                                    backgroundColor: const Color(0xFFFFF7F7),
                                    side: const BorderSide(
                                      color: Color(0xFFE6BABA),
                                      width: 1,
                                    ),
                                    minimumSize: const Size(0, 44),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  child: const Text('Disapprove'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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
        _contractData == null || previewContractStatus == 'terminated';

    return Scaffold(
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

          if (_selectedImages.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F2FB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primary.withOpacity(0.20)),
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
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
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
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),

          SafeArea(
            top: false,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            'Generating contract...',
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
                            'Saving contract...',
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
                        icon: const Icon(Icons.image_outlined, color: primary),
                        tooltip: 'Send image',
                      ),
                      const SizedBox(width: 4),

                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Write a message...',
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
      unawaited(
        _showErrorDialog(
          _friendlyErrorMessage(e),
        ),
      );
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
