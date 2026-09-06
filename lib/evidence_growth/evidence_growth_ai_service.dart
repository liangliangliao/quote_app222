import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_knowledge.dart';
import 'evidence_growth_models.dart';
import 'evidence_growth_router.dart';
import 'evidence_growth_review_engine.dart';
import 'evidence_growth_search.dart';

class EvidenceGrowthAiService {
  EvidenceGrowthAiService({UnifiedAiService? ai, required EvidenceGrowthDao dao})
      : _ai = ai ?? UnifiedAiService(),
        _dao = dao;
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

  Future<EvidenceRouteResult> enrichRoute(EvidenceRouteResult route, {int attempt = 0}) async {
    if (!route.canAct || route.selectedNodes.isEmpty) return route;
    UnifiedAiResolvedConfig cfg;
    try { cfg = await _ai.resolveGlobalConfig(); } catch (_) { return route; }
    if (!cfg.available) return route;
    final id = 'eg_route_${DateTime.now().microsecondsSinceEpoch}';
    final started = DateTime.now();
    var valid = false;
    var error = '';
    try {
      final raw = await _ai.generateText(
        prompt: '''USER_FACTS:${jsonEncode(route.facts)}
LOCAL_ROUTE:${jsonEncode({'module': route.primaryModule.key, 'operator': route.operator, 'checks': route.requiredChecks, 'risk_gate': route.riskGate})}
PERSONAL_EVIDENCE（只是同类个人样本，不是公共真理）:${jsonEncode(route.personalEvidence)}
ALLOWED_K_NODES:${jsonEncode(route.selectedNodes.map((e) => e.toJson()).toList())}
只返回JSON：{"selected_nodes":[{"node_id":"..."}],"inference":"...","confidence":0.0,"operator":"...","action_instruction":"...","completion_definition":"...","risk_gate":"PASS|NEED_CHECK|BLOCK","review_trigger":"...","evidence_status":"E3|E2|E1|E0","alternatives":["..."]}''',
        purpose: 'evidence_growth.route',
        systemPrompt: _contract,
        maxTokens: 1000,
        expectJson: true,
        temperature: .12,
      ).timeout(const Duration(seconds:20));
      final map = _decode(raw);
      final allowedIds = route.selectedNodes.map((e) => e.id).toSet();
      final ids = _maps(map['selected_nodes']).map((e) => (e['node_id'] ?? '').toString()).where((e) => e.isNotEmpty).toList();
      if (ids.isEmpty || ids.any((e) => !allowedIds.contains(e))) throw const FormatException('UNROUTED_NODE');
      if (!EvidenceGrowthKnowledge.byId(ids.first)!.isTal) throw const FormatException('TAL_FIRST_REQUIRED');
      final op = (map['operator'] ?? '').toString();
      final allowedOps = ids.map(EvidenceGrowthKnowledge.byId).whereType<EvidenceKNode>().expand((e) => e.operators).toSet();
      if (!allowedOps.contains(op) || op != route.operator) throw const FormatException('UNSUPPORTED_OPERATOR');
      final gate = (map['risk_gate'] ?? '').toString().toUpperCase();
      if (!const {'PASS', 'NEED_CHECK', 'BLOCK'}.contains(gate)) throw const FormatException('INVALID_RISK_GATE');
      final evidence = (map['evidence_status'] ?? '').toString().toUpperCase();
      if (!const {'E3', 'E2', 'E1', 'E0'}.contains(evidence)) throw const FormatException('INVALID_EVIDENCE');
      if (evidence == 'E3' && ids.length > 1) throw const FormatException('SYNTHESIS_NOT_DIRECT');
      final action = (map['action_instruction'] ?? '').toString().trim();
      final completion = (map['completion_definition'] ?? '').toString().trim();
      if (action.isEmpty || completion.isEmpty || action.length > 360) throw const FormatException('INVALID_ACTION');
      final actionGate = const EvidenceGrowthRouter().route(action);
      if (const {'RUIN_RISK','PANIC_RISK','PROFESSIONAL_ESCALATION','NEEDS_MORE_FACTS'}.contains(actionGate.status)) {
        throw const FormatException('UNSAFE_GENERATED_ACTION');
      }
      final alternatives = _strings(map['alternatives']).take(3).toList();
      for (final alternative in alternatives) {
        if (alternative.length > 360 || const {'RUIN_RISK','PANIC_RISK','PROFESSIONAL_ESCALATION','NEEDS_MORE_FACTS'}
            .contains(const EvidenceGrowthRouter().route(alternative).status)) throw const FormatException('UNSAFE_ALTERNATIVE');
      }
      if ((map['inference'] ?? '').toString().trim().isEmpty || !_number(map['confidence'],double.nan).isFinite) {
        throw const FormatException('INCOMPLETE_INFERENCE');
      }
      valid = true;
      return route.copyWith(
        selectedNodes: ids.map((e) => EvidenceGrowthKnowledge.byId(e)!).toList(),
        status: evidence == 'E0' ? 'KB_EVIDENCE_INSUFFICIENT' : gate == 'BLOCK' ? 'PANIC_RISK' : route.status,
        riskGate: evidence == 'E0' ? 'NEED_CHECK' : gate,
        inference: (map['inference'] ?? route.inference).toString(),
        confidence: _number(map['confidence'], route.confidence).clamp(0, 1).toDouble(),
        operator: op,
        actionInstruction: action,
        completionDefinition: completion,
        reviewTrigger: (map['review_trigger'] ?? route.reviewTrigger).toString(),
        evidenceLevel: evidence,
        alternatives: alternatives,
      );
    } catch (e) {
      error = e is FormatException ? e.message : 'AI_REQUEST_FAILED';
      return attempt < 1 ? await enrichRoute(route,attempt:attempt+1) : route;
    } finally {
      await _dao.recordPromptRun(
        requestId: id,
        purpose: 'route',
        provider: cfg.provider,
        model: cfg.model,
        valid: valid,
        latencyMs: DateTime.now().difference(started).inMilliseconds,
        errorCode: error,
      ).catchError((Object _) {});
    }
  }

