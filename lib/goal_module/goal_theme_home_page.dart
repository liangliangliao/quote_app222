import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../belief_lab/belief_lab_home_page.dart';
import '../failure_module/failure_module_home_page.dart';
import '../pages/discover_page.dart';
import 'goal_action_history_page.dart';
import 'goal_action_runner_page.dart';
import 'goal_action_record_detail_page.dart';
import 'goal_concepts_page.dart';
import 'goal_dao.dart';
import 'goal_module_review_page.dart';
import 'goal_models.dart';
import 'goal_review_center_page.dart';
import 'goal_segment_detail_page.dart';
import 'goal_segments_library_page.dart';
import 'goal_stats_page.dart';
import 'goal_study_progress_page.dart';
import 'goal_topic_review_page.dart';
import 'goal_virtual_world_page.dart';
import 'goal_world_scene_detail_page.dart';
import 'goal_world_seed.dart';
import 'goal_workshop_page.dart';

class GoalThemeHomePage extends StatelessWidget {
  const GoalThemeHomePage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('目标人生')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _HeroCard(
            title: '以目标为主题的成长模块',
            subtitle: '先把真正重要的目标找出来，再把它拆成可实践、可复盘、可长期坚持的日常路径。',
            chips: const ['课程原文馆', '概念实践馆', '目标工坊', '主题复习', '目标试验场', '场景任务'],
          ),
          const SizedBox(height: 14),
          const _StatsPreviewCard(),
          const SizedBox(height: 14),
          const _OperationsPanel(),
          const SizedBox(height: 14),
          const _SectionTitle('核心入口'),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.menu_book_outlined,
            title: '课程原文馆',
            subtitle: '完整保留 36 段目标课程简化正文，可查看、复习、回看。',
            onTap: () => _open(context, const GoalSegmentsLibraryPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.timeline_outlined,
            title: '学习进度',
            subtitle: '查看最近复习、章节完成度、难点回顾卡和主题学习进度。',
            onTap: () => _open(context, const GoalStudyProgressPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.lightbulb_outline,
            title: '概念实践馆',
            subtitle: '36 段原文对应的概念实践卡：是什么、为什么、怎么做。',
            onTap: () => _open(context, const GoalConceptsPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.construction_outlined,
            title: '目标工坊',
            subtitle: '身份宣言 → why → 外界期待 → 目标冲突检查 → lifeline → stretch → 本周推进 → if-then',
            onTap: () => _open(context, const GoalWorkshopPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.auto_stories_outlined,
            title: '按主题复习',
            subtitle: '按“目标为什么有效 / 自我一致性 / 目标落地技术”等主题回看正文。',
            onTap: () => _open(context, const GoalTopicReviewPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.landscape_outlined,
            title: '目标试验场',
            subtitle: '迷雾平原 / 镜湖 / 工坊城，用轻量场景把课程与现实问题连起来。',
            onTap: () => _open(context, const GoalVirtualWorldPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.autorenew_outlined,
            title: '行动闭环',
            subtitle: '按今天/本周查看行动记录，进入二次复盘，并决定继续、调整或放弃。',
            onTap: () => _open(context, const GoalActionHistoryPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.history_edu_outlined,
            title: '复习中心',
            subtitle: '查看收藏/难点/重点段落，以及最近行动记录。',
            onTap: () => _open(context, const GoalReviewCenterPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.query_stats_outlined,
            title: '数据看板',
            subtitle: '查看课程正文、概念实践、复习标记与行动记录的整体情况。',
            onTap: () => _open(context, const GoalStatsPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.flag_outlined,
            title: '愿景与目标',
            subtitle: '身份宣言 → WOOP → 时间/地点触发 → 专注与反思',
            onTap: () => _open(context, const VisionGoalPage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.auto_awesome,
            title: '信念工坊',
            subtitle: '微实验 + 案例 + 最小行动，把心理学概念落进现实。',
            onTap: () => _open(context, const BeliefLabHomePage()),
          ),
          const SizedBox(height: 10),
          _EntryCard(
            icon: Icons.psychology_alt_outlined,
            title: '失败与完美主义',
            subtitle: '3P急救 → 概念地图 → 行动模板 → 学习卡',
            onTap: () => _open(context, const FailureModuleHomePage()),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('当前说明'),
          const SizedBox(height: 10),
          const _InfoCard(
            lines: [
              '左侧菜单已新增“目标人生”入口。',
              '课程原文馆已把 36 段课程正文作为数据库 seed 落到独立表中，支持查看、复习与回看。',
              '概念实践馆已升级为高级版：加入误区辨析、小测问答、多级行动任务和概念级反思统计。',
              '目标工坊现在支持“外界期待 / 竞争性目标”记录，并提供目标冲突与一致性检查。',
              '目标工坊还会自动生成微行动/标准行动/进阶行动草稿，并在工坊内显示最近一次由工坊发起的行动结果与待复盘入口。',
              '现在已经新增行动执行页、复习中心与数据看板，开始形成“原文 → 概念 → 行动 → 复盘”的闭环。',
              '首页现在已增强为运营面板：可查看最近学习、最近行动、待复盘、场景进度和本周目标摘要，并支持恢复上次具体学习位置、场景状态和未完成行动步骤。',
              '课程原文馆现在加入了“章节完成仪式”和“主题复盘页”：学完某个主题后，再打开其中任意一段正文时，会弹出简短总结，并可进入主题复盘，写下这组内容讲了什么、最有感的一点，以及准备带去现实的一步。',
              '学习进度页和数据看板现在也会显示主题复盘统计：能看到哪些主题已经写过复盘、写过“现实一步”、进入行动，以及真正进入行动闭环。',
              '现在主题复盘发起的行动也已纳入首页继续流：如果最近一次由主题复盘带出的行动还未完成二次复盘，首页会优先提示你继续它，并在首页展示最近的主题复盘行动。',
              '现在首页也支持“继续主题复盘”：如果你最近写过某个主题复盘，首页会单独展示它，并恢复到你上次停下的大致位置。',
              '数据看板与学习进度页现在新增了“主题复盘转化可视化”：可以直接看到哪些主题已经从写下复盘推进到现实一步、发起行动和进入闭环。',
              '目标试验场现在会记住你上次停下的具体任务卡：首页可直接继续场景任务，并在场景进度里显示“上次停在”的任务。',
              '首页还新增了“最近场景奖励”：完成场景并领奖后，会在首页展示最近奖励，并可直接进入对应的推荐现实行动。',
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsPreviewCard extends StatefulWidget {
  const _StatsPreviewCard();

  @override
  State<_StatsPreviewCard> createState() => _StatsPreviewCardState();
}

class _StatsPreviewCardState extends State<_StatsPreviewCard> {
  final _dao = GoalDao();
  late Future<Map<String, int>> _future;

  @override
  void initState() {
    super.initState();
    _future = _dao.getStatsSummary();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final s = snap.data!;
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
              const Text('当前进度概览', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _miniStat('正文', '${s['segments'] ?? 0}')),
                  const SizedBox(width: 10),
                  Expanded(child: _miniStat('概念', '${s['concepts'] ?? 0}')),
                  const SizedBox(width: 10),
                  Expanded(child: _miniStat('复习', '${s['reviewed'] ?? 0}')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _miniStat('行动', '${s['actions'] ?? 0}')),
                  const SizedBox(width: 10),
                  Expanded(child: _miniStat('二次复盘', '${s['followups'] ?? 0}')),
                  const SizedBox(width: 10),
                  Expanded(child: _miniStat('主题复盘', '${s['moduleReviews'] ?? 0}')), 
                ],
              ),
              const SizedBox(height: 10),
              Text('收藏 ${s['favorites'] ?? 0} · 重点 ${s['keys'] ?? 0} · 难点 ${s['difficult'] ?? 0} · 主题复盘行动 ${s['moduleReviewActions'] ?? 0}', style: const TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        );
      },
    );
  }

  Widget _miniStat(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      );
}

class _OperationsPanel extends StatefulWidget {
  const _OperationsPanel();

  @override
  State<_OperationsPanel> createState() => _OperationsPanelState();
}

class _OperationsPanelState extends State<_OperationsPanel> {
  final _dao = GoalDao();
  late Future<_HomeOpsBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeOpsBundle> _load() async {
    final recentReviewed = await _dao.listRecentReviewedSegments(limit: 4);
    final recentActions = await _dao.listActionRecordViews(limit: 6, period: 'all');
    final workshop = await _dao.getWorkshopDraft();
    final worldProgress = await _dao.listWorldSceneProgress();
    final latestRewardProgress = await _dao.getLatestRewardedSceneProgress();
    GoalSceneActionSuggestion? latestRewardSuggestion;
    if (latestRewardProgress != null) {
      final suggestions = await _dao.listRecommendedActionsForScene(latestRewardProgress.sceneId, limit: 1);
      if (suggestions.isNotEmpty) latestRewardSuggestion = suggestions.first;
    }
    final latestDraft = await _dao.getLatestActionDraft();
    final moduleReviewOverview = await _dao.getModuleReviewActionOverview();
    final lastLearning = await _dao.getContinueState('last_learning');
    final lastScene = await _dao.getContinueState('last_scene');
    final lastModuleReview = await _dao.getContinueState('last_module_review');
    return _HomeOpsBundle(
      recentReviewed: recentReviewed,
      recentActions: recentActions,
      workshop: workshop,
      worldProgress: worldProgress,
      latestRewardProgress: latestRewardProgress,
      latestRewardSuggestion: latestRewardSuggestion,
      latestDraft: latestDraft,
      moduleReviewOverview: moduleReviewOverview,
      lastLearning: lastLearning,
      lastScene: lastScene,
      lastModuleReview: lastModuleReview,
    );
  }

  void _open(Widget page) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => page)).then((_) {
      if (mounted) setState(() => _future = _load());
    });
  }

  String _fmt(int ms) {
    if (ms <= 0) return '未记录';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.month}/${d.day} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeOpsBundle>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data!;
        final pending = data.recentActions.where((e) => !e.hasFollowup).toList();
        final latestPending = pending.isNotEmpty ? pending.first : null;
        final sceneMap = {for (final p in data.worldProgress) p.sceneId: p};
        final scenes = goalWorldScenes
            .map((def) => _HomeSceneProgressItem(def: def, progress: sceneMap[def.sceneId] ?? GoalWorldSceneProgress.empty(def.sceneId)))
            .toList();
        final latestInterrupted = _HomeContinueTarget.from(data, latestPending, scenes, data.moduleReviewOverview.pendingAction);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('继续与摘要'),
            const SizedBox(height: 10),
            _dashboardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('一键继续上次中断的任务', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                      if (latestInterrupted.badge.isNotEmpty) _badge(latestInterrupted.badge),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(latestInterrupted.subtitle, style: const TextStyle(color: Color(0xFF4B5563), height: 1.5)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _open(latestInterrupted.page),
                      icon: Icon(latestInterrupted.icon),
                      label: Text(latestInterrupted.title),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _dashboardCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardHeader('本周目标摘要', onTap: () => _open(const GoalWorkshopPage())),
                        const SizedBox(height: 10),
                        _summaryLine('身份宣言', data.workshop.identityStatement),
                        const SizedBox(height: 8),
                        _summaryLine('本周推进', data.workshop.weeklyGoal),
                        const SizedBox(height: 8),
                        _summaryLine('明天第一步', data.workshop.firstStep),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dashboardCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardHeader('待复盘行动', onTap: () => _open(const GoalActionHistoryPage())),
                        const SizedBox(height: 10),
                        _miniCount('待复盘', '${pending.length}'),
                        const SizedBox(height: 8),
                        _miniCount('最近行动', '${data.recentActions.length}'),
                        const SizedBox(height: 10),
                        if (latestPending != null)
                          _tinyActionTile(latestPending, onTap: () => _open(GoalActionRecordDetailPage(recordId: latestPending.record.id)))
                        else
                          const Text('最近的行动记录都已进入二次复盘。', style: TextStyle(color: Color(0xFF6B7280), height: 1.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _dashboardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cardHeader('最近学习', onTap: () => _open(const GoalStudyProgressPage())),
                  const SizedBox(height: 10),
                  if (data.recentReviewed.isEmpty)
                    const Text('还没有最近复习记录。打开任意一段课程正文后，这里会自动出现。', style: TextStyle(color: Color(0xFF6B7280), height: 1.5))
                  else
                    Column(
                      children: [
                        for (final item in data.recentReviewed.take(3)) ...[
                          _simpleListTile(
                            title: item.segment.sectionTitle,
                            subtitle: '${item.segment.sourceCourseName} · 最近复习 ${_fmt(item.review.reviewedAtMs)}',
                            icon: Icons.menu_book_outlined,
                            onTap: () => _open(GoalSegmentDetailPage(segmentId: item.segment.segmentId)),
                          ),
                          if (item != data.recentReviewed.take(3).last) const SizedBox(height: 8),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _dashboardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cardHeader('继续主题复盘', onTap: () {
                    final extra = data.lastModuleReview.extraMap;
                    final sourceCourse = extra['sourceCourse']?.trim() ?? '';
                    final moduleGroup = extra['moduleGroup']?.trim() ?? '';
                    if (sourceCourse.isEmpty || moduleGroup.isEmpty) return;
                    _open(GoalModuleReviewPage(sourceCourse: sourceCourse, moduleGroup: moduleGroup));
                  }),
                  const SizedBox(height: 10),
                  if ((data.lastModuleReview.extraMap['sourceCourse']?.trim().isNotEmpty ?? false) &&
                      (data.lastModuleReview.extraMap['moduleGroup']?.trim().isNotEmpty ?? false)) ...[
                    _simpleListTile(
                      title: '继续主题复盘：${data.lastModuleReview.extraMap['title']?.trim().isNotEmpty == true ? data.lastModuleReview.extraMap['title']!.trim() : data.lastModuleReview.extraMap['moduleGroup']!.trim()}',
                      subtitle: '${data.lastModuleReview.extraMap['sourceCourseName']?.trim().isNotEmpty == true ? data.lastModuleReview.extraMap['sourceCourseName']!.trim() : '课程主题'}${(data.lastModuleReview.extraMap['preview']?.trim().isNotEmpty ?? false) ? ' · ${data.lastModuleReview.extraMap['preview']!.trim()}' : ' · 将恢复到你上次写复盘的大致位置。'}',
                      icon: Icons.edit_note_outlined,
                      onTap: () => _open(GoalModuleReviewPage(
                        sourceCourse: data.lastModuleReview.extraMap['sourceCourse']!.trim(),
                        moduleGroup: data.lastModuleReview.extraMap['moduleGroup']!.trim(),
                      )),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.lastModuleReview.updatedAtMs > 0 ? '最近编辑：${_fmt(data.lastModuleReview.updatedAtMs)}' : '最近编辑：未记录',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ] else
                    const Text('当你写过某个主题复盘后，这里会出现“继续主题复盘”的入口，并恢复到你上次停下的大致位置。', style: TextStyle(color: Color(0xFF6B7280), height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _dashboardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cardHeader('主题复盘行动', onTap: () => _open(const GoalActionHistoryPage())),
                  const SizedBox(height: 10),
                  if (!data.moduleReviewOverview.hasAny)
                    const Text('还没有由主题复盘直接带出的行动。学完一个主题并进入主题复盘页后，这里会出现最近的主题复盘行动。', style: TextStyle(color: Color(0xFF6B7280), height: 1.5))
                  else ...[
                    if (data.moduleReviewOverview.pendingAction != null)
                      _simpleListTile(
                        title: '继续主题复盘行动',
                        subtitle: '${data.moduleReviewOverview.pendingAction!.actionTitle} · 这条由主题复盘发起的行动还在等待二次复盘。',
                        icon: Icons.play_circle_outline,
                        onTap: () => _open(GoalActionRecordDetailPage(recordId: data.moduleReviewOverview.pendingAction!.record.id)),
                      )
                    else if (data.moduleReviewOverview.latestAction != null)
                      _simpleListTile(
                        title: '查看最近主题复盘行动',
                        subtitle: '${data.moduleReviewOverview.latestAction!.actionTitle} · 最近一次由主题复盘带出的行动已经进入行动闭环。',
                        icon: Icons.assignment_turned_in_outlined,
                        onTap: () => _open(GoalActionRecordDetailPage(recordId: data.moduleReviewOverview.latestAction!.record.id)),
                      ),
                    if (data.moduleReviewOverview.latestAction != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '最近一次：${data.moduleReviewOverview.latestAction!.conceptTitle} · ${_fmt(data.moduleReviewOverview.latestAction!.record.completedAtMs)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _dashboardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cardHeader('最近场景奖励', onTap: () => _open(const GoalVirtualWorldPage())),
                  const SizedBox(height: 10),
                  if (data.latestRewardProgress == null) ...[
                    const Text('完成任意场景并领取奖励后，这里会显示最近的场景奖励与推荐下一步现实行动。', style: TextStyle(color: Color(0xFF6B7280), height: 1.5)),
                  ] else ...[
                    Builder(
                      builder: (_) {
                        GoalWorldSceneDef? def;
                        for (final item in goalWorldScenes) {
                          if (item.sceneId == data.latestRewardProgress!.sceneId) {
                            def = item;
                            break;
                          }
                        }
                        if (def == null) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _simpleListTile(
                              title: '${def.title} · ${def.rewardTitle}',
                              subtitle: data.latestRewardProgress!.realityNote.trim().isNotEmpty
                                  ? data.latestRewardProgress!.realityNote.trim()
                                  : def.rewardDescription,
                              icon: Icons.workspace_premium_outlined,
                              onTap: () => _open(GoalWorldSceneDetailPage(sceneId: def!.sceneId)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data.latestRewardProgress!.rewardClaimedAtMs > 0
                                  ? '最近领奖：${_fmt(data.latestRewardProgress!.rewardClaimedAtMs)}'
                                  : '最近领奖：${_fmt(data.latestRewardProgress!.updatedAtMs)}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                            if (data.latestRewardSuggestion != null) ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => _open(GoalActionRunnerPage(
                                  action: data.latestRewardSuggestion!.action,
                                  conceptTitle: data.latestRewardSuggestion!.conceptTitle,
                                  segmentTitle: data.latestRewardSuggestion!.segmentTitle,
                                )),
                                icon: const Icon(Icons.play_circle_outline),
                                label: Text('直接去做：${data.latestRewardSuggestion!.action.actionTitle}'),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _dashboardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cardHeader('场景进度', onTap: () => _open(const GoalVirtualWorldPage())),
                  const SizedBox(height: 10),
                  Column(
                    children: [
                      for (final item in scenes) ...[
                        _sceneTile(item, onTap: () => _open(GoalWorldSceneDetailPage(sceneId: item.def.sceneId))),
                        if (item != scenes.last) const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dashboardCard({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: child,
      );

  Widget _cardHeader(String text, {required VoidCallback onTap}) => Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          TextButton(onPressed: onTap, child: const Text('查看全部')),
        ],
      );

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4338CA))),
      );

  Widget _summaryLine(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 3),
          Text(value.trim().isEmpty ? '暂未填写' : value.trim(), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.45)),
        ],
      );

  Widget _miniCount(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _tinyActionTile(GoalActionRecordView item, {required VoidCallback onTap}) => Material(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.actionTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('完成度 ${(item.record.completionRate * 100).round()}% · ${item.conceptTitle}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ),
      );

  Widget _simpleListTile({required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) => Material(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF111827)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ),
      );

  Widget _sceneTile(_HomeSceneProgressItem item, {required VoidCallback onTap}) {
    final completed = item.progress.completedTaskIds.length;
    final total = item.def.tasks.length;
    final pct = total == 0 ? 0.0 : completed / total;
    final rewardText = item.progress.rewardClaimed ? '奖励已领取' : (completed == total ? '可领取奖励' : '进行中');
    final activeTaskTitle = (() {
      if (item.progress.activeTaskId.trim().isEmpty) return '';
      for (final task in item.def.tasks) {
        if (task.taskId == item.progress.activeTaskId) return task.title;
      }
      return '';
    })();
    return Material(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: item.def.accentColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.def.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                  Text(rewardText, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(item.def.accentColor),
              ),
              const SizedBox(height: 8),
              Text('已完成 $completed/$total 项任务' + (item.progress.updatedAtMs > 0 ? ' · 最近 ${_fmt(item.progress.updatedAtMs)}' : ''), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              if (activeTaskTitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('上次停在：$activeTaskTitle', style: TextStyle(fontSize: 12, color: item.def.accentColor, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeOpsBundle {
  final List<GoalReviewedSegment> recentReviewed;
  final List<GoalActionRecordView> recentActions;
  final GoalWorkshopDraft workshop;
  final List<GoalWorldSceneProgress> worldProgress;
  final GoalWorldSceneProgress? latestRewardProgress;
  final GoalSceneActionSuggestion? latestRewardSuggestion;
  final GoalActionDraft? latestDraft;
  final GoalModuleReviewActionOverview moduleReviewOverview;
  final GoalContinueState lastLearning;
  final GoalContinueState lastScene;
  final GoalContinueState lastModuleReview;

  _HomeOpsBundle({
    required this.recentReviewed,
    required this.recentActions,
    required this.workshop,
    required this.worldProgress,
    required this.latestRewardProgress,
    required this.latestRewardSuggestion,
    required this.latestDraft,
    required this.moduleReviewOverview,
    required this.lastLearning,
    required this.lastScene,
    required this.lastModuleReview,
  });
}

class _HomeSceneProgressItem {
  final GoalWorldSceneDef def;
  final GoalWorldSceneProgress progress;

  _HomeSceneProgressItem({required this.def, required this.progress});
}

class _HomeContinueTarget {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Widget page;

  _HomeContinueTarget({required this.title, required this.subtitle, required this.badge, required this.icon, required this.page});

  static _HomeContinueTarget from(_HomeOpsBundle data, GoalActionRecordView? latestPending, List<_HomeSceneProgressItem> scenes, GoalActionRecordView? moduleReviewPending) {
    if (data.latestDraft != null) {
      final draft = data.latestDraft!;
      final pct = (draft.completionRate * 100).round();
      return _HomeContinueTarget(
        title: '继续未完成行动',
        subtitle: '${draft.actionTitle} · 已恢复到上次未完成的步骤与填写内容（当前完成度 ${pct}%）。',
        badge: '步骤已恢复',
        icon: Icons.play_circle_outline,
        page: GoalActionRunnerPage(
          action: draft.toTemplate(),
          conceptTitle: draft.conceptTitleSnapshot,
          segmentTitle: draft.segmentTitleSnapshot,
        ),
      );
    }
    if (moduleReviewPending != null) {
      return _HomeContinueTarget(
        title: '继续主题复盘行动',
        subtitle: '${moduleReviewPending.actionTitle} · 这条由主题复盘带出的行动还没有完成二次复盘，可以继续处理。',
        badge: '主题复盘',
        icon: Icons.assignment_turned_in_outlined,
        page: GoalActionRecordDetailPage(recordId: moduleReviewPending.record.id),
      );
    }
    final moduleReviewSource = data.lastModuleReview.extraMap['sourceCourse']?.trim() ?? '';
    final moduleReviewGroup = data.lastModuleReview.extraMap['moduleGroup']?.trim() ?? '';
    if (moduleReviewSource.isNotEmpty && moduleReviewGroup.isNotEmpty) {
      final title = data.lastModuleReview.extraMap['title']?.trim().isNotEmpty == true
          ? data.lastModuleReview.extraMap['title']!.trim()
          : moduleReviewGroup;
      final preview = data.lastModuleReview.extraMap['preview']?.trim() ?? '';
      return _HomeContinueTarget(
        title: '继续主题复盘',
        subtitle: preview.isNotEmpty ? '$title · $preview' : '$title · 将恢复到你上次主题复盘的大致位置继续。',
        badge: '复盘已恢复',
        icon: Icons.edit_note_outlined,
        page: GoalModuleReviewPage(sourceCourse: moduleReviewSource, moduleGroup: moduleReviewGroup),
      );
    }
    if (latestPending != null) {
      return _HomeContinueTarget(
        title: '继续待复盘行动',
        subtitle: '${latestPending.actionTitle} · 这条记录还没有完成二次复盘，可以直接继续处理。',
        badge: '待复盘',
        icon: Icons.autorenew_outlined,
        page: GoalActionRecordDetailPage(recordId: latestPending.record.id),
      );
    }
    final sceneId = data.lastScene.targetId.trim();
    if (sceneId.isNotEmpty) {
      _HomeSceneProgressItem? current;
      for (final item in scenes) {
        if (item.def.sceneId == sceneId) {
          current = item;
          break;
        }
      }
      if (current != null) {
        final completed = current.progress.completedTaskIds.length;
        final total = current.def.tasks.length;
        final activeTaskTitle = data.lastScene.extraMap['activeTaskTitle']?.trim() ?? '';
        return _HomeContinueTarget(
          title: '继续场景任务',
          subtitle: activeTaskTitle.isNotEmpty
              ? '${current.def.title} · 继续上次停下的任务：$activeTaskTitle'
              : '${current.def.title} · 已完成 $completed/$total 项任务，可从上次场景状态继续。',
          badge: '场景已恢复',
          icon: Icons.landscape_outlined,
          page: GoalWorldSceneDetailPage(sceneId: current.def.sceneId),
        );
      }
    }
    final learningId = data.lastLearning.targetId.trim();
    if (learningId.isNotEmpty) {
      final title = data.lastLearning.extraMap['title']?.trim().isNotEmpty == true ? data.lastLearning.extraMap['title']!.trim() : '课程原文';
      return _HomeContinueTarget(
        title: '继续上次学习位置',
        subtitle: '${title} · 将恢复到你上次阅读的大致位置继续。',
        badge: '位置已恢复',
        icon: Icons.menu_book_outlined,
        page: GoalSegmentDetailPage(segmentId: learningId),
      );
    }
    if (data.recentReviewed.isNotEmpty) {
      final r = data.recentReviewed.first;
      return _HomeContinueTarget(
        title: '继续最近学习',
        subtitle: '${r.segment.sectionTitle} · 回到上次复习的地方，继续深入。',
        badge: '最近学习',
        icon: Icons.menu_book_outlined,
        page: GoalSegmentDetailPage(segmentId: r.segment.segmentId),
      );
    }
    return _HomeContinueTarget(
      title: '继续目标工坊',
      subtitle: '先把你真正想追求的方向、why 和下一步整理出来。',
      badge: '建议开始',
      icon: Icons.construction_outlined,
      page: const GoalWorkshopPage(),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> chips;

  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFFF3F4F6),
            child: Icon(Icons.track_changes_outlined, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in chips)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chip,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF374151)),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF111827)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 8, color: Color(0xFF111827)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(line, style: const TextStyle(height: 1.55, color: Color(0xFF374151))),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
