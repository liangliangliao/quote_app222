import 'dart:convert';
import 'evidence_growth_dao.dart';
import 'evidence_growth_journey_models.dart';
import 'evidence_growth_models.dart';

class GrowthNotificationTarget {
  const GrowthNotificationTarget(
      {this.trialId = '',
      this.journeyId = '',
      this.node = '',
      this.kind = '',
      this.title = '',
      this.summary = ''});
  final String trialId, journeyId, node, kind, title, summary;
  static const nodes = {
    'BELIEF',
    'GOAL',
    'ACTION',
    'OUTCOME',
    'REVIEW',
    'CHANGE',
    'BELIEF_CHECKPOINT',
    'GOAL_GATE',
    'MAINTENANCE_GATE',
    'EXPLORATION_GATE'
  };
  static String nodeFor(String kind) => switch (kind) {
        'trial_start' || 'recovery_end' => 'ACTION',
        'trial_review_due' || 'missing_result' => 'OUTCOME',
        'journey_review' => 'REVIEW',
        'repeated_avoidance' => 'CHANGE',
        'journey_maintenance' => 'MAINTENANCE_GATE',
        _ => ''
      };
  static GrowthNotificationTarget fromMap(Map<String, dynamic> m) {
    String value(String key, int max) {
      final v = m[key];
      return v is String && v.length <= max ? v : '';
    }

    var trial = value('trial_id', 200), journey = value('journey_id', 200);
    if (trial.startsWith('journey:')) {
      journey = trial.substring(8);
      trial = '';
    }
    final kind = value('type', 60), candidate = value('node', 50);
    return GrowthNotificationTarget(
        trialId: trial,
        journeyId: journey,
        node: nodes.contains(candidate) ? candidate : nodeFor(kind),
        kind: kind,
        title: value('title', 150),
        summary: value('summary', 600));
  }

  String get nodeLabel =>
      GrowthJourney.labels[node] ??
      switch (node) { 'MAINTENANCE_GATE' => '保持检查', _ => '当前步骤' };
  String get key => '$journeyId:$trialId:$node';
}

class GrowthNotificationLink {
  const GrowthNotificationLink(this.targets, {this.tapToken = ''});
  final List<GrowthNotificationTarget> targets;
  final String tapToken;
  static GrowthNotificationLink? parse(String? raw) {
    final s = (raw ?? '').trim();
    if (s == 'evidence_growth') return const GrowthNotificationLink([]);
    if (s.startsWith('evidence_growth:'))
      return GrowthNotificationLink([
        GrowthNotificationTarget.fromMap({'trial_id': s.substring(16)})
      ]);
    if (!s.startsWith('{') || s.length > 100000) return null;
    try {
      final d = jsonDecode(s);
      if (d is! Map || d['module'] != 'evidence_growth') return null;
      final map = Map<String, dynamic>.from(d), rows = map['targets'];
      final candidates = rows is List
          ? rows.take(50).whereType<Map>().map((r) =>
              GrowthNotificationTarget.fromMap(Map<String, dynamic>.from(r)))
          : [GrowthNotificationTarget.fromMap(map)];
      final unique = <String, GrowthNotificationTarget>{};
      for (final t in candidates) {
        if (t.trialId.isNotEmpty || t.journeyId.isNotEmpty) unique[t.key] = t;
      }
      return GrowthNotificationLink(unique.values.toList(),
          tapToken: map['tap_token'] is String ? map['tap_token'] : '');
    } catch (_) {
      return null;
    }
  }
}

class GrowthNotificationDestination {
  const GrowthNotificationDestination(this.page,
      {this.trial, this.journey, this.node = '', this.message = ''});
  final String page, node, message;
  final RealityTrial? trial;
  final GrowthJourney? journey;
  static Future<GrowthNotificationDestination> resolve(
      EvidenceGrowthDao dao, GrowthNotificationTarget target) async {
    final trial =
        target.trialId.isEmpty ? null : await dao.byId(target.trialId);
    if (target.trialId.isNotEmpty && trial == null)
      return const GrowthNotificationDestination('MISSING',
          message: '这条通知对应的行动已删除或不在当前设备中。');
    final parent = trial == null ? null : await dao.journeys.forTrial(trial.id);
    final j = target.journeyId.isEmpty
        ? parent
        : await dao.journeys.find(target.journeyId);
    if (target.journeyId.isNotEmpty &&
        (j == null || (trial != null && parent?.id != j.id)))
      return const GrowthNotificationDestination('MISSING',
          message: '这条通知对应的目标已不可用，未打开其他目标。');
    if (trial == null)
      return j == null
          ? const GrowthNotificationDestination('MISSING',
              message: '通知缺少可定位的记录。')
          : GrowthNotificationDestination('JOURNEY',
              journey: j,
              node: target.node,
              message: j.node == target.node || j.status == 'MAINTAINING'
                  ? ''
                  : '目标状态已更新，显示当前步骤。');
    if (trial.isClosed || (j != null && j.trialId != trial.id))
      return GrowthNotificationDestination('ARCHIVE',
          trial: trial,
          journey: j,
          node: target.node,
          message: '这条提醒对应的原行动已结束，显示原记录，不重复执行。');
    if (trial.status == 'RESULT_CAPTURED' && j != null)
      return GrowthNotificationDestination('JOURNEY',
          journey: j, node: 'REVIEW', message: '结果已记录，已定位到复盘准备度选择。');
    if (target.node == 'REVIEW' && j != null)
      return GrowthNotificationDestination('JOURNEY',
          journey: j, node: 'REVIEW');
    if (trial.status == 'REVIEWED')
      return GrowthNotificationDestination('DECISION',
          trial: trial, journey: j, node: 'CHANGE');
    final node = trial.status == 'RESULT_CAPTURED'
        ? 'REVIEW'
        : target.node.isNotEmpty
            ? target.node
            : trial.status == 'READY'
                ? 'ACTION'
                : 'OUTCOME';
    return GrowthNotificationDestination('TRIAL',
        trial: trial, journey: j, node: node);
  }
}
