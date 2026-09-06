import 'evidence_growth_knowledge.dart';
import 'evidence_growth_models.dart';
import 'evidence_growth_operator_registry.dart';

/// Local routing is deterministic and keeps high-impact gates outside the model.
class EvidenceGrowthRouter {
  const EvidenceGrowthRouter();
  static const _patterns = <(List<String>, String)>[
    (['没开始','拖延','等待动力','没有动力','等状态','投简历'], 'A02'),
    (['一直改','不敢发','怕拒绝','被拒绝','完美','不够好'], 'F01'),
    (['自动','一上床','短视频','习惯','环境','总忘记'], 'C05'),
    (['下一步','差距','目标明确','不知道今天'], 'G05'),
    (['失败说明','天生','不适合','我不行','一次失败'], 'F03'),
    (['复盘','只是感想','规则更新','预测和实际'], 'R01'),
    (['坚持两年','退出','没结果','该继续'], 'C02'),
    (['榜样','电影主角','完全像','照搬'], 'R-AUDIT-08'),
    (['换了很多方法','换很多方法','还是反复','系统结构','结构问题'], 'C05'),
    (['承诺','公开目标','背包过墙'], 'A05'),
    (['恐惧','不敢','焦虑','暴露'], 'A04'),
    (['积极思考','坏消息','一定成功','只要相信'], 'B02'),
    (['概率','肯定','绝不','可能性'], 'B01'),
    (['事实','解释','因果','造成','所以一定'], 'B01'),
    (['高期望','基准线'], 'B-AUDIT-01'),
    (['目标太多','舍弃','优先'], 'G-AUDIT-05'),
    (['真正想要','价值','目标','兴趣'], 'G03'),
    (['积极体验','重播','复现'], 'R03'),
    (['巨大','任务太大','缩小','第一步'], 'A-AUDIT-05'),
    (['反刍','停不下来','越想越'], 'R-AUDIT-01'),
    (['羞耻','自责','辱骂自己'], 'F-AUDIT-05'),
    (['重要项目','最可能失败','事前复盘'], 'G05'),
    (['压抑','不该难过','难受'], 'F-AUDIT-13'),
  ];

