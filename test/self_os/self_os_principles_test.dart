import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_principles.dart';
import 'package:quote_app/self_os/self_os_reality.dart';
import 'self_os_domain_test.dart' show plannedCase, reviewFor;

SelfOsCase experienceSource(
    {String capability = 'strength', bool shared = true}) {
  final c = plannedCase();
  c.v37.settings['shareExperience'] = shared;
  c.addReview(reviewFor(c)..notes['capability'] = capability);
  return c;
}

Map<String, dynamic> principleFor(List<SelfOsCase> sources,
    {bool accepted = true, List<String> counters = const []}) {
  final p = SelfOsPrinciples.candidate(
      {
        'condition': '招聘资料可核实时',
        'rule': '先核对真实岗位条件，再准备资料',
        'notApplicable': '岗位变化或健康安全条件不符',
        'riskGate': '安全资格与对方同意必须满足',
        'exception': '出现新要求、反例或支持条件变化',
        'nextTest': '下次记录是否想起、实际做过什么和观察结果',
      },
      sources
          .expand((c) => c.reviews)
          .map((r) => r.id)
          .where((id) => !counters.contains(id))
          .toList(),
      counters,
      sources);
  if (accepted) SelfOsPrinciples.setStatus(p, 'user_accepted', sources);
  return p;
}

