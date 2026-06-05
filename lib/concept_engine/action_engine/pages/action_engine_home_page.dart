import 'package:flutter/material.dart';

import '../../concept_engine_service.dart';
import '../../cabins/training_hub_page.dart';
import '../../concept_engine_world_page.dart';
import '../models/action_engine_models.dart';
import '../repository/action_engine_dao.dart';
import '../repository/action_engine_repository.dart';
import 'action_concept_tree_page.dart';
import 'action_execution_page.dart';
import 'action_growth_page.dart';

class ActionEngineHomePage extends StatefulWidget {
  const ActionEngineHomePage({super.key});

  @override
  State<ActionEngineHomePage> createState() => _ActionEngineHomePageState();
}

class _ActionEngineHomePageState extends State<ActionEngineHomePage> {
  final _repo = ActionEngineRepository();
  final _dao = ActionEngineDao();
  final _service = ConceptEngineService();
  final _conceptCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();
  final _domainCtrl = TextEditingController(text: '日常');
  final _dimensionsCtrl = TextEditingController(text: '启动,准备,执行,沟通,复盘');
  bool _loading = true;
  List<ActionPlan> _plans = const [];
  List<ActionGrowthSnapshot> _growth = const [];
  ConceptEngineRuntimeConfig? _cfg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _conceptCtrl.dispose();
    _goalCtrl.dispose();
    _domainCtrl.dispose();
    _dimensionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _dao.ensureSchema();
    final plans = await _dao.listPlans(limit: 20);
    final growth = await _dao.listGrowth();
    final cfg = await _service.loadRuntimeConfig();
    if (!mounted) return;
    setState(() {
      _plans = plans;
      _growth = growth;
      _cfg = cfg;
      _loading = false;
    });
  }

  List<String> _parsedDimensions() => _dimensionsCtrl.text
      .split(RegExp(r'[，,、\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _openConcept(String concept) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActionConceptTreePage(
          concept: concept,
          goal: _goalCtrl.text.trim(),
          domain: _domainCtrl.text.trim().isEmpty ? '日常' : _domainCtrl.text.trim(),
          dimensions: _parsedDimensions(),
        ),
      ),
    );
    _load();
  }

  Future<void> _resumePlan(ActionPlan plan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ActionExecutionPage(plan: plan)),
    );
    _load();
  }

  Future<void> _openTrainingHub() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainingHubPage()));
    _load();
  }

  Future<void> _openWorld() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConceptEngineWorldPage()));
    _load();
  }

  String _growthSummary() {
    if (_growth.isEmpty) return '还没有行动引擎记录，先从一个概念开始。';
    final top = _growth.first;
    final rate = (top.completionRate * 100).toStringAsFixed(0);
    return '最近最常练的是「${top.concept}」，完成率 $rate%，最常见异常：${top.mostCommonFrictionType.isEmpty ? '暂无' : top.mostCommonFrictionType}。';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('概念行动引擎'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: '行动成长',
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActionGrowthPage()));
              _load();
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F7FB),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('AI 概念 → 行动树 → 关键步骤进训练舱', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                const Text(
                  '输入一个概念后，AI 会从不同维度至少生成 10 个行动，每个行动继续细化为多个具体可执行步骤。你可以直接选，也可以自定义自己的现实做法；关键步骤再进入训练舱强化。',
                  style: TextStyle(color: Color(0xFF4B5563), height: 1.45),
                ),
                const SizedBox(height: 14),
                if (_cfg != null)
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _chip(_cfg!.providerLabel),
                    _chip(_cfg!.model.isEmpty ? '未设置模型' : _cfg!.model),
                    _chip(_cfg!.transportMode == ConceptEngineService.transportProxy ? '后端网关代理' : '客户端直连'),
                  ]),
                const SizedBox(height: 16),
                TextField(
                  controller: _conceptCtrl,
                  decoration: _inputDecoration('输入概念，例如：责任感 / 边界感 / 自律 / 领导力'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _goalCtrl,
                  decoration: _inputDecoration('当前目标，例如：今天把延期情况说明清楚'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _domainCtrl,
                  decoration: _inputDecoration('语境，例如：职场 / 日常 / 团队'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _dimensionsCtrl,
                  minLines: 1,
                  maxLines: 3,
                  decoration: _inputDecoration('维度（可选，逗号分隔），例如：启动,沟通,执行,复盘,协作'),
                ),
                const SizedBox(height: 8),
                const Text('如果不填，系统会自动从多个维度生成。维度越明确，行动树越贴近你的需要。', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () {
                    final concept = _conceptCtrl.text.trim();
                    if (concept.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先输入一个概念。')));
                      return;
                    }
                    _openConcept(concept);
                  },
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('AI 生成行动树（至少10个行动）'),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('快捷概念', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _repo.recommendedConcepts.map((e) => ActionChip(label: Text(e), onPressed: () => _openConcept(e))).toList(),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('成长摘要与强化入口', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(_growthSummary(), style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
                const SizedBox(height: 10),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActionGrowthPage()));
                      _load();
                    },
                    icon: const Icon(Icons.insights_outlined),
                    label: const Text('查看行动成长'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openTrainingHub,
                    icon: const Icon(Icons.fitness_center_outlined),
                    label: const Text('关键步骤训练舱'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openWorld,
                    icon: const Icon(Icons.travel_explore_outlined),
                    label: const Text('世界成长反馈'),
                  ),
                ])
              ]),
            ),
            const SizedBox(height: 16),
            const Text('最近行动链', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_plans.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: const Text('还没有保存的行动链。先从一个概念开始，把它拆成行动。'),
              )
            else
              ..._plans.map((plan) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                    child: ListTile(
                      title: Text(plan.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${plan.concept} · ${plan.goal.isEmpty ? '未写目标' : plan.goal}\n${plan.steps.length} 个步骤 · ${plan.sourceDirectionTitle ?? '自定义行动链'}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _resumePlan(plan),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151))),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );
}
