import 'package:flutter/material.dart';
import 'belief_dao.dart';
import 'belief_levels.dart';
import 'belief_models.dart';
import 'belief_flow_page.dart';
import 'belief_ui.dart';
import 'belief_action_consistency.dart';
import 'belief_action_models.dart';
import 'belief_action_runtime.dart';

class BeliefStatsPage extends StatefulWidget {
  const BeliefStatsPage({super.key});

  @override
  State<BeliefStatsPage> createState() => _BeliefStatsPageState();
}

class _BeliefStatsPageState extends State<BeliefStatsPage> {
  final _dao = BeliefDao();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('统计：进度与复盘')),
      body: FutureBuilder(
        future: Future.wait([
          _dao.listSegments(),
          _dao.listProgressByPrefix('episode:'),
          _dao.listProgressByPrefix('mission:'),
          _dao.listProgressByPrefix('actionrun:'),
        ]),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final segs = snap.data![0] as List<BeliefSegment>;
          final eps = snap.data![1] as List<BeliefProgress>;
          final mss = snap.data![2] as List<BeliefProgress>;
          final runs = snap.data![3] as List<BeliefProgress>;

          int epDone = eps.where((p) => p.status == 2).length;
          int epDoing = eps.where((p) => p.status == 1).length;
          int msDone = mss.where((p) => p.status == 2).length;
          int msDoing = mss.where((p) => p.status == 1).length;
          int runDone = runs.where((p) => p.status == 2).length;
          int runDoing = runs.where((p) => p.status == 1).length;

          final recent = [...eps, ...mss, ...runs]..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
          final recentTop = recent.take(12).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              _StatGrid(
                items: [
                  _StatItem(label: '段落', value: '${segs.length}'),
                  _StatItem(label: '案例完成', value: '$epDone/${beliefEpisodes.length}'),
                  _StatItem(label: '案例进行中', value: '$epDoing'),
                  _StatItem(label: '行动完成', value: '$msDone/${beliefMissions.length}'),
                  _StatItem(label: '行动进行中', value: '$msDoing'),
                  _StatItem(label: '模板行动完成', value: '$runDone'),
                  _StatItem(label: '模板行动进行中', value: '$runDoing'),
                ],
              ),
              const SizedBox(height: 16),
              const Text('最近活动', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (recentTop.isEmpty)
                const BeliefEmptyState(title: '还没有进度', subtitle: '去做一个“案例重演”或“行动任务”，这里就会出现记录。')
              else
                ...recentTop.map((p) => _ProgressTile(progress: p, onOpen: () => _openProgress(context, p))),
            ],
          );
        },
      ),
    );
  }

  void _openProgress(BuildContext context, BeliefProgress p) {
    final key = p.key;
    if (key.startsWith('episode:')) {
      final id = key.substring('episode:'.length);
      final ep = beliefEpisodes.where((e) => e.id == id).toList();
      if (ep.isEmpty) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BeliefFlowPage(
            kind: BeliefFlowKind.episode,
            id: ep.first.id,
            title: ep.first.title,
            subtitle: ep.first.subtitle,
            steps: ep.first.steps,
          ),
        ),
      ).then((_) => setState(() {}));
    } else if (key.startsWith('mission:')) {
      final id = key.substring('mission:'.length);
      final ms = beliefMissions.where((m) => m.id == id).toList();
      if (ms.isEmpty) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BeliefFlowPage(
            kind: BeliefFlowKind.mission,
            id: ms.first.id,
            title: ms.first.title,
            subtitle: ms.first.subtitle,
            steps: BeliefActionConsistency.enhanceMissionSteps(ms.first.steps),
          ),
        ),
      ).then((_) => setState(() {}));
    } else if (key.startsWith('actionrun:')) {
      final payload = p.payload;
      final tpl = BeliefActionTemplate.tryParseProgressPayload(payload);
      if (tpl == null) return;

      final conceptId = (payload['conceptId'] ?? tpl.conceptId).toString();
      String conceptTitle = conceptId;
      try {
        conceptTitle = getConceptById(conceptId).title;
      } catch (_) {}

      final title = (payload['title'] ?? '行动模板：${tpl.title}').toString();
      final subtitle = (payload['subtitle'] ?? '${conceptTitle} · ${tpl.modeLabel} · ${tpl.version}').toString();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BeliefFlowPage(
            kind: BeliefFlowKind.mission,
            id: key,
            title: title,
            subtitle: subtitle,
            steps: buildBeliefActionStepsFromTemplate(template: tpl, conceptTitle: conceptTitle),
            progressKeyOverride: key,
          ),
        ),
      ).then((_) => setState(() {}));
    }
  }
}

class _ProgressTile extends StatelessWidget {
  final BeliefProgress progress;
  final VoidCallback onOpen;

  const _ProgressTile({required this.progress, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    String kind = progress.key.startsWith('episode:')
        ? '案例'
        : progress.key.startsWith('mission:')
            ? '行动'
            : progress.key.startsWith('actionrun:')
                ? '模板行动'
                : '记录';
    String status = '未开始';
    if (progress.status == 1) status = '进行中';
    if (progress.status == 2) status = '已完成';

    final dt = DateTime.fromMillisecondsSinceEpoch(progress.updatedAtMs);
    final when = '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    final title = (progress.payload['title'] ?? progress.key).toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onOpen,
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
                child: Text('$kind · $status', style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(when, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.65))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black45),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});
}

class _StatGrid extends StatelessWidget {
  final List<_StatItem> items;
  const _StatGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        runSpacing: 12,
        spacing: 12,
        children: items
            .map(
              (it) => Container(
                width: (MediaQuery.of(context).size.width - 18 * 2 - 14 * 2 - 12) / 2,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(it.label, style: TextStyle(color: Colors.black.withOpacity(0.65))),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
