import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/zhaojian/src/domain/ai_parse.dart';
import 'package:quote_app/zhaojian/src/domain/json_util.dart';

void main() {
  group('json helpers', () {
    test('zParseObject and zParseArray strip fences and surrounding prose', () {
      expect(zParseObject('结果：\n```json\n{"a": 1}\n```\n完毕')!['a'], 1);
      expect(zParseArray('前言 [1, 2, 3] 后记').length, 3);
    });

    test('garbage yields null or empty without throwing', () {
      expect(zParseObject('没有对象'), isNull);
      expect(zParseObject('{oops'), isNull);
      expect(zParseArray('没有数组'), isEmpty);
      expect(zParseArray('[1, 2'), isEmpty);
    });

    test('zStrings trims, drops empties and limits the count', () {
      expect(zStrings(<dynamic>[' a ', '', 'b', 'c', 'd'], max: 3), <String>['a', 'b', 'c']);
      expect(zStrings('not a list'), isEmpty);
    });
  });

  group('parseAnalysis', () {
    const String good = '''
{"patterns":[
 {"t":"在人情面前先答应","ev":"三次借钱都答应","tier":"强","phase":"高中和现在都有"},
 {"t":"遇到批评会拖延","ev":"自述","tier":"很强","phase":""},
 {"t":"需要接受诊断","ev":"x","tier":"强","phase":""},
 {"t":"他本性难移","ev":"x","tier":"中","phase":""},
 {"t":"外貌影响自信","ev":"他的长相","tier":"弱","phase":""}],
 "untested":[
 {"sit":"被上司当众否定时","rope":"先答「我想想」"},
 {"sit":"","rope":"空情境被丢弃"},
 {"sit":"一辈子的事","rope":"x"}],
 "compare":"相比上一版，拖延的证据变弱"}
''';

    test('keeps compliant patterns, normalizes tiers, drops banned wording', () {
      final ZAnalysis a = parseAnalysis(good);
      expect(a.isEmpty, isFalse);
      expect(a.patterns.map((ZPattern p) => p.t).toList(), <String>['在人情面前先答应', '遇到批评会拖延']);
      expect(a.patterns[0].tier, '强');
      expect(a.patterns[1].tier, '弱', reason: '非法等级回到「弱」');
      expect(a.patterns[0].phase, '高中和现在都有');
      expect(a.dropped, 4, reason: '诊断、本性难移、外貌各丢 1 条，「一辈子」的情境丢 1 条');
      expect(a.untested.length, 1);
      expect(a.untested.single.sit, '被上司当众否定时');
      expect(a.compare, '相比上一版，拖延的证据变弱');
    });

    test('a banned compare text is blanked', () {
      final ZAnalysis a = parseAnalysis('{"patterns":[{"t":"拖延","ev":"a","tier":"强","phase":""}],"compare":"他注定如此"}');
      expect(a.patterns.length, 1);
      expect(a.compare, '');
    });

    test('limits patterns to five and untested to three', () {
      final StringBuffer p = StringBuffer();
      for (int i = 0; i < 8; i++) {
        p.write('{"t":"假设$i","ev":"e","tier":"中","phase":""}${i < 7 ? ',' : ''}');
      }
      final StringBuffer u = StringBuffer();
      for (int i = 0; i < 6; i++) {
        u.write('{"sit":"情境$i","rope":"r"}${i < 5 ? ',' : ''}');
      }
      final ZAnalysis a = parseAnalysis('{"patterns":[$p],"untested":[$u]}');
      expect(a.patterns.length, 5);
      expect(a.untested.length, 3);
    });

    test('garbage or an empty pattern list is empty', () {
      expect(parseAnalysis('随便什么').isEmpty, isTrue);
      expect(parseAnalysis('{"patterns":[]}').isEmpty, isTrue);
      expect(parseAnalysis('{"patterns":"x"}').isEmpty, isTrue);
    });

    test('toJson and fromJson round-trip', () {
      final ZAnalysis a = parseAnalysis(good);
      final ZAnalysis b = ZAnalysis.fromJson(a.toJson());
      expect(b.patterns.length, a.patterns.length);
      expect(b.patterns.first.t, a.patterns.first.t);
      expect(b.untested.first.rope, a.untested.first.rope);
      expect(b.compare, a.compare);
    });
  });
}
