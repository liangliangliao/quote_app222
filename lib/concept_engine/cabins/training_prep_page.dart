import 'package:flutter/material.dart';

import 'training_action_page.dart';
import 'training_cabin_models.dart';

class TrainingCabinPrepPage extends StatefulWidget {
  final TrainingCabinDescriptor descriptor;
  final String concept;
  final String goal;
  final String domain;
  final String selectedAttitude;
  final List<String> selectedMindPrompts;
  final bool returnToActionChain;
  final String? linkedPlanId;
  final String? linkedStepId;

  const TrainingCabinPrepPage({
    super.key,
    required this.descriptor,
    required this.concept,
    required this.goal,
    required this.domain,
    required this.selectedAttitude,
    required this.selectedMindPrompts,
    this.returnToActionChain = false,
    this.linkedPlanId,
    this.linkedStepId,
  });

  @override
  State<TrainingCabinPrepPage> createState() => _TrainingCabinPrepPageState();
}

class _TrainingCabinPrepPageState extends State<TrainingCabinPrepPage> {
  late List<String> _facts;
  late List<String> _risks;
  late List<String> _actions;
  late List<String> _blocks;
  final Set<String> _selectedFacts = <String>{};

  @override
  void initState() {
    super.initState();
    _facts = [...widget.descriptor.facts];
    _risks = [...widget.descriptor.risks];
    _actions = [...widget.descriptor.actions];
    _blocks = [...widget.descriptor.expressionBlocks];
  }

  bool get _ready => _selectedFacts.length >= 3 && _risks.isNotEmpty && _actions.isNotEmpty && _blocks.isNotEmpty;

  void _move(List<String> list, int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= list.length) return;
    setState(() {
      final item = list.removeAt(index);
      list.insert(target, item);
    });
  }

  void _goNext() {
    if (!_ready) return;
    final draft = TrainingCabinRunDraft(
      descriptor: widget.descriptor,
      concept: widget.concept,
      goal: widget.goal,
      domain: widget.domain,
      selectedAttitude: widget.selectedAttitude,
      selectedMindPrompts: widget.selectedMindPrompts,
      prepState: CabinPrepState(
        selectedFacts: _selectedFacts.toList(),
        rankedRisks: [..._risks],
        orderedActions: [..._actions],
        expressionBlocks: [..._blocks],
        finalAttitude: widget.selectedAttitude,
      ),
      returnToActionChain: widget.returnToActionChain,
      linkedPlanId: widget.linkedPlanId,
      linkedStepId: widget.linkedStepId,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TrainingCabinActionPage(draft: draft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.descriptor.title} · 准备台'), backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      backgroundColor: const Color(0xFFF7F7FB),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StageHeader(title: '阶段 2 / 6 · 行动准备', subtitle: '先整理事实、风险、顺序和表达结构，再进入实战。'),
          const SizedBox(height: 14),
          _Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('① 选择关键事实（至少 3 项）', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _facts
                    .map(
                      (e) => FilterChip(
                        label: Text(e),
                        selected: _selectedFacts.contains(e),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _selectedFacts.add(e);
                          } else {
                            _selectedFacts.remove(e);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          _reorderCard('② 风险排序（从最重要到次要）', _risks, (index, delta) => _move(_risks, index, delta)),
          const SizedBox(height: 14),
          _reorderCard('③ 行动顺序（拖不动就用上下箭头快速排序）', _actions, (index, delta) => _move(_actions, index, delta)),
          const SizedBox(height: 14),
          _reorderCard('④ 表达结构（你准备怎样开口）', _blocks, (index, delta) => _move(_blocks, index, delta)),
          const SizedBox(height: 14),
          _Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('态度校准', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('你当前选择的是「${widget.selectedAttitude}」。建议先把“${_blocks.first}”和“${_actions.first}”做到最清楚。', style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
              const SizedBox(height: 8),
              Text('已选关键事实 ${_selectedFacts.length} 项；首要风险：${_risks.first}；第一步动作：${_actions.first}。', style: const TextStyle(color: Color(0xFF6B7280))),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _ready ? _goNext : null,
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('进入行动舱'),
        ),
      ),
    );
  }

  Widget _reorderCard(String title, List<String> items, void Function(int, int) onMove) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...List.generate(items.length, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              CircleAvatar(radius: 12, backgroundColor: const Color(0xFFE5E7EB), child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Colors.black87))),
              const SizedBox(width: 10),
              Expanded(child: Text(items[index])),
              IconButton(onPressed: index == 0 ? null : () => onMove(index, -1), icon: const Icon(Icons.keyboard_arrow_up)),
              IconButton(onPressed: index == items.length - 1 ? null : () => onMove(index, 1), icon: const Icon(Icons.keyboard_arrow_down)),
            ]),
          );
        }),
      ]),
    );
  }
}

class _StageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _StageHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }
}
