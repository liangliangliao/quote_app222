import '../data/dao.dart';
import '../data/quote_insight_store.dart';
import '../models/quote_insight.dart';
import 'cognitive_models.dart';
import 'cognitive_store.dart';

enum ConceptQuoteReason { savedConcept, acceptedNote, proposedNote, textMatch }

class ConceptQuoteMatch {
  final Map<String, dynamic> row;
  final ConceptQuoteReason reason;
  const ConceptQuoteMatch(this.row, this.reason);

  String get explanation => switch (reason) {
        ConceptQuoteReason.savedConcept => '已保存的概念标注 · AI 暂定理解',
        ConceptQuoteReason.acceptedNote => '已采纳的概念注释 · 一种理解',
        ConceptQuoteReason.proposedNote => '待确认的概念注释',
        ConceptQuoteReason.textMatch => '文字匹配 · 不表示概念等同',
      };
}

class ConceptQuotePage {
  final List<ConceptQuoteMatch> matches;
  final int nextOffset;
  final bool hasMore;
  const ConceptQuotePage(this.matches, this.nextOffset, this.hasMore);
}

/// Reads only local quote records and their quote-scoped annotations. No model
/// request, diary read, or platform-dependent SQLite JSON extension is needed.
class QuoteConceptCatalog {
  final QuoteInsightStore insights;
  final CognitiveStore notes;
  final Future<List<Map<String, dynamic>>> Function(int limit, int offset)
      _readPage;
  QuoteConceptCatalog({
    QuoteInsightStore? insights,
    CognitiveStore? notes,
    Future<List<Map<String, dynamic>>> Function(int limit, int offset)?
        readPage,
  })  : insights = insights ?? QuoteInsightStore(),
        notes = notes ?? CognitiveStore(),
        _readPage = readPage ??
            ((limit, offset) =>
                QuoteDao().latest(limit: limit, offset: offset));

  static CognitiveNote? currentConceptNote(
          QuoteReference quote, List<CognitiveNote> notes) =>
      notes
          .where((n) =>
              n.task == CognitiveTask.concept &&
              n.selection.module == 'quote' &&
              n.selection.recordId ==
                  (quote.id.isEmpty ? quote.contentKey : quote.id) &&
              n.selection.matches(quote.content))
          .firstOrNull;

  Future<ConceptQuotePage> find(String concept,
      {int offset = 0, int limit = 30}) async {
    if (offset < 0 || limit < 1 || limit > 100) {
      throw ArgumentError('Invalid quote page');
    }
    final query = concept.trim().toLowerCase();
    if (query.isEmpty) return ConceptQuotePage(const [], offset, false);
    final matches = <ConceptQuoteMatch>[];
    var cursor = offset;
    const batchSize = 200;
    while (true) {
      final rows = await _readPage(batchSize, cursor);
      if (rows.isEmpty) return ConceptQuotePage(matches, cursor, false);
      final refs = rows.map(QuoteReference.fromRow).toList();
      final addons = await insights.readAddons(refs);
      final annotations = await notes.forRecords('quote',
          refs.map((q) => q.id.isEmpty ? q.contentKey : q.id).toList());
      for (var i = 0; i < rows.length; i++) {
        cursor++;
        final ref = refs[i];
        final note = currentConceptNote(ref, annotations);
        final labels = note?.analysis.concepts.isNotEmpty == true
            ? note!.analysis.concepts
            : addons[ref.contentKey]?.concepts ?? const <String>[];
        final tagged = labels.any((s) => s.trim().toLowerCase() == query);
        final literal = [
          'content',
          'theme',
          'explanation'
        ].any((key) => '${rows[i][key] ?? ''}'.toLowerCase().contains(query));
        if (tagged || literal) {
          final reason = !tagged
              ? ConceptQuoteReason.textMatch
              : note?.analysis.concepts.isNotEmpty == true
                  ? note!.accepted
                      ? ConceptQuoteReason.acceptedNote
                      : ConceptQuoteReason.proposedNote
                  : ConceptQuoteReason.savedConcept;
          matches.add(ConceptQuoteMatch(rows[i], reason));
        }
        if (matches.length == limit) {
          return ConceptQuotePage(
              matches, cursor, i + 1 < rows.length || rows.length == batchSize);
        }
      }
      if (rows.length < batchSize) {
        return ConceptQuotePage(matches, cursor, false);
      }
    }
  }
}
