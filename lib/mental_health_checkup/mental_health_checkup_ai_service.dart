import 'dart:convert';

import '../data/kv_dao.dart';
import '../services/unified_ai_service.dart';
import 'mental_health_content_governance.dart';
import 'mental_health_indicator_governance.dart';
import 'mental_health_knowledge_models.dart';
import 'mental_health_checkup_models.dart';
import 'mental_health_checkup_repository.dart';

class MentalHealthCheckupPromptConfig {
  static const String moduleId = 'mental_health_checkup';
  static const String globalId = 'global';
  static const String contentCandidateId = 'content_candidate';
  static const String indicatorCandidateId = 'indicator_candidate';

  static const Map<String, String> labels = <String, String>{
    globalId: '课程生成全局安全 Prompt',
    contentCandidateId: '题目与B0—B4候选生成 Prompt',
    indicatorCandidateId: '候选指标发现 Prompt',
  };

  static const String defaultGlobalPrompt = r'''
你是“哈佛幸福课23讲心理健康体检”的课程内容治理助手。你只能处理课程证据、指标本体和已批准的内容设计规则，不能接收或推断任何用户的回答、报告、行动记录、复验记录、安装标识或当地支持号码。

必须遵守：
1. 本系统不是医学疾病诊断，不是真实医疗处方，不提供药物建议，不承诺治愈。
2. 只能生成课程候选指标、候选题目和候选任务；AI不能发布、签发或改变正式内容。
3. “课程处方”只指课程中已有依据的练习、行动、生活仪式和反思任务。
4. C1是课程直接内容，C2是课程机制推导，D1是产品测量/剂量参数，D2是安全与功能分流。不得混淆。
5. 必须同时保留支持证据、冲突证据和至少两种替代解释。
6. 不得要求或处理个人体检结果；报告和复验解释必须由本机规则完成。
7. 风险型内容不得让用户练习风险行为，不得用积极练习覆盖风险。
8. 语言温和、具体、不羞辱、不贴永久人格标签；每次最多建议一个当前行动。
''';

  static const String defaultContentCandidatePrompt = r'''
请只根据 {{context_json}} 生成一个课程内容候选。不得引入外部量表、医学诊断、治疗建议或课程证据中不存在的结论；证据不足时必须返回 evidence_insufficient=true。候选只进入草稿，不得输出发布状态、审核人或正式版本。

只输出一个JSON对象，字段必须为：
{
  "evidence_insufficient": false,
  "content": "单一构念的题干或任务",
  "scale_or_duration": "量尺或期限",
  "scoring_direction": "计分方向",
  "recall_window": "明确时间窗",
  "answer_options": [],
  "correct_answer_index": null,
  "source_level": "C1候选直接证据或C2课程机制推导",
  "construct_rationale": "为什么只测primary_indicator_id",
  "safety_rule": "停止、减量或安全分流规则",
  "smaller_version": "B1-B4的更小版本，题目可为空",
  "counter_evidence_prompt": "B2/B4的反证或迁移证据，其他可为空",
  "quality_suggestion": {
    "indicator_consistency": 0,
    "course_fidelity": 0,
    "non_duplication": 0,
    "measurability": 0,
    "scale_window_fit": 0,
    "bidirectional_logic": 0,
    "safety": 0
  }
}

硬规则：
1. primary_indicator_id必须保持不变，一项内容只测一个构念。
2. A3必须写明7/14/30天；A7必须提供至少3个选项和唯一正确答案；A8要求具体事件、行为、结果、支持与冲突证据。
3. B0只观察不要求改变；B1必须有更小版本；B2必须保留反证；B3一次只建立1—2项仪式；B4必须有跨情境证据和复发预案。
4. 风险型指标不得让用户练习风险行为。
5. 质量分只是AI建议，不能代替独立审核、认知访谈、试测和人工签发。
''';

