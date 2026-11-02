import 'package:quote_app/quote_knowledge/batch_request.dart';
import 'dart:convert';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:quote_app/data/quote_insight_store.dart';
import 'package:quote_app/epistemic/cognitive_store.dart';
import 'package:quote_app/epistemic/quote_concept_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/quote_knowledge/models.dart';
import 'package:quote_app/quote_knowledge/repository.dart';
import 'package:quote_app/quote_knowledge/schema.dart';
import 'package:quote_app/quote_knowledge/classifier.dart';
import 'package:quote_app/quote_knowledge/runtime.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ControlledClassifier extends QuoteKnowledgeClassifier {
  final Future<QuoteClassification> Function(
      Map<String, dynamic>, List<QuoteCategory>) answer;
  int calls = 0;
  ControlledClassifier(this.answer, {bool available = true})
      : super(ai: ClassificationAi((_) => '', available: available));
  @override
  Future<Map<String, QuoteClassification>> classifyBatch(
          BatchClassificationRequest request) async =>
      {
        for (final c in request.claims)
          c.quoteKey: await classify(c.quote, request.candidates)
      };
  @override
  Future<QuoteClassification> classify(
      Map<String, dynamic> q, List<QuoteCategory> cats) {
    calls++;
    return answer(q, cats);
  }
}

class ClassificationAi extends UnifiedAiService {
  final String Function(String) respond;
  final prompts = <String>[];
  final bool available;
  ClassificationAi(this.respond, {this.available = true});
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      UnifiedAiResolvedConfig(
          provider: 'test',
          apiKey: '',
          model: 'fixture',
          endpoint: 'https://example.invalid',
          label: 'test',
          displayModel: '模拟模型',
          available: available);
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
    return respond(prompt);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late QuoteKnowledgeRepository repository;
  var time = DateTime.utc(2026, 11, 2);
  Future<int> insert(String uid,
          {String text = '幸福源于成长。', String theme = ''}) =>
      db.insert('quotes', {
        'quote_uid': uid,
        'content': text,
        'theme': theme,
        'explanation': ''
      });
  Future<String> category(String name) async =>
      (await repository.categories()).firstWhere((c) => c.name == name).id;
  QuoteClassification assigned(String id, {String evidence = '幸福'}) =>
      QuoteClassification(
          [], [CategoryAssignment(id, evidence, '原句讨论这个主题')], []);
  setUp(() async {
    time = DateTime.utc(2026, 11, 2);
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
            onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON')));
    await db.execute(
        'CREATE TABLE quotes(id INTEGER PRIMARY KEY AUTOINCREMENT,quote_uid TEXT UNIQUE,content TEXT,theme TEXT,explanation TEXT,avatar TEXT,notified INTEGER)');
    repository =
        QuoteKnowledgeRepository(database: () async => db, clock: () => time);
    await repository.database;
  });
  tearDown(() async => db.close());

