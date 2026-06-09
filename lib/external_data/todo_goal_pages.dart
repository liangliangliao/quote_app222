import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'todo_dao.dart';
import 'todo_goal_ai_service.dart';
import 'todo_goal_dao.dart';
import 'todo_goal_models.dart';
import 'todo_goal_prompt_config.dart';
import 'todo_goal_value_system.dart';
import 'todo_models.dart';
import 'todo_service.dart';

const _goalBlue = Color(0xFF5E72C3);
const _goalInk = Color(0xFF22223B);

class TodoGoalHomePage extends StatefulWidget {
  const TodoGoalHomePage({super.key, this.initialTaskId});
  final String? initialTaskId;

  @override
  State<TodoGoalHomePage> createState() => _TodoGoalHomePageState();
}

class _TodoGoalHomePageState extends State<TodoGoalHomePage> with SingleTickerProviderStateMixin {
  final _todoDao = TodoDao();
  final _goalDao = TodoGoalDao();
  final _ai = TodoGoalAiService();
  final _promptConfig = TodoGoalPromptConfig();
  final _manualGoalTitleCtrl = TextEditingController();
  final _manualGoalBodyCtrl = TextEditingController();
  final _clarifyWhyCtrl = TextEditingController();
  final _clarifyOwnershipCtrl = TextEditingController();
  final _clarifyChangeCtrl = TextEditingController();
  final _clarifyProcessCtrl = TextEditingController();
  final _clarifyValuesCtrl = TextEditingController();
  late final _todoService = TodoGraphService(dao: _todoDao);
  late final TabController _tabController;
  bool _loading = true;
  bool _busy = false;
  String _status = '';
  List<TodoGoalProfile> _goals = [];
  List<TodoTaskRecord> _tasks = [];
  List<TodoGoalActionStep> _todaySteps = [];
  List<TodoGoalReflection> _reflections = [];
  TodoGoalWeeklySummaryResult? _weeklyAiSummary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _load().then((_) async {
      final id = widget.initialTaskId;
      if (id != null && id.trim().isNotEmpty) {
        final task = await _todoDao.getTask(id.trim());
        if (task != null && mounted) await _transformTask(task, openDetail: true);
      }
    });
  }

  @override
  void dispose() {
    _manualGoalTitleCtrl.dispose();
    _manualGoalBodyCtrl.dispose();
    _clarifyWhyCtrl.dispose();
    _clarifyOwnershipCtrl.dispose();
    _clarifyChangeCtrl.dispose();
    _clarifyProcessCtrl.dispose();
    _clarifyValuesCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _goalDao.ensureTables();
      final goals = await _goalDao.listGoals();
      final tasks = await _goalDao.listCandidateTasks();
      final today = await _goalDao.listTodaySteps();
      final reflections = await _goalDao.listReflections();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = '';
        _goals = goals;
        _tasks = tasks;
        _todaySteps = today;
        _reflections = reflections;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = '加载目标实践系统失败：$e';
      });
      _show('加载目标实践系统失败：$e', isError: true);
    }
  }

  Future<void> _transformTask(TodoTaskRecord task, {bool openDetail = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '正在把 To Do 任务转化为自我和谐目标...';
    });
    try {
      final analysis = await _ai.analyzeTaskAsGoal(task);
      final goalId = await _goalDao.saveGoalFromAnalysis(task: task, analysis: analysis);
      await _load();
      if (!mounted) return;
      final message = analysis.usedFallback ? '已使用本地策略生成目标。配置 AI 后可重新分析。' : 'AI 已生成目标、过程价值和今日最小行动。';
      _show(message);
      if (openDetail) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => TodoGoalDetailPage(goalId: goalId)));
        if (mounted) await _load();
      }
    } catch (e) {
      if (!mounted) return;
      _show('目标转化失败：$e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = '';
        });
      }
    }
  }

  TodoTaskRecord _buildManualTask(String title, String body) {
    final now = DateTime.now().toIso8601String();
    return TodoTaskRecord(
      taskId: 'manual_goal_${DateTime.now().microsecondsSinceEpoch}',
      listId: 'manual_input',
      listDisplayName: '用户输入目标',
      title: title.trim(),
      bodyText: body.trim(),
      bodyHtml: '',
      bodyContentType: 'text',
      status: 'notStarted',
      importance: 'normal',
      createdDateTime: now,
      lastModifiedDateTime: now,
      dueDateTime: '',
      dueTimeZone: '',
      startDateTime: '',
      startTimeZone: '',
      isReminderOn: false,
      isMyDay: false,
      reminderDateTime: '',
      reminderTimeZone: '',
      completedDateTime: '',
      recurrenceJson: '',
      categoriesJson: '',
      hasAttachments: false,
      checklistCount: 0,
      attachmentCount: 0,
      linkedResourceCount: 0,
      localStatus: 'local',
      localDeleted: false,
      syncedAtMs: 0,
    );
  }

  Future<void> _transformManualGoal() async {
    final title = _manualGoalTitleCtrl.text.trim();
    if (title.isEmpty) {
      _show('请先输入一个你真正关心的目标或棘手问题。', isError: true);
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '正在把用户输入目标转化为自我一致目标...';
    });
    try {
      final clarification = <String>[
        if (_clarifyWhyCtrl.text.trim().isNotEmpty) '为什么想要：${_clarifyWhyCtrl.text.trim()}',
        if (_clarifyOwnershipCtrl.text.trim().isNotEmpty) '目标归属：${_clarifyOwnershipCtrl.text.trim()}',
        if (_clarifyChangeCtrl.text.trim().isNotEmpty) '期待变化：${_clarifyChangeCtrl.text.trim()}',
        if (_clarifyProcessCtrl.text.trim().isNotEmpty) '愿意体验的过程：${_clarifyProcessCtrl.text.trim()}',
        if (_clarifyValuesCtrl.text.trim().isNotEmpty) '核心价值：${_clarifyValuesCtrl.text.trim()}',
      ].join('\n');
      final background = [_manualGoalBodyCtrl.text.trim(), clarification].where((text) => text.isNotEmpty).join('\n\n');
      final task = _buildManualTask(title, background);
      final analysis = await _ai.analyzeTaskAsGoal(task);
      final goalId = await _goalDao.saveGoalFromAnalysis(task: task, analysis: analysis);
      _manualGoalTitleCtrl.clear();
      _manualGoalBodyCtrl.clear();
      _clarifyWhyCtrl.clear();
      _clarifyOwnershipCtrl.clear();
      _clarifyChangeCtrl.clear();
      _clarifyProcessCtrl.clear();
      _clarifyValuesCtrl.clear();
      await _load();
      if (!mounted) return;
      _show(analysis.usedFallback ? '已使用本地策略生成目标卡。配置 AI 后可重新分析。' : 'AI 已生成目标卡。需要问题树时，请在详情页单独点击“生成方案”。');
      await Navigator.push(context, MaterialPageRoute(builder: (_) => TodoGoalDetailPage(goalId: goalId)));
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      _show('目标转化失败：$e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = '';
        });
      }
    }
  }

  Future<void> _toggleStep(TodoGoalActionStep step) async {
    await _goalDao.completeStep(step.stepId, completed: !step.isCompleted);
    await _load();
  }

  Future<void> _startStep(TodoGoalActionStep step) async {
    if (step.isCompleted) return;
    var intention = step.experienceIntention.trim();
    if (intention.isEmpty || intention.startsWith('今天做这件事时')) {
      final selected = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('今天攀登时，你想体验什么？'),
          children: [
            SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, '学习感：允许自己先不熟练'), child: const Text('学习感 · 允许不熟练')),
            SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, '掌控感：只专注于手边这一步'), child: const Text('掌控感 · 专注这一步')),
            SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, '勇气：在不完美中仍然开始'), child: const Text('勇气 · 不完美也开始')),
            SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, '自由：为未来增加一点选择权'), child: const Text('自由 · 增加选择权')),
            SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, '进步感：比开始前多一个事实证据'), child: const Text('一点点进步 · 留下证据')),
          ],
        ),
      );
      if (!mounted) return;
      if (selected != null && selected.trim().isNotEmpty) {
        intention = selected.trim();
        await _goalDao.updateStepExperienceIntention(step.stepId, intention);
      }
    }
    await _goalDao.updateStepStatus(step.stepId, 'in_progress');
    await _load();
    _show(intention.isEmpty ? '已进入 5 分钟行动：先开始，不要求一次完成。' : '已进入 5 分钟行动。今天留意：$intention');
  }

  Future<void> _makeStepSmaller(TodoGoalActionStep step) async {
    await _goalDao.createActionStep(
      goalId: step.goalId,
      sourceTaskId: step.sourceTaskId,
      title: '先做2分钟：${step.title}',
      minimumStandard: '只做2分钟，打开、写一句、读一遍或完成一个最小可观察动作即可。',
      simplifiedStandard: '做5分钟，并留下一个事实记录。',
      recommendedStandard: '完成5分钟，并留下一个事实记录。',
      stretchStandard: '状态允许时再推进到15分钟，不强求。',
      difficultyScore: 2,
      zoneType: 'stretch',
      plannedDate: _goalDao.todayDate(),
      parentStepId: step.stepId,
      actionType: step.actionType,
      experienceIntention: step.experienceIntention,
    );
    await _load();
    _show('已把行动缩小成更容易开始的一步。');
  }

  Future<void> _writeStepBack(TodoGoalActionStep step) async {
    if (step.sourceListId.trim().isEmpty || step.sourceListId.startsWith('smart_')) {
      _show('这个目标没有可写回的真实 To Do 列表，请先从真实任务列表中的任务转化。', isError: true);
      return;
    }
    setState(() {
      _busy = true;
      _status = '正在写回 Microsoft To Do...';
    });
    try {
      final quote = todoGoalQuoteForMoment('write_back', seedOffset: step.stepId.hashCode);
      final parentLine = step.hasParentStep ? '父步骤：${step.parentLabel}' : '父步骤：这是父目标下的第一层行动';
      final body = '''关系路径：
父目标：${step.goalTitle}
$parentLine
今日行动：${step.title}

今天只实践这一件事：${step.title}

为什么做：
${step.deepMeaning}

开始前只问一个问题：
我现在能不能先做最低标准，而不是等待状态完美？

最低完成标准：
${step.minimumStandard}

正常推进标准：
${step.recommendedStandard}

做的时候观察：
${step.processValue}

完成后留一句记录：我做了什么？过程中有什么真实体验？

今日提示：${quote.title}
${quote.translation}

由 App 根据“目标服务当下、过程进入行动”的原则生成。''';
      final remoteTaskId = await _todoService.createTask(
        listId: step.sourceListId,
        title: '[今日最小行动] ${step.title}',
        bodyText: body,
        status: 'notStarted',
        importance: 'normal',
        dueDateTime: '',
        dueTimeZone: 'Asia/Shanghai',
        isReminderOn: false,
        recurrenceJson: '',
        categoriesJson: '',
        isMyDay: true,
        writeBack: true,
      );
      await _goalDao.markStepWrittenBack(stepId: step.stepId, remoteTaskId: remoteTaskId);
      await _goalDao.addSyncLink(goalId: step.goalId, localStepId: step.stepId, todoListId: step.sourceListId, todoTaskId: remoteTaskId);
      await _load();
      _show('今日最小行动已写回 Microsoft To Do，并加入本地“我的一天”。');
    } catch (e) {
      _show('写回失败：$e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = '';
        });
      }
    }
  }

  Future<bool> _confirmDanger({required String title, required String message, String actionText = '确认'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(actionText)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _resetGoalModuleDefaults() async {
    if (_busy) return;
    final ok = await _confirmDanger(title: '恢复默认配置', message: '这会恢复 To Do 目标实践系统的默认 AI 提示词，不会删除已有目标、行动或复盘。');
    if (!ok) return;
    await _promptConfig.reset();
    await _load();
    _show('已恢复 To Do 目标实践系统默认配置。');
  }

  Future<void> _clearGoalModuleData() async {
    if (_busy) return;
    final ok = await _confirmDanger(
      title: '清除全部目标模块数据？',
      message: '这会删除“向峰而行/To Do目标实践系统”的目标卡、今日行动、复盘、AI分析、问题解决方案和写回链接，并恢复默认提示词。不会删除 Microsoft To Do 原始同步任务。',
      actionText: '清除并恢复默认',
    );
    if (!ok) return;
    setState(() {
      _busy = true;
      _status = '正在清除目标模块数据并恢复默认状态...';
    });
    try {
      await _goalDao.clearAllGoalModuleData();
      await _promptConfig.reset();
      _manualGoalTitleCtrl.clear();
      _manualGoalBodyCtrl.clear();
      _clarifyWhyCtrl.clear();
      _clarifyOwnershipCtrl.clear();
      _clarifyChangeCtrl.clear();
      _clarifyProcessCtrl.clear();
      _clarifyValuesCtrl.clear();
      await _load();
      if (mounted) _show('已清除目标模块全部数据，并恢复默认状态。');
    } catch (e) {
      if (mounted) _show('清除失败：$e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = '';
        });
      }
    }
  }

  void _show(String message, {bool isError = false}) {
    if (!mounted) return;
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red.shade700 : null));
  }

  TodoGoalProfile? get _primaryActiveGoal {
    for (final goal in _goals) {
      if (goal.status == 'active') return goal;
    }
    return null;
  }

  TodoGoalActionStep? get _firstOpenTodayStep {
    for (final step in _todaySteps) {
      if (!step.isCompleted) return step;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('向峰而行 · 目标系统'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '今日攀登'),
            Tab(text: '我的山峰'),
            Tab(text: '山路行动'),
            Tab(text: '过程复盘'),
            Tab(text: 'AI教练'),
            Tab(text: '价值罗盘'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '提示词配置位置',
            onPressed: () => _show('AI 提示词请到：外部数据同步 → 右上角统一配置 → To Do 目标实践系统 AI 提示词 中统一配置。'),
            icon: const Icon(Icons.tune_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: '模块重置/清理',
            onSelected: (value) {
              if (value == 'reset_defaults') _resetGoalModuleDefaults();
              if (value == 'clear_all') _clearGoalModuleData();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reset_defaults', child: Text('恢复默认配置')),
              PopupMenuItem(value: 'clear_all', child: Text('清除目标模块全部数据')),
            ],
          ),
          IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    _buildValueSystemTab(),
                    _buildTransformTab(),
                    _buildTodayTab(),
                    _buildReviewTab(),
                    _buildCoachTab(),
                    _buildCompassTab(),
                  ],
                ),
                if (_busy)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _ProgressBanner(status: _status),
                  ),
              ],
            ),
    );
  }

  Widget _buildValueSystemTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        children: [
          _TodayClimbDashboard(
            goal: _primaryActiveGoal,
            step: _firstOpenTodayStep,
            completedCount: _todaySteps.where((step) => step.isCompleted).length,
            onStart: () => _tabController.animateTo(2),
            onCreateGoal: () => _tabController.animateTo(1),
          ),
          const SizedBox(height: 12),
          _ValuePracticeHeroCard(onStartToday: () => _tabController.animateTo(2), onTransform: () => _tabController.animateTo(1)),
          const SizedBox(height: 12),
          _TodayPracticeConsoleCard(goalCount: _goals.length, actionCount: _todaySteps.length, completedCount: _todaySteps.where((s) => s.isCompleted).length),
          const SizedBox(height: 12),
          _ContextualQuoteCard(momentTitle: '开始前的一句话', momentKey: 'entry', quote: todoGoalQuoteForMoment('entry'), actionText: todoGoalQuoteActionForMoment('entry')),
          const SizedBox(height: 12),
          const _FiveQuestionPracticeCard(),
        ],
      ),
    );
  }

  Widget _buildTransformTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        children: [
          const _GoalHeroCard(),
          const SizedBox(height: 12),
          _ContextualQuoteCard(momentTitle: '转化前提示', momentKey: 'transform', quote: todoGoalQuoteForMoment('transform'), actionText: todoGoalQuoteActionForMoment('transform')),
          const SizedBox(height: 12),
          const _TransformPracticeCard(),
          const SizedBox(height: 12),
          _ManualGoalInputCard(
            titleCtrl: _manualGoalTitleCtrl,
            bodyCtrl: _manualGoalBodyCtrl,
            whyCtrl: _clarifyWhyCtrl,
            ownershipCtrl: _clarifyOwnershipCtrl,
            changeCtrl: _clarifyChangeCtrl,
            processCtrl: _clarifyProcessCtrl,
            valuesCtrl: _clarifyValuesCtrl,
            busy: _busy,
            onGenerate: _transformManualGoal,
          ),
          const SizedBox(height: 12),
          _SectionHeader(
            title: '已转化目标',
            subtitle: _goals.isEmpty ? '还没有目标。可从下方 To Do 任务开始转化。' : '这些目标来自 Microsoft To Do，但已被重新校准为：方向感、深层意义、自我和谐、过程体验和今日最小行动。',
          ),
          if (_goals.isEmpty) const _EmptyCard(text: '暂无已转化目标。'),
          ..._goals.map((g) => _GoalCard(
                goal: g,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoGoalDetailPage(goalId: g.goalId))).then((_) => _load()),
              )),
          const SizedBox(height: 18),
          const _SectionHeader(title: '从 To Do 任务转化', subtitle: '不要机械拆任务；先判断它是否通向你真正关心的生活，再生成能落到今天的最小行动。'),
          if (_tasks.isEmpty) const _EmptyCard(text: '暂无可转化的未完成 To Do 任务。请先同步或新建任务。'),
          ..._tasks.map((t) => _CandidateTaskCard(task: t, busy: _busy, onTransform: () => _transformTask(t, openDetail: true))),
        ],
      ),
    );
  }

  Widget _buildTodayTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        children: [
          const _TodayJourneyIntroCard(),
          const SizedBox(height: 12),
          _ContextualQuoteCard(momentTitle: '行动前提示', momentKey: 'today', quote: todoGoalQuoteForMoment('today'), actionText: todoGoalQuoteActionForMoment('today')),
          const SizedBox(height: 12),
          const _TodayValueChecklistCard(),
          const SizedBox(height: 12),
          _SectionHeader(title: '今日行动关系树', subtitle: _todaySteps.isEmpty ? '暂无今日行动。请先把一个 To Do 任务转化为目标。' : '用“父目标 → 父步骤 → 子步骤”的树状关系看清每一步从哪里来、下一步接在哪里。'),
          const _JourneyRelationLegendCard(),
          if (_todaySteps.isEmpty) const _EmptyCard(text: '暂无今日最小行动。'),
          ..._buildTodayTreeWidgets(),
        ],
      ),
    );
  }


  List<Widget> _buildTodayTreeWidgets() {
    if (_todaySteps.isEmpty) return const <Widget>[];
    final grouped = <String, List<TodoGoalActionStep>>{};
    for (final step in _todaySteps) {
      grouped.putIfAbsent(step.goalId, () => <TodoGoalActionStep>[]).add(step);
    }
    return grouped.entries.map((entry) {
      final steps = entry.value;
      return _TodayGoalTreeCard(
        goalTitle: steps.first.goalTitle.trim().isEmpty ? '未命名父目标' : steps.first.goalTitle,
        steps: steps,
        onToggle: _toggleStep,
        onStart: _startStep,
        onMakeSmaller: _makeStepSmaller,
        onReview: (step) => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoGoalReviewPage(step: step))).then((_) => _load()),
        onWriteBack: (step) => step.writeBackToTodo || _busy ? null : () => _writeStepBack(step),
      );
    }).toList();
  }

  Widget _buildReviewTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        children: [
          const _ReviewIntroCard(),
          const SizedBox(height: 12),
          _ContextualQuoteCard(momentTitle: '复盘提示', momentKey: 'review', quote: todoGoalQuoteForMoment('review'), actionText: todoGoalQuoteActionForMoment('review')),
          const SizedBox(height: 12),
          const _ReviewValueChecklistCard(),
          const SizedBox(height: 12),
          _SectionHeader(title: '最近复盘', subtitle: _reflections.isEmpty ? '完成或部分完成今日行动后，可在这里沉淀过程体验。' : '复盘不是自责，而是让目标继续靠近真实生活。'),
          if (_reflections.isEmpty) const _EmptyCard(text: '暂无复盘记录。'),
          ..._reflections.map((r) => _ReflectionCard(reflection: r)),
        ],
      ),
    );
  }

  Widget _buildCoachTab() {
    final activeGoal = _primaryActiveGoal;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        children: [
          _AiCoachConsoleCard(
            activeGoal: activeGoal,
            onClarify: () => _tabController.animateTo(1),
            onAction: () => _tabController.animateTo(2),
            onReview: () => _tabController.animateTo(3),
            onCompass: () => _tabController.animateTo(5),
            onOpenGoal: activeGoal == null
                ? null
                : () => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoGoalDetailPage(goalId: activeGoal.goalId))).then((_) => _load()),
          ),
          const SizedBox(height: 12),
          const _PathRegretCoachingCard(),
          const SizedBox(height: 12),
          const _PlainValueCard(
            icon: Icons.psychology_alt_outlined,
            title: 'AI 教练的边界',
            text: '这里不是普通闲聊入口，而是把目标澄清、价值追问、行动拆解、阻碍分析、过程重构、复盘总结和目标调整串成固定流程。复杂问题树仍在目标详情页单独生成，避免拖慢目标分析。',
          ),
        ],
      ),
    );
  }

  Future<void> _generateWeeklySummary() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '正在生成本周过程总结...';
    });
    try {
      final since = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
      final result = await _ai.generateWeeklySummary(
        goals: _goals,
        reflections: _reflections.where((reflection) => reflection.createdAtMs >= since).toList(),
      );
      if (!mounted) return;
      setState(() => _weeklyAiSummary = result);
      _show(result.usedFallback ? '当前使用本地策略生成周总结。' : 'AI 已生成本周过程与价值总结。');
    } catch (e) {
      if (mounted) _show('周总结生成失败：$e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = '';
        });
      }
    }
  }

  Widget _buildCompassTab() {
    final since = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final weekly = _reflections.where((reflection) => reflection.createdAtMs >= since).toList();
    final valueCounts = <String, int>{};
    for (final goal in _goals) {
      for (final value in goal.coreValueList) {
        valueCounts[value] = (valueCounts[value] ?? 0) + 1;
      }
    }
    final sortedValues = valueCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    double average(Iterable<int> values) {
      final list = values.where((value) => value > 0).toList();
      return list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        children: [
          _ValueCompassCard(goals: _goals, values: sortedValues),
          const SizedBox(height: 12),
          _WeeklyMeaningCard(
            reflectionCount: weekly.length,
            actionCount: _todaySteps.length,
            completedCount: _todaySteps.where((step) => step.isCompleted).length,
            meaningAverage: average(weekly.map((reflection) => reflection.meaningScore)),
            processAverage: average(weekly.map((reflection) => reflection.processScore)),
            moodAverage: average(weekly.map((reflection) => reflection.moodScore)),
            alignedGoals: _goals.where((goal) => goal.selfConcordanceScore >= 70).length,
            pressureGoals: _goals.where((goal) => goal.externalPressureScore >= 70).length,
            aiSummary: _weeklyAiSummary,
            busy: _busy,
            onGenerate: _generateWeeklySummary,
          ),
          const SizedBox(height: 12),
          const _PlainValueCard(
            icon: Icons.explore_outlined,
            title: '罗盘不是另一张成绩单',
            text: '它用来检查：哪些目标更像真实的你，哪些行动带来意义、投入和自主感，哪些目标需要暂停、降强度或重新绑定价值。',
          ),
        ],
      ),
    );
  }

}

