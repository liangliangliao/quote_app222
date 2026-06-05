
import 'package:flutter/material.dart';

import 'belief_action_models.dart';
import 'belief_action_seed.dart';
import 'belief_dao.dart';
import 'belief_flow_page.dart';
import 'belief_models.dart';
import 'belief_ui.dart';
import 'belief_action_template_editor_page.dart';
import 'belief_action_ai_generate_page.dart';
import 'belief_action_runtime.dart';

class BeliefActionTemplatesPage extends StatefulWidget {
  final String conceptId;
  final String conceptTitle;

  const BeliefActionTemplatesPage({super.key, required this.conceptId, required this.conceptTitle});

  @override
  State<BeliefActionTemplatesPage> createState() => _BeliefActionTemplatesPageState();
}

class _BeliefActionTemplatesPageState extends State<BeliefActionTemplatesPage> with SingleTickerProviderStateMixin {
  final _dao = BeliefDao();
  late final TabController _tab;

  String _catRoot = '全部';
  String _mode = '全部';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<BeliefActionTemplate> _seed() {
    final all = beliefActionTemplates.where((t) => t.conceptId == widget.conceptId).toList();
    all.sort((a, b) => a.categoryPath.compareTo(b.categoryPath));
    return all;
  }

  List<String> _categoryRoots(List<BeliefActionTemplate> seed) {
    final set = <String>{};
    for (final t in seed) {
      final parts = t.categoryParts;
      if (parts.isNotEmpty) set.add(parts.first);
    }
    final out = set.toList()..sort();
    return ['全部', ...out];
  }

  List<BeliefActionTemplate> _applyFilter(List<BeliefActionTemplate> list) {
    return list.where((t) {
      if (_catRoot != '全部') {
        final parts = t.categoryParts;
        if (parts.isEmpty || parts.first != _catRoot) return false;
      }
      if (_mode != '全部') {
        if (_mode == '计划模式' && t.mode != 'planned') return false;
        if (_mode == '非计划模式' && t.mode != 'quick') return false;
      }
      return true;
    }).toList();
  }

  Future<List<BeliefActionTemplate>> _loadUserTemplates() async {
    final rows = await _dao.listProgressByPrefix('actiontpl:${widget.conceptId}:');
    final out = <BeliefActionTemplate>[];
    for (final p in rows) {
      final t = BeliefActionTemplate.tryParseProgressPayload(p.payload);
      if (t != null) out.add(t);
    }
    out.sort((a, b) => b.id.compareTo(a.id));
    return out;
  }

  List<BeliefStep> _stepsFromTemplate(BeliefActionTemplate t) =>
      buildBeliefActionStepsFromTemplate(template: t, conceptTitle: widget.conceptTitle);

  Future<void> _startTemplateRun(BeliefActionTemplate t) async {
    // 每次启动生成一个 runId，保留历史。
    final ts = DateTime.now().millisecondsSinceEpoch;
    final runId = 'actionrun:${t.id}:$ts';

    final title = '行动模板：${t.title}';
    final subtitle = '${widget.conceptTitle} · ${t.modeLabel} · ${t.version}';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BeliefFlowPage(
          kind: BeliefFlowKind.mission,
          id: 'actionrun_${t.id}_$ts',
          title: title,
          subtitle: subtitle,
          steps: _stepsFromTemplate(t),
          progressKeyOverride: runId,
          extraPayload: {
            'title': title,
            'subtitle': subtitle,
            'conceptId': t.conceptId,
            'templateId': t.id,
            'template': t.toJson(),
          },
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openEditor({BeliefActionTemplate? initial}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BeliefActionTemplateEditorPage(
          conceptId: widget.conceptId,
          conceptTitle: widget.conceptTitle,
          initial: initial,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final seed = _seed();
    final roots = _categoryRoots(seed);

    return Scaffold(
      appBar: AppBar(
        title: Text('行动模板 · ${widget.conceptTitle}'),
        actions: [
          IconButton(
            tooltip: 'AI 生成',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BeliefActionAIGeneratePage(
                    conceptId: widget.conceptId,
                    conceptTitle: widget.conceptTitle,
                  ),
                ),
              );
              if (!mounted) return;
              setState(() {});
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '推荐模板'),
            Tab(text: '我的模板'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('自定义'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: roots
                          .map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(r),
                                selected: _catRoot == r,
                                onSelected: (_) => setState(() => _catRoot = r),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _mode,
                  items: const [
                    DropdownMenuItem(value: '全部', child: Text('全部')),
                    DropdownMenuItem(value: '计划模式', child: Text('计划模式')),
                    DropdownMenuItem(value: '非计划模式', child: Text('非计划模式')),
                  ],
                  onChanged: (v) => setState(() => _mode = v ?? '全部'),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildSeedTab(seed),
                _buildUserTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeedTab(List<BeliefActionTemplate> seedAll) {
    final seed = _applyFilter(seedAll);

    if (seed.isEmpty) {
      return const BeliefEmptyState(
        title: '暂无模板',
        subtitle: '你可以点右下角“自定义”，或点右上角用 AI 生成。',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 90),
      itemCount: seed.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final t = seed[i];
        final tags = <String>[
          t.modeLabel,
          t.version,
          if (t.categoryParts.isNotEmpty) t.categoryParts.first,
        ];
        return _TemplateCard(
          template: t,
          tags: tags,
          onStart: () => _startTemplateRun(t),
          onCopy: () => _openEditor(initial: t),
        );
      },
    );
  }

  Widget _buildUserTab() {
    return FutureBuilder<List<BeliefActionTemplate>>(
      future: _loadUserTemplates(),
      builder: (context, snap) {
        final listAll = snap.data ?? const <BeliefActionTemplate>[];
        final list = _applyFilter(listAll);

        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        if (list.isEmpty) {
          return const BeliefEmptyState(
            title: '还没有自定义模板',
            subtitle: '点右下角“自定义”创建，或从推荐模板“复制并改写”。',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 90),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final t = list[i];
            final tags = <String>[t.modeLabel, t.version, '自定义'];
            return _TemplateCard(
              template: t,
              tags: tags,
              onStart: () => _startTemplateRun(t),
              onCopy: () => _openEditor(initial: t),
              onEdit: () => _openEditor(initial: t),
              onDelete: () async {
                final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('删除模板？'),
                        content: Text('将删除：${t.title}'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
                        ],
                      ),
                    ) ??
                    false;
                if (!ok) return;
                await _dao.deleteProgress('actiontpl:${widget.conceptId}:${t.id}');
                if (!mounted) return;
                setState(() {});
              },
            );
          },
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final BeliefActionTemplate template;
  final List<String> tags;
  final VoidCallback onStart;
  final VoidCallback onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TemplateCard({
    required this.template,
    required this.tags,
    required this.onStart,
    required this.onCopy,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = '${template.categoryPath}\n${template.operationalDefinition}';
    return Material(
      color: Colors.white,
      elevation: 6,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    template.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Text(template.modeLabel, style: TextStyle(color: Colors.black.withOpacity(0.6))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.black.withOpacity(0.72), height: 1.35),
            ),
            const SizedBox(height: 10),
            Wrap(
              children: tags.map((t) => BeliefChip(t)).toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('开始行动'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy),
                  label: const Text('复制改写'),
                ),
                if (onEdit != null) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: '编辑',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
                if (onDelete != null) ...[
                  IconButton(
                    tooltip: '删除',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

