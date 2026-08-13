import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'belief_mentor_dao.dart';
import 'belief_mentor_models.dart';
import 'belief_mentor_policies.dart';

class BeliefMentorMentorReply {
  const BeliefMentorMentorReply({
    required this.route,
    required this.observation,
    required this.inference,
    required this.nextAction,
    required this.boundary,
  });

  final String route;
  final String observation;
  final String inference;
  final String nextAction;
  final String boundary;

  String get displayText => <String>[
    observation,
    if (inference.isNotEmpty) '一种暂定解释：$inference',
    if (nextAction.isNotEmpty) '下一步：$nextAction',
    if (boundary.isNotEmpty) boundary,
  ].join('\n\n');

  Map<String, Object?> toJson() => <String, Object?>{
    'route': route,
    'observation': observation,
    'inference': inference,
    'next_action': nextAction,
    'boundary': boundary,
  };
}

class BeliefMentorAiService {
  BeliefMentorAiService({BeliefMentorDao? dao, UnifiedAiService? ai})
    : _dao = dao ?? BeliefMentorDao(),
      _ai = ai ?? UnifiedAiService();

  final BeliefMentorDao _dao;
  final UnifiedAiService _ai;

  static const String _systemPrompt = '''
你是 Belief Mentor 的结构化心理教练，不是治疗师，也不是事实裁判。

硬规则：
1. 先分离可观察事实、用户解释、情绪、行为倾向，再提出 3–5 个“候选信念”。候选必须让用户确认或编辑，绝不能当成诊断。
2. 所有推断都使用“可能、暂定、值得检验”等措辞；不得承诺结果，不得制造研究、人物、引文或统计数字。
3. 不把一次结果过度概括为能力、身份或未来的结论。替代信念必须可验证、允许边界条件。
4. 行动必须是 24 小时内可执行的微实验，包含最小版本、备用动作、难度与完成概率。概率低于 50 时主动缩小。
5. 只返回请求里规定的 JSON；不要 Markdown。
6. 出现自伤/伤人、妄想或偏执现实判断、躁狂式高风险行为、危险或违法计划时停止普通教练流程，建议立即联系当地紧急服务、可信任的人或专业支持。
''';

