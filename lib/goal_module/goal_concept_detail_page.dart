import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'goal_action_runner_page.dart';
import 'goal_concept_advanced.dart';
import 'goal_dao.dart';
import 'goal_models.dart';
import 'goal_segment_detail_page.dart';

class GoalConceptDetailPage extends StatefulWidget {
  final String conceptId;
  const GoalConceptDetailPage({super.key, required this.conceptId});

  @override
  State<GoalConceptDetailPage> createState() => _GoalConceptDetailPageState();
}

class _GoalConceptDetailPageState extends State<GoalConceptDetailPage> {
  final _dao = GoalDao();
  late Future<_ConceptBundle> _future;
  final Set<int> _revealedMisconceptions = <int>{};
  final Map<int, int> _quizAnswers = <int, int>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ConceptBundle> _load() async {
    final concept = await _dao.getConceptCard(widget.conceptId);
    if (concept == null) throw Exception('概念不存在');
    final segment = await _dao.getSegment(concept.segmentId);
    final actions = await _dao.listActionTemplatesForConcept(widget.conceptId);
    final stats = await _dao.getConceptProgressStats(widget.conceptId);
    return _ConceptBundle(concept: concept, segment: segment, actions: actions, stats: stats);
  }

  String _fmt(int ms) {
    if (ms <= 0) return '暂未执行';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.month}/${d.day} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _runAction(GoalActionTemplate action, GoalConceptCard concept, GoalCourseSegment? segment) async {
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => GoalActionRunnerPage(
          action: action,
          conceptTitle: concept.conceptTitle,
          segmentTitle: segment?.sectionTitle ?? '课程正文',
        ),
      ),
    );
    if (result == true && mounted) {
      setState(() => _future = _load());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('行动已记录，反思统计已更新')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('概念实践卡')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<_ConceptBundle>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(child: Text(snap.error?.toString() ?? '加载失败'));
          }
          final bundle = snap.data!;
          final c = bundle.concept;
          final misconceptions = buildConceptMisconceptions(c);
          final quiz = buildConceptQuiz(c, bundle.segment);
          final tiers = buildActionTiers(c, bundle.actions);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip('概念实践层'),
                        _chip('误区辨析', dark: false),
                        _chip('小测问答', dark: false),
                        _chip('多级行动', dark: false),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(c.conceptTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(c.oneLineDefinition, style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF374151))),
                    const SizedBox(height: 12),
                    Text('互动方式：${c.interactionType}', style: const TextStyle(color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '这是什么',
                child: Text(c.whatIsIt, style: const TextStyle(height: 1.7, color: Color(0xFF374151))),
              ),
              const SizedBox(height: 12),
              _card(
                title: '为什么重要',
                child: Text(c.whyItMatters, style: const TextStyle(height: 1.7, color: Color(0xFF374151))),
              ),
              const SizedBox(height: 12),
              _card(
                title: '互动理解方式',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.interactionType, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(c.interactionDescription, style: const TextStyle(height: 1.7, color: Color(0xFF374151))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '误区辨析',
                child: Column(
                  children: [
                    for (int i = 0; i < misconceptions.length; i++) ...[
                      _misconceptionTile(i, misconceptions[i]),
                      if (i != misconceptions.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '小测问答',
                child: Column(
                  children: [
                    for (int i = 0; i < quiz.length; i++) ...[
                      _quizCard(i, quiz[i]),
                      if (i != quiz.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '反思问题',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final q in c.reflections)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('• $q', style: const TextStyle(height: 1.7, color: Color(0xFF374151))),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '多级行动任务',
                child: Column(
                  children: [
                    for (int i = 0; i < tiers.length; i++) ...[
                      _tierCard(bundle, tiers[i]),
                      if (i != tiers.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '反思统计',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _miniStat('行动次数', '${bundle.stats.actionCount}'),
                        _miniStat('平均完成度', '${bundle.stats.avgCompletionPercent}%'),
                        _miniStat('二次复盘', '${bundle.stats.followupCount}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('继续 ${bundle.stats.continueCount} · 调整 ${bundle.stats.adjustCount} · 放弃 ${bundle.stats.releaseCount}', style: const TextStyle(color: Color(0xFF4B5563))),
                    const SizedBox(height: 8),
                    Text('最近一次实践：${_fmt(bundle.stats.lastCompletedAtMs)}', style: const TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(height: 10),
                    Text(
                      bundle.stats.actionCount == 0
                          ? '还没有与这个概念相关的实践记录。建议先从“微行动”开始。'
                          : '这块统计会随着你的执行和二次复盘自动更新，用来观察“理解”是否正在变成“实践”。',
                      style: const TextStyle(height: 1.65, color: Color(0xFF374151)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '回看原课程内容',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bundle.segment != null) ...[
                      Text(bundle.segment!.sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(
                        bundle.segment!.segmentText.replaceAll('\n', ' '),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(height: 1.6, color: Color(0xFF4B5563)),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          CupertinoPageRoute(builder: (_) => GoalSegmentDetailPage(segmentId: bundle.segment!.segmentId)),
                        ),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('查看原课程正文'),
                      ),
                    ] else
                      const Text('未找到对应的课程正文。'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _misconceptionTile(int index, GoalMisconceptionItem item) {
    final revealed = _revealedMisconceptions.contains(index);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            if (revealed) {
              _revealedMisconceptions.remove(index);
            } else {
              _revealedMisconceptions.add(index);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(item.myth, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5))),
                  Icon(revealed ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF6B7280)),
                ],
              ),
              const SizedBox(height: 8),
              Text(revealed ? '点按收起' : '点按查看纠正', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              if (revealed) ...[
                const SizedBox(height: 12),
                Text(item.correction, style: const TextStyle(height: 1.65, color: Color(0xFF374151))),
                const SizedBox(height: 8),
                Text('提示：${item.hint}', style: const TextStyle(height: 1.55, color: Color(0xFF6B7280))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _quizCard(int quizIndex, GoalQuizQuestion q) {
    final selected = _quizAnswers[quizIndex];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q.prompt, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.5)),
          const SizedBox(height: 10),
          for (int i = 0; i < q.options.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: selected == i ? const Color(0xFFEFF6FF) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected == i ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
                ),
              ),
              child: RadioListTile<int>(
                value: i,
                groupValue: selected,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(q.options[i], style: const TextStyle(height: 1.45)),
                onChanged: (v) => setState(() => _quizAnswers[quizIndex] = v ?? 0),
              ),
            ),
          if (selected != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected == q.correctIndex ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                selected == q.correctIndex ? '回答正确：${q.explanation}' : '再想想：${q.explanation}',
                style: TextStyle(
                  height: 1.55,
                  color: selected == q.correctIndex ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tierCard(_ConceptBundle bundle, GoalActionTier tier) {
    final action = tier.action;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(action.actionTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              _chip(tier.levelLabel, dark: false),
            ],
          ),
          const SizedBox(height: 8),
          Text(tier.emphasis, style: const TextStyle(color: Color(0xFF4B5563), height: 1.55)),
          const SizedBox(height: 8),
          Text(action.goalOfAction, style: const TextStyle(height: 1.65, color: Color(0xFF374151))),
          const SizedBox(height: 10),
          for (int i = 0; i < action.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${i + 1}. ${action.steps[i]}', style: const TextStyle(height: 1.55, color: Color(0xFF374151))),
            ),
          const SizedBox(height: 8),
          Text('失败备用方案：${action.failurePlan}', style: const TextStyle(height: 1.55, color: Color(0xFF6B7280))),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _runAction(action, bundle.concept, bundle.segment),
            icon: const Icon(Icons.play_circle_outline),
            label: Text('执行${tier.levelLabel}'),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) => Container(
        width: 104,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      );

  Widget _card({String? title, required Widget child}) {
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
          if (title != null) ...[
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }

  Widget _chip(String text, {bool dark = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: dark ? Colors.white : const Color(0xFF374151), fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ConceptBundle {
  final GoalConceptCard concept;
  final GoalCourseSegment? segment;
  final List<GoalActionTemplate> actions;
  final GoalConceptProgressStats stats;

  _ConceptBundle({
    required this.concept,
    required this.segment,
    required this.actions,
    required this.stats,
  });
}