class TodoGoalDetailPage extends StatefulWidget {
  const TodoGoalDetailPage({super.key, required this.goalId});
  final String goalId;

  @override
  State<TodoGoalDetailPage> createState() => _TodoGoalDetailPageState();
}

class _TodoGoalDetailPageState extends State<TodoGoalDetailPage> {
  final _goalDao = TodoGoalDao();
  final _todoDao = TodoDao();
  final _ai = TodoGoalAiService();
  TodoGoalProfile? _goal;
  TodoTaskRecord? _sourceTask;
  List<TodoGoalActionStep> _steps = [];
  List<TodoGoalSolutionPlan> _solutionPlans = [];
  List<TodoGoalProblemNode> _selectedNodes = [];
  bool _loading = true;
  bool _busy = false;
  String _loadError = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _goalDao.ensureTables();
      final goal = await _goalDao.getGoal(widget.goalId);
      final task = goal == null
          ? null
          : (goal.sourceType == 'manual_input'
              ? _manualTaskFromGoal(goal)
              : (goal.sourceTaskId.trim().isEmpty ? null : await _todoDao.getTask(goal.sourceTaskId)));
      final steps = await _goalDao.listActionSteps(widget.goalId);
      final plans = goal == null ? <TodoGoalSolutionPlan>[] : await _goalDao.listSolutionPlans(goalId: goal.goalId, includeArchived: false);
      final nodes = goal == null ? <TodoGoalProblemNode>[] : await _goalDao.listSelectedProblemNodes(goal.goalId);
      if (!mounted) return;
      setState(() {
        _goal = goal;
        _sourceTask = task;
        _steps = steps;
        _solutionPlans = plans;
        _selectedNodes = nodes;
        _loadError = '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '目标详情加载失败：$e';
        _loading = false;
      });
      _show('目标详情加载失败：$e', isError: true);
    }
  }

  TodoTaskRecord _manualTaskFromGoal(TodoGoalProfile goal) {
    final now = DateTime.now().toIso8601String();
    return TodoTaskRecord(
      taskId: goal.sourceTaskId.trim().isEmpty ? 'manual_goal_${DateTime.now().microsecondsSinceEpoch}' : goal.sourceTaskId,
      listId: 'manual_input',
      listDisplayName: '用户输入目标',
      title: goal.goalTitle,
      bodyText: '${goal.deepMeaning}\n${goal.obstacleSummary}',
      bodyHtml: '',
      bodyContentType: 'text',
      status: 'notStarted',
      importance: 'normal',
      createdDateTime: now,
      lastModifiedDateTime: now,
      dueDateTime: '',
      dueTimeZone: '',
      startDateTime: '',
      startTimeZone: '',
      isReminderOn: false,
      isMyDay: false,
      reminderDateTime: '',
      reminderTimeZone: '',
      completedDateTime: '',
      recurrenceJson: '',
      categoriesJson: '',
      hasAttachments: false,
      checklistCount: 0,
      attachmentCount: 0,
      linkedResourceCount: 0,
      localStatus: 'local',
      localDeleted: false,
      syncedAtMs: 0,
    );
  }

  Future<void> _reanalyze() async {
    final task = _sourceTask;
    if (task == null) return;
    setState(() => _busy = true);
    try {
      final result = await _ai.analyzeTaskAsGoal(task);
      await _goalDao.saveGoalFromAnalysis(task: task, analysis: result, existingGoalId: widget.goalId);
      await _load();
      _show(result.usedFallback ? '已使用本地策略重新生成。' : 'AI 已重新分析目标。');
    } catch (e) {
      _show('重新分析失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateProblemSolutions() async {
    final goal = _goal;
    final task = _sourceTask;
    if (goal == null || task == null || _busy) return;
    setState(() => _busy = true);
    try {
      final primaryStep = _steps.isEmpty ? null : _steps.first;
      TodoGoalActionStep? processStep;
      TodoGoalActionStep? valueStep;
      for (final step in _steps) {
        if (processStep == null && step.actionType == 'process') processStep = step;
        if (valueStep == null && step.actionType == 'value') valueStep = step;
        if (processStep != null && valueStep != null) break;
      }
      final analysis = TodoGoalAnalysisResult(
        goalTitle: goal.goalTitle,
        deepMeaning: goal.deepMeaning,
        desiredIdentity: goal.desiredIdentity,
        goalCategory: goal.goalCategory,
        goalOriginType: goal.goalOriginType,
        selfConcordanceScore: goal.selfConcordanceScore,
        processValue: goal.processValue,
        obstacleSummary: goal.obstacleSummary,
        todayMinimumAction: primaryStep == null ? '先做一个5分钟最小行动' : primaryStep.title,
        minimumStandard: primaryStep == null ? '开始5分钟即可。' : primaryStep.minimumStandard,
        recommendedStandard: primaryStep == null ? '完成一个小步骤并记录过程。' : primaryStep.recommendedStandard,
        stretchStandard: primaryStep == null ? '状态允许时推进15分钟。' : primaryStep.stretchStandard,
        difficultyScore: primaryStep == null ? 5 : primaryStep.difficultyScore,
        zoneType: primaryStep == null ? 'stretch' : primaryStep.zoneType,
        coachMessage: '',
        provider: goal.aiProvider,
        modelLabel: goal.aiModelLabel,
        resultGoal: goal.resultGoal,
        valueGoal: goal.valueGoal,
        processGoal: goal.processGoal,
        coreValues: goal.coreValues,
        autonomyScore: goal.autonomyScore,
        valueAlignmentScore: goal.valueAlignmentScore,
        interestConnectionScore: goal.interestConnectionScore,
        passionScore: goal.passionScore,
        feasibilityScore: goal.feasibilityScore,
        externalPressureScore: goal.externalPressureScore,
        processHappinessScore: goal.processHappinessScore,
        goalType: goal.goalType,
        currentStage: goal.currentStage,
        actionPlace: primaryStep?.actionPlace ?? '',
        startTrigger: primaryStep?.startTrigger ?? '',
        completionQuestion: primaryStep?.completionQuestion ?? '',
        processAction: processStep?.title ?? '',
        valueAction: valueStep?.title ?? '',
        experiencePrompt: primaryStep?.experienceIntention ?? '',
        userNeedInterpretation: goal.userNeedInterpretation,
        keyUncertainties: goal.keyUncertainties,
        clarifyingQuestions: goal.clarifyingQuestions,
        possibleDirections: goal.possibleDirections,
        referenceCases: goal.referenceCases,
        recommendationRationale: goal.recommendationRationale,
        userDecisionPrompt: goal.userDecisionPrompt,
      );
      final result = await _ai.generateProblemSolutions(task: task, analysis: analysis);
      final keepExisting = result.usedFallback && result.rawResponse.trim().isEmpty && _solutionPlans.isNotEmpty;
      if (!keepExisting) {
        await _goalDao.clearSolutionPlans(goal.goalId);
        await _goalDao.saveSolutionPlansFromAnalysis(goalId: goal.goalId, sourceTaskId: goal.sourceTaskId, plans: result.plans);
      }
      await _goalDao.addAiAnalysis(
        goalId: goal.goalId,
        sourceTaskId: goal.sourceTaskId,
        analysisType: 'goal_problem_solutions',
        promptText: '',
        resultJson: jsonEncode(result.toJson()),
        modelName: result.modelLabel,
      );
      await _load();
      final resultMessage = !result.usedFallback
          ? 'AI 已生成通过结构校验的问题解决方案和问题树。'
          : keepExisting
              ? 'AI方案请求未完成，已保留原有问题解决方案。'
              : result.rawResponse.trim().isNotEmpty
                  ? 'AI返回未通过推导链校验，已改用完整的本地备用问题树。'
                  : 'AI方案请求未完成，已生成完整的本地备用问题树。';
      _show(resultMessage);
    } catch (e) {
      _show('生成问题解决方案失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addTinyStep() async {
    final goal = _goal;
    if (goal == null) return;
    final title = await _askText(title: '新增今日最小行动', hint: '例如：先做5分钟，并留下一个事实记录');
    if (title == null || title.trim().isEmpty) return;
    await _goalDao.createActionStep(
      goalId: goal.goalId,
      sourceTaskId: goal.sourceTaskId,
      title: title.trim(),
      minimumStandard: '开始5分钟即可。',
      simplifiedStandard: '做5分钟，并留下一个事实记录。',
      recommendedStandard: '完成一个小步骤并记录过程。',
      stretchStandard: '连续推进25分钟。',
      difficultyScore: 5,
      zoneType: 'stretch',
      plannedDate: _goalDao.todayDate(),
      actionType: 'result',
      experienceIntention: '由我自己判断这一步是否仍然服务于真实需要。',
    );
    await _load();
  }

  Future<void> _selectSolutionPlan(TodoGoalSolutionPlan plan) async {
    final goal = _goal;
    if (goal == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _goalDao.selectSolutionPlan(goalId: goal.goalId, solutionId: plan.solutionId);
      await _load();
      _show('已选择“${plan.title}”。其他方案已作为备用方案保留。');
    } catch (e) {
      _show('选择方案失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _problemNodeReady(TodoGoalProblemNode node, {required bool forEvaluation}) {
    final byId = <String, TodoGoalProblemNode>{for (final item in _selectedNodes) item.nodeId: item};
    if (!node.resolvedDependencyNodeIds.every((id) => byId[id]?.isCompleted == true)) return false;
    final parent = byId[node.parentNodeId];
    if (parent?.relationType.toLowerCase() == 'sequence') {
      final earlierSiblings = _selectedNodes.where((item) => item.parentNodeId == parent!.nodeId && item.sequenceOrder < node.sequenceOrder);
      if (!earlierSiblings.every((item) => item.isCompleted)) return false;
    }
    final children = _selectedNodes.where((item) => item.parentNodeId == node.nodeId).toList();
    if (!forEvaluation) return children.isEmpty && node.isActionable && node.hasConcreteActionContract;
    if (children.isEmpty) return true;
    return node.relationType.toLowerCase() == 'or' ? children.any((child) => child.isCompleted) : children.every((child) => child.isCompleted);
  }

  Future<void> _activateProblemNode(TodoGoalProblemNode node) async {
    final goal = _goal;
    if (goal == null || _busy) return;
    if (!_problemNodeReady(node, forEvaluation: false)) {
      _show('请先完成这个动作依赖的前置节点；只有最底层、可直接执行的动作才能加入今日行动。', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final stepId = await _goalDao.createStepFromProblemNode(node, sourceTaskId: goal.sourceTaskId);
      await _goalDao.updateProblemNodeStatus(node.nodeId, 'in_progress', completionNote: '已转入今日行动 step=$stepId');
      await _load();
      _show('已把该底层动作加入今日旅程。');
    } catch (e) {
      _show('加入今日行动失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markProblemNode(TodoGoalProblemNode node, String status) async {
    final goal = _goal;
    if (goal == null || _busy) return;
    if (!_problemNodeReady(node, forEvaluation: true)) {
      _show('这个父问题仍有前置或子问题未完成，请先从最底层动作开始。', isError: true);
      return;
    }
    final note = await _askText(
      title: status == 'failed' ? '这个节点为什么失败了？' : '这个节点成功完成了吗？',
      hint: status == 'failed' ? '写下现实阻力、卡住环节或失败事实，AI会据此给出重启指导和替代步骤。' : '可简单记录完成证据，例如：已做了什么、达到什么标准。',
    );
    if (note == null) return;
    setState(() => _busy = true);
    try {
      final parentMatches = _selectedNodes.where((item) => item.nodeId == node.parentNodeId).toList();
      final parentProblem = parentMatches.isEmpty ? goal.goalTitle : parentMatches.first.title;
      final reasoningBasis = <String>[node.description, node.logicQuestion].where((text) => text.trim().isNotEmpty).join('；');
      if (status == 'failed') {
        final recovery = await _ai.generateStepRecovery(
          goalTitle: goal.goalTitle,
          deepMeaning: goal.deepMeaning,
          processValue: goal.processValue,
          actionTitle: node.displayAction,
          minimumStandard: node.acceptanceCriteria,
          userResult: 'failure',
          userReflection: note,
          obstacle: note,
          parentProblem: parentProblem,
          reasoningBasis: reasoningBasis,
          decisionRule: node.decisionRule,
        );
        final reviewJson = jsonEncode(recovery.toJson());
        await _goalDao.updateProblemNodeStatus(node.nodeId, 'failed', completionNote: note.trim(), aiReviewJson: reviewJson);
        await _goalDao.addStepReview(
          goalId: goal.goalId,
          stepId: '',
          nodeId: node.nodeId,
          userResult: 'failure',
          userText: note.trim(),
          recovery: recovery,
        );
        final chosen = await _chooseAlternativeStep(recovery.alternatives);
        if (chosen != null) {
          await _goalDao.addAlternativeProblemNode(original: node, alternative: chosen);
          await _goalDao.createActionStep(
            goalId: goal.goalId,
            sourceTaskId: goal.sourceTaskId,
            title: chosen.title,
            minimumStandard: chosen.minimumStandard,
            simplifiedStandard: chosen.actionOutput.trim().isEmpty ? chosen.minimumStandard : '至少留下：${chosen.actionOutput}',
            recommendedStandard: <String>[chosen.actionProcedure, chosen.recommendedStandard].where((text) => text.trim().isNotEmpty).join('；'),
            stretchStandard: '如果仍然失败，先尝试复盘中保存的其他备用步骤，或切换备用方案；只有关键前提被证伪时才重构全方案。',
            difficultyScore: chosen.difficultyScore,
            zoneType: chosen.zoneType,
            plannedDate: _goalDao.todayDate(),
            actionPlace: chosen.actionWhere,
            startTrigger: chosen.actionWhen,
            completionQuestion: '是否已经得到“${chosen.actionOutput}”，并达到“${chosen.minimumStandard}”？',
            actionType: 'result',
            experienceIntention: '验证这个替代步骤能否绕过原阻力，同时继续解决同一个父问题。',
          );
        }
        _show(chosen == null ? '已保存失败复盘与AI替代步骤。' : '已保存失败复盘，并把所选替代步骤加入今日行动。');
      } else {
        final recovery = await _ai.generateStepRecovery(
          goalTitle: goal.goalTitle,
          deepMeaning: goal.deepMeaning,
          processValue: goal.processValue,
          actionTitle: node.displayAction,
          minimumStandard: node.acceptanceCriteria,
          userResult: 'success',
          userReflection: note,
          obstacle: '',
          parentProblem: parentProblem,
          reasoningBasis: reasoningBasis,
          decisionRule: node.decisionRule,
        );
        final reviewJson = jsonEncode(recovery.toJson());
        await _goalDao.updateProblemNodeStatus(node.nodeId, 'completed', completionNote: note.trim(), aiReviewJson: reviewJson);
        await _goalDao.addStepReview(
          goalId: goal.goalId,
          stepId: '',
          nodeId: node.nodeId,
          userResult: 'success',
          userText: note.trim(),
          recovery: recovery,
        );
        if (node.parentNodeId.trim().isEmpty) {
          await _goalDao.updateGoalStatus(goal.goalId, 'completed');
          _show('根问题已通过验收：所有必要子问题已逐层回推完成，目标已标记为实现。');
        } else {
          _show('已标记该子问题成功。请继续回到它的父问题进行验收。');
        }
      }
      await _load();
    } catch (e) {
      _show('节点复盘失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<TodoGoalAlternativeStep?> _chooseAlternativeStep(List<TodoGoalAlternativeStep> alternatives) async {
    if (alternatives.isEmpty || !mounted) return null;
    return showModalBottomSheet<TodoGoalAlternativeStep>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('选择一个替代步骤加入今日行动', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _goalInk)),
            const SizedBox(height: 6),
            const Text('其他替代步骤会保存在AI复盘中作为备用。', style: TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 10),
            ...alternatives.map((a) => Card(
                  child: ListTile(
                    title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${a.actionWhen}\n${a.actionProcedure}\n产出：${a.actionOutput}', maxLines: 4, overflow: TextOverflow.ellipsis),
                    isThreeLine: true,
                    trailing: _ZoneChip(zone: a.zoneType, score: a.difficultyScore),
                    onTap: () => Navigator.pop(context, a),
                  ),
                )),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('暂不加入，先保存为备用')),
          ]),
        ),
      ),
    );
  }

  Future<void> _setGoalStatus(String status) async {
    final goal = _goal;
    if (goal == null || _busy) return;
    await _goalDao.updateGoalStatus(goal.goalId, status);
    if (status == 'archived' || status == 'deleted') {
      if (mounted) Navigator.pop(context);
      return;
    }
    await _load();
    _show(status == 'paused' ? '目标已暂停。暂停不是失败，今日行动将暂时隐藏。' : '目标已恢复，重新回到山路。');
  }

  Future<void> _editGoalAlignment() async {
    final goal = _goal;
    if (goal == null || _busy) return;
    final titleCtrl = TextEditingController(text: goal.goalTitle);
    final resultGoalCtrl = TextEditingController(text: goal.resultGoal);
    final valuesCtrl = TextEditingController(text: goal.coreValues);
    final valueGoalCtrl = TextEditingController(text: goal.valueGoal);
    final processGoalCtrl = TextEditingController(text: goal.processGoal);
    try {
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('让目标重新与真实自我对齐'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '目标名称', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: resultGoalCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '结果目标：山顶要达到什么', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: valuesCtrl, decoration: const InputDecoration(labelText: '核心价值（1-3个）', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: valueGoalCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '价值目标：为什么值得', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: processGoalCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '过程目标：想如何走这段山路', border: OutlineInputBorder())),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存调整')),
          ],
        ),
      );
      if (save != true) return;
      await _goalDao.updateGoalAlignment(
        goalId: goal.goalId,
        goalTitle: titleCtrl.text.trim().isEmpty ? goal.goalTitle : titleCtrl.text,
        resultGoal: resultGoalCtrl.text,
        coreValues: valuesCtrl.text,
        valueGoal: valueGoalCtrl.text,
        processGoal: processGoalCtrl.text,
      );
      await _load();
      _show('目标已重新绑定价值与过程。调整目标不是失败，而是重新对齐。');
    } finally {
      titleCtrl.dispose();
      resultGoalCtrl.dispose();
      valuesCtrl.dispose();
      valueGoalCtrl.dispose();
      processGoalCtrl.dispose();
    }
  }

  Future<void> _showPathRegretDialog() async {
    final goal = _goal;
    if (goal == null) return;
    final shouldRealign = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('路径后悔疏导'),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('当前山峰：${goal.goalTitle}', style: const TextStyle(fontWeight: FontWeight.w900, color: _goalInk)),
            const SizedBox(height: 10),
            const Text('先不要急着判断“我是不是选错了”。请用三个问题检查这条路是否还值得走一小段：', style: TextStyle(height: 1.45)),
            const SizedBox(height: 10),
            _MiniLine(label: '价值', text: '它是否仍然服务于你真正看重的成长、自由、关系、健康、创造或尊严？'),
            _MiniLine(label: '承诺', text: '你是否愿意先给它一个短周期承诺，而不是每天重新比较所有可能路径？'),
            _MiniLine(label: '过程', text: '你能否把下一步改小、换场景或换方法，让路上重新出现学习、掌控或意义？'),
            const SizedBox(height: 10),
            const Text('如果三个问题至少有一个仍然为“是”，建议先继续走一个最低版本；如果都是否定，就进入重新绑定价值与过程。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('先走最低版本')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('重新对齐目标')),
        ],
      ),
    );
    if (shouldRealign == true) await _editGoalAlignment();
  }

  Future<String?> _askText({required String title, required String hint}) async {
    final ctrl = TextEditingController();
    try {
      return showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: TextField(controller: ctrl, minLines: 2, maxLines: 5, decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder())),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('保存')),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }

  void _show(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red.shade700 : null));
  }

  @override
  Widget build(BuildContext context) {
    final goal = _goal;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('目标详情'),
        actions: [
          IconButton(onPressed: _busy || _sourceTask == null ? null : _reanalyze, tooltip: 'AI 重新分析目标卡', icon: const Icon(Icons.auto_awesome)),
          IconButton(onPressed: _busy || _sourceTask == null ? null : _generateProblemSolutions, tooltip: '单独生成AI问题解决方案', icon: const Icon(Icons.account_tree_outlined)),
          IconButton(onPressed: _busy ? null : _addTinyStep, tooltip: '新增最小行动', icon: const Icon(Icons.add_task_outlined)),
          PopupMenuButton<String>(
            tooltip: '调整目标',
            onSelected: (value) {
              if (value == 'align') _editGoalAlignment();
              if (value == 'regret') _showPathRegretDialog();
              if (value == 'pause') _setGoalStatus('paused');
              if (value == 'resume') _setGoalStatus('active');
              if (value == 'archive') _setGoalStatus('archived');
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'align', child: Text('重新绑定价值与过程')),
              const PopupMenuItem(value: 'regret', child: Text('路径后悔疏导')),
              PopupMenuItem(value: goal?.status == 'paused' ? 'resume' : 'pause', child: Text(goal?.status == 'paused' ? '恢复目标' : '暂停目标')),
              const PopupMenuItem(value: 'archive', child: Text('归档目标')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(_loadError, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700, height: 1.45)),
                  ),
                )
              : goal == null
                  ? const Center(child: Text('目标不存在或已删除。'))
                  : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  children: [
                    _GoalDetailHeader(goal: goal),
                    const SizedBox(height: 12),
                    _FourLayerGoalCard(goal: goal),
                    const SizedBox(height: 12),
                    _SelfConcordanceDiagnosisCard(goal: goal),
                    const SizedBox(height: 12),
                    _UserDecisionSupportCard(goal: goal, onRealign: _editGoalAlignment),
                    const SizedBox(height: 12),
                    _ContextualQuoteCard(momentTitle: '目标详情提示', momentKey: 'detail', seedOffset: goal.goalId.hashCode, quote: todoGoalQuoteForMoment('detail', seedOffset: goal.goalId.hashCode), actionText: todoGoalQuoteActionForMoment('detail')),
                    const SizedBox(height: 12),
                    if (goal.isLikelyFallbackAnalysis) ...[
                      _GoalFallbackNoticeCard(goal: goal),
                      const SizedBox(height: 12),
                    ],
                    _GoalPracticePanel(goal: goal, stepCount: _steps.length, openStepCount: _steps.where((s) => !s.isCompleted).length),
                    const SizedBox(height: 12),
                    _SolutionPlanBoard(
                      goalTitle: goal.goalTitle,
                      plans: _solutionPlans,
                      nodes: _selectedNodes,
                      onSelect: _selectSolutionPlan,
                      onActivateNode: _activateProblemNode,
                      onMarkNode: _markProblemNode,
                    ),
                    const SizedBox(height: 12),
                    _InfoBlock(title: '深层意义：这个目标为什么值得今天投入', text: goal.deepMeaning),
                    _InfoBlock(title: '身份方向：我正在成为怎样的人', text: goal.desiredIdentity),
                    _InfoBlock(title: '过程价值：沿途哪里值得体验', text: goal.processValue),
                    _InfoBlock(title: '可能阻力：哪里会把目标变成压力', text: goal.obstacleSummary),
                    const SizedBox(height: 14),
                    const _ThreeActionTypesCard(),
                    const SizedBox(height: 12),
                    const _SectionHeader(title: '行动步骤', subtitle: '每个目标同时保留结果型、过程型、价值型行动；不是只追结果，也不是只谈感受。'),
                    if (_steps.isEmpty) const _EmptyCard(text: '暂无行动步骤。'),
                    if (_steps.isNotEmpty)
                      _GoalStepTreeCard(
                        goalTitle: goal.goalTitle,
                        steps: _steps,
                        onTapStep: (s) => Navigator.push(context, MaterialPageRoute(builder: (_) => TodoGoalReviewPage(step: s))).then((_) => _load()),
                      ),
                  ],
                ),
    );
  }
}

