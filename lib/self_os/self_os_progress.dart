import 'self_os_models.dart';
import 'self_os_learning.dart';
import 'self_os_v37_rules.dart';

class OsNextStep {
  const OsNextStep(this.kind, this.title, this.reason,
      {this.workspace, this.engine, this.gapId = '', this.interventionId = ''});
  final String kind, title, reason, gapId, interventionId;
  final int? workspace;
  final SelfOsEngine? engine;
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'title': title,
        'reason': reason,
        'gapId': gapId,
        'interventionId': interventionId
      };
}

/// The same ordering drives home, guidance and AI context. A single useful next
/// step is selected from stored evidence; no life-domain keywords or diagnosis.
class SelfOsProgress {
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
    final due = s.interventions
        .where((i) =>
            !i.completed &&
            i.dueAt(s.futureMoment, now) != null &&
            !i.dueAt(s.futureMoment, now)!.isAfter(now))
        .toList()
      ..sort((a, b) => a
          .dueAt(s.futureMoment, now)!
          .compareTo(b.dueAt(s.futureMoment, now)!));
    if (due.isNotEmpty && c.committedAt == null) {
      return OsNextStep('prepare', '到了约定的准备时间', due.first.text('task'),
          workspace: 3,
          gapId: due.first.text('gapId'),
          interventionId: due.first.id);
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
    return const OsNextStep('explore', '理清想改变和想保护的东西', '一次回应一个会影响下一步的问题。');
  }
}
