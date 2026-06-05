import 'dart:convert';


import '../data/kv_dao.dart';
import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'stress_models.dart';
import 'stress_seed.dart';

class StressAiService {
  final KeyValueDao _kvDao = KeyValueDao();
  final GlobalAiSettings _globalAiSettings = GlobalAiSettings();
  final UnifiedAiService _unifiedAiService = UnifiedAiService();

  Future<Map<String, String>> getGlobalAiState() async {
    final state = await _globalAiSettings.getState();
    return <String, String>{
      'provider': state['provider'] ?? 'deepseek',
      'model': state['model'] ?? '',
      'label': state['label'] ?? '未配置',
      'available': state['available'] ?? '0',
      'note': (state['available'] == '1') ? '当前模块已复用主应用设置中的模型配置。' : '未检测到可用密钥，将回退到本地行动与本地洞察。',
    };
  }

  Future<StressActionPlanResult> generateActionPlan({required StressUnit unit, required String concern}) async {
    final state = await getGlobalAiState();
    if (state['available'] != '1') {
      return StressActionPlanResult.fallback(unit, concern: concern);
    }
    final prompt = '''
你是“压力与恢复知行实验室”的行动教练。请围绕以下课程单元输出一个严格 JSON 对象，不要输出 markdown，不要输出代码块。

课程标题：${unit.title}
课程母本：${unit.fullContent}
核心概念：${unit.concepts.join('、')}
课程摘要：${unit.summary}
现实实践动作：${unit.defaultActionTitle} / ${unit.defaultActionBody}
用户当前困扰：${concern.trim().isEmpty ? '未提供，请按一般学习者输出。' : concern.trim()}

请严格输出：
{
  "problem_judgment": "一句话判断当前更像哪种问题结构",
  "today_minimal_action": "今天10分钟内能做的最小行动",
  "week_chain": ["步骤1", "步骤2", "步骤3", "步骤4"],
  "recovery_action": "失败后的恢复或降级动作",
  "review_question": "晚间最值得回答的一道复盘问题"
}
''';
    final raw = await _requestText(prompt: prompt, purpose: 'action_plan');
    final parsed = _extractJsonObject(raw);
    if (parsed.isEmpty) return StressActionPlanResult.fallback(unit, concern: concern);
    return StressActionPlanResult.fromMap(parsed, provider: state['provider'] ?? 'local', modelLabel: state['label'] ?? 'AI', raw: raw);
  }

  Future<StressInsightResult> generateInsight({required List<StressAction> actions, required List<StressReviewEntry> reviews}) async {
    final state = await getGlobalAiState();
    if (state['available'] != '1') {
      return StressInsightResult.fallback(actions: actions, reviews: reviews);
    }
    final actionSummary = actions.take(8).map((e) => '行动：${e.title}｜状态：${e.status}｜事实：${e.factLog}｜阻碍：${e.obstacleNote}').join('\n');
    final reviewSummary = reviews.take(8).map((e) => '复盘：${e.unitTitle}｜事实：${e.fact}｜感受：${e.feeling}｜结果：${e.outcome}').join('\n');
    final prompt = '''
你是“压力与恢复知行实验室”的 AI 洞察教练。请根据用户最近的行动与复盘，输出一个严格 JSON 对象，不要输出 markdown，不要输出代码块。

最近行动：
${actionSummary.isEmpty ? '暂无。' : actionSummary}

最近复盘：
${reviewSummary.isEmpty ? '暂无。' : reviewSummary}

请严格输出：
{
  "summary": "一段 120-220 字的总体洞察",
  "patterns": ["模式1", "模式2", "模式3"],
  "next_focus": "接下来最值得优先处理的一点",
  "today_action": "今天最值得执行的一条微行动"
}
''';
    final raw = await _requestText(prompt: prompt, purpose: 'insight');
    final parsed = _extractJsonObject(raw);
    if (parsed.isEmpty) return StressInsightResult.fallback(actions: actions, reviews: reviews);
    return StressInsightResult.fromMap(parsed, provider: state['provider'] ?? 'local', modelLabel: state['label'] ?? 'AI', raw: raw);
  }