class TodoGoalReviewPage extends StatefulWidget {
  const TodoGoalReviewPage({super.key, required this.step});
  final TodoGoalActionStep step;

  @override
  State<TodoGoalReviewPage> createState() => _TodoGoalReviewPageState();
}

class _TodoGoalReviewPageState extends State<TodoGoalReviewPage> {
  final _goalDao = TodoGoalDao();
  final _ai = TodoGoalAiService();
  final _reflectionCtrl = TextEditingController();
  final _whatCtrl = TextEditingController();
  final _obstacleCtrl = TextEditingController();
  bool _completed = true;
  String _resultStatus = 'success';
  bool _createNextStep = true;
  int _meaningScore = 3;
  int _processScore = 3;
  int _moodScore = 3;
  bool _busy = false;
  String _status = '';

  @override
  void dispose() {
    _reflectionCtrl.dispose();
    _whatCtrl.dispose();
    _obstacleCtrl.dispose();
    super.dispose();
  }

  String _dateAfterDays(int days) {
    final d = DateTime.now().add(Duration(days: days));
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '正在生成复盘...';
    });
    try {
      _completed = _resultStatus == 'success' || _resultStatus == 'minimum';
      final persistedStatus = switch (_resultStatus) {
        'success' || 'minimum' => 'completed',
        'partial' => 'partial',
        'blocked' => 'blocked',
        'adjust' => 'adjusted',
        _ => 'failed',
      };
      await _goalDao.updateStepStatus(widget.step.stepId, persistedStatus);
      final review = await _ai.generateDailyReview(
        goalTitle: widget.step.goalTitle,
        deepMeaning: widget.step.deepMeaning,
        processValue: widget.step.processValue,
        actionTitle: widget.step.title,
        completed: _completed,
        userReflection: _reflectionCtrl.text,
      );
      TodoGoalStepRecoveryResult? recovery;
      if (!_completed) {
        recovery = await _ai.generateStepRecovery(
          goalTitle: widget.step.goalTitle,
          deepMeaning: widget.step.deepMeaning,
          processValue: widget.step.processValue,
          actionTitle: widget.step.title,
          minimumStandard: widget.step.minimumStandard,
          userResult: _resultStatus,
          userReflection: _reflectionCtrl.text,
          obstacle: _obstacleCtrl.text,
        );
        await _goalDao.addStepReview(
          goalId: widget.step.goalId,
          stepId: widget.step.stepId,
          userResult: _resultStatus,
          userText: _reflectionCtrl.text.trim(),
          recovery: recovery,
        );
      }
      final recoveryAlternativesText = recovery == null
          ? ''
          : recovery.alternatives.map((e) => '• ${e.title}（${e.minimumStandard}）').join('\n');
      final recoveryText = recovery == null
          ? ''
          : '\n\n失败诊断：${recovery.failureDiagnosis}\n\n重启指导：${recovery.restartGuidance}\n\n替代步骤：$recoveryAlternativesText\n\n${recovery.restructureWarning}';
      final aiSummary = '${review.summary}\n\n过程洞察：${review.processInsight}\n\n意义连接：${review.meaningConnection}\n\n可选下一步：${review.nextStepOptions}\n\n暂定建议：${review.tomorrowNextStep}\n\n由你决定：${review.decisionPrompt}\n\n${review.encouragement}$recoveryText';
      await _goalDao.addReflection(
        goalId: widget.step.goalId,
        stepId: widget.step.stepId,
        whatDone: _whatCtrl.text.trim().isEmpty ? widget.step.title : _whatCtrl.text.trim(),
        whyDone: widget.step.deepMeaning,
        processExperience: _reflectionCtrl.text.trim(),
        obstacle: _obstacleCtrl.text.trim(),
        tomorrowNextStep: review.tomorrowNextStep,
        aiSummary: aiSummary,
        moodScore: _moodScore,
        meaningScore: _meaningScore,
        processScore: _processScore,
      );
      if (_createNextStep) {
        final alternative = recovery == null || recovery.alternatives.isEmpty ? null : await _chooseReviewAlternative(recovery.alternatives);
        final useReviewSuggestion = recovery == null ? await _confirmReviewSuggestion(review) : alternative != null;
        final nextTitle = alternative?.title ?? (useReviewSuggestion ? review.tomorrowNextStep.trim() : '');
        if (nextTitle.trim().isNotEmpty) {
          await _goalDao.createActionStep(
            goalId: widget.step.goalId,
            sourceTaskId: widget.step.sourceTaskId,
            title: nextTitle.trim(),
            minimumStandard: alternative?.minimumStandard ?? (_completed ? '明天先做2分钟，保持连续性。' : '明天只做2分钟，把行动重新降到可以开始。'),
            simplifiedStandard: '做5分钟，并留下一个事实记录。',
            recommendedStandard: alternative?.recommendedStandard ?? '完成一个小步骤，并记录一句过程体验。',
            stretchStandard: '如果状态允许，再推进到15-25分钟；连续失败时优先换备用步骤，不急于重构全方案。',
            difficultyScore: alternative?.difficultyScore ?? (_completed ? 4 : 2),
            zoneType: alternative?.zoneType ?? 'stretch',
            plannedDate: _dateAfterDays(1),
            parentStepId: widget.step.stepId,
            actionType: widget.step.actionType,
            experienceIntention: widget.step.experienceIntention,
          );
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '复盘保存失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmReviewSuggestion(TodoGoalReviewResult review) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('由你选择明日行动'),
            content: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (review.nextStepOptions.trim().isNotEmpty) _MiniLine(label: '可选方向', text: review.nextStepOptions),
                _MiniLine(label: 'AI 暂定建议', text: review.tomorrowNextStep),
                if (review.decisionPrompt.trim().isNotEmpty) _MiniLine(label: '请判断', text: review.decisionPrompt),
                const SizedBox(height: 8),
                const Text('接受只表示把它加入明日行动，不代表这是唯一正确选择。', style: TextStyle(color: Color(0xFF6B7280))),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('暂不采用')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('采用此建议')),
            ],
          ),
        ) ??
        false;
  }

  Future<TodoGoalAlternativeStep?> _chooseReviewAlternative(List<TodoGoalAlternativeStep> alternatives) async {
    if (alternatives.isEmpty || !mounted) return null;
    return showModalBottomSheet<TodoGoalAlternativeStep>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AI 提供的是参考，请由你选择', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _goalInk)),
            const SizedBox(height: 6),
            const Text('比较每个方案的理由、最低标准和难度。也可以暂不创建明日行动。', style: TextStyle(color: Color(0xFF6B7280), height: 1.4)),
            const SizedBox(height: 10),
            ...alternatives.map((option) => Card(
                  child: ListTile(
                    title: Text(option.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${option.actionWhen}\n${option.actionProcedure}\n产出：${option.actionOutput}', maxLines: 4, overflow: TextOverflow.ellipsis),
                    trailing: _ZoneChip(zone: option.zoneType, score: option.difficultyScore),
                    isThreeLine: true,
                    onTap: () => Navigator.pop(sheetContext, option),
                  ),
                )),
            TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('都不选，先保留复盘')),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('今日复盘')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _TodayStepCard(step: step, onToggle: null, onReview: null, onWriteBack: null),
          const SizedBox(height: 12),
          _ContextualQuoteCard(momentTitle: '填写前提示', momentKey: 'review', seedOffset: step.stepId.hashCode, quote: todoGoalQuoteForMoment('review', seedOffset: step.stepId.hashCode), actionText: todoGoalQuoteActionForMoment('review')),
          const SizedBox(height: 12),
          const _ReviewGuidanceCard(),
          const SizedBox(height: 12),
          _ResultStatusSelector(
            value: _resultStatus,
            onChanged: _busy ? null : (v) => setState(() {
              _resultStatus = v;
              _completed = v == 'success' || v == 'minimum';
            }),
          ),
          TextField(controller: _whatCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '今天我具体做了什么（事实，不评价）', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _reflectionCtrl, minLines: 3, maxLines: 8, decoration: const InputDecoration(labelText: '过程中有什么体验、阻力或一点进步（为沿途而活）', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _obstacleCtrl, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: '今天哪里把目标变成压力或逃避（可选）', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          _ScoreSelector(title: '方向清晰度', value: _meaningScore, onChanged: _busy ? null : (v) => setState(() => _meaningScore = v)),
          _ScoreSelector(title: '过程体验感', value: _processScore, onChanged: _busy ? null : (v) => setState(() => _processScore = v)),
          _ScoreSelector(title: '行动可持续感', value: _moodScore, onChanged: _busy ? null : (v) => setState(() => _moodScore = v)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _createNextStep,
            onChanged: _busy ? null : (v) => setState(() => _createNextStep = v),
            title: const Text('保存后自动生成明日最小一步'),
            subtitle: const Text('复盘不是结束，而是把今天的经验变成下一步设计。'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.auto_awesome), label: Text(_busy ? '正在保存...' : '生成 AI 复盘并落到明天')),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_status, style: TextStyle(color: _status.contains('失败') ? Colors.red.shade700 : const Color(0xFF6B7280))),
          ],
        ],
      ),
    );
  }
}



