import '../kindling/kindling.dart';
import '../services/unified_ai_service.dart';

/// 调一次模型，拿回纯文本。抽出来是为了测试可以不碰网络和宿主配置。
typedef KindlingAiCall = Future<String> Function({
  required String prompt,
  required String systemPrompt,
  required String purpose,
});

/// AI 版追问器（方案 §7 的可选增强）。
///
/// 硬要求是"不联网时全部功能可用"：这里任何一步不可用、超时或产出不合规，
/// 都会静默落回 [LocalOracle]，调用方感觉不到差别。
class KindlingAiOracle implements KindlingOracle {
  KindlingAiOracle({
    KindlingAiCall? call,
    Future<bool> Function()? isAvailable,
    LocalOracle fallback = const LocalOracle(),
  })  : _call = call ?? _defaultCall,
        _isAvailable = isAvailable ?? _defaultAvailability,
        _fallback = fallback;

  final KindlingAiCall _call;
  final Future<bool> Function() _isAvailable;
  final LocalOracle _fallback;

  /// 方案 §7 规定的 system prompt，一字不改。
  static const String systemPrompt = '你只提问，不给建议、不安慰、不总结、不鼓励。\n'
      '每次只输出一个问句，不超过 25 字。\n'
      '禁止出现：加油、相信自己、你可以、建议、不妨、试试看。';

  static const String candidateSystemPrompt = '你只做切分，不评价、不建议、不总结、不鼓励。\n'
      '把用户的原话切成一行一条，保留原话措辞，不要改写成目标或计划。\n'
      '每条 2 到 40 字，最多 12 条，只输出这些行。';

  /// 追问最多问到第四步就收。
  static const int maxResistanceSteps = 4;

  /// 单问句上限，超过就当模型没守规矩。
  static const int maxQuestionLength = 25;

  /// 等模型的上限。宿主默认给 90 秒，那是给长文本用的；这里是用户点一下就要
  /// 看到下一问的地方，超过这点时间就直接用本地问题梯。
  static const Duration questionTimeout = Duration(seconds: 3);

  /// 切候选可以稍微多等一会，但也不能让「完成」之后干等着。
  static const Duration extractTimeout = Duration(seconds: 8);

  /// 出现任何一个词就判定不合规，落回本地问题梯。
  static const List<String> bannedWords = <String>[
    '加油',
    '相信自己',
    '你可以',
    '建议',
    '不妨',
    '试试看',
  ];

  static Future<String> _defaultCall({
    required String prompt,
    required String systemPrompt,
    required String purpose,
  }) {
    return UnifiedAiService().generateText(
      prompt: prompt,
      purpose: purpose,
      systemPrompt: systemPrompt,
      maxTokens: 400,
    );
  }

  static Future<bool> _defaultAvailability() async {
    try {
      final config = await UnifiedAiService().resolveGlobalConfig();
      return config.available;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> extractCandidates(Map<String, String> answers) async {
    final List<String> local = await _fallback.extractCandidates(answers);
    final String source = answers.values
        .map((String v) => v.trim())
        .where((String v) => v.isNotEmpty)
        .join('\n');
    if (source.isEmpty) return local;
    if (!await _isAvailable()) return local;

    try {
      final String raw = await _call(
        prompt: source,
        systemPrompt: candidateSystemPrompt,
        purpose: 'kindling.extract_candidates',
      ).timeout(extractTimeout);
      final List<String> parsed = LocalOracle.splitCandidates(<String>[raw]);
      return parsed.isEmpty ? local : parsed;
    } catch (_) {
      return local;
    }
  }

  @override
  Future<String?> nextResistanceQuestion(
    List<({String q, String? a})> history,
  ) async {
    if (history.length >= maxResistanceSteps) return null;
    final String? local = await _fallback.nextResistanceQuestion(history);

    // 第一问不问模型：这时还没有任何回答，模型没有上下文可用，等它只是让
    // 用户对着白屏干等。后面几问才有得追。
    if (history.isEmpty) return local;
    if (!await _isAvailable()) return local;

    try {
      final String raw = await _call(
        prompt: _historyPrompt(history),
        systemPrompt: systemPrompt,
        purpose: 'kindling.next_resistance_question',
      ).timeout(questionTimeout);
      final String question = _tidy(raw);
      return _isUsable(question) ? question : local;
    } catch (_) {
      return local;
    }
  }

  static String _historyPrompt(List<({String q, String? a})> history) {
    if (history.isEmpty) return '开始追问。';
    final StringBuffer buffer = StringBuffer('已经问过：\n');
    for (final ({String q, String? a}) step in history) {
      buffer.writeln('问：${step.q}');
      buffer.writeln('答：${(step.a ?? '').isEmpty ? '（跳过）' : step.a}');
    }
    buffer.write('接着问下一句。');
    return buffer.toString();
  }

  static String _tidy(String raw) {
    final String first = raw
        .trim()
        .split('\n')
        .map((String line) => line.trim())
        .firstWhere((String line) => line.isNotEmpty, orElse: () => '');
    return first.replaceFirst(RegExp(r'^[\s\-\*·•]+'), '').trim();
  }

  static bool _isUsable(String question) {
    if (question.isEmpty) return false;
    if (question.length > maxQuestionLength) return false;
    if (!question.endsWith('？') && !question.endsWith('?')) return false;
    for (final String banned in bannedWords) {
      if (question.contains(banned)) return false;
    }
    return true;
  }
}
