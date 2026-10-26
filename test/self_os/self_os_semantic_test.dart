import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_v37_ai.dart';
import 'semantic/harness.dart';

void main() {
  test('A40/A47：自然语言验收集覆盖十七族、指定跨域与三种变体，题目不含参考答案', () async {
    final corpus = loadSemanticCorpus();
    final families = osMaps(corpus['families']);
    expect(families, hasLength(17));
    expect(families.where((f) => f['task'] == 'gmrc'), hasLength(7));
    expect(families.where((f) => f['task'] == 'horizon'), hasLength(6));
    for (final f in families) {
      expect(osMaps(f['cases']).map((c) => c['domain']).toSet().length,
          greaterThanOrEqualTo(3));
    }
    expect(
        osMaps(families.firstWhere((f) => f['id'] == 'multi_order')['cases'])
            .map((c) => c['domain']),
        containsAll(['工作', '消费', '健康', '学习']));
    expect(
        osMaps(families.firstWhere((f) => f['id'] == 'option_delta')['cases'])
            .map((c) => c['domain']),
        containsAll(['职业', '学习', '居住', '财务']));
    final requests = await semanticRequests(corpus);
    expect(requests, hasLength(168));
    expect(requests.map((r) => r.id).toSet(), hasLength(168));
    final repeated = await semanticRequests(corpus);
    expect(requests.map((r) => r.hash), repeated.map((r) => r.hash));
    for (final r
        in requests.where((r) => r.metadata['variant'] == 'original')) {
      final swapped = requests.singleWhere((s) =>
          s.metadata['scenarioId'] == r.metadata['scenarioId'] &&
          s.metadata['variant'] == 'swapped');
      expect(swapped.value.problem, r.value.problem);
      expect(swapped.value.v37.routes.map((r) => r.id),
          r.value.v37.routes.reversed.map((r) => r.id));
      expect(r.request['prompt'], isNot(contains(r.metadata['rubric'])));
    }
  });

  test('A40/A47：空结果、旧提示、虚假来源和未人工评审都不能成为真实模型通过记录', () async {
    final corpus = loadSemanticCorpus(),
        requests = await semanticRequests(loadSemanticCorpus());
    final empty = await replaySemanticResponses(corpus, requests, {});
    expect(empty['acceptancePassed'], isFalse);
    expect(
        osMaps(empty['results']).every((r) => r['status'] == 'notRun'), isTrue);
    final request = requests.first;
    final raw = <String, dynamic>{
      'summary': '仅泛泛建议，没有后果图',
      'stopReason': '没有进一步信息'
    };
    final proposal = OsAnalysisProposal.parse(raw, request.value);
    final audit = auditSemanticOutput(request, raw, proposal);
    expect(audit['failed'], containsAll(['concrete', 'reentry', 'symmetry']));
    expect(
        reviewed({
          'reviewer': 'x',
          'reviewedAt': '2026-10-23',
          'checks': {
            'semanticDiagnosis': {'pass': true}
          }
        }, [
          'semanticDiagnosis'
        ]),
        isFalse);
    final bad = await replaySemanticResponses(corpus, [
      request
    ], {
      'source': 'fixture',
      'responses': [
        {'id': request.id, 'requestSha256': 'stale', 'raw': jsonEncode(raw)}
      ]
    });
    expect(bad['acceptancePassed'], isFalse);
    expect(osMaps(bad['results']).single['status'], 'invalidProvenance');
    raw['nodes'] = [
      {
        'id': 'n',
        'routeId': 'a',
        'title': '一定成功',
        'concrete': '假事实',
        'horizon': 'long',
        'valence': 'benefit',
        'label': 'fact',
        'order': 1
      }
    ];
    final cleaned = OsAnalysisProposal.parse(raw, request.value);
    final invalid = auditSemanticOutput(request, raw, cleaned);
    expect(osStrings(invalid['failed']), contains('evidenceDiscipline'));
  });

  final exportPath = Platform.environment['SELF_OS_EVAL_EXPORT'];
  final responsePath = Platform.environment['SELF_OS_EVAL_RESPONSES'];
  test('显式执行：导出生产提示或验收真实模型留档（默认不调用模型）', () async {
    final corpus = loadSemanticCorpus(),
        requests = await semanticRequests(loadSemanticCorpus());
    if (exportPath != null) {
      await File(exportPath)
          .writeAsString(const JsonEncoder.withIndent('  ').convert({
        'executionMode': 'exportOnly',
        'datasetSha256': digest(corpus),
        'specSha256': corpus['specSha256'],
        'requests': requests.map((r) => r.toJson()).toList()
      }));
    }
    if (responsePath != null) {
      final capture = jsonDecode(await File(responsePath).readAsString())
          as Map<String, dynamic>;
      final report = await replaySemanticResponses(corpus, requests, capture);
      final reportPath = Platform.environment['SELF_OS_EVAL_REPORT'] ??
          '$responsePath.report.json';
      await File(reportPath)
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      expect(report['acceptancePassed'], isTrue,
          reason: '必须全部覆盖，并同时通过原始输出检查、语义人工评审与变体一致性；详见报告。');
    }
  },
      skip: exportPath == null && responsePath == null
          ? '未提供真实模型留档；离线结构测试不计为模型泛化验收'
          : false);
}