class _AiCoachConsoleCard extends StatelessWidget {
  const _AiCoachConsoleCard({required this.activeGoal, required this.onClarify, required this.onAction, required this.onReview, required this.onCompass, this.onOpenGoal});
  final TodoGoalProfile? activeGoal;
  final VoidCallback onClarify;
  final VoidCallback onAction;
  final VoidCallback onReview;
  final VoidCallback onCompass;
  final VoidCallback? onOpenGoal;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF5F3FF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.smart_toy_outlined, color: _goalBlue), SizedBox(width: 8), Text('AI 教练 · 目标对话', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _goalInk))]),
          const SizedBox(height: 8),
          Text(activeGoal == null ? '先创建或转化一个目标，再让 AI 教练围绕它进行澄清、拆解、复盘与调整。' : '当前主目标：${activeGoal!.goalTitle}', style: const TextStyle(color: Color(0xFF4B5563), height: 1.45, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _CoachModeTile(icon: Icons.search_outlined, title: '目标澄清', text: '从模糊愿望进入结果、价值、过程和今日行动。', onTap: onClarify),
          _CoachModeTile(icon: Icons.favorite_border, title: '价值追问', text: '检查目标是否自我一致，是否来自真实价值而非单纯比较。', onTap: onCompass),
          _CoachModeTile(icon: Icons.route_outlined, title: '行动拆解', text: '回到今天能开始的结果型、过程型、价值型行动。', onTap: onAction),
          _CoachModeTile(icon: Icons.healing_outlined, title: '阻碍分析 / 过程重构', text: '没完成时先缩小、换路径、换环境，而不是责备自己。', onTap: onReview),
          _CoachModeTile(icon: Icons.tune_outlined, title: '目标调整', text: '当目标不再自我一致时，暂停、恢复、归档或重新绑定价值。', onTap: onOpenGoal),
        ]),
      ),
    );
  }
}

class _CoachModeTile extends StatelessWidget {
  const _CoachModeTile({required this.icon, required this.title, required this.text, this.onTap});
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: _goalBlue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: _goalInk)),
      subtitle: Text(text, style: const TextStyle(height: 1.35)),
      trailing: const Icon(Icons.chevron_right),
      enabled: onTap != null,
      onTap: onTap,
    );
  }
}

class _PathRegretCoachingCard extends StatelessWidget {
  const _PathRegretCoachingCard();

  @override
  Widget build(BuildContext context) {
    return const _PlainValueCard(
      icon: Icons.compare_arrows_outlined,
      title: '路径后悔疏导',
      text: '当你怀疑“是不是选错目标”时，系统不会立刻推翻整座山，而是先检查：这条路是否仍符合价值、是否值得短期承诺、过程是否还能被改小或改得更有意义。',
    );
  }
}

class _ValuePracticeHeroCard extends StatelessWidget {
  const _ValuePracticeHeroCard({required this.onStartToday, required this.onTransform});
  final VoidCallback onStartToday;
  final VoidCallback onTransform;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF111827), Color(0xFF4F46E5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('把价值放进今天的行动', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('目标不是拿来解释的，而是拿来开始的。', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.25)),
        const SizedBox(height: 10),
        const Text('每个 To Do 都要经过三次落地：看见方向、压成最小行动、复盘出下一步。文字只在行动前出现，帮助你进入现实，而不是停留在理论。', style: TextStyle(color: Colors.white70, height: 1.55)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: onStartToday, icon: const Icon(Icons.play_arrow), label: const Text('开始今日行动')),
          OutlinedButton.icon(
            onPressed: onTransform,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('转化一个 To Do'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
          ),
        ]),
      ]),
    );
  }
}

class _TodayPracticeConsoleCard extends StatelessWidget {
  const _TodayPracticeConsoleCard({required this.goalCount, required this.actionCount, required this.completedCount});
  final int goalCount;
  final int actionCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF0FDF4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFBBF7D0))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('今日实践台', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _goalInk)),
          const SizedBox(height: 8),
          const Text('这些原则不再单独堆在页面里，而是通过今天是否产生行动来检验。', style: TextStyle(color: Color(0xFF4B5563), height: 1.45)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _MetricPill(label: '已校准目标', value: '$goalCount'),
            _MetricPill(label: '今日行动', value: '$actionCount'),
            _MetricPill(label: '已完成', value: '$completedCount'),
          ]),
          const SizedBox(height: 12),
          const _PracticeStepLine(index: 1, text: '选一个真实 To Do：它背后通向什么方向？'),
          const _PracticeStepLine(index: 2, text: '压成最低标准：现在 2-5 分钟能不能开始？'),
          const _PracticeStepLine(index: 3, text: '做完留痕：写下事实、过程体验和明日一步。'),
        ]),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFBBF7D0))),
      child: Text('$label $value', style: const TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w900)),
    );
  }
}

class _ActionizedValueMapCard extends StatelessWidget {
  const _ActionizedValueMapCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('价值如何被动作验证', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _goalInk)),
          const SizedBox(height: 6),
          const Text('每一句提醒都必须出现在某个具体时刻，并推动用户做一个动作。', style: TextStyle(color: Color(0xFF4B5563), height: 1.45)),
          const SizedBox(height: 10),
          ...todoGoalPracticeMap.map((p) => _PracticeMapTile(practice: p)),
        ]),
      ),
    );
  }
}

class _PracticeMapTile extends StatelessWidget {
  const _PracticeMapTile({required this.practice});
  final TodoGoalValuePractice practice;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(practice.title, style: const TextStyle(fontWeight: FontWeight.w900, color: _goalInk)),
        const SizedBox(height: 5),
        Text('出现时机：${practice.trigger}', style: const TextStyle(height: 1.38, color: Color(0xFF6B7280))),
        const SizedBox(height: 4),
        Text('用户动作：${practice.userAction}', style: const TextStyle(height: 1.38, color: Color(0xFF166534), fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('AI动作：${practice.aiAction}', style: const TextStyle(height: 1.38, color: Color(0xFF4338CA), fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _FiveQuestionPracticeCard extends StatelessWidget {
  const _FiveQuestionPracticeCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF4F6FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE0E7FF))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('今天只保留 5 个实践问题', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _goalInk)),
          const SizedBox(height: 10),
          ...List.generate(todoGoalTodayPracticeQuestions.length, (i) => _PracticeStepLine(index: i + 1, text: todoGoalTodayPracticeQuestions[i])),
        ]),
      ),
    );
  }
}

class _TransformPracticeCard extends StatelessWidget {
  const _TransformPracticeCard();

  @override
  Widget build(BuildContext context) {
    return const _PlainValueCard(
      icon: Icons.tune_outlined,
      title: '转化不是解释任务，而是重设行动方式',
      text: 'AI 必须输出一个今天可以开始的动作；如果只得到长篇道理、抽象意义或空泛目标，就说明转化失败，需要重新分析。',
    );
  }
}

class _GoalFallbackNoticeCard extends StatelessWidget {
  const _GoalFallbackNoticeCard({required this.goal});
  final TodoGoalProfile goal;

  @override
  Widget build(BuildContext context) {
    final model = goal.aiModelLabel.trim().isEmpty ? '当前AI配置' : goal.aiModelLabel.trim();
    return Card(
      elevation: 0,
      color: const Color(0xFFFFFBEB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFF59E0B))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
            SizedBox(width: 8),
            Expanded(child: Text('当前目标内容是本地兜底，不代表AI已成功深度分析', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF92400E)))),
          ]),
          const SizedBox(height: 8),
          Text('系统没有拿到可靠的结构化目标分析，因此先使用本地策略保证目标卡和今日行动可继续使用。问题解决方案已经拆为独立请求，可在目标详情页右上角单独生成，不受本次目标分析影响。', style: const TextStyle(height: 1.45, color: Color(0xFF78350F), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('建议：检查 API Key、模型、网络和JSON返回格式后，点击右上角“AI重新分析”。当前模型/来源：$model。', style: const TextStyle(height: 1.45, color: Color(0xFF92400E), fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _GoalPracticePanel extends StatelessWidget {
  const _GoalPracticePanel({required this.goal, required this.stepCount, required this.openStepCount});
  final TodoGoalProfile goal;
  final int stepCount;
  final int openStepCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF0FDF4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFBBF7D0))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('这个目标今天怎样实践', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _goalInk)),
          const SizedBox(height: 8),
          _MiniLine(label: '方向', text: goal.deepMeaning.trim().isEmpty ? '先补充：它通向哪种生活或能力。' : goal.deepMeaning),
          _MiniLine(label: '过程', text: goal.processValue.trim().isEmpty ? '先补充：今天行动中有什么可体验或练习。' : goal.processValue),
          _MiniLine(label: '行动状态', text: '已有 $stepCount 个行动步骤，其中 $openStepCount 个尚未完成。没有开放步骤时，请新增一个2-5分钟最小行动。'),
        ]),
      ),
    );
  }
}

