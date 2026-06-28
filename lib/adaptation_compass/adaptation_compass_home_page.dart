import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'adaptation_compass_ai_service.dart';
import 'adaptation_compass_content.dart';
import 'adaptation_compass_dao.dart';
import 'adaptation_compass_models.dart';
import '../pages/ai_prompt_settings_page.dart';

import 'adaptation_compass_prompt_config.dart';

class AdaptationCompassHomePage extends StatefulWidget {
  final String initialScene;
  final String initialInput;
  const AdaptationCompassHomePage({super.key, this.initialScene = 'daily_stress', this.initialInput = ''});

  @override
  State<AdaptationCompassHomePage> createState() => _AdaptationCompassHomePageState();
}

class _AdaptationCompassHomePageState extends State<AdaptationCompassHomePage> with SingleTickerProviderStateMixin {
  final AdaptationCompassDao _dao = AdaptationCompassDao();
  final AdaptationCompassAiService _ai = AdaptationCompassAiService();
  late final TabController _tabs;
  final TextEditingController _inputCtrl = TextEditingController();
  final TextEditingController _balanceNoteCtrl = TextEditingController();
  final TextEditingController _profileValuesCtrl = TextEditingController();
  final TextEditingController _profileDefensesCtrl = TextEditingController();
  final TextEditingController _profileRelationsCtrl = TextEditingController();
  final TextEditingController _profileChildhoodCtrl = TextEditingController();
  final TextEditingController _profileTaskCtrl = TextEditingController();
  final TextEditingController _profileSafetyCtrl = TextEditingController();
  final TextEditingController _relationNameCtrl = TextEditingController();
  final TextEditingController _relationNoteCtrl = TextEditingController();
  final TextEditingController _timelineEventCtrl = TextEditingController();
  final TextEditingController _timelineOldCtrl = TextEditingController();
  final TextEditingController _timelineMatureCtrl = TextEditingController();
  final TextEditingController _timelineEvidenceCtrl = TextEditingController();
  final TextEditingController _contributionTargetCtrl = TextEditingController();
  final TextEditingController _contributionMotivationCtrl = TextEditingController();
  final TextEditingController _contributionBoundaryCtrl = TextEditingController();
  final TextEditingController _contributionResultCtrl = TextEditingController();
  final TextEditingController _healthSymptomsCtrl = TextEditingController();
  final TextEditingController _healthNoteCtrl = TextEditingController();
  final TextEditingController _courseReflectionCtrl = TextEditingController();

  bool _loading = true;
  bool _generating = false;
  String _scene = 'daily_stress';
  int _work = 5;
  int _love = 5;
  int _play = 5;
  int _body = 5;
  String _relationType = '安全关系';
  int _relationTrust = 5;
  int _relationIntimacy = 5;
  int _relationConflict = 3;
  int _relationSupport = 5;
  int _relationBoundary = 5;
  String _timelineChapter = '当前阶段';
  String _contributionForm = '经验分享';
  int _contributionMeaning = 5;
  int _sleepQuality = 5;
  int _alcoholRisk = 0;
  int _exerciseMinutes = 20;
  int _stressBody = 5;
  AdaptationCompassProfile _profile = const AdaptationCompassProfile();
  AdaptationCompassStats _stats = const AdaptationCompassStats();
  List<AdaptationCompassSession> _sessions = const <AdaptationCompassSession>[];
  List<AdaptationCompassAction> _actions = const <AdaptationCompassAction>[];
  List<AdaptationCompassBalanceEntry> _balance = const <AdaptationCompassBalanceEntry>[];
  List<AdaptationCompassRelationshipEntry> _relationships = const <AdaptationCompassRelationshipEntry>[];
  List<AdaptationCompassTimelineEntry> _timeline = const <AdaptationCompassTimelineEntry>[];
  List<AdaptationCompassContributionEntry> _contributions = const <AdaptationCompassContributionEntry>[];
  List<AdaptationCompassHealthEntry> _health = const <AdaptationCompassHealthEntry>[];
  List<AdaptationCompassCourseProgress> _courseProgress = const <AdaptationCompassCourseProgress>[];

  @override
  void initState() {
    super.initState();
    _scene = widget.initialScene;
    _inputCtrl.text = widget.initialInput;
    _tabs = TabController(length: 9, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _inputCtrl.dispose();
    _balanceNoteCtrl.dispose();
    _profileValuesCtrl.dispose();
    _profileDefensesCtrl.dispose();
    _profileRelationsCtrl.dispose();
    _profileChildhoodCtrl.dispose();
    _profileTaskCtrl.dispose();
    _profileSafetyCtrl.dispose();
    _relationNameCtrl.dispose();
    _relationNoteCtrl.dispose();
    _timelineEventCtrl.dispose();
    _timelineOldCtrl.dispose();
    _timelineMatureCtrl.dispose();
    _timelineEvidenceCtrl.dispose();
    _contributionTargetCtrl.dispose();
    _contributionMotivationCtrl.dispose();
    _contributionBoundaryCtrl.dispose();
    _contributionResultCtrl.dispose();
    _healthSymptomsCtrl.dispose();
    _healthNoteCtrl.dispose();
    _courseReflectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = await _dao.getProfile();
    final sessions = await _dao.recentSessions(limit: 50);
    final actions = await _dao.recentActions(limit: 50);
    final balance = await _dao.recentBalance(limit: 30);
    final relationships = await _dao.recentRelationships(limit: 30);
    final timeline = await _dao.recentTimeline(limit: 30);
    final contributions = await _dao.recentContributions(limit: 30);
    final health = await _dao.recentHealth(limit: 30);
    final courseProgress = await _dao.recentCourseProgress(limit: 30);
    final stats = await _dao.stats();
    if (!mounted) return;
    _profile = profile;
    _profileValuesCtrl.text = profile.values;
    _profileDefensesCtrl.text = profile.repeatedDefenses;
    _profileRelationsCtrl.text = profile.relationshipPatterns;
    _profileChildhoodCtrl.text = profile.childhoodClimate;
    _profileTaskCtrl.text = profile.developmentTask;
    _profileSafetyCtrl.text = profile.safetyResources;
    setState(() {
      _sessions = sessions;
      _actions = actions;
      _balance = balance;
      _relationships = relationships;
      _timeline = timeline;
      _contributions = contributions;
      _health = health;
      _courseProgress = courseProgress;
      _stats = stats;
      _loading = false;
    });
  }

  Future<void> _generate() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) {
      _toast('请先写下一个真实事件、冲突或复盘材料。');
      return;
    }
    setState(() => _generating = true);
    try {
      final recent = await _dao.recentContextJson(limit: 8);
      final session = await _ai.generate(scene: _scene, userInput: input, profile: _profile, recentContextJson: recent);
      await _dao.insertSession(session);
      _inputCtrl.clear();
      await _load();
      if (mounted) {
        _tabs.animateTo(0);
        _toast('已生成分析卡，并自动创建 10分钟 / 24小时 / 7天行动。');
      }
    } catch (e) {
      if (mounted) _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _saveBalance() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dao.insertBalance(AdaptationCompassBalanceEntry(
      createdAtMs: now,
      work: _work,
      love: _love,
      play: _play,
      body: _body,
      note: _balanceNoteCtrl.text.trim(),
    ));
    _balanceNoteCtrl.clear();
    await _load();
    _toast('已保存四维平衡记录。');
  }


