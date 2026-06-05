import 'package:flutter/material.dart';

import 'goal_action_record_detail_page.dart';
import 'goal_action_runner_page.dart';
import 'goal_dao.dart';
import 'goal_models.dart';
import 'goal_workshop_actions.dart';

class GoalWorkshopPage extends StatefulWidget {
  final String? entryNote;

  const GoalWorkshopPage({super.key, this.entryNote});

  @override
  State<GoalWorkshopPage> createState() => _GoalWorkshopPageState();
}

class _GoalWorkshopPageState extends State<GoalWorkshopPage> {
  final _dao = GoalDao();
  final _identity = TextEditingController();
  final _vision = TextEditingController();
  final _why = TextEditingController();
  final _realityProblem = TextEditingController();
  final _externalExpectation = TextEditingController();
  final _competingGoal = TextEditingController();
  final _lifeline = TextEditingController();
  final _weeklyGoal = TextEditingController();
  final _firstStep = TextEditingController();
  final _ifThen = TextEditingController();

  double _stretch = 5;
  bool _loading = true;
  bool _saving = false;
  int _step = 0;

  GoalWorkshopDraft _snapshot = GoalWorkshopDraft.empty();
  late Future<GoalWorkshopActionOverview> _workshopActionOverviewFuture;

  @override
  void initState() {
    super.initState();
    _workshopActionOverviewFuture = _dao.getWorkshopActionOverview();
    _load();
  }

  Future<void> _load() async {
    final draft = await _dao.getWorkshopDraft();
    _snapshot = draft;
    _identity.text = draft.identityStatement;
    _vision.text = draft.vision;
    _why.text = draft.whyText;
    _realityProblem.text = draft.realityProblem;
    _externalExpectation.text = draft.externalExpectation;
    _competingGoal.text = draft.competingGoal;
    _lifeline.text = draft.lifeline;
    _weeklyGoal.text = draft.weeklyGoal;
    _firstStep.text = draft.firstStep;
    _ifThen.text = draft.ifThenText;
    _stretch = draft.stretchScore;
    if (mounted) setState(() => _loading = false);
  }

  GoalWorkshopDraft _buildDraft() {
    return GoalWorkshopDraft(
      identityStatement: _identity.text.trim(),
      vision: _vision.text.trim(),
      whyText: _why.text.trim(),
      realityProblem: _realityProblem.text.trim(),
      externalExpectation: _externalExpectation.text.trim(),
      competingGoal: _competingGoal.text.trim(),
      lifeline: _lifeline.text.trim(),
      stretchScore: _stretch,
      weeklyGoal: _weeklyGoal.text.trim(),
      firstStep: _firstStep.text.trim(),
      ifThenText: _ifThen.text.trim(),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _save() async {
    await _saveSilently(showSnackBar: true);
  }

  void _refreshWorkshopActionOverview() {
    if (!mounted) return;
    setState(() {
      _workshopActionOverviewFuture = _dao.getWorkshopActionOverview();
    });
  }

  Future<void> _openWorkshopActionRecord(int recordId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GoalActionRecordDetailPage(recordId: recordId)),
    );
    if (!mounted) return;
    _refreshWorkshopActionOverview();
  }

  void _appendSuggestionToIfThen(String suggestion) {
    final trimmed = suggestion.trim();
    if (trimmed.isEmpty) return;
    final current = _ifThen.text.trim();
    final injected = current.isEmpty
        ? '如果我再次被这个问题卡住，那么我先：$trimmed'
        : '$current\n如果我再次被这个问题卡住，那么我先：$trimmed';
    setState(() => _ifThen.text = injected);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已把建议补到 if-then')));
  }

