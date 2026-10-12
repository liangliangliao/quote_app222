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

  @override
  bool get sendsData => true;

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

  // ------------------------------------------------------------ 一致度与难度

  static const String alignSystemPrompt =
      '你是严谨的决策对照助手，依据叔本华：根本欲求不变，行为与欲求不符常因认识有误而选错手段；'
      '欲求只是假设，证据强弱不同。只输出 JSON 对象，不输出解释和代码围栏。不替用户做决定。';

  @override
  Future<ZAlignResult> scoreAlignment({
    required String situation,
    required String optionA,
    required String optionB,
    required List<ZDesire> desires,
  }) async {
    if (desires.isEmpty || !await _isAvailable()) return const ZAlignResult();
    try {
      final StringBuffer list = StringBuffer();
      for (int i = 0; i < desires.length; i++) {
        list.writeln('${i + 1}. ${desires[i].text}'
            '（${desires[i].strong ? '被行为支持' : '自述'}）');
      }
      final String prompt = '$situation\n'
          '要对照的欲求假设（按顺序，括号内是证据等级）：\n$list'
          '请只回答：每个选项对每个欲求，在「本周」「一年」「十年」三个尺度上推进该欲求的程度'
          '（0 到 100 的整数；50 表示无关，低于 50 表示在背离）；以及每个选项做起来的难度，'
          '和完成它需要的外部条件（资源、他人的同意或配合、时机、身体条件等）及可控度。'
          '注意：一致度不是对错判断，也不保证幸福；证据弱就在 why 里说明；不要替用户决定。'
          '只输出 JSON 对象：'
          '{"rows":[{"a":{"w":0,"y":0,"d":0,"why":"不超过30字"},'
          '"b":{"w":0,"y":0,"d":0,"why":"不超过30字"}}],'
          '"diff":{"a":{"tier":"易|中|难","ring":"认知|动机|行为|环境","why":"不超过30字",'
          '"ladder":["小步","中步","大步"],"ext":[{"t":"条件","c":"可控|可影响|不可控"}]},'
          '"b":{同上}},"conf":0到1的数字}。rows 与欲求按顺序一一对应；w 本周，y 一年，d 十年。';
      final String raw = await _call(
        prompt: prompt,
        systemPrompt: alignSystemPrompt,
        purpose: 'zhaojian.score_alignment',
        maxTokens: 2500,
      ).timeout(callTimeout);
      return parseAlignment(raw, desires.length);
    } catch (_) {
      return const ZAlignResult();
    }
  }

  /// 把模型返回的文本解析成一致度结果。解析失败、行数对不上时返回空。
  static ZAlignResult parseAlignment(String raw, int desireCount) {
    final dynamic obj = _parseObject(raw);
    if (obj is! Map) return const ZAlignResult();
    final dynamic rowsRaw = obj['rows'];
    if (rowsRaw is! List || rowsRaw.length < desireCount) {
      return const ZAlignResult();
    }
    int num100(dynamic v) {
      final num? n = v is num ? v : num.tryParse('$v');
      if (n == null || n.isNaN) return 50;
      return n.round().clamp(0, 100).toInt();
    }

    List<int> triple(dynamic m) {
      if (m is! Map) return <int>[50, 50, 50];
      return <int>[num100(m['w']), num100(m['y']), num100(m['d'])];
    }

    final List<ZAlignRow> rows = <ZAlignRow>[];
    for (int i = 0; i < desireCount; i++) {
      final dynamic r = rowsRaw[i];
      if (r is! Map) return const ZAlignResult();
      rows.add(ZAlignRow(
        a: triple(r['a']),
        b: triple(r['b']),
        reasonA: r['a'] is Map ? '${(r['a'] as Map)['why'] ?? ''}' : '',
        reasonB: r['b'] is Map ? '${(r['b'] as Map)['why'] ?? ''}' : '',
      ));
    }
    final dynamic diff = obj['diff'];
    final dynamic confRaw = obj['conf'];
    final double? conf =
        confRaw is num ? confRaw.toDouble().clamp(0.0, 1.0).toDouble() : null;
    return ZAlignResult(
      rows: rows,
      diffA: _parseDifficulty(diff is Map ? diff['a'] : null),
      diffB: _parseDifficulty(diff is Map ? diff['b'] : null),
      confidence: conf,
      source: sourceNote,
    );
  }

  static ZDifficulty _parseDifficulty(dynamic d) {
    if (d is! Map) return const ZDifficulty();
    final String tier = '${d['tier'] ?? ''}'.trim();
    final String ring = '${d['ring'] ?? ''}'.trim();
    final dynamic ladder = d['ladder'];
    final dynamic ext = d['ext'];
    return ZDifficulty(
      tier: ZCopy.difficultyTiers.contains(tier) ? tier : '',
      ring: ZCopy.rings.contains(ring) ? ring : '',
      reason: '${d['why'] ?? ''}'.trim(),
      ladder: ladder is List
          ? ladder.map((dynamic e) => '$e'.trim()).where((String e) => e.isNotEmpty).take(3).toList()
          : <String>[],
      externals: ext is List
          ? ext
              .whereType<Map>()
              .map((Map e) => ZExternal(
                    '${e['t'] ?? ''}'.trim(),
                    ZCopy.controlLevels.contains('${e['c']}'.trim())
                        ? '${e['c']}'.trim()
                        : '可影响',
                  ))
              .where((ZExternal e) => e.text.isNotEmpty)
              .take(4)
              .toList()
          : <ZExternal>[],
    );
  }

  static dynamic _parseObject(String raw) {
    final String s = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    final int a = s.indexOf('{');
    final int b = s.lastIndexOf('}');
    if (a < 0 || b <= a) return null;
    try {
      return jsonDecode(s.substring(a, b + 1));
    } catch (_) {
      return null;
    }
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
