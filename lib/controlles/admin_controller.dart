/*import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/admin_model.dart';

class AdminController {
  // ✅ Fallback (لو ما رجع شيء من Firebase)
  AdminModel getAdmin() {
    return const AdminModel(
      name: "Admin",
      role: "Admin",
      nationalId: "----------",
      email: "----------",
      photoAssetPath: "assets/admin.png",
      photoUrl: null,
    );
  }

  // ==========================
  // Firebase: Get Admin Data
  // ==========================
  Future<AdminModel> getAdminFromFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return getAdmin();

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data == null) return getAdmin();

    final first = (data['firstName'] ?? '').toString().trim();
    final last = (data['lastName'] ?? '').toString().trim();
    final email = (data['email'] ?? '').toString().trim();
    final nationalId = (data['nationalId'] ?? '').toString().trim();
    final role = (data['accountType'] ?? 'Admin').toString().trim();
    final photoUrl = (data['photoUrl'] ?? '').toString().trim();

    final fullName = ([
      first,
      last,
    ]..removeWhere((e) => e.isEmpty)).join(' ').trim();
    final safeName = fullName.isEmpty ? "Admin" : fullName;

    return AdminModel(
      name: safeName,
      role: role.isEmpty ? "Admin" : role,
      nationalId: nationalId.isEmpty ? getAdmin().nationalId : nationalId,
      email: email.isEmpty ? getAdmin().email : email,
      photoUrl: photoUrl.isEmpty ? null : photoUrl,
      photoAssetPath: getAdmin().photoAssetPath,
    );
  }

  Future<String> getAdminFullName() async {
    final admin = await getAdminFromFirebase();
    return admin.name.isEmpty ? "Admin" : admin.name;
  }

  // ✅ First name فقط للترحيب في الهوم
  Future<String> getAdminFirstName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "Admin";

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data == null) return "Admin";

    final first = (data['firstName'] ?? '').toString().trim();
    return first.isEmpty ? "Admin" : first;
  }

  // ==========================
  // Upload Profile Photo
  // ==========================
  Future<void> pickAndUploadAdminPhoto(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) return;

      final file = File(picked.path);

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photoUrl': url},
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Profile photo updated ✅")));
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to update photo ❌")));
    }
  }

  // ==========================
  // Navigation
  // ==========================
  void openProfile(BuildContext context) {
    Navigator.pushNamed(context, '/adminProfile');
  }

  void back(BuildContext context) {
    Navigator.pop(context);
  }

  // ==========================
  // Actions
  // ==========================

  /// ✅ Reset Password (Admin)
  /// - يجيب الإيميل من Firestore (users/{uid}.email)
  /// - يرسل رابط الريسيت ويودّي المستخدم لصفحة reset.html في Hosting
  Future<void> resetPassword(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("You are not logged in.")));
        return;
      }

      // ✅ خذي الايميل من Firestore (الأضمن معكم)
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();
      final email = (data?['email'] ?? '').toString().trim();

      if (email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No email found for this account.")),
        );
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: ActionCodeSettings(
          // ✅ رابط صفحة الويب اللي سويتيها (Firebase Hosting)
          url: 'https://freelance-app-be58f.web.app/reset.html',
          // نخليه يفتح بالمتصفح (صفحة الويب)
          handleCodeInApp: false,

          // Android (اختياري لكنه ما يضر)
          androidPackageName: 'com.example.saneea_app',
          androidInstallApp: true,
          androidMinimumVersion: '21',
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reset link sent ✅ Check your email")),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Failed to send reset email.")),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to send reset email.")),
      );
    }
  }

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }
}
*/
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/admin_model.dart';

class AdminController {
  // ✅ Fallback (لو ما رجع شيء من Firebase)
  AdminModel getAdmin() {
    return const AdminModel(
      name: "Admin",
      role: "Admin",
      nationalId: "----------",
      email: "----------",
      photoAssetPath: "assets/admin.png",
      photoUrl: null,
    );
  }

  // ==========================
  // Firebase: Get Admin Data
  // ==========================
  Future<AdminModel> getAdminFromFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return getAdmin();

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data == null) return getAdmin();

    final first = (data['firstName'] ?? '').toString().trim();
    final last = (data['lastName'] ?? '').toString().trim();
    final email = (data['email'] ?? '').toString().trim();
    final nationalId = (data['nationalId'] ?? '').toString().trim();
    final role = (data['accountType'] ?? 'Admin').toString().trim();
    final photoUrl = (data['photoUrl'] ?? '').toString().trim();

    final fullName = ([
      first,
      last,
    ]..removeWhere((e) => e.isEmpty)).join(' ').trim();
    final safeName = fullName.isEmpty ? "Admin" : fullName;

    return AdminModel(
      name: safeName,
      role: role.isEmpty ? "Admin" : role,
      nationalId: nationalId.isEmpty ? getAdmin().nationalId : nationalId,
      email: email.isEmpty ? getAdmin().email : email,
      photoUrl: photoUrl.isEmpty ? null : photoUrl,
      photoAssetPath: getAdmin().photoAssetPath,
    );
  }

  Future<String> getAdminFullName() async {
    final admin = await getAdminFromFirebase();
    return admin.name.isEmpty ? "Admin" : admin.name;
  }

  // ✅ First name فقط للترحيب في الهوم
  Future<String> getAdminFirstName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "Admin";

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data == null) return "Admin";

    final first = (data['firstName'] ?? '').toString().trim();
    return first.isEmpty ? "Admin" : first;
  }

  // ==========================
  // Upload Profile Photo
  // ==========================
  Future<void> pickAndUploadAdminPhoto(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) return;

      final file = File(picked.path);

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photoUrl': url},
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Profile photo updated ✅")));
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to update photo ❌")));
    }
  }

  // ==========================
  // Navigation
  // ==========================
  void openProfile(BuildContext context) {
    Navigator.pushNamed(context, '/adminProfile');
  }

  void back(BuildContext context) {
    Navigator.pop(context);
  }

  // ==========================
  // Actions
  // ==========================

  /// ✅ Reset Password (Admin)
  /// - يجيب الإيميل من Firestore (users/{uid}.email)
  /// - يرسل رابط الريسيت ويودّي المستخدم لصفحة reset.html في Hosting
  Future<void> resetPassword(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("You are not logged in.")));
        return;
      }

      // ✅ خذي الايميل من Firestore (الأضمن معكم)
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();
      final email = (data?['email'] ?? '').toString().trim();

      if (email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No email found for this account.")),
        );
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: ActionCodeSettings(
          // ✅ رابط صفحة الويب اللي سويتيها (Firebase Hosting)
          url: 'https://freelance-app-be58f.web.app/reset.html',
          // نخليه يفتح بالمتصفح (صفحة الويب)
          handleCodeInApp: false,

          // Android (اختياري لكنه ما يضر)
          androidPackageName: 'com.example.saneea_app',
          androidInstallApp: true,
          androidMinimumVersion: '21',
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reset link sent ✅ Check your email")),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Failed to send reset email.")),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to send reset email.")),
      );
    }
  }

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }
}
