import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../pages/ai_prompt_settings_page.dart';
import 'self_determination_growth_prompt_config.dart';

enum MotivationStage { amotivation, external, introjected, identified, integrated, intrinsic }

extension MotivationStageLabel on MotivationStage {
  String get label => switch (this) {
        MotivationStage.amotivation => '无动机',
        MotivationStage.external => '外部调节',
        MotivationStage.introjected => '内摄调节',
        MotivationStage.identified => '认同调节',
        MotivationStage.integrated => '整合调节',
        MotivationStage.intrinsic => '内在动机',
      };
}

class SdgNeedSnapshot {
  final int autonomy;
  final int competence;
  final int relatedness;

  const SdgNeedSnapshot({required this.autonomy, required this.competence, required this.relatedness});

  int get risk => 100 - ((autonomy + competence + relatedness) / 3).round();
  String get lowestNeed => autonomy <= competence && autonomy <= relatedness ? '自主感' : competence <= relatedness ? '胜任感' : '关系感';
}

class SdgGoalAnalysis {
  final String reconstructedGoal;
  final MotivationStage stage;
  final int intrinsicScore;
  final int extrinsicScore;
  final String minimumAction;
  final String failureRecovery;
  final String identitySentence;
  final List<String> abilityTree;
  final List<String> signals;

  const SdgGoalAnalysis({
    required this.reconstructedGoal,
    required this.stage,
    required this.intrinsicScore,
    required this.extrinsicScore,
    required this.minimumAction,
    required this.failureRecovery,
    required this.identitySentence,
    required this.abilityTree,
    required this.signals,
  });
}

class SelfDeterminationGrowthEngine {
  static const globalPrompt = '''
你是一个基于 Ryan 与 Deci 自我决定理论的 AI 成长教练。所有建议必须支持自主感、胜任感和关系感，避免羞辱、恐吓、排名焦虑和控制式命令。失败不是人格缺陷，而是系统反馈；目标需要从外控、内摄逐步转向认同、整合与内在动机。
''';

  static SdgNeedSnapshot scoreNeeds(List<double> values) {
    int avg(List<double> xs) => xs.isEmpty
        ? 50
        : (xs.reduce((a, b) => a + b) / xs.length)
            .round()
            .clamp(0, 100)
            .toInt();
    final autonomy = avg([values[0], values[1], 100 - values[2]]);
    final competence = avg([values[3], values[4], values[5]]);
    final relatedness = avg([values[6], values[7], 100 - values[8]]);
    return SdgNeedSnapshot(autonomy: autonomy, competence: competence, relatedness: relatedness);
  }

  static SdgGoalAnalysis analyzeGoal({required String goal, required String reason, required String identity}) {
    final text = '$goal $reason $identity'.toLowerCase();
    int hits(List<String> words) => words.where((w) => text.contains(w.toLowerCase())).length;
    final intrinsic = 38 + hits(['成长', '健康', '学习', '关系', '贡献', '创造', '意义', '自由', '尊严', '责任', '爱', '自我实现']) * 8;
    final extrinsic = 22 + hits(['钱', '财富', '名声', '外貌', '地位', '权力', '羡慕', '报复', '证明', '看得起', '排名', '别人']) * 9;
    final shame = hits(['废物', '羞耻', '内疚', '必须', '应该', '失败者', '后悔']) > 0;
    final stage = shame
        ? MotivationStage.introjected
        : extrinsic > intrinsic
            ? MotivationStage.external
            : identity.trim().isNotEmpty
                ? MotivationStage.integrated
                : MotivationStage.identified;
    final cleanGoal = goal.trim().isEmpty ? '推进一个重要目标' : goal.trim();
    final reconstructed = '我选择通过“$cleanGoal”的持续小行动，建立真实能力、生活自主权与更稳定的身份；外部评价可以作为背景信息，但不再成为行动中心。';
    return SdgGoalAnalysis(
      reconstructedGoal: reconstructed,
      stage: stage,
      intrinsicScore: intrinsic.clamp(0, 100).toInt(),
      extrinsicScore: extrinsic.clamp(0, 100).toInt(),
      minimumAction: _minimumActionFor(cleanGoal),
      failureRecovery: '如果今天没有完成，不做人格审判；先判断是哪种心理需要受挫，再把任务降级为 3 分钟恢复动作。',
      identitySentence: identity.trim().isEmpty ? '我正在成为一个能从外控走向自主、从失败中恢复的人。' : '我正在成为$identity。',
      abilityTree: const ['目标澄清', '价值连接', '任务降级', '启动动作', '反馈记录', '失败复盘', '环境改造', '边界表达', '作品/成果沉淀'],
      signals: [
        if (extrinsic > intrinsic) '外在目标成分偏高，需要重新连接内在价值',
        if (shame) '检测到羞耻/内摄压力，建议改写为自主承诺',
        if (reason.trim().isEmpty) '目标原因还不清晰，先补充“为什么重要”',
      ],
    );
  }

