import 'package:flutter/material.dart';

import 'realistic_positivity_os_ai_service.dart';
import 'realistic_positivity_os_coverage_page.dart';
import 'realistic_positivity_os_experiment_page.dart';
import 'realistic_positivity_os_dao.dart';
import 'realistic_positivity_os_models.dart';
import 'realistic_positivity_os_prompt_config.dart';
import 'realistic_positivity_os_coverage_audit_page.dart';
import 'realistic_positivity_os_lifecycle_page.dart';
import 'realistic_positivity_os_system_page.dart';
import 'realistic_positivity_os_workbench_page.dart';
import '../pages/ai_prompt_settings_page.dart';

class RealisticPositivityOsHomePage extends StatefulWidget {
  final String initialInput;
  final String initialSceneType;

  const RealisticPositivityOsHomePage({
    super.key,
    this.initialInput = '',
    this.initialSceneType = 'reality_lens',
  });

  @override
  State<RealisticPositivityOsHomePage> createState() => _RealisticPositivityOsHomePageState();
}

class _RealisticPositivityOsHomePageState extends State<RealisticPositivityOsHomePage> with SingleTickerProviderStateMixin {
  final RealisticPositivityOsDao _dao = RealisticPositivityOsDao();
  final RealisticPositivityOsAiService _ai = RealisticPositivityOsAiService();
  final TextEditingController _inputCtrl = TextEditingController();
  final TextEditingController _emotionsCtrl = TextEditingController();
  final TextEditingController _oldQuestionsCtrl = TextEditingController();
  final TextEditingController _patternsCtrl = TextEditingController();
  final TextEditingController _currentTroublesCtrl = TextEditingController();
  final TextEditingController _supportCtrl = TextEditingController();
  final TextEditingController _relationshipMapCtrl = TextEditingController();
  final TextEditingController _stretchAreasCtrl = TextEditingController();
  final TextEditingController _gratitudeCtrl = TextEditingController();
  final TextEditingController _peakCtrl = TextEditingController();
  final TextEditingController _identityCtrl = TextEditingController();

  late final TabController _tab;
  bool _loading = true;
  bool _generating = false;
  String _sceneType = 'reality_lens';
  RpoProfile _profile = const RpoProfile();
  RpoStats _stats = const RpoStats();
  List<RpoPracticeRecord> _records = const <RpoPracticeRecord>[];
  List<Map<String, Object?>> _assets = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _evidence = const <Map<String, Object?>>[];
  RpoPracticeRecord? _latest;

  static const Map<String, String> _sceneLabels = <String, String>{
    'reality_lens': '真实看见',
    'question_reframing': '问题重构',
    'gratitude': '感恩训练',
    'relational_gratitude': '关系感恩',
    'emotional_processing': '允许为人',
    'meaning_making': '痛苦整合',
    'savoring_peak': '积极经验',
    'change_lab': '价值绑定',
    'abc_change': 'ABC 改变',
    'behavior_first': '行为优先',
    'stretch_zone': 'Stretch Zone',
    'weekly_integration': '周整合',
    'crisis': '安全支持',
    'onboarding': '人格地图',
  };

