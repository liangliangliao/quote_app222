import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_knowledge.dart';
import 'evidence_growth_models.dart';

class EvidenceGrowthAiService {
  EvidenceGrowthAiService({UnifiedAiService? ai, EvidenceGrowthDao? dao})
      : _ai = ai ?? UnifiedAiService(),
        _dao = dao ?? EvidenceGrowthDao();
  final UnifiedAiService _ai;
  final EvidenceGrowthDao _dao;

  static const String _contract = '''
你是六模块证据驱动运行时，不是自由发挥的心理建议机器人。
正式解释只能来自给定 K-Nodes；不得伪造 Tal 原话或 node_id。
来源顺序固定 K_TAL > K_EXT1 > K_EXT2；Tal 足够时停止扩展。
必须分开 USER_FACT、KNOWLEDGE_EVIDENCE、AI_INFERENCE、ACTION。
服从 prerequisite、contra_signals、Panic/Ruin/专业边界；不得降级硬风险门。
证据不足返回 KB_EVIDENCE_INSUFFICIENT。只输出结构化结果，不输出思维过程。
''';

  Future<EvidenceRouteResult> enrichRoute(EvidenceRouteResult route) async {
    if (!route.canAct || route.selectedNodes.isEmpty) return route;
    final cfg = await _ai.resolveGlobalConfig();
    if (!cfg.available) return route;
    final id = 'eg_route_${DateTime.now().microsecondsSinceEpoch}';
    final started = DateTime.now();
    var valid = false;
    var error = '';
    try {
      final raw = await _ai.generateText(
        prompt: '''USER_FACTS:${jsonEncode(route.facts)}
LOCAL_ROUTE:${jsonEncode({'module': route.primaryModule.key, 'checks': route.requiredChecks, 'risk_gate': route.riskGate})}
ALLOWED_K_NODES:${jsonEncode(route.selectedNodes.map((e) => e.toJson()).toList())}
只返回JSON：{"selected_nodes":[{"node_id":"..."}],"inference":"...","confidence":0.0,"operator":"...","action_instruction":"...","completion_definition":"...","risk_gate":"PASS|NEED_CHECK|BLOCK","review_trigger":"...","evidence_status":"E3|E2|E1|E0","alternatives":["..."]}''',
        purpose: 'evidence_growth.route',
        systemPrompt: _contract,
        maxTokens: 1000,
        expectJson: true,
        temperature: .12,
      );
      final map = _decode(raw);
      final allowedIds = route.selectedNodes.map((e) => e.id).toSet();
      final ids = _maps(map['selected_nodes']).map((e) => (e['node_id'] ?? '').toString()).where((e) => e.isNotEmpty).toList();
      if (ids.isEmpty || ids.any((e) => !allowedIds.contains(e))) throw const FormatException('UNROUTED_NODE');
      final op = (map['operator'] ?? '').toString();
      final allowedOps = route.selectedNodes.expand((e) => e.operators).toSet()..add(route.operator);
      if (!allowedOps.contains(op)) throw const FormatException('UNSUPPORTED_OPERATOR');
      final gate = (map['risk_gate'] ?? '').toString().toUpperCase();
      if (!const {'PASS', 'NEED_CHECK', 'BLOCK'}.contains(gate)) throw const FormatException('INVALID_RISK_GATE');
      final evidence = (map['evidence_status'] ?? '').toString().toUpperCase();
      if (!const {'E3', 'E2', 'E1', 'E0'}.contains(evidence)) throw const FormatException('INVALID_EVIDENCE');
      final action = (map['action_instruction'] ?? '').toString().trim();
      final completion = (map['completion_definition'] ?? '').toString().trim();
      if (action.isEmpty || completion.isEmpty || action.length > 360) throw const FormatException('INVALID_ACTION');
      valid = true;
      return route.copyWith(
        selectedNodes: ids.map((e) => EvidenceGrowthKnowledge.byId(e)!).toList(),
        status: gate == 'BLOCK' ? 'PANIC_RISK' : route.status,
        riskGate: gate,
        inference: (map['inference'] ?? route.inference).toString(),
        confidence: _number(map['confidence'], route.confidence).clamp(0, 1).toDouble(),
        operator: op,
        actionInstruction: action,
        completionDefinition: completion,
        reviewTrigger: (map['review_trigger'] ?? route.reviewTrigger).toString(),
        evidenceLevel: evidence,
        alternatives: _strings(map['alternatives']).take(3).toList(),
      );
    } catch (e) {
      error = e.toString();
      return route;
    } finally {
      await _dao.recordPromptRun(
        requestId: id,
        purpose: 'route',
        provider: cfg.provider,
        model: cfg.model,
        valid: valid,
        latencyMs: DateTime.now().difference(started).inMilliseconds,
        errorCode: error,
      );
    }
  }

