import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'xiangji_database.dart';
import 'xiangji_knowledge_router.dart';
import 'xiangji_models.dart';
import 'xiangji_state_machine.dart';

enum XiangjiAgentId {
  chiefStrategist,
  epistemicAuditor,
  judgmentEngine,
  groundingAuditor,
  causalAnalyst,
  problemFramer,
  solver,
  strategist,
  redTeam,
  actionOfficer,
  reviewHistorian,
  monitor,
  knowledgeRouter,
}

extension XiangjiAgentIdX on XiangjiAgentId {
  String get code => switch (this) {
        XiangjiAgentId.chiefStrategist => 'A00',
        XiangjiAgentId.epistemicAuditor => 'A01',
        XiangjiAgentId.judgmentEngine => 'A02',
        XiangjiAgentId.groundingAuditor => 'A03',
        XiangjiAgentId.causalAnalyst => 'A04',
        XiangjiAgentId.problemFramer => 'A05',
        XiangjiAgentId.solver => 'A06',
        XiangjiAgentId.strategist => 'A07',
        XiangjiAgentId.redTeam => 'A08',
        XiangjiAgentId.actionOfficer => 'A09',
        XiangjiAgentId.reviewHistorian => 'A10',
        XiangjiAgentId.monitor => 'A11',
        XiangjiAgentId.knowledgeRouter => 'A12',
      };

  String get label => switch (this) {
        XiangjiAgentId.chiefStrategist => '总军师',
        XiangjiAgentId.epistemicAuditor => '认识审计',
        XiangjiAgentId.judgmentEngine => '判断力仲裁',
        XiangjiAgentId.groundingAuditor => '认识根据审计',
        XiangjiAgentId.causalAnalyst => '因果分析',
        XiangjiAgentId.problemFramer => '真问题重构',
        XiangjiAgentId.solver => '问题求解',
        XiangjiAgentId.strategist => '战略军师',
        XiangjiAgentId.redTeam => '红队',
        XiangjiAgentId.actionOfficer => '行动参谋',
        XiangjiAgentId.reviewHistorian => '战史官',
        XiangjiAgentId.monitor => '主动监督',
        XiangjiAgentId.knowledgeRouter => '知识路由器',
      };
}

class XiangjiAgentRequest {
  const XiangjiAgentRequest({
    required this.requestId,
    required this.task,
    this.agent,
    this.problemId = '',
    this.campaignId = '',
    this.claimId = '',
    this.problemState,
    this.isMajorDecision = false,
    this.isHighRisk = false,
    this.isIrreversible = false,
    this.hasUserConfirmation = false,
    this.askingForOriginalSource = false,
    this.needsLargeRemoteFile = false,
    this.preferredProviderId = '',
    this.authorizedSensitiveContext = false,
    this.additionalContext = const <String, Object?>{},
  });

  final String requestId;
  final String task;
  final XiangjiAgentId? agent;
  final String problemId;
  final String campaignId;
  final String claimId;
  final XiangjiProblemState? problemState;
  final bool isMajorDecision;
  final bool isHighRisk;
  final bool isIrreversible;
  final bool hasUserConfirmation;
  final bool askingForOriginalSource;
  final bool needsLargeRemoteFile;
  final String preferredProviderId;
  final bool authorizedSensitiveContext;
  final Map<String, Object?> additionalContext;
}

class XiangjiAgentResult {
  const XiangjiAgentResult({
    required this.agent,
    required this.output,
    required this.modelRunId,
    required this.traceId,
    required this.localOnly,
    required this.executionFrozen,
  });

  final XiangjiAgentId agent;
  final Map<String, Object?> output;
  final String modelRunId;
  final String traceId;
  final bool localOnly;
  final bool executionFrozen;
}

class XiangjiAgentService {
  XiangjiAgentService({
    XiangjiDao? dao,
    XiangjiKnowledgeRouter? router,
    UnifiedAiService? ai,
    GlobalAiSettings? settings,
  })  : _dao = dao ?? XiangjiDao(),
        _router = router ?? XiangjiKnowledgeRouter(dao: dao),
        _ai = ai ?? UnifiedAiService(),
        _settings = settings ?? GlobalAiSettings();

  static const String promptVersion = 'xiangji-v6.1-rev2-p0';

