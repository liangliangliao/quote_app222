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
      case 'commitment_unverified':
        return _pick(<String>[
          '$l你标记完成了，账上没有对应的完整火种记录。这一条我不认，$a。',
          if (tone >= 2) '$l打了勾，账上却是空的。$a，勾是你画的，账是我记的。',
        ], seed);
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

  /// 其它模块有动静，而字据还开着：点出「在忙别的」。
  static String activity({
    required String label,
    required String address,
    required String openText,
    int seed = 0,
  }) {
    return _pick(<String>[
      '$address，你在${_quote(label)}有动静。字据「$openText」还开着，别只顾着别处。',
      '${_quote(label)}我看到了。可「$openText」还在等你，$address。',
    ], seed);
  }

  /// 主动巡查：晨报。
  static String morningBrief({
    required String address,
    required int open,
    required String nextText,
    required int yesterdayDone,
    required int yesterdayMissed,
    int seed = 0,
  }) {
    final String next = nextText.isEmpty ? '' : '，最近的是「$nextText」';
    return _pick(<String>[
      '$address，早。昨天账上：完成 $yesterdayDone，失败 $yesterdayMissed。今天开着 $open 条字据$next。',
      '早，$address。昨天完成 $yesterdayDone、失败 $yesterdayMissed。今天开着 $open 条字据$next。我会盯着。',
    ], seed);
  }

  /// 主动巡查：晚间结算。
  static String eveningLedger({
    required String address,
    required int open,
    required String nextText,
    required int doneToday,
    int seed = 0,
  }) {
    final String next = nextText.isEmpty ? '' : '，最近的是「$nextText」';
    final String done = doneToday == 0 ? '今天案卷里一件完成的事都没有。' : '今天完成了 $doneToday 件。';
    return _pick(<String>[
      '$address，今晚结账。$done还开着 $open 条字据$next。',
      '$address，天快黑了。$done还开着 $open 条字据$next。账不会自己平。',
    ], seed);
  }

  /// 主动巡查：人在 App 里，案卷里却没有新记录。
  static String stall({
    required String address,
    required int minutes,
    required String openText,
    int seed = 0,
  }) {
    return _pick(<String>[
      '$address，你在这儿待了 $minutes 分钟，案卷里没有一条新记录。「$openText」还在等。',
      '$minutes 分钟了，$address。账上一条新的都没有。「$openText」呢？',
    ], seed);
  }

  /// 他说做完了，账上没有。
  static String claimNoRecord(String address) =>
      '$address，你说做完了。案卷里最近 24 小时没有一条完成记录。做的是什么，几点做的？';

  /// 他说没时间，账上他在 App 里待了不短的时间。
  static String claimBusy(String address, int minutes) =>
      '$address，你说没时间。今天你在这个 App 里待了 $minutes 分钟。这段时间去哪了？';

  /// 他说做完了，账上有。
  static String claimConfirmed(String address, int records) =>
      '$address，账上最近 24 小时有 $records 条完成记录。你说的是哪一条？对得上，我认。';

  static const List<String> _openQuestions = <String>[
    '{a}，请回答：你今天最想躲开的那一件事是什么？',
    '{a}，如果明天的你要审今天的账，你现在敢让他看哪一条？',
    '{a}，你上一次主动立字据，是什么时候？账上我找不到。',
    '{a}，哪一个模块你最近一直不打开？为什么偏偏是它？',
    '请{a}说明：今天的时间，账上能解释多少？',
    '{a}，你今天做过的最难的一件事是什么？账上有吗？',
  ];

  /// 反对党的主动质询：用户没动静时，敌人也不闭嘴。
  /// 只用账上有的、缺的事实发问；讽刺对着借口、回避和计划，不对着人。
  static String probe({
    required String type,
    required String address,
    required int tone,
    int n = 0,
    int m = 0,
    int hours = 0,
    int days = 0,
    String label = '',
    String text = '',
    String category = '',
    int seed = 0,
  }) {
    final String a = address;
    switch (type) {
      case 'no_commitments':
        return _pick(<String>[
          '$a，请解释一件事：你手里没有一条字据。没有字据，就没有账可算——这是自由，还是回避？',
          if (tone >= 2) '全场安静。$a，你最近一条字据都没立。反对席今天只能质询空气。',
          if (tone >= 3) '没有字据，没有赌注，没有截止时间。$a，你的账上连一件可以被审的事都没有。',
        ], seed);
      case 'kindling_absent':
        if (hours <= 0) {
          return _pick(<String>[
            '$a，火种：账上没有一次完整的十五分钟。请问，你点过火吗？',
            if (tone >= 2) '议事录里，火种一栏是空白。$a，是没柴，还是你不想让它烧起来？',
          ], seed);
        }
        return _pick(<String>[
          '$a，火种：距离上一次完整的十五分钟已经 $hours 小时。请问这期间，你点的是什么火？',
          if (tone >= 2) '$hours 小时，零次完整点火。$a，是柴不够，还是火柴被你藏起来了？',
        ], seed);
      case 'knowledge_without_action':
        return _pick(<String>[
          '$a，知识转化 $n 次，行动 0 次。纸上谈兵的账，我替你记着。',
          if (tone >= 2) '又转了 $n 张卡，一个动作都没落地。你是在积累知识，还是在积累不行动的理由？',
        ], seed);
      case 'dormant_module':
        return _pick(<String>[
          '$a，「$label」你以前常来，最近 $days 天一条新记录都没有。请问它哪里得罪了你？',
          if (tone >= 2) '「$label」安静了 $days 天。$a，你在躲它，还是它已经被你宣布不重要了？',
        ], seed);
      case 'habit_empty':
        return _pick(<String>[
          '$a，预设行为打卡：过去七天案卷里是 0 条。习惯设了没有，打过卡没有？请向本席说明。',
          if (tone >= 2) '预设行为打卡，七天零条。$a，是没设，还是设了不敢看？',
        ], seed);
      case 'lesson_repeat':
        return _pick(<String>[
          '$a，「$category」，这是第 $n 次。你自己写的教训是：「$text」。你读过吗？',
          if (tone >= 2) '同一个坑，第 $n 次。教训是你亲手写的：「$text」。写下来，是为了留着好看？',
        ], seed);
      case 'ignored_verdict':
        return _pick(<String>[
          '$a，上一条判词你没有回应。沉默不是申辩，我把它记作默认。',
          if (tone >= 2) '判词摆在那儿，你既不接受也不申辩。$a，装作没看见，账也不会消失。',
        ], seed);
      case 'reject_pattern':
        return _pick(<String>[
          '$a，本周你驳回了 $n 项动议，兑现了 $m 条字据。驳回是你的权利，但账上只认兑现。',
          if (tone >= 2) '驳回 $n 次，兑现 $m 次。$a，你的否决权用得比行动权勤快。',
        ], seed);
      case 'unanswered_inquiry':
        return _pick(<String>[
          '$a，我 $hours 小时前问过：「$text」。沉默也是一种答复——要我这样记吗？',
          if (tone >= 2) '「$text」——$hours 小时了，没有回答。$a，不答，就是答了。',
        ], seed);
      default:
        if (hours >= 3 && tone >= 2) {
          return '案卷已经 $hours 小时没有新记录。$a，你是在休息，还是在躲？';
        }
        return _openQuestions[seed.abs() % _openQuestions.length].replaceAll('{a}', a);
    }
  }

  /// 正式提出一项动议。
  static String motion({
    required String address,
    required String text,
    required String dueText,
    required int tone,
    int seed = 0,
  }) {
    return _pick(<String>[
      '$address，本席提一项动议：$text，$dueText前。接受，还是驳回？驳回请给理由。',
      if (tone >= 2) '$address，动议已提交：$text，$dueText前。别让议事厅等你，接受或驳回，二选一。',
    ], seed);
  }

  static String motionAccepted({
    required String address,
    required String text,
    required String dueText,
    String stake = '',
  }) {
    final String s = stake.trim().isEmpty ? '' : '赌注：「${stake.trim()}」。';
    return '$address，动议通过。字据已立：「$text」，$dueText前。$s到期我会来对账。';
  }

  /// 他驳回了动议：不放他轻易脱身。
  static String rebut({required String address, required String reason, int seed = 0}) {
    final String r = reason.length > 30 ? '${reason.substring(0, 30)}…' : reason;
    return _pick(<String>[
      '$address，驳回记下了。理由是：「$r」。账上只认兑现，不认理由。动议我保留。',
      '「$r」——就这？$address，理由我收下，动议不撤。',
    ], seed);
  }

  /// 敌人让步：用户拿出了站得住的反驳。
  static String concede(String address) => '$address，这一条我看漏了。申辩成立，这一局算你的。';

  static String opening(String address) => EnemyCopy.opening(address);
}
