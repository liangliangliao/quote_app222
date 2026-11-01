import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/quote_insight.dart';
import 'concept_analysis.dart';
import 'cognitive_preferences.dart';
import 'cognitive_mode.dart';

/// Callers validate extension relations before constructing this widget.
/// Labels stay in normal Flutter widgets (text scaling / screen readers).
class ConceptMeaningDiagram extends StatefulWidget {
  final QuoteRelation relation;
  final String setA, setB, intersection, onlyA, onlyB, universe, otherMember;
  final ValueChanged<String>? onRegion;
  const ConceptMeaningDiagram({
    super.key,
    required this.relation,
    required this.setA,
    required this.setB,
    this.intersection = '',
    this.onlyA = '',
    this.onlyB = '',
    this.otherMember = '',
    this.universe = '',
    this.onRegion,
  });
  @override
  State<ConceptMeaningDiagram> createState() => _ConceptMeaningDiagramState();
}

class _ConceptMeaningDiagramState extends State<ConceptMeaningDiagram> {
  String? _region;
  void _select(String region) {
    setState(() => _region = region);
    widget.onRegion?.call(region);
  }

  @override
  void didUpdateWidget(ConceptMeaningDiagram old) {
    super.didUpdateWidget(old);
    if (old.setA != widget.setA ||
        old.setB != widget.setB ||
        old.relation != widget.relation ||
        old.universe != widget.universe) _region = null;
  }

  @override
  Widget build(BuildContext context) {
    final overlap = widget.relation == QuoteRelation.overlap;
    final subset = widget.relation == QuoteRelation.subset;
    final superset = widget.relation == QuoteRelation.superset;
    final nested = subset || superset;
    final equal = widget.relation == QuoteRelation.equal;
    final label = switch (widget.relation) {
      QuoteRelation.equal => '外延重合',
      QuoteRelation.partition => '互斥且穷尽上位范围',
      QuoteRelation.siblings => '同属上位范围但未穷尽',
      QuoteRelation.overlap => '部分交集',
      QuoteRelation.subset => 'A 包含于 B',
      QuoteRelation.superset => 'A 包含 B',
      _ => '相互排斥',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '概念含义圈 · $label',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (widget.universe.isNotEmpty)
          Text('论域：${widget.universe}', style: const TextStyle(fontSize: 12)),
        Semantics(
          label: '概念外延关系。A：${widget.setA}。B：${widget.setB}。$label。',
          child: ExcludeSemantics(
            child: LayoutBuilder(builder: (context, box) {
              final size = Size(box.maxWidth, 190);
              final geometry = _CircleMap(size, widget.relation);
              return GestureDetector(
                onTapUp: (tap) {
                  final region = geometry.regionAt(tap.localPosition);
                  if (region != null) _select(region);
                },
                child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: CustomPaint(
                      key: const ValueKey('quote-set-diagram'),
                      painter: _MeaningPainter(
                          widget.relation,
                          Theme.of(context).textTheme.bodyMedium?.fontFamily,
                          widget.setA,
                          widget.setB,
                          _region),
                    )),
              );
            }),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!subset && !equal)
              _chip('A', 'A 独有范围', const Color(0xff966b32)),
            if (overlap || nested || equal)
              _chip(
                  '共同',
                  equal
                      ? 'A 与 B 重合'
                      : subset
                          ? 'A 的全部范围'
                          : superset
                              ? 'B 的全部范围'
                              : '共同范围',
                  const Color(0xff596d87)),
            if (widget.relation == QuoteRelation.siblings)
              _chip('其余', '上位圈其余范围', const Color(0xff71614d)),
            if (!superset && !equal)
              _chip('B', 'B 独有范围', const Color(0xff426e91)),
          ],
        ),
        if (_region != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('$_region：${_detail(_region!)}',
                style: const TextStyle(height: 1.6)),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '圆圈表示对象的范围，大小不表示数量；交集不证明因果。',
            style: TextStyle(fontSize: 12, color: Color(0xff6b645b)),
          ),
        ),
      ],
    );
  }

  Widget _chip(String region, String label, Color color) => ActionChip(
        avatar: CircleAvatar(
          backgroundColor: color.withAlpha(35),
          child: Text(
              region == '共同'
                  ? '∩'
                  : region == '其余'
                      ? '○'
                      : region,
              style: TextStyle(fontSize: 12, color: color)),
        ),
        label: Text(label),
        onPressed: () => _select(region),
      );

  String _detail(String region) {
    if (region == '其余')
      return widget.otherMember.isNotEmpty
          ? widget.otherMember
          : '仍属于「${widget.universe}」且不满足 A、B 两项判准的成员。';
    final value = region == 'A'
        ? widget.onlyA
        : region == 'B'
            ? widget.onlyB
            : widget.intersection;
    return value.isEmpty ? '这个区域尚待补充具体成员。' : value;
  }
}

