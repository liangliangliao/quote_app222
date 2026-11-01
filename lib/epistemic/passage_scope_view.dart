import 'package:flutter/material.dart';
import 'concept_analysis.dart';
import 'cognitive_mode.dart';
import 'concept_meaning_diagram.dart';
import 'reading_scope.dart';

/// A quote can have a meaningful extension even when two whole statements
/// cannot be related as sets. A single concept needs no invented second set.
class PassageScopeView extends StatefulWidget {
  final String text;
  final List<ConceptScope> scopes;
  final List<ConceptAbstraction> abstractions;
  final VoidCallback? onAnalyze;
  const PassageScopeView(
      {super.key,
      required this.text,
      this.scopes = const [],
      this.abstractions = const [],
      this.onAnalyze});
  @override
  State<PassageScopeView> createState() => _PassageScopeViewState();
}

class _PassageScopeViewState extends State<PassageScopeView> {
  int index = 0;
  bool inside = true;
  @override
  Widget build(BuildContext context) {
    final editorial = passageScope(widget.text);
    final scopes = widget.scopes.isNotEmpty
        ? widget.scopes
        : [
            if (editorial != null) editorial,
            if (editorial != null &&
                widget.text.contains('否定') &&
                isBotanicalPassage(widget.text))
              botanicalNegation
          ];
    final terms = widget.abstractions;
    final length = scopes.length + terms.length;
    final i = index.clamp(0, length == 0 ? 0 : length - 1);
    final scope = i < scopes.length ? scopes[i] : null;
    final term =
        scope == null && terms.isNotEmpty ? terms[i - scopes.length] : null;
    return Container(
        key: const ValueKey('passage-scope'),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xfffcf7eb),
            border: Border.all(color: const Color(0xffdeceb0)),
            borderRadius: BorderRadius.circular(16)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (scope != null) ...[
            Text(scope.illustration ? '阅读示例  /  按给定判准分类' : '选文分析  /  暂定外延',
                style: Theme.of(context).textTheme.labelSmall),
            ConceptMeaningDiagram(
                key: ValueKey(scope.toJson().toString()),
                relation: scope.relation,
                setA: scope.setA,
                setB: scope.setB,
                universe: scope.universe,
                intersection: scope.intersection,
                onlyA: scope.onlyA,
                onlyB: scope.onlyB,
                otherMember: scope.otherMember),
            Text(scope.justification, style: const TextStyle(height: 1.55)),
            ExpansionTile(
                expansionAnimationStyle: cognitiveExpansionStyle(context),
                tilePadding: EdgeInsets.zero,
                title: const Text('查看成员判准和选文线索'),
                children: [
                  Text(
                      'A　${scope.criterionA}\nB　${scope.criterionB}\n${scope.basis}',
                      style: const TextStyle(height: 1.55))
                ]),
          ] else if (term != null) ...[
            const Text('概念含义圈 · 单一范围',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(children: [
              Expanded(
                  child: Center(
                      child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => inside = true),
                          child: Container(
                              width: 138,
                              height: 138,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xfff4dfac),
                                  border: Border.all(
                                      color: const Color(0xffac8035))),
                              child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(term.term,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700)),
                                        const Text('● 圈内',
                                            style: TextStyle(fontSize: 12)),
                                      ])))))),
              Expanded(
                  child: TextButton.icon(
                      onPressed: () => setState(() => inside = false),
                      icon: const Icon(Icons.radio_button_unchecked),
                      label: const Text('圈外 · 边界检验'))),
            ]),
            Text(
                inside
                    ? (term.memberExample.isEmpty
                        ? term.definition
                        : term.memberExample)
                    : (term.nonMember.isEmpty
                        ? term.counterExample
                        : term.nonMember),
                style:
                    const TextStyle(fontWeight: FontWeight.w600, height: 1.5)),
            for (final row in [
              ('成员判准', term.definition),
              ('共同规定', term.retained),
              ('对应材料', term.observed),
              ('抽象时省略', term.omitted),
              ('边界检验', term.counterExample)
            ])
              if (row.$2.isNotEmpty)
                Text('${row.$1}　${row.$2}',
                    style: const TextStyle(height: 1.6)),
          ] else ...[
            const Text('这句名言的概念含义圈',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('这条收录还缺少成员判准。分析后可查看圈内规定和边界实例。'),
            if (widget.onAnalyze != null)
              OutlinedButton(
                  onPressed: widget.onAnalyze, child: const Text('分析这句的概念范围')),
          ],
          if (length > 1)
            DropdownButton<int>(
                isExpanded: true,
                value: i,
                items: [
                  for (var j = 0; j < length; j++)
                    DropdownMenuItem(
                        value: j,
                        child: Text(
                            j >= scopes.length
                                ? terms[j - scopes.length].term
                                : '${scopes[j].setA} · ${scopes[j].setB}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis))
                ],
                onChanged: (v) {
                  if (v != null)
                    setState(() {
                      index = v;
                      inside = true;
                    });
                }),
        ]));
  }
}