  static const List<String> _quickInputs = <String>[
    '我最近总是拖延，明知道要学习，但就是不想开始。我觉得自己很废。',
    '今天和别人冲突后我一直反复想，觉得很委屈，也不知道怎么处理。',
    '我想感谢一个曾经帮助过我的老师，但不知道怎么开口。',
    '我总是完美主义，必须准备到很好才敢开始，所以很多事情拖着不做。',
    '今天发生了一件很温暖的小事，我怕它很快就被我忘掉。',
    '我想突破舒适区，练习在会议上表达，但又有点害怕。',
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 11, vsync: this);
    _sceneType = _sceneLabels.containsKey(widget.initialSceneType) ? widget.initialSceneType : 'reality_lens';
    _inputCtrl.text = widget.initialInput.trim().isEmpty ? _quickInputs.first : widget.initialInput.trim();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _inputCtrl.dispose();
    _emotionsCtrl.dispose();
    _oldQuestionsCtrl.dispose();
    _patternsCtrl.dispose();
    _currentTroublesCtrl.dispose();
    _supportCtrl.dispose();
    _relationshipMapCtrl.dispose();
    _stretchAreasCtrl.dispose();
    _gratitudeCtrl.dispose();
    _peakCtrl.dispose();
    _identityCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _dao.ensureTables();
      final profile = await _dao.loadProfile();
      final records = await _dao.listRecords(limit: 80);
      final assets = await _dao.listAssets(limit: 120);
      final evidence = await _dao.listActionEvidence(limit: 120);
      final stats = await _dao.stats();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _records = records;
        _assets = assets;
        _evidence = evidence;
        _stats = stats;
        _latest = records.isNotEmpty ? records.first : null;
        _emotionsCtrl.text = profile.commonEmotions.join('，');
        _oldQuestionsCtrl.text = profile.commonOldQuestions.join('\n');
        _patternsCtrl.text = profile.commonPatterns.join('，');
        _currentTroublesCtrl.text = profile.currentTroubles.join('\n');
        _supportCtrl.text = profile.supportPeople.join('，');
        _relationshipMapCtrl.text = profile.relationshipMap.join('\n');
        _stretchAreasCtrl.text = profile.stretchAreas.join('，');
        _gratitudeCtrl.text = profile.gratitudeAssets.join('\n');
        _peakCtrl.text = profile.peakExperiences.join('\n');
        _identityCtrl.text = profile.identityEvidence.join('\n');
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('加载真实积极行动系统失败：$e');
    }
  }

  Future<void> _saveProfile() async {
    final profile = RpoProfile(
      commonEmotions: _split(_emotionsCtrl.text),
      commonOldQuestions: _splitLines(_oldQuestionsCtrl.text),
      commonPatterns: _split(_patternsCtrl.text),
      currentTroubles: _splitLines(_currentTroublesCtrl.text),
      supportPeople: _split(_supportCtrl.text),
      relationshipMap: _splitLines(_relationshipMapCtrl.text),
      stretchAreas: _split(_stretchAreasCtrl.text),
      gratitudeAssets: _splitLines(_gratitudeCtrl.text),
      peakExperiences: _splitLines(_peakCtrl.text),
      identityEvidence: _splitLines(_identityCtrl.text),
      valueBindings: _profile.valueBindings,
    );
    await _dao.saveProfile(profile);
    await _load();
    _toast('人格地图已保存');
  }

  Future<void> _generate() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) {
      _toast('请先写下一个真实处境、情绪、好事、旧模式或想改变的目标。');
      return;
    }
    setState(() => _generating = true);
    try {
      final result = await _ai.generate(userInput: input, sceneType: _sceneType, profile: _profile);
      await _dao.upsertRecord(result.record);
      await _dao.materializeRecordAssets(result.record);
      await _load();
      if (!mounted) return;
      _tab.animateTo(1);
      _toast(result.usedAi ? 'AI 已生成行动卡' : 'AI 未可用，已使用本地价值引擎生成行动卡');
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _deleteRecord(RpoPracticeRecord item) async {
    await _dao.deleteRecord(item.id);
    await _load();
    _toast('已删除记录');
  }


  Future<void> _applyLatestToProfile() async {
    final item = _latest;
    if (item == null) {
      _toast('暂无可沉淀的行动卡。');
      return;
    }
    await _dao.applyRecordToProfile(item);
    await _load();
    _toast('已将本次行动卡沉淀到人格地图。');
  }

  Future<void> _completeEvidence(Map<String, Object?> evidence) async {
    final id = (evidence['id'] ?? '').toString();
    if (id.isEmpty) return;
    final ctrl = TextEditingController(text: (evidence['reflection'] ?? '').toString());
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('完成行动并写一句复盘'),
        content: TextField(
          controller: ctrl,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '行动后，我看见了什么新的现实或身份证据？',
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('保存完成')),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    final actionTitle = (evidence['action_title'] ?? '').toString();
    await _dao.updateActionEvidence(
      id: id,
      status: 'done',
      evidenceText: actionTitle.isEmpty ? '已完成一个真实积极行动' : '已完成：$actionTitle',
      reflection: result,
    );
    await _load();
    _toast('行动已闭环，已更新行动证据。');
  }

  void _openWorkbench([String scene = 'reality_lens']) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RealisticPositivityOsWorkbenchPage(initialSceneType: scene, profile: _profile),
    )).then((_) => _load());
  }

  void _openPromptCenter([String promptId = RealisticPositivityOsPromptConfig.globalId]) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AiPromptSettingsPage(
        initialModuleId: RealisticPositivityOsPromptConfig.moduleId,
        initialPromptId: promptId,
      ),
    ));
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空真实积极行动系统数据？'),
        content: const Text('将删除本独立模块的训练卡、资产、行动证据与人格地图，不影响其他模块。该操作不可恢复。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.clearAll();
      await _load();
      _toast('已清空本模块数据');
    }
  }

  List<String> _split(String text) => text
      .split(RegExp(r'[,，;；\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  List<String> _splitLines(String text) => text
      .split(RegExp(r'[\n;；]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('真实积极行动系统', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: <Widget>[
          IconButton(onPressed: () => _openPromptCenter(), icon: const Icon(Icons.tune_outlined), tooltip: 'AI 提示词统一配置中心'),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _clearAll, icon: const Icon(Icons.delete_outline)),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const <Widget>[
            Tab(text: '今日训练'),
            Tab(text: '行动卡'),
            Tab(text: '12模块'),
            Tab(text: '系统层'),
            Tab(text: '覆盖审计'),
            Tab(text: '生命周期'),
            Tab(text: '长期实验'),
            Tab(text: '激活审计'),
            Tab(text: '成长档案'),
            Tab(text: '历史记录'),
            Tab(text: 'Prompt'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: <Widget>[
          _buildTodayTab(),
          _buildLatestTab(),
          _buildModulesTab(),
          RealisticPositivityOsSystemPage(embedded: true, profile: _profile),
          RealisticPositivityOsCoveragePage(embedded: true, profile: _profile),
          const RealisticPositivityOsLifecyclePage(),
          RealisticPositivityOsExperimentPage(embedded: true, profile: _profile),
          const RealisticPositivityOsCoverageAuditPage(),
          _buildArchiveTab(),
          _buildHistoryTab(),
          _buildPromptTab(),
        ],
      ),
    );
  }

  Widget _buildTodayTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        _heroCard(),
        const SizedBox(height: 12),
        _statsRow(),
        const SizedBox(height: 12),
        _valueRadarCard(),
        const SizedBox(height: 12),
        _sectionCard(
          title: '今日调度建议',
          subtitle: '根据本独立模块的成长档案与训练记录，提醒今天更适合做哪种训练。',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _infoTile('推荐训练', _dailyRecommendation(), Icons.route_outlined),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              ActionChip(label: const Text('真实看见'), onPressed: () => setState(() => _sceneType = 'reality_lens')),
              ActionChip(label: const Text('允许情绪'), onPressed: () => setState(() => _sceneType = 'emotional_processing')),
              ActionChip(label: const Text('价值绑定'), onPressed: () => setState(() => _sceneType = 'change_lab')),
              ActionChip(label: const Text('行为启动'), onPressed: () => setState(() => _sceneType = 'behavior_first')),
              ActionChip(label: const Text('周整合'), onPressed: () => setState(() => _sceneType = 'weekly_integration')),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'AI 状态诊断入口',
          subtitle: '输入真实处境，AI 会按 Lecture 9–10 价值体系自动生成行动卡。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: _sceneType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '训练场景 / 独立子模块'),
                items: _sceneLabels.entries
                    .map((e) => DropdownMenuItem<String>(value: e.key, child: Text('${e.value} · ${e.key}')))
                    .toList(growable: false),
                onChanged: (v) => setState(() => _sceneType = v ?? 'reality_lens'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _inputCtrl,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: '写下真实处境 / 感恩对象 / 情绪 / 旧模式 / 高峰体验',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickInputs.map((q) => ActionChip(label: Text(_limit(q, 18)), onPressed: () => setState(() => _inputCtrl.text = q))).toList(growable: false),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _generating ? null : _generate,
                  icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                  label: Text(_generating ? '正在生成行动卡……' : '生成真实积极行动卡'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '今日人格训练面板',
          subtitle: '不是幸福分数，也不是打卡崇拜，而是训练真实、感恩、接纳、行动与成长。',
          child: Column(
            children: <Widget>[
              _trainingButton(Icons.visibility_outlined, '我需要看清一件事', 'Reality Lens：同时看见困难、资源和可控 1%。', 'reality_lens'),
              _trainingButton(Icons.volunteer_activism_outlined, '我想珍惜一件事', 'Gratitude：具体、感官化、保持 freshness。', 'gratitude'),
              _trainingButton(Icons.favorite_border, '我需要允许一种情绪', 'Permission to be human：先接纳，再行动。', 'emotional_processing'),
              _trainingButton(Icons.psychology_alt_outlined, '我想改变一个旧模式', 'Change Lab：保留价值，放下痛苦形式。', 'change_lab'),
              _trainingButton(Icons.directions_run_outlined, '我愿意做一个小行动', 'Behavior First：不等动力，先启动 2 分钟。', 'behavior_first'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: <Color>[Color(0xFF111827), Color(0xFF4338CA)]),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x22111827), blurRadius: 22, offset: Offset(0, 10))],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Realistic Positivity OS', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text('基于《哈佛积极心理学》Lecture 9–10：感恩、真实看见、允许为人、改变、ABC、Stretch Zone 与 Peak Experience。', style: TextStyle(color: Color(0xFFE0E7FF), height: 1.45)),
          SizedBox(height: 12),
          Text('目标不是短暂积极，而是把课程价值转化成现实行动和人格证据。', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _valueRadarCard() {
    final values = <_StatItem>[
      _StatItem('真实看见', _stats.totalRecords.toString(), Icons.visibility_outlined),
      _StatItem('感恩表达', (_stats.gratitudeCount + _stats.relationshipCount).toString(), Icons.volunteer_activism_outlined),
      _StatItem('情绪整合', _stats.emotionCount.toString(), Icons.favorite_border),
      _StatItem('改变实验', _stats.changeCount.toString(), Icons.psychology_alt_outlined),
      _StatItem('行为证据', _stats.identityEvidenceCount.toString(), Icons.verified_outlined),
      _StatItem('Stretch', _stats.stretchCount.toString(), Icons.trending_up),
      _StatItem('高峰体验', _stats.peakCount.toString(), Icons.auto_awesome_outlined),
      _StatItem('安全支持', _stats.crisisCount.toString(), Icons.health_and_safety_outlined),
    ];
    return _sectionCard(
      title: '核心价值覆盖雷达',
      subtitle: '用产品指标校验是否真正覆盖终极设计方案：不是只看打卡，而是看真实、感恩、接纳、改变、行动、Stretch、高峰体验和安全边界。',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values.map((e) => Chip(
          avatar: Icon(e.icon, size: 18, color: const Color(0xFF4F46E5)),
          label: Text('${e.label} ${e.value}'),
          backgroundColor: const Color(0xFFF8FAFC),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        )).toList(growable: false),
      ),
    );
  }

  Widget _statsRow() {
    final items = <_StatItem>[
      _StatItem('训练卡', _stats.totalRecords.toString(), Icons.dashboard_customize_outlined),
      _StatItem('感恩', _stats.gratitudeCount.toString(), Icons.volunteer_activism_outlined),
      _StatItem('情绪整合', _stats.emotionCount.toString(), Icons.favorite_border),
      _StatItem('改变', _stats.changeCount.toString(), Icons.change_circle_outlined),
      _StatItem('行动证据', _stats.identityEvidenceCount.toString(), Icons.verified_outlined),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: items.map((e) => _statCard(e)).toList(growable: false)),
    );
  }

  Widget _statCard(_StatItem item) {
    return Container(
      width: 112,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Icon(item.icon, color: const Color(0xFF4F46E5)),
        const SizedBox(height: 8),
        Text(item.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        Text(item.label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ]),
    );
  }

  Widget _trainingButton(IconData icon, String title, String subtitle, String scene) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _sceneType = scene),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _sceneType == scene ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _sceneType == scene ? const Color(0xFF818CF8) : const Color(0xFFE5E7EB)),
          ),
          child: Row(children: <Widget>[
            Icon(icon, color: const Color(0xFF4F46E5)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ])),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }

  Widget _buildLatestTab() {
    final item = _latest;
    if (item == null) {
      return const Center(child: Text('暂无行动卡。请先在“今日训练”生成一次。'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        _recordDetailCard(item),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.icon(onPressed: _applyLatestToProfile, icon: const Icon(Icons.archive_outlined), label: const Text('沉淀到人格地图')),
            OutlinedButton.icon(onPressed: () => _openPromptCenter(RealisticPositivityOsPromptConfig.outputCommonId), icon: const Icon(Icons.tune_outlined), label: const Text('配置输出 Prompt')),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '行动闭环',
          subtitle: '真实事件 → 状态诊断 → 课程价值 → 问题重构 → 最小行动 → 复盘 → 新身份证据。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _infoTile('最小行动', '${item.microAction.title} · ${item.microAction.durationMinutes} 分钟', Icons.play_circle_outline),
              for (final step in item.microAction.steps) _bullet(step),
              const SizedBox(height: 8),
              _infoTile('复盘问题', item.reflectionQuestion, Icons.rate_review_outlined),
              _infoTile('新身份证据', item.identityEvidence, Icons.verified_outlined),
            ],
          ),
        ),
      ],
    );
  }

  Widget _recordDetailCard(RpoPracticeRecord item) {
    return _sectionCard(
      title: item.title,
      subtitle: '${_sceneLabels[item.sceneType] ?? item.sceneType} · 风险：${item.riskLevel} · ${_formatTime(item.createdAtMs)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (item.userInput.trim().isNotEmpty) _quoteBox('用户输入', item.userInput),
          _chipWrap(item.coreValues),
          _infoTile('真实处境', item.realSituation, Icons.visibility_outlined),
          _infoTile('旧问题', item.oldQuestion, Icons.help_outline),
          _infoTile('更好的问题', item.betterQuestion, Icons.lightbulb_outline),
          _infoTile('干预摘要', item.interventionSummary, Icons.psychology_alt_outlined),
          if (item.abcPlan.affect.isNotEmpty || item.abcPlan.behavior.isNotEmpty || item.abcPlan.cognition.isNotEmpty)
            _abcBlock(item.abcPlan),
          if (item.valueBinding.isNotEmpty) _bindingBlock(item.valueBinding),
          if (item.relationshipAction.trim().isNotEmpty) _infoTile('关系行动', item.relationshipAction, Icons.people_alt_outlined),
          if (item.savoringOrMeaningMaking.trim().isNotEmpty) _infoTile('重温/整合', item.savoringOrMeaningMaking, Icons.auto_stories_outlined),
          if (item.stretchZone.nextChallenge.trim().isNotEmpty) _infoTile('Stretch Zone', '${item.stretchZone.currentZone} · ${item.stretchZone.nextChallenge}', Icons.trending_up),
          if (item.safetyNote.trim().isNotEmpty) _quoteBox('安全提示', item.safetyNote, color: const Color(0xFFFFF1F2)),
          if (item.displayCards.isNotEmpty) const SizedBox(height: 8),
          for (final card in item.displayCards) _displayCard(card),
        ],
      ),
    );
  }

  Widget _buildModulesTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        _sectionCard(
          title: '深度训练工作台 V5',
          subtitle: '把终极产品方案进一步落地：每个子模块都有专用表单、课程思想层、成长路径、覆盖度审计、生命周期实验、Prompt 快捷配置、AI 生成、行动复盘与人格地图沉淀。',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const _StaticBullet('不再只是一个通用行动卡入口，而是 12+1 个子模块的专用训练工作台。'),
            const _StaticBullet('覆盖 Onboarding、真实看见、问题重构、感恩、关系感恩、情绪处理、痛苦整合、积极经验、改变、ABC、行为优先、Stretch、周整合。'),
            const _StaticBullet('每个子模块可直接跳转到 AI 提示词统一配置中心修改对应 Prompt。'),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _openWorkbench(_sceneType), icon: const Icon(Icons.dashboard_customize_outlined), label: const Text('进入 RPO 深度训练工作台'))),
            const SizedBox(height: 8),
            Row(children: <Widget>[
              Expanded(child: OutlinedButton.icon(onPressed: () => _tab.animateTo(3), icon: const Icon(Icons.layers_outlined), label: const Text('系统层'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () => _tab.animateTo(4), icon: const Icon(Icons.check_circle_outline), label: const Text('覆盖审计'))),
            ]),
            const SizedBox(height: 8),
            Row(children: <Widget>[
              Expanded(child: OutlinedButton.icon(onPressed: () => _tab.animateTo(5), icon: const Icon(Icons.assignment_turned_in_outlined), label: const Text('生命周期'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () => _tab.animateTo(6), icon: const Icon(Icons.event_note_outlined), label: const Text('长期实验'))),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '14 个独立子功能模块',
          subtitle: '完整覆盖 Lecture 9–10 的中心思想、核心价值体系与安全边界。',
          child: Column(
            children: RealisticPositivityOsPromptConfig.moduleMatrix.map((m) {
              final id = m['id'] ?? 'reality_lens';
              final scene = id;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openWorkbench(scene),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    CircleAvatar(backgroundColor: const Color(0xFFEEF2FF), child: Text('${RealisticPositivityOsPromptConfig.moduleMatrix.indexOf(m) + 1}', style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w900))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                      Text(m['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(m['value'] ?? '', style: const TextStyle(color: Color(0xFF64748B), height: 1.35)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 6, children: <Widget>[
                        ActionChip(label: const Text('进入专用工作台'), onPressed: () => _openWorkbench(scene)),
                        ActionChip(label: const Text('配置 Prompt'), onPressed: () => _openPromptCenter(RealisticPositivityOsPromptConfig.sceneToPromptId[scene] ?? RealisticPositivityOsPromptConfig.stateDiagnosisId)),
                      ]),
                    ])),
                  ]),
                ),
              );
            }).toList(growable: false),
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '价值闭环',
          subtitle: '真实事件 → AI 状态诊断 → 匹配课程核心价值 → 问题重构 → 情绪接纳/感恩重温 → ABC 行动 → 复盘 → 新身份证据。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              _StaticBullet('痛苦场景优先 permission to be human，不强迫积极。'),
              _StaticBullet('积极场景优先 savoring，不把快乐过度拆解。'),
              _StaticBullet('改变失败优先价值绑定拆解，不责备用户。'),
              _StaticBullet('低动力优先行为启动，不等待动力。'),
              _StaticBullet('panic zone 优先降级与社会支持，不做成长挑战。'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '价值绑定数据库',
          subtitle: 'Lecture 10 的核心：保留珍贵价值，放下痛苦形式。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              _StaticBullet('完美主义 → 雄心/优秀 → 高标准 + 允许粗糙第一版'),
              _StaticBullet('焦虑 → 责任感/认真 → 计划 + 放下灾难预演'),
              _StaticBullet('内疚 → 善良/同理心 → 关心他人 + 清晰边界'),
              _StaticBullet('挑错 → 现实感/标准 → 完整现实 + 建设性反馈'),
              _StaticBullet('忙碌成瘾 → 价值感 → 有节奏投入 + 恢复能量'),
              _StaticBullet('讨好 → 爱与连接 → 真实表达 + 保持关系'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArchiveTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        _sectionCard(
          title: 'Onboarding 人格地图',
          subtitle: '这些信息会作为 AI 的长期背景，但仍保持在本独立模块中。',
          child: Column(children: <Widget>[
            _profileField(_emotionsCtrl, '常见情绪', '焦虑，羞耻，疲惫'),
            _profileField(_oldQuestionsCtrl, '常见旧问题', '我为什么这么废？\n我是不是永远改不了？', minLines: 2),
            _profileField(_patternsCtrl, '常见旧模式', '完美主义，拖延，反刍'),
            _profileField(_currentTroublesCtrl, '当前困扰地图', '拖延写作\n关系冲突后反刍', minLines: 2),
            _profileField(_supportCtrl, '支持关系', '朋友A，家人B，导师C'),
            _profileField(_relationshipMapCtrl, '关系地图 / 感恩与求助对象', '想感谢的老师\n可求助的朋友', minLines: 2),
            _profileField(_stretchAreasCtrl, 'Stretch Zone 成长方向', '表达，边界，学习启动'),
            _profileField(_gratitudeCtrl, '感恩资产', '热水澡\n朋友的支持\n能自由学习', minLines: 3),
            _profileField(_peakCtrl, '高峰体验', '第一次勇敢表达\n一次深度连接', minLines: 2),
            _profileField(_identityCtrl, '新身份证据', '我能在低动力时启动两分钟', minLines: 3),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saveProfile, icon: const Icon(Icons.save_outlined), label: const Text('保存人格地图'))),
          ]),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '成长资产库',
          subtitle: '由行动卡自动沉淀：感恩资产、高峰体验、价值绑定和新身份证据。',
          child: _assets.isEmpty
              ? const Text('暂无资产。生成行动卡并执行后会自动沉淀。')
              : Column(children: _assets.take(30).map((a) => _assetTile(a)).toList(growable: false)),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '行动证据库',
          subtitle: '小行动不是打卡，而是新身份的证据。',
          child: _evidence.isEmpty
              ? const Text('暂无行动证据。')
              : Column(children: _evidence.take(30).map((e) => _evidenceTile(e)).toList(growable: false)),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_records.isEmpty) return const Center(child: Text('暂无历史记录。'));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final item = _records[index];
        return Card(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          child: ListTile(
            leading: CircleAvatar(backgroundColor: const Color(0xFFEEF2FF), child: Icon(_iconForScene(item.sceneType), color: const Color(0xFF4F46E5))),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text('${_sceneLabels[item.sceneType] ?? item.sceneType} · ${_formatTime(item.createdAtMs)}\n${_limit(item.betterQuestion, 48)}'),
            isThreeLine: true,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _RecordDetailPage(item: item))),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteRecord(item)),
          ),
        );
      },
    );
  }

  Widget _buildPromptTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        _sectionCard(
          title: 'Prompt 已接入统一配置中心',
          subtitle: '本模块所有全局价值层、状态诊断、场景层、输出格式与档案更新 Prompt 都可在设置页自由配置。模块内不再作为唯一写死来源。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FilledButton.icon(onPressed: () => _openPromptCenter(), icon: const Icon(Icons.tune_outlined), label: const Text('打开本模块 Prompt 配置中心')),
              const SizedBox(height: 10),
              const _StaticBullet('配置路径：设置 → AI 提示词统一配置中心 → 真实积极行动系统 · RPO。'),
              const _StaticBullet('已注册：全局价值层、AI 状态诊断、12 个场景层、Onboarding、安全支持、档案更新、行动卡 JSON、档案补丁 JSON。'),
              const _StaticBullet('支持导出/导入本模块 Prompt JSON；保存后下一次 AI 生成立即生效。'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '已注册 Prompt 清单',
          subtitle: '点击任一项可直接定位到统一配置中心。',
          child: Column(
            children: RealisticPositivityOsPromptConfig.allIds.map((id) => ListTile(
              dense: true,
              leading: const Icon(Icons.tune_outlined, color: Color(0xFF4F46E5)),
              title: Text(RealisticPositivityOsPromptConfig.labels[id] ?? id),
              subtitle: Text(id),
              onTap: () => _openPromptCenter(id),
            )).toList(growable: false),
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(title: '源码默认全局价值层预览', subtitle: '只读预览；实际生效模板以配置中心为准。', child: _monoText(RealisticPositivityOsPromptConfig.globalValuePrompt)),
      ],
    );
  }

  Widget _sectionCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        if (subtitle.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), height: 1.35)),
        ],
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _infoTile(String title, String content, IconData icon) {
    if (content.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(content, style: const TextStyle(height: 1.42)),
        ])),
      ]),
    );
  }

  Widget _quoteBox(String title, String content, {Color color = const Color(0xFFF8FAFC)}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        Text(content, style: const TextStyle(height: 1.42)),
      ]),
    );
  }

  Widget _chipWrap(List<String> values) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values.map((v) => Chip(label: Text(v), backgroundColor: const Color(0xFFEEF2FF), side: BorderSide.none)).toList(growable: false),
      ),
    );
  }

  Widget _abcBlock(RpoAbcPlan abc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF0FDFA), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('ABC 改变模型', style: TextStyle(fontWeight: FontWeight.w900)),
        _bullet('Affect 情绪：${abc.affect}'),
        _bullet('Behavior 行为：${abc.behavior}'),
        _bullet('Cognition 认知：${abc.cognition}'),
      ]),
    );
  }

  Widget _bindingBlock(RpoValueBinding binding) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('价值绑定拆解', style: TextStyle(fontWeight: FontWeight.w900)),
        _bullet('你不需要消灭：${binding.oldPattern}'),
        _bullet('你真正想保留：${binding.boundValue}'),
        _bullet('需要放下：${binding.painfulForm}'),
        _bullet('健康表达：${binding.healthyExpression}'),
      ]),
    );
  }

  Widget _bullet(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('•  '),
        Expanded(child: Text(text, style: const TextStyle(height: 1.38))),
      ]),
    );
  }

  Widget _displayCard(Map<String, dynamic> card) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text((card['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text((card['content'] ?? '').toString(), style: const TextStyle(height: 1.38)),
      ]),
    );
  }

  Widget _profileField(TextEditingController ctrl, String label, String hint, {int minLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        minLines: minLines,
        maxLines: minLines + 3,
        decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _assetTile(Map<String, Object?> a) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.folder_special_outlined, color: Color(0xFF4F46E5)),
      title: Text((a['title'] ?? '').toString()),
      subtitle: Text('${a['asset_type'] ?? ''} · ${_limit((a['content'] ?? '').toString(), 42)}'),
    );
  }

  Widget _evidenceTile(Map<String, Object?> e) {
    final status = (e['status'] ?? '').toString();
    return ListTile(
      dense: true,
      leading: Icon(status == 'done' ? Icons.verified : Icons.radio_button_unchecked, color: status == 'done' ? const Color(0xFF059669) : const Color(0xFF64748B)),
      title: Text((e['action_title'] ?? '').toString()),
      subtitle: Text('$status · ${_limit((e['evidence_text'] ?? '').toString(), 42)}${(e['reflection'] ?? '').toString().trim().isEmpty ? '' : '\n复盘：${_limit((e['reflection'] ?? '').toString(), 42)}'}'),
      isThreeLine: (e['reflection'] ?? '').toString().trim().isNotEmpty,
      trailing: status == 'done' ? null : TextButton(onPressed: () => _completeEvidence(e), child: const Text('完成')),
    );
  }

  Widget _monoText(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16)),
      child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFE2E8F0), height: 1.42)),
    );
  }

  IconData _iconForScene(String scene) {
    switch (scene) {
      case 'gratitude': return Icons.volunteer_activism_outlined;
      case 'relational_gratitude': return Icons.people_alt_outlined;
      case 'emotional_processing': return Icons.favorite_border;
      case 'meaning_making': return Icons.edit_note_outlined;
      case 'savoring_peak': return Icons.auto_awesome_outlined;
      case 'change_lab': return Icons.psychology_alt_outlined;
      case 'behavior_first': return Icons.play_circle_outline;
      case 'stretch_zone': return Icons.trending_up;
      case 'weekly_integration': return Icons.calendar_month_outlined;
      default: return Icons.visibility_outlined;
    }
  }



  String _sampleForScene(String scene) {
    switch (scene) {
      case 'question_reframing':
        return '我总是在问“我为什么这么废”，想把这个问题换成更真实、更能行动的问题。';
      case 'gratitude':
        return '今天我想练习感恩，但不想机械列清单，请帮我重新体验一个平时被忽略的日常资源。';
      case 'relational_gratitude':
        return '我想感谢一个曾经帮助过我的人，但不知道如何表达得具体、真诚又不尴尬。';
      case 'emotional_processing':
        return '我今天很难过/焦虑，不想被强行积极，只想先允许自己真实感受，然后做一个小行动。';
      case 'meaning_making':
        return '有件痛苦的事我一直反复想，请帮我从反刍转向书写、表达、支持和修复行动。';
      case 'savoring_peak':
        return '今天有一个很温暖/高光的时刻，我想把它重温、保存，并转成一个延续行动。';
      case 'change_lab':
        return '我想改变一个旧模式但总失败，请帮我看它是否绑定了某个珍贵价值。';
      case 'abc_change':
        return '我有一个想改变的目标，请用 Affect / Behavior / Cognition 三层帮我设计 7 天小实验。';
      case 'behavior_first':
        return '我现在没有动力，也不想开始，请帮我设计一个 2 分钟启动行为。';
      case 'stretch_zone':
        return '我想突破舒适区，但不想把自己逼到崩溃，请帮我设计 3–5 级挑战阶梯。';
      case 'weekly_integration':
        return '请帮我做本周人格整合：真实看见、感恩、情绪接纳、关系表达、行为行动、价值绑定、stretch 和积极经验。';
      default:
        return '我想把今天的一件事看完整：真实困难是什么，仍有哪些资源，我能影响的 1% 是什么？';
    }
  }

  String _dailyRecommendation() {
    if (_stats.crisisCount > 0) return '最近出现过高风险/安全相关记录，今天优先做安全支持与现实支持连接，不做挑战。';
    if (_stats.emotionCount < 2) return '建议先做“允许为人”：命名一种情绪，接纳后只给一个小行动。';
    if (_stats.gratitudeCount < 2) return '建议做一次感恩 Freshness：选择一个平时视为理所当然的日常资源，具体重温。';
    if (_stats.changeCount < 2) return '建议做一次价值绑定拆解：看看旧模式正在保护哪个珍贵价值。';
    if (_stats.identityEvidenceCount < 3) return '建议做“行为优先”：完成一个 2–10 分钟行动，把它沉淀为新身份证据。';
    return '建议做每周人格整合：从真实看见、感恩、接纳、行动、关系、Stretch 中提取本周证据。';
  }

  String _limit(String text, int max) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.runes.length <= max) return clean;
    return String.fromCharCodes(clean.runes.take(max)) + '…';
  }

  String _formatTime(int ms) {
    if (ms <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _RecordDetailPage extends StatelessWidget {
  final RpoPracticeRecord item;
  const _RecordDetailPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(item.title), backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: SelectableText(item.rawJson.isEmpty ? item.toJson().toString() : item.rawJson),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  const _StatItem(this.label, this.value, this.icon);
}

class _StaticBullet extends StatelessWidget {
  final String text;
  const _StaticBullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('•  '),
        Expanded(child: Text(text, style: const TextStyle(height: 1.38))),
      ]),
    );
  }
}
