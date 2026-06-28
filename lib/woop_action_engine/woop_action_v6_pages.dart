import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'woop_action_ai_service.dart';
import 'woop_action_dao.dart';
import 'woop_action_models.dart';

class WoopActionDeepClosurePanel extends StatelessWidget {
  final ValueChanged<WoopActionCard>? onOpenCard;
  final Future<void> Function()? onRefresh;

  const WoopActionDeepClosurePanel({
    super.key,
    this.onOpenCard,
    this.onRefresh,
  });

  Future<void> _open(BuildContext context, Widget page) async {
    final result = await Navigator.of(context).push<dynamic>(MaterialPageRoute(builder: (_) => page));
    if (result is WoopActionCard) onOpenCard?.call(result);
    await onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    final items = <_DeepItem>[
      _DeepItem('首次引导', '价值/领域/障碍/第一张卡', Icons.flag_outlined, () => _open(context, WoopActionOnboardingPage(onOpenCard: onOpenCard))),
      _DeepItem('行动实验室', '把 if–then 当作可验证实验', Icons.science_outlined, () => _open(context, WoopActionExperimentLabPage(onOpenCard: onOpenCard))),
      _DeepItem('价值校准审计', '检查目标是否仍属于自己', Icons.verified_user_outlined, () => _open(context, WoopActionValueAlignmentAuditPage(onOpenCard: onOpenCard))),
      _DeepItem('数据闭环导出', '导出本模块完整 JSON', Icons.share_outlined, () => _open(context, const WoopActionDataExportPage())),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('V6 深度闭环补齐', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('继续补齐原产品方案中仍缺失的首次引导、实验验证、价值校准与数据闭环。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.05,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: items.map((item) => _DeepTile(item: item)).toList(growable: false),
        ),
      ]),
    );
  }
}

class WoopActionOnboardingPage extends StatefulWidget {
  final ValueChanged<WoopActionCard>? onOpenCard;
  const WoopActionOnboardingPage({super.key, this.onOpenCard});

  @override
  State<WoopActionOnboardingPage> createState() => _WoopActionOnboardingPageState();
}

