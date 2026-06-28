import 'dart:convert';

import '../data/dao.dart';
import '../services/native_guard.dart';

class DeepSeekLogger {
  static final LogDao _dao = LogDao();

  static String _providerTitle(String provider, String suffix) => '【${provider}${suffix}】';

  static Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final out = <String, String>{};
    headers.forEach((key, value) {
      final lower = key.toLowerCase();
      if (lower == 'authorization') {
        out[key] = 'Bearer ***REDACTED***';
      } else if (lower == 'x-goog-api-key' || lower == 'x-api-key' || lower.contains('api-key')) {
        out[key] = '***REDACTED***';
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  static String _pretty(dynamic value) {
    try {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
          return const JsonEncoder.withIndent('  ').convert(jsonDecode(trimmed));
        }
        return value;
      }
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value?.toString() ?? '';
    }
  }

  static Future<void> _write(String title, String module, String detail, {String provider = 'DeepSeek'}) async {
    final text = '$title[$module]\n$detail';
    try {
      await _dao.add(
        taskUid: 'system',
        detail: text,
        taskNameSnapshot: '$provider/$module',
        taskStartTimeSnapshot: DateTime.now().toIso8601String(),
      );
      SimpleBus.pokeLogs();
    } catch (_) {}
  }

  static Future<void> logRequest({
    required String module,
    required String endpoint,
    required Map<String, String> headers,
    required dynamic body,
    String? method,
    String provider = 'DeepSeek',
    String? model,
    String? traceId,
    String? sessionId,
  }) async {
    final sanitizedHeaders = _sanitizeHeaders(headers);
    await _write(
      _providerTitle(provider, '请求'),
      module,
      'Provider: $provider\n'
      'Model: ${model ?? ''}\n'
      'TraceId: ${traceId ?? ''}\n'
      'SessionId: ${sessionId ?? ''}\n'
      'Method: ${method ?? 'POST'}\n'
      'URL: $endpoint\n'
      'Headers:\n${_pretty(sanitizedHeaders)}\n\n'
      'Body:\n${_pretty(body)}',
      provider: provider,
    );
  }

  static Future<void> logResponse({
    required String module,
    required String endpoint,
    required int statusCode,
    required dynamic body,
    String provider = 'DeepSeek',
    String? model,
    String? traceId,
    String? sessionId,
  }) async {
    await _write(
      _providerTitle(provider, '响应'),
      module,
      'Provider: $provider\n'
      'Model: ${model ?? ''}\n'
      'TraceId: ${traceId ?? ''}\n'
      'SessionId: ${sessionId ?? ''}\n'
      'URL: $endpoint\n'
      'Status: $statusCode\n\n'
      'Body:\n${_pretty(body)}',
      provider: provider,
    );
  }

  static Future<void> logError({
    required String module,
    required String endpoint,
    required Object error,
    StackTrace? stackTrace,
    String provider = 'DeepSeek',
    String? model,
    String? traceId,
    String? sessionId,
  }) async {
    await _write(
      _providerTitle(provider, '异常'),
      module,
      'Provider: $provider\n'
      'Model: ${model ?? ''}\n'
      'TraceId: ${traceId ?? ''}\n'
      'SessionId: ${sessionId ?? ''}\n'
      'URL: $endpoint\n'
      'Error: $error\n'
      '${stackTrace == null ? '' : '\nStack:\n$stackTrace'}',
      provider: provider,
    );
  }
}
