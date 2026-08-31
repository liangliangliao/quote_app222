import 'dart:convert';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'xiangji_practical_product.dart';
import 'xiangji_privacy_guard.dart';

/// Answers product-usage questions from the same versioned feature contract
/// used by the UI. It always has an offline answer; configured AI may improve
/// wording, but cannot invent a feature, route, source, or psychological claim.
class XiangjiUsageAssistantService {
  XiangjiUsageAssistantService({
    GlobalAiSettings? settings,
    UnifiedAiService? ai,
    XiangjiCloudPrivacyGuard privacyGuard = const XiangjiCloudPrivacyGuard(),
  })  : _settings = settings ?? GlobalAiSettings(),
        _ai = ai ?? UnifiedAiService(),
        _privacyGuard = privacyGuard;

  final GlobalAiSettings _settings;
  final UnifiedAiService _ai;
  final XiangjiCloudPrivacyGuard _privacyGuard;

  Future<XiangjiUsageAssistantAnswer> answer(
    String question, {
    bool authorizedSensitiveContext = false,
  }) async {
    final local = XiangjiPracticalProductContract.answerLocally(question);
    final value = question.trim();
    if (value.isEmpty) return local;
    try {
      final state = await _settings.getState();
      if (state['available'] != '1') return local;
      final privacy = _privacyGuard.assess(
        task: value,
        additionalContext: const <String, Object?>{
          'scope': 'future_strategist_product_usage_only',
        },
      );
      if (privacy.containsSensitiveCategory && !authorizedSensitiveContext) {
        return local;
      }
      final safeQuestion = _privacyGuard.sanitizeText(value).value;
      final raw = await _ai.generateChatMessages(
        purpose: 'xiangji_future_strategist.usage_assistant',
        maxTokens: 900,
        temperature: 0.1,
        messages: <UnifiedAiChatMessage>[
          UnifiedAiChatMessage(
            role: 'system',
            content: '''
你是“向己·未来军师”的产品使用助手。只回答模块是什么、何时用、填什么、怎样操作、会产出什么、依据什么，以及怎样进入正确流程。

硬约束：
1. 只能使用下方产品合同，不得发明功能、按钮、知识来源或完成状态。
2. 默认引导用户回到四步闭环：说出需要、选择办法、只做一步、回报现实并改判。
3. 先给直接答案，再给不超过 4 个短步骤；不要要求用户理解内部模型。
4. 不诊断人格、疾病或创伤，不羞辱、不威胁、不制造依赖。
5. 只输出 JSON：{"answer":"...","steps":["..."],"guide_id":"已存在的 guide id"}。

产品合同：
${XiangjiPracticalProductContract.assistantKnowledgeJson()}
''',
          ),
          UnifiedAiChatMessage(
            role: 'user',
            content: jsonEncode(<String, Object?>{
              'question': safeQuestion,
              'local_route': local.guideId,
            }),
          ),
        ],
      );
      final parsed = _parseObject(raw);
      if (parsed == null) return local;
      final guideId = (parsed['guide_id'] ?? '').toString();
      if (!XiangjiPracticalProductContract.featureGuides
          .any((guide) => guide.id == guideId)) {
        return local;
      }
      final guide = XiangjiPracticalProductContract.guideForId(guideId);
      final answer = (parsed['answer'] ?? '').toString().trim();
      final steps = _strings(parsed['steps']).take(4).toList();
      if (answer.isEmpty || steps.isEmpty) return local;
      return XiangjiUsageAssistantAnswer(
        title: guide.title,
        answer: answer,
        steps: steps,
        guideId: guide.id,
        coreConceptIds: guide.coreConceptIds,
        knowledgeSource: guide.knowledgeSource,
        startPrompt: guide.startPrompt,
        destination: guide.destination,
        aiEnhanced: true,
      );
    } catch (_) {
      return local;
    }
  }

  Map<String, Object?>? _parseObject(String raw) {
    var value = raw.trim();
    if (value.startsWith('```')) {
      value = value.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      value = value.replaceFirst(RegExp(r'\s*```$'), '');
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      return decoded.map(
        (key, dynamic item) => MapEntry(key.toString(), item as Object?),
      );
    } catch (_) {
      return null;
    }
  }

  List<String> _strings(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
