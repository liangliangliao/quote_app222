import 'package:flutter/material.dart';

import 'james_will_training_complete_ai_service.dart';
import 'james_will_training_complete_dao.dart';
import 'james_will_training_complete_models.dart';
import 'james_will_training_dao.dart';
import 'james_will_training_models.dart';
import 'james_will_training_stage3_page.dart';

const _completePurple = Color(0xFF5B4B8A);
const _completeBg = Color(0xFFF6F3FF);
const _completeInk = Color(0xFF26233A);

class JamesWillCompleteLandingPage extends StatefulWidget {
  const JamesWillCompleteLandingPage({super.key});

  @override
  State<JamesWillCompleteLandingPage> createState() => _JamesWillCompleteLandingPageState();
}

class _JamesWillCompleteLandingPageState extends State<JamesWillCompleteLandingPage> {
  final _baseDao = JamesWillTrainingDao();
  final _completeDao = JamesWillTrainingCompleteDao();
  final _completeAi = JamesWillTrainingCompleteAiService();

  List<JamesWillActionIdea> _ideas = const <JamesWillActionIdea>[];
  List<JamesWillLog> _logs = const <JamesWillLog>[];
  List<JamesWillHabit> _habits = const <JamesWillHabit>[];
  List<JamesWillWeeklyReport> _reports = const <JamesWillWeeklyReport>[];
  Map<String, int> _baseStats = const <String, int>{};
  Map<String, int> _completeStats = const <String, int>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _baseDao.ensureTables();
    await _completeDao.ensureTables();
    final ideas = await _baseDao.listActionIdeas(limit: 100);
    final logs = await _baseDao.listLogs(limit: 200);
    final habits = await _completeDao.listHabits(limit: 100);
    final reports = await _completeDao.listWeeklyReports(limit: 8);
    final baseStats = await _baseDao.stats();
    final completeStats = await _completeDao.completeStats();
    if (!mounted) return;
    setState(() {
      _ideas = ideas;
      _logs = logs;
      _habits = habits;
      _reports = reports;
      _baseStats = baseStats;
      _completeStats = completeStats;
    });
  }

  Future<void> _generateWeeklyReport() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final report = await _completeAi.generateWeeklyReport(_logs, _ideas);
      await _completeDao.saveWeeklyReport(report);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('已生成每周意志报告。')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('生成周报失败：$e'), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmt(int ms) {
    if (ms <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final level = JamesWillGrowthLevel.fromLogs(_logs);
    final completed = _logs.where((e) => e.completed).length;
    final avgEffort = _logs.isEmpty ? 0 : (_logs.fold<int>(0, (sum, e) => sum + e.effortAttentionScore) / _logs.length).round();
    final recoveries = _logs.fold<int>(0, (sum, e) => sum + e.attentionRecoveryCount);
    return Scaffold(
      backgroundColor: _completeBg,
      appBar: AppBar(
        title: const Text('足下意志 · 完整落地中心'),
        actions: [
          IconButton(onPressed: _busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JamesWillPromptConfigPage())), icon: const Icon(Icons.tune), tooltip: '提示词配置'),
          IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _CompleteHeroCard(
                baseStats: _baseStats,
                completeStats: _completeStats,
                level: level,
                avgEffort: avgEffort,
                recoveries: recoveries,
              ),
              const SizedBox(height: 14),
              _CompleteSectionTitle('意志教育成长体系'),
              const SizedBox(height: 10),
              _GrowthLevelCard(level: level, logs: _logs),
              const SizedBox(height: 16),
              _CompleteSectionTitle('个人意志画像'),
              const SizedBox(height: 10),
              _ProfileCard(total: _logs.length, completed: completed, avgEffort: avgEffort, recoveries: recoveries, habits: _habits.length),
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(onPressed: _busy ? null : _generateWeeklyReport, icon: const Icon(Icons.summarize_outlined), label: const Text('生成每周报告')),
                OutlinedButton.icon(onPressed: _busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JamesWillStage3CenterPage())).then((_) => _load()), icon: const Icon(Icons.account_tree_outlined), label: const Text('第三阶段深化')),
                OutlinedButton.icon(onPressed: _busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JamesWillPromptConfigPage())), icon: const Icon(Icons.tune), label: const Text('AI提示词配置')),
              ]),
              const SizedBox(height: 16),
              _CompleteSectionTitle('习惯建筑师'),
              const SizedBox(height: 10),
              if (_habits.isEmpty)
                const _CompleteInfo(lines: ['还没有习惯。进入任意行动观念卡，在“习惯建筑师”中把行动固定为触发条件、地点、第一动作和失败恢复方案。'])
              else
                ..._habits.map((h) => _HabitCard(habit: h, compact: false)),
              const SizedBox(height: 16),
              _CompleteSectionTitle('每周意志报告'),
              const SizedBox(height: 10),
              if (_reports.isEmpty)
                const _CompleteInfo(lines: ['还没有每周报告。点击上方按钮，AI 会基于行动日志总结主导观念、阻碍模式、努力性注意和下周7天实验。'])
              else
                ..._reports.map((r) => _WeeklyReportCard(report: r, dateLabel: '${_fmt(r.fromMs)} 至 ${_fmt(r.toMs)}')),
              const SizedBox(height: 16),
              _CompleteSectionTitle('完整落地覆盖清单'),
              const SizedBox(height: 10),
              const _CompleteChecklist(),
            ],
          ),
          if (_busy) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.05), child: const Center(child: CircularProgressIndicator()))),
        ],
      ),
    );
  }
}

