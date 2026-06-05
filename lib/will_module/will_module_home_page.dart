import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'will_dao.dart';
import 'will_models.dart';
import 'will_seed.dart';
import 'will_unit_index_seed.dart';
import 'will_deep_content_seed.dart';
import 'will_route_link_seed.dart';
import 'will_route_resolver.dart';
import 'will_original_simplified_pages.dart';
import 'will_original_precise_segments.dart';


String _trainingTypeForTaskTitle(String title) {
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

List<WillNamedCount> _problemHitsFromExecutions(List<WillTaskExecutionEntry> executions) {
  final counts = <String, int>{};
  for (final execution in executions) {
    final task = WillRouteResolver.taskByTitle(execution.taskTitle);
    if (task == null) continue;
    for (final problem in WillRouteResolver.recommendedProblemsForTask(task)) {
      counts[problem.title] = (counts[problem.title] ?? 0) + 1;
    }
  }
  final list = counts.entries
      .map((e) => WillNamedCount(label: e.key, count: e.value))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  return list;
}

List<WillNamedCount> _taskTypeCountsFromExecutions(List<WillTaskExecutionEntry> executions) {
  final counts = <String, int>{
    '启动型': 0,
    '注意锁定型': 0,
    '抗诱惑型': 0,
    '复盘型': 0,
  };
  for (final execution in executions) {
    final label = _trainingTypeForTaskTitle(execution.taskTitle);
    counts[label] = (counts[label] ?? 0) + 1;
  }
  final list = counts.entries
      .map((e) => WillNamedCount(label: e.key, count: e.value))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  return list;
}

List<WillNamedCount> _weakestTaskTypesFromExecutions(List<WillTaskExecutionEntry> executions) {
  final list = _taskTypeCountsFromExecutions(executions)
    ..sort((a, b) => a.count.compareTo(b.count));
  return list;
}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _weekdayZh(int weekday) {
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  return labels[(weekday - 1).clamp(0, 6)];
}

class _DayActivitySummary {
  final DateTime day;
  final int total;
  final int executionCount;
  final int reviewCount;
  final int zoneCount;
  final double avgEffort;

  const _DayActivitySummary({
    required this.day,
    required this.total,
    required this.executionCount,
    required this.reviewCount,
    required this.zoneCount,
    required this.avgEffort,
  });
}

List<_DayActivitySummary> _lastNDayActivity({
  required List<WillTaskExecutionEntry> executions,
  required List<WillReviewEntry> reviews,
  required List<WillZoneVisitEntry> zones,
  int days = 7,
}) {
  final now = DateTime.now();
  final today = _dayOnly(now);
  final map = <String, Map<String, double>>{};

  void touch(DateTime day, {int execution = 0, int review = 0, int zone = 0, int effort = 0}) {
    final key = _dayOnly(day).toIso8601String();
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

  final out = <_DayActivitySummary>[];
  for (int i = days - 1; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    final item = map[day.toIso8601String()] ?? const {'e': 0, 'r': 0, 'z': 0, 'eff': 0, 'effc': 0};
    final e = (item['e'] ?? 0).toInt();
    final r = (item['r'] ?? 0).toInt();
    final z = (item['z'] ?? 0).toInt();
    final effc = (item['effc'] ?? 0).toInt();
    final eff = (item['eff'] ?? 0);
    out.add(_DayActivitySummary(
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

int _currentTrainingStreak({
  required List<WillTaskExecutionEntry> executions,
  required List<WillReviewEntry> reviews,
  required List<WillZoneVisitEntry> zones,
}) {
  final activeDays = <String>{};
  for (final e in executions) {
    activeDays.add(_dayOnly(DateTime.fromMillisecondsSinceEpoch(e.completedAtMs)).toIso8601String());
  }
  for (final r in reviews) {
    activeDays.add(_dayOnly(DateTime.fromMillisecondsSinceEpoch(r.updatedAtMs)).toIso8601String());
  }
  for (final z in zones) {
    activeDays.add(_dayOnly(DateTime.fromMillisecondsSinceEpoch(z.visitedAtMs)).toIso8601String());
  }
  int streak = 0;
  var cursor = _dayOnly(DateTime.now());
  while (activeDays.contains(cursor.toIso8601String())) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

List<WillNamedCount> _effortDistribution(List<WillTaskExecutionEntry> executions) {
  final counts = <String, int>{
    'Lv1': 0,
    'Lv2': 0,
    'Lv3': 0,
    'Lv4': 0,
    'Lv5': 0,
  };
  for (final e in executions) {
    final key = 'Lv${e.effortLevel.clamp(1,5)}';
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts.entries.map((e) => WillNamedCount(label: e.key, count: e.value)).toList();
}

class WillModuleHomePage extends StatelessWidget {
  const WillModuleHomePage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => page));
  }




  @override
  Widget build(BuildContext context) {
    final featured = kWillKnowledgeCards.take(3).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('意志实验室')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _HeroCard(
            title: '把“知道”变成“做到”',
            subtitle: '基于《心理学原理》第 26 章《意志》的独立模块：用知识库、问题诊断、微任务、复盘闭环与镜像城场景，帮助用户在真实生活里训练意志。',
            chips: ['209 个知识单元', '首批 30 张核心卡', '任务闭环', '镜像城', '知行合一'],
          ),
          const SizedBox(height: 14),
          _StatsCard(onOpenDashboard: () => _open(context, const WillDashboardPage())),
          const SizedBox(height: 14),
          const _SectionTitle('核心入口'),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.dashboard_outlined,
            title: '意志训练总览',
            subtitle: '查看计划、执行、复盘与任务链路，看到自己正在形成的训练历史。',
            onTap: () => _open(context, const WillDashboardPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.account_tree_outlined,
            title: '知识总览',
            subtitle: '查看章节结构、首批 30 张知识卡，并按问题回溯到概念。',
            onTap: () => _open(context, const WillKnowledgeMapPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.route_outlined,
            title: '课程学习路线',
            subtitle: '按“导论 83 段 → 观念—运动作用 19 段 → 其余模块”的顺序进入课程式学习。',
            onTap: () => _open(context, const WillStudyRoadmapPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.format_list_bulleted_outlined,
            title: '209 单元总表',
            subtitle: '按导论 / 观念—运动 / 审议 / 努力 / 爆发 / 阻塞 / 教育完整浏览本章知识索引。',
            onTap: () => _open(context, const WillUnitIndexPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.article_outlined,
            title: '原文简化版全文',
            subtitle: '按你前面发来的版本原样整合，完整浏览第26章〈意志〉简化版正文。',
            onTap: () => _open(context, WillOriginalSimplifiedReaderPage(onOpenUnit: (unit) => _open(context, WillUnitIndexDetailPage(unit: unit)))),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.psychology_alt_outlined,
            title: '问题诊断',
            subtitle: '从拖延、冲动、犹豫、无力等问题出发，定位对应机制与任务。',
            onTap: () => _open(context, const WillProblemDiagnosisPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.task_alt_outlined,
            title: '现实任务中心',
            subtitle: '围绕“启动、延迟、锁定、复盘”执行最小行动，并形成 if-then 计划。',
            onTap: () => _open(context, const WillTaskHubPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.history_edu_outlined,
            title: '复盘中心',
            subtitle: '记录主导观念、对抗观念、努力点与明日计划，建立知行闭环。',
            onTap: () => _open(context, const WillReviewCenterPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.landscape_outlined,
            title: '镜像城',
            subtitle: '起意场 / 努力坡 / 诱惑市集 / 阻塞谷，把现实难题先在虚拟世界里练一遍。',
            onTap: () => _open(context, const WillWorldPage()),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('首批核心知识卡'),
          const SizedBox(height: 10),
          ...featured.map((card) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _KnowledgeCardTile(
                  card: card,
                  onTap: () => _open(context, WillCardDetailPage(cardId: card.id)),
                ),
              )),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _open(context, const WillCardLibraryPage()),
            icon: const Icon(Icons.library_books_outlined),
            label: const Text('查看首批 30 张知识卡'),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('落地方式'),
          const SizedBox(height: 10),
          const _InfoCard(
            lines: [
              '本模块作为独立入口接入现有 App 左侧菜单，不影响原有首页、发现之旅、日记与其他主题模块。',
              'MVP 阶段先落地知识总览、问题诊断、任务中心、复盘中心与镜像城四大场景。',
              '后续可继续扩展为完整 209 段知识卡数据库、个性化推荐、进度追踪与 AI 教练。',
            ],
          ),
        ],
      ),
    );
  }
}

class WillDashboardPage extends StatefulWidget {
  const WillDashboardPage({super.key});

  @override
  State<WillDashboardPage> createState() => _WillDashboardPageState();
}

class _WillDashboardPageState extends State<WillDashboardPage> {
  final WillDao dao = WillDao();
  late Future<_DashboardBundle> _future;
  String? _shownStageTransitionToken;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardBundle> _load() async {
    final summary = await dao.getDashboardSummary();
    final chains = await dao.getTaskChainSummaries(limit: 20);
    final allReviews = await dao.getRecentReviews(limit: 200);
    final allExecutions = await dao.getRecentTaskExecutions(limit: 200);
    final allZoneVisits = await dao.getRecentZoneVisits(limit: 120);
    final zoneCounts = await dao.getZoneVisitCounts(limit: 8);
    final problemHits = _problemHitsFromExecutions(allExecutions);
    final taskTypeCounts = _taskTypeCountsFromExecutions(allExecutions);
    final weakestTaskTypes = _weakestTaskTypesFromExecutions(allExecutions);
    final streak = _currentTrainingStreak(
      executions: allExecutions,
      reviews: allReviews,
      zones: allZoneVisits,
    );
    final dailyActivity = _lastNDayActivity(
      executions: allExecutions,
      reviews: allReviews,
      zones: allZoneVisits,
      days: 7,
    );
    final effortDistribution = _effortDistribution(allExecutions);
    final tempBundle = _DashboardBundle(
      summary: summary,
      chains: chains,
      reviews: allReviews.take(6).toList(),
      executions: allExecutions.take(20).toList(),
      zoneCounts: zoneCounts,
      recentZoneVisits: allZoneVisits.take(6).toList(),
      problemHits: problemHits,
      taskTypeCounts: taskTypeCounts,
      weakestTaskTypes: weakestTaskTypes,
      streakDays: streak,
      dailyActivity: dailyActivity,
      effortDistribution: effortDistribution,
      suggestionStates: const [],
      milestones: const [],
      stageRuntimeState: null,
    );
    final stageStatuses = _evaluateStageStatuses(tempBundle);
    for (final status in stageStatuses.where((s) => s.achieved)) {
      await dao.ensureStageMilestone(stageKey: status.key, stageLabel: status.label, detail: status.detail);
    }
    final suggestionStates = await dao.getSuggestionStates();
    final milestones = await dao.getStageMilestones(limit: 12);
    var bundle = _DashboardBundle(
      summary: summary,
      chains: chains,
      reviews: allReviews.take(6).toList(),
      executions: allExecutions.take(20).toList(),
      zoneCounts: zoneCounts,
      recentZoneVisits: allZoneVisits.take(6).toList(),
      problemHits: problemHits,
      taskTypeCounts: taskTypeCounts,
      weakestTaskTypes: weakestTaskTypes,
      streakDays: streak,
      dailyActivity: dailyActivity,
      effortDistribution: effortDistribution,
      suggestionStates: suggestionStates,
      milestones: milestones,
      stageRuntimeState: null,
    );
    final coachStage = _buildCoachStage(bundle);
    final stageRuntimeState = await dao.syncCurrentStage(currentStageKey: coachStage.key);
    bundle = _DashboardBundle(
      summary: summary,
      chains: chains,
      reviews: allReviews.take(6).toList(),
      executions: allExecutions.take(20).toList(),
      zoneCounts: zoneCounts,
      recentZoneVisits: allZoneVisits.take(6).toList(),
      problemHits: problemHits,
      taskTypeCounts: taskTypeCounts,
      weakestTaskTypes: weakestTaskTypes,
      streakDays: streak,
      dailyActivity: dailyActivity,
      effortDistribution: effortDistribution,
      suggestionStates: suggestionStates,
      milestones: milestones,
      stageRuntimeState: stageRuntimeState,
    );
    return bundle;
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openSuggestion(_SmartSuggestion s) async {
    await dao.markSuggestionOpened(s.key);
    if (!mounted) return;
    if (s.kind == 'task') {
      final task = WillRouteResolver.taskByTitle(s.refTitle);
      if (task != null) {
        await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillTaskDetailPage(task: task)));
      }
    } else if (s.kind == 'zone') {
      final matches = kWillWorldZones.where((z) => z.title == s.refTitle).toList();
      if (matches.isNotEmpty) {
        await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillWorldZoneDetailPage(zone: matches.first)));
      }
    } else if (s.kind == 'problem') {
      final matches = kWillProblemPaths.where((p) => p.title == s.refTitle).toList();
      if (matches.isNotEmpty) {
        await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillProblemDetailPage(problem: matches.first)));
      }
    } else if (s.kind == 'review') {
      final latestExecution = await dao.getLatestTaskExecutionForTask(s.refTitle);
      await Navigator.of(context).push(CupertinoPageRoute(
        builder: (_) => WillReviewCenterPage(
          initialTaskTitle: s.refTitle,
          initialExecution: latestExecution,
        ),
      ));
    }
    await _reload();
  }

  Future<void> _completeSuggestion(_SmartSuggestion s) async {
    await dao.markSuggestionCompleted(s.key);
    await _reload();
  }

  Future<void> _openCoachStage(_CoachStage stage) async {
    if (stage.kind == 'task') {
      final task = WillRouteResolver.taskByTitle(stage.refTitle);
      if (task != null) {
        await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillTaskDetailPage(task: task)));
      }
    } else if (stage.kind == 'zone') {
      final matches = kWillWorldZones.where((z) => z.title == stage.refTitle).toList();
      if (matches.isNotEmpty) {
        await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillWorldZoneDetailPage(zone: matches.first)));
      }
    } else if (stage.kind == 'review') {
      final latestExecution = await dao.getLatestTaskExecutionForTask(stage.refTitle);
      await Navigator.of(context).push(CupertinoPageRoute(
        builder: (_) => WillReviewCenterPage(
          initialTaskTitle: stage.refTitle,
          initialExecution: latestExecution,
        ),
      ));
    }
    await _reload();
  }

  String _fmt(int ms) {
    if (ms <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  void _maybeCelebrateStageChange(_DashboardBundle data, _CoachStage coachStage) {
    final state = data.stageRuntimeState;
    if (!_isRecentStageChange(state)) return;
    if (state == null) return;
    if (state.notifiedAtMs >= state.changedAtMs) return;
    final token = '${state.previousStageKey}->${state.currentStageKey}@${state.changedAtMs}';
    if (_shownStageTransitionToken == token) return;
    _shownStageTransitionToken = token;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1F2937),
          content: Text('阶段升级：你已进入“${coachStage.stageLabel}”。接下来先完成这一步：${coachStage.actionLabel}'),
          action: SnackBarAction(
            label: '去完成',
            textColor: const Color(0xFF93C5FD),
            onPressed: () {
              _openCoachStage(coachStage);
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      await dao.markStageChangeNotified();
      if (mounted) {
        await _reload();
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('意志训练总览')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<_DashboardBundle>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final coachStage = _buildCoachStage(data);
          _maybeCelebrateStageChange(data, coachStage);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('训练历史概览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _MiniStat(label: '已保存计划', value: '${data.summary.planCount}')),
                        const SizedBox(width: 10),
                        Expanded(child: _MiniStat(label: '累计执行', value: '${data.summary.executionCount}')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _MiniStat(label: '复盘记录', value: '${data.summary.reviewCount}')),
                        const SizedBox(width: 10),
                        Expanded(child: _MiniStat(label: '任务链路', value: '${data.summary.taskCount}')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _MiniStat(label: '镜像城访问', value: '${data.summary.zoneVisitCount}')),
                        const SizedBox(width: 10),
                        Expanded(child: _MiniStat(label: '训练类型', value: '${data.taskTypeCounts.where((e) => e.count > 0).length}/4')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _SectionTitle('当前训练阶段'),
              const SizedBox(height: 8),
              _CoachStageCard(
                stage: coachStage,
                onTap: () => _openCoachStage(coachStage),
              ),
              if (_isRecentStageChange(data.stageRuntimeState)) ...[
                const SizedBox(height: 10),
                _StageTransitionCard(
                  previousLabel: _stageLabelFromKey(data.stageRuntimeState!.previousStageKey),
                  currentLabel: _stageLabelFromKey(data.stageRuntimeState!.currentStageKey),
                  changedAtLabel: _fmt(data.stageRuntimeState!.changedAtMs),
                  nextActionLabel: coachStage.actionLabel,
                  onTakeNextStep: () => _openCoachStage(coachStage),
                ),
              ],
              const SizedBox(height: 14),
              const _SectionTitle('阶段徽章与里程碑'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('已解锁阶段徽章', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (data.milestones.isEmpty)
                      const Text('还没有完成阶段徽章。先完成当前阶段的 3 条条件，这里会点亮第一枚徽章。', style: TextStyle(color: Color(0xFF6B7280), height: 1.5))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: data.milestones.map((m) => _StageBadgeChip(milestone: m)).toList(),
                      ),
                    const SizedBox(height: 14),
                    const Text('阶段历史时间线', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (data.milestones.isEmpty)
                      const Text('当一个阶段的 3 条条件全部满足后，这里会记录它被点亮的时间。', style: TextStyle(color: Color(0xFF6B7280), height: 1.5))
                    else ...[
                      ...data.milestones.reversed.take(6).map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _StageTimelineItem(
                              milestone: m,
                              timeLabel: _fmt(m.achievedAtMs),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _SectionTitle('训练节奏'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _MiniStat(label: '连续训练', value: '${data.streakDays} 天')),
                        const SizedBox(width: 10),
                        Expanded(child: _MiniStat(label: '近7天活跃日', value: '${data.dailyActivity.where((e) => e.total > 0).length}/7')),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('最近 7 天训练热力', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final day in data.dailyActivity)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: _HeatDayCell(day: day),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('每日 effort 分布', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (data.effortDistribution.every((e) => e.count == 0))
                      const Text('还没有执行记录，记录几次任务执行后，这里会显示你的 effort 分布。', style: TextStyle(color: Color(0xFF6B7280), height: 1.5))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: data.effortDistribution.map((e) => _TagChip('${e.label} ×${e.count}')).toList(),
                      ),
                    const SizedBox(height: 14),
                    const Text('最近 7 天训练节奏', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ...data.dailyActivity.map((day) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DayTrendRow(day: day),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _SectionTitle('训练偏向'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('最近最常命中的问题路径', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (data.problemHits.isEmpty)
                      const Text('暂无足够执行记录，先完成几次现实任务再看训练偏向。', style: TextStyle(color: Color(0xFF6B7280), height: 1.5))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: data.problemHits.take(4).map((e) => _TagChip('${e.label} ×${e.count}')).toList(),
                      ),
                    const SizedBox(height: 14),
                    const Text('最近最常进入的镜像城区域', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (data.zoneCounts.isEmpty)
                      const Text('还没有镜像城访问记录。进入任一区域后，这里会开始显示你的偏好。', style: TextStyle(color: Color(0xFF6B7280), height: 1.5))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: data.zoneCounts.take(4).map((e) => _TagChip('${e.label} ×${e.count}')).toList(),
                      ),
                    const SizedBox(height: 14),
                    const Text('当前较少训练的动作类型', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: data.weakestTaskTypes.take(4).map((e) => _TagChip('${e.label} ×${e.count}')).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _SectionTitle('智能建议'),
              const SizedBox(height: 8),
              ..._buildSmartSuggestions(data).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SmartSuggestionCard(
                      suggestion: s,
                      onTap: () => _openSuggestion(s),
                      onComplete: () => _completeSuggestion(s),
                    ),
                  )),
              const SizedBox(height: 14),
              const _SectionTitle('按任务查看链路'),
              const SizedBox(height: 8),
              if (data.chains.isEmpty)
                const _InfoCard(lines: ['还没有链路数据。先在“现实任务中心”里保存一条 if-then 计划，并记录一次执行或复盘。'])
              else
                ...data.chains.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 6))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.taskTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _TagChip('计划 ${item.planCount}'),
                                _TagChip('执行 ${item.executionCount}'),
                                _TagChip('复盘 ${item.reviewCount}'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('最近执行：${_fmt(item.latestExecutionAtMs)}', style: const TextStyle(color: Color(0xFF6B7280))),
                            const SizedBox(height: 4),
                            Text('最近复盘：${_fmt(item.latestReviewAtMs)}', style: const TextStyle(color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                    )),
              const SizedBox(height: 14),
              const _SectionTitle('最近执行'),
              const SizedBox(height: 8),
              if (data.executions.isEmpty)
                const _InfoCard(lines: ['还没有执行记录。去“现实任务中心”完成一次微行动即可在这里看到历史。'])
              else
                ...data.executions.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SimpleRowCard(
                        title: e.taskTitle,
                        subtitle: '努力等级 ${e.effortLevel}｜${_fmt(e.completedAtMs)}\n${e.note.isEmpty ? '无备注' : e.note}',
                      ),
                    )),
              const SizedBox(height: 14),
              const _SectionTitle('最近进入的镜像城区域'),
              const SizedBox(height: 8),
              if (data.recentZoneVisits.isEmpty)
                const _InfoCard(lines: ['还没有镜像城访问记录。进入任一镜像城场景后，这里会显示你的最近访问历史。'])
              else
                ...data.recentZoneVisits.map((z) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SimpleRowCard(
                        title: z.zoneTitle,
                        subtitle: _fmt(z.visitedAtMs),
                      ),
                    )),
              const SizedBox(height: 14),
              const _SectionTitle('最近复盘'),
              const SizedBox(height: 8),
              if (data.reviews.isEmpty)
                const _InfoCard(lines: ['还没有复盘记录。一次复盘就能让模块开始生成真正的“知—行—思”历史。'])
              else
                ...data.reviews.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SimpleRowCard(
                        title: r.taskTitle.isEmpty ? '未绑定任务的复盘' : r.taskTitle,
                        subtitle: '${_fmt(r.updatedAtMs)}\n主导观念：${r.dominantIdea.isEmpty ? '（未填写）' : r.dominantIdea}\n动作：${r.actionTaken.isEmpty ? '（未填写）' : r.actionTaken}',
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardBundle {
  final WillDashboardSummary summary;
  final List<WillTaskChainSummary> chains;
  final List<WillReviewEntry> reviews;
  final List<WillTaskExecutionEntry> executions;
  final List<WillNamedCount> zoneCounts;
  final List<WillZoneVisitEntry> recentZoneVisits;
  final List<WillNamedCount> problemHits;
  final List<WillNamedCount> taskTypeCounts;
  final List<WillNamedCount> weakestTaskTypes;
  final int streakDays;
  final List<_DayActivitySummary> dailyActivity;
  final List<WillNamedCount> effortDistribution;
  final List<WillSuggestionState> suggestionStates;
  final List<WillStageMilestoneEntry> milestones;
  final WillStageRuntimeState? stageRuntimeState;

  _DashboardBundle({
    required this.summary,
    required this.chains,
    required this.reviews,
    required this.executions,
    required this.zoneCounts,
    required this.recentZoneVisits,
    required this.problemHits,
    required this.taskTypeCounts,
    required this.weakestTaskTypes,
    required this.streakDays,
    required this.dailyActivity,
    required this.effortDistribution,
    required this.suggestionStates,
    required this.milestones,
    required this.stageRuntimeState,
  });
}

class _SmartSuggestion {
  final String key;
  final String title;
  final String subtitle;
  final String actionLabel;
  final String kind; // task / zone / problem / dashboard / review
  final String refTitle;
  final String priorityLabel;
  final String horizonLabel;
  final List<String> unitIds;
  final int priorityScore;

  const _SmartSuggestion({
    required this.key,
    required this.title,
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


class _StageStatus {
  final String key;
  final String label;
  final bool achieved;
  final String detail;

  const _StageStatus({
    required this.key,
    required this.label,
    required this.achieved,
    required this.detail,
  });
}

class _StageCheckpoint {
  final String label;
  final bool done;

  const _StageCheckpoint({
    required this.label,
    required this.done,
  });
}

class _CoachStage {
  final String key;
  final String stageLabel;
  final String title;
  final String subtitle;
  final List<String> focusPoints;
  final String actionLabel;
  final String kind;
  final String refTitle;
  final List<String> unitIds;
  final List<_StageCheckpoint> checkpoints;
  final bool completed;
  final String progressLabel;
  final String nextStageLabel;
  final String nextStageHint;

  const _CoachStage({
    required this.key,
    required this.stageLabel,
    required this.title,
    required this.subtitle,
    required this.focusPoints,
    required this.actionLabel,
    required this.kind,
    required this.refTitle,
    required this.unitIds,
    required this.checkpoints,
    required this.completed,
    required this.progressLabel,
    required this.nextStageLabel,
    required this.nextStageHint,
  });
}

String _topProblemLabel(List<WillNamedCount> problemHits) {
  if (problemHits.isEmpty) return '';
  return problemHits.first.label;
}

double _avgEffortFromExecutions(List<WillTaskExecutionEntry> executions) {
  if (executions.isEmpty) return 0;
  final sum = executions.fold<int>(0, (acc, e) => acc + e.effortLevel);
  return sum / executions.length;
}

String _progressSummary(List<_StageCheckpoint> checkpoints) {
  final done = checkpoints.where((e) => e.done).length;
  return '${done}/${checkpoints.length} 条已完成';
}

double _progressValue(List<_StageCheckpoint> checkpoints) {
  if (checkpoints.isEmpty) return 0;
  final done = checkpoints.where((e) => e.done).length;
  return done / checkpoints.length;
}


WillTaskExecutionEntry? _latestExecution(List<WillTaskExecutionEntry> executions) {
  if (executions.isEmpty) return null;
  final copy = [...executions]..sort((a, b) => b.completedAtMs.compareTo(a.completedAtMs));
  return copy.first;
}

WillReviewEntry? _latestReview(List<WillReviewEntry> reviews) {
  if (reviews.isEmpty) return null;
  final copy = [...reviews]..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
  return copy.first;
}

WillZoneVisitEntry? _latestZoneVisit(List<WillZoneVisitEntry> visits) {
  if (visits.isEmpty) return null;
  final copy = [...visits]..sort((a, b) => b.visitedAtMs.compareTo(a.visitedAtMs));
  return copy.first;
}

List<String> _defaultUnitIdsForTask(String taskTitle) {
  switch (taskTitle) {
    case '10 秒起步':
      return ['I-006', 'O-001'];
    case '30 秒注意锁定':
      return ['E-005', 'R-003'];
    case '90 秒延迟诱惑':
      return ['P-017', 'X-001'];
    case '晚间意志复盘':
      return ['R-014', 'F-011'];
    default:
      return ['W-001'];
  }
}

WillWorldZone? _primaryZoneForTaskTitle(String taskTitle) {
  final task = WillRouteResolver.taskByTitle(taskTitle);
  if (task == null) return null;
  final zones = WillRouteResolver.recommendedZonesForTask(task);
  return zones.isEmpty ? null : zones.first;
}

List<String> _defaultUnitIdsForZone(String zoneTitle) {
  switch (zoneTitle) {
    case '起意场':
      return ['D-003', 'I-003'];
    case '努力坡':
      return ['E-005', 'R-003'];
    case '诱惑市集':
      return ['P-017', 'X-001'];
    case '阻塞谷':
      return ['O-001', 'W-002'];
    default:
      return ['W-001'];
  }
}



List<_StageStatus> _evaluateStageStatuses(_DashboardBundle data) {
  final hasPlan = data.summary.planCount > 0;
  final hasExecution = data.summary.executionCount > 0;
  final hasReview = data.summary.reviewCount > 0;
  final hasZone = data.summary.zoneVisitCount > 0;
  final activeDays = data.dailyActivity.where((e) => e.total > 0).length;
  final avgEffort = data.executions.isEmpty
      ? 0.0
      : data.executions.map((e) => e.effortLevel).reduce((a, b) => a + b) / data.executions.length;

  return [
    _StageStatus(
      key: 'stage_start',
      label: '起步期',
      achieved: hasPlan && hasExecution && hasReview,
      detail: '完成第一条计划、第一次执行与第一次复盘。',
    ),
    _StageStatus(
      key: 'stage_recovery',
      label: '恢复节奏期',
      achieved: data.dailyActivity.isNotEmpty && data.dailyActivity.last.total > 0 && activeDays >= 2 && (hasExecution || hasReview),
      detail: '重新接上训练节奏，并在 7 天内至少活跃 2 天。',
    ),
    _StageStatus(
      key: 'stage_loop',
      label: '建立闭环期',
      achieved: hasExecution && hasReview && hasZone,
      detail: '让执行、复盘、镜像城三者真正接起来。',
    ),
    _StageStatus(
      key: 'stage_steady',
      label: '稳定训练期',
      achieved: data.streakDays >= 3 && activeDays >= 4 && avgEffort >= 3,
      detail: '保持连续训练并把平均 effort 提到 3.0 以上。',
    ),
  ];
}

Color _stageColor(String key) {
  switch (key) {
    case 'stage_start':
    case 'stage_bootstrap':
      return const Color(0xFF2563EB);
    case 'stage_recovery':
      return const Color(0xFFEA580C);
    case 'stage_loop':
    case 'stage_build_execution':
    case 'stage_build_review':
    case 'stage_build_zone':
      return const Color(0xFF7C3AED);
    case 'stage_steady':
    case 'stage_stable':
      return const Color(0xFF059669);
    default:
      return const Color(0xFF2563EB);
  }
}

IconData _stageIcon(String key) {
  switch (key) {
    case 'stage_start':
    case 'stage_bootstrap':
      return Icons.play_circle_outline;
    case 'stage_recovery':
      return Icons.autorenew_rounded;
    case 'stage_loop':
    case 'stage_build_execution':
    case 'stage_build_review':
    case 'stage_build_zone':
      return Icons.all_inclusive_rounded;
    case 'stage_steady':
    case 'stage_stable':
      return Icons.workspace_premium_outlined;
    default:
      return Icons.flag_outlined;
  }
}


String _stageLabelFromKey(String key) {
  switch (key) {
    case 'stage_start':
    case 'stage_bootstrap':
      return '起步期';
    case 'stage_recovery':
      return '恢复节奏期';
    case 'stage_loop':
    case 'stage_build_execution':
    case 'stage_build_review':
    case 'stage_build_zone':
      return '建立闭环期';
    case 'stage_steady':
    case 'stage_stable':
      return '稳定训练期';
    default:
      return '训练阶段';
  }
}

bool _isRecentStageChange(WillStageRuntimeState? state) {
  if (state == null) return false;
  if (state.previousStageKey.isEmpty) return false;
  final now = DateTime.now().millisecondsSinceEpoch;
  return now - state.changedAtMs <= const Duration(hours: 72).inMilliseconds;
}

_CoachStage _buildCoachStage(_DashboardBundle data) {
  final latestExecution = _latestExecution(data.executions);
  final activeDays = data.dailyActivity.where((e) => e.total > 0).length;
  final avgEffort = _avgEffortFromExecutions(data.executions);
  final hasPlan = data.summary.planCount > 0;
  final hasExecution = data.summary.executionCount > 0;
  final hasReview = data.summary.reviewCount > 0;
  final hasZone = data.summary.zoneVisitCount > 0;

  if (!hasPlan && !hasExecution && !hasReview) {
    final checkpoints = <_StageCheckpoint>[
      _StageCheckpoint(label: '已保存第一条 if-then 计划', done: hasPlan),
      _StageCheckpoint(label: '已完成第一次现实执行', done: hasExecution),
      _StageCheckpoint(label: '已写下第一次复盘', done: hasReview),
    ];
    return _CoachStage(
      key: 'stage_bootstrap',
      stageLabel: '起步期',
      title: '先把第一条训练链点亮',
      subtitle: '你现在最需要的不是学更多，而是建立第一条最小闭环：一条计划、一次执行、一次复盘。',
      focusPoints: const ['先写一条 if-then', '做一次极小现实动作', '当天晚上写一条复盘'],
      actionLabel: '去做 10 秒起步',
      kind: 'task',
      refTitle: '10 秒起步',
      unitIds: const ['W-002', 'I-006'],
      checkpoints: checkpoints,
      completed: checkpoints.every((e) => e.done),
      progressLabel: _progressSummary(checkpoints),
      nextStageLabel: '建立闭环期',
      nextStageHint: '当你完成“计划 + 执行 + 复盘”后，下一阶段会开始把执行、复盘和镜像城真正接成一条训练链。',
    );
  }

  final needsRecovery = data.streakDays == 0 && (hasExecution || hasReview || hasZone);
  if (needsRecovery) {
    final checkpoints = <_StageCheckpoint>[
      _StageCheckpoint(label: '今天重新接上一条训练行为', done: data.dailyActivity.isNotEmpty && data.dailyActivity.last.total > 0),
      _StageCheckpoint(label: '近 7 天至少活跃 2 天', done: activeDays >= 2),
      _StageCheckpoint(label: '补一条低阻力任务或复盘', done: hasExecution || hasReview),
    ];
    return _CoachStage(
      key: 'stage_recovery',
      stageLabel: '恢复节奏期',
      title: '先把训练节奏重新接上',
      subtitle: '你不是从零开始，而是链路暂时断了。现在最重要的是用一个低阻力动作把训练重新接上。',
      focusPoints: const ['优先恢复连续训练天数', '先做轻量任务，不追求高难度', '恢复后再回到完整闭环'],
      actionLabel: '恢复一次启动训练',
      kind: 'task',
      refTitle: '10 秒起步',
      unitIds: const ['D-083', 'I-009'],
      checkpoints: checkpoints,
      completed: checkpoints.every((e) => e.done),
      progressLabel: _progressSummary(checkpoints),
      nextStageLabel: '建立闭环期',
      nextStageHint: '当节奏重新接上后，下一阶段重点是把执行、复盘、镜像城三者真正连成一条训练链。',
    );
  }

  final buildingLoop = !hasExecution || !hasReview || !hasZone;
  if (buildingLoop) {
    final checkpoints = <_StageCheckpoint>[
      _StageCheckpoint(label: '至少有 1 次执行记录', done: hasExecution),
      _StageCheckpoint(label: '至少有 1 条复盘记录', done: hasReview),
      _StageCheckpoint(label: '至少进入过 1 次镜像城', done: hasZone),
    ];
    final missingReview = hasExecution && !hasReview;
    final missingZone = hasReview && !hasZone;
    if (missingReview) {
      return _CoachStage(
        key: 'stage_build_review',
        stageLabel: '建立闭环期',
        title: '把“执行”接到“复盘”上',
        subtitle: '你已经开始行动，但闭环还没形成。现在最该做的是把最近一次执行转成复盘记录。',
        focusPoints: const ['记录哪一个观念赢了', '写下 effort 出现在哪一刻', '给下一次补一个更早介入点'],
        actionLabel: '去补第一次复盘',
        kind: 'review',
        refTitle: latestExecution?.taskTitle ?? '晚间意志复盘',
        unitIds: const ['R-003', 'F-011'],
        checkpoints: checkpoints,
        completed: checkpoints.every((e) => e.done),
        progressLabel: _progressSummary(checkpoints),
        nextStageLabel: '稳定训练期',
        nextStageHint: '当执行、复盘、镜像城三者都接上后，下一阶段会转向保持节奏、提高 effort，并固定一条问题路径练深。',
      );
    }
    if (missingZone) {
      return _CoachStage(
        key: 'stage_build_zone',
        stageLabel: '建立闭环期',
        title: '把复盘接到镜像城预演上',
        subtitle: '你已经有了行动和复盘，下一步最适合去虚拟世界预演一次关键难点。',
        focusPoints: const ['先在镜像城里走一遍难点', '把复盘里提到的失败点提前模拟', '再把预演带回现实动作'],
        actionLabel: '进入起意场',
        kind: 'zone',
        refTitle: '起意场',
        unitIds: const ['W-024', 'I-015'],
        checkpoints: checkpoints,
        completed: checkpoints.every((e) => e.done),
        progressLabel: _progressSummary(checkpoints),
        nextStageLabel: '稳定训练期',
        nextStageHint: '当镜像城也加入训练链后，你会从“补环节”进入“稳节奏、提质量”的训练期。',
      );
    }
    return _CoachStage(
      key: 'stage_build_execution',
      stageLabel: '建立闭环期',
      title: '把“计划”真正落成第一次执行',
      subtitle: '你已经有了一些准备，现在不要继续停在理解层。先让一个最小动作真实发生。',
      focusPoints: const ['优先做 1 次最小现实动作', '执行完成立刻转复盘', '不要同时追求太多任务'],
      actionLabel: '去做第一次执行',
      kind: 'task',
      refTitle: '10 秒起步',
      unitIds: const ['I-006', 'O-001'],
      checkpoints: checkpoints,
      completed: checkpoints.every((e) => e.done),
      progressLabel: _progressSummary(checkpoints),
      nextStageLabel: '稳定训练期',
      nextStageHint: '当你把执行、复盘和镜像城都接起来后，下一阶段会更强调连续性和高质量训练。',
    );
  }

  final checkpoints = <_StageCheckpoint>[
    _StageCheckpoint(label: '连续训练至少 3 天', done: data.streakDays >= 3),
    _StageCheckpoint(label: '近 7 天至少活跃 4 天', done: activeDays >= 4),
    _StageCheckpoint(label: '最近平均 effort 达到 3.0', done: avgEffort >= 3),
  ];
  return _CoachStage(
    key: 'stage_stable',
    stageLabel: '稳定训练期',
    title: '现在该把一条问题路径练深',
    subtitle: '你已经具备计划、执行、复盘和镜像城预演。下一步不是广撒网，而是固定一条问题路径持续练深。',
    focusPoints: const ['锁定一条最常出现的问题路径', '保持连续训练天数', '提高一次更高 effort 的训练质量'],
    actionLabel: data.weakestTaskTypes.first.label == '抗诱惑型' ? '去做 90 秒延迟诱惑' : '去做 30 秒注意锁定',
    kind: 'task',
    refTitle: data.weakestTaskTypes.first.label == '抗诱惑型' ? '90 秒延迟诱惑' : '30 秒注意锁定',
    unitIds: data.weakestTaskTypes.first.label == '抗诱惑型' ? const ['P-017', 'X-001'] : const ['E-005', 'R-003'],
    checkpoints: checkpoints,
    completed: checkpoints.every((e) => e.done),
    progressLabel: _progressSummary(checkpoints),
    nextStageLabel: '深化训练期（预告）',
    nextStageHint: '下一阶段会更强调固定一条问题路径反复练、提高高 effort 训练质量，并把知识单元和现实任务绑定得更紧。',
  );
}

List<_SmartSuggestion> _buildSmartSuggestions(_DashboardBundle data) {
  final suggestions = <_SmartSuggestion>[];
  final activeDays = data.dailyActivity.where((e) => e.total > 0).length;
  final avgEffort = _avgEffortFromExecutions(data.executions);
  final weakest = data.weakestTaskTypes.isNotEmpty ? data.weakestTaskTypes.first.label : '';
  final topProblem = _topProblemLabel(data.problemHits);
  final stateMap = {for (final s in data.suggestionStates) s.suggestionKey: s};
  final now = DateTime.now().millisecondsSinceEpoch;
  final latestExecution = _latestExecution(data.executions);
  final latestReview = _latestReview(data.reviews);
  final latestZone = _latestZoneVisit(data.recentZoneVisits);
  const hideWindowMs = 1000 * 60 * 60 * 36;

  bool hiddenByCompletion(String key) {
    final s = stateMap[key];
    if (s == null || s.completedAtMs <= 0) return false;
    return now - s.completedAtMs < hideWindowMs;
  }

  void addSuggestion(_SmartSuggestion suggestion) {
    if (hiddenByCompletion(suggestion.key)) return;
    suggestions.add(suggestion);
  }

  if (data.summary.planCount == 0) {
    addSuggestion(const _SmartSuggestion(
      key: 'first_plan',
      title: '先建立第一条 if-then 计划',
      subtitle: '你还没有保存任何计划。先把一个现实情境绑定到一个最小动作上，模块才会开始形成真正的训练链路。',
      actionLabel: '去做 10 秒起步',
      kind: 'task',
      refTitle: '10 秒起步',
      priorityLabel: '高优先级',
      horizonLabel: '短期',
      unitIds: ['W-002', 'I-015'],
      priorityScore: 100,
    ));
  }

  if (data.summary.planCount > 0 && data.summary.executionCount == 0) {
    addSuggestion(const _SmartSuggestion(
      key: 'plan_to_execution',
      title: '你已经建好计划，下一步是第一次执行',
      subtitle: '现在最重要的不是再写更多计划，而是让第一条计划真正落地成一次执行记录。先完成一个最小动作。',
      actionLabel: '去做第一次执行',
      kind: 'task',
      refTitle: '10 秒起步',
      priorityLabel: '高优先级',
      horizonLabel: '短期',
      unitIds: ['I-006', 'W-002'],
      priorityScore: 98,
    ));
  }

  if (data.summary.executionCount == 0) {
    addSuggestion(const _SmartSuggestion(
      key: 'first_execution',
      title: '先完成第一次现实执行',
      subtitle: '现在最重要的不是继续看内容，而是做出第一次执行记录。完成一次极小动作，训练历史才会真正开始。',
      actionLabel: '进入现实任务',
      kind: 'task',
      refTitle: '10 秒起步',
      priorityLabel: '高优先级',
      horizonLabel: '短期',
      unitIds: ['I-006', 'O-001'],
      priorityScore: 96,
    ));
  }

  if (latestExecution != null && (latestReview == null || latestReview.updatedAtMs < latestExecution.completedAtMs)) {
    addSuggestion(_SmartSuggestion(
      key: 'execution_to_review_${latestExecution.id ?? latestExecution.completedAtMs}',
      title: '你刚完成了一次执行，下一步先立刻复盘',
      subtitle: '趁这次执行还在记忆里，把当时哪个观念赢了、你在哪一刻付出了努力、下次怎么更早介入写下来。',
      actionLabel: '带着这次执行去复盘',
      kind: 'review',
      refTitle: latestExecution.taskTitle,
      priorityLabel: '高优先级',
      horizonLabel: '短期',
      unitIds: _defaultUnitIdsForTask('晚间意志复盘'),
      priorityScore: 97,
    ));
  }

  if (data.summary.executionCount > 0 && data.summary.reviewCount == 0) {
    addSuggestion(const _SmartSuggestion(
      key: 'first_review',
      title: '补上第一次复盘',
      subtitle: '你已经开始训练了，但还没有形成“执行后反思”的闭环。先写一条晚间复盘，把观念、动作和努力点连起来。',
      actionLabel: '去写复盘',
      kind: 'task',
      refTitle: '晚间意志复盘',
      priorityLabel: '高优先级',
      horizonLabel: '短期',
      unitIds: ['R-003', 'F-011'],
      priorityScore: 94,
    ));
  }

  if (latestReview != null) {
    final needsZone = latestZone == null || latestZone.visitedAtMs < latestReview.updatedAtMs;
    final suggestedTaskTitle = latestReview.taskTitle.isNotEmpty ? latestReview.taskTitle : '10 秒起步';
    final zone = _primaryZoneForTaskTitle(suggestedTaskTitle);
    if (needsZone && zone != null) {
      addSuggestion(_SmartSuggestion(
        key: 'review_to_zone_${latestReview.id ?? latestReview.updatedAtMs}',
        title: '复盘之后，去镜像城先预演下一次难点',
        subtitle: '你已经写下了这次训练的问题点。现在最适合去 ${zone.title} 做一次虚拟预演，把下次的关键节点提前走一遍。',
        actionLabel: '进入${zone.title}',
        kind: 'zone',
        refTitle: zone.title,
        priorityLabel: '高优先级',
        horizonLabel: '短期',
        unitIds: _defaultUnitIdsForZone(zone.title),
        priorityScore: 90,
      ));
    }
  }

  if (latestZone != null && latestExecution != null && latestZone.visitedAtMs > latestExecution.completedAtMs) {
    final task = WillRouteResolver.recommendedTasksForZone(kWillWorldZones.firstWhere((z) => z.title == latestZone.zoneTitle, orElse: () => kWillWorldZones.first));
    final firstTask = task.isNotEmpty ? task.first : WillRouteResolver.taskByTitle('10 秒起步');
    if (firstTask != null) {
      addSuggestion(_SmartSuggestion(
        key: 'zone_to_execution_${latestZone.id ?? latestZone.visitedAtMs}',
        title: '把刚才的虚拟预演带回现实做一次',
        subtitle: '你已经进入了 ${latestZone.zoneTitle}。现在最适合立刻做一次现实版动作，让预演真正变成现实训练。',
        actionLabel: '去做现实动作',
        kind: 'task',
        refTitle: firstTask.title,
        priorityLabel: '高优先级',
        horizonLabel: '短期',
        unitIds: _defaultUnitIdsForTask(firstTask.title),
        priorityScore: 89,
      ));
    }
  }

  if (data.streakDays == 0 && (data.summary.executionCount > 0 || data.summary.reviewCount > 0 || data.summary.zoneVisitCount > 0)) {
    addSuggestion(const _SmartSuggestion(
      key: 'restore_streak',
      title: '先恢复训练节奏',
      subtitle: '你的连续训练已经中断。此刻最优先的不是高难度任务，而是恢复连续性。用一个极小动作重新点亮训练链路。',
      actionLabel: '恢复一次启动训练',
      kind: 'task',
      refTitle: '10 秒起步',
      priorityLabel: '高优先级',
      horizonLabel: '短期',
      unitIds: ['D-083', 'I-009'],
      priorityScore: 92,
    ));
  }
  if (activeDays > 0 && activeDays < 3) {
    addSuggestion(const _SmartSuggestion(
      key: 'low_density',
      title: '最近训练偏稀，建议补一个轻量动作',
      subtitle: '近 7 天活跃天数偏少。先用低阻力任务补密度，比追求高强度更适合恢复节奏。',
      actionLabel: '去做轻量启动',
      kind: 'task',
      refTitle: '10 秒起步',
      priorityLabel: '中优先级',
      horizonLabel: '短期',
      unitIds: ['D-020', 'I-003'],
      priorityScore: 72,
    ));
  }
  if (data.summary.executionCount > 0 && data.summary.reviewCount < (data.summary.executionCount / 2).floor()) {
    addSuggestion(const _SmartSuggestion(
      key: 'review_gap',
      title: '执行后复盘偏少，建议补一条晚间复盘',
      subtitle: '你已经开始行动，但执行后的整理还不够。补一条复盘会帮助你把努力点和失败模式固定下来。',
      actionLabel: '去写晚间意志复盘',
      kind: 'task',
      refTitle: '晚间意志复盘',
      priorityLabel: '中优先级',
      horizonLabel: '短期',
      unitIds: ['R-014', 'W-001'],
      priorityScore: 74,
    ));
  }
  if (weakest == '抗诱惑型' || topProblem == '总被眼前舒服拉走') {
    addSuggestion(const _SmartSuggestion(
      key: 'anti_temptation',
      title: '最近更该补“抗诱惑型”训练',
      subtitle: '你的训练里“抗诱惑型”偏少，或者最近更常被即时舒服拉走。先做一次延迟诱惑，再进诱惑市集预演。',
      actionLabel: '去做 90 秒延迟诱惑',
      kind: 'task',
      refTitle: '90 秒延迟诱惑',
      priorityLabel: '中优先级',
      horizonLabel: '中期',
      unitIds: ['P-017', 'X-001'],
      priorityScore: 70,
    ));
  }
  if (weakest == '注意锁定型' || topProblem == '明知该做却做不到') {
    addSuggestion(const _SmartSuggestion(
      key: 'attention_lock',
      title: '最近更该补“注意锁定型”训练',
      subtitle: '你最近更像是“知道该做，但注意站不住”。先做一次 30 秒注意锁定，再去努力坡或观念神殿练保持。',
      actionLabel: '去做 30 秒注意锁定',
      kind: 'task',
      refTitle: '30 秒注意锁定',
      priorityLabel: '中优先级',
      horizonLabel: '短期',
      unitIds: ['E-005', 'R-003'],
      priorityScore: 76,
    ));
  }
  if (data.summary.zoneVisitCount == 0) {
    addSuggestion(const _SmartSuggestion(
      key: 'first_zone',
      title: '还没进入过镜像城，建议先从起意场开始',
      subtitle: '镜像城能把现实中的启动、诱惑、阻塞先在虚拟场景里演练一遍。第一次建议从起意场开始。',
      actionLabel: '进入起意场',
      kind: 'zone',
      refTitle: '起意场',
      priorityLabel: '中优先级',
      horizonLabel: '短期',
      unitIds: ['D-003', 'W-024'],
      priorityScore: 68,
    ));
  }
  if (data.summary.executionCount >= 3 && avgEffort > 0 && avgEffort < 2.6) {
    addSuggestion(const _SmartSuggestion(
      key: 'raise_effort',
      title: '最近 effort 偏低，建议试一次更高 effort 训练',
      subtitle: '你的训练密度已经有了，但最近执行多停留在较低 effort。适合尝试一次更需要注意保持的任务。',
      actionLabel: '提高一次训练强度',
      kind: 'task',
      refTitle: '30 秒注意锁定',
      priorityLabel: '中优先级',
      horizonLabel: '中期',
      unitIds: ['E-003', 'T-005'],
      priorityScore: 66,
    ));
  }
  if (data.summary.executionCount >= 4 && data.summary.zoneVisitCount > 0 && data.summary.reviewCount > 0) {
    addSuggestion(const _SmartSuggestion(
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
  final deduped = <_SmartSuggestion>[];
  for (final s in suggestions) {
    final fingerprint = '${s.key}|${s.refTitle}|${s.title}';
    if (seen.add(fingerprint)) deduped.add(s);
  }
  deduped.sort((a, b) {
    if (b.priorityScore != a.priorityScore) return b.priorityScore.compareTo(a.priorityScore);
    final sa = stateMap[a.key]?.actionCount ?? 0;
    final sb = stateMap[b.key]?.actionCount ?? 0;
    return sa.compareTo(sb);
  });
  if (deduped.isEmpty) {
    deduped.add(const _SmartSuggestion(
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

class WillKnowledgeMapPage extends StatelessWidget {
  const WillKnowledgeMapPage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('知识总览')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _InfoCard(
            lines: [
              '这一页把“章节结构”和“首批知识卡”合并呈现，便于在已有 App 中快速集成。',
              '后续可把每个条目继续展开成完整知识卡：定义、案例、实践、复盘、关联概念。',
            ],
          ),
          const SizedBox(height: 12),
          ...kWillSections.map((section) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _KnowledgeSectionCard(
                  section: section,
                  onTap: () => _open(context, WillSectionDetailPage(sectionId: section.id)),
                ),
              )),
          const SizedBox(height: 8),
          _EntryCard(
            icon: Icons.menu_book_outlined,
            title: '导论 83 段标准库',
            subtitle: '集中浏览“欲望—动作观念—神经支配感批判—动作线索”的完整导论学习链。',
            onTap: () => _open(context, const WillModuleUnitLibraryPage(moduleCode: 'D')),
          ),
          const SizedBox(height: 8),
          _EntryCard(
            icon: Icons.bolt_outlined,
            title: '观念—运动作用 19 段标准库',
            subtitle: '集中浏览“想到就做、冲突观念、fiat 与阻滞解除”的完整学习链。',
            onTap: () => _open(context, const WillModuleUnitLibraryPage(moduleCode: 'I')),
          ),
          const SizedBox(height: 8),
          _EntryCard(
            icon: Icons.format_list_bulleted_outlined,
            title: '209 单元总表',
            subtitle: '先浏览全章索引，再进入首批 30 张核心卡。',
            onTap: () => _open(context, const WillUnitIndexPage()),
          ),
          const SizedBox(height: 8),
          _EntryCard(
            icon: Icons.article_outlined,
            title: '原文简化版全文',
            subtitle: '把你提供的第26章〈意志〉中文简化版正文按原样整合进 app 内容层。',
            onTap: () => _open(context, WillOriginalSimplifiedReaderPage(onOpenUnit: (unit) => _open(context, WillUnitIndexDetailPage(unit: unit)))),
          ),
          const SizedBox(height: 8),
          _EntryCard(
            icon: Icons.style_outlined,
            title: '首批 30 张知识卡',
            subtitle: '优先覆盖拖延、冲动、阻塞、努力、诱惑与意志教育。',
            onTap: () => _open(context, const WillCardLibraryPage()),
          ),
        ],
      ),
    );
  }
}

class WillSectionDetailPage extends StatelessWidget {
  final String sectionId;
  const WillSectionDetailPage({super.key, required this.sectionId});

  @override
  Widget build(BuildContext context) {
    final section = kWillSections.firstWhere((e) => e.id == sectionId);
    final cards = kWillKnowledgeCards.where((e) => e.sectionId == sectionId).toList();
    return Scaffold(
      appBar: AppBar(title: Text(section.title)),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(section.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                    _Badge('${section.unitCount} 单元'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(section.subtitle, style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: section.highlights.map((e) => _TagChip(e)).toList()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _SectionTitle('首批知识卡'),
          const SizedBox(height: 8),
          ...cards.map((card) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _KnowledgeCardTile(
                  card: card,
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillCardDetailPage(cardId: card.id))),
                ),
              )),
          if (cards.isEmpty)
            const _InfoCard(lines: ['当前章节还未拆成首批卡片，后续可继续补齐为完整 209 张知识卡。']),
        ],
      ),
    );
  }
}

class WillCardLibraryPage extends StatefulWidget {
  const WillCardLibraryPage({super.key});

  @override
  State<WillCardLibraryPage> createState() => _WillCardLibraryPageState();
}

class _WillCardLibraryPageState extends State<WillCardLibraryPage> {
  String _selected = 'all';

  @override
  Widget build(BuildContext context) {
    final sections = ['all', ...kWillSections.map((e) => e.id)];
    final cards = _selected == 'all'
        ? kWillKnowledgeCards
        : kWillKnowledgeCards.where((e) => e.sectionId == _selected).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('首批 30 张知识卡')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: sections.map((id) {
                final label = id == 'all' ? '全部' : kWillSections.firstWhere((e) => e.id == id).title;
                final active = id == _selected;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: active,
                    onSelected: (_) => setState(() => _selected = id),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _KnowledgeCardTile(
                    card: card,
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillCardDetailPage(cardId: card.id))),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class WillCardDetailPage extends StatelessWidget {
  final String cardId;
  const WillCardDetailPage({super.key, required this.cardId});

  @override
  Widget build(BuildContext context) {
    final card = kWillKnowledgeCards.firstWhere((e) => e.id == cardId);
    final related = kWillKnowledgeCards
        .where((e) => e.id != card.id && e.sectionId == card.sectionId)
        .take(3)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(card.label)),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(card.oneLiner, style: const TextStyle(fontSize: 15, color: Color(0xFF374151), height: 1.5)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: card.tags.map((e) => _TagChip(e)).toList()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DetailBlock(title: '概念内涵', body: card.meaning),
          const SizedBox(height: 10),
          _DetailBlock(title: '现实对应场景', body: card.realScene),
          const SizedBox(height: 10),
          _DetailBlock(title: '最小实践动作', body: card.practicalAction),
          const SizedBox(height: 10),
          _DetailBlock(title: '复盘问题', body: card.reflection),
          const SizedBox(height: 12),
          if (related.isNotEmpty) ...[
            const _SectionTitle('同章节相关卡'),
            const SizedBox(height: 8),
            ...related.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _KnowledgeCardTile(
                    card: e,
                    onTap: () => Navigator.of(context).pushReplacement(CupertinoPageRoute(builder: (_) => WillCardDetailPage(cardId: e.id))),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class WillProblemDiagnosisPage extends StatelessWidget {
  const WillProblemDiagnosisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('问题诊断')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _InfoCard(
            lines: [
              '诊断入口优先围绕现实问题，而不是理论术语。',
              '用户先认出“我现在卡在哪”，再进入对应概念、任务与镜像城区域。',
            ],
          ),
          const SizedBox(height: 12),
          ...kWillProblemPaths.map((problem) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProblemPathCard(
                  problem: problem,
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => WillProblemDetailPage(problem: problem)),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class WillProblemDetailPage extends StatelessWidget {
  final WillProblemPath problem;
  const WillProblemDetailPage({super.key, required this.problem});

  @override
  Widget build(BuildContext context) {
    final cards = problem.linkedCardIds
        .map((id) => kWillKnowledgeCards.firstWhere((e) => e.id == id))
        .toList();
    final tasks = WillRouteResolver.recommendedTasksForProblem(problem);
    final zones = WillRouteResolver.recommendedZonesForProblem(problem);
    final problems = <WillProblemPath>[];
    return Scaffold(
      appBar: AppBar(title: Text(problem.title)),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(lines: [problem.summary]),
          const SizedBox(height: 12),
          const _SectionTitle('建议动作'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Column(
              children: problem.actions.map((e) => _BulletLine(e)).toList(),
            ),
          ),
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionTitle('配套任务'),
            const SizedBox(height: 8),
            ...tasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActionLinkCard(
                    title: task.title,
                    subtitle: task.action,
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillTaskDetailPage(task: task))),
                  ),
                )),
          ],
          if (zones.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionTitle('配套镜像城'),
            const SizedBox(height: 8),
            ...zones.map((zone) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActionLinkCard(
                    title: zone.title,
                    subtitle: zone.missionTitle,
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillWorldZoneDetailPage(zone: zone))),
                  ),
                )),
          ],
          if (problems.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionTitle('这个场景常对应的问题'),
            const SizedBox(height: 8),
            ...problems.map((problem) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActionLinkCard(
                    title: problem.title,
                    subtitle: problem.summary,
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillProblemDetailPage(problem: problem))),
                  ),
                )),
          ],
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionTitle('建议先做的现实任务'),
            const SizedBox(height: 8),
            ...tasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActionLinkCard(
                    title: task.title,
                    subtitle: task.action,
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillTaskDetailPage(task: task))),
                  ),
                )),
          ],
          const SizedBox(height: 12),
          const _SectionTitle('关联知识卡'),
          const SizedBox(height: 8),
          ...cards.map((card) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _KnowledgeCardTile(
                  card: card,
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillCardDetailPage(cardId: card.id))),
                ),
              )),
        ],
      ),
    );
  }
}

class WillTaskHubPage extends StatelessWidget {
  const WillTaskHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('现实任务中心')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _InfoCard(
            lines: [
              '所有任务都遵循：触发情境 → 最小动作 → 证据/反馈 → 复盘 → 下一次 if-then。',
              'MVP 先提供 4 组高频任务模板，覆盖拖延启动、注意锁定、冲动延迟与晚间复盘。',
            ],
          ),
          const SizedBox(height: 12),
          ...kWillTaskPlans.map((task) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TaskPlanCard(
                  task: task,
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => WillTaskDetailPage(task: task)),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class WillTaskDetailPage extends StatefulWidget {
  final WillTaskPlan task;
  const WillTaskDetailPage({super.key, required this.task});

  @override
  State<WillTaskDetailPage> createState() => _WillTaskDetailPageState();
}

class _WillTaskDetailPageState extends State<WillTaskDetailPage> {
  final _dao = WillDao();
  late final TextEditingController _ifCtrl;
  late final TextEditingController _thenCtrl;
  late final TextEditingController _executionNoteCtrl;
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isLoggingExecution = false;
  int? _savedAtMs;
  int _effortLevel = 3;
  int _executionCount = 0;
  List<WillTaskExecutionEntry> _executions = const [];
  List<WillReviewEntry> _taskReviews = const [];

  @override
  void initState() {
    super.initState();
    _ifCtrl = TextEditingController(text: widget.task.sampleIf)..addListener(_refresh);
    _thenCtrl = TextEditingController(text: widget.task.sampleThen)..addListener(_refresh);
    _executionNoteCtrl = TextEditingController()..addListener(_refresh);
    _loadTaskData();
  }

  Future<void> _loadTaskData() async {
    try {
      final saved = await _dao.getPlanByTaskTitle(widget.task.title);
      final executions = await _dao.getRecentTaskExecutionsByTaskTitle(widget.task.title);
      final count = await _dao.getTaskExecutionCount(widget.task.title);
      final reviews = await _dao.getRecentReviewsByTaskTitle(widget.task.title);
      if (!mounted) return;
      if (saved != null) {
        _ifCtrl.text = saved.ifText.isEmpty ? widget.task.sampleIf : saved.ifText;
        _thenCtrl.text = saved.thenText.isEmpty ? widget.task.sampleThen : saved.thenText;
        _savedAtMs = saved.updatedAtMs;
      }
      setState(() {
        _executions = executions;
        _executionCount = count;
        _taskReviews = reviews;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePlan() async {
    setState(() => _isSaving = true);
    try {
      await _dao.savePlan(
        taskTitle: widget.task.title,
        ifText: _ifCtrl.text.trim(),
        thenText: _thenCtrl.text.trim(),
      );
      _savedAtMs = DateTime.now().millisecondsSinceEpoch;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('计划已保存到本地')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveExecution() async {
    setState(() => _isLoggingExecution = true);
    try {
      await _dao.saveTaskExecution(
        taskTitle: widget.task.title,
        note: _executionNoteCtrl.text.trim(),
        effortLevel: _effortLevel,
      );
      _executionNoteCtrl.clear();
      final executions = await _dao.getRecentTaskExecutionsByTaskTitle(widget.task.title);
      final count = await _dao.getTaskExecutionCount(widget.task.title);
      final reviews = await _dao.getRecentReviewsByTaskTitle(widget.task.title);
      if (!mounted) return;
      setState(() {
        _executions = executions;
        _executionCount = count;
        _taskReviews = reviews;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已记录这次执行')));
    } finally {
      if (mounted) setState(() => _isLoggingExecution = false);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ifCtrl.removeListener(_refresh);
    _thenCtrl.removeListener(_refresh);
    _executionNoteCtrl.removeListener(_refresh);
    _ifCtrl.dispose();
    _thenCtrl.dispose();
    _executionNoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.task.linkedCardIds
        .map((id) => kWillKnowledgeCards.firstWhere((e) => e.id == id))
        .toList();
    final problems = WillRouteResolver.recommendedProblemsForTask(widget.task);
    final zones = WillRouteResolver.recommendedZonesForTask(widget.task);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task.title),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _savePlan,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: const Text('保存'),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TaskPlanCard(task: widget.task),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('if-then 计划器', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                          if (_savedAtMs != null)
                            Text('最近保存：${_formatMs(_savedAtMs!)}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _ifCtrl,
                        decoration: const InputDecoration(labelText: '如果（触发情境）', border: OutlineInputBorder()),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _thenCtrl,
                        decoration: const InputDecoration(labelText: '那么（最小动作）', border: OutlineInputBorder()),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('我的计划：如果 ${_ifCtrl.text.trim().isEmpty ? '____' : _ifCtrl.text.trim()}，那么 ${_thenCtrl.text.trim().isEmpty ? '____' : _thenCtrl.text.trim()}。'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _savePlan,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('保存这条计划'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('执行记录', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                          _Badge('累计 ${_executionCount} 次'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('每完成一次现实动作，就在这里留下一条执行记录；记录后可以直接带入复盘，形成“计划 → 执行 → 复盘”的链路。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _executionNoteCtrl,
                        decoration: const InputDecoration(
                          labelText: '这次执行备注（可选）',
                          hintText: '例如：我在晚上 10:20 把手机放到门外，先写了 5 分钟。',
                          border: OutlineInputBorder(),
                        ),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      const Text('主观努力等级', style: TextStyle(fontWeight: FontWeight.w700)),
                      Slider(
                        value: _effortLevel.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: '$_effortLevel',
                        onChanged: (v) => setState(() => _effortLevel = v.round()),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('$_effortLevel / 5', style: const TextStyle(color: Color(0xFF6B7280))),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _isLoggingExecution ? null : _saveExecution,
                        icon: _isLoggingExecution
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline),
                        label: const Text('记录这次执行'),
                      ),
                      if (_executions.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text('最近执行', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ..._executions.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(_formatMs(entry.completedAtMs), style: const TextStyle(fontWeight: FontWeight.w700)),
                                        ),
                                        _Badge('努力 ${entry.effortLevel}/5'),
                                      ],
                                    ),
                                    if (entry.note.trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(entry.note, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
                                    ],
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () => Navigator.of(context).push(
                                          CupertinoPageRoute(
                                            builder: (_) => WillReviewCenterPage(
                                              initialTaskTitle: widget.task.title,
                                              initialExecution: entry,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(Icons.rate_review_outlined),
                                        label: const Text('带入复盘'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
                if (_taskReviews.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('该任务的最近复盘', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        ..._taskReviews.take(4).map((review) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(_formatMs(review.updatedAtMs), style: const TextStyle(fontWeight: FontWeight.w700))),
                                        if (review.sourceExecutionId != null) const _Badge('已关联执行'),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('主导观念：${review.dominantIdea.isEmpty ? '—' : review.dominantIdea}', style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
                                    const SizedBox(height: 4),
                                    Text('下一步：${review.nextStep.isEmpty ? '—' : review.nextStep}', style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
                                  ],
                                ),
                              ),
                            )),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (_) => WillReviewCenterPage(initialTaskTitle: widget.task.title),
                              ),
                            ),
                            icon: const Icon(Icons.open_in_new_outlined),
                            label: const Text('查看完整复盘链路'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (problems.isNotEmpty) ...[
                  const _SectionTitle('这个任务通常在解决'),
                  const SizedBox(height: 8),
                  ...problems.map((problem) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ActionLinkCard(
                          title: problem.title,
                          subtitle: problem.summary,
                          onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillProblemDetailPage(problem: problem))),
                        ),
                      )),
                  const SizedBox(height: 12),
                ],
                if (zones.isNotEmpty) ...[
                  const _SectionTitle('推荐镜像城场景'),
                  const SizedBox(height: 8),
                  ...zones.map((zone) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ActionLinkCard(
                          title: zone.title,
                          subtitle: zone.missionTitle,
                          onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillWorldZoneDetailPage(zone: zone))),
                        ),
                      )),
                  const SizedBox(height: 12),
                ],
                const _SectionTitle('关联知识卡'),
                const SizedBox(height: 8),
                ...cards.map((card) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _KnowledgeCardTile(
                        card: card,
                        onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillCardDetailPage(cardId: card.id))),
                      ),
                    )),
              ],
            ),
    );
  }
}

class WillReviewCenterPage extends StatefulWidget {
  final String? initialTaskTitle;
  final WillTaskExecutionEntry? initialExecution;

  const WillReviewCenterPage({super.key, this.initialTaskTitle, this.initialExecution});

  @override
  State<WillReviewCenterPage> createState() => _WillReviewCenterPageState();
}

class _WillReviewCenterPageState extends State<WillReviewCenterPage> {
  final _dao = WillDao();
  final _dominantCtrl = TextEditingController();
  final _opposingCtrl = TextEditingController();
  final _effortCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();
  final _nextCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  List<WillReviewEntry> _recent = const [];
  List<WillReviewEntry> _taskReviews = const [];
  List<WillTaskExecutionEntry> _taskExecutions = const [];
  String? _selectedTaskTitle;
  WillTaskExecutionEntry? _linkedExecution;

  @override
  void initState() {
    super.initState();
    _selectedTaskTitle = widget.initialTaskTitle ?? widget.initialExecution?.taskTitle;
    _linkedExecution = widget.initialExecution;
    for (final c in [_dominantCtrl, _opposingCtrl, _effortCtrl, _actionCtrl, _nextCtrl]) {
      c.addListener(_refresh);
    }
    if (_linkedExecution != null) {
      _applyExecution(_linkedExecution!);
    }
    _loadReviewData();
  }

  Future<void> _loadReviewData() async {
    try {
      final latest = await _dao.getLatestReview();
      final recent = await _dao.getRecentReviews();
      final selected = _selectedTaskTitle;
      final taskReviews = selected == null || selected.isEmpty ? const <WillReviewEntry>[] : await _dao.getRecentReviewsByTaskTitle(selected);
      final taskExecutions = selected == null || selected.isEmpty ? const <WillTaskExecutionEntry>[] : await _dao.getRecentTaskExecutionsByTaskTitle(selected);
      if (!mounted) return;
      if (_linkedExecution == null && latest != null) {
        _applyReview(latest);
        _selectedTaskTitle = latest.taskTitle.isEmpty ? _selectedTaskTitle : latest.taskTitle;
      }
      setState(() {
        _recent = recent;
        _taskReviews = taskReviews;
        _taskExecutions = taskExecutions;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyExecution(WillTaskExecutionEntry execution) {
    _linkedExecution = execution;
    _selectedTaskTitle = execution.taskTitle;
    if (_actionCtrl.text.trim().isEmpty) {
      _actionCtrl.text = execution.note.trim().isEmpty ? '完成任务：${execution.taskTitle}' : execution.note.trim();
    }
    _effortCtrl.text = '执行时主观努力：${execution.effortLevel}/5';
  }

  void _applyReview(WillReviewEntry review) {
    _dominantCtrl.text = review.dominantIdea;
    _opposingCtrl.text = review.opposingIdea;
    _effortCtrl.text = review.effortPoint;
    _actionCtrl.text = review.actionTaken;
    _nextCtrl.text = review.nextStep;
    if (review.taskTitle.isNotEmpty) {
      _selectedTaskTitle = review.taskTitle;
    }
  }

  Future<void> _saveReview() async {
    setState(() => _isSaving = true);
    try {
      await _dao.saveReview(
        dominantIdea: _dominantCtrl.text.trim(),
        opposingIdea: _opposingCtrl.text.trim(),
        effortPoint: _effortCtrl.text.trim(),
        actionTaken: _actionCtrl.text.trim(),
        nextStep: _nextCtrl.text.trim(),
        taskTitle: _selectedTaskTitle ?? '',
        sourceExecutionId: _linkedExecution?.id,
      );
      await _loadReviewData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('复盘已保存到本地')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_dominantCtrl, _opposingCtrl, _effortCtrl, _actionCtrl, _nextCtrl]) {
      c.removeListener(_refresh);
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('复盘中心'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveReview,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: const Text('保存'),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _InfoCard(
                  lines: [
                    '复盘不是再讲道理，而是把“哪个观念赢了、为什么赢、下次怎么更早介入”说清楚。',
                    '这一版已打通任务执行记录：你可以从执行直接进入复盘，并按任务查看历史链路。',
                  ],
                ),
                if (_selectedTaskTitle != null && _selectedTaskTitle!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(child: Text('当前链路任务', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                            _Badge(_selectedTaskTitle!),
                          ],
                        ),
                        if (_linkedExecution != null) ...[
                          const SizedBox(height: 10),
                          Text('来源执行：${_formatMs(_linkedExecution!.completedAtMs)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('努力等级：${_linkedExecution!.effortLevel}/5', style: const TextStyle(color: Color(0xFF6B7280))),
                          if (_linkedExecution!.note.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(_linkedExecution!.note, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _ReviewField(label: '今天最强的主导观念', controller: _dominantCtrl),
                const SizedBox(height: 10),
                _ReviewField(label: '今天最强的对抗观念', controller: _opposingCtrl),
                const SizedBox(height: 10),
                _ReviewField(label: '你今天在哪一刻付出了努力', controller: _effortCtrl),
                const SizedBox(height: 10),
                _ReviewField(label: '你今天做出的最小但关键的动作', controller: _actionCtrl),
                const SizedBox(height: 10),
                _ReviewField(label: '明天若再遇到同一情境，你准备怎样更早介入', controller: _nextCtrl),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('复盘摘要', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text('今天主导我的，是：${_safe(_dominantCtrl.text)}'),
                      const SizedBox(height: 6),
                      Text('与它对抗的，是：${_safe(_opposingCtrl.text)}'),
                      const SizedBox(height: 6),
                      Text('我真正付出努力的点，在：${_safe(_effortCtrl.text)}'),
                      const SizedBox(height: 6),
                      Text('今天最小但关键的动作，是：${_safe(_actionCtrl.text)}'),
                      const SizedBox(height: 6),
                      Text('明天的更早介入点：${_safe(_nextCtrl.text)}'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveReview,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('保存这次复盘'),
                      ),
                    ],
                  ),
                ),
                if (_taskExecutions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('该任务的最近执行', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        ..._taskExecutions.take(5).map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  _applyExecution(entry);
                                  setState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text(_formatMs(entry.completedAtMs), style: const TextStyle(fontWeight: FontWeight.w700))),
                                          _Badge('努力 ${entry.effortLevel}/5'),
                                        ],
                                      ),
                                      if (entry.note.trim().isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(entry.note, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
                                      ],
                                      const SizedBox(height: 6),
                                      const Text('点击可带入当前复盘', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                    ],
                                  ),
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
                if (_taskReviews.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _SectionTitle('该任务的复盘历史'),
                  const SizedBox(height: 8),
                  ..._taskReviews.map((review) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            _applyReview(review);
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 6))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        review.dominantIdea.isEmpty ? '未命名复盘' : review.dominantIdea,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    if (review.sourceExecutionId != null) const _Badge('关联执行'),
                                    const SizedBox(width: 8),
                                    Text(_formatMs(review.updatedAtMs), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '动作：${review.actionTaken.isEmpty ? '—' : review.actionTaken}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFF4B5563), height: 1.4),
                                ),
                                const SizedBox(height: 6),
                                const Text('点击可载入到上方表单继续修改', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                              ],
                            ),
                          ),
                        ),
                      )),
                ],
                if (_recent.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _SectionTitle('全局最近保存'),
                  const SizedBox(height: 8),
                  ..._recent.take(6).map((review) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            _applyReview(review);
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 6))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.history_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        review.dominantIdea.isEmpty ? '未命名复盘' : review.dominantIdea,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    Text(_formatMs(review.updatedAtMs), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                  ],
                                ),
                                if (review.taskTitle.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  _Badge(review.taskTitle),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )),
                ],
              ],
            ),
    );
  }

  String _safe(String text) => text.trim().isEmpty ? '____' : text.trim();
}

class WillWorldPage extends StatelessWidget {
  const WillWorldPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('镜像城')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _InfoCard(
            lines: [
              '镜像城不是脱离现实的游戏，而是现实问题的预演场。',
              '每个区域都对应一种意志机制，并要求回到现实做一个同构动作。',
            ],
          ),
          const SizedBox(height: 12),
          ...kWillWorldZones.map((zone) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WorldZoneCard(
                  zone: zone,
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => WillWorldZoneDetailPage(zone: zone)),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class WillWorldZoneDetailPage extends StatefulWidget {
  final WillWorldZone zone;
  const WillWorldZoneDetailPage({super.key, required this.zone});

  @override
  State<WillWorldZoneDetailPage> createState() => _WillWorldZoneDetailPageState();
}

class _WillWorldZoneDetailPageState extends State<WillWorldZoneDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await WillDao().saveZoneVisit(widget.zone.title);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final zone = widget.zone;
    final cards = zone.linkedCardIds
        .map((id) => kWillKnowledgeCards.firstWhere((e) => e.id == id))
        .toList();
    final problems = WillRouteResolver.recommendedProblemsForZone(zone);
    final tasks = WillRouteResolver.recommendedTasksForZone(zone);
    return Scaffold(
      appBar: AppBar(title: Text(zone.title)),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zone.missionTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(zone.subtitle, style: const TextStyle(color: Color(0xFF4B5563), height: 1.5)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: zone.skills.map((e) => _TagChip(e)).toList()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DetailBlock(title: '现实映射', body: zone.realWorldMapping),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('任务步骤', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ...List.generate(zone.missionSteps.length, (index) {
                  final step = zone.missionSteps[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(step, style: const TextStyle(height: 1.45))),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          if (problems.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionTitle('这个场景常对应的问题'),
            const SizedBox(height: 8),
            ...problems.map((problem) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActionLinkCard(
                    title: problem.title,
                    subtitle: problem.summary,
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillProblemDetailPage(problem: problem))),
                  ),
                )),
          ],
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionTitle('建议先做的现实任务'),
            const SizedBox(height: 8),
            ...tasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActionLinkCard(
                    title: task.title,
                    subtitle: task.action,
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillTaskDetailPage(task: task))),
                  ),
                )),
          ],
          const SizedBox(height: 12),
          const _SectionTitle('关联知识卡'),
          const SizedBox(height: 8),
          ...cards.map((card) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _KnowledgeCardTile(
                  card: card,
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillCardDetailPage(cardId: card.id))),
                ),
              )),
        ],
      ),
    );
  }
}



