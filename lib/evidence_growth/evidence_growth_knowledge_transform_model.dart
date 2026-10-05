import 'evidence_growth_journey_models.dart';

/// 「抽象知识 → 直观 → 理解 → 行动」6 步转换。
///
/// 输入只有两样：知识卡的【大标题】和【原案例 / 研究依据】。
/// 输出固定 6 步：还原问题 / 三正一反 / 类比或画图 / 用自己的话讲一遍 /
/// 压缩成行动规则 / 马上小实验。

class KnowledgeTransformRule {
  const KnowledgeTransformRule(this.trigger, this.action);
  final String trigger;
  final String action;
}

class KnowledgeTransform {
  const KnowledgeTransform({
    required this.core,
    required this.problem,
    required this.examples,
    required this.counter,
    required this.analogy,
    required this.differs,
    required this.diagram,
    required this.explain,
    required this.selfCheck,
    required this.rules,
    required this.action,
    required this.predict,
    required this.check,
    required this.safety,
  });

  static const String defaultSelfCheck = '合上这张卡，用一两句话把它讲给一个外行听；讲不顺的地方，就是还没真懂的地方。';
  static const String defaultSafety =
      '如果做的时候明显不适、会影响到别人，或事情无法挽回，就停下；需要时请找信任的人或专业人士。';

  final String core;
  final String problem;
  final List<String> examples;
  final String counter;
  final String analogy;
  final String differs;
  final String diagram;
  final String explain;
  final String selfCheck;
  final List<KnowledgeTransformRule> rules;
  final String action;
  final String predict;
  final String check;
  final String safety;

  /// 解析模型返回；缺少任何一步的必要内容都视为失败，不做本地编造。
  factory KnowledgeTransform.fromJson(GrowthData json) {
    String s(Object? v) => '${v ?? ''}'.trim();
    final experiment = growthMap(json['experiment']);
    final examples = growthStrings(json['examples'])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final rules = growthRows(json['rules'])
        .map((r) => KnowledgeTransformRule(s(r['trigger']), s(r['action'])))
        .where((r) => r.trigger.isNotEmpty && r.action.isNotEmpty)
        .toList();
    final selfCheck = s(json['selfCheck']);
    final safety = s(experiment['safety']);
    final result = KnowledgeTransform(
      core: s(json['core']),
      problem: s(json['problem']),
      examples: examples.take(3).toList(),
      counter: s(json['counter']),
      analogy: s(json['analogy']),
      differs: s(json['differs']),
      diagram: s(json['diagram']),
      explain: s(json['explain']),
      selfCheck: selfCheck.isEmpty ? defaultSelfCheck : selfCheck,
      rules: rules.take(3).toList(),
      action: s(experiment['action']),
      predict: s(experiment['predict']),
      check: s(experiment['check']),
      safety: safety.isEmpty ? defaultSafety : safety,
    );
    if (!result.isComplete) throw const FormatException('TRANSFORM_INCOMPLETE');
    return result;
  }

  bool get isComplete =>
      core.isNotEmpty &&
      problem.isNotEmpty &&
      examples.length == 3 &&
      counter.isNotEmpty &&
      analogy.isNotEmpty &&
      differs.isNotEmpty &&
      explain.isNotEmpty &&
      rules.isNotEmpty &&
      action.isNotEmpty &&
      predict.isNotEmpty &&
      check.isNotEmpty;

  GrowthData toJson() => {
        'core': core,
        'problem': problem,
        'examples': examples,
        'counter': counter,
        'analogy': analogy,
        'differs': differs,
        'diagram': diagram,
        'explain': explain,
        'selfCheck': selfCheck,
        'rules': [
          for (final r in rules) {'trigger': r.trigger, 'action': r.action}
        ],
        'experiment': {
          'action': action,
          'predict': predict,
          'check': check,
          'safety': safety,
        },
      };

  /// 复制与朗读共用的纯文本。
  String toPlainText(String title) {
    final b = StringBuffer()
      ..writeln(title)
      ..writeln('核心：$core')
      ..writeln()
      ..writeln('1 还原问题')
      ..writeln(problem)
      ..writeln()
      ..writeln('2 三正一反');
    for (var i = 0; i < examples.length; i++) {
      b.writeln('正例${i + 1}：${examples[i]}');
    }
    b
      ..writeln('反例：$counter')
      ..writeln()
      ..writeln('3 类比或画图')
      ..writeln('类比：$analogy')
      ..writeln('不像的地方：$differs');
    if (diagram.isNotEmpty) b.writeln(diagram);
    b
      ..writeln()
      ..writeln('4 用自己的话讲一遍')
      ..writeln(explain)
      ..writeln('自测：$selfCheck')
      ..writeln()
      ..writeln('5 压缩成行动规则');
    for (final r in rules) {
      b.writeln('${r.trigger}，${r.action}');
    }
    b
      ..writeln()
      ..writeln('6 马上小实验（24 小时内）')
      ..writeln('做什么：$action')
      ..writeln('事前预期：$predict')
      ..writeln('事后对照：$check')
      ..writeln('边界：$safety');
    return b.toString().trim();
  }
}
