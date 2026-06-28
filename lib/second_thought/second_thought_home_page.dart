import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../pages/ai_prompt_settings_page.dart';
import 'second_thought_ai_service.dart';
import 'second_thought_dao.dart';
import 'second_thought_models.dart';
import 'second_thought_prompt_config.dart';

class SecondThoughtHomePage extends StatefulWidget {
  final String initialInput;
  final String initialScene;

  const SecondThoughtHomePage({
    super.key,
    this.initialInput = '',
    this.initialScene = 'capture',
  });

  @override
  State<SecondThoughtHomePage> createState() => _SecondThoughtHomePageState();
}

class _SecondThoughtHomePageState extends State<SecondThoughtHomePage> {
  final SecondThoughtDao _dao = SecondThoughtDao();
  final SecondThoughtAiService _ai = SecondThoughtAiService();
  final TextEditingController _inputCtrl = TextEditingController();
  final TextEditingController _identityCtrl = TextEditingController();
  final TextEditingController _relationsCtrl = TextEditingController();
  final TextEditingController _directionCtrl = TextEditingController();
  final TextEditingController _languageBankCtrl = TextEditingController();
  final TextEditingController _customValueCtrl = TextEditingController();

  bool _loading = true;
  bool _generating = false;
  String _scene = 'capture';
  SecondThoughtProfile _profile = const SecondThoughtProfile();
  SecondThoughtCaseRecord? _latest;
  List<SecondThoughtCaseRecord> _cases = <SecondThoughtCaseRecord>[];
  List<SecondThoughtReviewRecord> _reviews = <SecondThoughtReviewRecord>[];
  SecondThoughtStats _stats = const SecondThoughtStats();
  Set<String> _selectedValues = <String>{};

  static const Map<String, String> _sceneLabels = <String, String>{
    'capture': '矛盾捕捉',
    'type_diagnosis': '四型矛盾诊断',
    'inner_committee': '内在委员会',
    'values': '价值澄清',
    'big_picture': '全局图景',
    'change_talk': '改变语言',
    'action_experiment': '行动实验',
    'review': '复盘与整合',
    'integration': '与矛盾共处',
    'social_influence': '社会影响分析',
  };

  static const List<String> _valueOptions = <String>[
    '自由', '成长', '健康', '自尊', '真实', '责任', '安全', '亲密', '稳定', '勇气', '创造', '贡献', '学习', '家庭', '乐趣', '平静',
    '诚实', '边界', '独立', '意义', '智慧', '慈悲', '秩序', '探索', '尊严', '长期自由', '身体照顾', '关系修复',
  ];

