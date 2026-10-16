import 'motivation_stimulus.dart';

/// 动机画像不是人格诊断，而是「什么外部刺激更可能转化成行动」的工作假设。
/// 默认值只是冷启动先验；问卷可以重设先验，之后真实行为学习会逐步覆盖它。
class MotivationProfile {
  const MotivationProfile._();

  static const String version = 'v1';

  /// 针对当前产品主人冷启动的默认先验（-4..4）。
  ///
  /// 只编码非敏感、与交互直接有关的观察：
  /// - 更偏好具体证据而非空泛鼓励；
  /// - 对直接外部挑战/督促反应较强；
  /// - 言行一致的张力有潜在推动力；
  /// - 自我竞争可用，但不是唯一主轴；
  /// - 挑衅可能点火，但必须谨慎、默认仍需单独授权。
  static const Map<String, int> ownerDefaultPriors = <String, int>{
    StimulusStyle.mirror: 2,
    StimulusStyle.integrity: 3,
    StimulusStyle.challenge: 4,
    StimulusStyle.competition: 2,
    StimulusStyle.provocation: 2,
  };

  static int defaultPrior(String style) => ownerDefaultPriors[style] ?? 0;

  static const List<MotivationQuestion> questions = <MotivationQuestion>[
    MotivationQuestion(
      id: 'q_mirror',
      style: StimulusStyle.mirror,
      text: '当我停滞时，把事实、数字和实际记录直接摆在我面前，会让我更容易行动。',
      low: '基本没用',
      high: '很能推动我',
    ),
    MotivationQuestion(
      id: 'q_integrity',
      style: StimulusStyle.integrity,
      text: '把“我说过要做什么”和“我实际上做了什么”并排，会对我形成明显推动力。',
      low: '基本没用',
      high: '很能推动我',
    ),
    MotivationQuestion(
      id: 'q_challenge',
      style: StimulusStyle.challenge,
      text: '别人直接挑战我“现在就做一个动作证明”，比温和提醒更容易把我点着。',
      low: '更想回避',
      high: '更想行动',
    ),
    MotivationQuestion(
      id: 'q_competition',
      style: StimulusStyle.competition,
      text: '让我和昨天的自己、过去的记录或当前承诺较量，会增强我的行动欲。',
      low: '基本没用',
      high: '很能推动我',
    ),
    MotivationQuestion(
      id: 'q_provocation',
      style: StimulusStyle.provocation,
      text: '克制地说“你可以继续拖，让我说中；也可以现在把我说错”，会激起我的证明欲。',
      low: '会让我关掉',
      high: '会激起我',
    ),
    MotivationQuestion(
      id: 'q_pressure_tolerance',
      style: StimulusStyle.provocation,
      text: '在我已经有压力时，再加一点直接刺激，通常会让我更行动，而不是更想逃开。',
      low: '更容易逃开',
      high: '更容易行动',
      secondaryStyle: StimulusStyle.challenge,
    ),
  ];

  /// 1..5 的问卷答案映射到 -4..4 的先验。
  /// 多道题映射到同一策略时取平均，问卷没有覆盖的策略保留默认值。
  static Map<String, int> priorsFromAnswers(Map<String, int> answers) {
    final Map<String, List<int>> bucket = <String, List<int>>{};
    for (final MotivationQuestion q in questions) {
      final int? raw = answers[q.id];
      if (raw == null) continue;
      final int v = raw.clamp(1, 5);
      final int mapped = (v - 3) * 2; // 1,2,3,4,5 => -4,-2,0,2,4
      (bucket[q.style] ??= <int>[]).add(mapped);
      if (q.secondaryStyle != null) {
        (bucket[q.secondaryStyle!] ??= <int>[]).add(mapped);
      }
    }

    final Map<String, int> out = <String, int>{};
    for (final String style in StimulusStyle.all) {
      final List<int>? values = bucket[style];
      if (values == null || values.isEmpty) {
        out[style] = defaultPrior(style);
      } else {
        final int sum = values.fold<int>(0, (int a, int b) => a + b);
        out[style] = (sum / values.length).round().clamp(-4, 4);
      }
    }
    return out;
  }

  /// 先验 + 已观察到的经验分。先验上限只有 4，而经验可走到 ±8，
  /// 因此样本积累后经验天然会压过冷启动假设。
  static int effectiveScore({required int prior, required int learned}) {
    final int v = prior + learned;
    if (v < -12) return -12;
    if (v > 12) return 12;
    return v;
  }

  static String confidenceLabel(int samples, {required bool questionnaireDone}) {
    if (samples >= 12) return '高：主要来自真实行动';
    if (samples >= 5) return '中：已有多次行为校准';
    if (questionnaireDone) return '初步：问卷 + 少量经验';
    return '冷启动：主要是默认假设';
  }
}

class MotivationQuestion {
  const MotivationQuestion({
    required this.id,
    required this.style,
    required this.text,
    required this.low,
    required this.high,
    this.secondaryStyle,
  });

  final String id;
  final String style;
  final String? secondaryStyle;
  final String text;
  final String low;
  final String high;
}
