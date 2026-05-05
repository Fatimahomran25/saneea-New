import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controlles/favorites_controller.dart';
import '../models/favorite_user_model.dart';
import 'client_profile.dart';
import 'favorite_heart_button.dart';
import 'freelancer_client_profile_view.dart';
import 'freelancer_profile.dart';

class FavoritesListView extends StatefulWidget {
  const FavoritesListView({super.key});

  @override
  State<FavoritesListView> createState() => _FavoritesListViewState();
}

class _FavoritesListViewState extends State<FavoritesListView> {
  static const Color primary = Color(0xFF5A3E9E);
  final FavoritesController _controller = FavoritesController();
  String _currentAccountType = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserRole();
  }

  Future<void> _loadCurrentUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!mounted) return;

    setState(() {
      _currentAccountType = (userDoc.data()?['accountType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
    });
  }

  String _formatRoleLabel(FavoriteUserModel item) {
    final role = item.favoriteUserRole.trim();
    final serviceField = item.serviceField.trim();
    final normalizedRole = role.toLowerCase();
    final normalizedField = serviceField.toLowerCase();

    if (normalizedRole == 'client') {
      return 'Client';
    }

    if (serviceField.isEmpty) {
      return role.isEmpty ? '-' : role;
    }

    if (normalizedField == normalizedRole || normalizedField == 'client') {
      return role.isEmpty ? serviceField : role;
    }

    if (role.isEmpty) {
      return serviceField;
    }

    return '$serviceField / ${role[0].toUpperCase()}${role.substring(1)}';
  }

  void _openFavoriteProfile(FavoriteUserModel item) {
    final role = item.favoriteUserRole.trim().toLowerCase();

    if (role == 'freelancer') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FreelancerProfileView(userId: item.favoriteUserId),
        ),
      );
      return;
    }

    if (_currentAccountType == 'freelancer') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              FreelancerClientProfileView(clientId: item.favoriteUserId),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientProfile(userId: item.favoriteUserId),
      ),
    );
  }

  Widget _buildStars(double rating, {double size = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (index == rating.floor() && rating % 1 != 0) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.amber, size: size);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Favorites'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
      ),
      body: StreamBuilder<List<FavoriteUserModel>>(
        stream: _controller.favoritesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final favorites = snapshot.data ?? [];
          if (favorites.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No favorites yet.'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = favorites[index];
              final roleLabel = _formatRoleLabel(item);

              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _openFavoriteProfile(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F2FB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white,
                          backgroundImage:
                              item.favoriteUserProfileImage.isNotEmpty
                              ? NetworkImage(item.favoriteUserProfileImage)
                              : null,
                          child: item.favoriteUserProfileImage.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: primary,
                                  size: 24,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.favoriteUserName.isEmpty
                                    ? 'User'
                                    : item.favoriteUserName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                roleLabel.trim().isEmpty ? '-' : roleLabel,
                                style: const TextStyle(
                                  color: primary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildStars(item.rating),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: 10,
                                  top: 3,
                                ),
                                child: SizedBox(
                                  height: 28,
                                  child: ElevatedButton(
                                    onPressed: () => _openFavoriteProfile(item),
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
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        FavoriteHeartButton(
                          favoriteUserId: item.favoriteUserId,
                          favoriteUserName: item.favoriteUserName,
                          favoriteUserRole: item.favoriteUserRole,
                          favoriteUserProfileImage:
                              item.favoriteUserProfileImage,
                          serviceField: item.serviceField,
                          rating: item.rating,
                          iconSize: 22,
                          padding: const EdgeInsets.all(8),
                          backgroundColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
