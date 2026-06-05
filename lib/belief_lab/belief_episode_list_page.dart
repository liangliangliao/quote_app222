import 'package:flutter/material.dart';

import 'belief_levels.dart';
import 'belief_dao.dart';
import 'belief_models.dart';
import 'belief_flow_page.dart';
import 'belief_ui.dart';
import 'belief_segment_replay.dart';

class BeliefEpisodeListPage extends StatefulWidget {
  final String? filterConceptId;
  const BeliefEpisodeListPage({super.key, this.filterConceptId});

  @override
  State<BeliefEpisodeListPage> createState() => _BeliefEpisodeListPageState();
}

class _BeliefEpisodeListPageState extends State<BeliefEpisodeListPage> {
  final _dao = BeliefDao();

  @override
  Widget build(BuildContext context) {
    // 全局列表：只展示“经典案例重演”（避免被 57 段逐段重演淹没）。
    if (widget.filterConceptId == null) {
      final list = beliefEpisodes;
      return Scaffold(
        appBar: AppBar(title: const Text('重演：案例关卡')),
        body: FutureBuilder(
          future: _dao.listProgressByPrefix('episode:'),
          builder: (context, snap) {
            final progress = snap.data as List<BeliefProgress>? ?? const [];
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final ep = list[i];
                final key = 'episode:${ep.id}';
                final p = progress.where((x) => x.key == key).toList();
                final status = p.isEmpty ? 0 : p.first.status;

                String badge = '未开始';
                if (status == 1) badge = '进行中';
                if (status == 2) badge = '已完成';

                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BeliefFlowPage(
                        kind: BeliefFlowKind.episode,
                        id: ep.id,
                        title: ep.title,
                        subtitle: ep.subtitle,
                        steps: ep.steps,
                      ),
                    ),
                  ).then((_) => setState(() {})),
                  borderRadius: BorderRadius.circular(18),
                  child: BeliefSectionCard(
                    title: ep.title,
                    subtitle: '${ep.subtitle}\n状态：$badge',
                    icon: Icons.theaters_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BeliefFlowPage(
                          kind: BeliefFlowKind.episode,
                          id: ep.id,
                          title: ep.title,
                          subtitle: ep.subtitle,
                          steps: ep.steps,
                        ),
                      ),
                    ).then((_) => setState(() {})),
                  ),
                );
              },
            );
          },
        ),
      );
    }

    // 概念内列表：
    // 1) 逐段重演：每个关联段落都有一个“直观还原”关卡（数量 >= 关联段落数）
    // 2) 经典案例重演：额外补充
    final concept = getConceptById(widget.filterConceptId!);

    return Scaffold(
      appBar: AppBar(title: const Text('重演：本概念关卡')),
      body: FutureBuilder(
        future: Future.wait([
          _dao.getSegmentsByKeys(concept.segmentKeys),
          _dao.listProgressByPrefix('episode:'),
        ]),
        builder: (context, snap) {
          final data = snap.data;
          final segMap = (data != null ? data[0] : null) as Map<String, BeliefSegment>? ?? {};
          final progress = (data != null ? data[1] : null) as List<BeliefProgress>? ?? const [];

          final segmentEpisodes = <BeliefEpisode>[];
          for (final k in concept.segmentKeys) {
            final s = segMap[k];
            if (s == null) continue;
            final id = makeSegmentReplayEpisodeId(conceptId: concept.id, segmentKey: s.key);
            segmentEpisodes.add(
              BeliefEpisode(
                id: id,
                conceptId: concept.id,
                title: '逐段重演：${s.title}',
                subtitle: '对应 ${s.key} · 还原段落 → 现实映射 → 一致性评分',
                steps: buildSegmentReplaySteps(concept: concept, segment: s),
              ),
            );
          }

          final classic = beliefEpisodes.where((e) => e.conceptId == widget.filterConceptId).toList();

          final list = <BeliefEpisode>[...segmentEpisodes, ...classic];

          if (list.isEmpty) {
            return const BeliefEmptyState(title: '暂无关卡', subtitle: '段落未初始化或数据查询失败。');
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final ep = list[i];
              final key = 'episode:${ep.id}';
              final p = progress.where((x) => x.key == key).toList();
              final status = p.isEmpty ? 0 : p.first.status;

              String badge = '未开始';
              if (status == 1) badge = '进行中';
              if (status == 2) badge = '已完成';

              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BeliefFlowPage(
                      kind: BeliefFlowKind.episode,
                      id: ep.id,
                      title: ep.title,
                      subtitle: ep.subtitle,
                      steps: ep.steps,
                    ),
                  ),
                ).then((_) => setState(() {})),
                borderRadius: BorderRadius.circular(18),
                child: BeliefSectionCard(
                  title: ep.title,
                  subtitle: '${ep.subtitle}\n状态：$badge',
                  icon: Icons.theaters_outlined,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BeliefFlowPage(
                        kind: BeliefFlowKind.episode,
                        id: ep.id,
                        title: ep.title,
                        subtitle: ep.subtitle,
                        steps: ep.steps,
                      ),
                    ),
                  ).then((_) => setState(() {})),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
