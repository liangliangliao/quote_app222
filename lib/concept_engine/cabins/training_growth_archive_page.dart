import 'package:flutter/material.dart';

import '../concept_engine_dao.dart';
import '../concept_engine_detail_page.dart';
import '../concept_engine_models.dart';

class TrainingGrowthArchivePage extends StatefulWidget {
  const TrainingGrowthArchivePage({super.key});

  @override
  State<TrainingGrowthArchivePage> createState() => _TrainingGrowthArchivePageState();
}

class _TrainingGrowthArchivePageState extends State<TrainingGrowthArchivePage> {
  final _dao = ConceptEngineDao();
  bool _loading = true;
  ConceptWorldProfile? _profile;
  List<ConceptEngineSessionRecord> _records = const [];
  Map<String, dynamic> _processInsights = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _dao.ensureSchema();
    final profile = await _dao.getWorldProfile();
    final records = await _dao.listRecent(limit: 80);
    final processInsights = await _dao.getCabinProcessInsights(limit: 400);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _records = records;
      _processInsights = processInsights;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile ?? ConceptWorldProfile.initial();
    final successCount = _records.where((e) => e.resultLabel.contains('成功')).length;
    final avgScore = _records.isEmpty ? 0 : (_records.map((e) => e.totalScore).reduce((a, b) => a + b) / _records.length).round();

    final providerCounts = <String, int>{};
    final domainCounts = <String, int>{};
    final weaknessCounts = <String, int>{};
    for (final r in _records) {
      providerCounts[r.providerLabel] = (providerCounts[r.providerLabel] ?? 0) + 1;
      domainCounts[r.domain.isEmpty ? '未标注' : r.domain] = (domainCounts[r.domain.isEmpty ? '未标注' : r.domain] ?? 0) + 1;
      for (final m in r.replayOrNull?.mistakes ?? const <String>[]) {
        weaknessCounts[m] = (weaknessCounts[m] ?? 0) + 1;
      }
    }
    final topWeaknesses = weaknessCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final bestRecords = [..._records]..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    final cabinBuckets = <String, List<ConceptEngineSessionRecord>>{};
    for (final r in _records) {
      final key = _inferCabinLabel(r);
      cabinBuckets.putIfAbsent(key, () => []).add(r);
    }
    final cabinSummaries = cabinBuckets.entries.map((e) {
      final runs = e.value;
      final avg = runs.isEmpty ? 0 : (runs.map((x) => x.totalScore).reduce((a,b)=>a+b) / runs.length).round();
      final success = runs.where((x) => x.resultLabel.contains('成功')).length;
      return {'label': e.key, 'runs': runs.length, 'avg': avg, 'success': success};
    }).toList()..sort((a,b)=> (b['runs'] as int).compareTo(a['runs'] as int));

