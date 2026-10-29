import 'package:flutter/foundation.dart';

import '../ai/decisions_gateway.dart';
import '../ai/pipeline.dart';
import '../ai/protocol.dart';
import '../ai/workbench_pass.dart';
import '../data/store.dart';
import '../domain/model.dart';
import '../domain/ranking.dart';
import '../domain/rules.dart';
import '../integration/reminders.dart';

class MirrorController extends ChangeNotifier {
  MirrorController(
      {required this.store,
      required this.model,
      required this.reminders,
      DecisionsGateway? decisions,
      CaseCommands? commands})
      : decisions = decisions ?? DecisionsGateway(),
        commands = commands ?? CaseCommands();
  final MirrorStore store;
  final StructuredModel model;
  final MirrorReminders reminders;
  final DecisionsGateway decisions;
  final CaseCommands commands;
  List<CaseFile> files = [];
  MirrorSettings preferences = const MirrorSettings();
  bool initialized = false;
  String? busyCaseId;
  String progressTitle = '', progressDetail = '', providerLabel = '';
  String? error;
  String? notice;
  AnalysisStage? retryStage;
  bool retryWorkflow = false;
  Json retryOptions = const {};
  CancelToken? _cancel;
  bool _disposed = false;
  Future<void> _queue = Future.value();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  CaseFile? file(String id) {
    for (final f in files) {
      if (f.id == id) return f;
    }
    return null;
  }

  MirrorNode? resolve(String id) {
    for (final f in files) {
      final n = f.node(id);
      if (n != null) return n;
    }
    return null;
  }

  Map<String, MirrorNode> get authorizedHistory => {
        for (final f
            in files.where((f) => preferences.crossCaseIds.contains(f.id)))
          for (final n in f.nodes.where((n) => n.usable)) n.id: n
      };
  Future<void> initialize() async {
    preferences = await store.settings();
    files = await store.list();
    // Provider settings and reminders are optional. Their platform failures must
    // not lock users out of a successfully opened, local encrypted ledger.
    final startupNotices = <String>[];
    try {
      providerLabel = await model.label();
    } catch (_) {
      providerLabel = 'AI 设置暂时不可用';
      startupNotices.add('AI 设置暂时无法读取，仍可查看资料和继续本地记录。');
    }
    try {
      await reconcileReminders();
    } catch (_) {
      startupNotices.add('提醒暂时无法同步，请在工作台手动回看；未确认提醒已送达。');
    }
    notice = startupNotices.isEmpty ? null : startupNotices.join('\n');
    initialized = true;
    _notify();
  }

  Future<void> reload() async {
    files = await store.list();
    _notify();
  }

  void stop() {
    _cancel?.cancel();
    _cancel = null;
    busyCaseId = null;
    progressTitle = '';
    progressDetail = '';
    _notify();
  }

  void clearError() {
    error = null;
    _notify();
  }

  Future<void> _commit(CaseFile before, CaseFile after) async {
    await store.save(after, expectedRevision: before.revision);
    final index = files.indexWhere((f) => f.id == after.id);
    if (index < 0) {
      files = [after, ...files];
    } else {
      files = [...files]..[index] = after;
    }
    files.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _notify();
  }

  Future<CaseFile> create(String issue, {bool retrospective = false}) async {
    final value = commands.create(issue, retrospective: retrospective);
    await store.save(value, expectedRevision: 0);
    files = [value, ...files];
    _notify();
    return value;
  }

  Future<void> mutate(String id, CaseFile Function(CaseFile) change) async {
    if (busyCaseId == id) stop();
    final operation = _queue.catchError((_) {}).then((_) async {
      final current = await store.load(id);
      if (current == null) throw const MirrorProblem('课题已经删除');
      await _commit(current, change(current));
    });
    _queue = operation;
    return operation;
  }

