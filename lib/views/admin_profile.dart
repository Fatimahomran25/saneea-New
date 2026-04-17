import 'package:flutter/material.dart';
import '../controlles/admin_controller.dart';
import '../models/admin_model.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  static const _primaryPurple = Color.fromRGBO(79, 55, 139, 1);
  static const _headerBg = Color(0xFFF2EAFB);
  static const _softBorder = Color(0x66B8A9D9);

  final c = AdminController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => c.back(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.red, size: 28),
              onPressed: () => c.logout(context),
            ),
          ),
        ],
      ),

      body: FutureBuilder<AdminModel>(
        future: c.getAdminFromFirebase(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final AdminModel admin = snapshot.data ?? c.getAdmin();

          return Column(
            children: [
              const SizedBox(height: 10),

              /// ✅ Header Box (سادة + إطار خفيف)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 210,
                  decoration: BoxDecoration(
                    color: _headerBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _primaryPurple.withOpacity(0.22),
                      width: 1.2,
                    ),
                  ),
                  child: Align(
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
                                      backgroundColor: _headerBg,
                                      backgroundImage:
                                          (admin.photoUrl != null &&
                                              admin.photoUrl!.isNotEmpty)
                                          ? NetworkImage(admin.photoUrl!)
                                          : AssetImage(admin.photoAssetPath)
                                                as ImageProvider,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 10,
                                  bottom: 8,
                                  child: GestureDetector(
                                    onTap: () async {
                                      await c.pickAndUploadAdminPhoto(context);
                                      setState(() {});
                                    },
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: _primaryPurple,
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
                          Text(
                            admin.name,
                            style: const TextStyle(
                              color: _primaryPurple,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            admin.role,
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
                ),
              ),

              const SizedBox(height: 14),

              /// ✅ الكارد الطويل الممتد
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F1FA),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _softBorder, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "National ID / Iqama",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          admin.nationalId,
                          style: const TextStyle(
                            color: _primaryPurple,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          "Email Address",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          admin.email,
                          style: const TextStyle(
                            color: _primaryPurple,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const Spacer(),

                        /// زر Reset بأسفل الكارد
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: _primaryPurple.withOpacity(0.25),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => c.resetPassword(context),
                            child: const Text(
                              "Reset password",
                              style: TextStyle(
                                color: Color(0xFF2F7BFF),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}
