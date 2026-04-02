import 'package:flutter/material.dart';
import '../models/client_home_model.dart';

class ClientHomeController extends ChangeNotifier {
  final TextEditingController searchController = TextEditingController();

  String _query = "";

  final List<CategoryModel> categories = const [
    CategoryModel("Graphic Designers", Icons.brush_outlined),
    CategoryModel("Marketing", Icons.campaign_outlined),
    CategoryModel("Software Developers", Icons.code),
    CategoryModel("Accounting", Icons.calculate_outlined),
  ];

  final List<FreelancerModel> _freelancers = const [
    FreelancerModel(
      name: "Lina Alharbi",
      role: "Marketing",
      rating: 4.0,
      imagePath: "assets/toprated/lina.jpg", // ✅ صورتك
    ),
    FreelancerModel(
      name: "Ahmed Ali",
      role: "Graphic Designer",
      rating: 3.0,
      imagePath: "assets/toprated/ahmed.jpg",
    ),

    FreelancerModel(
      name: "Khalid Fahad",
      role: "Software Developer",
      rating: 2.0,
      imagePath: "assets/toprated/khalid.jpg", // مؤقت
    ),
  ];

  List<FreelancerModel> get filteredFreelancers {
    if (_query.trim().isEmpty) return _freelancers;

    final q = _query.toLowerCase();
    return _freelancers
        .where(
          (f) =>
              f.name.toLowerCase().contains(q) ||
              f.role.toLowerCase().contains(q),
        )
        .toList();
  }

  
     void onSearchChanged(String value) {
      _query = value.trim();
     notifyListeners();
   } 

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