class _PracticeStepLine extends StatelessWidget {
  const _PracticeStepLine({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 12, backgroundColor: const Color(0xFFDCFCE7), child: Text('$index', style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w900))),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(height: 1.42, color: Color(0xFF374151), fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _ValueSystemHeroCard extends StatelessWidget {
  const _ValueSystemHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF111827), Color(0xFF4F46E5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('目标价值核心主题', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
        SizedBox(height: 8),
        Text(todoGoalCentralTheme, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.25)),
        SizedBox(height: 10),
        Text(todoGoalSubTheme, style: TextStyle(color: Colors.white70, height: 1.55)),
      ]),
    );
  }
}

class _ValueSystemBriefCard extends StatelessWidget {
  const _ValueSystemBriefCard({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = compact ? todoGoalCoreValues.take(3).toList() : todoGoalCoreValues;
    return Card(
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('本模块必须始终落地的行动原则', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _goalInk)),
          const SizedBox(height: 8),
          const Text('不是多做任务，而是让任务回到生活方向、当下过程和真实行动。', style: TextStyle(color: Color(0xFF4B5563), height: 1.45)),
          const SizedBox(height: 10),
          ...items.map((p) => _ValueBullet(title: p.title, text: p.description)),
        ]),
      ),
    );
  }
}

class _ContextualQuoteCard extends StatefulWidget {
  const _ContextualQuoteCard({
    required this.momentTitle,
    required this.quote,
    this.actionText = '',
    this.momentKey = '',
    this.seedOffset = 0,
    this.rotateSeconds = 9,
  });

  final String momentTitle;
  final TodoGoalOriginalQuote quote;
  final String actionText;
  final String momentKey;
  final int seedOffset;
  final int rotateSeconds;

  @override
  State<_ContextualQuoteCard> createState() => _ContextualQuoteCardState();
}

class _ContextualQuoteCardState extends State<_ContextualQuoteCard> {
  Timer? _timer;
  late int _index;

  List<String> get _keys {
    final keys = todoGoalQuoteMomentKeys[widget.momentKey];
    if (keys == null || keys.isEmpty) return <String>[widget.quote.key];
    return keys;
  }

  @override
  void initState() {
    super.initState();
    _index = _initialIndex();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant _ContextualQuoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.momentKey != widget.momentKey ||
        oldWidget.seedOffset != widget.seedOffset ||
        oldWidget.rotateSeconds != widget.rotateSeconds) {
      _index = _initialIndex();
      _restartTimer();
    }
  }

  int _initialIndex() {
    final keys = _keys;
    if (keys.length <= 1) return 0;
    return todoGoalDailyQuoteSeed(extra: widget.seedOffset).abs() % keys.length;
  }

  void _restartTimer() {
    _timer?.cancel();
    final keys = _keys;
    if (keys.length <= 1) return;
    _timer = Timer.periodic(Duration(seconds: widget.rotateSeconds.clamp(4, 60).toInt()), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _keys.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keys = _keys;
    final quote = keys.isEmpty ? widget.quote : todoGoalQuoteFor(keys[_index % keys.length]);
    final actionText = widget.actionText;
    return Card(
      elevation: 0,
      color: const Color(0xFFFFFBEB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFFDE68A))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.lightbulb_outline, color: Color(0xFF92400E), size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.momentTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF92400E)))),
            if (keys.length > 1)
              Text('${(_index % keys.length) + 1}/${keys.length}', style: const TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: Column(
              key: ValueKey('${widget.momentKey}_${quote.key}_$_index'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quote.title, style: const TextStyle(fontWeight: FontWeight.w900, color: _goalInk, fontSize: 16)),
                const SizedBox(height: 6),
                Text('“${quote.translation}”', style: const TextStyle(height: 1.5, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (actionText.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.72), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFDE68A))),
              child: Text('现在应用：$actionText', style: const TextStyle(color: Color(0xFF92400E), height: 1.42, fontWeight: FontWeight.w800)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _CoreValuePrinciplesCard extends StatelessWidget {
  const _CoreValuePrinciplesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF4F6FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE0E7FF))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('6 条原则如何落到动作', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _goalInk)),
          const SizedBox(height: 10),
          ...todoGoalCoreValues.map((p) => _PrincipleTile(principle: p)),
        ]),
      ),
    );
  }
}

class _RealityLoopCard extends StatelessWidget {
  const _RealityLoopCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF0FDF4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFBBF7D0))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('现实落地闭环', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _goalInk)),
          const SizedBox(height: 10),
          ...List.generate(todoGoalRealityLoop.length, (i) => _NumberedLine(index: i + 1, text: todoGoalRealityLoop[i])),
        ]),
      ),
    );
  }
}

class _AiRoleCard extends StatelessWidget {
  const _AiRoleCard();

  @override
  Widget build(BuildContext context) {
    return const _PlainValueCard(
      icon: Icons.auto_awesome,
      title: 'AI 的角色不是催促，而是价值引导',
      text: 'AI 每次分析都必须追问：这个任务背后的方向是什么？它是否自我和谐？今天哪一小步能进入现实？过程里有什么值得体验？如果未完成，是任务设计需要调整，而不是简单责备用户。',
    );
  }
}

class _TodayValueChecklistCard extends StatelessWidget {
  const _TodayValueChecklistCard();

  @override
  Widget build(BuildContext context) {
    return const _PlainValueCard(
      icon: Icons.route_outlined,
      title: '今日行动判断标准',
      text: '一个合格的今日行动必须同时满足：有方向、有过程、有最低标准、在拉伸区、5分钟内可以开始。否则 AI 应继续拆小。',
    );
  }
}

class _ReviewValueChecklistCard extends StatelessWidget {
  const _ReviewValueChecklistCard();

  @override
  Widget build(BuildContext context) {
    return const _PlainValueCard(
      icon: Icons.psychology_alt_outlined,
      title: '复盘判断标准',
      text: '复盘不问“我是不是失败”，而问：目标有没有让我更投入今天？我体验到了什么？阻力在哪里？明天怎样更小一步继续？',
    );
  }
}

class _ReviewGuidanceCard extends StatelessWidget {
  const _ReviewGuidanceCard();

  @override
  Widget build(BuildContext context) {
    return const _PlainValueCard(
      icon: Icons.spa_outlined,
      title: '复盘时请回到过程本身',
      text: '“为沿途而活。” 今天的行动不只是为了打勾，而是为了看见：你是否更有方向地进入当下，是否从一个小过程里获得真实经验。',
    );
  }
}

class _ValueBullet extends StatelessWidget {
  const _ValueBullet({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle, size: 18, color: _goalBlue),
        const SizedBox(width: 8),
        Expanded(child: RichText(text: TextSpan(style: const TextStyle(color: Color(0xFF374151), height: 1.42), children: [
          TextSpan(text: '$title：', style: const TextStyle(fontWeight: FontWeight.w900, color: _goalInk)),
          TextSpan(text: text),
        ]))),
      ]),
    );
  }
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({required this.quote});
  final TodoGoalOriginalQuote quote;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.72), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(quote.title, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF92400E))),
        const SizedBox(height: 6),
        Text('“${quote.translation}”', style: const TextStyle(height: 1.5, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _PrincipleTile extends StatelessWidget {
  const _PrincipleTile({required this.principle});
  final TodoGoalValuePrinciple principle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0E7FF))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(principle.title, style: const TextStyle(fontWeight: FontWeight.w900, color: _goalInk)),
        const SizedBox(height: 5),
        Text(principle.description, style: const TextStyle(height: 1.42, color: Color(0xFF4B5563))),
        const SizedBox(height: 6),
        Text('AI 引导问题：${principle.actionQuestion}', style: const TextStyle(height: 1.42, color: Color(0xFF4338CA), fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _NumberedLine extends StatelessWidget {
  const _NumberedLine({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 12, backgroundColor: const Color(0xFFDCFCE7), child: Text('$index', style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w900))),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(height: 1.42, color: Color(0xFF374151))))
      ]),
    );
  }
}

class _GoalHeroCard extends StatelessWidget {
  const _GoalHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF22223B), Color(0xFF5E72C3)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('让目标回到当下', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        SizedBox(height: 8),
        Text('Microsoft To Do 负责记录任务；这里负责把任务转化为方向感、自我和谐、过程价值和今天5分钟内能开始的真实行动。', style: TextStyle(color: Colors.white70, height: 1.45)),
      ]),
    );
  }
}

class _TodayJourneyIntroCard extends StatelessWidget {
  const _TodayJourneyIntroCard();

  @override
  Widget build(BuildContext context) {
    return const _PlainValueCard(
      icon: Icons.explore_outlined,
      title: '今日旅程',
      text: '今天不是为了赶到终点。目标的作用，是让你知道自己为什么出发，并更好地投入眼前这一小步：看见方向、体验过程、完成一个足够小的真实行动。',
    );
  }
}

class _ReviewIntroCard extends StatelessWidget {
  const _ReviewIntroCard();

  @override
  Widget build(BuildContext context) {
    return const _PlainValueCard(
      icon: Icons.rate_review_outlined,
      title: '复盘与洞察',
      text: '复盘不是审判自己，而是把经历转化成自我理解：我做了什么、为什么做、过程中发生了什么、目标是否仍然自我和谐、明天如何更小一步继续。',
    );
  }
}

class _PlainValueCard extends StatelessWidget {
  const _PlainValueCard({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF4F6FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE0E7FF))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: _goalBlue, size: 30),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _goalInk)),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
          ])),
        ]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        if (subtitle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), height: 1.35))),
      ]),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});
  final TodoGoalProfile goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: _scoreColor(goal.selfConcordanceScore).withOpacity(0.12), child: Text('${goal.selfConcordanceScore}', style: TextStyle(color: _scoreColor(goal.selfConcordanceScore), fontWeight: FontWeight.w900))),
        title: Text(goal.goalTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${goal.goalCategory} · ${goal.goalOriginType} · ${goal.status == 'paused' ? '已暂停' : (goal.status == 'archived' ? '已归档' : '进行中')}\n过程幸福：${goal.processHappinessScore}/100 · ${goal.currentStage.trim().isEmpty ? '现实行动期' : goal.currentStage}\n沿途体验：${goal.processValue}', maxLines: 4, overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}


class _ManualGoalInputCard extends StatelessWidget {
  const _ManualGoalInputCard({
    required this.titleCtrl,
    required this.bodyCtrl,
    required this.whyCtrl,
    required this.ownershipCtrl,
    required this.changeCtrl,
    required this.processCtrl,
    required this.valuesCtrl,
    required this.busy,
    required this.onGenerate,
  });
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final TextEditingController whyCtrl;
  final TextEditingController ownershipCtrl;
  final TextEditingController changeCtrl;
  final TextEditingController processCtrl;
  final TextEditingController valuesCtrl;
  final bool busy;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF0FDF4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFBBF7D0))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.edit_note_outlined, color: Color(0xFF166534)),
            SizedBox(width: 8),
            Expanded(child: Text('直接输入一个目标或棘手问题', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _goalInk))),
          ]),
          const SizedBox(height: 6),
          const Text('不必先进入 Microsoft To Do。你可以直接输入“我现在最想解决的问题”，AI会先生成目标卡、价值诊断和今日最小行动；深度问题解决方案可在目标详情页单独生成。', style: TextStyle(color: Color(0xFF4B5563), height: 1.45)),
          const SizedBox(height: 12),
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: '目标/棘手问题', hintText: '例：我想坚持每天学习英语，但总是拖延', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: bodyCtrl,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: '背景、阻力或当前状态（可选）', hintText: '例：下班后很累，开始成本高，怕自己坚持不了', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('目标澄清五问', style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: const Text('填写越具体，AI越能判断目标是否真正属于你；可先回答最有感觉的问题。'),
            children: [
              _ClarificationField(controller: whyCtrl, label: '1. 你为什么想要这个目标？'),
              _ClarificationField(controller: ownershipCtrl, label: '2. 这是你真正想要的，还是别人期待的？'),
              _ClarificationField(controller: changeCtrl, label: '3. 实现后，你希望生活发生什么变化？'),
              _ClarificationField(controller: processCtrl, label: '4. 过程中，哪一部分是你愿意体验的？'),
              _ClarificationField(controller: valuesCtrl, label: '5. 它对应哪些价值？', hint: '成长、自由、安全、创造、关系、健康、贡献……'),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(onPressed: busy ? null : onGenerate, icon: const Icon(Icons.auto_awesome), label: const Text('AI生成目标卡')),
          ),
        ]),
      ),
    );
  }
}

class _CandidateTaskCard extends StatelessWidget {
  const _CandidateTaskCard({required this.task, required this.busy, required this.onTransform});
  final TodoTaskRecord task;
  final bool busy;
  final VoidCallback onTransform;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(task.isMyDay ? Icons.wb_sunny_outlined : Icons.check_circle_outline, color: _goalBlue),
            const SizedBox(width: 10),
            Expanded(child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
          ]),
          const SizedBox(height: 6),
          Text(task.listDisplayName.trim().isEmpty ? '列表：${task.listId}' : '列表：${task.listDisplayName}', style: const TextStyle(color: Color(0xFF6B7280))),
          if (task.bodyText.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(task.bodyText, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF4B5563)))),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: busy ? null : onTransform, icon: const Icon(Icons.auto_awesome), label: const Text('AI 转成可行动目标'))),
        ]),
      ),
    );
  }
}


class _JourneyRelationLegendCard extends StatelessWidget {
  const _JourneyRelationLegendCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.account_tree_outlined, color: _goalBlue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '关系读法：父目标是方向，父步骤说明这一步从哪里接续，今日行动是现在要做的最小实践。每次“缩小一步”或“复盘生成下一步”都会自动挂到原步骤下面。',
              style: TextStyle(color: Color(0xFF374151), height: 1.45, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TodayGoalTreeCard extends StatelessWidget {
  const _TodayGoalTreeCard({
    required this.goalTitle,
    required this.steps,
    required this.onToggle,
    required this.onStart,
    required this.onMakeSmaller,
    required this.onReview,
    required this.onWriteBack,
  });

  final String goalTitle;
  final List<TodoGoalActionStep> steps;
  final ValueChanged<TodoGoalActionStep> onToggle;
  final ValueChanged<TodoGoalActionStep> onStart;
  final ValueChanged<TodoGoalActionStep> onMakeSmaller;
  final ValueChanged<TodoGoalActionStep> onReview;
  final VoidCallback? Function(TodoGoalActionStep step) onWriteBack;

  @override
  Widget build(BuildContext context) {
    final ids = steps.map((s) => s.stepId).toSet();
    final childrenByParent = <String, List<TodoGoalActionStep>>{};
    for (final step in steps) {
      if (step.parentStepId.trim().isNotEmpty && step.parentStepId != step.stepId) {
        childrenByParent.putIfAbsent(step.parentStepId, () => <TodoGoalActionStep>[]).add(step);
      }
    }
    final roots = steps.where((s) => s.parentStepId.trim().isEmpty || !ids.contains(s.parentStepId)).toList();
    final completed = steps.where((s) => s.isCompleted).length;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFDDE3F8))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.flag_outlined, color: _goalBlue),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('父目标', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800)),
              Text(goalTitle, style: const TextStyle(fontSize: 18, color: _goalInk, fontWeight: FontWeight.w900, height: 1.25)),
              const SizedBox(height: 4),
              Text('今日 $completed / ${steps.length} 步完成', style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
            ])),
          ]),
          const SizedBox(height: 12),
          ...roots.map((step) => _TodayTreeStepNode(
                step: step,
                depth: step.stepLevel <= 1 ? 0 : step.stepLevel - 1,
                childrenByParent: childrenByParent,
                onToggle: onToggle,
                onStart: onStart,
                onMakeSmaller: onMakeSmaller,
                onReview: onReview,
                onWriteBack: onWriteBack,
              )),
        ]),
      ),
    );
  }
}