  Future<void> advance(String id, int step) =>
      mutate(id, (f) => f.evolve(step: step));
  Future<void> pause(String id) async {
    await cancelReminders(id);
    await mutate(id, (f) => f.evolve(stage: CaseStage.paused));
  }

  Future<void> addEvidence(String id, String text,
      {String category = 'condition',
      bool sensitive = false,
      DateTime? happenedAt,
      bool materialChange = false}) async {
    if (text.trim().isEmpty) throw const MirrorProblem('请写下需要补充的一条事实');
    if (materialChange) await cancelReminders(id);
    await mutate(id, (f) {
      final node = commands.record(
          f,
          NodeKind.evidence,
          {
            'text': text.trim(),
            'category': category,
            'source': 'self_report',
            'sensitive': sensitive,
            'scope': 'case_only',
            if (materialChange) 'context': 'requires_route_review',
          },
          knownAt: DateTime.now().toUtc(),
          happenedAt: happenedAt);
      final next = commands.append(f, [node]);
      if (!materialChange) return next;
      const obsolete = {
        NodeKind.routeFit,
        NodeKind.preflight,
        NodeKind.plan,
        NodeKind.trigger,
        NodeKind.scene,
        NodeKind.principleMatch,
        NodeKind.recommendation,
      };
      return next.evolve(
          clearRoute: true,
          selectedMotiveIds: [],
          nodes: next.nodes
              .map((n) => n.episodeId == f.episodeId &&
                      obsolete.contains(n.kind) &&
                      n.usable
                  ? n.withStatus(NodeStatus.stale)
                  : n)
              .toList(),
          analysisMessage: '有新的现实记录，旧路线比较与预案需要重新核实；已发生的事实和封存历史保留。');
    });
  }

  Future<void> feedback(String id, String target, String action,
      {String comment = ''}) async {
    await mutate(
        id, (f) => commands.feedback(f, target, action, comment: comment));
    await _rerank(id);
    await reconcileReminders();
  }

  Future<void> addCounterEvidence(String id, String target, String text) async {
    stop();
    // Validate before cancelling anything; then cancel OS jobs before making
    // the new review version visible. Historical applications stay readable.
    final source = file(id);
    if (source == null) throw const MirrorProblem('课题已经删除');
    commands.addCounterEvidence(source, target, text);
    final affected = EvidenceRules.invalidationClosure(
        files.expand((f) => f.nodes), {target});
    await _cancelAffected({target});
    await mutate(id, (f) => commands.addCounterEvidence(f, target, text));
    for (final entry in files
        .where((f) =>
            f.nodes.any((n) => n.id != target && affected.contains(n.id)))
        .toList()) {
      await mutate(
          entry.id,
          (f) => f.evolve(
                nodes: f.nodes
                    .map((n) => n.id != target &&
                            affected.contains(n.id) &&
                            (analyticalKinds.contains(n.kind) ||
                                {
                                  NodeKind.plan,
                                  NodeKind.trigger,
                                  NodeKind.reminder,
                                  NodeKind.recommendation,
                                }.contains(n.kind))
                        ? n.withStatus(NodeStatus.stale)
                        : n)
                    .toList(),
                analysisMessage: '新增反例，相关建议已暂停。过去的准备、行动与应用版本继续保留。',
              ));
    }
    await reconcileReminders();
  }