  static String _minimumActionFor(String goal) {
    if (goal.contains('学习')) return '打开学习材料，只阅读或标注 3 分钟。';
    if (goal.contains('开发') || goal.contains('项目') || goal.contains('Unity')) return '打开项目，记录当前最主要的一个问题，不要求立刻解决。';
    if (goal.contains('运动') || goal.contains('健康')) return '换好鞋或站起来活动 2 分钟，先恢复“我能开始”的感觉。';
    if (goal.contains('写') || goal.contains('创作')) return '打开文档，写下一句话或一个标题。';
    return '把目标写成一个 1—3 分钟可启动动作，只完成第一步。';
  }
}

class SelfDeterminationGrowthHomePage extends StatefulWidget {
  const SelfDeterminationGrowthHomePage({super.key});

  @override
  State<SelfDeterminationGrowthHomePage> createState() => _SelfDeterminationGrowthHomePageState();
}

class _SelfDeterminationGrowthHomePageState extends State<SelfDeterminationGrowthHomePage> {
  int _tab = 0;
  final _goal = TextEditingController(text: '我要开发一款 Unity 游戏');
  final _reason = TextEditingController(text: '我想把逆境、痛苦、意志力和成长变成作品');
  final _identity = TextEditingController(text: '一个能够把人生体验转化为作品的人');
  final _coachInput = TextEditingController(text: '我今天拖延了，不想打开项目，觉得自己很失败。');
  late SdgGoalAnalysis _analysis;
  final List<double> _needValues = <double>[62, 58, 35, 46, 52, 48, 35, 42, 55];
  final List<String> _growthLogs = <String>[];

  @override
  void initState() {
    super.initState();
    _analysis = SelfDeterminationGrowthEngine.analyzeGoal(goal: _goal.text, reason: _reason.text, identity: _identity.text);
  }

  @override
  void dispose() {
    _goal.dispose();
    _reason.dispose();
    _identity.dispose();
    _coachInput.dispose();
    super.dispose();
  }

  SdgNeedSnapshot get _snapshot => SelfDeterminationGrowthEngine.scoreNeeds(_needValues);

