import 'model.dart';
import 'schema.dart';

const analyticalKinds = <NodeKind>{
  NodeKind.understanding,
  NodeKind.want,
  NodeKind.belief,
  NodeKind.motive,
  NodeKind.reframe,
  NodeKind.route,
  NodeKind.routeFit,
  NodeKind.graphEdge,
  NodeKind.conflict,
  NodeKind.consequence,
  NodeKind.obstacle,
  NodeKind.taskRequirement,
  NodeKind.supportVariant,
  NodeKind.resourceConflict,
  NodeKind.preflight,
  NodeKind.intervention,
  NodeKind.scene,
  NodeKind.review,
  NodeKind.repair,
  NodeKind.insight,
  NodeKind.manifestation,
  NodeKind.principle,
  NodeKind.changeability,
  NodeKind.strengthMatch,
  NodeKind.boundaryReview,
  NodeKind.principleMatch,
  NodeKind.capability,
};

class EvidenceRules {
  static void validateBatch(CaseFile file, List<MirrorNode> added,
      {Map<String, MirrorNode> authorized = const {},
      Set<NodeKind>? allowedKinds,
      bool modelOutput = false,
      DateTime? snapshotAt}) {
    final all = <String, MirrorNode>{
      for (final n in file.nodes) n.id: n,
      ...authorized
    };
    final unique = <String>{};
    for (final node in added) {
      if (node.caseId != file.id || node.episodeId != file.episodeId)
        throw const MirrorProblem('输出不属于当前课题和轮次');
      if (all.containsKey(node.id) || !unique.add(node.id))
        throw const MirrorProblem('记录标识重复');
      all[node.id] = node;
    }
    for (final node in added) {
      if (node.status == NodeStatus.retracted)
        throw const MirrorProblem('不能新增已撤回的内容');
      validateShape(node.body, nodeShapes[node.kind]!);
      if (allowedKinds != null && !allowedKinds.contains(node.kind))
        throw const MirrorProblem('分析阶段返回了不属于本阶段的对象');
      if (modelOutput) {
        if (!analyticalKinds.contains(node.kind) ||
            node.origin != EvidenceOrigin.aiHypothesis ||
            node.status != NodeStatus.draft) {
          throw const MirrorProblem('AI 只能提出候选，不能记录用户已经认可或发生的行为');
        }
        if (node.phase != file.phase || node.happenedAt != null)
          throw const MirrorProblem('AI 不能补造过去时点的行为事实');
      }
      for (final id in node.dependencies) {
        final target = all[id];
        if (target == null) throw MirrorProblem('来源不存在：$id');
        if (!target.usable &&
            !(node.kind == NodeKind.reminder &&
                node.text('state') == 'cancelled'))
          throw const MirrorProblem('输出引用了已撤回、否定或过期的内容');
        if (snapshotAt != null &&
            target.recordedAt.isAfter(snapshotAt) &&
            !unique.contains(id)) {
          throw const MirrorProblem('输出引用了快照之后才记录的资料');
        }
      }
      if (node.revisionOf != null &&
          file.node(node.revisionOf) == null &&
          !authorized.containsKey(node.revisionOf)) {
        throw const MirrorProblem('修订的原版本不存在');
      }
      if (node.revisionOf != null && all[node.revisionOf]?.kind != node.kind) {
        throw const MirrorProblem('新版本必须与被修订对象同类');
      }
      const typedReferences = {
        'routeId': NodeKind.route,
        'routeIds': NodeKind.route,
        'routeAId': NodeKind.route,
        'routeBId': NodeKind.route,
        'selectedRouteIds': NodeKind.route,
        'deferredRouteIds': NodeKind.route,
        'abandonedRouteIds': NodeKind.route,
        'actualRouteIds': NodeKind.route,
        'knownRouteIds': NodeKind.route,
        'wantId': NodeKind.want,
        'wantIds': NodeKind.want,
        'beliefIds': NodeKind.belief,
        'oldBeliefId': NodeKind.belief,
        'motiveId': NodeKind.motive,
        'motiveIds': NodeKind.motive,
        'sceneId': NodeKind.scene,
        'reframeIds': NodeKind.reframe,
        'planId': NodeKind.plan,
        'triggerId': NodeKind.trigger,
        'triggerCheckId': NodeKind.triggerCheck,
        'observationId': NodeKind.observation,
        'observationIds': NodeKind.observation,
        'attemptId': NodeKind.attempt,
        'attemptIds': NodeKind.attempt,
        'interventionId': NodeKind.intervention,
        'interventionIds': NodeKind.intervention,
        'decisionId': NodeKind.decision,
        'principleId': NodeKind.principle,
        'principleVersion': NodeKind.principle,
        'insightIds': NodeKind.insight,
        'capabilityIds': NodeKind.capability,
        'requirementId': NodeKind.taskRequirement,
        'requirementIds': NodeKind.taskRequirement,
        'taskRequirementIds': NodeKind.taskRequirement,
        'supportVariantIds': NodeKind.supportVariant,
        'opportunityId': NodeKind.opportunity,
        'reviewId': NodeKind.review,
      };
      void checkTypes(dynamic body) {
        if (body is Map) {
          for (final e in body.entries) {
            final expected = typedReferences[e.key];
            if (expected != null) {
              for (final id in e.value is List ? e.value as List : [e.value]) {
                if (id != null && all[id]?.kind != expected)
                  throw const MirrorProblem('关联标识的对象类型不匹配');
              }
            }
            if (e.value is Map || e.value is List) checkTypes(e.value);
          }
        } else if (body is List) {
          for (final row in body) {
            checkTypes(row);
          }
        }
      }

      if (node.kind != NodeKind.seal && node.kind != NodeKind.deliberation)
        checkTypes(node.body);
      if (node.kind == NodeKind.understanding) {
        for (final fact in node.objects('facts')) {
          final ids = stringList(fact['evidenceIds']);
          final quote = fact['quote'] as String;
          if (ids.isEmpty ||
              !ids.any((id) =>
                  all[id]?.isFact == true &&
                  all[id]!.text('text').contains(quote))) {
            throw const MirrorProblem('提取的事实必须能回到用户原话，不得添加无来源的细节');
          }
        }
      }
      if (modelOutput &&
          [
            'factStatus',
            'realityStatus',
            'evidenceStatus',
            'objectiveStatus'
          ].any((key) =>
              {'verified', 'observed', 'reported'}.contains(node.text(key))) &&
          actualRoots(node, all).isEmpty) {
        throw const MirrorProblem('没有真实来源的候选只能保留为假设或未知，不能标为已报告、观察或核实');
      }
      if (node.kind == NodeKind.routeFit) {
        final route = all[node.text('routeId')];
        if (route?.kind != NodeKind.route)
          throw const MirrorProblem('路线评估缺少原路线');
        if (route!.text('safety') == 'blocked' &&
            node.text('hardSafetyGate') != 'blocked') {
          throw const MirrorProblem('评分不能覆盖路线的硬性安全限制');
        }
        if (node.number('exploratoryIndex') != null) {
          final dimensions = node.objects('indexDimensions');
          final missing = dimensions.where((e) => e['value'] == null).length;
          final roots = actualRoots(node, all);
          if (dimensions.length != 4 ||
              missing >= 2 ||
              roots.length < 2 ||
              node.text('wantFit') == 'unknown') {
            throw const MirrorProblem('欲求或维度证据不足，不能生成精确路线指数');
          }
        }
      }
      if (node.kind == NodeKind.resourceConflict &&
          {'competing', 'strictly_exclusive'}.contains(node.text('relation'))) {
        if (node.evidenceIds.isEmpty ||
            !node.evidenceIds.any((id) => all[id]?.isFact == true)) {
          throw const MirrorProblem('没有真实资源证据，不能宣布路线互斥');
        }
      }
      if (node.kind == NodeKind.tradeoff && node.text('mode') == 'parallel') {
        final selected = node.strings('selectedRouteIds').toSet();
        if (file.current(NodeKind.resourceConflict).any((conflict) =>
            conflict.text('relation') == 'strictly_exclusive' &&
            {'reported', 'observed', 'verified'}
                .contains(conflict.text('status')) &&
            selected.contains(conflict.text('routeAId')) &&
            selected.contains(conflict.text('routeBId')))) {
          throw const MirrorProblem('当前资源与时间窗口存在已记录的互斥条件，请改为分期、减少投入或先核实新条件');
        }
      }
      if (node.kind == NodeKind.scene) {
        final route = all[node.text('routeId')];
        if (route?.text('safety') == 'blocked' &&
            !{'facts', 'verify_first'}.contains(node.text('mode'))) {
          throw const MirrorProblem('高风险路线只能核实事实或选择保护性处理');
        }
        if (node.text('fieldCue').runes.length > 95 ||
            node.strings('motiveIds').length > 3) {
          throw const MirrorProblem('现场提示过长或选用了过多动机');
        }
        for (final frame in node.objects('frames')) {
          if (frame['kind'] == 'future' && frame['claimType'] == 'fact')
            throw const MirrorProblem('未来画面不能标记为事实');
          if (frame['claimType'] == 'fact' &&
              !stringList(frame['evidenceIds'])
                  .any((id) => all[id]?.isFact == true)) {
            throw const MirrorProblem('事实画面缺少真实来源');
          }
        }
        for (final id in node.strings('motiveIds')) {
          if (all[id]?.status != NodeStatus.accepted)
            throw const MirrorProblem('预演只能使用用户已认可的动机');
        }
        for (final id in node.strings('reframeIds')) {
          if (all[id]?.status != NodeStatus.accepted)
            throw const MirrorProblem('预演不能使用尚未认可的认识');
        }
        if (route != null &&
            !routeCanBePrepared(route, file) &&
            !{'facts', 'verify_first'}.contains(node.text('mode'))) {
          throw const MirrorProblem('最新风险门槛要求先核实，不生成行动劝导');
        }
      }
      if (node.kind == NodeKind.review) {
        if (node.strings('observationIds').isEmpty ||
            node.strings('observationIds').any((id) =>
                all[id]?.kind != NodeKind.observation ||
                all[id]?.isFact != true)) {
          throw const MirrorProblem('复盘需要真实观察');
        }
        for (final h in node.objects('hypotheses')) {
          if (h['status'] == 'required_by_rule' &&
              stringList(h['evidenceIds']).isEmpty) {
            throw const MirrorProblem('没有规则出处，不能断言某项准备必不可少');
          }
        }
      }
      if ({NodeKind.insight, NodeKind.principle}.contains(node.kind)) {
        final roots = actualRoots(node, all);
        if (roots.isEmpty)
          throw const MirrorProblem('个人经验结论必须有真实证据，排名和假设不能循环自证');
        final events = roots
            .where((id) => {
                  NodeKind.observation,
                  NodeKind.attempt,
                  NodeKind.experience,
                  NodeKind.interventionExecution
                }.contains(all[id]?.kind))
            .toList();
        final contexts = events
            .map((id) => '${all[id]!.caseId}/${all[id]!.episodeId}')
            .toSet();
        if (node.text('maturity') == 'multiple_contexts' &&
            contexts.length < 2) {
          throw const MirrorProblem('单次经历不能成为跨情境稳定结论');
        }
        if (node.kind == NodeKind.insight &&
            node.text('category') == 'want' &&
            node.text('maturity') == 'multiple_contexts') {
          final qualified = all.values
              .where((n) =>
                  n.usable &&
                  n.isFact &&
                  n.kind == NodeKind.opportunity &&
                  n.text('state') == 'yes' &&
                  n.text('autonomy') == 'reasonably_free' &&
                  n.strings('actualRouteIds').length >= 2 &&
                  n.strings('knownRouteIds').length >= 2 &&
                  n.text('tradeoff').trim().isNotEmpty &&
                  contexts.contains('${n.caseId}/${n.episodeId}'))
              .map((n) => '${n.caseId}/${n.episodeId}')
              .toSet();
          if (qualified.length < 2) {
            throw const MirrorProblem('缺少不同情境下真实可选、自主、知情的取舍记录，不能升级为跨情境欲求结论');
          }
        }
      }
      if (node.kind == NodeKind.changeability &&
          node.text('classification') == 'hard_limit_for_task' &&
          node.evidenceIds.isEmpty) {
        throw const MirrorProblem('没有证据，不能宣布永久或硬性限制');
      }
      if (node.kind == NodeKind.principleApplication) {
        final principle = all[node.text('principleId')];
        final prior = all[node.revisionOf];
        if (node.text('principleVersion') != node.text('principleId') ||
            (prior != null &&
                prior.text('principleVersion') !=
                    node.text('principleVersion'))) {
          throw const MirrorProblem('应用记录必须保留当时的原则版本，不能替换成后来修订的版本');
        }
        final actualApplication = {'applied_self_report', 'applied_verified'}
            .contains(node.text('application'));
        if (actualApplication) {
          final observed = [
            ...node.strings('attemptIds'),
            ...node.strings('observationIds')
          ].map((id) => all[id]).any((n) =>
              n != null &&
              n.usable &&
              n.isFact &&
              n.caseId == file.id &&
              n.episodeId == file.episodeId &&
              (n.kind == NodeKind.attempt
                  ? !{'unknown', 'not_started'}.contains(n.text('stage'))
                  : n.kind == NodeKind.observation &&
                      n.text('actionState') != 'unknown'));
          if (node.phase.index < TimePhase.t2.index ||
              node.text('detail').trim().isEmpty ||
              !observed) {
            throw const MirrorProblem('实际采用需要具体做法和本轮真实尝试或观察；计划、打开和未知不算应用证据');
          }
          if (node.text('application') == 'applied_verified' &&
              node.origin != EvidenceOrigin.authorizedObservation) {
            throw const MirrorProblem('本人反馈只能标为自述采用，不能冒充外部核实');
          }
        }
        if (node.text('recall') == 'explicitly_recalled' &&
            file.phase == TimePhase.t0) {
          throw const MirrorProblem('请先核实实际现场条件；收到提醒或打开卡片不等于现场想起');
        }
        // Later reports may refer to the historical version actually used.
        // A new adoption or pre-action cue must use an accepted, current and
        // safe principle; a new version never rewrites the old application.
        final adopting = {'accepted', 'scheduled', 'delivered'}
            .contains(node.text('exposure'));
        if (adopting &&
            (prior == null || node.phase.index < TimePhase.t2.index) &&
            (principle == null ||
                !principleCanBePrepared(principle, file,
                    authorized: authorized))) {
          throw const MirrorProblem('这条原则尚未认可、已修订或需要重新核实适用条件，不能作为当前行动提示');
        }
      }
    }
  }

