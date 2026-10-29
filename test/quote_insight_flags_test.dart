import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/dao.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'package:quote_app/pages/history_page.dart';
import 'package:quote_app/services/quote_insight_settings.dart';
import 'package:quote_app/widgets/quote_reading_insights.dart';

class _EmptyHistory extends QuoteDao {
  @override
  Future<List<Map<String, dynamic>>> latest(
          {int limit = 100, int offset = 0, String? q}) async =>
      [];
}

void main() {
  testWidgets(
      'release switches hide optional actions and preserve source status',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: QuoteReadingInsights(
        quote: const QuoteReference(id: 'q', content: '原句', source: '出处待考'),
        loadAddon: (_) async =>
            const QuoteAnalysisAddon(concreteExample: '一个例子', boundary: '一个限制'),
      ),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('具体是什么样子'),
        QuoteInsightSettings.readingEnabled ? findsOneWidget : findsNothing);
    expect(find.text('出处待考'), findsOneWidget);
    await tester
        .pumpWidget(MaterialApp(home: HistoryPage(dao: _EmptyHistory())));
    await tester.pumpAndSettle();
    expect(find.text('选择比较'),
        QuoteInsightSettings.comparisonEnabled ? findsOneWidget : findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });
}