  @override
  Widget build(BuildContext context) {
    final pages = [_todayPage(), _needsPage(), _goalPage(), _coachPage(), _recoveryPage(), _narrativePage()];
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('自我决定成长系统'),
            Text('自主 · 胜任 · 关系', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'AI 提示词统一配置中心',
            icon: const Icon(Icons.tune_outlined),
            onPressed: () => _openPromptCenter(),
          ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_customize_outlined), label: '今日'),
          NavigationDestination(icon: Icon(Icons.radar_outlined), label: '雷达'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), label: '目标'),
          NavigationDestination(icon: Icon(Icons.psychology_alt_outlined), label: '教练'),
          NavigationDestination(icon: Icon(Icons.healing_outlined), label: '恢复'),
          NavigationDestination(icon: Icon(Icons.auto_stories_outlined), label: '叙事'),
        ],
      ),
    );
  }

  Widget _todayPage() {
    final s = _snapshot;
    return _scroll([
      _heroCard('你不是缺少意志力，你需要找到真正属于自己的行动源头。', '今日自我决定面板把任务背后的心理需要先放到前面。'),
      Row(children: [
        Expanded(child: _needCard('自主感', s.autonomy, const Color(0xFF6366F1))),
        const SizedBox(width: 10),
        Expanded(child: _needCard('胜任感', s.competence, const Color(0xFF0EA5E9))),
        const SizedBox(width: 10),
        Expanded(child: _needCard('关系感', s.relatedness, const Color(0xFF10B981))),
      ]),
      _section('今日 AI 建议', '今天最低的是${s.lowestNeed}。建议不要用羞耻推动自己，先做一个能恢复胜任感的最小行动：${_analysis.minimumAction}'),
      _section('今日心理风险', s.risk > 45 ? '风险偏高：容易进入外控、内耗或失败审判。' : '风险可控：适合推进 Level 1—2 行动。'),
      _section('今日成长敌人', _enemyFor(s.lowestNeed)),
      _section('今日恢复入口', '失败后只回答四问：哪种需要受挫？缺少什么支持？任务是否需要降级？下一步最小行动是什么？'),
    ]);
  }

  Widget _needsPage() => _scroll([
        _section('每日心理需要打分', '拖动 9 个问题，系统会合成自主、胜任、关系三大心理需要。'),
        for (var i = 0; i < _needQuestions.length; i++) _slider(i, _needQuestions[i]),
        _section('需要受挫诊断', '当前最低需要：${_snapshot.lowestNeed}。这说明行动困难未必是意志力问题，可能是目标未内化、任务过难或关系受挫。'),
        _miniTrend(),
      ]);

  Widget _goalPage() => _scroll([
        _section('目标创建与内容审查', '输入目标、原因与身份连接，系统会区分内在目标/外在目标，并生成自主整合型重构。'),
        _field(_goal, '我想完成什么？'),
        _field(_reason, '我为什么想完成？'),
        _field(_identity, '这个目标和我想成为的人有什么关系？'),
        FilledButton.icon(onPressed: _reanalyze, icon: const Icon(Icons.auto_awesome), label: const Text('分析并重构目标')),
        _scoreBar('内在目标评分', _analysis.intrinsicScore, const Color(0xFF10B981)),
        _scoreBar('外在目标评分', _analysis.extrinsicScore, const Color(0xFFF97316)),
        _section('当前动机类型', _analysis.stage.label),
        _section('自主整合型重构', _analysis.reconstructedGoal),
        _section('最小行动', _analysis.minimumAction),
        _chips('能力树', _analysis.abilityTree),
        if (_analysis.signals.isNotEmpty) _chips('诊断信号', _analysis.signals),
      ]);

  Widget _coachPage() => _scroll([
        _section('AI 自主支持教练', '本模块内置三层 Prompt：全局价值层、场景层、输出格式层。AI 不能羞辱、恐吓或控制用户。'),
        _field(_coachInput, '输入：拖延 / 被影响 / 失败 / 沉迷诱惑 / 目标迷茫', maxLines: 4),
        FilledButton.icon(onPressed: () => setState(() {}), icon: const Icon(Icons.psychology_alt), label: const Text('生成自主支持回应')),
        _coachOutput(_coachInput.text),
        _section('Prompt 已接入统一配置中心', '本模块全部 AI 提示词已注册到：设置 → AI 提示词统一配置中心 → 自我决定成长系统 · SDT Growth。点击右上角滑杆图标可配置全局价值层、六大场景层、十二大功能层、报告、输出格式、安全伦理与异常修复 Prompt。'),
      _chips('可配置 Prompt', SelfDeterminationGrowthPromptConfig.labels.values.toList(growable: false)),
      _section('源码默认全局价值层预览', SelfDeterminationGrowthEngine.globalPrompt.trim()),
      ]);

  Widget _recoveryPage() => _scroll([
        _section('失败恢复系统', '失败不是人格结论，而是系统信号。不要补偿式加倍努力，先恢复行动入口。'),
        _chips('失败类型', const ['目标不自主型', '任务过难型', '环境干扰型', '关系打击型', '情绪耗竭型', '技能不足型', '计划乐观型', '外部控制反弹型', '诱惑补偿型']),
        _section('失败复盘四问', '1. 我是哪种心理需要受挫了？\n2. 我缺少什么支持？\n3. 这个任务是否需要降级？\n4. 下一步最小行动是什么？'),
        _section('恢复行动生成', _analysis.failureRecovery),
        _section('环境改造清单', '手机放远；关闭短视频入口；固定启动动作；每次只解决一个问题；把报错记录成知识库；桌面只保留当前任务材料。'),
        _section('边界表达训练', '我理解你的看法，但这件事我想按自己的节奏来。\n你可以不同意我，但我不接受羞辱式表达。\n我现在需要的是建议，不是评价。'),
      ]);

  Widget _narrativePage() => _scroll([
        _section('成长叙事与身份整合', '把零散行动整合为“我正在成为谁”的证据。'),
        _section('身份句', _analysis.identitySentence),
        FilledButton.icon(onPressed: _addLog, icon: const Icon(Icons.add), label: const Text('记录今日成长证据')),
        for (final log in _growthLogs) _section('成长记录', log),
        _section('每周成长报告模板', '本周自主感变化 / 胜任感变化 / 关系感变化 / 主要敌人 / 最有效行动 / 失败模式 / 身份变化 / 下周建议。'),
        _section('逆境之路游戏化接口', '心理敌人通过现实行动削弱：最小行动削弱拖延兽，边界表达击退控制者，失败复盘削弱失败审判官。'),
        _chips('十二大模块覆盖', const ['首页：今日自我决定面板', '三大心理需要雷达', '目标创建与内容审查', '动机光谱分析器', '目标内化工作台', '最小行动与能力树', 'AI 自主支持教练', '关系感与边界系统', '环境改造系统', '失败恢复系统', '逆境之路游戏化', '成长叙事与身份整合']),
        _chips('MVP 闭环状态', const ['用户自我决定画像', '每日检测', '目标创建', '目标内容分析', '动机分析', '最小行动生成', '自主支持对话', '失败复盘', '每日成长记录', '每周成长报告模板', '关系与环境扩展入口', '游戏化扩展接口']),
        _section('产品伦理边界', '不替代心理治疗；不进行医学诊断；不使用羞辱、恐吓、排名焦虑提高留存；不把失败解释为人格缺陷；出现严重自伤、自杀、伤害他人或暴力风险时，引导寻求现实专业帮助或紧急支持。'),
      ]);

  void _reanalyze() => setState(() => _analysis = SelfDeterminationGrowthEngine.analyzeGoal(goal: _goal.text, reason: _reason.text, identity: _identity.text));

  void _openPromptCenter([String promptId = SelfDeterminationGrowthPromptConfig.globalId]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiPromptSettingsPage(
          initialModuleId: SelfDeterminationGrowthPromptConfig.moduleId,
          initialPromptId: promptId,
        ),
      ),
    );
  }

  void _addLog() => setState(() => _growthLogs.insert(0, '今天我完成了一个最小行动：“${_analysis.minimumAction}” 这不是机械打卡，而是在练习从外控回到自主。'));

  Widget _scroll(List<Widget> children) => ListView(padding: const EdgeInsets.all(16), children: children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w)).toList());

  Widget _heroCard(String title, String subtitle) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF312E81), Color(0xFF7C3AED)]), borderRadius: BorderRadius.circular(28)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 10), Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.4))]),
      );

  Widget _needCard(String title, int value, Color color) => _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 12), Text('$value', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)), LinearProgressIndicator(value: value / 100, color: color, backgroundColor: color.withOpacity(.12))]));

  Widget _section(String title, String body) => _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(body, style: const TextStyle(height: 1.45, color: Color(0xFF374151)))]));

  Widget _card(Widget child) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 18, offset: Offset(0, 8))]), child: child);

  Widget _slider(int i, String question) => _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(question, style: const TextStyle(fontWeight: FontWeight.w700)), Slider(value: _needValues[i], min: 0, max: 100, divisions: 20, label: _needValues[i].round().toString(), onChanged: (v) => setState(() => _needValues[i] = v))]));

  Widget _field(TextEditingController c, String label, {int maxLines = 1}) => TextField(controller: c, maxLines: maxLines, decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)));

  Widget _scoreBar(String title, int value, Color color) => _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$title：$value / 100', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8), LinearProgressIndicator(value: value / 100, color: color, backgroundColor: color.withOpacity(.12))]));

  Widget _chips(String title, List<String> items) => _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: [for (final item in items) Chip(label: Text(item))])])) ;

  Widget _miniTrend() => _card(SizedBox(height: 86, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(7, (i) { final h = 26 + math.Random(i + _snapshot.risk).nextInt(54); return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Container(height: h.toDouble(), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(.25 + i * .07), borderRadius: BorderRadius.circular(10))))); }))));

  Widget _coachOutput(String input) {
    final lower = input.toLowerCase();
    final scene = lower.contains('失败') ? '失败后自责' : lower.contains('别人') || lower.contains('影响') ? '关系/边界受扰' : lower.contains('沉迷') || lower.contains('短视频') ? '诱惑补偿' : '拖延';
    return _section('标准输出格式 · $scene', '1. 你现在真正遇到的问题：行动系统中的心理需要可能受挫。\n\n2. 这不是简单的意志力问题：先看自主、胜任、关系，而不是攻击自己。\n\n3. 三大心理需要分析：自主感 ${_snapshot.autonomy}，胜任感 ${_snapshot.competence}，关系感 ${_snapshot.relatedness}。\n\n4. 当前动机类型：${_analysis.stage.label}。\n\n5. 自主整合型重构：${_analysis.reconstructedGoal}\n\n6. 现在可以做的最小行动：${_analysis.minimumAction}\n\n7. 失败后的恢复方式：${_analysis.failureRecovery}\n\n8. 身份整合句：${_analysis.identitySentence}');
  }

  String _enemyFor(String need) => switch (need) {
        '自主感' => '控制者 / 外部评价魔像：通过价值连接和自主承诺削弱。',
        '胜任感' => '无力巨人 / 拖延兽：通过 Level 0 最小行动与进步证据削弱。',
        _ => '孤立荒原 / 羞耻之影：通过真实表达、支持请求和边界训练削弱。',
      };
}

const _needQuestions = <String>[
  '今天我做的事情有多少是我真正愿意做的？',
  '今天我是否知道自己为什么要做这些事？',
  '今天我是否感到被迫、被催促或被外界控制？',
  '今天我是否知道下一步该怎么做？',
  '今天的任务难度是否适合我？',
  '今天我是否感到自己有一点进步？',
  '今天我是否感到被理解？',
  '今天我是否有真实表达自己？',
  '今天我是否感到孤立、被否定或被控制？',
];