  static bool principleCanBePrepared(MirrorNode principle, CaseFile file,
      {Map<String, MirrorNode> authorized = const {},
      bool requireAccepted = true}) {
    final all = {...authorized, for (final n in file.nodes) n.id: n};
    final current = all[principle.id];
    if (current == null) return false;
    principle = current;
    if (principle.kind != NodeKind.principle ||
        (requireAccepted
            ? principle.status != NodeStatus.accepted
            : !{NodeStatus.draft, NodeStatus.accepted}
                .contains(principle.status)) ||
        principle.text('riskGate') != 'clear' ||
        principle.text('maturity') == 'needs_review' ||
        all.values.any((n) => n.revisionOf == principle.id)) return false;
    if (file.latest(NodeKind.reappraisal)?.flag('safetyChanged') == true) {
      return false;
    }
    if (principle.dependencies.any((id) => all[id]?.usable != true))
      return false;
    final matches = file
        .current(NodeKind.principleMatch)
        .where((n) => n.text('principleId') == principle.id);
    final contextVersion = matches.lastOrNull?.id ?? principle.id;
    final reviewedAt = file.nodes.indexWhere((n) => n.id == contextVersion);
    if (file.current(NodeKind.evidence).any((n) =>
        n.text('context') == 'requires_route_review' &&
        file.nodes.indexWhere((row) => row.id == n.id) > reviewedAt))
      return false;
    if (matches.any((n) =>
        !{'applicable', 'conditional'}.contains(n.text('fit')) ||
        n.text('riskGate') != 'clear')) return false;
    final application = file.latest(NodeKind.principleApplication);
    if (application?.text('principleId') == principle.id &&
        (application?.text('exposure') == 'declined' ||
            {'context_changed', 'rejected'}
                .contains(application?.text('recall')))) {
      return false;
    }
    // A new episode can have new conditions even inside the same Case.
    return (principle.caseId == file.id &&
            principle.episodeId == file.episodeId) ||
        matches.isNotEmpty;
  }

