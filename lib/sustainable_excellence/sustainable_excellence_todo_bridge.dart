import 'dart:convert';

import '../external_data/todo_dao.dart';
import '../external_data/todo_models.dart';
import 'sustainable_excellence_dao.dart';
import 'sustainable_excellence_models.dart';

class SustainableExcellenceTodoBridge {
  final TodoDao _todoDao = TodoDao();
  final SustainableExcellenceDao _seDao = SustainableExcellenceDao();

  Future<void> updateSourceTodoLinked(SustainableExcellenceCase item, {String generatedTaskId = ''}) async {
    final sourceId = item.sourceTodoId.trim();
    if (sourceId.isEmpty) return;
    final task = await _todoDao.getTask(sourceId);
    if (task == null) return;
    final generated = generatedTaskId.trim().isNotEmpty ? generatedTaskId.trim() : item.linkedTodoTaskId.trim();
    final managedBlock = _managedBlock(
      item: item,
      generatedTaskId: generated,
      stageEvents: _extractStageEvents(task.bodyText),
    );
    await _todoDao.updateLocalTask(
      taskId: task.taskId,
      title: task.title,
      bodyText: _replaceManagedBlock(task.bodyText, managedBlock),
      status: task.status,
      importance: task.importance,
      dueDateTime: task.dueDateTime,
      dueTimeZone: task.dueTimeZone,
      startDateTime: task.startDateTime,
      startTimeZone: task.startTimeZone,
      isReminderOn: task.isReminderOn,
      reminderDateTime: task.reminderDateTime,
      reminderTimeZone: task.reminderTimeZone,
      recurrenceJson: task.recurrenceJson,
      categoriesJson: _mergedCategories(task.categoriesJson, <String>['可持续卓越', '已转入实验室', item.spiralStage]),
      isMyDay: task.isMyDay,
    );
  }

  Future<void> markSourceTodoStage(SustainableExcellenceCase item, String stageLabel) async {
    final sourceId = item.sourceTodoId.trim();
    if (sourceId.isEmpty) return;
    final task = await _todoDao.getTask(sourceId);
    if (task == null) return;
    final events = <String>[_stageEventLine(stageLabel), ..._extractStageEvents(task.bodyText)].take(5).toList();
    final managedBlock = _managedBlock(item: item, generatedTaskId: item.linkedTodoTaskId, stageEvents: events);
    await _todoDao.updateLocalTask(
      taskId: task.taskId,
      title: task.title,
      bodyText: _replaceManagedBlock(task.bodyText, managedBlock),
      status: task.status,
      importance: task.importance,
      dueDateTime: task.dueDateTime,
      dueTimeZone: task.dueTimeZone,
      startDateTime: task.startDateTime,
      startTimeZone: task.startTimeZone,
      isReminderOn: task.isReminderOn,
      reminderDateTime: task.reminderDateTime,
      reminderTimeZone: task.reminderTimeZone,
      recurrenceJson: task.recurrenceJson,
      categoriesJson: _mergedCategories(task.categoriesJson, <String>['可持续卓越', stageLabel]),
      isMyDay: task.isMyDay,
    );
  }


  static const String _blockStart = '<!-- sustainable_excellence:start -->';
  static const String _blockEnd = '<!-- sustainable_excellence:end -->';

  String _managedBlock({required SustainableExcellenceCase item, String generatedTaskId = '', List<String> stageEvents = const <String>[]}) {
    final generatedIds = <String>[
      if (generatedTaskId.trim().isNotEmpty) generatedTaskId.trim(),
      ...item.generatedTodoTaskIds,
    ];
    final uniqueGenerated = <String>[];
    for (final id in generatedIds) {
      final clean = id.trim();
      if (clean.isNotEmpty && !uniqueGenerated.contains(clean)) uniqueGenerated.add(clean);
    }
    final lines = <String>[
      _blockStart,
      '已转入可持续卓越实验室：${item.title}',
      '关联实验ID：${item.id}',
      if (uniqueGenerated.isNotEmpty) '最近生成的下一步 Todo：${uniqueGenerated.first}',
      if (uniqueGenerated.length > 1) "历史生成 Todo：${uniqueGenerated.take(8).join('、')}",
      '当前螺旋阶段：${SustainableSpiralStage.label(item.spiralStage)}',
      '下一环建议：${SustainableSpiralStage.label(item.nextRecommendedStage)}',
      '最近更新时间：${DateTime.now().toIso8601String()}',
      if (stageEvents.isNotEmpty) '最近事件：',
      ...stageEvents.take(5),
      _blockEnd,
    ];
    return lines.join('\n');
  }

