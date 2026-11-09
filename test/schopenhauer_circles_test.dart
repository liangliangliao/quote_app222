import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/epistemic/schopenhauer_circles.dart';

// The examples are the ones used to explain §9: 花/红色的东西, 苹果/水果, and
// the chain 美德 → 诚实 → 归还失物 → 个别事件.
void main() {
  group('circle relations are read from the individuals inside the circles', () {
    test('two circles that share only some individuals cross', () {
      final r = classifyExtensions({'白百合', '红玫瑰'}, {'红玫瑰', '红旗'});
      expect(r.relation, CircleRelation.overlap);
      expect(r.both, ['红玫瑰']);
      expect(r.onlyA, ['白百合']);
      expect(r.onlyB, ['红旗']);
      expect(r.sentence('花', '红色的东西'), contains('有些「花」属于「红色的东西」'));
      expect(r.direction, contains('不能读成“A 是 B”'));
    });
    test('a species lies inside its genus, never the other way round', () {
      final r = classifyExtensions({'苹果1', '苹果2'}, {'苹果1', '苹果2', '梨1'});
      expect(r.relation, CircleRelation.subset);
      expect(r.sentence('苹果', '水果'), contains('所有「苹果」都属于「水果」'));
      expect(r.sentence('苹果', '水果'), contains('有些「水果」不属于「苹果」'));
      expect(r.direction, contains('不能混读'));
      expect(classifyExtensions({'a', 'b'}, {'a'}).relation,
          CircleRelation.superset);
    });
    test('equal, apart and unknown are distinct readings', () {
      expect(classifyExtensions({'a'}, {'a'}).relation, CircleRelation.equal);
      expect(classifyExtensions({'a'}, {'b'}).relation, CircleRelation.disjoint);
      final unknown = classifyExtensions({}, {'b'});
      expect(unknown.relation, CircleRelation.unknown);
      expect(unknown.sentence('甲', '乙'), contains('不能判断'));
    });
    test('a recorded count never becomes a universal claim', () {
      final r = classifyExtensions({'a'}, {'a', 'b'});
      expect(r.sentence('甲', '乙', basis: '已收录的名言'), contains('已收录的名言'));
    });
  });

  group('ground layers measure distance from intuition', () {
    test('chain of 美德 lands in three links; 殊相 sits on the ground floor', () {
      final layers = GroundLayers.compute(
          conceptIds: ['美德', '诚实', '归还失物', '空话'],
          groundIds: ['捡到钱包还给失主'],
          edges: [
            ('美德', '诚实'),
            ('诚实', '归还失物'),
            ('归还失物', '捡到钱包还给失主')
          ]);
      expect(layers['捡到钱包还给失主'], 0);
      expect(layers['归还失物'], 1);
      expect(layers['诚实'], 2);
      expect(layers['美德'], 3);
      expect(layers['空话'], isNull);
      expect(GroundLayers.label(1), '殊相 · 直接落地');
      expect(GroundLayers.label(3), '共相 · 隔2层概念');
      expect(GroundLayers.label(null), startsWith('悬空'));
      expect(GroundLayers.label(0), '直观 · 个别经验');
    });
    test('a short chain still lands; the shortest path decides', () {
      final apple = GroundLayers.compute(
          conceptIds: ['果实', '水果', '苹果'],
          groundIds: ['这个苹果'],
          edges: [('果实', '水果'), ('水果', '苹果'), ('苹果', '这个苹果')]);
      expect([apple['苹果'], apple['水果'], apple['果实']], [1, 2, 3]);
      final two = GroundLayers.compute(
          conceptIds: ['P', 'M'],
          groundIds: ['g'],
          edges: [('P', 'g'), ('P', 'M'), ('M', 'g')]);
      expect(two['P'], 1);
    });
  });

  test('unconnected short chains are counted as separate components', () {
    final parts = connectedComponents(['心理能力', '韧性', '自我认识', '识认韧性'],
        [('心理能力', '韧性'), ('自我认识', '识认韧性')]);
    expect(parts.length, 2);
    expect(connectedComponents(['a', 'b'], [('a', 'b'), ('a', '未知')]).length, 1);
  });
}
