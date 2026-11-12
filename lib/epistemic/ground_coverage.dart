/// Which forms of the principle of sufficient reason a reading really shows.
///
/// The five forms are five questions that can be put to a sentence, not slots
/// to fill: 时间 (继起) and 空间 (位置) belong to the ground of being, 因果 to the
/// ground of becoming, 认识根据 to the ground of knowing, 动机 to the ground of
/// acting. A sentence often states only some of them. For the rest the honest
/// choices are to say so, or to express the form through a related teaching
/// case that is clearly marked as a case.
///
/// This file has no Flutter dependency, so it can be tested with plain Dart.
library;

import 'reading_map_quality.dart';
import 'semantic_scope.dart';

enum GroundPresence {
  /// The sentence itself states it.
  stated,

  /// The wording supports it only through interpretation.
  partial,

  /// The sentence does not, but a related teaching case expresses it.
  viaCase,

  /// The wording has a cue, but no ground was built from it.
  cueOnly,

  /// Neither the sentence nor a case shows it.
  absent,
}

class GroundForm {
  final String kind, title, root;
  final List<String> words;
  final List<RegExp> patterns;
  const GroundForm(this.kind, this.title, this.root, this.words,
      [this.patterns = const []]);

  /// Wording cues found in [text], verbatim, at most four. A cue is a hint
  /// for the reader, never a proof that the form is present.
  List<String> cuesIn(String text) {
    final found = <String>[];
    for (final word in words) {
      if (text.contains(word)) found.add(word);
    }
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) found.add(match.group(0)!);
    }
    return found.take(4).toList();
  }
}

final groundForms = <GroundForm>[
  GroundForm('time', '时间', '存在根据', const [
    '之后', '以后', '之前', '以前', '然后', '随后', '后来', '终于', '曾经', '已经', //
    '正在', '同时', '每当', '始终', '一直', '再次', '隆冬', '清晨', '黄昏', '夜晚',
    '今天', '昨天', '明天', '时候',
  ], [
    RegExp(r'当.{1,12}时'),
    RegExp(r'\d+(?:年|月|日)'),
  ]),
  GroundForm('space', '空间', '存在根据', const [
    '之中', '之间', '之内', '之外', '之上', '之下', '旁边', '附近', '周围', '里面', //
    '外面', '内部', '远处', '近处', '上方', '下方', '左边', '右边', '前方', '后方',
  ], [
    RegExp(r'在.{1,8}[里中内外上下旁]'),
  ]),
  GroundForm('cause', '因果', '生成根据', const [
    '因为', '所以', '因此', '由于', '以致', '导致', '使得', '于是', '从而', '既然', //
    '只要', '如果', '假如', '一旦', '造成', '引起', '带来', '源于', '因而',
  ]),
  GroundForm('evidence', '认识根据', '认识根据', const [
    '证明', '说明', '表明', '可见', '看来', '发现', '知道', '认为', '相信', '意识到', //
    '看见', '听说', '显然', '可知', '证实', '感到', '体验', '感受', '确信',
  ]),
  GroundForm('motive', '动机', '行动根据', const [
    '为了', '想要', '愿意', '决定', '希望', '渴望', '打算', '选择', '追求', '热爱', //
    '不愿', '宁可', '立志', '但愿', '期望', '心愿', '意图',
  ]),
];

class GroundCoverage {
  final GroundForm form;
  final GroundPresence presence;

  /// A teaching case also expresses this form.
  final bool alsoCase;
  final List<String> cues;

  /// The sentence is figurative, so a cue is an image rather than a ground.
  final bool figurative;
  const GroundCoverage(this.form, this.presence,
      {this.alsoCase = false,
      this.cues = const [],
      this.figurative = false});

  String get title => '${form.title} · ${form.root}';

  String get status => switch (presence) {
        GroundPresence.stated => alsoCase ? '本句明示；案例中也有' : '本句明示',
        GroundPresence.partial => alsoCase ? '本句部分明示，需解读；案例中也有' : '本句部分明示，需解读',
        GroundPresence.viaCase => '本句没有，由相关案例表示',
        GroundPresence.cueOnly => figurative
            ? '措辞带有意象，不直接套用；尚无相关案例表示'
            : '措辞中有线索，但没有生成对应的根据',
        GroundPresence.absent => '本句没有；尚无相关案例表示',
      };

  /// Neither the sentence nor a case shows it yet.
  bool get needsCase =>
      presence == GroundPresence.cueOnly || presence == GroundPresence.absent;

  /// Cue text for the reader, empty when there is none.
  String get cueText => cues.isEmpty ? '' : '措辞线索：${cues.map((c) => '「$c」').join('')}';

  /// Five rows, one per form, in the order the panel shows them.
  static List<GroundCoverage> of(SemanticScope value, Iterable<String> sentences) {
    final text = sentences.join('\n');
    final figurative = ReadingMapQuality.figurative(value);
    return [
      for (final form in groundForms)
        () {
          final grounds =
              value.meaningfulGrounds.where((g) => g.kind == form.kind).toList();
          final stated = grounds.any((g) => g.status == 'text_claim');
          final partial = grounds
              .any((g) => g.status == 'interpretation' || g.status == 'unknown');
          final inCase = grounds.any((g) => g.status == 'example');
          final cues = form.cuesIn(text);
          final presence = stated
              ? GroundPresence.stated
              : partial
                  ? GroundPresence.partial
                  : inCase
                      ? GroundPresence.viaCase
                      : cues.isNotEmpty
                          ? GroundPresence.cueOnly
                          : GroundPresence.absent;
          return GroundCoverage(form, presence,
              alsoCase: inCase && (stated || partial),
              cues: cues,
              figurative: figurative);
        }(),
    ];
  }
}
