import 'semantic_scope.dart';

const readingMapPurpose = '从一般规定经必要概念中介返回直观内容，按材料选择概念树与含义圈';
const readingMapContext = SemanticContext(purpose: readingMapPurpose);

class ReadingMapQuality {
  static bool placeholder(String text) =>
      RegExp(r'^(?:[“"「]?.{1,40}[”"」]?的)?(?:具体表现|具体实例|具体经验|具体情境|模拟示例)[。.]?$')
          .hasMatch(text.trim());
  static SemanticScope adaptLegacy(
      SemanticScope value, List<ScopeSource> sources) {
    final map = value.toJson(), nodes = <Map<String, dynamic>>[];
    for (final node in value.concepts) {
      final raw = node.toJson();
      if (node.kind == 'experience' && placeholder(node.label)) {
        if (node.definition.trim().isEmpty || placeholder(node.definition))
          continue;
        raw['label'] = String.fromCharCodes(node.definition
            .replaceFirst(RegExp(r'^(?:模拟|示例|例子)[：:]\s*'), '')
            .runes
            .take(36));
      }
      nodes.add(raw);
    }
    final ids = nodes.map((n) => n['id']).toSet();
    map['concepts'] = nodes;
    map['hierarchy'] = [
      for (final e in value.hierarchy)
        if (ids.contains(e.parent) && ids.contains(e.child)) e.toJson()
    ];
    return SemanticScope.parse(map, sources, model: value.model);
  }

  static int depth(SemanticScope value) {
    final depths = {for (final c in value.concepts) c.id: 1};
    for (var i = 0; i < value.concepts.length; i++) {
      var changed = false;
      for (final e in value.hierarchy) {
        final next = (depths[e.parent] ?? 1) + 1;
        if (next > (depths[e.child] ?? 0)) {
          depths[e.child] = next;
          changed = true;
        }
      }
      if (!changed) break;
    }
    return depths.values.fold(0, (a, b) => a > b ? a : b);
  }

  static int connectedCircles(SemanticScope value) {
    final graph = <String, Set<String>>{};
    for (final r in value.relations
        .where((r) => r.scope != null && r.nodeIds.length == 2)) {
      final a = r.nodeIds[0], b = r.nodeIds[1];
      graph.putIfAbsent(a, () => {}).add(b);
      graph.putIfAbsent(b, () => {}).add(a);
    }
    var largest = 0;
    final seen = <String>{};
    for (final start in graph.keys) {
      if (seen.contains(start)) continue;
      final queue = [start];
      seen.add(start);
      for (var i = 0; i < queue.length; i++) {
        for (final n in graph[queue[i]] ?? <String>{}) {
          if (seen.add(n)) queue.add(n);
        }
      }
      if (queue.length > largest) largest = queue.length;
    }
    return largest;
  }

  static List<AnalysisIssue> issues(SemanticScope value) {
    final issues = <AnalysisIssue>[];
    final examples =
        value.concepts.where((c) => ['experience', 'formal'].contains(c.kind));
    for (final c in examples) {
      if (placeholder(c.label) ||
          placeholder(c.definition) ||
          c.definition.trim().isEmpty) {
        issues.add(AnalysisIssue('reading.experience.${c.id}',
            '“${c.label}”仍是文字占位；需要明确的对象、动作或可分辨的直观内容，不能把概念名加“具体表现”当作落地。'));
      }
    }
    final groundable = <String>{
      for (final n in value.concepts)
        if ((n.kind == 'formal' || n.kind == 'experience') &&
            !placeholder(n.label) &&
            !placeholder(n.definition) &&
            n.definition.trim().isNotEmpty)
          n.id
    };
    var changed = true;
    while (changed) {
      changed = false;
      for (final e in value.hierarchy) {
        // Each edge keeps its declared role. A teaching instance illustrates
        // a concept; it does not establish the truth of an empirical premise.
        if (groundable.contains(e.child) &&
            e.explanation.trim().isNotEmpty &&
            ['subtype', 'mediation', 'grounding', 'instance']
                .contains(e.kind) &&
            groundable.add(e.parent)) changed = true;
      }
    }
    final ungrounded = value.concepts
        .where((n) => n.kind == 'concept' && !groundable.contains(n.id))
        .toList();
    if (ungrounded.isNotEmpty &&
        !['fact', 'definition'].contains(value.materialKind)) {
      issues.add(AnalysisIssue('reading.grounding',
          '以下概念的直观根据或形式构造尚未展示：${ungrounded.map((n) => n.label).join('、')}。这表示内容来源尚需说明，不以虚构生活场景补齐。',
          retryable: false));
    }
    // Depth, length and number of circles are descriptive statistics only.
    // A short definition may be sufficient; a long argument must retain the
    // intermediaries it actually needs. Neither receives a numeric quality score.
    return issues;
  }
}
