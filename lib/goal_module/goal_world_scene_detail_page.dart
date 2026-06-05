import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'goal_action_runner_page.dart';
import 'goal_dao.dart';
import 'goal_models.dart';
import 'goal_segment_detail_page.dart';
import 'goal_workshop_page.dart';
import 'goal_world_profile_page.dart';
import 'goal_world_seed.dart';
import 'goal_world_identity_leap_detail_page.dart';
import 'goal_world_trend_detail_page.dart';

class GoalWorldSceneDetailPage extends StatefulWidget {
  final String sceneId;
  const GoalWorldSceneDetailPage({super.key, required this.sceneId});

  @override
  State<GoalWorldSceneDetailPage> createState() => _GoalWorldSceneDetailPageState();
}

class _GoalWorldSceneDetailPageState extends State<GoalWorldSceneDetailPage> {
  final _dao = GoalDao();
  late final GoalWorldSceneDef _scene;
  final _note = TextEditingController();
  final _simulationReflection = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _autosaveTimer;
  bool _restoreChecked = false;
  final Map<String, GlobalKey> _taskKeys = <String, GlobalKey>{};
  final Map<String, GlobalKey> _branchTaskKeys = <String, GlobalKey>{};
  Set<String> _completedTaskIds = <String>{};
  Set<String> _completedBranchTaskIds = <String>{};
  String _activeTaskId = '';
  String _activeBranchTaskId = '';
  bool _rewardClaimed = false;
  bool _saving = false;
  bool _loaded = false;
  String _simulationChoiceId = '';
  GoalWorldProfile _profile = GoalWorldProfile.empty();
  List<GoalSceneActionSuggestion> _recommendedActions = const <GoalSceneActionSuggestion>[];
  List<GoalWorldSimulationChoiceDef> _simulationChoices = const <GoalWorldSimulationChoiceDef>[];
  List<GoalWorldSceneProgress> _allProgress = const <GoalWorldSceneProgress>[];
  GoalWorldGrowthTrajectory _trajectory = const GoalWorldGrowthTrajectory.empty();
  GoalWorldIdentityEvolution _identityEvolution = const GoalWorldIdentityEvolution.empty();
  GoalWorldPracticeTimelineSummary _practiceTimeline = const GoalWorldPracticeTimelineSummary.empty();
  GoalWorldRecentIdentityLeapDetail _leapDetail = const GoalWorldRecentIdentityLeapDetail.empty();
  List<GoalWorldSevenDayTrendPoint> _sevenDayTrend = const <GoalWorldSevenDayTrendPoint>[];
  String _loadWarning = '';


  Future<T> _safeLoad<T>(Future<T> Function() loader, T fallback, String label, List<String> warnings) async {
    try {
      return await loader();
    } catch (e, st) {
      debugPrint('GoalWorldSceneDetailPage[$label] load failed: $e');
      debugPrintStack(stackTrace: st);
      warnings.add(label);
      return fallback;
    }
  }

  @override
  void initState() {
    super.initState();
    _scene = sceneById(widget.sceneId);
    _note.addListener(_scheduleAutosave);
    _simulationReflection.addListener(_scheduleAutosave);
    _scrollController.addListener(_scheduleAutosave);
    _load();
  }

