import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'favorite_heart_button.dart';
import 'report_flag_button.dart';

//تمت
class FreelancerClientProfileView extends StatelessWidget {
  final String clientId;
  final bool fromChat;
  const FreelancerClientProfileView({
    super.key,
    required this.clientId,
    this.fromChat = false,
  });

  static const primary = Color(0xFF5A3E9E);

  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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

  Widget _infoTile({required String title, required String value}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
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
    );
  }

  Widget _reviewTile({
    required String name,
    required String reviewerProfileUrl,
    required int rating,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0x66B8A9D9).withOpacity(0.7),
          width: 1.1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0x66B8A9D9).withOpacity(0.6),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: reviewerProfileUrl.trim().isNotEmpty
                  ? Image.network(
                      reviewerProfileUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return const Icon(Icons.person_outline, size: 20);
                      },
                    )
                  : const Icon(Icons.person_outline, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _buildRatingStars(rating.toDouble()),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _loadClientData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(clientId)
        .get();

    return doc.data();
  }

  Future<List<Map<String, dynamic>>> _loadClientReviews() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(clientId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    final missingReviewerIds = <String>{};
    final baseReviews = snap.docs.map((e) => e.data()).toList();

    for (final review in baseReviews) {
      final reviewerProfileUrl =
          ((review['reviewerProfileUrl'] ??
                      review['senderProfileUrl'] ??
                      review['senderProfileImage']) ??
                  '')
              .toString()
              .trim();
      final reviewerId = (review['reviewerId'] ?? '').toString().trim();

      if (reviewerProfileUrl.isEmpty && reviewerId.isNotEmpty) {
        missingReviewerIds.add(reviewerId);
      }
    }

    final resolvedUrls = <String, String>{};
    if (missingReviewerIds.isNotEmpty) {
      final userDocs = await Future.wait(
        missingReviewerIds.map((reviewerId) {
          return FirebaseFirestore.instance
              .collection('users')
              .doc(reviewerId)
              .get();
        }),
      );

      for (final userDoc in userDocs) {
        final userData = userDoc.data();
        if (userData == null) continue;
        final reviewerProfileUrl =
            ((userData['photoUrl'] ?? userData['profile']) ?? '')
                .toString()
                .trim();
        if (reviewerProfileUrl.isNotEmpty) {
          resolvedUrls[userDoc.id] = reviewerProfileUrl;
        }
      }
    }

    return baseReviews.map((review) {
      final enrichedReview = Map<String, dynamic>.from(review);
      final reviewerProfileUrl =
          ((enrichedReview['reviewerProfileUrl'] ??
                      enrichedReview['senderProfileUrl'] ??
                      enrichedReview['senderProfileImage']) ??
                  '')
              .toString()
              .trim();
      final reviewerId = (enrichedReview['reviewerId'] ?? '').toString().trim();

      if (reviewerProfileUrl.isEmpty &&
          reviewerId.isNotEmpty &&
          resolvedUrls.containsKey(reviewerId)) {
        enrichedReview['reviewerProfileUrl'] = resolvedUrls[reviewerId];
      }

      return enrichedReview;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadClientData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text('Profile'),
              centerTitle: true,
              backgroundColor: Colors.white,
              foregroundColor: primary,
              elevation: 0,
            ),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final data = snapshot.data;

        if (data == null) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text('Profile'),
              centerTitle: true,
              backgroundColor: Colors.white,
              foregroundColor: primary,
              elevation: 0,
            ),
            body: const Center(child: Text('Client profile not found')),
          );
        }

        final firstName = (data['firstName'] ?? '').toString().trim();
        final lastName = (data['lastName'] ?? '').toString().trim();
        final name = (data['name'] ?? '$firstName $lastName').toString().trim();
        final displayName = name.isEmpty ? 'Client' : name;

        final bio = (data['bio'] ?? '').toString();
        final email = (data['email'] ?? '').toString();

        final rawRating = data['rating'];
        final rating = rawRating is num ? rawRating.toDouble() : 0.0;
        final photoUrl = (data['photoUrl'] ?? data['profile'] ?? '').toString();
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final showReportAction = currentUserId != clientId;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Profile'),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: primary,
            elevation: 0,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FavoriteHeartButton(
                  favoriteUserId: clientId,
                  favoriteUserName: displayName,
                  favoriteUserRole: 'client',
                  favoriteUserProfileImage: photoUrl,
                  serviceField: 'Client',
                  rating: rating,
                  iconSize: 24,
                  padding: const EdgeInsets.all(10),
                  backgroundColor: const Color(0xFFF6F2FB),
                ),
              ),
              if (showReportAction)
                ReportFlagButton(
                  padding: const EdgeInsets.only(right: 12),
                  onPressed: () {
                    showReportIssueDialog(
                      context: context,
                      source: 'profile',
                      reportedUserId: clientId,
                      reportedUserName: displayName,
                      reportedUserRole: 'client',
                    );
                  },
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: const Color(0xFFF6F2FB),
                    child: ClipOval(
                      child: photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
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
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Client',
                    style: TextStyle(
                      fontSize: 15,
                      color: primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(child: _buildRatingStars(rating)),
                const SizedBox(height: 24),

                _infoTile(
                  title: 'Bio',
                  value: bio.isEmpty ? 'No bio added yet.' : bio,
                ),

                _infoTile(title: 'Email Address', value: email),

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadClientReviews(),
                  builder: (context, reviewSnapshot) {
                    if (reviewSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F2FB),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reviews',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 10),
                            Center(child: CircularProgressIndicator()),
                          ],
                        ),
                      );
                    }

                    if (reviewSnapshot.hasError) {
                      return _infoTile(
                        title: 'Reviews',
                        value: 'Failed to load reviews.',
                      );
                    }

                    final reviews = reviewSnapshot.data ?? [];

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F2FB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reviews',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          if (reviews.isEmpty)
                            const Text(
                              'No reviews yet.',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            )
                          else
                            ...reviews.map((review) {
                              final reviewerName =
                                  (review['reviewerName'] ?? 'User').toString();
                              final reviewerProfileUrl =
                                  ((review['reviewerProfileUrl'] ??
                                              review['senderProfileUrl'] ??
                                              review['senderProfileImage']) ??
                                          '')
                                      .toString();
                              final reviewText = (review['text'] ?? '')
                                  .toString();

                              final rawReviewRating = review['rating'];
                              final reviewRating = rawReviewRating is int
                                  ? rawReviewRating
                                  : (rawReviewRating is num
                                        ? rawReviewRating.toInt()
                                        : 0);

                              return _reviewTile(
                                name: reviewerName,
                                reviewerProfileUrl: reviewerProfileUrl,
                                rating: reviewRating.clamp(0, 5),
                                text: reviewText,
                              );
                            }),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
