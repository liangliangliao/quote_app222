import 'dart:convert';

class AiCancellation {
  bool cancelled = false;
  final Set<void Function()> _listeners = {};
  void Function() listen(void Function() callback) {
    if (cancelled)
      callback();
    else
      _listeners.add(callback);
    return () => _listeners.remove(callback);
  }

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    for (final callback in _listeners.toList()) {
      callback();
    }
    _listeners.clear();
  }
}

/// Provider-reported counts. Missing counts are unknown, never zero.
class AiTokenUsage {
  final int? input, output, cachedInput, reasoning;
  const AiTokenUsage(
      {this.input, this.output, this.cachedInput, this.reasoning});
  int? get total => input == null || output == null ? null : input! + output!;
  bool get known => input != null || output != null;
  Map<String, dynamic> toJson() => {
        'input': input,
        'output': output,
        'cached_input': cachedInput,
        'reasoning_in_output': reasoning,
      };
  static AiTokenUsage fromJson(Map raw) => AiTokenUsage(
      input: _count(raw['input']),
      output: _count(raw['output']),
      cachedInput: _count(raw['cached_input']),
      reasoning: _count(raw['reasoning_in_output']));
  static int? _count(dynamic v) => v is num && v >= 0 ? v.toInt() : null;
  static Map _map(dynamic v) => v is Map ? v : const {};
  static AiTokenUsage fromEnvelope(dynamic raw) {
    if (raw is! Map) return const AiTokenUsage();
    final response = _map(raw['response']);
    final message = _map(raw['message']);
    final u = _map(raw['usage'] ?? response['usage'] ?? message['usage']);
    var input = _count(u['prompt_tokens'] ?? u['input_tokens']);
    // Anthropic separates noncached input from cache reads and writes. Our
    // canonical input is the total, while cachedInput stays a subset of it.
    if (input != null &&
        u['prompt_tokens'] == null &&
        u.containsKey('input_tokens') &&
        (u.containsKey('cache_read_input_tokens') ||
            u.containsKey('cache_creation_input_tokens'))) {
      final read = _count(u['cache_read_input_tokens']),
          write = _count(u['cache_creation_input_tokens']);
      input = read == null || write == null ? null : input + read + write;
    }
    return AiTokenUsage(
        input: input,
        output: _count(u['completion_tokens'] ?? u['output_tokens']),
        cachedInput: _count(
            _map(u['prompt_tokens_details'] ?? u['input_tokens_details'])[
                    'cached_tokens'] ??
                u['cache_read_input_tokens']),
        reasoning: _count(
            _map(u['completion_tokens_details'] ?? u['output_tokens_details'])[
                'reasoning_tokens']));
  }

  /// Streaming counters are cumulative. Never sum repeated usage envelopes.
  AiTokenUsage merge(AiTokenUsage other) {
    int? largest(int? a, int? b) => a == null
        ? b
        : b == null
            ? a
            : (a > b ? a : b);
    return AiTokenUsage(
        input: largest(input, other.input),
        output: largest(output, other.output),
        cachedInput: largest(cachedInput, other.cachedInput),
        reasoning: largest(reasoning, other.reasoning));
  }

  static AiTokenUsage parse(String body) {
    var result = const AiTokenUsage();
    try {
      return fromEnvelope(jsonDecode(body));
    } catch (_) {}
    for (final line in const LineSplitter().convert(body)) {
      if (!line.startsWith('data:')) continue;
      try {
        result =
            result.merge(fromEnvelope(jsonDecode(line.substring(5).trim())));
      } catch (_) {}
    }
    return result;
  }

  String get label => '输入 ${input ?? '未知'} · 输出 ${output ?? '未知'}'
      '${reasoning == null ? '' : '（含推理 $reasoning）'}'
      '${cachedInput == null ? '' : ' · 缓存命中 $cachedInput'}';
}

class AiOutputBudget {
  final int task, effective;
  final int? global, modelLimit;
  const AiOutputBudget._(
      this.task, this.global, this.modelLimit, this.effective);
  const AiOutputBudget.unlimited() : this._(0, null, null, 0);
  factory AiOutputBudget.resolve(int task, {int? global, int? modelLimit}) {
    if (task <= 0) throw ArgumentError.value(task, 'task', '输出额度须为正整数');
    if (global != null && global <= 0) global = null;
    if (modelLimit != null && modelLimit <= 0) modelLimit = null;
    var effective = task;
    for (final limit in [global, modelLimit]) {
      if (limit != null && limit > 0 && limit < effective) effective = limit;
    }
    return AiOutputBudget._(task, global, modelLimit, effective);
  }
  Map<String, dynamic> toJson() => {
        'task': task,
        'global_ceiling': global,
        'model_limit': modelLimit,
        'effective': effective
      };
  String get label => effective == 0 ? '应用不设置输出 Token 上限' : '全局上限 ${global ?? '未设置'} · 任务 $task · 生效 $effective'
      ' · 模型上限 ${modelLimit ?? '未知'}';
}

String aiFinishReason(String body) {
  String find(dynamic raw) {
    if (raw is! Map) return '';
    if (raw['type'] == 'response.incomplete' || raw['status'] == 'incomplete')
      return 'max_output_tokens';
    final choices = raw['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final reason = choices.first['finish_reason'];
      if (reason is String && reason.isNotEmpty) return reason;
    }
    if (raw['stop_reason'] is String) return raw['stop_reason'];
    if (raw['delta'] is Map && raw['delta']['stop_reason'] is String)
      return raw['delta']['stop_reason'];
    if (raw['response'] is Map) return find(raw['response']);
    return '';
  }

  try {
    return find(jsonDecode(body));
  } catch (_) {}
  var reason = '';
  for (final line in const LineSplitter().convert(body)) {
    if (!line.startsWith('data:')) continue;
    try {
      final next = find(jsonDecode(line.substring(5).trim()));
      if (next.isNotEmpty) reason = next;
    } catch (_) {}
  }
  return reason;
}

bool aiOutputTruncated(String reason) =>
    const ['length', 'max_tokens', 'max_output_tokens'].contains(reason);
