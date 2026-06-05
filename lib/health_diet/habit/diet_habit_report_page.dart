import 'package:flutter/material.dart';

import '../repositories/daily_diet_entry_repository.dart';
import '../services/diet_habit_pattern_service.dart';
import 'diet_long_term_report_page.dart';
import 'diet_micro_action_page.dart';
import '../widgets/health_diet_data_source_banner.dart';

class DietHabitReportPage extends StatefulWidget {
  const DietHabitReportPage({super.key});

  @override
  State<DietHabitReportPage> createState() => _DietHabitReportPageState();
}

class _DietHabitReportPageState extends State<DietHabitReportPage> {
  final _entryRepo = DailyDietEntryRepository();
  final _patternService = DietHabitPatternService();

  bool _loading = true;
  List<DietHabitPatternView> _patterns = const [];
  int _entryCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _entryRepo.recentEntries(limit: 80);
    final patterns = _patternService.analyzeLastDays(entries, days: 7);
    if (!mounted) return;
    setState(() {
      _entryCount = entries.length;
      _patterns = patterns;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('饮食习惯报告')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  HealthDietDataSourceBanner(
                    sources: const ['本地饮食历史', '模式识别规则', '长期趋势'],
                    updatedAt: DateTime.now(),
                    note: '饮食模式来自多日确认记录，不是单日静态文案；记录越完整，模式越可靠。',
                  ),
                  _introCard(),
                  const SizedBox(height: 14),
                  if (_patterns.isEmpty) _emptyCard() else ..._patterns.map(_patternCard),
                ],
              ),
            ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFFECFDF5), Color(0xFFEFF6FF)]),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.psychology_alt_outlined, color: Color(0xFF059669)), SizedBox(width: 8), Text('最近饮食模式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          Text('系统已读取最近 $_entryCount 条饮食记录。第六阶段会把高糖、高盐、低蛋白、低蔬菜、早餐缺失等模式进一步沉淀为周报、30天趋势和微行动。', style: const TextStyle(height: 1.5)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DietLongTermReportPage(initialDays: 7))),
                icon: const Icon(Icons.timeline),
                label: const Text('看本周报告'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DietMicroActionPage())),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('看微行动'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('最近记录还不足，暂时没有发现稳定的饮食习惯模式。建议连续记录 3-7 天后再查看。', style: TextStyle(height: 1.5)),
      ),
    );
  }

  Widget _patternCard(DietHabitPatternView pattern) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_graph, color: Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                Expanded(child: Text(pattern.patternName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                Chip(label: Text('${pattern.frequencyCount} 天')),
              ],
            ),
            const SizedBox(height: 10),
            Text(pattern.impact, style: const TextStyle(height: 1.45)),
            if (pattern.evidence.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('证据：', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...pattern.evidence.map((e) => Text('• $e', style: const TextStyle(height: 1.38))),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('下一步微行动', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(pattern.microAction, style: const TextStyle(height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
