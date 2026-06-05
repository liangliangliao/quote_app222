import 'dart:convert';

import '../data/kv_dao.dart';
import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'yangming_models.dart';

class YangmingAiService {
  final KeyValueDao _kvDao = KeyValueDao();
  final GlobalAiSettings _globalAiSettings = GlobalAiSettings();
  final UnifiedAiService _unifiedAiService = UnifiedAiService();

  String _lessonContentContext(YangmingLesson lesson, {YangmingLessonContent? content}) {
    final original = (content?.originalText ?? '').trim();
    final explanation = (content?.detailedExplanation ?? '').trim();
    final originalSnippet = original.isEmpty ? '未提供原文。' : (original.length > 1600 ? '${original.substring(0, 1600)}…' : original);
    final explanationSnippet = explanation.isEmpty ? '未提供详细解释。' : (explanation.length > 2400 ? '${explanation.substring(0, 2400)}…' : explanation);
    return '原文：$originalSnippet\n详细解释：$explanationSnippet';
  }

  String _personaContext(YangmingPersonaProfile? profile) {
    if (profile == null || !profile.hasAnyProfile) {
      return '人格映射：未提供用户人格画像，请仅根据当前困扰与课程内容做一般化推断。';
    }
    return '人格映射：角色身份=${profile.roleIdentity.isEmpty ? '未填' : profile.roleIdentity}；人格倾向=${profile.personalityTendency.isEmpty ? '未填' : profile.personalityTendency}；常见偏差=${profile.commonBias.isEmpty ? '未填' : profile.commonBias}；高压触发=${profile.stressTrigger.isEmpty ? '未填' : profile.stressTrigger}；支持偏好=${profile.supportStyle.isEmpty ? '未填' : profile.supportStyle}。';
  }

  Future<Map<String, String>> getGlobalAiState() async {
    final state = await _globalAiSettings.getState();
    return <String, String>{
      'provider': state['provider'] ?? 'deepseek',
      'model': state['model'] ?? '',
      'label': state['label'] ?? '未配置',
      'available': state['available'] ?? '0',
      'note': (state['available'] == '1') ? '当前模块已复用主应用设置中的模型配置。' : '未检测到可用密钥，将回退到本地说明模式。',
    };
  }

  Future<YangmingExplainResult> explainLessonStructured({required YangmingLesson lesson, YangmingLessonContent? content, YangmingPersonaProfile? profile, String concern = ''}) async {
    final prompt = '''
你是“知行书院”的课程教练。请围绕以下课程对象生成结构化 JSON，只输出 JSON 对象，不要输出 markdown、不要输出代码块。

课程：${lesson.title}
分组：${lesson.group}
出处：${lesson.source}
核心概念：${lesson.coreConcepts.join('、')}
问题类型：${lesson.problemTypes.join('；')}
现实案例：${lesson.scenarioCases.join('；')}
建议行动：${lesson.actionPlans.join('；')}
用户当前困扰：${concern.trim().isEmpty ? '未提供，按一般学习者处理。' : concern.trim()}
${_lessonContentContext(lesson, content: content)}
${_personaContext(profile)}

请严格输出以下 JSON 结构：
{
  "core_problem": "一句话说明这段课最想解决的核心问题",
  "key_points": ["关键理解点1", "关键理解点2", "关键理解点3"],
  "misunderstandings": ["最常见误区1", "最常见误区2", "最常见误区3"],
  "case_analysis": "一个贴近现实的案例分析",
  "minimal_action": "今天就能开始的一条最小行动"
}
''';
    final map = await _requestJsonMap(prompt: prompt, purpose: 'lesson_explain_json');
    if (map.isEmpty) return YangmingExplainResult.fallback(lesson);
    return YangmingExplainResult.fromMap(map, raw: jsonEncode(map));
  }

