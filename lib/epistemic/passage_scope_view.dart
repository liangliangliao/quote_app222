import 'reading_illustration.dart';
import 'reading_map_quality.dart';
import 'semantic_scope_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'concept_analysis.dart';
import 'legacy_concept_view.dart';
import 'semantic_scope.dart';
import 'semantic_scope_view.dart';

class PassageScopeView extends StatelessWidget {
  final String text;
  final String origin;
  final List<ConceptScope> scopes;
  final List<ConceptAbstraction> abstractions;
  final VoidCallback? onAnalyze;
  final EpistemicViewKind? preferredView;
  final ValueChanged<SemanticScope>? onResult;
  final void Function(String, SemanticScope)? onOpenConcept;
  final String? imagePath;
  final bool showCircles;
  final SemanticScopeService? service;
  const PassageScopeView(
      {super.key,
      required this.text,
      this.origin = 'quote',
      this.scopes = const [],
      this.abstractions = const [],
      this.onAnalyze,
      this.preferredView,
      this.onResult,
      this.onOpenConcept,
      this.imagePath,
      this.showCircles = true,
      this.service});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (imagePath != null &&
            preferredView == EpistemicViewKind.hierarchy) ...[
          ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(File(imagePath!),
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          const Text('已有名言配画 · 帮助理解的视觉类比', style: TextStyle(fontSize: 12)),
        ],
        SemanticScopePanel(
            key: ValueKey(text),
            sources: [ScopeSource('A', text, origin: origin)],
            initial: legacyConceptView(text, abstractions, scopes),
            service: service,
            analysisContext: readingMapContext,
            preferredView: preferredView,
            allowCircles: showCircles,
            showViewSelector: preferredView == null,
            onResult: onResult,
            onOpenConcept: onOpenConcept,
            focus: '分析整句中的概念及其关系'),
        if (readingIllustration(text) != null)
          ExpansionTile(title: const Text('可选教学模拟 · 不作为原句根据'), children: [
            SemanticScopeView(
                value: readingIllustration(text)!,
                sources: [ScopeSource('A', text, origin: origin)],
                preferredView: preferredView,
                allowCircles: showCircles)
          ]),
      ]);
}
