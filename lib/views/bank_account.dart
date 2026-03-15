import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controlles/bank_account_controller.dart';
import '../models/bank_account_model.dart';

class BankAccountView extends StatefulWidget {
  const BankAccountView({super.key});

  @override
  State<BankAccountView> createState() => _BankAccountViewState();
}

class _BankAccountViewState extends State<BankAccountView> {
  final c = BankAccountController();
  final _formKey = GlobalKey<FormState>();

  static const Color kPurple = Color(0xFF4F378B);
  static const Color kSoftBg = Color(0xFFF4F1FA);
  static const Color kBorder = Color(0x66B8A9D9);

  @override
  void initState() {
    super.initState();
    c.init();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fix the highlighted fields")),
      );
      return;
    }

    final saved = await c.saveBankInfo();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(saved ? "Saved ✅" : "Save failed: ${c.error ?? ''}")),
    );

    if (saved) Navigator.pop(context, true); // ✅ يرجّع true للبروفايل للتحديث
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete bank info'),
        content: const Text('Are you sure you want to delete your bank information?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (yes != true) return;

    final deleted = await c.deleteBankInfo();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(deleted ? "Deleted ✅" : "Delete failed: ${c.error ?? ''}")),
    );

    if (deleted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Bank Account'),
            backgroundColor: Colors.white,
            elevation: 0,
            foregroundColor: Colors.black,
          ),
          body: c.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: _Card(
                      borderColor: kBorder,
                      background: kSoftBg,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bank Information',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            const SizedBox(height: 8),

                            // ✅ Summary (masked iban + last4 + expiry)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: kBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "IBAN: ${BankAccountModel.maskIban(c.savedIban)}",
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (c.savedCardLast4 ?? '').isEmpty
                                        ? "Saved card: none"
                                        : "Saved card: **** **** **** ${c.savedCardLast4}",
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (c.savedExpiry ?? '').isEmpty
                                        ? "Expiry: none"
                                        : "Expiry: ${c.savedExpiry}",
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // -------- IBAN --------
                            TextFormField(
                              controller: c.ibanCtrl,
                              validator: c.validateIban,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                                IbanFormatter(),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'IBAN',
                                hintText: 'SA00 0000 0000 0000 0000 0000',
                                border: OutlineInputBorder(),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // -------- Card Number --------
                            TextFormField(
                              controller: c.cardCtrl,
                              validator: c.validateCard,
                              keyboardType: TextInputType.number,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(16),
                                CardNumberFormatter(),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Card Number',
                                hintText: c.hasSavedCard
                                    ? '**** **** **** ${c.savedCardLast4}'
                                    : '1234 1234 1234 1234',
                                helperText: c.hasSavedCard
                                    ? 'Leave empty to keep saved card'
                                    : 'Required',
                                border: const OutlineInputBorder(),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // -------- Expiry --------
                            TextFormField(
                              controller: c.expiryCtrl,
                              validator: c.validateExpiry,
                              keyboardType: TextInputType.number,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                                ExpiryDateFormatter(),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Expiry (MM/YY)',
                                hintText: c.hasSavedExpiry ? c.savedExpiry : '08/28',
                                helperText: c.hasSavedCard
                                    ? 'Leave empty if you did not change card'
                                    : 'Required',
                                border: const OutlineInputBorder(),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // -------- CVC --------
                            // ❌ ما نعرض CVC محفوظ (مافيه)
                            TextFormField(
                              controller: c.cvcCtrl,
                              validator: c.validateCvc,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              decoration: InputDecoration(
                                labelText: 'CVC',
                                hintText: '***',
                                helperText: c.hasSavedCard
                                    ? 'Leave empty if you did not change card'
                                    : 'Required',
                                border: const OutlineInputBorder(),
                              ),
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: kPurple),
                                    onPressed: c.isSaving ? null : _save,
                                    child: c.isSaving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('Save'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: (c.isSaving || !c.hasSavedIban) ? null : _delete,
                                    child: const Text('Delete'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

// ---------- Card wrapper ----------
class _Card extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final Color background;

  const _Card({
    required this.child,
    required this.borderColor,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

// ---------- Formatters ----------

// SA.. groups of 4, max 24 chars (without spaces)
class IbanFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(' ', '').toUpperCase();
    if (text.length > 24) text = text.substring(0, 24);

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i + 1 != text.length) buffer.write(' ');
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// #### #### #### ####
class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(' ', '');
    if (text.length > 16) text = text.substring(0, 16);

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i + 1 != text.length) buffer.write(' ');
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// MMYY -> MM/YY
class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll('/', '');
    if (text.length > 4) text = text.substring(0, 4);

    String formatted = text;
    if (text.length >= 3) {
      formatted = '${text.substring(0, 2)}/${text.substring(2)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}