  Future<YangmingActionPlanResult> generateActionPlanStructured({required YangmingLesson lesson, YangmingLessonContent? content, YangmingPersonaProfile? profile, required String concern}) async {
    final prompt = '''
你是“知行书院”的行动设计教练。请根据课程和用户困扰生成结构化 JSON，只输出 JSON 对象，不要输出 markdown、不要输出代码块。

课程：${lesson.title}
核心概念：${lesson.coreConcepts.join('、')}
问题类型：${lesson.problemTypes.join('；')}
用户困扰：${concern.trim()}
课程建议行动：${lesson.actionPlans.join('；')}
课程复盘问题：${lesson.reviewPrompts.join('；')}
${_lessonContentContext(lesson, content: content)}
${_personaContext(profile)}

请严格输出以下 JSON 结构：
{
  "problem_judgment": "一句话判断当前更像哪种问题结构",
  "today_minimal_action": "今天10分钟内可启动的最小行动",
  "week_chain": ["本周步骤1", "本周步骤2", "本周步骤3", "本周步骤4"],
  "recovery_action": "如果失败后的补救动作",
  "review_question": "晚间最值得回答的一道复盘问题"
}
''';
    final map = await _requestJsonMap(prompt: prompt, purpose: 'action_plan_json');
    if (map.isEmpty) return YangmingActionPlanResult.fallback(lesson);
    return YangmingActionPlanResult.fromMap(map, raw: jsonEncode(map));
  }

  Future<YangmingTrainingPlanResult> generateTrainingPlanStructured({required YangmingLesson lesson, YangmingLessonContent? content, YangmingPersonaProfile? profile, required int durationDays, required String concern, String anchorAction = ''}) async {
    final prompt = '''
你是“知行书院”的周期训练教练。请根据课程、原文、详细解释、人格画像和用户当前困扰，生成一个${durationDays}天训练计划。只输出 JSON 对象，不要输出 markdown、不要输出代码块。

课程：${lesson.title}
核心概念：${lesson.coreConcepts.join('、')}
问题类型：${lesson.problemTypes.join('；')}
课程行动建议：${lesson.actionPlans.join('；')}
课程复盘问题：${lesson.reviewPrompts.join('；')}
用户当前困扰：${concern.trim().isEmpty ? '未提供具体困扰，请按一般练习者处理。' : concern.trim()}
锚定动作：${anchorAction.trim().isEmpty ? '未提供，请从课程行动建议中推断。' : anchorAction.trim()}
${_lessonContentContext(lesson, content: content)}
${_personaContext(profile)}

请严格输出以下 JSON 结构：
{
  "duration_days": ${durationDays},
  "plan_theme": "一句话命名这个训练计划",
  "plan_summary": "一句话说明这${durationDays}天最主要在练什么",
  "daily_tasks": ["第1天任务", "第2天任务"],
  "guardrails": ["训练守则1", "训练守则2", "训练守则3"],
  "checkpoints": ["阶段检查点1", "阶段检查点2", "阶段检查点3"],
  "review_prompts": ["复盘问题1", "复盘问题2", "复盘问题3"]
}
''';
    final map = await _requestJsonMap(prompt: prompt, purpose: 'training_plan_json');
    if (map.isEmpty) return YangmingTrainingPlanResult.fallback(lesson, durationDays);
    return YangmingTrainingPlanResult.fromMap(map, raw: jsonEncode(map));
  }

  String _trainingTraceContext(YangmingTrainingPlan plan, YangmingTrainingTrace trace) {
    final lines = trace.days.map((d) => "第${d.dayIndex}天｜完成=${d.done ? '是' : '否'}｜任务=${d.task}｜事实=${d.fact.trim().isEmpty ? '未填' : d.fact.trim()}｜反思=${d.reflection.trim().isEmpty ? '未填' : d.reflection.trim()}").join('\n');
    return '训练计划：${plan.planTheme}（${plan.durationDays}天）\n计划摘要：${plan.planSummary}\n已完成天数：${trace.completedDays}/${trace.days.length}\n每日打点：\n$lines';
  }

