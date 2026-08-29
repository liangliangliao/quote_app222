import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'will_mirror_capability_catalog.dart';
import 'will_mirror_knowledge_repository.dart';
import 'will_mirror_practice_engine.dart';
import 'will_mirror_practice_models.dart';

abstract class WillMirrorPracticeGenerator {
  Future<WillMirrorPracticeDraft> generate({
    required WillMirrorNeedType needType,
    required String need,
    required String desiredOutcome,
    required String obstacle,
    required WillMirrorPracticeProfile profile,
    required bool allowAi,
  });
}

class WillMirrorPracticeIntelligenceService
    implements WillMirrorPracticeGenerator {
  WillMirrorPracticeIntelligenceService({
    WillMirrorPracticeEngine? engine,
    WillMirrorKnowledgeRepository? knowledge,
    UnifiedAiService? ai,
  })  : _engine = engine ?? const WillMirrorPracticeEngine(),
        _knowledge = knowledge ?? WillMirrorKnowledgeRepository(),
        _ai = ai ?? UnifiedAiService();

  final WillMirrorPracticeEngine _engine;
  final WillMirrorKnowledgeRepository _knowledge;
  final UnifiedAiService _ai;

  @override
  Future<WillMirrorPracticeDraft> generate({
    required WillMirrorNeedType needType,
    required String need,
    required String desiredOutcome,
    required String obstacle,
    required WillMirrorPracticeProfile profile,
    required bool allowAi,
  }) async {
    final fallbackRoutes = _engine.buildRoutes(
      needType: needType,
      need: need,
      desiredOutcome: desiredOutcome,
      obstacle: obstacle,
      profile: profile,
    );
    final localKnowledgeIds = fallbackRoutes
        .expand((route) => route.theoryIds)
        .toSet()
        .toList(growable: false);
    final localSummary = _engine.localSituationSummary(
      needType: needType,
      need: need,
      desiredOutcome: desiredOutcome,
      obstacle: obstacle,
    );
    final blindSpot = _engine.localBlindSpotQuestion(obstacle);

    WillMirrorPracticeDraft localDraft({
      bool requested = false,
      String reason = '',
    }) {
      return WillMirrorPracticeDraft(
        routes: fallbackRoutes,
        receipt: WillMirrorIntelligenceReceipt.local(
          aiRequested: requested,
          knowledgeIds: localKnowledgeIds,
          generatedAt: DateTime.now().millisecondsSinceEpoch,
          situationSummary: localSummary,
          blindSpotQuestion: blindSpot,
          fallbackReason: reason,
        ),
      );
    }

    if (!allowAi) return localDraft();

    try {
      final config = await _ai.resolveGlobalConfig();
      if (!config.available) {
        return localDraft(
          requested: true,
          reason: '未检测到可用的 AI 配置，本次由本地知识规则完成。',
        );
      }
      final query = <String>[
        need,
        desiredOutcome,
        obstacle,
        profile.interest.label,
        '动机 行动 反证 现实实验',
      ].where((item) => item.trim().isNotEmpty).join(' ');
      final passages = await _knowledge.search(query, limit: 10);
      final allowedIds = <String>{
        ...localKnowledgeIds,
        ...passages.map((item) => item.recordId),
      };
      final payload = <String, dynamic>{
        'user_need': <String, dynamic>{
          'type': needType.value,
          'need': _redact(need.trim()),
          'desired_outcome': _redact(desiredOutcome.trim()),
          'reported_obstacle': _redact(obstacle.trim()),
          'interest': profile.interest.value,
          'support_style': profile.style.value,
          'available_minutes': profile.energyMinutes,
        },
        'knowledge': passages.map((item) {
          return <String, dynamic>{
            'id': item.recordId,
            'creator': item.creator,
            'section': item.sectionRef,
            'summary': item.summary,
            'product_rule': item.productRule,
            'misuse_boundary': item.misuseBoundary,
          };
        }).toList(growable: false),
        'local_safe_candidates': fallbackRoutes
            .map((item) => item.toJson())
            .toList(growable: false),
        'required_schema': <String, dynamic>{
          'situation_summary': 'string',
          'blind_spot_question': 'string',
          'routes': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'act_now | understand_then_act | seven_day_experiment',
              'title': 'string',
              'promise': 'string',
              'action': 'observable action string',
              'success_signal': 'observable completion string',
              'output': 'real artifact string',
              'why_it_works': 'case-specific mechanism string',
              'theory_ids': <String>[],
              'theory_applications': <Map<String, dynamic>>[
                <String, dynamic>{
                  'theory_id': 'allowed knowledge id',
                  'application': 'how the concept changes this case',
                  'reason': 'why it leads to this exact action',
                },
              ],
            },
          ],
        },
      };
      final raw = await _ai.generateText(
        prompt: jsonEncode(payload),
        purpose: 'will_mirror.v5.grounded_practice_plan',
        systemPrompt: _systemPrompt,
        maxTokens: 2200,
        expectJson: true,
        temperature: 0.15,
      );
      final decoded = _decodeObject(raw);
      if (decoded == null) {
        return localDraft(
          requested: true,
          reason: 'AI 返回内容无法通过结构校验，本地知识规则已接管。',
        );
      }
      final routes = _decodeRoutes(
        decoded['routes'],
        allowedIds: allowedIds,
        fallbacks: fallbackRoutes,
        minutes: profile.energyMinutes,
      );
      if (routes == null) {
        return localDraft(
          requested: true,
          reason: 'AI 方案缺少具体动作、现实产出或有效理论依据，本地知识规则已接管。',
        );
      }
      final summary = (decoded['situation_summary'] ?? '').toString().trim();
      final question = (decoded['blind_spot_question'] ?? '').toString().trim();
      if (summary.isEmpty || question.isEmpty || _containsForbiddenClaim(summary)) {
        return localDraft(
          requested: true,
          reason: 'AI 分析未通过认识边界校验，本地知识规则已接管。',
        );
      }
      return WillMirrorPracticeDraft(
        routes: routes,
        receipt: WillMirrorIntelligenceReceipt(
          aiRequested: true,
          aiUsed: true,
          provider: config.provider,
          model: config.label,
          status: 'ai_grounded',
          knowledgeIds: routes
              .expand((route) => route.theoryIds)
              .toSet()
              .toList(growable: false),
          generatedAt: DateTime.now().millisecondsSinceEpoch,
          situationSummary: summary,
          blindSpotQuestion: question,
        ),
      );
    } catch (error) {
      return localDraft(
        requested: true,
        reason: 'AI 调用失败，本地知识规则已接管：${_safeError(error)}',
      );
    }
  }

  static List<WillMirrorActionRoute>? _decodeRoutes(
    Object? raw, {
    required Set<String> allowedIds,
    required List<WillMirrorActionRoute> fallbacks,
    required int minutes,
  }) {
    if (raw is! List) return null;
    final byType = <WillMirrorRouteType, WillMirrorActionRoute>{};
    for (final value in raw.whereType<Map>()) {
      final item = value.map((key, value) => MapEntry(key.toString(), value));
      final type = parseWillMirrorRouteType(item['type']);
      if (byType.containsKey(type)) return null;
      final fallback = fallbacks.firstWhere((route) => route.type == type);
      final action = (item['action'] ?? '').toString().trim();
      final signal = (item['success_signal'] ?? '').toString().trim();
      final output = (item['output'] ?? '').toString().trim();
      final why = (item['why_it_works'] ?? '').toString().trim();
      final theoryIds = _strings(item['theory_ids'])
          .where(allowedIds.contains)
          .toSet()
          .toList(growable: false);
      if (action.isEmpty ||
          signal.isEmpty ||
          output.isEmpty ||
          why.isEmpty ||
          theoryIds.isEmpty ||
          _containsForbiddenClaim('$action $why')) {
        return null;
      }
      final applications = _decodeApplications(
        item['theory_applications'],
        allowedIds: theoryIds.toSet(),
      );
      byType[type] = fallback.copyWith(
        title: _textOr(item['title'], fallback.title),
        promise: _textOr(item['promise'], fallback.promise),
        action: action,
        successSignal: signal,
        output: output,
        whyItWorks: why,
        minutes: minutes,
        theoryIds: theoryIds,
        theoryApplications: applications.isEmpty
            ? fallback.theoryApplications
                .where((entry) => theoryIds.contains(entry.theoryId))
                .toList(growable: false)
            : applications,
      );
    }
    if (byType.length != WillMirrorPracticeEngine.requiredRouteTypes.length) {
      return null;
    }
    return fallbacks.map((item) => byType[item.type]!).toList(growable: false);
  }

  static List<WillMirrorTheoryApplication> _decodeApplications(
    Object? raw, {
    required Set<String> allowedIds,
  }) {
    if (raw is! List) return const <WillMirrorTheoryApplication>[];
    return raw.whereType<Map>().map((value) {
      final item = value.map((key, value) => MapEntry(key.toString(), value));
      final id = (item['theory_id'] ?? '').toString();
      if (!allowedIds.contains(id)) return null;
      final application = (item['application'] ?? '').toString().trim();
      final reason = (item['reason'] ?? '').toString().trim();
      if (application.isEmpty || reason.isEmpty) return null;
      return WillMirrorTheoryApplication(
        theoryId: id,
        concept: WillMirrorTheoryCatalog.find(id)?.shortLabel ?? id,
        application: application,
        reason: reason,
      );
    }).whereType<WillMirrorTheoryApplication>().toList(growable: false);
  }

  static String _textOr(Object? value, String fallback) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static Map<String, dynamic>? _decodeObject(String raw) {
    var text = raw.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    text = text.substring(start, end + 1);
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return null;
    }
  }

  static List<String> _strings(Object? value) => value is List
      ? value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
      : const <String>[];

  static bool _containsForbiddenClaim(String value) {
    return <String>[
      '你的本质是',
      '真正的你就是',
      '唯一真实需要',
      '童年根因是',
      '诊断为',
      '必须坚持',
    ].any(value.contains);
  }

  static String _safeError(Object error) {
    final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '未知错误';
    return text.length <= 80 ? text : '${text.substring(0, 80)}…';
  }

  static String _redact(String value) {
    return value
        .replaceAll(
          RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
          '[邮箱已隐藏]',
        )
        .replaceAll(RegExp(r'\b1[3-9]\d{9}\b'), '[手机号已隐藏]')
        .replaceAll(RegExp(r'\b\d{17}[0-9Xx]\b'), '[证件号已隐藏]');
  }

  static const String _systemPrompt = '''
你是《意志之镜》的“思想到行动”生成器。只输出一个 JSON 对象。

任务：把用户的一个目标或问题转换成三个不同、低压力、可在现实中完成并产生结果的方案。你不是在解释理论，而是在受理论约束地设计今天的行动。

硬规则：
1. 只能引用输入 knowledge 或 local_safe_candidates 中存在的 theory id，不得发明思想家、概念、引文或功能。
2. 必须恰好输出 act_now、understand_then_act、seven_day_experiment 三种方案各一个。
3. 每个方案必须明确：今天做什么、到哪里算完成、得到什么现实产出、为什么对这个用户有效。
4. theory_applications 必须逐条说明“概念怎样改变本案例”和“为什么推出这一步”，不能只复述理论名称。
5. 不得宣布用户的本质、唯一真实需要、固定人格、创伤根因或心理诊断。
6. 不得把没行动解释为不够想要；保留能力、时间、责任、资源、关系、环境和安全边界。
7. 不得使用羞耻、威胁、比较、惩罚、连续打卡压力或制造依赖的语言。
8. 行动必须具体到可观察的动词和产出，适配输入的时间预算；避免“思考一下、努力、坚持、提升自己”等空泛建议。
9. situation_summary 是暂定问题框架；blind_spot_question 只提出一个能改变下一步的关键问题。
''';
}
