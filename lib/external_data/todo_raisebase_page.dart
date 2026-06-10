import 'package:flutter/material.dart';

import 'todo_failure_growth_models.dart';
import 'todo_goal_dao.dart';
import 'todo_goal_models.dart';
import 'todo_raisebase_engine.dart';
import 'todo_raisebase_models.dart';

class TodoRaiseBasePage extends StatefulWidget {
  const TodoRaiseBasePage({
    super.key,
    required this.dao,
    required this.goals,
    required this.todaySteps,
    required this.reflections,
    required this.onOpenActions,
    required this.onOpenFailure,
    required this.onOpenReview,
    required this.onDataChanged,
  });

  final TodoGoalDao dao;
  final List<TodoGoalProfile> goals;
  final List<TodoGoalActionStep> todaySteps;
  final List<TodoGoalReflection> reflections;
  final VoidCallback onOpenActions;
  final VoidCallback onOpenFailure;
  final VoidCallback onOpenReview;
  final Future<void> Function() onDataChanged;

  @override
  State<TodoRaiseBasePage> createState() => _TodoRaiseBasePageState();
}

class _TodoRaiseBasePageState extends State<TodoRaiseBasePage> {
  static const _purple = Color(0xFF6558B1);
  static const _green = Color(0xFF2F7D68);
  final _engine = const TodoRaiseBaseEngine();
  final _beliefCtrl = TextEditingController();
  final _evidenceCtrl = TextEditingController();
  final _realityCtrl = TextEditingController();
  final _possibilityCtrl = TextEditingController();
  final _proofCtrl = TextEditingController();
  List<TodoRaiseBaseBeliefMap> _maps = const [];
  List<TodoRaiseBaseCheckIn> _checkIns = const [];
  List<TodoFailureGrowthLoop> _failures = const [];
  String _goalId = '';
  int _mood = 3;
  int _coping = 3;
  int _efficacy = 3;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _goalId = widget.goals.isEmpty ? '' : widget.goals.first.goalId;
    _load();
  }

  @override
  void didUpdateWidget(covariant TodoRaiseBasePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.goals.isNotEmpty && !widget.goals.any((goal) => goal.goalId == _goalId)) {
      _goalId = widget.goals.first.goalId;
    }
  }

  @override
  void dispose() {
    _beliefCtrl.dispose();
    _evidenceCtrl.dispose();
    _realityCtrl.dispose();
    _possibilityCtrl.dispose();
    _proofCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final values = await Future.wait<Object>([
      widget.dao.listRaiseBaseBeliefMaps(),
      widget.dao.listRaiseBaseCheckIns(),
      widget.dao.listFailureGrowthLoops(),
    ]);
    if (!mounted) return;
    setState(() {
      _maps = values[0] as List<TodoRaiseBaseBeliefMap>;
      _checkIns = values[1] as List<TodoRaiseBaseCheckIn>;
      _failures = values[2] as List<TodoFailureGrowthLoop>;
      _loading = false;
    });
  }

  TodoGoalProfile? get _selectedGoal {
    for (final goal in widget.goals) {
      if (goal.goalId == _goalId) return goal;
    }
    return widget.goals.isEmpty ? null : widget.goals.first;
  }

  Future<void> _createBeliefMap() async {
    final goal = _selectedGoal;
    if (goal == null) {
      _show('请先从“我的山峰”转化一个目标。');
      return;
    }
    setState(() => _saving = true);
    final map = _engine.buildBeliefMap(
      goal: goal,
      limitingBelief: _beliefCtrl.text,
      realityEvidence: _evidenceCtrl.text,
    );
    await widget.dao.saveRaiseBaseBeliefMap(map);
    await widget.dao.createActionStep(
      goalId: goal.goalId,
      sourceTaskId: goal.sourceTaskId,
      title: map.minimumAction.replaceFirst('先做 5–15 分钟版本：', ''),
      minimumStandard: '只投入 5 分钟，并留下一个可见痕迹。',
      simplifiedStandard: '打开工具，写下标题或完成第一个动作。',
      recommendedStandard: map.minimumAction,
      stretchStandard: '完成后记录一条反馈，不用证明自己一定会成功。',
      difficultyScore: 3,
      zoneType: 'comfort',
      completionQuestion: '这次行动增加了什么新证据？',
      actionType: 'process',
      experienceIntention: map.alternativeBelief,
    );
    _beliefCtrl.clear();
    _evidenceCtrl.clear();
    await _load();
    await widget.onDataChanged();
    if (mounted) setState(() => _saving = false);
    _show('信念已转成现实检查和 5–15 分钟行动，并加入“山路行动”。');
  }

  Future<void> _saveCheckIn() async {
    if (_realityCtrl.text.trim().isEmpty || _possibilityCtrl.text.trim().isEmpty) {
      _show('请同时写下需要面对的现实和仍愿意相信的可能性。');
      return;
    }
    await widget.dao.addRaiseBaseCheckIn(
      goalId: _goalId,
      realityText: _realityCtrl.text,
      possibilityText: _possibilityCtrl.text,
      moodScore: _mood,
      copingScore: _coping,
      selfEfficacyScore: _efficacy,
      evidenceText: _proofCtrl.text,
    );
    _realityCtrl.clear();
    _possibilityCtrl.clear();
    _proofCtrl.clear();
    await _load();
    _show('已更新幸福基线；系统记录的是应对与行动证据，不只是一时心情。');
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final snapshot = _engine.buildSnapshot(
      steps: widget.todaySteps,
      reflections: widget.reflections,
      failures: _failures,
      checkIns: _checkIns,
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        children: [
          _hero(snapshot),
          const SizedBox(height: 12),
          _dailyLoop(snapshot),
          const SizedBox(height: 12),
          _beliefStudio(),
          if (_maps.isNotEmpty) ...[
            const SizedBox(height: 12),
            _beliefResult(_maps.first),
          ],
          const SizedBox(height: 12),
          _baselineCheckIn(),
          const SizedBox(height: 12),
          _sevenDayPath(),
          const SizedBox(height: 12),
          _trainingLabs(),
          const SizedBox(height: 12),
          _safetyCard(),
        ],
      ),
    );
  }

  Widget _hero(TodoRaiseBaseSnapshot snapshot) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF433879), Color(0xFF7768C5)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('RaiseBase · 向上基线', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          const Text('现实乐观地看见可能性，用行动制造证据，用失败更新策略。', style: TextStyle(color: Color(0xFFEDEAFF), height: 1.45)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _metric('情绪基线', snapshot.moodBaseline, Icons.favorite_outline)),
            const SizedBox(width: 8),
            Expanded(child: _metric('应对指数', snapshot.copingIndex, Icons.shield_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _metric('自我效能', snapshot.selfEfficacy, Icons.trending_up)),
          ]),
        ]),
      );

  Widget _metric(String label, int value, IconData icon) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 19),
          const SizedBox(height: 5),
          Text(value == 0 ? '待记录' : '$value', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Color(0xFFEDEAFF), fontSize: 11)),
        ]),
      );

  Widget _dailyLoop(TodoRaiseBaseSnapshot snapshot) => _card(
        title: '今日现实乐观闭环',
        subtitle: 'AI 的角色是现实镜子、乐观翻译器、行动拆解师和证据记录员。',
        child: Column(children: [
          _promptLine('1', '诚实面对', _checkIns.isEmpty ? '今天你要诚实面对什么现实？' : _checkIns.first.realityText),
          _promptLine('2', '保留可能', _checkIns.isEmpty ? '今天你仍选择相信什么可能性？' : _checkIns.first.possibilityText),
          _promptLine('3', '最小行动', widget.todaySteps.where((e) => !e.isCompleted).isEmpty ? '创建一个 5–15 分钟动作，而不是等待完整方案。' : widget.todaySteps.firstWhere((e) => !e.isCompleted).title),
          _promptLine('4', '行动证据', snapshot.evidence.isEmpty ? '完成后，系统会把行动提炼成“我能做到”的证据。' : snapshot.evidence.first),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: widget.onOpenActions, icon: const Icon(Icons.play_arrow), label: const Text('开始最小行动'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: widget.onOpenFailure, icon: const Icon(Icons.replay), label: const Text('把不顺变反馈'))),
          ]),
        ]),
      );

  Widget _beliefStudio() => _card(
        title: 'AI 信念地图 → 行动阶梯',
        subtitle: '不把信念当魔法：先分开事实与预测，再自动生成一个可同步、可完成、可复盘的行动。',
        child: Column(children: [
          if (widget.goals.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _goalId.isEmpty ? widget.goals.first.goalId : _goalId,
              decoration: const InputDecoration(labelText: '关联现有目标', border: OutlineInputBorder()),
              items: widget.goals.map((goal) => DropdownMenuItem(value: goal.goalId, child: Text(goal.goalTitle, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (value) => setState(() => _goalId = value ?? ''),
            ),
          const SizedBox(height: 10),
          TextField(controller: _beliefCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '当前限制性信念', hintText: '例如：我不够优秀，所以不该尝试', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _evidenceCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '已知的现实依据（不是预测）', hintText: '例如：目前作品少、项目表达准备不足', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _createBeliefMap, icon: const Icon(Icons.account_tree_outlined), label: Text(_saving ? '正在生成...' : '生成信念地图并加入今日行动'))),
        ]),
      );

  Widget _beliefResult(TodoRaiseBaseBeliefMap map) => _card(
        title: '最近一张信念地图',
        subtitle: map.goalTitle,
        child: Column(children: [
          _mapLine('限制性信念', map.limitingBelief, Colors.red.shade700),
          _mapLine('现实依据', map.realityEvidence, Colors.blueGrey.shade700),
          _mapLine('可能夸大', map.exaggeratedPart, Colors.orange.shade800),
          _mapLine('替代信念', map.alternativeBelief, _green),
          _mapLine('今日行动', map.minimumAction, _purple),
          _mapLine('环境启动', map.environmentCue, _green),
          _mapLine('障碍预案', map.obstaclePlan, Colors.blueGrey.shade700),
        ]),
      );

  Widget _baselineCheckIn() => _card(
        title: '幸福基线签到',
        subtitle: '幸福不是每天都开心，而是遇到困难后越来越能恢复、行动并积累证据。',
        child: Column(children: [
          TextField(controller: _realityCtrl, decoration: const InputDecoration(labelText: '今天要诚实面对的现实', border: OutlineInputBorder())),
          const SizedBox(height: 9),
          TextField(controller: _possibilityCtrl, decoration: const InputDecoration(labelText: '今天仍愿意相信的可能性', border: OutlineInputBorder())),
          const SizedBox(height: 9),
          TextField(controller: _proofCtrl, decoration: const InputDecoration(labelText: '今天已有的行动证据（可稍后补）', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          _score('情绪感受', _mood, (v) => setState(() => _mood = v)),
          _score('困难后行动', _coping, (v) => setState(() => _coping = v)),
          _score('我能做到感', _efficacy, (v) => setState(() => _efficacy = v)),
          SizedBox(width: double.infinity, child: FilledButton.tonalIcon(onPressed: _saveCheckIn, icon: const Icon(Icons.insights), label: const Text('更新三条基线'))),
        ]),
      );

  Widget _sevenDayPath() {
    const items = [
      ('Day 1', '识别信念', '写下一条限制性信念，并区分事实与预测'),
      ('Day 2', '看见潜能', '找出一个被忽略的优势或过去证据'),
      ('Day 3', '微行动', '完成一个 5–15 分钟行动'),
      ('Day 4', '失败复盘', '把一次不顺改写为具体、暂时、可学习'),
      ('Day 5', '环境启动', '移除一个阻力，增加一个视觉线索'),
      ('Day 6', '过程可视化', '想象结果、过程、障碍与应对'),
      ('Day 7', '证据报告', '总结本周行动、恢复和自我效能证据'),
    ];
    return _card(
      title: '7 天现实乐观训练路径',
      subtitle: '训练嵌在现有目标、行动、失败复盘和周总结里，不另造一套打卡负担。',
      child: Column(children: items.map((item) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: const Color(0xFFEDEAFF), child: Text(item.$1.substring(4), style: const TextStyle(color: _purple, fontWeight: FontWeight.w900))), title: Text('${item.$1} · ${item.$2}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(item.$3))).toList()),
    );
  }

  Widget _trainingLabs() => _card(
        title: '增强训练实验室',
        subtitle: '围绕同一个目标按需调用，不替代 todo 主流程。',
        child: Column(children: [
          _lab(Icons.tune, 'Priming Studio · 环境启动', '桌面只保留工具；设置固定启动线索；把手机移出触手范围。'),
          _lab(Icons.visibility_outlined, 'Visualization Lab · 过程可视化', '依次想象结果、每日过程、最可能障碍，以及“如果发生，就做 5 分钟”的应对。'),
          _lab(Icons.psychology_alt_outlined, 'CBT Lite · ABCDE', '事件 → 自动解释 → 情绪/行动后果 → 证据反驳 → 更现实的新信念。'),
          _lab(Icons.people_alt_outlined, 'Relationship Pygmalion · 潜能视角', '把“你怎么又……”改成高期待 + 具体支持：我相信你能成长，我们先拆第一步。'),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: widget.onOpenReview, icon: const Icon(Icons.edit_note), label: const Text('进入结构化过程复盘'))),
        ]),
      );

  Widget _safetyCard() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFFFFF7E8), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFFFD89A))),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.health_and_safety_outlined, color: Color(0xFF9A5D00)),
          SizedBox(width: 10),
          Expanded(child: Text('安全边界：本功能是日常思维与行动训练，不是医疗诊断或心理治疗。若出现自伤想法、极端绝望或危机状态，请停止普通教练训练，并立即联系当地紧急服务、危机热线或可信任的专业人士。', style: TextStyle(height: 1.45, color: Color(0xFF704A10)))),
        ]),
      );

  Widget _card({required String title, required String subtitle, required Widget child}) => Card(
        elevation: 0,
        color: const Color(0xFFFAF9FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE7E2F5))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF292342))),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Color(0xFF666174), height: 1.4)),
            const SizedBox(height: 14),
            child,
          ]),
        ),
      );

  Widget _promptLine(String number, String title, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 13, backgroundColor: const Color(0xFFEDEAFF), child: Text(number, style: const TextStyle(color: _purple, fontWeight: FontWeight.w900))),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), Text(text, style: const TextStyle(height: 1.35, color: Color(0xFF55505F)))])),
        ]),
      );

  Widget _mapLine(String label, String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 76, child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900))),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ]),
      );

  Widget _score(String label, int value, ValueChanged<int> onChanged) => Row(children: [
        SizedBox(width: 92, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(child: Slider(value: value.toDouble(), min: 1, max: 5, divisions: 4, label: '$value', onChanged: (v) => onChanged(v.round()))),
        Text('$value/5'),
      ]);

  Widget _lab(IconData icon, String title, String body) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: const Color(0xFFE9F4F0), child: Icon(icon, color: _green)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(body, style: const TextStyle(height: 1.35)),
      );
}