  static Set<String> actualRoots(MirrorNode node, Map<String, MirrorNode> all) {
    final seen = <String>{}, roots = <String>{};
    void visit(String id) {
      if (!seen.add(id)) return;
      final n = all[id];
      if (n == null ||
          !n.usable ||
          {
            NodeKind.recommendation,
            NodeKind.principleApplication,
            NodeKind.principle,
            NodeKind.feedback,
            NodeKind.permission
          }.contains(n.kind)) return;
      const actualKinds = {
        NodeKind.evidence,
        NodeKind.capability,
        NodeKind.triggerCheck,
        NodeKind.awareness,
        NodeKind.decision,
        NodeKind.opportunity,
        NodeKind.attempt,
        NodeKind.observation,
        NodeKind.interventionExecution,
        NodeKind.acquisition,
        NodeKind.experience
      };
      if (n.isFact && actualKinds.contains(n.kind)) roots.add(id);
      for (final ref in n.evidenceIds) {
        visit(ref);
      }
    }

    for (final id in node.evidenceIds) {
      visit(id);
    }
    return roots;
  }

  /// Include dependent hypotheses transitively, including cross-case links.
  static Set<String> invalidationClosure(
      Iterable<MirrorNode> nodes, Set<String> roots) {
    final affected = <String>{...roots};
    var changed = true;
    while (changed) {
      changed = false;
      for (final node in nodes) {
        if (!affected.contains(node.id) &&
            (node.dependencies.any(affected.contains) ||
                affected.contains(node.revisionOf))) {
          affected.add(node.id);
          changed = true;
        }
      }
    }
    return affected;
  }

