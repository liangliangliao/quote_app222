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

  /// 评估两个选项对所选欲求的一致度（本周/一年/十年）和难度。
  /// 默认没有引擎：返回空结果，界面改为用户自评。
  Future<ZAlignResult> scoreAlignment({
    required String situation,
    required String optionA,
    required String optionB,
    required List<ZDesire> desires,
  }) async =>
      const ZAlignResult();
}

/// 要对照的欲求。strong 表示它已被后来的行为反复支持，否则只是自述。
class ZDesire {
  const ZDesire(this.text, {this.strong = false});

  final String text;
  final bool strong;

  @override
  bool operator ==(Object other) =>
      other is ZDesire && other.text == text && other.strong == strong;

  @override
  int get hashCode => Object.hash(text, strong);
}

/// 一个欲求对两个选项的评估：[本周, 一年, 十年]，0 到 100，50 表示无关。
class ZAlignRow {
  const ZAlignRow({
    required this.a,
    required this.b,
    this.reasonA = '',
    this.reasonB = '',
  });

  final List<int> a;
  final List<int> b;
  final String reasonA;
  final String reasonB;
}

/// 完成一个选项所需要的外部条件，以及可控度（可控/可影响/不可控）。
class ZExternal {
  const ZExternal(this.text, this.control);

  final String text;
  final String control;

  bool get uncontrollable => control == '不可控';
}

/// 一个选项的难度评估。
class ZDifficulty {
  const ZDifficulty({
    this.tier = '',
    this.ring = '',
    this.reason = '',
    this.ladder = const <String>[],
    this.externals = const <ZExternal>[],
  });

  /// 易 / 中 / 难 / 空。
  final String tier;

  /// 要动链条的哪一环：认知 / 动机 / 行为 / 环境 / 空。
  final String ring;
  final String reason;

  /// 小、中、大三档阶梯。
  final List<String> ladder;
  final List<ZExternal> externals;
}

/// 一致度与难度的评估结果。
class ZAlignResult {
  const ZAlignResult({
    this.rows = const <ZAlignRow>[],
    this.diffA = const ZDifficulty(),
    this.diffB = const ZDifficulty(),
    this.confidence,
    this.source = '',
  });

  /// 与传入的欲求一一对应。
  final List<ZAlignRow> rows;
  final ZDifficulty diffA;
  final ZDifficulty diffB;

  /// 模型自报的置信度 0 到 1。
  final double? confidence;
  final String source;

  bool get isEmpty => rows.isEmpty;
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
