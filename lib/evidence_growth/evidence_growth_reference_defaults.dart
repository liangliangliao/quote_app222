import 'evidence_growth_forecast_science.dart';
import 'evidence_growth_journey_models.dart';

/// Editable starting assumptions, never evidence about a real person.
class ReferenceForecastDefaults {
  static const fields = [
    'success_criterion',
    'observation_window',
    'fixed_external_context',
    'population_definition',
  ];

  static GrowthData forAction(String rawAction) {
    final action = EvidenceForecastScience.text(rawAction, 2000);
    if (action.isEmpty) return {};
    final time = RegExp(r'后天|明天|今天|下周|本周|下个月|下月|本月|每天|每日|每周|每月')
        .firstMatch(action)
        ?.group(0);
    final durations = RegExp(
            r'(?:未来|接下来|连续|持续)\s*\d+\s*(?:小时|分钟|天|周|个月|月|年)|\d+\s*(?:小时|天|周|个月|月|年)(?:之内|内)')
        .allMatches(action)
        .map((m) => m.group(0)!)
        .toList();
    // A session's length must not replace a whole challenge's horizon.
    final duration = durations.isEmpty ? null : durations.last;
    final window = switch (time) {
      '明天' || '后天' || '今天' => '$time内；行动中指定的时刻仍须遵守',
      '下周' || '本周' || '下个月' || '下月' || '本月' => '$time内',
      '每天' || '每日' || '每周' || '每月' => duration == null
          ? '从下一次约定时点起观察${time == '每月' ? '1个月' : '7天'}（默认，可修改）'
          : '从下一次约定时点起观察$duration',
      _ => duration == null
          ? '从现在起24小时内（默认；行动中已有期限时以该期限为准，请核对）'
          : '从约定开始时点起$duration内（默认，请核对）',
    };
    return {
      'success_criterion':
          '实际完成${action.length <= 400 ? '“$action”' : '上方行动的全部要求'}；遵守行动中的时间、次数、数量和质量要求。未写明数量时按完整执行一次计算（默认，可修改）。',
      'observation_window': window,
      'fixed_external_context':
          '默认假设：参照者已获知此行动及要求，有一次自主选择是否执行的机会；地点、费用、权限和可用资源相同，未提及的外部障碍按一般日常条件处理。并不假定其已承诺执行；能力、兴趣、意愿与习惯随人而异。行动中明确写出的困难和限制全部保留。',
      'population_definition':
          '以全世界成年人作宽泛参照，保留各自能力、兴趣和习惯差异；不额外筛选爱好者或已经承诺执行的人。若行动需特定资格、资源或健康条件，分别考虑具备和不具备条件的人（模型粗估，无全球抽样数据）。',
    };
  }

  /// Only replace empty fields or values we generated previously. A user's
  /// edits (including inherited personal action criteria) always win.
  static GrowthData merge({
    required GrowthData current,
    required GrowthData previousDefaults,
    required GrowthData proposed,
  }) =>
      {
        for (final field in fields)
          field: '${current[field] ?? ''}'.trim().isEmpty ||
                  current[field] == previousDefaults[field]
              ? EvidenceForecastScience.text(proposed[field], 4000)
              : current[field],
      };
}