  static const String defaultIndicatorCandidatePrompt = r'''
请只根据 {{context_json}} 发现一个新的课程候选指标。候选必须围绕课程证据中的单一构念，不能复制existing_indicators，不能引入外部量表、医学诊断或课程材料没有支持的结论。证据不足或没有真正新增价值时必须返回evidence_insufficient=true。

只输出一个JSON对象：
{
  "evidence_insufficient": false,
  "name": "简洁候选指标名称",
  "indicator_type": "保护型|风险型|平衡型|功能结果|哨兵型",
  "definition": "单一构念定义",
  "low_pattern": "低端或不足表现",
  "high_pattern": "高端表现及适用边界",
  "misuse_risk": "僵化、高端误用或过度化风险",
  "functional_signal": "学习、工作、关系或自我照护中的可观察表现",
  "definition_location": "课程location_id",
  "low_location": "课程location_id",
  "high_location": "课程location_id",
  "action_location": "课程location_id",
  "evidence_location_ids": [],
  "guardrail_indicator_ids": [],
  "possible_duplicate_indicator_ids": [],
  "source_level": "C1候选直接证据或C2课程机制推导",
  "construct_rationale": "为何是单一且不同于现有指标的构念",
  "safety_boundary": "不得越过的解释和使用边界",
  "quality_suggestion": {
    "course_evidence_fit": 0,
    "construct_clarity": 0,
    "non_duplication": 0,
    "measurability": 0,
    "bidirectional_balance": 0,
    "actionability": 0,
    "safety": 0
  }
}

AI只能生成草稿，不能决定proposed_indicator_id、审核、试测或正式签发。质量分只是建议，课程证据适配必须由独立审核人和课程专家重新评分。
''';

  final KeyValueDao _kv;

  MentalHealthCheckupPromptConfig({KeyValueDao? keyValueDao})
      : _kv = keyValueDao ?? KeyValueDao();

  static String _key(String id) => 'ai_prompt.$moduleId.$id';

  String defaultFor(String id) {
    switch (id) {
      case contentCandidateId:
        return defaultContentCandidatePrompt;
      case indicatorCandidateId:
        return defaultIndicatorCandidatePrompt;
      case globalId:
      default:
        return defaultGlobalPrompt;
    }
  }

  Future<String> getPrompt(String id) async {
    final value = (await _kv.getString(_key(id)))?.trim() ?? '';
    return value.isEmpty ? defaultFor(id) : value;
  }

  Future<void> savePrompt(String id, String value) async {
    final normalized = value.trim();
    await _kv.setString(
      _key(id),
      normalized.isEmpty ? defaultFor(id) : normalized,
    );
  }

  Future<void> resetPrompt(String id) =>
      _kv.setString(_key(id), defaultFor(id));

  Future<String> buildContentCandidatePrompt(
    Map<String, Object?> context,
  ) async {
    final template = await getPrompt(contentCandidateId);
    return template.replaceAll('{{context_json}}', jsonEncode(context));
  }

  Future<String> buildIndicatorCandidatePrompt(
    Map<String, Object?> context,
  ) async {
    final template = await getPrompt(indicatorCandidateId);
    return template.replaceAll('{{context_json}}', jsonEncode(context));
  }
}

class MentalHealthCheckupAiService {
  final UnifiedAiService _ai;
  final MentalHealthCheckupPromptConfig prompts;

  MentalHealthCheckupAiService({
    UnifiedAiService? ai,
    MentalHealthCheckupPromptConfig? promptConfig,
  })  : _ai = ai ?? UnifiedAiService(),
        prompts = promptConfig ?? MentalHealthCheckupPromptConfig();