  static bool routeNeedsReview(MirrorNode route, CaseFile file) {
    final assessment = file
        .current(NodeKind.routeFit)
        .where((n) => n.text('routeId') == route.id)
        .lastOrNull;
    final asOf = file.nodes.indexWhere(
      (n) => n.id == (assessment?.id ?? route.id),
    );
    return file.current(NodeKind.evidence).any(
          (n) =>
              n.text('context') == 'requires_route_review' &&
              file.nodes.indexWhere((row) => row.id == n.id) > asOf,
        );
  }

  static bool routeCanBePrepared(MirrorNode route, [CaseFile? file]) =>
      route.usable &&
      route.kind == NodeKind.route &&
      (file == null ||
          file.current(NodeKind.route).any((n) => n.id == route.id)) &&
      route.text('safety') != 'blocked' &&
      route.text('feasibility') != 'infeasible' &&
      (route.text('safety') == 'clear' || route.flag('protective')) &&
      (file == null ||
          !routeNeedsReview(route, file) ||
          route.flag('protective')) &&
      !(file?.latest(NodeKind.reappraisal)?.flag('safetyChanged') == true &&
          !route.flag('protective')) &&
      !(file?.current(NodeKind.routeFit).any((fit) =>
              fit.text('routeId') == route.id &&
              (fit.text('hardSafetyGate') == 'blocked' ||
                  fit.text('externalFeasibility') == 'infeasible' ||
                  fit.text('bodySkillFit') == 'prohibited_due_to_safety' ||
                  (fit.text('hardSafetyGate') != 'clear' &&
                      !route.flag('protective')))) ??
          false);