  Future<void> correctEvidence(
      String caseId, String evidenceId, String text) async {
    stop();
    final affectedAcross = EvidenceRules.invalidationClosure(
        files.expand((f) => f.nodes), {evidenceId});
    await _cancelAffected({evidenceId});
    await mutate(caseId, (f) {
      final old = f.node(evidenceId);
      if (old == null ||
          !old.usable ||
          old.kind != NodeKind.evidence ||
          text.trim().isEmpty) throw const MirrorProblem('请修改当前有效的原始记录');
      final revised = commands.record(f, NodeKind.evidence,
          {...old.body, 'text': text.trim(), 'category': 'correction'},
          knownAt: DateTime.now().toUtc(),
          happenedAt: old.happenedAt,
          revisionOf: old.id);
      final affected = EvidenceRules.invalidationClosure(f.nodes, {old.id});
      final checked = commands.append(f, [revised]);
      return checked.evolve(
          nodes: checked.nodes
              .map((n) => affected.contains(n.id) &&
                      n.id != old.id &&
                      (n.origin == EvidenceOrigin.aiHypothesis ||
                          {
                            NodeKind.plan,
                            NodeKind.scene,
                            NodeKind.reminder,
                            NodeKind.recommendation
                          }.contains(n.kind))
                  ? n.withStatus(NodeStatus.stale)
                  : n)
              .toList(),
          issue: f.issue == old.text('text') ? text.trim() : null,
          clearRoute: affected.contains(f.selectedRouteId),
          selectedMotiveIds: f.selectedMotiveIds
              .where((id) => !affected.contains(id))
              .toList());
    });
    for (final other in files
        .where((f) =>
            f.id != caseId && f.nodes.any((n) => affectedAcross.contains(n.id)))
        .toList()) {
      await mutate(
          other.id,
          (f) => f.evolve(
              nodes: f.nodes
                  .map((n) => affectedAcross.contains(n.id) &&
                          (n.origin == EvidenceOrigin.aiHypothesis ||
                              {
                                NodeKind.plan,
                                NodeKind.scene,
                                NodeKind.reminder,
                                NodeKind.recommendation
                              }.contains(n.kind))
                      ? n.withStatus(NodeStatus.stale)
                      : n)
                  .toList(),
              clearRoute: affectedAcross.contains(f.selectedRouteId),
              selectedMotiveIds: f.selectedMotiveIds
                  .where((id) => !affectedAcross.contains(id))
                  .toList()));
    }
  }

  Future<void> _rerank(String id) => mutate(id, (f) {
        if (f.current(NodeKind.motive).isEmpty) return f.evolve();
        // Feedback changes eligibility immediately. Old scores are kept as history;
        // new input is never presented as if the remote model had scored it.
        return commands.append(f, [
          MotiveRanking.build(f,
              weights: preferences.weights,
              message: '已按当前认可、反证与有效来源更新；在线评分需单独重算')
        ]);
      });

  Future<void> selectMotive(String id, String motiveId, bool selected) =>
      mutate(id, (f) => commands.chooseMotive(f, motiveId, selected));
  Future<void> selectRoute(String id, String routeId) async {
    await cancelReminders(id);
    await mutate(id, (f) {
      final next = commands.chooseRoute(f, routeId);
      return next.evolve(
          nodes: next.nodes
              .map((n) => n.usable &&
                      {
                        NodeKind.plan,
                        NodeKind.trigger,
                        NodeKind.preflight,
                        NodeKind.scene
                      }.contains(n.kind) &&
                      (n.kind == NodeKind.trigger ||
                          n.text('routeId') != routeId)
                  ? n.withStatus(NodeStatus.stale)
                  : n)
              .toList());
    });
  }

