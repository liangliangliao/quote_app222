import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/services/global_ai_request_settings.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:quote_app/quote_knowledge/batch_request.dart';
import 'package:quote_app/quote_knowledge/classifier.dart';
import 'package:quote_app/quote_knowledge/hierarchy_statistics.dart';
import 'package:quote_app/quote_knowledge/models.dart';
import 'package:quote_app/quote_knowledge/repository.dart';
import 'package:quote_app/quote_knowledge/runtime.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class NativeTestHttpOverrides extends HttpOverrides {}

class BatchAi extends UnifiedAiService {
  int calls = 0;
  final prompts = <String>[];
  final dynamic Function(Map<String, dynamic>, int) answer;
  BatchAi(this.answer);
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      const UnifiedAiResolvedConfig(
          provider: 'test',
          apiKey: '',
          model: 'test',
          endpoint: 'https://example.invalid',
          label: '模拟',
          displayModel: '模拟',
          available: true);
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
    calls++;
    final data = jsonDecode(prompt.split('\n').last) as Map<String, dynamic>;
    final value = await Future.value(answer(data, calls));
    if (value is Exception) throw value;
    if (value is Error) throw value;
    return value is String ? value : jsonEncode(value);
  }
}

class HttpClassificationAi extends UnifiedAiService {
  final String endpoint;
  HttpClassificationAi(this.endpoint);
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      UnifiedAiResolvedConfig(
          provider: 'deepseek',
          apiKey: 'fixture',
          model: 'test',
          endpoint: endpoint,
          label: '模拟',
          displayModel: '模拟',
          available: true);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late Directory docs;
  late QuoteKnowledgeRepository repo;
  var time = DateTime.utc(2026, 11, 2);
  setUpAll(() async {
    databaseFactory = databaseFactoryFfi;
    docs = await Directory.systemTemp.createTemp('economy-tests-');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => docs.path);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('native.scheduler'), (_) async => null);
    db = await AppDatabase.instance();
  });
  setUp(() async {
    repo =
        QuoteKnowledgeRepository(database: () async => db, clock: () => time);
    await repo.database;
    await db.delete('quotes');
    await db.delete('qk_classification_cache');
    await db.delete('qk_ai_requests');
    await db.update('qk_ai_budget', {
      'used': 0,
      'estimated_used': 0,
      'request_limit': 3,
      'stopped': 0,
      'token': '',
      'lease_ms': 0
    });
    time = DateTime.utc(2026, 11, 2);
  });
  tearDownAll(() async {
    await db.close();
    await docs.delete(recursive: true);
  });
  Future<void> insert(int n, {bool same = false, bool themed = false}) async {
    for (var i = 0; i < n; i++) {
      await db.insert('quotes', {
        'quote_uid': 'q$i',
        'content': same ? '幸福是一种体验。' : '幸福需要用心体验编号$i。',
        'theme': themed ? '幸福' : ''
      });
    }
  }

  Map<String, dynamic> valid(Map<String, dynamic> data,
      {bool onlyFirst = false}) {
    final rows = data['q'] as List;
    final c = (data['c'] as List).firstWhere((c) => c[1] == '幸福')[0];
    return {
      'n': [],
      'q': [
        for (final row in onlyFirst ? rows.take(1) : rows)
          {
            'id': row[0],
            'a': [
              [c, '幸福', '原句主题']
            ],
            'r': [],
            'u': ''
          }
      ]
    };
  }

  QuoteKnowledgeWorker worker(BatchAi ai, {bool local = true}) =>
      QuoteKnowledgeWorker(
          repository: repo,
          classifier: QuoteKnowledgeClassifier(ai: ai),
          localFirst: local);

  test('33 existing themed records finish locally with zero AI calls',
      () async {
    await insert(33, themed: true);
    final ai = BatchAi((d, _) => valid(d));
    expect(await worker(ai).drain(limit: 64), 33);
    expect(ai.calls, 0);
    expect((await repo.usage()).local, 33);
    expect((await repo.snapshot()).quoteCount, 33);
    expect(
        (await repo.assignments('q0'))
            .every((m) => m['status'] == 'provisional'),
        isTrue);
  });
  test('8 distinct records share one compact prompt and short category IDs',
      () async {
    await insert(8);
    final ai = BatchAi((d, _) => valid(d));
    expect(await worker(ai, local: false).drain(), 8);
    expect(ai.calls, 1);
    expect(ai.prompts.single, isNot(contains('qkc_')));
    expect(ai.prompts.single, isNot(contains('explanation_hint')));
    expect((await repo.usage()).used, 1);
    expect(await db.query('qk_jobs', where: "status='done'"), hasLength(8));
  });
  test(
      'duplicate records use one item and reuse the completed cache with zero additional calls',
      () async {
    await insert(5, same: true);
    final ai = BatchAi((d, _) => valid(d));
    expect(await worker(ai, local: false).drain(), 5);
    expect((jsonDecode(ai.prompts.single.split('\n').last)['q'] as List),
        hasLength(1));
    await db.insert(
        'quotes', {'quote_uid': 'copy', 'content': '幸福是一种体验。', 'theme': ''});
    expect(await worker(ai, local: false).drain(), 1);
    expect(ai.calls, 1);
    expect((await repo.usage()).cached, 5);
  });
  test(
      'category meaning changes invalidate cache; unrelated new categories do not',
      () async {
    await insert(1, same: true);
    final ai = BatchAi((d, _) => valid(d));
    await worker(ai, local: false).drain();
    await repo.createCategory('测试新主题', '无关主题');
    await db.insert('quotes', {'quote_uid': 'copy', 'content': '幸福是一种体验。'});
    await worker(ai, local: false).drain();
    expect(ai.calls, 1);
    await db.update('qk_categories', {'definition': '另一种语境中定义的幸福'},
        where: 'name=?', whereArgs: ['幸福']);
    await db.insert('quotes', {'quote_uid': 'copy2', 'content': '幸福是一种体验。'});
    await worker(ai, local: false).drain();
    expect(ai.calls, 2);
  });
  test(
      'round limits survive new workers and repeated start clicks; budget can resume explicitly',
      () async {
    await insert(33);
    final ai = BatchAi((d, _) => valid(d));
    for (var i = 0; i < 5; i++) {
      await worker(ai, local: false).drain();
      if (i == 0) {
        await repo.beginRound();
        expect((await repo.usage()).used, 1);
      }
      time = time.add(const Duration(minutes: 1));
    }
    expect(ai.calls, 3);
    await db.update('qk_ai_budget', {'used': 3, 'request_limit': 3});
    await db.insert('quotes', {'quote_uid': 'more', 'content': '幸福需要继续观察。'});
    final used = ai.calls;
    await worker(ai, local: false).drain();
    expect(ai.calls, used);
    expect((await repo.usage()).blocked, greaterThan(0));
    await repo.enqueueBackfill(semantic: true);
    await worker(ai, local: false).drain();
    expect(ai.calls, greaterThan(used));
  });
  test(
      'one batch may retry three times, then stops persistently; every retry consumes allowance',
      () async {
    await repo.beginRound(requestLimit: 6);
    await insert(1);
    final ai = BatchAi((_, __) => StateError('private-provider-detail'));
    final w = worker(ai, local: false);
    for (var i = 0; i < 8; i++) {
      await w.drain();
      time = time.add(const Duration(minutes: 2));
    }
    expect(ai.calls, 4);
    expect((await repo.usage()).used, 4);
    final job = (await db.query('qk_jobs')).single;
    expect(job['status'], 'blocked');
    expect(job['ai_attempts'], 4);
    expect(job['last_error'], isNot(contains('private-provider')));
    expect(await worker(ai, local: false).drain(), 0);
    expect(ai.calls, 4);
  });
  test('partial success is retained and only the missing quote is retried',
      () async {
    await insert(2);
    final ai = BatchAi((d, n) => valid(d, onlyFirst: n == 1));
    final w = worker(ai, local: false);
    expect(await w.drain(), 1);
    time = time.add(const Duration(minutes: 1));
    expect(await w.drain(), 1);
    final q = jsonDecode(ai.prompts.last.split('\n').last)['q'] as List;
    expect(q, hasLength(1));
    expect(q.single[1], contains('编号1'));
    expect(await db.query('qk_jobs', where: "status='done'"), hasLength(2));
  });
  test(
      'reply IDs and exact evidence prevent cross-record assignment; duplicates are not applied',
      () async {
    final cats = await repo.categories();
    const claims = [
      ClassificationClaim('a', '', '', {'content': '幸福属于此句。'}),
      ClassificationClaim('b', '', '', {'content': '另一条不同原句。'})
    ];
    final request = BatchClassificationRequest(claims, cats);
    final happy = request.codes.entries
        .firstWhere((e) => cats.firstWhere((c) => c.id == e.value).name == '幸福')
        .key;
    final data = {
      'n': [],
      'q': [
        {
          'id': 'q0',
          'a': [
            [happy, '幸福', '主题']
          ],
          'r': []
        },
        {
          'id': 'q1',
          'a': [
            [happy, '幸福', '串句证据']
          ],
          'r': []
        }
      ]
    };
    expect(request.parse(jsonEncode(data)).keys, ['a']);
    (data['q'] as List).add((data['q'] as List).first);
    expect(request.parse(jsonEncode(data)), isEmpty);
  });
  test(
      'a possibly sent request is not automatically billed again after process loss',
      () async {
    await insert(1);
    final c = (await repo.claim())!;
    await repo.reserveRequest([c], 1000);
    time = time.add(const Duration(minutes: 4));
    expect(await repo.claim(), isNull);
    expect((await db.query('qk_jobs')).single['status'], 'blocked');
    expect((await repo.usage()).used, 1);
  });
  test(
      'global output override is capped and global HTTP retries cannot multiply a batch',
      () async {
    await GlobalAiRequestSettings().saveRaw(
        timeoutSeconds: '',
        maxOutputTokens: '64000',
        temperature: '',
        topP: '',
        retryCount: '3',
        retryDelayMs: '0');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var calls = 0;
    Map<String, dynamic>? payload;
    server.listen((request) async {
      calls++;
      payload = jsonDecode(await utf8.decoder.bind(request).join());
      request.response.statusCode = 500;
      request.response.write('{"error":{"message":"fixture"}}');
      await request.response.close();
    });
    try {
      final ai = HttpClassificationAi(
          'http://127.0.0.1:${server.port}/chat/completions');
      await HttpOverrides.runWithHttpOverrides(() async {
        await expectLater(
            ai.generateText(
                prompt: 'compact',
                purpose: 'quote_knowledge.batch.v2',
                maxTokens: 476,
                expectJson: true),
            throwsA(anything));
        expect(calls, 1);
        expect(payload!['max_tokens'], 476);
      }, NativeTestHttpOverrides());
    } finally {
      await server.close(force: true);
      await GlobalAiRequestSettings().saveRaw(
          timeoutSeconds: '',
          maxOutputTokens: '',
          temperature: '',
          topP: '',
          retryCount: '',
          retryDelayMs: '');
    }
  });
  test('estimated budget prevents a request even when call allowance remains',
      () async {
    await insert(1);
    await db.update('qk_ai_budget', {'estimated_used': 47999});
    final ai = BatchAi((d, _) => valid(d));
    await worker(ai, local: false).drain();
    expect(ai.calls, 0);
    expect((await repo.usage()).used, 0);
    expect((await db.query('qk_jobs')).single['status'], 'budget');
  });
  test(
      'competing workers share a lock, and duplicate followers reuse the finished cache',
      () async {
    await insert(2, same: true);
    final wait = Completer<dynamic>();
    final ai = BatchAi((d, _) => wait.future);
    final first = worker(ai, local: false).drain(limit: 1);
    for (var i = 0; i < 50 && ai.calls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(ai.calls, 1);
    expect(await worker(ai, local: false).drain(limit: 1), 0);
    expect(ai.calls, 1);
    wait.complete(valid(jsonDecode(ai.prompts.first.split('\n').last)));
    expect(await first, 1);
    time = time.add(const Duration(minutes: 1));
    expect(await worker(ai, local: false).drain(limit: 1), 1);
    expect(ai.calls, 1);
  });
  test(
      'local indexing reuses a known child category instead of creating a duplicate root',
      () async {
    final happy = (await repo.categories()).firstWhere((c) => c.name == '幸福');
    final child =
        await repo.createCategory('过程幸福', '过程中的幸福', parentId: happy.id);
    await db.insert('quotes', {
      'quote_uid': 'child-record',
      'content': '沿路前进是一种体验。',
      'theme': '过程幸福'
    });
    final ai = BatchAi((d, _) => valid(d));
    expect(await worker(ai).drain(), 1);
    expect(ai.calls, 0);
    expect(
        (await repo.categories()).where((c) => c.name == '过程幸福'), hasLength(1));
    expect((await repo.assignments('child-record')).single['id'], child);
  });
  test(
      'upgrade does not automatically resend old requests with an unknown billing outcome',
      () async {
    await insert(1);
    await repo.claim();
    await db.update('qk_ai_budget', {'migrated': 0});
    await repo.initializeEconomy(db);
    expect(await repo.claim(), isNull);
    expect((await db.query('qk_jobs')).single['status'], 'blocked');
  });
  test(
      'ambiguous timeout does not automatically repeat a possibly billed request',
      () async {
    await insert(1);
    final ai = BatchAi((_, __) => TimeoutException('fixture timeout'));
    final w = worker(ai, local: false);
    await w.drain();
    time = time.add(const Duration(minutes: 4));
    await w.drain();
    expect(ai.calls, 1);
    expect((await db.query('qk_jobs')).single['status'], 'blocked');
    expect((await db.query('qk_jobs')).single['last_error'],
        contains('无法确认是否已计费'));
  });
  test('continuing a budget-paused round preserves the three-retry counter',
      () async {
    await repo.beginRound(requestLimit: 1);
    await insert(1);
    final ai = BatchAi((_, __) => StateError('fixture failure'));
    final w = worker(ai, local: false);
    await w.drain();
    time = time.add(const Duration(minutes: 1));
    await w.drain();
    expect((await db.query('qk_jobs')).single['status'], 'budget');
    await repo.enqueueBackfill(semantic: true, requestLimit: 6);
    expect((await db.query('qk_jobs')).single['ai_attempts'], 1);
    for (var i = 0; i < 5; i++) {
      time = time.add(const Duration(minutes: 2));
      await w.drain();
    }
    expect(ai.calls, 4);
    expect((await db.query('qk_jobs')).single['status'], 'blocked');
  });
  test('hierarchy statistics count roots, parents, leaves and every descendant',
      () {
    QuoteCategory c(String id, String parent, {int count = 1}) => QuoteCategory(
        id: id, name: id, definition: id, parentId: parent, quoteCount: count);
    final stats = CategoryHierarchyStatistics([
      c('root', ''),
      c('b', 'root'),
      c('c', 'root'),
      c('d', 'b'),
      c('empty', '', count: 0)
    ]);
    expect(stats.maxDepth, 3);
    expect(stats.roots, 2);
    expect(stats.parents, 2);
    expect(stats.subcategories, 3);
    expect(stats.leaves, 3);
    expect(stats.levels, {1: 2, 2: 2, 3: 1});
    expect(stats.descendants['root'], 3);
    final occupied =
        CategoryHierarchyStatistics(stats.categories, occupiedOnly: true);
    expect(occupied.roots, 1);
    final invalid = CategoryHierarchyStatistics(
        [c('a', 'b'), c('b', 'a'), c('orphan', 'absent')]);
    expect(invalid.maxDepth, 0);
    expect(invalid.invalid, 3);
  });
}