class _TodayTreeStepNode extends StatelessWidget {
  const _TodayTreeStepNode({
    required this.step,
    required this.depth,
    required this.childrenByParent,
    required this.onToggle,
    required this.onStart,
    required this.onMakeSmaller,
    required this.onReview,
    required this.onWriteBack,
  });

  final TodoGoalActionStep step;
  final int depth;
  final Map<String, List<TodoGoalActionStep>> childrenByParent;
  final ValueChanged<TodoGoalActionStep> onToggle;
  final ValueChanged<TodoGoalActionStep> onStart;
  final ValueChanged<TodoGoalActionStep> onMakeSmaller;
  final ValueChanged<TodoGoalActionStep> onReview;
  final VoidCallback? Function(TodoGoalActionStep step) onWriteBack;

  @override
  Widget build(BuildContext context) {
    final children = (childrenByParent[step.stepId] ?? const <TodoGoalActionStep>[]).where((s) => s.stepId != step.stepId).toList();
    final indent = (depth * 18.0).clamp(0.0, 90.0).toDouble();
    return Padding(
      padding: EdgeInsets.only(left: indent, top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(width: 2, height: 18, color: const Color(0xFFCBD5E1)),
            const Icon(Icons.subdirectory_arrow_right, size: 18, color: Color(0xFF64748B)),
          ]),
          const SizedBox(width: 8),
          Expanded(
            child: _TodayStepCard(
              step: step,
              showGoalSubtitle: false,
              onToggle: () => onToggle(step),
              onStart: () => onStart(step),
              onMakeSmaller: () => onMakeSmaller(step),
              onReview: () => onReview(step),
              onWriteBack: onWriteBack(step),
            ),
          ),
        ]),
        ...children.map((child) => _TodayTreeStepNode(
              step: child,
              depth: depth + 1,
              childrenByParent: childrenByParent,
              onToggle: onToggle,
              onStart: onStart,
              onMakeSmaller: onMakeSmaller,
              onReview: onReview,
              onWriteBack: onWriteBack,
            )),
      ]),
    );
  }
}

class _RelationPathCard extends StatelessWidget {
  const _RelationPathCard({required this.step});
  final TodoGoalActionStep step;

  @override
  Widget build(BuildContext context) {
    final parentTitle = step.hasParentStep ? step.parentLabel : step.goalTitle;
    final relationLabel = step.hasParentStep ? '接续父步骤' : '直属父目标';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.account_tree_outlined, color: Color(0xFF475569), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$relationLabel：$parentTitle\n当前位置：第 ${step.stepLevel <= 0 ? 1 : step.stepLevel} 层行动 → ${step.title}',
            style: const TextStyle(color: Color(0xFF475569), height: 1.35, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }
}

class _GoalStepTreeCard extends StatelessWidget {
  const _GoalStepTreeCard({required this.goalTitle, required this.steps, required this.onTapStep});
  final String goalTitle;
  final List<TodoGoalActionStep> steps;
  final ValueChanged<TodoGoalActionStep> onTapStep;

  @override
  Widget build(BuildContext context) {
    final ids = steps.map((s) => s.stepId).toSet();
    final childrenByParent = <String, List<TodoGoalActionStep>>{};
    for (final step in steps) {
      if (step.parentStepId.trim().isNotEmpty && step.parentStepId != step.stepId) {
        childrenByParent.putIfAbsent(step.parentStepId, () => <TodoGoalActionStep>[]).add(step);
      }
    }
    final roots = steps.where((s) => s.parentStepId.trim().isEmpty || !ids.contains(s.parentStepId)).toList();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.account_tree_outlined, color: _goalBlue),
            const SizedBox(width: 8),
            Expanded(child: Text('父目标：$goalTitle', style: const TextStyle(color: _goalInk, fontWeight: FontWeight.w900, fontSize: 16))),
          ]),
          const SizedBox(height: 8),
          const Text('从父目标向下看，每个子步骤都能看到自己承接的父步骤。这样复盘时就不会只看到零散任务，而能看见行动链条。', style: TextStyle(color: Color(0xFF6B7280), height: 1.4)),
          const SizedBox(height: 8),
          ...roots.map((s) => _GoalStepTreeNode(step: s, depth: 0, childrenByParent: childrenByParent, onTapStep: onTapStep)),
        ]),
      ),
    );
  }
}

class _GoalStepTreeNode extends StatelessWidget {
  const _GoalStepTreeNode({required this.step, required this.depth, required this.childrenByParent, required this.onTapStep});
  final TodoGoalActionStep step;
  final int depth;
  final Map<String, List<TodoGoalActionStep>> childrenByParent;
  final ValueChanged<TodoGoalActionStep> onTapStep;

  @override
  Widget build(BuildContext context) {
    final children = (childrenByParent[step.stepId] ?? const <TodoGoalActionStep>[]).where((s) => s.stepId != step.stepId).toList();
    final indent = (depth * 18.0).clamp(0.0, 90.0).toDouble();
    return Padding(
      padding: EdgeInsets.only(left: indent, top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.subdirectory_arrow_right, size: 18, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(child: _ActionStepListTile(step: step, onTap: () => onTapStep(step))),
        ]),
        ...children.map((child) => _GoalStepTreeNode(step: child, depth: depth + 1, childrenByParent: childrenByParent, onTapStep: onTapStep)),
      ]),
    );
  }
}

class _TodayStepCard extends StatelessWidget {
  const _TodayStepCard({required this.step, this.onToggle, this.onStart, this.onMakeSmaller, this.onReview, this.onWriteBack, this.showGoalSubtitle = true});
  final TodoGoalActionStep step;
  final VoidCallback? onToggle;
  final VoidCallback? onStart;
  final VoidCallback? onMakeSmaller;
  final VoidCallback? onReview;
  final VoidCallback? onWriteBack;
  final bool showGoalSubtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: onToggle,
              child: Icon(step.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, color: step.isCompleted ? Colors.green.shade700 : Colors.grey, size: 32),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(step.title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, decoration: step.isCompleted ? TextDecoration.lineThrough : null)),
                  _ActionTypeChip(actionType: step.actionType),
                ],
              ),
              if (showGoalSubtitle) ...[
                const SizedBox(height: 4),
                Text(step.goalTitle, style: const TextStyle(color: Color(0xFF6B7280))),
              ],
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _ZoneChip(zone: step.zoneType, score: step.difficultyScore),
              const SizedBox(height: 6),
              _StepStatusChip(status: step.status),
            ]),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBBF7D0))),
            child: const Text('实践顺序：先开始最低标准 → 观察过程体验 → 再决定是否继续。', style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w800, height: 1.35)),
          ),
          const SizedBox(height: 8),
          _RelationPathCard(step: step),
          if (step.minimumStandard.trim().isNotEmpty) _MiniLine(label: '最低版', text: step.minimumStandard),
          if (step.simplifiedStandard.trim().isNotEmpty) _MiniLine(label: '简化版', text: step.simplifiedStandard),
          if (step.recommendedStandard.trim().isNotEmpty) _MiniLine(label: '标准版', text: step.recommendedStandard),
          if (step.stretchStandard.trim().isNotEmpty) _MiniLine(label: '挑战版（可选）', text: step.stretchStandard),
          if (step.experienceIntention.trim().isNotEmpty) _MiniLine(label: '今日 AI 提问', text: step.experienceIntention),
          if (step.processValue.trim().isNotEmpty) _MiniLine(label: '做时观察', text: step.processValue),
          const SizedBox(height: 10),
          if (onStart != null || onMakeSmaller != null || onReview != null || onWriteBack != null)
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (onStart != null) FilledButton.icon(onPressed: step.isCompleted ? null : onStart, icon: const Icon(Icons.play_arrow), label: const Text('开始5分钟')),
              if (onMakeSmaller != null) OutlinedButton.icon(onPressed: step.isCompleted ? null : onMakeSmaller, icon: const Icon(Icons.remove_circle_outline), label: const Text('缩小一步')),
              if (onReview != null) OutlinedButton.icon(onPressed: onReview, icon: const Icon(Icons.rate_review_outlined), label: const Text('复盘生成下一步')),
              if (onWriteBack != null) OutlinedButton.icon(onPressed: onWriteBack, icon: Icon(step.writeBackToTodo ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined), label: Text(step.writeBackToTodo ? '已写回 To Do' : '写回 To Do')),
            ]),
        ]),
      ),
    );
  }
}

class _ActionStepListTile extends StatelessWidget {
  const _ActionStepListTile({required this.step, required this.onTap});
  final TodoGoalActionStep step;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final relationLine = step.hasParentStep ? '父步骤：${step.parentLabel}' : '父目标：${step.parentLabel}';
    final minimumLine = step.minimumStandard.isEmpty ? '开始5分钟即可' : step.minimumStandard;
    return Card(
      child: ListTile(
        leading: Icon(step.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, color: step.isCompleted ? Colors.green.shade700 : _goalBlue),
        title: Text(step.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${step.actionTypeLabel} · $relationLine\n最低版：$minimumLine'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}


class _SolutionPlanBoard extends StatelessWidget {
  const _SolutionPlanBoard({
    required this.goalTitle,
    required this.plans,
    required this.nodes,
    required this.onSelect,
    required this.onActivateNode,
    required this.onMarkNode,
  });

  final String goalTitle;
  final List<TodoGoalSolutionPlan> plans;
  final List<TodoGoalProblemNode> nodes;
  final ValueChanged<TodoGoalSolutionPlan> onSelect;
  final ValueChanged<TodoGoalProblemNode> onActivateNode;
  final void Function(TodoGoalProblemNode node, String status) onMarkNode;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return const _PlainValueCard(
        icon: Icons.account_tree_outlined,
        title: '还没有为这个目标设计行动路径',
        text: '点击右上角“问题树”，AI 会结合这个目标的现实处境，提出几条走法和可以先验证的小步骤。你可以比较、组合，也可以都不选。',
      );
    }
    final selectedPlans = plans.where((p) => p.isSelected).toList();
    final TodoGoalSolutionPlan? selected = selectedPlans.isEmpty ? null : selectedPlans.first;
    return Card(
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFDDE3F8))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.route_outlined, color: _goalBlue),
            const SizedBox(width: 8),
            Expanded(child: Text('怎样更实际地推进“$goalTitle”', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _goalInk))),
          ]),
          const SizedBox(height: 6),
          const Text('下面是几条不同的走法。先看哪一条更符合你现在的时间、资源和承受范围，再决定是否试一小步；选择后仍然可以调整。', style: TextStyle(color: Color(0xFF4B5563), height: 1.45)),
          const SizedBox(height: 12),
          ...plans.map((p) => _SolutionPlanCard(plan: p, onSelect: p.isSelected ? null : () => onSelect(p))),
          const SizedBox(height: 12),
          if (selected == null)
            const _EmptyCard(text: '先不用急着选。比较每条路是否适合你目前的现实条件，以及你愿意先承担哪一种成本，再选一条做小范围尝试。')
          else
            _ProblemNodeTreeCard(
              plan: selected,
              nodes: nodes,
              onActivateNode: onActivateNode,
              onMarkNode: onMarkNode,
            ),
        ]),
      ),
    );
  }
}

class _SolutionPlanCard extends StatelessWidget {
  const _SolutionPlanCard({required this.plan, required this.onSelect});
  final TodoGoalSolutionPlan plan;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final color = plan.zoneType == 'panic' ? Colors.red.shade700 : (plan.zoneType == 'comfort' ? Colors.grey.shade700 : _goalBlue);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: plan.isSelected ? color.withOpacity(0.45) : const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(plan.isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: color),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plan.title, style: const TextStyle(fontWeight: FontWeight.w900, color: _goalInk, fontSize: 16)),
              if (plan.methodName.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(_humanizeAiText(plan.methodName), style: TextStyle(color: color, fontWeight: FontWeight.w800)),
              ],
            ])),
            if (onSelect != null) TextButton(onPressed: onSelect, child: const Text('先试这条路')),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (plan.summary.trim().isNotEmpty) _FriendlyTextBlock(icon: Icons.route_outlined, title: '方案结论：怎样从现状走到目标', text: plan.summary),
            if (plan.evidencePlan.trim().isNotEmpty) _FriendlyTextBlock(icon: Icons.play_circle_outline, title: '第一轮需要验证什么', text: plan.evidencePlan),
            if (plan.successMetrics.trim().isNotEmpty) _FriendlyTextBlock(icon: Icons.visibility_outlined, title: '怎样知道它值得继续', text: plan.successMetrics),
            if (plan.riskNotes.trim().isNotEmpty) _FriendlyTextBlock(icon: Icons.warning_amber_outlined, title: '选择前需要考虑', text: plan.riskNotes),
          ]),
        ),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: const Text('为什么可能适合你', style: TextStyle(fontWeight: FontWeight.w800, color: _goalInk)),
          subtitle: const Text('展开查看判断依据；这些内容仍需要你结合实际确认。'),
          children: [
            if (plan.problemDefinition.trim().isNotEmpty) _MiniLine(label: 'AI理解的当前难题', text: plan.problemDefinition),
            if (plan.knownFacts.trim().isNotEmpty) _MiniLine(label: '从你的描述中能确认', text: plan.knownFacts),
            if (plan.keyAssumptions.trim().isNotEmpty) _MiniLine(label: '开始前还要问清', text: plan.keyAssumptions),
            if (plan.rootCauseAnalysis.trim().isNotEmpty) _MiniLine(label: '可能卡住你的地方', text: plan.rootCauseAnalysis),
            if (plan.optionComparison.trim().isNotEmpty) _MiniLine(label: '它更适合什么情况', text: plan.optionComparison),
            if (plan.stopConditions.trim().isNotEmpty) _MiniLine(label: '什么时候应该换路', text: plan.stopConditions),
            if (plan.userChoiceGuidance.trim().isNotEmpty) _MiniLine(label: '你可以怎样判断', text: plan.userChoiceGuidance),
          ],
        ),
      ]),
    );
  }
}

class _ProblemNodeTreeCard extends StatelessWidget {
  const _ProblemNodeTreeCard({required this.plan, required this.nodes, required this.onActivateNode, required this.onMarkNode});
  final TodoGoalSolutionPlan plan;
  final List<TodoGoalProblemNode> nodes;
  final ValueChanged<TodoGoalProblemNode> onActivateNode;
  final void Function(TodoGoalProblemNode node, String status) onMarkNode;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const _EmptyCard(text: '当前方案还没有问题树节点。请点击右上角“问题树”按钮单独重新生成方案。');
    }
    final ids = nodes.map((n) => n.nodeId).toSet();
    final childrenByParent = <String, List<TodoGoalProblemNode>>{};
    for (final node in nodes) {
      if (node.parentNodeId.trim().isNotEmpty && node.parentNodeId != node.nodeId) {
        childrenByParent.putIfAbsent(node.parentNodeId, () => <TodoGoalProblemNode>[]).add(node);
      }
    }
    final roots = nodes.where((n) => n.parentNodeId.trim().isEmpty || !ids.contains(n.parentNodeId)).toList();
    final nodesById = <String, TodoGoalProblemNode>{for (final node in nodes) node.nodeId: node};
    final completed = nodes.where((n) => n.isCompleted).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF4F6FF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0E7FF))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('解题过程：把“${plan.title}”逐层推导到现实动作', style: const TextStyle(fontWeight: FontWeight.w900, color: _goalInk, fontSize: 16)),
        const SizedBox(height: 4),
        Text('已解决 $completed / ${nodes.length} 个问题节点。请从没有未完成前置条件的最底层动作开始；叶节点成功后，再逐层评估父问题，直到根问题成立。', style: const TextStyle(color: Color(0xFF4B5563), height: 1.4)),
        const SizedBox(height: 8),
        ...roots.map((n) => _ProblemNodeTreeNode(
              node: n,
              depth: 0,
              childrenByParent: childrenByParent,
              nodesById: nodesById,
              onActivateNode: onActivateNode,
              onMarkNode: onMarkNode,
            )),
      ]),
    );
  }
}

class _ProblemNodeTreeNode extends StatelessWidget {
  const _ProblemNodeTreeNode({required this.node, required this.depth, required this.childrenByParent, required this.nodesById, required this.onActivateNode, required this.onMarkNode});
  final TodoGoalProblemNode node;
  final int depth;
  final Map<String, List<TodoGoalProblemNode>> childrenByParent;
  final Map<String, TodoGoalProblemNode> nodesById;
  final ValueChanged<TodoGoalProblemNode> onActivateNode;
  final void Function(TodoGoalProblemNode node, String status) onMarkNode;