  Future<void> acceptReframe(String id, String reframeId) async {
    final candidate = file(id)?.node(reframeId);
    if (candidate == null ||
        !candidate.usable ||
        candidate.kind != NodeKind.reframe)
      throw const MirrorProblem('认识候选已变化');
    await cancelReminders(id);
    await mutate(id, (f) {
      final reframe = f.node(reframeId);
      if (reframe == null || !reframe.usable)
        throw const MirrorProblem('认识候选已变化');
      final beforeEdges = f.current(NodeKind.graphEdge);
      final before = commands.record(
          f,
          NodeKind.deliberation,
          {
            'label': '认可新认识之前',
            'nodeIds': beforeEdges.map((n) => n.id).toList(),
            'unknowns': reframe.strings('unknowns'),
            'endorsedIds': f.selectedMotiveIds,
            'snapshot': {'nodes': beforeEdges.map((n) => n.toJson()).toList()}
          },
          origin: EvidenceOrigin.productRule);
      var next = commands.append(f, [before]);
      next = commands.feedback(next, reframeId, 'accept');
      final old = f.node(reframe.text('oldBeliefId'));
      final belief = commands.record(
          next,
          NodeKind.belief,
          {
            'claim': reframe.text('newClaim'),
            'kind': old?.text('kind') ?? 'prediction',
            'realityStatus': 'hypothesized',
            'confidence': null,
            'awareness': f.phase == TimePhase.t0
                ? 'known_before'
                : f.phase == TimePhase.t1
                    ? 'noticed_at_trigger'
                    : 'recalled_after',
            'influence': 'unknown',
            'verify': reframe.text('test')
          },
          evidenceIds: reframe.evidenceIds,
          links: [reframe.id],
          origin: EvidenceOrigin.aiHypothesis,
          status: NodeStatus.accepted,
          knownAt: DateTime.now().toUtc());
      final after = commands.record(
          next,
          NodeKind.deliberation,
          {
            'label': '认可新认识之后（影响仍待检验）',
            'nodeIds': [...beforeEdges.map((n) => n.id), belief.id],
            'unknowns': reframe.strings('unknowns'),
            'endorsedIds': [...f.selectedMotiveIds, reframe.id],
            'snapshot': {
              'newBelief': belief.toJson(),
              'affectedMotiveIds': reframe.strings('affectedMotiveIds'),
              'affectedRouteIds': reframe.strings('affectedRouteIds')
            }
          },
          links: [belief.id],
          origin: EvidenceOrigin.productRule);
      final shift = commands.record(
          next,
          NodeKind.graphShift,
          {
            'beforeId': before.id,
            'afterId': after.id,
            'addedIds': [belief.id],
            'removedIds': <String>[],
            'changedIds': reframe.strings('affectedMotiveIds'),
            'reason': reframe.text('mechanism'),
            'nextTest': reframe.text('test')
          },
          links: [reframe.id],
          origin: EvidenceOrigin.productRule);
      final revised = commands.append(next, [belief, after, shift],
          stage: CaseStage.reframed);
      final affected = reframe.strings('affectedRouteIds').toSet();
      return revised.evolve(
        nodes: revised.nodes
            .map(
              (n) => n.usable &&
                      n.episodeId == f.episodeId &&
                      {
                        NodeKind.routeFit,
                        NodeKind.preflight,
                        NodeKind.plan,
                        NodeKind.scene,
                      }.contains(n.kind) &&
                      affected.contains(n.text('routeId'))
                  ? n.withStatus(NodeStatus.stale)
                  : n,
            )
            .toList(),
      );
    });
  }

