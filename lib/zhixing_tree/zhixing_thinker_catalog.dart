import 'zhixing_models.dart';

/// A product-facing, author-level thought system.
///
/// Twenty-two reviewed works remain independent evidence sources and
/// mechanism lenses. The product navigation groups them into seventeen
/// coherent author/theory systems so a multi-book author is not fragmented
/// into several apparently unrelated philosophies.
class ZxThinkerGuide {
  final int sequence;
  final String systemId;
  final String displayName;
  final String thinker;
  final String category;
  final String evolutionStage;
  final String primaryLensId;
  final List<String> lensIds;
  final List<String> coreValues;
  final List<String> coreIdeas;
  final String knowledgeView;
  final String actionView;
  final String splitDiagnosis;
  final String transformationPath;
  final String actionFeedback;
  final String yangmingConnection;
  final String inheritedLimit;
  final String qualitativeLeap;
  final String synthesisOutcome;
  final String workSynthesis;
  final List<String> sevenLoopRoles;
  final String distinctiveFocus;
  final String decisionCue;
  final List<String> buildsOnSystemIds;
  final List<String> relatedSystemIds;
  final List<String> tensions;

  const ZxThinkerGuide({
    required this.sequence,
    required this.systemId,
    required this.displayName,
    required this.thinker,
    required this.category,
    required this.evolutionStage,
    required this.primaryLensId,
    required this.lensIds,
    required this.coreValues,
    required this.coreIdeas,
    required this.knowledgeView,
    required this.actionView,
    required this.splitDiagnosis,
    required this.transformationPath,
    required this.actionFeedback,
    required this.yangmingConnection,
    required this.inheritedLimit,
    required this.qualitativeLeap,
    required this.synthesisOutcome,
    required this.workSynthesis,
    required this.sevenLoopRoles,
    required this.distinctiveFocus,
    required this.decisionCue,
    required this.buildsOnSystemIds,
    required this.relatedSystemIds,
    required this.tensions,
  });

  /// Backwards-compatible representative lens used as the persisted selection
  /// token. Matching still receives every lens in [lensIds].
  String get lensId => primaryLensId;
}

class ZxThinkerCatalog {
  const ZxThinkerCatalog._();

  static const String yangmingSystemId = 'yangming';

  static const List<String> commonGround = <String>[
    '知不能只按“说得正确”判断，还要进入具体情境、动作与后果。',
    '行动不是知识的附属品；它会检验预测、暴露条件并生成新的认识。',
    '知行分裂不等于意志薄弱，可能来自价值、认知、情绪、能力、机会、习惯或容量。',
    '稳定行动依靠自主认领、具体技能、环境支持、反馈和恢复，不能长期依靠羞耻。',
    '高水平知行合一包括选择、开始、坚持、修正、退出、恢复、协作并承担后果。',
  ];

  static const Map<String, String> evolutionStageGuidance =
      <String, String>{
    '第一层 · 立根：王阳明知行合一主线':
        '确立总纲：真知包含行动方向，行动成就并检验所知。',
    '第二层 · 心理落地：观念、认知与非强迫行动':
        '解释“道理怎样进入动作”，并清除错误预测、绝对要求和过度用力。',
    '第三层 · 主体升华：接纳、自主、价值与意义':
        '让行动从消除不适、外部服从和继承价值，升级为自主、创造和责任。',
    '第四层 · 行动实现：探究、启动、学习与反回避':
        '把已认领方向编译为可学习、可启动、可检验、可修正的现实行动。',
    '第五层 · 系统整合：容量、日常转化与行为工程':
        '保护人的有限容量，把练习沉淀为生活，并用统一工程框架选择干预。',
  };

  static const Map<String, String> decisionRoutes = <String, String>{
    '方向与正当性': '先判断什么值得做、是不是自己认领、会让谁承担代价。',
    '事实与解释': '区分事实、预测、自动思维、绝对要求和仍未知的条件。',
    '情绪与心理关系': '不等待不适消失，区分需要接纳的体验与需要改变的伤害。',
    '启动与现场入口': '把方向缩成下一小步、动作表象和如果—那么线索。',
    '学习与胜任': '通过榜样、子技能、掌握经验和反馈形成真实能力。',
    '容量与恢复': '先检查身体、睡眠、安全、时间、工具、关系和支持。',
    '求证与内化': '让结果回写原判断，逐步形成习惯、能力、身份与贡献。',
  };

