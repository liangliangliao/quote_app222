import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../platform/exact_alarm_permission_coordinator.dart';
import '../platform/native_scheduler.dart';
import '../services/unified_ai_service.dart';
import 'evidence_growth_ai_service.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_knowledge.dart';
import 'evidence_growth_models.dart';
import 'evidence_growth_notification_service.dart';
import 'evidence_growth_router.dart';

const _brand = Color(0xFF24766C);
const _ink = Color(0xFF183E3A);
const _soft = Color(0xFFF2F7F6);
const _line = Color(0xFFD6E4E1);

class EvidenceGrowthHomePage extends StatefulWidget {
  const EvidenceGrowthHomePage({super.key, this.initialTrialId = '', this.initialInput = ''});
  final String initialTrialId;
  final String initialInput;
  @override
  State<EvidenceGrowthHomePage> createState() => _EvidenceGrowthHomePageState();
}

class _EvidenceGrowthHomePageState extends State<EvidenceGrowthHomePage> {
  final _dao = EvidenceGrowthDao();
  final _ai = EvidenceGrowthAiService();
  final _router = const EvidenceGrowthRouter();
  var _tab = 0;
  var _loading = true;
  var _routing = false;
  List<RealityTrial> _active = const [];
  List<RealityTrial> _recent = const [];
  EvidenceSummary? _summary;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _dao.ensureTables();
    await _reload();
    if (!mounted) return;
    if (widget.initialTrialId.isNotEmpty) {
      final trial = await _dao.byId(widget.initialTrialId);
      if (trial != null && mounted) await _openTrial(trial);
    } else if (widget.initialInput.trim().isNotEmpty) {
      await _begin(widget.initialInput);
    }
  }

  Future<void> _reload() async {
    final active = await _dao.activeTrials();
    final recent = await _dao.recentTrials();
    final summary = await _dao.summary();
    if (!mounted) return;
    setState(() {
      _active = active;
      _recent = recent;
      _summary = summary;
      _loading = false;
    });
  }

  Future<void> _begin(String input) async {
    if (input.trim().isEmpty || _routing) return;
    setState(() => _routing = true);
    try {
      var route = _router.route(input);
      if (route.canAct) route = await _ai.enrichRoute(route);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => _RoutePage(route: route, dao: _dao, ai: _ai)));
      await _reload();
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  Future<void> _openTrial(RealityTrial trial) async {
    final Widget page = trial.status == 'REVIEWED'
        ? _DecisionPage(trial: trial, dao: _dao, ai: _ai)
        : trial.isClosed
            ? _ArchivePage(trial: trial)
            : _TrialPage(trial: trial, dao: _dao, ai: _ai);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFB),
      appBar: AppBar(
        title: const Text('六模块证据成长'),
        actions: [
          IconButton(tooltip: '功能问答助手', onPressed: () => _showGuide(context, _ai), icon: const Icon(Icons.auto_awesome_outlined)),
          IconButton(tooltip: '设置', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _SettingsPage(dao: _dao))).then((_) => _reload()), icon: const Icon(Icons.settings_outlined)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _tab,
              children: [
                _Practice(active: _active, summary: _summary!, busy: _routing, onBegin: _begin, onOpen: _openTrial),
                _Review(recent: _recent, onOpen: _openTrial),
                _Learning(onApply: _begin),
                _Evidence(summary: _summary!, recent: _recent),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.play_circle_outline), selectedIcon: Icon(Icons.play_circle), label: '实战'),
          NavigationDestination(icon: Icon(Icons.replay_outlined), selectedIcon: Icon(Icons.replay_circle_filled), label: '复盘'),
          NavigationDestination(icon: Icon(Icons.account_tree_outlined), selectedIcon: Icon(Icons.account_tree), label: '学习'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: '我的证据'),
        ],
      ),
    );
  }
}

class _Practice extends StatefulWidget {
  const _Practice({required this.active, required this.summary, required this.busy, required this.onBegin, required this.onOpen});
  final List<RealityTrial> active;
  final EvidenceSummary summary;
  final bool busy;
  final ValueChanged<String> onBegin;
  final ValueChanged<RealityTrial> onOpen;
  @override
  State<_Practice> createState() => _PracticeState();
}

