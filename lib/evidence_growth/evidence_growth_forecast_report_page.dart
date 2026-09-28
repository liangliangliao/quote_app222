import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'evidence_growth_behavior_theories.dart';
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

  static const _relationLabels = {
    'MEDIATION': '中介关系',
    'MODERATION': '调节关系',
    'GATE': '必要前提',
    'CONFLICT': '相互冲突',
    'FEEDBACK': '反馈关系',
    'UNCERTAIN': '关系待验证',
  };

  static String verdict(Object? raw) =>
      const {
        'supported': '有证据支持',
        'partially_supported': '仅部分支持',
        'evidence_linked': '有观察依据的假设',
        'plausible_only': '仅是合理假设',
        'contradicted': '与证据矛盾',
        'insufficient': '证据不足',
        'feasible': '当前可行',
        'conditional': '需要先确认条件',
        'infeasible': '当前不可行',
        'unknown': '尚不清楚',
        'grounded': '依据观察，仍保留不确定性',
        'overclaimed': '存在超出证据的推断',
        'experiment': '实施一个可检验的改变',
        'clarify': '先核实关键事实',
        'revise_goal': '重新评估目标',
        'stop': '停止当前尝试',
      }['$raw'] ??
      '未完成判断';

  static List<GrowthData> sections(GrowthData p) {
    final report = growthMap(p['scientific_report']);
    final contract = growthMap(p['event_contract']);
    final provenance = growthMap(p['forecast_provenance']);
    final diagnosis = growthMap(p['behavior_diagnosis']);
    final theory = growthMap(diagnosis['theory_feedback_analysis']);
    final completeness = growthMap(report['evidence_completeness']);
    final calibration = growthMap(report['calibration']);
    final validation = growthMap(report['validation']);
    final spread = growthMap(report['model_spread']);
    final weights = growthMap(report['weight_analysis']);
    final review = growthMap(p['diagnostic_review']);
    final aiReview = growthMap(review['llm_analysis']);
    final sections = <GrowthData>[
      {
        'title': '1 · 预测的到底是什么',
        'body': [
          '行动：${p['plan']}',
          '达成标准：${contract['success_criterion'] ?? '旧记录未确认'}',
          '观察窗口：${contract['observation_window'] ?? '旧记录未确认'}',
          '可比情境组：${EvidenceForecastScience.text(contract['context_class']).isEmpty ? '未指定，不合并历史校准' : contract['context_class']}',
          '本次模型估计：${forecastPercent(p['estimate'])} · ${p['estimate_is_calibrated'] == true ? '个人校准试用' : '尚未经个人结果校准'}',
          ...growthStrings(p['pipeline_errors']),
          '${report['precision_note'] ?? '预测不是行为保证。'}',
        ].join('\n\n'),
      },
      {
        'title': '2 · 证据完整度与来源',
        'body': [
          '已知 ${completeness['known_answers'] ?? 0} / ${completeness['total'] ?? 0}；明确不知道 ${completeness['explicit_unknown'] ?? 0}；未回答 ${completeness['unselected_missing'] ?? 0}。缺失不作负分或中性事实。',
          '理论：${growthStrings(growthMap(p['theory'])['selected_ids']).map((id) => EvidenceBehaviorTheoryCatalog.theories[id]?['short_name'] ?? id).join('、')}',
          'LLM：${growthMap(p['ai'])['model'] ?? '未记录'}；JEV：${growthMap(p['jev'])['model'] ?? '未记录'}',
          'LLM交叉估计 ${forecastPercent(provenance['ai_fallback_probability'])}；JEV初判 ${forecastPercent(provenance['jev_primary_event_probability'])}；JEV综合判断 ${forecastPercent(provenance['jev_final_synthesis_probability'])}。',
          if (spread.isNotEmpty)
            '判断跨度 ${forecastPercent(spread['low'])}—${forecastPercent(spread['high'])}。${spread['label']}',
          '联合机制结论：${provenance['joint_decision_complete'] == true ? '三层判断相容，仍须现实检验' : '存在分歧或证据不足，保留候选解释'}。',
          for (final row in growthRows(theory['factor_rows']))
            '${row['factor_label']}：${row['option_label']}（用户提交；${row['selection_source'] == 'AUTO_LLM_JEV' ? '源自AI预填' : '手动选择'}）',
        ].join('\n\n'),
      },
      {
        'title': '3 · 因素之间怎样相互影响',
        'body': [
          '${theory['pattern_explanation'] ?? diagnosis['headline'] ?? '尚无综合解释'}',
          for (final row in growthRows(theory['interactions']))
            '${row['label']} · ${_relationLabels[row['relationship_type']] ?? '待验证关系'}\n${row['description']}',
          '同一构念重复出现不累计权重。意向的前因、实际约束、启动与维持条件处在不同作用位置，不能用简单平均抵消关键现实障碍。',
        ].join('\n\n'),
      },
    ];
    final roots = growthRows(report['roots_and_experiments']);
    sections.add({
      'title': '4 · 关键原因假设与行动实验',
      'body': roots.isEmpty
          ? '尚无可用的原因假设。先补充决定性事实，再分析。'
          : roots.map((row) {
              final delta = row['model_sensitivity_delta'];
              final feasible = growthMap(row['feasibility']);
              final evidenceVerdict = growthMap(row['evidence_verdict']);
              return [
                '${row['title']}',
                if (row['jev_reviewed_excerpt'] == true)
                  '这条解释较长，JEV核验使用了标明的摘要；完整解释中的其他细节未全部核验。',
                if (row['recommended'] == true)
                  'JEV建议优先验证这个行动实验（综合证据、可行性、成本与风险；并非已证明最优）。',
                '联合核验：${verdict(evidenceVerdict['choice'])}；深层原因：${verdict(growthMap(row['root_verdict'])['choice'])}。',
                for (final entry in const {
                  'observed_basis': '观察依据',
                  'mechanism': '作用机制',
                  'root_cause_hypothesis': '更深原因假设',
                  'maintaining_condition': '维持条件',
                  'alternative_explanation': '替代解释',
                  'counterevidence': '反证',
                  'falsifier': '怎样推翻假设',
                  'theory_lesson': '理论学习',
                  'belief_test': '态度与信念检验',
                  'minimum_action': '最小行动',
                  'if_then': '触发计划',
                  'cost_and_risk': '成本与风险',
                  'stop_rule': '停止条件',
                }.entries)
                  if (EvidenceForecastScience.text(
                    row[entry.key],
                  ).isNotEmpty)
                    '${entry.value}：${row[entry.key]}',
                if (growthStrings(row['changed_conditions']).isNotEmpty)
                  '假设变化：${growthStrings(row['changed_conditions']).join('；')}。',
                'JEV可行性判断：${verdict(feasible['choice'])}。',
                if (row['scenario_probability'] != null)
                  '仅在假设变化落实、事件标准不变时：${forecastPercent(row['scenario_probability'])}；相对同尺度原始综合估计${delta is num ? ' ${(delta * 100) >= 0 ? '+' : ''}${(delta * 100).round()}个百分点' : '差异未知'}。这是模型敏感性，不是实证干预效果，不与其他方案相加。',
                '现实验证：${row['review_focus'] ?? '记录行动断点前实际发生的事实。'}',
              ].join('\n');
            }).join('\n\n────────\n\n'),
    });
    sections.addAll([
      {
        'title': '5 · 权重依据与个人校准',
        'body': [
          '${weights['note'] ?? '暂无可用个人数据权重。'}',
          '个人可比独立记录 ${weights['sample_count'] ?? 0} 次。',
          for (final row in growthRows(weights['coefficients']))
            '${EvidenceBehaviorTheoryCatalog.factor('${row['factor_id']}')?['label'] ?? row['factor_id']} / ${EvidenceBehaviorTheoryCatalog.option('${row['factor_id']}', '${row['option_id']}')?['label'] ?? row['option_id']}：关联系数 ${(row['coefficient'] as num).toStringAsFixed(3)}，训练观察 ${row['training_count']} 次。',
          if (weights['estimate'] != null)
            '类别关联模型交叉估计：${forecastPercent(weights['estimate'])}（不替代JEV）。',
          '校准：${calibration['status'] == 'PERSONAL_PLATT_CALIBRATED' ? '时间留出验证通过，个人试用' : calibration['status'] == 'CALIBRATION_REJECTED_ON_HOLDOUT' ? '验证没有改善，不应用校准' : '证据未达到校准门槛'}。',
          '${calibration['minimum_rule'] ?? ''}',
          if (calibration['holdout_count'] != null)
            '校准留出样本 ${calibration['holdout_count']}；原始 Brier ${growthMap(calibration['holdout_raw'])['brier']}；校准 Brier ${growthMap(calibration['holdout_calibrated'])['brier']}。',
        ].join('\n\n'),
      },
      {
        'title': '6 · 预测与实际结果的偏差',
        'body': [
          '有效配对样本：${validation['final_count'] ?? 0}；平均预测 ${forecastPercent(validation['final_mean_prediction'])}；实际达成率 ${forecastPercent(validation['observed_rate'])}。',
          '原始 Brier：${validation['raw_brier'] ?? '暂无'}；最终 Brier：${validation['final_brier'] ?? '暂无'}。',
          '最终对数损失：${validation['final_log_loss'] ?? '暂无'}。',
          for (final bin in growthRows(validation['reliability_bins']))
            if ((bin['count'] as num? ?? 0) > 0)
              '${forecastPercent(bin['lower'])}—${forecastPercent(bin['upper'])} 组：${bin['count']}次，实际 ${forecastPercent(bin['observed_rate'])}。',
          '${validation['note'] ?? ''}',
        ].join('\n\n'),
      },
      {
        'title': '7 · 行动与复盘闭环',
        'body': [
          if (growthMap(report['decision_recommendation']).isNotEmpty)
            '下一步决策：${const {
                  'clarify': '先核实决定性未知事实',
                  'revise_goal': '重新评估、调整或取消当前目标',
                  'act_now': '停止重复预测，执行已经可行的下一步'
                }[growthMap(report['decision_recommendation'])['choice']] ?? '优先检验第4部分中标出的行动实验；若未标出，说明其可行性或把握仍不足'}。',
          '${report['cycle_policy'] ?? ''}',
          '本次结果：${const {
                'PENDING': '尚未观察',
                'SUCCESS': '主事件达成',
                'FAILED': '主事件未达成',
                'PARTIAL': '部分完成',
                'CANCELLED': '已取消',
                'UNOBSERVED': '无法观察'
              }[p['outcome']] ?? p['outcome']}。',
          if (review.isNotEmpty)
            '复盘：${review['status'] == 'COMPLETE' ? 'LLM与JEV均已参与' : '草稿或尚未完成联合分析'}。',
          for (final entry in const {
            'timeline': '实际过程',
            'breakpoint': '实际断点',
            'intervention_done': '改进实际落实情况',
            'learning': '自己的理解',
            'attitude_before': '原先态度',
            'attitude_after': '现在态度及依据',
          }.entries)
            if (EvidenceForecastScience.text(
              growthMap(review['user_observations'])[entry.key],
            ).isNotEmpty)
              '${entry.value}：${growthMap(review['user_observations'])[entry.key]}',
          for (final entry in const {
            'summary': 'AI复盘',
            'learning': '理论学习',
            'attitude_reconsideration': '态度修正建议',
            'next_experiment': '下一次验证',
            'next_action': '下一步',
            'stop_rule': '何时停止',
          }.entries)
            if (EvidenceForecastScience.text(aiReview[entry.key]).isNotEmpty)
              '${entry.value}：${aiReview[entry.key]}',
          if (growthMap(review['jev_review']).isNotEmpty)
            'JEV复盘判断：${verdict(growthMap(growthMap(growthMap(review['jev_review'])['answers'])['review_quality'])['choice'])}；下一步：${verdict(growthMap(growthMap(growthMap(review['jev_review'])['answers'])['next_step'])['choice'])}。',
        ].join('\n\n'),
      },
    ]);
    sections.add({
      'title': '8 · 理论与方法依据',
      'body': 'TPB：意向与实际控制共同影响行为，权重需要结合行为和人群研究。\nhttps://people.umass.edu/aizen/int.html\nhttps://people.umass.edu/aizen/abc.html\n\n'
          'COM-B：能力、机会、动机之间构成行为系统。\nhttps://doi.org/10.1186/1748-5908-6-42\n\n'
          '执行意图：把明确情境与具体反应连接起来的行动策略。\nhttps://doi.org/10.1016/S0065-2601(06)38002-1\n\n'
          '概率校准：需要将预测与真实观察比较，并在留出数据中检验。\nhttps://doi.org/10.1186/s12916-019-1466-7\n\n'
          '这些来源支持理论结构或验证原则，不提供本应用的通用权重，也不证明本次预测准确；本应用的样本门槛是工程规则，仍须前瞻性检验。',
    });
    return sections;
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
