import 'dart:convert';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'james_will_training_models.dart';
import 'james_will_training_stage3_models.dart';
import 'james_will_training_prompt_context.dart';
import 'james_will_training_complete_dao.dart';

class JamesWillTrainingStage3AiService {
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _ai = UnifiedAiService();
  final JamesWillTrainingCompleteDao _configDao = JamesWillTrainingCompleteDao();

  Future<JamesWillSevenDayExperiment> generateSevenDayExperiment({required JamesWillActionIdea idea, required List<JamesWillLog> logs}) async {
    final fallback = JamesWillSevenDayExperiment.fromIdea(idea);
    final state = await _settings.getState();
    if (state['available'] != '1') return fallback;
    final background = await _configDao.promptText('unified_background');
    final promptTemplate = await _configDao.promptText('seven_day_experiment_prompt');
    final recentLogs = logs.take(12).map((e) => <String, Object?>{
          'completed': e.completed,
          'obstacle': e.beforeObstacle,
          'dominantIdea': e.dominantActionIdea,
          'recoveries': e.attentionRecoveryCount,
          'effort': e.effortAttentionScore,
          'reflection': e.reflection,
        }).toList(growable: false);
    final fallbackPrompt = '''
${jamesWillEffectiveBackground(background)}

你是威廉·詹姆斯式意志训练的第三阶段行动实验设计师。
请为下面行动观念设计一个完整7天实验。目标不是替用户决定人生，而是把目标封存为可撤回、可复盘、可执行的小实验。

目标：${idea.originalGoal}
核心价值：${idea.coreValue}
行动观念：${idea.actionIdea}
第一身体动作：${idea.firstBodyAction}
最小行动：${idea.minimumAction}
五分钟版本：${idea.fiveMinuteVersion}
阻碍观念：${idea.obstacleIdeas.join('；')}
最近日志：${jsonEncode(recentLogs)}

请严格输出合法 JSON，不要 markdown，不要代码块：
{
  "title": "7天实验标题",
  "coreValue": "这轮实验真正训练的核心价值",
  "triggerText": "固定触发条件",
  "placeText": "固定地点",
  "firstBodyAction": "第一身体动作",
  "minimumVersion": "最小版本",
  "standardVersion": "标准版本",
  "fallbackVersion": "失败恢复版本",
  "dailyPlan": ["第1天计划", "第2天计划", "第3天计划", "第4天计划", "第5天计划", "第6天计划", "第7天计划"],
  "recoveryPlan": "失败当天和第二天如何恢复",
  "aiSummary": "80-140字说明：决定封存、执行期、反馈复盘；说明这只是可选实验，最终由用户选择"
}
''';
    final prompt = jamesWillApplyTemplate(promptTemplate, <String, String>{
      'goal': idea.originalGoal,
      'coreValue': idea.coreValue,
      'actionIdea': idea.actionIdea,
      'firstBodyAction': idea.firstBodyAction,
      'minimumAction': idea.minimumAction,
      'fiveMinuteVersion': idea.fiveMinuteVersion,
      'obstacleIdeas': idea.obstacleIdeas.join('；'),
      'logs': jsonEncode(recentLogs),
    }, fallbackPrompt);
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'external_data.james_will.stage3.experiment',
        systemPrompt: jamesWillSystemPrompt('你是威廉·詹姆斯式行动实验设计师。', jsonOnly: true, backgroundOverride: background),
        maxTokens: 1800,
        expectJson: true,
        temperature: 0.25,
      );
      final parsed = _extractJsonObject(raw);
      if (parsed.isEmpty) return fallback;
      return JamesWillSevenDayExperiment.fromAiJson(json: parsed, fallback: fallback);
    } catch (_) {
      return fallback;
    }
  }

  Future<JamesWillCooldownPlan> generateCooldownPlan({required JamesWillActionIdea idea, required String decisionText}) async {
    final fallback = JamesWillCooldownPlan.fromIdea(idea, decisionText: decisionText);
    final state = await _settings.getState();
    if (state['available'] != '1') return fallback;
    final background = await _configDao.promptText('unified_background');
    final promptTemplate = await _configDao.promptText('cooldown_prompt');
    final fallbackPrompt = '''
${jamesWillEffectiveBackground(background)}

你是威廉·詹姆斯式冲动决定冷却教练。
用户可能正在做一个冲动决定，请判断风险，并把决定转化为冷却期检查。

目标：${idea.originalGoal}
核心价值：${idea.coreValue}
行动观念：${idea.actionIdea}
阻碍观念：${idea.obstacleIdeas.join('；')}
用户想做的决定：$decisionText

请严格输出合法 JSON，不要 markdown，不要代码块：
{
  "triggerText": "触发冲动的观念或情境",
  "decisionText": "被冷却的决定",
  "riskLevel": "低/中/高，并说明原因",
  "reason": "为什么需要冷却，而不是立刻行动",
  "coolMinutes": 1440,
  "checkQuestions": ["冷却后需要回答的问题1", "问题2", "问题3", "问题4"],
  "fallbackAction": "冷却期内可执行的低风险第一步"
}
''';
    final prompt = jamesWillApplyTemplate(promptTemplate, <String, String>{
      'goal': idea.originalGoal,
      'coreValue': idea.coreValue,
      'actionIdea': idea.actionIdea,
      'obstacleIdeas': idea.obstacleIdeas.join('；'),
      'decisionText': decisionText,
    }, fallbackPrompt);
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'external_data.james_will.stage3.cooldown',
        systemPrompt: jamesWillSystemPrompt('你是威廉·詹姆斯式冲动决定冷却教练。', jsonOnly: true, backgroundOverride: background),
        maxTokens: 1200,
        expectJson: true,
        temperature: 0.2,
      );
      final parsed = _extractJsonObject(raw);
      if (parsed.isEmpty) return fallback;
      return JamesWillCooldownPlan.fromAiJson(json: parsed, fallback: fallback);
    } catch (_) {
      return fallback;
    }
  }

  Future<JamesWillValueMapSnapshot> generateValueMap({required List<JamesWillActionIdea> ideas, required List<JamesWillLog> logs}) async {
    final fallback = JamesWillValueMapSnapshot.fromIdeas(ideas, logs);
    final state = await _settings.getState();
    if (state['available'] != '1') return fallback;
    final background = await _configDao.promptText('unified_background');
    final promptTemplate = await _configDao.promptText('value_map_prompt');
    final ideaJson = ideas.take(25).map((e) => <String, Object?>{
          'goal': e.originalGoal,
          'coreValue': e.coreValue,
          'actionIdea': e.actionIdea,
          'firstBodyAction': e.firstBodyAction,
          'minimumAction': e.minimumAction,
        }).toList(growable: false);
    final logJson = logs.take(40).map((e) => <String, Object?>{
          'ideaId': e.ideaId,
          'completed': e.completed,
          'obstacle': e.beforeObstacle,
          'dominantIdea': e.dominantActionIdea,
          'effort': e.effortAttentionScore,
        }).toList(growable: false);
    final fallbackPrompt = '''
${jamesWillEffectiveBackground(background)}

你是长期价值地图分析师。请把用户目标系统梳理成“核心价值→行动观念→第一身体动作→反馈”的地图总结。
行动观念卡 JSON：${jsonEncode(ideaJson)}
意志日志 JSON：${jsonEncode(logJson)}

请严格输出合法 JSON，不要 markdown，不要代码块：
{
  "summary": "120-220字长期价值地图总结：哪些价值被反复提到，哪些行动已经落地，哪里仍停留在口号，给出多个可选下一步实验，不替用户选择"
}
''';
    final prompt = jamesWillApplyTemplate(promptTemplate, <String, String>{
      'ideas': jsonEncode(ideaJson),
      'logs': jsonEncode(logJson),
    }, fallbackPrompt);
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'external_data.james_will.stage3.value_map',
        systemPrompt: jamesWillSystemPrompt('你是威廉·詹姆斯式长期价值地图分析师。', jsonOnly: true, backgroundOverride: background),
        maxTokens: 900,
        expectJson: true,
        temperature: 0.25,
      );
      final parsed = _extractJsonObject(raw);
      return JamesWillValueMapSnapshot.fromIdeas(ideas, logs, aiSummary: (parsed['summary'] ?? '').toString());
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