String _formatMs(int ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}


class _TintCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color borderColor;
  const _TintCard({
    required this.child,
    required this.color,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String title;
  final String body;
  const _DetailBlock({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(height: 1.55, color: Color(0xFF374151))),
        ],
      ),
    );
  }
}

class _ProblemPathCard extends StatelessWidget {
  final WillProblemPath problem;
  final VoidCallback? onTap;
  const _ProblemPathCard({required this.problem, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _EntryCard(
      icon: Icons.psychology_alt_outlined,
      title: problem.title,
      subtitle: problem.summary,
      onTap: onTap,
    );
  }
}

class _TaskPlanCard extends StatelessWidget {
  final WillTaskPlan task;
  final VoidCallback? onTap;
  const _TaskPlanCard({required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _EntryCard(
      icon: Icons.checklist_rtl_rounded,
      title: task.title,
      subtitle: task.action,
      onTap: onTap,
    );
  }
}

class _WorldZoneCard extends StatelessWidget {
  final WillWorldZone zone;
  final VoidCallback? onTap;
  const _WorldZoneCard({required this.zone, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _EntryCard(
      icon: Icons.public_rounded,
      title: zone.title,
      subtitle: zone.missionTitle,
      onTap: onTap,
    );
  }
}

class _ReviewField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _ReviewField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: null,
          minLines: 2,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> chips;
  const _HeroCard({required this.title, required this.subtitle, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFEEF2FF), Color(0xFFF8FAFC)]),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Color(0xFF4B5563), height: 1.5)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: chips.map((e) => _TagChip(e)).toList()),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<String> lines;
  const _InfoCard({required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines
            .map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _BulletLine(e),
                ))
            .toList(),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _EntryCard({required this.icon, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _StageBadgeChip extends StatelessWidget {
  final WillStageMilestoneEntry milestone;
  const _StageBadgeChip({required this.milestone});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: _stageColor(milestone.stageKey).withOpacity(0.15),
        child: Icon(_stageIcon(milestone.stageKey), size: 16, color: _stageColor(milestone.stageKey)),
      ),
      label: Text(milestone.stageLabel),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE5E7EB)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }
}

