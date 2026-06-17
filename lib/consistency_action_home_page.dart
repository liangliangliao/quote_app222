import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'data/db.dart';
import 'services/global_ai_settings.dart';
import 'services/unified_ai_service.dart';
import 'consistency_action_prompt_config.dart';

class ConsistencyActionHomePage extends StatefulWidget {
  const ConsistencyActionHomePage({super.key});

  @override
  State<ConsistencyActionHomePage> createState() => _ConsistencyActionHomePageState();
}

class _ConsistencyActionHomePageState extends State<ConsistencyActionHomePage> {
  final _dao = _ConsistencyActionDao();
  final _ai = UnifiedAiService();
  final _promptConfig = ConsistencyActionPromptConfig();
  final _aiSettings = GlobalAiSettings();
  final TextEditingController _input = TextEditingController(text: '我想学习心理学，但总是刷视频。');
  final TextEditingController _value = TextEditingController(text: '成长、自由、真实自我');
  final TextEditingController _actualBehavior = TextEditingController(text: '总是刷短视频，迟迟没有打开学习材料。');
  final TextEditingController _selfExplanation = TextEditingController(text: '我觉得自己没动力，也怀疑做一点点没有意义。');
  final List<_EvidenceCard> _evidence = <_EvidenceCard>[];
  final List<_ReportSnapshot> _reportSnapshots = <_ReportSnapshot>[];
  final Set<String> _selectedValues = <String>{'成长', '自由'};
  final Set<String> _selectedRewards = <String>{'提醒'};
  final List<String> _messages = const <String>[
    '现在不需要证明你有多强，只需要完成这个最小动作。',
    '先不要判断有没有意义，完成后再评价。',
    '你正在制造一个新的自我证据。',
    '这不是完整胜利，但它是旧模式的裂缝。',
  ];
  String _analysis = '';
  String _activeAction = '打开一本相关书或文章，只读 1 页，并写下一句：这页让我理解了人的哪个心理机制？';
  String _commitment = '';
  String _aiStateLabel = '检测中';
  String _weeklyReport = '';
  int _secondsLeft = 180;
  int _messageIndex = 0;
  bool _running = false;
  bool _aiBusy = false;
  Timer? _timer;

