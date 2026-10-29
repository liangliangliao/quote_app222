import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/ai/pipeline.dart';
import 'package:quote_app/will_mirror/ai/protocol.dart';
import 'package:quote_app/will_mirror/domain/model.dart';

import 'ai_contract_test.dart' show FunctionModel, grant, inputOf, row;
import 'fixtures.dart';
import 'regression_v28_test.dart' show insightBody;
import 'clarity_workbench_test.dart' show understanding;

CaseFile linkedUnderstanding({bool includePrivateSource = false}) {
  var f = newCase('我想练习一项新技能，但担心一次失败就证明我没有能力。');
  final root = f.nodes.first.id;
  final uId = newId('understanding'), bId = newId('belief');
  final private = commands.record(f, NodeKind.evidence, {
    ...f.nodes.first.body,
    'text': 'PRIVATE_UNSELECTED',
    'sensitive': true,
  });
  if (includePrivateSource) f = commands.append(f, [private]);
  final u = commands.record(
      f,
      NodeKind.understanding,
      {
        'summary': '你想学习，却把一次表现当成了对能力的总判断。',
        'facts': [
          {
            'claim': f.issue,
            'quote': f.issue,
            'evidenceIds': [root]
          }
        ],
        'unknowns': ['想练习的具体技能'],
        'keyQuestion': '你最想先学会什么？',
        'domains': ['学习'],
        'riskFlags': <String>[],
        'timeContext': 'future',
      },
      id: uId,
      evidenceIds: [root],
      links: [bId],
      origin: EvidenceOrigin.aiHypothesis,
      status: NodeStatus.draft);
  final b = commands.record(
      f,
      NodeKind.belief,
      {
        'claim': '失败一次就证明我没有能力',
        'kind': 'prediction',
        'realityStatus': 'hypothesized',
        'confidence': null,
        'awareness': 'known_before',
        'influence': 'unknown',
        'verify': '区分一次练习反馈和能力总判断',
      },
      id: bId,
      evidenceIds: [root, if (includePrivateSource) private.id],
      links: [uId],
      origin: EvidenceOrigin.aiHypothesis,
      status: NodeStatus.draft);
  return commands.append(f, [u, b]);
}