  Future<void> _load() async {
    final warnings = <String>[];
    final progress = await _safeLoad(() => _dao.getWorldSceneProgress(widget.sceneId), GoalWorldSceneProgress.empty(widget.sceneId), 'scene_progress', warnings);
    final recommended = await _safeLoad(() => _dao.listRecommendedActionsForScene(widget.sceneId, limit: 8), const <GoalSceneActionSuggestion>[], 'scene_actions', warnings);
    final profile = await _safeLoad(() => _dao.getWorldProfile(), GoalWorldProfile.empty(), 'world_profile', warnings);
    final allProgress = await _safeLoad(() => _dao.listWorldSceneProgress(), const <GoalWorldSceneProgress>[], 'all_scene_progress', warnings);
    final trajectory = await _safeLoad(() => _dao.getWorldGrowthTrajectory(limit: 5), const GoalWorldGrowthTrajectory.empty(), 'growth_trajectory', warnings);
    final identityEvolution = await _safeLoad(() => _dao.getWorldIdentityEvolution(), const GoalWorldIdentityEvolution.empty(), 'identity_evolution', warnings);
    final practiceTimeline = await _safeLoad(() => _dao.getWorldPracticeTimelineSummary(), const GoalWorldPracticeTimelineSummary.empty(), 'practice_timeline', warnings);
    final leapDetail = await _safeLoad(() => _dao.getRecentIdentityLeapDetail(), const GoalWorldRecentIdentityLeapDetail.empty(), 'recent_identity_leap', warnings);
    final sevenDayTrend = await _safeLoad(() => _dao.getWorldSevenDayTrend(), const <GoalWorldSevenDayTrendPoint>[], 'seven_day_trend', warnings);
    final choices = simulationChoicesForScene(
      scene: _scene,
      roleTitle: profile.roleTitle,
      lifeArea: profile.lifeArea,
      realEvent: profile.realEvent,
      desiredIdentity: profile.desiredIdentity,
    );
    if (!mounted) return;
    final nextCompletedTaskIds = progress.completedTaskIds.toSet();
    final nextSimulationChoiceId = progress.simulationChoiceId;
    final nextCompletedBranchTaskIds = progress.completedBranchTaskIds.toSet();
    setState(() {
      _profile = profile;
      _simulationChoices = choices;
      _completedTaskIds = nextCompletedTaskIds;
      _activeTaskId = progress.activeTaskId.trim().isNotEmpty ? progress.activeTaskId.trim() : _firstIncompleteTaskId(nextCompletedTaskIds);
      _completedBranchTaskIds = nextCompletedBranchTaskIds;
      _simulationChoiceId = nextSimulationChoiceId;
      _activeBranchTaskId = progress.activeBranchTaskId.trim().isNotEmpty
          ? progress.activeBranchTaskId.trim()
          : _firstIncompleteBranchTaskId(nextCompletedBranchTaskIds, nextSimulationChoiceId);
      _rewardClaimed = progress.rewardClaimed;
      if (_note.text != progress.realityNote) {
        _note.text = progress.realityNote;
      }
      if (_simulationReflection.text != progress.simulationReflection) {
        _simulationReflection.text = progress.simulationReflection;
      }
      _recommendedActions = recommended;
      _allProgress = allProgress;
      _trajectory = trajectory;
      _identityEvolution = identityEvolution;
      _practiceTimeline = practiceTimeline;
      _leapDetail = leapDetail;
      _sevenDayTrend = sevenDayTrend;
      _loaded = true;
      _loadWarning = warnings.isEmpty ? '' : '部分世界数据加载失败，已回退到基础内容：${warnings.join('、')}';
    });
  }