class _WoopActionOnboardingPageState extends State<WoopActionOnboardingPage> {
  final WoopActionDao _dao = WoopActionDao();
  final TextEditingController _valuesCtrl = TextEditingController();
  final TextEditingController _domainsCtrl = TextEditingController(text: '健康\n学习/工作\n关系\n情绪管理');
  final TextEditingController _obstaclesCtrl = TextEditingController(text: '拖延\n完美主义\n害怕评价\n分心逃避\n报复性熬夜');
  final TextEditingController _wishCtrl = TextEditingController();
  final TextEditingController _outcomeCtrl = TextEditingController();
  final TextEditingController _obstacleCtrl = TextEditingController();
  final TextEditingController _actionCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _valuesCtrl.dispose();
    _domainsCtrl.dispose();
    _obstaclesCtrl.dispose();
    _wishCtrl.dispose();
    _outcomeCtrl.dispose();
    _obstacleCtrl.dispose();
    _actionCtrl.dispose();
    super.dispose();
  }

  List<String> _lines(String text) => text.split(RegExp(r'[\n,，;；]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);

  Future<void> _saveAndCreate() async {
    final wish = _wishCtrl.text.trim();
    if (wish.isEmpty) {
      _toast('请先写下你的第一张 WOOP 愿望。');
      return;
    }
    setState(() => _saving = true);
    try {
      await _dao.saveProfile(WoopActionProfile(
        userValues: _valuesCtrl.text.trim(),
        lifeDomains: _lines(_domainsCtrl.text),
        commonObstacles: _lines(_obstaclesCtrl.text),
        preferredActionWindow: '默认从 5—15 分钟第一步开始，不把愿望直接做成大任务。',
        supportBoundary: '不要把外部结构性困难全部归因于个人；需要先找可控部分。',
      ));
      final now = DateTime.now().millisecondsSinceEpoch;
      final obstacle = _obstacleCtrl.text.trim();
      final card = WoopActionCard(
        createdAtMs: now,
        updatedAtMs: now,
        source: 'onboarding',
        scene: 'onboarding_first_woop',
        title: wish.length > 20 ? '${wish.substring(0, 20)}…' : wish,
        rawInput: wish,
        currentJudgement: '首次引导生成：已完成价值、生活领域、常见障碍和第一张 WOOP 卡的初始化。',
        wish: wish,
        outcome: _outcomeCtrl.text.trim(),
        obstacle: obstacle,
        obstacleType: obstacle.isEmpty ? '待验证内在障碍' : '首次识别内在障碍',
        obstacleTags: obstacle.isEmpty ? const <String>['待验证'] : _lines(_obstaclesCtrl.text).take(3).toList(growable: false),
        planIf: obstacle.isEmpty ? '我开始拖延或想逃避时' : obstacle,
        planThen: _actionCtrl.text.trim().isEmpty ? '先做 5 分钟最小动作' : _actionCtrl.text.trim(),
        firstAction: _actionCtrl.text.trim().isEmpty ? '现在写下这件事的第一个 5 分钟动作。' : _actionCtrl.text.trim(),
        reviewQuestion: '第一张 WOOP 的障碍是否真的出现？这个 if–then 是否足够小？',
        reminder: '首次引导不是结束。请在 24 小时内进入今日驾驶舱记录一次触发/未触发。',
        feasibility: 'medium',
        importance: 'high',
        controllability: 'medium',
        cost: 'medium',
        belongsToUser: 'unclear',
        direction: 'continue',
        status: 'active',
        provider: 'manual',
        modelLabel: 'WOOP 首次引导',
        fromFallback: true,
      );
      final id = await _dao.upsertCard(card);
      final saved = await _dao.getCard(id) ?? card.copyWith(id: id);
      if (!mounted) return;
      widget.onOpenCard?.call(saved);
      Navigator.pop(context, saved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WOOP 首次引导')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          const _DeepGuideBlock(
            title: '从“功能入口”补成“首次产品体验”',
            icon: Icons.flag_outlined,
            body: '最初产品方案要求 App 先帮助用户理解价值体系、识别真实愿望、配置常见障碍，再进入第一张 WOOP。这里把这些步骤合成一个可保存的 onboarding 流程。',
          ),
          _DeepTextBox(controller: _valuesCtrl, label: '你真正重视的方向', hint: '例如：健康、创造、家庭连接、自由、稳定、学习成长'),
          _DeepTextBox(controller: _domainsCtrl, label: '主要生活领域（每行一个）', hint: '健康\n学习/工作\n关系\n情绪管理'),
          _DeepTextBox(controller: _obstaclesCtrl, label: '常见内在障碍（每行一个）', hint: '拖延\n完美主义\n害怕评价'),
          const Divider(height: 28),
          _DeepTextBox(controller: _wishCtrl, label: '第一张 W｜愿望', hint: '例如：今天晚上 10:30 前上床睡觉'),
          _DeepTextBox(controller: _outcomeCtrl, label: '第一张 O｜最佳结果', hint: '例如：明天醒来更清醒，不再后悔熬夜'),
          _DeepTextBox(controller: _obstacleCtrl, label: '第一张 O｜内在障碍', hint: '例如：10 点后觉得累，想刷手机补偿自己'),
          _DeepTextBox(controller: _actionCtrl, label: '第一张 P｜那么行动', hint: '例如：把手机放到客厅，回卧室听 10 分钟播客'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _saveAndCreate,
            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
            label: Text(_saving ? '正在保存首次引导…' : '保存个人化配置并创建第一张 WOOP'),
          ),
        ],
      ),
    );
  }
}

class WoopActionExperimentLabPage extends StatefulWidget {
  final ValueChanged<WoopActionCard>? onOpenCard;
  const WoopActionExperimentLabPage({super.key, this.onOpenCard});

  @override
  State<WoopActionExperimentLabPage> createState() => _WoopActionExperimentLabPageState();
}

