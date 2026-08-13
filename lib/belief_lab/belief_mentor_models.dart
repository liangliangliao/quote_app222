import 'dart:convert';

enum BeliefMentorBeliefType {
  reality,
  capability,
  action,
  failure,
  relationship,
  identity,
}

extension BeliefMentorBeliefTypeLabel on BeliefMentorBeliefType {
  String get code => name;

  String get label => switch (this) {
    BeliefMentorBeliefType.reality => '现实判断',
    BeliefMentorBeliefType.capability => '能力信念',
    BeliefMentorBeliefType.action => '行动信念',
    BeliefMentorBeliefType.failure => '失败信念',
    BeliefMentorBeliefType.relationship => '关系信念',
    BeliefMentorBeliefType.identity => '身份信念',
  };

  static BeliefMentorBeliefType parse(Object? value) {
    final raw = (value ?? '').toString();
    return BeliefMentorBeliefType.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => BeliefMentorBeliefType.action,
    );
  }
}

enum BeliefMentorBeliefState {
  discovered,
  activeLimiting,
  alternativeFormed,
  testing,
  evidenceAccumulating,
  shifting,
  internalized,
  userRejected,
  archived,
  needsRealityCheck,
}

extension BeliefMentorBeliefStateLabel on BeliefMentorBeliefState {
  String get dbValue => name;

  String get label => switch (this) {
    BeliefMentorBeliefState.discovered => '待确认',
    BeliefMentorBeliefState.activeLimiting => '正在限制',
    BeliefMentorBeliefState.alternativeFormed => '已形成替代信念',
    BeliefMentorBeliefState.testing => '现实检验中',
    BeliefMentorBeliefState.evidenceAccumulating => '证据积累中',
    BeliefMentorBeliefState.shifting => '正在转变',
    BeliefMentorBeliefState.internalized => '已经内化',
    BeliefMentorBeliefState.userRejected => '用户否认',
    BeliefMentorBeliefState.archived => '已归档',
    BeliefMentorBeliefState.needsRealityCheck => '需要现实校准',
  };

  static BeliefMentorBeliefState parse(Object? value) {
    final raw = (value ?? '').toString();
    return BeliefMentorBeliefState.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => BeliefMentorBeliefState.discovered,
    );
  }
}

enum BeliefMentorExperimentState {
  draft,
  scheduled,
  started,
  completed,
  abandoned,
  reflection,
  evidenceCreated,
}

extension BeliefMentorExperimentStateLabel on BeliefMentorExperimentState {
  String get label => switch (this) {
    BeliefMentorExperimentState.draft => '草稿',
    BeliefMentorExperimentState.scheduled => '已安排',
    BeliefMentorExperimentState.started => '进行中',
    BeliefMentorExperimentState.completed => '待复盘',
    BeliefMentorExperimentState.abandoned => '需要调整',
    BeliefMentorExperimentState.reflection => '复盘中',
    BeliefMentorExperimentState.evidenceCreated => '已形成证据',
  };

  static BeliefMentorExperimentState parse(Object? value) {
    final raw = (value ?? '').toString();
    return BeliefMentorExperimentState.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => BeliefMentorExperimentState.draft,
    );
  }
}

enum BeliefMentorReminderType {
  morningPrime,
  preAction,
  antiAvoidance,
  evidenceCapture,
  failureRecovery,
}

extension BeliefMentorReminderTypeLabel on BeliefMentorReminderType {
  String get label => switch (this) {
    BeliefMentorReminderType.morningPrime => '晨间启动',
    BeliefMentorReminderType.preAction => '行动前',
    BeliefMentorReminderType.antiAvoidance => '反回避',
    BeliefMentorReminderType.evidenceCapture => '证据捕捉',
    BeliefMentorReminderType.failureRecovery => '失败恢复',
  };

  bool get isCritical => this == BeliefMentorReminderType.preAction;

  static BeliefMentorReminderType parse(Object? value) {
    final raw = (value ?? '').toString();
    return BeliefMentorReminderType.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => BeliefMentorReminderType.preAction,
    );
  }
}

