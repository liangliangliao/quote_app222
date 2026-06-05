import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'goal_concept_detail_page.dart';
import 'goal_module_review_page.dart';
import 'goal_dao.dart';
import 'goal_models.dart';
import 'goal_study_progress_page.dart';
import 'goal_workshop_page.dart';

class GoalSegmentDetailPage extends StatefulWidget {
  final String segmentId;
  const GoalSegmentDetailPage({super.key, required this.segmentId});

  @override
  State<GoalSegmentDetailPage> createState() => _GoalSegmentDetailPageState();
}

class _GoalSegmentDetailPageState extends State<GoalSegmentDetailPage> {
  final _dao = GoalDao();
  late Future<_SegmentBundle> _future;
  final _scrollController = ScrollController();
  Timer? _saveTimer;
  bool _restoreChecked = false;
  bool _ritualChecked = false;
  String _currentTitle = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scheduleSavePosition);
    _future = _load(markViewed: true);
  }

  Future<_SegmentBundle> _load({bool markViewed = false}) async {
    if (markViewed) {
      await _dao.touchSegmentReviewed(widget.segmentId);
    }
    final segment = await _dao.getSegment(widget.segmentId);
    if (segment == null) throw Exception('内容不存在');
    final review = await _dao.getSegmentReview(widget.segmentId);
    final concepts = await _dao.listConceptCardsForSegment(widget.segmentId);
    return _SegmentBundle(segment: segment, review: review, concepts: concepts);
  }

  void _scheduleSavePosition() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () { _persistPosition(); });
  }

  Future<void> _persistPosition() async {
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    await _dao.saveContinueState(
      stateKey: 'last_learning',
      targetId: widget.segmentId,
      scrollOffset: offset,
      extra: {'title': _currentTitle, 'segment_id': widget.segmentId},
    );
  }

  Future<void> _restorePositionIfNeeded() async {
    if (_restoreChecked) return;
    _restoreChecked = true;
    final state = await _dao.getContinueState('last_learning');
    if (!mounted || state.targetId != widget.segmentId) return;
    final offset = state.scrollOffset;
    if (offset <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      final target = offset.clamp(0.0, max);
      _scrollController.jumpTo(target);
    });
  }

  Future<void> _toggleReview(_SegmentBundle bundle, {bool? favorite, bool? difficult, bool? key}) async {
    await _dao.saveSegmentReview(
      segmentId: bundle.segment.segmentId,
      isFavorited: favorite ?? bundle.review.isFavorited,
      isDifficult: difficult ?? bundle.review.isDifficult,
      isKey: key ?? bundle.review.isKey,
    );
    if (!mounted) return;
    setState(() => _future = _load());
  }


  Future<void> _checkCompletionRitualIfNeeded(GoalCourseSegment segment) async {
    if (_ritualChecked) return;
    _ritualChecked = true;
    final ritual = await _dao.getPendingModuleCompletionRitual(segment.segmentId);
    if (!mounted || ritual == null) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompletionRitualSheet(ritual: ritual),
    );

    await _dao.markCompletionRitualShown(ritual.ritualKey);
    if (!mounted) return;

    if (choice == 'concept' && ritual.nextConceptId != null) {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => GoalConceptDetailPage(conceptId: ritual.nextConceptId!)),
      );
      return;
    }
    if (choice == 'segment' && ritual.nextSegmentId != null) {
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => GoalSegmentDetailPage(segmentId: ritual.nextSegmentId!)),
      );
      return;
    }
    if (choice == 'review') {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => GoalModuleReviewPage(
            sourceCourse: ritual.sourceCourse,
            moduleGroup: ritual.moduleGroup,
          ),
        ),
      );
      return;
    }
    if (choice == 'workshop') {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const GoalWorkshopPage(entryNote: '你刚完成了一组课程主题，适合把收获转回目标工坊。')),
      );
      return;
    }
    if (choice == 'progress') {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const GoalStudyProgressPage()),
      );
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _persistPosition();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('课程原文')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<_SegmentBundle>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(child: Text(snap.error?.toString() ?? '内容不存在'));
          }
          final bundle = snap.data!;
          final s = bundle.segment;
          final review = bundle.review;
          _currentTitle = s.sectionTitle;
          _restorePositionIfNeeded();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkCompletionRitualIfNeeded(s);
          });
          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(s.sourceCourseName),
                        _chip('第${s.segmentNo}段'),
                        _chip(s.moduleGroup),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(s.sectionTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    if (s.tags.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (final t in s.tags) _chip(t, dark: false)],
                      ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _toggleChip(
                          label: review.isFavorited ? '已收藏' : '收藏',
                          selected: review.isFavorited,
                          icon: review.isFavorited ? Icons.favorite : Icons.favorite_border,
                          onTap: () => _toggleReview(bundle, favorite: !review.isFavorited),
                        ),
                        _toggleChip(
                          label: review.isDifficult ? '已标难点' : '标记难点',
                          selected: review.isDifficult,
                          icon: Icons.help_outline,
                          onTap: () => _toggleReview(bundle, difficult: !review.isDifficult),
                        ),
                        _toggleChip(
                          label: review.isKey ? '已标重点' : '标记重点',
                          selected: review.isKey,
                          icon: Icons.push_pin_outlined,
                          onTap: () => _toggleReview(bundle, key: !review.isKey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SelectableText(
                      s.segmentText,
                      style: const TextStyle(fontSize: 16, height: 1.75, color: Color(0xFF1F2937)),
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
                    const Text('关联概念实践', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('原课程正文保持原样，下面这些概念卡会围绕它做解释、互动和现实行动。', style: TextStyle(height: 1.6, color: Color(0xFF4B5563))),
                    const SizedBox(height: 12),
                    if (bundle.concepts.isEmpty)
                      const Text('暂未找到关联概念。')
                    else
                      ...bundle.concepts.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Navigator.of(context).push(
                                  CupertinoPageRoute(builder: (_) => GoalConceptDetailPage(conceptId: c.conceptId)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.lightbulb_outline, color: Color(0xFF111827)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(c.conceptTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                                            const SizedBox(height: 4),
                                            Text(c.oneLineDefinition, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6B7280), height: 1.4)),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String text, {bool dark = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: dark ? Colors.white : const Color(0xFF374151),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _toggleChip({required String label, required bool selected, required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: selected ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : const Color(0xFF374151)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF374151), fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}


class _CompletionRitualSheet extends StatelessWidget {
  final GoalCompletionRitual ritual;
  const _CompletionRitualSheet({required this.ritual});

  @override
  Widget build(BuildContext context) {
    final primaryAction = ritual.nextConceptId != null
        ? 'concept'
        : (ritual.nextSegmentId != null ? 'segment' : 'workshop');
    final primaryLabel = ritual.nextConceptId != null
        ? '进入下一步概念'
        : (ritual.nextSegmentId != null ? '继续下一主题' : '回到目标工坊');

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.celebration_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('章节完成仪式', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                      const SizedBox(height: 2),
                      Text(ritual.summaryTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ritualChip(ritual.sourceCourseName),
                _ritualChip(ritual.moduleGroup),
                _ritualChip('已复习 ${ritual.reviewedCount}/${ritual.totalCount}'),
              ],
            ),
            const SizedBox(height: 14),
            Text(ritual.summaryText, style: const TextStyle(height: 1.7, color: Color(0xFF374151))),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('推荐下一步', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(ritual.nextTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(ritual.nextSubtitle, style: const TextStyle(height: 1.6, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop('review'),
                    child: const Text('写主题复盘'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(primaryAction),
                    child: Text(primaryLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop('progress'),
                child: const Text('看学习进度'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ritualChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
        ),
      );
}

class _SegmentBundle {
  final GoalCourseSegment segment;
  final GoalSegmentReview review;
  final List<GoalConceptCard> concepts;
  _SegmentBundle({required this.segment, required this.review, required this.concepts});
}