  Future<MentalHealthContentCandidateResult> generateContentCandidate({
    required CheckupContentGenerationPlan plan,
    required String contentCode,
    required String courseVersion,
    required List<CheckupEvidenceTrace> evidenceTraces,
    CheckupProviderKnowledgeResource? knowledgeResource,
  }) async {
    const governance = MentalHealthContentGovernanceEngine();
    final fallback = governance.createLocalDraft(
      plan: plan,
      contentCode: contentCode,
      courseVersion: courseVersion,
    );
    final evidence = evidenceTraces
        .where((trace) => trace.indicatorId == plan.indicatorId)
        .take(8)
        .map((trace) => trace.toJson())
        .toList(growable: false);
    final context = <String, Object?>{
      'generation_plan': plan.toJson(),
      'target_content_code': contentCode,
      'course_evidence': evidence,
      'fixed_governance': const <String, Object?>{
        'candidate_stage': 'draft',
        'ai_may_publish': false,
        'human_gates': <String>['课程证据与单一构念独立审核', '认知访谈', '小样本试测', '人工签发'],
      },
      'privacy_exclusions': const <String>[
        '用户回答',
        '历史报告',
        '行动执行记录',
        '安装标识',
        '当地支持号码',
      ],
    };
    try {
      final prompt = await prompts.buildContentCandidatePrompt(context);
      final systemPrompt = await prompts.getPrompt(
        MentalHealthCheckupPromptConfig.globalId,
      );
      final raw = await _generateGovernedJson(
        prompt: prompt,
        purpose: 'mental_health_checkup.content_candidate',
        systemPrompt: systemPrompt,
        maxTokens: 2200,
        temperature: 0.15,
        knowledgeResource: knowledgeResource,
      );
      final decoded = _decodeJsonObject(raw);
      if (decoded['evidence_insufficient'] == true) {
        return MentalHealthContentCandidateResult(
          candidate: fallback,
          usedAi: false,
          message: 'AI判断课程证据不足，已保留本地草稿并阻止进入候选阶段。',
        );
      }
      final qualityRow = Map<String, dynamic>.from(
        decoded['quality_suggestion'] as Map? ?? const <String, dynamic>{},
      );
      final suggested = CheckupCandidateQuality.fromJson(qualityRow);
      final generatedOptions = _aiStringList(decoded['answer_options']);
      final candidate = fallback.copyWith(
        content: (decoded['content'] ?? fallback.content).toString(),
        scaleOrDuration:
            (decoded['scale_or_duration'] ?? fallback.scaleOrDuration)
                .toString(),
        scoringDirection:
            (decoded['scoring_direction'] ?? fallback.scoringDirection)
                .toString(),
        recallWindow:
            (decoded['recall_window'] ?? fallback.recallWindow).toString(),
        answerOptions: generatedOptions.isEmpty
            ? fallback.answerOptions
            : generatedOptions,
        correctAnswerIndex: (decoded['correct_answer_index'] as num?)?.toInt(),
        sourceLevel:
            (decoded['source_level'] ?? fallback.sourceLevel).toString(),
        constructRationale:
            (decoded['construct_rationale'] ?? fallback.constructRationale)
                .toString(),
        safetyRule: (decoded['safety_rule'] ?? fallback.safetyRule).toString(),
        smallerVersion:
            (decoded['smaller_version'] ?? fallback.smallerVersion).toString(),
        counterEvidencePrompt: (decoded['counter_evidence_prompt'] ??
                fallback.counterEvidencePrompt)
            .toString(),
        quality: suggested.copyWith(
          courseFidelity: suggested.courseFidelity.clamp(0, 79).toDouble(),
        ),
        author: 'AI候选',
        modelVersion: 'user-configured-provider',
      );
      final validation = governance.validate(candidate);
      return MentalHealthContentCandidateResult(
        candidate: candidate,
        usedAi: true,
        message: validation.valid
            ? 'AI候选已生成；仍需独立审核、访谈、试测与人工签发。'
            : 'AI候选已生成，但仍有${validation.blockingIssues.length}项发布门槛未满足。',
      );
    } catch (_) {
      return MentalHealthContentCandidateResult(
        candidate: fallback,
        usedAi: false,
        message: 'AI不可用或返回格式无效，已创建完全离线的本地草稿。',
      );
    }
  }

