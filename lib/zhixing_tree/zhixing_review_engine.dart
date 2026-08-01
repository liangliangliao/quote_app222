import 'zhixing_extended_models.dart';
import 'zhixing_models.dart';
import 'zhixing_thinker_catalog.dart';

/// Deterministic, offline review. It uses the reviewed thinker catalog and
/// therefore remains available without an AI account or network connection.
class ZxLocalReviewEngine {
  const ZxLocalReviewEngine();

  ZxReviewReport generate({
    required ZxActionPrescription action,
    required ZxReviewInput review,
  }) {
    final current = ZxThinkerCatalog.guideFor(action.primaryLensId);
    final currentId = current?.systemId ?? action.primaryLensId;
    final outcome = _outcomeLabel(review.completion);
    final finding = _barrierFinding(review);
    final route = _route(review, currentId);
    final recommended = route.systems
        .map(_findGuide)
        .whereType<ZxThinkerGuide>()
        .toList(growable: false);
    final names = recommended.map((item) => item.displayName).join(' + ');
    final currentName = current?.displayName ?? action.primaryLensId;
    final knowledgeReason = recommended.isEmpty
        ? current?.decisionCue ?? '继续用当前方案收集一轮行动证据。'
        : recommended
            .map(
              (item) =>
                  item.displayName +
                  '：' +
                  item.decisionCue +
                  '；与王阳明主线的连接是' +
                  item.yangmingConnection,
            )
            .join('\n');
    final nextAction = review.nextAction.trim().isNotEmpty
        ? review.nextAction.trim()
        : review.difficultyFit == '过高' ||
                review.completion == ZxCompletionStatus.notCompleted
            ? action.lowerLoadAlternative
            : action.mainAction;
    final insight = review.hypothesisUpdate.trim();

    return ZxReviewReport(
      actionUid: action.id,
      origin: ZxKnowledgeOrigin.localReviewed,
      summary: '本轮$outcome；难度' +
          review.difficultyFit +
          '。' +
          (insight.isEmpty ? '' : '关键发现：$insight'),
      progressEvidence: review.whatHappened.trim().isEmpty
          ? '已记录$outcome，形成一条可用于修正下一步的行动证据。'
          : review.whatHappened.trim(),
      barrierFinding: finding,
      recommendedDecision: route.decision,
      currentSystemId: currentId,
      recommendedSystemIds:
          recommended.map((item) => item.systemId).toList(growable: false),
      rationale: route.decision == ZxReviewDecision.continueCurrent
          ? '当前的$currentName仍能解释本轮结果，先保持框架并校准行动强度。$knowledgeReason'
          : '建议' +
              route.decision.label +
              (names.isEmpty ? '' : '：$names') +
              '。' +
              knowledgeReason,
      nextAction: nextAction,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  _ReviewRoute _route(ZxReviewInput review, String currentId) {
    if (review.completion == ZxCompletionStatus.exited) {
      return const _ReviewRoute(
        ZxReviewDecision.switchThought,
        <String>['自我决定', '弗兰克尔', '王阳明'],
      );
    }
    if (review.completion == ZxCompletionStatus.safetyDowngrade) {
      return const _ReviewRoute(
        ZxReviewDecision.blendThoughts,
        <String>['老子', '马斯洛'],
      );
    }
    if (review.completion == ZxCompletionStatus.notCompleted) {
      if (review.difficultyFit == '过高') {
        return const _ReviewRoute(
          ZxReviewDecision.blendThoughts,
          <String>['行为激活', 'Gollwitzer', '老子'],
        );
      }
      return const _ReviewRoute(
        ZxReviewDecision.switchThought,
        <String>['威廉·詹姆斯', '行为激活', '班杜拉'],
      );
    }
    if (review.difficultyFit == '过低') {
      return const _ReviewRoute(
        ZxReviewDecision.blendThoughts,
        <String>['杜威', '班杜拉', '尼采'],
      );
    }
    if (review.learning == ZxLearningStatus.updated ||
        review.hypothesisUpdate.trim().isNotEmpty) {
      return const _ReviewRoute(
        ZxReviewDecision.blendThoughts,
        <String>['杜威', '贝克'],
      );
    }
    return _ReviewRoute(
      ZxReviewDecision.continueCurrent,
      <String>[currentId],
    );
  }

  ZxThinkerGuide? _findGuide(String token) {
    for (final guide in ZxThinkerCatalog.guides) {
      if (guide.systemId == token ||
          guide.displayName.contains(token) ||
          guide.thinker.contains(token)) {
        return guide;
      }
    }
    return null;
  }

  String _barrierFinding(ZxReviewInput review) {
    if (review.completion == ZxCompletionStatus.exited) {
      return '主要问题不再是坚持，而是目标方向、价值认领或代价需要重新判断。';
    }
    if (review.completion == ZxCompletionStatus.notCompleted) {
      return review.difficultyFit == '过高'
          ? '行动负荷超过当下容量，应缩小步骤、增加现场线索或环境支持。'
          : '意图尚未稳定转成现场动作，需要更明确的触发线索和第一步。';
    }
    if (review.completion == ZxCompletionStatus.safetyDowngrade) {
      return '用户已主动保护安全与容量；这是一种有效校准，不是失败。';
    }
    if (review.difficultyFit == '过低') {
      return '启动已经形成，可逐步提高挑战或增加真实结果反馈。';
    }
    return '当前知—行连接基本有效，重点是重复、复审并让经验反过来深化认识。';
  }

  String _outcomeLabel(ZxCompletionStatus status) {
    switch (status) {
      case ZxCompletionStatus.completed:
        return '已完成';
      case ZxCompletionStatus.notCompleted:
        return '未完成';
      case ZxCompletionStatus.safetyDowngrade:
        return '完成了安全降级步骤';
      case ZxCompletionStatus.exited:
        return '基于新认识退出';
    }
  }
}

class _ReviewRoute {
  const _ReviewRoute(this.decision, this.systems);

  final ZxReviewDecision decision;
  final List<String> systems;
}
