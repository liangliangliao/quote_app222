import 'zhixing_models.dart';

/// Product-facing guide for turning the reviewed knowledge package into a
/// complete, user-readable decision catalog.
///
/// The knowledge manifest remains the evidence source. These guides make the
/// value system, distinctive focus and cross-lens relationships explicit so
/// users can choose an action philosophy without completing a questionnaire.
class ZxThinkerGuide {
  final int sequence;
  final String lensId;
  final String category;
  final List<String> coreValues;
  final List<String> coreIdeas;
  final String distinctiveFocus;
  final String decisionCue;
  final List<String> relatedLensIds;

  const ZxThinkerGuide({
    required this.sequence,
    required this.lensId,
    required this.category,
    required this.coreValues,
    required this.coreIdeas,
    required this.distinctiveFocus,
    required this.decisionCue,
    required this.relatedLensIds,
  });
}

class ZxThinkerCatalog {
  const ZxThinkerCatalog._();

  static const List<String> commonGround = <String>[
    '理解必须进入具体情境和可观察行动，不能只停留在口号。',
    '行动要由用户自主认领，系统只能提供视角、方法和边界。',
    '从足够小、可停止、可求证的一步开始，再根据现实反馈调整。',
    '失败不是人格判决，而是用来修改思想、方法或行动难度的信息。',
    '身体容量、现实条件、他人权益和安全边界不能被“意志不足”掩盖。',
  ];

  static const Map<String, String> categoryGuidance = <String, String>{
    '方向与意义': '不知道为何行动、目标并非自己认领，或需要重建长期方向。',
    '认知与心理灵活': '被想法、绝对要求、情绪等待或体验回避卡住。',
    '启动与执行': '方向已清楚，但总是忘记、犹豫、拖延或缺少现场入口。',
    '学习与能力': '不会做、缺少示范、信心失真，或需要通过实验持续改进。',
    '容量与环境': '身体、睡眠、时间、工具、支持或环境摩擦正在限制行动。',
  };

