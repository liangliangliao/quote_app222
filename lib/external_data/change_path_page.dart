import 'package:flutter/material.dart';

import 'change_path_dao.dart';
import 'change_path_engine.dart';
import 'change_path_models.dart';
import 'todo_dao.dart';
import 'todo_goal_dao.dart';
import 'todo_goal_models.dart';
import 'todo_service.dart';

const _changePurple = Color(0xFF6558C8);
const _changeMint = Color(0xFFE9F7F2);

class ChangePathPage extends StatefulWidget {
  const ChangePathPage({super.key});

  @override
  State<ChangePathPage> createState() => _ChangePathPageState();
}

class _ChangePathPageState extends State<ChangePathPage> with SingleTickerProviderStateMixin {
  final _goalDao = TodoGoalDao();
  final _todoDao = TodoDao();
  final _dao = ChangePathDao();
  final _engine = const ChangePathEngine();
  late final TodoGraphService _todoService = TodoGraphService(dao: _todoDao);
  late final TabController _tabs;
  List<TodoGoalProfile> _goals = const [];
  List<TodoGoalActionStep> _steps = const [];
  List<ChangePathActionCard> _cards = const [];
  List<ChangePathEvidence> _evidence = const [];
  List<ChangePathAbcJournal> _journals = const [];
  bool _loading = true;
  bool _busy = false;
  String _selectedGoalId = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _dao.ensureTables();
    final goals = await _goalDao.listGoals();
    final cards = await _dao.listActionCards();
    final evidence = await _dao.listEvidence();
    final journals = await _dao.listJournals();
    final steps = <TodoGoalActionStep>[];
    for (final goal in goals.take(20)) {
      steps.addAll(await _goalDao.listActionSteps(goal.goalId));
    }
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _cards = cards;
      _evidence = evidence;
      _journals = journals;
      _steps = steps;
      _selectedGoalId = _selectedGoalId.isNotEmpty ? _selectedGoalId : (goals.isEmpty ? '' : goals.first.goalId);
      _loading = false;
    });
  }

  TodoGoalProfile? get _selectedGoal {
    for (final goal in _goals) {
      if (goal.goalId == _selectedGoalId) return goal;
    }
    return _goals.isEmpty ? null : _goals.first;
  }

  ChangePathActionCard? get _todayCard {
    for (final card in _cards) {
      if (!card.isCompleted && (_selectedGoalId.isEmpty || card.goalId == _selectedGoalId)) return card;
    }
    return null;
  }

  Future<void> _generateCard() async {
    final goal = _selectedGoal;
    if (goal == null) {
      _message('请先从 Microsoft To Do 或手动输入转化一个改变目标。');
      return;
    }
    final candidates = _steps.where((step) => step.goalId == goal.goalId && !step.isCompleted).toList();
    if (candidates.isEmpty) {
      _message('这个目标还没有可执行行动，请先在“山路行动”中创建最小行动。');
      return;
    }
    setState(() => _busy = true);
    final card = _engine.buildActionCard(goal: goal, step: candidates.first);
    await _dao.saveActionCard(card);
    await _load();
    if (mounted) setState(() => _busy = false);
    _message('已生成改变行动卡。现在离开分析，去现实中完成一个动作。');
  }

  Future<void> _start(ChangePathActionCard card) async {
    await _dao.startAction(card.cardId);
    await _load();
    _message('计时不是重点。现在去做，完成后再回来复盘。');
  }

  Future<void> _writeBack(ChangePathActionCard card) async {
    if (card.sourceListId.trim().isEmpty || card.sourceListId.startsWith('smart_')) {
      _message('这张行动卡没有可写回的真实 Microsoft To Do 列表。');
      return;
    }
    setState(() => _busy = true);
    try {
      final body = '''ChangePath 改变行动卡

改变目标：${card.changeGoal}
旧模式：${card.oldPattern}
保留价值：${card.preservedValue}
当前阻力：${card.resistanceType}

今日行动：${card.action}
难度：${card.difficulty}/10（${card.zoneLabel}）
完成标准：${card.completionStandard}
失败预案：${card.failurePlan}
行动意义：${card.actionMeaning}
复盘问题：${card.reviewQuestion}

改变来自重复，不是完美。完成现实行动后，再回到 ChangePath 复盘。''';
      final remoteTaskId = await _todoService.createTask(
        listId: card.sourceListId,
        title: '[ChangePath] ${card.action}',
        bodyText: body,
        status: 'notStarted',
        importance: 'normal',
        dueDateTime: '',
        dueTimeZone: 'Asia/Shanghai',
        isReminderOn: false,
        recurrenceJson: '',
        categoriesJson: '',
        isMyDay: true,
        writeBack: true,
      );
      if (card.stepId.isNotEmpty) {
        await _goalDao.markStepWrittenBack(stepId: card.stepId, remoteTaskId: remoteTaskId);
      }
      await _goalDao.addSyncLink(
        goalId: card.goalId,
        localStepId: card.stepId,
        todoListId: card.sourceListId,
        todoTaskId: remoteTaskId,
      );
      _message('行动卡已写回 Microsoft To Do，并加入“我的一天”。');
    } catch (error) {
      _message('写回 Microsoft To Do 失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(ChangePathActionCard card) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _ActionReviewDialog(card: card),
    );
    if (result == null) return;
    final didIt = result['didIt'] == 'yes';
    if (!didIt) {
      final diagnosis = _engine.diagnoseResistance(
        action: card.action,
        difficulty: card.difficulty,
        obstacle: result['hardest'] ?? card.resistanceType,
        hasTime: false,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('不把它定义为失败'),
          content: Text('这次数据更像：${diagnosis.type}\n\n${diagnosis.explanation}\n\n调整建议：${diagnosis.adjustment}\n\n下一版：${_engine.downgradedAction(card)}'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了'))],
        ),
      );
      return;
    }
    final actual = result['actual']?.trim() ?? '';
    final evidence = result['evidence']?.trim().isNotEmpty == true ? result['evidence']!.trim() : '即使有不适，我仍完成了一个真实行动。';
    final newBelief = result['newBelief']?.trim().isNotEmpty == true ? result['newBelief']!.trim() : '我不需要等到状态完美，也可以先行动一点。';
    await _dao.addEvidence(
      card: card,
      oldBelief: card.oldPattern,
      prediction: result['prediction'] ?? '',
      actualResult: actual,
      hardestPart: result['hardest'] ?? '',
      evidence: evidence,
      newBelief: newBelief,
    );
    if (card.stepId.isNotEmpty) await _goalDao.completeStep(card.stepId);
    await _load();
    _message('行动已转化为一条新的自我证据。');
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ChangePath｜改变之路'), Text('把想改变，变成真的改变', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400))]),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [Tab(text: '今日改变'), Tab(text: 'AI 教练'), Tab(text: 'ABC 日记'), Tab(text: '自我证据'), Tab(text: '改变地图')],
        ),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [_today(), _coach(), _abc(), _evidenceView(), _map()],
            ),
    );
  }

  Widget _goalPicker() => DropdownButtonFormField<String>(
        value: _selectedGoalId.isEmpty ? null : _selectedGoalId,
        decoration: const InputDecoration(labelText: '今日改变主题', border: OutlineInputBorder()),
        items: _goals.map((goal) => DropdownMenuItem(value: goal.goalId, child: Text(goal.goalTitle, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (value) => setState(() => _selectedGoalId = value ?? ''),
      );

  Widget _today() {
    final card = _todayCard;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _HeroCard(),
        const SizedBox(height: 14),
        if (_goals.isNotEmpty) _goalPicker() else const _Empty(text: '还没有改变主题。先回到目标系统，把一个 To Do 或真实愿望转成目标。'),
        const SizedBox(height: 14),
        if (card == null)
          _Panel(
            title: '今天只生成一个真实行动',
            icon: Icons.bolt_outlined,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('行动会自动继承现有目标、To Do 来源、旧模式、价值与最低完成标准，并校准到拉伸区。'),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _busy ? null : _generateCard, icon: const Icon(Icons.auto_awesome), label: const Text('生成今日行动')),
            ]),
          )
        else
          _ActionCardView(card: card, onStart: () => _start(card), onReview: () => _review(card), onSync: card.sourceListId.isEmpty ? null : () => _writeBack(card)),
        const SizedBox(height: 12),
        const _Panel(
          title: 'Change Loop',
          icon: Icons.loop,
          child: Text('觉察旧模式 → 澄清具体改变 → 识别阻力 → 设计拉伸区行动 → 回到现实执行 → 复盘 → 形成自我证据。\n\n改变来自重复，不是完美。'),
        ),
      ],
    );
  }

  Widget _coach() {
    final goal = _selectedGoal;
    final card = _todayCard;
    final diagnosis = card == null ? null : _engine.diagnoseResistance(action: card.action, difficulty: card.difficulty, obstacle: card.oldPattern, hasTime: true);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _Panel(title: '改变教练工作原则', icon: Icons.psychology_alt_outlined, child: Text('真实承认 → 模式识别 → 阻力判断 → 行动设计 → 复盘强化。\n\n不做空泛鼓励，不承诺速成，不把未完成归因于意志力。')),
        const SizedBox(height: 12),
        if (_goals.isNotEmpty) _goalPicker(),
        const SizedBox(height: 12),
        if (goal != null)
          _Panel(
            title: '当前模式画像',
            icon: Icons.route_outlined,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _line('想改变', goal.goalTitle),
              _line('旧模式', goal.obstacleSummary.isEmpty ? '等待进一步行动数据' : goal.obstacleSummary),
              _line('保留价值', goal.coreValueList.isEmpty ? goal.valueGoal : goal.coreValueList.join('、')),
              _line('身份方向', goal.desiredIdentity),
            ]),
          ),
        if (diagnosis != null) ...[
          const SizedBox(height: 12),
          _Panel(title: '阻力诊断｜${diagnosis.type}', icon: Icons.search, child: Text('${diagnosis.explanation}\n\n调整：${diagnosis.adjustment}')),
        ],
        const SizedBox(height: 12),
        _Panel(
          title: '行为实验室',
          icon: Icons.science_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('不要只在脑中争论旧信念。设计一次低风险现实实验，用实际结果更新认知。'),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: goal == null ? null : () => _createExperiment(goal), icon: const Icon(Icons.add), label: const Text('设计一个行为实验')),
          ]),
        ),
      ],
    );
  }

  Future<void> _createExperiment(TodoGoalProfile goal) async {
    final old = TextEditingController(text: goal.obstacleSummary);
    final action = TextEditingController(text: _todayCard?.action ?? '完成一次低风险拉伸区行动');
    final prediction = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('设计行为实验'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: old, decoration: const InputDecoration(labelText: '要验证的旧信念')),
        TextField(controller: action, decoration: const InputDecoration(labelText: '实验行动')),
        TextField(controller: prediction, decoration: const InputDecoration(labelText: '我预测会发生什么')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存实验'))],
    ));
    if (ok == true) {
      await _dao.saveExperiment(goalId: goal.goalId, oldBelief: old.text, action: action.text, prediction: prediction.text);
      _message('实验已保存。完成后请在行动复盘中记录实际结果。');
    }
    old.dispose(); action.dispose(); prediction.dispose();
  }

  Widget _abc() => _AbcJournalForm(goals: _goals, selectedGoalId: _selectedGoalId, onSaved: (data) async {
        await _dao.addJournal(
          goalId: data.goalId,
          emotion: data.emotion,
          intensity: data.intensity,
          bodySignal: data.body,
          actionTaken: data.action,
          avoidance: data.avoidance,
          stretchAction: data.stretch,
          oldInterpretation: data.oldThought,
          freedomCheck: data.freedom,
          newInterpretation: data.newThought,
        );
        await _load();
        _message('ABC 日记已保存：情绪、行为和认知被放回同一个改变闭环。');
      });

  Widget _evidenceView() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Panel(title: '你的行为正在重写身份', icon: Icons.fingerprint, child: Text('已积累 ${_evidence.length} 条行动证据。这里记录的不是“打卡成功”，而是：这个行动证明了我是怎样的人。')),
          const SizedBox(height: 12),
          if (_evidence.isEmpty) const _Empty(text: '完成一张行动卡并复盘后，第一条自我证据会出现在这里。'),
          ..._evidence.map((item) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.evidenceDate, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Text(item.newEvidence, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const Divider(height: 24),
            _line('旧信念', item.oldBelief),
            _line('真实行动', item.action),
            _line('实际结果', item.actualResult),
            _line('新信念', item.newBelief),
          ])))),
        ],
      );

  Widget _map() {
    final goal = _selectedGoal;
    if (goal == null) return const Center(child: _Empty(text: '创建目标后，改变地图会连接旧模式、保留价值、阻力、新行为与自我证据。'));
    final snapshot = _engine.buildMap(goal: goal, cards: _cards, evidence: _evidence, reviewCount: _journals.where((item) => item.goalId == goal.goalId).length);
    return ListView(padding: const EdgeInsets.all(16), children: [
      _goalPicker(),
      const SizedBox(height: 14),
      _Panel(title: snapshot.theme, icon: Icons.map_outlined, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _mapNode('1', '旧模式', snapshot.oldPattern),
        _mapNode('2', '保留价值', snapshot.preservedValue),
        _mapNode('3', '最强阻力', snapshot.strongestResistance),
        _mapNode('4', '正在练习的新行为', snapshot.newBehavior),
        _mapNode('5', '自我证据', '${snapshot.evidenceCount} 条证据 · ${snapshot.completedActions} 次行动 · ${snapshot.reviewCount} 次 ABC 复盘'),
        _mapNode('6', '新身份叙事', snapshot.newIdentity, last: true),
      ])),
    ]);
  }

  Widget _mapNode(String number, String title, String text, {bool last = false}) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Column(children: [CircleAvatar(radius: 14, backgroundColor: _changePurple, child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12))), if (!last) Container(width: 2, height: 58, color: _changePurple.withOpacity(.25))]),
    const SizedBox(width: 12),
    Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(text.isEmpty ? '等待更多行动数据' : text)]))),
  ]);
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_changePurple, Color(0xFF8A77DD)]), borderRadius: BorderRadius.circular(24)),
    child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('今天不用改变整个人。', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
      SizedBox(height: 6),
      Text('只完成一个真实行动。', style: TextStyle(color: Colors.white, fontSize: 18)),
      SizedBox(height: 14),
      Text('改变是训练，不是刺激。我们正在建立新的路径。', style: TextStyle(color: Colors.white70)),
    ]),
  );
}