  static const List<String> _coreValues = <String>['成长', '自由', '责任', '健康', '学习', '创造', '自律', '勇气', '关系', '真实自我'];
  static const List<String> _rewardOptions = <String>['提醒', '视觉反馈', '积分', '连续打卡', '排名', '他人监督', '惩罚'];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadState();
    await _loadEvidence();
    await _loadReports();
    await _loadAiState();
    if (!mounted) return;
    _generatePlan();
  }

  Future<void> _loadAiState() async {
    try {
      final state = await _aiSettings.getState();
      if (!mounted) return;
      setState(() => _aiStateLabel = state['available'] == '1' ? (state['label'] ?? '统一 AI 可用') : '未配置，将使用本地引导');
    } catch (_) {
      if (mounted) setState(() => _aiStateLabel = '未配置，将使用本地引导');
    }
  }

  Future<void> _loadEvidence() async {
    final records = await _dao.listEvidence();
    if (!mounted) return;
    setState(() => _evidence
      ..clear()
      ..addAll(records));
  }

  Future<void> _loadReports() async {
    final reports = await _dao.listReports();
    if (!mounted) return;
    setState(() => _reportSnapshots
      ..clear()
      ..addAll(reports));
  }

  Future<void> _loadState() async {
    final state = await _dao.loadState();
    if (state.isEmpty || !mounted) return;
    setState(() {
      _input.text = (state['goal'] ?? _input.text).toString();
      _value.text = (state['value'] ?? _value.text).toString();
      _actualBehavior.text = (state['actualBehavior'] ?? _actualBehavior.text).toString();
      _selfExplanation.text = (state['selfExplanation'] ?? _selfExplanation.text).toString();
      _selectedValues
        ..clear()
        ..addAll(((state['selectedValues'] as List?) ?? const <Object?>[]).map((e) => e.toString()).where((e) => e.isNotEmpty));
      _selectedRewards
        ..clear()
        ..addAll(((state['selectedRewards'] as List?) ?? const <Object?>[]).map((e) => e.toString()).where((e) => e.isNotEmpty));
      final seconds = int.tryParse((state['secondsLeft'] ?? '').toString());
      if (seconds != null && seconds > 0 && seconds <= 3600) _secondsLeft = seconds;
    });
  }

  Future<void> _saveState() async {
    await _dao.saveState(<String, Object?>{
      'goal': _input.text,
      'value': _value.text,
      'actualBehavior': _actualBehavior.text,
      'selfExplanation': _selfExplanation.text,
      'selectedValues': _selectedValues.toList(),
      'selectedRewards': _selectedRewards.toList(),
      'secondsLeft': _secondsLeft,
      'activeAction': _activeAction,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _value.dispose();
    _actualBehavior.dispose();
    _selfExplanation.dispose();
    super.dispose();
  }

  void _generatePlan() {
    final goal = _safe(_input.text, '一个一直拖延的重要目标');
    final value = _currentValues;
    final action = _oneDollarAction(goal);
    setState(() {
      _activeAction = action;
      _commitment = '我现在不是为了证明自己彻底改变，而是为了给自己一个新的证据：我可以在没动力时，仍然完成一个足够小但真实的行动。';
      _analysis = _localStructuredOutput(goal: goal, value: value, action: action);
      _weeklyReport = _buildReportText();
    });
    unawaited(_saveState());
  }

  Future<void> _generateWithAi(String scene) async {
    final scenePrompt = _renderPromptTemplate(await _promptConfig.getPrompt(_scenePromptId(scene)), scene);
    final outputPrompt = _renderPromptTemplate(await _promptConfig.getPrompt(ConsistencyActionPromptConfig.outputId), scene);
    final systemPrompt = _renderPromptTemplate(await _promptConfig.getPrompt(ConsistencyActionPromptConfig.globalId), scene);
    final prompt = '''$scenePrompt

场景：$scene
用户目标/困扰：${_input.text}
用户重视的价值：$_currentValues
用户实际行为：${_actualBehavior.text}
用户当前解释：${_selfExplanation.text}
当前候选1美元行动：$_activeAction
外部奖励依赖：${_selectedRewards.join('、')}

请基于“足下一致行动系统”三层 Prompt 输出。
$outputPrompt''';
    if (!mounted) return;
    setState(() => _aiBusy = true);
    try {
      final text = await _ai.generateText(
        prompt: prompt,
        systemPrompt: systemPrompt,
        purpose: 'consistency_action.$scene',
        maxTokens: 1400,
        temperature: 0.4,
      );
      if (!mounted) return;
      _applyAiText(text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI 暂不可用，已保留本地方案：$e')));
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }




  void _applyAiText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    final action = _extractSection(text, '【三、你的1美元行动】');
    final commitment = _extractSection(text, '【四、行动前承诺语】');
    setState(() {
      _analysis = text;
      if (action.isNotEmpty) _activeAction = action.split('\n').first.trim();
      if (commitment.isNotEmpty) _commitment = commitment.replaceAll('“', '').replaceAll('”', '').trim();
      _weeklyReport = _buildReportText();
    });
    unawaited(_saveState());
  }

  String _extractSection(String text, String title) {
    final start = text.indexOf(title);
    if (start < 0) return '';
    final bodyStart = start + title.length;
    final next = RegExp(r'【[一二三四五六七八九十]+、[^】]+】').allMatches(text, bodyStart).map((m) => m.start).where((i) => i > bodyStart).fold<int?>(null, (prev, i) => prev == null || i < prev ? i : prev);
    return text.substring(bodyStart, next ?? text.length).trim();
  }

  void _shrinkAfterMiss() {
    final previous = _activeAction;
    setState(() {
      _activeAction = '只做 30 秒：打开入口、看一眼材料或完成动作的第一步，然后记录“我回来了”。';
      _secondsLeft = 30;
      _analysis = '''【一、你现在的核心冲突】
这次没有完成，不等于你失败，而是说明原行动入口可能仍然太大。

【二、这不是失败，而是一个改变入口】
失败在这里被当作行动设计数据：我们不清零身份证据，而是降低门槛，让你从逃避中回来。

【三、你的1美元行动】
$_activeAction

【四、行动前承诺语】
“我现在不是为了补偿之前没做到，而是为了给自己一个回来证据：我可以重新开始 30 秒。”

【五、行动中提醒语】
现在只回来 30 秒。

【六、行动后解释】
“这次行动虽然更小，但它说明我可以从中断中回来。它打破了‘断了就彻底失败’。它支持我成为一个有恢复能力的人。”

【七、下一步】
先重复 30 秒；连续两次回来后，再恢复到原行动：$previous

【八、风险提醒】
不要用中断否定全部自我。真正重要的是回来次数，而不是完美连续。''';
      _weeklyReport = _buildReportText();
    });
    unawaited(_saveState());
  }

  void _setCompanionDuration(int seconds) {
    _timer?.cancel();
    setState(() {
      _secondsLeft = seconds;
      _running = false;
    });
    unawaited(_saveState());
  }

  String _renderPromptTemplate(String template, String scene) {
    return template
        .replaceAll('{{scene}}', scene)
        .replaceAll('{{user_goal}}', _input.text)
        .replaceAll('{{user_values}}', _currentValues)
        .replaceAll('{{actual_behavior}}', _actualBehavior.text)
        .replaceAll('{{self_explanation}}', _selfExplanation.text)
        .replaceAll('{{one_dollar_action}}', _activeAction)
        .replaceAll('{{external_rewards}}', _selectedRewards.join('、'));
  }

  String _scenePromptId(String scene) {
    switch (scene) {
      case 'dissonance_analysis':
        return ConsistencyActionPromptConfig.sceneDissonanceId;
      case 'anti_hesitation':
        return ConsistencyActionPromptConfig.sceneAntiHesitationId;
      case 'post_action_explanation':
        return ConsistencyActionPromptConfig.scenePostActionId;
      case 'reward_denoise':
        return ConsistencyActionPromptConfig.sceneRewardDenoiseId;
      case 'rationalization_warning':
        return ConsistencyActionPromptConfig.sceneRationalizationId;
      case 'goal_to_one_dollar_action':
      default:
        return ConsistencyActionPromptConfig.sceneGoalId;
    }
  }

  String get _currentValues {
    final typed = _value.text.trim();
    final chips = _selectedValues.join('、');
    if (typed.isEmpty) return chips.isEmpty ? '成长' : chips;
    if (chips.isEmpty) return typed;
    return '$chips；$typed';
  }

  String _safe(String value, String fallback) => value.trim().isEmpty ? fallback : value.trim();

  String _localStructuredOutput({required String goal, required String value, required String action}) => '''【一、你现在的核心冲突】
你可能重视$value，但当前行为是：${_safe(_actualBehavior.text, '行动入口被拖延、即时刺激或完美主义挡住')}。更深的冲突不只是“做没做”，还包括你把自己解释成：${_safe(_selfExplanation.text, '我没动力，所以不能开始')}。

【二、这不是失败，而是一个改变入口】
这不是人格缺陷，而是旧自我与新价值之间的摩擦点。认知失调会不舒服，但它也提醒你：你仍然在乎这件事，可以用一个小行动让行为稍微靠近价值。

【三、你的1美元行动】
$action

【四、行动前承诺语】
“$_commitment”

【五、行动中提醒语】
先不要判断有没有意义，完成后再评价。你正在制造一个新的自我证据。

【六、行动后解释】
“这次行动虽然很小，但它说明我不是只能停在旧模式里。它打破了‘我必须有动力才开始’。它支持我成为一个能用小行动靠近价值的人。”

【七、下一步】
下一次只重复同一个动作；如果阻力变小，再轻微升级 1 分钟、1 页或 1 个更具体的输出。

【八、风险提醒】
如果你想用“做这么一点没用”否定行动，或用积分、连续打卡证明自己，请先回到真实证据：小行动不能证明你彻底改变，但能证明旧模式不是绝对的。''';

  String _oneDollarAction(String text) {
    if (text.contains('运动') || text.contains('锻炼') || text.contains('身体')) return '穿上运动鞋，走到门口或楼下；如果愿意，多走 3 分钟，不愿意也算完成。完成后记录：我可以从完全不动变成移动一步。';
    if (text.contains('工作') || text.contains('简历') || text.contains('求职')) return '打开一个招聘网站，只收藏 1 个愿意进一步了解的岗位，并写一句它和未来选择权的关系，不要求投递。';
    if (text.contains('关系') || text.contains('道歉') || text.contains('沟通')) return '写下 1 句不指责对方的真实表达，先不发送，只确认自己愿意靠近关系中的诚实与责任。';
    if (text.contains('整理') || text.contains('收拾')) return '只整理桌面上 3 件物品，并记录：我可以从一个小范围恢复秩序。';
    if (text.contains('英语') || text.contains('学习') || text.contains('书') || text.contains('心理')) return '打开相关书、课程或文章，只读 1 页或 3 分钟，并写下一句：这页内容让我看到什么机制？';
    return '打开相关材料，只推进 3 分钟或 1 个最小步骤，并写下一句：这个小动作和我重视的价值有什么关系？';
  }

  void _toggleTimer() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _running = false;
        });
      } else {
        setState(() {
          _secondsLeft--;
          if (_secondsLeft % 35 == 0) _messageIndex = (_messageIndex + 1) % _messages.length;
        });
      }
    });
  }

  Future<void> _completeAction() async {
    final card = _EvidenceCard(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      action: _activeAction,
      value: _currentValues,
      oldStory: '我完全做不到 / 我必须有动力才开始',
      newStory: '我可以在动力不足时，仍然完成一个小行动。',
      identity: _identityForValues(_currentValues),
      category: _categoryForValues(_currentValues),
      createdAt: DateTime.now(),
      recovered: _evidence.isNotEmpty && DateTime.now().difference(_evidence.first.createdAt).inDays > 1,
    );
    await _dao.saveEvidence(card);
    if (!mounted) return;
    setState(() {
      _evidence.insert(0, card);
      _secondsLeft = 180;
      _running = false;
      _weeklyReport = _buildReportText();
    });
    _timer?.cancel();
    unawaited(_saveState());
  }

  String _identityForValues(String value) {
    if (value.contains('健康')) return '我是一个愿意照顾身体的人。';
    if (value.contains('责任')) return '我是一个愿意用小行动承担现实责任的人。';
    if (value.contains('勇气')) return '我是一个可以带着不适靠近重要事物的人。';
    if (value.contains('关系')) return '我是一个愿意在关系里练习诚实与修复的人。';
    return '我是一个能够用小行动靠近价值的人。';
  }

  String _categoryForValues(String value) {
    if (value.contains('健康')) return '健康证据';
    if (value.contains('勇气')) return '勇气证据';
    if (value.contains('责任')) return '责任证据';
    if (value.contains('关系')) return '关系证据';
    if (value.contains('学习') || value.contains('成长')) return '学习证据';
    return '自律证据';
  }

  Future<void> _deleteEvidence(_EvidenceCard card) async {
    await _dao.deleteEvidence(card.id);
    if (!mounted) return;
    setState(() {
      _evidence.removeWhere((e) => e.id == card.id);
      _weeklyReport = _buildReportText();
    });
  }

  Future<void> _saveReportSnapshot() async {
    final snapshot = _ReportSnapshot(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: '价值一致性周报 · ${DateTime.now().month}/${DateTime.now().day}',
      body: _weeklyReport.isEmpty ? _buildReportText() : _weeklyReport,
      createdAt: DateTime.now(),
      evidenceCount: _evidence.where((e) => e.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 7)))).length,
      comebackCount: _evidence.where((e) => e.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 7))) && e.recovered).length,
    );
    await _dao.saveReport(snapshot);
    if (!mounted) return;
    setState(() => _reportSnapshots.insert(0, snapshot));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存本周价值一致性报告')));
  }

  Future<void> _deleteReportSnapshot(_ReportSnapshot snapshot) async {
    await _dao.deleteReport(snapshot.id);
    if (!mounted) return;
    setState(() => _reportSnapshots.removeWhere((e) => e.id == snapshot.id));
  }

  String _buildReportText() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final weekly = _evidence.where((e) => e.createdAt.isAfter(weekAgo)).toList();
    final recovered = weekly.where((e) => e.recovered).length;
    final categories = <String, int>{};
    for (final e in weekly) categories[e.category] = (categories[e.category] ?? 0) + 1;
    final topCategory = categories.entries.isEmpty ? '等待第一张行动证据' : (categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    return '''本周最重要的行动证据：${weekly.isEmpty ? '等待第一张行动证据卡' : weekly.first.action}

本周证据数量：${weekly.length}。回来次数：$recovered。系统不清零连续性，更重视你从逃避中返回的能力。

本周最大的认知失调点：${_safe(_selfExplanation.text, '价值出现了，但行动入口仍可能过大')}。

本周最常见的逃避解释：没动力、做一点没用、断了就失败。

本周最有效的1美元行动类别：$topCategory。

下周建议身份方向：${weekly.isEmpty ? '先制造第一条真实证据' : weekly.first.identity}''';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 10,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('足下一致行动系统'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '价值罗盘'),
              Tab(text: '失调雷达'),
              Tab(text: '1美元行动'),
              Tab(text: '承诺卡'),
              Tab(text: '行动陪伴'),
              Tab(text: '自我解释'),
              Tab(text: '身份证据'),
              Tab(text: '奖励降噪'),
              Tab(text: '合理化警报'),
              Tab(text: '一致性报告'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCompass(),
            _buildRadar(),
            _buildDesigner(),
            _buildCommitment(),
            _buildCompanion(),
            _buildExplanation(),
            _buildLedger(),
            _buildRewardDenoise(),
            _buildRationalization(),
            _buildReport(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompass() => _PageShell(children: [
        const _HeroCard(),
        _Section(title: 'AI 状态', body: '$_aiStateLabel。未配置时会使用本地规则完成完整闭环；配置后可用三层 Prompt 生成更贴合的引导。'),
        _Field(label: '我最近一直想做但没做的事情', controller: _input, maxLines: 3),
        _Field(label: '我说重要但一直逃避的实际行为', controller: _actualBehavior, maxLines: 2),
        _Field(label: '我现在如何解释自己', controller: _selfExplanation, maxLines: 2),
        _Field(label: '这件事背后真正重要的价值', controller: _value),
        _ChoiceWrap(values: _coreValues, selected: _selectedValues, onChanged: (v) { setState(() => _selectedValues.contains(v) ? _selectedValues.remove(v) : _selectedValues.add(v)); unawaited(_saveState()); }),
        Row(children: [Expanded(child: FilledButton.icon(onPressed: _generatePlan, icon: const Icon(Icons.explore_outlined), label: const Text('生成闭环'))), const SizedBox(width: 12), Expanded(child: OutlinedButton.icon(onPressed: _aiBusy ? null : () => _generateWithAi('goal_to_one_dollar_action'), icon: const Icon(Icons.auto_awesome), label: Text(_aiBusy ? 'AI生成中' : 'AI细化')))]),
        _Section(title: '提炼结果', body: '表层目标：${_input.text}\n深层价值：$_currentValues\n身份方向：${_identityForValues(_currentValues)}\n当前冲突：价值与行为、自我解释之间尚未一致\n最小入口：$_activeAction'),
      ]);

  Widget _buildRadar() => _PageShell(children: [
        _Section(title: '认知失调三角', body: '我相信什么？\n$_currentValues\n\n我做了什么？\n${_actualBehavior.text}\n\n我如何解释自己？\n${_selfExplanation.text}'),
        _Section(title: '真正冲突点', body: '价值失调：重视的方向与即时行为不一致。\n身份失调：想成为的人与当前证据不足。\n解释失调：用“没动力/明天再说/一点没用”减少不舒服，却可能维持逃避。'),
        Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _aiBusy ? null : () => _generateWithAi('dissonance_analysis'), icon: const Icon(Icons.auto_awesome), label: const Text('AI分析失调')))]),
        _Section(title: 'AI 引导输出', body: _analysis),
      ]);

  Widget _buildDesigner() => _PageShell(children: [
        _PrincipleGrid(items: const ['足够小', '足够真实', '具体到第一步', '贴近价值', '5分钟内能开始', '不靠强奖惩', '完成后能成为证据']),
        _Section(title: '今天的 1 美元行动', body: _activeAction),
        _Section(title: '轻微升级机制', body: '第 1 次：只完成当前动作。\n第 2 次：重复同一动作。\n第 3 次：多 1 分钟、1 页或 1 个输出。\n如果失败：不是清零，而是把动作缩小到 30 秒。'),
      ]);

  Widget _buildCommitment() => _PageShell(children: [
        _Section(title: '行动前承诺卡', body: '今天我要完成的 1 美元行动是：\n$_activeAction\n\n这件事很小，但它代表我愿意靠近的价值是：\n$_currentValues\n\n我不要求自己立刻有动力，我只要求自己先行动。\n\n完成后，我会把它当作一个证据，而不是用完美主义否定它。\n\n$_commitment'),
        const _Section(title: '自主性提醒', body: '你不是被 App 控制，也不是为了积分。你是在给未来的自己留下一条可验证的新证据。'),
      ]);

  Widget _buildCompanion() => _PageShell(children: [
        _Section(title: '当前动作', body: _activeAction),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('30秒回来'), selected: _secondsLeft == 30, onSelected: (_) => _setCompanionDuration(30)),
          ChoiceChip(label: const Text('3分钟'), selected: _secondsLeft == 180, onSelected: (_) => _setCompanionDuration(180)),
          ChoiceChip(label: const Text('5分钟'), selected: _secondsLeft == 300, onSelected: (_) => _setCompanionDuration(300)),
          ChoiceChip(label: const Text('10分钟'), selected: _secondsLeft == 600, onSelected: (_) => _setCompanionDuration(600)),
        ]),
        Center(child: Text('${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900))),
        Row(children: [Expanded(child: FilledButton.icon(onPressed: _toggleTimer, icon: Icon(_running ? Icons.pause : Icons.play_arrow), label: Text(_running ? '暂停' : '开始陪伴'))), const SizedBox(width: 12), Expanded(child: OutlinedButton.icon(onPressed: _completeAction, icon: const Icon(Icons.verified_outlined), label: const Text('完成并生成证据')))]),
        Row(children: [Expanded(child: TextButton.icon(onPressed: _shrinkAfterMiss, icon: const Icon(Icons.keyboard_double_arrow_down), label: const Text('没完成：缩小到30秒')))]),
        Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _aiBusy ? null : () => _generateWithAi('anti_hesitation'), icon: const Icon(Icons.auto_awesome), label: const Text('AI抗犹豫短句')))]),
        _Section(title: '行动中提醒', body: _messages[_messageIndex]),
      ]);

  Widget _buildExplanation() => _PageShell(children: [
        const _Section(title: '复盘问题', body: '1. 我刚才完成了什么具体行动？\n2. 这个行动和原来的逃避模式有什么不同？\n3. 它是否说明我并不是完全不能开始？\n4. 它和我真正重视的价值有什么关系？\n5. 它可以作为哪一种自我证据？\n6. 下一次我愿意重复或轻微升级哪个动作？'),
        _Section(title: '行动后解释模板', body: '这次行动虽然很小，但它说明我不是只能停在旧模式里。它打破了“我必须有动力才开始”。它支持我成为${_identityForValues(_currentValues)}'),
        Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _aiBusy ? null : () => _generateWithAi('post_action_explanation'), icon: const Icon(Icons.auto_awesome), label: const Text('AI生成解释')))]),
        FilledButton.icon(onPressed: _completeAction, icon: const Icon(Icons.add_card_outlined), label: const Text('把本次行动沉淀为证据卡')),
      ]);

  Widget _buildLedger() => _PageShell(children: [
        if (_evidence.isEmpty) const _Section(title: '身份证据账本', body: '完成一次行动后，这里会沉淀为自律、勇气、学习、责任、复盘、面对不适与从逃避中返回的证据。'),
        for (final group in _groupedEvidence().entries) ...[
          _Section(title: group.key, body: '共 ${group.value.length} 条证据。系统重视真实证据、回来次数和解释质量，而不是完美连续。'),
          for (final card in group.value) _EvidenceCardTile(card: card, onDelete: () => _deleteEvidence(card)),
        ],
      ]);

  Widget _buildRewardDenoise() => _PageShell(children: [
        const _Section(title: '外部奖励降噪系统', body: '第一阶段：提醒和视觉反馈帮助启动。\n第二阶段：减少奖励刺激，增加行动证据反馈。\n第三阶段：展示“我为什么做”和“这和我是谁有关”。\n第四阶段：主要靠价值感和身份感持续行动。'),
        _ChoiceWrap(values: _rewardOptions, selected: _selectedRewards, onChanged: (v) { setState(() => _selectedRewards.contains(v) ? _selectedRewards.remove(v) : _selectedRewards.add(v)); unawaited(_saveState()); }),
        Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _aiBusy ? null : () => _generateWithAi('reward_denoise'), icon: const Icon(Icons.auto_awesome), label: const Text('AI奖励降噪建议')))]),
        _Section(title: '当前外部理由评估', body: _rewardRiskText()),
      ]);

  Widget _buildRationalization() => _PageShell(children: [
        _Section(title: '自我欺骗与合理化警报', body: '认知失调既能促进成长，也可能导致自我欺骗。系统会区分：保护自己 vs 欺骗自己；承认困难 vs 放弃责任；接纳自己 vs 合理化逃避。'),
        _Section(title: '温和提醒模板', body: '这里可能存在一种自我保护式解释。它能让你短期舒服，但可能会让你远离真正重视的价值。我们可以区分两件事：理解你的处境，不等于否认你的责任；承认困难，不等于放弃行动。'),
        const _Section(title: '修复性小行动', body: '写下一句更诚实但不羞辱的解释：我现在确实有困难，但我仍然可以做一个 30 秒的小动作来靠近价值。'),
        Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _aiBusy ? null : () => _generateWithAi('rationalization_warning'), icon: const Icon(Icons.auto_awesome), label: const Text('AI温和识别')))]),
      ]);

  Widget _buildReport() => _PageShell(children: [
        _Section(title: '价值一致性报告', body: _weeklyReport.isEmpty ? _buildReportText() : _weeklyReport),
        Row(children: [Expanded(child: FilledButton.icon(onPressed: _saveReportSnapshot, icon: const Icon(Icons.archive_outlined), label: const Text('保存本周报告快照')))]),
        const _Section(title: '失败也转化为信息', body: '如果没有完成行动，不说“我失败了”，而是检查：行动是否仍然太大？阻力是什么？是否过度依赖情绪？下一步能否缩小到 30 秒？'),
        if (_reportSnapshots.isEmpty) const _Section(title: '报告档案', body: '保存周报后，这里会形成阶段性成长档案，避免长期证据被遗忘。'),
        for (final report in _reportSnapshots) _ReportSnapshotTile(snapshot: report, onDelete: () => _deleteReportSnapshot(report)),
      ]);

  Map<String, List<_EvidenceCard>> _groupedEvidence() {
    final map = <String, List<_EvidenceCard>>{};
    for (final e in _evidence) map.putIfAbsent(e.category, () => <_EvidenceCard>[]).add(e);
    return map;
  }

  String _rewardRiskText() {
    final strong = _selectedRewards.where((e) => e == '积分' || e == '连续打卡' || e == '排名' || e == '惩罚').toList();
    if (strong.isEmpty) return '当前更偏向低奖励、低压力启动。可以保留提醒，但把重点放在行动证据和身份解释上。';
    return '你正在使用较强外部理由：${strong.join('、')}。它们短期能启动，但长期可能让你觉得“我是为了奖励/惩罚才做”。建议保留提醒，减少清零式连续打卡，把本次行动重新连接到：$_currentValues。';
  }
}

