import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../controlles/admin_controller.dart';
import '../controlles/notification_navigation_service.dart';
import '../controlles/request_notifications_controller.dart';
import 'admin_contract_reviews_view.dart';
import 'admin_general_reports_view.dart';
import 'request_notifications_sheet.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  static const Color _pageBackground = Color(0xFFFCFAFF);

  final AdminController _controller = AdminController();
  int _currentIndex = 0;

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _openProfile() {
    _controller.openProfile(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _AdminDashboardTab(
            controller: _controller,
            onOpenGeneralReports: () => _selectTab(1),
            onOpenContractReviews: () => _selectTab(2),
            onOpenProfile: _openProfile,
          ),
          const AdminGeneralReportsView(),
          const AdminContractReviewsView(),
          _AdminProfileTab(
            controller: _controller,
            onOpenProfile: _openProfile,
          ),
        ],
      ),
      bottomNavigationBar: _AdminBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _selectTab,
      ),
    );
  }
}

class _AdminDashboardTab extends StatelessWidget {
  const _AdminDashboardTab({
    required this.controller,
    required this.onOpenGeneralReports,
    required this.onOpenContractReviews,
    required this.onOpenProfile,
  });

  final AdminController controller;
  final VoidCallback onOpenGeneralReports;
  final VoidCallback onOpenContractReviews;
  final VoidCallback onOpenProfile;

  static const Color _pageBackground = Color(0xFFFCFAFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _pageBackground,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final contentMaxWidth = width > 700 ? 560.0 : width;
            final horizontalPadding = width > 700 ? 24.0 : 18.0;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    10,
                    horizontalPadding,
                    24,
                  ),
                  children: [
                    _DashboardHeader(
                      controller: controller,
                      onOpenProfile: onOpenProfile,
                    ),
                    const SizedBox(height: 22),
                    const _SectionTitle(title: 'Overview'),
                    const SizedBox(height: 12),
                    const _OverviewSection(),
                    const SizedBox(height: 24),
                    const _SectionTitle(title: 'Quick Access'),
                    const SizedBox(height: 12),
                    _QuickAccessCard(
                      icon: Icons.outlined_flag_rounded,
                      title: 'General Reports',
                      description: 'Review user and content reports.',
                      onTap: onOpenGeneralReports,
                    ),
                    const SizedBox(height: 12),
                    _QuickAccessCard(
                      icon: Icons.fact_check_outlined,
                      title: 'Contract Reviews',
                      description: 'Check disputes and contract requests.',
                      onTap: onOpenContractReviews,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.controller,
    required this.onOpenProfile,
  });

  final AdminController controller;
  final VoidCallback onOpenProfile;