  final XiangjiDao _dao;
  final XiangjiKnowledgeRouter _router;
  final UnifiedAiService _ai;
  final GlobalAiSettings _settings;
  final XiangjiCertaintyLanguage _certainty =
      const XiangjiCertaintyLanguage();

  XiangjiAgentId chooseAgent(XiangjiAgentRequest request) {
    if (request.agent != null) return request.agent!;
    return switch (request.problemState) {
      XiangjiProblemState.captured || XiangjiProblemState.formalizing =>
        XiangjiAgentId.epistemicAuditor,
      XiangjiProblemState.epistemicReview =>
        XiangjiAgentId.groundingAuditor,
      XiangjiProblemState.conceptReview => XiangjiAgentId.problemFramer,
      XiangjiProblemState.solving => XiangjiAgentId.solver,
      XiangjiProblemState.actionReady => XiangjiAgentId.actionOfficer,
      XiangjiProblemState.executing => XiangjiAgentId.actionOfficer,
      XiangjiProblemState.verifying ||
      XiangjiProblemState.backtracking ||
      XiangjiProblemState.resolved =>
        XiangjiAgentId.reviewHistorian,
      _ when request.campaignId.isNotEmpty => XiangjiAgentId.strategist,
      _ => XiangjiAgentId.chiefStrategist,
    };
  }

  Future<XiangjiAgentResult> run(XiangjiAgentRequest request) async {
    final agent = chooseAgent(request);
    final knowledge = await _router.route(XiangjiKnowledgeRequest(
      requestId: request.requestId,
      query: request.task,
      problemId: request.problemId,
      campaignId: request.campaignId,
      claimId: request.claimId,
      isMajorDecision: request.isMajorDecision,
      isHighRisk: request.isHighRisk,
      isIrreversible: request.isIrreversible,
      hasUserConfirmation: request.hasUserConfirmation,
      askingForOriginalSource: request.askingForOriginalSource,
      needsLargeRemoteFile: request.needsLargeRemoteFile,
      preferredProviderId: request.preferredProviderId,
      authorizedSensitiveContext: request.authorizedSensitiveContext,
      realityResultMissing:
          agent == XiangjiAgentId.reviewHistorian &&
          !(request.additionalContext['has_reality_result'] == true),
    ));
    final now = DateTime.now().millisecondsSinceEpoch;
    final runId = '${request.requestId}-${agent.code}-$now';

    if (knowledge.preflight.executionFrozen) {
      final output = <String, Object?>{
        'status': 'execution_frozen',
        'current_facts': knowledge.currentReality,
        'critical_unknowns': knowledge.trace.debtIds,
        'required_actions': knowledge.preflight.hits
            .map((hit) => hit.action)
            .toList(),
        'message': '当前为不可逆高风险且认识债务高；先补证、降低不可逆性，并在需要时寻求专业复核。',
        'user_decision_required': true,
      };
      await _saveRun(
        id: runId,
        agent: agent,
        provider: 'local_rule_engine',
        model: 'K0-offline',
        inputRefs: knowledge.trace.sourcesUsed,
        output: output,
        status: 'blocked_by_rule',
        createdAtMs: now,
      );
      await _saveKnowledgeUse(
        request: request,
        knowledge: knowledge,
        runId: runId,
        now: now,
      );
      return XiangjiAgentResult(
        agent: agent,
        output: output,
        modelRunId: runId,
        traceId: knowledge.trace.id,
        localOnly: true,
        executionFrozen: true,
      );
    }

    final state = await _settings.getState();
    final hasPersonalObject =
        request.problemId.isNotEmpty || request.campaignId.isNotEmpty;
    final privacyLocalOnly =
        hasPersonalObject && !request.authorizedSensitiveContext;
    if (state['available'] != '1' || privacyLocalOnly) {
      final output = _localFallback(agent, knowledge);
      await _saveRun(
        id: runId,
        agent: agent,
        provider:
            privacyLocalOnly ? 'local_privacy_guard' : 'local_rule_engine',
        model: privacyLocalOnly
            ? 'sensitive-context-not-authorized'
            : 'structured-fallback',
        inputRefs: knowledge.trace.sourcesUsed,
        output: output,
        status: 'local_fallback',
        createdAtMs: now,
      );
      await _saveKnowledgeUse(
        request: request,
        knowledge: knowledge,
        runId: runId,
        now: now,
      );
      return XiangjiAgentResult(
        agent: agent,
        output: output,
        modelRunId: runId,
        traceId: knowledge.trace.id,
        localOnly: true,
        executionFrozen: false,
      );
    }

    final started = DateTime.now().millisecondsSinceEpoch;
    try {
      final raw = await _ai.generateChatMessages(
        purpose: 'xiangji_future_strategist.${agent.code.toLowerCase()}',
        maxTokens: agent == XiangjiAgentId.actionOfficer ? 1200 : 3600,
        temperature: 0.15,
        messages: <UnifiedAiChatMessage>[
          const UnifiedAiChatMessage(
            role: 'system',
            content: _systemConstitution,
          ),
          UnifiedAiChatMessage(
            role: 'system',
            content: _rolePrompt(agent),
          ),
          UnifiedAiChatMessage(
            role: 'user',
            content: jsonEncode(<String, Object?>{
              'task': request.task,
              'agent': '${agent.code} ${agent.label}',
              'knowledge_context': knowledge.toPromptMap(),
              'additional_context': request.additionalContext,
              'output_contract': _outputContract(agent),
            }),
          ),
        ],
      );
      final parsed = _parseObject(raw);
      if (parsed == null) throw const FormatException('AI 没有返回 JSON 对象。');
      final validated = _validateAndDiscipline(agent, parsed, knowledge);
      final provider = (state['provider'] ?? 'configured').toString();
      final model = (state['model'] ?? state['model_label'] ?? '').toString();
      await _saveRun(
        id: runId,
        agent: agent,
        provider: provider,
        model: model,
        inputRefs: knowledge.trace.sourcesUsed,
        output: validated,
        status: 'success',
        createdAtMs: now,
        latencyMs: DateTime.now().millisecondsSinceEpoch - started,
      );
      await _saveKnowledgeUse(
        request: request,
        knowledge: knowledge,
        runId: runId,
        now: now,
      );
      await _persistCandidates(validated, runId, now);
      return XiangjiAgentResult(
        agent: agent,
        output: validated,
        modelRunId: runId,
        traceId: knowledge.trace.id,
        localOnly: false,
        executionFrozen: false,
      );
    } catch (error) {
      await _dao.saveModelRun(<String, Object?>{
        'id': runId,
        'agent_id': agent.code,
        'provider': (state['provider'] ?? '').toString(),
        'model': (state['model'] ?? '').toString(),
        'prompt_version': promptVersion,
        'input_refs_json': jsonEncode(knowledge.trace.sourcesUsed),
        'output_hash': '',
        'output_json': '',
        'status': 'failed',
        'error': _safeError(error),
        'latency_ms': DateTime.now().millisecondsSinceEpoch - started,
        'created_at_ms': now,
      });
      rethrow;
    }
  }

