import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/prp_plugin/src/text_guard.dart';

void main() {
  group('BuiltinTextGuard', () {
    test('危机词被识别', () {
      expect(BuiltinTextGuard.isCrisis('我真的不想活了'), isTrue);
      expect(BuiltinTextGuard.check('我想死').crisis, isTrue);
      expect(BuiltinTextGuard.check('我想 自 杀').crisis, isTrue);
    });

    test('对自己的身份判断被标出', () {
      expect(BuiltinTextGuard.hasIdentityJudgement('我就是个废物'), isTrue);
      expect(BuiltinTextGuard.hasIdentityJudgement('我总是做不好'), isTrue);
      expect(BuiltinTextGuard.hasIdentityJudgement('我真没用'), isTrue);
      expect(BuiltinTextGuard.check('我就是个废物').problems, contains('identity'));
    });

    test('描述行为的句子通过', () {
      final r = BuiltinTextGuard.check('晚上十点还在刷手机，没有开始写');
      expect(r.ok, isTrue);
      expect(r.crisis, isFalse);
    });
  });

  group('VagueCheck', () {
    test('空话与过短的话算空话', () {
      expect(VagueCheck.isVague('忙'), isTrue);
      expect(VagueCheck.isVague('没时间'), isTrue);
      expect(VagueCheck.isVague('太累'), isTrue);
    });

    test('具体情境不算空话', () {
      expect(VagueCheck.isVague('晚上刷了两小时手机'), isFalse);
      expect(VagueCheck.isVague('没有开始写'), isFalse);
    });
  });

  group('SentenceClassifier', () {
    test('切成事实、解释、自责', () {
      final r = SentenceClassifier.classify('晚上十点还在刷手机。因为太累了。我就是个废物！');
      expect(r.length, 3);
      expect(r[0].kind, SentenceKind.fact);
      expect(r[1].kind, SentenceKind.interpretation);
      expect(r[2].kind, SentenceKind.selfBlame);
    });

    test('factsOf 只保留事实', () {
      final r = SentenceClassifier.classify('晚上十点还在刷手机。因为太累了。');
      expect(SentenceClassifier.factsOf(r), <String>['晚上十点还在刷手机']);
    });

    test('空文本得到空列表', () {
      expect(SentenceClassifier.classify('  \n '), isEmpty);
    });
  });
}
