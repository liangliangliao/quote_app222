/// Frozen V5 product contract for the Schopenhauer epistemological core.
///
/// The strategist uses this catalog as its L0 operating system. It deliberately
/// distinguishes Schopenhauer's source concepts from product mechanisms that
/// operationalize those concepts. Product terms such as `epistemic debt` are
/// therefore visible and useful without being misrepresented as quotations or
/// original terminology.
class XiangjiSchopenhauerCoreConcept {
  const XiangjiSchopenhauerCoreConcept({
    required this.id,
    required this.displayName,
    required this.originalTerm,
    required this.category,
    required this.conceptKind,
    required this.definition,
    required this.operationalRule,
    required this.featureBindings,
    required this.relatedRuleIds,
    required this.sourceLocator,
    required this.passageIds,
  });

  final String id;
  final String displayName;
  final String originalTerm;
  final String category;

  /// Either an original/core concept or an explicitly labelled product
  /// operationalization derived from it.
  final String conceptKind;
  final String definition;
  final String operationalRule;
  final List<String> featureBindings;
  final List<String> relatedRuleIds;
  final String sourceLocator;
  final List<String> passageIds;

  bool get isProductOperationalization => conceptKind.startsWith('V5');

  String get nodeType => isProductOperationalization
      ? 'schopenhauer_product_operationalization'
      : 'schopenhauer_core_concept';
}

class XiangjiSchopenhauerCoreCatalog {
  const XiangjiSchopenhauerCoreCatalog._();

  static const String sourceId = 'XF-K0-SCHOPENHAUER';
  static const String version = 'V6.1-Rev5.2-Schopenhauer-Core-V5.0';
  static const String productContract = '《向己·未来导师 V5.0》旧版产品方案';
  static const String frozenArchitecture =
      '经验世界 I → 认识根据 G → 抽象反思世界 C → 问题求解 → 计划行动 → 新经验世界 I′ → 修订旧认识';

  static const List<String> layerArchitecture = <String>[
    'L0 叔本华认识论操作系统：决定什么可以算作认识',
    'L1 形式化问题求解：把目标、差距、子目标、算子与验算连成闭环',
    'L2 多思想家行动方法：只能在 L0 边界内提供可比较办法',
    'L3 个人经验科学：用长期现实结果修订个人概念与规则',
  ];

