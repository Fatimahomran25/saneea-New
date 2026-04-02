import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FreelancerRequestsController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getIncomingRequests() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No logged in freelancer found.');
    }

    final snapshot = await _firestore
        .collection('requests')
        .where('freelancerId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    return snapshot.docs;
  }

  Future<void> acceptRequest(String requestId) async {
    await _firestore.collection('requests').doc(requestId).update({
      'status': 'accepted',
    });
  }

  Future<void> rejectRequest(String requestId) async {
    await _firestore.collection('requests').doc(requestId).update({
      'status': 'rejected',
    });
  }
}