  static const List<ZxThinkerGuide> guides = <ZxThinkerGuide>[
    ZxThinkerGuide(
      sequence: 1,
      lensId: 'WY_KNOW_ACT',
      category: '方向与意义',
      coreValues: <String>['良知', '知行一致', '责任', '现实求证'],
      coreIdeas: <String>[
        '真知本身包含好恶、意向与行动方向。',
        '在具体事情上“事上磨”，用行动成就并检验所知。',
      ],
      distinctiveFocus: '先问“我是否真的认领并实行所知”，强调道德方向与言行一致。',
      decisionCue: '你已经讲了很多道理，却仍没有在一件具体事情上做出来。',
      relatedLensIds: <String>[
        'DHT_REFLECTIVE_INQUIRY',
        'ACT_FLEXIBILITY',
        'BCW_COMB',
      ],
    ),
    ZxThinkerGuide(
      sequence: 2,
      lensId: 'LZ_REDUCE_FORCE',
      category: '容量与环境',
      coreValues: <String>['自然', '节制', '柔韧', '不妄为'],
      coreIdeas: <String>[
        '减少过度控制、无效步骤和不必要摩擦。',
        '在问题尚微时介入，以更小、更柔韧的行动保持方向。',
      ],
      distinctiveFocus: '不是加码意志，而是先做减法，让行动重新流动。',
      decisionCue: '你越逼自己越僵硬，计划越来越重，恢复也变成任务。',
      relatedLensIds: <String>[
        'MMP_CAPACITY',
        'DHC_HABIT_ENVIRONMENT',
        'BA_ACTIVATION',
      ],
    ),
    ZxThinkerGuide(
      sequence: 3,
      lensId: 'WJ_ATTENTION_HABIT',
      category: '启动与执行',
      coreValues: <String>['注意', '意志', '习惯', '实践'],
      coreIdeas: <String>[
        '让困难但重要的动作表象在关键时刻继续占据注意。',
        '重复具体行动，把费力选择沉淀为习惯并释放注意。',
      ],
      distinctiveFocus: '把意志落实为注意保持、动作入口和可重复习惯。',
      decisionCue: '你知道要做什么，却在临场分心、摇摆或忘记开始。',
      relatedLensIds: <String>[
        'II_CUE_ACTION',
        'DHC_HABIT_ENVIRONMENT',
        'SDT_INTERNALIZATION',
      ],
    ),
    ZxThinkerGuide(
      sequence: 4,
      lensId: 'NZ_SELF_OVERCOMING',
      category: '方向与意义',
      coreValues: <String>['自主', '创造', '生命肯定', '自我超越'],
      coreIdeas: <String>[
        '用骆驼—狮子—孩子区分承担、争取自主与积极创造。',
        '审查继承的“你应当”，让身体和生命经验参与价值创造。',
      ],
      distinctiveFocus: '不只完成既定目标，而是克服被动身份并创造可肯定的新方向。',
      decisionCue: '你正在挣脱外界规定，却还没有形成真正愿意创造的方向。',
      relatedLensIds: <String>[
        'NGS_STYLE',
        'NBG_WILL_COMPLEXITY',
        'NGM_GENEALOGY',
        'SDT_INTERNALIZATION',
      ],
    ),
    ZxThinkerGuide(
      sequence: 5,
      lensId: 'AB_COGNITIVE_TEST',
      category: '认知与心理灵活',
      coreValues: <String>['求真', '可检验', '可修正', '行动实验'],
      coreIdeas: <String>[
        '自动思维是待检验的假设，不是已经证明的事实。',
        '通过证据、反证、替代解释和分级行为实验更新判断。',
      ],
      distinctiveFocus: '直接检验阻断行动的预测是否符合事实。',
      decisionCue: '“一定失败、别人会否定我、一次失败说明我不行”等预测让你不敢行动。',
      relatedLensIds: <String>[
        'AE_PREFERENCE_TOLERANCE',
        'ACT_FLEXIBILITY',
        'DHT_REFLECTIVE_INQUIRY',
      ],
    ),
    ZxThinkerGuide(
      sequence: 6,
      lensId: 'AE_PREFERENCE_TOLERANCE',
      category: '认知与心理灵活',
      coreValues: <String>['理性弹性', '偏好', '挫折耐受', '无条件自我接纳'],
      coreIdeas: <String>[
        '把“必须、应该、受不了”退回为强烈但可调整的偏好。',
        '区分一次表现与整个人的价值，并在现实触发中练习耐受。',
      ],
      distinctiveFocus: '处理绝对化要求和把困难升级为灾难或人格否定的问题。',
      decisionCue: '你不是不想做，而是要求自己必须完美、不能失败或不能难受。',
      relatedLensIds: <String>[
        'AB_COGNITIVE_TEST',
        'ACT_FLEXIBILITY',
        'BA_ACTIVATION',
      ],
    ),
    ZxThinkerGuide(
      sequence: 7,
      lensId: 'ACT_FLEXIBILITY',
      category: '认知与心理灵活',
      coreValues: <String>['心理灵活性', '接纳', '当下', '价值行动'],
      coreIdeas: <String>[
        '不必先消除不适，先改变自己与念头、情绪的关系。',
        '带着允许存在的体验，朝自己认领的价值迈一小步。',
      ],
      distinctiveFocus: '不与内在体验纠缠，把“等状态好再做”改为“带着它也能做”。',
      decisionCue: '你总在等待焦虑、羞耻、厌烦或怀疑消失以后才开始。',
      relatedLensIds: <String>[
        'AB_COGNITIVE_TEST',
        'SDT_INTERNALIZATION',
        'BA_ACTIVATION',
        'WY_KNOW_ACT',
      ],
    ),
    ZxThinkerGuide(
      sequence: 8,
      lensId: 'SDT_INTERNALIZATION',
      category: '方向与意义',
      coreValues: <String>['自主', '胜任', '关系', '内化'],
      coreIdeas: <String>[
        '行动理由需要从外控、羞耻和奖励依赖走向认同与整合。',
        '自主选择、胜任支架和关系支持共同提高持续行动质量。',
      ],
      distinctiveFocus: '先确认目标是不是“我的”，再为能力和关系提供支持。',
      decisionCue: '你主要因为别人要求、害怕内疚或为了奖励而坚持，提醒一撤就停止。',
      relatedLensIds: <String>[
        'II_CUE_ACTION',
        'SEF_MASTERY',
        'FRK_MEANING',
        'NZ_SELF_OVERCOMING',
      ],
    ),
    ZxThinkerGuide(
      sequence: 9,
      lensId: 'HPL_TRANSFORMATION',
      category: '学习与能力',
      coreValues: <String>['转化', '日常练习', '允许为人', '恢复'],
      coreIdeas: <String>[
        '信息要通过情感、行为或认知通道进入今天，才可能成为转化。',
        '过程想象、仪式、短练习、恢复与反馈把知识变成生活。',
      ],
      distinctiveFocus: '把听懂的知识变成每天可重复、对人性友好的练习。',
      decisionCue: '你阅读和理解了很多，但这些信息还没有改变日常行为。',
      relatedLensIds: <String>[
        'DHT_REFLECTIVE_INQUIRY',
        'BA_ACTIVATION',
        'MMP_CAPACITY',
      ],
    ),
    ZxThinkerGuide(
      sequence: 10,
      lensId: 'DHT_REFLECTIVE_INQUIRY',
      category: '学习与能力',
      coreValues: <String>['经验', '探究', '可修正', '成长'],
      coreIdeas: <String>[
        '把受阻转成问题、竞争假设、推理、行动检验和下一轮修正。',
        '错误提供观察材料，不是对人格的判决。',
      ],
      distinctiveFocus: '以完整探究循环处理“为什么没做成”，避免过早认定单一原因。',
      decisionCue: '你反复失败，却仍不清楚真正卡点，多个解释彼此竞争。',
      relatedLensIds: <String>[
        'WY_KNOW_ACT',
        'AB_COGNITIVE_TEST',
        'DHC_HABIT_ENVIRONMENT',
      ],
    ),
    ZxThinkerGuide(
      sequence: 11,
      lensId: 'DHC_HABIT_ENVIRONMENT',
      category: '容量与环境',
      coreValues: <String>['人境互动', '习惯重构', '审议', '能动性'],
      coreIdeas: <String>[
        '习惯是主体与环境持续互动形成的倾向。',
        '改变既要审议自己的下一行动，也要重构维持旧行为的条件。',
      ],
      distinctiveFocus: '既不只怪意志，也不把人说成环境的被动产物。',
      decisionCue: '同一个环境总是自动触发旧习惯，目标与现实入口距离太远。',
      relatedLensIds: <String>[
        'BCW_COMB',
        'WJ_ATTENTION_HABIT',
        'DHT_REFLECTIVE_INQUIRY',
      ],
    ),
    ZxThinkerGuide(
      sequence: 12,
      lensId: 'II_CUE_ACTION',
      category: '启动与执行',
      coreValues: <String>['具体', '预承诺', '情境启动', '减少决策负担'],
      coreIdeas: <String>[
        '预先把一个清楚线索X与一个具体反应Y绑定。',
        '关键情境出现时直接启动，减少现场重新决定和犹豫。',
      ],
      distinctiveFocus: '目标已经确定后，把意图“编译”为如果—那么行动入口。',
      decisionCue: '你认同目标也会做，但总在关键时刻忘记、拖延或被干扰。',
      relatedLensIds: <String>[
        'OET_WOOP',
        'WJ_ATTENTION_HABIT',
        'SDT_INTERNALIZATION',
      ],
    ),
    ZxThinkerGuide(
      sequence: 13,
      lensId: 'SLT_MODELING',
      category: '学习与能力',
      coreValues: <String>['观察学习', '示范', '演练', '反馈'],
      coreIdeas: <String>[
        '通过相似榜样获得注意、保持、动作再现与实施动机。',
        '把复杂行动拆成子技能，先观察和演练，再用信息反馈精炼。',
      ],
      distinctiveFocus: '不会做时先找可模仿的过程，减少昂贵的盲目试错。',
      decisionCue: '你不是缺少意愿，而是不知道具体怎么做或缺少动作示范。',
      relatedLensIds: <String>[
        'SEF_MASTERY',
        'DHC_HABIT_ENVIRONMENT',
        'HPL_TRANSFORMATION',
      ],
    ),
    ZxThinkerGuide(
      sequence: 14,
      lensId: 'BA_ACTIVATION',
      category: '启动与执行',
      coreValues: <String>['行动优先', '反回避', '分级', '自然强化'],
      coreIdeas: <String>[
        '识别行为短期避开什么、长期又维持了什么。',
        '用分级活动和替代应对打破情绪等待与回避循环。',
      ],
      distinctiveFocus: '先用小行动接触现实强化，不把情绪好转当作行动许可证。',
      decisionCue: '刷手机、躺着或逃开带来短期轻松，却让长期行动越来越少。',
      relatedLensIds: <String>[
        'ACT_FLEXIBILITY',
        'HPL_TRANSFORMATION',
        'MMP_CAPACITY',
      ],
    ),
    ZxThinkerGuide(
      sequence: 15,
      lensId: 'MMP_CAPACITY',
      category: '容量与环境',
      coreValues: <String>['安全', '基本需要', '恢复', '成长容量'],
      coreIdeas: <String>[
        '安全、睡眠、身体、归属和负荷会动态争夺行动优先级。',
        '容量不足时先恢复、减负或获得支持，再谈更高挑战。',
      ],
      distinctiveFocus: '防止把真实过载和基本需要缺口误判为懒惰或意志薄弱。',
      decisionCue: '你睡眠不足、身体不适、过载或缺少支持，硬逼只会继续透支。',
      relatedLensIds: <String>[
        'LZ_REDUCE_FORCE',
        'BA_ACTIVATION',
        'FRK_MEANING',
      ],
    ),
    ZxThinkerGuide(
      sequence: 16,
      lensId: 'NGS_STYLE',
      category: '方向与意义',
      coreValues: <String>['生命肯定', '身体智慧', '长期风格', '创造'],
      coreIdeas: <String>[
        '从身体、健康和动机来源审查一个选择来自充盈还是匮乏。',
        '以长期工作赋予性格风格，并检验是否愿意重复这种选择。',
      ],
      distinctiveFocus: '把单次行动放到“我愿成为怎样的人和长期怎样生活”中审查。',
      decisionCue: '你面对的是长期身份和生活风格选择，而不只是一次启动。',
      relatedLensIds: <String>[
        'NZ_SELF_OVERCOMING',
        'NBG_WILL_COMPLEXITY',
        'FRK_MEANING',
      ],
    ),
    ZxThinkerGuide(
      sequence: 17,
      lensId: 'NBG_WILL_COMPLEXITY',
      category: '方向与意义',
      coreValues: <String>['意志复杂性', '自主纪律', '力量整合', '代价诚实'],
      coreIdeas: <String>[
        '“我想要”由感受、命令、服从、条件和行动能力共同构成。',
        '自选约束能够塑造形式，也可能压抑力量，必须审查长期代价。',
      ],
      distinctiveFocus: '拒绝把意志当成一个按钮，拆开愿望、命令、能力和纪律。',
      decisionCue: '你把“很想要”误当成“已经能执行”，或长期纪律正在反噬自己。',
      relatedLensIds: <String>[
        'NZ_SELF_OVERCOMING',
        'BCW_COMB',
        'SDT_INTERNALIZATION',
      ],
    ),
    ZxThinkerGuide(
      sequence: 18,
      lensId: 'NGM_GENEALOGY',
      category: '方向与意义',
      coreValues: <String>['价值谱系', '承诺', '责任', '去罪责化'],
      coreIdeas: <String>[
        '追踪目标和价值如何形成、服务什么功能。',
        '区分可依赖的长期承诺与怨恨、坏良心、羞耻驱动的自责。',
      ],
      distinctiveFocus: '不是立刻执行目标，而是先识别它来自创造还是反应与罪责。',
      decisionCue: '你被羞耻、怨恨、亏欠感或“必须证明自己”驱动着行动。',
      relatedLensIds: <String>[
        'NZ_SELF_OVERCOMING',
        'WY_KNOW_ACT',
        'AB_COGNITIVE_TEST',
      ],
    ),
    ZxThinkerGuide(
      sequence: 19,
      lensId: 'OET_WOOP',
      category: '启动与执行',
      coreValues: <String>['现实主义', '愿望', '障碍', '计划'],
      coreIdeas: <String>[
        '把最佳未来与当前最关键的现实障碍同时放在眼前。',
        '先判断可行性，再为障碍编写如果—那么工具行为。',
      ],
      distinctiveFocus: '限制单纯积极幻想，把愿景直接连接到障碍和现场计划。',
      decisionCue: '你愿景很强、想象很多，却没有正视真正障碍或决定是否投入。',
      relatedLensIds: <String>[
        'II_CUE_ACTION',
        'BCW_COMB',
        'HPL_TRANSFORMATION',
      ],
    ),
    ZxThinkerGuide(
      sequence: 20,
      lensId: 'SEF_MASTERY',
      category: '学习与能力',
      coreValues: <String>['掌握', '现实信心', '校准', '有限迁移'],
      coreIdeas: <String>[
        '任务特定效能来自掌握、替代、劝导和身心状态信息。',
        '以亲历掌握为主要证据，只在相似任务和情境中更新信心。',
      ],
      distinctiveFocus: '用真实掌握阶梯校准“我能不能”，既反对低估也反对空泛自信。',
      decisionCue: '“我做不到”阻止了尝试，或你的信心与实际能力明显不一致。',
      relatedLensIds: <String>[
        'SLT_MODELING',
        'SDT_INTERNALIZATION',
        'BCW_COMB',
      ],
    ),
    ZxThinkerGuide(
      sequence: 21,
      lensId: 'FRK_MEANING',
      category: '方向与意义',
      coreValues: <String>['具体意义', '责任', '受限自由', '自我超越'],
      coreIdeas: <String>[
        '意义随人和时刻变化，要回答此时生活提出的具体问题。',
        '通过创造、体验/相遇，或对不可避免痛苦采取立场而行动。',
      ],
      distinctiveFocus: '在不能完全控制处境时，寻找仍可认领的责任和自由。',
      decisionCue: '你感到无意义、受限或失去方向，需要知道自己愿对谁或何事负责。',
      relatedLensIds: <String>[
        'SDT_INTERNALIZATION',
        'WY_KNOW_ACT',
        'NGS_STYLE',
        'MMP_CAPACITY',
      ],
    ),
    ZxThinkerGuide(
      sequence: 22,
      lensId: 'BCW_COMB',
      category: '容量与环境',
      coreValues: <String>['情境', '系统性', '可行性', '行为工程'],
      coreIdeas: <String>[
        '把具体行为拆成身体/心理能力、物理/社会机会、反思/自动动机。',
        '形成竞争假设，再用可接受性、可行性和副作用等标准选择干预。',
      ],
      distinctiveFocus: '系统检查“能不能、有无条件、想不想”，纠正把问题全归于内心。',
      decisionCue: '建议反复错配，真正障碍可能来自技能、环境、支持或多种因素。',
      relatedLensIds: <String>[
        'DHC_HABIT_ENVIRONMENT',
        'SDT_INTERNALIZATION',
        'WY_KNOW_ACT',
        'OET_WOOP',
      ],
    ),
  ];

