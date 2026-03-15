import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your email')));
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: ActionCodeSettings(
          url:
              'https://freelance-app-be58f.page.link/reset', // راح نسويه بالحساب
          handleCodeInApp: true,
          androidPackageName: 'com.example.saneea_app',
          androidInstallApp: true,
          androidMinimumVersion: '21',
          // حطي iosBundleId لو تبين iOS لاحقًا
        ),
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset link sent ✅ Check your email')),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? 'Something went wrong';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendResetEmail,
                child: Text(_loading ? 'Sending...' : 'Send reset link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===============================================================
/// ResetPasswordScreen (داخل التطبيق) + شروط كلمة المرور
/// ===============================================================
class ResetPasswordScreen extends StatefulWidget {
  final String oobCode; // يجي من dynamic link
  const ResetPasswordScreen({super.key, required this.oobCode});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  // شروطك
  bool get _lenOK => _newPassCtrl.text.length >= 8;
  bool get _upperOK => RegExp(r'[A-Z]').hasMatch(_newPassCtrl.text);
  bool get _lowerOK => RegExp(r'[a-z]').hasMatch(_newPassCtrl.text);
  bool get _numberOK => RegExp(r'\d').hasMatch(_newPassCtrl.text);
  bool get _specialOK => RegExp(
    r'[!@#$%^&*(),.?":{}|<>_\-\\/\[\]=+;`~]',
  ).hasMatch(_newPassCtrl.text);

  bool get _confirmOK =>
      _confirmCtrl.text.isNotEmpty && _confirmCtrl.text == _newPassCtrl.text;

  bool get _allOK =>
      _lenOK && _upperOK && _lowerOK && _numberOK && _specialOK && _confirmOK;

  @override
  void initState() {
    super.initState();
    _newPassCtrl.addListener(() => setState(() {}));
    _confirmCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNewPassword() async {
    if (!_allOK) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please meet all password requirements')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // هذا اللي يغيّر كلمة المرور فعلياً على Firebase
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: _newPassCtrl.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated ✅ You can login now')),
      );

      // رجّعيه للّوقن مثلاً
      Navigator.popUntil(context, (r) => r.isFirst);
      // أو لو عندك route login:
      // Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? 'Something went wrong';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _rule(String text, bool ok) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          size: 18,
          color: ok ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: ok ? Colors.green : Colors.red,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _newPassCtrl,
              obscureText: _obscure1,
              decoration: InputDecoration(
                labelText: 'New password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure1 = !_obscure1),
                  icon: Icon(
                    _obscure1 ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Checklist
            _rule('At least 8 characters', _lenOK),
            const SizedBox(height: 6),
            _rule('At least one uppercase character', _upperOK),
            const SizedBox(height: 6),
            _rule('At least one lowercase character', _lowerOK),
            const SizedBox(height: 6),
            _rule('At least one numeric character', _numberOK),
            const SizedBox(height: 6),
            _rule('At least one special character', _specialOK),

            const SizedBox(height: 16),

            TextField(
              controller: _confirmCtrl,
              obscureText: _obscure2,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure2 = !_obscure2),
                  icon: Icon(
                    _obscure2 ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
                errorText: _confirmCtrl.text.isEmpty
                    ? null
                    : (_confirmOK ? null : 'Passwords do not match'),
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : (_allOK ? _saveNewPassword : null),
                child: Text(_loading ? 'Saving...' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
