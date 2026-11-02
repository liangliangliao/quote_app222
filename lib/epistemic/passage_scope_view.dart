import 'package:flutter/material.dart';
import 'concept_analysis.dart';
import 'semantic_scope.dart';
import 'semantic_scope_view.dart';

class PassageScopeView extends StatelessWidget {
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
  Widget build(BuildContext context) => SemanticScopePanel(
      key: ValueKey(text),
      sources: [ScopeSource('A', text)],
      focus: '分析整句中的概念及其关系');
}
