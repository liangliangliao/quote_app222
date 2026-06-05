import 'package:flutter/material.dart';

import '../models/action_engine_models.dart';
import '../repository/action_engine_repository.dart';
import 'action_plan_builder_page.dart';

class ActionBreakdownPage extends StatefulWidget {
  final ActionConcept concept;
  final ActionDirection direction;
  final String goal;
  final String domain;

  const ActionBreakdownPage({
    super.key,
    required this.concept,
    required this.direction,
    required this.goal,
    required this.domain,
  });

  @override
  State<ActionBreakdownPage> createState() => _ActionBreakdownPageState();
}

class _ActionBreakdownPageState extends State<ActionBreakdownPage> {
  final _repo = ActionEngineRepository();
  final Set<String> _selected = <String>{};
  final TextEditingController _customCtrl = TextEditingController();
  final List<ActionStep> _customSteps = [];
  late ActionDirection _direction;
  bool _loadingExpand = false;
  String? _expandError;
  bool _expandingCustom = false;
  bool _expandingMorePaths = false;

  @override
  void initState() {
    super.initState();
    _direction = widget.direction;
    if (_direction.needsExpansion || _direction.modules.isEmpty || _direction.stepCount == 0) {
      _expandDirection();
    }
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _expandDirection() async {
    setState(() {
      _loadingExpand = true;
      _expandError = null;
    });
    try {
      final expanded = await _repo.expandDirection(
        concept: widget.concept,
        direction: _direction,
        goal: widget.goal,
        domain: widget.domain,
        sessionId: 'expand_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      setState(() => _direction = expanded);
    } catch (e) {
      if (!mounted) return;
      setState(() => _expandError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingExpand = false);
    }
  }

  Future<void> _expandMorePaths() async {
    setState(() => _expandingMorePaths = true);
    try {
      final expanded = await _repo.expandDirectionMorePaths(
        concept: widget.concept,
        direction: _direction,
        goal: widget.goal,
        domain: widget.domain,
        sessionId: 'more_paths_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      setState(() => _direction = expanded);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已补充更多实现路径，可从不同做法中选择更适合自己的方案。')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扩展更多实现路径失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _expandingMorePaths = false);
    }
  }

  void _toggleStep(ActionStep step, bool value) {
    setState(() {
      if (value) {
        _selected.add(step.id);
      } else {
        _selected.remove(step.id);
      }
    });
  }

  Future<void> _addCustomStep() async {
    final text = _customCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _expandingCustom = true);
    try {
      final expanded = await _repo.expandCustomStep(
        concept: widget.concept,
        goal: widget.goal,
        domain: widget.domain,
        customStep: text,
        sessionId: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      setState(() {
        _customSteps.addAll(expanded);
        _selected.addAll(expanded.map((e) => e.id));
      });
      _customCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已将“$text”扩展为 ${expanded.length} 个可执行动作。')),
        );
      }
    } catch (_) {
      final step = ActionStep(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        isCustom: true,
        minimalVersion: text,
        tags: const ['custom'],
      );
      setState(() {
        _customSteps.add(step);
        _selected.add(step.id);
      });
      _customCtrl.clear();
    } finally {
      if (mounted) setState(() => _expandingCustom = false);
    }
  }

  List<ActionStep> get _selectedSteps {
    final all = <ActionStep>[];
    for (final m in _direction.modules) {
      all.addAll(m.steps);
    }
    all.addAll(_customSteps);
    return all.where((s) => _selected.contains(s.id)).toList();
  }

  String _layerMeaning(ActionModule module) {
    if (module.realityMeaning.trim().isNotEmpty) return module.realityMeaning.trim();
    final src = '${widget.concept.concept} ${_direction.title} ${module.title}';
    if (_containsAny(src, ['学习', '成长', '习惯', '课程', '资料', '英语', '技能'])) {
      return '在这一层，“${widget.concept.concept}”不是想法或计划，而是今天真的会发生一次学习动作：有开始时间、有学习入口、有一段学习过程、最后留下一条学习痕迹。';
    }
    if (_containsAny(src, ['边界', '拒绝', '范围', '拉扯'])) {
      return '在这一层，“${widget.concept.concept}”不是心里知道自己不想答应，而是现实里真的说清楚边界，别人能听见、你自己也没有继续往回退。';
    }
    if (_containsAny(src, ['责任', '汇报', '延期', '领导', '客户', '说明'])) {
      return '在这一层，“${widget.concept.concept}”不是觉得自己该负责，而是现实里已经把情况说明出去：状态、影响和下一步都能被对方看见。';
    }
    if (_containsAny(src, ['自律', '启动', '拖延', '开始'])) {
      return '在这一层，“${widget.concept.concept}”不是想开始，而是现实里已经出现了第一轮动作：入口打开了、计时开始了、第一步已经在做。';
    }
    return '在这一层，“${widget.concept.concept}”指的是让“${_direction.title}”在现实里真的发生，而不是只停留在脑内期待。';
  }

  List<String> _observableChanges(ActionModule module) {
    if (module.observableChanges.isNotEmpty) return module.observableChanges;
    final src = '${widget.concept.concept} ${_direction.title} ${module.title}';
    if (_containsAny(src, ['学习', '成长', '习惯', '课程', '资料', '英语', '技能'])) {
      return const [
        '一天里会出现一个固定的学习开始时刻。',
        '学习入口会被真正打开，而不是停留在“等会再学”。',
        '学习后会留下可见痕迹，比如一句总结、一页笔记或一个要点。',
      ];
    }
    if (_containsAny(src, ['边界', '拒绝', '范围', '拉扯'])) {
      return const [
        '你会真正说出不能答应的部分。',
        '对话里会出现清楚的范围，而不是继续拉扯。',
        '你不会因为愧疚又把边界收回去。',
      ];
    }
    if (_containsAny(src, ['责任', '汇报', '延期', '领导', '客户', '说明'])) {
      return const [
        '对方会收到一条清楚的说明。',
        '说明里会出现影响范围和下一次更新时间。',
        '事情不再停留在“我之后再说”，而是已经进入可追踪状态。',
      ];
    }
    if (_containsAny(src, ['自律', '启动', '拖延', '开始'])) {
      return const [
        '一个最强干扰会先被关掉。',
        '任务入口会被打开。',
        '第一轮 3-10 分钟的动作已经开始，而不是还在等状态。',
      ];
    }
    return [
      '会出现一个今天真的会发生的动作。',
      '会留下一个可见结果，而不是只停在想法里。',
    ];
  }

  String _experienceFact(ActionModule module) {
    if (module.experienceFact.trim().isNotEmpty) return module.experienceFact.trim();
    final actions = _actionBullets(module);
    final lastDone = module.factDoneSignal.trim().isNotEmpty
        ? module.factDoneSignal.trim()
        : (module.steps.firstWhere(
            (e) => (e.doneSignal?.trim().isNotEmpty ?? false),
            orElse: () => module.steps.isNotEmpty ? module.steps.first : const ActionStep(id: 'none', text: ''),
          ).doneSignal ?? '你已经留下一个别人或你自己都能看见的结果。');
    if (actions.isNotEmpty) {
      return '当这一层真正发生时，现实里会像这样：${actions.take(2).join('；')}；最后，$lastDone';
    }
    return '当这一层真正发生时，现实里会出现一个可以被直接看见和确认的动作结果。';
  }

  List<String> _actionBullets(ActionModule module) {
    final steps = module.steps.take(3).toList();
    if (steps.isEmpty) return const [];
    return steps
        .map((s) {
          final v = (s.directInstruction?.trim().isNotEmpty ?? false)
              ? s.directInstruction!.trim()
              : s.text.trim();
          return v.endsWith('。') ? v.substring(0, v.length - 1) : v;
        })
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _moduleDoneSignal(ActionModule module) {
    if (module.factDoneSignal.trim().isNotEmpty) return module.factDoneSignal.trim();
    for (final step in module.steps) {
      if (step.doneSignal?.trim().isNotEmpty ?? false) return step.doneSignal!.trim();
    }
    return '你自己或别人能清楚看到，这一层对应的现实动作已经发生。';
  }

  bool _containsAny(String source, List<String> terms) => terms.any((t) => source.contains(t));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_direction.title} · 行动拆解'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF7F7FB),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: (_selectedSteps.isEmpty || _loadingExpand)
                ? null
                : () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ActionPlanBuilderPage(
                        concept: widget.concept,
                        direction: _direction,
                        goal: widget.goal,
                        domain: widget.domain,
                        initialSteps: _selectedSteps,
                      ),
                    ));
                  },
            icon: const Icon(Icons.playlist_add_check_circle_outlined),
            label: Text('加入行动链（${_selectedSteps.length}）'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_direction.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(_direction.description, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
              const SizedBox(height: 12),
              if (widget.goal.isNotEmpty) Text('当前目标：${widget.goal}', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              const SizedBox(height: 6),
              if (widget.concept.dimensions.isNotEmpty) Text('当前维度：${widget.concept.dimensions.join(' / ')}', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              const SizedBox(height: 6),
              Text(
                _direction.needsExpansion || _direction.modules.isEmpty
                    ? '进入后先展开这条路径，再把它一步步压到现实里能看见的经验事实。'
                    : '这里先把概念继续往下压：压到现实里意味着什么、会看到什么变化、最后会长成一个什么经验事实。下面的动作，只是为了把那个事实做出来。',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.45),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: (_loadingExpand || _expandingMorePaths) ? null : _expandMorePaths,
                  icon: _expandingMorePaths
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_mosaic),
                  label: Text(_expandingMorePaths ? 'AI 扩展中…' : 'AI 补充更多实现路径'),
                ),
                if (_direction.modules.isNotEmpty)
                  Text(
                    '当前 ${_direction.modules.length} 个模块 · ${_direction.stepCount} 个步骤',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                  ),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          if (_loadingExpand)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                const LinearProgressIndicator(minHeight: 8, borderRadius: BorderRadius.all(Radius.circular(999))),
                const SizedBox(height: 12),
                Text('AI 正在把“${_direction.title}”压到更贴近现实的经验事实和可执行动作…', style: const TextStyle(color: Color(0xFF4B5563))),
              ]),
            ),
          if (_expandError != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('展开失败', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(_expandError!, style: const TextStyle(color: Color(0xFFB91C1C))),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: _expandDirection, icon: const Icon(Icons.refresh), label: const Text('重试展开')),
              ]),
            ),
          if (!_loadingExpand && _direction.modules.isNotEmpty) ...[
            ..._direction.modules.map((module) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(module.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(height: 10),
                    _InfoBlock(label: '这一层在现实里意味着什么', child: Text(_layerMeaning(module), style: const TextStyle(color: Color(0xFF374151), height: 1.6))),
                    const SizedBox(height: 10),
                    _InfoBlock(
                      label: '如果这一层真的成立，你会看到什么变化',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final item in _observableChanges(module))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(color: Color(0xFF4338CA), fontWeight: FontWeight.w700)),
                                  Expanded(child: Text(item, style: const TextStyle(color: Color(0xFF374151), height: 1.5))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _InfoBlock(label: '把概念压到最后，会变成这样一个经验事实', child: Text(_experienceFact(module), style: const TextStyle(color: Color(0xFF111827), height: 1.6, fontWeight: FontWeight.w600))),
                    const SizedBox(height: 10),
                    _InfoBlock(
                      label: '为了让这个经验事实发生，先做这些动作',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final item in _actionBullets(module))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('1. ', style: TextStyle(color: Color(0xFF4338CA), fontWeight: FontWeight.w700)),
                                  Expanded(child: Text(item, style: const TextStyle(color: Color(0xFF374151), height: 1.5))),
                                ],
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text('完成标志：${_moduleDoneSignal(module)}', style: const TextStyle(color: Color(0xFF4B5563), height: 1.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('可勾选动作', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...module.steps.map((step) {
                      final checked = _selected.contains(step.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) => _toggleStep(step, v ?? false),
                        title: Row(children: [
                          Expanded(child: Text(step.text)),
                          if (step.shouldSuggestCabin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(999)),
                              child: Text(step.importance == 'critical' ? '关键强化' : '可预演', style: const TextStyle(fontSize: 11, color: Color(0xFF075985))),
                            )
                        ]),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (step.directInstruction != null && step.directInstruction!.trim().isNotEmpty)
                              Text('直接照做：${step.directInstruction!}'),
                            if (step.doneSignal != null && step.doneSignal!.trim().isNotEmpty)
                              Text('做到什么算真的发生：${step.doneSignal!}'),
                            if (step.example != null && step.example!.trim().isNotEmpty)
                              Text('现实里像这样：${step.example!}'),
                            if (step.minimalVersion != null && step.minimalVersion!.trim().isNotEmpty)
                              Text('如果暂时做不到，先做这个最小版：${step.minimalVersion}${step.linkedCabinType != null ? ' · 可进训练舱' : ''}'),
                          ],
                        ),
                        isThreeLine: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ]),
                )),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('新增自定义动作', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              TextField(
                controller: _customCtrl,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '例如：今晚 8 点先打开课程，只学 10 分钟并写一句总结',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _expandingCustom ? null : _addCustomStep,
                icon: _expandingCustom
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(_expandingCustom ? 'AI 正在扩展动作…' : 'AI 扩展为更现实的可执行动作'),
              ),
              const SizedBox(height: 8),
              const Text('说明：请尽量直接写“会发生的现实动作”，系统会把它继续往下压成更容易看见、做出和验证的动作。', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
              if (_customSteps.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._customSteps.map((e) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Checkbox(
                        value: _selected.contains(e.id),
                        onChanged: (v) => _toggleStep(e, v ?? false),
                      ),
                      title: Text(e.text),
                      subtitle: Text(((e.directInstruction?.isNotEmpty == true) ? '直接照做：${e.directInstruction}' : (e.isCustom ? '自定义 / AI 扩展动作' : '动作'))),
                    )),
              ]
            ]),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String label;
  final Widget child;
  const _InfoBlock({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
