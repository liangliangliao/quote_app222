import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Long concept maps remain JSON tasks, but need not wait for the whole JSON
/// before receiving HTTP headers. Used only by an explicit semantic-map request.
class SemanticRequestException implements Exception {
  final String message;
  final Object? cause;
  const SemanticRequestException(this.message, {this.cause});
  @override
  String toString() => message;
}

class SemanticJsonReply {
  final int statusCode;
  final String text, wireBody;
  const SemanticJsonReply(this.statusCode, this.text, this.wireBody);
}

class SemanticJsonTransport {
  static bool handles(String purpose) =>
      RegExp(r'^cognition\.semantic\.v\d+$').hasMatch(purpose);
  static int outputLimit(int requested, int configured) =>
      [requested, configured, 10000].reduce((a, b) => a < b ? a : b);
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
      required Duration idleTimeout}) async {
    final client = clientFactory(), text = SemanticJsonStream();
    final wire = StringBuffer();
    var deadline = false, status = 0, isEvents = false;
    final timer = Timer(totalTimeout, () {
      deadline = true;
      client.close();
    });
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll(headers)
        ..body = jsonEncode(body);
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
        if (wire.length > 4 * 1024 * 1024)
          throw const SemanticRequestException('本次响应过长，已停止接收，请减少展开范围后重试。');
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
    } on SemanticRequestException {
      rethrow;
    } catch (error) {
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
          cause: error);
    } finally {
      timer.cancel();
      client.close();
    }
  }
}

/// Assembles answer deltas, never reasoning deltas. Multi-line SSE data fields,
/// keep-alives and terminal events do not become part of the JSON document.
class SemanticJsonStream {
  final _pieces = StringBuffer(), _event = <String>[];
  String _fallback = '';
  bool terminal = false, truncated = false, rejected = false;
  String get content => _pieces.isNotEmpty ? _pieces.toString() : _fallback;
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
      throw const SemanticRequestException(
          '本次输出达到上限，概念图尚未完整生成。可提高较低的输出设置或减少展开范围后重试。');
    if (rejected)
      throw const SemanticRequestException('服务未提供本次请求的完整正文，请调整内容后重试。');
    if (hasCompleteObject || (terminal && content.trim().isNotEmpty))
      return content;
    throw const SemanticRequestException('尚未收到完整的概念图结果，请稍后手动重试。');
  }
}
