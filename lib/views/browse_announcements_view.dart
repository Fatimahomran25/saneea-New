import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saneea_app/views/freelancer_profile.dart';
import 'package:saneea_app/views/my_announcement_requests_view.dart';
import '../controlles/recommendation_controller.dart';
import '../controlles/freelancer_profile_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BrowseAnnouncementsView extends StatefulWidget {
  const BrowseAnnouncementsView({super.key});

  @override
  State<BrowseAnnouncementsView> createState() =>
      _BrowseAnnouncementsViewState();
}

class _BrowseAnnouncementsViewState extends State<BrowseAnnouncementsView> {
  static const Color primary = Color(0xFF5A3E9E);

  final RecommendationController _controller = RecommendationController();

  String _budgetFilter = 'All budgets';
  String _deadlineFilter = 'All deadlines';
  String _sortOption = 'Nearest first';
  String _applyFilter = 'All requests';

  final List<String> _applyOptions = [
    'All requests',
    'Not applied yet',
    'Applied',
  ];

  final List<String> _budgetOptions = [
    'All budgets',
    '0 - 100 SAR',
    '101 - 300 SAR',
    '301 - 500 SAR',
    '501 - 1000 SAR',
    '1000+ SAR',
  ];

  final List<String> _deadlineOptions = [
    'All deadlines',
    'Overdue',
    'Due today',
    'Due this week',
    'Due this month',
  ];

  final List<String> _sortOptions = ['Nearest first', 'Latest first'];

  void _clearFilters() {
    setState(() {
      _budgetFilter = 'All budgets';
      _deadlineFilter = 'All deadlines';
      _sortOption = 'Nearest first';
      _applyFilter = 'All requests';
    });
  }

  double _safeBudget(dynamic rawBudget) {
    if (rawBudget is num) return rawBudget.toDouble();
    return double.tryParse(rawBudget?.toString() ?? '0') ?? 0;
  }

  DateTime? _parseDeadline(dynamic rawDeadline) {
    if (rawDeadline == null) return null;

    if (rawDeadline is Timestamp) {
      return rawDeadline.toDate().toLocal();
    }

    if (rawDeadline is DateTime) {
      return rawDeadline.toLocal();
    }

    if (rawDeadline is String) {
      final value = rawDeadline.trim();
      if (value.isEmpty) return null;

      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toLocal();

      final normalized = value.replaceAll('-', '/');
      final parts = normalized.split('/');

      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);

        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    }

    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _matchesBudget(double budget) {
    switch (_budgetFilter) {
      case '0 - 100 SAR':
        return budget >= 0 && budget <= 100;
      case '101 - 300 SAR':
        return budget >= 101 && budget <= 300;
      case '301 - 500 SAR':
        return budget >= 301 && budget <= 500;
      case '501 - 1000 SAR':
        return budget >= 501 && budget <= 1000;
      case '1000+ SAR':
        return budget > 1000;
      default:
        return true;
    }
  }

