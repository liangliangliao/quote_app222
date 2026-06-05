import 'dart:convert';


import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'happiness_models.dart';
import 'happiness_seed.dart';
import 'happiness_training_specs.dart';

class HappinessAiResult {
  final List<HappinessAction> actions;
  final String provider;
  final String modelLabel;

  const HappinessAiResult({required this.actions, required this.provider, required this.modelLabel});

  HappinessAction? get firstAction => actions.isEmpty ? null : actions.first;
}

class HappinessAiService {
  final GlobalAiSettings _globalAiSettings = GlobalAiSettings();
  final UnifiedAiService _unifiedAiService = UnifiedAiService();

  Future<Map<String, String>> getGlobalAiState() async {
    try {
      return await _globalAiSettings.getState();
    } catch (_) {
      return {
        'provider': 'none',
        'model': 'none',
        'label': '未配置（将使用默认行动）',
        'endpoint': '',
        'available': '0',
      };
    }
  }

  Future<HappinessAiResult> generateActions({
    required HappinessUnit unit,
    required String concern,
    required bool smaller,
    required bool avoidSocial,
    required String extraPrompt,
    required int count,
  }) async {
    final state = await getGlobalAiState();
    if (state['available'] != '1') {
      return HappinessAiResult(
        actions: _buildLocalVariants(unit, concern: concern, smaller: smaller, avoidSocial: avoidSocial, count: count),
        provider: 'local',
        modelLabel: state['label'] ?? '未配置',
      );
    }
    final acts = await _genViaUnified(
      unit: unit,
      concern: concern,
      smaller: smaller,
      avoidSocial: avoidSocial,
      extraPrompt: extraPrompt,
      count: count,
    );
    if (acts != null && acts.isNotEmpty) {
      return HappinessAiResult(
        actions: acts,
        provider: state['provider'] ?? 'local',
        modelLabel: state['label'] ?? '统一 AI',
      );
    }
    return HappinessAiResult(
      actions: _buildLocalVariants(unit, concern: concern, smaller: smaller, avoidSocial: avoidSocial, count: count),
      provider: 'local',
      modelLabel: state['label'] ?? '本地回退',
    );
  }


  Future<HappinessAiResult> generateAction({
    required HappinessUnit unit,
    required String concern,
    required bool smaller,
    required bool avoidSocial,
    required String extraPrompt,
  }) => generateActions(
        unit: unit,
        concern: concern,
        smaller: smaller,
        avoidSocial: avoidSocial,
        extraPrompt: extraPrompt,
        count: 1,
      );


  Future<String> generateHistoryInsight({
    required List<HappinessAction> actions,
    required List<HappinessReviewEntry> reviews,
    required String extraPrompt,
  }) async {
    final state = await getGlobalAiState();
    if (state['available'] != '1') {
      return _buildLocalHistoryInsight(actions: actions, reviews: reviews, extraPrompt: extraPrompt);
    }
    final res = await _requestUnifiedText(
      prompt: _historyPrompt(actions: actions, reviews: reviews, extraPrompt: extraPrompt),
      purpose: 'happiness_history.generate',
      systemPrompt: '你是一个具体、克制、强调模式识别的成长档案分析师。',
      maxTokens: 800,
    );
    if (res != null && res.trim().isNotEmpty) return res.trim();
    return _buildLocalHistoryInsight(actions: actions, reviews: reviews, extraPrompt: extraPrompt);
  }

  Future<String> generateReviewSummary({
    required HappinessUnit unit,
    required String fact,
    required String feeling,
    required String thought,
    required String action,
    required String outcome,
    required String extraPrompt,
  }) async {
    final state = await getGlobalAiState();
    if (state['available'] != '1') {
      return _buildLocalReviewSummary(unit: unit, fact: fact, feeling: feeling, thought: thought, action: action, outcome: outcome, extraPrompt: extraPrompt);
    }
    final res = await _requestUnifiedText(
      prompt: _reviewPrompt(unit: unit, fact: fact, feeling: feeling, thought: thought, action: action, outcome: outcome, extraPrompt: extraPrompt),
      purpose: 'happiness_review.generate',
      systemPrompt: '你是一个具体、克制、强调行动的复盘教练。',
      maxTokens: 700,
    );
    if (res != null && res.trim().isNotEmpty) return res.trim();
    return _buildLocalReviewSummary(unit: unit, fact: fact, feeling: feeling, thought: thought, action: action, outcome: outcome, extraPrompt: extraPrompt);
  }


