import 'dart:convert';

/// Product rules (PRD §§24,26,30), not quotations or psychological cutoffs.
class EvidenceGrowthWorkflows {
  static const commitments = <String, String>{
    'L1': '内部明确：目标与日期', 'L2': '时间结构：日历或固定时段',
    'L3': '现实准备：材料、路线、设备', 'L4': '可信见证：一位可信对象',
    'L5': '预约／提交：预约、报名或草稿', 'L6': '可承受成本：小额费用或预定',
    'L7': '公共交付：向真实受众发布',
  };
  static String normalizeCommitment(String value) => const {
    'PRIVATE':'L1','WITNESS':'L4','REVERSIBLE':'L6','PUBLIC':'L7',
  }[value] ?? value;
  static const layers = <String, String>{
    'friction':'参数／摩擦：正确和旧行为分别要几步？',
    'resources':'时间／资源：是否有时间、精力和必要资源？',
    'delay':'延迟：多久后才能看到结果？',
    'feedback':'反馈环：什么行为得到即时反馈或奖励？',
    'information':'信息可见性：何时能知道已经偏离？',
    'rules':'规则／激励：实际奖励和惩罚什么？',
    'goal':'系统目标：实际追求的和口头目标一致吗？',
    'assumption':'核心假设：什么默认信念在维持旧模式？',
  };

  static List<Map<String,dynamic>> rankedRisks(Map<String,dynamic> data) {
    final risks=(data['risks'] as List? ?? []).map((r)=>Map<String,dynamic>.from(r as Map)).toList();
    risks.sort((a,b) {
      final score=((b['probability'] as num? ?? 0)*(b['loss'] as num? ?? 0))
          .compareTo((a['probability'] as num? ?? 0)*(a['loss'] as num? ?? 0));
      return score != 0 ? score : (a['id'] as num).compareTo(b['id'] as num);
    });
    return risks;
  }

  static Map<String,dynamic> decode(String? json) =>
      json == null || json.isEmpty ? {} : Map<String,dynamic>.from(jsonDecode(json) as Map);

  static void validate(String operator, Map<String,String> inputs, {String commitment = ''}) {
    if(operator=='COMMITMENT_LADDER') {
      if(!commitments.containsKey(normalizeCommitment(commitment))) throw ArgumentError('请选择 L1–L7 承诺等级');
      for(final key in ['承诺内容与日期','退出方式','损失上限']) {
        if((inputs[key]??'').trim().isEmpty) throw ArgumentError('请填写$key');
      }
      if(inputs['目标已基本验证']!='true') throw ArgumentError('请先验证目标值得投入，再升级承诺');
    }
    if(!const {'PREMORTEM','SYSTEM_SCAN'}.contains(operator)) return;
    final d=decode(inputs['advanced_json']);
    bool filled(Object? v)=>v is String && v.trim().isNotEmpty;
    if(operator=='PREMORTEM') {
      final risks=rankedRisks(d);
      final count=(d['selected_count'] as num? ?? 0).toInt();
      if(risks.length!=5 || count<1 || count>3 ||
          (d['analysis_finished_ms'] as num? ?? 0)<=0 ||
          !const [30,90].contains(d['horizon_days'])) throw ArgumentError('请完成限时分析，列五个原因并选择前 1–3 项');
      for(final r in risks) {
        final p=r['probability'], l=r['loss'];
        if(!filled(r['reason']) || p is! num || !p.isFinite || p<0 || p>100 ||
            l is! num || !l.isFinite || l<1 || l>5) throw ArgumentError('每项风险需要原因、概率和损失评分');
      }
      for(final r in risks.take(count)) {
        if(!['prevention','signal','backup'].every((k)=>filled(r[k]))) {
          throw ArgumentError('选中风险必须分别填写预防动作、监测信号和备用方案');
        }
      }
    } else {
      final scans=Map<String,dynamic>.from(d['scans'] as Map? ?? {});
      if(!layers.keys.every((k)=>filled(scans[k])) || !layers.containsKey(d['layer']) ||
          d['controllable']!=true || !['owner','baseline','change','metric','next_action'].every((k)=>filled(d[k])) ||
          (d['window_days'] as num? ?? 0)<=0) {
        throw ArgumentError('请核查八层，选择一个可控层，并保存基线、单一变化、观察信号与行动');
      }
    }
  }

  static String action(String operator, Map<String,String> inputs) {
    final d=decode(inputs['advanced_json']);
    if(operator=='SYSTEM_SCAN') return '${d['next_action']}\n只改变：${d['change']}；'
        '观察 ${d['window_days']} 天：${d['metric']}。';
    if(operator=='PREMORTEM') return rankedRisks(d).take((d['selected_count'] as num).toInt())
        .map((r)=>'预防：${r['prevention']}\n监测：${r['signal']}\n触发时备用：${r['backup']}').join('\n\n');
    return '';
  }
}
