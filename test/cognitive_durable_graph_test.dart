import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/epistemic/cognitive_store.dart';
import 'package:quote_app/epistemic/concept_meaning_network.dart';
import 'package:quote_app/epistemic/reading_map_quality.dart';
import 'package:quote_app/epistemic/semantic_analysis_archive.dart';
import 'package:quote_app/epistemic/semantic_scope.dart';
import 'package:quote_app/epistemic/semantic_scope_service.dart';
import 'package:quote_app/epistemic/source_excerpt.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fixtures/nietzsche_body.dart';

const sources = [ScopeSource('A', bodyQuote)];
const cfg = UnifiedAiResolvedConfig(
    provider: 'test',
    apiKey: '',
    model: 'offline',
    endpoint: 'https://example.invalid',
    label: '离线',
    displayModel: '离线夹具',
    available: true);

class OfflineAi extends UnifiedAiService {
  final prompts = <String>[];
  final responses = <String>[];
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      cfg;
  @override
  Future<String> generateText(
      {required String prompt,
      required String purpose,
      String? systemPrompt,
      int maxTokens = 1800,
      bool expectJson = false,
      String? forcedProvider,
      String? forcedModel,
      double? temperature}) async {
    prompts.add(prompt);
    if (responses.isEmpty) throw StateError('测试不能访问真实模型');
    return responses.removeAt(0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory folder;
  late Database db;
  late SemanticScopeService service;
  late OfflineAi ai;
  late SemanticAnalysisArchive archive;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('durable-grounded-graph-');
    db =
        await databaseFactoryFfi.openDatabase('${folder.path}/analysis.sqlite');
    archive = SemanticAnalysisArchive(database: () async => db);
    ai = OfflineAi();
    service = SemanticScopeService(
        ai: ai,
        store: CognitiveStore(database: () async => db),
        archiveStore: archive);
  });
  tearDown(() async {
    await db.close();
    await folder.delete(recursive: true);
  });
  Future<SemanticScope> parse([Map<String, dynamic>? raw]) =>
      service.validateResponse(raw ?? bodyGraph(), sources, '身体与自我评价', cfg,
          context: readingMapContext);

  test(
      'actual screenshot has typed relations, concrete experiences, valid spheres and grouped epistemic premises',
      () async {
    final v = await parse();
    expect(v.issues, isEmpty,
        reason: jsonEncode(v.issues.map((i) => i.toJson()).toList()));
    expect(v.classEdges.map((e) => e.child), ['ack', 'divine']);
    expect(
        v.meaningLinks.any(
            (e) => e.from == 'lower' && e.to == 'body' && e.kind == 'part_of'),
        isTrue);
    expect(v.hierarchy.any((e) => e.kind == 'subtype' && e.child == 'lower'),
        isFalse);
    expect(v.concepts.where((n) => n.kind == 'experience'), hasLength(3));
    expect(
        ReadingMapQuality.issues(v, requestedViews: ['hierarchy', 'circles']),
        isEmpty);
    expect(v.scopeRelations, hasLength(7));
    expect(ConceptCircleLayout.build(v).every((g) => g.geometryConsistent),
        isTrue);
    expect(v.grounds.single.premises, hasLength(2));
    expect(v.grounds.single.experienceIds, ['E1', 'E2']);
    expect(v.grounds.single.kind, 'evidence');
    expect(v.grounds.single.to, contains('在案例及本次判准下'));
    final restored = SemanticScope.parse(v.toJson(), sources);
    expect(restored.analysisSummary, v.analysisSummary);
    expect(restored.grounds.single.premises, v.grounds.single.premises);
  });

  test(
      'new wire anchors permit typography but never rewrite negation or proposition content',
      () async {
    expect(locateSourceExcerpt('他说：“并非所有人都如此。”', '他说:「并非所有人都如此。」'),
        '他说：“并非所有人都如此。”');
    expect(locateSourceExcerpt('A > B 且 x != y', 'A > B 且 x = y'), isNull);
    expect(locateSourceExcerpt('不是每一个人都接受。', '每一个人都接受。'),
        '每一个人都接受。'); // A literal excerpt remains a literal excerpt.
    expect(locateSourceExcerpt('不愿不欲', '愿意欲'), isNull);
    expect(locateSourceExcerpt('甲 乙，甲\n乙', '甲乙'), isNull);
    final raw = bodyGraph();
    raw['evidence'][0]['excerpt'] =
        bodyQuote.replaceAll('（', '(').replaceAll('）', ')');
    expect((await parse(raw)).needsRepair, isFalse);
    raw['evidence'][0]['excerpt'] = bodyQuote.replaceAll('不那么容易', '很容易');
    final rejected = await parse(raw);
    expect(rejected.needsRepair, isTrue);
    expect(
        rejected.concepts
            .expand((n) => n.references)
            .any((e) => e.excerpt.contains('很容易')),
        isFalse);
  });

  test(
      'duplicate or altered definitions and missing endpoints are not silently repaired into false relations',
      () async {
    final raw = bodyGraph();
    raw['circles'][1]['b'] = 'unknown';
    final v = await parse(raw);
    expect(v.issues, isNotEmpty);
    expect(v.scopeRelations.any((r) => r.nodeIds.contains('unknown')), isFalse);
    final duplicate = bodyGraph();
    duplicate['evidence'].add({'id': 'q', 'source': 'A', 'excerpt': '不存在'});
    expect((await parse(duplicate)).needsRepair, isTrue);
  });

