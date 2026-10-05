import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/will_mirror_assistant_service.dart';
import 'package:quote_app/will_mirror/will_mirror_capability_catalog.dart';
import 'package:quote_app/will_mirror/will_mirror_example_repository.dart';
import 'package:quote_app/will_mirror/will_mirror_knowledge_repository.dart';
import 'package:quote_app/will_mirror/will_mirror_models.dart';
import 'package:quote_app/will_mirror/will_mirror_practice_engine.dart';
import 'package:quote_app/will_mirror/will_mirror_practice_intelligence_service.dart';
import 'package:quote_app/will_mirror/will_mirror_practice_models.dart';
import 'package:quote_app/services/unified_ai_service.dart';

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
        need: '作品集拖了三个月没有开始，联系邮箱 user@example.com',
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
        expect(route.theoryApplications, isNotEmpty);
        for (final theoryId in route.theoryIds) {
          expect(
            WillMirrorTheoryCatalog.byId,
            contains(theoryId),
            reason: '$theoryId 必须来自现有 KB',
          );
        }
      }
      expect(routes.first.action, contains('2 分钟'));
      expect(routes.first.action, contains('标题'));
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

  group('grounded AI planner', () {
    const profile = WillMirrorPracticeProfile(
      style: WillMirrorSupportStyle.gentle,
      interest: WillMirrorInterest.create,
      energyMinutes: 5,
    );

    test('AI turns retrieved concepts into case-specific routes and receipt',
        () async {
      final ai = _PracticeAi(_validPlanJson);
      final service = WillMirrorPracticeIntelligenceService(
        ai: ai,
        knowledge: _PracticeKnowledge(),
      );
      final draft = await service.generate(
        needType: WillMirrorNeedType.problem,
        need: '作品集拖了三个月没有开始，联系邮箱 user@example.com',
        desiredOutcome: '七天后有两页草稿',
        obstacle: '怕做不好',
        profile: profile,
        allowAi: true,
      );

      expect(ai.calls, 1);
      expect(ai.lastPrompt, isNot(contains('user@example.com')));
      expect(ai.lastPrompt, contains('[邮箱已隐藏]'));
      expect(draft.receipt.aiUsed, isTrue);
      expect(draft.receipt.model, contains('测试模型'));
      expect(draft.receipt.situationSummary, contains('完美'));
      expect(draft.routes, hasLength(3));
      expect(draft.routes.first.action, contains('空白文件'));
      for (final route in draft.routes) {
        expect(route.theoryApplications, isNotEmpty);
        expect(route.theoryApplications.first.application, contains('作品集'));
        expect(route.minutes, 5);
      }
    });

    test('invalid AI result is visibly replaced by grounded local routes',
        () async {
      final service = WillMirrorPracticeIntelligenceService(
        ai: _PracticeAi('{"routes": []}'),
        knowledge: _PracticeKnowledge(),
      );
      final draft = await service.generate(
        needType: WillMirrorNeedType.goal,
        need: '学习摄影',
        desiredOutcome: '',
        obstacle: '不知道第一步',
        profile: profile,
        allowAi: true,
      );

      expect(draft.receipt.aiRequested, isTrue);
      expect(draft.receipt.aiUsed, isFalse);
      expect(draft.receipt.fallbackReason, contains('本地知识规则已接管'));
      expect(draft.routes, hasLength(3));
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
      expect(item.whyItWorks, isNotEmpty);
      expect(item.theoryApplications, isNotEmpty);
      expect(item.generationReceipt, isNotEmpty);
      expect(item.result, isNotEmpty);
      expect(item.nextRevision, isNotEmpty);
    }
  });
}

class _PracticeAi extends UnifiedAiService {
  _PracticeAi(this.response);

  final String response;
  int calls = 0;
  String lastPrompt = '';

  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig({
    String? forcedProvider,
    String? forcedModel,
  }) async {
    return const UnifiedAiResolvedConfig(
      provider: 'test',
      apiKey: 'not-a-real-key',
      model: 'test-model',
      endpoint: 'https://example.invalid',
      label: '测试模型',
      displayModel: '测试模型',
      available: true,
    );
  }