  static const List<ZxThinkerGuide> guides = <ZxThinkerGuide>[
    ZxThinkerGuide(
      sequence: 1,
      systemId: yangmingSystemId,
      displayName: '王阳明 · 知行合一总纲',
      thinker: '王阳明',
      category: '方向、伦理与工夫',
      evolutionStage: '第一层 · 立根：王阳明知行合一主线',
      primaryLensId: 'WY_KNOW_ACT',
      lensIds: <String>['WY_KNOW_ACT'],
      coreValues: <String>['良知', '诚意', '责任', '知行一体', '事上磨'],
      coreIdeas: <String>[
        '知是行的主意，行是知的功夫；没有进入意向和行动的“知道”仍未完成。',
        '良知提供是非与责任方向，格物是在具体事情上纠正意念、对象和做法。',
        '立志使长期方向持续在场，省察克治处理意念发动处的遮蔽与自欺。',
        '事上磨让判断接受现实检验，行动结果再回到省察，使知不断加深。',
      ],
      knowledgeView:
          '知不是外置的信息库存，而是包含好恶、判断、责任和行动趋向的切身认识；真知会改变人怎样面对眼前之事。',
      actionView:
          '行是意念发动后的现实工夫，包括选择、实行、承担后果和继续省察，不等于无辨别的冲动。',
      splitDiagnosis:
          '把口头理解与真实意向分开，以借来的道理替代切身判断，或让私欲、自欺和情境压力遮蔽已经认领的方向。',
      transformationPath:
          '立志与伦理校准 → 检查意念发动 → 在一件具体事上格物 → 做出可承担的一步 → 事上磨与省察 → 更新下一步。',
      actionFeedback:
          '行动会显出所知是否真切、意图是否诚实、方法是否适当；结果不是简单奖惩，而是继续致知和修正工夫的材料。',
      yangmingConnection:
          '这是全产品的主干。其他思想不取代知行合一，而是分别补足心理机制、价值辨析、行动技术、环境条件和反馈工程。',
      inheritedLimit:
          '作为第一层没有前置理论缺口；它主动留下的问题是：具体心理机制、能力机会、经验检验和现代安全边界怎样被细化。',
      qualitativeLeap:
          '把“知”从正确陈述提升为必须在真实意向、现实行动和后果承担中成立的生命实践。',
      synthesisOutcome:
          '形成产品不可改变的总原则：先辨方向与责任，再让一个具体行动成就并检验所知。',
      workSynthesis:
          '以《传习录》中的心即理、良知、致良知、格物、立志、知行合一、事上磨和省察克治构成一条完整工夫链。',
      sevenLoopRoles: <String>['方向', '澄清', '求证', '内化'],
      distinctiveFocus:
          '最关心“你声称知道和重视的，是否已经成为真实意向并在一件事上表现出来”。',
      decisionCue:
          '你理解了很多，也真心说它重要，但现实中长期没有任何与之相称的具体行动。',
      buildsOnSystemIds: <String>[],
      relatedSystemIds: <String>[
        'william_james',
        'dewey',
        'act',
        'self_determination',
        'nietzsche',
        'frankl',
        'comb_bcw',
      ],
      tensions: <String>[
        '不得把知行合一简化成“想到就做”，否则会把冥行妄作误认为行动。',
        '若把所有失败解释为私欲或不诚，容易忽略身体容量、技能、机会、结构伤害和专业风险。',
      ],
    ),
    ZxThinkerGuide(
      sequence: 2,
      systemId: 'william_james',
      displayName: '威廉·詹姆斯 · 观念如何成为动作',
      thinker: 'William James',
      category: '注意、意志与习惯',
      evolutionStage: '第二层 · 心理落地：观念、认知与非强迫行动',
      primaryLensId: 'WJ_ATTENTION_HABIT',
      lensIds: <String>['WJ_ATTENTION_HABIT'],
      coreValues: <String>['注意', '实践', '意志努力', '习惯', '可塑性'],
      coreIdeas: <String>[
        '行动观念若在关键时刻清楚地占据注意，常会直接释放相应动作；犹豫来自竞争观念和抑制。',
        '意志努力的重要部分不是凭空制造力量，而是让困难但重要的动作表象继续留在注意中心。',
        '先完成第一次真实动作，再通过重复和稳定线索把费力选择沉淀为习惯。',
        '习惯保存行动成果并释放注意，但必须服务于经过审查的方向，而不是刚性连续或自我惩罚。',
      ],
      knowledgeView:
          '观念和动作表象是心理中的可能行动；它只有获得清晰度、注意优势并接通现实条件，才会成为有效的行动知识。',
      actionView:
          '行从第一个身体或操作动作开始，通过注意保持、动作反馈和重复逐步形成更自动的习惯倾向。',
      splitDiagnosis:
          '知道目标却没有清楚动作表象，关键时刻注意被竞争观念占据，入口不可见，或新选择尚未形成稳定习惯。',
      transformationPath:
          '把目标改写为可见动作 → 形成清楚动作表象 → 在关键时刻保持注意 → 立即完成首个微动作 → 用线索和重复形成习惯。',
      actionFeedback:
          '实际动作产生感觉、结果和熟练度信息，使原本抽象的观念获得现实内容，并告诉人下一次注意和动作应怎样调整。',
      yangmingConnection:
          '它把王阳明“意念发动”和“事上磨”补成可观察的心理—动作机制，但本身不提供良知和伦理方向。',
      inheritedLimit:
          '王阳明说明真知应当包含行，却没有细分关键时刻观念、注意、抑制、动作释放和习惯形成的心理过程。',
      qualitativeLeap:
          '从“真心知道就会做”推进到“必须让正确动作表象获得注意优势并进入身体行动”。',
      synthesisOutcome:
          '知行合一第一次获得微观启动机制：价值方向不再停在道理，而被编译成当下可见的动作入口。',
      workSynthesis:
          '综合《心理学原理》中注意、意志、观念运动、感觉—运动反馈与习惯章节；历史神经表述只作机制启发，不当作当代定论。',
      sevenLoopRoles: <String>['启动', '稳定', '内化'],
      distinctiveFocus:
          '最关心关键时刻究竟是哪一个动作表象占据注意，以及首个动作怎样被重复成习惯。',
      decisionCue:
          '你认可目标，也知道大致怎么做，却总在临场分心、摇摆、忘记开始或停在准备中。',
      buildsOnSystemIds: <String>['yangming'],
      relatedSystemIds: <String>[
        'yangming',
        'dewey',
        'gollwitzer',
        'bandura',
        'harvard_positive_psychology',
      ],
      tensions: <String>[
        '注意和习惯是方向中性的，高效习惯不等于正当行动。',
        '历史性刚性习惯建议必须由恢复、可塑性和中断后重启原则修正。',
      ],
    ),
    ZxThinkerGuide(
      sequence: 3,
      systemId: 'beck_cognitive_therapy',
      displayName: '贝克 · 认知检验与行为实验',
      thinker: 'Aaron T. Beck',
      category: '事实、解释与预测',
      evolutionStage: '第二层 · 心理落地：观念、认知与非强迫行动',
      primaryLensId: 'AB_COGNITIVE_TEST',
      lensIds: <String>['AB_COGNITIVE_TEST'],
      coreValues: <String>['求真', '合作检验', '可修正', '现实证据', '行动实验'],
      coreIdeas: <String>[
        '自动思维是迅速出现的解释和预测，不应因为感觉真实就被当成事实。',
        '把事实、解释、预测和人格结论分开，寻找证据、反证及可行的替代解释。',
        '重要预测需要通过低风险、分级、可逆的行为实验接受现实检验。',
        '一次失败只能更新一个具体假设，不能直接证明“我这个人不行”。',
      ],
      knowledgeView:
          '当前理解是一组可观察、可检验、可修订的假设；确信感不等于证据，解释必须接受事实和结果约束。',
      actionView:
          '行动既是目标行为，也是产生新证据的实验；它用实际结果校正预测、信念和下一步难度。',
      splitDiagnosis:
          '灾难化、负面预测、读心、过度概括或失败人格化，使人把未经检验的解释当成已经发生的事实。',
      transformationPath:
          '捕捉自动思维 → 分开事实/解释/预测 → 检查证据与替代解释 → 设计最小行为实验 → 比较预测和实际结果 → 更新判断。',
      actionFeedback:
          '预测误差为认识提供直接回写：结果可能支持、部分支持或反驳原判断，并指出需要改变的是信念、技能还是条件。',
      yangmingConnection:
          '它把“格物”和“事上磨”转化为现代可检验协议，但贝克的经验检验不能替代王阳明关于行动方向和责任正当性的判断。',
      inheritedLimit:
          '即使动作表象足够清楚，若“我一定失败”“别人必定否定我”等预测被当成事实，注意仍会服务于回避。',
      qualitativeLeap:
          '从保持一个行动观念，升级为先审查这个观念所依赖的事实模型，再让行动主动制造证据。',
      synthesisOutcome:
          '知行循环加入“假设—实验—预测误差—更新”，行动不仅实行所知，也系统地修正所知。',
      workSynthesis:
          '以《认知治疗与情绪障碍》中的自动思维、认知检验、替代解释、分级任务和行为实验构成证据更新链。',
      sevenLoopRoles: <String>['澄清', '求证'],
      distinctiveFocus:
          '最关心阻断行动的具体预测是否有证据，以及能否用一个小实验得到新事实。',
      decisionCue:
          '“一定失败、别人会否定我、一次失败说明我没有能力”等未经验证的判断让你不敢开始。',
      buildsOnSystemIds: <String>['yangming', 'william_james'],
      relatedSystemIds: <String>[
        'ellis_rebt',
        'act',
        'dewey',
        'behavioral_activation',
        'comb_bcw',
      ],
      tensions: <String>[
        '真实危险、歧视、资源不足和结构伤害不能被说成“只是你的想法”。',
        '对不可即时判定或反复纠缠的念头，持续辩论可能加重融合，需要ACT补足。',
      ],
    ),
    ZxThinkerGuide(
      sequence: 4,
      systemId: 'ellis_rebt',
      displayName: '埃利斯 · 从“必须”退回偏好',
      thinker: 'Albert Ellis',
      category: '绝对要求与挫折耐受',
      evolutionStage: '第二层 · 心理落地：观念、认知与非强迫行动',
      primaryLensId: 'AE_PREFERENCE_TOLERANCE',
      lensIds: <String>['AE_PREFERENCE_TOLERANCE'],
      coreValues: <String>['理性弹性', '偏好', '挫折耐受', '无条件自我接纳', '实践'],
      coreIdeas: <String>[
        '事件并不直接决定反应，人对事件的信念和评价会放大或缓冲其影响。',
        '“必须、应该、绝不能失败、我受不了”会把困难升级为灾难和人格判决。',
        '把绝对要求退回强烈偏好，承认不理想、困难和失败可以令人痛苦但仍可承受。',
        '辩驳若不进入现实触发情境中的练习，仍只是新的漂亮说法。',
      ],
      knowledgeView:
          '理性认识不仅要符合事实，还要检查逻辑一致性、现实后果和语言中的绝对化要求。',
      actionView:
          '行是在真实触发中带着不完美练习偏好、耐受和无条件自我接纳，而不是等说服自己后才行动。',
      splitDiagnosis:
          '绝对要求、低挫折耐受、灾难化和表现—人格混同，使人宁愿回避也不愿承担不完美行动。',
      transformationPath:
          '识别A情境与C反应 → 找到B中的“必须/受不了” → 逻辑、证据和效用辩驳 → 改写为偏好 → 在低风险现场练习。',
      actionFeedback:
          '现实练习会显示不完美结果是否真的不可承受，并让挫折耐受从一句话变成可调用的经验。',
      yangmingConnection:
          '它帮助区分诚意工夫与羞耻式自逼，防止把“克治”误用成对人格的绝对否定；但不决定何者是良知方向。',
      inheritedLimit:
          '贝克能修正预测内容，但人仍可能用“我必须成功、不能难受”把任何行动结果变成自我价值审判。',
      qualitativeLeap:
          '从“这个预测真实吗”推进到“即使结果不理想，我是否仍能承受并继续选择”。',
      synthesisOutcome:
          '知行合一获得反完美主义保护：真知不再等同于无误行动，行动者可以在失误中保留尊严和修正能力。',
      workSynthesis:
          '以《心理治疗中的理性与情绪》中的ABC、绝对化信念、积极辩驳、挫折耐受和无条件自我接纳构成实践路径。',
      sevenLoopRoles: <String>['澄清', '容纳', '启动'],
      distinctiveFocus:
          '最关心“必须、应该、受不了”和整个人格评价怎样把普通困难升级为无法行动。',
      decisionCue:
          '你并非不知道怎么做，而是要求自己必须完美、不能失败、不能被否定或不能感到难受。',
      buildsOnSystemIds: <String>[
        'yangming',
        'beck_cognitive_therapy',
      ],
      relatedSystemIds: <String>[
        'beck_cognitive_therapy',
        'act',
        'laozi',
        'behavioral_activation',
      ],
      tensions: <String>[
        '真实侵害、权利受损和不公不能只靠改变信念来适应。',
        '原著的强硬辩驳语气不能复制成产品中的羞耻、责备或强迫。',
      ],
    ),
    ZxThinkerGuide(
      sequence: 5,
      systemId: 'laozi',
      displayName: '老子 · 无为、减法与柔韧行动',
      thinker: '老子',
      category: '非强迫行动与恢复',
      evolutionStage: '第二层 · 心理落地：观念、认知与非强迫行动',
      primaryLensId: 'LZ_REDUCE_FORCE',
      lensIds: <String>['LZ_REDUCE_FORCE'],
      coreValues: <String>['自然', '无为', '节制', '柔弱', '知止', '微小'],
      coreIdeas: <String>[
        '无为不是不行动，而是不以过度控制、虚妄加码和僵硬执持破坏行动条件。',
        '先删除无效步骤、过多目标和人为摩擦，在问题尚微时采取最小必要介入。',
        '柔弱意味着保持方向时允许方法、节奏和姿态随条件调整。',
        '知道何时停止、留白和恢复，是行动智慧的一部分，不是失败。',
      ],
      knowledgeView:
          '知包含对时机、限度、关系和整体过程的体察；不是掌握越多规则、施加越多控制就越接近现实。',
      actionView:
          '行是与现实条件协调的必要介入：少而准确、可退可调、在尚微处开始，不以强制制造表面服从。',
      splitDiagnosis:
          '越想控制越僵硬，把恢复也变成任务，不断增加计划和意志要求，最终让行动入口被自身设计压垮。',
      transformationPath:
          '辨认妄为和过控 → 删除一个非必要步骤 → 缩小到尚微可做的一步 → 保留停止和调整条件 → 观察系统是否重新流动。',
      actionFeedback:
          '反馈不只看是否完成，还看摩擦是否下降、身体和关系是否可持续、过程是否因少做而更准确。',
      yangmingConnection:
          '王阳明提供“为何做、向何处做”的规范主线；老子补充“不要把致知工夫做成过度强迫”，形成方向坚定、方法柔韧。',
      inheritedLimit:
          '认知检验和挫折耐受仍可能被误用成“更正确、更能忍、更用力”，行动系统反而因过控而失去弹性。',
      qualitativeLeap:
          '从不断增加认知和意志，转向识别哪些多余控制必须撤掉，行动才会重新发生。',
      synthesisOutcome:
          '知行合一不再等于持续加压，而成为“守住方向、减去妄为、在微处行动、随反馈调整”的柔性工夫。',
      workSynthesis:
          '综合《道德经/德道经》中的无为、少私寡欲、图难于易、为大于细、柔弱胜刚强和知止；翻译差异保留版本说明。',
      sevenLoopRoles: <String>['容纳', '启动', '稳定', '恢复'],
      distinctiveFocus:
          '最关心是不是行动方式本身过重、过多、过急，正在制造原本不存在的阻力。',
      decisionCue:
          '你越逼自己越僵硬，计划越来越复杂，连休息和恢复都被变成了必须完成的任务。',
      buildsOnSystemIds: <String>[
        'yangming',
        'william_james',
        'ellis_rebt',
      ],
      relatedSystemIds: <String>[
        'yangming',
        'act',
        'maslow',
        'dewey',
        'comb_bcw',
      ],
      tensions: <String>[
        '无为不得被解释为逃避责任、放弃必要治疗、求助、边界或明确紧急行动。',
        '与强调纪律和重复的路径存在真实张力，需要区分方向坚持与方法僵化。',
      ],
    ),
    ZxThinkerGuide(
      sequence: 6,
      systemId: 'act',
      displayName: 'ACT · 带着不适走向价值',
      thinker: 'Hayes、Strosahl、Wilson',
      category: '心理灵活性与承诺行动',
      evolutionStage: '第三层 · 主体升华：接纳、自主、价值与意义',
      primaryLensId: 'ACT_FLEXIBILITY',
      lensIds: <String>['ACT_FLEXIBILITY'],
      coreValues: <String>['心理灵活性', '接纳', '解离', '当下', '价值', '承诺行动'],
      coreIdeas: <String>[
        '不必先消除焦虑、羞耻、厌烦或怀疑，先改变自己与这些体验的关系。',
        '认知解离让念头从命令退回为正在发生的心理事件，接纳允许不可避免体验存在。',
        '价值是持续可选择的行动方向，不是一次完成的目标、社会标准或情绪状态。',
        '承诺行动允许偏离、复发和重新选择，心理灵活性比完美控制更重要。',
      ],
      knowledgeView:
          '除了判断念头内容真假，还要知道它在此刻怎样发挥功能；一种想法即使无法立即解决，也不必继续支配行动。',
      actionView:
          '行是在当下与价值保持联系，愿意携带允许存在的不适，完成一个可调整的承诺动作。',
      splitDiagnosis:
          '认知融合和经验回避把“先感觉好、先想明白、先消除恐惧”设为行动许可证，导致生活范围不断缩小。',
      transformationPath:
          '觉察当下 → 命名头脑故事并解离 → 区分可避免伤害与可允许体验 → 澄清价值 → 选择小承诺行动 → 偏离后重承诺。',
      actionFeedback:
          '结果不仅回答任务是否完成，还回答这种行动是否让生活更接近价值、是否扩大可选择行为范围。',
      yangmingConnection:
          '它把“允许感受存在”与“是否按冲动行动”分开，补足王阳明工夫中对非自愿内在体验的现代处理；价值根据与良知本体仍不同。',
      inheritedLimit:
          '即使减少用力、修正信念，某些不适仍会持续；若仍把舒适当作前提，行动会再次被内在体验控制。',
      qualitativeLeap:
          '从“先改变想法和感觉再行动”推进到“可以带着它们行动，并由价值而非舒适决定方向”。',
      synthesisOutcome:
          '知行合一获得心理灵活性：知不必等内心完全一致，行也不要求压抑体验，而是在不适中保持可选择。',
      workSynthesis:
          '整合ACT的接触当下、认知解离、接纳、自我即情境、价值和承诺行动六类过程，并保留功能语境边界。',
      sevenLoopRoles: <String>['方向', '容纳', '启动', '内化'],
      distinctiveFocus:
          '最关心人是否为了控制内在体验而远离生活，以及能否带着体验向价值移动。',
      decisionCue:
          '你总在等焦虑、羞耻、厌烦、怀疑或低落消失以后才允许自己开始。',
      buildsOnSystemIds: <String>[
        'yangming',
        'beck_cognitive_therapy',
        'ellis_rebt',
        'laozi',
      ],
      relatedSystemIds: <String>[
        'yangming',
        'beck_cognitive_therapy',
        'ellis_rebt',
        'laozi',
        'self_determination',
        'behavioral_activation',
      ],
      tensions: <String>[
        '接纳内部体验不等于接受外部侵害、结构不公或可避免伤害。',
        '与贝克、埃利斯在“改变思想内容还是改变与思想的关系”上存在方法张力。',
      ],
    ),
    ZxThinkerGuide(
      sequence: 7,
      systemId: 'self_determination',
      displayName: '自我决定理论 · 从外控到内化',
      thinker: 'Ryan、Deci',
      category: '自主、胜任与关系',
      evolutionStage: '第三层 · 主体升华：接纳、自主、价值与意义',
      primaryLensId: 'SDT_INTERNALIZATION',
      lensIds: <String>['SDT_INTERNALIZATION'],
      coreValues: <String>['自主', '胜任', '关系', '内化', '整合', '支持性环境'],
      coreIdeas: <String>[
        '动机不只有多少，还有质量：外部控制、内摄压力、认同和整合会产生不同的持续方式。',
        '自主不是任性，而是体验到行动由自己认领；胜任需要适配挑战和有效反馈。',
        '关系需要让人感到被看见、被尊重且与重要他人相连，而不是被孤立地要求自律。',
        '高质量持续来自自主、胜任和关系共同支持，奖励不能取代行动意义。',
      ],
      knowledgeView:
          '知道目标“有好处”还不够，还要知道它是否被主体认领、与自我整合，以及当前环境是否支持三种基本心理需要。',
      actionView:
          '行是由自己认领、难度适配、获得真实反馈并处于支持关系中的持续实践，而非被监控后的短期服从。',
      splitDiagnosis:
          '目标主要由奖励、羞耻、内疚、威胁或他人期待驱动；提醒撤除后行动消失，或挑战持续破坏胜任与关系。',
      transformationPath:
          '识别动机调节位置 → 给出选择和真实理由 → 调整难度以形成胜任证据 → 建立关系支持 → 逐步撤除控制性支架。',
      actionFeedback:
          '复盘要观察自主感、胜任证据、关系质量和提醒依赖是否变化，而不只看打卡次数。',
      yangmingConnection:
          '它把“立志”和真实认领细化为动机内化过程，并提醒良好方向若依靠控制性方式推进，也可能制造新的知行分裂。',
      inheritedLimit:
          '一个人能够带着不适行动，并不说明目标真正属于自己；羞耻和外控同样可以制造高执行。',
      qualitativeLeap:
          '从“我能否做出来”提升到“是谁在决定、为什么做，以及这种动力能否成为我自己的”。',
      synthesisOutcome:
          '知行合一加入主体性检验：行动必须逐步从外部控制转为自主认同、能力掌握和关系支持。',
      workSynthesis:
          '综合自我决定理论的三种基本心理需要、动机内化连续体、自主支持、胜任反馈和关系情境。',
      sevenLoopRoles: <String>['方向', '稳定', '内化'],
      distinctiveFocus:
          '最关心目标是不是用户自己的，以及持续行动是否由自主、胜任和关系共同支持。',
      decisionCue:
          '你主要因为别人要求、怕内疚或为了奖励而行动，一旦监督和提醒撤掉就停止。',
      buildsOnSystemIds: <String>['yangming', 'act'],
      relatedSystemIds: <String>[
        'yangming',
        'act',
        'nietzsche',
        'bandura',
        'frankl',
        'comb_bcw',
      ],
      tensions: <String>[
        '自主不能被误读为无需结构、责任和他人边界。',
        '金币和奖励只能确认进展，若成为主要控制手段会削弱内化。',
      ],
    ),
    ZxThinkerGuide(
      sequence: 8,
      systemId: 'nietzsche',
      displayName: '尼采 · 谱系、自我克服与价值创造',
      thinker: 'Friedrich Nietzsche',
      category: '价值来源、生命肯定与风格',
      evolutionStage: '第三层 · 主体升华：接纳、自主、价值与意义',
      primaryLensId: 'NZ_SELF_OVERCOMING',
      lensIds: <String>[
        'NZ_SELF_OVERCOMING',
        'NGS_STYLE',
        'NBG_WILL_COMPLEXITY',
        'NGM_GENEALOGY',
      ],
      coreValues: <String>[
        '生命肯定',
        '自我克服',
        '价值创造',
        '身体诚实',
        '风格',
        '承诺能力',
      ],
      coreIdeas: <String>[
        '价值谱系追问目标如何形成、服务何种力量，区分主动创造与怨恨、罪责和反应性证明。',
        '“我想要”不是一个按钮，而是感觉、命令、服从、能力、冲动和长期纪律的复杂关系。',
        '骆驼—狮子—孩子呈现承担、争取自主和积极创造三个不能互相替代的转化任务。',
        '身体、健康、充盈或匮乏参与思想判断；生命肯定要求审查自己是否愿意重复这种生活方式。',
        '自我克服不是压倒别人，而是重组自身力量，以长期实践赋予性格风格并形成可承担的承诺。',
      ],
      knowledgeView:
          '认识总带着视角、身体状态、欲望和价值判断；更深的知需要追问解释来自何种生命条件和权力关系。',
      actionView:
          '行是对自身力量的组织、对继承价值的实验性超越，以及通过长期选择创造能够肯定的生活风格。',
      splitDiagnosis:
          '目标看似自主，实则由“你应当”、怨恨、坏良心、羞耻证明或未整合的冲动支配；意志语言掩盖了真实条件和代价。',
      transformationPath:
          '价值谱系审查 → 身体与动机检查 → 拆解意志中的命令/服从/能力 → 完成骆驼/狮子/孩子当前任务 → 做价值实验 → 形成风格与承诺。',
      actionFeedback:
          '行动要检验它是否扩大创造能力、减少反应性、能够承担代价，并能否在“愿意再次如此选择”的试验中被肯定。',
      yangmingConnection:
          '二者都反对把思想停在言辞并强调自我工夫；但王阳明以良知作为规范根据，尼采则对价值来源进行谱系追问并强调创造，张力必须保留。',
      inheritedLimit:
          '自主认领仍可能只是内化了旧命令；一个目标即使“是我选择的”，也可能源于怨恨、亏欠、证明欲或生命否定。',
      qualitativeLeap:
          '从认领现有价值提升到追问价值的生成史，并在身体、力量和长期实践中创造新的可肯定方向。',
      synthesisOutcome:
          '知行合一从“执行正确目标”升华为“在行动中审查、克服并创造自己愿意承担的价值风格”。',
      workSynthesis:
          '《道德谱系》负责来源与罪责审查，《善恶的彼岸》拆解意志和纪律，《快乐的科学》加入身体、命运之爱与风格，《查拉图斯特拉》完成自我克服和价值创造；四书保留分工与张力。',
      sevenLoopRoles: <String>['方向', '澄清', '内化', '生成性行动'],
      distinctiveFocus:
          '最关心目标来自创造还是反应、意志内部如何组织，以及行动正在把人塑造成怎样的生命风格。',
      decisionCue:
          '你正在挣脱别人规定的人生，却仍被羞耻、怨恨、证明欲或继承的“你应当”推动。',
      buildsOnSystemIds: <String>['yangming', 'self_determination'],
      relatedSystemIds: <String>[
        'yangming',
        'self_determination',
        'frankl',
        'act',
        'maslow',
      ],
      tensions: <String>[
        '不得用力量、自我超越或“强者”语言正当化支配、轻视弱者、冒险和持续自我压迫。',
        '与王阳明在普遍良知和价值创造之间、与Frankl在意义发现和创造之间存在真实张力。',
      ],
    ),
    ZxThinkerGuide(
      sequence: 9,
      systemId: 'frankl',
      displayName: '弗兰克尔 · 意义、责任与受限自由',
      thinker: 'Viktor E. Frankl',
      category: '具体意义与自我超越',
      evolutionStage: '第三层 · 主体升华：接纳、自主、价值与意义',
      primaryLensId: 'FRK_MEANING',
      lensIds: <String>['FRK_MEANING'],
      coreValues: <String>['具体意义', '责任', '受限自由', '自我超越', '人的尊严'],
      coreIdeas: <String>[
        '意义不是一条普遍口号，而是此人此刻面对的具体任务、关系或立场。',
        '责任是对生活提出的问题作答，不是被羞耻和他人控制所追责。',
        '意义可通过创造、体验/相遇，以及对真正不可避免痛苦采取立场而实现。',
        '自由总是受条件限制，但人在部分条件中仍可能选择态度和可承担行动。',
        '自我超越把注意从不断评估自我，转向值得服务的人、事、作品或责任。',
      ],
      knowledgeView:
          '知是辨认此刻生活向自己提出的具体问题，区分可改变条件、不可改变条件和不能转嫁的责任。',
      actionView:
          '行是在限制中作出具体回应：创造、相遇、照料、完成责任，或在不可避免处境中选择不被夺走的立场。',
      splitDiagnosis:
          '行动失去意义对象，只剩自我评分；把所有痛苦浪漫化，或反过来因为不能完全控制处境而放弃仍有的自由。',
      transformationPath:
          '先移除可避免痛苦并求助 → 确认真实限制 → 询问此刻谁或什么值得回应 → 划清责任边界 → 完成一个指向自身之外的动作。',
      actionFeedback:
          '复盘观察行动是否真正服务了某人某事、是否尊重限制与边界，以及责任感是变得具体还是再次变成自责。',
      yangmingConnection:
          '二者都把知与责任性行动相连；弗兰克尔补足极端限制和具体意义情境，王阳明则提供更明确的良知与成德主线。',
      inheritedLimit:
          '价值创造和自主可能仍以自我为中心；当处境不可改变时，仅强调创造自己也可能无法回答“我仍能对什么负责”。',
      qualitativeLeap:
          '从“我想成为谁”推进到“此刻生活在向我提出什么问题，我愿意对谁或什么作答”。',
      synthesisOutcome:
          '知行合一获得受限处境中的意义轴：行动不要求全能控制，而要求在边界内承担具体、非浪漫化的责任。',
      workSynthesis:
          '以《活出意义来/Man’s Search for Meaning》中的具体意义、责任、三条意义道路、自我超越、自由与态度价值构成体系。',
      sevenLoopRoles: <String>['方向', '容纳', '内化', '生成性行动'],
      distinctiveFocus:
          '最关心人在限制、失向和不可控条件中，仍愿意对谁、对什么、以何种边界作答。',
      decisionCue:
          '你感到无意义、受限或失去方向，需要找到一个不是抽象口号的具体责任对象。',
      buildsOnSystemIds: <String>[
        'yangming',
        'act',
        'self_determination',
        'nietzsche',
      ],
      relatedSystemIds: <String>[
        'yangming',
        'act',
        'self_determination',
        'nietzsche',
        'maslow',
      ],
      tensions: <String>[
        '不得把可避免的痛苦神圣化，也不得要求用户从创伤、疾病或压迫中“找到意义”来证明自己。',
        '意义建议不能替用户规定使命，必须由用户在事实和边界中认领。',
      ],
    ),
    ZxThinkerGuide(
      sequence: 10,
      systemId: 'dewey',
      displayName: '杜威 · 探究、习惯与环境重构',
      thinker: 'John Dewey',
      category: '反思性探究与经验生长',
      evolutionStage: '第四层 · 行动实现：探究、启动、学习与反回避',
      primaryLensId: 'DHT_REFLECTIVE_INQUIRY',
      lensIds: <String>[
        'DHT_REFLECTIVE_INQUIRY',
        'DHC_HABIT_ENVIRONMENT',
      ],
      coreValues: <String>['经验', '探究', '开放心态', '智识责任', '生长', '人境互动'],
      coreIdeas: <String>[
        '反思从真实行动受阻和疑惑开始，经建议、问题化、假设、推演与行动检验形成可靠判断。',
        '错误不是人格判决，而是指出还需观察什么、假设和方法应怎样修正。',
        '习惯是人与物质、社会环境共同形成的行动倾向，不是头脑中的孤立程序。',
        '目的只有转化为当前下一行动才发挥作用，手段和目的在后果中连续并共同接受修正。',
        '生长不是到达固定终点，而是持续重建经验、习惯、能力、关系和判断。',
      ],
      knowledgeView:
          '知是在受阻情境中主动、持续、审慎地考察信念的依据和后果，并通过行动检验形成的暂定可靠判断。',
      actionView:
          '行既是解决问题的尝试，也是探究的一部分；它同时改变外部条件、习惯结构和未来可采取的行动。',
      splitDiagnosis:
          '问题未被具体化就套用答案，把失败归因于固定人格，目标与当前条件脱节，或忽略维持旧习惯的工具、空间和关系。',
      transformationPath:
          '受阻事实 → 问题化 → 竞争假设 → 推演可观察结果 → 小型行动检验 → 环境/习惯重构 → 结果回写与下一轮探究。',
      actionFeedback:
          '后果用于修改问题定义、假设、手段、目的和环境条件；有效答案始终保留复审期限。',
      yangmingConnection:
          '它把“事上磨”补成问题—假设—检验协议，并把环境重构纳入工夫；但杜威不诉诸良知本体，产品仍需独立伦理守门。',
      inheritedLimit:
          '价值、意义和心理灵活性仍不足以处理“究竟卡在哪里”的模糊失败，也容易把习惯和环境问题重新内化为主体缺陷。',
      qualitativeLeap:
          '从在行动中体现既有认识，推进到把行动本身组织成能够生成、检验和修正认识的持续探究。',
      synthesisOutcome:
          '知行合一形成完整回路：行动受阻产生问题，探究生成假设，行动检验假设，结果重构知识、习惯和环境。',
      workSynthesis:
          '《我们怎样思维》提供问题化、假设、推演和检验；《人性与行为》补入习惯、冲动、环境、审议、目的—手段连续性和生长，二书统一为经验探究系统。',
      sevenLoopRoles: <String>['澄清', '稳定', '求证', '内化'],
      distinctiveFocus:
          '最关心受阻情境如何被转成可检验问题，以及人和环境怎样共同维持或重构习惯。',
      decisionCue:
          '你反复失败，却仍说不清真正问题，多个解释彼此竞争，同一个环境还总触发旧习惯。',
      buildsOnSystemIds: <String>[
        'yangming',
        'william_james',
        'beck_cognitive_therapy',
      ],
      relatedSystemIds: <String>[
        'yangming',
        'william_james',
        'beck_cognitive_therapy',
        'gollwitzer',
        'bandura',
        'comb_bcw',
      ],
      tensions: <String>[
        '不能把一切人生关系都实验化；不可逆、第三方、医疗、法律和重大财务问题必须先限缩风险。',
        '有效和可修正不自动等于道德正当，伦理方向不能由问题解决效率代替。',
      ],
    ),
    ZxThinkerGuide(
      sequence: 11,
      systemId: 'gollwitzer',
      displayName: 'Gollwitzer · 把意图编译成现场行动',
      thinker: 'Peter M. Gollwitzer',
      category: '实施意向与情境启动',
      evolutionStage: '第四层 · 行动实现：探究、启动、学习与反回避',
      primaryLensId: 'II_CUE_ACTION',
      lensIds: <String>['II_CUE_ACTION'],
      coreValues: <String>['具体', '预承诺', '情境线索', '减少决策负担', '复审'],
      coreIdeas: <String>[
        '目标意向回答“我要达到什么”，实施意向回答“当X出现时，我就做Y”。',
        '清楚且可识别的线索会提高现场可及性，具体反应会减少临场重新决定。',
        '如果—那么计划只适用于已经认领、可行且风险受控的目标。',
        '自动启动不是永久命令，规则需要例外、有效期和触发复审。',
      ],
      knowledgeView:
          '程序性知必须包含何时、何地、出现什么线索以及立即采取什么反应，而不只是目标和理由。',
      actionView:
          '行是在预定情境出现时执行一个具体可控反应，使行动入口不再依赖临场动机和重新决策。',
      splitDiagnosis:
          '目标和理由都清楚，却在关键时刻忘记、犹豫、被干扰或把决定无限推迟。',
      transformationPath:
          '确认目标已认领且可行 → 选择高辨识度线索X → 指定单一可控反应Y → 预演一次 → 设定例外与复审时间。',
      actionFeedback:
          '观察线索是否真正出现、是否被识别、反应是否可执行，以及规则是否产生意外僵化，再修改X或Y。',
      yangmingConnection:
          '它把立志后的具体意向编译成现场入口，使“知是行的主意”获得时间和情境结构，但不能判断目标是否合乎良知。',
      inheritedLimit:
          '探究已经找到了合理下一步，仍不能保证关键情境中它会被想起和启动。',
      qualitativeLeap:
          '从“我决定要做”推进到“现实中一旦出现哪个信号，我立即做哪个动作”。',
      synthesisOutcome:
          '知行之间增加情境桥梁，减少每次行动都重新调用意志和决策的成本。',
      workSynthesis:
          '综合实施意向研究中的目标意向—实施意向区分、线索可及性、反应自动启动、边界条件和计划僵化风险。',
      sevenLoopRoles: <String>['启动', '稳定'],
      distinctiveFocus:
          '最关心已认领目标为何在关键时刻没有被触发，以及线索和反应能否预先绑定。',
      decisionCue:
          '你知道、愿意也会做，但总在关键时刻忘记、拖延、犹豫或被别的事情带走。',
      buildsOnSystemIds: <String>[
        'william_james',
        'self_determination',
        'dewey',
      ],
      relatedSystemIds: <String>[
        'william_james',
        'dewey',
        'bandura',
        'oettingen',
        'comb_bcw',
      ],
      tensions: <String>[
        '线索—反应自动化不能替代价值、可行性、能力和风险判断。',
        '把所有生活脚本化会压缩反思和适应性，规则必须允许例外和过期。',
      ],
    ),
    ZxThinkerGuide(
      sequence: 12,
      systemId: 'bandura',
      displayName: '班杜拉 · 榜样、效能与能动性',
      thinker: 'Albert Bandura',
      category: '社会学习、自我效能与自我调节',
      evolutionStage: '第四层 · 行动实现：探究、启动、学习与反回避',
      primaryLensId: 'SLT_MODELING',
      lensIds: <String>['SLT_MODELING', 'SEF_MASTERY'],
      coreValues: <String>['能动性', '观察学习', '掌握经验', '效能校准', '自我调节', '集体效能'],
      coreIdeas: <String>[
        '个人、行为和环境相互影响，人既受条件塑造，也能通过行动改变条件。',
        '观察学习通过注意、保持、动作再现和动机过程降低昂贵试错。',
        '自我效能是对特定情境中组织并执行行动能力的判断，不等于自尊和空泛积极思考。',
        '掌握经验是最强效能信息，榜样、劝导和身心状态只能在真实技能与反馈中校准。',
        '自我调节和集体效能把行动从孤立意志扩展到目标、监测、反馈、协作和共同能力。',
      ],
      knowledgeView:
          '知不仅是理解道理，还包括“我是否知道怎么做、能否在此情境组织行动、可以从谁和什么反馈中学习”。',
      actionView:
          '行是观察、演练、分级掌握、自我监测和协作调节的能动过程，并会反过来改变环境与自我效能判断。',
      splitDiagnosis:
          '缺少子技能和过程示范，把他人结果当成自己的能力证据，低估或高估特定任务效能，或孤立行动缺少团队支持。',
      transformationPath:
          '定义具体子技能 → 选择相似且过程透明的榜样 → 观察与演练 → 完成略高于现有掌握的一步 → 获取信息性反馈 → 更新任务特定效能。',
      actionFeedback:
          '真实掌握、错误位置、投入质量和协作结果共同校准效能；信心只迁移到相似任务和条件。',
      yangmingConnection:
          '它为事上磨补入“不会做”和“尚不相信能做”的学习机制，并把环境与集体能动性纳入知行；效能本身仍需良知守门。',
      inheritedLimit:
          '一个清楚的如果—那么计划无法弥补技能缺口，也无法凭空产生有证据的行动信心。',
      qualitativeLeap:
          '从“把行动触发出来”推进到“通过榜样、掌握和反馈真正学会，并形成可校准的能动信念”。',
      synthesisOutcome:
          '知行合一获得能力成长轴：行动不只是实行意志，而是在社会环境中学习、掌握和扩大真实可行性。',
      workSynthesis:
          '《社会学习理论》提供观察学习、相互决定和自我调节；《自我效能》补入任务特定效能、四类信息来源、中介过程与集体效能，统一为能动学习系统。',
      sevenLoopRoles: <String>['启动', '稳定', '求证', '内化'],
      distinctiveFocus:
          '最关心用户是否真正会做、是否有相似榜样和掌握证据，以及信心是否与具体能力匹配。',
      decisionCue:
          '你并非不想做，而是不知道动作细节、缺少示范，或“我做不到”的判断没有经过真实掌握检验。',
      buildsOnSystemIds: <String>[
        'william_james',
        'dewey',
        'gollwitzer',
      ],
      relatedSystemIds: <String>[
        'william_james',
        'self_determination',
        'dewey',
        'gollwitzer',
        'oettingen',
        'comb_bcw',
      ],
      tensions: <String>[
        '效能是价值中性的，高自我效能可以服务于不正当目标，必须先通过伦理和第三方守门。',
        '言语鼓励不能替代技能、机会和亲历掌握，产品不得制造虚假自信。',
      ],
    ),
    ZxThinkerGuide(
      sequence: 13,
      systemId: 'oettingen',
      displayName: 'Oettingen · 心理对照与WOOP',
      thinker: 'Gabriele Oettingen',
      category: '愿望、障碍与可行承诺',
      evolutionStage: '第四层 · 行动实现：探究、启动、学习与反回避',
      primaryLensId: 'OET_WOOP',
      lensIds: <String>['OET_WOOP'],
      coreValues: <String>['现实主义', '愿望', '可行性', '障碍', '投入或退出'],
      coreIdeas: <String>[
        '单纯沉浸在最佳未来可能提前带来满足感，却没有产生面对现实障碍的能量。',
        '心理对照把期待未来与当前现实并置，让可行性调节承诺和投入。',
        'WOOP依次澄清愿望、最佳结果、关键内部障碍和针对障碍的计划。',
        '低可行愿望允许降级、延期或退出，退出不等于意志失败。',
      ],
      knowledgeView:
          '知包含对愿望价值、现实障碍和可行性的同时认识；积极图景只有与现实对照才成为行动信息。',
      actionView:
          '行是在确认可行后针对关键障碍采取工具行为；若不可行，则主动修改目标、增加资源或退出。',
      splitDiagnosis:
          '愿景和积极幻想很强，却没有识别现实障碍、没有做可行性判断，或把所有外部限制错误写成内部心态。',
      transformationPath:
          'Wish愿望 → Outcome最佳结果 → Obstacle关键障碍 → 可行性分流 → Plan为障碍写如果—那么工具反应。',
      actionFeedback:
          '行动结果验证障碍识别和可行性判断；若反复失败，应重新区分内部障碍、结构条件和资源缺口。',
      yangmingConnection:
          '它使立志不再停留于愿景，把“知而不行”具体化为尚未正视障碍或尚未决定真实投入；但不决定愿望的伦理方向。',
      inheritedLimit:
          '技能和效能都可能存在，人仍可停留在积极想象中，未把未来图景与当前障碍放在一起。',
      qualitativeLeap:
          '从“相信自己并制定计划”推进到“让现实可行性决定承诺、降级、增加条件或退出”。',
      synthesisOutcome:
          '知行合一加入愿望—现实对照：不是所有愿望都应强行执行，真实知道也包含知道何时不投入。',
      workSynthesis:
          '以《Rethinking Positive Thinking》及其研究综述中的心理对照、期待依赖、WOOP和脱离低可行目标构成体系。',
      sevenLoopRoles: <String>['方向', '澄清', '启动'],
      distinctiveFocus:
          '最关心积极愿景为何没有进入现实，以及关键障碍和可行性是否被诚实面对。',
      decisionCue:
          '你想象了许多成功画面、愿望也很强，却始终没有正视真正障碍或决定是否值得投入。',
      buildsOnSystemIds: <String>[
        'self_determination',
        'gollwitzer',
        'bandura',
      ],
      relatedSystemIds: <String>[
        'gollwitzer',
        'bandura',
        'behavioral_activation',
        'comb_bcw',
        'harvard_positive_psychology',
      ],
      tensions: <String>[
        'WOOP中的障碍不能默认是“内心问题”，结构性机会必须由COM-B先行检查。',
        '不应把四步做成新的冗长问卷；产品只在真正需要时展开关键一步。',
      ],
    ),
    ZxThinkerGuide(
      sequence: 14,
      systemId: 'behavioral_activation',
      displayName: '行为激活 · 从回避循环重新接触生活',
      thinker: 'Martell等行为激活体系',
      category: '功能分析、分级活动与自然强化',
      evolutionStage: '第四层 · 行动实现：探究、启动、学习与反回避',
      primaryLensId: 'BA_ACTIVATION',
      lensIds: <String>['BA_ACTIVATION'],
      coreValues: <String>['行动接触', '功能分析', '反回避', '分级', '自然强化', '同情边界'],
      coreIdeas: <String>[
        '回避常在短期减轻不适，因此被强化，却在长期缩小生活并增加困难。',
        '功能分析不问行为抽象上好坏，而问触发、反应、短期结果和长期代价。',
        '不必等情绪改善才行动，可先安排与价值、掌握或连接有关的分级活动。',
        'TRAP识别触发—反应—回避模式，TRAC把替代应对落实为可做的一步。',
      ],
      knowledgeView:
          '知是看见行为在具体情境中的功能和强化后果，而不是用“懒惰、意志差”概括整个人。',
      actionView:
          '行是按计划接触现实、减少回避、获得自然结果和新信息；步幅随容量调整。',
      splitDiagnosis:
          '刷手机、躺下、取消、拖延等行为带来短期轻松，因此不断被强化；情绪好转被设成开始条件。',
      transformationPath:
          '记录触发与短期缓解 → 看见长期代价 → 选择价值/掌握/连接活动 → 缩成可完成一步 → 按计划接触 → 观察自然后果。',
      actionFeedback:
          '复盘区分完成、情绪变化、回避功能和现实强化；未完成用于调整活动、时间、难度和支持。',
      yangmingConnection:
          '它把“事上磨”落到反回避和现实接触，但必须避免把临床方法道德化；行动方向仍由良知、价值和安全决定。',
      inheritedLimit:
          '人可能已经理解障碍、拥有计划和效能，却仍因回避立即带来的轻松而维持不行动。',
      qualitativeLeap:
          '从继续分析和准备，推进到用一个分级现实接触改变正在维持问题的行为—后果循环。',
      synthesisOutcome:
          '知行合一获得反回避机制：行动先带来环境反馈和生活接触，情绪不再垄断开始权。',
      workSynthesis:
          '综合行为激活中的活动监测、功能分析、按计划行动、分级任务、TRAP—TRAC和自然强化；仅作自助行动框架，不作疾病诊断。',
      sevenLoopRoles: <String>['容纳', '启动', '求证', '恢复'],
      distinctiveFocus:
          '最关心当前行为短期避开了什么、长期又维持了什么，以及哪个替代动作能重新接触生活。',
      decisionCue:
          '刷手机、躺着、取消或逃开会立刻轻松一些，却让长期活动、掌握和联系越来越少。',
      buildsOnSystemIds: <String>[
        'beck_cognitive_therapy',
        'act',
        'oettingen',
      ],
      relatedSystemIds: <String>[
        'beck_cognitive_therapy',
        'act',
        'oettingen',
        'maslow',
        'harvard_positive_psychology',
      ],
      tensions: <String>[
        '不得把严重低落、急性风险或功能显著受损简化为“先做起来”，需要专业评估时必须转介。',
        '行动优先不能覆盖容量、疼痛、安全和不可逆后果。',
      ],
    ),
    ZxThinkerGuide(
      sequence: 15,
      systemId: 'maslow',
      displayName: '马斯洛 · 需要、容量与成长条件',
      thinker: 'Abraham H. Maslow',
      category: '需要、恢复与成长容量',
      evolutionStage: '第五层 · 系统整合：容量、日常转化与行为工程',
      primaryLensId: 'MMP_CAPACITY',
      lensIds: <String>['MMP_CAPACITY'],
      coreValues: <String>['基本需要', '安全', '归属', '成长', '整体人', '容量保护'],
      coreIdeas: <String>[
        '需要具有动态相对优先性，不是人人按固定台阶逐级通关。',
        '安全、睡眠、身体、归属和支持不足会真实压缩行动容量，不能先解释为懒惰。',
        '缺失动机试图填补不足，成长动机趋向表达和实现可能性，两者可以同时存在。',
        '自我实现不是精英等级，而是更充分地实现真实能力、价值和创造。',
      ],
      knowledgeView:
          '知必须包括对身体、基本需要、负荷和当前成长容量的现实判断，不能只知道理想目标。',
      actionView:
          '行既可以是挑战，也可以是睡眠、进食、就医、求助、减负、建立安全和恢复秩序等支持动作。',
      splitDiagnosis:
          '把过载、疼痛、缺睡、安全不足和关系孤立解释为意志问题，用更高目标持续压迫已经不足的容量。',
      transformationPath:
          '检查安全与身体 → 找到当前最紧迫的需要缺口 → 选择恢复、减负或支持动作 → 重新评估容量 → 再决定挑战难度。',
      actionFeedback:
          '观察睡眠、疼痛、注意、压力、支持和功能是否恢复，以及挑战是否扩大能力而非继续透支。',
      yangmingConnection:
          '它提醒致良知和事上磨发生在有限身体与现实条件中，防止把一切困难道德化；需要满足本身仍不决定行动方向。',
      inheritedLimit:
          '行动优先、意义张力和自我超越若缺少容量守门，可能把疲惫、病痛和缺乏支持误称为成长机会。',
      qualitativeLeap:
          '从“怎样让自己继续行动”推进到“当前是否具备行动容量，以及恢复本身是不是最必要的行”。',
      synthesisOutcome:
          '知行合一纳入有限人性：休息、求助、治疗、减负和建立安全可以是服务长期方向的正当行动。',
      workSynthesis:
          '以《动机与人格》中的动态需要优先、缺失/成长动机、整体人和自我实现构成容量守门；拒绝刚性金字塔解释。',
      sevenLoopRoles: <String>['方向', '容纳', '恢复', '稳定'],
      distinctiveFocus:
          '最关心当前身体和基本需要是否允许挑战，以及恢复、减负或支持是否应先于执行。',
      decisionCue:
          '你睡眠不足、身体不适、过载、缺少安全或支持，继续硬逼只会把行动变成透支。',
      buildsOnSystemIds: <String>[
        'self_determination',
        'behavioral_activation',
      ],
      relatedSystemIds: <String>[
        'laozi',
        'self_determination',
        'frankl',
        'behavioral_activation',
        'harvard_positive_psychology',
        'comb_bcw',
      ],
      tensions: <String>[
        '需要层级不能用于给人贴等级、推迟一切成长或诊断人格。',
        '容量保护不是无限回避挑战，恢复后仍要重新评估可行的小步。',
      ],
    ),
    ZxThinkerGuide(
      sequence: 16,
      systemId: 'harvard_positive_psychology',
      displayName: '哈佛积极心理学课程 · 从信息到转化',
      thinker: 'Tal Ben-Shahar课程体系',
      category: '练习、仪式、允许为人与恢复',
      evolutionStage: '第五层 · 系统整合：容量、日常转化与行为工程',
      primaryLensId: 'HPL_TRANSFORMATION',
      lensIds: <String>['HPL_TRANSFORMATION'],
      coreValues: <String>['转化', '日常练习', '允许为人', '现实主义乐观', '恢复', '仪式'],
      coreIdeas: <String>[
        '信息本身不会自动带来改变，理解必须通过认知、情感和行为通道进入生活。',
        '允许自己为人承认正常情绪和有限性，避免用积极要求制造二次痛苦。',
        '过程想象比只想象结果更接近行动，仪式把重要行为安置在稳定时间和情境中。',
        '短练习、恢复、运动、感恩、优势和关系表达为长期行动提供积极资源。',
        '改变依靠反复实践与反思，而不是一次高峰体验或知识消费。',
      ],
      knowledgeView:
          '知必须从information转化为transformation：它在认知、情感、行为和日常仪式中产生可观察变化。',
      actionView:
          '行是小而重复、对人性友好、包含恢复的日常练习，并通过复盘逐渐成为生活结构。',
      splitDiagnosis:
          '不断阅读、听课和理解，却没有练习编排；只想象成功结果，不想象过程；把正常情绪和休息当成失败。',
      transformationPath:
          '选择一个原则 → 指定认知/情感/行为入口 → 过程想象 → 设计最小日常仪式 → 安排恢复 → 周期复盘与调整。',
      actionFeedback:
          '观察练习是否真正进入生活、是否提高积极资源和可恢复性，而不是只记录知识量和连续打卡。',
      yangmingConnection:
          '它把知行合一转成日常转化课程：道理只有被练习、体验、仪式和反思吸收才改变生活；课程材料不提供良知本体。',
      inheritedLimit:
          '前述理论即使结构完整，也可能再次成为信息收藏；缺少简洁练习、仪式、允许为人和恢复，就难以进入日常。',
      qualitativeLeap:
          '从拥有一套解释和方法，推进到把它们编排成可以长期生活、偏离后能够恢复的日常实践。',
      synthesisOutcome:
          '知行合一获得转化节律：学到—练习—体验—恢复—反思—再练习，知识逐步沉淀为生活。',
      workSynthesis:
          '整合课程中的information/transformation、ABC通道、允许为人、过程想象、仪式、恢复、优势、感恩和关系练习；转录材料标明需外部复核。',
      sevenLoopRoles: <String>['启动', '稳定', '恢复', '内化'],
      distinctiveFocus:
          '最关心丰富知识怎样被安排成今天可练、能够恢复、最终改变生活的日常结构。',
      decisionCue:
          '你阅读和理解了很多，甚至能清楚解释，却没有形成任何稳定练习和生活变化。',
      buildsOnSystemIds: <String>[
        'william_james',
        'self_determination',
        'behavioral_activation',
        'maslow',
      ],
      relatedSystemIds: <String>[
        'william_james',
        'act',
        'self_determination',
        'oettingen',
        'behavioral_activation',
        'maslow',
      ],
      tensions: <String>[
        '课程转录和教学简化不能被当成临床疗效证据，具体主张需要按来源等级使用。',
        '积极练习不得否认痛苦、结构障碍和专业照护需要。',
      ],
    ),
    ZxThinkerGuide(
      sequence: 17,
      systemId: 'comb_bcw',
      displayName: 'COM-B/BCW · 把全部思想编排成行为工程',
      thinker: 'Michie、Atkins、West',
      category: '能力、机会、动机与干预设计',
      evolutionStage: '第五层 · 系统整合：容量、日常转化与行为工程',
      primaryLensId: 'BCW_COMB',
      lensIds: <String>['BCW_COMB'],
      coreValues: <String>['具体行为', '系统性', '多因诊断', '可行性', '可接受性', '公平'],
      coreIdeas: <String>[
        '先把结果词改写成谁在何时、何地、多久、与谁做什么的具体行为。',
        '用身体/心理能力、物理/社会机会、反思/自动动机六格形成竞争假设。',
        '干预必须针对首要机制，不用励志语言覆盖技能、工具、关系和环境缺口。',
        'APEASE要求同时审查可负担性、可实施性、有效性、可接受性、副作用/安全与公平。',
        '思想镜头负责解释和方向，行为技术负责落地，现实结果负责重新诊断。',
      ],
      knowledgeView:
          '知是关于一个具体行为在此情境下的能力、机会、动机及其证据置信度的可修正系统模型。',
      actionView:
          '行是经过安全、伦理、容量和APEASE审查的单一干预动作，并包含支持条件、停止规则、证据和复审。',
      splitDiagnosis:
          '把目标写成抽象结果，把所有失败归因于动机，多个方法随意堆叠，或没有检查实施负担、副作用和公平。',
      transformationPath:
          '规定目标行为 → 安全/伦理/容量守门 → COM-B初筛 → 定位七环断点 → 选择主思想与互补思想 → 选择单一干预 → APEASE审查 → 行动与复盘。',
      actionFeedback:
          '结果更新首要障碍、思想匹配、效能、难度和环境假设；两次现实反驳后必须重新诊断而非继续加码。',
      yangmingConnection:
          '它是王阳明主线的工程编排层：帮助回答“这一件事怎样做出来并被检验”，但不能替代良知、价值、意义和责任判断。',
      inheritedLimit:
          '十六套思想已经提供丰富方向与方法，但若没有统一行为规定、障碍路由和干预审查，仍会出现建议堆叠与错配。',
      qualitativeLeap:
          '从拥有多种思想工具，升级为能够说明“为什么此时选这一套、怎样安全落地、结果如何改变下一轮”的完整系统。',
      synthesisOutcome:
          '最终形成知行合一行为工程：王阳明定主线，各思想补机制，COM-B负责路由，单一行动负责求证，复盘负责再知。',
      workSynthesis:
          '以《The Behaviour Change Wheel》中的行为规定、COM-B、TDF、干预功能、行为改变技术、APEASE和八步设计流程完成总编排。',
      sevenLoopRoles: <String>['澄清', '启动', '稳定', '求证', '系统编排'],
      distinctiveFocus:
          '最关心这个具体行为究竟缺能力、机会还是动机，以及哪一种干预在现实中最可行、可接受和安全。',
      decisionCue:
          '你已经尝试多种思想和技巧却反复错配，真正障碍可能来自多个条件或目标仍然过于抽象。',
      buildsOnSystemIds: <String>[
        'yangming',
        'dewey',
        'gollwitzer',
        'bandura',
        'oettingen',
        'behavioral_activation',
        'maslow',
        'harvard_positive_psychology',
      ],
      relatedSystemIds: <String>[
        'yangming',
        'dewey',
        'gollwitzer',
        'bandura',
        'oettingen',
        'behavioral_activation',
        'maslow',
      ],
      tensions: <String>[
        '行为工程不能决定终极价值、意义和道德方向，有效不等于正当。',
        '诊断只针对当前行为情境，不能变成疾病诊断、人格标签或永久哲学类型。',
      ],
    ),
  ];

