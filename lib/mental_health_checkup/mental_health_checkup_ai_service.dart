import 'dart:convert';

import '../data/kv_dao.dart';
import '../services/unified_ai_service.dart';
import 'mental_health_content_governance.dart';
import 'mental_health_checkup_catalog.dart';
import 'mental_health_checkup_models.dart';
import 'mental_health_checkup_repository.dart';
import 'mental_health_checkup_trends.dart';

class MentalHealthCheckupPromptConfig {
  static const String moduleId = 'mental_health_checkup';
  static const String globalId = 'global';
  static const String reportId = 'report';
  static const String retestId = 'retest';
  static const String contentCandidateId = 'content_candidate';

  static const Map<String, String> labels = <String, String>{
    globalId: '全局价值与安全 Prompt',
    reportId: '课程体检报告 Prompt',
    retestId: '复验与处方调整 Prompt',
    contentCandidateId: '题目与B0—B4候选生成 Prompt',
  };

  static const String defaultGlobalPrompt = r'''
你是“哈佛幸福课23讲心理健康体检”的课程型解释助手。你只能在应用已经计算完成的结构化结果上做解释和行动转化，不能修改分数、安全状态、证据等级、诊断候选、处方上限或复验规则。

必须遵守：
1. 本系统不是医学疾病诊断，不是真实医疗处方，不提供药物建议，不承诺治愈。
2. “课程型诊断”只表示最值得继续验证的课程机制假设；证据不足时必须明确说“候选假设”。
3. “课程处方”只指课程中已有依据的练习、行动、生活仪式和反思任务。
4. C1是课程直接内容，C2是课程机制推导，D1是产品测量/剂量参数，D2是安全与功能分流。不得混淆。
5. 必须同时保留支持证据、冲突证据和至少两种替代解释。
6. 不把高完成率直接当疗效；同时检查现实功能、过度化、疲劳、睡眠、关系和自主性。
7. 若 safety_status 不是 clear，只能重申应用的安全路线，不得生成普通课程任务，不得用积极练习覆盖风险。
8. 语言温和、具体、不羞辱、不贴永久人格标签；每次最多建议一个当前行动。
''';

  static const String defaultReportPrompt = r'''
请根据 {{context_json}} 生成一份便于用户理解的课程型体检解释。上下文可能包含当前报告、历史趋势、行动执行、复验、课程证据图谱和治理规则；缺失字段必须明确说证据不足，不能自行补造。严格使用以下结构：

【本轮能说明什么】说明模式、覆盖度、数据质量和结论强度。
【先看安全与功能】准确复述安全状态和现实功能影响。
【八域画像】解释最低的1-3个已覆盖领域，也指出至少一个保留能力或反证。
【当前优先验证的课程机制】区分确定事实、候选机制和替代解释。
【为什么不是人格判决】说明时间线、环境、身体基础和现实情境仍可能改变解释。
【一项课程行动处方】只能复述结构化结果中已经批准的处方；说明微量、疗程、证据位置和停止规则。
【如何判断有效】同时使用指标、现实功能、执行率、过度化和自主性。
【复验计划】说明何时复验以及继续、减量、暂停、换方或维持的条件。
【来源边界】逐项说明 C1/C2/D1/D2，不把课程机制说成医学结论。

只输出中文，不制造新量表、新阈值、新诊断或新处方。
''';