  static bool canReveal(CaseFile file) =>
      file.current(NodeKind.observation).any((n) =>
          n.isFact &&
          n.text('actionState') != 'unknown' &&
          n.evidenceIds.isNotEmpty);

  static bool verifySeal(MirrorNode seal) {
    if (seal.kind != NodeKind.seal ||
        !seal.usable ||
        seal.flag('privacyRedacted')) return false;
    return seal.text('hash') ==
        digest({
          'caseId': seal.caseId,
          'snapshot': seal.body['snapshot'],
          'sealedAt': seal.body['sealedAt'],
          'nonce': seal.body['nonce']
        });
  }
}

class CaseCommands {
  CaseCommands({DateTime Function()? clock}) : clock = clock ?? DateTime.now;
  final DateTime Function() clock;

  MirrorNode record(CaseFile file, NodeKind kind, Json body,
          {List<String> evidenceIds = const [],
          List<String> counterIds = const [],
          List<String> links = const [],
          DateTime? happenedAt,
          DateTime? knownAt,
          TimePhase? phase,
          EvidenceOrigin origin = EvidenceOrigin.selfReport,
          NodeStatus status = NodeStatus.active,
          String? revisionOf,
          String? id}) =>
      MirrorNode(
          id: id ?? newId(kind.name),
          caseId: file.id,
          episodeId: file.episodeId,
          kind: kind,
          origin: origin,
          phase: phase == null || phase.index < file.phase.index
              ? file.phase
              : phase,
          recordedAt: clock().toUtc(),
          knownAt: knownAt,
          happenedAt: happenedAt,
          body: body,
          evidenceIds: evidenceIds,
          counterIds: counterIds,
          links: links,
          status: status,
          revisionOf: revisionOf);

