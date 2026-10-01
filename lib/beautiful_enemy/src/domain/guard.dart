import '../enemy_oracle.dart';

/// 判词的本地校验。模型的输出必须过这一关才能展示——系统提示是第一道防线，
/// 这里是第二道，两者冲突以更严的为准。
class DraftValidator {
  const DraftValidator();

  static const int maxChargeChars = 160;
  static const int maxActionChars = 40;
  static const int maxActionHorizonDays = 7;

  /// 直接命中即判违规的词。人格、身份、威胁、孤立、控制。
  static const List<String> bannedPhrases = <String>[
    // 对人的评判 / 侮辱
    '废物', '垃圾', '蠢货', '白痴', '傻子', '贱', '窝囊', '没出息', '活该', '混蛋',
    '你这种人', '你这类人', '你永远', '你一辈子', '你这辈子',
    // 威胁恐吓
    '没人会要你', '没人会', '没有人会', '后悔一辈子', '完蛋了', '再这样就完了', '去死', '死了算了',
    // 孤立 / 制造依赖
    '只有我', '别人都不', '离了我', '没有我你',
    // 身份与处境攻击
    '学历', '出身', '长相', '外貌', '身材', '你的家人', '你父母', '你太穷', '你这么穷',
  ];

  /// 「你就是…的人」一类的身份判断句式。
  static final List<RegExp> bannedPatterns = <RegExp>[
    RegExp(r'你(就)?是(一)?个?[^，。！？\s]{0,8}(的人|的家伙|的东西|货色|废|垃圾)'),
    RegExp(r'你他妈的?是'),
    RegExp(r'你根本不是真的'),
  ];

  /// 粗口语气词：只有 3 档允许出现，且不能指向人（上面的句式已拦）。
  static const List<String> profanityMarkers = <String>[
    '他妈',
    '妈的',
    '狗屁',
    '放屁',
    '屁话',
  ];

  /// 「具体」= 有阿拉伯数字，或有「三次 / 两天」这样带单位的中文数字。
  /// 单独一个「一」（如「一定」「一直」）不算。
  static final RegExp _hasDigit = RegExp(
    r'[0-9０-９]|[零一二两三四五六七八九十百]+\s*(次|条|天|个|分钟|小时|张|回|遍|周)',
  );
  static final RegExp _hasQuote = RegExp('[「」“”"]');

  /// 返回问题代码列表；空表示通过。
  List<String> validate(
    EnemyDraft d, {
    required Set<int> allowedEvidence,
    required int maxTone,
    required int nowMs,
  }) {
    final List<String> problems = <String>[];

    if (d.evidenceIds.isEmpty) {
      problems.add('no_evidence');
    } else if (!d.evidenceIds.every(allowedEvidence.contains)) {
      problems.add('unknown_evidence');
    }

    final String charge = d.charge.trim();
    if (charge.isEmpty) problems.add('empty_charge');
    if (charge.length > maxChargeChars) problems.add('charge_too_long');
    if (!d.factOnly && !_hasDigit.hasMatch(charge) && !_hasQuote.hasMatch(charge)) {
      problems.add('charge_not_concrete');
    }

    final String action = d.action.trim();
    if (action.isEmpty) problems.add('no_action');
    if (action.length > maxActionChars) problems.add('action_too_long');

    if (d.actionDueMs <= nowMs) {
      problems.add('due_in_past');
    } else if (d.actionDueMs - nowMs >
        const Duration(days: maxActionHorizonDays).inMilliseconds) {
      problems.add('due_too_far');
    }

    if (d.toneLevel < 0 || d.toneLevel > maxTone) problems.add('tone_above_limit');

    final String all = '${d.charge}\n${d.action}\n${d.lessonHint}\n${d.appealPrompt}';
    if (containsBanned(all)) problems.add('banned_content');
    if (d.toneLevel < 3 && profanityMarkers.any(all.contains)) {
      problems.add('profanity_below_tier3');
    }
    return problems;
  }

  static const int maxLineChars = 200;

  /// 校验一句对话（对话回复、插话）。返回问题代码；空表示通过。
  /// 对话没有证据 id、动作、截止时间，所以只查：长度、禁区、粗口档位。
  List<String> validateLine(String line, {required int maxTone}) {
    final String t = line.trim();
    final List<String> problems = <String>[];
    if (t.isEmpty) problems.add('empty');
    if (t.length > maxLineChars) problems.add('too_long');
    if (containsBanned(t)) problems.add('banned_content');
    if (maxTone < 3 && profanityMarkers.any(t.contains)) {
      problems.add('profanity_below_tier3');
    }
    return problems;
  }

  static bool containsBanned(String text) {
    if (bannedPhrases.any(text.contains)) return true;
    return bannedPatterns.any((RegExp p) => p.hasMatch(text));
  }
}

/// 安全阀：用户自己写下的文字里出现自伤、自杀、绝望表达，或明确说「停战」时，
/// 敌人立刻收起来。
class SafetyValve {
  const SafetyValve._();

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
    '撑不住了',
    '撑不下去',
    '了结自己',
    '割腕',
    '跳楼',
  ];

  static bool isCrisis(String text) {
    final String t = text.replaceAll(RegExp(r'\s'), '');
    return crisisMarkers.any(t.contains);
  }

  static bool isTruce(String text) => text.contains('停战');

  /// 用户写的任何文字都应先过这里：crisis 或 truce 都要静音。
  static bool shouldMute(String text) => isCrisis(text) || isTruce(text);
}

/// 强度治理：实际档位永远不高于用户设定，只降不自动升。
class IntensityGovernor {
  const IntensityGovernor._();

  /// 返回 0..3。0 表示纯事实播报（休战日）。
  static int effective({
    required int base,
    required bool truceDay,
    required int unansweredStreak,
    required bool tooMuchRecently,
  }) {
    if (truceDay) return 0;
    int level = base.clamp(1, 3);
    if (unansweredStreak >= 3) level -= 1;
    if (tooMuchRecently) level -= 1;
    return level < 1 ? 1 : level;
  }
}

/// 赌注守卫：赌注只能是一个行动，不能伤害自己、羞辱自己，也不能涉及钱。
class StakeGuard {
  const StakeGuard._();

  static const int maxChars = 40;

  static const List<String> harmfulMarkers = <String>[
    '不吃', '绝食', '饿', '打自己', '掐自己', '扇自己', '伤害', '自残', '冷水',
    '不睡', '熬夜', '罚站', '罚跪', '羞辱', '发朋友圈', '公开道歉', '罚款', '转账', '红包', '赔钱',
  ];

  static bool isAcceptable(String stake) {
    final String s = stake.trim();
    if (s.isEmpty) return true;
    if (s.length > maxChars) return false;
    if (harmfulMarkers.any(s.contains)) return false;
    return !DraftValidator.containsBanned(s);
  }
}