    final processAttitudes = Map<String, int>.from((_processInsights['attitudes'] as Map?) ?? const {});
    final impactDecisions = Map<String, int>.from((_processInsights['impact_decisions'] as Map?) ?? const {});
    final stageCounts = Map<String, int>.from((_processInsights['stages'] as Map?) ?? const {});
    final topAttitudes = processAttitudes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topImpactDecisions = impactDecisions.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('训练舱成长档案'), backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      backgroundColor: const Color(0xFFF7F7FB),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('成长总览', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _pill('Lv.${profile.level}'),
                        _pill('总 XP ${profile.totalXp}'),
                        _pill('训练 ${profile.totalRuns} 次'),
                        _pill('成功 ${profile.successfulRuns} 次'),
                        _pill('当前连胜 ${profile.streak}'),
                        _pill('平均分 $avgScore'),
                      ]),
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: (profile.xpIntoCurrentLevel.clamp(0, 100)) / 100,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      const SizedBox(height: 8),
                      Text('距离下一级还差 ${profile.xpToNextLevel} XP', style: const TextStyle(color: Color(0xFF6B7280))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('现实行动画像', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _kv('成功率', _records.isEmpty ? '--' : '${((successCount / _records.length) * 100).round()}%')),
                        Expanded(child: _kv('最近模型', _records.isEmpty ? '--' : _records.first.providerLabel)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _kv('最常训练领域', domainCounts.entries.isEmpty ? '--' : (domainCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key)),
                        Expanded(child: _kv('最近高分', bestRecords.isEmpty ? '--' : '${bestRecords.first.totalScore}分')),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('薄弱点与训练建议', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      if (topWeaknesses.isEmpty)
                        const Text('还没有足够训练数据，先完成几次训练舱挑战。', style: TextStyle(color: Color(0xFF6B7280)))
                      else
                        ...topWeaknesses.take(5).map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('• ${e.key}（${e.value} 次）', style: const TextStyle(color: Color(0xFF4B5563), height: 1.4)),
                            )),
                      const SizedBox(height: 8),
                      Text(_archiveSuggestion(topWeaknesses), style: const TextStyle(color: Color(0xFF1F2937), height: 1.5)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('模型与领域分布', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        ...providerCounts.entries.map((e) => _pill('${e.key} ${e.value}次')),
                        ...domainCounts.entries.map((e) => _pill('${e.key} ${e.value}次')),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('训练舱表现分布', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      if (cabinSummaries.isEmpty)
                        const Text('完成训练后，这里会开始按训练舱统计你的现实行动表现。', style: TextStyle(color: Color(0xFF6B7280)))
                      else
                        ...cabinSummaries.map((s) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(s['label'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text('训练 ${(s['runs'] as int)} 次 · 成功 ${(s['success'] as int)} 次 · 平均 ${(s['avg'] as int)} 分', style: const TextStyle(color: Color(0xFF6B7280))),
                                  ]),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(999)),
                                  child: Text(_cabinComment(s['label'] as String, s['avg'] as int), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                ),
                              ]),
                            )),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('过程数据洞察', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      if (topAttitudes.isEmpty && topImpactDecisions.isEmpty)
                        const Text('过程数据正在积累。完成更多训练后，这里会开始显示你的进入态度、快速决断与阶段分布。', style: TextStyle(color: Color(0xFF6B7280)))
                      else ...[
                        if (topAttitudes.isNotEmpty) ...[
                          const Text('最常进入的态度', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Wrap(spacing: 8, runSpacing: 8, children: topAttitudes.take(5).map((e) => _pill('${e.key} ${e.value}次')).toList()),
                          const SizedBox(height: 10),
                        ],
                        if (topImpactDecisions.isNotEmpty) ...[
                          const Text('冲击层快速决断', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          ...topImpactDecisions.take(4).map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('• ${e.key}（${e.value} 次）', style: const TextStyle(color: Color(0xFF4B5563), height: 1.4)),
                              )),
                          const SizedBox(height: 10),
                        ],
                        if (stageCounts.isNotEmpty) ...[
                          const Text('阶段事件累计', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Wrap(spacing: 8, runSpacing: 8, children: stageCounts.entries.map((e) => _pill('${e.key} ${e.value}')).toList()),
                        ],
                      ],
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('最近关键训练', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (_records.isEmpty)
                        const Text('暂无训练记录')
                      else
                        ..._records.take(8).map((r) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(r.sceneTitle.isNotEmpty ? r.sceneTitle : r.concept),
                              subtitle: Text('${r.domain} · ${r.summary}', maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(r.resultLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text('${r.totalScore}', style: const TextStyle(color: Color(0xFF6B7280))),
                              ]),
                              onTap: r.id == null
                                  ? null
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => ConceptEngineDetailPage(recordId: r.id!)),
                                      ),
                            )),
                    ]),
                  ),
                ],
              ),
            ),
    );
  }

  String _archiveSuggestion(List<MapEntry<String, int>> topWeaknesses) {
    if (topWeaknesses.isEmpty) {
      return '建议先从【延期汇报舱】开始，训练承担、补救和结构化表达。';
    }
    final top = topWeaknesses.first.key;
    if (top.contains('边界') || top.contains('解释')) {
      return '你当前更适合继续练【边界表达舱】。重点不是说更多，而是更清楚地立住边界。';
    }
    if (top.contains('启动') || top.contains('拖延') || top.contains('推进')) {
      return '你当前更适合继续练【自律启动舱】。重点是缩小第一步并尽快进入行动。';
    }
    return '你当前更适合继续练【延期汇报舱】。重点是先承担、再说明、再给补救方案。';
  }


  String _inferCabinLabel(ConceptEngineSessionRecord r) {
    if (r.cabinType == 'boundary_expression') return '边界表达舱';
    if (r.cabinType == 'self_discipline_start') return '自律启动舱';
    if (r.cabinType == 'delay_report') return '延期汇报舱';
    final s = '${r.sceneTitle} ${r.goal} ${r.concept}';
    if (s.contains('边界') || s.contains('拒绝') || s.contains('越界')) return '边界表达舱';
    if (s.contains('自律') || s.contains('启动') || s.contains('拖延') || s.contains('执行')) return '自律启动舱';
    return '延期汇报舱';
  }

  String _cabinComment(String label, int avg) {
    if (avg >= 80) return '已形成优势';
    if (avg >= 65) return '继续打磨';
    return label == '边界表达舱' ? '先稳住立场' : label == '自律启动舱' ? '先保启动' : '先练承担';
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(fontSize: 12.5)),
      );

  Widget _kv(String label, String value) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
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
