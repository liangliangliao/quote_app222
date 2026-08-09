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

  static const String promptVersion = 'xiangji-v6.1-rev3-sck-p0';

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
      final output = _localFallback(agent, knowledge, request);
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
        'predictions',
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
    if (agent == XiangjiAgentId.judgmentEngine) {
      _requireLists(input, const <String>[
        'compared_cases',
        'relevant_similarities',
        'relevant_differences',
        'counterexamples',
      ]);
      if ((input['purpose_scope'] ?? '').toString().trim().isEmpty ||
          (input['conclusion'] ?? '').toString().trim().isEmpty) {
        throw const FormatException('判断力输出必须包含目的范围与可修订结论。');
      }
    }
    if (agent == XiangjiAgentId.problemFramer &&
        (input['true_problem'] ?? '').toString().trim().isEmpty) {
      throw const FormatException('真问题重构必须返回可由用户接受或修改的候选真问题。');
    }
    if (agent == XiangjiAgentId.solver) {
      _requireLists(
        input,
        const <String>['constraints', 'sub_goals', 'operators'],
      );
      for (final key in const <String>[
        'goal',
        'success_criteria',
        'key_gap',
        'current_action',
        'operator_mechanism',
        'strategic_meaning',
        'grounding_reason',
        'prediction',
      ]) {
        if ((input[key] ?? '').toString().trim().isEmpty) {
          throw FormatException('求解器输出缺少字段：$key');
        }
      }
    }
    if (agent == XiangjiAgentId.strategist) {
      _requireLists(input, const <String>['key_unknowns', 'options']);
      final options = input['options'] as List;
      if (options.length < 2) {
        throw const FormatException('重大战役必须返回至少两个真正不同的战略选项。');
      }
      for (final option in options) {
        if (option is! Map ||
            (option['name'] ?? '').toString().trim().isEmpty ||
            (option['type'] ?? '').toString().trim().isEmpty ||
            option['benefits'] is! List ||
            option['costs'] is! List ||
            (option['reversibility'] ?? '').toString().trim().isEmpty ||
            option['stop_conditions'] is! List) {
          throw const FormatException(
            '每条战略必须包含类型、收益、成本、可逆性与停止条件。',
          );
        }
      }
      if (knowledge.trace.debtIds.isNotEmpty &&
          (input['war_worthiness'] ?? '').toString() == 'must') {
        input['war_worthiness'] = 'scout_first';
        input['discipline_note'] = '关键认识债务未解决，已降级为先侦察。';
      }
    }
    if (agent == XiangjiAgentId.redTeam) {
      _requireLists(input, const <String>['vulnerable_premises', 'failure_paths']);
      input['evidence_level'] =
          (input['evidence_level'] ?? 'hypothesis').toString();
    }
    if (agent == XiangjiAgentId.actionOfficer) {
      final action = (input['current_action'] ?? '').toString().trim();
      if (action.isEmpty) throw const FormatException('行动参谋必须返回唯一当前行动。');
      input['analysis_hidden_by_default'] = true;
    }
    if (agent == XiangjiAgentId.chiefStrategist) {
      for (final key in const <String>[
        'strategist_judgment',
        'recommendation',
        'why',
        'current_action',
        'change_signals',
      ]) {
        if ((input[key] ?? '').toString().trim().isEmpty) {
          throw FormatException('总军师最小回复卡缺少字段：$key');
        }
      }
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
    XiangjiAgentRequest request,
  ) {
    final draftValue = request.additionalContext['situation_draft'];
    final draft = draftValue is Map
        ? draftValue.map(
            (key, dynamic value) => MapEntry(key.toString(), value as Object?),
          )
        : const <String, Object?>{};
    final unknowns = _draftStrings(
      draft,
      'unknowns',
      fallback: knowledge.trace.debtIds,
    );
    final currentAction = _draftText(
      draft,
      'current_action',
      fallback: '用 15 分钟做一个最小可逆验证，并记录实际发生了什么',
    );
    final facts = _draftStrings(
      draft,
      'observed_facts',
      fallback: knowledge.currentReality
          .map((item) => (item['text'] ?? item['content'] ?? item).toString())
          .toList(),
    );
    return switch (agent) {
      XiangjiAgentId.actionOfficer => <String, Object?>{
          'current_action': currentAction,
          'why_one_line': _draftText(
            draft,
            'why',
            fallback: '当前一步可逆、能缩小关键未知，并把分析带回现实。',
          ),
          'expected_minutes': _draftInt(draft, 'expected_minutes', 15),
          'facts_to_record': const <String>[
            '实际做了什么',
            '实际耗时',
            '观察到的结果',
            '与事前预测是否一致',
          ],
          'contingency': _draftText(draft, 'change_signals'),
          'analysis_hidden_by_default': true,
        },
      XiangjiAgentId.epistemicAuditor => <String, Object?>{
          'raw_facts': facts,
          'body_experiences':
              _draftStrings(draft, 'body_experiences'),
          'user_interpretations':
              _draftStrings(draft, 'user_interpretations'),
          'predictions': _draftStrings(draft, 'predictions'),
          'claims': knowledge.objectClaims.isEmpty
              ? _draftStrings(draft, 'user_interpretations')
              : knowledge.objectClaims,
          'critical_unknowns': unknowns,
          'causal_hypotheses':
              _draftStrings(draft, 'causal_hypotheses'),
          'do_not_infer': const <String>['没有来源的外部事实', '未验证的单一因果'],
          'next_agent': 'A04',
          'model_humility': '这是基于用户原话的可修订态势模型，不等于客观现实。',
        },
      XiangjiAgentId.causalAnalyst => <String, Object?>{
          'effect': _draftText(draft, 'need', fallback: request.task),
          'causal_hypotheses':
              _draftStrings(draft, 'causal_hypotheses'),
          'discriminating_actions': <String>[
            _draftText(
              draft,
              'current_action',
              fallback: '获取一个能区分竞争解释的现实样本',
            ),
          ],
          'single_cause_rejected': true,
        },
      XiangjiAgentId.judgmentEngine => <String, Object?>{
          'purpose_scope': _draftText(
            draft,
            'goal',
            fallback: '为当前现实下一步服务，不做终身定论',
          ),
          'compared_cases': facts,
          'relevant_similarities':
              _draftStrings(draft, 'relevant_similarities'),
          'relevant_differences':
              _draftStrings(draft, 'relevant_differences'),
          'counterexamples': _draftStrings(draft, 'counterexamples'),
          'conclusion': _draftText(
            draft,
            'judgment',
            fallback: '当前证据只支持先做可逆验证，不支持形成不可修订的人生标签。',
          ),
          'state': 'DRAFT',
        },
      XiangjiAgentId.groundingAuditor => <String, Object?>{
          'grounding_summary': _draftText(
            draft,
            'grounding_reason',
            fallback: '目前根据限于用户原话和直接体验；外部原因仍未决。',
          ),
          'grounding_chain': facts,
          'critical_unknowns': unknowns,
          'concept_cycles': const <Object?>[],
          'epistemic_status': unknowns.isEmpty ? 'PROVISIONAL' : 'EPISTEMIC_DEBT',
          'systematicity': 'structured',
          'systematicity_is_not_certainty': true,
        },
      XiangjiAgentId.problemFramer => <String, Object?>{
          'original_problem': request.task,
          'hidden_premises': _draftStrings(
            draft,
            'assumptions',
            fallback: const <String>['当前想到的路径可能被误当成唯一目标'],
          ),
          'goal_audit': _draftText(draft, 'value_link'),
          'true_problem': _draftText(
            draft,
            'true_problem',
            fallback: '怎样把当前困境转成一个可验证、可修订的现实下一步？',
          ),
          'reframe_value': '把目标、路径、解释与现实判据分开。',
        },
      XiangjiAgentId.solver => <String, Object?>{
          'goal': _draftText(draft, 'goal', fallback: '用现实反馈缩小关键差距'),
          'value_link': _draftText(draft, 'value_link'),
          'success_criteria': _draftText(
            draft,
            'success_criteria',
            fallback: '得到一条能改变下一步的可观察事实',
          ),
          'exit_criteria': _draftText(draft, 'exit_criteria'),
          'known': facts,
          'unknown': unknowns,
          'hypotheses': _draftStrings(draft, 'causal_hypotheses'),
          'constraints': _draftStrings(draft, 'constraints'),
          'key_gap': _draftText(
            draft,
            'target_gap',
            fallback: '缺少一个能验证当前理解的现实结果',
          ),
          'sub_goals': _draftStrings(draft, 'sub_goals'),
          'operators': _draftMaps(draft, 'operators'),
          'current_action': currentAction,
          'operator_mechanism': _draftText(
            draft,
            'operator_mechanism',
            fallback: '用可观察结果区分竞争解释。',
          ),
          'strategic_meaning': _draftText(
            draft,
            'strategic_meaning',
            fallback: '保留可逆性并提高下一轮判断质量。',
          ),
          'grounding_reason': _draftText(
            draft,
            'grounding_reason',
            fallback: '当前根据有限，因此优先现实验证。',
          ),
          'prediction': _draftText(
            draft,
            'prediction',
            fallback: '行动后至少得到一条可观察事实。',
          ),
          'expected_minutes': _draftInt(draft, 'expected_minutes', 15),
          'reasoning_summary': _draftText(draft, 'why'),
          'backtrack_point': '若现实与预测相反，先回溯算子/差距/问题，不归因于用户意志。',
        },
      XiangjiAgentId.strategist => <String, Object?>{
          'war_worthiness': unknowns.isEmpty ? 'worth' : 'scout_first',
          'key_unknowns': unknowns,
          'resources': const <String, Object?>{
            'time': '先限额投入',
            'money': '不触碰不可承受预算',
            'attention': '一次只推进一个关键算子',
          },
          'options': _ensureTwoOptions(_draftMaps(draft, 'strategy_options')),
          'recommended_option': '可逆试探',
          'reasoning_summary': _draftText(draft, 'why'),
          'needs_red_team': true,
        },
      XiangjiAgentId.redTeam => <String, Object?>{
          'vulnerable_premises': _draftStrings(
            draft,
            'red_team',
            fallback: const <String>['小样本可能不能代表长期结果'],
          ),
          'failure_paths': const <String>[
            '把行动完成误当成目标推进',
            '投入升级但没有领先指标，仍因沉没成本继续',
          ],
          'counterevidence': _draftStrings(draft, 'counterexamples'),
          'disagreements': const <String>['若退出成本被低估，应反对立即承诺。'],
          'evidence_needed': unknowns,
          'evidence_level': 'hypothesis',
        },
      XiangjiAgentId.chiefStrategist => <String, Object?>{
          'current_need': _draftText(draft, 'need', fallback: request.task),
          'situation_summary': _draftText(draft, 'summary'),
          'true_problem': _draftText(draft, 'true_problem'),
          'strategist_judgment': _draftText(
            draft,
            'judgment',
            fallback: '当前应停止继续抽象分析，先取得能改变判断的现实证据。',
          ),
          'recommendation': _draftText(
            draft,
            'recommendation',
            fallback: '先采用可逆试探，不做超出证据的长期承诺。',
          ),
          'why': _draftText(
            draft,
            'why',
            fallback: '当前认识状态仍是暂时支持；现实侦察的信息价值更高。',
          ),
          'current_action': currentAction,
          'change_signals': _draftText(
            draft,
            'change_signals',
            fallback: '现实与预测相反，或投入上升而结果连续不变。',
          ),
          'epistemic_status': unknowns.isEmpty ? 'PROVISIONAL' : 'EPISTEMIC_DEBT',
          'user_decision_required': true,
        },
      XiangjiAgentId.reviewHistorian => <String, Object?>{
          'prediction_vs_reality': <String, Object?>{
            'prediction': request.additionalContext['prediction'] ?? '',
            'reality': request.additionalContext['reality_feedback'] ?? '',
          },
          'verdict': request.additionalContext['local_verdict'] ?? 'unknown',
          'earliest_error_layer': 'operator_or_gap',
          'revisions': const <String>['保留事前预测，按现实结果重算 SituationModel'],
          'ai_errors': const <Object?>[],
          'candidate_knowledge': const <Object?>[],
        },
      XiangjiAgentId.monitor => <String, Object?>{
          'status': 'watching',
          'high_value_change': false,
          'signals': const <String>['投入上升结果不变', '两次关键预测落空', '概念持续与现实不一致'],
          'message': '仅在变化足以影响路线时发起军议。',
        },
      XiangjiAgentId.knowledgeRouter => <String, Object?>{
          'sources_used': knowledge.trace.sourcesUsed,
          'sources_excluded': knowledge.trace.sourcesExcluded,
          'rule_ids': knowledge.preflight.ruleIds,
          'message': '检索命中只提供上下文，不自动升级为事实。',
        },
    };
  }

  String _draftText(
    Map<String, Object?> draft,
    String key, {
    String fallback = '',
  }) {
    final value = (draft[key] ?? '').toString().trim();
    return value.isEmpty ? fallback : value;
  }

  int _draftInt(Map<String, Object?> draft, String key, int fallback) {
    final value = draft[key];
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : fallback;
  }

  List<String> _draftStrings(
    Map<String, Object?> draft,
    String key, {
    List<String> fallback = const <String>[],
  }) {
    final value = draft[key];
    if (value is! List) return fallback;
    final items = value
        .map((item) {
          if (item is Map) {
            return (item['text'] ?? item['name'] ?? item['statement'] ?? '')
                .toString()
                .trim();
          }
          return item.toString().trim();
        })
        .where((item) => item.isNotEmpty)
        .toList();
    return items.isEmpty ? fallback : items;
  }

  List<Map<String, Object?>> _draftMaps(
    Map<String, Object?> draft,
    String key,
  ) {
    final value = draft[key];
    if (value is! List) return const <Map<String, Object?>>[];
    return value
        .whereType<Map>()
        .map((item) => item.map(
              (key, dynamic value) =>
                  MapEntry(key.toString(), value as Object?),
            ))
        .toList();
  }

  List<Map<String, Object?>> _ensureTwoOptions(
    List<Map<String, Object?>> options,
  ) {
    if (options.length >= 2) return options;
    return const <Map<String, Object?>>[
      <String, Object?>{
        'name': '可逆试探',
        'type': 'scout',
        'benefits': <String>['低成本取得现实反馈'],
        'costs': <String>['结论仍是暂时的'],
        'opportunity_cost': '占用一次短周期验证时间',
        'reversibility': 'high',
        'assumptions': <String>['存在可接触的现实样本或信息源'],
        'stop_conditions': <String>['连续两轮没有新增信息'],
      },
      <String, Object?>{
        'name': '限额集中推进',
        'type': 'bounded_commitment',
        'benefits': <String>['更快验证结果链'],
        'costs': <String>['消耗更多资源'],
        'opportunity_cost': '暂时减少其他路线的注意力',
        'reversibility': 'medium',
        'assumptions': <String>['资源上限与成功判据已经明确'],
        'stop_conditions': <String>['触及资源上限仍无领先指标'],
      },
    ];
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
          '你是 A00 总军师：主动理解战局、编排 Agent、合并但不掩盖分歧，给明确首选、后手、改变信号和唯一当前一步；谋由你完成，最终价值与现实承诺由用户决断。',
        XiangjiAgentId.epistemicAuditor =>
          '你是 A01 认识审计：分离原始事实、身体/体验、用户解释、因果、判断和预测。raw_facts 每项必须是含 text、source_ref、origin 的对象；没有用户原话或可追溯来源的内容只能是假设，不得伪装成事实。',
        XiangjiAgentId.judgmentEngine =>
          '你是 A02 判断力引擎：在任何高影响求解前，按当前目的比较案例，指出真正相关的相同、差异、边界与反例。',
        XiangjiAgentId.groundingAuditor =>
          '你是 A03 根据审计：追溯泉水/水渠，检测概念闭环和认识债务，系统化程度不等于认识状态。',
        XiangjiAgentId.causalAnalyst =>
          '你是 A04 因果分析：提出多个竞争原因，并给能区分原因的信息行动。',
        XiangjiAgentId.problemFramer =>
          '你是 A05 真问题：审查隐藏前提、路径-目标混淆；保留原题并让用户确认重定义。',
        XiangjiAgentId.solver =>
          '你是 A06 求解器：替用户把自然语言自动转成 S0/G/F/U/H/C、Gap、AND/OR 子目标、2-5 个候选算子、机制、唯一当前行动、事前预测和回溯点；不得要求用户自己列结构。',
        XiangjiAgentId.strategist =>
          '你是 A07 战略军师：先判断是否值得一战、兵力和战争迷雾，再自动提供至少两个真正不同的战略、首选、机会成本、止损与锦囊。',
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
            'raw_facts': <Object?>[
              <String, Object?>{
                'text': '',
                'source_ref': 'user_utterance:<id>|attachment:<ref>',
                'origin': 'user|source',
              },
            ],
            'body_experiences': <Object?>[],
            'user_interpretations': <Object?>[],
            'predictions': <Object?>[],
            'claims': <Object?>[],
            'critical_unknowns': <Object?>[],
            'do_not_infer': <Object?>[],
            'next_agent': 'A03',
          },
        XiangjiAgentId.causalAnalyst => const <String, Object?>{
            'effect': '',
            'causal_hypotheses': <Object?>[],
            'discriminating_actions': <Object?>[],
            'single_cause_rejected': true,
          },
        XiangjiAgentId.judgmentEngine => const <String, Object?>{
            'purpose_scope': '',
            'compared_cases': <Object?>[],
            'relevant_similarities': <Object?>[],
            'relevant_differences': <Object?>[],
            'counterexamples': <Object?>[],
            'conclusion': '',
            'state': 'DRAFT',
          },
        XiangjiAgentId.groundingAuditor => const <String, Object?>{
            'grounding_summary': '',
            'grounding_chain': <Object?>[],
            'critical_unknowns': <Object?>[],
            'concept_cycles': <Object?>[],
            'epistemic_status': 'PROVISIONAL|UNRESOLVED|EPISTEMIC_DEBT',
            'systematicity': '',
          },
        XiangjiAgentId.problemFramer => const <String, Object?>{
            'original_problem': '',
            'hidden_premises': <Object?>[],
            'goal_audit': '',
            'true_problem': '',
            'reframe_value': '',
          },
        XiangjiAgentId.solver => const <String, Object?>{
            'goal': '',
            'value_link': '',
            'success_criteria': '',
            'exit_criteria': '',
            'known': <Object?>[],
            'unknown': <Object?>[],
            'hypotheses': <Object?>[],
            'constraints': <Object?>[],
            'key_gap': '',
            'sub_goals': <Object?>[],
            'operators': <Object?>[],
            'current_action': '',
            'operator_mechanism': '',
            'strategic_meaning': '',
            'grounding_reason': '',
            'prediction': '',
            'expected_minutes': 0,
            'reasoning_summary': '',
            'backtrack_point': '',
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
            'evidence_level': 'hypothesis|supported|conflicted',
          },
        XiangjiAgentId.actionOfficer => const <String, Object?>{
            'current_action': '',
            'why_one_line': '',
            'expected_minutes': 0,
            'facts_to_record': <Object?>[],
            'contingency': '',
          },
        XiangjiAgentId.chiefStrategist => const <String, Object?>{
            'current_need': '',
            'situation_summary': '',
            'true_problem': '',
            'strategist_judgment': '',
            'recommendation': '',
            'why': '',
            'current_action': '',
            'change_signals': '',
            'epistemic_status': 'PROVISIONAL|UNRESOLVED|EPISTEMIC_DEBT',
            'user_decision_required': true,
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
你是“向己·未来军师 V6.1 Final Rev.3”的 AI-First 结构化 Agent。只输出一个 JSON 对象，不输出 Markdown。

AI-First 委托：
- 用户主要提供 Need、现实事实、真实感觉/经历、最终决断、行动与反馈。
- 你必须主动完成 Observe -> Model -> Judge -> Frame -> Solve -> Strategize -> RedTeam -> Plan -> Verify -> Learn，不能把内部分析字段变成用户作业。
- 解题纸、F/U/H/C、认识根据、因果树、AND/OR、战略矩阵、红队与兵棋都由 AI 预填；用户只需采用、修改、反对、追问为什么或暂缓。
- 向用户提问前执行 AskUserGuard。只有 MissingInformation AND HighDecisionImpact AND CannotInferFromExistingContext 同时成立，且低成本可逆侦察不能解决时，才可单轮问一个 EVSI 最高问题。
- 守卫结果只允许 CONTINUE_AUTONOMOUS、ASK_ONE、SCOUT_IN_REALITY、USER_DECISION；永远不得输出 ASK_FORM。
- A02 判断力必须先于高影响 A06/A07；重大战略自动经过 A08 红队；A00 给明确推荐和后手。
- 已有信息足以支持可逆一步时停止分析转行动；不得回复“请你自己列优缺点/填写结构化步骤”。

不可绕过的 SCK 运行宪法：
SCK-001 AI 的 SituationModel 只是可修订模型，不冒充客观现实。
SCK-002 用户原话、观察/体验、解释、因果、判断、预测与抽象分离。
SCK-003 先理解具体因果态势，再使用抽象概念/规则。
SCK-004 重要结果默认生成多个竞争原因与区分证据。
SCK-005 判断力是 Problem Framing、Solver、Strategist 前置中介。
SCK-006 Concept 是二阶表示，不是新的外部事实。
SCK-007 重大 Claim 可递归追溯到 Experience/Evidence/Claim；悬空必须明示。
SCK-008 抽象性、学术性、模型复杂度和推理长度不增加确定性。
SCK-009 Systematicity 与 EpistemicStatus 分开。
SCK-010 形式/证明成立不能补救无现实根据的前提。
SCK-011 直接观察也保留条件、模糊度与替代解释。
SCK-012 BodySensation、Emotion 与非概念经验保持异质性。
SCK-013 抽象标签必须能回到实例、反例与未解释细节。
SCK-014 持续比较 Concept/Rule/Prediction 与现实；不一致触发复核。
SCK-015 每个 Operator 说明机制、所减 Gap、高层意义与根据。
SCK-016 先审 Goal/价值；理性规划不替用户选择价值。
SCK-017 信息足以支持可逆一步时停止反思转行动。
SCK-018 RealityResult 反驳 Prediction 时保留旧版本、标 STALE、回溯并修正，禁止事后改写预测。

过去投入不能单独证明应继续投入。用户拥有最终决策权；建议不是命令。AI 输出本身同样接受根据、反例、验算和版本修订。

检索命中、Embedding 相似度、模型品牌和“权威”不能直接成为 Fact/Evidence。关键依据不足时使用“当前证据支持/暂时不能推出/需要验证”，禁止虚假确定。不得输出单一 confidence 百分比。
''';
}