  Future<HappinessAction> generateNextRecommendedAction({
    required List<HappinessAction> actions,
    required List<HappinessReviewEntry> reviews,
    required String extraPrompt,
  }) async {
    final Map<String, int> unitCount = <String, int>{};
    for (final HappinessAction a in actions) {
      unitCount[a.unitId] = (unitCount[a.unitId] ?? 0) + 1;
    }
    for (final HappinessReviewEntry r in reviews) {
      unitCount[r.unitId] = (unitCount[r.unitId] ?? 0) + 1;
    }
    HappinessUnit unit = happinessUnits.first;
    if (unitCount.isNotEmpty) {
      final hottest = unitCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      unit = happinessUnits.firstWhere((u) => u.id == hottest.first.key, orElse: () => happinessUnits.first);
    }
    final int skipped = actions.where((a) => a.status == 'skipped').length;
    final int done = actions.where((a) => a.status == 'done').length;
    final String historyConcern = [
      if (unitCount.isNotEmpty) '最近最集中的训练单元是 ${unit.id} ${unit.title}。',
      if (skipped > 0) '最近有 $skipped 条动作停在回避/跳过。',
      if (done > 0) '已经完成了 $done 条动作。',
      if (reviews.isNotEmpty)
        '最近复盘里反复出现的想法有：${reviews.take(3).map((r) => r.thought).where((e) => e.trim().isNotEmpty).join('；')}',
    ].join(' ');
    final HappinessAiResult result = await generateActions(
      unit: unit,
      concern: historyConcern,
      smaller: skipped > 0,
      avoidSocial: false,
      extraPrompt: ['这是基于历史经验推荐的下一轮动作，请优先输出最适合继续推进的一条。', extraPrompt]
          .where((e) => e.trim().isNotEmpty)
          .join(' '),
      count: 1,
    );
    return result.firstAction ?? _buildLocalVariants(unit, concern: historyConcern, smaller: skipped > 0, avoidSocial: false, count: 1).first;
  }

  String _buildLocalHistoryInsight({
    required List<HappinessAction> actions,
    required List<HappinessReviewEntry> reviews,
    required String extraPrompt,
  }) {
    final done = actions.where((a) => a.status == 'done').length;
    final skipped = actions.where((a) => a.status == 'skipped').length;
    final doing = actions.where((a) => a.status == 'doing').length;
    final Map<String, int> units = <String, int>{};
    for (final a in actions) {
      units[a.unitId] = (units[a.unitId] ?? 0) + 1;
    }
    final hottest = units.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final hotText = hottest.isEmpty ? '当前还没有明显的聚焦单元。' : '最近最常围绕 ${hottest.first.key} 训练，说明这个主题是你当下最真实的练习点。';
    final statusText = skipped > 0
        ? '目前最值得注意的不是能力不够，而是回避正在重新抬头：有 $skipped 条动作停在跳过。'
        : done > 0
            ? '你已经完成了 $done 条动作，说明你不只是理解课程，而是在把它搬进现实。'
            : doing > 0
                ? '你现在有 $doing 条动作正在推进，重点不是再加新任务，而是把现有动作做完并留下事实。'
                : '你已经开始保存动作，下一步是把其中一条真正做完并写一次复盘。';
    final reviewText = reviews.isNotEmpty
        ? '复盘已经开始把经验反推回概念，这是从知道走向做到的关键。'
        : '下一步建议至少完成一次复盘，让经验真正沉淀下来。';
    final promptHint = extraPrompt.trim().isEmpty ? '' : ' 已参考你的历史归纳提示偏好。';
    return '$hotText\n\n$statusText\n\n$reviewText$promptHint';
  }

  String _historyPrompt({
    required List<HappinessAction> actions,
    required List<HappinessReviewEntry> reviews,
    required String extraPrompt,
  }) {
    final recentActions = actions.take(8).map((a) => '- [${a.unitId}] ${a.title} / 状态:${a.status} / 事实:${a.factLog.isEmpty ? '无' : a.factLog}').join('\n');
    final recentReviews = reviews.take(6).map((r) => '- [${r.unitId}] 事实:${r.fact} / 想法:${r.thought} / 结果:${r.outcome}').join('\n');
    return """
你是“知行合一幸福课模块”的成长档案分析师。
请基于下面的历史行动和复盘，写一段 160 到 260 字的中文经验归纳。
要求：
1. 先指出当前最集中的训练主题
2. 再指出用户更常卡在回避、推进还是恢复中的哪一步
3. 点出一个最值得继续训练的动作方向
4. 最后给一个下一轮最适合的动作类型
5. 不要空泛鼓励，不要输出标题和列表

历史行动：
$recentActions

历史复盘：
$recentReviews

额外提示词：${extraPrompt.trim().isEmpty ? '无' : extraPrompt.trim()}
""";
  }