class _ActionCardView extends StatelessWidget {
  const _ActionCardView({required this.card, required this.onStart, required this.onReview, this.onSync});
  final ChangePathActionCard card;
  final VoidCallback onStart;
  final VoidCallback onReview;
  final VoidCallback? onSync;
  @override
  Widget build(BuildContext context) {
    final zoneColor = card.zone == 'stretch' ? const Color(0xFF16886B) : card.zone == 'panic' ? Colors.red : Colors.blueGrey;
    return _Panel(title: 'Change Action Card', icon: Icons.directions_run, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _line('改变目标', card.changeGoal),
      _line('旧模式', card.oldPattern),
      _line('保留价值', card.preservedValue),
      _line('当前阻力', card.resistanceType),
      Container(margin: const EdgeInsets.symmetric(vertical: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _changeMint, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('今日行动', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(card.action, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))])),
      Wrap(spacing: 8, children: [Chip(label: Text('${card.difficulty}/10')), Chip(backgroundColor: zoneColor.withOpacity(.12), label: Text(card.zoneLabel, style: TextStyle(color: zoneColor)))]),
      _line('完成标准', card.completionStandard),
      _line('失败预案', card.failurePlan),
      _line('行动意义', card.actionMeaning),
      _line('复盘问题', card.reviewQuestion),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: FilledButton.icon(onPressed: card.isStarted ? null : onStart, icon: const Icon(Icons.open_in_new), label: Text(card.isStarted ? '行动已开始' : '我现在去做'))), const SizedBox(width: 8), Expanded(child: OutlinedButton(onPressed: onReview, child: const Text('完成后复盘')))]),
      if (onSync != null) ...[
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: TextButton.icon(onPressed: onSync, icon: const Icon(Icons.sync), label: const Text('写回 Microsoft To Do · 我的 一天'))),
      ],
    ]));
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.black.withOpacity(.06))), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: _changePurple), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))]), const SizedBox(height: 14), child])));
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text}); final String text;
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(text)));
}

