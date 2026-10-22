import 'dart:convert';
import 'self_os_models.dart';
import 'self_os_learning.dart';
import 'self_os_v37_rules.dart';
import 'self_os_engine.dart';

class OsNextStep {
  const OsNextStep(this.kind, this.title, this.reason,
      {this.workspace,
      this.engine,
      this.gapId = '',
      this.interventionId = '',
      this.analysisTask});
  final String kind, title, reason, gapId, interventionId;
  final String? analysisTask;
  final int? workspace;
  final SelfOsEngine? engine;
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'title': title,
        'reason': reason,
        'gapId': gapId,
        'interventionId': interventionId,
        if (analysisTask != null) 'analysisTask': analysisTask,
        if (engine != null) 'engine': engine!.name,
        if (workspace != null) 'workspace': workspace,
      };
}

/// The same ordering drives home, guidance and AI context. A single useful next
/// step is selected from stored evidence; no life-domain keywords or diagnosis.
class SelfOsProgress {
  static String conflictFingerprint(SelfOsCase c) {
    final motives = c.motives.where((m) => m.selected).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return jsonEncode({
      'round': c.round,
      'motives': motives.map((m) => m.toJson()).toList(),
      'mutuallyExclusive': c.v37.flag('mutuallyExclusive'),
    });
  }

  static bool conflictNeedsReview(SelfOsCase c) =>
      c.v37.text('reviewedConflict') != conflictFingerprint(c);

  static String? actionBlocker(SelfOsCase c, {DateTime? at}) {
    if (c.v37.flag('requiresReconsideration') ||
        (c.text('newInformation').isNotEmpty &&
            !c.v37.flag('newInformationReviewed'))) {
      return '先回应重要新信息，更新认识后再确认行动约定。';
    }
    // Scope belongs to the frozen agreement, never to mutable AI settings.
    // Legacy agreements without an explicit experiment scope use the full gate.
    if (c.commitment != null &&
        c.commitment!['commitmentScope'] != 'experiment') {
      final gate = SelfOsV37Rules.gate(c.v37, at: at);
      if (!gate.mayCommit) return '${gate.label}：${gate.reasons.first}';
    }
    return null;
  }

