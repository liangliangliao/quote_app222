import 'dart:convert';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'life_note_models.dart';

class LifeNoteAiService {
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _ai = UnifiedAiService();

  Future<LifeNoteReport> analyze({
    required String experience,
    required List<String> selectedEmotions,
    required List<String> sceneTags,
  }) async {
    final text = experience.trim();
    if (text.isEmpty) {
      return LifeNoteReport.emptyWithMessage('请先写下一段你想理解的经历、感受或人生故事。');
    }

    final template = await _settings.getLifeNoteAnalysisPrompt();
    final input = <String, dynamic>{
      'experience': text,
      'selected_emotions': selectedEmotions,
      'scene_tags': sceneTags,
      'client_time': DateTime.now().toIso8601String(),
    };
    final prompt = _settings.renderTemplate(template, <String, String>{
      'user_experience': text,
      'selected_emotions': selectedEmotions.join('、'),
      'scene_tags': sceneTags.join('、'),
      'life_note_input_json': const JsonEncoder.withIndent('  ').convert(input),
    });

    final raw = await _ai.generateText(
      prompt: prompt,
      purpose: 'life_note.analysis',
      systemPrompt: '你是一个温和、严谨、非诊断式的自我理解与疗愈阅读推荐助手。只输出一个JSON对象，不要输出markdown或解释性前后缀。',
      maxTokens: 3200,
      expectJson: true,
      temperature: 0.65,
    );
    if (raw.trim().isEmpty) {
      return LifeNoteReport.emptyWithMessage('当前通用 AI 模型尚未配置或请求未返回内容。请先到设置页配置通用 AI Provider、API Key 与模型。');
    }
    final decoded = jsonDecode(_extractFirstJsonObject(raw));
    if (decoded is Map<String, dynamic>) {
      return LifeNoteReport.fromJson(decoded);
    }
    if (decoded is Map) {
      return LifeNoteReport.fromJson(Map<String, dynamic>.from(decoded));
    }
    return LifeNoteReport.emptyWithMessage('AI 已返回内容，但格式不是预期的 JSON 对象。请在提示词配置中心恢复默认模板后重试。');
  }

  String _extractFirstJsonObject(String raw) {
    final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    if (cleaned.startsWith('{') && cleaned.endsWith('}')) return cleaned;
    final start = cleaned.indexOf('{');
    if (start < 0) return cleaned;
    var depth = 0;
    var inString = false;
    var escape = false;
    for (var i = start; i < cleaned.length; i++) {
      final c = cleaned.codeUnitAt(i);
      if (escape) {
        escape = false;
        continue;
      }
      if (c == 0x5C) {
        escape = true;
        continue;
      }
      if (c == 0x22) {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (c == 0x7B) depth++;
      if (c == 0x7D) {
        depth--;
        if (depth == 0) return cleaned.substring(start, i + 1);
      }
    }
    return cleaned.substring(start);
  }
}
