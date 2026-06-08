import 'dart:convert';

import 'package:intl/intl.dart';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'behavior_tracking_models.dart';

class BehaviorPresetAiAnalysisService {
  BehaviorPresetAiAnalysisService();

  final UnifiedAiService _ai = UnifiedAiService();
  final GlobalAiSettings _settings = GlobalAiSettings();

  Future<BehaviorPresetAiAnalysisResult> analyzeDailyPresetBehaviors({
    required DateTime date,
    required List<Map<String, dynamic>> details,
    required int totalCount,
    required int doneCount,
    required int missedCount,
    required double completionRate,
  }) async {
    final template = await _settings.getBehaviorPresetDailyReviewAiPrompt();
    final input = <String, dynamic>{
      'review_date': DateFormat('yyyy-MM-dd').format(date),
      'client_generated_at': DateTime.now().toIso8601String(),
      'review_summary': <String, dynamic>{
        'total_count': totalCount,
        'done_count': doneCount,
        'missed_count': missedCount,
        'completion_rate': completionRate,
      },
      'preset_behaviors': details,
      'important_limits': <String>[
        '无法获得真实全球行为数据库；请基于公开知识、流行病学/社会学/心理学常识、人口统计数量级和合理假设给出粗略估算。',
        '必须说明估算不确定性、证据等级和推理链，避免把推测写成精确事实。',
        '风险评估只作生活复盘参考，不代替医疗、法律或财务建议。',
      ],
    };
    final inputJson = const JsonEncoder.withIndent('  ').convert(input);
    final prompt = template.replaceAll('{{review_input_json}}', inputJson);
    final raw = await _ai.generateChatMessages(
      purpose: 'behavior_tracking.preset_daily_review_ai_analysis',
      maxTokens: 5200,
      temperature: 0.35,
      messages: <UnifiedAiChatMessage>[
        const UnifiedAiChatMessage(
          role: 'system',
          content: '你是严谨的行为科学、社会统计、风险评估、心理学与哲学综合分析助手。只输出 JSON，不输出 Markdown。',
        ),
        UnifiedAiChatMessage(role: 'user', content: prompt),
      ],
    );
    final data = _extractJsonObject(raw);
    if (data.isEmpty) {
      return BehaviorPresetAiAnalysisResult(
        status: raw.trim().isEmpty ? 'not_configured' : 'parse_failed',
        rawText: raw,
        analysisJson: _fallbackJson(
          date: date,
          totalCount: totalCount,
          doneCount: doneCount,
          missedCount: missedCount,
          message: raw.trim().isEmpty
              ? '未检测到可用的统一 AI 配置，请先在设置页填写 API Key 与模型。'
              : 'AI 已返回内容，但未能解析成严格 JSON；已保存原始返回文本。',
        ),
      );
    }
    return BehaviorPresetAiAnalysisResult(status: 'ok', rawText: raw, analysisJson: data);
  }

  Map<String, dynamic> _fallbackJson({
    required DateTime date,
    required int totalCount,
    required int doneCount,
    required int missedCount,
    required String message,
  }) {
    return <String, dynamic>{
      'schema_version': 'behavior_preset_ai_analysis_v1',
      'review_date': DateFormat('yyyy-MM-dd').format(date),
      'summary': <String, dynamic>{
        'title': 'AI 分析暂不可用',
        'overall_conclusion': message,
        'human_behavior_position': '等待统一 AI 配置完成后重新分析。',
        'total_count': totalCount,
        'done_count': doneCount,
        'missed_count': missedCount,
      },
      'behaviors': <Map<String, dynamic>>[],
      'rare_high_risk_meaningful_cases': <Map<String, dynamic>>[],
      'method_notes': <String>[message],
    };
  }

  Map<String, dynamic> _extractJsonObject(String raw) {
    final text = raw.trim().replaceAll('```json', '').replaceAll('```', '').trim();
    if (text.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return decoded.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
    } catch (_) {}
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final slice = text.substring(start, end + 1);
      try {
        final decoded = jsonDecode(slice);
        if (decoded is Map) return decoded.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
      } catch (_) {}
    }
    return <String, dynamic>{};
  }
}

class BehaviorPresetAiAnalysisResult {
  final String status;
  final String rawText;
  final Map<String, dynamic> analysisJson;

  const BehaviorPresetAiAnalysisResult({
    required this.status,
    required this.rawText,
    required this.analysisJson,
  });
}