  Future<BeliefMentorAiResult<BeliefMentorDiagnosis>> diagnose({
    required String event,
    required String thought,
    required String action,
  }) async {
    final source = '$event\n$thought\n$action'.trim();
    final safety = BeliefMentorSafetyPolicy.assess(source);
    final fallback = _localDiagnosis(
      event: event,
      thought: thought,
      action: action,
      safety: safety,
    );
    if (safety.blocksNormalFlow) {
      await _saveRun(
        agent: 'SafetyAgent',
        output: _diagnosisJson(fallback),
        config: null,
        status: 'blocked_by_safety',
        redacted: 0,
      );
      return BeliefMentorAiResult<BeliefMentorDiagnosis>(
        value: fallback,
        usedCloudAi: false,
        provider: 'local',
        model: 'safety-policy-v1',
        runStatus: 'blocked_by_safety',
        redactedCount: 0,
      );
    }

    final sanitized = BeliefMentorPrivacySanitizer.redact(<String, Object?>{
      'event': event,
      'automatic_thought': thought,
      'action_or_avoidance': action,
    });
    final config = await _ai.resolveGlobalConfig();
    if (!config.available) {
      await _saveRun(
        agent: 'DiagnosisAgent',
        output: _diagnosisJson(fallback),
        config: config,
        status: 'local_fallback_no_runtime_ai',
        redacted: sanitized.redactedCount,
      );
      return _localResult(
        fallback,
        status: 'local_fallback_no_runtime_ai',
        redacted: sanitized.redactedCount,
      );
    }

    final prompt = <String, Object?>{
      'input': sanitized.value,
      'required_output_schema': <String, Object?>{
        'facts': <String>[],
        'interpretations': <String>[],
        'emotions': <String>[],
        'behavior_tendencies': <String>[],
        'candidate_beliefs': <Map<String, Object?>>[
          <String, Object?>{
            'statement': 'string',
            'type': 'reality|capability|action|failure|relationship|identity',
            'trigger': 'string',
            'alternative': 'string',
            'confidence': 'number 0..1',
          },
        ],
        'risk_level': 'low|medium|high',
        'safety_message': 'string',
      },
    };
    try {
      final raw = await _ai.generateText(
        prompt: jsonEncode(prompt),
        purpose: 'belief_mentor.diagnosis',
        systemPrompt: _systemPrompt,
        maxTokens: 1500,
        expectJson: true,
        temperature: 0.1,
      );
      final decoded = _decodeObject(raw);
      final cloud = decoded == null ? null : _diagnosisFromJson(decoded);
      final valid =
          cloud != null &&
          cloud.candidates.length >= 3 &&
          cloud.candidates.length <= 5;
      final value = valid ? cloud : fallback;
      final status = valid ? 'success' : 'cloud_invalid_local_fallback';
      await _saveRun(
        agent: 'DiagnosisAgent',
        output: _diagnosisJson(value),
        config: config,
        status: status,
        redacted: sanitized.redactedCount,
      );
      return BeliefMentorAiResult<BeliefMentorDiagnosis>(
        value: value,
        usedCloudAi: valid,
        provider: valid ? config.provider : 'local',
        model: valid ? config.label : 'rule-engine-v1',
        runStatus: status,
        redactedCount: sanitized.redactedCount,
      );
    } catch (error) {
      await _saveRun(
        agent: 'DiagnosisAgent',
        output: _diagnosisJson(fallback),
        config: config,
        status: 'cloud_failed_local_fallback',
        redacted: sanitized.redactedCount,
        failure: error.toString(),
      );
      return BeliefMentorAiResult<BeliefMentorDiagnosis>(
        value: fallback,
        usedCloudAi: false,
        provider: 'local',
        model: 'rule-engine-v1',
        runStatus: 'cloud_failed_local_fallback',
        redactedCount: sanitized.redactedCount,
        failureMessage: error.toString(),
      );
    }
  }

