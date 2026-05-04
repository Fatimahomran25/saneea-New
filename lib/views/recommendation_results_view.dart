import 'package:flutter/material.dart';
import 'package:saneea_app/views/client_home_screen.dart';

import '../models/recommendation_model.dart';
import 'freelancer_profile.dart';
import 'request_action_button.dart';

class RecommendationResultsView extends StatefulWidget {
  final List<RecommendationResult> results;
  final String requestDescription;

  const RecommendationResultsView({
    super.key,
    required this.results,
    required this.requestDescription,
  });

  @override
  State<RecommendationResultsView> createState() =>
      _RecommendationResultsViewState();
}

class _RecommendationResultsViewState extends State<RecommendationResultsView> {
  static const primary = Color(0xFF5A3E9E);

  Widget _buildRatingStars(double rating) {
    return Row(
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 18);
        } else if (index == rating.floor() && rating % 1 != 0) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 18);
        } else {
          return const Icon(Icons.star_border, color: Colors.amber, size: 18);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Recommended Freelancers'),
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.home_outlined,
              color: Color(0xFF5A3E9E),
              size: 26,
            ),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const ClientHomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: widget.results.isEmpty
          ? const Center(
              child: Text(
                'No matching freelancers found.',
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = widget.results[index];
                final freelancer = item.freelancer;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F2FB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        backgroundImage:
                            freelancer.profileImage != null &&
                                freelancer.profileImage!.isNotEmpty
                            ? NetworkImage(freelancer.profileImage!)
                            : null,
                        child: (freelancer.profileImage == null ||
                                freelancer.profileImage!.isEmpty)
                            ? const Icon(
                                Icons.person,
                                color: primary,
                                size: 28,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              freelancer.name.isEmpty
                                  ? 'Freelancer'
                                  : freelancer.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              freelancer.serviceField,
                              style: const TextStyle(
                                color: primary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (item.matchPercentage > 0)
                              Text(
                                'Match: ${item.matchPercentage}%',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const SizedBox(height: 6),
                            if (freelancer.hasExperience)
                              const Text(
                                'Experienced',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            _buildRatingStars(item.rating),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FreelancerProfileView(
                                      userId: freelancer.id,
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                'View Profile',
                                style: TextStyle(
                                  color: primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SendRequestButton(
                        freelancerId: freelancer.id,
                        freelancerName: freelancer.name,
                        iconOnly: true,
                        onChanged: () {
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