class JamesWillIdeaCompleteSections extends StatefulWidget {
  const JamesWillIdeaCompleteSections({super.key, required this.idea, required this.logs, required this.decisions, required this.onChanged});
  final JamesWillActionIdea idea;
  final List<JamesWillLog> logs;
  final List<JamesWillDecision> decisions;
  final Future<void> Function() onChanged;

  @override
  State<JamesWillIdeaCompleteSections> createState() => _JamesWillIdeaCompleteSectionsState();
}

class _JamesWillIdeaCompleteSectionsState extends State<JamesWillIdeaCompleteSections> {
  final _dao = JamesWillTrainingCompleteDao();
  JamesWillHabit? _habit;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant JamesWillIdeaCompleteSections oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idea.id != widget.idea.id) _load();
  }

  Future<void> _load() async {
    await _dao.ensureTables();
    final habit = await _dao.activeHabitForIdea(widget.idea.id);
    if (!mounted) return;
    setState(() => _habit = habit);
  }

  Future<void> _createOrUpgradeHabit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final current = _habit;
      final habit = current == null ? JamesWillHabit.fromIdea(widget.idea) : current.copyWith(level: current.level + 1);
      await _dao.saveHabit(habit);
      await _load();
      await widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(current == null ? '已创建习惯结构。' : '已提升习惯等级。')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('习惯保存失败：$e'), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final control = JamesWillControlSplit.fromIdea(widget.idea);
    final pleasurePain = JamesWillPleasurePainSplit.fromIdea(widget.idea);
    final level = JamesWillGrowthLevel.fromLogs(widget.logs);
    final activeDecision = widget.decisions.where((e) => e.sealedUntilMs > DateTime.now().millisecondsSinceEpoch).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CompleteSectionTitle('第二阶段：完整落地模块'),
        const SizedBox(height: 10),
        _PleasurePainCard(split: pleasurePain),
        const SizedBox(height: 10),
        _ControlSplitCard(split: control),
        const SizedBox(height: 10),
        _ObstacleLibraryCard(idea: widget.idea),
        const SizedBox(height: 10),
        _GrowthLevelCard(level: level, logs: widget.logs),
        const SizedBox(height: 10),
        _DecisionLockCard(decisions: activeDecision),
        const SizedBox(height: 10),
        _HabitBuilderCard(habit: _habit, idea: widget.idea, busy: _busy, onCreateOrUpgrade: _createOrUpgradeHabit),
        const SizedBox(height: 10),
        const _VoiceGuideTextCard(),
      ],
    );
  }
}

