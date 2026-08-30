/// Canonical Rev.5.2 method knowledge used by runtime routing, persistence and
/// every user-facing concept label.
///
/// The catalog deliberately separates three things that were previously
/// collapsed in the UI:
/// 1. the product capability defined by the Master PRD;
/// 2. the original epistemic concept that grounds it;
/// 3. the persistent-solver mechanism implemented by Xiangji.
class XiangjiMethodKnowledge {
  const XiangjiMethodKnowledge({
    required this.id,
    required this.englishName,
    required this.displayName,
    required this.domain,
    required this.layer,
    required this.sourceConcept,
    required this.principle,
    required this.triggerSummary,
    required this.stateEffect,
    required this.realityTest,
    required this.transferQuestion,
    required this.sourceLocator,
    required this.passageIds,
    required this.relatedRuleIds,
  });

  final String id;
  final String englishName;
  final String displayName;
  final String domain;
  final String layer;
  final String sourceConcept;
  final String principle;
  final String triggerSummary;
  final String stateEffect;
  final String realityTest;
  final String transferQuestion;
  final String sourceLocator;
  final List<String> passageIds;
  final List<String> relatedRuleIds;

  String get nodeType => layer == 'K1'
      ? 'signature_epistemic_method'
      : 'signature_solver_method';

  List<String> get sourceRefs => <String>[
        'product:$id',
        ...passageIds,
      ];
}

class XiangjiMethodCatalog {
  const XiangjiMethodCatalog._();

  static const String version = 'V6.1 Final Rev.5.2';
  static const String sourceId = 'XF-K1-METHOD-CATALOG';
  static const String documentId = 'XF-K1-DOC-METHOD-CATALOG';
  static const String productContract =
      '01_Xiangji_V6.1_Rev5.2_Master_PRD.pdf';

