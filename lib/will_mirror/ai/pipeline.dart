import 'dart:convert';

import '../domain/model.dart';
import '../domain/ranking.dart';
import '../domain/rules.dart';
import '../domain/schema.dart';
import 'protocol.dart';
import 'workbench_pass.dart';

typedef StageCommit = Future<void> Function(
    CaseFile before, CaseFile after, AnalysisStage stage);
typedef StageProgress = void Function(AnalysisStage stage, String detail);

class CaseAnalysisPipeline {
  CaseAnalysisPipeline(this.model);
  final StructuredModel model;

  /// Only explicitly selected facts and derivatives whose roots are inside the
  /// grant may enter a request. The issue/title is not separately appended.
  static List<MirrorNode> permittedNodes(CaseFile file, AnalysisConsent consent,
      Map<String, MirrorNode> external, Set<String> generated) {
    final candidates = [...file.nodes, ...external.values];
    final allowed = <String, MirrorNode>{};
    for (final node in candidates) {
      if (!node.usable) continue;
      final inCase = node.caseId == file.id;
      if (!inCase && !consent.sourceCaseIds.contains(node.caseId)) continue;
      if ((node.kind == NodeKind.evidence ||
              node.kind == NodeKind.capability) &&
          node.flag('sensitive') &&
          !consent.sensitiveAllowed) continue;
      if (consent.evidenceIds.contains(node.id)) allowed[node.id] = node;
    }
    var changed = true;
    while (changed) {
      changed = false;
      for (final node in candidates) {
        const derived = {
          NodeKind.seal,
          NodeKind.deliberation,
          NodeKind.graphShift,
          NodeKind.recommendation,
          NodeKind.principleApplication
        };
        if (allowed.containsKey(node.id) ||
            !node.usable ||
            (!analyticalKinds.contains(node.kind) &&
                !derived.contains(node.kind))) continue;
        if (node.caseId != file.id &&
            !consent.sourceCaseIds.contains(node.caseId)) continue;
        if (node.flag('sensitive') && !consent.sensitiveAllowed) continue;
        if (node.dependencies.isNotEmpty &&
                node.dependencies.every(allowed.containsKey) ||
            generated.contains(node.id)) {
          // Generated nodes passed strict permission-aware validation already.
          allowed[node.id] = node;
          changed = true;
        }
      }
    }
    return allowed.values.toList();
  }