enum BeliefMentorReminderState {
  created,
  scheduled,
  suppressed,
  sent,
  opened,
  snoozed,
  ignored,
  actionStarted,
  rescheduled,
  followUp,
  evidenceCreated,
  closed,
}

extension BeliefMentorReminderStateLabel on BeliefMentorReminderState {
  String get label => switch (this) {
    BeliefMentorReminderState.created => '已创建',
    BeliefMentorReminderState.scheduled => '已安排',
    BeliefMentorReminderState.suppressed => '已抑制',
    BeliefMentorReminderState.sent => '已发送',
    BeliefMentorReminderState.opened => '已打开',
    BeliefMentorReminderState.snoozed => '已延期',
    BeliefMentorReminderState.ignored => '已忽略',
    BeliefMentorReminderState.actionStarted => '已启动行动',
    BeliefMentorReminderState.rescheduled => '已重新安排',
    BeliefMentorReminderState.followUp => '跟进中',
    BeliefMentorReminderState.evidenceCreated => '已形成证据',
    BeliefMentorReminderState.closed => '已关闭',
  };

  static BeliefMentorReminderState parse(Object? value) {
    final raw = (value ?? '').toString();
    return BeliefMentorReminderState.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => BeliefMentorReminderState.created,
    );
  }
}

enum BeliefMentorEvidenceStrength { weak, medium, strong }

extension BeliefMentorEvidenceStrengthLabel on BeliefMentorEvidenceStrength {
  String get label => switch (this) {
    BeliefMentorEvidenceStrength.weak => '弱',
    BeliefMentorEvidenceStrength.medium => '中',
    BeliefMentorEvidenceStrength.strong => '强',
  };

  static BeliefMentorEvidenceStrength parse(Object? value) {
    final raw = (value ?? '').toString();
    return BeliefMentorEvidenceStrength.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => BeliefMentorEvidenceStrength.medium,
    );
  }
}

class BeliefMentorProfile {
  const BeliefMentorProfile({
    this.onboardingCompleted = false,
    this.domains = const <String>[],
    this.remindersEnabled = false,
    this.quietStart = '22:00',
    this.quietEnd = '08:00',
    this.morningTime = '08:30',
    this.tone = 'coach',
    this.notificationsPaused = false,
    this.needsSpaceUntilMs = 0,
    this.timezone = '',
    this.updatedAtMs = 0,
  });

  final bool onboardingCompleted;
  final List<String> domains;
  final bool remindersEnabled;
  final String quietStart;
  final String quietEnd;
  final String morningTime;
  final String tone;
  final bool notificationsPaused;
  final int needsSpaceUntilMs;
  final String timezone;
  final int updatedAtMs;

  bool needsSpaceAt(DateTime now) =>
      needsSpaceUntilMs > now.millisecondsSinceEpoch;

  BeliefMentorProfile copyWith({
    bool? onboardingCompleted,
    List<String>? domains,
    bool? remindersEnabled,
    String? quietStart,
    String? quietEnd,
    String? morningTime,
    String? tone,
    bool? notificationsPaused,
    int? needsSpaceUntilMs,
    String? timezone,
    int? updatedAtMs,
  }) => BeliefMentorProfile(
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    domains: domains ?? this.domains,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
    morningTime: morningTime ?? this.morningTime,
    tone: tone ?? this.tone,
    notificationsPaused: notificationsPaused ?? this.notificationsPaused,
    needsSpaceUntilMs: needsSpaceUntilMs ?? this.needsSpaceUntilMs,
    timezone: timezone ?? this.timezone,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );

  Map<String, Object?> toRow() => <String, Object?>{
    'id': 1,
    'onboarding_completed': onboardingCompleted ? 1 : 0,
    'domains_json': jsonEncode(domains),
    'reminders_enabled': remindersEnabled ? 1 : 0,
    'quiet_start': quietStart,
    'quiet_end': quietEnd,
    'morning_time': morningTime,
    'tone': tone,
    'notifications_paused': notificationsPaused ? 1 : 0,
    'needs_space_until_ms': needsSpaceUntilMs,
    'timezone': timezone,
    'updated_at_ms': updatedAtMs,
  };