  String _replaceManagedBlock(String original, String block) {
    var body = original.trim();
    final reg = RegExp(r'<!-- sustainable_excellence:start -->[\s\S]*?<!-- sustainable_excellence:end -->', multiLine: true);
    body = body.replaceAll(reg, '').trim();
    if (body.isEmpty) return block;
    return '$body\n\n$block';
  }

  List<String> _extractStageEvents(String body) {
    final reg = RegExp(r'<!-- sustainable_excellence:start -->[\s\S]*?<!-- sustainable_excellence:end -->', multiLine: true);
    final match = reg.firstMatch(body);
    if (match == null) return const <String>[];
    final block = match.group(0) ?? '';
    final lines = block.split('\n').map((e) => e.trim()).where((e) => e.startsWith('- ')).toList();
    return lines.take(5).toList();
  }

  String _stageEventLine(String label) => '- ${DateTime.now().toIso8601String()} $label';

  String _mergedCategories(String raw, List<String> additions) {
    final values = <String>[];
    try {
      final decoded = jsonDecode(raw.trim().isEmpty ? '[]' : raw);
      if (decoded is List) values.addAll(decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty));
    } catch (_) {}
    for (final add in additions) {
      final v = add.trim();
      if (v.isNotEmpty && !values.contains(v)) values.add(v);
    }
    return jsonEncode(values.take(12).toList());
  }

  Future<TodoListRecord> _defaultList() async {
    final lists = await _todoDao.listLists();
    if (lists.isNotEmpty) {
      final defaultLists = lists.where((e) => e.wellknownListName == 'defaultList').toList();
      if (defaultLists.isNotEmpty) return defaultLists.first;
      final taskLists = lists.where((e) => !e.isSmartView).toList();
      if (taskLists.isNotEmpty) return taskLists.first;
      return lists.first;
    }
    final id = await _todoDao.createLocalList('可持续卓越行动', themeColor: '#4338CA');
    final created = await _todoDao.getList(id);
    if (created != null) return created;
    throw StateError('无法创建本地 Todo 列表');
  }

  Future<String> writeCaseNextTodo(SustainableExcellenceCase item) async {
    final list = item.sourceListId.trim().isNotEmpty ? (await _todoDao.getList(item.sourceListId.trim())) ?? await _defaultList() : await _defaultList();
    final body = _bodyForCase(item);
    final taskId = await _todoDao.createLocalTask(
      listId: list.listId,
      title: item.todoWriteback.nextTodoTitle.trim().isEmpty ? '做一次可持续卓越实验' : item.todoWriteback.nextTodoTitle.trim(),
      bodyText: body,
      status: 'notStarted',
      importance: 'normal',
      categoriesJson: '["可持续卓越","${item.todoWriteback.statusLabel}"]',
      isMyDay: true,
    );
    final steps = item.todoWriteback.nextTodoSteps.isEmpty ? item.actionExperiments.first.steps : item.todoWriteback.nextTodoSteps;
    for (final step in steps) {
      await _todoDao.upsertLocalChecklistItem(listId: list.listId, taskId: taskId, title: step);
    }
    await _seDao.linkTodo(caseId: item.id, taskId: taskId, sourceTodoId: item.sourceTodoId, sourceListId: list.listId);
    await updateSourceTodoLinked(item.copyWith(linkedTodoTaskId: taskId, sourceListId: list.listId, generatedTodoTaskIds: <String>[taskId, ...item.generatedTodoTaskIds]), generatedTaskId: taskId);
    return taskId;
  }

  Future<String> writeExperimentTodo(SustainableExcellenceCase item, SustainableActionExperiment exp) async {
    final list = item.sourceListId.trim().isNotEmpty ? (await _todoDao.getList(item.sourceListId.trim())) ?? await _defaultList() : await _defaultList();
    final body = '''
来自「可持续卓越实验室」
父目标：${item.userGoal}
实验：${exp.title}
适用状态：${exp.suitableWhen}

行动前恢复：${exp.recoveryBefore}
可能失败点：${exp.failurePoint}
失败学习：${exp.failureLearningMethod}
过程锚点：${exp.processAnchor}
行动后恢复：${exp.recoveryAfter}

核心提醒：这不是证明我行不行的考试，只是一次获得反馈的实验。
''';
    final taskId = await _todoDao.createLocalTask(
      listId: list.listId,
      title: exp.title,
      bodyText: body,
      status: 'notStarted',
      importance: exp.type == 'challenge_action' ? 'high' : 'normal',
      categoriesJson: '["可持续卓越","行动实验","${exp.type}"]',
      isMyDay: true,
    );
    for (final step in exp.steps) {
      await _todoDao.upsertLocalChecklistItem(listId: list.listId, taskId: taskId, title: step);
    }
    await _seDao.linkTodo(caseId: item.id, taskId: taskId, sourceTodoId: item.sourceTodoId, sourceListId: list.listId);
    await updateSourceTodoLinked(item.copyWith(linkedTodoTaskId: taskId, sourceListId: list.listId, generatedTodoTaskIds: <String>[taskId, ...item.generatedTodoTaskIds]), generatedTaskId: taskId);
    return taskId;
  }

  Future<String> writeFailureNextTodo({
    required SustainableExcellenceCase item,
    required String title,
    required List<String> steps,
  }) async {
    final list = item.sourceListId.trim().isNotEmpty ? (await _todoDao.getList(item.sourceListId.trim())) ?? await _defaultList() : await _defaultList();
    final taskId = await _todoDao.createLocalTask(
      listId: list.listId,
      title: title.trim().isEmpty ? item.failureLearning.nextSmallerExperiment : title.trim(),
      bodyText: '''
来自「失败学习复盘」
原目标：${item.userGoal}
失败类型：${item.lastFailureType}

下一轮原则：不要增加压力，只改变一个变量，让任务更小、更具体、更可恢复。
''',
      status: 'notStarted',
      importance: 'normal',
      categoriesJson: '["可持续卓越","失败学习","下一轮更小实验"]',
      isMyDay: true,
    );
    for (final step in steps.where((e) => e.trim().isNotEmpty)) {
      await _todoDao.upsertLocalChecklistItem(listId: list.listId, taskId: taskId, title: step.trim());
    }
    await _seDao.linkTodo(caseId: item.id, taskId: taskId, sourceTodoId: item.sourceTodoId, sourceListId: list.listId);
    await updateSourceTodoLinked(item.copyWith(linkedTodoTaskId: taskId, sourceListId: list.listId, generatedTodoTaskIds: <String>[taskId, ...item.generatedTodoTaskIds]), generatedTaskId: taskId);
    return taskId;
  }

  Future<SustainableExcellenceCase?> buildCaseSeedFromTodo(String taskId) async {
    final task = await _todoDao.getTask(taskId);
    if (task == null) return null;
    final checklist = await _todoDao.listChildren(task.taskId, 'checklistItem');
    final checklistSteps = checklist.map((e) => e.title.trim()).where((e) => e.isNotEmpty).toList();
    final metaLines = <String>[
      if (task.bodyText.trim().isNotEmpty) task.bodyText.trim(),
      if (checklistSteps.isNotEmpty) 'Todo 检查清单：${checklistSteps.join('；')}',
      if (task.dueDateTime.trim().isNotEmpty) '到期时间：${task.dueDateTime} ${task.dueTimeZone}',
      if (task.isReminderOn) '提醒时间：${task.reminderDateTime} ${task.reminderTimeZone}',
      if (task.importance.trim().isNotEmpty) '重要性：${task.importance}',
      if (task.recurrenceJson.trim().isNotEmpty) '重复规则：${task.recurrenceJson}',
      if (task.categoriesJson.trim().isNotEmpty) '分类：${task.categoriesJson}',
      if (task.isMyDay) '已加入我的一天',
    ];
    final now = DateTime.now().millisecondsSinceEpoch;
    return SustainableExcellenceCase(
      id: 'se_todo_${DateTime.now().microsecondsSinceEpoch}',
      source: 'todo',
      sourceTodoId: task.taskId,
      sourceListId: task.listId,
      linkedTodoTaskId: '',
      generatedTodoTaskIds: const <String>[],
      title: '「${task.title}」的可持续卓越实验',
      coreTheme: '压力-恢复-失败-反馈-卓越-过程',
      userGoal: task.title,
      currentStateSummary: metaLines.isEmpty ? '这是从 Todo 导入的目标，适合转化为可执行、可失败、可恢复的小实验。' : metaLines.join('\n'),
      modeDetection: const SustainableModeDetection(
        pressureLevel: 'medium',
        recoveryLevel: 'insufficient',
        perfectionismLevel: 'medium',
        failureFearLevel: 'medium',
        processConnectionLevel: 'medium',
      ),
      valueMapping: const SustainableValueMapping(
        preserve: <String>['目标感', '责任感', '想把事情推进到现实行动中'],
        adjust: <String>['把 Todo 当成一次性证明自己的任务', '只盯完成状态而忽略尝试、恢复与复盘'],
        coreReframe: '这个 Todo 不是一场成败审判，而是一轮可以尝试、恢复、失败学习和再行动的卓越实验。',
      ),
      obstacleAnalysis: const <SustainableObstacleAnalysis>[],
      actionExperiments: checklistSteps.isEmpty ? _fallbackBridgeExperiments() : _experimentsFromChecklist(task.title, checklistSteps),
      recoveryPlan: const SustainableRecoveryPlan(
        microRecovery: <String>['3次慢呼吸', '喝水', '离开屏幕2分钟'],
        mediumRecovery: <String>['15分钟散步', '整理桌面', '冥想10分钟'],
        deepRecovery: <String>['完整休息日', '减少社交媒体', '保证睡眠'],
        recommendedRhythm: '25分钟行动 + 5分钟恢复',
      ),
      failureLearning: const SustainableFailureLearning(
        possibleFailureType: 'Todo 过大 / 启动失败 / 完美主义拖延',
        ifFailedThen: '如果失败，只提取一个可改变变量，不做人格否定。',
        learningQuestion: '这次失败暴露的是任务大小、恢复不足、环境诱因还是失败恐惧？',
        nextSmallerExperiment: '把这个 Todo 缩小为 5 分钟能开始的一步。',
      ),
      processEnjoyment: const SustainableProcessEnjoyment(
        meaningConnection: '这个 Todo 连接到现实行动、能力感和自我信任。',
        onePercentExperience: '只寻找 1% 的掌控感：我已经开始把它推进到现实。',
        duringActionReminder: '这只是一次实验，不是证明自己完美。',
        afterActionReflection: '这次行动里，哪一小部分值得保留？',
      ),
      todoWriteback: SustainableTodoWriteback(
        nextTodoTitle: '做一次 5 分钟「${task.title}」最小行动实验',
        nextTodoSteps: checklistSteps.isEmpty ? const <String>['打开材料', '完成第一小步', '记录一个反馈', '安排微恢复'] : checklistSteps,
        parentGoal: task.title,
        statusLabel: 'attempted',
        evidenceTags: const <String>['Todo已转实验', '失败可学习', '恢复已安排'],
      ),
      reflectionQuestions: const <String>['这个 Todo 当前处在卓越螺旋哪一环？', '我下一步只改变哪个变量？'],
      coachMessage: '先不要把 Todo 当成必须完美完成的压力，把它变成一轮可执行的小实验。',
      riskNote: '',
      provider: 'local',
      modelLabel: 'Todo 导入种子',
      selectedExperimentType: '',
      spiralStage: SustainableSpiralStage.experiment,
      spiralCycleCount: 0,
      lastFailureType: '',
      lastRecoveryAtMs: 0,
      lastActionAtMs: 0,
      nextRecommendedStage: SustainableSpiralStage.action,
      archivedAtMs: 0,
      logs: const <SustainableEvidenceLog>[],
      createdAtMs: now,
      updatedAtMs: now,
    );
  }

  String _bodyForCase(SustainableExcellenceCase item) => '''
来自「可持续卓越实验室」
父目标：${item.userGoal}
核心主题：${item.coreTheme}
当前螺旋阶段：${SustainableSpiralStage.label(item.spiralStage)}

价值重构：${item.valueMapping.coreReframe}
行动中提醒：${item.processEnjoyment.duringActionReminder}
失败学习：${item.failureLearning.ifFailedThen}
恢复节律：${item.recoveryPlan.recommendedRhythm}
''';
}


