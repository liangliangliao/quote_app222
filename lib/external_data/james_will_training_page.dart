import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'james_will_training_ai_service.dart';
import 'james_will_training_complete_ai_service.dart';
import 'james_will_training_complete_page.dart';
import 'james_will_training_dao.dart';
import 'james_will_training_models.dart';
import 'james_will_training_practice_dao.dart';
import 'james_will_training_practice_page.dart';
import 'james_will_training_stage3_page.dart';

const _willPurple = Color(0xFF5B4B8A);
const _willBg = Color(0xFFF6F3FF);
const _willInk = Color(0xFF26233A);

class JamesWillTrainingHomePage extends StatefulWidget {
  const JamesWillTrainingHomePage({super.key});

  @override
  State<JamesWillTrainingHomePage> createState() => _JamesWillTrainingHomePageState();
}

class _JamesWillTrainingHomePageState extends State<JamesWillTrainingHomePage> {
  final _dao = JamesWillTrainingDao();
  final _ai = JamesWillTrainingAiService();
  final _goalCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _busy = false;
  String _status = '';
  List<JamesWillActionIdea> _ideas = const <JamesWillActionIdea>[];
  List<JamesWillLog> _recentLogs = const <JamesWillLog>[];
  Map<String, int> _stats = const <String, int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _goalCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _dao.ensureTables();
    await JamesWillTrainingPracticeDao().ensureTables();
    final ideas = await _dao.listActionIdeas(limit: 30);
    final logs = await _dao.listLogs(limit: 8);
    final stats = await _dao.stats();
    if (!mounted) return;
    setState(() {
      _ideas = ideas;
      _recentLogs = logs;
      _stats = stats;
    });
  }

  void _show(String message, {bool error = false}) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  Future<void> _createActionIdea() async {
    final goal = _goalCtrl.text.trim();
    if (goal.isEmpty) {
      _show('请先输入一个目标、愿望或行动困难。', error: true);
      return;
    }
    setState(() {
      _busy = true;
      _status = '正在生成行动观念训练卡...';
    });
    try {
      final idea = await _ai.generateActionIdea(goal: goal, note: _noteCtrl.text.trim());
      await _dao.upsertActionIdea(idea);
      _goalCtrl.clear();
      _noteCtrl.clear();
      await _load();
      if (!mounted) return;
      _show(idea.aiUsedFallback ? '已生成本地行动观念卡。配置全局 AI 后可获得更个性化分析。' : 'AI 已生成行动观念卡。');
      await Navigator.push(context, MaterialPageRoute(builder: (_) => JamesWillActionIdeaDetailPage(ideaId: idea.id)));
      if (mounted) await _load();
    } catch (e) {
      _show('生成失败：$e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = '';
        });
      }
    }
  }

  Future<void> _openIdea(JamesWillActionIdea idea) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => JamesWillActionIdeaDetailPage(ideaId: idea.id)));
    if (mounted) await _load();
  }

  String _fmt(int ms) {
    if (ms <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.month}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _willBg,
      appBar: AppBar(
        title: const Text('足下意志 · 行动观念训练'),
        actions: [IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _HeroPanel(stats: _stats),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(onPressed: _busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JamesWillCompleteLandingPage())).then((_) => _load()), icon: const Icon(Icons.dashboard_customize_outlined), label: const Text('完整落地中心')),
                  OutlinedButton.icon(onPressed: _busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JamesWillStage3CenterPage())).then((_) => _load()), icon: const Icon(Icons.account_tree_outlined), label: const Text('第三阶段深化')),
                  OutlinedButton.icon(onPressed: _busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JamesWillPromptConfigPage())), icon: const Icon(Icons.tune), label: const Text('提示词配置')),
                ],
              ),
              const SizedBox(height: 14),
              _InputPanel(
                goalCtrl: _goalCtrl,
                noteCtrl: _noteCtrl,
                busy: _busy,
                onCreate: _createActionIdea,
              ),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_status, style: const TextStyle(color: Color(0xFF6B7280))),
              ],
              const SizedBox(height: 18),
              const _SectionTitle('行动观念卡'),
              const SizedBox(height: 10),
              if (_ideas.isEmpty)
                const _EmptyPanel()
              else
                ..._ideas.map((idea) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ActionIdeaTile(idea: idea, onTap: () => _openIdea(idea)),
                    )),
              const SizedBox(height: 18),
              const _SectionTitle('最近意志日志'),
              const SizedBox(height: 10),
              if (_recentLogs.isEmpty)
                const _InfoPanel(lines: ['还没有行动日志。先生成一张行动观念卡，再进入“五分钟启动器”。'])
              else
                ..._recentLogs.map((log) => _LogTile(log: log, timeLabel: _fmt(log.createdAtMs))),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: Container(
                  color: Colors.black.withOpacity(0.05),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class JamesWillActionIdeaDetailPage extends StatefulWidget {
  const JamesWillActionIdeaDetailPage({super.key, required this.ideaId});
  final String ideaId;

  @override
  State<JamesWillActionIdeaDetailPage> createState() => _JamesWillActionIdeaDetailPageState();
}

class _JamesWillActionIdeaDetailPageState extends State<JamesWillActionIdeaDetailPage> {
  final _dao = JamesWillTrainingDao();
  final _ai = JamesWillTrainingAiService();
  JamesWillActionIdea? _idea;
  List<JamesWillDecision> _decisions = const <JamesWillDecision>[];
  List<JamesWillLog> _logs = const <JamesWillLog>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final idea = await _dao.getActionIdea(widget.ideaId);
    if (idea == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final decisions = await _dao.listDecisions(widget.ideaId);
    final logs = await _dao.listLogs(ideaId: widget.ideaId, limit: 30);
    if (!mounted) return;
    setState(() {
      _idea = idea;
      _decisions = decisions;
      _logs = logs;
    });
  }

  void _show(String message, {bool error = false}) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  Future<void> _refreshActionIdea() async {
    final idea = _idea;
    if (idea == null || _busy) return;
    setState(() => _busy = true);
    try {
      final updated = await _ai.generateActionIdea(goal: idea.originalGoal, note: idea.goalNote);
      await _dao.upsertActionIdea(updated);
      await _load();
      _show(updated.aiUsedFallback ? '已刷新为本地行动观念卡。' : 'AI 已刷新行动观念卡。');
    } catch (e) {
      _show('刷新失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openStarter() async {
    final idea = _idea;
    if (idea == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => JamesWillFiveMinuteStarterPage(idea: idea)));
    if (mounted) await _load();
  }

  Future<void> _openPracticeFlow() async {
    final idea = _idea;
    if (idea == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => JamesWillPracticeFlowPage(idea: idea)));
    if (mounted) await _load();
  }

  Future<void> _analyzeDecision() async {
    final idea = _idea;
    if (idea == null || _busy) return;
    final ctrl = TextEditingController(text: '我要不要继续执行这个行动？');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('詹姆斯式决定分析'),
          content: TextField(
            controller: ctrl,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: '你正在犹豫什么？', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('开始分析')),
          ],
        ),
      );
      if (ok != true || ctrl.text.trim().isEmpty) return;
      setState(() => _busy = true);
      final decision = await _ai.analyzeDecision(idea: idea, question: ctrl.text.trim());
      await _dao.saveDecision(decision);
      await _load();
      _show('已保存决定分析，并进入封存/实验执行视角。');
    } catch (e) {
      _show('决定分析失败：$e', error: true);
    } finally {
      ctrl.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordReview() async {
    final idea = _idea;
    if (idea == null || _busy) return;
    final obstacle = TextEditingController(text: idea.obstacleIdeas.isEmpty ? '' : idea.obstacleIdeas.first);
    final dominant = TextEditingController(text: idea.fiveMinuteVersion);
    final reflection = TextEditingController();
    var completed = true;
    var recoveries = 0;
    var startDelay = 0;
    var effort = 70;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: const Text('意志复盘'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: completed,
                    title: const Text('这次行动已完成'),
                    onChanged: (v) => setLocalState(() => completed = v ?? true),
                  ),
                  TextField(controller: obstacle, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '开始前最强阻碍观念', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: dominant, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '最终主导的行动观念', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  Row(children: [const Expanded(child: Text('分心后拉回次数')), Text('$recoveries')]),
                  Slider(value: recoveries.toDouble(), min: 0, max: 10, divisions: 10, onChanged: (v) => setLocalState(() => recoveries = v.round())),
                  Row(children: [const Expanded(child: Text('启动延迟分钟')), Text('$startDelay')]),
                  Slider(value: startDelay.toDouble(), min: 0, max: 60, divisions: 12, onChanged: (v) => setLocalState(() => startDelay = v.round())),
                  Row(children: [const Expanded(child: Text('努力性注意评分')), Text('$effort')]),
                  Slider(value: effort.toDouble(), min: 0, max: 100, divisions: 20, onChanged: (v) => setLocalState(() => effort = v.round())),
                  TextField(controller: reflection, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: '我看见了什么？下次如何降低启动难度？', border: OutlineInputBorder())),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存复盘')),
            ],
          ),
        ),
      );
      if (ok != true) return;
      setState(() => _busy = true);
      var log = JamesWillLog.create(
        ideaId: idea.id,
        completed: completed,
        beforeObstacle: obstacle.text,
        dominantActionIdea: dominant.text,
        attentionRecoveryCount: recoveries,
        startDelayMinutes: startDelay,
        effortAttentionScore: effort,
        reflection: reflection.text,
      );
      final summary = await _ai.summarizeReview(idea: idea, log: log);
      log = JamesWillLog.create(
        ideaId: idea.id,
        completed: completed,
        beforeObstacle: obstacle.text,
        dominantActionIdea: dominant.text,
        attentionRecoveryCount: recoveries,
        startDelayMinutes: startDelay,
        effortAttentionScore: effort,
        reflection: reflection.text,
        aiSummary: summary,
      );
      await _dao.saveLog(log);
      await _load();
      _show('已保存意志复盘。');
    } catch (e) {
      _show('保存复盘失败：$e', error: true);
    } finally {
      obstacle.dispose();
      dominant.dispose();
      reflection.dispose();
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
    final idea = _idea;
    if (idea == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: _willBg,
      appBar: AppBar(
        title: const Text('行动观念卡'),
        actions: [
          IconButton(onPressed: _busy ? null : _refreshActionIdea, icon: const Icon(Icons.auto_fix_high_outlined), tooltip: 'AI刷新'),
          IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _IdeaHeaderCard(idea: idea),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: FilledButton.icon(onPressed: _busy ? null : _openStarter, icon: const Icon(Icons.play_arrow), label: const Text('五分钟启动'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _analyzeDecision, icon: const Icon(Icons.balance_outlined), label: const Text('决定分析'))),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: _busy ? null : _openPracticeFlow, icon: const Icon(Icons.route_outlined), label: const Text('完整实践流程：由我选择实验')),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: _busy ? null : _recordReview, icon: const Icon(Icons.history_edu_outlined), label: const Text('手动记录一次意志复盘')),
              const SizedBox(height: 18),
              const _SectionTitle('核心业务逻辑：实践闭环'),
              const SizedBox(height: 10),
              const _InfoPanel(lines: [
                '完整流程不是“AI给答案→用户看结果”，而是：澄清真实需要 → AI打开多种可能 → 用户自己选择一条低风险实验 → 执行第一身体动作 → 记录实践经验 → 复盘调整。',
                '点击“完整实践流程”，可以把本行动观念推进为一个可选择、可承诺、可反馈的真实实践过程。',
              ]),
              const SizedBox(height: 18),
              const _SectionTitle('观念竞争面板'),
              const SizedBox(height: 10),
              _CompetitionPanel(items: idea.competitionItems),
              const SizedBox(height: 18),
              const _SectionTitle('第一身体动作预演'),
              const SizedBox(height: 10),
              _BodyRehearsalPanel(idea: idea),
              const SizedBox(height: 18),
              JamesWillIdeaCompleteSections(idea: idea, logs: _logs, decisions: _decisions, onChanged: _load),
              const SizedBox(height: 18),
              JamesWillStage3IdeaSections(idea: idea, logs: _logs, onChanged: _load),
              const SizedBox(height: 18),
              const _SectionTitle('决定封存 / 实验执行'),
              const SizedBox(height: 10),
              if (_decisions.isEmpty)
                const _InfoPanel(lines: ['还没有决定分析。点击上方“决定分析”，把无限犹豫变成 3-7 天实验决定。'])
              else
                ..._decisions.map((d) => _DecisionCard(decision: d, dateLabel: _fmt(d.sealedUntilMs))),
              const SizedBox(height: 18),
              const _SectionTitle('意志日志'),
              const SizedBox(height: 10),
              if (_logs.isEmpty)
                const _InfoPanel(lines: ['还没有复盘记录。完成一次五分钟启动后，这里会记录阻碍观念、主导观念、分心拉回和努力性注意。'])
              else
                ..._logs.map((log) => _LogTile(log: log, timeLabel: _fmt(log.createdAtMs))),
            ],
          ),
          if (_busy)
            Positioned.fill(child: Container(color: Colors.black.withOpacity(0.05), child: const Center(child: CircularProgressIndicator()))),
        ],
      ),
    );
  }
}

