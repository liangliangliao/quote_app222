import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/dao.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'package:quote_app/pages/history_page.dart';
import 'package:quote_app/services/quote_comparison_service.dart';
import 'package:quote_app/widgets/quote_comparison_sheet.dart';
import 'package:quote_app/widgets/quote_reading_insights.dart';

const quote = QuoteReference(
    id: 'q1', content: '坚持目标，调整方法。', author: '甲', source: '出处待考');
const result = QuoteComparison(
    common: '都希望行动',
    difference: '是否调整方法',
    notEquivalent: '目标不等于方法',
    limitation: '取决于新信息',
    relation: QuoteRelation.contrast);

class _HistoryDao extends QuoteDao {
  @override
  Future<List<Map<String, dynamic>>> latest(
          {int limit = 100, int offset = 0, String? q}) async =>
      List.generate(
              3,
              (i) => <String, dynamic>{
                    'quote_uid': 'q${i + 1}',
                    'content': '名言 ${i + 1}',
                    'author_name': '作者 ${i + 1}',
                    'source_from': '出处待考'
                  })
          .where((row) => q == null || row['content'].toString().contains(q))
          .toList();
}

class _Comparisons extends QuoteComparisonService {
  int calls = 0;
  bool fail = false;
  @override
  Future<QuoteComparison> compare(QuoteReference a, QuoteReference b) async {
    calls++;
    if (fail) throw StateError('offline');
    return result;
  }

  @override
  Future<void> clearCache(QuoteReference a, QuoteReference b) async {}
}

void main() {
  testWidgets(
      'relation selector draws sets only with grounded extension and directs evidence correctly',
      (tester) async {
    const sets = QuoteComparison(
        common: '共同点',
        difference: '差异',
        notEquivalent: '不能等同',
        limitation: '有条件',
        relation: QuoteRelation.subset,
        relationScope: 'extension',
        setA: '学者',
        setB: '学习者',
        justification: '原句说明包含关系',
        groundedInQuotes: true);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: QuoteRelationView(result: sets))));
    expect(find.byKey(const ValueKey('quote-set-diagram')), findsOneWidget);
    const evidence = QuoteComparison(
        common: '共同点',
        difference: '差异',
        notEquivalent: '不能等同',
        limitation: '有条件',
        relation: QuoteRelation.evidence,
        relationDirection: 'A_to_B');
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: QuoteRelationView(result: evidence))));
    expect(find.byKey(const ValueKey('quote-set-diagram')), findsNothing);
    expect(find.textContaining('B（判断）← A（所引依据）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reading folds remain optional on a narrow, enlarged-text screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(
          size: Size(320, 850),
          textScaler: TextScaler.linear(2),
          disableAnimations: true),
      child: Scaffold(
          body: SingleChildScrollView(
              child: QuoteReadingInsights(
                  quote: quote,
                  loadAddon: (_) async => const QuoteAnalysisAddon(
                      concreteExample: '遇到封路时换路线',
                      commonality: '目标相同',
                      criticalDifference: '是否更新方法',
                      boundary: '需考虑风险')))),
    )));
    await tester.pumpAndSettle();
    expect(find.text('遇到封路时换路线'), findsNothing);
    await tester.tap(find.text('具体是什么样子'));
    await tester.pumpAndSettle();
    expect(find.text('遇到封路时换路线'), findsOneWidget);
    expect(find.text('示例 / 模拟情境，不作为史实或作者原意'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old records and failed annotation loads retain source honesty',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: QuoteReadingInsights(
                quote: quote,
                loadAddon: (_) async =>
                    throw StateError('no optional data')))));
    await tester.pumpAndSettle();
    expect(find.text('出处待考'), findsOneWidget);
    expect(find.text('具体是什么样子'), findsNothing);
    expect(find.text('相似与不同'), findsNothing);
    await tester.tap(find.text('这个解释依据什么'));
    await tester.pumpAndSettle();
    expect(find.textContaining('模型自评为“高可信”'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'history generates only after explicit selection of exactly two records',
      (tester) async {
    final service = _Comparisons();
    await tester.pumpWidget(MaterialApp(
        home: HistoryPage(dao: _HistoryDao(), comparisonService: service)));
    await tester.pumpAndSettle();
    expect(service.calls, 0);
    await tester.tap(find.byKey(const ValueKey('quote-select-comparison')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quote-history-row-q1')));
    await tester.tap(find.byKey(const ValueKey('quote-history-row-q2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quote-history-row-q3')));
    await tester.pump();
    expect(find.text('一次比较两条名言，请先取消一条'), findsOneWidget);
    expect(service.calls, 0);
    await tester.tap(find.byKey(const ValueKey('quote-start-comparison')));
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    expect(find.text('两句名言比较'), findsOneWidget);
    expect(find.text('名言 1'), findsWidgets);
    expect(find.text('名言 2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection persists across search and exits without a request',
      (tester) async {
    final service = _Comparisons();
    await tester.pumpWidget(MaterialApp(
        home: HistoryPage(dao: _HistoryDao(), comparisonService: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quote-select-comparison')));
    await tester.tap(find.byKey(const ValueKey('quote-history-row-q1')));
    await tester.enterText(find.byType(TextField), '名言 2');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quote-history-row-q2')));
    await tester.pump();
    expect(find.text('退出选择（2/2）'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quote-select-comparison')));
    await tester.pump();
    expect(find.text('开始比较'), findsNothing);
    expect(service.calls, 0);
  });

  testWidgets('comparison failure preserves originals and supports retry',
      (tester) async {
    final service = _Comparisons()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: QuoteComparisonSheet(
                a: quote,
                b: const QuoteReference(id: 'q2', content: '另一条原句'),
                service: service))));
    await tester.pumpAndSettle();
    expect(find.text(quote.content), findsOneWidget);
    expect(find.text('另一条原句'), findsOneWidget);
    expect(find.textContaining('暂时无法比较'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('重新比较'));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    await tester.scrollUntilVisible(find.text('不能直接等同的部分'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('不能直接等同的部分'), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-set-diagram')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