class _KnowledgeSectionCard extends StatelessWidget {
  final WillModuleSection section;
  final VoidCallback onTap;
  const _KnowledgeSectionCard({required this.section, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _EntryCard(
      icon: Icons.library_books_outlined,
      title: section.title,
      subtitle: '${section.subtitle} · ${section.unitCount} 单元',
      onTap: onTap,
    );
  }
}

class _KnowledgeCardTile extends StatelessWidget {
  final WillKnowledgeCard card;
  final VoidCallback onTap;
  const _KnowledgeCardTile({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _EntryCard(
      icon: Icons.menu_book_rounded,
      title: '${card.label} · ${card.title}',
      subtitle: card.oneLiner,
      onTap: onTap,
    );
  }
}

class _StatsCard extends StatelessWidget {
  final VoidCallback? onOpenDashboard;
  const _StatsCard({this.onOpenDashboard});

  @override
  Widget build(BuildContext context) {
    final dao = WillDao();
    return FutureBuilder<WillDashboardSummary>(
      future: dao.getDashboardSummary(),
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final loading = snapshot.connectionState != ConnectionState.done && summary == null;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('意志训练总览', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  if (onOpenDashboard != null)
                    TextButton.icon(
                      onPressed: onOpenDashboard,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('查看全部'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _MiniStat(label: '计划', value: loading ? '...' : '${summary?.planCount ?? 0}')),
                  const SizedBox(width: 10),
                  Expanded(child: _MiniStat(label: '执行', value: loading ? '...' : '${summary?.executionCount ?? 0}')),
                  const SizedBox(width: 10),
                  Expanded(child: _MiniStat(label: '复盘', value: loading ? '...' : '${summary?.reviewCount ?? 0}')),
                  const SizedBox(width: 10),
                  Expanded(child: _MiniStat(label: '链路', value: loading ? '...' : '${summary?.taskCount ?? 0}')),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                loading
                    ? '正在读取本地训练数据…'
                    : '你已经留下了 ${summary?.planCount ?? 0} 条计划、${summary?.executionCount ?? 0} 次执行、${summary?.reviewCount ?? 0} 条复盘，形成了 ${summary?.taskCount ?? 0} 条任务链路。',
                style: const TextStyle(color: Color(0xFF6B7280), height: 1.45),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SimpleRowCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SimpleRowCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), height: 1.4)),
        ],
      ),
    );
  }
}