class _PracticeState extends State<_Practice> {
  final _input = TextEditingController();
  final _speech = SpeechToText();
  var _listening = false;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _voice() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!await _speech.initialize()) return;
    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: SpeechListenOptions(localeId: 'zh_CN'),
      onResult: (result) {
        _input.text = result.recognizedWords;
        _input.selection = TextSelection.collapsed(offset: _input.text.length);
        if (result.finalResult && mounted) setState(() => _listening = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        const Text('把一个真实问题带进现实', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(height: 6),
        const Text('系统自动选择模块与知识依据，只给一个能获得现实证据的下一步。', style: TextStyle(color: Color(0xFF58706B), height: 1.45)),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: _soft,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(children: [
              TextField(
                controller: _input,
                minLines: 3,
                maxLines: 6,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '例如：我知道要投简历，但就是没开始……',
                  border: OutlineInputBorder(),
                  helperText: '说事实即可，不需要先判断属于哪个模块。',
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                IconButton.filledTonal(onPressed: _voice, icon: Icon(_listening ? Icons.stop : Icons.mic_none), tooltip: _listening ? '停止录音' : '语音输入'),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _input.text.trim().isEmpty || widget.busy ? null : () => widget.onBegin(_input.text),
                    icon: widget.busy ? const SizedBox.square(dimension: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.route),
                    label: Text(widget.busy ? '正在匹配证据' : '生成现实下一步'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
        if (widget.active.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _Title('继续中的 Reality Trial', '从中断处继续，预测与结果不会丢失'),
          ...widget.active.map((trial) => _TrialTile(trial: trial, onTap: () => widget.onOpen(trial))),
        ],
        const SizedBox(height: 20),
        const _Title('20 个真实案例', '点击填入，再按自己的情况修改'),
        SizedBox(
          height: 106,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: EvidenceGrowthKnowledge.defaultCases.length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (_, index) => SizedBox(
              width: 230,
              child: ActionChip(
                avatar: CircleAvatar(child: Text('${index + 1}')),
                label: Text(EvidenceGrowthKnowledge.defaultCases[index], maxLines: 3, overflow: TextOverflow.ellipsis),
                onPressed: () => setState(() => _input.text = EvidenceGrowthKnowledge.defaultCases[index]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          elevation: 0,
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE2F2EE), child: Icon(Icons.hub_outlined, color: _brand)),
            title: const Text('六模块不是六张孤立页面', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('已激活 ${widget.summary.activatedNodes}/${widget.summary.learnedNodes} 个节点 · 当前闭环：信念→目标→行动→失败→复盘→改变'),
          ),
        ),
      ],
    );
  }
}

class _RoutePage extends StatefulWidget {
  const _RoutePage({required this.route, required this.dao, required this.ai});
  final EvidenceRouteResult route;
  final EvidenceGrowthDao dao;
  final EvidenceGrowthAiService ai;
  @override
  State<_RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<_RoutePage> {
  late EvidenceRouteResult route = widget.route;
  var alternative = -1;
  var starting = false;

  Future<void> _start() async {
    if (!route.canAct || starting) return;
    final setup = await showDialog<_PredictionSetup>(context: context, barrierDismissible: false, builder: (_) => _PredictionDialog());
    if (setup == null || !mounted) return;
    setState(() => starting = true);
    try {
      if (setup.remind) {
        final granted = await ExactAlarmPermissionCoordinator.ensureGranted(
          context,
          featureName: 'Reality Trial 结果复盘提醒',
          explanation: '仅在本轮观察窗口到期时提醒你比较预测与实际。',
        );
        if (!granted || !mounted) return;
      }
      var trial = await widget.dao.createTrial(route, prediction: setup.prediction, probability: setup.probability, reviewAt: setup.reviewAt);
      trial = await widget.dao.startTrial(trial);
      if (setup.remind) await const EvidenceGrowthNotificationService().scheduleReview(trial);
      if (!mounted) return;
      await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => _TrialPage(trial: trial, dao: widget.dao, ai: widget.ai)));
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = !route.canAct;
    return Scaffold(
      appBar: AppBar(title: const Text('现实下一步')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Wrap(spacing: 7, children: [
            _Chip(route.primaryModule.label, _brand),
            _Chip(route.evidenceLevel, route.evidenceLevel == 'E0' ? Colors.red : _brand),
            if (route.riskGate != 'PASS') _Chip(route.riskGate, Colors.red),
          ]),
          const SizedBox(height: 12),
          _Card(title: blocked ? '当前不能生成正式行动' : 'AI/规则判断', child: Text(route.inference, style: const TextStyle(height: 1.5))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: blocked ? const Color(0xFFFFF1F0) : const Color(0xFFE7F5F1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: blocked ? const Color(0xFFF0C1BD) : const Color(0xFFB8DBD3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(blocked ? route.status : '现在只做这一件事', style: TextStyle(color: blocked ? Colors.red : _brand, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(route.actionInstruction.isEmpty ? route.missingFacts.join('\n') : route.actionInstruction, style: const TextStyle(fontSize: 20, height: 1.4, fontWeight: FontWeight.w900, color: _ink)),
              if (route.completionDefinition.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('完成定义｜${route.completionDefinition}', style: const TextStyle(color: Color(0xFF536A65))),
              ],
              if (!blocked) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _Why(route)), icon: const Icon(Icons.help_outline), label: const Text('为什么'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: route.alternatives.isEmpty ? null : () {
                    setState(() {
                      alternative = (alternative + 1) % route.alternatives.length;
                      route = route.copyWith(actionInstruction: route.alternatives[alternative], completionDefinition: '完成替代动作并留下一个可观察事实。');
                    });
                  }, icon: const Icon(Icons.swap_horiz), label: const Text('换方案'))),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 10),
          _Card(title: '四类信息已分开', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Label('用户事实', route.facts.join('\n')),
            const Divider(),
            _Label('知识证据', route.selectedNodes.map((e) => '${e.id} · ${e.title}').join('\n')),
            const Divider(),
            _Label('AI 推断', route.inference),
            const Divider(),
            _Label('产品动作', route.actionInstruction),
          ])),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: FilledButton(
            onPressed: blocked ? () => Navigator.pop(context) : starting ? null : _start,
            child: Text(blocked ? '返回补充现实信息' : starting ? '正在建立 Trial' : '开始并保存事前预测'),
          ),
        ),
      ),
    );
  }
}

class _PredictionSetup {
  const _PredictionSetup(this.prediction, this.probability, this.reviewAt, this.remind);
  final String prediction;
  final double probability;
  final DateTime reviewAt;
  final bool remind;
}

class _PredictionDialog extends StatefulWidget {
  @override
  State<_PredictionDialog> createState() => _PredictionDialogState();
}

class _PredictionDialogState extends State<_PredictionDialog> {
  final prediction = TextEditingController(text: '我预测：完成这个动作后，会获得至少一个可观察结果。');
  var probability = .6;
  var window = 0;
  var remind = true;
  @override
  void dispose() {
    prediction.dispose();
    super.dispose();
  }
  DateTime get reviewAt {
    final now = DateTime.now();
    return [now.add(const Duration(minutes: 10)), now.add(const Duration(hours: 1)), now.add(const Duration(hours: 4)), DateTime(now.year, now.month, now.day + 1, 20)][window];
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('先保存预测，再进入现实'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('复盘时逐字保留这条预测，不能事后改写。'),
          const SizedBox(height: 10),
          TextField(controller: prediction, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '我预测会发生什么？', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Text('发生概率：${(probability * 100).round()}%'),
          Slider(value: probability, min: 0, max: 1, divisions: 10, onChanged: (v) => setState(() => probability = v)),
          DropdownButtonFormField<int>(
            initialValue: window,
            decoration: const InputDecoration(labelText: '结果观察窗口', border: OutlineInputBorder()),
            items: const [DropdownMenuItem(value: 0, child: Text('10 分钟后')), DropdownMenuItem(value: 1, child: Text('1 小时后')), DropdownMenuItem(value: 2, child: Text('4 小时后')), DropdownMenuItem(value: 3, child: Text('明天 20:00'))],
            onChanged: (v) => setState(() => window = v ?? 0),
          ),
          SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: remind, onChanged: (v) => setState(() => remind = v), title: const Text('到期精准提醒'), subtitle: const Text('开启时才申请闹钟权限')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, _PredictionSetup(prediction.text.trim(), probability, reviewAt, remind)), child: const Text('保存并开始')),
        ],
      );
}

class _TrialPage extends StatefulWidget {
  const _TrialPage({required this.trial, required this.dao, required this.ai});
  final RealityTrial trial;
  final EvidenceGrowthDao dao;
  final EvidenceGrowthAiService ai;
  @override
  State<_TrialPage> createState() => _TrialPageState();
}

class _TrialPageState extends State<_TrialPage> {
  late RealityTrial trial = widget.trial;
  var saving = false;
  Future<void> _capture(String kind) async {
    final result = await showDialog<_Captured>(context: context, barrierDismissible: false, builder: (_) => _ResultDialog(kind));
    if (result == null || !mounted) return;
    setState(() => saving = true);
    try {
      final captured = await widget.dao.captureResult(trial, didAction: result.did, actualOutcome: result.actual, unexpected: result.unexpected);
      await const EvidenceGrowthNotificationService().cancel(trial.id);
      final review = await widget.ai.review(captured);
      final reviewed = await widget.dao.saveReview(captured, review);
      if (!mounted) return;
      await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => _DecisionPage(trial: reviewed, review: review, dao: widget.dao, ai: widget.ai)));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reality Trial · 进行中')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 7, children: [_Chip(trial.primaryModule.label, _brand), _Chip(trial.stretchLevel, trial.stretchLevel == 'RECOVERY' ? Colors.blue : _brand)]),
          const SizedBox(height: 12),
          _Card(title: '唯一主动作', child: Text(trial.actionInstruction, style: const TextStyle(fontSize: 21, height: 1.4, fontWeight: FontWeight.w900, color: _ink))),
          const SizedBox(height: 10),
          _Card(title: '事前预测 · 已锁定', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(trial.prediction),
            const SizedBox(height: 6),
            Text('置信度 ${(trial.probability * 100).round()}% · 观察至 ${_date(DateTime.fromMillisecondsSinceEpoch(trial.reviewAtMs))}', style: const TextStyle(color: Color(0xFF60736E))),
          ])),
          const SizedBox(height: 10),
          _Card(title: '安全与证据', child: Text('风险门 ${trial.riskGate} · 可撤回：${trial.reversible ? '是' : '否'} · 保留下一轮：${trial.nextRoundPreserved ? '是' : '否'}\n依据 ${trial.nodeIds.join(' / ')}')),
          const SizedBox(height: 16),
          const Text('完成、部分、未做、中止都允许；只记录事实。'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(onPressed: saving ? null : () => _capture('完成'), child: const Text('完成')),
            OutlinedButton(onPressed: saving ? null : () => _capture('部分完成'), child: const Text('部分完成')),
            OutlinedButton(onPressed: saving ? null : () => _capture('未做'), child: const Text('未做')),
            TextButton(onPressed: saving ? null : () => _capture('中止'), child: const Text('中止')),
          ]),
          if (saving) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
        ]),
      );
}

