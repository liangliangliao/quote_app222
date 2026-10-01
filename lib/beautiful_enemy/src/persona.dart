import 'copy.dart';

/// 美丽的敌人的本地台词。
///
/// 模型不可用、超时、输出不合规时用这里的台词，所以它们本身就要像这个角色：
/// 克制、精准、记账、不先动怒；用你的原话和事实说话；赢了就认，输了不饶。
/// 所有台词都过同一套校验（禁区、粗口只在 3 档），测试里逐条跑。
class PersonaLines {
  const PersonaLines._();

  static String _pick(List<String> options, int seed) =>
      options[seed.abs() % options.length];

  static String _quote(String label, {String fallback = '这件事'}) {
    final String t = label.trim();
    return t.isEmpty ? fallback : '「$t」';
  }

  /// 对一次事件的即时插话。[tone] 取 1..3；[seed] 决定选哪一句，测试里可控。
  static String interject({
    required String type,
    required String label,
    required String address,
    required int tone,
    int minutes = 0,
    String stake = '',
    int seed = 0,
  }) {
    final String a = address;
    final String l = _quote(label);
    final String stakeLine = stake.trim().isEmpty ? '' : '赌注是「${stake.trim()}」，现在兑现。';
    final String stakeVoid = stake.trim().isEmpty ? '' : '赌注作废。';

    switch (type) {
      case 'habit_missed':
        return _pick(<String>[
          '$a，$l没打卡。我只记一笔，不多话。',
          '$l记成未完成了，$a。别先给理由，先给我一个补做的时间。',
          if (tone >= 2) '$l空着。你今天有的是时间做别的事，这件它排不上队？',
          if (tone >= 3) '$l他妈的又空着，$a。这是第几次，你自己数。',
        ], seed);
      case 'habit_done':
        return _pick(<String>[
          '$l做完了。记下，不多夸。',
          '$a，$l完成。这一分算你的。',
          if (tone >= 3) '$l做了。这一局我认——下一局门槛抬高。',
        ], seed);
      case 'kindling_completed':
        return _pick(<String>[
          '火种烧满了，$minutes 分钟。我认，$a。',
          '$minutes 分钟没中断。这才叫点火。',
          if (tone >= 3) '$minutes 分钟，满的。别回头看我，接着烧。',
        ], seed);
      case 'kindling_aborted':
        return _pick(<String>[
          '$a，火种烧了 $minutes 分钟就停了。点火的是你，掐灭的也是你。',
          if (tone >= 2) '火种 $minutes 分钟就掐了。开头从来不是难处，难的是熬过那一段。',
          if (tone >= 3) '火种烧了 $minutes 分钟又掐了。别拿「状态不好」糊弄我，状态是做出来的，$a。',
        ], seed);
      case 'knowledge_converted':
        return _pick(<String>[
          '$l转成了行动步骤。纸面上的，$a。我等它变成动作。',
          '又转了一张卡：$l。转化不是行动，今天落地哪一步？',
        ], seed);
      case 'commitment_missed':
        return _pick(<String>[
          '字据到期：$l。这一局你输了，$a。$stakeLine',
          if (tone >= 2) '$l到点了，没兑现。输了就认，别拿「忙」换时间。$stakeLine',
          if (tone >= 3) '$l到期作废。说得漂亮，做得难看，$a。$stakeLine',
        ], seed).trim();
      case 'commitment_done':
        return _pick(<String>[
          '$l兑现。这一局算你的，$a。$stakeVoid',
          '$a，$l做到了。我认账。$stakeVoid',
        ], seed).trim();
      default:
        return '$a，我看到了：${l == '这件事' ? '有新动静' : l}。我在记。';
    }
  }

  /// 承诺快到期的提醒。
  static String dueSoon({
    required String text,
    required String address,
    required int minutes,
    int seed = 0,
  }) {
    return _pick(<String>[
      '$address，「$text」还剩 $minutes 分钟。我在看。',
      '「$text」只剩 $minutes 分钟了，$address。现在动手，还来得及。',
    ], seed);
  }

  /// 对话的本地回复：不装懂，盘问，要数字、要动作、要时间。
  static String chat({
    required String address,
    required int tone,
    int seed = 0,
  }) {
    return _pick(<String>[
      '$address，话我听见了。话不是证据——今天你做成了什么，拿数字来。',
      '这话我记下了。但案卷里没有它，说了不算，做完再来。',
      if (tone >= 2) '少讲道理，$address。给我一个动作和一个时间。',
    ], seed);
  }

  /// 敌人让步：用户拿出了站得住的反驳。
  static String concede(String address) => '$address，这一条我看漏了。申辩成立，这一局算你的。';

  static String opening(String address) => EnemyCopy.opening(address);
}