  factory BeliefMentorProfile.fromRow(Map<String, Object?> row) =>
      BeliefMentorProfile(
        onboardingCompleted: _asBool(row['onboarding_completed']),
        domains: _stringList(row['domains_json']),
        remindersEnabled: _asBool(row['reminders_enabled']),
        quietStart: (row['quiet_start'] ?? '22:00').toString(),
        quietEnd: (row['quiet_end'] ?? '08:00').toString(),
        morningTime: (row['morning_time'] ?? '08:30').toString(),
        tone: (row['tone'] ?? 'coach').toString(),
        notificationsPaused: _asBool(row['notifications_paused']),
        needsSpaceUntilMs: _asInt(row['needs_space_until_ms']),
        timezone: (row['timezone'] ?? '').toString(),
        updatedAtMs: _asInt(row['updated_at_ms']),
      );
}

class BeliefMentorBelief {
  const BeliefMentorBelief({
    required this.id,
    required this.statement,
    required this.type,
    required this.strength,
    required this.trigger,
    required this.alternativeStatement,
    required this.state,
    required this.userConfirmed,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.testingStartedAtMs = 0,
    this.initialStrength = 0,
  });

  final String id;
  final String statement;
  final BeliefMentorBeliefType type;
  final int strength;
  final int initialStrength;
  final String trigger;
  final String alternativeStatement;
  final BeliefMentorBeliefState state;
  final bool userConfirmed;
  final int createdAtMs;
  final int updatedAtMs;
  final int testingStartedAtMs;

  Map<String, Object?> toRow() => <String, Object?>{
    'id': id,
    'statement': statement,
    'belief_type': type.name,
    'strength': strength.clamp(0, 100),
    'initial_strength': initialStrength.clamp(0, 100),
    'trigger_text': trigger,
    'alternative_statement': alternativeStatement,
    'state': state.name,
    'user_confirmed': userConfirmed ? 1 : 0,
    'created_at_ms': createdAtMs,
    'updated_at_ms': updatedAtMs,
    'testing_started_at_ms': testingStartedAtMs,
  };

  factory BeliefMentorBelief.fromRow(Map<String, Object?> row) =>
      BeliefMentorBelief(
        id: (row['id'] ?? '').toString(),
        statement: (row['statement'] ?? '').toString(),
        type: BeliefMentorBeliefTypeLabel.parse(row['belief_type']),
        strength: _asInt(row['strength']).clamp(0, 100),
        initialStrength: _asInt(row['initial_strength']).clamp(0, 100),
        trigger: (row['trigger_text'] ?? '').toString(),
        alternativeStatement: (row['alternative_statement'] ?? '').toString(),
        state: BeliefMentorBeliefStateLabel.parse(row['state']),
        userConfirmed: _asBool(row['user_confirmed']),
        createdAtMs: _asInt(row['created_at_ms']),
        updatedAtMs: _asInt(row['updated_at_ms']),
        testingStartedAtMs: _asInt(row['testing_started_at_ms']),
      );
}

class BeliefMentorExperiment {
  const BeliefMentorExperiment({
    required this.id,
    required this.beliefId,
    required this.action,
    required this.minimumVersion,
    required this.fallbackAction,
    required this.scheduledAtMs,
    required this.timezone,
    required this.difficulty,
    required this.completionProbability,
    required this.state,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.startedAtMs = 0,
    this.completedAtMs = 0,
  });

  final String id;
  final String beliefId;
  final String action;
  final String minimumVersion;
  final String fallbackAction;
  final int scheduledAtMs;
  final String timezone;
  final int difficulty;
  final int completionProbability;
  final BeliefMentorExperimentState state;
  final int createdAtMs;
  final int updatedAtMs;
  final int startedAtMs;
  final int completedAtMs;

