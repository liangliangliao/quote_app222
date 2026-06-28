import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../pages/ai_prompt_settings_page.dart';
import 'act_compass_ai_service.dart';
import 'act_compass_dao.dart';
import 'act_compass_models.dart';
import 'act_compass_prompt_config.dart';

class ActCompassHomePage extends StatefulWidget {
  final String initialInput;
  final String initialScene;

  const ActCompassHomePage({
    super.key,
    this.initialInput = '',
    this.initialScene = 'daily_checkin',
  });

  @override
  State<ActCompassHomePage> createState() => _ActCompassHomePageState();
}

class _ActCompassHomePageState extends State<ActCompassHomePage> with SingleTickerProviderStateMixin {
  final ActCompassDao _dao = ActCompassDao();
  final ActCompassAiService _ai = ActCompassAiService();

  late final TabController _tabController;
  final TextEditingController _inputCtrl = TextEditingController();
  final TextEditingController _todayExperienceCtrl = TextEditingController();
  final TextEditingController _todayValueCtrl = TextEditingController();
  final TextEditingController _todayActionCtrl = TextEditingController();
  final TextEditingController _identityCtrl = TextEditingController();
  final TextEditingController _domainsCtrl = TextEditingController();
  final TextEditingController _storiesCtrl = TextEditingController();
  final TextEditingController _avoidanceCtrl = TextEditingController();
  final TextEditingController _practicesCtrl = TextEditingController();
  final TextEditingController _customValuesCtrl = TextEditingController();

  bool _loading = true;
  bool _generating = false;
  String _scene = 'daily_checkin';
  String _outputMode = 'common';
  ActCompassProfile _profile = const ActCompassProfile();
  ActCompassFlexRadar _radar = const ActCompassFlexRadar();
  ActCompassSessionRecord? _latest;
  List<ActCompassSessionRecord> _sessions = <ActCompassSessionRecord>[];
  List<ActCompassActionCard> _actions = <ActCompassActionCard>[];
  List<ActCompassReviewRecord> _reviews = <ActCompassReviewRecord>[];
  List<ActCompassPracticeLog> _practiceLogs = <ActCompassPracticeLog>[];
  List<ActCompassValueExperiment> _experiments = <ActCompassValueExperiment>[];
  ActCompassStats _stats = const ActCompassStats();
  ActCompassPersonalizationSnapshot _snapshot = const ActCompassPersonalizationSnapshot();
  Set<String> _selectedValues = <String>{};

  static const Map<String, String> _sceneLabels = <String, String>{
    'daily_checkin': '每日三问',
    'anxiety': '焦虑 / 恐惧',
    'procrastination': '拖延 / 行动困难',
    'self_criticism': '自我批评 / 羞耻',
    'relationship': '关系冲突',
    'values_confusion': '价值迷茫',
    'action_failure': '行动失败 / 复发',
    'bedtime_rumination': '睡前反刍',
    'impulse': '冲动行为',
    'thought_defusion': '头脑故事识别',
    'acceptance_training': '接纳训练',
    'values_compass': '价值罗盘',
    'committed_action': '承诺行动卡',
    'review': '行动复盘',
    'present_moment': '当下觉察',
    'self_as_context': '观察者自我',
    'clean_dirty_pain': '干净/二次痛苦',
    'value_experiment': '7天价值实验',
    'weekly_report': '每周报告',
    'profile_update': '地图更新',
  };

  static const List<String> _valueOptions = <String>[
    '成长', '真诚', '责任', '爱', '亲密', '自由', '勇气', '创造', '贡献', '健康', '自我照顾', '学习', '家庭', '尊重', '边界', '专业', '稳定', '探索', '慈悲', '意义', '长期自由', '诚实', '表达', '身体照顾'
  ];