  Future<void> _saveSilently({bool showSnackBar = false}) async {
    setState(() => _saving = true);
    final draft = _buildDraft();
    await _dao.saveWorkshopDraft(
      identityStatement: draft.identityStatement,
      vision: draft.vision,
      whyText: draft.whyText,
      realityProblem: draft.realityProblem,
      externalExpectation: draft.externalExpectation,
      competingGoal: draft.competingGoal,
      lifeline: draft.lifeline,
      stretchScore: draft.stretchScore,
      weeklyGoal: draft.weeklyGoal,
      firstStep: draft.firstStep,
      ifThenText: draft.ifThenText,
    );
    _snapshot = draft;
    if (!mounted) return;
    setState(() => _saving = false);
    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('目标工坊已保存')));
    }
  }

  Future<void> _runWorkshopAction(GoalWorkshopActionDraft draftCard) async {
    final draft = _buildDraft();
    if (draft.vision.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先写下你真正想追求的目标，再生成行动草稿')));
      return;
    }
    await _saveSilently(showSnackBar: false);
    if (!mounted) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GoalActionRunnerPage(
          action: draftCard.action,
          conceptTitle: draftCard.conceptTitle,
          segmentTitle: draftCard.segmentTitle,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _refreshWorkshopActionOverview();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已从工坊启动并保存：${draftCard.levelLabel}')),
      );
    }
  }

  @override
  void dispose() {
    _identity.dispose();
    _vision.dispose();
    _why.dispose();
    _realityProblem.dispose();
    _externalExpectation.dispose();
    _competingGoal.dispose();
    _lifeline.dispose();
    _weeklyGoal.dispose();
    _firstStep.dispose();
    _ifThen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _buildDraft();
    return Scaffold(
      appBar: AppBar(title: const Text('目标工坊')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if ((widget.entryNote ?? '').trim().isNotEmpty) ...[
                  _noticeCard(widget.entryNote!.trim()),
                  const SizedBox(height: 12),
                ],
                _heroCard(draft),
                const SizedBox(height: 12),
                _alignmentCheckCard(draft),
                const SizedBox(height: 12),
                _stepper(),
                const SizedBox(height: 12),
                ..._stepCards(draft),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _step == 0 ? null : () => setState(() => _step -= 1),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('上一步'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                if (_step < 3) {
                                  setState(() => _step += 1);
                                } else {
                                  await _save();
                                }
                              },
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(_step < 3 ? Icons.chevron_right : Icons.save_outlined),
                        label: Text(_saving ? '保存中…' : (_step < 3 ? '下一步' : '保存工坊')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _noticeCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.move_down_outlined, color: Color(0xFF065F46)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.55, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard(GoalWorkshopDraft draft) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('从“想要一个目标”到“能真正执行的目标”', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            '这一页把课程里的目标思想压成四步：身份与方向、why 与现实问题、生命线与拉伸度、每周推进与 if-then。现在还会帮你检查：这个目标到底更像你自己，还是更像外界期待。',
            style: TextStyle(height: 1.6, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _scoreCard('完成度', '${(draft.completionRate * 100).round()}%')),
              const SizedBox(width: 10),
              Expanded(child: _scoreCard('结构分', '${draft.consistencyScore}')),
              const SizedBox(width: 10),
              Expanded(child: _scoreCard('一致性', '${draft.alignmentScore}')),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: draft.completionRate,
            minHeight: 10,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: const Color(0xFFE5E7EB),
          ),
          if (_snapshot.updatedAtMs > 0) ...[
            const SizedBox(height: 10),
            Text(
              '上次保存：${DateTime.fromMillisecondsSinceEpoch(_snapshot.updatedAtMs).toLocal().toString().substring(0, 16)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _alignmentCheckCard(GoalWorkshopDraft draft) {
    final riskColor = draft.alignmentScore >= 80
        ? const Color(0xFF065F46)
        : (draft.alignmentScore >= 60 ? const Color(0xFF92400E) : const Color(0xFF991B1B));
    final riskBg = draft.alignmentScore >= 80
        ? const Color(0xFFECFDF5)
        : (draft.alignmentScore >= 60 ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('目标冲突与一致性检查', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: riskBg, borderRadius: BorderRadius.circular(99)),
                child: Text(draft.alignmentLevel, style: TextStyle(color: riskColor, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricChip('外界期待', '${draft.externalPressureScore}', draft.externalPressureScore),
              _metricChip('目标冲突', '${draft.conflictScore}', draft.conflictScore),
              _metricChip('拉力风险', '${draft.stretchRiskScore}', draft.stretchRiskScore),
            ],
          ),
          const SizedBox(height: 12),
          if (draft.detectedRisks.isNotEmpty) ...[
            const Text('当前提示', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: draft.detectedRisks.map((e) => _tagChip(e)).toList(),
            ),
            const SizedBox(height: 12),
          ],
          const Text('调整建议', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (int i = 0; i < draft.adjustmentSuggestions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.subdirectory_arrow_right_rounded, size: 18, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(draft.adjustmentSuggestions[i], style: const TextStyle(height: 1.55, color: Color(0xFF374151))),
                        if (i < 2)
                          TextButton.icon(
                            onPressed: () => _appendSuggestionToIfThen(draft.adjustmentSuggestions[i]),
                            icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                            label: const Text('补到 if-then'),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _scoreCard(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      );

  Widget _metricChip(String label, String value, int score) {
    final color = score >= 60
        ? const Color(0xFF991B1B)
        : (score >= 30 ? const Color(0xFF92400E) : const Color(0xFF065F46));
    final bg = score >= 60
        ? const Color(0xFFFEF2F2)
        : (score >= 30 ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _tagChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
      );

  Widget _stepper() {
    const labels = ['方向', 'why', '拉力', '执行'];
    return Row(
      children: List.generate(labels.length, (i) {
        final active = i == _step;
        final done = i < _step;
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: done || active ? const Color(0xFF111827) : Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: active ? const Color(0xFF111827) : const Color(0xFFD1D5DB)),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(color: done || active ? Colors.white : const Color(0xFF6B7280), fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(labels[i], style: TextStyle(fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: const Color(0xFF374151))),
            ],
          ),
        );
      }),
    );
  }

  List<Widget> _stepCards(GoalWorkshopDraft draft) {
    switch (_step) {
      case 0:
        return [
          _fieldCard(
            title: '1. 我想成为什么样的人',
            subtitle: '先把目标和身份连接起来，而不是只写一件待办。',
            child: _textField(_identity, hint: '例如：成为一个更诚实行动、持续推进长期目标的人'),
          ),
          const SizedBox(height: 12),
          _fieldCard(
            title: '2. 我真正想追求的目标',
            subtitle: '写出你此刻最想认真面对的一件事。',
            child: _textField(_vision, hint: '例如：建立更像自己的职业路径 / 连续8周完成健康训练计划'),
          ),
          const SizedBox(height: 12),
          _fieldCard(
            title: '3. 外界对我的期待',
            subtitle: '把“别人希望我怎样”单独写出来，避免它悄悄伪装成“我的目标”。',
            child: _textField(_externalExpectation, hint: '例如：家人希望我优先稳定、同伴都在冲热门赛道', maxLines: 4),
          ),
        ];
      case 1:
        return [
          _fieldCard(
            title: '4. Why：这件事为什么重要',
            subtitle: '不是“应该做”，而是“它为什么值得我花生命”。',
            child: _textField(_why, hint: '例如：因为它让我更像真正的自己，也会改善我的工作与情绪', maxLines: 4),
          ),
          const SizedBox(height: 12),
          _fieldCard(
            title: '5. 当前真正卡住我的问题',
            subtitle: '把含糊焦虑翻译成一个清楚的现实阻碍。',
            child: _textField(_realityProblem, hint: '例如：晚上下班后精力低，遇到难度就逃开，容易刷手机', maxLines: 4),
          ),
          const SizedBox(height: 12),
          _fieldCard(
            title: '6. 竞争性目标 / 现实拉扯',
            subtitle: '把正在和这个目标争夺时间、精力、资源的另一件事写出来。',
            child: _textField(_competingGoal, hint: '例如：一边想转型，一边又不敢放下现有绩效；健康目标和加班冲突', maxLines: 4),
          ),
        ];
      case 2:
        return [
          _fieldCard(
            title: '7. Lifeline（生命线）',
            subtitle: '给目标一个清晰时间点，不要只说“我以后会做”。',
            child: _textField(_lifeline, hint: '例如：我会在 2026-06-30 前完成第一阶段'),
          ),
          const SizedBox(height: 12),
          _fieldCard(
            title: '8. Stretch 拉伸程度',
            subtitle: '0 很容易，10 很难。更推荐“有拉力但不是压垮你”的区间。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  min: 0,
                  max: 10,
                  divisions: 10,
                  value: _stretch,
                  label: _stretch.toStringAsFixed(0),
                  onChanged: (v) => setState(() => _stretch = v),
                ),
                Text(
                  _stretch <= 3
                      ? '当前偏容易：可能不够点燃你。'
                      : (_stretch >= 8 ? '当前偏高压：建议再拆台阶。' : '当前处于可激励区间：有拉力，也更有机会推进。'),
                  style: const TextStyle(color: Color(0xFF6B7280), height: 1.5),
                ),
              ],
            ),
          ),
        ];
      default:
        return [
          _fieldCard(
            title: '9. 本周推进点',
            subtitle: '把长期目标压缩成本周真正可推进的一件事。',
            child: _textField(_weeklyGoal, hint: '例如：本周完成第一版作品集框架 / 本周跑步 3 次'),
          ),
          const SizedBox(height: 12),
          _fieldCard(
            title: '10. 明天第一步',
            subtitle: '不要再写“大计划”，而是写最小可执行的下一步。',
            child: _textField(_firstStep, hint: '例如：明天 20:30 打开电脑，只整理目录 15 分钟'),
          ),
          const SizedBox(height: 12),
          _fieldCard(
            title: '11. If-Then 脚本',
            subtitle: '提前给阻碍写好脚本，减少临场靠意志硬扛。',
            child: _textField(_ifThen, hint: '例如：如果我下班后只想躺着，那么我先做 5 分钟而不是要求自己做 1 小时', maxLines: 4),
          ),
          const SizedBox(height: 12),
          _summaryCard(draft),
          const SizedBox(height: 12),
          _workshopActionLoopCard(),
          const SizedBox(height: 12),
          _generatedActionDraftsCard(draft),
        ];
    }
  }

  Widget _summaryCard(GoalWorkshopDraft draft) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('当前工坊总结', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _summaryLine('身份', draft.identityStatement),
          _summaryLine('目标', draft.vision),
          _summaryLine('why', draft.whyText),
          _summaryLine('外界期待', draft.externalExpectation),
          _summaryLine('竞争性目标', draft.competingGoal),
          _summaryLine('阻碍', draft.realityProblem),
          _summaryLine('生命线', draft.lifeline),
          _summaryLine('本周推进', draft.weeklyGoal),
          _summaryLine('明天第一步', draft.firstStep),
          _summaryLine('if-then', draft.ifThenText),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: Color(0xFF374151), height: 1.6),
            children: [
              TextSpan(text: '$label：', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: value.trim().isEmpty ? '（待填写）' : value),
            ],
          ),
        ),
      );

  Widget _workshopActionLoopCard() {
    return FutureBuilder<GoalWorkshopActionOverview>(
      future: _workshopActionOverviewFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: const SizedBox(height: 72, child: Center(child: CircularProgressIndicator())),
          );
        }
        final overview = snap.data!;
        final latest = overview.latestAction;
        final pending = overview.pendingAction;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('工坊最近一次行动结果', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                '这里会显示最近一次由目标工坊自动发起的行动，以及是否还待你做二次复盘。这样工坊不会停留在“想清楚”，而能持续看到自己发起过什么、推进到了哪。',
                style: TextStyle(color: Color(0xFF6B7280), height: 1.55),
              ),
              const SizedBox(height: 12),
              if (pending != null) ...[
                _workshopActionStatusTile(
                  label: '继续上次工坊行动',
                  helper: '这条行动还没有完成二次复盘，建议先做“继续 / 调整 / 放弃”的判断。',
                  view: pending,
                  emphasize: true,
                ),
                if (latest != null && latest.record.id != pending.record.id) const SizedBox(height: 10),
              ],
              if (latest != null && (pending == null || latest.record.id != pending.record.id)) ...[
                _workshopActionStatusTile(
                  label: '最近一次由工坊发起的行动结果',
                  helper: latest.hasFollowup ? '这条行动已经进入闭环，你可以回看结果并决定是否继续沿用当前工坊策略。' : '这条行动已经保存，但还没有进入二次复盘。',
                  view: latest,
                ),
              ],
              if (latest == null && pending == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
                  child: const Text(
                    '这里还没有由工坊发起的行动记录。你可以先保存下面任意一条“工坊自动生成行动草稿”，然后这里就会出现最近结果与待复盘入口。',
                    style: TextStyle(color: Color(0xFF6B7280), height: 1.55),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _workshopActionStatusTile({
    required String label,
    required String helper,
    required GoalActionRecordView view,
    bool emphasize = false,
  }) {
    final statusText = view.hasFollowup ? '已${view.followupDecision}' : '待复盘';
    final statusBg = view.hasFollowup ? const Color(0xFF111827) : const Color(0xFFFEF3C7);
    final statusFg = view.hasFollowup ? Colors.white : const Color(0xFF92400E);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: emphasize ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: emphasize ? const Color(0xFFD1D5DB) : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(999)),
                child: Text(statusText, style: TextStyle(color: statusFg, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(view.actionTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(view.conceptTitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          Text(helper, style: const TextStyle(color: Color(0xFF4B5563), height: 1.5)),
          const SizedBox(height: 8),
          Text(
            '完成度 ${(view.record.completionRate * 100).round()}% · ${_fmtDate(view.record.completedAtMs)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _openWorkshopActionRecord(view.record.id),
                icon: Icon(view.hasFollowup ? Icons.visibility_outlined : Icons.autorenew_outlined),
                label: Text(view.hasFollowup ? '查看行动结果' : '继续做二次复盘'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _step = 3);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已回到目标工坊执行层，可继续调整本周推进和下一步动作。')),
                  );
                },
                icon: const Icon(Icons.construction_outlined),
                label: const Text('回到工坊继续调整'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _generatedActionDraftsCard(GoalWorkshopDraft draft) {
    final drafts = buildWorkshopActionDrafts(draft);
    final canRun = draft.vision.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('工坊自动生成行动草稿', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(99)),
                child: const Text('保存后可直接执行', style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '工坊会根据你现在填写的目标、why、本周推进和 if-then，自动长出三条行动草稿：微行动、标准行动、进阶行动。它们不是固定模板，而是和你当前草稿联动的启动器。',
            style: TextStyle(color: Color(0xFF6B7280), height: 1.55),
          ),
          if (!canRun) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(14)),
              child: const Text('先填好“我真正想追求的目标”，下面三条行动草稿才会更像你现在真正要推进的事。', style: TextStyle(color: Color(0xFF92400E), height: 1.55)),
            ),
          ],
          const SizedBox(height: 12),
          for (final item in drafts) ...[
            _workshopActionTile(item, enabled: canRun),
            if (item != drafts.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _workshopActionTile(GoalWorkshopActionDraft draftCard, {required bool enabled}) {
    final action = draftCard.action;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(999)),
                child: Text(draftCard.levelLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(action.actionTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(draftCard.subtitle, style: const TextStyle(color: Color(0xFF4B5563), height: 1.5)),
          const SizedBox(height: 8),
          Text(action.goalOfAction, style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
          const SizedBox(height: 8),
          Text('预计 ${action.durationMin} 分钟 · 来源：${draftCard.segmentTitle}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 10),
          ...action.steps.take(3).map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Icon(Icons.circle, size: 7, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(step, style: const TextStyle(color: Color(0xFF374151), height: 1.5))),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: enabled && !_saving ? () => _runWorkshopAction(draftCard) : null,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('保存并执行'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), height: 1.5)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _textField(TextEditingController controller, {required String hint, int maxLines = 2}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}
