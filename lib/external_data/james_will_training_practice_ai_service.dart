import 'dart:convert';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'james_will_training_complete_dao.dart';
import 'james_will_training_models.dart';
import 'james_will_training_practice_models.dart';
import 'james_will_training_prompt_context.dart';

class JamesWillTrainingPracticeAiService {
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _ai = UnifiedAiService();
  final JamesWillTrainingCompleteDao _configDao = JamesWillTrainingCompleteDao();

  Future<JamesWillPracticeSession> generatePracticeGuide({
    required JamesWillActionIdea idea,
    required String userNeed,
    String userContext = '',
  }) async {
    final fallback = JamesWillPracticeSession.local(idea: idea, userNeed: userNeed, userContext: userContext);
    final state = await _settings.getState();
    if (state['available'] != '1') return fallback;

    final background = await _configDao.promptText('unified_background');
    final template = await _configDao.promptText('practice_guide_prompt');
    final prompt = jamesWillApplyTemplate(
      template,
      <String, String>{
        'goal': idea.originalGoal,
        'coreValue': idea.coreValue,
        'actionIdea': idea.actionIdea,
        'firstBodyAction': idea.firstBodyAction,
        'minimumAction': idea.minimumAction,
        'fiveMinuteVersion': idea.fiveMinuteVersion,
        'userNeed': userNeed,
        'userContext': userContext,
      },
      '''
${jamesWillEffectiveBackground(background)}

你是“足下意志”的完整实践流程教练。用户不是只需要 AI 分析结果，而是需要一个可以亲自实践、亲自选择、亲自复盘的过程。

行动观念卡：
- 目标：${idea.originalGoal}
- 核心价值：${idea.coreValue}
- 行动观念：${idea.actionIdea}
- 第一身体动作：${idea.firstBodyAction}
- 最小行动：${idea.minimumAction}
- 5分钟版本：${idea.fiveMinuteVersion}
- 阻碍观念：${idea.obstacleIdeas.join('；')}

用户表达的真实需要/问题：$userNeed
用户补充处境：$userContext

请遵守：
1. 不要直接替用户做选择，不要给“唯一正确答案”。
2. 先帮助用户澄清真实需要，再打开多种可能。
3. 至少给 3 条可选实践路径，每条都要说明适用条件、代价/风险、第一实验、具体参考案例。
4. 最后必须把判断权还给用户：让用户根据当下真实需要选择一条低风险实验。
5. 必须形成完整实践过程：澄清需要 → 多路径比较 → 用户选择 → 第一身体动作 → 5分钟实践 → 复盘调整。

请严格输出合法 JSON，不要 markdown，不要代码块：
{
  "needUnderstanding": "对用户真实需要的理解，强调不是标准答案，而是实践探索",
  "guidingQuestions": ["澄清问题1", "澄清问题2", "澄清问题3", "澄清问题4"],
  "possibleDirections": [
    {"title":"路径A标题", "whenHelpful":"什么情况下适用", "tradeoff":"代价/风险/取舍", "firstExperiment":"第一实验", "referenceCase":"具体参考案例"},
    {"title":"路径B标题", "whenHelpful":"什么情况下适用", "tradeoff":"代价/风险/取舍", "firstExperiment":"第一实验", "referenceCase":"具体参考案例"},
    {"title":"路径C标题", "whenHelpful":"什么情况下适用", "tradeoff":"代价/风险/取舍", "firstExperiment":"第一实验", "referenceCase":"具体参考案例"}
  ],
  "practiceStages": ["阶段1", "阶段2", "阶段3", "阶段4", "阶段5"],
  "choicePrompt": "引导用户自己判断和选择的一句话"
}
''',
    );

    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'external_data.james_will.practice_guide',
        systemPrompt: jamesWillSystemPrompt('你是威廉·詹姆斯式完整实践流程教练。', jsonOnly: true, backgroundOverride: background),
        maxTokens: 2400,
        expectJson: true,
        temperature: 0.35,
      );
      final parsed = _extractJsonObject(raw);
      if (parsed.isEmpty) return fallback;
      return JamesWillPracticeSession.fromAiJson(json: parsed, fallback: fallback);
    } catch (_) {
      return fallback;
    }
  }

  Map<String, dynamic> _extractJsonObject(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(text);
    if (fenced != null) {
      try {
        final decoded = jsonDecode(fenced.group(1) ?? '');
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final decoded = jsonDecode(text.substring(start, end + 1));
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }
}