  static const Color _primaryPurple = Color(0xFF5A3E9E);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              GestureDetector(
                onTap: onOpenProfile,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: _primaryPurple.withOpacity(0.12),
                  child: const Icon(
                    Icons.person_outline,
                    color: _primaryPurple,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FutureBuilder<String>(
                  future: controller.getAdminFirstName(),
                  builder: (context, snapshot) {
                    final firstName = (snapshot.data ?? '').trim();
                    final safeName = firstName.isEmpty ? 'Admin' : firstName;

                    return Text(
                      'Welcome back, $safeName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _primaryPurple,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const _AdminNotificationButton(),
      ],
    );
  }
}

class _AdminNotificationButton extends StatefulWidget {
  const _AdminNotificationButton({super.key});

  @override
  State<_AdminNotificationButton> createState() => _AdminNotificationButtonState();
}

class _AdminNotificationButtonState extends State<_AdminNotificationButton> {
  final RequestNotificationsController _notificationsController =
      RequestNotificationsController();

  static const Color _primaryPurple = Color(0xFF5A3E9E);

  Future<void> _openNotificationTarget(RequestNotificationItem item) async {
    if (!mounted) return;
    Navigator.of(context).pop();
    await handleNotificationTap(context: context, notification: item);
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.8,
        child: RequestNotificationsSheet(
          controller: _notificationsController,
          onOpen: _openNotificationTarget,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _notificationsController.unreadCountStream(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return GestureDetector(
          onTap: _openNotifications,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F2FB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _primaryPurple.withOpacity(0.10)),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: _primaryPurple,
                  size: 22,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFC75A5A),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  static const Color _primaryPurple = Color(0xFF5A3E9E);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: _primaryPurple,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('general_reports').snapshots(),
      builder: (context, generalSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('contract_reports').snapshots(),
          builder: (context, contractSnapshot) {
            final generalDocs = generalSnapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final contractDocs = contractSnapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];

            final isLoading =
                generalSnapshot.connectionState == ConnectionState.waiting ||
                    contractSnapshot.connectionState == ConnectionState.waiting;

            final openCount = _countWithFallback(
              generalDocs,
              const {'open', 'submitted', 'pending'},
              fallback: 'open',
            );

            final underReviewCount =
                _countWithFallback(
                  generalDocs,
                  const {'under_review'},
                  fallback: 'open',
                ) +
                    _countWithFallback(
                      contractDocs,
                      const {'under_review'},
                      fallback: 'requested',
                    );

            final contractReviewCount = contractDocs.length;

            final resolvedCount =
                _countWithFallback(
                  generalDocs,
                  const {'resolved', 'valid'},
                  fallback: 'open',
                ) +
                    _countWithFallback(
                      contractDocs,
                      const {'resolved'},
                      fallback: 'requested',
                    );

            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.22,
              children: [
                _OverviewStatCard(
                  icon: Icons.outlined_flag_rounded,
                  label: 'Open Reports',
                  value: isLoading ? '--' : openCount.toString(),
                ),
                _OverviewStatCard(
                  icon: Icons.hourglass_top_rounded,
                  label: 'Under Review',
                  value: isLoading ? '--' : underReviewCount.toString(),
                ),
                _OverviewStatCard(
                  icon: Icons.fact_check_outlined,
                  label: 'Contract Reviews',
                  value: isLoading ? '--' : contractReviewCount.toString(),
                ),
                _OverviewStatCard(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Resolved',
                  value: isLoading ? '--' : resolvedCount.toString(),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _OverviewStatCard extends StatelessWidget {
  const _OverviewStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  static const Color _primaryPurple = Color(0xFF5A3E9E);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryPurple.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: _primaryPurple.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF6F2FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _primaryPurple, size: 19),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black.withOpacity(0.68),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  static const Color _primaryPurple = Color(0xFF5A3E9E);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primaryPurple.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: _primaryPurple.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F2FB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _primaryPurple, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.64),
                        fontSize: 12.8,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F2FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: _primaryPurple,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminProfileTab extends StatelessWidget {
  const _AdminProfileTab({
    required this.controller,
    required this.onOpenProfile,
  });

  final AdminController controller;
  final VoidCallback onOpenProfile;

  static const Color _primaryPurple = Color(0xFF5A3E9E);
  static const Color _pageBackground = Color(0xFFFCFAFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _pageBackground,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final contentMaxWidth = width > 700 ? 560.0 : width;
            final horizontalPadding = width > 700 ? 24.0 : 18.0;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    10,
                    horizontalPadding,
                    24,
                  ),
                  children: [
                    _DashboardHeader(
                      controller: controller,
                      onOpenProfile: onOpenProfile,
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(title: 'Profile'),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onOpenProfile,
                        borderRadius: BorderRadius.circular(16),
                        child: Ink(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _primaryPurple.withOpacity(0.10),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryPurple.withOpacity(0.05),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6F2FB),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.person_outline,
                                  color: _primaryPurple,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Admin Profile',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Open your account and profile settings.',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.black.withOpacity(0.64),
                                        fontSize: 12.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: _primaryPurple,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdminBottomNavigationBar extends StatelessWidget {
  const _AdminBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          _AdminNavItem(
            label: 'Dashboard',
            icon: Icons.home_outlined,
            selected: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _AdminNavItem(
            label: 'General',
            icon: Icons.outlined_flag_rounded,
            selected: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _AdminNavItem(
            label: 'Contracts',
            icon: Icons.fact_check_outlined,
            selected: currentIndex == 2,
            onTap: () => onTap(2),
          ),
          _AdminNavItem(
            label: 'Profile',
            icon: Icons.person_outline,
            selected: currentIndex == 3,
            onTap: () => onTap(3),
          ),
        ],
      ),
    );
  }
}

class _AdminNavItem extends StatelessWidget {
  const _AdminNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  static const Color _primaryPurple = Color(0xFF5A3E9E);
  static const Color _inactiveNav = Color(0xFF9A92B8);

  @override
  Widget build(BuildContext context) {
    final color = selected ? _primaryPurple : _inactiveNav;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

int _countWithFallback(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  Set<String> statuses, {
  required String fallback,
}) {
  return docs.where((doc) {
    final status = _normalizedStatus(doc.data()['status'], fallback: fallback);
    return statuses.contains(status);
  }).length;
}

String _normalizedStatus(dynamic value, {required String fallback}) {
  final text = (value ?? '').toString().trim().toLowerCase().replaceAll(
        ' ',
        '_',
      );
  if (text.isEmpty) {
    return fallback.trim().toLowerCase().replaceAll(' ', '_');
  }
  return text;
}
