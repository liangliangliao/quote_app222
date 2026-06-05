import 'package:flutter/material.dart';

import '../models/action_engine_models.dart';
import '../repository/action_engine_repository.dart';
import 'action_breakdown_page.dart';

class ActionConceptTreePage extends StatefulWidget {
  final String concept;
  final String goal;
  final String domain;
  final List<String> dimensions;

  const ActionConceptTreePage({
    super.key,
    required this.concept,
    required this.goal,
    required this.domain,
    this.dimensions = const [],
  });

  @override
  State<ActionConceptTreePage> createState() => _ActionConceptTreePageState();
}

class _ActionConceptTreePageState extends State<ActionConceptTreePage> {
  final _repo = ActionEngineRepository();
  ActionConcept? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.generateConceptTree(
        concept: widget.concept,
        goal: widget.goal,
        domain: widget.domain,
        dimensions: widget.dimensions,
        sessionId: 'action_tree_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('行动树 · ${widget.concept}'), backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      backgroundColor: const Color(0xFFF7F7FB),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.concept, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('AI 正在从多个维度生成行动树：至少 10 个行动，每个行动继续细化到多个可执行步骤。', style: TextStyle(color: Color(0xFF4B5563), height: 1.45)),
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(minHeight: 10, borderRadius: BorderRadius.all(Radius.circular(999))),
                    const SizedBox(height: 10),
                    Text(widget.dimensions.isEmpty ? '未指定维度，系统自动扩展维度中…' : '当前维度：${widget.dimensions.join(' / ')}', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  ]),
                ),
              ],
            )
          : _error != null
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('生成行动树失败', style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(height: 1.45)),
                        const SizedBox(height: 12),
                        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('重试')),
                      ]),
                    ),
                  ],
                )
              : _buildContent(context, _data!),
    );
  }

  Widget _buildContent(BuildContext context, ActionConcept data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data.concept, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(data.shortDescription, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (widget.goal.isNotEmpty) _pill('当前目标：${widget.goal}'),
              _pill('语境：${widget.domain}'),
              _pill('行动数：${data.directions.length}'),
              _pill(data.generatedByAi ? 'AI 生成' : '本地 fallback'),
              _pill('支持按需展开与补充更多实现路径'),
            ]),
            if (data.dimensions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: data.dimensions.map((e) => _pill('维度：$e')).toList()),
            ],
            if (data.generationNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(data.generationNote, style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        const Text('行动方向（至少 10 个）', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...data.directions.map((direction) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ActionBreakdownPage(
                      concept: data,
                      direction: direction,
                      goal: widget.goal,
                      domain: widget.domain,
                    ),
                  ));
                },
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(direction.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
                    const Icon(Icons.chevron_right),
                  ]),
                  const SizedBox(height: 8),
                  Text(direction.description, style: const TextStyle(height: 1.45, color: Color(0xFF374151))),
                  const SizedBox(height: 10),
                  _SectionCard(
                    title: '这一层在现实里意味着什么',
                    content: direction.realityMeaning.isNotEmpty ? direction.realityMeaning : '它不是抽象原则，而是一条现实行动方案：今天会有一个动作真的发生。',
                  ),
                  const SizedBox(height: 8),
                  _SectionCard(
                    title: '如果它真的成立，你会看到什么变化',
                    contentWidget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in (direction.observableChanges.isNotEmpty ? direction.observableChanges : const ['会出现一个看得见的推进和痕迹。']))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(color: Color(0xFF4338CA), fontWeight: FontWeight.w700)),
                                Expanded(child: Text(item, style: const TextStyle(height: 1.45, color: Color(0xFF374151)))),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _FactCard(
                    title: '经验事实',
                    fact: direction.experienceFact.isNotEmpty ? direction.experienceFact : '今天这件事已经发生了，并且留下了一个可见结果。',
                    doneSignal: direction.factDoneSignal,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${direction.displayModuleCount} 个模块 · ${direction.displayStepCount} 个可执行步骤${direction.needsExpansion ? ' · 进入后展开' : ''}',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                  ),
                ]),
              ),
            )),
      ],
    );
  }

  Widget _SectionCard({
    required String title,
    String? content,
    Widget? contentWidget,
  }) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          contentWidget ?? Text(content ?? '', style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
        ]),
      );

  Widget _FactCard({
    required String title,
    required String fact,
    String? doneSignal,
  }) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(fact, style: const TextStyle(color: Color(0xFF312E81), height: 1.6, fontWeight: FontWeight.w600)),
          if ((doneSignal ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('完成标志：${doneSignal!.trim()}', style: const TextStyle(color: Color(0xFF4338CA), height: 1.45)),
          ],
        ]),
      );

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151))),
      );
}
