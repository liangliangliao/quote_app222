import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/quote_insight_store.dart';
import 'package:quote_app/epistemic/cognitive_models.dart';
import 'package:quote_app/epistemic/cognitive_store.dart';
import 'package:quote_app/epistemic/quote_concept_catalog.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late QuoteInsightStore insights;
  late CognitiveStore notes;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    insights = QuoteInsightStore(database: () async => db);
    notes = CognitiveStore(database: () async => db);
  });
  tearDown(() => db.close());

  QuoteConceptCatalog catalog(List<Map<String, dynamic>> rows) =>
      QuoteConceptCatalog(
          insights: insights,
          notes: notes,
          readPage: (limit, offset) async =>
              rows.skip(offset).take(limit).toList());

  test(
      'concept tags find quotes without the word; pagination retains every result',
      () async {
    final rows = List.generate(
        75,
        (i) => <String, dynamic>{
              'quote_uid': 'quote-$i',
              'content': i == 1 ? '幸福是这里的关键词。' : '没有该词的原句 $i',
            });
    for (var i = 0; i < rows.length; i++) {
      await insights.saveAddon(QuoteReference.fromRow(rows[i]),
          QuoteAnalysisAddon(concepts: [i.isEven ? '幸福' : '勇气']));
    }
    final index = catalog(rows);
    final first = await index.find('幸福');
    final next = await index.find('幸福', offset: first.nextOffset);
    expect(first.matches.length, 30);
    expect(first.hasMore, isTrue);
    expect(next.hasMore, isFalse);
    final all = [...first.matches, ...next.matches];
    expect(all.map((e) => e.row['quote_uid']).toSet(), {
      for (var i = 0; i < 75; i++)
        if (i.isEven || i == 1) 'quote-$i',
    });
    expect(all.length, 39);
    expect(all.first.reason, ConceptQuoteReason.savedConcept);
    expect(all.singleWhere((e) => e.row['quote_uid'] == 'quote-1').reason,
        ConceptQuoteReason.textMatch);
  });

  test(
      'only current quote-scoped notes supply concepts; draft status remains visible',
      () async {
    final rows = List.generate(
        3,
        (i) => <String, dynamic>{
              'quote_uid': 'subject-$i',
              'content': '观察材料 $i',
            });
    CognitiveNote annotation(int i,
            {String module = 'quote', bool accepted = true}) =>
        CognitiveNote(
            id: '$module-$i',
            task: CognitiveTask.concept,
            selection: CognitiveSelection.fromText(
                module: module,
                recordId: 'subject-$i',
                title: '记录',
                fullText: '观察材料 $i'),
            analysis:
                const CognitiveAnalysis(summary: '一种理解', concepts: ['成长']),
            modelInfo: 'fixture',
            createdAt: '2026-11-01T00:00:00Z',
            accepted: accepted);
    await notes.save(annotation(0));
    await notes.save(annotation(1, module: 'diary'));
    await notes.save(annotation(2, accepted: false));
    final index = catalog(rows);
    final page = await index.find('成长');
    expect(page.matches.map((e) => e.row['quote_uid']).toList(),
        ['subject-0', 'subject-2']);
    expect(page.matches.first.reason, ConceptQuoteReason.acceptedNote);
    expect(page.matches.last.reason, ConceptQuoteReason.proposedNote);
    rows.first['content'] = '原文已经修改';
    expect(
        (await index.find('成长'))
            .matches
            .map((e) => e.row['quote_uid'])
            .toList(),
        ['subject-2']);
  });
}
