import 'package:flutter/material.dart';
import 'belief_levels.dart';
import 'belief_dao.dart';
import 'belief_models.dart';
import 'belief_ui.dart';
import 'belief_episode_list_page.dart';
import 'belief_mission_list_page.dart';

class _DiagChoice {
  final String id;
  final String text;
  final Map<String, int> scoreByConcept;
  const _DiagChoice({required this.id, required this.text, required this.scoreByConcept});
}

class _DiagQ {
  final String id;
  final String title;
  final String body;
  final List<_DiagChoice> choices;
  const _DiagQ({required this.id, required this.title, required this.body, required this.choices});
}

const List<_DiagQ> _qs = [
  _DiagQ(
    id: 'q1',
    title: '我更像被什么牵着走？',
    body: '最近 7 天，你的状态更像：',
    choices: [
      _DiagChoice(id: 'a', text: '环境一变我就跟着变（桌面/手机/人/话）', scoreByConcept: {'c4_priming': 3, 'c3_situation_power': 1}),
      _DiagChoice(id: 'b', text: '失败/评价会把我打回原形', scoreByConcept: {'c8_explanatory_style': 2, 'c7_fail_to_learn': 1}),
      _DiagChoice(id: 'c', text: '我主要是拖延/不行动', scoreByConcept: {'c6_mechanisms': 2, 'c10_tools': 1}),
    ],
  ),
  _DiagQ(
    id: 'q2',
    title: '我对失败的默认解释是？',
    body: '更贴近哪一句：',
    choices: [
      _DiagChoice(id: 'a', text: '我就是不行（我一直都这样）', scoreByConcept: {'c8_explanatory_style': 3}),
      _DiagChoice(id: 'b', text: '这次没准备好/策略不对（下次可改）', scoreByConcept: {'c8_explanatory_style': 1, 'c7_fail_to_learn': 2}),
      _DiagChoice(id: 'c', text: '我会尽量不去想，先躲开', scoreByConcept: {'c6_mechanisms': 2}),
    ],
  ),
  _DiagQ(
    id: 'q3',
    title: '我更容易陷入哪种认知陷阱？',
    body: '选一个更常发生的：',
    choices: [
      _DiagChoice(id: 'a', text: '放大：一次失误=全盘失败', scoreByConcept: {'c10_tools': 3}),
      _DiagChoice(id: 'b', text: '缩小：只盯一个负面点，忽略大局', scoreByConcept: {'c10_tools': 3}),
      _DiagChoice(id: 'c', text: '我更像对自己/别人低期待', scoreByConcept: {'c2_expectation': 2}),
    ],
  ),
  _DiagQ(
    id: 'q4',
    title: '我对“努力”的态度更像？',
    body: '选最贴近的：',
    choices: [
      _DiagChoice(id: 'a', text: '努力没用，现实就是这样', scoreByConcept: {'c1_limit_break': 2, 'c6_mechanisms': 1}),
      _DiagChoice(id: 'b', text: '努力有用，但我常因失败停下', scoreByConcept: {'c7_fail_to_learn': 2, 'c8_explanatory_style': 1}),
      _DiagChoice(id: 'c', text: '我愿意努力，但需要更具体的方法/结构', scoreByConcept: {'c10_tools': 2}),
    ],
  ),
  _DiagQ(
    id: 'q5',
    title: '我的目标/梦想更像？',
    body: '选最贴近的：',
    choices: [
      _DiagChoice(id: 'a', text: '我常只有“终点幻想”，缺少过程行动', scoreByConcept: {'c10_tools': 2}),
      _DiagChoice(id: 'b', text: '我会把目标拆步骤，但心态容易崩', scoreByConcept: {'c8_explanatory_style': 2}),
      _DiagChoice(id: 'c', text: '我能做，但环境/人经常把我拉低', scoreByConcept: {'c3_situation_power': 2, 'c4_priming': 1}),
    ],
  ),
  _DiagQ(
    id: 'q6',
    title: '我在关系里更像？',
    body: '选最贴近的：',
    choices: [
      _DiagChoice(id: 'a', text: '我容易带着“你不行”的眼镜看人', scoreByConcept: {'c2_expectation': 3}),
      _DiagChoice(id: 'b', text: '我愿意看见潜能，但不会把它变成互动', scoreByConcept: {'c2_expectation': 2, 'c10_tools': 1}),
      _DiagChoice(id: 'c', text: '我主要卡在自己身上', scoreByConcept: {'c8_explanatory_style': 1, 'c10_tools': 1}),
    ],
  ),
  _DiagQ(
    id: 'q7',
    title: '我更需要哪种“情境”支持？',
    body: '选最贴近的：',
    choices: [
      _DiagChoice(id: 'a', text: '需要更能让我进入状态的环境（线索/仪式）', scoreByConcept: {'c4_priming': 3}),
      _DiagChoice(id: 'b', text: '需要更能让我持续的制度（节奏/边界/复盘）', scoreByConcept: {'c3_situation_power': 2, 'c10_tools': 1}),
      _DiagChoice(id: 'c', text: '需要更能让我敢失败的安全感', scoreByConcept: {'c7_fail_to_learn': 2}),
    ],
  ),
  _DiagQ(
    id: 'q8',
    title: '我会不会“自欺式乐观”？',
    body: '选最贴近的：',
    choices: [
      _DiagChoice(id: 'a', text: '会：我常靠“相信”替代行动', scoreByConcept: {'c9_realistic_optimism': 2, 'c10_tools': 1}),
      _DiagChoice(id: 'b', text: '不会：我更容易悲观/现实到不敢开始', scoreByConcept: {'c1_limit_break': 2, 'c7_fail_to_learn': 1}),
      _DiagChoice(id: 'c', text: '我能信也能做，但需要更强纪律', scoreByConcept: {'c9_realistic_optimism': 3}),
    ],
  ),
  _DiagQ(
    id: 'q9',
    title: '我对“不一致/内耗”的反应更像？',
    body: '当我知道该做却没做时：',
    choices: [
      _DiagChoice(id: 'a', text: '我会找理由/拖延（先舒服再说）', scoreByConcept: {'c6_mechanisms': 3}),
      _DiagChoice(id: 'b', text: '我会自责到崩溃', scoreByConcept: {'c10_tools': 2, 'c8_explanatory_style': 1}),
      _DiagChoice(id: 'c', text: '我会做一个最小行动把它对齐', scoreByConcept: {'c6_mechanisms': 1, 'c10_tools': 1}),
    ],
  ),
  _DiagQ(
    id: 'q10',
    title: '我最想先解决的，是？',
    body: '选最迫切的：',
    choices: [
      _DiagChoice(id: 'a', text: '我想更敢做、更能承受失败', scoreByConcept: {'c7_fail_to_learn': 3}),
      _DiagChoice(id: 'b', text: '我想让自己更稳定乐观、不再一击崩', scoreByConcept: {'c8_explanatory_style': 3}),
      _DiagChoice(id: 'c', text: '我想把环境变成“自动推我行动”', scoreByConcept: {'c4_priming': 2, 'c3_situation_power': 1}),
    ],
  ),
];