  static ZxThinkerGuide? guideFor(String lensId) {
    for (final guide in guides) {
      if (guide.lensId == lensId) return guide;
    }
    return null;
  }

  static List<ZxThinkerGuide> relatedTo(ZxThinkerGuide guide) => guide
      .relatedLensIds
      .map(guideFor)
      .whereType<ZxThinkerGuide>()
      .toList(growable: false);

  static List<String> validateAgainst(List<ZxThinkerLens> lenses) {
    final issues = <String>[];
    final lensIds = lenses.map((item) => item.id).toSet();
    final guideIds = <String>{};
    for (final guide in guides) {
      if (!guideIds.add(guide.lensId)) {
        issues.add('重复思想指南：${guide.lensId}');
      }
      if (!lensIds.contains(guide.lensId)) {
        issues.add('思想指南缺少知识镜头：${guide.lensId}');
      }
      for (final related in guide.relatedLensIds) {
        if (!lensIds.contains(related)) {
          issues.add('${guide.lensId}关联了不存在的思想镜头：$related');
        }
      }
      if (guide.coreValues.isEmpty ||
          guide.coreIdeas.isEmpty ||
          guide.distinctiveFocus.trim().isEmpty ||
          guide.decisionCue.trim().isEmpty) {
        issues.add('${guide.lensId}的产品化思想说明不完整');
      }
    }
    for (final lensId in lensIds) {
      if (!guideIds.contains(lensId)) {
        issues.add('知识镜头尚未依次展示：$lensId');
      }
    }
    if (guides.length != lenses.length) {
      issues.add('思想指南数量与知识镜头数量不一致：${guides.length}/${lenses.length}');
    }
    return issues;
  }
}