class _StageTransitionCard extends StatelessWidget {
  final String previousLabel;
  final String currentLabel;
  final String changedAtLabel;
  final String nextActionLabel;
  final VoidCallback onTakeNextStep;

  const _StageTransitionCard({
    required this.previousLabel,
    required this.currentLabel,
    required this.changedAtLabel,
    required this.nextActionLabel,
    required this.onTakeNextStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.celebration_outlined, color: Color(0xFF4F46E5), size: 18),
              SizedBox(width: 8),
              Text('阶段切换提示', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF312E81))),
            ],
          ),
          const SizedBox(height: 8),
          Text('你已从“$previousLabel”进入“$currentLabel”。', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text('记录时间：$changedAtLabel\n这说明你的训练状态已经跨过了上一个阶段。现在最值得做的，是顺着当前阶段的重点继续推进，而不是回头把所有事重做一遍。', style: const TextStyle(color: Color(0xFF4B5563), height: 1.5)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.flag_outlined, color: Color(0xFF4F46E5), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('进入新阶段后的第一步：$nextActionLabel', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF312E81))),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: onTakeNextStep,
                  child: const Text('现在去做'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StageTimelineItem extends StatelessWidget {
  final WillStageMilestoneEntry milestone;
  final String timeLabel;

  const _StageTimelineItem({required this.milestone, required this.timeLabel});

  @override
  Widget build(BuildContext context) {
    final color = _stageColor(milestone.stageKey);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Container(width: 2, height: 52, color: color.withOpacity(0.22)),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${milestone.stageLabel} 已点亮', style: const TextStyle(fontWeight: FontWeight.w800))),
                    Text(timeLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(milestone.detail, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CoachStageCard extends StatelessWidget {
  final _CoachStage stage;
  final VoidCallback? onTap;

  const _CoachStageCard({required this.stage, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _stageColor(stage.key).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(stage.stageLabel, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _stageColor(stage.key))),
              ),
              const SizedBox(width: 8),
              if (stage.completed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Text('阶段已点亮', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF047857))),
                ),
              const Spacer(),
              Icon(_stageIcon(stage.key), color: _stageColor(stage.key), size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(stage.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(stage.subtitle, style: const TextStyle(color: Color(0xFF4B5563), height: 1.55)),
          const SizedBox(height: 12),
          const Text('这个阶段先抓 3 件事', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...stage.focusPoints.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e, style: const TextStyle(color: Color(0xFF374151), height: 1.45))),
                  ],
                ),
              )),
          if (stage.unitIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('这一阶段建议先学', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stage.unitIds
                  .map((id) => WillRouteResolver.unitById(id))
                  .whereType<WillUnitIndex>()
                  .map((unit) => InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillUnitIndexDetailPage(unit: unit))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text('${unit.id} · ${unit.title}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          const Text('阶段完成条件', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stage.progressLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: _progressValue(stage.checkpoints),
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(height: 10),
                ...stage.checkpoints.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            c.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: c.done ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.label,
                              style: TextStyle(
                                color: c.done ? const Color(0xFF111827) : const Color(0xFF6B7280),
                                fontWeight: c.done ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          if (stage.completed) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Text('当前阶段已达成，继续完成下一个动作，就会更自然地进入下一阶段。', style: TextStyle(color: Color(0xFF065F46), height: 1.5, fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 12),
          const Text('下一阶段预告', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stage.nextStageLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF92400E))),
                const SizedBox(height: 6),
                Text(stage.nextStageHint, style: const TextStyle(color: Color(0xFF6B7280), height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.trending_up_outlined),
            label: Text(stage.actionLabel),
          ),
        ],
      ),
    );
  }
}

