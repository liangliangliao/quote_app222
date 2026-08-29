import 'will_mirror_models.dart';
import 'will_mirror_practice_engine.dart';
import 'will_mirror_practice_models.dart';
import 'will_mirror_vault.dart';

class WillMirrorCheckInResult {
  const WillMirrorCheckInResult({
    required this.plan,
    required this.completedExperiment,
  });

  final WillMirrorActionPlan plan;
  final bool completedExperiment;
}

class WillMirrorPracticeCoordinator {
  WillMirrorPracticeCoordinator({
    required WillMirrorVault vault,
    WillMirrorPracticeEngine? engine,
  })  : _vault = vault,
        _engine = engine ?? const WillMirrorPracticeEngine();

  final WillMirrorVault _vault;
  final WillMirrorPracticeEngine _engine;

  Future<WillMirrorActionPlan> start({
    required WillMirrorNeedType needType,
    required String need,
    required String desiredOutcome,
    required String obstacle,
    required WillMirrorPracticeProfile profile,
    required WillMirrorActionRoute route,
    WillMirrorIntelligenceReceipt? intelligenceReceipt,
  }) async {
    final cleanNeed = need.trim();
    if (cleanNeed.isEmpty) throw ArgumentError.value(need, 'need', '不能为空');
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final goalId = WillMirrorIds.next('goal');
    final hypothesisId = WillMirrorIds.next('hyp');
    final experimentId = WillMirrorIds.next('exp');
    final planId = WillMirrorIds.next('plan');

    final goal = WillMirrorGoal(
      id: goalId,
      text: cleanNeed,
      domain: profile.interest.label,
      baselineDesire: 0,
      status: 'active',
      createdAt: nowMs,
      updatedAt: nowMs,
      intelligenceReceipt: intelligenceReceipt,
    );
    await _vault.saveGoal(goal);

    final outcomeText = desiredOutcome.trim();
    if (outcomeText.isNotEmpty) {
      await _vault.saveWhyNode(
        WillMirrorWhyNode(
          id: WillMirrorIds.next('why'),
          goalId: goalId,
          parentId: null,
          nodeType: 'desired_outcome',
          text: outcomeText,
          depth: 0,
          createdAt: nowMs,
        ),
      );
    }
    final obstacleText = obstacle.trim();
    if (obstacleText.isNotEmpty) {
      await _vault.saveWhyNode(
        WillMirrorWhyNode(
          id: WillMirrorIds.next('why'),
          goalId: goalId,
          parentId: null,
          nodeType: 'observed_obstacle',
          text: obstacleText,
          depth: 0,
          createdAt: nowMs + 1,
        ),
      );
    }

    final hypothesis = WillMirrorHypothesis(
      id: hypothesisId,
      goalId: goalId,
      label: _engine.candidateLabel(needType: needType, need: cleanNeed),
      type: WillMirrorHypothesisType.motive,
      status: 'candidate',
      confidenceBand: WillMirrorConfidenceBand.insufficient,
      explanation: '先通过低风险行动观察是否愿意持续，以及哪些能力、责任和环境条件影响行动。',
      counterSearchCompleted: false,
      counterSearchNote: '',
      createdAt: nowMs,
      updatedAt: nowMs,
    );
    await _vault.saveHypothesis(hypothesis);

    final experiment = WillMirrorExperiment(
      id: experimentId,
      hypothesisId: hypothesisId,
      title: '七日实践：${_short(cleanNeed, 26)}',
      protocol: <String>[
        '每日动作：${route.action}',
        '完成信号：${route.successSignal}',
        '为什么：${route.whyItWorks}',
        '没做成也只记录阻碍，不把它解释成没有欲望。',
      ].join('\n'),
      startAt: nowMs,
      endAt: now.add(const Duration(days: 7)).millisecondsSinceEpoch,
      status: WillMirrorExperimentStatus.active,
      createdAt: nowMs,
    );
    await _vault.saveExperiment(experiment);

    final plan = WillMirrorActionPlan(
      id: planId,
      goalId: goalId,
      hypothesisId: hypothesisId,
      experimentId: experimentId,
      needType: needType,
      need: cleanNeed,
      desiredOutcome: outcomeText,
      obstacle: obstacleText,
      profile: profile,
      route: route,
      status: 'active',
      checkInCount: 0,
      completedCount: 0,
      createdAt: nowMs,
      updatedAt: nowMs,
    );
    await _vault.savePracticeProfile(profile);
    await _vault.saveActionPlan(plan);
    return plan;
  }