Widget _line(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 8), child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, height: 1.4), children: [TextSpan(text: '$label：', style: const TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: value.isEmpty ? '等待更多行动数据' : value)])));

class _ActionReviewDialog extends StatefulWidget {
  const _ActionReviewDialog({required this.card}); final ChangePathActionCard card;
  @override State<_ActionReviewDialog> createState() => _ActionReviewDialogState();
}
class _ActionReviewDialogState extends State<_ActionReviewDialog> {
  bool _didIt = true;
  final _prediction = TextEditingController();
  final _actual = TextEditingController();
  final _hardest = TextEditingController();
  final _evidence = TextEditingController();
  final _belief = TextEditingController();
  @override void dispose() { _prediction.dispose(); _actual.dispose(); _hardest.dispose(); _evidence.dispose(); _belief.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(
    title: const Text('行动复盘'),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('我完成了吗？'), value: _didIt, onChanged: (v) => setState(() => _didIt = v)),
      TextField(controller: _prediction, decoration: const InputDecoration(labelText: '做之前，我预测会发生什么？')),
      TextField(controller: _actual, decoration: const InputDecoration(labelText: '实际发生了什么？')),
      TextField(controller: _hardest, decoration: const InputDecoration(labelText: '哪个部分最难？')),
      if (_didIt) TextField(controller: _evidence, decoration: const InputDecoration(labelText: '这次行动证明了什么？')),
      if (_didIt) TextField(controller: _belief, decoration: const InputDecoration(labelText: '正在形成的新信念')),
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, {'didIt': _didIt ? 'yes' : 'no', 'prediction': _prediction.text, 'actual': _actual.text, 'hardest': _hardest.text, 'evidence': _evidence.text, 'newBelief': _belief.text}), child: const Text('保存复盘'))],
  );
}

