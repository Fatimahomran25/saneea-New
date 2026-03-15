/*import 'package:flutter/material.dart';

import 'freelancer_profile.dart'; // نفس مجلد views

class FreelancerHomeView extends StatelessWidget {
  const FreelancerHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Freelancer Home"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),

        // ✅ زر البروفايل هنا
        actions: [
          IconButton(
            tooltip: "Profile",
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FreelancerProfileView(),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: const Center(child: Text("Welcome Freelancer")),
    );
  }
}
*/

import 'package:flutter/material.dart';
import 'freelancer_profile.dart';

class FreelancerHomeView extends StatelessWidget {
  const FreelancerHomeView({super.key});

  static const primary = Color(0xFF5A3E9E); // نفس الكلاينت

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Freelancer Home"),

        // ✅ نفس ستايل الكلاينت + على اليسار
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FreelancerProfileView(),
                ),
              );
            },
            child: CircleAvatar(
              radius: 20,
              backgroundColor: primary.withOpacity(0.12),
              child: const Icon(Icons.person_outline, color: primary, size: 22),
            ),
          ),
        ),

        // ❌ احذفي زر البروفايل من اليمين
        actions: const [SizedBox(width: 6)],
      ),
      body: const Center(child: Text("Welcome Freelancer 👋")),
    );
  }
}