  Future<YangmingTrainingCorrectionResult> generateTrainingCorrectionStructured({
    required YangmingLesson lesson,
    YangmingLessonContent? content,
    YangmingPersonaProfile? profile,
    required YangmingTrainingPlan plan,
    required YangmingTrainingTrace trace,
  }) async {
    final prompt = '''
你是“知行书院”的周期训练纠偏教练。请根据课程、原文、详细解释、人格画像、训练计划和每日打点，生成结构化 JSON，只输出 JSON 对象，不要输出 markdown、不要输出代码块。

课程：${lesson.title}
核心概念：${lesson.coreConcepts.join('、')}
问题类型：${lesson.problemTypes.join('；')}
${_lessonContentContext(lesson, content: content)}
${_personaContext(profile)}
${_trainingTraceContext(plan, trace)}

请严格输出以下 JSON 结构：
{
  "main_pattern": "一句话说明当前训练最主要的问题模式",
  "keep_doing": "一句话说明最该继续保持的动作",
  "adjust_now": "一句话说明此刻最该调整什么",
  "next_focus": "未来3天训练重点",
  "reminder": "一句短提醒"
}
''';
    final map = await _requestJsonMap(prompt: prompt, purpose: 'training_correction_json');
    if (map.isEmpty) return YangmingTrainingCorrectionResult.fallback(plan, trace);
    return YangmingTrainingCorrectionResult.fromMap(map, raw: jsonEncode(map));
  }

  Future<YangmingTrainingWeeklySummaryResult> generateTrainingWeeklySummaryStructured({
    required YangmingLesson lesson,
    YangmingLessonContent? content,
    YangmingPersonaProfile? profile,
    required YangmingTrainingPlan plan,
    required YangmingTrainingTrace trace,
  }) async {
    final prompt = '''
你是“知行书院”的周期训练总结教练。请根据课程、原文、详细解释、人格画像、训练计划和每日打点，生成一份周末总结。只输出 JSON 对象，不要输出 markdown、不要输出代码块。

课程：${lesson.title}
核心概念：${lesson.coreConcepts.join('、')}
问题类型：${lesson.problemTypes.join('；')}
${_lessonContentContext(lesson, content: content)}
${_personaContext(profile)}
${_trainingTraceContext(plan, trace)}

请严格输出以下 JSON 结构：
{
  "completion_signal": "一句话总结完成情况",
  "biggest_shift": "一句话说明本周最主要的变化",
  "recurring_obstacle": "一句话说明最常反复出现的障碍",
  "next_week_focus": "下一阶段训练重点",
  "reminder": "一句提醒"
}
''';
    final map = await _requestJsonMap(prompt: prompt, purpose: 'training_weekly_summary_json');
    if (map.isEmpty) return YangmingTrainingWeeklySummaryResult.fallback(plan, trace);
    return YangmingTrainingWeeklySummaryResult.fromMap(map, raw: jsonEncode(map));
  }