  CaseFile create(String issue, {bool retrospective = false}) {
    if (issue.trim().isEmpty || issue.length > 16000)
      throw const MirrorProblem('请描述一件具体的事（最多 16000 字）');
    final now = clock().toUtc();
    final file = CaseFile(
        id: newId('case'),
        issue: issue.trim(),
        createdAt: now,
        updatedAt: now,
        episodeId: newId('episode'),
        retrospective: retrospective);
    final first = record(
        file,
        NodeKind.evidence,
        {
          'text': issue.trim(),
          'category': 'event',
          'source': 'self_report',
          'sensitive': false,
          'scope': 'case_only'
        },
        knownAt: now,
        phase: retrospective ? TimePhase.t2 : TimePhase.t0);
    return file.evolve(nodes: [first], now: now);
  }

  CaseFile append(CaseFile file, List<MirrorNode> nodes,
      {CaseStage? stage,
      int? step,
      Map<String, MirrorNode> authorized = const {}}) {
    EvidenceRules.validateBatch(file, nodes, authorized: authorized);
    return file.evolve(
        nodes: [...file.nodes, ...nodes],
        stage: stage,
        step: step,
        now: clock());
  }

  CaseFile feedback(CaseFile file, String targetId, String action,
      {String comment = ''}) {
    final target = file.node(targetId);
    if (target == null || !target.usable)
      throw const MirrorProblem('这项内容已变更，请刷新后再操作');
    final feedback = record(file, NodeKind.feedback,
        {'targetId': targetId, 'action': action, 'comment': comment},
        links: [targetId]);
    final checked = append(file, [feedback]);
    final rejected = {'reject', 'not_applicable', 'retire'}.contains(action);
    final affected = rejected
        ? EvidenceRules.invalidationClosure(file.nodes, {targetId})
        : <String>{};
    final status = action == 'later'
        ? NodeStatus.draft
        : action == 'accept'
            ? NodeStatus.accepted
            : action == 'retire'
                ? NodeStatus.retired
                : NodeStatus.rejected;
    return checked.evolve(
        nodes: checked.nodes.map((n) {
          if (n.id == targetId &&
              (rejected || action == 'accept' || action == 'later'))
            return n.withStatus(status);
          if (affected.contains(n.id) &&
              (n.origin == EvidenceOrigin.aiHypothesis ||
                  {
                    NodeKind.plan,
                    NodeKind.scene,
                    NodeKind.reminder,
                    NodeKind.recommendation,
                    NodeKind.principleApplication
                  }.contains(n.kind))) return n.withStatus(NodeStatus.stale);
          return n;
        }).toList(),
        selectedMotiveIds: rejected
            ? file.selectedMotiveIds
                .where((id) => !affected.contains(id))
                .toList()
            : null,
        clearRoute: affected.contains(file.selectedRouteId),
        now: clock());
  }

