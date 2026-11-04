import '../prp_host.dart';
import 'models.dart';

class PrpLessonValidation {
  const PrpLessonValidation(this.problems, this.quality);
  final List<String> problems;
  final int quality;
  bool get valid => problems.isEmpty;
}

class LessonValidator {
  const LessonValidator(this.host);
  final PrpHost host;
  static const categories = ['拖延', '回避', '目标太大', '被打断', '精力不足', '其他'];
  static const vague = [
    '忙',
    '没时间',
    '太忙',
    '努力',
    '加油',
    '下次努力',
    '坚持',
    '认真',
    '做好',
    '不知道'
  ];
  static final identity =
      RegExp(r'(我|你)(就|本来|天生|根本)?是.{0,10}(的人|失败者|懒人|没用|废|垃圾)|一无是处|我没有价值');
  static final measurable =
      RegExp(r'[0-9０-９]|[一二两三四五六七八九十]+(次|条|页|天|个|分钟|小时|张|回|遍)');
  static final actionVerb =
      RegExp(r'写|读|打开|关|放|走|喝|做|发|记|练|看|收|坐|起|拿|呼吸|开始|联系|休息|停');

  bool concrete(String text) =>
      text.trim().length >= 4 && !vague.contains(text.trim());
  bool testable(String text) =>
      concrete(text) && measurable.hasMatch(text) && actionVerb.hasMatch(text);
  bool identityJudgment(String text) => identity.hasMatch(text);

  PrpLessonValidation validate(PrpLesson lesson) {
    final problems = <String>[];
    if (!concrete(lesson.triggerText)) problems.add('写清原本希望做到的具体事情。');
    final texts = [
      lesson.triggerText,
      ...lesson.worked,
      ...lesson.failed,
      lesson.earlySignal,
      lesson.ifCue,
      lesson.thenAction,
      ...lesson.sentences
          .where((s) => s.kind != PrpSentenceKind.selfBlame)
          .map((s) => s.revision.isEmpty ? s.text : s.revision)
    ];
    if (texts.any((t) => !host.guardText(t).allowed || identityJudgment(t)))
      problems.add('只写具体行为，不把对自己的评价记为教训。');
    if (lesson.worked.isEmpty || lesson.worked.any((t) => !concrete(t)))
      problems.add('先写至少一件有效的具体做法。');
    if (lesson.failed.isEmpty || lesson.failed.any((t) => !concrete(t)))
      problems.add('没起作用的做法请写具体场景，不能只写“忙”。');
    if (!concrete(lesson.earlySignal)) problems.add('补上最早出现的预警信号。');
    if (!concrete(lesson.ifCue)) problems.add('补上“如果”里的具体线索。');
    if (lesson.thenAction.runes.length > 40 || !testable(lesson.thenAction))
      problems.add('动作不超过 40 字，写清动作和数量，例如“打开书读 1 页”。');
    if (texts.any((t) => t.runes.length > 1000))
      problems.add('单项请控制在 1000 字以内。');
    final quality = [
      lesson.evidence.isNotEmpty,
      lesson.worked.isNotEmpty && lesson.worked.every(concrete),
      !texts.any((t) => identityJudgment(t) || !host.guardText(t).allowed),
      concrete(lesson.earlySignal),
      concrete(lesson.ifCue) &&
          lesson.thenAction.runes.length <= 40 &&
          testable(lesson.thenAction),
    ].where((v) => v).length;
    return PrpLessonValidation(problems, quality);
  }

  List<PrpSentence> classify(String text) => text
      .split(RegExp(r'[。！？\n]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .map((s) => PrpSentence(
            s,
            identityJudgment(s) || !host.guardText(s).allowed
                ? PrpSentenceKind.selfBlame
                : RegExp(r'觉得|可能|因为|总是|一定|应该|似乎').hasMatch(s)
                    ? PrpSentenceKind.interpretation
                    : PrpSentenceKind.fact,
          ))
      .toList();

  static const earlyExamples = <String, List<String>>{
    '拖延': ['打开了别的 App', '反复整理桌面，没有开始'],
    '回避': ['看见消息后把手机扣下', '想到这件事就切换页面'],
    '目标太大': ['开始前列了太多步骤', '发现第一步超过了可用时间'],
    '被打断': ['收到一条新通知', '有人临时来找我'],
    '精力不足': ['连续打了几个哈欠', '注意力开始反复飘走'],
    '其他': ['准备开始时切换了任务', '没有预留开始的时间'],
  };
}