  Map<String, Object?> toRow() => <String, Object?>{
    'id': id,
    'belief_id': beliefId,
    'action_text': action,
    'minimum_version': minimumVersion,
    'fallback_action': fallbackAction,
    'scheduled_at_ms': scheduledAtMs,
    'timezone': timezone,
    'difficulty': difficulty.clamp(1, 10),
    'completion_probability': completionProbability.clamp(0, 100),
    'state': state.name,
    'created_at_ms': createdAtMs,
    'updated_at_ms': updatedAtMs,
    'started_at_ms': startedAtMs,
    'completed_at_ms': completedAtMs,
  };

  factory BeliefMentorExperiment.fromRow(Map<String, Object?> row) =>
      BeliefMentorExperiment(
        id: (row['id'] ?? '').toString(),
        beliefId: (row['belief_id'] ?? '').toString(),
        action: (row['action_text'] ?? '').toString(),
        minimumVersion: (row['minimum_version'] ?? '').toString(),
        fallbackAction: (row['fallback_action'] ?? '').toString(),
        scheduledAtMs: _asInt(row['scheduled_at_ms']),
        timezone: (row['timezone'] ?? '').toString(),
        difficulty: _asInt(row['difficulty']).clamp(1, 10),
        completionProbability: _asInt(row['completion_probability'])
            .clamp(0, 100),
        state: BeliefMentorExperimentStateLabel.parse(row['state']),
        createdAtMs: _asInt(row['created_at_ms']),
        updatedAtMs: _asInt(row['updated_at_ms']),
        startedAtMs: _asInt(row['started_at_ms']),
        completedAtMs: _asInt(row['completed_at_ms']),
      );
}

class BeliefMentorEvidence {
  const BeliefMentorEvidence({
    required this.id,
    required this.beliefId,
    required this.experimentId,
    required this.prediction,
    required this.action,
    required this.outcome,
    required this.emotionBefore,
    required this.emotionAfter,
    required this.learning,
    required this.statement,
    required this.strength,
    required this.createdAtMs,
  });

  final String id;
  final String beliefId;
  final String experimentId;
  final String prediction;
  final String action;
  final String outcome;
  final int emotionBefore;
  final int emotionAfter;
  final String learning;
  final String statement;
  final BeliefMentorEvidenceStrength strength;
  final int createdAtMs;

  Map<String, Object?> toRow() => <String, Object?>{
    'id': id,
    'belief_id': beliefId,
    'experiment_id': experimentId,
    'prediction_text': prediction,
    'action_text': action,
    'outcome_text': outcome,
    'emotion_before': emotionBefore.clamp(0, 10),
    'emotion_after': emotionAfter.clamp(0, 10),
    'learning_text': learning,
    'evidence_statement': statement,
    'strength': strength.name,
    'created_at_ms': createdAtMs,
  };

  factory BeliefMentorEvidence.fromRow(Map<String, Object?> row) =>
      BeliefMentorEvidence(
        id: (row['id'] ?? '').toString(),
        beliefId: (row['belief_id'] ?? '').toString(),
        experimentId: (row['experiment_id'] ?? '').toString(),
        prediction: (row['prediction_text'] ?? '').toString(),
        action: (row['action_text'] ?? '').toString(),
        outcome: (row['outcome_text'] ?? '').toString(),
        emotionBefore: _asInt(row['emotion_before']).clamp(0, 10),
        emotionAfter: _asInt(row['emotion_after']).clamp(0, 10),
        learning: (row['learning_text'] ?? '').toString(),
        statement: (row['evidence_statement'] ?? '').toString(),
        strength: BeliefMentorEvidenceStrengthLabel.parse(row['strength']),
        createdAtMs: _asInt(row['created_at_ms']),
      );
}

class BeliefMentorReminder {
  const BeliefMentorReminder({
    required this.id,
    required this.experimentId,
    required this.beliefId,
    required this.type,
    required this.scheduledAtMs,
    required this.state,
    required this.title,
    required this.body,
    required this.alarmId,
    required this.deliveryKey,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.suppressReason = '',
    this.ignoredCount = 0,
  });

  final String id;
  final String experimentId;
  final String beliefId;
  final BeliefMentorReminderType type;
  final int scheduledAtMs;
  final BeliefMentorReminderState state;
  final String title;
  final String body;
  final int alarmId;
  final String deliveryKey;
  final String suppressReason;
  final int ignoredCount;
  final int createdAtMs;
  final int updatedAtMs;

