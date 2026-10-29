import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_principles.dart';
import 'package:quote_app/self_os/self_os_reality.dart';
import 'package:quote_app/self_os/self_os_v37_rules.dart';
import 'package:quote_app/self_os/self_os_guidance.dart';
import 'package:quote_app/self_os/self_os_progress.dart';
import 'self_os_domain_test.dart' show plannedCase;
import 'self_os_guide_test.dart' show experimentGuide;
import 'self_os_principles_test.dart' show experienceSource, principleFor;

Map<String, dynamic> verifiedLimit(SelfOsCase c, {String routeId = ''}) {
  c.v37.evidence.add(OsEvidence({
    'id': 'qualification',
    'claim': '本岗位需要尚未取得的法定资格',
    'label': 'external',
    'source': '用户核对的任务资格原文',
    'verified': true,
    'contradiction': 'clear',
    'observedAt': DateTime.now().toIso8601String()
  }));
  return SelfOsReality.assess(c, {
    'fact': '本岗位资格尚不满足',
    'task': c.problem,
    'routeId': routeId,
    'classification': 'hard_limit_for_task',
    'evidenceIds': ['qualification'],
    'reason': '核对了本岗位的实际资格要求',
    'nextAction': '暂停此岗位路线，核实其他岗位或培训途径',
    'reviewAt': '获得新资格后'
  });
}

void main() {
  test('T347 高动机分、优势和用户勾选都不能覆盖已核实任务资格', () {
    final source = experienceSource(), c = plannedCase();
    c.v37.settings['changeabilityAssessments'] = [verifiedLimit(c)];
    for (final m in c.motives) {
      m.predicted = 100;
    }
    c.scores['planProbability'] = 100;
    expect(
        c.commit,
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'reason', contains('限制'))));
    expect(
        () => SelfOsPrinciples.choose(c, principleFor([source]), [source, c],
            contextMatches: true, safe: true),
        throwsFormatException);
    expect(c.commitment, isNull);
  });

  test('T347 低成本实验和已封存协议仍需核对新出现的硬限制', () {
    final c = experimentGuide();
    c.v37.settings['changeabilityAssessments'] = [verifiedLimit(c)];
    expect(() => SelfOsGuidance.commitExperiment(c), throwsFormatException);
    final sealed = experimentGuide();
    SelfOsGuidance.commitExperiment(sealed);
    sealed.v37.settings['changeabilityAssessments'] = [verifiedLimit(sealed)];
    expect(SelfOsProgress.actionBlocker(sealed), contains('限制'));
  });

  test('T348 特定路线限制不封锁新路线；不明或虚构路线不能用来绕过核验', () {
    final source = experienceSource(), c = plannedCase();
    c.v37.routes.addAll([
      OsRoute({'id': 'licensed', 'title': '有法定资格的岗位'}),
      OsRoute({'id': 'alternative', 'title': '核实不同资格要求的低风险任务'})
    ]);
    c.v37.settings['changeabilityAssessments'] = [
      verifiedLimit(c, routeId: 'licensed')
    ];
    expect(SelfOsV37Rules.taskLimit(c.v37, routeId: 'alternative'), isNull);
    expect(
        SelfOsV37Rules.taskLimit(c.v37, routeId: 'licensed'), contains('限制'));
    expect(SelfOsV37Rules.taskLimit(c.v37, routeId: ''), isNotNull);
    c.fields['routeId'] = 'invented';
    expect(c.commit, throwsFormatException);
    expect(
        () => SelfOsPrinciples.choose(c, principleFor([source]), [source, c],
            contextMatches: true, safe: true),
        throwsFormatException);
    c.fields['routeId'] = 'alternative';
    SelfOsPrinciples.choose(c, principleFor([source]), [source, c],
        contextMatches: true, safe: true);
    expect(SelfOsPrinciples.applications(c), hasLength(1));
  });

  test('T352 同一事实的新支持证据可以修订限制，保留旧记录而不认定永远不行', () {
    final c = plannedCase();
    final before = verifiedLimit(c);
    final after = SelfOsReality.assess(c, {
      ...before,
      'evidenceIds': ['qualification'],
      'classification': 'modifiable_with_support',
      'reason': '新核实的制度允许合规培训后申请',
      'support': '先完成培训与资格复核',
      'nextAction': '咨询合规培训条件'
    });
    c.v37.settings['changeabilityAssessments'] = [before, after];
    expect(after['factId'], before['factId']);
    expect(after['version'], 2);
    expect(SelfOsReality.currentAssessments(c), hasLength(1));
    expect(SelfOsV37Rules.taskLimit(c.v37), isNull);
    expect(
        osMaps(c.v37.settings['changeabilityAssessments'])
            .first['classification'],
        'hard_limit_for_task');
  });
}
