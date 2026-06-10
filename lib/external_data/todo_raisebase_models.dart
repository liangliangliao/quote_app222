class TodoRaiseBaseBeliefMap {
  const TodoRaiseBaseBeliefMap({
    required this.mapId,
    required this.goalId,
    required this.goalTitle,
    required this.limitingBelief,
    required this.realityEvidence,
    required this.exaggeratedPart,
    required this.alternativeBelief,
    required this.minimumAction,
    required this.controllableFactor,
    required this.environmentCue,
    required this.obstaclePlan,
    required this.createdAtMs,
  });

  final String mapId;
  final String goalId;
  final String goalTitle;
  final String limitingBelief;
  final String realityEvidence;
  final String exaggeratedPart;
  final String alternativeBelief;
  final String minimumAction;
  final String controllableFactor;
  final String environmentCue;
  final String obstaclePlan;
  final int createdAtMs;

  factory TodoRaiseBaseBeliefMap.fromMap(Map<String, Object?> row) => TodoRaiseBaseBeliefMap(
        mapId: '${row['map_id'] ?? ''}',
        goalId: '${row['goal_id'] ?? ''}',
        goalTitle: '${row['goal_title'] ?? ''}',
        limitingBelief: '${row['limiting_belief'] ?? ''}',
        realityEvidence: '${row['reality_evidence'] ?? ''}',
        exaggeratedPart: '${row['exaggerated_part'] ?? ''}',
        alternativeBelief: '${row['alternative_belief'] ?? ''}',
        minimumAction: '${row['minimum_action'] ?? ''}',
        controllableFactor: '${row['controllable_factor'] ?? ''}',
        environmentCue: '${row['environment_cue'] ?? ''}',
        obstaclePlan: '${row['obstacle_plan'] ?? ''}',
        createdAtMs: _asInt(row['created_at_ms']),
      );
}

class TodoRaiseBaseCheckIn {
  const TodoRaiseBaseCheckIn({
    required this.checkInId,
    required this.goalId,
    required this.checkInDate,
    required this.realityText,
    required this.possibilityText,
    required this.moodScore,
    required this.copingScore,
    required this.selfEfficacyScore,
    required this.evidenceText,
    required this.createdAtMs,
  });

  final String checkInId;
  final String goalId;
  final String checkInDate;
  final String realityText;
  final String possibilityText;
  final int moodScore;
  final int copingScore;
  final int selfEfficacyScore;
  final String evidenceText;
  final int createdAtMs;

  factory TodoRaiseBaseCheckIn.fromMap(Map<String, Object?> row) => TodoRaiseBaseCheckIn(
        checkInId: '${row['check_in_id'] ?? ''}',
        goalId: '${row['goal_id'] ?? ''}',
        checkInDate: '${row['check_in_date'] ?? ''}',
        realityText: '${row['reality_text'] ?? ''}',
        possibilityText: '${row['possibility_text'] ?? ''}',
        moodScore: _asInt(row['mood_score']),
        copingScore: _asInt(row['coping_score']),
        selfEfficacyScore: _asInt(row['self_efficacy_score']),
        evidenceText: '${row['evidence_text'] ?? ''}',
        createdAtMs: _asInt(row['created_at_ms']),
      );
}

class TodoRaiseBaseSnapshot {
  const TodoRaiseBaseSnapshot({
    required this.moodBaseline,
    required this.copingIndex,
    required this.selfEfficacy,
    required this.completedActions,
    required this.failureReflections,
    required this.evidence,
  });

  final int moodBaseline;
  final int copingIndex;
  final int selfEfficacy;
  final int completedActions;
  final int failureReflections;
  final List<String> evidence;
}

int _asInt(Object? value) => value is int ? value : int.tryParse('${value ?? ''}') ?? 0;