class _WoopActionExperimentLabPageState extends State<WoopActionExperimentLabPage> {
  final WoopActionDao _dao = WoopActionDao();
  bool _loading = true;
  List<WoopActionCard> _cards = <WoopActionCard>[];
  List<WoopActionExperiment> _experiments = <WoopActionExperiment>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cards = await _dao.listCardsByStatuses(<String>['active'], limit: 120);
    final experiments = await _dao.listExperiments(limit: 160);
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _experiments = experiments;
      _loading = false;
    });
  }

  Future<void> _createExperiment(WoopActionCard card) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dao.addExperiment(WoopActionExperiment(
      cardId: card.id,
      createdAtMs: now,
      updatedAtMs: now,
      title: card.wish.isEmpty ? '未命名行动实验' : card.wish,
      hypothesis: '如果“${card.planIf.isEmpty ? card.obstacle : card.planIf}”出现，并执行“${card.planThen.isEmpty ? card.firstAction : card.planThen}”，我会更接近：${card.outcome}',
      triggerText: card.planIf.isEmpty ? card.obstacle : card.planIf,
      actionText: card.planThen.isEmpty ? card.firstAction : card.planThen,
      expectedDifficulty: card.feasibility == 'low' ? 'high' : 'medium',
      scheduledAtMs: now,
      status: 'planned',
      result: '',
      learning: '',
    ));
    await _load();
  }

  Future<void> _finishExperiment(WoopActionExperiment experiment, String result) async {
    await _dao.updateExperimentStatus(
      experiment.id,
      status: 'closed',
      result: result,
      learning: result == 'worked' ? '该 if–then 有效，下一步可保持或提高频率。' : '该 if–then 没有覆盖真实障碍，需要重新识别障碍或降低动作门槛。',
    );
    if (experiment.cardId > 0) {
      await _dao.addPlanLog(WoopActionPlanLog(
        cardId: experiment.cardId,
        triggerText: experiment.triggerText,
        actionText: experiment.actionText,
        result: result == 'worked' ? 'done' : 'missed',
        note: '来自行动实验室：${result == 'worked' ? '实验有效' : '实验未通过'}。',
      ));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WOOP 行动实验室')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: <Widget>[
                  const _DeepGuideBlock(
                    title: '把 if–then 计划当成可验证实验',
                    icon: Icons.science_outlined,
                    body: '最初方案强调失败是系统反馈。实验室让每条计划都有“假设—触发—行动—结果—学习”，避免只保存计划却不验证。',
                  ),
                  const Text('从行动中卡片创建实验', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (_cards.isEmpty)
                    const _DeepEmpty(text: '暂无行动中 WOOP 卡。先创建一张行动卡。')
                  else
                    for (final card in _cards.take(8)) ...<Widget>[
                      _ExperimentSourceTile(card: card, onOpen: () => widget.onOpenCard?.call(card), onCreate: () => _createExperiment(card)),
                      const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 18),
                  Text('实验记录 ${_experiments.length} 条', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (_experiments.isEmpty)
                    const _DeepEmpty(text: '还没有实验记录。选择一张行动卡创建实验后，在这里标记有效或未通过。')
                  else
                    for (final exp in _experiments) ...<Widget>[
                      _ExperimentTile(experiment: exp, onWorked: () => _finishExperiment(exp, 'worked'), onFailed: () => _finishExperiment(exp, 'failed')),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
    );
  }
}

class WoopActionValueAlignmentAuditPage extends StatefulWidget {
  final ValueChanged<WoopActionCard>? onOpenCard;
  const WoopActionValueAlignmentAuditPage({super.key, this.onOpenCard});

  @override
  State<WoopActionValueAlignmentAuditPage> createState() => _WoopActionValueAlignmentAuditPageState();
}

class _WoopActionValueAlignmentAuditPageState extends State<WoopActionValueAlignmentAuditPage> {
  final WoopActionDao _dao = WoopActionDao();
  final WoopActionAiService _ai = WoopActionAiService();
  bool _loading = true;
  bool _generating = false;
  List<WoopActionCard> _cards = <WoopActionCard>[];
  WoopActionProfile _profile = const WoopActionProfile();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cards = await _dao.listCards(limit: 200);
    final profile = await _dao.getProfile();
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _profile = profile;
      _loading = false;
    });
  }

  Future<void> _setDirection(WoopActionCard card, String direction, String status) async {
    await _dao.upsertCard(card.copyWith(direction: direction, status: status));
    await _load();
  }

  Future<void> _generateAudit() async {
    setState(() => _generating = true);
    try {
      final history = await _dao.historySummaryJson(limit: 160);
      final profile = await _dao.profileContextJson();
      final result = await _ai.generateCard(
        userInput: '请做一次 WOOP 价值校准审计：哪些愿望应该继续，哪些应该调整，哪些应该暂存或有尊严地放下？请特别检查这些愿望是否仍然属于我本人，是否代价过高。',
        scene: 'weekly_review',
        source: 'value_alignment_audit',
        extraContext: '$profile\n$history',
      );
      final id = await _dao.upsertCard(result.card.copyWith(scene: 'value_alignment_audit', direction: 'adjust'));
      final saved = await _dao.getCard(id);
      await _load();
      if (!mounted) return;
      if (saved != null) widget.onOpenCard?.call(saved);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('价值校准审计')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                _DeepGuideBlock(
                  title: '该坚持、该调整，还是该放下？',
                  icon: Icons.verified_user_outlined,
                  body: _profile.isEmpty
                      ? '你还没有配置个人化价值。仍可手动审计，但建议先进入首次引导或个人化配置。'
                      : '当前个人化价值：${_profile.userValues.isEmpty ? '未填写' : _profile.userValues}\n常见障碍：${_profile.commonObstacles.join('、')}',
                ),
                FilledButton.icon(
                  onPressed: _generating ? null : _generateAudit,
                  icon: _generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_fix_high_outlined),
                  label: Text(_generating ? '正在生成 AI 审计卡…' : '基于历史生成 AI 价值校准卡'),
                ),
                const SizedBox(height: 18),
                for (final card in _cards) ...<Widget>[
                  _AlignmentTile(card: card, onOpen: () => widget.onOpenCard?.call(card), onContinue: () => _setDirection(card, 'continue', 'active'), onAdjust: () => _setDirection(card, 'adjust', 'active'), onPause: () => _setDirection(card, 'wait', 'paused'), onDrop: () => _setDirection(card, 'drop', 'dropped')),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class WoopActionDataExportPage extends StatefulWidget {
  const WoopActionDataExportPage({super.key});

  @override
  State<WoopActionDataExportPage> createState() => _WoopActionDataExportPageState();
}

class _WoopActionDataExportPageState extends State<WoopActionDataExportPage> {
  final WoopActionDao _dao = WoopActionDao();
  bool _loading = true;
  String _json = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _dao.fullExportJson();
    if (!mounted) return;
    setState(() {
      _json = const JsonEncoder.withIndent('  ').convert(jsonDecode(data));
      _loading = false;
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制 WOOP 模块 JSON 数据。'), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WOOP 数据闭环导出'), actions: <Widget>[IconButton(onPressed: _loading ? null : _copy, icon: const Icon(Icons.copy_outlined))]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                const _DeepGuideBlock(
                  title: '独立模块数据闭环',
                  icon: Icons.share_outlined,
                  body: '导出内容只来自 woop_action_* 表和 WOOP 个人化配置，不混入其他模块。用于审计是否真正形成“愿望—障碍—计划—执行—复盘—学习”的闭环。',
                ),
                FilledButton.icon(onPressed: _copy, icon: const Icon(Icons.copy_outlined), label: const Text('复制 JSON')),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(18)),
                  child: SelectableText(_json, style: const TextStyle(color: Color(0xFFE5E7EB), fontFamily: 'monospace', fontSize: 12, height: 1.35)),
                ),
              ],
            ),
    );
  }
}

