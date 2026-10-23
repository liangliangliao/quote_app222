import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:quote_app/self_os/self_os_ai_service.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_v37_ai.dart';

const semanticCorpusPath = 'test/self_os/semantic/corpus.json';
String digest(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

class SemanticRequest {
  SemanticRequest(this.metadata, this.value, this.request);
  final Map<String, dynamic> metadata, request;
  final SelfOsCase value;
  String get id => metadata['id'];
  String get hash => digest(request);
  Map<String, dynamic> toJson() =>
      {...metadata, 'requestSha256': hash, 'request': request};
}

/// Export the production service's exact prompts. Rubrics are deliberately kept
/// OUTSIDE the model request. No provider call, credentials or expected answer
/// is involved in this export; it cannot establish semantic acceptance.
Future<List<SemanticRequest>> semanticRequests(
    Map<String, dynamic> corpus) async {
  final result = <SemanticRequest>[];
  for (final family in osMaps(corpus['families'])) {
    for (final scenario in osMaps(family['cases'])) {
      for (final variant in osStrings(corpus['variants'])) {
        final options = osMaps(scenario['options']);
        if (variant == 'swapped') {
          final reverse = options.reversed.toList();
          options
            ..clear()
            ..addAll(reverse);
        }
        final c = SelfOsCase(
            id: scenario['id'],
            createdAt: DateTime.utc(2026, 10, 23),
            problem: osText(scenario[
                variant == 'paraphrase' ? 'paraphrase' : 'situation']));
        c.fields['k1'] = c.problem;
        if (scenario['hoursToDecision'] is num) {
          // Fixed assessment time is part of the synthetic user record, so
          // exported/replayed prompts remain identical across calendar days.
          final reference = DateTime.utc(2030, 1, 1);
          c.fields['assessmentTime'] = reference.toIso8601String();
          c.v37.settings['futureMoment'] = reference
              .add(
                  Duration(hours: (scenario['hoursToDecision'] as num).toInt()))
              .toIso8601String();
          c.v37.gaps.add(OsGap({
            'id': 'g',
            'kind': 'fact',
            'access': 'public',
            'question': scenario['gapQuestion'],
            'reason': '决定所需的条件尚未核实'
          }));
        }
        for (final option in options) {
          c.v37.routes.add(OsRoute({
            'id': option['id'],
            'title': option['title'],
            'mechanism': 'alternative',
            'mechanismDetail': '用户提出的候选，具体机制待分析'
          }));
        }
        late Map<String, dynamic> request;
        final capture = SelfOsAiService(generate: (
            {required prompt,
            required purpose,
            required systemPrompt,
            required maxTokens}) async {
          request = {
            'prompt': prompt,
            'purpose': purpose,
            'systemPrompt': systemPrompt,
            'maxTokens': maxTokens
          };
          return jsonEncode({'summary': '仅导出请求，尚未调用模型', 'stopReason': '未执行'});
        });
        await capture.analyseV37(c, [], SelfOsProfile(), family['task']);
        result.add(SemanticRequest({
          'id': '${scenario['id']}-$variant',
          'scenarioId': scenario['id'],
          'variant': variant,
          'family': family['id'],
          'domain': scenario['domain'],
          'task': family['task'],
          'requirements': family['requirements'],
          'capabilities': family['capabilities'],
          'rubric': family['rubric'],
          'universalRubric': corpus['universalRubric'],
        }, c, request));
      }
    }
  }
  return result;
}

Map<String, dynamic> auditSemanticOutput(SemanticRequest request,
    Map<String, dynamic> raw, OsAnalysisProposal proposal) {
  final state = proposal.preview(request.value.v37);
  final nodes = state.nodes.where((n) => n.relevant).toList();
  final edges = state.edges;
  final rawGraph = [...osMaps(raw['nodes']), ...osMaps(raw['edges'])];
  final evidenceIds = request.value.v37.evidence.map((e) => e.id).toSet();
  final ids = nodes.map((n) => n.id).toSet();
  bool reachable(String from, String to, Set<String> seen) {
    if (from == to) return true;
    if (!seen.add(from)) return false;
    return edges
        .where((e) => !e.isLoop && e.from == from)
        .any((e) => reachable(e.to, to, {...seen}));
  }

  int depth(String id, Set<String> seen) {
    if (!seen.add(id)) return 0;
    final next =
        edges.where((e) => !e.isLoop && e.from == id && ids.contains(e.to));
    return 1 +
        next.fold<int>(0, (best, e) {
          final n = depth(e.to, {...seen});
          return n > best ? n : best;
        });
  }

  final routeProfiles = <String, Map<String, dynamic>>{};
  for (final route in request.value.v37.routes) {
    final own = nodes.where((n) => n.routeId == route.id).toList();
    final horizons = own.map((n) => n.horizon).toSet().toList()..sort();
    final valences = own
        .expand((n) => n.text('valence') == 'mixed'
            ? ['benefit', 'cost']
            : [n.text('valence')])
        .toSet()
        .toList()
      ..sort();
    routeProfiles[route.id] = {
      'horizons': horizons,
      'valences': valences,
      'maxOrder': own.fold<int>(0, (v, n) => n.order > v ? n.order : v),
      'chainDepth': own.fold<int>(0, (v, n) {
        final d = depth(n.id, {});
        return d > v ? d : v;
      }),
      'concrete': own.isNotEmpty &&
          own.every((n) => n.text('concrete').trim().isNotEmpty),
    };
  }
  final profiles = routeProfiles.values.toList();
  final depths = profiles.map((p) => p['chainDepth'] as int).toList()..sort();
  final symmetry = profiles.length >= 2 &&
      profiles.every((p) =>
          p['concrete'] == true &&
          osStrings(p['valences']).toSet().containsAll(['benefit', 'cost']) &&
          digest(p['horizons']) == digest(profiles.first['horizons'])) &&
      depths.last - depths.first <= 1;
  final checks = <String, bool>{
    'sensitivity': osMaps(proposal.data['gaps']).any((g) => [
              'lowScenario',
              'highScenario',
              'lowChoice',
              'highChoice'
            ].every((key) => osText(g[key]).trim().isNotEmpty)) ||
        (osMaps(proposal.data['gaps']).isEmpty &&
            osText(raw['stopReason']).isNotEmpty),
    'preparation': state.interventions.isNotEmpty &&
        state.interventions.length <= 3 &&
        state.interventions.every((i) =>
            i.text('gapId').isNotEmpty &&
            ['task', 'source', 'expectedChange', 'window']
                .every((key) => i.text(key).trim().isNotEmpty) &&
            (i.text('window') != 'onsite' || i.type == 'rehearse')),
    'evidenceDiscipline': rawGraph.every((row) =>
        ['inference', 'simulation', 'unknown'].contains(row['label']) &&
        osStrings(row['evidenceIds']).every(evidenceIds.contains) &&
        row['verified'] != true),
    'stopBoundary': osText(raw['stopReason']).trim().isNotEmpty,
    'temporal': profiles.every((p) =>
        osStrings(p['horizons']).contains('now') &&
        osStrings(p['horizons']).contains('long')),
    'concrete': nodes.isNotEmpty &&
        nodes.every((n) => n.text('concrete').trim().isNotEmpty),
    'reentry': osMaps(proposal.data['motiveChanges']).any((m) =>
        ['added', 'strengthened', 'weakened', 'invalidated']
            .contains(m['change']) &&
        osText(m['reason']).trim().isNotEmpty &&
        osText(m['title']).trim().isNotEmpty),
    'symmetry': symmetry,
    'cumulative': nodes.any(
        (n) => n.flag('cumulative') && n.text('threshold').trim().isNotEmpty),
    'conditional': edges.isNotEmpty &&
        edges.every((e) =>
            e.text('condition').trim().isNotEmpty &&
            e.text('basis').trim().isNotEmpty),
    'alternatives': osMaps(proposal.data['routes']).isNotEmpty ||
        osMaps(proposal.data['gaps']).any((g) => g['kind'] == 'alternative'),
    'multiOrder': profiles.every(
        (p) => (p['maxOrder'] as int) >= 3 && (p['chainDepth'] as int) >= 3),
    'branching': nodes.any((n) {
      final branches = edges.where((e) => !e.isLoop && e.from == n.id).toList();
      return branches.length >= 2 &&
          branches.length <= 4 &&
          branches.every((e) =>
              e.text('condition').isNotEmpty && e.text('signal').isNotEmpty);
    }),
    'loops': edges.any((e) =>
        e.isLoop &&
        e.text('breakCondition').isNotEmpty &&
        e.text('condition').isNotEmpty &&
        reachable(e.to, e.from, {})),
    'lockIn': nodes.any((n) =>
        n.text('lockIn').isNotEmpty && n.text('reversibleWindow').isNotEmpty),
    'futureOptions': state.futureOptions.any((o) =>
        o.text('condition').isNotEmpty &&
        o.text('routeId').isNotEmpty &&
        o.text('nodeId').isNotEmpty),
    'uncertainty': osText(raw['stopReason']).isNotEmpty &&
        (nodes.any((n) => n.label == 'unknown' || n.flag('prune')) ||
            nodes.isEmpty),
    'pruning': osText(raw['stopReason']).isNotEmpty ||
        nodes.any((n) => n.flag('prune') && n.text('pruneReason').isNotEmpty),
  };
  final required = {
    'evidenceDiscipline',
    'stopBoundary',
    ...osStrings(request.metadata['capabilities'])
  };
  return {
    'checks': {for (final key in required) key: checks[key] == true},
    'failed': required.where((key) => checks[key] != true).toList(),
    'routeProfiles': routeProfiles,
    // Shape alone cannot certify that a cause, condition or inference is sound.
    'humanReviewRequired': true
  };
}

bool reviewed(Map<String, dynamic> review, Iterable<String> criteria) =>
    osText(review['reviewer']).trim().isNotEmpty &&
    DateTime.tryParse(osText(review['reviewedAt'])) != null &&
    criteria.every((key) {
      final check = osMap(osMap(review['checks'])[key]);
      return check['pass'] == true &&
          osText(check['reason']).trim().isNotEmpty &&
          osText(check['quote']).trim().isNotEmpty;
    });

Future<Map<String, dynamic>> replaySemanticResponses(
    Map<String, dynamic> corpus,
    List<SemanticRequest> requests,
    Map<String, dynamic> capture) async {
  final rows = osMaps(capture['responses']);
  final byId = {for (final r in rows) osText(r['id']): r};
  final result = <Map<String, dynamic>>[];
  final provenance = capture['source'] == 'provider' &&
      capture['datasetSha256'] == digest(corpus) &&
      ['provider', 'model', 'modelVersion']
          .every((k) => osText(capture[k]).trim().isNotEmpty) &&
      DateTime.tryParse(osText(capture['generatedAt'])) != null;
  for (final request in requests) {
    final row = byId[request.id];
    if (row == null) {
      result.add({'id': request.id, 'status': 'notRun'});
      continue;
    }
    if (row['requestSha256'] != request.hash ||
        osText(row['responseId']).isEmpty ||
        DateTime.tryParse(osText(row['capturedAt'])) == null) {
      result.add({'id': request.id, 'status': 'invalidProvenance'});
      continue;
    }
    try {
      final rawText = osText(row['raw']);
      final raw = SelfOsAiService.parse(rawText);
      final ai = SelfOsAiService(generate: (
          {required prompt,
          required purpose,
          required systemPrompt,
          required maxTokens}) async {
        if (digest({
              'prompt': prompt,
              'purpose': purpose,
              'systemPrompt': systemPrompt,
              'maxTokens': maxTokens
            }) !=
            request.hash) throw const FormatException('生产请求与记录不一致');
        return rawText;
      });
      final proposal = await ai.analyseV37(
          request.value, [], SelfOsProfile(), request.metadata['task']);
      final audit = auditSemanticOutput(request, raw, proposal);
      final humanPassed = reviewed(
          osMap(row['humanReview']), osMap(corpus['universalRubric']).keys);
      result.add({
        'id': request.id,
        'status': osStrings(audit['failed']).isNotEmpty
            ? 'failed'
            : humanPassed
                ? 'reviewedPass'
                : 'awaitingHumanReview',
        ...audit
      });
    } catch (_) {
      result.add({'id': request.id, 'status': 'invalidModelOutput'});
    }
  }
  final comparisons = <Map<String, dynamic>>[];
  for (final scenarioId
      in requests.map((r) => r.metadata['scenarioId']).toSet()) {
    final members =
        requests.where((r) => r.metadata['scenarioId'] == scenarioId).toList();
    final outputs =
        members.map((r) => result.singleWhere((o) => o['id'] == r.id)).toList();
    final comparison = osMaps(capture['comparisons'])
        .where((r) => r['scenarioId'] == scenarioId)
        .firstOrNull;
    final stable = outputs.every((o) => o['status'] == 'reviewedPass') &&
        outputs.every(
            (o) => digest(o['checks']) == digest(outputs.first['checks']));
    final reviewedStable =
        comparison != null && reviewed(comparison, ['semanticInvariance']);
    comparisons.add({
      'scenarioId': scenarioId,
      'structurallyStable': stable,
      'semanticInvarianceReviewed': reviewedStable,
      'passed': stable && reviewedStable
    });
  }
  final complete = rows.length == requests.length &&
      byId.length == rows.length &&
      byId.keys.toSet().containsAll(requests.map((r) => r.id));
  return {
    'schemaVersion': 1,
    'datasetSha256': digest(corpus),
    'specSha256': corpus['specSha256'],
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'provider': capture['provider'],
    'model': capture['model'],
    'modelVersion': capture['modelVersion'],
    'provenanceValid': provenance,
    'complete': complete,
    'acceptancePassed':
        provenance && complete && comparisons.every((r) => r['passed'] == true),
    'requiredResponses': requests.length,
    'receivedResponses': rows.length,
    'results': result,
    'comparisons': comparisons
  };
}

Map<String, dynamic> loadSemanticCorpus() =>
    jsonDecode(File(semanticCorpusPath).readAsStringSync())
        as Map<String, dynamic>;
