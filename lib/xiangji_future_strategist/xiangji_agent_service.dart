import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'xiangji_database.dart';
import 'xiangji_knowledge_router.dart';
import 'xiangji_models.dart';
import 'xiangji_privacy_guard.dart';
import 'xiangji_state_machine.dart';

enum XiangjiAgentId {
  chiefStrategist,
  epistemicAuditor,
  causalAnalyst,
  judgmentEngine,
  groundingAuditor,
  problemFramer,
  solver,
  campaignSelector,
  resourcePlanner,
  strategist,
  redTeam,
  wargameContingency,
  actionOfficer,
  reviewHistorian,
  monitor,
  knowledgeRouter,
  methodTranslator,
  personalScienceLearner,
  methodEffectValidator,
  antiTemplateValidator,
}

extension XiangjiAgentIdX on XiangjiAgentId {
  String get code => switch (this) {
        XiangjiAgentId.chiefStrategist => 'A00',
        XiangjiAgentId.epistemicAuditor => 'A01',
        XiangjiAgentId.causalAnalyst => 'A02',
        XiangjiAgentId.judgmentEngine => 'A03',
        XiangjiAgentId.groundingAuditor => 'A04',
        XiangjiAgentId.problemFramer => 'A05',
        XiangjiAgentId.solver => 'A06',
        XiangjiAgentId.campaignSelector => 'A07',
        XiangjiAgentId.resourcePlanner => 'A08',
        XiangjiAgentId.strategist => 'A09',
        XiangjiAgentId.redTeam => 'A10',
        XiangjiAgentId.wargameContingency => 'A11',
        XiangjiAgentId.actionOfficer => 'A12',
        XiangjiAgentId.reviewHistorian => 'A13',
        XiangjiAgentId.monitor => 'A14',
        XiangjiAgentId.knowledgeRouter => 'A15',
        XiangjiAgentId.methodTranslator => 'A16',
        XiangjiAgentId.personalScienceLearner => 'A17',
        XiangjiAgentId.methodEffectValidator => 'A18',
        XiangjiAgentId.antiTemplateValidator => 'A19',
      };

  String get label => switch (this) {
        XiangjiAgentId.chiefStrategist => '总军师',
        XiangjiAgentId.epistemicAuditor => '经验分层',
        XiangjiAgentId.causalAnalyst => '竞争因果',
        XiangjiAgentId.judgmentEngine => '判断力仲裁',
        XiangjiAgentId.groundingAuditor => '认识根据审计',
        XiangjiAgentId.problemFramer => '目标审查 / 真问题重构',
        XiangjiAgentId.solver => '持续问题求解',
        XiangjiAgentId.campaignSelector => '选战',
        XiangjiAgentId.resourcePlanner => '兵力规划',
        XiangjiAgentId.strategist => '战略军师',
        XiangjiAgentId.redTeam => '红队',
        XiangjiAgentId.wargameContingency => '兵棋与锦囊',
        XiangjiAgentId.actionOfficer => '行动参谋',
        XiangjiAgentId.reviewHistorian => '对账 / 战史官',
        XiangjiAgentId.monitor => '监督 / 战机探测',
        XiangjiAgentId.knowledgeRouter => '知识路由器',
        XiangjiAgentId.methodTranslator => '即时方法翻译',
        XiangjiAgentId.personalScienceLearner => '个人科学学习',
        XiangjiAgentId.methodEffectValidator => '方法效果校验',
        XiangjiAgentId.antiTemplateValidator => '反模板校验',
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
    this.aiConfigured = false,
    this.provider = '',
    this.model = '',
    this.runStatus = '',
    this.privacyMode = 'minimum_necessary',
    this.sensitiveCategories = const <String>[],
    this.redactedFieldCount = 0,
    this.latencyMs = 0,
    this.failureMessage = '',
  });

  final XiangjiAgentId agent;
  final Map<String, Object?> output;
  final String modelRunId;
  final String traceId;
  final bool localOnly;
  final bool executionFrozen;
  final bool aiConfigured;
  final String provider;
  final String model;
  final String runStatus;
  final String privacyMode;
  final List<String> sensitiveCategories;
  final int redactedFieldCount;
  final int latencyMs;
  final String failureMessage;
}

class XiangjiAgentService {
  XiangjiAgentService({
    XiangjiDao? dao,
    XiangjiKnowledgeRouter? router,
    UnifiedAiService? ai,
    GlobalAiSettings? settings,
    XiangjiCloudPrivacyGuard privacyGuard = const XiangjiCloudPrivacyGuard(),
  })  : _dao = dao ?? XiangjiDao(),
        _router = router ?? XiangjiKnowledgeRouter(dao: dao),
        _ai = ai ?? UnifiedAiService(),
        _settings = settings ?? GlobalAiSettings(),
        _privacyGuard = privacyGuard;

  static const String promptVersion = 'xiangji-v6.1-rev5.2-p0-p9';