void main() {
  test('T327/T328 多次与单次真实经历都有出处，均不升级为永久规律', () {
    final a = experienceSource(), b = experienceSource();
    final single = principleFor([a]), multiple = principleFor([a, b]);
    expect(single['maturity'], 'tentative');
    expect(multiple['maturity'], 'tentative');
    expect(multiple['evidenceIds'], [a.reviews.single.id, b.reviews.single.id]);
    expect(multiple['counterSearch'], contains('不代表没有反例'));
  });

  test('T329 不同情境与反例并存，不能将支持和反例混写为同一事实', () {
    final a = experienceSource(), b = experienceSource();
    final p = principleFor([a, b], counters: [b.reviews.single.id]);
    expect(p['counterEvidenceIds'], [b.reviews.single.id]);
    expect(p['notApplicable'], isNotEmpty);
    expect(
        () => SelfOsPrinciples.candidate({'rule': '绝对执行'},
            [a.reviews.single.id], [a.reviews.single.id], [a]),
        throwsFormatException);
  });

  test('T330/T331 未认可、拒绝和归档不默认用于新案例，可重新讨论', () {
    final source = experienceSource(), c = plannedCase();
    final p = principleFor([source], accepted: false);
    final profile = SelfOsProfile()..principles.add(p);
    expect(p['status'], 'draft');
    for (final status in ['draft', 'user_rejected', 'retired']) {
      SelfOsPrinciples.setStatus(p, status, [source]);
      expect(SelfOsPrinciples.eligible(profile, [source, c], c), isEmpty);
    }
    SelfOsPrinciples.setStatus(p, 'user_accepted', [source]);
    expect(SelfOsPrinciples.eligible(profile, [source, c], c), hasLength(1));
  });

  test('T332 修订保留旧版和T0应用快照，旧版本修改冲突报错', () {
    final source = experienceSource(), c = plannedCase();
    final p = principleFor([source]);
    final a = SelfOsPrinciples.choose(c, p, [source, c],
        contextMatches: true, safe: true);
    final frozen = jsonEncode(a['principleSnapshot']);
    SelfOsPrinciples.revise(p, {'rule': '先确认截止日期'}, expectedVersion: 1);
    expect(p['version'], 2);
    expect(p['status'], 'draft');
    expect(osMaps(p['history']).single['rule'], contains('岗位条件'));
    expect(
        jsonEncode(
            SelfOsPrinciples.applications(c).single['principleSnapshot']),
        frozen);
    expect(
        () => SelfOsPrinciples.revise(p, {'rule': '过期修改'}, expectedVersion: 1),
        throwsFormatException);
  });

  for (final situation in [(false, true), (true, false)]) {
    test('T333/T347 条件或安全不符合时不可选入：$situation', () {
      final source = experienceSource(), c = plannedCase();
      expect(
          () => SelfOsPrinciples.choose(c, principleFor([source]), [source, c],
              contextMatches: situation.$1, safe: situation.$2),
          throwsFormatException);
      expect(SelfOsPrinciples.applications(c), isEmpty);
    });
  }

  test('T334/T335 事前选择和打开卡不自动产生想起、采用与行动证据', () {
    final source = experienceSource(), c = plannedCase();
    final a = SelfOsPrinciples.choose(c, principleFor([source]), [source, c],
        contextMatches: true, safe: true);
    SelfOsPrinciples.recordExposure(c, a['id'], 'delivered');
    var delivered = SelfOsPrinciples.applications(c).single;
    expect(delivered['exposureStatus'], 'delivered');
    expect(delivered['recallStatus'], 'unknown');
    expect(delivered['applicationStatus'], 'unknown');
    expect(delivered['atT1'], isNull);
    SelfOsPrinciples.checkIn(c, a['id'], 'unknown');
    final loaded = SelfOsPrinciples.applications(c).single;
    expect(loaded['exposureStatus'], 'opened');
    expect(loaded['recallStatus'], 'unknown');
    expect(loaded['applicationStatus'], 'unknown');
    expect(loaded['observationIds'], isEmpty);
    expect(c.reviews, isEmpty);
  });

  test('T333 现场新信息触发重审，不机械执行', () {
    final source = experienceSource(), c = plannedCase();
    final a = SelfOsPrinciples.choose(c, principleFor([source]), [source, c],
        contextMatches: true, safe: true);
    SelfOsPrinciples.checkIn(c, a['id'], 'context_changed',
        newInformation: '岗位资格已变化');
    expect(c.v37.flag('requiresReconsideration'), isTrue);
    expect(c.text('newInformation'), '岗位资格已变化');
    expect(SelfOsPrinciples.applications(c).single['applicationStatus'],
        'unknown');
  });

  test('T336 受阻时真实准备不清零，采用、尝试和外部结果分开', () {
    final source = experienceSource(), c = plannedCase();
    final p = principleFor([source]), profile = SelfOsProfile();
    profile.principles.add(p);
    final a = SelfOsPrinciples.choose(c, p, [source, c],
        contextMatches: true, safe: true);
    final r = reviewFor(c, outcome: 'notDone');
    c.addReview(r);
    SelfOsPrinciples.review(c, profile, a['id'], r,
        use: 'applied_self_report',
        attempt: 'blocked',
        preparation: '已核对岗位并整理资料',
        effect: 'unknown');
    final saved = SelfOsPrinciples.applications(c).single;
    expect(saved['preparation'], contains('整理资料'));
    expect(saved['applicationStatus'], 'applied_self_report');
    expect(saved['attemptStatus'], 'blocked');
    expect(saved['observedOutcome'], 'notDone');
    expect(saved['causalConclusion'], 'unknown');
  });

  test('T337 完成结果不证明原则起效，事后反馈不能倒填T1', () {
    final source = experienceSource(), c = plannedCase();
    final p = principleFor([source]),
        profile = SelfOsProfile()..principles.add(p);
    final a = SelfOsPrinciples.choose(c, p, [source, c],
        contextMatches: true, safe: true);
    final r = reviewFor(c);
    c.addReview(r);
    SelfOsPrinciples.review(c, profile, a['id'], r,
        use: 'unknown',
        attempt: 'completed',
        preparation: '',
        effect: 'unknown');
    final saved = SelfOsPrinciples.applications(c).single;
    expect(saved['atT1'], isNull);
    expect(saved['applicationStatus'], 'unknown');
    expect(saved['observedOutcome'], 'done');
    expect(saved['causalConclusion'], 'unknown');
    expect(() => SelfOsPrinciples.checkIn(c, a['id'], 'explicitly_recalled'),
        throwsFormatException);
  });

  test('T338/T359 反例修订版本并降级，不因单次偏离贴道德标签', () {
    final source = experienceSource(), c = plannedCase();
    final p = principleFor([source]),
        profile = SelfOsProfile()..principles.add(p);
    final a = SelfOsPrinciples.choose(c, p, [source, c],
        contextMatches: true, safe: true);
    final r = reviewFor(c);
    c.addReview(r);
    SelfOsPrinciples.review(c, profile, a['id'], r,
        use: 'not_applied',
        attempt: 'rerouted',
        preparation: '按新信息核实后改道',
        effect: 'not_helped',
        counterExample: true);
    expect(p['status'], 'needs_review');
    expect(p['version'], 2);
    expect(p['counterEvidenceIds'], [r.id]);
    expect(SelfOsPrinciples.applications(c).single['principleVersion'], 1);
    expect(p['revisionReason'], contains('检查条件'));
  });

  test('T339/T363 撤回传播清除原则、版本与应用解释，并移除力量观察', () {
    final source = experienceSource(), c = plannedCase();
    final p = principleFor([source]),
        profile = SelfOsProfile()..principles.add(p);
    profile.strengths.add(OsStrength({
      'id': 's',
      'observations': [
        {'reviewId': source.reviews.single.id}
      ]
    }));
    SelfOsPrinciples.choose(c, p, [source, c],
        contextMatches: true, safe: true);
    SelfOsPrinciples.invalidate(
        profile, [source, c], {source.reviews.single.id});
    expect(p['staleReason'], 'stale_due_to_revocation');
    expect(p['history'], isEmpty);
    expect(p['rule'], isNot(contains('岗位')));
    expect(
        SelfOsPrinciples.applications(c).single['principleSnapshot'], isEmpty);
    expect(
        SelfOsPrinciples.applications(c).single['exposureStatus'], 'cancelled');
    expect(profile.strengths.single.observations, isEmpty);
    expect(SelfOsPrinciples.eligible(profile, [source, c], c), isEmpty);
  });

  test('T342/T360 一轮先选一条，暂停后可选择不同原则，不强制统一人格故事', () {
    final source = experienceSource(), c = plannedCase();
    final p = principleFor([source]), another = principleFor([source]);
    final a = SelfOsPrinciples.choose(c, p, [source, c],
        contextMatches: true, safe: true, opposingReason: '仍需保留休息和安全的价值');
    expect(
        () => SelfOsPrinciples.choose(c, another, [source, c],
            contextMatches: true, safe: true),
        throwsFormatException);
    SelfOsPrinciples.pause(c, a['id']);
    SelfOsPrinciples.choose(c, another, [source, c],
        contextMatches: true, safe: true);
    expect(SelfOsPrinciples.applications(c), hasLength(2));
    expect(SelfOsPrinciples.applications(c).first['opposingReason'],
        contains('休息'));
  });

  test('T343/T348 无可靠经验不伪造原则或永久能力判断，原案例仍可复盘', () {
    final c = plannedCase(), profile = SelfOsProfile();
    expect(SelfOsPrinciples.evidence([c]), isEmpty);
    expect(SelfOsPrinciples.eligible(profile, [c], c), isEmpty);
    expect(SelfOsReality.opportunities([c], c), isEmpty);
    c.addReview(reviewFor(c));
    expect(c.reviewed, isTrue);
  });

  test('跨Case许可缺省关闭；认可不授予历史来源跨案例权限', () {
    final source = experienceSource(shared: false), c = plannedCase();
    final profile = SelfOsProfile()..principles.add(principleFor([source]));
    expect(SelfOsPrinciples.eligible(profile, [source, c], c), isEmpty);
    source.v37.settings['shareExperience'] = true;
    expect(SelfOsPrinciples.eligible(profile, [source, c], c), hasLength(1));
  });

  test('T365 未来才记录的事实和未来才建立的原则不能用于T0', () {
    final c = experienceSource();
    final p = principleFor([c]);
    final before =
        c.reviews.single.createdAt.subtract(const Duration(seconds: 1));
    expect(SelfOsPrinciples.evidence([c], knownAt: before), isEmpty);
    expect(SelfOsPrinciples.unavailable(p, [c], knownAt: before), isNotNull);
    final oldTime = DateTime.now();
    p['updatedAt'] = oldTime.add(const Duration(seconds: 1)).toIso8601String();
    expect(
        SelfOsPrinciples.unavailable(p, [c], knownAt: oldTime), contains('版本'));
    expect(
        () => SelfOsPrinciples.candidate({'rule': '假来源'}, ['made-up'], [], [c]),
        throwsFormatException);
  });

  for (final fit in const {
    'strength': 'demonstrated_strength',
    'trainable': 'trainable_gap',
    'variable': 'variable_state',
    'support': 'fit_with_support',
    'limit': 'unknown',
    'misfit': 'task_mismatch',
  }.entries) {
    test('T344–T346 任务级能力分类与出处：${fit.key}', () {
      final source = experienceSource(capability: fit.key), c = plannedCase();
      final m = SelfOsReality.opportunities([source, c], c).single;
      expect(m['classification'], fit.value);
      expect(m['evidenceId'], source.reviews.single.id);
      expect(m['task'], source.problem);
      expect(m.containsKey('personalityScore'), isFalse);
    });
  }

  test('T350 过去事实需已发生的时点与来源，接受和补救分开', () {
    final c = experienceSource();
    final a = SelfOsReality.assess(c, {
      'fact': '昨天申请截止',
      'task': '核实补录机会',
      'classification': 'irreversible_past',
      'happenedAt':
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'reason': '已查看实际截止时间',
      'evidenceIds': [c.reviews.single.id],
      'nextAction': '询问是否有补录渠道',
    });
    expect(a['classification'], 'irreversible_past');
    expect(a['safeAlternatives'], contains('询问是否有补录渠道'));
    expect(a['acceptanceBoundary'], contains('责任'));
  });

  test('T351/T352 可干预与支持成本需要具体依据、动作和复核', () {
    final c = experienceSource();
    for (final kind in [
      'modifiable_now',
      'modifiable_with_support',
      'externally_dependent'
    ]) {
      final a = SelfOsReality.assess(c, {
        'fact': '任务需要多人协作',
        'task': '准备材料',
        'classification': kind,
        'evidenceIds': [c.reviews.single.id],
        'reason': '已确认可以协作',
        'support': '征得同事同意，使用共享清单',
        'nextAction': '询问一次可协作的时间',
        'reviewAt': '收到回复后',
      });
      expect(a['classification'], kind);
      expect(a['support'], contains('同意'));
      expect(a['reviewAt'], '收到回复后');
    }
  });

  test('T353 没有可靠依据不能宣布不可改变，也不能把未来当过去', () {
    final c = experienceSource();
    final empty = {
      'fact': '目前做不到',
      'task': '具体任务',
      'nextAction': '先核实所需资格',
      'classification': 'hard_limit_for_task'
    };
    expect(SelfOsReality.assess(c, empty)['classification'], 'uncertain');
    expect(
        SelfOsReality.assess(c, {
          ...empty,
          'classification': 'irreversible_past',
          'happenedAt':
              DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          'evidenceIds': [c.reviews.single.id],
          'reason': '用户推测'
        })['classification'],
        'uncertain');
  });

  for (final fact in ['暴力威胁', '受到歧视', '被强迫危险工作']) {
    test('T354 安全与求助优先：$fact', () {
      final c = plannedCase();
      final a = SelfOsReality.assess(c, {
        'fact': fact,
        'task': '继续工作',
        'classification': 'irreversible_past',
        'nextAction': '忍耐过去'
      });
      expect(a['safetyConcern'], isTrue);
      expect(osStrings(a['safeAlternatives']).join(), contains('保护安全'));
      expect(osStrings(a['safeAlternatives']).join(), isNot(contains('忍耐')));
    });
  }

  test('T355–T358 反事实、他人自主、义务与情绪允许并存', () {
    final c = plannedCase();
    final a = SelfOsReality.assess(c, {
      'fact': '对方这次拒绝',
      'task': '商议分工',
      'nextAction': '表达一次事实与自己的边界',
      'ownAction': '说明条件',
      'otherChoice': '对方可以拒绝自愿协作',
      'obligation': '核实合同约定，必要时通过适当合法渠道求助',
    });
    expect(a['counterfactualBoundary'], contains('不确定'));
    expect(a['otherChoice'], contains('可以拒绝'));
    expect(a['obligation'], contains('合法渠道'));
    expect(a['acceptanceBoundary'], contains('悲伤、愤怒'));
  });
}