  String _buildLocalReviewSummary({
    required HappinessUnit unit,
    required String fact,
    required String feeling,
    required String thought,
    required String action,
    required String outcome,
    required String extraPrompt,
  }) {
    final concept = unit.concepts.take(2).join('、');
    final promptHint = extraPrompt.trim().isEmpty ? '' : ' 已参考你的复盘提示偏好。';
    return '这次记录最值得回看的，是 $concept。先把事实和解释分开：事实是“$fact”，而你最自动的解释更接近“$thought”。接下来别急着评价自己，先做一个更小一步的动作，并记录真实结果。$promptHint';
  }

  String _reviewPrompt({
    required HappinessUnit unit,
    required String fact,
    required String feeling,
    required String thought,
    required String action,
    required String outcome,
    required String extraPrompt,
  }) {
    return """
你是“知行合一幸福课模块”的复盘教练。
请严格基于当前课程单元，对下面的复盘记录给出一段 120 到 220 字的中文总结。
要求：
1. 先区分事实和解释
2. 点出最相关的课程概念
3. 说明用户现在更适合练什么
4. 最后给出一个更小一步的下一次行动方向
5. 不要空泛鼓励，不要输出标题和列表

单元：${unit.id} ${unit.title}
单元概念：${unit.concepts.join('、')}
单元内容摘要：${unit.summary}
用户记录：
- 事实：$fact
- 情绪：$feeling
- 想法：$thought
- 行为：$action
- 结果：$outcome
额外提示词：${extraPrompt.trim().isEmpty ? '无' : extraPrompt.trim()}
""";
  }

  String _prompt({required HappinessUnit unit, required String concern, required bool smaller, required bool avoidSocial, required String extraPrompt, required int count}) {
    return '''
你是“知行合一幸福课模块”的行动教练。
请严格基于当前课程单元，为用户生成 $count 条现实行动。禁止空泛鼓励。
要求：
1. 每条行动都必须直接对应本单元课程原内容中的一个核心概念或方法。
2. 行动必须可执行、可观察、可记录。
3. 先考虑用户当前困扰，再考虑默认行动和课程原案例。
4. 如用户要求更小一步，就优先给最小可执行版本。
5. 如用户要求低社交暴露，就避免把所有行动都设计成高社交暴露。
6. 每条行动都必须给出清晰、具体、按顺序的步骤，至少 4 步，最多 6 步。
7. 步骤必须写出“先做什么、再做什么、做到什么程度、何时记录”。

单元：${unit.id} ${unit.title}
单元概念：${unit.concepts.join('、')}
单元完整学习内容：${unit.fullContent}
单元摘要：${unit.summary}
课程案例：${unit.courseCases.join('；')}
现实案例：${unit.lifeCases.join('；')}
默认行动：${unit.defaultActionTitle} / ${unit.defaultActionBody}
用户当前困扰：${concern.trim().isEmpty ? '未提供' : concern.trim()}
额外约束：${smaller ? '更小一步；' : ''}${avoidSocial ? '尽量不涉及高社交暴露；' : ''}
额外提示词：${extraPrompt.trim().isEmpty ? '无' : extraPrompt.trim()}

请只输出 JSON，不要输出其他文字。格式：
{
  "actions":[
    {
      "title":"",
      "body":"",
      "steps":["步骤1","步骤2","步骤3","步骤4"],
      "difficulty":"Easy/Medium/Hard",
      "duration":"",
      "successCriteria":"",
      "fallbackAction":"",
      "reviewQuestion":""
    }
  ]
}
''';
  }

