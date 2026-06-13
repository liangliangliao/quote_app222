import 'package:flutter/material.dart';

import 'james_will_training_models.dart';
import 'james_will_training_practice_ai_service.dart';
import 'james_will_training_practice_dao.dart';
import 'james_will_training_practice_models.dart';

const _practicePurple = Color(0xFF5B4B8A);
const _practiceBg = Color(0xFFF6F3FF);
const _practiceInk = Color(0xFF26233A);

class JamesWillPracticeFlowPage extends StatefulWidget {
  const JamesWillPracticeFlowPage({super.key, required this.idea});
  final JamesWillActionIdea idea;

  @override
  State<JamesWillPracticeFlowPage> createState() => _JamesWillPracticeFlowPageState();
}

class _JamesWillPracticeFlowPageState extends State<JamesWillPracticeFlowPage> {
  final _dao = JamesWillTrainingPracticeDao();
  final _ai = JamesWillTrainingPracticeAiService();
  final _needCtrl = TextEditingController();
  final _contextCtrl = TextEditingController();
  final _commitCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();
  JamesWillPracticeSession? _session;
  List<JamesWillPracticeSession> _history = const <JamesWillPracticeSession>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _needCtrl.dispose();
    _contextCtrl.dispose();
    _commitCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _dao.ensureTables();
    final latest = await _dao.latestForIdea(widget.idea.id);
    final history = await _dao.listForIdea(widget.idea.id);
    if (!mounted) return;
    setState(() {
      _session = latest;
      _history = history;
      if (latest != null) {
        _needCtrl.text = latest.userNeed;
        _contextCtrl.text = latest.userContext;
        _commitCtrl.text = latest.userCommitment;
        _feedbackCtrl.text = latest.practiceFeedback;
      }
    });
  }

  void _show(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? Colors.red.shade700 : null));
  }

  Future<void> _generateGuide() async {
    final need = _needCtrl.text.trim();
    if (need.isEmpty) {
      _show('请先写下：我真正需要解决什么？', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final session = await _ai.generatePracticeGuide(idea: widget.idea, userNeed: need, userContext: _contextCtrl.text.trim());
      await _dao.saveSession(session);
      await _load();
      _show('已生成完整实践流程。请比较多个路径后自己选择。');
    } catch (e) {
      _show('生成实践流程失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectOption(JamesWillPracticeOption option) async {
    final session = _session;
    if (session == null) return;
    _commitCtrl.text = _commitCtrl.text.trim().isEmpty ? option.firstExperiment : _commitCtrl.text;
    final updated = session.copyWith(
      selectedOptionTitle: option.title,
      userCommitment: _commitCtrl.text.trim(),
      currentStage: 3,
      status: 'selected',
    );
    await _dao.saveSession(updated);
    await _load();
    _show('已选择本轮实验方向。下一步由你确认承诺并进入真实行动。');
  }

  Future<void> _saveCommitment() async {
    final session = _session;
    if (session == null) return;
    final text = _commitCtrl.text.trim();
    if (text.isEmpty) {
      _show('请写下你自己选择的本轮实验承诺。', error: true);
      return;
    }
    await _dao.saveSession(session.copyWith(userCommitment: text, currentStage: 4, status: 'committed'));
    await _load();
    _show('已保存实践承诺。现在可以返回行动卡，进入五分钟启动器。');
  }

  Future<void> _saveFeedback() async {
    final session = _session;
    if (session == null) return;
    final text = _feedbackCtrl.text.trim();
    if (text.isEmpty) {
      _show('请写下实践后的反馈。', error: true);
      return;
    }
    await _dao.saveSession(session.copyWith(practiceFeedback: text, currentStage: 5, status: 'reviewed'));
    await _load();
    _show('已保存实践反馈。下一次根据反馈调整，而不是重新空想。');
  }

  String _fmt(int ms) {
    if (ms <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.month}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      backgroundColor: _practiceBg,
      appBar: AppBar(title: const Text('完整实践流程')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _PracticeHero(idea: widget.idea),
              const SizedBox(height: 12),
              _NeedInputCard(needCtrl: _needCtrl, contextCtrl: _contextCtrl, busy: _busy, onGenerate: _generateGuide),
              const SizedBox(height: 12),
              if (session != null) ...[
                _ProcessCard(session: session),
                const SizedBox(height: 12),
                _UnderstandingCard(session: session),
                const SizedBox(height: 12),
                _QuestionsCard(session: session),
                const SizedBox(height: 12),
                _OptionsCard(session: session, onSelect: _selectOption),
                const SizedBox(height: 12),
                _CommitmentCard(session: session, ctrl: _commitCtrl, onSave: _saveCommitment),
                const SizedBox(height: 12),
                _FeedbackCard(ctrl: _feedbackCtrl, onSave: _saveFeedback),
                const SizedBox(height: 12),
                const _PracticeInfo(lines: [
                  '下一步：返回行动观念卡，点击“五分钟启动”。',
                  '实践完成后，再回到这里写反馈，或者进入“意志复盘”。',
                  '核心不是让 AI 替你决定，而是让你通过小实验获得真实经验。',
                ]),
              ] else
                const _PracticeInfo(lines: [
                  '这里不是让 AI 直接给标准答案，而是建立完整实践过程：澄清真实需要 → 打开多种可能 → 你自己选择低风险实验 → 执行第一身体动作 → 复盘反馈。',
                ]),
              const SizedBox(height: 18),
              if (_history.isNotEmpty) ...[
                const Text('历史实践流程', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _practiceInk)),
                const SizedBox(height: 8),
                ..._history.take(5).map((e) => Card(
                      child: ListTile(
                        title: Text(e.selectedOptionTitle.isEmpty ? e.userNeed : e.selectedOptionTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('阶段 ${e.currentStage}/5 · ${e.status} · ${_fmt(e.updatedAtMs)}'),
                      ),
                    )),
              ],
            ],
          ),
          if (_busy) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.05), child: const Center(child: CircularProgressIndicator()))),
        ],
      ),
    );
  }
}