  EvidenceRouteResult route(String rawInput, {Map<String, double> personalFit = const {}}) {
    final text = rawInput.trim();
    if (text.length < 2) return _insufficient(text);
    if (_has(text, ['停药','药物剂量','自杀','伤害自己','伤害他人','医疗急救','法律诉讼',
        '自残','不想活','胸痛','呼吸困难','昏厥','严重创伤','投资建议','买什么股票'])) {
      return _stop(text, 'PROFESSIONAL_ESCALATION',
        '输入涉及专业或人身安全边界；当前知识库不支持处置建议。',
        '暂停当前干预，联系适当的专业支持；若有即时人身危险，联系当地紧急服务。');
    }
    if (_has(text, ['惊恐发作','恐慌发作','已经失控','无法呼吸','极度恐慌','焦虑10分','焦虑9分'])) {
      return _stop(text, 'PANIC_RISK', '当前已出现 Panic 信号，不适合继续暴露。',
        '停止本轮暴露，回到安全环境并寻求适当支持；恢复后再评估更小层级。');
    }
    if (_has(text, ['全部积蓄','借债','抵押房','孤注一掷','梭哈','没有退路','全部资源'])) {
      final tal = EvidenceGrowthKnowledge.source('A05');
      final ruin = EvidenceGrowthKnowledge.source('F-EXT2-02');
      return _stop(text, 'RUIN_RISK', '最坏损失可能破坏下一轮资格，不能开始本轮。',
        '暂停不可逆承诺；先改为损失封顶、可撤回、保留生活资源的试验。')
          .copyWith(selectedNodes: [tal, ruin], evidenceLevel: 'E2',
            reversible: false, nextRoundPreserved: false,
            worstCase: '不可逆资源或安全损失');
    }
    if (_has(text, ['辞职','离婚','签合同','大额投入','手术']) &&
        !_has(text, ['只做模拟','纸面模拟','不实际执行'])) {
      return _stop(text, 'NEEDS_MORE_FACTS', '高影响决定尚缺最坏结果、可逆性和专业前提。',
        '先补充损失上限、撤回方式、生活保障和必要的专业意见。')
          .copyWith(riskGate: 'NEED_CHECK');
    }
    final exhausted = _has(text, ['三天没睡','没睡好','没睡','耗竭','精疲力尽','通宵','特别累']);
    final candidates = <RoutedNode>[];
    for (final rule in _patterns) {
      final hits = rule.$1.where(text.contains).toList();
      if (hits.isEmpty) continue;
      final node = EvidenceGrowthKnowledge.source(rule.$2);
      final score = hits.fold<double>(0, (v, s) => v + (s.length >= 4 ? 3 : 2)) +
          (personalFit[node.id] ?? .5).clamp(0, 1);
      if (!candidates.any((c) => c.node.id == node.id)) {
        candidates.add(RoutedNode(node: node, score: score,
          reason: '情境命中：${hits.join('、')}；个人适配只在已匹配节点间重排'));
      }
    }
    // A learning-card application can select its exact source title.
    for (final node in EvidenceGrowthKnowledge.talNodes) {
      if (text.contains(node.title)) {
        candidates.add(RoutedNode(node: node, score: 50, reason: '用户明确应用该知识节点'));
      }
    }
    if (exhausted) {
      candidates.insert(0, RoutedNode(node: EvidenceGrowthKnowledge.source('A-AUDIT-01'),
        score: 100, reason: '先执行恢复前提检查'));
    }
    if (candidates.isEmpty) return _insufficient(text);
    candidates.sort((a,b) => b.score.compareTo(a.score));
    final selected = <EvidenceKNode>[candidates.first.node];
    String? gap;
    if (!exhausted) {
      if (_has(text, ['所以一定','造成的','因果','每次戴红帽'])) gap = 'B-EXT2-02';
      else if (_has(text, ['换了很多方法','换很多方法','还是反复','系统结构','结构问题'])) gap = 'C-EXT2-01';
      else if (_has(text, ['自动','一上床','手已经'])) gap = 'A-EXT2-01';
      else if (_has(text, ['目标明确','目标很明确']) && _has(text, ['下一步','差距'])) gap = 'G-EXT2-02';
      else if (_has(text, ['复盘很多','只是感想','复盘无效'])) gap = 'R-EXT2-01';
      else if (_has(text, ['怕他们发现','不能让他们看出','承认错误比','别人知道就完'])) gap = 'F-EXT2-01';
      else if (_has(text, ['重要项目','最可能失败','事前复盘'])) gap = 'R-EXT2-02';
      else if (_has(text, ['概率','事后改写','置信度'])) gap = 'B-EXT2-01';
      else if (_has(text, ['失败分类','复杂失败','聪明失败'])) gap = 'F-EXT-01';
      else if (_has(text, ['嘴上相信','实际规则'])) gap = 'C-EXT-02';
    }
    if (gap != null) {
      final node = EvidenceGrowthKnowledge.source(gap);
      selected.add(node);
      candidates.add(RoutedNode(node: node, score: 1,
        reason: 'Tal 主干之后的明确机制缺口：${node.mechanism}'));
    }
    var op = selected.last.operators.first;
    if (exhausted) op = 'RECOVER';
    // Dedicated primary mechanisms win over weaker incidental words.
    if (!exhausted && gap == null && _has(text, ['一直改','不敢发'])) {
      selected[0] = EvidenceGrowthKnowledge.source('F01'); op = 'SAFE_EXPOSURE';
    }
    if (!exhausted && text.contains('失败') && _has(text, ['天生','不适合','我不行']) && gap == null) {
      selected[0] = EvidenceGrowthKnowledge.source('F03'); op = 'FAILURE_REFRAME';
    }
    final spec = EvidenceGrowthOperatorRegistry.byId(op);
    return EvidenceRouteResult(
      rawInput: text, facts: ['用户原话：$text'],
      primaryModule: selected.first.module,
      secondaryModules: selected.skip(1).map((n)=>n.module).where((m)=>m!=selected.first.module).toSet().toList(),
      candidates: candidates, selectedNodes: selected,
      requiredChecks: selected.expand((n)=>n.prerequisites).toSet().toList(),
      status: 'READY_FOR_ACTION', riskGate: 'PASS',
      inference: '当前可先使用“${spec.label}”获得现实证据。该判断需由你的结果验证。',
      confidence: .7, operator: op,
      actionInstruction: op == 'SOURCE_PRACTICE' ? selected.first.howTo.first : spec.instruction,
      completionDefinition: spec.completion, reviewTrigger: spec.reviewTrigger,
      evidenceLevel: gap == null ? 'E3' : 'E2', alternatives: spec.alternatives,
      contextTags: [if(exhausted) 'RECOVERY', if(_has(text,['求职','简历','面试','工厂'])) 'WORK',
        if(_has(text,['自动','习惯','上床'])) 'HABIT',
        if(_has(text,['评价','不敢发','别人'])) 'EXPOSURE'],
      currentState: '用户描述待核实；行动前确认具体对象与条件。',
      topGap: spec.label,
      riskChecks: {'PROFESSIONAL_BOUNDARY':'NO_EXPLICIT_SIGNAL','RUIN_GATE':'NO_EXPLICIT_SIGNAL',
        'RECOVERY_CHECK': exhausted ? 'RECOVER_FIRST' : 'CONFIRM_BEFORE_START',
        'STRETCH_ZONE_CHECK':'CONFIRM_BEFORE_START'},
    );
  }

  EvidenceRouteResult _insufficient(String text) => _stop(text,
    'KB_EVIDENCE_INSUFFICIENT', '当前没有可靠的知识匹配，需补充现实信息。',
    '请说明要做的具体事情、已发生的事实和卡住的位置。')
    .copyWith(riskGate: 'NEED_CHECK');

  EvidenceRouteResult _stop(String text, String status, String inference, String action) =>
    EvidenceRouteResult(rawInput:text, facts:[if(text.isNotEmpty)'用户原话：$text'],
      primaryModule:GrowthModule.action, secondaryModules:const[], candidates:const[],
      selectedNodes:const[], requiredChecks:const['REALITY_CHECK','PROFESSIONAL_BOUNDARY','RUIN_GATE'],
      status:status, riskGate:'BLOCK', inference:inference, confidence:0,
      operator:'', actionInstruction:action, completionDefinition:'', reviewTrigger:'',
      evidenceLevel:'E0', alternatives:const[],
      missingFacts:const['具体行为','已有事实','当前约束'],
      riskChecks:{'GATE':status});
  bool _has(String text, List<String> words) => words.any(text.contains);
}
