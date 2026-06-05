import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pages/settings_page.dart';
import 'goal_setting_ai_service.dart';
import 'goal_setting_dao.dart';
import 'goal_setting_famous_figures.dart';
import 'goal_setting_models.dart';
import 'goal_setting_seed.dart';



String _loopExtraSectionTitle(String key) {
  switch (key) {
    case 'comparative_judgement':
      return '高判断力比较分析';
    case 'related_theories':
      return '相关理论概念';
    case 'psychology_analysis':
      return '心理学多学派分析';
    case 'philosophy_analysis':
      return '相关哲学思想';
    case 'strength_potential_analysis':
      return '显性与潜藏优势 / 潜能深挖';
    case '_local_note':
      return '⚠️ 系统保守提炼说明';
    case '_source':
      return '来源标记';
    case 'visible_strengths':
      return '显而易见的优势';
    case 'hidden_strengths':
      return '潜藏优势 / 潜能';
    case 'reverse_potential_from_weakness':
      return '从缺点反向挖掘出的潜能';
    case 'weakness_or_failure_clue':
      return '反面线索';
    case 'potential':
      return '潜在能力';
    case 'development_direction':
      return '发展方向';
    case 'historical_strength_evolution':
      return '历史中的优势演化';
    case 'activation_suggestions':
      return '潜能激活建议';
    case 'evidence':
      return '证据线索';
    case 'similar_historical_figure':
      return '高度相似的历史或当今人物';
    case 'famous_figure_matching':
      return '名人思想定向匹配';
    case 'requested_category':
      return '用户选择类别';
    case 'requested_figure':
      return '用户指定人物';
    case 'requested_figures':
      return '用户指定人物列表';
    case 'requested_custom_figures':
      return '自定义人物列表';
    case 'matched_figure':
      return '最佳匹配人物';
    case 'best_matched_figure':
      return '综合最佳匹配人物';
    case 'match_score':
      return '匹配度';
    case 'best_match_score':
      return '综合最佳匹配度';
    case 'match_level':
      return '匹配等级';
    case 'overall_summary':
      return '整体匹配总结';
    case 'matches':
      return '逐位人物匹配结果';
    case 'figure':
      return '人物';
    case 'source_category':
      return '所属类别';
    case 'analysis':
      return '重合分析';
    case 'thought_connection':
      return '思想连接';
    case 'difference_note':
      return '差异提醒';
    case 'practical_takeaway':
      return '可借鉴之处';
    case 'subconscious_analysis':
      return '潜意识专栏';
    case 'core_unconscious_theme':
      return '潜意识核心主题';
    case 'hidden_protective_motive':
      return '隐藏的保护性动机';
    case 'repeated_inner_script':
      return '反复出现的内在脚本';
    case 'desire_fear_conflict':
      return '欲望与恐惧冲突';
    case 'awareness_upgrade':
      return '意识升级方向';
    case 'summary':
      return '总结';
    case 'experience_recap_full':
      return 'AI经验重建全文';
    default:
      return key.replaceAll('_', ' ').trim();
  }
}

bool _loopShouldDisplayExtraSection(String key, dynamic value) {
  if (key.trim().endsWith('（原始结构保留）')) return false;
  if (key == 'AI 原始返回（宽松展示）' || key == 'experience_recap_full') return false;
  final body = _loopPrettyExtraValue(value).trim();
  if (body.isEmpty) return false;
  final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (key == 'famous_figure_matching') {
    if (compact.contains('未指定定向匹配人物') || compact.contains('用户未提供人物偏好，无法进行定向匹配。')) {
      return false;
    }
  }
  return true;
}

String _loopPrettyExtraValue(dynamic value, {int depth = 0}) {
  final indent = '  ' * depth;
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is num || value is bool) return '$value';
  if (value is List) {
    final items = value
        .map((e) => _loopPrettyExtraValue(e, depth: depth + 1))
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.contains('\n') ? '•\n$e' : '• $e')
        .toList();
    return items.join('\n');
  }
  if (value is Map) {
    final lines = <String>[];
    for (final entry in value.entries) {
      final pretty = _loopPrettyExtraValue(entry.value, depth: depth + 1);
      if (pretty.trim().isEmpty) continue;
      final label = _loopExtraSectionTitle('${entry.key}');
      if (entry.value is Map || entry.value is List) {
        lines.add('$indent$label：\n$pretty');
      } else {
        lines.add('$indent$label：$pretty');
      }
    }
    return lines.join('\n');
  }
  return '$value';
}

bool _loopIsLocalConservativeStrengthPotential(dynamic value) {
  if (value is! Map) return false;
  final source = '${value['_source'] ?? ''}'.trim();
  final note = '${value['_local_note'] ?? ''}'.trim();
  return source == 'local_conservative_strength_potential' || note.isNotEmpty;
}

String _loopStrengthPotentialSectionTitle(dynamic value) {
  if (_loopIsLocalConservativeStrengthPotential(value)) {
    return '⚠️ 系统保守版：显性与潜藏优势 / 潜能深挖';
  }
  return '显性与潜藏优势 / 潜能深挖';
}

String _loopPrettyStrengthPotentialValue(dynamic value) {
  if (!_loopIsLocalConservativeStrengthPotential(value)) {
    return _loopPrettyExtraValue(value);
  }
  final note = (value is Map ? '${value['_local_note'] ?? ''}'.trim() : '').trim();
  final cleanMap = <String, dynamic>{};
  if (value is Map) {
    for (final entry in value.entries) {
      final key = '${entry.key}';
      if (key == '_local_note' || key == '_source') continue;
      cleanMap[key] = entry.value;
    }
  }
  final body = _loopPrettyExtraValue(cleanMap).trim();
  final warning = note.isNotEmpty
      ? '⚠️【系统保守版 / AI 未直接返回】\n$note\n此区块仅作临时参考；如需更可靠、更深入的潜能分析，请点击重新生成，让 AI 按新版提示词直接返回 strength_potential_analysis。'
      : '⚠️【系统保守版 / AI 未直接返回】\n此区块由 App 根据 AI 已返回内容保守提炼，仅作临时参考；请点击重新生成以获取 AI 直接输出的潜能深挖结果。';
  if (body.isEmpty) return warning;
  return '$warning\n\n$body';
}

dynamic _loopTryResolveExtraSection(dynamic directValue, {String rawResponse = '', required String key}) {
  if (_loopShouldDisplayExtraSection(key, directValue)) return directValue;
  final raw = rawResponse.trim();
  if (raw.isEmpty) return directValue;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      final direct = decoded[key];
      if (_loopShouldDisplayExtraSection(key, direct)) return direct;
      final extra = decoded['extra_sections'];
      if (extra is Map && _loopShouldDisplayExtraSection(key, extra[key])) return extra[key];
    }
  } catch (_) {}
  return directValue;
}

String _loopPrettyFamousFigureMatching(dynamic value) {
  if (value is! Map) return _loopPrettyExtraValue(value);
  String clean(dynamic v) => '${v ?? ''}'.trim();
  final lines = <String>[];
  final requestedCategories = (value['requested_categories'] is List)
      ? (value['requested_categories'] as List).map((e) => '${e ?? ''}'.trim()).where((e) => e.isNotEmpty).toList()
      : <String>[];
  final requestedFigures = (value['requested_figures'] is List)
      ? (value['requested_figures'] as List).map((e) => '${e ?? ''}'.trim()).where((e) => e.isNotEmpty).toList()
      : <String>[];
  final requestedCustom = (value['requested_custom_figures'] is List)
      ? (value['requested_custom_figures'] as List).map((e) => '${e ?? ''}'.trim()).where((e) => e.isNotEmpty).toList()
      : <String>[];
  final requestedCategory = clean(value['requested_category']);
  final bestFigure = clean(value['best_matched_figure']);
  final bestScore = clean(value['best_match_score']);
  final overall = clean(value['overall_summary']);

  if (requestedCategory.isNotEmpty && requestedCategory != '不指定') lines.add('选择类别：$requestedCategory');
  if (requestedCategories.isNotEmpty) lines.add('类别列表：${requestedCategories.join('、')}');
  if (requestedFigures.isNotEmpty) lines.add('指定人物：${requestedFigures.join('、')}');
  if (requestedCustom.isNotEmpty) lines.add('自定义人物：${requestedCustom.join('、')}');
  if (bestFigure.isNotEmpty && bestFigure != '未指定定向匹配人物' && bestFigure != '暂时缺乏高置信匹配') {
    lines.add(bestScore.isNotEmpty && bestScore != '0' ? '综合最佳匹配：$bestFigure（$bestScore 分）' : '综合最佳匹配：$bestFigure');
  }
  if (overall.isNotEmpty && overall != '未提供具体人物或类别，故未进行定向匹配。') {
    lines.add('整体结论：$overall');
  }

  final matches = value['matches'];
  if (matches is List) {
    for (final item in matches) {
      if (item is! Map) continue;
      final figure = clean(item['figure']);
      if (figure.isEmpty) continue;
      final source = clean(item['source_category']);
      final score = clean(item['match_score']);
      final level = clean(item['match_level']);
      final parts = <String>[];
      final head = <String>[figure, if (source.isNotEmpty) source, if (level.isNotEmpty) level, if (score.isNotEmpty && score != '0') '$score 分'].join('｜');
      parts.add(head);
      for (final pair in <MapEntry<String, String>>[
        MapEntry('重合分析', clean(item['analysis'])),
        MapEntry('思想连接', clean(item['thought_connection'])),
        MapEntry('差异提醒', clean(item['difference_note'])),
        MapEntry('可借鉴之处', clean(item['practical_takeaway'])),
      ]) {
        if (pair.value.isNotEmpty) parts.add('${pair.key}：${pair.value}');
      }
      lines.add(parts.join('\n'));
    }
  }

  return lines.join('\n\n').trim();
}

List<MapEntry<String, String>> _loopExtraSectionEntries(Map<String, dynamic> extraSections) {
  final entries = <MapEntry<String, String>>[];
  for (final entry in extraSections.entries) {
    if (!_loopShouldDisplayExtraSection('${entry.key}', entry.value)) continue;
    final body = _loopPrettyExtraValue(entry.value);
    if (body.trim().isEmpty) continue;
    entries.add(MapEntry<String, String>(_loopExtraSectionTitle(entry.key), body));
  }
  return entries;
}