  Future<StressGrowthReport> generateGrowthReport({
    required List<StressAction> actions,
    required List<StressReviewEntry> reviews,
    required List<StressSceneSession> sessions,
    StressPersonaProfile? persona,
  }) async {
    final curve = buildStressGrowthCurve(actions: actions, reviews: reviews, sessions: sessions);
    final state = await getGlobalAiState();
    if (state['available'] != '1') {
      return StressGrowthReport.fallback(actions: actions, reviews: reviews, sessions: sessions, persona: persona, curve: curve);
    }
    final actionSummary = actions.take(10).map((e) => '行动：${e.title}｜状态：${e.status}｜事实：${e.factLog}').join('\n');
    final reviewSummary = reviews.take(10).map((e) => '复盘：${e.unitTitle}｜感受：${e.feeling}｜结果：${e.outcome}').join('\n');
    final sceneSummary = sessions.take(10).map((e) => '场景：${e.sceneName}｜选择：${e.choiceTitle}｜压力：${e.pressure}｜恢复：${e.recovery}').join('\n');
    final prompt = '''
你是“压力与恢复知行实验室”的长期成长教练。请基于用户最近一段时间的数据，输出一个严格 JSON 对象，不要输出 markdown，不要输出代码块。

用户画像：${persona == null ? '未设置' : '${persona.roleLabel} / 焦点：${persona.currentFocus} / 能量模式：${persona.energyStyle} / 支持方式：${persona.supportStyle} / 改变节奏：${persona.changeTempo} / 回避模式：${persona.avoidancePattern}'}

最近行动：
${actionSummary.isEmpty ? '暂无。' : actionSummary}

最近复盘：
${reviewSummary.isEmpty ? '暂无。' : reviewSummary}

最近知行城选择：
${sceneSummary.isEmpty ? '暂无。' : sceneSummary}

请严格输出：
{
  "summary": "120-220字，概括用户当前处在怎样的成长阶段",
  "major_gain": "当前最明显的一项成长收获",
  "fragile_loop": "当前最脆弱、最容易反复出现的一条旧回路",
  "next_quest": "未来7天最值得盯住的一项任务",
  "story_title": "给用户当前成长阶段起一个剧情标题",
  "story_body": "用100-180字说明当前剧情主线与内在冲突",
  "month_focus": "本月最值得持续追踪的一项长期重点"
}
''';
    final raw = await _requestText(prompt: prompt, purpose: 'growth_report');
    final parsed = _extractJsonObject(raw);
    if (parsed.isEmpty) {
      return StressGrowthReport.fallback(actions: actions, reviews: reviews, sessions: sessions, persona: persona, curve: curve);
    }
    return StressGrowthReport.fromMap(parsed, provider: state['provider'] ?? 'local', modelLabel: state['label'] ?? 'AI', raw: raw, curve: curve);
  }


  Future<StressWeeklyReport> generateWeeklyReport({
    required List<StressAction> actions,
    required List<StressReviewEntry> reviews,
    required List<StressSceneSession> sessions,
    StressPersonaProfile? persona,
  }) async {
    final state = await getGlobalAiState();
    if (state['available'] != '1') {
      return StressWeeklyReport.fallback(actions: actions, reviews: reviews, sessions: sessions);
    }
    final actionSummary = actions.take(12).map((e) => '行动：${e.title}｜状态：${e.status}｜事实：${e.factLog}').join('\n');
    final reviewSummary = reviews.take(10).map((e) => '复盘：${e.unitTitle}｜感受：${e.feeling}｜结果：${e.outcome}').join('\n');
    final sceneSummary = sessions.take(10).map((e) => '场景：${e.sceneName}｜选择：${e.choiceTitle}｜压力：${e.pressure}｜恢复：${e.recovery}').join('\n');
    final prompt = '''
你是“压力与恢复知行实验室”的周复盘教练。请根据用户最近一周的行动、复盘和知行城选择，输出一个严格 JSON 对象，不要输出 markdown，不要输出代码块。

用户画像：${persona == null ? '未设置' : '${persona.roleLabel} / 焦点：${persona.currentFocus} / 旧回路：${persona.avoidancePattern}'}

最近行动：
${actionSummary.isEmpty ? '暂无。' : actionSummary}

最近复盘：
${reviewSummary.isEmpty ? '暂无。' : reviewSummary}

最近知行城：
${sceneSummary.isEmpty ? '暂无。' : sceneSummary}

请严格输出：
{
  "week_label": "本周",
  "headline": "一句 20-40 字的周主题标题",
  "summary": "120-220字周总结",
  "wins": ["本周做对了什么1", "本周做对了什么2"],
  "blockers": ["本周主要阻碍1", "本周主要阻碍2"],
  "next_focus": "下周最值得优先处理的一点",
  "recommended_unit_id": "最值得回到的课程单元ID，例如 S11",
  "next_action": "下周最建议执行的一条微行动"
}
''';
    final raw = await _requestText(prompt: prompt, purpose: 'weekly_report');
    final parsed = _extractJsonObject(raw);
    if (parsed.isEmpty) {
      return StressWeeklyReport.fallback(actions: actions, reviews: reviews, sessions: sessions);
    }
    return StressWeeklyReport.fromMap(parsed, provider: state['provider'] ?? 'local', modelLabel: state['label'] ?? 'AI', raw: raw);
  }

