import 'package:flutter/material.dart';

import 'training_cabin_models.dart';
import 'training_prep_page.dart';

class TrainingCabinIntroPage extends StatefulWidget {
  final TrainingCabinDescriptor descriptor;
  final String concept;
  final String goal;
  final String domain;
  final bool returnToActionChain;
  final String? linkedPlanId;
  final String? linkedStepId;

  const TrainingCabinIntroPage({
    super.key,
    required this.descriptor,
    required this.concept,
    required this.goal,
    required this.domain,
    this.returnToActionChain = false,
    this.linkedPlanId,
    this.linkedStepId,
  });

  @override
  State<TrainingCabinIntroPage> createState() => _TrainingCabinIntroPageState();
}

class _TrainingCabinIntroPageState extends State<TrainingCabinIntroPage> {
  String? _selectedAttitude;
  final Set<String> _selectedPrompts = <String>{};
  bool _ritualDone = false;

  void _goNext() {
    if (_selectedAttitude == null || !_ritualDone) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TrainingCabinPrepPage(
          descriptor: widget.descriptor,
          concept: widget.concept,
          goal: widget.goal,
          domain: widget.domain,
          selectedAttitude: _selectedAttitude!,
          selectedMindPrompts: _selectedPrompts.toList(),
          returnToActionChain: widget.returnToActionChain,
          linkedPlanId: widget.linkedPlanId,
          linkedStepId: widget.linkedStepId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.descriptor;
    final canNext = _selectedAttitude != null && _ritualDone;
    return Scaffold(
      appBar: AppBar(title: Text(d.title), backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      backgroundColor: const Color(0xFFF7F7FB),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: d.color, borderRadius: BorderRadius.circular(16)),
                  child: Icon(d.icon),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(d.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 12),
              Text(d.sceneNarration, style: const TextStyle(height: 1.5, color: Color(0xFF374151))),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _chip('角色：${d.roleLabel}'),
                _chip('目标：${d.missionLabel}'),
                _chip('概念：${widget.concept}'),
                _chip('领域：${widget.domain}'),
                if (widget.returnToActionChain) _chip('来自行动链关键步骤'),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          _Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('心像启动', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('先点出你最想逃避或最在意的部分，再进入行动。', style: TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 12),
              ...d.mindPrimingQuestions.map((q) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(q),
                    value: _selectedPrompts.contains(q),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedPrompts.add(q);
                        } else {
                          _selectedPrompts.remove(q);
                        }
                      });
                    },
                  )),
            ]),
          ),
          const SizedBox(height: 14),
          _Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('选择本轮态度', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: d.attitudes
                    .map((e) => ChoiceChip(
                          label: Text(e),
                          selected: _selectedAttitude == e,
                          onSelected: (_) => setState(() => _selectedAttitude = e),
                        ))
                    .toList(),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          _Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('启动动作', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('不是直接点下一步，而是先做一个进入行动的仪式动作。', style: TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 12),
              GestureDetector(
                onLongPress: () => setState(() => _ritualDone = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: _ritualDone ? const Color(0xFFDCFCE7) : const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      _ritualDone ? '已进入行动状态' : '长按 1.5 秒：我准备面对',
                      style: TextStyle(fontWeight: FontWeight.w700, color: _ritualDone ? const Color(0xFF166534) : const Color(0xFF3730A3)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: canNext ? _goNext : null,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('进入准备台'),
        ),
      ),
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(fontSize: 12.5)),
      );
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
