import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'mi_growth_ai_service.dart';
import 'mi_growth_dao.dart';
import 'mi_growth_models.dart';
import '../pages/ai_prompt_settings_page.dart';
import 'mi_growth_prompt_config.dart';

class MiGrowthHomePage extends StatefulWidget {
  final String initialInput;
  final String initialScene;
  const MiGrowthHomePage({super.key, this.initialInput = '', this.initialScene = 'daily_growth'});

  @override
  State<MiGrowthHomePage> createState() => _MiGrowthHomePageState();
}

class _MiGrowthHomePageState extends State<MiGrowthHomePage> {
  final MiGrowthDao _dao = MiGrowthDao();
  final MiGrowthAiService _ai = MiGrowthAiService();
  final TextEditingController _inputCtrl = TextEditingController();
  final TextEditingController _identityCtrl = TextEditingController();
  final TextEditingController _relationsCtrl = TextEditingController();
  final TextEditingController _directionCtrl = TextEditingController();
  final TextEditingController _reasonsCtrl = TextEditingController();
  final TextEditingController _helperCtrl = TextEditingController(text: '你再这样拖延下去肯定完蛋。');
  String _scene = 'daily_growth';
  bool _loading = true;
  bool _generating = false;
  MiGrowthValueProfile _profile = const MiGrowthValueProfile();
  MiGrowthSessionRecord? _latest;
  List<MiGrowthSessionRecord> _sessions = <MiGrowthSessionRecord>[];
  List<MiGrowthActionPlan> _actions = <MiGrowthActionPlan>[];
  List<MiGrowthReviewRecord> _reviews = <MiGrowthReviewRecord>[];
  MiGrowthStats _stats = const MiGrowthStats();
  Set<String> _selectedValues = <String>{};

  static const List<String> _valueOptions = <String>[
    '健康', '家庭', '成长', '自由', '关系', '责任', '尊严', '创造', '安全', '学习', '稳定', '贡献'
  ];

  static const Map<String, String> _sceneLabels = <String, String>{
    'daily_growth': '日常成长向导',
    'habit_change': '习惯改变 / 反复失败',
    'confusion_focus': '混乱聚焦',
    'low_motivation': '暂时没动力',
    'action_failure': '行动失败 / 复发修复',
    'life_transition': '人生转变 / 身份成长',
    'help_others': '帮助别人改变',
    'review': '复盘与维持',
  };

