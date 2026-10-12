import 'dart:convert';

import '../services/unified_ai_service.dart';
import '../zhaojian/zhaojian.dart';

/// 调一次模型，拿回纯文本。抽出来是为了测试可以不碰网络和宿主配置。
typedef ZhaojianAiCall = Future<String> Function({
  required String prompt,
  required String systemPrompt,
  required String purpose,
  required int maxTokens,
});

/// AI 版动机补全与打分（模拟决策引擎）。
///
/// 硬要求是「不联网、没配 AI 时全部功能可用」：这里任何一步不可用、超时或产出
/// 不合规，都返回空结果，调用方会落回内置动机库与规则推荐。
///
/// 注意：打分由通用大模型按「决策引擎」的格式给出，**不是**真实的
/// OpenAI Decisions API 或 JEV；接真实引擎是下一阶段的事（见 AUDIT.md）。
class ZhaojianAiOracle extends ZhaojianOracle {
  ZhaojianAiOracle({
    ZhaojianAiCall? call,
    Future<bool> Function()? isAvailable,
  })  : _call = call ?? _defaultCall,
        _isAvailable = isAvailable ?? _defaultAvailability;

  final ZhaojianAiCall _call;
  final Future<bool> Function() _isAvailable;

  static const String sourceNote = 'AI 按决策引擎的格式逐个打分（不是真实的 Decisions API 或 JEV）';

  @override
  String get label => 'AI 补全与打分（模拟决策引擎）';

  static const Duration callTimeout = Duration(seconds: 100);

  static const String motiveSystemPrompt =
      '你是叔本华式的动机分析师，只输出 JSON 数组，不输出解释和代码围栏。'
      '不替用户做决定，不给建议。';

  static const String scoreSystemPrompt =
      '你现在模拟一个只做决策、不写文字的模型：对每个候选只给分数和置信度，'
      '信息不足就给低置信，不要硬凑。只输出 JSON 数组，不输出解释和代码围栏。';

  static Future<String> _defaultCall({
    required String prompt,
    required String systemPrompt,
    required String purpose,
    required int maxTokens,
  }) {
    return UnifiedAiService().generateText(
      prompt: prompt,
      purpose: purpose,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
    );
  }