class _SmartSuggestionCard extends StatelessWidget {
  final _SmartSuggestion suggestion;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  const _SmartSuggestionCard({required this.suggestion, this.onTap, this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tips_and_updates_outlined, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(suggestion.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(suggestion.priorityLabel),
              _Badge(suggestion.horizonLabel),
            ],
          ),
          const SizedBox(height: 10),
          Text(suggestion.subtitle, style: const TextStyle(color: Color(0xFF4B5563), height: 1.55)),
          if (suggestion.unitIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('推荐先学', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestion.unitIds
                  .map((id) => WillRouteResolver.unitById(id))
                  .whereType<WillUnitIndex>()
                  .map((unit) => InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillUnitIndexDetailPage(unit: unit)));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(
                            '${unit.id} · ${unit.title}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(suggestion.actionLabel),
              ),
              OutlinedButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('已处理并刷新'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeatDayCell extends StatelessWidget {
  final _DayActivitySummary day;
  const _HeatDayCell({required this.day});

  @override
  Widget build(BuildContext context) {
    final level = day.total >= 5 ? 1.0 : day.total >= 3 ? 0.75 : day.total >= 1 ? 0.45 : 0.12;
    return Column(
      children: [
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: Color.lerp(const Color(0xFFE5E7EB), const Color(0xFF2563EB), level),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              '${day.total}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: level > 0.5 ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('${day.day.month}/${day.day.day}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        const SizedBox(height: 2),
        Text('周${_weekdayZh(day.day.weekday)}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
      ],
    );
  }
}

class _DayTrendRow extends StatelessWidget {
  final _DayActivitySummary day;
  const _DayTrendRow({required this.day});

  @override
  Widget build(BuildContext context) {
    final barWidth = (day.total * 28.0).clamp(12.0, 160.0);
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text('${day.day.month}/${day.day.day} 周${_weekdayZh(day.day.weekday)}', style: const TextStyle(color: Color(0xFF6B7280))),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Container(
                width: barWidth,
                height: 16,
                decoration: BoxDecoration(
                  color: day.total == 0 ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 84,
          child: Text(
            '执${day.executionCount} 复${day.reviewCount} 城${day.zoneCount}',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800));
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  final bool dark;
  const _TagChip(this.text, {this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: dark ? Colors.white : const Color(0xFF374151),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF3730A3))),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;
  const _BulletLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('• '),
          ),
          Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
        ],
      ),
    );
  }
}


class WillStudyRoadmapPage extends StatelessWidget {
  const WillStudyRoadmapPage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('课程学习路线')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _InfoCard(lines: [
            '建议先学导论，再进入观念—运动作用，之后再转到努力、爆发、阻塞与意志教育。',
            '这样学习的好处是：先理解意志如何发生，再进入现实中的拖延、冲动、决策与训练。',
          ]),
          const SizedBox(height: 12),
          _RoadmapStepCard(
            step: 'Step 1',
            title: '导论 83 段',
            subtitle: '欲望 / 愿望 / 意志、动作观念、动觉、神经支配感批判、动作线索',
            onTap: () => _open(context, const WillModuleUnitLibraryPage(moduleCode: 'D')),
          ),
          const SizedBox(height: 10),
          _RoadmapStepCard(
            step: 'Step 2',
            title: '观念—运动作用 19 段',
            subtitle: '想到就做、冲突观念、赖床案例、fiat 与阻滞解除',
            onTap: () => _open(context, const WillModuleUnitLibraryPage(moduleCode: 'I')),
          ),
          const SizedBox(height: 10),
          _RoadmapStepCard(
            step: 'Step 3',
            title: '审议 → 决断 → 努力',
            subtitle: '先看自己如何犹豫，再看自己如何决定，再看 effort 落在什么地方',
            onTap: () => _open(context, const WillUnitIndexPage(initialModuleCode: 'A')),
          ),
          const SizedBox(height: 10),
          _RoadmapStepCard(
            step: 'Step 4',
            title: '爆发、阻塞与快乐痛苦动力',
            subtitle: '把现实中的冲动失控、明白却做不到、即时舒服牵引放回机制里理解',
            onTap: () => _open(context, const WillUnitIndexPage(initialModuleCode: 'X')),
          ),
          const SizedBox(height: 10),
          _RoadmapStepCard(
            step: 'Step 5',
            title: '意志与观念 / 自由意志 / 意志教育',
            subtitle: '最后再进入“同意”“努力变量”与“新通路形成”的训练视角',
            onTap: () => _open(context, const WillUnitIndexPage(initialModuleCode: 'R')),
          ),
        ],
      ),
    );
  }
}