  Future<void> _saveRun({
    required String id,
    required XiangjiAgentId agent,
    required String provider,
    required String model,
    required List<String> inputRefs,
    required Map<String, Object?> output,
    required String status,
    required int createdAtMs,
    int latencyMs = 0,
  }) async {
    final encoded = jsonEncode(output);
    await _dao.saveModelRun(<String, Object?>{
      'id': id,
      'agent_id': agent.code,
      'provider': provider,
      'model': model,
      'prompt_version': promptVersion,
      'input_refs_json': jsonEncode(inputRefs),
      'output_hash': sha256.convert(utf8.encode(encoded)).toString(),
      'output_json': encoded,
      'status': status,
      'error': '',
      'latency_ms': latencyMs,
      'created_at_ms': createdAtMs,
    });
  }

  Future<void> _saveKnowledgeUse({
    required XiangjiAgentRequest request,
    required XiangjiKnowledgeContext knowledge,
    required String runId,
    required int now,
  }) =>
      _dao.saveKnowledgeUseRecord(<String, Object?>{
        'id': '${knowledge.trace.id}-use',
        'retrieval_trace_id': knowledge.trace.id,
        'model_run_id': runId,
        'rule_ids_json': jsonEncode(knowledge.trace.ruleIds),
        'node_ids_json': jsonEncode(
          knowledge.methodNodes.map((row) => row['id']).toList(),
        ),
        'passage_ids_json': jsonEncode(
          knowledge.passages.map((row) => row['id']).toList(),
        ),
        'personal_case_ids_json': jsonEncode(
          knowledge.personalHistory.map((row) => row['id']).toList(),
        ),
        'provider_file_ids_json': jsonEncode(
          knowledge.providerFiles.map((item) => item.id).toList(),
        ),
        'created_at_ms': now,
      });