class _AbcData {
  const _AbcData({required this.goalId, required this.emotion, required this.intensity, required this.body, required this.action, required this.avoidance, required this.stretch, required this.oldThought, required this.freedom, required this.newThought});
  final String goalId, emotion, body, action, avoidance, stretch, oldThought, freedom, newThought; final int intensity;
}
class _AbcJournalForm extends StatefulWidget {
  const _AbcJournalForm({required this.goals, required this.selectedGoalId, required this.onSaved});
  final List<TodoGoalProfile> goals; final String selectedGoalId; final Future<void> Function(_AbcData) onSaved;
  @override State<_AbcJournalForm> createState() => _AbcJournalFormState();
}
class _AbcJournalFormState extends State<_AbcJournalForm> {
  late String _goalId; double _intensity = 5;
  final _emotion = TextEditingController(), _body = TextEditingController(), _action = TextEditingController(), _avoidance = TextEditingController(), _stretch = TextEditingController(), _old = TextEditingController(), _freedom = TextEditingController(), _newThought = TextEditingController();
  @override void initState() { super.initState(); _goalId = widget.selectedGoalId; }
  @override void dispose() { for (final c in [_emotion,_body,_action,_avoidance,_stretch,_old,_freedom,_newThought]) { c.dispose(); } super.dispose(); }
  InputDecoration _dec(String label) => InputDecoration(labelText: label, border: const OutlineInputBorder(), alignLabelWithHint: true);
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const _Panel(title: 'ABC 改变日记', icon: Icons.edit_note, child: Text('不是只让自己“想开点”，也不是逼自己行动。记录感受、解释与行为如何互相影响，再用真实行动生成新解释。')),
    const SizedBox(height: 12),
    if (widget.goals.isNotEmpty) DropdownButtonFormField<String>(value: _goalId.isEmpty ? null : _goalId, decoration: _dec('关联改变主题'), items: widget.goals.map((g) => DropdownMenuItem(value: g.goalId, child: Text(g.goalTitle))).toList(), onChanged: (v) => setState(() => _goalId = v ?? '')),
    const SizedBox(height: 12),
    _Panel(title: 'A｜情绪 Affective', icon: Icons.favorite_outline, child: Column(children: [TextField(controller: _emotion, decoration: _dec('今天的主要情绪')), const SizedBox(height: 10), Text('强度 ${_intensity.round()}/10'), Slider(value: _intensity, min: 1, max: 10, divisions: 9, onChanged: (v) => setState(() => _intensity = v)), TextField(controller: _body, decoration: _dec('身体有什么反应？'))])),
    const SizedBox(height: 12),
    _Panel(title: 'B｜行为 Behavioral', icon: Icons.directions_walk, child: Column(children: [TextField(controller: _action, decoration: _dec('我实际采取了什么行动？')), const SizedBox(height: 10), TextField(controller: _avoidance, decoration: _dec('我回避了什么？')), const SizedBox(height: 10), TextField(controller: _stretch, decoration: _dec('我完成了哪个拉伸区行动？'))])),
    const SizedBox(height: 12),
    _Panel(title: 'C｜认知 Cognitive', icon: Icons.psychology_outlined, child: Column(children: [TextField(controller: _old, decoration: _dec('我当时怎么解释这件事？')), const SizedBox(height: 10), TextField(controller: _freedom, decoration: _dec('这个解释让我更自由还是更受限？')), const SizedBox(height: 10), TextField(controller: _newThought, decoration: _dec('行动后，我可以形成什么新解释？')), const SizedBox(height: 14), SizedBox(width: double.infinity, child: FilledButton(onPressed: _goalId.isEmpty ? null : () => widget.onSaved(_AbcData(goalId: _goalId, emotion: _emotion.text, intensity: _intensity.round(), body: _body.text, action: _action.text, avoidance: _avoidance.text, stretch: _stretch.text, oldThought: _old.text, freedom: _freedom.text, newThought: _newThought.text)), child: const Text('保存 ABC 日记')))])),
  ]);
}