  static const List<XiangjiMethodKnowledge> entries =
      <XiangjiMethodKnowledge>[
    XiangjiMethodKnowledge(
      id: 'MEC-001',
      englishName: 'Experience vs Interpretation',
      displayName: '经验与解释分层',
      domain: '认识方法',
      layer: 'K1',
      sourceConcept: '概念是表象的表象；直观经验不等于抽象解释',
      principle:
          '先保留亲历的事实与感受，再把“它意味着什么”作为可修订解释。抽象解释不能越过现实材料直接支配决定。',
      triggerSummary: '事实、直接体验和解释在同一段材料中混写时。',
      stateEffect: '分层保存事实、体验与解释，并取消无根据解释的决策权限。',
      realityTest: '补充可观察记录或独立来源，检查解释是否仍成立。',
      transferQuestion: '下次可问：我直接经历或观察到什么？哪些只是我对它的解释？',
      sourceLocator: '《作为意志和表象的世界》第一篇 §9；Master PRD MEC-001',
      passageIds: <String>['XF-K0-PASSAGE-09'],
      relatedRuleIds: <String>[
        'K0-RULE-002',
        'SCK-002',
        'CEL-002',
        'CEL-003',
      ],
    ),
    XiangjiMethodKnowledge(
      id: 'MEC-002',
      englishName: 'Feeling vs External Cause',
      displayName: '感觉与外部原因分开',
      domain: '认识方法',
      layer: 'K1',
      sourceConcept: '内在体验与外部因果属于不同认识层',
      principle:
          '感觉本身是内在经验的事实，但它所指向的外部原因仍需独立根据。军师因此把外部解释降为候选原因。',
      triggerSummary: '身体感觉、害怕或抗拒被直接用来推出外部事实时。',
      stateEffect: '保留体验，同时把外部原因改为待验证假设。',
      realityTest: '寻找一个能独立支持或反驳外部原因的安全观察。',
      transferQuestion: '下次可问：这个感觉本身告诉了我什么，关于外部原因还缺什么根据？',
      sourceLocator: '《作为意志和表象的世界》第一篇判断力相关论述；Master PRD MEC-002',
      passageIds: <String>['XF-K0-PASSAGE-JUDGMENT'],
      relatedRuleIds: <String>[
        'K0-RULE-003',
        'SCK-012',
        'CEL-002',
      ],
    ),
    XiangjiMethodKnowledge(
      id: 'MEC-003',
      englishName: 'Competing Causality',
      displayName: '竞争因果与区分实验',
      domain: '认识方法',
      layer: 'K1',
      sourceConcept: '知性追问原因，但一个结果不只指向唯一原因',
      principle:
          '第一个顺手的解释不等于真实原因。军师必须提出机制不同、能被现实区分的竞争原因。',
      triggerSummary: '一个重要结果被直接归为单一原因时。',
      stateEffect: '建立二至五个机制不同的候选原因，并把关键差距改为信息缺口。',
      realityTest: '执行一个低风险观察，寻找某个候选原因独有的信号。',
      transferQuestion: '下次可问：还有哪种机制也会造成同一结果？什么观察能区分它们？',
      sourceLocator: '《作为意志和表象的世界》第一篇知性与判断力相关论述；Master PRD MEC-003',
      passageIds: <String>['XF-K0-PASSAGE-JUDGMENT'],
      relatedRuleIds: <String>['SCK-004', 'CEL-004', 'PS-018'],
    ),
    XiangjiMethodKnowledge(
      id: 'MEC-004',
      englishName: 'Judgment Case Comparison',
      displayName: '判断力案例比较',
      domain: '认识方法',
      layer: 'K1',
      sourceConcept: '判断力比较具体情形的同、异与决定性差异',
      principle:
          '判断力不是机械套用旧标签，而是比较具体案例的相同点、差异和哪项差异真正影响当前目的。',
      triggerSummary: '准备复用历史案例、抽象标签或旧策略时。',
      stateEffect: '保存决定性差异，重新选择关键差距并使不再适用的旧办法失效。',
      realityTest: '执行新路线后，观察该决定性差异是否确实解释了结果变化。',
      transferQuestion: '下次可问：这次与过去最关键的差异是什么，它会改变哪一步？',
      sourceLocator: '《作为意志和表象的世界》第一篇判断力相关论述；Master PRD MEC-004',
      passageIds: <String>['XF-K0-PASSAGE-JUDGMENT'],
      relatedRuleIds: <String>[
        'K0-RULE-011',
        'SCK-005',
        'CEL-005',
        'PS-019',
      ],
    ),
    XiangjiMethodKnowledge(
      id: 'MEC-005',
      englishName: 'Unconceptualized Experience',
      displayName: '未概念化体验保留',
      domain: '认识方法',
      layer: 'K1',
      sourceConcept: '直观内容不能被既有概念完全穷尽',
      principle:
          '暂时说不清的体验也可以先被完整保留。军师不会为了整齐而过早贴标签。',
      triggerSummary: '用户报告“说不清但不对劲”等尚未稳定命名的体验时。',
      stateEffect: '按原样保存体验与场景，并阻止强制贴标签。',
      realityTest: '下次出现时记录身体、情境、强度和变化，比较跨场景模式。',
      transferQuestion: '下次可问：如果先不命名，我还能具体描述哪些身体、情境和变化？',
      sourceLocator: '《作为意志和表象的世界》第一篇 §9；Master PRD MEC-005',
      passageIds: <String>['XF-K0-PASSAGE-09'],
      relatedRuleIds: <String>['SCK-012', 'CEL-008'],
    ),
    XiangjiMethodKnowledge(
      id: 'MEC-006',
      englishName: 'Concept Scope and Mosaic-Painting Fidelity',
      displayName: '概念边界与镶嵌画保真',
      domain: '认识方法',
      layer: 'K1',
      sourceConcept: '概念如镶嵌画，直观如连续绘画',
      principle:
          '抽象概念会压缩连续而细密的现实。军师检查概念解释了什么、遗漏了什么，并用反例收缩边界。',
      triggerSummary: '抽象标签开始覆盖复杂经验或个人情形时。',
      stateEffect: '保存概念的覆盖范围、遗漏、反例和压缩损失，并收窄适用边界。',
      realityTest: '寻找一个不符合当前标签的具体反例，检查概念边界。',
      transferQuestion: '下次可问：这个标签解释了哪些例子，又遗漏或解释不了哪些反例？',
      sourceLocator: '《作为意志和表象的世界》第一篇 §9；Master PRD MEC-006',
      passageIds: <String>['XF-K0-PASSAGE-09'],
      relatedRuleIds: <String>[
        'K0-RULE-004',
        'SCK-006',
        'SCK-013',
        'CEL-007',
      ],
    ),
    XiangjiMethodKnowledge(
      id: 'MEC-007',
      englishName: 'Ground Explorer / Spring-Aqueduct',
      displayName: '根据探查：泉水—水渠',
      domain: '认识方法',
      layer: 'K1',
      sourceConcept: '间接判断必须沿根据链回到现实“泉水”',
      principle:
          '间接判断像水渠，最终必须能回到直接事实、体验或可靠记录这眼“泉水”。根据弱时，行动承诺必须降低。',
      triggerSummary: '高影响判断、建议或关键前提的现实根据不足时。',
      stateEffect: '保存根据链与最弱前提，并按根据强度降低不可逆行动承诺。',
      realityTest: '补足最弱前提的一项独立事实，或把路线缩小为可逆侦察。',
      transferQuestion: '下次可问：这个判断最后能沿哪条链回到直接现实根据？',
      sourceLocator: '《作为意志和表象的世界》第一篇 §§9、15；Master PRD MEC-007',
      passageIds: <String>['XF-K0-PASSAGE-09', 'XF-K0-PASSAGE-15'],
      relatedRuleIds: <String>[
        'K0-RULE-005',
        'K0-RULE-006',
        'SCK-007',
        'CEL-006',
      ],
    ),
    XiangjiMethodKnowledge(
      id: 'MEC-008',
      englishName: 'Systematicity-Certainty / Proof Audit',
      displayName: '系统性、确定性与证明审查',
      domain: '认识方法',
      layer: 'K1',
      sourceConcept: '系统性不等于确定性；证明不替代前提根据',
      principle:
          '模型越完整、推理越长，并不会自动增加真实性。逻辑结构和前提是否有现实根据必须分别审查。',
      triggerSummary: '复杂模型、长推理或形式证明被用来提高确定性时。',
      stateEffect: '分开保存体系完整度与认识状态，并显式标出最弱前提。',
      realityTest: '直接核查最弱前提，而不是继续延长推理链。',
      transferQuestion: '下次可问：结构完整之外，最弱前提凭什么是真的？',
      sourceLocator: '《作为意志和表象的世界》第一篇 §§14–15；Master PRD MEC-008',
      passageIds: <String>['XF-K0-PASSAGE-14', 'XF-K0-PASSAGE-15'],
      relatedRuleIds: <String>[
        'K0-RULE-014',
        'K0-RULE-015',
        'K0-RULE-016',
        'SCK-008',
        'SCK-009',
        'SCK-010',
        'CEL-010',
        'CEL-011',
      ],
    ),
    XiangjiMethodKnowledge(
      id: 'MEC-009',
      englishName: 'Concept-Reality Conflict',
      displayName: '概念—现实冲突',
      domain: '认识方法',
      layer: 'K1',
      sourceConcept: '抽象概念必须接受直观现实纠错',
      principle:
          '当预测与现实冲突时，应先修订抽象概念和旧解释，而不是责怪现实；受影响的差距与办法也要重算。',
      triggerSummary: '概念、规则或预测持续不能解释新现实时。',
      stateEffect: '登记冲突、更新关键差距，并使建立在旧解释上的办法失效。',
      realityTest: '用修订后的概念产生一项新预测，再与下一次现实结果对账。',
      transferQuestion: '下次可问：如果现实不符合旧解释，我应先修订哪个概念或假设？',
      sourceLocator: '《作为意志和表象的世界》第一篇判断力相关论述；Master PRD MEC-009',
      passageIds: <String>['XF-K0-PASSAGE-JUDGMENT'],
      relatedRuleIds: <String>[
        'K0-RULE-021',
        'SCK-014',
        'SCK-018',
        'CEL-009',
        'PS-021',
      ],
    ),
    XiangjiMethodKnowledge(
      id: 'MEC-010',
      englishName: 'Goal Audit',
      displayName: '目标与价值审查',
      domain: '用户主权与求解',
      layer: 'K2',
      sourceConcept: '理性安排目的—手段，但不替用户决定终极价值',
      principle:
          '军师审查把路径、证明冲动或沉没成本误当目标的情况；什么值得追求仍由用户决定。',
      triggerSummary: '优化路线前，或路径、沉没成本、证明欲可能冒充最终目标时。',
      stateEffect: '创建目标新版本和用户确认门；未确认前停止继续优化。',
      realityTest: '让用户确认可观察成功判据，并检查它是否仍服务真正珍视的结果。',
      transferQuestion: '下次可问：这是我真正珍视的结果，还是一条路径、证明或沉没成本？',
      sourceLocator: 'Master PRD MEC-010；《作为意志和表象的世界》第一篇理性与目的相关论述',
      passageIds: <String>['XF-K0-PASSAGE-JUDGMENT'],
      relatedRuleIds: <String>[
        'K0-RULE-019',
        'K0-RULE-USER',
        'SCK-016',
      ],
    ),
    XiangjiMethodKnowledge(
      id: 'MEC-011',
      englishName: 'Gap Radar',
      displayName: '七维差距雷达',
      domain: '持续问题求解',
      layer: 'K2',
      sourceConcept: '目标与当前现实之间的可改变差距',
      principle:
          '目标只有与当前可观察现实比较，才会形成可求解的差距。军师按影响、可控性和依赖关系选择唯一关键差距。',
      triggerSummary: '当前现实与目标已经足够明确，需要选择先解决哪项差距时。',
      stateEffect: '比较信息、概念、能力、资源、环境、行动和风险七维差距并选出 KeyGap。',
      realityTest: '完成当前小步后，检查目标相关的关键差距是否实际缩小。',
      transferQuestion: '下次可问：目标与当前现实之间，哪项差距最影响结果且最值得先解？',
      sourceLocator: 'Master PRD MEC-011 / GapVector—KeyGap 合约',
      passageIds: <String>['XF-K0-PASSAGE-JUDGMENT'],
      relatedRuleIds: <String>['SCK-015', 'CEL-012', 'PS-020', 'PS-025'],
    ),
    XiangjiMethodKnowledge(
      id: 'MEC-012',
      englishName: 'SubGoal-Operator-Precondition Solver',
      displayName: '子目标—算子—前提求解',
      domain: '持续问题求解',
      layer: 'K2',
      sourceConcept: '手段必须说明机制、差距与生效前提',
      principle:
          '计划必须说明手段通过什么机制缩小哪项差距，并检查生效前提；前提不成立时先把它变成新的小目标。',
      triggerSummary: '关键差距已选定，需要形成当前小步和唯一行动时。',
      stateEffect: '建立 AND/OR 子目标图；把缺失前提递归改为前提子目标，再选择可执行算子。',
      realityTest: '先验证缺失前提；前提成立后再观察行动是否产生预期效果。',
      transferQuestion: '下次可问：这个办法靠什么机制起效，前提真的具备吗？',
      sourceLocator: 'Master PRD MEC-012 / SubGoal—Operator—Precondition 合约',
      passageIds: <String>['XF-K0-PASSAGE-15'],
      relatedRuleIds: <String>['SCK-015', 'CEL-012', 'PS-018', 'PS-023'],
    ),
    XiangjiMethodKnowledge(
      id: 'MEC-013',
      englishName: 'Prediction-Reality Ledger',
      displayName: '预测—现实账本',
      domain: '持续问题求解',
      layer: 'K2',
      sourceConcept: '锁定事前预测，让现实拥有最终验算权',
      principle:
          '行动前写下可被反驳的预测，行动后让现实作最终验算；结果出现后不能倒改原预测维护旧解释。',
      triggerSummary: '行动即将开始，或行动后已有现实结果需要对账时。',
      stateEffect: '锁定事前预测并关联现实结果；反驳时挑战假设并重估差距。',
      realityTest: '行动后记录可观察事实，与未改写的原预测逐项对账。',
      transferQuestion: '下次可问：行动前我愿意预先写下什么可观察结果来检验它？',
      sourceLocator: 'Master PRD MEC-013 / Prediction—Reality 合约',
      passageIds: <String>['XF-K0-PASSAGE-JUDGMENT'],
      relatedRuleIds: <String>[
        'K0-RULE-REALITY',
        'SCK-018',
        'CEL-014',
        'PS-023',
        'PS-025',
      ],
    ),
    XiangjiMethodKnowledge(
      id: 'MEC-014',
      englishName: 'Backtrack Inspector',
      displayName: '分层回溯检查',
      domain: '持续问题求解',
      layer: 'K2',
      sourceConcept: '从执行逐层回溯到事实与判断',
      principle:
          '现实反驳不是笼统的“失败”，而是定位哪一层最早失效；军师从执行、办法、前提一路回溯到概念与事实。',
      triggerSummary: '现实与预测不符，或行动完成但没有产生预期效果时。',
      stateEffect: '记录最早失败层，使旧办法失效，并把当前小步改为修复该层。',
      realityTest: '执行重算后的新路线，检查同一失败信号是否消失。',
      transferQuestion: '下次可问：最早出错的是执行、办法、前提、目标，还是更前面的判断？',
      sourceLocator: 'Master PRD MEC-014 / BacktrackHistory 合约',
      passageIds: <String>['XF-K0-PASSAGE-15', 'XF-K0-PASSAGE-JUDGMENT'],
      relatedRuleIds: <String>['SCK-018', 'CEL-009', 'CEL-014', 'PS-021', 'PS-025'],
    ),
  ];

  static List<String> get ids =>
      entries.map((entry) => entry.id).toList(growable: false);

  static XiangjiMethodKnowledge forId(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return XiangjiMethodKnowledge(
      id: id,
      englishName: id,
      displayName: id,
      domain: '可修订认识方法',
      layer: 'K1',
      sourceConcept: '现实优先的可修订认识',
      principle: '当前判断只是一份可修订模型，现实结果拥有最终纠正权。',
      triggerSummary: '当前问题需要认识或求解审查时。',
      stateEffect: '保留当前状态并等待足够现实根据。',
      realityTest: '寻找能支持或推翻当前理解的现实材料。',
      transferQuestion: '下次可问：什么现实会支持或推翻当前理解？',
      sourceLocator: productContract,
      passageIds: const <String>[],
      relatedRuleIds: const <String>[],
    );
  }
}