  Map<String, Object?> _validateAndDiscipline(
    XiangjiAgentId agent,
    Map<String, Object?> input,
    XiangjiKnowledgeContext knowledge,
  ) {
    if (input.containsKey('confidence') || input.containsKey('ai_confidence')) {
      input = <String, Object?>{...input}
        ..remove('confidence')
        ..remove('ai_confidence');
      input['confidence_removed_reason'] =
          '认识状态使用多维画像，不用单一伪精确分数。';
    }
    if (agent == XiangjiAgentId.epistemicAuditor) {
      _requireLists(input, const <String>[
        'raw_facts',
        'body_experiences',
        'user_interpretations',
        'claims',
        'critical_unknowns',
        'do_not_infer',
      ]);
      final rawFacts = input['raw_facts'] as List;
      final accepted = <Object?>[];
      final demoted = <Object?>[];
      for (final item in rawFacts) {
        if (item is Map &&
            ((item['source_ref'] ?? '').toString().isNotEmpty ||
                (item['origin'] ?? '').toString() == 'user')) {
          accepted.add(item);
        } else {
          demoted.add(<String, Object?>{
            'text': item is Map ? (item['text'] ?? '').toString() : item.toString(),
            'type': 'hypothesis',
            'reason': '缺少 source_ref/用户原话来源，禁止写入 Fact',
          });
        }
      }
      input['raw_facts'] = accepted;
      input['demoted_hypotheses'] = demoted;
    }
    if (agent == XiangjiAgentId.strategist) {
      _requireLists(input, const <String>['key_unknowns', 'options']);
      final options = input['options'] as List;
      if (options.length < 2) {
        throw const FormatException('重大战役必须返回至少两个真正不同的战略选项。');
      }
      if (knowledge.trace.debtIds.isNotEmpty &&
          (input['war_worthiness'] ?? '').toString() == 'must') {
        input['war_worthiness'] = 'scout_first';
        input['discipline_note'] = '关键认识债务未解决，已降级为先侦察。';
      }
    }
    if (agent == XiangjiAgentId.redTeam) {
      _requireLists(input, const <String>['vulnerable_premises', 'failure_paths']);
    }
    if (agent == XiangjiAgentId.actionOfficer) {
      final action = (input['current_action'] ?? '').toString().trim();
      if (action.isEmpty) throw const FormatException('行动参谋必须返回唯一当前行动。');
      input['analysis_hidden_by_default'] = true;
    }
    final epistemicState = knowledge.trace.debtIds.isEmpty
        ? XiangjiClaimState.provisional
        : XiangjiClaimState.epistemicDebt;
    for (final key in <String>[
      'recommendation',
      'reasoning_summary',
      'strategist_judgment',
      'message',
    ]) {
      final value = input[key];
      if (value is String) input[key] = _certainty.discipline(value, epistemicState);
    }
    input['retrieval_trace_id'] = knowledge.trace.id;
    input['epistemic_status'] = epistemicState.wire;
    input['systematicity_is_not_certainty'] = true;
    input['user_decision_required'] = true;
    return input;
  }

  void _requireLists(Map<String, Object?> value, List<String> keys) {
    for (final key in keys) {
      if (value[key] is! List) {
        throw FormatException('AI 输出缺少数组字段：$key');
      }
    }
  }

  Future<void> _persistCandidates(
    Map<String, Object?> output,
    String runId,
    int now,
  ) async {
    final candidates = output['candidate_knowledge'];
    if (candidates is! List) return;
    for (var index = 0; index < candidates.length; index++) {
      final item = candidates[index];
      if (item is! Map) continue;
      final statement = (item['statement'] ?? '').toString().trim();
      if (statement.isEmpty) continue;
      await _dao.saveCandidateKnowledge(
        id: '$runId-candidate-$index',
        statement: statement,
        originRunId: runId,
        supportingRefs: _strings(item['supporting_refs']),
        counterRefs: _strings(item['counter_refs']),
        validationPlan: (item['validation_plan'] ?? '').toString(),
        scope: (item['scope'] ?? '').toString(),
        state: XiangjiKnowledgeItemState.candidate,
      );
    }
  }

