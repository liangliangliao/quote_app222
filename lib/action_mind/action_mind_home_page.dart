import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'action_mind_ai_service.dart';
import 'action_mind_dao.dart';
import 'action_mind_models.dart';
import '../pages/ai_prompt_settings_page.dart';

class ActionMindHomePage extends StatefulWidget {
  final String initialInput;
  final String initialScene;

  const ActionMindHomePage({
    super.key,
    this.initialInput = '',
    this.initialScene = 'wish_start',
  });

  @override
  State<ActionMindHomePage> createState() => _ActionMindHomePageState();
}

class _ActionMindHomePageState extends State<ActionMindHomePage> with SingleTickerProviderStateMixin {
  final ActionMindDao _dao = ActionMindDao();
  final ActionMindAiService _ai = ActionMindAiService();

  late final TabController _tabController;
  final TextEditingController _inputCtrl = TextEditingController();
  final TextEditingController _dailyGoalCtrl = TextEditingController();
  final TextEditingController _dailyEmotionCtrl = TextEditingController();
  final TextEditingController _dailyEnergyCtrl = TextEditingController();
  final TextEditingController _dailyObstacleCtrl = TextEditingController();
  final TextEditingController _valuesCtrl = TextEditingController();
  final TextEditingController _identityCtrl = TextEditingController();
  final TextEditingController _domainsCtrl = TextEditingController();
  final TextEditingController _intrinsicCtrl = TextEditingController();
  final TextEditingController _externalCtrl = TextEditingController();
  final TextEditingController _defenseCtrl = TextEditingController();
  final TextEditingController _emotionPatternCtrl = TextEditingController();
  final TextEditingController _cueCtrl = TextEditingController();
  final TextEditingController _socialCtrl = TextEditingController();

  bool _loading = true;
  bool _generating = false;
  String _scene = 'wish_start';
  String _outputMode = 'common';
  ActionMindProfile _profile = const ActionMindProfile();
  List<ActionMindSession> _sessions = const <ActionMindSession>[];
  List<ActionMindGoal> _goals = const <ActionMindGoal>[];
  List<ActionMindPlan> _plans = const <ActionMindPlan>[];
  List<ActionMindEmotionLog> _emotions = const <ActionMindEmotionLog>[];
  List<ActionMindReview> _reviews = const <ActionMindReview>[];
  List<ActionMindToolRun> _toolRuns = const <ActionMindToolRun>[];
  List<ActionMindDailyCard> _dailyCards = const <ActionMindDailyCard>[];
  List<ActionMindLifeSnapshot> _lifeSnapshots = const <ActionMindLifeSnapshot>[];
  ActionMindStats _stats = const ActionMindStats();
  ActionMindSession? _latest;

  static const Map<String, String> _sceneLabels = <String, String>{
    'wish_start': '愿望启动',
    'procrastination': '拖延诊断',
    'failure': '失败/想放弃',
    'emotion': '情绪信号',
    'long_goal': '长期目标',
    'fantasy': '愿景-现实对照',
    'habit': '习惯/诱惑',
    'social': '社会互动',
    'goal_conflict': '多目标内耗',
    'review': '行动复盘',
    'daily_cockpit': '今日驾驶舱',
    'weekly_system': '周目标系统',
  };