  Future<YangmingAdaptiveMissionResult> buildAdaptiveMissionBranch({
    required YangmingLesson lesson,
    YangmingLessonContent? content,
    YangmingPersonaProfile? profile,
    required String concern,
    List<YangmingMissionRound> currentRounds = const <YangmingMissionRound>[],
  }) async {
    final prompt = '''
你是“知行书院”的虚拟世界关卡教练。请根据课程、原文、详细解释、人格画像和用户真实困扰，生成一份“AI动态分支”，用于替换状态机里的第2轮（结构辨认）和第3轮（现实迁移）。
你必须输出结构化 JSON，只输出 JSON 对象，不要输出 markdown、不要输出代码块。

课程：${lesson.title}
分组：${lesson.group}
出处：${lesson.source}
核心概念：${lesson.coreConcepts.join('、')}
问题类型：${lesson.problemTypes.join('；')}
现实案例：${lesson.scenarioCases.join('；')}
行动建议：${lesson.actionPlans.join('；')}
复盘问题：${lesson.reviewPrompts.join('；')}
用户现实困扰：${concern.trim()}
${_lessonContentContext(lesson, content: content)}
${_personaContext(profile)}

当前默认状态机结构：
${currentRounds.map((r) => '- ${r.id}｜${r.title}｜${r.prompt}').join('\n')}

请严格输出以下 JSON 结构：
{
  "branch_tag": "一句话命名这个动态分支，例如：回避型知行断裂 / 高目标逃避下手 / 自责型立志摇摆",
  "persona_lens": "一句话指出当前更接近哪种人格倾向，例如：回避型 / 过度思辨型 / 自责型 / 讨好型 / 完美主义型",
  "training_focus": "一句话说明这次动态分支最主要训练什么",
  "concern_mirror": "一句话复述并点明用户困扰的真正结构",
  "mission_reminder": "给用户进入本次动态关卡前的提醒",
  "dynamic_inner_round": {
    "id": "round_2_inner_ai",
    "title": "第二轮：辨认内在结构（AI）",
    "prompt": "一段新的轮次提示，必须贴合用户困扰",
    "guide": "一段引导语",
    "choices": [
      {"id": "A", "label": "选项A", "feedback": "对应反馈", "will_delta": -1, "awareness_delta": -1, "integration_delta": -1},
      {"id": "B", "label": "选项B", "feedback": "对应反馈", "will_delta": 1, "awareness_delta": 2, "integration_delta": 1},
      {"id": "C", "label": "选项C", "feedback": "对应反馈", "will_delta": 2, "awareness_delta": 3, "integration_delta": 3}
    ]
  },
  "dynamic_action_round": {
    "id": "round_3_action_ai",
    "title": "第三轮：现实迁移（AI）",
    "prompt": "一段新的现实迁移提示，必须贴合用户困扰",
    "guide": "一段行动引导语",
    "choices": [
      {"id": "A", "label": "选项A", "feedback": "对应反馈", "will_delta": -2, "awareness_delta": 0, "integration_delta": -2},
      {"id": "B", "label": "选项B", "feedback": "对应反馈", "will_delta": 1, "awareness_delta": 1, "integration_delta": 1},
      {"id": "C", "label": "选项C", "feedback": "对应反馈", "will_delta": 3, "awareness_delta": 2, "integration_delta": 4}
    ]
  },
  "bridge_action": "完成这次动态分支后，今天最小现实迁移动作",
  "review_question": "完成后最值得进入复盘的一道问题"
}
''';
    final map = await _requestJsonMap(prompt: prompt, purpose: 'adaptive_mission_json');
    if (map.isEmpty) return YangmingAdaptiveMissionResult.fallback(lesson, concern);
    return YangmingAdaptiveMissionResult.fromMap(map, raw: jsonEncode(map));
  }