  Future<BeliefMentorAiResult<BeliefMentorExperimentDraft>> generateExperiment({
    required BeliefMentorBelief belief,
    String context = '',
  }) async {
    final safety = BeliefMentorSafetyPolicy.assess(
      '$context\n${belief.statement}',
    );
    final fallback = _localExperiment(belief, context);
    if (safety.blocksNormalFlow) {
      return BeliefMentorAiResult<BeliefMentorExperimentDraft>(
        value: fallback,
        usedCloudAi: false,
        provider: 'local',
        model: 'safety-policy-v1',
        runStatus: 'blocked_by_safety',
        redactedCount: 0,
      );
    }
    final sanitized = BeliefMentorPrivacySanitizer.redact(<String, Object?>{
      'belief': belief.statement,
      'type': belief.type.name,
      'trigger': belief.trigger,
      'alternative': belief.alternativeStatement,
      'context': context,
    });
    final config = await _ai.resolveGlobalConfig();
    if (!config.available) {
      await _saveRun(
        agent: 'ActionAgent',
        output: _experimentJson(fallback),
        config: config,
        status: 'local_fallback_no_runtime_ai',
        redacted: sanitized.redactedCount,
      );
      return _localResult(
        fallback,
        status: 'local_fallback_no_runtime_ai',
        redacted: sanitized.redactedCount,
      );
    }
    try {
      final raw = await _ai.generateText(
        prompt: jsonEncode(<String, Object?>{
          'input': sanitized.value,
          'required_output_schema': <String, Object?>{
            'action': 'string',
            'minimum_version': 'string',
            'fallback_action': 'string',
            'difficulty': 'integer 1..10',
            'completion_probability': 'integer 0..100',
            'rationale': 'string',
          },
        }),
        purpose: 'belief_mentor.action_experiment',
        systemPrompt: _systemPrompt,
        maxTokens: 900,
        expectJson: true,
        temperature: 0.2,
      );
      final decoded = _decodeObject(raw);
      final draft = decoded == null ? null : _experimentFromJson(decoded);
      final valid =
          draft != null && BeliefMentorExperimentPolicy.validate(draft).isEmpty;
      var value = valid ? draft : fallback;
      if (BeliefMentorExperimentPolicy.shouldShrink(
        value.completionProbability,
      )) {
        value = BeliefMentorExperimentDraft(
          action: value.minimumVersion,
          minimumVersion: value.fallbackAction,
          fallbackAction: '只写下要测试的第一步，并为明天选一个时间',
          difficulty: (value.difficulty - 2).clamp(1, 10),
          completionProbability: (value.completionProbability + 25).clamp(
            50,
            90,
          ),
          rationale: '${value.rationale} 已按完成概率缩小为更安全的版本。',
        );
      }
      final status = valid ? 'success' : 'cloud_invalid_local_fallback';
      await _saveRun(
        agent: 'ActionAgent',
        output: _experimentJson(value),
        config: config,
        status: status,
        redacted: sanitized.redactedCount,
      );
      return BeliefMentorAiResult<BeliefMentorExperimentDraft>(
        value: value,
        usedCloudAi: valid,
        provider: valid ? config.provider : 'local',
        model: valid ? config.label : 'rule-engine-v1',
        runStatus: status,
        redactedCount: sanitized.redactedCount,
      );
    } catch (error) {
      await _saveRun(
        agent: 'ActionAgent',
        output: _experimentJson(fallback),
        config: config,
        status: 'cloud_failed_local_fallback',
        redacted: sanitized.redactedCount,
        failure: error.toString(),
      );
      return BeliefMentorAiResult<BeliefMentorExperimentDraft>(
        value: fallback,
        usedCloudAi: false,
        provider: 'local',
        model: 'rule-engine-v1',
        runStatus: 'cloud_failed_local_fallback',
        redactedCount: sanitized.redactedCount,
        failureMessage: error.toString(),
      );
    }
  }

  Future<BeliefMentorAiResult<BeliefMentorMentorReply>> mentorReply({
    required String message,
    BeliefMentorBelief? belief,
  }) async {
    final safety = BeliefMentorSafetyPolicy.assess(message);
    final fallback = _localReply(message, belief, safety);
    if (safety.blocksNormalFlow) {
      await _saveRun(
        agent: 'SafetyAgent',
        output: fallback.toJson(),
        config: null,
        status: 'blocked_by_safety',
        redacted: 0,
      );
      return _localResult(fallback, status: 'blocked_by_safety');
    }
    final sanitized = BeliefMentorPrivacySanitizer.redact(<String, Object?>{
      'message': message,
      if (belief != null) 'confirmed_belief': belief.statement,
      if (belief != null) 'belief_state': belief.state.name,
    });
    final config = await _ai.resolveGlobalConfig();
    if (!config.available)
      return _localResult(fallback, status: 'local_fallback_no_runtime_ai');
    try {
      final raw = await _ai.generateText(
        prompt: jsonEncode(<String, Object?>{
          'input': sanitized.value,
          'required_output_schema': <String, Object?>{
            'route': 'diagnosis|story|action|recovery|reflection',
            'observation': 'string',
            'inference': 'string',
            'next_action': 'string',
            'boundary': 'string',
          },
        }),
        purpose: 'belief_mentor.orchestrator',
        systemPrompt: _systemPrompt,
        maxTokens: 900,
        expectJson: true,
        temperature: 0.2,
      );
      final decoded = _decodeObject(raw);
      final reply = decoded == null ? null : _replyFromJson(decoded);
      final valid =
          reply != null &&
          reply.observation.isNotEmpty &&
          reply.nextAction.isNotEmpty;
      final value = valid ? reply : fallback;
      await _saveRun(
        agent: 'OrchestratorAgent',
        output: value.toJson(),
        config: config,
        status: valid ? 'success' : 'cloud_invalid_local_fallback',
        redacted: sanitized.redactedCount,
      );
      return BeliefMentorAiResult<BeliefMentorMentorReply>(
        value: value,
        usedCloudAi: valid,
        provider: valid ? config.provider : 'local',
        model: valid ? config.label : 'rule-engine-v1',
        runStatus: valid ? 'success' : 'cloud_invalid_local_fallback',
        redactedCount: sanitized.redactedCount,
      );
    } catch (error) {
      await _saveRun(
        agent: 'OrchestratorAgent',
        output: fallback.toJson(),
        config: config,
        status: 'cloud_failed_local_fallback',
        redacted: sanitized.redactedCount,
        failure: error.toString(),
      );
      return _localResult(
        fallback,
        status: 'cloud_failed_local_fallback',
        redacted: sanitized.redactedCount,
        failure: error.toString(),
      );
    }
  }

