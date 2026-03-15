import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controlles/freelancer_profile_controller.dart';
import '../models/freelancer_profile_model.dart';

class FreelancerProfileView extends StatefulWidget {
  const FreelancerProfileView({super.key});

  @override
  State<FreelancerProfileView> createState() => _FreelancerProfileViewState();
}

class _FreelancerProfileViewState extends State<FreelancerProfileView> {
  final c = FreelancerProfileController();
  final _formKey = GlobalKey<FormState>();

  static const Color kPurple = Color.fromRGBO(79, 55, 139, 1);
  static const Color kHeaderBg = Color(0xFFF2EAFB);
  static const Color kCardBg = Color(0xFFF4F1FA);
  static const Color kSoftBorder = Color(0x66B8A9D9);

  String _maskIban(String? iban) {
    final s = (iban ?? '').replaceAll(' ', '').toUpperCase();
    if (s.isEmpty) return "No bank account added";
    final head = s.length >= 4 ? s.substring(0, 4) : s;
    return '$head •••• •••• •••• •••• ••••';
  }

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

  Future<void> _pickProfileImage() async {
    if (!c.isEditing) return;

    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (x == null) return;
      c.setPickedImage(File(x.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pick failed: $e')));
    }
  }

  Future<void> _pickPortfolioImages() async {
    if (!c.isEditing) return;
    final xs = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (xs.isEmpty) return;
    c.addPortfolioFiles(xs.map((e) => File(e.path)).toList());
  }

  Future<ExperienceModel?> _experienceDialog({ExperienceModel? initial}) async {
    final fieldCtrl = TextEditingController(text: initial?.field ?? '');
    final orgCtrl = TextEditingController(text: initial?.org ?? '');
    final periodCtrl = TextEditingController(text: initial?.period ?? '');
    final formKey = GlobalKey<FormState>();

    final res = await showDialog<ExperienceModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(initial == null ? "Add Experience" : "Edit Experience"),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: fieldCtrl,
                  decoration: const InputDecoration(
                    labelText: "Field",
                    hintText: "e.g. Graphic Design",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? "Field is required"
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: orgCtrl,
                  decoration: const InputDecoration(
                    labelText: "Organization",
                    hintText: "e.g. King Saud University",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? "Organization is required"
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: periodCtrl,
                  decoration: const InputDecoration(
                    labelText: "Period",
                    hintText: "e.g. Sep 2021 - Jun 2023",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? "Period is required"
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                ctx,
                ExperienceModel(
                  field: fieldCtrl.text.trim(),
                  org: orgCtrl.text.trim(),
                  period: periodCtrl.text.trim(),
                ),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );

    return res;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final fixedMq = mq.copyWith(textScaler: const TextScaler.linear(1.0));

    return MediaQuery(
      data: fixedMq,
      child: AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: const BackButton(color: Colors.black),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: IconButton(
                    tooltip: "Log out",
                    onPressed: () => c.logout(context),
                    icon: const Icon(Icons.logout, color: Colors.red, size: 28),
                  ),
                ),
              ],
            ),
            body: c.isLoading
                ? const Center(child: CircularProgressIndicator())
                : (c.profile == null)
                ? Center(child: Text(c.error ?? "Failed to load profile"))
                : Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        const SizedBox(height: 10),

                        // ✅ Header نفس ستايلك + الاسم حقلين
                        _HeaderLikeAdmin_NoJobTitle(
                          purple: kPurple,
                          headerBg: kHeaderBg,
                          isEditing: c.isEditing,
                          profile: c.profile!,
                          pickedImageFile: c.pickedImageFile,
                          onPickImage: _pickProfileImage,
                          firstNameCtrl: c.firstNameCtrl,
                          lastNameCtrl: c.lastNameCtrl,
                          onEditTap: c.isEditing ? null : c.startEdit,
                          firstNameValidator: c.validateFirstName,
                          lastNameValidator: c.validateLastName,
                        ),

                        const SizedBox(height: 14),

                        // ✅ الكارد الطويل
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                            decoration: BoxDecoration(
                              color: kCardBg,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: kSoftBorder,
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _EditableField(
                                  label: "Bio",
                                  enabled: c.isEditing,
                                  controller: c.bioCtrl,
                                  maxLength: FreelancerProfileController.bioMax,
                                  maxLines: 4,
                                  validator: c.validateBio,
                                  counterText:
                                      "${c.bioLen.clamp(0, FreelancerProfileController.bioMax)}/${FreelancerProfileController.bioMax}",
                                  hintText: "Write your bio...",
                                  purple: kPurple,
                                ),

                                const SizedBox(height: 18),

                                _ReadOnlyBlock(
                                  title: "National ID / Iqama",
                                  value: c.profile!.nationalId,
                                  purple: kPurple,
                                ),

                                const SizedBox(height: 18),

                                _EditableField(
                                  label: "Email Address",
                                  enabled: c.isEditing,
                                  controller: c.emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: c.validateGmail,
                                  hintText: "name@gmail.com",
                                  purple: kPurple,
                                ),

                                const SizedBox(height: 14),

                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "IBAN",
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: kPurple.withOpacity(
                                                  0.25,
                                                ),
                                                width: 1.2,
                                              ),
                                            ),
                                            child: Text(
                                              c.isEditing
                                                  ? c.ibanCtrl.text.isEmpty
                                                        ? "No bank account added"
                                                        : c.ibanCtrl.text
                                                  : _maskIban(c.profile!.iban),
                                              style: TextStyle(
                                                color: Colors.grey.shade800,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      tooltip: "Bank account",
                                      onPressed: () async {
                                        final changed =
                                            await Navigator.pushNamed(
                                              context,
                                              '/bankAccount',
                                            );
                                        if (changed == true) {
                                          await c.init();
                                        }
                                      },
                                      icon: Icon(
                                        Icons.account_balance,
                                        color: kPurple,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                Text(
                                  "Service Type",
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _SegmentBar(
                                  options: FreelancerProfileController
                                      .serviceTypeOptions,
                                  value: c.profile!.serviceType,
                                  enabled: c.isEditing,
                                  onChanged: (v) =>
                                      c.setServiceTypeAndPersist(v),
                                  purple: kPurple,
                                ),

                                const SizedBox(height: 14),

                                Text(
                                  "Working Mode",
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _SegmentBar(
                                  options: FreelancerProfileController
                                      .workingModeOptions,
                                  value: c.profile!.workingMode,
                                  enabled: c.isEditing,
                                  onChanged: (v) =>
                                      c.setWorkingModeAndPersist(v),
                                  purple: kPurple,
                                ),

                                const SizedBox(height: 16),

                                // Experience
                                Row(
                                  children: [
                                    Text(
                                      "Experience",
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (c.isEditing)
                                      TextButton.icon(
                                        onPressed: () async {
                                          final res = await _experienceDialog();
                                          if (res == null) return;
                                          await c.addExperience(res);
                                        },
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text("Add"),
                                        style: TextButton.styleFrom(
                                          foregroundColor: kPurple,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                ...List.generate(
                                  c.profile!.experiences.length,
                                  (i) {
                                    final e = c.profile!.experiences[i];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _ExperienceCard(
                                        purple: kPurple,
                                        experience: e,
                                        editable: c.isEditing,
                                        onEdit: () async {
                                          final res = await _experienceDialog(
                                            initial: e,
                                          );
                                          if (res == null) return;
                                          await c.editExperience(i, res);
                                        },
                                        onDelete: () async =>
                                            await c.deleteExperience(i),
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 14),

                                // Portfolio
                                _InnerBox(
                                  borderColor: kSoftBorder,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            "Portfolio",
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (c.isEditing)
                                            TextButton.icon(
                                              onPressed: _pickPortfolioImages,
                                              icon: const Icon(
                                                Icons.add,
                                                size: 18,
                                              ),
                                              label: const Text("Add"),
                                              style: TextButton.styleFrom(
                                                foregroundColor: kPurple,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Builder(
                                        builder: (context) {
                                          final net = c.profile!.portfolioUrls;
                                          final local = c.pickedPortfolioFiles;
                                          final total =
                                              net.length + local.length;

                                          return GridView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            itemCount: total == 0 ? 4 : total,
                                            gridDelegate:
                                                const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 2,
                                                  crossAxisSpacing: 10,
                                                  mainAxisSpacing: 10,
                                                ),
                                            itemBuilder: (ctx, i) {
                                              if (total == 0) {
                                                return _PlaceholderTile(
                                                  purple: kPurple,
                                                );
                                              }

                                              if (i < net.length) {
                                                final url = net[i];
                                                return ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.network(
                                                    url,
                                                    fit: BoxFit.cover,
                                                  ),
                                                );
                                              }

                                              final localIndex = i - net.length;
                                              final f = local[localIndex];

                                              return Stack(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    child: Image.file(
                                                      f,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                  if (c.isEditing)
                                                    Positioned(
                                                      top: 6,
                                                      right: 6,
                                                      child: IconButton(
                                                        onPressed: () =>
                                                            c.removePortfolioAt(
                                                              localIndex,
                                                            ),
                                                        icon: const Icon(
                                                          Icons.close,
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 18),

                                if (c.isEditing) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _AdminOutlinedBtn(
                                          text: "Cancel",
                                          textColor: kPurple,
                                          borderColor: kPurple.withOpacity(
                                            0.25,
                                          ),
                                          onPressed: c.isSaving
                                              ? null
                                              : c.cancelEdit,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: kPurple,
                                            minimumSize: const Size.fromHeight(
                                              50,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          onPressed: c.isSaving
                                              ? null
                                              : () async {
                                                  final ok =
                                                      _formKey.currentState
                                                          ?.validate() ??
                                                      false;
                                                  if (!ok) return;

                                                  // ✅ تأكيد الاسم حقلين
                                                  final okName =
                                                      c.validateFirstName(
                                                            c
                                                                .firstNameCtrl
                                                                .text,
                                                          ) ==
                                                          null &&
                                                      c.validateLastName(
                                                            c.lastNameCtrl.text,
                                                          ) ==
                                                          null;
                                                  if (!okName) return;

                                                  final saved = await c.save();
                                                  if (!mounted) return;

                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        saved
                                                            ? "Saved successfully ✅"
                                                            : "Save failed: ${c.error ?? ''}",
                                                      ),
                                                    ),
                                                  );
                                                },
                                          child: c.isSaving
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Text("Done"),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  _AdminOutlinedBtn(
                                    text: "Reset password",
                                    textColor: const Color(0xFF2F7BFF),
                                    borderColor: kPurple.withOpacity(0.25),
                                    onPressed: () => c.goResetPassword(context),
                                  ),
                                  const SizedBox(height: 12),
                                  _AdminOutlinedBtn(
                                    text: "Delete account",
                                    textColor: Colors.red,
                                    borderColor: kPurple.withOpacity(0.25),
                                    onPressed: () => c.deleteAccount(context),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}

// ===== Header Widget (No Job Title) =====

class _HeaderLikeAdmin_NoJobTitle extends StatelessWidget {
  const _HeaderLikeAdmin_NoJobTitle({
    required this.purple,
    required this.headerBg,
    required this.isEditing,
    required this.profile,
    required this.pickedImageFile,
    required this.onPickImage,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.onEditTap,
    required this.firstNameValidator,
    required this.lastNameValidator,
  });

  final Color purple;
  final Color headerBg;

  final bool isEditing;
  final FreelancerProfileModel profile;
  final File? pickedImageFile;
  final VoidCallback onPickImage;

  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;

  final VoidCallback? onEditTap;

  final String? Function(String?) firstNameValidator;
  final String? Function(String?) lastNameValidator;

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatar;
    if (pickedImageFile != null) {
      avatar = FileImage(pickedImageFile!);
    } else if (profile.photoUrl != null && profile.photoUrl!.isNotEmpty) {
      avatar = NetworkImage(profile.photoUrl!);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          color: headerBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: purple.withOpacity(0.22), width: 1.2),
        ),
        child: Stack(
          children: [
            if (!isEditing)
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  onPressed: onEditTap,
                  icon: Icon(Icons.edit, color: purple, size: 20),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: Stack(
                        children: [
                          Center(
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 41,
                                backgroundColor: headerBg,
                                backgroundImage: avatar,
                                child: avatar == null
                                    ? Icon(
                                        Icons.person,
                                        color: purple,
                                        size: 34,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          if (isEditing)
                            Positioned(
                              right: 10,
                              bottom: 8,
                              child: GestureDetector(
                                onTap: onPickImage,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: purple,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (!isEditing)
                      Text(
                        profile.fullName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: purple,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 125,
                            child: TextFormField(
                              controller: firstNameCtrl,
                              validator: firstNameValidator,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: purple,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                hintText: "First",
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 125,
                            child: TextFormField(
                              controller: lastNameCtrl,
                              validator: lastNameValidator,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: purple,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                hintText: "Last",
                              ),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 4),
                    Text(
                      "Freelancer",
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== rest widgets (same as your file) =====

class _InnerBox extends StatelessWidget {
  const _InnerBox({required this.child, required this.borderColor});
  final Widget child;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: child,
    );
  }
}

class _AdminOutlinedBtn extends StatelessWidget {
  const _AdminOutlinedBtn({
    required this.text,
    required this.textColor,
    required this.borderColor,
    required this.onPressed,
  });

  final String text;
  final Color textColor;
  final Color borderColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: borderColor, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.label,
    required this.enabled,
    required this.controller,
    required this.purple,
    this.maxLength,
    this.maxLines = 1,
    this.validator,
    this.keyboardType,
    this.counterText,
    this.hintText,
  });

  final String label;
  final bool enabled;
  final TextEditingController controller;
  final Color purple;

  final int? maxLength;
  final int maxLines;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final String? counterText;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: purple.withOpacity(0.25), width: 1.2),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          keyboardType: keyboardType,
          maxLength: maxLength,
          maxLines: maxLines,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hintText,
            counterText: counterText ?? "",
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(color: purple, width: 1.4),
            ),
            disabledBorder: border.copyWith(
              borderSide: BorderSide(
                color: purple.withOpacity(0.18),
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyBlock extends StatelessWidget {
  const _ReadOnlyBlock({
    required this.title,
    required this.value,
    required this.purple,
  });

  final String title;
  final String value;
  final Color purple;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: purple,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({
    required this.purple,
    required this.experience,
    required this.editable,
    required this.onEdit,
    required this.onDelete,
  });

  final Color purple;
  final ExperienceModel experience;
  final bool editable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: purple.withOpacity(0.22), width: 1.2),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFF2EAFB),
            child: Icon(Icons.school, color: purple),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  experience.field,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  experience.org,
                  style: TextStyle(color: purple, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  experience.period,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          if (editable) ...[
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, size: 18),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile({required this.purple});
  final Color purple;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Icon(Icons.image, color: purple),
    );
  }
}

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({
    required this.options,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.purple,
  });

  final List<String> options;
  final String? value;
  final bool enabled;
  final void Function(String v) onChanged;
  final Color purple;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: purple.withOpacity(0.25), width: 1.2),
      ),
      child: Row(
        children: options.map((o) {
          final selected = o == value;
          return Expanded(
            child: InkWell(
              onTap: enabled ? () => onChanged(o) : null,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? purple.withOpacity(0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    o,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? purple : Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