void _appendLoopSection(List<MapEntry<String, String>> entries, String title, String body) {
  final normalized = body.trim();
  if (normalized.isEmpty) return;
  entries.add(MapEntry<String, String>(title, normalized));
}

List<MapEntry<String, String>> _buildLoopInsightDisplaySections(GoalSettingActionLoopInsight insight) {
  final entries = <MapEntry<String, String>>[];
  if (insight.evidenceBasis.isNotEmpty) {
    _appendLoopSection(entries, '本轮输入中的关键要点', insight.evidenceBasis.map((e) => '• $e').join('\n'));
  }
  _appendLoopSection(entries, '本轮经验重建', insight.experienceRecap);
  _appendLoopSection(entries, '结果判断', insight.resultJudgement);
  _appendLoopSection(entries, '成功 / 失败原因分析', insight.resultReasonAnalysis);
  _appendLoopSection(entries, '这次表现出的优势', insight.strengthsFound);
  final strengthPotential = _loopTryResolveExtraSection(
    insight.extraSections['strength_potential_analysis'],
    rawResponse: insight.rawResponse,
    key: 'strength_potential_analysis',
  );
  if (_loopShouldDisplayExtraSection('strength_potential_analysis', strengthPotential)) {
    _appendLoopSection(entries, _loopStrengthPotentialSectionTitle(strengthPotential), _loopPrettyStrengthPotentialValue(strengthPotential));
  }
  _appendLoopSection(entries, '这次暴露出的缺点 / 盲点', insight.weaknessesOrBlindspots);
  _appendLoopSection(entries, '从经验中提炼出的行为 / 心理模式', insight.patternInduction);
  if (insight.relatedKnowledgeConcepts.isNotEmpty) {
    _appendLoopSection(entries, '相关心理学 / 哲学 / 行为科学概念', insight.relatedKnowledgeConcepts.map((e) => '• $e').join('\n'));
  }
  _appendLoopSection(entries, '从经验上升到理论层面 / 新概念', insight.theoryElevation);
  _appendLoopSection(entries, '与当前课程的关系', insight.courseConnection);
  if (_loopShouldDisplayExtraSection('subconscious_analysis', insight.extraSections['subconscious_analysis'])) {
    _appendLoopSection(entries, '潜意识专栏', _loopPrettyExtraValue(insight.extraSections['subconscious_analysis']));
  }
  final famous = _loopTryResolveExtraSection(insight.extraSections['famous_figure_matching'], rawResponse: insight.rawResponse, key: 'famous_figure_matching');
  if (_loopShouldDisplayExtraSection('famous_figure_matching', famous)) {
    _appendLoopSection(entries, '名人思想定向匹配', _loopPrettyFamousFigureMatching(famous));
  }
  final remainingExtras = Map<String, dynamic>.from(insight.extraSections)
    ..remove('subconscious_analysis')
    ..remove('famous_figure_matching')
    ..remove('strength_potential_analysis')
    ..remove('next_iteration_guidance');
  for (final extra in _loopExtraSectionEntries(remainingExtras)) {
    _appendLoopSection(entries, extra.key, extra.value);
  }
  _appendLoopSection(entries, '复盘指导', insight.retrospectiveGuidance);
  final retryBody = [
    if (insight.retryPlanTitle.trim().isNotEmpty) insight.retryPlanTitle.trim(),
    if (insight.retryVisualPlan.trim().isNotEmpty) insight.retryVisualPlan.trim(),
    ...insight.retryPlanSteps.where((e) => e.trim().isNotEmpty).map((e) => '• $e'),
  ].join('\n');
  _appendLoopSection(entries, '重新挑战的具体计划', retryBody);
  _appendLoopSection(entries, '闭环总结', insight.closureSummary);
  return entries;
}

List<MapEntry<String, String>> _buildLoopReviewDisplaySections(GoalSettingReview review) {
  final entries = <MapEntry<String, String>>[];
  _appendLoopSection(entries, '本轮经验与事实', review.fact);
  if (review.evidenceBasis.isNotEmpty) {
    _appendLoopSection(entries, '本轮输入中的关键要点', review.evidenceBasis.map((e) => '• $e').join('\n'));
  }
  _appendLoopSection(entries, '结果判断', review.resultJudgement);
  final reasonBody = review.resultReasonAnalysis.isEmpty
      ? (review.learningSummary.isEmpty ? review.feeling : review.learningSummary)
      : review.resultReasonAnalysis;
  _appendLoopSection(entries, '成功 / 失败原因分析', reasonBody);
  _appendLoopSection(entries, '这次表现出的优势', review.strengthsFound);
  if (_loopShouldDisplayExtraSection('strength_potential_analysis', review.extraSections['strength_potential_analysis'])) {
    _appendLoopSection(entries, _loopStrengthPotentialSectionTitle(review.extraSections['strength_potential_analysis']), _loopPrettyStrengthPotentialValue(review.extraSections['strength_potential_analysis']));
  }
  _appendLoopSection(entries, '这次暴露出的缺点 / 盲点', review.weaknessesOrBlindspots);
  _appendLoopSection(entries, '从经验中提炼出的行为 / 心理模式', review.patternInduction);
  if (review.relatedKnowledgeConcepts.isNotEmpty) {
    _appendLoopSection(entries, '相关心理学 / 哲学 / 行为科学概念', review.relatedKnowledgeConcepts.map((e) => '• $e').join('\n'));
  }
  _appendLoopSection(entries, '从经验上升到理论层面 / 新概念', review.theoryElevation);
  _appendLoopSection(entries, '与当前课程的关系', review.courseConnection);
  if (_loopShouldDisplayExtraSection('subconscious_analysis', review.extraSections['subconscious_analysis'])) {
    _appendLoopSection(entries, '潜意识专栏', _loopPrettyExtraValue(review.extraSections['subconscious_analysis']));
  }
  if (_loopShouldDisplayExtraSection('famous_figure_matching', review.extraSections['famous_figure_matching'])) {
    _appendLoopSection(entries, '名人思想定向匹配', _loopPrettyFamousFigureMatching(review.extraSections['famous_figure_matching']));
  }
  final remainingExtras = Map<String, dynamic>.from(review.extraSections)
    ..remove('subconscious_analysis')
    ..remove('famous_figure_matching')
    ..remove('strength_potential_analysis')
    ..remove('next_iteration_guidance');
  for (final extra in _loopExtraSectionEntries(remainingExtras)) {
    _appendLoopSection(entries, extra.key, extra.value);
  }
  _appendLoopSection(entries, '本轮结果记录', review.result);
  _appendLoopSection(entries, '复盘指导', review.retrospectiveGuidance);
  final retryBody = [
    if (review.retryPlanTitle.trim().isNotEmpty) review.retryPlanTitle.trim(),
    if (review.retryVisualPlan.trim().isNotEmpty) review.retryVisualPlan.trim(),
    ...review.retryPlan.where((e) => e.trim().isNotEmpty).map((e) => '• $e'),
  ].join('\n');
  _appendLoopSection(entries, '重新挑战的具体计划', retryBody);
  _appendLoopSection(entries, '闭环总结', review.summary);
  return entries;
}

class GoalSettingModuleHomePage extends StatefulWidget {
  const GoalSettingModuleHomePage({super.key});

  @override
  State<GoalSettingModuleHomePage> createState() => _GoalSettingModuleHomePageState();
}

class _GoalSettingModuleHomePageState extends State<GoalSettingModuleHomePage> {
  final GoalSettingDao _dao = GoalSettingDao();
  final GoalSettingAiService _ai = GoalSettingAiService();

  int _idx = 0;
  bool _loading = true;
  List<GoalSettingAction> _actions = <GoalSettingAction>[];
  List<GoalSettingReview> _reviews = <GoalSettingReview>[];
  Set<String> _done = <String>{};
  GoalSettingPersonaProfile? _persona;
  GoalSettingWorldState? _world;
  Map<String, String> _aiState = const <String, String>{'label': '读取中…'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final actions = await _dao.loadActions();
    final reviews = await _dao.loadReviews();
    final done = await _dao.loadCompletedSegments();
    final persona = await _dao.loadPersona();
    final world = await _dao.loadWorldState();
    final aiState = await _ai.getGlobalAiState();
    final synced = _syncWorld(done: done, actions: actions, current: world);
    await _dao.saveWorldState(synced);
    if (!mounted) return;
    setState(() {
      _actions = actions;
      _reviews = reviews;
      _done = done;
      _persona = persona;
      _world = synced;
      _aiState = aiState;
      _loading = false;
    });
  }

  GoalSettingWorldState _syncWorld({required Set<String> done, required List<GoalSettingAction> actions, required GoalSettingWorldState current}) {
    final zones = <String>{'聚焦之塔'};
    if (done.any((e) => e.startsWith('GS12_16')) || done.length >= 8) zones.add('山路与意义');
    if (done.any((e) => e.startsWith('GS12_35')) || done.length >= 16) zones.add('自我一致神殿');
    if (done.any((e) => e.startsWith('GS13_13')) || actions.where((e) => e.status == 'done').length >= 3) zones.add('VIA 优势学院');
    if (done.any((e) => e.startsWith('GS13_30')) || _reviews.length >= 2) zones.add('Calling 三岔路');
    if (done.any((e) => e.startsWith('GS13_49')) || done.length >= 24) zones.add('登月指挥部');
    final currentZone = zones.contains(current.currentZone) ? current.currentZone : zones.first;
    return current.copyWith(unlockedZones: zones.toList(), currentZone: currentZone, updatedAt: DateTime.now().millisecondsSinceEpoch);
  }

