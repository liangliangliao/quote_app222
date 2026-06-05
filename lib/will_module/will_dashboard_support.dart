import 'package:flutter/material.dart';

import 'will_models.dart';
import 'will_seed.dart';
import 'will_route_resolver.dart';

String trainingTypeForTaskTitle(String title) {
  switch (title) {
    case '10 秒起步':
      return '启动型';
    case '30 秒注意锁定':
      return '注意锁定型';
    case '90 秒延迟诱惑':
      return '抗诱惑型';
    case '晚间意志复盘':
      return '复盘型';
    default:
      return '通用型';
  }
}

List<WillNamedCount> problemHitsFromExecutions(List<WillTaskExecutionEntry> executions) {
  final counts = <String, int>{};
  for (final execution in executions) {
    final task = WillRouteResolver.taskByTitle(execution.taskTitle);
    if (task == null) continue;
    for (final problem in WillRouteResolver.recommendedProblemsForTask(task)) {
      counts[problem.zoneTitle] = (counts[problem.zoneTitle] ?? 0) + 1;
    }
  }
  final list = counts.entries.map((e) => WillNamedCount(label: e.key, count: e.value)).toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  return list;
}

List<WillNamedCount> taskTypeCountsFromExecutions(List<WillTaskExecutionEntry> executions) {
  final counts = <String, int>{'启动型': 0, '注意锁定型': 0, '抗诱惑型': 0, '复盘型': 0};
  for (final execution in executions) {
    final label = trainingTypeForTaskTitle(execution.taskTitle);
    counts[label] = (counts[label] ?? 0) + 1;
  }
  final list = counts.entries.map((e) => WillNamedCount(label: e.key, count: e.value)).toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  return list;
}

