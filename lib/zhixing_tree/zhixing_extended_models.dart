import 'dart:convert';

/// Reviewed package content and AI-derived content deliberately use separate
/// origins. AI-derived records can be selected, but never mutate the local
/// reviewed package.
enum ZxKnowledgeOrigin { localReviewed, aiDerived }

extension ZxKnowledgeOriginX on ZxKnowledgeOrigin {
  String get key =>
      this == ZxKnowledgeOrigin.localReviewed ? 'local_reviewed' : 'ai_derived';

  String get label =>
      this == ZxKnowledgeOrigin.localReviewed ? '本地审核知识库' : 'AI派生知识';

  static ZxKnowledgeOrigin parse(Object? raw) =>
      raw?.toString() == 'ai_derived'
          ? ZxKnowledgeOrigin.aiDerived
          : ZxKnowledgeOrigin.localReviewed;
}

class ZxAiBook {
  const ZxAiBook({
    this.id = 0,
    required this.thinker,
    required this.title,
    required this.fileName,
    required this.localPath,
    required this.mimeType,
    required this.byteSize,
    required this.sha256,
    this.extractedCharacters = 0,
    this.createdAtMs = 0,
  });

  final int id;
  final String thinker;
  final String title;
  final String fileName;
  final String localPath;
  final String mimeType;
  final int byteSize;
  final String sha256;
  final int extractedCharacters;
  final int createdAtMs;

  Map<String, Object?> toMap() => <String, Object?>{
        'thinker': thinker,
        'title': title,
        'file_name': fileName,
        'local_path': localPath,
        'mime_type': mimeType,
        'byte_size': byteSize,
        'sha256': sha256,
        'extracted_characters': extractedCharacters,
        'created_at_ms': createdAtMs,
      };

  factory ZxAiBook.fromMap(Map<String, Object?> row) => ZxAiBook(
        id: _int(row['id']),
        thinker: (row['thinker'] ?? '').toString(),
        title: (row['title'] ?? '').toString(),
        fileName: (row['file_name'] ?? '').toString(),
        localPath: (row['local_path'] ?? '').toString(),
        mimeType: (row['mime_type'] ?? '').toString(),
        byteSize: _int(row['byte_size']),
        sha256: (row['sha256'] ?? '').toString(),
        extractedCharacters: _int(row['extracted_characters']),
        createdAtMs: _int(row['created_at_ms']),
      );
}

class ZxAiKnowledgeDraft {
  const ZxAiKnowledgeDraft({
    this.id = 0,
    required this.thinker,
    required this.title,
    required this.bookIds,
    required this.coreValues,
    required this.coreIdeas,
    required this.knowledgeView,
    required this.actionView,
    required this.transformationPath,
    required this.decisionCue,
    required this.yangmingConnection,
    required this.commonGround,
    required this.differences,
    required this.boundaries,
    required this.provider,
    required this.modelLabel,
    this.sourceMode = 'local_upload',
    this.status = 'saved',
    this.createdAtMs = 0,
  });

  final int id;
  final String thinker;
  final String title;
  final List<int> bookIds;
  final List<String> coreValues;
  final List<String> coreIdeas;
  final String knowledgeView;
  final String actionView;
  final String transformationPath;
  final String decisionCue;
  final String yangmingConnection;
  final List<String> commonGround;
  final List<String> differences;
  final List<String> boundaries;
  final String provider;
  final String modelLabel;
  /// `remote_knowledge` means generation was grounded through saved provider
  /// resource IDs, not by re-sending the local file content.
  final String sourceMode;
  final String status;
  final int createdAtMs;

  ZxKnowledgeOrigin get origin => ZxKnowledgeOrigin.aiDerived;

  bool get usesRemoteKnowledge => sourceMode == 'remote_knowledge';

  Map<String, Object?> toMap() => <String, Object?>{
        'origin': origin.key,
        'thinker': thinker,
        'title': title,
        'book_ids_json': jsonEncode(bookIds),
        'core_values_json': jsonEncode(coreValues),
        'core_ideas_json': jsonEncode(coreIdeas),
        'knowledge_view': knowledgeView,
        'action_view': actionView,
        'transformation_path': transformationPath,
        'decision_cue': decisionCue,
        'yangming_connection': yangmingConnection,
        'common_ground_json': jsonEncode(commonGround),
        'differences_json': jsonEncode(differences),
        'boundaries_json': jsonEncode(boundaries),
        'provider': provider,
        'model_label': modelLabel,
        'source_mode': sourceMode,
        'status': status,
        'created_at_ms': createdAtMs,
      };

