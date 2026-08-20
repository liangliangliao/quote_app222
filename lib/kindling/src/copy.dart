/// 全部面向用户的字符串。
///
/// 语气规范：陈述句，不用感叹号，不用「你可以做到」「加油」「太棒了」，
/// 不称呼用户为「你真棒」类主语。UI 文件里禁止写字面量文案。
class KCopy {
  const KCopy._();

  static const String title = '火种';
  static const String emptyList = '还没有火种。先做一次回溯。';
  static const String emptyDirect = '直接写一个';
  static const String recall = '回溯';
  static const String burn = '十五分钟';
  static const String released = '放掉的';

  static const String qLostTrack = '上一次做某件事忘了时间，是什么时候？';
  static const String qItch = '现在有什么事，是你不做会痒的？哪怕它毫无用处、上不了台面。';
  static const String qEnvy = '你最近对什么感到羡慕或不服？';
  static const String pickHint = '挑出你想留下的。留不留都行。';

  static const String verdictQ = '如果没人知道你做了这件事，你还做吗？';
  static const String verdictYes = '做';
  static const String verdictNo = '不做';
  static const String verdictIdk = '说不准';
  static const String verdictNoTip = '那这件事可能不是你的。先放到「放掉的」里，随时能拿回来。';

  static const String burnAsk = '还想接着做吗？';
  static const String burnYes = '想';
  static const String burnNo = '不想';

  static const String resistance1 = '不做它，你避免了什么？';
  static const String resistance2 = '如果做了，最坏会发生什么？';
  static const String resistance3 = '那件最坏的事，你在防的是谁？';
  static const String resistance4 = '那个人现在还在场吗？';
  static const String resistanceEnd = '就到这里。识别出来就够了，不用现在解决它。';

  static const String releasedTip = '放掉不是失败。这里的每一条都省下了一份力气。';

  /// 发现之旅入口卡片的无障碍标签。
  static const String discoverSemantics = '火种，回溯、判别式、十五分钟与放掉的';

  // —— 长按菜单 ——
  static const String menuRename = '换个说法';
  static const String menuVerdict = '问一句';
  static const String menuResistance = '卡住了';
  static const String menuRelease = '放掉';

  // —— 其余必要的界面字 ——
  static const String next = '下一步';
  static const String done = '完成';
  static const String skip = '跳过';
  static const String cancel = '取消';
  static const String save = '保存';
  static const String start = '开始';
  static const String restore = '拿回来';
  static const String pickBurnItem = '选一个';
  static const String emptyReleased = '这里还没有东西。';
  static const String emptyCandidates = '这次没有可留下的。';
  static const String writeHint = '写在这里';
  static const String titleHint = '一句话就够';

  // —— 放掉的原因 ——
  static const String releaseReasonVerdict = '判别式：不做';
  static const String releaseReasonManual = '手动放掉';

  static String releasedWithCount(int count) => '$released ($count)';

  /// 回溯三问的固定顺序与文案。
  static const List<String> recallQuestions = <String>[
    qLostTrack,
    qItch,
    qEnvy,
  ];

  /// 阻抗追问的本地问题梯。
  static const List<String> resistanceLadder = <String>[
    resistance1,
    resistance2,
    resistance3,
    resistance4,
  ];
}