class JamesWillPromptConfigPage extends StatefulWidget {
  const JamesWillPromptConfigPage({super.key});

  @override
  State<JamesWillPromptConfigPage> createState() => _JamesWillPromptConfigPageState();
}

class _JamesWillPromptConfigPageState extends State<JamesWillPromptConfigPage> {
  final _dao = JamesWillTrainingCompleteDao();
  List<JamesWillPromptConfig> _configs = const <JamesWillPromptConfig>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _dao.ensureTables();
    final configs = await _dao.listPromptConfigs();
    if (!mounted) return;
    setState(() => _configs = configs);
  }

  Future<void> _edit(JamesWillPromptConfig config) async {
    final ctrl = TextEditingController(text: config.prompt);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(config.title),
          content: TextField(controller: ctrl, minLines: 6, maxLines: 12, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '提示词内容（支持 {{goal}}、{{actionIdea}} 等占位符）')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
          ],
        ),
      );
      if (ok != true) return;
      setState(() => _busy = true);
      await _dao.savePromptConfig(JamesWillPromptConfig(key: config.key, title: config.title, prompt: ctrl.text.trim(), updatedAtMs: DateTime.now().millisecondsSinceEpoch));
      await _load();
    } finally {
      ctrl.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _completeBg,
      appBar: AppBar(title: const Text('足下意志 · AI提示词配置')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _CompleteInfo(lines: ['这里可配置本模块所有 AI 提示词，包括统一核心背景、行动观念、决定分析、复盘、周报、语音拉回、7天实验、冲动冷却、价值地图和完整实践流程。AI 必须提供结构、判断、案例和多种可能，最终让用户自己选择。']),
              const SizedBox(height: 12),
              ..._configs.map((config) => Card(
                    child: ListTile(
                      title: Text(config.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(config.prompt, maxLines: 3, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(config),
                    ),
                  )),
            ],
          ),
          if (_busy) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.05), child: const Center(child: CircularProgressIndicator()))),
        ],
      ),
    );
  }
}

class _CompleteHeroCard extends StatelessWidget {
  const _CompleteHeroCard({required this.baseStats, required this.completeStats, required this.level, required this.avgEffort, required this.recoveries});
  final Map<String, int> baseStats;
  final Map<String, int> completeStats;
  final JamesWillGrowthLevel level;
  final int avgEffort;
  final int recoveries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF5B4B8A), Color(0xFF9277D9)]), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 10))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('第二阶段：完整落地', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('补齐：阻碍观念库、短期舒服/长期价值、可控域、注意力指标、习惯建筑、成长等级、每周报告、提示词配置、语音拉回。', style: TextStyle(color: Colors.white, height: 1.5)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _HeroPill(label: '成长等级', value: level.title),
          _HeroPill(label: '平均努力', value: '$avgEffort'),
          _HeroPill(label: '拉回次数', value: '$recoveries'),
          _HeroPill(label: '习惯', value: '${completeStats['habits'] ?? 0}'),
          _HeroPill(label: '报告', value: '${completeStats['reports'] ?? 0}'),
          _HeroPill(label: '日志', value: '${baseStats['logs'] ?? 0}'),
        ]),
      ]),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
      child: Text('$label：$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.total, required this.completed, required this.avgEffort, required this.recoveries, required this.habits});
  final int total;
  final int completed;
  final int avgEffort;
  final int recoveries;
  final int habits;

  @override
  Widget build(BuildContext context) {
    final rate = total == 0 ? 0 : (completed * 100 / total).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('不是评价人格，而是识别你的行动结构。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
          const SizedBox(height: 10),
          _KV(label: '行动记录', value: '$total 次'),
          _KV(label: '完成率', value: '$rate%'),
          _KV(label: '平均努力性注意', value: '$avgEffort/100'),
          _KV(label: '分心拉回', value: '$recoveries 次'),
          _KV(label: '习惯结构', value: '$habits 个'),
          const SizedBox(height: 8),
          Text(total == 0 ? '下一步：先生成一张行动观念卡，并完成一次 5 分钟启动。' : '下一步：把最稳定的行动绑定固定触发条件、地点和第一身体动作。', style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _CompleteChecklist extends StatelessWidget {
  const _CompleteChecklist();

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      'P0：目标→行动观念、观念竞争、五分钟启动、决定分析、决定封存、意志复盘。',
      'P1：阻碍观念库、快乐/痛苦动力分析、可控域拆解、注意力指标、习惯等级、每周报告、提示词配置。',
      'P2：语音式注意力拉回文案、个人意志画像、观念趋势、长期价值地图、7天行动实验、冲动决定冷却机制。',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: items.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_outline, color: _completePurple), const SizedBox(width: 8), Expanded(child: Text(e, style: const TextStyle(height: 1.45)))]))).toList()),
      ),
    );
  }
}