class _EvidenceCard {
  final String id;
  final String action;
  final String value;
  final String oldStory;
  final String newStory;
  final String identity;
  final String category;
  final DateTime createdAt;
  final bool recovered;

  const _EvidenceCard({required this.id, required this.action, required this.value, required this.oldStory, required this.newStory, required this.identity, required this.category, required this.createdAt, required this.recovered});

  Map<String, Object?> toMap() => <String, Object?>{'id': id, 'action': action, 'value': value, 'old_story': oldStory, 'new_story': newStory, 'identity': identity, 'category': category, 'created_at_ms': createdAt.millisecondsSinceEpoch, 'recovered': recovered ? 1 : 0};

  static _EvidenceCard fromMap(Map<String, Object?> map) => _EvidenceCard(id: (map['id'] ?? '').toString(), action: (map['action'] ?? '').toString(), value: (map['value'] ?? '').toString(), oldStory: (map['old_story'] ?? '').toString(), newStory: (map['new_story'] ?? '').toString(), identity: (map['identity'] ?? '').toString(), category: (map['category'] ?? '自律证据').toString(), createdAt: DateTime.fromMillisecondsSinceEpoch((map['created_at_ms'] as num?)?.toInt() ?? 0), recovered: ((map['recovered'] as num?)?.toInt() ?? 0) == 1);
}

