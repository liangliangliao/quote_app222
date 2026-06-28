import 'package:flutter/material.dart';

import '../pages/settings_page.dart';
import 'yangming_ai_service.dart';
import 'yangming_content_import_page.dart';
import 'yangming_dao.dart';
import 'yangming_models.dart';
import 'yangming_seed.dart';

String _safeSnippet(String text, {int max = 120}) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) return '';
  return normalized.length <= max ? normalized : '${normalized.substring(0, max)}…';
}

String _buildActionInstruction({required YangmingLesson lesson, YangmingLessonContent? content, required String instruction}) {
  final parts = <String>[instruction.trim()];
  final quote = _safeSnippet(content?.originalText ?? '', max: 90);
  final explain = _safeSnippet(content?.detailedExplanation ?? '', max: 120);
  if (quote.isNotEmpty) parts.add('对应原文：$quote');
  if (explain.isNotEmpty) parts.add('详解提醒：$explain');
  if (lesson.reviewPrompts.isNotEmpty) parts.add('复盘问题：${lesson.reviewPrompts.first}');
  return parts.where((e) => e.trim().isNotEmpty).join('\n');
}


class YangmingModuleHomePage extends StatefulWidget {
  const YangmingModuleHomePage({super.key});

  @override
  State<YangmingModuleHomePage> createState() => _YangmingModuleHomePageState();
}

class _YangmingModuleHomePageState extends State<YangmingModuleHomePage> {
  final YangmingDao _dao = YangmingDao();
  final YangmingAiService _ai = YangmingAiService();

