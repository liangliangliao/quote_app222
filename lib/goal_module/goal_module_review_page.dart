import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'goal_action_runner_page.dart';
import 'goal_concept_detail_page.dart';
import 'goal_dao.dart';
import 'goal_models.dart';
import 'goal_module_review_actions.dart';
import 'goal_segment_detail_page.dart';
import 'goal_workshop_page.dart';

class GoalModuleReviewPage extends StatefulWidget {
  final String sourceCourse;
  final String moduleGroup;

  const GoalModuleReviewPage({
    super.key,
    required this.sourceCourse,
    required this.moduleGroup,
  });

  @override
  State<GoalModuleReviewPage> createState() => _GoalModuleReviewPageState();
}

class _GoalModuleReviewPageState extends State<GoalModuleReviewPage> {
  final _dao = GoalDao();
  late Future<_ModuleReviewBundle> _future;
  final _summaryCtl = TextEditingController();
  final _insightCtl = TextEditingController();
  final _actionCtl = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _autosaveTimer;
  bool _hydrated = false;
  bool _saving = false;
  bool _showAllSegments = false;
  bool _restoreChecked = false;
  String _ritualKey = '';
  String _ritualSourceCourse = '';
  String _ritualModuleGroup = '';
  String _ritualSourceCourseName = '';

  @override
  void initState() {
    super.initState();
    _summaryCtl.addListener(_scheduleAutosave);
    _insightCtl.addListener(_scheduleAutosave);
    _actionCtl.addListener(_scheduleAutosave);
    _scrollController.addListener(_scheduleAutosave);
    _future = _load();
  }

  Future<_ModuleReviewBundle> _load() async {
    final ritual = await _dao.getModuleCompletionRitual(
      sourceCourse: widget.sourceCourse,
      moduleGroup: widget.moduleGroup,
    );
    if (ritual == null) {
      throw Exception('当前主题尚未完成，暂时还不能进入主题复盘。');
    }
    final reflection = await _dao.getModuleReflection(
      ritualKey: ritual.ritualKey,
      sourceCourse: ritual.sourceCourse,
      moduleGroup: ritual.moduleGroup,
    );
    final segments = await _dao.listSegments(
      sourceCourse: widget.sourceCourse,
      moduleGroup: widget.moduleGroup,
    );
    final reviewedSegments = <GoalReviewedSegment>[];
    for (final segment in segments) {
      final review = await _dao.getSegmentReview(segment.segmentId);
      reviewedSegments.add(GoalReviewedSegment(segment: segment, review: review));
    }
    return _ModuleReviewBundle(
      ritual: ritual,
      reflection: reflection,
      anchorSegment: segments.isEmpty ? null : segments.first,
      segments: segments,
      reviewedSegments: reviewedSegments,
    );
  }

  void _hydrate(_ModuleReviewBundle bundle) {
    if (_hydrated) return;
    _hydrated = true;
    _summaryCtl.text = bundle.reflection.summaryText;
    _insightCtl.text = bundle.reflection.insightText;
    _actionCtl.text = bundle.reflection.actionText;
  }