class _ReportSnapshot {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final int evidenceCount;
  final int comebackCount;

  const _ReportSnapshot({required this.id, required this.title, required this.body, required this.createdAt, required this.evidenceCount, required this.comebackCount});

  Map<String, Object?> toMap() => <String, Object?>{'id': id, 'title': title, 'body': body, 'created_at_ms': createdAt.millisecondsSinceEpoch, 'evidence_count': evidenceCount, 'comeback_count': comebackCount};

  static _ReportSnapshot fromMap(Map<String, Object?> map) => _ReportSnapshot(
        id: (map['id'] ?? '').toString(),
        title: (map['title'] ?? '价值一致性报告').toString(),
        body: (map['body'] ?? '').toString(),
        createdAt: DateTime.fromMillisecondsSinceEpoch((map['created_at_ms'] as num?)?.toInt() ?? 0),
        evidenceCount: (map['evidence_count'] as num?)?.toInt() ?? 0,
        comebackCount: (map['comeback_count'] as num?)?.toInt() ?? 0,
      );
}

class _ConsistencyActionDao {
  Future<void> _ensure() async {
    final db = await AppDatabase.instance();
    await db.execute('''CREATE TABLE IF NOT EXISTS consistency_action_evidence (id TEXT PRIMARY KEY, action TEXT, value TEXT, old_story TEXT, new_story TEXT, identity TEXT, category TEXT, created_at_ms INTEGER, recovered INTEGER DEFAULT 0)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS consistency_action_state (key TEXT PRIMARY KEY, value TEXT)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS consistency_action_reports (id TEXT PRIMARY KEY, title TEXT, body TEXT, created_at_ms INTEGER, evidence_count INTEGER DEFAULT 0, comeback_count INTEGER DEFAULT 0)''');
  }


