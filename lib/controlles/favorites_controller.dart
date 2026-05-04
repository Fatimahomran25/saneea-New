import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/favorite_user_model.dart';

class FavoritesController {
  FavoritesController({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? _favoritesCollection() {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) return null;
    return _firestore.collection('users').doc(uid).collection('favorites');
  }

  Stream<bool> watchIsFavorite(String favoriteUserId) {
    final collection = _favoritesCollection();
    final normalizedId = favoriteUserId.trim();
    if (collection == null || normalizedId.isEmpty) {
      return const Stream<bool>.empty();
    }

    return collection.doc(normalizedId).snapshots().map((doc) => doc.exists);
  }

  Stream<List<FavoriteUserModel>> favoritesStream() {
    final collection = _favoritesCollection();
    if (collection == null) {
      return const Stream<List<FavoriteUserModel>>.empty();
    }

    return collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(FavoriteUserModel.fromDoc).toList(),
        );
  }

  Future<void> addFavorite({
    required String favoriteUserId,
    required String favoriteUserName,
    required String favoriteUserRole,
    required String favoriteUserProfileImage,
    required String serviceField,
    required double rating,
  }) async {
    final collection = _favoritesCollection();
    final normalizedId = favoriteUserId.trim();
    if (collection == null || normalizedId.isEmpty) return;

    await collection.doc(normalizedId).set({
      'favoriteUserId': normalizedId,
      'favoriteUserName': favoriteUserName.trim().isEmpty
          ? 'User'
          : favoriteUserName.trim(),
      'favoriteUserRole': favoriteUserRole.trim(),
      'favoriteUserProfileImage': favoriteUserProfileImage.trim(),
      'serviceField': serviceField.trim(),
      'rating': double.parse(rating.toStringAsFixed(1)),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeFavorite(String favoriteUserId) async {
    final collection = _favoritesCollection();
    final normalizedId = favoriteUserId.trim();
    if (collection == null || normalizedId.isEmpty) return;
    await collection.doc(normalizedId).delete();
  }
}