  BeliefMentorDiagnosis _localDiagnosis({
    required String event,
    required String thought,
    required String action,
    required BeliefMentorSafetyDecision safety,
  }) {
    if (safety.blocksNormalFlow) {
      return BeliefMentorDiagnosis(
        facts: event.trim().isEmpty ? const <String>[] : <String>[event.trim()],
        interpretations: const <String>[],
        emotions: const <String>[],
        behaviorTendencies: const <String>[],
        candidates: const <BeliefMentorCandidateBelief>[],
        riskLevel: safety.riskLevel,
        safetyMessage: safety.message,
      );
    }
    final lower = '$event $thought $action'.toLowerCase();
    final primaryType = lower.contains('失败') || lower.contains('搞砸')
        ? BeliefMentorBeliefType.failure
        : lower.contains('别人') || lower.contains('关系') || lower.contains('拒绝')
        ? BeliefMentorBeliefType.relationship
        : lower.contains('能力') || lower.contains('不会') || lower.contains('做不到')
        ? BeliefMentorBeliefType.capability
        : lower.contains('我就是') || lower.contains('我这种人')
        ? BeliefMentorBeliefType.identity
        : BeliefMentorBeliefType.action;
    final trigger = event.trim().isEmpty ? '遇到需要开始或被评价的时刻' : event.trim();
    final interpretation = thought.trim().isEmpty
        ? '我可能做不好，所以最好先不要开始'
        : thought.trim();
    final candidates = <BeliefMentorCandidateBelief>[
      BeliefMentorCandidateBelief(
        statement: interpretation,
        type: primaryType,
        trigger: trigger,
        alternative: '我不需要先证明自己一定成功，可以用一个小行动收集现实证据。',
        confidence: 0.62,
      ),
      BeliefMentorCandidateBelief(
        statement: '只有准备得足够好，行动才是安全的。',
        type: BeliefMentorBeliefType.action,
        trigger: trigger,
        alternative: '准备与行动可以交替进行，最小版本也能提供信息。',
        confidence: 0.48,
      ),
      BeliefMentorCandidateBelief(
        statement: '一次不理想的结果会说明我的能力或价值。',
        type: BeliefMentorBeliefType.failure,
        trigger: trigger,
        alternative: '一次结果只说明这次方法与情境，不足以定义能力或身份。',
        confidence: 0.41,
      ),
    ];
    return BeliefMentorDiagnosis(
      facts: event.trim().isEmpty ? const <String>[] : <String>[event.trim()],
      interpretations: <String>[interpretation],
      emotions: const <String>['紧张、担心或挫败（请按实际感受修改）'],
      behaviorTendencies: action.trim().isEmpty
          ? const <String>['可能推迟、回避或过度准备']
          : <String>[action.trim()],
      candidates: candidates,
      riskLevel: 'low',
      safetyMessage: '',
    );
  }

