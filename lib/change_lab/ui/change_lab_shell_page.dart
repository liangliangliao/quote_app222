import 'package:flutter/material.dart';

import '../controllers/change_lab_controller.dart';
import '../models/change_models.dart';
import 'change_ai_coach_page.dart';
import 'change_concept_detail_page.dart';
import 'change_course_review_page.dart';
import 'change_course_reader_page.dart';
import 'change_diagnosis_page.dart';
import 'change_growth_timeline_page.dart';
import 'change_profile_page.dart';
import 'change_reminder_center_page.dart';
import 'change_rules_config_page.dart';
import 'change_task_center_page.dart';
import 'change_weekly_plan_page.dart';
import 'change_world_achievement_page.dart';
import 'mirror_world_page.dart';
import 'mirror_world_scene_page.dart';
import 'widgets/section_card.dart';

class ChangeLabShellPage extends StatefulWidget {
  const ChangeLabShellPage({super.key});

  @override
  State<ChangeLabShellPage> createState() => _ChangeLabShellPageState();
}

class _ChangeLabShellPageState extends State<ChangeLabShellPage> with WidgetsBindingObserver {
  late final ChangeLabController controller;
  int currentIndex = 0;
  String? _presentingRewardId;

  void _presentRewardDialogIfNeeded() {
    if (!mounted) return;
    final unseen = controller.unseenRewardEvents;
    if (unseen.isEmpty) return;
    final event = unseen.first;
    if (_presentingRewardId == event.id) return;
    _presentingRewardId = event.id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final isWorldComplete = controller.isCompletionRewardEvent(event);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(controller.rewardDialogTitle(event)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isWorldComplete ? controller.worldById(event.worldId).title : event.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(controller.rewardFeedNarrative(event), style: const TextStyle(height: 1.5)),
              const SizedBox(height: 12),
              Text(
                isWorldComplete
                    ? controller.worldCompletionNarrative(event.worldId)
                    : '阶段奖励已经进入成长时间线，现在最适合把它接成下一步现实动作。',
                style: const TextStyle(color: Color(0xFF6A6175), height: 1.45),
              ),
              const SizedBox(height: 10),
              Text(
                '下一步：${controller.nextMainlineSummary}',
                style: const TextStyle(color: Color(0xFF6A6175), height: 1.45),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('稍后查看'),
            ),
            if (isWorldComplete)
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeWorldAchievementPage(
                        controller: controller,
                        worldId: event.worldId,
                      ),
                    ),
                  );
                },
                child: const Text('查看世界成就'),
              ),
            FilledButton.tonal(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChangeGrowthTimelinePage(controller: controller),
                  ),
                );
              },
              child: Text(controller.rewardDialogPrimaryActionLabel(event)),
            ),
          ],
        ),
      );
      controller.markRewardEventSeen(event.id);
      _presentingRewardId = null;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = ChangeLabController();
    controller.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.handleAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _OverviewTab(controller: controller),
      _ConceptTab(controller: controller),
      ChangeTaskCenterPage(controller: controller),
      MirrorWorldPage(controller: controller),
      ChangeProfilePage(controller: controller),
    ];
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        _presentRewardDialogIfNeeded();
        return Scaffold(
          backgroundColor: const Color(0xFFF4F2F8),
          appBar: AppBar(
            title: const Text('改变实验室'),
            backgroundColor: const Color(0xFFF4F2F8),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_active_outlined),
                tooltip: '提醒与跟进',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeReminderCenterPage(controller: controller),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.smart_toy_outlined),
                tooltip: 'AI教练',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeAiCoachPage(controller: controller),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.auto_stories_outlined),
                tooltip: '原课全景',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeCourseReaderPage(controller: controller),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.bookmarks_outlined),
                tooltip: '原课收藏与复习',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeCourseReviewPage(controller: controller),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.timeline_outlined),
                tooltip: '成长时间线',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeGrowthTimelinePage(controller: controller),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                tooltip: '本周计划',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeWeeklyPlanPage(controller: controller),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: '问题诊断',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeDiagnosisPage(controller: controller),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.rule_folder_outlined),
                tooltip: '规则与配置',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeRulesConfigPage(controller: controller),
                    ),
                  );
                },
              )
            ],
          ),
          body: controller.isLoading && !controller.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : pages[currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentIndex,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), label: '总览'),
              NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: '概念'),
              NavigationDestination(icon: Icon(Icons.playlist_add_check_circle_outlined), label: '任务'),
              NavigationDestination(icon: Icon(Icons.travel_explore_outlined), label: '镜像'),
              NavigationDestination(icon: Icon(Icons.analytics_outlined), label: '画像'),
            ],
            onDestinationSelected: (index) => setState(() => currentIndex = index),
          ),
        );
      },
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.controller});

  final ChangeLabController controller;

  @override
  Widget build(BuildContext context) {
    final today = controller.suggestedToday;
    final pinned = controller.pinnedConcept;
    final priorityMission = controller.priorityMission;
    final recentRewards = controller.recentRewardEvents(limit: 3);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: '原课全景入口',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lecture 9 后半与 Lecture 10 的完整“改变”主题内容，已经按原顺序接入模块。你可以先系统阅读原课，再回到概念、案例和行动。现在还支持逐段收藏、写笔记、加入复习清单。',
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('收藏 ${controller.favoriteParagraphCount}')),
                  Chip(label: Text('复习 ${controller.reviewParagraphCount}')),
                  Chip(label: Text('笔记 ${controller.notedParagraphCount}')),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeCourseReaderPage(controller: controller),
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: const Text('打开原课全景阅读'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeCourseReviewPage(controller: controller),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bookmarks_outlined),
                    label: const Text('打开原课收藏与复习'),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (controller.recentCourseStudyItems().isNotEmpty)
          SectionCard(
            title: '原课阅读最近进展',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...controller.recentCourseStudyItems(limit: 3).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.bookmark_added_outlined, size: 18, color: Color(0xFF7A63A8)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.conceptTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('${item.blockTitle} · ${item.lectureLabel}', style: const TextStyle(color: Color(0xFF6A6175))),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeCourseReviewPage(controller: controller),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history_edu_outlined),
                  label: const Text('打开原课收藏与复习'),
                ),
              ],
            ),
          ),
        SectionCard(
          title: '本周改变仪表盘',
          child: Row(
            children: [
              Expanded(child: _MetricChip(label: '连续天数', value: '${controller.streakDays}')),
              const SizedBox(width: 8),
              Expanded(child: _MetricChip(label: '已行动概念', value: '${controller.actedConceptCount}')),
              const SizedBox(width: 8),
              Expanded(child: _MetricChip(label: '已内化', value: '${controller.internalizedCount}')),
            ],
          ),
        ),
        if (controller.diagnosisResult != null)
          SectionCard(
            title: '当前诊断建议',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.diagnosisResult!.summary, style: const TextStyle(height: 1.55)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: controller.diagnosisResult!.recommendedConceptIds.map((id) {
                    final concept = controller.conceptById(id);
                    return ActionChip(
                      label: Text(concept.title),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeConceptDetailPage(
                              controller: controller,
                              concept: concept,
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                )
              ],
            ),
          ),
        if (controller.recommendedTaskNow != null)
          SectionCard(
            title: 'AI 教练建议',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.coachDailyBrief, style: const TextStyle(height: 1.55)),
                const SizedBox(height: 12),
                Text(
                  '推荐动作：${controller.recommendedTaskNow!.task.title}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(controller.recommendedTaskNow!.reason),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeAiCoachPage(controller: controller),
                      ),
                    );
                  },
                  child: const Text('打开 AI 教练'),
                ),
              ],
            ),
          ),

        if (controller.latestCompletionRewardEvent != null)
          SectionCard(
            title: '完整世界完成奖励',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.rewardFeedNarrative(controller.latestCompletionRewardEvent!),
                  style: const TextStyle(height: 1.55),
                ),
                const SizedBox(height: 10),
                Text(
                  controller.nextMainlineSummaryForWorld(controller.latestCompletionRewardEvent!.worldId),
                  style: const TextStyle(color: Color(0xFF6A6175), height: 1.45),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeWorldAchievementPage(
                              controller: controller,
                              worldId: controller.latestCompletionRewardEvent!.worldId,
                            ),
                          ),
                        );
                      },
                      child: const Text('查看世界成就页'),
                    ),
                    FilledButton(
                      onPressed: () {
                        controller.generateWeeklyPlanFromWorldCompletion(controller.latestCompletionRewardEvent!.worldId);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已基于完整世界奖励生成新的下一周计划。')));
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeWeeklyPlanPage(controller: controller),
                          ),
                        );
                      },
                      child: const Text('生成下一周计划'),
                    ),
                  ],
                ),
              ],
            ),
          ),

        SectionCard(
          title: '连续成长旅程',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(controller.growthJourneySummary, style: const TextStyle(height: 1.55)),
              const SizedBox(height: 12),
              if (controller.completedWorlds.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: controller.completedWorlds.take(3).map((world) => Chip(
                    backgroundColor: const Color(0xFFEFF8F1),
                    label: Text('已点亮 · ${world.title}'),
                  )).toList(),
                ),
                const SizedBox(height: 12),
              ],
              ...controller.recentJourneyItems(limit: 4).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (item.worldId != null && item.worldId!.isNotEmpty) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MirrorWorldScenePage(controller: controller, worldId: item.worldId!),
                        ),
                      );
                      return;
                    }
                    if (item.conceptId != null && item.conceptId!.isNotEmpty) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeConceptDetailPage(
                            controller: controller,
                            concept: controller.conceptById(item.conceptId!),
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE7E2F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(item.message, style: const TextStyle(height: 1.45, color: Color(0xFF5F6470))),
                      ],
                    ),
                  ),
                ),
              )),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeGrowthTimelinePage(controller: controller),
                        ),
                      );
                    },
                    child: const Text('打开成长时间线'),
                  ),
                  if (controller.completedWorldCount > 0)
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MirrorWorldPage(controller: controller),
                          ),
                        );
                      },
                      child: Text('查看已点亮世界（${controller.completedWorldCount}）'),
                    ),
                ],
              ),
            ],
          ),
        ),

        if (priorityMission != null)
          SectionCard(
            title: '世界主线推进',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${controller.worldById(priorityMission.worldId).title} · 阶段 ${priorityMission.stageNo}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(priorityMission.title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5E6270))),
                const SizedBox(height: 6),
                Text(controller.missionUnlockBanner(priorityMission), style: const TextStyle(height: 1.55)),
                const SizedBox(height: 8),
                Text(
                  controller.worldMissionProgressText(priorityMission.id),
                  style: const TextStyle(color: Color(0xFF7A6177)),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.nextMainlineSummary,
                  style: const TextStyle(color: Color(0xFF7A6177), height: 1.45),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MirrorWorldScenePage(
                              controller: controller,
                              worldId: priorityMission.worldId,
                            ),
                          ),
                        );
                      },
                      child: const Text('进入当前世界主线'),
                    ),
                    if (controller.worldPriorityRecommendation != null)
                      OutlinedButton(
                        onPressed: () {
                          final rec = controller.worldPriorityRecommendation!;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChangeConceptDetailPage(
                                controller: controller,
                                concept: rec.concept,
                                initialTaskId: rec.task.id,
                              ),
                            ),
                          );
                        },
                        child: const Text('去做主线推荐动作'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (recentRewards.isNotEmpty)
          SectionCard(
            title: controller.unseenRewardCount > 0 ? '最近奖励事件流 · ${controller.unseenRewardCount} 条未读' : '最近奖励事件流',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...recentRewards.map((event) {
                  final unseen = controller.seenRewardEventIds.contains(event.id) == false;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: unseen ? const Color(0xFFF7F2FF) : const Color(0xFFF9F7FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: unseen ? const Color(0xFFD8C7FF) : const Color(0xFFE6E0F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                            if (unseen)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE9DDFF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text('新奖励', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6D3EF0))),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(controller.rewardFeedNarrative(event), style: const TextStyle(height: 1.5)),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeGrowthTimelinePage(controller: controller),
                          ),
                        );
                      },
                      child: const Text('打开成长时间线'),
                    ),
                    if (controller.unseenRewardCount > 0)
                      OutlinedButton(
                        onPressed: controller.markAllRewardEventsSeen,
                        child: const Text('全部标为已读'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (controller.currentWeeklyPlan != null)
          SectionCard(
            title: '本周计划引擎',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.weeklyPlanSummary, style: const TextStyle(height: 1.55)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('今日待做 ${controller.todayTaskInstances.where((e) => e.isOpen).length}')),
                    Chip(label: Text('失败待重启 ${controller.restartQueueCount}')),
                    Chip(label: Text('本周计划 ${controller.weeklyTaskInstances.length}')),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeWeeklyPlanPage(controller: controller),
                      ),
                    );
                  },
                  child: const Text('打开本周计划'),
                ),
              ],
            ),
          ),
        if (controller.dueReminderCount > 0)
          SectionCard(
            title: '提醒与跟进',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('你当前有 ${controller.dueReminderCount} 条已到期提醒，优先处理它们能让计划—执行—跟进闭环更完整。', style: const TextStyle(height: 1.55)),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeReminderCenterPage(controller: controller),
                      ),
                    );
                  },
                  child: const Text('打开提醒中心'),
                ),
              ],
            ),
          ),
        SectionCard(
          title: '本周行动概览',
          child: Row(
            children: [
              Expanded(child: _MetricChip(label: '今日动作', value: '${controller.todayActionCount}')),
              const SizedBox(width: 8),
              Expanded(child: _MetricChip(label: '本周动作', value: '${controller.weeklyActionCount}')),
              const SizedBox(width: 8),
              Expanded(child: _MetricChip(label: '平均缓解', value: controller.averageReliefScore.toStringAsFixed(1))),
            ],
          ),
        ),
        SectionCard(
          title: pinned == null ? '今日最重要的一件事' : '当前钉住概念',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((pinned ?? today.first).title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Text((pinned ?? today.first).oneLineSummary),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeConceptDetailPage(
                            controller: controller,
                            concept: pinned ?? today.first,
                          ),
                        ),
                      );
                    },
                    child: const Text('开始今天的概念与行动'),
                  ),
                  if (pinned != null)
                    OutlinedButton(
                      onPressed: controller.clearPin,
                      child: const Text('取消钉住'),
                    ),
                ],
              )
            ],
          ),
        ),
        SectionCard(
          title: '模块路径',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              Chip(label: Text('改变总览')),
              Chip(label: Text('问题诊断')),
              Chip(label: Text('19张概念卡')),
              Chip(label: Text('现实任务')),
              Chip(label: Text('复盘中心')),
              Chip(label: Text('镜像世界')),
              Chip(label: Text('成长画像')),
            ],
          ),
        ),
        if (controller.recentTaskRuns.isNotEmpty)
          SectionCard(
            title: '最近行动记录',
            child: Column(
              children: controller.recentTaskRuns.take(3).map((run) {
                final concept = controller.conceptById(run.conceptId);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(concept.title),
                  subtitle: Text(run.actionText.isEmpty ? run.taskId : run.actionText),
                  trailing: Text('${run.beforeScore}→${run.afterScore}'),
                );
              }).toList(),
            ),
          ),
        SectionCard(
          title: '推荐优先概念',
          child: Column(
            children: today.map((concept) {
              final progress = controller.progressById(concept.id);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(concept.title),
                subtitle: Text(concept.problemSolved),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Icon(Icons.chevron_right),
                    Text(
                      _statusText(progress.status),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF676B74)),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeConceptDetailPage(
                        controller: controller,
                        concept: concept,
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _statusText(ConceptStatus status) {
    switch (status) {
      case ConceptStatus.unread:
        return '未进入';
      case ConceptStatus.read:
        return '已阅读';
      case ConceptStatus.acted:
        return '已行动';
      case ConceptStatus.internalized:
        return '已内化';
    }
  }
}

class _ConceptTab extends StatelessWidget {
  const _ConceptTab({required this.controller});

  final ChangeLabController controller;

  static const moduleNames = {
    'foundation': '基础逻辑',
    'resistance': '阻力与框架',
    'affect': '情绪路径',
    'behavior': '行为路径',
  };

  String _statusText(ConceptStatus status) {
    switch (status) {
      case ConceptStatus.unread:
        return '未进入';
      case ConceptStatus.read:
        return '已阅读';
      case ConceptStatus.acted:
        return '已行动';
      case ConceptStatus.internalized:
        return '已内化';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: moduleNames.entries.map((entry) {
        final concepts = controller.conceptsByModule(entry.key);
        final actedCount = concepts
            .where((c) => controller.progressById(c.id).status.index >= ConceptStatus.acted.index)
            .length;
        return SectionCard(
          title: entry.value,
          trailing: Chip(label: Text('$actedCount/${concepts.length}')),
          child: Column(
            children: concepts.map((concept) {
              final progress = controller.progressById(concept.id);
              final isPinned = controller.pinnedConceptId == concept.id;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Expanded(child: Text(concept.title)),
                    if (isPinned)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7E8FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('已钉住', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                subtitle: Text(concept.oneLineSummary),
                trailing: Chip(label: Text(_statusText(progress.status))),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeConceptDetailPage(
                        controller: controller,
                        concept: concept,
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F8FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E0F0)),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B6F78))),
        ],
      ),
    );
  }
}
