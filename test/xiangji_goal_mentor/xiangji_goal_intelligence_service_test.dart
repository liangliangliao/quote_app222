import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_goal_examples.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_goal_intelligence_service.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_grounded_ai_service.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_knowledge_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late XiangjiKnowledgeCatalog catalog;

  setUpAll(() async {
    catalog = await XiangjiKnowledgeRepository().load();
  });

  test('turns one need into three concrete and source-backed local routes',
      () async {
    final bundle = await XiangjiGoalIntelligenceService().generate(
      need: '我想恢复写作，但总担心写不好。',
      desiredOutcome: '七天留下三次写作痕迹。',
      obstacle: '早晨时间不稳定。',
      profile: const XiangjiGoalSupportProfile(
        interest: XiangjiGoalInterest.create,
        tone: XiangjiSupportTone.gentle,
        minutes: 5,
      ),
      catalog: catalog,
      allowAi: false,
    );

    expect(bundle.routes, hasLength(3));
    expect(bundle.routes.map((item) => item.id).toSet(), hasLength(3));
    expect(bundle.routes.map((item) => item.mentorId).toSet(), hasLength(3));
    expect(bundle.routes.map((item) => item.draft.step.actionText).toSet(),
        hasLength(3));
    for (final route in bundle.routes) {
      expect(route.draft.step.actionText, contains(RegExp(r'\d')));
      expect(route.output, isNotEmpty);
      expect(route.successSignal, isNotEmpty);
      expect(route.applications, isNotEmpty);
      expect(route.applications.single.locator, isNotEmpty);
      expect(route.applications.single.caseApplication, contains('写作'));
      expect(route.applications.single.boundary, isNotEmpty);
    }
    expect(bundle.receipt.aiUsed, isFalse);
    expect(bundle.receipt.status, 'local_selected');
  });

  test('uses valid grounded AI output and exposes a truthful receipt',
      () async {
    final service = XiangjiGoalIntelligenceService(
      generator: ({
        required String systemPrompt,
        required String prompt,
        String? forcedProvider,
      }) async {
        final payload = jsonDecode(prompt) as Map<String, dynamic>;
        final candidates = payload['candidate_routes'] as List<dynamic>;
        final routes = candidates.map((raw) {
          final candidate = Map<String, dynamic>.from(raw as Map);
          final evidence = Map<String, dynamic>.from(
            (candidate['allowed_evidence'] as List<dynamic>).first as Map,
          );
          return <String, Object?>{
            'id': candidate['id'],
            'mentor_id': candidate['mentor_id'],
            'title': '情境化 ${candidate['id']}',
            'understanding': '先把愿望变成一次现实检验，再根据证据调整。',
            'blind_spot': '现在缺少的是现实证据，而不是更多自我评价。',
            'action': '用 6 分钟完成一份可以继续修改的现实草稿。',
            'success_signal': '文件中出现一个可继续修改的草稿。',
            'output': '一份带日期的草稿文件',
            'why_it_works': '它把知识判断转成今天可验证的现实结果。',
            'theory_applications': <Object?>[
              <String, Object?>{
                'evidence_id': evidence['evidence_id'],
                'case_application': '把恢复写作理解为生成草稿证据，而非证明能力。',
                'why_this_action': '先产生草稿，现实反馈才能改变下一轮行动。',
              },
            ],
          };
        }).toList(growable: false);
        return XiangjiGeneratedText(
          text: jsonEncode(<String, Object?>{
            'situation_summary': '用户想恢复写作，但评价压力阻止了开始。',
            'blind_spot_question': '如果不要求写好，今天最小的可见产出是什么？',
            'routes': routes,
          }),
          provider: 'openai',
          modelLabel: '测试模型',
        );
      },
    );

    final bundle = await service.generate(
      need: '我想恢复写作。',
      desiredOutcome: '留下三次草稿。',
      obstacle: '担心写不好。',
      profile: const XiangjiGoalSupportProfile(
        interest: XiangjiGoalInterest.create,
        tone: XiangjiSupportTone.curious,
        minutes: 5,
      ),
      catalog: catalog,
      allowAi: true,
    );

    expect(bundle.receipt.aiRequested, isTrue);
    expect(bundle.receipt.aiUsed, isTrue);
    expect(bundle.receipt.provider, 'openai');
    expect(bundle.receipt.model, '测试模型');
    expect(bundle.receipt.knowledgeIds, isNotEmpty);
    expect(bundle.routes.singleWhere((item) => item.id == 'direct_output').draft.step.actionText,
        contains('6 分钟'));
  });

  test('recursively redacts direct identifiers before any AI request',
      () async {
    var capturedPrompt = '';
    final service = XiangjiGoalIntelligenceService(
      generator: ({
        required String systemPrompt,
        required String prompt,
        String? forcedProvider,
      }) async {
        capturedPrompt = prompt;
        return const XiangjiGeneratedText(
          text: '',
          provider: 'local',
          modelLabel: '本地',
        );
      },
    );

    final bundle = await service.generate(
      need: '请联系 me@example.com 帮我推进目标。',
      desiredOutcome: '回复手机号 13812345678。',
      obstacle: '证件号 11010519491231002X 写在资料里。',
      profile: const XiangjiGoalSupportProfile(
        interest: XiangjiGoalInterest.career,
        tone: XiangjiSupportTone.practical,
        minutes: 10,
      ),
      catalog: catalog,
      allowAi: true,
    );

    expect(capturedPrompt, isNot(contains('me@example.com')));
    expect(capturedPrompt, isNot(contains('13812345678')));
    expect(capturedPrompt, isNot(contains('11010519491231002X')));
    expect(capturedPrompt, contains('[邮箱已隐藏]'));
    expect(capturedPrompt, contains('[手机号已隐藏]'));
    expect(capturedPrompt, contains('[证件号已隐藏]'));
    expect(bundle.receipt.status, 'local_fallback');
  });

  test('rejects ungrounded AI structure and visibly falls back', () async {
    final service = XiangjiGoalIntelligenceService(
      generator: ({
        required String systemPrompt,
        required String prompt,
        String? forcedProvider,
      }) async => const XiangjiGeneratedText(
        text: '{"situation_summary":"空泛建议","routes":[]}',
        provider: 'test',
        modelLabel: '坏模型',
      ),
    );
    final bundle = await service.generate(
      need: '我想更稳定地学习。',
      desiredOutcome: '',
      obstacle: '',
      profile: const XiangjiGoalSupportProfile(
        interest: XiangjiGoalInterest.learn,
        tone: XiangjiSupportTone.gentle,
        minutes: 5,
      ),
      catalog: catalog,
      allowAi: true,
    );
    expect(bundle.receipt.aiUsed, isFalse);
    expect(bundle.receipt.fallbackReason, contains('本地规则已接管'));
    expect(bundle.routes, hasLength(3));
  });

  test('assistant gives the exact current step and recovery boundary',
      () async {
    final service = XiangjiGoalIntelligenceService();
    final bundle = await service.generate(
      need: '我想恢复写作。',
      desiredOutcome: '',
      obstacle: '',
      profile: const XiangjiGoalSupportProfile(
        interest: XiangjiGoalInterest.create,
        tone: XiangjiSupportTone.gentle,
        minutes: 5,
      ),
      catalog: catalog,
      allowAi: false,
    );
    final route = bundle.routes.first;
    final now = await service.answer(
      question: '我现在该做什么？',
      catalog: catalog,
      step: route.draft.step,
      guidance: route.draft.guidance,
    );
    final blocked = await service.answer(
      question: '我卡住了怎么办？',
      catalog: catalog,
      step: route.draft.step,
      guidance: route.draft.guidance,
    );
    expect(now.text, contains(route.draft.step.actionText));
    expect(now.text, contains(route.draft.step.minimumDone));
    expect(blocked.text, contains('不要评价自己'));
    expect(blocked.text, contains(route.draft.step.smallerVariant));
  });

  test('built-in examples preserve seven-day reality and revision traces', () {
    expect(xiangjiGoalExamples, hasLength(3));
    for (final example in xiangjiGoalExamples) {
      expect(example.need, isNotEmpty);
      expect(example.desiredOutcome, isNotEmpty);
      expect(example.obstacle, isNotEmpty);
      expect(example.expectedOutput, isNotEmpty);
      expect(example.sevenDayTrace, hasLength(7));
      expect(example.sevenDayTrace.join(), anyOf(contains('没开始'), contains('未获回复'), contains('没有开口')));
      expect(example.review, isNotEmpty);
    }
  });

  test('planning policy rejects manipulation and product dependency', () {
    final combined = XiangjiGoalIntelligenceService.capabilities
        .map((item) => '${item.purpose}${item.why}')
        .join();
    for (final forbidden in <String>['羞耻', '威胁', '敌人刺激', '离不开向己', '断签惩罚']) {
      expect(combined, isNot(contains(forbidden)));
    }
  });
}