  Map<String, Object?> _localFallback(
    XiangjiAgentId agent,
    XiangjiKnowledgeContext knowledge,
  ) {
    final unknowns = knowledge.trace.debtIds;
    return switch (agent) {
      XiangjiAgentId.actionOfficer => <String, Object?>{
          'current_action': '',
          'why_one_line': '需要用户先在解题纸选定当前算子。',
          'facts_to_record': const <String>[
            '实际做了什么',
            '实际耗时',
            '观察到的结果',
          ],
          'analysis_hidden_by_default': true,
        },
      XiangjiAgentId.epistemicAuditor => <String, Object?>{
          'raw_facts': knowledge.currentReality,
          'body_experiences': const <Object?>[],
          'user_interpretations': const <Object?>[],
          'claims': knowledge.objectClaims,
          'critical_unknowns': unknowns,
          'do_not_infer': const <String>['没有来源的外部事实', '未验证的单一因果'],
          'next_agent': 'A03',
        },
      _ => <String, Object?>{
          'status': 'needs_user_work',
          'current_facts': knowledge.currentReality,
          'critical_unknowns': unknowns,
          'available_rules': knowledge.preflight.ruleIds,
          'message': unknowns.isEmpty
              ? '本地规则已执行；可继续由用户填写结构化步骤，或在全局 AI 设置中配置模型。'
              : '目前不能可靠下结论；先清偿最关键认识债务。',
          'user_decision_required': true,
        },
    };
  }

