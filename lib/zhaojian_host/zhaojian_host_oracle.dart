import '../zhaojian/zhaojian.dart';

/// 宿主的引擎组合：补全动机交给文字引擎；打分优先用真实的决策引擎，
/// 它不可用（没启用、没密钥、限流、响应不合规）就回落到文字引擎的模拟打分，
/// 再不行就返回空，由模块回落到规则推荐。
class ZhaojianHostOracle extends ZhaojianOracle {
  const ZhaojianHostOracle({
    required this.text,
    required this.scorer,
    this.extraScorers = const <ZhaojianOracle>[],
  });

  /// 能生成文字的引擎（AI）。
  final ZhaojianOracle text;

  /// 优先使用的打分引擎（JEV）。
  final ZhaojianOracle scorer;

  /// 之后依次尝试的打分引擎（OpenAI Decisions API）。
  final List<ZhaojianOracle> extraScorers;

  Iterable<ZhaojianOracle> get _scorers => <ZhaojianOracle>[scorer, ...extraScorers];

  @override
  String get label => 'JEV（已在「证据成长」里启用时）、OpenAI Decisions API（已配置 OpenAI 密钥时）或 AI；都没有时用规则推荐';

  @override
  bool get sendsData => true;

  @override
  String get generateLabel => text.generateLabel;

  @override
  Future<List<ZMotive>> completeMotives({
    required String question,
    required String optionA,
    required String optionB,
    required String profile,
  }) {
    return text.completeMotives(
      question: question,
      optionA: optionA,
      optionB: optionB,
      profile: profile,
    );
  }

  @override
  Future<String> generate({
    required String prompt,
    required String purpose,
    int maxTokens = 2500,
  }) {
    return text.generate(prompt: prompt, purpose: purpose, maxTokens: maxTokens);
  }

  @override
  Future<ZAlignResult> scoreAlignment({
    required String situation,
    required String optionA,
    required String optionB,
    required List<ZDesire> desires,
  }) async {
    // 分数优先用真实的决策引擎；难度、阶梯、外部条件是文字，由文字引擎补。
    ZAlignResult real = const ZAlignResult();
    for (final ZhaojianOracle s in _scorers) {
      try {
        real = await s.scoreAlignment(
            situation: situation, optionA: optionA, optionB: optionB, desires: desires);
      } catch (_) {
        real = const ZAlignResult();
      }
      if (!real.isEmpty) break;
    }
    ZAlignResult words = const ZAlignResult();
    try {
      words = await text.scoreAlignment(
          situation: situation, optionA: optionA, optionB: optionB, desires: desires);
    } catch (_) {
      words = const ZAlignResult();
    }
    if (real.isEmpty) return words;
    if (words.isEmpty) return real;
    return ZAlignResult(
      rows: <ZAlignRow>[
        for (int i = 0; i < real.rows.length; i++)
          ZAlignRow(
            a: real.rows[i].a,
            b: real.rows[i].b,
            reasonA: i < words.rows.length ? words.rows[i].reasonA : '',
            reasonB: i < words.rows.length ? words.rows[i].reasonB : '',
          ),
      ],
      diffA: words.diffA,
      diffB: words.diffB,
      confidence: real.confidence ?? words.confidence,
      source: '分数：${real.source}；难度与外部条件：${words.source}',
    );
  }

  @override
  Future<ZScoreResult> scoreMotives({
    required String situation,
    required List<ZMotive> motives,
  }) async {
    for (final ZhaojianOracle s in _scorers) {
      ZScoreResult r = const ZScoreResult();
      try {
        r = await s.scoreMotives(situation: situation, motives: motives);
      } catch (_) {
        r = const ZScoreResult();
      }
      if (!r.isEmpty) return r;
    }
    return text.scoreMotives(situation: situation, motives: motives);
  }
}