  Future<CaseFile> run(
      {required CaseFile file,
      required AnalysisConsent consent,
      required CancelToken cancel,
      required StageCommit commit,
      required StageProgress progress,
      Map<String, MirrorNode> external = const {},
      AnalysisStage? onlyStage,
      Json options = const {},
      List<double> weights = const [0.35, 0.25, 0.25, 0.15]}) async {
    if (consent.caseId != file.id || consent.revision != file.revision)
      throw const VersionConflict();
    if (consent.evidenceIds.isEmpty)
      throw const MirrorProblem('请至少选择一条允许本次分析的资料');
    if (!await model.available())
      throw const MirrorProblem('尚未配置 AI 服务；课题已在本地保存');
    var current = file;
    final generated = <String>{};
    final workflow = [
      AnalysisStage.understand,
      AnalysisStage.wants,
      AnalysisStage.options,
      AnalysisStage.motives,
      AnalysisStage.cognition,
      AnalysisStage.challenge,
      AnalysisStage.routeAssessment
    ];
    final pass = requestedPass(options);
    final stages = pass ??
        (options['resumeWorkflow'] == true && workflow.contains(onlyStage)
            ? workflow.skipWhile((s) => s != onlyStage).toList()
            : onlyStage == null
                ? [
                    AnalysisStage.understand,
                    AnalysisStage.wants,
                    AnalysisStage.options,
                    AnalysisStage.motives,
                    AnalysisStage.cognition,
                    AnalysisStage.challenge,
                    AnalysisStage.routeAssessment,
                  ]
                : onlyStage == AnalysisStage.review
                    ? [AnalysisStage.review, AnalysisStage.learning]
                    : [onlyStage]);
    // A previously complete pool must be re-examined after new facts. Reaching
    // fifty earlier is not evidence that its old route directions remain valid.
    if (pass == null &&
        (onlyStage == null || options['resumeWorkflow'] == true) &&
        file.current(NodeKind.motive).length >= 50) {
      stages.add(AnalysisStage.reappraise);
    }
    var sequence = 0;
    for (final stage in stages) {
      if (pass != null &&
          stage == AnalysisStage.options &&
          current.current(NodeKind.route).isNotEmpty &&
          !current
              .current(NodeKind.route)
              .any((r) => EvidenceRules.routeNeedsReview(r, current))) continue;
      var batch = 0;
      // Commit one route's matrix at a time to avoid truncating the combined
      // six-route, multi-want response at the provider's output limit.
      final assessmentRoutes = stage == AnalysisStage.routeAssessment
          ? current.current(NodeKind.route)
          : <MirrorNode>[];
      if (stage == AnalysisStage.routeAssessment && assessmentRoutes.isEmpty)
        throw const MirrorProblem('先生成或填写一条实际走法，再比较路线条件');
      do {
        cancel.check();
        final pool = MotiveRanking.distinct(current.current(NodeKind.motive));
        if (stage == AnalysisStage.motives && pool.length >= 50) break;
        progress(
            stage,
            stage == AnalysisStage.motives
                ? '已整理 ${pool.length} 条不同理由，正在补全第 ${batch + 1} 批'
                : stage == AnalysisStage.routeAssessment
                    ? '正在比较第 ${batch + 1}/${assessmentRoutes.length} 条走法：${assessmentRoutes[batch].text('title')}'
                    : '正在核对来源、条件和反证');
        final visible = permittedNodes(current, consent, external, generated);
        final scoped =
            current.evolve(nodes: visible, revision: current.revision);
        final prefix = '${consent.runId}_${sequence++}_';
        final data = {
          'caseId': current.id,
          'episodeId': current.episodeId,
          'phase': current.phase.name,
          'asOf': consent.grantedAt.toUtc().toIso8601String(),
          'idPrefix': prefix,
          'selectedRouteId': current.selectedRouteId,
          'selectedMotiveIds': current.selectedMotiveIds,
          'currentRouteIds':
              scoped.current(NodeKind.route).map((n) => n.id).toList(),
          'currentMotiveIds':
              scoped.current(NodeKind.motive).map((n) => n.id).toList(),
          'records': visible.map((n) => n.toJson()).toList(),
          'options': {
            ...options,
            if (stage == AnalysisStage.routeAssessment)
              'assessmentRouteId': assessmentRoutes[batch].id,
          },
          if (stage == AnalysisStage.cognition) 'theory': theoryCards,
        };
        final prompt =
            '${taskFor(stage, batch: batch)}\n\n允许的结构：${jsonEncode(stageSchema(stage))}\n\n本次授权数据：${canonicalJson(data)}';
        List<MirrorNode> records = const [];
        String summary = '';
        String? repairHint;
        // One schema-repair attempt only; no unbounded generation or auto billing loops.
        for (var attempt = 0; attempt < 2; attempt++) {
          cancel.check();
          final result = await model.complete(
              stage: stage,
              system: systemProtocol,
              prompt: repairHint == null
                  ? prompt
                  : '$prompt\n上次输出未通过校验，请重新给出当前阶段完整JSON。原因：$repairHint',
              schema: stageSchema(stage),
              cancel: cancel);
          cancel.check();
          try {
            if (result.keys.toSet().difference(
                    {'records', 'summary', 'unknowns'}).isNotEmpty ||
                result['records'] is! List ||
                result['summary'] is! String ||
                result['unknowns'] is! List)
              throw const MirrorProblem('顶层字段不完整');
            final now = DateTime.now().toUtc();
            final output = result['records'] as List;
            if (output.length > 100) throw const MirrorProblem('单次输出记录过多');
            records = output.map((raw) {
              final row = jsonMap(raw);
              validateShape(row, {
                'id': 'text',
                'kind': 'text',
                'body': 'json',
                'evidenceIds': ['text'],
                'counterIds': ['text'],
                'links': ['text'],
                'revisionOf': 'text?'
              });
              if (!(row['id'] as String).startsWith(prefix))
                throw const MirrorProblem('新记录标识没有使用当前运行前缀');
              final kind = NodeKind.values.byName(row['kind'] as String);
              return MirrorNode(
                  id: row['id'] as String,
                  caseId: current.id,
                  episodeId: current.episodeId,
                  kind: kind,
                  origin: EvidenceOrigin.aiHypothesis,
                  phase: current.phase,
                  recordedAt: now,
                  knownAt: now,
                  body: jsonMap(row['body']),
                  evidenceIds: stringList(row['evidenceIds']),
                  counterIds: stringList(row['counterIds']),
                  links: stringList(row['links']),
                  status: NodeStatus.draft,
                  revisionOf: row['revisionOf'] as String?);
            }).toList();
            EvidenceRules.validateBatch(scoped, records,
                modelOutput: true,
                allowedKinds: stageKinds[stage],
                snapshotAt: now);
            _stageRequirements(
                stage, records, scoped, stringList(result['unknowns']));
            final liveRoutes =
                scoped.current(NodeKind.route).map((n) => n.id).toSet();
            if (records.where((n) => n.kind == NodeKind.motive).any((n) => n
                .objects('directionByRoute')
                .any((r) => !liveRoutes.contains(r['routeId']))))
              throw const MirrorProblem('新动机必须引用 currentRouteIds 中的当前路线版本');
            if (stage == AnalysisStage.routeAssessment) {
              final fits =
                  records.where((n) => n.kind == NodeKind.routeFit).toList();
              if (fits.length != 1 ||
                  fits.single.text('routeId') != assessmentRoutes[batch].id)
                throw const MirrorProblem('本次需只评估指定的一条路线；信息不足时各判断保留未知');
              final prior = scoped
                  .current(NodeKind.routeFit)
                  .where((n) => n.text('routeId') == assessmentRoutes[batch].id)
                  .lastOrNull;
              if (prior != null && fits.single.revisionOf != prior.id)
                throw MirrorProblem(
                    '请用 revisionOf=${prior.id} 修订此路线已有的评估，不能并列追加');
            }
            if ({AnalysisStage.scene, AnalysisStage.learning}.contains(stage)) {
              await _qualityReview(stage, records, visible, cancel);
            }
            summary = result['summary'] as String;
            break;
          } on MirrorProblem catch (error) {
            if (attempt == 1) rethrow;
            repairHint = error.message;
          } on ArgumentError {
            if (attempt == 1) throw const MirrorProblem('模型返回了未知记录类型');
            repairHint = '未知的记录类型';
          }
        }
        cancel.check();
        var semanticRemoved = <String>{};
        if (stage == AnalysisStage.motives) {
          final existing =
              MotiveRanking.distinct(current.current(NodeKind.motive));
          final accepted = <MirrorNode>[];
          final rejectedIds = <String>{};
          for (final node in records.where((n) => n.kind == NodeKind.motive)) {
            if (existing.any((p) => MotiveRanking.similar(p, node)) ||
                accepted.any((p) => MotiveRanking.similar(p, node)) ||
                existing.length + accepted.length >= 70) {
              rejectedIds.add(node.id);
            } else {
              accepted.add(node);
            }
          }
          final dependent =
              EvidenceRules.invalidationClosure(records, rejectedIds);
          records = records.where((n) => !dependent.contains(n.id)).toList();
          final currentMotiveIds =
              current.current(NodeKind.motive).map((n) => n.id).toSet();
          final auditPool = [
            ...permittedNodes(current, consent, external, generated).where(
                (n) =>
                    n.kind == NodeKind.motive &&
                    currentMotiveIds.contains(n.id)),
            ...records.where((n) => n.kind == NodeKind.motive),
          ];
          progress(stage, '正在独立检查理由的语义差异，合并换一种说法的重复理由');
          semanticRemoved = await _semanticDuplicates(auditPool, cancel);
          final duplicated = EvidenceRules.invalidationClosure(
              [...current.nodes, ...records], semanticRemoved);
          records = records.where((n) => !duplicated.contains(n.id)).toList();
          semanticRemoved = duplicated;
        }
        var next = current.evolve(
            nodes: [
              ...current.nodes.map((n) => semanticRemoved.contains(n.id)
                  ? n.withStatus(NodeStatus.stale)
                  : n),
              ...records
            ],
            stage:
                stage == AnalysisStage.understand ? CaseStage.understood : null,
            analysisMessage: summary);
        if (stage == AnalysisStage.challenge) {
          // A rejected old interpretation cannot stay actionable under a new label.
          final replaced =
              records.map((r) => r.revisionOf).whereType<String>().toSet();
          final dependent =
              EvidenceRules.invalidationClosure(current.nodes, replaced);
          next = next.evolve(
              nodes: next.nodes
                  .map((n) => dependent.contains(n.id)
                      ? n.withStatus(NodeStatus.stale)
                      : n)
                  .toList());
        }
        if (stage == AnalysisStage.reappraise) {
          final commands = CaseCommands();
          final kinds = {
            NodeKind.graphEdge,
            NodeKind.motive,
            NodeKind.routeFit
          };
          final beforeNodes = current.nodes
              .where((n) => n.usable && kinds.contains(n.kind))
              .toList();
          final changed = records.where((n) => kinds.contains(n.kind)).toList();
          final before = commands.record(
              next,
              NodeKind.deliberation,
              {
                'label': '重新审议前的理由关系',
                'nodeIds': beforeNodes.map((n) => n.id).toList(),
                'unknowns': <String>[],
                'endorsedIds': current.selectedMotiveIds,
                'snapshot': {
                  'nodes': beforeNodes.map((n) => n.toJson()).toList()
                }
              },
              origin: EvidenceOrigin.productRule);
          final after = commands.record(
              next,
              NodeKind.deliberation,
              {
                'label': '新认识与事实后的理由关系',
                'nodeIds': changed.map((n) => n.id).toList(),
                'unknowns': <String>[],
                'endorsedIds': current.selectedMotiveIds,
                'snapshot': {'nodes': changed.map((n) => n.toJson()).toList()}
              },
              origin: EvidenceOrigin.productRule);
          final shift = commands.record(
              next,
              NodeKind.graphShift,
              {
                'beforeId': before.id,
                'afterId': after.id,
                'addedIds': changed
                    .where((n) => n.revisionOf == null)
                    .map((n) => n.id)
                    .toList(),
                'removedIds': <String>[],
                'changedIds': changed
                    .where((n) => n.revisionOf != null)
                    .map((n) => n.id)
                    .toList(),
                'reason': summary.isEmpty ? '本次未发现可证实的关系变化' : summary,
                'nextTest': '将新的条件性判断与下一次实际观察对照'
              },
              origin: EvidenceOrigin.productRule);
          next = commands.append(next, [before, after, shift],
              authorized: external);
        }
        final activeRoutes =
            next.current(NodeKind.route).map((n) => n.id).toSet();
        final activeMotives =
            next.current(NodeKind.motive).map((n) => n.id).toSet();
        if ((next.selectedRouteId != null &&
                !activeRoutes.contains(next.selectedRouteId)) ||
            next.selectedMotiveIds.any((id) => !activeMotives.contains(id))) {
          next = next.evolve(
              clearRoute: next.selectedRouteId != null &&
                  !activeRoutes.contains(next.selectedRouteId),
              selectedMotiveIds:
                  next.selectedMotiveIds.where(activeMotives.contains).toList(),
              revision: next.revision);
        }
        await commit(current, next, stage);
        current = next;
        generated.addAll(records.map((n) => n.id));
        batch++;
      } while ((stage == AnalysisStage.motives && batch < 4) ||
          (stage == AnalysisStage.routeAssessment &&
              batch < assessmentRoutes.length));
    }
    if ((pass == null && onlyStage == null) ||
        pass?.contains(AnalysisStage.motives) == true ||
        options['resumeWorkflow'] == true ||
        onlyStage == AnalysisStage.motives ||
        onlyStage == AnalysisStage.reappraise) {
      cancel.check();
      final visible = permittedNodes(current, consent, external, generated);
      final rankedFile =
          current.evolve(nodes: visible, revision: current.revision);
      final count =
          MotiveRanking.distinct(current.current(NodeKind.motive)).length;
      final message = count < 50
          ? '本次得到 $count 条不同候选，尚未达到 50 条；已保留真实缺口，可补充事实后继续。'
          : '已整理 $count 条不同候选；默认先看最值得审议的几条。';
      final ranking =
          MotiveRanking.build(rankedFile, weights: weights, message: message);
      final next = current
          .evolve(nodes: [...current.nodes, ranking], analysisMessage: message);
      await commit(current, next, AnalysisStage.motives);
      current = next;
    }
    return current;
  }

