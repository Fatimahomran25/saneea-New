import 'package:cloud_firestore/cloud_firestore.dart';

class BankAccountModel {
  final String? iban;        // full stored in DB
  final String? cardLast4;   // only last 4 stored
  final String? cardExpiry;  // MM/YY stored
  final DateTime? updatedAt;

  const BankAccountModel({
    required this.iban,
    required this.cardLast4,
    required this.cardExpiry,
    required this.updatedAt,
  });

  static String cleanIban(String s) => s.replaceAll(' ', '').toUpperCase();

  static String maskIban(String? iban) {
    final s = cleanIban(iban ?? '');
    if (s.isEmpty) return 'No bank account added';
    final head = s.length >= 4 ? s.substring(0, 4) : s;
    return '$head •••• •••• •••• •••• ••••';
  }

  factory BankAccountModel.fromUserDoc(Map<String, dynamic>? data) {
    final d = data ?? {};

    final iban = (d['iban'] ?? '').toString().trim();
    final cardLast4 = (d['cardLast4'] ?? '').toString().trim();
    final cardExpiry = (d['cardExpiry'] ?? '').toString().trim();

    final ts = d['bankUpdatedAt'];
    DateTime? updatedAt;
    if (ts is Timestamp) updatedAt = ts.toDate();

    return BankAccountModel(
      iban: iban.isEmpty ? null : iban,
      cardLast4: cardLast4.isEmpty ? null : cardLast4,
      cardExpiry: cardExpiry.isEmpty ? null : cardExpiry,
      updatedAt: updatedAt,
    );
  }
}