  Future<YangmingNextCycleRecommendationResult> generateNextCycleRecommendationStructured({
    required YangmingLesson currentLesson,
    YangmingLessonContent? currentContent,
    YangmingPersonaProfile? profile,
    required YangmingTrainingPlan currentPlan,
    required YangmingTrainingTrace trace,
    required List<YangmingLesson> lessons,
    Map<String, YangmingLessonContent> lessonContents = const {},
    YangmingTrainingCorrectionResult? latestCorrection,
    YangmingTrainingWeeklySummaryResult? latestWeeklySummary,
  }) async {
    final shortlist = lessons.take(27).map((lesson) {
      final c = lessonContents[lesson.id];
      final detail = (c?.detailedExplanation ?? '').trim();
      final summary = detail.isEmpty ? '' : ' | 详解摘要:${detail.length > 100 ? detail.substring(0, 100) + '…' : detail}';
      return '${lesson.id} | ${lesson.title} | 分组:${lesson.group} | 问题类型:${lesson.problemTypes.join('、')} | 核心概念:${lesson.coreConcepts.join('、')}$summary';
    }).join('\n');
    final prompt = '''
你是“知行书院”的成长路径教练。请根据当前课程、原文、详细解释、人格画像、训练计划、每日打点、周中纠偏和周末总结，为用户推荐“下一轮课程与训练周期”。只输出 JSON 对象，不要输出 markdown、不要输出代码块。

当前课程：${currentLesson.title}
当前课程分组：${currentLesson.group}
${_lessonContentContext(currentLesson, content: currentContent)}
${_personaContext(profile)}
${_trainingTraceContext(currentPlan, trace)}
周中纠偏：${latestCorrection == null ? '暂无，按每日打点判断。' : '主要模式=${latestCorrection.mainPattern}；继续保持=${latestCorrection.keepDoing}；此刻调整=${latestCorrection.adjustNow}；未来3天=${latestCorrection.nextFocus}'}
周末总结：${latestWeeklySummary == null ? '暂无，按当前训练状态判断。' : '完成情况=${latestWeeklySummary.completionSignal}；最大变化=${latestWeeklySummary.biggestShift}；反复障碍=${latestWeeklySummary.recurringObstacle}；下周重点=${latestWeeklySummary.nextWeekFocus}'}

可选课程列表：
$shortlist

请严格输出以下 JSON 结构：
{
  "recommended_lesson_id": "课程ID",
  "recommended_lesson_title": "课程标题",
  "recommended_duration_days": 3,
  "recommendation_summary": "一句话说明为什么下一轮应该这样安排",
  "why_this_lesson": "一句话说明为什么推荐这段课程",
  "why_this_duration": "一句话说明为什么推荐这个训练天数",
  "training_focus": "一句话说明下一轮最该练的核心点",
  "starter_actions": ["下一轮起手动作1", "下一轮起手动作2", "下一轮起手动作3"],
  "review_prompts": ["复盘问题1", "复盘问题2", "复盘问题3"]
}
''';
    final map = await _requestJsonMap(prompt: prompt, purpose: 'next_cycle_recommendation_json');
    if (map.isEmpty) {
      return YangmingNextCycleRecommendationResult.fallback(currentLesson: currentLesson, currentPlan: currentPlan, trace: trace);
    }
    return YangmingNextCycleRecommendationResult.fromMap(map, raw: jsonEncode(map));
  }
  Future<YangmingReviewResult> generateReviewStructured({required YangmingLesson lesson, YangmingLessonContent? content, YangmingPersonaProfile? profile, required String fact, required String reflection}) async {
    final prompt = '''
你是“知行书院”的复盘教练。请基于课程、事实记录和用户反思生成结构化 JSON，只输出 JSON 对象，不要输出 markdown、不要输出代码块。

课程：${lesson.title}
核心概念：${lesson.coreConcepts.join('、')}
事实记录：$fact
用户反思：$reflection
${_lessonContentContext(lesson, content: content)}
${_personaContext(profile)}

请严格输出以下 JSON 结构：
{
  "main_problem": "这次最主要的问题结构",
  "affirmation": "这次最值得肯定的一点",
  "correction": "这次最需要修正的一点",
  "next_action": "明天最小行动",
  "reminder": "一句提醒"
}
''';
    final map = await _requestJsonMap(prompt: prompt, purpose: 'review_json');
    if (map.isEmpty) return YangmingReviewResult.fallback(lesson);
    return YangmingReviewResult.fromMap(map, raw: jsonEncode(map));
  }

