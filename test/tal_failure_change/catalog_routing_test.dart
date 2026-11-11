import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/failure_module/tal/tal_failure_change.dart';
import 'fixtures.dart';

void main() {
  final catalog = loadCatalog();
  final router = TalRouter(catalog);
  List<String> ids(Set<String> signals,
          {Set<String> rejected = const {}, Set<String> failed = const {}}) =>
      router
          .route(signals, rejected: rejected, notHelped: failed)
          .methods
          .map((r) => r.method.id)
          .toList();

  test('catalog preserves all supplied methods, cases, sources and boundaries',
      () {
    expect(catalog.methods.length, 15);
    expect(catalog.methods.keys.toSet(), TalCatalog.approvedMethodIds);
    expect(catalog.cases.length, 19);
    expect(catalog.sources.length, 18);
    final original = jsonDecode(
        File('docs/tal_failure_change/acceptance_scenarios.json')
            .readAsStringSync());
    expect(original['scenarios'], hasLength(20));
    for (final method in catalog.methods.values) {
      expect(method.sources.every(catalog.sources.containsKey), isTrue);
      expect(method.limit, isNotEmpty);
    }
    for (final story in catalog.cases) {
      expect(
          (story['mapped_method_ids'] as List)
              .every(catalog.methods.containsKey),
          isTrue);
      expect(story['mapping_disclaimer'], isNotEmpty);
    }
    expect(catalog.storiesFor(null).first['id'], 'C18');
    expect(catalog.methods['prp']!.provenance, 'tal_original_exercise');
    expect(catalog.methods['three_ms']!.provenance, 'tal_lecture');
    expect(catalog.methods['trial_error']!.provenance, 'tal_autobiography');
  });
  test(
      'T02 unknown causes stay unknown: no signal invents an unconscious cause',
      () {
    final result = router.route({});
    expect(ids({}), ['explore_failures']);
    expect(result.methods.single.uncertainty, contains('尚不能确定原因'));
  });
  test(
      'T03 catastrophizing recommends 3Ms, each recommendation has evidence and limits',
      () {
    final result = router.route({'catastrophizing'});
    expect(result.methods.first.method.id, 'three_ms');
    expect(result.methods.first.basis, ['catastrophizing']);
    expect(result.methods.first.whenToSwitch, contains('没有帮助'));
    expect(result.methods.first.method.limit, contains('证据'));
  });
  test('T04 rational goal exit has no failure label or training coercion', () {
    final result = router
        .route({'rational_decline', 'hard_to_start', 'user_chooses_goal'});
    expect(result.route, 'review_goal_no_failure_label');
    expect(result.methods, isEmpty);
  });
  test('T05 pending / no data blocks automatic reflection', () {
    expect(
        router.route({'no_confirmed_missed'}).route, 'do_not_trigger_failure');
  });
  test('T06 kindling abort overrides all training rules', () {
    expect(router.route({'kindling_aborted', 'self_condemnation'}).methods,
        isEmpty);
  });
  test(
      'T07 failed five-minute method is excluded; other failed and rejected methods too',
      () {
    final signals = {
      'user_chooses_goal',
      'hard_to_start',
      'physical_conditions_ok',
      'prior_method_not_helped',
      'user_wants_new_trial'
    };
    expect(ids(signals), isNot(contains('five_minute_takeoff')));
    expect(ids(signals), contains('trial_error'));
    expect(ids(signals, failed: {'trial_error'}, rejected: {'abc_change'}),
        isNot(anyOf(contains('trial_error'), contains('abc_change'))));
    expect(
        ids({
          'user_chooses_goal',
          'hard_to_start',
          'physical_conditions_ok',
          'prior_method_not_helped',
          'user_asks_to_retry'
        }),
        contains('five_minute_takeoff'));
  });
  test(
      'T08 challenge must be explicitly safe before any exposure recommendation',
      () {
    expect(ids({'avoids_due_to_failure_fear', 'challenge_too_large'}),
        isNot(anyOf(contains('learn_to_fail'), contains('stretch_zone'))));
    expect(ids({'avoids_due_to_failure_fear', 'challenge_is_safe'}),
        ['learn_to_fail', 'stretch_zone']);
  });
  test('T09 Unbundling requires expressed value conflict and willingness', () {
    expect(
        ids({
          'valued_positive_trait_linked_to_negative_trait',
          'user_interested_in_exploration'
        }),
        ['unbundling']);
    expect(ids({'hard_to_start'}), isNot(contains('unbundling')));
  });
  test('T10 emotional distress never forces benefit finding', () {
    expect(ids({'high_emotional_distress'}), ['permission_to_be_human']);
    expect(ids({'user_requests_benefit_finding'}),
        isNot(contains('benefit_finding')));
    expect(ids({'user_requests_benefit_finding', 'emotionally_ready'}),
        ['benefit_finding']);
  });
  test(
      'T14 stories are exactly catalog facts, not AI-generated first-person dialogue',
      () {
    final c18 = catalog.storiesFor('prp').single;
    expect(c18['reported_action'], contains('陪女儿悠闲散步'));
    expect(c18['reported_outcome'], contains('无完整追踪证据'));
    final c15 = catalog.cases.singleWhere((s) => s['id'] == 'C15');
    expect(c15['evidence_level'], 'external_report');
    expect(c15['reported_action'], contains('补救公平性'));
  });
  test('T18 crisis exit takes precedence even over rational goal review', () {
    expect(router.route({'crisis_warning', 'rational_decline'}).route,
        'safety_exit');
  });
  test(
      'literal observations keep quotations, handle negation and do not infer readiness',
      () {
    final signals =
        TalRouter.observedSignals('今天没做，说明我一辈子没希望。五分钟法试过很多次没有用。我有点困，也记不清原因。');
    expect(signals['catastrophizing'], '一辈子没希望');
    expect(signals.keys,
        containsAll(['prior_method_not_helped', 'fatigue_or_sleep_concern']));
    expect(signals.keys, isNot(contains('physical_conditions_ok')));
    expect(signals.keys, isNot(contains('challenge_is_safe')));
    expect(ids(signals.keys.toSet()).first, 'three_ms');
    expect(TalRouter.observedSignals('我不认为我一辈子没希望'), isEmpty);
    expect(TalRouter.observedSignals('我想摆脱焦虑，却怕失去责任心'),
        contains('valued_positive_trait_linked_to_negative_trait'));
  });
  test('fatigue is not reduced to lack of willpower; methods are capped at two',
      () {
    final signals = {
      'fatigue_or_sleep_concern',
      'user_chooses_goal',
      'hard_to_start',
      'physical_conditions_ok',
      'cannot_repeat'
    };
    expect(ids(signals), isNot(contains('five_minute_takeoff')));
    expect(ids(signals), contains('spire'));
    expect(ids(signals).length, lessThanOrEqualTo(2));
  });
}
