import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'zhixing_ai_service.dart';
import 'zhixing_dao.dart';
import 'zhixing_engines.dart';
import 'zhixing_knowledge_repository.dart';
import 'zhixing_models.dart';
import 'zhixing_prompt_config.dart';
import 'zhixing_tree_visual.dart';

class ZhixingTreeHomePage extends StatefulWidget {
  const ZhixingTreeHomePage({super.key});

  @override
  State<ZhixingTreeHomePage> createState() => _ZhixingTreeHomePageState();
}

class _ZhixingTreeHomePageState extends State<ZhixingTreeHomePage>
    with SingleTickerProviderStateMixin {
  static const Color _ink = Color(0xFF17362A);
  static const Color _green = Color(0xFF2F7550);
  static const Color _cream = Color(0xFFF6F3E8);

  final ZxKnowledgeRepository _knowledge = ZxKnowledgeRepository();
  final ZxDao _dao = ZxDao();
  final ZxAiService _ai = ZxAiService();
  final ZxBehaviourDiagnoser _diagnoser = const ZxBehaviourDiagnoser();
  final ZxThinkerMatcher _matcher = const ZxThinkerMatcher();
  final ZxActionGenerator _actionGenerator = const ZxActionGenerator();
  final ZxRewardEngine _rewardEngine = const ZxRewardEngine();
  final ZxTreeEngine _treeEngine = const ZxTreeEngine();
  final ZxChallengeFactory _challengeFactory = const ZxChallengeFactory();
  final ZxPromptConfig _promptConfig = ZxPromptConfig();

  late final TabController _tabs;
  late final List<ZxChallenge> _challenges;

  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _eventController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _thoughtController = TextEditingController();
  final TextEditingController _emotionController = TextEditingController();
  final TextEditingController _urgeController = TextEditingController();
  final TextEditingController _actualController = TextEditingController();
  final TextEditingController _cueController = TextEditingController();
  final TextEditingController _attemptsController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _working = false;
  String _error = '';
  ZxTreeState _tree = const ZxTreeState();
  List<ZxActionPrescription> _actions = const <ZxActionPrescription>[];
  List<ZxCandidateLens> _candidates = const <ZxCandidateLens>[];
  Map<String, String> _providerState = const <String, String>{};
  Map<String, double> _lensHistory = const <String, double>{};
  Set<String> _disabledLenses = <String>{};
  bool _personalizationEnabled = true;

  ZxSituationInput? _currentInput;
  ZxDiagnosisResult? _diagnosis;
  ZxMatchResult? _match;
  ZxActionPrescription? _prescription;
  ZxDifficulty? _selectedDifficulty;

  int _availableMinutes = 15;
  double _bodyCapacity = 0.65;
  double _attentionCapacity = 0.6;
  double _sleepCapacity = 0.6;
  double _autonomy = 0.65;
  double _importance = 0.75;
  double _selfEfficacy = 0.5;
  bool _knowsHow = true;
  bool _hasTime = true;
  bool _hasTools = true;
  bool _hasSupport = true;
  bool _waitingForMood = false;
  bool _positiveFantasy = false;
  bool _ethicalConflict = false;
  bool _thirdPartyImpact = false;
  bool _irreversibleImpact = false;
  bool _professionalDecision = false;
  bool _acuteDanger = false;
  bool _severeFunctionLoss = false;

  String _knowledgeSource = '';
  List<ZxKnowledgeSearchResult> _searchResults =
      const <ZxKnowledgeSearchResult>[];
  final Set<String> _compareLensIds = <String>{};
  String _challengeDimension = '';
  ZxDifficulty? _challengeDifficulty;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _challenges = _challengeFactory.buildAll();
    _initialize();
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final controller in <TextEditingController>[
      _goalController,
      _eventController,
      _targetController,
      _valueController,
      _thoughtController,
      _emotionController,
      _urgeController,
      _actualController,
      _cueController,
      _attemptsController,
      _searchController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _knowledge.load();
      await _dao.ensureTables();
      await _dao.seedKnowledge(_knowledge);
      final tree = _treeEngine.refreshTemporalState(await _dao.loadTree());
      final actions = await _dao.actions();
      final candidates = await _dao.candidates();
      final provider = await _ai.providerState();
      final history = await _dao.historicalLensResponse();
      final disabled = await _dao.disabledLenses();
      final personalization = await _dao.personalizationEnabled();
      if (!mounted) return;
      setState(() {
        _tree = tree;
        _actions = actions;
        _candidates = candidates;
        _providerState = provider;
        _lensHistory = history;
        _disabledLenses = disabled;
        _personalizationEnabled = personalization;
        _searchResults = _knowledge.search('');
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refreshLocalState() async {
    final actions = await _dao.actions();
    final candidates = await _dao.candidates();
    final tree = _treeEngine.refreshTemporalState(await _dao.loadTree());
    if (!mounted) return;
    setState(() {
      _actions = actions;
      _candidates = candidates;
      _tree = tree;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _green,
          brightness: Theme.of(context).brightness,
        ),
        scaffoldBackgroundColor: _cream,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('知行树'),
              Text(
                '智能行动成长系统',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
            ],
          ),
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const <Tab>[
              Tab(text: '今日'),
              Tab(text: '行动处方'),
              Tab(text: '问知'),
              Tab(text: '挑战花园'),
              Tab(text: '知行树'),
              Tab(text: '证据与隐私'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
                ? _buildError()
                : Stack(
                    children: <Widget>[
                      TabBarView(
                        controller: _tabs,
                        children: <Widget>[
                          _buildToday(),
                          _buildPrescriptionPage(),
                          _buildKnowledgePage(),
                          _buildChallengeGarden(),
                          _buildTreePage(),
                          _buildEvidencePrivacyPage(),
                        ],
                      ),
                      if (_working)
                        const ColoredBox(
                          color: Color(0x44000000),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 42),
              const SizedBox(height: 12),
              const Text('知识包或本地数据初始化失败'),
              const SizedBox(height: 8),
              SelectableText(_error, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _initialize, child: const Text('重试')),
            ],
          ),
        ),
      );

  Widget _buildToday() {
    final active = _actions
        .where((item) => item.status == ZxActionStatus.active)
        .toList(growable: false);
    return RefreshIndicator(
      onRefresh: _refreshLocalState,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: <Widget>[
          _heroCard(
            title: active.isEmpty ? '今天，从一件可求证的小事开始' : '今天只推进一个主动作',
            body: active.isEmpty
                ? '不是把思想变成口号，而是把现实反馈带回下一轮判断。'
                : active.first.mainAction,
            buttonLabel: active.isEmpty ? '生成行动处方' : '查看当前行动',
            onPressed: () => _tabs.animateTo(active.isEmpty ? 1 : 0),
          ),
          const SizedBox(height: 14),
          _treeSummaryCard(),
          const SizedBox(height: 14),
          _sectionCard(
            title: '当前行动',
            subtitle: '完成和学习分开记录；安全降级也是有效校准。',
            child: active.isEmpty
                ? _emptyState(
                    icon: Icons.route_outlined,
                    title: '还没有激活的行动',
                    body: '进入“行动处方”描述一个最近的具体情境。',
                  )
                : Column(
                    children: active
                        .take(3)
                        .map(_buildActionCard)
                        .toList(growable: false),
                  ),
          ),
          const SizedBox(height: 14),
          _sectionCard(
            title: '能力不是金币',
            subtitle: 'XP来自现实练习与复盘，金币只能兑换成长树资源。',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tree.abilityXp.entries
                  .map(
                    (entry) => Chip(
                      avatar: const Icon(Icons.auto_graph, size: 17),
                      label: Text('${entry.key} ${entry.value.toStringAsFixed(1)} XP'),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
      children: <Widget>[
        _sectionCard(
          title: '1 · 定义现实情境',
          subtitle: '系统诊断的是“此时此地的行为障碍”，不是给人格贴标签。',
          child: Column(
            children: <Widget>[
              _field(_goalController, '想推进的方向', hint: '例如：完成论文初稿'),
              _field(
                _eventController,
                '最近一次具体卡住的情境',
                hint: '时间、地点、发生了什么',
                maxLines: 3,
              ),
              _field(
                _targetController,
                '这次可观察的目标行为',
                hint: '例如：打开文档并写出一个段落',
                maxLines: 2,
              ),
              _field(
                _valueController,
                '它服务什么价值、责任或关系？',
                hint: '可留空，留空会降低匹配置信度',
                maxLines: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '2 · 收集现场证据',
          subtitle: '想法、情绪和冲动只是证据，不自动等于原因。',
          child: Column(
            children: <Widget>[
              _field(_thoughtController, '当时脑中出现的想法', maxLines: 2),
              _field(_emotionController, '情绪与身体感受', maxLines: 2),
              _field(_urgeController, '最强冲动', hint: '例如：刷手机、逃开、争辩'),
              _field(_actualController, '实际上做了什么', maxLines: 2),
              _field(_attemptsController, '过去尝试与结果', maxLines: 2),
              _field(_cueController, '希望绑定的线索', hint: '可留空，由系统生成'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '3 · 容量、机会与动机',
          subtitle: '先检查“能不能、有没有条件”，再谈“想不想”。',
          child: Column(
            children: <Widget>[
              _slider(
                '可用时间',
                _availableMinutes.toDouble(),
                1,
                120,
                '${_availableMinutes}分钟',
                (value) => setState(() => _availableMinutes = value.round()),
              ),
              _slider(
                '身体容量',
                _bodyCapacity,
                0,
                1,
                _percent(_bodyCapacity),
                (value) => setState(() => _bodyCapacity = value),
              ),
              _slider(
                '注意容量',
                _attentionCapacity,
                0,
                1,
                _percent(_attentionCapacity),
                (value) => setState(() => _attentionCapacity = value),
              ),
              _slider(
                '睡眠容量',
                _sleepCapacity,
                0,
                1,
                _percent(_sleepCapacity),
                (value) => setState(() => _sleepCapacity = value),
              ),
              _slider(
                '目标自主度',
                _autonomy,
                0,
                1,
                _percent(_autonomy),
                (value) => setState(() => _autonomy = value),
              ),
              _slider(
                '重要性',
                _importance,
                0,
                1,
                _percent(_importance),
                (value) => setState(() => _importance = value),
              ),
              _slider(
                '对此具体任务的把握',
                _selfEfficacy,
                0,
                1,
                _percent(_selfEfficacy),
                (value) => setState(() => _selfEfficacy = value),
              ),
              const Divider(),
              _switch('我基本知道怎样做', _knowsHow,
                  (value) => setState(() => _knowsHow = value)),
              _switch('现实中有可用时间', _hasTime,
                  (value) => setState(() => _hasTime = value)),
              _switch('工具与空间已就位', _hasTools,
                  (value) => setState(() => _hasTools = value)),
              _switch('有可用支持或协作者', _hasSupport,
                  (value) => setState(() => _hasSupport = value)),
              _switch('我在等待状态/情绪先变好', _waitingForMood,
                  (value) => setState(() => _waitingForMood = value)),
              _switch('我主要在想象成功，尚未检验障碍', _positiveFantasy,
                  (value) => setState(() => _positiveFantasy = value)),
              _switch('存在价值或伦理冲突', _ethicalConflict,
                  (value) => setState(() => _ethicalConflict = value)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '4 · 安全与影响门槛',
          subtitle: '这些开关会限制或阻断普通行动，不会用于惩罚或奖励。',
          child: Column(
            children: <Widget>[
              _switch('行动会影响第三方权益', _thirdPartyImpact,
                  (value) => setState(() => _thirdPartyImpact = value)),
              _switch('后果难以撤销', _irreversibleImpact,
                  (value) => setState(() => _irreversibleImpact = value)),
              _switch('涉及医疗/药物/法律/重大财务判断', _professionalDecision,
                  (value) => setState(() => _professionalDecision = value)),
              _switch('存在即时人身危险', _acuteDanger,
                  (value) => setState(() => _acuteDanger = value)),
              _switch('存在严重功能丧失或失控', _severeFunctionLoss,
                  (value) => setState(() => _severeFunctionLoss = value)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _working ? null : _generatePrescription,
          icon: const Icon(Icons.psychology_alt_outlined),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Text('诊断并生成处方'),
          ),
        ),
        if (_diagnosis != null) ...<Widget>[
          const SizedBox(height: 16),
          _buildDiagnosisResult(),
        ],
        if (_prescription != null) ...<Widget>[
          const SizedBox(height: 12),
          _buildPrescriptionResult(),
        ],
      ],
    );
  }

  Future<void> _generatePrescription() async {
    if (_goalController.text.trim().isEmpty ||
        _eventController.text.trim().isEmpty ||
        _targetController.text.trim().isEmpty) {
      _snack('请先填写方向、最近情境和目标行为。');
      return;
    }
    FocusScope.of(context).unfocus();
    final input = _buildSituationInput();
    final diagnosis = _diagnoser.diagnose(input);
    ZxMatchResult? match;
    ZxActionPrescription? prescription;
    if (diagnosis.safety.actionAllowed) {
      match = _matcher.match(
        input: input,
        diagnosis: diagnosis,
        lenses: _knowledge.lenses,
        historicalResponse:
            _personalizationEnabled ? _lensHistory : const <String, double>{},
        disabledLensIds: _disabledLenses,
      );
      prescription = _actionGenerator.generate(
        input: input,
        diagnosis: diagnosis,
        match: match,
      );
    }
    setState(() {
      _currentInput = input;
      _diagnosis = diagnosis;
      _match = match;
      _prescription = prescription;
      _selectedDifficulty = diagnosis.suggestedDifficulty;
    });
  }

  ZxSituationInput _buildSituationInput() => ZxSituationInput(
        goalTitle: _goalController.text.trim(),
        recentEvent: _eventController.text.trim(),
        targetBehavior: _targetController.text.trim(),
        valueReason: _valueController.text.trim(),
        thought: _thoughtController.text.trim(),
        emotion: _emotionController.text.trim(),
        urge: _urgeController.text.trim(),
        actualAction: _actualController.text.trim(),
        cue: _cueController.text.trim(),
        availableMinutes: _availableMinutes,
        bodyCapacity: _bodyCapacity,
        attentionCapacity: _attentionCapacity,
        sleepCapacity: _sleepCapacity,
        autonomy: _autonomy,
        importance: _importance,
        selfEfficacy: _selfEfficacy,
        knowsHow: _knowsHow,
        hasTime: _hasTime,
        hasTools: _hasTools,
        hasSupport: _hasSupport,
        waitingForMood: _waitingForMood,
        positiveFantasy: _positiveFantasy,
        ethicalConflict: _ethicalConflict,
        thirdPartyImpact: _thirdPartyImpact,
        irreversibleImpact: _irreversibleImpact,
        professionalDecision: _professionalDecision,
        acuteDanger: _acuteDanger,
        severeFunctionLoss: _severeFunctionLoss,
        previousAttempts: _attemptsController.text.trim(),
      );

  Widget _buildDiagnosisResult() {
    final diagnosis = _diagnosis!;
    final safety = diagnosis.safety;
    final riskColor = safety.risk.index >= ZxRiskLevel.r3.index
        ? Colors.red.shade700
        : safety.risk == ZxRiskLevel.r2
            ? Colors.orange.shade800
            : _green;
    return _sectionCard(
      title: '诊断：${diagnosis.primary.barrier.label}',
      subtitle:
          '${diagnosis.stage.code} ${diagnosis.stage.label} · 置信度 ${_percent(diagnosis.overallConfidence)}',
      leading: CircleAvatar(
        backgroundColor: riskColor.withValues(alpha: 0.12),
        child: Icon(Icons.health_and_safety_outlined, color: riskColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _statusBanner(
            '${safety.risk.label} · ${safety.actionAllowed ? '允许受限行动' : '普通行动已阻断'}',
            safety.safeNextStep,
            riskColor,
          ),
          const SizedBox(height: 10),
          ...safety.reasons.map(_bullet),
          if (diagnosis.hypotheses.isNotEmpty) ...<Widget>[
            const Divider(height: 24),
            const Text('竞争假设（最多三项）',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...diagnosis.hypotheses.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.barrier.label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(_percent(item.score)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: item.score),
                    const SizedBox(height: 4),
                    Text(
                      item.evidence.join('；'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrescriptionResult() {
    final item = _prescription!;
    final match = _match!;
    final diagnosis = _diagnosis!;
    final allowedDifficulties = ZxDifficulty.values
        .where(
          (difficulty) =>
              difficulty.index <= diagnosis.safety.maximumDifficulty.index,
        )
        .toList(growable: false);
    final primaryScore = match.scoreFor(match.primary.id);
    return _sectionCard(
      title: '行动处方',
      subtitle: '一个主动作、两个负荷选项；结果不可控，证据与复盘可控。',
      leading: const CircleAvatar(child: Icon(Icons.route_outlined)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _statusBanner(
            '${match.primary.thinker} · ${match.primary.name}',
            '匹配 ${_percent(primaryScore?.total ?? 0)} · '
                '不确定性 ${_percent(match.uncertainty)}',
            _green,
          ),
          const SizedBox(height: 10),
          Text(match.primary.mechanism),
          if (match.complementary != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '互补镜头：${match.complementary!.thinker} · ${match.complementary!.name}',
              ),
            ),
          if (match.lowMatch)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _statusBanner('低匹配提示', match.lowMatchReason,
                  Colors.orange.shade800),
            ),
          const Divider(height: 26),
          DropdownButtonFormField<ZxDifficulty>(
            value: allowedDifficulties.contains(_selectedDifficulty)
                ? _selectedDifficulty
                : item.difficulty,
            decoration: const InputDecoration(
              labelText: '行动负荷',
              border: OutlineInputBorder(),
            ),
            items: allowedDifficulties
                .map(
                  (difficulty) => DropdownMenuItem<ZxDifficulty>(
                    value: difficulty,
                    child: Text(difficulty.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (difficulty) {
              if (difficulty == null ||
                  _currentInput == null ||
                  _diagnosis == null ||
                  _match == null) {
                return;
              }
              setState(() {
                _selectedDifficulty = difficulty;
                _prescription = _actionGenerator.generate(
                  input: _currentInput!,
                  diagnosis: _diagnosis!,
                  match: _match!,
                  selectedDifficulty: difficulty,
                );
              });
            },
          ),
          const SizedBox(height: 14),
          _actionOption(
            '本轮唯一主动作',
            item.mainAction,
            Icons.play_circle_outline,
            emphasized: true,
          ),
          _actionOption('低负荷替代', item.lowerLoadAlternative,
              Icons.keyboard_double_arrow_down),
          _actionOption('条件充足后的挑战', item.challengeAlternative,
              Icons.trending_up),
          const Divider(height: 26),
          _labelValue('线索', item.cue),
          _labelValue('完成定义', item.completionDefinition),
          _labelValue('复盘问题', item.reviewQuestion),
          const SizedBox(height: 8),
          const Text('支持改造', style: TextStyle(fontWeight: FontWeight.w700)),
          ...item.supportChanges.map(_bullet),
          const SizedBox(height: 8),
          const Text('停止条件', style: TextStyle(fontWeight: FontWeight.w700)),
          ...item.stopConditions.map(_bullet),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: item.evidenceLocators
                .map(
                  (locator) => ActionChip(
                    label: Text(locator),
                    avatar: const Icon(Icons.fact_check_outlined, size: 16),
                    onPressed: () => _openEvidenceLocator(locator),
                  ),
                )
                .toList(growable: false),
          ),
          if (match.conflictNotes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('冲突、盲点与适用边界'),
              children: match.conflictNotes
                  .map(
                    (note) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.balance_outlined),
                      title: Text(note),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: _working ? null : _activatePrescription,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('确认并激活'),
              ),
              OutlinedButton.icon(
                onPressed: _providerState['available'] == '1' && !_working
                    ? _enhanceWithAi
                    : null,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  _providerState['available'] == '1'
                      ? 'AI仅优化表达'
                      : 'AI未配置（不影响使用）',
                ),
              ),
              TextButton.icon(
                onPressed: () => _markLensWrong(match.primary),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('判断不对，换一个镜头'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _enhanceWithAi() async {
    final input = _currentInput;
    final diagnosis = _diagnosis;
    final match = _match;
    final local = _prescription;
    if (input == null || diagnosis == null || match == null || local == null) {
      return;
    }
    setState(() => _working = true);
    final result = await _ai.enhanceAction(
      local: local,
      input: input,
      diagnosis: diagnosis,
      match: match,
      knowledge: _knowledge,
    );
    if (!mounted) return;
    setState(() {
      _prescription = result;
      _working = false;
    });
    _snack(
      identical(result, local)
          ? 'AI不可用或输出未通过本地校验，已保留规则版处方。'
          : '已通过本地安全、结构与证据校验；奖励规则未改变。',
    );
  }

  Future<void> _activatePrescription() async {
    final input = _currentInput;
    final diagnosis = _diagnosis;
    final match = _match;
    final prescription = _prescription;
    if (input == null ||
        diagnosis == null ||
        match == null ||
        prescription == null) {
      return;
    }
    if (diagnosis.safety.requiresSecondConfirmation) {
      final confirmed = await _confirm(
        title: 'R2 二次确认',
        body: '该行动涉及第三方或难以撤销的影响。你是否已检查同意、受影响者、可逆性和退出路径？',
        confirmLabel: '已检查，继续',
      );
      if (!confirmed) return;
    }
    setState(() => _working = true);
    try {
      final goalId = await _dao.saveGoal(
        ZxGoal(
          title: input.goalTitle,
          valueDirection: input.valueReason,
          autonomy: input.autonomy,
          stage: diagnosis.stage,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      final sessionId = await _dao.saveSession(
        goalId: goalId,
        input: input,
        diagnosis: diagnosis,
        match: match,
      );
      await _dao.saveAction(
        prescription.copyWith(
          goalId: goalId,
          status: ZxActionStatus.active,
        ),
        sessionId: sessionId,
      );
      await _refreshLocalState();
      if (!mounted) return;
      setState(() => _working = false);
      _tabs.animateTo(0);
      _snack('行动已激活。完成后请记录“完成”和“学到什么”。');
    } catch (error) {
      if (!mounted) return;
      setState(() => _working = false);
      _snack('保存失败：$error');
    }
  }

  Future<void> _markLensWrong(ZxThinkerLens lens) async {
    await _dao.recordLensFeedback(lens.id, 0.0, reason: '用户在处方页主动否定');
    final nextDisabled = <String>{..._disabledLenses, lens.id};
    await _dao.setDisabledLenses(nextDisabled);
    final history = await _dao.historicalLensResponse();
    if (!mounted) return;
    setState(() {
      _disabledLenses = nextDisabled;
      _lensHistory = history;
    });
    await _generatePrescription();
    _snack('已移除该镜头并重新匹配；可在“证据与隐私”恢复。');
  }

  Widget _buildActionCard(ZxActionPrescription action) {
    final lens = _knowledge.lensById(action.primaryLensId);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    action.goalTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _miniTag(action.difficulty.code),
                const SizedBox(width: 5),
                _miniTag(action.risk.code),
              ],
            ),
            const SizedBox(height: 8),
            Text(action.mainAction),
            const SizedBox(height: 8),
            Text(
              '${action.primaryBarrier.label} · ${lens?.thinker ?? action.primaryLensId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: () => _reviewAction(action),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('复盘'),
                ),
                TextButton(
                  onPressed: () =>
                      _dao.updateActionStatus(action.id, ZxActionStatus.paused)
                        ..then((_) => _refreshLocalState()),
                  child: const Text('暂停'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewAction(ZxActionPrescription action) async {
    var completion = ZxCompletionStatus.completed;
    var learning = ZxLearningStatus.updated;
    var proof = action.proofOptions.first;
    var difficultyFit = '合适';
    final happened = TextEditingController();
    final hypothesis = TextEditingController();
    final consequences = TextEditingController();
    final nextDecision = TextEditingController();
    final nextAction = TextEditingController();
    final review = await showDialog<ZxReviewInput>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('行动复盘'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<ZxCompletionStatus>(
                    value: completion,
                    decoration: const InputDecoration(labelText: '现实完成状态'),
                    items: const <DropdownMenuItem<ZxCompletionStatus>>[
                      DropdownMenuItem(
                        value: ZxCompletionStatus.completed,
                        child: Text('已完成可观察动作'),
                      ),
                      DropdownMenuItem(
                        value: ZxCompletionStatus.notCompleted,
                        child: Text('未完成，但可记录学习'),
                      ),
                      DropdownMenuItem(
                        value: ZxCompletionStatus.safetyDowngrade,
                        child: Text('安全降级完成'),
                      ),
                      DropdownMenuItem(
                        value: ZxCompletionStatus.exited,
                        child: Text('发现目标不对，负责地退出'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => completion = value);
                      }
                    },
                  ),
                  DropdownButtonFormField<ZxLearningStatus>(
                    value: learning,
                    decoration: const InputDecoration(labelText: '模型更新'),
                    items: const <DropdownMenuItem<ZxLearningStatus>>[
                      DropdownMenuItem(
                        value: ZxLearningStatus.none,
                        child: Text('暂无新学习'),
                      ),
                      DropdownMenuItem(
                        value: ZxLearningStatus.updated,
                        child: Text('有一条可用学习'),
                      ),
                      DropdownMenuItem(
                        value: ZxLearningStatus.strong,
                        child: Text('明显修正了原假设'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => learning = value);
                      }
                    },
                  ),
                  DropdownButtonFormField<ZxProofType>(
                    value: proof,
                    decoration: const InputDecoration(labelText: '完成证据'),
                    items: action.proofOptions
                        .map(
                          (value) => DropdownMenuItem<ZxProofType>(
                            value: value,
                            child: Text(_proofLabel(value)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => proof = value);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: difficultyFit,
                    decoration: const InputDecoration(labelText: '难度校准'),
                    items: const <String>['过低', '合适', '过高']
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => difficultyFit = value);
                      }
                    },
                  ),
                  _dialogField(happened, '事实发生了什么？'),
                  _dialogField(hypothesis, '原障碍假设被支持、反驳还是需改写？'),
                  _dialogField(consequences, '实际后果与副作用是什么？'),
                  _dialogField(nextDecision, '继续、修改、暂停还是退出？'),
                  _dialogField(nextAction, '下一次最小动作是什么？'),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final fields = <String>[
                  happened.text,
                  hypothesis.text,
                  consequences.text,
                  nextDecision.text,
                  nextAction.text,
                ];
                final depth =
                    fields.where((value) => value.trim().isNotEmpty).length;
                Navigator.pop(
                  dialogContext,
                  ZxReviewInput(
                    completion: completion,
                    learning: learning,
                    proofType: proof,
                    whatHappened: happened.text.trim(),
                    hypothesisUpdate: hypothesis.text.trim(),
                    difficultyFit: difficultyFit,
                    consequences: consequences.text.trim(),
                    nextDecision: nextDecision.text.trim(),
                    nextAction: nextAction.text.trim(),
                    safeDowngrade:
                        completion == ZxCompletionStatus.safetyDowngrade,
                    reflectionDepth: depth,
                  ),
                );
              },
              child: const Text('保存复盘'),
            ),
          ],
        ),
      ),
    );
    happened.dispose();
    hypothesis.dispose();
    consequences.dispose();
    nextDecision.dispose();
    nextAction.dispose();
    if (review == null) return;

    setState(() => _working = true);
    final contextData = await _dao.rewardContext(action);
    final reward = _rewardEngine.calculate(
      action: action,
      review: review,
      sameActionRewardedCount: contextData.sameActionRewardedCount,
      sameDifficultyCountToday: contextData.sameDifficultyCountToday,
      coinsEarnedToday: contextData.coinsEarnedToday,
    );
    final nextTree = _treeEngine.applyReward(
      _tree,
      reward,
      stage: action.stage,
    );
    await _dao.recordReviewAndReward(
      action: action,
      review: review,
      reward: reward,
      tree: nextTree,
    );
    await _refreshLocalState();
    if (!mounted) return;
    setState(() => _working = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('复盘已保存'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('完成金币 ${reward.completionCoins}'),
            Text('学习金币 ${reward.learningCoins}'),
            Text('${reward.abilityDimension} +${reward.xp.toStringAsFixed(1)} XP'),
            const SizedBox(height: 10),
            ...reward.explanations.map(_bullet),
          ],
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildKnowledgePage() {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: <Widget>[
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: '搜索问题、概念、思想家或证据定位键',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _runKnowledgeSearch();
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _runKnowledgeSearch(),
                onSubmitted: (_) => _runKnowledgeSearch(),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _knowledgeSource,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '来源筛选',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('全部22部作品'),
                        ),
                        ..._knowledge.works.map(
                          (work) => DropdownMenuItem<String>(
                            value: work.sourceId,
                            child: Text('${work.sourceId} · ${work.author}'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _knowledgeSource = value ?? '');
                        _runKnowledgeSearch();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Badge(
                    label: Text('${_compareLensIds.length}/2'),
                    child: IconButton.filledTonal(
                      tooltip: '比较思想镜头',
                      onPressed:
                          _compareLensIds.length == 2 ? _compareLenses : null,
                      icon: const Icon(Icons.compare_arrows),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty
              ? _emptyState(
                  icon: Icons.manage_search,
                  title: '没有命中已审阅知识',
                  body: '这可能是信息不足或知识缺口。可以在“证据与隐私”登记扩展候选。',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    final selected = _compareLensIds.contains(result.id);
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          result.type == 'lens'
                              ? Icons.filter_vintage_outlined
                              : result.type == 'evidence'
                                  ? Icons.fact_check_outlined
                                  : Icons.menu_book_outlined,
                        ),
                        title: Text(result.title),
                        subtitle: Text(
                          '${result.subtitle}\n${result.summary}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: result.type == 'lens'
                            ? Checkbox(
                                value: selected,
                                onChanged: (_) =>
                                    _toggleCompareLens(result.id),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () => _openKnowledgeResult(result),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _runKnowledgeSearch() {
    setState(() {
      _searchResults = _knowledge.search(
        _searchController.text,
        sourceId: _knowledgeSource,
      );
    });
  }

  void _toggleCompareLens(String id) {
    setState(() {
      if (!_compareLensIds.remove(id)) {
        if (_compareLensIds.length >= 2) {
          _compareLensIds.remove(_compareLensIds.first);
        }
        _compareLensIds.add(id);
      }
    });
  }

  Future<void> _openKnowledgeResult(ZxKnowledgeSearchResult result) async {
    if (result.type == 'lens') {
      final lens = _knowledge.lensById(result.id);
      if (lens == null) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          maxChildSize: 0.96,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
            children: <Widget>[
              Text(
                '${lens.thinker} · ${lens.name}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(lens.coreQuestion),
              const Divider(height: 28),
              _labelValue('机制', lens.mechanism),
              _labelValue('最适合', lens.bestFit),
              _labelValue('不适合', lens.nonFit),
              _labelValue('前提', lens.prerequisites),
              _labelValue('禁忌/边界', lens.contraindications),
              _labelValue('方法', lens.methods.join(' · ')),
              _labelValue('张力链接', lens.tensionLinks.join('；')),
              const SizedBox(height: 8),
              const Text('证据定位', style: TextStyle(fontWeight: FontWeight.w700)),
              ...lens.evidenceLinks.map(
                (locator) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text(locator),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _openEvidenceLocator(locator);
                  },
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('在个性化匹配中启用'),
                subtitle: const Text('关闭不会删除知识，只会从自动匹配中排除。'),
                value: !_disabledLenses.contains(lens.id),
                onChanged: (enabled) async {
                  final next = <String>{..._disabledLenses};
                  enabled ? next.remove(lens.id) : next.add(lens.id);
                  await _dao.setDisabledLenses(next);
                  if (mounted) setState(() => _disabledLenses = next);
                },
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rateLens(lens, 1),
                      icon: const Icon(Icons.thumb_up_alt_outlined),
                      label: const Text('有帮助'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rateLens(lens, 0),
                      icon: const Icon(Icons.thumb_down_alt_outlined),
                      label: const Text('不适合我'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      return;
    }
    if (result.type == 'evidence') {
      final item = _knowledge.evidence.firstWhere(
        (evidence) => evidence.id == result.id,
        orElse: () => ZxEvidenceItem(
          id: result.id,
          sourceId: '',
          locator: result.locator,
          title: result.title,
          summary: result.summary,
          use: '',
          boundary: '',
          contentType: 'original_claim',
          tags: const <String>[],
        ),
      );
      _showEvidence(item);
      return;
    }
    final work = _knowledge.workBySourceId(result.id);
    if (work != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(work.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _labelValue('作者/体系', work.author),
              _labelValue('证据角色', work.evidenceRole),
              _labelValue('证据层级', work.evidenceTier),
              _labelValue('来源ID', work.sourceId),
            ],
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openEvidenceLocator(String locator) async {
    final evidence = _knowledge.evidenceByLocator(locator);
    if (evidence != null) {
      _showEvidence(evidence);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(locator),
        content: const Text('定位键已通过知识包完整性校验；当前解析索引未拆出独立条目，请在累计知识库全文中查看上下文。'),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEvidence(ZxEvidenceItem item) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(item.locator),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _miniTag(_contentTypeLabel(item.contentType)),
                const SizedBox(height: 10),
                _labelValue('原主张/摘要', item.summary),
                _labelValue('产品用途', item.use),
                _labelValue('适用边界', item.boundary),
                _labelValue('来源', item.sourceId),
              ],
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );

  Future<void> _rateLens(ZxThinkerLens lens, double score) async {
    await _dao.recordLensFeedback(lens.id, score);
    final history = await _dao.historicalLensResponse();
    if (mounted) {
      setState(() => _lensHistory = history);
      _snack('反馈已保存，本地个性化只影响历史反应项（权重8%）。');
    }
  }

  Future<void> _compareLenses() async {
    final items = _compareLensIds
        .map(_knowledge.lensById)
        .whereType<ZxThinkerLens>()
        .toList(growable: false);
    if (items.length != 2) return;
    final a = items[0];
    final b = items[1];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('思想镜头对照'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Table(
              border: TableBorder.all(color: Theme.of(context).dividerColor),
              columnWidths: const <int, TableColumnWidth>{
                0: FixedColumnWidth(78),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
              },
              children: <TableRow>[
                _comparisonRow('', '${a.thinker}\n${a.name}',
                    '${b.thinker}\n${b.name}', header: true),
                _comparisonRow('核心问题', a.coreQuestion, b.coreQuestion),
                _comparisonRow('机制', a.mechanism, b.mechanism),
                _comparisonRow('最适合', a.bestFit, b.bestFit),
                _comparisonRow('不适合', a.nonFit, b.nonFit),
                _comparisonRow('方法', a.methods.join('、'), b.methods.join('、')),
                _comparisonRow(
                    '边界', a.contraindications, b.contraindications),
                _comparisonRow('证据', a.evidenceLinks.join('\n'),
                    b.evidenceLinks.join('\n')),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  TableRow _comparisonRow(
    String label,
    String first,
    String second, {
    bool header = false,
  }) =>
      TableRow(
        decoration: header ? BoxDecoration(color: _green.withValues(alpha: 0.1)) : null,
        children: <Widget>[
          _tableCell(label, bold: true),
          _tableCell(first, bold: header),
          _tableCell(second, bold: header),
        ],
      );

  Widget _buildChallengeGarden() {
    final dimensions =
        _challenges.map((item) => item.dimension).toSet().toList()..sort();
    final filtered = _challenges
        .where(
          (item) =>
              (_challengeDimension.isEmpty ||
                  item.dimension == _challengeDimension) &&
              (_challengeDifficulty == null ||
                  item.difficulty == _challengeDifficulty),
        )
        .toList(growable: false);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _challengeDimension,
                  decoration: const InputDecoration(
                    labelText: '10个挑战维度',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem(value: '', child: Text('全部维度')),
                    ...dimensions.map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _challengeDimension = value ?? ''),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<ZxDifficulty?>(
                  value: _challengeDifficulty,
                  decoration: const InputDecoration(
                    labelText: '难度',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<ZxDifficulty?>>[
                    const DropdownMenuItem(value: null, child: Text('全部L0–L4')),
                    ...ZxDifficulty.values.map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.code),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _challengeDifficulty = value),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: <Widget>[
              Text('${filtered.length}/50 个机制型挑战'),
              const Spacer(),
              const Text('L4始终为R2'),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final challenge = filtered[index];
              return Card(
                child: ExpansionTile(
                  leading: CircleAvatar(child: Text(challenge.difficulty.code)),
                  title: Text(challenge.title),
                  subtitle: Text(
                    '${challenge.stage.label} · ${challenge.risk.label}',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(challenge.purpose),
                    ),
                    const SizedBox(height: 8),
                    _actionOption('挑战动作', challenge.action,
                        Icons.local_florist_outlined),
                    _actionOption('低负荷替代', challenge.lowerLoadAlternative,
                        Icons.keyboard_double_arrow_down),
                    _labelValue('证明', challenge.proof),
                    _labelValue('停止条件', challenge.stopCondition),
                    Wrap(
                      spacing: 5,
                      children: challenge.evidenceLocators
                          .map(
                            (locator) => ActionChip(
                              label: Text(locator),
                              onPressed: () => _openEvidenceLocator(locator),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: () => _startChallenge(challenge),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('激活挑战'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _startChallenge(ZxChallenge challenge) async {
    if (challenge.risk == ZxRiskLevel.r2) {
      final confirmed = await _confirm(
        title: 'L4 / R2 二次确认',
        body: '这是多日或较高影响挑战。请确认已检查容量、同意、可逆性、单一瓶颈与退出路径。',
        confirmLabel: '已检查，激活',
      );
      if (!confirmed) return;
    }
    final primary = _knowledge.lenses.firstWhere(
      (lens) => lens.evidenceLinks
          .toSet()
          .intersection(challenge.evidenceLocators.toSet())
          .isNotEmpty,
      orElse: () => _knowledge.lenses.first,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    final goalId = await _dao.saveGoal(
      ZxGoal(
        title: challenge.title,
        domain: challenge.dimension,
        valueDirection: challenge.purpose,
        stage: challenge.stage,
        createdAtMs: now,
      ),
    );
    final action = ZxActionPrescription(
      id: 'challenge_${challenge.id}_$now',
      goalId: goalId,
      goalTitle: challenge.title,
      targetBehavior: challenge.action,
      primaryLensId: primary.id,
      primaryBarrier: challenge.barrier,
      stage: challenge.stage,
      difficulty: challenge.difficulty,
      risk: challenge.risk,
      thoughtLens: primary.mechanism,
      mainAction: challenge.action,
      lowerLoadAlternative: challenge.lowerLoadAlternative,
      challengeAlternative: challenge.action,
      cue: '在今天预先选择的现实情境出现时',
      response: challenge.action,
      supportChanges: const <String>['只激活当前一个瓶颈。', '提前准备必要时间、工具与支持。'],
      stopConditions: <String>[challenge.stopCondition],
      proofOptions: const <ZxProofType>[
        ZxProofType.selfReport,
        ZxProofType.processTrace,
      ],
      completionDefinition: challenge.proof,
      reviewQuestion: '这次现实反馈支持还是反驳了原障碍假设？',
      evidenceLocators: challenge.evidenceLocators,
      uncertainty: 0.35,
      status: ZxActionStatus.active,
      createdAtMs: now,
      updatedAtMs: now,
    );
    await _dao.saveAction(action);
    await _refreshLocalState();
    if (!mounted) return;
    _tabs.animateTo(0);
    _snack('挑战已激活；不会因连续天数中断而惩罚。');
  }

  Widget _buildTreePage() {
    final ledgerFuture = _dao.rewardLedger(limit: 15);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
      children: <Widget>[
        _sectionCard(
          title: '我的知行树',
          subtitle:
              '${_tree.stageLabel} · ${_tree.visualState} · 生命力 ${_tree.vitality.toStringAsFixed(0)}',
          child: Column(
            children: <Widget>[
              Semantics(
                label:
                    '知行树，${_tree.stageLabel}，${_tree.visualState}，水分${_tree.water.round()}，阳光${_tree.sunlight.round()}，养分${_tree.fertilizer.round()}',
                image: true,
                child: SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: ZhixingTreePainter(_tree),
                  ),
                ),
              ),
              if (_tree.dormant)
                FilledButton.tonalIcon(
                  onPressed: _reviveTree,
                  icon: const Icon(Icons.eco_outlined),
                  label: const Text('从休眠中温和恢复'),
                ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(child: _resourceGauge('水分', _tree.water, Colors.blue)),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        _resourceGauge('阳光', _tree.sunlight, Colors.orange),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _resourceGauge(
                        '养分', _tree.fertilizer, Colors.brown),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('平衡系数 ${_tree.balanceFactor.toStringAsFixed(2)} · '
                  '成长 ${_tree.growth.toStringAsFixed(1)}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_tree.gamificationEnabled)
          _sectionCard(
            title: '资源兑换',
            subtitle: '${_tree.coins} 金币 · 金币不能购买能力或晋级',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _shopButton('water', '水分 +12', Icons.water_drop_outlined),
                _shopButton('sunlight', '阳光 +12', Icons.wb_sunny_outlined),
                _shopButton('fertilizer', '养分 +10', Icons.compost_outlined),
                _shopButton('balanced', '平衡包 +8×3', Icons.balance_outlined),
              ],
            ),
          ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '能力维度',
          subtitle: '成长阶段依赖真实XP、平衡和关键能力，不依赖付费或金币。',
          child: Column(
            children: _tree.abilityXp.entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: <Widget>[
                        SizedBox(width: 58, child: Text(entry.key)),
                        Expanded(
                          child: LinearProgressIndicator(
                            value:
                                (entry.value / 50).clamp(0.0, 1.0).toDouble(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(entry.value.toStringAsFixed(1)),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '奖励账本',
          subtitle: '可审计、可重算；同动作递减、难度限次、单日最多60金币。',
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: ledgerFuture,
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const <Map<String, Object?>>[];
              if (rows.isEmpty) {
                return const Text('完成第一次复盘后，这里会显示确定性奖励公式。');
              }
              return Column(
                children: rows
                    .map(
                      (row) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(
                          '+${row['total_coins']} 金币 '
                          '（完成${row['completion_coins']} / 学习${row['learning_coins']}）',
                        ),
                        subtitle: Text(_dateLabel(_asInt(row['created_at_ms']))),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _treeSummaryCard() => Card(
        color: _ink,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 95,
                height: 95,
                child: CustomPaint(painter: ZhixingTreePainter(_tree)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: DefaultTextStyle(
                  style: const TextStyle(color: Colors.white),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _tree.stageLabel,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '生命力 ${_tree.vitality.toStringAsFixed(0)} · ${_tree.visualState}',
                      ),
                      const SizedBox(height: 4),
                      Text('${_tree.coins} 金币 · ${_tree.growth.toStringAsFixed(1)} 成长'),
                    ],
                  ),
                ),
              ),
              IconButton(
                color: Colors.white,
                onPressed: () => _tabs.animateTo(4),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      );

  Widget _resourceGauge(String label, double value, Color color) => Column(
        children: <Widget>[
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0).toDouble(),
            color: color,
            minHeight: 9,
            borderRadius: BorderRadius.circular(9),
          ),
          const SizedBox(height: 4),
          Text(value.toStringAsFixed(0)),
        ],
      );

  Widget _shopButton(String resource, String label, IconData icon) {
    final cost = ZxTreeEngine.prices[resource] ?? 0;
    return OutlinedButton.icon(
      onPressed: () => _exchange(resource),
      icon: Icon(icon),
      label: Text('$label · $cost币'),
    );
  }

  Future<void> _exchange(String resource) async {
    final result = _treeEngine.exchange(_tree, resource);
    if (result.appliedAmount <= 0) {
      _snack(result.message);
      return;
    }
    await _dao.saveTree(
      result.state,
      eventType: 'exchange',
      resource: resource,
      coinDelta: -result.cost,
      resourceDelta: result.appliedAmount,
    );
    if (!mounted) return;
    setState(() => _tree = result.state);
    _snack(result.message);
  }

  Future<void> _reviveTree() async {
    final next = _treeEngine.revive(_tree);
    await _dao.saveTree(next, eventType: 'revive');
    if (mounted) setState(() => _tree = next);
  }

  Widget _buildEvidencePrivacyPage() {
    final info = _knowledge.packageInfo;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
      children: <Widget>[
        _sectionCard(
          title: '证据包',
          subtitle: '原主张、来源内综合、跨来源综合和产品建议在界面中分层显示。',
          leading: CircleAvatar(
            backgroundColor: info.integrityValid
                ? Colors.green.withValues(alpha: 0.12)
                : Colors.red.withValues(alpha: 0.12),
            child: Icon(
              info.integrityValid ? Icons.verified_outlined : Icons.warning,
              color: info.integrityValid ? Colors.green : Colors.red,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _labelValue('知识版本', info.version),
              _labelValue('规则版本', info.ruleVersion),
              _labelValue('审阅状态', info.reviewStatus),
              _labelValue('来源数量', '${info.sourceCount}部作品'),
              _labelValue('思想镜头', '${_knowledge.lenses.length}个机制级镜头'),
              _labelValue(
                'SHA-256',
                '${info.actualSha256.substring(0, 16)}… · '
                    '${info.integrityValid ? '完整性通过' : '不匹配'}',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: const <Widget>[
                  Chip(label: Text('原主张')),
                  Chip(label: Text('来源内综合')),
                  Chip(label: Text('跨来源综合')),
                  Chip(label: Text('产品建议')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'AI与本地规则',
          subtitle: '不登录也可离线完成全闭环。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _labelValue(
                '当前提供方',
                _providerState['available'] == '1'
                    ? (_providerState['label'] ?? '已配置')
                    : '未配置 · 使用本地确定性引擎',
              ),
              const Text(
                'AI只能优化表达或整理扩展候选；安全门、COM-B诊断、匹配公式、证据定位、奖励与成长均由本地规则决定。',
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _editPrompts,
                icon: const Icon(Icons.tune),
                label: const Text('查看/编辑模块提示词'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '个性化与游戏化',
          subtitle: '随时关闭、重置，不影响知识访问和安全规则。',
          child: Column(
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用历史反应个性化'),
                subtitle: const Text('只占匹配公式8%，不覆盖硬门槛。'),
                value: _personalizationEnabled,
                onChanged: (value) async {
                  await _dao.setPersonalizationEnabled(value);
                  if (mounted) {
                    setState(() => _personalizationEnabled = value);
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('显示成长树游戏化'),
                subtitle: const Text('关闭后仍保留行动、复盘和证据功能。'),
                value: _tree.gamificationEnabled,
                onChanged: (value) async {
                  final next = _tree.copyWith(gamificationEnabled: value);
                  await _dao.saveTree(next, eventType: 'gamification_toggle');
                  if (mounted) setState(() => _tree = next);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restart_alt),
                title: const Text('重置个性化'),
                subtitle: Text(
                  '清除镜头反馈与${_disabledLenses.length}个禁用项，不删除行动。',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _resetPersonalization,
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('管理思想镜头（已禁用 ${_disabledLenses.length}）'),
                children: _knowledge.lenses
                    .map(
                      (lens) => CheckboxListTile(
                        value: !_disabledLenses.contains(lens.id),
                        title: Text('${lens.thinker} · ${lens.name}'),
                        subtitle: Text(lens.sourceId),
                        onChanged: (enabled) =>
                            _setLensEnabled(lens.id, enabled ?? true),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '知识扩展审查台',
          subtitle: '候选 → 人工核查/隔离/拒绝；未发布进新知识包前绝不参与行动与奖励。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: _addManualCandidate,
                    icon: const Icon(Icons.add),
                    label: const Text('登记候选'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _providerState['available'] == '1'
                        ? _proposeCandidateWithAi
                        : null,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('AI整理候选'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_candidates.isEmpty)
                const Text('尚无扩展候选。')
              else
                ..._candidates.map(
                  (candidate) => Card(
                    child: ExpansionTile(
                      title: Text(candidate.concept),
                      subtitle: Text(
                        '${candidate.thinker} · ${candidate.status}',
                      ),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: <Widget>[
                        _labelValue('缺口', candidate.gap),
                        _labelValue('作品', candidate.work),
                        _labelValue('来源URI', candidate.sourceUri),
                        _labelValue('新增价值', candidate.addedValue),
                        _labelValue('风险/反证', candidate.risks),
                        Wrap(
                          spacing: 6,
                          children: <Widget>[
                            OutlinedButton(
                              onPressed: () => _setCandidateStatus(
                                  candidate.id, 'quarantine'),
                              child: const Text('隔离'),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  _setCandidateStatus(candidate.id, 'rejected'),
                              child: const Text('拒绝'),
                            ),
                            FilledButton.tonal(
                              onPressed: () => _setCandidateStatus(
                                  candidate.id, 'reviewed_pending_package'),
                              child: const Text('人工核查通过'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '数据权利',
          subtitle: '数据默认仅保存在本机，可导出或删除。',
          child: Column(
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.download_outlined),
                title: const Text('导出全部知行树数据'),
                subtitle: const Text('JSON含目标、行动、复盘、双账本、树状态与候选。'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _exportData,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_forever_outlined,
                    color: Colors.red),
                title: const Text('删除全部用户数据'),
                subtitle: const Text('保留只读知识包；此操作不可撤销。'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _deleteAllData,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '本系统用于行动学习与自我管理，不替代医疗、心理治疗、法律、财务或紧急服务。R3/R4信息会阻断普通任务。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }

  Future<void> _resetPersonalization() async {
    final confirmed = await _confirm(
      title: '重置个性化？',
      body: '将清除思想镜头的帮助度历史和禁用列表；目标、行动、复盘与奖励不受影响。',
      confirmLabel: '重置',
    );
    if (!confirmed) return;
    await _dao.resetPersonalization();
    if (!mounted) return;
    setState(() {
      _lensHistory = const <String, double>{};
      _disabledLenses = <String>{};
    });
  }

  Future<void> _setLensEnabled(String id, bool enabled) async {
    final next = <String>{..._disabledLenses};
    enabled ? next.remove(id) : next.add(id);
    await _dao.setDisabledLenses(next);
    if (mounted) setState(() => _disabledLenses = next);
  }

  Future<void> _addManualCandidate() async {
    final gap = TextEditingController();
    final concept = TextEditingController();
    final thinker = TextEditingController();
    final work = TextEditingController();
    final uri = TextEditingController();
    final value = TextEditingController();
    final risks = TextEditingController();
    final candidate = await showDialog<ZxCandidateLens>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('登记知识扩展候选'),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _dialogField(gap, '现有知识缺口'),
                _dialogField(concept, '候选概念/机制'),
                _dialogField(thinker, '思想家/研究体系'),
                _dialogField(work, '一手作品/权威来源'),
                _dialogField(uri, '可核查来源URI'),
                _dialogField(value, '比现有知识新增什么'),
                _dialogField(risks, '反证、风险与适用边界'),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (gap.text.trim().isEmpty || concept.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(
                dialogContext,
                ZxCandidateLens(
                  gap: gap.text.trim(),
                  concept: concept.text.trim(),
                  thinker: thinker.text.trim(),
                  work: work.text.trim(),
                  sourceUri: uri.text.trim(),
                  addedValue: value.text.trim(),
                  risks: risks.text.trim(),
                  createdAtMs: DateTime.now().millisecondsSinceEpoch,
                ),
              );
            },
            child: const Text('保存为候选'),
          ),
        ],
      ),
    );
    for (final controller in <TextEditingController>[
      gap,
      concept,
      thinker,
      work,
      uri,
      value,
      risks,
    ]) {
      controller.dispose();
    }
    if (candidate == null) return;
    await _dao.addCandidate(candidate);
    await _refreshLocalState();
  }

  Future<void> _proposeCandidateWithAi() async {
    final gap = TextEditingController();
    final contextController = TextEditingController();
    final values = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('AI整理扩展候选'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _dialogField(gap, '必须明确的知识缺口'),
            _dialogField(contextController, '可选：情境与现有知识不足'),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (gap.text.trim().isEmpty) return;
              Navigator.pop(
                dialogContext,
                <String>[gap.text.trim(), contextController.text.trim()],
              );
            },
            child: const Text('生成候选'),
          ),
        ],
      ),
    );
    gap.dispose();
    contextController.dispose();
    if (values == null) return;
    setState(() => _working = true);
    final candidate = await _ai.proposeExpansion(
      gap: values[0],
      userContext: values[1],
    );
    if (candidate != null) await _dao.addCandidate(candidate);
    await _refreshLocalState();
    if (!mounted) return;
    setState(() => _working = false);
    _snack(candidate == null
        ? 'AI不可用或输出不合格，未写入候选。'
        : '已保存为候选；它不会进入行动、安全或奖励引擎。');
  }

  Future<void> _setCandidateStatus(int id, String status) async {
    await _dao.updateCandidateStatus(id, status);
    await _refreshLocalState();
    _snack(
      status == 'reviewed_pending_package'
          ? '已标记人工核查通过；仍需发布新版签名知识包才会进入核心。'
          : '候选状态已更新。',
    );
  }

  Future<void> _editPrompts() async {
    final action = TextEditingController(await _promptConfig.actionPrompt());
    final expansion =
        TextEditingController(await _promptConfig.expansionPrompt());
    if (!mounted) return;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('知行树提示词'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: action,
                  minLines: 8,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    labelText: '行动表达增强',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: expansion,
                  minLines: 7,
                  maxLines: 13,
                  decoration: const InputDecoration(
                    labelText: '知识扩展候选',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await _promptConfig.reset();
              if (dialogContext.mounted) Navigator.pop(dialogContext, false);
            },
            child: const Text('恢复默认'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (save == true) {
      await _promptConfig.saveActionPrompt(action.text);
      await _promptConfig.saveExpansionPrompt(expansion.text);
    }
    action.dispose();
    expansion.dispose();
  }

  Future<void> _exportData() async {
    setState(() => _working = true);
    try {
      final snapshot = await _dao.exportSnapshot();
      final text = const JsonEncoder.withIndent('  ').convert(snapshot);
      final now = DateTime.now();
      final fileName =
          'zhixing-tree-${now.year}${_two(now.month)}${_two(now.day)}.json';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出知行树数据',
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(text)),
      );
      if (path == null) {
        await Clipboard.setData(ClipboardData(text: text));
        _snack('未选择保存位置，JSON已复制到剪贴板。');
      } else {
        _snack('导出完成：$path');
      }
    } catch (error) {
      _snack('导出失败：$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deleteAllData() async {
    final confirmed = await _confirm(
      title: '删除全部用户数据？',
      body: '目标、诊断、行动、复盘、金币/XP账本、成长树、反馈和候选都会永久删除。只读知识包会保留。',
      confirmLabel: '永久删除',
      destructive: true,
    );
    if (!confirmed) return;
    await _dao.deleteAllUserData();
    await _refreshLocalState();
    if (!mounted) return;
    setState(() {
      _tree = const ZxTreeState();
      _lensHistory = const <String, double>{};
      _disabledLenses = <String>{};
    });
    _snack('用户数据已删除；知识包仍可离线查询。');
  }

  Widget _heroCard({
    required String title,
    required String body,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) =>
      Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF245A40), Color(0xFF6B8F56)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(body, style: const TextStyle(color: Colors.white, height: 1.5)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _ink,
              ),
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ],
        ),
      );

  Widget _sectionCard({
    required String title,
    required Widget child,
    String subtitle = '',
    Widget? leading,
  }) =>
      Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (leading != null) ...<Widget>[
                    leading,
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    String hint = '',
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint.isEmpty ? null : hint,
            alignLabelWithHint: maxLines > 1,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Widget _dialogField(TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: TextField(
          controller: controller,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    String display,
    ValueChanged<double> onChanged,
  ) =>
      Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label)),
              Text(display, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: max == 1 ? 20 : 119,
            onChanged: onChanged,
          ),
        ],
      );

  Widget _switch(String title, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(title),
        value: value,
        onChanged: onChanged,
      );

  Widget _statusBanner(String title, String body, Color color) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title,
                style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(body),
          ],
        ),
      );

  Widget _actionOption(
    String label,
    String body,
    IconData icon, {
    bool emphasized = false,
  }) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: emphasized
              ? _green.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: emphasized
                ? _green.withValues(alpha: 0.45)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: emphasized ? _green : null),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _labelValue(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label：',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Icon(Icons.circle, size: 5),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );

  Widget _miniTag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: _green,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String body,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 42, color: Colors.black38),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _tableCell(String text, {bool bold = false}) => Padding(
        padding: const EdgeInsets.all(9),
        child: Text(
          text,
          style: TextStyle(fontWeight: bold ? FontWeight.w700 : null),
        ),
      );

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: Colors.red)
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _percent(double value) => '${(value * 100).round()}%';

  static String _proofLabel(ZxProofType value) => switch (value) {
        ZxProofType.selfReport => '自我确认',
        ZxProofType.processTrace => '过程痕迹',
        ZxProofType.outcomeTrace => '结果痕迹',
        ZxProofType.collaborator => '经同意的协作者确认',
        ZxProofType.learning => '学习证据',
      };

  static String _contentTypeLabel(String value) => switch (value) {
        'original_claim' => '原主张',
        'source_synthesis' => '来源内综合',
        'cross_source_synthesis' => '跨来源综合',
        'product_suggestion' => '产品建议',
        _ => value,
      };

  static String _dateLabel(int ms) {
    if (ms <= 0) return '';
    final value = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${value.year}-${_two(value.month)}-${_two(value.day)} '
        '${_two(value.hour)}:${_two(value.minute)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

extension on ZxTreeState {
  String get stageLabel => switch (stage) {
        'sapling' => '幼苗',
        'young' => '小树',
        'branching' => '分枝',
        'canopy' => '成荫',
        'towering' => '参天',
        _ => '种子',
      };
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
