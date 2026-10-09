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

  static double? displayEstimate(GrowthData p) =>
      EvidenceForecastScience.probability(p['estimate']) ??
      EvidenceForecastScience.probability(p['preliminary_estimate']) ??
      (p['pipeline_status'] == 'PARTIAL'
          ? EvidenceForecastScience.probability(p['raw_model_estimate'])
          : null);

  static bool preliminary(GrowthData p) =>
      p['prediction_complete'] == false ||
      const {'LLM_ONLY', 'JEV_FIRST_PASS'}.contains(p['estimate_stage']) ||
      (p['estimate'] == null && displayEstimate(p) != null);

  static String estimateTitle(GrowthData p) {
    if (displayEstimate(p) == null) return '行动预测（尚未完成）';
    if (!preliminary(p)) return '行动发生可能性';
    final source = growthMap(p['forecast_provenance']);
    return source['jev_first_pass_status'] == 'JEV'
        ? '初步估计（JEV初判已完成）'
        : '初步估计（仅LLM，JEV未完成）';
  }

  static String failureReason(Object? reason, {String service = 'JEV', Object? httpStatus}) {
    final code = '$reason ${httpStatus ?? ''}'.toUpperCase();
    if (code.contains('401')) return '密钥无效，请重新配置$service';
    if (code.contains('403')) return '当前密钥没有访问权限';
    if (code.contains('422') || code.contains('400')) return '请求格式未通过$service接口校验';
    if (code.contains('429') ||
        code.contains('529') ||
        code.contains('COOLDOWN')) return '服务繁忙，请稍后重试';
    if (code.contains('TIMEOUT') || code.contains('408') || code.contains('504')) return '请求超时，请重试';
    if (code.contains('NETWORK') || code.contains('TRANSPORT'))
      return '网络连接失败，请检查网络后重试';
    if (code.contains('CONTEXT_TOO_LARGE')) return '资料过长，需分批判断';
    if (code.contains('PARSE') || code.contains('JSON_INVALID') ||
        code.contains('SHAPE_INVALID') || code.contains('TYPED_RESPONSE'))
      return '返回结果不完整，请重试';
    if (code.contains('EMPTY_AI_RESPONSE')) return '服务没有返回可用内容，请重试';
    if (code.contains('NO_KEY') || code.contains('NOT_CONFIGURED'))
      return '尚未配置$service';
    if (code.contains('CONFIG_UNAVAILABLE')) return '无法读取$service配置，请检查设置';
    if (code.contains('SERVICE_UNAVAILABLE') || code.contains('HTTP_5'))
      return '服务暂时不可用，请稍后重试';
    return '请求未完成，可重试';
  }

  static String completionNotice(GrowthData p) {
    if (p['pipeline_status'] != 'PARTIAL' && p['prediction_complete'] != false)
      return '';
    final source = growthMap(p['forecast_provenance']);
    if (source['llm_first_pass_status'] != null &&
        source['llm_first_pass_status'] != 'AI') {
      return 'LLM初步分析未完成：${failureReason(source['llm_first_pass_reason'], service: 'AI', httpStatus: source['llm_first_pass_http_status'])}。${source['jev_first_pass_status'] == 'JEV' ? 'JEV初判已保留，补全时继续缺失步骤。' : '已成功的步骤会保留。'}';
    }
    if (source['jev_first_pass_status'] != 'JEV') {
      final hasAi = growthMap(p['ai'])['status'] == 'AI' ||
          EvidenceForecastScience.probability(source['ai_fallback_probability']) != null;
      return 'JEV初判未完成：${failureReason(source['jev_first_pass_reason'], httpStatus: source['jev_first_pass_http_status'])}。${hasAi ? '已有LLM分析已保留，补全时继续缺失步骤。' : '尚未取得可用结果，可重试。'}';
    }
    if (source['jev_final_adjudication_status'] != 'JEV') {
      if ('${source['jev_final_adjudication_reason']}'
          .startsWith('LLM_SYNTHESIS_UNAVAILABLE')) {
        final reason = source['llm_synthesis_reason'] ??
            '${source['jev_final_adjudication_reason']}'.replaceFirst('LLM_SYNTHESIS_UNAVAILABLE_', '');
        return 'LLM综合未完成：${failureReason(reason, service: 'AI', httpStatus: source['llm_synthesis_http_status'])}。JEV初判已保留，补全时从综合继续。';
      }
      return 'JEV初判已完成，最终复核未完成：${failureReason(source['jev_final_adjudication_reason'], httpStatus: source['jev_final_adjudication_http_status'])}。补全时继续最终复核。';
    }
    final warnings = growthStrings(p['pipeline_warnings']);
    if (source['jev_retry_reason'] != null) {
      return '已保留有效预测，JEV明细补全未成功：${failureReason(source['jev_retry_reason'], httpStatus: source['jev_retry_http_status'])}。';
    }
    return warnings.isNotEmpty
        ? '预测分数已完成；${warnings.join('；')}，可重试补全。'
        : '部分分析尚未完成，已有判断已保留。';
  }

  static String diagnostics(GrowthData p) {
    final source = growthMap(p['forecast_provenance']);
    String code(Object? value) => value == null ? 'NONE'
        : RegExp(r'^[A-Z][A-Z0-9_]{0,120}$').hasMatch('$value') ? '$value' : 'UNKNOWN';
    String modelText(Object? value) => '$value'.replaceAll(RegExp(r'[\r\n]'), ' ').substring(
        0, '$value'.length > 80 ? 80 : '$value'.length);
    return [
      '预测阶段诊断 v1',
      if (growthMap(p['execution_model']).isNotEmpty)
        'AI: ${modelText(growthMap(p['execution_model'])['provider'])} / ${modelText(growthMap(p['execution_model'])['model'])}; ${modelText(growthMap(p['execution_model'])['request_version'])}',
      for (final stage in const {
        'LLM初步分析': 'llm_first_pass', 'JEV初判': 'jev_first_pass',
        'LLM综合': 'llm_synthesis', 'JEV复核': 'jev_final_adjudication',
      }.entries)
        '${stage.key}: ${code(source['${stage.value}_status'])}; ${code(source['${stage.value}_reason'])}${source['${stage.value}_http_status'] is num ? '; HTTP ${source['${stage.value}_http_status']}' : ''}${source['${stage.value}_detail_code'] != null ? '; ${code(source['${stage.value}_detail_code'])}' : ''}',
    ].join('\n');
  }

  static String brief(Object? value, [int max = 120]) {
    final text = EvidenceForecastScience.text(value, max)
        .replaceAll(RegExp(r'\s+'), ' ');
    if (RegExp(
            r'event_contract|normalized_action|confirmed=true|observation_window|success_criterion|\bnull\b')
        .hasMatch(text)) {
      return '';
    }
    return text;
  }

  static String outcomeLabel(GrowthData p) =>
      const {
        'PENDING': '尚未记录',
        'SUCCESS': '已完成',
        'ON_TIME': '按时完成',
        'FAILED': '未完成',
        'NOT_DONE': '没有执行',
        'LATE': '迟到',
        'PARTIAL': '部分完成',
        'CANCELLED': '已取消',
        'UNOBSERVED': '无法观察',
      }[p['outcome']] ??
      '尚未记录';

  static String stateLabel(Object? value) =>
      const {
        'supportive': '有利',
        'adverse': '不利',
        'mixed': '利弊并存',
      }[value] ??
      '未知';

  static String improvementNote(GrowthData prediction) {
    final audit = growthMap(prediction['performance_comparison']);
    if (audit.isEmpty) return '';
    final count = (audit['count'] as num?)?.toInt() ?? 0;
    final minimum = (audit['minimum_count'] as num?)?.toInt() ?? 60;
    if (audit['status'] == 'INSUFFICIENT_REAL_OUTCOMES')
      return '改进验证：已配对$count次同类行动，需至少$minimum次且包含足够成功和失败；10%改善目标待验证。';
    final gain = audit['relative_brier_reduction'];
    if (gain is! num || !gain.isFinite) return '改进验证：旧组合在这些结果上已无概率误差，无法计算相对改善。';
    return '与同次旧组合相比，概率误差${gain >= 0 ? '降低' : '增加'}${(gain.abs() * 100).toStringAsFixed(1)}%（$count次）。'
        '${audit['target_verified'] == true ? '已通过至少10%改善的验证门槛。' : '尚未证明至少10%的稳定改善。'}';
  }

  static List<GrowthData> sections(GrowthData p) {
    final contract = growthMap(p['event_contract']);
    final report = growthMap(p['scientific_report']);
    final weights = growthMap(p['factor_weight_analysis']);
    final ranked = growthRows(weights['factors']);
    final provenance = growthMap(p['forecast_provenance']);
    final validation = growthMap(p['forecast_validation']).isNotEmpty
        ? growthMap(p['forecast_validation'])
        : growthMap(report['validation']);
    final estimate = displayEstimate(p);
    final observed = EvidenceForecastScience.outcome(p);
    final observations =
        growthMap(growthMap(p['diagnostic_review'])['user_observations']);
    final count = (validation['final_count'] as num?)?.toInt() ?? 0;
    final obstacles = ranked
        .where((r) =>
            r['evidence_status'] == 'adverse' ||
            r['evidence_status'] == 'mixed' &&
                (EvidenceForecastScience.probability(
                            r['bottleneck_probability']) ??
                        0) >=
                    .55)
        .toList()
      ..sort((a, b) => (b['opposition_contribution'] as num)
          .compareTo(a['opposition_contribution'] as num));
    for (final critical in growthRows(weights['critical_obstacles']).reversed) {
      obstacles.removeWhere((r) => r['key'] == critical['key']);
      obstacles.insert(0, {
        ...growthMap(growthMap(p['factors'])[critical['key']]),
        ...critical
      });
    }
    final fallback = growthRows(p['top_risks']);
    final roots = growthRows(report['roots_and_experiments']);
    final guidance = growthMap(p['action_guidance']);
    final steps = growthRows(guidance['steps']);
    final questions = growthRows(guidance['verification_questions']);
    return [
      {
        'title': '预测与实际结果',
        'body': [
          '${estimateTitle(p)}：${estimate == null ? '预测尚未完成' : forecastPercent(estimate)}',
          if (completionNotice(p).isNotEmpty) completionNotice(p),
          '实际结果：${outcomeLabel(p)}',
          if (observed != null && estimate != null)
            '${preliminary(p) ? '初步预测' : '预测'}对照：${(estimate >= .5) == (observed == 1) ? '发生倾向与实际结果一致' : '发生倾向与实际结果不一致'}',
          '行动：${brief(p['plan'], 300)}',
          '达成标准：${brief(contract['success_criterion'], 600).isEmpty ? '未记录' : brief(contract['success_criterion'], 600)}',
          '观察窗口：${brief(contract['observation_window'], 300).isEmpty ? '未记录' : brief(contract['observation_window'], 300)}',
          if (brief(observations['timeline']).isNotEmpty)
            '实际经过：${brief(observations['timeline'])}',
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
                if (improvementNote(p).isNotEmpty) improvementNote(p),
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
                for (final row in (obstacles.isNotEmpty ? obstacles : fallback)
                    .take(3)) ...[
                  '${brief(row['label'], 50)}${row['weight'] == null ? '' : ' · 权重 ${forecastPercent(row['weight'])}'}',
                  if (brief(row['evidence']).isNotEmpty)
                    '依据：${brief(row['evidence'])}',
                  if (brief(row['mechanism']).isNotEmpty)
                    '为什么可能卡住：${brief(row['mechanism'])}',
                  if (brief(row['intervention']).isNotEmpty)
                    '可先处理：${brief(row['intervention'])}',
                ],
                if (growthMap(p['score_aggregation'])['ceiling_applied'] ==
                    true)
                  '有关键条件未满足，其他有利因素无法完全抵消。',
              ].join('\n'),
      },
      if (steps.isNotEmpty)
        {
          'title': '下一步怎么做',
          'body': [
            for (final step in steps.take(2)) ...[
              '${step['priority'] == 'PREREQUISITE' ? '先处理必要条件' : '先处理'}：${brief(step['label'], 60)}',
              brief(step['plan'], 240),
            if (step['basis'] != '有已提供的依据') brief(step['basis'], 90),
              if (brief(step['fallback']).isNotEmpty)
                '如果受阻：${brief(step['fallback'])}',
              if (brief(step['check']).isNotEmpty)
                '完成检查：${brief(step['check'])}',
              if ((step['recurrence_count'] as num? ?? 0) >= 2)
                '这项阻碍曾在${step['recurrence_count']}次同类行动复盘中出现。',
            ]
          ].join('\n'),
        }
      else if (roots.any((r) => brief(r['minimum_action']).isNotEmpty))
        {
          'title': '下一步',
          'body': roots
              .where((r) => brief(r['minimum_action']).isNotEmpty)
              .take(1)
              .map((r) => brief(r['minimum_action']))
              .join(),
        },
      if (questions.isNotEmpty)
        {
          'title': '优先核实的关键条件',
          'body': questions.map((q) => brief(q['question'], 160)).join('\n')
        },
      if (count == 0 && improvementNote(p).isNotEmpty)
        {'title': '改进是否更准', 'body': improvementNote(p)},
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