  static const List<String> _quickInputs = <String>[
    '我想变得更自律，但总是拖延，一开始就想刷手机。',
    '我想考研/学习成功，但一想到失败就焦虑，所以一直准备不起来。',
    '我想赚钱，但我也担心这个目标只是为了证明自己。',
    '我和同事沟通很容易防御，我想表达清楚但又怕被否定。',
    '我目标太多，健身、学习、赚钱、关系都想要，最后什么都推进不了。',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _scene = _sceneLabels.containsKey(widget.initialScene) ? widget.initialScene : 'wish_start';
    _inputCtrl.text = widget.initialInput.trim().isEmpty ? _quickInputs.first : widget.initialInput.trim();
    _dailyGoalCtrl.text = '推进一个真正重要的目标';
    _dailyEmotionCtrl.text = '焦虑/抗拒/不确定';
    _dailyEnergyCtrl.text = '6/10，可用 25 分钟';
    _dailyObstacleCtrl.text = '手机诱惑、完美主义和启动困难';
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inputCtrl.dispose();
    _dailyGoalCtrl.dispose();
    _dailyEmotionCtrl.dispose();
    _dailyEnergyCtrl.dispose();
    _dailyObstacleCtrl.dispose();
    _valuesCtrl.dispose();
    _identityCtrl.dispose();
    _domainsCtrl.dispose();
    _intrinsicCtrl.dispose();
    _externalCtrl.dispose();
    _defenseCtrl.dispose();
    _emotionPatternCtrl.dispose();
    _cueCtrl.dispose();
    _socialCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _dao.ensureTables();
      final profile = await _dao.loadProfile();
      final sessions = await _dao.listSessions(limit: 100);
      final goals = await _dao.listGoals(limit: 100);
      final plans = await _dao.listPlans(limit: 100);
      final emotions = await _dao.listEmotions(limit: 80);
      final reviews = await _dao.listReviews(limit: 80);
      final toolRuns = await _dao.listToolRuns(limit: 120);
      final dailyCards = await _dao.listDailyCards(limit: 60);
      final lifeSnapshots = await _dao.listLifeSnapshots(limit: 40);
      final stats = await _dao.stats();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _sessions = sessions;
        _goals = goals;
        _plans = plans;
        _emotions = emotions;
        _reviews = reviews;
        _toolRuns = toolRuns;
        _dailyCards = dailyCards;
        _lifeSnapshots = lifeSnapshots;
        _stats = stats;
        _latest = sessions.isNotEmpty ? sessions.first : null;
        _valuesCtrl.text = profile.coreValues.join('，');
        _identityCtrl.text = profile.identityDirection;
        _domainsCtrl.text = profile.lifeDomains;
        _intrinsicCtrl.text = profile.intrinsicAnchor;
        _externalCtrl.text = profile.externalPressures;
        _defenseCtrl.text = profile.commonDefenses;
        _emotionPatternCtrl.text = profile.commonEmotions;
        _cueCtrl.text = profile.environmentCues;
        _socialCtrl.text = profile.socialPatterns;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('加载 ActionMind 失败：$e');
    }
  }

  Future<void> _saveProfile() async {
    final values = _valuesCtrl.text
        .split(RegExp(r'[,，;；\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final profile = ActionMindProfile(
      coreValues: values,
      identityDirection: _identityCtrl.text.trim(),
      lifeDomains: _domainsCtrl.text.trim(),
      intrinsicAnchor: _intrinsicCtrl.text.trim(),
      externalPressures: _externalCtrl.text.trim(),
      commonDefenses: _defenseCtrl.text.trim(),
      commonEmotions: _emotionPatternCtrl.text.trim(),
      environmentCues: _cueCtrl.text.trim(),
      socialPatterns: _socialCtrl.text.trim(),
    );
    await _dao.saveProfile(profile);
    await _load();
    _toast('ActionMind 档案已保存');
  }

  Future<void> _generate({String? forceScene, String? forceInput, String? forceOutputMode}) async {
    if (_generating) return;
    final scene = forceScene ?? _scene;
    final input = (forceInput ?? _inputCtrl.text).trim();
    if (input.isEmpty) {
      _toast('请先输入真实目标、情绪或行动场景');
      return;
    }
    setState(() => _generating = true);
    try {
      final recent = await _dao.recentContextJson();
      final goals = await _dao.goalsContextJson();
      final record = await _ai.generate(
        scene: scene,
        userInput: input,
        profile: _profile,
        recentContextJson: recent,
        goalsJson: goals,
        outputMode: forceOutputMode ?? _outputMode,
      );
      await _dao.insertSession(record);
      await _load();
      if (mounted) _tabController.animateTo(1);
    } catch (e) {
      _toast('AI 生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _dailyCockpit() async {
    if (_generating) return;
    final input = '''今日主目标：${_dailyGoalCtrl.text.trim()}
当前情绪：${_dailyEmotionCtrl.text.trim()}
能量/可用时间：${_dailyEnergyCtrl.text.trim()}
最大障碍：${_dailyObstacleCtrl.text.trim()}''';
    setState(() => _generating = true);
    try {
      final recent = await _dao.recentContextJson();
      final goals = await _dao.goalsContextJson();
      final record = await _ai.generate(
        scene: 'daily_cockpit',
        userInput: input,
        profile: _profile,
        recentContextJson: recent,
        goalsJson: goals,
        outputMode: 'common',
      );
      await _dao.insertSession(record);
      await _dao.insertDailyCard(ActionMindDailyCard(
        dateKey: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        mainGoal: _dailyGoalCtrl.text.trim(),
        emotion: _dailyEmotionCtrl.text.trim(),
        energy: _dailyEnergyCtrl.text.trim(),
        obstacle: _dailyObstacleCtrl.text.trim(),
        ifThen: record.plan.ifThen,
        minimumAction: record.plan.minimumAction,
        standardAction: record.plan.standardAction,
        challengeAction: record.plan.challengeAction,
        recoveryAction: record.emotionHandling,
        aiResponse: record.aiResponse,
      ));
      await _load();
      if (mounted) _tabController.animateTo(0);
      _toast('今日行动卡已生成并保存');
    } catch (e) {
      _toast('生成今日行动卡失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _openPromptSettings() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const AiPromptSettingsPage(
        initialModuleId: 'action_mind',
        initialPromptId: 'am_global_value',
      ),
    ));
  }


  Future<void> _runToolWorkflow({
    required String toolId,
    required String title,
    required String scene,
    required String sample,
    String outputMode = 'common',
  }) async {
    final inputCtrl = TextEditingController(text: sample);
    final extraCtrl = TextEditingController();
    var mode = outputMode;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('这个工具会作为独立工作流记录保存，并进入后续目标系统上下文。', style: TextStyle(color: Colors.grey.shade700, height: 1.45)),
                const SizedBox(height: 10),
                _dialogField(inputCtrl, '你的真实情况 / 目标 / 障碍', 7),
                _dialogField(extraCtrl, '补充：资源、时间、他人、环境线索、失败记录等（可空）', 4),
                Row(children: [
                  const Text('输出深度：', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: mode,
                    items: const [
                      DropdownMenuItem(value: 'quick', child: Text('快速')),
                      DropdownMenuItem(value: 'common', child: Text('标准')),
                      DropdownMenuItem(value: 'deep', child: Text('深度')),
                    ],
                    onChanged: (v) => setDialogState(() => mode = v ?? 'common'),
                  ),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('生成并保存工作流')),
          ],
        ),
      ),
    );
    final main = inputCtrl.text.trim();
    final extra = extraCtrl.text.trim();
    inputCtrl.dispose();
    extraCtrl.dispose();
    if (ok != true || main.isEmpty) return;
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final recent = await _dao.recentContextJson();
      final goalsJson = await _dao.goalsContextJson();
      final composedInput = extra.isEmpty ? main : '$main\n\n补充上下文：$extra';
      final session = await _ai.generate(
        scene: scene,
        userInput: composedInput,
        profile: _profile,
        recentContextJson: recent,
        goalsJson: goalsJson,
        outputMode: mode,
      );
      await _dao.insertSession(session);
      if (session.plan.hasPlan) {
        await _dao.insertPlan(session.plan.copyWith(goalId: 0, status: 'active'));
      }
      await _dao.insertToolRun(ActionMindToolRun(
        toolId: toolId,
        scene: scene,
        title: title,
        userInput: composedInput,
        aiResponse: session.aiResponse,
        extractedGoal: session.rewrittenGoal,
        extractedPlan: session.plan.ifThen,
        nextAction: session.finalAction,
      ));
      if (scene == 'emotion') {
        await _dao.insertEmotion(ActionMindEmotionLog(
          emotion: _lineOrFallback(session.emotionHandling, '情绪', '情绪信号'),
          trigger: main,
          blockedGoal: session.targetClarification,
          signal: session.emotionHandling,
          recoveryAction: '慢呼气 6 次，写下“我现在能控制的一件事”。',
          nextAction: session.finalAction,
        ));
      }
      if (scene == 'weekly_system' || scene == 'goal_conflict') {
        await _dao.insertLifeSnapshot(ActionMindLifeSnapshot(
          periodKey: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          identityDirection: _profile.identityDirection,
          primaryGoal: _lineOrFallback(session.aiResponse, '主线目标', session.rewrittenGoal),
          supportingGoals: _lineOrFallback(session.aiResponse, '支持目标', ''),
          conflictGoals: _lineOrFallback(session.aiResponse, '冲突目标', session.realityObstacle),
          pausedGoals: _lineOrFallback(session.aiResponse, '暂停目标', ''),
          lowMaintenanceGoals: _lineOrFallback(session.aiResponse, '低维护目标', ''),
          weeklyFocus: session.finalAction,
          aiResponse: session.aiResponse,
        ));
      }
      await _load();
      if (mounted) {
        _latest = session;
        _tabController.animateTo(1);
      }
      _toast('$title 已生成并保存');
    } catch (e) {
      _toast('$title 生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _runTool(String scene, String input, {String outputMode = 'common'}) async {
    setState(() {
      _scene = scene;
      _inputCtrl.text = input;
      _outputMode = outputMode;
    });
    await _generate(forceScene: scene, forceInput: input, forceOutputMode: outputMode);
  }

  String _goalsSummaryText() {
    final active = _goals.where((g) => g.isActive).take(8).map((g) {
      return '- ${g.title}: 来源=${g.goalSource}; 价值=${g.valueLayer}; 障碍=${g.obstacles}; 行动=${g.actionLayer}';
    }).join('\n');
    final recentReviews = _reviews.take(6).map((r) => '- ${r.completed ? '完成' : '未完成'}：${r.gap} / 学到=${r.learned} / 下一次=${r.nextIfThen}').join('\n');
    final emotions = _emotions.take(6).map((e) => '- ${e.emotion}: ${e.signal}; 目标=${e.blockedGoal}').join('\n');
    return '核心价值：${_profile.coreValues.join('、')}\n身份方向：${_profile.identityDirection}\n生活任务：${_profile.lifeDomains}\n活跃目标：\n${active.isEmpty ? '暂无' : active}\n近期情绪：\n${emotions.isEmpty ? '暂无' : emotions}\n近期复盘：\n${recentReviews.isEmpty ? '暂无' : recentReviews}';
  }

  Future<void> _createGoalDialog() async {
    final rawCtrl = TextEditingController(text: _inputCtrl.text.trim());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 创建目标画像'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: rawCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '输入一个愿望/长期目标/想改变的方向',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('生成并保存')),
        ],
      ),
    );
    final raw = rawCtrl.text.trim();
    rawCtrl.dispose();
    if (ok != true || raw.isEmpty) return;
    setState(() => _generating = true);
    try {
      final recent = await _dao.recentContextJson();
      final goalsJson = await _dao.goalsContextJson();
      final session = await _ai.generate(
        scene: 'wish_start',
        userInput: raw,
        profile: _profile,
        recentContextJson: recent,
        goalsJson: goalsJson,
        outputMode: 'json',
      );
      await _dao.insertSession(session);
      final value = _extractValue(session.rewrittenGoal);
      final goal = ActionMindGoal(
        title: _cleanTitle(raw),
        rawWish: raw,
        deepGoal: session.targetClarification,
        goalSource: _lineOrFallback(session.targetClarification, '目标来源', '自主/外部/自尊防御等来源待继续验证'),
        intrinsicExternal: _lineOrFallback(session.targetClarification, '内在/外在', '内在与外在目标混合，需要持续校准'),
        approachAvoidance: _lineOrFallback(session.targetClarification, '接近/回避', '接近/回避倾向待观察'),
        idealOught: _lineOrFallback(session.targetClarification, '理想/应该', '理想/应该自我待观察'),
        identityLayer: '我想成为能够自主选择目标并稳定行动的人。',
        valueLayer: value,
        projectLayer: session.rewrittenGoal,
        actionLayer: session.plan.minimumAction,
        obstacles: session.realityObstacle,
        conflicts: '与时间、能量、外部评价或其他目标的冲突待复盘确认。',
        autonomyScore: 6,
        meaningScore: 7,
        feasibilityScore: 6,
        resourceFitScore: 6,
      );
      final id = await _dao.insertGoal(goal);
      if (session.plan.hasPlan) await _dao.insertPlan(session.plan.copyWith(goalId: id));
      await _load();
      if (mounted) _tabController.animateTo(2);
      _toast('目标画像与执行意图已保存');
    } catch (e) {
      _toast('创建目标失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }


  Future<void> _createManualPlanDialog({int goalId = 0, String seed = ''}) async {
    final triggerCtrl = TextEditingController(text: seed.isEmpty ? '我坐到书桌前/晚饭后/早上洗漱后' : seed);
    final actionCtrl = TextEditingController(text: '打开任务并做 5 分钟最低行动');
    final obstacleCtrl = TextEditingController(text: '如果出现抗拒或完美主义，我就只完成最低行动，不评价人格。');
    final temptationCtrl = TextEditingController(text: '如果想刷手机，我就把手机放到房间外并倒一杯水。');
    final minCtrl = TextEditingController(text: '做 5 分钟或完成一个最小可见动作');
    final stdCtrl = TextEditingController(text: '专注 25 分钟并留下一个可见产出');
    final chalCtrl = TextEditingController(text: '完成一个完整小成果并记录复盘');
    final cueCtrl = TextEditingController(text: '把工具提前放到眼前，把诱惑移出启动环境');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建 if–then 执行意图'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(children: [
              _dialogField(triggerCtrl, '如果出现这个情境 X', 2),
              _dialogField(actionCtrl, '我就执行这个行为 Y', 2),
              _dialogField(obstacleCtrl, '障碍应对计划', 3),
              _dialogField(temptationCtrl, '诱惑替代计划', 3),
              _dialogField(minCtrl, '最低行动', 2),
              _dialogField(stdCtrl, '标准行动', 2),
              _dialogField(chalCtrl, '挑战行动', 2),
              _dialogField(cueCtrl, '环境线索设计', 2),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.insertPlan(ActionMindPlan(
        goalId: goalId,
        trigger: triggerCtrl.text.trim(),
        action: actionCtrl.text.trim(),
        obstaclePlan: obstacleCtrl.text.trim(),
        temptationPlan: temptationCtrl.text.trim(),
        minimumAction: minCtrl.text.trim(),
        standardAction: stdCtrl.text.trim(),
        challengeAction: chalCtrl.text.trim(),
        environmentCue: cueCtrl.text.trim(),
        status: 'active',
      ));
      await _load();
      _toast('执行意图已保存');
    }
    triggerCtrl.dispose();
    actionCtrl.dispose();
    obstacleCtrl.dispose();
    temptationCtrl.dispose();
    minCtrl.dispose();
    stdCtrl.dispose();
    chalCtrl.dispose();
    cueCtrl.dispose();
  }

  Future<void> _changeGoalStatus(ActionMindGoal goal, String status) async {
    await _dao.updateGoalStatus(goal.id, status);
    await _load();
    _toast('目标状态已更新为 $status');
  }

  Future<void> _deleteGoalConfirm(ActionMindGoal goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除目标画像？'),
        content: Text('将删除“${goal.title}”。执行意图和复盘不会自动删除，便于保留行动历史。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.deleteGoal(goal.id);
      await _load();
      _toast('目标画像已删除');
    }
  }

  Future<void> _saveSessionPlan(ActionMindSession session) async {
    if (!session.plan.hasPlan) {
      _toast('当前记录没有可保存的执行意图');
      return;
    }
    await _dao.insertPlan(session.plan.copyWith(goalId: 0, status: 'active'));
    await _load();
    _toast('已保存到 if–then 执行意图库');
  }

  Future<void> _recordEmotionDialog() async {
    final emotionCtrl = TextEditingController(text: '焦虑');
    final triggerCtrl = TextEditingController(text: '想到一个重要目标还没有推进');
    final goalCtrl = TextEditingController(text: _goals.isNotEmpty ? _goals.first.title : '重要目标');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('记录情绪信号'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(children: [
              _dialogField(emotionCtrl, '情绪名称', 1),
              _dialogField(triggerCtrl, '触发情境', 3),
              _dialogField(goalCtrl, '关联/受阻目标', 2),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true) {
      final emotion = emotionCtrl.text.trim().isEmpty ? '情绪' : emotionCtrl.text.trim();
      final trigger = triggerCtrl.text.trim();
      final goal = goalCtrl.text.trim();
      final signal = _emotionSignal(emotion);
      await _dao.insertEmotion(ActionMindEmotionLog(
        emotion: emotion,
        trigger: trigger,
        blockedGoal: goal,
        signal: signal,
        recoveryAction: '慢呼气 6 次，写下“我现在能控制的一件事”。',
        nextAction: '把目标缩小到 3–5 分钟可开始的动作。',
      ));
      await _load();
      _toast('情绪信号已记录');
    }
    emotionCtrl.dispose();
    triggerCtrl.dispose();
    goalCtrl.dispose();
  }

  Future<void> _reviewPlan(ActionMindPlan plan, {required bool completed}) async {
    final gapCtrl = TextEditingController(text: completed ? '已完成最低/标准行动。' : '计划没有启动或只完成了一部分。');
    final causeCtrl = TextEditingController(text: completed ? '情境线索有效，行动足够小。' : '可能是目标太大、资源不足、情绪阻碍、环境诱惑或启动情境不清。');
    final emotionCtrl = TextEditingController(text: completed ? '完成后更有掌控感。' : '出现了自责/焦虑/抗拒，但这是信息，不是人格失败。');
    final learnedCtrl = TextEditingController(text: completed ? 'if–then 有帮助，可以重复。' : '下一次需要缩小行动或换一个更明确情境。');
    final nextCtrl = TextEditingController(text: plan.obstaclePlan.isEmpty ? plan.ifThen : plan.obstaclePlan);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(completed ? '完成复盘' : '没做到也复盘'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(children: [
              _dialogField(gapCtrl, '实际发生了什么/差距是什么？', 3),
              _dialogField(causeCtrl, '差距原因：目标/计划/资源/情绪/环境/他人/习惯？', 3),
              _dialogField(emotionCtrl, '情绪反馈', 3),
              _dialogField(learnedCtrl, '学到了什么？', 3),
              _dialogField(nextCtrl, '下一次 if–then', 3),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存复盘')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.insertReview(ActionMindReview(
        goalId: plan.goalId,
        planId: plan.id,
        completed: completed,
        gap: gapCtrl.text.trim(),
        cause: causeCtrl.text.trim(),
        emotionFeedback: emotionCtrl.text.trim(),
        learned: learnedCtrl.text.trim(),
        nextIfThen: nextCtrl.text.trim(),
      ));
      await _load();
      _toast('复盘已保存');
    }
    gapCtrl.dispose();
    causeCtrl.dispose();
    emotionCtrl.dispose();
    learnedCtrl.dispose();
    nextCtrl.dispose();
  }

  String _cleanTitle(String raw) {
    final t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length > 24 ? t.substring(0, 24) : t;
  }

  String _lineOrFallback(String text, String key, String fallback) {
    for (final line in text.split('\n')) {
      if (line.contains(key)) return line.trim();
    }
    return fallback;
  }

  String _extractValue(String text) {
    final values = _profile.coreValues.isEmpty ? <String>['成长'] : _profile.coreValues;
    for (final v in values) {
      if (text.contains(v)) return v;
    }
    return values.first;
  }

  String _emotionSignal(String emotion) {
    if (emotion.contains('焦虑') || emotion.contains('害怕')) return '未来威胁、责任压力或控制感不足。';
    if (emotion.contains('沮丧') || emotion.contains('难过')) return '目标进展慢、理想目标受挫。';
    if (emotion.contains('愤怒') || emotion.contains('生气')) return '边界被侵犯或目标被阻碍。';
    if (emotion.contains('羞耻') || emotion.contains('内疚')) return '自我评价受到威胁，需要区分事实与人格审判。';
    if (emotion.contains('空虚')) return '目标可能过度外在化或意义连接不足。';
    if (emotion.contains('厌烦')) return '任务挑战/反馈不匹配。';
    return '某个目标正在被激活或受阻，需要转化为信息。';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  String _fmt(int ms) {
    if (ms <= 0) return '';
    return DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('ActionMind · 行动心理学', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(icon: const Icon(Icons.tune), tooltip: '配置 ActionMind AI 提示词', onPressed: _openPromptSettings),
          IconButton(icon: const Icon(Icons.refresh), tooltip: '刷新', onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '今日'),
            Tab(text: 'AI教练'),
            Tab(text: '目标地图'),
            Tab(text: '情绪资源'),
            Tab(text: '执行意图'),
            Tab(text: '工具箱'),
            Tab(text: '生活系统'),
            Tab(text: '复盘档案'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTodayTab(),
                _buildCoachTab(),
                _buildGoalsTab(),
                _buildEmotionTab(),
                _buildPlansTab(),
                _buildToolsTab(),
                _buildLifeSystemTab(),
                _buildArchiveTab(),
              ],
            ),
    );
  }

  Widget _buildTodayTab() {
    final activePlans = _plans.where((p) => p.status == 'active').toList(growable: false);
    return _scroll(children: [
      _heroCard(),
      _sectionCard(
        title: '今日行动驾驶舱',
        subtitle: '把主目标、情绪、能量、障碍放在同一个行动系统里。',
        icon: Icons.dashboard,
        child: Column(children: [
          _textField(_dailyGoalCtrl, '今日主目标', maxLines: 2),
          const SizedBox(height: 10),
          _textField(_dailyEmotionCtrl, '当前情绪信号'),
          const SizedBox(height: 10),
          _textField(_dailyEnergyCtrl, '能量 / 可用时间'),
          const SizedBox(height: 10),
          _textField(_dailyObstacleCtrl, '最大现实障碍', maxLines: 2),
          const SizedBox(height: 12),
          _primaryButton('生成今日行动卡', Icons.auto_awesome, _generating ? null : _dailyCockpit),
        ]),
      ),
      _statsRow(),
      if (_dailyCards.isNotEmpty) _dailyCardView(_dailyCards.first),
      if (activePlans.isNotEmpty) _planCard(activePlans.first, title: '当前 if–then 执行意图'),
      _sectionCard(
        title: '产品核心链路',
        subtitle: '愿望不是行动；愿望需要经过目标化、表征化、计划化、资源化、情境化和反馈化。',
        icon: Icons.schema_outlined,
        child: const Text('愿望 → 目标来源 → 目标内容 → 目标层级 → 心理对照 → if–then 计划 → 情绪/资源调节 → 环境线索 → 社会互动校正 → 行动复盘 → 长期整合', style: TextStyle(height: 1.6, fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  Widget _buildCoachTab() {
    return _scroll(children: [
      _sectionCard(
        title: 'AI 行动心理学教练',
        subtitle: '全局价值层 Prompt × 场景层 Prompt × 输出格式 Prompt，引导目标进入现实行动。',
        icon: Icons.psychology_alt_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sceneLabels.entries
                .map((e) => ChoiceChip(label: Text(e.value), selected: _scene == e.key, onSelected: (_) => setState(() => _scene = e.key)))
                .toList(growable: false),
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Text('输出：', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _outputMode,
              items: const [
                DropdownMenuItem(value: 'common', child: Text('通用结构')),
                DropdownMenuItem(value: 'quick', child: Text('快速模式')),
                DropdownMenuItem(value: 'deep', child: Text('深度模式')),
                DropdownMenuItem(value: 'json', child: Text('结构化JSON')),
              ],
              onChanged: (v) => setState(() => _outputMode = v ?? 'common'),
            ),
          ]),
          _textField(_inputCtrl, '写下真实目标、情绪、拖延、失败、诱惑或关系场景', maxLines: 7),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: _quickInputs.map((q) => ActionChip(label: Text(q), onPressed: () => setState(() => _inputCtrl.text = q))).toList(growable: false)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(onPressed: _generating ? null : () => _generate(), icon: const Icon(Icons.auto_awesome), label: Text(_generating ? '生成中...' : '生成行动方案')),
            OutlinedButton.icon(onPressed: _generating ? null : _createGoalDialog, icon: const Icon(Icons.add_task), label: const Text('保存为目标画像')),
          ]),
        ]),
      ),
      if (_latest != null) _sessionView(_latest!),
      _historyList(),
    ]);
  }

  Widget _buildGoalsTab() {
    return _scroll(children: [
      _sectionCard(
        title: '目标系统地图',
        subtitle: '不是普通待办，而是目标来源、内容、层级、冲突、意义和资源匹配。',
        icon: Icons.account_tree,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _primaryButton('AI 创建新目标画像', Icons.add, _generating ? null : _createGoalDialog),
          const SizedBox(height: 8),
          const Text('目标层级：身份层 → 价值层 → 项目层 → 今日行动。迷茫时上升到意义，拖延时下沉到动作。', style: TextStyle(height: 1.5)),
        ]),
      ),
      if (_goals.isEmpty) _emptyCard('还没有目标画像。先在 AI 教练里输入一个愿望，然后保存为目标。'),
      ..._goals.map(_goalCard),
    ]);
  }

  Widget _buildEmotionTab() {
    return _scroll(children: [
      _sectionCard(
        title: '情绪信号雷达',
        subtitle: '情绪不是敌人，而是目标受阻、价值冲突、资源不足或控制感下降的信号。',
        icon: Icons.track_changes,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _primaryButton('记录一次情绪信号', Icons.add_circle_outline, _recordEmotionDialog),
          const SizedBox(height: 12),
          _kvLine('常用解释', '焦虑=未来威胁/控制感不足；沮丧=进展慢；愤怒=边界/目标受阻；羞耻=自我评价威胁；空虚=意义不足。'),
        ]),
      ),
      _sectionCard(
        title: '资源与努力调节',
        subtitle: '每个目标都需要最低/标准/挑战三档，避免把资源不足误判为人格失败。',
        icon: Icons.battery_full,
        child: const Text('原则：任务难度、认知资源、情绪负荷、技能水平和反馈速度共同决定努力是否能被调动。状态差时做最低行动，状态好时再升级。', style: TextStyle(height: 1.6)),
      ),
      if (_emotions.isEmpty) _emptyCard('还没有情绪记录。记录一次情绪，看看它在提示哪个目标。'),
      ..._emotions.map(_emotionCard),
    ]);
  }

  Widget _buildPlansTab() {
    final active = _plans.where((p) => p.status == 'active').toList(growable: false);
    return _scroll(children: [
      _sectionCard(
        title: 'if–then 执行意图库',
        subtitle: '把目标交给具体情境线索：如果 X 出现，我就做 Y。',
        icon: Icons.playlist_add_check,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('执行意图解决“知道要做但没有做”：启动计划、障碍应对计划、诱惑替代计划都应绑定到具体情境。', style: TextStyle(height: 1.6)),
          const SizedBox(height: 10),
          _primaryButton('手动新建执行意图', Icons.add, () => _createManualPlanDialog()),
        ]),
      ),
      if (active.isEmpty) _emptyCard('还没有 active 的执行意图。创建目标画像时会自动生成。'),
      ...active.map((p) => _planCard(p)),
    ]);
  }

  Widget _buildToolsTab() {
    return _scroll(children: [
      _sectionCard(
        title: 'ActionMind 功能工具箱',
        subtitle: '产品设计方案中的 12 类能力全部独立入口化：每个工具都会调用对应场景层 Prompt，并沿用全局价值层与输出格式层。',
        icon: Icons.widgets_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: _openPromptSettings, icon: const Icon(Icons.tune), label: const Text('配置本模块全部 Prompt')),
            OutlinedButton.icon(onPressed: () => _tabController.animateTo(1), icon: const Icon(Icons.chat_bubble_outline), label: const Text('回到 AI 教练')),
          ]),
          const SizedBox(height: 10),
          const Text('所有 Prompt 位于：设置 → AI 提示词统一配置中心 → ActionMind · 行动心理学引擎。', style: TextStyle(height: 1.5, color: Color(0xFF64748B))),
        ]),
      ),
      _toolCoverageCard(),
      if (_toolRuns.isNotEmpty) _recentToolRunsCard(),
      _toolCard(
        title: '1. 目标澄清器',
        subtitle: '愿望 → 目标来源 / 内容 / 层级 / 第一行动。',
        scene: 'wish_start',
        sample: '我有一个很想实现但一直很模糊的愿望：我想变得更自律、更能推进重要事情。请帮我澄清真实目标。',
        icon: Icons.flag_outlined,
      ),
      _toolCard(
        title: '2. 目标价值校准器',
        subtitle: '识别内在/外在目标、证明自己、羞耻逃避和自主价值。',
        scene: 'long_goal',
        sample: '我想年入百万/获得认可/证明自己不是失败者。请帮我分析这个目标的内在价值、外在压力和更自主的重写方式。',
        icon: Icons.explore_outlined,
      ),
      _toolCard(
        title: '3. 目标层级地图',
        subtitle: '身份层 → 价值层 → 项目层 → 行动层。',
        scene: 'long_goal',
        sample: '请把我的目标拆成身份层、价值层、项目层、本周行动层和今天最低行动层，并指出我应该上升到意义还是下沉到动作。',
        icon: Icons.account_tree_outlined,
      ),
      _toolCard(
        title: '4. 心理模拟与现实对照',
        subtitle: '未来愿景必须撞上现实障碍，避免空泛幻想。',
        scene: 'fantasy',
        sample: '我有一个美好愿景，但一直没有行动。请帮我做未来愿景、现实障碍、过程模拟和 if–then 行动计划。',
        icon: Icons.compare_arrows,
      ),
      _toolCard(
        title: '5. if–then 执行意图生成器',
        subtitle: '如果 X 出现，我就做 Y。',
        scene: 'procrastination',
        sample: '我知道应该开始，但总启动不了。请只围绕具体情境帮我生成启动计划、障碍应对计划、诱惑替代计划和三档行动。',
        icon: Icons.route_outlined,
      ),
      _toolCard(
        title: '6. 情绪信号雷达',
        subtitle: '焦虑/沮丧/愤怒/羞耻/空虚/厌烦 → 目标信息。',
        scene: 'emotion',
        sample: '我现在有强烈情绪。请帮我命名情绪、找到受阻目标、解释情绪信息，并给一个 3 分钟恢复动作和下一步行动。',
        icon: Icons.radar,
      ),
      _toolCard(
        title: '7. 自我防御识别器',
        subtitle: '拖延、贬低目标、攻击他人、逃避反馈 → 自尊保护机制。',
        scene: 'failure',
        sample: '我又失败了，现在很想说这个目标根本没意义，或者我本来就不适合。请帮我识别事实失败、自我评价失败和防御机制。',
        icon: Icons.shield_outlined,
      ),
      _toolCard(
        title: '8. 资源与努力调节器',
        subtitle: '任务难度 × 认知资源 × 情绪负荷 × 技能水平。',
        scene: 'daily_cockpit',
        sample: '我今天能量有限，但仍想推进目标。请根据能量、时间、难度和情绪负荷生成最低/标准/挑战三档行动。',
        icon: Icons.battery_charging_full,
      ),
      _toolCard(
        title: '9. 无意识习惯与环境线索管理',
        subtitle: '不要只说“不做 X”，而是替代行为 + 环境重设计。',
        scene: 'habit',
        sample: '我总是自动刷短视频/游戏/熬夜。请帮我识别触发线索、即时需要、替代行为、环境设计和 if–then 替代计划。',
        icon: Icons.auto_fix_high,
      ),
      _toolCard(
        title: '10. 社会互动行动教练',
        subtitle: '准确理解、防御自尊、印象管理、期待偏差。',
        scene: 'social',
        sample: '我有一次重要沟通/冲突/面试。请帮我分析我的互动目标、对方可能目标、期待偏差、防御反应，并给下一句可说的话。',
        icon: Icons.groups_outlined,
      ),
      _toolCard(
        title: '11. 个人奋斗与生活任务地图',
        subtitle: '多个目标如何互相支持、冲突、降级或暂停。',
        scene: 'goal_conflict',
        sample: '我同时想推进健康、学习、职业、关系、创造和财务目标，但很内耗。请帮我做目标系统整合。',
        icon: Icons.map_outlined,
      ),
      _toolCard(
        title: '12. 复盘与反馈循环',
        subtitle: '进展/停滞/偏离 → 情绪反馈 → 计划更新。',
        scene: 'review',
        sample: '请帮我复盘今天的行动：哪些目标有进展、哪些受阻、原因是什么、明天 if–then 如何更新。',
        icon: Icons.history_edu_outlined,
      ),
    ]);
  }

  Widget _buildLifeSystemTab() {
    final activeGoals = _goals.where((g) => g.isActive).toList(growable: false);
    return _scroll(children: [
      _sectionCard(
        title: '生活任务与多目标整合',
        subtitle: '把健康、学习、职业、关系、财务、创造、家庭、意义目标放进同一张系统图。',
        icon: Icons.hub_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _kvLine('身份方向', _profile.identityDirection.isEmpty ? '尚未填写，可在复盘档案页补充。' : _profile.identityDirection),
          _kvLine('核心价值', _profile.coreValues.isEmpty ? '尚未填写' : _profile.coreValues.join('、')),
          _kvLine('生活领域/任务', _profile.lifeDomains.isEmpty ? '健康、学习、职业、关系、财务、创造、家庭、意义' : _profile.lifeDomains),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: _generating ? null : () => _runToolWorkflow(toolId: 'weekly_system', title: '每周目标系统图', scene: 'weekly_system', sample: _goalsSummaryText(), outputMode: 'deep'),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI 生成每周目标系统图'),
            ),
            OutlinedButton.icon(
              onPressed: _generating ? null : () => _runToolWorkflow(toolId: 'goal_conflict', title: '目标冲突检测', scene: 'goal_conflict', sample: _goalsSummaryText(), outputMode: 'deep'),
              icon: const Icon(Icons.call_split_outlined),
              label: const Text('AI 检测目标冲突'),
            ),
          ]),
        ]),
      ),
      _sectionCard(
        title: '当前系统快照',
        subtitle: '根据本模块独立表中的目标、执行意图、情绪和复盘自动汇总。',
        icon: Icons.analytics_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _kvLine('活跃目标数', activeGoals.length.toString()),
          _kvLine('执行意图数', _plans.where((p) => p.status == 'active').length.toString()),
          _kvLine('近期情绪记录', _emotions.take(4).map((e) => e.emotion).join('、')),
          _kvLine('近期复盘数', _reviews.length.toString()),
          const Divider(),
          const Text('建议每周保留：1 个主线目标、2 个支持目标、若干低维护目标；主动暂停外部压力过强、资源暂不匹配或与主线冲突的目标。', style: TextStyle(height: 1.55)),
        ]),
      ),
      if (_lifeSnapshots.isNotEmpty) _lifeSnapshotCard(_lifeSnapshots.first),
      if (activeGoals.isEmpty) _emptyCard('还没有活跃目标。先创建目标画像，再回到这里做生活系统整合。'),
      ...activeGoals.map((g) => _goalCard(g)),
    ]);
  }


  Widget _lifeSnapshotCard(ActionMindLifeSnapshot snapshot) {
    return _sectionCard(
      title: '最近一次生活系统快照',
      subtitle: '${snapshot.periodKey} · ${_fmt(snapshot.createdAtMs)}',
      icon: Icons.hub,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _kvLine('身份方向', snapshot.identityDirection),
        _kvLine('主线目标', snapshot.primaryGoal),
        _kvLine('支持目标', snapshot.supportingGoals),
        _kvLine('冲突目标', snapshot.conflictGoals),
        _kvLine('暂停目标', snapshot.pausedGoals),
        _kvLine('低维护目标', snapshot.lowMaintenanceGoals),
        _kvLine('本周焦点', snapshot.weeklyFocus),
        const Divider(),
        SelectableText(snapshot.aiResponse, style: const TextStyle(height: 1.55)),
      ]),
    );
  }

  Widget _buildArchiveTab() {
    return _scroll(children: [
      _sectionCard(
        title: '个人行动档案',
        subtitle: '整合核心价值、常见防御、情绪模式、环境线索和社会互动模式。',
        icon: Icons.folder,
        child: Column(children: [
          _textField(_valuesCtrl, '核心价值（逗号分隔）', maxLines: 2),
          const SizedBox(height: 10),
          _textField(_identityCtrl, '身份方向：我想成为什么样的人？', maxLines: 2),
          const SizedBox(height: 10),
          _textField(_domainsCtrl, '生活任务/领域：健康、学习、职业、关系、创造、家庭...', maxLines: 3),
          const SizedBox(height: 10),
          _textField(_intrinsicCtrl, '内在价值锚点：成长/关系/贡献/创造/健康...', maxLines: 2),
          const SizedBox(height: 10),
          _textField(_externalCtrl, '外部压力/评价来源', maxLines: 2),
          const SizedBox(height: 10),
          _textField(_defenseCtrl, '常见自我防御：拖延、贬低目标、逃避反馈、攻击他人...', maxLines: 3),
          const SizedBox(height: 10),
          _textField(_emotionPatternCtrl, '常见情绪模式', maxLines: 2),
          const SizedBox(height: 10),
          _textField(_cueCtrl, '环境线索/诱惑触发器', maxLines: 2),
          const SizedBox(height: 10),
          _textField(_socialCtrl, '社会互动模式：防御、讨好、证明、冷战、准确理解...', maxLines: 2),
          const SizedBox(height: 12),
          _primaryButton('保存行动档案', Icons.save_outlined, _saveProfile),
        ]),
      ),
      _sectionCard(
        title: '最近复盘',
        subtitle: '复盘不是审判，而是让目标系统根据反馈重新组织。',
        icon: Icons.history,
        child: _reviews.isEmpty
            ? const Text('暂无复盘。执行意图完成或没做到时，都可以保存复盘。')
            : Column(children: _reviews.take(8).map(_reviewTile).toList(growable: false)),
      ),
    ]);
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF0F766E)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF312E81).withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ActionMind', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
        SizedBox(height: 8),
        Text('把愿望转化为目标，把目标绑定到情境，把情绪变成信息，把行动整合进长期价值。', style: TextStyle(color: Colors.white, height: 1.55, fontWeight: FontWeight.w700)),
        SizedBox(height: 12),
        Text('核心链路：目标来源 × 目标内容 × 目标层级 × 心理对照 × if–then × 情绪资源 × 环境线索 × 社会互动 × 反馈循环', style: TextStyle(color: Color(0xFFE0E7FF), height: 1.45, fontSize: 12)),
      ]),
    );
  }

  Widget _sessionView(ActionMindSession s) {
    return _sectionCard(
      title: '最近一次行动方案',
      subtitle: '${_sceneLabels[s.scene] ?? s.scene} · ${_fmt(s.createdAtMs)} · 风险：${s.riskLevel}',
      icon: Icons.auto_awesome,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SelectableText(s.aiResponse, style: const TextStyle(height: 1.65)),
        if (s.plan.hasPlan) ...[
          Padding(padding: const EdgeInsets.only(top: 12), child: _compactPlan(s.plan)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: () => _saveSessionPlan(s), icon: const Icon(Icons.bookmark_add_outlined), label: const Text('保存执行意图')),
            OutlinedButton.icon(onPressed: () => _reviewPlan(s.plan, completed: false), icon: const Icon(Icons.rate_review_outlined), label: const Text('复盘这条计划')),
          ]),
        ],
      ]),
    );
  }

  Widget _historyList() {
    return _sectionCard(
      title: '最近 AI 记录',
      subtitle: '这些记录会作为后续目标系统整合的上下文。',
      icon: Icons.history,
      child: _sessions.isEmpty
          ? const Text('暂无记录。')
          : Column(
              children: _sessions.take(8).map((s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_sceneLabels[s.scene] ?? s.scene, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(s.userInput, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Text(_fmt(s.createdAtMs), style: const TextStyle(fontSize: 11)),
                    onTap: () => setState(() => _latest = s),
                  )).toList(growable: false),
            ),
    );
  }

  Widget _goalCard(ActionMindGoal g) {
    return _sectionCard(
      title: g.title.isEmpty ? '目标画像' : g.title,
      subtitle: '${g.status} · 自主${g.autonomyScore}/10 · 意义${g.meaningScore}/10 · 可行${g.feasibilityScore}/10 · 资源${g.resourceFitScore}/10',
      icon: Icons.flag,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _kvLine('原始愿望', g.rawWish),
        _kvLine('目标来源', g.goalSource),
        _kvLine('内在/外在', g.intrinsicExternal),
        _kvLine('接近/回避', g.approachAvoidance),
        _kvLine('理想/应该', g.idealOught),
        const Divider(),
        _kvLine('身份层', g.identityLayer),
        _kvLine('价值层', g.valueLayer),
        _kvLine('项目层', g.projectLayer),
        _kvLine('行动层', g.actionLayer),
        const Divider(),
        _kvLine('现实障碍', g.obstacles),
        _kvLine('目标冲突', g.conflicts),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: () => _createManualPlanDialog(goalId: g.id, seed: g.actionLayer), icon: const Icon(Icons.route_outlined), label: const Text('补执行意图')),
          OutlinedButton.icon(onPressed: () => _changeGoalStatus(g, 'active'), icon: const Icon(Icons.play_arrow), label: const Text('激活')),
          OutlinedButton.icon(onPressed: () => _changeGoalStatus(g, 'paused'), icon: const Icon(Icons.pause), label: const Text('暂停')),
          OutlinedButton.icon(onPressed: () => _changeGoalStatus(g, 'completed'), icon: const Icon(Icons.check), label: const Text('完成')),
          OutlinedButton.icon(onPressed: () => _changeGoalStatus(g, 'archived'), icon: const Icon(Icons.archive_outlined), label: const Text('归档')),
          TextButton.icon(onPressed: () => _deleteGoalConfirm(g), icon: const Icon(Icons.delete_outline), label: const Text('删除')),
        ]),
      ]),
    );
  }


  Widget _dailyCardView(ActionMindDailyCard c) {
    return _sectionCard(
      title: '已保存的今日行动卡',
      subtitle: '${c.dateKey} · ${_fmt(c.createdAtMs)}',
      icon: Icons.today_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _kvLine('主目标', c.mainGoal),
        _kvLine('情绪信号', c.emotion),
        _kvLine('能量/时间', c.energy),
        _kvLine('最大障碍', c.obstacle),
        const Divider(),
        _kvLine('if–then', c.ifThen),
        _kvLine('最低行动', c.minimumAction),
        _kvLine('标准行动', c.standardAction),
        _kvLine('挑战行动', c.challengeAction),
        _kvLine('恢复动作', c.recoveryAction),
      ]),
    );
  }

  Widget _planCard(ActionMindPlan p, {String title = '执行意图'}) {
    return _sectionCard(
      title: title,
      subtitle: '${p.status} · Goal#${p.goalId}',
      icon: Icons.timeline,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _kvLine('启动计划', p.ifThen),
        _kvLine('障碍应对', p.obstaclePlan),
        _kvLine('诱惑替代', p.temptationPlan),
        _kvLine('环境线索', p.environmentCue),
        const Divider(),
        _kvLine('最低行动', p.minimumAction),
        _kvLine('标准行动', p.standardAction),
        _kvLine('挑战行动', p.challengeAction),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: p.id > 0 ? () => _reviewPlan(p, completed: true) : null, icon: const Icon(Icons.check_circle_outline), label: const Text('完成复盘')),
          OutlinedButton.icon(onPressed: p.id > 0 ? () => _reviewPlan(p, completed: false) : null, icon: const Icon(Icons.info_outline), label: const Text('没做到也复盘')),
        ]),
      ]),
    );
  }

  Widget _compactPlan(ActionMindPlan p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFC7D2FE))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.ifThen, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF312E81))),
        const SizedBox(height: 8),
        Text('最低行动：${p.minimumAction}', style: const TextStyle(color: Color(0xFF4338CA), height: 1.45)),
      ]),
    );
  }


  Widget _toolCoverageCard() {
    const requiredTools = <String>[
      '1. 目标澄清器',
      '2. 目标价值校准器',
      '3. 目标层级地图',
      '4. 心理模拟与现实对照',
      '5. if–then 执行意图生成器',
      '6. 情绪信号雷达',
      '7. 自我防御识别器',
      '8. 资源与努力调节器',
      '9. 无意识习惯与环境线索管理',
      '10. 社会互动行动教练',
      '11. 个人奋斗与生活任务地图',
      '12. 复盘与反馈循环',
    ];
    return _sectionCard(
      title: '功能覆盖与真实使用状态',
      subtitle: '不再只展示入口：每个工具生成后会保存为 action_mind_tool_runs，进入后续上下文。',
      icon: Icons.fact_check_outlined,
      child: Column(
        children: requiredTools.map((name) {
          final count = _toolRuns.where((r) => r.title.startsWith(name)).length;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(count > 0 ? Icons.check_circle : Icons.radio_button_unchecked, color: count > 0 ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
            trailing: Text('$count 次', style: const TextStyle(fontWeight: FontWeight.w800)),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _recentToolRunsCard() {
    return _sectionCard(
      title: '最近工具工作流记录',
      subtitle: '工具结果会被后续 AI 读取，用于多目标整合和个性化行动建议。',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: _toolRuns.take(6).map((r) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(r.nextAction.isEmpty ? r.userInput : r.nextAction, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Text(_fmt(r.createdAtMs), style: const TextStyle(fontSize: 11)),
              onTap: () => setState(() => _latest = ActionMindSession(scene: r.scene, userInput: r.userInput, aiResponse: r.aiResponse, rewrittenGoal: r.extractedGoal, finalAction: r.nextAction, createdAtMs: r.createdAtMs)),
            )).toList(growable: false),
      ),
    );
  }

  Widget _toolCard({required String title, required String subtitle, required String scene, required String sample, required IconData icon, String toolId = ''}) {
    return _sectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(sample, style: const TextStyle(height: 1.55, color: Color(0xFF334155))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: _generating ? null : () => _runToolWorkflow(toolId: toolId.isEmpty ? title : toolId, title: title, scene: scene, sample: sample, outputMode: scene == 'weekly_system' || scene == 'goal_conflict' ? 'deep' : 'common'),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('用此工具生成'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _scene = scene;
                _inputCtrl.text = sample;
              });
              _tabController.animateTo(1);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('带到 AI 教练编辑'),
          ),
        ]),
      ]),
    );
  }

  Widget _emotionCard(ActionMindEmotionLog e) {
    return _sectionCard(
      title: e.emotion.isEmpty ? '情绪信号' : e.emotion,
      subtitle: _fmt(e.createdAtMs),
      icon: Icons.insights,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _kvLine('触发情境', e.trigger),
        _kvLine('受阻目标', e.blockedGoal),
        _kvLine('情绪信息', e.signal),
        _kvLine('3分钟恢复', e.recoveryAction),
        _kvLine('下一步行动', e.nextAction),
      ]),
    );
  }

  Widget _reviewTile(ActionMindReview r) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(r.completed ? Icons.check_circle : Icons.info_outline, color: r.completed ? const Color(0xFF16A34A) : const Color(0xFFF97316)),
      title: Text(r.completed ? '完成复盘' : '没做到也复盘', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${r.learned}\n下一次：${r.nextIfThen}', maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: Text(_fmt(r.createdAtMs), style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _statsRow() {
    final items = <Widget>[
      _statBox('AI记录', _stats.sessionCount.toString(), Icons.auto_awesome),
      _statBox('目标', _stats.goalCount.toString(), Icons.flag),
      _statBox('活跃目标', _stats.activeGoalCount.toString(), Icons.bolt),
      _statBox('执行意图', _stats.planCount.toString(), Icons.route),
      _statBox('情绪', _stats.emotionCount.toString(), Icons.radar),
      _statBox('复盘', _stats.reviewCount.toString(), Icons.history),
    ];
    return Wrap(spacing: 10, runSpacing: 10, children: items.map((w) => SizedBox(width: 112, child: w)).toList(growable: false));
  }

  Widget _statBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: const Color(0xFF4F46E5), size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ]),
    );
  }

  Widget _scroll({required List<Widget> children}) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [for (final child in children) Padding(padding: const EdgeInsets.only(bottom: 14), child: child)],
      ),
    );
  }

  Widget _sectionCard({required String title, required String subtitle, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB)), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 14, offset: Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: const Color(0xFF4F46E5))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35)),
          ])),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _emptyCard(String text) => _sectionCard(title: '空状态', subtitle: '开始建立你的行动系统。', icon: Icons.inbox_outlined, child: Text(text, style: const TextStyle(height: 1.5)));

  Widget _textField(TextEditingController controller, String label, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), filled: true, fillColor: const Color(0xFFFAFAFA)),
    );
  }

  Widget _dialogField(TextEditingController controller, String label, int maxLines) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(controller: controller, maxLines: maxLines, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13))),
    );
  }

  Widget _kvLine(String label, String value) {
    final text = value.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xFF111827), height: 1.45, fontSize: 14),
          children: [
            TextSpan(text: '$label：', style: const TextStyle(fontWeight: FontWeight.w900)),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }
}
