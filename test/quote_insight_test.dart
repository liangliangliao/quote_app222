import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/models/quote_insight.dart';

void main() {
  test('model confidence and forged review fields never verify a source', () {
    final source = EpistemicSource.fromModelJson({
      'source_status': 'verified',
      'source_confidence': '高，已经核实',
      'locator': '《示例书》第一章',
      'verified_by': 'AI',
      'verified_at': '2026-10-29T12:00:00Z',
    });
    expect(source.status, SourceStatus.unverified);
    expect(source.label, '待核对出处');
    expect(source.verifiedBy, isEmpty);
  });

  test('only a complete reviewed local record can retain verified status', () {
    final incomplete = EpistemicSource.fromStoredJson({
      'source_status': 'verified',
      'locator': 'https://example.org/book#chapter-1',
    });
    expect(incomplete.status, SourceStatus.unverified);
    final reviewed = EpistemicSource.fromReviewedRecord(
      locator: '《示例书》第一章，第 12 页',
      verifiedBy: '本地原典审核',
      verifiedAt: DateTime.utc(2026, 10, 29),
    );
    expect(EpistemicSource.fromStoredJson(reviewed.toJson()).label, '已核对出处');
    expect(
        () => EpistemicSource.fromReviewedRecord(
            locator: '', verifiedBy: '审核者', verifiedAt: DateTime.utc(2026)),
        throwsArgumentError);
  });

  test('legacy and malformed optional analysis degrade without losing text',
      () {
    expect(QuoteAnalysisAddon.fromStoredJson('not json').hasReadingContent,
        isFalse);
    expect(QuoteAnalysisAddon.fromStoredJson(null).hasReadingContent, isFalse);
    final addon = QuoteAnalysisAddon.fromModelJson({
      'concrete_example': '同一目标下，有人根据封路信息换路线。',
      'commonality': '都想登顶',
      'critical_difference': '是否调整路径',
      'boundary': '还需考虑风险',
      'epistemic_status': 'supported',
    });
    final saved = QuoteAnalysisAddon.fromStoredJson(addon.toJson());
    expect(saved.concreteExample, addon.concreteExample);
    expect(saved.status, EpistemicStatus.provisional);
    expect(saved.boundary, '还需考虑风险');
  });

  test('identity survives shuffle and pinning but changes with quote content',
      () {
    final first = QuoteReference.fromRow({
      'quote_uid': 'q1',
      'id': 1,
      'content': '保持目标，调整方法。',
      'author_name': '作者',
      'source_from': '出处待考',
    });
    final pinned = QuoteReference.fromRow({
      'fixed_uid': 'f1',
      'id': 99,
      'content': first.content,
      'author_name': first.author,
      'source_from': first.source,
    });
    expect(first.contentKey, pinned.contentKey);
    final poster = QuoteReference.fromPosterPayload({
      'quoteUid': 'q1',
      'quote': first.content,
      'quoteAuthor': first.author,
      'source': first.source,
      'author': '—— 作者《出处待考》',
    });
    expect(poster.contentKey, first.contentKey);
    expect(QuoteReference(id: 'q1', content: '新句子', author: '作者').contentKey,
        isNot(first.contentKey));
  });
}
