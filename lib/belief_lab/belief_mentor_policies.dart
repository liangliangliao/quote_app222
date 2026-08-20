import 'belief_mentor_models.dart';

class BeliefMentorTransitionPolicy {
  const BeliefMentorTransitionPolicy._();

  static const Map<BeliefMentorBeliefState, Set<BeliefMentorBeliefState>>
  allowed = <BeliefMentorBeliefState, Set<BeliefMentorBeliefState>>{
    BeliefMentorBeliefState.discovered: <BeliefMentorBeliefState>{
      BeliefMentorBeliefState.activeLimiting,
      BeliefMentorBeliefState.userRejected,
      BeliefMentorBeliefState.needsRealityCheck,
    },
    BeliefMentorBeliefState.activeLimiting: <BeliefMentorBeliefState>{
      BeliefMentorBeliefState.alternativeFormed,
      BeliefMentorBeliefState.userRejected,
      BeliefMentorBeliefState.archived,
      BeliefMentorBeliefState.needsRealityCheck,
    },
    BeliefMentorBeliefState.alternativeFormed: <BeliefMentorBeliefState>{
      BeliefMentorBeliefState.testing,
      BeliefMentorBeliefState.archived,
      BeliefMentorBeliefState.needsRealityCheck,
    },
    BeliefMentorBeliefState.testing: <BeliefMentorBeliefState>{
      BeliefMentorBeliefState.evidenceAccumulating,
      BeliefMentorBeliefState.activeLimiting,
      BeliefMentorBeliefState.needsRealityCheck,
      BeliefMentorBeliefState.archived,
    },
    BeliefMentorBeliefState.evidenceAccumulating: <BeliefMentorBeliefState>{
      BeliefMentorBeliefState.shifting,
      BeliefMentorBeliefState.testing,
      BeliefMentorBeliefState.needsRealityCheck,
      BeliefMentorBeliefState.archived,
    },
    BeliefMentorBeliefState.shifting: <BeliefMentorBeliefState>{
      BeliefMentorBeliefState.internalized,
      BeliefMentorBeliefState.evidenceAccumulating,
      BeliefMentorBeliefState.needsRealityCheck,
      BeliefMentorBeliefState.archived,
    },
    BeliefMentorBeliefState.internalized: <BeliefMentorBeliefState>{
      BeliefMentorBeliefState.evidenceAccumulating,
      BeliefMentorBeliefState.archived,
    },
    BeliefMentorBeliefState.userRejected: <BeliefMentorBeliefState>{
      BeliefMentorBeliefState.archived,
    },
    BeliefMentorBeliefState.archived: <BeliefMentorBeliefState>{},
    BeliefMentorBeliefState.needsRealityCheck: <BeliefMentorBeliefState>{
      BeliefMentorBeliefState.activeLimiting,
      BeliefMentorBeliefState.testing,
      BeliefMentorBeliefState.archived,
    },
  };

  static bool canTransition(
    BeliefMentorBeliefState from,
    BeliefMentorBeliefState to,
  ) => allowed[from]?.contains(to) ?? false;

  /// Calculates the next evidence-based state. LLM output is intentionally not
  /// an input: the transition depends on confirmation, persisted behavior,
  /// elapsed time, evidence count and the user's own strength score.
  static BeliefMentorBeliefState suggestedState({
    required BeliefMentorBelief belief,
    required int completedExperiments,
    required int evidenceCount,
    required int distinctEvidenceDays,
    required DateTime now,
  }) {
    if (!belief.userConfirmed) return BeliefMentorBeliefState.discovered;
    if (belief.alternativeStatement.trim().isEmpty) {
      return BeliefMentorBeliefState.activeLimiting;
    }
    if (completedExperiments == 0) {
      return BeliefMentorBeliefState.alternativeFormed;
    }
    if (evidenceCount == 0) return BeliefMentorBeliefState.testing;
    final scoreDrop = belief.initialStrength - belief.strength;
    // Check the strongest state first: its thresholds are a strict superset of
    // `shifting`, so the reverse order would make it unreachable.
    if (evidenceCount >= 10 &&
        distinctEvidenceDays >= 8 &&
        scoreDrop >= 30 &&
        belief.testingStartedAtMs > 0 &&
        now
                .difference(
                  DateTime.fromMillisecondsSinceEpoch(
                    belief.testingStartedAtMs,
                  ),
                )
                .inDays >=
            21) {
      // Never jump over the explicit `shifting` state. A later user action,
      // score update or evidence capture can then complete the transition.
      return belief.state == BeliefMentorBeliefState.shifting ||
              belief.state == BeliefMentorBeliefState.internalized
          ? BeliefMentorBeliefState.internalized
          : BeliefMentorBeliefState.shifting;
    }
    if (evidenceCount >= 5 &&
        distinctEvidenceDays >= 4 &&
        scoreDrop >= 20 &&
        belief.testingStartedAtMs > 0 &&
        now
                .difference(
                  DateTime.fromMillisecondsSinceEpoch(
                    belief.testingStartedAtMs,
                  ),
                )
                .inDays >=
            7) {
      return BeliefMentorBeliefState.shifting;
    }
    return BeliefMentorBeliefState.evidenceAccumulating;
  }
}

