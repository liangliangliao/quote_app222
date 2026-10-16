/// 「美丽的敌人」的动机刺激策略。
///
/// 核心不是把话说得更狠，而是用最小、可控的外部刺激，把用户从停滞推入
/// stretch zone：先事实，再张力，再给一个可执行动作。刺激针对行为、借口、
/// 言行差距，不针对人格；挑衅只在用户明确允许且强度 >= 2 时可用。
class StimulusStyle {
  const StimulusStyle._();

  static const String mirror = 'mirror';
  static const String integrity = 'integrity';
  static const String challenge = 'challenge';
  static const String competition = 'competition';
  static const String provocation = 'provocation';

  static const List<String> all = <String>[
    mirror,
    integrity,
    challenge,
    competition,
    provocation,
  ];

  static String label(String style) {
    switch (style) {
      case integrity:
        return '言行一致';
      case challenge:
        return '直接挑战';
      case competition:
        return '自我竞争';
      case provocation:
        return '轻度挑衅';
      case mirror:
      default:
        return '事实镜照';
    }
  }

  static String help(String style) {
    switch (style) {
      case integrity:
        return '把你自己写下的承诺与当前行为并排，让“言行不一致”本身产生推动力。';
      case challenge:
        return '把问题变成一场现在就能接下的挑战：少解释，先做一个动作。';
      case competition:
        return '只和自己的旧记录、承诺或当前目标较量，不拿别人压你。';
      case provocation:
        return '用克制的挑衅激起“我偏要证明给你看”的趋近动机；只冲着借口和回避。';
      case mirror:
      default:
        return '只把账上的事实摆出来，不替你解释，让事实本身形成张力。';
    }
  }
}

class StimulusFeedback {
  const StimulusFeedback._();

  static const String fired = 'fired';
  static const String flat = 'flat';
  static const String tooMuch = 'too_much';

  static const Set<String> all = <String>{fired, flat, tooMuch};
}

/// 纯逻辑选择器：不读数据库，所以可以独立测试。
class MotivationStimulus {
  const MotivationStimulus._();

  /// 有明确反馈时优先使用得分最高的方式；同分时用 [seed] 轮换，避免永远卡在第一种。
  ///
  /// 挑衅必须同时满足：用户允许 + 当前有效强度 >= 2。
  static String choose({
    required int intensity,
    required bool allowProvocation,
    required Map<String, int> scores,
    required int seed,
  }) {
    final List<String> candidates = <String>[
      StimulusStyle.mirror,
      StimulusStyle.integrity,
      StimulusStyle.challenge,
      if (intensity >= 2) StimulusStyle.competition,
      if (intensity >= 2 && allowProvocation) StimulusStyle.provocation,
    ];

    int best = -999;
    for (final String s in candidates) {
      final int score = scores[s] ?? 0;
      if (score > best) best = score;
    }
    final List<String> top =
        candidates.where((String s) => (scores[s] ?? 0) == best).toList();
    return top[seed.abs() % top.length];
  }

  static int feedbackDelta(String feedback) {
    switch (feedback) {
      case StimulusFeedback.fired:
        return 2;
      case StimulusFeedback.flat:
        return -1;
      case StimulusFeedback.tooMuch:
        return -4;
      default:
        return 0;
    }
  }

  static int updatedScore(int current, String feedback) =>
      (current + feedbackDelta(feedback)).clamp(-8, 8);

  /// 给模型的策略说明。所有策略都保留“beautiful + enemy”双重约束。
  static String instruction(String style) {
    switch (style) {
      case StimulusStyle.integrity:
        return '使用【言行一致】刺激：只引用用户自己写下的承诺、字据、计划或原话，'
            '把“他说要做什么”和“账上实际发生什么”并排。不要替他发明价值观。'
            '目标是产生可承受的认知张力，然后立刻收束到一个动作。';
      case StimulusStyle.challenge:
        return '使用【直接挑战】刺激：把眼前问题变成一个现在就能接下的小挑战，'
            '用“敢不敢现在做一个动作把这句话打回去”一类结构。'
            '挑战行为，不挑战人格；不要羞辱、威胁或激将到失控。';
      case StimulusStyle.competition:
        return '使用【自我竞争】刺激：只让用户和自己的旧记录、当前字据或今天的账竞争。'
            '不要拿别人比较，不制造社会羞耻。目标是让他现在拿下一分。';
      case StimulusStyle.provocation:
        return '使用【轻度挑衅】刺激：目标是激起“我偏要证明给你看”的证明欲或有益愤怒，'
            '把情绪转成趋近行动。挑衅只能针对借口、回避、拖延和言行差距，绝不针对人格、'
            '身份、能力、外貌、处境；不用羞辱、恐吓、孤立、愧疚绑架。'
            '刺激一句后必须马上给一个可执行动作，不能持续拱火。';
      case StimulusStyle.mirror:
      default:
        return '使用【事实镜照】刺激：克制地把账上的事实和差距摆出来，少评价，'
            '不替用户解释。让事实本身形成张力，然后给一个动作。';
    }
  }

  /// 模型不可用时，在原有、已经过安全校验的事实台词后补一小句动机钩子。
  /// 总长度控制在 195 字内，留给 DraftValidator.validateLine 的 200 字上限。
  static String decorateLocal({
    required String base,
    required String style,
    required String address,
  }) {
    final String suffix;
    switch (style) {
      case StimulusStyle.integrity:
        suffix = '你自己把话写在账上了。现在让行动和它对上。';
        break;
      case StimulusStyle.challenge:
        suffix = '别解释。现在做一个动作，把我这句话打回去。';
        break;
      case StimulusStyle.competition:
        suffix = '这一局只算行动。现在替今天的自己拿下一分。';
        break;
      case StimulusStyle.provocation:
        suffix = '你可以继续拖，让我说中；也可以现在动手，把我说错。';
        break;
      case StimulusStyle.mirror:
      default:
        return _clip(base.trim(), 195);
    }
    final String head = _clip(base.trim(), 195 - suffix.length - 1);
    return '$head\n$suffix';
  }

  static String _clip(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max - 1)}…';
}
