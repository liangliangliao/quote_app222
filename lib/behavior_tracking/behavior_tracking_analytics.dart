import 'behavior_tracking_models.dart';

class BehaviorStatsOverview {
  final int rangeDays;
  final int totalRecords;
  final int totalMinutes;
  final int daysCovered;
  final double effectiveRecordRate;
  final double reviewClosureRate;
  final List<BehaviorStatSlice> timeDistribution;
  final List<BehaviorStatSlice> topBehaviors;
  final List<BehaviorStatSlice> topTriggers;
  final List<BehaviorDailyEmotionPoint> emotionTrend;
  final List<BehaviorHeatmapCell> triggerHeatmap;
  final List<BehaviorEffectComparison> effectComparisons;
  final List<BehaviorTrackingRecord> pendingFollowUps;

  const BehaviorStatsOverview({
    required this.rangeDays,
    required this.totalRecords,
    required this.totalMinutes,
    required this.daysCovered,
    required this.effectiveRecordRate,
    required this.reviewClosureRate,
    required this.timeDistribution,
    required this.topBehaviors,
    required this.topTriggers,
    required this.emotionTrend,
    required this.triggerHeatmap,
    required this.effectComparisons,
    required this.pendingFollowUps,
  });

  factory BehaviorStatsOverview.fromRecords(List<BehaviorTrackingRecord> records, {required int rangeDays, DateTime? now}) {
    final clock = now ?? DateTime.now();
    final totalMinutes = records.fold<int>(0, (sum, record) => sum + (record.durationMinutes ?? 0));
    final days = records.map((record) {
      final date = record.recordDate;
      return DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    }).toSet();
    final effectiveRecords = records.where((record) {
      return record.trigger.trim().isNotEmpty ||
          record.emotion.trim().isNotEmpty ||
          record.emotionIntensity != null ||
          record.shortTermResult.trim().isNotEmpty ||
          record.longTermImpact.trim().isNotEmpty ||
          record.alternative.trim().isNotEmpty;
    }).length;
    final tbrRecords = records.where((record) => record.templateKey == 'tbr_default' || record.mode == 'trigger_behavior_result').toList();
    final closedTbr = tbrRecords.where((record) => record.longTermImpact.trim().isNotEmpty && record.alternative.trim().isNotEmpty).length;
    return BehaviorStatsOverview(
      rangeDays: rangeDays,
      totalRecords: records.length,
      totalMinutes: totalMinutes,
      daysCovered: days.length,
      effectiveRecordRate: records.isEmpty ? 0 : effectiveRecords / records.length,
      reviewClosureRate: tbrRecords.isEmpty ? 0 : closedTbr / tbrRecords.length,
      timeDistribution: _timeDistribution(records, totalMinutes),
      topBehaviors: _topText(records.map((record) => record.behavior), limit: 5),
      topTriggers: _topText(records.expand((record) => [record.trigger, record.cueTags]), limit: 5),
      emotionTrend: _emotionTrend(records),
      triggerHeatmap: _triggerHeatmap(records),
      effectComparisons: _effectComparisons(records),
      pendingFollowUps: _pendingFollowUps(records, clock),
    );
  }

  static List<BehaviorStatSlice> _timeDistribution(List<BehaviorTrackingRecord> records, int totalMinutes) {
    final map = <String, int>{};
    for (final record in records) {
      final minutes = record.durationMinutes ?? 0;
      if (minutes <= 0) continue;
      final key = record.category.trim().isEmpty ? '未分类' : record.category.trim();
      map[key] = (map[key] ?? 0) + minutes;
    }
    return _sortedEntries(map).map((entry) => BehaviorStatSlice(label: entry.key, value: entry.value, ratio: totalMinutes <= 0 ? 0 : entry.value / totalMinutes)).toList();
  }

  static List<BehaviorStatSlice> _topText(Iterable<String> values, {required int limit}) {
    final map = <String, int>{};
    for (final raw in values) {
      for (final part in raw.split(RegExp(r'[,，、;；\s]+'))) {
        final value = part.trim();
        if (value.isEmpty) continue;
        map[value] = (map[value] ?? 0) + 1;
      }
    }
    final total = map.values.fold<int>(0, (a, b) => a + b);
    return _sortedEntries(map).take(limit).map((entry) => BehaviorStatSlice(label: entry.key, value: entry.value, ratio: total <= 0 ? 0 : entry.value / total)).toList();
  }