  @override
  void initState() {
    super.initState();
    _scene = _sceneLabels.containsKey(widget.initialScene) ? widget.initialScene : 'capture';
    _inputCtrl.text = widget.initialInput.trim().isEmpty ? '我现在有一件事既想做又抗拒，不知道该怎么决定。' : widget.initialInput.trim();
    _load();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _identityCtrl.dispose();
    _relationsCtrl.dispose();
    _directionCtrl.dispose();
    _languageBankCtrl.dispose();
    _customValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _dao.ensureTables();
      final profile = await _dao.loadProfile();
      final cases = await _dao.listCases(limit: 120);
      final reviews = await _dao.listReviews(limit: 120);
      final stats = await _dao.stats();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _selectedValues = profile.coreValues.toSet();
        _identityCtrl.text = profile.identityVision;
        _relationsCtrl.text = profile.relationshipContext;
        _directionCtrl.text = profile.longTermDirection;
        _languageBankCtrl.text = profile.changeLanguageBank.join('\n');
        _cases = cases;
        _reviews = reviews;
        _latest = cases.isNotEmpty ? cases.first : null;
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('加载第二念模块失败：$e');
    }
  }

  Future<void> _saveProfile() async {
    final custom = _customValueCtrl.text
        .split(RegExp(r'[,，;；\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    final bank = _languageBankCtrl.text
        .split(RegExp(r'[\n；;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final profile = SecondThoughtProfile(
      coreValues: <String>{..._selectedValues, ...custom}.toList(growable: false),
      identityVision: _identityCtrl.text.trim(),
      relationshipContext: _relationsCtrl.text.trim(),
      longTermDirection: _directionCtrl.text.trim(),
      changeLanguageBank: bank,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _dao.saveProfile(profile);
    _customValueCtrl.clear();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _selectedValues = profile.coreValues.toSet();
    });
    _toast('第二念价值档案已保存。');
  }

  Future<void> _generate() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) {
      _toast('请先写下一个正在纠结、摇摆、拖延或需要整合的问题。');
      return;
    }
    setState(() => _generating = true);
    try {
      final result = await _ai.generate(
        scene: _scene,
        userInput: input,
        profile: _profile,
        recentContextJson: await _dao.recentContextJson(),
      );
      await _dao.insertCase(result);
      await _mergeProfile(result);
      await _load();
      _toast('已生成第二念分析，并作为独立案例保存。');
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _mergeProfile(SecondThoughtCaseRecord record) async {
    final values = <String>{..._profile.coreValues, ...record.coreValuesToConfirm, ...record.possibleValues}
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
    final bank = <String>{..._profile.changeLanguageBank, ...record.changeTalk.all.take(6)}
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
    if (values.length == _profile.coreValues.length && bank.length == _profile.changeLanguageBank.length) return;
    await _dao.saveProfile(_profile.copyWith(
      coreValues: values.take(24).toList(growable: false),
      changeLanguageBank: bank.take(32).toList(growable: false),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<void> _markStatus(SecondThoughtCaseRecord item, String status) async {
    if (item.id == null) return;
    await _dao.updateCaseStatus(item.id!, status);
    await _load();
  }

  Future<void> _deleteCase(SecondThoughtCaseRecord item) async {
    if (item.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这个第二念案例？'),
        content: const Text('会同时删除该案例的复盘记录。此操作不可撤销。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await _dao.deleteCase(item.id!);
    await _load();
  }

  Future<void> _reviewCase(SecondThoughtCaseRecord item) async {
    if (item.id == null) return;
    final happenedCtrl = TextEditingController();
    final valueCtrl = TextEditingController(text: item.coreValuesToConfirm.take(3).join('、'));
    final voicesCtrl = TextEditingController(text: item.innerCommittee.take(2).map((e) => e.voiceName).join('、'));
    final adjustCtrl = TextEditingController(text: item.actionExperiment.recoveryPlanIfFailed);
    final nextCtrl = TextEditingController(text: item.actionExperiment.microAction);
    String status = 'partial';
    final review = await showDialog<SecondThoughtReviewRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('复盘：不是审判，是收集现实证据'),
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
                    DropdownMenuItem(value: 'integrating', child: Text('正在与矛盾共处')),
                  ],
                  onChanged: (v) => setLocal(() => status = v ?? 'partial'),
                ),
                const SizedBox(height: 8),
                TextField(controller: happenedCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '实际发生了什么？')),
                TextField(controller: valueCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '哪些价值被体现或被提醒？')),
                TextField(controller: voicesCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '哪个内在声音仍然很强？')),
                TextField(controller: adjustCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '下一次怎么调小或调准？')),
                TextField(controller: nextCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '下一步最小行动')),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(SecondThoughtReviewRecord(
                caseId: item.id!,
                status: status,
                whatHappened: happenedCtrl.text.trim(),
                valuesLived: valueCtrl.text.trim(),
                remainingVoices: voicesCtrl.text.trim(),
                adjustment: adjustCtrl.text.trim(),
                nextMicroAction: nextCtrl.text.trim(),
              )),
              child: const Text('保存复盘'),
            ),
          ],
        ),
      ),
    );
    happenedCtrl.dispose();
    valueCtrl.dispose();
    voicesCtrl.dispose();
    adjustCtrl.dispose();
    nextCtrl.dispose();
    if (review == null) return;
    await _dao.insertReview(review);
    await _dao.updateCaseStatus(item.id!, status == 'completed' ? 'integrating' : 'acting');
    await _load();
    _toast('复盘已保存。');
  }

  void _openPromptCenter() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const AiPromptSettingsPage(
        initialModuleId: 'second_thought',
        initialPromptId: SecondThoughtPromptConfig.globalId,
      ),
    ));
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 10,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('第二念 · 矛盾心理价值行动引擎'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: '向导'),
              Tab(text: '四型诊断'),
              Tab(text: '价值地图'),
              Tab(text: '内在委员会'),
              Tab(text: '全局图景'),
              Tab(text: '改变语言'),
              Tab(text: '行动实验'),
              Tab(text: '复盘整合'),
              Tab(text: '共处/社会'),
              Tab(text: 'Prompt'),
            ],
          ),
          actions: <Widget>[
            IconButton(onPressed: _openPromptCenter, icon: const Icon(Icons.tune_outlined), tooltip: '统一 Prompt 配置中心'),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: '刷新'),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: <Widget>[
                  _buildGuideTab(),
                  _buildTypeDiagnosisTab(),
                  _buildValueMapTab(),
                  _buildInnerCommitteeTab(),
                  _buildBigPictureTab(),
                  _buildChangeTalkTab(),
                  _buildActionTab(),
                  _buildReviewTab(),
                  _buildIntegrationSocialTab(),
                  _buildPromptTab(),
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
          value: _sceneLabels.containsKey(_scene) ? _scene : 'capture',
          decoration: const InputDecoration(labelText: '当前场景层 Prompt', border: OutlineInputBorder()),
          items: _sceneLabels.entries.map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value))).toList(growable: false),
          onChanged: (v) => setState(() => _scene = v ?? 'capture'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _inputCtrl,
          minLines: 6,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: '写下你现在的“既想又不想 / 选择摇摆 / 拖延抗拒 / 价值冲突”',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _generating ? null : _generate,
          icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.psychology_alt_outlined),
          label: Text(_generating ? 'AI 正在进行三层 Prompt 分析...' : '生成第二念分析'),
        ),
        const SizedBox(height: 16),
        if (_latest != null) _caseCard(_latest!, expanded: true),
        const SizedBox(height: 12),
        ..._cases.skip(_latest == null ? 0 : 1).take(20).map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _caseCard(c))),
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: <Color>[Color(0xFFEFF6FF), Color(0xFFF8FAFC), Color(0xFFF7F2FF)]),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('不急着消灭矛盾，先理解矛盾；不让 AI 替你决定，而是让价值带你行动。', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, height: 1.25)),
        const SizedBox(height: 8),
        const Text('已扩展为完整独立闭环：四型诊断、Go/No 地图、内在委员会、价值地图、可能自我、全局画布、七类改变语言、行动实验、复盘整合、社会影响与共处策略。', style: TextStyle(color: Color(0xB3000000), height: 1.45)),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: _openPromptCenter, icon: const Icon(Icons.tune_outlined), label: const Text('到设置页统一配置本模块全部 AI 提示词')),
      ]),
    );
  }

  Widget _statsStrip() {
    final items = <_MetricItem>[
      _MetricItem('案例', _stats.cases.toString()),
      _MetricItem('行动实验', _stats.actionExperiments.toString()),
      _MetricItem('开放', _stats.openCases.toString()),
      _MetricItem('复盘', _stats.reviews.toString()),
      _MetricItem('价值', _stats.valueCount.toString()),
      _MetricItem('改变语言', _stats.changeTalkCount.toString()),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) => SizedBox(
        width: 104,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(children: <Widget>[
              Text(item.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(item.label, style: const TextStyle(fontSize: 12, color: Colors.black54), textAlign: TextAlign.center),
            ]),
          ),
        ),
      )).toList(growable: false),
    );
  }

  Widget _caseCard(SecondThoughtCaseRecord c, {bool expanded = false}) {
    return Card(
      elevation: expanded ? 1 : 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: expanded ? const Color(0xFFCBD5E1) : const Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            Icon(_typeIcon(c.ambivalenceType), color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(child: Text(c.title.isEmpty ? '第二念案例' : c.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            Text(_fmt(c.createdAtMs), style: const TextStyle(color: Colors.black45, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
            Chip(label: Text(c.ambivalenceType), visualDensity: VisualDensity.compact),
            Chip(label: Text(_sceneLabels[c.scene] ?? c.scene), visualDensity: VisualDensity.compact),
            Chip(label: Text('状态：${_statusLabel(c.status)}'), visualDensity: VisualDensity.compact),
            if (c.confidence > 0) Chip(label: Text('置信 ${(c.confidence * 100).clamp(0, 100).toStringAsFixed(0)}%'), visualDensity: VisualDensity.compact),
            if (c.riskLevel != 'none') Chip(label: Text('风险：${c.riskLevel}'), visualDensity: VisualDensity.compact),
          ]),
          if (c.coreConflict.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(c.coreConflict, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4))),
          if (c.aiResponse.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(c.aiResponse, style: const TextStyle(height: 1.48))),
          if (expanded) ...<Widget>[
            const Divider(height: 24),
            _forceMap(c),
            if (c.coreValuesToConfirm.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              const Text('核心价值候选', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: c.coreValuesToConfirm.map((v) => Chip(label: Text(v), visualDensity: VisualDensity.compact)).toList(growable: false)),
            ],
            if (c.actionExperiment.hasAction) ...<Widget>[
              const SizedBox(height: 10),
              _actionMini(c.actionExperiment),
            ],
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            OutlinedButton.icon(onPressed: () => _reviewCase(c), icon: const Icon(Icons.fact_check_outlined), label: const Text('复盘')),
            OutlinedButton.icon(onPressed: () => _markStatus(c, 'acting'), icon: const Icon(Icons.play_arrow_outlined), label: const Text('行动中')),
            OutlinedButton.icon(onPressed: () => _markStatus(c, 'integrating'), icon: const Icon(Icons.all_inclusive), label: const Text('整合')),
            OutlinedButton.icon(onPressed: () => _markStatus(c, 'closed'), icon: const Icon(Icons.check_circle_outline), label: const Text('关闭')),
            TextButton.icon(onPressed: () => _deleteCase(c), icon: const Icon(Icons.delete_outline), label: const Text('删除')),
          ]),
        ]),
      ),
    );
  }

  Widget _buildTypeDiagnosisTab() {
    final source = _latest;
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      _sectionTitle('四型矛盾诊断', '把“纠结”先归类：糖果店、陷阱、悠悠球、钟摆。类型不同，行动策略也不同。'),
      const SizedBox(height: 12),
      if (source != null) _caseCard(source, expanded: false),
      const SizedBox(height: 12),
      _typeCard('Go-Go · 糖果店型', '多个选项都好。重点不是逼自己否定某个好选项，而是看优先级、机会成本、阶段兼容和长期身份。', Icons.toll_outlined, source?.ambivalenceType == 'Go-Go'),
      _typeCard('No-No · 陷阱型', '多个选项都不好。重点是最小伤害、底线价值、拖延代价、外部支持和可承受的下一步。', Icons.warning_amber_outlined, source?.ambivalenceType == 'No-No'),
      _typeCard('Go-No · 悠悠球型', '同一对象既吸引又排斥。重点是短期奖励与长期代价、诱因管理、替代动作和反复复盘。', Icons.sync_alt_outlined, source?.ambivalenceType == 'Go-No'),
      _typeCard('Go-No-Go-No · 钟摆型', '互斥选项各有强好处和强坏处。重点是第三选择、试运行、时间边界、后悔预演和价值排序。', Icons.compare_arrows_outlined, source?.ambivalenceType == 'Go-No-Go-No'),
      _principleCard(Icons.route_outlined, '下一步分流', source == null ? '先生成一个案例，AI 会根据文本判断类型。' : _typeNextStep(source.ambivalenceType)),
    ]);
  }

  Widget _typeCard(String title, String body, IconData icon, bool selected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? Colors.indigo : const Color(0xFFE5E7EB), width: selected ? 1.4 : 1),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Icon(icon, color: selected ? Colors.indigo : Colors.black54),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(height: 1.42, color: Color(0xB3000000))),
        ])),
      ]),
    );
  }

  String _typeNextStep(String type) {
    switch (type) {
      case 'Go-Go':
        return '建议进入“价值地图”和“全局图景”：把多个好选项分别连接到长期身份、时间成本和阶段优先级。';
      case 'No-No':
        return '建议进入“全局图景”和“共处/社会”：先识别底线风险、最小伤害方案和需要求助的资源。';
      case 'Go-No':
        return '建议进入“内在委员会”和“行动实验”：看同一对象的短期好处与长期代价，并设计可逆替代动作。';
      case 'Go-No-Go-No':
        return '建议进入“全局图景”：设置复查期限，设计第三条路或试运行实验，避免无限钟摆。';
      default:
        return '信息还不够。可以先补充：你靠近它会得到什么？远离它又在保护什么？';
    }
  }

  Widget _buildValueMapTab() {
    final source = _latest;
    final values = <String>{..._profile.coreValues, if (source != null) ...source.possibleValues, if (source != null) ...source.coreValuesToConfirm}.where((e) => e.isNotEmpty).toList(growable: false);
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      _sectionTitle('价值地图与可能自我', '把选择从“短期舒服/不舒服”带回“我想成为什么样的人”。'),
      const SizedBox(height: 12),
      const Text('选择你的核心价值候选', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _valueOptions.map((v) => FilterChip(
          label: Text(v),
          selected: _selectedValues.contains(v),
          onSelected: (selected) => setState(() => selected ? _selectedValues.add(v) : _selectedValues.remove(v)),
        )).toList(growable: false),
      ),
      const SizedBox(height: 10),
      TextField(controller: _customValueCtrl, minLines: 1, maxLines: 2, decoration: const InputDecoration(labelText: '补充自定义价值，逗号或换行分隔', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      TextField(controller: _identityCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '理想自我：我想成为什么样的人？', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      TextField(controller: _directionCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '长期方向 / 未来自我', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      TextField(controller: _relationsCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '关系与社会背景：这会影响哪些人？哪些声音来自外界？', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      TextField(controller: _languageBankCtrl, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: '我的改变语言库（一行一句）', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _saveProfile, icon: const Icon(Icons.save_outlined), label: const Text('保存价值档案')),
      const SizedBox(height: 16),
      if (values.isNotEmpty) _listCard('当前价值候选', values, Icons.diamond_outlined),
      if (source != null && source.valueConflicts.isNotEmpty) _valueConflictCard(source.valueConflicts),
      if (source != null && source.evidenceQuestions.isNotEmpty) _listCard('价值证据问题', source.evidenceQuestions, Icons.fact_check_outlined),
      _possibleSelfCard(source),
    ]);
  }

  Widget _possibleSelfCard(SecondThoughtCaseRecord? source) {
    final values = source?.coreValuesToConfirm ?? _profile.coreValues;
    final v = values.isEmpty ? '核心价值' : values.take(3).join('、');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('可能自我四格', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _kvLine('理想自我', '如果我根据$v行动，我可能成为怎样的人？'),
          _kvLine('惯性自我', '如果我继续旧模式，三个月后生活会如何？'),
          _kvLine('恐惧自我', '我最害怕自己变成什么样？这个恐惧是否在替我守住某个价值？'),
          _kvLine('整合自我', '我如何承认恐惧，同时不让恐惧独占方向盘？'),
        ]),
      ),
    );
  }

  Widget _buildInnerCommitteeTab() {
    final source = _latest;
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      _sectionTitle('内在委员会', '把“我怎么这么纠结”拆成多个内在声音：每个声音都在保护某种需要，但不能让单一声音独占决策。'),
      const SizedBox(height: 12),
      if (source == null) const Text('还没有案例。请先在“向导”页生成一次第二念分析。'),
      if (source != null) ...source.innerCommittee.map(_voiceCard),
      if (source != null && source.innerCommittee.isEmpty) const Text('当前案例还没有内在声音数据。'),
    ]);
  }

  Widget _voiceCard(SecondThoughtInnerVoice v) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            const Icon(Icons.record_voice_over_outlined, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(child: Text(v.voiceName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            Chip(label: Text('${v.strength}/10'), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 8),
          _kvLine('它说', v.whatItSays),
          _kvLine('保护', v.whatItProtects),
          _kvLine('害怕', v.whatItFears),
          _kvLine('价值/需要', v.valueOrNeed),
          _kvLine('积极意义', v.benefit),
          _kvLine('过度掌控风险', v.riskIfDominant),
        ]),
      ),
    );
  }

  Widget _buildBigPictureTab() {
    final source = _latest;
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      _sectionTitle('全局图景', '把 A/B/C/D 选项同时放在眼前，避免大脑一会儿只看一边优点、一会儿只看另一边代价。'),
      const SizedBox(height: 12),
      if (source == null) const Text('还没有案例。请先生成一次分析。'),
      if (source != null) ...<Widget>[
        _forceMap(source),
        const SizedBox(height: 12),
        ...source.options.map(_optionCard),
        if (source.thirdWayPossibilities.isNotEmpty) _listCard('第三条路 / 实验性方案', source.thirdWayPossibilities, Icons.call_split_outlined),
        _principleCard(Icons.balance_outlined, '权重提醒', '不要让十个小理由压倒一个底线价值。标记哪些只是轻微不便，哪些属于底线风险或长期价值背离。'),
      ],
    ]);
  }

  Widget _forceMap(SecondThoughtCaseRecord c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      const Text('Go / No 力量地图', style: TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Expanded(child: _forceColumn('Go · 靠近力量', c.goForces, const Color(0xFFEFF6FF))),
        const SizedBox(width: 8),
        Expanded(child: _forceColumn('No · 远离力量', c.noForces, const Color(0xFFFFF7ED))),
      ]),
    ]);
  }

  Widget _forceColumn(String title, List<SecondThoughtForce> forces, Color bg) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (forces.isEmpty) const Text('待补充', style: TextStyle(color: Colors.black45)),
        ...forces.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('• ${f.content}\n  来源：${f.source} · 强度 ${f.strength}/10', style: const TextStyle(fontSize: 12.5, height: 1.35)),
        )),
      ]),
    );
  }

  Widget _optionCard(SecondThoughtDecisionOption o) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: ExpansionTile(
        title: Text(o.optionName, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(o.valueAlignment, maxLines: 2, overflow: TextOverflow.ellipsis),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          _bulletGroup('短期好处', o.shortTermBenefits),
          _bulletGroup('短期代价', o.shortTermCosts),
          _bulletGroup('长期好处', o.longTermBenefits),
          _bulletGroup('长期代价', o.longTermCosts),
          _kvLine('可逆性', o.reversibility),
          _kvLine('风险', o.riskLevel),
          _kvLine('不行动代价', o.costOfInaction),
          _bulletGroup('后悔预演', <String>['三个月后我最可能后悔什么？', '如果选择这个方案，我愿意承担哪一种代价？', '我需要什么支持，才能让这个选项更安全？']),
        ],
      ),
    );
  }

  Widget _buildChangeTalkTab() {
    final source = _latest;
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      _sectionTitle('改变语言', '语言不只反映动机，也会塑造动机。这里把“我想、我能、我有理由、我需要”推进到“我愿意、我决定、我已经开始”。'),
      const SizedBox(height: 12),
      if (source == null) const Text('还没有案例。请先生成一次分析。'),
      if (source != null) ...<Widget>[
        _changeTalkBlock('愿望语言 Desire', source.changeTalk.desire, '我想 / 我希望 / 我渴望'),
        _changeTalkBlock('能力语言 Ability', source.changeTalk.ability, '我可以 / 我能够 / 我曾经做到过'),
        _changeTalkBlock('理由语言 Reason', source.changeTalk.reasons, '这样做的理由是 / 如果我这样做'),
        _changeTalkBlock('需要语言 Need', source.changeTalk.need, '我需要 / 我必须认真面对'),
        _changeTalkBlock('准备语言 Activation', source.changeTalk.activation, '我愿意 / 我准备 / 我可以试试'),
        _changeTalkBlock('承诺语言 Commitment', source.changeTalk.commitment, '我决定 / 我承诺 / 我会在'),
        _changeTalkBlock('已行动语言 Taking Steps', source.changeTalk.takingSteps, '我已经 / 我刚刚 / 我将立刻'),
        _principleCard(Icons.bookmark_add_outlined, '保存规则', '只把你读起来真实、有力量、像自己会说的话保存进语言库。空洞口号不如一句具体承诺。'),
      ],
    ]);
  }

  Widget _changeTalkBlock(String title, List<String> lines, String hint) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(hint, style: const TextStyle(color: Colors.black45, fontSize: 12)),
          const SizedBox(height: 8),
          if (lines.isEmpty) const Text('还没有捕捉到这一类语言，不强行生成。', style: TextStyle(color: Colors.black54)),
          ...lines.map((e) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('• $e', style: const TextStyle(height: 1.35)))),
        ]),
      ),
    );
  }

  Widget _buildActionTab() {
    final actionCases = _cases.where((c) => c.actionExperiment.hasAction).toList(growable: false);
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      _sectionTitle('行动实验室', '不要求完全想通才行动。先设计低风险、可逆、可复盘的小实验，让现实反馈帮助你走出脑内循环。'),
      const SizedBox(height: 12),
      if (actionCases.isEmpty) const Text('还没有行动实验。请先在向导页生成一次分析。'),
      ...actionCases.map((c) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(c.title.isEmpty ? '行动实验' : c.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            _actionMini(c.actionExperiment),
            if (c.actionExperiment.ifThenPlan.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              const Text('If-Then 应对计划', style: TextStyle(fontWeight: FontWeight.w800)),
              ...c.actionExperiment.ifThenPlan.map((m) => Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text('如果：${m['if']}\n那么：${m['then']}', style: const TextStyle(height: 1.35)),
              )),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              FilledButton.icon(onPressed: () => _reviewCase(c), icon: const Icon(Icons.rate_review_outlined), label: const Text('行动后复盘')),
              OutlinedButton.icon(onPressed: () => _markStatus(c, 'acting'), icon: const Icon(Icons.play_arrow_outlined), label: const Text('进行中')),
            ]),
          ]),
        ),
      )),
    ]);
  }

  Widget _actionMini(SecondThoughtActionExperiment action) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFBBF7D0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('下一最小行动实验', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(action.microAction, style: const TextStyle(height: 1.4)),
        Text('时间：${action.startTime.isEmpty ? '今天固定时刻' : action.startTime}'),
        Text('时长：${action.duration.isEmpty ? '5-10 分钟' : action.duration}'),
        Text('完成标准：${action.successCriteria.isEmpty ? '开始就算成功' : action.successCriteria}'),
      ]),
    );
  }

  Widget _buildReviewTab() {
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      _sectionTitle('复盘整合', '失败不是归零，而是信息。复盘关注：行动前哪个声音最强、行动后哪个价值被体现、下一步如何调小或调准。'),
      const SizedBox(height: 12),
      if (_reviews.isEmpty) const Text('还没有复盘记录。'),
      ..._reviews.map((r) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Row(children: <Widget>[
              const Icon(Icons.insights_outlined, color: Colors.indigo),
              const SizedBox(width: 8),
              Expanded(child: Text('复盘 · ${_statusLabel(r.status)}', style: const TextStyle(fontWeight: FontWeight.w900))),
              Text(_fmt(r.createdAtMs), style: const TextStyle(color: Colors.black45, fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            _kvLine('发生了什么', r.whatHappened),
            _kvLine('价值证据', r.valuesLived),
            _kvLine('仍强的声音', r.remainingVoices),
            _kvLine('调整', r.adjustment),
            _kvLine('下一步', r.nextMicroAction),
          ]),
        ),
      )),
    ]);
  }

  Widget _buildIntegrationSocialTab() {
    final source = _latest;
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      _sectionTitle('与矛盾共处 / 社会影响', '不是所有矛盾都要立刻二选一。有些矛盾需要阶段性平衡、第三条路和外部声音辨析。'),
      const SizedBox(height: 12),
      if (source != null) _caseCard(source),
      const SizedBox(height: 12),
      _principleCard(Icons.all_inclusive, '共处而不背叛价值', '问：这个矛盾的两边各自在守护什么价值？哪些可以阶段性平衡？哪些是不可牺牲底线？有没有一种生活结构能让两个重要价值都被部分照顾？'),
      const SizedBox(height: 10),
      _principleCard(Icons.groups_outlined, '社会影响辨析', '把声音分开：哪些来自我自己？哪些来自父母、伴侣、组织、社会评价？哪些是现实责任，哪些是羞耻压迫？'),
      const SizedBox(height: 10),
      _principleCard(Icons.self_improvement_outlined, '垂直矛盾提醒', '如果你嘴上说“不想要”，身体和行为却反复靠近；或者嘴上说“想改变”，行为却总是逃离，可能存在更深层的保护、创伤、依恋或身份议题。先观察，不急着审判。'),
      if (source != null && source.thirdWayPossibilities.isNotEmpty) ...<Widget>[
        const SizedBox(height: 10),
        _listCard('适合当前案例的第三条路', source.thirdWayPossibilities, Icons.call_split_outlined),
      ],
      _listCard('整合表达模板', const <String>[
        '我可以听见安全的声音，也不放弃成长的方向。',
        '我听见外界的声音，但最终要根据我的核心价值和现实责任来选择。',
        '我可以带着不确定走一个小实验，而不是等到完全确定才开始。',
        '这不是一次终局判决，而是一段会被复盘和调整的实践。',
      ], Icons.edit_note_outlined),
    ]);
  }

  Widget _buildPromptTab() {
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      _sectionTitle('Prompt 已迁移到统一配置中心', '本模块所有 AI 提示词均使用 App 设置页的“AI 提示词统一配置中心”管理。模块内部只显示结构与入口，不再做分散配置。'),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _openPromptCenter, icon: const Icon(Icons.tune_outlined), label: const Text('打开第二念 Prompt 配置中心')),
      const SizedBox(height: 12),
      _promptPreview('全局价值层 Prompt', SecondThoughtPromptConfig.globalValuePrompt, maxLines: 8),
      _promptPreview('当前场景层 Prompt：${_sceneLabels[_scene] ?? _scene}', SecondThoughtPromptConfig.scenePrompt(_scene), maxLines: 8),
      _promptPreview('输出格式 Prompt', SecondThoughtPromptConfig.outputJsonPrompt, maxLines: 10),
      const SizedBox(height: 12),
      ExpansionTile(
        title: const Text('本模块所有 Prompt ID'),
        subtitle: const Text('在设置页可逐项自由配置、恢复默认、导入导出'),
        children: SecondThoughtPromptConfig.allIds.map((id) => ListTile(
          dense: true,
          title: Text(SecondThoughtPromptConfig.labels[id] ?? id),
          subtitle: Text(id),
        )).toList(growable: false),
      ),
    ]);
  }

  Widget _promptPreview(String title, String body, {int maxLines = 8}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(body.trim(), maxLines: maxLines, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xB3000000))),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(color: Color(0x99000000), height: 1.45)),
    ]);
  }

  Widget _principleCard(IconData icon, String title, String body) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Icon(icon, color: Colors.indigo),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: Color(0xAB000000), height: 1.42)),
        ])),
      ]),
    );
  }

  Widget _listCard(String title, List<String> items, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[Icon(icon, color: Colors.indigo), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 8),
          ...items.map((e) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('• $e', style: const TextStyle(height: 1.35)))),
        ]),
      ),
    );
  }

  Widget _valueConflictCard(List<SecondThoughtValueConflict> conflicts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('价值冲突', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...conflicts.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${c.valueA} ↔ ${c.valueB}\n${c.description}', style: const TextStyle(height: 1.35)),
          )),
        ]),
      ),
    );
  }

  Widget _bulletGroup(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        ...items.map((e) => Text('• $e', style: const TextStyle(height: 1.35))),
      ]),
    );
  }

  Widget _kvLine(String key, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, height: 1.35),
          children: <TextSpan>[
            TextSpan(text: '$key：', style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Go-Go':
        return Icons.toll_outlined;
      case 'No-No':
        return Icons.warning_amber_outlined;
      case 'Go-No':
        return Icons.sync_alt_outlined;
      case 'Go-No-Go-No':
        return Icons.compare_arrows_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'acting':
        return '行动中';
      case 'integrating':
        return '整合中';
      case 'closed':
        return '已关闭';
      case 'completed':
        return '完成';
      case 'missed':
        return '未完成';
      case 'partial':
        return '部分完成';
      case 'exploring':
      default:
        return '探索中';
    }
  }

  String _fmt(int ms) {
    if (ms <= 0) return '';
    return DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ms));
  }
}

class _MetricItem {
  final String label;
  final String value;
  const _MetricItem(this.label, this.value);
}
