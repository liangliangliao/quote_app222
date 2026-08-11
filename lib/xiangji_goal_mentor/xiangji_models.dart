import 'dart:convert';

enum XiangjiGoalState {
  mist,
  spark,
  anchored,
  active,
  feedback,
  calibrating,
  paused,
  reselecting,
  completed,
  archived,
}

extension XiangjiGoalStateX on XiangjiGoalState {
  String get value => name;

  String get label {
    switch (this) {
      case XiangjiGoalState.mist:
        return '迷雾';
      case XiangjiGoalState.spark:
        return '火种';
      case XiangjiGoalState.anchored:
        return '锚定';
      case XiangjiGoalState.active:
        return '行动中';
      case XiangjiGoalState.feedback:
        return '反馈中';
      case XiangjiGoalState.calibrating:
        return '校准中';
      case XiangjiGoalState.paused:
        return '已暂停';
      case XiangjiGoalState.reselecting:
        return '重新选择';
      case XiangjiGoalState.completed:
        return '已完成';
      case XiangjiGoalState.archived:
        return '已归档';
    }
  }
}

XiangjiGoalState parseXiangjiGoalState(Object? raw) {
  final value = (raw ?? '').toString();
  return XiangjiGoalState.values.firstWhere(
    (item) => item.name == value,
    orElse: () => XiangjiGoalState.mist,
  );
}

enum XiangjiZoomMode { panorama, structure, detail, action, evidence }

extension XiangjiZoomModeX on XiangjiZoomMode {
  String get label {
    switch (this) {
      case XiangjiZoomMode.panorama:
        return '先告诉我核心';
      case XiangjiZoomMode.structure:
        return '展开其中逻辑';
      case XiangjiZoomMode.detail:
        return '结合我的情况深入';
      case XiangjiZoomMode.action:
        return '告诉我现在做什么';
      case XiangjiZoomMode.evidence:
        return '查看书籍依据';
    }
  }
}

enum XiangjiCalibrationResult {
  continueGoal,
  changeMethod,
  reduceScope,
  pause,
  reselect,
}

enum XiangjiCheckinResult {
  completed,
  partiallyCompleted,
  notStarted,
  blocked,
  noLongerRelevant,
}

extension XiangjiCheckinResultX on XiangjiCheckinResult {
  String get value {
    switch (this) {
      case XiangjiCheckinResult.completed:
        return 'completed';
      case XiangjiCheckinResult.partiallyCompleted:
        return 'partially_completed';
      case XiangjiCheckinResult.notStarted:
        return 'not_started';
      case XiangjiCheckinResult.blocked:
        return 'blocked';
      case XiangjiCheckinResult.noLongerRelevant:
        return 'no_longer_relevant';
    }
  }

  String get label {
    switch (this) {
      case XiangjiCheckinResult.completed:
        return '已经完成';
      case XiangjiCheckinResult.partiallyCompleted:
        return '部分完成';
      case XiangjiCheckinResult.notStarted:
        return '尚未开始';
      case XiangjiCheckinResult.blocked:
        return '今天条件不允许';
      case XiangjiCheckinResult.noLongerRelevant:
        return '这一步已不再适用';
    }
  }

  String get prompt {
    switch (this) {
      case XiangjiCheckinResult.completed:
      case XiangjiCheckinResult.partiallyCompleted:
        return '留下真实发生过的事实';
      case XiangjiCheckinResult.notStarted:
        return '如实记录尚未开始的条件';
      case XiangjiCheckinResult.blocked:
        return '今天是什么条件不允许？';
      case XiangjiCheckinResult.noLongerRelevant:
        return '为什么这一步已经不再适用？';
    }
  }

  XiangjiEvidenceType get defaultEvidenceType {
    switch (this) {
      case XiangjiCheckinResult.completed:
      case XiangjiCheckinResult.partiallyCompleted:
        return XiangjiEvidenceType.action;
      case XiangjiCheckinResult.notStarted:
        return XiangjiEvidenceType.restAndRecovery;
      case XiangjiCheckinResult.blocked:
        return XiangjiEvidenceType.learning;
      case XiangjiCheckinResult.noLongerRelevant:
        return XiangjiEvidenceType.goalExit;
    }
  }
}

XiangjiCheckinResult? tryParseXiangjiCheckinResult(Object? raw) {
  final value = (raw ?? '').toString();
  for (final result in XiangjiCheckinResult.values) {
    if (result.value == value) return result;
  }
  return null;
}

