import 'package:flutter/material.dart';

import '../../concept_engine_service.dart';
import '../models/action_engine_models.dart';
import '../repository/action_engine_dao.dart';
import 'action_execution_page.dart';

class ActionPlanBuilderPage extends StatefulWidget {
  final ActionConcept concept;
  final ActionDirection direction;
  final String goal;
  final String domain;
  final List<ActionStep> initialSteps;

  const ActionPlanBuilderPage({
    super.key,
    required this.concept,
    required this.direction,
    required this.goal,
    required this.domain,
    required this.initialSteps,
  });

  @override
  State<ActionPlanBuilderPage> createState() => _ActionPlanBuilderPageState();
}

class _ActionPlanBuilderPageState extends State<ActionPlanBuilderPage> {
  final _titleCtrl = TextEditingController();
  final _customCtrl = TextEditingController();
  final _dao = ActionEngineDao();
  final _service = ConceptEngineService();
  late List<ActionStep> _steps;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _steps = List<ActionStep>.from(widget.initialSteps);
    _titleCtrl.text = '${widget.concept.concept} · ${widget.direction.title}';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  void _addCustom() {
    final text = _customCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _steps.add(ActionStep(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        isCustom: true,
        minimalVersion: text,
        tags: const ['custom'],
      ));
    });
    _customCtrl.clear();
  }

  Future<void> _saveAndExecute() async {
    if (_steps.isEmpty) return;
    setState(() => _saving = true);
    try {
      final cfg = await _service.loadRuntimeConfig();
      final plan = ActionPlan(
        planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
        concept: widget.concept.concept,
        goal: widget.goal,
        domain: widget.domain,
        title: _titleCtrl.text.trim().isEmpty ? '${widget.concept.concept}行动链' : _titleCtrl.text.trim(),
        provider: cfg.provider,
        model: cfg.model,
        transportMode: cfg.transportMode,
        sourceDirectionId: widget.direction.id,
        sourceDirectionTitle: widget.direction.title,
        steps: _steps,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _dao.savePlan(plan);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ActionExecutionPage(plan: plan)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('组装行动链'), backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      backgroundColor: const Color(0xFFF7F7FB),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _saveAndExecute,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
            label: Text(_saving ? '保存中...' : '保存并执行'),
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
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: '行动链标题',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              Text('概念：${widget.concept.concept} · 方向：${widget.direction.title}', style: const TextStyle(color: Color(0xFF4B5563))),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('拖拽排序你的行动链', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _steps.removeAt(oldIndex);
                    _steps.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return ListTile(
                    key: ValueKey(step.id),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    leading: CircleAvatar(radius: 14, child: Text('${index + 1}')),
                    title: Text(step.text),
                    subtitle: Text(step.isCustom ? '自定义步骤' : (step.minimalVersion == null ? '系统步骤' : '最小版：${step.minimalVersion}')),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _steps.removeAt(index)),
                    ),
                  );
                },
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('新增我的步骤', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              TextField(
                controller: _customCtrl,
                decoration: InputDecoration(
                  hintText: '例如：先发一条短消息说明现状',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: _addCustom, icon: const Icon(Icons.add), label: const Text('加入行动链')),
            ]),
          ),
        ],
      ),
    );
  }
}
