import '../data/models.dart';

/// 动议计划：一项带截止时间的具体安排，由用户接受或驳回。
class MotionPlan {
  const MotionPlan({
    required this.kind,
    required this.text,
    required this.dueMs,
    this.needsText = false,
    this.verify = '',
  });

  final String kind;
  final String text;
  final int dueMs;

  /// 接受时要用户亲手写下具体做什么。
  final bool needsText;
  final String verify;
}

/// 一次主动质询的计划。
class ProbePlan {
  const ProbePlan({
    required this.type,
    required this.situation,
    this.n = 0,
    this.m = 0,
    this.hours = 0,
    this.days = 0,
    this.label = '',
    this.text = '',
    this.category = '',
    this.motion,
    this.followUpOf,
  });

  final String type;

  /// 发给模型的情境：事实 + 角色要求。
  final String situation;
  final int n;
  final int m;
  final int hours;
  final int days;
  final String label;
  final String text;
  final String category;
  final MotionPlan? motion;

  /// 这是对哪条质询消息的追问。
  final int? followUpOf;
}

/// 一个沉寂的模块：曾经常有记录，最近一直没有。
class DormantModule {
  const DormantModule(this.label, this.days);

  final String label;
  final int days;
}

/// 选质询所需的全部事实。由 [EnemyPresence] 从案卷里算出来，这里只做决定，
/// 所以可以脱离数据库单独测试。
class ProbeFacts {
  const ProbeFacts({
    required this.nowMs,
    this.consentKindling = false,
    this.consentHabit = false,
    this.consentKnowledge = false,
    this.openCommitments = 0,
    this.createdLast24h = 0,
    this.lastKindlingCompletedMs = 0,
    this.knowledge24h = 0,
    this.actions24h = 0,
    this.habitEvents7d = 0,
    this.dormant = const <DormantModule>[],
    this.repeatedLesson,
    this.ignoredVerdict,
    this.rejected7d = 0,
    this.accepted7d = 0,
    this.done7d = 0,
    this.unanswered,
    this.unansweredFollowUps = 0,
    this.silentHours = 0,
    this.motionDueMs = 0,
    this.motionAllowed = true,
    this.lastProbeMs = const <String, int>{},
  });

  final int nowMs;
  final bool consentKindling;
  final bool consentHabit;
  final bool consentKnowledge;
  final int openCommitments;
  final int createdLast24h;

  /// 最近一次完整的十五分钟火种；从没有为 0。
  final int lastKindlingCompletedMs;
  final int knowledge24h;

  /// 24 小时内真正的行动：习惯完成、火种完成、字据兑现。
  final int actions24h;
  final int habitEvents7d;
  final List<DormantModule> dormant;
  final EnemyLesson? repeatedLesson;
  final EnemyVerdict? ignoredVerdict;
  final int rejected7d;
  final int accepted7d;
  final int done7d;

  /// 敌人最近一条没被回应的质询或动议。
  final EnemyMessage? unanswered;
  final int unansweredFollowUps;

  /// 案卷已经多少小时没有新记录。
  final int silentHours;

  /// 动议的截止时间；0 表示现在不适合提动议（太晚、或离静默时段太近）。
  final int motionDueMs;

  /// 今天还能不能再提动议（有没有未决的、有没有到上限）。
  final bool motionAllowed;

  /// 每一类质询上一次提出的时间。
  final Map<String, int> lastProbeMs;
}

/// 反对党：用户一声不响的时候，敌人不会跟着安静。
///
/// 沉默本身就是证据。这里从案卷里**已有的**和**缺失的**事实出发，挑出此刻最该质询的一件事。
/// 它可以把账上的缺口摆出来逼问，可以提动议要用户接受或驳回，但不会编造不存在的事实：
/// 账上没有的东西只说「账上没有」，不说「你没做」。
class Opposition {
  const Opposition._();

