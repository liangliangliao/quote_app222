import 'package:flutter/material.dart';

import '../controllers/change_lab_controller.dart';
import '../models/change_models.dart';
import 'change_concept_detail_page.dart';
import 'widgets/section_card.dart';

class ChangeCourseReviewPage extends StatelessWidget {
  const ChangeCourseReviewPage({super.key, required this.controller});

  final ChangeLabController controller;

  Future<void> _editNote(BuildContext context, CourseParagraphView view) async {
    final noteController = TextEditingController(text: view.record.note);
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑笔记 · ${view.blockTitle}'),
        content: TextField(
          controller: noteController,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '写下这一段最触动你的地方、疑问，或想放进现实行动的一句话。',
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
    if (saved != null) {
      controller.saveParagraphNote(
        view.record.conceptId,
        view.record.sectionType,
        view.record.paragraphIndex,
        saved,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存这段原课笔记。')),
        );
      }
    }
  }

  Widget _metaChips(CourseParagraphView view) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(label: Text(view.lectureLabel)),
        if (view.record.isFavorite) const Chip(label: Text('已收藏')),
        if (view.record.inReviewList) const Chip(label: Text('复习清单')),
        if (view.record.note.trim().isNotEmpty) const Chip(label: Text('有笔记')),
      ],
    );
  }

  Widget _paragraphCard(BuildContext context, CourseParagraphView view) {
    final concept = controller.conceptById(view.record.conceptId);
    final isReview = view.record.inReviewList;
    final isFavorite = view.record.isFavorite;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E2F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(view.conceptTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(view.blockTitle, style: const TextStyle(color: Color(0xFF6A6175))),
          const SizedBox(height: 8),
          _metaChips(view),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(view.text, style: const TextStyle(height: 1.68)),
          ),
          if (view.record.note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0E6C9)),
              ),
              child: Text(view.record.note, style: const TextStyle(height: 1.6)),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                selected: isFavorite,
                label: const Text('收藏'),
                onSelected: (_) => controller.toggleParagraphFavorite(
                  view.record.conceptId,
                  view.record.sectionType,
                  view.record.paragraphIndex,
                ),
              ),
              FilterChip(
                selected: isReview,
                label: const Text('加入复习清单'),
                onSelected: (_) => controller.toggleParagraphReviewList(
                  view.record.conceptId,
                  view.record.sectionType,
                  view.record.paragraphIndex,
                ),
              ),
              ActionChip(
                label: const Text('编辑笔记'),
                onPressed: () => _editNote(context, view),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
  }

  Widget _buildSection(BuildContext context, {
    required String title,
    required String subtitle,
    required List<CourseParagraphView> items,
  }) {
    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: const TextStyle(color: Color(0xFF6A6175), height: 1.55)),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F7FC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('这里还没有内容。先去原课全景阅读里逐段收藏、写笔记或加入复习清单。'),
            )
          else
            ...items.map((view) => _paragraphCard(context, view)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = controller.favoriteParagraphViews;
    final reviews = controller.reviewParagraphViews;
    final notes = controller.notedParagraphViews;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F8),
      appBar: AppBar(
        title: const Text('原课收藏与复习'),
        backgroundColor: const Color(0xFFF4F2F8),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: '学习入口说明',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '这里把“原课阅读”变成一个长期学习入口。你可以把任意一段原课加入收藏、写下自己的笔记，或加入复习清单，之后再回到概念与行动。',
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
              ],
            ),
          ),
          _buildSection(
            context,
            title: '复习清单',
            subtitle: '适合反复回看、转成现实行动的关键段落。',
            items: reviews,
          ),
          _buildSection(
            context,
            title: '收藏段落',
            subtitle: '你认为值得反复阅读、保留的原课内容。',
            items: favorites,
          ),
          _buildSection(
            context,
            title: '笔记段落',
            subtitle: '带有你自己理解、问题或行动线索的原课笔记。',
            items: notes,
          ),
        ],
      ),
    );
  }
}
