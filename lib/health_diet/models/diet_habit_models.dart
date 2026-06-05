import 'dart:convert';

class DietHabitPatternRecord {
  const DietHabitPatternRecord({
    this.id,
    required this.userId,
    required this.patternType,
    required this.patternName,
    this.evidence = const [],
    required this.frequencyCount,
    this.firstSeenAt,
    this.lastSeenAt,
    this.status = 'active',
  });

  final int? id;
  final String userId;
  final String patternType;
  final String patternName;
  final List<String> evidence;
  final int frequencyCount;
  final String? firstSeenAt;
  final String? lastSeenAt;
  final String status;

  factory DietHabitPatternRecord.fromMap(Map<String, Object?> map) {
    final evidenceJson = map['evidence_json']?.toString();
    List<String> evidence = const [];
    if (evidenceJson != null && evidenceJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(evidenceJson);
        if (decoded is List) evidence = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return DietHabitPatternRecord(
      id: int.tryParse((map['id'] ?? '').toString()),
      userId: (map['user_id'] ?? 'local_user').toString(),
      patternType: (map['pattern_type'] ?? '').toString(),
      patternName: (map['pattern_name'] ?? '').toString(),
      evidence: evidence,
      frequencyCount: int.tryParse((map['frequency_count'] ?? '0').toString()) ?? 0,
      firstSeenAt: map['first_seen_at']?.toString(),
      lastSeenAt: map['last_seen_at']?.toString(),
      status: (map['status'] ?? 'active').toString(),
    );
  }
}

class DietMicroAction {
  const DietMicroAction({
    this.id,
    required this.userId,
    required this.actionDate,
    required this.actionTitle,
    required this.actionReason,
    this.difficultyLevel = 'easy',
    this.relatedPattern,
    this.status = 'active',
    this.createdAt,
    this.completedAt,
  });

  final int? id;
  final String userId;
  final String actionDate;
  final String actionTitle;
  final String actionReason;
  final String difficultyLevel;
  final String? relatedPattern;
  final String status;
  final String? createdAt;
  final String? completedAt;

  factory DietMicroAction.fromMap(Map<String, Object?> map) {
    return DietMicroAction(
      id: int.tryParse((map['id'] ?? '').toString()),
      userId: (map['user_id'] ?? 'local_user').toString(),
      actionDate: (map['action_date'] ?? '').toString(),
      actionTitle: (map['action_title'] ?? '').toString(),
      actionReason: (map['action_reason'] ?? '').toString(),
      difficultyLevel: (map['difficulty_level'] ?? 'easy').toString(),
      relatedPattern: map['related_pattern']?.toString(),
      status: (map['status'] ?? 'active').toString(),
      createdAt: map['created_at']?.toString(),
      completedAt: map['completed_at']?.toString(),
    );
  }
}

class DietTrendPoint {
  const DietTrendPoint({
    required this.date,
    required this.entryCount,
    required this.recoveryScore,
    required this.proteinScore,
    required this.vegetableScore,
    required this.fiberScore,
    required this.sugarRiskScore,
    required this.sodiumRiskScore,
    required this.processedRiskScore,
    required this.hasBreakfast,
  });

  final String date;
  final int entryCount;
  final double recoveryScore;
  final double proteinScore;
  final double vegetableScore;
  final double fiberScore;
  final double sugarRiskScore;
  final double sodiumRiskScore;
  final double processedRiskScore;
  final bool hasBreakfast;
}

class DietLongTermReport {
  const DietLongTermReport({
    required this.days,
    required this.recordedDays,
    required this.totalEntries,
    required this.averageRecoveryScore,
    required this.averageProteinScore,
    required this.averageVegetableScore,
    required this.averageFiberScore,
    required this.averageSugarRisk,
    required this.averageSodiumRisk,
    required this.averageProcessedRisk,
    required this.breakfastDays,
    required this.trendPoints,
    required this.patterns,
    this.priorityAction,
  });

  final int days;
  final int recordedDays;
  final int totalEntries;
  final double averageRecoveryScore;
  final double averageProteinScore;
  final double averageVegetableScore;
  final double averageFiberScore;
  final double averageSugarRisk;
  final double averageSodiumRisk;
  final double averageProcessedRisk;
  final int breakfastDays;
  final List<DietTrendPoint> trendPoints;
  final List<DietHabitPatternRecord> patterns;
  final DietMicroAction? priorityAction;
}