class WillUnitIndexPage extends StatefulWidget {
  final String? initialModuleCode;
  const WillUnitIndexPage({super.key, this.initialModuleCode});

  @override
  State<WillUnitIndexPage> createState() => _WillUnitIndexPageState();
}

class _WillUnitIndexPageState extends State<WillUnitIndexPage> {
  late String _selectedModule;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedModule = widget.initialModuleCode ?? 'ALL';
  }

  @override
  Widget build(BuildContext context) {
    final moduleCodes = ['ALL', ...{for (final e in kWillUnitIndexes) e.moduleCode}.toList()];
    final filtered = kWillUnitIndexes.where((u) {
      final m = _selectedModule == 'ALL' || u.moduleCode == _selectedModule;
      final q = _query.trim().isEmpty || u.title.contains(_query.trim()) || u.oneLiner.contains(_query.trim()) || u.tags.any((t) => t.contains(_query.trim()));
      return m && q;
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('209 单元总表')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索标题、定义或标签',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: moduleCodes.map((code) {
                final active = code == _selectedModule;
                final label = code == 'ALL' ? '全部' : _moduleTabLabel(code);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: active,
                    onSelected: (_) => setState(() => _selectedModule = code),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final unit = filtered[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _UnitIndexTile(
                    unit: unit,
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillUnitIndexDetailPage(unit: unit))),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class WillModuleUnitLibraryPage extends StatelessWidget {
  final String moduleCode;
  const WillModuleUnitLibraryPage({super.key, required this.moduleCode});

  @override
  Widget build(BuildContext context) {
    final units = kWillUnitIndexes.where((e) => e.moduleCode == moduleCode).toList();
    final moduleTitle = units.isEmpty ? moduleCode : units.first.moduleTitle;
    final intro = kWillModuleLongIntro[moduleCode] ?? '这一模块正在持续扩充中。';
    final goals = kWillModuleStudyGoals[moduleCode] ?? const <String>[];
    return Scaffold(
      appBar: AppBar(title: Text('$moduleTitle · 标准库')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(moduleTitle, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                    _Badge('${units.length} 单元'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(intro, style: const TextStyle(color: Color(0xFF4B5563), height: 1.5)),
                if (goals.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('学习目标', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  ...goals.map((g) => _BulletLine(g)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _SectionTitle('标准知识单元'),
          const SizedBox(height: 8),
          ...units.map((unit) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _UnitIndexTile(
                  unit: unit,
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillUnitIndexDetailPage(unit: unit))),
                ),
              )),
        ],
      ),
    );
  }
}

class WillUnitIndexDetailPage extends StatelessWidget {
  final WillUnitIndex unit;
  const WillUnitIndexDetailPage({super.key, required this.unit});

  @override
  Widget build(BuildContext context) {
    final deep = getWillDeepLessonContent(unit);
    final preciseOriginal = kWillOriginalPreciseSegments[unit.id];
    final recommendedProblems = WillRouteResolver.recommendedProblemsForUnit(unit);
    final recommendedTasks = WillRouteResolver.recommendedTasksForUnit(unit);
    final recommendedZones = WillRouteResolver.recommendedZonesForUnit(unit);
    return Scaffold(
      appBar: AppBar(title: Text(unit.id)),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(unit.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                    _Badge(unit.moduleCode),
                  ],
                ),
                const SizedBox(height: 8),
                Text(unit.oneLiner, style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF374151))),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: unit.tags.map((e) => _TagChip(e)).toList()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (preciseOriginal != null) ...[
            _TintCard(
              color: const Color(0xFFFFF7ED),
              borderColor: const Color(0xFFFED7AA),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.compare_arrows_outlined, size: 18, color: Color(0xFFEA580C)),
                      SizedBox(width: 8),
                      Text('对照学习：原文片段 × 单元解释', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF9A3412))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('${unit.id} · ${unit.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF7C2D12))),
                  const SizedBox(height: 10),
                  const Text('原文简化版对应片段', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF9A3412))),
                  const SizedBox(height: 6),
                  SelectableText(
                    preciseOriginal,
                    style: const TextStyle(fontSize: 14.5, height: 1.7, color: Color(0xFF7C2D12)),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  const Text('本单元解释', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF9A3412))),
                  const SizedBox(height: 6),
                  Text(deep.coreMeaning, style: const TextStyle(fontSize: 14.5, height: 1.65, color: Color(0xFF7C2D12))),
                  const SizedBox(height: 10),
                  const Text('现实应用', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF9A3412))),
                  const SizedBox(height: 6),
                  Text(deep.realCase, style: const TextStyle(fontSize: 14.5, height: 1.65, color: Color(0xFF7C2D12))),
                  const SizedBox(height: 10),
                  const Text('实践动作', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF9A3412))),
                  const SizedBox(height: 6),
                  Text(deep.practiceAction, style: const TextStyle(fontSize: 14.5, height: 1.65, color: Color(0xFF7C2D12))),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          _DetailBlock(title: '原著要点', body: deep.originalKeyPoint),
          const SizedBox(height: 10),
          _DetailBlock(title: '核心含义', body: deep.coreMeaning),
          const SizedBox(height: 10),
          _DetailBlock(title: '外延与适用范围', body: deep.extension),
          const SizedBox(height: 10),
          _DetailBlock(title: '现实场景', body: deep.realCase),
          const SizedBox(height: 10),
          _DetailBlock(title: '最小实践动作', body: deep.practiceAction),
          const SizedBox(height: 10),
          _DetailBlock(title: 'if-then 模板', body: deep.ifThen),
          const SizedBox(height: 10),
          _DetailBlock(title: '镜像城映射', body: '推荐在「${deep.mirrorZone}」练习这个概念：先在虚拟场景里识别它，再回到现实中做一次最小动作。'),
          const SizedBox(height: 10),
          _DetailBlock(title: '复盘问题', body: deep.reviewPrompt),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => WillOriginalSimplifiedReaderPage(
                  initialUnitId: unit.id,
                  onOpenUnit: (picked) => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => WillUnitIndexDetailPage(unit: picked)),
                  ),
                ),
              ),
            ),
            icon: const Icon(Icons.article_outlined),
            label: const Text('查看原文简化版全文对应位置'),
          ),
          if (recommendedProblems.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionTitle('推荐问题路径'),
            const SizedBox(height: 8),
            ...recommendedProblems.map((problem) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActionLinkCard(
                    title: problem.title,
                    subtitle: problem.summary,
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillProblemDetailPage(problem: problem))),
                  ),
                )),
          ],
          if (recommendedTasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionTitle('推荐现实任务'),
            const SizedBox(height: 8),
            ...recommendedTasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActionLinkCard(
                    title: task.title,
                    subtitle: task.action,
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillTaskDetailPage(task: task))),
                  ),
                )),
          ],
          if (recommendedZones.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionTitle('推荐镜像城练习'),
            const SizedBox(height: 8),
            ...recommendedZones.map((zone) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActionLinkCard(
                    title: zone.title,
                    subtitle: zone.missionTitle,
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => WillWorldZoneDetailPage(zone: zone))),
                  ),
                )),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => WillReviewCenterPage(
                  initialTaskTitle: '${unit.id}｜${unit.title}',
                ),
              ),
            ),
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('用这个单元开始复盘'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const WillTaskHubPage()),
            ),
            icon: const Icon(Icons.task_alt_outlined),
            label: const Text('前往现实任务中心'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const WillDashboardPage()),
            ),
            icon: const Icon(Icons.dashboard_outlined),
            label: const Text('查看训练总览'),
          ),
        ],
      ),
    );
  }
}

class _RoadmapStepCard extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _RoadmapStepCard({required this.step, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(step, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3730A3))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}


class _ActionLinkCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionLinkCard({required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.chevron_right_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitIndexTile extends StatelessWidget {
  final WillUnitIndex unit;
  final VoidCallback onTap;
  const _UnitIndexTile({required this.unit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Badge(unit.id),
                  const SizedBox(width: 8),
                  Expanded(child: Text(unit.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                ],
              ),
              const SizedBox(height: 8),
              Text(unit.oneLiner, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: unit.tags.map((e) => _TagChip(e)).toList()),
            ],
          ),
        ),
      ),
    );
  }
}

String _moduleTabLabel(String code) {
  switch (code) {
    case 'D': return '导论';
    case 'I': return '观念—运动';
    case 'A': return '审议';
    case 'T': return '决定类型';
    case 'E': return '努力';
    case 'X': return '爆发';
    case 'O': return '阻塞';
    case 'P': return '快痛动力';
    case 'R': return '意志与观念';
    case 'F': return '自由意志';
    case 'W': return '意志教育';
    default: return code;
  }
}
