import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/prp_plugin/src/lesson_validator.dart';
import 'package:quote_app/prp_plugin/src/text_guard.dart';

import 'fakes.dart';

void main() {
  final LessonValidator v = LessonValidator(BuiltinTextGuard.check);

  group('LessonValidator', () {
    test('完整的教训可以盖印，成色 5/5', () {
      final c = v.check(goodDraft, hasEvidence: true);
      expect(c.canSeal, isTrue);
      expect(c.quality, 5);
      expect(c.missing, isEmpty);
      expect(c.problems, isEmpty);
    });

    test('没有证据时成色少 1 分，但仍可盖印', () {
      final c = v.check(goodDraft, hasEvidence: false);
      expect(c.canSeal, isTrue);
      expect(c.quality, 4);
    });

    test('缺“有效”不能盖印', () {
      final c = v.check(
        goodDraft.copyWith(worked: <String>[]),
        hasEvidence: true,
      );
      expect(c.canSeal, isFalse);
      expect(c.missing, contains('worked'));
    });

    test('“没起作用”只写空话不能盖印', () {
      final c = v.check(
        goodDraft.copyWith(failed: <String>['忙']),
        hasEvidence: true,
      );
      expect(c.canSeal, isFalse);
      expect(c.missing, contains('failed'));
    });

    test('缺“如果—那么”不能盖印', () {
      final c = v.check(
        goodDraft.copyWith(ifCue: '', thenAction: ''),
        hasEvidence: true,
      );
      expect(c.canSeal, isFalse);
      expect(c.missing, contains('if_then'));
    });

    test('动作超过 40 字不能盖印', () {
      final c = v.check(
        goodDraft.copyWith(thenAction: '很' * 45),
        hasEvidence: true,
      );
      expect(c.canSeal, isFalse);
      expect(c.problems, contains('action_too_long'));
    });

    test('含身份判断不能盖印，且不计“行为层”分', () {
      final c = v.check(
        goodDraft.copyWith(worked: <String>['我就是个废物']),
        hasEvidence: true,
      );
      expect(c.canSeal, isFalse);
      expect(c.problems, contains('identity'));
      expect(c.quality, 4);
    });

    test('含危机词被标出', () {
      final c = v.check(
        goodDraft.copyWith(failed: <String>['我想死']),
        hasEvidence: true,
      );
      expect(c.hasCrisis, isTrue);
      expect(c.canSeal, isFalse);
    });

    test('预警可选：缺它仍可盖印，但成色少 1 分', () {
      final c = v.check(goodDraft.copyWith(earlySignal: ''), hasEvidence: true);
      expect(c.canSeal, isTrue);
      expect(c.quality, 4);
      expect(c.missing, contains('early_signal'));
    });
  });
}