  Future<MentalHealthIndicatorCandidateResult> generateIndicatorCandidate({
    required int lecture,
    required String area,
    required String courseVersion,
    required List<CheckupEvidenceTrace> evidenceTraces,
    required List<CheckupIndicator> existingIndicators,
    CheckupProviderKnowledgeResource? knowledgeResource,
  }) async {
    const governance = MentalHealthIndicatorGovernanceEngine();
    final locationIds = evidenceTraces
        .where((trace) => trace.lecture == lecture)
        .map((trace) => trace.locationId)
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .take(12)
        .toList(growable: false);
    final fallback = governance.createLocalDraft(
      lecture: lecture,
      area: area,
      courseVersion: courseVersion,
      evidenceLocationIds: locationIds,
      existingIndicatorIds: existingIndicators
          .where((indicator) => indicator.lecture == lecture)
          .map((indicator) => indicator.id)
          .toList(growable: false),
    );
    final context = <String, Object?>{
      'target_lecture': lecture,
      'target_area': area,
      'course_evidence': evidenceTraces
          .where((trace) => trace.lecture == lecture)
          .take(24)
          .map((trace) => trace.toJson())
          .toList(growable: false),
      'existing_indicators': existingIndicators
          .where((indicator) => indicator.lecture == lecture)
          .map(
            (indicator) => <String, Object?>{
              'indicator_id': indicator.id,
              'name': indicator.name,
              'type': indicator.type,
              'area': indicator.area,
              'definition_location': indicator.definitionLocation,
            },
          )
          .toList(growable: false),
      'fixed_governance': const <String, Object?>{
        'candidate_stage': 'draft',
        'ai_may_assign_id': false,
        'ai_may_publish': false,
        'human_gates': <String>[
          '课程证据审核',
          '单一构念与去重审核',
          '课程专家审核',
          '目标用户认知访谈',
          '小样本试测',
          '人工签发',
        ],
      },
      'privacy_exclusions': const <String>[
        '用户回答',
        '历史报告',
        '行动执行记录',
        '安装标识',
        '当地支持号码',
      ],
    };
    try {
      final prompt = await prompts.buildIndicatorCandidatePrompt(context);
      final systemPrompt = await prompts.getPrompt(
        MentalHealthCheckupPromptConfig.globalId,
      );
      final raw = await _generateGovernedJson(
        prompt: prompt,
        purpose: 'mental_health_checkup.indicator_candidate',
        systemPrompt: systemPrompt,
        maxTokens: 2600,
        temperature: 0.1,
        knowledgeResource: knowledgeResource,
      );
      final decoded = _decodeJsonObject(raw);
      if (decoded['evidence_insufficient'] == true) {
        return MentalHealthIndicatorCandidateResult(
          candidate: fallback,
          usedAi: false,
          message: 'AI没有发现证据充分且不重复的新指标，已保留本地治理草稿。',
        );
      }
      final quality = CheckupIndicatorCandidateQuality.fromJson(
        Map<String, dynamic>.from(
          decoded['quality_suggestion'] as Map? ?? const <String, dynamic>{},
        ),
      );
      final proposedLocations = _aiStringList(decoded['evidence_location_ids']);
      final knownLocations =
          evidenceTraces.map((trace) => trace.locationId).toSet();
      final proposedType =
          (decoded['indicator_type'] ?? fallback.indicatorType).toString();
      final proposedSource =
          (decoded['source_level'] ?? fallback.sourceLevel).toString();
      final safeLocations = proposedLocations
          .where(knownLocations.contains)
          .toSet()
          .toList(growable: false);
      String safeLocation(String key, String fallbackValue) {
        final proposed = (decoded[key] ?? '').toString();
        return knownLocations.contains(proposed) ? proposed : fallbackValue;
      }

      final definitionLocation = safeLocation(
        'definition_location',
        fallback.definitionLocation,
      );
      final lowLocation = safeLocation('low_location', fallback.lowLocation);
      final highLocation = safeLocation('high_location', fallback.highLocation);
      final actionLocation = safeLocation(
        'action_location',
        fallback.actionLocation,
      );
      final candidateEvidenceIds = <String>{
        ...(safeLocations.isEmpty
            ? fallback.evidenceLocationIds
            : safeLocations),
        definitionLocation,
        lowLocation,
        highLocation,
        actionLocation,
      }..removeWhere((value) => value.trim().isEmpty);

      final candidate = fallback.copyWith(
        name: (decoded['name'] ?? fallback.name).toString(),
        indicatorType:
            MentalHealthIndicatorGovernanceEngine.supportedTypes.contains(
          proposedType,
        )
                ? proposedType
                : fallback.indicatorType,
        definition: (decoded['definition'] ?? fallback.definition).toString(),
        lowPattern: (decoded['low_pattern'] ?? fallback.lowPattern).toString(),
        highPattern:
            (decoded['high_pattern'] ?? fallback.highPattern).toString(),
        misuseRisk: (decoded['misuse_risk'] ?? fallback.misuseRisk).toString(),
        functionalSignal:
            (decoded['functional_signal'] ?? fallback.functionalSignal)
                .toString(),
        definitionLocation: definitionLocation,
        lowLocation: lowLocation,
        highLocation: highLocation,
        actionLocation: actionLocation,
        evidenceLocationIds: candidateEvidenceIds.toList(growable: false),
        guardrailIndicatorIds: _onlyExistingIndicatorIds(
          decoded['guardrail_indicator_ids'],
          existingIndicators,
        ),
        possibleDuplicateIndicatorIds: _onlyExistingIndicatorIds(
          decoded['possible_duplicate_indicator_ids'],
          existingIndicators,
        ),
        sourceLevel:
            proposedSource == 'C1候选直接证据' || proposedSource == 'C2课程机制推导'
                ? proposedSource
                : fallback.sourceLevel,
        constructRationale:
            (decoded['construct_rationale'] ?? fallback.constructRationale)
                .toString(),
        safetyBoundary:
            (decoded['safety_boundary'] ?? fallback.safetyBoundary).toString(),
        quality: quality.copyWith(
          courseEvidenceFit: quality.courseEvidenceFit.clamp(0, 79).toDouble(),
        ),
        author: 'AI候选',
        modelVersion: 'user-configured-provider',
      );
      final validation = governance.validate(
        candidate,
        existingIndicators: existingIndicators,
      );
      return MentalHealthIndicatorCandidateResult(
        candidate: candidate,
        usedAi: true,
        message: validation.valid
            ? 'AI候选指标草稿已生成；仍需全部人工门禁。'
            : 'AI候选指标已生成，但有'
                '${validation.blockingIssues.length}项门槛未满足。',
      );
    } catch (_) {
      return MentalHealthIndicatorCandidateResult(
        candidate: fallback,
        usedAi: false,
        message: 'AI不可用或返回格式无效，已创建本地候选指标治理草稿。',
      );
    }
  }

