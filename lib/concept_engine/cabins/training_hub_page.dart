import 'package:flutter/material.dart';

import '../concept_engine_dao.dart';
import '../concept_engine_models.dart';
import '../concept_engine_service.dart';
import '../concept_engine_detail_page.dart';
import '../action_engine/pages/action_engine_home_page.dart';
import 'training_cabin_models.dart';
import 'training_intro_page.dart';
import 'training_growth_archive_page.dart';

class TrainingHubPage extends StatefulWidget {
  const TrainingHubPage({super.key});

  @override
  State<TrainingHubPage> createState() => _TrainingHubPageState();
}

class _TrainingHubPageState extends State<TrainingHubPage> {
  final _dao = ConceptEngineDao();
  final _service = ConceptEngineService();
  final _conceptCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();
  String _selectedDomain = '职场';
  TrainingCabinType _selectedCabin = TrainingCabinType.delayReport;
  ConceptWorldProfile? _profile;
  ConceptEngineRuntimeConfig? _cfg;
  List<ConceptEngineSessionRecord> _recent = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _conceptCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _dao.ensureSchema();
    final profile = await _dao.getWorldProfile();
    final recent = await _dao.listRecent(limit: 8);
    final cfg = await _service.loadRuntimeConfig();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _recent = recent;
      _cfg = cfg;
      _loading = false;
    });
  }

  void _openCabin(TrainingCabinDescriptor d) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainingCabinIntroPage(
          descriptor: d,
          concept: _conceptCtrl.text.trim().isEmpty ? d.defaultConcept : _conceptCtrl.text.trim(),
          goal: _goalCtrl.text.trim().isEmpty ? d.defaultGoal : _goalCtrl.text.trim(),
          domain: _selectedDomain,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final selectedDescriptor = cabinByType(_selectedCabin);
    return Scaffold(
      appBar: AppBar(title: const Text('训练舱大厅'), backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      backgroundColor: const Color(0xFFF7F7FB),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('现实实践训练舱', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('训练舱现在作为关键步骤强化器存在：先在概念行动引擎里生成行动树和行动链，再把关键动作送进训练舱预演。你也可以独立进入训练舱。', style: TextStyle(height: 1.45, color: Color(0xFF4B5563))),
                    const SizedBox(height: 12),
                    Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActionEngineHomePage())), icon: const Icon(Icons.account_tree_outlined), label: const Text('先从行动引擎生成行动树')))]),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _metaChip('当前提供商：${_cfg?.providerLabel ?? '未加载'}'),
                      _metaChip(_cfg?.model ?? ''),
                      if (_profile != null) _metaChip('Lv.${_profile!.level} · XP ${_profile!.totalXp} · 连胜 ${_profile!.streak}'),
                    ]),
                  ]),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  const Expanded(child: Text('首批训练舱', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainingGrowthArchivePage())),
                    icon: const Icon(Icons.insights_outlined),
                    label: const Text('成长档案'),
                  ),
                ]),
                const SizedBox(height: 10),
                ...trainingCabins.map((d) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: d.color, borderRadius: BorderRadius.circular(16)),
                            child: Icon(d.icon),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(d.subtitle, style: const TextStyle(color: Color(0xFF6B7280), height: 1.35)),
                          ])),
                        ]),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _metaChip('默认概念：${d.defaultConcept}'),
                          _metaChip('领域：${d.domain}'),
                          _metaChip('适合训练：${d.attitudes.take(2).join(' / ')}'),
                        ]),
                        const SizedBox(height: 12),
                        Wrap(spacing: 10, runSpacing: 10, children: [
                          FilledButton.icon(onPressed: () => _openCabin(d), icon: const Icon(Icons.play_arrow), label: const Text('进入训练舱')),
                          OutlinedButton(
                            onPressed: () => setState(() {
                              _selectedCabin = d.type;
                              _selectedDomain = d.domain;
                              _conceptCtrl.text = d.defaultConcept;
                              _goalCtrl.text = d.defaultGoal;
                            }),
                            child: const Text('设为下方自定义训练'),
                          ),
                        ]),
                      ]),
                    )),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('自定义进入训练舱', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<TrainingCabinType>(
                      value: _selectedCabin,
                      decoration: const InputDecoration(labelText: '训练舱类型'),
                      items: trainingCabins.map((e) => DropdownMenuItem(value: e.type, child: Text(e.title))).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        final d = cabinByType(v);
                        setState(() {
                          _selectedCabin = v;
                          _selectedDomain = d.domain;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _conceptCtrl, decoration: InputDecoration(labelText: '概念（默认：${selectedDescriptor.defaultConcept}）')),
                    const SizedBox(height: 10),
                    TextField(controller: _goalCtrl, decoration: InputDecoration(labelText: '训练目标（默认：${selectedDescriptor.defaultGoal}）'), minLines: 2, maxLines: 4),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedDomain,
                      decoration: const InputDecoration(labelText: '领域'),
                      items: const ['职场', '日常生活', '团队协作'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _selectedDomain = v ?? _selectedDomain),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _openCabin(selectedDescriptor),
                      icon: const Icon(Icons.rocket_launch_outlined),
                      label: const Text('开始这次训练'),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                const Text('最近训练', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ..._recent.map((e) => ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(e.sceneTitle.isNotEmpty ? e.sceneTitle : e.concept),
                      subtitle: Text('${e.domain} · ${e.goal}\n${e.summary}', maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(e.resultLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${e.totalScore}', style: const TextStyle(color: Color(0xFF6B7280))),
                      ]),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConceptEngineDetailPage(recordId: e.id))).then((_) => _load()),
                    )),
              ],
            ),
    );
  }

  Widget _metaChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(fontSize: 12.5)),
      );
}
