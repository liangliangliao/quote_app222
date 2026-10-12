import 'copy.dart';
import 'data/models.dart';

/// 补全动机、给动机打分的「引擎」接口。
///
/// 硬要求是「不联网、没配 AI 时全部功能可用」：宿主给什么实现都行，
/// 实现里任何一步不可用、超时或产出不合规，都应该返回空结果，由本地实现兜底。
abstract class ZhaojianOracle {
  const ZhaojianOracle();

  /// 给界面看的来源说明。
  String get label;

  /// 这个引擎会不会把用户写下的内容发给外部服务。界面据此决定是否披露。
  bool get sendsData => false;

  /// 针对这个选择补出用户可能没意识到的动机。返回空表示没有（用本地库）。
  Future<List<ZMotive>> completeMotives({
    required String question,
    required String optionA,
    required String optionB,
    required String profile,
  });

  /// 对每个候选动机在现场的拉力打分（下标 -> 0 到 4）。
  /// 返回空表示没有引擎可用（用规则推荐）。
  Future<ZScoreResult> scoreMotives({
    required String situation,
    required List<ZMotive> motives,
  });
}

/// 打分结果：拉力与置信度。
class ZScoreResult {
  const ZScoreResult({
    this.pulls = const <int, double>{},
    this.confidences = const <int, double>{},
    this.source = '',
  });

  final Map<int, double> pulls;
  final Map<int, double> confidences;

  /// 打分来源的说明；空表示没有引擎打分。
  final String source;

  bool get isEmpty => pulls.isEmpty;
}

/// 内置动机库：61 条，12 类，每条配一个「画面」。
List<ZMotive> buildMotiveLibrary() {
  final List<ZMotive> out = <ZMotive>[];
  for (int c = 0; c < ZCopy.motiveLibrary.length; c++) {
    for (final String t in ZCopy.motiveLibrary[c]) {
      out.add(ZMotive.fromLibrary(c, t));
    }
  }
  return out;
}

/// 本地实现：只有内置动机库，没有打分（前 5 走规则推荐）。
class LocalZhaojianOracle extends ZhaojianOracle {
  const LocalZhaojianOracle();

  @override
  String get label => '本地（内置动机库，规则推荐）';

  @override
  Future<List<ZMotive>> completeMotives({
    required String question,
    required String optionA,
    required String optionB,
    required String profile,
  }) async =>
      <ZMotive>[];

  @override
  Future<ZScoreResult> scoreMotives({
    required String situation,
    required List<ZMotive> motives,
  }) async =>
      const ZScoreResult();
}
