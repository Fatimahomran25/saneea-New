import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controlles/recommendation_controller.dart';
import '../models/recommendation_model.dart';
import 'freelancer_home.dart';

class MyAnnouncementRequestsView extends StatefulWidget {
  final bool fromAnnouncements;

  const MyAnnouncementRequestsView({super.key, this.fromAnnouncements = false});

  @override
  State<MyAnnouncementRequestsView> createState() =>
      _MyAnnouncementRequestsViewState();
}

class _MyAnnouncementRequestsViewState
    extends State<MyAnnouncementRequestsView> {
  static const Color primary = Color(0xFF5A3E9E);

  final RecommendationController _controller = RecommendationController();

  bool _isLoading = true;
  List<FreelancerAnnouncementRequest> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final data = await _controller.getMyAnnouncementRequests();

      if (!mounted) return;

      setState(() {
        _requests = data;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load requests: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return primary;
    }
  }

  String _formatStatus(String status) {
    if (status.isEmpty) return '-';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatBudget(dynamic budget) {
    if (budget == null) return '-';

    if (budget is num) {
      if (budget == budget.toInt()) {
        return '${budget.toInt()} SAR';
      }
      return '$budget SAR';
    }

    final text = budget.toString().trim();
    if (text.isEmpty) return '-';

    return '$text SAR';
  }

  String _formatDeadline(dynamic deadline) {
    if (deadline == null) return '-';

    if (deadline is Timestamp) {
      final date = deadline.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }

    final text = deadline.toString().trim();
    if (text.isEmpty) return '-';

    return text;
  }

  Future<void> _cancelRequest(FreelancerAnnouncementRequest request) async {
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

    try {
      await _controller.cancelAnnouncementRequest(requestId: request.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request cancelled successfully')),
      );

      _loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to cancel request: $e')));
    }
  }

  Widget _buildRequestCard(FreelancerAnnouncementRequest request) {
    final statusColor = _statusColor(request.status);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(request.clientId)
          .collection('announcements')
          .doc(request.announcementId)
          .get(),
      builder: (context, snapshot) {
        final announcementData = snapshot.data?.data();

        final announcementDescription = (announcementData?['description'] ?? '')
            .toString()
            .trim();
        final budgetText = _formatBudget(announcementData?['budget']);
        final deadlineText = _formatDeadline(announcementData?['deadline']);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F2FB),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_outlined, color: primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'My Proposal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatStatus(request.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Applied to service request',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      announcementDescription.isEmpty
                          ? 'Service requests details not available'
                          : announcementDescription,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          size: 16,
                          color: primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Budget: $budgetText',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Deadline: $deadlineText',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'Proposal',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                request.proposalText.isEmpty ? '-' : request.proposalText,
                style: const TextStyle(fontSize: 14, color: Colors.black),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(request.createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),

              if (request.status.toLowerCase() == 'pending') ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _cancelRequest(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Cancel Request',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Proposals'),
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: true,
        actions: widget.fromAnnouncements
            ? [
                IconButton(
                  icon: const Icon(Icons.home_outlined),
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'You have not sent any requests yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, index) => _buildRequestCard(_requests[index]),
              ),
            ),
    );
  }
}