  static OsNextStep next(SelfOsCase c, {DateTime? at}) {
    final now = at ?? DateTime.now(), s = c.v37;
    if (s.flag('requiresReconsideration') ||
        (c.text('newInformation').isNotEmpty &&
            !s.flag('newInformationReviewed'))) {
      return const OsNextStep('reconsider', '先回应新情况', '现实条件已改变，原来的行动约定需要重新审视。',
          workspace: 1);
    }
    if (c.retrospective && !c.reviewed || c.guide.phase == 'review') {
      return const OsNextStep('review', '记下实际发生的事', '完成、部分完成或没有行动，都从真实情境开始。');
    }
    final review = c.reviews.where((r) => r.round == c.round).firstOrNull;
    if (review != null &&
        !SelfOsLearning.calibrated(review) &&
        osMap(review.snapshot['experiment']).isNotEmpty) {
      return const OsNextStep(
          'calibrate', '把这次发现带回原问题', '对照事前预期，确认它支持、修正了什么，以及只能用于什么情境。');
    }
    if (s.nodes.any((n) => n.relevant && n.flag('calibrationNeedsReview'))) {
      return const OsNextStep(
          'verify', '先修订没有得到支持的推断', '实际反馈已改变判断依据，相关未来路径也需要复核。',
          workspace: 1);
    }
    if (s.cognitionOpen) {
      return const OsNextStep(
          'reentry', '新认识怎样改变了你的选择？', '校准受影响的动机，或明确记录为什么暂不改变决定。',
          workspace: 1);
    }
    if (c.committedAt != null && !c.reviewed) {
      final blocker = actionBlocker(c, at: now);
      if (blocker != null) {
        return OsNextStep('assess', '行动前重新核对依据', blocker, workspace: 1);
      }
    }
    final due = s.interventions
        .where((i) =>
            !i.completed &&
            i.dueAt(s.futureMoment, now) != null &&
            !i.dueAt(s.futureMoment, now)!.isAfter(now))
        .toList()
      ..sort((a, b) => a
          .dueAt(s.futureMoment, now)!
          .compareTo(b.dueAt(s.futureMoment, now)!));
    if (due.isNotEmpty &&
        !c.reviewed &&
        (s.futureMoment?.isBefore(now) == false ||
            due.first.text('window') == 'onsite')) {
      return OsNextStep('prepare', '到了约定的准备时间', due.first.text('task'),
          workspace: 3,
          gapId: due.first.text('gapId'),
          interventionId: due.first.id);
    }
    if (!c.reviewed &&
        s.futureMoment?.isAfter(now) == true &&
        s.interventions.where((i) => !i.completed).isEmpty &&
        ((c.temporalGap ?? 0) >= 25 ||
            SelfOsV37Rules.attentionBreaks(
                    c.motives.map((m) => m.toJson()).toList())
                .isNotEmpty)) {
      return routed('prepare', '未来时刻已明确，计划与现场可能不同；先准备届时需要的认识与注意条件。',
          canPrepare: s.gaps.isNotEmpty);
    }
    if (c.committedAt != null && !c.reviewed) {
      return const OsNextStep('act', '按约定走出第一步', '按已经确认的边界行动，回来记录真实观察。');
    }
    if (c.guide.confirmed && !c.reviewed) {
      return const OsNextStep(
          'plan', '安排这个有边界的小实验', '确认触发、成本和可逆性，保持大选择与小实验的边界。');
    }
    final gate = SelfOsV37Rules.gate(s, at: now);
    final gaps = s.gaps
        .where((g) => g.important && !g.resolvedBy(s.evidence, now))
        .toList()
      ..sort((a, b) {
        final sensitivity = (a.sensitivity == 'flip' ? 0 : 1)
            .compareTo(b.sensitivity == 'flip' ? 0 : 1);
        return sensitivity == 0 ? a.id.compareTo(b.id) : sensitivity;
      });
    if (gate.action == 'HOLD' || gate.action == 'VERIFY') {
      return OsNextStep(gate.action == 'HOLD' ? 'hold' : 'verify', gate.label,
          gate.reasons.first,
          workspace: 1);
    }
    if (gaps.isNotEmpty && (s.text('risk') != 'unassessed' || c.reviewed)) {
      final g = gaps.first;
      return OsNextStep(
          switch (g.text('access')) {
            'public' => 'retrieve',
            'experience' => 'experiment',
            _ => 'ask'
          },
          switch (g.text('access')) {
            'public' => '核对一个有来源的事实',
            'experience' => '还有一个未知需要现实回答',
            _ => '先澄清这一点'
          },
          g.text('question'),
          workspace: g.text('access') == 'public' ? 1 : null,
          gapId: g.id);
    }
    if (c.reviewed) {
      return OsNextStep(
          gate.action == 'PASS' ? 'decide' : 'assess',
          gate.action == 'PASS' ? '把认识用在路径取舍上' : '看看原来的选择现在还缺什么',
          gate.reasons.first,
          workspace: gate.action == 'PASS' ? 0 : 1);
    }
    if (s.highStakes && s.text('risk') != 'unassessed') {
      return OsNextStep('assess', gate.label, gate.reasons.first, workspace: 1);
    }
    if (s.flag('natureConflict') && s.text('natureEvidence').isNotEmpty) {
      return routed('alignment', '当前目标与已记录的倾向或限制冲突，先检查能力、手段与环境。');
    }
    if (s.text('triggerSource') == 'comparison' &&
        !s.flag('fullLifeAccepted')) {
      return routed('routes', '把羡慕的外观与完整生活结构、代价和个人适配放在一起比较。');
    }
    if (s.futureMoment?.isAfter(now) == true &&
        !c.reviewed &&
        s.interventions.where((i) => !i.completed).isEmpty &&
        ((c.temporalGap ?? 0) >= 25 ||
            SelfOsV37Rules.attentionBreaks(
                    c.motives.map((m) => m.toJson()).toList())
                .isNotEmpty ||
            gaps.isNotEmpty)) {
      return routed('prepare', '未来时刻已明确；先为可能退到背景的认识与尚未解决的未知做最小准备。',
          canPrepare: s.gaps.isNotEmpty);
    }
    if (s.needsLongHorizon &&
        s.routes.isNotEmpty &&
        SelfOsV37Rules.representationGaps(s).any((g) => g.kind == 'causal')) {
      return routed('horizon', '当前只展开了前几步，后续状态可能改变未来还能选择哪些路。');
    }
    final routing = osMap(osMap(c.guide.frame)['routing']);
    if (osGuideTasks.containsKey(routing['task']) &&
        osText(routing['reason']).isNotEmpty &&
        (routing['task'] != 'conflict' || conflictNeedsReview(c))) {
      return routed(osText(routing['task']), osText(routing['reason']),
          canPrepare:
              s.futureMoment?.isAfter(now) == true && s.gaps.isNotEmpty);
    }
    final conflict =
        SelfOsV37Rules.conflict(s, c.motives.map((m) => m.toJson()).toList());
    if (conflict != 'unknown' && conflictNeedsReview(c)) {
      return routed('conflict', SelfOsV37Rules.conflictAdvice[conflict]!);
    }
    // Older, manually entered cases still receive the same core-engine routing
    // as the detailed interface, without inferring structure from keywords.
    if (c.acceptedDesires.isNotEmpty || c.blocker != 'unknown') {
      final core = SelfOsEngineService.next(c);
      return OsNextStep(
          'engine', osGuideTasks[core.engine.name] ?? '继续当前认识', core.reason,
          engine: core.engine);
    }
    return const OsNextStep('explore', '理清想改变和想保护的东西', '一次回应一个会影响下一步的问题。');
  }

  static OsNextStep routed(String task, String reason,
      {bool canPrepare = false}) {
    const workspaces = {
      'routes': 0,
      'gmrc': 1,
      'conflict': 2,
      'prepare': 3,
      'alignment': 4,
      'horizon': 1
    };
    final engine = SelfOsEngine.values.where((e) => e.name == task).firstOrNull;
    return OsNextStep(task, osGuideTasks[task] ?? '继续理清这件事', reason,
        workspace: workspaces[task],
        engine: engine,
        analysisTask: ['routes', 'gmrc', 'alignment', 'horizon'].contains(task)
            ? task
            : task == 'prepare' && canPrepare
                ? 'prepare'
                : null);
  }
}
