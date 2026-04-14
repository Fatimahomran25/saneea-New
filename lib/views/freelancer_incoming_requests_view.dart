import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controlles/freelancer_requests_controller.dart';
import 'freelancer_client_profile_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controlles/chat_controller.dart';
import 'chat_view.dart';

class FreelancerIncomingRequestsView extends StatefulWidget {
  final String? initialRequestId;

  const FreelancerIncomingRequestsView({super.key, this.initialRequestId});

  @override
  State<FreelancerIncomingRequestsView> createState() =>
      _FreelancerIncomingRequestsViewState();
}

class _FreelancerIncomingRequestsViewState
    extends State<FreelancerIncomingRequestsView> {
  final FreelancerRequestsController controller =
      FreelancerRequestsController();

  late Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _futureRequests;

  static const Color primary = Color(0xFF5A3E9E);

  @override
  void initState() {
    super.initState();
    _futureRequests = controller.getIncomingRequests();
  }

  Future<void> _reload() async {
    setState(() {
      _futureRequests = controller.getIncomingRequests();
    });
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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _visibleRequests(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> requests,
  ) {
    final requestId = widget.initialRequestId;
    if (requestId == null || requestId.isEmpty) {
      return requests;
    }

    return requests.where((doc) => doc.id == requestId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Incoming Requests'),
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        future: _futureRequests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final requests = snapshot.data ?? [];
          final visibleRequests = _visibleRequests(requests);

          if (visibleRequests.isEmpty) {
            return const Center(
              child: Text(
                'This request is no longer available.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: visibleRequests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final doc = visibleRequests[index];
                final data = doc.data();

                final clientName = (data['clientName'] ?? 'Client').toString();
                final description = (data['description'] ?? '').toString();
                final clientId = (data['clientId'] ?? '').toString();
                final status = (data['status'] ?? '').toString().toLowerCase();

                if (status == 'cancelled_by_client') {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F2FB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'This request was cancelled because the client deleted their account.',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F2FB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(clientId)
                        .get(),
                    builder: (context, snapshot) {
                      final userData = snapshot.data?.data();

                      final firstName = (userData?['firstName'] ?? '')
                          .toString()
                          .trim();
                      final lastName = (userData?['lastName'] ?? '')
                          .toString()
                          .trim();

                      final latestName = ('$firstName $lastName').trim().isEmpty
                          ? clientName
                          : ('$firstName $lastName').trim();

                      final imageUrl =
                          (userData?['photoUrl'] ?? userData?['profile'] ?? '')
                              .toString()
                              .trim();

                      final budgetText = _formatBudget(data['budget']);
                      final deadlineText = _formatDeadline(data['deadline']);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: Colors.white,
                                    backgroundImage: imageUrl.isNotEmpty
                                        ? NetworkImage(imageUrl)
                                        : null,
                                    child: imageUrl.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            color: primary,
                                            size: 22,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      latestName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: status == 'accepted'
                                          ? Colors.green.withOpacity(0.12)
                                          : const Color(0xFFF6E7D8),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      status == 'accepted'
                                          ? 'Accepted'
                                          : 'Pending',
                                      style: TextStyle(
                                        color: status == 'accepted'
                                            ? Colors.green
                                            : Colors.orange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 0),
                              Padding(
                                padding: const EdgeInsets.only(left: 54),
                                child: SizedBox(
                                  height: 28,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              FreelancerClientProfileView(
                                                clientId: clientId,
                                              ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text(
                                      'View Profile',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          const Text(
                            'Request description',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 6),

                          Text(
                            description.isEmpty ? '-' : description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 14),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.payments_outlined,
                                      size: 18,
                                      color: primary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Budget:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        budgetText,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                      color: primary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Deadline:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        deadlineText,
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

                          const SizedBox(height: 18),

                          const SizedBox(height: 18),

                          if (status == 'pending') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 40,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: primary,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                      ),
                                      onPressed: () async {
                                        await controller.acceptRequest(doc.id);
                                        await _reload();
                                      },
                                      child: const Text(
                                        'Accept',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: SizedBox(
                                    height: 40,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        side: const BorderSide(
                                          color: Colors.red,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                      ),
                                      onPressed: () async {
                                        await controller.rejectRequest(doc.id);
                                        await _reload();
                                      },
                                      child: const Text(
                                        'Reject',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (status == 'accepted') ...[
                            SizedBox(
                              width: double.infinity,
                              height: 42,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                onPressed: () async {
                                  final chatController = ChatController();

                                  final chatId = await chatController
                                      .createOrGetChat(
                                        requestId: doc.id,
                                        clientId: clientId,
                                        freelancerId: FirebaseAuth
                                            .instance
                                            .currentUser!
                                            .uid,
                                      );

                                  if (!context.mounted) return;

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatView(
                                        chatId: chatId,
                                        otherUserName: latestName,
                                        otherUserId: clientId,
                                        otherUserRole: 'client',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Chat'),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
