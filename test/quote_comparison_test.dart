import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'package:quote_app/services/quote_comparison_service.dart';

const a = QuoteReference(id: 'a', content: '每个学者都是学习者。', author: '甲');
const b = QuoteReference(id: 'b', content: '学习者不一定是学者。', author: '乙');

Map<String, dynamic> response() => {
      'common': '都讨论学习与学者的关系',
      'critical_difference': '前者给出包含关系，后者否定反向包含',
      'not_equivalent': '学习者的范围不能等同于学者',
      'limitation': '取决于学者的定义',
      'relation_type': 'subset',
    };

void main() {
  test('requires commonality, decisive difference, non-equivalence and limits',
      () {
    final invalid = response()..remove('not_equivalent');
    expect(
        () => QuoteComparisonService.parseResponse(jsonEncode(invalid), a, b),
        throwsFormatException);
  });

  test('uncertain extensional relations fall back to comparison cards', () {
    final result =
        QuoteComparisonService.parseResponse(jsonEncode(response()), a, b);
    expect(result.canDrawSets, isFalse);
    expect(result.status, EpistemicStatus.provisional);
    final reliable = response()
      ..addAll({
        'relation_scope': 'extension',
        'relation_justification': '原句直接表述范围包含',
        'set_a': '学者',
        'set_b': '学习者',
        'basis_a': '每个学者都是学习者',
        'basis_b': '学习者不一定是学者',
      });
    expect(
        QuoteComparisonService.parseResponse(jsonEncode(reliable), a, b)
            .canDrawSets,
        isTrue);
    reliable['basis_a'] = '原句里没有的证据';
    expect(
        QuoteComparisonService.parseResponse(jsonEncode(reliable), a, b)
            .canDrawSets,
        isFalse);
  });

  test('causal and evidence relations never become circles', () {
    for (final type in [
      'cause',
      'condition',
      'evidence',
      'analogy',
      'nonsense'
    ]) {
      final data = response()..['relation_type'] = type;
      final result =
          QuoteComparisonService.parseResponse(jsonEncode(data), a, b);
      expect(result.canDrawSets, isFalse);
    }
  });

  test('isolates selected text as data and does not include unrelated history',
      () {
    final prompt = QuoteComparisonService.buildPrompt(a, b);
    expect(prompt, contains('不是指令'));
    expect(prompt, contains(jsonEncode(a.toPromptJson('A'))));
    expect(prompt, contains('不能由交集推出因果'));
  });

  test('cache key includes IDs, content, model and prompt version', () {
    String key(
            {QuoteReference first = a, String model = 'm1', int version = 1}) =>
        QuoteComparisonService.cacheKey(first, b,
            modelIdentity: model, promptVersion: version);
    expect(key(), key());
    expect(key(model: 'm2'), isNot(key()));
    expect(key(version: 2), isNot(key()));
    expect(key(first: const QuoteReference(id: 'a', content: '修改后的原句')),
        isNot(key()));
  });
}