  CaseFile chooseRoute(CaseFile file, String routeId) {
    final route = file.node(routeId);
    if (route == null || !EvidenceRules.routeCanBePrepared(route, file))
      throw const MirrorProblem('这条路线需要先核实限制，或选择安全的替代方式');
    return file.evolve(
        selectedRouteId: routeId,
        stage: CaseStage.preflight,
        step: 4,
        now: clock());
  }

  CaseFile chooseMotive(CaseFile file, String motiveId, bool selected) {
    final motive = file.node(motiveId);
    if (motive == null ||
        motive.kind != NodeKind.motive ||
        !motive.usable ||
        !file.current(NodeKind.motive).any((n) => n.id == motiveId))
      throw const MirrorProblem('这条理由已失效');
    var updated = file;
    final ids = {...file.selectedMotiveIds};
    if (selected) {
      if (ids.length >= 3 && !ids.contains(motiveId))
        throw const MirrorProblem('现场保留最多三条关键理由，其余仍可随时查看');
      updated = feedback(file, motiveId, 'accept');
      ids.add(motiveId);
    } else {
      ids.remove(motiveId);
    }
    return updated.evolve(selectedMotiveIds: ids.toList(), now: clock());
  }

  CaseFile sealPlan(CaseFile file, Json body,
      {bool sealPrediction = true,
      Map<String, MirrorNode> authorized = const {}}) {
    if (file.retrospective ||
        file.current(NodeKind.observation).isNotEmpty ||
        file
            .current(NodeKind.triggerCheck)
            .any((n) => {'confirmed', 'changed'}.contains(n.text('state')))) {
      throw const MirrorProblem('现场或事后记录不能补成事前预测；可以在同一课题开始下一轮');
    }
    final route = file.node(body['routeId'] as String?);
    if (route == null || !EvidenceRules.routeCanBePrepared(route, file))
      throw const MirrorProblem('请先选择条件允许的路线');
    final scene = file.node(body['sceneId'] as String?);
    if (scene != null && (!scene.usable || scene.status != NodeStatus.accepted))
      throw const MirrorProblem('预演尚未认可或已经失效');
    final principleId = body['principleId'] as String?;
    if (principleId != null) {
      final principle = file.node(principleId) ?? authorized[principleId];
      if (principle == null ||
          !EvidenceRules.principleCanBePrepared(principle, file,
              authorized: authorized)) {
        throw const MirrorProblem('这条原则需要重新核实，不能封存为现场提示；也可以不使用原则继续');
      }
    }
    final prior = file.latest(NodeKind.plan);
    final now = clock().toUtc();
    final plan = record(file, NodeKind.plan, {...body, 'userConfirmed': true},
        links: [
          route.id,
          ...file.selectedMotiveIds,
          ...stringList(body['interventionIds'])
        ],
        knownAt: now,
        phase: TimePhase.t0,
        revisionOf: prior?.id);
    final trigger = record(
        file,
        NodeKind.trigger,
        {
          'planId': plan.id,
          'signal': body['triggerSignal'],
          'scheduledAt': body['remindAt'],
          'expiresAt': body['expiresAt'],
          'verificationRequired': true
        },
        phase: TimePhase.t0);
    final records = <MirrorNode>[plan, trigger];
    if (sealPrediction) {
      final nonce = newId('nonce');
      final snapshot = {
        'plan': plan.toJson(),
        'nodes': file.nodes
            .where((n) => n.usable && n.kind != NodeKind.permission)
            .map((e) => e.toJson())
            .toList(),
        'caseRevision': file.revision,
        'selectedMotiveIds': file.selectedMotiveIds
      };
      final time = now.toIso8601String();
      records.add(record(
          file,
          NodeKind.seal,
          {
            'planId': plan.id,
            'snapshot': snapshot,
            'hash': digest({
              'caseId': file.id,
              'snapshot': snapshot,
              'sealedAt': time,
              'nonce': nonce
            }),
            'nonce': nonce,
            'sealedAt': time,
            'clockWarning': now.isBefore(file.updatedAt)
          },
          links: [
            plan.id,
            ...file.nodes
                .where((n) => n.usable && n.kind != NodeKind.permission)
                .map((n) => n.id)
          ],
          phase: TimePhase.t0,
          origin: EvidenceOrigin.productRule));
    }
    return append(file, records,
        stage: CaseStage.waiting, step: 5, authorized: authorized);
  }