class _CircleMap {
  final Size size;
  final QuoteRelation relation;
  _CircleMap(this.size, this.relation);
  double get r => math.min(size.width / 4.5, 82.0);
  Offset get center => Offset(size.width / 2, size.height / 2);
  bool get nested =>
      relation == QuoteRelation.subset || relation == QuoteRelation.superset;
  double get displacement => switch (relation) {
        QuoteRelation.equal ||
        QuoteRelation.subset ||
        QuoteRelation.superset =>
          0,
        QuoteRelation.siblings => .48,
        QuoteRelation.partition => .5,
        QuoteRelation.disjoint => 1.13,
        _ => .58,
      };
  Offset get a => center.translate(-r * displacement, 0);
  Offset get b => center.translate(r * displacement, 0);
  double get ra =>
      r *
      (relation == QuoteRelation.siblings
          ? .39
          : relation == QuoteRelation.subset
              ? .52
              : 1);
  double get rb =>
      r *
      (relation == QuoteRelation.siblings
          ? .39
          : relation == QuoteRelation.superset
              ? .52
              : 1);
  String? regionAt(Offset point) {
    if (relation == QuoteRelation.partition) {
      if ((center - point).distance > r * 1.08) return null;
      return point.dx < center.dx ? 'A' : 'B';
    }
    final inA = (point - a).distance <= ra, inB = (point - b).distance <= rb;
    if (!inA &&
        !inB &&
        relation == QuoteRelation.siblings &&
        (point - center).distance <= r * 1.08) return '其余';
    return inA && inB
        ? '共同'
        : inA
            ? 'A'
            : inB
                ? 'B'
                : null;
  }
}

