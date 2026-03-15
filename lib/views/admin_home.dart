/*import 'package:flutter/material.dart';
import '../controlles/admin_controller.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  static const _primaryPurple = Color(0xFF4F378B);

  @override
  Widget build(BuildContext context) {
    final c = AdminController();

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,

        // 👤 أيقونة البروفايل يسار (نفس الفريلانسر)
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: () => c.openProfile(context),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: _primaryPurple.withOpacity(0.12),
              child: const Icon(
                Icons.person_outline,
                color: _primaryPurple,
                size: 22,
              ),
            ),
          ),
        ),

        // 👋 Welcome back, FirstName!
        title: FutureBuilder<String>(
          future: c.getAdminFirstName(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text(
                "Welcome back...",
                style: TextStyle(
                  color: _primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              );
            }

            final firstName = (snapshot.data ?? '').trim();
            final safeName = firstName.isEmpty ? "Admin" : firstName;

            return Text(
              "Welcome back, $safeName!",
              style: const TextStyle(
                color: _primaryPurple,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),

        // 🟣 الشعار يمين
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'assets/LOGO.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),

      // ✅ فاضي (ما فيه كروت ولا أرقام)
      body: const SizedBox(),
    );
  }
}
*/
import 'package:flutter/material.dart';
import '../controlles/admin_controller.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  static const _primaryPurple = Color(0xFF4F378B);

  @override
  Widget build(BuildContext context) {
    final c = AdminController();

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,

        // 👤 أيقونة البروفايل يسار (نفس الفريلانسر)
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: () => c.openProfile(context),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: _primaryPurple.withOpacity(0.12),
              child: const Icon(
                Icons.person_outline,
                color: _primaryPurple,
                size: 22,
              ),
            ),
          ),
        ),

        // 👋 Welcome back, FirstName!
        title: FutureBuilder<String>(
          future: c.getAdminFirstName(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text(
                "Welcome back...",
                style: TextStyle(
                  color: _primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              );
            }

            final firstName = (snapshot.data ?? '').trim();
            final safeName = firstName.isEmpty ? "Admin" : firstName;

            return Text(
              "Welcome back, $safeName!",
              style: const TextStyle(
                color: _primaryPurple,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),

        // 🟣 الشعار يمين
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'assets/LOGO.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),

      // ✅ فاضي (ما فيه كروت ولا أرقام)
      body: const SizedBox(),
    );
  }
}
