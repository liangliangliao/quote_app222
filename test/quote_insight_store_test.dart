import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/quote_insight_store.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'package:quote_app/services/quote_comparison_service.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const first = QuoteReference(id: 'q1', content: '坚持目标，调整方法。', author: '甲');
const second = QuoteReference(id: 'q2', content: '遇到问题也要坚持原来的方法。', author: '乙');

class _FakeAi extends UnifiedAiService {
  int calls = 0;
  bool available = true;
  String model = 'test-model';
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      UnifiedAiResolvedConfig(
          provider: 'test',
          apiKey: '',
          model: model,
          endpoint: 'https://example.invalid',
          label: 'test',
          displayModel: model,
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
    calls++;
    expect(prompt, contains(first.content));
    expect(prompt, contains(second.content));
    return jsonEncode({
      'common': '都希望持续行动',
      'critical_difference': '是否随新信息调整方法',
      'not_equivalent': '坚持目标不等于坚持方法',
      'limitation': '还需判断新信息是否可靠',
      'relation_type': 'contrast',
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late QuoteInsightStore store;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    store = QuoteInsightStore(database: () async => db);
  });
  tearDown(() async => db.close());

  test('sidecar survives pin identity and does not modify original records',
      () async {
    await db.execute('CREATE TABLE quotes (content TEXT, explanation TEXT)');
    await db
        .insert('quotes', {'content': first.content, 'explanation': '原有解读'});
    await store.saveAddon(first,
        const QuoteAnalysisAddon(concreteExample: '生活示例', boundary: '还需检验'));
    final pinned = QuoteReference(
        id: 'fixed-1', content: first.content, author: first.author);
    expect((await store.readAddon(pinned)).concreteExample, '生活示例');
    expect((await db.query('quotes')).single,
        {'content': first.content, 'explanation': '原有解读'});
    expect((await store.readAddon(second)).hasReadingContent, isFalse);
  });

  test('same pair reuses cache offline and clears only its own comparison',
      () async {
    final ai = _FakeAi();
    final service = QuoteComparisonService(ai: ai, store: store);
    await store.saveAddon(first, const QuoteAnalysisAddon(boundary: '保留注释'));
    final initial = await service.compare(first, second);
    ai.available = false;
    expect(
        (await service.compare(first, second)).difference, initial.difference);
    expect(ai.calls, 1);
    await service.clearCache(first, second);
    expect((await store.readAddon(first)).boundary, '保留注释');
    await expectLater(service.compare(first, second), throwsStateError);
    ai.available = true;
    await service.compare(first, second);
    expect(ai.calls, 2);
    ai.model = 'another-model';
    await service.compare(first, second);
    expect(ai.calls, 3);
  });

  test('concurrent requests for a pair share one model call', () async {
    final ai = _FakeAi();
    final service = QuoteComparisonService(ai: ai, store: store);
    await Future.wait(
        [service.compare(first, second), service.compare(first, second)]);
    expect(ai.calls, 1);
  });

  test(
      'corrupt cached analysis can be regenerated without losing the originals',
      () async {
    final ai = _FakeAi();
    final service = QuoteComparisonService(ai: ai, store: store);
    await service.compare(first, second);
    await db.update('app_kv', {'value': '{invalid json'},
        where: "key GLOB 'quote_insight.comparison.*'");
    expect((await service.compare(first, second)).notEquivalent, '坚持目标不等于坚持方法');
    expect(ai.calls, 2);
  });

  test('comparison cache is bounded without pruning unrelated KV entries',
      () async {
    await store.saveAddon(first, const QuoteAnalysisAddon(boundary: '保留'));
    await db.insert('app_kv', {'key': 'unrelated.setting', 'value': 'keep'});
    await db.insert('app_kv',
        {'key': 'quoteXinsight.comparison.keep', 'value': 'also keep'});
    const comparison = QuoteComparison(
        common: '共性',
        difference: '差异',
        notEquivalent: '不能等同',
        limitation: '条件',
        relation: QuoteRelation.unknown);
    for (var i = 0; i < 103; i++) {
      await store.saveComparison('$i', comparison);
    }
    expect(await store.readComparison('0'), isNull);
    expect(await store.readComparison('102'), isNotNull);
    expect((await store.readAddon(first)).boundary, '保留');
    expect(
        (await db.query('app_kv',
                where: 'key=?', whereArgs: ['unrelated.setting']))
            .single['value'],
        'keep');
    expect(
        (await db.query('app_kv',
                where: 'key=?', whereArgs: ['quoteXinsight.comparison.keep']))
            .single['value'],
        'also keep');
    expect(
        (await db.rawQuery(
                "SELECT count(*) AS n FROM app_kv WHERE key GLOB 'quote_insight.comparison.*'"))
            .single['n'],
        100);
  });
}