  GoalSettingSegment? _segmentById(String id) {
    for (final s in goalSettingSegments) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> _saveAction(GoalSettingAction action) async {
    await _dao.saveAction(action);
    await _dao.markSegmentCompleted(action.segmentId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入行动清单')));
  }

  Future<void> _updateAction(GoalSettingAction action) async {
    await _dao.updateAction(action);
    if (action.status == 'done') {
      await _dao.markSegmentCompleted(action.segmentId);
    }
    await _load();
  }

  Future<void> _saveReview(GoalSettingReview review) async {
    await _dao.saveReview(review);
    await _dao.markSegmentCompleted(review.segmentId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存复盘')));
  }

  Future<void> _deleteReview(GoalSettingReview review) async {
    await _dao.deleteReview(review.id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除复盘记录')));
  }

  Future<void> _clearReviews() async {
    await _dao.clearReviews();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清空全部复盘记录')));
  }

  Future<void> _openSegment(GoalSettingSegment segment) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GoalSettingSegmentDetailPage(
        segment: segment,
        ai: _ai,
        onSaveAction: _saveAction,
        onSaveReview: _saveReview,
      ),
    ));
    await _load();
  }

  Future<void> _openAction(GoalSettingAction action) async {
    final segment = _segmentById(action.segmentId);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GoalSettingActionDetailPage(
        action: action,
        segment: segment,
        ai: _ai,
        onSave: _updateAction,
        onSaveReview: _saveReview,
        onDeleteFactRecord: _dao.deleteFactRecord,
        onClearFactRecords: (actionId) => _dao.clearFactRecords(actionId: actionId),
      ),
    ));
    await _load();
  }

  Future<void> _openReview(GoalSettingReview review) async {
    final segment = _segmentById(review.segmentId);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GoalSettingReviewDetailPage(review: review, segment: segment, onDelete: () => _deleteReview(review)),
    ));
  }

  Future<void> _openPersonaSheet() async {
    final current = _persona;
    final roleCtrl = TextEditingController(text: current?.lifeRole ?? '探索者');
    final focusCtrl = TextEditingController(text: current?.currentFocus ?? '目标设定');
    final problemCtrl = TextEditingController(text: current?.currentProblem ?? '');
    final goalCtrl = TextEditingController(text: current?.currentGoal ?? '');
    final blockCtrl = TextEditingController(text: current?.motivationBlock ?? '');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('建立你的现实映射档案', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('这一步会影响推荐段落、现实行动与虚拟世界导航。'),
                const SizedBox(height: 12),
                _input('你当前最重要的身份/角色', roleCtrl),
                const SizedBox(height: 8),
                _input('你当前最想改善的焦点', focusCtrl),
                const SizedBox(height: 8),
                _input('你最近最困扰的问题', problemCtrl, maxLines: 3),
                const SizedBox(height: 8),
                _input('你希望通过这个模块达成什么目标', goalCtrl, maxLines: 3),
                const SizedBox(height: 8),
                _input('你最常见的动力阻碍是什么', blockCtrl, maxLines: 3),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final profile = GoalSettingPersonaProfile(
                        lifeRole: roleCtrl.text.trim().isEmpty ? '探索者' : roleCtrl.text.trim(),
                        currentFocus: focusCtrl.text.trim().isEmpty ? '目标设定' : focusCtrl.text.trim(),
                        currentProblem: problemCtrl.text.trim(),
                        currentGoal: goalCtrl.text.trim(),
                        motivationBlock: blockCtrl.text.trim(),
                        updatedAt: DateTime.now().millisecondsSinceEpoch,
                      );
                      await _dao.savePersona(profile);
                      if (!mounted) return;
                      Navigator.pop(sheetContext);
                      await _load();
                    },
                    child: const Text('保存映射档案'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pages = <Widget>[
      _OverviewPage(
        aiState: _aiState,
        actions: _actions,
        reviews: _reviews,
        completed: _done,
        persona: _persona,
        world: _world,
        onOpenPersona: _openPersonaSheet,
        onOpenSettings: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
        onOpenSegment: _openSegment,
      ),
      _LibraryPage(done: _done, onOpenSegment: _openSegment),
      _DiagnosisPage(persona: _persona, onOpenSegment: _openSegment),
      _ActionPage(actions: _actions, onOpenAction: _openAction),
      _WorldPage(world: _world, onOpenSegment: _openSegment),
      _ReviewPage(reviews: _reviews, onOpenReview: _openReview, onDeleteReview: _deleteReview, onClearReviews: _clearReviews),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('目标设定知行课'),
        actions: [
          IconButton(onPressed: _openPersonaSheet, icon: const Icon(Icons.person_outline)),
          IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())), icon: const Icon(Icons.settings_outlined)),
        ],
      ),
      backgroundColor: const Color(0xFFF6F7FB),
      body: pages[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: '总览'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: '课程原文'),
          NavigationDestination(icon: Icon(Icons.search_outlined), label: '问题诊断'),
          NavigationDestination(icon: Icon(Icons.playlist_add_check_circle_outlined), label: '现实行动'),
          NavigationDestination(icon: Icon(Icons.landscape_outlined), label: '虚拟世界'),
          NavigationDestination(icon: Icon(Icons.history_outlined), label: '复盘'),
        ],
      ),
    );
  }

  Widget _input(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(controller: controller, maxLines: maxLines, decoration: const InputDecoration(border: OutlineInputBorder())),
      ],
    );
  }
}

class _OverviewPage extends StatelessWidget {
  final Map<String, String> aiState;
  final List<GoalSettingAction> actions;
  final List<GoalSettingReview> reviews;
  final Set<String> completed;
  final GoalSettingPersonaProfile? persona;
  final GoalSettingWorldState? world;
  final Future<void> Function() onOpenPersona;
  final VoidCallback onOpenSettings;
  final Future<void> Function(GoalSettingSegment segment) onOpenSegment;

  const _OverviewPage({
    required this.aiState,
    required this.actions,
    required this.reviews,
    required this.completed,
    required this.persona,
    required this.world,
    required this.onOpenPersona,
    required this.onOpenSettings,
    required this.onOpenSegment,
  });


  @override
  Widget build(BuildContext context) {
    final total = goalSettingSegments.length;
    final today = _recommendTodaySegment();
    final latestAction = actions.isEmpty ? null : actions.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _HeroCard(
          title: 'Lecture 12 + Lecture 13 的目标主题课程母本',
          subtitle: '完整保留当前导入的全部简化分段原文，并把它们接到深度理解、问题诊断、现实行动、虚拟世界与复盘闭环。',
          chips: <String>['原文母本', '${total}段已导入', '深度理解', '现实行动', '虚拟世界', '复盘成长'],
        ),
        const SizedBox(height: 12),
        _AiStateCard(aiState: aiState, onOpenSettings: onOpenSettings),
        const SizedBox(height: 12),
        _PromptCard(
          title: 'AI 提示词设置入口',
          body: '本模块的理解页、行动页、行动闭环页 AI 提示词都支持用户自行配置。你可以在设置里修改模板，让 AI 更贴合你的课程理解、行动设计和复盘风格。',
          cta: '去配置',
          onTap: onOpenSettings,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(label: '已学习', value: '${completed.length}/$total')),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: '行动', value: '${actions.length}')),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: '复盘', value: '${reviews.length}')),
          ],
        ),
        const SizedBox(height: 12),
        if (persona == null)
          _PromptCard(
            title: '先建立你的现实映射档案',
            body: '这样模块才能更贴近你的真实角色、真实问题和真实目标。',
            cta: '去填写',
            onTap: onOpenPersona,
          )
        else
          _PersonaCard(persona: persona!),
        const SizedBox(height: 12),
        if (today != null)
          _NextSegmentCard(
            segment: today,
            done: completed.contains(today.id),
            onTap: () => onOpenSegment(today),
          ),
        if (latestAction != null) ...[
          const SizedBox(height: 12),
          _InfoCard(
            title: '最近一次现实行动',
            lines: <String>[
              latestAction.title,
              '状态：${latestAction.status == 'done' ? '已完成' : latestAction.status == 'doing' ? '进行中' : '待开始'}',
              latestAction.body,
            ],
          ),
        ],
        const SizedBox(height: 12),
        _InfoCard(
          title: '当前已解锁的虚拟世界区域',
          lines: (world?.unlockedZones ?? const <String>['聚焦之塔']).map((e) => '• $e').toList(),
        ),
      ],
    );
  }

  GoalSettingSegment? _recommendTodaySegment() {
    for (final segment in goalSettingSegments) {
      if (!completed.contains(segment.id)) return segment;
    }
    return goalSettingSegments.isEmpty ? null : goalSettingSegments.first;
  }
}

class _LibraryPage extends StatefulWidget {
  final Set<String> done;
  final Future<void> Function(GoalSettingSegment segment) onOpenSegment;
  const _LibraryPage({required this.done, required this.onOpenSegment});

  @override
  State<_LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<_LibraryPage> {
  String _query = '';
  int _lecture = 0;


  @override
  Widget build(BuildContext context) {
    final items = goalSettingSegments.where((segment) {
      if (_lecture != 0 && segment.lecture != _lecture) return false;
      final q = _query.trim();
      if (q.isEmpty) return true;
      return segment.title.contains(q) || segment.originalText.contains(q) || segment.concepts.any((c) => c.contains(q));
    }).toList();
    final lecture12 = goalSettingSegments.where((e) => e.lecture == 12).toList();
    final lecture13 = goalSettingSegments.where((e) => e.lecture == 13).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _LectureQuickCard(
                      title: 'Lecture 12 原文总库',
                      subtitle: '${lecture12.length} 段完整导入',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => GoalSettingLectureReaderPage(
                          lecture: 12,
                          title: 'Lecture 12 · 目标设定后半段',
                          segments: lecture12,
                          done: widget.done,
                          onOpenSegment: widget.onOpenSegment,
                        ),
                      )),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LectureQuickCard(
                      title: 'Lecture 13 原文总库',
                      subtitle: '${lecture13.length} 段完整导入',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => GoalSettingLectureReaderPage(
                          lecture: 13,
                          title: 'Lecture 13 · 目标/自我一致前半段',
                          segments: lecture13,
                          done: widget.done,
                          onOpenSegment: widget.onOpenSegment,
                        ),
                      )),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '搜索标题、原文、概念', border: OutlineInputBorder()),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(label: const Text('全部'), selected: _lecture == 0, onSelected: (_) => setState(() => _lecture = 0)),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('Lecture 12'), selected: _lecture == 12, onSelected: (_) => setState(() => _lecture = 12)),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('Lecture 13'), selected: _lecture == 13, onSelected: (_) => setState(() => _lecture = 13)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemBuilder: (_, index) {
              final item = items[index];
              final done = widget.done.contains(item.id);
              return Material(
                color: Colors.white,
                elevation: 2,
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  onTap: () => widget.onOpenSegment(item),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('L${item.lecture}-${item.indexInLecture.toString().padLeft(2, '0')} · ${item.concepts.take(4).join(' / ')}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: done ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                    child: Text('${item.indexInLecture}', style: TextStyle(color: done ? const Color(0xFF166534) : const Color(0xFF1D4ED8), fontWeight: FontWeight.w800)),
                  ),
                  trailing: done ? const Icon(Icons.check_circle, color: Color(0xFF16A34A)) : const Icon(Icons.chevron_right),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: items.length,
          ),
        ),
      ],
    );
  }
}

