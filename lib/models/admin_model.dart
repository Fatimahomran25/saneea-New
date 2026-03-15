class AdminModel {
  final String name;
  final String role;
  final String nationalId;
  final String email;

  // ✅ احتياطي: صورة ثابتة من assets
  final String photoAssetPath;

  // ✅ جديد: رابط الصورة من Firebase Storage (Firestore field: photoUrl)
  final String? photoUrl;

  const AdminModel({
    required this.name,
    required this.role,
    required this.nationalId,
    required this.email,
    required this.photoAssetPath,
    this.photoUrl, // ✅ اختياري
  });
}