import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controlles/recommendation_controller.dart';
import '../models/recommendation_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../views/chat_view.dart';
import '../controlles/chat_controller.dart';
import 'anouncment_view.dart';

class MyRequestsView extends StatefulWidget {
  final String? initialRequestId;

  const MyRequestsView({super.key, this.initialRequestId});

  @override
  State<MyRequestsView> createState() => _MyRequestsViewState();
}

class _MyRequestsViewState extends State<MyRequestsView> {
  static const primary = Color(0xFF5A3E9E);

  final RecommendationController _controller = RecommendationController();
  final ChatController _chatController = ChatController();

  bool _isLoading = true;
  List<ClientRequest> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final initialRequestId = widget.initialRequestId?.trim();
      final data = initialRequestId != null && initialRequestId.isNotEmpty
          ? await _loadSingleRequest(initialRequestId)
          : await _controller.getMyRequests();

      if (!mounted) return;

      setState(() {
        _requests = data;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to load requests.')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<ClientRequest>> _loadSingleRequest(String requestId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('No logged in client found.');
    }

    final doc = await FirebaseFirestore.instance
        .collection('requests')
        .doc(requestId)
        .get();

    final data = doc.data();
    final clientId = (data?['clientId'] ?? '').toString();
    if (data == null || clientId != currentUser.uid) {
      return [];
    }

    return [ClientRequest.fromMap(doc.id, data)];
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
      case 'freelancer_deleted_account':
        return Colors.red;
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

  Future<void> _cancelRequest(ClientRequest request) async {
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

    await _controller.cancelRequest(requestId: request.id);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Request cancelled')));

    _loadRequests();
  }

  Future<void> _openExistingChat(ClientRequest request) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open chat right now.')),
      );
      return;
    }

    final chatId = await _chatController.createOrGetChat(
      requestId: request.id,
      clientId: currentUser.uid,
      freelancerId: request.freelancerId,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatView(
          chatId: chatId,
          otherUserName: request.freelancerName,
          otherUserId: request.freelancerId,
          otherUserRole: 'freelancer',
        ),
      ),
    );
  }

  Widget _buildChatActionButton({
    required VoidCallback onPressed,
    bool isEnabled = true,
    bool isLoading = false,
  }) {
    return IgnorePointer(
      ignoring: !isEnabled,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.7,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A3E9E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onPressed,
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Chat'),
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptedChatAction(ClientRequest request) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('requests')
          .doc(request.id)
          .snapshots(),
      builder: (context, requestSnapshot) {
        final storedChatId = (requestSnapshot.data?.data()?['chatId'] ?? '')
            .toString()
            .trim();

        if (storedChatId.isNotEmpty) {
          return _buildChatActionButton(
            onPressed: () => _openExistingChat(request),
          );
        }

        return StreamBuilder<String?>(
          stream: _chatController.watchChatIdForRequest(request.id),
          builder: (context, chatSnapshot) {
            final resolvedChatId = (chatSnapshot.data ?? '').trim();
            final hasChat =
                storedChatId.isNotEmpty || resolvedChatId.isNotEmpty;
            final isLoading =
                requestSnapshot.connectionState == ConnectionState.waiting ||
                chatSnapshot.connectionState == ConnectionState.waiting;

            return _buildChatActionButton(
              onPressed: () => _openExistingChat(request),
              isEnabled: true,
              isLoading: !hasChat && isLoading,
            );
          },
        );
      },
    );
  }

  Widget _buildRequestCard(ClientRequest request) {
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
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(request.freelancerId)
                .get(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();

              final firstName = (data?['firstName'] ?? '').toString().trim();
              final lastName = (data?['lastName'] ?? '').toString().trim();

              final latestName = ('$firstName $lastName').trim().isEmpty
                  ? (request.freelancerName.isEmpty
                        ? 'Freelancer'
                        : request.freelancerName)
                  : ('$firstName $lastName').trim();

              final imageUrl = (data?['photoUrl'] ?? data?['profile'] ?? '')
                  .toString()
                  .trim();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFF6F2FB),
                        child: ClipOval(
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) {
                                    return const Icon(
                                      Icons.person,
                                      color: primary,
                                    );
                                  },
                                )
                              : const Icon(Icons.person, color: primary),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          latestName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (request.status.toLowerCase() == 'pending')
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AnnouncementView(
                                  requestId: request.id,
                                  initialDescription: request.description,
                                  initialBudget: request.budget,
                                  initialDeadline: request.deadline,
                                ),
                              ),
                            );
                          },
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
                ],
              );
            },
          ),
          if (request.status.toLowerCase() == 'freelancer_deleted_account') ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'This request was cancelled because the freelancer deleted their account.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Request Description',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            request.description.isEmpty ? '-' : request.description,
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
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _cancelRequest(request),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red),
                ),
                child: const Center(
                  child: Text(
                    'Cancel Request',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (request.status.toLowerCase() == 'accepted') ...[
            const SizedBox(height: 12),
            _buildAcceptedChatAction(request),
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
        title: const Text('My Requests'),
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? const Center(
              child: Text('No requests found.', style: TextStyle(fontSize: 16)),
            )
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final request = _requests[index];
                  return _buildRequestCard(request);
                },
              ),
            ),
    );
  }
}