List<WillNamedCount> weakestTaskTypesFromExecutions(List<WillTaskExecutionEntry> executions) {
  final list = taskTypeCountsFromExecutions(executions)..sort((a, b) => a.count.compareTo(b.count));
  return list;
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String weekdayZh(int weekday) {
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  return labels[(weekday - 1).clamp(0, 6)];
}

class DayActivitySummary {
  final DateTime day;
  final int total;
  final int executionCount;
  final int reviewCount;
  final int zoneCount;
  final double avgEffort;

  const DayActivitySummary({
    required this.day,
    required this.total,
    required this.executionCount,
    required this.reviewCount,
    required this.zoneCount,
    required this.avgEffort,
  });
}

List<DayActivitySummary> lastNDayActivity({
  required List<WillTaskExecutionEntry> executions,
  required List<WillReviewEntry> reviews,
  required List<WillZoneVisitEntry> zones,
  int days = 7,
}) {
  final now = DateTime.now();
  final today = dayOnly(now);
  final map = <String, Map<String, double>>{};

  void touch(DateTime day, {int execution = 0, int review = 0, int zone = 0, int effort = 0}) {
    final key = dayOnly(day).toIso8601String();
    final item = map.putIfAbsent(key, () => {'e': 0, 'r': 0, 'z': 0, 'eff': 0, 'effc': 0});
    item['e'] = (item['e'] ?? 0) + execution;
    item['r'] = (item['r'] ?? 0) + review;
    item['z'] = (item['z'] ?? 0) + zone;
    if (effort > 0) {
      item['eff'] = (item['eff'] ?? 0) + effort;
      item['effc'] = (item['effc'] ?? 0) + 1;
    }
  }

  for (final e in executions) {
    touch(DateTime.fromMillisecondsSinceEpoch(e.completedAtMs), execution: 1, effort: e.effortLevel);
  }
  for (final r in reviews) {
    touch(DateTime.fromMillisecondsSinceEpoch(r.updatedAtMs), review: 1);
  }
  for (final z in zones) {
    touch(DateTime.fromMillisecondsSinceEpoch(z.visitedAtMs), zone: 1);
  }

  final out = <DayActivitySummary>[];
  for (int i = days - 1; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    final item = map[day.toIso8601String()] ?? const {'e': 0, 'r': 0, 'z': 0, 'eff': 0, 'effc': 0};
    final e = (item['e'] ?? 0).toInt();
    final r = (item['r'] ?? 0).toInt();
    final z = (item['z'] ?? 0).toInt();
    final effc = (item['effc'] ?? 0).toInt();
    final eff = (item['eff'] ?? 0);
    out.add(DayActivitySummary(
      day: day,
      total: e + r + z,
      executionCount: e,
      reviewCount: r,
      zoneCount: z,
      avgEffort: effc == 0 ? 0 : eff / effc,
    ));
  }
  return out;
}

int currentTrainingStreak({
  required List<WillTaskExecutionEntry> executions,
  required List<WillReviewEntry> reviews,
  required List<WillZoneVisitEntry> zones,
}) {
  final activeDays = <String>{};
  for (final e in executions) {
    activeDays.add(dayOnly(DateTime.fromMillisecondsSinceEpoch(e.completedAtMs)).toIso8601String());
  }
  for (final r in reviews) {
    activeDays.add(dayOnly(DateTime.fromMillisecondsSinceEpoch(r.updatedAtMs)).toIso8601String());
  }
  for (final z in zones) {
    activeDays.add(dayOnly(DateTime.fromMillisecondsSinceEpoch(z.visitedAtMs)).toIso8601String());
  }
  int streak = 0;
  var cursor = dayOnly(DateTime.now());
  while (activeDays.contains(cursor.toIso8601String())) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

List<WillNamedCount> effortDistribution(List<WillTaskExecutionEntry> executions) {
  final counts = <String, int>{'Lv1': 0, 'Lv2': 0, 'Lv3': 0, 'Lv4': 0, 'Lv5': 0};
  for (final e in executions) {
    final key = 'Lv${e.effortLevel.clamp(1, 5)}';
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts.entries.map((e) => WillNamedCount(label: e.key, count: e.value)).toList();
}

class DashboardBundle {
  final WillDashboardSummary summary;
  final List<WillTaskChainSummary> chains;
  final List<WillReviewEntry> reviews;
  final List<WillTaskExecutionEntry> executions;
  final List<WillReviewEntry> allReviews;
  final List<WillTaskExecutionEntry> allExecutions;
  final List<WillZoneVisitEntry> recentZoneVisits;
  final List<WillNamedCount> zoneCounts;
  final List<WillNamedCount> problemHits;
  final List<WillNamedCount> taskTypeCounts;
  final List<WillNamedCount> weakestTaskTypes;
  final int streak;
  final List<DayActivitySummary> dailyActivity;
  final List<WillNamedCount> effortDistribution;
  final List<WillStageMilestoneEntry> stageMilestones;
  final WillStageRuntimeState? stageRuntimeState;
  final Map<String, WillSuggestionState> suggestionStates;

  const DashboardBundle({
    required this.summary,
    required this.chains,
    required this.reviews,
    required this.executions,
    required this.allReviews,
    required this.allExecutions,
    required this.recentZoneVisits,
    required this.zoneCounts,
    required this.problemHits,
    required this.taskTypeCounts,
    required this.weakestTaskTypes,
    required this.streak,
    required this.dailyActivity,
    required this.effortDistribution,
    required this.stageMilestones,
    required this.stageRuntimeState,
    required this.suggestionStates,
  });

  int get streakDays => streak;
  List<WillStageMilestoneEntry> get milestones => stageMilestones;
}

class SmartSuggestion {
  final String key;
  final String title;
  final String subtitle;
  final String actionLabel;
  final String kind;
  final String refTitle;
  final String priorityLabel;
  final String horizonLabel;
  final List<String> unitIds;
  final int priorityScore;

  const SmartSuggestion({
    required this.key,
    required this.zoneTitle,
    required this.subtitle,
    required this.actionLabel,
    required this.kind,
    required this.refTitle,
    required this.priorityLabel,
    required this.horizonLabel,
    required this.unitIds,
    required this.priorityScore,
  });
}

class StageStatus {
  final String key;
  final String label;
  final bool achieved;
  final String detail;

  const StageStatus({required this.key, required this.label, required this.achieved, required this.detail});
}

class StageCheckpoint {
  final String label;
  final bool done;

  const StageCheckpoint({required this.label, required this.done});
}

class CoachStage {
  final String key;
  final String label;
  final String title;
  final String subtitle;
  final List<String> focusPoints;
  final List<String> recommendedUnitIds;
  final String primaryActionLabel;
  final String primaryActionKind;
  final String primaryActionRef;
  final List<StageCheckpoint> checkpoints;
  final String progressLabel;
  final String nextStageLabel;
  final String nextStageHint;

  const CoachStage({
    required this.key,
    required this.label,
    required this.zoneTitle,
    required this.subtitle,
    required this.focusPoints,
    required this.recommendedUnitIds,
    required this.primaryActionLabel,
    required this.primaryActionKind,
    required this.primaryActionRef,
    required this.checkpoints,
    required this.progressLabel,
    required this.nextStageLabel,
    required this.nextStageHint,
  });

  String get stageLabel => label;
  String get actionLabel => primaryActionLabel;
  String get kind => primaryActionKind;
  String get refTitle => primaryActionRef;
  List<String> get unitIds => recommendedUnitIds;
  bool get completed => checkpoints.every((e) => e.done);
}

String progressSummary(List<StageCheckpoint> checkpoints) {
  final done = checkpoints.where((e) => e.done).length;
  return '$done / ${checkpoints.length} 条已完成';
}

double progressValue(List<StageCheckpoint> checkpoints) {
  if (checkpoints.isEmpty) return 0;
  final done = checkpoints.where((e) => e.done).length;
  return done / checkpoints.length;
}

WillTaskExecutionEntry? latestExecution(List<WillTaskExecutionEntry> executions) {
  if (executions.isEmpty) return null;
  final sorted = [...executions]..sort((a, b) => b.completedAtMs.compareTo(a.completedAtMs));
  return sorted.first;
}

WillReviewEntry? latestReview(List<WillReviewEntry> reviews) {
  if (reviews.isEmpty) return null;
  final sorted = [...reviews]..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
  return sorted.first;
}

WillZoneVisitEntry? latestZoneVisit(List<WillZoneVisitEntry> visits) {
  if (visits.isEmpty) return null;
  final sorted = [...visits]..sort((a, b) => b.visitedAtMs.compareTo(a.visitedAtMs));
  return sorted.first;
}

List<String> defaultUnitIdsForTask(String taskTitle) {
  switch (taskTitle) {
    case '10 秒起步':
      return ['I-006', 'I-009'];
    case '30 秒注意锁定':
      return ['E-003', 'R-003'];
    case '90 秒延迟诱惑':
      return ['P-017', 'X-001'];
    case '晚间意志复盘':
      return ['R-003', 'F-011'];
    default:
      return ['W-001', 'R-008'];
  }
}

WillWorldZone? primaryZoneForTaskTitle(String taskTitle) {
  final task = WillRouteResolver.taskByTitle(taskTitle);
  if (task == null) return null;
  final zones = WillRouteResolver.recommendedZonesForTask(task);
  return zones.isEmpty ? null : zones.first;
}

List<String> defaultUnitIdsForZone(String zoneTitle) {
  switch (zoneTitle) {
    case '起意场':
      return ['D-083', 'I-006'];
    case '努力坡':
      return ['E-003', 'R-003'];
    case '诱惑市集':
      return ['P-017', 'X-001'];
    case '阻塞谷':
      return ['O-001', 'I-015'];
    default:
      return ['W-001', 'R-008'];
  }
}

List<StageStatus> evaluateStageStatuses(DashboardBundle data) {
  final hasPlan = data.summary.savedPlanCount > 0;
  final hasExecution = data.summary.executionCount > 0;
  final hasReview = data.summary.reviewCount > 0;
  final hasZone = data.summary.zoneVisitCount > 0;
  final activeDays = data.dailyActivity.where((e) => e.total > 0).length;
  final avgEffort = data.executions.isEmpty
      ? 0.0
      : data.executions.map((e) => e.effortLevel).reduce((a, b) => a + b) / data.executions.length;
  return [
    StageStatus(
      key: 'starter',
      label: '起步期',
      achieved: hasPlan && hasExecution && hasReview,
      detail: '计划、执行、复盘三点已具备，说明最小训练闭环已经跑起来。',
    ),
    StageStatus(
      key: 'recovery',
      label: '恢复节奏期',
      achieved: activeDays >= 2,
      detail: '最近 7 天重新接上至少 2 个活跃日，说明节奏开始恢复。',
    ),
    StageStatus(
      key: 'loop',
      label: '建立闭环期',
      achieved: hasExecution && hasReview && hasZone,
      detail: '执行、复盘、镜像城三点贯通，说明训练不再停留在单点。',
    ),
    StageStatus(
      key: 'stable',
      label: '稳定训练期',
      achieved: data.streak >= 3 && activeDays >= 4 && avgEffort >= 3.0,
      detail: '连续性、活跃度与 effort 都达标，说明训练已进入较稳定状态。',
    ),
  ];
}

String stageLabelFromKey(String key) {
  switch (key) {
    case 'starter':
      return '起步期';
    case 'loop':
      return '建立闭环期';
    case 'recovery':
      return '恢复节奏期';
    case 'stable':
      return '稳定训练期';
    default:
      return '训练阶段';
  }
}

bool isRecentStageChange(WillStageRuntimeState? state) {
  if (state == null) return false;
  if (state.previousStageKey.isEmpty) return false;
  return DateTime.now().millisecondsSinceEpoch - state.changedAtMs < const Duration(hours: 48).inMilliseconds;
}

CoachStage buildCoachStage(DashboardBundle data) {
  final latestExecutionEntry = latestExecution(data.executions);
  final latestReviewEntry = latestReview(data.reviews);
  final latestZoneEntry = latestZoneVisit(data.recentZoneVisits);
  final hasPlan = data.summary.savedPlanCount > 0;
  final hasExecution = data.summary.executionCount > 0;
  final hasReview = data.summary.reviewCount > 0;
  final hasZone = data.summary.zoneVisitCount > 0;
  final activeDays = data.dailyActivity.where((e) => e.total > 0).length;
  final avgEffort = data.executions.isEmpty
      ? 0.0
      : data.executions.map((e) => e.effortLevel).reduce((a, b) => a + b) / data.executions.length;

  if (!hasPlan || !hasExecution || !hasReview) {
    final checkpoints = [
      StageCheckpoint(label: '已保存第一条 if-then 计划', done: hasPlan),
      StageCheckpoint(label: '已完成第一次现实执行', done: hasExecution),
      StageCheckpoint(label: '已写下第一次复盘', done: hasReview),
    ];
    return CoachStage(
      key: 'starter',
      label: '起步期',
      title: '先把最小训练闭环跑起来',
      subtitle: '你现在最重要的不是一次做很多，而是把“计划 → 执行 → 复盘”这条最小链路真的走通一次。',
      focusPoints: const ['先写第一条 if-then 计划', '完成一次最小现实执行', '当天补一条复盘，形成第一圈闭环'],
      recommendedUnitIds: const ['W-002', 'I-006', 'R-003'],
      primaryActionLabel: !hasPlan ? '先建立第一条 if-then 计划' : (!hasExecution ? '去做第一次现实执行' : '补第一次复盘'),
      primaryActionKind: !hasPlan ? 'task' : (!hasExecution ? 'task' : 'review'),
      primaryActionRef: !hasPlan
          ? '10 秒起步'
          : (!hasExecution ? '10 秒起步' : (latestExecutionEntry?.taskTitle ?? '晚间意志复盘')),
      checkpoints: checkpoints,
      progressLabel: progressSummary(checkpoints),
      nextStageLabel: '建立闭环期',
      nextStageHint: '当你把“执行 + 复盘 + 镜像城预演”接起来后，训练重点会转向让这条链真正稳定下来。',
    );
  }

  if (!hasZone) {
    final checkpoints = [
      const StageCheckpoint(label: '至少有 1 次执行记录', done: true),
      const StageCheckpoint(label: '至少有 1 条复盘记录', done: true),
      StageCheckpoint(label: '至少进入过 1 次镜像城', done: hasZone),
    ];
    final taskTitle = latestReviewEntry?.taskTitle ?? latestExecutionEntry?.taskTitle ?? '10 秒起步';
    final zone = primaryZoneForTaskTitle(taskTitle);
    return CoachStage(
      key: 'loop',
      label: '建立闭环期',
      title: '把复盘与镜像城真正接上',
      subtitle: '你已经有了最小闭环。现在要做的，是把“现实训练”和“虚拟预演”接起来，形成更稳定的训练回路。',
      focusPoints: const ['把执行接到复盘', '把复盘接到镜像城', '同一条任务先不要频繁切换'],
      recommendedUnitIds: const ['R-003', 'W-001', 'P-017'],
      primaryActionLabel: zone == null ? '进入起意场' : '进入${zone.zoneTitle}',
      primaryActionKind: 'zone',
      primaryActionRef: zone?.zoneTitle ?? '起意场',
      checkpoints: checkpoints,
      progressLabel: progressSummary(checkpoints),
      nextStageLabel: '稳定训练期',
      nextStageHint: '当执行、复盘和镜像城都逐步接上后，训练重点会从“补环节”转向“稳节奏、提质量”。',
    );
  }

  if (data.streak == 0 || activeDays < 2) {
    final checkpoints = [
      StageCheckpoint(label: '今天重新接上一条训练行为', done: data.streak > 0),
      StageCheckpoint(label: '近 7 天至少活跃 2 天', done: activeDays >= 2),
      StageCheckpoint(label: '补一条低阻力任务或复盘', done: hasExecution || hasReview),
    ];
    return CoachStage(
      key: 'recovery',
      label: '恢复节奏期',
      title: '先把节奏重新接上，不先追求强度',
      subtitle: '你现在最重要的不是做难任务，而是重新形成连续训练感。节奏先于强度。',
      focusPoints: const ['先恢复连续训练', '先做低阻力任务', '让今天重新留下训练痕迹'],
      recommendedUnitIds: const ['D-083', 'I-009', 'W-001'],
      primaryActionLabel: '去做 10 秒起步',
      primaryActionKind: 'task',
      primaryActionRef: '10 秒起步',
      checkpoints: checkpoints,
      progressLabel: progressSummary(checkpoints),
      nextStageLabel: '稳定训练期',
      nextStageHint: '当你恢复连续训练并连续几天留下痕迹后，训练会更自然地进入稳定期。',
    );
  }

  final checkpoints = [
    StageCheckpoint(label: '连续训练至少 3 天', done: data.streak >= 3),
    StageCheckpoint(label: '近 7 天至少活跃 4 天', done: activeDays >= 4),
    StageCheckpoint(label: '最近平均 effort 达到 3.0', done: avgEffort >= 3.0),
  ];
  final weakest = data.weakestTaskTypes.isNotEmpty ? data.weakestTaskTypes.first.label : '注意锁定型';
  if (weakest == '抗诱惑型') {
    return CoachStage(
      key: 'stable',
      label: '稳定训练期',
      title: '维持节奏，并补最薄弱的一类训练',
      subtitle: '你已经进入更稳定的训练区间。下一步的重点不是从头来，而是固定一条问题路径，持续练深。',
      focusPoints: const ['保持连续性', '不要同时追太多目标', '开始提高一次更高 effort 的训练质量'],
      recommendedUnitIds: const ['E-003', 'T-005', 'P-017'],
      primaryActionLabel: '去做 90 秒延迟诱惑',
      primaryActionKind: 'task',
      primaryActionRef: '90 秒延迟诱惑',
      checkpoints: checkpoints,
      progressLabel: progressSummary(checkpoints),
      nextStageLabel: '深化训练期',
      nextStageHint: '下一步会更注重固定一条问题路径练深，并逐步提高高 effort 训练的质量。',
    );
  }
  if (weakest == '注意锁定型') {
    return CoachStage(
      key: 'stable',
      label: '稳定训练期',
      title: '维持节奏，并补最薄弱的一类训练',
      subtitle: '你已经进入更稳定的训练区间。下一步的重点不是从头来，而是固定一条问题路径，持续练深。',
      focusPoints: const ['保持连续性', '不要同时追太多目标', '开始提高一次更高 effort 的训练质量'],
      recommendedUnitIds: const ['E-003', 'T-005', 'R-003'],
      primaryActionLabel: '去做 30 秒注意锁定',
      primaryActionKind: 'task',
      primaryActionRef: '30 秒注意锁定',
      checkpoints: checkpoints,
      progressLabel: progressSummary(checkpoints),
      nextStageLabel: '深化训练期',
      nextStageHint: '下一步会更注重固定一条问题路径练深，并逐步提高高 effort 训练的质量。',
    );
  }
  return CoachStage(
    key: 'stable',
    label: '稳定训练期',
    title: '维持节奏，并开始深化一条问题路径',
    subtitle: '你已经进入更稳定的训练区间。下一步更适合把一条高频问题路径固定下来，持续练深，而不是频繁切换。',
    focusPoints: const ['固定一条问题路径练深', '保持连续性', '开始提高一次更高 effort 训练质量'],
    recommendedUnitIds: const ['W-001', 'R-008', 'A-001'],
    primaryActionLabel: '查看训练总览',
    primaryActionKind: 'dashboard',
    primaryActionRef: 'dashboard',
    checkpoints: checkpoints,
    progressLabel: progressSummary(checkpoints),
    nextStageLabel: '深化训练期',
    nextStageHint: '下一步会更注重固定一条问题路径练深，并逐步提高高 effort 训练的质量。',
  );
}

List<SmartSuggestion> buildSmartSuggestions(DashboardBundle data) {
  final suggestions = <SmartSuggestion>[];
  final stateMap = data.suggestionStates;

  bool isSoftHidden(String key) {
    final state = stateMap[key];
    if (state == null || state.completedAtMs == null) return false;
    return DateTime.now().millisecondsSinceEpoch - state.completedAtMs! < const Duration(hours: 36).inMilliseconds;
  }

  void addSuggestion(SmartSuggestion s) {
    if (!isSoftHidden(s.key)) suggestions.add(s);
  }

  final latestExecutionEntry = latestExecution(data.executions);
  final latestReviewEntry = latestReview(data.reviews);
  final latestZone = latestZoneVisit(data.recentZoneVisits);

  final hasPlan = data.summary.savedPlanCount > 0;
  final hasExecution = data.summary.executionCount > 0;
  final hasReview = data.summary.reviewCount > 0;
  final hasZone = data.summary.zoneVisitCount > 0;

  if (!hasPlan) {
    addSuggestion(const SmartSuggestion(
      key: 'create_first_plan',
      title: '先建立第一条 if-then 计划',
      subtitle: '你的训练还没形成最小启动点。先把“如果…那么…”写下来，会比空想更容易进入现实动作。',
      actionLabel: '去做 10 秒起步',
      kind: 'task',
      refTitle: '10 秒起步',
      priorityLabel: '高优先级',
      horizonLabel: '短期',
      unitIds: ['W-002', 'I-015'],
      priorityScore: 100,
    ));
  }

  if (hasPlan && !hasExecution) {
    addSuggestion(const SmartSuggestion(
      key: 'first_execution',
      title: '先完成第一次现实执行',
      subtitle: '你已经有了计划，但还缺少让训练真正落地的一步。先完成一次最小现实执行。',
      actionLabel: '去做 10 秒起步',
      kind: 'task',
      refTitle: '10 秒起步',
      priorityLabel: '高优先级',
      horizonLabel: '短期',
      unitIds: ['I-006', 'O-001'],
      priorityScore: 95,
    ));
  }

  if (hasExecution && !hasReview) {
    addSuggestion(SmartSuggestion(
      key: 'first_review',
      title: '补上第一次复盘',
      subtitle: '你已经开始行动，但训练还没形成反思闭环。现在就把这次执行带进复盘。',
      actionLabel: '去写复盘',
      kind: 'review',
      refTitle: latestExecutionEntry?.taskTitle ?? '晚间意志复盘',
      priorityLabel: '高优先级',
      horizonLabel: '短期',
      unitIds: ['R-003', 'F-011'],
      priorityScore: 92,
    ));
  }

  if (latestExecutionEntry != null) {
    final latestReviewTime = latestReviewEntry?.updatedAtMs ?? 0;
    if (latestExecutionEntry.completedAtMs > latestReviewTime) {
      addSuggestion(SmartSuggestion(
        key: 'execution_to_review',
        title: '你刚完成了一次执行，下一步先立刻复盘',
        subtitle: '趁这次行动还很鲜活，最适合马上写一条复盘，把“做了什么”和“为什么这样”连起来。',
        actionLabel: '带着这次执行去复盘',
        kind: 'review',
        refTitle: latestExecutionEntry.taskTitle,
        priorityLabel: '高优先级',
        horizonLabel: '短期',
        unitIds: defaultUnitIdsForTask(latestExecutionEntry.taskTitle),
        priorityScore: 94,
      ));
    }
  }

  if (latestReviewEntry != null) {
    final latestZoneTime = latestZone?.visitedAtMs ?? 0;
    if (latestReviewEntry.updatedAtMs > latestZoneTime) {
      final taskTitle = latestReviewEntry.taskTitle ?? latestExecutionEntry?.taskTitle ?? '10 秒起步';
      final zone = primaryZoneForTaskTitle(taskTitle);
      if (zone != null) {
        addSuggestion(SmartSuggestion(
          key: 'review_to_zone',
          title: '复盘之后，先去镜像城预演下一次难点',
          subtitle: '你已经把这次行动写出来了。下一步更适合去 ${zone.zoneTitle} 里先模拟一次，把下次最容易卡住的地方预演掉。',
          actionLabel: '进入${zone.zoneTitle}',
          kind: 'zone',
          refTitle: zone.zoneTitle,
          priorityLabel: '高优先级',
          horizonLabel: '短期',
          unitIds: defaultUnitIdsForZone(zone.zoneTitle),
          priorityScore: 90,
        ));
      }
    }
  }

  if (latestZone != null) {
    final latestExecutionTime = latestExecutionEntry?.completedAtMs ?? 0;
    if (latestZone.visitedAtMs > latestExecutionTime) {
      final mappedTasks = kWillTaskPlans.where((task) {
        final zones = WillRouteResolver.recommendedZonesForTask(task);
        return zones.any((z) => z.zoneTitle == latestZone.zoneTitle);
      }).toList();
      final firstTask = mappedTasks.isNotEmpty ? mappedTasks.first : null;
      if (firstTask != null) {
        addSuggestion(SmartSuggestion(
          key: 'zone_to_execution',
          title: '把刚才的虚拟预演带回现实做一次',
          subtitle: '你刚进入过 ${latestZone.zoneTitle}。现在最适合把那次预演立即带回现实，完成一次对应动作。',
          actionLabel: '去做${firstTask.zoneTitle}',
          kind: 'task',
          refTitle: firstTask.zoneTitle,
          priorityLabel: '高优先级',
          horizonLabel: '短期',
          unitIds: defaultUnitIdsForTask(firstTask.zoneTitle),
          priorityScore: 89,
        ));
      }
    }
  }

  if (!hasZone) {
    addSuggestion(const SmartSuggestion(
      key: 'first_zone_visit',
      title: '还没进入过镜像城，建议先从起意场开始',
      subtitle: '现实训练已经开始了。现在更适合进入镜像城先做一次低阻力预演，帮助你把训练变得更可视化。',
      actionLabel: '进入起意场',
      kind: 'zone',
      refTitle: '起意场',
      priorityLabel: '中优先级',
      horizonLabel: '短期',
      unitIds: ['D-083', 'I-006'],
      priorityScore: 80,
    ));
  }

  if (data.streak == 0 && (hasPlan || hasExecution || hasReview)) {
    addSuggestion(const SmartSuggestion(
      key: 'resume_cadence',
      title: '先恢复训练节奏',
      subtitle: '你的训练记录已经存在，但今天还没有留下痕迹。先做一个低阻力动作，把训练节奏重新接上。',
      actionLabel: '去做 10 秒起步',
      kind: 'task',
      refTitle: '10 秒起步',
      priorityLabel: '高优先级',
      horizonLabel: '短期',
      unitIds: ['D-083', 'I-009'],
      priorityScore: 88,
    ));
  }

  final activeDays = data.dailyActivity.where((e) => e.total > 0).length;
  if (activeDays < 2 && (hasExecution || hasReview || hasZone)) {
    addSuggestion(const SmartSuggestion(
      key: 'light_reconnect',
      title: '最近训练偏稀，建议补一个轻量动作',
      subtitle: '你最近一周的训练节奏还比较疏。现在更适合补一个低门槛动作，而不是追求大强度。',
      actionLabel: '去做 10 秒起步',
      kind: 'task',
      refTitle: '10 秒起步',
      priorityLabel: '中优先级',
      horizonLabel: '短期',
      unitIds: ['W-001', 'I-006'],
      priorityScore: 75,
    ));
  }

  final weakestTaskType = data.weakestTaskTypes.isNotEmpty ? data.weakestTaskTypes.first.label : null;
  if (weakestTaskType == '抗诱惑型') {
    addSuggestion(const SmartSuggestion(
      key: 'weak_anti_temptation',
      title: '最近更该补“抗诱惑型”训练',
      subtitle: '从你最近的执行分布看，抗诱惑训练偏少。补这一类训练，更能帮助你处理“眼前舒服把人拉走”的问题。',
      actionLabel: '去做 90 秒延迟诱惑',
      kind: 'task',
      refTitle: '90 秒延迟诱惑',
      priorityLabel: '中优先级',
      horizonLabel: '中期',
      unitIds: ['P-017', 'X-001'],
      priorityScore: 70,
    ));
  }
  if (weakestTaskType == '注意锁定型') {
    addSuggestion(const SmartSuggestion(
      key: 'weak_attention_hold',
      title: '最近更该补“注意锁定型”训练',
      subtitle: '从你最近的执行分布看，注意锁定类训练偏少。补这一类训练，会更直接地增强“把困难观念留在心里”的能力。',
      actionLabel: '去做 30 秒注意锁定',
      kind: 'task',
      refTitle: '30 秒注意锁定',
      priorityLabel: '中优先级',
      horizonLabel: '中期',
      unitIds: ['E-005', 'R-003'],
      priorityScore: 72,
    ));
  }

  final avgEffort = data.executions.isEmpty
      ? 0.0
      : data.executions.map((e) => e.effortLevel).reduce((a, b) => a + b) / data.executions.length;
  if (data.summary.executionCount >= 4 && avgEffort < 3) {
    addSuggestion(const SmartSuggestion(
      key: 'raise_effort_once',
      title: '最近 effort 偏低，建议试一次更高 effort 训练',
      subtitle: '你已经有了多次执行记录。下一步可以尝试一次稍高 effort 的训练，不求多，只求一次真实突破。',
      actionLabel: '去做 30 秒注意锁定',
      kind: 'task',
      refTitle: '30 秒注意锁定',
      priorityLabel: '中优先级',
      horizonLabel: '中期',
      unitIds: ['E-003', 'T-005'],
      priorityScore: 66,
    ));
  }
  if (data.summary.executionCount >= 4 && data.summary.zoneVisitCount > 0 && data.summary.reviewCount > 0) {
    addSuggestion(const SmartSuggestion(
      key: 'deepen_problem_path',
      title: '把一条问题路径继续练深',
      subtitle: '你已经有了计划、执行、复盘和镜像城访问。接下来更适合固定一条最常出现的问题路径，连续练深 3 到 5 次。',
      actionLabel: '查看训练总览',
      kind: 'dashboard',
      refTitle: 'dashboard',
      priorityLabel: '中优先级',
      horizonLabel: '中期',
      unitIds: ['A-001', 'W-001'],
      priorityScore: 60,
    ));
  }

  final seen = <String>{};
  final deduped = <SmartSuggestion>[];
  for (final s in suggestions) {
    final fingerprint = '${s.key}|${s.refTitle}|${s.zoneTitle}';
    if (seen.add(fingerprint)) deduped.add(s);
  }
  deduped.sort((a, b) {
    if (b.priorityScore != a.priorityScore) return b.priorityScore.compareTo(a.priorityScore);
    final sa = stateMap[a.key]?.actionCount ?? 0;
    final sb = stateMap[b.key]?.actionCount ?? 0;
    return sa.compareTo(sb);
  });
  if (deduped.isEmpty) {
    deduped.add(const SmartSuggestion(
      key: 'keep_momentum',
      title: '继续保持当前节奏',
      subtitle: '你的训练链路已经跑起来了。此刻最重要的是保持连续训练，并把一条问题路径练深，而不是频繁换方向。',
      actionLabel: '查看训练总览',
      kind: 'dashboard',
      refTitle: 'dashboard',
      priorityLabel: '中优先级',
      horizonLabel: '中期',
      unitIds: ['W-001', 'R-008'],
      priorityScore: 40,
    ));
  }
  return deduped.take(4).toList();
}
