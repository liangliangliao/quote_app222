import 'semantic_scope.dart';

const readingMapPurpose = '从一般规定逐层限定到可观察经验，并用多个概念含义圈呈现连续关系';
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
        if (node.definition.runes.length < 24 || placeholder(node.definition))
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
        value.concepts.where((c) => c.kind == 'experience').toList();
    if (examples.any((c) =>
        placeholder(c.label) ||
        placeholder(c.definition) ||
        c.definition.runes.length < 24)) {
      issues.add(const AnalysisIssue('reading.experiences',
          '具体经验仍是占位或过短：请写明人物/对象、情境、动作和可观察结果；节点标题直接描述该次事件。'));
    }
    final groundable = <String>{
      for (final n in examples)
        if (!placeholder(n.label) && n.definition.runes.length >= 24) n.id
    };
    var changed = true;
    while (changed) {
      changed = false;
      for (final e in value.hierarchy) {
        if (groundable.contains(e.child) && groundable.add(e.parent))
          changed = true;
      }
    }
    final ungrounded = value.concepts
        .where((n) => n.kind == 'concept' && !groundable.contains(n.id))
        .toList();
    if (ungrounded.isNotEmpty)
      issues.add(AnalysisIssue('reading.grounding',
          '以下概念尚未经过中介链路落到具体经验：${ungrounded.take(6).map((n) => n.label).join('、')}。请补充概念依赖及最终的直观依据，不能用文字占位代替。'));
    if (depth(value) < 4)
      issues.add(const AnalysisIssue('reading.hierarchy',
          '层级过短：需要一般概念→有意义的下位限定→更具体的条件/活动→可观察经验；不能靠同义改名凑层。'));
    if (examples.length < 2)
      issues.add(const AnalysisIssue(
          'reading.examples', '请补充至少两条具体且明确标记的模拟经验，说明如何呈现共同规定及差异。'));
    if (value.relations.where((r) => r.scope != null).length < 4 ||
        connectedCircles(value) < 5) {
      issues.add(const AnalysisIssue('reading.circles',
          '含义圈缺少连续结构：在同一明确论域中复用至少5个概念节点并建立至少4条有成员例子的圈关系；可构造有边界的模拟练习，不将其冒充原句事实。'));
    }
    return issues;
  }
}