class BeliefMentorExperimentPolicy {
  const BeliefMentorExperimentPolicy._();

  static List<String> validate(BeliefMentorExperimentDraft draft) {
    final errors = <String>[];
    if (draft.action.trim().isEmpty) errors.add('行动不能为空');
    if (draft.minimumVersion.trim().isEmpty) errors.add('必须提供最小版本');
    if (draft.fallbackAction.trim().isEmpty) errors.add('必须提供备用动作');
    if (draft.difficulty < 1 || draft.difficulty > 10) errors.add('难度必须在 1–10');
    if (draft.completionProbability < 0 || draft.completionProbability > 100) {
      errors.add('完成概率必须在 0–100%');
    }
    return errors;
  }

  static bool shouldShrink(int completionProbability) =>
      completionProbability < 50;
}

class BeliefMentorExperimentTransitionPolicy {
  const BeliefMentorExperimentTransitionPolicy._();

  static const Map<
    BeliefMentorExperimentState,
    Set<BeliefMentorExperimentState>
  >
  allowed = <BeliefMentorExperimentState, Set<BeliefMentorExperimentState>>{
    BeliefMentorExperimentState.draft: <BeliefMentorExperimentState>{
      BeliefMentorExperimentState.scheduled,
      BeliefMentorExperimentState.resized,
      BeliefMentorExperimentState.rescheduled,
      BeliefMentorExperimentState.abandoned,
    },
    BeliefMentorExperimentState.scheduled: <BeliefMentorExperimentState>{
      BeliefMentorExperimentState.started,
      BeliefMentorExperimentState.resized,
      BeliefMentorExperimentState.rescheduled,
      BeliefMentorExperimentState.abandoned,
    },
    BeliefMentorExperimentState.resized: <BeliefMentorExperimentState>{
      BeliefMentorExperimentState.started,
      BeliefMentorExperimentState.rescheduled,
      BeliefMentorExperimentState.abandoned,
    },
    BeliefMentorExperimentState.rescheduled: <BeliefMentorExperimentState>{
      BeliefMentorExperimentState.started,
      BeliefMentorExperimentState.resized,
      BeliefMentorExperimentState.abandoned,
    },
    BeliefMentorExperimentState.started: <BeliefMentorExperimentState>{
      BeliefMentorExperimentState.completed,
      BeliefMentorExperimentState.resized,
      BeliefMentorExperimentState.rescheduled,
      BeliefMentorExperimentState.abandoned,
    },
    BeliefMentorExperimentState.completed: <BeliefMentorExperimentState>{
      BeliefMentorExperimentState.reflection,
      BeliefMentorExperimentState.evidenceCreated,
    },
    BeliefMentorExperimentState.reflection: <BeliefMentorExperimentState>{
      BeliefMentorExperimentState.evidenceCreated,
    },
    BeliefMentorExperimentState.abandoned: <BeliefMentorExperimentState>{
      BeliefMentorExperimentState.resized,
      BeliefMentorExperimentState.rescheduled,
    },
    BeliefMentorExperimentState.evidenceCreated:
        <BeliefMentorExperimentState>{},
  };

  static bool canTransition(
    BeliefMentorExperimentState from,
    BeliefMentorExperimentState to,
  ) => allowed[from]?.contains(to) ?? false;
}

/// Deterministic evidence de-duplication used by state transitions.
///
/// Very similar evidence still contributes a small amount, but repeated copies
/// cannot rapidly advance a belief through the state machine.
class BeliefMentorEvidencePolicy {
  const BeliefMentorEvidencePolicy._();

  static int effectiveCount(List<BeliefMentorEvidence> evidence) {
    final accepted = <String>[];
    var weight = 0.0;
    for (final item in evidence.reversed) {
      final fingerprint = _normalize(
        '${item.action} ${item.outcome} ${item.statement}',
      );
      if (fingerprint.isEmpty) continue;
      final similarity = accepted.isEmpty
          ? 0.0
          : accepted
                .map((value) => textSimilarity(value, fingerprint))
                .reduce((a, b) => a > b ? a : b);
      weight += similarity >= 0.72 ? 0.25 : 1;
      accepted.add(fingerprint);
    }
    return weight.floor();
  }