class _PleasurePainCard extends StatelessWidget {
  const _PleasurePainCard({required this.split});
  final JamesWillPleasurePainSplit split;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('短期舒服 vs 长期力量', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _completeInk)),
          const SizedBox(height: 8),
          _KV(label: '短期舒服', value: split.shortComfort),
          _KV(label: '长期代价', value: split.longCost),
          _KV(label: '开始痛苦', value: split.shortPain),
          _KV(label: '长期力量', value: split.longPower),
          _KV(label: '最小必要痛苦', value: split.minimalNecessaryPain),
        ]),
      ),
    );
  }
}

class _ControlSplitCard extends StatelessWidget {
  const _ControlSplitCard({required this.split});
  final JamesWillControlSplit split;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('可控域 / 不可控域', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _completeInk)),
          const SizedBox(height: 8),
          const Text('意志不是控制世界，而是控制此刻可执行的下一步。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
          const SizedBox(height: 10),
          const Text('不可直接控制', style: TextStyle(fontWeight: FontWeight.w900)),
          ...split.uncontrollable.map((e) => _Bullet(e)),
          const SizedBox(height: 8),
          const Text('现在可控制', style: TextStyle(fontWeight: FontWeight.w900)),
          ...split.controllable.map((e) => _Bullet(e)),
        ]),
      ),
    );
  }
}

class _ObstacleLibraryCard extends StatelessWidget {
  const _ObstacleLibraryCard({required this.idea});
  final JamesWillActionIdea idea;

  @override
  Widget build(BuildContext context) {
    final interventions = JamesWillObstacleIntervention.defaultsFor(idea).take(8).toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('阻碍观念干预库', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _completeInk)),
          const SizedBox(height: 8),
          ...interventions.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.obstacle, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('本质：${item.nature}', style: const TextStyle(color: Color(0xFF6B7280), height: 1.35)),
                    Text('替代观念：${item.replacement}', style: const TextStyle(height: 1.35)),
                    Text('第一动作：${item.firstAction}', style: const TextStyle(height: 1.35)),
                  ]),
                ),
              )),
        ]),
      ),
    );
  }
}

class _DecisionLockCard extends StatelessWidget {
  const _DecisionLockCard({required this.decisions});
  final List<JamesWillDecision> decisions;

  @override
  Widget build(BuildContext context) {
    if (decisions.isEmpty) {
      return const _CompleteInfo(lines: ['冲动/犹豫处理：如果还没有决定封存，遇到重大选择先做决定分析。决定前允许权衡；决定后进入执行期；复盘日再重新判断。']);
    }
    final d = decisions.first;
    final days = DateTime.fromMillisecondsSinceEpoch(d.sealedUntilMs).difference(DateTime.now()).inDays.clamp(0, 999).toInt();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('决定封存 / 冲动冷却', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _completeInk)),
          const SizedBox(height: 8),
          _KV(label: '当前决定', value: d.question),
          _KV(label: '封存剩余', value: '$days 天'),
          _KV(label: '执行原则', value: '执行期内不重新审判决定，只优化行动；确有重大新信息才提前重评。'),
        ]),
      ),
    );
  }
}

class _HabitBuilderCard extends StatelessWidget {
  const _HabitBuilderCard({required this.habit, required this.idea, required this.busy, required this.onCreateOrUpgrade});
  final JamesWillHabit? habit;
  final JamesWillActionIdea idea;
  final bool busy;
  final VoidCallback onCreateOrUpgrade;

