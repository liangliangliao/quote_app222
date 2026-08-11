import '../external_data/todo_goal_dao.dart';
import '../external_data/todo_goal_models.dart';
import '../external_data/todo_models.dart';
import 'zhixing_dao.dart';
import 'zhixing_extended_models.dart';

/// Read-only bridge over the three supported goal sources. Selecting a
/// candidate copies only its public goal/next-step fields into the Zhixing
/// action form; source modules remain authoritative for their own records.
class ZxGoalSourceService {
  ZxGoalSourceService({ZxDao? zxDao, TodoGoalDao? todoGoalDao})
      : _zxDao = zxDao ?? ZxDao(),
        _todoGoalDao = todoGoalDao ?? TodoGoalDao();

  final ZxDao _zxDao;
  final TodoGoalDao _todoGoalDao;

  Future<List<ZxGoalCandidate>> load(
    ZxGoalSource source, {
    int limit = 20,
  }) async {
    switch (source) {
      case ZxGoalSource.zhixingLocal:
        return _local(limit);
      case ZxGoalSource.todoGoalValue:
        return _todoGoals(limit);
      case ZxGoalSource.microsoftTodo:
        return _microsoftTodo(limit);
    }
  }

  Future<List<ZxGoalCandidate>> _local(int limit) async {
    final goals = await _zxDao.goals();
    return goals
        .where((goal) => goal.status == 'active')
        .take(limit)
        .map(
          (goal) => ZxGoalCandidate(
            source: ZxGoalSource.zhixingLocal,
            sourceId: goal.id.toString(),
            title: goal.title,
            valueDirection: goal.valueDirection,
            updatedAtMs: goal.updatedAtMs,
          ),
        )
        .toList(growable: false);
  }

  Future<List<ZxGoalCandidate>> _todoGoals(int limit) async {
    final goals = await _todoGoalDao.listGoals(limit: limit);
    final result = <ZxGoalCandidate>[];
    for (final goal in goals.where((item) => item.status == 'active')) {
      final steps = await _todoGoalDao.listActionSteps(goal.goalId);
      final next = _firstOpenStep(steps);
      result.add(
        ZxGoalCandidate(
          source: ZxGoalSource.todoGoalValue,
          sourceId: goal.goalId,
          title: goal.goalTitle,
          valueDirection: _firstNonEmpty(<String>[
            goal.valueGoal,
            goal.coreValues,
            goal.deepMeaning,
            goal.processValue,
          ]),
          nextStep: next == null
              ? _firstNonEmpty(<String>[goal.processGoal, goal.resultGoal])
              : _firstNonEmpty(<String>[
                  next.minimumStandard,
                  next.title,
                  next.simplifiedStandard,
                ]),
          dueLabel: next == null
              ? ''
              : <String>[next.plannedDate, next.plannedTime]
                  .where((item) => item.trim().isNotEmpty)
                  .join(' '),
          updatedAtMs: goal.updatedAtMs,
        ),
      );
    }
    return result.take(limit).toList(growable: false);
  }

  Future<List<ZxGoalCandidate>> _microsoftTodo(int limit) async {
    final tasks = await _todoGoalDao.listCandidateTasks(limit: limit);
    return tasks
        .where((task) => !task.isCompleted)
        .map(_mapTask)
        .toList(growable: false);
  }

  ZxGoalCandidate _mapTask(TodoTaskRecord task) => ZxGoalCandidate(
        source: ZxGoalSource.microsoftTodo,
        sourceId: task.taskId,
        title: task.title,
        valueDirection: task.listDisplayName.trim().isEmpty
            ? '来自 Microsoft To Do'
            : '来自 Microsoft To Do · ' + task.listDisplayName.trim(),
        nextStep: task.bodyText.trim(),
        dueLabel: _firstNonEmpty(<String>[
          task.dueDateTime,
          task.reminderDateTime,
          task.startDateTime,
        ]),
        updatedAtMs:
            DateTime.tryParse(task.lastModifiedDateTime)?.millisecondsSinceEpoch ??
                task.syncedAtMs,
      );

  TodoGoalActionStep? _firstOpenStep(List<TodoGoalActionStep> steps) {
    for (final step in steps) {
      if (!step.isCompleted) return step;
    }
    return null;
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }
}