class _Captured {
  const _Captured(this.did, this.actual, this.unexpected);
  final bool did;
  final String actual;
  final String unexpected;
}

class _ResultDialog extends StatefulWidget {
  const _ResultDialog(this.kind);
  final String kind;
  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog> {
  final actual = TextEditingController();
  final unexpected = TextEditingController();
  @override
  void dispose() {
    actual.dispose();
    unexpected.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${widget.kind} · 只记录事实'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: actual, minLines: 3, maxLines: 6, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: '实际发生了什么？', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: unexpected, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '最意外的是什么？（可选）', border: OutlineInputBorder())),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: actual.text.trim().isEmpty ? null : () => Navigator.pop(context, _Captured(widget.kind == '完成' || widget.kind == '部分完成', actual.text.trim(), unexpected.text.trim())), child: const Text('保存事实并复盘')),
        ],
      );
}

class _DecisionPage extends StatefulWidget {
  const _DecisionPage({required this.trial, required this.dao, required this.ai, this.review});
  final RealityTrial trial;
  final EvidenceGrowthDao dao;
  final EvidenceGrowthAiService ai;
  final TrialReviewResult? review;
  @override
  State<_DecisionPage> createState() => _DecisionPageState();
}

class _DecisionPageState extends State<_DecisionPage> {
  late RealityTrial trial = widget.trial;
  late TrialReviewResult review = widget.review ?? TrialReviewResult(
    predictionOriginal: trial.prediction,
    actualFacts: [trial.actualOutcome],
    predictionError: '原预测与实际结果已分别保存。',
    failureClass: trial.failureClass,
    learning: trial.learning,
    ruleUpdate: trial.ruleUpdate,
    decision: trial.decision.isEmpty ? 'ADJUST' : trial.decision,
    nextChangeOneVariable: trial.nextAction,
    knowledgeNodeIds: trial.nodeIds,
  );
  String? chosen;
  Future<void> _choose(String decision) async {
    final reason = TextEditingController(text: review.learning);
    final next = TextEditingController(text: review.nextChangeOneVariable);
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text('$decision · 确认本轮出口'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: reason, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '依据 / 学习')),
        TextField(controller: next, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: decision == 'EXIT' ? 'Hypothesis Closed / 替代路线' : '下一轮只改变什么？')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认'))],
    ));
    if (ok == true) {
      trial = await widget.dao.decide(trial, decision: decision, reason: reason.text, nextAction: next.text);
      if (mounted) setState(() => chosen = decision);
    }
    reason.dispose();
    next.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('复盘结果 · 本轮出口')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      _Card(title: '预测完整性', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Label('原预测（未改写）', review.predictionOriginal), const Divider(),
        _Label('实际事实', trial.actualOutcome), const Divider(),
        _Label('Prediction Error', review.predictionError),
      ])),
      const SizedBox(height: 10),
      _Card(title: '经历产生的信息', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 7, children: [_Chip(review.failureClass, _brand), _Chip('建议 ${review.decision}', const Color(0xFF5268A0))]),
        const SizedBox(height: 10), Text(review.learning), const SizedBox(height: 6), Text('规则更新｜${review.ruleUpdate}', style: const TextStyle(color: Color(0xFF5C706B))),
      ])),
      const SizedBox(height: 16),
      const _Title('选择 ACT / ADJUST / EXIT', '退出也是完成验证，不等于否定自己'),
      _DecisionTile('ACT · 继续取样', '核心假设仍有支持；再取一个现实样本。', chosen == 'ACT', () => _choose('ACT')),
      _DecisionTile('ADJUST · 只改一个变量', '方法、强度或环境被反证；只改一个条件。', chosen == 'ADJUST', () => _choose('ADJUST')),
      _DecisionTile('EXIT · 结束路线', '保存 Hypothesis Closed、成本与学习。', chosen == 'EXIT', () => _choose('EXIT')),
      if (chosen != null) FilledButton(onPressed: () => Navigator.pop(context), child: const Text('完成验证并返回')),
    ]),
  );
}

