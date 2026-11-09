import 'schopenhauer_circles.dart';
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

  // A metaphorical quote must be read positively: image -> the concept it
  // points to -> why the image can point there -> where it does not
  // correspond. A reading that stops at "literal or figurative is not
  // stated" has not understood the sentence.
  static final _disclaimer = RegExp(
      r'未说明.{0,14}(?:字面|隐喻|比喻)|无法(?:确定|判断).{0,14}(?:字面|隐喻|比喻)|是字面.{0,10}还是.{0,6}(?:隐喻|比喻)');
  static Iterable<String> _readingTexts(SemanticScope value) => [
        for (final p in value.propositions) p.conclusion,
        for (final j in value.judgments) ...[j.common, j.difference, j.decisive],
      ];
  static bool figurative(SemanticScope value) =>
      value.materialKind == 'metaphor' ||
      value.concepts.any((n) => n.role == 'imagery') ||
      _readingTexts(value).any(_disclaimer.hasMatch);

  /// Issues that compare the map with the quote's own images and with the
  /// chain from concepts down to intuition. Pure and testable.
  static List<AnalysisIssue> structureIssues(SemanticScope value,
      {List<String> requestedViews = const []}) {
    final issues = <AnalysisIssue>[];
    if (figurative(value)) {
      final stalled = _readingTexts(value).any(_disclaimer.hasMatch);
      final imagery = {
        for (final n in value.concepts.where((n) => n.role == 'imagery')) n.id
      };
      final mapped = value.meaningLinks.any((l) =>
          l.kind == 'metaphor' &&
          (imagery.contains(l.from) || imagery.contains(l.to)));
      if (imagery.isEmpty || !mapped) {
        // Advisory unless the reading also stalled: older accepted maps that
        // read the sentence through abstract concepts stay usable, but the
        // note travels with a repair request and shows what is missing.
        issues.add(AnalysisIssue('reading.metaphor_mapping',
            '原句含有意象：建议把原句自己的意象词（如“隆冬”“夏天”“内心”）建成 role=imagery 的节点，'
            '用 metaphor 关系指向它所指的经验概念（如逆境、内在的生机），并写明共同规定与不对应之处，'
            '不要只保留“心理能力”“自我认识”这类抽象近义词来代替原句的概念。',
            retryable: stalled));
      }
      if (stalled) {
        issues.add(const AnalysisIssue('reading.metaphor_disclaimer',
            '解读停在“原句未说明是字面还是隐喻”。请先给出正面读法：意象→所指概念→为何能指向它→不对应之处→整句断言了哪个判断；'
            '字面义与隐喻义的取舍依据本次目的与原句语境，不以免责声明代替理解。'));
      }
    }
    if (requestedViews.contains('hierarchy')) {
      final links = [
        for (final e in value.hierarchy)
          if (const ['subtype', 'mediation', 'grounding', 'instance']
              .contains(e.kind))
            (e.parent, e.child)
      ];
      final ids = {for (final (a, b) in links) ...[a, b]};
      final parts = connectedComponents(ids, links);
      // Several short chains and no real tree: the concepts were never
      // related to one another. A forest with at least one substantial tree
      // is a legitimate result and is left alone.
      if (parts.length > 1 && parts.every((p) => p.length <= 3)) {
        final names = {for (final n in value.concepts) n.id: n.label};
        final shown = parts
            .take(4)
            .map((p) => p.take(3).map((id) => names[id] ?? id).join('、'))
            .join(' ｜ ');
        issues.add(AnalysisIssue('reading.fragmented_tree',
            '概念树被拆成${parts.length}段互不相连的短链（$shown）。需要用共同上位概念或必要中介把它们连成'
            '以原句核心概念为根的一棵树，并让每一支都追到可指认的个别经验；确实没有共同规定时，在判断中写明差异所在。'));
      }
    }
    return issues;
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
    if (requestedViews.isNotEmpty)
      issues.addAll(structureIssues(value, requestedViews: requestedViews));
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
