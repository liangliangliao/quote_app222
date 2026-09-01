import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'zhixing_ai_service.dart';
import 'zhixing_agent_service.dart';
import 'zhixing_ai_knowledge_service.dart';
import 'zhixing_dao.dart';
import 'zhixing_engines.dart';
import 'zhixing_extended_models.dart';
import 'zhixing_goal_source_service.dart';
import 'zhixing_knowledge_repository.dart';
import 'zhixing_models.dart';
import 'zhixing_productization.dart';
import 'zhixing_prompt_config.dart';
import 'zhixing_review_engine.dart';
import 'zhixing_remote_knowledge_models.dart';
import 'zhixing_thinker_catalog.dart';
import 'zhixing_tree_visual.dart';
import 'zhixing_user_guide_page.dart';

class ZhixingTreeHomePage extends StatefulWidget {
  const ZhixingTreeHomePage({
    super.key,
    this.initialAgentScene = '',
  });

  final String initialAgentScene;

  @override
  State<ZhixingTreeHomePage> createState() => _ZhixingTreeHomePageState();
}

class _ZhixingTreeHomePageState extends State<ZhixingTreeHomePage>
    with SingleTickerProviderStateMixin {
  static const Color _ink = Color(0xFF17362A);
  static const Color _green = Color(0xFF2F7550);
  static const Color _cream = Color(0xFFF6F3E8);
  static const int _actionTab = 0;
  static const int _thoughtTab = 1;
  static const int _growthTab = 2;
  static const int _mentorTab = 3;

  final ZxKnowledgeRepository _knowledge = ZxKnowledgeRepository();
  final ZxDao _dao = ZxDao();
  final ZxAiService _ai = ZxAiService();
  final ZxAiKnowledgeService _aiKnowledge = ZxAiKnowledgeService();
  final ZxGoalSourceService _goalSources = ZxGoalSourceService();
  final ZxAgentService _agent = ZxAgentService();
  final ZxLocalReviewEngine _localReview = const ZxLocalReviewEngine();
  final ZxBehaviourDiagnoser _diagnoser = const ZxBehaviourDiagnoser();
  final ZxThinkerMatcher _matcher = const ZxThinkerMatcher();
  final ZxActionGenerator _actionGenerator = const ZxActionGenerator();
  final ZxRewardEngine _rewardEngine = const ZxRewardEngine();
  final ZxTreeEngine _treeEngine = const ZxTreeEngine();
  final ZxChallengeFactory _challengeFactory = const ZxChallengeFactory();
  final ZxPromptConfig _promptConfig = ZxPromptConfig();
  final ZxProductizationEngine _productization =
      const ZxProductizationEngine();
  final ZxModuleAssistantEngine _moduleAssistant =
      const ZxModuleAssistantEngine();

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
  final TextEditingController _assistantController = TextEditingController();

  bool _loading = true;
  bool _working = false;
  String _error = '';
  ZxTreeState _tree = const ZxTreeState();
  List<ZxActionPrescription> _actions = const <ZxActionPrescription>[];
  List<ZxCandidateLens> _candidates = const <ZxCandidateLens>[];
  List<ZxAiBook> _aiBooks = const <ZxAiBook>[];
  List<ZxRemoteKnowledgeItem> _remoteKnowledgeItems =
      const <ZxRemoteKnowledgeItem>[];
  List<ZxAiKnowledgeDraft> _aiDrafts = const <ZxAiKnowledgeDraft>[];
  List<ZxReviewReport> _reviewReports = const <ZxReviewReport>[];
  ZxAiKnowledgeDraft? _selectedAiKnowledge;
  bool _useAiKnowledge = false;
  ZxGoalSource _lastGoalSource = ZxGoalSource.zhixingLocal;
  ZxAgentSettings _agentSettings = const ZxAgentSettings();
  ZxAgentScene _agentScene = ZxAgentScene.setGoal;
  ZxRemoteKnowledgeProvider _remoteKnowledgeProvider =
      ZxRemoteKnowledgeProvider.openai;
  ZxRemoteKnowledgeConfig? _remoteKnowledgeConfig;
  Map<String, String> _providerState = const <String, String>{};
  Map<String, double> _lensHistory = const <String, double>{};
  Set<String> _disabledLenses = <String>{};
  // Persisted values are representative lens ids, one token per integrated
  // thought system. A selected system may expose several mechanism lenses to
  // the matcher (for example Nietzsche, Dewey and Bandura).
  Set<String> _selectedLensIds = <String>{};
  bool _personalizationEnabled = true;
  bool _safetyExpanded = false;
  ZxActionPreference _actionPreference = const ZxActionPreference();
  ZxExperienceMode _experienceMode = ZxExperienceMode.direct;
  ZxStarterBlock _starterBlock = ZxStarterBlock.inertia;

  ZxSituationInput? _currentInput;
  ZxDiagnosisResult? _diagnosis;
  ZxMatchResult? _match;
  ZxActionPrescription? _prescription;
  ZxDifficulty? _selectedDifficulty;

  int _availableMinutes = 5;
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
  final Set<String> _compareSystemIds = <String>{};
  String _challengeDimension = '';
  ZxDifficulty? _challengeDifficulty;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _challenges = _challengeFactory.buildAll();
    _initialize();
  }

  List<ZxThinkerGuide> get _selectedSystems => _selectedLensIds
      .map(ZxThinkerCatalog.guideFor)
      .whereType<ZxThinkerGuide>()
      .toList(growable: false);

  List<ZxThinkerLens> _lensesForSystem(ZxThinkerGuide guide) =>
      ZxThinkerCatalog.lensesFor(
        guide,
        _knowledge.lenses,
        disabledLensIds: _disabledLenses,
      );

  ZxThinkerGuide? _systemForLens(String lensId) =>
      ZxThinkerCatalog.guideFor(lensId);

  String _systemLabelForLens(ZxThinkerLens lens) {
    final system = _systemForLens(lens.id);
    if (system == null) return '${lens.thinker} · ${lens.name}';
    if (system.lensIds.length == 1) return system.displayName;
    return '${system.displayName} · 当前镜头：${lens.name}';
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
      _assistantController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _knowledge.load();
      final catalogIssues =
          ZxThinkerCatalog.validateAgainst(_knowledge.lenses);
      if (catalogIssues.isNotEmpty) {
        throw StateError('思想导航完整性校验失败：${catalogIssues.join('；')}');
      }
      await _dao.ensureTables();
      await _dao.seedKnowledge(_knowledge);
      final tree = _treeEngine.refreshTemporalState(await _dao.loadTree());
      final actions = await _dao.actions();
      final candidates = await _dao.candidates();
      final aiBooks = await _dao.aiBooks();
      final remoteKnowledgeProvider =
          await _aiKnowledge.remoteKnowledgeProvider();
      final remoteKnowledgeItems = await _dao.remoteKnowledgeItems(
        includeDeleted: true,
      );
      final remoteKnowledgeConfig = await _aiKnowledge.remoteKnowledgeConfig(
        provider: remoteKnowledgeProvider,
      );
      final aiDrafts = await _dao.aiKnowledgeDrafts();
      final reviewReports = await _dao.reviewReports();
      final agentSettings = await _dao.agentSettings();
      final goals = await _dao.goals();
      final provider = await _ai.providerState();
      final history = await _dao.historicalLensResponse();
      final disabled = await _dao.disabledLenses();
      final selected = await _dao.selectedLenses();
      final personalization = await _dao.personalizationEnabled();
      final actionPreference = await _dao.actionPreference();
      final normalizedSelected =
          ZxThinkerCatalog.normalizeSelectionTokens(selected)
              .where((token) {
                final system = ZxThinkerCatalog.guideFor(token);
                return system != null &&
                    system.lensIds.any((id) => !disabled.contains(id));
              })
              .take(3)
              .toSet();
      if (!setEquals(selected, normalizedSelected)) {
        await _dao.setSelectedLenses(normalizedSelected);
      }
      final agentScene = _agent.decide(
        goals: goals,
        actions: actions,
        selectedThoughtCount: normalizedSelected.length,
        hasRecentReport: reviewReports.isNotEmpty,
      );
      if (!mounted) return;
      setState(() {
        _tree = tree;
        _actions = actions;
        _candidates = candidates;
        _aiBooks = aiBooks;
        _remoteKnowledgeProvider = remoteKnowledgeProvider;
        _remoteKnowledgeItems = remoteKnowledgeItems;
        _remoteKnowledgeConfig = remoteKnowledgeConfig;
        _aiDrafts = aiDrafts;
        _reviewReports = reviewReports;
        _selectedAiKnowledge =
            aiDrafts.isEmpty ? null : aiDrafts.first;
        _agentSettings = agentSettings;
        _agentScene = agentScene;
        _providerState = provider;
        _lensHistory = history;
        _disabledLenses = disabled;
        _selectedLensIds = normalizedSelected;
        _personalizationEnabled = personalization;
        _actionPreference = actionPreference;
        _experienceMode = actionPreference.mode;
        _searchResults = _knowledge.search('');
        _loading = false;
      });
      if (widget.initialAgentScene.trim().isNotEmpty) {
        final requested =
            ZxAgentSceneX.parse(widget.initialAgentScene.trim());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _tabs.animateTo(_tabForAgentScene(requested));
          _snack('行动导师：' + requested.title);
        });
      }
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
    final aiBooks = await _dao.aiBooks();
    final remoteKnowledgeProvider =
        await _aiKnowledge.remoteKnowledgeProvider();
    final remoteKnowledgeItems = await _dao.remoteKnowledgeItems(
      includeDeleted: true,
    );
    final remoteKnowledgeConfig = await _aiKnowledge.remoteKnowledgeConfig(
      provider: remoteKnowledgeProvider,
    );
    final aiDrafts = await _dao.aiKnowledgeDrafts();
    final reports = await _dao.reviewReports();
    final goals = await _dao.goals();
    final agentSettings = await _dao.agentSettings();
    final tree = _treeEngine.refreshTemporalState(await _dao.loadTree());
    final selectedDraftId = _selectedAiKnowledge?.id ?? 0;
    final nextSelectedDraft = aiDrafts.where(
      (item) => item.id == selectedDraftId,
    );
    if (!mounted) return;
    setState(() {
      _actions = actions;
      _candidates = candidates;
      _aiBooks = aiBooks;
      _remoteKnowledgeProvider = remoteKnowledgeProvider;
      _remoteKnowledgeItems = remoteKnowledgeItems;
      _remoteKnowledgeConfig = remoteKnowledgeConfig;
      _aiDrafts = aiDrafts;
      _reviewReports = reports;
      _selectedAiKnowledge = nextSelectedDraft.isNotEmpty
          ? nextSelectedDraft.first
          : aiDrafts.isEmpty
              ? null
              : aiDrafts.first;
      _agentSettings = agentSettings;
      _agentScene = _agent.decide(
        goals: goals,
        actions: actions,
        selectedThoughtCount: _selectedLensIds.length,
        hasRecentReport: reports.isNotEmpty,
      );
      _tree = tree;
    });
  }

  int _tabForAgentScene(ZxAgentScene scene) {
    switch (scene) {
      case ZxAgentScene.chooseThought:
        return _thoughtTab;
      case ZxAgentScene.setGoal:
      case ZxAgentScene.startAction:
      case ZxAgentScene.trackProgress:
      case ZxAgentScene.requestReview:
      case ZxAgentScene.continueCycle:
        return _actionTab;
    }
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
          actions: <Widget>[
            IconButton(
              tooltip: '使用说明',
              onPressed: _openUserGuide,
              icon: const Icon(Icons.help_outline_rounded),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const <Tab>[
              Tab(text: '现在做'),
              Tab(text: '思想工具'),
              Tab(text: '成长'),
              Tab(text: '导师'),
              Tab(text: '更多'),
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
                          _buildActionCockpit(),
                          _buildKnowledgePage(),
                          _buildGrowthHub(),
                          _buildAiMentorPage(),
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
        floatingActionButton: _loading || _error.isNotEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: _showModuleAssistant,
                icon: const Icon(Icons.support_agent_outlined),
                label: const Text('问助手'),
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

  Widget _buildActionCockpit() {
    final active = _actions
        .where((item) => item.status == ZxActionStatus.active)
        .toList(growable: false);
    return RefreshIndicator(
      onRefresh: _refreshLocalState,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: <Widget>[
          _buildAgentNextStepCard(active),
          const SizedBox(height: 12),
          _buildPreferenceStrip(),
          const SizedBox(height: 12),
          if (active.isNotEmpty)
            ...active.take(1).map(_buildActiveCockpitCard)
          else
            _buildCompactStartForm(),
          if (_diagnosis != null &&
              !_diagnosis!.safety.actionAllowed) ...<Widget>[
            const SizedBox(height: 12),
            _buildSafetyBoundaryResult(),
          ],
          if (_prescription != null) ...<Widget>[
            const SizedBox(height: 12),
            _buildPrescriptionResult(),
          ],
          if (_reviewReports.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _buildLatestReportCard(),
          ],
          const SizedBox(height: 12),
          _treeSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildAgentNextStepCard(List<ZxActionPrescription> active) {
    final title = active.isNotEmpty
        ? '今天只推进这一项'
        : switch (_agentScene) {
            ZxAgentScene.setGoal => '先给我一个真实目标或问题',
            ZxAgentScene.chooseThought => '系统会先推荐思想，你再决定',
            ZxAgentScene.startAction => '把目标变成现在能做的一步',
            ZxAgentScene.trackProgress => '回到当前动作，不重新规划',
            ZxAgentScene.requestReview => '先反馈现实结果，再安排下一步',
            ZxAgentScene.continueCycle => '把上轮认识转成今天的一步',
          };
    final body = active.isNotEmpty
        ? active.first.mainAction
        : _productization.motivationLine(
            _actionPreference.copyWith(mode: _experienceMode),
          );
    return Card(
      color: const Color(0xFFE7F2EA),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(height: 1.5)),
            if (active.isEmpty) ...<Widget>[
              const SizedBox(height: 10),
              const Text(
                '你只提供目标和真实反馈；卡点判断、思想匹配、行动拆解与复盘由系统承担。',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceStrip() {
    final profile = _actionPreference.copyWith(mode: _experienceMode);
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.tune_rounded)),
        title: Text(
          _actionPreference.completed ? '导师已按你的偏好呈现' : '1分钟让导师更懂你（可跳过）',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(profile.summary),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: _editActionPreference,
      ),
    );
  }

  Widget _buildCompactStartForm() {
    return _sectionCard(
      title: '你现在想推进或解决什么？',
      subtitle: '一个目标 + 一个卡点就够了；思想与第一步由系统先推荐。',
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '直接试跑一个完整案例',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: zxStarterCases
                .map(
                  (item) => ActionChip(
                    avatar: const Icon(Icons.play_arrow_rounded, size: 17),
                    label: Text(item.title),
                    onPressed: () => _applyStarterCase(item),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          _field(
            _goalController,
            '我现在想推进 / 解决',
            hint: '例如：投递第一份简历、出门走一走、开始写文章',
            maxLines: 2,
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickGoalFromSources,
                  icon: const Icon(Icons.move_to_inbox_outlined),
                  label: const Text('从已有目标导入'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '可从知行树、Todo目标价值系统或 Microsoft To Do 导入',
                onPressed: _showGoalSourceHelp,
                icon: const Icon(Icons.info_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '现在最接近哪一种卡点？',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: ZxStarterBlock.values
                .map(
                  (block) => ChoiceChip(
                    label: Text(block.label),
                    selected: _starterBlock == block,
                    onSelected: (_) => setState(() => _starterBlock = block),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          const Text(
            '这次用哪种方式开始？',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: ZxExperienceMode.values
                .map(
                  (mode) => ChoiceChip(
                    avatar: Icon(_experienceIcon(mode), size: 17),
                    label: Text(mode.label),
                    selected: _experienceMode == mode,
                    onSelected: (_) => setState(() {
                      _experienceMode = mode;
                      if (mode == ZxExperienceMode.gentle) {
                        _availableMinutes = mathMin(_availableMinutes, 5);
                      } else if (mode == ZxExperienceMode.challenge) {
                        _availableMinutes = mathMax(_availableMinutes, 10);
                      }
                    }),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 5),
          Text(
            _experienceMode.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('补充下一步、价值或安全信息（可选）'),
            subtitle: const Text('不填也能生成；只有确实重要时再展开。'),
            children: <Widget>[
              _field(
                _targetController,
                '你已经想到的下一小步',
                hint: '留空时由系统自动拆解',
                maxLines: 2,
              ),
              _field(
                _valueController,
                '为什么值得做',
                hint: '留空时使用你在偏好小测中的动力锚点',
                maxLines: 2,
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '本轮可投入时间',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                children: <int>[2, 5, 10, 15]
                    .map(
                      (minutes) => ChoiceChip(
                        label: Text(minutes.toString() + '分钟'),
                        selected: _availableMinutes == minutes,
                        onSelected: (_) =>
                            setState(() => _availableMinutes = minutes),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 10),
              ExpansionTile(
                initiallyExpanded: _safetyExpanded,
                tilePadding: EdgeInsets.zero,
                title: const Text('涉及危险、专业决定或他人重大权益？'),
                subtitle: const Text('普通工作、学习和生活小行动保持收起。'),
                onExpansionChanged: (value) =>
                    setState(() => _safetyExpanded = value),
                children: <Widget>[
                  _switch('会影响第三方重要权益', _thirdPartyImpact,
                      (value) => setState(() => _thirdPartyImpact = value)),
                  _switch('后果难以撤销', _irreversibleImpact,
                      (value) => setState(() => _irreversibleImpact = value)),
                  _switch(
                    '涉及医疗、药物、法律或重大财务判断',
                    _professionalDecision,
                    (value) => setState(() => _professionalDecision = value),
                  ),
                  _switch('存在即时人身危险', _acuteDanger,
                      (value) => setState(() => _acuteDanger = value)),
                  _switch(
                    '存在严重失控或无法维持基本功能',
                    _severeFunctionLoss,
                    (value) => setState(() => _severeFunctionLoss = value),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _working ? null : _generatePrescription,
              icon: const Icon(Icons.bolt_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Text('给我一个现在能做的动作'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(
                _useAiKnowledge
                    ? Icons.auto_awesome_outlined
                    : Icons.verified_outlined,
                size: 17,
                color: _useAiKnowledge ? Colors.deepPurple : _green,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _useAiKnowledge
                      ? '本轮使用AI派生知识；审核本地库仍负责安全基线。'
                      : '默认使用审核本地知识库；离线也能完成闭环。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () => _tabs.animateTo(_mentorTab),
                child: const Text('切换'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCockpitCard(ZxActionPrescription action) {
    final lens = _knowledge.lensById(action.primaryLensId);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.play_circle_fill_rounded, color: _green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    action.goalTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _miniTag(action.difficulty.code),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              '现在只做',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              action.mainAction,
              style: const TextStyle(
                fontSize: 19,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _statusBanner(
              '做到这里就算完成',
              action.completionDefinition,
              _green,
            ),
            const SizedBox(height: 8),
            Text(
              '本轮运用：' +
                  (lens == null
                      ? action.primaryLensId
                      : _systemLabelForLens(lens)),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _green,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _reviewAction(action),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('反馈结果'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showLowerLoad(action),
                    icon: const Icon(Icons.keyboard_double_arrow_down),
                    label: const Text('太难，缩小'),
                  ),
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('为什么这样做？'),
              subtitle: const Text('理论、支持条件与证据按需展开'),
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(action.thoughtLens),
                ),
                const SizedBox(height: 8),
                _labelValue('启动线索', action.cue),
                ...action.supportChanges.map(_bullet),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: action.evidenceLocators
                      .map(
                        (locator) => ActionChip(
                          label: Text(locator),
                          avatar: const Icon(
                            Icons.fact_check_outlined,
                            size: 16,
                          ),
                          onPressed: () => _openEvidenceLocator(locator),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestReportCard() {
    final report = _reviewReports.first;
    return _sectionCard(
      title: '上一次行动已经变成下一步',
      subtitle: report.origin.label + ' · ' + report.recommendedDecision.label,
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _labelValue('现实结论', report.summary),
          _labelValue('发现的卡点', report.barrierFinding),
          _statusBanner('下一小步', report.nextAction, _green),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('查看思想调整理由'),
            children: <Widget>[
              _labelValue('系统建议', report.recommendedDecision.label),
              _labelValue('理由', report.rationale),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthHub() => DefaultTabController(
        length: 2,
        child: Column(
          children: <Widget>[
            const Material(
              color: Color(0xFFF6F3E8),
              child: TabBar(
                tabs: <Tab>[
                  Tab(text: '我的成长树'),
                  Tab(text: '自选挑战'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _buildTreePage(),
                  _buildChallengeGarden(),
                ],
              ),
            ),
          ],
        ),
      );

  Future<void> _openUserGuide() => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ZhixingUserGuidePage(),
        ),
      );

  Future<void> _showGoalSourceHelp() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('三路目标导入'),
          content: const Text(
            '可读取知行树当前目标、外部数据同步中的 Todo 目标价值系统，以及 Microsoft To Do 最近一次同步的未完成任务。选择只会复制目标和步骤，不会修改源模块。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );

  void _applyStarterCase(ZxStarterCase item) {
    setState(() {
      _goalController.text = item.goal;
      _targetController.text = item.nextStep;
      _valueController.text = item.valueReason;
      _starterBlock = item.block;
      _experienceMode = item.mode;
      _availableMinutes = item.minutes;
      _diagnosis = null;
      _match = null;
      _prescription = null;
    });
    _snack('案例已填入；点击“给我一个现在能做的动作”即可跑通。');
  }

  IconData _experienceIcon(ZxExperienceMode mode) => switch (mode) {
        ZxExperienceMode.gentle => Icons.spa_outlined,
        ZxExperienceMode.direct => Icons.arrow_forward_rounded,
        ZxExperienceMode.challenge => Icons.flag_outlined,
        ZxExperienceMode.experiment => Icons.science_outlined,
      };

  int mathMin(int a, int b) => a < b ? a : b;

  int mathMax(int a, int b) => a > b ? a : b;

  Future<void> _showLowerLoad(ZxActionPrescription action) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '这不是放弃，是校准行动负荷',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  action.lowerLoadAlternative,
                  style: const TextStyle(fontSize: 17, height: 1.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  '做完后点“反馈结果”，选择“做了更安全、更小的一步”，系统会把这条现实证据写入复盘。',
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('好，现在只做这个'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _editActionPreference() async {
    var draft = _actionPreference.copyWith(mode: _experienceMode);
    final result = await showModalBottomSheet<ZxActionPreference>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '1分钟行动偏好',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text('没有对错；以后可随时修改，也可关闭个性化。'),
                const SizedBox(height: 18),
                const Text('1 · 我更愿意怎样开始',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: ZxExperienceMode.values
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item.label),
                          selected: draft.mode == item,
                          onSelected: (_) => setSheetState(
                            () => draft = draft.copyWith(mode: item),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 16),
                const Text('2 · 什么最能拉动我',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: ZxMotivationAnchor.values
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item.label),
                          selected: draft.anchor == item,
                          onSelected: (_) => setSheetState(
                            () => draft = draft.copyWith(anchor: item),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 16),
                const Text('3 · 我希望导师怎样说',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: ZxMentorTone.values
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item.label),
                          selected: draft.tone == item,
                          onSelected: (_) => setSheetState(
                            () => draft = draft.copyWith(tone: item),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 16),
                const Text('4 · 我更愿意从哪种优势出发',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: ZxStrengthPreference.values
                      .map(
                        (item) => ChoiceChip(
                          label: Text(item.label),
                          selected: draft.strength == item,
                          onSelected: (_) => setSheetState(
                            () => draft = draft.copyWith(strength: item),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      draft.copyWith(completed: true),
                    ),
                    child: const Text('保存我的偏好'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    await _dao.saveActionPreference(result);
    if (!mounted) return;
    setState(() {
      _actionPreference = result;
      _experienceMode = result.mode;
    });
    _snack('偏好已保存；它只改变呈现与负荷，不越过安全规则。');
  }

  Future<void> _showModuleAssistant() async {
    final hasActive = _actions.any(
      (item) => item.status == ZxActionStatus.active,
    );
    var answer = _moduleAssistant.answer(
      _assistantController.text,
      hasActiveAction: hasActive,
      hasRecentReport: _reviewReports.isNotEmpty,
      aiConfigured: _providerState['available'] == '1',
    );
    var visibleBody = answer.body;
    var asking = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              4,
              18,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    CircleAvatar(child: Icon(Icons.support_agent_outlined)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '知行树助手',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: <String>[
                    '我该从哪里开始？',
                    '这一步太难怎么办？',
                    '如何更换指导思想？',
                    'AI书库怎么用？',
                  ]
                      .map(
                        (question) => ActionChip(
                          label: Text(question),
                          onPressed: () => setSheetState(
                            () => _assistantController.text = question,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _assistantController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '直接问功能、流程或下一步',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: asking
                        ? null
                        : () async {
                            final question =
                                _assistantController.text.trim();
                            final local = _moduleAssistant.answer(
                              question,
                              hasActiveAction: hasActive,
                              hasRecentReport: _reviewReports.isNotEmpty,
                              aiConfigured:
                                  _providerState['available'] == '1',
                            );
                            setSheetState(() {
                              answer = local;
                              visibleBody = local.body;
                              asking =
                                  _providerState['available'] == '1';
                            });
                            if (_providerState['available'] == '1') {
                              final aiText = await _ai.answerModuleQuestion(
                                question: question,
                                localAnswer:
                                    local.title + '\n' + local.body,
                                featureGrounding:
                                    _moduleAssistant.groundingText(),
                                currentState: '导师状态：' +
                                    _agentScene.title +
                                    '；活动行动：' +
                                    (hasActive ? '有' : '无') +
                                    '；已选思想体系：' +
                                    _selectedLensIds.length.toString() +
                                    '；最近复盘：' +
                                    (_reviewReports.isNotEmpty ? '有' : '无'),
                              );
                              if (!sheetContext.mounted) return;
                              setSheetState(() {
                                asking = false;
                                if (aiText.isNotEmpty) visibleBody = aiText;
                              });
                            }
                          },
                    icon: const Icon(Icons.send_rounded),
                    label: Text(
                      asking
                          ? '正在结合当前状态回答…'
                          : _providerState['available'] == '1'
                              ? '问助手（本地功能图 + AI）'
                              : '问助手（本地功能图）',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  color: const Color(0xFFE7F2EA),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          answer.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 7),
                        SelectableText(
                          visibleBody,
                          style: const TextStyle(height: 1.5),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _tabs.animateTo(answer.area.tabIndex);
                          },
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: Text(
                            answer.actionLabel + ' · ' + answer.area.label,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Kept as a compatibility layout while the V3 cockpit is validated.
  // ignore: unused_element
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
                ? _selectedLensIds.isEmpty
                    ? '直接写下目标，由系统先推荐思想并落实为今天的一小步。'
                    : '已选思想准备就绪：现在直接生成一项可立即执行的行动。'
                : active.first.mainAction,
            buttonLabel: active.isEmpty
                ? '立即行动'
                : '查看当前行动',
            onPressed: () => _tabs.animateTo(_actionTab),
          ),
          const SizedBox(height: 14),
          _treeSummaryCard(),
          const SizedBox(height: 14),
          _sectionCard(
            title: '当前行动与复盘',
            subtitle: '完成、未完成或改做更小一步都可以复盘；复盘后可继续、换思想或融合思想。',
            initiallyExpanded: active.isNotEmpty,
            child: active.isEmpty
                ? _emptyState(
                    icon: Icons.route_outlined,
                    title: '还没有激活的行动',
                    body: '选择思想后进入“立即行动”，只需写下现在想做的事。',
                  )
                : Column(
                    children: active
                        .take(3)
                        .map(_buildActionCard)
                        .toList(growable: false),
                  ),
          ),
          const SizedBox(height: 14),
          if (_reviewReports.isNotEmpty) ...<Widget>[
            _sectionCard(
              title: '最近复盘报告',
              subtitle: _reviewReports.first.origin.label +
                  ' · 自动依据行动反馈生成',
              initiallyExpanded: true,
              leading: CircleAvatar(
                child: Icon(
                  _reviewReports.first.origin ==
                          ZxKnowledgeOrigin.aiDerived
                      ? Icons.auto_awesome_outlined
                      : Icons.fact_check_outlined,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _labelValue('总结', _reviewReports.first.summary),
                  _labelValue(
                    '关键发现',
                    _reviewReports.first.barrierFinding,
                  ),
                  _labelValue(
                    '建议',
                    _reviewReports.first.recommendedDecision.label,
                  ),
                  _labelValue('理由', _reviewReports.first.rationale),
                  _labelValue('下一小步', _reviewReports.first.nextAction),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
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

  // Kept as a compatibility layout while the V3 cockpit is validated.
  // ignore: unused_element
  Widget _buildPrescriptionPage() {
    final selectedSystems = _selectedSystems;
    final selectedLenses = selectedSystems
        .expand(_lensesForSystem)
        .toList(growable: false);
    final quickActions = selectedLenses
        .expand((lens) => lens.actionTemplates)
        .toSet()
        .take(6)
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
      children: <Widget>[
        _sectionCard(
          title: '把一个“知”变成现在的一步',
          subtitle: '这不是疾病诊断，也不是调查。普通行动只需写下你现在想做什么。',
          expansionKey: ValueKey<bool>(_prescription == null),
          initiallyExpanded: _prescription == null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '知识方案',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('本地审核知识库'),
                    avatar: const Icon(Icons.verified_outlined, size: 17),
                    selected: !_useAiKnowledge,
                    onSelected: (_) =>
                        setState(() => _useAiKnowledge = false),
                  ),
                  ChoiceChip(
                    label: const Text('AI派生知识'),
                    avatar: const Icon(Icons.auto_awesome_outlined, size: 17),
                    selected: _useAiKnowledge,
                    onSelected: (_) {
                      if (_selectedAiKnowledge == null) {
                        _snack('请先在“AI与导师”中上传著作并生成派生思想。');
                        _tabs.animateTo(_mentorTab);
                        return;
                      }
                      setState(() => _useAiKnowledge = true);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_useAiKnowledge && _selectedAiKnowledge != null)
                _statusBanner(
                  'AI派生 · 本地保存 · 不替换核心库',
                  _selectedAiKnowledge!.thinker +
                      ' · ' +
                      _selectedAiKnowledge!.title,
                  Colors.deepPurple,
                )
              else if (selectedSystems.isEmpty)
                _statusBanner(
                  '尚未选择行动思想',
                  '可以先从${_knowledge.packageInfo.systemCount}套完整思想体系中自主选择；'
                      '也可直接生成，由系统给出推荐供你决定。',
                  Colors.orange.shade800,
                )
              else
                _statusBanner(
                  selectedSystems.length == 1
                      ? '单一思想体系指导'
                      : '融合思想体系指导',
                  selectedSystems
                      .map((system) => system.displayName)
                      .join('  +  '),
                  _green,
                ),
              if (_useAiKnowledge && _aiDrafts.length > 1) ...<Widget>[
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: _selectedAiKnowledge?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '本轮使用的AI派生思想',
                    border: OutlineInputBorder(),
                  ),
                  items: _aiDrafts
                      .map(
                        (draft) => DropdownMenuItem<int>(
                          value: draft.id,
                          child: Text(draft.thinker + ' · ' + draft.title),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (id) {
                    if (id == null) return;
                    setState(
                      () => _selectedAiKnowledge =
                          _aiDrafts.firstWhere((item) => item.id == id),
                    );
                  },
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () =>
                        _tabs.animateTo(
                          _useAiKnowledge ? _mentorTab : _thoughtTab,
                        ),
                    icon: Icon(
                      _useAiKnowledge
                          ? Icons.folder_copy_outlined
                          : Icons.account_tree_outlined,
                    ),
                    label: Text(
                      _useAiKnowledge
                          ? '管理AI派生思想'
                          : selectedSystems.isEmpty
                              ? '先看懂并选择思想'
                              : '修改所选思想',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickGoalFromSources,
                    icon: const Icon(Icons.move_to_inbox_outlined),
                    label: Text('从已有目标导入 · ' + _lastGoalSource.label),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _field(
                _goalController,
                '现在想推进什么？',
                hint: '例如：开始写论文、出门散步、整理桌面',
                maxLines: 2,
              ),
              _field(
                _targetController,
                '下一小步（可留空）',
                hint: '留空时，系统会把目标缩成可立即开始的一步',
                maxLines: 2,
              ),
              _field(
                _valueController,
                '为什么值得做？（可留空）',
                hint: '例如：学习、健康、责任、关系或创造',
                maxLines: 2,
              ),
              const Text(
                '这次愿意先投入多久？',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <int>[2, 5, 10, 15]
                    .map(
                      (minutes) => ChoiceChip(
                        label: Text('$minutes分钟'),
                        selected: _availableMinutes == minutes,
                        onSelected: (_) =>
                            setState(() => _availableMinutes = minutes),
                      ),
                    )
                    .toList(growable: false),
              ),
              if (quickActions.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                const Text(
                  '所选思想提供的行动入口',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: quickActions
                      .map(
                        (template) => ActionChip(
                          avatar: const Icon(Icons.bolt_outlined, size: 17),
                          label: Text(template),
                          onPressed: () =>
                              setState(() => _targetController.text = template),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '必要安全检查',
          subtitle: '普通学习、工作和生活小行动无需填写；仅在涉及重大影响时展开。',
          child: ExpansionTile(
            initiallyExpanded: _safetyExpanded,
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            leading: const Icon(Icons.shield_outlined),
            title: const Text('这项行动涉及危险、专业判断或他人重大权益吗？'),
            subtitle: const Text('如不涉及，保持收起并直接开始。'),
            onExpansionChanged: (expanded) =>
                setState(() => _safetyExpanded = expanded),
            children: <Widget>[
              _switch('会影响第三方重要权益', _thirdPartyImpact,
                  (value) => setState(() => _thirdPartyImpact = value)),
              _switch('后果难以撤销', _irreversibleImpact,
                  (value) => setState(() => _irreversibleImpact = value)),
              _switch('涉及医疗、药物、法律或重大财务判断', _professionalDecision,
                  (value) => setState(() => _professionalDecision = value)),
              _switch('存在即时人身危险', _acuteDanger,
                  (value) => setState(() => _acuteDanger = value)),
              _switch('存在严重失控或无法维持基本功能', _severeFunctionLoss,
                  (value) => setState(() => _severeFunctionLoss = value)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _working ? null : _generatePrescription,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Text('生成一个可立即执行的行动'),
          ),
        ),
        if (_diagnosis != null && !_diagnosis!.safety.actionAllowed) ...<Widget>[
          const SizedBox(height: 16),
          _buildSafetyBoundaryResult(),
        ],
        if (_prescription != null) ...<Widget>[
          const SizedBox(height: 12),
          _buildPrescriptionResult(),
        ],
      ],
    );
  }

  Future<void> _pickGoalFromSources() async {
    var source = _lastGoalSource;
    var loading = true;
    var error = '';
    var candidates = <ZxGoalCandidate>[];
    try {
      candidates = await _goalSources.load(source);
      loading = false;
    } catch (e) {
      loading = false;
      error = e.toString();
    }
    if (!mounted) return;
    final selected = await showDialog<ZxGoalCandidate>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('导入已有目标'),
          content: SizedBox(
            width: 620,
            height: 470,
            child: Column(
              children: <Widget>[
                DropdownButtonFormField<ZxGoalSource>(
                  value: source,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '目标来源',
                    border: OutlineInputBorder(),
                  ),
                  items: ZxGoalSource.values
                      .map(
                        (item) => DropdownMenuItem<ZxGoalSource>(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (next) async {
                    if (next == null) return;
                    setDialogState(() {
                      source = next;
                      loading = true;
                      error = '';
                      candidates = <ZxGoalCandidate>[];
                    });
                    try {
                      final loaded = await _goalSources.load(next);
                      if (!dialogContext.mounted) return;
                      setDialogState(() {
                        candidates = loaded;
                        loading = false;
                      });
                    } catch (e) {
                      if (!dialogContext.mounted) return;
                      setDialogState(() {
                        error = e.toString();
                        loading = false;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : error.isNotEmpty
                          ? Center(child: SelectableText(error))
                          : candidates.isEmpty
                              ? const Center(
                                  child: Text(
                                    '没有可导入的目标。Microsoft To Do 会读取外部数据同步模块最近一次同步的未完成任务。',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: candidates.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final item = candidates[index];
                                    return ListTile(
                                      leading: Icon(
                                        item.source ==
                                                ZxGoalSource.microsoftTodo
                                            ? Icons.check_circle_outline
                                            : item.source ==
                                                    ZxGoalSource.todoGoalValue
                                                ? Icons.flag_outlined
                                                : Icons.park_outlined,
                                      ),
                                      title: Text(item.title),
                                      subtitle: Text(
                                        <String>[
                                          item.valueDirection,
                                          item.nextStep,
                                          item.dueLabel,
                                        ]
                                            .where(
                                              (value) =>
                                                  value.trim().isNotEmpty,
                                            )
                                            .join('\n'),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () =>
                                          Navigator.pop(dialogContext, item),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() {
      _lastGoalSource = selected.source;
      _goalController.text = selected.title;
      if (selected.valueDirection.trim().isNotEmpty) {
        _valueController.text = selected.valueDirection.trim();
      }
      if (selected.nextStep.trim().isNotEmpty) {
        _targetController.text = selected.nextStep.trim();
      }
    });
    _snack('已从' + selected.source.label + '导入；原目标数据不会被修改。');
  }

  Future<void> _generatePrescription() async {
    if (_goalController.text.trim().isEmpty) {
      _snack('只需先写下你现在想推进什么。');
      return;
    }
    FocusScope.of(context).unfocus();
    final input = _buildSituationInput();
    final diagnosis = _diagnoser.diagnose(input);
    ZxMatchResult? match;
    ZxActionPrescription? prescription;
    String aiError = '';
    if (diagnosis.safety.actionAllowed) {
      final selectedSystems = _selectedSystems;
      final manuallySelected = selectedSystems
          .expand(_lensesForSystem)
          .toList(growable: false);
      final matched = _matcher.match(
        input: input,
        diagnosis: diagnosis,
        lenses:
            manuallySelected.isEmpty ? _knowledge.lenses : manuallySelected,
        historicalResponse:
            _personalizationEnabled ? _lensHistory : const <String, double>{},
        disabledLensIds: _disabledLenses,
      );
      match = _alignMatchToThoughtSystems(matched, selectedSystems);
      final localPrescription = _actionGenerator.generate(
        input: input,
        diagnosis: diagnosis,
        match: match,
      )!;
      prescription = localPrescription;
      if (_useAiKnowledge && _selectedAiKnowledge != null) {
        setState(() => _working = true);
        try {
          prescription = await _aiKnowledge.generateAction(
            knowledge: _selectedAiKnowledge!,
            localBaseline: localPrescription,
            input: input,
            diagnosis: diagnosis,
          );
        } catch (error) {
          aiError = error.toString();
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _currentInput = input;
      _diagnosis = diagnosis;
      _match = match;
      _prescription = prescription;
      _selectedDifficulty = diagnosis.suggestedDifficulty;
      _working = false;
    });
    if (aiError.isNotEmpty) {
      _snack('AI派生方案生成失败，已安全回退到本地方案：$aiError');
    }
  }

  ZxMatchResult _alignMatchToThoughtSystems(
    ZxMatchResult matched,
    List<ZxThinkerGuide> selectedSystems,
  ) {
    final primarySystem = _systemForLens(matched.primary.id);
    final selectedSystemIds =
        selectedSystems.map((item) => item.systemId).toSet();

    bool isAllowedComplement(ZxThinkerLens lens) {
      final system = _systemForLens(lens.id);
      if (system == null || system.systemId == primarySystem?.systemId) {
        return false;
      }
      return selectedSystemIds.isEmpty ||
          selectedSystemIds.contains(system.systemId);
    }

    ZxThinkerLens? complementary;
    if (selectedSystems.length != 1) {
      final existing = matched.complementary;
      if (existing != null && isAllowedComplement(existing)) {
        complementary = existing;
      } else {
        for (final score in matched.ranking) {
          if (score.disqualified || score.total < 0.4) continue;
          final lens = _knowledge.lensById(score.lensId);
          if (lens != null && isAllowedComplement(lens)) {
            complementary = lens;
            break;
          }
        }
      }
    }

    final primarySystemTensions =
        primarySystem?.tensions.take(1) ?? const <String>[];
    final complementarySystemTensions =
        _systemForLens(complementary?.id ?? '')?.tensions.take(1) ??
            const <String>[];
    return ZxMatchResult(
      primary: matched.primary,
      complementary: complementary,
      ranking: matched.ranking,
      lowMatch: matched.lowMatch,
      lowMatchReason: matched.lowMatchReason,
      uncertainty: matched.uncertainty,
      conflictNotes: <String>[
        ...matched.primary.tensionLinks.take(1),
        ...primarySystemTensions,
        if (complementary != null)
          ...complementary.tensionLinks.take(1),
        ...complementarySystemTensions,
      ].toSet().take(3).toList(growable: false),
      createdAtMs: matched.createdAtMs,
    );
  }

  ZxSituationInput _buildSituationInput() {
    final shaped = _productization.buildInput(
      goal: _goalController.text,
      nextStep: _targetController.text,
      valueReason: _valueController.text,
      availableMinutes: _availableMinutes,
      block: _starterBlock,
      preference: _actionPreference.copyWith(mode: _experienceMode),
      cue: _cueController.text,
      thirdPartyImpact: _thirdPartyImpact,
      irreversibleImpact: _irreversibleImpact,
      professionalDecision: _professionalDecision,
      acuteDanger: _acuteDanger,
      severeFunctionLoss: _severeFunctionLoss,
    );
    return ZxSituationInput(
      goalTitle: shaped.goalTitle,
      recentEvent: _eventController.text.trim().isEmpty
          ? shaped.recentEvent
          : _eventController.text.trim(),
      targetBehavior: shaped.targetBehavior,
      valueReason: shaped.valueReason,
      thought: _thoughtController.text.trim().isEmpty
          ? shaped.thought
          : _thoughtController.text.trim(),
      emotion: _emotionController.text.trim().isEmpty
          ? shaped.emotion
          : _emotionController.text.trim(),
      urge: _urgeController.text.trim().isEmpty
          ? shaped.urge
          : _urgeController.text.trim(),
      actualAction: _actualController.text.trim().isEmpty
          ? shaped.actualAction
          : _actualController.text.trim(),
      cue: shaped.cue,
      availableMinutes: shaped.availableMinutes,
      bodyCapacity: shaped.bodyCapacity,
      attentionCapacity: shaped.attentionCapacity,
      sleepCapacity: shaped.sleepCapacity,
      autonomy: shaped.autonomy,
      importance: shaped.importance,
      selfEfficacy: shaped.selfEfficacy,
      knowsHow: shaped.knowsHow && _knowsHow,
      hasTime: shaped.hasTime && _hasTime,
      hasTools: shaped.hasTools && _hasTools,
      hasSupport: shaped.hasSupport && _hasSupport,
      waitingForMood: shaped.waitingForMood || _waitingForMood,
      positiveFantasy: shaped.positiveFantasy || _positiveFantasy,
      ethicalConflict: _ethicalConflict,
      thirdPartyImpact: shaped.thirdPartyImpact,
      irreversibleImpact: shaped.irreversibleImpact,
      professionalDecision: shaped.professionalDecision,
      acuteDanger: shaped.acuteDanger,
      severeFunctionLoss: shaped.severeFunctionLoss,
      previousAttempts: _attemptsController.text.trim().isEmpty
          ? shaped.previousAttempts
          : _attemptsController.text.trim(),
    );
  }

  Widget _buildSafetyBoundaryResult() {
    final diagnosis = _diagnosis!;
    final safety = diagnosis.safety;
    final riskColor = safety.risk.index >= ZxRiskLevel.r3.index
        ? Colors.red.shade700
        : safety.risk == ZxRiskLevel.r2
            ? Colors.orange.shade800
            : _green;
    return _sectionCard(
      title: '这次先不要生成普通行动',
      subtitle: '这不是疾病判断，只是保护本次行动的安全边界。',
      initiallyExpanded: true,
      leading: CircleAvatar(
        backgroundColor: riskColor.withValues(alpha: 0.12),
        child: Icon(Icons.shield_outlined, color: riskColor),
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
    return _sectionCard(
      title: '现在就做这一步',
      subtitle: '先行动，再用事实复盘；不要求先解释清楚所有原因。',
      initiallyExpanded: true,
      leading: const CircleAvatar(child: Icon(Icons.play_arrow_rounded)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (item.guidanceOrigin == 'ai_derived') ...<Widget>[
            _statusBanner(
              'AI派生行动 · 与本地核心库分开',
              (_selectedAiKnowledge?.thinker ?? '已保存派生思想') +
                  ' · ' +
                  (item.aiModelLabel.isEmpty
                      ? '全局AI模型'
                      : item.aiModelLabel),
              Colors.deepPurple,
            ),
            const SizedBox(height: 10),
          ],
          _statusBanner(
            match.complementary == null ? '本次指导思想' : '本次融合思想',
            <String>[
              _systemLabelForLens(match.primary),
              if (match.complementary != null)
                _systemLabelForLens(match.complementary!),
            ].join('  +  '),
            _green,
          ),
          if (match.lowMatch)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _statusBanner(
                '当前思想未必完全适合',
                '可以先把这一步当作小实验；复盘时可立即换思想或融合另一种思想。',
                Colors.orange.shade800,
              ),
            ),
          const SizedBox(height: 14),
          _actionOption(
            '本轮只做这一项',
            item.mainAction,
            Icons.play_circle_outline,
            emphasized: true,
          ),
          const SizedBox(height: 8),
          const Text(
            '做到什么算完成',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(item.completionDefinition),
          const SizedBox(height: 6),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('这一步太难或太轻？'),
            subtitle: const Text('按需要调整，不把难度当成意志考验。'),
            children: <Widget>[
              DropdownButtonFormField<ZxDifficulty>(
                value: allowedDifficulties.contains(_selectedDifficulty)
                    ? _selectedDifficulty
                    : item.difficulty,
                decoration: const InputDecoration(
                  labelText: '行动强度',
                  border: OutlineInputBorder(),
                ),
                items: allowedDifficulties
                    .map(
                      (difficulty) => DropdownMenuItem<ZxDifficulty>(
                        value: difficulty,
                        child: Text(_plainDifficultyLabel(difficulty)),
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
              const SizedBox(height: 10),
              _actionOption(
                '更轻的一步',
                item.lowerLoadAlternative,
                Icons.keyboard_double_arrow_down,
              ),
              _actionOption(
                '条件充足时再做',
                item.challengeAlternative,
                Icons.trending_up,
              ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('为什么这样行动？'),
            subtitle: Text('${match.primary.thinker}的行动思路与证据边界'),
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(match.primary.mechanism),
              ),
              const SizedBox(height: 8),
              _labelValue('行动线索', item.cue),
              if (item.supportChanges.isNotEmpty) ...<Widget>[
                const Text(
                  '让行动更容易',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                ...item.supportChanges.map(_bullet),
              ],
              const SizedBox(height: 6),
              const Text(
                '停止边界',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              ...item.stopConditions.map(_bullet),
              if (match.conflictNotes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                const Text(
                  '与其他思想的差异或张力',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                ...match.conflictNotes.map(_bullet),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.evidenceLocators
                    .map(
                      (locator) => ActionChip(
                        label: Text(locator),
                        avatar:
                            const Icon(Icons.fact_check_outlined, size: 16),
                        onPressed: () => _openEvidenceLocator(locator),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: _working ? null : _activatePrescription,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('开始并记录'),
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
                onPressed: () => _tabs.animateTo(_thoughtTab),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('换思想'),
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
      if (_selectedLensIds.isEmpty) {
        final automaticallySelected = <String>{};
        final primarySystem = _systemForLens(match.primary.id);
        automaticallySelected.add(
          primarySystem?.primaryLensId ?? match.primary.id,
        );
        if (match.complementary != null) {
          final complementSystem = _systemForLens(match.complementary!.id);
          automaticallySelected.add(
            complementSystem?.primaryLensId ?? match.complementary!.id,
          );
        }
        await _dao.setSelectedLenses(automaticallySelected);
        _selectedLensIds = automaticallySelected;
      }
      await _refreshLocalState();
      if (!mounted) return;
      setState(() => _working = false);
      _tabs.animateTo(_actionTab);
      _snack('行动已激活。完成后请记录“完成”和“学到什么”。');
    } catch (error) {
      if (!mounted) return;
      setState(() => _working = false);
      _snack('保存失败：$error');
    }
  }

  Widget _buildActionCard(ZxActionPrescription action) {
    final lens = _knowledge.lensById(action.primaryLensId);
    ZxAiKnowledgeDraft? aiKnowledge;
    for (final draft in _aiDrafts) {
      if (draft.id == action.guidanceKnowledgeRefId) {
        aiKnowledge = draft;
        break;
      }
    }
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
              '指导思想：${lens == null ? action.primaryLensId : _systemLabelForLens(lens)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (action.guidanceOrigin == 'ai_derived') ...<Widget>[
              const SizedBox(height: 5),
              Text(
                '知识来源：AI派生 · 本地保存 · 不替换核心库' +
                    (aiKnowledge == null
                        ? ''
                        : ' · ' + aiKnowledge.thinker) +
                    (action.aiModelLabel.isEmpty
                        ? ''
                        : ' · ' + action.aiModelLabel),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: () => _reviewAction(action),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('完成后行动复盘'),
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
    var difficultyFit = '合适';
    var thoughtDecision = 'auto';
    var obstacleReason = '';
    final currentSystem = _systemForLens(action.primaryLensId);
    final alternatives = ZxThinkerCatalog.guides
        .where((guide) => guide.systemId != currentSystem?.systemId)
        .where((guide) => _lensesForSystem(guide).isNotEmpty)
        .toList(growable: false);
    var alternativeLensId =
        alternatives.isEmpty ? '' : alternatives.first.primaryLensId;
    final insight = TextEditingController();
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('只回答现实结果和难度；系统负责生成报告、调整思想与安排下一步。'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<ZxCompletionStatus>(
                    value: completion,
                    decoration: const InputDecoration(
                      labelText: '1 · 这一步实际怎样？',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<ZxCompletionStatus>>[
                      DropdownMenuItem(
                        value: ZxCompletionStatus.completed,
                        child: Text('完成了'),
                      ),
                      DropdownMenuItem(
                        value: ZxCompletionStatus.notCompleted,
                        child: Text('没有完成'),
                      ),
                      DropdownMenuItem(
                        value: ZxCompletionStatus.safetyDowngrade,
                        child: Text('做了更安全、更小的一步'),
                      ),
                      DropdownMenuItem(
                        value: ZxCompletionStatus.exited,
                        child: Text('发现目标不对，决定退出'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => completion = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: difficultyFit,
                    decoration: const InputDecoration(
                      labelText: '2 · 难度感觉如何？',
                      border: OutlineInputBorder(),
                    ),
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
                  if (completion == ZxCompletionStatus.notCompleted) ...<Widget>[
                    const SizedBox(height: 12),
                    const Text(
                      '最接近哪个现实原因？（可选，但能让下一步更准）',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: const <String>[
                        '不知道第一步/不会做',
                        '害怕失败/追求完美',
                        '时间/工具/环境卡住',
                        '精力/睡眠/身体容量不足',
                        '目标不是我真正想要的',
                      ]
                          .map(
                            (reason) => ChoiceChip(
                              label: Text(reason),
                              selected: obstacleReason == reason,
                              onSelected: (_) => setDialogState(
                                () => obstacleReason = reason,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  const SizedBox(height: 4),
                  _dialogField(insight, '最关键的发现（可留空）'),
                  _dialogField(nextAction, '下一次最小动作（可留空）'),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: const Text('我想自己决定是否换思想（可选）'),
                    subtitle: const Text('默认由复盘报告自动推荐。'),
                    children: <Widget>[
                      DropdownButtonFormField<String>(
                        value: thoughtDecision,
                        decoration: const InputDecoration(
                          labelText: '思想调整方式',
                          border: OutlineInputBorder(),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'auto',
                            child: Text('由复盘报告自动推荐（建议）'),
                          ),
                          DropdownMenuItem(
                            value: 'continue',
                            child: Text('继续当前思想'),
                          ),
                          DropdownMenuItem(
                            value: 'switch',
                            child: Text('换一种思想'),
                          ),
                          DropdownMenuItem(
                            value: 'blend',
                            child: Text('融合另一种思想'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => thoughtDecision = value);
                          }
                        },
                      ),
                      if (thoughtDecision != 'auto' &&
                          thoughtDecision != 'continue' &&
                          alternatives.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: alternativeLensId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: thoughtDecision == 'switch'
                                ? '选择替换思想'
                                : '选择互补思想',
                            border: const OutlineInputBorder(),
                          ),
                          items: alternatives
                              .map(
                                (system) => DropdownMenuItem<String>(
                                  value: system.primaryLensId,
                                  child: Text(system.displayName),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(
                                () => alternativeLensId = value,
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ),
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
                final combinedInsight = <String>[
                  obstacleReason,
                  insight.text.trim(),
                ].where((value) => value.isNotEmpty).join('；');
                final hasLearning = combinedInsight.isNotEmpty ||
                    (thoughtDecision != 'continue' &&
                        thoughtDecision != 'auto');
                final depth = 1 +
                    <String>[combinedInsight, nextAction.text]
                        .where((value) => value.trim().isNotEmpty)
                        .length;
                Navigator.pop(
                  dialogContext,
                  ZxReviewInput(
                    completion: completion,
                    learning: hasLearning
                        ? ZxLearningStatus.updated
                        : ZxLearningStatus.none,
                    proofType: ZxProofType.selfReport,
                    whatHappened: _completionReviewLabel(completion) +
                        (obstacleReason.isEmpty
                            ? ''
                            : '；现实原因：' + obstacleReason),
                    hypothesisUpdate: combinedInsight,
                    difficultyFit: difficultyFit,
                    consequences: '',
                    nextDecision: '$thoughtDecision|$alternativeLensId',
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
    insight.dispose();
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
    final localReport = _localReview.generate(
      action: action,
      review: review,
    );
    await _dao.saveReviewReport(localReport);
    var report = localReport;
    if (action.guidanceOrigin == 'ai_derived' &&
        action.guidanceKnowledgeRefId > 0) {
      final aiDraft =
          await _dao.aiKnowledgeDraft(action.guidanceKnowledgeRefId);
      if (aiDraft != null) {
        final aiReport = await _aiKnowledge.generateReviewReport(
          knowledge: aiDraft,
          action: action,
          review: review,
        );
        if (aiReport.origin == ZxKnowledgeOrigin.aiDerived) {
          await _dao.saveReviewReport(aiReport);
          report = aiReport;
        }
      }
    }
    final decisionParts = review.nextDecision.split('|');
    var decision =
        decisionParts.isEmpty ? 'continue' : decisionParts.first;
    var alternativeId =
        decisionParts.length < 2 ? '' : decisionParts[1];
    if (decision == 'auto') {
      decision = report.recommendedDecision.key;
      final recommendedAlternative = report.recommendedSystemIds
          .map(ZxThinkerCatalog.guideFor)
          .whereType<ZxThinkerGuide>()
          .where((guide) => guide.systemId != currentSystem?.systemId);
      alternativeId = recommendedAlternative.isEmpty
          ? ''
          : recommendedAlternative.first.primaryLensId;
      if (decision != 'continue' && alternativeId.isEmpty) {
        decision = 'continue';
      }
    }
    final currentSelectionToken =
        currentSystem?.primaryLensId ?? action.primaryLensId;
    final nextSelected = <String>{..._selectedLensIds};
    if (decision == 'switch' && alternativeId.isNotEmpty) {
      nextSelected
        ..clear()
        ..add(alternativeId);
    } else if (decision == 'blend' && alternativeId.isNotEmpty) {
      nextSelected
        ..add(currentSelectionToken)
        ..add(alternativeId);
      while (nextSelected.length > 3) {
        final removable = nextSelected.firstWhere(
          (id) => id != currentSelectionToken && id != alternativeId,
          orElse: () => nextSelected.first,
        );
        nextSelected.remove(removable);
      }
    } else if (nextSelected.isEmpty) {
      nextSelected.add(currentSelectionToken);
    }
    final selectedSystemLensIds = nextSelected
        .map(ZxThinkerCatalog.guideFor)
        .whereType<ZxThinkerGuide>()
        .expand((system) => system.lensIds)
        .toSet();
    final nextDisabled = <String>{..._disabledLenses}
      ..removeAll(selectedSystemLensIds);
    await _dao.recordLensFeedback(
      action.primaryLensId,
      decision == 'switch'
          ? 0
          : decision == 'blend'
              ? 0.65
              : 1,
      reason: '极简行动复盘：$decision',
    );
    await _dao.setSelectedLenses(nextSelected);
    if (nextDisabled.length != _disabledLenses.length) {
      await _dao.setDisabledLenses(nextDisabled);
    }
    _goalController.text = action.goalTitle;
    _targetController.text = report.nextAction;
    await _refreshLocalState();
    if (!mounted) return;
    final selectedNames = nextSelected
        .map(ZxThinkerCatalog.guideFor)
        .whereType<ZxThinkerGuide>()
        .map((system) => system.displayName)
        .join(' + ');
    setState(() {
      _working = false;
      _selectedLensIds = nextSelected;
      _disabledLenses = nextDisabled;
      _diagnosis = null;
      _match = null;
      _prescription = null;
    });
    final continueNext = await showDialog<bool>(
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
            _statusBanner(
              report.origin.label + '复盘报告',
              report.summary,
              report.origin == ZxKnowledgeOrigin.aiDerived
                  ? Colors.deepPurple
                  : _green,
            ),
            const SizedBox(height: 10),
            _labelValue('行动证据', report.progressEvidence),
            _labelValue('关键发现', report.barrierFinding),
            _labelValue('系统建议', report.recommendedDecision.label),
            _labelValue('建议理由', report.rationale),
            _labelValue('下一轮思想', selectedNames),
            if (report.nextAction.isNotEmpty)
              _labelValue('下一小步', report.nextAction),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('稍后'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('按新方案继续行动'),
          ),
        ],
      ),
    );
    if (continueNext == true && mounted) {
      _tabs.animateTo(_actionTab);
    }
  }

  Widget _buildKnowledgePage() {
    final selected = _selectedSystems;
    final info = _knowledge.packageInfo;
    final recordCount = NumberFormat.decimalPattern('en_US')
        .format(info.recordCount);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
      children: <Widget>[
        _sectionCard(
          title: '以王阳明为主干，逐层推进知行合一',
          subtitle:
              'V${info.version}已重新打开${info.sourceCount}部登记原著/材料，'
              '以$recordCount条可回定位文本和${info.evidenceCount}条重点证据'
              '整合成${info.systemCount}套思想体系。'
              '每次引入都说明上一层缺口、共同点、差异、本次质变和融合后的新能力。',
          initiallyExpanded: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '当前已选',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              if (selected.isEmpty)
                const Text('尚未选择。先按“我现在卡在哪里”选择一套即可，不必一次接受全部思想。')
              else
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: selected
                      .map(
                        (system) => InputChip(
                          avatar:
                              const Icon(Icons.check_circle_outline, size: 17),
                          label: Text(system.displayName),
                          onDeleted: () => _toggleSelectedSystem(system),
                        ),
                      )
                      .toList(growable: false),
                ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: selected.isEmpty
                    ? null
                    : () => _tabs.animateTo(_actionTab),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  selected.length <= 1
                      ? '用所选思想开始行动'
                      : '融合${selected.length}套思想开始行动',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '它们怎样共同推进知行合一？',
          subtitle:
              '相得益彰不等于观点完全相同：共同主线被保留，真实差异和张力也必须公开。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ...ZxThinkerCatalog.commonGround.map(_bullet),
              const Divider(height: 24),
              _labelValue(
                '三种“知”',
                '规范性知：什么值得；解释性知：为何没做；程序性知：下一次怎样做。',
              ),
              _labelValue(
                '三种“行”',
                '启动行为；持续、修正与恢复行为；长期形成能力、关系、价值风格与贡献的生成性行动。',
              ),
              const Divider(height: 24),
              const Text(
                '按当前卡点快速决策',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              ...ZxThinkerCatalog.decisionRoutes.entries.map(
                (entry) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.route_outlined),
                  title: Text(entry.key),
                  subtitle: Text(entry.value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '完整17套思想体系（按需阅读）',
          subtitle: '主流程会自动匹配；只有想主动学习、比较或改选时才需要展开。',
          initiallyExpanded: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      '从王阳明总纲逐层补足心理、行动、意义、能力与环境。',
                    ),
                  ),
                  Badge(
                    label: Text('${_compareSystemIds.length}/2'),
                    child: IconButton.filledTonal(
                      tooltip: '对照两套思想',
                      onPressed: _compareSystemIds.length == 2
                          ? _compareSystems
                          : null,
                      icon: const Icon(Icons.compare_arrows),
                    ),
                  ),
                ],
              ),
              ...ZxThinkerCatalog.evolutionStageGuidance.entries.expand(
                (entry) => <Widget>[
                  _buildEvolutionStageHeader(entry.key, entry.value),
                  ...ZxThinkerCatalog.guides
                      .where((guide) => guide.evolutionStage == entry.key)
                      .map(_buildThinkerGuideCard),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '查找原始知识与证据',
          subtitle: '完整思想导航在上方；这里用于进一步查概念、作品和证据定位键。',
          child: Column(
            children: <Widget>[
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: '搜索概念、思想家、作品或证据定位键',
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
              DropdownButtonFormField<String>(
                value: _knowledgeSource,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '来源筛选',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: '',
                    child: Text('全部${info.sourceCount}部登记原著/材料'),
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
              const SizedBox(height: 8),
              if (_searchResults.isEmpty)
                const ListTile(
                  leading: Icon(Icons.manage_search),
                  title: Text('没有命中已审阅知识'),
                  subtitle: Text('可在“证据与隐私”登记扩展候选。'),
                )
              else
                ..._searchResults.take(12).map(
                      (result) => ListTile(
                        contentPadding: EdgeInsets.zero,
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
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openKnowledgeResult(result),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEvolutionStageHeader(String title, String body) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildThinkerGuideCard(ZxThinkerGuide guide) {
    final lenses =
        ZxThinkerCatalog.lensesFor(guide, _knowledge.lenses);
    final availableLenses = _lensesForSystem(guide);
    final works = lenses
        .map((lens) => _knowledge.workBySourceId(lens.sourceId))
        .whereType<ZxWork>()
        .toList(growable: false);
    final selected = _selectedLensIds.contains(guide.primaryLensId);
    final comparing = _compareSystemIds.contains(guide.systemId);
    final related = ZxThinkerCatalog.relatedTo(guide);
    final buildsOn = guide.buildsOnSystemIds
        .map(ZxThinkerCatalog.guideForSystem)
        .whereType<ZxThinkerGuide>()
        .map((item) => item.displayName)
        .join(' → ');
    final actionTemplates = lenses
        .expand((lens) => lens.actionTemplates)
        .toSet()
        .toList(growable: false);
    final evidenceLocators = lenses
        .expand((lens) => lens.evidenceLinks)
        .toSet()
        .toList(growable: false);
    final tensionNotes = <String>[
      ...guide.tensions,
      ...lenses.expand((lens) => lens.tensionLinks),
    ].toSet().toList(growable: false);
    final bestFit =
        lenses.map((lens) => lens.bestFit).toSet().join('；');
    final boundaries = <String>[
      ...lenses.map((lens) => lens.nonFit),
      ...lenses.map((lens) => lens.contraindications),
    ].where((item) => item.trim().isNotEmpty).toSet().join('；');
    final workTitles = works
        .map((work) => work.title)
        .toSet()
        .join('；');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: selected
          ? _green.withValues(alpha: 0.08)
          : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? _green
              : Theme.of(context).colorScheme.outlineVariant,
          width: selected ? 1.6 : 1,
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
                CircleAvatar(
                  backgroundColor: _green.withValues(alpha: 0.12),
                  foregroundColor: _green,
                  child: Text('${guide.sequence}'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        guide.displayName,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${guide.category} · ${works.length}部作品 · '
                        '${guide.lensIds.length}个行动机制',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: comparing ? '移出对照' : '加入两两对照',
                  onPressed: () => _toggleCompareSystem(guide.systemId),
                  icon: Icon(
                    comparing
                        ? Icons.compare_arrows
                        : Icons.compare_arrows_outlined,
                    color: comparing ? _green : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _statusBanner('本次引入产生的质变', guide.qualitativeLeap, _green),
            const SizedBox(height: 10),
            _labelValue('上一层仍未解决', guide.inheritedLimit),
            const Text(
              '核心价值体系',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: guide.coreValues
                  .map((value) => _miniTag(value))
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            const Text(
              '围绕知行合一的核心思想 · B/C层',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            ...guide.coreIdeas.take(4).map(_bullet),
            if (guide.coreIdeas.length > 4)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text('查看全部${guide.coreIdeas.length}条核心思想'),
                subtitle: const Text('先看4条总纲，需要时再展开完整思想脉络'),
                children: guide.coreIdeas
                    .skip(4)
                    .map(_bullet)
                    .toList(growable: false),
              ),
            const SizedBox(height: 8),
            _labelValue('怎样理解“知”', guide.knowledgeView),
            _labelValue('怎样理解“行”', guide.actionView),
            _labelValue('为什么会知行分裂', guide.splitDiagnosis),
            _labelValue('适合现在的你', guide.decisionCue),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('展开完整体系、著作融合与思想关系'),
              subtitle: Text(
                works.length > 1
                    ? '同一作者${works.length}部作品已统一整合，仍保留各书分工'
                    : '查看转化路径、王阳明主线、关系、边界与证据',
              ),
              children: <Widget>[
                _labelValue('从知到行的转化路径', guide.transformationPath),
                _labelValue('行动怎样回写认识', guide.actionFeedback),
                _labelValue('与王阳明主线的关系', guide.yangmingConnection),
                _labelValue('原著重新核验', guide.primarySourceFoundation),
                const Text(
                  '与王阳明的共同点 · C层跨源综合',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                ...guide.commonGroundWithYangming.map(_bullet),
                const SizedBox(height: 8),
                const Text(
                  '与王阳明的差异 · C层跨源综合',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                ...guide.differencesFromYangming.map(_bullet),
                if (buildsOn.isNotEmpty)
                  _labelValue('承接的前序思想', buildsOn),
                _labelValue('融合后形成什么', guide.synthesisOutcome),
                _labelValue('著作如何整合', guide.workSynthesis),
                if (workTitles.isNotEmpty)
                  _labelValue('对应的22源作品', workTitles),
                const Text(
                  '在七环知行回路中的位置',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: guide.sevenLoopRoles
                      .map(_miniTag)
                      .toList(growable: false),
                ),
                const SizedBox(height: 12),
                _labelValue('独特贡献', guide.distinctiveFocus),
                const Text(
                  '真实张力与误用边界',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                ...tensionNotes.map(_bullet),
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    '原著证据链 · A/B层（${guide.evidenceHighlights.length}条）',
                  ),
                  subtitle: const Text('逐条查看来源、定位、主张、用途和边界'),
                  children: guide.evidenceHighlights
                      .map(
                        (evidence) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.fact_check_outlined),
                          title: Text(
                            '${evidence.locator} · ${evidence.claim}',
                          ),
                          subtitle: Text(
                            '${evidence.summary}\n'
                            '产品用途：${evidence.use}\n'
                            '边界：${evidence.boundary}',
                          ),
                          isThreeLine: false,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              _openEvidenceLocator(evidence.locator),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 8),
                const Text(
                  '相互补足的思想体系',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: related
                      .map(
                        (item) => ActionChip(
                          avatar:
                              const Icon(Icons.hub_outlined, size: 16),
                          label: Text(item.displayName),
                          onPressed: () =>
                              _showThoughtRelationship(guide, item),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 10),
                _labelValue('最适合', bestFit),
                _labelValue('不适合/边界', boundaries),
                const Text(
                  '可直接采用的行动方式 · D层产品推论',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                ...actionTemplates.map(_bullet),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: evidenceLocators
                      .map(
                        (locator) => ActionChip(
                          avatar: const Icon(
                            Icons.fact_check_outlined,
                            size: 16,
                          ),
                          label: Text(locator),
                          onPressed: () => _openEvidenceLocator(locator),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: selected
                  ? OutlinedButton.icon(
                      onPressed: () => _toggleSelectedSystem(guide),
                      icon: const Icon(Icons.remove_circle_outline),
                      label: const Text('移出行动指导'),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: availableLenses.isEmpty
                          ? null
                          : () => _toggleSelectedSystem(guide),
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text(
                        availableLenses.isEmpty
                            ? '本体系镜头已全部停用'
                            : '选为行动指导',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSelectedSystem(ZxThinkerGuide guide) async {
    final next = <String>{..._selectedLensIds};
    final disabled = <String>{..._disabledLenses};
    if (!next.remove(guide.primaryLensId)) {
      if (next.length >= 3) {
        _snack('最多融合3套思想；请先移除一套再选择。');
        return;
      }
      next.add(guide.primaryLensId);
      disabled.removeAll(guide.lensIds);
    }
    await _dao.setSelectedLenses(next);
    if (disabled.length != _disabledLenses.length) {
      await _dao.setDisabledLenses(disabled);
    }
    if (!mounted) return;
    setState(() {
      _selectedLensIds = next;
      _disabledLenses = disabled;
      _diagnosis = null;
      _match = null;
      _prescription = null;
    });
  }

  Future<void> _selectSystemsTogether(
    Iterable<ZxThinkerGuide> systems,
  ) async {
    final requiredSystems = systems.toSet();
    final requiredTokens =
        requiredSystems.map((system) => system.primaryLensId).toSet();
    final next = <String>{..._selectedLensIds, ...requiredTokens};
    while (next.length > 3) {
      final removable = next.firstWhere(
        (token) => !requiredTokens.contains(token),
        orElse: () => next.first,
      );
      next.remove(removable);
    }
    final enabledLensIds =
        requiredSystems.expand((system) => system.lensIds).toSet();
    final disabled = <String>{..._disabledLenses}
      ..removeAll(enabledLensIds);
    await _dao.setSelectedLenses(next);
    if (!setEquals(disabled, _disabledLenses)) {
      await _dao.setDisabledLenses(disabled);
    }
    if (!mounted) return;
    setState(() {
      _selectedLensIds = next;
      _disabledLenses = disabled;
      _diagnosis = null;
      _match = null;
      _prescription = null;
    });
    _snack('已融合${requiredSystems.map((item) => item.thinker).join('与')}的思想体系。');
  }

  Future<void> _showThoughtRelationship(
    ZxThinkerGuide first,
    ZxThinkerGuide second,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${first.thinker} × ${second.thinker}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _labelValue(
                '共同主线',
                '都被纳入“方向—澄清—容纳—启动—稳定—求证—内化”的知行回路，让理解进入行动并由现实结果回写。',
              ),
              _labelValue(
                '${first.thinker}带来的质变',
                first.qualitativeLeap,
              ),
              _labelValue(
                '${second.thinker}带来的质变',
                second.qualitativeLeap,
              ),
              _labelValue(
                '${first.thinker}与王阳明',
                first.yangmingConnection,
              ),
              _labelValue(
                '${second.thinker}与王阳明',
                second.yangmingConnection,
              ),
              _labelValue(
                '融合后形成什么',
                '${first.synthesisOutcome}；${second.synthesisOutcome}',
              ),
              const Text(
                '不能抹平的张力',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              ...<String>{
                ...first.tensions.take(1),
                ...second.tensions.take(1),
              }.map(_bullet),
              _labelValue(
                '本轮如何融合',
                '只由更贴合当前卡点的一套体系确定唯一主动作，另一套只补足方向、心理关系、能力、环境或停止条件；复盘后再决定是否交换主次。',
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _selectSystemsTogether(<ZxThinkerGuide>[first, second]);
            },
            child: const Text('融合这两套思想'),
          ),
        ],
      ),
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

  void _toggleCompareSystem(String id) {
    setState(() {
      if (!_compareSystemIds.remove(id)) {
        if (_compareSystemIds.length >= 2) {
          _compareSystemIds.remove(_compareSystemIds.first);
        }
        _compareSystemIds.add(id);
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
                _labelValue('原主张/来源内综合', item.title),
                _labelValue('证据摘要', item.summary),
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

  Future<void> _compareSystems() async {
    final items = _compareSystemIds
        .map(ZxThinkerCatalog.guideForSystem)
        .whereType<ZxThinkerGuide>()
        .toList(growable: false);
    if (items.length != 2) return;
    final a = items[0];
    final b = items[1];
    String worksFor(ZxThinkerGuide guide) =>
        ZxThinkerCatalog.lensesFor(guide, _knowledge.lenses)
            .map((lens) => _knowledge.workBySourceId(lens.sourceId)?.title ?? '')
            .where((title) => title.isNotEmpty)
            .toSet()
            .join('\n');
    String bestFitFor(ZxThinkerGuide guide) =>
        ZxThinkerCatalog.lensesFor(guide, _knowledge.lenses)
            .map((lens) => lens.bestFit)
            .toSet()
            .join('\n');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('思想方案对照'),
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
                _comparisonRow('', a.displayName, b.displayName, header: true),
                _comparisonRow(
                    '演化层级', a.evolutionStage, b.evolutionStage),
                _comparisonRow(
                    '前层缺口', a.inheritedLimit, b.inheritedLimit),
                _comparisonRow(
                    '本次质变', a.qualitativeLeap, b.qualitativeLeap),
                _comparisonRow('核心价值', a.coreValues.join('、'),
                    b.coreValues.join('、')),
                _comparisonRow('核心思想', a.coreIdeas.join('\n'),
                    b.coreIdeas.join('\n')),
                _comparisonRow(
                  '共同点',
                  '进入具体行动，并由现实反馈回写认识。',
                  '进入具体行动，并由现实反馈回写认识。',
                ),
                _comparisonRow(
                    '怎样理解知', a.knowledgeView, b.knowledgeView),
                _comparisonRow('怎样理解行', a.actionView, b.actionView),
                _comparisonRow(
                    '分裂原因', a.splitDiagnosis, b.splitDiagnosis),
                _comparisonRow(
                    '转化路径', a.transformationPath, b.transformationPath),
                _comparisonRow(
                    '行动回写', a.actionFeedback, b.actionFeedback),
                _comparisonRow(
                    '与王阳明', a.yangmingConnection, b.yangmingConnection),
                _comparisonRow(
                    '独特贡献', a.distinctiveFocus, b.distinctiveFocus),
                _comparisonRow(
                    '融合结果', a.synthesisOutcome, b.synthesisOutcome),
                _comparisonRow(
                    '七环位置',
                    a.sevenLoopRoles.join('、'),
                    b.sevenLoopRoles.join('、')),
                _comparisonRow('最适合', bestFitFor(a), bestFitFor(b)),
                _comparisonRow(
                    '真实张力', a.tensions.join('\n'), b.tensions.join('\n')),
                _comparisonRow('作品', worksFor(a), worksFor(b)),
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
    _tabs.animateTo(_actionTab);
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
          initiallyExpanded: true,
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
                onPressed: () => _tabs.animateTo(_growthTab),
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

  Widget _buildAiMentorPage() {
    final booksByThinker = <String, List<ZxAiBook>>{};
    for (final book in _aiBooks) {
      booksByThinker.putIfAbsent(book.thinker, () => <ZxAiBook>[]).add(book);
    }
    final remoteReadyCount = _remoteKnowledgeItems
        .where(
          (item) =>
              item.provider == _remoteKnowledgeProvider && item.isReady,
        )
        .length;
    final remoteConfig = _remoteKnowledgeConfig;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
      children: <Widget>[
        _sectionCard(
          title: '两套知识方案',
          subtitle: '本地审核知识是稳定基线；AI派生知识来自你保存的著作，可选用但不会覆盖基线。',
          initiallyExpanded: true,
          leading: const CircleAvatar(
            child: Icon(Icons.account_tree_outlined),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _statusBanner(
                '本地审核知识库',
                '离线可用 · ' +
                    _knowledge.packageInfo.systemCount.toString() +
                    '套思想体系 · 用于行动、复盘与推荐',
                _green,
              ),
              const SizedBox(height: 8),
              _statusBanner(
                'AI派生知识库',
                '独立表与独立文件目录 · 清楚标记来源 · 仅由用户主动选择',
                Colors.deepPurple,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '远端书库',
          subtitle: '著作保存在所选服务商；本应用保存其文件／知识库 ID。直连与中转能力均按真实保留期限标记。',
          initiallyExpanded: true,
          leading: const CircleAvatar(
            child: Icon(Icons.cloud_done_outlined),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _statusBanner(
                remoteConfig?.isConfigured == true
                    ? '${_remoteKnowledgeProvider.label} 已配置'
                    : '${_remoteKnowledgeProvider.label} 尚未配置',
                '${_remoteKnowledgeProvider.retentionLabel} · 已就绪 $remoteReadyCount 本',
                remoteConfig?.isConfigured == true
                    ? _green
                    : Colors.orange.shade800,
              ),
              const SizedBox(height: 6),
              Text(
                _remoteKnowledgeProvider.isGateway
                    ? '当前类型：第三方中转服务'
                    : '当前类型：服务商直连',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: _working ? null : _configureRemoteKnowledge,
                    icon: const Icon(Icons.tune_outlined),
                    label: const Text('选择服务商'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _working || _aiBooks.isEmpty
                        ? null
                        : _syncAllRemoteBooks,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('同步全部著作'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '著作文件库',
          subtitle: '同一思想家的著作先统一归类；展开后可同步远端、问书或融合成派生思想。',
          initiallyExpanded: true,
          leading: const CircleAvatar(
            child: Icon(Icons.folder_copy_outlined),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: _working ? null : _importAiBooks,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('导入思想家著作'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_aiBooks.isEmpty)
                const Text('还没有保存著作。支持 PDF、DOC/DOCX、EPUB、MOBI、AZW、FB2、RTF、TXT、MD。')
              else
                ...booksByThinker.entries.map(
                  (entry) => _buildThinkerBookGroup(
                    thinker: entry.key,
                    books: entry.value,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '已保存的AI派生思想',
          subtitle: '可用于目标转行动、复盘报告和思想推荐；每条都保留模型与著作引用。',
          initiallyExpanded: _selectedAiKnowledge != null,
          leading: const CircleAvatar(
            child: Icon(Icons.auto_awesome_outlined),
          ),
          child: _aiDrafts.isEmpty
              ? const Text('尚未生成AI派生思想。')
              : Column(
                  children: _aiDrafts
                      .map(
                        (draft) => Card(
                          child: ExpansionTile(
                            leading: Icon(
                              _selectedAiKnowledge?.id == draft.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: Colors.deepPurple,
                            ),
                            title: Text(draft.thinker + ' · ' + draft.title),
                            subtitle: Text(
                              (draft.usesRemoteKnowledge
                                      ? 'AI派生 · 远端书库 ID · '
                                      : 'AI派生 · 本机临时附件 · ') +
                                  draft.modelLabel +
                                  ' · ' +
                                  draft.bookIds.length.toString() +
                                  '本著作',
                            ),
                            onExpansionChanged: (expanded) {
                              if (expanded) {
                                setState(() => _selectedAiKnowledge = draft);
                              }
                            },
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            children: <Widget>[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: draft.coreValues
                                      .map((value) => Chip(label: Text(value)))
                                      .toList(growable: false),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _labelValue('怎样理解知', draft.knowledgeView),
                              _labelValue('怎样理解行', draft.actionView),
                              _labelValue(
                                '知—行—反馈路径',
                                draft.transformationPath,
                              ),
                              _labelValue(
                                '与王阳明主线的关系',
                                draft.yangmingConnection,
                              ),
                              _labelValue(
                                '共同点',
                                draft.commonGround.join('；'),
                              ),
                              _labelValue(
                                '差异',
                                draft.differences.join('；'),
                              ),
                              _labelValue(
                                '适用边界',
                                draft.boundaries.join('；'),
                              ),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '核心思想',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              ...draft.coreIdeas.map(_bullet),
                              const SizedBox(height: 8),
                              FilledButton.tonalIcon(
                                onPressed: () {
                                  setState(() {
                                    _selectedAiKnowledge = draft;
                                    _useAiKnowledge = true;
                                  });
                                  _tabs.animateTo(_actionTab);
                                },
                                icon: const Icon(Icons.play_arrow_outlined),
                                label: const Text('选用并转成行动'),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '行动导师 Agent',
          subtitle: '按当前状态提醒目标、执行、反馈与下一轮；思想由系统先推荐，用户保留改选权。',
          initiallyExpanded: _agentSettings.enabled,
          leading: const CircleAvatar(
            child: Icon(Icons.notifications_active_outlined),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _statusBanner(
                _agentSettings.enabled ? '导师提醒已开启' : '导师提醒未开启',
                '当前建议：' + _agentScene.title,
                _agentSettings.enabled ? _green : Colors.orange.shade800,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text('推进提醒'),
                subtitle: Text(
                  TimeOfDay(
                    hour: _agentSettings.hour,
                    minute: _agentSettings.minute,
                  ).format(context),
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _pickAgentTime(review: false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.rate_review_outlined),
                title: const Text('反馈与复盘提醒'),
                subtitle: Text(
                  TimeOfDay(
                    hour: _agentSettings.reviewHour,
                    minute: _agentSettings.reviewMinute,
                  ).format(context),
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _pickAgentTime(review: true),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用行动导师提醒'),
                subtitle: const Text('未来7天每天两次；修改时间后会重新登记。'),
                value: _agentSettings.enabled,
                onChanged: _working ? null : _toggleAgent,
              ),
              const Text(
                '导师状态流：目标 → 自动匹配思想并生成行动 → 跟踪推进 → 请求现实反馈 → 自动复盘/调整思想 → 下一轮。AI不会在没有反馈时虚构结果。',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        if (_reviewReports.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _sectionCard(
            title: '报告记录',
            subtitle: '本地报告与AI派生报告同时保留并清楚区分。',
            child: Column(
              children: _reviewReports
                  .take(8)
                  .map(
                    (report) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        report.origin == ZxKnowledgeOrigin.aiDerived
                            ? Icons.auto_awesome_outlined
                            : Icons.fact_check_outlined,
                      ),
                      title: Text(
                        report.origin.label +
                            ' · ' +
                            report.recommendedDecision.label,
                      ),
                      subtitle: Text(
                        report.summary + '\n下一步：' + report.nextAction,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildThinkerBookGroup({
    required String thinker,
    required List<ZxAiBook> books,
  }) {
    final readyCount = books
        .where((book) => _remoteItemForBook(book)?.isReady ?? false)
        .length;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.person_outline),
        title: Text(thinker),
        subtitle: Text(
          '本机 ${books.length} 本 · 当前服务商已就绪 $readyCount 本',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: _working
                      ? null
                      : () => _syncRemoteBooks(
                            books,
                            label: thinker,
                          ),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('同步远端'),
                ),
                OutlinedButton.icon(
                  onPressed: _working
                      ? null
                      : () => _askRemoteBooksFor(thinker),
                  icon: const Icon(Icons.question_answer_outlined),
                  label: const Text('基于著作提问'),
                ),
                FilledButton.icon(
                  onPressed: _working ? null : () => _analyzeBooksFor(thinker),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('融合思想'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...books.map(_buildAiBookTile),
        ],
      ),
    );
  }

  Widget _buildAiBookTile(ZxAiBook book) {
    final remote = _remoteItemForBook(book);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(book.title),
      subtitle: Text(book.fileName),
      trailing: _remoteStatusChip(remote),
      childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      children: <Widget>[
        _labelValue(
          '本机文件',
          '${(book.byteSize / 1024 / 1024).toStringAsFixed(1)} MB · 已提取 ${book.extractedCharacters} 字',
        ),
        if (remote != null) ...<Widget>[
          _labelValue('远端保留方式', remote.retentionLabel),
          _labelValue('服务商资源 ID', _remoteResourceSummary(remote)),
          if (remote.expiresAtMs > 0)
            _labelValue('到期时间', _dateLabel(remote.expiresAtMs)),
          if (remote.lastError.trim().isNotEmpty)
            _labelValue('同步状态', remote.lastError),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _working
                    ? null
                    : () => _syncRemoteBooks(<ZxAiBook>[book], label: book.title),
                icon: const Icon(Icons.sync_outlined),
                label: Text(remote?.isReady == true ? '检查远端状态' : '同步到远端'),
              ),
              if (remote != null &&
                  remote.status != ZxRemoteKnowledgeStatus.deleted &&
                  remote.status != ZxRemoteKnowledgeStatus.processing)
                OutlinedButton.icon(
                  onPressed: _working
                      ? null
                      : () => _deleteRemoteBookCopy(book, remote),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    remote.provider.supportsImmediateDelete
                        ? '删除远端副本'
                        : '停止使用（到期自动删）',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  ZxRemoteKnowledgeItem? _remoteItemForBook(ZxAiBook book) {
    for (final item in _remoteKnowledgeItems) {
      if (item.bookId == book.id && item.provider == _remoteKnowledgeProvider) {
        return item;
      }
    }
    return null;
  }

  Widget _remoteStatusChip(ZxRemoteKnowledgeItem? item) {
    if (item?.isExpired == true) {
      final color = Colors.orange.shade800;
      return Chip(
        visualDensity: VisualDensity.compact,
        label: Text('已过期', style: TextStyle(color: color)),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        backgroundColor: color.withValues(alpha: 0.08),
      );
    }
    final status = item?.status;
    final Color color;
    final String label;
    switch (status) {
      case ZxRemoteKnowledgeStatus.ready:
        color = _green;
        label = '远端已就绪';
        break;
      case ZxRemoteKnowledgeStatus.processing:
        color = Colors.orange.shade800;
        label = '正在索引';
        break;
      case ZxRemoteKnowledgeStatus.failed:
        color = Colors.red.shade700;
        label = '同步失败';
        break;
      case ZxRemoteKnowledgeStatus.deleted:
        color = Colors.grey.shade700;
        label = item?.provider == ZxRemoteKnowledgeProvider.edenAi
            ? '已停用·等待到期'
            : '已删除';
        break;
      case null:
        color = Colors.blueGrey;
        label = '仅本机';
        break;
    }
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label, style: TextStyle(color: color)),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }

  String _remoteResourceSummary(ZxRemoteKnowledgeItem item) {
    final ids = <String>[
      if (item.remoteFileId.isNotEmpty) 'file: ${item.remoteFileId}',
      if (item.remoteStoreId.isNotEmpty) 'store: ${item.remoteStoreId}',
      if (item.remoteDocumentId.isNotEmpty) 'document: ${item.remoteDocumentId}',
    ];
    return ids.isEmpty ? '服务商尚未返回可用资源 ID。' : ids.join('\n');
  }

  Future<void> _importAiBooks() async {
    final thinker = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导入思想家著作'),
        content: _dialogField(
          thinker,
          '思想家或理论体系（同一作者多本书将统一融合）',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (thinker.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, thinker.text.trim());
            },
            child: const Text('选择文件'),
          ),
        ],
      ),
    );
    thinker.dispose();
    if (name == null || !mounted) return;
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const <String>[
        'pdf',
        'doc',
        'docx',
        'epub',
        'mobi',
        'azw',
        'azw3',
        'fb2',
        'rtf',
        'txt',
        'md',
      ],
    );
    if (picked == null) return;
    setState(() => _working = true);
    var imported = 0;
    final failures = <String>[];
    for (final selected in picked.files) {
      final path = selected.path;
      if (path == null || path.trim().isEmpty) {
        failures.add(selected.name + '：无法取得本机路径');
        continue;
      }
      try {
        await _aiKnowledge.importBook(
          source: File(path),
          thinker: name,
        );
        imported++;
      } catch (error) {
        failures.add(selected.name + '：' + error.toString());
      }
    }
    await _refreshLocalState();
    if (!mounted) return;
    setState(() => _working = false);
    _snack(
      '已保存' +
          imported.toString() +
          '本著作' +
          (failures.isEmpty ? '。' : '；失败：' + failures.join('；')),
    );
  }

  Future<void> _configureRemoteKnowledge() async {
    final values = await _aiKnowledge.remoteKnowledgeEditableSettings();
    if (!mounted) return;
    var provider = _remoteKnowledgeProvider;
    final claudeKey = TextEditingController(text: values['claude_key'] ?? '');
    final claudeModel =
        TextEditingController(text: values['claude_model'] ?? 'claude-sonnet-4-5');
    final azureKey =
        TextEditingController(text: values['azure_key'] ?? '');
    final azureEndpoint =
        TextEditingController(text: values['azure_endpoint'] ?? '');
    final azureModel =
        TextEditingController(text: values['azure_model'] ?? '');
    final openRouterFileKey =
        TextEditingController(text: values['openrouter_file_key'] ?? '');
    final compatibleKey =
        TextEditingController(text: values['compatible_key'] ?? '');
    final compatibleBase =
        TextEditingController(text: values['compatible_base_url'] ?? '');
    final compatibleModel = TextEditingController(
      text: values['compatible_model'] ?? 'gpt-4.1-mini',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('选择远端书库服务商'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DropdownButtonFormField<ZxRemoteKnowledgeProvider>(
                  value: provider,
                  decoration: const InputDecoration(
                    labelText: '服务商',
                    border: OutlineInputBorder(),
                  ),
                  items: ZxRemoteKnowledgeProvider.values
                      .map(
                        (item) => DropdownMenuItem<ZxRemoteKnowledgeProvider>(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => provider = value);
                  },
                ),
                const SizedBox(height: 12),
                Text(provider.setupHint),
                const SizedBox(height: 8),
                Text(
                  provider.retentionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (provider == ZxRemoteKnowledgeProvider.claude) ...<Widget>[
                  _dialogField(claudeKey, 'Claude API Key', obscureText: true),
                  _dialogField(claudeModel, 'Claude 模型'),
                ],
                if (provider == ZxRemoteKnowledgeProvider.azureOpenAi)
                  ...<Widget>[
                    _dialogField(
                      azureEndpoint,
                      'Azure 资源地址',
                      hint: 'https://你的资源名.openai.azure.com',
                    ),
                    _dialogField(azureKey, 'Azure OpenAI API Key',
                        obscureText: true),
                    _dialogField(azureModel, '模型部署名'),
                  ],
                if (provider == ZxRemoteKnowledgeProvider.openRouter)
                  _dialogField(
                    openRouterFileKey,
                    'OpenRouter Management Key',
                    hint: '工作区文件上传和删除必填；与全局推理 Key 分开',
                    obscureText: true,
                  ),
                if (provider == ZxRemoteKnowledgeProvider.openAiCompatible)
                  ...<Widget>[
                    _dialogField(compatibleBase, 'API 基地址（含或不含 /v1）'),
                    _dialogField(compatibleKey, 'API Key', obscureText: true),
                    _dialogField(compatibleModel, '模型名称'),
                  ],
                if (provider == ZxRemoteKnowledgeProvider.openai ||
                    provider == ZxRemoteKnowledgeProvider.xgrok ||
                    provider == ZxRemoteKnowledgeProvider.gemini ||
                    provider == ZxRemoteKnowledgeProvider.openRouter ||
                    provider == ZxRemoteKnowledgeProvider.edenAi)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '密钥与模型使用应用的全局 AI 设置；此处只选择用于书库的服务商。',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('保存选择'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _aiKnowledge.saveRemoteKnowledgeSettings(
        provider: provider,
        claudeKey: claudeKey.text,
        claudeModel: claudeModel.text,
        azureKey: azureKey.text,
        azureEndpoint: azureEndpoint.text,
        azureModel: azureModel.text,
        openRouterFileKey: openRouterFileKey.text,
        compatibleKey: compatibleKey.text,
        compatibleBaseUrl: compatibleBase.text,
        compatibleModel: compatibleModel.text,
      );
      await _refreshLocalState();
      if (mounted) _snack('已选择${provider.label}。');
    }
    claudeKey.dispose();
    claudeModel.dispose();
    azureKey.dispose();
    azureEndpoint.dispose();
    azureModel.dispose();
    openRouterFileKey.dispose();
    compatibleKey.dispose();
    compatibleBase.dispose();
    compatibleModel.dispose();
  }

  Future<void> _syncAllRemoteBooks() =>
      _syncRemoteBooks(_aiBooks, label: '全部已导入著作');

  Future<void> _syncRemoteBooks(
    List<ZxAiBook> books, {
    required String label,
  }) async {
    if (books.isEmpty) return;
    final config = await _aiKnowledge.remoteKnowledgeConfig(
      provider: _remoteKnowledgeProvider,
    );
    if (!config.isConfigured) {
      _snack('请先配置${_remoteKnowledgeProvider.label}的密钥与模型。');
      return;
    }
    final confirmed = await _confirm(
      title: '同步到${_remoteKnowledgeProvider.label}？',
      body: '将上传“$label”共${books.length}本著作，并保存服务商返回的文件／知识库 ID。'
          '${_remoteKnowledgeProvider.retentionLabel}。之后的远端问答、思想融合、行动和复盘都会通过这些 ID 检索；'
          '${_remoteKnowledgeProvider.supportsImmediateDelete ? '可随时删除远端副本。' : '本应用可立即停止使用该 ID，但服务商未提供即时删除接口，远端副本会在到期时间自动删除。'}',
      confirmLabel: '上传并保存 ID',
    );
    if (!confirmed || !mounted) return;
    setState(() => _working = true);
    try {
      final results = await _aiKnowledge.syncBooksToRemote(
        books,
        provider: _remoteKnowledgeProvider,
      );
      await _refreshLocalState();
      if (!mounted) return;
      final ready = results.where((item) => item.isReady).length;
      final processing = results
          .where((item) => item.status == ZxRemoteKnowledgeStatus.processing)
          .length;
      final failed = results
          .where((item) => item.status == ZxRemoteKnowledgeStatus.failed)
          .toList(growable: false);
      final detail = failed.isEmpty
          ? ''
          : '；失败 ${failed.length} 本：${failed.first.lastError}';
      _snack(
        '远端书库：已就绪 $ready 本${processing > 0 ? '；正在索引 $processing 本' : ''}$detail',
      );
    } catch (error) {
      if (mounted) _snack('远端同步失败：$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deleteRemoteBookCopy(
    ZxAiBook book,
    ZxRemoteKnowledgeItem item,
  ) async {
    final canDeleteNow = item.provider.supportsImmediateDelete;
    final confirmed = await _confirm(
      title: canDeleteNow ? '删除服务商副本？' : '停止使用远端副本？',
      body: canDeleteNow
          ? '将从${item.provider.label}删除“${book.title}”对应的远端文件或检索文档。'
              '本机著作、已保存的 AI 派生思想和本地审核知识库不会删除。'
          : '${item.provider.label}没有公开即时删除接口。本应用将立即停止使用“${book.title}”的远端 ID，'
              '服务商副本会在${_dateLabel(item.expiresAtMs)}自动到期；本机著作和本地知识库不受影响。',
      confirmLabel: canDeleteNow ? '删除远端副本' : '停止使用',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _working = true);
    try {
      await _aiKnowledge.deleteRemoteBook(item);
      await _refreshLocalState();
      if (mounted) {
        _snack(
          canDeleteNow
              ? '已删除服务商副本；本机著作仍保留。'
              : '已停止使用该远端 ID；服务商副本将在到期时间自动删除。',
        );
      }
    } catch (error) {
      if (mounted) _snack('删除远端副本失败：$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _askRemoteBooksFor(String thinker) async {
    final books = _aiBooks
        .where((item) => item.thinker == thinker)
        .toList(growable: false);
    final unavailable = books
        .where((book) => !(_remoteItemForBook(book)?.isReady ?? false))
        .length;
    if (unavailable > 0) {
      _snack('“$thinker”还有 $unavailable 本著作未在当前远端书库就绪，请先同步。');
      return;
    }
    final question = TextEditingController();
    final submitted = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('基于“$thinker”著作提问'),
        content: _dialogField(
          question,
          '你的问题',
          maxLines: 4,
          hint: '例如：这一体系如何把“知行合一”转化为今天的行动？',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = question.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('提问'),
          ),
        ],
      ),
    );
    question.dispose();
    if (submitted == null || !mounted) return;
    setState(() => _working = true);
    try {
      final answer = await _aiKnowledge.askRemoteBooks(
        bookIds: books.map((book) => book.id).toList(growable: false),
        provider: _remoteKnowledgeProvider,
        question: submitted,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${answer.provider.label} · 著作回答'),
          content: SingleChildScrollView(child: SelectableText(answer.text)),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _snack('远端书库回答失败：$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _analyzeBooksFor(String thinker) async {
    final books =
        _aiBooks.where((item) => item.thinker == thinker).toList(growable: false);
    if (books.isEmpty) return;
    final config = await _aiKnowledge.remoteKnowledgeConfig(
      provider: _remoteKnowledgeProvider,
    );
    if (!config.isConfigured) {
      _snack('请先在“远端书库”中配置${_remoteKnowledgeProvider.label}。');
      return;
    }
    final confirmed = await _confirm(
      title: '上传著作并融合思想？',
      body: '将把${books.length}本“$thinker”著作上传至${_remoteKnowledgeProvider.label}，'
          '并保存服务商文件／知识库 ID。${_remoteKnowledgeProvider.retentionLabel}。'
          '融合、后续行动和复盘均通过这些已保存的远端资源检索；输出只保存为 AI 派生思想，不替换本地审核知识。',
      confirmLabel: '上传并生成',
    );
    if (!confirmed || !mounted) return;
    setState(() => _working = true);
    try {
      final synced = await _aiKnowledge.syncBooksToRemote(
        books,
        provider: _remoteKnowledgeProvider,
      );
      final notReady = synced.where((item) => !item.isReady).toList(
            growable: false,
          );
      if (notReady.isNotEmpty) {
        await _refreshLocalState();
        if (!mounted) return;
        final failed = notReady
            .where((item) => item.status == ZxRemoteKnowledgeStatus.failed)
            .toList(growable: false);
        final reason = failed.isEmpty
            ? '远端索引仍在进行，请稍后点击“融合思想”。'
            : failed.first.lastError;
        _snack('尚未生成融合结果：$reason');
        return;
      }
      final draft = await _aiKnowledge.analyzeAndSave(
        thinker: thinker,
        books: books,
        requireRemoteKnowledge: true,
      );
      await _refreshLocalState();
      if (!mounted) return;
      setState(() {
        _selectedAiKnowledge = draft;
      });
      _snack('已通过已保存的远端书库生成 AI 派生思想；本地审核知识未改变。');
    } catch (error) {
      if (mounted) _snack('AI分析失败：$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pickAgentTime({required bool review}) async {
    final current = TimeOfDay(
      hour: review ? _agentSettings.reviewHour : _agentSettings.hour,
      minute: review ? _agentSettings.reviewMinute : _agentSettings.minute,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: review ? '选择复盘提醒时间' : '选择推进提醒时间',
    );
    if (picked == null) return;
    final next = ZxAgentSettings(
      enabled: _agentSettings.enabled,
      hour: review ? _agentSettings.hour : picked.hour,
      minute: review ? _agentSettings.minute : picked.minute,
      reviewHour: review ? picked.hour : _agentSettings.reviewHour,
      reviewMinute: review ? picked.minute : _agentSettings.reviewMinute,
      daysAhead: _agentSettings.daysAhead,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() => _agentSettings = next);
    if (next.enabled) await _toggleAgent(true);
  }

  Future<void> _toggleAgent(bool enabled) async {
    setState(() => _working = true);
    if (!enabled) {
      await _agent.disable();
      await _refreshLocalState();
      if (!mounted) return;
      setState(() => _working = false);
      _snack('行动导师提醒已关闭。');
      return;
    }
    final result = await _agent.enableAndSchedule(
      _agentSettings,
      selectedThoughtCount: _selectedLensIds.length,
    );
    await _refreshLocalState();
    if (!mounted) return;
    setState(() => _working = false);
    _snack(
      result.ready
          ? '已登记' + result.scheduledCount.toString() + '个行动导师提醒。'
          : '提醒未完全启用，请授予通知与精确闹钟权限后重试。',
    );
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
              _labelValue('来源数量', '${info.sourceCount}部登记原著/材料'),
              _labelValue(
                '可回定位文本',
                '${NumberFormat.decimalPattern('en_US').format(info.recordCount)}条抽取记录',
              ),
              _labelValue(
                '完整思想体系',
                '${info.systemCount}套作者/理论整合体系',
              ),
              _labelValue(
                '作品级机制',
                '${_knowledge.lenses.length}个机制镜头（保留原始证据分工）',
              ),
              _labelValue(
                '重点原著证据',
                '${info.evidenceCount}条可回定位证据卡',
              ),
              _labelValue(
                '累计知识库 SHA-256',
                '${info.actualSha256.substring(0, 16)}… · '
                    '${info.contentIntegrityValid ? '完整性通过' : '不匹配'}',
              ),
              _labelValue(
                '思想目录 SHA-256',
                '${info.actualCatalogSha256.substring(0, 16)}… · '
                    '${info.catalogIntegrityValid ? '同步通过' : '不匹配'}',
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
          subtitle: '本地审核方案可离线完成全闭环；AI派生方案由用户主动启用。',
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
                '本地审核知识与AI派生知识分表保存。AI可以基于用户上传著作生成详细思想、行动和复盘报告，但不能覆盖本地审核知识，也不能放宽安全、奖励和成长规则。',
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
                  '清除思想反馈与${_disabledLenses.length}个禁用项，不删除行动。',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _resetPersonalization,
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('管理行动思想（已禁用 ${_disabledLenses.length}）'),
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
                subtitle: const Text('JSON含本地行动、复盘、AI著作元数据、AI派生知识、导师事件、双账本与树状态。'),
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
      body: '将清除思想帮助度历史、禁用列表和行动偏好小测；目标、行动、复盘与奖励不受影响。',
      confirmLabel: '重置',
    );
    if (!confirmed) return;
    await _dao.resetPersonalization();
    if (!mounted) return;
    setState(() {
      _lensHistory = const <String, double>{};
      _disabledLenses = <String>{};
      _actionPreference = const ZxActionPreference();
      _experienceMode = ZxExperienceMode.direct;
    });
  }

  Future<void> _setLensEnabled(String id, bool enabled) async {
    final next = <String>{..._disabledLenses};
    enabled ? next.remove(id) : next.add(id);
    await _dao.setDisabledLenses(next);
    final selected = <String>{..._selectedLensIds};
    final system = ZxThinkerCatalog.guideFor(id);
    final systemUnavailable = !enabled &&
        system != null &&
        system.lensIds.every(next.contains);
    if (systemUnavailable && selected.remove(system.primaryLensId)) {
      await _dao.setSelectedLenses(selected);
    }
    if (mounted) {
      setState(() {
        _disabledLenses = next;
        _selectedLensIds = selected;
      });
    }
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
    final action = TextEditingController(
      text: await _promptConfig.actionPrompt(),
    );
    final expansion = TextEditingController(
      text: await _promptConfig.expansionPrompt(),
    );
    final assistant = TextEditingController(
      text: await _promptConfig.assistantPrompt(),
    );
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
                const SizedBox(height: 14),
                TextField(
                  controller: assistant,
                  minLines: 8,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    labelText: '模块智能助手',
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
      await _promptConfig.saveAssistantPrompt(assistant.text);
    }
    action.dispose();
    expansion.dispose();
    assistant.dispose();
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
    final hasDeferredRemoteDeletion = _remoteKnowledgeItems.any(
      (item) =>
          item.status != ZxRemoteKnowledgeStatus.deleted &&
          !item.provider.supportsImmediateDelete,
    );
    final confirmed = await _confirm(
      title: '删除全部用户数据？',
      body: '所选思想、目标、行动、复盘、AI派生知识、已导入著作文件、导师提醒、金币/XP账本、成长树、反馈和候选都会永久删除。'
          '支持即时删除的服务商副本会先删除；${hasDeferredRemoteDeletion ? 'Eden AI 等临时文件会立即停用其 ID，并按服务商到期时间自动删除；' : ''}'
          '只读审核知识包会保留。',
      confirmLabel: '永久删除',
      destructive: true,
    );
    if (!confirmed) return;
    final remoteItems = await _dao.remoteKnowledgeItems();
    for (final item in remoteItems) {
      try {
        await _aiKnowledge.deleteRemoteBook(item);
      } catch (error) {
        if (mounted) {
          _snack('未能删除${item.provider.label}远端副本；已停止清除本机数据：$error');
        }
        return;
      }
    }
    await _agent.disable();
    final importedBooks = await _dao.aiBooks();
    for (final book in importedBooks) {
      final file = File(book.localPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    await _dao.deleteAllUserData();
    await _refreshLocalState();
    if (!mounted) return;
    setState(() {
      _tree = const ZxTreeState();
      _lensHistory = const <String, double>{};
      _disabledLenses = <String>{};
      _selectedLensIds = <String>{};
      _actionPreference = const ZxActionPreference();
      _experienceMode = ZxExperienceMode.direct;
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
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                color: Colors.white,
                height: 1.45,
              ),
            ),
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
    Key? expansionKey,
    bool initiallyExpanded = false,
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
        child: ExpansionTile(
          key: expansionKey,
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: leading,
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          children: <Widget>[
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            child,
          ],
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

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    String hint = '',
    int maxLines = 3,
    bool obscureText = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: TextField(
          controller: controller,
          minLines: 1,
          maxLines: obscureText ? 1 : maxLines,
          obscureText: obscureText,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint.isEmpty ? null : hint,
            border: const OutlineInputBorder(),
            alignLabelWithHint: !obscureText && maxLines > 1,
          ),
        ),
      );

  Widget _switch(String title, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(title),
        value: value,
        onChanged: onChanged,
      );

  Widget _statusBanner(String title, String body, Color color) =>
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(body),
            ],
          ),
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
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight:
                          emphasized ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
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

  static String _plainDifficultyLabel(ZxDifficulty value) => switch (value) {
        ZxDifficulty.l0 => '先恢复或只做准备',
        ZxDifficulty.l1 => '最小一步',
        ZxDifficulty.l2 => '标准行动',
        ZxDifficulty.l3 => '多步骤行动',
        ZxDifficulty.l4 => '长期或公开挑战',
      };

  static String _completionReviewLabel(ZxCompletionStatus value) =>
      switch (value) {
        ZxCompletionStatus.completed => '完成了本轮可观察动作',
        ZxCompletionStatus.notCompleted => '本轮没有完成，但保留现实反馈',
        ZxCompletionStatus.safetyDowngrade => '完成了更安全、更小的一步',
        ZxCompletionStatus.exited => '发现目标不合适并负责地退出',
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
