import 'evidence_growth_journey_models.dart';
import 'evidence_growth_knowledge_runtime.dart';
import 'evidence_growth_models.dart';

/// Provenance is assigned by application code, never trusted from the model.
class GrowthGuidance {
  static const origins = {
    'AI': 'AI 生成 · 待核对',
    'LOCAL_RULE': '本地规则',
    'KNOWLEDGE': '知识库原文／整理内容',
    'DEFAULT': '默认示例',
    'USER': '用户记录／确认',
    'UNKNOWN': '历史内容 · 来源未记录'
  };
  static String label(String? origin) => origins[origin] ?? origins['UNKNOWN']!;
  static const duties = <String, String>{
    'BELIEF': '分开事实、解释和可检验信念；说明依据、证据强弱、怎样检验与何时修正。不能把人格标签当事实。',
    'GOAL': '连接上游信念与目标；给可观察标准、可控过程、质量边界、核验时机与停止条件。探索只给待体验候选；核验逐项比较事实，不代用户宣布达成。',
    'ACTION': '根据当前计划、差距或积极意图给一个可执行可撤回的过程动作、预期信号、前提与停止条件；已有行动不得改写原预测。',
    'OUTCOME':
        '核对实际结果、对象与明确程度；行动完成不等于外部成功，成功不等于目标达成。未做不是能力反证；最多一个必要澄清。先尊重复盘准备度，不催学习。',
    'REVIEW':
        '保留原预测和实际事实；无事前预测明确缺失。给1至3个原因假设及支持/反对证据、学习、保留项与1至2个改变候选；比较当前批次与同目标历史反馈。',
    'CHANGE':
        '从确认的学习提出1至2处具体改变及检验信号。结构变化需新版计划，改目标需新合同；拒绝后不得劝说纠缠；证据不足可KEEP或NO_ACTION_YET。'
  };
  static const fields = <String, List<String>>{
    'BELIEF': [
      'belief',
      'belief_basis',
      'testable_belief',
      'belief_update_rule'
    ],
    'GOAL': [
      'criterion',
      'quality',
      'measurement',
      'review_gate',
      'stop_condition',
      'self_concordance',
      'statement',
      'belief'
    ],
    'ACTION': [
      'next_action',
      'expected_signal',
      'prerequisite',
      'stop_condition'
    ],
    'OUTCOME': ['classification', 'object_question', 'readiness_question'],
    'REVIEW': [
      'prediction_error',
      'cause_hypothesis',
      'learning',
      'keep',
      'change_candidate'
    ],
    'CHANGE': [
      'reason',
      'next_action',
      'belief_after',
      'change_object',
      'plan_change',
      'expected_signal'
    ]
  };
  static const next = {
    'BELIEF': 'GOAL',
    'GOAL': 'ACTION',
    'ACTION': 'OUTCOME',
    'OUTCOME': 'REVIEW',
    'REVIEW': 'CHANGE',
    'CHANGE': 'BELIEF_CHECKPOINT'
  };
  static String stage(GrowthJourney j, String purpose) =>
      purpose == 'contract' || purpose == 'candidate'
          ? 'GOAL'
          : purpose == 'plan' || purpose == 'change'
              ? 'CHANGE'
              : purpose == 'review'
                  ? 'REVIEW'
                  : EvidenceGrowthKnowledgeRuntime.stage(j.node);
  static bool deferred(GrowthJourney j) => const [
        'FACTS_ONLY',
        'DEFERRED',
        'RECOVERY_HOLD'
      ].contains(j.data['readiness']);
  static GrowthData local(GrowthJourney j, String at, String reason) => {
        'origin': 'LOCAL_RULE',
        'reason': reason,
        'stage': at,
        'journey_version': j.version,
        'summary': deferred(j)
            ? '已保留现实记录，按你选择的时机继续。现在无需提炼学习或改变。'
            : EvidenceGrowthKnowledgeRuntime.lessons[at]![0],
        'question':
            deferred(j) ? '' : EvidenceGrowthKnowledgeRuntime.lessons[at]![1],
        'interpretation': '',
        'next_step': '',
        'node_output': <String, dynamic>{},
        'evidence': []
      };
  static GrowthData validate(GrowthData v, GrowthJourney j, String at,
      List<EvidenceKNode> nodes, List<String> facts) {
    if (v['journey_id'] != j.id ||
        v['current_node'] != j.node ||
        v['stage'] != at ||
        v['next_node'] != next[at])
      throw const FormatException('GUIDANCE_WORKFLOW');
    final ids = growthStrings(v['node_ids']);
    if (ids.isEmpty ||
        ids.any((id) => !nodes.any((n) => n.id == id)) ||
        !nodes.firstWhere((n) => n.id == ids.first).isTal)
      throw const FormatException('GUIDANCE_SOURCE');
    final quotes = growthStrings(v['fact_quotes']);
    if (quotes.any((q) => q.trim().isEmpty || !facts.any((f) => f.contains(q))))
      throw const FormatException('GUIDANCE_FACT');
    String text(String key, int limit) {
      if (v[key] is! String || (v[key] as String).length > limit)
        throw FormatException('GUIDANCE_$key');
      return (v[key] as String).trim();
    }

    final output = growthMap(v['node_output']);
    if (output.isEmpty ||
        output.keys.any((k) => !fields[at]!.contains(k)) ||
        output.values.any((v) => v is! String || v.length > 600))
      throw const FormatException('GUIDANCE_OUTPUT');
    final result = <String, dynamic>{
      'stage': at,
      'journey_version': j.version,
      'summary': text('summary', 600),
      'interpretation': text('interpretation', 1200),
      'question': text('question', 200),
      'next_step': text('next_step', 600),
      'node_output': output,
      'fact_quotes': quotes,
      'node_ids': ids,
      'evidence': nodes
          .where((n) => ids.contains(n.id))
          .map((n) => n.toJson())
          .toList(),
      'evidence_level': 'E2',
      'next_node': next[at]
    };
    if (result['summary'] == '' || result['interpretation'] == '')
      throw const FormatException('GUIDANCE_INCOMPLETE');
    return result;
  }
}
