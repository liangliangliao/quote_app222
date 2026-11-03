import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_request_accounting.dart';

/// Long concept maps remain JSON tasks, but need not wait for the whole JSON
/// before receiving HTTP headers. Used only by an explicit semantic-map request.
class SemanticRequestException implements Exception {
  final String message;
  final Object? cause;
  final String code;
  const SemanticRequestException(this.message,
      {this.cause, this.code = 'unknown'});
  @override
  String toString() => message;
}

class SemanticJsonReply {
  final int statusCode;
  final String text, wireBody;
  const SemanticJsonReply(this.statusCode, this.text, this.wireBody);
}

class SemanticJsonTransport {
  static bool handles(String purpose) => RegExp(
          r'^(?:cognition\.semantic(?:\.(?:expand|repair|verify))?|quote_ai\.comparison)\.v\d+$')
      .hasMatch(purpose);
  static int outputLimit(int requested, int configured) =>
      [requested, configured].reduce((a, b) => a < b ? a : b);
  final http.Client Function() clientFactory;
  final Duration totalTimeout;
  SemanticJsonTransport(
      {http.Client Function()? clientFactory,
      this.totalTimeout = const Duration(minutes: 5)})
      : clientFactory = clientFactory ?? http.Client.new;

  /// Exactly one send. A broken response cannot trigger another paid request.
  Future<SemanticJsonReply> post(
      {required Uri uri,
      required Map<String, String> headers,
      required Map<String, dynamic> body,
      required Duration idleTimeout,
      AiCancellation? cancellation,
      Future<void> Function(int status, String wire, String? failure)?
          onResponse}) async {
    final client = clientFactory(),
        text = SemanticJsonStream(
            outputLimit: (body['max_output_tokens'] ??
                body['max_completion_tokens'] ??
                body['max_tokens']) as int?);
    final wire = StringBuffer();
    String? failure;
    var deadline = false, status = 0, isEvents = false, sent = false;
    final stopListening = cancellation?.listen(client.close);
    final timer = Timer(totalTimeout, () {
      deadline = true;
      client.close();
    });
    try {
      if (cancellation?.cancelled == true)
        throw const SemanticRequestException('已停止接收；已发送请求的用量以服务返回为准。',
            code: 'cancelled');
      final request = http.Request('POST', uri)
        ..headers.addAll(headers)
        ..body = jsonEncode(body);
      sent = true;
      final response = await client.send(request).timeout(idleTimeout);
      status = response.statusCode;
      isEvents = (response.headers['content-type'] ?? '')
          .toLowerCase()
          .contains('text/event-stream');
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(idleTimeout)) {
        wire.writeln(line);
        if (isEvents && status >= 200 && status < 300) text.addLine(line);
      }
      if (deadline) throw TimeoutException('semantic request deadline');
      if (status < 200 || status >= 300)
        return SemanticJsonReply(status, '', wire.toString());
      if (isEvents) {
        text.endEvent();
      } else {
        // Some compatible gateways ignore stream:true and return one JSON body.
        text.addEnvelope(jsonDecode(wire.toString()));
      }
      return SemanticJsonReply(status, text.finish(), wire.toString());
    } on SemanticRequestException catch (error) {
      failure = error.code;
      rethrow;
    } catch (error) {
      failure = cancellation?.cancelled == true
          ? 'cancelled'
          : deadline || error is TimeoutException
              ? 'timeout'
              : 'connection';
      if (cancellation?.cancelled == true)
        throw const SemanticRequestException('已停止接收；已发送请求仍可能产生用量，未返回的用量未知。',
            code: 'cancelled');
      // A transport can close after the final JSON but before the trailing SSE
      // marker. Retain a complete answer; never return a partial JSON fragment.
      if (isEvents && status >= 200 && status < 300) {
        text.endEvent();
        if (text.hasCompleteObject && !text.truncated && !text.rejected)
          return SemanticJsonReply(status, text.content, wire.toString());
      }
      throw SemanticRequestException(
          deadline || error is TimeoutException
              ? '生成等待超时，尚未收到完整结果。请稍后手动重试。'
              : '连接在完整结果返回前中断。请检查网络后手动重试。',
          cause: error,
          code: failure);
    } finally {
      timer.cancel();
      stopListening?.call();
      client.close();
      if (sent)
        await onResponse?.call(status, wire.toString(),
            failure ?? (status < 200 || status >= 300 ? 'http_error' : null));
    }
  }
}