class _DiagnosisPage extends StatefulWidget {
  final GoalSettingPersonaProfile? persona;
  final Future<void> Function(GoalSettingSegment segment) onOpenSegment;
  const _DiagnosisPage({required this.persona, required this.onOpenSegment});

  @override
  State<_DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends State<_DiagnosisPage> {
  final TextEditingController _ctrl = TextEditingController();
  List<GoalSettingSegment> _matches = const <GoalSettingSegment>[];

  @override
  void initState() {
    super.initState();
    final seed = widget.persona?.currentProblem ?? '';
    if (seed.trim().isNotEmpty) {
      _ctrl.text = seed;
      _run();
    }
  }

  void _run() {
    final q = _ctrl.text.trim();
    final List<MapEntry<GoalSettingSegment, int>> scored = goalSettingSegments.map((segment) {
      var score = 0;
      if (q.isNotEmpty) {
        for (final part in q.split(RegExp(r'[，。,.、\s]+')).where((e) => e.trim().isNotEmpty)) {
          if (segment.title.contains(part)) score += 4;
          if (segment.originalText.contains(part)) score += 2;
          if (segment.concepts.any((c) => c.contains(part))) score += 3;
        }
      }
      return MapEntry(segment, score);
    }).where((e) => e.value > 0).toList();
    scored.sort((a, b) => b.value.compareTo(a.value));
    setState(() => _matches = scored.take(8).map((e) => e.key).toList());
  }


  @override
  Widget build(BuildContext context) {
    final top = _matches.isEmpty ? null : _matches.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _InfoCard(
          title: '从现实问题反查课程',
          lines: const <String>[
            '输入你现在最真实的困扰，例如：我不知道自己真正想做什么、我目标很多却很乱、我总是拖延、我明明成功了却不快乐。',
            '系统会把问题映射回最相关的课程段落，并给出一条建议的第一步。',
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '描述你当前最真实的问题'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: _run, icon: const Icon(Icons.search), label: const Text('开始诊断')),
        if (top != null) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: '诊断摘要',
            body: '你当前的问题，更像和「${top.title}」有关。优先从 ${top.concepts.take(3).join('、')} 这条线开始。建议第一步：${top.defaultActionTitle}。',
          ),
        ] else if (_ctrl.text.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionCard(
            title: '暂未命中明确段落',
            body: '可以尝试把问题写得更具体：你现在最困扰的，是方向感、拖延、外界期待、工作意义，还是目标拆解？',
          ),
        ],
        const SizedBox(height: 14),
        ..._matches.map((segment) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                elevation: 2,
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  onTap: () => widget.onOpenSegment(segment),
                  title: Text(segment.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('概念：${segment.concepts.join(' / ')}\n建议动作：${segment.defaultActionTitle}', maxLines: 3, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            )),
      ],
    );
  }
}

class _ActionPage extends StatelessWidget {
  final List<GoalSettingAction> actions;
  final Future<void> Function(GoalSettingAction action) onOpenAction;
  const _ActionPage({required this.actions, required this.onOpenAction});


  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const Center(child: Text('还没有行动记录。先从课程原文里挑一段，把理解变成现实动作。'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemBuilder: (_, index) {
        final action = actions[index];
        return Material(
          color: Colors.white,
          elevation: 2,
          borderRadius: BorderRadius.circular(18),
          child: ListTile(
            onTap: () => onOpenAction(action),
            title: Text(action.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${action.segmentTitle}\n状态：${_statusLabel(action.status)}', maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: actions.length,
    );
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'doing':
        return '进行中';
      case 'done':
        return '已完成';
      default:
        return '待开始';
    }
  }
}


Widget _buildLoopDebugChip(String label, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text('$label：$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
  );
}

void _showLoopDebugTextSheet(BuildContext context, String title, String content) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final safeContent = content.trim().isEmpty ? '（空）' : content;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: safeContent));
                      if (!sheetContext.mounted) return;
                      ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('复制'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    safeContent,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildLoopDebugPanel(BuildContext context, GoalSettingActionLoopInsight insight) {
  final promptSourceText = insight.promptSourceLabel.trim().isNotEmpty
      ? insight.promptSourceLabel.trim()
      : (insight.promptSource.trim().isEmpty ? '未知' : insight.promptSource.trim());
  final fallbackText = insight.fallbackReason.trim().isEmpty ? '本次未触发回退。' : insight.fallbackReason.trim();
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: const Text('调试信息', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          insight.usedFallback ? '定位这次为什么回退到模板结果' : '查看这次实际生效 Prompt 与模型原始输出',
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLoopDebugChip('结果', insight.usedFallback ? '本地回退' : 'AI 通过'),
              _buildLoopDebugChip('Prompt 来源', promptSourceText),
              _buildLoopDebugChip('模型', insight.modelLabel),
            ],
          ),
          if (insight.promptSourceNote.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(insight.promptSourceNote, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
          const SizedBox(height: 10),
          _SectionCard(title: '回退 / 校验结论', body: fallbackText),
          if (insight.debugTrace.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SectionCard(title: '调试轨迹', body: insight.debugTrace.map((e) => '• $e').join('\n')),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (insight.promptTemplateUsed.trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _showLoopDebugTextSheet(context, '实际生效的 Prompt 模板', insight.promptTemplateUsed),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('看生效模板'),
                ),
              if (insight.requestPrompt.trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _showLoopDebugTextSheet(context, '本次实际请求 Prompt', insight.requestPrompt),
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: const Text('看请求 Prompt'),
                ),
              if (insight.rawResponse.trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _showLoopDebugTextSheet(context, '首轮原始 AI 输出', insight.rawResponse),
                  icon: const Icon(Icons.code_outlined, size: 18),
                  label: const Text('看首轮输出'),
                ),
              if (insight.retryRawResponse.trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _showLoopDebugTextSheet(context, '重试原始 AI 输出', insight.retryRawResponse),
                  icon: const Icon(Icons.refresh_outlined, size: 18),
                  label: const Text('看重试输出'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _WorldPage extends StatelessWidget {
  final GoalSettingWorldState? world;
  final Future<void> Function(GoalSettingSegment segment) onOpenSegment;
  const _WorldPage({required this.world, required this.onOpenSegment});


  @override
  Widget build(BuildContext context) {
    final zones = <Map<String, String>>[
      {'title': '聚焦之塔', 'desc': '训练目标为什么能带来聚焦、资源与承诺。', 'match': '聚焦之塔'},
      {'title': '山路与意义', 'desc': '练习目标与幸福、方向感、过程体验之间的关系。', 'match': '山路与意义'},
      {'title': '自我一致神殿', 'desc': '区分“我真想做”和“我以为我该做”的事。', 'match': '自我一致神殿'},
      {'title': 'VIA 优势学院', 'desc': '识别真正的我，并让优势进入过程与问题解决。', 'match': 'VIA 优势学院'},
      {'title': 'Calling 三岔路', 'desc': '把工作、人生方向看成 job、career 还是 calling。', 'match': 'Calling 三岔路'},
      {'title': '登月指挥部', 'desc': '训练拉伸型目标、目标分解与每日第一步。', 'match': '登月指挥部'},
    ];
    final unlocked = (world?.unlockedZones ?? const <String>['聚焦之塔']).toSet();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemBuilder: (_, index) {
        final zone = zones[index];
        final title = zone['title']!;
        final available = unlocked.contains(title);
        final related = goalSettingSegments.where((s) => s.worldZone == title).take(3).toList();
        return Material(
          color: Colors.white,
          elevation: 2,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                    if (available)
                      const Chip(label: Text('已解锁'))
                    else
                      const Chip(label: Text('未解锁')),
                  ],
                ),
                const SizedBox(height: 6),
                Text(zone['desc']!),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: related.map((segment) => ActionChip(label: Text(segment.title), onPressed: available ? () => onOpenSegment(segment) : null)).toList(),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: zones.length,
    );
  }
}

class _ReviewPage extends StatelessWidget {
  final List<GoalSettingReview> reviews;
  final Future<void> Function(GoalSettingReview review) onOpenReview;
  final Future<void> Function(GoalSettingReview review) onDeleteReview;
  final Future<void> Function() onClearReviews;
  const _ReviewPage({required this.reviews, required this.onOpenReview, required this.onDeleteReview, required this.onClearReviews});

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const Center(child: Text('还没有复盘记录。完成一次行动后，再回来写事实、感受、结果。'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemBuilder: (_, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('AI行动闭环总结历史记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                  TextButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('清空复盘记录'),
                          content: const Text('确定清空全部 AI 行动闭环总结历史记录吗？'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
                            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('清空')),
                          ],
                        ),
                      );
                      if (ok == true) await onClearReviews();
                    },
                    child: const Text('清空全部'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...reviews.map((review) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.white,
                      elevation: 2,
                      borderRadius: BorderRadius.circular(18),
                      child: ListTile(
                        onTap: () => onOpenReview(review),
                        title: Text(review.segmentTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(review.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('删除复盘记录'),
                                content: Text('确定删除「${review.segmentTitle}」这条复盘记录吗？'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
                                  FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('删除')),
                                ],
                              ),
                            );
                            if (ok == true) await onDeleteReview(review);
                          },
                        ),
                      ),
                    ),
                  )),
            ],
          );
        }
        return const SizedBox.shrink();
      },
      separatorBuilder: (_, __) => const SizedBox.shrink(),
      itemCount: 1,
    );
  }
}