  static double textSimilarity(String left, String right) {
    final a = _grams(_normalize(left));
    final b = _grams(_normalize(right));
    if (a.isEmpty || b.isEmpty) return 0;
    final intersection = a.intersection(b).length;
    final union = a.union(b).length;
    return union == 0 ? 0 : intersection / union;
  }

  static Set<String> _grams(String value) {
    if (value.length <= 2) return value.isEmpty ? <String>{} : <String>{value};
    return <String>{
      for (var index = 0; index < value.length - 1; index++)
        value.substring(index, index + 2),
    };
  }

  static String _normalize(String value) => value.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]+', unicode: true),
    '',
  );
}

class BeliefMentorCognitivePatternPolicy {
  const BeliefMentorCognitivePatternPolicy._();

  static final Map<BeliefMentorCognitivePattern, RegExp> _signals =
      <BeliefMentorCognitivePattern, RegExp>{
        BeliefMentorCognitivePattern.magnification: RegExp(
          r'一定会|肯定会|彻底|完蛋|灾难|毁掉|永远不会|毫无希望|最糟',
          caseSensitive: false,
        ),
        BeliefMentorCognitivePattern.minimization: RegExp(
          r'不算什么|没什么了不起|只是运气|谁都能|这不重要|微不足道',
          caseSensitive: false,
        ),
        BeliefMentorCognitivePattern.unsupportedInference: RegExp(
          r'他们都|别人一定|肯定觉得|一定认为|没人会|所有人都|他就是想',
          caseSensitive: false,
        ),
        BeliefMentorCognitivePattern.allOrNothing: RegExp(
          r'要么.*要么|不是.*就是|必须完美|只要失败|一次都不能',
          caseSensitive: false,
        ),
        BeliefMentorCognitivePattern.identityOvergeneralization: RegExp(
          r'我就是.*的人|说明我不行|我永远是|我天生|我根本没有',
          caseSensitive: false,
        ),
        BeliefMentorCognitivePattern.emotionalReasoning: RegExp(
          r'我感觉.*所以|既然我害怕|因为我焦虑|感觉不对.*一定',
          caseSensitive: false,
        ),
      };

  static List<BeliefMentorCognitivePattern> detect(String text) => _signals
      .entries
      .where((entry) => entry.value.hasMatch(text))
      .map((entry) => entry.key)
      .toList(growable: false);
}

class BeliefMentorReminderEligibility {
  const BeliefMentorReminderEligibility({
    required this.allowed,
    required this.reason,
  });

  final bool allowed;
  final String reason;
}

class BeliefMentorReminderPolicy {
  const BeliefMentorReminderPolicy._();

  static const int psychologicalDailyLimit = 2;
  static const int criticalDailyLimit = 1;

  static BeliefMentorReminderEligibility evaluate({
    required BeliefMentorReminderType type,
    required DateTime scheduledAt,
    required String quietStart,
    required String quietEnd,
    required bool remindersEnabled,
    required bool paused,
    required bool needsSpace,
    required bool experimentCompleted,
    required int sameTypeIgnoredCount,
    required int psychologicalCountToday,
    required int criticalCountToday,
    required bool alreadyDelivered,
    required bool anotherInterventionWithin60Minutes,
  }) {
    if (!remindersEnabled) {
      return const BeliefMentorReminderEligibility(
        allowed: false,
        reason: '用户未开启提醒',
      );
    }
    if (paused) {
      return const BeliefMentorReminderEligibility(
        allowed: false,
        reason: '用户已暂停主动提醒',
      );
    }
    if (alreadyDelivered) {
      return const BeliefMentorReminderEligibility(
        allowed: false,
        reason: '同一提醒已发送',
      );
    }
    if (experimentCompleted && type == BeliefMentorReminderType.antiAvoidance) {
      return const BeliefMentorReminderEligibility(
        allowed: false,
        reason: '实验已完成',
      );
    }
    if (sameTypeIgnoredCount >= 3) {
      return const BeliefMentorReminderEligibility(
        allowed: false,
        reason: '连续忽略三次，等待用户重新选择偏好',
      );
    }
    if (needsSpace && type != BeliefMentorReminderType.failureRecovery) {
      return const BeliefMentorReminderEligibility(
        allowed: false,
        reason: '用户当前需要空间',
      );
    }
    if (_insideQuietHours(scheduledAt, quietStart, quietEnd)) {
      return const BeliefMentorReminderEligibility(
        allowed: false,
        reason: '安静时段',
      );
    }
    if (anotherInterventionWithin60Minutes) {
      return const BeliefMentorReminderEligibility(
        allowed: false,
        reason: '60 分钟内已有心理干预提醒',
      );
    }
    if (type.isCritical) {
      if (criticalCountToday >= criticalDailyLimit) {
        return const BeliefMentorReminderEligibility(
          allowed: false,
          reason: '关键行动提醒预算已用完',
        );
      }
    } else if (psychologicalCountToday >= psychologicalDailyLimit) {
      return const BeliefMentorReminderEligibility(
        allowed: false,
        reason: '今日心理干预预算已用完',
      );
    }
    return const BeliefMentorReminderEligibility(
      allowed: true,
      reason: '符合发送条件',
    );
  }