  void _scheduleAutosave() {

    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 350), _persistDraftState);
  }

  String _firstIncompleteTaskId(Set<String> completed) {
    for (final task in _scene.tasks) {
      if (!completed.contains(task.taskId)) return task.taskId;
    }
    return _scene.tasks.isNotEmpty ? _scene.tasks.first.taskId : '';
  }

  String _taskTitleById(String taskId) {
    for (final task in _scene.tasks) {
      if (task.taskId == taskId) return task.title;
    }
    return '';
  }

  List<GoalWorldBranchTaskDef> get _branchTasks => branchTasksForSceneChoice(sceneId: _scene.sceneId, choiceId: _simulationChoiceId);

  String _firstIncompleteBranchTaskId(Set<String> completed, String choiceId) {
    final tasks = branchTasksForSceneChoice(sceneId: _scene.sceneId, choiceId: choiceId);
    for (final task in tasks) {
      if (!completed.contains(task.taskId)) return task.taskId;
    }
    return tasks.isNotEmpty ? tasks.first.taskId : '';
  }

  String _branchTaskTitleById(String taskId) {
    for (final task in _branchTasks) {
      if (task.taskId == taskId) return task.title;
    }
    return '';
  }

  GoalWorldSimulationChoiceDef? get _selectedSimulationChoice {
    for (final item in _simulationChoices) {
      if (item.choiceId == _simulationChoiceId) return item;
    }
    return null;
  }

  GoalWorldRecommendationRule get _recommendationRule => recommendationRuleForChoice(_simulationChoiceId);

  List<GoalSceneActionSuggestion> get _displayedRecommendedActions {
    if (_recommendedActions.isEmpty) return const <GoalSceneActionSuggestion>[];
    if (_simulationChoiceId.trim().isEmpty) return _recommendedActions.take(3).toList();
    final rule = _recommendationRule;
    int scoreFor(GoalSceneActionSuggestion item) {
      var score = 0;
      final segmentIndex = rule.preferredSegmentIds.indexOf(item.action.segmentId);
      if (segmentIndex >= 0) score += 200 - (segmentIndex * 20);
      final levelIndex = rule.preferredActionLevels.indexOf(item.action.actionLevel);
      if (levelIndex >= 0) score += 80 - (levelIndex * 10);
      if (item.action.actionLevel == '微行动') score += 5;
      return score;
    }

    final sorted = [..._recommendedActions]..sort((a, b) => scoreFor(b).compareTo(scoreFor(a)));
    return sorted.take(3).toList();
  }

  GoalWorldSceneProgress get _currentSceneSnapshot => GoalWorldSceneProgress(
        sceneId: _scene.sceneId,
        completedTaskIdsJson: json.encode(_completedTaskIds.toList()),
        realityNote: _note.text.trim(),
        rewardClaimed: _rewardClaimed,
        activeTaskId: _activeTaskId.trim(),
        rewardClaimedAtMs: 0,
        simulationChoiceId: _simulationChoiceId,
        simulationReflection: _simulationReflection.text.trim(),
        branchCompletedTaskIdsJson: json.encode(_completedBranchTaskIds.toList()),
        activeBranchTaskId: _activeBranchTaskId.trim(),
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );

  List<GoalWorldSceneProgress> get _mergedProgressList {
    final current = _currentSceneSnapshot;
    final list = <GoalWorldSceneProgress>[];
    var replaced = false;
    for (final item in _allProgress) {
      if (item.sceneId == _scene.sceneId) {
        list.add(current);
        replaced = true;
      } else {
        list.add(item);
      }
    }
    if (!replaced) list.add(current);
    return list;
  }

  GoalWorldRoleStatus get _roleStatus => computeWorldRoleStatus(profile: _profile, progressList: _mergedProgressList);

  GoalWorldBranchOutcomeDef? get _branchOutcome => branchOutcomeForSceneChoice(
        scene: _scene,
        profile: _profile,
        choiceId: _simulationChoiceId,
        reflection: _simulationReflection.text.trim(),
      );

  GoalWorldSceneStateShift? get _incomingStateShift => incomingSceneStateShift(
        sceneId: _scene.sceneId,
        progressList: _allProgress,
        profile: _profile,
      );

  List<GoalWorldSceneStateShift> get _outgoingStateShifts => _simulationChoiceId.trim().isEmpty
      ? const <GoalWorldSceneStateShift>[]
      : sceneStateShiftsForChoice(sceneId: _scene.sceneId, choiceId: _simulationChoiceId, profile: _profile);

  void _markActiveTask(String taskId) {
    _activeTaskId = taskId;
    _scheduleAutosave();
  }

  void _markActiveBranchTask(String taskId) {
    _activeBranchTaskId = taskId;
    _scheduleAutosave();
  }

  void _updateSimulationChoice(String choiceId) {
    final changed = _simulationChoiceId != choiceId;
    setState(() {
      _simulationChoiceId = choiceId;
      if (changed) {
        _completedBranchTaskIds = <String>{};
        _activeBranchTaskId = _firstIncompleteBranchTaskId(_completedBranchTaskIds, choiceId);
      } else if (_activeBranchTaskId.trim().isEmpty) {
        _activeBranchTaskId = _firstIncompleteBranchTaskId(_completedBranchTaskIds, choiceId);
      }
    });
    _scheduleAutosave();
  }

  Future<void> _persistDraftState() async {
    final activeTaskId = _activeTaskId.trim().isNotEmpty ? _activeTaskId.trim() : _firstIncompleteTaskId(_completedTaskIds);
    await _dao.saveWorldSceneProgress(
      sceneId: _scene.sceneId,
      completedTaskIds: _completedTaskIds.toList(),
      realityNote: _note.text.trim(),
      rewardClaimed: _rewardClaimed,
      activeTaskId: activeTaskId,
      simulationChoiceId: _simulationChoiceId,
      simulationReflection: _simulationReflection.text.trim(),
      completedBranchTaskIds: _completedBranchTaskIds.toList(),
      activeBranchTaskId: _activeBranchTaskId.trim(),
    );
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    _allProgress = _mergedProgressList;
    await _dao.saveContinueState(
      stateKey: 'last_scene',
      targetId: _scene.sceneId,
      scrollOffset: offset,
      extra: {
        'title': _scene.title,
        'activeTaskId': activeTaskId,
        'activeBranchTaskId': _activeBranchTaskId.trim(),
        'activeTaskTitle': _taskTitleById(activeTaskId),
        'rewardTitle': _rewardClaimed ? _scene.rewardTitle : '',
      },
    );
  }

  Future<void> _restorePositionIfNeeded() async {
    if (_restoreChecked) return;
    _restoreChecked = true;
    final state = await _dao.getContinueState('last_scene');
    if (!mounted || state.targetId != _scene.sceneId) return;
    final extra = state.extraMap;
    final activeTaskId = (extra['activeTaskId'] ?? '').trim();
    if (activeTaskId.isNotEmpty) {
      _activeTaskId = activeTaskId;
    }
    final activeBranchTaskId = (extra['activeBranchTaskId'] ?? '').trim();
    if (activeBranchTaskId.isNotEmpty) {
      _activeBranchTaskId = activeBranchTaskId;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetKey = _taskKeys[activeTaskId] ?? _branchTaskKeys[activeBranchTaskId];
      final targetContext = targetKey?.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(targetContext, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        return;
      }
      final offset = state.scrollOffset;
      if (!_scrollController.hasClients || offset <= 0) return;
      final max = _scrollController.position.maxScrollExtent;
      final target = offset.clamp(0.0, max);
      _scrollController.jumpTo(target);
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _persistDraftState();
    _note.dispose();
    _simulationReflection.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _allDone => _completedTaskIds.length == _scene.tasks.length;
  bool get _branchAllDone => _branchTasks.isEmpty || _completedBranchTaskIds.length >= _branchTasks.length;
  bool get _effectiveAllDone => _allDone && _branchAllDone;

  Future<void> _save({bool claimReward = false, bool openWorkshop = false}) async {
    if (claimReward && _note.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先写下你这一关在现实里的收获或方向。')));
      return;
    }
    setState(() => _saving = true);
    final shouldClaim = claimReward || _rewardClaimed;
    if (claimReward && !_effectiveAllDone) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先完成当前分支解锁的后续任务，再领取场景奖励。')));
      setState(() => _saving = false);
      return;
    }
    final activeTaskId = _activeTaskId.trim().isNotEmpty ? _activeTaskId.trim() : _firstIncompleteTaskId(_completedTaskIds);
    await _dao.saveWorldSceneProgress(
      sceneId: _scene.sceneId,
      completedTaskIds: _completedTaskIds.toList(),
      realityNote: _note.text.trim(),
      rewardClaimed: shouldClaim,
      activeTaskId: activeTaskId,
      rewardClaimedAtMs: shouldClaim ? DateTime.now().millisecondsSinceEpoch : null,
      simulationChoiceId: _simulationChoiceId,
      simulationReflection: _simulationReflection.text.trim(),
      completedBranchTaskIds: _completedBranchTaskIds.toList(),
      activeBranchTaskId: _activeBranchTaskId.trim(),
    );
    if (claimReward) {
      await _dao.mergeWorldSceneIntoWorkshop(sceneId: _scene.sceneId, realityNote: _note.text.trim());
    }
    if (!mounted) return;
    setState(() {
      _rewardClaimed = shouldClaim;
      _allProgress = _mergedProgressList;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(claimReward ? '已领取${_scene.rewardTitle}，并同步到目标工坊。' : '场景进度已保存。')),
    );
    if (claimReward && openWorkshop) {
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const GoalWorkshopPage()));
    }
  }

  Future<void> _openRecommendedAction(GoalSceneActionSuggestion item) async {
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => GoalActionRunnerPage(
          action: item.action,
          conceptTitle: item.conceptTitle,
          segmentTitle: item.segmentTitle,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已从试验场进入行动执行，并记录到行动闭环。')));
    }
  }

  Future<void> _openProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(builder: (_) => const GoalWorldProfilePage()),
    );
    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: Text(_scene.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final progress = _scene.tasks.isEmpty ? 0.0 : _completedTaskIds.length / _scene.tasks.length;
    _restorePositionIfNeeded();
    return Scaffold(
      appBar: AppBar(title: Text(_scene.title)),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          if (_loadWarning.trim().isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFB45309)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _loadWarning,
                      style: const TextStyle(color: Color(0xFF92400E), height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _scene.accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.explore_outlined, color: _scene.accentColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_scene.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(_scene.subtitle, style: const TextStyle(color: Color(0xFF4B5563), height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(_scene.accentColor),
                ),
                const SizedBox(height: 8),
                Text('已完成 ${_completedTaskIds.length}/${_scene.tasks.length} 个场景任务', style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 14),
                Text(_scene.mission, style: const TextStyle(height: 1.65, color: Color(0xFF374151))),
                if (_activeTaskId.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _scene.accentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('上次停在的任务', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                        const SizedBox(height: 4),
                        Text(_taskTitleById(_activeTaskId), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            title: '现实角色镜像',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_profile.hasContent)
                  const Text('先把你的现实身份、正在发生的事件和感受带进来，这一关会更贴近你的真实世界。', style: TextStyle(color: Color(0xFF4B5563), height: 1.6))
                else ...[
                  Text(_profile.profileTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  if (_profile.summaryLine.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(_profile.summaryLine, style: const TextStyle(color: Color(0xFF4B5563), height: 1.55)),
                  ],
                  if (_profile.realEvent.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
                      child: Text('最近真实事件：${_profile.realEvent.trim()}', style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openProfile,
                  icon: const Icon(Icons.person_outline),
                  label: Text(_profile.hasContent ? '编辑世界身份' : '先构建世界身份'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            title: '角色状态面板',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_roleStatus.headline, style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _statusMetric('清晰度', _roleStatus.clarity)),
                    const SizedBox(width: 8),
                    Expanded(child: _statusMetric('一致性', _roleStatus.alignment)),
                    const SizedBox(width: 8),
                    Expanded(child: _statusMetric('行动势能', _roleStatus.momentum)),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('下一步聚焦：${_roleStatus.nextFocus}', style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_trajectory.hasData)
            _card(
              title: '持续成长轨迹',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_trajectory.headline, style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _deltaMetric('清晰度', _trajectory.latestSnapshot!.clarity, _trajectory.clarityDelta)),
                      const SizedBox(width: 8),
                      Expanded(child: _deltaMetric('一致性', _trajectory.latestSnapshot!.alignment, _trajectory.alignmentDelta)),
                      const SizedBox(width: 8),
                      Expanded(child: _deltaMetric('行动势能', _trajectory.latestSnapshot!.momentum, _trajectory.momentumDelta)),
                    ],
                  ),
                  if (_trajectory.recentSnapshots.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('最近一次成长变化：${_trajectory.recentSnapshots.first.note}', style: const TextStyle(color: Color(0xFF374151), height: 1.5)),
                  ],
                ],
              ),
            ),
          if (_trajectory.hasData) const SizedBox(height: 12),
          if (_identityEvolution.hasContent) ...[
            _card(
              title: '我正在成为什么样的人',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_identityEvolution.stageTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _scene.accentColor)),
                  if (_identityEvolution.stageSubtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(_identityEvolution.stageSubtitle, style: const TextStyle(color: Color(0xFF6B7280), height: 1.5)),
                  ],
                  const SizedBox(height: 8),
                  Text(_identityEvolution.headline, style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
                  if (_identityEvolution.evidence.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('当前演化证据：${_identityEvolution.evidence.take(2).join('；')}', style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_practiceTimeline.hasIdentityShift || _practiceTimeline.hasBeforeAfter || _practiceTimeline.hasStrongestScene) ...[
            _card(
              title: '这次变化在整条练习时间轴里的位置',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_practiceTimeline.hasIdentityShift) ...[
                    Text(_practiceTimeline.latestIdentityShift!.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _scene.accentColor)),
                    if (_practiceTimeline.latestIdentityShift!.body.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(_practiceTimeline.latestIdentityShift!.body, style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
                    ],
                  ],
                  if (_practiceTimeline.hasBeforeAfter) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _deltaMetric('清晰度', _practiceTimeline.latestSnapshot!.clarity, _practiceTimeline.clarityDelta)),
                        const SizedBox(width: 8),
                        Expanded(child: _deltaMetric('一致性', _practiceTimeline.latestSnapshot!.alignment, _practiceTimeline.alignmentDelta)),
                        const SizedBox(width: 8),
                        Expanded(child: _deltaMetric('行动势能', _practiceTimeline.latestSnapshot!.momentum, _practiceTimeline.momentumDelta)),
                      ],
                    ),
                  ],
                  if (_practiceTimeline.hasStrongestScene) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_practiceTimeline.strongestSceneId == _scene.sceneId ? _scene.accentColor.withOpacity(0.08) : const Color(0xFFF9FAFB)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _practiceTimeline.strongestSceneId == _scene.sceneId
                            ? '这一关最近最推动你的身份变化：${_practiceTimeline.strongestSceneReason.trim().isEmpty ? '继续把这里的收获带回现实。' : _practiceTimeline.strongestSceneReason}'
                            : '最近更推动这次变化的是：${_practiceTimeline.strongestSceneTitle}${_practiceTimeline.strongestSceneReason.trim().isEmpty ? '' : '。${_practiceTimeline.strongestSceneReason}'}',
                        style: const TextStyle(color: Color(0xFF374151), height: 1.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_leapDetail.hasShift || _leapDetail.hasBeforeAfter || _leapDetail.hasStrongestScene) ...[
            _card(
              title: '最近一次身份跃迁详情',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _leapDetail.headline.trim().isNotEmpty ? _leapDetail.headline : '最近一次明显的身份变化，会在这里显示出来。',
                    style: const TextStyle(color: Color(0xFF374151), height: 1.55),
                  ),
                  if (_leapDetail.hasBeforeAfter) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _deltaMetric('清晰度', _leapDetail.afterSnapshot!.clarity, _leapDetail.clarityDelta)),
                        const SizedBox(width: 8),
                        Expanded(child: _deltaMetric('一致性', _leapDetail.afterSnapshot!.alignment, _leapDetail.alignmentDelta)),
                        const SizedBox(width: 8),
                        Expanded(child: _deltaMetric('行动势能', _leapDetail.afterSnapshot!.momentum, _leapDetail.momentumDelta)),
                      ],
                    ),
                  ],
                  if (_leapDetail.evidence.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('变化证据：${_leapDetail.evidence.take(2).join('；')}', style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
                  ],
                  if (_leapDetail.hasStrongestScene) ...[
                    const SizedBox(height: 10),
                    Text(
                      _leapDetail.strongestSceneId == _scene.sceneId
                          ? '这一关最近最推动你的身份跃迁。'
                          : '最近更推动这次变化的是：${_leapDetail.strongestSceneTitle}',
                      style: const TextStyle(color: Color(0xFF374151), height: 1.55),
                    ),
                  ],
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const GoalWorldIdentityLeapDetailPage())),
                    icon: const Icon(Icons.open_in_new_outlined),
                    label: const Text('展开跃迁详情'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_sevenDayTrend.any((e) => e.hasData)) ...[
            _card(
              title: '最近7天成长变化趋势',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('看看最近7天清晰度、一致性和行动势能，是在持续抬升、波动，还是停在原地。', style: TextStyle(color: Color(0xFF374151), height: 1.55)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final item in _sevenDayTrend)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (item.hasData)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _miniTrendBar(item.clarity, const Color(0xFF0EA5E9)),
                                        const SizedBox(width: 2),
                                        _miniTrendBar(item.alignment, const Color(0xFF8B5CF6)),
                                        const SizedBox(width: 2),
                                        _miniTrendBar(item.momentum, const Color(0xFFF59E0B)),
                                      ],
                                    )
                                  else
                                    const SizedBox(height: 64, child: Center(child: Text('—', style: TextStyle(color: Color(0xFF9CA3AF))))),
                                  const SizedBox(height: 6),
                                  Text(item.label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const GoalWorldTrendDetailPage())),
                    icon: const Icon(Icons.open_in_new_outlined),
                    label: const Text('查看趋势明细'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_incomingStateShift != null) ...[
            _card(
              title: '你带着的上一步影响',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_incomingStateShift!.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _scene.accentColor)),
                  const SizedBox(height: 8),
                  Text(_incomingStateShift!.description, style: const TextStyle(color: Color(0xFF374151), height: 1.6)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _card(
            title: '场景任务',
            child: Column(
              children: [
                for (final task in _scene.tasks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      key: _taskKeys.putIfAbsent(task.taskId, () => GlobalKey()),
                      onTap: () {
                        setState(() {
                          _markActiveTask(task.taskId);
                          if (_completedTaskIds.contains(task.taskId)) {
                            _completedTaskIds.remove(task.taskId);
                          } else {
                            _completedTaskIds.add(task.taskId);
                          }
                        });
                        _scheduleAutosave();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _completedTaskIds.contains(task.taskId)
                              ? _scene.accentColor.withOpacity(0.08)
                              : (_activeTaskId == task.taskId ? _scene.accentColor.withOpacity(0.04) : const Color(0xFFF9FAFB)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _completedTaskIds.contains(task.taskId)
                                ? _scene.accentColor.withOpacity(0.35)
                                : (_activeTaskId == task.taskId ? _scene.accentColor.withOpacity(0.25) : const Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _completedTaskIds.contains(task.taskId),
                              onChanged: (_) {
                                setState(() {
                                  _markActiveTask(task.taskId);
                                  if (_completedTaskIds.contains(task.taskId)) {
                                    _completedTaskIds.remove(task.taskId);
                                  } else {
                                    _completedTaskIds.add(task.taskId);
                                  }
                                });
                                _scheduleAutosave();
                              },
                              activeColor: _scene.accentColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w800))),
                                      if (_activeTaskId == task.taskId)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _scene.accentColor.withOpacity(0.14),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text('继续这里', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _scene.accentColor)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(task.description, style: const TextStyle(color: Color(0xFF4B5563), height: 1.55)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            title: '世界内决策模拟',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('把你的真实身份和正在发生的事代进这一关，先在世界里做一次选择，再把它翻译回现实。', style: TextStyle(color: Color(0xFF374151), height: 1.55)),
                const SizedBox(height: 10),
                for (final item in _simulationChoices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        _updateSimulationChoice(item.choiceId);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _simulationChoiceId == item.choiceId ? _scene.accentColor.withOpacity(0.08) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _simulationChoiceId == item.choiceId ? _scene.accentColor.withOpacity(0.35) : const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800))),
                                if (_simulationChoiceId == item.choiceId)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: _scene.accentColor.withOpacity(0.16), borderRadius: BorderRadius.circular(999)),
                                    child: Text('已选择', style: TextStyle(color: _scene.accentColor, fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(item.description, style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
                            const SizedBox(height: 8),
                            Text('提示：${item.reflectionPrompt}', style: const TextStyle(color: Color(0xFF6B7280), height: 1.55)),
                          ],
                        ),
                      ),
                    ),
                  ),
                TextField(
                  controller: _simulationReflection,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: '把这次世界内选择翻译回现实',
                    hintText: _selectedSimulationChoice?.reflectionPrompt ?? '写下：如果把这个选择带回现实，你准备怎么做？',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_branchOutcome != null) ...[
            _card(
              title: '分支后果预演',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_branchOutcome!.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _scene.accentColor)),
                  const SizedBox(height: 10),
                  _outcomeRow('短期效果', _branchOutcome!.immediateEffect),
                  const SizedBox(height: 8),
                  _outcomeRow('可能风险', _branchOutcome!.likelyRisk),
                  const SizedBox(height: 8),
                  _outcomeRow('现实实验', _branchOutcome!.realityExperiment),
                  const SizedBox(height: 8),
                  _outcomeRow('状态提示', _branchOutcome!.statusHint),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_outgoingStateShifts.isNotEmpty) ...[
            _card(
              title: '这次选择会改变的后续场景状态',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('你的分支不只影响这一关，也会改变后面场景的进入方式与练习重点。', style: TextStyle(color: Color(0xFF374151), height: 1.55)),
                  const SizedBox(height: 10),
                  for (final shift in _outgoingStateShifts)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _scene.accentColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shift.title, style: TextStyle(fontWeight: FontWeight.w800, color: _scene.accentColor)),
                          const SizedBox(height: 4),
                          Text(shift.description, style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_branchTasks.isNotEmpty) ...[
            _card(
              title: '分支后续任务',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '你当前的分支选择会额外解锁 ${_branchTasks.length} 条后续任务。只有把它们也做掉，场景奖励和推荐行动才会更贴合你这次的选择。',
                    style: const TextStyle(color: Color(0xFF374151), height: 1.55),
                  ),
                  const SizedBox(height: 10),
                  for (final task in _branchTasks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        key: _branchTaskKeys.putIfAbsent(task.taskId, () => GlobalKey()),
                        onTap: () {
                          setState(() {
                            _markActiveBranchTask(task.taskId);
                            if (_completedBranchTaskIds.contains(task.taskId)) {
                              _completedBranchTaskIds.remove(task.taskId);
                            } else {
                              _completedBranchTaskIds.add(task.taskId);
                            }
                          });
                          _scheduleAutosave();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _completedBranchTaskIds.contains(task.taskId)
                                ? _scene.accentColor.withOpacity(0.08)
                                : (_activeBranchTaskId == task.taskId ? _scene.accentColor.withOpacity(0.04) : const Color(0xFFF9FAFB)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _completedBranchTaskIds.contains(task.taskId)
                                  ? _scene.accentColor.withOpacity(0.35)
                                  : (_activeBranchTaskId == task.taskId ? _scene.accentColor.withOpacity(0.25) : const Color(0xFFE5E7EB)),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _completedBranchTaskIds.contains(task.taskId),
                                onChanged: (_) {
                                  setState(() {
                                    _markActiveBranchTask(task.taskId);
                                    if (_completedBranchTaskIds.contains(task.taskId)) {
                                      _completedBranchTaskIds.remove(task.taskId);
                                    } else {
                                      _completedBranchTaskIds.add(task.taskId);
                                    }
                                  });
                                  _scheduleAutosave();
                                },
                                activeColor: _scene.accentColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w800))),
                                        if (_activeBranchTaskId == task.taskId)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _scene.accentColor.withOpacity(0.14),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text('当前分支', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _scene.accentColor)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(task.description, style: const TextStyle(color: Color(0xFF4B5563), height: 1.55)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (!_branchAllDone)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
                      child: Text(
                        '分支后续任务已完成 ${_completedBranchTaskIds.length}/${_branchTasks.length} 条。完成后，系统会按你选的分支推荐更贴合的现实行动。',
                        style: const TextStyle(color: Color(0xFF6B7280), height: 1.55),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _card(
            title: '现实映射',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_scene.inputLabel, style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
                const SizedBox(height: 10),
                TextField(
                  controller: _note,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: '把你在这个场景里看清楚、决定好或准备执行的内容写下来。',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _rewardClaimed ? _scene.accentColor.withOpacity(0.08) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_rewardClaimed ? Icons.workspace_premium_outlined : Icons.card_giftcard_outlined, color: _scene.accentColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_scene.rewardTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(_scene.rewardDescription, style: const TextStyle(color: Color(0xFF4B5563), height: 1.55)),
                            const SizedBox(height: 6),
                            Text(_rewardClaimed ? '状态：已领取并同步到工坊' : (_effectiveAllDone ? '状态：基础任务与分支任务均完成，可领取奖励' : (_branchTasks.isNotEmpty ? '状态：完成基础任务 + 当前分支后续任务后可领取奖励' : '状态：完成全部任务后可领取奖励')), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_effectiveAllDone || _rewardClaimed) ...[
            const SizedBox(height: 12),
            _card(
              title: '推荐现实行动',
              child: _recommendedActions.isEmpty
                  ? const Text('当前场景还没有可用的行动模板。', style: TextStyle(color: Color(0xFF6B7280)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '完成场景后，下一步最好立刻做一个现实动作。${_recommendationRule.recommendationHint}',
                          style: const TextStyle(color: Color(0xFF4B5563), height: 1.6),
                        ),
                        const SizedBox(height: 10),
                        for (final item in _displayedRecommendedActions)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(item.action.actionTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _scene.accentColor.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(item.action.actionLevel, style: TextStyle(color: _scene.accentColor, fontSize: 12, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(item.conceptTitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                const SizedBox(height: 8),
                                Text(item.action.goalOfAction, style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () => _openRecommendedAction(item),
                                      icon: const Icon(Icons.play_circle_outline),
                                      label: const Text('直接进入执行'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => Navigator.of(context).push(
                                        CupertinoPageRoute(builder: (_) => GoalSegmentDetailPage(segmentId: item.action.segmentId)),
                                      ),
                                      icon: const Icon(Icons.menu_book_outlined),
                                      label: const Text('回看课程正文'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
          const SizedBox(height: 12),
          _card(
            title: '相关课程 / 快捷入口',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in _scene.relatedSegmentIds)
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => GoalSegmentDetailPage(segmentId: id))),
                        child: Text('查看 $id'),
                      ),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const GoalWorkshopPage())),
                      child: const Text('进入目标工坊'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : () => _save(),
              child: const Text('保存场景进度'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: _saving || !_effectiveAllDone ? null : () => _save(claimReward: true, openWorkshop: true),
              child: Text(_rewardClaimed ? '再次同步到目标工坊' : '领取奖励并同步到工坊'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTrendBar(int value, Color color) {
    final height = ((value <= 0 ? 6 : value) / 100.0 * 64.0).clamp(6.0, 64.0);
    return Container(
      width: 8,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _deltaMetric(String label, int value, int delta) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${delta >= 0 ? '+' : ''}$delta', style: TextStyle(fontSize: 12, color: delta >= 0 ? const Color(0xFF047857) : const Color(0xFFB91C1C))),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      );

  Widget _statusMetric(String label, int value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      );

  Widget _outcomeRow(String label, String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
          ],
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
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      );
}