  final XiangjiDao _dao;
  final XiangjiKnowledgeRouter _router;
  final UnifiedAiService _ai;
  final GlobalAiSettings _settings;
  final XiangjiCloudPrivacyGuard _privacyGuard;
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
    final solverState = request.problemId.isEmpty
        ? null
        : await _dao.solverSnapshot(request.problemId);
    final activeMethodEvents = request.problemId.isEmpty
        ? const <XiangjiMethodEvent>[]
        : await _dao.latestMethodTurnEvents(
            problemId: request.problemId,
            userVisibleOnly: true,
            limit: 3,
          );
    final methodEffects = activeMethodEvents
        .map((event) => event.toPromptMap())
        .toList(growable: false);
    final state = await _settings.getState();
    final aiConfigured = state['available'] == '1';
    final configuredProvider = (state['provider'] ?? '').toString();
    final configuredModel =
        (state['model'] ?? state['display_model'] ?? '').toString();
    final privacy = _privacyGuard.assess(
      task: request.task,
      additionalContext: <String, Object?>{
        'request_context': request.additionalContext,
        'knowledge_context': knowledge.toPromptMap(),
        if (solverState != null) 'solver_state': solverState.toPromptMap(),
        'method_events': methodEffects,
      },
    );

    if (knowledge.preflight.executionFrozen) {
      final output = <String, Object?>{
        'status': 'execution_frozen',
        'current_facts': knowledge.currentReality,
        'critical_unknowns': knowledge.trace.debtIds,
        'required_actions': knowledge.preflight.hits
            .map((hit) => hit.action)
            .toList(),
        'message': '当前为不可逆高风险且认识债务高；先补证、降低不可逆性，并在需要时寻求专业复核。',
        'method_effects': methodEffects,
        'user_decision_required': true,
        'ai_runtime': <String, Object?>{
          'execution_mode': 'local_safety_kernel',
          'status': 'blocked_by_safety_rule',
          'ai_configured': aiConfigured,
          'provider': configuredProvider,
          'model': configuredModel,
          'privacy_mode': 'local_only',
        },
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
        aiConfigured: aiConfigured,
        provider: configuredProvider,
        model: configuredModel,
        runStatus: 'blocked_by_safety_rule',
        privacyMode: 'local_only',
      );
    }

