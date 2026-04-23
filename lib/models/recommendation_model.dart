import 'package:cloud_firestore/cloud_firestore.dart';

class FreelancerRecommendation {
  final String id;
  final String name;
  final String serviceField;
  final String serviceType;
  final String workingMode;
  final double rating;
  final String? profileImage;
  final List<String> portfolioUrls;

  // 🔧 تعديل فاطمه
  final bool hasExperience;

  // 🔧 نهاية تعديلات فاطمه

  FreelancerRecommendation({
    required this.id,
    required this.name,
    required this.serviceField,
    required this.serviceType,
    required this.workingMode,
    required this.rating,
    required this.profileImage,
    required this.portfolioUrls,

    // 🔧 تعديل فاطمه
    this.hasExperience = false,
    // 🔧 نهاية تعديلات فاطمه
  });

  factory FreelancerRecommendation.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final portfolioList =
        (data['portfolioUrls'] as List?)?.map((e) => e.toString()).toList() ??
        [];

    // 🔧 تعديل فاطمه
    final experiencesList = (data['experiences'] as List?) ?? [];
    // 🔧 نهاية تعديلات فاطمه

    return FreelancerRecommendation(
      id: id,
      name: "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim(),
      serviceField: (data['serviceField'] ?? '').toString(),
      serviceType: (data['serviceType'] ?? '').toString(),
      workingMode: (data['workingMode'] ?? '').toString(),
      rating: (data['rating'] ?? 0).toDouble(),
      profileImage: data['profile']?.toString(), // ✅ التعديل هنا
      portfolioUrls: portfolioList,
      // 🔧 تعديل فاطمه
      hasExperience: experiencesList.isNotEmpty,

      // 🔧 نهاية تعديلات فاطمه
    );
  }
}

class RecommendationResult {
  final FreelancerRecommendation freelancer;
  // 🔧 تعديل فاطمه
  final int matchPercentage;
  // 🔧 نهاية تعديلات فاطمه
  final double rating;

  RecommendationResult({
    required this.freelancer,
    required this.rating,
    required this.matchPercentage,
  });
}

class ClientRequest {
  final String id;
  final String freelancerId;
  final String freelancerName;
  final String description;
  final double? budget;
  final String deadline;
  final String status;
  final DateTime? createdAt;

  ClientRequest({
    required this.id,
    required this.freelancerId,
    required this.freelancerName,
    required this.description,
    required this.budget,
    required this.deadline,
    required this.status,
    required this.createdAt,
  });

  factory ClientRequest.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['createdAt'];
    final budgetValue = data['budget'] ?? data['amount'];
    final deadlineValue = data['deadline'] ?? data['deadlineText'];

    double? parsedBudget;
    if (budgetValue is num) {
      parsedBudget = budgetValue.toDouble();
    } else if (budgetValue != null) {
      parsedBudget = double.tryParse(budgetValue.toString().trim());
    }

    String parsedDeadline;
    if (deadlineValue is Timestamp) {
      final date = deadlineValue.toDate();
      parsedDeadline = '${date.day}/${date.month}/${date.year}';
    } else {
      parsedDeadline = (deadlineValue ?? '').toString();
    }

    return ClientRequest(
      id: id,
      freelancerId: (data['freelancerId'] ?? '').toString(),
      freelancerName: (data['freelancerName'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      budget: parsedBudget,
      deadline: parsedDeadline,
      status: (data['status'] ?? '').toString(),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

class AnnouncementRequest {
  final String id;
  final String announcementId;
  final String clientId;
  final String freelancerId;
  final String freelancerName;
  final String proposalText;
  final String status;
  final DateTime? createdAt;

  AnnouncementRequest({
    required this.id,
    required this.announcementId,
    required this.clientId,
    required this.freelancerId,
    required this.freelancerName,
    required this.proposalText,
    required this.status,
    required this.createdAt,
  });

  factory AnnouncementRequest.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['createdAt'];

    return AnnouncementRequest(
      id: id,
      announcementId: (data['announcementId'] ?? '').toString(),
      clientId: (data['clientId'] ?? '').toString(),
      freelancerId: (data['freelancerId'] ?? '').toString(),
      freelancerName: (data['freelancerName'] ?? '').toString(),
      proposalText: (data['proposalText'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

class FreelancerAnnouncementRequest {
  final String id;
  final String announcementId;
  final String clientId;
  final String freelancerId;
  final String freelancerName;
  final String proposalText;
  final String status;
  final DateTime? createdAt;

  FreelancerAnnouncementRequest({
    required this.id,
    required this.announcementId,
    required this.clientId,
    required this.freelancerId,
    required this.freelancerName,
    required this.proposalText,
    required this.status,
    required this.createdAt,
  });

  factory FreelancerAnnouncementRequest.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final timestamp = data['createdAt'];

    return FreelancerAnnouncementRequest(
      id: id,
      announcementId: (data['announcementId'] ?? '').toString(),
      clientId: (data['clientId'] ?? '').toString(),
      freelancerId: (data['freelancerId'] ?? '').toString(),
      freelancerName: (data['freelancerName'] ?? '').toString(),
      proposalText: (data['proposalText'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}
