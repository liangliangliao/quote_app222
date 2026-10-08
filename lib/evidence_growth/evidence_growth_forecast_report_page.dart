import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'evidence_growth_forecast_science.dart';
import 'evidence_growth_journey_models.dart';

String forecastPercent(Object? value) =>
    EvidenceForecastScience.probability(value) == null
        ? '尚不能估计'
        : '${(EvidenceForecastScience.probability(value)! * 100).round()}%';

/// Both screen and copy export use the same frozen report, not live form data.
class EvidenceGrowthForecastReportPage extends StatelessWidget {
  const EvidenceGrowthForecastReportPage({super.key, required this.prediction});
  final GrowthData prediction;

  static String brief(Object? value, [int max = 120]) {
    final text = EvidenceForecastScience.text(value, max)
        .replaceAll(RegExp(r'\s+'), ' ');
    if (RegExp(r'event_contract|normalized_action|confirmed=true|observation_window|success_criterion|\bnull\b').hasMatch(text)) {
      return '';
    }
    return text;
  }

  static String outcomeLabel(GrowthData p) => const {
    'PENDING': '尚未记录', 'SUCCESS': '已完成', 'ON_TIME': '按时完成',
    'FAILED': '未完成', 'NOT_DONE': '没有执行', 'LATE': '迟到',
    'PARTIAL': '部分完成', 'CANCELLED': '已取消', 'UNOBSERVED': '无法观察',
  }[p['outcome']] ?? '尚未记录';

  static String stateLabel(Object? value) => const {
    'supportive': '有利', 'adverse': '不利', 'mixed': '利弊并存',
  }[value] ?? '未知';

