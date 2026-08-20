import 'copy.dart';

/// 追问器。AI 为可选增强：不联网时 LocalOracle 覆盖全部功能。
abstract class KindlingOracle {
  /// 把回溯的原始回答切成候选火种。
  Future<List<String>> extractCandidates(Map<String, String> answers);

  /// 阻抗追问的下一问；返回 null 表示结束。
  Future<String?> nextResistanceQuestion(
    List<({String q, String? a})> history,
  );
}

/// 离线实现：规则切分 + 固定四问。默认使用它，全程不联网。
class LocalOracle implements KindlingOracle {
  const LocalOracle();

  /// 候选条目的长度区间（字数）。
  static const int minLength = 2;
  static const int maxLength = 40;

  static final RegExp _splitter = RegExp(r'[\n\r。；;]+');

  @override
  Future<List<String>> extractCandidates(Map<String, String> answers) async {
    return splitCandidates(answers.values);
  }

  /// 按换行 / 。/ ； 切分，去空白，保留长度 2–40 字的片段，并去重。
  static List<String> splitCandidates(Iterable<String> rawAnswers) {
    final List<String> out = <String>[];
    final Set<String> seen = <String>{};
    for (final String raw in rawAnswers) {
      for (final String piece in raw.split(_splitter)) {
        final String text = _tidy(piece);
        if (text.length < minLength || text.length > maxLength) continue;
        if (!seen.add(text)) continue;
        out.add(text);
      }
    }
    return out;
  }

  static String _tidy(String piece) {
    String text = piece.trim();
    // 去掉列表前缀（-、*、1.、1、等），它们不是内容。
    text = text.replaceFirst(RegExp(r'^[\s\-\*·•]+'), '');
    text = text.replaceFirst(RegExp(r'^\d+[\.、\)]\s*'), '');
    return text.trim();
  }

  @override
  Future<String?> nextResistanceQuestion(
    List<({String q, String? a})> history,
  ) async {
    final int step = history.length;
    if (step >= KCopy.resistanceLadder.length) return null;
    return KCopy.resistanceLadder[step];
  }
}
