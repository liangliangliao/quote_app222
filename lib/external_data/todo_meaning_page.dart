import 'package:flutter/material.dart';

import 'todo_goal_dao.dart';
import 'todo_goal_models.dart';
import 'todo_meaning_engine.dart';
import 'todo_meaning_models.dart';

const _meaningNavy = Color(0xFF18324A);
const _meaningTeal = Color(0xFF2F7D78);
const _meaningGold = Color(0xFFD49A3A);
const _meaningPaper = Color(0xFFF6F1E8);

class TodoMeaningCompassPage extends StatefulWidget {
  const TodoMeaningCompassPage({
    super.key,
    required this.dao,
    required this.goals,
    required this.todaySteps,
    required this.reflections,
    required this.onOpenGoals,
    required this.onOpenToday,
    required this.onOpenReview,
    required this.onDataChanged,
  });

  final TodoGoalDao dao;
  final List<TodoGoalProfile> goals;
  final List<TodoGoalActionStep> todaySteps;
  final List<TodoGoalReflection> reflections;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenToday;
  final VoidCallback onOpenReview;
  final Future<void> Function() onDataChanged;

  @override
  State<TodoMeaningCompassPage> createState() => _TodoMeaningCompassPageState();
}

class _TodoMeaningCompassPageState extends State<TodoMeaningCompassPage> {
  final _engine = const TodoMeaningEngine();
  TodoMeaningCompassSnapshot? _snapshot;
  List<TodoMeaningFutureAnchor> _anchors = const [];
  List<TodoMeaningArchiveEntry> _archive = const [];
  List<TodoMeaningHardshipRecord> _hardships = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait<Object?>([
      widget.dao.latestMeaningCompassSnapshot(),
      widget.dao.listMeaningFutureAnchors(),
      widget.dao.listMeaningArchive(),
      widget.dao.listMeaningHardships(),
    ]);
    if (!mounted) return;
    setState(() {
      _snapshot = values[0] as TodoMeaningCompassSnapshot?;
      _anchors = values[1] as List<TodoMeaningFutureAnchor>;
      _archive = values[2] as List<TodoMeaningArchiveEntry>;
      _hardships = values[3] as List<TodoMeaningHardshipRecord>;
      _loading = false;
    });
  }

  Future<void> _refreshAll() async {
    await _load();
    await widget.onDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        children: [
          _MeaningHero(snapshot: _snapshot, onScan: _openScan),
          const SizedBox(height: 12),
          _CompassMetrics(snapshot: _snapshot),
          const SizedBox(height: 12),
          _MeaningLoopCard(
            openGoals: widget.onOpenGoals,
            openToday: widget.onOpenToday,
            openReview: widget.onOpenReview,
          ),
          const SizedBox(height: 12),
          _ThreePathsCard(onCreation: widget.onOpenGoals, onRelationship: _openRelationshipAction, onAttitude: _openHardship),
          const SizedBox(height: 12),
          _TodayResponsibilityCard(steps: widget.todaySteps, snapshot: _snapshot, onOpenToday: widget.onOpenToday),
          const SizedBox(height: 12),
          _FutureAnchorCard(anchors: _anchors, onAdd: _openAnchor),
          const SizedBox(height: 12),
          _MeaningArchiveCard(entries: _archive, onAdd: _openArchive, onImportCompleted: _archiveCompletedStep),
          const SizedBox(height: 12),
          _HardshipCard(records: _hardships, onOpen: _openHardship),
          const SizedBox(height: 12),
          const _SafetyBoundaryCard(),
        ],
      ),
    );
  }

  Future<void> _openScan() async {
    final situation = TextEditingController(text: _snapshot?.situation ?? '');
    final unavoidable = TextEditingController(text: _snapshot?.unavoidableQuestion ?? '');
    final recurring = TextEditingController(text: _snapshot?.recurringResponsibility ?? '');
    final waiting = TextEditingController(text: _snapshot?.waitingPerson ?? '');
    final unique = TextEditingController(text: _snapshot?.uniqueTask ?? '');
    final avoided = TextEditingController(text: _snapshot?.avoidedResponsibility ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('当前处境扫描'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _field(situation, '用一句话描述你现在的处境'),
          _field(unavoidable, '现在最无法回避的问题是什么？'),
          _field(recurring, '最近反复出现的责任是什么？'),
          _field(waiting, '有谁正在等待你的回应？'),
          _field(unique, '有什么事情可能只有你能完成？'),
          _field(avoided, '你最想逃避、却可能需要面对的是什么？'),
          const Align(alignment: Alignment.centerLeft, child: Text('这不是人格测试。系统只帮助你命名当下责任，并给出下一步练习。', style: TextStyle(color: Colors.black54, height: 1.4))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('生成意义地图')),
        ],
      ),
    );
    if (save != true) return;
    final combined = [situation.text, unavoidable.text, recurring.text, waiting.text, unique.text, avoided.text].join(' ');
    if (_engine.containsCrisisSignal(combined)) {
      if (mounted) await _showCrisisSupport();
      return;
    }
    final snapshot = _engine.buildSnapshot(
      input: TodoMeaningScanInput(
        situation: situation.text,
        unavoidableQuestion: unavoidable.text,
        recurringResponsibility: recurring.text,
        waitingPerson: waiting.text,
        uniqueTask: unique.text,
        avoidedResponsibility: avoided.text,
      ),
      goals: widget.goals,
      todaySteps: widget.todaySteps,
      reflections: widget.reflections,
    );
    await widget.dao.saveMeaningCompassSnapshot(snapshot);
    await _refreshAll();
  }

  Future<void> _openAnchor() async {
    var type = 'work';
    final title = TextEditingController();
    final why = TextEditingController();
    final how = TextEditingController();
    final save = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('建立未来支点'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: '支点类型', border: OutlineInputBorder()), items: const [
          DropdownMenuItem(value: 'work', child: Text('等待我完成的作品 / 任务')),
          DropdownMenuItem(value: 'person', child: Text('等待我照顾 / 回应的人')),
          DropdownMenuItem(value: 'identity', child: Text('等待我成为的自己')),
        ], onChanged: (value) => setLocal(() => type = value ?? 'work')),
        _field(title, '未来正在等待我的具体事物'),
        _field(why, '我的 Why：它为什么值得？'),
        _field(how, '今天的 How：2–15 分钟做什么？'),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, title.text.trim().isNotEmpty), child: const Text('保存支点'))],
    )));
    if (save != true) return;
    await widget.dao.addMeaningFutureAnchor(anchorType: type, title: title.text, whyText: why.text, todayHow: how.text);
    await _refreshAll();
  }

  Future<void> _openArchive({String initialTitle = '', String initialEvidence = '', String goalId = '', String stepId = ''}) async {
    var type = 'completed';
    final title = TextEditingController(text: initialTitle);
    final evidence = TextEditingController(text: initialEvidence);
    final happened = TextEditingController(text: _today());
    final save = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('保存不可夺走的过去'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: '意义证据类型', border: OutlineInputBorder()), items: const [
          DropdownMenuItem(value: 'completed', child: Text('我完成过的')),
          DropdownMenuItem(value: 'loved', child: Text('我爱过 / 回应过的')),
          DropdownMenuItem(value: 'endured', child: Text('我承受过的')),
          DropdownMenuItem(value: 'chosen', child: Text('我选择过的')),
          DropdownMenuItem(value: 'needed', child: Text('我被需要过的')),
        ], onChanged: (value) => setLocal(() => type = value ?? 'completed')),
        _field(title, '已经发生、不会再被夺走的事'),
        _field(evidence, '留下什么证据、影响或记忆？'),
        _field(happened, '发生日期（YYYY-MM-DD）'),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, title.text.trim().isNotEmpty), child: const Text('存入意义档案'))],
    )));
    if (save != true) return;
    await widget.dao.addMeaningArchiveEntry(entryType: type, title: title.text, evidence: evidence.text, happenedOn: happened.text, goalId: goalId, stepId: stepId);
    await _refreshAll();
  }

  Future<void> _archiveCompletedStep() async {
    final completed = widget.todaySteps.where((step) => step.isCompleted).toList(growable: false);
    if (completed.isEmpty) {
      _message('今天还没有已完成行动。完成后可把真实行动一键保存为生命证据。');
      return;
    }
    final step = completed.first;
    await _openArchive(initialTitle: step.title, initialEvidence: '我回应了目标“${step.goalTitle}”，并完成了今天的具体行动。', goalId: step.goalId, stepId: step.stepId);
  }

  Future<void> _openRelationshipAction() async {
    final person = TextEditingController();
    final action = TextEditingController();
    final save = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('关系回应行动'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(person, '今天想真实看见 / 回应谁？'),
        _field(action, '一次联系、倾听、陪伴、感谢或道歉'),
        const Text('不是为了“完成社交打卡”，而是回应一个具体、独特的人。', style: TextStyle(color: Colors.black54, height: 1.4)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, person.text.trim().isNotEmpty), child: const Text('保存为未来支点'))],
    ));
    if (save != true) return;
    await widget.dao.addMeaningFutureAnchor(anchorType: 'person', title: person.text, whyText: '爱与关系使我走向一个真实的人，而不只停留在自我感受中。', todayHow: action.text);
    await _refreshAll();
  }

  Future<void> _openHardship() async {
    final situation = TextEditingController();
    final controllable = TextEditingController();
    final choice = TextEditingController();
    final action = TextEditingController();
    final support = TextEditingController();
    var type = 'partial';
    final save = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('困境分流 · 先解决，再重构'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _field(situation, '正在面对的具体困境'),
        DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: '它有多大程度可以改变？', border: OutlineInputBorder()), items: const [
          DropdownMenuItem(value: 'changeable', child: Text('可改变：优先制定行动计划')),
          DropdownMenuItem(value: 'partial', child: Text('部分可改变：拆出可控部分')),
          DropdownMenuItem(value: 'unchangeable', child: Text('不可改变：练习态度自由')),
        ], onChanged: (value) => setLocal(() => type = value ?? 'partial')),
        const SizedBox(height: 8),
        Text(_engine.classifyControllability(type), style: const TextStyle(color: _meaningTeal, fontWeight: FontWeight.w700, height: 1.4)),
        _field(controllable, '我仍可改变 / 保护的部分'),
        _field(choice, '即使如此，我仍然可以选择什么？'),
        _field(action, '今天一件有尊严的小事'),
        _field(support, '我需要联系谁或获得什么专业支持？'),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, situation.text.trim().isNotEmpty), child: const Text('保存分流结果'))],
    )));
    if (save != true) return;
    if (_engine.containsCrisisSignal('${situation.text} ${choice.text} ${action.text}')) {
      if (mounted) await _showCrisisSupport();
      return;
    }
    await widget.dao.addMeaningHardship(situation: situation.text, controllability: type, controllablePart: controllable.text, remainingChoice: choice.text, dignifiedAction: action.text, supportNeeded: support.text);
    await _refreshAll();
  }

  Future<void> _showCrisisSupport() => showDialog<void>(context: context, barrierDismissible: false, builder: (context) => AlertDialog(
    icon: const Icon(Icons.health_and_safety_outlined, color: Colors.red, size: 34),
    title: const Text('先保证此刻安全'),
    content: const Text('检测到可能涉及自伤或轻生的表达。此时暂停意义追问：\n\n• 如果有立即危险，请联系当地急救服务或前往最近急诊。\n• 在美国或加拿大，可拨打或短信 988 联系危机支持。\n• 现在联系一位可信任的人，请对方陪在你身边并移开可能伤害自己的物品。\n\n本 App 不能替代医生、心理治疗或危机干预。', style: TextStyle(height: 1.55)),
    actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('我会先联系支持'))],
  ));

  Widget _field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: controller, minLines: 1, maxLines: 3, decoration: InputDecoration(labelText: label, alignLabelWithHint: true, border: const OutlineInputBorder())),
  );

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