  Future<Map<String, Object?>> loadState() async {
    try {
      await _ensure();
      final db = await AppDatabase.instance();
      final rows = await db.query('consistency_action_state', where: 'key = ?', whereArgs: ['draft'], limit: 1);
      if (rows.isEmpty) return <String, Object?>{};
      final raw = (rows.first['value'] ?? '').toString();
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, Object?>() : <String, Object?>{};
    } catch (_) {
      return <String, Object?>{};
    }
  }

  Future<void> saveState(Map<String, Object?> state) async {
    await _ensure();
    final db = await AppDatabase.instance();
    await db.insert('consistency_action_state', <String, Object?>{'key': 'draft', 'value': jsonEncode(state)}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<_EvidenceCard>> listEvidence() async {
    try {
      await _ensure();
      final db = await AppDatabase.instance();
      final rows = await db.query('consistency_action_evidence', orderBy: 'created_at_ms DESC', limit: 200);
      return rows.map(_EvidenceCard.fromMap).toList();
    } catch (_) {
      return <_EvidenceCard>[];
    }
  }

  Future<void> saveEvidence(_EvidenceCard card) async {
    await _ensure();
    final db = await AppDatabase.instance();
    await db.insert('consistency_action_evidence', card.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteEvidence(String id) async {
    await _ensure();
    final db = await AppDatabase.instance();
    await db.delete('consistency_action_evidence', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<_ReportSnapshot>> listReports() async {
    try {
      await _ensure();
      final db = await AppDatabase.instance();
      final rows = await db.query('consistency_action_reports', orderBy: 'created_at_ms DESC', limit: 52);
      return rows.map(_ReportSnapshot.fromMap).toList();
    } catch (_) {
      return <_ReportSnapshot>[];
    }
  }

  Future<void> saveReport(_ReportSnapshot report) async {
    await _ensure();
    final db = await AppDatabase.instance();
    await db.insert('consistency_action_reports', report.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteReport(String id) async {
    await _ensure();
    final db = await AppDatabase.instance();
    await db.delete('consistency_action_reports', where: 'id = ?', whereArgs: [id]);
  }
}

class _PageShell extends StatelessWidget {
  final List<Widget> children;
  const _PageShell({required this.children});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [for (final child in children) Padding(padding: const EdgeInsets.only(bottom: 14), child: child)]);
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('不是等到相信才行动，而是在行动中重新相信。', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(height: 8), Text('用最小行动制造真实证据，用真实证据重塑自我认同。')])));
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  const _Field({required this.label, required this.controller, this.maxLines = 1});
  @override
  Widget build(BuildContext context) => TextField(controller: controller, maxLines: maxLines, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(body, style: const TextStyle(height: 1.45))])));
}

class _PrincipleGrid extends StatelessWidget {
  final List<String> items;
  const _PrincipleGrid({required this.items});
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [for (final item in items) Chip(label: Text(item), avatar: const Icon(Icons.check_circle_outline, size: 18))]);
}