  static const String defaultRetestPrompt = r'''
请根据 {{context_json}} 解释本次复验。上下文可能包含基线、当前复验、历史复验、执行记录、课程证据与治理边界。先复述规则引擎给出的 decision 和 reason，再解释分数变化、现实功能、执行率和过度化风险之间的关系。不得推翻规则引擎决策；不得因为完成率高就宣告恢复；结尾只给一个最小下一步。
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

  final KeyValueDao _kv;

  MentalHealthCheckupPromptConfig({KeyValueDao? keyValueDao})
      : _kv = keyValueDao ?? KeyValueDao();

  static String _key(String id) => 'ai_prompt.$moduleId.$id';

  String defaultFor(String id) {
    switch (id) {
      case reportId:
        return defaultReportPrompt;
      case retestId:
        return defaultRetestPrompt;
      case contentCandidateId:
        return defaultContentCandidatePrompt;
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
    await _kv.setString(_key(id), normalized.isEmpty ? defaultFor(id) : normalized);
  }

  Future<void> resetPrompt(String id) =>
      _kv.setString(_key(id), defaultFor(id));

  Future<String> buildReportPrompt(
    CheckupReport report, {
    Map<String, Object?>? context,
  }) async {
    final template = await getPrompt(reportId);
    final reportJson = jsonEncode(report.toJson());
    final contextJson = jsonEncode(context ?? report.toJson());
    return template
        .replaceAll('{{context_json}}', contextJson)
        .replaceAll('{{report_json}}', reportJson);
  }

  Future<String> buildRetestPrompt(
    CheckupRetestRecord retest, {
    Map<String, Object?>? context,
  }) async {
    final template = await getPrompt(retestId);
    final retestJson = jsonEncode(retest.toJson());
    final contextJson = jsonEncode(context ?? retest.toJson());
    return template
        .replaceAll('{{context_json}}', contextJson)
        .replaceAll('{{retest_json}}', retestJson);
  }

  Future<String> buildContentCandidatePrompt(
    Map<String, Object?> context,
  ) async {
    final template = await getPrompt(contentCandidateId);
    return template.replaceAll('{{context_json}}', jsonEncode(context));
  }
}

class MentalHealthCheckupAiResult {
  final String text;
  final bool usedAi;

  const MentalHealthCheckupAiResult({
    required this.text,
    required this.usedAi,
  });
}

class MentalHealthCheckupAiService {
  final UnifiedAiService _ai;
  final MentalHealthCheckupPromptConfig prompts;

  MentalHealthCheckupAiService({
    UnifiedAiService? ai,
    MentalHealthCheckupPromptConfig? promptConfig,
  })  : _ai = ai ?? UnifiedAiService(),
        prompts = promptConfig ?? MentalHealthCheckupPromptConfig();

  Map<String, Object?> buildReportContext({
    required CheckupReport report,
    required MentalHealthCheckupState state,
    required MentalHealthCheckupCatalog catalog,
    List<CheckupEvidenceTrace> evidenceTraces =
        const <CheckupEvidenceTrace>[],
    bool includeHistory = true,
  }) {
    CheckupSession? sourceSession;
    for (final session in state.sessions) {
      if (session.report.id == report.id || session.id == report.sessionId) {
        sourceSession = session;
        break;
      }
    }
    final trends = includeHistory
        ? const MentalHealthCheckupTrendAnalyzer().analyze(state.sessions)
        : const <CheckupTrendInsight>[];
    return <String, Object?>{
      'context_version': '2.5-full-evidence-v1',
      'history_included': includeHistory,
      'current_report': report.toJson(),
      'current_assessment_plan': sourceSession?.assessmentPlan.toJson(),
      'current_answer_summary': sourceSession == null
          ? const <Object?>[]
          : sourceSession.answers
              .map(
                (answer) => <String, Object?>{
                  'question_id': answer.questionId,
                  'selected_label': answer.label,
                  'value': answer.value,
                  'response_duration_ms': answer.responseDurationMs,
                },
              )
              .toList(growable: false),
      'historical_reports': includeHistory
          ? state.sessions
              .where((session) => session.report.id != report.id)
              .take(8)
              .map(
                (session) => <String, Object?>{
                  'mode_id': session.modeId,
                  'completed_at_ms': session.completedAtMs,
                  'assessment_plan': session.assessmentPlan.toJson(),
                  'report': session.report.toJson(),
                },
              )
              .toList(growable: false)
          : const <Object?>[],
      'trend_insights': trends
          .map(
            (item) => <String, Object?>{
              'severity': item.severity.name,
              'title': item.title,
              'message': item.message,
            },
          )
          .toList(growable: false),
      'course_evidence_graph': evidenceTraces
          .map((trace) => trace.toJson())
          .toList(growable: false),
      'course_evidence_locations': report.courseEvidence,
      'plans_and_execution': includeHistory
          ? state.plans
              .take(5)
              .map((plan) => plan.toJson())
              .toList(growable: false)
          : const <Object?>[],
      'retests': includeHistory
          ? state.retests
              .take(10)
              .map((retest) => retest.toJson())
              .toList(growable: false)
          : const <Object?>[],
      'governance': catalog.governanceContext(),
      'privacy_exclusions': const <String>[
        'install_id',
        '当地危机支持号码',
        '当地紧急服务号码',
        '开放题原文',
      ],
    };
  }

  Map<String, Object?> buildRetestContext({
    required CheckupRetestRecord retest,
    required MentalHealthCheckupState state,
    required MentalHealthCheckupCatalog catalog,
    List<CheckupEvidenceTrace> evidenceTraces =
        const <CheckupEvidenceTrace>[],
    bool includeHistory = true,
  }) {
    CheckupReport? reportById(String id) {
      for (final session in state.sessions) {
        if (session.report.id == id) return session.report;
      }
      return null;
    }

    CheckupPrescriptionPlan? plan;
    for (final candidate in state.plans) {
      if (candidate.id == retest.planId) {
        plan = candidate;
        break;
      }
    }
    return <String, Object?>{
      'context_version': '2.5-full-evidence-v1',
      'history_included': includeHistory,
      'current_retest': retest.toJson(),
      'baseline_report': reportById(retest.baselineReportId)?.toJson(),
      'retest_report': reportById(retest.retestReportId)?.toJson(),
      'current_plan_and_execution': plan?.toJson(),
      'prior_retests': includeHistory
          ? state.retests
              .where((item) =>
                  item.planId == retest.planId && item.id != retest.id)
              .take(8)
              .map((item) => item.toJson())
              .toList(growable: false)
          : const <Object?>[],
      'course_evidence_graph': evidenceTraces
          .map((trace) => trace.toJson())
          .toList(growable: false),
      'governance': catalog.governanceContext(),
      'privacy_exclusions': const <String>[
        'install_id',
        '当地危机支持号码',
        '当地紧急服务号码',
        '开放题原文',
      ],
    };
  }

  Future<MentalHealthCheckupAiResult> explainReport(
    CheckupReport report, {
    required String fallback,
    MentalHealthCheckupState state = const MentalHealthCheckupState(),
    MentalHealthCheckupCatalog? catalog,
    List<CheckupEvidenceTrace> evidenceTraces =
        const <CheckupEvidenceTrace>[],
    bool includeHistory = false,
  }) async {
    if (!report.safetyClear) {
      return MentalHealthCheckupAiResult(text: fallback, usedAi: false);
    }
    try {
      final context = catalog == null
          ? <String, Object?>{'current_report': report.toJson()}
          : buildReportContext(
              report: report,
              state: state,
              catalog: catalog,
              evidenceTraces: evidenceTraces,
              includeHistory: includeHistory,
            );
      final prompt =
          await prompts.buildReportPrompt(report, context: context);
      final systemPrompt = await prompts.getPrompt(
        MentalHealthCheckupPromptConfig.globalId,
      );
      final value = await _ai.generateText(
        prompt: prompt,
        purpose: 'mental_health_checkup.explain_report',
        systemPrompt: systemPrompt,
        maxTokens: 3000,
        expectJson: false,
        temperature: 0.2,
      );
      if (value.trim().isNotEmpty) {
        return MentalHealthCheckupAiResult(
          text: value.trim(),
          usedAi: true,
        );
      }
    } catch (_) {}
    return MentalHealthCheckupAiResult(text: fallback, usedAi: false);
  }

  Future<MentalHealthCheckupAiResult> explainRetest(
    CheckupRetestRecord retest, {
    required String fallback,
    MentalHealthCheckupState state = const MentalHealthCheckupState(),
    MentalHealthCheckupCatalog? catalog,
    List<CheckupEvidenceTrace> evidenceTraces =
        const <CheckupEvidenceTrace>[],
    bool includeHistory = false,
  }) async {
    try {
      final context = catalog == null
          ? <String, Object?>{'current_retest': retest.toJson()}
          : buildRetestContext(
              retest: retest,
              state: state,
              catalog: catalog,
              evidenceTraces: evidenceTraces,
              includeHistory: includeHistory,
            );
      final prompt =
          await prompts.buildRetestPrompt(retest, context: context);
      final systemPrompt = await prompts.getPrompt(
        MentalHealthCheckupPromptConfig.globalId,
      );
      final value = await _ai.generateText(
        prompt: prompt,
        purpose: 'mental_health_checkup.explain_retest',
        systemPrompt: systemPrompt,
        maxTokens: 1800,
        expectJson: false,
        temperature: 0.2,
      );
      if (value.trim().isNotEmpty) {
        return MentalHealthCheckupAiResult(
          text: value.trim(),
          usedAi: true,
        );
      }
    } catch (_) {}
    return MentalHealthCheckupAiResult(text: fallback, usedAi: false);
  }

  Future<MentalHealthContentCandidateResult> generateContentCandidate({
    required CheckupContentGenerationPlan plan,
    required String contentCode,
    required String courseVersion,
    required List<CheckupEvidenceTrace> evidenceTraces,
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
        'human_gates': <String>[
          '课程证据与单一构念独立审核',
          '认知访谈',
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
      final prompt = await prompts.buildContentCandidatePrompt(context);
      final systemPrompt = await prompts.getPrompt(
        MentalHealthCheckupPromptConfig.globalId,
      );
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'mental_health_checkup.content_candidate',
        systemPrompt: systemPrompt,
        maxTokens: 2200,
        expectJson: true,
        temperature: 0.15,
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
        decoded['quality_suggestion'] as Map? ??
            const <String, dynamic>{},
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
        correctAnswerIndex:
            (decoded['correct_answer_index'] as num?)?.toInt(),
        sourceLevel:
            (decoded['source_level'] ?? fallback.sourceLevel).toString(),
        constructRationale:
            (decoded['construct_rationale'] ??
                    fallback.constructRationale)
                .toString(),
        safetyRule:
            (decoded['safety_rule'] ?? fallback.safetyRule).toString(),
        smallerVersion:
            (decoded['smaller_version'] ?? fallback.smallerVersion)
                .toString(),
        counterEvidencePrompt:
            (decoded['counter_evidence_prompt'] ??
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
