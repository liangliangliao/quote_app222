import 'package:flutter/material.dart';
import 'belief_levels.dart';
import 'belief_dao.dart';
import 'belief_ui.dart';
import 'belief_models.dart';
import 'belief_segment_detail_page.dart';
import 'belief_episode_list_page.dart';
import 'belief_mission_list_page.dart';
import 'belief_action_templates_page.dart';
import 'belief_segment_replay.dart';

class BeliefConceptsPage extends StatefulWidget {
  const BeliefConceptsPage({super.key});

  @override
  State<BeliefConceptsPage> createState() => _BeliefConceptsPageState();
}

class _BeliefConceptsPageState extends State<BeliefConceptsPage> {
  final _dao = BeliefDao();
  final _qCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = beliefConcepts.where((c) {
      if (_q.trim().isEmpty) return true;
      final k = _q.trim().toLowerCase();
      return c.title.toLowerCase().contains(k) ||
          c.oneLiner.toLowerCase().contains(k) ||
          c.group.toLowerCase().contains(k) ||
          c.detail.toLowerCase().contains(k);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('学习：概念地图')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _qCtrl,
              decoration: InputDecoration(
                hintText: '搜索概念（例：Stockdale / 3Ms / 失败 / priming）',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                const groupOrder = <String>[
                  '信念与现实',
                  '关系与期待',
                  '情境与环境',
                  '身心机制',
                  '认知机制',
                  '失败与乐观',
                  '幸福与应对',
                  '工具箱',
                ];

                int groupIndex(String g) {
                  final i = groupOrder.indexOf(g);
                  return i < 0 ? groupOrder.length : i;
                }

                items.sort((a, b) {
                  final g = groupIndex(a.group).compareTo(groupIndex(b.group));
                  if (g != 0) return g;
                  final o = a.order.compareTo(b.order);
                  if (o != 0) return o;
                  return a.title.compareTo(b.title);
                });

                final rows = <Object>[];
                String? lastGroup;
                for (final c in items) {
                  if (lastGroup != c.group) {
                    lastGroup = c.group;
                    rows.add(lastGroup);
                  }
                  rows.add(c);
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final row = rows[i];
                    if (row is String) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
                        child: _GroupHeader(title: row),
                      );
                    }
                    final c = row as BeliefConcept;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ConceptCard(concept: c, dao: _dao),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _ConceptCard extends StatelessWidget {
  final BeliefConcept concept;
  final BeliefDao dao;
  const _ConceptCard({required this.concept, required this.dao});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        dao.getSegmentsByKeys(concept.segmentKeys),
        dao.listProgressByPrefix('episode:'),
        dao.listProgressByPrefix('mission:'),
      ]),
      builder: (context, snap) {
        int doneEpisodes = 0;
        int doneMissions = 0;

        // 概念内的“案例重演”分两类：
        // 1) 逐段重演：每个关联段落一个关卡（数量 >= 段落数）
        // 2) 经典案例：额外补充
        final segmentEpisodeIds = concept.segmentKeys
            .map((k) => makeSegmentReplayEpisodeId(conceptId: concept.id, segmentKey: k))
            .toList();
        final classicEpisodeIds =
            beliefEpisodes.where((e) => e.conceptId == concept.id).map((e) => e.id).toList();
        final episodeTotal = segmentEpisodeIds.length + classicEpisodeIds.length;

        if (snap.hasData) {
          final ep = snap.data![1] as List<BeliefProgress>;
          final ms = snap.data![2] as List<BeliefProgress>;

          for (final id in [...segmentEpisodeIds, ...classicEpisodeIds]) {
            final key = 'episode:$id';
            final p = ep.where((e) => e.key == key).toList();
            if (p.isNotEmpty && p.first.status == 2) doneEpisodes++;
          }
          for (final id in concept.missionIds) {
            final key = 'mission:$id';
            final p = ms.where((e) => e.key == key).toList();
            if (p.isNotEmpty && p.first.status == 2) doneMissions++;
          }
        }

        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BeliefConceptDetailPage(conceptId: concept.id)),
          ),
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 124,
            child: BeliefSectionCard(
              title: concept.title,
              subtitle: '${concept.group} · ${concept.oneLiner}\n进度：案例 $doneEpisodes/$episodeTotal · 行动 $doneMissions/${concept.missionIds.length}',
              icon: Icons.school_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BeliefConceptDetailPage(conceptId: concept.id)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class BeliefConceptDetailPage extends StatefulWidget {
  final String conceptId;
  const BeliefConceptDetailPage({super.key, required this.conceptId});

  @override
  State<BeliefConceptDetailPage> createState() => _BeliefConceptDetailPageState();
}

class _BeliefConceptDetailPageState extends State<BeliefConceptDetailPage> {
  final _dao = BeliefDao();

  @override
  Widget build(BuildContext context) {
    final c = getConceptById(widget.conceptId);
    final classicEpisodeCount = beliefEpisodes.where((e) => e.conceptId == c.id).length;
    final episodeTotal = c.segmentKeys.length + classicEpisodeCount;

    return Scaffold(
      appBar: AppBar(title: Text(c.title)),
      body: FutureBuilder(
        future: _dao.getSegmentsByKeys(c.segmentKeys),
        builder: (context, snap) {
          final segMap = (snap.data ?? {}) as Map<String, BeliefSegment>;
          final segs = c.segmentKeys.map((k) => segMap[k]).whereType<BeliefSegment>().toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              Text(c.oneLiner, style: TextStyle(color: Colors.black.withOpacity(0.75), fontSize: 14)),
              const SizedBox(height: 10),
              if (c.detail.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    c.detail,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                children: [
                  BeliefChip(c.group),
                  BeliefChip('段落 ${c.segmentKeys.length}'),
                  BeliefChip('案例 $episodeTotal'),
                  BeliefChip('行动 ${c.missionIds.length}'),
                ],
              ),
              const SizedBox(height: 16),
              const Text('关联段落（资料库）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (segs.isEmpty)
                BeliefEmptyState(title: '暂无段落', subtitle: '种子数据未初始化或查询失败。')
              else
                ...segs.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BeliefSegmentDetailPage(segmentKey: s.key)),
                      ),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(s.key, style: const TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.black45),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              const Text('快速进入', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              BeliefSectionCard(
                title: '案例重演（逐段还原 + 经典）',
                subtitle: '逐段重演（${c.segmentKeys.length}）+ 经典案例（$classicEpisodeCount）。\n每个关联段落都有一个“直观还原”关卡，并要求一致性评分。',
                icon: Icons.theaters_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BeliefEpisodeListPage(filterConceptId: c.id)),
                ),
              ),
              const SizedBox(height: 12),
              if (c.missionIds.isNotEmpty)
                BeliefSectionCard(
                  title: '行动任务（本概念）',
                  subtitle: '把知识落地：做一个 3 天/7 天任务。',
                  icon: Icons.checklist_outlined,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BeliefMissionListPage(filterConceptId: c.id)),
                  ),
                ),
              const SizedBox(height: 12),
              BeliefSectionCard(
                title: '行动模板（AI 生成 / 自定义）',
                subtitle: '把概念翻译成你的行动脚本，并用一致性评分验证落地效果。',
                icon: Icons.auto_awesome_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BeliefActionTemplatesPage(conceptId: c.id, conceptTitle: c.title),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