  Future<TrialReviewResult> review(RealityTrial trial) async {
    final fallback = localReview(trial);
    final cfg = await _ai.resolveGlobalConfig();
    if (!cfg.available) return fallback;
    final nodes = trial.nodeIds.map(EvidenceGrowthKnowledge.byId).whereType<EvidenceKNode>().toList();
    if (nodes.isEmpty) return fallback;
    final id = 'eg_review_${DateTime.now().microsecondsSinceEpoch}';
    final started = DateTime.now();
    var valid = false;
    var error = '';
    try {
      final raw = await _ai.generateText(
        prompt: '''ORIGINAL_PREDICTION（禁止改写）:${jsonEncode(trial.prediction)}
PROBABILITY:${trial.probability}
ACTUAL_FACTS:${jsonEncode([trial.actualOutcome, if (trial.unexpected.isNotEmpty) trial.unexpected])}
DID_ACTION:${trial.didAction}
ALLOWED_K_NODES:${jsonEncode(nodes.map((e) => e.toJson()).toList())}
只返回JSON：{"prediction_original":"逐字复制","actual_facts":["..."],"prediction_error":"...","failure_class":"NO_FAILURE|TOO_EARLY|INTELLIGENT|BASIC|COMPLEX|RUIN_RISK","learning":"...","rule_update":"...","decision":"ACT|ADJUST|EXIT|OBSERVE","next_change_one_variable":"...","knowledge_nodes_used":["..."]}''',
        purpose: 'evidence_growth.review',
        systemPrompt: _contract,
        maxTokens: 1100,
        expectJson: true,
        temperature: .1,
      );
      final map = _decode(raw);
      if ((map['prediction_original'] ?? '').toString().trim() != trial.prediction.trim()) {
        throw const FormatException('PREDICTION_INTEGRITY');
      }
      final allowedIds = nodes.map((e) => e.id).toSet();
      final used = _strings(map['knowledge_nodes_used']);
      if (used.isEmpty || used.any((e) => !allowedIds.contains(e))) throw const FormatException('UNROUTED_NODE');
      final decision = (map['decision'] ?? '').toString().toUpperCase();
      final failure = (map['failure_class'] ?? '').toString().toUpperCase();
      if (!const {'ACT', 'ADJUST', 'EXIT', 'OBSERVE'}.contains(decision)) throw const FormatException('INVALID_DECISION');
      if (!const {'NO_FAILURE', 'TOO_EARLY', 'INTELLIGENT', 'BASIC', 'COMPLEX', 'RUIN_RISK'}.contains(failure)) {
        throw const FormatException('INVALID_FAILURE');
      }
      valid = true;
      return TrialReviewResult(
        predictionOriginal: trial.prediction,
        actualFacts: _strings(map['actual_facts']),
        predictionError: (map['prediction_error'] ?? '').toString(),
        failureClass: failure,
        learning: (map['learning'] ?? '').toString(),
        ruleUpdate: (map['rule_update'] ?? '').toString(),
        decision: decision,
        nextChangeOneVariable: (map['next_change_one_variable'] ?? '').toString(),
        knowledgeNodeIds: used,
      );
    } catch (e) {
      error = e.toString();
      return fallback;
    } finally {
      await _dao.recordPromptRun(
        requestId: id,
        purpose: 'review',
        provider: cfg.provider,
        model: cfg.model,
        valid: valid,
        latencyMs: DateTime.now().difference(started).inMilliseconds,
        errorCode: error,
      );
    }
  }