class JamesWillFiveMinuteStarterPage extends StatefulWidget {
  const JamesWillFiveMinuteStarterPage({super.key, required this.idea});
  final JamesWillActionIdea idea;

  @override
  State<JamesWillFiveMinuteStarterPage> createState() => _JamesWillFiveMinuteStarterPageState();
}

class _JamesWillFiveMinuteStarterPageState extends State<JamesWillFiveMinuteStarterPage> {
  final _dao = JamesWillTrainingDao();
  final _ai = JamesWillTrainingAiService();
  final _completeAi = JamesWillTrainingCompleteAiService();
  final FlutterTts _tts = FlutterTts();
  Timer? _timer;
  int _remaining = 5 * 60;
  int _recoveries = 0;
  int _startDelayMinutes = 0;
  bool _running = false;
  bool _saving = false;
  bool _speaking = false;
  String _coach = '当前只保留一个观念：我只做 5 分钟。';
  late final int _openedAtMs;

  @override
  void initState() {
    super.initState();
    _openedAtMs = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    super.dispose();
  }

  void _start() {
    if (_running) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _startDelayMinutes = ((now - _openedAtMs) / 60000).round();
    setState(() {
      _running = true;
      _coach = '很好。现在不评价状态，只执行第一身体动作：${widget.idea.firstBodyAction}';
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining <= 1) {
        timer.cancel();
        _finish(completed: true, reflection: '完成了五分钟启动。');
      } else {
        setState(() => _remaining -= 1);
      }
    });
  }

  Future<void> _finish({required bool completed, required String reflection}) async {
    if (_saving) return;
    _timer?.cancel();
    setState(() => _saving = true);
    try {
      final obstacle = widget.idea.obstacleIdeas.isEmpty ? '启动阻力' : widget.idea.obstacleIdeas.first;
      var log = JamesWillLog.create(
        ideaId: widget.idea.id,
        completed: completed,
        beforeObstacle: obstacle,
        dominantActionIdea: widget.idea.fiveMinuteVersion,
        attentionRecoveryCount: _recoveries,
        startDelayMinutes: _startDelayMinutes,
        effortAttentionScore: completed ? (70 + _recoveries * 5).clamp(70, 100).toInt() : (45 + _recoveries * 5).clamp(0, 80).toInt(),
        reflection: reflection,
      );
      final summary = await _ai.summarizeReview(idea: widget.idea, log: log);
      log = JamesWillLog.create(
        ideaId: widget.idea.id,
        completed: completed,
        beforeObstacle: obstacle,
        dominantActionIdea: widget.idea.fiveMinuteVersion,
        attentionRecoveryCount: _recoveries,
        startDelayMinutes: _startDelayMinutes,
        effortAttentionScore: completed ? (70 + _recoveries * 5).clamp(70, 100).toInt() : (45 + _recoveries * 5).clamp(0, 80).toInt(),
        reflection: reflection,
        aiSummary: summary,
      );
      await _dao.saveLog(log);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('保存失败：$e'), backgroundColor: Colors.red.shade700));
      setState(() => _saving = false);
    }
  }

  String get _timeText {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _speakPullback(String stateLabel) async {
    if (_saving || _speaking) return;
    setState(() => _speaking = true);
    try {
      final script = await _completeAi.generateVoicePullbackScript(idea: widget.idea, stateLabel: stateLabel);
      setState(() => _coach = script);
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.speak(script);
    } catch (_) {
      if (mounted) {
        setState(() => _coach = '现在只保留一个观念：${widget.idea.attentionAnchor}。执行第一身体动作：${widget.idea.firstBodyAction}。');
      }
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _willBg,
      appBar: AppBar(title: const Text('五分钟启动器')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _willPurple, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 10))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('当前只保留一个观念', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(widget.idea.attentionAnchor, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.35)),
                const SizedBox(height: 18),
                Center(child: Text(_timeText, style: const TextStyle(color: Colors.white, fontSize: 58, fontWeight: FontWeight.w900, letterSpacing: 2))),
                const SizedBox(height: 12),
                Text(_coach, style: const TextStyle(color: Colors.white, height: 1.45)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoPanel(lines: [
            '第一身体动作：${widget.idea.firstBodyAction}',
            '最小行动：${widget.idea.minimumAction}',
            '5分钟版本：${widget.idea.fiveMinuteVersion}',
          ]),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: _saving || _speaking ? null : () => _speakPullback('启动前抗拒'), icon: Icon(_speaking ? Icons.volume_up : Icons.record_voice_over_outlined), label: Text(_speaking ? '正在朗读拉回文案' : '语音式注意力拉回')),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: _running || _saving ? null : _start, icon: const Icon(Icons.play_arrow), label: const Text('开始 5 分钟')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() {
                            _recoveries += 1;
                            _coach = '分心不是失败，只是另一个观念抢走了注意力。现在重新保留一个观念：继续当前一步。';
                          });
                        },
                  icon: const Icon(Icons.center_focus_strong_outlined),
                  label: Text('我分心了 $_recoveries'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() {
                            _remaining = _remaining.clamp(0, 2 * 60).toInt();
                            _coach = '已经降低难度。现在只承受最小必要痛苦：做 2 分钟或只完成第一动作。';
                          });
                        },
                  icon: const Icon(Icons.compress_outlined),
                  label: const Text('降低难度'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: FilledButton.tonalIcon(onPressed: _saving ? null : () => _finish(completed: true, reflection: '我主动标记完成。'), icon: const Icon(Icons.check_circle_outline), label: const Text('完成'))),
              const SizedBox(width: 10),
              Expanded(child: TextButton.icon(onPressed: _saving ? null : () => _finish(completed: false, reflection: '这次中断了，但我记录了断点。'), icon: const Icon(Icons.pause_circle_outline), label: const Text('中断并记录'))),
            ],
          ),
          if (_saving) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.stats});
  final Map<String, int> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF5B4B8A), Color(0xFF9277D9)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('完整落地：把目标变成行动', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('目标 → 价值 → 行动观念 → 观念竞争 → 决定封存 → 第一身体动作 → 五分钟启动 → 复盘 → 习惯 → 周报。', style: TextStyle(color: Colors.white, height: 1.5)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _HeroStat(label: '行动观念', value: '${stats['ideas'] ?? 0}')),
              const SizedBox(width: 8),
              Expanded(child: _HeroStat(label: '决定分析', value: '${stats['decisions'] ?? 0}')),
              const SizedBox(width: 8),
              Expanded(child: _HeroStat(label: '意志日志', value: '${stats['logs'] ?? 0}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _InputPanel extends StatelessWidget {
  const _InputPanel({required this.goalCtrl, required this.noteCtrl, required this.busy, required this.onCreate});
  final TextEditingController goalCtrl;
  final TextEditingController noteCtrl;
  final bool busy;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('生成行动观念卡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _willInk)),
            const SizedBox(height: 8),
            const Text('输入目标、愿望或行动困难。AI 会把它转化为可执行的第一身体动作和五分钟版本。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
            const SizedBox(height: 12),
            TextField(controller: goalCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '目标 / 愿望 / 行动困难', hintText: '例如：我想学习心理学，但总是拖延', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: noteCtrl, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: '补充说明（可选）', hintText: '当前阻力、时间地点、想解决的问题', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : onCreate, icon: const Icon(Icons.auto_awesome), label: const Text('生成行动观念卡'))),
          ],
        ),
      ),
    );
  }
}

