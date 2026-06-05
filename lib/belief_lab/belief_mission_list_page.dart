import 'package:flutter/material.dart';
import 'belief_levels.dart';
import 'belief_dao.dart';
import 'belief_models.dart';
import 'belief_flow_page.dart';
import 'belief_ui.dart';
import 'belief_action_consistency.dart';

class BeliefMissionListPage extends StatefulWidget {
  final String? filterConceptId;
  const BeliefMissionListPage({super.key, this.filterConceptId});

  @override
  State<BeliefMissionListPage> createState() => _BeliefMissionListPageState();
}

class _BeliefMissionListPageState extends State<BeliefMissionListPage> {
  final _dao = BeliefDao();

  @override
  Widget build(BuildContext context) {
    final list = widget.filterConceptId == null
        ? beliefMissions
        : beliefMissions.where((m) => m.conceptId == widget.filterConceptId).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.filterConceptId == null ? '行动：任务与复盘' : '行动：本概念任务')),
      body: FutureBuilder(
        future: _dao.listProgressByPrefix('mission:'),
        builder: (context, snap) {
          final progress = snap.data as List<BeliefProgress>? ?? const [];
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final m = list[i];
              final key = 'mission:${m.id}';
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
                      kind: BeliefFlowKind.mission,
                      id: m.id,
                      title: m.title,
                      subtitle: m.subtitle,
                      steps: BeliefActionConsistency.enhanceMissionSteps(m.steps),
                    ),
                  ),
                ).then((_) => setState(() {})),
                borderRadius: BorderRadius.circular(18),
                child: BeliefSectionCard(
                  title: m.title,
                  subtitle: '${m.subtitle}\n状态：$badge',
                  icon: Icons.checklist_outlined,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BeliefFlowPage(
                        kind: BeliefFlowKind.mission,
                        id: m.id,
                        title: m.title,
                        subtitle: m.subtitle,
                        steps: BeliefActionConsistency.enhanceMissionSteps(m.steps),
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