  Future<StressMonthlyReport> generateMonthlyReport({
    required List<StressAction> actions,
    required List<StressReviewEntry> reviews,
    required List<StressSceneSession> sessions,
    StressPersonaProfile? persona,
    StressGrowthReport? growthReport,
  }) async {
    final state = await getGlobalAiState();
    if (state['available'] != '1') {
      return StressMonthlyReport.fallback(actions: actions, reviews: reviews, sessions: sessions, growthReport: growthReport);
    }
    final actionSummary = actions.take(16).map((e) => '行动：${e.title}｜状态：${e.status}｜事实：${e.factLog}').join('\n');
    final reviewSummary = reviews.take(16).map((e) => '复盘：${e.unitTitle}｜感受：${e.feeling}｜结果：${e.outcome}').join('\n');
    final sceneSummary = sessions.take(16).map((e) => '场景：${e.sceneName}｜选择：${e.choiceTitle}｜压力：${e.pressure}｜恢复：${e.recovery}').join('\n');
    final prompt = '''
你是“压力与恢复知行实验室”的月度成长教练。请根据用户最近一个月的学习、行动、复盘与知行城数据，输出一个严格 JSON 对象，不要输出 markdown，不要输出代码块。

用户画像：${persona == null ? '未设置' : '${persona.roleLabel} / 焦点：${persona.currentFocus} / 支持方式：${persona.supportStyle} / 旧回路：${persona.avoidancePattern}'}

最近行动：
${actionSummary.isEmpty ? '暂无。' : actionSummary}

最近复盘：
${reviewSummary.isEmpty ? '暂无。' : reviewSummary}

最近知行城：
${sceneSummary.isEmpty ? '暂无。' : sceneSummary}

已有成长主线：${growthReport == null ? '暂无。' : '${growthReport.storyTitle} / ${growthReport.monthFocus}'}

请严格输出：
{
  "month_label": "本月",
  "headline": "一句 20-40 字的月主题标题",
  "summary": "120-260字月总结",
  "shifts": ["本月出现的新变化1", "本月出现的新变化2"],
  "loops": ["仍在反复出现的旧回路1", "旧回路2"],
  "next_month_focus": "下月最值得持续追踪的一点",
  "recommended_unit_id": "最值得回到的课程单元ID，例如 S04",
  "next_experiment": "下月最值得连续做的一项小实验"
}
''';
    final raw = await _requestText(prompt: prompt, purpose: 'monthly_report');
    final parsed = _extractJsonObject(raw);
    if (parsed.isEmpty) {
      return StressMonthlyReport.fallback(actions: actions, reviews: reviews, sessions: sessions, growthReport: growthReport);
    }
    return StressMonthlyReport.fromMap(parsed, provider: state['provider'] ?? 'local', modelLabel: state['label'] ?? 'AI', raw: raw);
  }