  Map<String, MirrorNode> externalFor(AnalysisConsent consent) => {
        for (final f in files.where((f) =>
            f.id != consent.caseId &&
            preferences.crossCaseIds.contains(f.id) &&
            consent.sourceCaseIds.contains(f.id)))
          for (final n in f.nodes.where((n) => n.usable)) n.id: n,
      };
  Future<void> analyze(AnalysisConsent consent,
      {AnalysisStage? onlyStage, Json options = const {}}) async {
    if (busyCaseId != null) stop();
    var initial = await store.load(consent.caseId);
    if (initial == null || initial.revision != consent.revision)
      throw const VersionConflict();
    final pass = requestedPass(options);
    notice = null;
    final fingerprint = digest({
      'sources': (consent.evidenceIds.toList()..sort())
          .map((id) => resolve(id)?.toJson())
          .toList(),
      'scope': (consent.sourceCaseIds.toList()..sort()),
      'sensitive': consent.sensitiveAllowed,
      'selectedRouteId': initial.selectedRouteId,
      'selectedMotiveIds': initial.selectedMotiveIds,
      'phase': initial.phase.name,
      'provider': providerLabel
    });
    if (onlyStage == null &&
        options['workbenchPass'] == null &&
        initial.current(NodeKind.motive).length >= 50 &&
        initial.current(NodeKind.routeFit).isNotEmpty &&
        initial.current(NodeKind.permission).any((n) =>
            n.flag('completed') &&
            n.text('stage') == 'full' &&
            n.text('analysisFingerprint') == fingerprint)) {
      notice = '资料未发生变化，已保留现有分析。可以继续比较路线、准备或等待真实条件。';
      error = null;
      _notify();
      return;
    }
    final permission = commands.record(
        initial,
        NodeKind.permission,
        {
          'purpose': 'analysis',
          'allowedIds': consent.evidenceIds.toList(),
          'sourceCaseIds': consent.sourceCaseIds.toList(),
          'sensitiveAllowed': consent.sensitiveAllowed,
          'granted': true,
          'runId': consent.runId,
          'analysisFingerprint': fingerprint,
          'stage': options['workbenchPass'] is String
              ? 'workbench_${options['workbenchPass']}'
              : onlyStage?.name ?? 'full',
          'completed': false,
        },
        origin: EvidenceOrigin.deviceEvent);
    final permitted = commands.append(initial, [permission],
        authorized: externalFor(consent));
    await _commit(initial, permitted);
    initial = permitted;
    consent = consent.atRevision(initial.revision);
    final cancel = CancelToken();
    _cancel = cancel;
    busyCaseId = initial.id;
    error = null;
    retryStage = onlyStage;
    retryOptions = {...options};
    retryWorkflow = pass == null &&
        (onlyStage == null || options['resumeWorkflow'] == true);
    _notify();
    try {
      final external = externalFor(consent);
      final result = await CaseAnalysisPipeline(model).run(
          file: initial,
          consent: consent,
          cancel: cancel,
          external: external,
          onlyStage: onlyStage,
          options: options,
          weights: preferences.weights,
          progress: (stage, detail) {
            retryStage = stage;
            if (pass != null)
              retryOptions = {...options, 'resumeAt': stage.name};
            progressTitle = stageTitles[stage]!;
            progressDetail = detail;
            _notify();
          },
          commit: (before, after, stage) async {
            cancel.check();
            await _commit(before, after);
          });
      cancel.check();
      final complete = commands.record(
          result, NodeKind.permission, {...permission.body, 'completed': true},
          origin: EvidenceOrigin.deviceEvent, revisionOf: permission.id);
      await _commit(
          result, commands.append(result, [complete], authorized: external));
    } catch (e) {
      if (!cancel.cancelled) {
        error = e is MirrorProblem ? e.message : '分析没有完成，已有阶段结果已保存';
        final failed = await store.load(initial.id);
        if (failed != null && !cancel.cancelled) {
          final audit = commands.record(
              failed,
              NodeKind.permission,
              {
                ...permission.body,
                'failureCode': e is MirrorProblem ? e.code : 'service_failure',
                'failedStage': retryStage?.name ?? 'unavailable'
              },
              origin: EvidenceOrigin.deviceEvent,
              revisionOf: permission.id);
          await _commit(
              failed,
              commands.append(failed, [audit],
                  authorized: externalFor(consent)));
        }
      }
    } finally {
      if (identical(_cancel, cancel)) {
        _cancel = null;
        busyCaseId = null;
        progressTitle = '';
        progressDetail = '';
      }
      await reconcileReminders();
      _notify();
    }
  }

