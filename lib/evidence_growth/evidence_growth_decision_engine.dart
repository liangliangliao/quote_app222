import 'evidence_growth_models.dart';

class EvidenceDecision {
  const EvidenceDecision(this.type,this.reason,this.next,{this.protective=false});
  final String type,reason,next;
  final bool protective;
}

/// PRD §28 / KB35 p158,190,191. These thresholds are transparent product
/// rules, not claims of causality or psychological diagnoses.
class EvidenceGrowthDecisionEngine {
  static EvidenceDecision evaluate(RealityTrial t,{List<RealityTrial> history=const [],DateTime? now}) {
    final m=t.operatorInputs;
    final time=(now??DateTime.now()).millisecondsSinceEpoch;
    final cost=double.tryParse(m['cost_spent']??''), budget=double.tryParse(m['cost_limit']??'');
    final reason=m['decision_evidence']?.trim()??'';
    final hasEvidence=reason.isNotEmpty;
    if(!t.nextRoundPreserved || !t.reversible || m['next_round_safe']=='false' || t.failureClass=='RUIN_RISK') {
      return const EvidenceDecision('EXIT','最坏损失威胁下一轮资格；先停止当前规模。',
        '保存本轮学习，关闭当前高风险路线；需要时另建可撤回、损失封顶的小试验。',protective:true);
    }
    if(hasEvidence && cost!=null && budget!=null && cost>=budget) {
      return EvidenceDecision('EXIT','已用成本 $cost 达到预设预算 $budget。依据：$reason',
        '保存结果和预算边界，停止当前路线；明确可承受的替代方案后另建试验。',protective:true);
    }
    if(hasEvidence && m['goal_fit']=='false') {
      return EvidenceDecision('EXIT','目标已不再符合当前价值或约束。依据：$reason','保存学习与目标变化，关闭该假设，选择更协调的方向。');
    }
    if(hasEvidence && m['alternative_better']=='true') {
      return EvidenceDecision('EXIT','已有明确替代路线及比较依据：$reason',
        '保存比较结果，结束当前路线；把替代路线变成下一次低风险试验。');
    }
    final due=t.nextReviewAtMs>0?t.nextReviewAtMs:t.reviewAtMs;
    if(t.resultStatus=='OBSERVING' || t.actualOutcome.trim().isEmpty ||
        (time<due && m['signal_final']!='true')) {
      return const EvidenceDecision('OBSERVE','观察窗口未完成，或还没有足够现实反馈，不能提前判定路线失败。',
        '保留原预测，到观察窗口结束补充约定的结果信号。');
    }
    final hypothesis=m['hypothesis_id']??t.id;
    final related={for(final h in history)
      if((h.operatorInputs['hypothesis_id']??h.id)==hypothesis)h.id:h, t.id:t}.values;
    final refutations=related.where((h)=>h.didAction==true && h.operatorInputs['hypothesis_support']=='refuted' &&
      (h.operatorInputs['decision_evidence']??'').trim().isNotEmpty && h.resultStatus!='OBSERVING' &&
      (h.operatorInputs['signal_final']=='true' || (h.resultAtMs>0 && h.resultAtMs>=h.reviewAtMs))).toList();
    if(hasEvidence && m['hypothesis_support']=='refuted' && refutations.length>=2 &&
        refutations.any((h)=>h.operatorInputs['method_changed']=='true')) {
      return EvidenceDecision('EXIT','同一核心假设在 ${refutations.length} 轮真实试验中被反证，且已经调整过策略。依据：$reason',
        '保存 Hypothesis Closed 与关键反证；停止原样投入，测试替代假设。');
    }
    if(t.didAction!=true) return const EvidenceDecision('ADJUST','本轮未做／中止是行动障碍信息，不能当作核心假设被证伪。',
      '只改变一个启动条件：先检查恢复、必要前提或情境摩擦，再安排下一步。');
    if(m['hypothesis_support']=='refuted' || m['outcome_helpful']=='false') {
      return EvidenceDecision('ADJUST',hasEvidence?'本轮有反证，先区分方法问题与方向问题。依据：$reason':'本轮没有正向结果，但尚无足够证据否定整条路线。',
        (m['proposed_change']??'').trim().isNotEmpty?m['proposed_change']!:
        t.failureClass=='BASIC' || m['failure_class']=='BASIC'?'只修复一个已识别的执行步骤或检查点，其余条件不变。':
        t.failureClass=='COMPLEX' || m['failure_class']=='COMPLEX'?'只改变一个可控的环境或反馈变量，记录前后差异。':
        '选择一个最有解释力且可逆的方法变量，明确改变内容，保留其余条件再取样。');
    }
    if(m['outcome_helpful']=='true' && m['hypothesis_support']!='refuted') {
      return const EvidenceDecision('ACT','已经观察到对目标有帮助的信号，且没有触发退出条件；继续采样而非宣布普遍有效。',
        '保持本轮有效条件，创建下一次现实试验并保存新的预测。');
    }
    return const EvidenceDecision('OBSERVE','已有行动事实，但不足以判断假设是否成立或目标是否推进。',
      '补一项可判断方向的现实证据，并约定下一次观察时间。');
  }
}