  static DateTime moveOutsideQuietHours(
    DateTime selected, {
    required String quietStart,
    required String quietEnd,
  }) {
    if (!_insideQuietHours(selected, quietStart, quietEnd)) return selected;
    final end = _minutes(quietEnd);
    var candidate = DateTime(
      selected.year,
      selected.month,
      selected.day,
      end ~/ 60,
      end % 60,
    );
    final start = _minutes(quietStart);
    if (start > end && selected.hour * 60 + selected.minute >= start) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  static String deliveryKey(BeliefMentorReminder reminder) =>
      '${reminder.experimentId}:${reminder.type.name}:${reminder.scheduledAtMs}';

  static bool _insideQuietHours(
    DateTime time,
    String quietStart,
    String quietEnd,
  ) {
    final minute = time.hour * 60 + time.minute;
    final start = _minutes(quietStart);
    final end = _minutes(quietEnd);
    return start <= end
        ? minute >= start && minute < end
        : minute >= start || minute < end;
  }

  static int _minutes(String value) {
    final parts = value.trim().split(':');
    final hour = int.tryParse(parts.isEmpty ? '' : parts.first) ?? 22;
    final minute = int.tryParse(parts.length < 2 ? '' : parts[1]) ?? 0;
    return hour.clamp(0, 23).toInt() * 60 + minute.clamp(0, 59).toInt();
  }
}

class BeliefMentorSafetyDecision {
  const BeliefMentorSafetyDecision({
    required this.riskLevel,
    required this.blocksNormalFlow,
    required this.message,
    this.category = 'none',
  });

  final String riskLevel;
  final bool blocksNormalFlow;
  final String message;
  final String category;
}

class BeliefMentorSafetyPolicy {
  const BeliefMentorSafetyPolicy._();

  static final RegExp _selfHarm = RegExp(
    r'自杀|轻生|不想活|活不下去|结束生命|伤害自己|伤害我自己|自残|割腕|跳楼|吞药|kill myself|end my life|suicid',
    caseSensitive: false,
  );
  static final RegExp _dangerous = RegExp(
    r'杀人|杀了他|杀了她|报复.*伤害|制造.*炸弹|做炸弹|纵火|抢劫|绑架|投毒|违法行动',
    caseSensitive: false,
  );
  static final RegExp _psychosis = RegExp(
    r'有人控制我的思想|读取我的思想|植入.*芯片|全世界都在监视我|有人跟踪我.*证据|神命令我|声音命令我|我无所不能',
    caseSensitive: false,
  );
  static final RegExp _acuteMania = RegExp(
    r'几天不睡.*不累|不需要睡觉|我是神|无所不能.*不用睡|倾家荡产.*投资',
    caseSensitive: false,
  );

  static BeliefMentorSafetyDecision assess(String text) {
    if (_selfHarm.hasMatch(text)) {
      return const BeliefMentorSafetyDecision(
        riskLevel: 'high',
        blocksNormalFlow: true,
        message: '你现在的安全比任何信念训练更重要。请立即联系当地紧急服务、危机热线，或一位能陪在你身边的可信任的人。',
        category: 'self_harm',
      );
    }
    if (_dangerous.hasMatch(text)) {
      return const BeliefMentorSafetyDecision(
        riskLevel: 'high',
        blocksNormalFlow: true,
        message: '我不能帮助设计危险或违法行动。我们可以先把目标改写为保护安全、远离冲突并寻求合适支持。',
        category: 'violence_or_illegal',
      );
    }
    if (_psychosis.hasMatch(text)) {
      return const BeliefMentorSafetyDecision(
        riskLevel: 'high',
        blocksNormalFlow: true,
        message: '我不会把这个判断确认成事实。先回到当下可核验的信息，并考虑联系心理健康专业人员或可信任的人一起评估。',
        category: 'reality_testing',
      );
    }
    if (_acuteMania.hasMatch(text)) {
      return const BeliefMentorSafetyDecision(
        riskLevel: 'high',
        blocksNormalFlow: true,
        message: '先暂停重大决定并优先休息与安全。请尽快联系可信任的人和心理健康专业人员，一起评估当前状态。',
        category: 'acute_mania',
      );
    }
    return const BeliefMentorSafetyDecision(
      riskLevel: 'normal',
      blocksNormalFlow: false,
      message: '',
    );
  }
}
