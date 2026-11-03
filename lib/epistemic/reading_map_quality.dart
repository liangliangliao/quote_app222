import 'semantic_scope.dart';

const readingMapPurpose = '从一般规定经必要概念中介返回直观内容，按材料选择概念树与含义圈';
const readingMapContext = SemanticContext(
    purpose: readingMapPurpose,
    requestedViews: ['hierarchy', 'circles'],
    inquiry: '理解名言的核心概念及其与生活经验的关系');

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

  static List<AnalysisIssue> issues(SemanticScope value,
      {List<String> requestedViews = const []}) {
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
      for (final n in value.concepts.where((n) => n.role == 'perspective')) {
        if (groundable.contains(n.coreId) && groundable.add(n.id))
          changed = true;
      }
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
          '以下概念的直观根据或形式构造尚未展示：${ungrounded.map((n) => n.label).join('、')}。请补上必要中介及可辨认内容；原句不宜直接演示时，可用核心意义高度对应、明确标为教学的相关案例，不能冒充事实。',
          retryable: requestedViews.contains('hierarchy')));
    }
    if (requestedViews.isNotEmpty) {
      final core = value.concepts
          .where((n) => n.kind == 'concept' && n.role != 'perspective')
          .toList();
      for (final node in core) {
        if (RegExp(r'单独说|单说|不足以体现.*语境|不符合.*语境|删去|删掉')
            .hasMatch(node.counterExample))
          issues.add(AnalysisIssue('reading.counterexample.${node.id}',
              '“${node.label}”的反例仍在比较措辞；需要能辨认概念适用边界的经验或相关案例。'));
        if (node.textTaxonomy)
          issues.add(AnalysisIssue('reading.selection.${node.id}',
              '“${node.label}”把文本表达方式当成了所谈概念；请先按本次考量选取原句涉及的经验、能力、认识或价值概念，再解释其隐喻表达。'));
        if (!value.legacy && node.selectionReason.trim().isEmpty)
          issues.add(AnalysisIssue('reading.selection_reason.${node.id}',
              '尚未说明为什么选取“${node.label}”：需要原句依据及它对本次考量的作用。'));
      }
      if (!value.legacy && value.analysisPurpose.trim().isEmpty)
        issues.add(const AnalysisIssue(
            'reading.purpose', '缺少本次占主导的目的与考量，尚不能说明概念选取及比较尺度。'));
      final connected = <String>{
        for (final e in value.hierarchy) ...[e.parent, e.child],
        for (final e in value.meaningLinks) ...[e.from, e.to],
        for (final r in value.scopeRelations) ...r.nodeIds,
        for (final n in value.concepts.where((n) => n.coreId.isNotEmpty)) ...[
          n.id,
          n.coreId
        ],
      };
      final isolated = core.where((n) => !connected.contains(n.id)).toList();
      if (isolated.isNotEmpty)
        issues.add(AnalysisIssue('reading.common_basis',
            '尚未完成共同规定与差异的考察：${isolated.map((n) => n.label).join('、')}仍未与本次概念联系。需按当前目的说明共同尺度、区别及关系，不能把未分析当成没有联系。'));
    }
    // Explicit projections cannot be satisfied by adding general semantic edges.
    if (requestedViews.isNotEmpty && value.legacy) {
      issues.add(const AnalysisIssue('reading.schema',
          '本次生成仍使用旧版图谱协议，缺少新版的限定与范围约定；已保留内容，请按新版重新生成。旧缓存不会自动付费重跑。'));
    }
    if (requestedViews.contains('hierarchy') && value.classEdges.isEmpty) {
      issues.add(const AnalysisIssue('reading.class_structure',
          '概念树尚未建立：需在同一论域中给出上位规定、下位新增规定，并另外展示返回直观的内容链路；条件和隐喻连线不能替代。'));
    }
    if (requestedViews.contains('circles') && value.scopeRelations.isEmpty) {
      issues.add(const AnalysisIssue('reading.meaning_spheres',
          '本次回复漏掉了含义圈：应继续按当前考量寻找共同规定和可说明的比较尺度；必要时将核心概念映射到共同经验论域，明确判准与范围。尚未返回关系不表示概念之间没有联系。'));
    }
    // Depth, length and number of circles are descriptive statistics only.
    // A short definition may be sufficient; a long argument must retain the
    // intermediaries it actually needs. Neither receives a numeric quality score.
    return issues;
  }
}
