import 'package:flutter/material.dart';
import '../controlles/recommendation_controller.dart';
import '../models/recommendation_model.dart';

class AnnouncementRequestsView extends StatefulWidget {
  final String announcementId;
  final String announcementDescription;
  final bool fromSeeAll;

  const AnnouncementRequestsView({
    super.key,
    required this.announcementId,
    required this.announcementDescription,
    this.fromSeeAll = false,
  });

  @override
  State<AnnouncementRequestsView> createState() =>
      _AnnouncementRequestsViewState();
}

class _AnnouncementRequestsViewState extends State<AnnouncementRequestsView> {
  static const primary = Color(0xFF5A3E9E);

  final RecommendationController _controller = RecommendationController();
  bool _isLoading = true;
  List<AnnouncementRequest> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final data = await _controller.getRequestsForAnnouncement(
        announcementId: widget.announcementId,
      );

      if (!mounted) return;

      setState(() {
        _requests = data;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load freelancer requests.')),
      );
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
      default:
        return primary;
    }
  }

  Widget _buildCard(AnnouncementRequest request) {
    final statusColor = _statusColor(request.status);

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
              const Icon(Icons.person_outline, color: primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.freelancerName.isEmpty
                      ? 'Freelancer'
                      : request.freelancerName,
                  style: const TextStyle(
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
                  request.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Proposal',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            request.proposalText.isEmpty ? '-' : request.proposalText,
            style: const TextStyle(fontSize: 14),
          ),
          if (request.status.toLowerCase() == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await _controller.updateAnnouncementRequestStatus(
                        requestId: request.id,
                        status: 'accepted',
                      );
                      _loadRequests();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5A3E9E),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Center(
                        child: Text(
                          'Accept',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await _controller.updateAnnouncementRequestStatus(
                        requestId: request.id,
                        status: 'rejected',
                      );
                      _loadRequests();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Center(
                        child: Text(
                          'Reject',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Freelancer Requests'),
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (widget.fromSeeAll)
            IconButton(
              icon: const Icon(Icons.home_outlined),
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'No freelancer applied to this request yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, index) => _buildCard(_requests[index]),
            ),
    );
  }
}