  @override
  void initState() {
    super.initState();
    _scene = widget.initialScene;
    _inputCtrl.text = widget.initialInput.trim().isEmpty ? '我想改变一件事，但也有点累，不知道从哪里开始。' : widget.initialInput.trim();
    _load();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _identityCtrl.dispose();
    _relationsCtrl.dispose();
    _directionCtrl.dispose();
    _reasonsCtrl.dispose();
    _helperCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _dao.ensureTables();
      final profile = await _dao.loadProfile();
      final sessions = await _dao.listSessions(limit: 30);
      final actions = await _dao.listActions(limit: 50);
      final reviews = await _dao.listReviews(limit: 50);
      final stats = await _dao.stats();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _selectedValues = profile.values.toSet();
        _identityCtrl.text = profile.identityDirection;
        _relationsCtrl.text = profile.importantRelationships;
        _directionCtrl.text = profile.longTermDirection;
        _reasonsCtrl.text = profile.changeReasons.join('\n');
        _sessions = sessions;
        _actions = actions;
        _reviews = reviews;
        _stats = stats;
        _latest = sessions.isNotEmpty ? sessions.first : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('加载 MI 成长向导失败：$e');
    }
  }

  Future<void> _saveProfile() async {
    final reasons = _reasonsCtrl.text
        .split(RegExp(r'[\n；;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final profile = MiGrowthValueProfile(
      values: _selectedValues.toList(growable: false),
      identityDirection: _identityCtrl.text.trim(),
      importantRelationships: _relationsCtrl.text.trim(),
      longTermDirection: _directionCtrl.text.trim(),
      changeReasons: reasons,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _dao.saveProfile(profile);
    if (!mounted) return;
    setState(() => _profile = profile);
    _toast('价值罗盘已保存。');
  }

  Future<void> _generate() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) {
      _toast('请先写下你现在想改变、想理清或想复盘的一件事。');
      return;
    }
    setState(() => _generating = true);
    try {
      final context = await _dao.recentContextJson();
      final result = await _ai.generate(scene: _scene, userInput: input, profile: _profile, recentContextJson: context);
      await _dao.insertSession(result);
      await _mergeDetectedValues(result);
      await _load();
      if (!mounted) return;
      _toast(result.nextAction.hasConcreteStep ? '已生成向导回应并保存小步行动。' : '已生成向导回应。');
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _mergeDetectedValues(MiGrowthSessionRecord result) async {
    final detected = result.valuesDetected.where((e) => e.trim().isNotEmpty).toSet();
    final changeReasons = <String>{..._profile.changeReasons, ...result.changeTalk.all.take(3)}.where((e) => e.trim().isNotEmpty).toList(growable: false);
    if (detected.isEmpty && changeReasons.length == _profile.changeReasons.length) return;
    final merged = _profile.copyWith(
      values: <String>{..._profile.values, ...detected}.toList(growable: false),
      changeReasons: changeReasons.take(12).toList(growable: false),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _dao.saveProfile(merged);
  }

  Future<void> _markAction(MiGrowthActionPlan action, String status) async {
    if (action.id == null) return;
    await _dao.updateActionStatus(action.id!, status);
    await _load();
  }

  Future<void> _reviewAction(MiGrowthActionPlan action) async {
    final whatCtrl = TextEditingController();
    final doneCtrl = TextEditingController();
    final stuckCtrl = TextEditingController();
    final adjustCtrl = TextEditingController(text: action.backupPlan);
    String status = 'partial';
    final review = await showDialog<MiGrowthReviewRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('温和复盘：不是失败，是信息'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: '这次行动结果'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'completed', child: Text('完成')),
                    DropdownMenuItem(value: 'partial', child: Text('部分完成')),
                    DropdownMenuItem(value: 'missed', child: Text('没有完成，但获得信息')),
                  ],
                  onChanged: (v) => setLocal(() => status = v ?? 'partial'),
                ),
                const SizedBox(height: 8),
                TextField(controller: whatCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '这次实际发生了什么？')),
                TextField(controller: doneCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '哪怕 1%，哪部分做到了或学到了？')),
                TextField(controller: stuckCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '主要卡在哪里？')),
                TextField(controller: adjustCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '下一次如何调小或调准？')),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(MiGrowthReviewRecord(
                actionId: action.id ?? 0,
                status: status,
                whatHappened: whatCtrl.text.trim(),
                donePart: doneCtrl.text.trim(),
                stuckPart: stuckCtrl.text.trim(),
                nextAdjustment: adjustCtrl.text.trim(),
                valueConnection: action.valueConnection,
              )),
              child: const Text('保存复盘'),
            ),
          ],
        ),
      ),
    );
    whatCtrl.dispose();
    doneCtrl.dispose();
    stuckCtrl.dispose();
    adjustCtrl.dispose();
    if (review == null) return;
    await _dao.insertReview(review);
    await _load();
    _toast('复盘已保存。');
  }

  Future<void> _generateHelperRewrite() async {
    final input = _helperCtrl.text.trim();
    if (input.isEmpty) return;
    setState(() => _generating = true);
    try {
      final result = await _ai.generate(
        scene: 'help_others',
        userInput: '请把下面这句话改写成尊重自主、少说教、多反映、多邀请的 MI 式表达：$input',
        profile: _profile,
        recentContextJson: await _dao.recentContextJson(),
      );
      await _dao.insertSession(result);
      await _load();
      _toast('已生成帮助者训练回应。');
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 8,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('向内生长 · MI 成长向导'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: '向导'),
              Tab(text: '价值罗盘'),
              Tab(text: '焦点地图'),
              Tab(text: '改变语言'),
              Tab(text: '小步行动'),
              Tab(text: '复盘'),
              Tab(text: '成长报告'),
              Tab(text: '训练/安全'),
            ],
          ),
          actions: <Widget>[
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: '刷新'),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: <Widget>[
                  _buildGuideTab(),
                  _buildValueTab(),
                  _buildFocusMapTab(),
                  _buildChangeTalkTab(),
                  _buildActionTab(),
                  _buildReviewTab(),
                  _buildGrowthReportTab(),
                  _buildTrainingSafetyTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildGuideTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _heroCard(),
        const SizedBox(height: 12),
        _statsStrip(),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _sceneLabels.containsKey(_scene) ? _scene : 'daily_growth',
          decoration: const InputDecoration(labelText: '当前场景层 Prompt', border: OutlineInputBorder()),
          items: _sceneLabels.entries.map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value))).toList(growable: false),
          onChanged: (v) => setState(() => _scene = v ?? 'daily_growth'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _inputCtrl,
          minLines: 5,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: '写下你现在想改变、想理清或想复盘的一件事',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _generating ? null : _generate,
          icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
          label: Text(_generating ? 'AI 正在按 MI 四任务生成...' : '生成 MI 向导回应'),
        ),
        const SizedBox(height: 16),
        if (_latest != null) _sessionCard(_latest!, expanded: true),
        const SizedBox(height: 12),
        _promptArchitectureCard(),
        const SizedBox(height: 12),
        ..._sessions.skip(_latest == null ? 0 : 1).take(6).map((s) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _sessionCard(s))),
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: <Color>[Color(0xFFEFF4FF), Color(0xFFF7F1FF)]),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('不是被催促改变，而是在被理解中听见自己的理由', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text('V2 补齐版：价值罗盘、焦点地图、改变语言卡、小步行动、复盘修复、成长报告、帮助者训练、风险边界、AI 忠诚度自检与三层 Prompt。', style: TextStyle(color: Color(0xB3000000), height: 1.45)),
        ],
      ),
    );
  }

  Widget _statsStrip() {
    final items = <_MetricItem>[
      _MetricItem('价值', _stats.valueCount.toString()),
      _MetricItem('改变语言', _stats.changeTalkCount.toString()),
      _MetricItem('行动', _stats.actions.toString()),
      _MetricItem('待复盘', _stats.openActions.toString()),
      _MetricItem('复盘', _stats.reviews.toString()),
    ];
    return Row(
      children: items.map((item) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(children: <Widget>[
              Text(item.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(item.label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
        ),
      )).toList(growable: false),
    );
  }

  Widget _sessionCard(MiGrowthSessionRecord s, {bool expanded = false}) {
    final action = s.nextAction;
    return Card(
      elevation: expanded ? 1 : 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: expanded ? const Color(0xFFCBD5E1) : const Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: <Widget>[
              Icon(_stageIcon(s.stage), size: 20, color: Colors.indigo),
              const SizedBox(width: 8),
              Expanded(child: Text('${_stageLabel(s.stage)} · ${_sceneLabels[s.scene] ?? s.scene}', style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(_fmt(s.createdAtMs), style: const TextStyle(color: Colors.black45, fontSize: 12)),
            ]),
            if (s.focus.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('焦点：${s.focus}', style: const TextStyle(color: Colors.black87))),
            if (s.valuesDetected.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 6, runSpacing: 6, children: s.valuesDetected.map((v) => Chip(label: Text(v), visualDensity: VisualDensity.compact)).toList(growable: false)),
            ),
            const SizedBox(height: 8),
            Text(s.aiResponse, style: const TextStyle(height: 1.48)),
            if (!s.changeTalk.isEmpty) ...<Widget>[
              const SizedBox(height: 10),
              const Text('捕捉到的改变语言', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ...s.changeTalk.all.take(4).map((e) => Text('• $e', style: const TextStyle(color: Colors.black87))),
            ],
            if (action.hasConcreteStep) ...<Widget>[
              const Divider(height: 22),
              _actionMini(action),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionMini(MiGrowthActionPlan action) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(children: const <Widget>[
          Icon(Icons.flag_circle_outlined, color: Colors.green),
          SizedBox(width: 6),
          Text('下一小步', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        if (action.valueConnection.isNotEmpty) Text(action.valueConnection, style: const TextStyle(color: Colors.black87)),
        const SizedBox(height: 6),
        Text('时间：${action.timeText.isEmpty ? '今天或明天一个固定时刻' : action.timeText}'),
        Text('地点：${action.place.isEmpty ? '最容易开始的地方' : action.place}'),
        Text('动作：${action.action}'),
        Text('时长：${action.duration.isEmpty ? '3 分钟' : action.duration}'),
        if (action.backupPlan.isNotEmpty) Text('备用：${action.backupPlan}'),
      ],
    );
  }

  Widget _promptArchitectureCard() {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
      title: const Text('三层 Prompt 架构已接入'),
      subtitle: const Text('全局价值层 + 场景层 + 输出格式层'),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.tune_outlined),
            label: const Text('去设置页统一配置 MI Prompt'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const AiPromptSettingsPage(initialModuleId: 'mi_growth'),
            )),
          ),
        ),
        const SizedBox(height: 8),
        _smallPromptBlock('全局价值层', MiGrowthPromptConfig.globalValuePrompt, maxLines: 8),
        const SizedBox(height: 8),
        _smallPromptBlock('当前场景层', MiGrowthPromptConfig.scenePrompt(_scene), maxLines: 5),
        const SizedBox(height: 8),
        _smallPromptBlock('输出格式层', MiGrowthPromptConfig.outputJsonPrompt, maxLines: 8),
      ],
    );
  }

  Widget _smallPromptBlock(String title, String text, {int maxLines = 6}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(text.trim(), maxLines: maxLines, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xAB000000), height: 1.35)),
      ]),
    );
  }

  Widget _buildFocusMapTab() {
    final candidates = _focusCandidates();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text('焦点地图', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('当问题很多时，先把混乱拆成可选择焦点。AI 不替你决定，而是把方向摆出来，让你选择今天最值得谈的一项。', style: TextStyle(color: Color(0x99000000), height: 1.45)),
        const SizedBox(height: 16),
        _principleCard(
          icon: Icons.map_outlined,
          title: '产品设计对应：聚焦任务',
          body: '这里把“我很乱”转化成 3–6 个焦点候选：健康/睡眠、工作学习、关系沟通、情绪压力、拖延行动、身份成长。点击任一焦点即可回到向导页，让 AI 围绕它继续参与-聚焦-唤起-计划。',
        ),
        const SizedBox(height: 12),
        ...candidates.map((c) => Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Row(children: <Widget>[
                Icon(c.icon, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(child: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                Chip(label: Text(c.sceneLabel), visualDensity: VisualDensity.compact),
              ]),
              const SizedBox(height: 6),
              Text(c.reason, style: const TextStyle(color: Color(0xAB000000), height: 1.4)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => _useFocusCandidate(c),
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('围绕这个焦点继续'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _scene = 'confusion_focus';
                      _inputCtrl.text = '我现在有几个方向都很乱，想先聚焦在：${c.title}。${c.reason}';
                    });
                    DefaultTabController.of(context).animateTo(0);
                  },
                  child: const Text('用聚焦模式'),
                ),
              ]),
            ]),
          ),
        )),
      ],
    );
  }

  Widget _buildChangeTalkTab() {
    final groups = _changeTalkGroups();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text('改变语言卡', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('这里不是 AI 替你找理由，而是保存你自己已经说出口的想要、能力、理由、需要、承诺、准备与已行动。后续行动会优先连接这些语言。', style: TextStyle(color: Color(0x99000000), height: 1.45)),
        const SizedBox(height: 16),
        if (groups.values.every((v) => v.isEmpty)) const _EmptyHint(icon: Icons.chat_bubble_outline, text: '还没有捕捉到改变语言。去“向导”页写下你想改变或想理清的一件事。'),
        ...groups.entries.where((e) => e.value.isNotEmpty).map((entry) => _changeTalkGroupCard(entry.key, entry.value)),
        const SizedBox(height: 12),
        _principleCard(
          icon: Icons.psychology_alt_outlined,
          title: '产品设计对应：语言机制',
          body: 'MI 认为人会被自己说出的话推动。这个页面把对话中的改变语言做成长期资产，避免 App 只停留在一次性聊天。',
        ),
      ],
    );
  }

  Widget _changeTalkGroupCard(String title, List<String> items) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            const Icon(Icons.auto_stories_outlined, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
            Text('${items.length}', style: const TextStyle(color: Colors.black45)),
          ]),
          const SizedBox(height: 8),
          ...items.take(8).map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const Text('• '),
              Expanded(child: Text(item, style: const TextStyle(height: 1.35))),
              TextButton(
                onPressed: () => _addReason(item),
                child: const Text('加入罗盘'),
              ),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _buildGrowthReportTab() {
    final fidelity = _averageFidelityScore();
    final topValues = _topValues();
    final open = _actions.where((a) => a.status == 'open').length;
    final completed = _actions.where((a) => a.status == 'completed').length;
    final reviewed = _reviews.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text('成长报告', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('报告不是排名和施压，而是把价值、改变语言、行动、复盘和 AI 忠诚度放在同一张地图上。', style: TextStyle(color: Color(0x99000000), height: 1.45)),
        const SizedBox(height: 16),
        Row(children: <Widget>[
          Expanded(child: _metricCard('MI 忠诚度', '$fidelity', '基于最近回应的自检分')),
          Expanded(child: _metricCard('待行动', '$open', '可复盘的小步')),
        ]),
        Row(children: <Widget>[
          Expanded(child: _metricCard('已完成', '$completed', '不追求连续打卡')),
          Expanded(child: _metricCard('复盘', '$reviewed', '失败也算信息')),
        ]),
        const SizedBox(height: 12),
        _principleCard(
          icon: Icons.verified_outlined,
          title: 'AI 忠诚度自检',
          body: '当前分数根据最近回应是否先反映、是否尊重自主、是否捕捉改变语言、是否生成小步行动、是否识别风险/关系失调来估算。后续可扩展为完整 MITI 式编码仪表盘。',
        ),
        const SizedBox(height: 12),
        _reportSection('本阶段最常出现的价值', topValues.isEmpty ? <String>['还没有足够数据。先保存价值罗盘或进行一次向导对话。'] : topValues),
        _reportSection('你已经说出的改变理由', _profile.changeReasons.isEmpty ? <String>['还没有保存的改变理由。'] : _profile.changeReasons.take(8).toList(growable: false)),
        _reportSection('最近阻碍模式', _reviews.where((r) => r.stuckPart.isNotEmpty).map((r) => r.stuckPart).take(6).toList(growable: false)),
        _reportSection('下一步建议', <String>[
          open > 0 ? '先不要新增大目标，选择一个待行动做温和复盘。' : '从一个 3 分钟小步开始，生成一个可复盘行动。',
          _profile.values.isEmpty ? '先补齐价值罗盘，让行动连接到你真正重视的东西。' : '继续把行动连接到价值：${_profile.values.take(3).join('、')}。',
          fidelity < 75 ? '最近回应的 MI 忠诚度偏低，建议到设置页检查 Prompt 是否被改得过于命令式。' : '当前 AI 回应整体保持了 MI 的自主、反映和小步原则。',
        ]),
      ],
    );
  }

  Widget _metricCard(String label, String value, String hint) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(hint, style: const TextStyle(fontSize: 12, color: Color(0x99000000))),
        ]),
      ),
    );
  }

  Widget _reportSection(String title, List<String> items) {
    final visible = items.where((e) => e.trim().isNotEmpty).toList(growable: false);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (visible.isEmpty) const Text('暂无足够数据。', style: TextStyle(color: Color(0x99000000))),
          ...visible.take(8).map((e) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $e'))),
        ]),
      ),
    );
  }

  Widget _principleCard({required IconData icon, required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Icon(icon, color: Colors.indigo),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: Color(0xAB000000), height: 1.4)),
        ])),
      ]),
    );
  }

  Widget _buildValueTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text('价值罗盘', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('先看见用户真正重视什么，再把行动连接到价值。这里保存的内容会进入 AI 的全局上下文。', style: TextStyle(color: Color(0x99000000), height: 1.45)),
        const SizedBox(height: 16),
        const Text('核心价值', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _valueOptions.map((v) => FilterChip(
            label: Text(v),
            selected: _selectedValues.contains(v),
            onSelected: (selected) => setState(() {
              if (selected) {
                _selectedValues.add(v);
              } else {
                _selectedValues.remove(v);
              }
            }),
          )).toList(growable: false),
        ),
        const SizedBox(height: 16),
        TextField(controller: _identityCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '我正在练习成为怎样的人？', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _relationsCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '哪些人、关系或责任对我重要？', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _directionCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '一年后的我会感谢现在的我守住了什么？', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _reasonsCtrl, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: '我已经说出的改变理由（每行一个）', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _saveProfile, icon: const Icon(Icons.save_outlined), label: const Text('保存价值罗盘')),
      ],
    );
  }

  Widget _buildActionTab() {
    final open = _actions.where((a) => a.status == 'open').toList(growable: false);
    final done = _actions.where((a) => a.status != 'open').toList(growable: false);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text('小步行动', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('行动不是证明自律，而是把价值转化为今天可接触的一小步。低于 7 分信心时，应继续缩小。', style: TextStyle(color: Color(0x99000000), height: 1.45)),
        const SizedBox(height: 16),
        if (open.isEmpty) const _EmptyHint(icon: Icons.flag_outlined, text: '还没有待执行的小步行动。先在“向导”页生成一次 MI 回应。'),
        ...open.map((a) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _actionCard(a, active: true))),
        if (done.isNotEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('已复盘 / 已完成', style: TextStyle(fontWeight: FontWeight.w800))),
        ...done.take(12).map((a) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _actionCard(a, active: false))),
      ],
    );
  }

  Widget _actionCard(MiGrowthActionPlan a, {required bool active}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Text(a.title.isEmpty ? '小步实验' : a.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            Chip(label: Text(_actionStatusLabel(a.status)), visualDensity: VisualDensity.compact),
          ]),
          if (a.focus.isNotEmpty) Text('焦点：${a.focus}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          _actionMini(a),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            if (active) FilledButton.tonal(onPressed: () => _reviewAction(a), child: const Text('复盘这一步')),
            if (active) TextButton(onPressed: () => _markAction(a, 'completed'), child: const Text('标记完成')),
            if (active) TextButton(onPressed: () => _markAction(a, 'paused'), child: const Text('暂缓')),
          ]),
        ]),
      ),
    );
  }

  Widget _buildReviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text('复盘与维持改变', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('完成、部分完成、未完成都进入学习。这里记录阻碍模式、有效因素、下一次更小行动。', style: TextStyle(color: Color(0x99000000), height: 1.45)),
        const SizedBox(height: 16),
        if (_reviews.isEmpty) const _EmptyHint(icon: Icons.rate_review_outlined, text: '还没有复盘。去“小步行动”页选择一个行动进行温和复盘。'),
        ..._reviews.map((r) => Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Row(children: <Widget>[
                Icon(r.status == 'completed' ? Icons.check_circle_outline : Icons.info_outline, color: r.status == 'completed' ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(_reviewStatusLabel(r.status), style: const TextStyle(fontWeight: FontWeight.w800))),
                Text(_fmt(r.createdAtMs), style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ]),
              if (r.whatHappened.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('发生了什么：${r.whatHappened}')),
              if (r.donePart.isNotEmpty) Text('做到/学到：${r.donePart}'),
              if (r.stuckPart.isNotEmpty) Text('卡点：${r.stuckPart}'),
              if (r.nextAdjustment.isNotEmpty) Text('下次调整：${r.nextAdjustment}'),
              if (r.valueConnection.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.valueConnection, style: const TextStyle(color: Colors.black54))),
            ]),
          ),
        )),
      ],
    );
  }

  Widget _buildTrainingSafetyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text('帮助者训练与安全边界', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('用于父母、伴侣、老师、管理者、教练等场景。目标不是操控别人，而是减少修理反射，练习开放式问题、反映、肯定和邀请。', style: TextStyle(color: Color(0x99000000), height: 1.45)),
        const SizedBox(height: 16),
        TextField(controller: _helperCtrl, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: '写下一句原本想说的话', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _generating ? null : _generateHelperRewrite, icon: const Icon(Icons.record_voice_over_outlined), label: const Text('改写成 MI 式表达')),
        const SizedBox(height: 16),
        const Text('练习方向', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const _TrainingTip(text: '把“你必须改”改成“你怎么看这件事对你的影响？”'),
        const _TrainingTip(text: '把“你就是不自律”改成“你一方面想做好，另一方面很难开始。”'),
        const _TrainingTip(text: '把“我告诉你怎么做”改成“我可以提供几个选项，你想听吗？”'),
        const SizedBox(height: 16),
        _principleCard(
          icon: Icons.health_and_safety_outlined,
          title: '风险与危机边界',
          body: '出现自伤、自杀、他伤、虐待、严重戒断、急性医疗风险时，AI 必须停止普通成长对话，优先提示联系当地紧急服务、专业人员或可信赖的人。',
        ),
        const SizedBox(height: 12),
        _principleCard(
          icon: Icons.no_accounts_outlined,
          title: '反操控伦理',
          body: '本模块不帮助父母、伴侣、老板或机构控制他人；只帮助用户把命令、批评和说教改写成尊重自主的对话邀请。',
        ),
        const SizedBox(height: 12),
        ..._sessions.where((s) => s.scene == 'help_others').take(5).map((s) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _sessionCard(s))),
      ],
    );
  }

  void _useFocusCandidate(_FocusCandidate c) {
    setState(() {
      _scene = c.scene;
      _inputCtrl.text = '我想先聚焦在：${c.title}。${c.reason}\n\n请先理解我的处境，再帮我澄清为什么这件事重要，以及今天可以迈出的一个很小的行动。';
    });
    DefaultTabController.of(context).animateTo(0);
  }

  Future<void> _addReason(String reason) async {
    final text = reason.trim();
    if (text.isEmpty) return;
    final reasons = <String>{..._profile.changeReasons, text}.toList(growable: false);
    final updated = _profile.copyWith(changeReasons: reasons.take(20).toList(growable: false), updatedAtMs: DateTime.now().millisecondsSinceEpoch);
    await _dao.saveProfile(updated);
    await _load();
    _toast('已加入价值罗盘的改变理由。');
  }

  List<_FocusCandidate> _focusCandidates() {
    final raw = <String>[_inputCtrl.text, ..._sessions.take(6).map((s) => '${s.userInput} ${s.focus}')].join('\n');
    final lower = raw.toLowerCase();
    final candidates = <_FocusCandidate>[];
    void add(String title, String reason, String scene, IconData icon) {
      if (candidates.any((c) => c.title == title)) return;
      candidates.add(_FocusCandidate(title: title, reason: reason, scene: scene, icon: icon, sceneLabel: _sceneLabels[scene] ?? scene));
    }
    if (RegExp('睡|累|身体|健康|运动|饮食|烟|酒|体力|病').hasMatch(lower)) add('健康与身体恢复', '你的表达里出现了身体、精力或健康相关线索。', 'habit_change', Icons.monitor_heart_outlined);
    if (RegExp('拖延|工作|学习|文档|任务|效率|项目|考试|计划').hasMatch(lower)) add('拖延、工作或学习启动', '这里可能不是缺自律，而是需要把开始动作缩小。', 'habit_change', Icons.task_alt_outlined);
    if (RegExp('家人|孩子|父母|伴侣|朋友|关系|沟通|对方').hasMatch(lower)) add('关系与沟通', '这里涉及重要关系，适合先表达关心，再邀请对话。', 'help_others', Icons.favorite_border);
    if (RegExp('焦虑|压力|乱|烦|崩|害怕|内疚|羞耻|失败').hasMatch(lower)) add('情绪压力与自我评价', '你可能需要先被理解，而不是立刻被推进方案。', 'confusion_focus', Icons.self_improvement_outlined);
    if (RegExp('换|毕业|失业|分手|退休|搬家|人生|未来|方向|身份').hasMatch(lower)) add('人生转变与身份成长', '这更像是价值和身份问题，不能只压缩成效率目标。', 'life_transition', Icons.explore_outlined);
    if (candidates.isEmpty) {
      add('先理清现在最重要的一件事', '目前信息还不够集中，可以先用聚焦模式把混乱拆开。', 'confusion_focus', Icons.center_focus_strong_outlined);
      add('寻找自己的改变理由', '先不急着行动，看看这件事为什么对你重要。', 'daily_growth', Icons.forum_outlined);
      add('设计一个 3 分钟小步', '当你已经有一点方向时，可以把它变成今天可接触的一小步。', 'habit_change', Icons.flag_outlined);
    }
    while (candidates.length < 4) {
      add('价值连接', '把行动连接到你真正重视的人、关系、健康、成长或自由。', 'daily_growth', Icons.emoji_objects_outlined);
      add('复盘与调小', '如果之前没有完成，不评判，先找阻碍并把下一步缩小。', 'action_failure', Icons.loop_outlined);
    }
    return candidates.take(6).toList(growable: false);
  }

  Map<String, List<String>> _changeTalkGroups() {
    final result = <String, List<String>>{
      '想要 Desire': <String>[],
      '能够 Ability': <String>[],
      '理由 Reasons': <String>[..._profile.changeReasons],
      '需要 Need': <String>[],
      '承诺/准备/已行动 CATs': <String>[],
    };
    for (final s in _sessions) {
      result['想要 Desire']!.addAll(s.changeTalk.desire);
      result['能够 Ability']!.addAll(s.changeTalk.ability);
      result['理由 Reasons']!.addAll(s.changeTalk.reasons);
      result['需要 Need']!.addAll(s.changeTalk.need);
      result['承诺/准备/已行动 CATs']!.addAll(<String>[...s.changeTalk.commitment, ...s.changeTalk.activation, ...s.changeTalk.takingSteps]);
    }
    for (final key in result.keys) {
      result[key] = <String>{...result[key]!.where((e) => e.trim().isNotEmpty)}.toList(growable: false);
    }
    return result;
  }

  List<String> _topValues() {
    final counts = <String, int>{};
    for (final v in _profile.values) {
      counts[v] = (counts[v] ?? 0) + 3;
    }
    for (final s in _sessions) {
      for (final v in s.valuesDetected) {
        counts[v] = (counts[v] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(8).map((e) => '${e.key}：出现 ${e.value} 次').toList(growable: false);
  }

  int _averageFidelityScore() {
    final recent = _sessions.take(10).toList(growable: false);
    if (recent.isEmpty) return 0;
    final sum = recent.fold<int>(0, (acc, s) => acc + _fidelityScore(s));
    return (sum / recent.length).round();
  }

  int _fidelityScore(MiGrowthSessionRecord s) {
    var score = 45;
    if (s.aiResponse.contains('听起来') || s.aiResponse.contains('我听到') || s.strategy.contains('reflection')) score += 12;
    if (s.aiResponse.contains('选择权') || s.aiResponse.contains('可以调整') || s.aiResponse.contains('你可以')) score += 10;
    if (!s.changeTalk.isEmpty || s.aiResponse.contains('改变理由')) score += 12;
    if (s.nextAction.hasConcreteStep && s.stage == 'planning') score += 10;
    if (s.discordSignals.isNotEmpty && s.stage == 'repairing_discord') score += 8;
    if ((s.riskLevel == 'high' || s.riskLevel == 'crisis') && s.stage == 'safety') score += 12;
    if (s.aiResponse.contains('必须') || s.aiResponse.contains('你应该') || s.aiResponse.contains('照做')) score -= 18;
    return score.clamp(0, 100).toInt();
  }

  IconData _stageIcon(String stage) {
    switch (stage) {
      case 'focusing': return Icons.center_focus_strong_outlined;
      case 'evoking': return Icons.forum_outlined;
      case 'planning': return Icons.flag_outlined;
      case 'maintaining': return Icons.loop_outlined;
      case 'repairing_discord': return Icons.handshake_outlined;
      case 'safety': return Icons.health_and_safety_outlined;
      default: return Icons.favorite_border;
    }
  }

  String _stageLabel(String stage) {
    switch (stage) {
      case 'focusing': return '聚焦';
      case 'evoking': return '唤起';
      case 'planning': return '计划';
      case 'maintaining': return '维持';
      case 'repairing_discord': return '关系修复';
      case 'safety': return '安全边界';
      default: return '参与';
    }
  }

  String _actionStatusLabel(String status) {
    switch (status) {
      case 'completed': return '已完成';
      case 'reviewed': return '已复盘';
      case 'paused': return '暂缓';
      default: return '待行动';
    }
  }

  String _reviewStatusLabel(String status) {
    switch (status) {
      case 'completed': return '完成：提取有效因素';
      case 'missed': return '未完成：这是一条信息';
      default: return '部分完成：继续调小';
    }
  }

  String _fmt(int ms) {
    if (ms <= 0) return '';
    return DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ms));
  }
}

class _FocusCandidate {
  final String title;
  final String reason;
  final String scene;
  final String sceneLabel;
  final IconData icon;
  const _FocusCandidate({required this.title, required this.reason, required this.scene, required this.sceneLabel, required this.icon});
}

class _MetricItem {
  final String label;
  final String value;
  const _MetricItem(this.label, this.value);
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(18)),
      child: Row(children: <Widget>[
        Icon(icon, color: Colors.black45),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(color: Color(0x99000000)))),
      ]),
    );
  }
}

class _TrainingTip extends StatelessWidget {
  final String text;
  const _TrainingTip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ]),
    );
  }
}