class _ExperimentSourceTile extends StatelessWidget {
  final WoopActionCard card;
  final VoidCallback onOpen;
  final VoidCallback onCreate;
  const _ExperimentSourceTile({required this.card, required this.onOpen, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(card.wish, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(card.planText.isEmpty ? '暂无 if–then 文本' : card.planText, style: const TextStyle(color: Color(0xFF374151), height: 1.4)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: <Widget>[
          OutlinedButton(onPressed: onOpen, child: const Text('打开卡片')),
          FilledButton(onPressed: onCreate, child: const Text('创建实验')),
        ]),
      ]),
    );
  }
}

class _ExperimentTile extends StatelessWidget {
  final WoopActionExperiment experiment;
  final VoidCallback onWorked;
  final VoidCallback onFailed;
  const _ExperimentTile({required this.experiment, required this.onWorked, required this.onFailed});

  @override
  Widget build(BuildContext context) {
    final closed = experiment.status == 'closed';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(experiment.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('假设：${experiment.hypothesis}', style: const TextStyle(height: 1.4, color: Color(0xFF374151))),
        const SizedBox(height: 6),
        Text('如果 ${experiment.triggerText} → 那么 ${experiment.actionText}', style: const TextStyle(height: 1.4, fontWeight: FontWeight.w800)),
        if (closed) ...<Widget>[
          const SizedBox(height: 8),
          Text('结果：${experiment.result}｜学习：${experiment.learning}', style: const TextStyle(color: Color(0xFF6B7280), height: 1.35)),
        ] else ...<Widget>[
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: <Widget>[
            FilledButton(onPressed: onWorked, child: const Text('实验有效')),
            OutlinedButton(onPressed: onFailed, child: const Text('未通过')),
          ]),
        ],
      ]),
    );
  }
}