  Map<String, Object?>? _parseObject(String raw) {
    var value = raw.trim();
    if (value.startsWith('```')) {
      value = value.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      value = value.replaceFirst(RegExp(r'\s*```$'), '');
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return decoded.map((key, item) => MapEntry(key.toString(), item));
      }
    } catch (_) {}
    final start = value.indexOf('{');
    final end = value.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final decoded = jsonDecode(value.substring(start, end + 1));
        if (decoded is Map) {
          return decoded.map((key, item) => MapEntry(key.toString(), item));
        }
      } catch (_) {}
    }
    return null;
  }

  List<String> _strings(Object? value) => value is List
      ? value.map((item) => item.toString()).toList()
      : const <String>[];

  String _safeError(Object error) {
    final text = error.toString();
    return text.length <= 600 ? text : text.substring(0, 600);
  }

  static String _rolePrompt(XiangjiAgentId agent) => switch (agent) {
        XiangjiAgentId.chiefStrategist =>
          '你是 A00 总军师：只编排阶段、合并但不掩盖分歧，不替用户决断。',
        XiangjiAgentId.epistemicAuditor =>
          '你是 A01 认识审计：分离原始事实、身体/体验、用户解释、因果、判断和预测。',
        XiangjiAgentId.judgmentEngine =>
          '你是 A02 判断力引擎：按当前目的找真正相关的同异、边界与反例。',
        XiangjiAgentId.groundingAuditor =>
          '你是 A03 根据审计：追溯泉水/水渠，检测概念闭环和认识债务，系统化程度不等于认识状态。',
        XiangjiAgentId.causalAnalyst =>
          '你是 A04 因果分析：提出多个竞争原因，并给能区分原因的信息行动。',
        XiangjiAgentId.problemFramer =>
          '你是 A05 真问题：审查隐藏前提、路径-目标混淆；保留原题并让用户确认重定义。',
        XiangjiAgentId.solver =>
          '你是 A06 求解器：建立目标判据、差距、AND/OR 子目标、候选算子、事前预测和回溯点。',
        XiangjiAgentId.strategist =>
          '你是 A07 战略军师：先判断是否值得一战、兵力和战争迷雾，再提供多战略、止损与锦囊。',
        XiangjiAgentId.redTeam =>
          '你是 A08 红队：每项反对标注证据/假设/可能性，寻找最脆弱前提但不为反对而反对。',
        XiangjiAgentId.actionOfficer =>
          '你是 A09 行动参谋：只输出唯一当前行动、一行理由、预计时间和 3-5 项现实记录，不塞长篇理论。',
        XiangjiAgentId.reviewHistorian =>
          '你是 A10 战史官：比较事前预测与 RealityResult，定位最早错误层；现实证伪 AI 时生成 AIError。',
        XiangjiAgentId.monitor =>
          '你是 A11 监督：依据跨周期结构化数据识别脱节和五色战况，少打扰。',
        XiangjiAgentId.knowledgeRouter =>
          '你是 A12 知识路由器：解释为何检索/排除资料，绝不把相似度或检索命中当作事实。',
      };

  static Map<String, Object?> _outputContract(XiangjiAgentId agent) =>
      switch (agent) {
        XiangjiAgentId.epistemicAuditor => const <String, Object?>{
            'raw_facts': <Object?>[],
            'body_experiences': <Object?>[],
            'user_interpretations': <Object?>[],
            'claims': <Object?>[],
            'critical_unknowns': <Object?>[],
            'do_not_infer': <Object?>[],
            'next_agent': 'A03',
          },
        XiangjiAgentId.strategist => const <String, Object?>{
            'war_worthiness': 'must|worth|scout_first|defer|do_not_fight',
            'key_unknowns': <Object?>[],
            'resources': <String, Object?>{},
            'options': <Object?>[],
            'recommended_option': null,
            'reasoning_summary': '',
            'needs_red_team': true,
          },
        XiangjiAgentId.redTeam => const <String, Object?>{
            'vulnerable_premises': <Object?>[],
            'failure_paths': <Object?>[],
            'counterevidence': <Object?>[],
            'disagreements': <Object?>[],
            'evidence_needed': <Object?>[],
          },
        XiangjiAgentId.actionOfficer => const <String, Object?>{
            'current_action': '',
            'why_one_line': '',
            'expected_minutes': 0,
            'facts_to_record': <Object?>[],
            'contingency': '',
          },
        XiangjiAgentId.reviewHistorian => const <String, Object?>{
            'prediction_vs_reality': <String, Object?>{},
            'verdict': 'supports|partly_supports|refutes|unknown',
            'earliest_error_layer': '',
            'revisions': <Object?>[],
            'ai_errors': <Object?>[],
            'candidate_knowledge': <Object?>[],
          },
        _ => const <String, Object?>{
            'current_facts': <Object?>[],
            'system_judgments': <Object?>[],
            'critical_unknowns': <Object?>[],
            'counterevidence': <Object?>[],
            'recommendation': '',
            'next_stage': '',
            'candidate_knowledge': <Object?>[],
          },
      };

  static const String _systemConstitution = '''
你是“向己·未来军师 V6.1 Rev.2”的结构化 Agent。只输出一个 JSON 对象，不输出 Markdown。

不可绕过的认识论宪法：
1. 用户原话与 AI 解释分离；不得把改写冒充用户事实。
2. 身体/主观体验可是真实体验；外部原因另需根据。
3. 概念与直观是不同类型表象；例子不能穷尽概念。
4. 重要概念最终需有认识根据；关键链不得无限悬空。
5. 概念闭环必须提示并停止把循环当支持。
6. 未验证且承担关键决策作用的前提登记认识债务。
7. 抽象性、学术性、模型复杂度不提供确定性加成。
8. 系统化程度与认识状态分离。
9. 证明/逻辑有效不能补救薄弱前提。
10. 直接知觉也不自动无误；记录观察条件与替代解释。
11. 有决策影响的因果判断默认生成多个候选原因。
12. 单次经验不得推广为“永远/所有/唯一”。
13. AI 标签保留实例、反例与边界。
14. 决定性未知优先生成侦察/信息子目标。
15. 区分价值、目标、路径和手段。
16. 每个行动说明其减少的差距和服务的高层目标。
17. 预测事前记录；现实冲突时先修订模型。
18. 过去投入不能单独证明应继续投入。
19. 用户拥有最终决策权；建议不是命令。
20. AI 输出同样接受根据、反例、验算和版本修订。

检索命中、Embedding 相似度、模型品牌和“权威”不能直接成为 Fact/Evidence。关键依据不足时使用“当前证据支持/暂时不能推出/需要验证”，禁止虚假确定。不得输出单一 confidence 百分比。
''';
}