class _Review extends StatelessWidget {
  const _Review({required this.recent, required this.onOpen});
  final List<RealityTrial> recent;
  final ValueChanged<RealityTrial> onOpen;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const _Title('现实证据复盘', '比较预测与实际，再决定继续、调整或退出'),
      if (recent.isEmpty) const _Empty('还没有 Trial。先从“实战”输入一个现实问题。'),
      ...recent.map((e) => _TrialTile(trial: e, onTap: () => onOpen(e))),
    ],
  );
}

class _Learning extends StatefulWidget {
  const _Learning({required this.onApply});
  final ValueChanged<String> onApply;
  @override
  State<_Learning> createState() => _LearningState();
}

class _LearningState extends State<_Learning> {
  GrowthModule? module;
  var query = '';
  @override
  Widget build(BuildContext context) {
    final nodes = EvidenceGrowthKnowledge.nodes.where((node) {
      return (module == null || node.module == module) && (query.isEmpty || node.embeddingText.toLowerCase().contains(query.toLowerCase()));
    }).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      const _Title('Tal 六模块母树', 'Tal 核心默认展开；专家只在明确缺口时补位'),
      TextField(onChanged: (v) => setState(() => query = v.trim()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '搜索知识、情境或 Operator', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 6, children: [
        FilterChip(label: const Text('全部'), selected: module == null, onSelected: (_) => setState(() => module = null)),
        ...GrowthModule.values.map((m) => FilterChip(label: Text(m.label), selected: module == m, onSelected: (_) => setState(() => module = m))),
      ]),
      const SizedBox(height: 10),
      ExpansionTile(
        initiallyExpanded: true,
        title: Text('Tal 核心 · ${nodes.where((e) => e.isTal).length} 个'),
        children: nodes.where((e) => e.isTal).map((node) => _NodeTile(node, widget.onApply)).toList(),
      ),
      ExpansionTile(
        title: Text('专家延伸 I / II · ${nodes.where((e) => !e.isTal).length} 个'),
        subtitle: const Text('仅用于明确机制缺口'),
        children: nodes.where((e) => !e.isTal).map((node) => _NodeTile(node, widget.onApply)).toList(),
      ),
    ]);
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile(this.node, this.onApply);
  final EvidenceKNode node;
  final ValueChanged<String> onApply;
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text('${node.id} · ${node.title}'),
    subtitle: Text(node.claim, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => ListView(padding: const EdgeInsets.all(20), children: [
      Text(node.title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12), _Label('是什么', node.claim), const Divider(),
      _Label('为什么', node.mechanism), const Divider(),
      _Label('怎么做', node.operators.join(' / ')), const Divider(),
      _Label('使用边界', node.boundaries.join('\n')), const Divider(),
      _Label('来源', node.locator.display), const SizedBox(height: 16),
      FilledButton.icon(onPressed: () { Navigator.pop(context); onApply('我想把“${node.title}”应用到当前真实问题：'); }, icon: const Icon(Icons.play_arrow), label: const Text('立即应用，创建 Trial')),
    ])),
  );
}

