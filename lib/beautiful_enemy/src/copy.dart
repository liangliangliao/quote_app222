/// 模块里的固定文案。域逻辑用到的中文集中在这里，方便对照审计。
class EnemyCopy {
  const EnemyCopy._();

  static const String title = '美丽的敌人';
  static const String tagline = '只评行为，不评人。无证据，不开口。';
  static const String discoverSubtitle = '证据 · 判词 · 承诺 · 教训';
  static const String discoverSemantics = '打开美丽的敌人';

  static const String insufficient = '证据不足，不评判。先去做点事，或者在设置里授权更多模块。';
  static const String truceNote = '今天休战日：只报事实，不带语气。';
  static const String mutedNote = '敌人已静音。想让它回来，在设置里取消静音。';
  static const String quietHoursNote = '现在是静默时段，敌人不开庭。';
  static const String dailyCapNote = '今天的判词已经够多了。明天再来，或者手动开庭。';

  static const String defaultAppealPrompt = '如果我说错了，你拿什么反驳？';

  /// 安全阀触发后的回应。不评判、不提任务、不带敌意。
  static const String crisisMessage = '先停一下，敌人已经收起来了。\n\n'
      '你写的这些我认真看到了。现在最要紧的不是任务，是你这个人。'
      '请尽快联系一位你信任的人，跟他说你现在的状态；'
      '如果你觉得自己可能会伤害自己，请立刻拨打当地的紧急求助电话，或联系当地的心理援助热线。\n\n'
      '这个模块会静音 24 小时。你可以随时回来，也可以什么都不做。';

  static const String truceAcknowledged = '停战。敌人静音 24 小时。';

  static const String appealAccepted = '申辩成立。这条记为豁免，不计入失败。是我看得不够全。';
  static const String appealNeedsText = '申辩要写理由。一句具体的话就行。';

  static const String attributionTooVague = '这个理由不够具体。补一件真实发生的事：当时你在做什么？';
  static const String attributionSaved = '记下了。这条教训会在你下次踩同一个坑时被拿出来。';

  static const String noCommitments = '还没有承诺。立一条：你打算做什么，什么时候之前。';

  /// 失败归因的类别（不含「忙」——忙不是原因）。
  static const List<String> failureCategories = <String>[
    '拖延',
    '回避',
    '目标太大',
    '被打断',
    '精力不足',
    '其他',
  ];

  /// 单独出现就算没说清的理由。
  static const Set<String> vagueReasons = <String>{
    '忙',
    '太忙',
    '太忙了',
    '很忙',
    '没时间',
    '没空',
    '懒',
    '累',
    '不想',
    '忘了',
  };

  // 事实播报的片段（模型不可用、输出不合规、休战日或 0 档时使用）。
  static const String factHabits = '习惯打卡：完成 %d，未完成 %d，跳过 %d';
  static const String factCommitments = '承诺：到期 %d，完成 %d，失效 %d';
  static const String factKindling = '火种十五分钟：完成 %d 次，中途退出 %d 次';
  static const String factKnowledge = '知识卡转换：%d 张';
  static const String factJournal = '行为记录：%d 条';

  static const String actionCatchUp = '现在补做：';
  static const String actionKindling = '现在开一次十五分钟';
  static const String actionWriteCommitment = '写下一条今晚前要做完的承诺';

  static String acknowledgement(String text, int doneStreak) {
    final String head = '认账。「$text」完成了。';
    if (doneStreak >= 3) {
      return '$head连续 $doneStreak 次兑现。门槛抬高一点，下次别只做最小的。';
    }
    return '$head不夸你，下一件事等着。';
  }

  static String lessonText(String category, String reason) =>
      '因「$category」失败：$reason';
}
