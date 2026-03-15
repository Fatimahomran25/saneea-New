import 'package:flutter/material.dart';
// السبب: هذا الاستيراد أساسي لاستخدام عناصر واجهة Flutter بنمط Material Design.
// مستخدم هنا لتوفير Widgets وتنسيقات مثل: Scaffold, SafeArea, Center, Column, Row,
// Text, SizedBox, Icon, Icons, Colors, ElevatedButton, ClipRRect, Image,
// ShaderMask, LinearGradient, TextStyle, BorderRadius, BoxConstraints, MediaQuery,
// وكذلك عناصر مثل BoxDecoration و Border و Alignment و Curves.

import '../controlles/signup_controller.dart';
// السبب: هذا الاستيراد مطلوب لاستخدام SignupController داخل الشاشة.
// مستخدم هنا في تعريف: late final SignupController c;
// ومستخدم أيضاً لاستدعاء دوال: submit(), createAccount(), loginTap(...)
// وللوصول إلى خصائص الحالة والتحقق مثل: submitted, isLoading, serverError,
// و TextEditingControllers مثل: nationalIdCtrl, firstNameCtrl, emailCtrl, passwordCtrl, confirmPasswordCtrl.

import '../models/signup_model.dart';
// السبب: هذا الاستيراد مطلوب لاستخدام AccountType.
// مستخدم هنا في: AccountType? selectedType;
// وفي المقارنات: selectedType == AccountType.freelancer / client
// وكذلك في نتيجة التسجيل: final type = await c.createAccount(); ثم التوجيه بناءً على type.

import 'package:flutter/services.dart';
// السبب: هذا الاستيراد مطلوب لاستخدام أدوات تقييد الإدخال وسياسات الطول.
// مستخدم هنا مع TextField في:
// FilteringTextInputFormatter.digitsOnly لمنع إدخال غير الأرقام عند الحقول الرقمية.
// LengthLimitingTextInputFormatter لتطبيق حد أقصى للطول عند وجود maxLength.
// MaxLengthEnforcement.enforced لفرض حد الطول بشكل صريح.

/// شاشة التسجيل (SignupScreen):
/// - واجهة المستخدم (View) لجمع بيانات إنشاء الحساب
/// - تفوّض التحقق وإدارة الحالة والمنطق والتعامل مع Firebase إلى SignupController (Controller)
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

/// حالة الشاشة (_SignupScreenState) تحتوي حالات تخص الواجهة فقط مثل:
/// - FocusNodes لمعرفة الحقل المُركّز عليه وإظهار رسائل التحقق بشكل حي
/// - حالة اختيار نوع الحساب (selectedType)
/// - مفاتيح إظهار/إخفاء كلمة المرور (أيقونة العين)
class _SignupScreenState extends State<SignupScreen> {
  /// الكنترولر المسؤول عن:
  /// - TextEditingControllers
  /// - خصائص التحقق (Validation getters)
  /// - createAccount() لإنشاء الحساب عبر Firebase
  late final SignupController c;

  /// اختيار نوع الحساب محلياً لتحديث شكل الأزرار في الواجهة.
  /// النوع الحقيقي يُحفظ أيضاً داخل model في الكنترولر عبر c.setAccountType()
  AccountType? selectedType;

  /// FocusNodes تُستخدم من أجل:
  /// - معرفة الحقل الذي عليه تركيز حالياً
  /// - إظهار/إخفاء رسائل المساعدة حسب التركيز
  /// - تحديث الواجهة عند تغيّر التركيز
  final _nidFocus = FocusNode();
  final _firstFocus = FocusNode();
  final _lastFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();

  /// مفاتيح إظهار/إخفاء كلمة المرور:
  /// true  => مخفية (obscureText)
  /// false => ظاهرة
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  /// تعيد بناء الواجهة لتحديث:
  /// - رسائل التحقق الحية
  /// - مؤشرات قواعد كلمة المرور
  /// - عناصر تعتمد على التركيز (Focus)
  void _refresh() => setState(() {});