  Future<Set<String>> _semanticDuplicates(
      List<MirrorNode> pool, CancelToken cancel) async {
    if (pool.length < 2) return {};
    final schema = jsonSchema({
      'items': [
        {'id': 'text', 'duplicateOf': 'text?', 'reason': 'text'}
      ]
    });
    final response = await model.complete(
        stage: AnalysisStage.motives,
        system: systemProtocol,
        prompt:
            '这是独立语义审查，不生成新动机。逐条比较核心欲求、作用机制、对象、条件、时域及路线方向。仅措辞变化应合并；同一句话在不同条件或正反方向下可能独立。不能为凑数量宣称不同。每个 ID 恰好输出一次；不同理由 duplicateOf=null，重复理由指向保留的唯一理由 ID。优先保留已认可或更早版本，已认可理由不得移除。说明具体差异或重复机制。只返回所给结构。\n${canonicalJson(pool.map((n) => {
                  'id': n.id,
                  'body': n.body,
                  'status': n.status.name
                }).toList())}',
        schema: schema,
        cancel: cancel);
    cancel.check();
    validateShape(response, {
      'items': [
        {'id': 'text', 'duplicateOf': 'text?', 'reason': 'text'}
      ]
    });
    final rows = (response['items'] as List).map(jsonMap).toList();
    final expected = pool.map((n) => n.id).toSet();
    if (rows.length != expected.length ||
        rows.map((n) => n['id']).toSet().length != expected.length ||
        rows.any((n) => !expected.contains(n['id'])))
      throw const MirrorProblem('语义检查没有覆盖全部候选，未宣称已完成去重');
    final removed = <String>{
      for (final row in rows)
        if (row['duplicateOf'] != null) row['id'] as String
    };
    for (final row in rows.where((r) => r['duplicateOf'] != null)) {
      if (!expected.contains(row['duplicateOf']) ||
          removed.contains(row['duplicateOf']) ||
          pool.any((n) => n.id == row['id'] && n.status == NodeStatus.accepted))
        throw const MirrorProblem('语义合并关系无效，已保留原始候选');
    }
    return removed;
  }

  Future<void> _qualityReview(AnalysisStage stage, List<MirrorNode> records,
      List<MirrorNode> sources, CancelToken cancel) async {
    if (records.isEmpty) return;
    final shape = {
      'violations': [
        'enum:invented_fact,coercion_or_shame,unsafe_persuasion,permanent_label,temporal_backfill,unsupported_cause,source_mismatch'
      ]
    };
    final result = await model.complete(
        stage: stage,
        system: systemProtocol,
        prompt:
            '独立质量复核，不改写记录。逐条对照授权来源与时间。检查是否编造事实/金额/他人话语、以羞耻恐惧胁迫、绕过现实安全/他人同意、作永久人格断言、倒填时点、把先后当必要因果、引用不支持的来源。允许忠实引用用户原话与有明确假想标签的自愿想象；不能误判为事实宣称。只返回 violations，确无这些违规时为空。\n${canonicalJson({
              'proposed': records.map((n) => n.toJson()).toList(),
              'sources': sources.map((n) => n.toJson()).toList()
            })}',
        schema: jsonSchema(shape),
        cancel: cancel);
    cancel.check();
    validateShape(result, shape);
    if (stringList(result['violations']).isNotEmpty)
      throw MirrorProblem('内容未通过事实与自主性复核，未进入预演或个人原则。需要重新检查事实、时间、因果和个人自主。',
          code: 'quality_rejected');
  }

  void _stageRequirements(AnalysisStage stage, List<MirrorNode> nodes,
      CaseFile file, List<String> unknowns) {
    int count(NodeKind kind) => nodes.where((n) => n.kind == kind).length;
    for (final kind in [NodeKind.want, NodeKind.route]) {
      final replacements = nodes
          .where((n) => n.kind == kind)
          .map((n) => n.revisionOf)
          .whereType<String>()
          .toSet();
      final remaining =
          file.current(kind).where((n) => !replacements.contains(n.id)).length;
      if (count(kind) > 0 && count(kind) + remaining > 6) {
        throw const MirrorProblem(
            '更新后最多保留六个当前欲求或路线；请用 revisionOf 修订原对象，不重复追加同一阶段');
      }
    }
    if (stage == AnalysisStage.understand && count(NodeKind.understanding) != 1)
      throw const MirrorProblem('理解阶段需要一份事实与未知摘要');
    if (stage == AnalysisStage.wants &&
        ((count(NodeKind.want) < 2 && unknowns.isEmpty) ||
            count(NodeKind.want) > 6))
      throw const MirrorProblem('欲求候选过多，需保留关键差异');
    if (stage == AnalysisStage.options &&
        ((count(NodeKind.route) < 3 && unknowns.isEmpty) ||
            count(NodeKind.route) > 6))
      throw const MirrorProblem('路线超过六条，应先去重');
    if (stage == AnalysisStage.learning && count(NodeKind.principle) > 3)
      throw const MirrorProblem('原则候选最多三条');
    if (stage == AnalysisStage.cognition) {
      final reframes = nodes.where((n) => n.kind == NodeKind.reframe).toList();
      if (reframes.length > 6 ||
          reframes.map((n) => n.text('operator')).toSet().length > 3)
        throw const MirrorProblem('应选择少数相关的认知转换方法');
      const allowed = {
        'schopenhauer_55',
        'james_26',
        'product_evidence',
        'positive_psychology'
      };
      if (reframes
          .any((n) => n.strings('theoryRefs').any((r) => !allowed.contains(r))))
        throw const MirrorProblem('理论来源没有经过登记');
    }
    if (stage == AnalysisStage.prepare && count(NodeKind.preflight) != 1)
      throw const MirrorProblem('准备阶段需要一份条件性预案');
    if (stage == AnalysisStage.scene && count(NodeKind.scene) != 1)
      throw const MirrorProblem('预演阶段需要一份可跳过的脚本');
    if (stage == AnalysisStage.review && count(NodeKind.review) != 1)
      throw const MirrorProblem('复盘阶段需要一份事实对照');
  }
}
