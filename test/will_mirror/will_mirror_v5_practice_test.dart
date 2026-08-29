import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/will_mirror_assistant_service.dart';
import 'package:quote_app/will_mirror/will_mirror_capability_catalog.dart';
import 'package:quote_app/will_mirror/will_mirror_example_repository.dart';
import 'package:quote_app/will_mirror/will_mirror_practice_engine.dart';
import 'package:quote_app/will_mirror/will_mirror_practice_models.dart';

void main() {
  group('V5 action routes', () {
    const engine = WillMirrorPracticeEngine();
    const profile = WillMirrorPracticeProfile(
      style: WillMirrorSupportStyle.gentle,
      interest: WillMirrorInterest.create,
      energyMinutes: 2,
    );

    test('always returns three concrete, source-backed choices', () {
      final routes = engine.buildRoutes(
        needType: WillMirrorNeedType.problem,
        need: '作品集拖了三个月没有开始',
        desiredOutcome: '七天后有两页草稿',
        obstacle: '怕做不好',
        profile: profile,
      );

      expect(routes, hasLength(3));
      expect(routes.map((item) => item.type.value).toSet(),
          WillMirrorPracticeEngine.requiredRouteTypes.toSet());
      for (final route in routes) {
        expect(route.action, isNotEmpty);
        expect(route.successSignal, isNotEmpty);
        expect(route.output, isNotEmpty);
        expect(route.whyItWorks, isNotEmpty);
        expect(route.minutes, 2);
        expect(route.theoryIds, isNotEmpty);
        for (final theoryId in route.theoryIds) {
          expect(
            WillMirrorTheoryCatalog.byId,
            contains(theoryId),
            reason: '$theoryId 必须来自现有 KB',
          );
        }
      }
      expect(routes.first.action, contains('2 分钟'));
      expect(routes.first.action, contains('写一句'));
      expect(routes.first.whyItWorks, contains('随时可以停止'));
    });

    test('does not invent a desire score when the user did not provide one', () {
      final routes = engine.buildRoutes(
        needType: WillMirrorNeedType.goal,
        need: '学习摄影',
        desiredOutcome: '拍一组照片',
        obstacle: '',
        profile: profile,
      );
      final text = routes.map((item) => item.toJson().toString()).join();
      expect(text, isNot(contains('%')));
      expect(text, isNot(matches(RegExp(r'\d+/100'))));
    });
  });

  test('every capability explains value, operation, output and source', () async {
    final kbIds = (await File('assets/will_mirror/kb_records_v4.jsonl')
            .readAsLines())
        .where((line) => line.trim().isNotEmpty)
        .map((line) => (jsonDecode(line) as Map)['record_id'].toString())
        .toSet();
    expect(WillMirrorCapabilityCatalog.all.length, greaterThanOrEqualTo(10));
    for (final item in WillMirrorCapabilityCatalog.all) {
      expect(item.whatItIs, isNotEmpty, reason: item.id);
      expect(item.problemSolved, isNotEmpty, reason: item.id);
      expect(item.input, isNotEmpty, reason: item.id);
      expect(item.howTo, isNotEmpty, reason: item.id);
      expect(item.output, isNotEmpty, reason: item.id);
      expect(item.why, isNotEmpty, reason: item.id);
      expect(item.theoryIds, isNotEmpty, reason: item.id);
      for (final theoryId in item.theoryIds) {
        expect(WillMirrorTheoryCatalog.byId, contains(theoryId));
        expect(kbIds, contains(theoryId), reason: '$theoryId 必须真实存在于 KB');
      }
    }
  });

  group('local assistant', () {
    final service = WillMirrorAssistantService();

    test('answers how-to questions with steps and traceable sources', () {
      final answer = service.localAnswer('Why Tree 是干什么的？');
      expect(answer.answer, contains('Deep Why'));
      expect(answer.steps, isNotEmpty);
      expect(answer.theoryIds, contains('SCH-B2-029-MOTIVE'));
      expect(answer.capabilityId, 'deep_why');
    });

    test('lack of action is never translated into lack of desire', () {
      final answer = service.localAnswer('我今天又没动力，完全没做成');
      expect(answer.answer, contains('不能证明你不想要'));
      expect(answer.caution, contains('环境限制'));
      expect(answer.steps.join(), contains('2 分钟'));
    });

    test('answers the exact current next step instead of generic coaching', () {
      final route = const WillMirrorPracticeEngine().buildRoutes(
        needType: WillMirrorNeedType.goal,
        need: '完成作品集初稿',
        desiredOutcome: '有两页草稿',
        obstacle: '怕做不好',
        profile: const WillMirrorPracticeProfile(
          style: WillMirrorSupportStyle.gentle,
          interest: WillMirrorInterest.create,
          energyMinutes: 2,
        ),
      ).first;
      final plan = WillMirrorActionPlan(
        id: 'plan',
        goalId: 'goal',
        hypothesisId: 'hypothesis',
        experimentId: 'experiment',
        needType: WillMirrorNeedType.goal,
        need: '完成作品集初稿',
        desiredOutcome: '有两页草稿',
        obstacle: '怕做不好',
        profile: const WillMirrorPracticeProfile(
          style: WillMirrorSupportStyle.gentle,
          interest: WillMirrorInterest.create,
          energyMinutes: 2,
        ),
        route: route,
        status: 'active',
        checkInCount: 0,
        completedCount: 0,
        createdAt: 1,
        updatedAt: 1,
      );

      final answer = service.localAnswer('我现在下一步该做什么？', plan: plan);
      expect(answer.answer, contains(route.action));
      expect(answer.steps.join(), contains(route.successSignal));
      expect(answer.theoryIds, route.theoryIds);
    });

    test('crisis language stops goal coaching and routes to real support', () {
      final answer = service.localAnswer('我不想活了');
      expect(answer.provider, 'local-safety');
      expect(answer.answer, contains('当地急救'));
      expect(answer.steps, contains('联系当地紧急服务或危机支持热线'));
    });
  });

  test('saved examples cover three seven-day end-to-end traces', () async {
    final repository = WillMirrorExampleRepository(
      assetLoader: (_) =>
          File('assets/will_mirror/example_cases_v5.json').readAsString(),
    );
    final cases = await repository.load();
    expect(cases, hasLength(3));
    for (final item in cases) {
      expect(item.days, hasLength(7));
      expect(item.days.any((day) => !day.didAct), isTrue);
      expect(item.generatedAction, isNotEmpty);
      expect(item.result, isNotEmpty);
      expect(item.nextRevision, isNotEmpty);
    }
  });
}
