import 'package:flutter/material.dart';

class CategoryModel {
  final String title;
  final IconData icon;

  const CategoryModel(this.title, this.icon);
}

class FreelancerModel {
  final String name;
  final String role;
  final double rating;
  final String imagePath; // ✅ asset path

  const FreelancerModel({
    required this.name,
    required this.role,
    required this.rating,
    required this.imagePath,
  });
}