  Future<String?> _requestUnifiedText({
    required String prompt,
    required String purpose,
    required String systemPrompt,
    required int maxTokens,
    bool expectJson = false,
  }) async {
    try {
      final text = await _unifiedAiService.generateText(
        prompt: prompt,
        purpose: purpose,
        systemPrompt: systemPrompt,
        maxTokens: maxTokens,
        expectJson: expectJson,
        temperature: 0.3,
      );
      final value = text.trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<List<HappinessAction>?> _genViaUnified({
    required HappinessUnit unit,
    required String concern,
    required bool smaller,
    required bool avoidSocial,
    required String extraPrompt,
    required int count,
  }) async {
    final text = await _requestUnifiedText(
      prompt: _prompt(unit: unit, concern: concern, smaller: smaller, avoidSocial: avoidSocial, extraPrompt: extraPrompt, count: count),
      purpose: 'happiness_action.generate',
      systemPrompt: '你是一个严格输出 JSON 的行动教练。',
      maxTokens: 1400,
      expectJson: true,
    );
    if (text == null || text.trim().isEmpty) return null;
    return _parseActions(text, unit, count: count);
  }

  List<HappinessAction> _buildLocalVariants(HappinessUnit unit, {required String concern, required bool smaller, required bool avoidSocial, required int count}) {
    final List<HappinessAction> out = <HappinessAction>[];
    final List<String> levels = <String>['easy', 'standard', 'stretch', 'easy', 'standard'];
    for (int i = 0; i < count; i++) {
      final String level = smaller ? 'easy' : levels[i % levels.length];
      final HappinessActionPlanSpec plan = actionPlanFor(unit, level);
      final List<String> steps = List<String>.from(plan.steps);
      if (concern.trim().isNotEmpty) {
        steps.insert(0, '把这次行动明确绑定到你的现实困扰：${concern.trim()}。');
      }
      if (avoidSocial) {
        steps.add('如果步骤里涉及高社交暴露，先改成低暴露版本，例如先写出来、先发给安全对象、先做私下演练。');
      }
      out.add(HappinessAction(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}_$i',
        unitId: unit.id,
        unitTitle: unit.title,
        source: 'ai',
        title: 'AI建议 ${i + 1}：${unit.defaultActionTitle}',
        body: plan.intro,
        steps: steps,
        difficulty: level == 'easy' ? 'Easy' : (level == 'standard' ? 'Medium' : 'Hard'),
        duration: level == 'easy' ? '5-10分钟' : (level == 'standard' ? '10-20分钟' : '20-30分钟'),
        successCriteria: plan.successCriteria,
        fallbackAction: plan.fallbackAction,
        reviewQuestion: unit.reflectionQuestion,
        createdAt: DateTime.now().millisecondsSinceEpoch + i,
        planNote: steps.isNotEmpty ? steps.first : '先把这条 AI 行动放进一个今天真实会发生的情境里。',
        obstacleNote: plan.fallbackAction,
        nextStepNote: plan.recordFocus,
        realityVersion: concern.trim(),
      ));
    }
    return out;
  }

  List<String> _parseActionSteps(dynamic raw, HappinessUnit unit) {
    if (raw is List) {
      final steps = raw.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
      if (steps.isNotEmpty) return steps;
    }
    return actionPlanFor(unit, 'standard').steps;
  }

  List<HappinessAction>? _parseActions(String raw, HappinessUnit unit, {required int count}) {
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      final clean = (start >= 0 && end > start) ? raw.substring(start, end + 1) : raw;
      final dynamic decoded = jsonDecode(clean);
      List<dynamic> list = <dynamic>[];
      if (decoded is Map && decoded['actions'] is List) {
        list = decoded['actions'] as List<dynamic>;
      } else if (decoded is List) {
        list = decoded;
      } else if (decoded is Map) {
        list = <dynamic>[decoded];
      }
      final actions = <HappinessAction>[];
      for (int i = 0; i < list.length && actions.length < count; i++) {
        final item = list[i];
        if (item is! Map) continue;
        actions.add(HappinessAction(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}_$i',
          unitId: unit.id,
          unitTitle: unit.title,
          source: 'ai',
          title: '${item['title'] ?? unit.defaultActionTitle}',
          body: '${item['body'] ?? unit.defaultActionBody}',
          steps: _parseActionSteps(item['steps'], unit),
          difficulty: '${item['difficulty'] ?? 'Medium'}',
          duration: '${item['duration'] ?? '10-20分钟'}',
          successCriteria: '${item['successCriteria'] ?? '完成一次可观察的小行动。'}',
          fallbackAction: '${item['fallbackAction'] ?? '把动作缩小一半再做。'}',
          reviewQuestion: '${item['reviewQuestion'] ?? unit.reflectionQuestion}',
          createdAt: DateTime.now().millisecondsSinceEpoch + i,
          planNote: '先把这条动作放到今天具体的一个情境里。',
          obstacleNote: '最容易卡住时，不要整条放弃，先缩成最小一步。',
          nextStepNote: '执行后补事实记录，再决定要不要做第二次。',
          realityVersion: '',
        ));
      }
      if (actions.isEmpty) return null;
      while (actions.length < count) {
        actions.add(_buildLocalVariants(unit, concern: '', smaller: true, avoidSocial: false, count: 1).first.copyWith());
      }
      return actions;
    } catch (_) {
      return null;
    }
  }
}