class BeliefDiagnosePage extends StatefulWidget {
  const BeliefDiagnosePage({super.key});

  @override
  State<BeliefDiagnosePage> createState() => _BeliefDiagnosePageState();
}

class _BeliefDiagnosePageState extends State<BeliefDiagnosePage> {
  final _dao = BeliefDao();
  int _idx = 0;
  final Map<String, String> _pick = {}; // qid -> choiceId
  bool _done = false;
  Map<String, int> _scores = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _dao.seedIfNeeded();
    final p = await _dao.getProgress('diagnose:latest');
    if (p == null) return;
    final payload = p.payload;
    final saved = payload['pick'];
    final savedIdx = (payload['idx'] as num?)?.toInt();
    if (saved is Map) {
      saved.forEach((k, v) {
        _pick[k.toString()] = v.toString();
      });
    }
    if (savedIdx != null && savedIdx >= 0 && savedIdx < _qs.length) {
      setState(() => _idx = savedIdx);
    }
  }

  Future<void> _save() async {
    await _dao.upsertProgress(
      'diagnose:latest',
      status: _done ? 2 : 1,
      payload: {'idx': _idx, 'pick': _pick, 'scores': _scores},
    );
  }

  void _calc() {
    final scores = <String, int>{};
    for (final q in _qs) {
      final cid = _pick[q.id];
      if (cid == null) continue;
      final choice = q.choices.firstWhere((c) => c.id == cid);
      choice.scoreByConcept.forEach((k, v) {
        scores[k] = (scores[k] ?? 0) + v;
      });
    }
    _scores = scores;
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildResult(context);

    final q = _qs[_idx];
    final picked = _pick[q.id];

    return Scaffold(
      appBar: AppBar(title: const Text('诊断：我卡在哪？')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: (_idx + 1) / _qs.length)),
                const SizedBox(height: 6),
                Text('第 ${_idx + 1} / ${_qs.length} 题', style: TextStyle(color: Colors.black.withOpacity(0.65))),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                        color: Colors.black.withOpacity(0.04),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text(q.body, style: TextStyle(color: Colors.black.withOpacity(0.75))),
                      const SizedBox(height: 12),
                      ...q.choices.map(
                        (c) => RadioListTile<String>(
                          value: c.id,
                          groupValue: picked,
                          title: Text(c.text),
                          onChanged: (v) => setState(() => _pick[q.id] = v ?? ''),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _idx == 0 ? null : () async {
                        setState(() => _idx--);
                        await _save();
                      },
                      child: const Text('上一题'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if ((_pick[q.id] ?? '').isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先选择一项。')));
                          return;
                        }
                        if (_idx == _qs.length - 1) {
                          _calc();
                          setState(() => _done = true);
                          await _save();
                        } else {
                          setState(() => _idx++);
                          await _save();
                        }
                      },
                      child: Text(_idx == _qs.length - 1 ? '出结果' : '下一题'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    _calc();
    final sorted = _scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(3).toList();

    if (top.isEmpty) {
      return const Scaffold(
        body: BeliefEmptyState(title: '暂无结果', subtitle: '先完成 10 题诊断。'),
      );
    }

    String labelForConcept(String id) {
      return beliefConcepts.firstWhere((c) => c.id == id).title;
    }

    BeliefConcept conceptById(String id) => beliefConcepts.firstWhere((c) => c.id == id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('诊断结果'),
        actions: [
          IconButton(
            tooltip: '重测',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() {
                _idx = 0;
                _pick.clear();
                _done = false;
                _scores = {};
              });
              await _save();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          const Text('你最可能卡在：', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...top.map((e) {
            final c = conceptById(e.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${c.title}  ·  得分 ${e.value}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(c.oneLiner, style: TextStyle(color: Colors.black.withOpacity(0.75))),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => BeliefEpisodeListPage(filterConceptId: c.id)),
                            ),
                            child: const Text('去做案例重演'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => BeliefMissionListPage(filterConceptId: c.id)),
                            ),
                            child: const Text('去做行动任务'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              '使用建议：先做“案例重演”（把链条走一遍）→ 再做“行动任务”（落地 3天/7天）→ 去统计里看复盘。',
              style: TextStyle(color: Colors.black.withOpacity(0.75)),
            ),
          ),
        ],
      ),
    );
  }
}
