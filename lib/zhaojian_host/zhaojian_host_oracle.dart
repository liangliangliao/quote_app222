import '../zhaojian/zhaojian.dart';

/// 宿主的引擎组合：补全动机交给文字引擎；打分优先用真实的决策引擎，
/// 它不可用（没启用、没密钥、限流、响应不合规）就回落到文字引擎的模拟打分，
/// 再不行就返回空，由模块回落到规则推荐。
class ZhaojianHostOracle extends ZhaojianOracle {
  const ZhaojianHostOracle({required this.text, required this.scorer});

  /// 能生成文字的引擎（AI）。
  final ZhaojianOracle text;

  /// 优先使用的打分引擎（JEV）。
  final ZhaojianOracle scorer;

  @override
  String get label => 'JEV（已在「证据成长」里启用时）或 AI；都没有时用规则推荐';

  @override
  bool get sendsData => true;

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
  Future<ZScoreResult> scoreMotives({
    required String situation,
    required List<ZMotive> motives,
  }) async {
    ZScoreResult r = const ZScoreResult();
    try {
      r = await scorer.scoreMotives(situation: situation, motives: motives);
    } catch (_) {
      r = const ZScoreResult();
    }
    if (!r.isEmpty) return r;
    return text.scoreMotives(situation: situation, motives: motives);
  }
}
