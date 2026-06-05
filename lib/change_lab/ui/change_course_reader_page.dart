import 'package:flutter/material.dart';

import '../controllers/change_lab_controller.dart';
import '../data/change_course_full_content.dart';
import 'change_concept_detail_page.dart';
import 'change_course_review_page.dart';
import 'change_weekly_plan_page.dart';
import 'widgets/section_card.dart';

class ChangeCourseReaderPage extends StatelessWidget {
  const ChangeCourseReaderPage({super.key, required this.controller});

  final ChangeLabController controller;

  List<String> _paragraphs(String text) {
    return text
        .split(RegExp(r'\n\s*\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> _highlightTokens(ChangeCourseFullEntry entry) {
    final merged = entry.keyPoint.replaceAll('；', '，').replaceAll('：', '，');
    final tokens = merged
        .split(RegExp(r'[，。]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return [entry.keyPoint];
    return tokens.take(4).toList();
  }

  Widget _highlightWrap(ChangeCourseFullEntry entry) {
    final tokens = _highlightTokens(entry);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tokens
          .map(
            (token) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF2ECFF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFD8CBFF)),
              ),
              child: Text(
                token,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _editParagraphNote(
    BuildContext context, {
    required String conceptId,
    required String sectionType,
    required int index,
    required String blockTitle,
  }) async {
    final noteController = TextEditingController(
      text: controller.paragraphNote(conceptId, sectionType, index),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑笔记 · $blockTitle'),
        content: TextField(
          controller: noteController,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '写下这一段最触动你的地方、疑问，或想转成行动的提醒。',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('清空'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(noteController.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null) {
      controller.saveParagraphNote(conceptId, sectionType, index, result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存这段原课笔记。')),
        );
      }
    }
  }

  Widget _paragraphActionChips(
    BuildContext context, {
    required String conceptId,
    required String sectionType,
    required int index,
    required String blockTitle,
  }) {
    final isFavorite = controller.isParagraphFavorite(conceptId, sectionType, index);
    final inReview = controller.isParagraphInReviewList(conceptId, sectionType, index);
    final hasNote = controller.paragraphNote(conceptId, sectionType, index).trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              selected: isFavorite,
              label: const Text('收藏'),
              onSelected: (_) => controller.toggleParagraphFavorite(conceptId, sectionType, index),
            ),
            FilterChip(
              selected: inReview,
              label: const Text('加入复习清单'),
              onSelected: (_) => controller.toggleParagraphReviewList(conceptId, sectionType, index),
            ),
            ActionChip(
              label: Text(hasNote ? '编辑笔记' : '写笔记'),
              onPressed: () => _editParagraphNote(
                context,
                conceptId: conceptId,
                sectionType: sectionType,
                index: index,
                blockTitle: blockTitle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (isFavorite) const Chip(label: Text('已收藏')),
            if (inReview) const Chip(label: Text('复习清单')),
            if (hasNote) const Chip(label: Text('有笔记')),
          ],
        ),
      ],
    );
  }

  Widget _readingBlock(
    BuildContext context, {
    required String conceptId,
    required String sectionType,
    required int index,
    required String title,
    required String body,
    Color? color,
    Color? borderColor,
  }) {
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
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6A6175)),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.75)),
          const SizedBox(height: 10),
          _paragraphActionChips(
            context,
            conceptId: conceptId,
            sectionType: sectionType,
            index: index,
            blockTitle: title,
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, String title, List<String> ids) {
    return SectionCard(
      title: title,
      child: Column(
        children: ids.map((id) {
          final entry = changeCourseFullContent[id]!;
          final concept = controller.conceptById(id);
          final recommendedTask = controller.recommendedTaskForConcept(id);
          final existingInstance = controller.recommendedOpenInstanceForConcept(id);
          final paras = _paragraphs(entry.fullText);
          final caseParas = _paragraphs(entry.caseText);
          final inWeekly = controller.isConceptInWeeklyLearning(id);
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F8FD),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE6E0F0)),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              title: Text(concept.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(entry.lectureLabel),
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2ECFF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    entry.keyPoint,
                    style: const TextStyle(height: 1.6, fontWeight: FontWeight.w600),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(id)),
                      Chip(label: Text(entry.lectureLabel)),
                      Chip(label: Text(inWeekly ? '已加入本周学习' : '未加入本周学习')),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _highlightWrap(entry),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEAE7F2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '概念—案例—行动三联动',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '建议顺序：先读 ${paras.length} 段原课，再看 ${caseParas.isEmpty ? 0 : caseParas.length} 张案例卡，最后完成「${recommendedTask.title}」。',
                        style: const TextStyle(height: 1.65),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        existingInstance != null
                            ? '当前已有挂接任务实例，适合直接继续执行。'
                            : '系统已为这一段原课匹配推荐动作，可直接把阅读转成现实证据。',
                        style: const TextStyle(color: Color(0xFF6A6175), height: 1.55),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...paras.asMap().entries.map(
                      (kv) => _readingBlock(
                        context,
                        conceptId: id,
                        sectionType: 'full',
                        index: kv.key,
                        title: '原课分段 ${kv.key + 1}',
                        body: kv.value,
                      ),
                    ),
                if (caseParas.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('案例与补充', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  ...caseParas.asMap().entries.map(
                    (entryCase) => _readingBlock(
                      context,
                      conceptId: id,
                      sectionType: 'case',
                      index: entryCase.key,
                      title: '案例卡片 ${entryCase.key + 1}',
                      body: entryCase.value,
                      color: const Color(0xFFFFFBF2),
                      borderColor: const Color(0xFFF0E6C9),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FCF7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD4E8D1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              existingInstance != null ? '继续今日动作' : '推荐动作：${recommendedTask.title}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Chip(label: Text('${recommendedTask.estimatedMinutes} 分钟')),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(recommendedTask.summary, style: const TextStyle(height: 1.55)),
                      const SizedBox(height: 6),
                      Text(
                        '失败时可降级为：${recommendedTask.fallbackHint}',
                        style: const TextStyle(color: Color(0xFF5D6D5C), height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          controller.addConceptToWeeklyLearning(id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已把「${concept.title}」加入本周学习。')),
                          );
                        },
                        icon: const Icon(Icons.playlist_add_check_circle_outlined),
                        label: Text(inWeekly ? '已加入本周学习' : '加入本周学习'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChangeConceptDetailPage(
                                controller: controller,
                                concept: concept,
                                initialTaskId: recommendedTask.id,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.task_alt_outlined),
                        label: Text(existingInstance != null ? '继续推荐动作' : '去做推荐动作'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
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
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('进入概念页'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lecture9 = changeCourseOrderedConceptIds.where((e) => int.parse(e.substring(1)) <= 6).toList();
    final lecture10 = changeCourseOrderedConceptIds.where((e) => int.parse(e.substring(1)) >= 7).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F8),
      appBar: AppBar(
        title: const Text('原课全景阅读'),
        backgroundColor: const Color(0xFFF4F2F8),
        actions: [
          IconButton(
            tooltip: '打开原课收藏与复习',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChangeCourseReviewPage(controller: controller),
                ),
              );
            },
            icon: const Icon(Icons.bookmarks_outlined),
          ),
          IconButton(
            tooltip: '打开本周计划',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChangeWeeklyPlanPage(controller: controller),
                ),
              );
            },
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionCard(
            title: '阅读说明',
            child: Text(
              '这里按 Lecture 9 后半与 Lecture 10 的原顺序，集中呈现“改变”主题的完整课程内容。每个单元都保留了要点、简化直译和案例说明。现在你还可以把任意一段原课直接加入本周学习，并自动挂接推荐动作。',
              style: TextStyle(height: 1.65),
            ),
          ),
          SectionCard(
            title: '原课重点收藏与复习',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '现在你可以逐段收藏、逐段写笔记、逐段加入复习清单。这样原课阅读不只是一次性浏览，而会变成长期学习入口。',
                  style: TextStyle(height: 1.65),
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
                FilledButton.tonalIcon(
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
          ),
          SectionCard(
            title: '原课—案例—行动使用法',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('建议按这条顺序使用课程内容：', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  '1. 先读原课分段，把课程脉络真正看明白。\n2. 再看案例卡片，确认它在现实里长什么样。\n3. 最后把这一段加入本周学习，并立刻去做挂接的现实动作。',
                  style: TextStyle(height: 1.65),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeWeeklyPlanPage(controller: controller),
                      ),
                    );
                  },
                  icon: const Icon(Icons.playlist_add_check_circle_outlined),
                  label: const Text('打开本周学习与任务计划'),
                ),
              ],
            ),
          ),
          const SectionCard(
            title: '总收束',
            child: Text(changeCourseClosingSummary, style: TextStyle(height: 1.65)),
          ),
          _buildGroup(context, 'Lecture 9 · Change 导入（6 段）', lecture9),
          _buildGroup(context, 'Lecture 10 · Change 展开（13 段）', lecture10),
        ],
      ),
    );
  }
}