  BeliefMentorExperimentDraft _localExperiment(
    BeliefMentorBelief belief,
    String context,
  ) {
    final object = context.trim().isEmpty ? '一个低风险对象' : context.trim();
    return BeliefMentorExperimentDraft(
      action: '在 24 小时内，针对“${belief.statement}”向$object完成一次 10 分钟现实检验，并记录实际结果。',
      minimumVersion: '先花 2 分钟写出一句要问或要做的话，然后完成第一步。',
      fallbackAction: '如果暂时不能行动，给自己发一条草稿并约定下一个具体时间。',
      difficulty: 4,
      completionProbability: 75,
      rationale: '目标不是证明替代信念永远正确，而是取得一条可核验的新证据。',
    );
  }

  BeliefMentorMentorReply _localReply(
    String message,
    BeliefMentorBelief? belief,
    BeliefMentorSafetyDecision safety,
  ) {
    if (safety.blocksNormalFlow) {
      return BeliefMentorMentorReply(
        route: 'safety',
        observation: safety.message,
        inference: '',
        nextAction: '先暂停当前计划，联系当地紧急服务、危机热线或一位可信任的人，并尽量不要独处。',
        boundary: 'Belief Mentor 不能替代紧急援助或专业医疗支持。',
      );
    }
    final route = message.contains('失败') || message.contains('没做到')
        ? 'recovery'
        : message.contains('为什么')
        ? 'diagnosis'
        : 'action';
    return BeliefMentorMentorReply(
      route: route,
      observation: '你描述的是一个值得认真对待的具体时刻；先把发生了什么与对它的解释分开。',
      inference: belief == null
          ? '这里可能有一个关于行动、能力或失败的限制性信念，但需要你确认。'
          : '“${belief.statement}”可能正在影响这次选择，但它仍只是待检验的工作假设。',
      nextAction: route == 'recovery'
          ? '写下一个不带评价的事实，再把下一步缩小到两分钟以内。'
          : '选择一个 24 小时内、低风险、可记录结果的最小动作。',
      boundary: '一次结果不能定义你的能力、身份或未来。',
    );
  }

  BeliefMentorDiagnosis? _diagnosisFromJson(Map<String, dynamic> json) {
    final candidatesRaw = json['candidate_beliefs'];
    if (candidatesRaw is! List) return null;
    final candidates = <BeliefMentorCandidateBelief>[];
    for (final raw in candidatesRaw.take(5)) {
      if (raw is! Map) continue;
      final item = raw.map((key, value) => MapEntry(key.toString(), value));
      final statement = (item['statement'] ?? '').toString().trim();
      final alternative = (item['alternative'] ?? '').toString().trim();
      if (statement.isEmpty || alternative.isEmpty) continue;
      final confidence = _double(item['confidence']).clamp(0, 1).toDouble();
      candidates.add(
        BeliefMentorCandidateBelief(
          statement: statement,
          type: BeliefMentorBeliefTypeLabel.parse(item['type']),
          trigger: (item['trigger'] ?? '').toString().trim(),
          alternative: alternative,
          confidence: confidence,
        ),
      );
    }
    return BeliefMentorDiagnosis(
      facts: _strings(json['facts']),
      interpretations: _strings(json['interpretations']),
      emotions: _strings(json['emotions']),
      behaviorTendencies: _strings(json['behavior_tendencies']),
      candidates: candidates,
      riskLevel: (json['risk_level'] ?? 'low').toString(),
      safetyMessage: (json['safety_message'] ?? '').toString(),
    );
  }

  BeliefMentorExperimentDraft? _experimentFromJson(Map<String, dynamic> json) {
    final action = (json['action'] ?? '').toString().trim();
    final minimum = (json['minimum_version'] ?? '').toString().trim();
    final fallback = (json['fallback_action'] ?? '').toString().trim();
    if (action.isEmpty || minimum.isEmpty || fallback.isEmpty) return null;
    return BeliefMentorExperimentDraft(
      action: action,
      minimumVersion: minimum,
      fallbackAction: fallback,
      difficulty: _int(json['difficulty']).clamp(1, 10),
      completionProbability: _int(json['completion_probability']).clamp(0, 100),
      rationale: (json['rationale'] ?? '').toString().trim(),
    );
  }

