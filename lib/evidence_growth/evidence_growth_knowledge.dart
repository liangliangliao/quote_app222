import 'evidence_growth_models.dart';
import 'evidence_growth_source_cards.dart';

/// Knowledge text is extracted from KB35; routing and operators are ENG derivations.
/// r2 uses canonical source IDs. Retired r1 IDs are never reassigned to new claims;
/// historical Trials retain their original evidence snapshots in SQLite.
class EvidenceGrowthKnowledge {
  EvidenceGrowthKnowledge._();
  static const String kbVersion = '3.5-r2';
  static const String promptVersion = 'eg-p1.1';
  static const sources = <String, String>{
    'KB35': '哈佛幸福课_六大模块成长闭环知识库_v3.5_Tal主线_专家延伸II正式整合版',
    'TAL23': 'Lecture 01–23；讲次按 KB35 保留，未另行加载课程原稿',
    'ENG': '正式产品方案 v1.0 的软件设计推导，非 Tal 原话',
  };
  static final List<EvidenceKNode> nodes = List.unmodifiable(
    evidenceGrowthSourceCards.map(_fromSource),
  );
  static final Map<String, EvidenceKNode> _index = {
    for (final node in nodes) node.id: node,
  };
  static List<EvidenceKNode> get talNodes =>
      nodes.where((node) => node.isTal).toList(growable: false);
  static List<EvidenceKNode> get extensionNodes =>
      nodes.where((node) => !node.isTal).toList(growable: false);
  static List<EvidenceKNode> forModule(GrowthModule module) =>
      nodes.where((node) => node.module == module).toList(growable: false);
  static EvidenceKNode? byId(String id) => _index[id];
  static EvidenceKNode source(String originalId) => _index['KB35-$originalId']!;

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

  /// Explicit mechanism-to-operator mappings; remaining source cards run their
  /// own original How-to through SOURCE_PRACTICE, with no fabricated instruction.
  static const operatorBySource = <String, String>{
    'B01': 'BELIEF_TO_TESTABLE_HYPOTHESIS', 'B02': 'REALITY_CALIBRATION',
    'B03': 'REALITY_CALIBRATION', 'B04': 'CONTEXT_REDESIGN',
    'B05': 'SAFE_EXPOSURE', 'B06': 'ALTERNATIVE_EVIDENCE',
    'B-AUDIT-01': 'REALITY_CALIBRATION', 'B-AUDIT-02': 'EXPOSURE_LADDER',
    'B-AUDIT-03': 'EXPOSURE_LADDER', 'B-AUDIT-05': 'CONTEXT_REDESIGN',
    'B-AUDIT-06': 'PROCESS_ACTION', 'B-AUDIT-08': 'ALTERNATIVE_EVIDENCE',
    'B-AUDIT-13': 'ALTERNATIVE_EVIDENCE', 'B-AUDIT-14': 'CONTEXT_REDESIGN',
    'G01': 'PRIORITY_CUT', 'G02': 'GOAL_ROLE_CHECK',
    'G03': 'SELF_CONCORDANCE_CHECK', 'G04': 'SELF_CONCORDANCE_CHECK',
    'G05': 'GAP_OPERATOR', 'G06': 'EXPOSURE_LADDER',
    'G-AUDIT-05': 'PRIORITY_CUT', 'G-AUDIT-09': 'OBSERVATION_WINDOW',
    'G-AUDIT-10': 'SELF_CONCORDANCE_CHECK', 'G-AUDIT-13': 'SELF_CONCORDANCE_CHECK',
    'A01': 'START_5_MIN', 'A02': 'START_5_MIN', 'A03': 'PROCESS_ACTION',
    'A04': 'EXPOSURE_LADDER', 'A05': 'COMMITMENT_LADDER', 'A06': 'VISIBLE_TRACE',
    'A-AUDIT-01': 'RECOVER', 'A-AUDIT-02': 'RECOVER',
    'A-AUDIT-03': 'COMMITMENT_LADDER', 'A-AUDIT-04': 'SAFE_EXPOSURE',
    'A-AUDIT-05': 'DIVIDE_NEXT_STEP', 'A-AUDIT-06': 'PROCESS_ACTION',
    'A-AUDIT-07': 'RECOVER', 'A-AUDIT-08': 'BODY_FIRST',
    'A-AUDIT-10': 'RECOVER_REENTER', 'A-AUDIT-14': 'RISK_DOWNSCALE',
    'A-AUDIT-16': 'SAFE_EXPOSURE', 'A-AUDIT-17': 'RECOVER',
    'F01': 'SAFE_EXPOSURE', 'F02': 'OPTIMALIST_CHECK',
    'F03': 'FAILURE_REFRAME', 'F04': 'EXPOSURE_LADDER',
    'F05': 'OPTIMALIST_CHECK', 'F06': 'SAFE_IMPERFECTION',
    'F-AUDIT-01': 'FAILURE_REFRAME', 'F-AUDIT-03': 'FAILURE_CLASSIFY',
    'F-AUDIT-05': 'COMPASSIONATE_ACCOUNTABILITY', 'F-AUDIT-09': 'ONE_VARIABLE_CHANGE',
    'F-AUDIT-13': 'PERMISSION_TO_BE_HUMAN', 'F-AUDIT-14': 'PERMISSION_TO_BE_HUMAN',
    'R01': 'PDSA_REVIEW', 'R02': 'FACT_INFERENCE_SPLIT',
    'R03': 'POSITIVE_REPLAY', 'R04': 'PERMISSION_TO_BE_HUMAN',
    'R05': 'PDSA_REVIEW', 'R06': 'PDSA_REVIEW',
    'R-AUDIT-01': 'STOP_RUMINATION', 'R-AUDIT-03': 'POSITIVE_REPLAY',
    'R-AUDIT-08': 'ROLE_MODEL_TRANSFER', 'R-AUDIT-09': 'PDSA_REVIEW',
    'C01': 'REPETITION_PLAN', 'C02': 'ACT_ADJUST_EXIT', 'C03': 'BODY_FIRST',
    'C04': 'NEXT_TRIAL', 'C05': 'CONTEXT_REDESIGN', 'C06': 'CONTEXT_REDESIGN',
    'C07': 'RECOVERY_MEASURE', 'C-AUDIT-04': 'VISIBLE_TRACE',
    'C-AUDIT-05': 'RECOVERY_MEASURE', 'C-AUDIT-18': 'NEXT_TRIAL',
    'C-AUDIT-19': 'SAFE_EXPOSURE', 'C-AUDIT-20': 'CONTEXT_REDESIGN',
    'B-EXT-01': 'SAFE_EXPOSURE', 'B-EXT-02': 'TESTABLE_GROWTH_RULE',
    'B-EXT-03': 'FACT_INFERENCE_SPLIT', 'B-EXT-04': 'BELIEF_TO_TESTABLE_HYPOTHESIS',
    'G-EXT-01': 'SELF_CONCORDANCE_CHECK', 'G-EXT-02': 'PREREQUISITE_CHECK',
    'G-EXT-03': 'PRIORITY_CUT', 'A-EXT-01': 'CONTEXT_REDESIGN',
    'A-EXT-02': 'PROCESS_ACTION', 'A-EXT-03': 'VISIBLE_TRACE',
    'F-EXT-01': 'FAILURE_CLASSIFY', 'F-EXT-02': 'COMPASSIONATE_ACCOUNTABILITY',
    'F-EXT-03': 'FAILURE_CLASSIFY', 'R-EXT-01': 'PDSA_REVIEW',
    'R-EXT-02': 'ACT_ADJUST_EXIT', 'R-EXT-03': 'PDSA_REVIEW',
    'R-EXT-04': 'FACT_INFERENCE_SPLIT', 'C-EXT-01': 'PROCESS_ACTION',
    'C-EXT-02': 'THEORY_IN_USE_CHECK', 'C-EXT-03': 'SELF_CONCORDANCE_CHECK',
    'C-EXT-04': 'VISIBLE_TRACE', 'B-EXT2-01': 'PROBABILITY_LEDGER',
    'B-EXT2-02': 'CAUSAL_LEVEL_CHECK', 'G-EXT2-01': 'GAP_OPERATOR',
    'G-EXT2-02': 'GAP_OPERATOR', 'A-EXT2-01': 'CONTEXT_REDESIGN',
    'F-EXT2-01': 'SAFE_EXPOSURE', 'F-EXT2-02': 'RISK_DOWNSCALE',
    'R-EXT2-01': 'PDSA_REVIEW', 'R-EXT2-02': 'PREMORTEM',
    'C-EXT2-01': 'SYSTEM_SCAN',
  };