  @override
  void initState() {
    super.initState();

    // تهيئة الكنترولر مرة واحدة طوال عمر الشاشة.
    c = SignupController();

    // عند تغيّر التركيز بين الحقول: نعيد بناء الواجهة فوراً لتحديث رسائل المساعدة.
    _nidFocus.addListener(_refresh);
    _firstFocus.addListener(_refresh);
    _lastFocus.addListener(_refresh);
    _emailFocus.addListener(_refresh);
    _passFocus.addListener(_refresh);
    _confirmFocus.addListener(_refresh);
  }

  @override
  void dispose() {
    // التخلص من FocusNodes لتفادي تسرب الذاكرة.
    _nidFocus.dispose();
    _firstFocus.dispose();
    _lastFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();

    // التخلص من الكنترولر (يشمل TextEditingControllers داخله) لتفادي تسرب الذاكرة.
    c.dispose();
    super.dispose();
  }

  // ===== ثوابت الثيم/التنسيق =====

  /// لون خلفية الشاشة.
  static const _bg = Colors.white;

  /// لون تعبئة حقول الإدخال (شفاف قليلاً حسب التصميم).
  static const _fieldFill = Color(0x5CE8DEF8);

  /// اللون الأساسي للبراند المستخدم لزر الإجراء الأساسي.
  static const _primaryPurple = Color(0xFF4F378B);

  // ===== القياسات (حسب فيقما) =====

  /// ارتفاع الحقول الصغيرة (مثل الاسم الأول/الأخير).
  static const double _smallBoxH = 46;

  /// نصف قطر حاوية حقول الإدخال.
  static const double _radiusField = 5;

  /// نصف قطر زر التسجيل.
  static const double _radiusButton = 10;

  /// قياسات اللوقو وتدويره.
  static const double _logoW = 112;
  static const double _logoH = 128;
  static const double _logoRadius = 33;