enum XiangjiEvidenceType {
  action,
  learning,
  strategyChange,
  boundary,
  helpSeeking,
  restAndRecovery,
  goalExit,
  contribution,
}

extension XiangjiEvidenceTypeX on XiangjiEvidenceType {
  String get value {
    switch (this) {
      case XiangjiEvidenceType.action:
        return 'action';
      case XiangjiEvidenceType.learning:
        return 'learning';
      case XiangjiEvidenceType.strategyChange:
        return 'strategy_change';
      case XiangjiEvidenceType.boundary:
        return 'boundary';
      case XiangjiEvidenceType.helpSeeking:
        return 'help_seeking';
      case XiangjiEvidenceType.restAndRecovery:
        return 'rest_and_recovery';
      case XiangjiEvidenceType.goalExit:
        return 'goal_exit';
      case XiangjiEvidenceType.contribution:
        return 'contribution';
    }
  }

  String get label {
    switch (this) {
      case XiangjiEvidenceType.action:
        return '真实行动';
      case XiangjiEvidenceType.learning:
        return '形成学习';
      case XiangjiEvidenceType.strategyChange:
        return '调整策略';
      case XiangjiEvidenceType.boundary:
        return '守住边界';
      case XiangjiEvidenceType.helpSeeking:
        return '主动求助';
      case XiangjiEvidenceType.restAndRecovery:
        return '休息与恢复';
      case XiangjiEvidenceType.goalExit:
        return '退出不适合的目标';
      case XiangjiEvidenceType.contribution:
        return '产生贡献';
    }
  }
}

XiangjiEvidenceType? tryParseXiangjiEvidenceType(Object? raw) {
  final value = (raw ?? '').toString();
  for (final type in XiangjiEvidenceType.values) {
    if (type.value == value) return type;
  }
  return null;
}

extension XiangjiCalibrationResultX on XiangjiCalibrationResult {
  String get value {
    switch (this) {
      case XiangjiCalibrationResult.continueGoal:
        return 'continue';
      case XiangjiCalibrationResult.changeMethod:
        return 'change_method';
      case XiangjiCalibrationResult.reduceScope:
        return 'reduce_scope';
      case XiangjiCalibrationResult.pause:
        return 'pause';
      case XiangjiCalibrationResult.reselect:
        return 'reselect';
    }
  }

  String get label {
    switch (this) {
      case XiangjiCalibrationResult.continueGoal:
        return '继续';
      case XiangjiCalibrationResult.changeMethod:
        return '改法';
      case XiangjiCalibrationResult.reduceScope:
        return '缩小';
      case XiangjiCalibrationResult.pause:
        return '暂停';
      case XiangjiCalibrationResult.reselect:
        return '重选';
    }
  }

  String get description {
    switch (this) {
      case XiangjiCalibrationResult.continueGoal:
        return '方向和方法仍然基本有效，继续当前节奏。';
      case XiangjiCalibrationResult.changeMethod:
        return '目标仍然重要，但当前方法没有得到足够支持。';
      case XiangjiCalibrationResult.reduceScope:
        return '方向保留，把当前阶段缩小到现实资源能够承受的范围。';
      case XiangjiCalibrationResult.pause:
        return '目标可以保留，但现在不必持续推进。';
      case XiangjiCalibrationResult.reselect:
        return '高层价值可能仍然重要，但这条具体路径已经不再适合。';
    }
  }
}

