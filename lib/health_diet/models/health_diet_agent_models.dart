import 'dart:convert';

import 'health_profile.dart';
import '../services/health_diet_options.dart';

class HealthDietGoal {
  const HealthDietGoal({
    this.id,
    required this.userId,
    required this.goalType,
    required this.goalTitle,
    required this.durationDays,
    required this.difficulty,
    required this.preferences,
    required this.avoid,
    required this.successMetrics,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String userId;
  final String goalType;
  final String goalTitle;
  final int durationDays;
  final String difficulty;
  final List<String> preferences;
  final List<String> avoid;
  final List<String> successMetrics;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  factory HealthDietGoal.fromMap(Map<String, Object?> map) {
    List<String> decodeList(Object? raw) {
      if (raw == null) return const [];
      try {
        final decoded = jsonDecode(raw.toString());
        if (decoded is List) return decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      } catch (_) {}
      return raw.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    return HealthDietGoal(
      id: int.tryParse((map['id'] ?? '').toString()),
      userId: (map['user_id'] ?? 'default_user').toString(),
      goalType: (map['goal_type'] ?? 'balanced').toString(),
      goalTitle: (map['goal_title'] ?? '').toString(),
      durationDays: int.tryParse((map['duration_days'] ?? '14').toString()) ?? 14,
      difficulty: (map['difficulty'] ?? 'gentle').toString(),
      preferences: decodeList(map['preferences_json']),
      avoid: decodeList(map['avoid_json']),
      successMetrics: decodeList(map['success_metrics_json']),
      status: (map['status'] ?? 'active').toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }

  Map<String, Object?> toInsertMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'user_id': userId,
      'goal_type': goalType,
      'goal_title': goalTitle,
      'duration_days': durationDays,
      'difficulty': difficulty,
      'preferences_json': jsonEncode(preferences),
      'avoid_json': jsonEncode(avoid),
      'success_metrics_json': jsonEncode(successMetrics),
      'status': status,
      'created_at': createdAt ?? now,
      'updated_at': updatedAt ?? now,
    };
  }

  Map<String, Object?> toAgentJson() => {
        'id': id,
        'goal_type': goalType,
        'goal_title': displayTitle,
        'duration_days': durationDays,
        'difficulty': difficulty,
        'preferences': preferences,
        'avoid': avoid,
        'success_metrics': successMetrics,
        'status': status,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  String get displayTitle {
    if (goalTitle.trim().isNotEmpty) return goalTitle.trim();
    return HealthDietOptions.labelOf(HealthDietOptions.goals, goalType);
  }

  String get difficultyLabel {
    switch (difficulty) {
      case 'strict':
        return '严格';
      case 'medium':
        return '中等';
      case 'gentle':
      default:
        return '温和';
    }
  }
}

class HealthDietAgentTask {
  const HealthDietAgentTask({
    this.id,
    required this.userId,
    this.goalId,
    required this.taskType,
    required this.taskTitle,
    required this.taskReason,
    required this.triggerType,
    this.triggerTime,
    required this.status,
    this.priority = 50,
    this.evidenceJson,
    this.resultJson,
    this.createdAt,
    this.executedAt,
    this.completedAt,
  });

  final int? id;
  final String userId;
  final int? goalId;
  final String taskType;
  final String taskTitle;
  final String taskReason;
  final String triggerType;
  final String? triggerTime;
  final String status;
  final int priority;
  final String? evidenceJson;
  final String? resultJson;
  final String? createdAt;
  final String? executedAt;
  final String? completedAt;

  factory HealthDietAgentTask.fromMap(Map<String, Object?> map) => HealthDietAgentTask(
        id: int.tryParse((map['id'] ?? '').toString()),
        userId: (map['user_id'] ?? 'default_user').toString(),
        goalId: int.tryParse((map['goal_id'] ?? '').toString()),
        taskType: (map['task_type'] ?? '').toString(),
        taskTitle: (map['task_title'] ?? '').toString(),
        taskReason: (map['task_reason'] ?? '').toString(),
        triggerType: (map['trigger_type'] ?? '').toString(),
        triggerTime: map['trigger_time']?.toString(),
        status: (map['status'] ?? 'pending').toString(),
        priority: int.tryParse((map['priority'] ?? '50').toString()) ?? 50,
        evidenceJson: map['evidence_json']?.toString(),
        resultJson: map['result_json']?.toString(),
        createdAt: map['created_at']?.toString(),
        executedAt: map['executed_at']?.toString(),
        completedAt: map['completed_at']?.toString(),
      );
}

class HealthDietAgentMemory {
  const HealthDietAgentMemory({
    this.id,
    required this.userId,
    required this.memoryType,
    required this.memoryKey,
    required this.memoryValue,
    this.confidence = 0.7,
    this.evidenceJson,
    this.firstSeenAt,
    this.lastSeenAt,
    this.updatedAt,
  });

  final int? id;
  final String userId;
  final String memoryType;
  final String memoryKey;
  final String memoryValue;
  final double confidence;
  final String? evidenceJson;
  final String? firstSeenAt;
  final String? lastSeenAt;
  final String? updatedAt;

  factory HealthDietAgentMemory.fromMap(Map<String, Object?> map) => HealthDietAgentMemory(
        id: int.tryParse((map['id'] ?? '').toString()),
        userId: (map['user_id'] ?? 'default_user').toString(),
        memoryType: (map['memory_type'] ?? '').toString(),
        memoryKey: (map['memory_key'] ?? '').toString(),
        memoryValue: (map['memory_value'] ?? '').toString(),
        confidence: double.tryParse((map['confidence'] ?? '0.7').toString()) ?? 0.7,
        evidenceJson: map['evidence_json']?.toString(),
        firstSeenAt: map['first_seen_at']?.toString(),
        lastSeenAt: map['last_seen_at']?.toString(),
        updatedAt: map['updated_at']?.toString(),
      );
}

class HealthDietAgentPlanRecord {
  const HealthDietAgentPlanRecord({
    this.id,
    required this.userId,
    this.goalId,
    required this.planDate,
    required this.source,
    required this.planJson,
    this.createdAt,
  });

  final int? id;
  final String userId;
  final int? goalId;
  final String planDate;
  final String source;
  final String planJson;
  final String? createdAt;
}

class HealthDietAgentGatewayStatus {
  const HealthDietAgentGatewayStatus({
    required this.enabled,
    required this.baseUrl,
    required this.modeLabel,
    required this.message,
  });

  final bool enabled;
  final String baseUrl;
  final String modeLabel;
  final String message;
}