class _AlignmentTile extends StatelessWidget {
  final WoopActionCard card;
  final VoidCallback onOpen;
  final VoidCallback onContinue;
  final VoidCallback onAdjust;
  final VoidCallback onPause;
  final VoidCallback onDrop;
  const _AlignmentTile({required this.card, required this.onOpen, required this.onContinue, required this.onAdjust, required this.onPause, required this.onDrop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(card.wish.isEmpty ? card.title : card.wish, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('方向 ${_directionText(card.direction)}｜状态 ${card.status}｜归属 ${card.belongsToUser}｜代价 ${card.cost}', style: const TextStyle(color: Color(0xFF6B7280), height: 1.35)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          OutlinedButton(onPressed: onOpen, child: const Text('打开')),
          FilledButton(onPressed: onContinue, child: const Text('继续')),
          OutlinedButton(onPressed: onAdjust, child: const Text('调整')),
          OutlinedButton(onPressed: onPause, child: const Text('暂存')),
          OutlinedButton(onPressed: onDrop, child: const Text('放下')),
        ]),
      ]),
    );
  }
}

class _DeepGuideBlock extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  const _DeepGuideBlock({required this.title, required this.body, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[Icon(icon, color: const Color(0xFF4F46E5)), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)))]),
        const SizedBox(height: 10),
        Text(body, style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
      ]),
    );
  }
}

class _DeepTextBox extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _DeepTextBox({required this.controller, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        minLines: 2,
        maxLines: 5,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        ),
      ),
    );
  }
}

class _DeepEmpty extends StatelessWidget {
  final String text;
  const _DeepEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Text(text, style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
    );
  }
}

class _DeepItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _DeepItem(this.title, this.subtitle, this.icon, this.onTap);
}

class _DeepTile extends StatelessWidget {
  final _DeepItem item;
  const _DeepTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Row(children: <Widget>[
          Icon(item.icon, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
          ])),
        ]),
      ),
    );
  }
}

String _directionText(String direction) {
  switch (direction) {
    case 'adjust':
      return '调整';
    case 'wait':
      return '等待/暂存';
    case 'drop':
      return '放下';
    default:
      return '继续';
  }
}
