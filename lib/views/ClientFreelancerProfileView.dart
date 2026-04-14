import 'package:flutter/material.dart';
import '../models/recommendation_model.dart';
import 'request_action_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controlles/chat_controller.dart';
import 'chat_view.dart';

//تمت
class ClientFreelancerProfileView extends StatelessWidget {
  final FreelancerRecommendation freelancer;
  final bool fromChat;
  const ClientFreelancerProfileView({
    super.key,
    required this.freelancer,
    this.fromChat = false,
  });

  static const primary = Color(0xFF5A3E9E);

  Widget _buildRatingStars(double rating) {
    return Row(
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 20);
        } else if (index == rating.floor() && rating % 1 != 0) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 20);
        } else {
          return const Icon(Icons.star_border, color: Colors.amber, size: 20);
        }
      }),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value.trim().isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _portfolioSection() {
    if (freelancer.portfolioUrls.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F2FB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'No portfolio uploaded.',
          style: TextStyle(fontSize: 14),
        ),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: freelancer.portfolioUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final imageUrl = freelancer.portfolioUrls[index];

          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 110,
              color: const Color(0xFFF6F2FB),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = freelancer.name.trim().isEmpty
        ? 'Freelancer'
        : freelancer.name;

    final profileImage = freelancer.profileImage;
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Freelancer Profile'),
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 46,
              backgroundColor: const Color(0xFFF6F2FB),
              child: ClipOval(
                child: (profileImage != null && profileImage.isNotEmpty)
                    ? Image.network(
                        profileImage,
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return const Icon(
                            Icons.person,
                            size: 42,
                            color: primary,
                          );
                        },
                      )
                    : const Icon(Icons.person, size: 42, color: primary),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              freelancer.serviceField,
              style: const TextStyle(
                fontSize: 15,
                color: primary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            _buildRatingStars(freelancer.rating),
            const SizedBox(height: 24),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('requests')
                  .where('clientId', isEqualTo: currentUserId)
                  .where('freelancerId', isEqualTo: freelancer.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox();
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return SendRequestButton(
                    freelancerId: freelancer.id,
                    freelancerName: freelancer.name,
                  );
                }

                QueryDocumentSnapshot<Map<String, dynamic>>? acceptedRequest;

                for (final doc in docs) {
                  final docStatus = (doc.data()['status'] ?? '')
                      .toString()
                      .toLowerCase();
                  if (docStatus == 'accepted') {
                    acceptedRequest = doc;
                    break;
                  }
                }

                if (acceptedRequest != null && !fromChat) {
                  final requestId = acceptedRequest.id;

                  return SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: () async {
                        final chatController = ChatController();

                        final chatId = await chatController.createOrGetChat(
                          requestId: requestId,
                          clientId: currentUserId,
                          freelancerId: freelancer.id,
                        );

                        if (!context.mounted) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatView(
                              chatId: chatId,
                              otherUserName: freelancer.name,
                              otherUserId: freelancer.id,
                              otherUserRole: 'freelancer',
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Chat',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }

                bool hasPending = false;

                for (final doc in docs) {
                  final docStatus = (doc.data()['status'] ?? '')
                      .toString()
                      .toLowerCase();
                  if (docStatus == 'pending') {
                    hasPending = true;
                    break;
                  }
                }

                if (hasPending) {
                  return const Text(
                    'Request sent',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }

                return SendRequestButton(
                  freelancerId: freelancer.id,
                  freelancerName: freelancer.name,
                );
              },
            ),
            _infoTile(
              icon: Icons.work_outline,
              title: 'Service Type',
              value: freelancer.serviceType,
            ),
            _infoTile(
              icon: Icons.location_on_outlined,
              title: 'Working Mode',
              value: freelancer.workingMode,
            ),

            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Portfolio',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            _portfolioSection(),
          ],
        ),
      ),
    );
  }
}