class GoalSettingSegmentDetailPage extends StatefulWidget {
  final GoalSettingSegment segment;
  final GoalSettingAiService ai;
  final Future<void> Function(GoalSettingAction action) onSaveAction;
  final Future<void> Function(GoalSettingReview review) onSaveReview;

  const GoalSettingSegmentDetailPage({super.key, required this.segment, required this.ai, required this.onSaveAction, required this.onSaveReview});

  @override
  State<GoalSettingSegmentDetailPage> createState() => _GoalSettingSegmentDetailPageState();
}

class _GoalSettingSegmentDetailPageState extends State<GoalSettingSegmentDetailPage> {
  final GoalSettingDao _cacheDao = GoalSettingDao();
  late List<GoalSettingAction> _actionOptions;
  late GoalSettingUnderstandingResult _understanding;
  Map<String, String> _aiState = const <String, String>{'label': '读取中…'};
  bool _generating = false;
  bool _loadingUnderstanding = true;
  bool _hasSavedActionDrafts = false;
  bool _actionUsedFallback = false;
  String _actionGenerationNote = '';
  String _actionRawResponse = '';
  String _actionModelLabel = '本地策略';
  final TextEditingController _concernCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _actionOptions = widget.ai.previewActionOptions(segment: widget.segment);
    _understanding = GoalSettingUnderstandingResult(
      whatText: widget.segment.whatText,
      whyText: widget.segment.whyText,
      howText: widget.segment.howSteps.join('；'),
      realCase: widget.segment.cases.join('；'),
      provider: 'local',
      modelLabel: '本地策略',
    );
    _loadAiState();
    _loadUnderstanding();
    _loadSavedActionDrafts();
  }

  Future<void> _loadAiState() async {
    final state = await widget.ai.getGlobalAiState();
    if (!mounted) return;
    setState(() => _aiState = state);
  }

  Future<void> _loadUnderstanding() async {
    setState(() => _loadingUnderstanding = true);
    final cached = await _cacheDao.loadUnderstanding(widget.segment.id);
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _understanding = cached;
        _loadingUnderstanding = false;
      });
      return;
    }
    await _generateAndPersistUnderstanding(showSnackBar: false);
  }

  Future<void> _generateAndPersistUnderstanding({bool showSnackBar = true}) async {
    setState(() => _loadingUnderstanding = true);
    final result = await widget.ai.generateUnderstandingAnalysis(segment: widget.segment);
    await _cacheDao.saveUnderstanding(widget.segment.id, result);
    if (!mounted) return;
    setState(() {
      _understanding = result;
      _loadingUnderstanding = false;
    });
    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已重新生成并更新本地分析')));
    }
  }

  Future<void> _loadSavedActionDrafts() async {
    final bundle = await _cacheDao.loadActionDraftBundle(widget.segment.id);
    if (bundle == null) return;
    if (!mounted) return;
    setState(() {
      _actionOptions = bundle.actions;
      _hasSavedActionDrafts = bundle.actions.isNotEmpty;
      _actionModelLabel = bundle.modelLabel;
      _actionUsedFallback = bundle.usedFallback;
      _actionGenerationNote = bundle.generationNote;
      _actionRawResponse = bundle.rawResponse;
      if (bundle.userConcern.trim().isNotEmpty) {
        _concernCtrl.text = bundle.userConcern;
      }
    });
  }

  Future<void> _generateAiActions() async {
    setState(() => _generating = true);
    final result = await widget.ai.generateActionOptions(segment: widget.segment, userConcern: _concernCtrl.text.trim());
    final bundle = GoalSettingActionDraftBundle(
      segmentId: widget.segment.id,
      userConcern: _concernCtrl.text.trim(),
      actions: result.actions,
      provider: result.provider,
      modelLabel: result.modelLabel,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      usedFallback: result.usedFallback,
      generationNote: result.generationNote,
      rawResponse: result.rawResponse,
    );
    await _cacheDao.saveActionDraftBundle(bundle);
    if (!mounted) return;
    setState(() {
      _actionOptions = result.actions;
      _generating = false;
      _hasSavedActionDrafts = true;
      _actionModelLabel = result.modelLabel;
      _actionUsedFallback = result.usedFallback;
      _actionGenerationNote = result.generationNote;
      _actionRawResponse = result.rawResponse;
    });
    final msg = result.usedFallback ? 'AI 结果未完全结构化，已更新为可执行草稿' : '已根据 ${result.modelLabel} 生成并保存行动草稿';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _persistActionDrafts({
    required List<GoalSettingAction> actions,
    String? provider,
    String? modelLabel,
    bool? usedFallback,
    String? generationNote,
    String? rawResponse,
  }) async {
    final bundle = GoalSettingActionDraftBundle(
      segmentId: widget.segment.id,
      userConcern: _concernCtrl.text.trim(),
      actions: actions,
      provider: provider ?? (_actionRawResponse.trim().isNotEmpty ? 'ai' : (_actionModelLabel == '自定义行动' ? 'custom' : 'local')),
      modelLabel: modelLabel ?? (_actionModelLabel.trim().isEmpty ? (_aiState['label'] ?? '自定义行动') : _actionModelLabel),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      usedFallback: usedFallback ?? _actionUsedFallback,
      generationNote: generationNote ?? _actionGenerationNote,
      rawResponse: rawResponse ?? _actionRawResponse,
    );
    await _cacheDao.saveActionDraftBundle(bundle);
    if (!mounted) return;
    setState(() {
      _actionOptions = actions;
      _hasSavedActionDrafts = actions.isNotEmpty;
      _actionModelLabel = bundle.modelLabel;
      _actionUsedFallback = bundle.usedFallback;
      _actionGenerationNote = bundle.generationNote;
      _actionRawResponse = bundle.rawResponse;
    });
  }

  String _normalizeDraftTitle(String raw, List<String> steps) {
    final title = raw.trim();
    if (title.isNotEmpty) return title;
    if (steps.isNotEmpty) return '自定义行动｜${steps.first}';
    return '自定义行动';
  }

  List<String> _parseStepLines(String raw) {
    return raw
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .map((e) => e.replaceFirst(RegExp(r'^[-•]\s*'), '').replaceFirst(RegExp(r'^[0-9]+[.、]\s*'), '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _openCustomActionEditor({GoalSettingAction? initial}) async {
    final titleCtrl = TextEditingController(text: initial?.title ?? '');
    final bodyCtrl = TextEditingController(text: initial?.body ?? '');
    final stepsCtrl = TextEditingController(text: initial == null ? '' : initial.steps.join('\n'));
    final successCtrl = TextEditingController(text: initial?.successCriteria ?? '');
    final fallbackCtrl = TextEditingController(text: initial?.fallbackAction ?? '');
    final reviewCtrl = TextEditingController(text: initial?.reviewQuestion ?? widget.segment.reflectionQuestion);
    String errorText = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(initial == null ? '新增自定义行动' : '编辑行动', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('自定义行动会与 AI 行动使用同一数据结构与同一草稿存储方式。'),
                    const SizedBox(height: 12),
                    _sheetInput('行动标题（可选）', titleCtrl),
                    const SizedBox(height: 8),
                    _sheetInput('行动说明', bodyCtrl, hintText: '说明这次行动要做什么、为什么要这样做'),
                    const SizedBox(height: 8),
                    _sheetInput('行动步骤（必填，每行一步）', stepsCtrl, maxLines: 5, hintText: '例如：\n1. 打开招聘网站\n2. 投递 3 个岗位\n3. 记录反馈'),
                    const SizedBox(height: 8),
                    _sheetInput('完成标准', successCtrl),
                    const SizedBox(height: 8),
                    _sheetInput('降级动作', fallbackCtrl),
                    const SizedBox(height: 8),
                    _sheetInput('复盘问题', reviewCtrl),
                    if (errorText.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(errorText, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final steps = _parseStepLines(stepsCtrl.text);
                          if (steps.isEmpty) {
                            setSheetState(() => errorText = '请至少填写一个行动步骤；每行代表一步。');
                            return;
                          }
                          final now = DateTime.now().millisecondsSinceEpoch;
                          final action = GoalSettingAction(
                            id: initial?.id ?? 'gs_custom_${widget.segment.id}_$now',
                            segmentId: widget.segment.id,
                            segmentTitle: widget.segment.title,
                            level: (initial?.level ?? '').trim().isEmpty ? 'custom' : initial!.level,
                            source: (initial?.source ?? '').trim().isEmpty ? 'custom' : initial!.source,
                            title: _normalizeDraftTitle(titleCtrl.text, steps),
                            body: bodyCtrl.text.trim(),
                            steps: steps,
                            successCriteria: successCtrl.text.trim(),
                            fallbackAction: fallbackCtrl.text.trim(),
                            reviewQuestion: reviewCtrl.text.trim().isEmpty ? widget.segment.reflectionQuestion : reviewCtrl.text.trim(),
                            createdAt: initial?.createdAt ?? now,
                            status: initial?.status ?? 'todo',
                            factLog: initial?.factLog ?? '',
                            obstacleNote: initial?.obstacleNote ?? '',
                            nextStepNote: initial?.nextStepNote ?? '',
                          );
                          final actions = List<GoalSettingAction>.from(_actionOptions);
                          final idx = actions.indexWhere((e) => e.id == action.id);
                          if (idx >= 0) {
                            actions[idx] = action;
                          } else {
                            actions.insert(0, action);
                          }
                          await _persistActionDrafts(
                            actions: actions,
                            provider: _hasSavedActionDrafts ? null : 'custom',
                            modelLabel: _actionModelLabel.trim().isEmpty ? '自定义行动' : _actionModelLabel,
                            usedFallback: false,
                            generationNote: initial == null ? '已新增自定义行动草稿。' : '已更新行动草稿。',
                          );
                          if (!mounted) return;
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(initial == null ? '已新增自定义行动' : '已更新行动')));
                        },
                        child: Text(initial == null ? '保存自定义行动' : '保存修改'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _deleteDraftAction(GoalSettingAction action) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除行动'),
            content: Text('确定删除「${action.title}」吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('删除')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final actions = List<GoalSettingAction>.from(_actionOptions)..removeWhere((e) => e.id == action.id);
    await _persistActionDrafts(
      actions: actions,
      generationNote: actions.isEmpty ? '已删除全部行动草稿。' : '已删除一条行动草稿。',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除行动')));
  }

  Future<void> _openReviewComposer() async {
    final factCtrl = TextEditingController();
    final feelingCtrl = TextEditingController();
    final actionCtrl = TextEditingController();
    final resultCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('写一次复盘', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _sheetInput('事实', factCtrl),
              const SizedBox(height: 8),
              _sheetInput('感受', feelingCtrl),
              const SizedBox(height: 8),
              _sheetInput('我做了什么', actionCtrl),
              const SizedBox(height: 8),
              _sheetInput('结果', resultCtrl),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final review = GoalSettingReview(
                      id: 'gsr_${DateTime.now().millisecondsSinceEpoch}',
                      segmentId: widget.segment.id,
                      segmentTitle: widget.segment.title,
                      fact: factCtrl.text.trim(),
                      feeling: feelingCtrl.text.trim(),
                      action: actionCtrl.text.trim(),
                      result: resultCtrl.text.trim(),
                      summary: widget.ai.buildReviewSummary(
                        segment: widget.segment,
                        fact: factCtrl.text.trim(),
                        feeling: feelingCtrl.text.trim(),
                        action: actionCtrl.text.trim(),
                        result: resultCtrl.text.trim(),
                      ),
                      createdAt: DateTime.now().millisecondsSinceEpoch,
                    );
                    await widget.onSaveReview(review);
                    if (!mounted) return;
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('保存复盘'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final segment = widget.segment;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(segment.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          bottom: const TabBar(tabs: [Tab(text: '原文'), Tab(text: '理解'), Tab(text: '行动'), Tab(text: '虚拟世界'), Tab(text: '复盘')]),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Pill('L${segment.lecture}-${segment.indexInLecture.toString().padLeft(2, '0')}'),
                const SizedBox(height: 12),
                SelectableText(segment.originalText, style: const TextStyle(fontSize: 16, height: 1.7)),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: segment.concepts.map((e) => _Pill(e)).toList()),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text('当前 AI：${_understanding.modelLabel}', style: const TextStyle(color: Color(0xFF6B7280)))),
                    FilledButton.tonal(
                      onPressed: _loadingUnderstanding ? null : () => _generateAndPersistUnderstanding(showSnackBar: true),
                      child: Text(_loadingUnderstanding ? '分析中…' : '重新生成并更新'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_loadingUnderstanding)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  _SectionCard(title: '这段在讲什么', body: _understanding.whatText),
                  const SizedBox(height: 10),
                  _SectionCard(title: '为什么重要', body: _understanding.whyText),
                  const SizedBox(height: 10),
                  _SectionCard(title: '如何做', body: _understanding.howText),
                  const SizedBox(height: 10),
                  _SectionCard(title: '现实具体案例', body: _understanding.realCase),
                  const SizedBox(height: 10),
                  _SectionCard(title: '对应的虚拟世界区域', body: segment.worldZone),
                ],
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _concernCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '输入你当前的真实困扰，让行动建议更贴近你'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('当前 AI：${_actionModelLabel == '本地策略' ? (_aiState['label'] ?? '未配置') : _actionModelLabel}', style: const TextStyle(color: Color(0xFF6B7280)))),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: _generating ? null : _generateAiActions,
                      child: Text(_generating ? '生成中…' : (_hasSavedActionDrafts ? '重新生成并更新' : '用AI生成动作')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async { await _openCustomActionEditor(); },
                      icon: const Icon(Icons.add),
                      label: const Text('新增自定义行动'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_hasSavedActionDrafts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _actionUsedFallback
                              ? '当前显示的是根据 AI 返回内容整理出的可执行草稿；点击“重新生成并更新”会覆盖本地数据库中的该段行动草稿。'
                              : (_actionRawResponse.trim().isNotEmpty
                                  ? '已显示上次保存的 AI 行动结果；点击“重新生成并更新”会覆盖本地数据库中的该段行动草稿。'
                                  : '已显示上次保存的行动草稿；你可以继续编辑、删除或加入行动清单。'),
                          style: const TextStyle(color: Color(0xFF6B7280)),
                        ),
                        if (_actionGenerationNote.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(_actionGenerationNote, style: const TextStyle(color: Color(0xFF6B7280))),
                        ],
                        if (_actionRawResponse.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: 8),
                            title: const Text('查看 AI 原始输出', style: TextStyle(fontWeight: FontWeight.w700)),
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: SelectableText(_actionRawResponse, style: const TextStyle(height: 1.5)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                if (_actionOptions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('还没有行动草稿。你可以先用 AI 生成，或手动新增自定义行动。')),
                  )
                else
                  ..._actionOptions.map((action) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ActionDraftCard(
                          action: action,
                          onSave: () => widget.onSaveAction(action),
                          onEdit: () => _openCustomActionEditor(initial: action),
                          onDelete: () => _deleteDraftAction(action),
                        ),
                      )),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionCard(title: '虚拟世界区域', body: segment.worldZone),
                const SizedBox(height: 10),
                _SectionCard(title: '该区域训练什么', body: _zoneDescription(segment.worldZone)),
                const SizedBox(height: 10),
                _SectionCard(title: '本段推荐虚拟任务', body: _worldMissionForSegment(segment)),
                const SizedBox(height: 10),
                _SectionCard(title: '如何映射回现实', body: '完成虚拟任务后，直接执行「${segment.defaultActionTitle}」。把虚拟世界里的选择，变成今天现实中的一个动作。'),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionCard(title: '默认复盘问题', body: segment.reflectionQuestion),
                const SizedBox(height: 10),
                ...widget.ai.buildReviewQuestions(segment: segment).map((q) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.help_outline), title: Text(q))),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: _openReviewComposer, icon: const Icon(Icons.edit_note), label: const Text('写一次复盘')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetInput(String label, TextEditingController controller, {int maxLines = 3, String? hintText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(border: const OutlineInputBorder(), hintText: hintText),
        ),
      ],
    );
  }
}

class GoalSettingActionDetailPage extends StatefulWidget {
  final GoalSettingAction action;
  final GoalSettingSegment? segment;
  final GoalSettingAiService ai;
  final Future<void> Function(GoalSettingAction action) onSave;
  final Future<void> Function(GoalSettingReview review) onSaveReview;
  final Future<void> Function(String recordId) onDeleteFactRecord;
  final Future<void> Function(String actionId) onClearFactRecords;

  const GoalSettingActionDetailPage({super.key, required this.action, required this.segment, required this.ai, required this.onSave, required this.onSaveReview, required this.onDeleteFactRecord, required this.onClearFactRecords});

  @override
  State<GoalSettingActionDetailPage> createState() => _GoalSettingActionDetailPageState();
}

class _GoalSettingActionDetailPageState extends State<GoalSettingActionDetailPage> {
  final GoalSettingDao _dao = GoalSettingDao();
  late String _status;
  late TextEditingController _factCtrl;
  late TextEditingController _obstacleCtrl;
  late TextEditingController _nextCtrl;
  List<GoalSettingFactRecord> _records = const <GoalSettingFactRecord>[];
  GoalSettingActionLoopInsight? _insight;
  bool _loadingLoop = false;
  final Set<String> _selectedFigureCategories = <String>{};
  final Set<String> _selectedFigures = <String>{};
  late TextEditingController _customFigureCtrl;

  @override
  void initState() {
    super.initState();
    _status = widget.action.status;
    _factCtrl = TextEditingController();
    _obstacleCtrl = TextEditingController();
    _nextCtrl = TextEditingController();
    _customFigureCtrl = TextEditingController();
    _loadLoopData();
  }

  @override
  void dispose() {
    _factCtrl.dispose();
    _obstacleCtrl.dispose();
    _nextCtrl.dispose();
    _customFigureCtrl.dispose();
    super.dispose();
  }

  List<String> get _figureOptions => GoalSettingFamousFigureCatalogX.figuresForCategories(_selectedFigureCategories);

  List<String> get _figureCategoryOptions => GoalSettingFamousFigureCatalog.categories.keys.toList();

  List<String> _parseFigureNames(String raw) {
    return raw
        .split(RegExp(r'[，,、；;\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> _effectiveRequestedFigures() {
    final custom = _parseFigureNames(_customFigureCtrl.text);
    if (custom.isNotEmpty) return custom;
    return _selectedFigures.where((e) => e.trim().isNotEmpty).toList();
  }

  List<String> _effectiveRequestedCategories() {
    return _selectedFigureCategories.where((e) => e.trim().isNotEmpty).toList();
  }

  Future<void> _loadLoopData() async {
    final records = await _dao.loadFactRecords(actionId: widget.action.id);
    final insight = await _dao.loadLoopInsight(widget.action.id);
    if (!mounted) return;
    setState(() {
      _records = records;
      _insight = insight;
    });
  }

  String _behaviorChainText() {
    final steps = widget.action.steps;
    if (steps.isEmpty) {
      return '''触发：想起这段课或遇到真实困境时
动作：立刻执行一个最小动作
留痕：完成后写1条事实记录
反馈：记录阻碍、结果与下一步。''';
    }
    final first = steps.isNotEmpty ? steps[0] : '先开始';
    final second = steps.length > 1 ? steps[1] : '继续推进';
    final rest = steps.length > 2 ? steps.sublist(2).join('；') : '完成后记录结果';
    return '''触发：当你在现实里再次遇到「${widget.segment?.title ?? widget.action.segmentTitle}」相关困境时。
第1步：$first
第2步：$second
第3步：$rest
留痕：完成后立刻写下事实、反馈与结果。
闭环：根据事实记录，用 AI 提炼下一轮行为链。''';
  }

  Future<void> _persistStatus(String status) async {
    _status = status;
    await widget.onSave(widget.action.copyWith(status: status, factLog: '', obstacleNote: '', nextStepNote: ''));
  }

  Future<void> _addFactRecord() async {
    final fact = _factCtrl.text.trim();
    final feedback = _obstacleCtrl.text.trim();
    final result = _nextCtrl.text.trim();
    if (fact.isEmpty && feedback.isEmpty && result.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先至少填写一条事实、反馈或结果')));
      return;
    }
    final record = GoalSettingFactRecord(
      id: 'gs_fact_${DateTime.now().millisecondsSinceEpoch}',
      actionId: widget.action.id,
      segmentId: widget.action.segmentId,
      actionTitle: widget.action.title,
      fact: fact,
      feedback: feedback,
      result: result,
      evidence: fact.isNotEmpty ? '文本事实记录' : '文本反馈记录',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _dao.saveFactRecord(record);
    await widget.onSave(widget.action.copyWith(status: _status, factLog: '', obstacleNote: '', nextStepNote: ''));
    _factCtrl.clear();
    _obstacleCtrl.clear();
    _nextCtrl.clear();
    await _loadLoopData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存一次事实记录与反馈')));
  }

  Future<void> _deleteFactRecord(GoalSettingFactRecord record) async {
    await widget.onDeleteFactRecord(record.id);
    await _loadLoopData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除这条事实记录')));
  }

  Future<void> _clearFactRecords() async {
    await widget.onClearFactRecords(widget.action.id);
    await _loadLoopData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清空该行动下的全部事实记录')));
  }

  Future<void> _generateLoopInsight() async {
    final segment = widget.segment;
    if (segment == null) return;
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先点击“保存一次事实记录”，再让 AI 做经验归纳。')));
      return;
    }
    setState(() => _loadingLoop = true);
    final insight = await widget.ai.generateLoopInsight(
      segment: segment,
      action: widget.action,
      records: _records,
      actionStatus: _status,
      figureCategories: _effectiveRequestedCategories(),
      selectedFigures: _selectedFigures.toList(),
      customFigures: _parseFigureNames(_customFigureCtrl.text),
    );
    await _dao.saveLoopInsight(insight);
    if (!insight.usedFallback) {
      final autoReview = _buildReviewFromInsight(insight);
      if (autoReview != null) {
        await widget.onSaveReview(autoReview);
      }
    }
    if (!mounted) return;
    setState(() {
      _insight = insight;
      _loadingLoop = false;
    });
    final msg = insight.usedFallback
        ? (insight.generationNote.trim().isEmpty ? 'AI 返回内容无法直接显示，已回退到本地闭环模板' : insight.generationNote.trim())
        : '已根据 ${insight.modelLabel} 生成行动闭环总结，并自动写入历史闭环记录';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  GoalSettingReview? _buildReviewFromInsight(GoalSettingActionLoopInsight? insight) {
    final segment = widget.segment;
    if (segment == null || insight == null || _records.isEmpty) return null;
    final latest = _records.first;
    final summary = insight.closureSummary.trim().isNotEmpty
        ? insight.closureSummary.trim()
        : widget.ai.buildReviewSummary(segment: segment, fact: latest.fact, feeling: latest.feedback, action: widget.action.title, result: latest.result);
    final reviewExtraSections = <String, dynamic>{
      ...?insight.extraSections,
      if (insight.experienceRecap.trim().isNotEmpty) 'experience_recap_full': insight.experienceRecap,
    }..removeWhere((key, value) => key == 'AI 原始返回（宽松展示）');
    return GoalSettingReview(
      id: 'gsr_${latest.id}_${latest.createdAt}',
      segmentId: segment.id,
      segmentTitle: segment.title,
      fact: latest.fact,
      feeling: latest.feedback,
      action: widget.action.title,
      result: latest.result,
      summary: summary,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      evidenceBasis: insight.evidenceBasis,
      learningSummary: insight.resultReasonAnalysis,
      abstractConcept: insight.patternInduction,
      retrospectiveGuidance: insight.retrospectiveGuidance,
      retryPlan: insight.retryPlanSteps,
      courseAnchor: segment.whatText,
      sourceActionTitle: widget.action.title,
      resultJudgement: insight.resultJudgement,
      resultReasonAnalysis: insight.resultReasonAnalysis,
      strengthsFound: insight.strengthsFound,
      weaknessesOrBlindspots: insight.weaknessesOrBlindspots,
      patternInduction: insight.patternInduction,
      relatedKnowledgeConcepts: insight.relatedKnowledgeConcepts,
      theoryElevation: insight.theoryElevation,
      courseConnection: insight.courseConnection,
      retryPlanTitle: insight.retryPlanTitle,
      retryVisualPlan: insight.retryVisualPlan,
      extraSections: reviewExtraSections,
    );
  }

  Future<void> _saveReview() async {
    final review = _buildReviewFromInsight(_insight);
    if (review == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先保存事实记录并生成一次有效闭环总结。')));
      return;
    }
    await widget.onSaveReview(review);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已写入复盘中心')));
  }


  @override
  Widget build(BuildContext context) {
    final latest = _records.isEmpty ? null : _records.first;
    return Scaffold(
      appBar: AppBar(title: Text(widget.action.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(title: '行动说明', body: widget.action.body),
          const SizedBox(height: 10),
          _SectionCard(title: '行为链', body: _behaviorChainText()),
          const SizedBox(height: 10),
          _SectionCard(title: '步骤', body: widget.action.steps.map((e) => '• $e').join('\n')),
          const SizedBox(height: 10),
          _SectionCard(title: '完成标准', body: widget.action.successCriteria),
          const SizedBox(height: 10),
          _SectionCard(title: '失败后的降级动作', body: widget.action.fallbackAction),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _status,
            items: const [
              DropdownMenuItem(value: 'todo', child: Text('待开始')),
              DropdownMenuItem(value: 'doing', child: Text('进行中')),
              DropdownMenuItem(value: 'done', child: Text('已完成')),
            ],
            onChanged: (v) {
              final next = v ?? 'todo';
              setState(() => _status = next);
              _persistStatus(next);
            },
            decoration: const InputDecoration(labelText: '当前状态', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(controller: _factCtrl, maxLines: 4, decoration: const InputDecoration(labelText: '事实记录（发生了什么）', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _obstacleCtrl, maxLines: 4, decoration: const InputDecoration(labelText: '反馈 / 阻碍 / 感受', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _nextCtrl, maxLines: 4, decoration: const InputDecoration(labelText: '结果 / 下一步', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _addFactRecord, child: const Text('保存一次事实记录')),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            elevation: 1,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('名人思想定向匹配（可选）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('可选择哲学、心理学、文学、诗人中的高影响力代表人物，让 AI 在行动闭环时额外评估你当前经验与该人物思想或经验结构的匹配度。也可直接输入自定义名人。', style: TextStyle(color: Color(0xFF6B7280))),
                  const SizedBox(height: 12),
                  const Text('可跨类别多选人物类别（支持同时选择哲学、心理学、文学、诗人）', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _figureCategoryOptions.map((category) {
                      final selected = _selectedFigureCategories.contains(category);
                      return FilterChip(
                        label: Text(category),
                        selected: selected,
                        onSelected: (value) => setState(() {
                          if (value) {
                            _selectedFigureCategories.add(category);
                          } else {
                            _selectedFigureCategories.remove(category);
                            final valid = _figureOptions.toSet();
                            _selectedFigures.removeWhere((e) => !valid.contains(e));
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  if (_selectedFigureCategories.isNotEmpty) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text('可跨类别多选默认人物（Top30）', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _selectedFigures
                              ..clear()
                              ..addAll(_figureOptions);
                          }),
                          child: const Text('全选'),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _selectedFigures.clear()),
                          child: const Text('清空'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _figureOptions.map((name) {
                        final selected = _selectedFigures.contains(name);
                        return FilterChip(
                          label: Text(name),
                          selected: selected,
                          onSelected: (value) => setState(() {
                            if (value) {
                              _selectedFigures.add(name);
                            } else {
                              _selectedFigures.remove(name);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: _customFigureCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '或输入自定义名人（支持多个，逗号/顿号/换行分隔；优先于默认人物）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _effectiveRequestedFigures().isEmpty
                        ? '当前未指定人物，AI 将按通用历史人物匹配逻辑处理。'
                        : '当前将优先围绕以下名人进行定向匹配分析：${_effectiveRequestedFigures().join('、')}',
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '最近一次事实记录',
            body: latest == null ? '还没有事实记录。先完成一次真实动作，再留下发生了什么、遇到什么阻碍、结果如何。' : '事实：${latest.fact}\n\n反馈：${latest.feedback}\n\n结果：${latest.result}',
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            elevation: 1,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('已保存的事实记录（历史输入数据）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                      TextButton(
                        onPressed: _records.isEmpty
                            ? null
                            : () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('清空事实记录'),
                                    content: const Text('确定清空该行动下的全部事实记录吗？'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
                                      FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('清空')),
                                    ],
                                  ),
                                );
                                if (ok == true) await _clearFactRecords();
                              },
                        child: const Text('清空全部'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_records.isEmpty)
                    const Text('还没有保存的事实记录。')
                  else
                    ..._records.map((record) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              title: Text(record.fact.trim().isEmpty ? '（无事实文本）' : record.fact, maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text('反馈：${record.feedback.isEmpty ? '—' : record.feedback}\n结果：${record.result.isEmpty ? '—' : record.result}', maxLines: 3, overflow: TextOverflow.ellipsis),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text('删除事实记录'),
                                      content: const Text('确定删除这条事实记录吗？'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
                                        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('删除')),
                                      ],
                                    ),
                                  );
                                  if (ok == true) await _deleteFactRecord(record);
                                },
                              ),
                            ),
                          ),
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            elevation: 1,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('AI 行动闭环总结', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                      FilledButton.tonal(
                        onPressed: _loadingLoop ? null : _generateLoopInsight,
                        child: Text(_loadingLoop ? '生成中…' : (_insight == null ? '用AI总结这一轮' : '重新生成闭环')), 
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('这里会把“事实 → 结果判断 → 原因分析 → 优势与盲点 → 相关知识概念 → 复盘指导 → 重新挑战计划”串成闭环。', style: const TextStyle(color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('配置本模块 AI 提示词'),
                    ),
                  ),
                  if (_insight != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _insight!.usedFallback ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _insight!.usedFallback ? const Color(0xFFF59E0B) : const Color(0xFF22C55E)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _insight!.usedFallback ? '结果来源：本地回退模板' : '结果来源：${_insight!.modelLabel}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (_insight!.generationNote.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(_insight!.generationNote, style: const TextStyle(color: Color(0xFF6B7280))),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildLoopDebugPanel(context, _insight!),
                    const SizedBox(height: 10),
                    for (final section in _buildLoopInsightDisplaySections(_insight!)) ...[
                      const SizedBox(height: 10),
                      _SectionCard(title: section.key, body: section.value),
                    ],
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: OutlinedButton(onPressed: _saveReview, child: const Text('写入复盘中心'))),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GoalSettingReviewDetailPage extends StatelessWidget {
  final GoalSettingReview review;
  final GoalSettingSegment? segment;
  final Future<void> Function()? onDelete;
  const GoalSettingReviewDetailPage({super.key, required this.review, this.segment, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('复盘详情'), actions: [if (onDelete != null) IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('删除复盘记录'), content: const Text('确定删除这条复盘记录吗？'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('删除'))],)); if (ok == true) { await onDelete!.call(); if (context.mounted) Navigator.of(context).maybePop(); } })]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(review.segmentTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (review.learningSummary.isNotEmpty ||
              review.abstractConcept.isNotEmpty ||
              review.retryPlan.isNotEmpty ||
              review.resultJudgement.isNotEmpty ||
              review.retrospectiveGuidance.isNotEmpty ||
              review.extraSections.isNotEmpty) ...[
            for (final section in _buildLoopReviewDisplaySections(review)) ...[
              const SizedBox(height: 10),
              _SectionCard(title: section.key, body: section.value),
            ],
            if (review.courseAnchor.isNotEmpty || segment != null) ...[
              const SizedBox(height: 10),
              _SectionCard(title: '对应课程段落', body: review.courseAnchor.isNotEmpty ? review.courseAnchor : (segment?.title ?? review.segmentTitle)),
            ],
          ] else ...[
            _SectionCard(title: '事实', body: review.fact),
            const SizedBox(height: 10),
            _SectionCard(title: '感受', body: review.feeling),
            const SizedBox(height: 10),
            _SectionCard(title: '行动', body: review.action),
            const SizedBox(height: 10),
            _SectionCard(title: '结果', body: review.result),
            const SizedBox(height: 10),
            _SectionCard(title: '总结', body: review.summary),
            if (segment != null) ...[
              const SizedBox(height: 10),
              _SectionCard(title: '对应课程段落', body: segment!.title),
            ],
          ],
        ],
      ),
    );
  }
}

class _LectureQuickCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _LectureQuickCard({required this.title, required this.subtitle, required this.onTap});


  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 8),
              const Row(children: [Icon(Icons.library_books_outlined, size: 18), SizedBox(width: 6), Text('全文复习')]),
            ],
          ),
        ),
      ),
    );
  }
}

class GoalSettingLectureReaderPage extends StatelessWidget {
  final int lecture;
  final String title;
  final List<GoalSettingSegment> segments;
  final Set<String> done;
  final Future<void> Function(GoalSettingSegment segment) onOpenSegment;

  const GoalSettingLectureReaderPage({super.key, required this.lecture, required this.title, required this.segments, required this.done, required this.onOpenSegment});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _InfoCard(title: '全文复习模式', lines: <String>['本讲已完整导入 ${segments.length} 段原内容。', '你可以逐段点开学习，也可以直接顺序复习整讲。']),
          const SizedBox(height: 12),
          ...segments.map((segment) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(18),
                  child: ListTile(
                    onTap: () => onOpenSegment(segment),
                    leading: CircleAvatar(
                      backgroundColor: done.contains(segment.id) ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                      child: Text('${segment.indexInLecture}', style: TextStyle(color: done.contains(segment.id) ? const Color(0xFF166534) : const Color(0xFF1D4ED8), fontWeight: FontWeight.w800)),
                    ),
                    title: Text(segment.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(segment.originalText, maxLines: 3, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

String _zoneDescription(String zone) {
  switch (zone) {
    case '聚焦之塔':
      return '训练目标如何带来聚焦、资源调动与承诺感。';
    case '山路与意义':
      return '训练目标与幸福、方向感、过程体验之间的关系。';
    case '自我一致神殿':
      return '训练区分“我真想做”和“我以为我该做”的事。';
    case 'VIA 优势学院':
      return '训练识别真正的我，并用优势去走过程、解问题。';
    case 'Calling 三岔路':
      return '训练把工作和人生方向看成 job、career 还是 calling。';
    case '登月指挥部':
      return '训练 stretch goals、目标拆解与每日第一步。';
    default:
      return '把课程理论映射进一个可模拟的行动场景。';
  }
}

String _worldMissionForSegment(GoalSettingSegment segment) {
  if (segment.worldZone == '聚焦之塔') return '你站在迷雾塔前，必须先选定一个真正重要的目标，主路才会显现。';
  if (segment.worldZone == '山路与意义') return '你要在通往山顶的路上收集“方向感碎片”，体会幸福来自沿途，而不只是终点。';
  if (segment.worldZone == '自我一致神殿') return '你将与“真正的我”“外界期待”“恐惧自我”对话，辨认哪一个声音更值得跟随。';
  if (segment.worldZone == 'VIA 优势学院') return '你要在优势学院里激活一种最像你的能力，并用它解决一个具体问题。';
  if (segment.worldZone == 'Calling 三岔路') return '同一份任务会分出 job / career / calling 三条支线，你要体验不同解释带来的不同人生感受。';
  if (segment.worldZone == '登月指挥部') return '先设一个足够振奋的大目标，再拆成季度、月、周、今天的第一步，火箭才会点火。';
  return '把这段课程化成一个可模拟的任务，然后把选择映射回现实。';
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
        gradient: const LinearGradient(colors: [Color(0xFF111827), Color(0xFF334155)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Color(0xFFE5E7EB), height: 1.5)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: chips.map((e) => Chip(backgroundColor: Colors.white.withOpacity(0.12), label: Text(e, style: const TextStyle(color: Colors.white)))).toList()),
        ],
      ),
    );
  }
}

class _AiStateCard extends StatelessWidget {
  final Map<String, String> aiState;
  final VoidCallback onOpenSettings;
  const _AiStateCard({required this.aiState, required this.onOpenSettings});


  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy_outlined),
                const SizedBox(width: 8),
                Expanded(child: Text('当前 AI：${aiState['label'] ?? '未配置'}', style: const TextStyle(fontWeight: FontWeight.w700))),
                TextButton(onPressed: onOpenSettings, child: const Text('去设置')),
              ],
            ),
            const SizedBox(height: 6),
            Text(aiState['note'] ?? '', style: const TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Color(0xFF6B7280))), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))]),
    );
  }
}

