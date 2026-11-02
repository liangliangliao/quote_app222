import 'model.dart';

/// Authorship follows revisions of the same content. Merely referring to an
/// AI-proposed route does not turn a person's actual action into AI content.
String? aiContentOrigin(MirrorNode node,
    {MirrorNode? Function(String)? resolve}) {
  bool fromAi(MirrorNode current, Set<String> seen) {
    if (!seen.add(current.id)) return false;
    if (current.origin == EvidenceOrigin.aiHypothesis) return true;
    if (resolve == null) return false;
    final prior = resolve(current.revisionOf ?? '');
    if (prior != null && prior.kind == current.kind && fromAi(prior, seen))
      return true;
    const editable = {
      NodeKind.principle,
      NodeKind.scene,
      NodeKind.insight,
      NodeKind.route,
      NodeKind.reframe,
      NodeKind.belief
    };
    return editable.contains(current.kind) &&
        current.links.any((id) {
          final source = resolve(id);
          return source != null &&
              source.kind == current.kind &&
              fromAi(source, seen);
        });
  }

  bool hasAiReferences() =>
      resolve != null &&
      node.dependencies.any((id) {
        final source = resolve(id);
        return source != null && fromAi(source, <String>{});
      });

  if (node.kind == NodeKind.recommendation) {
    if (node.text('method') == 'decisions') return 'AI 评估 · 规则排序';
    if (hasAiReferences()) return 'AI 理由 · 规则排序';
  }
  if ({NodeKind.seal, NodeKind.deliberation}.contains(node.kind)) {
    final stored = node.object('snapshot')['nodes'];
    if (stored is List &&
        stored
            .whereType<Map>()
            .any((row) => row['origin'] == EvidenceOrigin.aiHypothesis.name)) {
      return node.kind == NodeKind.seal ? '系统封存 · 含 AI 分析' : '系统整理 · 含 AI 分析';
    }
  }
  if (fromAi(node, <String>{})) {
    return node.origin == EvidenceOrigin.selfReport ? 'AI 原稿 · 你已更新' : 'AI 生成';
  }
  if (node.kind == NodeKind.plan && hasAiReferences())
    return '你确认的预案 · 含 AI 建议';
  if (node.kind == NodeKind.graphShift) return '系统整理 · 参考 AI 分析';
  return null;
}