  test(
      'unknown circle pairs use real local circles instead of implying invented overlaps',
      () async {
    final raw = bodyGraph();
    raw['circles'] = (raw['circles'] as List).take(4).toList();
    final v = await parse(raw), groups = ConceptCircleLayout.build(v);
    expect(v.scopeRelations, hasLength(4));
    expect(
        groups.where((g) => g.relations.length > 1).single.geometryConsistent,
        isFalse);
    expect(v.needsRepair,
        isFalse); // Local diagrams can still express each known relation.
  });

  test(
      'wire expansion reuses old case and definitions and connects new concepts plus epistemic experience identities',
      () async {
    final old = await parse();
    final raw = {
      'format': 'grounded_graph_v1',
      'purpose': old.analysisPurpose,
      'reading': '核对这次有限的自我评价。',
      'evidence': [
        {'id': 'bc', 'source': 'C1', 'excerpt': '至少这次自己仍受身体需要限制'}
      ],
      'concepts': [
        {
          'id': 'limited',
          'label': '对本次身体限制的承认',
          'definition': '承认身体限制中，明确将断言限定为本次具体经历的自我评价。',
          'universe': '同一时段的一项自我评价',
          'reason': '保留至少这次的限定，避免从个例跳到普遍结论。',
          'refs': ['bc']
        }
      ],
      'experiences': [
        {
          'id': 'E3',
          'label': '小周明确说至少这次仍受限制',
          'description': '讨论返回时，小周说至少这次自己仍受身体需要限制。',
          'refs': ['bc']
        }
      ],
      'links': [
        {
          'from': 'ack',
          'to': 'limited',
          'type': 'subtype',
          'added': '明确限定为本次具体经历',
          'why': '仍承认身体限制，再限定到本次经历。',
          'refs': ['bc']
        },
        {
          'from': 'limited',
          'to': 'E3',
          'type': 'instance',
          'why': '案例中的这项有限判断体现本次规定。',
          'refs': ['bc']
        }
      ],
      'judgments': [
        {
          'claim': '案例中的这项自我评价限于本次经历。',
          'premises': ['案例明确保留至少这次这一限制。'],
          'why': '只依案例明示的断言范围，不推广到全部经历。',
          'refs': ['bc'],
          'experiences': ['E3']
        }
      ],
    };
    final patch = await service.validateResponse(raw, sources, '承认身体限制', cfg,
        context: SemanticContext(
            conceptId: 'ack',
            conceptLabel: '承认身体限制',
            existingConcepts: old.concepts,
            existingCases: old.alignedCases,
            existingHierarchy: old.hierarchy,
            existingLinks: old.meaningLinks,
            existingRelations: old.relations));
    expect(patch.issues, isEmpty,
        reason: jsonEncode(patch.issues.map((i) => i.toJson()).toList()));
    final merged = old.merge(patch);
    expect(
        merged.classEdges
            .any((e) => e.parent == 'ack' && e.child == 'ack/limited'),
        isTrue);
    expect(
        merged.hierarchy
            .any((e) => e.parent == 'ack/limited' && e.child == 'ack/E3'),
        isTrue);
    expect(patch.grounds.single.experienceIds, ['ack/E3']);
    expect(merged.concepts.singleWhere((n) => n.id == 'ack').definition,
        old.concepts.singleWhere((n) => n.id == 'ack').definition);
    expect(merged.alignedCases.single.text, bodyStory);
  });

  test(
      'complete, partial and failed attempts survive restart; restore and browsing never call AI',
      () async {
    ai.responses.addAll([
      jsonEncode(bodyGraph()),
      jsonEncode(bodyGraph(omitCircles: true)),
      '{"broken":'
    ]);
    final complete = await service.analyze(sources, '身体与自我评价',
        force: true, context: readingMapContext);
    final first =
        (await archive.history(sources, '身体与自我评价', readingMapContext)).single;
    final review =
        readingMapContext.withReview('请重新核对直观链路与含义范围', complete.toJson());
    final partial =
        await service.analyze(sources, '身体与自我评价', force: true, context: review);
    expect(partial.needsRepair, isTrue);
    expect(ai.prompts.last, contains('再次深度分析'));
    expect(ai.prompts.last, contains('previous_analysis'));
    expect(ai.prompts.last, contains('请重新核对直观链路与含义范围'));
    await expectLater(
        service.analyze(sources, '身体与自我评价', force: true, context: review),
        throwsFormatException);
    final history =
        await archive.history(sources, '身体与自我评价', readingMapContext);
    expect(history.map((h) => h.status), ['failed', 'partial', 'complete']);
    expect(history.first.raw, '{"broken":');
    final path = db.path;
    await db.close();
    db = await databaseFactoryFfi.openDatabase(path);
    final reopened = SemanticScopeService(
        ai: ai,
        store: CognitiveStore(database: () async => db),
        archiveStore: archive);
    expect(
        (await reopened.analyze(sources, '身体与自我评价', context: readingMapContext))
            .needsRepair,
        isTrue);
    await archive.select(first);
    final restored =
        await reopened.analyze(sources, '身体与自我评价', context: readingMapContext);
    expect(restored.needsRepair, isFalse);
    expect(restored.scopeRelations, hasLength(7));
    expect((await archive.forLibrary([bodyQuote])).single.id, first.id);
    expect(await archive.forLibrary(['别的名言']), isEmpty);
    expect(ai.prompts, hasLength(3));
  });
}
