import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_ai_service.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_principles.dart';
import 'self_os_domain_test.dart' show plannedCase;
import 'self_os_principles_test.dart' show experienceSource, principleFor;

void main() {
  test('T327–T330 AI输出只生成暂定候选，支持反例和条件均可回链', () async {
    final source = experienceSource(),
        counter = experienceSource(),
        c = plannedCase();
    final row = {
      ...principleFor([source, counter], counters: [counter.reviews.single.id]),
      'comparability': '任务相近，但协作和健康条件可能不同',
      'counterSearch': '已检查另一条相反经历，保留情境差异',
      'status': 'user_accepted',
      'maturity': 'permanent'
    };
    final ai = SelfOsAiService(generate: (
        {required prompt,
        required purpose,
        required systemPrompt,
        required maxTokens}) async {
      expect(prompt, contains(source.reviews.single.id));
      expect(prompt, contains(counter.reviews.single.id));
      return jsonEncode({
        'principles': [row],
        'unknowns': ['现场作用未知']
      });
    });
    final results = await ai.principleCandidates(c, [source, counter, c]);
    expect(results.single['status'], 'draft');
    expect(results.single['maturity'], 'tentative');
    expect(results.single['evidenceIds'], [source.reviews.single.id]);
    expect(results.single['counterEvidenceIds'], [counter.reviews.single.id]);
    expect(c.reviews, isEmpty);
  });

  for (final invalid in [
    'fake',
    'future',
    'unshared',
    'withdrawn',
    'too_many'
  ]) {
    test('来源校验拒绝 $invalid，模型不能伪造权限或事实', () async {
      final source = experienceSource(), c = plannedCase();
      final row = {
        ...principleFor([source]),
        'comparability': '同类任务',
        'counterSearch': '检查后未确认反例'
      };
      switch (invalid) {
        case 'fake':
          row['evidenceIds'] = ['made-up'];
        case 'future':
          row['evidenceIds'] = ['future-record'];
          final j = source.reviews.single.toJson();
          j['id'] = 'future-record';
          j['createdAt'] =
              DateTime.now().add(const Duration(days: 1)).toIso8601String();
          source.reviews.add(SelfOsReview.fromJson(j));
        case 'unshared':
          final other = experienceSource(shared: false);
          row['evidenceIds'] = [other.reviews.single.id];
        case 'withdrawn':
          source.reviews.single.notes['experienceWithdrawn'] = 'yes';
          // Retain a visible allowed record so an actual candidate validation is reached.
          final other = experienceSource();
          source.reviews.add(other.reviews.single);
      }
      final ai = SelfOsAiService(
          generate: (
                  {required prompt,
                  required purpose,
                  required systemPrompt,
                  required maxTokens}) async =>
              jsonEncode({
                'principles':
                    List.generate(invalid == 'too_many' ? 4 : 1, (_) => row)
              }));
      await expectLater(
          ai.principleCandidates(c, [source, c]), throwsFormatException);
    });
  }

  test('T343 无可靠经验可以零原则，且不调用远程服务', () async {
    var calls = 0;
    final ai = SelfOsAiService(generate: (
        {required prompt,
        required purpose,
        required systemPrompt,
        required maxTokens}) async {
      calls++;
      return '{}';
    });
    expect(await ai.principleCandidates(plannedCase(), []), isEmpty);
    expect(calls, 0);
  });

  test('T331/T339/T340 AI上下文排除拒绝、缺源、旧版本与未授权跨案例内容', () async {
    final source = experienceSource(),
        private = experienceSource(shared: false),
        c = plannedCase();
    final accepted = principleFor([source])..['rule'] = 'ACCEPTED_CUE';
    final rejected = principleFor([source])
      ..['rule'] = 'REJECTED_CUE'
      ..['status'] = 'user_rejected';
    final draft = principleFor([source], accepted: false)
      ..['rule'] = 'DRAFT_CUE';
    final stale = principleFor([source])
      ..['rule'] = 'STALE_CUE'
      ..['stale'] = true;
    final profile = SelfOsProfile()
      ..principles.addAll([accepted, rejected, draft, stale]);
    final payloads = <String>[];
    final ai = SelfOsAiService(generate: (
        {required prompt,
        required purpose,
        required systemPrompt,
        required maxTokens}) async {
      payloads.add(prompt);
      return '{"suggestions":[{"field":"firstAction","value":"先核实条件","reason":"待核实"}]}';
    });
    await ai.suggest(c, [source, private, c], 'action', profile: profile);
    final prompt = payloads.single;
    expect(prompt, contains('ACCEPTED_CUE'));
    for (final forbidden in [
      'REJECTED_CUE',
      'DRAFT_CUE',
      'STALE_CUE',
      private.reviews.single.id
    ]) {
      expect(prompt, isNot(contains(forbidden)));
    }
    // Outbound filtering is a copy; user history and rejected records stay editable.
    expect(profile.principles, hasLength(4));
    source.reviews.single.notes['experienceWithdrawn'] = 'yes';
    payloads.clear();
    await ai.suggest(c, [source, c], 'action', profile: profile);
    expect(payloads.single, isNot(contains('ACCEPTED_CUE')));
    expect(payloads.single, isNot(contains(source.reviews.single.id)));
  });

  test('T361/T362 关闭远程分析阻止全部API入口，不妨碍本地原则操作', () async {
    var calls = 0;
    final ai = SelfOsAiService(generate: (
        {required prompt,
        required purpose,
        required systemPrompt,
        required maxTokens}) async {
      calls++;
      return '{}';
    });
    final c = plannedCase()..v37.settings['allowRemoteAnalysis'] = false;
    final profile = SelfOsProfile();
    await expectLater(ai.discover(c, []), throwsFormatException);
    await expectLater(
        ai.motives(c, [], profile: profile), throwsFormatException);
    await expectLater(
        ai.suggest(c, [], 'action', profile: profile), throwsFormatException);
    await expectLater(
        ai.analyseV37(c, [], profile, 'gmrc'), throwsFormatException);
    await expectLater(ai.guide(c, [], profile), throwsFormatException);
    await expectLater(ai.principleCandidates(c, []), throwsFormatException);
    expect(calls, 0);
    expect(SelfOsPrinciples.eligible(profile, [c], c), isEmpty);
  });
}