List<SustainableActionExperiment> _experimentsFromChecklist(String goalTitle, List<String> checklistSteps) {
  final cleanSteps = checklistSteps.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (cleanSteps.isEmpty) return _fallbackBridgeExperiments();
  final firstSteps = cleanSteps.take(6).toList();
  final minimumStep = firstSteps.first;
  return <SustainableActionExperiment>[
    SustainableActionExperiment(
      type: 'todo_checklist_minimum_action',
      title: '先完成清单第一步：$minimumStep',
      suitableWhen: '适合从 Todo 导入后，任务已经有检查清单，但用户仍然容易因压力、完美主义或任务过大而启动困难时。',
      steps: <String>[
        '打开「$goalTitle」相关材料',
        '只完成检查清单第一步：$minimumStep',
        '记录实际阻碍：任务过大、环境分心、恢复不足，还是害怕失败',
        '做 2 分钟微恢复，再决定是否继续下一步',
      ],
      timeRequired: '5-15分钟',
      failurePoint: '想一次完成全部清单，导致启动成本过高。',
      failureLearningMethod: '失败后只缩小下一步，不评价自己；判断第一步是否还需要继续拆小。',
      recoveryBefore: '闭眼呼吸 30 秒，提醒自己：这只是启动实验，不是完成全部任务。',
      recoveryAfter: '离开屏幕或材料 2-3 分钟，记录一个行动证据。',
      processAnchor: '我正在把 Todo 从压力对象转成可执行的第一步。',
    ),
    SustainableActionExperiment(
      type: 'todo_checklist_sequence_action',
      title: '按顺序推进 ${firstSteps.length} 个检查项',
      suitableWhen: '适合已经能开始，但需要稳定节奏和清晰边界时。',
      steps: firstSteps,
      timeRequired: firstSteps.length <= 3 ? '25分钟' : '25-45分钟',
      failurePoint: '中途跳到更难的步骤、反复检查，或试图把每一步都做到完美。',
      failureLearningMethod: '只复盘一个变量：步骤顺序、步骤大小、时间估计或恢复间隔。',
      recoveryBefore: '把清单只显示当前要做的 1-3 步，降低认知负荷。',
      recoveryAfter: '完成后暂停 5 分钟，不马上追加更大目标。',
      processAnchor: '卓越不是一次性清空全部清单，而是稳定地推进一个小循环。',
    ),
    SustainableActionExperiment(
      type: 'todo_checklist_feedback_action',
      title: '完成一个可反馈版本',
      suitableWhen: '适合清单较长、容易卡在完美主义修改，或需要先拿到现实反馈时。',
      steps: <String>[
        ...firstSteps.take(4),
        '把当前结果保存或提交为一个不完美版本',
        '只收集一个反馈，不立刻进行无限修改',
      ],
      timeRequired: '40-90分钟',
      failurePoint: '因为害怕评价而不提交，或在提交前无限补充细节。',
      failureLearningMethod: '把反馈当作下一轮实验信息，而不是自我价值判决。',
      recoveryBefore: '写下一句允许语：我允许这个版本先不完美。',
      recoveryAfter: '提交/保存后做中恢复，避免立刻反复检查。',
      processAnchor: '真实反馈比脑内完美更能推动可持续卓越。',
    ),
  ];
}