  static const List<String> _scenarioQuickInputs = <String>[
    '我明天要汇报，但一想到讲不好就很焦虑，所以一直刷手机。',
    '我又拖延了，感觉自己很没用，越自责越不想开始。',
    '我和伴侣吵架了，我很委屈，也很想冷战，但我其实想好好沟通。',
    '我最近很迷茫，不知道自己想要什么，感觉做什么都没意义。',
    '我睡前脑子停不下来，一直想过去做错的事和明天要发生的事。',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _scene = _sceneLabels.containsKey(widget.initialScene) ? widget.initialScene : 'daily_checkin';
    _inputCtrl.text = widget.initialInput.trim().isEmpty ? '我现在有点卡住，想带着不舒服也做一个有价值的小行动。' : widget.initialInput.trim();
    _todayExperienceCtrl.text = '我现在有一些焦虑/抗拒/不确定。';
    _todayValueCtrl.text = '成长';
    _todayActionCtrl.text = '打开一个任务，做 5 分钟。';
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inputCtrl.dispose();
    _todayExperienceCtrl.dispose();
    _todayValueCtrl.dispose();
    _todayActionCtrl.dispose();
    _identityCtrl.dispose();
    _domainsCtrl.dispose();
    _storiesCtrl.dispose();
    _avoidanceCtrl.dispose();
    _practicesCtrl.dispose();
    _customValuesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _dao.ensureTables();
      final profile = await _dao.loadProfile();
      final radar = await _dao.loadRadar();
      final sessions = await _dao.listSessions(limit: 120);
      final actions = await _dao.listActions(limit: 120);
      final reviews = await _dao.listReviews(limit: 120);
      final practiceLogs = await _dao.listPracticeLogs(limit: 120);
      final experiments = await _dao.listValueExperiments(limit: 120);
      final stats = await _dao.stats();
      final snapshot = await _dao.personalizationSnapshot();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _radar = radar;
        _selectedValues = profile.coreValues.toSet();
        _identityCtrl.text = profile.identityDirection;
        _domainsCtrl.text = profile.lifeDomains;
        _storiesCtrl.text = profile.commonStories;
        _avoidanceCtrl.text = profile.avoidancePatterns;
        _practicesCtrl.text = profile.effectivePractices;
        _sessions = sessions;
        _actions = actions;
        _reviews = reviews;
        _practiceLogs = practiceLogs;
        _experiments = experiments;
        _stats = stats;
        _snapshot = snapshot;
        _latest = sessions.isNotEmpty ? sessions.first : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('加载行愿 Compass 失败：$e');
    }
  }

  Future<void> _saveProfile() async {
    final custom = _customValuesCtrl.text
        .split(RegExp(r'[,，;；\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    final profile = ActCompassProfile(
      coreValues: <String>{..._selectedValues, ...custom}.toList(growable: false),
      identityDirection: _identityCtrl.text.trim(),
      lifeDomains: _domainsCtrl.text.trim(),
      commonStories: _storiesCtrl.text.trim(),
      avoidancePatterns: _avoidanceCtrl.text.trim(),
      effectivePractices: _practicesCtrl.text.trim(),
    );
    await _dao.saveProfile(profile);
    _customValuesCtrl.clear();
    await _load();
    _toast('价值罗盘已保存');
  }

  Future<void> _saveRadar(ActCompassFlexRadar radar) async {
    setState(() => _radar = radar);
    await _dao.saveRadar(radar);
  }

  Future<void> _generate({String? forceScene, String? forceInput, String? forceOutputMode}) async {
    final scene = forceScene ?? _scene;
    final input = (forceInput ?? _inputCtrl.text).trim();
    if (input.isEmpty) {
      _toast('请先输入真实场景或今天的体验');
      return;
    }
    setState(() => _generating = true);
    try {
      final recent = await _dao.recentContextJson();
      final record = await _ai.generate(
        scene: scene,
        userInput: input,
        profile: _profile,
        radar: _radar,
        recentContextJson: recent,
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

  Future<void> _dailyCheckin() async {
    final input = '今天的体验：${_todayExperienceCtrl.text.trim()}\n今天想靠近的价值：${_todayValueCtrl.text.trim()}\n今天愿意做的小行动：${_todayActionCtrl.text.trim()}';
    await _generate(forceScene: 'daily_checkin', forceInput: input, forceOutputMode: 'action_card');
  }


  Future<void> _runPractice({required String scene, required String title, required String seed, required String process, int durationMinutes = 5}) async {
    if (_generating) return;
    setState(() {
      _scene = scene;
      _inputCtrl.text = seed;
      _generating = true;
    });
    try {
      final recent = await _dao.recentContextJson();
      final mode = scene == 'committed_action' ? 'action_card' : (scene == 'value_experiment' ? 'deep' : 'common');
      final record = await _ai.generate(
        scene: scene,
        userInput: seed,
        profile: _profile,
        radar: _radar,
        recentContextJson: recent,
        outputMode: mode,
      );
      await _dao.insertSession(record);
      await _dao.insertPracticeLog(ActCompassPracticeLog(
        process: process,
        scene: scene,
        title: title,
        userInput: seed,
        aiGuidance: record.aiResponse,
        valueDirection: record.values.isEmpty ? '' : record.values.first,
        learned: record.actionCard.microAction,
        durationMinutes: durationMinutes,
      ));
      await _load();
      if (mounted) _tabController.animateTo(1);
    } catch (e) {
      _toast('练习生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _generateWeeklyReport() async {
    final input = '请基于近期行愿 Compass 会话、价值行动、行动复盘、训练日志和价值实验，生成本周心理灵活性报告，并给出下周最小训练重点。';
    await _generate(forceScene: 'weekly_report', forceInput: input, forceOutputMode: 'deep');
  }

  Future<void> _generateProfileUpdate() async {
    final input = '请基于我的近期记录生成个性化地图更新：核心价值候选、常见头脑故事、常见回避动作、有效练习和下一个优先训练过程。';
    await _generate(forceScene: 'profile_update', forceInput: input, forceOutputMode: 'deep');
  }

  Future<void> _createSevenDayExperiment({String? seedValue}) async {
    final valueCtrl = TextEditingController(text: seedValue ?? (_selectedValues.isNotEmpty ? _selectedValues.first : '成长'));
    final whyCtrl = TextEditingController(text: '我想用行动验证这个价值是否真实重要，而不是只靠想明白。');
    final obstacleCtrl = TextEditingController(text: '头脑说没意义、没状态、做不好，或者身体出现焦虑/抗拒。');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建 7 天价值实验'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _dialogField(valueCtrl, '价值方向', 1),
              _dialogField(whyCtrl, '为什么重要？', 3),
              _dialogField(obstacleCtrl, '预计内在障碍', 3),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('创建')),
        ],
      ),
    );
    if (ok != true) {
      valueCtrl.dispose();
      whyCtrl.dispose();
      obstacleCtrl.dispose();
      return;
    }
    final value = valueCtrl.text.trim().isEmpty ? '成长' : valueCtrl.text.trim();
    final why = whyCtrl.text.trim();
    final obstacle = obstacleCtrl.text.trim();
    valueCtrl.dispose();
    whyCtrl.dispose();
    obstacleCtrl.dispose();
    setState(() => _generating = true);
    try {
      final userInput = '价值：$value\n为什么重要：$why\n预计障碍：$obstacle\n请生成一个 7 天价值实验。';
      final recent = await _dao.recentContextJson();
      final record = await _ai.generate(
        scene: 'value_experiment',
        userInput: userInput,
        profile: _profile,
        radar: _radar,
        recentContextJson: recent,
        outputMode: 'deep',
      );
      await _dao.insertSession(record);
      final now = DateTime.now();
      await _dao.insertValueExperiment(ActCompassValueExperiment(
        title: '7天价值实验：$value',
        valueDirection: value,
        whyItMatters: why,
        experimentSteps: record.aiResponse,
        expectedObstacle: obstacle,
        actResponse: record.acceptanceSentence.isEmpty ? '我可以允许不舒服在这里，同时继续靠近$value。' : record.acceptanceSentence,
        startAtMs: DateTime(now.year, now.month, now.day).millisecondsSinceEpoch,
        endAtMs: DateTime(now.year, now.month, now.day).add(const Duration(days: 7)).millisecondsSinceEpoch,
        status: 'active',
      ));
      await _load();
      if (mounted) _tabController.animateTo(3);
      _toast('7 天价值实验已创建');
    } catch (e) {
      _toast('创建价值实验失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _reviewExperiment(ActCompassValueExperiment experiment, String status) async {
    final reviewCtrl = TextEditingController(text: status == 'completed' ? '我观察到这个价值确实值得靠近。' : '这次实验中断了，但提供了关于障碍和价值的重要信息。');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'completed' ? '完成价值实验复盘' : '中断 / 调整价值实验'),
        content: _dialogField(reviewCtrl, '复盘：我靠近了什么？学到了什么？下一步怎么缩小？', 5),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.updateValueExperiment(experiment.copyWith(status: status, review: reviewCtrl.text.trim()));
      await _load();
      _toast('价值实验复盘已保存');
    }
    reviewCtrl.dispose();
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
        title: const Text('行愿 Compass', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Prompt 设置',
            icon: const Icon(Icons.tune),
            onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const AiPromptSettingsPage(initialModuleId: ActCompassPromptConfig.moduleId, initialPromptId: ActCompassPromptConfig.globalId))); },
          ),
          IconButton(tooltip: '刷新', icon: const Icon(Icons.refresh), onPressed: () => _load()),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '今日'),
            Tab(text: 'AI教练'),
            Tab(text: '训练室'),
            Tab(text: '价值实验'),
            Tab(text: '价值罗盘'),
            Tab(text: '行动复盘'),
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
                _buildTrainingTab(),
                _buildExperimentTab(),
                _buildValuesTab(),
                _buildActionReviewTab(),
              ],
            ),
    );
  }

  Widget _buildTodayTab() {
    final active = _actions.where((a) => a.status != 'completed').toList(growable: false);
    return _scroll(
      children: [
        _heroCard(),
        _sectionCard(
          title: '每日三问 Check-in',
          subtitle: '把体验、价值和小行动放到同一张地图；目标不是消灭痛苦，而是带着它行动。',
          icon: Icons.today_outlined,
          child: Column(
            children: [
              _textField(_todayExperienceCtrl, '1. 我现在正在经历什么？', maxLines: 3),
              const SizedBox(height: 10),
              _textField(_todayValueCtrl, '2. 我今天想靠近什么价值？'),
              const SizedBox(height: 10),
              _textField(_todayActionCtrl, '3. 我今天愿意做哪一个小行动？', maxLines: 2),
              const SizedBox(height: 12),
              _primaryButton('生成今日价值行动卡', Icons.auto_awesome, _generating ? null : () => _dailyCheckin()),
            ],
          ),
        ),
        _radarCard(),
        if (active.isNotEmpty) _actionCardView(active.first, title: '当前价值行动'),
        _statsRow(),
      ],
    );
  }

  Widget _buildCoachTab() {
    return _scroll(
      children: [
        _sectionCard(
          title: 'AI ACT 对话教练',
          subtitle: '命名体验 → 看见头脑 → 给体验空间 → 连接价值 → 生成行动。',
          icon: Icons.psychology_alt_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sceneLabels.entries.map((e) => ChoiceChip(label: Text(e.value), selected: _scene == e.key, onSelected: (_) => setState(() => _scene = e.key))).toList(growable: false),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('输出：', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _outputMode,
                    items: const [
                      DropdownMenuItem(value: 'common', child: Text('通用结构')),
                      DropdownMenuItem(value: 'quick', child: Text('快速模式')),
                      DropdownMenuItem(value: 'deep', child: Text('深度模式')),
                      DropdownMenuItem(value: 'action_card', child: Text('行动卡')),
                    ],
                    onChanged: (v) => setState(() => _outputMode = v ?? 'common'),
                  ),
                ],
              ),
              _textField(_inputCtrl, '写下你的真实场景、头脑故事、情绪或行动困难', maxLines: 7),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _scenarioQuickInputs.map((q) => ActionChip(label: Text(q, maxLines: 1, overflow: TextOverflow.ellipsis), onPressed: () => setState(() => _inputCtrl.text = q))).toList(growable: false),
              ),
              const SizedBox(height: 12),
              _primaryButton(_generating ? 'AI 正在引导...' : '开始 ACT 引导', Icons.auto_awesome, _generating ? null : () => _generate()),
            ],
          ),
        ),
        if (_latest != null) _sessionView(_latest!),
        if (_sessions.length > 1) _historyList(),
      ],
    );
  }

  Widget _buildTrainingTab() {
    return _scroll(
      children: [
        _sectionCard(
          title: '六过程训练库',
          subtitle: '训练目标不是追求感觉好，而是强化开放、居中、投入：接纳/解离、当下/观察者自我、价值/行动。',
          icon: Icons.hub_outlined,
          child: Wrap(spacing: 8, runSpacing: 8, children: const [
            Chip(label: Text('开放：接纳 + 解离')),
            Chip(label: Text('居中：当下 + 观察者自我')),
            Chip(label: Text('投入：价值 + 行动')),
          ]),
        ),
        _trainingTile(
          icon: Icons.center_focus_strong_outlined,
          title: '当下觉察 90 秒',
          subtitle: '从反刍/担忧中回来，看见环境、身体、呼吸和此刻可行动的一步。',
          scene: 'present_moment',
          process: '当下觉察',
          seed: '我现在脑子很乱，一直在想过去和未来，想先回到当下。',
        ),
        _trainingTile(
          icon: Icons.visibility_outlined,
          title: '观察者自我练习',
          subtitle: '从“我就是这个故事”转向“我正在注意到这个故事”。',
          scene: 'self_as_context',
          process: '观察者自我',
          seed: '我总觉得自己就是失败者，这个故事一出现我就不想行动。',
        ),
        _trainingTile(
          icon: Icons.bubble_chart_outlined,
          title: '头脑故事识别器',
          subtitle: '把“我不行 / 必须完美 / 别人会讨厌我”转成可观察的头脑活动。',
          scene: 'thought_defusion',
          process: '认知解离',
          seed: '我肯定做不好，大家会觉得我很蠢，所以我还是别去了。',
        ),
        _trainingTile(
          icon: Icons.spa_outlined,
          title: '接纳训练室',
          subtitle: '定位身体感受，区分干净痛苦与二次痛苦，为价值留出空间。',
          scene: 'acceptance_training',
          process: '接纳',
          seed: '我不想感受胸口这团焦虑，我越想摆脱它越紧。',
        ),
        _trainingTile(
          icon: Icons.water_drop_outlined,
          title: '干净痛苦 / 二次痛苦',
          subtitle: '区分不可避免的痛与抗拒带来的额外痛，把精力还给行动。',
          scene: 'clean_dirty_pain',
          process: '接纳',
          seed: '我失败了很难过，但更痛苦的是我一直骂自己不该难过、必须马上好起来。',
        ),
        _trainingTile(
          icon: Icons.explore_outlined,
          title: '价值罗盘',
          subtitle: '从“找标准答案”转向“用 7 天实验发现方向”。',
          scene: 'values_compass',
          process: '价值连接',
          seed: '我不知道自己真正想要什么，也不知道应该往哪里走。',
        ),
        _trainingTile(
          icon: Icons.flag_circle_outlined,
          title: '承诺行动卡',
          subtitle: '把价值落到做什么、什么时候、多久、障碍应对与完成标准。',
          scene: 'committed_action',
          process: '承诺行动',
          seed: '我想靠近成长，但一开始就害怕做不好。',
        ),
        _trainingTile(
          icon: Icons.calendar_month_outlined,
          title: '7 天价值实验',
          subtitle: '把价值从抽象词变成连续 7 天可观察的小实验。',
          scene: 'value_experiment',
          process: '价值连接 + 承诺行动',
          seed: '我想测试“真诚”这个价值，请帮我设计一个 7 天价值实验。',
        ),
        _sectionCard(
          title: '场景训练库',
          subtitle: '拖延、焦虑、关系冲突、睡前反刍、冲动行为等，都映射到六个 ACT 过程。',
          icon: Icons.grid_view_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sceneLabels.entries
                .where((e) => !e.key.contains('daily') && !e.key.contains('review') && e.key != 'weekly_report' && e.key != 'profile_update' && e.key != 'safety')
                .map((e) => ActionChip(
                      label: Text(e.value),
                      onPressed: () {
                        setState(() {
                          _scene = e.key;
                          _inputCtrl.text = '我想练习“${e.value}”场景，请用 ACT 方式引导我回到价值行动。';
                        });
                        _tabController.animateTo(1);
                      },
                    ))
                .toList(growable: false),
          ),
        ),
      ],
    );
  }


  Widget _buildExperimentTab() {
    return _scroll(
      children: [
        _sectionCard(
          title: '7 天价值实验',
          subtitle: '把价值变成连续一周可验证的小行动；用行动发现方向，而不是只靠想明白。',
          icon: Icons.calendar_month_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _generating ? null : () => _createSevenDayExperiment(),
                  icon: const Icon(Icons.add_task),
                  label: const Text('创建价值实验'),
                ),
                OutlinedButton.icon(
                  onPressed: _generating ? null : () => _generateWeeklyReport(),
                  icon: const Icon(Icons.summarize_outlined),
                  label: const Text('生成每周报告'),
                ),
                OutlinedButton.icon(
                  onPressed: _generating ? null : () => _generateProfileUpdate(),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('AI 更新个性化地图'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('当前活跃实验：${_stats.activeExperimentCount}；累计实验：${_stats.experimentCount}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4B5563))),
          ]),
        ),
        if (_experiments.isEmpty)
          _sectionCard(
            title: '还没有价值实验',
            subtitle: '先选择一个价值词，例如真诚、健康、成长、责任，然后创建 7 天实验。',
            icon: Icons.explore_outlined,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _valueOptions.take(10).map((v) => ActionChip(label: Text(v), onPressed: () => _createSevenDayExperiment(seedValue: v))).toList(growable: false),
            ),
          ),
        for (final experiment in _experiments) _experimentCard(experiment),
        if (_practiceLogs.isNotEmpty)
          _sectionCard(
            title: '最近训练日志',
            subtitle: '这里记录六过程练习：当下、解离、接纳、观察者自我、价值和行动。',
            icon: Icons.fitness_center_outlined,
            child: Column(children: _practiceLogs.take(8).map(_practiceTile).toList(growable: false)),
          ),
      ],
    );
  }

  Widget _buildValuesTab() {
    return _scroll(
      children: [
        _sectionCard(
          title: '价值罗盘与个性化地图',
          subtitle: '记录核心价值、常见头脑故事、回避策略和有效练习；AI 后续会用它个性化引导。',
          icon: Icons.explore,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('核心价值词', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _valueOptions.map((v) => FilterChip(label: Text(v), selected: _selectedValues.contains(v), onSelected: (selected) => setState(() { if (selected) { _selectedValues.add(v); } else { _selectedValues.remove(v); } }))).toList(growable: false),
              ),
              const SizedBox(height: 12),
              _textField(_customValuesCtrl, '自定义价值词，可用逗号或换行分隔'),
              const SizedBox(height: 10),
              _textField(_identityCtrl, '我正在成为怎样的人？', maxLines: 2),
              const SizedBox(height: 10),
              _textField(_domainsCtrl, '重要生活领域：关系 / 工作 / 学习 / 健康 / 创造 / 家庭', maxLines: 2),
              const SizedBox(height: 10),
              _textField(_storiesCtrl, '常见头脑故事：我不够好 / 我会失败 / 别人会讨厌我', maxLines: 3),
              const SizedBox(height: 10),
              _textField(_avoidanceCtrl, '常见回避策略：刷手机 / 拖延 / 讨好 / 冷战 / 暴食', maxLines: 3),
              const SizedBox(height: 10),
              _textField(_practicesCtrl, '对我有效的练习：呼吸 / 解离句 / 散步 / 价值卡', maxLines: 3),
              const SizedBox(height: 12),
              _primaryButton('保存价值罗盘', Icons.save_outlined, () => _saveProfile()),
            ],
          ),
        ),
        _personalizationCard(),
        _sectionCard(
          title: '心理灵活性雷达',
          subtitle: '不是诊断，只是帮助你观察本周最适合训练的入口。',
          icon: Icons.radar_outlined,
          child: _radarSliders(),
        ),
      ],
    );
  }

  Widget _buildActionReviewTab() {
    return _scroll(
      children: [
        _statsRow(),
        if (_actions.isEmpty)
          _sectionCard(
            title: '还没有价值行动',
            subtitle: '先从“今日”或“AI教练”生成一个足够小的行动。',
            icon: Icons.flag_outlined,
            child: _primaryButton('去生成行动', Icons.add_task, () => _tabController.animateTo(0)),
          ),
        for (final action in _actions) _actionCardView(action),
        if (_reviews.isNotEmpty)
          _sectionCard(
            title: '最近复盘',
            subtitle: '记录的是“带着不舒服行动”的证据，而不是新的自我批评。',
            icon: Icons.history_toggle_off,
            child: Column(children: _reviews.take(8).map(_reviewTile).toList(growable: false)),
          ),
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF111827), Color(0xFF4338CA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x22111827), blurRadius: 28, offset: Offset(0, 14))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
          child: const Text('ACT 心理灵活性 · 价值行动', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        const SizedBox(height: 16),
        const Text('痛苦可以在车上，方向盘交还给价值。', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, height: 1.18)),
        const SizedBox(height: 10),
        const Text('看见头脑，不必服从头脑；允许体验，不把人生让给回避；回到当下，做一个足够小但真实的行动。', style: TextStyle(color: Color(0xFFE0E7FF), fontSize: 14, height: 1.65, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: const [
          _MiniPill('开放：接纳 + 解离'),
          _MiniPill('居中：当下 + 观察者自我'),
          _MiniPill('投入：价值 + 行动'),
        ]),
      ]),
    );
  }


  Widget _personalizationCard() {
    return _sectionCard(
      title: 'AI 个性化地图',
      subtitle: '基于本模块内的对话、行动、复盘、训练与实验自动提取，不和其他模块混合。',
      icon: Icons.map_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _chipLine('常见头脑故事', _snapshot.frequentStories),
        _chipLine('常见障碍 / 回避', _snapshot.frequentObstacles),
        _chipLine('高频价值', _snapshot.frequentValues),
        _chipLine('有效回应', _snapshot.effectiveResponses),
        _kvLine('本周优先训练', _snapshot.nextFocus),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: _generating ? null : () => _generateProfileUpdate(), icon: const Icon(Icons.auto_fix_high_outlined), label: const Text('让 AI 生成更新建议')),
          OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiPromptSettingsPage(initialModuleId: ActCompassPromptConfig.moduleId, initialPromptId: ActCompassPromptConfig.sceneProfileUpdateId))), icon: const Icon(Icons.tune), label: const Text('配置地图 Prompt')),
        ]),
      ]),
    );
  }

  Widget _chipLine(String label, List<String> values) {
    if (values.isEmpty) return _kvLine(label, '暂无足够记录');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF111827))),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: values.map((v) => Chip(label: Text(v), visualDensity: VisualDensity.compact)).toList(growable: false)),
      ]),
    );
  }

  Widget _radarCard() {
    return _sectionCard(
      title: '心理灵活性雷达',
      subtitle: '当前平均 ${_radar.average.toStringAsFixed(1)}/10，本周优先入口：${_radar.weakestLabel}',
      icon: Icons.radar_outlined,
      child: Column(
        children: [
          _processBar('当下觉察', _radar.presentMoment),
          _processBar('认知解离', _radar.defusion),
          _processBar('接纳', _radar.acceptance),
          _processBar('观察者自我', _radar.selfAsContext),
          _processBar('价值连接', _radar.values),
          _processBar('承诺行动', _radar.committedAction),
        ],
      ),
    );
  }

  Widget _radarSliders() {
    return Column(
      children: [
        _radarSlider('当下觉察', _radar.presentMoment, (v) { _saveRadar(ActCompassFlexRadar(presentMoment: v, defusion: _radar.defusion, acceptance: _radar.acceptance, selfAsContext: _radar.selfAsContext, values: _radar.values, committedAction: _radar.committedAction)); }),
        _radarSlider('认知解离', _radar.defusion, (v) { _saveRadar(ActCompassFlexRadar(presentMoment: _radar.presentMoment, defusion: v, acceptance: _radar.acceptance, selfAsContext: _radar.selfAsContext, values: _radar.values, committedAction: _radar.committedAction)); }),
        _radarSlider('接纳', _radar.acceptance, (v) { _saveRadar(ActCompassFlexRadar(presentMoment: _radar.presentMoment, defusion: _radar.defusion, acceptance: v, selfAsContext: _radar.selfAsContext, values: _radar.values, committedAction: _radar.committedAction)); }),
        _radarSlider('观察者自我', _radar.selfAsContext, (v) { _saveRadar(ActCompassFlexRadar(presentMoment: _radar.presentMoment, defusion: _radar.defusion, acceptance: _radar.acceptance, selfAsContext: v, values: _radar.values, committedAction: _radar.committedAction)); }),
        _radarSlider('价值连接', _radar.values, (v) { _saveRadar(ActCompassFlexRadar(presentMoment: _radar.presentMoment, defusion: _radar.defusion, acceptance: _radar.acceptance, selfAsContext: _radar.selfAsContext, values: v, committedAction: _radar.committedAction)); }),
        _radarSlider('承诺行动', _radar.committedAction, (v) { _saveRadar(ActCompassFlexRadar(presentMoment: _radar.presentMoment, defusion: _radar.defusion, acceptance: _radar.acceptance, selfAsContext: _radar.selfAsContext, values: _radar.values, committedAction: v)); }),
      ],
    );
  }

  Widget _radarSlider(String label, int value, ValueChanged<int> onChanged) {
    return Row(children: [
      SizedBox(width: 86, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
      Expanded(child: Slider(value: value.toDouble(), min: 0, max: 10, divisions: 10, label: '$value', onChanged: (v) => onChanged(v.round()))),
      SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900))),
    ]);
  }

  Widget _processBar(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(width: 86, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: value / 10, minHeight: 8, backgroundColor: const Color(0xFFE5E7EB)))),
        const SizedBox(width: 8),
        Text('$value/10', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _trainingTile({required IconData icon, required String title, required String subtitle, required String scene, required String seed, required String process}) {
    return _sectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      child: Row(children: [
        Expanded(child: Text(seed, style: const TextStyle(color: Color(0xFF4B5563), height: 1.5))),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: _generating
              ? null
              : () {
                  _runPractice(scene: scene, title: title, seed: seed, process: process, durationMinutes: scene == 'present_moment' ? 2 : 5);
                },
          child: const Text('练习'),
        ),
      ]),
    );
  }

  Widget _sessionView(ActCompassSessionRecord s) {
    return _sectionCard(
      title: '最近一次 AI 引导',
      subtitle: '${_sceneLabels[s.scene] ?? s.scene} · ${_fmt(s.createdAtMs)} · 风险：${s.riskLevel}',
      icon: Icons.auto_awesome,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (s.focusProcesses.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: s.focusProcesses.map((p) => Chip(label: Text(p), visualDensity: VisualDensity.compact)).toList(growable: false)),
        if (s.aiResponse.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: SelectableText(s.aiResponse, style: const TextStyle(height: 1.65, fontSize: 14))),
        if (s.actionCard.hasAction) Padding(padding: const EdgeInsets.only(top: 12), child: _compactActionCard(s.actionCard)),
      ]),
    );
  }

  Widget _historyList() {
    return _sectionCard(
      title: '最近对话记录',
      subtitle: '用于建立个性化地图，帮助 AI 识别常见头脑故事与回避模式。',
      icon: Icons.history,
      child: Column(
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


  Widget _experimentCard(ActCompassValueExperiment e) {
    return _sectionCard(
      title: e.title.isEmpty ? '价值实验' : e.title,
      subtitle: '${e.status} · ${e.valueDirection} · ${_fmt(e.startAtMs)} - ${_fmt(e.endAtMs)}',
      icon: Icons.calendar_month_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _kvLine('价值方向', e.valueDirection),
        _kvLine('为什么重要', e.whyItMatters),
        _kvLine('预计障碍', e.expectedObstacle),
        _kvLine('ACT 应对', e.actResponse),
        _kvLine('实验步骤', e.experimentSteps),
        if (e.review.trim().isNotEmpty) _kvLine('复盘', e.review),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: e.id > 0 ? () => _reviewExperiment(e, 'completed') : null, icon: const Icon(Icons.check_circle_outline), label: const Text('完成复盘')),
          OutlinedButton.icon(onPressed: e.id > 0 ? () => _reviewExperiment(e, 'paused') : null, icon: const Icon(Icons.pause_circle_outline), label: const Text('中断/调整')),
        ]),
      ]),
    );
  }

  Widget _practiceTile(ActCompassPracticeLog p) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.self_improvement_outlined, color: Color(0xFF4F46E5)),
      title: Text('${p.process} · ${p.title}', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(p.learned.isEmpty ? p.userInput : p.learned, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(_fmt(p.createdAtMs), style: const TextStyle(fontSize: 11)),
      onTap: () {
        setState(() {
          _scene = p.scene;
          _inputCtrl.text = p.userInput;
          _latest = null;
        });
        _tabController.animateTo(1);
      },
    );
  }

  Widget _actionCardView(ActCompassActionCard a, {String title = '价值行动卡'}) {
    return _sectionCard(
      title: title,
      subtitle: '${a.status} · ${a.valueDirection.isEmpty ? '价值待确认' : a.valueDirection}',
      icon: Icons.flag_circle_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _kvLine('价值方向', a.valueDirection),
        _kvLine('今天的障碍', a.obstacle),
        _kvLine('头脑故事', a.thoughtStory),
        _kvLine('解离句', a.defusionSentence),
        _kvLine('接纳句', a.acceptanceSentence),
        _kvLine('最小行动', a.microAction),
        _kvLine('开始时间', a.startTime),
        _kvLine('持续时间', a.duration),
        _kvLine('完成标准', a.successCriteria),
        _kvLine('痛苦出现时', a.ifPainThen),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: a.id > 0 ? () => _reviewAction(a, completed: true) : null, icon: const Icon(Icons.check_circle_outline), label: const Text('完成复盘')),
          OutlinedButton.icon(onPressed: a.id > 0 ? () => _reviewAction(a, completed: false) : null, icon: const Icon(Icons.replay), label: const Text('没做到也复盘')),
        ]),
      ]),
    );
  }

  Widget _compactActionCard(ActCompassActionCard a) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFC7D2FE))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('价值行动：${a.microAction}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF312E81))),
        const SizedBox(height: 6),
        Text('当障碍出现：${a.ifPainThen}', style: const TextStyle(color: Color(0xFF4338CA), height: 1.4)),
      ]),
    );
  }

  Future<void> _reviewAction(ActCompassActionCard a, {required bool completed}) async {
    final happened = TextEditingController(text: completed ? '我开始/完成了这个行动。' : '我没有做到，或者只做到了一部分。');
    final lived = TextEditingController(text: a.valueDirection);
    final exp = TextEditingController(text: '过程中出现了：${a.obstacle}');
    final learned = TextEditingController(text: completed ? '我可以带着不舒服行动。' : '这次不是人格失败，而是行动可能需要缩小或调整情境。');
    final next = TextEditingController(text: completed ? '下一次把这个行动重复一次或增加一点点。' : '把行动缩小一半，重新选择一个开始时间。');
    final thanks = TextEditingController(text: '感谢自己愿意复盘，而不是只自责。');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(completed ? '完成复盘' : '没做到也复盘'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _dialogField(happened, '实际发生了什么？', 3),
              _dialogField(lived, '我靠近了什么价值？', 2),
              _dialogField(exp, '出现了什么念头 / 情绪 / 身体感受？', 3),
              _dialogField(learned, '我学到了什么？', 3),
              _dialogField(next, '下一步可以怎样更小更具体？', 2),
              _dialogField(thanks, '我想感谢自己什么？', 2),
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
      await _dao.insertReview(ActCompassReviewRecord(
        actionId: a.id,
        completed: completed,
        whatHappened: happened.text.trim(),
        valuesLived: lived.text.trim(),
        experiences: exp.text.trim(),
        learned: learned.text.trim(),
        nextAction: next.text.trim(),
        selfThanks: thanks.text.trim(),
      ));
      await _load();
      _toast('复盘已保存');
    }
    happened.dispose();
    lived.dispose();
    exp.dispose();
    learned.dispose();
    next.dispose();
    thanks.dispose();
  }

  Widget _dialogField(TextEditingController controller, String label, int maxLines) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(controller: controller, maxLines: maxLines, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
    );
  }

  Widget _reviewTile(ActCompassReviewRecord r) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(r.completed ? Icons.check_circle : Icons.info_outline, color: r.completed ? const Color(0xFF16A34A) : const Color(0xFFF97316)),
      title: Text(r.valuesLived.isEmpty ? '复盘记录' : '靠近：${r.valuesLived}', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${r.learned}\n下一步：${r.nextAction}', maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: Text(_fmt(r.createdAtMs), style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _statsRow() {
    final items = <Widget>[
      _statBox('AI引导', _stats.sessionCount.toString(), Icons.auto_awesome),
      _statBox('价值行动', _stats.actionCount.toString(), Icons.flag),
      _statBox('完成', _stats.completedActionCount.toString(), Icons.check_circle),
      _statBox('复盘', _stats.reviewCount.toString(), Icons.history),
      _statBox('训练', _stats.practiceCount.toString(), Icons.self_improvement),
      _statBox('实验', _stats.experimentCount.toString(), Icons.calendar_month),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((w) => SizedBox(width: 112, child: w)).toList(growable: false),
    );
  }

  Widget _statBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: const Color(0xFF4F46E5), size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _kvLine(String k, String v) {
    if (v.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(text: TextSpan(style: const TextStyle(color: Color(0xFF111827), height: 1.45), children: [TextSpan(text: '$k：', style: const TextStyle(fontWeight: FontWeight.w900)), TextSpan(text: v)])),
    );
  }

  Widget _textField(TextEditingController controller, String label, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE5E7EB))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE5E7EB)))),
    );
  }

  Widget _primaryButton(String text, IconData icon, VoidCallback? onPressed) {
    return FilledButton.icon(onPressed: onPressed, icon: _generating && onPressed == null ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icon), label: Text(text), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))));
  }

  Widget _sectionCard({required String title, required String subtitle, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFE5E7EB)), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 18, offset: Offset(0, 10))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: const Color(0xFF4F46E5))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF111827))), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), height: 1.35, fontSize: 12, fontWeight: FontWeight.w600))])),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  Widget _scroll({required List<Widget> children}) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String text;
  const _MiniPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}