  static ZxThinkerGuide? guideForSystem(String systemId) {
    for (final guide in guides) {
      if (guide.systemId == systemId) return guide;
    }
    return null;
  }

  /// Finds an integrated system by either system id or any contained lens id.
  static ZxThinkerGuide? guideFor(String systemOrLensId) {
    for (final guide in guides) {
      if (guide.systemId == systemOrLensId ||
          guide.lensIds.contains(systemOrLensId)) {
        return guide;
      }
    }
    return null;
  }

  static String selectionTokenForLens(String lensId) =>
      guideFor(lensId)?.primaryLensId ?? lensId;

  static Set<String> normalizeSelectionTokens(Iterable<String> ids) => ids
      .map(selectionTokenForLens)
      .where((id) => id.trim().isNotEmpty)
      .toSet();

  static List<ZxThinkerGuide> relatedTo(ZxThinkerGuide guide) => guide
      .relatedSystemIds
      .map(guideForSystem)
      .whereType<ZxThinkerGuide>()
      .toList(growable: false);

  static List<ZxThinkerLens> lensesFor(
    ZxThinkerGuide guide,
    List<ZxThinkerLens> lenses, {
    Set<String> disabledLensIds = const <String>{},
  }) {
    final byId = <String, ZxThinkerLens>{
      for (final lens in lenses) lens.id: lens,
    };
    return guide.lensIds
        .where((id) => !disabledLensIds.contains(id))
        .map((id) => byId[id])
        .whereType<ZxThinkerLens>()
        .toList(growable: false);
  }

