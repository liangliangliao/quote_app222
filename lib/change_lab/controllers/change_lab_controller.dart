import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../data/change_course_full_content.dart';
import '../data/change_lab_seed.dart';
import '../models/change_models.dart';
import '../services/change_lab_notification_bridge.dart';

class ChangeLabController extends ChangeNotifier {
  ChangeLabController()
      : concepts = ChangeLabSeed.concepts,
        diagnosisQuestions = ChangeLabSeed.buildQuestions(),
        reminders = ChangeLabSeed.buildReminderTemplates(ChangeLabSeed.concepts),
        aiPrompts = ChangeLabSeed.buildAiPromptTemplates(ChangeLabSeed.concepts),
        worldScenes = ChangeLabSeed.worldScenes,
        missionStages = ChangeLabSeed.worldMissionStages {
    for (final concept in concepts) {
      _progress[concept.id] = ChangeProgress(conceptId: concept.id);
    }
  }

  static const _stateFileName = 'change_lab_state_v1.json';

  final List<ChangeConcept> concepts;
  final List<DiagnosisQuestion> diagnosisQuestions;
  final List<ReminderTemplate> reminders;
  final List<AiPromptTemplate> aiPrompts;
  final List<WorldScene> worldScenes;
  final List<WorldMissionStage> missionStages;

  final Map<String, ChangeProgress> _progress = {};
  final List<ReflectionEntry> _reflections = [];
  final List<TaskRunRecord> _taskRuns = [];
  final List<ChangeTaskInstance> _taskInstances = [];
  final List<ReminderSchedule> _reminderSchedules = [];
  final Set<String> _deliveredReminderIds = <String>{};
  final Set<String> _seenRewardEventIds = <String>{};
  final Map<String, String> _diagnosisAnswers = {};
  final Map<String, WorldMissionRecord> _missionRecords = {};
  final List<WorldRewardEvent> _worldRewardEvents = [];
  final Map<String, CourseParagraphRecord> _courseParagraphRecords = {};

  DiagnosisResult? _diagnosisResult;
  WeeklyPlan? _weeklyPlan;
  String? _pinnedConceptId;
  String? _latestMilestoneMessage;
  bool _isInitialized = false;
  bool _isLoading = false;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  Map<String, ChangeProgress> get progress => _progress;
  List<ReflectionEntry> get reflections => List.unmodifiable(_reflections);
  List<TaskRunRecord> get taskRuns => List.unmodifiable(_taskRuns);
  List<ChangeTaskInstance> get taskInstances => List.unmodifiable(_taskInstances);
  List<ReminderSchedule> get reminderSchedules => List.unmodifiable(_reminderSchedules);
  Set<String> get deliveredReminderIds => Set.unmodifiable(_deliveredReminderIds);
  Set<String> get seenRewardEventIds => Set.unmodifiable(_seenRewardEventIds);
  Map<String, WorldMissionRecord> get missionRecords => Map.unmodifiable(_missionRecords);
  List<WorldRewardEvent> get worldRewardEvents => List.unmodifiable(_worldRewardEvents);
  Map<String, CourseParagraphRecord> get courseParagraphRecords => Map.unmodifiable(_courseParagraphRecords);
  DiagnosisResult? get diagnosisResult => _diagnosisResult;
  String? get pinnedConceptId => _pinnedConceptId;
  WeeklyPlan? get currentWeeklyPlan => _weeklyPlan;
  String? get latestMilestoneMessage => _latestMilestoneMessage;

  ChangeConcept conceptById(String id) => concepts.firstWhere((c) => c.id == id);

  ChangeTask taskById(String conceptId, String taskId) =>
      conceptById(conceptId).tasks.firstWhere((t) => t.id == taskId);

  Future<void> handleAppResumed() async {
    await syncNotificationBridge();
  }

  Future<void> syncNotificationBridge({bool force = false}) async {
    final schedules = dueReminderSchedules
        .where((e) => force || !_deliveredReminderIds.contains(e.id))
        .toList();
    if (schedules.isEmpty) return;
    final delivered = await ChangeLabNotificationBridge.syncDueReminders(
      schedules: schedules,
      hasDelivered: (id) => _deliveredReminderIds.contains(id),
      onDelivered: (id) => _deliveredReminderIds.add(id),
      conceptById: conceptById,
      taskById: taskById,
    );
    if (delivered > 0) {
      await _saveState();
      notifyListeners();
    }
  }

  WorldScene worldById(String id) => worldScenes.firstWhere((w) => w.id == id);

  WorldMissionStage missionById(String id) => missionStages.firstWhere((m) => m.id == id);

