import 'package:flutter/material.dart';
// السبب: هذا الاستيراد ضروري لاستخدام عناصر Flutter الأساسية داخل الكنترولر مثل:
// TextEditingController لإدارة نصوص الحقول، وكذلك BuildContext و Navigator في loginTap().

import 'package:firebase_auth/firebase_auth.dart';
// السبب: هذا الاستيراد ضروري لإنشاء الحساب وتسجيل المستخدم عبر Firebase Authentication.
// مستخدم هنا في: FirebaseAuth.instance.createUserWithEmailAndPassword(...)
// وكذلك للتعامل مع الاستثناءات: FirebaseAuthException.

import 'package:cloud_firestore/cloud_firestore.dart';
// السبب: هذا الاستيراد ضروري للتعامل مع قاعدة البيانات Firestore.
// مستخدم هنا في: FirebaseFirestore.instance.collection(...).where(...).get()
// وأيضاً في: .doc(uid).set({...})
// وكذلك FieldValue.serverTimestamp() لتسجيل وقت الإنشاء من السيرفر.
// وأيضاً للتعامل مع الاستثناءات: FirebaseException.

import '../models/signup_model.dart';
// السبب: هذا الاستيراد ضروري لاستخدام SignupModel و AccountType.
// مستخدم هنا في: final SignupModel model = SignupModel();
// ومستخدم في: setAccountType(AccountType type) وفي إرجاع AccountType من createAccount().

import 'dart:async';
// السبب: هذا الاستيراد ضروري لاستخدام TimeoutException و Duration.
// مستخدم هنا مع: .timeout(const Duration(seconds: 8))
// وكذلك في: on TimeoutException catch (_) { ... }.

/// SignupController يعمل كـ "Controller" لشاشة التسجيل:
/// - يحتفظ بـ TextEditingControllers لكل حقول الإدخال
/// - يوفر خصائص تحقق (Validation getters) تستخدمها الواجهة
/// - يحتفظ بحالة بسيطة للواجهة (submitted, serverError, isLoading)
/// - ينفذ إنشاء الحساب عبر FirebaseAuth و Firestore
class SignupController {
  /// موديل لتخزين البيانات غير النصية مثل نوع الحساب المختار (AccountType).
  final SignupModel model = SignupModel();

  /// متحكمات النص الخاصة بحقول الإدخال في الواجهة لقراءة النص والتحكم به.
  final nationalIdCtrl = TextEditingController();
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  // ===== حالة الواجهة =====

  /// يوضح هل المستخدم حاول إرسال الفورم أم لا.
  /// تستخدمه الواجهة لإظهار حدود/رسائل التحقق عند الإرسال.
  bool submitted = false;

  /// رسالة خطأ قادمة من Firebase/Auth/Firestore لعرضها في الواجهة عند الفشل.
  /// مثال: الإيميل مستخدم أو رقم الهوية مكرر.
  String? serverError;

  /// حالة تحميل لمنع الضغط المتكرر على زر إنشاء الحساب أثناء تنفيذ الطلب.
  bool isLoading = false;

  // ===== دوال مساعدة =====

  /// دالة مساعدة للتحقق من الاسم: تقبل أحرف إنجليزية فقط (A-Z / a-z).
  /// ملاحظة: هذا يعني أن إدخال أحرف عربية سيُعتبر غير صالح وفق هذا الشرط.
  bool _isOnlyLetters(String v) => RegExp(r'^[a-zA-Z]+$').hasMatch(v);

  // ===== التحقق (Validation) =====

  /// يتحقق أن المستخدم اختار نوع الحساب (Freelancer أو Client).
  /// النوع محفوظ داخل model وليس داخل TextField.
  bool get isAccountTypeSelected => model.accountType != null;

  /// يتحقق من رقم الهوية/الإقامة:
  /// - الطول 10 أرقام
  /// - يبدأ بـ 1 (هوية) أو 2 (إقامة)
  /// ملاحظة: هذا تحقق مبدئي، ولا يتحقق من صحة الرقم حسابياً.
  bool get isNationalIdValid {
    final v = nationalIdCtrl.text.trim();
    if (v.length != 10) return false;
    return v.startsWith('1') || v.startsWith('2');
  }

