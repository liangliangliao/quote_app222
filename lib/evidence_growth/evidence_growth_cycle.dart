import 'dart:convert';
import 'evidence_growth_models.dart';

/// PRD §3, §15–17, §25–28; KB35 p62/145/158/194.
/// A cycle connects Reality Trials. Plans and learning remain versioned
/// interpretations; they never replace the user's observations or public KB.
class EvidenceGrowthCycle {
  static const planKeys = {'goal','current','gap','belief','belief_basis',
    'expected_signal','why_action','learning_applied'};
  static const updateKeys = {'belief_after','belief_reason','goal_progress',
    'next_goal','next_gap','change_target','change_reason','carry_forward'};
  static const targets = {'belief','goal','action','recovery','habit','rule','system','retain','observe','exit'};
  static const targetLabels = {'belief':'信念／解释','goal':'目标','action':'行动方法',
    'recovery':'恢复与接纳','habit':'习惯线索','rule':'行为规则','system':'环境与系统',
    'retain':'保留有效条件','observe':'补充观察','exit':'结束当前路线'};

  static Map<String,String> decode(String? raw) {
    try {
      final value=jsonDecode(raw??'{}');
      return value is Map ? value.map((k,v)=>MapEntry(k.toString(),v.toString())) : {};
    } catch(_) { return {}; }
  }
  static Map<String,String> checked(Object? raw, {bool update=false}) {
    if(raw is! Map) throw const FormatException('CYCLE_OBJECT_REQUIRED');
    final keys=update?updateKeys:planKeys;
    final result=<String,String>{};
    for(final key in keys) {
      final value=raw[key]??'';
      if(value is! String || value.length>600) throw const FormatException('INVALID_CYCLE_FIELD');
      result[key]=value.trim();
    }
    final required=update?['belief_reason','goal_progress','next_gap','change_target','change_reason','carry_forward']:
      ['goal','current','gap','expected_signal','why_action'];
    if(required.any((k)=>result[k]!.isEmpty)) throw const FormatException('INCOMPLETE_CYCLE');
    if(update && !targets.contains(result['change_target'])) throw const FormatException('INVALID_CHANGE_TARGET');
    return result;
  }
  static Map<String,String> plan(RealityTrial t) => decode(t.operatorInputs['cycle_plan_json']);
  static Map<String,String> update(RealityTrial t) => decode(t.operatorInputs['cycle_update_json']);
  static Map<String,String> confirmed(RealityTrial t) => decode(t.operatorInputs['cycle_confirmed_json']);
  static int round(RealityTrial t) => int.tryParse(t.operatorInputs['cycle_round']??'1')??1;

  static Map<String,String> nextPlan(RealityTrial t) {
    final p=plan(t), u=confirmed(t);
    return {
      'goal': (u['next_goal']??'').isNotEmpty ? u['next_goal']! : t.goalState,
      'current':t.actualOutcome,
      'gap':u['next_gap']??'',
      'belief':(u['belief_after']??'').isNotEmpty ? u['belief_after']! : p['belief']??'',
      'belief_basis':u['belief_reason']??p['belief_basis']??'',
      'expected_signal':'', // A new observation requires a new prediction.
      'why_action':'',
      'learning_applied':'${t.learning}\n已确认改变：${t.nextAction}',
    };
  }
  static Map<String,Object?> context(RealityTrial t) => {
    'trial_id':t.id,'round':round(t),'module':t.primaryModule.key,'nodes':t.nodeIds,
    'goal':t.goalState,'belief_before':plan(t)['belief']??'',
    'prediction_original':t.prediction,'action':t.actionInstruction,
    'did_action':t.didAction,'actual_outcome':t.actualOutcome,'unexpected':t.unexpected,
    'user_signals':{'shame':t.shameSignal,'image_exposure':t.imageExposureSignal},
    'learning_inference':t.learning,'confirmed_update':confirmed(t),
    'decision':t.decision,'confirmed_next_action':t.nextAction,
  };

  static Map<String,String> fallbackUpdate(RealityTrial t,String decision,String reason,String next) => {
    'belief_after':'', // No automatic positive belief or invented causal conclusion.
    'belief_reason':t.didAction==true?'只有本次情境的样本，尚不足以概括个人能力或一般规律。':'尚未实际检验原预测；未开始不能证明原信念成立。',
    'goal_progress':'依据实际记录判断进展：${t.actualOutcome}',
    'next_goal':'',
    'next_gap':decision=='ACT'?'在保留有效条件下继续观察能否重复':
      decision=='ADJUST'?(t.didAction==true?'区分方法和方向，确认一个可调整条件':'确认本轮没有开始的具体障碍'):
      decision=='EXIT'?'当前路线已结束；如有替代方向需重新核对目标与风险':'补足与目标有关的可观察信号',
    'change_target':decision=='ACT'?'retain':decision=='EXIT'?'exit':decision=='OBSERVE'?'observe':'action',
    'change_reason':reason,'carry_forward':next,
  };
}
