import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_v37_rules.dart';
import 'package:quote_app/self_os/self_os_insights.dart';
import 'self_os_domain_test.dart' show plannedCase, reviewFor;

SelfOsV37 decision({String risk = 'low'}) {
  final s = SelfOsV37()..settings.addAll({'risk': risk, 'reversible': true});
  s.routes.addAll([
    OsRoute({'id': 'a', 'title': '尝试', 'mechanism': 'current'}),
    OsRoute({'id': 'b', 'title': '等待', 'mechanism': 'wait'}),
  ]);
  return s;
}

OsEvidence proof({String id = 'proof', DateTime? now}) => OsEvidence({
      'id': id,
      'claim': '有来源的记录',
      'label': 'personal',
      'source': '行动日志 1',
      'verified': true,
      'contradiction': 'clear',
      'observedAt': (now ?? DateTime.now())
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
    });

OsConsequence node(String id, int order,
        {String route = 'a', String label = 'inference'}) =>
    OsConsequence({
      'id': id,
      'routeId': route,
      'title': '状态 $order',
      'order': order,
      'horizon': order == 1
          ? 'now'
          : order == 2
              ? 'near'
              : 'long',
      'valence': 'mixed',
      'concrete': '可观察的状态改变',
      'label': label,
      'evidenceIds': ['proof'],
      'relevance': 'high',
    });

OsCausalEdge link(String from, String to, {String label = 'inference'}) =>
    OsCausalEdge({
      'id': '$from-$to',
      'from': from,
      'to': to,
      'label': label,
      'condition': '条件持续满足',
      'basis': '对应实际观察',
      'evidenceIds': ['proof'],
    });