  /// يتحقق من الاسم الأول:
  /// - غير فارغ
  /// - لا يتجاوز 15 حرف
  /// - أحرف إنجليزية فقط حسب _isOnlyLetters
  bool get isFirstNameValid {
    final v = firstNameCtrl.text.trim();
    if (v.isEmpty) return false;
    if (v.length > 15) return false;
    return _isOnlyLetters(v);
  }

  /// يتحقق من الاسم الأخير:
  /// - غير فارغ
  /// - لا يتجاوز 15 حرف
  /// - أحرف إنجليزية فقط حسب _isOnlyLetters
  bool get isLastNameValid {
    final v = lastNameCtrl.text.trim();
    if (v.isEmpty) return false;
    if (v.length > 15) return false;
    return _isOnlyLetters(v);
  }

  /// يتحقق من البريد الإلكتروني بصيغة Gmail فقط (شرط خاص بالتطبيق).
  /// ملاحظة: هذا شرط تجاري/واجهة وليس شرطاً من Firebase.
  bool get isEmailValid {
    final v = emailCtrl.text.trim();
    if (v.isEmpty) return false;
    final gmailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$');
    return gmailRegex.hasMatch(v);
  }

  /// قاعدة كلمة المرور: يحتوي على رمز خاص واحد على الأقل.
  bool get hasSpecialChar =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-]').hasMatch(passwordCtrl.text);

  /// قاعدة كلمة المرور: يحتوي على رقم واحد على الأقل.
  bool get hasNumber => RegExp(r'\d').hasMatch(passwordCtrl.text);

  /// قاعدة كلمة المرور: يحتوي على حرف كبير واحد على الأقل (A-Z).
  bool get hasUppercase => RegExp(r'[A-Z]').hasMatch(passwordCtrl.text);

  /// قاعدة كلمة المرور: يحتوي على حرف صغير واحد على الأقل (a-z).
  bool get hasLowercase => RegExp(r'[a-z]').hasMatch(passwordCtrl.text);

  /// قاعدة كلمة المرور: يحتوي على 8 أحرف إنجليزية على الأقل (A-Z / a-z) داخل كلمة المرور.
  /// ملاحظة: هذا يتحقق من عدد الأحرف فقط، وليس طول النص الكامل (قد يشمل رموز/أرقام).
  bool get hasAtLeast8Letters =>
      RegExp(r'[A-Za-z]').allMatches(passwordCtrl.text).length >= 8;

  /// صلاحية كلمة المرور بناءً على القواعد5  المعرفة أعلاه.
  bool get isPasswordValid =>
      hasAtLeast8Letters &&
      hasUppercase &&
      hasLowercase &&
      hasNumber &&
      hasSpecialChar;

  /// قوة كلمة المرور (نفس شروط isPasswordValid هنا).
  bool get isPasswordStrong =>
      hasAtLeast8Letters &&
      hasUppercase &&
      hasLowercase &&
      hasNumber &&
      hasSpecialChar;

  /// تحقق تأكيد كلمة المرور:
  /// - غير فارغ
  /// - يطابق كلمة المرور الأصلية
  bool get isConfirmPasswordValid =>
      confirmPasswordCtrl.text.isNotEmpty &&
      confirmPasswordCtrl.text == passwordCtrl.text;

  /// تحقق مجمع لكل الحقول المطلوبة قبل محاولة إنشاء الحساب.
  /// إذا كان false: يجب على الواجهة إيقاف الإرسال وإظهار الأخطاء.
  bool get allRequiredValid =>
      isAccountTypeSelected &&
      isNationalIdValid &&
      isFirstNameValid &&
      isLastNameValid &&
      isEmailValid &&
      isPasswordValid &&
      isConfirmPasswordValid;

  // ===== إجراءات (Actions) =====

  /// حفظ نوع الحساب المختار داخل الموديل.
  /// تُستدعى عند ضغط المستخدم على زر Freelancer أو Client في الواجهة.
  void setAccountType(AccountType type) {
    model.accountType = type;
  }

  /// تعليم أن المستخدم حاول إرسال الفورم حتى تبدأ الواجهة بإظهار أخطاء التحقق.
  void submit() {
    submitted = true;
  }

  /// التخلص من جميع TextEditingControllers لتفادي تسرب الذاكرة.
  /// يجب استدعاؤها من dispose() في الشاشة.
  void dispose() {
    nationalIdCtrl.dispose();
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
  }

  /// إنشاء حساب جديد:
  /// 1) يمنع التنفيذ إذا كان هناك طلب جارٍ (isLoading)
  /// 2) يتحقق من allRequiredValid (تحقق على الجهاز)
  /// 3) يتحقق من تكرار رقم الهوية في Firestore (شرط تجاري)
  /// 4) ينشئ مستخدم في FirebaseAuth باستخدام email/password
  /// 5) يحفظ بيانات المستخدم في Firestore باستخدام uid كمعرف للوثيقة
  ///
  /// يعيد:
  /// - AccountType عند النجاح (لتستخدمه الواجهة في التوجيه للصفحة المناسبة)
  /// - null عند الفشل مع ضبط serverError لعرض السبب
  Future<AccountType?> createAccount() async {
    if (isLoading) return null;

    // تفعيل حالة التحميل وإزالة أي خطأ سابق قبل بدء العملية.
    isLoading = true;
    serverError = null;

    try {
      // إيقاف العملية إذا كان التحقق المجمع غير مكتمل.
      if (!allRequiredValid) return null;

      // قراءة القيم بعد تنظيف المسافات.
      final nationalId = nationalIdCtrl.text.trim();
      final firstName = firstNameCtrl.text.trim();
      final lastName = lastNameCtrl.text.trim();
      final email = emailCtrl.text.trim();
      final password = passwordCtrl.text;
      final accountType = model.accountType!;

      // التحقق من وجود نفس nationalId مسبقاً في مجموعة users.
      // timeout لتفادي الانتظار الطويل إذا الاتصال ضعيف.
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('nationalId', isEqualTo: nationalId)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8));

      if (existing.docs.isNotEmpty) {
        // منع إنشاء حساب جديد إذا كان رقم الهوية موجود مسبقاً.
        serverError = "National ID / Iqama already exists.";
        return null;
      }

      // إنشاء المستخدم في Firebase Authentication.
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 8));

      // الحصول على uid للمستخدم الجديد لاستخدامه كمعرف وثيقة في Firestore.
      final uid = credential.user!.uid;

      // حفظ بيانات الملف الشخصي في Firestore.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
            'accountType': accountType.name,
            'nationalId': nationalId,
            'firstName': firstName,
            'lastName': lastName,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 8));

      // إعادة نوع الحساب لتمكين الواجهة من التوجيه للصفحة المناسبة.
      return accountType;
    } on FirebaseAuthException catch (e) {
      // أخطاء المصادقة/إنشاء الحساب في FirebaseAuth.
      if (e.code == 'network-request-failed') {
        serverError = "No internet connection.";
      } else if (e.code == 'email-already-in-use') {
        serverError = "Email already exists. Try a different email.";
      } else {
        serverError = e.message ?? "Auth error.";
      }
      return null;
    } on FirebaseException catch (e) {
      // أخطاء Firestore مثل عدم التوفر أو تأخير الاستجابة.
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        serverError = "No internet connection. Please try again.";
      } else {
        serverError = "Database error. Try again.";
      }
      return null;
    } on TimeoutException {
      // timeout من .timeout(...) عند بطء/انقطاع الشبكة.
      serverError = "Connection timed out. Check your internet.";
      return null;
    } catch (_) {
      // أي أخطاء غير متوقعة.
      serverError = "Something went wrong. Try again.";
      return null;
    } finally {
      // إيقاف حالة التحميل دائماً سواء نجحت العملية أو فشلت.
      isLoading = false;
    }
  }

  /// الانتقال إلى صفحة تسجيل الدخول.
  /// تُستدعى عند الضغط على رابط "Log in" في شاشة التسجيل.
  void loginTap(BuildContext context) {
    Navigator.pushNamed(context, '/login');
  }
}