import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/zhaojian/src/copy.dart';
import 'package:quote_app/zhaojian/src/data/models.dart';
import 'package:quote_app/zhaojian/src/domain/analysis.dart';

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
