import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/evidence_growth/evidence_growth_knowledge.dart';
import 'package:quote_app/evidence_growth/evidence_growth_router.dart';

void main() {
  const router = EvidenceGrowthRouter();
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
    expect(result.selectedNodes.first.id, 'TAL-A02');
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