  Future<YangmingGrowthNavigatorResult> generateGrowthNavigatorStructured({
    required List<YangmingLesson> lessons,
    required Map<String, YangmingLessonContent> lessonContents,
    YangmingPersonaProfile? profile,
    required List<YangmingAction> actions,
    required List<YangmingReviewEntry> reviews,
    required List<YangmingTrainingPlan> trainingPlans,
  }) async {
    final shortlist = lessons.take(27).map((e) {
      final c = lessonContents[e.id];
      final detail = (c?.detailedExplanation ?? '').trim();
      final summary = detail.isEmpty ? '' : ' | 详解摘要:${detail.length > 100 ? detail.substring(0, 100) + '…' : detail}';
      return '${e.id} | ${e.title} | 关卡:${e.missionTitle} | 问题:${e.problemTypes.join('、')} | 行动:${e.actionPlans.join('；')}$summary';
    }).join('\n');
    final actionCtx = actions.take(5).map((e) => '- ${e.lessonTitle}｜${e.taskTitle}｜状态=${e.status}').join('\n');
    final reviewCtx = reviews.take(5).map((e) => '- ${e.lessonTitle}｜事实=${e.fact.length > 80 ? e.fact.substring(0, 80) + '…' : e.fact}').join('\n');
    final planCtx = trainingPlans.take(5).map((e) => '- ${e.lessonTitle}｜${e.durationDays}天｜状态=${e.status}｜主题=${e.planTheme}').join('\n');
    final prompt = '''
你是“知行书院”的成长导航教练。请根据用户当前课程状态、人格画像、行动、复盘和训练计划，从候选课程中推荐一个“下一步最该进入的入口”。只输出 JSON 对象，不要输出 markdown、不要输出代码块。

${_personaContext(profile)}
当前行动：${actionCtx.isEmpty ? '暂无。' : '\n' + actionCtx}
当前复盘：${reviewCtx.isEmpty ? '暂无。' : '\n' + reviewCtx}
当前训练计划：${planCtx.isEmpty ? '暂无。' : '\n' + planCtx}
候选课程：
$shortlist

请严格输出以下 JSON 结构：
{
  "recommended_lesson_id": "课程ID",
  "recommended_lesson_title": "课程标题",
  "recommended_mission_title": "对应关卡标题",
  "recommended_duration_days": 3,
  "recommendation_summary": "一句话说明为什么现在最该进入这个入口",
  "why_this_lesson": "为什么是这段课程",
  "why_this_mission": "为什么先进入这个虚拟关卡",
  "why_this_duration": "为什么建议这个训练天数",
  "next_action": "打开首页后就能做的一步动作",
  "review_question": "带着进入下一轮的一道复盘问题"
}
''';
    final map = await _requestJsonMap(prompt: prompt, purpose: 'growth_navigator_json');
    if (map.isEmpty) {
      final lesson = lessons.isNotEmpty ? lessons.first : throw StateError('lessons empty');
      return YangmingGrowthNavigatorResult.fallback(
        lesson: lesson,
        durationDays: 3,
        summary: '先从一段课程、一关虚拟操练和一个最小动作重新接上知行闭环。',
        whyLesson: '当前没有足够结构化数据时，先回到最基础的课程入口更稳。',
        whyMission: '先进入关卡比只看课程更容易把问题带回现实。',
        whyDuration: '3天更适合先启动再观察。',
        nextAction: lesson.actionPlans.isNotEmpty ? lesson.actionPlans.first : '先完成一个10分钟动作。',
        reviewQuestion: lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '今天哪里最能体现当前问题结构？',
        source: 'ai_fallback',
      );
    }
    return YangmingGrowthNavigatorResult.fromMap(map, raw: jsonEncode(map), source: 'ai');
  }