  Future<TrialReviewResult> review(RealityTrial trial, {int attempt = 0}) async {
    final fallback = localReview(trial);
    UnifiedAiResolvedConfig cfg;
    try { cfg = await _ai.resolveGlobalConfig(); } catch (_) { return fallback; }
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
RESULT_STATUS:${trial.resultStatus}
USER_MEASUREMENTS:${jsonEncode(trial.operatorInputs)}
DID_ACTION:${trial.didAction}（行动完成不等于预测成立，也不自动代表假设有效）
ALLOWED_K_NODES:${jsonEncode(nodes.map((e) => e.toJson()).toList())}
actual_facts 只能逐字复制 ACTUAL_FACTS 中的记录；不能添加观察或改写事实。
只返回JSON：{"prediction_original":"逐字复制","actual_facts":["..."],"prediction_error":"...","failure_class":"NO_FAILURE|NO_ACTION|NOT_CLASSIFIED|TOO_EARLY|INTELLIGENT|BASIC|COMPLEX|RUIN_RISK","learning":"...","rule_update":"...","decision":"ACT|ADJUST|EXIT|OBSERVE","next_change_one_variable":"...","knowledge_nodes_used":["..."]}''',
        purpose: 'evidence_growth.review',
        systemPrompt: _contract,
        maxTokens: 1100,
        expectJson: true,
        temperature: .1,
      ).timeout(const Duration(seconds:20));
      final map = _decode(raw);
      if (map['prediction_original'] != trial.prediction) {
        throw const FormatException('PREDICTION_INTEGRITY');
      }
      final allowedIds = nodes.map((e) => e.id).toSet();
      final used = _strings(map['knowledge_nodes_used']);
      if (used.isEmpty || used.any((e) => !allowedIds.contains(e))) throw const FormatException('UNROUTED_NODE');
      final decision = (map['decision'] ?? '').toString().toUpperCase();
      final failure = (map['failure_class'] ?? '').toString().toUpperCase();
      if (!const {'ACT', 'ADJUST', 'EXIT', 'OBSERVE'}.contains(decision)) throw const FormatException('INVALID_DECISION');
      if (!const {'NO_FAILURE', 'NO_ACTION', 'NOT_CLASSIFIED', 'TOO_EARLY', 'INTELLIGENT', 'BASIC', 'COMPLEX', 'RUIN_RISK'}.contains(failure)) {
        throw const FormatException('INVALID_FAILURE');
      }
      if (trial.resultStatus == 'OBSERVING' && decision != 'OBSERVE') throw const FormatException('OBSERVATION_WINDOW');
      if (trial.didAction != true && failure == 'INTELLIGENT') throw const FormatException('NO_ACTION_IS_NOT_EXPERIMENT');
      final actualFacts = _strings(map['actual_facts']);
      if (actualFacts.isEmpty || actualFacts.any((f)=>f!=trial.actualOutcome && f!=trial.unexpected)) throw const FormatException('FABRICATED_FACT');
      if (['prediction_error','learning','rule_update','next_change_one_variable']
          .any((key)=>(map[key]??'').toString().trim().isEmpty)) throw const FormatException('INCOMPLETE_REVIEW');
      final nextGate = const EvidenceGrowthRouter().route(map['next_change_one_variable'].toString());
      if (const {'RUIN_RISK','PANIC_RISK','PROFESSIONAL_ESCALATION','NEEDS_MORE_FACTS'}.contains(nextGate.status)) throw const FormatException('UNSAFE_NEXT_TRIAL');
      valid = true;
      return TrialReviewResult(
        predictionOriginal: trial.prediction,
        actualFacts: actualFacts,
        predictionError: (map['prediction_error'] ?? '').toString(),
        failureClass: failure,
        learning: (map['learning'] ?? '').toString(),
        ruleUpdate: (map['rule_update'] ?? '').toString(),
        decision: decision,
        nextChangeOneVariable: (map['next_change_one_variable'] ?? '').toString(),
        knowledgeNodeIds: used,
      );
    } catch (e) {
      error = e is FormatException ? e.message : 'AI_REQUEST_FAILED';
      return attempt < 1 ? await review(trial,attempt:attempt+1) : fallback;
    } finally {
      await _dao.recordPromptRun(
        requestId: id,
        purpose: 'review',
        provider: cfg.provider,
        model: cfg.model,
        valid: valid,
        latencyMs: DateTime.now().difference(started).inMilliseconds,
        errorCode: error,
      ).catchError((Object _) {});
    }
  }

  TrialReviewResult localReview(RealityTrial trial) => const EvidenceGrowthReviewEngine().review(trial);

  Future<String> answerGuide(String question) async {
    final text = question.trim();
    if (text.isEmpty) return '请问一个关于功能、流程、知识依据或如何填写的问题。';
    if (RegExp('怎么用|流程|如何开始|预测|退出|EXIT|提醒|如何填写|怎么填').hasMatch(text)) {
      return '实战输入现实问题 → 确认一个动作与知识依据 → 保存预测、概率和安全条件 → 行动并记录完成/部分/未做/中止 → 比较预测与实际 → ACT、ADJUST、EXIT 或继续观察。\n'
          '预测写“在何时看到什么”，结果只写已发生事实；EXIT 保存学习，ADJUST 只改一个变量。\n'
          '依据：KB35 A02、R01、C02；这些页面步骤属于产品设计。';
    }
    final gate = const EvidenceGrowthRouter().route(text);
    if (const {'RUIN_RISK','PANIC_RISK','PROFESSIONAL_ESCALATION','NEEDS_MORE_FACTS'}.contains(gate.status)) return gate.actionInstruction;
    final nodes = EvidenceGrowthSearch.current.search(text,talOnly:true,limit:3).map((e)=>e.node).toList();
    if (nodes.isEmpty) return '当前没有足够的 KB35 依据，请补充具体情境。';
    final fallback = '${nodes.first.title}：${nodes.first.claim}\n怎么做：${nodes.first.howTo.first}\n边界：${nodes.first.boundaries.first}\n来源：${nodes.first.locator.display}';
    try {
      final cfg = await _ai.resolveGlobalConfig();
      if (!cfg.available) return fallback;
      final raw = await _ai.generateText(
      prompt: '用户问题：${jsonEncode(text)}\n只依据：${jsonEncode(nodes.map((e) => e.toJson()).toList())}\n只返回 JSON：{"answer":"简短解释","node_ids":["使用的节点 ID"]}。答案属于 AI 解释，不得冒充原话。',
      purpose: 'evidence_growth.guide',
      systemPrompt: _contract,
      maxTokens: 650,
      temperature: .12,
      expectJson: true,
    ).timeout(const Duration(seconds:20));
      final data=_decode(raw), ids=_strings(_decode(raw)['node_ids']);
      if(ids.isEmpty || ids.any((id)=>!nodes.any((n)=>n.id==id)) || (data['answer']??'').toString().trim().isEmpty) return fallback;
      return 'AI 解释：${data['answer']}\n依据：${nodes.where((n)=>ids.contains(n.id)).map((n)=>'${n.title} · ${n.locator.display}').join('\n')}';
    } catch (_) { return fallback; }
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
