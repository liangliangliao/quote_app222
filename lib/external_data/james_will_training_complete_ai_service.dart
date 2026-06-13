import 'dart:convert';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'james_will_training_complete_dao.dart';
import 'james_will_training_complete_models.dart';
import 'james_will_training_models.dart';
import 'james_will_training_prompt_context.dart';

class JamesWillTrainingCompleteAiService {
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _ai = UnifiedAiService();
  final JamesWillTrainingCompleteDao _dao = JamesWillTrainingCompleteDao();

  Future<JamesWillWeeklyReport> generateWeeklyReport(List<JamesWillLog> logs, List<JamesWillActionIdea> ideas) async {
    final fallback = JamesWillWeeklyReport.fromLogs(logs);
    final state = await _settings.getState();
    if (state['available'] != '1') return fallback;
    final background = await _dao.promptText('unified_background');
    final promptTail = await _dao.promptText('weekly_report_tail');
    final promptTemplate = await _dao.promptText('weekly_report_prompt');
    final recentLogs = logs.take(30).map((e) => <String, Object?>{
          'completed': e.completed,
          'beforeObstacle': e.beforeObstacle,
          'dominantActionIdea': e.dominantActionIdea,
          'recoveries': e.attentionRecoveryCount,
          'effort': e.effortAttentionScore,
          'reflection': e.reflection,
        }).toList();
    final ideaNames = ideas.take(20).map((e) => '${e.originalGoal} / ${e.actionIdea}').join('\n');
    final fallbackPrompt = '''
${jamesWillEffectiveBackground(background)}

你是威廉·詹姆斯式意志训练每周报告教练。请基于用户最近行动观念卡与意志日志，输出一份结构化周报。

行动观念卡：
$ideaNames

最近意志日志 JSON：
${jsonEncode(recentLogs)}

附加要求：
$promptTail

请严格输出合法 JSON，不要 markdown，不要代码块：
{
  "summary": "120-220字周报总结，围绕行动观念、阻碍观念、努力性注意、决定稳定度、习惯化进展；给出多种可能，不替用户选择",
  "nextExperiment": "下周一个可选的7天实验，包含固定触发条件、地点、第一身体动作和失败恢复方案"
}
''';
    final prompt = jamesWillApplyTemplate(promptTemplate, <String, String>{
      'ideas': ideaNames,
      'logs': jsonEncode(recentLogs),
      'additionalPrompt': promptTail,
    }, fallbackPrompt);
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'external_data.james_will.weekly_report',
        systemPrompt: jamesWillSystemPrompt('你是威廉·詹姆斯式意志训练周报教练。', jsonOnly: true, backgroundOverride: background),
        maxTokens: 1200,
        expectJson: true,
        temperature: 0.25,
      );
      final json = _extractJsonObject(raw);
      return JamesWillWeeklyReport.fromLogs(
        logs,
        aiSummary: (json['summary'] ?? '').toString(),
        aiNextExperiment: (json['nextExperiment'] ?? '').toString(),
      );
    } catch (_) {
      return fallback;
    }
  }

  Future<String> generateVoicePullbackScript({required JamesWillActionIdea idea, required String stateLabel}) async {
    final state = await _settings.getState();
    final fallback = '现在不要评价自己，也不要思考整个人生。只保留一个观念：${idea.attentionAnchor}。接下来执行第一身体动作：${idea.firstBodyAction}。';
    if (state['available'] != '1') return fallback;
    final background = await _dao.promptText('unified_background');
    final promptTemplate = await _dao.promptText('voice_pullback_prompt');
    final fallbackPrompt = '''
${jamesWillEffectiveBackground(background)}

你是注意力守门人。用户当前状态：$stateLabel。
目标：${idea.originalGoal}
行动观念：${idea.actionIdea}
第一身体动作：${idea.firstBodyAction}
阻碍观念：${idea.obstacleIdeas.join('；')}

请生成一段 30-45 秒的中文语音引导文案，帮助用户从分心/拖延/想放弃回到当前一步。
要求：不批评、不鸡血、不讲大道理，只把行动观念放回意识中心；不要替用户决定，只提供当下可执行的第一动作。只输出文案。
''';
    final prompt = jamesWillApplyTemplate(promptTemplate, <String, String>{
      'stateLabel': stateLabel,
      'goal': idea.originalGoal,
      'actionIdea': idea.actionIdea,
      'firstBodyAction': idea.firstBodyAction,
      'obstacleIdeas': idea.obstacleIdeas.join('；'),
    }, fallbackPrompt);
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'external_data.james_will.voice_pullback',
        systemPrompt: jamesWillSystemPrompt('你是简短、温和、具体的注意力拉回教练。', jsonOnly: false, backgroundOverride: background),
        maxTokens: 400,
        expectJson: false,
        temperature: 0.3,
      );
      return raw.trim().isEmpty ? fallback : raw.trim();
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
