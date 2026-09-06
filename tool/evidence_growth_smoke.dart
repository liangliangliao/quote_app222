import '../lib/evidence_growth/evidence_growth_knowledge.dart';
import '../lib/evidence_growth/evidence_growth_router.dart';

void main() {
  if (EvidenceGrowthKnowledge.talNodes.length < 60) throw StateError('Tal coverage below P0');
  if (EvidenceGrowthKnowledge.defaultCases.length < 20) throw StateError('Case coverage below P0');
  for (final node in EvidenceGrowthKnowledge.nodes) {
    if (node.locator.pages.isEmpty || node.boundaries.isEmpty || node.triggers.isEmpty || node.operators.isEmpty) {
      throw StateError('Incomplete node ${node.id}');
    }
  }
  const router = EvidenceGrowthRouter();
  final checks = <(String, String, String)>[
    ('我知道要投简历，但没开始，一直等待动力。', 'READY_FOR_ACTION', 'START_5_MIN'),
    ('我三天没睡好，已经精疲力尽。', 'READY_FOR_ACTION', 'RECOVER'),
    ('我一直改作品，不敢发给别人看。', 'READY_FOR_ACTION', 'SAFE_EXPOSURE'),
    ('我一上床手就自动点开短视频。', 'READY_FOR_ACTION', 'CONTEXT_REDESIGN'),
    ('目标明确但不知道今天下一步做什么。', 'READY_FOR_ACTION', 'GAP_OPERATOR'),
    ('面试失败说明我天生不适合。', 'READY_FOR_ACTION', 'FAILURE_REFRAME'),
    ('我复盘很多但都只是感想。', 'READY_FOR_ACTION', 'PDSA_REVIEW'),
    ('坚持两年没结果，不知道继续还是退出。', 'READY_FOR_ACTION', 'ACT_ADJUST_EXIT'),
    ('我要完全像电影主角一样生活。', 'READY_FOR_ACTION', 'ROLE_MODEL_TRANSFER'),
    ('换了很多方法还是反复，是系统结构问题。', 'READY_FOR_ACTION', 'SYSTEM_SCAN'),
    ('每次戴红帽都失败，所以一定是红帽造成的。', 'READY_FOR_ACTION', 'CAUSAL_LEVEL_CHECK'),
    ('我想借债，把全部积蓄押在未经验证的项目上。', 'RUIN_RISK', ''),
  ];
  for (final (input, status, operator) in checks) {
    final result = router.route(input);
    if (result.status != status || result.operator != operator) {
      throw StateError('$input -> ${result.status}/${result.operator}; expected $status/$operator');
    }
    if (result.selectedNodes.isNotEmpty && !result.selectedNodes.first.isTal) throw StateError('Tal-first violated');
  }
  print('Evidence growth smoke passed: ${checks.length}; Tal=${EvidenceGrowthKnowledge.talNodes.length}; EXT=${EvidenceGrowthKnowledge.extensionNodes.length}');
}
