import 'james_will_training_dao.dart';
import 'james_will_training_models.dart';
import 'todo_goal_models.dart';

/// Keeps the existing Todo goal/value system as the source of truth while
/// projecting one goal action into the Jamesian will-training engine.
class TodoGoalWillBridge {
  TodoGoalWillBridge({JamesWillTrainingDao? willDao}) : _willDao = willDao ?? JamesWillTrainingDao();

  final JamesWillTrainingDao _willDao;

  static String ideaIdFor(String goalId, String? stepId) {
    final actionKey = (stepId ?? '').trim().isEmpty ? 'goal' : stepId!.trim();
    return 'todo_goal_will_${goalId.trim()}_$actionKey';
  }

  JamesWillActionIdea project({required TodoGoalProfile goal, TodoGoalActionStep? step, JamesWillActionIdea? existing}) {
    final seed = JamesWillActionIdea.local(
      goal: goal.goalTitle,
      note: [
        '来源：Todo 目标价值系统',
        '目标价值：${goal.coreValues.trim().isEmpty ? goal.valueGoal : goal.coreValues}',
        '长期意义：${goal.deepMeaning}',
        if (step != null) '当前行动：${step.title}',
      ].join('\n'),
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    final action = step?.title.trim().isNotEmpty == true ? step!.title.trim() : seed.actionIdea;
    final firstBodyAction = _firstBodyAction(goal, step, seed.firstBodyAction);
    final minimumAction = step?.minimumStandard.trim().isNotEmpty == true ? step!.minimumStandard.trim() : seed.minimumAction;
    final fiveMinute = step?.simplifiedStandard.trim().isNotEmpty == true ? step!.simplifiedStandard.trim() : seed.fiveMinuteVersion;
    final obstacles = _obstacles(goal, seed.obstacleIdeas);
    final replacements = <String>[
      '先执行第一身体动作：$firstBodyAction',
      '只做最低版本：$minimumAction',
      '行动先于心情，5分钟后再决定是否继续',
    ];
    final coreValue = goal.coreValues.trim().isNotEmpty
        ? goal.coreValues.trim()
        : (goal.valueGoal.trim().isNotEmpty ? goal.valueGoal.trim() : seed.coreValue);
    return JamesWillActionIdea(
      id: ideaIdFor(goal.goalId, step?.stepId),
      originalGoal: goal.goalTitle,
      goalNote: seed.goalNote,
      coreValue: coreValue,
      actionIdea: action,
      firstBodyAction: firstBodyAction,
      minimumAction: minimumAction,
      fiveMinuteVersion: fiveMinute,
      attentionAnchor: '现在不重新审判整个目标，只让“$action”占据注意力 30 秒。',
      obstacleIdeas: obstacles,
      replacementIdeas: replacements,
      competitionItems: <JamesWillCompetitionItem>[
        JamesWillCompetitionItem(type: '行动观念', content: action, strength: 68, role: '推动此刻行动'),
        JamesWillCompetitionItem(type: '阻碍观念', content: obstacles.first, strength: 78, role: '提高启动成本'),
        if (obstacles.length > 1) JamesWillCompetitionItem(type: '逃避观念', content: obstacles[1], strength: 72, role: '把注意力移出可控域'),
        JamesWillCompetitionItem(type: '价值观念', content: coreValue, strength: 74, role: '支撑长期方向'),
      ],
      coachMessage: '目标仍由 Todo 目标价值系统管理；足下意志只负责把它压缩为当下可执行的身体动作、有限决定和真实反馈。',
      aiProvider: existing?.aiProvider ?? seed.aiProvider,
      aiModelLabel: existing?.aiModelLabel ?? seed.aiModelLabel,
      aiUsedFallback: existing?.aiUsedFallback ?? true,
      status: existing?.status ?? 'active',
      createdAtMs: existing?.createdAtMs ?? now,
      updatedAtMs: now,
    );
  }

  Future<JamesWillActionIdea> synchronize({required TodoGoalProfile goal, TodoGoalActionStep? step}) async {
    final id = ideaIdFor(goal.goalId, step?.stepId);
    final existing = await _willDao.getActionIdea(id);
    final idea = project(goal: goal, step: step, existing: existing);
    await _willDao.upsertActionIdea(idea);
    return idea;
  }

  Future<List<JamesWillLog>> logsFor({required String goalId, String? stepId, int limit = 20}) {
    return _willDao.listLogs(ideaId: ideaIdFor(goalId, stepId), limit: limit);
  }

  String _firstBodyAction(TodoGoalProfile goal, TodoGoalActionStep? step, String fallback) {
    final place = step?.actionPlace.trim() ?? '';
    final trigger = step?.startTrigger.trim() ?? '';
    if (trigger.isNotEmpty && place.isNotEmpty) return '$trigger，身体移动到$place并打开行动入口';
    if (place.isNotEmpty) return '身体移动到$place，打开行动入口';
    if (trigger.isNotEmpty) return '$trigger，立刻打开“${step?.title ?? goal.goalTitle}”的行动入口';
    return fallback;
  }

  List<String> _obstacles(TodoGoalProfile goal, List<String> fallback) {
    final text = goal.obstacleSummary.trim();
    if (text.isEmpty) return fallback;
    final values = text.split(RegExp(r'[\n，,；;、]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).take(3).toList();
    return values.isEmpty ? fallback : values;
  }
}