class _PracticeHero extends StatelessWidget {
  const _PracticeHero({required this.idea});
  final JamesWillActionIdea idea;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF5B4B8A), Color(0xFF9277D9)]), borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('从 AI 分析走向真实实践', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('AI 提供结构、问题、参考案例和多种可能；最终由你根据真实需要选择一条低风险实验。', style: TextStyle(color: Colors.white, height: 1.5)),
        const SizedBox(height: 12),
        Text('行动观念：${idea.actionIdea}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        Text('第一身体动作：${idea.firstBodyAction}', style: const TextStyle(color: Colors.white70)),
      ]),
    );
  }
}

class _NeedInputCard extends StatelessWidget {
  const _NeedInputCard({required this.needCtrl, required this.contextCtrl, required this.busy, required this.onGenerate});
  final TextEditingController needCtrl;
  final TextEditingController contextCtrl;
  final bool busy;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('第一步：澄清真实需要', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('不要急着问“标准答案是什么”。先写下：我真正需要解决什么？我现在卡在哪里？', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
          const SizedBox(height: 10),
          TextField(controller: needCtrl, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: '我真正需要解决的是……', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: contextCtrl, minLines: 1, maxLines: 4, decoration: const InputDecoration(labelText: '我的现实处境/限制/资源（可选）', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : onGenerate, icon: const Icon(Icons.route_outlined), label: const Text('生成多路径实践引导'))),
        ]),
      ),
    );
  }
}

class _ProcessCard extends StatelessWidget {
  const _ProcessCard({required this.session});
  final JamesWillPracticeSession session;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('核心业务流程：阶段 ${session.currentStage}/5', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...session.practiceStages.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(radius: 13, backgroundColor: e.key + 1 <= session.currentStage ? _practicePurple : const Color(0xFFE5E7EB), child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.value, style: const TextStyle(height: 1.45))),
                ]),
              )),
        ]),
      ),
    );
  }
}

class _UnderstandingCard extends StatelessWidget {
  const _UnderstandingCard({required this.session});
  final JamesWillPracticeSession session;
  @override
  Widget build(BuildContext context) => _PracticeInfo(title: 'AI 对真实需要的理解', lines: [session.needUnderstanding, session.choicePrompt]);
}

class _QuestionsCard extends StatelessWidget {
  const _QuestionsCard({required this.session});
  final JamesWillPracticeSession session;
  @override
  Widget build(BuildContext context) => _PracticeInfo(title: '先思考这些问题', lines: session.guidingQuestions);
}

class _OptionsCard extends StatelessWidget {
  const _OptionsCard({required this.session, required this.onSelect});
  final JamesWillPracticeSession session;
  final Future<void> Function(JamesWillPracticeOption option) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('多种可能路径：由你选择', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _practiceInk)),
      const SizedBox(height: 8),
      ...session.options.map((option) => Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(option.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                  if (session.selectedOptionTitle == option.title) const Icon(Icons.check_circle, color: _practicePurple),
                ]),
                const SizedBox(height: 8),
                _PracticeLine(label: '适用时机', value: option.whenHelpful),
                _PracticeLine(label: '代价取舍', value: option.tradeoff),
                _PracticeLine(label: '第一实验', value: option.firstExperiment),
                _PracticeLine(label: '参考案例', value: option.referenceCase),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => onSelect(option), icon: const Icon(Icons.touch_app_outlined), label: const Text('我选择这条作为本轮实验'))),
              ]),
            ),
          )),
    ]);
  }
}

class _CommitmentCard extends StatelessWidget {
  const _CommitmentCard({required this.session, required this.ctrl, required this.onSave});
  final JamesWillPracticeSession session;
  final TextEditingController ctrl;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('用户选择与实践承诺', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('当前选择：${session.selectedOptionTitle.isEmpty ? '尚未选择路径' : session.selectedOptionTitle}', style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 10),
          TextField(controller: ctrl, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: '我自己选择的本轮实验是……', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onSave, icon: const Icon(Icons.edit_note_outlined), label: const Text('保存我的选择'))),
        ]),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.ctrl, required this.onSave});
  final TextEditingController ctrl;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('实践后的经验反馈', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('记录真实经验：哪个观念阻碍了我？哪个动作真的启动了？下次要调小、换路径，还是继续封存执行？', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
          const SizedBox(height: 10),
          TextField(controller: ctrl, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: '实践反馈 / 下一次调整', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onSave, icon: const Icon(Icons.fact_check_outlined), label: const Text('保存实践反馈'))),
        ]),
      ),
    );
  }
}

class _PracticeInfo extends StatelessWidget {
  const _PracticeInfo({required this.lines, this.title});
  final String? title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
          ],
          ...lines.map((e) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Text(e, style: const TextStyle(height: 1.45, color: Color(0xFF4B5563))))),
        ]),
      ),
    );
  }
}

class _PracticeLine extends StatelessWidget {
  const _PracticeLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 74, child: Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700))),
        Expanded(child: Text(value, style: const TextStyle(height: 1.35))),
      ]),
    );
  }
}