  Future<StressProblemRoute> mapProblemToRoute({required String problem, StressPersonaProfile? persona}) async {
    final localUnits = _rankUnitsForProblem(problem: problem, persona: persona);
    final state = await getGlobalAiState();
    if (state['available'] != '1') {
      return StressProblemRoute.fallback(problem: problem, units: localUnits);
    }
    final prompt = '''
你是“压力与恢复知行实验室”的问题映射助手。请根据用户当前困扰，把它映射到最相关的课程单元。输出一个严格 JSON 对象，不要输出 markdown，不要输出代码块。

用户困扰：$problem
用户画像：${persona == null ? '未设置' : '${persona.roleLabel} / 焦点：${persona.currentFocus} / 压力标签：${persona.stressTags.join('、')} / 旧回路：${persona.avoidancePattern}'}

可选课程单元（节选标题）：${stressUnits.take(20).map((e) => '${e.id}:${e.title}').join(' | ')}

请严格输出：
{
  "problem": "原问题简写",
  "summary": "80-160字，说明当前问题更像什么结构",
  "recommended_unit_ids": ["S04", "S11", "S13"],
  "reasons": ["为什么推荐单元1", "为什么推荐单元2", "为什么推荐单元3"],
  "quick_start": "最合适的起步顺序和第一步"
}
''';
    final raw = await _requestText(prompt: prompt, purpose: 'problem_route');
    final parsed = _extractJsonObject(raw);
    if (parsed.isEmpty) {
      return StressProblemRoute.fallback(problem: problem, units: localUnits);
    }
    final route = StressProblemRoute.fromMap(parsed, provider: state['provider'] ?? 'local', modelLabel: state['label'] ?? 'AI', raw: raw);
    if (route.recommendedUnitIds.isEmpty) {
      return StressProblemRoute.fallback(problem: problem, units: localUnits);
    }
    return route;
  }

  List<StressUnit> _rankUnitsForProblem({required String problem, StressPersonaProfile? persona}) {
    final q = problem.trim();
    final candidates = List<StressUnit>.from(stressUnits);
    int score(StressUnit u) {
      var s = 0;
      for (final tag in u.tags) {
        if (q.contains(tag) || tag.contains(q)) s += 5;
      }
      for (final c in u.concepts) {
        if (q.contains(c) || c.contains(q)) s += 4;
      }
      if (u.title.contains(q) || u.summary.contains(q) || u.whatText.contains(q) || u.whyText.contains(q)) s += 6;
      if (q.contains('恢复') && u.tags.contains('恢复')) s += 5;
      if ((q.contains('拖延') || q.contains('开始不了')) && u.tags.contains('拖延')) s += 5;
      if ((q.contains('专注') || q.contains('消息') || q.contains('打断')) && (u.tags.contains('专注') || u.title.contains('多任务'))) s += 5;
      if ((q.contains('拒绝') || q.contains('说不') || q.contains('边界')) && (u.tags.contains('边界') || u.title.contains('说“不”') || u.title.contains('说"不"'))) s += 5;
      if ((q.contains('时间') || q.contains('赶') || q.contains('没空')) && (u.title.contains('时间富足') || u.tags.contains('时间'))) s += 5;
      if (persona != null) {
        if (u.whatText.contains(persona.currentFocus) || u.whyText.contains(persona.currentFocus)) s += 2;
        for (final t in persona.stressTags) {
          if (u.tags.any((e) => e.contains(t) || t.contains(e)) || u.title.contains(t) || u.summary.contains(t)) s += 2;
        }
      }
      return s;
    }
    candidates.sort((a, b) {
      final c = score(b).compareTo(score(a));
      if (c != 0) return c;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return candidates.take(3).toList();
  }

  Future<String> summarizeReview({required StressUnit unit, required String fact, required String feeling, required String action, required String outcome}) async {
    final state = await getGlobalAiState();
    if (state['available'] != '1') {
      final parts = <String>[
        '今天更像在练习「${unit.concepts.isNotEmpty ? unit.concepts.first : unit.title}」。',
        if (fact.trim().isNotEmpty) '事实：$fact',
        if (feeling.trim().isNotEmpty) '感受：$feeling',
        '下一步：把动作再缩小一点，并继续记录可观察事实。',
      ];
      return parts.join('\n');
    }
    final prompt = '''
你是“压力与恢复知行实验室”的复盘教练。请根据以下信息，输出 80-180 字中文总结，不要输出标题，不要输出 markdown。
课程标题：${unit.title}
核心概念：${unit.concepts.join('、')}
事实：$fact
感受：$feeling
行动：$action
结果：$outcome
请总结：这次更像在练什么、卡在哪里、下一步最该怎么调小一点。
''';
    final raw = await _requestText(prompt: prompt, purpose: 'review_summary');
    return raw.trim().isEmpty ? '这次更像在练习「${unit.title}」，下一步建议把动作缩小并继续记录事实。' : raw.trim();
  }

  Future<String> _requestText({required String prompt, required String purpose}) async {
    return _unifiedAiService.generateText(
      prompt: prompt,
      purpose: 'stress_ai.$purpose',
      systemPrompt: '你是压力与恢复知行实验室的 AI 教练。回答必须全中文；若要求 JSON，则只能输出 JSON 对象。',
      maxTokens: purpose == 'review_summary' ? 600 : 1800,
      expectJson: purpose != 'review_summary',
      temperature: 0.2,
    );
  }

  String _extractText(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is Map && data['output'] is List) {
        for (final dynamic item in data['output'] as List) {
          if (item is Map && item['content'] is List) {
            for (final dynamic content in item['content'] as List) {
              if (content is Map && content['text'] != null) return content['text'].toString();
            }
          }
        }
      }
      if (data is Map && data['choices'] is List && (data['choices'] as List).isNotEmpty) {
        final first = (data['choices'] as List).first;
        if (first is Map) {
          final msg = first['message'];
          if (msg is Map && msg['content'] != null) return msg['content'].toString();
        }
      }
      if (data is Map && data['content'] != null) return data['content'].toString();
    } catch (_) {}
    return raw;
  }

