class ClientProfileModel {
  final String uid;

  // read-only
  final String nationalId;

  // editable
  final String name;
  final String email;
  final String bio; // <= 150
  final String? photoUrl;

  // computed read-only
  final double rating;

  const ClientProfileModel({
    required this.uid,
    required this.nationalId,
    required this.name,
    required this.email,
    required this.bio,
    required this.photoUrl,
    required this.rating,
  });

  ClientProfileModel copyWith({
    String? nationalId,
    String? name,
    String? email,
    String? bio,
    String? photoUrl,
    double? rating,
  }) {
    return ClientProfileModel(
      uid: uid,
      nationalId: nationalId ?? this.nationalId,
      name: name ?? this.name,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      rating: rating ?? this.rating,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'accountType': 'client',
      'nationalId': nationalId,
      'name': name,
      'email': email,
      'bio': bio,
      'photoUrl': photoUrl,
    };
  }

  static ClientProfileModel fromFirestore({
    required String uid,
    required Map<String, dynamic> data,
    required double rating,
  }) {
    final firstName = (data['firstName'] ?? '').toString().trim();
    final lastName = (data['lastName'] ?? '').toString().trim();
    final composedName = (data['name'] ?? '$firstName $lastName')
        .toString()
        .trim();

    return ClientProfileModel(
      uid: uid,
      nationalId: (data['nationalId'] ?? '').toString(),
      name: composedName.isEmpty ? "Client" : composedName,
      email: (data['email'] ?? '').toString(),
      bio: (data['bio'] ?? '').toString(),
      photoUrl: data['photoUrl']?.toString(),
      rating: rating,
    );
  }
}

class ClientReviewModel {
  final String reviewerName;
  final int rating; // 1..5
  final String text;

  const ClientReviewModel({
    required this.reviewerName,
    required this.rating,
    required this.text,
  });

  static ClientReviewModel fromFirestore(Map<String, dynamic> data) {
    final r = data['rating'];
    final ratingInt = (r is int) ? r : (r is num ? r.toInt() : 0);

    return ClientReviewModel(
      reviewerName: (data['reviewerName'] ?? 'User').toString(),
      rating: ratingInt.clamp(0, 5),
      text: (data['text'] ?? '').toString(),
    );
  }
}