class _EvidenceCardTile extends StatelessWidget {
  final _EvidenceCard card;
  final VoidCallback onDelete;

  const _EvidenceCardTile({required this.card, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(card.category, style: const TextStyle(fontWeight: FontWeight.w900))),
                if (card.recovered) const Chip(label: Text('回来证据')),
                IconButton(tooltip: '删除证据', onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
              ],
            ),
            Text(card.action, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 8),
            Text('价值：${card.value}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            Text('旧解释：${card.oldStory}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            Text('新解释：${card.newStory}', style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
            Text('身份：${card.identity}', style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
          ],
        ),
      ),
    );
  }
}

class _ReportSnapshotTile extends StatelessWidget {
  final _ReportSnapshot snapshot;
  final VoidCallback onDelete;

  const _ReportSnapshotTile({required this.snapshot, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(snapshot.title, style: const TextStyle(fontWeight: FontWeight.w900))),
                IconButton(tooltip: '删除报告', onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
              ],
            ),
            Text('证据 ${snapshot.evidenceCount} · 回来 ${snapshot.comebackCount}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            Text(snapshot.body, style: const TextStyle(height: 1.45)),
          ],
        ),
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  final List<String> values;
  final Set<String> selected;
  final ValueChanged<String> onChanged;
  const _ChoiceWrap({required this.values, required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [for (final value in values) FilterChip(label: Text(value), selected: selected.contains(value), onSelected: (_) => onChanged(value))]);
}