  Future<String> _generateGovernedJson({
    required String prompt,
    required String purpose,
    required String systemPrompt,
    required int maxTokens,
    required double temperature,
    CheckupProviderKnowledgeResource? knowledgeResource,
  }) {
    if (knowledgeResource != null && knowledgeResource.ready) {
      return _ai.generateTextWithFile(
        prompt: prompt,
        purpose: purpose,
        provider: knowledgeResource.provider,
        fileId: knowledgeResource.providerFileId,
        fileName: knowledgeResource.fileName,
        systemPrompt: systemPrompt,
        maxTokens: maxTokens,
        expectJson: true,
        temperature: temperature,
      );
    }
    return _ai.generateText(
      prompt: prompt,
      purpose: purpose,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
      expectJson: true,
      temperature: temperature,
    );
  }
}

class MentalHealthContentCandidateResult {
  final CheckupContentCandidate candidate;
  final bool usedAi;
  final String message;

  const MentalHealthContentCandidateResult({
    required this.candidate,
    required this.usedAi,
    required this.message,
  });
}

class MentalHealthIndicatorCandidateResult {
  final CheckupIndicatorCandidate candidate;
  final bool usedAi;
  final String message;

  const MentalHealthIndicatorCandidateResult({
    required this.candidate,
    required this.usedAi,
    required this.message,
  });
}

Map<String, dynamic> _decodeJsonObject(String raw) {
  var value = raw.trim();
  if (value.startsWith('```')) {
    value = value.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
    value = value.replaceFirst(RegExp(r'\s*```$'), '');
  }
  final decoded = jsonDecode(value);
  if (decoded is! Map) throw const FormatException('AI候选不是JSON对象');
  return Map<String, dynamic>.from(decoded);
}

List<String> _aiStringList(Object? value) =>
    (value as List? ?? const <Object?>[])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);

List<String> _onlyExistingIndicatorIds(
  Object? value,
  Iterable<CheckupIndicator> indicators,
) {
  final known = indicators.map((indicator) => indicator.id).toSet();
  return _aiStringList(
    value,
  ).where(known.contains).toSet().toList(growable: false);
}
