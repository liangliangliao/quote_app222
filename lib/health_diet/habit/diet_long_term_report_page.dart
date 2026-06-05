import 'package:flutter/material.dart';

import '../models/diet_habit_models.dart';
import '../repositories/diet_habit_repository.dart';
import '../services/diet_long_term_report_service.dart';
import 'diet_micro_action_page.dart';
import '../widgets/health_diet_data_source_banner.dart';

class DietLongTermReportPage extends StatefulWidget {
  const DietLongTermReportPage({super.key, this.initialDays = 7});

  final int initialDays;

  @override
  State<DietLongTermReportPage> createState() => _DietLongTermReportPageState();
}

class _DietLongTermReportPageState extends State<DietLongTermReportPage> {
  final _service = DietLongTermReportService();
  final _habitRepo = DietHabitRepository();
  late int _days;
  bool _loading = true;
  DietLongTermReport? _report;

  @override
  void initState() {
    super.initState();
    _days = widget.initialDays;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final report = await _service.buildReport(days: _days);
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  Future<void> _createActionFromPattern(DietHabitPatternRecord pattern) async {
    final title = _actionTitle(pattern.patternType);
    final reason = _actionReason(pattern.patternType);
    await _habitRepo.createMicroAction(actionTitle: title, actionReason: reason, relatedPattern: pattern.patternType);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已生成微行动')));
    await _load();
  }

  String _actionTitle(String type) {
    switch (type) {
      case 'frequent_sweet_drinks':
        return '下一杯奶茶改成小杯少糖';
      case 'high_sodium_days':
        return '下一次泡面/外卖少喝汤汁';
      case 'ultra_processed_foods':
        return '用鸡蛋或豆腐替代一部分加工食品';
      case 'low_protein':
        return '明天早餐加一个鸡蛋或无糖豆浆';
      case 'low_vegetable_fiber':
        return '明天任意一餐加一份青菜';
      case 'skip_breakfast':
        return '明天吃一个最小早餐';
      default:
        return '明天只做一个小改变';
    }
  }

  String _actionReason(String type) {
    switch (type) {
      case 'frequent_sweet_drinks':
        return '先不完全戒甜饮，只把最容易改变的一杯改小、改少糖。';
      case 'high_sodium_days':
        return '少喝汤汁和调料减半是降低高盐负担的低难度动作。';
      case 'ultra_processed_foods':
        return '用真实食物替代一部分加工食品，饮食结构会更稳定。';
      case 'low_protein':
        return '稳定蛋白质有助于饱腹感、体力恢复和运动恢复。';
      case 'low_vegetable_fiber':
        return '先补一份蔬菜或菌菇，比追求完美饮食更容易坚持。';
      case 'skip_breakfast':
        return '最小早餐能减少后续靠甜饮或重口味食物补偿的概率。';
      default:
        return '越小的改变越容易持续。';
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: Text(_days == 7 ? '本周饮食报告' : '近30天饮食趋势'),
        actions: [
          TextButton(
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DietMicroActionPage()));
              await _load();
            },
            child: const Text('微行动'),
          ),
        ],
      ),
      body: _loading || report == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  HealthDietDataSourceBanner(
                    sources: const ['本地历史饮食记录', '7/14/30 天趋势', '饮食模式规则'],
                    updatedAt: DateTime.now(),
                    note: '长期趋势不是固定模板，会随你每天确认的饮食记录动态变化。',
                  ),
                  _rangeSwitch(),
                  const SizedBox(height: 12),
                  _summaryCard(report),
                  const SizedBox(height: 14),
                  _scoreCard(report),
                  const SizedBox(height: 14),
                  _trendCard(report),
                  const SizedBox(height: 14),
                  _priorityActionCard(report),
                  const SizedBox(height: 14),
                  _patternsCard(report),
                ],
              ),
            ),
    );
  }

  Widget _rangeSwitch() {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 7, label: Text('7天'), icon: Icon(Icons.calendar_view_week_outlined)),
        ButtonSegment(value: 30, label: Text('30天'), icon: Icon(Icons.calendar_month_outlined)),
      ],
      selected: {_days},
      onSelectionChanged: (values) {
        setState(() => _days = values.first);
        _load();
      },
    );
  }

  Widget _summaryCard(DietLongTermReport report) {
    final completion = report.days == 0 ? 0.0 : report.recordedDays / report.days;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFFEFF6FF), Color(0xFFF0FDF4)]),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.timeline, color: Color(0xFF2563EB)), SizedBox(width: 8), Text('长期饮食趋势', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 12),
          Text('近 ${report.days} 天记录了 ${report.recordedDays} 天，共 ${report.totalEntries} 条饮食记录。', style: const TextStyle(height: 1.5)),
          const SizedBox(height: 12),
          _metricBar('记录连续性', completion * 100, suffix: '%'),
          _metricBar('平均恢复指数', report.averageRecoveryScore),
          _metricBar('早餐出现天数', report.days == 0 ? 0 : report.breakfastDays / report.days * 100, suffix: '%'),
        ],
      ),
    );
  }

  Widget _scoreCard(DietLongTermReport report) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('营养结构概览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _metricBar('蛋白质充足', report.averageProteinScore),
            _metricBar('蔬菜水果', report.averageVegetableScore),
            _metricBar('膳食纤维', report.averageFiberScore),
            const Divider(height: 24),
            _riskBar('高糖风险', report.averageSugarRisk),
            _riskBar('高盐风险', report.averageSodiumRisk),
            _riskBar('加工食品风险', report.averageProcessedRisk),
          ],
        ),
      ),
    );
  }

  Widget _trendCard(DietLongTermReport report) {
    final points = report.trendPoints;
    if (points.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('还没有足够记录生成趋势。')));
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('每日恢复指数', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...points.take(14).map((p) => _metricBar(p.date.substring(5), p.recoveryScore)),
            if (points.length > 14) const Padding(padding: EdgeInsets.only(top: 8), child: Text('已显示最近 14 个有记录的日期。', style: TextStyle(color: Colors.black54))),
          ],
        ),
      ),
    );
  }

  Widget _priorityActionCard(DietLongTermReport report) {
    final action = report.priorityAction;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.flag_outlined, color: Color(0xFFD97706)), SizedBox(width: 8), Text('下一个最小改变', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          if (action == null)
            const Text('继续记录 3-7 天后，系统会从你的稳定饮食模式中生成一个最优先的微行动。', style: TextStyle(height: 1.5))
          else ...[
            Text(action.actionTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(action.actionReason, style: const TextStyle(height: 1.45)),
          ],
        ],
      ),
    );
  }

  Widget _patternsCard(DietLongTermReport report) {
    if (report.patterns.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('暂时没有发现稳定饮食模式。继续记录后，系统会识别甜饮、高盐、低蛋白、低蔬菜、早餐缺失等长期模式。')));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('已识别饮食模式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...report.patterns.map((p) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Expanded(child: Text(p.patternName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), Chip(label: Text('${p.frequencyCount}天'))]),
                    if (p.evidence.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...p.evidence.take(3).map((e) => Text('• $e', style: const TextStyle(height: 1.35))),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _createActionFromPattern(p),
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('生成微行动'),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _metricBar(String label, double value, {String suffix = ''}) {
    final v = value.clamp(0, 100).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 92, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: v / 100, minHeight: 9, backgroundColor: const Color(0xFFE2E8F0)),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 44, child: Text('${v.round()}$suffix', textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _riskBar(String label, double value) {
    return _metricBar(label, value);
  }
}
