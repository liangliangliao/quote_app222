import 'package:flutter/material.dart';

import '../controllers/change_lab_controller.dart';
import '../data/change_course_full_content.dart';
import '../models/change_models.dart';
import 'change_course_review_page.dart';
import 'widgets/section_card.dart';

class ChangeConceptDetailPage extends StatefulWidget {
  const ChangeConceptDetailPage({
    super.key,
    required this.controller,
    required this.concept,
    this.initialTaskId,
  });

  final ChangeLabController controller;
  final ChangeConcept concept;
  final String? initialTaskId;

  @override
  State<ChangeConceptDetailPage> createState() => _ChangeConceptDetailPageState();
}

class _ChangeConceptDetailPageState extends State<ChangeConceptDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<String> _splitBlocks(String text) {
    return text
        .split(RegExp(r'\n\s*\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> _highlightTokens(ChangeCourseFullEntry? entry) {
    if (entry == null) return [widget.concept.oneLineSummary];
    final merged = entry.keyPoint.replaceAll('；', '，').replaceAll('：', '，');
    final parts = merged
        .split(RegExp(r'[，。]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return (parts.isEmpty ? [entry.keyPoint] : parts).take(4).toList();
  }

  Widget _highlightWrap(ChangeCourseFullEntry? entry) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _highlightTokens(entry)
          .map(
            (token) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF2ECFF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFD8CBFF)),
              ),
              child: Text(token, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          )
          .toList(),
    );
  }

  Widget _readingBlock({required String title, required String body, Color? color, Color? borderColor}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? const Color(0xFFEAE7F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6A6175))),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.75)),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    if (widget.initialTaskId != null) {
      _tabController.index = 4;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.markConceptRead(widget.concept.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _completeTask(BuildContext context, ChangeTask task) async {
    final input = TextEditingController();
    final beforeController = TextEditingController();
    final afterController = TextEditingController();
    double beforeScore = 3;
    double afterScore = 3;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('完成：${task.title}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(task.summary, style: const TextStyle(color: Color(0xFF666A73))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: beforeController,
                    decoration: const InputDecoration(
                      labelText: '行动前我最担心/最卡住的是什么？',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  Text('行动前主观压力：${beforeScore.round()}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Slider(
                    value: beforeScore,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '${beforeScore.round()}',
                    onChanged: (v) => setSheetState(() => beforeScore = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: input,
                    decoration: const InputDecoration(
                      labelText: '我这次真正做了什么？',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 3,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: afterController,
                    decoration: const InputDecoration(
                      labelText: '行动后，我学到了什么 / 下次如何做小一点？',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  Text('行动后主观压力：${afterScore.round()}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Slider(
                    value: afterScore,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '${afterScore.round()}',
                    onChanged: (v) => setSheetState(() => afterScore = v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(context, {
                              'beforeText': beforeController.text.trim(),
                              'actionText': input.text.trim(),
                              'afterText': afterController.text.trim(),
                              'beforeScore': beforeScore.round(),
                              'afterScore': afterScore.round(),
                            });
                          },
                          child: const Text('提交记录'),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        });
      },
    );
    if (result != null) {
      widget.controller.completeTask(
        conceptId: widget.concept.id,
        taskId: task.id,
        beforeText: (result['beforeText'] ?? '').toString(),
        actionText: (result['actionText'] ?? '').toString(),
        afterText: (result['afterText'] ?? '').toString(),
        beforeScore: (result['beforeScore'] as num?)?.toInt() ?? 3,
        afterScore: (result['afterScore'] as num?)?.toInt() ?? 3,
      );
      if (context.mounted) {
        final latest = widget.controller.lastTaskRunForConcept(widget.concept.id);
        final base = latest == null ? '已记录你的行动与复盘。' : widget.controller.coachSuccessMessage(latest);
        final milestone = widget.controller.latestMilestoneMessage;
        final message = milestone == null || milestone.isEmpty ? base : '$base\n$milestone';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
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

  String _taskTypeLabel(TaskType type) {
    switch (type) {
      case TaskType.light:
        return '轻任务';
      case TaskType.main:
        return '主任务';
      case TaskType.challenge:
        return '挑战';
      case TaskType.fallback:
        return '降级';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final progress = widget.controller.progressById(widget.concept.id);
        final fullContent = changeCourseFullContent[widget.concept.id];
        final relatedIds = widget.controller.relatedConceptIds(widget.concept.id);
        final reflections = widget.controller.reflectionsForConcept(widget.concept.id).take(3).toList();
        final taskRuns = widget.controller.taskRunsForConcept(widget.concept.id).take(5).toList();
        return Scaffold(
          backgroundColor: const Color(0xFFF4F2F8),
          appBar: AppBar(
            title: Text(widget.concept.title),
            backgroundColor: const Color(0xFFF4F2F8),
            actions: [
              IconButton(
                tooltip: '原课收藏与复习',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeCourseReviewPage(controller: widget.controller),
                    ),
                  );
                },
                icon: const Icon(Icons.bookmarks_outlined),
              ),
              IconButton(
                tooltip: '钉住当前概念',
                onPressed: () {
                  widget.controller.pinConcept(widget.concept.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已钉住到首页与任务中心。')),
                  );
                },
                icon: const Icon(Icons.push_pin_outlined),
              )
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: '概念'),
                Tab(text: '意义'),
                Tab(text: '原课'),
                Tab(text: '案例'),
                Tab(text: '行动'),
                Tab(text: '复盘'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SectionCard(
                    title: '一句话摘要',
                    trailing: Chip(label: Text(_statusText(progress.status))),
                    child: Text(widget.concept.oneLineSummary, style: const TextStyle(height: 1.5)),
                  ),
                  SectionCard(
                    title: '现实中的常见表现',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.concept.commonSigns
                          .map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• '),
                                    Expanded(child: Text(e)),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  SectionCard(
                    title: '关联概念',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: relatedIds.map((id) {
                        final concept = widget.controller.conceptById(id);
                        return ActionChip(
                          label: Text(concept.title),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChangeConceptDetailPage(
                                  controller: widget.controller,
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
              ),
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SectionCard(
                    title: '这张卡帮助你解决什么问题',
                    child: Text(widget.concept.problemSolved, style: const TextStyle(height: 1.6)),
                  ),
                  SectionCard(
                    title: '当前进度',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('状态：${_statusText(progress.status)}'),
                        const SizedBox(height: 8),
                        Text('行动次数：${progress.actionCount}'),
                        const SizedBox(height: 4),
                        Text('复盘次数：${progress.reflectionCount}'),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: progress.status == ConceptStatus.unread
                              ? 0
                              : progress.status == ConceptStatus.read
                                  ? 0.33
                                  : progress.status == ConceptStatus.acted
                                      ? 0.66
                                      : 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SectionCard(
                    title: fullContent?.lectureLabel ?? '原课精华',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text(widget.concept.id)),
                            if (fullContent != null) Chip(label: Text(fullContent.lectureLabel)),
                            Chip(label: Text(widget.controller.isConceptInWeeklyLearning(widget.concept.id) ? '已加入本周学习' : '未加入本周学习')),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2ECFF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(fullContent?.keyPoint ?? widget.concept.courseEssence, style: const TextStyle(height: 1.65, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 10),
                        _highlightWrap(fullContent),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () {
                                  widget.controller.addConceptToWeeklyLearning(widget.concept.id, source: '概念页原课阅读');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('已把「${widget.concept.title}」加入本周学习。')),
                                  );
                                },
                                icon: const Icon(Icons.playlist_add_check_circle_outlined),
                                label: const Text('加入本周学习'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final task = widget.controller.recommendedTaskForConcept(widget.concept.id);
                                  _tabController.animateTo(4);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('已为你定位到推荐动作：${task.title}')),
                                  );
                                },
                                icon: const Icon(Icons.task_alt_outlined),
                                label: const Text('去做推荐动作'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SectionCard(
                    title: '简化直译 / 原课展开',
                    child: Column(
                      children: _splitBlocks(fullContent?.fullText ?? widget.concept.courseEssence)
                          .asMap()
                          .entries
                          .map((entry) => _readingBlock(title: '原课分段 ${entry.key + 1}', body: entry.value))
                          .toList(),
                    ),
                  ),
                  SectionCard(
                    title: '原课—案例—行动提示',
                    child: Text('不要只把原课内容看成知识点。建议按“先读原课分段 → 再看案例 → 再做任务”的顺序使用。当前最适合的下一步，是把这张卡至少转成一次现实动作。', style: const TextStyle(height: 1.6)),
                  )
                ],
              ),
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SectionCard(
                    title: '课程案例原文整理',
                    child: Column(
                      children: _splitBlocks(fullContent?.caseText.isNotEmpty == true ? fullContent!.caseText : widget.concept.classicCase)
                          .asMap()
                          .entries
                          .map((entry) => _readingBlock(
                                title: '案例卡片 ${entry.key + 1}',
                                body: entry.value,
                                color: const Color(0xFFFFFBF2),
                                borderColor: const Color(0xFFF0E6C9),
                              ))
                          .toList(),
                    ),
                  ),
                  if (fullContent != null)
                    SectionCard(
                      title: '产品化案例摘要',
                      child: Text(widget.concept.classicCase, style: const TextStyle(height: 1.6)),
                    ),
                  SectionCard(
                    title: '概念—案例—行动',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '先问自己：这张卡的案例，在我生活里最像哪一幕？再回到“行动”页签，至少完成一个与该案例最相似的现实动作。',
                          style: TextStyle(height: 1.6),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _highlightTokens(fullContent)
                              .map((e) => Chip(label: Text(e)))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SectionCard(
                    title: '今日行动任务',
                    child: Column(
                      children: widget.concept.tasks
                          .map(
                            (task) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9F8FD),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE6E0F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(task.title,
                                            style: const TextStyle(fontWeight: FontWeight.w700)),
                                      ),
                                      Chip(label: Text(_taskTypeLabel(task.type))),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(task.summary),
                                  const SizedBox(height: 8),
                                  Text(
                                    task.instructions,
                                    style:
                                        const TextStyle(color: Color(0xFF555A66), height: 1.45),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '失败时降级：${task.fallbackHint}',
                                    style: const TextStyle(color: Color(0xFF7A6177)),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      FilledButton.tonal(
                                        onPressed: () => _completeTask(context, task),
                                        child: const Text('完成并记录'),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${task.estimatedMinutes} 分钟'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SectionCard(
                    title: '最近任务记录',
                    child: taskRuns.isEmpty
                        ? const Text('完成任意一个任务后，这里会自动出现你的行动记录。')
                        : Column(
                            children: taskRuns.map((run) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(run.taskId),
                                subtitle: Text(run.combinedReflection),
                                trailing: Text('${run.beforeScore}→${run.afterScore}'),
                              );
                            }).toList(),
                          ),
                  ),
                  if (reflections.isNotEmpty)
                    SectionCard(
                      title: '最近复盘摘录',
                      child: Column(
                        children: reflections.map((entry) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(entry.taskId),
                            subtitle: Text(entry.text),
                            trailing: Text('${entry.createdAt.month}/${entry.createdAt.day}'),
                          );
                        }).toList(),
                      ),
                    ),
                  const SectionCard(
                    title: '复盘提示',
                    child: Text('每次至少回答三个问题：我做之前在担心什么？我这次真正做了什么？下次我如何把动作做小一点但不断线？'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
