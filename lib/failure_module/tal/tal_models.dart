import 'dart:convert';

/// Evidence states describe an event or an experiment, never a person's worth.
enum TalState {
  eventRecorded('EVENT_RECORDED', '已记录'),
  reflectionDraft('REFLECTION_DRAFT', '反思草稿'),
  savedUnfinished('SAVED_UNFINISHED', '暂未完成'),
  insightCandidate('INSIGHT_CANDIDATE', '待验证的认识'),
  actionPlanned('ACTION_PLANNED', '已计划，尚未执行'),
  actionAttempted('ACTION_ATTEMPTED', '已尝试，等待结果'),
  outcomeHelped('OUTCOME_HELPED', '这次有帮助'),
  outcomeUnclear('OUTCOME_UNCLEAR', '效果未知'),
  outcomeNotHelped('OUTCOME_NOT_HELPED', '这次没帮助'),
  lessonRevised('LESSON_REVISED', '认识已修订'),
  nextTrial('NEXT_TRIAL', '下一次试验'),
  paused('PAUSED', '暂时放下'),
  goalExited('GOAL_EXITED', '已选择退出目标'),
  closed('CLOSED', '已结束');

  const TalState(this.code, this.label);
  final String code, label;
  static TalState parse(Object? code) =>
      values.firstWhere((v) => v.code == code, orElse: () => eventRecorded);
}

enum TalChoice {
  undecided('还没决定'),
  continueGoal('继续'),
  adjust('调整'),
  pause('暂时放下'),
  exit('重新评估 / 退出');

  const TalChoice(this.label);
  final String label;
}

class TalTrial {
  const TalTrial(
      {required this.id,
      required this.methodId,
      required this.action,
      required this.trigger,
      required this.check,
      required this.createdMs,
      this.reason = '',
      this.previousId,
      this.evidence = const []});
  final String id, methodId, action, trigger, check, reason;
  final String? previousId;
  final int createdMs;
  final List<Map<String, dynamic>> evidence;

