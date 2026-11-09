/// Deterministic helpers for Schopenhauer's §9 meaning circles (Sphären).
///
/// Two things are computed here without any AI call, so the star map and the
/// concept tree can show them even when a model reply is incomplete:
///
/// 1. [classifyExtensions] reads the relation between two concepts from the
///    individuals they actually contain (equal / contains / overlap / apart).
///    The individuals are the "dots" inside the circles; a judgment is the
///    knowledge of how two circles (or a dot and a circle) lie to each other.
/// 2. [GroundLayers] measures how far a concept is from intuition: a concept
///    grounded directly in an identifiable individual experience is a
///    殊相 (ground floor); one that reaches intuition only through other
///    concepts is a 共相 (an upper floor). Distance, not generality, decides.
///
/// This file has no Flutter dependency on purpose, so it can be unit-tested
/// with plain Dart.
library;

/// The five ways two circles can lie to each other.
///
/// [unknown] means at least one concept has no recorded individual yet, so no
/// relation may be claimed. That is a gap in the material, not a relation.
enum CircleRelation { equal, subset, superset, overlap, disjoint, unknown }

class CircleReading {
  final CircleRelation relation;

  /// Individuals only in A, in both, and only in B (sorted for stable output).
  final List<String> onlyA, both, onlyB;
  const CircleReading(this.relation, this.onlyA, this.both, this.onlyB);

  int get sizeA => onlyA.length + both.length;
  int get sizeB => onlyB.length + both.length;

  /// Short Chinese name of the relation, for chips and legends.
  String get label => switch (relation) {
        CircleRelation.equal => '重合',
        CircleRelation.subset => 'A 在 B 内',
        CircleRelation.superset => 'B 在 A 内',
        CircleRelation.overlap => '部分相交',
        CircleRelation.disjoint => '互不相交',
        CircleRelation.unknown => '尚无依据',
      };

  /// The judgment this relation expresses, in the traditional quantified form.
  ///
  /// [basis] says what the circles contain ("已收录的名言"), because a count
  /// of recorded individuals never proves a universal claim.
  String sentence(String a, String b, {String basis = '已收录的材料'}) =>
      switch (relation) {
        CircleRelation.equal => '在$basis中，「$a」与「$b」所含相同（含义圈重合）。',
        CircleRelation.subset => '在$basis中，所有「$a」都属于「$b」，但有些「$b」不属于「$a」。',
        CircleRelation.superset => '在$basis中，所有「$b」都属于「$a」，但有些「$a」不属于「$b」。',
        CircleRelation.overlap => '在$basis中，有些「$a」属于「$b」，有些「$a」不属于「$b」。',
        CircleRelation.disjoint => '在$basis中，没有「$a」属于「$b」。',
        CircleRelation.unknown => '「$a」或「$b」尚无已收录的个别材料，不能判断二者的关系。',
      };

  /// Reading direction that must not be confused with the opposite one:
  /// containment is read upward ("是"), grounding is asked downward ("追溯").
  String get direction => switch (relation) {
        CircleRelation.subset || CircleRelation.superset =>
          '内圈向外圈读“是”；外圈要向内追问“凭什么”。两个方向不能混读。',
        CircleRelation.overlap => '相交只说明有共同部分，不能读成“A 是 B”。',
        _ => '',
      };
}

/// Classifies two extensions. Empty sets give [CircleRelation.unknown].
CircleReading classifyExtensions(Set<String> a, Set<String> b) {
  List<String> sorted(Iterable<String> v) => v.toList()..sort();
  if (a.isEmpty || b.isEmpty) {
    return CircleReading(CircleRelation.unknown, sorted(a), const [], sorted(b));
  }
  final both = a.intersection(b), onlyA = a.difference(b), onlyB = b.difference(a);
  final relation = both.isEmpty
      ? CircleRelation.disjoint
      : onlyA.isEmpty && onlyB.isEmpty
          ? CircleRelation.equal
          : onlyA.isEmpty
              ? CircleRelation.subset
              : onlyB.isEmpty
                  ? CircleRelation.superset
                  : CircleRelation.overlap;
  return CircleReading(relation, sorted(onlyA), sorted(both), sorted(onlyB));
}

/// How far each concept is from intuition.
///
/// Edges are `(parent, child)` pairs: the parent is thought through the child
/// (class membership, mediation, grounding and instance edges all point the
/// same way). Layer 0 is intuition itself, layer 1 a concept grounded
/// directly in it, layer n a concept with n-1 mediating concepts between it
/// and intuition. A concept with no path down to intuition has no layer at
/// all: it hangs in the air, and the tree must say so instead of guessing.
class GroundLayers {
  static Map<String, int?> compute(
      {required Iterable<String> conceptIds,
      required Iterable<String> groundIds,
      required Iterable<(String, String)> edges}) {
    final parentsOf = <String, Set<String>>{};
    for (final (parent, child) in edges) {
      parentsOf.putIfAbsent(child, () => {}).add(parent);
    }
    final layer = <String, int>{for (final id in groundIds) id: 0};
    final queue = [...groundIds];
    for (var i = 0; i < queue.length; i++) {
      final current = queue[i];
      for (final parent in parentsOf[current] ?? const <String>{}) {
        if (layer.containsKey(parent)) continue;
        layer[parent] = layer[current]! + 1;
        queue.add(parent);
      }
    }
    return {
      for (final id in {...conceptIds, ...groundIds}) id: layer[id]
    };
  }

  /// Label for a node card or legend.
  static String label(int? layer) {
    if (layer == null) return '悬空 · 尚无直观依据';
    if (layer == 0) return '直观 · 个别经验';
    if (layer == 1) return '殊相 · 直接落地';
    return '共相 · 隔${layer - 1}层概念';
  }
}

/// Connected components of an undirected edge list over [ids].
///
/// A concept tree made of several unconnected short chains has not related
/// its concepts to each other; callers use the count to say so.
List<Set<String>> connectedComponents(
    Iterable<String> ids, Iterable<(String, String)> edges) {
  final graph = <String, Set<String>>{for (final id in ids) id: {}};
  for (final (a, b) in edges) {
    if (!graph.containsKey(a) || !graph.containsKey(b)) continue;
    graph[a]!.add(b);
    graph[b]!.add(a);
  }
  final seen = <String>{}, result = <Set<String>>[];
  for (final start in graph.keys) {
    if (!seen.add(start)) continue;
    final component = {start}, queue = [start];
    for (var i = 0; i < queue.length; i++) {
      for (final next in graph[queue[i]]!) {
        if (seen.add(next)) {
          component.add(next);
          queue.add(next);
        }
      }
    }
    result.add(component);
  }
  return result;
}