  static List<BehaviorDailyEmotionPoint> _emotionTrend(List<BehaviorTrackingRecord> records) {
    final byDay = <int, List<int>>{};
    for (final record in records) {
      final value = record.emotionIntensity;
      if (value == null) continue;
      final date = record.recordDate;
      final key = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
      byDay.putIfAbsent(key, () => <int>[]).add(value);
    }
    final entries = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      return BehaviorDailyEmotionPoint(date: DateTime.fromMillisecondsSinceEpoch(entry.key), avgIntensity: avg, samples: entry.value.length);
    }).toList();
  }

  static List<BehaviorHeatmapCell> _triggerHeatmap(List<BehaviorTrackingRecord> records) {
    final map = <String, _HeatAccumulator>{};
    for (final record in records) {
      final trigger = record.trigger.trim().isNotEmpty ? record.trigger.trim() : record.cueTags.trim();
      if (trigger.isEmpty) continue;
      final minute = record.startMinute ?? record.endMinute;
      if (minute == null) continue;
      final date = record.recordDate;
      final weekday = date.weekday;
      final hour = minute ~/ 60;
      final key = '$weekday#$hour';
      map.putIfAbsent(key, () => _HeatAccumulator(weekday: weekday, hour: hour)).add(trigger);
    }
    final cells = map.values.map((acc) => acc.toCell()).toList()..sort((a, b) => b.count.compareTo(a.count));
    return cells.take(8).toList();
  }

  static List<BehaviorEffectComparison> _effectComparisons(List<BehaviorTrackingRecord> records) {
    final groups = <String, List<BehaviorTrackingRecord>>{};
    for (final record in records) {
      final key = record.behavior.trim().isNotEmpty ? record.behavior.trim() : record.category.trim();
      if (key.isEmpty) continue;
      if (record.longTermImpact.trim().isEmpty && record.energyMorning == null && record.shortTermResult.trim().isEmpty) continue;
      groups.putIfAbsent(key, () => <BehaviorTrackingRecord>[]).add(record);
    }
    final effects = <BehaviorEffectComparison>[];
    for (final entry in groups.entries) {
      if (entry.value.length < 2) continue;
      final energies = entry.value.map((record) => record.energyMorning).whereType<int>().toList();
      final negative = entry.value.where((record) => _containsAny(record.longTermImpact, const ['累', '疲', '后悔', '焦虑', '亏', '差', '晚睡', '拖延'])).length;
      final positive = entry.value.where((record) => _containsAny(record.longTermImpact, const ['好', '完成', '满足', '轻松', '精力', '收益', '推进'])).length;
      effects.add(BehaviorEffectComparison(
        behavior: entry.key,
        sampleSize: entry.value.length,
        avgNextEnergy: energies.isEmpty ? null : energies.reduce((a, b) => a + b) / energies.length,
        positiveCount: positive,
        negativeCount: negative,
      ));
    }
    effects.sort((a, b) => b.sampleSize.compareTo(a.sampleSize));
    return effects.take(6).toList();
  }

  static bool _containsAny(String text, List<String> needles) => needles.any((needle) => text.contains(needle));

  static List<BehaviorTrackingRecord> _pendingFollowUps(List<BehaviorTrackingRecord> records, DateTime now) {
    final threshold = now.subtract(const Duration(hours: 8)).millisecondsSinceEpoch;
    return records.where((record) {
      final needsDelayedOutcome = record.entryMode == 'quick_capture' || record.templateKey == 'tbr_default' || record.mode == 'trigger_behavior_result';
      return needsDelayedOutcome && record.updatedAtMs <= threshold && record.longTermImpact.trim().isEmpty;
    }).take(5).toList();
  }

  static List<MapEntry<String, int>> _sortedEntries(Map<String, int> source) {
    final entries = source.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}

class BehaviorStatSlice {
  final String label;
  final int value;
  final double ratio;

  const BehaviorStatSlice({required this.label, required this.value, required this.ratio});
}

class BehaviorDailyEmotionPoint {
  final DateTime date;
  final double avgIntensity;
  final int samples;

  const BehaviorDailyEmotionPoint({required this.date, required this.avgIntensity, required this.samples});
}

class BehaviorHeatmapCell {
  final int weekday;
  final int hour;
  final int count;
  final String topTrigger;

  const BehaviorHeatmapCell({required this.weekday, required this.hour, required this.count, required this.topTrigger});

  String get weekdayLabel => const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][weekday - 1];
  String get hourLabel => '${hour.toString().padLeft(2, '0')}:00';
}

class BehaviorEffectComparison {
  final String behavior;
  final int sampleSize;
  final double? avgNextEnergy;
  final int positiveCount;
  final int negativeCount;

  const BehaviorEffectComparison({
    required this.behavior,
    required this.sampleSize,
    required this.avgNextEnergy,
    required this.positiveCount,
    required this.negativeCount,
  });

  String get directionLabel {
    if (negativeCount > positiveCount) return '长期偏亏损';
    if (positiveCount > negativeCount) return '长期偏收益';
    return '影响待确认';
  }
}

class _HeatAccumulator {
  final int weekday;
  final int hour;
  final Map<String, int> triggers = <String, int>{};

  _HeatAccumulator({required this.weekday, required this.hour});

  void add(String trigger) {
    triggers[trigger] = (triggers[trigger] ?? 0) + 1;
  }

  BehaviorHeatmapCell toCell() {
    final sorted = triggers.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final count = triggers.values.fold<int>(0, (a, b) => a + b);
    return BehaviorHeatmapCell(weekday: weekday, hour: hour, count: count, topTrigger: sorted.isEmpty ? '未标记' : sorted.first.key);
  }
}
