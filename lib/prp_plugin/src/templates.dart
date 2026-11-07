import 'models.dart';

/// 失败类别（与美丽的敌人的类别一致，插件自己保存一份，避免反向依赖）。
const List<String> kPrpCategories = <String>[
  '拖延',
  '回避',
  '目标太大',
  '被打断',
  '精力不足',
  '其他',
];

/// 每个类别下“最早的预警信号”示例，离线引导用。
const Map<String, List<String>> kEarlySignalExamples = <String, List<String>>{
  '拖延': <String>['打开了别的 App', '反复整理环境', '先去做了更容易的事'],
  '回避': <String>['改了开始时间', '一想到就换话题', '把它排到“明天”'],
  '目标太大': <String>['不知道从哪一步开始', '一想到全部就累', '拆不出第一步'],
  '被打断': <String>['手机提示一响就去看', '有人来找就停了', '没有关通知'],
  '精力不足': <String>['已经很久没休息', '吃完饭就犯困', '前一晚睡得很晚'],
  '其他': <String>['说不清，但开始前有点抗拒', '开始前先找了个理由'],
};

/// “缓一缓”里可以点选的允许句。
const List<String> kAllowPhrases = <String>[
  '我允许自己难受一会儿。',
  '这件事没做好，不等于我没有价值。',
  '我可以先停一下，再想办法。',
];

/// 会话文案。敌人口吻温暖而坚定；中性口吻平和。都不审讯、不评价人格。
class PrpCopy {
  const PrpCopy(this.voice);

  final PrpVoice voice;

  bool get _enemy => voice == PrpVoice.enemy;

  String get sessionTitle => '缓一缓 · 对账 · 盖印';

  // —— P：缓一缓 ——
  String get pauseTitle => '这次没做到。先不分析。';
  String pauseBody(int sec) =>
      _enemy ? '缓一缓，$sec 秒，我在这儿。' : '先停一下，$sec 秒，什么都不用做。';
  String get pauseHint => '可以只是坐着，也可以写一句话。写下来的不会被评判。';
  String get emotionBeforeLabel => '现在的难受程度（0–10）';
  String get pauseReady => '我好了';
  String pauseWait(int left) => '再等 $left 秒';
  String get pauseSkip => '这次先不做了';

  // —— R1：对账 ——
  String get ledgerTitle => '先把事实摆出来';
  String get ledgerExpected => '预期';
  String get ledgerActual => '记录里是';
  String get ledgerYourWords => '你怎么说';
  String get ledgerHint =>
      _enemy ? '说一件具体发生的事。我只看事实和做法，不看你这个人。' : '说一件具体发生的事。这里只看事实和做法，不评价人。';
  String get ledgerSplit => '拆开看';
  String get ledgerNotAccounted => '这句是对你的评价，不是证据，不入账。';
  String get kindFact => '事实';
  String get kindInterpretation => '解释';
  String get kindSelfBlame => '自责';
  String get ledgerTapToChange => '点一下可以改类别';

  // —— R2：双栏 ——
  String get columnsTitle => '先说有效的';
  String get columnsWorkedHint => '这次有哪一件事是对的？哪怕只是开始了、记下了。';
  String get columnsFailedTitle => '再说没起作用的';
  String get columnsFailedHint => '当时你在做什么？说具体场景，不要只写“忙”。';
  String get categoryLabel => '更接近哪一类';
  String get addItem => '加入';

  // —— R3/R4：预警 + 如果—那么 ——
  String get signalTitle => '最早出现的信号是什么？';
  String get signalHint => '比如：打开了别的 App、改了开始时间……';
  String get ifThenTitle => '如果……，我就……';
  String get ifHint => '如果［线索］';
  String get thenHint => '我就［动作］（40 字以内）';

  // —— R5：盖印 ——
  String get sealTitle => '这条教训，你认可吗？';
  String get sealHint => '长按 3 秒盖印，之后它会在你需要的时候出现。';
  String get sealHold => '按住盖印';
  String get sealDone => '已盖印';
  String get sealLater => '先存为草稿';
  String qualityLine(int q) => '成色 $q/5';

  // —— P：拉远 ——
  String get zoomTitle => '拉远一点';
  String get zoomInsufficient => '数据还不够，先不下结论。';
  String zoomLine({
    required int total,
    required int done,
    required int missed,
  }) => '近 30 天你立了 $total 条字据：兑现 $done、失效 $missed。这是其中的一条。';
  String get emotionAfterLabel => '现在的难受程度（0–10）';
  String get finish => '完成';

  // —— 回访 ——
  String recallTitle(int nth) => '这是类似情况的第 $nth 次。';
  String get recallLast => '你上次盖印的是：';
  String get recallAsk => '这次要试一下吗？';
  String get recallRepeated => '这条教训没挡住这次。它可能写得不对，不是你不行。要改一版吗？';
  String get recallRewrite => '改一版';
  String get recallDismiss => '知道了';
  String get recallContinue => '继续记这次';

  String get crisisFallback => '如果你现在很难受，先别管这个练习。请联系身边信得过的人，或当地的心理援助热线，和他们说说。';
}