void main() {
  test(
      'an invented source is repaired against actual allowed IDs without being silently dropped',
      () async {
    final f = prepared();
    var calls = 0, commits = 0;
    final model = FunctionModel((stage, prompt, schema) async {
      calls++;
      final input = inputOf(prompt);
      expect(input['allowedReferenceIds'], contains(f.nodes.first.id));
      return {
        'records': [
          row(
              commands.record(f, NodeKind.route, route(f).body, evidenceIds: [
                calls == 1 ? 'run_missing_0_3' : f.nodes.first.id
              ]),
              '${input['idPrefix']}r')
        ],
        'summary': '可先整理一个问题',
        'unknowns': ['其他路线待核实']
      };
    });
    final result = await CaseAnalysisPipeline(model).run(
        file: f,
        consent: grant(f),
        cancel: CancelToken(),
        onlyStage: AnalysisStage.options,
        commit: (_, __, ___) async {
          commits++;
        },
        progress: (_, __) {});
    expect(calls, 2);
    expect(commits, 1);
    expect(result.latest(NodeKind.route)!.evidenceIds, [f.nodes.first.id]);
  });

  test(
      'JSON formatting may be repaired once but service/authentication failures are not regenerated',
      () async {
    final f = prepared();
    var requests = 0;
    final model = FunctionModel((stage, prompt, schema) async {
      requests++;
      if (requests == 1) return parseStructured('{"records":');
      final input = inputOf(prompt);
      return {
        'records': [row(route(f), '${input['idPrefix']}r')],
        'summary': '先整理问题',
        'unknowns': ['其他走法仍待核实']
      };
    });
    await CaseAnalysisPipeline(model).run(
        file: f,
        consent: grant(f),
        cancel: CancelToken(),
        onlyStage: AnalysisStage.options,
        commit: (_, __, ___) async {},
        progress: (_, __) {});
    expect(model.calls, 2);
    final unavailable = FunctionModel((_, __, ___) async =>
        throw const MirrorProblem('服务鉴权不可用',
            code: 'provider_auth_unavailable'));
    await expectLater(
        CaseAnalysisPipeline(unavailable).run(
            file: f,
            consent: grant(f),
            cancel: CancelToken(),
            onlyStage: AnalysisStage.options,
            commit: (_, __, ___) async {},
            progress: (_, __) {}),
        throwsA(isA<MirrorProblem>()));
    expect(unavailable.calls, 1);
  });

  test(
      'new workbench responses must add a useful angle and small step, not just extracted facts',
      () async {
    final f = newCase('我想学一项新技能，但害怕失败。');
    var generated = 0;
    final model = FunctionModel((stage, prompt, schema) async {
      generated++;
      final input = inputOf(prompt);
      return {
        'records': [
          row(understanding(f, withClarity: generated > 1),
              '${input['idPrefix']}u')
        ],
        'summary': '先把这件事说清楚',
        'unknowns': <String>[]
      };
    });
    final result = await CaseAnalysisPipeline(model).run(
        file: f,
        consent: grant(f),
        cancel: CancelToken(),
        onlyStage: AnalysisStage.understand,
        options: {'requireClarity': true},
        commit: (_, __, ___) async {},
        progress: (_, __) {});
    expect(generated, 2);
    expect(result.latest(NodeKind.understanding)!.object('clarity')['nextStep'],
        isNotEmpty);
  });

  test(
      'a connected-looking group without any granted source cannot self-authorize',
      () {
    final base = linkedUnderstanding();
    final pair = base.nodes
        .where(
            (n) => {NodeKind.understanding, NodeKind.belief}.contains(n.kind))
        .toList();
    MirrorNode noSource(MirrorNode n) => MirrorNode(
        id: n.id,
        caseId: n.caseId,
        episodeId: n.episodeId,
        kind: n.kind,
        origin: n.origin,
        phase: n.phase,
        recordedAt: n.recordedAt,
        body: {
          ...n.body,
          if (n.kind == NodeKind.understanding) 'facts': <Json>[]
        },
        links: n.links,
        status: n.status);
    final f = base.evolve(nodes: [base.nodes.first, ...pair.map(noSource)]);
    final allowed = CaseAnalysisPipeline.permittedNodes(f, grant(f), {}, {});
    expect(allowed.map((n) => n.id), [base.nodes.first.id]);
  });

  test(
      'a repaired review that reports an actual problem still rejects the first advice',
      () async {
    var f = prepared();
    f = commands.observe(f, body: observationBody(f), evidenceText: '真实询问资料');
    var generations = 0, reviews = 0;
    final committed = <CaseFile>[];
    final model = FunctionModel((stage, prompt, schema) async {
      if ((schema['properties'] as Map).containsKey('violations')) {
        reviews++;
        return {
          'violations': reviews == 1
              ? ['不安全劝导']
              : reviews == 2
                  ? ['unsafe_persuasion']
                  : <String>[]
        };
      }
      generations++;
      final input = inputOf(prompt);
      return {
        'records': [
          row(
              commands.record(f, NodeKind.insight,
                  {...insightBody(), 'claim': '第 $generations 次重新核对的经验'},
                  evidenceIds: [f.latest(NodeKind.observation)!.id]),
              '${input['idPrefix']}i')
        ],
        'summary': '经验有条件成立',
        'unknowns': ['还需实践']
      };
    });
    final result = await CaseAnalysisPipeline(model).run(
        file: f,
        consent: grant(f),
        cancel: CancelToken(),
        onlyStage: AnalysisStage.learning,
        commit: (_, after, __) async {
          committed.add(after);
        },
        progress: (_, __) {});
    expect(generations, 2);
    expect(reviews, 3);
    expect(committed, hasLength(1));
    expect(result.latest(NodeKind.insight)!.text('claim'), '第 2 次重新核对的经验');
  });
  test(
      'a new pass retains mutually linked analysis when all real sources are granted',
      () async {
    final f = linkedUnderstanding();
    final belief = f.latest(NodeKind.belief)!;
    final visible = CaseAnalysisPipeline.permittedNodes(f, grant(f), {}, {});
    expect(visible.map((n) => n.id),
        containsAll([belief.id, f.latest(NodeKind.understanding)!.id]));
    final model = FunctionModel((stage, prompt, schema) async {
      final input = inputOf(prompt);
      final candidate = commands.record(f, NodeKind.route, route(f).body,
          evidenceIds: [belief.id],
          origin: EvidenceOrigin.aiHypothesis,
          status: NodeStatus.draft);
      return {
        'records': [row(candidate, '${input['idPrefix']}route')],
        'summary': '先把练习目标拆小',
        'unknowns': ['具体技能尚待说明']
      };
    });
    final result = await CaseAnalysisPipeline(model).run(
      file: f,
      consent: grant(f),
      cancel: CancelToken(),
      onlyStage: AnalysisStage.options,
      commit: (_, after, __) async {},
      progress: (_, __) {},
    );
    expect(result.latest(NodeKind.route)!.evidenceIds, [belief.id]);
  });

  test('a mutually linked group cannot conceal a private or withdrawn source',
      () {
    final f = linkedUnderstanding(includePrivateSource: true);
    final visible = CaseAnalysisPipeline.permittedNodes(
        f, grant(f, ids: {f.nodes.first.id}), {}, {});
    expect(
        visible.where(
            (n) => {NodeKind.understanding, NodeKind.belief}.contains(n.kind)),
        isEmpty);
    expect(visible.any((n) => n.text('text') == 'PRIVATE_UNSELECTED'), isFalse);
  });

  test(
      'malformed review is repaired without regenerating the already valid advice',
      () async {
    var f = prepared();
    f = commands.observe(f, body: observationBody(f), evidenceText: '真实发出了询问');
    var generated = 0, reviewed = 0, committed = 0;
    final model = FunctionModel((stage, prompt, schema) async {
      if ((schema['properties'] as Map).containsKey('violations')) {
        reviewed++;
        return {
          'violations': reviewed == 1 ? ['无违规'] : <String>[]
        };
      }
      generated++;
      final input = inputOf(prompt);
      final insight = commands.record(f, NodeKind.insight, insightBody(),
          evidenceIds: [f.latest(NodeKind.observation)!.id]);
      return {
        'records': [row(insight, '${input['idPrefix']}insight')],
        'summary': '这一次先核实资料提供了可用信息',
        'unknowns': ['其他情境仍需观察']
      };
    });
    await CaseAnalysisPipeline(model).run(
        file: f,
        consent: grant(f),
        cancel: CancelToken(),
        onlyStage: AnalysisStage.learning,
        commit: (_, __, ___) async {
          committed++;
        },
        progress: (_, __) {});
    expect(generated, 1);
    expect(reviewed, 2);
    expect(committed, 1);
  });

  test('unreadable review stays untrusted and has a bounded format repair',
      () async {
    var f = prepared();
    f = commands.observe(f, body: observationBody(f), evidenceText: '真实发出了询问');
    var generated = 0, reviewed = 0, committed = 0;
    final model = FunctionModel((stage, prompt, schema) async {
      if ((schema['properties'] as Map).containsKey('violations')) {
        reviewed++;
        return {
          'violations': ['无法映射的自由文本']
        };
      }
      generated++;
      final input = inputOf(prompt);
      return {
        'records': [
          row(
              commands.record(f, NodeKind.insight, insightBody(),
                  evidenceIds: [f.latest(NodeKind.observation)!.id]),
              '${input['idPrefix']}i')
        ],
        'summary': '候选',
        'unknowns': ['需要核实']
      };
    });
    await expectLater(
        CaseAnalysisPipeline(model).run(
            file: f,
            consent: grant(f),
            cancel: CancelToken(),
            onlyStage: AnalysisStage.learning,
            commit: (_, __, ___) async {
              committed++;
            },
            progress: (_, __) {}),
        throwsA(isA<MirrorProblem>().having(
            (p) => p.code, 'format failure', 'quality_format_invalid')));
    expect(generated, 1);
    expect(reviewed, 2);
    expect(committed, 0);
  });
}