  @override
  Widget build(BuildContext context) {
    final children = (childrenByParent[node.nodeId] ?? const <TodoGoalProblemNode>[]).where((n) => n.nodeId != node.nodeId).toList();
    final dependenciesReady = node.resolvedDependencyNodeIds.every((id) => nodesById[id]?.isCompleted == true);
    final dependencyTitles = node.resolvedDependencyNodeIds.map((id) => nodesById[id]?.title ?? '').where((title) => title.isNotEmpty).toList(growable: false);
    final parent = nodesById[node.parentNodeId];
    final siblings = <TodoGoalProblemNode>[];
    if (parent != null) siblings.addAll(childrenByParent[parent.nodeId] ?? const <TodoGoalProblemNode>[]);
    siblings.sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
    final previousSiblingsReady = parent?.relationType.toLowerCase() != 'sequence' || siblings.where((sibling) => sibling.sequenceOrder < node.sequenceOrder).every((sibling) => sibling.isCompleted);
    final childrenReady = children.isEmpty
        ? true
        : (node.relationType.toLowerCase() == 'or' ? children.any((child) => child.isCompleted) : children.every((child) => child.isCompleted));
    final ready = dependenciesReady && previousSiblingsReady && childrenReady;
    final indent = (depth * 16.0).clamp(0.0, 80.0).toDouble();
    return Padding(
      padding: EdgeInsets.only(left: indent, top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_nodeIcon(node), color: node.isCompleted ? Colors.green.shade700 : _goalBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(node.title, style: TextStyle(fontWeight: FontWeight.w900, color: _goalInk, decoration: node.isCompleted ? TextDecoration.lineThrough : null))),
              _NodeStatusChip(status: node.status),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                _LogicRelationChip(label: node.relationTypeLabel),
                if (node.resolvedDependencyNodeIds.isNotEmpty) _LogicRelationChip(label: '依赖 ${node.resolvedDependencyNodeIds.length} 个前置节点'),
                if (!ready && !node.isCompleted) const _LogicRelationChip(label: '等待前置问题完成', waiting: true),
              ]),
            ),
            if (dependencyTitles.isNotEmpty) _MiniLine(label: '还需要先完成', text: dependencyTitles.join('、')),
            if (node.description.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_humanizeAiText(node.description), style: const TextStyle(color: Color(0xFF4B5563), height: 1.4))),
            if (node.actionableStep.trim().isNotEmpty) _FriendlyTextBlock(icon: Icons.play_arrow_rounded, title: '现在可以做', text: node.actionableStep),
            if (node.isActionable && !node.hasConcreteActionContract)
              const _FriendlyTextBlock(icon: Icons.warning_amber_outlined, title: '这个旧节点还不能直接执行', text: '缺少时间、地点/工具、对象、操作步骤或产出物。请重新生成问题树，系统不会把抽象建议加入今日行动。'),
            if (node.isActionable) ...[
              if (node.actionWhen.trim().isNotEmpty) _MiniLine(label: '何时开始', text: node.actionWhen),
              if (node.actionWhere.trim().isNotEmpty) _MiniLine(label: '在哪里/用什么', text: node.actionWhere),
              if (node.actionObject.trim().isNotEmpty) _MiniLine(label: '具体处理什么', text: node.actionObject),
              if (node.actionProcedure.trim().isNotEmpty) _MiniLine(label: '按什么步骤做', text: node.actionProcedure),
              if (node.actionOutput.trim().isNotEmpty) _MiniLine(label: '必须留下什么', text: node.actionOutput),
            ],
            if (node.acceptanceCriteria.trim().isNotEmpty) _FriendlyTextBlock(icon: Icons.flag_outlined, title: '怎样算成功', text: node.acceptanceCriteria),
            if (node.completionNote.trim().isNotEmpty) _MiniLine(label: '我的记录', text: node.completionNote),
            if (node.logicQuestion.trim().isNotEmpty || node.knownFacts.trim().isNotEmpty || node.assumptions.trim().isNotEmpty || node.evidenceNeeded.trim().isNotEmpty || node.decisionRule.trim().isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 6),
                dense: true,
                title: const Text('为什么安排这一步', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                children: [
                  if (node.logicQuestion.trim().isNotEmpty) _MiniLine(label: '这一步要弄清', text: node.logicQuestion),
                  if (node.knownFacts.trim().isNotEmpty) _MiniLine(label: '目前知道', text: node.knownFacts),
                  if (node.assumptions.trim().isNotEmpty) _MiniLine(label: '还要确认', text: node.assumptions),
                  if (node.evidenceNeeded.trim().isNotEmpty) _MiniLine(label: '请留意或记录', text: node.evidenceNeeded),
                  if (node.decisionRule.trim().isNotEmpty) _MiniLine(label: '接下来怎么判断', text: node.decisionRule),
                ],
              ),
            if (node.aiReviewJson.trim().isNotEmpty) _NodeAiReviewBox(reviewJson: node.aiReviewJson),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (node.isActionable && children.isEmpty) OutlinedButton.icon(onPressed: node.isCompleted || !ready || !node.hasConcreteActionContract ? null : () => onActivateNode(node), icon: const Icon(Icons.add_task_outlined), label: const Text('加入今日行动')),
              OutlinedButton.icon(onPressed: node.isCompleted || !ready ? null : () => onMarkNode(node, 'completed'), icon: const Icon(Icons.check_circle_outline), label: const Text('成功')),
              OutlinedButton.icon(onPressed: node.isFailed || !ready ? null : () => onMarkNode(node, 'failed'), icon: const Icon(Icons.cancel_outlined), label: const Text('失败')),
            ]),
          ]),
        ),
        ...children.map((child) => _ProblemNodeTreeNode(
              node: child,
              depth: depth + 1,
              childrenByParent: childrenByParent,
              nodesById: nodesById,
              onActivateNode: onActivateNode,
              onMarkNode: onMarkNode,
            )),
      ]),
    );
  }

  IconData _nodeIcon(TodoGoalProblemNode n) {
    if (n.nodeType == 'action') return Icons.touch_app_outlined;
    if (n.nodeType == 'sub_problem') return Icons.subdirectory_arrow_right;
    return Icons.account_tree_outlined;
  }
}

class _LogicRelationChip extends StatelessWidget {
  const _LogicRelationChip({required this.label, this.waiting = false});
  final String label;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final color = waiting ? Colors.orange.shade800 : const Color(0xFF53639D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.2))),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

class _NodeAiReviewBox extends StatelessWidget {
  const _NodeAiReviewBox({required this.reviewJson});
  final String reviewJson;

  @override
  Widget build(BuildContext context) {
    String diagnosis = '';
    String guidance = '';
    final alternatives = <String>[];
    try {
      final decoded = jsonDecode(reviewJson);
      if (decoded is Map) {
        diagnosis = (decoded['failureDiagnosis'] ?? '').toString();
        guidance = (decoded['restartGuidance'] ?? '').toString();
        final rawAlternatives = decoded['alternatives'];
        if (rawAlternatives is List) {
          for (final item in rawAlternatives) {
            if (item is Map) {
              final title = (item['title'] ?? '').toString().trim();
              final min = (item['minimumStandard'] ?? '').toString().trim();
              if (title.isNotEmpty) alternatives.add(min.isEmpty ? title : '$title（$min）');
            }
          }
        }
      }
    } catch (_) {
      diagnosis = reviewJson;
    }
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('AI节点复盘与备用步骤', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF92400E))),
        if (diagnosis.trim().isNotEmpty) _MiniLine(label: '诊断', text: diagnosis),
        if (guidance.trim().isNotEmpty) _MiniLine(label: '重启', text: guidance),
        if (alternatives.isNotEmpty) _MiniLine(label: '备用步骤', text: alternatives.map((e) => '• $e').join('\n')),
      ]),
    );
  }
}

class _NodeStatusChip extends StatelessWidget {
  const _NodeStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final label = status == 'completed' ? '成功' : (status == 'failed' ? '失败' : (status == 'in_progress' ? '进行中' : '未开始'));
    final color = status == 'completed' ? Colors.green.shade700 : (status == 'failed' ? Colors.red.shade700 : (status == 'in_progress' ? Colors.orange.shade800 : Colors.grey.shade700));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.25))),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
    );
  }
}

class _GoalDetailHeader extends StatelessWidget {
  const _GoalDetailHeader({required this.goal});
  final TodoGoalProfile goal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFF22223B), borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(goal.goalTitle, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.25)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _WhiteChip('自我和谐 ${goal.selfConcordanceScore}'),
          const _WhiteChip('目标解放当下'),
          _WhiteChip(goal.goalCategory),
          _WhiteChip(goal.goalOriginType),
        ]),
      ]),
    );
  }
}

class _WhiteChip extends StatelessWidget {
  const _WhiteChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF8F8FB),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(text.trim().isEmpty ? '暂无。' : text, style: const TextStyle(height: 1.48, color: Color(0xFF374151))),
        ]),
      ),
    );
  }
}

class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({required this.reflection});
  final TodoGoalReflection reflection;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(reflection.goalTitle.trim().isEmpty ? '目标复盘' : reflection.goalTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          Text(reflection.reflectionDate, style: const TextStyle(color: Color(0xFF6B7280))),
          if (reflection.whatDone.trim().isNotEmpty) _MiniLine(label: '做了什么', text: reflection.whatDone),
          if (reflection.processExperience.trim().isNotEmpty) _MiniLine(label: '过程体验', text: reflection.processExperience),
          if (reflection.aiSummary.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(reflection.aiSummary, style: const TextStyle(height: 1.45))),
        ]),
      ),
    );
  }
}

String _humanizeAiText(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return '';
  try {
    final decoded = jsonDecode(text);
    return _decodedAiText(decoded);
  } catch (_) {
    // Older records may contain Dart-style Map/List strings. Convert the
    // direction objects that users previously saw as raw implementation data.
  }

  if (text.contains('direction:') || text.contains('applicableConditions:') || text.contains('costsAndRisks:')) {
    final options = <String>[];
    final objectPattern = RegExp(r'\{([^{}]+)\}');
    for (final match in objectPattern.allMatches(text)) {
      final body = match.group(1) ?? '';
      String field(String key) {
        final pattern = RegExp('$key' r':\s*(.*?)(?=,\s*(?:direction|applicableConditions|benefits|costsAndRisks):|$)');
        return (pattern.firstMatch(body)?.group(1) ?? '').trim();
      }
      final direction = field('direction');
      final conditions = field('applicableConditions');
      final benefits = field('benefits');
      final costs = field('costsAndRisks');
      if (direction.isEmpty && conditions.isEmpty && benefits.isEmpty && costs.isEmpty) continue;
      options.add(<String>[
        '${options.length + 1}. ${direction.isEmpty ? '一种可选路径' : direction}',
        if (conditions.isNotEmpty) '适合：$conditions',
        if (benefits.isNotEmpty) '可能收获：$benefits',
        if (costs.isNotEmpty) '需要考虑：$costs',
      ].join('\n'));
    }
    if (options.isNotEmpty) return options.join('\n\n');
  }

  text = text
      .replaceAll(RegExp(r'^\s*[\[\{]+'), '')
      .replaceAll(RegExp(r'[\]\}]+\s*$'), '')
      .replaceAll(RegExp(r'\bapplicableConditions\s*:'), '适合：')
      .replaceAll(RegExp(r'\bcostsAndRisks\s*:'), '需要考虑：')
      .replaceAll(RegExp(r'\bbenefits\s*:'), '可能收获：')
      .replaceAll(RegExp(r'\bdirection\s*:'), '')
      .replaceAll(RegExp(r'\},\s*\{'), '\n\n')
      .replaceAll(r'\n', '\n');
  return text.trim();
}

String _decodedAiText(dynamic value, {int depth = 0}) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is List) {
    final items = <String>[];
    for (var index = 0; index < value.length; index++) {
      final item = value[index];
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final direction = (map['direction'] ?? map['title'] ?? map['name'] ?? '').toString().trim();
        final conditions = (map['applicableConditions'] ?? map['conditions'] ?? '').toString().trim();
        final benefits = (map['benefits'] ?? map['possibleBenefits'] ?? '').toString().trim();
        final costs = (map['costsAndRisks'] ?? map['risks'] ?? '').toString().trim();
        items.add(<String>[
          '${index + 1}. ${direction.isEmpty ? '一种可选路径' : direction}',
          if (conditions.isNotEmpty) '适合：$conditions',
          if (benefits.isNotEmpty) '可能收获：$benefits',
          if (costs.isNotEmpty) '需要考虑：$costs',
        ].join('\n'));
      } else {
        final text = _decodedAiText(item, depth: depth + 1);
        if (text.isNotEmpty) items.add('${index + 1}. $text');
      }
    }
    return items.join('\n\n');
  }
  if (value is Map) {
    final readable = <String>[];
    for (final entry in value.entries) {
      final text = _decodedAiText(entry.value, depth: depth + 1);
      if (text.isNotEmpty) readable.add(text);
    }
    return readable.join('\n');
  }
  return value.toString();
}

String _firstReadableItem(String raw) {
  final text = _humanizeAiText(raw);
  if (text.isEmpty) return '';
  final lines = text.split(RegExp(r'[\n]+')).map((line) => line.replaceFirst(RegExp(r'^\s*(?:\d+[.、)]|[-•])\s*'), '').trim()).where((line) => line.isNotEmpty);
  if (lines.isEmpty) return '';
  final first = lines.first;
  final questionEnd = first.indexOf('？');
  return questionEnd >= 0 ? first.substring(0, questionEnd + 1) : first;
}

class _FriendlyTextBlock extends StatelessWidget {
  const _FriendlyTextBlock({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 19, color: _goalBlue),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: _goalInk)),
          const SizedBox(height: 3),
          Text(_humanizeAiText(text), style: const TextStyle(color: Color(0xFF374151), height: 1.45)),
        ])),
      ]),
    );
  }
}

class _MiniLine extends StatelessWidget {
  const _MiniLine({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xFF374151), height: 1.35),
          children: [
            TextSpan(text: '$label：', style: const TextStyle(fontWeight: FontWeight.w900, color: _goalInk)),
            TextSpan(text: _humanizeAiText(text)),
          ],
        ),
      ),
    );
  }
}

class _ActionTypeChip extends StatelessWidget {
  const _ActionTypeChip({required this.actionType});
  final String actionType;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (actionType) {
      'process' => ('过程型', const Color(0xFF0F766E)),
      'value' => ('价值型', const Color(0xFFB45309)),
      _ => ('结果型', _goalBlue),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.35))),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }
}

class _ThreeActionTypesCard extends StatelessWidget {
  const _ThreeActionTypesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('三类行动：同时推进未来与当下', style: TextStyle(fontWeight: FontWeight.w900, color: _goalInk)),
          SizedBox(height: 8),
          _MiniLine(label: '结果型', text: '直接产生可验证进展，回答“我向山顶推进了什么”。'),
          _MiniLine(label: '过程型', text: '刻意体验学习、投入、勇气或掌控感，回答“今天如何攀登”。'),
          _MiniLine(label: '价值型', text: '把行动与真正看重的生活连接，回答“这一步为什么值得”。'),
        ]),
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  const _ZoneChip({required this.zone, required this.score});
  final String zone;
  final int score;

  @override
  Widget build(BuildContext context) {
    final label = zone == 'panic' ? '恐慌区' : (zone == 'comfort' ? '舒适区' : '拉伸区');
    final color = zone == 'panic' ? Colors.red.shade700 : (zone == 'comfort' ? Colors.grey.shade700 : _goalBlue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.25))),
      child: Text('$label $score', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF9FAFB),
      child: Padding(padding: const EdgeInsets.all(18), child: Text(text, style: const TextStyle(color: Color(0xFF6B7280)))),
    );
  }
}