  BeliefMentorMentorReply? _replyFromJson(Map<String, dynamic> json) {
    final observation = (json['observation'] ?? '').toString().trim();
    final nextAction = (json['next_action'] ?? '').toString().trim();
    if (observation.isEmpty || nextAction.isEmpty) return null;
    return BeliefMentorMentorReply(
      route: (json['route'] ?? 'reflection').toString(),
      observation: observation,
      inference: (json['inference'] ?? '').toString().trim(),
      nextAction: nextAction,
      boundary: (json['boundary'] ?? '这是待检验的暂定模型。').toString().trim(),
    );
  }

  Map<String, Object?> _diagnosisJson(BeliefMentorDiagnosis value) =>
      <String, Object?>{
        'facts': value.facts,
        'interpretations': value.interpretations,
        'emotions': value.emotions,
        'behavior_tendencies': value.behaviorTendencies,
        'candidate_beliefs': value.candidates
            .map(
              (item) => <String, Object?>{
                'statement': item.statement,
                'type': item.type.name,
                'trigger': item.trigger,
                'alternative': item.alternative,
                'confidence': item.confidence,
              },
            )
            .toList(growable: false),
        'risk_level': value.riskLevel,
        'safety_message': value.safetyMessage,
      };

  Map<String, Object?> _experimentJson(BeliefMentorExperimentDraft value) =>
      <String, Object?>{
        'action': value.action,
        'minimum_version': value.minimumVersion,
        'fallback_action': value.fallbackAction,
        'difficulty': value.difficulty,
        'completion_probability': value.completionProbability,
        'rationale': value.rationale,
      };

  Future<void> _saveRun({
    required String agent,
    required Map<String, Object?> output,
    required UnifiedAiResolvedConfig? config,
    required String status,
    required int redacted,
    String failure = '',
  }) => _dao.saveAgentRun(
    agent: agent,
    output: output,
    provider: config?.provider ?? 'local',
    model: config?.label ?? 'local-policy-v1',
    runStatus: status,
    redactedCount: redacted,
    failureMessage: failure,
  );

  BeliefMentorAiResult<T> _localResult<T>(
    T value, {
    required String status,
    int redacted = 0,
    String failure = '',
  }) => BeliefMentorAiResult<T>(
    value: value,
    usedCloudAi: false,
    provider: 'local',
    model: 'rule-engine-v1',
    runStatus: status,
    redactedCount: redacted,
    failureMessage: failure,
  );

  static Map<String, dynamic>? _decodeObject(String raw) {
    var text = raw.trim();
    if (!text.startsWith('{')) {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      text = text.substring(start, end + 1);
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return null;
    }
  }

  static List<String> _strings(Object? value) => value is List
      ? value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
      : const <String>[];

  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static double _double(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class BeliefMentorRedactionResult {
  const BeliefMentorRedactionResult(this.value, this.redactedCount);

  final Map<String, Object?> value;
  final int redactedCount;
}

class BeliefMentorPrivacySanitizer {
  const BeliefMentorPrivacySanitizer._();

  static final List<RegExp> _patterns = <RegExp>[
    RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
    RegExp(r'(?<!\d)(?:\+?\d[\d\s-]{7,}\d)(?!\d)'),
    RegExp(r'(?<!\d)\d{17}[0-9Xx](?!\d)'),
  ];

  static BeliefMentorRedactionResult redact(Map<String, Object?> input) {
    var count = 0;
    String clean(String text) {
      var result = text;
      for (final pattern in _patterns) {
        result = result.replaceAllMapped(pattern, (_) {
          count += 1;
          return '[已脱敏]';
        });
      }
      return result;
    }

    return BeliefMentorRedactionResult(
      input.map(
        (key, value) => MapEntry(key, value is String ? clean(value) : value),
      ),
      count,
    );
  }
}