  static const List<XiangjiSchopenhauerCoreConcept> entries =
      <XiangjiSchopenhauerCoreConcept>[
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-001',
      displayName: '经验世界（世界 A / I）',
      originalTerm: '直观表象；世界作为表象',
      category: '世界与认识起点',
      conceptKind: '叔本华原典核心',
      definition: '外部事件、实际言行、身体变化、时间地点、数字、文件与行动结果，构成用户直接面对的经验世界。',
      operationalRule: '原始现实必须先按自身身份保存；AI 标签、解释或计划不能覆盖它。',
      featureBindings: <String>[
        'RawEvent / Experience 原始记录',
        '“经验世界 I”页面',
        '事实、身体与真实结果分层',
      ],
      relatedRuleIds: <String>['K0-RULE-001', 'K0-RULE-002', 'SCK-002'],
      sourceLocator: 'V5.0「世界 A：经验世界」；《作为意志和表象的世界》第一篇 §9',
      passageIds: <String>['XF-K0-PASSAGE-09'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-002',
      displayName: '抽象反思世界（世界 B / C）',
      originalTerm: '抽象表象与反省认识',
      category: '世界与认识起点',
      conceptKind: '叔本华原典核心',
      definition: '概念、语言、判断、解释、假设、规则、目标、预测与计划属于抽象反思世界，而不是新增的外部事实。',
      operationalRule: '所有抽象产物都必须标明类型、版本、来源和可修订状态。',
      featureBindings: <String>[
        'Claim / Concept / Prediction / Plan 分层',
        '“概念世界 C”页面',
        'AI 推断与用户解释身份标记',
      ],
      relatedRuleIds: <String>['K0-RULE-002', 'K0-RULE-004', 'SCK-001'],
      sourceLocator: 'V5.0「世界 B：抽象反思世界」；《作为意志和表象的世界》第一篇 §9',
      passageIds: <String>['XF-K0-PASSAGE-09'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-003',
      displayName: '概念是“表象的表象”',
      originalTerm: 'Vorstellungen von Vorstellungen',
      category: '世界与认识起点',
      conceptKind: '叔本华原典核心',
      definition: '概念是对既有表象的抽象压缩，能组织经验，但不能因此获得独立于经验的新事实地位。',
      operationalRule: '每个高影响概念都要能回到支持它的实例，并保留未被概念覆盖的材料。',
      featureBindings: <String>[
        '经验—概念双图',
        '概念版本与支持实例',
        '事实 / 解释分层卡',
      ],
      relatedRuleIds: <String>['K0-RULE-004', 'SCK-006', 'SCK-013'],
      sourceLocator: 'V5.0「概念是表象的表象」；《作为意志和表象的世界》第一篇 §9',
      passageIds: <String>['XF-K0-PASSAGE-09'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-004',
      displayName: '直观与概念根本不同',
      originalTerm: '直观与概念 toto genere 不同',
      category: '世界与认识起点',
      conceptKind: '叔本华原典核心',
      definition: '直接经验与抽象概念不是清晰度不同的同一种东西；抽象概念不必被强行变成画面，直觉也不应被过早标签化。',
      operationalRule: '抽象概念用可观察判据落地；尚未概念化的直觉按原貌暂存。',
      featureBindings: <String>[
        '可观察判据',
        '未概念化直觉箱',
        '“我不知道”保守侦察',
      ],
      relatedRuleIds: <String>['K0-RULE-019', 'SCK-012', 'CEL-008'],
      sourceLocator: 'V5.0「概念与直观 toto genere 不同」；《作为意志和表象的世界》第一篇相关论述',
      passageIds: <String>['XF-K0-PASSAGE-09'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-005',
      displayName: '认识根据（Grounding）',
      originalTerm: 'Erkenntnisgrund（认识根据）',
      category: '根据与认识债务',
      conceptKind: '叔本华原典核心',
      definition: '一个判断凭什么成立，必须与该判断说了什么分开记录；重要判断需要可追溯的认识根据。',
      operationalRule: '关键判断递归追溯到经验、证据或明确可靠来源；没有根据时只可保持未决。',
      featureBindings: <String>[
        'GroundingRelation 根据图',
        '关键判断根据审计',
        '四层“为什么这样做”',
      ],
      relatedRuleIds: <String>['K0-RULE-005', 'SCK-007', 'CEL-006'],
      sourceLocator: 'V5.0「认识根据」；《作为意志和表象的世界》第一篇 §§9、15',
      passageIds: <String>['XF-K0-PASSAGE-09', 'XF-K0-PASSAGE-15'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-006',
      displayName: '根据链：泉水—水渠',
      originalTerm: '直接认识与间接认识的根据关系',
      category: '根据与认识债务',
      conceptKind: '叔本华原典核心',
      definition: '间接判断像水渠，必须最终回到直接经验或可靠材料这眼泉水；更长的水渠不会自动制造水源。',
      operationalRule: '展示根据链、最弱前提和最终现实出口，不以引用另一个概念结束追溯。',
      featureBindings: <String>[
        '泉水—水渠根据探查',
        '递归 Ground Explorer',
        '最弱前提显示',
      ],
      relatedRuleIds: <String>['K0-RULE-005', 'K0-RULE-006', 'K0-RULE-016'],
      sourceLocator: 'V5.0「认识根据 / 泉水—水渠」；《作为意志和表象的世界》第一篇 §§9、15',
      passageIds: <String>['XF-K0-PASSAGE-09', 'XF-K0-PASSAGE-15'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-007',
      displayName: '无经验出口的概念循环',
      originalTerm: '由认识根据要求推导的产品检测机制',
      category: '根据与认识债务',
      conceptKind: 'V5 产品操作化（不冒充原典术语）',
      definition: '概念甲支持概念乙、概念乙又支持概念甲，但整条链没有回到经验或证据时，循环不能算作支持。',
      operationalRule: '检测概念支持环并取消其根据权重，转为补充现实材料的任务。',
      featureBindings: <String>[
        'ConceptCycle 检测器',
        '循环支持失效',
        '黄色 / 橙色认识警报',
      ],
      relatedRuleIds: <String>['K0-RULE-006', 'SCK-007', 'CEL-006'],
      sourceLocator: 'V5.0「概念循环检测器」；理论根据见第一篇 §§9、15',
      passageIds: <String>['XF-K0-PASSAGE-09', 'XF-K0-PASSAGE-15'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-008',
      displayName: '认识债务',
      originalTerm: '由根据不足推导的产品状态',
      category: '根据与认识债务',
      conceptKind: 'V5 产品操作化（不冒充原典术语）',
      definition: '会显著改变决策、但当前仍缺少现实根据的未知，被登记为认识债务而非被模糊语言掩盖。',
      operationalRule: '优先把影响最大的认识债务转为信息子目标；债务未清时降低不可逆承诺。',
      featureBindings: <String>[
        'EpistemicDebt 账本',
        '信息子目标 / EVSI 排序',
        '风险与承诺限制器',
      ],
      relatedRuleIds: <String>['K0-RULE-005', 'K0-RULE-RISK', 'SCK-007'],
      sourceLocator: 'V5.0「认识债务」；理论根据见第一篇 §§9、15',
      passageIds: <String>['XF-K0-PASSAGE-09', 'XF-K0-PASSAGE-15'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-009',
      displayName: '根据率与认识等级',
      originalTerm: '由认识根据强弱推导的产品量表',
      category: '根据与认识债务',
      conceptKind: 'V5 产品操作化（不冒充原典术语）',
      definition: '主要判断有多少能回到现实根据，决定当前可以多确定地表达，而不是决定该判断必然真或假。',
      operationalRule: '展示根据覆盖率和认识状态；根据不足时说“尚不足以确定”，不武断判假。',
      featureBindings: <String>[
        'Grounding rate',
        'SUPPORTED / PROVISIONAL / UNRESOLVED 状态',
        '行动承诺随根据强度调整',
      ],
      relatedRuleIds: <String>['K0-RULE-005', 'K0-RULE-015', 'CEL-006'],
      sourceLocator: 'V5.0「主要判断根据率」；理论根据见第一篇 §§9、15',
      passageIds: <String>['XF-K0-PASSAGE-09', 'XF-K0-PASSAGE-15'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-010',
      displayName: '镶嵌画与连续绘画',
      originalTerm: '概念如镶嵌画，直观如连续绘画',
      category: '概念、判断与直觉',
      conceptKind: '叔本华原典核心',
      definition: '概念以离散边界压缩连续而丰富的现实，便于推理，却必然遗漏部分细节。',
      operationalRule: '概念卡必须同时显示覆盖、遗漏、压缩损失、支持实例与反例。',
      featureBindings: <String>[
        'Mosaic–Painting fidelity 审查',
        '概念覆盖 / 遗漏 / 压缩损失',
        '概念边界页面',
      ],
      relatedRuleIds: <String>['K0-RULE-004', 'SCK-006', 'SCK-013'],
      sourceLocator: 'V5.0「镶嵌画原则」；《作为意志和表象的世界》第一篇 §9',
      passageIds: <String>['XF-K0-PASSAGE-09'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-011',
      displayName: '判断力：同、异与决定性差异',
      originalTerm: '判断力连接直观与抽象',
      category: '概念、判断与直觉',
      conceptKind: '叔本华原典核心',
      definition: '判断力不是机械套标签，而是从具体案例中识别相同点、差异以及对当前目的真正关键的差异。',
      operationalRule: '复用旧案例或旧规则前必须比较决定性差异，并据此调整适用范围。',
      featureBindings: <String>[
        '案例比较器',
        '决定性差异',
        '判断成长历史',
      ],
      relatedRuleIds: <String>['K0-RULE-011', 'SCK-005', 'PS-019'],
      sourceLocator: 'V5.0「判断力与案例比较」；《作为意志和表象的世界》第一篇判断力相关论述',
      passageIds: <String>['XF-K0-PASSAGE-JUDGMENT'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-012',
      displayName: '概念边界与反例区',
      originalTerm: '由概念抽象与判断力推导的产品机制',
      category: '概念、判断与直觉',
      conceptKind: 'V5 产品操作化（不冒充原典术语）',
      definition: '一个概念的意义不仅由支持案例决定，也由它解释不了什么、在哪些条件下失效来界定。',
      operationalRule: '每个高影响个人概念都保存反例、适用条件、未解释细节与修订版本。',
      featureBindings: <String>[
        '反例区',
        '适用边界',
        '概念版本控制',
      ],
      relatedRuleIds: <String>['K0-RULE-004', 'K0-RULE-011', 'SCK-013'],
      sourceLocator: 'V5.0「概念反例区 / 概念版本」；理论根据见第一篇 §9 与判断力论述',
      passageIds: <String>['XF-K0-PASSAGE-09', 'XF-K0-PASSAGE-JUDGMENT'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-013',
      displayName: '未概念化直觉',
      originalTerm: '面相例所示的整体直观先于清晰概念',
      category: '概念、判断与直觉',
      conceptKind: '叔本华原典核心',
      definition: '用户可能先感到某种整体模式，却暂时无法准确命名；这种直觉可以保留，但不能直接升级为外部事实。',
      operationalRule: '先记录场景、身体、强度和反复模式，再由多次比较形成可修订判断。',
      featureBindings: <String>[
        '未概念化直觉箱',
        '跨场景模式采样',
        '延迟命名与保守假设',
      ],
      relatedRuleIds: <String>['SCK-012', 'CEL-008', 'K0-RULE-017'],
      sourceLocator: 'V5.0「面相例的方法意义 / 未概念化直觉箱」；原典细定位待知识校勘',
      passageIds: <String>['XF-K0-PASSAGE-JUDGMENT'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-014',
      displayName: '感觉阶梯：体验不等于外因',
      originalTerm: '内在体验与外部因果认识的区分',
      category: '感受、知性与因果',
      conceptKind: '叔本华原典核心',
      definition: '身体变化、直接体验、情绪、行动冲动、外部解释、因果判断和预测是不同台阶；前一台阶真实不等于后一台阶已证实。',
      operationalRule: '承认感觉事实，同时把关于他人和外部世界的解释保留为候选假设。',
      featureBindings: <String>[
        '感觉阶梯',
        '身体 / 情绪 / 冲动分层',
        '外部解释独立验算',
      ],
      relatedRuleIds: <String>['K0-RULE-003', 'SCK-012', 'CEL-002'],
      sourceLocator: 'V5.0「感觉阶梯」；《作为意志和表象的世界》第一篇知性与判断力相关论述',
      passageIds: <String>['XF-K0-PASSAGE-JUDGMENT'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-015',
      displayName: '知性与因果认识',
      originalTerm: 'Verstand（知性）与因果性',
      category: '感受、知性与因果',
      conceptKind: '叔本华原典核心',
      definition: '知性把感觉变化理解为有原因的现实，但特定结果并不自动唯一锁定某一个外部原因。',
      operationalRule: '重要结果先形成多个机制候选，再寻找能区分它们的观察。',
      featureBindings: <String>[
        '因果候选图',
        '结果—原因分离',
        'Causal engine',
      ],
      relatedRuleIds: <String>['K0-RULE-003', 'SCK-004', 'CEL-004'],
      sourceLocator: 'V5.0「独立因果引擎」；《作为意志和表象的世界》第一篇知性相关论述',
      passageIds: <String>['XF-K0-PASSAGE-JUDGMENT'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-016',
      displayName: '竞争原因与区分实验',
      originalTerm: '由因果认识边界推导的产品机制',
      category: '感受、知性与因果',
      conceptKind: 'V5 产品操作化（不冒充原典术语）',
      definition: '同一结果可能由机制不同的原因造成；第一个顺手解释不能独占决策权。',
      operationalRule: '生成二至五个竞争原因，选一个低风险观察寻找某个原因独有的信号。',
      featureBindings: <String>[
        '2–N 竞争假设',
        '区分实验',
        '假设支持 / 反驳状态',
      ],
      relatedRuleIds: <String>['SCK-004', 'CEL-004', 'PS-018'],
      sourceLocator: 'V5.0「竞争因果 / 区分实验」；理论根据见第一篇知性相关论述',
      passageIds: <String>['XF-K0-PASSAGE-JUDGMENT'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-017',
      displayName: '理性、语言与隐藏概念链',
      originalTerm: 'Vernunft（理性）与抽象概念',
      category: '理性、语言与确定性',
      conceptKind: '叔本华原典核心',
      definition: '理性借助概念与语言推理、设定目标和计划；语言也会暴露被省略的分类、前提和价值判断。',
      operationalRule: '重要绝对化或身份化表达必须展开为隐藏概念链并逐项检查根据。',
      featureBindings: <String>[
        '语言概念诊断',
        '隐藏前提链',
        '事实 / 判断 / 价值拆分',
      ],
      relatedRuleIds: <String>['K0-RULE-002', 'K0-RULE-016', 'SCK-010'],
      sourceLocator: 'V5.0「语言作为概念诊断器」；《作为意志和表象的世界》第一篇 §§9、15',
      passageIds: <String>['XF-K0-PASSAGE-09', 'XF-K0-PASSAGE-15'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-018',
      displayName: '系统性不等于确定性',
      originalTerm: 'Wissenschaft 的系统联系与认识确定性之别',
      category: '理性、语言与确定性',
      conceptKind: '叔本华原典核心',
      definition: '模型更完整、术语更专业或推理更长，只增加系统性，不自动增加现实确定性。',
      operationalRule: '分开显示模型完整度与认识状态，取消学术性、权威性和复杂度加成。',
      featureBindings: <String>[
        '系统性 / 确定性双指标',
        '认识状态画像',
        '复杂模型不加权',
      ],
      relatedRuleIds: <String>['K0-RULE-014', 'K0-RULE-015', 'SCK-008'],
      sourceLocator: 'V5.0「系统性不等于确定性」；《作为意志和表象的世界》第一篇 §14',
      passageIds: <String>['XF-K0-PASSAGE-14'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-019',
      displayName: '证明不能补救弱前提',
      originalTerm: '证明在概念关系中推进，前提仍需根据',
      category: '理性、语言与确定性',
      conceptKind: '叔本华原典核心',
      definition: '逻辑上成立的长推导不能把缺乏现实根据的前提变真；最弱前提决定结论可承诺的上限。',
      operationalRule: '形式结构与前提根据分开审计，优先核查最弱前提而非继续延长推理。',
      featureBindings: <String>[
        'Proof audit',
        '最弱前提',
        '前提信息子目标',
      ],
      relatedRuleIds: <String>['K0-RULE-016', 'SCK-009', 'SCK-010'],
      sourceLocator: 'V5.0「证明审查」；《作为意志和表象的世界》第一篇 §15',
      passageIds: <String>['XF-K0-PASSAGE-15'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-020',
      displayName: '抽象目标的可观察判据',
      originalTerm: '由概念与直观之别推导的目标操作化',
      category: '理性、语言与确定性',
      conceptKind: 'V5 产品操作化（不冒充原典术语）',
      definition: '自由、成功、稳定等抽象目标需要现实中的满足判据，但这些判据只是操作化，不等于概念本身。',
      operationalRule: '目标必须由用户确认并写成可观察成功判据；路径、证明冲动和沉没成本不能冒充目标。',
      featureBindings: <String>[
        'GoalState 成功判据',
        '目标—路径审查',
        '用户确认门',
      ],
      relatedRuleIds: <String>['K0-RULE-019', 'K0-RULE-USER', 'SCK-016'],
      sourceLocator: 'V5.0「抽象目标操作化 / 用户目标权」；理论根据见第一篇判断力相关论述',
      passageIds: <String>['XF-K0-PASSAGE-JUDGMENT'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-021',
      displayName: '归纳、频率与可证伪规则',
      originalTerm: '由具体经验形成一般判断的边界',
      category: '理性、语言与确定性',
      conceptKind: 'V5 产品操作化（不冒充原典术语）',
      definition: '“总是”必须回到样本和条件；个人规则应表达为通常、偶尔及其适用分布，并允许反例推翻。',
      operationalRule: '绝对化语言转成带次数、条件、反例、最近验证和置信度的可证伪规则。',
      featureBindings: <String>[
        'Always → Usually / Sometimes 检测',
        '个人规则计数与条件',
        '可证伪与最近验证',
      ],
      relatedRuleIds: <String>['SCK-011', 'SCK-017', 'CEL-013'],
      sourceLocator: 'V5.0「总是—通常检测 / 可证伪个人规则」；理论根据见第一篇判断力相关论述',
      passageIds: <String>['XF-K0-PASSAGE-JUDGMENT'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-022',
      displayName: '熟练行动与过度反省',
      originalTerm: '熟练直观行动与抽象反省的边界',
      category: '行动、科学与现实修订',
      conceptKind: '叔本华原典核心',
      definition: '反思能帮助纠错，但在已掌握的行动中持续插入抽象监控，也可能破坏本来有效的熟练执行。',
      operationalRule: '反思模式展示根据和概念；行动模式隐藏非必要分析，只保留当前一步、停止条件与安全边界。',
      featureBindings: <String>[
        '反思模式 / 行动模式',
        '行动页隐藏分析',
        '可停止的小步执行',
      ],
      relatedRuleIds: <String>['SCK-015', 'CEL-015', 'PS-023'],
      sourceLocator: 'V5.0「反思模式与行动模式」；原典细定位待知识校勘',
      passageIds: <String>['XF-K0-PASSAGE-JUDGMENT'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-023',
      displayName: '个人经验科学（Wissenschaft）',
      originalTerm: 'Wissenschaft：经验知识的系统联系',
      category: '行动、科学与现实修订',
      conceptKind: '叔本华原典核心',
      definition: '个人长期经验只有按条件、预测、结果、反例和修订系统组织，才会成为可复核的个人经验科学，而非故事堆积。',
      operationalRule: '每条个人规则保存条件、样本次数、反例、最近验算、置信度和版本。',
      featureBindings: <String>[
        '个人经验科学 / 战史',
        '可证伪个人规则',
        '规则版本与置信度',
      ],
      relatedRuleIds: <String>['K0-RULE-015', 'SCK-017', 'CEL-013'],
      sourceLocator: 'V5.0「个人认识科学」；《作为意志和表象的世界》第一篇 §14',
      passageIds: <String>['XF-K0-PASSAGE-14'],
    ),
    XiangjiSchopenhauerCoreConcept(
      id: 'SC-K0-024',
      displayName: '新现实修订旧概念',
      originalTerm: '直观现实对抽象认识的纠正权',
      category: '行动、科学与现实修订',
      conceptKind: '叔本华原典核心',
      definition: '行动后的新经验世界 I′ 是认识闭环的最终验算者；预测与现实不符时应先修订旧概念、假设和路径。',
      operationalRule: '事前锁定预测，事后记录事实，冲突时生成概念新版本并回溯最早失效层。',
      featureBindings: <String>[
        '预测—现实账本',
        'ConceptRealityConflict',
        '学习时刻与分层回溯',
      ],
      relatedRuleIds: <String>['K0-RULE-021', 'K0-RULE-REALITY', 'SCK-018'],
      sourceLocator: 'V5.0「现实修订 / 三重闭环」；《作为意志和表象的世界》第一篇判断力相关论述',
      passageIds: <String>['XF-K0-PASSAGE-JUDGMENT'],
    ),
  ];

  static List<String> get ids =>
      entries.map((entry) => entry.id).toList(growable: false);

  static XiangjiSchopenhauerCoreConcept forId(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    throw ArgumentError.value(id, 'id', '未知叔本华 L0 核心概念');
  }

  static List<XiangjiSchopenhauerCoreConcept> forIds(Iterable<String> ids) =>
      ids.map(forId).toList(growable: false);
}
