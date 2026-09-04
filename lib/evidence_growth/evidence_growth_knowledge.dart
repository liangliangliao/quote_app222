import 'evidence_growth_models.dart';

typedef _Seed = ({
  String title,
  String claim,
  List<String> triggers,
  List<String> operators,
  List<int> pages,
  List<int> lectures,
});

/// KB35 v3.5 的可执行层。PDF 是 Source of Truth；这里保留来源定位、
/// Tal-first 层级、触发、操作符与误用边界，不把模型常识混入公共知识。
class EvidenceGrowthKnowledge {
  EvidenceGrowthKnowledge._();
  static const String kbVersion = '3.5';
  static const String promptVersion = 'eg-p1.0';

  static final List<EvidenceKNode> nodes = <EvidenceKNode>[
    ..._tal('B', GrowthModule.belief, _belief),
    ..._tal('G', GrowthModule.goal, _goal),
    ..._tal('A', GrowthModule.action, _action),
    ..._tal('F', GrowthModule.failure, _failure),
    ..._tal('R', GrowthModule.review, _review),
    ..._tal('C', GrowthModule.change, _change),
    ..._extensions,
  ];

  static List<EvidenceKNode> get talNodes =>
      nodes.where((node) => node.isTal).toList(growable: false);
  static List<EvidenceKNode> get extensionNodes =>
      nodes.where((node) => !node.isTal).toList(growable: false);
  static List<EvidenceKNode> forModule(GrowthModule module) =>
      nodes.where((node) => node.module == module).toList(growable: false);
  static EvidenceKNode? byId(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  static const List<String> defaultCases = <String>[
    '我知道要投简历，但就是没开始，一直在等待动力。',
    '我特别累，三天没睡好，却逼自己继续。',
    '我一直改作品，不敢发给别人看。',
    '我一上床手就自动点开短视频。',
    '目标明确，但今天不知道下一步做什么。',
    '面试失败说明我天生不适合这份职业。',
    '我复盘很多，却都只是感想。',
    '这条路线坚持两年没结果，要继续还是退出？',
    '我要完全像某个电影主角一样生活。',
    '换了很多方法还是反复，可能是系统结构问题。',
    '我总认为一次失败就证明一切。',
    '只要积极思考，坏结果就不会发生吗？',
    '我的目标太多，不知道该舍弃什么。',
    '任务巨大，我希望把第一步缩小。',
    '我很怕被拒绝，所以从不提出请求。',
    '经历积极体验后，我想学会重播它。',
    '我想把一次结果写成下一轮规则。',
    '重要项目开始前，我想检查最可能失败的地方。',
    '每次戴红帽都面试失败，所以一定是帽子导致的。',
    '我想辞职借债，把全部积蓄押在未经验证的项目上。',
  ];
}

List<EvidenceKNode> _tal(String prefix, GrowthModule module, List<_Seed> seeds) =>
    List<EvidenceKNode>.generate(seeds.length, (index) {
      final seed = seeds[index];
      return EvidenceKNode(
        id: 'TAL-$prefix${(index + 1).toString().padLeft(2, '0')}',
        module: module,
        sourceClass: 'K_TAL',
        title: seed.title,
        claim: seed.claim,
        mechanism: seed.claim,
        triggers: seed.triggers,
        contraSignals: const <String>['PANIC_ZONE', 'PROFESSIONAL_BOUNDARY'],
        prerequisites: const <String>['REALITY_CHECK', 'STRETCH_ZONE_CHECK'],
        operators: seed.operators,
        boundaries: const <String>['只用于低风险成长实践；不替代医疗、法律或财务专业判断。'],
        nextNodes: const <String>[],
        evidenceStrength: 'COURSE_CORE',
        displayExcerpt: seed.claim,
        locator: EvidenceSourceLocator(
          document: 'KB35',
          pages: seed.pages,
          lectures: seed.lectures,
        ),
      );
    });

const List<_Seed> _belief = <_Seed>[
  (title: '问题塑造心理现实', claim: '问题决定注意从现实中寻找什么；更好的问题扩大可见资源，但不能取消痛苦事实。', triggers: ['为什么总是我', '问题', '只看见'], operators: ['BELIEF_TO_TESTABLE_HYPOTHESIS'], pages: [66], lectures: [2, 3]),
  (title: '积极思考只是方程的一半', claim: '希望必须与事实、行动和反馈共同存在；只相信而不面对现实不是现实主义乐观。', triggers: ['积极思考', '坏消息', '相信'], operators: ['REALITY_CALIBRATION'], pages: [73], lectures: [5, 7]),
  (title: 'Stockdale 悖论', claim: '成熟信念同时保留最终希望与眼前残酷事实，不以具体日期和单次结果保证成功。', triggers: ['一定成功', '希望', '现实'], operators: ['PROBABILITY_LEDGER'], pages: [73], lectures: [7]),
  (title: '期待改变互动与表现', claim: '期待通过注意、互动、机会和反馈影响表现，但不是控制他人的宇宙遥控器。', triggers: ['期待', '标签', '别人不行'], operators: ['CONTEXT_REDESIGN'], pages: [66, 73], lectures: [5, 6]),
  (title: '自我效能来自现实应对', claim: '可靠信心来自进入伸展区、完成动作和失败后恢复所形成的掌握证据。', triggers: ['没信心', '做不到', '自信'], operators: ['SAFE_EXPOSURE', 'START_5_MIN'], pages: [66, 94], lectures: [6, 7, 10]),
  (title: '行动创造信念', claim: '不必等到完全相信自己才行动；小行动会产生新经验并更新自我知觉。', triggers: ['等相信', '身份限制', '一直这样'], operators: ['START_5_MIN'], pages: [77, 97], lectures: [10, 11, 14]),
  (title: '高期望放在正确对象上', claim: '把高期望放在成长、应对、学习与恢复能力，而非保证单次外部结果。', triggers: ['高期望', '结果保证', '自尊基准'], operators: ['PROBABILITY_LEDGER'], pages: [78, 79], lectures: [7]),
  (title: '允许自己成为人', claim: '接受真实情绪能释放资源；压抑并不会令痛苦消失。', triggers: ['不该难过', '压抑', '情绪'], operators: ['PERMISSION_TO_BE_HUMAN'], pages: [68, 69], lectures: [3]),
  (title: '解释不是事实', claim: '同一事件可以有多种解释，解释应当接受现实证据校准。', triggers: ['说明我', '一定是', '解释'], operators: ['FACT_INFERENCE_SPLIT'], pages: [70, 71], lectures: [4]),
  (title: '放大、缩小与隧道视野', claim: '压力下注意会放大威胁、缩小资源并过度归纳，需要重新看见完整事实。', triggers: ['放大', '缩小', '总是', '从来'], operators: ['ALTERNATIVE_EVIDENCE'], pages: [71, 72], lectures: [4]),
  (title: '成长心态需要策略证据', claim: '能力可发展不等于只要努力；必须结合策略、反馈与求助。', triggers: ['天赋', '能力固定', '努力'], operators: ['TESTABLE_GROWTH_RULE'], pages: [75, 76], lectures: [7]),
  (title: '独立型自尊', claim: '稳定自尊更多来自自我认同的价值与实践，不完全依赖比较和外界证明。', triggers: ['证明自己', '比较', '依赖性自尊'], operators: ['SELF_CONCORDANCE_CHECK'], pages: [79, 80], lectures: [18]),
];

const List<_Seed> _goal = <_Seed>[
  (title: '自我和谐目标', claim: '目标应与真正重视的价值和兴趣协调，而非只为取悦或证明。', triggers: ['目标', '想要', '价值'], operators: ['SELF_CONCORDANCE_CHECK'], pages: [82, 83], lectures: [8]),
  (title: '具体目标释放注意', claim: '具体目标让注意从反复权衡转向路径发现，但仍须接受现实修正。', triggers: ['不具体', '方向', '计划'], operators: ['GAP_OPERATOR'], pages: [84], lectures: [8]),
  (title: '目标不是幸福终点', claim: '抵达目标只带来短暂变化；价值在追求过程、意义与当下体验的协调。', triggers: ['达到就幸福', '终点', '空虚'], operators: ['GOAL_ROLE_CHECK'], pages: [85], lectures: [8]),
  (title: '背包过墙式承诺', claim: '适度公开承诺可以改变现实结构，但必须保留安全、尊严与下一轮资格。', triggers: ['承诺', '置于线上', '退路'], operators: ['COMMITMENT_LADDER'], pages: [88, 94], lectures: [8]),
  (title: '分阶段而非压倒', claim: '远目标应转化成当前阶段与可见下一步，避免巨大清单替代行动。', triggers: ['下一步', '巨大', '不知道今天'], operators: ['GAP_OPERATOR', 'DIVIDE_NEXT_STEP'], pages: [89, 90], lectures: [8]),
  (title: '必要条件与充分条件', claim: '先确认下一动作所依赖的必要条件，别把愿望误当路径。', triggers: ['前提', '条件', '准备'], operators: ['PREREQUISITE_CHECK'], pages: [90, 91], lectures: [8]),
  (title: '目标差距提供反馈', claim: '比较当前状态与目标状态，找到最大可改变差距并产生一个动作。', triggers: ['差距', '进展', '离目标'], operators: ['GAP_OPERATOR'], pages: [91, 92], lectures: [8]),
  (title: '选择意味着舍弃', claim: '真正优先级必须同时写出暂不做什么，保护注意和资源。', triggers: ['目标太多', '优先', '舍弃'], operators: ['PRIORITY_CUT'], pages: [92], lectures: [8]),
  (title: '恢复是目标系统的一部分', claim: '恢复不是行动的对立面；耗竭时恢复是重新进入任务的前提。', triggers: ['累', '耗竭', '没睡'], operators: ['RECOVER'], pages: [93, 94], lectures: [10]),
  (title: 'Stretch 而非 Panic', claim: '有效目标提高挑战但不越过恐慌区；过强暴露会破坏学习。', triggers: ['害怕', '恐慌', '挑战'], operators: ['EXPOSURE_LADDER'], pages: [94, 95], lectures: [10]),
  (title: '目标需要现实窗口', claim: '为假设设定足以产生反馈的观察窗口，过早和无限等待都不可检验。', triggers: ['多久', '没结果', '观察'], operators: ['OBSERVATION_WINDOW'], pages: [95], lectures: [8]),
  (title: '继续、调整或退出', claim: '忠于学习过程不等于忠于昨天的方法；证据允许继续、修改或停止。', triggers: ['坚持', '退出', '没结果'], operators: ['ACT_ADJUST_EXIT'], pages: [95, 158, 191], lectures: [8, 23]),
];

const List<_Seed> _action = <_Seed>[
  (title: '五分钟起飞', claim: '动机不足时先做五分钟可见动作；行动常常先于动机。', triggers: ['没开始', '拖延', '等待动力'], operators: ['START_5_MIN'], pages: [97, 98], lectures: [11]),
  (title: '先检查恢复', claim: '明显睡眠不足、疾病或耗竭时先恢复，再判断是否仍是启动摩擦。', triggers: ['三天没睡', '精疲力尽', '耗竭'], operators: ['RECOVER'], pages: [99], lectures: [10]),
  (title: '行为改变情绪', claim: '身体和行为进入不同状态，会反向影响感受和认知。', triggers: ['情绪不好', '等状态', '身体'], operators: ['BODY_FIRST'], pages: [100], lectures: [11]),
  (title: '安全现实暴露', claim: '把足够好的版本给一位安全对象，获取真实反馈而非无限准备。', triggers: ['不敢发', '怕拒绝', '被看见'], operators: ['SAFE_EXPOSURE'], pages: [101, 152], lectures: [12, 21]),
  (title: '把动作缩到可进入', claim: '当第一步仍未发生，继续缩小动作直至能留下现实痕迹。', triggers: ['任务太大', '第一步', '进入'], operators: ['DIVIDE_NEXT_STEP'], pages: [102], lectures: [11]),
  (title: '仪式减少决策摩擦', claim: '稳定时间、线索与顺序让行动少依赖当下意志力。', triggers: ['仪式', '固定时间', '总忘记'], operators: ['CONTEXT_REDESIGN'], pages: [104, 105], lectures: [11]),
  (title: '环境比责备更可改', claim: '调整线索、摩擦与工具位置，比给身份贴标签更可检验。', triggers: ['环境', '自动', '习惯'], operators: ['CONTEXT_REDESIGN'], pages: [106], lectures: [11]),
  (title: '立即建立可见痕迹', claim: '行动应产生提交、发送、到场或作品片段等现实痕迹。', triggers: ['执行', '提交', '投递'], operators: ['VISIBLE_TRACE'], pages: [108], lectures: [11]),
  (title: '渐进暴露阶梯', claim: '从伸展区最小层级开始，记录预测痛苦、实际痛苦与恢复时间。', triggers: ['不敢', '焦虑', '暴露'], operators: ['EXPOSURE_LADDER'], pages: [110, 152], lectures: [12, 21]),
  (title: '过程优先于形象', claim: '关注训练和反馈，而不是看起来像成功者。', triggers: ['形象', '别人看', '证明'], operators: ['PROCESS_ACTION'], pages: [112, 114], lectures: [12]),
  (title: '恢复后重新进入', claim: '恢复需要明确结束点，结束后用极小动作重新进入原任务。', triggers: ['恢复', '回到', '重新开始'], operators: ['RECOVER_REENTER'], pages: [116], lectures: [10]),
  (title: '正确行动也需要边界', claim: '行动强度不能破坏身体、关系安全或下一轮资格。', triggers: ['拼命', '受伤', '牺牲一切'], operators: ['RISK_DOWNSCALE'], pages: [114, 118], lectures: [12]),
  (title: '榜样只迁移机制', claim: '提取榜样的一个行为、所需条件和自身差异，不复制整个人生。', triggers: ['榜样', '电影主角', '完全像'], operators: ['ROLE_MODEL_TRANSFER'], pages: [114, 123], lectures: [12, 17]),
];

const List<_Seed> _failure = <_Seed>[
  (title: '学习失败而非身份失败', claim: '结果说明本轮策略与情境，不直接证明“我不行”。', triggers: ['失败说明', '我不行', '不适合'], operators: ['FAILURE_REFRAME'], pages: [129], lectures: [13]),
  (title: '完美主义拒绝现实', claim: '完美主义常以无限准备避免评价；要让 80% 版本安全进入现实。', triggers: ['一直改', '完美', '不敢发'], operators: ['SAFE_EXPOSURE'], pages: [131, 132], lectures: [13]),
  (title: '优秀主义允许弯路', claim: '健康追求高标准同时允许错误、反馈、休息与不完美路径。', triggers: ['高标准', '错误', '弯路'], operators: ['OPTIMALIST_CHECK'], pages: [133], lectures: [13]),
  (title: '过程与身份分开', claim: '一次拒绝是事件；把事件升级成稳定身份会阻断下一轮学习。', triggers: ['拒绝', '否定自己', '身份'], operators: ['FACT_INFERENCE_SPLIT'], pages: [134], lectures: [13]),
  (title: '允许痛苦存在', claim: '失败后的痛苦不需立刻消除；先允许，再从事实中提取信息。', triggers: ['难受', '羞耻', '痛苦'], operators: ['PERMISSION_TO_BE_HUMAN', 'FAILURE_REFRAME'], pages: [135], lectures: [13]),
  (title: '失败需要分类', claim: '区分过早观察、聪明失败、基本失败、复杂失败和毁灭风险，不能一概浪漫化。', triggers: ['失败类型', '为什么失败', '分类'], operators: ['FAILURE_CLASSIFY'], pages: [136, 175], lectures: [13]),
  (title: '反复不等于不可改变', claim: '复发是情境、线索与规则的新样本，应改变一个条件而非全盘否定。', triggers: ['又失败', '复发', '反复'], operators: ['FAILURE_REFRAME', 'CONTEXT_REDESIGN'], pages: [137], lectures: [13]),
  (title: '自我关怀保持责任', claim: '善待自己不是取消责任，而是减少羞辱以恢复学习能力。', triggers: ['责骂自己', '自我关怀', '羞辱'], operators: ['COMPASSIONATE_ACCOUNTABILITY'], pages: [138], lectures: [13]),
  (title: '害怕评价时缩小暴露', claim: '暴露应足够真实但仍可恢复，不把人推入 Panic。', triggers: ['评价', '被看见', '恐慌'], operators: ['EXPOSURE_LADDER'], pages: [139, 152], lectures: [13, 21]),
  (title: '失败后先保存事实', claim: '先记录做了什么、发生什么、何处停止，再进行解释。', triggers: ['失败后', '事实', '结果'], operators: ['FACT_INFERENCE_SPLIT'], pages: [140], lectures: [13]),
  (title: '恢复时间也是证据', claim: '不仅看是否失败，也看恢复和重新进入所需时间。', triggers: ['恢复时间', '走不出来', '回到行动'], operators: ['RECOVERY_MEASURE'], pages: [141], lectures: [13]),
  (title: '反完美主义许可', claim: '用可控的不完美练习打破“必须无误才安全”的规则。', triggers: ['不能出错', '必须完美', '瑕疵'], operators: ['SAFE_IMPERFECTION'], pages: [142, 143], lectures: [13]),
];

const List<_Seed> _review = <_Seed>[
  (title: 'Time-In 主动反思', claim: '反思把经历转为学习，但必须连接事实和下一动作。', triggers: ['反思', '复盘', '经历'], operators: ['PDSA_REVIEW'], pages: [146], lectures: [14]),
  (title: 'Replay 重播积极经验', claim: '重播具体情境、身体、行为和意义，可增加未来调用线索。', triggers: ['重播', '积极体验', '复现'], operators: ['POSITIVE_REPLAY'], pages: [147, 148], lectures: [14]),
  (title: '写下原预测', claim: '复盘必须保留事前预测，避免事后聪明和记忆改写。', triggers: ['预测', '事后', '准确'], operators: ['PREDICTION_LEDGER'], pages: [149], lectures: [14]),
  (title: '事实与解释分栏', claim: '先写可观察事实，再写解释、情绪和判断，防止推断伪装成事实。', triggers: ['事实', '解释', '判断'], operators: ['FACT_INFERENCE_SPLIT'], pages: [150], lectures: [14]),
  (title: '预测误差产生学习', claim: '比较原预测与实际差异，提取让下一轮更准的一条规则。', triggers: ['差异', '实际', '预测误差'], operators: ['PDSA_REVIEW'], pages: [151], lectures: [14]),
  (title: '反刍不是复盘', claim: '重复回放羞辱而没有新事实与新动作是反刍，应先停下和恢复。', triggers: ['反刍', '回放', '停不下来'], operators: ['STOP_RUMINATION'], pages: [152, 153], lectures: [14]),
  (title: '只改变一个变量', claim: '下一轮默认只改一个关键变量，保留可比较性。', triggers: ['下一轮', '改变什么', '全部改'], operators: ['ONE_VARIABLE_CHANGE'], pages: [154], lectures: [14]),
  (title: '观察过早不判失败', claim: '结果窗口未结束时标记继续观察，而不是提前证实悲观结论。', triggers: ['还没结果', '太早', '等待'], operators: ['OBSERVATION_WINDOW'], pages: [155], lectures: [14]),
  (title: '积极结果也要审计', claim: '成功后同样检查偶然性、条件与可重复性，不只庆祝。', triggers: ['成功', '有效', '运气'], operators: ['POSITIVE_RESULT_AUDIT'], pages: [156], lectures: [14]),
  (title: '保存意外', claim: '最意外之处常暴露错误假设，应独立记录。', triggers: ['意外', '没想到', '出乎意料'], operators: ['SURPRISE_CAPTURE'], pages: [156, 157], lectures: [14]),
  (title: '从感想到规则更新', claim: '有效复盘以新的可检验规则和动作结束，而不是停在长篇感想。', triggers: ['只是感想', '没有变化', '复盘无效'], operators: ['PDSA_REVIEW'], pages: [157], lectures: [14]),
  (title: '忠于学习过程', claim: '证据反对旧方法时，修改或停止比僵化坚持更忠于成长。', triggers: ['坚持两年', '该退出', '旧方法'], operators: ['ACT_ADJUST_EXIT'], pages: [158, 191], lectures: [14, 23]),
];

const List<_Seed> _change = <_Seed>[
  (title: '改变是闭环不是宣言', claim: '新信念必须进入目标、行动、结果和复盘，才能成为稳定改变。', triggers: ['想改变', '宣言', '旧模式'], operators: ['NEXT_TRIAL'], pages: [160], lectures: [11, 14]),
  (title: '仪式化巩固行为', claim: '把价值转为固定线索、时间和最小动作，让重复减少决策消耗。', triggers: ['仪式', '坚持不住', '日复一日'], operators: ['CONTEXT_REDESIGN'], pages: [162], lectures: [11]),
  (title: '神经可塑性需要重复', claim: '理解一次不会自动改变；适量重复和反馈让新路径更易调用。', triggers: ['知道但做不到', '重复', '习惯化'], operators: ['REPETITION_PLAN'], pages: [164], lectures: [11]),
  (title: '环境支持胜过纯意志', claim: '让正确行为少一步、旧行为多一步，并观察真实频率变化。', triggers: ['环境', '意志力', '自动'], operators: ['CONTEXT_REDESIGN'], pages: [166], lectures: [11]),
  (title: '恢复旧的积极路径', claim: '从旧经验提取情境、线索、行为和支持条件，再做最小复现。', triggers: ['以前可以', '回到原来', '复现'], operators: ['POSITIVE_REPLAY'], pages: [168], lectures: [14]),
  (title: '从例外寻找可复制条件', claim: '寻找问题没有发生的例外时刻，提取可迁移条件而非神化状态。', triggers: ['例外', '有一次', '为什么那次'], operators: ['EXCEPTION_REPLAY'], pages: [169], lectures: [14]),
  (title: '改变一层而非全部', claim: '参数、规则、信息与目标应分层检查，每轮只实验一层。', triggers: ['换很多方法', '还是反复', '系统结构'], operators: ['SYSTEM_SCAN'], pages: [170, 171], lectures: [11, 14]),
  (title: '个人证据重排', claim: '公共知识不因个人一次无效而改变；只更新该情境下的个人适配度。', triggers: ['对我无效', '个性化', '适合我'], operators: ['PERSONAL_FIT_UPDATE'], pages: [172], lectures: [14]),
  (title: '小胜利形成身份证据', claim: '重复可观察行动让新身份有现实证据，而不是靠口号。', triggers: ['身份改变', '小胜利', '成为'], operators: ['VISIBLE_TRACE'], pages: [173], lectures: [11]),
  (title: '心理安全支持学习', claim: '可承认错误、提问和求助的环境更利于从失败中学习。', triggers: ['不敢承认', '求助', '团队安全'], operators: ['SAFE_EXPOSURE'], pages: [175], lectures: [13]),
  (title: '复杂失败检查系统', claim: '多因素互动造成的失败不能只责怪一个人，应选择一个可检验系统变量。', triggers: ['复杂失败', '多人', '系统'], operators: ['SYSTEM_SCAN'], pages: [175, 176], lectures: [13]),
  (title: '新规则必须可证伪', claim: '规则要说明何种新证据会让它上调、下调或关闭。', triggers: ['规则更新', '证伪', '新证据'], operators: ['PROBABILITY_LEDGER'], pages: [185, 191], lectures: [14]),
];

EvidenceKNode _ext(String id, GrowthModule module, String source, String title,
        String claim, List<String> triggers, List<String> operators, List<int> pages) =>
    EvidenceKNode(
      id: id,
      module: module,
      sourceClass: source,
      title: title,
      claim: claim,
      mechanism: claim,
      triggers: triggers,
      contraSignals: const <String>[],
      prerequisites: const <String>['TAL_MECHANISM_GAP'],
      operators: operators,
      boundaries: const <String>['仅在 Tal 主干存在明确机制缺口时补位，不得越级成为默认答案。'],
      nextNodes: const <String>[],
      evidenceStrength: source == 'K_EXT1' ? 'EXTERNAL_RESEARCH' : 'EXTERNAL_ADVANCED',
      displayExcerpt: claim,
      locator: EvidenceSourceLocator(document: 'KB35', pages: pages),
    );

final List<EvidenceKNode> _extensions = <EvidenceKNode>[
  _ext('EXT1-B01', GrowthModule.belief, 'K_EXT1', 'Bandura 自我效能', '掌握经验、替代经验与反馈可补充解释信心如何形成。', ['自我效能', '掌握经验'], ['SAFE_EXPOSURE'], [179]),
  _ext('EXT1-B02', GrowthModule.belief, 'K_EXT1', 'Dweck 成长心态', '用策略、反馈和求助补充“能力可发展”，不等于努力保证成功。', ['成长心态', '能力固定'], ['TESTABLE_GROWTH_RULE'], [178]),
  _ext('EXT1-B03', GrowthModule.belief, 'K_EXT1', 'Beck 认知校准', '识别过度概括、灾难化和选择性注意，再回到可观察证据。', ['灾难化', '过度概括'], ['ALTERNATIVE_EVIDENCE'], [179]),
  _ext('EXT2-B01', GrowthModule.belief, 'K_EXT2', 'Popper 可证伪边界', '信念应写出什么证据会使它被修改或关闭。', ['证伪', '反证'], ['PROBABILITY_LEDGER'], [184]),
  _ext('EXT2-B02', GrowthModule.belief, 'K_EXT2', 'Pearl 因果层级', '观察到关联不等于干预因果；小型个人试验只能谨慎升级证据。', ['所以一定', '造成的', '因果'], ['CAUSAL_LEVEL_CHECK'], [185, 186]),
  _ext('EXT2-B03', GrowthModule.belief, 'K_EXT2', 'Schopenhauer 概念接地', '抽象概念必须回到直观经验与现实根据，避免概念闭环。', ['抽象', '凭什么', '概念'], ['FACT_INFERENCE_SPLIT'], [187]),
  _ext('EXT1-G01', GrowthModule.goal, 'K_EXT1', 'Deci/Ryan 自主目标', '检查目标是否来自自主、胜任与联结需要。', ['别人要求', '自主', '内在动机'], ['SELF_CONCORDANCE_CHECK'], [180]),
  _ext('EXT1-G02', GrowthModule.goal, 'K_EXT1', 'Carver/Scheier 差距反馈', '目标调节依靠当前与目标的差距及进展速度。', ['差距', '进展速度'], ['GAP_OPERATOR'], [181]),
  _ext('EXT1-G03', GrowthModule.goal, 'K_EXT1', 'Simon 有限理性', '在有限信息与资源下选择足够好的下一步，而非无限求最优。', ['最优', '选择困难'], ['DIVIDE_NEXT_STEP'], [181]),
  _ext('EXT2-G01', GrowthModule.goal, 'K_EXT2', 'Goodhart 单指标边界', '指标成为唯一目标时会扭曲真实价值，需保留多维现实检查。', ['唯一指标', '只看数字'], ['GOAL_ROLE_CHECK'], [188]),
  _ext('EXT2-G02', GrowthModule.goal, 'K_EXT2', '机会成本', '优先级同时意味着明确暂不投入的路线。', ['机会成本', '目标太多'], ['PRIORITY_CUT'], [188]),
  _ext('EXT1-A01', GrowthModule.action, 'K_EXT1', 'Gollwitzer 执行意图', '把情境线索写成“如果发生 X，我就做 Y”。', ['如果就', '总忘记'], ['CONTEXT_REDESIGN'], [182]),
  _ext('EXT1-A02', GrowthModule.action, 'K_EXT1', 'Fogg 最小行为', '同时缩小动作并明确提示，让启动不依赖高动机。', ['太大', '最小行为'], ['START_5_MIN'], [182]),
  _ext('EXT2-A01', GrowthModule.action, 'K_EXT2', 'Wendy Wood 情境习惯', '自动行为由稳定情境线索触发时，应只改一个线索或摩擦。', ['自动', '一上床', '离开环境'], ['CONTEXT_REDESIGN'], [189]),
  _ext('EXT2-A02', GrowthModule.action, 'K_EXT2', '暴露学习', '渐进暴露关注新安全学习，不追求立即消除全部焦虑。', ['暴露', '焦虑', '恐惧'], ['EXPOSURE_LADDER'], [189]),
  _ext('EXT2-A03', GrowthModule.action, 'K_EXT2', '机制迁移', '榜样只能迁移可观察行为机制，并检查起点与条件差异。', ['榜样', '完全像', '电影主角'], ['ROLE_MODEL_TRANSFER'], [186]),
  _ext('EXT1-F01', GrowthModule.failure, 'K_EXT1', 'Dweck 失败信息', '失败可提供策略和学习信息，但不能自动保证成长。', ['失败说明', '天生'], ['FAILURE_REFRAME'], [178]),
  _ext('EXT1-F02', GrowthModule.failure, 'K_EXT1', 'Edmondson 失败分类', '区分可预防、复杂与聪明失败，决定修流程、查系统或继续实验。', ['失败类型', '复杂失败'], ['FAILURE_CLASSIFY'], [175]),
  _ext('EXT2-F01', GrowthModule.failure, 'K_EXT2', 'Hewitt/Flett 完美主义', '当形象评价信号明确时，区分自我导向、他人导向与社会规定型完美主义。', ['怕他们发现', '评价', '一直改'], ['SAFE_EXPOSURE'], [189, 190]),
  _ext('EXT2-F02', GrowthModule.failure, 'K_EXT2', 'Taleb Ruin Gate', '不允许单次试验消灭下一轮资格；破产、不可逆伤害和极端尾部风险必须硬拦截。', ['全部积蓄', '借债', '没有退路'], ['ACT_ADJUST_EXIT'], [190, 195]),
  _ext('EXT2-F03', GrowthModule.failure, 'K_EXT2', '自我关怀边界', '减少羞辱同时保留事实、责任与下一行动。', ['羞辱自己', '自我关怀'], ['COMPASSIONATE_ACCOUNTABILITY'], [180]),
  _ext('EXT1-R01', GrowthModule.review, 'K_EXT1', 'Deming PDSA', '用计划、行动、研究、调整把复盘连接到下一轮变量。', ['只是感想', '预测和实际'], ['PDSA_REVIEW'], [183]),
  _ext('EXT1-R02', GrowthModule.review, 'K_EXT1', 'Klein Premortem', '高重要项目开始前限时预想失败原因，只处理概率乘损失最高的一项。', ['最可能失败', '重要项目'], ['PREMORTEM'], [183]),
  _ext('EXT2-R01', GrowthModule.review, 'K_EXT2', '贝叶斯式概率更新', '依据新证据调整概率，而不是用一次结果把概率改成零或一。', ['概率', '更新信念'], ['PROBABILITY_LEDGER'], [184]),
  _ext('EXT2-R02', GrowthModule.review, 'K_EXT2', '预测完整性', '原预测必须锁定；复盘时不得改写成更接近结果的版本。', ['事后改写', '预测准确'], ['PREDICTION_LEDGER'], [184]),
  _ext('EXT2-R03', GrowthModule.review, 'K_EXT2', 'Argyris 理论在用', '比较口头相信的规则与行为实际遵守的规则。', ['嘴上相信', '实际行为'], ['THEORY_IN_USE_CHECK'], [192]),
  _ext('EXT1-C01', GrowthModule.change, 'K_EXT1', 'Prochaska 改变阶段', '准备、行动和维持阶段需要不同尺度的下一步。', ['改变阶段', '准备好'], ['NEXT_TRIAL'], [181]),
  _ext('EXT1-C02', GrowthModule.change, 'K_EXT1', '心理安全', '学习环境需要允许承认错误、提问和求助。', ['团队', '不敢承认'], ['SAFE_EXPOSURE'], [175]),
  _ext('EXT2-C01', GrowthModule.change, 'K_EXT2', 'Meadows 系统杠杆', '反复换参数无效时，检查信息、规则和目标层，但每轮只实验一层。', ['换很多方法', '系统结构', '还是反复'], ['SYSTEM_SCAN'], [193]),
  _ext('EXT2-C02', GrowthModule.change, 'K_EXT2', '复杂适应边界', '多变量系统不能由一次小试验宣布普遍规律。', ['多因素', '复杂系统'], ['SYSTEM_SCAN'], [193]),
  _ext('EXT2-C03', GrowthModule.change, 'K_EXT2', '个人适配重排', '个人结果只更新本人、该情境与节点的适配度，不污染公共知识。', ['对我无效', '个人证据'], ['PERSONAL_FIT_UPDATE'], [194]),
];