List<SustainableActionExperiment> _fallbackBridgeExperiments() => const <SustainableActionExperiment>[
        SustainableActionExperiment(
          type: 'minimum_action',
          title: '5分钟粗糙开始',
          suitableWhen: '适合压力高、害怕失败、迟迟开始不了时。',
          steps: <String>['打开任务材料', '只做第一小步', '停止前写下一句反馈'],
          timeRequired: '5分钟',
          failurePoint: '想一次性做完，导致启动焦虑。',
          failureLearningMethod: '失败后只判断任务是否过大，不评价自己。',
          recoveryBefore: '闭眼呼吸 30 秒，提醒自己这只是实验。',
          recoveryAfter: '离开屏幕 3 分钟，记录一个学习点。',
          processAnchor: '我正在练习开始，而不是证明自己完美。',
        ),
        SustainableActionExperiment(
          type: 'standard_action',
          title: '25分钟行动 + 5分钟恢复',
          suitableWhen: '适合能量中等、可以进入专注但需要节律时。',
          steps: <String>['设定25分钟计时', '完成一个明确小块', '结束后复盘并恢复5分钟'],
          timeRequired: '30分钟',
          failurePoint: '中途分心或想把标准抬太高。',
          failureLearningMethod: '记录分心触发点，下一轮只改一个环境变量。',
          recoveryBefore: '整理桌面，只留下当前材料。',
          recoveryAfter: '伸展、喝水、短暂走动。',
          processAnchor: '我在积累行动证据和能力感。',
        ),
        SustainableActionExperiment(
          type: 'challenge_action',
          title: '提交一个不完美版本',
          suitableWhen: '适合已有基础但因完美主义迟迟不提交时。',
          steps: <String>['确定最低可提交标准', '完成并提交一个版本', '只收集反馈，不做自我审判'],
          timeRequired: '40-90分钟',
          failurePoint: '反复修改、害怕评价、拖延提交。',
          failureLearningMethod: '把反馈看成版本迭代信息，而不是人格判决。',
          recoveryBefore: '写下“我允许这个版本不完美”。',
          recoveryAfter: '做一次中恢复，暂时不反复检查。',
          processAnchor: '真正的卓越来自反馈循环，不来自无错幻想。',
        ),
      ];