  Future<void> score(AnalysisConsent consent) async {
    var current = await store.load(consent.caseId);
    if (current == null || current.revision != consent.revision)
      throw const VersionConflict();
    stop();
    final permission = commands.record(
        current,
        NodeKind.permission,
        {
          'purpose': 'scoring',
          'allowedIds': consent.evidenceIds.toList(),
          'sourceCaseIds': consent.sourceCaseIds.toList(),
          'sensitiveAllowed': consent.sensitiveAllowed,
          'granted': true,
          'runId': consent.runId,
          'completed': false
        },
        origin: EvidenceOrigin.deviceEvent);
    final permitted = commands.append(current, [permission],
        authorized: externalFor(consent));
    await _commit(current, permitted);
    current = permitted;
    final cancel = CancelToken();
    _cancel = cancel;
    busyCaseId = current.id;
    progressTitle = '按四维量规核对候选';
    _notify();
    try {
      final nodes = CaseAnalysisPipeline.permittedNodes(
          current, consent, externalFor(consent), {});
      final scoped = current.evolve(nodes: nodes, revision: current.revision);
      final ranking = await decisions.score(scoped, preferences, cancel);
      cancel.check();
      final completed = commands.record(
          current, NodeKind.permission, {...permission.body, 'completed': true},
          origin: EvidenceOrigin.deviceEvent, revisionOf: permission.id);
      await _commit(
          current,
          commands.append(current, [ranking, completed],
              authorized: externalFor(consent)));
    } finally {
      if (identical(_cancel, cancel)) {
        _cancel = null;
        busyCaseId = null;
        progressTitle = '';
      }
      _notify();
    }
  }

  Future<void> updateWeights(List<double> weights, String? caseId) async {
    await savePreferences(preferences.change({'weights': weights}));
    if (caseId != null)
      await mutate(caseId, (f) {
        final old = f.latest(NodeKind.recommendation);
        final facets = <String, List<Json>>{};
        for (final row in old?.objects('allFacets') ?? <Json>[]) {
          facets[row['motiveId'] as String] =
              (row['facets'] as List).map(jsonMap).toList();
        }
        final ranking = MotiveRanking.build(f,
            weights: weights,
            facets: facets,
            method: old?.text('method') ?? 'rules',
            model: old?.text('model') ?? '',
            scoredAt: parseTime(old?.body['scoredAt']) ?? old?.recordedAt,
            expiresAt: parseTime(old?.body['expiresAt']),
            message: '按你调整后的权重重新比较；旧榜单仍保留');
        return commands.append(f, [ranking]);
      });
  }

  Future<void> seal(String id, Json body,
      {bool prediction = true, bool reminderPermission = false}) async {
    await cancelReminders(id);
    await mutate(
        id,
        (f) => commands.sealPlan(f, body,
            sealPrediction: prediction, authorized: authorizedHistory));
    final current = file(id)!;
    final at = parseTime(body['remindAt']);
    if (at == null) return;
    final plan = current.latest(NodeKind.plan)!;
    final trigger = current.latest(NodeKind.trigger)!;
    final jobId =
        0x30000000 + int.parse(digest(trigger.id).substring(0, 6), radix: 16);
    final permitted = reminderPermission && await reminders.requestPermission();
    final link = MirrorLink(
        caseId: id,
        triggerId: trigger.id,
        planId: plan.id,
        principleId: body['principleId'] as String?,
        sceneId: body['sceneId'] as String?,
        runId: current.latest(NodeKind.recommendation)?.id,
        version: current.revision,
        jobId: jobId);
    final ok = permitted && await reminders.schedule(jobId, at, link);
    await mutate(
        id,
        (f) => commands.append(
            f,
            [
              commands.record(
                  f,
                  NodeKind.reminder,
                  {
                    'triggerId': trigger.id,
                    'planId': plan.id,
                    'principleId': body['principleId'],
                    'sceneId': body['sceneId'],
                    'runId': current.latest(NodeKind.recommendation)?.id,
                    'jobId': jobId,
                    'scheduledAt': at.toIso8601String(),
                    'state': ok
                        ? 'scheduled'
                        : permitted
                            ? 'failed'
                            : 'denied',
                    'snapshotVersion': current.revision
                  },
                  origin: EvidenceOrigin.deviceEvent)
            ],
            authorized: authorizedHistory));
  }

