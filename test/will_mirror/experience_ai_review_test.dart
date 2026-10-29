import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/ai/pipeline.dart';
import 'package:quote_app/will_mirror/ai/protocol.dart';
import 'package:quote_app/will_mirror/domain/model.dart';

import 'ai_contract_test.dart' show FunctionModel, grant, inputOf, row;
import 'fixtures.dart';
import 'intent_workbench_test.dart' show fitBody;

void main() {
  for (final violation in [
    'fatalistic_acceptance',
    'unsupported_obligation',
    'principle_conflict'
  ]) {
    test(
        'T342 T354 T357: $violation fails closed before practical advice commits',
        () async {
      final f = prepared();
      var audits = 0, commits = 0;
      final model = FunctionModel((stage, prompt, schema) async {
        if ((schema['properties'] as Map).containsKey('violations')) {
          audits++;
          return {
            'violations': [violation]
          };
        }
        final input = inputOf(prompt);
        final fit =
            commands.record(f, NodeKind.routeFit, fitBody(f.selectedRouteId!));
        final boundary = commands.record(f, NodeKind.boundaryReview, {
          'ownActions': ['把不公当作自己必须接受的命运'],
          'otherAutonomy': ['对方永远不会改变'],
          'verifiedObligations': <String>[],
          'unknownObligations': <String>[],
          'safeOptions': ['放弃求助并忍受'],
          'riskGate': 'clear',
          'nextVerification': '不再核实',
        }, evidenceIds: [
          f.nodes.first.id
        ]);
        return {
          'records': [
            row(fit, '${input['idPrefix']}fit'),
            row(boundary, '${input['idPrefix']}boundary')
          ],
          'summary': '不合格的建议',
          'unknowns': <String>[],
        };
      });
      await expectLater(
          CaseAnalysisPipeline(model).run(
            file: f,
            consent: grant(f),
            cancel: CancelToken(),
            onlyStage: AnalysisStage.routeAssessment,
            commit: (before, after, stage) async {
              commits++;
            },
            progress: (stage, detail) {},
          ),
          throwsA(isA<MirrorProblem>()
              .having((p) => p.code, 'safe rejection', 'quality_rejected')));
      expect(audits, 2);
      expect(commits, 0);
      expect(f.current(NodeKind.boundaryReview), isEmpty);
    });
  }
}