  TrialReviewResult localReview(RealityTrial trial) {
    final did = trial.didAction == true;
    final actual = trial.actualOutcome.trim();
    final tooEarly = actual.isEmpty || (DateTime.now().millisecondsSinceEpoch < trial.reviewAtMs && actual.length < 4);
    final failure = tooEarly ? 'TOO_EARLY' : did ? 'NO_FAILURE' : trial.operator == 'SAFE_EXPOSURE' ? 'INTELLIGENT' : 'BASIC';
    final decision = tooEarly ? 'OBSERVE' : did ? 'ACT' : 'ADJUST';
    return TrialReviewResult(
      predictionOriginal: trial.prediction,
      actualFacts: [if (actual.isNotEmpty) actual, if (trial.unexpected.isNotEmpty) trial.unexpected],
      predictionError: tooEarly
          ? '观察窗口尚未结束，不能把“还没有结果”分类成失败。'
          : '原预测是“${trial.prediction}”；实际记录是“${actual.isEmpty ? '尚无结果' : actual}”。',
      failureClass: failure,
      learning: did ? '现实中已出现行动证据；下一轮保留有效结构。' : '未进入或中止也是事实证据；不能伪造成完成。',
      ruleUpdate: did ? '保留帮助行动发生的一个条件。' : '下一轮只降低动作尺度或改变一个触发条件。',
      decision: decision,
      nextChangeOneVariable: did ? '在相同条件下再取一个现实样本。' : '把动作缩小一半后再试一次。',
      knowledgeNodeIds: trial.nodeIds,
    );
  }

  Future<String> answerGuide(String question) async {
    final text = question.trim();
    if (text.isEmpty) return '请问一个关于功能、流程、知识依据或如何填写的问题。';
    final nodes = EvidenceGrowthKnowledge.nodes.where((node) {
      return text.split(RegExp(r'[，。？！、\s]')).where((e) => e.length >= 2).any(node.embeddingText.contains);
    }).take(4).toList();
    if (nodes.isEmpty) return '当前没有足够的 KB35 依据，请补充具体情境。';
    final cfg = await _ai.resolveGlobalConfig();
    if (!cfg.available) return '${nodes.first.title}：${nodes.first.claim}\n怎么做：${nodes.first.operators.first}\n边界：${nodes.first.boundaries.first}';
    final raw = await _ai.generateText(
      prompt: '用户问题：${jsonEncode(text)}\n只依据：${jsonEncode(nodes.map((e) => e.toJson()).toList())}\n用“回答/依据/怎么做/边界”简短回答。',
      purpose: 'evidence_growth.guide',
      systemPrompt: _contract,
      maxTokens: 650,
      temperature: .12,
    );
    return raw.trim().isEmpty ? 'AI 暂不可用；学习与 Trial 仍可离线使用。' : raw.trim();
  }

  Map<String, dynamic> _decode(String raw) {
    var text = raw.trim().replaceFirst(RegExp(r'^```(?:json)?\s*'), '').replaceFirst(RegExp(r'\s*```$'), '');
    final first = text.indexOf('{');
    final last = text.lastIndexOf('}');
    if (first >= 0 && last > first) text = text.substring(first, last + 1);
    final decoded = jsonDecode(text);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
  }
  List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];
  List<String> _strings(Object? value) => value is List
      ? value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
      : <String>[];
  double _number(Object? value, double fallback) => value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
}