  Future<void> verifyTrigger(String id, String state, String detail,
      {DateTime? occurredAt}) async {
    await mutate(
        id,
        (f) =>
            commands.verifyTrigger(f, state, detail, occurredAt: occurredAt));
    if ({'changed', 'expired', 'cancelled'}.contains(state))
      await cancelReminders(id);
  }

  Future<void> recordNode(String id, NodeKind kind, Json body,
      {List<String> evidenceIds = const [],
      List<String> counterIds = const [],
      List<String> links = const [],
      DateTime? happenedAt,
      String? revisionOf,
      TimePhase? phase,
      EvidenceOrigin origin = EvidenceOrigin.selfReport}) async {
    await mutate(id, (f) {
      final updated = commands.append(
          f,
          [
            commands.record(f, kind, body,
                origin: origin,
                status: kind == NodeKind.principle
                    ? NodeStatus.draft
                    : NodeStatus.active,
                evidenceIds: evidenceIds,
                counterIds: counterIds,
                links: links,
                happenedAt: happenedAt,
                knownAt: DateTime.now().toUtc(),
                revisionOf: revisionOf,
                phase: phase)
          ],
          authorized: authorizedHistory);
      if (kind != NodeKind.reappraisal || body['safetyChanged'] != true) {
        return updated;
      }
      return updated.evolve(
          nodes: updated.nodes
              .map((n) => n.episodeId == f.episodeId &&
                      {NodeKind.plan, NodeKind.preflight, NodeKind.scene}
                          .contains(n.kind)
                  ? n.withStatus(NodeStatus.stale)
                  : n)
              .toList());
    });
    if (kind == NodeKind.reappraisal && body['safetyChanged'] == true) {
      await cancelReminders(id);
      await _rerank(id);
    }
    if (kind == NodeKind.principle && revisionOf != null) {
      await reconcileReminders();
    }
  }

  Future<void> observe(String id, Json body, String evidenceText,
      {DateTime? happenedAt}) async {
    await mutate(
        id,
        (f) => commands.observe(f,
            body: body, evidenceText: evidenceText, happenedAt: happenedAt));
    await cancelReminders(id);
  }

  Future<void> reveal(String id) => mutate(id, commands.reveal);
  Future<void> nextEpisode(String id) async {
    await cancelReminders(id);
    await mutate(id, commands.nextEpisode);
  }

  Future<void> retract(String evidenceId) async {
    stop();
    await _queue.catchError((_) {});
    await _cancelAffected({evidenceId});
    await store.retractEvidence({evidenceId});
    await reload();
  }

  Future<void> deleteCase(String id) async {
    stop();
    await _queue.catchError((_) {});
    await _cancelAffected(file(id)?.nodes.map((n) => n.id).toSet() ?? {});
    await cancelReminders(id);
    await store.deleteCase(id);
    preferences = await store.settings();
    await reload();
    await reconcileReminders();
  }

  Future<void> savePreferences(MirrorSettings value) async {
    stop();
    await _queue.catchError((_) {});
    for (final source in preferences.crossCaseIds
        .where((id) => !value.crossCaseIds.contains(id))) {
      await _cancelAffected(file(source)?.nodes.map((n) => n.id).toSet() ?? {},
          preserveSource: source);
      await store.revokeCrossCase(source);
    }
    await store.saveSettings(value);
    preferences = value;
    await reload();
    await reconcileReminders();
  }

  Future<void> _cancelAffected(Set<String> roots,
      {String? preserveSource}) async {
    final affected =
        EvidenceRules.invalidationClosure(files.expand((f) => f.nodes), roots);
    for (final f in files.where((f) => f.id != preserveSource)) {
      for (final n in f.nodes.where(
          (n) => n.kind == NodeKind.reminder && affected.contains(n.id))) {
        final job = n.number('jobId')?.toInt();
        if (job != null) await reminders.cancel(job);
      }
    }
  }