  /// 同一类质询的最短重复间隔（小时）。
  static const Map<String, int> cooldownHours = <String, int>{
    'unanswered_inquiry': 2,
    'ignored_verdict': 12,
    'lesson_repeat': 24,
    'no_commitments': 6,
    'knowledge_without_action': 6,
    'kindling_absent': 8,
    'reject_pattern': 24,
    'dormant_module': 12,
    'habit_empty': 24,
    'open_question': 3,
  };

  static const int maxFollowUps = 2;
  static const int unansweredAfterHours = 2;
  static const int ignoredVerdictAfterHours = 24;
  static const int dormantAfterDays = 3;
  static const int kindlingAbsentHours = 24;

  static const int _hour = 3600 * 1000;

  static bool _ready(ProbeFacts f, String type) {
    final int last = f.lastProbeMs[type] ?? 0;
    final int cool = (cooldownHours[type] ?? 3) * _hour;
    return last == 0 || f.nowMs - last >= cool;
  }

  static const String _style = '你是反对党席位上的议员：质询、反问、归谬，先摆账上的事实，再逼问。'
      '可以讽刺他的借口、回避和计划，不能攻击他这个人；不编造账上没有的事——账上没有的，只说「账上没有」。'
      '一到两句话。';

  /// 挑一件此刻最该质询的事。全都没到间隔时返回 null。
  static ProbePlan? choose(ProbeFacts f) {
    // 1) 他没回答的质询：追问，最多两次。
    final EnemyMessage? q = f.unanswered;
    if (q != null &&
        f.unansweredFollowUps < maxFollowUps &&
        f.nowMs - q.ts >= unansweredAfterHours * _hour &&
        _ready(f, 'unanswered_inquiry')) {
      final String quoted = q.text.length > 40 ? '${q.text.substring(0, 40)}…' : q.text;
      return ProbePlan(
        type: 'unanswered_inquiry',
        hours: ((f.nowMs - q.ts) / _hour).floor(),
        text: quoted,
        followUpOf: q.id,
        situation: '【追问】你 ${((f.nowMs - q.ts) / _hour).floor()} 小时前质询过他：「$quoted」，他一直没有回答。'
            '沉默也是一种答复，点破它，问他要不要这样记。$_style',
      );
    }

    // 2) 判词他从来不回应。
    final EnemyVerdict? v = f.ignoredVerdict;
    if (v != null && _ready(f, 'ignored_verdict')) {
      return ProbePlan(
        type: 'ignored_verdict',
        situation: '【质询】上一条判词（${v.charge}）他超过 $ignoredVerdictAfterHours 小时没有任何回应，'
            '既没接受也没申辩。沉默不是申辩，你把它记作默认。$_style',
      );
    }

    final bool noCommitments = f.openCommitments == 0 && f.createdLast24h == 0;
    final bool canMotion = f.motionAllowed && f.motionDueMs > 0;

    // 3) 手里一条字据都没有。
    if (noCommitments && _ready(f, 'no_commitments')) {
      return ProbePlan(
        type: 'no_commitments',
        situation: '【质询】他手里没有一条开着的字据，最近 24 小时也没立过。没有字据就没有账可算。'
            '问他这是自由还是回避。${canMotion ? '同时正式提一项动议：请他现在立一条今晚能做完的字据。' : ''}$_style',
        motion: canMotion
            ? MotionPlan(
                kind: 'no_commitments',
                text: '立一条字据：写清楚做什么、几点前',
                dueMs: f.motionDueMs,
                needsText: true,
              )
            : null,
      );
    }

    // 4) 反复踩同一个坑。
    final EnemyLesson? l = f.repeatedLesson;
    if (l != null && _ready(f, 'lesson_repeat')) {
      return ProbePlan(
        type: 'lesson_repeat',
        n: l.timesRepeated,
        category: l.category,
        text: l.lesson,
        situation: '【质询】「${l.category}」这个坑他已经踩了 ${l.timesRepeated} 次。'
            '他自己写下的教训是：「${l.lesson}」。问他读过没有、做了什么不同的事。$_style',
      );
    }

    // 5) 知识转化了，行动是零。
    if (f.consentKnowledge &&
        f.knowledge24h >= 1 &&
        f.actions24h == 0 &&
        _ready(f, 'knowledge_without_action')) {
      return ProbePlan(
        type: 'knowledge_without_action',
        n: f.knowledge24h,
        situation: '【质询】过去 24 小时他把 ${f.knowledge24h} 张知识卡转成了行动步骤，'
            '但账上没有任何一次行动（习惯完成、火种完成、字据兑现都是零）。纸上谈兵。'
            '${canMotion ? '同时正式提一项动议：请他把其中一个行动步骤立成字据。' : ''}$_style',
        motion: canMotion
            ? MotionPlan(
                kind: 'knowledge_without_action',
                text: '把一个行动步骤落地，立成字据',
                dueMs: f.motionDueMs,
                needsText: true,
              )
            : null,
      );
    }

    // 6) 火种：24 小时没有一次完整的十五分钟。
    final bool kindlingStale = f.lastKindlingCompletedMs == 0 ||
        f.nowMs - f.lastKindlingCompletedMs >= kindlingAbsentHours * _hour;
    if (f.consentKindling && kindlingStale && _ready(f, 'kindling_absent')) {
      final int hours = f.lastKindlingCompletedMs == 0
          ? 0
          : ((f.nowMs - f.lastKindlingCompletedMs) / _hour).floor();
      return ProbePlan(
        type: 'kindling_absent',
        hours: hours,
        situation: hours == 0
            ? '【质询】火种：账上没有任何一次完整的十五分钟。问他点过火没有。'
                '${canMotion ? '同时正式提一项动议：限期内完成一次完整的十五分钟火种。' : ''}$_style'
            : '【质询】火种：距离上一次完整的十五分钟已经 $hours 小时，账上这期间是零。'
                '${canMotion ? '同时正式提一项动议：限期内完成一次完整的十五分钟火种。' : ''}$_style',
        motion: canMotion
            ? MotionPlan(
                kind: 'kindling_absent',
                text: '完成一次完整的十五分钟火种',
                dueMs: f.motionDueMs,
                verify: 'kindling',
              )
            : null,
      );
    }

    // 7) 驳回成了习惯，兑现却很少。
    if (f.rejected7d >= 2 && _ready(f, 'reject_pattern')) {
      return ProbePlan(
        type: 'reject_pattern',
        n: f.rejected7d,
        m: f.done7d,
        situation: '【质询】本周他驳回了 ${f.rejected7d} 项动议，兑现了 ${f.done7d} 条字据。'
            '驳回是他的权利，但账上只认兑现。$_style',
      );
    }

    // 8) 沉寂的模块。
    if (f.dormant.isNotEmpty && _ready(f, 'dormant_module')) {
      final DormantModule d = f.dormant.first;
      return ProbePlan(
        type: 'dormant_module',
        label: d.label,
        days: d.days,
        situation: '【质询】「${d.label}」他以前常有记录，最近 ${d.days} 天一条新记录都没有。'
            '问他是它出了问题，还是他在躲。${canMotion ? '同时正式提一项动议：限期内在这个模块留下一条新记录。' : ''}$_style',
        motion: canMotion
            ? MotionPlan(
                kind: 'dormant_module',
                text: '在「${d.label}」留下一条新记录',
                dueMs: f.motionDueMs,
              )
            : null,
      );
    }

    // 9) 预设行为打卡：七天零条。
    if (f.consentHabit && f.habitEvents7d == 0 && _ready(f, 'habit_empty')) {
      return ProbePlan(
        type: 'habit_empty',
        situation: '【质询】预设行为打卡：过去七天案卷里是 0 条。问他习惯设了没有、打过卡没有。$_style',
      );
    }

    // 10) 兜底：什么都没抓到，也要问。沉默不是好结果。
    if (_ready(f, 'open_question')) {
      return ProbePlan(
        type: 'open_question',
        hours: f.silentHours,
        situation: '【质询】案卷已经 ${f.silentHours} 小时没有新记录，没有可以抓的具体事实。'
            '那就问他一个直接的问题：他此刻在回避什么、今天的账他敢让谁看。'
            '问一个问题，别替他回答。$_style',
      );
    }
    return null;
  }
}