class _MeaningHero extends StatelessWidget {
  const _MeaningHero({required this.snapshot, required this.onScan});
  final TodoMeaningCompassSnapshot? snapshot;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [_meaningNavy, Color(0xFF315E68)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [BoxShadow(color: Color(0x3318324A), blurRadius: 18, offset: Offset(0, 8))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.explore_outlined, color: Color(0xFFF2C879)), SizedBox(width: 8), Text('MEANING COMPASS · 意义罗盘', style: TextStyle(color: Color(0xFFF2C879), fontWeight: FontWeight.w900, letterSpacing: 1.1))]),
      const SizedBox(height: 18),
      Text(snapshot?.currentMeaningQuestion ?? '今天，生活正在向你提出什么问题？', style: const TextStyle(color: Colors.white, fontSize: 24, height: 1.28, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      Text(snapshot?.nextResponse ?? '不是寻找一个宏大答案，而是在具体处境中发现责任，并用一个真实行动作答。', style: const TextStyle(color: Colors.white70, height: 1.5)),
      const SizedBox(height: 16),
      FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF2C879), foregroundColor: _meaningNavy), onPressed: onScan, icon: const Icon(Icons.radar_outlined), label: Text(snapshot == null ? '开始当前处境扫描' : '重新校准当前处境')),
    ]),
  );
}