void main() {
  test('有限展示预算先覆盖竞争路线，不让第一条路线的分支吞掉其他未来', () {
    final s = decision()..evidence.add(proof());
    for (var i = 0; i < 8; i++) {
      s.nodes.add(node('a$i', 1));
    }
    s.nodes.add(node('b0', 1, route: 'b'));
    final paths = SelfOsV37Rules.causalPaths(s);
    expect(paths, hasLength(7));
    expect(paths.any((p) => p.nodes.first.routeId == 'b'), isTrue);
    s.nodes.add(node('orphan', 3));
    expect(
        SelfOsV37Rules.representationGaps(s)
            .any((g) => g.key == 'a:conditional'),
        isTrue);
  });
  // Each family changes semantic structure, then checks invariance under domain
  // wording and option order. No classifier may depend on example keywords.
  final families = <String, (void Function(SelfOsV37), String)>{
    '单一路径与替代盲点': ((s) => s.routes.removeLast(), 'option'),
    '只看收益或只看损失': (
      (s) => s.nodes.add(node('n', 1)..data['valence'] = 'benefit'),
      'valence'
    ),
    '长程与重复的时间截断': (
      (s) {
        s.settings['longHorizon'] = true;
        s.nodes.add(node('n', 1));
      },
      'temporal'
    ),
    '把中间状态误当终点': (
      (s) {
        s.settings['longHorizon'] = true;
        s.nodes.add(node('n', 1));
      },
      'causal'
    ),
    '抽象口号没有现实含义': (
      (s) => s.nodes.add(node('n', 1)..data['concrete'] = ''),
      'abstraction'
    ),
    '单次后果冒充重复累积': (
      (s) {
        s.settings['repeated'] = true;
        s.nodes.add(node('n', 1));
      },
      'cumulative'
    ),
    '必然叙事缺少条件': (
      (s) {
        s.nodes.addAll([node('n', 1), node('m', 2)]);
        s.edges.add(link('n', 'm')..data['condition'] = '');
      },
      'conditional'
    ),
  };
  for (final family in families.entries) {
    test('GMRC 回归：${family.key}，领域/措辞/顺序不变性', () {
      List<String>? baseline;
      for (final domain in ['职业机会', '亲密关系', '学习技能', '健康习惯', '财务选择', '照护责任']) {
        final s = decision();
        family.value.$1(s);
        for (final r in s.routes) {
          r.data['title'] = '$domain 的不同说法 ${r.id}';
        }
        s.routes.setAll(0, s.routes.reversed.toList());
        final gaps = SelfOsV37Rules.representationGaps(s);
        expect(gaps.map((g) => g.kind), contains(family.value.$2));
        final keys = gaps.map((g) => g.key).toList();
        baseline ??= keys;
        expect(keys, baseline);
      }
    });
  }

  test('不适用需理由；单次低风险不强迫长程与累积展开', () {
    final s = decision();
    s.nodes.addAll([node('n1', 1), node('n2', 2)]);
    s.edges.add(link('n1', 'n2'));
    expect(SelfOsV37Rules.representationGaps(s).where((g) => g.routeId == 'a'),
        isEmpty);
    s.settings['coverageExceptions'] = {
      'b': {'valence': ''}
    };
    expect(
        SelfOsV37Rules.representationGaps(s).any((g) => g.key == 'b:valence'),
        isTrue);
    s.settings['coverageExceptions'] = {
      'b': {'valence': '仅保存草稿，此阶段不形成收益代价承诺'}
    };
    expect(
        SelfOsV37Rules.representationGaps(s).any((g) => g.key == 'b:valence'),
        isFalse);
    expect(SelfOsV37Rules.symmetryWarnings(s), isNotEmpty);
  });

  test('私有问题 ASK，公共问题 RETRIEVE，经验未知 EXPERIMENT；高风险不能跳过', () {
    for (final entry in {
      'private': 'ASK',
      'public': 'RETRIEVE',
      'experience': 'EXPERIMENT'
    }.entries) {
      final s = decision(risk: 'high');
      s.gaps
          .add(OsGap({'id': 'g', 'question': '关键条件是什么', 'access': entry.key}));
      expect(SelfOsV37Rules.gate(s).action, entry.value);
      expect(SelfOsV37Rules.gate(s).mayCommit, isFalse);
      s.gaps.single.data['unavailable'] = true;
      expect(SelfOsV37Rules.gate(s).action, 'HOLD');
    }
  });

  test('事实来源、未来日期、过期、冲突和模型推断均不能冒充核实依据', () {
    final now = DateTime(2026, 10, 19);
    final s = decision();
    s.gaps.add(OsGap({
      'question': '事实',
      'evidenceIds': ['proof']
    }));
    final e = proof(now: now);
    s.evidence.add(e);
    expect(SelfOsV37Rules.gate(s, at: now).action, 'PASS');
    for (final edit in <String, dynamic>{
      'source': '',
      'observedAt': now.add(const Duration(days: 1)).toIso8601String(),
      'validUntil': now.subtract(const Duration(days: 1)).toIso8601String(),
      'contradiction': 'conflict',
      'label': 'inference',
      'verified': false
    }.entries) {
      final previous = e.data[edit.key];
      e.data[edit.key] = edit.value;
      expect(SelfOsV37Rules.gate(s, at: now).action, 'VERIFY',
          reason: edit.key);
      if (previous == null) {
        e.data.remove(edit.key);
      } else {
        e.data[edit.key] = previous;
      }
    }
  });

  test('可逆小实验需要边界；重要新信息和未完成认识更新仍优先', () {
    final c = plannedCase();
    c.v37.gaps.add(OsGap({'question': '具体效果尚未知', 'access': 'experience'}));
    expect(c.commit, throwsFormatException);
    c.v37.settings['experimentPlan'] = '十分钟，出现明显不适即停止';
    c.commit();
    c.beginCognition();
    expect(c.commit, throwsFormatException);
    c.completeCognition('认识尚未改变', noChangeReason: '低成本实验仍是获取证据的方式');
    c.fields['newInformation'] = '现场条件已经不同';
    expect(c.commit, throwsFormatException);
  });

  test('敏感性检查按合理情景是否翻转，稳定未知允许停止搜索', () {
    final s = decision();
    final g = OsGap({
      'question': '投入时间',
      'lowScenario': '每周一小时',
      'highScenario': '每周三小时',
      'lowChoice': 'a',
      'highChoice': 'b'
    });
    s.gaps.add(g);
    expect(g.sensitivity, 'flip');
    expect(SelfOsV37Rules.gate(s).mayCommit, isFalse);
    g.data['highChoice'] = 'a';
    expect(g.sensitivity, 'stable');
    expect(SelfOsV37Rules.stopAdvice(s), contains('停止搜索'));
    g.data.remove('lowScenario');
    expect(g.sensitivity, 'unknown');
  });

  test('James 分类仅在有决意过程后成立，高风险偶然决意须冷却', () {
    final s = decision(risk: 'high');
    s.settings
        .addAll({'jamesMode': 'impulse', 'criticalUnknownsReviewed': true});
    s.evidence.add(proof());
    s.settings['coverageExceptions'] = {
      for (final r in s.routes)
        r.id: {for (final kind in osRepresentationKinds.keys) kind: '已记录不适用范围'}
    };
    expect(SelfOsV37Rules.jamesMode(s), 'unknown');
    s.settings
        .addAll({'decisionStage': 'near', 'decisionEvidence': '反复核对后突然有行动冲动'});
    expect(SelfOsV37Rules.gate(s).action, 'HOLD');
    s.settings['cooledAndReviewed'] = true;
    expect(SelfOsV37Rules.gate(s).action, 'PASS');
  });

  test('四类冲突基于高权重且选入的动机结构，注意占据不等于价值重要', () {
    final s = decision();
    Map<String, dynamic> m(String id, String side) =>
        {'optionId': id, 'side': side, 'selected': true, 'importance': 80};
    expect(
        SelfOsV37Rules.conflict(s, [m('a', 'for'), m('b', 'for')]), 'approach');
    expect(SelfOsV37Rules.conflict(s, [m('a', 'against'), m('b', 'against')]),
        'avoidance');
    expect(SelfOsV37Rules.conflict(s, [m('a', 'for'), m('a', 'against')]),
        'approachAvoidance');
    expect(
        SelfOsV37Rules.conflict(s, [
          m('a', 'for'),
          m('a', 'against'),
          m('b', 'for'),
          m('b', 'against')
        ]),
        'double');
    expect(
        SelfOsV37Rules.conflict(
            s, [m('a', 'for')..['importance'] = 10, m('b', 'for')]),
        'unknown');
    final valued = m('a', 'for')
      ..addAll({'endorsement': 'valued', 'occupancy': 5, 'actionLink': ''});
    expect(SelfOsV37Rules.attentionBreaks([valued]), hasLength(1));
  });

  test('图按最弱关键边降级，远期保留情景；回路不无限展开', () {
    final s = decision()..evidence.add(proof());
    for (var i = 1; i <= 6; i++) {
      s.nodes.add(node('n$i', i, label: 'personal'));
      if (i > 1) s.edges.add(link('n${i - 1}', 'n$i', label: 'personal'));
    }
    s.edges.add(link('n4', 'n2')
      ..data.addAll({'loop': 'reinforcing', 'breakCondition': '停止持续投入'}));
    s.validate();
    final paths = SelfOsV37Rules.causalPaths(s);
    expect(paths.single.nodes, hasLength(6));
    expect(paths.single.certainty, 'scenario');
    s.edges.first.data['label'] = 'unknown';
    final uncertain = SelfOsV37Rules.causalPaths(s).single;
    expect(uncertain.nodes, hasLength(2));
    expect(uncertain.certainty, 'unknown');
    expect(uncertain.stopReason, contains('停止'));
  });

  test('条件分支保留不同未来，低价值剪枝、深度与条数限制有效', () {
    final s = decision()..evidence.add(proof());
    s.nodes.addAll(
        [node('root', 1), node('up', 2), node('down', 2), node('next', 3)]);
    s.edges.addAll([
      link('root', 'up')..data['branch'] = 'upside',
      link('root', 'down')..data['branch'] = 'downside',
      link('up', 'next')
    ]);
    expect(SelfOsV37Rules.causalPaths(s), hasLength(2));
    s.nodes
        .firstWhere((n) => n.id == 'up')
        .data
        .addAll({'prune': true, 'pruneReason': '新增信息不影响选择'});
    expect(
        SelfOsV37Rules.causalPaths(s)
            .any((p) => p.nodes.any((n) => n.id == 'next')),
        isFalse);
    expect(SelfOsV37Rules.causalPaths(s, limit: 1), hasLength(1));
    expect(
        SelfOsV37Rules.causalPaths(s, maxDepth: 1).single.nodes, hasLength(1));
  });

  test('六种未来路径变化持久化，悬空和跨路线因果边被拒绝', () {
    final s = decision()..nodes.add(node('n', 1));
    for (final delta in osOptionDeltas.keys) {
      s.futureOptions.add(OsFutureOption(
          {'routeId': 'a', 'nodeId': 'n', 'delta': delta, 'title': '未来路径'}));
    }
    expect(SelfOsV37.fromJson(s.toJson()).futureOptions.map((d) => d.delta),
        osOptionDeltas.keys);
    s.nodes.add(node('b1', 2, route: 'b'));
    s.edges.add(link('n', 'b1'));
    expect(s.validate, throwsFormatException);
    s.edges.clear();
    s.edges.add(link('n', 'absent'));
    expect(s.validate, throwsFormatException);
  });

  test('认识重新入场必须含实际动机差异或明确无变化；快照不可被后续篡改', () {
    final c = plannedCase();
    c.beginCognition();
    c.fields['k2'] = '只多一段文字';
    expect(() => c.completeCognition('新认识'), throwsFormatException);
    c.motives.first.importance = 80;
    c.motives.first.occupancy = 75;
    c.motives.first.attention = 'foreground';
    c.completeCognition('这条事实让稳定收入进入前景');
    final trace = c.v37.knowledgeTraces.single;
    expect(trace['status'], 'rebuilt');
    final serialized = jsonEncode(trace);
    c.motives.first.title = '后来改变';
    c.fields['k2'] = '后续认识';
    expect(jsonEncode(trace), serialized);
    c.commit();
    final first = jsonEncode(c.commitment);
    c.fields['firstAction'] = '后来第一步';
    c.commit();
    expect(jsonEncode(c.v37.priorCommitments.single), first);
  });

  test('认识准备在 T* 前后比较，读完材料不自动算成功，真实反馈另行回写', () {
    final c = plannedCase();
    c.v37.settings['futureMoment'] =
        DateTime.now().add(const Duration(hours: 2)).toIso8601String();
    c.v37.gaps.add(OsGap({'id': 'g', 'question': '现场情况'}));
    final i = OsIntervention({
      'gapId': 'g',
      'type': 'read',
      'window': 'now',
      'task': '阅读说明',
      'source': '已保存原文',
      'expectedChange': '了解现场要求'
    });
    c.v37.interventions.add(i);
    c.startIntervention(i);
    c.completeIntervention(i, '读完，但认识与选择未变');
    expect(osMap(i.data['gain'])['decisionConditionsChanged'], isFalse);
    expect(i.text('reviewId'), isEmpty);
    c.addReview(reviewFor(c));
    expect(i.text('reviewId'), c.reviews.single.id);
    expect(SelfOsInsights.interventionFingerprint([c]).single,
        contains('0 次在决定前'));
    expect(() => c.startIntervention(i), throwsFormatException);
  });

  test('过时准备不能冒充事前干预，现场不能插入复杂阅读', () {
    final c = plannedCase();
    c.v37.settings['futureMoment'] =
        DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();
    c.v37.gaps.add(OsGap({'id': 'g'}));
    final i = OsIntervention({
      'gapId': 'g',
      'type': 'read',
      'window': 'now',
      'task': '读',
      'source': '原文',
      'expectedChange': '认识'
    });
    expect(() => c.startIntervention(i), throwsFormatException);
    c.v37.settings['futureMoment'] =
        DateTime.now().add(const Duration(hours: 1)).toIso8601String();
    i.data['window'] = 'onsite';
    expect(() => c.startIntervention(i), throwsFormatException);
    i.data['type'] = 'rehearse';
    c.startIntervention(i);
    c.v37.settings['futureMoment'] =
        DateTime.now().subtract(const Duration(seconds: 1)).toIso8601String();
    c.completeIntervention(i, '现场预演已结束');
    expect(i.flag('late'), isTrue);
  });

  test('力量证据须跨案例跨情境，重复引用、删除来源和问卷不能提高可信度', () {
    final a = plannedCase(), b = plannedCase();
    a.addReview(reviewFor(a, context: '工作'));
    b.addReview(reviewFor(b, context: '家庭'));
    final s = OsStrength({
      'title': '耐心',
      'selfReport': '问卷高分',
      'observations': [
        {'reviewId': a.reviews.single.id, 'effect': 'helped'},
        {'reviewId': a.reviews.single.id, 'effect': 'helped'},
        {'reviewId': '不存在', 'effect': 'helped'},
        {'reviewId': b.reviews.single.id, 'effect': 'helped'},
      ]
    });
    expect(SelfOsInsights.strength(s, [a, b]).supports, 2);
    expect(SelfOsInsights.strength(s, [a, b]).verified, isFalse);
    a.nextRound();
    a.addReview(reviewFor(a, context: '学习'));
    s.data['observations'] = [
      ...s.observations,
      {'reviewId': a.reviews.last.id, 'effect': 'helped', 'usage': 'overuse'}
    ];
    expect(SelfOsInsights.strength(s, [a, b]).verified, isTrue);
    expect(SelfOsInsights.strength(s, [a, b]).overuse, 1);
    expect(SelfOsInsights.strength(s, [a]).verified, isFalse);
  });

  test('性格变化必须排查其他条件，未记录不等于条件稳定', () {
    final a = plannedCase(), b = plannedCase();
    for (final c in [a, b, a]) {
      if (c.reviewed) c.nextRound();
      final r = reviewFor(c, context: c == a ? '工作' : '家庭');
      r.notes.addAll({
        'patternClaim': '在阻力下持续尝试',
        'alternativeExplanationCheck': '逐项核对日志',
        'variablesChecked': 'yes'
      });
      c.addReview(r);
    }
    expect(SelfOsInsights.stableChanges([a, b]), isEmpty);
    for (final c in [a, b]) {
      for (final r in c.reviews) {
        for (final key in ['K', 'M', 'Att', 'E', 'T', 'Skill']) {
          r.notes['control.$key'] = 'stable';
        }
      }
    }
    expect(SelfOsInsights.stableChanges([a, b]), hasLength(1));
    b.reviews.single.notes['control.E'] = 'changed';
    expect(SelfOsInsights.stableChanges([a, b]), isEmpty);
  });

  test('主线漂移只在重复的无新增证据切换时提示，完整生活比较保留', () {
    final p = SelfOsProfile();
    final now = DateTime.now();
    for (var i = 0; i < 3; i++) {
      p.tradeoffs.add({
        'caseId': '$i',
        'routeId': 'r$i',
        'to': 'active',
        'trigger': 'comparison',
        'createdAt': now.toIso8601String()
      });
    }
    expect(SelfOsInsights.pathGuard([], p), hasLength(1));
    p.tradeoffs.clear();
    expect(SelfOsInsights.pathGuard([], p), isEmpty);
    final c = plannedCase();
    c.v37.settings['triggerSource'] = 'comparison';
    expect(SelfOsInsights.pathGuard([c], p), hasLength(1));
    c.v37.settings['fullLifeAccepted'] = true;
    expect(SelfOsInsights.pathGuard([c], p), isEmpty);
  });
}