  factory ZxAiKnowledgeDraft.fromMap(Map<String, Object?> row) =>
      ZxAiKnowledgeDraft(
        id: _int(row['id']),
        thinker: (row['thinker'] ?? '').toString(),
        title: (row['title'] ?? '').toString(),
        bookIds: _intList(row['book_ids_json']),
        coreValues: _strings(row['core_values_json']),
        coreIdeas: _strings(row['core_ideas_json']),
        knowledgeView: (row['knowledge_view'] ?? '').toString(),
        actionView: (row['action_view'] ?? '').toString(),
        transformationPath: (row['transformation_path'] ?? '').toString(),
        decisionCue: (row['decision_cue'] ?? '').toString(),
        yangmingConnection: (row['yangming_connection'] ?? '').toString(),
        commonGround: _strings(row['common_ground_json']),
        differences: _strings(row['differences_json']),
        boundaries: _strings(row['boundaries_json']),
        provider: (row['provider'] ?? '').toString(),
        modelLabel: (row['model_label'] ?? '').toString(),
        sourceMode: (row['source_mode'] ?? 'local_upload').toString(),
        status: (row['status'] ?? 'saved').toString(),
        createdAtMs: _int(row['created_at_ms']),
      );

  factory ZxAiKnowledgeDraft.fromAiJson(
    Map<String, dynamic> map, {
    required String thinker,
    required List<int> bookIds,
    required String provider,
    required String modelLabel,
    String sourceMode = 'local_upload',
  }) {
    final values = _strings(map['core_values']);
    final ideas = _strings(map['core_ideas']);
    final common = _strings(map['common_ground']);
    final differences = _strings(map['differences']);
    final boundaries = _strings(map['boundaries']);
    if (values.length < 4 ||
        ideas.length < 8 ||
        common.isEmpty ||
        differences.isEmpty ||
        boundaries.isEmpty) {
      throw const FormatException(
        'AI输出不够完整：核心价值至少4条、核心思想至少8条，并需包含共同点、差异和边界。',
      );
    }
    String requiredText(String key) {
      final value = (map[key] ?? '').toString().trim();
      if (value.isEmpty) throw FormatException('AI输出缺少$key。');
      return value;
    }

    return ZxAiKnowledgeDraft(
      thinker: thinker.trim().isEmpty
          ? requiredText('thinker')
          : thinker.trim(),
      title: requiredText('title'),
      bookIds: bookIds,
      coreValues: values,
      coreIdeas: ideas,
      knowledgeView: requiredText('knowledge_view'),
      actionView: requiredText('action_view'),
      transformationPath: requiredText('transformation_path'),
      decisionCue: requiredText('decision_cue'),
      yangmingConnection: requiredText('yangming_connection'),
      commonGround: common,
      differences: differences,
      boundaries: boundaries,
      provider: provider,
      modelLabel: modelLabel,
      sourceMode: sourceMode,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

enum ZxReviewDecision { continueCurrent, switchThought, blendThoughts }

extension ZxReviewDecisionX on ZxReviewDecision {
  String get key {
    switch (this) {
      case ZxReviewDecision.switchThought:
        return 'switch';
      case ZxReviewDecision.blendThoughts:
        return 'blend';
      case ZxReviewDecision.continueCurrent:
        return 'continue';
    }
  }

  String get label {
    switch (this) {
      case ZxReviewDecision.switchThought:
        return '更换指导思想';
      case ZxReviewDecision.blendThoughts:
        return '融合互补思想';
      case ZxReviewDecision.continueCurrent:
        return '继续当前思想';
    }
  }

  static ZxReviewDecision parse(Object? raw) {
    switch (raw?.toString()) {
      case 'switch':
        return ZxReviewDecision.switchThought;
      case 'blend':
        return ZxReviewDecision.blendThoughts;
      default:
        return ZxReviewDecision.continueCurrent;
    }
  }
}

class ZxReviewReport {
  const ZxReviewReport({
    this.id = 0,
    required this.actionUid,
    required this.origin,
    this.knowledgeRefId = 0,
    required this.summary,
    required this.progressEvidence,
    required this.barrierFinding,
    required this.recommendedDecision,
    required this.currentSystemId,
    required this.recommendedSystemIds,
    required this.rationale,
    required this.nextAction,
    this.provider = '',
    this.modelLabel = '',
    this.createdAtMs = 0,
  });

  final int id;
  final String actionUid;
  final ZxKnowledgeOrigin origin;
  final int knowledgeRefId;
  final String summary;
  final String progressEvidence;
  final String barrierFinding;
  final ZxReviewDecision recommendedDecision;
  final String currentSystemId;
  final List<String> recommendedSystemIds;
  final String rationale;
  final String nextAction;
  final String provider;
  final String modelLabel;
  final int createdAtMs;

  Map<String, Object?> toMap() => <String, Object?>{
        'action_uid': actionUid,
        'origin': origin.key,
        'knowledge_ref_id': knowledgeRefId,
        'summary': summary,
        'progress_evidence': progressEvidence,
        'barrier_finding': barrierFinding,
        'recommended_decision': recommendedDecision.key,
        'current_system_id': currentSystemId,
        'recommended_system_ids_json': jsonEncode(recommendedSystemIds),
        'rationale': rationale,
        'next_action': nextAction,
        'provider': provider,
        'model_label': modelLabel,
        'created_at_ms': createdAtMs,
      };

  factory ZxReviewReport.fromMap(Map<String, Object?> row) => ZxReviewReport(
        id: _int(row['id']),
        actionUid: (row['action_uid'] ?? '').toString(),
        origin: ZxKnowledgeOriginX.parse(row['origin']),
        knowledgeRefId: _int(row['knowledge_ref_id']),
        summary: (row['summary'] ?? '').toString(),
        progressEvidence: (row['progress_evidence'] ?? '').toString(),
        barrierFinding: (row['barrier_finding'] ?? '').toString(),
        recommendedDecision:
            ZxReviewDecisionX.parse(row['recommended_decision']),
        currentSystemId: (row['current_system_id'] ?? '').toString(),
        recommendedSystemIds:
            _strings(row['recommended_system_ids_json']),
        rationale: (row['rationale'] ?? '').toString(),
        nextAction: (row['next_action'] ?? '').toString(),
        provider: (row['provider'] ?? '').toString(),
        modelLabel: (row['model_label'] ?? '').toString(),
        createdAtMs: _int(row['created_at_ms']),
      );
}

enum ZxGoalSource { zhixingLocal, todoGoalValue, microsoftTodo }

extension ZxGoalSourceX on ZxGoalSource {
  String get key {
    switch (this) {
      case ZxGoalSource.todoGoalValue:
        return 'todo_goal_value';
      case ZxGoalSource.microsoftTodo:
        return 'microsoft_todo';
      case ZxGoalSource.zhixingLocal:
        return 'zhixing_local';
    }
  }

  String get label {
    switch (this) {
      case ZxGoalSource.todoGoalValue:
        return 'Todo目标价值系统';
      case ZxGoalSource.microsoftTodo:
        return 'Microsoft To Do最近任务';
      case ZxGoalSource.zhixingLocal:
        return '知行树当前目标';
    }
  }
}

class ZxGoalCandidate {
  const ZxGoalCandidate({
    required this.source,
    required this.sourceId,
    required this.title,
    this.valueDirection = '',
    this.nextStep = '',
    this.dueLabel = '',
    this.updatedAtMs = 0,
  });

  final ZxGoalSource source;
  final String sourceId;
  final String title;
  final String valueDirection;
  final String nextStep;
  final String dueLabel;
  final int updatedAtMs;
}

class ZxAgentSettings {
  const ZxAgentSettings({
    this.enabled = false,
    this.hour = 9,
    this.minute = 0,
    this.reviewHour = 20,
    this.reviewMinute = 30,
    this.daysAhead = 7,
    this.updatedAtMs = 0,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final int reviewHour;
  final int reviewMinute;
  final int daysAhead;
  final int updatedAtMs;

  Map<String, Object?> toMap() => <String, Object?>{
        'singleton_id': 1,
        'enabled': enabled ? 1 : 0,
        'hour': hour,
        'minute': minute,
        'review_hour': reviewHour,
        'review_minute': reviewMinute,
        'days_ahead': daysAhead,
        'updated_at_ms': updatedAtMs,
      };

  factory ZxAgentSettings.fromMap(Map<String, Object?> row) =>
      ZxAgentSettings(
        enabled: _int(row['enabled']) == 1,
        hour: _int(row['hour'], 9),
        minute: _int(row['minute']),
        reviewHour: _int(row['review_hour'], 20),
        reviewMinute: _int(row['review_minute'], 30),
        daysAhead: _int(row['days_ahead'], 7),
        updatedAtMs: _int(row['updated_at_ms']),
      );
}

enum ZxAgentScene {
  setGoal,
  chooseThought,
  startAction,
  trackProgress,
  requestReview,
  continueCycle,
}

extension ZxAgentSceneX on ZxAgentScene {
  String get key => name;

  String get title {
    switch (this) {
      case ZxAgentScene.setGoal:
        return '设定一个目标';
      case ZxAgentScene.chooseThought:
        return '选择指导思想';
      case ZxAgentScene.startAction:
        return '开始今天的最小行动';
      case ZxAgentScene.trackProgress:
        return '跟进行动进度';
      case ZxAgentScene.requestReview:
        return '反馈行动结果';
      case ZxAgentScene.continueCycle:
        return '查看复盘并进入下一轮';
    }
  }

  static ZxAgentScene parse(String? raw) => ZxAgentScene.values.firstWhere(
        (item) => item.name == raw,
        orElse: () => ZxAgentScene.startAction,
      );
}

int _int(Object? raw, [int fallback = 0]) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

List<String> _strings(Object? raw) {
  if (raw is List) {
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (raw == null) return const <String>[];
  try {
    final decoded = jsonDecode(raw.toString());
    if (decoded is List) return _strings(decoded);
  } catch (_) {}
  return raw
      .toString()
      .split(RegExp(r'[\n;；|]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<int> _intList(Object? raw) {
  if (raw is List) {
    return raw
        .map((item) => item is num ? item.toInt() : int.tryParse('$item') ?? 0)
        .where((item) => item > 0)
        .toList(growable: false);
  }
  if (raw == null) return const <int>[];
  try {
    final decoded = jsonDecode(raw.toString());
    if (decoded is List) return _intList(decoded);
  } catch (_) {}
  return const <int>[];
}
