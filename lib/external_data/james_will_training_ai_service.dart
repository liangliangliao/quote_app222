import 'dart:convert';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'james_will_training_complete_dao.dart';
import 'james_will_training_models.dart';
import 'james_will_training_prompt_context.dart';

class JamesWillTrainingAiService {
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _ai = UnifiedAiService();
  final JamesWillTrainingCompleteDao _completeDao = JamesWillTrainingCompleteDao();

  Future<JamesWillActionIdea> generateActionIdea({required String goal, String note = ''}) async {
    final state = await _settings.getState();
    final fallback = JamesWillActionIdea.local(goal: goal, note: note, aiState: state);
    if (state['available'] != '1') return fallback;
    final background = await _completeDao.promptText('unified_background');
    final promptTail = await _completeDao.promptText('action_idea_tail');
    final promptTemplate = await _completeDao.promptText('action_idea_prompt');
    final fallbackPrompt = '''
${jamesWillEffectiveBackground(background)}

你是基于威廉·詹姆斯《心理学原理》第26章“意志”的行动观念教练。
用户目标：$goal
补充说明：$note

请把用户目标转化为第一阶段 P0 可执行的“行动观念训练卡”。你不能替用户做人生选择，不能输出空泛鼓励，必须落到身体动作。

重要升级要求：
- 先理解用户真正需要，不要直接给标准答案。
- 输出要帮助用户打开思路：提供阻碍观念、替代观念、参考案例和可选择的实践方向。
- AI 只提供结构化引导，最终由用户自己判断和选择。

请严格输出合法 JSON，不要 markdown，不要代码块：
{
  "originalGoal": "用户目标",
  "coreValue": "目标背后的核心价值，尽量具体",
  "actionIdea": "今日行动观念：一个可想象、可启动、可执行的动作",
  "firstBodyAction": "第一身体动作，必须是现在能做的身体动作",
  "minimumAction": "最小行动，不超过2-5分钟",
  "fiveMinuteVersion": "5分钟版本",
  "attentionAnchor": "注意力锚定语，体现让行动观念占据注意力",
  "obstacleIdeas": ["阻碍观念1", "阻碍观念2", "阻碍观念3"],
  "replacementIdeas": ["替代观念1", "替代观念2", "替代观念3"],
  "competitionItems": [
    {"type":"行动观念", "content":"...", "strength":60, "role":"推动行动"},
    {"type":"阻碍观念", "content":"...", "strength":75, "role":"降低启动"},
    {"type":"逃避观念", "content":"...", "strength":80, "role":"转移注意"},
    {"type":"价值观念", "content":"...", "strength":70, "role":"支撑长期方向"}
  ],
  "coachMessage": "一句清晰引导：把目标落到当前一步，同时提醒最终由用户自己选择"
}

核心思想必须体现：目标→价值→行动观念→观念竞争→努力性注意→第一身体动作→五分钟启动→用户实践反馈。
附加提示词：
$promptTail
''';
    final prompt = jamesWillApplyTemplate(promptTemplate, <String, String>{
      'goal': goal,
      'note': note,
      'additionalPrompt': promptTail,
    }, fallbackPrompt);
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'external_data.james_will.action_idea',
        systemPrompt: jamesWillSystemPrompt('你是威廉·詹姆斯意志心理学行动教练。', jsonOnly: true, backgroundOverride: background),
        maxTokens: 2200,
        expectJson: true,
        temperature: 0.25,
      );
      final parsed = _extractJsonObject(raw);
      if (parsed.isEmpty) return fallback;
      return JamesWillActionIdea.fromAiJson(
        json: parsed,
        fallback: fallback,
        provider: state['provider'] ?? 'ai',
        modelLabel: state['label'] ?? 'AI',
        usedFallback: false,
      );
    } catch (_) {
      return fallback;
    }
  }

  Future<JamesWillDecision> analyzeDecision({
    required JamesWillActionIdea idea,
    required String question,
  }) async {
    final state = await _settings.getState();
    final fallback = JamesWillDecision.local(
      ideaId: idea.id,
      question: question,
      firstAction: idea.minimumAction,
    );
    if (state['available'] != '1') return fallback;
    final background = await _completeDao.promptText('unified_background');
    final promptTail = await _completeDao.promptText('decision_tail');
    final promptTemplate = await _completeDao.promptText('decision_prompt');
    final fallbackPrompt = '''
${jamesWillEffectiveBackground(background)}

你是詹姆斯式决定教练。用户正在犹豫：$question
关联目标：${idea.originalGoal}
核心价值：${idea.coreValue}
行动观念：${idea.actionIdea}
第一身体动作：${idea.firstBodyAction}
常见阻碍观念：${idea.obstacleIdeas.join('；')}

请根据威廉·詹姆斯“审议后的行动”和“五种决定类型”分析。不要替用户强行决定，而是把无限犹豫转成有限实验。

重要升级要求：
- 不能只给一个标准答案；要说明至少两个可能方向的价值、代价和适用条件。
- 必须帮助用户澄清真实需要、事实信息、可控域、可撤回实验。
- 最终输出的 strategy 应是“建议用户如何自己判断/如何做实验”，而不是 AI 直接替用户拍板。

五种决定类型只能从下面选或组合：理性结账型、外因推动型、内在自动放电型、价值尺度突变型、努力压舱型。

请严格输出合法 JSON：
{
  "question": "用户正在犹豫的问题",
  "positiveIdea": "正向行动观念",
  "negativeIdea": "反向阻碍观念",
  "hesitationType": "信息不足型/害怕不可逆型/短期舒服型/外界推动型/冲动爆发型/完美主义型/价值不清型之一或组合",
  "decisionType": "五种决定类型之一或组合",
  "strategy": "给用户的判断框架与低风险实验，不替用户选择",
  "sealedUntilDays": 7,
  "todayFirstAction": "今天第一步行动",
  "attentionAnchor": "注意力锚定语",
  "coachMessage": "一句清晰教练语：提醒用户最终自己判断和选择"
}

附加提示词：
$promptTail
''';
    final prompt = jamesWillApplyTemplate(promptTemplate, <String, String>{
      'question': question,
      'goal': idea.originalGoal,
      'coreValue': idea.coreValue,
      'actionIdea': idea.actionIdea,
      'firstBodyAction': idea.firstBodyAction,
      'obstacleIdeas': idea.obstacleIdeas.join('；'),
      'additionalPrompt': promptTail,
    }, fallbackPrompt);
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'external_data.james_will.decision',
        systemPrompt: jamesWillSystemPrompt('你是威廉·詹姆斯式决定教练。', jsonOnly: true, backgroundOverride: background),
        maxTokens: 1800,
        expectJson: true,
        temperature: 0.2,
      );
      final parsed = _extractJsonObject(raw);
      if (parsed.isEmpty) return fallback;
      return JamesWillDecision.fromAiJson(json: parsed, fallback: fallback);
    } catch (_) {
      return fallback;
    }
  }

  Future<String> summarizeReview({required JamesWillActionIdea idea, required JamesWillLog log}) async {
    final state = await _settings.getState();
    final fallback = _localReviewSummary(idea, log);
    if (state['available'] != '1') return fallback;
    final background = await _completeDao.promptText('unified_background');
    final promptTail = await _completeDao.promptText('review_tail');
    final promptTemplate = await _completeDao.promptText('review_prompt');
    final logSummary = '是否完成：${log.completed ? '完成' : '未完成'}；阻碍观念：${log.beforeObstacle}；主导观念：${log.dominantActionIdea}；拉回次数：${log.attentionRecoveryCount}；努力评分：${log.effortAttentionScore}；用户复盘：${log.reflection}';
    final fallbackPrompt = '''
${jamesWillEffectiveBackground(background)}

你是意志复盘教练。请根据下面行动记录，输出一段 80-180 字的中文复盘总结。
目标：${idea.originalGoal}
核心价值：${idea.coreValue}
行动观念：${idea.actionIdea}
$logSummary

要求：重点不是完成数量，而是用户如何在阻力中保持行动观念；同时提出下一次可由用户自己选择的调整方向，不要空泛鸡血。
附加提示词：
$promptTail
''';
    final prompt = jamesWillApplyTemplate(promptTemplate, <String, String>{
      'goal': idea.originalGoal,
      'coreValue': idea.coreValue,
      'actionIdea': idea.actionIdea,
      'logSummary': logSummary,
      'additionalPrompt': promptTail,
    }, fallbackPrompt);
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'external_data.james_will.review',
        systemPrompt: jamesWillSystemPrompt('你是威廉·詹姆斯意志复盘教练。', jsonOnly: false, backgroundOverride: background),
        maxTokens: 600,
        expectJson: false,
        temperature: 0.35,
      );
      return raw.trim().isEmpty ? fallback : raw.trim();
    } catch (_) {
      return fallback;
    }
  }

  String _localReviewSummary(JamesWillActionIdea idea, JamesWillLog log) {
    if (log.completed) {
      return '今天真正重要的不是完成了多少，而是你在“${log.beforeObstacle.isEmpty ? '阻碍观念' : log.beforeObstacle}”存在时，仍然让“${log.dominantActionIdea.isEmpty ? idea.fiveMinuteVersion : log.dominantActionIdea}”占据注意力并进入行动。下一次可以由你选择：继续同一最小行动、降低难度，或改成 7 天实验。';
    }
    return '这次没有完整完成，但你已经记录了阻碍观念和启动断点。下一次不要重新审判目标，可以从三个方向中选一个：把动作再缩小、换触发场景，或先做 2 分钟实验。能回到当前一步，本身就是训练。';
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