  Map<String, dynamic> _extractJsonObject(String raw) {
    final direct = _tryDecodeObject(raw);
    if (direct.isNotEmpty) return direct;
    final trimmed = raw.trim().replaceAll('```json', '').replaceAll('```', '').trim();
    final fenced = _tryDecodeObject(trimmed);
    if (fenced.isNotEmpty) return fenced;
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return _tryDecodeObject(trimmed.substring(start, end + 1));
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _tryDecodeObject(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }
}


List<StressGrowthPoint> buildStressGrowthCurve({
  required List<StressAction> actions,
  required List<StressReviewEntry> reviews,
  required List<StressSceneSession> sessions,
}) {
  final now = DateTime.now();
  final labels = <String>['第1周', '第2周', '第3周', '本周'];
  final points = <StressGrowthPoint>[];
  for (int i = 0; i < 4; i++) {
    final bucketStart = now.subtract(Duration(days: 7 * (3 - i) + 6));
    final bucketEnd = now.subtract(Duration(days: 7 * (3 - i)));
    bool inRange(int ts) {
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      final start = DateTime(bucketStart.year, bucketStart.month, bucketStart.day);
      final end = DateTime(bucketEnd.year, bucketEnd.month, bucketEnd.day).add(const Duration(days: 1));
      return !d.isBefore(start) && d.isBefore(end);
    }

    final acted = actions.where((e) => inRange(e.createdAt) && (e.status == 'done' || e.status == 'partial' || e.status == 'doing')).length;
    final reviewedCount = reviews.where((e) => inRange(e.createdAt)).length;
    final simulated = sessions.where((e) => inRange(e.createdAt)).length;
    final learned = <String>{
      ...actions.where((e) => inRange(e.createdAt)).map((e) => e.unitId),
      ...reviews.where((e) => inRange(e.createdAt)).map((e) => e.unitId),
      ...sessions.where((e) => inRange(e.createdAt)).map((e) => e.unitId),
    }.length;
    points.add(StressGrowthPoint(label: labels[i], learned: learned, acted: acted, reviewed: reviewedCount, simulated: simulated));
  }
  return points;
}