    final privacyLocalOnly = privacy.containsSensitiveCategory &&
        !request.authorizedSensitiveContext;
    if (!aiConfigured || privacyLocalOnly) {
      final fallbackStatus = privacyLocalOnly
          ? 'sensitive_consent_required'
          : 'ai_not_configured';
      final output = <String, Object?>{
        ..._localFallback(agent, knowledge, request),
        'method_effects': methodEffects,
        if (solverState != null) 'solver_state': solverState.toPromptMap(),
        'ai_runtime': <String, Object?>{
          'execution_mode': privacyLocalOnly
              ? 'local_privacy_guard'
              : 'local_solver_kernel',
          'status': fallbackStatus,
          'ai_configured': aiConfigured,
          'provider': configuredProvider,
          'model': configuredModel,
          'privacy_mode': privacyLocalOnly
              ? 'sensitive_consent_required'
              : 'local_only',
          'sensitive_categories': privacy.sensitiveCategories,
          'direct_identifiers_detected': privacy.directIdentifierCount,
        },
      };
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
        status: fallbackStatus,
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
        aiConfigured: aiConfigured,
        provider: configuredProvider,
        model: configuredModel,
        runStatus: fallbackStatus,
        privacyMode: privacyLocalOnly
            ? 'sensitive_consent_required'
            : 'local_only',
        sensitiveCategories: privacy.sensitiveCategories,
      );
    }

    final started = DateTime.now().millisecondsSinceEpoch;
    try {
      final sanitizedTask = _privacyGuard.sanitizeText(request.task);
      final sanitizedKnowledge =
          _privacyGuard.sanitize(knowledge.toPromptMap());
      final sanitizedAdditional =
          _privacyGuard.sanitize(request.additionalContext);
      final sanitizedSolver =
          _privacyGuard.sanitize(solverState?.toPromptMap());
      final sanitizedMethodEffects = _privacyGuard.sanitize(methodEffects);
      final redactedFieldCount = sanitizedTask.redactedCount +
          sanitizedKnowledge.redactedCount +
          sanitizedAdditional.redactedCount +
          sanitizedSolver.redactedCount +
          sanitizedMethodEffects.redactedCount;
      final privacyMode = privacy.containsSensitiveCategory
          ? 'explicit_sensitive_consent_with_redaction'
          : redactedFieldCount > 0
              ? 'redacted_minimum_necessary'
              : 'minimum_necessary';
      final promptLayers = await _assemblePromptLayers(agent);
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
            content: promptLayers,
          ),
          UnifiedAiChatMessage(
            role: 'user',
            content: jsonEncode(<String, Object?>{
              'task': sanitizedTask.value,
              'agent': '${agent.code} ${agent.label}',
              'knowledge_context': sanitizedKnowledge.value,
              if (solverState != null) 'solver_state': sanitizedSolver.value,
              'active_method_events': sanitizedMethodEffects.value,
              'additional_context': sanitizedAdditional.value,
              'output_contract': _outputContract(agent),
            }),
          ),
        ],
      );
      final parsed = _parseObject(raw);
      if (parsed == null) throw const FormatException('AI 没有返回 JSON 对象。');
      parsed['method_effects'] ??= methodEffects;
      final validated = _validateAndDiscipline(agent, parsed, knowledge);
      validated['active_method_events'] = methodEffects;
      if (solverState != null) {
        validated['solver_state_version'] = solverState.stateVersion;
      }
      final provider = (state['provider'] ?? 'configured').toString();
      final model = (state['model'] ?? state['model_label'] ?? '').toString();
      final latencyMs = DateTime.now().millisecondsSinceEpoch - started;
      validated['ai_runtime'] = <String, Object?>{
        'execution_mode': 'cloud_ai',
        'status': 'success',
        'ai_configured': true,
        'provider': provider,
        'model': model,
        'agent': '${agent.code} ${agent.label}',
        'privacy_mode': privacyMode,
        'sensitive_categories': privacy.sensitiveCategories,
        'redacted_field_count': redactedFieldCount,
        'latency_ms': latencyMs,
      };
      await _saveRun(
        id: runId,
        agent: agent,
        provider: provider,
        model: model,
        inputRefs: knowledge.trace.sourcesUsed,
        output: validated,
        status: 'success',
        createdAtMs: now,
        latencyMs: latencyMs,
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
        aiConfigured: true,
        provider: provider,
        model: model,
        runStatus: 'success',
        privacyMode: privacyMode,
        sensitiveCategories: privacy.sensitiveCategories,
        redactedFieldCount: redactedFieldCount,
        latencyMs: latencyMs,
      );
    } catch (error) {
      final latencyMs = DateTime.now().millisecondsSinceEpoch - started;
      final failureMessage = _safeError(error);
      final provider = (state['provider'] ?? 'configured').toString();
      final model = (state['model'] ?? state['model_label'] ?? '').toString();
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
        'error': failureMessage,
        'latency_ms': latencyMs,
        'created_at_ms': now,
      });
      final output = <String, Object?>{
        ..._localFallback(agent, knowledge, request),
        'method_effects': methodEffects,
        if (solverState != null) 'solver_state': solverState.toPromptMap(),
        'ai_runtime': <String, Object?>{
          'execution_mode': 'cloud_failed_local_fallback',
          'status': 'cloud_failed_local_fallback',
          'ai_configured': true,
          'provider': provider,
          'model': model,
          'privacy_mode': 'minimum_necessary_with_redaction',
          'redacted_field_count': privacy.directIdentifierCount,
          'latency_ms': latencyMs,
        },
      };
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
        aiConfigured: true,
        provider: provider,
        model: model,
        runStatus: 'cloud_failed_local_fallback',
        privacyMode: 'minimum_necessary_with_redaction',
        sensitiveCategories: privacy.sensitiveCategories,
        redactedFieldCount: privacy.directIdentifierCount,
        latencyMs: latencyMs,
        failureMessage: failureMessage,
      );
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
    input['method_effects'] ??= const <Object?>[];
    _validateMethodEffects(input['method_effects']);
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
      _requireLists(input, const <String>[
        'gap_vector',
        'candidate_operators',
        'termination',
      ]);
      if (input['subgoal_graph'] is! Map) {
        throw const FormatException('Persistent Solver 缺少 AND/OR subgoal_graph。');
      }
      final gapTypes = (input['gap_vector'] as List)
          .whereType<Map>()
          .map((gap) => (gap['type'] ?? '').toString())
          .toSet();
      const requiredGapTypes = <String>{
        'information',
        'capability',
        'resource',
        'environment',
        'action',
        'risk',
      };
      if (!gapTypes.containsAll(requiredGapTypes)) {
        throw const FormatException('GapVector 必须覆盖信息、能力、资源、环境、行动与风险维度。');
      }
      final active = input['active_operator'];
      if (active is! Map) {
        throw const FormatException('Persistent Solver 缺少 active_operator。');
      }
      for (final key in const <String>[
        'target_gap',
        'mechanism',
        'preconditions',
        'expected_effect',
        'cost',
        'risk',
        'reversibility',
        'information_value',
      ]) {
        if (!active.containsKey(key)) {
          throw FormatException('active_operator 缺少 $key。');
        }
      }
      if (active['preconditions'] is! List) {
        throw const FormatException('active_operator.preconditions 必须是数组。');
      }
      active['success_signals'] ??= <String>[
        (active['expected_effect'] ?? '').toString(),
      ];
      active['failure_signals'] ??= <String>[
        (input['change_signals'] ?? '事前预测没有出现').toString(),
      ];
    }
    if (agent == XiangjiAgentId.strategist) {
      _requireLists(input, const <String>['key_unknowns', 'options']);
      final options = input['options'] as List;
      if (options.length < 2 || options.length > 3) {
        throw const FormatException('重大战役必须返回 2-3 个真正不同的战略选项。');
      }
      final mechanisms = options
          .whereType<Map>()
          .map(
            (option) =>
                (option['mechanism_for_this_case'] ?? option['mechanism'] ?? '')
                    .toString()
                    .trim(),
          )
          .where((value) => value.isNotEmpty)
          .toSet();
      if (mechanisms.length < 2) {
        throw const FormatException('战略选项必须包含至少两个不同且非空的作用机制。');
      }
      var preferredCount = 0;
      for (final option in options) {
        if (option is! Map ||
            (option['name'] ?? '').toString().trim().isEmpty ||
            (option['type'] ?? '').toString().trim().isEmpty ||
            option['benefits'] is! List ||
            option['costs'] is! List ||
            (option['reversibility'] ?? '').toString().trim().isEmpty ||
            option['stop_conditions'] is! List ||
            (option['target_gap'] ?? '').toString().trim().isEmpty ||
            (option['mechanism_for_this_case'] ?? '')
                .toString()
                .trim()
                .isEmpty ||
            (option['key_assumption'] ?? '').toString().trim().isEmpty ||
            (option['why_not_other_options'] ?? '')
                .toString()
                .trim()
                .isEmpty ||
            (option['switch_trigger'] ?? '').toString().trim().isEmpty) {
          throw const FormatException(
            '每条战略必须针对当前案例包含目标差距、作用机制、关键假设、路线取舍、切换触发与停止条件。',
          );
        }
        if (option['preferred'] == true) preferredCount++;
      }
      if (preferredCount == 0 && options.first is Map) {
        (options.first as Map)['preferred'] = true;
        preferredCount = 1;
      }
      if (preferredCount != 1) {
        throw const FormatException('战略路线必须且只能有一个军师首选。');
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
    if (agent == XiangjiAgentId.wargameContingency) {
      _requireLists(input, const <String>[
        'scenarios',
        'if_then_branches',
        'contingencies',
        'stop_loss',
      ]);
    }
    if (agent == XiangjiAgentId.actionOfficer) {
      final action = (input['current_action'] ?? '').toString().trim();
      if (action.isEmpty) throw const FormatException('行动参谋必须返回唯一当前行动。');
      input['analysis_hidden_by_default'] = true;
      input['method_explanations_suppressed'] = true;
    }
    if (agent == XiangjiAgentId.methodEffectValidator) {
      _requireLists(input, const <String>['checked_methods', 'failures']);
      input['release_gate_passed'] = (input['failures'] as List).isEmpty;
    }
    if (agent == XiangjiAgentId.antiTemplateValidator) {
      _requireLists(input, const <String>[
        'template_signals',
        'invalid_operators',
      ]);
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
    input['validation_outcome'] = 'passed_rev5_2_gates';
    return input;
  }

  void _validateMethodEffects(Object? value) {
    if (value is! List) {
      throw const FormatException('AI 输出 method_effects 必须是数组。');
    }
    for (final raw in value) {
      if (raw is! Map) {
        throw const FormatException('method_effects 每项必须是对象。');
      }
      final methodId = (raw['method_id'] ?? '').toString();
      final number = int.tryParse(methodId.replaceFirst('MEC-', '')) ?? 0;
      if (number < 1 || number > 14) {
        throw FormatException('未知 method_id：$methodId');
      }
      for (final key in const <String>[
        'trigger',
        'before_state',
        'after_state',
        'decision_effect',
        'reality_test',
      ]) {
        final item = raw[key];
        if (item == null || (item is String && item.trim().isEmpty)) {
          throw FormatException('MethodEffect $methodId 缺少 $key。');
        }
      }
      final mutations = raw['data_mutations'];
      if (mutations is! List || mutations.isEmpty) {
        throw FormatException('MethodEffect $methodId 没有真实数据变更。');
      }
    }
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
    final constraints = _draftStrings(draft, 'constraints');
    final subGoals = _draftStrings(draft, 'sub_goals');
    final operatorDrafts = _draftMaps(draft, 'operators');
    final topLevelPreconditions = _draftStrings(draft, 'preconditions');
    final preconditions = topLevelPreconditions.isNotEmpty
        ? topLevelPreconditions
        : operatorDrafts.isEmpty
            ? const <String>[]
            : _draftStrings(operatorDrafts.first, 'preconditions');
    final counterexamples = _draftStrings(draft, 'counterexamples');
    final highRisk = draft['high_risk'] == true;
    final caseOptions = _ensureCaseOptions(draft);
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
          'constraints': constraints,
          'key_gap': _draftText(
            draft,
            'target_gap',
            fallback: '缺少一个能验证当前理解的现实结果',
          ),
          'sub_goals': subGoals,
          'operators': operatorDrafts,
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
          'backtrack_point': '若现实与预测相反，先回溯当前办法、差距和真问题，不归因于用户意志。',
          'problem_frame': <String, Object?>{
            'statement': _draftText(draft, 'true_problem', fallback: request.task),
            'value_link': _draftText(draft, 'value_link'),
          },
          'current_state': <String, Object?>{
            'facts': facts,
            'unknowns': unknowns,
          },
          'goal_state': <String, Object?>{
            'statement': _draftText(draft, 'goal'),
            'success_criteria': _draftText(draft, 'success_criteria'),
            'exit_criteria': _draftText(draft, 'exit_criteria'),
          },
          'gap_vector': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'information',
              'label': unknowns.isEmpty ? '当前无关键未知阻塞' : unknowns.first,
              'items': unknowns,
              'priority': unknowns.isEmpty ? 0 : 90,
            },
            <String, Object?>{
              'type': 'concept',
              'label': counterexamples.isEmpty
                  ? '当前概念边界未形成主要阻塞'
                  : '当前概念仍有反例未解释',
              'items': counterexamples,
              'priority': counterexamples.isEmpty ? 0 : 80,
            },
            <String, Object?>{
              'type': 'capability',
              'label': preconditions.isNotEmpty
                  ? preconditions.first
                  : subGoals.isNotEmpty
                      ? subGoals.first
                      : '当前无待补齐能力或前提',
              'items': <String>{...preconditions, ...subGoals}.toList(),
              'priority': preconditions.isNotEmpty
                  ? 105
                  : subGoals.isNotEmpty
                      ? 75
                      : 0,
            },
            <String, Object?>{
              'type': 'resource',
              'label': constraints.isEmpty ? '当前资源未形成主要阻塞' : constraints.first,
              'items': constraints,
              'priority': constraints.isEmpty ? 0 : 70,
            },
            const <String, Object?>{
              'type': 'environment',
              'label': '环境条件随现实反馈继续更新',
              'priority': 0,
            },
            <String, Object?>{
              'type': 'action',
              'label': _draftText(
                draft,
                'target_gap',
                fallback: '缺少一个能验证当前理解的现实结果',
              ),
              'priority': 100,
            },
            <String, Object?>{
              'type': 'risk',
              'label': highRisk ? '需要先降低不可逆风险' : '当前无优先风险缺口',
              'priority': highRisk ? 110 : 0,
            },
          ],
          'subgoal_graph': <String, Object?>{
            'logic': preconditions.isEmpty ? 'OR' : 'AND',
            'sub_goals': subGoals,
            'precondition_sub_goals': preconditions,
          },
          'candidate_operators': operatorDrafts,
          'active_operator': <String, Object?>{
            'title': currentAction,
            'target_gap': _draftText(draft, 'target_gap'),
            'mechanism': _draftText(
              draft,
              'operator_mechanism',
              fallback: '用可观察结果区分竞争解释。',
            ),
            'preconditions': preconditions,
            'expected_effect': _draftText(draft, 'prediction'),
            'cost': '${_draftInt(draft, 'expected_minutes', 15)} 分钟',
            'risk': 'low',
            'reversibility': 'high',
            'information_value': '现实结果将改变下一轮判断',
            'success_signals': <String>[
              _draftText(draft, 'prediction'),
            ],
            'failure_signals': <String>[
              _draftText(draft, 'change_signals'),
            ],
          },
          'termination': const <String>[
            '成功判据被现实满足',
            '止损条件触发',
            '关键前提被现实否定后回溯',
          ],
        },
      XiangjiAgentId.campaignSelector => <String, Object?>{
          'war_worthiness': unknowns.isEmpty ? 'worth' : 'scout_first',
          'strategic_value': _draftText(draft, 'value_link'),
          'victory_criteria': <String>[
            _draftText(draft, 'success_criteria'),
          ].where((item) => item.isNotEmpty).toList(),
          'exit_criteria': <String>[
            _draftText(draft, 'exit_criteria'),
          ].where((item) => item.isNotEmpty).toList(),
          'opportunity_cost': _draftStrings(draft, 'constraints'),
        },
      XiangjiAgentId.resourcePlanner => <String, Object?>{
          'resources': const <String, Object?>{
            'time': '先限额投入',
            'attention': '一次只推进一个关键差距',
          },
          'constraints': _draftStrings(draft, 'constraints'),
          'front_concentration': '只把资源集中到当前最大差距。',
          'opportunity_cost': _draftStrings(draft, 'constraints'),
        },
      XiangjiAgentId.strategist => <String, Object?>{
          'war_worthiness': unknowns.isEmpty ? 'worth' : 'scout_first',
          'key_unknowns': unknowns,
          'resources': const <String, Object?>{
            'time': '先限额投入',
            'money': '不触碰不可承受预算',
            'attention': '一次只推进一个关键办法',
          },
          'options': caseOptions,
          'recommended_option': caseOptions
              .firstWhere(
                (option) => option['preferred'] == true,
                orElse: () => caseOptions.first,
              )['name'],
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
      XiangjiAgentId.wargameContingency => <String, Object?>{
          'scenarios': <String>['按预测发展', '低于预测', '出现反向结果'],
          'if_then_branches': <Map<String, Object?>>[
            <String, Object?>{
              'if': '现实与预测相反',
              'then': '停止沿原办法加码并回溯最早错误层',
            },
          ],
          'contingencies': <String>[
            _draftText(
              draft,
              'change_signals',
              fallback: '关键前提变化时重新军议',
            ),
          ],
          'stop_loss': <String>[
            _draftText(draft, 'exit_criteria', fallback: '达到不可承受成本前停止'),
          ],
          'retreat_route': '保留当前版本和已验证事实，退回当前最大差距重算。',
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
          'sources_excluded': knowledge.trace.rejectedSources,
          'rule_ids': knowledge.preflight.ruleIds,
          'message': '检索命中只提供上下文，不自动升级为事实。',
        },
      XiangjiAgentId.methodTranslator => <String, Object?>{
          'primary_answer': currentAction,
          'experience_interpretation_split': true,
          'model_is_revisable': true,
          'competing_causes': _draftStrings(draft, 'causal_hypotheses'),
          'case_differences':
              _draftStrings(draft, 'relevant_differences'),
          'grounding_summary': _draftText(draft, 'grounding_reason'),
          'action_mechanism': _draftText(draft, 'operator_mechanism'),
          'developer_language_hidden': true,
        },
      XiangjiAgentId.personalScienceLearner => <String, Object?>{
          'just_in_time_method':
              '把当前体验与解释分开，再用能区分候选原因的现实结果继续判断。',
          'transfer_prompt':
              '下次遇到类似情境，先各写一句“实际发生了什么”和“我怎样解释它”。',
          'candidate_rules': const <Object?>[],
          'counterexamples': _draftStrings(draft, 'counterexamples'),
          'validation_plan': _draftText(draft, 'prediction'),
          'training_optional': true,
        },
      XiangjiAgentId.methodEffectValidator => <String, Object?>{
          'checked_methods': request.additionalContext['method_effects'] is List
              ? request.additionalContext['method_effects'] as List
              : const <Object?>[],
          'failures': const <Object?>[],
          'release_gate_passed': true,
        },
      XiangjiAgentId.antiTemplateValidator => <String, Object?>{
          'template_signals': const <Object?>[],
          'invalid_operators': const <Object?>[],
          'recommended_fixes': const <Object?>[],
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

  List<Map<String, Object?>> _ensureCaseOptions(
    Map<String, Object?> draft,
  ) {
    final options = _draftMaps(draft, 'strategy_options');
    if (options.length >= 2) return options;
    final need = _draftText(draft, 'need', fallback: '当前问题');
    final gap = _draftText(
      draft,
      'target_gap',
      fallback: '缺少能改变下一步的现实信息',
    );
    final action = _draftText(
      draft,
      'current_action',
      fallback: '取得一个能区分候选原因的现实样本',
    );
    final mechanism = _draftText(
      draft,
      'operator_mechanism',
      fallback: '让候选原因产生不同的可观察结果',
    );
    final signal = _draftText(
      draft,
      'change_signals',
      fallback: '现实与事前预测相反',
    );
    return <Map<String, Object?>>[
      <String, Object?>{
        'name': '先验证“$need”的关键未知',
        'type': 'case_discriminating_scout',
        'preferred': true,
        'target_gap': gap,
        'mechanism_for_this_case': '$action；$mechanism。',
        'key_assumption': '能够取得至少一个与当前问题直接相关的现实样本',
        'benefits': const <String>['直接减少关键未知', '保留退出空间'],
        'costs': const <String>['终局结论仍需更多现实'],
        'opportunity_cost': '占用一个短复核周期。',
        'reversibility': 'high',
        'assumptions': const <String>['现实样本能够区分候选原因'],
        'why_preferred': '当前缺的是事实，不是更多抽象解释。',
        'why_not_other_options': '直接加码会放大未经验证前提的代价。',
        'switch_trigger': '获得稳定支持后转为限额推进；被反驳时回溯。',
        'stop_conditions': <String>[signal],
        'user_summary': '先用现实区分原因，再决定是否投入更多。',
      },
      <String, Object?>{
        'name': '围绕“$need”限额推进一个周期',
        'type': 'case_bounded_commitment',
        'preferred': false,
        'target_gap': gap,
        'mechanism_for_this_case': '在资源上限内重复已获支持的机制并观察领先指标。',
        'key_assumption': '当前机制已有现实支持且退出条件可执行',
        'benefits': const <String>['更快检验机制稳定性'],
        'costs': const <String>['占用更多资源'],
        'opportunity_cost': '减少其他路线的注意力。',
        'reversibility': 'medium',
        'assumptions': const <String>['成功判据与资源上限已明确'],
        'why_preferred': '',
        'why_not_other_options': '当前证据尚不足，因此暂不作为首选。',
        'switch_trigger': '预测落空或触及资源上限时转回侦察或退出。',
        'stop_conditions': <String>[signal, '触及资源上限仍无领先指标'],
        'user_summary': '只投入一个可复核周期，以结果决定去留。',
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

  Future<String> _assemblePromptLayers(XiangjiAgentId agent) async {
    final paths = <String>[
      'assets/xiangji_future_strategist/prompts/00_P0_Constitution.md',
      _promptAssetForAgent(agent),
      'assets/xiangji_future_strategist/prompts/16_Output_Contracts.md',
      'assets/xiangji_future_strategist/prompts/17_Orchestration_Policy.md',
      'assets/xiangji_future_strategist/prompts/19_System_State_Schema.md',
      'assets/xiangji_future_strategist/prompts/20_Method_Experience_Contract.md',
      'assets/xiangji_future_strategist/prompts/21_Signature_Capability_Router.md',
    ].toSet().toList();
    final loaded = await Future.wait(paths.map((path) async {
      try {
        return await rootBundle.loadString(path);
      } catch (_) {
        return '';
      }
    }));
    final available = loaded.where((item) => item.trim().isNotEmpty).toList();
    if (available.isEmpty) return _rolePrompt(agent);
    return <String>[
      ...available,
      'Runtime role fallback/identity: ${_rolePrompt(agent)}',
    ].join('\n\n---\n\n');
  }

  static String _promptAssetForAgent(XiangjiAgentId agent) => switch (agent) {
        XiangjiAgentId.chiefStrategist =>
          'assets/xiangji_future_strategist/prompts/01_Chief_Strategist.md',
        XiangjiAgentId.epistemicAuditor =>
          'assets/xiangji_future_strategist/prompts/02_Experience_Parser.md',
        XiangjiAgentId.causalAnalyst =>
          'assets/xiangji_future_strategist/prompts/03_Causal_Analyst.md',
        XiangjiAgentId.judgmentEngine =>
          'assets/xiangji_future_strategist/prompts/04_Judgment_Engine.md',
        XiangjiAgentId.groundingAuditor =>
          'assets/xiangji_future_strategist/prompts/05_Grounding_Auditor.md',
        XiangjiAgentId.problemFramer =>
          'assets/xiangji_future_strategist/prompts/06_Goal_Auditor_Problem_Framer.md',
        XiangjiAgentId.solver =>
          'assets/xiangji_future_strategist/prompts/07_Persistent_Solver.md',
        XiangjiAgentId.campaignSelector ||
        XiangjiAgentId.resourcePlanner ||
        XiangjiAgentId.strategist =>
          'assets/xiangji_future_strategist/prompts/08_Strategist.md',
        XiangjiAgentId.redTeam =>
          'assets/xiangji_future_strategist/prompts/09_Red_Team.md',
        XiangjiAgentId.wargameContingency =>
          'assets/xiangji_future_strategist/prompts/10_Wargame_Contingency.md',
        XiangjiAgentId.actionOfficer =>
          'assets/xiangji_future_strategist/prompts/11_Action_Officer.md',
        XiangjiAgentId.reviewHistorian =>
          'assets/xiangji_future_strategist/prompts/12_Reconciler_Historian.md',
        XiangjiAgentId.monitor =>
          'assets/xiangji_future_strategist/prompts/13_Monitor_Opportunity.md',
        XiangjiAgentId.methodTranslator =>
          'assets/xiangji_future_strategist/prompts/14_Method_Translator.md',
        XiangjiAgentId.knowledgeRouter =>
          'assets/xiangji_future_strategist/prompts/15_Knowledge_Router.md',
        XiangjiAgentId.personalScienceLearner =>
          'assets/xiangji_future_strategist/prompts/12_Reconciler_Historian.md',
        XiangjiAgentId.methodEffectValidator =>
          'assets/xiangji_future_strategist/prompts/20_Method_Experience_Contract.md',
        XiangjiAgentId.antiTemplateValidator =>
          'assets/xiangji_future_strategist/prompts/18_Anti_Template_Validator.md',
      };

  static String _rolePrompt(XiangjiAgentId agent) => switch (agent) {
        XiangjiAgentId.chiefStrategist =>
          '你是 A00 总军师：主动理解战局、编排 Agent、合并但不掩盖分歧，给明确首选、后手、改变信号和唯一当前一步；谋由你完成，最终价值与现实承诺由用户决断。',
        XiangjiAgentId.epistemicAuditor =>
          '你是 A01 经验分层：分离原始事实、身体/体验、用户解释、因果、判断和预测。raw_facts 每项必须是含 text、source_ref、origin 的对象；没有用户原话或可追溯来源的内容只能是假设，不得伪装成事实。',
        XiangjiAgentId.causalAnalyst =>
          '你是 A02 因果分析：提出多个竞争原因，并给能区分原因的信息行动。',
        XiangjiAgentId.judgmentEngine =>
          '你是 A03 判断力引擎：在任何高影响求解前，按当前目的比较案例，指出真正相关的相同、差异、边界与反例。',
        XiangjiAgentId.groundingAuditor =>
          '你是 A04 根据审计：追溯泉水/水渠，检测概念闭环和认识债务，系统化程度不等于认识状态。',
        XiangjiAgentId.problemFramer =>
          '你是 A05 真问题：审查隐藏前提、路径-目标混淆；保留原题并让用户确认重定义。',
        XiangjiAgentId.solver =>
          '你是 A06 求解器：替用户把自然语言自动转成 S0/G/F/U/H/C、Gap、AND/OR 子目标、2-5 个候选算子、机制、唯一当前行动、事前预测和回溯点；不得要求用户自己列结构。',
        XiangjiAgentId.campaignSelector =>
          '你是 A07 选战官：先审查是否值得一战、与大战略的关系、胜利和退出条件。',
        XiangjiAgentId.resourcePlanner =>
          '你是 A08 兵力规划：核算时间、精力、金钱、关系与机会成本，避免战线分散。',
        XiangjiAgentId.strategist =>
          '你是 A09 战略军师：提供 2-3 条机制真正不同的路线、首选、切换条件和止损。',
        XiangjiAgentId.redTeam =>
          '你是 A10 红队：每项反对标注证据/假设/可能性，寻找最脆弱前提但不为反对而反对。',
        XiangjiAgentId.wargameContingency =>
          '你是 A11 兵棋与锦囊：用 IF/THEN 推演情景，给触发条件、后手、止损和撤退路线。',
        XiangjiAgentId.actionOfficer =>
          '你是 A12 行动参谋：只输出唯一当前行动、一行理由、预计时间和 3-5 项现实记录，不塞长篇理论。',
        XiangjiAgentId.reviewHistorian =>
          '你是 A13 对账/战史官：比较事前预测与 RealityResult，定位最早错误层；现实证伪 AI 时生成 AIError。',
        XiangjiAgentId.monitor =>
          '你是 A14 监督/战机探测：依据跨周期结构化数据识别八类脱节、五色战况和机会窗口，少打扰。',
        XiangjiAgentId.knowledgeRouter =>
          '你是 A15 知识路由器：解释为何检索/排除资料，绝不把相似度或检索命中当作事实。',
        XiangjiAgentId.methodTranslator =>
          '你是 A16 方法翻译：只把本轮已发生的方法效果翻成简洁人话，不新增判断或改变内部状态。',
        XiangjiAgentId.personalScienceLearner =>
          '你是 A17 个人科学学习：从多次现实事件生成候选规律，保留范围、反例与验证计划，不把单次经验升格为规则。',
        XiangjiAgentId.methodEffectValidator =>
          '你是 A18 方法效果校验：检查每个 MEC 是否有 trigger、operation、data mutation、decision effect 与 reality test。',
        XiangjiAgentId.antiTemplateValidator =>
          '你是 A19 反模板校验：检测固定侦察/推进/等待套话、机制为空和不同问题复用同一算子。',
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
            'problem_frame': <String, Object?>{},
            'current_state': <String, Object?>{},
            'goal_state': <String, Object?>{},
            'gap_vector': <Object?>[
              <String, Object?>{'type': 'information'},
              <String, Object?>{'type': 'concept'},
              <String, Object?>{'type': 'capability'},
              <String, Object?>{'type': 'resource'},
              <String, Object?>{'type': 'environment'},
              <String, Object?>{'type': 'action'},
              <String, Object?>{'type': 'risk'},
            ],
            'subgoal_graph': <String, Object?>{
              'logic': 'AND|OR',
              'nodes': <Object?>[],
              'edges': <Object?>[],
            },
            'candidate_operators': <Object?>[],
            'active_operator': <String, Object?>{
              'target_gap': '',
              'mechanism': '',
              'preconditions': <Object?>[],
              'expected_effect': '',
              'cost': '',
              'risk': '',
              'reversibility': '',
              'information_value': '',
              'success_signals': <Object?>[],
              'failure_signals': <Object?>[],
            },
            'termination': <Object?>[],
          },
        XiangjiAgentId.campaignSelector => const <String, Object?>{
            'war_worthiness': 'must|worth|scout_first|defer|do_not_fight',
            'strategic_value': '',
            'victory_criteria': <Object?>[],
            'exit_criteria': <Object?>[],
            'opportunity_cost': <Object?>[],
          },
        XiangjiAgentId.resourcePlanner => const <String, Object?>{
            'resources': <String, Object?>{},
            'constraints': <Object?>[],
            'front_concentration': '',
            'opportunity_cost': <Object?>[],
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
        XiangjiAgentId.wargameContingency => const <String, Object?>{
            'scenarios': <Object?>[],
            'if_then_branches': <Object?>[],
            'contingencies': <Object?>[],
            'stop_loss': <Object?>[],
            'retreat_route': '',
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
        XiangjiAgentId.methodTranslator => const <String, Object?>{
            'primary_answer': '',
            'experience_interpretation_split': true,
            'model_is_revisable': true,
            'competing_causes': <Object?>[],
            'case_differences': <Object?>[],
            'grounding_summary': '',
            'action_mechanism': '',
            'developer_language_hidden': true,
          },
        XiangjiAgentId.personalScienceLearner => const <String, Object?>{
            'just_in_time_method': '',
            'transfer_prompt': '',
            'candidate_rules': <Object?>[],
            'counterexamples': <Object?>[],
            'validation_plan': '',
            'training_optional': true,
          },
        XiangjiAgentId.methodEffectValidator => const <String, Object?>{
            'checked_methods': <Object?>[],
            'failures': <Object?>[],
            'release_gate_passed': false,
          },
        XiangjiAgentId.antiTemplateValidator => const <String, Object?>{
            'template_signals': <Object?>[],
            'invalid_operators': <Object?>[],
            'recommended_fixes': <Object?>[],
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
你是“向己·未来军师 V6.1 Final Rev.5.2”的 AI-First 持久问题求解 Agent。只输出一个 JSON 对象，不输出 Markdown。

AI-First 委托：
- 用户主要提供 Need、现实事实、真实感觉/经历、最终决断、行动与反馈。每条输入先分类；反馈、体验和纠正默认继续更新稳定问题身份。
- 你必须主动完成 Observe -> Model -> Judge -> Frame -> Solve -> Strategize -> RedTeam -> Plan -> Verify -> Learn，不能把内部分析字段变成用户作业。
- 解题纸、F/U/H/C、认识根据、因果树、AND/OR、战略矩阵、红队与兵棋都由 AI 预填；用户只需采用、修改、反对、追问为什么或暂缓。
- 向用户提问前执行 AskUserGuard。只有 MissingInformation AND HighDecisionImpact AND CannotInferFromExistingContext 同时成立，且低成本可逆侦察不能解决时，才可单轮问一个 EVSI 最高问题。
- 守卫结果只允许 CONTINUE_AUTONOMOUS、ASK_ONE、SCOUT_IN_REALITY、USER_DECISION；永远不得输出 ASK_FORM。
- A03 判断力必须先于高影响 A06/A09；A06维护持久问题状态；重大战略自动经过 A10 红队与 A11 兵棋；A00 给明确推荐和后手；A16/A17只转译已发生的方法与学习事件。
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

Rev.4 用户体验与持久求解约束：
- 同一道核心问题跨对话保持稳定 problem_id；每轮只追加 ProblemStateVersion、HypothesisTest 与 SolutionAttempt，不覆盖历史。
- 现实反馈必须更新事实、假设、差距和算子优先级；完成行动不等于问题已经解决。
- 当用户回答“我不知道”，不得重复追问；改用安全假设、低成本现实侦察或保守默认。
- 每个高影响方法同时生成用户可理解的 CognitiveExperience。普通界面严禁出现 raw_context、causal_map、judgment_map、grounding_chain、problem_tree、strategy_matrix、red_team、war_game 或原始 JSON。
- 第一层直接给“现在怎么办”；原因、证据、反例、最弱前提、未知和即时方法放在按需展开的第二层。
- 每条战略必须针对当前案例说明目标差距、作用机制、关键假设、首选原因、不选其他路线的原因、切换触发和停止条件；不得用固定模板冒充个案战略。

Rev.5.2 Signature Method Effect 约束：
- Signature Capability Router 只选择当前决策相关的 MEC-001..MEC-014；默认每轮只让用户看到 0-3 项。
- 每个已触发方法必须形成 MethodEvent：trigger、before/after state、data_mutations、decision_effect、reality_test，不保存私密思维链。
- 方法只增加解释文字却不改变 ProblemFrame、Gap、Hypothesis、Operator 或 Strategy，且未说明维持理由，判定失败。
- 所有方法作用于同一个 PersistentProblem / SolverState，不创建 14 个平行页面或断裂会话。
- Action Mode 隐藏方法与长分析；Reality 返回后再显示必要的对账、改判和回溯。

过去投入不能单独证明应继续投入。用户拥有最终决策权；建议不是命令。AI 输出本身同样接受根据、反例、验算和版本修订。

检索命中、Embedding 相似度、模型品牌和“权威”不能直接成为 Fact/Evidence。关键依据不足时使用“当前证据支持/暂时不能推出/需要验证”，禁止虚假确定。不得输出单一 confidence 百分比。
''';
}
