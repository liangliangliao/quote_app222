import 'dart:math' as math;

import 'evidence_growth_knowledge.dart';
import 'evidence_growth_models.dart';

/// 规则先行的证据路由。安全门和来源优先级在调用大模型前完成。
class EvidenceGrowthRouter {
  const EvidenceGrowthRouter();

  static const Map<GrowthModule, List<String>> _signals = <GrowthModule, List<String>>{
    GrowthModule.belief: ['相信', '信念', '一定', '天生', '不适合', '解释', '自信', '期望'],
    GrowthModule.goal: ['目标', '方向', '选择', '优先', '意义', '下一步', '坚持', '退出', '差距'],
    GrowthModule.action: ['行动', '开始', '拖延', '没做', '不敢', '动力', '自动', '习惯', '投递', '榜样'],
    GrowthModule.failure: ['失败', '完美', '错误', '拒绝', '羞耻', '评价', '不够好', '复发'],
    GrowthModule.review: ['复盘', '反思', '结果', '实际', '预测', '意外', '经历', '反刍'],
    GrowthModule.change: ['改变', '旧模式', '环境', '反复', '恢复', '仪式', '系统', '复现'],
  };

  EvidenceRouteResult route(String rawInput) {
    final text = rawInput.trim();
    if (text.isEmpty || text.length < 2) {
      return _insufficient(text, ['请说明你要做什么、卡在哪里，以及最担心什么。']);
    }
    if (_has(text, ['停药', '药物剂量', '自杀', '伤害自己', '伤害他人', '医疗急救', '法律诉讼'])) {
      return _blocked(
        text,
        'PROFESSIONAL_ESCALATION',
        '输入涉及医疗、法律或人身安全边界，KB35 不足以支持处置建议。',
        '暂停高影响决定并联系当地适当的医疗、法律或紧急支持；本模块不生成成长干预。',
      );
    }
    if (_has(text, ['全部积蓄', '借债', '抵押房', '孤注一掷', '梭哈', '没有退路', '全部资源'])) {
      final tal = EvidenceGrowthKnowledge.byId('TAL-G04')!;
      final ruin = EvidenceGrowthKnowledge.byId('EXT2-F02')!;
      return EvidenceRouteResult(
        rawInput: text,
        facts: const ['用户明确描述了可能失去下一轮资格的高成本或不可逆行动。'],
        primaryModule: GrowthModule.failure,
        secondaryModules: const [GrowthModule.goal, GrowthModule.action],
        candidates: [
          RoutedNode(node: tal, score: 1, reason: 'Tal 的安全承诺边界适用'),
          RoutedNode(node: ruin, score: .99, reason: '命中 Ruin 窄范围护栏'),
        ],
        selectedNodes: [tal, ruin],
        requiredChecks: const ['RUIN_GATE'],
        status: 'RUIN_RISK',
        riskGate: 'BLOCK',
        inference: '本轮可能以不可逆损失破坏下一轮资格，不能把“置于线上”解释成豪赌。',
        confidence: .99,
        operator: 'ACT_ADJUST_EXIT',
        actionInstruction: '暂停不可逆承诺；把试验缩小到不借债、不辞职、损失封顶且失败后仍可再试的一轮。',
        completionDefinition: '写出一个可撤回、损失封顶、保留下一轮资格的替代版本。',
        reviewTrigger: '重新通过 Ruin Gate 后',
        evidenceLevel: 'E3',
        alternatives: const ['纸面模拟', '只投入可承受的小额预算', 'EXIT 并保存学习'],
      );
    }

    final scores = <GrowthModule, double>{};
    for (final module in GrowthModule.values) {
      scores[module] = _signals[module]!.fold<double>(
        0,
        (sum, word) => sum + (text.contains(word) ? (word.length >= 3 ? 1.4 : 1) : 0),
      );
    }
    final ranked = GrowthModule.values.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    final primary = scores[ranked.first] == 0 ? GrowthModule.action : ranked.first;
    final secondary = ranked.skip(1).where((m) => scores[m]! > 0).take(2).toList();

    final talCandidates = EvidenceGrowthKnowledge.talNodes
        .map((node) => RoutedNode(
              node: node,
              score: _score(node, text, primary, secondary),
              reason: _reason(node, text),
            ))
        .where((item) => item.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    if (talCandidates.isEmpty) {
      return _insufficient(text, ['当前描述无法可靠路由到 KB35；请补充具体行为和现实结果。']);
    }

    final selected = <EvidenceKNode>[talCandidates.first.node];
    if (talCandidates.length > 1 &&
        talCandidates[1].node.module != selected.first.module &&
        talCandidates[1].score >= talCandidates.first.score * .65) {
      selected.add(talCandidates[1].node);
    }
    final extensions = EvidenceGrowthKnowledge.extensionNodes
        .map((node) => RoutedNode(node: node, score: _explicit(node, text), reason: 'Tal 主干后仍命中明确机制缺口'))
        .where((item) => item.score >= 2)
        .toList()
      ..sort((a, b) {
        final pa = a.node.isExtension1 ? 2 : 1;
        final pb = b.node.isExtension1 ? 2 : 1;
        return pa == pb ? b.score.compareTo(a.score) : pb.compareTo(pa);
      });
    if (extensions.isNotEmpty) selected.add(extensions.first.node);

    final exhausted = _has(text, ['三天没睡', '没睡好', '明显耗竭', '精疲力尽', '发烧', '通宵']);
    if (exhausted) {
      final recovery = EvidenceGrowthKnowledge.byId('TAL-A02')!;
      selected.removeWhere((node) => node.id == recovery.id);
      selected.insert(0, recovery);
    }
    final failureIdentity = text.contains('失败') && _has(text, ['不适合', '我不行', '天生', '没用', '否定']);
    final structural = _has(text, ['换了很多方法', '换很多方法', '还是反复', '系统结构', '结构问题']);
    final operatorNode = extensions.isEmpty ? selected.first : extensions.first.node;
    final operator = exhausted
        ? 'RECOVER'
        : structural
            ? 'SYSTEM_SCAN'
            : failureIdentity
                ? 'FAILURE_REFRAME'
                : _chooseOperator(operatorNode, text);
    final action = _action(operator);
    return EvidenceRouteResult(
      rawInput: text,
      facts: _facts(text, exhausted),
      primaryModule: exhausted ? GrowthModule.action : primary,
      secondaryModules: secondary,
      candidates: [...talCandidates.take(5), ...extensions.take(2)],
      selectedNodes: selected,
      requiredChecks: selected.expand((node) => node.prerequisites).toSet().toList(),
      status: 'READY_FOR_ACTION',
      riskGate: 'PASS',
      inference: '${_inference(operator, primary)} 这是规则/AI 判断，不是 Tal 原话。',
      confidence: math.min(.93, .58 + talCandidates.first.score * .035),
      operator: operator,
      actionInstruction: action.instruction,
      completionDefinition: action.completion,
      reviewTrigger: action.review,
      evidenceLevel: selected.length > 1 ? 'E2' : 'E3',
      alternatives: action.alternatives,
    );
  }

  double _score(EvidenceKNode node, String text, GrowthModule primary, List<GrowthModule> secondary) {
    var score = node.module == primary ? 4.0 : (secondary.contains(node.module) ? 1.5 : 0);
    for (final trigger in node.triggers) {
      for (final word in trigger.split(RegExp(r'[，、 /]'))) {
        if (word.length >= 2 && text.contains(word)) score += word.length >= 4 ? 3 : 2;
      }
    }
    for (final op in node.operators) {
      if (op == 'START_5_MIN' && _has(text, ['没开始', '拖延', '动力'])) score += 7;
      if (op == 'SAFE_EXPOSURE' && _has(text, ['不敢发', '一直改', '被拒绝'])) score += 7;
      if (op == 'PDSA_REVIEW' && _has(text, ['复盘', '只是感想'])) score += 6;
      if (op == 'ACT_ADJUST_EXIT' && _has(text, ['坚持两年', '退出', '没结果'])) score += 7;
      if (op == 'GAP_OPERATOR' && _has(text, ['下一步', '不知道今天'])) score += 7;
      if (op == 'ROLE_MODEL_TRANSFER' && _has(text, ['榜样', '电影主角', '完全像'])) score += 8;
    }
    return score;
  }

  double _explicit(EvidenceKNode node, String text) {
    var score = 0.0;
    for (final trigger in node.triggers) {
      for (final word in trigger.split(RegExp(r'[，、 /]'))) {
        if (word.length >= 2 && text.contains(word)) score += 2;
      }
    }
    return score;
  }

  String _reason(EvidenceKNode node, String text) {
    final hits = node.triggers.where((t) => t.split(RegExp(r'[，、 /]')).any((w) => w.length >= 2 && text.contains(w))).take(2);
    return hits.isEmpty ? '模块结构匹配' : '现实语言命中：${hits.join('、')}';
  }

  String _chooseOperator(EvidenceKNode node, String text) {
    if (_has(text, ['没开始', '拖延', '等待动力']) && node.operators.contains('START_5_MIN')) return 'START_5_MIN';
    if (_has(text, ['一直改', '不敢发', '怕拒绝']) && node.operators.contains('SAFE_EXPOSURE')) return 'SAFE_EXPOSURE';
    if (_has(text, ['自动', '一上床', '习惯']) && node.operators.contains('CONTEXT_REDESIGN')) return 'CONTEXT_REDESIGN';
    return node.operators.isEmpty ? 'DIVIDE_NEXT_STEP' : node.operators.first;
  }

  ({String instruction, String completion, String review, List<String> alternatives}) _action(String op) {
    return switch (op) {
      'START_5_MIN' => (instruction: '现在只做 5 分钟：打开真正需要的材料并完成第一个可见动作；到点允许停。', completion: '已进入任务并留下可观察痕迹，不要求完成整件事。', review: '5 分钟后', alternatives: ['缩成 2 分钟', '只打开材料', '请一位可信的人见证开始']),
      'RECOVER' => (instruction: '先做 20 分钟明确恢复：停止输入、补水、闭眼或安静休息；结束后只重新进入原任务 2 分钟。', completion: '完成有起止时间的恢复，并检查能否重新进入。', review: '恢复窗口结束后', alternatives: ['先补完整睡眠', '降低今日强度', '暂停高风险决定']),
      'SAFE_EXPOSURE' => (instruction: '把一个 80% 版本交给 1 位可信且风险低的对象，本轮只获取 1 条具体反馈。', completion: '真实发送、展示或提出请求并记录回应。', review: '回应出现或窗口到期后', alternatives: ['只展示局部草稿', '选择更安全对象', '降低受众数量']),
      'CONTEXT_REDESIGN' => (instruction: '只改一个环境变量：让正确行为少一步，或让旧行为多一步；保持 7 天观察。', completion: '一个线索或摩擦已改变，并记录三次重复情境。', review: '7 天或出现 3 次情境后', alternatives: ['移除旧线索', '提前放好工具', '增加可见反馈']),
      'GAP_OPERATOR' || 'DIVIDE_NEXT_STEP' => (instruction: '各写一句目标状态、当前状态和最大差距，只做一个能让差距今天变小的动作。', completion: '产生现实输出或反馈，而非新增巨大清单。', review: '动作完成后', alternatives: ['先补必要前提', '缩到 10 分钟', '删除无关任务']),
      'FAILURE_REFRAME' || 'FAILURE_CLASSIFY' => (instruction: '把结果分成“事实、失败类型、新信息”三栏，只提取一条下一轮能验证的信息。', completion: '结果与身份分开，并形成一个可检验变化。', review: '分类完成后', alternatives: ['检查是否观察过早', '修一个流程', '缩小下一轮']),
      'PDSA_REVIEW' => (instruction: '用四行记录：原预测、实际事实、最大差异、下一轮只改变的一个变量。', completion: '保留原预测并形成可执行规则更新。', review: '现在完成', alternatives: ['先分开事实与解释', '重播积极经验', '情绪过强先恢复']),
      'ACT_ADJUST_EXIT' => (instruction: '整理有效信号、关键反证和继续成本，据此选择 ACT、ADJUST 或 EXIT。', completion: '保存决定、理由与下一动作或 Hypothesis Closed。', review: '证据整理完成后', alternatives: ['ACT：再取一个样本', 'ADJUST：只改一个变量', 'EXIT：保存学习']),
      'ROLE_MODEL_TRANSFER' => (instruction: '只提取榜样的一个具体行为，写出它依赖的条件与自己的差异，再测试最小迁移动作。', completion: '完成机制迁移，而不是复制整个人生。', review: '最小迁移动作完成后', alternatives: ['降低强度', '只保留机制', '选择起点更相近的榜样']),
      'PREMORTEM' => (instruction: '限时 7 分钟：假设项目已失败，列 5 个原因；只为概率×损失最高的一项设置护栏。', completion: '产生一个预防动作和一个早期信号，然后停止分析。', review: '7 分钟到点', alternatives: ['降低规模', '设置备用方案', '延迟不可逆承诺']),
      'CAUSAL_LEVEL_CHECK' => (instruction: '把结论标成“观察到关联”，设计只改变一个变量的低风险小测试，暂不宣布因果。', completion: '保存关联、干预和测试结果。', review: '完成一轮干预观察后', alternatives: ['继续收集样本', '寻找共同原因', '保持为假设']),
      'SYSTEM_SCAN' => (instruction: '在参数、信息、规则、目标中只选择一层和一个变量做实验，不同时重构全部系统。', completion: '一个系统变量已改变并有明确观察窗口。', review: '窗口到期后', alternatives: ['先查信息流', '先查规则', '先查反馈延迟']),
      _ => (instruction: '把当前问题缩成一个低风险、可撤回、能留下现实反馈的动作并立即执行。', completion: '动作产生一个可观察事实。', review: '结果出现后', alternatives: ['缩小动作', '补必要前提', '设置观察窗口']),
    };
  }

  String _inference(String op, GrowthModule module) => switch (op) {
        'START_5_MIN' => '当前更像 0→1 启动摩擦，而不是缺少更多理论。',
        'RECOVER' => '当前有耗竭信号，应先恢复再判断是否仍是拖延。',
        'SAFE_EXPOSURE' => '卡点更可能是进入现实评价，而不是准备程度。',
        'PDSA_REVIEW' => '缺口是连接预测、实际和下一变化，而非再写感想。',
        'ACT_ADJUST_EXIT' => '需要依据证据决定继续、调整或结束，而不是默认坚持。',
        _ => '当前主要落在${module.label}环节，先用最小现实动作获得新证据。',
      };

  List<String> _facts(String text, bool exhausted) => <String>[
        '用户原话：$text',
        if (_has(text, ['没开始', '没做', '拖延'])) '用户明确报告尚未进入目标行为。',
        if (_has(text, ['失败', '拒绝', '结果'])) '用户明确提到现实结果或失败信号。',
        if (exhausted) '用户明确报告睡眠或耗竭信号。',
      ];

  EvidenceRouteResult _insufficient(String text, List<String> missing) => EvidenceRouteResult(
        rawInput: text,
        facts: text.isEmpty ? const [] : ['用户原话：$text'],
        primaryModule: GrowthModule.action,
        secondaryModules: const [],
        candidates: const [],
        selectedNodes: const [],
        requiredChecks: const [],
        status: 'KB_EVIDENCE_INSUFFICIENT',
        riskGate: 'NEED_CHECK',
        inference: '信息不足，不能把模型常识伪装成 KB35 正式建议。',
        confidence: 0,
        operator: '',
        actionInstruction: '',
        completionDefinition: '',
        reviewTrigger: '',
        evidenceLevel: 'E0',
        alternatives: const [],
        missingFacts: missing,
      );

  EvidenceRouteResult _blocked(String text, String status, String inference, String action) => EvidenceRouteResult(
        rawInput: text,
        facts: ['用户原话：$text'],
        primaryModule: GrowthModule.change,
        secondaryModules: const [],
        candidates: const [],
        selectedNodes: const [],
        requiredChecks: const ['PROFESSIONAL_BOUNDARY'],
        status: status,
        riskGate: 'BLOCK',
        inference: inference,
        confidence: 1,
        operator: '',
        actionInstruction: action,
        completionDefinition: '已转向适当的专业或紧急支持。',
        reviewTrigger: '',
        evidenceLevel: 'E0',
        alternatives: const [],
      );

  bool _has(String text, List<String> words) => words.any(text.contains);
}