class _ActionIdeaTile extends StatelessWidget {
  const _ActionIdeaTile({required this.idea, required this.onTap});
  final JamesWillActionIdea idea;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: Color(0xFFEDE9FE), child: Icon(Icons.psychology_alt_outlined, color: _willPurple)),
        title: Text(idea.originalGoal, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('行动观念：${idea.actionIdea}\n第一动作：${idea.firstBodyAction}', maxLines: 3, overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _IdeaHeaderCard extends StatelessWidget {
  const _IdeaHeaderCard({required this.idea});
  final JamesWillActionIdea idea;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(idea.originalGoal, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _willInk)),
            if (idea.goalNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(idea.goalNote, style: const TextStyle(color: Color(0xFF6B7280))),
            ],
            const Divider(height: 22),
            _KVLine(label: '核心价值', value: idea.coreValue),
            _KVLine(label: '行动观念', value: idea.actionIdea),
            _KVLine(label: '第一身体动作', value: idea.firstBodyAction),
            _KVLine(label: '最小行动', value: idea.minimumAction),
            _KVLine(label: '5分钟版本', value: idea.fiveMinuteVersion),
            _KVLine(label: '注意力锚定', value: idea.attentionAnchor),
            if (idea.coachMessage.isNotEmpty) _KVLine(label: 'AI教练', value: idea.coachMessage),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ...idea.obstacleIdeas.take(3).map((e) => Chip(label: Text(e), avatar: const Icon(Icons.block_outlined, size: 18))),
              ...idea.replacementIdeas.take(3).map((e) => Chip(label: Text(e), avatar: const Icon(Icons.change_circle_outlined, size: 18))),
            ]),
            const SizedBox(height: 6),
            Text(idea.aiUsedFallback ? '来源：本地策略' : '来源：${idea.aiModelLabel}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _CompetitionPanel extends StatelessWidget {
  const _CompetitionPanel({required this.items});
  final List<JamesWillCompetitionItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _InfoPanel(lines: ['暂无观念竞争数据。请刷新行动观念卡。']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('当前不是“懒不懒”的问题，而是多个观念在争夺注意力主导权。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('${item.type}：${item.content}', style: const TextStyle(fontWeight: FontWeight.w800))),
                          Text('${item.strength}', style: const TextStyle(color: _willPurple, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(value: item.strength.clamp(0, 100) / 100),
                      const SizedBox(height: 3),
                      Text(item.role, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _BodyRehearsalPanel extends StatelessWidget {
  const _BodyRehearsalPanel({required this.idea});
  final JamesWillActionIdea idea;

  @override
  Widget build(BuildContext context) {
    final steps = <String>[
      '站起来或把身体转向行动发生的地方',
      idea.firstBodyAction,
      idea.minimumAction,
      '只保持 30 秒，不评价状态',
      idea.fiveMinuteVersion,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('请在脑中预演下面 5 秒，然后只执行第一步。', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(radius: 12, backgroundColor: const Color(0xFFEDE9FE), child: Text('${e.key + 1}', style: const TextStyle(fontSize: 12, color: _willPurple, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.value, style: const TextStyle(height: 1.4))),
                ]),
              )),
        ]),
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.decision, required this.dateLabel});
  final JamesWillDecision decision;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(decision.question, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          _KVLine(label: '犹豫类型', value: decision.hesitationType),
          _KVLine(label: '决定类型', value: decision.decisionType),
          _KVLine(label: '执行策略', value: decision.strategy),
          _KVLine(label: '今日第一步', value: decision.todayFirstAction),
          _KVLine(label: '封存到', value: dateLabel),
          if (decision.coachMessage.isNotEmpty) _KVLine(label: '教练语', value: decision.coachMessage),
        ]),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log, required this.timeLabel});
  final JamesWillLog log;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(log.completed ? Icons.check_circle_outline : Icons.pause_circle_outline, color: log.completed ? Colors.green.shade700 : Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(child: Text(log.completed ? '已完成一次行动' : '中断并记录断点', style: const TextStyle(fontWeight: FontWeight.w900))),
            Text(timeLabel, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          _KVLine(label: '阻碍观念', value: log.beforeObstacle.isEmpty ? '—' : log.beforeObstacle),
          _KVLine(label: '主导观念', value: log.dominantActionIdea.isEmpty ? '—' : log.dominantActionIdea),
          _KVLine(label: '分心拉回', value: '${log.attentionRecoveryCount} 次'),
          _KVLine(label: '努力性注意', value: '${log.effortAttentionScore}/100'),
          if (log.reflection.isNotEmpty) _KVLine(label: '复盘', value: log.reflection),
          if (log.aiSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
              child: Text(log.aiSummary, style: const TextStyle(height: 1.45)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _KVLine extends StatelessWidget {
  const _KVLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 92, child: Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700))),
        Expanded(child: Text(value, style: const TextStyle(height: 1.35))),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _willInk));
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.lines});
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

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return const _InfoPanel(lines: [
      '还没有行动观念卡。',
      '先输入一个目标或行动困难，例如“我想学习心理学，但总是拖延”。',
      '系统会生成：核心价值、行动观念、第一身体动作、五分钟版本、观念竞争和复盘入口。',
    ]);
  }
}