  static EvidenceKNode _fromSource(Map<String, Object> card) {
    String str(String key) => card[key] as String? ?? '';
    final original = str('originalId');
    final module = <String, GrowthModule>{
      'B': GrowthModule.belief, 'G': GrowthModule.goal, 'A': GrowthModule.action,
      'F': GrowthModule.failure, 'R': GrowthModule.review, 'C': GrowthModule.change,
    }[original[0]]!;
    final op = operatorBySource[original] ?? 'SOURCE_PRACTICE';
    final next = <GrowthModule, String>{
      GrowthModule.belief: 'G03', GrowthModule.goal: 'A02',
      GrowthModule.action: 'F03', GrowthModule.failure: 'R01',
      GrowthModule.review: 'C04', GrowthModule.change: 'B05',
    };
    return EvidenceKNode(
      id: 'KB35-$original', version: 2, module: module,
      sourceClass: str('sourceClass'), title: str('title'),
      claim: str('claim'), mechanism: str('mechanism'),
      teachingContext: str('context'), storyOrStudy: str('story'),
      howTo: [str('howTo')], misuseBoundary: [str('boundary')],
      triggers: [str('title'), if (str('trigger').isNotEmpty) str('trigger')],
      contraSignals: ['PROFESSIONAL_BOUNDARY', 'RUIN_RISK',
        if (['EXPOSURE_LADDER','SAFE_EXPOSURE','SAFE_IMPERFECTION'].contains(op)) 'PANIC_ZONE'],
      prerequisites: ['REALITY_CHECK', 'RECOVERY_CHECK',
        if (op == 'COMMITMENT_LADDER') 'COMMITMENT_CHECK',
        if (['EXPOSURE_LADDER','SAFE_EXPOSURE'].contains(op)) 'STRETCH_ZONE_CHECK'],
      operators: [op], boundaries: [str('boundary')],
      nextNodes: ['KB35-${next[module]}'],
      evidenceStrength: str('sourceClass') == 'K_TAL' ? 'COURSE_SOURCE' : 'KB_EXTERNAL_SOURCE',
      displayExcerpt: str('claim'),
      locator: EvidenceSourceLocator(document: 'KB35',
        pages: card['pages'] as List<int>, originalNodeIds: [original],
        sourceType: str('sourceClass') == 'K_TAL' ? 'COURSE_SOURCE' : 'EXPERT_EXTENSION',
        note: str('locator')),
    );
  }
}