class XiangjiGoal {
  const XiangjiGoal({
    required this.id,
    required this.versionId,
    required this.state,
    required this.isActive,
    required this.originalText,
    required this.whyText,
    required this.higherValues,
    required this.successDefinition,
    required this.scopeText,
    required this.primaryThinkerId,
    required this.currentNodeId,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final int id;
  final int versionId;
  final XiangjiGoalState state;
  final bool isActive;
  final String originalText;
  final String whyText;
  final List<String> higherValues;
  final String successDefinition;
  final String scopeText;
  final String primaryThinkerId;
  final String currentNodeId;
  final int createdAtMs;
  final int updatedAtMs;

  factory XiangjiGoal.fromJoinedRow(Map<String, Object?> row) {
    return XiangjiGoal(
      id: _asInt(row['id']),
      versionId: _asInt(row['version_id'] ?? row['current_version_id']),
      state: parseXiangjiGoalState(row['status']),
      isActive: _asInt(row['is_active']) == 1,
      originalText: (row['original_text'] ?? '').toString(),
      whyText: (row['why_text'] ?? '').toString(),
      higherValues: _decodeStringList(row['higher_values_json']),
      successDefinition: (row['success_definition'] ?? '').toString(),
      scopeText: (row['scope_text'] ?? '').toString(),
      primaryThinkerId: (row['primary_thinker_id'] ?? '').toString(),
      currentNodeId: (row['current_node_id'] ?? '').toString(),
      createdAtMs: _asInt(row['created_at_ms']),
      updatedAtMs: _asInt(row['updated_at_ms']),
    );
  }
}

class XiangjiDailyStep {
  const XiangjiDailyStep({
    required this.id,
    required this.goalId,
    required this.goalVersionId,
    required this.actionText,
    required this.triggerContext,
    required this.minimumDone,
    required this.evidenceRule,
    required this.controllabilityReason,
    required this.smallerVariant,
    required this.sourceSystemId,
    required this.status,
    required this.createdAtMs,
  });

  final int id;
  final int goalId;
  final int goalVersionId;
  final String actionText;
  final String triggerContext;
  final String minimumDone;
  final String evidenceRule;
  final String controllabilityReason;
  final String smallerVariant;
  final String sourceSystemId;
  final String status;
  final int createdAtMs;

  factory XiangjiDailyStep.fromRow(Map<String, Object?> row) {
    return XiangjiDailyStep(
      id: _asInt(row['id']),
      goalId: _asInt(row['goal_id']),
      goalVersionId: _asInt(row['goal_version_id']),
      actionText: (row['action_text'] ?? '').toString(),
      triggerContext: (row['trigger_context'] ?? '').toString(),
      minimumDone: (row['minimum_done'] ?? '').toString(),
      evidenceRule: (row['evidence_rule'] ?? '').toString(),
      controllabilityReason:
          (row['controllability_reason'] ?? '').toString(),
      smallerVariant: (row['smaller_variant'] ?? '').toString(),
      sourceSystemId: (row['source_system_id'] ?? '').toString(),
      status: (row['status'] ?? 'ready').toString(),
      createdAtMs: _asInt(row['created_at_ms']),
    );
  }
}

class XiangjiGrowthEvidence {
  const XiangjiGrowthEvidence({
    required this.id,
    required this.goalId,
    required this.evidenceType,
    required this.userOriginalText,
    required this.summary,
    required this.confirmed,
    required this.createdAtMs,
  });

  final int id;
  final int goalId;
  final String evidenceType;
  final String userOriginalText;
  final String summary;
  final bool confirmed;
  final int createdAtMs;

  factory XiangjiGrowthEvidence.fromRow(Map<String, Object?> row) {
    return XiangjiGrowthEvidence(
      id: _asInt(row['id']),
      goalId: _asInt(row['goal_id']),
      evidenceType: (row['evidence_type'] ?? 'action').toString(),
      userOriginalText: (row['user_original_text'] ?? '').toString(),
      summary: (row['ai_summary'] ?? '').toString(),
      confirmed: row['confirmed_at_ms'] != null,
      createdAtMs: _asInt(row['created_at_ms']),
    );
  }
}

class XiangjiSourceCitation {
  const XiangjiSourceCitation({
    required this.evidenceId,
    required this.sourceId,
    required this.bookTitle,
    required this.author,
    required this.locator,
    required this.claim,
    required this.summary,
    required this.boundary,
    required this.contentType,
  });

  final String evidenceId;
  final String sourceId;
  final String bookTitle;
  final String author;
  final String locator;
  final String claim;
  final String summary;
  final String boundary;
  final String contentType;
}

class XiangjiGuidance {
  const XiangjiGuidance({
    required this.systemId,
    required this.mentorName,
    required this.mechanismId,
    required this.mechanismLabel,
    required this.coreJudgment,
    required this.selectionReason,
    required this.boundaryNote,
    required this.knowledgeView,
    required this.structureText,
    required this.detailText,
    required this.actionDerivation,
    required this.confidence,
    required this.sources,
  });

  final String systemId;
  final String mentorName;
  final String mechanismId;
  final String mechanismLabel;
  final String coreJudgment;
  final String selectionReason;
  final String boundaryNote;
  final String knowledgeView;
  final String structureText;
  final String detailText;
  final String actionDerivation;
  final double confidence;
  final List<XiangjiSourceCitation> sources;

  String textFor(XiangjiZoomMode mode) {
    switch (mode) {
      case XiangjiZoomMode.panorama:
        return knowledgeView;
      case XiangjiZoomMode.structure:
        return structureText;
      case XiangjiZoomMode.detail:
        return detailText;
      case XiangjiZoomMode.action:
        return actionDerivation;
      case XiangjiZoomMode.evidence:
        return sources.isEmpty
            ? '本地书库依据不足，已停止生成确定性观点。'
            : '以下内容只显示可回定位的书籍依据；应用建议不冒充作者原话。';
    }
  }
}

class XiangjiGoalDraft {
  const XiangjiGoalDraft({
    required this.originalText,
    required this.whyText,
    required this.higherValues,
    required this.successDefinition,
    required this.scopeText,
    required this.guidance,
    required this.step,
  });

  final String originalText;
  final String whyText;
  final List<String> higherValues;
  final String successDefinition;
  final String scopeText;
  final XiangjiGuidance guidance;
  final XiangjiDailyStep step;

  XiangjiGoalDraft copyWith({
    String? originalText,
    String? whyText,
    List<String>? higherValues,
    String? successDefinition,
    String? scopeText,
    XiangjiGuidance? guidance,
    XiangjiDailyStep? step,
  }) {
    return XiangjiGoalDraft(
      originalText: originalText ?? this.originalText,
      whyText: whyText ?? this.whyText,
      higherValues: higherValues ?? this.higherValues,
      successDefinition: successDefinition ?? this.successDefinition,
      scopeText: scopeText ?? this.scopeText,
      guidance: guidance ?? this.guidance,
      step: step ?? this.step,
    );
  }
}

class XiangjiCalibrationDecision {
  const XiangjiCalibrationDecision({
    required this.valueAssessment,
    required this.goalAssessment,
    required this.methodAssessment,
    required this.actionAssessment,
    required this.result,
    required this.retainedValues,
  });

  final String valueAssessment;
  final String goalAssessment;
  final String methodAssessment;
  final String actionAssessment;
  final XiangjiCalibrationResult result;
  final List<String> retainedValues;
}

class XiangjiReminderSettings {
  const XiangjiReminderSettings({
    required this.enabled,
    required this.timeOfDay,
    required this.quietStart,
    required this.quietEnd,
    required this.taskUid,
  });

  final bool enabled;
  final String timeOfDay;
  final String quietStart;
  final String quietEnd;
  final String taskUid;

  factory XiangjiReminderSettings.defaults() {
    return const XiangjiReminderSettings(
      enabled: false,
      timeOfDay: '09:00',
      quietStart: '22:00',
      quietEnd: '08:00',
      taskUid: '',
    );
  }

  XiangjiReminderSettings copyWith({
    bool? enabled,
    String? timeOfDay,
    String? quietStart,
    String? quietEnd,
    String? taskUid,
  }) {
    return XiangjiReminderSettings(
      enabled: enabled ?? this.enabled,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
      taskUid: taskUid ?? this.taskUid,
    );
  }
}

class XiangjiScheduledReminder {
  const XiangjiScheduledReminder({
    required this.deliveryKey,
    required this.goalId,
    required this.contentType,
    required this.body,
  });

  final String deliveryKey;
  final int goalId;
  final String contentType;
  final String body;
}

class XiangjiBookInfo {
  const XiangjiBookInfo({
    required this.id,
    required this.title,
    required this.author,
    required this.edition,
    required this.sourceStatus,
    required this.builtIn,
    this.localPath = '',
    this.contentHash = '',
    this.parseStatus = '',
    this.mimeType = '',
    this.sizeBytes = 0,
    this.parsedCharacters = 0,
    this.chunkCount = 0,
    this.parseError = '',
    this.providerMirror,
  });

  final String id;
  final String title;
  final String author;
  final String edition;
  final String sourceStatus;
  final bool builtIn;
  final String localPath;
  final String contentHash;
  final String parseStatus;
  final String mimeType;
  final int sizeBytes;
  final int parsedCharacters;
  final int chunkCount;
  final String parseError;
  final XiangjiProviderMirror? providerMirror;

  bool get isLocallySearchable =>
      !builtIn &&
      (parseStatus == 'ready' || parseStatus == 'partial') &&
      chunkCount > 0;
}

class XiangjiBookChunk {
  const XiangjiBookChunk({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.chunkIndex,
    required this.sectionTitle,
    required this.locator,
    required this.text,
    required this.contentHash,
    this.relevanceScore = 0,
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final int chunkIndex;
  final String sectionTitle;
  final String locator;
  final String text;
  final String contentHash;
  final double relevanceScore;

  XiangjiBookChunk copyWith({double? relevanceScore}) => XiangjiBookChunk(
        id: id,
        bookId: bookId,
        bookTitle: bookTitle,
        chunkIndex: chunkIndex,
        sectionTitle: sectionTitle,
        locator: locator,
        text: text,
        contentHash: contentHash,
        relevanceScore: relevanceScore ?? this.relevanceScore,
      );
}

class XiangjiProviderMirror {
  const XiangjiProviderMirror({
    required this.bookId,
    required this.provider,
    required this.providerFileId,
    required this.providerIndexId,
    required this.syncedHash,
    required this.syncStatus,
    required this.indexedStatus,
    required this.consentedAtMs,
    required this.lastError,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String bookId;
  final String provider;
  final String providerFileId;
  final String providerIndexId;
  final String syncedHash;
  final String syncStatus;
  final String indexedStatus;
  final int consentedAtMs;
  final String lastError;
  final int createdAtMs;
  final int updatedAtMs;

  bool get hasRemoteResources =>
      providerFileId.isNotEmpty || providerIndexId.isNotEmpty;

  bool isReadyFor(String contentHash) =>
      syncStatus == 'ready' &&
      indexedStatus == 'ready' &&
      syncedHash.isNotEmpty &&
      syncedHash == contentHash;

  XiangjiProviderMirror copyWith({
    String? providerFileId,
    String? providerIndexId,
    String? syncedHash,
    String? syncStatus,
    String? indexedStatus,
    int? consentedAtMs,
    String? lastError,
    int? createdAtMs,
    int? updatedAtMs,
  }) =>
      XiangjiProviderMirror(
        bookId: bookId,
        provider: provider,
        providerFileId: providerFileId ?? this.providerFileId,
        providerIndexId: providerIndexId ?? this.providerIndexId,
        syncedHash: syncedHash ?? this.syncedHash,
        syncStatus: syncStatus ?? this.syncStatus,
        indexedStatus: indexedStatus ?? this.indexedStatus,
        consentedAtMs: consentedAtMs ?? this.consentedAtMs,
        lastError: lastError ?? this.lastError,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );
}

class XiangjiMentorKnowledgeMigration {
  const XiangjiMentorKnowledgeMigration({
    required this.id,
    required this.goalId,
    required this.fromThinkerId,
    required this.targetKnowledgeVersion,
    required this.status,
    required this.resolvedThinkerId,
    required this.detectedAtMs,
    required this.resolvedAtMs,
  });

  final int id;
  final int goalId;
  final String fromThinkerId;
  final String targetKnowledgeVersion;
  final String status;
  final String resolvedThinkerId;
  final int detectedAtMs;
  final int resolvedAtMs;

  bool get requiresReselection => status == 'reselection_required';

  factory XiangjiMentorKnowledgeMigration.fromRow(
    Map<String, Object?> row,
  ) {
    return XiangjiMentorKnowledgeMigration(
      id: _asInt(row['id']),
      goalId: _asInt(row['goal_id']),
      fromThinkerId: (row['from_thinker_id'] ?? '').toString(),
      targetKnowledgeVersion:
          (row['target_kb_version'] ?? '').toString(),
      status: (row['status'] ?? '').toString(),
      resolvedThinkerId: (row['resolved_thinker_id'] ?? '').toString(),
      detectedAtMs: _asInt(row['detected_at_ms']),
      resolvedAtMs: _asInt(row['resolved_at_ms']),
    );
  }
}

class XiangjiGroundedCitation {
  const XiangjiGroundedCitation({
    required this.sourceId,
    required this.bookId,
    required this.bookTitle,
    required this.locator,
    required this.excerpt,
  });

  final String sourceId;
  final String bookId;
  final String bookTitle;
  final String locator;
  final String excerpt;
}

class XiangjiGroundedAnswer {
  const XiangjiGroundedAnswer({
    required this.text,
    required this.boundary,
    required this.contentType,
    required this.citations,
    required this.sourceMode,
    required this.provider,
    required this.modelLabel,
  });

  final String text;
  final String boundary;
  final String contentType;
  final List<XiangjiGroundedCitation> citations;
  final String sourceMode;
  final String provider;
  final String modelLabel;
}

int _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse((value ?? '0').toString()) ?? 0;
}

List<String> _decodeStringList(Object? raw) {
  if (raw == null) return const <String>[];
  try {
    final decoded = jsonDecode(raw.toString());
    if (decoded is List) {
      return decoded
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
  } catch (_) {}
  return const <String>[];
}
