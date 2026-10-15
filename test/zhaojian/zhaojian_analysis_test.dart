import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/zhaojian/src/copy.dart';
import 'package:quote_app/zhaojian/src/data/models.dart';
import 'package:quote_app/zhaojian/src/domain/analysis.dart';
import 'package:quote_app/zhaojian/src/zhaojian_oracle.dart';

ZMotive m(
  String text, {
  int cat = 0,
  String kind = 'int',
  String side = 'a',
  String valence = 'ap',
  int weight = 3,
  List<String> imagery = const <String>[],
}) {
  return ZMotive(
    text: text,
    cat: cat,
    kind: kind,
    side: side,
    valence: valence,
    weight: weight,
    imagery: imagery,
    rated: true,
  );
}

ZDecision decision({
  required List<ZMotive> motives,
  String pred = 'a',
  String? actual,
  int stake = 3,
  int? freedom,
  double? depth,
  String importance = '',
}) {
  return ZDecision(
    question: 'q',
    optionA: 'A',
    optionB: 'B',
    importance: importance,
    motives: motives,
    pred: pred,
    stake: stake,
    feltFreedom: freedom,
    sealedAt: DateTime(2026, 10, 1),
    actual: actual,
    actualAt: actual == null ? null : DateTime(2026, 10, 2),
    imageryDepth: depth,
  );
}

