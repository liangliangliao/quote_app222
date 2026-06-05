class HealthProfile {
  const HealthProfile({
    this.id,
    required this.userId,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.mainGoal,
    required this.conditions,
    required this.restrictions,
    required this.preferences,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String userId;
  final String gender;
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final String activityLevel;
  final String mainGoal;
  final List<String> conditions;
  final List<String> restrictions;
  final List<String> preferences;
  final String? createdAt;
  final String? updatedAt;

  HealthProfile copyWith({
    int? id,
    String? userId,
    String? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    String? activityLevel,
    String? mainGoal,
    List<String>? conditions,
    List<String>? restrictions,
    List<String>? preferences,
    String? createdAt,
    String? updatedAt,
  }) {
    return HealthProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      activityLevel: activityLevel ?? this.activityLevel,
      mainGoal: mainGoal ?? this.mainGoal,
      conditions: conditions ?? this.conditions,
      restrictions: restrictions ?? this.restrictions,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class HealthDietOption {
  const HealthDietOption(this.code, this.label, {this.description});

  final String code;
  final String label;
  final String? description;
}