  ChangeProgress progressById(String conceptId) =>
      _progress[conceptId] ?? ChangeProgress(conceptId: conceptId);

  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _loadState();
      _ensureMissionState();
      _ensureWeeklyPlan();
      _syncReminderSchedules();
      unawaited(syncNotificationBridge());
    } catch (_) {
      _ensureMissionState();
      _ensureWeeklyPlan();
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<File> _stateFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_stateFileName');
  }

  Future<void> _loadState() async {
    final file = await _stateFile();
    if (!await file.exists()) return;
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return;
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;

    final progressMap = json['progress'] as Map<String, dynamic>? ?? const {};
    for (final entry in progressMap.entries) {
      final value = entry.value as Map<String, dynamic>? ?? const {};
      _progress[entry.key] = ChangeProgress(
        conceptId: entry.key,
        isRead: value['isRead'] == true,
        actionCount: (value['actionCount'] as num?)?.toInt() ?? 0,
        reflectionCount: (value['reflectionCount'] as num?)?.toInt() ?? 0,
      );
    }

    _reflections
      ..clear()
      ..addAll(((json['reflections'] as List<dynamic>?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .map(
            (e) => ReflectionEntry(
              conceptId: (e['conceptId'] ?? '').toString(),
              taskId: (e['taskId'] ?? '').toString(),
              text: (e['text'] ?? '').toString(),
              createdAt:
                  DateTime.tryParse((e['createdAt'] ?? '').toString()) ?? DateTime.now(),
            ),
          ));

    _taskRuns
      ..clear()
      ..addAll(((json['taskRuns'] as List<dynamic>?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .map(
            (e) => TaskRunRecord(
              conceptId: (e['conceptId'] ?? '').toString(),
              taskId: (e['taskId'] ?? '').toString(),
              taskType: TaskType.values.firstWhere(
                (v) => v.name == (e['taskType'] ?? 'main').toString(),
                orElse: () => TaskType.main,
              ),
              beforeText: (e['beforeText'] ?? '').toString(),
              actionText: (e['actionText'] ?? '').toString(),
              afterText: (e['afterText'] ?? '').toString(),
              beforeScore: (e['beforeScore'] as num?)?.toInt() ?? 3,
              afterScore: (e['afterScore'] as num?)?.toInt() ?? 3,
              createdAt:
                  DateTime.tryParse((e['createdAt'] ?? '').toString()) ?? DateTime.now(),
            ),
          ));

    _taskInstances
      ..clear()
      ..addAll(((json['taskInstances'] as List<dynamic>?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .map(
            (e) => ChangeTaskInstance(
              id: (e['id'] ?? '').toString(),
              conceptId: (e['conceptId'] ?? '').toString(),
              taskId: (e['taskId'] ?? '').toString(),
              taskType: TaskType.values.firstWhere(
                (v) => v.name == (e['taskType'] ?? 'main').toString(),
                orElse: () => TaskType.main,
              ),
              plannedFor:
                  DateTime.tryParse((e['plannedFor'] ?? '').toString()) ?? DateTime.now(),
              createdAt:
                  DateTime.tryParse((e['createdAt'] ?? '').toString()) ?? DateTime.now(),
              status: TaskInstanceStatus.values.firstWhere(
                (v) => v.name == (e['status'] ?? 'planned').toString(),
                orElse: () => TaskInstanceStatus.planned,
              ),
              assignedReason: (e['assignedReason'] ?? '').toString(),
              failureReason: (e['failureReason'] ?? '').toString(),
              parentInstanceId: (e['parentInstanceId'] as String?)?.trim(),
              isFromWeeklyPlan: e['isFromWeeklyPlan'] == true,
              startedAt: DateTime.tryParse((e['startedAt'] ?? '').toString()),
              completedAt: DateTime.tryParse((e['completedAt'] ?? '').toString()),
              failCount: (e['failCount'] as num?)?.toInt() ?? 0,
            ),
          ));


    _reminderSchedules
      ..clear()
      ..addAll(((json['reminderSchedules'] as List<dynamic>?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .map(
            (e) => ReminderSchedule(
              id: (e['id'] ?? '').toString(),
              instanceId: (e['instanceId'] ?? '').toString(),
              conceptId: (e['conceptId'] ?? '').toString(),
              taskId: (e['taskId'] ?? '').toString(),
              type: ReminderType.values.firstWhere(
                (v) => v.name == (e['type'] ?? 'pre').toString(),
                orElse: () => ReminderType.pre,
              ),
              scheduledFor: DateTime.tryParse((e['scheduledFor'] ?? '').toString()) ?? DateTime.now(),
              createdAt: DateTime.tryParse((e['createdAt'] ?? '').toString()) ?? DateTime.now(),
              title: (e['title'] ?? '').toString(),
              message: (e['message'] ?? '').toString(),
              status: ReminderScheduleStatus.values.firstWhere(
                (v) => v.name == (e['status'] ?? 'pending').toString(),
                orElse: () => ReminderScheduleStatus.pending,
              ),
              worldId: (e['worldId'] as String?)?.trim(),
              completedAt: DateTime.tryParse((e['completedAt'] ?? '').toString()),
            ),
          ));

    final planMap = json['weeklyPlan'] as Map<String, dynamic>?;
    if (planMap != null && planMap.isNotEmpty) {
      _weeklyPlan = WeeklyPlan(
        id: (planMap['id'] ?? '').toString(),
        weekKey: (planMap['weekKey'] ?? '').toString(),
        createdAt: DateTime.tryParse((planMap['createdAt'] ?? '').toString()) ?? DateTime.now(),
        focusConceptIds: ((planMap['focusConceptIds'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        taskInstanceIds: ((planMap['taskInstanceIds'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        summary: (planMap['summary'] ?? '').toString(),
      );
    }

    final diagnosisAnswers = json['diagnosisAnswers'] as Map<String, dynamic>? ?? const {};
    _diagnosisAnswers
      ..clear()
      ..addEntries(diagnosisAnswers.entries.map((e) => MapEntry(e.key, e.value.toString())));

    _deliveredReminderIds
      ..clear()
      ..addAll(((json['deliveredReminderIds'] as List<dynamic>?) ?? const []).map((e) => e.toString()));

    _seenRewardEventIds
      ..clear()
      ..addAll(((json['seenRewardEventIds'] as List<dynamic>?) ?? const []).map((e) => e.toString()));

    final missionMap = json['missionRecords'] as Map<String, dynamic>? ?? const {};
    _missionRecords
      ..clear()
      ..addEntries(missionMap.entries.map((entry) {
        final value = entry.value as Map<String, dynamic>? ?? const {};
        return MapEntry(
          entry.key,
          WorldMissionRecord(
            missionId: entry.key,
            progressCount: (value['progressCount'] as num?)?.toInt() ?? 0,
            unlockedAt: DateTime.tryParse((value['unlockedAt'] ?? '').toString()),
            completedAt: DateTime.tryParse((value['completedAt'] ?? '').toString()),
            rewardClaimedAt: DateTime.tryParse((value['rewardClaimedAt'] ?? '').toString()),
            lastProgressAt: DateTime.tryParse((value['lastProgressAt'] ?? '').toString()),
            contributionRunKeys: ((value['contributionRunKeys'] as List<dynamic>?) ?? const [])
                .map((e) => e.toString())
                .toList(),
          ),
        );
      }));

    _worldRewardEvents
      ..clear()
      ..addAll(((json['worldRewardEvents'] as List<dynamic>?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .map((e) => WorldRewardEvent(
                id: (e['id'] ?? '').toString(),
                worldId: (e['worldId'] ?? '').toString(),
                missionId: (e['missionId'] ?? '').toString(),
                title: (e['title'] ?? '').toString(),
                message: (e['message'] ?? '').toString(),
                createdAt: DateTime.tryParse((e['createdAt'] ?? '').toString()) ?? DateTime.now(),
              )));

    final paragraphMap = json['courseParagraphRecords'] as Map<String, dynamic>? ?? const {};
    _courseParagraphRecords
      ..clear()
      ..addEntries(paragraphMap.entries.map((entry) {
        final value = entry.value as Map<String, dynamic>? ?? const {};
        return MapEntry(
          entry.key,
          CourseParagraphRecord(
            id: entry.key,
            conceptId: (value['conceptId'] ?? '').toString(),
            sectionType: (value['sectionType'] ?? 'full').toString(),
            paragraphIndex: (value['paragraphIndex'] as num?)?.toInt() ?? 0,
            isFavorite: value['isFavorite'] == true,
            inReviewList: value['inReviewList'] == true,
            note: (value['note'] ?? '').toString(),
            updatedAt: DateTime.tryParse((value['updatedAt'] ?? '').toString()) ?? DateTime.now(),
          ),
        );
      }));

    _latestMilestoneMessage = (json['latestMilestoneMessage'] as String?)?.trim();

    final pinned = (json['pinnedConceptId'] as String?)?.trim();
    _pinnedConceptId = (pinned == null || pinned.isEmpty) ? null : pinned;

    if (_diagnosisAnswers.isNotEmpty) {
      calculateDiagnosis(notify: false);
    }
  }

  Future<void> _saveState() async {
    final file = await _stateFile();
    final json = <String, dynamic>{
      'progress': {
        for (final entry in _progress.entries)
          entry.key: {
            'isRead': entry.value.isRead,
            'actionCount': entry.value.actionCount,
            'reflectionCount': entry.value.reflectionCount,
          },
      },
      'reflections': _reflections
          .map(
            (e) => {
              'conceptId': e.conceptId,
              'taskId': e.taskId,
              'text': e.text,
              'createdAt': e.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'taskRuns': _taskRuns
          .map(
            (e) => {
              'conceptId': e.conceptId,
              'taskId': e.taskId,
              'taskType': e.taskType.name,
              'beforeText': e.beforeText,
              'actionText': e.actionText,
              'afterText': e.afterText,
              'beforeScore': e.beforeScore,
              'afterScore': e.afterScore,
              'createdAt': e.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'taskInstances': _taskInstances
          .map(
            (e) => {
              'id': e.id,
              'conceptId': e.conceptId,
              'taskId': e.taskId,
              'taskType': e.taskType.name,
              'plannedFor': e.plannedFor.toIso8601String(),
              'createdAt': e.createdAt.toIso8601String(),
              'status': e.status.name,
              'assignedReason': e.assignedReason,
              'failureReason': e.failureReason,
              'parentInstanceId': e.parentInstanceId,
              'isFromWeeklyPlan': e.isFromWeeklyPlan,
              'startedAt': e.startedAt?.toIso8601String(),
              'completedAt': e.completedAt?.toIso8601String(),
              'failCount': e.failCount,
            },
          )
          .toList(),

      'reminderSchedules': _reminderSchedules
          .map(
            (e) => {
              'id': e.id,
              'instanceId': e.instanceId,
              'conceptId': e.conceptId,
              'taskId': e.taskId,
              'type': e.type.name,
              'scheduledFor': e.scheduledFor.toIso8601String(),
              'createdAt': e.createdAt.toIso8601String(),
              'title': e.title,
              'message': e.message,
              'status': e.status.name,
              'worldId': e.worldId,
              'completedAt': e.completedAt?.toIso8601String(),
            },
          )
          .toList(),
      'weeklyPlan': _weeklyPlan == null
          ? null
          : {
              'id': _weeklyPlan!.id,
              'weekKey': _weeklyPlan!.weekKey,
              'createdAt': _weeklyPlan!.createdAt.toIso8601String(),
              'focusConceptIds': _weeklyPlan!.focusConceptIds,
              'taskInstanceIds': _weeklyPlan!.taskInstanceIds,
              'summary': _weeklyPlan!.summary,
            },
      'diagnosisAnswers': _diagnosisAnswers,
      'pinnedConceptId': _pinnedConceptId,
      'deliveredReminderIds': _deliveredReminderIds.toList(),
      'seenRewardEventIds': _seenRewardEventIds.toList(),
      'missionRecords': {
        for (final entry in _missionRecords.entries)
          entry.key: {
            'progressCount': entry.value.progressCount,
            'unlockedAt': entry.value.unlockedAt?.toIso8601String(),
            'completedAt': entry.value.completedAt?.toIso8601String(),
            'rewardClaimedAt': entry.value.rewardClaimedAt?.toIso8601String(),
            'lastProgressAt': entry.value.lastProgressAt?.toIso8601String(),
            'contributionRunKeys': entry.value.contributionRunKeys,
          },
      },
      'worldRewardEvents': _worldRewardEvents
          .map((e) => {
                'id': e.id,
                'worldId': e.worldId,
                'missionId': e.missionId,
                'title': e.title,
                'message': e.message,
                'createdAt': e.createdAt.toIso8601String(),
              })
          .toList(),
      'courseParagraphRecords': {
        for (final entry in _courseParagraphRecords.entries)
          entry.key: {
            'conceptId': entry.value.conceptId,
            'sectionType': entry.value.sectionType,
            'paragraphIndex': entry.value.paragraphIndex,
            'isFavorite': entry.value.isFavorite,
            'inReviewList': entry.value.inReviewList,
            'note': entry.value.note,
            'updatedAt': entry.value.updatedAt.toIso8601String(),
          },
      },
      'latestMilestoneMessage': _latestMilestoneMessage,
    };
    await file.writeAsString(jsonEncode(json));
  }

  void pinConcept(String conceptId) {
    _pinnedConceptId = conceptId;
    _ensureMissionState();
    _ensureWeeklyPlan(forceRegenerate: true);
    _syncReminderSchedules();
    unawaited(syncNotificationBridge());
    _persistAndNotify();
  }

  void clearPin() {
    _pinnedConceptId = null;
    _ensureWeeklyPlan(forceRegenerate: true);
    _syncReminderSchedules();
    _persistAndNotify();
  }

  void markConceptRead(String conceptId) {
    final progress = _progress[conceptId];
    if (progress == null || progress.isRead) return;
    progress.isRead = true;
    _ensureMissionState();
    _ensureWeeklyPlan();
    _syncReminderSchedules();
    unawaited(syncNotificationBridge());
    _persistAndNotify();
  }

  void startTaskInstance(String instanceId) {
    final index = _taskInstances.indexWhere((e) => e.id == instanceId);
    if (index == -1) return;
    final current = _taskInstances[index];
    if (current.status == TaskInstanceStatus.completed) return;
    _taskInstances[index] = current.copyWith(
      status: TaskInstanceStatus.inProgress,
      startedAt: current.startedAt ?? DateTime.now(),
    );
    _persistAndNotify();
  }

  void failTaskInstance(String instanceId, {String reason = ''}) {
    final index = _taskInstances.indexWhere((e) => e.id == instanceId);
    if (index == -1) return;
    final current = _taskInstances[index];
    _taskInstances[index] = current.copyWith(
      status: TaskInstanceStatus.failed,
      failureReason: reason,
      failCount: current.failCount + 1,
    );
    _syncReminderSchedules();
    unawaited(syncNotificationBridge());
    _persistAndNotify();
  }

  void skipTaskInstance(String instanceId, {String reason = ''}) {
    final index = _taskInstances.indexWhere((e) => e.id == instanceId);
    if (index == -1) return;
    final current = _taskInstances[index];
    _taskInstances[index] = current.copyWith(
      status: TaskInstanceStatus.skipped,
      failureReason: reason.isEmpty ? '本次先跳过，系统会在后续计划里再次安排。' : reason,
    );
    _syncReminderSchedules();
    _persistAndNotify();
  }

  ChangeTaskInstance? restartTaskInstance(String instanceId) {
    final index = _taskInstances.indexWhere((e) => e.id == instanceId);
    if (index == -1) return null;
    final current = _taskInstances[index];
    final concept = conceptById(current.conceptId);
    final fallbackTask = concept.tasks.firstWhere(
      (t) => t.type == TaskType.fallback,
      orElse: () => concept.tasks.first,
    );
    _taskInstances[index] = current.copyWith(status: TaskInstanceStatus.restarted);
    final instance = ChangeTaskInstance(
      id: _newInstanceId(current.conceptId, fallbackTask.id),
      conceptId: current.conceptId,
      taskId: fallbackTask.id,
      taskType: fallbackTask.type,
      plannedFor: DateTime.now(),
      createdAt: DateTime.now(),
      status: TaskInstanceStatus.planned,
      assignedReason: '失败后重启：先改成更小版本。',
      parentInstanceId: current.id,
      isFromWeeklyPlan: false,
    );
    _taskInstances.insert(0, instance);
    _recordRestartProgress(current);
    _ensureMissionState();
    _syncReminderSchedules();
    _persistAndNotify();
    return instance;
  }

  void completeTask({
    required String conceptId,
    required String taskId,
    String beforeText = '',
    String actionText = '',
    String afterText = '',
    int beforeScore = 3,
    int afterScore = 3,
  }) {
    final item = _progress[conceptId];
    if (item == null) return;
    item.isRead = true;
    item.actionCount += 1;
    final task = taskById(conceptId, taskId);
    final hasReflection = beforeText.trim().isNotEmpty ||
        actionText.trim().isNotEmpty ||
        afterText.trim().isNotEmpty ||
        beforeScore != afterScore;
    if (hasReflection) {
      item.reflectionCount += 1;
    }
    final record = TaskRunRecord(
      conceptId: conceptId,
      taskId: taskId,
      taskType: task.type,
      beforeText: beforeText,
      actionText: actionText,
      afterText: afterText,
      beforeScore: beforeScore,
      afterScore: afterScore,
      createdAt: DateTime.now(),
    );
    _taskRuns.insert(0, record);
    if (hasReflection) {
      _reflections.insert(
        0,
        ReflectionEntry(
          conceptId: conceptId,
          taskId: taskId,
          text: record.combinedReflection,
          createdAt: record.createdAt,
        ),
      );
    }
    _completeMatchingTaskInstance(conceptId: conceptId, taskId: taskId, completedAt: record.createdAt);
    _applyWorldProgressForRun(record);
    _ensureMissionState();
    _ensureWeeklyPlan();
    _syncReminderSchedules();
    _persistAndNotify();
  }

  void _completeMatchingTaskInstance({
    required String conceptId,
    required String taskId,
    required DateTime completedAt,
  }) {
    final candidates = _taskInstances.where(
      (e) => e.conceptId == conceptId &&
          e.taskId == taskId &&
          (e.status == TaskInstanceStatus.planned || e.status == TaskInstanceStatus.inProgress),
    );
    if (candidates.isEmpty) {
      _taskInstances.insert(
        0,
        ChangeTaskInstance(
          id: _newInstanceId(conceptId, taskId),
          conceptId: conceptId,
          taskId: taskId,
          taskType: taskById(conceptId, taskId).type,
          plannedFor: completedAt,
          createdAt: completedAt,
          status: TaskInstanceStatus.completed,
          assignedReason: '来自概念页直接完成。',
          completedAt: completedAt,
          startedAt: completedAt,
          isFromWeeklyPlan: false,
        ),
      );
      return;
    }
    final instance = candidates.first;
    final index = _taskInstances.indexWhere((e) => e.id == instance.id);
    _taskInstances[index] = instance.copyWith(
      status: TaskInstanceStatus.completed,
      completedAt: completedAt,
      startedAt: instance.startedAt ?? completedAt,
    );
  }

  int get completedConceptCount =>
      _progress.values.where((e) => e.status != ConceptStatus.unread).length;

  int get actedConceptCount =>
      _progress.values.where((e) => e.status.index >= ConceptStatus.acted.index).length;

  int get internalizedCount =>
      _progress.values.where((e) => e.status == ConceptStatus.internalized).length;

  double get consistencyScore {
    final totalActions = _progress.values.fold<int>(0, (sum, e) => sum + e.actionCount);
    final totalReflections = _progress.values.fold<int>(0, (sum, e) => sum + e.reflectionCount);
    return ((totalActions * 0.7) + (totalReflections * 0.3)) / 10.0;
  }

  int get totalActionCount => _progress.values.fold<int>(0, (sum, e) => sum + e.actionCount);

  int get todayActionCount =>
      _taskRuns.where((e) => _isSameDay(e.createdAt, DateTime.now())).length;

  int get weeklyActionCount =>
      _taskRuns.where((e) => DateTime.now().difference(e.createdAt).inDays < 7).length;

  double get averageReliefScore {
    if (_taskRuns.isEmpty) return 0;
    final deltas = _taskRuns.map((e) => (e.beforeScore - e.afterScore).toDouble()).toList();
    final total = deltas.fold<double>(0, (sum, e) => sum + e);
    return total / deltas.length;
  }

  int get streakDays {
    final days = _taskRuns
        .map((e) => DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) return 0;
    int streak = 0;
    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    for (final day in days) {
      if (day == cursor) {
        streak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      if (streak == 0 && day == cursor.subtract(const Duration(days: 1))) {
        streak += 1;
        cursor = day.subtract(const Duration(days: 1));
        continue;
      }
      break;
    }
    return streak;
  }

  List<ChangeConcept> conceptsByModule(String module) =>
      concepts.where((c) => c.module == module).toList();

  List<ChangeTask> tasksForConcept(String conceptId, {TaskType? filter}) {
    final tasks = conceptById(conceptId).tasks;
    if (filter == null) return tasks;
    return tasks.where((t) => t.type == filter).toList();
  }

  List<ReflectionEntry> reflectionsForConcept(String conceptId) =>
      _reflections.where((e) => e.conceptId == conceptId).toList();

  List<TaskRunRecord> taskRunsForConcept(String conceptId) =>
      _taskRuns.where((e) => e.conceptId == conceptId).toList();

  TaskRunRecord? lastTaskRunForConcept(String conceptId) {
    final list = taskRunsForConcept(conceptId);
    return list.isEmpty ? null : list.first;
  }

  List<TaskRunRecord> get recentTaskRuns => _taskRuns.take(10).toList();

  ChangeConcept? get pinnedConcept {
    if (_pinnedConceptId == null) return null;
    final matches = concepts.where((c) => c.id == _pinnedConceptId);
    return matches.isEmpty ? null : matches.first;
  }

  List<ChangeConcept> get suggestedToday {
    final diagnosisConcepts = _diagnosisResult?.recommendedConceptIds
            .where((id) => concepts.any((c) => c.id == id))
            .map(conceptById)
            .toList() ??
        [];

    final queue = <ChangeConcept>[];
    if (pinnedConcept != null) queue.add(pinnedConcept!);
    queue.addAll(diagnosisConcepts);
    queue.addAll(concepts.where((c) => progressById(c.id).status == ConceptStatus.unread));
    queue.addAll(concepts.where((c) => progressById(c.id).status == ConceptStatus.read));

    final unique = <String>{};
    return queue.where((c) => unique.add(c.id)).take(3).toList();
  }

  List<ChangeTaskInstance> get todayTaskInstances {
    final today = DateTime.now();
    final list = _taskInstances.where((e) => _isSameDay(e.plannedFor, today)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  List<ChangeTaskInstance> get weeklyTaskInstances {
    final now = DateTime.now();
    return _taskInstances.where((e) => e.plannedFor.difference(now).inDays <= 6 && e.plannedFor.difference(now).inDays >= -1).toList()
      ..sort((a, b) => a.plannedFor.compareTo(b.plannedFor));
  }

  List<ChangeTaskInstance> get activeTaskInstances =>
      _taskInstances.where((e) => e.status == TaskInstanceStatus.inProgress || e.status == TaskInstanceStatus.planned).toList();

  List<ChangeTaskInstance> get failedTaskInstances =>
      _taskInstances.where((e) => e.status == TaskInstanceStatus.failed).toList();

  int get restartQueueCount => failedTaskInstances.length;

  ChangeTaskInstance? taskInstanceById(String id) {
    final matches = _taskInstances.where((e) => e.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  List<ReminderSchedule> remindersForInstance(String instanceId) =>
      _reminderSchedules.where((e) => e.instanceId == instanceId).toList()
        ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));

  List<WorldMissionStage> missionsForWorld(String worldId) =>
      missionStages.where((m) => m.worldId == worldId).toList()
        ..sort((a, b) => a.stageNo.compareTo(b.stageNo));

  bool _missionRequirementsMet(WorldMissionStage mission) {
    if (mission.requiredConceptIds.isEmpty) return true;
    return mission.requiredConceptIds.every((id) => progressById(id).status.index >= ConceptStatus.read.index);
  }

  WorldMissionRecord missionRecordById(String missionId) =>
      _missionRecords[missionId] ?? WorldMissionRecord(missionId: missionId);

  int worldMissionCurrentCount(String missionId) {
    final record = missionRecordById(missionId);
    final mission = missionStages.firstWhere((m) => m.id == missionId);
    final count = record.progressCount;
    if (count < 0) return 0;
    if (count > mission.actionTarget) return mission.actionTarget;
    return count;
  }

  bool isWorldMissionCompleted(String missionId) => missionRecordById(missionId).isCompleted;

  bool isWorldMissionUnlocked(String missionId) {
    final mission = missionStages.firstWhere((m) => m.id == missionId);
    if (!isWorldUnlocked(mission.worldId)) return false;
    final record = missionRecordById(missionId);
    if (record.isUnlocked) return true;
    if (!_missionRequirementsMet(mission)) return false;
    if (mission.stageNo <= 1) return true;
    final previous = missionsForWorld(mission.worldId).where((m) => m.stageNo == mission.stageNo - 1);
    return previous.isNotEmpty && isWorldMissionCompleted(previous.first.id);
  }

  bool isWorldMissionRewardClaimed(String missionId) => missionRecordById(missionId).isRewardClaimed;

  WorldMissionStatus worldMissionStatus(String missionId) {
    if (isWorldMissionCompleted(missionId)) return WorldMissionStatus.completed;
    if (isWorldMissionUnlocked(missionId)) return WorldMissionStatus.active;
    return WorldMissionStatus.locked;
  }

  WorldMissionStage? activeMissionForWorld(String worldId) {
    for (final mission in missionsForWorld(worldId)) {
      final status = worldMissionStatus(mission.id);
      if (status == WorldMissionStatus.active) return mission;
    }
    final worldMissions = missionsForWorld(worldId);
    return worldMissions.isEmpty ? null : worldMissions.last;
  }

  int completedMissionCountForWorld(String worldId) =>
      missionsForWorld(worldId).where((m) => missionRecordById(m.id).isCompleted).length;

  List<WorldRewardEvent> rewardEventsForWorld(String worldId) =>
      _worldRewardEvents.where((e) => e.worldId == worldId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  String worldMissionStatusLabel(String missionId) {
    switch (worldMissionStatus(missionId)) {
      case WorldMissionStatus.locked:
        return '未解锁';
      case WorldMissionStatus.active:
        return '当前任务';
      case WorldMissionStatus.completed:
        return isWorldMissionRewardClaimed(missionId) ? '已领奖' : '已完成';
    }
  }

  Color worldMissionStatusColor(String missionId) {
    switch (worldMissionStatus(missionId)) {
      case WorldMissionStatus.locked:
        return const Color(0xFF7A7F8A);
      case WorldMissionStatus.active:
        return const Color(0xFF6D5EF0);
      case WorldMissionStatus.completed:
        return const Color(0xFF1C9E5E);
    }
  }

  String worldMissionProgressText(String missionId) {
    final mission = missionStages.firstWhere((m) => m.id == missionId);
    final count = worldMissionCurrentCount(missionId);
    final suffix = isWorldMissionCompleted(missionId) ? ' · 奖励已解锁' : '';
    return '阶段推进 ${count}/${mission.actionTarget}$suffix';
  }

  List<CoachDialogueTurn> coachDialogueForInstance(String instanceId) {
    final instance = taskInstanceById(instanceId);
    if (instance == null) return const [];
    final concept = conceptById(instance.conceptId);
    final task = taskById(instance.conceptId, instance.taskId);
    final dialogue = <CoachDialogueTurn>[
      CoachDialogueTurn(
        speaker: 'AI教练',
        message: '当前任务是「${concept.title}」里的「${task.title}」。先别想着一次做满，先把最小动作落实。',
        emphasis: instance.assignedReason,
      ),
    ];
    if (instance.status == TaskInstanceStatus.failed) {
      dialogue.add(CoachDialogueTurn(
        speaker: 'AI教练',
        message: coachFailureMessage(task, concept),
        emphasis: instance.failureReason.isEmpty ? '优先把动作缩小，再重新开始。' : instance.failureReason,
      ));
    } else if (instance.status == TaskInstanceStatus.completed) {
      final run = _taskRuns.where((e) => e.conceptId == instance.conceptId && e.taskId == instance.taskId).toList();
      if (run.isNotEmpty) {
        dialogue.add(CoachDialogueTurn(
          speaker: 'AI教练',
          message: coachSuccessMessage(run.first),
          emphasis: '下一步是把这次动作变成可重复证据。',
        ));
      }
    } else {
      final prompt = aiPromptForTask(conceptId: concept.id, taskId: task.id, scenario: PromptScenario.taskAssigned);
      dialogue.add(CoachDialogueTurn(
        speaker: 'AI教练',
        message: prompt?.prompt ?? '先从最小版本开始，不要求一次做很多。',
        emphasis: '失败降级：${task.fallbackHint}',
      ));
    }
    final instanceReminders = remindersForInstance(instanceId).where((e) => e.status == ReminderScheduleStatus.pending).toList();
    if (instanceReminders.isNotEmpty) {
      dialogue.add(CoachDialogueTurn(
        speaker: '系统提醒',
        message: '这个任务当前还有 ${instanceReminders.length} 条待处理提醒。先处理提醒，再执行，会更稳。',
        emphasis: instanceReminders.first.message,
      ));
    }
    final world = worldScenes.where((w) => w.conceptIds.contains(instance.conceptId)).toList();
    if (world.isNotEmpty) {
      final activeMission = activeMissionForWorld(world.first.id);
      if (activeMission != null) {
        dialogue.add(CoachDialogueTurn(
          speaker: '镜像世界',
          message: '你现在推动的是「${world.first.title}」里的阶段任务：${activeMission.title}。',
          emphasis: activeMission.summary,
        ));
      }
    }
    return dialogue;
  }

  String coachPrimaryActionForInstance(String instanceId) {
    final instance = taskInstanceById(instanceId);
    if (instance == null) return '先完成一个最小动作。';
    final task = taskById(instance.conceptId, instance.taskId);
    switch (instance.status) {
      case TaskInstanceStatus.planned:
        return '先开始这个任务，做最小版本。';
      case TaskInstanceStatus.inProgress:
        return '回到当前动作，把这次执行收尾。';
      case TaskInstanceStatus.failed:
        return '先把它缩成更小版本，再失败重启。';
      case TaskInstanceStatus.completed:
        return '做一次次日延续动作，把证据变成节奏。';
      case TaskInstanceStatus.restarted:
        return '从重启后的更小任务重新开始。';
      case TaskInstanceStatus.skipped:
        return '重新安排一个更现实的时间点，再启动。';
    }
  }

  TaskRecommendation? get recommendedTaskNow {
    final openToday = todayTaskInstances.where((e) => e.isOpen).toList();
    if (openToday.isNotEmpty) {
      final instance = openToday.first;
      return TaskRecommendation(
        concept: conceptById(instance.conceptId),
        task: taskById(instance.conceptId, instance.taskId),
        reason: instance.assignedReason.isNotEmpty ? instance.assignedReason : '这是你今天计划中的现实动作。',
      );
    }
    final worldRec = worldPriorityRecommendation;
    if (worldRec != null) return worldRec;
    final concept = pinnedConcept ?? (suggestedToday.isEmpty ? null : suggestedToday.first);
    if (concept == null) return null;
    final progress = progressById(concept.id);
    final task = progress.status == ConceptStatus.unread
        ? concept.tasks.firstWhere((t) => t.type == TaskType.light, orElse: () => concept.tasks.first)
        : concept.tasks.firstWhere((t) => t.type == TaskType.main, orElse: () => concept.tasks.first);
    final reason = pinnedConcept != null
        ? '你已经钉住这张概念卡，最适合先把它变成一个现实动作。'
        : '这是你今天最值得先推进的一步：先做一个任务，再决定是否加难。';
    return TaskRecommendation(concept: concept, task: task, reason: reason);
  }

  String get coachDailyBrief {
    if (failedTaskInstances.isNotEmpty) {
      return '你有 ${failedTaskInstances.length} 个任务停在失败重启队列里。先把其中一个缩小并重新启动，比继续堆新任务更有效。';
    }
    if (todayTaskInstances.where((e) => e.isOpen).isNotEmpty) {
      return '今天系统已经为你生成了 ${todayTaskInstances.where((e) => e.isOpen).length} 个现实动作。先完成计划里的一个，再考虑扩展。';
    }
    final mission = priorityMission;
    if (mission != null) {
      return missionUnlockBanner(mission);
    }
    if (latestRewardEvent != null) {
      return '你最近刚领取一个世界奖励：${rewardFeedNarrative(latestRewardEvent!)}。$nextMainlineSummary';
    }
    if (pinnedConcept != null) {
      return '今天先别分散。围绕「${pinnedConcept!.title}」完成一个现实动作，哪怕只做轻任务。';
    }
    if (_diagnosisResult != null && _diagnosisResult!.recommendedConceptIds.isNotEmpty) {
      final first = conceptById(_diagnosisResult!.recommendedConceptIds.first);
      return '根据你的诊断结果，今天最值得先推进的是「${first.title}」。先完成一个小动作，再谈更大改变。';
    }
    return '先别追求一下子全变好。今天只要完成一个最小行动，你就已经在改变系统里前进。';
  }

  String get weeklyPlanSummary => _weeklyPlan?.summary ?? '本周计划尚未生成。';

  String coachSuccessMessage(TaskRunRecord run) {
    final concept = conceptById(run.conceptId);
    final delta = run.beforeScore - run.afterScore;
    final relief = delta > 0
        ? '你把主观压力从 ${run.beforeScore} 降到了 ${run.afterScore}。'
        : '即使感受没有立刻变轻，你也已经给自己留下了行动证据。';
    final template = aiPromptForTask(
      conceptId: run.conceptId,
      taskId: run.taskId,
      scenario: PromptScenario.taskCompleted,
    );
    final suffix = template == null ? '' : ' ${template.systemGoal}';
    return '你刚刚在「${concept.title}」上完成了一次真实练习。$relief 关键不是完美，而是你没有停在理解层。$suffix';
  }

  String coachFailureMessage(ChangeTask task, ChangeConcept concept) {
    final template = aiPromptForTask(
      conceptId: concept.id,
      taskId: task.id,
      scenario: PromptScenario.taskFailed,
    );
    final guidance = template?.prompt ?? '先把任务缩到更小版本。';
    return '这次在「${concept.title}」上没做成，也不用把它等同于失败。$guidance';
  }

  List<String> coachPromptsForConcept(String conceptId) {
    final prompts = aiPrompts
        .where((p) => p.conceptId == conceptId && p.scenario == PromptScenario.reflectionFollowup)
        .map((p) => p.prompt)
        .toList();
    if (prompts.isNotEmpty) return prompts.take(3).toList();
    return const [
      '这张卡今天最值得你落实的一个动作是什么？',
      '如果缩小到最小版本，你愿意做什么？',
    ];
  }

  List<String> reminderTemplatesForTask(ChangeTask task, ChangeConcept concept) {
    final matched = reminders
        .where((r) => r.conceptId == concept.id && r.taskId == task.id)
        .map((r) => '${_reminderTypeLabel(r.type)}：${r.message}')
        .toList();
    return matched.isEmpty
        ? [
            '预提醒：今天请把「${concept.title}」落到一个现实动作，而不只是停在理解层。',
            '临场提醒：${task.summary}',
            '中断提醒：如果现在做不动，就先改成更小版本——${task.fallbackHint}',
          ]
        : matched;
  }

  String _reminderTypeLabel(ReminderType type) {
    switch (type) {
      case ReminderType.pre:
        return '预提醒';
      case ReminderType.moment:
        return '临场提醒';
      case ReminderType.interrupt:
        return '中断提醒';
      case ReminderType.nextDay:
        return '次日追问';
    }
  }

  List<String> get dominantPatterns {
    final patterns = <String>[];
    final q1 = _diagnosisAnswers['q1'];
    final q2 = _diagnosisAnswers['q2'];
    final q4 = _diagnosisAnswers['q4'];
    final q5 = _diagnosisAnswers['q5'];

    if (q1 == '知道很多但做得少' || q2 == '总在想但不落实') {
      patterns.add('知行断裂型：理解很多，但动作启动慢。');
    }
    if (q1 == '一焦虑就退' || q2 == '情绪一来就崩') {
      patterns.add('情绪裹挟型：需要先练习停顿和正念。');
    }
    if (q1 == '总想快速见效') {
      patterns.add('速成期待型：更适合用渐进式改变建立节奏。');
    }
    if (q4 == '我怕一旦放松，就会失去优秀/责任感') {
      patterns.add('隐性绑定型：需要先解绑价值与代价。');
    }
    if (q5 == '我总是把任务想得太大') {
      patterns.add('任务过载型：需要用5%拉伸和最小行动。');
    }
    if (patterns.isEmpty) {
      patterns.add('基础构建型：先建立可改变感、通路意识和一个现实动作。');
    }
    return patterns;
  }

  Map<String, double> get moduleCompletionRates {
    final modules = <String, List<ChangeConcept>>{};
    for (final c in concepts) {
      modules.putIfAbsent(c.module, () => []).add(c);
    }
    return {
      for (final entry in modules.entries)
        entry.key: entry.value.isEmpty
            ? 0
            : entry.value
                    .where((c) => progressById(c.id).status.index >= ConceptStatus.acted.index)
                    .length /
                entry.value.length,
    };
  }

  List<String> relatedConceptIds(String conceptId) => ChangeLabSeed.relatedConceptIds(conceptId);

  void answerDiagnosis(String questionId, String answerLabel) {
    _diagnosisAnswers[questionId] = answerLabel;
    _persistAndNotify();
  }

  String? diagnosisAnswer(String questionId) => _diagnosisAnswers[questionId];

  void calculateDiagnosis({bool notify = true}) {
    final scores = <String, int>{};
    for (final question in diagnosisQuestions) {
      final label = _diagnosisAnswers[question.id];
      if (label == null) continue;
      final option = question.options.firstWhere((e) => e.label == label);
      for (final cid in option.suggestedConceptIds) {
        scores[cid] = (scores[cid] ?? 0) + 1;
      }
    }
    final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final recommended = sorted.take(3).map((e) => e.key).toList();
    final recommendedIds = recommended.isEmpty ? ['C01', 'C02', 'C14'] : recommended;
    final recommendedTitles = recommendedIds.map((id) => conceptById(id).title).join('、');
    final summary = recommended.isEmpty
        ? '你目前更适合从基础理解开始。建议先学习：$recommendedTitles。'
        : '系统判断你当前更适合优先从这几张卡进入：$recommendedTitles。';
    _diagnosisResult = DiagnosisResult(
      summary: summary,
      recommendedConceptIds: recommendedIds,
    );
    _ensureMissionState();
    _ensureWeeklyPlan(forceRegenerate: true);
    _syncReminderSchedules();
    unawaited(syncNotificationBridge());
    if (notify) {
      _persistAndNotify();
    }
  }

  bool isWorldUnlocked(String worldId) {
    final world = worldById(worldId);
    if (world.unlockConceptIds.isEmpty) return true;
    return world.unlockConceptIds.every(
      (conceptId) => progressById(conceptId).status.index >= world.requiredStatus.index,
    );
  }

  String worldUnlockHint(String worldId) {
    final world = worldById(worldId);
    if (isWorldUnlocked(worldId)) {
      return '已满足进入条件。下一步是完成这个世界里至少一个现实动作，让剧情继续推进。';
    }
    final missing = world.unlockConceptIds
        .where((id) => progressById(id).status.index < world.requiredStatus.index)
        .map((id) => conceptById(id).title)
        .join('、');
    final needed = world.requiredStatus == ConceptStatus.acted ? '已行动' : '已阅读';
    return '要解锁「${world.title}」，先让这些概念至少达到“$needed”：$missing。';
  }

  List<ChangeConcept> conceptsForWorld(String worldId) =>
      worldById(worldId).conceptIds.map(conceptById).toList();

  bool isConceptInWeeklyLearning(String conceptId) => _weeklyPlan?.focusConceptIds.contains(conceptId) ?? false;

  ChangeTaskInstance? recommendedOpenInstanceForConcept(String conceptId) {
    final matches = _taskInstances.where((e) => e.conceptId == conceptId && e.isOpen).toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) => a.plannedFor.compareTo(b.plannedFor));
    return matches.first;
  }

  ChangeTask recommendedTaskForConcept(String conceptId) {
    final concept = conceptById(conceptId);
    final open = recommendedOpenInstanceForConcept(conceptId);
    if (open != null) {
      return taskById(open.conceptId, open.taskId);
    }
    final progress = progressById(conceptId);
    if (progress.status == ConceptStatus.unread) {
      return concept.tasks.firstWhere((t) => t.type == TaskType.light, orElse: () => concept.tasks.first);
    }
    if (progress.status.index < ConceptStatus.acted.index) {
      return concept.tasks.firstWhere((t) => t.type == TaskType.main, orElse: () => concept.tasks.first);
    }
    return concept.tasks.firstWhere((t) => t.type == TaskType.challenge, orElse: () => concept.tasks.last);
  }

  void addConceptToWeeklyLearning(String conceptId, {String source = '原课全景阅读'}) {
    final concept = conceptById(conceptId);
    final nowKey = _weekKey(DateTime.now());
    final startOfWeek = _startOfWeek(DateTime.now());

    final existingIds = <String>[
      ...?_weeklyPlan?.focusConceptIds,
    ];
    final deduped = <String>[];
    for (final id in [...existingIds, conceptId]) {
      if (!deduped.contains(id) && concepts.any((c) => c.id == id)) {
        deduped.add(id);
      }
    }
    final focusIds = deduped.take(7).toList();

    final openWeeklyForConcept = _taskInstances.where((e) => e.conceptId == conceptId && e.isFromWeeklyPlan && e.isOpen).toList();
    final createdIds = <String>[];
    if (_weeklyPlan != null && _weeklyPlan!.weekKey == nowKey) {
      createdIds.addAll(_weeklyPlan!.taskInstanceIds.where((id) => _taskInstances.any((e) => e.id == id)));
    }

    if (openWeeklyForConcept.isEmpty) {
      final task = recommendedTaskForConcept(conceptId);
      final plannedFor = startOfWeek.add(Duration(days: (focusIds.length - 1).clamp(0, 6)));
      final instance = ChangeTaskInstance(
        id: _newInstanceId(concept.id, task.id),
        conceptId: concept.id,
        taskId: task.id,
        taskType: task.type,
        plannedFor: plannedFor,
        createdAt: DateTime.now(),
        status: TaskInstanceStatus.planned,
        assignedReason: '来自「$source」：已把「${concept.title}」加入本周学习，并自动挂接推荐动作。',
        isFromWeeklyPlan: true,
      );
      _taskInstances.insert(0, instance);
      createdIds.add(instance.id);
    }

    for (final id in focusIds) {
      final open = _taskInstances.where((e) => e.conceptId == id && e.isFromWeeklyPlan).map((e) => e.id);
      for (final tid in open) {
        if (!createdIds.contains(tid)) createdIds.add(tid);
      }
    }

    _weeklyPlan = WeeklyPlan(
      id: _weeklyPlan?.id ?? 'WP_${DateTime.now().millisecondsSinceEpoch}',
      weekKey: nowKey,
      createdAt: _weeklyPlan?.createdAt ?? DateTime.now(),
      focusConceptIds: focusIds,
      taskInstanceIds: createdIds,
      summary: '你已把「${concept.title}」加入本周学习。建议按“读原课 → 看案例 → 做动作”来推进，并至少完成一个与该段原课对应的现实任务。',
    );

    _syncReminderSchedules();
    unawaited(syncNotificationBridge(force: true));
    _persistAndNotify();
  }

  TaskRecommendation? recommendedTaskForWorld(String worldId) {
    final concepts = conceptsForWorld(worldId);
    if (concepts.isEmpty) return null;
    final matchingOpen = todayTaskInstances.where((e) => concepts.any((c) => c.id == e.conceptId) && e.isOpen).toList();
    if (matchingOpen.isNotEmpty) {
      final instance = matchingOpen.first;
      return TaskRecommendation(
        concept: conceptById(instance.conceptId),
        task: taskById(instance.conceptId, instance.taskId),
        reason: '这个世界今天已有一个现实联动任务，先把它完成最有效。',
      );
    }
    for (final concept in concepts) {
      final progress = progressById(concept.id);
      if (progress.status == ConceptStatus.unread) {
        return TaskRecommendation(
          concept: concept,
          task: concept.tasks.first,
          reason: '先从这个世界最前面的概念开始，让场景真正亮起来。',
        );
      }
      final mainTask = concept.tasks.firstWhere(
        (t) => t.type == TaskType.main,
        orElse: () => concept.tasks.first,
      );
      if (progress.status.index < ConceptStatus.acted.index) {
        return TaskRecommendation(
          concept: concept,
          task: mainTask,
          reason: '这个世界的推进依赖现实任务证据，先完成一个主任务最有效。',
        );
      }
    }
    final concept = concepts.first;
    final challenge = concept.tasks.firstWhere(
      (t) => t.type == TaskType.challenge,
      orElse: () => concept.tasks.last,
    );
    return TaskRecommendation(
      concept: concept,
      task: challenge,
      reason: '这个世界已点亮，适合用挑战任务把进展继续推进。',
    );
  }

  AiPromptTemplate? aiPromptForTask({
    required String conceptId,
    required String taskId,
    required PromptScenario scenario,
  }) {
    final list = aiPrompts.where(
      (p) => p.conceptId == conceptId && p.taskId == taskId && p.scenario == scenario,
    );
    return list.isEmpty ? null : list.first;
  }

  List<AiPromptTemplate> aiPromptsForConcept(String conceptId) =>
      aiPrompts.where((p) => p.conceptId == conceptId).toList();

  List<ReminderTemplate> remindersForConcept(String conceptId) =>
      reminders.where((r) => r.conceptId == conceptId).toList();

  void regenerateWeeklyPlan() {
    _ensureMissionState();
    _ensureWeeklyPlan(forceRegenerate: true);
    _syncReminderSchedules();
    _persistAndNotify();
  }


  void _ensureMissionState({bool spawnTasks = true}) {
    for (final world in worldScenes) {
      if (!isWorldUnlocked(world.id)) continue;
      final worldMissions = missionsForWorld(world.id);
      if (worldMissions.isEmpty) continue;
      for (final mission in worldMissions) {
        final shouldUnlock = _missionRequirementsMet(mission) &&
            (mission.stageNo == 1 || isWorldMissionCompleted(worldMissions.firstWhere((m) => m.stageNo == mission.stageNo - 1).id));
        if (shouldUnlock) {
          final record = missionRecordById(mission.id);
          if (!record.isUnlocked) {
            _missionRecords[mission.id] = record.copyWith(unlockedAt: DateTime.now());
          }
        }
      }
      if (spawnTasks) {
        final active = activeMissionForWorld(world.id);
        if (active != null && worldMissionStatus(active.id) == WorldMissionStatus.active) {
          _maybeSpawnMissionTask(active, reason: '世界推进：当前主线「${active.title}」已解锁。');
        }
      }
    }
  }

  void _maybeSpawnMissionTask(WorldMissionStage mission, {String reason = ''}) {
    final candidateIds = mission.requiredConceptIds.isNotEmpty
        ? mission.requiredConceptIds
        : worldById(mission.worldId).conceptIds;
    if (candidateIds.isEmpty) return;
    final hasOpen = _taskInstances.any((e) =>
        candidateIds.contains(e.conceptId) &&
        e.isOpen &&
        taskById(e.conceptId, e.taskId).type == mission.suggestedTaskType);
    if (hasOpen) return;
    final concept = candidateIds.where((id) => concepts.any((c) => c.id == id)).map(conceptById).first;
    final task = concept.tasks.firstWhere(
      (t) => t.type == mission.suggestedTaskType,
      orElse: () => concept.tasks.firstWhere(
        (t) => t.type == TaskType.main,
        orElse: () => concept.tasks.first,
      ),
    );
    _taskInstances.insert(
      0,
      ChangeTaskInstance(
        id: _newInstanceId(concept.id, task.id),
        conceptId: concept.id,
        taskId: task.id,
        taskType: task.type,
        plannedFor: DateTime.now(),
        createdAt: DateTime.now(),
        status: TaskInstanceStatus.planned,
        assignedReason: reason.isEmpty ? '世界推进：${mission.title}' : reason,
        isFromWeeklyPlan: false,
      ),
    );
  }

  void _applyWorldProgressForRun(TaskRunRecord run) {
    _latestMilestoneMessage = null;
    for (final world in worldScenes.where((w) => w.conceptIds.contains(run.conceptId))) {
      final mission = activeMissionForWorld(world.id);
      if (mission == null) continue;
      if (!isWorldMissionUnlocked(mission.id) || !_missionRequirementsMet(mission)) continue;
      if (mission.requiredConceptIds.isNotEmpty && !mission.requiredConceptIds.contains(run.conceptId)) continue;
      final record = missionRecordById(mission.id);
      final contributionKey = 'run|${run.conceptId}|${run.taskId}|${run.createdAt.toIso8601String()}';
      if (record.contributionRunKeys.contains(contributionKey)) continue;
      final nextCount = record.progressCount + 1;
      final completed = nextCount >= mission.actionTarget;
      _missionRecords[mission.id] = record.copyWith(
        unlockedAt: record.unlockedAt ?? run.createdAt,
        progressCount: nextCount,
        lastProgressAt: run.createdAt,
        completedAt: completed ? (record.completedAt ?? run.createdAt) : record.completedAt,
        rewardClaimedAt: completed ? (record.rewardClaimedAt ?? run.createdAt) : record.rewardClaimedAt,
        contributionRunKeys: [...record.contributionRunKeys, contributionKey],
      );
      if (completed) {
        _worldRewardEvents.insert(
          0,
          WorldRewardEvent(
            id: 'WE_${mission.id}_${run.createdAt.millisecondsSinceEpoch}',
            worldId: mission.worldId,
            missionId: mission.id,
            title: mission.title,
            message: mission.rewardText,
            createdAt: run.createdAt,
          ),
        );
        _latestMilestoneMessage = '世界推进：${world.title} 完成「${mission.title}」，已自动领取奖励并解锁下一阶段。';
        _unlockNextMissionAfter(mission, run.createdAt);
        if (isFinalMissionOfWorld(mission)) {
          _spawnFollowUpAfterWorldCompletion(world.id, run.createdAt);
        }
      } else {
        _latestMilestoneMessage = '世界推进：${world.title} 的「${mission.title}」已前进 ${nextCount}/${mission.actionTarget}。';
      }
    }
  }

  void _recordRestartProgress(ChangeTaskInstance current) {
    for (final world in worldScenes.where((w) => w.conceptIds.contains(current.conceptId))) {
      final mission = activeMissionForWorld(world.id);
      if (mission == null) continue;
      if (!isWorldMissionUnlocked(mission.id) || !_missionRequirementsMet(mission)) continue;
      final matchRestartMission = mission.summary.contains('失败重启') || mission.rewardText.contains('完整性');
      if (!matchRestartMission) continue;
      final record = missionRecordById(mission.id);
      final contributionKey = 'restart|${current.id}|${DateTime.now().toIso8601String()}';
      final nextCount = record.progressCount + 1;
      final completed = nextCount >= mission.actionTarget;
      _missionRecords[mission.id] = record.copyWith(
        unlockedAt: record.unlockedAt ?? DateTime.now(),
        progressCount: nextCount,
        lastProgressAt: DateTime.now(),
        completedAt: completed ? (record.completedAt ?? DateTime.now()) : record.completedAt,
        rewardClaimedAt: completed ? (record.rewardClaimedAt ?? DateTime.now()) : record.rewardClaimedAt,
        contributionRunKeys: [...record.contributionRunKeys, contributionKey],
      );
      if (completed) {
        _worldRewardEvents.insert(
          0,
          WorldRewardEvent(
            id: 'WE_${mission.id}_${DateTime.now().millisecondsSinceEpoch}',
            worldId: mission.worldId,
            missionId: mission.id,
            title: mission.title,
            message: mission.rewardText,
            createdAt: DateTime.now(),
          ),
        );
        _latestMilestoneMessage = '世界推进：${world.title} 已把“失败重启”也计入通关进度。';
        _unlockNextMissionAfter(mission, DateTime.now());
        if (isFinalMissionOfWorld(mission)) {
          _spawnFollowUpAfterWorldCompletion(world.id, DateTime.now());
        }
      }
    }
  }

  void _unlockNextMissionAfter(WorldMissionStage mission, DateTime time) {
    final nextMatches = missionsForWorld(mission.worldId).where((m) => m.stageNo == mission.stageNo + 1).toList();
    if (nextMatches.isEmpty) return;
    final next = nextMatches.first;
    if (!_missionRequirementsMet(next)) return;
    final nextRecord = missionRecordById(next.id);
    if (!nextRecord.isUnlocked) {
      _missionRecords[next.id] = nextRecord.copyWith(unlockedAt: time);
      _maybeSpawnMissionTask(next, reason: '世界解锁：完成上一阶段后，系统为你生成了下一阶段任务。');
    }
  }

  void _spawnFollowUpAfterWorldCompletion(String completedWorldId, DateTime time) {
    _ensureMissionState(spawnTasks: false);
    final world = worldById(completedWorldId);
    WorldMissionStage? candidate;
    for (final nextId in world.nextWorldIds) {
      final active = activeMissionForWorld(nextId);
      if (active != null && worldMissionStatus(active.id) == WorldMissionStatus.active) {
        candidate = active;
        break;
      }
    }
    final queue = activeMissionQueue.where((m) => m.worldId != completedWorldId).toList();
    candidate ??= queue.isEmpty ? null : queue.first;
    if (candidate == null) return;
    _maybeSpawnMissionTask(
      candidate,
      reason: '完成「${world.title}」后，系统为你派发了下一条主线任务：${candidate.title}',
    );
  }

  String? latestRewardMessageForWorld(String worldId) {
    final events = rewardEventsForWorld(worldId);
    if (events.isEmpty) return null;
    final latest = events.first;
    return '最近奖励：${latest.message}';
  }

  bool isCompletionRewardEvent(WorldRewardEvent event) {
    final missions = missionsForWorld(event.worldId);
    if (missions.isEmpty) return false;
    return missions.last.id == event.missionId;
  }

  bool isWorldFullyCompleted(String worldId) {
    final missions = missionsForWorld(worldId);
    return missions.isNotEmpty && missions.every((m) => missionRecordById(m.id).isCompleted);
  }

  DateTime? worldCompletedAt(String worldId) {
    final missions = missionsForWorld(worldId);
    if (missions.isEmpty) return null;
    final finals = missions.where((m) => m.stageNo == missions.map((e) => e.stageNo).reduce((a, b) => a > b ? a : b)).toList();
    if (finals.isEmpty) return null;
    return missionRecordById(finals.first.id).completedAt;
  }

  List<WorldScene> get completedWorlds {
    final worlds = worldScenes.where((w) => isWorldFullyCompleted(w.id)).toList();
    worlds.sort((a, b) {
      final at = worldCompletedAt(a.id) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = worldCompletedAt(b.id) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return worlds;
  }

  int get completedWorldCount => completedWorlds.length;

  List<WorldRewardEvent> get recentCompletionRewardEvents =>
      _worldRewardEvents.where(isCompletionRewardEvent).take(6).toList();

  WorldRewardEvent? get latestCompletionRewardEvent =>
      recentCompletionRewardEvents.isEmpty ? null : recentCompletionRewardEvents.first;

  String rewardDialogTitle(WorldRewardEvent event) =>
      isCompletionRewardEvent(event) ? '已点亮一个完整世界' : '已解锁新的阶段奖励';

  String rewardDialogPrimaryActionLabel(WorldRewardEvent event) =>
      isCompletionRewardEvent(event) ? '查看世界完成旅程' : '打开成长时间线';

  String worldCompletionNarrative(String worldId) {
    final world = worldById(worldId);
    final completedAt = worldCompletedAt(worldId);
    final timeText = completedAt == null
        ? '最近'
        : '${completedAt.month.toString().padLeft(2, '0')}/${completedAt.day.toString().padLeft(2, '0')}';
    return '${world.title} 已在 $timeText 完成全部阶段。现在适合把奖励沉淀成新的主线动作。';
  }

  bool isFinalMissionOfWorld(WorldMissionStage mission) {
    final missions = missionsForWorld(mission.worldId);
    if (missions.isEmpty) return false;
    final maxStage = missions.map((e) => e.stageNo).reduce((a, b) => a > b ? a : b);
    return mission.stageNo >= maxStage;
  }

  WorldMissionStage? nextMissionAfterWorldCompletion(String worldId) {
    final world = worldById(worldId);
    for (final nextId in world.nextWorldIds) {
      final active = activeMissionForWorld(nextId);
      if (active != null && worldMissionStatus(active.id) == WorldMissionStatus.active) {
        return active;
      }
    }
    final queue = activeMissionQueue.where((m) => m.worldId != worldId).toList();
    return queue.isEmpty ? null : queue.first;
  }

  List<ChangeTaskInstance> followUpInstancesForCompletedWorld(String worldId) {
    final world = worldById(worldId);
    final completedAt = worldCompletedAt(worldId);
    final threshold = completedAt?.subtract(const Duration(minutes: 1));
    return _taskInstances.where((instance) {
      if (!instance.isOpen) return false;
      if (!instance.assignedReason.contains('完成「${world.title}」')) return false;
      if (threshold == null) return true;
      return !instance.createdAt.isBefore(threshold);
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  String worldAchievementPosterTitle(String worldId) => '世界完成成就';

  String worldAchievementPosterSubtitle(String worldId) {
    final world = worldById(worldId);
    final completedAt = worldCompletedAt(worldId);
    final stamp = completedAt == null
        ? '已点亮全部阶段'
        : '完成于 ${completedAt.year}-${completedAt.month.toString().padLeft(2, '0')}-${completedAt.day.toString().padLeft(2, '0')}';
    return '${world.title} · $stamp';
  }

  String worldAchievementPosterBody(String worldId) {
    final world = worldById(worldId);
    final completed = completedMissionCountForWorld(worldId);
    final rewards = rewardEventsForWorld(worldId).length;
    return '${world.title} 已完成 $completed 个阶段任务，并积累 $rewards 条奖励事件。这个世界不是被“看懂”的，而是被你用现实动作点亮的。';
  }

  String nextMainlineSummaryForWorld(String worldId) {
    final next = nextMissionAfterWorldCompletion(worldId);
    if (next == null) return '当前没有更高优先级的主线，适合回到时间线巩固已完成的成长证据。';
    return '下一主线：${worldById(next.worldId).title} · ${next.title}。${missionUnlockBanner(next)}';
  }

  List<WorldScene> recommendedNextWorldBranches(String worldId) {
    final world = worldById(worldId);
    final branches = world.nextWorldIds
        .where((id) => worldScenes.any((w) => w.id == id))
        .map(worldById)
        .toList();
    branches.sort((a, b) {
      final aCompleted = isWorldFullyCompleted(a.id) ? 1 : 0;
      final bCompleted = isWorldFullyCompleted(b.id) ? 1 : 0;
      if (aCompleted != bCompleted) return aCompleted.compareTo(bCompleted);
      final aMission = activeMissionForWorld(a.id);
      final bMission = activeMissionForWorld(b.id);
      final aRemain = aMission == null ? 999 : remainingActionCountForMission(aMission.id);
      final bRemain = bMission == null ? 999 : remainingActionCountForMission(bMission.id);
      return aRemain.compareTo(bRemain);
    });
    return branches;
  }

  List<WorldMissionStage> recommendedNextBranchMissions(String worldId) {
    return recommendedNextWorldBranches(worldId)
        .map((w) => activeMissionForWorld(w.id))
        .whereType<WorldMissionStage>()
        .toList();
  }

  String branchRecommendationSummary(String worldId) {
    final branches = recommendedNextBranchMissions(worldId);
    if (branches.isEmpty) {
      return '当前没有可直接推进的新分支，适合先回到成长时间线巩固已完成的奖励。';
    }
    return branches
        .take(3)
        .map((m) => '${worldById(m.worldId).title} · ${m.title}（还差 ${remainingActionCountForMission(m.id)} 次现实动作）')
        .join('；');
  }

  String achievementPosterShareText(String worldId) {
    final world = worldById(worldId);
    final subtitle = worldAchievementPosterSubtitle(worldId);
    final body = worldAchievementPosterBody(worldId);
    final narrative = worldCompletionNarrative(worldId);
    final next = nextMainlineSummaryForWorld(worldId);
    return '【$subtitle】\n$body\n\n$narrative\n\n下一步：$next\n\n来自改变实验室 · ${world.title}';
  }

  void generateWeeklyPlanFromWorldCompletion(String worldId) {
    final nextBranches = recommendedNextWorldBranches(worldId);
    if (nextBranches.isNotEmpty) {
      generateWeeklyPlanForWorldBranch(nextBranches.first.id, sourceWorldId: worldId);
      return;
    }
    final preferredIds = <String>[];
    for (final mission in recommendedNextBranchMissions(worldId)) {
      preferredIds.addAll(mission.requiredConceptIds);
    }
    for (final branch in nextBranches) {
      preferredIds.addAll(branch.conceptIds.take(2));
    }
    final unique = <String>{};
    final conceptsToPlan = preferredIds
        .where((id) => concepts.any((c) => c.id == id))
        .map(conceptById)
        .where((c) => unique.add(c.id))
        .take(4)
        .toList();
    if (conceptsToPlan.isEmpty) {
      final next = nextMissionAfterWorldCompletion(worldId);
      if (next != null) {
        conceptsToPlan.addAll(next.requiredConceptIds.where((id) => concepts.any((c) => c.id == id)).map(conceptById).take(3));
      }
    }
    if (conceptsToPlan.isEmpty) {
      _ensureWeeklyPlan(forceRegenerate: true);
      _persistAndNotify();
      return;
    }
    final world = worldById(worldId);
    _replaceWeeklyPlanWithConcepts(
      conceptsToPlan,
      summary: '你刚完成「${world.title}」，系统已围绕下一主线为你生成本周计划：${conceptsToPlan.map((e) => '「${e.title}」').join('、')}。先把世界奖励接成新的现实动作。',
    );
    _syncReminderSchedules();
    unawaited(syncNotificationBridge(force: true));
    _persistAndNotify();
  }

  void generateWeeklyPlanForWorldBranch(String targetWorldId, {String? sourceWorldId}) {
    final targetWorld = worldById(targetWorldId);
    final mission = activeMissionForWorld(targetWorldId);
    final preferredIds = <String>[];
    if (mission != null) preferredIds.addAll(mission.requiredConceptIds);
    preferredIds.addAll(targetWorld.conceptIds.take(3));
    final unique = <String>{};
    final conceptsToPlan = preferredIds
        .where((id) => concepts.any((c) => c.id == id))
        .map(conceptById)
        .where((c) => unique.add(c.id))
        .take(4)
        .toList();
    if (conceptsToPlan.isEmpty) {
      _ensureWeeklyPlan(forceRegenerate: true);
      _persistAndNotify();
      return;
    }
    final sourceText = sourceWorldId == null ? '' : '基于「${worldById(sourceWorldId).title}」完成后的分支推荐，';
    _replaceWeeklyPlanWithConcepts(
      conceptsToPlan,
      summary: '${sourceText}系统已为你优先生成「${targetWorld.title}」的下一周计划：${conceptsToPlan.map((e) => '「${e.title}」').join('、')}。先把这条分支主线做成新的现实证据。',
    );
    _syncReminderSchedules();
    unawaited(syncNotificationBridge(force: true));
    _persistAndNotify();
  }

  String get growthJourneySummary {
    if (_taskRuns.isEmpty && _worldRewardEvents.isEmpty && _reflections.isEmpty) {
      return '你的成长旅程还没有留下太多证据。先完成一个现实动作，时间线就会开始发光。';
    }
    final summaryParts = <String>[
      '你已累计完成 ${_taskRuns.length} 次现实动作',
      '留下 ${_reflections.length} 条复盘',
      '解锁 ${_worldRewardEvents.length} 个阶段奖励',
    ];
    if (completedWorldCount > 0) {
      summaryParts.add('并完整点亮了 $completedWorldCount 个镜像世界');
    }
    return '${summaryParts.join('，')}。成长不是抽象感觉，而是这些被记录下来的行动证据。';
  }

  String get nextMainlineSummary {
    final mission = priorityMission;
    if (mission != null) {
      return missionUnlockBanner(mission);
    }
    final unlocked = recentlyUnlockedMissions;
    if (unlocked.isNotEmpty) {
      final next = unlocked.first;
      return '新主线已解锁：${worldById(next.worldId).title} · ${next.title}。现在适合顺着它继续往前。';
    }
    if (latestCompletionRewardEvent != null) {
      return '你刚完成一个完整世界：${rewardFeedNarrative(latestCompletionRewardEvent!)}。接下来可以把奖励转成新的现实动作。';
    }
    return '系统会继续根据你的现实动作和复盘，自动为你推荐下一条值得推进的主线。';
  }

  List<GrowthTimelineItem> recentJourneyItems({int limit = 5}) => growthTimelineItems(limit: limit);

  List<WorldRewardEvent> recentRewardEvents({int limit = 6}) => _worldRewardEvents.take(limit).toList();

  WorldRewardEvent? get latestRewardEvent => _worldRewardEvents.isEmpty ? null : _worldRewardEvents.first;

  List<WorldRewardEvent> get unseenRewardEvents =>
      _worldRewardEvents.where((e) => !_seenRewardEventIds.contains(e.id)).toList();

  int get unseenRewardCount => unseenRewardEvents.length;

  void markRewardEventSeen(String eventId, {bool persist = true}) {
    if (_seenRewardEventIds.add(eventId) && persist) {
      _persistAndNotify();
    }
  }

  void markAllRewardEventsSeen() {
    _seenRewardEventIds
      ..clear()
      ..addAll(_worldRewardEvents.map((e) => e.id));
    _persistAndNotify();
  }

  List<GrowthTimelineItem> growthTimelineItems({int limit = 30}) {
    final items = <GrowthTimelineItem>[];

    for (final event in _worldRewardEvents) {
      final isCompletion = isCompletionRewardEvent(event);
      items.add(GrowthTimelineItem(
        id: 'timeline_reward_${event.id}',
        type: TimelineItemType.reward,
        title: isCompletion ? '${worldById(event.worldId).title} · 世界完成奖励' : event.title,
        message: rewardFeedNarrative(event),
        createdAt: event.createdAt,
        worldId: event.worldId,
        missionId: event.missionId,
        accentLabel: isCompletion ? '世界完成奖励' : '阶段奖励',
      ));
    }

    for (final run in _taskRuns) {
      final concept = conceptById(run.conceptId);
      final task = taskById(run.conceptId, run.taskId);
      final delta = run.beforeScore - run.afterScore;
      final deltaText = delta == 0 ? '状态持平' : (delta > 0 ? '缓解 $delta 分' : '提升紧张 ${-delta} 分');
      items.add(GrowthTimelineItem(
        id: 'timeline_action_${run.conceptId}_${run.taskId}_${run.createdAt.microsecondsSinceEpoch}',
        type: TimelineItemType.action,
        title: '${concept.title} · ${task.title}',
        message: run.actionText.trim().isEmpty ? deltaText : '${run.actionText.trim()} · $deltaText',
        createdAt: run.createdAt,
        conceptId: run.conceptId,
        accentLabel: '现实动作',
      ));
    }

    for (final reflection in _reflections) {
      final concept = concepts.where((c) => c.id == reflection.conceptId).toList();
      items.add(GrowthTimelineItem(
        id: 'timeline_reflection_${reflection.conceptId}_${reflection.createdAt.microsecondsSinceEpoch}',
        type: TimelineItemType.reflection,
        title: concept.isEmpty ? '复盘记录' : '${concept.first.title} · 复盘',
        message: reflection.text,
        createdAt: reflection.createdAt,
        conceptId: reflection.conceptId,
        accentLabel: '复盘',
      ));
    }

    for (final mission in missionStages) {
      final record = missionRecordById(mission.id);
      if (record.unlockedAt != null) {
        items.add(GrowthTimelineItem(
          id: 'timeline_unlock_${mission.id}_${record.unlockedAt!.microsecondsSinceEpoch}',
          type: TimelineItemType.unlock,
          title: '${worldById(mission.worldId).title} · 阶段 ${mission.stageNo} 已解锁',
          message: '新主线已开启：${mission.title}',
          createdAt: record.unlockedAt!,
          worldId: mission.worldId,
          missionId: mission.id,
          accentLabel: '解锁',
        ));
      }
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(limit).toList();
  }

  List<TaskRecommendation> get recommendedTaskQueue {
    final results = <TaskRecommendation>[];
    final seen = <String>{};

    void add(TaskRecommendation? rec) {
      if (rec == null) return;
      final key = '${rec.concept.id}_${rec.task.id}';
      if (seen.add(key)) results.add(rec);
    }

    add(recommendedTaskNow);
    add(worldPriorityRecommendation);

    for (final instance in todayTaskInstances.where((e) => e.isOpen)) {
      add(TaskRecommendation(
        concept: conceptById(instance.conceptId),
        task: taskById(instance.conceptId, instance.taskId),
        reason: instance.assignedReason.isEmpty ? '这是今天已生成的待执行任务。' : instance.assignedReason,
      ));
    }

    for (final concept in suggestedToday) {
      final progress = progressById(concept.id);
      final preferredType = progress.status == ConceptStatus.unread ? TaskType.light : TaskType.main;
      final task = concept.tasks.firstWhere(
        (t) => t.type == preferredType,
        orElse: () => concept.tasks.first,
      );
      add(TaskRecommendation(
        concept: concept,
        task: task,
        reason: '这是系统为你排序后的下一优先动作。',
      ));
    }

    return results;
  }

  List<WorldMissionStage> get activeMissionQueue {
    final missions = <WorldMissionStage>[];
    for (final world in worldScenes) {
      final active = activeMissionForWorld(world.id);
      if (active != null && worldMissionStatus(active.id) == WorldMissionStatus.active) {
        missions.add(active);
      }
    }
    missions.sort((a, b) {
      final aRecord = missionRecordById(a.id);
      final bRecord = missionRecordById(b.id);
      final aUnlocked = aRecord.unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bUnlocked = bRecord.unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final recentUnlockCompare = bUnlocked.compareTo(aUnlocked);
      if (recentUnlockCompare != 0) return recentUnlockCompare;
      final remainA = remainingActionCountForMission(a.id);
      final remainB = remainingActionCountForMission(b.id);
      if (remainA != remainB) return remainA.compareTo(remainB);
      if (a.stageNo != b.stageNo) return a.stageNo.compareTo(b.stageNo);
      return a.title.compareTo(b.title);
    });
    return missions;
  }

  List<WorldMissionStage> get recentlyUnlockedMissions {
    final missions = missionStages.where((mission) {
      final record = missionRecordById(mission.id);
      return record.unlockedAt != null && !record.isCompleted;
    }).toList();
    missions.sort((a, b) {
      final at = missionRecordById(a.id).unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = missionRecordById(b.id).unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return missions;
  }

  WorldMissionStage? get priorityMission {
    final queue = activeMissionQueue;
    return queue.isEmpty ? null : queue.first;
  }

  int remainingActionCountForMission(String missionId) {
    final mission = missionStages.firstWhere((m) => m.id == missionId);
    final remaining = mission.actionTarget - worldMissionCurrentCount(missionId);
    return remaining < 0 ? 0 : remaining;
  }

  String missionUnlockBanner(WorldMissionStage mission) {
    final world = worldById(mission.worldId);
    if (!isWorldMissionUnlocked(mission.id)) {
      return '「${world.title}」的阶段 ${mission.stageNo} 还未解锁。先完成前置概念或上一阶段。';
    }
    if (isWorldMissionCompleted(mission.id)) {
      return '「${world.title}」的阶段 ${mission.stageNo} 已完成，奖励已经进入事件流。';
    }
    final remaining = remainingActionCountForMission(mission.id);
    if (remaining == 0) {
      return '「${world.title}」的阶段 ${mission.stageNo} 已满足推进条件，系统正在准备下一段主线。';
    }
    return '当前主线：${world.title} · ${mission.title}。再完成 $remaining 次相关现实动作，就会自动领奖并解锁下一阶段。';
  }

  String rewardFeedNarrative(WorldRewardEvent event) {
    final world = worldById(event.worldId);
    if (isCompletionRewardEvent(event)) {
      return '${world.title} 已完整点亮：${event.message}';
    }
    return '${world.title} 已完成「${event.title}」：${event.message}';
  }

  TaskRecommendation? get worldPriorityRecommendation {
    final mission = priorityMission;
    if (mission == null) return null;
    final base = recommendedTaskForWorld(mission.worldId);
    if (base == null) return null;
    return TaskRecommendation(
      concept: base.concept,
      task: base.task,
      reason: '优先推进世界主线「${mission.title}」。${base.reason}',
    );
  }

  void _ensureWeeklyPlan({bool forceRegenerate = false}) {
    final nowKey = _weekKey(DateTime.now());
    if (!forceRegenerate && _weeklyPlan != null && _weeklyPlan!.weekKey == nowKey && _weeklyPlan!.taskInstanceIds.isNotEmpty) {
      return;
    }

    final focus = <ChangeConcept>[];
    if (pinnedConcept != null) focus.add(pinnedConcept!);
    if (_diagnosisResult != null) {
      focus.addAll(_diagnosisResult!.recommendedConceptIds.where((id) => concepts.any((c) => c.id == id)).map(conceptById));
    }
    focus.addAll(suggestedToday);
    final unique = <String>{};
    final conceptsToPlan = focus.where((c) => unique.add(c.id)).take(4).toList();
    if (conceptsToPlan.isEmpty) {
      conceptsToPlan.addAll(concepts.take(3));
    }

    _replaceWeeklyPlanWithConcepts(
      conceptsToPlan,
      summary: '本周先围绕 ${conceptsToPlan.map((e) => '「${e.title}」').join('、')} 建立动作证据。每天先做计划里的一个任务，不求全做完。',
    );
  }

  void _replaceWeeklyPlanWithConcepts(List<ChangeConcept> conceptsToPlan, {required String summary}) {
    final nowKey = _weekKey(DateTime.now());
    _taskInstances.removeWhere((e) => e.isFromWeeklyPlan && e.status != TaskInstanceStatus.completed);
    final startOfWeek = _startOfWeek(DateTime.now());
    final createdIds = <String>[];
    for (var i = 0; i < conceptsToPlan.length; i++) {
      final concept = conceptsToPlan[i];
      final progress = progressById(concept.id);
      final task = progress.status == ConceptStatus.unread
          ? concept.tasks.firstWhere((t) => t.type == TaskType.light, orElse: () => concept.tasks.first)
          : concept.tasks.firstWhere((t) => t.type == TaskType.main, orElse: () => concept.tasks.first);
      final plannedFor = startOfWeek.add(Duration(days: i.clamp(0, 6)));
      final instance = ChangeTaskInstance(
        id: _newInstanceId(concept.id, task.id),
        conceptId: concept.id,
        taskId: task.id,
        taskType: task.type,
        plannedFor: plannedFor,
        createdAt: DateTime.now(),
        status: TaskInstanceStatus.planned,
        assignedReason: i == 0 ? '这是本周第一推进位，先把它做成行动证据。' : '这是系统为你安排的本周推进任务。',
        isFromWeeklyPlan: true,
      );
      createdIds.add(instance.id);
      _taskInstances.add(instance);
    }

    _weeklyPlan = WeeklyPlan(
      id: 'WP_${DateTime.now().millisecondsSinceEpoch}',
      weekKey: nowKey,
      createdAt: DateTime.now(),
      focusConceptIds: conceptsToPlan.map((e) => e.id).toList(),
      taskInstanceIds: createdIds,
      summary: summary,
    );
  }

  List<ChangeTaskInstance> taskInstancesForConcept(String conceptId) =>
      _taskInstances.where((e) => e.conceptId == conceptId).toList();

  List<ChangeTaskInstance> taskInstancesForDay(DateTime day) =>
      _taskInstances.where((e) => _isSameDay(e.plannedFor, day)).toList();

  String taskInstanceStatusLabel(TaskInstanceStatus status) {
    switch (status) {
      case TaskInstanceStatus.planned:
        return '待执行';
      case TaskInstanceStatus.inProgress:
        return '进行中';
      case TaskInstanceStatus.completed:
        return '已完成';
      case TaskInstanceStatus.failed:
        return '待重启';
      case TaskInstanceStatus.restarted:
        return '已重启';
      case TaskInstanceStatus.skipped:
        return '已跳过';
    }
  }

  Color taskInstanceStatusColor(TaskInstanceStatus status) {
    switch (status) {
      case TaskInstanceStatus.planned:
        return const Color(0xFF6D5EF0);
      case TaskInstanceStatus.inProgress:
        return const Color(0xFF1570EF);
      case TaskInstanceStatus.completed:
        return const Color(0xFF1C9E5E);
      case TaskInstanceStatus.failed:
        return const Color(0xFFC14C2A);
      case TaskInstanceStatus.restarted:
        return const Color(0xFF8E5CF7);
      case TaskInstanceStatus.skipped:
        return const Color(0xFF7A7F8A);
    }
  }

  String weeklyBucketLabel(DateTime day) {
    final start = _startOfWeek(DateTime.now());
    final delta = DateTime(day.year, day.month, day.day).difference(start).inDays;
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    if (delta >= 0 && delta < labels.length) return labels[delta];
    return '${day.month}/${day.day}';
  }

  List<ReminderSchedule> get dueReminderSchedules => _reminderSchedules
      .where((e) => e.isDue)
      .toList()
    ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));

  List<ReminderSchedule> get upcomingReminderSchedules => _reminderSchedules
      .where((e) => e.status == ReminderScheduleStatus.pending && e.scheduledFor.isAfter(DateTime.now()))
      .toList()
    ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));

  List<ReminderSchedule> get nextDayFollowups => _reminderSchedules
      .where((e) => e.type == ReminderType.nextDay && e.status == ReminderScheduleStatus.pending)
      .toList()
    ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));

  int get dueReminderCount => dueReminderSchedules.length;
  int get deliveredReminderCount => _deliveredReminderIds.length;

  ReminderSchedule? reminderById(String id) {
    final matches = _reminderSchedules.where((e) => e.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  void markReminderDone(String reminderId, {String note = ''}) {
    final index = _reminderSchedules.indexWhere((e) => e.id == reminderId);
    if (index == -1) return;
    final reminder = _reminderSchedules[index];
    _reminderSchedules[index] = reminder.copyWith(
      status: ReminderScheduleStatus.done,
      completedAt: DateTime.now(),
    );
    if (note.trim().isNotEmpty) {
      _reflections.insert(0, ReflectionEntry(
        conceptId: reminder.conceptId,
        taskId: reminder.taskId,
        text: note.trim(),
        createdAt: DateTime.now(),
      ));
    }
    if (reminder.type == ReminderType.nextDay) {
      _spawnFollowupFromReminder(reminder);
    }
    _persistAndNotify();
  }

  void snoozeReminder(String reminderId, {Duration delay = const Duration(hours: 2)}) {
    final index = _reminderSchedules.indexWhere((e) => e.id == reminderId);
    if (index == -1) return;
    final reminder = _reminderSchedules[index];
    _reminderSchedules[index] = reminder.copyWith(
      scheduledFor: DateTime.now().add(delay),
      status: ReminderScheduleStatus.pending,
      completedAt: null,
    );
    _deliveredReminderIds.remove(reminder.id);
    _persistAndNotify();
  }

  void dismissReminder(String reminderId) {
    final index = _reminderSchedules.indexWhere((e) => e.id == reminderId);
    if (index == -1) return;
    final reminder = _reminderSchedules[index];
    _reminderSchedules[index] = reminder.copyWith(
      status: ReminderScheduleStatus.dismissed,
      completedAt: DateTime.now(),
    );
    _persistAndNotify();
  }

  void _spawnFollowupFromReminder(ReminderSchedule reminder) {
    final concept = conceptById(reminder.conceptId);
    final progress = progressById(reminder.conceptId);
    final preferred = progress.status.index >= ConceptStatus.acted.index ? TaskType.challenge : TaskType.main;
    final task = concept.tasks.firstWhere(
      (t) => t.type == preferred,
      orElse: () => concept.tasks.firstWhere((t) => t.type == TaskType.light, orElse: () => concept.tasks.first),
    );
    final alreadyExists = _taskInstances.any((e) => e.conceptId == reminder.conceptId && e.taskId == task.id && e.isOpen);
    if (alreadyExists) return;
    _taskInstances.insert(0, ChangeTaskInstance(
      id: _newInstanceId(reminder.conceptId, task.id),
      conceptId: reminder.conceptId,
      taskId: task.id,
      taskType: task.type,
      plannedFor: DateTime.now(),
      createdAt: DateTime.now(),
      status: TaskInstanceStatus.planned,
      assignedReason: '来自次日追问后的延续动作：把昨天的行动继续往前推一点。',
      isFromWeeklyPlan: false,
    ));
    _syncReminderSchedules();
    unawaited(syncNotificationBridge());
  }

  String reminderScheduleLabel(ReminderSchedule schedule) =>
      '${_reminderTypeLabel(schedule.type)} · ${schedule.title}';

  String reminderDueLabel(ReminderSchedule schedule) {
    final t = schedule.scheduledFor;
    return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String nextDayFollowupPrompt(ReminderSchedule schedule) {
    final template = aiPromptForTask(
      conceptId: schedule.conceptId,
      taskId: schedule.taskId,
      scenario: PromptScenario.nextDayCheckin,
    );
    return template?.prompt ?? '昨天那个动作对今天留下了什么影响？你愿意延续哪一点？';
  }

  List<String> worldStoryBeats(String worldId) {
    switch (worldId) {
      case 'W01':
        return const ['你开始看见旧通路并不等于命运。', '新通路第一次被点亮。', '旧反应与新动作开始并存。'];
      case 'W02':
        return const ['你开始看见自己默认的解释方式。', '你第一次给同一件事写出第二种解释。', '镜像不再只反射焦虑，也开始反射选择。'];
      case 'W03':
        return const ['你开始允许情绪被看见。', '呼吸与命名让风暴开始松动。', '你不再只想消灭情绪，而是能穿过它。'];
      case 'W04':
        return const ['你开始把重要经验写下来。', '高峰体验不再只是回忆，而开始指向行动。', '痛苦与高峰都被整合进你的生命叙事。'];
      case 'W05':
        return const ['你开始用身体和行为进入世界。', '行为第一次反过来支持了态度。', '你正在把“知道”变成看得见的证据。'];
      case 'W06':
        return const ['你第一次主动进入拉伸区。', '失败不再意味着退出，而是进入重启。', '完整感来自一次次真实行动，而不是空想。'];
      default:
        return const ['开始建立动作证据。', '用现实推进世界。'];
    }
  }

  int worldStage(String worldId) {
    final progress = worldProgress(worldId);
    if (!progress.unlocked) return 0;
    final completed = completedMissionCountForWorld(worldId);
    if (completed <= 0) return 1;
    if (completed >= missionsForWorld(worldId).length) return 3;
    return (completed + 1).clamp(1, 3);
  }

  String worldNarrativeText(String worldId) {
    final stage = worldStage(worldId);
    final beats = worldStoryBeats(worldId);
    if (stage == 0) return '这个世界还没完全解锁。先完成前置概念的阅读或行动，让入口真正打开。';
    if (stage == 1) return beats.first;
    if (stage == 2) return beats.length > 1 ? beats[1] : beats.first;
    return beats.last;
  }

  String worldNextMilestoneText(String worldId) {
    final progress = worldProgress(worldId);
    if (!progress.unlocked) return worldUnlockHint(worldId);
    if (progress.completed) return '这个世界的阶段任务已全部完成。现在适合去做挑战任务，巩固奖励，并推动后续世界。';
    final active = activeMissionForWorld(worldId);
    if (active == null) return '继续完成相关现实动作，系统会自动推进阶段主线。';
    final remaining = (active.actionTarget - worldMissionCurrentCount(active.id)).clamp(0, 99);
    if (remaining <= 0) {
      return '当前阶段奖励已解锁，系统正在准备下一阶段。';
    }
    return '当前里程碑：${active.title}。再完成 $remaining 次相关现实动作，就会自动领奖并解锁下一阶段。';
  }

  WorldProgress worldProgress(String worldId) {
    final missions = missionsForWorld(worldId);
    final completedStages = completedMissionCountForWorld(worldId);
    final worldRuns = _taskRuns.where((e) => worldById(worldId).conceptIds.contains(e.conceptId)).toList();
    final missionTimestamps = missions
        .map((m) => missionRecordById(m.id).lastProgressAt)
        .whereType<DateTime>()
        .toList();
    final allTimes = <DateTime>[...worldRuns.map((e) => e.createdAt), ...missionTimestamps];
    allTimes.sort((a, b) => b.compareTo(a));
    final lastActionAt = allTimes.isEmpty ? null : allTimes.first;
    final unlocked = isWorldUnlocked(worldId);
    final target = missions.isEmpty ? 1 : missions.length;
    final completed = unlocked && completedStages >= target;
    return WorldProgress(
      worldId: worldId,
      unlocked: unlocked,
      completed: completed,
      completedActions: completedStages,
      targetActions: target,
      lastActionAt: lastActionAt,
    );
  }

  String worldProgressLabel(String worldId) {
    final progress = worldProgress(worldId);
    if (!progress.unlocked) return '待解锁';
    if (progress.completed) return '世界点亮';
    return '阶段推进中';
  }

  void _syncReminderSchedules() {
    final validInstanceIds = _taskInstances.map((e) => e.id).toSet();
    _reminderSchedules.removeWhere((e) => e.instanceId.isNotEmpty && !validInstanceIds.contains(e.instanceId));
    final validReminderIds = _reminderSchedules.map((e) => e.id).toSet();
    _deliveredReminderIds.removeWhere((id) => !validReminderIds.contains(id));
    for (final instance in _taskInstances) {
      final task = taskById(instance.conceptId, instance.taskId);
      final concept = conceptById(instance.conceptId);
      final world = worldScenes.where((w) => w.conceptIds.contains(instance.conceptId));
      final worldId = world.isEmpty ? null : world.first.id;
      if (instance.status == TaskInstanceStatus.planned || instance.status == TaskInstanceStatus.inProgress) {
        _ensureReminderForInstance(instance, task, concept, ReminderType.pre, _atHour(instance.plannedFor, 9), worldId: worldId);
        _ensureReminderForInstance(instance, task, concept, ReminderType.moment, _atHour(instance.plannedFor, 18), worldId: worldId);
      }
      if (instance.status == TaskInstanceStatus.failed) {
        _ensureReminderForInstance(instance, task, concept, ReminderType.interrupt, DateTime.now().add(const Duration(minutes: 30)), worldId: worldId);
      }
      if (instance.status == TaskInstanceStatus.completed && instance.completedAt != null) {
        final next = _atHour(instance.completedAt!.add(const Duration(days: 1)), 9);
        _ensureReminderForInstance(instance, task, concept, ReminderType.nextDay, next, worldId: worldId);
      }
    }
  }

  void _ensureReminderForInstance(
    ChangeTaskInstance instance,
    ChangeTask task,
    ChangeConcept concept,
    ReminderType type,
    DateTime scheduledFor, {
    String? worldId,
  }) {
    final existsIndex = _reminderSchedules.indexWhere((e) => e.instanceId == instance.id && e.type == type);
    final template = reminders.firstWhere(
      (r) => r.conceptId == concept.id && r.taskId == task.id && r.type == type,
      orElse: () => ReminderTemplate(
        id: 'TMP_${concept.id}_${task.id}_${type.name}',
        conceptId: concept.id,
        taskId: task.id,
        type: type,
        title: _reminderTypeLabel(type),
        message: type == ReminderType.nextDay
            ? '昨天那个动作对今天留下了什么影响？'
            : type == ReminderType.interrupt
                ? '先把动作缩小，不要直接退出。'
                : task.summary,
      ),
    );
    final schedule = ReminderSchedule(
      id: existsIndex == -1 ? _newReminderId(instance.id, type) : _reminderSchedules[existsIndex].id,
      instanceId: instance.id,
      conceptId: concept.id,
      taskId: task.id,
      type: type,
      scheduledFor: scheduledFor,
      createdAt: DateTime.now(),
      title: template.title,
      message: template.message,
      status: existsIndex == -1 ? ReminderScheduleStatus.pending : _reminderSchedules[existsIndex].status,
      worldId: worldId,
      completedAt: existsIndex == -1 ? null : _reminderSchedules[existsIndex].completedAt,
    );
    if (existsIndex == -1) {
      _reminderSchedules.add(schedule);
    } else if (_reminderSchedules[existsIndex].status == ReminderScheduleStatus.pending) {
      _reminderSchedules[existsIndex] = schedule;
    }
    if (schedule.status == ReminderScheduleStatus.pending && schedule.scheduledFor.isAfter(DateTime.now())) {
      _deliveredReminderIds.remove(schedule.id);
    }
  }

  DateTime _atHour(DateTime base, int hour) => DateTime(base.year, base.month, base.day, hour);

  String _newReminderId(String instanceId, ReminderType type) =>
      'RS_${instanceId}_${type.name}';


  List<String> courseParagraphsForConcept(String conceptId, {bool isCaseSection = false}) {
    final entry = changeCourseFullContent[conceptId];
    final raw = isCaseSection
        ? ((entry?.caseText.isNotEmpty == true) ? entry!.caseText : conceptById(conceptId).classicCase)
        : ((entry?.fullText.isNotEmpty == true) ? entry!.fullText : conceptById(conceptId).courseEssence);
    return raw
        .split(RegExp(r'\n\s*\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String paragraphRecordId(String conceptId, String sectionType, int paragraphIndex) =>
      'CP_${conceptId}_${sectionType}_$paragraphIndex';

  CourseParagraphRecord paragraphRecord(String conceptId, String sectionType, int paragraphIndex) {
    final id = paragraphRecordId(conceptId, sectionType, paragraphIndex);
    return _courseParagraphRecords[id] ??
        CourseParagraphRecord(
          id: id,
          conceptId: conceptId,
          sectionType: sectionType,
          paragraphIndex: paragraphIndex,
          updatedAt: DateTime.now(),
        );
  }

  bool isParagraphFavorite(String conceptId, String sectionType, int paragraphIndex) =>
      paragraphRecord(conceptId, sectionType, paragraphIndex).isFavorite;

  bool isParagraphInReviewList(String conceptId, String sectionType, int paragraphIndex) =>
      paragraphRecord(conceptId, sectionType, paragraphIndex).inReviewList;

  String paragraphNote(String conceptId, String sectionType, int paragraphIndex) =>
      paragraphRecord(conceptId, sectionType, paragraphIndex).note;

  void toggleParagraphFavorite(String conceptId, String sectionType, int paragraphIndex) {
    final current = paragraphRecord(conceptId, sectionType, paragraphIndex);
    _courseParagraphRecords[current.id] = current.copyWith(
      isFavorite: !current.isFavorite,
      updatedAt: DateTime.now(),
    );
    _persistAndNotify();
  }

  void toggleParagraphReviewList(String conceptId, String sectionType, int paragraphIndex) {
    final current = paragraphRecord(conceptId, sectionType, paragraphIndex);
    _courseParagraphRecords[current.id] = current.copyWith(
      inReviewList: !current.inReviewList,
      updatedAt: DateTime.now(),
    );
    _persistAndNotify();
  }

  void saveParagraphNote(String conceptId, String sectionType, int paragraphIndex, String note) {
    final current = paragraphRecord(conceptId, sectionType, paragraphIndex);
    final trimmed = note.trim();
    _courseParagraphRecords[current.id] = current.copyWith(
      note: trimmed,
      updatedAt: DateTime.now(),
    );
    _persistAndNotify();
  }

  CourseParagraphView? paragraphViewForRecord(CourseParagraphRecord record) {
    final concept = concepts.where((e) => e.id == record.conceptId);
    if (concept.isEmpty) return null;
    final entry = changeCourseFullContent[record.conceptId];
    final blocks = courseParagraphsForConcept(record.conceptId, isCaseSection: record.sectionType == 'case');
    if (record.paragraphIndex < 0 || record.paragraphIndex >= blocks.length) return null;
    return CourseParagraphView(
      record: record,
      conceptTitle: concept.first.title,
      lectureLabel: entry?.lectureLabel ?? concept.first.title,
      blockTitle: record.sectionType == 'case' ? '案例卡片 ${record.paragraphIndex + 1}' : '原课分段 ${record.paragraphIndex + 1}',
      text: blocks[record.paragraphIndex],
      keyPoint: entry?.keyPoint ?? concept.first.oneLineSummary,
    );
  }

  List<CourseParagraphView> _paragraphViewsWhere(bool Function(CourseParagraphRecord record) test) {
    final records = _courseParagraphRecords.values.where(test).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records
        .map(paragraphViewForRecord)
        .whereType<CourseParagraphView>()
        .toList();
  }

  List<CourseParagraphView> get favoriteParagraphViews =>
      _paragraphViewsWhere((record) => record.isFavorite);

  List<CourseParagraphView> get reviewParagraphViews =>
      _paragraphViewsWhere((record) => record.inReviewList);

  List<CourseParagraphView> get notedParagraphViews =>
      _paragraphViewsWhere((record) => record.note.trim().isNotEmpty);

  int get favoriteParagraphCount => favoriteParagraphViews.length;
  int get reviewParagraphCount => reviewParagraphViews.length;
  int get notedParagraphCount => notedParagraphViews.length;

  List<CourseParagraphView> recentCourseStudyItems({int limit = 6}) {
    final ids = <String>{};
    final merged = <CourseParagraphView>[];
    for (final view in [
      ...reviewParagraphViews,
      ...favoriteParagraphViews,
      ...notedParagraphViews,
    ]) {
      if (ids.add(view.record.id)) merged.add(view);
      if (merged.length >= limit) break;
    }
    return merged;
  }

  void _persistAndNotify() {
    notifyListeners();
    _saveState();
  }

  String _weekKey(DateTime time) {
    final start = _startOfWeek(time);
    return '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final weekday = normalized.weekday;
    return normalized.subtract(Duration(days: weekday - 1));
  }

  String _newInstanceId(String conceptId, String taskId) =>
      'TI_${conceptId}_${taskId}_${DateTime.now().microsecondsSinceEpoch}';

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