  static List<String> validateAgainst(List<ZxThinkerLens> lenses) {
    final issues = <String>[];
    final lensIds = lenses.map((item) => item.id).toSet();
    final coveredLensIds = <String>{};
    final systemIds = <String>{};
    final sequenceBySystem = <String, int>{};

    for (final guide in guides) {
      if (!systemIds.add(guide.systemId)) {
        issues.add('重复思想体系：${guide.systemId}');
      }
      sequenceBySystem[guide.systemId] = guide.sequence;
    }

    for (final guide in guides) {
      if (!guide.lensIds.contains(guide.primaryLensId)) {
        issues.add('${guide.systemId}的代表镜头未包含在本体系');
      }
      for (final lensId in guide.lensIds) {
        if (!lensIds.contains(lensId)) {
          issues.add('${guide.systemId}缺少知识镜头：$lensId');
        }
        if (!coveredLensIds.add(lensId)) {
          issues.add('知识镜头被多个思想体系重复收录：$lensId');
        }
      }
      for (final related in guide.relatedSystemIds) {
        if (!systemIds.contains(related)) {
          issues.add('${guide.systemId}关联了不存在的思想体系：$related');
        }
        if (related == guide.systemId) {
          issues.add('${guide.systemId}不能关联自身');
        }
      }
      for (final parent in guide.buildsOnSystemIds) {
        final parentSequence = sequenceBySystem[parent];
        if (parentSequence == null) {
          issues.add('${guide.systemId}承接了不存在的思想体系：$parent');
        } else if (parentSequence >= guide.sequence) {
          issues.add('${guide.systemId}的承接关系不是向前演化：$parent');
        }
      }
      if (guide.sequence > 1 && guide.buildsOnSystemIds.isEmpty) {
        issues.add('${guide.systemId}缺少前序承接关系');
      }
      if (guide.coreValues.length < 4 ||
          guide.coreIdeas.length < 4 ||
          guide.knowledgeView.trim().isEmpty ||
          guide.actionView.trim().isEmpty ||
          guide.splitDiagnosis.trim().isEmpty ||
          guide.transformationPath.trim().isEmpty ||
          guide.actionFeedback.trim().isEmpty ||
          guide.yangmingConnection.trim().isEmpty ||
          guide.inheritedLimit.trim().isEmpty ||
          guide.qualitativeLeap.trim().isEmpty ||
          guide.synthesisOutcome.trim().isEmpty ||
          guide.workSynthesis.trim().isEmpty ||
          guide.sevenLoopRoles.isEmpty ||
          guide.distinctiveFocus.trim().isEmpty ||
          guide.decisionCue.trim().isEmpty ||
          guide.tensions.isEmpty) {
        issues.add('${guide.systemId}的完整知行体系说明不完整');
      }
    }

    for (final lensId in lensIds) {
      if (!coveredLensIds.contains(lensId)) {
        issues.add('知识镜头尚未归入思想体系：$lensId');
      }
    }
    if (guides.length != 17) {
      issues.add('顶层思想体系应为17套，当前为${guides.length}套');
    }
    if (coveredLensIds.length != lenses.length) {
      issues.add('思想体系未完整覆盖22个机制镜头：'
          '${coveredLensIds.length}/${lenses.length}');
    }
    final expectedSequences =
        List<int>.generate(guides.length, (index) => index + 1);
    final actualSequences = guides.map((item) => item.sequence).toList();
    for (var index = 0; index < expectedSequences.length; index++) {
      if (actualSequences[index] != expectedSequences[index]) {
        issues.add('思想演化顺序不连续：$actualSequences');
        break;
      }
    }
    if (guides.isEmpty || guides.first.systemId != yangmingSystemId) {
      issues.add('思想演化主线必须由王阳明知行合一开始');
    }
    return issues;
  }
}
