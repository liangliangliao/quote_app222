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

  static String researchLabel(GrowthData result) {
    final hasWorks = growthRows(result['sources'])
        .any((s) => s['kind'] == 'PUBLISHED_WORKS_COLLECTION');
    final status = growthMap(result['research'])['status'];
    if (hasWorks && status == 'NO_SOURCES') {
      return '已读取公开著作与观点引文，出处见资料来源。';
    }
    return const {
        'WEB': '已自动联网检索，来源见报告末尾。',
        'ENCYCLOPEDIA': '已自动读取公开百科资料，身份理解见下方。',
        'SELECTED': '采用你选定的资料。',
        'NOT_PUBLIC': '采用你提供的资料与明确假设。',
        'AMBIGUOUS': '存在同名歧义，暂按假设粗估；可补充身份或手动选定资料。',
        'NO_SOURCES': '本次未取得可引用的网络资料，继续基于常识与明确假设粗估。',
      }[status] ??
      '资料状态见下方来源。';
  }

  static String _weight(Object? value) {
    final p = EvidenceForecastScience.probability(value);
    return p == null ? '未评估' : '${(p * 100).round()}%';
  }

  static String _brief(Object? value, [int limit = 120]) =>
      EvidenceForecastScience.text(value, limit).replaceAll(RegExp(r'\s+'), ' ');

  static String sourcesMarkdown(GrowthData r) => growthRows(r['sources']).map((source) => [
    '${_brief(source['title'], 180)} · ${source['kind'] == 'PUBLISHED_WORKS_COLLECTION' ? '引文集整理，原作待核对' : source['kind'] == 'GROUNDED_WEB_SUMMARY' ? '联网摘要' : '所提供的资料'}',
    if (_brief(source['url'], 500).isNotEmpty) _brief(source['url'], 500),
    for (final link in growthRows(source['links'])) '${_brief(link['title'])}：${_brief(link['url'], 500)}',
  ].join('\n')).join('\n\n');

  static String markdown(GrowthData r, {bool includeSources = true}) {
    final profile = growthMap(r['profile']);
    final snapshot = growthMap(r['input_snapshot']);
    final range = growthMap(r['assumption_range']);
    final weights = growthMap(r['factor_weight_analysis']);
    final ranked = growthRows(weights['factors']);
    final claims = growthRows(profile['claims']);
    final obstacles = ranked.where((c) => c['evidence_status'] == 'adverse').toList()
        ..sort((a, b) => (b['opposition_contribution'] as num)
            .compareTo(a['opposition_contribution'] as num));
    for (final critical in growthRows(weights['critical_obstacles']).reversed) {
      obstacles.removeWhere((r) => r['key'] == critical['key']);
      obstacles.insert(0, critical);
    }
    final works = claims.where((c) => c['evidence_kind'] == 'AUTHORED_WORK' &&
        c['evidence_status'] != 'MODEL_ASSUMPTION').take(2);
    return [
      '同情境参考 · ${snapshot['reference_mode'] == 'PERSON' ? _brief(snapshot['person_identity']) : '全世界人群'}',
      if (r['estimate_available'] == true) ...[
        '行动发生可能性：${percent(r['estimate'])} · ${direction(r['estimate'])}',
        '判断把握：${r['estimate_confidence'] == 'medium' ? '中等' : '较低'} · 尚未用实际结果验证',
        if (range.isNotEmpty)
          '可能范围：${percent(range['low'], lower: true)}—${percent(range['high'], lower: false)}（随未知条件变化）',
      ] else _brief(r['unavailable_reason'], 160),
      if (_brief(profile['likely_attitude']).isNotEmpty)
        '可能态度：${_brief(profile['likely_attitude'])}',
      '可能行为：${_brief(profile['likely_behavior']).isEmpty ? _brief(profile['theory_explanation'], 180) : _brief(profile['likely_behavior'])}',
      '行动：${_brief(snapshot['action'], 200)}\n标准：${_brief(growthMap(snapshot['event_contract'])['success_criterion'], 200)}\n窗口：${_brief(growthMap(snapshot['event_contract'])['observation_window'])}',
      if (ranked.isNotEmpty) ...[
        '有利 ${_weight(weights['support_share'])} · 不利 ${_weight(weights['opposing_share'])} · 利弊并存 ${_weight(weights['mixed_share'])}（按重要性加权）',
        '关键因素：',
        for (final row in ranked.take(6))
          '${row['rank']}. ${_brief(row['label'], 90)} · 权重 ${_weight(row['weight'])} · ${const {'supportive': '有利', 'adverse': '不利', 'mixed': '利弊并存'}[row['evidence_status']] ?? '未知'}',
      ] else ...[
        '关键因素：',
        for (final c in claims.take(4))
          '${_brief(c['claim'])}\n${_brief(c['relevance'])}',
      ],
      if (obstacles.isNotEmpty) '可能的阻碍：',
      for (final row in obstacles.take(2))
        '${_brief(row['label'])}\n为什么可能卡住：${_brief(row['mechanism']).isEmpty ? _brief(row['importance_reason']) : _brief(row['mechanism'])}',
      if (growthMap(r['score_aggregation'])['ceiling_applied'] == true)
        '有关键条件未满足，其他有利因素无法完全抵消。',
      if (works.isNotEmpty) '著作思想与本次行动：',
      for (final c in works)
        '${_brief(c['work_title']).isEmpty ? '公开作品观点' : '《${_brief(c['work_title'])}》'}：${_brief(c['quote'], 100)}\n${_brief(c['transfer_reason'], 140)}',
      for (final row in growthRows(r['scenarios']).take(2))
        '${_brief(row['label'], 60)}：${growthStrings(row['assumptions']).take(2).map((s) => _brief(s, 60)).join('；')} → ${percent(row['probability'])}',
      researchLabel(r),
      if (includeSources && growthRows(r['sources']).isNotEmpty)
        '资料出处：\n${sourcesMarkdown(r)}',
      snapshot['reference_mode'] == 'PERSON'
          ? '思想提供态度线索，实际行动仍取决于本人习惯与当前条件。'
          : '这是所选人群的条件性模型粗估，尚非全球实际发生率。',
    ].where((s) => s.isNotEmpty).join('\n\n');
  }
}
