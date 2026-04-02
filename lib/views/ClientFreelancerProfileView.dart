import 'package:flutter/material.dart';
import '../models/recommendation_model.dart';
import 'request_action_button.dart';

//تمت
class ClientFreelancerProfileView extends StatelessWidget {
  final FreelancerRecommendation freelancer;

  const ClientFreelancerProfileView({super.key, required this.freelancer});

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

            SendRequestButton(
              freelancerId: freelancer.id,
              freelancerName: freelancer.name,
            ),
            const SizedBox(height: 16),

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
