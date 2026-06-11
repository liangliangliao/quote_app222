import 'todo_goal_models.dart';
import 'todo_meaning_models.dart';

class TodoMeaningScanInput {
  const TodoMeaningScanInput({
    required this.situation,
    required this.unavoidableQuestion,
    required this.recurringResponsibility,
    required this.waitingPerson,
    required this.uniqueTask,
    required this.avoidedResponsibility,
  });

  final String situation;
  final String unavoidableQuestion;
  final String recurringResponsibility;
  final String waitingPerson;
  final String uniqueTask;
  final String avoidedResponsibility;
}

class TodoMeaningEngine {
  const TodoMeaningEngine();

  static const _crisisTerms = <String>[
    '自杀', '轻生', '不想活', '结束生命', '伤害自己', '自伤', '自残', '活不下去',
    'suicide', 'kill myself', 'self harm', 'end my life',
  ];

  bool containsCrisisSignal(String text) {
    final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return _crisisTerms.any((term) => normalized.contains(term.replaceAll(' ', '')));
  }

  TodoMeaningCompassSnapshot buildSnapshot({
    required TodoMeaningScanInput input,
    required List<TodoGoalProfile> goals,
    required List<TodoGoalActionStep> todaySteps,
    required List<TodoGoalReflection> reflections,
    int? nowMs,
  }) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final responsibilityText = '${input.unavoidableQuestion} ${input.recurringResponsibility} ${input.avoidedResponsibility}'.trim();
    final futureText = '${input.uniqueTask} ${goals.map((goal) => goal.goalTitle).join(' ')}'.trim();
    final relationalText = '${input.waitingPerson} ${input.recurringResponsibility}'.trim();
    final hardshipText = '${input.situation} ${input.unavoidableQuestion}'.trim();

    final responsibility = _score(
      responsibilityText,
      base: goals.isEmpty ? 1 : 2,
      evidence: todaySteps.where((step) => !step.isCompleted).length,
    );
    final future = _score(futureText, base: goals.where((goal) => goal.status == 'active').length, evidence: goals.length);
    final transcendence = _score(relationalText, base: 1, evidence: _otherFocusedCount(relationalText));
    final attitude = _score(hardshipText, base: reflections.isEmpty ? 1 : 2, evidence: reflections.where((item) => item.meaningScore > 0).length);
    final path = _primaryPath(input);
    final response = _nextResponse(input, path, todaySteps);

    return TodoMeaningCompassSnapshot(
      snapshotId: 'meaning_scan_$now',
      createdAtMs: now,
      situation: input.situation.trim(),
      unavoidableQuestion: input.unavoidableQuestion.trim(),
      recurringResponsibility: input.recurringResponsibility.trim(),
      waitingPerson: input.waitingPerson.trim(),
      uniqueTask: input.uniqueTask.trim(),
      avoidedResponsibility: input.avoidedResponsibility.trim(),
      primaryPath: path,
      responsibilityClarity: responsibility,
      futureAnchorStrength: future,
      selfTranscendence: transcendence,
      attitudeFreedom: attitude,
      currentMeaningQuestion: _meaningQuestion(input),
      nextResponse: response,
    );
  }

  String classifyControllability(String controllability) {
    switch (controllability) {
      case 'changeable':
        return '可改变：先解决问题，不把本可消除的痛苦浪漫化。';
      case 'unchangeable':
        return '不可改变：承认失去，同时寻找仍可选择的态度、关系与有尊严的小行动。';
      default:
        return '部分可改变：把可控部分变成行动，把不可控部分交给态度与支持系统。';
    }
  }

  int _score(String text, {required int base, required int evidence}) {
    final lengthPoints = text.trim().isEmpty ? 0 : (text.trim().length >= 18 ? 2 : 1);
    return (base + lengthPoints + (evidence > 0 ? 1 : 0)).clamp(0, 5).toInt();
  }

  int _otherFocusedCount(String text) {
    const terms = <String>['家人', '父母', '孩子', '伴侣', '朋友', '同事', '客户', '学生', '团队', '他人', '谁'];
    return terms.where(text.contains).length;
  }

  String _primaryPath(TodoMeaningScanInput input) {
    final relationship = '${input.waitingPerson} ${input.recurringResponsibility}';
    final attitude = '${input.situation} ${input.unavoidableQuestion}';
    if (relationship.trim().isNotEmpty && _otherFocusedCount(relationship) > 0) return 'relationship';
    if (RegExp(r'失去|疾病|离别|无法改变|不可改变|痛苦|失败|困境').hasMatch(attitude)) return 'attitude';
    return 'creation';
  }

  String _meaningQuestion(TodoMeaningScanInput input) {
    if (input.unavoidableQuestion.trim().isNotEmpty) return '生活此刻在问我：${input.unavoidableQuestion.trim()}';
    if (input.recurringResponsibility.trim().isNotEmpty) return '我愿意怎样回应反复出现的责任：${input.recurringResponsibility.trim()}';
    if (input.waitingPerson.trim().isNotEmpty) return '我今天可以怎样真实地回应：${input.waitingPerson.trim()}';
    return '今天，生活正在向我提出什么具体问题？';
  }

  String _nextResponse(TodoMeaningScanInput input, String path, List<TodoGoalActionStep> steps) {
    if (steps.any((step) => !step.isCompleted)) {
      final step = steps.firstWhere((step) => !step.isCompleted);
      return '先回应已有行动“${step.title}”：只做最低标准 ${step.minimumStandard.trim().isEmpty ? '2 分钟' : step.minimumStandard}。';
    }
    if (path == 'relationship' && input.waitingPerson.trim().isNotEmpty) return '为“${input.waitingPerson.trim()}”完成一次具体回应：联系、倾听、陪伴或感谢。';
    if (path == 'attitude') return '先分清可改变与不可改变；今天只做一件保护尊严、连接支持的小事。';
    final task = input.uniqueTask.trim().isNotEmpty ? input.uniqueTask.trim() : input.recurringResponsibility.trim();
    return task.isEmpty ? '选择一件值得做的事，把它缩小为 2–15 分钟可开始的动作。' : '把“$task”缩小为今天 2–15 分钟可留下证据的一步。';
  }
}