  @override
  Widget build(BuildContext context) {
    // عرض الشاشة الحالي لاستخدامه في حساب عرض الفورم بشكل متجاوب.
    final screenW = MediaQuery.of(context).size.width;

    /// متى نعرض قواعد كلمة المرور:
    /// - عند الوقوف على حقل كلمة المرور
    /// - أو عند وجود نص وكلمة المرور ليست قوية
    /// - أو بعد الضغط على Submit وكلمة المرور غير قوية
    final showPasswordRules =
        _passFocus.hasFocus ||
        (c.passwordCtrl.text.isNotEmpty && !c.isPasswordStrong) ||
        (c.submitted && !c.isPasswordStrong);

    /// متى نعرض قاعدة تأكيد كلمة المرور:
    /// - عند الوقوف على حقل التأكيد
    /// - أو عند وجود نص ولا يوجد تطابق
    /// - أو بعد الضغط على Submit والتأكيد غير صحيح
    final showConfirmRules =
        _confirmFocus.hasFocus ||
        (c.confirmPasswordCtrl.text.isNotEmpty && !c.isConfirmPasswordValid) ||
        (c.submitted && !c.isConfirmPasswordValid);

    /// عرض الفورم بشكل متجاوب:
    /// - 88% من عرض الشاشة
    /// - مع حد أدنى 280 وحد أعلى 420 للمحافظة على اتساق التصميم عبر الأجهزة
    final formW = (screenW * 0.88).clamp(280.0, 420.0);

    /// المسافة الأفقية بين حقلي الاسم الأول والاسم الأخير.
    final gap = 12.0;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // ScrollView يمنع Overflow في الشاشات الصغيرة أو عند ظهور لوحة المفاتيح.
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              // تقييد العرض الأقصى يمنع تمدد الواجهة بشكل مبالغ فيه على الأجهزة الكبيرة.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 14),

                  // ===== الشعار =====
                  // قص الصورة بحواف دائرية لتطابق التصميم.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_logoRadius),
                    child: Image.asset(
                      'assets/LOGO.png',
                      width: _logoW,
                      height: _logoH,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // ===== اسم البراند (نص بتدرج) =====
                  // ShaderMask يطبق التدرج على النص ويشترط أن يكون لون النص أبيض ليعمل كقناع.
                  ShaderMask(
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        colors: [
                          Color(0xFF4F378B),
                          Color(0xFF8F3F78),
                          Color(0xFF5A3888),
                          Color(0xFFA24272),
                        ],
                      ).createShader(bounds);
                    },
                    child: const Text(
                      'Saneea',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'DMSerifDisplay',
                        fontSize: 36,
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                        letterSpacing: 0,
                        // مطلوب لأن ShaderMask يستخدم لون النص كقناع.
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ===== رسائل خطأ عامة للفورم =====
                  // تظهر بعد الضغط على Submit إذا كان هناك حقول مطلوبة غير مكتملة/غير صحيحة.
                  if (c.submitted && !c.allRequiredValid)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Please complete all required fields.',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // تظهر رسالة خطأ قادمة من السيرفر (مثل الإيميل مستخدم أو رقم الهوية مكرر).
                  if (c.serverError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        c.serverError!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // ===== اختيار نوع الحساب =====
                  // زرين: Freelancer / Client
                  // يظهر إطار أحمر إذا تم الضغط على Submit بدون اختيار نوع الحساب.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AccountTypeButton(
                        text: 'Freelancer',
                        icon: Icons.person_outline,
                        isSelected: selectedType == AccountType.freelancer,
                        showErrorBorder:
                            c.submitted && !c.isAccountTypeSelected,
                        onTap: () {
                          // تحديث الاختيار محلياً لتغيير شكل الزر.
                          setState(() => selectedType = AccountType.freelancer);
                          // حفظ النوع داخل الكنترولر لاستخدامه أثناء إنشاء الحساب وبعده.
                          c.setAccountType(AccountType.freelancer);
                        },
                      ),
                      const SizedBox(width: 12),
                      _AccountTypeButton(
                        text: 'Client',
                        icon: Icons.groups_outlined,
                        isSelected: selectedType == AccountType.client,
                        showErrorBorder:
                            c.submitted && !c.isAccountTypeSelected,
                        onTap: () {
                          // تحديث الاختيار محلياً لتغيير شكل الزر.
                          setState(() => selectedType = AccountType.client);
                          // حفظ النوع داخل الكنترولر لاستخدامه أثناء إنشاء الحساب وبعده.
                          c.setAccountType(AccountType.client);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ===== حقل رقم الهوية/الإقامة =====
                  // أرقام فقط + حد أقصى 10.
                  _LabeledField(
                    label: 'National ID / Iqama',
                    width: formW,
                    maxLength: 10,
                    showError: c.submitted && !c.isNationalIdValid,
                    focusNode: _nidFocus,
                    onChanged: _refresh,
                    boxHeight: 46,
                    controller: c.nationalIdCtrl,
                    fillColor: _fieldFill,
                    radius: _radiusField,
                    keyboardType: TextInputType.number,
                    // رسالة تحقق تظهر تحت الحقل بعد مغادرة الحقل إذا كانت القيمة غير صحيحة.
                    liveMessage:
                        (!_nidFocus.hasFocus &&
                            c.nationalIdCtrl.text.isNotEmpty &&
                            !c.isNationalIdValid)
                        ? 'Must be 10 digits and start with 1 (ID) or 2 (Iqama).'
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // ===== حقول الاسم (الأول + الأخير) =====
                  SizedBox(
                    width: formW,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'First name',
                            width: double.infinity,
                            showError: c.submitted && !c.isFirstNameValid,
                            focusNode: _firstFocus,
                            onChanged: _refresh,
                            boxHeight: _smallBoxH,
                            controller: c.firstNameCtrl,
                            fillColor: _fieldFill,
                            radius: _radiusField,
                            // رسالة تحقق تظهر تحت الحقل بعد مغادرة الحقل إذا كانت القيمة غير صحيحة.
                            liveMessage:
                                (!_firstFocus.hasFocus &&
                                    c.firstNameCtrl.text.isNotEmpty &&
                                    !c.isFirstNameValid)
                                ? 'Only letters, max 15 characters.'
                                : null,
                          ),
                        ),
                        // مسافة ثابتة بين الحقلين حسب التصميم.
                        SizedBox(width: gap),
                        Expanded(
                          child: _LabeledField(
                            label: 'Last name',
                            width: double.infinity,
                            boxHeight: _smallBoxH,
                            showError: c.submitted && !c.isLastNameValid,
                            focusNode: _lastFocus,
                            onChanged: _refresh,
                            controller: c.lastNameCtrl,
                            fillColor: _fieldFill,
                            radius: _radiusField,
                            // رسالة تحقق تظهر تحت الحقل بعد مغادرة الحقل إذا كانت القيمة غير صحيحة.
                            liveMessage:
                                (!_lastFocus.hasFocus &&
                                    c.lastNameCtrl.text.isNotEmpty &&
                                    !c.isLastNameValid)
                                ? 'Only letters, max 15 characters.'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ===== حقل البريد الإلكتروني =====
                  // يستخدم لوحة مفاتيح الإيميل والتحقق يتم في الكنترولر.
                  _LabeledField(
                    label: 'Email address',
                    width: formW,
                    showError: c.submitted && !c.isEmailValid,
                    hintText: 'e.g. name@gmail.com',
                    focusNode: _emailFocus,
                    onChanged: _refresh,
                    boxHeight: 46,
                    controller: c.emailCtrl,
                    fillColor: _fieldFill,
                    radius: _radiusField,
                    keyboardType: TextInputType.emailAddress,
                    // رسالة تحقق تظهر تحت الحقل بعد مغادرة الحقل إذا كان الإيميل غير صحيح.
                    liveMessage:
                        (!_emailFocus.hasFocus &&
                            c.emailCtrl.text.isNotEmpty &&
                            !c.isEmailValid)
                        ? 'Please enter a valid Gmail address.'
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // ===== حقل كلمة المرور =====
                  // زر العين يبدل بين الإخفاء/الإظهار.
                  _LabeledField(
                    label: 'Password',
                    width: formW,
                    showError: c.submitted && !c.isPasswordValid,
                    focusNode: _passFocus,
                    onChanged: _refresh,
                    boxHeight: 46,
                    controller: c.passwordCtrl,
                    fillColor: _fieldFill,
                    radius: _radiusField,
                    obscureText: _obscurePass,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass ? Icons.visibility_off : Icons.visibility,
                        color: _primaryPurple,
                      ),
                      // تغيير حالة إخفاء/إظهار كلمة المرور فقط على مستوى الواجهة.
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),

                  // مؤشرات قواعد كلمة المرور (عرض فقط لشرح القواعد للمستخدم).
                  if (showPasswordRules) ...[
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PasswordRule(
                          text: "At least 8 letters",
                          isValid: c.hasAtLeast8Letters,
                          // تفعيل المؤشر عند وجود نص داخل حقل كلمة المرور.
                          isActive: c.passwordCtrl.text.isNotEmpty,
                        ),
                        _PasswordRule(
                          text: "At least one uppercase character",
                          isValid: c.hasUppercase,
                          isActive: c.passwordCtrl.text.isNotEmpty,
                        ),
                        _PasswordRule(
                          text: "At least one lowercase character",
                          isValid: c.hasLowercase,
                          isActive: c.passwordCtrl.text.isNotEmpty,
                        ),
                        _PasswordRule(
                          text: "At least one numeric character",
                          isValid: c.hasNumber,
                          isActive: c.passwordCtrl.text.isNotEmpty,
                        ),
                        _PasswordRule(
                          text: "At least one special character",
                          isValid: c.hasSpecialChar,
                          isActive: c.passwordCtrl.text.isNotEmpty,
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ===== حقل تأكيد كلمة المرور =====
                  // زر العين يبدل بين الإخفاء/الإظهار.
                  _LabeledField(
                    label: 'Confirm password',
                    width: formW,
                    showError: c.submitted && !c.isConfirmPasswordValid,
                    focusNode: _confirmFocus,
                    onChanged: _refresh,
                    boxHeight: 46,
                    controller: c.confirmPasswordCtrl,
                    fillColor: _fieldFill,
                    radius: _radiusField,
                    obscureText: _obscureConfirm,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: _primaryPurple,
                      ),
                      // تغيير حالة إخفاء/إظهار تأكيد كلمة المرور فقط على مستوى الواجهة.
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    // رسالة تحقق تظهر تحت الحقل بعد مغادرته إذا كان التأكيد لا يطابق كلمة المرور.
                    liveMessage:
                        (!_confirmFocus.hasFocus &&
                            c.confirmPasswordCtrl.text.isNotEmpty &&
                            !c.isConfirmPasswordValid)
                        ? 'Passwords do not match.'
                        : null,
                  ),

                  // مؤشر تطابق كلمة المرور (عرض فقط).
                  if (showConfirmRules) ...[
                    const SizedBox(height: 8),
                    _PasswordRule(
                      text: "Matches password",
                      isValid: c.isConfirmPasswordValid,
                      isActive: c.confirmPasswordCtrl.text.isNotEmpty,
                    ),
                  ],

                  const SizedBox(height: 22),

                  // ===== زر إنشاء الحساب =====
                  // ينفذ: submit() لإظهار أخطاء التحقق ثم createAccount() للتسجيل عبر Firebase.
                  SizedBox(
                    width: formW,
                    height: 46,
                    child: ElevatedButton(
                      // يتم تعطيل الزر أثناء التحميل لمنع تكرار الطلبات.
                      onPressed: c.isLoading
                          ? null
                          : () async {
                              // تغيير حالة submitted لعرض رسائل/حدود التحقق على الحقول.
                              setState(c.submit);

                              // محاولة إنشاء الحساب. تعيد AccountType عند النجاح أو null عند الفشل.
                              final type = await c.createAccount();

                              // إعادة بناء الواجهة لإظهار رسالة serverError عند حدوث خطأ.
                              setState(() {});

                              // التحقق أن الشاشة لا تزال موجودة بعد await قبل تنفيذ التنقل.
                              if (!context.mounted) return;

                              // عدم التنقل إذا فشل إنشاء الحساب.
                              if (type == null) return;

                              // توجيه المستخدم حسب نوع الحساب الذي تم إنشاؤه.
                              Navigator.pushReplacementNamed(
                                context,
                                type == AccountType.freelancer
                                    ? '/freelancerHome'
                                    : '/clientHome',
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_radiusButton),
                        ),
                        elevation: 6,
                      ),
                      child: c.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ===== رابط تسجيل الدخول =====
                  // جعل كلمة "Log in" فقط قابلة للنقر.
                  SizedBox(
                    width: formW,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Text(
                            "Have an account already? ",
                            style: TextStyle(fontSize: 14, color: Colors.black),
                          ),
                          GestureDetector(
                            // استدعاء دالة الانتقال إلى شاشة تسجيل الدخول من الكنترولر.
                            onTap: () => c.loginTap(context),
                            child: const Text(
                              "Log in",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF467FFF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// _LabeledField:
/// ويدجت قابلة لإعادة الاستخدام لعرض:
/// - عنوان الحقل
/// - TextField بتنسيق موحد
/// - liveMessage اختيارية تحت الحقل مع حركة AnimatedSize
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.width,
    required this.boxHeight,
    required this.controller,
    required this.fillColor,
    required this.radius,
    this.keyboardType,
    required this.showError,
    this.obscureText = false,
    required this.focusNode,
    this.hintText,
    this.liveMessage,
    this.onChanged,
    this.maxLength,
    this.suffixIcon,
  });

  final String label;
  final double width;
  final double boxHeight;
  final TextEditingController controller;
  final Color fillColor;
  final double radius;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool showError;

  final FocusNode focusNode;
  final String? hintText;
  final String? liveMessage;
  final VoidCallback? onChanged;
  final int? maxLength;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // نص عنوان الحقل (Label) المعروض فوق مربع الإدخال.
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF000000),
            ),
          ),
          const SizedBox(height: 8),

          // حاوية TextField (لون تعبئة + حواف + إطار خطأ عند الحاجة).
          SizedBox(
            height: boxHeight,
            child: Container(
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  // يظهر إطار أحمر إذا كان showError = true.
                  color: showError ? Colors.red : Colors.transparent,
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              child: TextField(
                // ربط FocusNode لتحديد متى يدخل/يخرج المستخدم من الحقل.
                focusNode: focusNode,
                // ربط الكنترولر لإدارة نص الحقل.
                controller: controller,
                // عند تغيير النص: نستدعي onChanged لتحديث الواجهة خارج هذا الويدجت.
                onChanged: (_) => onChanged?.call(),
                keyboardType: keyboardType,
                obscureText: obscureText,

                // تقييد الإدخال:
                // - digitsOnly عند استخدام لوحة مفاتيح رقمية
                // - طول أقصى عند تحديد maxLength
                inputFormatters: [
                  if (keyboardType == TextInputType.number)
                    FilteringTextInputFormatter.digitsOnly,
                  if (maxLength != null)
                    LengthLimitingTextInputFormatter(maxLength!),
                ],

                // تطبيق حد الطول (إن وجد) بشكل صريح.
                maxLength: maxLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,

                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(
                    color: Color(0xFFBDBDBD),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  // إخفاء عداد maxLength الافتراضي أسفل الحقل.
                  counterText: '',
                  // أيقونة اختيارية (مثل زر العين لكلمة المرور).
                  suffixIcon: suffixIcon,
                ),
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
          ),

          // رسالة تحقق/مساعدة تظهر تحت الحقل عند توفر liveMessage.
          // AnimatedSize يجعل ظهور/اختفاء الرسالة بحركة ناعمة بدون قفزة في التصميم.
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            child: liveMessage == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      liveMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// _AccountTypeButton:
/// ويدجت قابلة لإعادة الاستخدام لاختيار نوع الحساب.
/// تعرض:
/// - أيقونة + نص
/// - إطار يوضح حالة الاختيار
/// - إطار أحمر عند الإرسال بدون اختيار
class _AccountTypeButton extends StatelessWidget {
  const _AccountTypeButton({
    required this.text,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.showErrorBorder,
  });

  final String text;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showErrorBorder;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // تمرير حدث النقر إلى onTap القادم من الشاشة الرئيسية.
      onTap: onTap,
      child: Container(
        // حجم ثابت حسب التصميم.
        width: 136,
        height: 142,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(60),
          border: Border.all(
            // إطار أحمر إذا تم الإرسال بدون اختيار، وإلا لون حسب حالة الاختيار.
            color: showErrorBorder
                ? Colors.red
                : (isSelected
                      ? const Color(0xFF4F378B)
                      : const Color(0xFFB8A9D9)),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // أيقونة نوع الحساب.
            Icon(icon, size: 65, color: const Color(0xFF4F378B)),
            const SizedBox(height: 12),
            // نص نوع الحساب.
            Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4F378B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// _PasswordRule:
/// مؤشر بصري لقواعد كلمة المرور.
/// يغير اللون حسب:
/// - رمادي: لم يبدأ المستخدم بالكتابة
/// - أخضر: القاعدة متحققة
/// - أحمر: القاعدة غير متحققة
class _PasswordRule extends StatelessWidget {
  const _PasswordRule({
    required this.text,
    required this.isValid,
    required this.isActive,
  });

  final String text;
  final bool isValid;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    // تحديد لون المؤشر والنص بناءً على حالة التفعيل وصحة القاعدة.
    Color color;

    if (!isActive) {
      // قبل البدء بالكتابة: حالة محايدة.
      color = Colors.grey;
    } else {
      // بعد البدء بالكتابة: أخضر إذا القاعدة صحيحة وإلا أحمر.
      color = isValid ? Colors.green : Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          // نقطة صغيرة كمؤشر لحالة القاعدة.
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 6),
          // نص القاعدة بنفس لون المؤشر.
          Text(text, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