class _Evidence extends StatelessWidget {
  const _Evidence({required this.summary, required this.recent});
  final EvidenceSummary summary;
  final List<RealityTrial> recent;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const _Title('我的证据，不是公共真理', '只更新你在具体情境中的适配度，不修改 Tal/专家节点'),
    GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.7,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _Metric('知识激活', '${(summary.activationRate * 100).round()}%'),
        _Metric('行动完成', '${(summary.actionRate * 100).round()}%'),
        _Metric('失败样本', '${summary.failureSamples}'),
        _Metric('策略调整', '${summary.strategyChanges}'),
        _Metric('主动退出', '${summary.exits}'),
        _Metric('Reality Trial', '${summary.startedTrials}'),
      ],
    ),
    const SizedBox(height: 16),
    _Card(title: '六模块调用分布', child: Column(children: GrowthModule.values.map((m) {
      final count = summary.moduleCounts[m] ?? 0;
      return Row(children: [Expanded(child: Text(m.label)), Text('$count 次')]);
    }).toList())),
    const SizedBox(height: 10),
    _Card(title: '最常调用节点', child: Text(summary.topNodeIds.isEmpty ? '完成 Trial 后形成个人适配证据。' : summary.topNodeIds.join(' · '))),
  ]);
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.dao});
  final EvidenceGrowthDao dao;
  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  var loading = true;
  var keepRaw = true;
  var exact = false;
  var provider = '未配置';
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }
  Future<void> _load() async {
    keepRaw = await widget.dao.getSetting('keep_raw_input', fallback: 'true') == 'true';
    exact = await NativeScheduler.canScheduleExactAlarm();
    final cfg = await UnifiedAiService().resolveGlobalConfig();
    provider = cfg.available ? '${cfg.label} · ${cfg.displayModel}' : '未配置（自动使用离线路由）';
    if (mounted) setState(() => loading = false);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('证据成长设置')),
    body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
      _Card(title: '运行配置', child: Column(children: [
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('AI Provider'), subtitle: Text(provider)),
        const ListTile(contentPadding: EdgeInsets.zero, title: Text('知识库版本'), subtitle: Text('KB35 v3.5 · Tal-first · Prompt eg-p1.0')),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('精准闹钟权限'), subtitle: Text(exact ? '已授权' : '未授权；仅在创建提醒时引导开启')),
      ])),
      const SizedBox(height: 10),
      _Card(title: '隐私与数据', child: Column(children: [
        SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: keepRaw, title: const Text('保存原始问题文本'), subtitle: const Text('关闭后只保存结构化事实、节点与结果'), onChanged: (v) async { await widget.dao.setSetting('keep_raw_input', '$v'); if (mounted) setState(() => keepRaw = v); }),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.copy_all_outlined), title: const Text('导出个人证据 JSON'), onTap: () async {
          final data = await widget.dao.exportJson();
          await Clipboard.setData(ClipboardData(text: data));
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制结构化 JSON')));
        }),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('删除个人证据', style: TextStyle(color: Colors.red)), onTap: () async {
          final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('删除所有个人证据？'), content: const Text('Trial、结果、复盘和个人适配度会删除；公共知识节点不会改变。'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认删除'))]));
          if (ok == true) await widget.dao.deletePersonalEvidence();
        }),
      ])),
    ]),
  );
}

