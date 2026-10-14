import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/model.dart';
import '../domain/ranking.dart';
import '../domain/rules.dart';
import 'protocol.dart';

class DecisionsGateway {
  DecisionsGateway({http.Client Function()? clientFactory})
      : clientFactory = clientFactory ?? http.Client.new;
  final http.Client Function() clientFactory;

  Future<MirrorNode> score(CaseFile permittedFile, MirrorSettings settings,
      CancelToken cancel) async {
    final base = Uri.tryParse(settings.gatewayUrl);
    if (!settings.remoteScoring ||
        base == null ||
        base.scheme != 'https' ||
        base.userInfo.isNotEmpty ||
        settings.gatewayAccessToken.isEmpty) {
      return MotiveRanking.build(permittedFile,
          weights: settings.weights, message: '未启用已配置的远程评分；当前为来源规则摘要，没有在线分数');
    }
    final candidates = MotiveRanking.shortlist(permittedFile);
    if (candidates.isEmpty)
      return MotiveRanking.build(permittedFile, message: '没有足够的候选可送评');
    final all = {for (final n in permittedFile.nodes) n.id: n};
    final rootIds =
        candidates.expand((n) => EvidenceRules.actualRoots(n, all)).toSet();
    final payload = {
      'case_id': permittedFile.id,
      'rubric_version': rubricVersion,
      'motives': [
        for (final n in candidates)
          {
            'id': n.id,
            'summary': n.text('summary'),
            'personal_basis': n.text('personalBasis'),
            'horizon': n.text('horizon'),
            'materiality': n.text('materiality'),
            'risk_warning': n.flag('riskWarning'),
            'evidence_ids': EvidenceRules.actualRoots(n, all).toList(),
            'directions': n.objects('directionByRoute'),
            'unknowns': n.strings('unknowns'),
            'counter_reason': n.text('counterReason'),
            'fact_status': n.text('factStatus')
          }
      ],
      'evidence': [
        for (final id in rootIds)
          {
            'id': id,
            'source': all[id]!.origin.name,
            'phase': all[id]!.phase.name,
            'recorded_at': all[id]!.recordedAt.toIso8601String(),
            'body': all[id]!.body
          }
      ],
    };
    final client = clientFactory();
    cancel.onCancel(client.close);
    try {
      cancel.check();
      final response = await client
          .post(
              base.resolve(
                  '${base.path.endsWith('/') ? '' : '${base.path}/'}v1/will-mirror/motives/score'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${settings.gatewayAccessToken}'
              },
              body: jsonEncode(payload))
          .timeout(const Duration(minutes: 3));
      cancel.check();
      if (response.statusCode != 200) throw const MirrorProblem('远程评分暂不可用');
      final data = jsonMap(jsonDecode(utf8.decode(response.bodyBytes)));
      if (data['rubric_version'] != rubricVersion ||
          data['case_id'] != permittedFile.id ||
          data['model'] != 'gpt-6-luna')
        throw const MirrorProblem('评分版本或课题标识不匹配');
      final scores = <String, List<Json>>{};
      final expected = candidates.map((n) => n.id).toSet();
      for (final row in (data['scores'] as List? ?? const [])) {
        final value = jsonMap(row), id = value['motive_id'];
        if (id is! String || !expected.contains(id) || scores.containsKey(id))
          throw const MirrorProblem('评分与候选未能正确对应');
        final facets =
            (value['facets'] as List? ?? const []).map(jsonMap).toList();
        if (facets.length != 4 ||
            facets.map((f) => f['dimension']).toSet().length != 4)
          throw const MirrorProblem('评分维度不完整');
        for (final facet in facets) {
          if (!rankingDimensions.contains(facet['dimension']))
            throw const MirrorProblem('评分量规不匹配');
          final score = facet['score'], confidence = facet['confidence'];
          if (score != null &&
              (score is! num || !score.isFinite || score < 0 || score > 4))
            throw const MirrorProblem('评分超出原始量规');
          if (confidence != null &&
              (confidence is! num ||
                  !confidence.isFinite ||
                  confidence < 0 ||
                  confidence > 1)) throw const MirrorProblem('评分置信度无效');
          if (facet['status'] != 'scored' && score != null)
            throw const MirrorProblem('未知或拒绝不能补造分数');
          if (!{'scored', 'unknown', 'refused'}.contains(facet['status']) ||
              (facet['status'] == 'scored' && score == null) ||
              facet['answerName'] is! String ||
              (facet['answerName'] as String).isEmpty) {
            throw const MirrorProblem('评分状态或映射名称无效');
          }
        }
        scores[id] = facets;
      }
      return MotiveRanking.build(permittedFile,
          weights: settings.weights,
          facets: scores,
          method: 'decisions',
          model: 'gpt-6-luna',
          message: '固定四维量规的本次审议优先级；不是实际动机强度或行为概率');
    } catch (_) {
      cancel.check();
      return MotiveRanking.build(permittedFile,
          weights: settings.weights, message: '在线评分未完成，已回退到来源规则摘要；没有填入默认分数');
    } finally {
      client.close();
    }
  }
}
