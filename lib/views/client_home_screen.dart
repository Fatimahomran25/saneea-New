import 'package:flutter/material.dart';
import 'package:saneea_app/views/client_profile.dart';
import 'anouncment_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  static const primary = Color(0xFF5A3E9E);

  Future<bool> _hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) return false;

    try {
      final lookup = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 3));
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myAnnouncementsStream() {
    final user = FirebaseAuth.instance.currentUser!;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  final TextEditingController _searchController = TextEditingController();

  // Local data (NO Firebase)
  final List<_CategoryModel> _categories = const [
    _CategoryModel(title: "Graphic\nDesigners", icon: Icons.brush_outlined),
    _CategoryModel(title: "Marketing", icon: Icons.campaign_outlined),
    _CategoryModel(title: "Software\nDevelopers", icon: Icons.code_outlined),
    _CategoryModel(
      title: "Accounting",
      icon: Icons.account_balance_wallet_outlined,
    ),
    _CategoryModel(title: "Tutoring", icon: Icons.design_services_outlined),
  ];

  final List<_FreelancerModel> _allFreelancers = [
    _FreelancerModel(
      name: "Lina Alharbi",
      role: "Marketing",
      rating: 4,
      imagePath: "assets/toprated/lina.jpg",
    ),
    _FreelancerModel(
      name: "Ahmed Ali",
      role: "Graphic Designer",
      rating: 4,
      imagePath: "assets/toprated/ahmed.jpg",
    ),
    _FreelancerModel(
      name: "Khalid Fahad",
      role: "Software Developer",
      rating: 3,
      imagePath: "assets/toprated/khalid.jpg",
    ),
  ];

  // New announcements returned from AnnouncementView
  final List<String> _announcements = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);

  List<_FreelancerModel> get _filteredFreelancers {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allFreelancers;
    return _allFreelancers.where((f) {
      return f.name.toLowerCase().contains(q) ||
          f.role.toLowerCase().contains(q);
    }).toList();
  }

  void _openAnnouncement() async {
    try {
      debugPrint('PLUS TAPPED ✅');

      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const AnnouncementView()),
      );

      debugPrint('Returned: $result');

      if (!mounted) return;

      if (result != null && result.trim().isNotEmpty) {
        setState(() {
          _announcements.insert(0, result.trim());
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Published successfully ✅')),
        );
      }
    } catch (e, st) {
      debugPrint('OPEN SERVICE REQUEST ERROR: $e');
      debugPrint('$st');

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening page: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      bottomNavigationBar: _BottomNavigationBar(
        primary: primary,
        onCenterTap: _openAnnouncement,
      ),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final contentMaxWidth = w > 700 ? 560.0 : w;
            final padding = _clamp(w * 0.06, 16, 28);

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(padding, 6, padding, padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ClientProfile(),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: primary.withOpacity(0.12),
                              child: const Icon(
                                Icons.person_outline,
                                color: primary,
                                size: 22,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.notifications_none,
                              color: primary,
                              size: 26,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Search
                      Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: Colors.grey.shade500,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: "Search....",
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            Icon(Icons.tune, color: primary, size: 20),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Categories (horizontal scroll)
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final c = _categories[index];
                            return SizedBox(
                              width: 100,
                              child: _CategoryItem(
                                title: c.title,
                                icon: c.icon,
                                primary: primary,
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Top rated
                      Text(
                        "Top rated",
                        style: TextStyle(
                          fontSize: _clamp(w * 0.055, 20, 24),
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ..._filteredFreelancers.map(
                        (f) => _FreelancerTile(freelancer: f, primary: primary),
                      ),

                      const SizedBox(height: 18),

                      // Announcements list (local, from publish)
                      ...[
                        Text(
                          "Service Requests",
                          style: TextStyle(
                            fontSize: _clamp(w * 0.05, 18, 22),
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 10),

                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _myAnnouncementsStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            }

                            final docs = snapshot.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return const Text('No service requests yet.');
                            }

                            return Column(
                              children: docs.map((doc) {
                                final text = (doc.data()['text'] ?? '')
                                    .toString();

                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      text,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () async {
                                        // 🔹 تأكيد قبل الحذف
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text(
                                              'Delete Service Requests?',
                                            ),
                                            content: const Text(
                                              'This action cannot be undone.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm != true) return;

                                        // 🔹 فحص الإنترنت
                                        final online = await _hasInternet();
                                        if (!online) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'No internet connection. Please try again.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        try {
                                          await doc.reference.delete();

                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Deleted successfully ✅',
                                              ),
                                            ),
                                          );
                                        } on FirebaseException catch (e) {
                                          if (!context.mounted) return;

                                          if (e.code == 'unavailable' ||
                                              e.code ==
                                                  'network-request-failed') {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'No internet connection. Please try again.',
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Something went wrong. Please try again.',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (_) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Something went wrong. Please try again.',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ---------- Models ----------
class _CategoryModel {
  final String title;
  final IconData icon;
  const _CategoryModel({required this.title, required this.icon});
}

class _FreelancerModel {
  final String name;
  final String role;
  final int rating; // 0..5
  final String imagePath;

  _FreelancerModel({
    required this.name,
    required this.role,
    required this.rating,
    required this.imagePath,
  });
}

/// ---------- Widgets ----------
class _CategoryItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color primary;

  const _CategoryItem({
    required this.title,
    required this.icon,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey.shade200,
          child: Icon(icon, color: primary, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, height: 1.1),
        ),
      ],
    );
  }
}

class _FreelancerTile extends StatelessWidget {
  final _FreelancerModel freelancer;
  final Color primary;

  const _FreelancerTile({required this.freelancer, required this.primary});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: AssetImage(freelancer.imagePath),
        onBackgroundImageError: (_, __) {},
      ),
      title: Text(
        freelancer.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            freelancer.role,
            style: TextStyle(color: primary.withOpacity(0.85)),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < freelancer.rating ? Icons.star : Icons.star_border,
                size: 16,
                color: Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigationBar extends StatelessWidget {
  final Color primary;
  final VoidCallback onCenterTap;

  const _BottomNavigationBar({
    required this.primary,
    required this.onCenterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.chat_bubble_outline, color: primary, size: 26),
          Icon(Icons.bookmark_border, color: primary, size: 26),
          GestureDetector(
            onTap: onCenterTap,
            child: CircleAvatar(
              radius: 30,
              backgroundColor: primary,
              child: const Icon(Icons.add, size: 34, color: Colors.white),
            ),
          ),
          Icon(Icons.work_outline, color: primary, size: 26),
          SizedBox(width: 26),
        ],
      ),
    );
  }
}