  Map<String, Object?> toRow() => <String, Object?>{
    'id': id,
    'experiment_id': experimentId,
    'belief_id': beliefId,
    'reminder_type': type.name,
    'scheduled_at_ms': scheduledAtMs,
    'state': state.name,
    'title': title,
    'body': body,
    'alarm_id': alarmId,
    'delivery_key': deliveryKey,
    'suppress_reason': suppressReason,
    'ignored_count': ignoredCount,
    'created_at_ms': createdAtMs,
    'updated_at_ms': updatedAtMs,
  };

  factory BeliefMentorReminder.fromRow(Map<String, Object?> row) =>
      BeliefMentorReminder(
        id: (row['id'] ?? '').toString(),
        experimentId: (row['experiment_id'] ?? '').toString(),
        beliefId: (row['belief_id'] ?? '').toString(),
        type: BeliefMentorReminderTypeLabel.parse(row['reminder_type']),
        scheduledAtMs: _asInt(row['scheduled_at_ms']),
        state: BeliefMentorReminderStateLabel.parse(row['state']),
        title: (row['title'] ?? '').toString(),
        body: (row['body'] ?? '').toString(),
        alarmId: _asInt(row['alarm_id']),
        deliveryKey: (row['delivery_key'] ?? '').toString(),
        suppressReason: (row['suppress_reason'] ?? '').toString(),
        ignoredCount: _asInt(row['ignored_count']),
        createdAtMs: _asInt(row['created_at_ms']),
        updatedAtMs: _asInt(row['updated_at_ms']),
      );
}

class BeliefMentorStory {
  const BeliefMentorStory({
    required this.id,
    required this.title,
    required this.targetType,
    required this.hook,
    required this.story,
    required this.mechanism,
    required this.boundary,
    required this.reflection,
    required this.experiment,
    required this.evidenceGrade,
    required this.sourceLabel,
    required this.reviewStatus,
  });

  final String id;
  final String title;
  final BeliefMentorBeliefType targetType;
  final String hook;
  final String story;
  final String mechanism;
  final String boundary;
  final String reflection;
  final String experiment;
  final String evidenceGrade;
  final String sourceLabel;
  final String reviewStatus;

  Map<String, Object?> toRow() => <String, Object?>{
    'id': id,
    'title': title,
    'target_type': targetType.name,
    'hook': hook,
    'story_text': story,
    'mechanism': mechanism,
    'boundary_text': boundary,
    'reflection_question': reflection,
    'proposed_experiment': experiment,
    'evidence_grade': evidenceGrade,
    'source_label': sourceLabel,
    'review_status': reviewStatus,
  };

  factory BeliefMentorStory.fromRow(Map<String, Object?> row) =>
      BeliefMentorStory(
        id: (row['id'] ?? '').toString(),
        title: (row['title'] ?? '').toString(),
        targetType: BeliefMentorBeliefTypeLabel.parse(row['target_type']),
        hook: (row['hook'] ?? '').toString(),
        story: (row['story_text'] ?? '').toString(),
        mechanism: (row['mechanism'] ?? '').toString(),
        boundary: (row['boundary_text'] ?? '').toString(),
        reflection: (row['reflection_question'] ?? '').toString(),
        experiment: (row['proposed_experiment'] ?? '').toString(),
        evidenceGrade: (row['evidence_grade'] ?? '').toString(),
        sourceLabel: (row['source_label'] ?? '').toString(),
        reviewStatus: (row['review_status'] ?? '').toString(),
      );
}

class BeliefMentorFailure {
  const BeliefMentorFailure({
    required this.id,
    required this.beliefId,
    required this.experimentId,
    required this.facts,
    required this.interpretation,
    required this.emotion,
    required this.nextStep,
    required this.stage,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.closedAtMs = 0,
  });

  final String id;
  final String beliefId;
  final String experimentId;
  final String facts;
  final String interpretation;
  final String emotion;
  final String nextStep;
  final String stage;
  final int createdAtMs;
  final int updatedAtMs;
  final int closedAtMs;

