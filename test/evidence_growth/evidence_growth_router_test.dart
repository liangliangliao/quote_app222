import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/evidence_growth/evidence_growth_knowledge.dart';
import 'package:quote_app/evidence_growth/evidence_growth_router.dart';
import 'package:quote_app/evidence_growth/evidence_growth_operator_registry.dart';

void main() {
  const router = EvidenceGrowthRouter();
  test('unsupported non-empty input and Panic do not fall through to action', () {
    expect(router.route('巴黎现在天气怎么样').evidenceLevel, 'E0');
    expect(router.route('我已经惊恐发作，仍然逼自己继续暴露').canAct, isFalse);
  });
  test('all source records have meaningful fields and registered operators', () {
    for (final node in EvidenceGrowthKnowledge.nodes) {
      expect(node.teachingContext, isNotEmpty, reason: node.id);
      expect(node.storyOrStudy, isNotEmpty, reason: node.id);
      expect(node.howTo.single, isNotEmpty, reason: node.id);
      expect(node.misuseBoundary.single, isNotEmpty, reason: node.id);
      expect(node.locator.originalNodeIds, isNotEmpty);
      expect(node.mechanism, isNotEmpty, reason: node.id);
      expect(node.nextNodes.every((id) => EvidenceGrowthKnowledge.byId(id) != null), isTrue);
      expect(node.operators.every(EvidenceGrowthOperatorRegistry.ids.contains), isTrue);
    }
    expect(EvidenceGrowthKnowledge.source('G-EXT2-01').sourceClass, 'K_EXT2');
    expect(EvidenceGrowthKnowledge.source('R-EXT2-01').locator.pages, contains(191));
    expect(EvidenceGrowthKnowledge.source('B-AUDIT-01').locator.pages, contains(2));
    expect(EvidenceGrowthKnowledge.nodes.any((n) => n.title.contains('Fogg')), isFalse);
  });
  test('P0 knowledge has 60+ Tal nodes, expert layers, sources and cases', () {
    expect(EvidenceGrowthKnowledge.talNodes.length, greaterThanOrEqualTo(60));
    expect(EvidenceGrowthKnowledge.extensionNodes.length, greaterThanOrEqualTo(20));
    expect(EvidenceGrowthKnowledge.defaultCases.length, greaterThanOrEqualTo(20));
    expect(EvidenceGrowthKnowledge.nodes.every((n) => n.locator.pages.isNotEmpty && n.boundaries.isNotEmpty), isTrue);
  });
  final scenarios = <(String, String)>[
    ('我知道要投简历，但没开始，一直等待动力。', 'START_5_MIN'),
    ('我一直改作品，不敢发给别人看。', 'SAFE_EXPOSURE'),
    ('我一上床手就自动点开短视频。', 'CONTEXT_REDESIGN'),
    ('目标明确但不知道今天下一步做什么。', 'GAP_OPERATOR'),
    ('面试失败说明我天生不适合。', 'FAILURE_REFRAME'),
    ('我复盘很多但都只是感想。', 'PDSA_REVIEW'),
    ('坚持两年没结果，不知道继续还是退出。', 'ACT_ADJUST_EXIT'),
    ('我要完全像电影主角一样生活。', 'ROLE_MODEL_TRANSFER'),
    ('换了很多方法还是反复，是系统结构问题。', 'SYSTEM_SCAN'),
  ];
  for (var i = 0; i < scenarios.length; i++) {
    test('S${i + 1} routes through Tal to expected operator', () {
      final result = router.route(scenarios[i].$1);
      expect(result.operator, scenarios[i].$2);
      expect(result.selectedNodes.first.isTal, isTrue);
    });
  }
  test('N1 exhaustion recovers before five-minute action', () {
    final result = router.route('三天没睡好，精疲力尽但必须继续。');
    expect(result.operator, 'RECOVER');
    expect(result.selectedNodes.first.id, 'KB35-A-AUDIT-01');
  });
  test('N2 irreversible bet is blocked by Ruin Gate', () {
    final result = router.route('辞职借债，把全部积蓄押上。');
    expect(result.status, 'RUIN_RISK');
    expect(result.riskGate, 'BLOCK');
  });
  test('N3 correlation does not become causation', () {
    final result = router.route('每次戴红帽都失败，所以一定是红帽造成的。');
    expect(result.operator, 'CAUSAL_LEVEL_CHECK');
  });
  test('N4 extensions never precede Tal', () {
    final result = router.route('我没开始，一直等待动力。');
    expect(result.selectedNodes.first.isTal, isTrue);
  });
  test('N5 insufficient evidence is explicit E0', () {
    final result = router.route('嗯');
    expect(result.status, 'KB_EVIDENCE_INSUFFICIENT');
    expect(result.evidenceLevel, 'E0');
  });
  test('professional boundary blocks action', () {
    final result = router.route('告诉我应该停药并调整药物剂量。');
    expect(result.status, 'PROFESSIONAL_ESCALATION');
    expect(result.riskGate, 'BLOCK');
  });
}
