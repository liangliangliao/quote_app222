import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_action_facts.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_engine.dart';
import 'package:quote_app/self_os/self_os_learning.dart';
import 'package:quote_app/self_os/self_os_motive_recommendations.dart';
import 'package:quote_app/self_os/self_os_principles.dart';
import 'package:quote_app/self_os/self_os_v37_rules.dart';
import 'self_os_domain_test.dart' show plannedCase, reviewFor;
import 'self_os_principles_test.dart' show experienceSource;
import 'self_os_learning_test.dart' show observedExperiment;
import 'self_os_reality_gate_test.dart' show verifiedLimit;

SelfOsMotive sourced(String id, SelfOsCase source,
        {String side = 'for', double score = 80, String key = ''}) =>
    SelfOsMotive(
        id: id,
        title: id,
        side: side,
        predicted: score,
        semanticKey: key,
        evidenceIds: [source.reviews.single.id]);

void main() {
  test('T128/T223 旧复盘缺少机会或自主条件时保持未知，不默认推断自愿偏好', () {
    final cases = <SelfOsCase>[];
    for (var i = 0; i < 3; i++) {
      final c = plannedCase();
      final r = reviewFor(c, context: '旧情境$i')
        ..notes['sacrificedDesire'] = '舒适';
      final persisted = r.toJson();
      final notes = osMap(persisted['notes']);
      notes.remove('opportunity');
      notes.remove('autonomy');
      persisted['notes'] = notes;
      final legacy = SelfOsReview.fromJson(persisted);
      c.reviews.add(legacy);
      expect(legacy.result, r.result);
      expect(legacy.mayGeneralize, isFalse);
      cases.add(c);
    }
    expect(SelfOsEngineService.patterns(cases), isEmpty);
    expect(SelfOsEngineService.conflicts(cases), isEmpty);
    expect(
        SelfOsActionFacts.mayGeneralize({
          'evidenceUse': 'usable',
          'opportunity': 'unknown',
          'autonomy': 'voluntary'
        }),
        isFalse);
    expect(
        SelfOsActionFacts.mayGeneralize({
          'evidenceUse': 'usable',
          'opportunity': 'present',
          'autonomy': 'unknown'
        }),
        isFalse);
  });

  test('T125/T129/T134/T162 尝试、外部结果、自主条件分开，受阻不算零努力', () {
    final c = plannedCase();
    final r = reviewFor(c, outcome: 'notDone')
      ..notes.addAll({
        'attemptStatus': 'started_blocked',
        'preparation': '已整理资料并出发',
        'opportunity': 'absent',
        'autonomy': 'coerced',
        'targetStatus': 'not_acquired',
      });
    c.addReview(r);
    expect(r.actionLabel, contains('已尝试'));
    expect(r.notes['preparation'], contains('已整理资料'));
    expect(r.mayGeneralize, isFalse);
    expect(SelfOsEngineService.actionCalibrationError([c]), isNull);
    expect(r.notes['experienceCausality'], 'unknown');
  });

  test('T131/T223/T272 被迫或无机会的反复行为，不升级为稳定自愿偏好', () {
    final cases = <SelfOsCase>[];
    for (var i = 0; i < 3; i++) {
      final c = plannedCase();
      final r = reviewFor(c, context: '不同情境$i')
        ..notes.addAll({
          'servedDesire': '加班',
          'sacrificedDesire': '休息',
          'autonomy': 'coerced',
          'opportunity': 'absent',
        });
      c.addReview(r);
      cases.add(c);
    }
    expect(SelfOsEngineService.patterns(cases), isEmpty);
    expect(SelfOsEngineService.conflicts(cases), isEmpty);
  });

  for (final status in ['unknown', 'not_acquired']) {
    test('T244/T245/T250 $status 不能编造获得后满意度', () {
      expect(
          () => SelfOsActionFacts.normalize(
              {'targetStatus': status, 'realizedExperience': '想象中的长期满意'}),
          throwsFormatException);
      final normalized = SelfOsActionFacts.normalize({'targetStatus': status});
      expect(normalized['realizedExperience'], isEmpty);
      expect(normalized['targetStatus'], status);
    });
  }

  test('T244/T246 真正获得仍可满意未知，收益、负担与因果不合并', () {
    final acquired = SelfOsActionFacts.normalize({
      'targetStatus': 'acquired',
      'realizedExperience': '日常内容比原先想象更合适',
      'ongoingBurden': '通勤成本仍待持续观察'
    });
    expect(acquired['experienceCausality'], 'unknown');
    expect(acquired['ongoingBurden'], contains('通勤'));
    expect(
        SelfOsActionFacts.normalize(
            {'targetStatus': 'acquired'})['realizedExperience'],
        isEmpty);
  });

  test('T116/T365 长期预测未到窗口不能以T2改时点倒证T0', () {
    final c = observedExperiment();
    final r = c.reviews.single;
    final exp = osMap(r.snapshot['experiment']);
    final node = c.v37.nodes.firstWhere((n) => n.id == exp['nodeId']);
    node.data.addAll({
      'horizon': 'long',
      'observableAfter':
          DateTime.now().add(const Duration(days: 30)).toIso8601String()
    });
    final frozen = osMap(r.snapshot['v37']);
    frozen['nodes'] = [node.toJson()];
    r.snapshot['v37'] = frozen;
    node.data['observableAfter'] =
        DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
    expect(
        () => SelfOsLearning.calibrate(c,
            reviewId: r.id,
            verdict: 'supported',
            conclusion: '今天一次行动不能证明长期结果',
            scope: '仅当前经历',
            influence: 'unchanged'),
        throwsFormatException);
    expect(SelfOsLearning.calibrated(r), isFalse);
  });

  test('T293/T295/T296/T297 同义去重、最多五条且保留重要反方', () {
    final source = experienceSource(), c = plannedCase();
    c.motives.clear();
    c.motives.addAll([
      for (var i = 0; i < 5; i++)
        sourced('重复$i', source, key: '同一主题', score: 99),
      sourced('独立理由', source, score: 90),
      sourced('重要反方', source, side: 'against', score: 20),
    ]);
    final ranked =
        osMaps(SelfOsMotiveRecommendations.build(c, [source, c])['ranked']);
    expect(ranked, hasLength(3));
    expect(ranked.map((r) => r['motiveId']), contains('重要反方'));
    expect(c.motives, hasLength(7));
  });

  test('T298/T299/T311 未核实、已反驳和硬限制不能靠高分进入推荐', () {
    final source = experienceSource(), c = plannedCase();
    c.motives.clear();
    c.v37.routes.addAll([
      OsRoute({'id': 'blocked', 'title': '资格受限岗位'}),
      OsRoute({'id': 'safe', 'title': '另一可核实任务'})
    ]);
    c.v37.settings['changeabilityAssessments'] = [
      verifiedLimit(c, routeId: 'blocked')
    ];
    c.motives.addAll([
      sourced('危险高分', source, score: 100)..optionId = 'blocked',
      sourced('安全候选', source)..optionId = 'safe',
      sourced('已拒绝', source)..userStatus = 'rejected',
      SelfOsMotive(
          id: '未核实反方', side: 'against', importance: 90, predicted: 100),
    ]);
    final ranking = SelfOsMotiveRecommendations.build(c, [source, c]);
    expect(osMaps(ranking['ranked']).single['motiveId'], '安全候选');
    expect(ranking['pendingIds'], contains('未核实反方'));
  });

  test('T340 原则ID与推荐分不构成新的事实证据', () {
    final c = plannedCase();
    c.motives
      ..clear()
      ..add(SelfOsMotive(
          id: 'm',
          title: '高分原则',
          predicted: 100,
          evidenceIds: ['principle-id']));
    expect(SelfOsMotiveRecommendations.build(c, [c])['ranked'], isEmpty);
  });

  test('T300/T318 旧榜单冻结来源与时点，分数相近保留不稳定提示', () {
    final source = experienceSource(), c = plannedCase();
    c.motives
      ..clear()
      ..addAll([
        sourced('a', source, score: 80),
        sourced('b', source, side: 'against', score: 81)
      ]);
    SelfOsMotiveRecommendations.record(c, [source, c]);
    final before =
        jsonEncode(osMaps(c.v37.settings['motiveRecommendationRuns']).single);
    expect(SelfOsMotiveRecommendations.build(c, [source, c])['uncertainOrder'],
        isTrue);
    c.motives.first.evidenceIds.add('new-unverified-id');
    c.motives.first.title = '修改后的含义';
    SelfOsMotiveRecommendations.record(c, [source, c]);
    expect(osMaps(c.v37.settings['motiveRecommendationRuns']), hasLength(2));
    expect(jsonEncode(osMaps(c.v37.settings['motiveRecommendationRuns']).first),
        before);
  });

  test('T86/T309 同一动机的双向路线关系与前后版本共存', () {
    final c = plannedCase();
    final m = c.motives.first..importance = 90;
    final before = c.cognitiveSnapshot();
    m.routeEffects = [
      {'routeId': 'work', 'side': 'against', 'condition': '健康风险已核实'},
      {'routeId': 'rest', 'side': 'for', 'condition': '休息有现实必要'},
    ];
    final restored = SelfOsCase.fromJson(jsonDecode(jsonEncode(c.toJson())));
    expect(restored.motives.first.routeEffects, hasLength(2));
    expect(
        SelfOsV37Rules.motiveDelta(before, c.cognitiveSnapshot()), isNotEmpty);
    expect(osMaps(osMaps(before['motives']).first['routeEffects']), isEmpty);
  });

  test('T54/T231/T265/T280 撤回事实同步失效证据索引、榜单与派生助手记忆', () {
    final source = experienceSource(),
        c = plannedCase(),
        profile = SelfOsProfile();
    c.motives
      ..clear()
      ..add(sourced('sensitive', source)..title = 'PRIVATE_DERIVED');
    c.v37.evidence.add(OsEvidence({
      'id': 'derived',
      'claim': 'PRIVATE_DERIVED',
      'label': 'personal',
      'verified': true,
      'reviewId': source.reviews.single.id,
      'source': '用户复盘'
    }));
    c.guide.turns.addAll([
      {'role': 'assistant', 'text': 'PRIVATE_DERIVED'},
      {'role': 'user', 'text': '原始用户陈述'}
    ]);
    c.suggestions['action'] = [
      {'field': 'firstAction', 'value': 'PRIVATE_DERIVED'}
    ];
    SelfOsMotiveRecommendations.record(c, [source, c]);
    SelfOsPrinciples.invalidate(
        profile, [source, c], {source.reviews.single.id});
    expect(c.motives.single.userStatus, 'needs_review');
    expect(c.v37.evidence.single.verified, isFalse);
    expect(osMaps(c.v37.settings['motiveRecommendationRuns']).single['stale'],
        isTrue);
    expect(c.guide.turns.single['role'], 'user');
    expect(jsonEncode(c.toJson()), isNot(contains('PRIVATE_DERIVED')));
  });
}