  CaseFile verifyTrigger(CaseFile file, String state, String detail,
      {DateTime? occurredAt}) {
    final trigger = file.latest(NodeKind.trigger);
    if (trigger == null) throw const MirrorProblem('尚未定义要核实的条件');
    if (state == 'confirmed' && (detail.trim().isEmpty || occurredAt == null))
      throw const MirrorProblem('请确认实际出现的条件与时间；提醒到时不能替代它');
    final prior = file.latest(NodeKind.triggerCheck);
    final node = record(
        file,
        NodeKind.triggerCheck,
        {
          'triggerId': trigger.id,
          'state': state,
          'detail': detail,
          'occurredAt': occurredAt?.toUtc().toIso8601String()
        },
        happenedAt: occurredAt,
        knownAt: clock().toUtc(),
        phase: TimePhase.t1,
        revisionOf: prior?.id);
    return append(file, [node],
        stage: switch (state) {
          'confirmed' => CaseStage.triggered,
          'changed' => CaseStage.conditionsChanged,
          'expired' => CaseStage.triggerMissed,
          'cancelled' => CaseStage.paused,
          _ => CaseStage.waiting
        },
        step: 5);
  }

  CaseFile observe(CaseFile file,
      {required Json body,
      DateTime? happenedAt,
      required String evidenceText}) {
    final evidence = record(
        file,
        NodeKind.evidence,
        {
          'text': evidenceText,
          'category': 'action',
          'source': 'self_report',
          'sensitive': false,
          'scope': 'case_only'
        },
        happenedAt: happenedAt,
        knownAt: clock().toUtc(),
        phase: TimePhase.t2);
    final observation = record(file, NodeKind.observation, body,
        evidenceIds: [evidence.id],
        happenedAt: happenedAt,
        knownAt: clock().toUtc(),
        phase: TimePhase.t2);
    return append(file, [evidence, observation],
        stage: body['actionState'] == 'unknown'
            ? CaseStage.noObservation
            : CaseStage.observed,
        step: 6);
  }

  CaseFile reveal(CaseFile file) {
    if (!EvidenceRules.canReveal(file))
      throw const MirrorProblem('还没有足够的真实行为反馈，结果继续等待');
    return file.evolve(stage: CaseStage.revealed, step: 6, now: clock());
  }

  CaseFile nextEpisode(CaseFile file) => file.evolve(
      episodeId: newId('episode'),
      cycle: file.cycle + 1,
      stage: CaseStage.newCase,
      step: 0,
      clearRoute: true,
      selectedMotiveIds: [],
      retrospective: false,
      analysisMessage: '带着已记录的经历，重新核实这一次的条件。',
      now: clock());

  CaseFile retract(CaseFile file, Set<String> roots, {Set<String>? affected}) {
    final ids =
        affected ?? EvidenceRules.invalidationClosure(file.nodes, roots);
    return file.evolve(
        nodes: file.nodes.map((node) {
          if (roots.contains(node.id))
            return node.withStatus(NodeStatus.retracted, redact: true);
          if (ids.contains(node.id))
            return node.withStatus(NodeStatus.stale, redact: true);
          return node;
        }).toList(),
        issue: file.nodes.where((n) => ids.contains(n.id)).any((n) =>
                n.kind == NodeKind.evidence && n.text('text') == file.issue)
            ? '已撤回原始描述'
            : null,
        clearRoute: ids.contains(file.selectedRouteId),
        selectedMotiveIds:
            file.selectedMotiveIds.where((id) => !ids.contains(id)).toList(),
        analysisMessage: '来源有变更，相关建议已停止使用。',
        now: clock());
  }
}