  static Future<bool> _defaultAvailability() async {
    try {
      final UnifiedAiResolvedConfig config =
          await UnifiedAiService().resolveGlobalConfig();
      return config.available;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------ 动机补全

  @override
  Future<List<ZMotive>> completeMotives({
    required String question,
    required String optionA,
    required String optionB,
    required String profile,
  }) async {
    if (!await _isAvailable()) return <ZMotive>[];
    try {
      final List<List<ZMotive>> parts = await Future.wait(
        <Future<List<ZMotive>>>[
          _motivePart(question, optionA, optionB, profile, 0, 5),
          _motivePart(question, optionA, optionB, profile, 6, 11),
        ],
      );
      return <ZMotive>[...parts[0], ...parts[1]];
    } catch (_) {
      return <ZMotive>[];
    }
  }

  Future<List<ZMotive>> _motivePart(
    String question,
    String optionA,
    String optionB,
    String profile,
    int from,
    int to,
  ) async {
    final StringBuffer cats = StringBuffer();
    for (int i = from; i <= to; i++) {
      if (i > from) cats.write('，');
      cats.write('$i=${ZCopy.categories[i]}');
    }
    final String prompt = '用户面临选择：「$question」。选项A：$optionA；选项B：$optionB。'
        '$profile\n'
        '请补全用户可能没意识到的动机，共 30 条，类别只能用这些序号：$cats（尽量均匀）。'
        '每条要具体到这个选择，字段：t(动机，不超过14字)、c(类别序号，数字)、'
        'k("abs"抽象思想或"int"直观印象)、s("a"|"b"|"both"，它把人拉向哪边)、'
        'y("ap"想要靠近或"av"害怕回避)、'
        'v(一句不超过45字的第二人称现在时画面，写出那一刻看到、听到、身体感到什么，让人真切体验到这个动机的分量)。'
        '其中至少 5 条是用户可能不愿承认的动机。只输出 JSON 数组。';
    final String raw = await _call(
      prompt: prompt,
      systemPrompt: motiveSystemPrompt,
      purpose: 'zhaojian.complete_motives',
      maxTokens: 3500,
    ).timeout(callTimeout);
    return parseMotives(raw, from: from, to: to);
  }

  /// 把模型返回的文本解析成动机。解析失败返回空，不抛异常。
  static List<ZMotive> parseMotives(String raw, {int from = 0, int to = 11}) {
    final List<dynamic> arr = _parseArray(raw);
    final List<ZMotive> out = <ZMotive>[];
    for (final dynamic e in arr) {
      if (e is! Map) continue;
      final String t = (e['t'] ?? '').toString().trim();
      final String v = (e['v'] ?? '').toString().trim();
      if (t.isEmpty || v.isEmpty) continue;
      final dynamic cRaw = e['c'];
      int c = cRaw is num ? cRaw.toInt() : (int.tryParse('$cRaw') ?? from);
      if (c < 0 || c >= ZCopy.categories.length) c = from;
      final String s = '${e['s']}';
      out.add(ZMotive(
        text: t,
        cat: c,
        kind: e['k'] == 'abs' ? 'abs' : 'int',
        side: (s == 'a' || s == 'b') ? s : 'both',
        valence: e['y'] == 'av' ? 'av' : 'ap',
        scene: v,
        ai: true,
      ));
    }
    return out;
  }

  // ------------------------------------------------------------ 打分

  @override
  Future<ZScoreResult> scoreMotives({
    required String situation,
    required List<ZMotive> motives,
  }) async {
    if (motives.isEmpty || !await _isAvailable()) return const ZScoreResult();
    try {
      final StringBuffer list = StringBuffer();
      for (int i = 0; i < motives.length; i++) {
        final ZMotive m = motives[i];
        final String cat = m.cat >= 0 ? ZCopy.categories[m.cat] : '自己写的';
        list.writeln('$i|${m.text}（$cat）');
      }
      final String prompt = '$situation\n'
          '下面是候选动机（序号|动机）：\n$list'
          '对每条动机回答：s=在用户做这个选择的现场，它对决定的拉力有多大（0 到 4 的数，'
          '可以是小数，0=无关，4=决定性）；conf=置信度（0 到 1）。'
          '每条独立判断，不要互相比较。只输出 JSON 数组 [{"i":序号,"s":数,"conf":数}]。';
      final String raw = await _call(
        prompt: prompt,
        systemPrompt: scoreSystemPrompt,
        purpose: 'zhaojian.score_motives',
        maxTokens: 3000,
      ).timeout(callTimeout);
      return parseScores(raw, motives.length);
    } catch (_) {
      return const ZScoreResult();
    }
  }

  /// 把模型返回的文本解析成打分。解析失败或不足一半的候选有分数时返回空。
  static ZScoreResult parseScores(String raw, int count) {
    final List<dynamic> arr = _parseArray(raw);
    final Map<int, double> pulls = <int, double>{};
    final Map<int, double> confs = <int, double>{};
    for (final dynamic e in arr) {
      if (e is! Map) continue;
      final dynamic iRaw = e['i'];
      final int? i = iRaw is num ? iRaw.toInt() : int.tryParse('$iRaw');
      final dynamic sRaw = e['s'];
      final double? s = sRaw is num ? sRaw.toDouble() : double.tryParse('$sRaw');
      if (i == null || s == null || i < 0 || i >= count || s.isNaN) continue;
      pulls[i] = s.clamp(0.0, 4.0).toDouble();
      final dynamic cRaw = e['conf'];
      final double? c = cRaw is num ? cRaw.toDouble() : double.tryParse('$cRaw');
      if (c != null && !c.isNaN) confs[i] = c.clamp(0.0, 1.0).toDouble();
    }
    if (pulls.length * 2 < count) return const ZScoreResult();
    return ZScoreResult(pulls: pulls, confidences: confs, source: sourceNote);
  }

  static List<dynamic> _parseArray(String raw) {
    final String s = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    final int a = s.indexOf('[');
    final int b = s.lastIndexOf(']');
    if (a < 0 || b <= a) return <dynamic>[];
    try {
      final dynamic v = jsonDecode(s.substring(a, b + 1));
      return v is List ? v : <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }
}
