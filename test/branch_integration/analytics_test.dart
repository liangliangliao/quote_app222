import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/behavior_tracking/behavior_tracking_analytics.dart';
import 'package:quote_app/behavior_tracking/behavior_tracking_models.dart';

void main() {
  test('current list tags and recorded times feed the recovered analytics', () {
    final now = DateTime(2026, 10, 12, 20);
    BehaviorTrackingRecord record(int hour, String outcome) => BehaviorTrackingRecord.fromMap({
      'record_date_ms': DateTime(2026, 10, 12).millisecondsSinceEpoch,
      'updated_at_ms': now.subtract(const Duration(hours: 10)).millisecondsSinceEpoch,
      'start_minute': hour * 60, 'end_minute': hour * 60 + 10,
      'behavior': '散步', 'trigger_text': '午饭后', 'cue_tags_json': '["阳光","门口"]',
      'entry_mode': 'quick_capture', 'template_key': 'tbr_default',
      'emotion_intensity': 3, 'energy_morning': 4,
      'long_term_impact': outcome, 'alternative': outcome.isEmpty ? '' : '继续散步',
    });
    final overview = BehaviorStatsOverview.fromRecords(
      [record(12, '精力变好'), record(12, '完成计划'), record(14, '')],
      rangeDays: 7, now: now,
    );
    expect(overview.totalMinutes, 30);
    expect(overview.topTriggers.map((x) => x.label), containsAll(['阳光', '门口']));
    expect(overview.triggerHeatmap.first.hour, 12);
    expect(overview.triggerHeatmap.first.count, 2);
    expect(overview.emotionTrend.single.avgIntensity, 3);
    expect(overview.effectComparisons.single.directionLabel, '长期偏收益');
    expect(overview.pendingFollowUps, hasLength(1));
    expect(overview.reviewClosureRate, closeTo(2 / 3, 0.001));
  });
}