class _ResultStatusSelector extends StatelessWidget {
  const _ResultStatusSelector({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('这个节点/步骤的实际结果', style: TextStyle(fontWeight: FontWeight.w900, color: _goalInk)),
          const SizedBox(height: 6),
          const Text('如实选择今天走到了哪里。没有完美完成也不等于失败；系统会据此保留成果、缩小行动或调整山路。', style: TextStyle(color: Color(0xFF6B7280), height: 1.4)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(label: const Text('已完成'), selected: value == 'success', onSelected: onChanged == null ? null : (_) => onChanged!('success')),
            ChoiceChip(label: const Text('完成最低版'), selected: value == 'minimum', onSelected: onChanged == null ? null : (_) => onChanged!('minimum')),
            ChoiceChip(label: const Text('做了一部分'), selected: value == 'partial', onSelected: onChanged == null ? null : (_) => onChanged!('partial')),
            ChoiceChip(label: const Text('遇到阻碍'), selected: value == 'blocked', onSelected: onChanged == null ? null : (_) => onChanged!('blocked')),
            ChoiceChip(label: const Text('今天需调整'), selected: value == 'adjust', onSelected: onChanged == null ? null : (_) => onChanged!('adjust')),
          ]),
        ]),
      ),
    );
  }
}

class _ScoreSelector extends StatelessWidget {
  const _ScoreSelector({required this.title, required this.value, required this.onChanged});
  final String title;
  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$title：$value/5', style: const TextStyle(fontWeight: FontWeight.w900, color: _goalInk)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: List.generate(5, (i) {
            final v = i + 1;
            return ChoiceChip(
              label: Text('$v'),
              selected: value == v,
              onSelected: onChanged == null ? null : (_) => onChanged!(v),
            );
          }),
        ),
      ]),
    );
  }
}

class _StepStatusChip extends StatelessWidget {
  const _StepStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'completed' => '已完成',
      'partial' => '完成部分',
      'blocked' => '遇到阻碍',
      'adjusted' => '需要调整',
      'failed' => '未完成',
      'in_progress' => '进行中',
      _ => '未开始',
    };
    final color = switch (status) {
      'completed' => Colors.green.shade700,
      'partial' => Colors.blue.shade700,
      'blocked' || 'failed' => Colors.red.shade700,
      'adjusted' || 'in_progress' => Colors.orange.shade800,
      _ => Colors.grey.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.25))),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Row(children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(child: Text(status.trim().isEmpty ? '正在处理...' : status)),
        ]),
      ),
    );
  }
}

Color _scoreColor(int score) {
  if (score >= 80) return Colors.green.shade700;
  if (score >= 60) return _goalBlue;
  if (score >= 40) return Colors.orange.shade800;
  return Colors.red.shade700;
}

class _TodayClimbDashboard extends StatelessWidget {
  const _TodayClimbDashboard({
    required this.goal,
    required this.step,
    required this.completedCount,
    required this.onStart,
    required this.onCreateGoal,
  });

  final TodoGoalProfile? goal;
  final TodoGoalActionStep? step;
  final int completedCount;
  final VoidCallback onStart;
  final VoidCallback onCreateGoal;

  @override
  Widget build(BuildContext context) {
    final activeGoal = goal;
    final todayStep = step;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF29386D), Color(0xFF6879C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x3329386D), blurRadius: 18, offset: Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.landscape_outlined, color: Colors.white),
          SizedBox(width: 8),
          Text('今日攀登', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        const Text('幸福不是站在山顶，而是朝山顶攀登的体验。', style: TextStyle(color: Color(0xFFE8ECFF), height: 1.4)),
        const SizedBox(height: 18),
        if (activeGoal == null) ...[
          const Text('还没有正在攀登的山峰', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('输入一个愿望或同步一条 To Do，AI 会先澄清价值，再生成今天能开始的一小步。', style: TextStyle(color: Color(0xFFDCE3FF), height: 1.45)),
        ] else ...[
          Text(activeGoal.goalTitle, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            activeGoal.valueGoal.trim().isEmpty ? activeGoal.deepMeaning : activeGoal.valueGoal,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFDCE3FF), height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('今天只需要完成', style: TextStyle(color: Color(0xFFC9D3FF), fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(todayStep?.title ?? '为这座山峰生成一个 2 分钟最低版本', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(
                todayStep?.processValue.trim().isNotEmpty == true ? todayStep!.processValue : activeGoal.processValue,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFE5E9FF), height: 1.35),
              ),
              if (todayStep?.actionPlace.trim().isNotEmpty == true || todayStep?.startTrigger.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  [
                    if (todayStep!.actionPlace.trim().isNotEmpty) '地点：${todayStep!.actionPlace}',
                    if (todayStep!.startTrigger.trim().isNotEmpty) '启动：${todayStep.startTrigger}',
                  ].join(' · '),
                  style: const TextStyle(color: Color(0xFFC9D3FF), fontSize: 12),
                ),
              ],
            ]),
          ),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF33427D)),
              onPressed: activeGoal == null ? onCreateGoal : onStart,
              icon: Icon(activeGoal == null ? Icons.add : Icons.hiking),
              label: Text(activeGoal == null ? '创建第一座山峰' : '开始攀登'),
            ),
          ),
          const SizedBox(width: 10),
          Text('今日已走 $completedCount 步', style: const TextStyle(color: Color(0xFFDCE3FF), fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

class _UserDecisionSupportCard extends StatelessWidget {
  const _UserDecisionSupportCard({required this.goal, required this.onRealign});
  final TodoGoalProfile goal;
  final VoidCallback onRealign;

  @override
  Widget build(BuildContext context) {
    final hasContent = goal.userNeedInterpretation.trim().isNotEmpty || goal.possibleDirections.trim().isNotEmpty || goal.userDecisionPrompt.trim().isNotEmpty;
    if (!hasContent) return const SizedBox.shrink();
    final firstQuestion = _firstReadableItem(goal.clarifyingQuestions);
    return Card(
      elevation: 0,
      color: const Color(0xFFFFFBEB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFF3D9A4))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.explore_outlined, color: Color(0xFFB45309)),
            SizedBox(width: 8),
            Expanded(child: Text('先确认：这是不是你真正想解决的？', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _goalInk))),
          ]),
          const SizedBox(height: 8),
          if (goal.userNeedInterpretation.trim().isNotEmpty)
            Text(_humanizeAiText(goal.userNeedInterpretation), style: const TextStyle(color: Color(0xFF78350F), height: 1.5)),
          if (firstQuestion.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF3D9A4))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('先回答这一个问题', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF92400E))),
                const SizedBox(height: 6),
                Text(firstQuestion, style: const TextStyle(color: _goalInk, height: 1.45, fontSize: 16)),
              ]),
            ),
          ],
          if (goal.keyUncertainties.trim().isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('AI 还不了解哪些现实情况', style: TextStyle(fontWeight: FontWeight.w800, color: _goalInk)),
              children: [Align(alignment: Alignment.centerLeft, child: Text(_humanizeAiText(goal.keyUncertainties), style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)))],
            ),
          if (goal.possibleDirections.trim().isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('看看几种不同的走法', style: TextStyle(fontWeight: FontWeight.w800, color: _goalInk)),
              subtitle: const Text('不是让你立刻选，只是帮助你打开思路。'),
              children: [Align(alignment: Alignment.centerLeft, child: Text(_humanizeAiText(goal.possibleDirections), style: const TextStyle(color: Color(0xFF374151), height: 1.55)))],
            ),
          if (goal.referenceCases.trim().isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('看看别人可能怎样判断', style: TextStyle(fontWeight: FontWeight.w800, color: _goalInk)),
              children: [Align(alignment: Alignment.centerLeft, child: Text(_humanizeAiText(goal.referenceCases), style: const TextStyle(color: Color(0xFF374151), height: 1.55)))],
            ),
          if (goal.recommendationRationale.trim().isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('如果想先试一步', style: TextStyle(fontWeight: FontWeight.w800, color: _goalInk)),
              children: [Align(alignment: Alignment.centerLeft, child: Text(_humanizeAiText(goal.recommendationRationale), style: const TextStyle(color: Color(0xFF374151), height: 1.55)))],
            ),
          if (goal.userDecisionPrompt.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_humanizeAiText(goal.userDecisionPrompt), style: const TextStyle(fontWeight: FontWeight.w800, color: _goalInk, height: 1.45)),
          ],
          const SizedBox(height: 12),
          FilledButton.tonalIcon(onPressed: onRealign, icon: const Icon(Icons.edit_outlined), label: const Text('按我的实际情况调整目标')),
        ]),
      ),
    );
  }
}

class _FourLayerGoalCard extends StatelessWidget {
  const _FourLayerGoalCard({required this.goal});
  final TodoGoalProfile goal;

  @override
  Widget build(BuildContext context) {
    final layers = <(IconData, String, String)>[
      (Icons.flag_outlined, '山顶 · 结果目标', goal.resultGoal.trim().isEmpty ? goal.goalTitle : goal.resultGoal),
      (Icons.explore_outlined, '价值 · 为什么值得', goal.valueGoal.trim().isEmpty ? goal.deepMeaning : goal.valueGoal),
      (Icons.route_outlined, '山路 · 过程目标', goal.processGoal.trim().isEmpty ? goal.processValue : goal.processGoal),
      (Icons.directions_walk_outlined, '风景 · 当下体验', goal.processValue),
    ];
    return Card(
      elevation: 0,
      color: const Color(0xFFF7F8FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFDDE2FF))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('山路地图', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _goalInk)),
          const SizedBox(height: 12),
          ...layers.map((layer) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFE8ECFF), borderRadius: BorderRadius.circular(10)), child: Icon(layer.$1, color: _goalBlue, size: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(layer.$2, style: const TextStyle(fontWeight: FontWeight.w800, color: _goalInk)),
                    const SizedBox(height: 3),
                    Text(layer.$3.trim().isEmpty ? '等待进一步澄清' : layer.$3, style: const TextStyle(color: Color(0xFF4B5563), height: 1.4)),
                  ])),
                ]),
              )),
        ]),
      ),
    );
  }
}

class _SelfConcordanceDiagnosisCard extends StatelessWidget {
  const _SelfConcordanceDiagnosisCard({required this.goal});
  final TodoGoalProfile goal;

  @override
  Widget build(BuildContext context) {
    final metrics = <(String, int)>[
      ('自主性', goal.autonomyScore),
      ('价值一致', goal.valueAlignmentScore),
      ('兴趣连接', goal.interestConnectionScore),
      ('热情', goal.passionScore),
      ('现实可行', goal.feasibilityScore),
      ('过程幸福', goal.processHappinessScore),
      ('外部压力', goal.externalPressureScore),
    ];
    final values = goal.coreValueList;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('目标体检 · 自我一致性', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            Chip(label: Text(goal.goalType.trim().isEmpty ? '待持续校准' : goal.goalType)),
          ]),
          const SizedBox(height: 4),
          Text('当前阶段：${goal.currentStage.trim().isEmpty ? '现实行动验证期' : goal.currentStage}', style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 14),
          ...metrics.map((metric) {
            final isPressure = metric.$1 == '外部压力';
            final score = metric.$2 == 0 ? (isPressure ? 100 - goal.selfConcordanceScore : goal.selfConcordanceScore) : metric.$2;
            final color = isPressure ? (score >= 70 ? Colors.red : Colors.orange) : _scoreColor(score);
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(children: [
                SizedBox(width: 72, child: Text(metric.$1, style: const TextStyle(fontWeight: FontWeight.w700))),
                Expanded(child: LinearProgressIndicator(value: score / 100, minHeight: 8, borderRadius: BorderRadius.circular(99), color: color, backgroundColor: color.withOpacity(0.12))),
                const SizedBox(width: 9),
                SizedBox(width: 30, child: Text('$score', textAlign: TextAlign.right, style: TextStyle(color: color, fontWeight: FontWeight.w900))),
              ]),
            );
          }),
          if (values.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 7, runSpacing: 7, children: values.map((value) => Chip(avatar: const Icon(Icons.explore, size: 16), label: Text(value))).toList()),
          ],
          if (goal.needsRealignment || goal.lacksProcessDesign) ...[
            const SizedBox(height: 8),
            Text(
              goal.needsRealignment ? '这个目标的外部压力较高。建议先缩短承诺周期，并重新确认它是否仍服务于你的真实价值。' : '这个目标缺少可享受、可观察的过程设计。建议把下一步改写为一个能体验学习、勇气或掌控感的动作。',
              style: TextStyle(color: Colors.orange.shade900, height: 1.4, fontWeight: FontWeight.w600),
            ),
          ],
        ]),
      ),
    );
  }
}

class _ClarificationField extends StatelessWidget {
  const _ClarificationField({required this.controller, required this.label, this.hint = ''});
  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: 3,
        decoration: InputDecoration(labelText: label, hintText: hint.isEmpty ? null : hint, border: const OutlineInputBorder()),
      ),
    );
  }
}

class _ValueCompassCard extends StatelessWidget {
  const _ValueCompassCard({required this.goals, required this.values});
  final List<TodoGoalProfile> goals;
  final List<MapEntry<String, int>> values;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF0FDF4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFBBF7D0))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.explore_outlined, color: Color(0xFF166534)), SizedBox(width: 8), Text('价值罗盘', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _goalInk))]),
          const SizedBox(height: 6),
          const Text('每个目标绑定的价值，会在这里形成你当前的人生方向地图。', style: TextStyle(color: Color(0xFF4B5563), height: 1.4)),
          const SizedBox(height: 14),
          if (values.isEmpty)
            const Text('还没有价值数据。创建目标时回答“目标澄清五问”，或重新分析已有目标。', style: TextStyle(color: Color(0xFF6B7280)))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values.map((entry) => Chip(avatar: const Icon(Icons.navigation_outlined, size: 16), label: Text('${entry.key} · ${entry.value} 个目标'))).toList(),
            ),
          const SizedBox(height: 14),
          ...goals.take(5).map((goal) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(child: Text(goal.goalTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text('${goal.selfConcordanceScore}', style: TextStyle(color: _scoreColor(goal.selfConcordanceScore), fontWeight: FontWeight.w900)),
                ]),
              )),
        ]),
      ),
    );
  }
}

class _WeeklyMeaningCard extends StatelessWidget {
  const _WeeklyMeaningCard({
    required this.reflectionCount,
    required this.actionCount,
    required this.completedCount,
    required this.meaningAverage,
    required this.processAverage,
    required this.moodAverage,
    required this.alignedGoals,
    required this.pressureGoals,
    required this.aiSummary,
    required this.busy,
    required this.onGenerate,
  });
  final int reflectionCount;
  final int actionCount;
  final int completedCount;
  final double meaningAverage;
  final double processAverage;
  final double moodAverage;
  final int alignedGoals;
  final int pressureGoals;
  final TodoGoalWeeklySummaryResult? aiSummary;
  final bool busy;
  final VoidCallback onGenerate;

  String _score(double value) => value == 0 ? '暂无' : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final insight = pressureGoals > 0
        ? '有 $pressureGoals 个目标外部压力偏高。下周优先降低强度、缩短承诺周期，或重新确认价值。'
        : (reflectionCount == 0 ? '完成一次行动后复盘，才能看见过程幸福的真实证据。' : '本周已有 $reflectionCount 次过程记录。继续保留带来意义感和投入感的行动方式。');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE0E7FF))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('本周过程总结', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _goalInk)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _MetricPill(label: '行动', value: '$completedCount/$actionCount'),
            _MetricPill(label: '复盘', value: '$reflectionCount'),
            _MetricPill(label: '意义感', value: _score(meaningAverage)),
            _MetricPill(label: '过程感', value: _score(processAverage)),
            _MetricPill(label: '情绪', value: _score(moodAverage)),
            _MetricPill(label: '自我一致目标', value: '$alignedGoals'),
          ]),
          const SizedBox(height: 12),
          Text(insight, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (aiSummary == null)
            OutlinedButton.icon(onPressed: busy ? null : onGenerate, icon: const Icon(Icons.auto_awesome), label: const Text('AI生成本周深度总结'))
          else ...[
            _MiniLine(label: '自我一致', text: aiSummary!.alignmentInsight),
            _MiniLine(label: '过程幸福', text: aiSummary!.processInsight),
            _MiniLine(label: '价值证据', text: aiSummary!.valueEvidence),
            _MiniLine(label: '需要调整', text: aiSummary!.adjustmentAdvice),
            _MiniLine(label: '下周重点', text: aiSummary!.nextWeekFocus),
            TextButton.icon(onPressed: busy ? null : onGenerate, icon: const Icon(Icons.refresh), label: const Text('重新生成')),
          ],
        ]),
      ),
    );
  }
}