  Map<String, Object?> toRow() => <String, Object?>{
    'id': id,
    'belief_id': beliefId,
    'experiment_id': experimentId,
    'facts': facts,
    'interpretation_text': interpretation,
    'emotion_text': emotion,
    'next_step': nextStep,
    'stage': stage,
    'created_at_ms': createdAtMs,
    'updated_at_ms': updatedAtMs,
    'closed_at_ms': closedAtMs,
  };
}

class BeliefMentorTodaySnapshot {
  const BeliefMentorTodaySnapshot({
    this.belief,
    this.experiment,
    this.nextReminder,
    this.latestEvidence,
    this.story,
    this.openFailure,
  });

  final BeliefMentorBelief? belief;
  final BeliefMentorExperiment? experiment;
  final BeliefMentorReminder? nextReminder;
  final BeliefMentorEvidence? latestEvidence;
  final BeliefMentorStory? story;
  final BeliefMentorFailure? openFailure;
}

class BeliefMentorWeeklyReport {
  const BeliefMentorWeeklyReport({
    required this.experimentsCreated,
    required this.experimentsStarted,
    required this.experimentsCompleted,
    required this.evidenceCreated,
    required this.failuresLogged,
    required this.recoveryActions,
    required this.remindersSent,
    required this.autonomousStarts,
    required this.averageReminderCount,
  });

  final int experimentsCreated;
  final int experimentsStarted;
  final int experimentsCompleted;
  final int evidenceCreated;
  final int failuresLogged;
  final int recoveryActions;
  final int remindersSent;
  final int autonomousStarts;
  final double averageReminderCount;

  double get actionInitiationRate =>
      experimentsCreated == 0 ? 0 : experimentsStarted / experimentsCreated;

  double get completionRate =>
      experimentsCreated == 0 ? 0 : experimentsCompleted / experimentsCreated;

  double get evidenceConversion =>
      experimentsCompleted == 0 ? 0 : evidenceCreated / experimentsCompleted;
}

class BeliefMentorCandidateBelief {
  const BeliefMentorCandidateBelief({
    required this.statement,
    required this.type,
    required this.trigger,
    required this.alternative,
    required this.confidence,
  });

  final String statement;
  final BeliefMentorBeliefType type;
  final String trigger;
  final String alternative;
  final double confidence;
}

class BeliefMentorDiagnosis {
  const BeliefMentorDiagnosis({
    required this.facts,
    required this.interpretations,
    required this.emotions,
    required this.behaviorTendencies,
    required this.candidates,
    required this.riskLevel,
    required this.safetyMessage,
  });

  final List<String> facts;
  final List<String> interpretations;
  final List<String> emotions;
  final List<String> behaviorTendencies;
  final List<BeliefMentorCandidateBelief> candidates;
  final String riskLevel;
  final String safetyMessage;

  bool get blocksNormalFlow => riskLevel == 'high';
}

class BeliefMentorAiResult<T> {
  const BeliefMentorAiResult({
    required this.value,
    required this.usedCloudAi,
    required this.provider,
    required this.model,
    required this.runStatus,
    required this.redactedCount,
    this.failureMessage = '',
  });

  final T value;
  final bool usedCloudAi;
  final String provider;
  final String model;
  final String runStatus;
  final int redactedCount;
  final String failureMessage;
}

class BeliefMentorExperimentDraft {
  const BeliefMentorExperimentDraft({
    required this.action,
    required this.minimumVersion,
    required this.fallbackAction,
    required this.difficulty,
    required this.completionProbability,
    required this.rationale,
  });

  final String action;
  final String minimumVersion;
  final String fallbackAction;
  final int difficulty;
  final int completionProbability;
  final String rationale;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

bool _asBool(Object? value) => value == true || value == 1 || value == '1';

List<String> _stringList(Object? value) {
  if (value is List) return value.map((item) => item.toString()).toList();
  try {
    final decoded = jsonDecode((value ?? '[]').toString());
    if (decoded is List) return decoded.map((item) => item.toString()).toList();
  } catch (_) {}
  return const <String>[];
}