  Future<WillMirrorCheckInResult> checkIn({
    required WillMirrorActionPlan plan,
    required bool didAct,
    required int energy,
    required int realMe,
    required int persistence,
    required int satisfaction,
    required String note,
    DateTime? nowOverride,
  }) async {
    final nowDate = nowOverride ?? DateTime.now();
    final previousObservations = await _vault.observations(plan.experimentId);
    if (previousObservations.any(
      (item) => _sameLocalDay(
        DateTime.fromMillisecondsSinceEpoch(item.observedAt),
        nowDate,
      ),
    )) {
      throw StateError('今天已经记录过现实反馈；明天再继续，或到实验明细查看今天的记录。');
    }
    final now = nowDate.millisecondsSinceEpoch;
    final safeEnergy = energy.clamp(0, 10).toInt();
    final safeRealMe = realMe.clamp(0, 10).toInt();
    final safePersistence = persistence.clamp(0, 10).toInt();
    final safeSatisfaction = satisfaction.clamp(0, 10).toInt();
    final cleanNote = note.trim();
    await _vault.saveObservation(
      WillMirrorObservation(
        id: WillMirrorIds.next('obs'),
        experimentId: plan.experimentId,
        energy: safeEnergy,
        realMe: safeRealMe,
        persistence: safePersistence,
        satisfaction: safeSatisfaction,
        note: cleanNote.isEmpty
            ? didAct
                ? '完成了今天的小行动。'
                : '今天没有完成；保留为阻碍信息，不解释为没有欲望。'
            : cleanNote,
        observedAt: now,
      ),
    );

    if (didAct) {
      await _vault.saveEvidence(
        WillMirrorLifeEvidence(
          id: WillMirrorIds.next('evidence'),
          goalId: plan.goalId,
          type: WillMirrorEvidenceType.action,
          title: _short(plan.route.action, 46),
          note: cleanNote,
          lifeStage: '当前七日实践',
          domain: plan.profile.interest.label,
          intensity: 5,
          duration:
              (plan.profile.energyMinutes / 2).ceil().clamp(1, 10).toInt(),
          costLevel: 1,
          audiencePresent: false,
          externallyRequested: false,
          rewardPresent: false,
          energyBefore: 5,
          energyAfter: safeEnergy,
          repeatWish: safeRealMe,
          occurredAt: now,
          createdAt: now,
        ),
      );
    }

    final checkIns = previousObservations.length + 1;
    final completed = plan.completedCount + (didAct ? 1 : 0);
    final experimentDone = checkIns >= 7;
    final revisedRoute = didAct ? plan.route : _smallerNextStep(plan, cleanNote);
    final revisionNote = didAct
        ? '这次行动只算一条支持证据。下一次保持 ${plan.route.minutes} 分钟，不加码，用重复发生来检验是否适合。'
        : cleanNote.isEmpty
            ? '没有把未完成判成失败。下一步已缩为 2 分钟准备动作，用来查清真实阻碍。'
            : '已把“${_short(cleanNote, 32)}”保留为现实限制，并把下一步缩为 2 分钟准备动作。';
    final updated = plan.copyWith(
      status: experimentDone ? 'completed' : 'active',
      checkInCount: checkIns,
      completedCount: completed,
      updatedAt: now,
      lastCheckInAt: now,
      route: revisedRoute,
      revisionNote: revisionNote,
    );
    await _vault.saveActionPlan(updated);
    if (experimentDone) {
      final experiments = await _vault.experiments(
        hypothesisId: plan.hypothesisId,
      );
      for (final experiment in experiments) {
        if (experiment.id == plan.experimentId) {
          await _vault.saveExperiment(
            experiment.copyWith(status: WillMirrorExperimentStatus.completed),
          );
          break;
        }
      }
    }
    return WillMirrorCheckInResult(
      plan: updated,
      completedExperiment: experimentDone,
    );
  }