class _CompassMetrics extends StatelessWidget {
  const _CompassMetrics({required this.snapshot});
  final TodoMeaningCompassSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('责任清晰度', snapshot?.responsibilityClarity ?? 0, Icons.task_alt_outlined),
      ('未来支点', snapshot?.futureAnchorStrength ?? 0, Icons.flag_outlined),
      ('自我超越', snapshot?.selfTranscendence ?? 0, Icons.people_alt_outlined),
      ('态度自由', snapshot?.attitudeFreedom ?? 0, Icons.wb_sunny_outlined),
    ];
    return _paper(children: [
      const Text('当前意义坐标', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _meaningNavy)),
      const SizedBox(height: 4),
      const Text('用于定位下一步练习，不是给人生打分。', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 14),
      ...values.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
        Icon(item.$3, color: _meaningTeal, size: 20), const SizedBox(width: 8), SizedBox(width: 78, child: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: item.$2 / 5, minHeight: 9, backgroundColor: const Color(0xFFE5DED0), color: item.$2 >= 3 ? _meaningTeal : _meaningGold))),
        const SizedBox(width: 8), Text('${item.$2}/5', style: const TextStyle(fontWeight: FontWeight.w900)),
      ]))),
    ]);
  }
}

class _MeaningLoopCard extends StatelessWidget {
  const _MeaningLoopCard({required this.openGoals, required this.openToday, required this.openReview});
  final VoidCallback openGoals;
  final VoidCallback openToday;
  final VoidCallback openReview;

