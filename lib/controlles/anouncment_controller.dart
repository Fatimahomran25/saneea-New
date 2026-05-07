import 'package:flutter/material.dart';
import '../models/anouncment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'account_access_service.dart';

class AnnouncementController extends ChangeNotifier {
  AnnouncementModel _model = AnnouncementModel();

  

final TextEditingController descriptionController = TextEditingController();
final TextEditingController budgetController = TextEditingController();

String? selectedDuration;

  AnnouncementModel get model => _model;

  void onDescriptionChanged(String value) {
  _model = _model.copyWith(description: value);
  notifyListeners();
}

void onBudgetChanged(String value) {
  final budget = double.tryParse(value) ?? 0;
  _model = _model.copyWith(budget: budget);
  notifyListeners();
}

void onDurationChanged(String? value) {
  if (value == null) return;
  selectedDuration = value;
  _model = _model.copyWith(duration: value);
  notifyListeners();
}

  Future<void> publish(BuildContext context) async {
    final description = descriptionController.text.trim();
    final budgetText = budgetController.text.trim();
    final budget = double.tryParse(budgetText);

    if (description.isEmpty) {
     if (budgetText.isEmpty || budget == null || budget <= 0) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Enter a valid budget')),
  );
  return;
}

if (selectedDuration == null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Select duration')),
  );
  return;
}
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something before publishing')),
      );
      return;
    }

    if (await AccountAccessService().isCurrentUserBlocked()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AccountAccessService.blockedActionMessage),
        ),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 👇 نجيب بيانات اليوزر من users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final firstName = userDoc.data()?['firstName'] ?? '';
      final lastName = userDoc.data()?['lastName'] ?? '';

      await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('announcements')
      .add({
       'description': description,
        'budget': budget,
       'duration': selectedDuration,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'userName': '$firstName $lastName', // 👈 اسم صاحب الإعلان
      });

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Publish failed: $e')));
    }
  }

  void cancel(BuildContext context) {
    Navigator.pop(context, false);
  }

  @override
  void dispose() {
    descriptionController.dispose();
    budgetController.dispose();
    super.dispose();
  }
}