  @override
  Widget build(BuildContext context) {
    final h = habit;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('习惯建筑师', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _completeInk)),
          const SizedBox(height: 8),
          if (h == null) ...[
            _KV(label: '触发条件', value: '固定提醒时间到达时'),
            _KV(label: '地点', value: '行动发生的固定地点'),
            _KV(label: '第一动作', value: idea.firstBodyAction),
            _KV(label: '最低版本', value: idea.minimumAction),
            _KV(label: '失败恢复', value: idea.fiveMinuteVersion),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : onCreateOrUpgrade, icon: const Icon(Icons.add_task), label: const Text('创建习惯结构'))),
          ] else ...[
            _HabitCard(habit: h, compact: true),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : onCreateOrUpgrade, icon: const Icon(Icons.trending_up), label: const Text('提升习惯等级'))),
          ],
        ]),
      ),
    );
  }
}

class _VoiceGuideTextCard extends StatelessWidget {
  const _VoiceGuideTextCard();

  @override
  Widget build(BuildContext context) {
    return const _CompleteInfo(lines: ['语音式注意力拉回已接入“五分钟启动器”：当你分心或想放弃时，可以生成并朗读 30 秒拉回文案，把行动观念重新放回意识中心。']);
  }
}

class _GrowthLevelCard extends StatelessWidget {
  const _GrowthLevelCard({required this.level, required this.logs});
  final JamesWillGrowthLevel level;
  final List<JamesWillLog> logs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(backgroundColor: const Color(0xFFEDE9FE), child: Text('${level.level}', style: const TextStyle(color: _completePurple, fontWeight: FontWeight.w900))),
            const SizedBox(width: 10),
            Expanded(child: Text(level.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _completeInk))),
          ]),
          const SizedBox(height: 8),
          Text(level.description, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 8),
          _KV(label: '日志数量', value: '${logs.length} 次'),
          _KV(label: '下一训练', value: level.nextTraining),
        ]),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habit, required this.compact});
  final JamesWillHabit habit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: compact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${habit.name} · L${habit.level}', style: const TextStyle(fontWeight: FontWeight.w900, color: _completeInk)),
          const SizedBox(height: 6),
          _KV(label: '触发', value: habit.trigger),
          _KV(label: '地点', value: habit.place),
          _KV(label: '第一动作', value: habit.firstBodyAction),
          _KV(label: '最低版本', value: habit.minimumVersion),
          _KV(label: '失败恢复', value: habit.fallbackVersion),
        ]),
      ),
    );
  }
}

class _WeeklyReportCard extends StatelessWidget {
  const _WeeklyReportCard({required this.report, required this.dateLabel});
  final JamesWillWeeklyReport report;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(dateLabel, style: const TextStyle(fontWeight: FontWeight.w900, color: _completeInk)),
          const SizedBox(height: 8),
          _KV(label: '完成/记录', value: '${report.completedCount}/${report.totalLogs}'),
          _KV(label: '平均努力', value: report.averageEffort.toStringAsFixed(0)),
          _KV(label: '主要阻碍', value: report.dominantObstacle),
          _KV(label: '有效观念', value: report.bestActionIdea),
          _KV(label: '成长等级', value: report.growthLevel),
          const SizedBox(height: 8),
          Text(report.summary, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 8),
          Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)), child: Text('下周实验：${report.nextExperiment}', style: const TextStyle(height: 1.45))),
        ]),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('•  '), Expanded(child: Text(text, style: const TextStyle(height: 1.35)))]),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 94, child: Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700))),
        Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(height: 1.35))),
      ]),
    );
  }
}

class _CompleteSectionTitle extends StatelessWidget {
  const _CompleteSectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _completeInk));
}

class _CompleteInfo extends StatelessWidget {
  const _CompleteInfo({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines.map((e) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(e, style: const TextStyle(height: 1.45, color: Color(0xFF4B5563))))).toList()),
      ),
    );
  }
}