  Future<YangmingDailyCockpitResult> generateDailyCockpitStructured({
    required List<YangmingLesson> lessons,
    required Map<String, YangmingLessonContent> lessonContents,
    YangmingPersonaProfile? profile,
    required List<YangmingAction> actions,
    required List<YangmingReviewEntry> reviews,
    required List<YangmingTrainingPlan> trainingPlans,
    YangmingGrowthNavigatorResult? growthNavigator,
  }) async {
    final shortlist = lessons.take(27).map((e) {
      final c = lessonContents[e.id];
      final detail = (c?.detailedExplanation ?? '').trim();
      final summary = detail.isEmpty ? '' : ' | 详解摘要:${detail.length > 90 ? detail.substring(0, 90) + '…' : detail}';
      return '${e.id} | ${e.title} | 关卡:${e.missionTitle} | 行动:${e.actionPlans.join('；')}$summary';
    }).join('\n');
    final actionCtx = actions.take(6).map((e) => '- ${e.lessonTitle}｜${e.taskTitle}｜状态=${e.status}').join('\n');
    final reviewCtx = reviews.take(4).map((e) => '- ${e.lessonTitle}｜事实=${e.fact.length > 70 ? e.fact.substring(0, 70) + '…' : e.fact}').join('\n');
    final planCtx = trainingPlans.take(4).map((e) => '- ${e.lessonTitle}｜${e.durationDays}天｜状态=${e.status}｜主题=${e.planTheme}').join('\n');
    final navCtx = growthNavigator == null
        ? '暂无成长导航。'
        : '当前成长导航：课程=${growthNavigator.recommendedLessonTitle}｜关卡=${growthNavigator.recommendedMissionTitle}｜动作=${growthNavigator.nextAction}｜问题=${growthNavigator.reviewQuestion}';
    final prompt = '''
你是“知行书院”的每日知行驾驶舱教练。请根据用户当前课程状态、人格画像、行动、复盘、训练计划和成长导航，给出“今天最该做的一步”。只输出 JSON 对象，不要输出 markdown、不要输出代码块。

${_personaContext(profile)}
$navCtx
当前行动：${actionCtx.isEmpty ? '暂无。' : '\n' + actionCtx}
当前复盘：${reviewCtx.isEmpty ? '暂无。' : '\n' + reviewCtx}
当前训练计划：${planCtx.isEmpty ? '暂无。' : '\n' + planCtx}
候选课程：
$shortlist

请严格输出以下 JSON 结构：
{
  "headline": "今日驾驶舱标题",
  "today_focus": "今天最该守住的焦点",
  "today_action": "今天最小行动",
  "training_prompt": "今天更适合继续哪种训练或入口",
  "reflection_question": "今晚最该回答的一道复盘问题",
  "recommended_lesson_id": "课程ID",
  "recommended_lesson_title": "课程标题",
  "recommended_mission_title": "关卡标题",
  "linked_plan_id": "若存在最该继续的训练计划ID，否则留空",
  "linked_plan_theme": "若存在对应训练计划主题，否则留空"
}
''';
    final map = await _requestJsonMap(prompt: prompt, purpose: 'daily_cockpit_json');
    if (map.isEmpty) {
      final lesson = growthNavigator != null
          ? lessons.firstWhere((e) => e.id == growthNavigator.recommendedLessonId, orElse: () => lessons.first)
          : lessons.first;
      return YangmingDailyCockpitResult.fallback(
        lesson: lesson,
        headline: '今日先把知行重新接上',
        todayFocus: growthNavigator?.recommendationSummary ?? '先不要再开新题，先把今天最该做的一步接上。',
        todayAction: growthNavigator?.nextAction ?? (lesson.actionPlans.isNotEmpty ? lesson.actionPlans.first : '先完成一个最小动作。'),
        trainingPrompt: growthNavigator == null ? '先进入对应课程与关卡。' : '先沿着当前成长导航进入对应课程或关卡。',
        reflectionQuestion: growthNavigator?.reviewQuestion ?? (lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '今天哪里最能体现当前问题结构？'),
        source: 'ai_fallback',
      );
    }
    return YangmingDailyCockpitResult.fromMap(map, raw: jsonEncode(map), source: 'ai');
  }