  bool _matchesDeadline(DateTime? deadline) {
    if (_deadlineFilter == 'All deadlines') return true;
    if (deadline == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(deadline.year, deadline.month, deadline.day);

    final diff = d.difference(today).inDays;

    switch (_deadlineFilter) {
      case 'Overdue':
        return d.isBefore(today);
      case 'Due today':
        return diff == 0;
      case 'Due this week':
        return diff >= 0 && diff <= 7;
      case 'Due this month':
        return d.year == now.year && d.month == now.month;
      default:
        return true;
    }
  }

  Color _deadlineColor(DateTime? deadline) {
    if (deadline == null) return Colors.black87;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(deadline.year, deadline.month, deadline.day);
    final diff = d.difference(today).inDays;

    if (d.isBefore(today)) return Colors.orange;
    if (diff <= 1) return const Color.fromARGB(255, 245, 208, 0);
    if (diff <= 7) return Colors.green;
    return Colors.black87;
  }

  Future<void> _showApplyDialog({
    required String announcementId,
    required String clientId,
    required String description,
  }) async {
    final TextEditingController proposalController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Apply to service request',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: proposalController,
              maxLines: 4,
              style: const TextStyle(color: Colors.black, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Write your proposal...',
                hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide(color: primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final proposal = proposalController.text.trim();

              if (proposal.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please write a proposal first.'),
                  ),
                );
                return;
              }

              try {
                await _controller.sendAnnouncementRequest(
                  announcementId: announcementId,
                  clientId: clientId,
                  proposalText: proposal,
                );

                if (!mounted) return;
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Proposal sent successfully ✅')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to send proposal: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Apply',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String hint,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Expanded(
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F2FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withOpacity(0.15)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: Text(hint, style: const TextStyle(fontSize: 13)),
            isExpanded: true,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            items: items
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(
                      e,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Future<bool> _checkFreelancerProfileBeforeApply() async {
    final profileController = FreelancerProfileController();
    await profileController.init();

    if (profileController.hasRequiredProfileData) {
      return true;
    }

    if (!mounted) return false;

    final missing = profileController.missingRequiredFields;

    await showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 254, 251, 238), // خلفية تحذير
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔥 العنوان
              Row(
                children: const [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Color.fromARGB(255, 255, 197, 21),
                    size: 28,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Complete your profile to apply',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              const Text(
                'You must complete these details before sending any request:',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),

              const SizedBox(height: 14),

              // 🔥 القائمة
              ...missing.map(
                (field) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 6,
                        color: Color.fromARGB(255, 255, 197, 21),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        field,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 🔥 الأزرار
              Row(
                children: [
                  // زر OK
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color.fromARGB(255, 255, 197, 21),
                        ),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // زر Complete Profile
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);

                        // 👇 اربطيه بصفحة تعديل البروفايل
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FreelancerProfileView(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                          255,
                          255,
                          206,
                          60,
                        ),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Complete Profile',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return false;
  }

  Stream<bool> _hasAppliedStream({
    required String announcementId,
    required String clientId,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);

    return FirebaseFirestore.instance
        .collection('announcement_requests')
        .where('announcementId', isEqualTo: announcementId)
        .where('clientId', isEqualTo: clientId)
        .where('freelancerId', isEqualTo: user.uid)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  Stream<Set<String>> _appliedAnnouncementIdsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(<String>{});

    return FirebaseFirestore.instance
        .collection('announcement_requests')
        .where('freelancerId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => (doc.data()['announcementId'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet();
        });
  }

  Widget _buildAnnouncementCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final description = (data['description'] ?? '').toString();
    final budget = _safeBudget(data['budget']);
    final deadline = _parseDeadline(data['deadline']);
    final clientName = (data['clientName'] ?? '').toString();

    final parentPath = doc.reference.parent.parent;
    final clientId = parentPath?.id ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2FB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            clientName.isEmpty
                ? 'Client service requests'
                : "$clientName's service requests",
            style: const TextStyle(color: primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            description.isEmpty ? '-' : description,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text('Budget: $budget SAR'),
          Text(
            'Deadline: ${_formatDate(deadline)}',
            style: TextStyle(
              color: _deadlineColor(deadline),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          StreamBuilder<bool>(
            stream: _hasAppliedStream(
              announcementId: doc.id,
              clientId: clientId,
            ),
            builder: (context, snapshot) {
              final hasApplied = snapshot.data ?? false;

              return Column(
                children: [
                  if (hasApplied) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              border: Border.all(color: primary),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF5A3E9E),
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Applied',
                                  style: TextStyle(
                                    color: Color(0xFF5A3E9E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const MyAnnouncementRequestsView(
                                          fromAnnouncements: true,
                                        ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'My Proposals',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final canApply =
                              await _checkFreelancerProfileBeforeApply();
                          if (!canApply) return;

                          _showApplyDialog(
                            announcementId: doc.id,
                            clientId: clientId,
                            description: description,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Apply'), // 🔥 هذا اللي ناقص عندك
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Browse service requests'),
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildFilterDropdown(
                      hint: 'Budget',
                      value: _budgetFilter,
                      items: _budgetOptions,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _budgetFilter = value);
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildFilterDropdown(
                      hint: 'Deadline',
                      value: _deadlineFilter,
                      items: _deadlineOptions,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _deadlineFilter = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildFilterDropdown(
                      hint: 'Apply',
                      value: _applyFilter,
                      items: _applyOptions,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _applyFilter = value);
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildFilterDropdown(
                      hint: 'Sort',
                      value: _sortOption,
                      items: _sortOptions,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _sortOption = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _clearFilters,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Clear filters'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<Set<String>>(
              stream: _appliedAnnouncementIdsStream(),
              builder: (context, appliedSnapshot) {
                final appliedIds = appliedSnapshot.data ?? <String>{};

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collectionGroup('announcements')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting ||
                        appliedSnapshot.connectionState ==
                            ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Error: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    final filteredDocs = docs.where((doc) {
                      final data = doc.data();
                      final budget = _safeBudget(data['budget']);
                      final deadline = _parseDeadline(data['deadline']);
                      final hasApplied = appliedIds.contains(doc.id);

                      if (!_matchesBudget(budget)) return false;
                      if (!_matchesDeadline(deadline)) return false;

                      if (_applyFilter == 'Applied') {
                        return hasApplied;
                      }

                      if (_applyFilter == 'Not applied yet') {
                        return !hasApplied;
                      }

                      return true;
                    }).toList();

                    filteredDocs.sort((a, b) {
                      final aDeadline = _parseDeadline(a.data()['deadline']);
                      final bDeadline = _parseDeadline(b.data()['deadline']);

                      if (aDeadline == null && bDeadline == null) return 0;
                      if (aDeadline == null) return 1;
                      if (bDeadline == null) return -1;

                      if (_sortOption == 'Nearest first') {
                        return aDeadline.compareTo(bDeadline);
                      } else {
                        return bDeadline.compareTo(aDeadline);
                      }
                    });

                    if (filteredDocs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'No service requests found.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredDocs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, index) =>
                          _buildAnnouncementCard(filteredDocs[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