  bool _loading = true;
  String _loadWarning = '';
  int _idx = 0;
  List<YangmingAction> _actions = <YangmingAction>[];
  List<YangmingReviewEntry> _reviews = <YangmingReviewEntry>[];
  List<YangmingTrainingPlan> _trainingPlans = <YangmingTrainingPlan>[];
  Set<String> _doneLessons = <String>{};
  Map<String, YangmingLessonContent> _lessonContents = <String, YangmingLessonContent>{};
  Map<String, YangmingMissionConfig> _missionConfigs = <String, YangmingMissionConfig>{};
  Map<String, String> _aiState = const <String, String>{'label': '读取中…'};
  YangmingPersonaProfile _personaProfile = YangmingPersonaProfile.empty;
  YangmingGrowthNavigatorResult? _growthNavigator;
  bool _growthNavigatorLoading = false;
  YangmingDailyCockpitResult? _dailyCockpit;
  bool _dailyCockpitLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadWarning = '';
      });
    }

    final List<String> warnings = <String>[];

    Future<T> guard<T>(Future<T> Function() loader, T fallback, String label) async {
      try {
        return await loader();
      } catch (e) {
        warnings.add(label);
        return fallback;
      }
    }

    final actions = await guard<List<YangmingAction>>(_dao.loadActions, <YangmingAction>[], '行动数据');
    final reviews = await guard<List<YangmingReviewEntry>>(_dao.loadReviews, <YangmingReviewEntry>[], '复盘数据');
    final trainingPlans = await guard<List<YangmingTrainingPlan>>(_dao.loadTrainingPlans, <YangmingTrainingPlan>[], '周期训练计划');
    final done = await guard<Set<String>>(_dao.loadCompletedLessons, <String>{}, '完成进度');
    final contents = await guard<Map<String, YangmingLessonContent>>(_dao.loadLessonContents, <String, YangmingLessonContent>{}, '课程内容');
    final profile = await guard<YangmingPersonaProfile>(_dao.loadPersonaProfile, YangmingPersonaProfile.empty, '人格画像');
    final aiState = await guard<Map<String, String>>(_ai.getGlobalAiState, const <String, String>{'label': '读取失败', 'available': '0'}, '模型状态');
    final missionConfigs = await guard<Map<String, YangmingMissionConfig>>(loadYangmingMissionConfigs, <String, YangmingMissionConfig>{}, '关卡配置');
    final latestNavigator = await guard<YangmingGrowthNavigatorResult?>(_dao.loadLatestGrowthNavigator, null, '成长导航回流');
    final latestNextCycle = await guard<YangmingNextCycleRecommendationResult?>(_dao.loadLatestNextCycleRecommendation, null, '下一周期回流');
    final latestDailyCockpit = await guard<YangmingDailyCockpitResult?>(_dao.loadLatestDailyCockpit, null, '每日驾驶舱');
    final fallbackNavigator = _buildHeuristicNavigator(
      actions: actions,
      reviews: reviews,
      trainingPlans: trainingPlans,
      profile: profile,
    );
    final resolvedNavigator = latestNavigator ?? (latestNextCycle != null ? _navigatorFromNextCycleRecommendation(latestNextCycle, source: 'auto_next_cycle_cached') : fallbackNavigator);
    final resolvedDailyCockpit = latestDailyCockpit ?? _buildDailyCockpit(
      actions: actions,
      trainingPlans: trainingPlans,
      reviews: reviews,
      navigator: resolvedNavigator,
      profile: profile,
    );
    if (!mounted) return;
    setState(() {
      _actions = actions;
      _reviews = reviews;
      _trainingPlans = trainingPlans;
      _doneLessons = done;
      _lessonContents = contents;
      _missionConfigs = missionConfigs;
      _personaProfile = profile;
      _aiState = aiState;
      _growthNavigator = resolvedNavigator;
      _dailyCockpit = resolvedDailyCockpit;
      _loadWarning = warnings.isEmpty ? '' : '部分数据加载失败：${warnings.join('、')}。其余内容已继续显示。';
      _loading = false;
    });
  }

  YangmingLesson _lessonById(String lessonId) {
    return yangmingLessons.firstWhere((e) => e.id == lessonId, orElse: () => yangmingLessons.first);
  }

  YangmingGrowthNavigatorResult _navigatorFromNextCycleRecommendation(YangmingNextCycleRecommendationResult rec, {String source = 'auto_next_cycle_reflow'}) {
    final lesson = _lessonById(rec.recommendedLessonId);
    final missionTitle = lesson.missionTitle.trim().isEmpty ? '进入对应虚拟关卡' : lesson.missionTitle;
    final nextAction = rec.starterActions.isNotEmpty ? rec.starterActions.first : (lesson.actionPlans.isNotEmpty ? lesson.actionPlans.first : '先完成一个最小动作。');
    final reviewQuestion = rec.reviewPrompts.isNotEmpty ? rec.reviewPrompts.first : (lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '今天哪里最能体现当前问题结构？');
    return YangmingGrowthNavigatorResult(
      recommendedLessonId: lesson.id,
      recommendedLessonTitle: rec.recommendedLessonTitle.trim().isEmpty ? lesson.title : rec.recommendedLessonTitle,
      recommendedMissionTitle: missionTitle,
      recommendedDurationDays: rec.recommendedDurationDays <= 0 ? 3 : rec.recommendedDurationDays,
      recommendationSummary: rec.recommendationSummary.trim().isEmpty ? '系统已根据当前训练轨迹自动回流出下一周期建议。' : rec.recommendationSummary,
      whyThisLesson: rec.whyThisLesson.trim().isEmpty ? '当前训练轨迹显示，这段课程更适合作为下一轮继续深化的入口。' : rec.whyThisLesson,
      whyThisMission: '先进入对应关卡，把下一轮训练重点带回情境中操练，再落回现实行动。',
      whyThisDuration: rec.whyThisDuration.trim().isEmpty ? '这是根据当前守持节奏自动给出的下一周期长度。' : rec.whyThisDuration,
      nextAction: nextAction,
      reviewQuestion: reviewQuestion,
      source: source,
      raw: rec.raw,
    );
  }

  YangmingGrowthNavigatorResult _navigatorFromWeeklySummary({required YangmingLesson lesson, required YangmingTrainingPlan plan, required YangmingTrainingWeeklySummaryResult summary, required YangmingTrainingTrace trace}) {
    final nextAction = plan.dailyTasks.isNotEmpty ? plan.dailyTasks[(trace.completedDays.clamp(0, plan.dailyTasks.length - 1)).toInt()] : (lesson.actionPlans.isNotEmpty ? lesson.actionPlans.first : '先把一个最小动作接回现实。');
    final reviewQuestion = plan.reviewPrompts.isNotEmpty ? plan.reviewPrompts.first : (lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '今天哪里最能体现当前问题结构？');
    return YangmingGrowthNavigatorResult(
      recommendedLessonId: lesson.id,
      recommendedLessonTitle: lesson.title,
      recommendedMissionTitle: lesson.missionTitle,
      recommendedDurationDays: plan.durationDays,
      recommendationSummary: '已根据本周总结自动更新成长导航：先围绕当前课程继续守持，再进入下一轮推荐。',
      whyThisLesson: summary.nextWeekFocus.trim().isEmpty ? '当前周总结显示，还需要继续围绕这段课程压实训练。' : summary.nextWeekFocus,
      whyThisMission: summary.recurringObstacle.trim().isEmpty ? '先回到对应关卡重看高频卡点，再落回现实守持。' : '本周反复障碍提示：${summary.recurringObstacle}',
      whyThisDuration: '当前已有${plan.durationDays}天训练在推进，先把这一轮总结出的重点继续压实。',
      nextAction: nextAction,
      reviewQuestion: reviewQuestion,
      source: 'auto_weekly_reflow',
      raw: summary.raw,
    );
  }

  YangmingDailyCockpitResult _cockpitFromGrowthNavigator(YangmingGrowthNavigatorResult navigator, {YangmingTrainingPlan? linkedPlan, String source = 'auto_growth_reflow'}) {
    final lesson = _lessonById(navigator.recommendedLessonId);
    return YangmingDailyCockpitResult.fallback(
      lesson: lesson,
      headline: '今日最该守住的一步',
      todayFocus: navigator.recommendationSummary,
      todayAction: navigator.nextAction,
      trainingPrompt: linkedPlan != null ? '先继续训练：${linkedPlan.planTheme}' : '先进入：${navigator.recommendedMissionTitle}',
      reflectionQuestion: navigator.reviewQuestion,
      linkedPlanId: linkedPlan?.id ?? '',
      linkedPlanTheme: linkedPlan?.planTheme ?? '',
      source: source,
    );
  }

  YangmingDailyCockpitResult _buildDailyCockpit({
    required List<YangmingAction> actions,
    required List<YangmingTrainingPlan> trainingPlans,
    required List<YangmingReviewEntry> reviews,
    required YangmingGrowthNavigatorResult navigator,
    required YangmingPersonaProfile profile,
  }) {
    final activePlan = trainingPlans.where((e) => e.status != 'done').cast<YangmingTrainingPlan?>().firstWhere((e) => e != null, orElse: () => null);
    if (activePlan != null) {
      final lesson = _lessonById(activePlan.lessonId);
      final todayTask = activePlan.dailyTasks.isNotEmpty ? activePlan.dailyTasks.first : (lesson.actionPlans.isNotEmpty ? lesson.actionPlans.first : navigator.nextAction);
      return YangmingDailyCockpitResult.fallback(
        lesson: lesson,
        headline: '今日先守住正在进行的训练',
        todayFocus: '你已经有一份进行中的${activePlan.durationDays}天计划，当前最重要的是别切换主题，把这一轮真正做完。',
        todayAction: todayTask,
        trainingPrompt: '先打开“每日打点 / 纠偏”，继续：${activePlan.planTheme}',
        reflectionQuestion: activePlan.reviewPrompts.isNotEmpty ? activePlan.reviewPrompts.first : navigator.reviewQuestion,
        linkedPlanId: activePlan.id,
        linkedPlanTheme: activePlan.planTheme,
        source: 'heuristic_active_plan',
      );
    }
    final pendingAction = actions.where((e) => e.status != 'done').cast<YangmingAction?>().firstWhere((e) => e != null, orElse: () => null);
    if (pendingAction != null) {
      final lesson = _lessonById(pendingAction.lessonId);
      return YangmingDailyCockpitResult.fallback(
        lesson: lesson,
        headline: '今日先把这条行动真正做掉',
        todayFocus: '你当前最需要的不是再开新题，而是把最近这条未完成行动带回现实。',
        todayAction: pendingAction.taskTitle,
        trainingPrompt: '先回到${lesson.missionTitle}，把行动和情境重新接上。',
        reflectionQuestion: pendingAction.reviewQuestion.isNotEmpty ? pendingAction.reviewQuestion : navigator.reviewQuestion,
        source: 'heuristic_pending_action',
      );
    }
    if (reviews.isNotEmpty || profile.hasAnyProfile) {
      return _cockpitFromGrowthNavigator(navigator, source: navigator.source.startsWith('auto') ? 'auto_growth_reflow' : 'heuristic_growth');
    }
    return _cockpitFromGrowthNavigator(navigator, source: 'heuristic_default');
  }

  Future<void> _runDailyCockpitAi() async {
    if (_dailyCockpitLoading) return;
    setState(() => _dailyCockpitLoading = true);
    try {
      final result = await _ai.generateDailyCockpitStructured(
        lessons: yangmingLessons,
        lessonContents: _lessonContents,
        profile: _personaProfile,
        actions: _actions,
        reviews: _reviews,
        trainingPlans: _trainingPlans,
        growthNavigator: _growthNavigator,
      );
      await _dao.saveLatestDailyCockpit(result);
      if (!mounted) return;
      setState(() => _dailyCockpit = result);
    } finally {
      if (mounted) setState(() => _dailyCockpitLoading = false);
    }
  }

  Future<void> _openDailyCockpitLesson() async {
    final cockpit = _dailyCockpit;
    if (cockpit == null) return;
    await _openLesson(_lessonById(cockpit.recommendedLessonId));
  }

  Future<void> _openDailyCockpitMission() async {
    final cockpit = _dailyCockpit;
    if (cockpit == null) return;
    await _openMission(_lessonById(cockpit.recommendedLessonId));
  }

  Future<void> _openDailyCockpitPlan() async {
    final cockpit = _dailyCockpit;
    if (cockpit == null || cockpit.linkedPlanId.trim().isEmpty) return;
    final plan = _trainingPlans.where((e) => e.id == cockpit.linkedPlanId).cast<YangmingTrainingPlan?>().firstWhere((e) => e != null, orElse: () => null);
    if (plan != null) {
      await _openTrainingPlanWorkbench(plan);
    }
  }

  YangmingGrowthNavigatorResult _buildHeuristicNavigator({
    required List<YangmingAction> actions,
    required List<YangmingReviewEntry> reviews,
    required List<YangmingTrainingPlan> trainingPlans,
    required YangmingPersonaProfile profile,
  }) {
    YangmingLesson chooseByKeywords() {
      final text = '${profile.personalityTendency} ${profile.commonBias} ${profile.stressTrigger}'.toLowerCase();
      if (text.contains('回避') || text.contains('拖延')) return _lessonById('ZX-01');
      if (text.contains('起念') || text.contains('情绪') || text.contains('嫉妒')) return _lessonById('ZX-12');
      if (text.contains('完美') || text.contains('高目标') || text.contains('结果')) return _lessonById('LZ-03');
      if (text.contains('分心') || text.contains('外好')) return _lessonById('LZ-06');
      if (text.contains('自责') || text.contains('否定')) return _lessonById('ZX-10');
      if (text.contains('讨好') || text.contains('关系') || text.contains('利害')) return _lessonById('LZ-10');
      if (text.contains('想太多') || text.contains('思辨')) return _lessonById('ZX-06');
      return _lessonById('ZX-01');
    }

    final activePlan = trainingPlans.where((e) => e.status != 'done').cast<YangmingTrainingPlan?>().firstWhere((e) => e != null, orElse: () => null);
    if (activePlan != null) {
      final lesson = _lessonById(activePlan.lessonId);
      return YangmingGrowthNavigatorResult.fallback(
        lesson: lesson,
        durationDays: activePlan.durationDays,
        summary: '先把正在进行的训练计划继续接稳，再通过课程与关卡把它压实。',
        whyLesson: '你当前最需要的不是切换主题，而是把正在练的这一段真正守住。',
        whyMission: '先回到对应关卡，能把训练中的高频卡点重新看清。',
        whyDuration: '当前已有${activePlan.durationDays}天训练在推进，先把这一轮做完更符合长期闭环。',
        nextAction: activePlan.dailyTasks.isNotEmpty ? activePlan.dailyTasks.first : (lesson.actionPlans.isNotEmpty ? lesson.actionPlans.first : '先完成一个最小动作。'),
        reviewQuestion: activePlan.reviewPrompts.isNotEmpty ? activePlan.reviewPrompts.first : (lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '今天哪里最能体现当前问题结构？'),
        source: 'heuristic_active_plan',
      );
    }

    final pendingAction = actions.where((e) => e.status != 'done').cast<YangmingAction?>().firstWhere((e) => e != null, orElse: () => null);
    if (pendingAction != null) {
      final lesson = _lessonById(pendingAction.lessonId);
      return YangmingGrowthNavigatorResult.fallback(
        lesson: lesson,
        durationDays: 3,
        summary: '你现在最该做的不是再开新主题，而是把最近这条行动真正做到并带回复盘。',
        whyLesson: '最近未完成行动已经明确指向这段课程的问题结构。',
        whyMission: '先进对应关卡，能把“知道但没做”重新带回情境中操练。',
        whyDuration: '先用3天训练把最近这条行动压实，比直接跳长周期更稳。',
        nextAction: pendingAction.taskTitle,
        reviewQuestion: pendingAction.reviewQuestion.isNotEmpty ? pendingAction.reviewQuestion : (lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '今天最需要复盘的问题是什么？'),
        source: 'heuristic_pending_action',
      );
    }

    final lesson = chooseByKeywords();
    final duration = reviews.isEmpty ? 3 : 7;
    final summary = profile.hasAnyProfile
        ? '根据你当前的人格倾向与最近训练状态，系统建议先从这段课程与对应关卡重新进入。'
        : '先从一段基础课程和对应关卡进入，再慢慢建立更稳定的成长路径。';
    return YangmingGrowthNavigatorResult.fallback(
      lesson: lesson,
      durationDays: duration,
      summary: summary,
      whyLesson: profile.hasAnyProfile ? '你当前画像里最显著的倾向，更容易在这段课程里得到针对性训练。' : '这段课程最适合作为当前阶段的基础入口。',
      whyMission: '先用虚拟关卡把问题带进情境，再落回现实动作，更符合原 PRD 的训练主线。',
      whyDuration: duration == 3 ? '先用3天把入口接上。' : '7天更适合把课程、关卡和现实行动接成一轮。',
      nextAction: lesson.actionPlans.isNotEmpty ? lesson.actionPlans.first : '今天先完成一个最小动作。',
      reviewQuestion: lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '今天哪里最能体现当前问题结构？',
      source: profile.hasAnyProfile ? 'heuristic_profile' : 'heuristic_default',
    );
  }

  Future<void> _runGrowthNavigatorAi() async {
    if (_growthNavigatorLoading) return;
    setState(() => _growthNavigatorLoading = true);
    try {
      final result = await _ai.generateGrowthNavigatorStructured(
        lessons: yangmingLessons,
        lessonContents: _lessonContents,
        profile: _personaProfile,
        actions: _actions,
        reviews: _reviews,
        trainingPlans: _trainingPlans,
      );
      await _dao.saveLatestGrowthNavigator(result);
      final cockpit = _buildDailyCockpit(
        actions: _actions,
        trainingPlans: _trainingPlans,
        reviews: _reviews,
        navigator: result,
        profile: _personaProfile,
      );
      await _dao.saveLatestDailyCockpit(cockpit);
      if (!mounted) return;
      setState(() {
        _growthNavigator = result;
        _dailyCockpit = cockpit;
      });
    } finally {
      if (mounted) setState(() => _growthNavigatorLoading = false);
    }
  }

  Future<void> _openRecommendedLesson() async {
    final rec = _growthNavigator;
    if (rec == null) return;
    await _openLesson(_lessonById(rec.recommendedLessonId));
  }

  Future<void> _openRecommendedMission() async {
    final rec = _growthNavigator;
    if (rec == null) return;
    await _openMission(_lessonById(rec.recommendedLessonId));
  }


  Future<void> _saveAction(YangmingAction action) async {
    await _dao.saveAction(action);
    await _dao.markLessonCompleted(action.lessonId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入行动中心')));
  }

  Future<void> _saveTrainingPlan(YangmingTrainingPlan plan) async {
    await _dao.saveTrainingPlan(plan);
    await _dao.markLessonCompleted(plan.lessonId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入周期训练计划')));
  }

  Future<void> _toggleTrainingPlanDone(YangmingTrainingPlan plan, bool done) async {
    await _dao.markTrainingPlanDone(plan.id, done);
    await _load();
  }

  Future<void> _openTrainingPlanWorkbench(YangmingTrainingPlan plan) async {
    final lesson = _lessonById(plan.lessonId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YangmingTrainingPlanWorkbenchPage(
          plan: plan,
          lesson: lesson,
          lessonContent: _lessonContents[lesson.id],
          lessonContents: _lessonContents,
          profile: _personaProfile,
          ai: _ai,
          dao: _dao,
          onPublishNavigator: (YangmingGrowthNavigatorResult result) async {
            await _dao.saveLatestGrowthNavigator(result);
            final linkedPlan = _trainingPlans.where((e) => e.id == plan.id).cast<YangmingTrainingPlan?>().firstWhere((e) => e != null, orElse: () => plan);
            await _dao.saveLatestDailyCockpit(_cockpitFromGrowthNavigator(result, linkedPlan: linkedPlan, source: 'auto_growth_reflow'));
          },
          onPublishNextCycle: (YangmingNextCycleRecommendationResult result) async {
            await _dao.saveLatestNextCycleRecommendation(result);
            final nav = _navigatorFromNextCycleRecommendation(result);
            await _dao.saveLatestGrowthNavigator(nav);
            await _dao.saveLatestDailyCockpit(_cockpitFromGrowthNavigator(nav, source: 'auto_next_cycle_reflow'));
          },
        ),
      ),
    );
    await _load();
  }

  Future<void> _toggleActionDone(YangmingAction action, bool done) async {
    await _dao.markActionDone(action.id, done);
    await _load();
  }

  Future<void> _saveReview(YangmingReviewEntry review) async {
    await _dao.saveReview(review);
    await _dao.markLessonCompleted(review.lessonId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存复盘')));
  }

  Future<void> _openPersonaProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YangmingPersonaProfilePage(
          dao: _dao,
          initialProfile: _personaProfile,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openImportCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YangmingContentImportPage(
          dao: _dao,
          lessons: yangmingLessons,
          existingContents: _lessonContents,
          onChanged: _load,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openLesson(YangmingLesson lesson) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YangmingLessonDetailPage(
          lesson: lesson,
          lessonContent: _lessonContents[lesson.id],
          dao: _dao,
          ai: _ai,
          aiState: _aiState,
          profile: _personaProfile,
          isCompleted: _doneLessons.contains(lesson.id),
          onCreateAction: (String instruction, {String source = 'manual'}) async {
            final action = _dao.createAction(
              lessonId: lesson.id,
              lessonTitle: lesson.title,
              taskTitle: '${lesson.title} · 现实行动',
              instruction: _buildActionInstruction(lesson: lesson, content: _lessonContents[lesson.id], instruction: instruction),
              source: source,
              reviewQuestion: lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '',
            );
            await _saveAction(action);
          },
          onOpenMission: () async => _openMission(lesson),
          onOpenReview: () async => _openReviewComposer(lesson: lesson),
          onOpenImportCenter: _openImportCenter,
          onContentChanged: _load,
          onSaveTrainingPlan: (YangmingTrainingPlan plan) async {
            await _saveTrainingPlan(plan);
          },
        ),
      ),
    );
    await _load();
  }

  Future<void> _openMission(YangmingLesson lesson) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YangmingMissionPage(
          lesson: lesson,
          lessonContent: _lessonContents[lesson.id],
          missionConfig: _missionConfigs[lesson.id],
          profile: _personaProfile,
          ai: _ai,
          onCreateAction: (String instruction) async {
            final action = _dao.createAction(
              lessonId: lesson.id,
              lessonTitle: lesson.title,
              taskTitle: '${lesson.missionTitle} · 迁移任务',
              instruction: _buildActionInstruction(lesson: lesson, content: _lessonContents[lesson.id], instruction: instruction),
              source: 'mission',
              reviewQuestion: lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '',
            );
            await _saveAction(action);
          },
        ),
      ),
    );
    await _load();
  }

  Future<void> _openDiagnosis() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YangmingDiagnosisPage(ai: _ai, lessons: yangmingLessons, lessonContents: _lessonContents, profile: _personaProfile, onOpenLesson: _openLesson),
      ),
    );
    await _load();
  }

  Future<void> _openReviewComposer({YangmingLesson? lesson, YangmingAction? action}) async {
    final targetLesson = lesson ?? _lessonById(action!.lessonId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YangmingReviewComposerPage(
          lesson: targetLesson,
          lessonContent: _lessonContents[targetLesson.id],
          ai: _ai,
          profile: _personaProfile,
          initialFact: action?.fact ?? '',
          onSave: (String fact, String reflection, String aiSummary) async {
            final review = _dao.createReview(
              lessonId: targetLesson.id,
              lessonTitle: targetLesson.title,
              fact: fact,
              reflection: reflection,
              aiSummary: aiSummary,
            );
            await _saveReview(review);
          },
          onCreateFollowupAction: (String instruction) async {
            final followup = _dao.createAction(
              lessonId: targetLesson.id,
              lessonTitle: targetLesson.title,
              taskTitle: '${targetLesson.title} · 复盘后下一步',
              instruction: _buildActionInstruction(lesson: targetLesson, content: _lessonContents[targetLesson.id], instruction: instruction),
              source: 'review_followup',
              reviewQuestion: targetLesson.reviewPrompts.isNotEmpty ? targetLesson.reviewPrompts.first : '',
            );
            await _saveAction(followup);
          },
        ),
      ),
    );
    await _load();
  }

  Future<void> _openActionWorkbench(YangmingAction action) async {
    final lesson = _lessonById(action.lessonId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YangmingActionWorkbenchPage(
          action: action,
          lesson: lesson,
          lessonContent: _lessonContents[lesson.id],
          ai: _ai,
          profile: _personaProfile,
          onSaveAction: (YangmingAction updated) async {
            await _dao.saveAction(updated.copyWith(updatedAt: DateTime.now().toIso8601String()));
            await _load();
          },
          onCreateFollowupAction: (String instruction) async {
            final followup = _dao.createAction(
              lessonId: lesson.id,
              lessonTitle: lesson.title,
              taskTitle: '${lesson.title} · 诊断后下一步',
              instruction: _buildActionInstruction(lesson: lesson, content: _lessonContents[lesson.id], instruction: instruction),
              source: 'ai_diagnosis_followup',
              reviewQuestion: lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '',
            );
            await _saveAction(followup);
          },
          onOpenLesson: () async => _openLesson(lesson),
          onOpenReview: (fact) async => _openReviewComposer(action: action.copyWith(fact: fact)),
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _OverviewPage(
        aiState: _aiState,
        lessonCount: yangmingLessons.length,
        completedCount: _doneLessons.length,
        importedContentCount: _lessonContents.length,
        totalActions: _actions.length,
        doneActions: _actions.where((e) => e.status == 'done').length,
        reviewCount: _reviews.length,
        latestAction: _actions.isEmpty ? null : _actions.first,
        trainingPlanCount: _trainingPlans.length,
        profile: _personaProfile,
        onOpenDiagnosis: _openDiagnosis,
        onOpenSettings: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
        onOpenPersona: _openPersonaProfile,
        onOpenLesson: () => _openLesson(yangmingLessons[DateTime.now().day % yangmingLessons.length]),
        growthNavigator: _growthNavigator,
        growthNavigatorLoading: _growthNavigatorLoading,
        dailyCockpit: _dailyCockpit,
        dailyCockpitLoading: _dailyCockpitLoading,
        onRefreshGrowthNavigator: () { _runGrowthNavigatorAi(); },
        onRefreshDailyCockpit: () { _runDailyCockpitAi(); },
        onOpenRecommendedLesson: () { _openRecommendedLesson(); },
        onOpenRecommendedMission: () { _openRecommendedMission(); },
        onOpenDailyCockpitLesson: () { _openDailyCockpitLesson(); },
        onOpenDailyCockpitMission: () { _openDailyCockpitMission(); },
        onOpenDailyCockpitPlan: () { _openDailyCockpitPlan(); },
      ),
      _CoursePage(doneLessons: _doneLessons, importedLessonIds: _lessonContents.keys.toSet(), lessonContents: _lessonContents, onOpenLesson: _openLesson, onOpenImportCenter: _openImportCenter),
      _WorldPage(onOpenMission: _openMission, configuredMissionCount: _missionConfigs.length),
      _ActionCenterPage(
        actions: _actions,
        trainingPlans: _trainingPlans,
        onToggleDone: _toggleActionDone,
        onOpenReview: (a) => _openReviewComposer(action: a),
        onOpenLessonByAction: (a) => _openLesson(_lessonById(a.lessonId)),
        onOpenActionWorkbench: _openActionWorkbench,
        onToggleTrainingPlanDone: _toggleTrainingPlanDone,
        onOpenLessonByPlan: (p) => _openLesson(_lessonById(p.lessonId)),
        onOpenTrainingPlanWorkbench: _openTrainingPlanWorkbench,
      ),
      _ReviewHubPage(reviews: _reviews, onOpenReviewComposer: () => _openReviewComposer(lesson: yangmingLessons.first)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('知行书院'),
        actions: <Widget>[
          IconButton(
            tooltip: '诊断',
            icon: const Icon(Icons.search_outlined),
            onPressed: _openDiagnosis,
          ),
          IconButton(
            tooltip: '导入课程内容',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: _openImportCenter,
          ),
          IconButton(
            tooltip: '人格画像',
            icon: const Icon(Icons.person_outline),
            onPressed: _openPersonaProfile,
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Column(children: [if (_loadWarning.isNotEmpty) Container(width: double.infinity, color: Colors.amber.shade50, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text(_loadWarning, style: TextStyle(color: Colors.orange.shade900, fontSize: 12))), Expanded(child: pages[_idx])]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (v) => setState(() => _idx = v),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '总览'),
          NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: '课程库'),
          NavigationDestination(icon: Icon(Icons.videogame_asset_outlined), selectedIcon: Icon(Icons.videogame_asset), label: '虚拟世界'),
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt), label: '行动'),
          NavigationDestination(icon: Icon(Icons.history_edu_outlined), selectedIcon: Icon(Icons.history_edu), label: '复盘'),
        ],
      ),
    );
  }
}