  test(
      'new, batch and raw inserts enqueue; notification/avatar changes keep classification',
      () async {
    await db.transaction((txn) async {
      for (var i = 0; i < 3; i++) {
        await txn.insert('quotes', {'quote_uid': 'q$i', 'content': '幸福$i'});
      }
    });
    expect((await db.query('qk_jobs')).length, 3);
    final claim = (await repository.claim())!;
    expect(
        await repository.apply(claim, assigned(await category('幸福'))), isTrue);
    await db.update('quotes', {'avatar': 'local', 'notified': 1},
        where: 'quote_uid=?', whereArgs: [claim.quoteKey]);
    expect((await repository.assignments(claim.quoteKey)).length, 1);
    expect(
        (await db.query('qk_jobs',
                where: 'quote_key=?', whereArgs: [claim.quoteKey]))
            .single['status'],
        'done');
  });
  test(
      'reuses existing categories and creates a meaningful multi-level tree transactionally',
      () async {
    await insert('q');
    final claim = (await repository.claim())!;
    final happy = await category('幸福');
    final result = QuoteClassification.parse({
      'categories': [
        {
          'ref': 'process',
          'name': '过程中的幸福',
          'definition': '行动过程中体验到的幸福',
          'parent_ref': happy,
          'reason': '原句限定了幸福的来源'
        },
        {
          'ref': 'learning',
          'name': '学习的幸福',
          'definition': '在学习成长中体验幸福',
          'parent_ref': 'process',
          'reason': '更具体的过程主题'
        }
      ],
      'assignments': [
        {'category_ref': 'learning', 'evidence': '幸福源于成长', 'reason': '幸福发生在成长中'}
      ]
    }, claim.quote['content'], await repository.categories());
    expect(await repository.apply(claim, result), isTrue);
    final graph = await repository.snapshot();
    final learning = graph.categories.firstWhere((c) => c.name == '学习的幸福');
    expect(graph.category(happy)!.quoteCount, 1);
    expect(graph.children(happy).single.name, '过程中的幸福');
    expect(
        (await repository.quotesForCategory(happy)).single['quote_uid'], 'q');
    expect(graph.edges.where((e) => e.kind == 'subtopic').length, 2);
    await insert('q2');
    final claim2 = (await repository.claim())!;
    expect(await repository.apply(claim2, assigned(learning.id)), isTrue);
    expect(
        (await repository.categories()).where((c) => c.name == '学习的幸福').length,
        1);
  });
  test(
      'aliases deduplicate concurrent category proposals under the same parent',
      () async {
    final happy = await category('幸福');
    final id =
        await repository.createCategory('当下的幸福', '在当下体验满足', parentId: happy);
    await db.insert('qk_aliases', {
      'category_id': id,
      'parent_id': happy,
      'alias_key': categoryNameKey('当下幸福')
    });
    final same =
        await repository.createCategory('当下幸福', '同义表述', parentId: happy);
    expect(same, id);
    final values = await Future.wait([
      repository.createCategory('体验幸福', '体验中的幸福', parentId: happy),
      repository.createCategory('体验幸福', '体验中的幸福', parentId: happy)
    ]);
    expect(values.toSet().length, 1);
  });
  test(
      'editing an in-flight quote rejects the stale result before creating any category',
      () async {
    await insert('q');
    final claim = (await repository.claim())!;
    await db.update('quotes', {'content': '自由意味着承担责任。'},
        where: 'quote_uid=?', whereArgs: ['q']);
    final result = QuoteClassification([
      const CategoryProposal(
          ref: 'new', name: '不该生成', definition: '过期数据', reason: '测试')
    ], [
      const CategoryAssignment('new', '幸福', '测试')
    ], []);
    expect(await repository.apply(claim, result), isFalse);
    expect(
        (await repository.categories()).any((c) => c.name == '不该生成'), isFalse);
    expect((await repository.claim())!.quote['content'], '自由意味着承担责任。');
  });
  test('leased jobs prevent competing workers and recover after process loss',
      () async {
    await insert('q');
    final old = (await repository.claim())!;
    expect(await repository.claim(), isNull);
    time = time.add(const Duration(minutes: 4));
    final recovered = (await repository.claim())!;
    expect(recovered.token, isNot(old.token));
    expect(
        await repository.apply(old, assigned(await category('幸福'))), isFalse);
    expect(await repository.apply(recovered, assigned(await category('幸福'))),
        isTrue);
  });
  test(
      'manual correction wins over running AI and is preserved by old-record backfill',
      () async {
    await insert('q');
    final old = (await repository.claim())!;
    final growth = await category('成长');
    await repository.assignManually('q', [growth]);
    expect(
        await repository.apply(old, assigned(await category('幸福'))), isFalse);
    await repository.enqueueBackfill();
    expect(await repository.claim(), isNull);
    expect((await repository.assignments('q')).single['id'], growth);
  });
  test(
      'legacy indexing uses no model; batch can pause and resume across repository instances',
      () async {
    await db.execute('DROP TRIGGER qk_quote_insert');
    await insert('old1', theme: '幸福');
    await insert('old2', theme: '成长');
    await QuoteKnowledgeSchema.ensure(db);
    expect(await repository.bootstrapLegacy(), 2);
    expect(await repository.claim(), isNull);
    expect((await repository.snapshot()).legacyRemaining, 2);
    await repository.enqueueBackfill();
    await repository.pauseBackfill();
    expect(await repository.claim(), isNull);
    final next =
        QuoteKnowledgeRepository(database: () async => db, clock: () => time);
    await next.enqueueBackfill();
    expect((await next.claim())!.quoteKey, 'old1');
  });
  test(
      'missing model defers jobs without losing quotes or claiming correct semantic classification',
      () async {
    await insert('q', theme: '幸福');
    final classifier = ControlledClassifier(
        (_, __) async => throw ClassificationUnavailable(),
        available: false);
    expect(
        await QuoteKnowledgeWorker(
                repository: repository,
                classifier: classifier,
                localFirst: false)
            .drain(),
        0);
    final job = (await db.query('qk_jobs')).single;
    expect(job['status'], 'blocked');
    expect((await repository.assignments('q')).map((r) => r['status']),
        everyElement('provisional'));
    expect((await db.query('quotes')).single['content'], '幸福源于成长。');
    expect(await repository.claim(), isNull);
    await repository.retryPending();
    expect(await repository.claim(), isNotNull);
  });
  test(
      'invalid AI response retries with generic errors; successful worker stores proof',
      () async {
    await insert('q');
    final bad =
        ControlledClassifier((_, __) async => throw StateError('secret-token'));
    await QuoteKnowledgeWorker(
            repository: repository, classifier: bad, localFirst: false)
        .drain();
    expect((await db.query('qk_jobs')).single['last_error'],
        isNot(contains('secret')));
    await repository.retryPending();
    final good = ControlledClassifier(
        (_, cats) async => assigned(cats.firstWhere((c) => c.name == '幸福').id));
    expect(
        await QuoteKnowledgeWorker(
                repository: repository, classifier: good, localFirst: false)
            .drain(),
        1);
    expect((await repository.assignments('q')).single['evidence'], '幸福');
  });
  test(
      'typed semantic relations retain source proof; co-occurrence never means set inclusion',
      () async {
    await insert('q');
    final claim = (await repository.claim())!;
    final happy = await category('幸福'), growth = await category('成长');
    await repository.apply(
        claim,
        QuoteClassification([], [
          CategoryAssignment(happy, '幸福', '主题'),
          CategoryAssignment(growth, '成长', '主题')
        ], [
          CategoryRelationProposal(
              growth, happy, 'cause_claim', '幸福源于成长', '原句主张成长带来幸福，尚需检验')
        ]));
    final graph = await repository.snapshot();
    expect(graph.edges.single.kind, 'cause_claim');
    expect((await repository.relationEvidence(growth, happy)).single['excerpt'],
        '幸福源于成长');
    await db.delete('quotes', where: 'quote_uid=?', whereArgs: ['q']);
    expect((await repository.snapshot()).edges, isEmpty);
    expect(await db.query('qk_memberships'), isEmpty);
    expect(await db.query('qk_jobs'), isEmpty);
  });
  test(
      'whole-library counts, descendants, pagination and search ignore the current history page',
      () async {
    final happy = await category('幸福'),
        child =
            await repository.createCategory('过程幸福', '行动中的幸福', parentId: happy);
    for (var i = 0; i < 107; i++) {
      await insert('q$i', text: '幸福$i');
      await repository.assignManually('q$i', [happy, child]);
    }
    final graph = await repository.snapshot();
    expect(graph.quoteCount, 107);
    expect(graph.category(happy)!.quoteCount, 107);
    expect((await repository.quotesForCategory(happy, offset: 100)).length, 7);
    expect(
        (await repository.snapshot(query: '幸福106')).category(happy)!.quoteCount,
        1);
  });
  test(
      'rejects category cycles and ungrounded classification without mutating the index',
      () async {
    final happy = await category('幸福'),
        child =
            await repository.createCategory('过程幸福', '行动中的幸福', parentId: happy);
    await expectLater(
        repository.moveCategory(happy, child), throwsArgumentError);
    expect(
        (await repository.categories())
            .firstWhere((c) => c.id == happy)
            .parentId,
        '');
    await insert('q');
    final claim = (await repository.claim())!;
    await expectLater(
        repository.apply(claim, assigned(happy, evidence: '不存在的片段')),
        throwsFormatException);
    expect(await repository.assignments('q'), isEmpty);
    expect(
        () => QuoteClassification.parse(
            {
              'categories': [
                {
                  'ref': 'x',
                  'name': '循环类',
                  'definition': '测试',
                  'reason': '测试',
                  'parent_ref': 'x'
                }
              ],
              'assignments': []
            },
            '幸福',
            []),
        throwsFormatException);
  });
  test(
      'stable legacy identity preserves classifications through physical source table replacement',
      () async {
    await db.insert('quotes', {'content': '幸福', 'theme': '幸福'});
    final claim = (await repository.claim())!;
    expect(claim.quoteKey, 'legacy:1');
    final happy = await category('幸福');
    await repository.apply(claim, assigned(happy));
    await db.transaction((txn) async {
      await QuoteKnowledgeSchema.preserveLegacyIdentity(txn);
      await txn.execute('CREATE TABLE quotes_new AS SELECT * FROM quotes');
      await txn.execute('DROP TABLE quotes');
      await txn.execute('ALTER TABLE quotes_new RENAME TO quotes');
      await QuoteKnowledgeSchema.ensure(txn);
    });
    final uid = '${(await db.query('quotes')).single['quote_uid']}';
    expect((await repository.assignments(uid)).single['id'], happy);
    await db.update('quotes', {'content': '成长'},
        where: 'quote_uid=?', whereArgs: [uid]);
    expect(await repository.assignments(uid), isEmpty);
    expect((await db.query('qk_jobs')).single['status'], 'pending');
  });
  test(
      'real classifier parses a fenced model answer and reuses IDs with grounded evidence',
      () async {
    await insert('q');
    final happy = await category('幸福');
    final ai = ClassificationAi((_) => '```json\n${jsonEncode({
              'categories': [],
              'assignments': [
                {'category_ref': happy, 'evidence': '幸福', 'reason': '原句主题'}
              ]
            })}\n```');
    final worker = QuoteKnowledgeWorker(
        repository: repository,
        classifier: QuoteKnowledgeClassifier(ai: ai),
        localFirst: false);
    expect(await worker.drain(), 1);
    expect((await repository.assignments('q')).single['id'], happy);
    expect(ai.prompts.single, contains('复用已有类别'));
  });
  test('a category can be moved and its old path reused without ID collisions',
      () async {
    final happy = await category('幸福'), growth = await category('成长');
    final old =
        await repository.createCategory('过程体验', '行动过程中的体验', parentId: happy);
    await repository.moveCategory(old, growth);
    final recreated =
        await repository.createCategory('过程体验', '幸福中的过程体验', parentId: happy);
    expect(recreated, isNot(old));
    expect(
        (await repository.categories()).where((c) => c.name == '过程体验').length,
        2);
  });
  test('single-character philosophical categories and aliases remain valid',
      () async {
    final result = QuoteClassification.parse({
      'categories': [
        {
          'ref': 'love',
          'name': '爱',
          'definition': '关切他人与联结的主题',
          'reason': '已有主题未覆盖'
        }
      ],
      'assignments': [
        {'category_ref': 'love', 'evidence': '爱', 'reason': '原句明确讨论爱'}
      ]
    }, '爱带来联结。', await repository.categories());
    await insert('q', text: '爱带来联结。');
    await repository.apply((await repository.claim())!, result);
    expect((await repository.assignments('q')).single['name'], '爱');
  });
  test(
      'other pages find shared category descendants even without a literal keyword',
      () async {
    final happy = await category('幸福');
    final process =
        await repository.createCategory('过程体验', '过程中的幸福体验', parentId: happy);
    await insert('q', text: '沿着山路前进，享受眼前的风景。');
    await repository.assignManually('q', [process]);
    final catalog = QuoteConceptCatalog(
        knowledge: repository,
        insights: QuoteInsightStore(database: () async => db),
        notes: CognitiveStore(database: () async => db),
        readPage: (limit, offset) =>
            db.query('quotes', limit: limit, offset: offset));
    final page = await catalog.find('幸福');
    expect(page.matches.single.row['quote_uid'], 'q');
    expect(page.matches.single.reason, ConceptQuoteReason.manualCategory);
  });
  test('INSERT OR REPLACE invalidates old membership immediately', () async {
    await insert('q');
    await repository.assignManually('q', [await category('幸福')]);
    await db.insert('quotes', {'quote_uid': 'q', 'content': '自由与责任。'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    expect(await repository.assignments('q'), isEmpty);
    expect((await repository.claim())!.quote['content'], '自由与责任。');
  });
  test('portrait paths never change analysis identity or get sent to AI', () {
    const a = QuoteReference(
        id: 'a', content: '幸福', avatarPath: '/private/portrait.jpg');
    const b = QuoteReference(id: 'a', content: '幸福', avatarPath: 'other');
    expect(a.contentKey, b.contentKey);
    expect(a.toPromptJson('A').toString(), isNot(contains('/private')));
    final prompt = QuoteKnowledgeClassifier.buildPrompt(
        {'content': '幸福', 'avatar': '/private/photo', 'theme': '幸福'}, []);
    expect(prompt, isNot(contains('/private')));
  });
}