void main() {
  group('sumMotives', () {
    test('splits abstract and intuitive per side and halves "both"', () {
      final ZSums s = sumMotives(<ZMotive>[
        m('x', kind: 'abs', side: 'a', weight: 4),
        m('y', kind: 'int', side: 'b', weight: 3),
        m('z', kind: 'int', side: 'both', weight: 4),
        m('ignored', side: 'a', weight: 0),
      ]);
      expect(s.aAbs, 4);
      expect(s.aInt, 2);
      expect(s.bAbs, 0);
      expect(s.bInt, 5);
    });

    test('abstract lane and intuitive lane can disagree', () {
      final ZSums s = sumMotives(<ZMotive>[
        m('后果', kind: 'abs', side: 'a', weight: 5),
        m('他的神情', kind: 'int', side: 'b', weight: 4),
      ]);
      expect(absLean(s), 'a');
      expect(intLean(s), 'b');
      expect(lanesDisagree(s), isTrue);
    });

    test('no disagreement when one lane is empty', () {
      final ZSums s = sumMotives(<ZMotive>[
        m('后果', kind: 'abs', side: 'a', weight: 5),
      ]);
      expect(lanesDisagree(s), isFalse);
    });
  });

  group('conflictOf', () {
    test('approach-approach', () {
      final ZConflict c = conflictOf(<ZMotive>[
        m('a', side: 'a', valence: 'ap', weight: 5),
        m('b', side: 'b', valence: 'ap', weight: 5),
      ]);
      expect(c.type, 1);
    });

    test('avoidance-avoidance', () {
      final ZConflict c = conflictOf(<ZMotive>[
        m('a', side: 'a', valence: 'av', weight: 5),
        m('b', side: 'b', valence: 'av', weight: 5),
      ]);
      expect(c.type, 2);
    });

    test('approach-avoidance on one side', () {
      final ZConflict c = conflictOf(<ZMotive>[
        m('a1', side: 'a', valence: 'ap', weight: 5),
        m('a2', side: 'a', valence: 'av', weight: 5),
      ]);
      expect(c.type, 3);
    });

    test('double approach-avoidance', () {
      final ZConflict c = conflictOf(<ZMotive>[
        m('a1', side: 'a', valence: 'ap', weight: 5),
        m('a2', side: 'a', valence: 'av', weight: 5),
        m('b1', side: 'b', valence: 'ap', weight: 5),
        m('b2', side: 'b', valence: 'av', weight: 5),
      ]);
      expect(c.type, 4);
    });

    test('no strong conflict when nothing is rated', () {
      expect(conflictOf(<ZMotive>[]).type, 0);
    });
  });

  group('decision outcomes', () {
    final List<ZMotive> split = <ZMotive>[
      m('后果', kind: 'abs', side: 'a', weight: 5),
      m('他的神情', kind: 'int', side: 'b', weight: 4),
    ];

    test('followedKind reports which lane the action followed', () {
      expect(followedKind(decision(motives: split, actual: 'b')), '直观');
      expect(followedKind(decision(motives: split, actual: 'a')), '抽象');
      expect(followedKind(decision(motives: split)), isNull);
    });

    test('self score is stake when hit and minus stake when missed', () {
      expect(selfScoreOf(decision(motives: split, pred: 'a', actual: 'a', stake: 4)), 4);
      expect(selfScoreOf(decision(motives: split, pred: 'a', actual: 'b', stake: 4)), -4);
      expect(selfScoreOf(decision(motives: split, pred: 'a')), 0);
    });

    test('opposesBalance flags an action against the heavier side', () {
      final List<ZMotive> heavy = <ZMotive>[
        m('x', side: 'a', weight: 5),
        m('y', side: 'b', weight: 1),
      ];
      expect(opposesBalance(decision(motives: heavy, actual: 'b')), isTrue);
      expect(opposesBalance(decision(motives: heavy, actual: 'a')), isFalse);
      expect(opposesBalance(decision(motives: <ZMotive>[], actual: 'a')), isFalse);
    });

    test('hit rate ignores unrevealed decisions', () {
      final List<ZDecision> ds = <ZDecision>[
        decision(motives: split, pred: 'a', actual: 'a'),
        decision(motives: split, pred: 'a', actual: 'b'),
        decision(motives: split, pred: 'a'),
      ];
      expect(hitRateOf(ds), 0.5);
      expect(hitRateOf(<ZDecision>[decision(motives: split)]), isNull);
    });

    test('winStat counts only decisions where the lanes disagree', () {
      final ZWinStat w = winStat(<ZDecision>[
        decision(motives: split, actual: 'b'),
        decision(motives: split, actual: 'b'),
        decision(motives: split, actual: 'a'),
        decision(motives: <ZMotive>[m('x', side: 'a')], actual: 'a'),
      ]);
      expect(w.intuitive, 2);
      expect(w.abstractWins, 1);
      expect(w.total, 3);
    });
  });

  group('hypothesisStatus', () {
    test('needs 3 supports and twice the refutations', () {
      expect(hypothesisStatus(2, 0), 0);
      expect(hypothesisStatus(3, 0), 1);
      expect(hypothesisStatus(3, 1), 1);
      expect(hypothesisStatus(3, 2), 0);
    });

    test('refuted when refutations are at least 2 and outnumber supports', () {
      expect(hypothesisStatus(0, 1), 0);
      expect(hypothesisStatus(1, 2), 2);
      expect(hypothesisStatus(2, 2), 0);
    });
  });

  group('rankTop5', () {
    final List<ZMotive> cards = <ZMotive>[
      for (int c = 0; c < 4; c++)
        for (int k = 0; k < 4; k++) m('c${c}_$k', cat: c),
    ];

    test('keeps at most two per category and returns five', () {
      final Map<int, double> pulls = <int, double>{
        for (int i = 0; i < cards.length; i++) i: 4.0 - (i % 4),
      };
      final List<ZRank> top = rankTop5(cards, pulls);
      expect(top.length, 5);
      final Map<int, int> perCat = <int, int>{};
      for (final ZRank r in top) {
        perCat[r.motive.cat] = (perCat[r.motive.cat] ?? 0) + 1;
      }
      expect(perCat.values.every((int n) => n <= 2), isTrue);
    });

    test('higher pull ranks first', () {
      final List<ZMotive> two = <ZMotive>[m('low', cat: 0), m('high', cat: 1)];
      final List<ZRank> top = rankTop5(two, <int, double>{0: 1.0, 1: 3.5});
      expect(top.first.motive.text, 'high');
      expect(top.first.scored, isTrue);
    });

    test('rule fallback prefers hidden and frequently missed categories', () {
      final List<ZMotive> lib = <ZMotive>[
        m('plain', cat: 9),
        m('hidden', cat: ZCopy.hiddenCategory),
        m('missed', cat: 1),
      ];
      final List<ZRank> top = rankTop5(lib, <int, double>{}, missCats: <int>{1});
      expect(top.first.scored, isFalse);
      expect(top.map((ZRank r) => r.motive.text).toList().last, 'plain');
    });

    test('badge marks missed categories', () {
      final List<ZRank> top = rankTop5(
        <ZMotive>[m('x', cat: 1)],
        <int, double>{0: 2.0},
        missCats: <int>{1},
      );
      expect(top.single.badge, '你常漏这类');
    });
  });

  group('imageryOf', () {
    test('counts depth per side and the worst moment', () {
      final ZImagery im = imageryOf(<ZMotive>[
        m('x', side: 'a', imagery: <String>['看到', '听到', ZCopy.worstMomentTag]),
        m('y', side: 'b', imagery: <String>['看到']),
        m('z', side: 'a'),
      ]);
      expect(im.count, 2);
      expect(im.a, 3);
      expect(im.b, 1);
      expect(im.worst, isTrue);
      expect(im.lopsided, isTrue);
      expect(im.average, 2.0);
    });

    test('no imagery means no symmetry', () {
      final ZImagery im = imageryOf(<ZMotive>[m('x')]);
      expect(im.count, 0);
      expect(im.symmetry, isNull);
      expect(im.lopsided, isFalse);
    });
  });

  group('threshold statistics', () {
    List<ZDecision> many(int n, {required int Function(int) freedom, required bool Function(int) hit}) {
      return <ZDecision>[
        for (int i = 0; i < n; i++)
          decision(
            motives: <ZMotive>[m('x')],
            pred: 'a',
            actual: hit(i) ? 'a' : 'b',
            freedom: freedom(i),
            depth: freedom(i).toDouble(),
          ),
      ];
    }

    test('freedomStat needs at least six samples', () {
      expect(freedomStat(many(5, freedom: (int i) => i, hit: (int i) => true)), isNull);
    });

    test('freedomStat splits high and low by the mean', () {
      final ZFreedomStat? s = freedomStat(many(
        8,
        freedom: (int i) => i < 4 ? 9 : 2,
        hit: (int i) => i < 4,
      ));
      expect(s, isNotNull);
      expect(s!.highCount, 4);
      expect(s.lowCount, 4);
      expect(s.highHit, 1.0);
      expect(s.lowHit, 0.0);
    });

    test('imageryStat needs six samples and a spread', () {
      expect(imageryStat(many(5, freedom: (int i) => i + 1, hit: (int i) => true)), isNull);
      expect(imageryStat(many(8, freedom: (int i) => 3, hit: (int i) => true)), isNull);
      final ZImageryStat? s =
          imageryStat(many(8, freedom: (int i) => i < 4 ? 5 : 1, hit: (int i) => i < 4));
      expect(s, isNotNull);
      expect(s!.deepHit, 1.0);
      expect(s.shallowHit, 0.0);
    });
  });

  group('topMissCategories', () {
    test('returns the three most frequent categories', () {
      final List<ZMiss> ms = <ZMiss>[
        for (final int c in <int>[1, 1, 1, 2, 2, 3, 4, -1])
          ZMiss(cat: c, text: 't', createdAt: DateTime(2026, 10, 1)),
      ];
      expect(topMissCategories(ms), <int>{1, 2, 3});
    });
  });

  group('alignment', () {
    ZAlignRow row(int ya, int yb) =>
        ZAlignRow(a: <int>[ya - 10, ya, ya + 10], b: <int>[yb - 10, yb, yb + 10]);

    test('weights desires by evidence tier and reports the range', () {
      final ZAlignResult r = ZAlignResult(
        rows: <ZAlignRow>[row(80, 40), row(20, 60)],
        confidence: 0.95,
      );
      final ZAlignCalc c = calcAlignment(
        r,
        const <ZDesire>[ZDesire('被行为支持', strong: true), ZDesire('自述')],
      )!;
      // 一年：A = (1.0*80 + 0.3*20) / 1.3 ≈ 66；B = (1.0*40 + 0.3*60) / 1.3 ≈ 45
      expect(c.yearA, 66);
      expect(c.yearB, 45);
      expect(c.loA, 20);
      expect(c.hiA, 80);
      expect(c.weekA, 56);
      expect(c.decadeA, 76);
      expect(c.flip, isTrue, reason: '第二个欲求下排序相反');
      expect(c.weakOnly, isFalse);
      expect(c.confidence, 0.9, reason: '有被行为支持的欲求，置信度封顶 0.9');
    });

    test('weak-only desires cap confidence at 0.5 and are flagged', () {
      final ZAlignCalc c = calcAlignment(
        ZAlignResult(rows: <ZAlignRow>[row(70, 30)], confidence: 0.9),
        const <ZDesire>[ZDesire('自述')],
      )!;
      expect(c.confidence, 0.5);
      expect(c.weakOnly, isTrue);
      expect(c.flip, isFalse);
    });

    test('empty results and mismatched rows', () {
      expect(calcAlignment(const ZAlignResult(), const <ZDesire>[ZDesire('x')]), isNull);
      expect(calcAlignment(ZAlignResult(rows: <ZAlignRow>[row(50, 50)]), const <ZDesire>[]), isNull);
    });

    test('manual alignment is flagged and has no range or confidence', () {
      final ZAlignCalc c = manualAlignment(30, 120);
      expect(c.manual, isTrue);
      expect(c.yearA, 30);
      expect(c.yearB, 100, reason: '越界值被截断到 100');
      expect(c.confidence, isNull);
      expect(c.hiA, c.loA);
    });

    test('quadrants combine alignment with the pull share', () {
      expect(quadrantOf(70, 0.8), 0);
      expect(quadrantOf(70, 0.3), 1);
      expect(quadrantOf(40, 0.8), 2);
      expect(quadrantOf(40, 0.3), 3);
      expect(quadrantOf(60, 0.5), 1, reason: '边界：60 算高一致，0.5 不算高拉力');
    });

    test('pullShare divides the total weight between the sides', () {
      final ZSums s = sumMotives(<ZMotive>[
        m('x', side: 'a', weight: 3),
        m('y', side: 'b', weight: 1),
      ]);
      expect(pullShare(s, 'a'), 0.75);
      expect(pullShare(s, 'b'), 0.25);
      expect(pullShare(const ZSums(0, 0, 0, 0), 'a'), 0.5);
    });

    test('alignTrend averages the chosen option over early and recent halves', () {
      ZDecision d(String actual, int ya, int yb) => ZDecision(
            question: 'q',
            optionA: 'A',
            optionB: 'B',
            motives: const <ZMotive>[],
            pred: 'a',
            stake: 1,
            sealedAt: DateTime(2026, 10, 1),
            actual: actual,
            actualAt: DateTime(2026, 10, 2),
            align: ZAlignSummary(yearA: ya, yearB: yb),
          );
      expect(alignTrend(<ZDecision>[d('a', 50, 50)]), isNull);
      final ({double? early, double? recent})? t = alignTrend(<ZDecision>[
        d('a', 40, 80),
        d('b', 10, 50),
        d('a', 70, 20),
        d('b', 30, 90),
      ]);
      expect(t, isNotNull);
      expect(t!.early, 45.0);
      expect(t!.recent, 80.0);
    });
  });

  group('change helpers', () {
    test('asifVerdict covers keep, continue, reset, drop and incomplete', () {
      expect(asifVerdict('', '没成真', '更靠近'), startsWith('信息不全'));
      expect(asifVerdict('自然', '没成真', '更远了'), startsWith('弃'), reason: '不通向欲求就弃，无论反应如何');
      expect(asifVerdict('自然', '成真了', '更靠近'), startsWith('重设'));
      expect(asifVerdict('自然', '没成真', '更靠近'), startsWith('保留'));
      expect(asifVerdict('别扭', '没成真', '更靠近'), startsWith('继续'));
      expect(asifVerdict('像在演', '部分成真', '更靠近'), startsWith('继续'));
      expect(asifVerdict('自然', '没成真', '说不准'), startsWith('再观察'));
    });

    test('asifVerdict puts the alignment check before the belief check', () {
      expect(asifVerdict('自然', '成真了', '更远了'), startsWith('弃'));
    });

    test('crisis detection catches despair and self-harm wording only', () {
      expect(zCrisis('我真的不想活了'), isTrue);
      expect(zCrisis('有时候想自杀'), isTrue);
      expect(zCrisis('活着没意思'), isTrue);
      expect(zCrisis('今天活着没有意思'), isTrue);
      expect(zCrisis('我想把这个项目做完'), isFalse);
      expect(zCrisis('这个任务快把我累死了'), isFalse, reason: '日常夸张说法不触发');
      expect(zCrisis(''), isFalse);
    });

    test('fatalism detection returns the first matched phrase', () {
      expect(zFatalism('反正我就是改不了'), '反正');
      expect(zFatalism('本性难移吧'), '本性难移');
      expect(zFatalism('这次我会试试看'), isNull);
    });

    test('ropeStats counts kept and broken', () {
      final ({int kept, int broken}) s = ropeStats(<String>['y', 'n', 'y', 'y', '']);
      expect(s.kept, 3);
      expect(s.broken, 1);
    });

    test('acceptance comfort needs control 2, a bypass and a confirmation', () {
      expect(acceptComfortAllowed(control: 2, bypass: '换条路', confirmedFixed: true), isTrue);
      expect(acceptComfortAllowed(control: 2, bypass: '  ', confirmedFixed: true), isFalse);
      expect(acceptComfortAllowed(control: 2, bypass: '换条路', confirmedFixed: false), isFalse);
      expect(acceptComfortAllowed(control: 1, bypass: '换条路', confirmedFixed: true), isFalse);
    });

    test('string counting ignores empties and ranks by count then name', () {
      final Map<String, int> c = countStrings(<String>['b', 'a', 'b', '', 'a', 'c']);
      expect(c, <String, int>{'b': 2, 'a': 2, 'c': 1});
      expect(topCounts(c, n: 2), 'a 2　b 2');
    });
  });

  group('action and belief helpers', () {
    test('billRisk grows as evidence, endorsement, term and the never-cashed case go missing', () {
      expect(billRisk(term: '一年', evidence: '有数据', endorser: '导师', neverCashed: '换个方向'), 0);
      expect(billRisk(term: '', evidence: '有数据', endorser: '导师', neverCashed: '换个方向'), 1);
      expect(billRisk(term: '一年', evidence: '', endorser: '导师', neverCashed: '换个方向'), 1);
      expect(billRisk(term: '', evidence: '', endorser: '导师', neverCashed: '换个方向'), 2);
      expect(billRisk(term: '', evidence: '有数据', endorser: '', neverCashed: ''), 2);
      expect(billRisk(term: '', evidence: '', endorser: '', neverCashed: ''), 2);
    });

    test('funnel counts each stage reached and the conversions', () {
      final ZFunnel f = funnelOf(<int>[0, 0, 1, 2, 2, 1]);
      expect(f.wish, 6);
      expect(f.resolve, 4);
      expect(f.act, 2);
      expect(f.wishToResolve, closeTo(4 / 6, 1e-9));
      expect(f.resolveToAct, 0.5);
      final ZFunnel empty = funnelOf(<int>[]);
      expect(empty.wishToResolve, isNull);
      expect(empty.resolveToAct, isNull);
      expect(funnelOf(<int>[0, 0]).resolveToAct, isNull, reason: '没有决意就没有决意→行动的转化率');
    });

    test('knowActGaps keeps decisions where abstract motives lost to intuitive ones', () {
      final List<ZMotive> split = <ZMotive>[
        m('后果', kind: 'abs', side: 'a', weight: 5),
        m('他的神情', kind: 'int', side: 'b', weight: 4),
      ];
      final List<ZDecision> gaps = knowActGaps(<ZDecision>[
        decision(motives: split, actual: 'b'),
        decision(motives: split, actual: 'a'),
        decision(motives: <ZMotive>[m('x', side: 'a')], actual: 'a'),
      ]);
      expect(gaps.length, 1);
      expect(gaps.single.actual, 'b');
    });
  });

  group('direction helpers', () {
    test('probeQuadrant uses 4 and above as high', () {
      expect(probeQuadrant(5, 4), 0);
      expect(probeQuadrant(4, 3), 1);
      expect(probeQuadrant(3, 5), 2);
      expect(probeQuadrant(1, 2), 3);
      expect(probeQuadrant(4, 4), 0);
    });

    test('signature stats count hits, misses and distinct contexts of hits', () {
      final ZSigStats st = signatureStats(<Map<String, dynamic>>[
        <String, dynamic>{'ctx': '会议', 'hit': true},
        <String, dynamic>{'ctx': '会议', 'hit': true},
        <String, dynamic>{'ctx': '饭局', 'hit': true},
        <String, dynamic>{'ctx': '', 'hit': true},
        <String, dynamic>{'ctx': '会议', 'hit': false},
      ]);
      expect(st.hits, 4);
      expect(st.misses, 1);
      expect(st.contexts, 2, reason: '空情境不算，落空的情境不算');
    });

    test('signature gate needs 3 hits, 2 contexts and hits not below misses', () {
      expect(signatureGate(const ZSigStats(3, 0, 2)), isTrue);
      expect(signatureGate(const ZSigStats(2, 0, 2)), isFalse);
      expect(signatureGate(const ZSigStats(3, 0, 1)), isFalse);
      expect(signatureGate(const ZSigStats(3, 4, 2)), isFalse);
      expect(signatureGate(const ZSigStats(4, 4, 2)), isTrue);
    });

    test('analysis needs at least four pieces of behavior evidence', () {
      expect(analysisMinEvidence, 4);
    });
  });

  group('library', () {
    test('static data is consistent', () {
      expect(ZCopy.categories.length, 12);
      expect(ZCopy.motiveLibrary.length, 12);
      expect(ZCopy.sceneTemplates.length, 12);
      expect(ZCopy.motiveLibrary.expand((List<String> e) => e).length, 61);
      expect(ZCopy.jamesTypes.length, 5);
      expect(ZCopy.conflictTypes.length, 5);
      for (final String t in ZCopy.sceneTemplates) {
        expect(t.contains('{t}'), isTrue);
      }
    });
  });
}