  Future<void> _saveRelationship() async {
    final name = _relationNameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('请先填写关系对象名称或代称。');
      return;
    }
    await _dao.insertRelationship(AdaptationCompassRelationshipEntry(
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      name: name,
      type: _relationType,
      trust: _relationTrust,
      intimacy: _relationIntimacy,
      conflict: _relationConflict,
      support: _relationSupport,
      boundary: _relationBoundary,
      note: _relationNoteCtrl.text.trim(),
    ));
    _relationNameCtrl.clear();
    _relationNoteCtrl.clear();
    await _load();
    _toast('已保存关系地图记录。');
  }

  Future<void> _saveTimeline() async {
    final event = _timelineEventCtrl.text.trim();
    if (event.isEmpty) {
      _toast('请先写下一个生命章节事件。');
      return;
    }
    await _dao.insertTimeline(AdaptationCompassTimelineEntry(
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      chapter: _timelineChapter,
      event: event,
      oldAdaptation: _timelineOldCtrl.text.trim(),
      matureShift: _timelineMatureCtrl.text.trim(),
      evidence: _timelineEvidenceCtrl.text.trim(),
    ));
    _timelineEventCtrl.clear();
    _timelineOldCtrl.clear();
    _timelineMatureCtrl.clear();
    _timelineEvidenceCtrl.clear();
    await _load();
    _toast('已加入生命时间线。');
  }

  Future<void> _saveContribution() async {
    final target = _contributionTargetCtrl.text.trim();
    if (target.isEmpty) {
      _toast('请先填写想帮助的人、群体或对象。');
      return;
    }
    await _dao.insertContribution(AdaptationCompassContributionEntry(
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      target: target,
      form: _contributionForm,
      motivation: _contributionMotivationCtrl.text.trim(),
      boundary: _contributionBoundaryCtrl.text.trim(),
      result: _contributionResultCtrl.text.trim(),
      meaning: _contributionMeaning,
    ));
    _contributionTargetCtrl.clear();
    _contributionMotivationCtrl.clear();
    _contributionBoundaryCtrl.clear();
    _contributionResultCtrl.clear();
    await _load();
    _toast('已保存生成性贡献记录。');
  }


  Future<void> _saveHealth() async {
    await _dao.insertHealth(AdaptationCompassHealthEntry(
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      sleepQuality: _sleepQuality,
      alcoholRisk: _alcoholRisk,
      exerciseMinutes: _exerciseMinutes,
      stressBody: _stressBody,
      symptoms: _healthSymptomsCtrl.text.trim(),
      note: _healthNoteCtrl.text.trim(),
    ));
    _healthSymptomsCtrl.clear();
    _healthNoteCtrl.clear();
    await _load();
    _toast('已保存身体健康与压力日志。');
  }

  Future<void> _saveCourseProgress(AdaptationCourseWeek week, {String status = 'done'}) async {
    await _dao.insertCourseProgress(AdaptationCompassCourseProgress(
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      week: week.week,
      title: week.title,
      status: status,
      reflection: _courseReflectionCtrl.text.trim(),
    ));
    _courseReflectionCtrl.clear();
    await _load();
    _toast('已保存第 ${week.week} 周课程进度。');
  }

  Future<void> _generateFromContext(String scene) async {
    setState(() => _generating = true);
    try {
      final recent = await _dao.recentContextJson(limit: 30);
      final spec = _sceneSpec(scene);
      final input = '''${spec.template}

请基于本模块已有记录、行动、关系、时间线、健康日志、课程进度和生成性贡献，生成该场景需要的完整输出。''';
      final session = await _ai.generate(scene: scene, userInput: input, profile: _profile, recentContextJson: recent);
      await _dao.insertSession(session);
      await _load();
      if (mounted) {
        _tabs.animateTo(0);
        _toast('已生成${spec.title}。');
      }
    } catch (e) {
      if (mounted) _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _copyExportJson() async {
    final json = await _dao.exportAllJson();
    await Clipboard.setData(ClipboardData(text: json));
    _toast('已复制 Adaptation Compass 独立模块 JSON 导出。');
  }

  Future<void> _confirmClearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空成熟适应力罗盘数据？'),
        content: const Text('这会清空本模块的分析、行动、四维平衡、关系、时间线、贡献、身体日志、课程进度和个人背景，不影响其他模块。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('确认清空')),
        ],
      ),
    );
    if (ok != true) return;
    await _dao.clearAll();
    await _load();
    _toast('已清空 Adaptation Compass 独立模块数据。');
  }

  Future<void> _openPromptSettings() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const AiPromptSettingsPage(
        initialModuleId: 'adaptation_compass',
        initialPromptId: AdaptationCompassPromptConfig.globalId,
      ),
    ));
  }

  Future<void> _saveProfile() async {
    final p = AdaptationCompassProfile(
      values: _profileValuesCtrl.text.trim(),
      repeatedDefenses: _profileDefensesCtrl.text.trim(),
      relationshipPatterns: _profileRelationsCtrl.text.trim(),
      childhoodClimate: _profileChildhoodCtrl.text.trim(),
      developmentTask: _profileTaskCtrl.text.trim(),
      safetyResources: _profileSafetyCtrl.text.trim(),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _dao.saveProfile(p);
    await _load();
    _toast('个人价值与长期背景已保存。');
  }

  Future<void> _toggleAction(AdaptationCompassAction action) async {
    final next = action.status == 'done' ? 'open' : 'done';
    await _dao.updateActionStatus(action, next);
    await _load();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(milliseconds: 1400)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2EA),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('成熟适应力罗盘'),
            Text('Adaptation Compass · Adaptation to Life', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        backgroundColor: const Color(0xFFF6F2EA),
        foregroundColor: const Color(0xFF2C241C),
        elevation: 0,
        actions: <Widget>[
          IconButton(
            tooltip: '本模块 AI 提示词配置',
            onPressed: _openPromptSettings,
            icon: const Icon(Icons.tune_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: const Color(0xFF6B4E2E),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFF6B4E2E),
          tabs: const <Widget>[
            Tab(text: '首页'),
            Tab(text: 'AI 分析'),
            Tab(text: '防御/现实'),
            Tab(text: '冲突转化'),
            Tab(text: '关系亲密'),
            Tab(text: '四维平衡'),
            Tab(text: '发展地图'),
            Tab(text: '课程贡献'),
            Tab(text: '复盘安全'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: <Widget>[
                _dashboardTab(),
                _analysisTab(),
                _defenseRealityTab(),
                _conflictTab(),
                _relationshipTab(),
                _balanceTab(),
                _developmentTab(),
                _courseContributionTab(),
                _reviewSafetyTab(),
              ],
            ),
    );
  }

  Widget _dashboardTab() {
    final latest = _sessions.isNotEmpty ? _sessions.first : null;
    final open = _actions.where((a) => a.status != 'done').take(6).toList();
    return _page(
      children: <Widget>[
        _heroCard(),
        _statsGrid(),
        if (latest != null) _sessionCard(latest, expanded: true) else _emptyCard('还没有记录', '从“AI 分析”写下一个事件，系统会生成成熟适应力分析卡。'),
        _sectionTitle('待完成行动闭环'),
        if (open.isEmpty) _emptyCard('暂无待办行动', '每次 AI 分析会自动生成 10 分钟、24 小时和 7 天行动。'),
        ...open.map(_actionTile),
        _sectionTitle('产品闭环'),
        _flowCard(),
      ],
    );
  }

  Widget _analysisTab() {
    final spec = _sceneSpec(_scene);
    return _page(
      children: <Widget>[
        _sectionCard(
          title: '三层 Prompt 驱动的 AI 成熟适应力分析',
          subtitle: '${AdaptationCompassContent.bookName} · ${AdaptationCompassContent.courseName}',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            DropdownButtonFormField<String>(
              value: _scene,
              decoration: const InputDecoration(labelText: '选择场景层 Prompt', border: OutlineInputBorder()),
              items: AdaptationCompassContent.scenes.map((s) => DropdownMenuItem(value: s.id, child: Text(s.title))).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _scene = v;
                  final next = _sceneSpec(v);
                  _inputCtrl.text = next.template;
                });
              },
            ),
            const SizedBox(height: 12),
            Text(spec.subtitle, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            TextField(
              controller: _inputCtrl,
              minLines: 8,
              maxLines: 16,
              decoration: InputDecoration(
                labelText: spec.title,
                alignLabelWithHint: true,
                hintText: spec.template,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _generating ? null : _generate,
                  icon: _generating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.psychology_alt_outlined),
                  label: Text(_generating ? '生成中…' : '生成成熟适应力分析卡'),
                ),
              ),
            ]),
          ]),
        ),
        _sectionTitle('最近分析'),
        ..._sessions.take(8).map((s) => _sessionCard(s)),
      ],
    );
  }

  Widget _defenseRealityTab() {
    return _page(
      children: <Widget>[
        _sectionCard(
          title: '现实检查室',
          subtitle: '把 Vaillant 的现实主义价值落到具体操作：事实、解释、恐惧、投射、未知信息、可行动部分。',
          child: Wrap(spacing: 8, runSpacing: 8, children: const <Widget>[
            _MiniChip('事实'), _MiniChip('解释'), _MiniChip('恐惧版本'), _MiniChip('希望版本'), _MiniChip('缺失信息'), _MiniChip('低风险验证'), _MiniChip('边界'), _MiniChip('可行动部分'),
          ]),
        ),
        _sectionTitle('四层防御地图'),
        _layerCard('严重现实歪曲风险', '强烈否认现实、妄想性解释、现实检验下降或危险冲动。进入安全支持，不做普通成长分析。', Icons.warning_amber_outlined),
        _layerCard('不成熟防御', '投射、幻想逃避、疑病、被动攻击、行动化。先理解保护功能，再训练现实检查和替代行动。', Icons.shield_outlined),
        _layerCard('神经症性防御', '理智化、压抑、反向形成、置换、情感隔离。能维持功能，但可能牺牲鲜活、游戏和亲密。', Icons.psychology_outlined),
        _layerCard('成熟防御', '升华、利他、幽默、预期、抑制。承认现实和情绪，同时转化为关系友好和建设性行动。', Icons.local_florist_outlined),
        _sectionTitle('防御机制卡片'),
        ...AdaptationCompassContent.defenses.map(_defenseCard),
      ],
    );
  }

  Widget _conflictTab() {
    final conflictModules = AdaptationCompassContent.modules.where((m) => m.title.contains('冲突') || m.title.contains('神经症') || m.title.contains('现实')).toList();
    return _page(
      children: <Widget>[
        _sectionCard(
          title: '冲突转化实验室',
          subtitle: '把愤怒、羞耻、恐惧、嫉妒、孤独和行动化冲动转为更成熟的现实行动。',
          child: Column(children: <Widget>[
            _transformRow('愤怒', '边界表达 / 运动 / 写作 / 现实改变'),
            _transformRow('羞耻', '事实责任 / 自我慈悲 / 修复行动'),
            _transformRow('恐惧', '预期计划 / 求助 / 风险拆解'),
            _transformRow('嫉妒', '欲望识别 / 学习计划 / 目标重设'),
            _transformRow('孤独', '低风险联系 / 真实对话 / 共同活动'),
            _transformRow('行动化', '10 分钟延迟 / 身体稳定 / 支持资源'),
          ]),
        ),
        ...conflictModules.map(_moduleCard),
        _sectionTitle('可直接进入的场景'),
        _sceneButtons(<String>['anger_transform', 'shame_failure', 'anxiety_fear', 'reality_check', 'acting_out', 'high_functioning']),
      ],
    );
  }

  Widget _relationshipTab() {
    final modules = AdaptationCompassContent.modules.where((m) => m.title.contains('关系') || m.title.contains('童年')).toList();
    return _page(
      children: <Widget>[
        _sectionCard(
          title: '关系与亲密系统',
          subtitle: '关系不是心理健康之外的附属物，而是人格成熟的试金石。',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _bullet('安全关系：让我放松、真实、被看见。'),
            _bullet('亲密关系：伴侣、家人、深度朋友。'),
            _bullet('冲突关系：正在消耗或触发我的人。'),
            _bullet('责任关系：孩子、父母、下属、学生、团队。'),
            _bullet('成长关系：导师、治疗师、教练、榜样。'),
            _bullet('贡献关系：我正在帮助或照顾的人。'),
          ]),
        ),
        _relationshipMapCard(),
        _sectionTitle('最近关系地图记录'),
        if (_relationships.isEmpty) _emptyCard('还没有关系记录', '记录一段安全、亲密、冲突、责任、成长或贡献关系，AI 会在后续分析中参考关系背景。'),
        ..._relationships.take(8).map(_relationshipTile),
        ...modules.map(_moduleCard),
        _sectionCard(
          title: '修复对话公式',
          subtitle: '事实 + 感受 + 我的责任 + 我的边界 + 我的请求 + 我愿意听你的部分',
          child: const Text('例：当昨天会议上我的方案被直接否定时，我感到受伤和防御。我后来有点冷淡，这部分我愿意负责。我的需要是被具体说明问题，而不是被整体否定。下次我们能否先列出两个最关键的修改点？'),
        ),
        _sceneButtons(<String>['relationship_conflict', 'intimacy_avoidance', 'childhood_climate', 'understand_other']),
      ],
    );
  }

  Widget _balanceTab() {
    return _page(
      children: <Widget>[
        _sectionCard(
          title: '工作-爱-游戏-身体平衡盘',
          subtitle: '完整健康不是单一成功；工作、亲密、非功利快乐和身体照顾需要共同进入生活。',
          child: Column(children: <Widget>[
            _scoreSlider('工作', _work, (v) => setState(() => _work = v.round())),
            _scoreSlider('爱/关系', _love, (v) => setState(() => _love = v.round())),
            _scoreSlider('游戏/快乐', _play, (v) => setState(() => _play = v.round())),
            _scoreSlider('身体/睡眠/饮酒/运动', _body, (v) => setState(() => _body = v.round())),
            TextField(controller: _balanceNoteCtrl, decoration: const InputDecoration(labelText: '今日四维备注', border: OutlineInputBorder()), minLines: 2, maxLines: 4),
            const SizedBox(height: 12),
            Row(children: <Widget>[Expanded(child: FilledButton.icon(onPressed: _saveBalance, icon: const Icon(Icons.save_outlined), label: const Text('保存四维平衡记录')))]),
          ]),
        ),
        _sectionTitle('最近四维记录'),
        ..._balance.take(10).map(_balanceTile),
        _healthLogCard(),
        _sectionTitle('最近身体健康与压力日志'),
        if (_health.isEmpty) _emptyCard('还没有身体健康日志', '记录睡眠质量、饮酒风险、运动、身体压力和症状，让 AI 不再只从情绪解释身体。'),
        ..._health.take(8).map(_healthTile),
        _sceneButtons(<String>['balance_four', 'body_health', 'work_consolidation']),
      ],
    );
  }

  Widget _developmentTab() {
    return _page(
      children: <Widget>[
        _sectionCard(
          title: '成人发展地图',
          subtitle: '把人生放在阶段任务中理解，而不是用单次状态判断自己。',
          child: Column(children: AdaptationCompassContent.stages.map(_stageTile).toList()),
        ),
        _timelineCard(),
        _sectionTitle('生命时间线记录'),
        if (_timeline.isEmpty) _emptyCard('还没有生命时间线', '记录一个生命章节：它如何塑造旧适应，以及现在想发展什么成熟转化。'),
        ..._timeline.take(8).map(_timelineTile),
        _sectionCard(
          title: '童年重要，但不是命运',
          subtitle: '早年关系气候塑造防御，但成人仍可通过关系、行动、治疗、工作、爱、游戏和时间继续发展。',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const <Widget>[
            Text('要观察的不是单一创伤，而是长期关系气候：温暖、稳定、自治、玩耍、信任、被理解。'),
            SizedBox(height: 8),
            Text('产品引导：承认影响 → 感谢旧防御 → 看见成人资源 → 发展新适应。'),
          ]),
        ),
        _sceneButtons(<String>['life_stage_review', 'childhood_climate', 'high_functioning']),
      ],
    );
  }

  Widget _courseContributionTab() {
    return _page(
      children: <Widget>[
        _sectionCard(
          title: '生成性与贡献计划',
          subtitle: '最高成熟不只是自我成功，而是帮助他人、照顾下一代、创造可延续价值，避免把伤害继续传递。',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _bullet('痛苦转贡献：我经历过什么，因此更能理解谁？'),
            _bullet('贡献边界：我是在真正关怀，还是讨好、控制、过度牺牲？'),
            _bullet('最小行动：一句经验、一次陪伴、一个资源、一次指导。'),
          ]),
        ),
        _contributionCard(),
        _sectionTitle('最近生成性贡献记录'),
        if (_contributions.isEmpty) _emptyCard('还没有贡献记录', '记录一次帮助、分享、指导、照顾、公共表达或作品创造，并检查是否有边界。'),
        ..._contributions.take(8).map(_contributionTile),
        _sectionTitle('12 周课程'),
        _sectionCard(
          title: '课程进度复盘输入',
          subtitle: '写下本周练习后的观察，再点课程卡片中的“标记完成”。课程进度会进入后续 AI 上下文。',
          child: TextField(controller: _courseReflectionCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '本周练习复盘 / 旧防御与成熟转化', border: OutlineInputBorder())),
        ),
        ...AdaptationCompassContent.course.map(_courseTile),
        _sectionTitle('最近课程进度'),
        if (_courseProgress.isEmpty) _emptyCard('还没有课程进度', '完成任意一周练习后，系统会在长期复盘中参考课程学习路径。'),
        ..._courseProgress.take(8).map(_courseProgressTile),
        _sectionTitle('案例路径原型'),
        ...AdaptationCompassContent.caseArchetypes.map((e) => _simpleCard(e)),
        _sceneButtons(<String>['generativity', 'life_stage_review']),
      ],
    );
  }

  Widget _reviewSafetyTab() {
    return _page(
      children: <Widget>[
        _sectionCard(
          title: 'AI 深度复盘',
          subtitle: '7 天、30 天、90 天、年度纵向观察：不以单次情绪判断整个人。',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _bullet('7 天：主要压力、情绪、防御、成熟行动、关系影响。'),
            _bullet('30 天：重复触发器、关系模式、四维失衡、成熟防御变化。'),
            _bullet('90 天：现实感、关系修复、冲动减少、游戏/身体增加、生成性出现。'),
            _bullet('年度：我如何适应生活，哪里更成熟，哪里仍需升级。'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              FilledButton.tonal(onPressed: _generating ? null : () => _generateFromContext('weekly_review'), child: const Text('生成 7 天复盘')),
              FilledButton.tonal(onPressed: _generating ? null : () => _generateFromContext('monthly_review'), child: const Text('生成 30/90 天复盘')),
              FilledButton.tonal(onPressed: _generating ? null : () => _generateFromContext('profile_update'), child: const Text('更新个人适应地图')),
              FilledButton.tonal(onPressed: _generating ? null : () => _generateFromContext('therapist_export'), child: const Text('生成治疗师导出包')),
              OutlinedButton(onPressed: _generating ? null : () => _generateFromContext('prompt_audit'), child: const Text('Prompt/产品覆盖审计')),
            ]),
          ]),
        ),
        _sectionCard(
          title: '个人价值与长期背景',
          subtitle: '这些内容会进入 Adaptation Compass 独立 Prompt 背景，不进入其他模块。',
          child: Column(children: <Widget>[
            _profileField(_profileValuesCtrl, '我重视的价值 / 不想继续传递的伤害'),
            _profileField(_profileDefensesCtrl, '我反复出现的旧防御'),
            _profileField(_profileRelationsCtrl, '我的关系模式'),
            _profileField(_profileChildhoodCtrl, '童年关系气候'),
            _profileField(_profileTaskCtrl, '当前成人发展任务'),
            _profileField(_profileSafetyCtrl, '安全资源 / 可联系的人 / 专业支持'),
            Row(children: <Widget>[Expanded(child: FilledButton.icon(onPressed: _saveProfile, icon: const Icon(Icons.lock_outline), label: const Text('保存独立个人背景')))]),
          ]),
        ),
        _sectionCard(
          title: '本模块 AI 提示词统一配置',
          subtitle: '全局价值层、全部场景层和输出格式层 Prompt 已接入 App 设置页统一配置中心。修改后下一次 AI 调用立即生效。',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _bullet('配置位置：App 设置页 → AI 提示词配置中心 → 成熟适应力罗盘 · Adaptation Compass。'),
            _bullet('可配置项：全局价值层、24 个场景层、输出格式层、JSON 修复、复盘、治疗师导出、Prompt 审计。'),
            _bullet('提示词保存在 ai_prompt.adaptation_compass.*，与其他模块完全隔离。'),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _openPromptSettings, icon: const Icon(Icons.tune_outlined), label: const Text('打开成熟适应力 Prompt 配置')),
          ]),
        ),
        _sectionCard(
          title: '隐私控制与数据导出',
          subtitle: '独立导出或清空 Adaptation Compass 模块数据，不影响其他模块。',
          child: Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            OutlinedButton.icon(onPressed: _copyExportJson, icon: const Icon(Icons.copy_all_outlined), label: const Text('复制本模块 JSON 导出')),
            OutlinedButton.icon(onPressed: _confirmClearAll, icon: const Icon(Icons.delete_outline), label: const Text('清空本模块数据')),
          ]),
        ),
        _sectionCard(
          title: '危机与安全支持',
          subtitle: '高风险时停止普通成长分析，优先现实安全。',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _bullet('自杀、自伤、伤人、家庭暴力、被威胁、严重成瘾、现实检验受损 → 进入安全模式。'),
            _bullet('安全模式：确认安全、远离危险物、联系可信任的人、联系专业/紧急服务、10 分钟安全动作。'),
            _bullet('本 App 不能替代专业医疗、心理治疗、危机干预或紧急服务。'),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () => _jumpScene('safety_support'), icon: const Icon(Icons.health_and_safety_outlined), label: const Text('打开安全支持场景')),
          ]),
        ),
      ],
    );
  }


  Widget _relationshipMapCard() => _sectionCard(
        title: '关系地图记录器',
        subtitle: '把安全关系、亲密关系、冲突关系、责任关系、成长关系和贡献关系变成可追踪数据。',
        child: Column(children: <Widget>[
          DropdownButtonFormField<String>(
            value: _relationType,
            decoration: const InputDecoration(labelText: '关系类型', border: OutlineInputBorder()),
            items: const <String>['安全关系', '亲密关系', '冲突关系', '责任关系', '成长关系', '贡献关系']
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _relationType = v ?? _relationType),
          ),
          const SizedBox(height: 10),
          TextField(controller: _relationNameCtrl, decoration: const InputDecoration(labelText: '关系对象名称或代称', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          _scoreSlider('信任', _relationTrust, (v) => setState(() => _relationTrust = v.round())),
          _scoreSlider('亲密', _relationIntimacy, (v) => setState(() => _relationIntimacy = v.round())),
          _scoreSlider('冲突', _relationConflict, (v) => setState(() => _relationConflict = v.round())),
          _scoreSlider('支持', _relationSupport, (v) => setState(() => _relationSupport = v.round())),
          _scoreSlider('边界清晰', _relationBoundary, (v) => setState(() => _relationBoundary = v.round())),
          TextField(controller: _relationNoteCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '关系备注：防御、触发、修复可能', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: <Widget>[Expanded(child: FilledButton.icon(onPressed: _saveRelationship, icon: const Icon(Icons.people_alt_outlined), label: const Text('保存关系地图记录')))]),
        ]),
      );

  Widget _timelineCard() => _sectionCard(
        title: '生命时间线记录器',
        subtitle: '不以单点判断人生：记录一个生命章节如何形成旧防御，以及现在如何发展更成熟适应。',
        child: Column(children: <Widget>[
          DropdownButtonFormField<String>(
            value: _timelineChapter,
            decoration: const InputDecoration(labelText: '生命章节', border: OutlineInputBorder()),
            items: const <String>['童年', '青春期', '亲密关系', '职业形成', '重大失败', '疾病/丧失', '中年转型', '当前阶段', '贡献/传承']
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _timelineChapter = v ?? _timelineChapter),
          ),
          const SizedBox(height: 10),
          TextField(controller: _timelineEventCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '事件 / 章节', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _timelineOldCtrl, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: '当时形成或使用的旧适应方式', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _timelineMatureCtrl, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: '现在想发展的成熟转化', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _timelineEvidenceCtrl, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: '人生证据：我活下来/修复/创造/贡献过什么', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: <Widget>[Expanded(child: FilledButton.icon(onPressed: _saveTimeline, icon: const Icon(Icons.route_outlined), label: const Text('保存生命时间线')))]),
        ]),
      );

  Widget _contributionCard() => _sectionCard(
        title: '生成性贡献记录器',
        subtitle: '把“我如何活下来”推进到“我如何帮助别人活得更好”，同时防止讨好、控制和过度牺牲。',
        child: Column(children: <Widget>[
          DropdownButtonFormField<String>(
            value: _contributionForm,
            decoration: const InputDecoration(labelText: '贡献形式', border: OutlineInputBorder()),
            items: const <String>['经验分享', '指导后辈', '照顾家人', '支持朋友', '志愿服务', '知识/作品创造', '组织改善', '公共表达']
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _contributionForm = v ?? _contributionForm),
          ),
          const SizedBox(height: 10),
          TextField(controller: _contributionTargetCtrl, decoration: const InputDecoration(labelText: '我想帮助的人/群体/对象', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _contributionMotivationCtrl, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: '这段经验让我理解了什么', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _contributionBoundaryCtrl, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: '边界：如何避免讨好、控制或过度牺牲', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _contributionResultCtrl, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: '实际行动 / 结果 / 复盘', border: OutlineInputBorder())),
          _scoreSlider('意义感', _contributionMeaning, (v) => setState(() => _contributionMeaning = v.round())),
          Row(children: <Widget>[Expanded(child: FilledButton.icon(onPressed: _saveContribution, icon: const Icon(Icons.volunteer_activism_outlined), label: const Text('保存生成性贡献')))]),
        ]),
      );


  Widget _healthLogCard() => _sectionCard(
        title: '身体健康与压力日志',
        subtitle: '落实原书对身体健康、酒精、睡眠和压力适应的重视：不把身体问题简单心理化，也不忽视压力信号。',
        child: Column(children: <Widget>[
          _scoreSlider('睡眠质量', _sleepQuality, (v) => setState(() => _sleepQuality = v.round())),
          _scoreSlider('饮酒/成瘾风险', _alcoholRisk, (v) => setState(() => _alcoholRisk = v.round())),
          _scoreSlider('身体压力强度', _stressBody, (v) => setState(() => _stressBody = v.round())),
          Row(children: <Widget>[
            const Text('运动分钟：', style: TextStyle(fontWeight: FontWeight.w700)),
            Expanded(child: Slider(value: _exerciseMinutes.toDouble(), min: 0, max: 120, divisions: 12, label: _exerciseMinutes.toString(), onChanged: (v) => setState(() => _exerciseMinutes = v.round()))),
            Text('$_exerciseMinutes 分钟'),
          ]),
          TextField(controller: _healthSymptomsCtrl, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: '身体症状 / 睡眠 / 酒精 / 疲劳', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _healthNoteCtrl, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: '备注：最近压力、是否医学评估、身体照顾动作', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: <Widget>[Expanded(child: FilledButton.icon(onPressed: _saveHealth, icon: const Icon(Icons.monitor_heart_outlined), label: const Text('保存身体健康日志')))]),
        ]),
      );

  Widget _heroCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(colors: <Color>[Color(0xFF2F251C), Color(0xFF8B6B45)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const <Widget>[
          Text('Adaptation Compass', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
          SizedBox(height: 8),
          Text('基于 George E. Vaillant《Adaptation to Life》：看见自己如何防御，理解防御如何保护，再把痛苦转化为现实、关系、创造、游戏、责任和生成性行动。', style: TextStyle(color: Colors.white, height: 1.45)),
          SizedBox(height: 12),
          Text('今日问题：我最需要成熟回应的现实是什么？', style: TextStyle(color: Color(0xFFFFE2B8), fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _statsGrid() => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: MediaQuery.of(context).size.width > 720 ? 4 : 2,
        childAspectRatio: 1.7,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: <Widget>[
          _statCard('分析记录', _stats.sessionCount.toString(), Icons.timeline_outlined),
          _statCard('开放行动', _stats.openActions.toString(), Icons.flag_outlined),
          _statCard('已完成行动', _stats.doneActions.toString(), Icons.check_circle_outline),
          _statCard('成熟防御命中', _stats.matureDefenseHits.toString(), Icons.local_florist_outlined),
          _statCard('工作均分', _stats.avgWork.toStringAsFixed(1), Icons.work_outline),
          _statCard('爱均分', _stats.avgLove.toStringAsFixed(1), Icons.favorite_border),
          _statCard('游戏均分', _stats.avgPlay.toStringAsFixed(1), Icons.sports_esports_outlined),
          _statCard('身体均分', _stats.avgBody.toStringAsFixed(1), Icons.monitor_heart_outlined),
        ],
      );

  Widget _statCard(String label, String value, IconData icon) => _surface(
        child: Row(children: <Widget>[
          Icon(icon, color: const Color(0xFF6B4E2E)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: Colors.black54)),
          ])),
        ]),
      );

  Widget _sessionCard(AdaptationCompassSession s, {bool expanded = false}) {
    final date = DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(s.createdAtMs));
    return _surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Expanded(child: Text('${AdaptationCompassPromptConfig.sceneLabel(s.scene)} · $date', style: const TextStyle(fontWeight: FontWeight.w800))),
          _riskPill(s.riskLevel),
        ]),
        const SizedBox(height: 8),
        Text(s.eventSummary.isEmpty ? s.userInput : s.eventSummary, style: const TextStyle(fontSize: 15, height: 1.4)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
          _tag(s.defenseLayer),
          ...s.defenseMechanisms.take(3).map(_tag),
          ...s.matureAlternatives.take(3).map(_tag),
        ]),
        if (expanded || s.aiResponse.length < 1200) ...<Widget>[
          const SizedBox(height: 12),
          SelectableText(s.aiResponse, style: const TextStyle(height: 1.45)),
        ] else ...<Widget>[
          const SizedBox(height: 8),
          Text(s.aiResponse, maxLines: 8, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.45)),
        ],
      ]),
    );
  }

  Widget _actionTile(AdaptationCompassAction a) => _surface(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Checkbox(value: a.status == 'done', onChanged: (_) => _toggleAction(a)),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(a.title, style: TextStyle(fontWeight: FontWeight.w700, decoration: a.status == 'done' ? TextDecoration.lineThrough : null)),
            const SizedBox(height: 4),
            Text('${a.domain} · ${a.horizon}', style: const TextStyle(color: Colors.black54)),
          ])),
        ]),
      );


  Widget _relationshipTile(AdaptationCompassRelationshipEntry r) => _surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[Expanded(child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800))), _tag(r.type)]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            _tag('信任 ${r.trust}'), _tag('亲密 ${r.intimacy}'), _tag('冲突 ${r.conflict}'), _tag('支持 ${r.support}'), _tag('边界 ${r.boundary}'),
          ]),
          if (r.note.trim().isNotEmpty) ...<Widget>[const SizedBox(height: 8), Text(r.note, style: const TextStyle(height: 1.35))],
        ]),
      );

  Widget _timelineTile(AdaptationCompassTimelineEntry t) => _surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[Expanded(child: Text(t.chapter, style: const TextStyle(fontWeight: FontWeight.w800))), Text(DateFormat('MM-dd').format(DateTime.fromMillisecondsSinceEpoch(t.createdAtMs)), style: const TextStyle(color: Colors.black54))]),
          if (t.event.trim().isNotEmpty) _kvLine('事件', t.event),
          if (t.oldAdaptation.trim().isNotEmpty) _kvLine('旧适应', t.oldAdaptation),
          if (t.matureShift.trim().isNotEmpty) _kvLine('成熟转化', t.matureShift),
          if (t.evidence.trim().isNotEmpty) _kvLine('人生证据', t.evidence),
        ]),
      );

  Widget _contributionTile(AdaptationCompassContributionEntry c) => _surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[Expanded(child: Text(c.target, style: const TextStyle(fontWeight: FontWeight.w800))), _tag(c.form)]),
          if (c.motivation.trim().isNotEmpty) _kvLine('理解', c.motivation),
          if (c.boundary.trim().isNotEmpty) _kvLine('边界', c.boundary),
          if (c.result.trim().isNotEmpty) _kvLine('结果', c.result),
          const SizedBox(height: 8),
          _tag('意义感 ${c.meaning}/10'),
        ]),
      );


  Widget _healthTile(AdaptationCompassHealthEntry h) => _surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(h.createdAtMs)), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            _tag('睡眠 ${h.sleepQuality}'), _tag('饮酒/成瘾风险 ${h.alcoholRisk}'), _tag('运动 ${h.exerciseMinutes} 分钟'), _tag('身体压力 ${h.stressBody}'),
          ]),
          if (h.symptoms.trim().isNotEmpty) _kvLine('症状', h.symptoms),
          if (h.note.trim().isNotEmpty) _kvLine('备注', h.note),
        ]),
      );

  Widget _courseProgressTile(AdaptationCompassCourseProgress c) => _surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Text('第 ${c.week} 周 · ${c.title}', style: const TextStyle(fontWeight: FontWeight.w800))),
            _tag(c.status),
          ]),
          if (c.reflection.trim().isNotEmpty) _kvLine('复盘', c.reflection),
          Text(DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(c.createdAtMs)), style: const TextStyle(color: Colors.black54)),
        ]),
      );

  Widget _balanceTile(AdaptationCompassBalanceEntry b) => _surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(b.createdAtMs)), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            _tag('工作 ${b.work}'), _tag('爱 ${b.love}'), _tag('游戏 ${b.play}'), _tag('身体 ${b.body}'),
          ]),
          if (b.note.trim().isNotEmpty) ...<Widget>[const SizedBox(height: 8), Text(b.note)],
        ]),
      );

  Widget _defenseCard(AdaptationDefenseCard d) => _surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[Expanded(child: Text(d.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))), _tag(d.layer)]),
          const SizedBox(height: 8),
          Text(d.description),
          const SizedBox(height: 8),
          _kvLine('保护', d.protects),
          _kvLine('代价', d.cost),
          _kvLine('升级', d.upgrade),
        ]),
      );

  Widget _layerCard(String title, String text, IconData icon) => _surface(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Icon(icon, color: const Color(0xFF6B4E2E)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(height: 1.4)),
          ])),
        ]),
      );

  Widget _moduleCard(AdaptationModuleSpec m) => _surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(m.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(m.subtitle, style: const TextStyle(color: Colors.black87, height: 1.35)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: m.functions.map(_tag).toList()),
        ]),
      );

  Widget _courseTile(AdaptationCourseWeek w) => _surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text('第 ${w.week} 周 · ${w.title}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          _kvLine('学习', w.focus),
          _kvLine('练习', w.practice),
        ]),
      );

  Widget _stageTile(AdaptationStageSpec s) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _surface(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(s.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            _kvLine('核心问题', s.question),
            _kvLine('常见防御', s.defenses),
            _kvLine('成熟行动', s.action),
          ]),
        ),
      );

  Widget _flowCard() => _surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const <Widget>[
          Text('生活事件 → 情绪与身体 → 适应方式识别 → 保护功能理解 → 长期代价看见 → 成熟替代选择 → 现实行动 → 复盘数据 → 长期生命轨迹', style: TextStyle(height: 1.5, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _sectionCard({required String title, required String subtitle, required Widget child}) => _surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.black54, height: 1.4)),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _surface({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7DCCC)),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: child,
      );

  Widget _emptyCard(String title, String subtitle) => _surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(subtitle, style: const TextStyle(color: Colors.black54))]));

  Widget _simpleCard(String text) => _surface(child: Text(text, style: const TextStyle(height: 1.4)));

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF2C241C))),
      );

  Widget _page({required List<Widget> children}) => ListView(padding: const EdgeInsets.all(16), children: children);

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xFFF3E8D8), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF6B4E2E), fontWeight: FontWeight.w600)),
      );

  Widget _riskPill(String risk) {
    final Color color = risk == 'crisis' || risk == 'high' ? Colors.red : risk == 'medium' ? Colors.orange : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(risk, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('•  '),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ]),
      );

  Widget _kvLine(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, height: 1.35), children: <TextSpan>[TextSpan(text: '$k：', style: const TextStyle(fontWeight: FontWeight.w800)), TextSpan(text: v)])),
      );

  Widget _transformRow(String emotion, String action) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          SizedBox(width: 62, child: Text(emotion, style: const TextStyle(fontWeight: FontWeight.w800))),
          Expanded(child: Text(action)),
        ]),
      );

  Widget _scoreSlider(String label, int value, ValueChanged<double> onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[Expanded(child: Text('$label：$value/10', style: const TextStyle(fontWeight: FontWeight.w700)))]),
        Slider(value: value.toDouble(), min: 0, max: 10, divisions: 10, label: value.toString(), onChanged: onChanged),
      ]);

  Widget _profileField(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: c, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
      );

  Widget _sceneButtons(List<String> ids) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ids.map((id) => OutlinedButton(onPressed: () => _jumpScene(id), child: Text(_sceneSpec(id).title))).toList(),
      );

  void _jumpScene(String id) {
    final spec = _sceneSpec(id);
    setState(() {
      _scene = id;
      _inputCtrl.text = spec.template;
    });
    _tabs.animateTo(1);
  }

  AdaptationSceneSpec _sceneSpec(String id) {
    for (final spec in AdaptationCompassContent.scenes) {
      if (spec.id == id) return spec;
    }
    return AdaptationCompassContent.scenes.first;
  }
}

class _MiniChip extends StatelessWidget {
  final String text;
  const _MiniChip(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFF3E8D8), borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(color: Color(0xFF6B4E2E), fontWeight: FontWeight.w700)),
      );
}
