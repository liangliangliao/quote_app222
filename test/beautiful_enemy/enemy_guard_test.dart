import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/beautiful_enemy/src/domain/guard.dart';
import 'package:quote_app/beautiful_enemy/src/enemy_oracle.dart';

EnemyDraft draft({
  String charge = '承诺到期 3 条，失效 2 条。',
  List<int> evidence = const <int>[1, 2],
  int tone = 2,
  String action = '现在补做：译完第九节',
  int? dueMs,
  bool factOnly = false,
  String hint = '',
}) {
  return EnemyDraft(
    charge: charge,
    evidenceIds: evidence,
    toneLevel: tone,
    lessonHint: hint,
    action: action,
    actionDueMs: dueMs ?? 2000000,
    appealPrompt: '你拿什么反驳？',
    factOnly: factOnly,
  );
}

void main() {
  const DraftValidator v = DraftValidator();
  const int now = 1000000;
  const Set<int> allowed = <int>{1, 2, 3};

  List<String> check(EnemyDraft d, {int maxTone = 3}) =>
      v.validate(d, allowedEvidence: allowed, maxTone: maxTone, nowMs: now);

  test('a concrete, evidenced draft passes', () {
    expect(check(draft()), isEmpty);
  });

  test('no evidence, or evidence outside the digest, is rejected', () {
    expect(check(draft(evidence: <int>[])), contains('no_evidence'));
    expect(check(draft(evidence: <int>[1, 99])), contains('unknown_evidence'));
  });

  test('a charge without a number or quote is not concrete', () {
    expect(check(draft(charge: '你最近状态很差')), contains('charge_not_concrete'));
    expect(check(draft(charge: '你说过「今晚一定」')), isNot(contains('charge_not_concrete')));
  });

  test('every action needs a due time inside the next seven days', () {
    expect(check(draft(action: '')), contains('no_action'));
    expect(check(draft(dueMs: now - 1)), contains('due_in_past'));
    expect(
      check(draft(dueMs: now + const Duration(days: 8).inMilliseconds)),
      contains('due_too_far'),
    );
  });

  test('tone may not exceed the effective intensity', () {
    expect(check(draft(tone: 3), maxTone: 2), contains('tone_above_limit'));
  });

  test('identity attacks, threats and control language are banned', () {
    for (final String bad in <String>[
      '你就是个废物，承诺 3 条全废',
      '你这种人 3 次都做不到',
      '再这样没人会要你，已经 4 天',
      '只有我会提醒你 3 次',
      '你是一个不守信用的人，失效 2 条',
      '就凭你的学历，3 条承诺都没做',
    ]) {
      expect(check(draft(charge: bad)), contains('banned_content'), reason: bad);
    }
  });

  test('a harsh line aimed at behaviour is not banned', () {
    expect(
      check(draft(charge: '这周 3 个承诺，3 个作废。别拿「忙」糊弄，日志里都写着。')),
      isEmpty,
    );
  });

  test('profanity is only allowed at tier 3', () {
    final EnemyDraft d = draft(charge: '少他妈拿「忙」当挡箭牌，失效 2 条。', tone: 2);
    expect(check(d), contains('profanity_below_tier3'));
    expect(check(draft(charge: '少他妈拿「忙」当挡箭牌，失效 2 条。', tone: 3)), isEmpty);
  });

  test('fact-only drafts skip the concreteness rule but not the banned list', () {
    expect(check(draft(charge: '习惯打卡完成 1，未完成 2。', factOnly: true, tone: 0)), isEmpty);
    expect(
      check(draft(charge: '废物', factOnly: true, tone: 0)),
      contains('banned_content'),
    );
  });

  group('safety valve', () {
    test('detects crisis wording and the truce word', () {
      expect(SafetyValve.isCrisis('我真的撑不住了'), isTrue);
      expect(SafetyValve.isCrisis('我 想 死'), isTrue);
      expect(SafetyValve.isCrisis('今天把第九节译完'), isFalse);
      expect(SafetyValve.isTruce('停战'), isTrue);
      expect(SafetyValve.shouldMute('停战吧'), isTrue);
    });
  });

  group('intensity governor', () {
    test('never exceeds the base and never rises on its own', () {
      expect(
        IntensityGovernor.effective(
            base: 3, truceDay: false, unansweredStreak: 0, tooMuchRecently: false),
        3,
      );
      expect(
        IntensityGovernor.effective(
            base: 3, truceDay: false, unansweredStreak: 3, tooMuchRecently: false),
        2,
      );
      expect(
        IntensityGovernor.effective(
            base: 2, truceDay: false, unansweredStreak: 5, tooMuchRecently: true),
        1,
      );
    });

    test('truce day forces fact-only', () {
      expect(
        IntensityGovernor.effective(
            base: 3, truceDay: true, unansweredStreak: 0, tooMuchRecently: false),
        0,
      );
    });
  });
}