  Future<YangmingDiagnosisResult> diagnoseStructured({required String concern, required List<YangmingLesson> lessons, Map<String, YangmingLessonContent> lessonContents = const {}, YangmingPersonaProfile? profile}) async {
    final shortlist = lessons.take(12).map((e) {
      final c = lessonContents[e.id];
      final detail = (c?.detailedExplanation ?? '').trim();
      final summary = detail.isEmpty ? '' : ' | 详解摘要:${detail.length > 120 ? detail.substring(0, 120) + '…' : detail}';
      return '${e.id} | ${e.title} | 问题类型:${e.problemTypes.join('、')} | 核心概念:${e.coreConcepts.join('、')}$summary';
    }).join('\n');
    final prompt = '''
你是“知行书院”的诊断教练。请根据用户困扰，从课程列表中匹配最相关的3段，并用结构化 JSON 输出。只输出 JSON 对象，不要输出 markdown、不要输出代码块。

用户困扰：$concern
${_personaContext(profile)}
候选课程：
$shortlist

请严格输出以下 JSON 结构：
{
  "top_matches": [
    {"lesson_id": "课程ID", "title": "课程标题", "reason": "为什么相关"},
    {"lesson_id": "课程ID", "title": "课程标题", "reason": "为什么相关"},
    {"lesson_id": "课程ID", "title": "课程标题", "reason": "为什么相关"}
  ],
  "main_problem_structure": "一句话判断用户当前最主要的问题结构",
  "recommended_start_lesson_id": "最适合先学的课程ID",
  "recommended_start_lesson_title": "最适合先学的课程标题"
}
''';
    final map = await _requestJsonMap(prompt: prompt, purpose: 'diagnosis_json');
    if (map.isEmpty) return YangmingDiagnosisResult.fallback(lessons);
    return YangmingDiagnosisResult.fromMap(map, raw: jsonEncode(map));
  }

  Future<YangmingActionDiagnosisResult> diagnoseActionExecutionStructured({
    required YangmingLesson lesson,
    YangmingLessonContent? content,
    YangmingPersonaProfile? profile,
    required YangmingAction action,
    required String fact,
  }) async {
    final prompt = '''
你是“知行书院”的行动诊断教练。请基于课程、行动任务和事实记录生成结构化 JSON，只输出 JSON 对象，不要输出 markdown、不要输出代码块。

课程：${lesson.title}
核心概念：${lesson.coreConcepts.join('、')}
问题类型：${lesson.problemTypes.join('；')}
行动任务：${action.taskTitle}
任务说明：${action.instruction}
已记录事实：${fact.trim()}
${_lessonContentContext(lesson, content: content)}
${_personaContext(profile)}

请严格输出以下 JSON 结构：
{
  "main_problem_structure": "一句话判断当前最主要的问题结构",
  "likely_bias": "一句话指出最可能的偏差或卡点",
  "fact_advice": "如何把事实记录得更清楚，或下一步如何看清问题",
  "next_micro_action": "接下来24小时内最小动作",
  "review_question": "最值得进入复盘的一道问题",
  "recommended_lesson_id": "最值得回看的课程ID",
  "recommended_lesson_title": "最值得回看的课程标题"
}
''';
    final map = await _requestJsonMap(prompt: prompt, purpose: 'action_execution_diagnosis_json');
    if (map.isEmpty) return YangmingActionDiagnosisResult.fallback(lesson, fact);
    return YangmingActionDiagnosisResult.fromMap(map, raw: jsonEncode(map));
  }

  Future<Map<String, dynamic>> _requestJsonMap({required String prompt, required String purpose}) async {
    final raw = await _requestText(prompt: prompt, purpose: purpose);
    final parsed = _extractJsonObject(raw);
    return parsed;
  }

  Future<String> _requestText({required String prompt, required String purpose}) async {
    return _unifiedAiService.generateText(
      prompt: prompt,
      purpose: 'yangming_ai.$purpose',
      systemPrompt: '你是知行书院的AI教练。回答必须全中文，且若用户要求JSON则只能输出JSON对象。',
      maxTokens: 1800,
      expectJson: true,
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
    final trimmed = raw.trim();
    final fenced = trimmed.replaceAll('```json', '').replaceAll('```', '').trim();
    final fencedDecoded = _tryDecodeObject(fenced);
    if (fencedDecoded.isNotEmpty) return fencedDecoded;
    final start = fenced.indexOf('{');
    final end = fenced.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final sub = fenced.substring(start, end + 1);
      final subDecoded = _tryDecodeObject(sub);
      if (subDecoded.isNotEmpty) return subDecoded;
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
