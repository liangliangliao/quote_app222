import 'dart:math' as math;

import 'evidence_growth_knowledge.dart';
import 'evidence_growth_models.dart';

/// BM25 over words and Chinese bigrams, with optional provider-produced vectors.
/// Lexical matching is never presented as a learned semantic embedding.
class EvidenceGrowthSearch {
  EvidenceGrowthSearch(List<EvidenceKNode> nodes, {this.vectors = const {}})
      : nodes = List.unmodifiable(nodes) {
    for (final node in nodes) {
      final tokens = tokenize(node.embeddingText);
      final frequency = <String, int>{};
      for (final term in tokens) { frequency[term] = (frequency[term] ?? 0) + 1; }
      _terms[node.id] = frequency;
      _lengths[node.id] = tokens.length;
      for (final term in frequency.keys) { _documentFrequency[term] = (_documentFrequency[term] ?? 0) + 1; }
    }
  }
  final List<EvidenceKNode> nodes;
  final Map<String, List<double>> vectors;
  final _terms = <String, Map<String,int>>{};
  final _lengths = <String,int>{};
  final _documentFrequency = <String,int>{};
  static EvidenceGrowthSearch? _current;
  static String _version = '';
  static EvidenceGrowthSearch get current {
    if (_current == null || _version != EvidenceGrowthKnowledge.kbVersion) {
      _version = EvidenceGrowthKnowledge.kbVersion;
      _current = EvidenceGrowthSearch(EvidenceGrowthKnowledge.nodes);
    }
    return _current!;
  }

  static List<String> tokenize(String text) {
    final result = <String>[];
    for (final m in RegExp(r'[a-z0-9_-]+|[\u3400-\u9fff]+').allMatches(text.toLowerCase())) {
      final part = m[0]!;
      if (RegExp(r'^[a-z0-9]').hasMatch(part)) { result.add(part); continue; }
      if (part.length == 1) continue;
      for (var i=0; i<part.length-1; i++) { result.add(part.substring(i,i+2)); }
    }
    return result;
  }

  List<RoutedNode> search(String query, {GrowthModule? module, bool talOnly = false,
      int limit = 20, List<double>? queryVector}) {
    final terms = tokenize(query).toSet();
    if (terms.isEmpty) return [];
    final average = _lengths.isEmpty ? 1.0 : _lengths.values.reduce((a,b)=>a+b) / _lengths.length;
    final found = <RoutedNode>[];
    for (final node in nodes) {
      if ((module != null && node.module != module) || (talOnly && !node.isTal)) continue;
      var score = 0.0;
      for (final term in terms) {
        final count = _terms[node.id]![term] ?? 0;
        if (count == 0) continue;
        final df = _documentFrequency[term] ?? 0;
        final idf = math.log(1 + (nodes.length - df + .5) / (df + .5));
        score += idf * count * 2.2 / (count + 1.2 * (.25 + .75 * _lengths[node.id]! / average));
      }
      if (node.id.toLowerCase() == query.toLowerCase() || node.title.toLowerCase().contains(query.toLowerCase())) score += 10;
      if (queryVector != null && vectors[node.id] != null) score += cosine(queryVector,vectors[node.id]!) * 5;
      if (score > 0) found.add(RoutedNode(node:node,score:score,reason:'知识术语/案例召回；仍需前提与情境匹配'));
    }
    found.sort((a,b)=>b.score.compareTo(a.score));
    return found.take(limit).toList();
  }

  static double cosine(List<double> a,List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0;
    double dot=0, aa=0, bb=0;
    for (var i=0;i<a.length;i++) { if (!a[i].isFinite || !b[i].isFinite) return 0; dot+=a[i]*b[i]; aa+=a[i]*a[i]; bb+=b[i]*b[i]; }
    return aa==0 || bb==0 ? 0 : dot / math.sqrt(aa*bb);
  }
}