class _Why extends StatelessWidget {
  const _Why(this.route);
  final EvidenceRouteResult route;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('为什么推荐这个动作？', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
    const SizedBox(height: 12),
    ...route.selectedNodes.map((node) => _Card(title: '${node.id} · ${node.title}', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(node.claim), const SizedBox(height: 8), Text('来源｜${node.locator.display}', style: const TextStyle(color: _brand)), const SizedBox(height: 5), Text('边界｜${node.boundaries.first}', style: const TextStyle(color: Color(0xFF5B6E69))),
    ]))),
    const SizedBox(height: 8),
    _Label('适用理由', route.candidates.where((e) => route.selectedNodes.any((n) => n.id == e.node.id)).map((e) => e.reason).join('\n')),
  ]);
}

Future<void> _showGuide(BuildContext context, EvidenceGrowthAiService ai) async {
  final controller = TextEditingController();
  var answer = '可以问：这个模块怎么用？为什么要先保存预测？什么情况应该 EXIT？';
  var busy = false;
  await showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => StatefulBuilder(builder: (context, setState) => Padding(
    padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('功能问答助手', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10), Text(answer), const SizedBox(height: 12),
      TextField(controller: controller, decoration: const InputDecoration(hintText: '询问流程、填写方法或知识依据', border: OutlineInputBorder())),
      const SizedBox(height: 8), SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : () async {
        setState(() => busy = true);
        answer = await ai.answerGuide(controller.text);
        setState(() => busy = false);
      }, child: Text(busy ? '正在查找依据' : '提问'))),
    ]),
  )));
  controller.dispose();
}