  @override
  Future<String> generateText({
    required String prompt,
    required String purpose,
    String? systemPrompt,
    int maxTokens = 1800,
    bool expectJson = false,
    String? forcedProvider,
    String? forcedModel,
    double? temperature,
  }) async {
    calls++;
    lastPrompt = prompt;
    expect(prompt, contains('user_need'));
    expect(prompt, contains('knowledge'));
    return response;
  }
}

class _PracticeKnowledge extends WillMirrorKnowledgeRepository {
  @override
  Future<List<WillMirrorKnowledgePassage>> search(
    String query, {
    Set<WillMirrorRelation>? relations,
    Set<String>? modules,
    Set<WillMirrorEvidenceLevel>? levels,
    int limit = 8,
  }) async {
    return const <WillMirrorKnowledgePassage>[
      WillMirrorKnowledgePassage(
        recordId: 'SCH-B4-055-ACTION-CHARACTER',
        sourceId: 'schopenhauer',
        creator: '叔本华',
        workTitle: '作为意志和表象的世界',
        workPart: '第四卷',
        sectionRef: '§55',
        locatorText: '§55',
        originalText: '',
        zhTranslation: '',
        translationStatus: 'reviewed',
        evidenceLevel: WillMirrorEvidenceLevel.a,
        summary: '行动和生活序列帮助形成经验性的自我认识。',
        methodologicalImplication: '用行动检验叙述。',
        productRule: '生成可观察动作。',
        misuseBoundary: '一次行动不能宣布本质。',
        tags: <String>['行动'],
        modules: <String>['practice'],
        relations: <WillMirrorRelation>[],
        hypothesisCodes: <String>[],
        sourceFidelity: 1,
        rightsStatus: 'public-domain',
        canonicalUrl: '',
        contentSha256: 'test',
      ),
    ];
  }
}

const String _validPlanJson = '''
{
  "situation_summary": "当前更像完美压力阻挡了开始，这只是待验证解释。",
  "blind_spot_question": "如果这个版本永远不公开，你还会怕什么？",
  "routes": [
    {
      "type": "act_now",
      "title": "做一个不公开的第0版",
      "promise": "5分钟留下草稿",
      "action": "新建一个空白文件，写下作品集标题和三个栏目，到点就停。",
      "success_signal": "文件中有一个标题和三个栏目。",
      "output": "可再次打开的作品集骨架",
      "why_it_works": "先让行动产生证据，避免继续用想象评价成品。",
      "theory_ids": ["SCH-B4-055-ACTION-CHARACTER"],
      "theory_applications": [{
        "theory_id": "SCH-B4-055-ACTION-CHARACTER",
        "application": "用作品集的实际草稿检验口头愿望。",
        "reason": "行动证据能揭示真实阻碍。"
      }]
    },
    {
      "type": "understand_then_act",
      "title": "分离完美压力",
      "promise": "一问一动作",
      "action": "写下如果作品集永不公开最先会做什么，再执行答案中的最小一步。",
      "success_signal": "得到一个具体答案和一个现实痕迹。",
      "output": "阻碍线索与现实尝试",
      "why_it_works": "只追问能改变下一步的动机，不做本质判断。",
      "theory_ids": ["SCH-B2-029-MOTIVE"],
      "theory_applications": [{
        "theory_id": "SCH-B2-029-MOTIVE",
        "application": "围绕作品集打开文件这一具体动作追问。",
        "reason": "具体动机比抽象自我评价更能改变行动。"
      }]
    },
    {
      "type": "seven_day_experiment",
      "title": "七天现实验证",
      "promise": "至少三次反馈",
      "action": "七天内任选三天，每次为作品集增加一个标题或一张旧图。",
      "success_signal": "获得三次不同日期的行动或阻碍记录。",
      "output": "支持、反证和限制记录",
      "why_it_works": "跨日期事实减少一次状态的误导。",
      "theory_ids": ["SCH-B4-055-ACTION-CHARACTER"],
      "theory_applications": [{
        "theory_id": "SCH-B4-055-ACTION-CHARACTER",
        "application": "比较作品集在三次真实行动中的变化。",
        "reason": "重复选择比一次表态更可靠。"
      }]
    }
  ]
}
''';