  void _bindContinueContext(_ModuleReviewBundle bundle) {
    _ritualKey = bundle.ritual.ritualKey;
    _ritualSourceCourse = bundle.ritual.sourceCourse;
    _ritualModuleGroup = bundle.ritual.moduleGroup;
    _ritualSourceCourseName = bundle.ritual.sourceCourseName;
    _restorePositionIfNeeded();
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    if (_ritualKey.isEmpty) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 350), () {
      _persistContinueState();
    });
  }

  Future<void> _persistContinueState() async {
    if (_ritualKey.isEmpty) return;
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final previewSource = _actionCtl.text.trim().isNotEmpty
        ? _actionCtl.text.trim()
        : (_insightCtl.text.trim().isNotEmpty ? _insightCtl.text.trim() : _summaryCtl.text.trim());
    final preview = previewSource.length > 48 ? '${previewSource.substring(0, 48)}…' : previewSource;
    await _dao.saveContinueState(
      stateKey: 'last_module_review',
      targetId: _ritualKey,
      scrollOffset: offset,
      extra: {
        'sourceCourse': _ritualSourceCourse,
        'moduleGroup': _ritualModuleGroup,
        'sourceCourseName': _ritualSourceCourseName,
        'title': _ritualModuleGroup,
        'preview': preview,
      },
    );
  }

  Future<void> _restorePositionIfNeeded() async {
    if (_restoreChecked || _ritualKey.isEmpty) return;
    _restoreChecked = true;
    final state = await _dao.getContinueState('last_module_review');
    if (!mounted || state.targetId != _ritualKey) return;
    final offset = state.scrollOffset;
    if (offset <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      final target = offset.clamp(0.0, max);
      _scrollController.jumpTo(target);
    });
  }

  Future<void> _save(_ModuleReviewBundle bundle, {bool showSnack = true}) async {
    setState(() => _saving = true);
    await _dao.saveModuleReflection(
      ritualKey: bundle.ritual.ritualKey,
      sourceCourse: bundle.ritual.sourceCourse,
      moduleGroup: bundle.ritual.moduleGroup,
      summaryText: _summaryCtl.text.trim(),
      insightText: _insightCtl.text.trim(),
      actionText: _actionCtl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    await _persistContinueState();
    if (showSnack) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('主题复盘已保存')),
      );
    }
  }

  Future<void> _saveAndRunAction(_ModuleReviewBundle bundle, GoalModuleReviewActionDraft draft) async {
    await _save(bundle, showSnack: false);
    if (!mounted) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => GoalActionRunnerPage(
          action: draft.action,
          conceptTitle: draft.conceptTitle,
          segmentTitle: draft.segmentTitle,
        ),
      ),
    );
  }

  Future<void> _toggleSegmentReview(GoalReviewedSegment item, {bool? favorite, bool? difficult, bool? key}) async {
    await _dao.saveSegmentReview(
      segmentId: item.segment.segmentId,
      isFavorited: favorite ?? item.review.isFavorited,
      isDifficult: difficult ?? item.review.isDifficult,
      isKey: key ?? item.review.isKey,
    );
    if (!mounted) return;
    setState(() => _future = _load());
  }

  Future<void> _saveAndGoNext(_ModuleReviewBundle bundle) async {
    await _save(bundle, showSnack: false);
    if (!mounted) return;
    final ritual = bundle.ritual;
    if (ritual.nextConceptId != null) {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => GoalConceptDetailPage(conceptId: ritual.nextConceptId!)),
      );
      return;
    }
    if (ritual.nextSegmentId != null) {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => GoalSegmentDetailPage(segmentId: ritual.nextSegmentId!)),
      );
      return;
    }
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => GoalWorkshopPage(
          entryNote: '你刚完成了主题复盘，适合把“准备带去现实的一步”继续带回目标工坊。',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _persistContinueState();
    _summaryCtl.dispose();
    _insightCtl.dispose();
    _actionCtl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('主题复盘页')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<_ModuleReviewBundle>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(child: Text(snap.error?.toString() ?? '加载失败'));
          }
          final bundle = snap.data!;
          _hydrate(bundle);
          _bindContinueContext(bundle);
          final ritual = bundle.ritual;
          final actionDrafts = buildModuleReviewActionDrafts(
            ritual: ritual,
            summaryText: _summaryCtl.text.trim(),
            insightText: _insightCtl.text.trim(),
            actionText: _actionCtl.text.trim(),
            anchorSegment: bundle.anchorSegment,
          );
          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('你已经走完一个主题，现在把它变成自己的话。', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text(
                      '主题复盘页不是再看一次内容，而是把这一组课程真正带回自己：它讲了什么、最触动你的是什么、你准备把哪一步带去现实。',
                      style: TextStyle(height: 1.6, color: Color(0xFF4B5563)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(ritual.sourceCourseName),
                        _chip(ritual.moduleGroup),
                        _chip('已复习 ${ritual.reviewedCount}/${ritual.totalCount}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: ritual.summaryTitle,
                child: Text(
                  ritual.summaryText,
                  style: const TextStyle(height: 1.7, color: Color(0xFF374151)),
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '边复盘边回看本主题正文',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '当前主题下的原课程段落都在这里。你可以边写复盘，边回看原文，不需要退出主题复盘页再去找。',
                      style: TextStyle(height: 1.6, color: Color(0xFF4B5563)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip('本主题 ${bundle.segments.length} 段'),
                        if (bundle.segments.isNotEmpty) _chip('起始段落 ${bundle.segments.first.segmentNo}'),
                        if (bundle.segments.isNotEmpty) _chip('结束段落 ${bundle.segments.last.segmentNo}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._buildSegmentPreviewList(bundle),
                    if (bundle.segments.length > 3) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _showAllSegments = !_showAllSegments),
                          icon: Icon(_showAllSegments ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                          label: Text(_showAllSegments ? '收起正文列表' : '展开全部正文段落'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '本主题重点 / 难点回看',
                child: _moduleReviewHighlights(bundle),
              ),
              const SizedBox(height: 12),
              _card(
                title: '写下你的主题复盘',
                child: Column(
                  children: [
                    _field(
                      label: '这组内容讲了什么',
                      hint: '用你自己的话，写下这组主题的核心内容。',
                      controller: _summaryCtl,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      label: '我最有感的一点',
                      hint: '哪句话、哪个概念、哪个例子最触动你？为什么？',
                      controller: _insightCtl,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      label: '我准备带去现实的一步',
                      hint: '把这组内容变成一个现实中的小动作。',
                      controller: _actionCtl,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : () => _save(bundle),
                            icon: _saving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.save_outlined),
                            label: const Text('保存复盘'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : () => _saveAndGoNext(bundle),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('保存并继续'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '把主题复盘带去现实',
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '现在你已经写下“准备带去现实的一步”，可以直接把它生成为行动草稿并进入执行。',
                        style: TextStyle(height: 1.6, color: Color(0xFF4B5563)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (int i = 0; i < actionDrafts.length; i++) ...[
                      _actionDraftCard(actionDrafts[i], bundle),
                      if (i != actionDrafts.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '推荐下一步',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ritual.nextTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(ritual.nextSubtitle, style: const TextStyle(height: 1.6, color: Color(0xFF4B5563))),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (ritual.nextConceptId != null)
                          _actionChip(
                            context,
                            label: '进入下一步概念',
                            onTap: () => Navigator.of(context).push(
                              CupertinoPageRoute(builder: (_) => GoalConceptDetailPage(conceptId: ritual.nextConceptId!)),
                            ),
                          ),
                        if (ritual.nextSegmentId != null)
                          _actionChip(
                            context,
                            label: '继续下一主题',
                            onTap: () => Navigator.of(context).push(
                              CupertinoPageRoute(builder: (_) => GoalSegmentDetailPage(segmentId: ritual.nextSegmentId!)),
                            ),
                          ),
                        _actionChip(
                          context,
                          label: '带回目标工坊',
                          onTap: () => Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => GoalWorkshopPage(
                                entryNote: '你刚完成一组主题复盘，适合把“准备带去现实的一步”继续带回目标工坊。',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildSegmentPreviewList(_ModuleReviewBundle bundle) {
    final visibleSegments = _showAllSegments ? bundle.reviewedSegments : bundle.reviewedSegments.take(3).toList();
    return [
      for (int i = 0; i < visibleSegments.length; i++) ...[
        _segmentPreviewTile(visibleSegments[i]),
        if (i != visibleSegments.length - 1) const SizedBox(height: 10),
      ],
    ];
  }

  Widget _moduleReviewHighlights(_ModuleReviewBundle bundle) {
    final keyItems = bundle.reviewedSegments.where((e) => e.review.isKey).toList();
    final difficultItems = bundle.reviewedSegments.where((e) => e.review.isDifficult).toList();
    final focusItems = [
      ...keyItems,
      ...difficultItems.where((d) => !keyItems.any((k) => k.segment.segmentId == d.segment.segmentId)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '优先看你已经标过的重点和难点。这样复盘时不用平均回看整组内容，而是先抓最关键、最卡住你的段落。',
          style: TextStyle(height: 1.6, color: Color(0xFF4B5563)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('已标重点 ${keyItems.length}'),
            _chip('已标难点 ${difficultItems.length}'),
            _chip('优先回看 ${focusItems.length} 段'),
          ],
        ),
        const SizedBox(height: 12),
        if (focusItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '这个主题下你还没有标记重点或难点。你可以直接在下面的正文列表里补标，复盘页会优先帮你回看这些段落。',
              style: TextStyle(height: 1.6, color: Color(0xFF4B5563)),
            ),
          )
        else
          ...[
            for (int i = 0; i < focusItems.length; i++) ...[
              _segmentPreviewTile(focusItems[i], emphasize: true),
              if (i != focusItems.length - 1) const SizedBox(height: 10),
            ],
          ],
      ],
    );
  }

  Widget _segmentPreviewTile(GoalReviewedSegment item, {bool emphasize = false}) {
    final segment = item.segment;
    final review = item.review;
    final preview = segment.segmentText.replaceAll('\n', ' ').trim();
    final shortText = preview.length > 96 ? '${preview.substring(0, 96)}…' : preview;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: emphasize ? const Color(0xFFFFFBEB) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: emphasize ? Border.all(color: const Color(0xFFFDE68A)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${segment.segmentNo}）${segment.sectionTitle}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(shortText, style: const TextStyle(height: 1.6, color: Color(0xFF4B5563))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionChip(
                context,
                label: '查看正文',
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => GoalSegmentDetailPage(segmentId: segment.segmentId)),
                ),
              ),
              if (segment.tags.isNotEmpty) _chip(segment.tags.first),
              if (review.isKey) _chip('已标重点'),
              if (review.isDifficult) _chip('已标难点'),
              _actionChip(
                context,
                label: review.isKey ? '取消重点' : '标记重点',
                onTap: () => _toggleSegmentReview(item, key: !review.isKey),
              ),
              _actionChip(
                context,
                label: review.isDifficult ? '取消难点' : '标记难点',
                onTap: () => _toggleSegmentReview(item, difficult: !review.isDifficult),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionDraftCard(GoalModuleReviewActionDraft draft, _ModuleReviewBundle bundle) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(draft.action.actionTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                _chip(draft.levelLabel),
              ],
            ),
            const SizedBox(height: 8),
            Text(draft.subtitle, style: const TextStyle(color: Color(0xFF4B5563), height: 1.55)),
            const SizedBox(height: 8),
            Text(draft.action.goalOfAction, style: const TextStyle(height: 1.65, color: Color(0xFF374151))),
            const SizedBox(height: 10),
            for (int i = 0; i < draft.action.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${i + 1}. ${draft.action.steps[i]}', style: const TextStyle(height: 1.55, color: Color(0xFF374151))),
              ),
            const SizedBox(height: 8),
            Text('失败备用方案：${draft.action.failurePlan}', style: const TextStyle(height: 1.55, color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : () => _saveAndRunAction(bundle, draft),
              icon: const Icon(Icons.play_circle_outline),
              label: Text(_saving ? '保存中…' : '保存复盘并执行${draft.levelLabel}'),
            ),
          ],
        ),
      );

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 4,
  }) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            onChanged: (_) {
              setState(() {});
              _scheduleAutosave();
            },
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      );

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
      );

  Widget _actionChip(BuildContext context, {required String label, required VoidCallback onTap}) => Material(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      );

  Widget _card({String? title, required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      );
}

class _ModuleReviewBundle {
  final GoalCompletionRitual ritual;
  final GoalModuleReflection reflection;
  final GoalCourseSegment? anchorSegment;
  final List<GoalCourseSegment> segments;
  final List<GoalReviewedSegment> reviewedSegments;

  const _ModuleReviewBundle({
    required this.ritual,
    required this.reflection,
    required this.anchorSegment,
    required this.segments,
    required this.reviewedSegments,
  });
}
