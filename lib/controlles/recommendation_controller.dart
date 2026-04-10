import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/recommendation_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class RecommendationController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String backendBaseUrl =
      "http://10.0.2.2:5000"; // يتغير حسب الجهاز/المحاكي

  String _requestDocId({
    required String clientId,
    required String freelancerId,
  }) {
    return '${clientId}_$freelancerId';
  }

  // 🔧 تعديل فاطمه
  // دالة جديدة بدل القديمة
  // تغير اسم الميثود من _analyzeMatchedWorks إلى _analyzeMatchPercentage
  Future<int> _analyzeMatchPercentage({
    required String description,
    required List<String> images,
  }) async {
    if (images.isEmpty) return 0;

    final response = await http
        .post(
          Uri.parse('$backendBaseUrl/analyze'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'description': description, 'images': images}),
        )
        .timeout(const Duration(minutes: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final matchPercentage = data['matchPercentage'];

      if (matchPercentage == null) return 0;

      return (matchPercentage as num).toInt();
    } else {
      throw Exception('Failed to analyze portfolio');
    }
  }
  // 🔧 نهاية تعديلات فاطمه
  /* Future<int> _analyzeMatchedWorks({
    required String description,
    required List<String> images,
  }) async {
    if (images.isEmpty) return 0;

    final response = await http.post(
      Uri.parse('$backendBaseUrl/analyze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'description': description, 'images': images}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final matchedWorks = data['matchedWorks'];

      if (matchedWorks == null) return 0;
      return (matchedWorks as num).toInt();
    } else {
      throw Exception('Failed to analyze portfolio');
    }
  }*/

  Future<List<RecommendationResult>> findFreelancers({
    required String serviceField,
    required String description,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .where('accountType', isEqualTo: 'freelancer')
        .get();

    final freelancers = snapshot.docs
        .map((doc) => FreelancerRecommendation.fromMap(doc.id, doc.data()))
        .toList();

    // 🔧 تعديل فاطمه
    // تم تعديل الفلترة
    // سابقاً كانت تعتمد فقط على fieldMatch
    // وتم استبدالها بإضافة شرط اكتمال الحساب:
    // Service Field + Service Type + Working Mode + Portfolio
    final filtered = freelancers.where((f) {
      final fieldMatch =
          f.serviceField.trim().toLowerCase() ==
          serviceField.trim().toLowerCase();

      final hasCompleteProfile =
          f.serviceField.trim().isNotEmpty &&
          (f.serviceType?.trim().isNotEmpty ?? false) &&
          (f.workingMode?.trim().isNotEmpty ?? false) &&
          f.portfolioUrls.isNotEmpty;

      return fieldMatch && hasCompleteProfile;
    }).toList();
    // 🔧 نهاية تعديلات فاطمه

    final List<RecommendationResult> results = [];

    // 🔧 تعديل فاطمه
    // تم تغيير المتغير:
    // كان matchedWorks وأصبح matchPercentage
    for (final freelancer in filtered) {
      int matchPercentage = 0;

      try {
        matchPercentage = await _analyzeMatchPercentage(
          description: description,
          images: freelancer.portfolioUrls,
        );
      } catch (e) {
        if (e is TimeoutException) {
          throw Exception('The analysis is taking too long. Please try again.');
        } else {
          throw Exception(e.toString());
        }
      }

      // تم إضافة شرط جديد:
      // لا يتم إضافة الفريلانسر إذا كانت النسبة = 0
      if (matchPercentage > 0) {
        results.add(
          RecommendationResult(
            freelancer: freelancer,
            matchPercentage: matchPercentage,
            rating: freelancer.rating,
          ),
        );
      }
    }
    // 🔧 نهاية تعديلات فاطمه

    // 🔧 تعديل فاطمه
    // تم تعديل ترتيب النتائج:
    // سابقاً: matchedWorks ثم rating
    // حالياً: rating أول ثم matchPercentage
    results.sort((a, b) {
      if (b.rating != a.rating) {
        return b.rating.compareTo(a.rating);
      }
      return b.matchPercentage.compareTo(a.matchPercentage);
    });
    // 🔧 نهاية تعديلات فاطمه

    return results;
  }

  Future<Map<String, dynamic>?> getExistingRequest({
    required String freelancerId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _firestore
        .collection('requests')
        .where('clientId', isEqualTo: user.uid)
        .where('freelancerId', isEqualTo: freelancerId)
        .get();

    if (snapshot.docs.isEmpty) return null;

    // نبحث أولًا عن accepted أو pending فقط
    for (final doc in snapshot.docs) {
      final status = (doc.data()['status'] ?? '').toString().toLowerCase();

      if (status == 'accepted' || status == 'pending') {
        return {'id': doc.id, 'status': status};
      }
    }

    // لو كل الموجود cancelled/rejected نعتبره ما فيه طلب فعّال
    return null;
  }

  Future<void> sendRequest({
    required FreelancerRecommendation freelancer,
    required String description,
    required double budget,
    required String deadline,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('No logged in client found.');
    }

    final clientDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final clientData = clientDoc.data();

    if (clientData == null) {
      throw Exception('Client data not found.');
    }

    final clientName =
        "${clientData['firstName'] ?? ''} ${clientData['lastName'] ?? ''}"
            .trim();

    final requestId = _requestDocId(
      clientId: currentUser.uid,
      freelancerId: freelancer.id,
    );

    final requestRef = _firestore.collection('requests').doc(requestId);
    final existingDoc = await requestRef.get();

    if (existingDoc.exists) {
      final existingData = existingDoc.data() ?? {};
      final status = (existingData['status'] ?? '').toString().toLowerCase();

      if (status == 'pending' || status == 'accepted') {
        throw Exception('already sent');
      }
    }

    final requestData = {
      'clientId': currentUser.uid,
      'clientName': clientName,
      'freelancerId': freelancer.id,
      'freelancerName': freelancer.name,
      'description': description,

      // ✅ أهم إضافة
      'budget': budget,
      'deadline': deadline,

      'status': 'pending',
      'requestType': 'private',

      'createdAt': existingDoc.exists
          ? (existingDoc.data()?['createdAt'] ?? FieldValue.serverTimestamp())
          : FieldValue.serverTimestamp(),

      'updatedAt': FieldValue.serverTimestamp(),
    };

    await requestRef.set(requestData, SetOptions(merge: true));
  }

  Future<void> cancelRequest({required String requestId}) async {
    await _firestore.collection('requests').doc(requestId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, String>> getPendingRequestsForCurrentClient() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('No logged in client found.');
    }

    final snapshot = await _firestore
        .collection('requests')
        .where('clientId', isEqualTo: currentUser.uid)
        .where('status', whereIn: ['pending', 'accepted'])
        .get();

    final Map<String, String> pendingRequests = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final freelancerId = (data['freelancerId'] ?? '').toString();

      if (freelancerId.isNotEmpty) {
        pendingRequests[freelancerId] = doc.id;
      }
    }

    return pendingRequests;
  }

  Future<List<ClientRequest>> getMyRequests() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('No logged in client found.');
    }

    final snapshot = await _firestore
        .collection('requests')
        .where('clientId', isEqualTo: currentUser.uid)
        .where('status', whereIn: ['pending', 'accepted'])
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ClientRequest.fromMap(doc.id, doc.data()))
        .toList();
  }

  // =========================
  // Announcement Requests
  // =========================

  Future<void> sendAnnouncementRequest({
    required String announcementId,
    required String clientId,
    required String proposalText,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('No logged in freelancer found.');
    }

    final freelancerDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final freelancerData = freelancerDoc.data();
    if (freelancerData == null) {
      throw Exception('Freelancer data not found.');
    }

    final freelancerName =
        "${freelancerData['firstName'] ?? ''} ${freelancerData['lastName'] ?? ''}"
            .trim();

    final existing = await _firestore
        .collection('announcement_requests')
        .where('announcementId', isEqualTo: announcementId)
        .where('freelancerId', isEqualTo: currentUser.uid)
        .limit(1)
        .get();

    final requestData = {
      'announcementId': announcementId,
      'clientId': clientId,
      'freelancerId': currentUser.uid,
      'freelancerName': freelancerName,
      'proposalText': proposalText,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (existing.docs.isNotEmpty) {
      await _firestore
          .collection('announcement_requests')
          .doc(existing.docs.first.id)
          .update(requestData);
    } else {
      await _firestore.collection('announcement_requests').add(requestData);
    }
  }

  Future<List<AnnouncementRequest>> getRequestsForAnnouncement({
    required String announcementId,
  }) async {
    final snapshot = await _firestore
        .collection('announcement_requests')
        .where('announcementId', isEqualTo: announcementId)
        .get();

    return snapshot.docs
        .map((doc) => AnnouncementRequest.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> updateAnnouncementRequestStatus({
    required String requestId,
    required String status,
  }) async {
    await _firestore.collection('announcement_requests').doc(requestId).update({
      'status': status,
    });
  }

  Future<List<FreelancerAnnouncementRequest>>
  getMyAnnouncementRequests() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('No logged in freelancer found.');
    }

    final snapshot = await _firestore
        .collection('announcement_requests')
        .where('freelancerId', isEqualTo: currentUser.uid)
        .get();

    return snapshot.docs
        .map((doc) => FreelancerAnnouncementRequest.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> cancelAnnouncementRequest({required String requestId}) async {
    await _firestore.collection('announcement_requests').doc(requestId).update({
      'status': 'cancelled',
    });
  }
}