  @override
  Widget build(BuildContext context) => _paper(children: [
    const Text('意义实践闭环', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _meaningNavy)),
    const SizedBox(height: 12),
    Wrap(spacing: 7, runSpacing: 7, children: const [
      _LoopChip('1 处境觉察'), _LoopChip('2 意义识别'), _LoopChip('3 责任选择'), _LoopChip('4 行动承诺'), _LoopChip('5 复盘保存'), _LoopChip('6 意义更新'),
    ]),
    const SizedBox(height: 14),
    Row(children: [Expanded(child: OutlinedButton(onPressed: openGoals, child: const Text('选择责任'))), const SizedBox(width: 8), Expanded(child: FilledButton(onPressed: openToday, child: const Text('开始行动'))), const SizedBox(width: 8), Expanded(child: OutlinedButton(onPressed: openReview, child: const Text('完成复盘')))]),
  ]);
}

class _LoopChip extends StatelessWidget {
  const _LoopChip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: const Color(0xFFE5F0ED), borderRadius: BorderRadius.circular(20)), child: Text(text, style: const TextStyle(color: _meaningTeal, fontWeight: FontWeight.w800)));
}

class _ThreePathsCard extends StatelessWidget {
  const _ThreePathsCard({required this.onCreation, required this.onRelationship, required this.onAttitude});
  final VoidCallback onCreation;
  final VoidCallback onRelationship;
  final VoidCallback onAttitude;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text('三条意义路径', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _meaningNavy))),
    _path(Icons.auto_awesome_outlined, '创造 · 我可以完成什么？', '连接已有目标、作品、问题树与今日最小行动。', const Color(0xFFEAF0FF), onCreation),
    const SizedBox(height: 8),
    _path(Icons.favorite_border, '体验与爱 · 我可以回应谁？', '把注意力投向一个真实的人、关系或不以效率为目的的体验。', const Color(0xFFFFECE9), onRelationship),
    const SizedBox(height: 8),
    _path(Icons.light_mode_outlined, '态度 · 我可以如何面对？', '先分流可改变部分；只对不可避免之事练习态度自由。', const Color(0xFFFFF3D8), onAttitude),
  ]);

  Widget _path(IconData icon, String title, String text, Color color, VoidCallback tap) => Material(color: color, borderRadius: BorderRadius.circular(18), child: InkWell(borderRadius: BorderRadius.circular(18), onTap: tap, child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [Icon(icon, color: _meaningNavy, size: 28), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: _meaningNavy)), const SizedBox(height: 3), Text(text, style: const TextStyle(color: Colors.black54, height: 1.35))])), const Icon(Icons.chevron_right)]))));
}

class _TodayResponsibilityCard extends StatelessWidget {
  const _TodayResponsibilityCard({required this.steps, required this.snapshot, required this.onOpenToday});
  final List<TodoGoalActionStep> steps;
  final TodoMeaningCompassSnapshot? snapshot;
  final VoidCallback onOpenToday;