  static List<GrowthData> sections(GrowthData p) {
    final contract = growthMap(p['event_contract']);
    final report = growthMap(p['scientific_report']);
    final weights = growthMap(p['factor_weight_analysis']);
    final ranked = growthRows(weights['factors']);
    final provenance = growthMap(p['forecast_provenance']);
    final validation = growthMap(p['forecast_validation']).isNotEmpty
        ? growthMap(p['forecast_validation']) : growthMap(report['validation']);
    final estimate = EvidenceForecastScience.probability(p['estimate']);
    final observed = EvidenceForecastScience.outcome(p);
    final observations = growthMap(growthMap(p['diagnostic_review'])['user_observations']);
    final count = (validation['final_count'] as num?)?.toInt() ?? 0;
    final obstacles = ranked.where((r) => r['evidence_status'] == 'adverse' ||
        r['evidence_status'] == 'mixed' &&
        (EvidenceForecastScience.probability(r['bottleneck_probability']) ?? 0) >= .55)
        .toList()..sort((a, b) => (b['opposition_contribution'] as num)
            .compareTo(a['opposition_contribution'] as num));
    for (final critical in growthRows(weights['critical_obstacles']).reversed) {
      obstacles.removeWhere((r) => r['key'] == critical['key']);
      obstacles.insert(0, {...growthMap(growthMap(p['factors'])[critical['key']]), ...critical});
    }
    final fallback = growthRows(p['top_risks']);
    final roots = growthRows(report['roots_and_experiments']);
    return [
      {
        'title': '预测与实际结果',
        'body': [
          '行动发生可能性：${forecastPercent(p['estimate'])}',
          '实际结果：${outcomeLabel(p)}',
          if (observed != null && estimate != null)
            '预测对照：${(estimate >= .5) == (observed == 1) ? '发生倾向与实际结果一致' : '发生倾向与实际结果不一致'}',
          '行动：${brief(p['plan'], 300)}',
          '达成标准：${brief(contract['success_criterion'], 600).isEmpty ? '未记录' : brief(contract['success_criterion'], 600)}',
          '观察窗口：${brief(contract['observation_window'], 300).isEmpty ? '未记录' : brief(contract['observation_window'], 300)}',
          if (brief(observations['timeline']).isNotEmpty)
            '实际经过：${brief(observations['timeline'])}',
          if (p['pipeline_status'] == 'PARTIAL') '计算尚未完成，可重试。',
          'LLM ${forecastPercent(provenance['ai_fallback_probability'])} · JEV初判 ${forecastPercent(provenance['jev_primary_event_probability'])} · JEV复核 ${forecastPercent(provenance['jev_final_synthesis_probability'])}',
        ].join('\n'),
      },
      {
        'title': '预测准确度',
        'body': count == 0
            ? '尚无同类行动的有效实际结果，准确度待验证。完成后记录“做了／没做”，即可与本次预测对照。'
            : [
                '已验证 $count 次同类行动。',
                if (validation['direction_accuracy'] != null)
                  '发生倾向命中率：${forecastPercent(validation['direction_accuracy'])}（≥50%判断会发生）',
                '平均预测：${forecastPercent(validation['final_mean_prediction'])} · 实际完成率：${forecastPercent(validation['observed_rate'])}',
                if (validation['final_brier'] is num)
                  '概率误差：${(validation['final_brier'] as num).toStringAsFixed(3)}（Brier，越低越好）',
              ].join('\n'),
      },
      {
        'title': '有利与不利因素占比',
        'body': ranked.isEmpty
            ? '这条记录没有可核对的因素权重，重新预测后可查看。'
            : [
                '有利 ${forecastPercent(weights['support_share'])} · 不利 ${forecastPercent(weights['opposing_share'])} · 利弊并存 ${forecastPercent(weights['mixed_share'])}',
                '按本次行动的重要性分配占比，未知项不扣分。',
                for (final row in ranked)
                  '${row['rank']}. ${brief(row['label'], 50)} · ${stateLabel(row['evidence_status'])} · 权重 ${forecastPercent(row['weight'])}'
                  '${brief(row['importance_reason'], 70).isEmpty ? '' : '\n   ${brief(row['importance_reason'], 70)}'}',
                if (growthStrings(weights['unknown_factors']).isNotEmpty)
                  '尚不清楚：${growthStrings(weights['unknown_factors']).take(3).join('、')}',
                if (growthStrings(weights['unassessed_factors']).isNotEmpty)
                  '另有 ${growthStrings(weights['unassessed_factors']).length} 项未返回重要性，未计入占比。',
              ].join('\n'),
      },
      {
        'title': '可能让你没有行动的阻碍',
        'body': obstacles.isEmpty && fallback.isEmpty
            ? '目前没有证据明确的主要阻碍。'
            : [
                for (final row in (obstacles.isNotEmpty ? obstacles : fallback).take(3)) ...[
                  '${brief(row['label'], 50)}${row['weight'] == null ? '' : ' · 权重 ${forecastPercent(row['weight'])}'}',
                  if (brief(row['evidence']).isNotEmpty) '依据：${brief(row['evidence'])}',
                  if (brief(row['mechanism']).isNotEmpty) '为什么可能卡住：${brief(row['mechanism'])}',
                  if (brief(row['intervention']).isNotEmpty) '可先处理：${brief(row['intervention'])}',
                ],
                if (growthMap(p['score_aggregation'])['ceiling_applied'] == true)
                  '有关键条件未满足，其他有利因素无法完全抵消。',
              ].join('\n'),
      },
      if (roots.any((r) => brief(r['minimum_action']).isNotEmpty)) {
        'title': '下一步',
        'body': roots.where((r) => brief(r['minimum_action']).isNotEmpty).take(1)
            .map((r) => brief(r['minimum_action'])).join(),
      },
    ];
  }

  static String markdown(GrowthData p) =>
      '# 行动预测与学习报告\n\n生成时间：${DateTime.fromMillisecondsSinceEpoch((p['created_at_ms'] as num?)?.toInt() ?? 0).toLocal()}\n\n${sections(p).map((s) => '## ${s['title']}\n\n${s['body']}').join('\n\n')}';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('行动预测与学习报告'),
          actions: [
            IconButton(
              tooltip: '复制完整报告',
              icon: const Icon(Icons.copy),
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: markdown(prediction)));
                if (context.mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已复制报告')));
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final section in sections(prediction))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${section['title']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        '${section['body']}',
                        style: const TextStyle(height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}
