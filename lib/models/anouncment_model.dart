class AnnouncementModel {
  final String description;
  final double budget;
  final String duration;

  AnnouncementModel({
    this.description = '',
    this.budget = 0,
    this.duration = '',
  });

  AnnouncementModel copyWith({
    String? description,
    double? budget,
    String? duration,
  }) {
    return AnnouncementModel(
      description: description ?? this.description,
      budget: budget ?? this.budget,
      duration: duration ?? this.duration,
    );
  }
}

