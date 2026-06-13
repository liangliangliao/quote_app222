class TodoGoalWillState {
  const TodoGoalWillState({
    required this.ideaId,
    this.selectedObstacle = '',
    this.actionStrength = 60,
    this.obstacleStrength = 70,
    this.actionExperience = 'similar',
    this.bodyCapability = 'ready',
    this.attentionTargetSeconds = 30,
    this.rehearsalCompleted = false,
    this.firstActionCompleted = false,
    this.updatedAtMs = 0,
  });

  final String ideaId;
  final String selectedObstacle;
  final int actionStrength;
  final int obstacleStrength;
  final String actionExperience;
  final String bodyCapability;
  final int attentionTargetSeconds;
  final bool rehearsalCompleted;
  final bool firstActionCompleted;
  final int updatedAtMs;

  bool get needsActionDemonstration => actionExperience == 'new';
  bool get bodyExecutionBlocked => bodyCapability == 'blocked';
  bool get actionIdeaDominant => actionStrength > obstacleStrength;

  TodoGoalWillState copyWith({
    String? selectedObstacle,
    int? actionStrength,
    int? obstacleStrength,
    String? actionExperience,
    String? bodyCapability,
    int? attentionTargetSeconds,
    bool? rehearsalCompleted,
    bool? firstActionCompleted,
    int? updatedAtMs,
  }) =>
      TodoGoalWillState(
        ideaId: ideaId,
        selectedObstacle: selectedObstacle ?? this.selectedObstacle,
        actionStrength: (actionStrength ?? this.actionStrength).clamp(0, 100).toInt(),
        obstacleStrength: (obstacleStrength ?? this.obstacleStrength).clamp(0, 100).toInt(),
        actionExperience: actionExperience ?? this.actionExperience,
        bodyCapability: bodyCapability ?? this.bodyCapability,
        attentionTargetSeconds: (attentionTargetSeconds ?? this.attentionTargetSeconds).clamp(10, 300).toInt(),
        rehearsalCompleted: rehearsalCompleted ?? this.rehearsalCompleted,
        firstActionCompleted: firstActionCompleted ?? this.firstActionCompleted,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );

  factory TodoGoalWillState.fromMap(Map<String, Object?> map) => TodoGoalWillState(
        ideaId: (map['idea_id'] ?? '').toString(),
        selectedObstacle: (map['selected_obstacle'] ?? '').toString(),
        actionStrength: _int(map['action_strength'], 60),
        obstacleStrength: _int(map['obstacle_strength'], 70),
        actionExperience: (map['action_experience'] ?? 'similar').toString(),
        bodyCapability: (map['body_capability'] ?? 'ready').toString(),
        attentionTargetSeconds: _int(map['attention_target_seconds'], 30),
        rehearsalCompleted: _int(map['rehearsal_completed'], 0) == 1,
        firstActionCompleted: _int(map['first_action_completed'], 0) == 1,
        updatedAtMs: _int(map['updated_at_ms'], 0),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'idea_id': ideaId,
        'selected_obstacle': selectedObstacle,
        'action_strength': actionStrength,
        'obstacle_strength': obstacleStrength,
        'action_experience': actionExperience,
        'body_capability': bodyCapability,
        'attention_target_seconds': attentionTargetSeconds,
        'rehearsal_completed': rehearsalCompleted ? 1 : 0,
        'first_action_completed': firstActionCompleted ? 1 : 0,
        'updated_at_ms': updatedAtMs,
      };

  static int _int(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }
}