class _PromptCard extends StatelessWidget {
  final String title;
  final String body;
  final String cta;
  final FutureOr<void> Function() onTap;
  const _PromptCard({required this.title, required this.body, required this.cta, required this.onTap});


  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.person_search_outlined, color: Color(0xFF1D4ED8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(body, style: const TextStyle(color: Color(0xFF6B7280), height: 1.5)),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      onPressed: () async { await onTap(); },
                      child: Text(cta),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  final GoalSettingPersonaProfile persona;
  const _PersonaCard({required this.persona});


  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: '你的现实映射档案',
      lines: <String>[
        '当前角色：${persona.lifeRole}',
        '当前焦点：${persona.currentFocus}',
        if (persona.currentProblem.trim().isNotEmpty) '当前困扰：${persona.currentProblem}',
        if (persona.currentGoal.trim().isNotEmpty) '当前目标：${persona.currentGoal}',
        if (persona.motivationBlock.trim().isNotEmpty) '常见阻碍：${persona.motivationBlock}',
      ],
    );
  }
}

class _NextSegmentCard extends StatelessWidget {
  final GoalSettingSegment segment;
  final bool done;
  final FutureOr<void> Function() onTap;
  const _NextSegmentCard({required this.segment, required this.done, required this.onTap});


  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: ListTile(
        onTap: () async { await onTap(); },
        title: const Text('推荐进入的下一段', style: TextStyle(color: Color(0xFF6B7280))),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(segment.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ),
        trailing: done ? const Icon(Icons.check_circle, color: Color(0xFF16A34A)) : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<String> lines;
  const _InfoCard({required this.title, required this.lines});


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...lines.map((e) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(e, style: const TextStyle(height: 1.5)))),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String body;
  const _SectionCard({required this.title, required this.body});


  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 5))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text(body, style: const TextStyle(height: 1.6))]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w700)),
      );
}