  @override
  Widget build(BuildContext context) {
    TodoGoalActionStep? open;
    for (final step in steps) { if (!step.isCompleted) { open = step; break; } }
    return _paper(children: [
      const Row(children: [Icon(Icons.today_outlined, color: _meaningGold), SizedBox(width: 8), Text('今日责任卡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _meaningNavy))]),
      const SizedBox(height: 10),
      Text(open?.title ?? snapshot?.nextResponse ?? '今天还没有责任行动。先从当前处境或已有 To Do 中选择一个真实回应。', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.4)),
      if (open != null) ...[const SizedBox(height: 7), Text('最小行动：${open.minimumStandard.trim().isEmpty ? '先做 2 分钟' : open.minimumStandard}', style: const TextStyle(color: _meaningTeal, fontWeight: FontWeight.w800))],
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onOpenToday, icon: const Icon(Icons.play_arrow), label: Text(open == null ? '去生成今日行动' : '去回应这项责任'))),
    ]);
  }
}

class _FutureAnchorCard extends StatelessWidget {
  const _FutureAnchorCard({required this.anchors, required this.onAdd});
  final List<TodoMeaningFutureAnchor> anchors;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => _paper(children: [
    Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('未来支点', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _meaningNavy)), Text('不是空泛梦想，而是等待我完成、照顾或成为的具体未来。', style: TextStyle(color: Colors.black54, height: 1.35))])), IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline, color: _meaningTeal))]),
    if (anchors.isEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: Text('尚未建立支点。可以从一件作品、一个人或一种想成为的品质开始。')),
    ...anchors.take(3).map((item) => Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)), if (item.whyText.isNotEmpty) Text('Why · ${item.whyText}', style: const TextStyle(color: Colors.black54)), if (item.todayHow.isNotEmpty) Text('今天的 How · ${item.todayHow}', style: const TextStyle(color: _meaningTeal, fontWeight: FontWeight.w700))]))),
  ]);
}

class _MeaningArchiveCard extends StatelessWidget {
  const _MeaningArchiveCard({required this.entries, required this.onAdd, required this.onImportCompleted});
  final List<TodoMeaningArchiveEntry> entries;
  final VoidCallback onAdd;
  final VoidCallback onImportCompleted;
  @override
  Widget build(BuildContext context) => _paper(children: [
    Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('意义档案 · 生命证据库', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _meaningNavy)), Text('已经发生的意义，会成为不可夺走的过去。', style: TextStyle(color: Colors.black54))])), IconButton(onPressed: onAdd, icon: const Icon(Icons.add_photo_alternate_outlined, color: _meaningTeal))]),
    if (entries.isEmpty) ...[const SizedBox(height: 10), const Text('本周有什么事情，一旦发生，就不会再被夺走？'), const SizedBox(height: 8), OutlinedButton.icon(onPressed: onImportCompleted, icon: const Icon(Icons.inventory_2_outlined), label: const Text('从已完成行动保存证据'))],
    ...entries.take(3).map((item) => ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(backgroundColor: Color(0xFFE5F0ED), child: Icon(Icons.bookmark_added_outlined, color: _meaningTeal)), title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text([item.happenedOn, item.evidence].where((text) => text.isNotEmpty).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis))),
  ]);
}

class _HardshipCard extends StatelessWidget {
  const _HardshipCard({required this.records, required this.onOpen});
  final List<TodoMeaningHardshipRecord> records;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => _paper(children: [
    const Text('困境重构', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _meaningNavy)),
    const SizedBox(height: 5),
    const Text('如果痛苦可以改变，优先改变原因；只有面对不可避免之事，才进入态度选择。', style: TextStyle(color: Colors.black54, height: 1.4)),
    if (records.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('最近的有尊严行动：${records.first.dignifiedAction.isEmpty ? records.first.remainingChoice : records.first.dignifiedAction}', style: const TextStyle(color: _meaningTeal, fontWeight: FontWeight.w800))),
    const SizedBox(height: 10),
    OutlinedButton.icon(onPressed: onOpen, icon: const Icon(Icons.call_split_outlined), label: const Text('可改变 / 不可改变分流')),
  ]);
}

class _SafetyBoundaryCard extends StatelessWidget {
  const _SafetyBoundaryCard();
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFF2F0), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1C2BB))), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.health_and_safety_outlined, color: Color(0xFFB94A3D)), SizedBox(width: 10), Expanded(child: Text('安全边界：本系统提供意义探索与自我反思工具，不做医疗诊断，也不替代心理治疗。出现自伤、轻生或立即危险时，应暂停练习并联系当地急救、危机热线、专业人员和可信任支持者。', style: TextStyle(height: 1.45, color: Color(0xFF76372F))))]));
}

Widget _paper({required List<Widget> children}) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(color: _meaningPaper, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5DED0))),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
);