  Future<void> cancelReminders(String id) async {
    final current = await store.load(id);
    if (current == null) return;
    final jobs = current
        .current(NodeKind.reminder, allEpisodes: true)
        .where((n) => n.text('state') == 'scheduled')
        .toList();
    for (final job in jobs) {
      await reminders.cancel(job.number('jobId')!.toInt());
    }
    if (jobs.isEmpty) return;
    final cancelled = jobs
        .map((job) => commands.record(
            current, NodeKind.reminder, {...job.body, 'state': 'cancelled'},
            origin: EvidenceOrigin.deviceEvent, revisionOf: job.id))
        .toList();
    await _commit(current,
        commands.append(current, cancelled, authorized: authorizedHistory));
  }

  Future<void> reconcileReminders() async {
    final pending = await reminders.pending();
    for (final file in [...files]) {
      for (final job in file.current(NodeKind.reminder,
          allEpisodes: true, usableOnly: false)) {
        final id = job.number('jobId')?.toInt();
        if (id == null) continue;
        final plan = file.node(job.text('planId'));
        final route = file.node(plan?.text('routeId'));
        final principleId = plan?.body['principleId'] as String?;
        final principle = principleId == null ? null : resolve(principleId);
        final active = job.usable &&
            job.text('state') == 'scheduled' &&
            plan?.usable == true &&
            route != null &&
            EvidenceRules.routeCanBePrepared(route, file) &&
            (principleId == null ||
                (principle != null &&
                    EvidenceRules.principleCanBePrepared(principle, file,
                        authorized: authorizedHistory))) &&
            file.stage != CaseStage.paused &&
            file.current(NodeKind.observation).isEmpty;
        if (!active) {
          await reminders.cancel(id);
          continue;
        }
        final at = parseTime(job.body['scheduledAt']);
        if (at != null && at.isAfter(DateTime.now()) && !pending.contains(id)) {
          await reminders.schedule(
              id,
              at,
              MirrorLink(
                  caseId: file.id,
                  triggerId: job.text('triggerId'),
                  planId: job.text('planId'),
                  principleId: job.body['principleId'] as String?,
                  runId: job.body['runId'] as String?,
                  sceneId: job.body['sceneId'] as String?,
                  version: job.number('snapshotVersion')?.toInt(),
                  jobId: id));
        }
      }
    }
  }

  Future<bool> openNotification(MirrorLink link) async {
    final current = file(link.caseId);
    if (current == null) return false;
    final plan = current.node(link.planId);
    final trigger = current.node(link.triggerId);
    final route = current.node(plan?.text('routeId'));
    final principleId = plan?.body['principleId'] as String?;
    final principle = principleId == null ? null : resolve(principleId);
    if (plan == null ||
        trigger == null ||
        !plan.usable ||
        !trigger.usable ||
        route == null ||
        !EvidenceRules.routeCanBePrepared(route, current) ||
        (principleId != null &&
            (principle == null ||
                !EvidenceRules.principleCanBePrepared(principle, current,
                    authorized: authorizedHistory))) ||
        current.latest(NodeKind.plan)?.id != plan.id) return false;
    final jobs = current
        .current(NodeKind.reminder, allEpisodes: true)
        .where((n) =>
            n.number('jobId') == link.jobId && n.text('state') == 'scheduled')
        .toList();
    if (jobs.isEmpty) return false;
    final job = jobs.last;
    if (job.number('snapshotVersion') != link.version ||
        job.text('triggerId') != link.triggerId ||
        job.body['principleId'] != link.principleId ||
        job.body['runId'] != link.runId ||
        job.body['sceneId'] != link.sceneId ||
        job.text('planId') != link.planId) return false;
    await recordNode(
        current.id, NodeKind.reminder, {...job.body, 'state': 'opened'},
        revisionOf: job.id, origin: EvidenceOrigin.deviceEvent);
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel?.cancel();
    super.dispose();
  }
}
