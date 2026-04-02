import 'package:flutter/material.dart';
import '../controlles/recommendation_controller.dart';
import 'anouncment_view.dart';
import 'my_requests_view.dart';

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

  bool _isLoading = true;
  String? _pendingRequestId;

  @override
  void initState() {
    super.initState();
    _loadRequestState();
  }

  Future<void> _loadRequestState() async {
    try {
      final requestId = await _controller.getExistingRequestId(
        freelancerId: widget.freelancerId,
      );

      if (!mounted) return;

      setState(() {
        _pendingRequestId = requestId;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _pendingRequestId = null;
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
    final latestRequestId = await _controller.getExistingRequestId(
      freelancerId: widget.freelancerId,
    );

    if (!mounted) return;

    if (latestRequestId != null) {
      setState(() {
        _pendingRequestId = latestRequestId;
      });

      _showAlreadyRequestedDialog();
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
        _isLoading = false;
      });

      widget.onChanged?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request cancelled successfully.')),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to cancel request.')),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final hasPendingRequest = _pendingRequestId != null;

    if (!hasPendingRequest) {
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
                      'Send Service Request',
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

    if (widget.iconOnly) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _showAlreadyRequestedDialog,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(
                  0xFF5A3E9E,
                ).withOpacity(0.12), // 👈 نفس البادج
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF5A3E9E), // 👈 بنفسجي
                size: 18,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Requested badge
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

        // Buttons row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // My Requests (يسار)
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

            // Cancel (يمين + ظل أحمر خفيف)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.30), // 👈 ظل خفيف
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
}