/// Assembles answer deltas, never reasoning deltas. Multi-line SSE data fields,
/// keep-alives and terminal events do not become part of the JSON document.
class SemanticJsonStream {
  final int? outputLimit;
  SemanticJsonStream({this.outputLimit});
  final _pieces = StringBuffer(), _event = <String>[];
  String _fallback = '';
  bool terminal = false, truncated = false, rejected = false;
  String get content => (_pieces.isNotEmpty ? _pieces.toString() : _fallback)
      .trim()
      .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'\s*```$'), '');
  bool get hasCompleteObject {
    try {
      return jsonDecode(content) is Map;
    } catch (_) {
      return false;
    }
  }

  void addLine(String line) {
    if (line.isEmpty) {
      endEvent();
    } else if (line.startsWith('data:')) {
      var value = line.substring(5);
      if (value.startsWith(' ')) value = value.substring(1);
      _event.add(value);
    }
  }

  void endEvent() {
    if (_event.isEmpty) return;
    final data = _event.join('\n');
    _event.clear();
    if (data.trim() == '[DONE]') {
      terminal = true;
      return;
    }
    try {
      addEnvelope(jsonDecode(data));
    } on FormatException {
      // An incomplete final event will fail the completeness check below.
    }
  }

  void _reason(dynamic reason) {
    if (['length', 'max_tokens', 'max_output_tokens'].contains(reason))
      truncated = true;
    if (['content_filter', 'refusal'].contains(reason)) rejected = true;
    if (['stop', 'end_turn', 'stop_sequence'].contains(reason)) terminal = true;
  }

  void addEnvelope(dynamic raw) {
    if (raw is! Map) return;
    if (raw['error'] != null || raw['type'] == 'error')
      throw const SemanticRequestException('服务未完成本次生成，请稍后手动重试。');
    final type = raw['type'];
    if (type == 'response.output_text.delta' && raw['delta'] is String)
      _pieces.write(raw['delta']);
    if (type == 'response.completed') terminal = true;
    if (type == 'response.incomplete') {
      truncated = true;
    }
    if (type == 'response.failed')
      throw const SemanticRequestException('服务未完成本次生成，请稍后手动重试。');
    if (type == 'message_stop') terminal = true;
    final delta = raw['delta'];
    if (type == 'content_block_delta' &&
        delta is Map &&
        delta['type'] == 'text_delta') _pieces.write(delta['text'] ?? '');
    if (delta is Map) _reason(delta['stop_reason']);
    _reason(raw['stop_reason']);
    final choices = raw['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final first = choices.first as Map;
      _reason(first['finish_reason']);
      final part = first['delta'];
      if (part is Map && part['content'] is String)
        _pieces.write(part['content']);
      if (part is Map && part['refusal'] != null) rejected = true;
      final message = first['message'];
      if (message is Map && message['content'] is String)
        _fallback = message['content'] as String;
      if (message is Map && message['refusal'] != null) rejected = true;
    }
    final response = raw['response'];
    if (response is Map) {
      if (response['status'] == 'incomplete') truncated = true;
      addEnvelope(response);
    }
    if (raw['output_text'] is String) _fallback = raw['output_text'] as String;
    final output = raw['output'];
    if (output is List) {
      final values = <String>[];
      for (final item in output) {
        if (item is! Map || item['type'] != 'message') continue;
        for (final c
            in (item['content'] is List ? item['content'] as List : [])) {
          if (c is Map && c['type'] == 'output_text' && c['text'] is String)
            values.add(c['text'] as String);
          if (c is Map && c['type'] == 'refusal') rejected = true;
        }
      }
      if (values.isNotEmpty) _fallback = values.join();
    }
    final blocks = raw['content'];
    if (blocks is List) {
      final values = [
        for (final block in blocks)
          if (block is Map &&
              block['type'] == 'text' &&
              block['text'] is String)
            block['text'] as String
      ];
      if (values.isNotEmpty) _fallback = values.join();
    }
  }

  String finish() {
    if (truncated)
      throw SemanticRequestException(
          '服务端停止输出，结果未完整生成。应用没有设置输出 Token 上限，请核对模型服务的输出能力。',
          code: 'output_limit');
    if (rejected)
      throw const SemanticRequestException('服务未提供本次请求的完整正文，请调整内容后重试。',
          code: 'refused');
    if (hasCompleteObject) return content;
    throw const SemanticRequestException('尚未收到完整的概念图结果，请稍后手动重试。',
        code: 'incomplete');
  }
}