class _ArchivePage extends StatelessWidget {
  const _ArchivePage({required this.trial});
  final RealityTrial trial;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Trial 证据档案')), body: ListView(padding: const EdgeInsets.all(16), children: [
    _Card(title: '${trial.decision} · ${trial.primaryModule.label}', child: Text(trial.decision == 'EXIT' ? 'Hypothesis Closed：结束路线不等于否定自己。' : '本轮验证已完成。')),
    const SizedBox(height: 10), _Card(title: '原预测', child: Text(trial.prediction)),
    const SizedBox(height: 10), _Card(title: '实际事实', child: Text(trial.actualOutcome)),
    const SizedBox(height: 10), _Card(title: '学习与规则更新', child: Text('${trial.learning}\n\n${trial.ruleUpdate}')),
  ]));
}

class _DecisionTile extends StatelessWidget {
  const _DecisionTile(this.title, this.body, this.selected, this.onTap);
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, color: selected ? const Color(0xFFE4F3EF) : Colors.white, child: ListTile(onTap: onTap, leading: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: _brand), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(body)));
}

class _TrialTile extends StatelessWidget {
  const _TrialTile({required this.trial, required this.onTap});
  final RealityTrial trial;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: ListTile(onTap: onTap, leading: CircleAvatar(backgroundColor: _moduleColor(trial.primaryModule).withValues(alpha: .14), child: Icon(Icons.route, color: _moduleColor(trial.primaryModule))), title: Text(trial.actionInstruction, maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: Text('${trial.primaryModule.label} · ${_status(trial.status)} · ${_date(DateTime.fromMillisecondsSinceEpoch(trial.updatedAtMs))}'), trailing: const Icon(Icons.chevron_right)));
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: _line)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)), const SizedBox(height: 9), child])));
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Color(0xFF60736E))) ]));
}

class _Label extends StatelessWidget {
  const _Label(this.label, this.text);
  final String label;
  final String text;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _brand)), const SizedBox(height: 3), Text(text.isEmpty ? '—' : text, style: const TextStyle(height: 1.45))]);
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(20)), child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)));
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(15)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: _brand)), Text(label, style: const TextStyle(fontSize: 12))]));
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF60736E)))));
}

Color _moduleColor(GrowthModule module) => switch (module) {
  GrowthModule.belief => const Color(0xFF5268A0),
  GrowthModule.goal => const Color(0xFFC77835),
  GrowthModule.action => const Color(0xFF24766C),
  GrowthModule.failure => const Color(0xFFA95361),
  GrowthModule.review => const Color(0xFF76569B),
  GrowthModule.change => const Color(0xFF3D7897),
};
String _status(String value) => switch (value) { 'READY' => '待开始', 'IN_PROGRESS' => '进行中', 'RESULT_CAPTURED' => '待复盘', 'REVIEWED' => '待决策', 'DECIDED' => '已验证', _ => value };
String _date(DateTime value) => '${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