  static String _short(String value, int max) {
    if (value.length <= max) return value;
    return '${value.substring(0, max)}…';
  }

  static bool _sameLocalDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static WillMirrorActionRoute _smallerNextStep(
    WillMirrorActionPlan plan,
    String obstacle,
  ) {
    final condition = obstacle.isEmpty ? '今天出现的现实阻碍' : _short(obstacle, 36);
    final next = _recoveryAction(condition);
    return plan.route.copyWith(
      title: next.$1,
      promise: '针对真实阻碍调整，不要求补做原任务',
      action: next.$2,
      successSignal: next.$3,
      whyItWorks: '没行动不能自动解释为没有欲望；先降低能力、责任、资源或环境阻力，再用下一次真实选择检验。',
      output: '一个更容易开始的入口 + 一条现实限制记录',
      minutes: 2,
      theoryIds: const <String>[
        'SCH-B4-055-ACTION-CHARACTER',
        'SCH-B4-053-DESCRIPTION-NORM',
        'TAL-L13-SEVEN-DAY-STRENGTH',
      ],
      theoryApplications: <WillMirrorTheoryApplication>[
        WillMirrorTheoryApplication(
          theoryId: 'SCH-B4-055-ACTION-CHARACTER',
          concept: '叔本华 §55 · 行动检验',
          application: '没有把“$condition”解释成人格缺陷，而是改变条件后再观察下一次真实选择。',
          reason: '没行动同时可能受能力、责任、资源和环境影响，必须先减少混淆变量。',
        ),
        const WillMirrorTheoryApplication(
          theoryId: 'SCH-B4-053-DESCRIPTION-NORM',
          concept: '叔本华 §53 · 描述与规范分离',
          application: '记录今天发生了什么，不把事实升级成“你应该怎样”的道德评判。',
          reason: '描述事实能保留学习价值，羞耻和惩罚只会制造新的干扰。',
        ),
      ],
    );
  }

  static (String, String, String) _recoveryAction(String condition) {
    if (_contains(condition, <String>['时间', '没精力', '太累', '加班', '照顾', '责任'])) {
      return (
        '为现实责任留出一个入口',
        '承认“$condition”是现实条件。用 2 分钟在日历里找一个真实可用窗口；如果今天没有窗口，就明确暂停到可用日期。',
        '留下一个可执行时间窗，或一条明确的暂停条件。',
      );
    }
    if (_contains(condition, <String>['不知道', '不清楚', '不会', '步骤', '第一步'])) {
      return (
        '先把未知变成一个问题',
        '把“$condition”归到“缺决定、缺信息、缺动作”中的一类，用 2 分钟只写下一个可搜索的问题或第一个物理动作。',
        '出现一个能直接查询的问题，或一个可立即执行的动作。',
      );
    }
    if (_contains(condition, <String>['怕', '完美', '失败', '比较', '评价'])) {
      return (
        '先做一个不会公开的第 0 版',
        '把“$condition”当作评价压力。用 2 分钟做一个明确不会发布、允许删除的粗糙痕迹，到点停止。',
        '留下一个不需要被评价的粗糙痕迹。',
      );
    }
    if (_contains(condition, <String>['工具', '设备', '材料', '钱', '资源'])) {
      return (
        '补齐或替代唯一前提',
        '从“$condition”中圈出唯一缺少的资源，用 2 分钟找到一个借用、替代或低成本验证方式。',
        '得到一个可获得的资源入口或可行替代方案。',
      );
    }
    if (_contains(condition, <String>['不想', '不重要', '目标变了', '放弃', '暂停'])) {
      return (
        '先决定继续、换路还是停止',
        '不强迫继续。用 2 分钟写下：继续这件事、换一个目标、暂时停止，各自会带来什么现实后果；只做一个选择。',
        '明确选择继续、换路或停止，并写下一句理由。',
      );
    }
    return (
      '先降低下一次开始的阻力',
      '把“$condition”当作待检验条件。用 2 分钟只打开材料、写下第一步或移除一个阻碍；到点就停。',
      '留下一个能降低下次开始难度的准备痕迹。',
    );
  }

  static bool _contains(String value, List<String> words) =>
      words.any(value.contains);
}
