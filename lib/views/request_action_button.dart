import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controlles/account_access_service.dart';
import '../controlles/recommendation_controller.dart';
import 'anouncment_view.dart';
import 'my_requests_view.dart';
import '../views/chat_view.dart';
import '../controlles/chat_controller.dart';
import 'chat_action_button.dart';

class SendRequestButton extends StatefulWidget {
  final String freelancerId;
  final String? freelancerName;
  final VoidCallback? onChanged;
  final bool iconOnly;
  final bool showGoToRequests;

  const SendRequestButton({
    super.key,
    required this.freelancerId,
    this.freelancerName,
    this.onChanged,
    this.iconOnly = false,
    this.showGoToRequests = true,
  });

  @override
  State<SendRequestButton> createState() => _SendRequestButtonState();
}

class _SendRequestButtonState extends State<SendRequestButton> {
  static const Color primary = Color(0xFF5A3E9E);

  final RecommendationController _controller = RecommendationController();
  final ChatController _chatController = ChatController();

  bool _isLoading = true;
  String? _pendingRequestId;
  String? _status;
  String? _chatId;

  @override
  void initState() {
    super.initState();
    _loadRequestState();
  }

  @override
  void didUpdateWidget(covariant SendRequestButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.freelancerId != widget.freelancerId) {
      setState(() {
        _isLoading = true;
        _pendingRequestId = null;
        _status = null;
        _chatId = null;
      });
      _loadRequestState();
    }
  }

  Future<void> _loadRequestState() async {
    try {
      final request = await _controller.getExistingRequest(
        freelancerId: widget.freelancerId,
      );

      final requestId = request?['id'] as String?;
      final status = (request?['status'] ?? '').toString().toLowerCase();
      final chatId = requestId != null && status == 'accepted'
          ? await _chatController.getExistingChatIdForRequest(requestId)
          : null;

      if (!mounted) return;

      setState(() {
        _pendingRequestId = requestId;
        _status = request?['status'] as String?;
        _chatId = chatId;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _pendingRequestId = null;
        _status = null;
        _chatId = null;
        _isLoading = false;
      });
    }
  }

  void _showAlreadyRequestedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request already sent'),
        content: const Text(
          'You already sent a request to this freelancer.\n\n'
          'Please wait for a response or cancel your request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),

          if (widget.showGoToRequests) // 👈 الشرط هنا
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _goToMyRequests();
              },
              child: const Text('Go to My Requests'),
            ),
        ],
      ),
    );
  }

  Future<void> _openRequestForm() async {
    final request = await _controller.getExistingRequest(
      freelancerId: widget.freelancerId,
    );

    if (!mounted) return;

    if (request != null) {
      final requestId = request['id'] as String?;
      final status = (request['status'] ?? '').toString().toLowerCase();
      final chatId = requestId != null && status == 'accepted'
          ? await _chatController.getExistingChatIdForRequest(requestId)
          : null;

      if (!mounted) return;

      setState(() {
        _pendingRequestId = requestId;
        _status = request['status'] as String?;
        _chatId = chatId;
      });

      if (status == 'accepted') {
        await _openExistingChat(chatId ?? '');
      } else {
        _showAlreadyRequestedDialog();
      }
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AnnouncementView(
          freelancerId: widget.freelancerId,
          freelancerName: widget.freelancerName ?? '',
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      setState(() {
        _isLoading = true;
      });

      await _loadRequestState();
      widget.onChanged?.call();
    }
  }

  Future<void> _cancelRequest() async {
    if (_pendingRequestId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text('Are you sure you want to cancel this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final requestId = _pendingRequestId!;

    setState(() {
      _isLoading = true;
    });

    try {
      await _controller.cancelRequest(requestId: requestId);

      if (!mounted) return;

      setState(() {
        _pendingRequestId = null;
        _status = null;
        _chatId = null;
        _isLoading = false;
      });

      widget.onChanged?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request cancelled successfully.')),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', '').trim() ==
                    AccountAccessService.blockedActionMessage
                ? AccountAccessService.blockedActionMessage
                : 'Failed to cancel request.',
          ),
        ),
      );
    }
  }

  Future<void> _goToMyRequests() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyRequestsView()),
    );

    if (!mounted) return;
    await _loadRequestState();
    widget.onChanged?.call();
  }

  Future<void> _openExistingChat(String chatId) async {
    final requestId = _pendingRequestId;

    try {
      String? existingChatId = chatId.trim();

      if (requestId != null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open chat right now.')),
          );
          return;
        }

        existingChatId = await _chatController.createOrGetChat(
          requestId: requestId,
          clientId: currentUser.uid,
          freelancerId: widget.freelancerId,
        );
      }

      if (!mounted) return;

      if (existingChatId == null || existingChatId.isEmpty) {
        setState(() {
          _chatId = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat is not available yet.')),
        );
        return;
      }

      final safeChatId = existingChatId;

      setState(() {
        _chatId = safeChatId;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatView(
            chatId: safeChatId,
            otherUserName: widget.freelancerName ?? 'Freelancer',
            otherUserId: widget.freelancerId,
            otherUserRole: 'freelancer',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open chat right now.')),
      );
    }
  }

  Widget _buildChatButton(String chatId) {
    // 🔹 الحالة الأولى: الكارد (Top rated)
    if (widget.iconOnly) {
      return GestureDetector(
        onTap: () => _openExistingChat(chatId),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
          child: const Icon(
            Icons.chat_bubble_outline,
            color: Colors.white,
            size: 18,
          ),
        ),
      );
    }

    // 🔹 الحالة الثانية: زر كبير (مثلاً داخل شاشة ثانية)
    return SizedBox(
      width: double.infinity,
      child: ChatActionButton(
        onPressed: () => _openExistingChat(chatId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final hasRequest = _pendingRequestId != null;
    final status = (_status ?? '').toLowerCase();

    // ✅ accepted → Chat فقط
    if (hasRequest && status == 'accepted') {
      return _buildChatButton((_chatId ?? '').trim());
    }

    // ✅ no request → Send Request
    if (!hasRequest) {
      return InkWell(
        onTap: _openRequestForm,
        borderRadius: BorderRadius.circular(14),
        child: widget.iconOnly
            ? Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.send_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.send_outlined, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Send Request',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
      );
    }

    // ✅ pending + iconOnly
    if (hasRequest && status == 'pending' && widget.iconOnly) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _showAlreadyRequestedDialog,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF5A3E9E).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF5A3E9E), size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Requested',
                    style: TextStyle(
                      color: Color(0xFF5A3E9E),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 28,
            child: OutlinedButton(
              onPressed: _cancelRequest,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ✅ pending + full button
    if (hasRequest && status == 'pending') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF5A3E9E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: Color(0xFF5A3E9E)),
                SizedBox(width: 4),
                Text(
                  'Requested',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5A3E9E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: _goToMyRequests,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A3E9E),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'My Requests',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.30),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    onPressed: _cancelRequest,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // ✅ rejected / cancelled / أي حالة ثانية → Send Request
    return InkWell(
      onTap: _openRequestForm,
      borderRadius: BorderRadius.circular(14),
      child: widget.iconOnly
          ? Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.send_outlined,
                color: Colors.white,
                size: 18,
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.send_outlined, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Send Request',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