class _OverviewPage extends StatelessWidget {
  final Map<String, String> aiState;
  final int lessonCount;
  final int completedCount;
  final int importedContentCount;
  final int totalActions;
  final int doneActions;
  final int reviewCount;
  final YangmingAction? latestAction;
  final int trainingPlanCount;
  final YangmingPersonaProfile profile;
  final YangmingGrowthNavigatorResult? growthNavigator;
  final bool growthNavigatorLoading;
  final YangmingDailyCockpitResult? dailyCockpit;
  final bool dailyCockpitLoading;
  final VoidCallback onOpenDiagnosis;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenPersona;
  final VoidCallback onOpenLesson;
  final VoidCallback onRefreshGrowthNavigator;
  final VoidCallback onRefreshDailyCockpit;
  final VoidCallback onOpenRecommendedLesson;
  final VoidCallback onOpenRecommendedMission;
  final VoidCallback onOpenDailyCockpitLesson;
  final VoidCallback onOpenDailyCockpitMission;
  final VoidCallback onOpenDailyCockpitPlan;

  const _OverviewPage({
    required this.aiState,
    required this.lessonCount,
    required this.completedCount,
    required this.importedContentCount,
    required this.totalActions,
    required this.doneActions,
    required this.reviewCount,
    required this.latestAction,
    required this.trainingPlanCount,
    required this.profile,
    required this.growthNavigator,
    required this.growthNavigatorLoading,
    required this.dailyCockpit,
    required this.dailyCockpitLoading,
    required this.onOpenDiagnosis,
    required this.onOpenSettings,
    required this.onOpenPersona,
    required this.onOpenLesson,
    required this.onRefreshGrowthNavigator,
    required this.onRefreshDailyCockpit,
    required this.onOpenRecommendedLesson,
    required this.onOpenRecommendedMission,
    required this.onOpenDailyCockpitLesson,
    required this.onOpenDailyCockpitMission,
    required this.onOpenDailyCockpitPlan,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: <Widget>[
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
                    child: const Text('首页左侧菜单 > 知行书院', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(999)),
                    child: Text(aiState['label'] ?? 'AI', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('王阳明《传习录》训练模块', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                '按照原 PRD 继续推进：27 段课程库、问题诊断、虚拟世界操练、现实行动、反思复盘，统一复用主应用现有全局 AI 配置（DeepSeek / OpenAI / OpenRouter / Eden AI / xGrok / Gemini）。\n\n${aiState['note'] ?? ''}',
                style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  FilledButton.icon(onPressed: onOpenDiagnosis, icon: const Icon(Icons.psychology_alt_outlined), label: const Text('问题诊断')),
                  OutlinedButton.icon(onPressed: onOpenLesson, icon: const Icon(Icons.menu_book_outlined), label: const Text('打开今日课程')),
                  OutlinedButton.icon(onPressed: onOpenSettings, icon: const Icon(Icons.settings_outlined), label: const Text('模型与设置')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: <Widget>[
            _MetricCard(title: '课程完成', value: '$completedCount / $lessonCount', hint: '27 段课程进度', icon: Icons.menu_book_outlined),
            _MetricCard(title: '已导入内容', value: '$importedContentCount', hint: '原文 / 详细解释', icon: Icons.upload_file_outlined),
            _MetricCard(title: '行动中心', value: '$doneActions / $totalActions', hint: '完成 / 总任务', icon: Icons.task_alt_outlined),
            _MetricCard(title: '复盘条目', value: '$reviewCount', hint: '事实记录与总结', icon: Icons.history_edu_outlined),
          ],
        ),
        const SizedBox(height: 14),
        _GlassCard(
          child: Row(
            children: <Widget>[
              const Expanded(child: Text('周期训练计划', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(999)),
                child: Text('已生成 $trainingPlanCount 份', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(child: Text('人格映射', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  OutlinedButton.icon(
                    onPressed: onOpenPersona,
                    icon: const Icon(Icons.person_outline),
                    label: Text(profile.hasAnyProfile ? '编辑画像' : '建立画像'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                profile.hasAnyProfile
                    ? '当前画像会被带入 AI 讲解、问题诊断、动态关卡分支与复盘。'
                    : '建立你的角色、人格倾向、常见偏差和高压触发后，AI 动态分支会更贴近你的真实问题。',
                style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 10),
              if (profile.hasAnyProfile) ...<Widget>[
                _MiniSection(title: '当前画像', body: profile.summaryLine),
                if (profile.stressTrigger.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  _MiniSection(title: '高压触发', body: profile.stressTrigger),
                ],
                if (profile.supportStyle.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  _MiniSection(title: '支持偏好', body: profile.supportStyle),
                ],
              ] else
                const _MiniSection(title: '当前状态', body: '尚未建立人格画像。建议先填写角色身份、人格倾向、常见偏差和高压触发。'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (dailyCockpit != null)
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(child: Text('每日知行驾驶舱', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: dailyCockpit!.source.startsWith('ai') ? const Color(0xFFECFDF5) : (dailyCockpit!.source.startsWith('auto') ? const Color(0xFFF5F3FF) : const Color(0xFFF3F4F6)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(dailyCockpit!.source.startsWith('ai') ? 'AI 驾驶舱' : (dailyCockpit!.source.startsWith('auto') ? '自动回流' : '本地驾驶舱'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dailyCockpit!.source.startsWith('ai') ? const Color(0xFF047857) : (dailyCockpit!.source.startsWith('auto') ? const Color(0xFF6D28D9) : const Color(0xFF374151)))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(dailyCockpit!.headline, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _MiniSection(title: '今天最该守住的焦点', body: dailyCockpit!.todayFocus),
                const SizedBox(height: 8),
                _MiniSection(title: '今天最小行动', body: dailyCockpit!.todayAction),
                const SizedBox(height: 8),
                _MiniSection(title: '今日训练入口', body: dailyCockpit!.trainingPrompt),
                const SizedBox(height: 8),
                _MiniSection(title: '今晚最该回答的一问', body: dailyCockpit!.reflectionQuestion),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(onPressed: onOpenDailyCockpitLesson, icon: const Icon(Icons.menu_book_outlined), label: const Text('打开今日课程')),
                    OutlinedButton.icon(onPressed: onOpenDailyCockpitMission, icon: const Icon(Icons.videogame_asset_outlined), label: const Text('进入今日关卡')),
                    if (dailyCockpit!.linkedPlanId.trim().isNotEmpty)
                      OutlinedButton.icon(onPressed: onOpenDailyCockpitPlan, icon: const Icon(Icons.event_note_outlined), label: const Text('继续今日训练')),
                    OutlinedButton.icon(
                      onPressed: dailyCockpitLoading ? null : onRefreshDailyCockpit,
                      icon: dailyCockpitLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_outlined),
                      label: Text(dailyCockpitLoading ? '生成中…' : 'AI 刷新今日建议'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        if (growthNavigator != null)
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(child: Text('成长导航', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: growthNavigator!.source.startsWith('ai') ? const Color(0xFFECFDF5) : (growthNavigator!.source.startsWith('auto') ? const Color(0xFFF5F3FF) : const Color(0xFFF3F4F6)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(growthNavigator!.source.startsWith('ai') ? 'AI 推荐' : (growthNavigator!.source.startsWith('auto') ? '自动回流' : '本地推荐'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: growthNavigator!.source.startsWith('ai') ? const Color(0xFF047857) : (growthNavigator!.source.startsWith('auto') ? const Color(0xFF6D28D9) : const Color(0xFF374151)))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(growthNavigator!.recommendationSummary, style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563))),
                const SizedBox(height: 12),
                _MiniSection(title: '推荐课程', body: '${growthNavigator!.recommendedLessonTitle} · 推荐训练 ${growthNavigator!.recommendedDurationDays} 天'),
                const SizedBox(height: 8),
                _MiniSection(title: '推荐关卡', body: growthNavigator!.recommendedMissionTitle),
                const SizedBox(height: 8),
                _MiniSection(title: '为什么是这段课程', body: growthNavigator!.whyThisLesson),
                const SizedBox(height: 8),
                _MiniSection(title: '为什么先走这个入口', body: growthNavigator!.whyThisMission),
                const SizedBox(height: 8),
                _MiniSection(title: '为什么是这个周期', body: growthNavigator!.whyThisDuration),
                const SizedBox(height: 8),
                _MiniSection(title: '下一步动作', body: growthNavigator!.nextAction),
                const SizedBox(height: 8),
                _MiniSection(title: '带着进入下一轮的问题', body: growthNavigator!.reviewQuestion),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(onPressed: onOpenRecommendedLesson, icon: const Icon(Icons.menu_book_outlined), label: const Text('打开推荐课程')),
                    OutlinedButton.icon(onPressed: onOpenRecommendedMission, icon: const Icon(Icons.videogame_asset_outlined), label: const Text('进入推荐关卡')),
                    OutlinedButton.icon(
                      onPressed: growthNavigatorLoading ? null : onRefreshGrowthNavigator,
                      icon: growthNavigatorLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_outlined),
                      label: Text(growthNavigatorLoading ? '生成中…' : 'AI 刷新推荐'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('原 PRD 对应结构', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _BulletLine('课程库：15 段知行合一 + 12 段立志，共 27 段。'),
              _BulletLine('问题诊断：从现实困扰匹配到对应课程。'),
              _BulletLine('虚拟世界：一段一关卡，模拟知行断裂与立志摇摆。'),
              _BulletLine('现实行动：每段都可生成最小行动与行为链。'),
              _BulletLine('复盘闭环：事实记录 → 反思 → AI 总结 → 下一轮行动。'),
            ],
          ),
        ),
        if (latestAction != null) ...<Widget>[
          const SizedBox(height: 14),
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('最新行动', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(latestAction!.taskTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(latestAction!.instruction, style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF4B5563))),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CoursePage extends StatelessWidget {
  final Set<String> doneLessons;
  final Set<String> importedLessonIds;
  final Map<String, YangmingLessonContent> lessonContents;
  final Future<void> Function(YangmingLesson lesson) onOpenLesson;
  final Future<void> Function() onOpenImportCenter;

  const _CoursePage({required this.doneLessons, required this.importedLessonIds, required this.lessonContents, required this.onOpenLesson, required this.onOpenImportCenter});

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<YangmingLesson>>{
      '知行合一': zhixingLessons,
      '立志': lizhiLessons,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: <Widget>[
        _GlassCard(
          child: Row(
            children: <Widget>[
              Expanded(child: Text('已内置并加载 ${importedLessonIds.length} / ${zhixingLessons.length + lizhiLessons.length} 段课程内容，可继续逐段编辑或批量覆盖。', style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563)))),
              const SizedBox(width: 12),
              FilledButton.icon(onPressed: onOpenImportCenter, icon: const Icon(Icons.file_upload_outlined), label: const Text('导入内容')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...groups.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(entry.key, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('${entry.value.length} 段课程 · 每段都对应概念、问题、行动与虚拟关卡。', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(height: 12),
                ...entry.value.map((lesson) {
                  final content = lessonContents[lesson.id];
                  return InkWell(
                    onTap: () => onOpenLesson(lesson),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(18)),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(child: Text(lesson.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                                    if (doneLessons.contains(lesson.id))
                                      const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(lesson.source, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                if ((content?.hasAnyContent ?? false)) ...<Widget>[
                                  const SizedBox(height: 6),
                                  Text(_safeSnippet(content!.detailedExplanation.isNotEmpty ? content.detailedExplanation : content.originalText, max: 70), style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF4B5563))),
                                ],
                                const SizedBox(height: 8),
                                Wrap(spacing: 6, runSpacing: 6, children: <Widget>[...lesson.coreConcepts.take(3).map((e) => _Tag(text: e)), if (importedLessonIds.contains(lesson.id)) const _Tag(text: '已导入内容')]),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
      ],
    );
  }
}

class _WorldPage extends StatelessWidget {
  final Future<void> Function(YangmingLesson lesson) onOpenMission;
  final int configuredMissionCount;

  const _WorldPage({required this.onOpenMission, required this.configuredMissionCount});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: <Widget>[
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('虚拟世界操练', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('按原 PRD，虚拟世界不是装饰，而是为理论服务。当前版本已把单次关卡升级为多轮状态机：情境进入 → 结构辨认 → 现实迁移 → 守持补救。并且已开始转为配置驱动，当前已加载状态机配置：$configuredMissionCount / 27。', style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563))),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...yangmingLessons.map((lesson) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _GlassCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.videogame_asset_outlined),
              ),
              title: Text(lesson.missionTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${lesson.missionWorld} · ${lesson.title}\n${lesson.missionSetup}', maxLines: 3, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onOpenMission(lesson),
            ),
          ),
        )),
      ],
    );
  }
}

class _ActionCenterPage extends StatelessWidget {
  final List<YangmingAction> actions;
  final List<YangmingTrainingPlan> trainingPlans;
  final Future<void> Function(YangmingAction action, bool done) onToggleDone;
  final Future<void> Function(YangmingAction action) onOpenReview;
  final Future<void> Function(YangmingAction action) onOpenLessonByAction;
  final Future<void> Function(YangmingAction action) onOpenActionWorkbench;
  final Future<void> Function(YangmingTrainingPlan plan, bool done) onToggleTrainingPlanDone;
  final Future<void> Function(YangmingTrainingPlan plan) onOpenLessonByPlan;
  final Future<void> Function(YangmingTrainingPlan plan) onOpenTrainingPlanWorkbench;

  const _ActionCenterPage({
    required this.actions,
    required this.trainingPlans,
    required this.onToggleDone,
    required this.onOpenReview,
    required this.onOpenLessonByAction,
    required this.onOpenActionWorkbench,
    required this.onToggleTrainingPlanDone,
    required this.onOpenLessonByPlan,
    required this.onOpenTrainingPlanWorkbench,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty && trainingPlans.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('还没有行动任务或周期训练计划。\n你可以先从课程详情页或虚拟世界关卡中生成行动与守持计划。', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Color(0xFF6B7280), height: 1.7)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: <Widget>[
        if (trainingPlans.isNotEmpty) ...<Widget>[
          const _GlassCard(child: Text('周期训练计划', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
          ...trainingPlans.map((plan) {
            final done = plan.status == 'done';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: Text(plan.planTheme, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: done ? const Color(0xFFD1FAE5) : const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(999)),
                          child: Text(done ? '已完成' : '${plan.durationDays}天计划', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: done ? const Color(0xFF047857) : const Color(0xFF6D28D9))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${plan.lessonTitle} · ${plan.source}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    const SizedBox(height: 10),
                    Text(plan.planSummary, style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF374151))),
                    const SizedBox(height: 10),
                    _ListBlock(title: '每日训练', items: plan.dailyTasks),
                    if (plan.guardrails.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      _ListBlock(title: '守则', items: plan.guardrails),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: () => onToggleTrainingPlanDone(plan, !done),
                          icon: Icon(done ? Icons.refresh : Icons.check_circle_outline),
                          label: Text(done ? '改回进行中' : '标记计划完成'),
                        ),
                        FilledButton.icon(
                          onPressed: () => onOpenTrainingPlanWorkbench(plan),
                          icon: const Icon(Icons.event_note_outlined),
                          label: const Text('每日打点 / 纠偏'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => onOpenLessonByPlan(plan),
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('回到课程'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          const _GlassCard(child: Text('行动任务', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
        ],
        ...actions.map((action) {
          final done = action.status == 'done';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: Text(action.taskTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: done ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(999)),
                        child: Text(done ? '已完成' : '进行中', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: done ? const Color(0xFF047857) : const Color(0xFF92400E))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${action.lessonTitle} · ${action.source}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(height: 10),
                  Text(action.instruction, style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF374151))),
                  if (action.fact.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    _MiniSection(title: '事实记录', body: action.fact),
                  ],
                  if (action.diagnosisSummary.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    _MiniSection(title: 'AI 诊断', body: action.diagnosisSummary),
                  ],
                  if (action.nextStepSuggestion.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    _MiniSection(title: '下一步建议', body: action.nextStepSuggestion),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        onPressed: () => onToggleDone(action, !done),
                        icon: Icon(done ? Icons.refresh : Icons.check_circle_outline),
                        label: Text(done ? '改回进行中' : '标记完成'),
                      ),
                      FilledButton.icon(
                        onPressed: () => onOpenActionWorkbench(action),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text(action.fact.trim().isEmpty ? '记录事实 / AI诊断' : '继续诊断'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => onOpenReview(action),
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('写复盘'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => onOpenLessonByAction(action),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('回到课程'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ReviewHubPage extends StatelessWidget {
  final List<YangmingReviewEntry> reviews;
  final VoidCallback onOpenReviewComposer;

  const _ReviewHubPage({required this.reviews, required this.onOpenReviewComposer});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: <Widget>[
        _GlassCard(
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('反思复盘中心', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 8),
                    Text('按照原 PRD，把事实记录、反思、AI 总结和下一轮行动连成闭环。', style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563))),
                  ],
                ),
              ),
              FilledButton(onPressed: onOpenReviewComposer, child: const Text('新建复盘')),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (reviews.isEmpty)
          const _GlassCard(child: Padding(padding: EdgeInsets.all(8), child: Text('还没有复盘条目。完成一次行动后，记录事实和反思，会更容易形成知行闭环。', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.6))))
        else
          ...reviews.map((review) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(review.lessonTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(_fmt(review.createdAt), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(height: 10),
                  _MiniSection(title: '事实', body: review.fact),
                  const SizedBox(height: 8),
                  _MiniSection(title: '反思', body: review.reflection),
                  const SizedBox(height: 8),
                  _MiniSection(title: 'AI 总结', body: review.aiSummary),
                ],
              ),
            ),
          )),
      ],
    );
  }
}

class YangmingPersonaProfilePage extends StatefulWidget {
  final YangmingDao dao;
  final YangmingPersonaProfile initialProfile;

  const YangmingPersonaProfilePage({super.key, required this.dao, required this.initialProfile});

  @override
  State<YangmingPersonaProfilePage> createState() => _YangmingPersonaProfilePageState();
}

class _YangmingPersonaProfilePageState extends State<YangmingPersonaProfilePage> {
  late final TextEditingController _roleCtrl = TextEditingController(text: widget.initialProfile.roleIdentity);
  late final TextEditingController _tendencyCtrl = TextEditingController(text: widget.initialProfile.personalityTendency);
  late final TextEditingController _biasCtrl = TextEditingController(text: widget.initialProfile.commonBias);
  late final TextEditingController _triggerCtrl = TextEditingController(text: widget.initialProfile.stressTrigger);
  late final TextEditingController _supportCtrl = TextEditingController(text: widget.initialProfile.supportStyle);
  bool _saving = false;

  @override
  void dispose() {
    _roleCtrl.dispose();
    _tendencyCtrl.dispose();
    _biasCtrl.dispose();
    _triggerCtrl.dispose();
    _supportCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final profile = YangmingPersonaProfile(
      roleIdentity: _roleCtrl.text.trim(),
      personalityTendency: _tendencyCtrl.text.trim(),
      commonBias: _biasCtrl.text.trim(),
      stressTrigger: _triggerCtrl.text.trim(),
      supportStyle: _supportCtrl.text.trim(),
      updatedAt: DateTime.now().toIso8601String(),
    );
    await widget.dao.savePersonaProfile(profile);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('人格画像')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: <Widget>[
          const _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('建立你的训练透镜', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                SizedBox(height: 8),
                Text('按原 PRD，这里的画像会被带入 AI 讲解、问题诊断、动态关卡分支与复盘。它不是给你贴标签，而是帮助系统更贴近你真实的自动路径。', style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(controller: _roleCtrl, decoration: InputDecoration(labelText: '角色身份', hintText: '例如：产品经理 / 创业者 / 学生 / 家长', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
                const SizedBox(height: 12),
                TextField(controller: _tendencyCtrl, decoration: InputDecoration(labelText: '人格倾向', hintText: '例如：回避型 / 过度思辨型 / 自责型 / 讨好型 / 完美主义型', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
                const SizedBox(height: 12),
                TextField(controller: _biasCtrl, maxLines: 3, decoration: InputDecoration(labelText: '常见偏差', hintText: '例如：总想一步到位、知道很多但迟迟不做、容易先自责', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
                const SizedBox(height: 12),
                TextField(controller: _triggerCtrl, maxLines: 3, decoration: InputDecoration(labelText: '高压触发', hintText: '例如：一想到别人不高兴就回避；任务变复杂就拖延', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
                const SizedBox(height: 12),
                TextField(controller: _supportCtrl, maxLines: 3, decoration: InputDecoration(labelText: '支持偏好', hintText: '例如：希望被提醒先拆小；需要更温和或更直接的反馈', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
                const SizedBox(height: 14),
                FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('保存人格画像')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class YangmingLessonDetailPage extends StatefulWidget {
  final YangmingLesson lesson;
  final YangmingLessonContent? lessonContent;
  final YangmingDao dao;
  final YangmingAiService ai;
  final Map<String, String> aiState;
  final YangmingPersonaProfile profile;
  final bool isCompleted;
  final Future<void> Function(String instruction, {String source}) onCreateAction;
  final Future<void> Function() onOpenMission;
  final Future<void> Function() onOpenReview;
  final Future<void> Function() onOpenImportCenter;
  final Future<void> Function() onContentChanged;
  final Future<void> Function(YangmingTrainingPlan plan) onSaveTrainingPlan;

  const YangmingLessonDetailPage({
    super.key,
    required this.lesson,
    required this.lessonContent,
    required this.dao,
    required this.ai,
    required this.aiState,
    required this.profile,
    required this.isCompleted,
    required this.onCreateAction,
    required this.onOpenMission,
    required this.onOpenReview,
    required this.onOpenImportCenter,
    required this.onContentChanged,
    required this.onSaveTrainingPlan,
  });

  @override
  State<YangmingLessonDetailPage> createState() => _YangmingLessonDetailPageState();
}

class _YangmingLessonDetailPageState extends State<YangmingLessonDetailPage> {
  final TextEditingController _concernCtrl = TextEditingController();
  bool _loadingExplain = false;
  bool _loadingPlan = false;
  YangmingLessonContent? _content;
  YangmingExplainResult? _aiExplain;
  YangmingActionPlanResult? _aiPlan;
  final Map<int, YangmingTrainingPlanResult> _aiTrainingPlans = <int, YangmingTrainingPlanResult>{};
  final Set<int> _trainingLoadingDays = <int>{};

  @override
  void initState() {
    super.initState();
    _content = widget.lessonContent;
  }

  Future<void> _openContentEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YangmingLessonContentEditorPage(
          lesson: widget.lesson,
          dao: widget.dao,
          initialContent: _content,
        ),
      ),
    );
    _content = await widget.dao.loadLessonContent(widget.lesson.id);
    await widget.onContentChanged();
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _concernCtrl.dispose();
    super.dispose();
  }

  Future<void> _runExplain() async {
    setState(() => _loadingExplain = true);
    final res = await widget.ai.explainLessonStructured(lesson: widget.lesson, content: _content, profile: widget.profile, concern: _concernCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _aiExplain = res;
      _loadingExplain = false;
    });
  }

  Future<void> _runPlan() async {
    setState(() => _loadingPlan = true);
    final res = await widget.ai.generateActionPlanStructured(lesson: widget.lesson, content: _content, profile: widget.profile, concern: _concernCtrl.text.trim().isEmpty ? '我想把这段课落到现实，但还没确定困扰。' : _concernCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _aiPlan = res;
      _loadingPlan = false;
    });
  }

  Future<void> _runTrainingPlan(int days, {String anchorAction = ''}) async {
    setState(() => _trainingLoadingDays.add(days));
    final res = await widget.ai.generateTrainingPlanStructured(
      lesson: widget.lesson,
      content: _content,
      profile: widget.profile,
      durationDays: days,
      concern: _concernCtrl.text.trim().isEmpty ? '我希望把这段课变成连续守持训练。' : _concernCtrl.text.trim(),
      anchorAction: anchorAction,
    );
    if (!mounted) return;
    setState(() {
      _aiTrainingPlans[days] = res;
      _trainingLoadingDays.remove(days);
    });
  }

  Future<void> _saveTrainingPlanResult(YangmingTrainingPlanResult result) async {
    final plan = widget.dao.createTrainingPlan(
      lessonId: widget.lesson.id,
      lessonTitle: widget.lesson.title,
      durationDays: result.durationDays,
      planTheme: result.planTheme,
      planSummary: result.planSummary,
      dailyTasks: result.dailyTasks,
      guardrails: result.guardrails,
      checkpoints: result.checkpoints,
      reviewPrompts: result.reviewPrompts,
      source: 'ai_training_plan',
    );
    await widget.onSaveTrainingPlan(plan);
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: <Widget>[
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: Text(lesson.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
                    if (widget.isCompleted)
                      const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${lesson.group} · ${lesson.source}', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: lesson.coreConcepts.map((e) => _Tag(text: e)).toList()),
                const SizedBox(height: 12),
                Text('共享模型：${widget.aiState['label'] ?? '未读取'}', style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
                if ((_content?.hasAnyContent ?? false)) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                      if ((_content?.originalText ?? '').trim().isNotEmpty) Text('原文提要：${_safeSnippet(_content!.originalText, max: 110)}', style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF374151))),
                      if ((_content?.detailedExplanation ?? '').trim().isNotEmpty) ...<Widget>[
                        if ((_content?.originalText ?? '').trim().isNotEmpty) const SizedBox(height: 6),
                        Text('详解提要：${_safeSnippet(_content!.detailedExplanation, max: 140)}', style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF6B7280))),
                      ],
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(onPressed: widget.onOpenMission, icon: const Icon(Icons.videogame_asset_outlined), label: const Text('进入虚拟关卡')),
                    OutlinedButton.icon(onPressed: widget.onOpenReview, icon: const Icon(Icons.history_edu_outlined), label: const Text('写复盘')),
                    OutlinedButton.icon(onPressed: _openContentEditor, icon: const Icon(Icons.edit_note_outlined), label: Text((_content?.hasAnyContent ?? false) ? '编辑内容' : '导入内容')),
                    OutlinedButton.icon(onPressed: () => widget.onCreateAction(lesson.actionPlans.first, source: 'manual'), icon: const Icon(Icons.task_alt_outlined), label: const Text('加入行动')), 
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(title: (_content?.hasAnyContent ?? false) ? '原文与详细解释' : '课程内容导入', children: <Widget>[
            Text((_content?.hasAnyContent ?? false)
                ? '这两块内容已经直接作为本段课程的依据，其它模块（AI讲解、虚拟关卡、行动与复盘）都会优先参考这里。'
                : '这段课程还没有内容。导入原文与详细解释后，AI讲解、虚拟关卡、行动与复盘会自动按内容同步更新。', style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563))),
            const SizedBox(height: 10),
            if ((_content?.hasAnyContent ?? false)) ...<Widget>[
              _LongTextBlock(label: '完整原文', value: _content!.originalText),
              const SizedBox(height: 8),
              _LongTextBlock(label: '详细解释', value: _content!.detailedExplanation),
            ] else ...<Widget>[
              _PlaceholderBox(label: '原文槽位', value: lesson.originalTextSlot),
              const SizedBox(height: 8),
              _PlaceholderBox(label: '详细解释槽位', value: lesson.detailedExplanationSlot),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.tonalIcon(onPressed: _openContentEditor, icon: const Icon(Icons.edit_note_outlined), label: Text((_content?.hasAnyContent ?? false) ? '编辑这段内容' : '现在导入这段内容')),
                OutlinedButton.icon(onPressed: widget.onOpenImportCenter, icon: const Icon(Icons.file_upload_outlined), label: const Text('打开导入中心')),
              ],
            ),
          ]),
          const SizedBox(height: 14),
          _SectionCard(title: '与原文和详解同步的课程资产', children: <Widget>[
            _ListBlock(title: '问题类型', items: lesson.problemTypes),
            const SizedBox(height: 10),
            _ListBlock(title: '现实案例', items: lesson.scenarioCases),
            const SizedBox(height: 10),
            _ListBlock(title: '现实行动', items: lesson.actionPlans),
            const SizedBox(height: 10),
            _ListBlock(title: '复盘问题', items: lesson.reviewPrompts),
          ]),
          const SizedBox(height: 14),
          _SectionCard(title: 'AI 教练区', children: <Widget>[
            if (widget.profile.hasAnyProfile) ...<Widget>[
              _MiniSection(title: '当前人格映射', body: widget.profile.summaryLine),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _concernCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '输入你的现实困扰，例如：我知道该沟通，但总在关键时刻回避。',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(onPressed: _loadingExplain ? null : _runExplain, icon: _loadingExplain ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_outlined), label: const Text('AI 深度讲解')),
                OutlinedButton.icon(onPressed: _loadingPlan ? null : _runPlan, icon: _loadingPlan ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.route_outlined), label: const Text('AI 行动链')),
              ],
            ),
            if (_aiExplain != null) ...<Widget>[
              const SizedBox(height: 12),
              _StructuredExplainCard(result: _aiExplain!),
            ],
            if (_aiPlan != null) ...<Widget>[
              const SizedBox(height: 12),
              _StructuredActionPlanCard(result: _aiPlan!),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: () => widget.onCreateAction(_aiPlan!.todayMinimalAction, source: 'ai_minimal_action'),
                    icon: const Icon(Icons.flash_on_outlined),
                    label: const Text('加入今日最小行动'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => widget.onCreateAction(_aiPlan!.weekChain.join('\n'), source: 'ai_week_chain'),
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('加入本周行动链'),
                  ),
                ],
              ),
            ],
          ]),
          const SizedBox(height: 14),
          _SectionCard(title: '周期训练计划', children: <Widget>[
            const Text('按原 PRD，把单次理解与行动继续拉长成 3 / 7 / 14 天守持计划。每份计划都会结合课程原文、详细解释、当前困扰和人格画像来生成。', style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                for (final days in <int>[3, 7, 14])
                  OutlinedButton.icon(
                    onPressed: _trainingLoadingDays.contains(days) ? null : () => _runTrainingPlan(days, anchorAction: _aiPlan?.todayMinimalAction ?? ''),
                    icon: _trainingLoadingDays.contains(days) ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.event_repeat_outlined),
                    label: Text('生成${days}天计划'),
                  ),
              ],
            ),
            if (_aiTrainingPlans.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              ...(_aiTrainingPlans.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).expand((entry) => <Widget>[
                    _StructuredTrainingPlanCard(result: entry.value),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: () => _saveTrainingPlanResult(entry.value),
                          icon: const Icon(Icons.add_task_outlined),
                          label: const Text('加入周期训练'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => widget.onCreateAction(entry.value.dailyTasks.first, source: 'training_plan_day_1'),
                          icon: const Icon(Icons.flash_on_outlined),
                          label: const Text('加入第1天动作'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ]),
            ],
          ]),
        ],
      ),
    );
  }
}

class YangmingMissionPage extends StatefulWidget {
  final YangmingLesson lesson;
  final YangmingLessonContent? lessonContent;
  final YangmingMissionConfig? missionConfig;
  final YangmingPersonaProfile profile;
  final YangmingAiService ai;
  final Future<void> Function(String instruction) onCreateAction;

  const YangmingMissionPage({super.key, required this.lesson, required this.lessonContent, required this.profile, required this.ai, required this.onCreateAction, this.missionConfig});

  @override
  State<YangmingMissionPage> createState() => _YangmingMissionPageState();
}

class _YangmingMissionPageState extends State<YangmingMissionPage> {
  late final List<YangmingMissionRound> _baseRounds;
  final List<YangmingMissionChoice> _pickedChoices = <YangmingMissionChoice>[];
  final TextEditingController _missionConcernCtrl = TextEditingController();
  int _roundIndex = 0;
  YangmingMissionChoice? _selected;
  bool _adaptiveLoading = false;
  YangmingAdaptiveMissionResult? _adaptiveResult;

  @override
  void initState() {
    super.initState();
    _baseRounds = buildMissionRounds(widget.lesson, config: widget.missionConfig);
  }

  @override
  void dispose() {
    _missionConcernCtrl.dispose();
    super.dispose();
  }

  List<YangmingMissionRound> get _rounds {
    if (_adaptiveResult == null || !_adaptiveResult!.hasDynamicRounds) return _baseRounds;
    final rounds = List<YangmingMissionRound>.from(_baseRounds);
    if (_adaptiveResult!.dynamicInnerRound != null && rounds.length > 1) {
      rounds[1] = _adaptiveResult!.dynamicInnerRound!;
    }
    if (_adaptiveResult!.dynamicActionRound != null && rounds.length > 2) {
      rounds[2] = _adaptiveResult!.dynamicActionRound!;
    }
    return rounds;
  }

  bool get _isFinished => _roundIndex >= _rounds.length;

  int get _willScore => _pickedChoices.fold(0, (sum, item) => sum + item.willDelta);
  int get _awarenessScore => _pickedChoices.fold(0, (sum, item) => sum + item.awarenessDelta);
  int get _integrationScore => _pickedChoices.fold(0, (sum, item) => sum + item.integrationDelta);

  void _pickChoice(YangmingMissionChoice choice) {
    setState(() => _selected = choice);
  }

  void _advanceRound() {
    if (_selected == null) return;
    setState(() {
      _pickedChoices.add(_selected!);
      _selected = null;
      _roundIndex += 1;
    });
  }

  void _goPreviousRound() {
    if (_roundIndex <= 0 || _pickedChoices.isEmpty) return;
    setState(() {
      _roundIndex -= 1;
      _pickedChoices.removeLast();
      _selected = null;
    });
  }

  Future<void> _runAdaptiveBranch() async {
    final concern = _missionConcernCtrl.text.trim();
    if (concern.isEmpty) return;
    setState(() => _adaptiveLoading = true);
    final result = await widget.ai.buildAdaptiveMissionBranch(
      lesson: widget.lesson,
      content: widget.lessonContent,
      profile: widget.profile,
      concern: concern,
      currentRounds: _baseRounds,
    );
    if (!mounted) return;
    setState(() {
      _adaptiveResult = result;
      _adaptiveLoading = false;
      _pickedChoices.clear();
      _selected = null;
      _roundIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final summary = summarizeMissionRun(lesson: lesson, pickedChoices: _pickedChoices, config: widget.missionConfig);
    final displayedRealityTask = (_adaptiveResult?.bridgeAction ?? '').trim().isNotEmpty ? _adaptiveResult!.bridgeAction : summary.realityTask;
    final displayedReviewQuestion = (_adaptiveResult?.reviewQuestion ?? '').trim().isNotEmpty ? _adaptiveResult!.reviewQuestion : summary.reviewQuestion;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.missionTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: <Widget>[
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(lesson.missionTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('${lesson.missionWorld} · ${lesson.title}', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(999)),
                      child: Text(_isFinished ? '已完成' : '第 ${_roundIndex + 1} / ${_rounds.length} 轮', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('按原 PRD，这里不再是一次性选择，而是“情境 → 结构 → 现实迁移 → 守持补救”的多轮状态机训练。', style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF374151))),
                if ((widget.lessonContent?.hasAnyContent ?? false)) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                      if ((widget.lessonContent?.originalText ?? '').trim().isNotEmpty) Text('原文提要：${_safeSnippet(widget.lessonContent!.originalText, max: 90)}', style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF374151))),
                      if ((widget.lessonContent?.detailedExplanation ?? '').trim().isNotEmpty) ...<Widget>[
                        if ((widget.lessonContent?.originalText ?? '').trim().isNotEmpty) const SizedBox(height: 6),
                        Text('详解提醒：${_safeSnippet(widget.lessonContent!.detailedExplanation, max: 120)}', style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF6B7280))),
                      ],
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _ScoreChip(label: '意志', value: _willScore),
                    _ScoreChip(label: '觉察', value: _awarenessScore),
                    _ScoreChip(label: '贯通', value: _integrationScore),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('AI 动态分支', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('把你眼前最真实的现实困扰带入这一关，系统会基于本段原文与详细解释，重写第2轮和第3轮。', style: TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF4B5563))),
                const SizedBox(height: 10),
                if (widget.profile.hasAnyProfile)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                      const Text('当前人格映射', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(widget.profile.summaryLine, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF374151))),
                      if (widget.profile.stressTrigger.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text('高压触发：${widget.profile.stressTrigger}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ]),
                  ),
                TextField(
                  controller: _missionConcernCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '例如：我知道该沟通，但一想到对方会不高兴就开始回避。',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _adaptiveLoading ? null : _runAdaptiveBranch,
                      icon: _adaptiveLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.alt_route_outlined),
                      label: const Text('生成 AI 动态分支'),
                    ),
                    if (_adaptiveResult != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _adaptiveResult = null;
                            _pickedChoices.clear();
                            _selected = null;
                            _roundIndex = 0;
                          });
                        },
                        icon: const Icon(Icons.layers_clear_outlined),
                        label: const Text('回到默认关卡'),
                      ),
                  ],
                ),
                if (_adaptiveResult != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(_adaptiveResult!.branchTag, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                        if (_adaptiveResult!.personaLens.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text('人格透镜：${_adaptiveResult!.personaLens}', style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF374151))),
                        ],
                        if (_adaptiveResult!.trainingFocus.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text('本次训练重点：${_adaptiveResult!.trainingFocus}', style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF374151))),
                        ],
                        if (_adaptiveResult!.concernMirror.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text('困扰镜像：${_adaptiveResult!.concernMirror}', style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF374151))),
                        ],
                        if (_adaptiveResult!.missionReminder.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text('进入提醒：${_adaptiveResult!.missionReminder}', style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF4B5563))),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (!_isFinished) ...<Widget>[
            _MissionProgress(rounds: _rounds, roundIndex: _roundIndex, pickedChoices: _pickedChoices),
            const SizedBox(height: 12),
            _MissionRoundCard(round: _rounds[_roundIndex]),
            const SizedBox(height: 14),
            ..._rounds[_roundIndex].choices.map((choice) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _pickChoice(choice),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _selected?.id == choice.id ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _selected?.id == choice.id ? const Color(0xFF60A5FA) : const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _selected?.id == choice.id ? const Color(0xFFDBEAFE) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(choice.id, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(choice.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text('意志 ${choice.willDelta >= 0 ? '+' : ''}${choice.willDelta} · 觉察 ${choice.awarenessDelta >= 0 ? '+' : ''}${choice.awarenessDelta} · 贯通 ${choice.integrationDelta >= 0 ? '+' : ''}${choice.integrationDelta}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )),
            if (_selected != null) ...<Widget>[
              const SizedBox(height: 8),
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('本轮反馈', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text(_selected!.feedback, style: const TextStyle(fontSize: 14, height: 1.65, color: Color(0xFF374151))),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        if (_roundIndex > 0)
                          OutlinedButton.icon(
                            onPressed: _goPreviousRound,
                            icon: const Icon(Icons.chevron_left_rounded),
                            label: const Text('上一步'),
                          ),
                        if (_roundIndex > 0) const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: _advanceRound,
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: Text(_roundIndex == _rounds.length - 1 ? '完成状态机' : '进入下一轮'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ] else ...<Widget>[
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('状态机总结', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
                        child: Text(summary.routeTag, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Text('意志 ${summary.willScore} · 觉察 ${summary.awarenessScore} · 贯通 ${summary.integrationScore}', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(summary.diagnosis, style: const TextStyle(fontSize: 14, height: 1.65, color: Color(0xFF374151))),
                  if (_adaptiveResult != null && _adaptiveResult!.concernMirror.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text('AI 动态分支说明：${_adaptiveResult!.concernMirror}', style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF4B5563))),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('现实迁移任务', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(displayedRealityTask, style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF374151))),
                        const SizedBox(height: 10),
                        Text('复盘问题：$displayedReviewQuestion', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.6)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: () async {
                          await widget.onCreateAction('现实迁移任务：${summary.realityTask}\n复盘问题：${summary.reviewQuestion}');
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已把状态机迁移任务加入行动中心')));
                        },
                        icon: const Icon(Icons.add_task_outlined),
                        label: const Text('加入行动中心'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _pickedChoices.clear();
                            _selected = null;
                            _roundIndex = 0;
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重新演练'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MissionProgress extends StatelessWidget {
  final List<YangmingMissionRound> rounds;
  final int roundIndex;
  final List<YangmingMissionChoice> pickedChoices;

  const _MissionProgress({required this.rounds, required this.roundIndex, required this.pickedChoices});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('状态机进度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...List<Widget>.generate(rounds.length, (index) {
            final done = index < pickedChoices.length;
            final active = index == roundIndex && roundIndex < rounds.length;
            final color = done
                ? const Color(0xFFDCFCE7)
                : active
                    ? const Color(0xFFDBEAFE)
                    : const Color(0xFFF3F4F6);
            return Padding(
              padding: EdgeInsets.only(bottom: index == rounds.length - 1 ? 0 : 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                      child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(rounds[index].title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                    if (done) const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                    if (active) const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF2563EB), size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MissionRoundCard extends StatelessWidget {
  final YangmingMissionRound round;

  const _MissionRoundCard({required this.round});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(round.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(round.prompt, style: const TextStyle(fontSize: 14, height: 1.65, color: Color(0xFF374151))),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
            child: Text(round.guide, style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF6B7280))),
          ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final int value;

  const _ScoreChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final Color bg = value >= 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    final Color fg = value >= 0 ? const Color(0xFF166534) : const Color(0xFF991B1B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text('$label ${value >= 0 ? '+' : ''}$value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class YangmingActionWorkbenchPage extends StatefulWidget {
  final YangmingAction action;
  final YangmingLesson lesson;
  final YangmingLessonContent? lessonContent;
  final YangmingPersonaProfile profile;
  final YangmingAiService ai;
  final Future<void> Function(YangmingAction updated) onSaveAction;
  final Future<void> Function(String instruction) onCreateFollowupAction;
  final Future<void> Function() onOpenLesson;
  final Future<void> Function(String fact) onOpenReview;

  const YangmingActionWorkbenchPage({
    super.key,
    required this.action,
    required this.lesson,
    required this.lessonContent,
    required this.profile,
    required this.ai,
    required this.onSaveAction,
    required this.onCreateFollowupAction,
    required this.onOpenLesson,
    required this.onOpenReview,
  });

  @override
  State<YangmingActionWorkbenchPage> createState() => _YangmingActionWorkbenchPageState();
}

class _YangmingActionWorkbenchPageState extends State<YangmingActionWorkbenchPage> {
  late final TextEditingController _factCtrl = TextEditingController(text: widget.action.fact);
  bool _loading = false;
  YangmingActionDiagnosisResult? _diagnosis;

  @override
  void dispose() {
    _factCtrl.dispose();
    super.dispose();
  }

  Future<void> _runDiagnosis() async {
    if (_factCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final result = await widget.ai.diagnoseActionExecutionStructured(
      lesson: widget.lesson,
      content: widget.lessonContent,
      profile: widget.profile,
      action: widget.action,
      fact: _factCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _diagnosis = result;
      _loading = false;
    });
  }

  Future<void> _saveFactAndDiagnosis() async {
    final diagnosis = _diagnosis;
    final updated = widget.action.copyWith(
      fact: _factCtrl.text.trim(),
      diagnosisSummary: diagnosis == null ? widget.action.diagnosisSummary : '问题结构：${diagnosis.mainProblemStructure}\n可能偏差：${diagnosis.likelyBias}\n事实建议：${diagnosis.factAdvice}',
      nextStepSuggestion: diagnosis == null ? widget.action.nextStepSuggestion : diagnosis.nextMicroAction,
      reviewQuestion: diagnosis == null ? widget.action.reviewQuestion : diagnosis.reviewQuestion,
      lessonRecommendationId: diagnosis == null ? widget.action.lessonRecommendationId : diagnosis.recommendedLessonId,
      lessonRecommendationTitle: diagnosis == null ? widget.action.lessonRecommendationTitle : diagnosis.recommendedLessonTitle,
      lastAiDiagnosisAt: diagnosis == null ? widget.action.lastAiDiagnosisAt : DateTime.now().toIso8601String(),
      status: widget.action.status == 'todo' ? 'doing' : widget.action.status,
    );
    await widget.onSaveAction(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存事实记录与AI诊断')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('事实记录 / AI诊断')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: <Widget>[
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(widget.action.taskTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('${widget.lesson.title} · ${widget.action.source}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                const SizedBox(height: 10),
                Text(widget.action.instruction, style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF374151))),
                if ((widget.lessonContent?.hasAnyContent ?? false)) ...<Widget>[
                  const SizedBox(height: 10),
                  Text('本次诊断会结合该段原文与详细解释。', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _factCtrl,
                  maxLines: 7,
                  decoration: InputDecoration(
                    labelText: '事实记录',
                    hintText: '请尽量写事实：什么时候、发生了什么、你做了什么、结果怎样。先不要急着评价自己。',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _loading ? null : _runDiagnosis,
                      icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.psychology_alt_outlined),
                      label: const Text('AI诊断执行过程'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saveFactAndDiagnosis,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('保存事实与诊断'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onOpenLesson,
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('回到课程'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_diagnosis != null) ...<Widget>[
            const SizedBox(height: 14),
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _StructuredActionDiagnosisCard(result: _diagnosis!),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: () async {
                          await widget.onCreateFollowupAction(_diagnosis!.nextMicroAction);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已把诊断后的下一步加入行动中心')));
                        },
                        icon: const Icon(Icons.add_task_outlined),
                        label: const Text('加入下一步行动'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => widget.onOpenReview(_factCtrl.text.trim()),
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('带着诊断去复盘'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (widget.action.diagnosisSummary.trim().isNotEmpty && _diagnosis == null) ...<Widget>[
            const SizedBox(height: 14),
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('上次诊断摘要', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  _MiniSection(title: '诊断摘要', body: widget.action.diagnosisSummary),
                  if (widget.action.nextStepSuggestion.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    _MiniSection(title: '下一步建议', body: widget.action.nextStepSuggestion),
                  ],
                  if (widget.action.reviewQuestion.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    _MiniSection(title: '复盘问题', body: widget.action.reviewQuestion),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class YangmingDiagnosisPage extends StatefulWidget {
  final YangmingAiService ai;
  final List<YangmingLesson> lessons;
  final Map<String, YangmingLessonContent> lessonContents;
  final YangmingPersonaProfile profile;
  final Future<void> Function(YangmingLesson lesson) onOpenLesson;

  const YangmingDiagnosisPage({super.key, required this.ai, required this.lessons, required this.lessonContents, required this.profile, required this.onOpenLesson});

  @override
  State<YangmingDiagnosisPage> createState() => _YangmingDiagnosisPageState();
}

class _YangmingDiagnosisPageState extends State<YangmingDiagnosisPage> {
  final TextEditingController _ctrl = TextEditingController();
  bool _loading = false;
  YangmingDiagnosisResult? _result;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final result = await widget.ai.diagnoseStructured(concern: _ctrl.text.trim(), lessons: widget.lessons, lessonContents: widget.lessonContents, profile: widget.profile);
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('问题诊断')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: <Widget>[
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('把现实问题映射到课程', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('输入你现在最困扰的一件事，系统会按照原 PRD 中的问题诊断逻辑，把它映射到最相关的课程段落。', style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563))),
                if (widget.profile.hasAnyProfile) ...<Widget>[
                  const SizedBox(height: 10),
                  _MiniSection(title: '当前人格映射', body: widget.profile.summaryLine),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _ctrl,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: '例如：我明明知道该沟通，但一到关键时刻就想拖，拖完又自责。',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _loading ? null : _run,
                  icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.psychology_alt_outlined),
                  label: const Text('开始诊断'),
                ),
              ],
            ),
          ),
          if (_result != null) ...<Widget>[
            const SizedBox(height: 14),
            _GlassCard(child: _StructuredDiagnosisCard(result: _result!, onOpenLesson: (id) async {
              final lesson = widget.lessons.firstWhere((e) => e.id == id, orElse: () => widget.lessons.first);
              await widget.onOpenLesson(lesson);
            })),
          ],
          const SizedBox(height: 14),
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('可直接进入的高频课程', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ...widget.lessons.take(6).map((lesson) {
                  final content = widget.lessonContents[lesson.id];
                  final subtitle = (content?.hasAnyContent ?? false)
                      ? _safeSnippet(content!.detailedExplanation.isNotEmpty ? content.detailedExplanation : content.originalText, max: 54)
                      : lesson.problemTypes.join(' · ');
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(lesson.title),
                    subtitle: Text(subtitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => widget.onOpenLesson(lesson),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class YangmingReviewComposerPage extends StatefulWidget {
  final YangmingLesson lesson;
  final YangmingLessonContent? lessonContent;
  final YangmingPersonaProfile profile;
  final YangmingAiService ai;
  final String initialFact;
  final Future<void> Function(String fact, String reflection, String aiSummary) onSave;
  final Future<void> Function(String instruction) onCreateFollowupAction;

  const YangmingReviewComposerPage({
    super.key,
    required this.lesson,
    required this.lessonContent,
    required this.profile,
    required this.ai,
    required this.initialFact,
    required this.onSave,
    required this.onCreateFollowupAction,
  });

  @override
  State<YangmingReviewComposerPage> createState() => _YangmingReviewComposerPageState();
}

class _YangmingReviewComposerPageState extends State<YangmingReviewComposerPage> {
  late final TextEditingController _factCtrl = TextEditingController(text: widget.initialFact);
  final TextEditingController _reflectionCtrl = TextEditingController();
  bool _loading = false;
  YangmingReviewResult? _aiSummary;

  @override
  void dispose() {
    _factCtrl.dispose();
    _reflectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_factCtrl.text.trim().isEmpty || _reflectionCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final res = await widget.ai.generateReviewStructured(lesson: widget.lesson, content: widget.lessonContent, profile: widget.profile, fact: _factCtrl.text.trim(), reflection: _reflectionCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _aiSummary = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('写复盘')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: <Widget>[
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(widget.lesson.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('请先写事实，再写反思，最后让 AI 帮你做结构化总结。', style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.6)),
                if (widget.profile.hasAnyProfile) ...<Widget>[
                  const SizedBox(height: 10),
                  _MiniSection(title: '当前人格映射', body: widget.profile.summaryLine),
                ],
                if ((widget.lessonContent?.hasAnyContent ?? false)) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
                    child: Text('复盘会优先参考本段原文与详解：${_safeSnippet((widget.lessonContent?.detailedExplanation ?? widget.lessonContent?.originalText ?? ''), max: 120)}', style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF6B7280))),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _factCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(labelText: '事实记录', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reflectionCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(labelText: '我的反思', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _loading ? null : _run,
                      icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_outlined),
                      label: const Text('AI 总结'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _aiSummary == null
                          ? null
                          : () async {
                              await widget.onSave(_factCtrl.text.trim(), _reflectionCtrl.text.trim(), _formatReviewSummary(_aiSummary!));
                              if (!mounted) return;
                              Navigator.of(context).pop();
                            },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('保存复盘'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _aiSummary == null
                          ? null
                          : () async {
                              await widget.onCreateFollowupAction(_aiSummary!.nextAction);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已把明天最小行动加入行动中心')));
                            },
                      icon: const Icon(Icons.add_task_outlined),
                      label: const Text('加入明天行动'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_aiSummary != null) ...<Widget>[
            const SizedBox(height: 14),
            _GlassCard(child: _StructuredReviewCard(result: _aiSummary!)),
          ],
        ],
      ),
    );
  }
}


class _StructuredExplainCard extends StatelessWidget {
  final YangmingExplainResult result;
  const _StructuredExplainCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('AI 深度讲解', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _MiniSection(title: '核心问题', body: result.coreProblem),
        const SizedBox(height: 10),
        _ListBlock(title: '关键理解点', items: result.keyPoints),
        const SizedBox(height: 10),
        _ListBlock(title: '常见误区', items: result.misunderstandings),
        const SizedBox(height: 10),
        _MiniSection(title: '案例分析', body: result.caseAnalysis),
        const SizedBox(height: 10),
        _MiniSection(title: '今日最小行动', body: result.minimalAction),
      ],
    );
  }
}

class _StructuredActionPlanCard extends StatelessWidget {
  final YangmingActionPlanResult result;
  const _StructuredActionPlanCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('AI 行动链', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _MiniSection(title: '问题判断', body: result.problemJudgment),
        const SizedBox(height: 10),
        _MiniSection(title: '今日最小行动', body: result.todayMinimalAction),
        const SizedBox(height: 10),
        _ListBlock(title: '本周行动链', items: result.weekChain),
        const SizedBox(height: 10),
        _MiniSection(title: '失败后补救', body: result.recoveryAction),
        const SizedBox(height: 10),
        _MiniSection(title: '晚间复盘问题', body: result.reviewQuestion),
      ],
    );
  }
}

class _StructuredTrainingPlanCard extends StatelessWidget {
  final YangmingTrainingPlanResult result;
  const _StructuredTrainingPlanCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('${result.durationDays}天守持计划', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _MiniSection(title: '计划主题', body: result.planTheme),
        const SizedBox(height: 10),
        _MiniSection(title: '计划摘要', body: result.planSummary),
        const SizedBox(height: 10),
        _ListBlock(title: '每日训练', items: result.dailyTasks),
        if (result.guardrails.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _ListBlock(title: '守则', items: result.guardrails),
        ],
        if (result.checkpoints.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _ListBlock(title: '阶段检查点', items: result.checkpoints),
        ],
        if (result.reviewPrompts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _ListBlock(title: '复盘问题', items: result.reviewPrompts),
        ],
      ],
    );
  }
}

class _StructuredActionDiagnosisCard extends StatelessWidget {
  final YangmingActionDiagnosisResult result;
  const _StructuredActionDiagnosisCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('AI 执行诊断', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _MiniSection(title: '主要问题结构', body: result.mainProblemStructure),
        const SizedBox(height: 10),
        _MiniSection(title: '最可能偏差', body: result.likelyBias),
        const SizedBox(height: 10),
        _MiniSection(title: '事实记录建议', body: result.factAdvice),
        const SizedBox(height: 10),
        _MiniSection(title: '接下来24小时最小动作', body: result.nextMicroAction),
        const SizedBox(height: 10),
        _MiniSection(title: '复盘问题', body: result.reviewQuestion),
        if (result.recommendedLessonId.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _MiniSection(title: '建议回看课程', body: '${result.recommendedLessonId} · ${result.recommendedLessonTitle}'),
        ],
      ],
    );
  }
}

class _StructuredDiagnosisCard extends StatelessWidget {
  final YangmingDiagnosisResult result;
  final Future<void> Function(String lessonId) onOpenLesson;
  const _StructuredDiagnosisCard({required this.result, required this.onOpenLesson});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('诊断结果', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _MiniSection(title: '主要问题结构', body: result.mainProblemStructure),
        const SizedBox(height: 10),
        const Text('最相关课程 TOP3', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...result.topMatches.map((m) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Row(children: <Widget>[
              Expanded(child: Text('${m.lessonId} · ${m.title}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              TextButton(onPressed: () => onOpenLesson(m.lessonId), child: const Text('打开课程')),
            ]),
            Text(m.reason, style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF4B5563))),
          ]),
        )),
        if (result.recommendedStartLessonId.trim().isNotEmpty)
          _MiniSection(title: '建议起点', body: '${result.recommendedStartLessonId} · ${result.recommendedStartLessonTitle}'),
      ],
    );
  }
}

class _StructuredReviewCard extends StatelessWidget {
  final YangmingReviewResult result;
  const _StructuredReviewCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('AI 复盘', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _MiniSection(title: '主要问题', body: result.mainProblem),
        const SizedBox(height: 10),
        _MiniSection(title: '值得肯定', body: result.affirmation),
        const SizedBox(height: 10),
        _MiniSection(title: '需要修正', body: result.correction),
        const SizedBox(height: 10),
        _MiniSection(title: '明天最小行动', body: result.nextAction),
        const SizedBox(height: 10),
        _MiniSection(title: '一句提醒', body: result.reminder),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String hint;
  final IconData icon;
  const _MetricCard({required this.title, required this.value, required this.hint, required this.icon});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[Icon(icon), const Spacer()]),
          const Spacer(),
          Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(hint, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;
  const _BulletLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: CircleAvatar(radius: 3, backgroundColor: Color(0xFF111827)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF374151)))),
        ],
      ),
    );
  }
}


class YangmingTrainingPlanWorkbenchPage extends StatefulWidget {
  final YangmingTrainingPlan plan;
  final YangmingLesson lesson;
  final YangmingLessonContent? lessonContent;
  final Map<String, YangmingLessonContent> lessonContents;
  final YangmingPersonaProfile profile;
  final YangmingAiService ai;
  final YangmingDao dao;
  final Future<void> Function(YangmingGrowthNavigatorResult result) onPublishNavigator;
  final Future<void> Function(YangmingNextCycleRecommendationResult result) onPublishNextCycle;

  const YangmingTrainingPlanWorkbenchPage({
    super.key,
    required this.plan,
    required this.lesson,
    required this.lessonContent,
    required this.lessonContents,
    required this.profile,
    required this.ai,
    required this.dao,
    required this.onPublishNavigator,
    required this.onPublishNextCycle,
  });

  @override
  State<YangmingTrainingPlanWorkbenchPage> createState() => _YangmingTrainingPlanWorkbenchPageState();
}

class _YangmingTrainingPlanWorkbenchPageState extends State<YangmingTrainingPlanWorkbenchPage> {
  YangmingTrainingTrace? _trace;
  bool _loading = true;
  bool _runningCorrection = false;
  bool _runningSummary = false;
  bool _runningNextCycle = false;
  YangmingTrainingCorrectionResult? _correction;
  YangmingTrainingWeeklySummaryResult? _weeklySummary;
  YangmingNextCycleRecommendationResult? _nextCycle;
  late final List<TextEditingController> _factCtrls;
  late final List<TextEditingController> _reflectionCtrls;

  @override
  void initState() {
    super.initState();
    _factCtrls = List<TextEditingController>.generate(widget.plan.dailyTasks.length, (_) => TextEditingController());
    _reflectionCtrls = List<TextEditingController>.generate(widget.plan.dailyTasks.length, (_) => TextEditingController());
    _load();
  }

  @override
  void dispose() {
    for (final c in _factCtrls) { c.dispose(); }
    for (final c in _reflectionCtrls) { c.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    final trace = await widget.dao.loadTrainingTrace(widget.plan);
    if (!mounted) return;
    for (int i = 0; i < trace.days.length && i < _factCtrls.length; i++) {
      _factCtrls[i].text = trace.days[i].fact;
      _reflectionCtrls[i].text = trace.days[i].reflection;
    }
    setState(() {
      _trace = trace;
      _loading = false;
    });
  }

  YangmingGrowthNavigatorResult _buildNavigatorFromNextCycle(YangmingNextCycleRecommendationResult rec) {
    final lesson = yangmingLessons.firstWhere((e) => e.id == rec.recommendedLessonId, orElse: () => widget.lesson);
    return YangmingGrowthNavigatorResult(
      recommendedLessonId: lesson.id,
      recommendedLessonTitle: rec.recommendedLessonTitle.trim().isEmpty ? lesson.title : rec.recommendedLessonTitle,
      recommendedMissionTitle: lesson.missionTitle,
      recommendedDurationDays: rec.recommendedDurationDays <= 0 ? 3 : rec.recommendedDurationDays,
      recommendationSummary: rec.recommendationSummary.trim().isEmpty ? '已根据当前训练轨迹自动给出下一周期入口。' : rec.recommendationSummary,
      whyThisLesson: rec.whyThisLesson.trim().isEmpty ? '这段课程更适合作为下一轮继续推进的入口。' : rec.whyThisLesson,
      whyThisMission: '先进入对应关卡，把下一轮训练重点重新带回情境中操练。',
      whyThisDuration: rec.whyThisDuration.trim().isEmpty ? '这是根据当前守持状态自动建议的训练长度。' : rec.whyThisDuration,
      nextAction: rec.starterActions.isNotEmpty ? rec.starterActions.first : (lesson.actionPlans.isNotEmpty ? lesson.actionPlans.first : '先完成一个最小动作。'),
      reviewQuestion: rec.reviewPrompts.isNotEmpty ? rec.reviewPrompts.first : (lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '今天哪里最能体现当前问题结构？'),
      source: 'auto_next_cycle_reflow',
      raw: rec.raw,
    );
  }

  YangmingGrowthNavigatorResult _buildNavigatorFromWeeklySummary(YangmingTrainingWeeklySummaryResult summary, YangmingTrainingTrace trace) {
    final nextAction = widget.plan.dailyTasks.isNotEmpty
        ? widget.plan.dailyTasks[(trace.completedDays.clamp(0, widget.plan.dailyTasks.length - 1)).toInt()]
        : (widget.lesson.actionPlans.isNotEmpty ? widget.lesson.actionPlans.first : '先把一个最小动作接回现实。');
    final reviewQuestion = widget.plan.reviewPrompts.isNotEmpty
        ? widget.plan.reviewPrompts.first
        : (widget.lesson.reviewPrompts.isNotEmpty ? widget.lesson.reviewPrompts.first : '今天哪里最能体现当前问题结构？');
    return YangmingGrowthNavigatorResult(
      recommendedLessonId: widget.lesson.id,
      recommendedLessonTitle: widget.lesson.title,
      recommendedMissionTitle: widget.lesson.missionTitle,
      recommendedDurationDays: widget.plan.durationDays,
      recommendationSummary: '已根据周末总结自动回流：先继续围绕当前课程守持，再进入下一轮推荐。',
      whyThisLesson: summary.nextWeekFocus.trim().isEmpty ? '本周总结显示，还需要继续围绕当前课程压实训练。' : summary.nextWeekFocus,
      whyThisMission: summary.recurringObstacle.trim().isEmpty ? '先回到对应关卡重看高频卡点，再落回现实守持。' : '本周反复障碍提示：${summary.recurringObstacle}',
      whyThisDuration: '当前已有${widget.plan.durationDays}天训练在推进，先把这一轮总结出的重点继续压实。',
      nextAction: nextAction,
      reviewQuestion: reviewQuestion,
      source: 'auto_weekly_reflow',
      raw: summary.raw,
    );
  }

  Future<void> _saveDay(int index, {bool? done}) async {
    final trace = _trace;
    if (trace == null) return;
    final old = trace.days[index];
    final updatedDay = old.copyWith(
      done: done ?? old.done,
      fact: _factCtrls[index].text.trim(),
      reflection: _reflectionCtrls[index].text.trim(),
      checkedAt: DateTime.now().toIso8601String(),
    );
    final days = List<YangmingTrainingDayCheckin>.from(trace.days);
    days[index] = updatedDay;
    final updated = trace.copyWith(days: days, updatedAt: DateTime.now().toIso8601String());
    await widget.dao.saveTrainingTrace(updated);
    if (!mounted) return;
    setState(() => _trace = updated);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存当天打点')));
  }

  Future<void> _runCorrection() async {
    final trace = _trace;
    if (trace == null) return;
    setState(() => _runningCorrection = true);
    final result = await widget.ai.generateTrainingCorrectionStructured(
      lesson: widget.lesson,
      content: widget.lessonContent,
      profile: widget.profile,
      plan: widget.plan,
      trace: trace,
    );
    final updated = trace.copyWith(
      latestCorrection: '主要模式：${result.mainPattern}\n继续保持：${result.keepDoing}\n此刻调整：${result.adjustNow}\n未来3天：${result.nextFocus}\n提醒：${result.reminder}',
      updatedAt: DateTime.now().toIso8601String(),
    );
    await widget.dao.saveTrainingTrace(updated);
    if (!mounted) return;
    setState(() {
      _trace = updated;
      _correction = result;
      _runningCorrection = false;
    });
  }

  Future<void> _runWeeklySummary() async {
    final trace = _trace;
    if (trace == null) return;
    setState(() => _runningSummary = true);
    final result = await widget.ai.generateTrainingWeeklySummaryStructured(
      lesson: widget.lesson,
      content: widget.lessonContent,
      profile: widget.profile,
      plan: widget.plan,
      trace: trace,
    );
    final updated = trace.copyWith(
      latestWeeklySummary: '完成情况：${result.completionSignal}\n最大变化：${result.biggestShift}\n反复障碍：${result.recurringObstacle}\n下周重点：${result.nextWeekFocus}\n提醒：${result.reminder}',
      updatedAt: DateTime.now().toIso8601String(),
    );
    await widget.dao.saveTrainingTrace(updated);
    await widget.onPublishNavigator(_buildNavigatorFromWeeklySummary(result, updated));
    if (!mounted) return;
    setState(() {
      _trace = updated;
      _weeklySummary = result;
      _runningSummary = false;
    });
  }

  Future<void> _runNextCycleRecommendation() async {
    final trace = _trace;
    if (trace == null) return;
    setState(() => _runningNextCycle = true);
    try {
      final result = await widget.ai.generateNextCycleRecommendationStructured(
        currentLesson: widget.lesson,
        currentContent: widget.lessonContent,
        profile: widget.profile,
        currentPlan: widget.plan,
        trace: trace,
        lessons: yangmingLessons,
        lessonContents: widget.lessonContents,
        latestCorrection: _correction,
        latestWeeklySummary: _weeklySummary,
      );
      await widget.onPublishNextCycle(result);
      if (!mounted) return;
      setState(() {
        _nextCycle = result;
        _runningNextCycle = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _runningNextCycle = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('生成下一周期推荐失败')));
    }
  }

  Future<void> _createPlanFromRecommendation() async {
    final rec = _nextCycle;
    if (rec == null) return;
    setState(() => _runningNextCycle = true);
    try {
      final lesson = yangmingLessons.firstWhere(
        (e) => e.id == rec.recommendedLessonId,
        orElse: () => widget.lesson,
      );
      final content = widget.lessonContents[lesson.id];
      final planResult = await widget.ai.generateTrainingPlanStructured(
        lesson: lesson,
        content: content,
        profile: widget.profile,
        durationDays: rec.recommendedDurationDays <= 0 ? 3 : rec.recommendedDurationDays,
        concern: rec.trainingFocus.trim().isEmpty ? rec.recommendationSummary : rec.trainingFocus,
        anchorAction: rec.starterActions.isNotEmpty ? rec.starterActions.first : '',
      );
      final plan = widget.dao.createTrainingPlan(
        lessonId: lesson.id,
        lessonTitle: lesson.title,
        durationDays: planResult.durationDays,
        planTheme: planResult.planTheme,
        planSummary: planResult.planSummary,
        dailyTasks: planResult.dailyTasks,
        guardrails: planResult.guardrails,
        checkpoints: planResult.checkpoints,
        reviewPrompts: planResult.reviewPrompts,
        source: 'ai_next_cycle_plan',
      );
      await widget.dao.saveTrainingPlan(plan);
      await widget.dao.markLessonCompleted(lesson.id);
      await widget.onPublishNavigator(
        YangmingGrowthNavigatorResult.fallback(
          lesson: lesson,
          durationDays: plan.durationDays,
          summary: '下一轮计划已生成，首页成长导航会优先把你带回这份新训练。',
          whyLesson: rec.whyThisLesson.trim().isEmpty ? '这段课程就是下一轮最该继续深化的入口。' : rec.whyThisLesson,
          whyMission: '先进入对应关卡，把新计划的训练重点重新带回情境中操练。',
          whyDuration: rec.whyThisDuration.trim().isEmpty ? '这是一份依据当前训练轨迹自动生成的新周期。' : rec.whyThisDuration,
          nextAction: plan.dailyTasks.isNotEmpty ? plan.dailyTasks.first : (lesson.actionPlans.isNotEmpty ? lesson.actionPlans.first : '先完成一个最小动作。'),
          reviewQuestion: plan.reviewPrompts.isNotEmpty ? plan.reviewPrompts.first : (lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '今天哪里最能体现当前问题结构？'),
          source: 'auto_new_plan_reflow',
        ),
      );
      if (!mounted) return;
      setState(() => _runningNextCycle = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已生成下一周期计划：${plan.planTheme}')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _runningNextCycle = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('按推荐生成计划失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final trace = _trace;
    if (_loading || trace == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final percent = trace.days.isEmpty ? 0.0 : trace.completedDays / trace.days.length;
    return Scaffold(
      appBar: AppBar(title: const Text('周期训练执行台')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: <Widget>[
          _SectionCard(title: widget.plan.planTheme, children: <Widget>[
            Text('${widget.plan.lessonTitle} · ${widget.plan.durationDays}天计划', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 10),
            Text(widget.plan.planSummary, style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF374151))),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: percent, minHeight: 10, backgroundColor: const Color(0xFFE5E7EB), color: const Color(0xFF6D28D9)),
            ),
            const SizedBox(height: 8),
            Text('已完成 ${trace.completedDays}/${trace.days.length} 天', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9))),
            if (widget.plan.guardrails.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _ListBlock(title: '守则', items: widget.plan.guardrails),
            ],
          ]),
          const SizedBox(height: 14),
          _SectionCard(title: 'AI 周中纠偏 / 周末总结', children: <Widget>[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _runningCorrection ? null : _runCorrection,
                  icon: _runningCorrection ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.tune_outlined),
                  label: const Text('AI 周中纠偏'),
                ),
                OutlinedButton.icon(
                  onPressed: _runningSummary ? null : _runWeeklySummary,
                  icon: _runningSummary ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.summarize_outlined),
                  label: const Text('AI 周末总结'),
                ),
              ],
            ),
            if (_correction != null) ...<Widget>[
              const SizedBox(height: 12),
              _StructuredTrainingCorrectionCard(result: _correction!),
            ] else if (trace.latestCorrection.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _MiniSection(title: '上次纠偏', body: trace.latestCorrection),
            ],
            if (_weeklySummary != null) ...<Widget>[
              const SizedBox(height: 12),
              _StructuredTrainingWeeklySummaryCard(result: _weeklySummary!),
            ] else if (trace.latestWeeklySummary.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _MiniSection(title: '上次总结', body: trace.latestWeeklySummary),
            ],
          ]),
          const SizedBox(height: 14),

          const SizedBox(height: 14),
          _SectionCard(title: '下一周期推荐', children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '根据当前课程、人格画像、每日打点、周中纠偏与周末总结，生成下一轮推荐课程与训练天数。',
                    style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _runningNextCycle ? null : _runNextCycleRecommendation,
                  icon: _runningNextCycle ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.alt_route_outlined),
                  label: const Text('AI 生成下一周期'),
                ),
                if (_nextCycle != null)
                  OutlinedButton.icon(
                    onPressed: _runningNextCycle ? null : _createPlanFromRecommendation,
                    icon: const Icon(Icons.playlist_add_check_circle_outlined),
                    label: const Text('按推荐生成计划'),
                  ),
              ],
            ),
            if (_nextCycle != null) ...<Widget>[
              const SizedBox(height: 12),
              _StructuredNextCycleRecommendationCard(result: _nextCycle!),
            ],
          ]),
          const SizedBox(height: 14),
          _SectionCard(title: '每日打点', children: <Widget>[
            ...List<Widget>.generate(trace.days.length, (index) {
              final day = trace.days[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Row(children: <Widget>[
                    Expanded(child: Text('第${day.dayIndex}天', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                    Checkbox(value: day.done, onChanged: (v) => _saveDay(index, done: v ?? false)),
                  ]),
                  Text(day.task, style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF374151))),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _factCtrls[index],
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: '事实记录',
                      hintText: '今天具体做了什么、什么时候、结果怎样',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reflectionCtrls[index],
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: '当日反思',
                      hintText: widget.plan.reviewPrompts.isNotEmpty ? widget.plan.reviewPrompts.first : '今天哪一刻最体现这段课程？',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _saveDay(index),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('保存当天记录'),
                    ),
                  ),
                ]),
              );
            }),
          ]),
        ],
      ),
    );
  }
}

class _StructuredTrainingCorrectionCard extends StatelessWidget {
  final YangmingTrainingCorrectionResult result;
  const _StructuredTrainingCorrectionCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('AI 周中纠偏', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _MiniSection(title: '当前主要模式', body: result.mainPattern),
        const SizedBox(height: 10),
        _MiniSection(title: '继续保持', body: result.keepDoing),
        const SizedBox(height: 10),
        _MiniSection(title: '此刻最该调整', body: result.adjustNow),
        const SizedBox(height: 10),
        _MiniSection(title: '未来3天重点', body: result.nextFocus),
        const SizedBox(height: 10),
        _MiniSection(title: '提醒', body: result.reminder),
      ],
    );
  }
}

class _StructuredTrainingWeeklySummaryCard extends StatelessWidget {
  final YangmingTrainingWeeklySummaryResult result;
  const _StructuredTrainingWeeklySummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('AI 周末总结', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _MiniSection(title: '完成情况', body: result.completionSignal),
        const SizedBox(height: 10),
        _MiniSection(title: '最大变化', body: result.biggestShift),
        const SizedBox(height: 10),
        _MiniSection(title: '反复障碍', body: result.recurringObstacle),
        const SizedBox(height: 10),
        _MiniSection(title: '下周重点', body: result.nextWeekFocus),
        const SizedBox(height: 10),
        _MiniSection(title: '提醒', body: result.reminder),
      ],
    );
  }
}


class _StructuredNextCycleRecommendationCard extends StatelessWidget {
  final YangmingNextCycleRecommendationResult result;
  const _StructuredNextCycleRecommendationCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('AI 下一周期推荐', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _MiniSection(title: '推荐课程', body: '${result.recommendedLessonTitle}（${result.recommendedLessonId}）'),
        const SizedBox(height: 10),
        _MiniSection(title: '推荐天数', body: '${result.recommendedDurationDays}天'),
        const SizedBox(height: 10),
        _MiniSection(title: '推荐摘要', body: result.recommendationSummary),
        const SizedBox(height: 10),
        _MiniSection(title: '为什么是这段课程', body: result.whyThisLesson),
        const SizedBox(height: 10),
        _MiniSection(title: '为什么是这个天数', body: result.whyThisDuration),
        const SizedBox(height: 10),
        _MiniSection(title: '下一轮训练重点', body: result.trainingFocus),
        if (result.starterActions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _ListBlock(title: '下一轮起手动作', items: result.starterActions),
        ],
        if (result.reviewPrompts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _ListBlock(title: '下一轮复盘问题', items: result.reviewPrompts),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _LongTextBlock extends StatelessWidget {
  final String label;
  final String value;
  const _LongTextBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
        const SizedBox(height: 6),
        Text(value.trim().isEmpty ? '（暂无内容）' : value, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.6)),
      ]),
    );
  }
}

class _PlaceholderBox extends StatelessWidget {
  final String label;
  final String value;
  const _PlaceholderBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.5)),
      ]),
    );
  }
}

class _ListBlock extends StatelessWidget {
  final String title;
  final List<String> items;
  const _ListBlock({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...items.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Padding(padding: EdgeInsets.only(top: 6), child: CircleAvatar(radius: 3, backgroundColor: Color(0xFF111827))),
            const SizedBox(width: 8),
            Expanded(child: Text(e, style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF374151)))),
          ]),
        )),
      ],
    );
  }
}

class _MiniSection extends StatelessWidget {
  final String title;
  final String body;
  const _MiniSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(body, style: const TextStyle(fontSize: 14, height: 1.65, color: Color(0xFF374151))),
      ],
    );
  }
}

String _fmt(String iso) {
  if (iso.length >= 16) {
    return iso.substring(0, 16).replaceFirst('T', ' ');
  }
  return iso;
}

String _formatReviewSummary(YangmingReviewResult result) {
  return '1. 主要问题：${result.mainProblem}\n2. 值得肯定：${result.affirmation}\n3. 需要修正：${result.correction}\n4. 明天行动：${result.nextAction}\n5. 提醒：${result.reminder}';
}
