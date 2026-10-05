import 'dart:async';
import 'dart:convert';
import 'evidence_growth_journey_models.dart';

class GrowthAiJson {
  static GrowthData decode(String raw) {
    final text = raw.trim();
    // Providers sometimes surround otherwise valid JSON with prose or fences.
    for (var start = text.indexOf('{');
        start >= 0;
        start = text.indexOf('{', start + 1)) {
      var depth = 0, quoted = false, escaped = false;
      for (var end = start; end < text.length; end++) {
        final c = text[end];
        if (quoted) {
          if (escaped) {
            escaped = false;
          } else if (c == r'\') {
            escaped = true;
          } else if (c == '"') {
            quoted = false;
          }
          continue;
        }
        if (c == '"') quoted = true;
        if (c == '{') depth++;
        if (c == '}' && --depth == 0) {
          try {
            return growthMap(jsonDecode(text.substring(start, end + 1)));
          } catch (_) {
            break;
          }
        }
      }
    }
    throw const FormatException('INVALID_JSON');
  }

  static String code(Object error) => error is TimeoutException
      ? 'REQUEST_TIMEOUT'
      : error is FormatException
          ? '${error.message}'
          : 'REQUEST_FAILED';
  static String reason(Object error) {
    final c = code(error);
    if (c == 'REQUEST_TIMEOUT') return '模型响应超时，已有内容已保留。可手动重试或更换响应更快的文本模型。';
    if (c == 'INVALID_JSON') return '模型未返回完整的结构化内容。请手动重试；已有记录没有改变。';
    if (c.contains('FACT') || c.contains('PREDICTION'))
      return '模型改写了原记录或加入未提供的事实，已拒绝采用。请重试或补充真实记录。';
    if (c.contains('NODE') || c.contains('SOURCE'))
      return '模型引用了未提供的知识依据，已拒绝采用。请重新匹配或重试。';
    if (c.contains('BOUNDARY') || c.contains('UNSAFE'))
      return '建议与当前边界冲突，已保留安全的本地步骤。';
    if (c == 'REQUEST_FAILED') return '模型服务请求失败，请检查统一 AI 配置或稍后手动重试。';
    return '返回内容不符合当前步骤的要求（$c），已保留本地内容，可手动重新分析。';
  }
}