class _ActionDraftCard extends StatelessWidget {
  final GoalSettingAction action;
  final Future<void> Function() onSave;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onDelete;
  const _ActionDraftCard({required this.action, required this.onSave, this.onEdit, this.onDelete});

  String _sourceLabel() {
    switch (action.source) {
      case 'custom':
        return '自定义';
      case 'ai':
        return 'AI';
      default:
        return '本地';
    }
  }

  String _levelLabel() {
    switch (action.level) {
      case 'min':
        return '最小动作';
      case 'deep':
        return '挑战动作';
      case 'custom':
        return '自定义动作';
      default:
        return '标准动作';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(action.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(999)),
                child: Text('${_sourceLabel()} · ${_levelLabel()}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
              ),
            ],
          ),
          if (action.body.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(action.body, style: const TextStyle(height: 1.5)),
          ],
          if (action.steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...action.steps.map((e) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('• '), Expanded(child: Text(e))]))),
          ],
          if (action.successCriteria.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('完成标准：${action.successCriteria}', style: const TextStyle(color: Color(0xFF6B7280))),
          ],
          if (action.fallbackAction.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('降级动作：${action.fallbackAction}', style: const TextStyle(color: Color(0xFF6B7280))),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onEdit != null)
                OutlinedButton.icon(
                  onPressed: () async { await onEdit!(); },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
                ),
              if (onDelete != null)
                OutlinedButton.icon(
                  onPressed: () async { await onDelete!(); },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              FilledButton.tonal(onPressed: () async { await onSave(); }, child: const Text('加入行动清单')),
            ],
          ),
        ],
      ),
    );
  }
}
