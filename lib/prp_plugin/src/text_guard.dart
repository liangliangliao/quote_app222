import 'models.dart';

/// 插件自带的最小文本护栏。宿主可以换成更严格的实现（例如接敌人的 SafetyValve）。
class BuiltinTextGuard {
  const BuiltinTextGuard._();

  static const String crisisMessage =
      '如果你现在很难受，先别管这个练习。请联系身边信得过的人，或当地的心理援助热线，和他们说说。这个练习可以先放一放。';

  static const List<String> crisisMarkers = <String>[
    '不想活',
    '不想再活',
    '想死',
    '自杀',
    '自残',
    '轻生',
    '活不下去',
    '结束生命',
    '结束自己',
    '伤害自己',
    '撑不下去',
    '了结自己',
  ];

  /// 对“自己”的身份判断：不是行为，不入账。
  static final List<RegExp> identityPatterns = <RegExp>[
    RegExp(r'我(就)?是(一)?个?[^，。！？\s]{0,6}(废物|垃圾|失败者|没用|笨蛋|蠢货|废柴)'),
    RegExp(r'我(总是|永远|从来|一直)(都)?(不行|做不好|做不到|失败|搞砸)'),
    RegExp(r'我(真|太|好)(没用|笨|蠢|废|差劲|失败)'),
    RegExp(r'(没出息|没救了|不配|烂人|废物|垃圾)'),
  ];

  static bool isCrisis(String text) {
    final String t = text.replaceAll(RegExp(r'\s'), '');
    return crisisMarkers.any(t.contains);
  }

  static bool hasIdentityJudgement(String text) =>
      identityPatterns.any((RegExp p) => p.hasMatch(text));

  /// 用户写的任何文字先过这里。
  static GuardResult check(String text) {
    if (isCrisis(text)) {
      return const GuardResult(
        ok: false,
        crisis: true,
        problems: <String>['crisis'],
        message: crisisMessage,
      );
    }
    final List<String> problems = <String>[];
    if (hasIdentityJudgement(text)) problems.add('identity');
    return GuardResult(ok: problems.isEmpty, problems: problems);
  }
}

/// 空话检查：说不出具体情境的原因不收。
class VagueCheck {
  const VagueCheck._();

  static const int minChars = 4;

  static const List<String> vagueWords = <String>[
    '忙',
    '没时间',
    '太忙',
    '懒',
    '累',
    '不想',
    '不知道',
    '太难',
    '没心情',
    '没动力',
    '没状态',
    '就是',
    '随便',
    '没什么',
    '不好说',
  ];

  /// 太短，或者整句就是一个空词，算空话。
  static bool isVague(String text) {
    final String t = text.trim();
    if (t.length < minChars) return true;
    for (final String w in vagueWords) {
      if (t == w || t == '$w。' || t == '太$w') return true;
    }
    return false;
  }
}

enum SentenceKind { fact, interpretation, selfBlame }

class ClassifiedSentence {
  const ClassifiedSentence(this.text, this.kind);

  final String text;
  final SentenceKind kind;

  ClassifiedSentence withKind(SentenceKind k) => ClassifiedSentence(text, k);
}

/// 把用户的话切成“事实 / 解释 / 自责”。纯本地启发式，用户可以手动改。
class SentenceClassifier {
  const SentenceClassifier._();

  static const List<String> _interpretMarkers = <String>[
    '因为',
    '所以',
    '可能',
    '大概',
    '也许',
    '觉得',
    '感觉',
    '应该',
    '估计',
    '总是',
    '每次',
    '一直',
    '不够',
    '没动力',
    '不想',
    '懒',
    '太',
  ];

  static List<ClassifiedSentence> classify(String text) {
    final List<String> parts = text
        .split(RegExp(r'[。！？!?；;\n]+'))
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();
    return parts.map((String s) => ClassifiedSentence(s, _kindOf(s))).toList();
  }

  static SentenceKind _kindOf(String s) {
    if (BuiltinTextGuard.hasIdentityJudgement(s)) return SentenceKind.selfBlame;
    if (_interpretMarkers.any(s.contains)) return SentenceKind.interpretation;
    return SentenceKind.fact;
  }

  /// 只保留被标为“事实”的句子，作为证据引用。
  static List<String> factsOf(List<ClassifiedSentence> list) => list
      .where((ClassifiedSentence c) => c.kind == SentenceKind.fact)
      .map((ClassifiedSentence c) => c.text)
      .toList();
}