class _MeaningPainter extends CustomPainter {
  final QuoteRelation relation;
  final String? fontFamily, selected;
  final String setA, setB;
  const _MeaningPainter(
      this.relation, this.fontFamily, this.setA, this.setB, this.selected);
  @override
  void paint(Canvas canvas, Size size) {
    final map = _CircleMap(size, relation);
    final r = map.r, center = map.center;
    final a = map.a, b = map.b, ra = map.ra, rb = map.rb;
    void circle(Offset c, double radius, Color color) {
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withAlpha(30), color.withAlpha(75)],
          ).createShader(Rect.fromCircle(center: c, radius: radius)),
      );
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..color = color.withAlpha(150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    final parent = relation == QuoteRelation.siblings ||
        relation == QuoteRelation.partition;
    if (parent) {
      circle(center, r * 1.08, const Color(0xffb3ab9e));
      if (relation == QuoteRelation.partition) {
        final rect = Rect.fromCircle(center: center, radius: r * 1.08);
        canvas.drawArc(rect, math.pi / 2, math.pi, true,
            Paint()..color = const Color(0xffefbb68).withAlpha(80));
        canvas.drawArc(rect, -math.pi / 2, math.pi, true,
            Paint()..color = const Color(0xff7fb0d5).withAlpha(80));
        canvas.drawLine(
            center.translate(0, -r * 1.08),
            center.translate(0, r * 1.08),
            Paint()..color = const Color(0xffa39785));
      }
    }
    if (relation == QuoteRelation.partition) {
      // The two half-discs above exhaust the stated universe.
    } else if (ra < rb) {
      circle(b, rb, const Color(0xff7fb0d5));
      circle(a, ra, const Color(0xffefbb68));
    } else {
      circle(a, ra, const Color(0xffefbb68));
      circle(b, rb, const Color(0xff7fb0d5));
    }
    if (selected != null) {
      final enclosing = Path()
        ..addOval(Rect.fromCircle(center: center, radius: r * 1.08));
      final left = Path()..addOval(Rect.fromCircle(center: a, radius: ra));
      final right = Path()..addOval(Rect.fromCircle(center: b, radius: rb));
      final Path active;
      if (relation == QuoteRelation.partition) {
        final half = Path()
          ..addRect(Rect.fromLTRB(selected == 'A' ? 0 : center.dx, 0,
              selected == 'A' ? center.dx : size.width, size.height));
        active = Path.combine(PathOperation.intersect, enclosing, half);
      } else {
        active = switch (selected) {
          '共同' => Path.combine(PathOperation.intersect, left, right),
          'A' => Path.combine(PathOperation.difference, left, right),
          'B' => Path.combine(PathOperation.difference, right, left),
          _ => Path.combine(PathOperation.difference, enclosing,
              Path.combine(PathOperation.union, left, right)),
        };
      }
      canvas.drawPath(active, Paint()..color = const Color(0x285c4d78));
      canvas.drawPath(
          active,
          Paint()
            ..color = const Color(0xff716284)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0);
    }
    void label(String text, Offset offset, {double? maxWidth}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xff3b3935),
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 3,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth ?? r * .95);
      painter.paint(
        canvas,
        offset - Offset(painter.width / 2, painter.height / 2),
      );
    }

    if (relation == QuoteRelation.equal) {
      label('$setA = $setB', center, maxWidth: r * 1.5);
    } else if (ra != rb) {
      label(ra < rb ? setA : setB, center);
      label(ra < rb ? setB : setA, center.translate(0, -r * .75),
          maxWidth: r * 1.55);
    } else {
      final shift = parent ? 0.0 : r * .3;
      label(setA, a.translate(-shift, 0), maxWidth: r * .78);
      label(setB, b.translate(shift, 0), maxWidth: r * .78);
      if (relation == QuoteRelation.overlap)
        label('共同', center, maxWidth: r * .5);
    }
  }

  @override
  bool shouldRepaint(_MeaningPainter old) =>
      old.relation != relation ||
      old.selected != selected ||
      old.fontFamily != fontFamily ||
      old.setA != setA ||
      old.setB != setB;
}

class ConceptAnalysisView extends StatelessWidget {
  final List<ConceptAbstraction> abstractions;
  final List<ConceptScope> scopes;
  const ConceptAnalysisView({
    super.key,
    this.abstractions = const [],
    this.scopes = const [],
  });
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in abstractions)
            Card(
              color: const Color(0xfffaf5e9),
              elevation: 0,
              child: ExpansionTile(
                expansionAnimationStyle: cognitiveExpansionStyle(context),
                title: Text(
                  a.term,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(a.definition),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  for (final line in [
                    ('具体材料', a.observed),
                    ('保留的共同规定', a.retained),
                    ('抽象时省略', a.omitted),
                    ('反例与非成员', a.counterExample),
                  ])
                    if (line.$2.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${line.$1}：${line.$2}',
                            style: const TextStyle(height: 1.6),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          if (CognitivePreferenceStore.instance.value.relations)
            for (final scope in scopes)
              Card(
                color: const Color(0xfffaf6ee),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        scope.illustration
                            ? '分类示意 · 为理解构造，非原文的事实断言'
                            : '外延关系 · 对所选材料的暂定理解',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      ConceptMeaningDiagram(
                        relation: scope.relation,
                        setA: scope.setA,
                        setB: scope.setB,
                        intersection: scope.intersection,
                        otherMember: scope.otherMember,
                        onlyA: scope.onlyA,
                        onlyB: scope.onlyB,
                        universe: scope.universe,
                      ),
                      ExpansionTile(
                        expansionAnimationStyle:
                            cognitiveExpansionStyle(context),
                        title: const Text('论域、成员判准与根据'),
                        children: [
                          Text(
                            '论域：${scope.universe}\nA 的成员判准：${scope.criterionA}\nB 的成员判准：${scope.criterionB}\n'
                            '${scope.basis.isEmpty ? '' : '选文：${scope.basis}\n'}关系解释与限制：${scope.justification}',
                            style: const TextStyle(height: 1.6),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
      );
}
