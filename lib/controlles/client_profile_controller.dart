import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/client_profile_model.dart';

class ClientProfileController extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // UI state
  bool isLoading = true;
  bool isSaving = false;
  bool isEditing = false;
  String? error;

  ClientProfileModel? profile;
  List<ClientReviewModel> reviews = [];

  // fields
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final bioCtrl = TextEditingController();

  File? pickedImageFile;

  static const int bioMax = 150;
  final RegExp gmailReg = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$');

  int get bioLen => bioCtrl.text.length;

  Future<void> init() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        error = "Not logged in";
        isLoading = false;
        notifyListeners();
        return;
      }

      // 1) read profile
      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

      // 2) read reviews + rating
      final fetchedReviews = await _fetchReviews(user.uid);
      final rating = _avgRating(fetchedReviews);

      profile = ClientProfileModel.fromFirestore(
        uid: user.uid,
        data: data,
        rating: rating,
      );

      reviews = fetchedReviews;

      // fill controllers
      nameCtrl.text = profile!.name;
      emailCtrl.text = profile!.email;
      bioCtrl.text = profile!.bio;

      isLoading = false;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<ClientReviewModel>> _fetchReviews(String uid) async {
    // users/{uid}/reviews
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    return snap.docs
        .map((d) => ClientReviewModel.fromFirestore(d.data()))
        .toList();
  }

  double _avgRating(List<ClientReviewModel> list) {
    if (list.isEmpty) return 0;
    final sum = list.fold<int>(0, (p, r) => p + r.rating);
    return double.parse((sum / list.length).toStringAsFixed(1));
  }

  // edit flow
  void startEdit() {
    if (profile == null) return;
    isEditing = true;
    notifyListeners();
  }

  void cancelEdit() {
    if (profile == null) return;

    isEditing = false;
    pickedImageFile = null;

    nameCtrl.text = profile!.name;
    emailCtrl.text = profile!.email;
    bioCtrl.text = profile!.bio;

    notifyListeners();
  }

  // validators
  String? validateName(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return "Name is required";
    if (value.length < 2) return "Name is too short";
    return null;
  }

  String? validateGmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return "Email is required";
    if (!gmailReg.hasMatch(value))
      return "Enter a valid gmail (name@gmail.com)";
    return null;
  }

  String? validateBio(String? v) {
    final value = (v ?? '');
    if (value.length > bioMax) return "Bio must be $bioMax characters or less";
    return null;
  }

  String? validateIbanNullable(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null; // optional

    // يشيل المسافات
    final clean = s.replaceAll(' ', '');

    // ✅ Saudi IBAN: يبدأ SA وبعدها 22 رقم (المجموع 24)
    final reg = RegExp(r'^SA\d{22}$');
    if (!reg.hasMatch(clean))
      return 'IBAN غير صحيح. مثال: SA00 0000 0000 0000 0000 0000';
    return null;
  }

  // image
  void setPickedImage(File file) {
    if (!isEditing) return;
    pickedImageFile = file;
    notifyListeners();
  }

  Future<String?> _uploadProfileImage(String uid) async {
    if (pickedImageFile == null) return profile?.photoUrl;
    final ref = _storage.ref().child('profile_images').child('$uid.jpg');
    await ref.putFile(pickedImageFile!);
    return await ref.getDownloadURL();
  }

  // save
  Future<bool> save() async {
    if (profile == null) return false;

    isSaving = true;
    error = null;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) throw "Not logged in";

      final newName = nameCtrl.text.trim();
      final parts = newName
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .toList();
      final firstName = parts.isNotEmpty ? parts.first : '';
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      final newEmail = emailCtrl.text.trim();
      final safeBio = bioCtrl.text.length > bioMax
          ? bioCtrl.text.substring(0, bioMax)
          : bioCtrl.text;

      final photoUrl = await _uploadProfileImage(user.uid);

      await _db.collection('users').doc(user.uid).set({
        'accountType': 'client',
        'name': newName,
        'firstName': firstName,
        'lastName': lastName,
        'email': newEmail,
        'bio': safeBio,
        if (photoUrl != null) 'photoUrl': photoUrl,
      }, SetOptions(merge: true));

      // refresh rating/reviews
      final fetchedReviews = await _fetchReviews(user.uid);
      final rating = _avgRating(fetchedReviews);

      reviews = fetchedReviews;
      profile = profile!.copyWith(
        name: newName,
        email: newEmail,
        bio: safeBio,
        photoUrl: photoUrl,
        rating: rating,
      );

      isSaving = false;
      isEditing = false;
      pickedImageFile = null;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // logout -> sign in
  Future<void> logout(BuildContext context) async {
    await _auth.signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  // delete -> signup
  Future<void> deleteAccount(BuildContext context) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // delete Firestore doc first
      await _db.collection('users').doc(user.uid).delete();

      // delete auth user (قد يطلب recent login)
      await user.delete();

      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/signup', (_) => false);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    bioCtrl.dispose();
    super.dispose();
  }
}
