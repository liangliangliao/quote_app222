import 'evidence_growth_forecast_science.dart';
import 'evidence_growth_journey_models.dart';

class ReferenceForecastReport {
  static String percent(dynamic value, {bool? lower}) {
    final p = EvidenceForecastScience.probability(value);
    if (p == null) return '计算未完成';
    if (lower != null) {
      final n = lower ? (p * 20).floor() * 5 : (p * 20).ceil() * 5;
      return '$n%';
    }
    if (p < .025) return '低于5%';
    if (p > .975) return '高于95%';
    return '约${(p * 20).round() * 5}%';
  }

  static String direction(dynamic value) {
    final p = EvidenceForecastScience.probability(value);
    if (p == null) return '可稍后重试';
    if (p < .3) return '发生的可能性偏低';
    if (p < .7) return '存在可能，较依赖具体条件';
    return '发生的可能性偏高';
  }

  static String researchLabel(GrowthData result) =>
      const {
        'WEB': '已自动联网检索，来源见报告末尾。',
        'ENCYCLOPEDIA': '已自动读取公开百科资料，身份理解见下方。',
        'SELECTED': '采用你选定的资料。',
        'NOT_PUBLIC': '采用你提供的资料与明确假设。',
        'AMBIGUOUS': '存在同名歧义，暂按假设粗估；可补充身份或手动选定资料。',
        'NO_SOURCES': '本次未取得可引用的网络资料，继续基于常识与明确假设粗估。',
      }[growthMap(result['research'])['status']] ??
      '资料状态见下方来源。';

  static String markdown(GrowthData r) {
    final profile = growthMap(r['profile']);
    final snapshot = growthMap(r['input_snapshot']);
    final range = growthMap(r['assumption_range']);
    final answers = growthMap(growthMap(r['jev'])['answers']);
    final sources = growthRows(r['sources']);
    final names = {for (final s in sources) s['id']: s['title']};
    return [
      '同情境参考报告 · ${snapshot['reference_mode'] == 'PERSON' ? snapshot['person_identity'] : '全世界人群'}',
      if (r['estimate_available'] == true) ...[
        '粗略可能性：${percent(r['estimate'])} · ${direction(r['estimate'])}',
        '判断把握：${r['estimate_confidence'] == 'medium' ? '中等' : '较低'}。${r['confidence_note'] ?? ''}',
        if (range.isNotEmpty)
          '可能范围：${percent(range['low'], lower: true)}—${percent(range['high'], lower: false)}。${r['range_note']}',
      ] else
        '${r['unavailable_reason'] ?? '旧报告未给出概率，可使用当前表单重新生成粗估。'}',
      researchLabel(r),
      '参照理解：${profile['identity_summary']}',
      '主要影响：${const {
            'capability': '能力与技能',
            'opportunity': '机会与资源',
            'motivation': '动机、兴趣与态度',
            'habit': '习惯与相似经历',
            'planning': '计划与自我调节',
            'unknown': '多种未知条件，结合下面的情景判断'
          }[growthMap(answers['dominant_dimension'])['choice']] ?? '见下面的因素分析'}。',
      '综合判断与可借鉴之处：${profile['theory_explanation']}',
      '行动：${snapshot['action']}\n标准：${growthMap(snapshot['event_contract'])['success_criterion']}\n窗口：${growthMap(snapshot['event_contract'])['observation_window']}',
      '相同外部条件：${snapshot['fixed_external_context']}',
      if (snapshot['reference_mode'] == 'WORLD')
        '比较范围：${snapshot['population_definition']}',
      '关键影响因素：',
      for (final row in growthRows(profile['claims']))
        '${row['dimension']} · ${const {
              'SOURCE_LINKED': '有资料对应',
              'RESEARCH_LINKED': '联网摘要线索',
              'MODEL_ASSUMPTION': '条件假设'
            }[row['evidence_status']] ?? '条件假设'}\n${row['claim']}\n${row['relevance']}${row['source_id'] == '' ? '' : '\n依据：${names[row['source_id']] ?? '提供的资料'}；片段：“${row['quote']}”'}',
      '过往经验的影响：${profile['past_behavior_analysis']}',
      '兴趣、态度与性格：${profile['attitude_and_personality_hypotheses']}',
      for (final row in growthRows(r['scenarios']))
        '${row['label']}：${growthStrings(row['assumptions']).join('；')}\n对应粗估：${percent(row['probability'])}',
      if (growthStrings(profile['unknowns']).isNotEmpty)
        '这些补充可能改变判断（可选）：${growthStrings(profile['unknowns']).join('；')}',
      '${r['note']}\n${profile['transfer_limits']}\n${r['same_situation_rule']}',
      '资料支持程度：${const {
            'adequate_for_rough_estimate': '有相关线索',
            'insufficient': '资料较少，采用条件假设',
            'contradictory': '资料存在冲突，需结合不同情景'
          }[growthMap(answers['evidence_quality'])['choice']] ?? '未完成'}。',
      'LLM：${r['llm_model']}；JEV：${growthMap(r['jev'])['model'] ?? '未完成'}。',
      if (sources.isNotEmpty) '参考资料：',
      for (final source in sources) ...[
        '${source['title']}\n${source['url'] ?? (source['kind'] == 'GROUNDED_WEB_SUMMARY' ? '联网摘要，原始来源如下' : '用户提供，未独立核实')}\n${source['retrieved_at'] ?? ''}',
        for (final link in growthRows(source['links']))
          '${link['title']}\n${link['url']}',
      ],
    ].join('\n\n');
  }
}
