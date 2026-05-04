import 'package:cloud_firestore/cloud_firestore.dart';

class FavoriteUserModel {
  final String favoriteUserId;
  final String favoriteUserName;
  final String favoriteUserRole;
  final String favoriteUserProfileImage;
  final String serviceField;
  final double rating;
  final DateTime? createdAt;

  const FavoriteUserModel({
    required this.favoriteUserId,
    required this.favoriteUserName,
    required this.favoriteUserRole,
    required this.favoriteUserProfileImage,
    required this.serviceField,
    required this.rating,
    required this.createdAt,
  });

  factory FavoriteUserModel.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawRating = data['rating'];

    return FavoriteUserModel(
      favoriteUserId: (data['favoriteUserId'] ?? doc.id).toString().trim(),
      favoriteUserName: (data['favoriteUserName'] ?? 'User').toString().trim(),
      favoriteUserRole: (data['favoriteUserRole'] ?? '').toString().trim(),
      favoriteUserProfileImage:
          (data['favoriteUserProfileImage'] ?? '').toString().trim(),
      serviceField: (data['serviceField'] ?? '').toString().trim(),
      rating: rawRating is num
          ? rawRating.toDouble()
          : double.tryParse(rawRating?.toString() ?? '0') ?? 0.0,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