  TalState get state {
    if (evidence.isEmpty) return TalState.actionPlanned;
    final last = evidence.last;
    if (last['action_done'] != true) return TalState.savedUnfinished;
    return switch (last['outcome']) {
      'helped' => TalState.outcomeHelped,
      'not_helped' => TalState.outcomeNotHelped,
      'unclear' => TalState.outcomeUnclear,
      _ => TalState.actionAttempted,
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'method_id': methodId,
        'action': action,
        'trigger': trigger,
        'check': check,
        'reason': reason,
        'created_ms': createdMs,
        'previous_id': previousId,
        'evidence': evidence,
      };
  factory TalTrial.fromJson(Map<String, dynamic> m) => TalTrial(
        id: m['id'] as String,
        methodId: m['method_id'] as String,
        action: m['action'] as String,
        trigger: m['trigger'] as String,
        check: m['check'] as String,
        reason: '${m['reason'] ?? ''}',
        previousId: m['previous_id'] as String?,
        createdMs: (m['created_ms'] as num).toInt(),
        evidence: (m['evidence'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
}

class TalRecord {
  const TalRecord(
      {required this.eventId,
      required this.createdMs,
      required this.updatedMs,
      required this.source,
      this.cardId,
      this.subjectKey = '',
      this.plan = '',
      this.observed = '',
      this.confirmed = false,
      this.state = TalState.eventRecorded,
      this.reflection = const {},
      this.choice = TalChoice.undecided,
      this.trials = const [],
      this.revisions = const [],
      this.rejectedMethods = const [],
      this.reminders = const [],
      this.reminderConsent = false,
      this.aiConsent = false,
      this.quoteConsent = false,
      this.validatedByUser = false,
      this.consolidatedByUser = false});
  final int? cardId;
  final String eventId, source, subjectKey, plan, observed;
  final int createdMs, updatedMs;
  final bool confirmed, reminderConsent, aiConsent, quoteConsent;
  final bool validatedByUser, consolidatedByUser;
  final TalState state;
  final TalChoice choice;
  final Map<String, String> reflection;
  final List<TalTrial> trials;
  final List<Map<String, dynamic>> revisions, reminders;
  final List<String> rejectedMethods;

  TalTrial? get currentTrial => trials.isEmpty ? null : trials.last;
  String get lesson => reflection['lessons'] ?? '';
  bool get hasLesson =>
      lesson.trim().isNotEmpty &&
      !['还不清楚', '没有教训', '暂时没有'].contains(lesson.trim());
  String get level {
    final evidence = trials
        .expand((t) => t.evidence)
        .where((e) => e['action_done'] == true)
        .toList();
    final helped = evidence
        .where((e) =>
            e['outcome'] == 'helped' &&
            '${e['observed_outcome'] ?? ''}'.trim().isNotEmpty)
        .toList();
    // Consolidation requires explicit judgement and independent contexts/dates.
    if (validatedByUser &&
        consolidatedByUser &&
        helped.length >= 3 &&
        helped
                .map((e) => '${e['context'] ?? ''}')
                .where((s) => s.trim().isNotEmpty)
                .toSet()
                .length >=
            2 &&
        helped
                .map((e) => DateTime.fromMillisecondsSinceEpoch(
                        (e['observed_ms'] as num).toInt(),
                        isUtc: true)
                    .toIso8601String()
                    .substring(0, 10))
                .toSet()
                .length >=
            3) {
      return 'L5 巩固';
    }
    if (validatedByUser && helped.isNotEmpty) return 'L4 有效（个人观察）';
    if (evidence.isNotEmpty) return 'L3 执行';
    if (trials.isNotEmpty) return 'L2 计划';
    if (hasLesson || reflection.values.any((v) => v.trim().isNotEmpty)) {
      return 'L1 理解（尚待验证）';
    }
    return 'L0 记录';
  }

  Map<String, dynamic> toJson() => {
        'schema_version': 1,
        'event_id': eventId,
        'created_ms': createdMs,
        'updated_ms': updatedMs,
        'source': source,
        'subject_key': subjectKey,
        'plan': plan,
        'observed': observed,
        'user_confirmed': confirmed,
        'state': state.code,
        'reflection': reflection,
        'choice': choice.name,
        'trials': trials.map((e) => e.toJson()).toList(),
        'revisions': revisions,
        'rejected_methods': rejectedMethods,
        'reminders': reminders,
        'reminder_consent': reminderConsent,
        'ai_consent': aiConsent,
        'quote_consent': quoteConsent,
        'validated_by_user': validatedByUser,
        'consolidated_by_user': consolidatedByUser,
        'source_provenance': 'product_extension',
      };
  factory TalRecord.fromJson(Map<String, dynamic> m, {int? cardId}) =>
      TalRecord(
        cardId: cardId,
        eventId: m['event_id'] as String,
        createdMs: (m['created_ms'] as num).toInt(),
        updatedMs: (m['updated_ms'] as num).toInt(),
        source: m['source'] as String,
        subjectKey: '${m['subject_key'] ?? ''}',
        plan: '${m['plan'] ?? ''}',
        observed: '${m['observed'] ?? ''}',
        confirmed: m['user_confirmed'] == true,
        state: TalState.parse(m['state']),
        reflection:
            (m['reflection'] as Map? ?? {}).map((k, v) => MapEntry('$k', '$v')),
        choice: TalChoice.values.firstWhere((c) => c.name == m['choice'],
            orElse: () => TalChoice.undecided),
        trials: (m['trials'] as List? ?? [])
            .map((e) => TalTrial.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        revisions: (m['revisions'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        rejectedMethods:
            List<String>.from(m['rejected_methods'] as List? ?? []),
        reminders: (m['reminders'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        reminderConsent: m['reminder_consent'] == true,
        aiConsent: m['ai_consent'] == true,
        quoteConsent: m['quote_consent'] == true,
        validatedByUser: m['validated_by_user'] == true,
        consolidatedByUser: m['consolidated_by_user'] == true,
      );

  TalRecord withJson(Map<String, dynamic> changes) =>
      TalRecord.fromJson({...toJson(), ...changes}, cardId: cardId);
  String get exportJson => const JsonEncoder.withIndent('  ').convert(toJson());
}
