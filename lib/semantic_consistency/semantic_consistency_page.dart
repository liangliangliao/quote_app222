import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'semantic_consistency_dao.dart';
import 'semantic_consistency_models.dart';
import 'semantic_consistency_service.dart';
import 'semantic_consistency_settings_page.dart';

class SemanticConsistencyPage extends StatefulWidget {
  const SemanticConsistencyPage({super.key});

  @override
  State<SemanticConsistencyPage> createState() => _SemanticConsistencyPageState();
}

class _SemanticConsistencyPageState extends State<SemanticConsistencyPage> {
  final _service = SemanticConsistencyService();
  final _dao = SemanticConsistencyDao();
  final _textACtrl = TextEditingController(text: '我打了小明');
  final _textBCtrl = TextEditingController(text: '小明被我打了');
  SemanticPrecisionMode _mode = SemanticPrecisionMode.standardJudge;
  SemanticConsistencyResult? _result;
  List<SemanticConsistencyResult> _history = <SemanticConsistencyResult>[];
  bool _loading = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textACtrl.dispose();
    _textBCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await SemanticConsistencySettings.load();
    final history = await _dao.latest(limit: 12);
    if (!mounted) return;
    setState(() {
      _mode = settings.defaultMode;
      _history = history;
      _loading = false;
    });
  }

  Future<void> _check() async {
    final a = _textACtrl.text.trim();
    final b = _textBCtrl.text.trim();
    if (a.isEmpty || b.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请同时输入文本A和文本B')));
      return;
    }
    setState(() => _checking = true);
    final res = await _service.check(textA: a, textB: b, mode: _mode);
    final history = await _dao.latest(limit: 12);
    if (!mounted) return;
    setState(() {
      _result = res;
      _history = history;
      _checking = false;
    });
  }

  Future<void> _clearHistory() async {
    await _dao.clearHistory();
    final history = await _dao.latest(limit: 12);
    if (!mounted) return;
    setState(() => _history = history);
  }

  Future<void> _clearEmbeddingCache() async {
    await _dao.clearEmbeddingCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清空 Embedding 向量缓存，下次会重新调用真实 API。')));
  }

  void _swap() {
    final a = _textACtrl.text;
    _textACtrl.text = _textBCtrl.text;
    _textBCtrl.text = a;
  }

  void _fillExample(String a, String b, SemanticPrecisionMode mode) {
    setState(() {
      _textACtrl.text = a;
      _textBCtrl.text = b;
      _mode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('语义一致性精判'),
        actions: [
          IconButton(
            tooltip: '配置',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SemanticConsistencySettingsPage()));
              await _load();
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _modeCard(),
                const SizedBox(height: 12),
                _inputCard(),
                const SizedBox(height: 12),
                _actionButtons(),
                const SizedBox(height: 12),
                if (_checking) const LinearProgressIndicator(),
                if (_result != null) _resultCard(_result!),
                const SizedBox(height: 12),
                _examplesCard(),
                const SizedBox(height: 12),
                _historyCard(),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _modeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('精准性模式', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            DropdownButtonFormField<SemanticPrecisionMode>(
              value: _mode,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: SemanticPrecisionMode.values.map((mode) => DropdownMenuItem(value: mode, child: Text(mode.label))).toList(),
              onChanged: _checking ? null : (v) => setState(() => _mode = v ?? SemanticPrecisionMode.standardJudge),
            ),
            const SizedBox(height: 8),
            Text(_mode.description, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _inputCard() {
    final textALabel = _mode == SemanticPrecisionMode.titleFaithfulness ? '文本A：文章全文' : '文本A';
    final textBLabel = _mode == SemanticPrecisionMode.titleFaithfulness
        ? '文本B：标题 / 摘要'
        : _mode == SemanticPrecisionMode.retrievalRerank
            ? '文本B：候选文本列表（空行或 --- 分隔）'
            : '文本B';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: _textACtrl,
              minLines: 5,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: textALabel,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textBCtrl,
              minLines: 5,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: textBLabel,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButtons() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: _checking ? null : _check,
          icon: _checking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.fact_check_outlined),
          label: const Text('开始分析'),
        ),
        OutlinedButton.icon(
          onPressed: _checking ? null : _swap,
          icon: const Icon(Icons.swap_vert),
          label: const Text('交换A/B'),
        ),
        OutlinedButton.icon(
          onPressed: _checking
              ? null
              : () {
                  setState(() {
                    _textACtrl.clear();
                    _textBCtrl.clear();
                    _result = null;
                  });
                },
          icon: const Icon(Icons.clear),
          label: const Text('清空'),
        ),
        OutlinedButton.icon(
          onPressed: _checking ? null : _clearEmbeddingCache,
          icon: const Icon(Icons.cleaning_services_outlined),
          label: const Text('清空向量缓存'),
        ),
      ],
    );
  }

  Widget _resultCard(SemanticConsistencyResult result) {
    final informationalRelation = <String>{
      'near_equivalent',
      'hypernym',
      'hyponym',
      'co_hyponym',
      'causal_relation',
      'entailment',
      'prerequisite',
      'related_not_equivalent',
      'topic_related',
      'weak_context_related',
      'shared_context_only',
      'ambiguous_related',
      'topic_opposition',
      'concept_instance',
      'extension_member',
      'manifestation',
      'effect',
      'cause_effect',
      'method_purpose',
      'possible_purpose_relation',
      'possible_preparation_relation',
      'attribute',
      'part_whole',
      'local_high_related',
      'global_high_related',
      'partially_faithful',
      'high_multi_route_related',
      'medium_multi_route_related',
      'low_multi_route_related',
    }.contains(result.relation);
    final color = result.isConsistent
        ? const Color(0xFF059669)
        : (result.relation == 'ambiguous'
            ? const Color(0xFF6B7280)
            : (informationalRelation ? const Color(0xFFD97706) : const Color(0xFFDC2626)));
    final extra = _extraMap(result.extraJson);
    final vectorADims = _extraInt(extra, 'vector_a_dims');
    final vectorBDims = _extraInt(extra, 'vector_b_dims');
    final lexicalScore = _extraDouble(extra, 'lexical_similarity_for_diagnosis_only') ?? _extraDouble(extra, 'lexical_surface_similarity');
    final rawNativeCosine = _extraDouble(extra, 'raw_native_cosine');
    final effectiveLowThreshold = _extraDouble(extra, 'effective_low_threshold');
    final effectiveHighThreshold = _extraDouble(extra, 'effective_high_threshold');
    final importantNote = extra['important_note'];
    final diagnosticWarning = extra['diagnostic_warning'];
    final llmUsed = extra['llm_used'];
    final localRuleUsed = extra['local_rule_used'];
    final fallbackUsed = extra['fallback_used'];
    final dotProduct = _extraDouble(extra, 'dot_product');
    final normA = _extraDouble(extra, 'vector_a_l2_norm');
    final normB = _extraDouble(extra, 'vector_b_l2_norm');
    final endpoint = extra['endpoint'];
    final extractionPathA = extra['text_a_embedding_extraction_path'];
    final extractionPathB = extra['text_b_embedding_extraction_path'];
    final cacheHitA = extra['text_a_cache_hit'];
    final cacheHitB = extra['text_b_cache_hit'];
    final vectorA = extra['vector_a'];
    final vectorB = extra['vector_b'];
    final finalMultiRouteScore = _extraDouble(extra, 'final_multi_route_score') ?? _extraDouble(extra, 'final_embedding_semantic_score');
    final bestRecallScore = _extraDouble(extra, 'best_recall_embedding_score');
    final bestRecallRoute = extra['best_recall_embedding_route'];
    final localConceptPrior = _extraDouble(extra, 'local_concept_prior');
    final routeScores = extra['route_scores'];
    final surfaceStats = extra['surface_stats'];
    final warningCode = extra['warning_code'];
    final conceptHits = extra['concept_hits'];
    final localRuleHits = extra['local_rule_hits'];
    final relatednessScore = _extraDouble(extra, 'relatedness_score');
    final equivalenceScore = _extraDouble(extra, 'equivalence_score');
    final coverageScore = _extraDouble(extra, 'coverage_score');
    final localBestScore = _extraDouble(extra, 'local_best_score');
    final matchScope = extra['match_scope'];
    final highlyRelated = extra['highly_related'];
    final sameMeaning = extra['same_meaning'];
    final completelyUnrelated = extra['completely_unrelated'];
    final direction = extra['direction'];
    final aRole = extra['a_role'];
    final bRole = extra['b_role'];
    final topEvidence = extra['top_evidence'];
    final commonAspects = extra['common_aspects'];
    final commonConcepts = extra['common_concepts'];
    final commonConceptAnalysis = extra['common_concept_analysis'];
    final directCommonalityScore = _extraDouble(extra, 'direct_commonality_score');
    final abstractCommonalityScore = _extraDouble(extra, 'abstract_commonality_score');
    final substantialCommonalityScore = _extraDouble(extra, 'substantial_commonality_score');
    final commonalityLevel = extra['commonality_level'];
    final differentAspects = extra['different_aspects'];
    final differenceAxes = extra['difference_axes'];
    final differenceAnalysis = extra['difference_analysis'];
    final differenceScore = _extraDouble(extra, 'difference_score');
    final unsupportedInferences = extra['unsupported_inferences'];
    final localCommonalityAdjusted = extra['local_commonality_adjusted'];
    final rawEmbeddingNote = extra['raw_embedding_note'];
    final oneSentenceConclusion = extra['one_sentence_conclusion'];
    final commonalitySummary = extra['commonality_summary'];
    final differenceSummary = extra['difference_summary'];
    final essentialCommonality = extra['essential_commonality'];
    final essentialDifference = extra['essential_difference'];
    final aSemanticFocus = extra['a_semantic_focus'];
    final bSemanticFocus = extra['b_semantic_focus'];
    final interchangeableContext = extra['interchangeable_context'];
    final nonInterchangeableContext = extra['non_interchangeable_context'];
    final displayCommonAspects = extra['display_common_aspects'];
    final displayCommonConcepts = extra['display_common_concepts'];
    final displayDifferenceAxes = extra['display_difference_axes'];
    final displayUnsupportedInferences = extra['display_unsupported_inferences'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(result.isConsistent ? Icons.check_circle : (informationalRelation ? Icons.info_outline : Icons.warning_amber_rounded), color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.relationLabel,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (result.mode == SemanticPrecisionMode.fastEmbedding.id)
                  _chip('是否高多路相关：${result.isConsistent ? '是' : '否'}')
                else if (result.mode == SemanticPrecisionMode.semanticRelation.id)
                  _chip('是否可视为同一含义：${result.isConsistent ? '是' : '否'}')
                else
                  _chip('是否一致：${result.isConsistent ? '是' : '否'}'),
                if (result.mode == SemanticPrecisionMode.fastEmbedding.id)
                  _chip('多路诊断分：${(result.confidence * 100).toStringAsFixed(0)}%')
                else
                  _chip('置信度：${(result.confidence * 100).toStringAsFixed(0)}%'),
                if (result.cosineScore != null) _chip('原生Embedding余弦：${result.cosineScore!.toStringAsFixed(4)}（仅参考）'),
                if (relatednessScore != null) _chip('语义相关度：${(relatednessScore * 100).toStringAsFixed(0)}%'),
                if (equivalenceScore != null) _chip('同义/等价度：${(equivalenceScore * 100).toStringAsFixed(0)}%'),
                if (coverageScore != null) _chip('覆盖度：${(coverageScore * 100).toStringAsFixed(0)}%'),
                if (localBestScore != null) _chip('局部最高匹配：${(localBestScore * 100).toStringAsFixed(0)}%'),
                if (highlyRelated != null) _chip('是否高度相关：$highlyRelated'),
                if (sameMeaning != null) _chip('是否同义等价：$sameMeaning'),
                if (completelyUnrelated != null) _chip('是否完全无关：$completelyUnrelated'),
                if (localCommonalityAdjusted != null) _chip('共同性校正：$localCommonalityAdjusted'),
                if (commonalityLevel is String && commonalityLevel.trim().isNotEmpty) _chip('共同性层级：$commonalityLevel'),
                if (directCommonalityScore != null) _chip('直接共同性：${(directCommonalityScore * 100).toStringAsFixed(0)}%'),
                if (abstractCommonalityScore != null) _chip('上位抽象共同性：${(abstractCommonalityScore * 100).toStringAsFixed(0)}%'),
                if (substantialCommonalityScore != null) _chip('实质共同性：${(substantialCommonalityScore * 100).toStringAsFixed(0)}%'),
                if (differenceScore != null) _chip('差异强度：${(differenceScore * 100).toStringAsFixed(0)}%'),
                if (matchScope is String && matchScope.trim().isNotEmpty) _chip('匹配范围：$matchScope'),
                if (direction is String && direction.trim().isNotEmpty) _chip('方向：$direction'),
                if (aRole is String && aRole.trim().isNotEmpty) _chip('A角色：$aRole'),
                if (bRole is String && bRole.trim().isNotEmpty) _chip('B角色：$bRole'),
                if (finalMultiRouteScore != null) _chip('多路召回参考分：${finalMultiRouteScore.toStringAsFixed(4)}'),
                if (bestRecallScore != null) _chip('最高召回向量：${bestRecallScore.toStringAsFixed(4)}'),
                if (localConceptPrior != null) _chip('本地概念/规则：${localConceptPrior.toStringAsFixed(4)}'),
                if (bestRecallRoute is String && bestRecallRoute.trim().isNotEmpty) _chip('命中通道：$bestRecallRoute'),
                if (warningCode is String && warningCode.trim().isNotEmpty) _chip('诊断码：$warningCode'),
                if (rawNativeCosine != null && rawNativeCosine != result.cosineScore) _chip('原生余弦：${rawNativeCosine.toStringAsFixed(4)}'),
                if (effectiveHighThreshold != null) _chip('高相关阈值：${effectiveHighThreshold.toStringAsFixed(2)}'),
                if (effectiveLowThreshold != null) _chip('中等阈值：${effectiveLowThreshold.toStringAsFixed(2)}'),
                if (vectorADims != null) _chip('A向量维度：$vectorADims'),
                if (vectorBDims != null) _chip('B向量维度：$vectorBDims'),
                if (dotProduct != null) _chip('dot：${dotProduct.toStringAsFixed(4)}'),
                if (normA != null) _chip('A范数：${normA.toStringAsFixed(4)}'),
                if (normB != null) _chip('B范数：${normB.toStringAsFixed(4)}'),
                if (cacheHitA != null) _chip('A缓存：$cacheHitA'),
                if (cacheHitB != null) _chip('B缓存：$cacheHitB'),
                if (lexicalScore != null) _chip('词面相似：${lexicalScore.toStringAsFixed(4)}（仅诊断）'),
                if (llmUsed != null) _chip('LLM：$llmUsed'),
                if (localRuleUsed != null) _chip('本地规则：$localRuleUsed'),
                if (fallbackUsed != null) _chip('Fallback：$fallbackUsed'),
                _chip('模式：${semanticPrecisionModeFromId(result.mode).label}'),
              ],
            ),
            if (oneSentenceConclusion is String && oneSentenceConclusion.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('一句话结论：$oneSentenceConclusion', style: const TextStyle(fontWeight: FontWeight.w600, height: 1.45)),
              ),
            ],
            if (commonalitySummary is String && commonalitySummary.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('共同性：$commonalitySummary', style: const TextStyle(height: 1.45)),
            ],
            if (differenceSummary is String && differenceSummary.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('差异性：$differenceSummary', style: const TextStyle(height: 1.45)),
            ],
            if (essentialCommonality is String && essentialCommonality.trim().isNotEmpty && essentialCommonality != commonalitySummary) ...[
              const SizedBox(height: 8),
              Text('本质共同性：$essentialCommonality', style: const TextStyle(height: 1.45)),
            ],
            if (essentialDifference is String && essentialDifference.trim().isNotEmpty && essentialDifference != differenceSummary) ...[
              const SizedBox(height: 8),
              Text('本质差异：$essentialDifference', style: const TextStyle(height: 1.45)),
            ],
            if ((aSemanticFocus is String && aSemanticFocus.trim().isNotEmpty) || (bSemanticFocus is String && bSemanticFocus.trim().isNotEmpty)) ...[
              const SizedBox(height: 8),
              Text('语义重心：A=${aSemanticFocus ?? ''}；B=${bSemanticFocus ?? ''}', style: const TextStyle(height: 1.45)),
            ],
            if (interchangeableContext is String && interchangeableContext.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('可互换语境：$interchangeableContext', style: const TextStyle(height: 1.45)),
            ],
            if (nonInterchangeableContext is String && nonInterchangeableContext.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('不宜互换语境：$nonInterchangeableContext', style: const TextStyle(height: 1.45)),
            ],
            if (result.errorType.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('差异类型：${result.errorType}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
            if (result.keyDifference.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('关键差异：${result.keyDifference}'),
            ],
            if (diagnosticWarning is String && diagnosticWarning.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('诊断提示：$diagnosticWarning', style: const TextStyle(color: Color(0xFFB45309))),
            ],
            if (importantNote is String && importantNote.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('说明：$importantNote', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            if (rawEmbeddingNote is String && rawEmbeddingNote.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Embedding说明：$rawEmbeddingNote', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            if (topEvidence is List && topEvidence.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('关键证据：${topEvidence.map((e) => e.toString()).join('；')}', style: const TextStyle(height: 1.45)),
            ],
            if (displayCommonAspects is List && displayCommonAspects.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('关键共同点：${displayCommonAspects.map((e) => e.toString()).join('；')}', style: const TextStyle(height: 1.45)),
            ],
            if (displayCommonConcepts is List && displayCommonConcepts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('共同概念：${displayCommonConcepts.map((e) => e.toString()).join('；')}', style: const TextStyle(height: 1.45)),
            ],
            if (displayDifferenceAxes is List && displayDifferenceAxes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('关键差异轴：${displayDifferenceAxes.map((e) => e.toString()).join('；')}', style: const TextStyle(height: 1.45)),
            ],
            if (displayUnsupportedInferences is List && displayUnsupportedInferences.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('不能推出：${displayUnsupportedInferences.map((e) => e.toString()).join('；')}', style: const TextStyle(height: 1.45, color: Color(0xFF6B7280))),
            ],
            if (result.reason.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('判断理由：${result.reason}', style: const TextStyle(height: 1.45)),
            ],
            if ((commonAspects is List && commonAspects.isNotEmpty) ||
                (commonConcepts is List && commonConcepts.isNotEmpty) ||
                (commonConceptAnalysis is String && commonConceptAnalysis.trim().isNotEmpty) ||
                (differentAspects is List && differentAspects.isNotEmpty) ||
                (differenceAxes is List && differenceAxes.isNotEmpty) ||
                (differenceAnalysis is String && differenceAnalysis.trim().isNotEmpty) ||
                (unsupportedInferences is List && unsupportedInferences.isNotEmpty)) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('查看完整共同性/差异分析'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
                        'common_aspects_full': commonAspects,
                        'common_concepts_full': commonConcepts,
                        'common_concept_analysis_full': commonConceptAnalysis,
                        'different_aspects_full': differentAspects,
                        'difference_axes_full': differenceAxes,
                        'difference_analysis_full': differenceAnalysis,
                        'unsupported_inferences_full': unsupportedInferences,
                        'essential_commonality': essentialCommonality,
                        'essential_difference': essentialDifference,
                        'a_semantic_focus': aSemanticFocus,
                        'b_semantic_focus': bSemanticFocus,
                        'interchangeable_context': interchangeableContext,
                        'non_interchangeable_context': nonInterchangeableContext,
                      }),
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text('模型：${result.provider} / ${result.model}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Embedding：${result.embeddingProvider} / ${result.embeddingModel}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (endpoint is String && endpoint.trim().isNotEmpty)
              Text('Endpoint：$endpoint', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (extractionPathA is String && extractionPathA.trim().isNotEmpty)
              Text('A向量路径：$extractionPathA', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (extractionPathB is String && extractionPathB.trim().isNotEmpty)
              Text('B向量路径：$extractionPathB', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (routeScores is Map || surfaceStats is Map || conceptHits is List || localRuleHits is List) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('查看多路召回诊断'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
                        'one_sentence_conclusion': oneSentenceConclusion,
                        'commonality_summary': commonalitySummary,
                        'difference_summary': differenceSummary,
                        'display_common_aspects': displayCommonAspects,
                        'display_common_concepts': displayCommonConcepts,
                        'display_difference_axes': displayDifferenceAxes,
                        'display_unsupported_inferences': displayUnsupportedInferences,
                        'relatedness_score': relatednessScore,
                        'equivalence_score': equivalenceScore,
                        'coverage_score': coverageScore,
                        'local_best_score': localBestScore,
                        'match_scope': matchScope,
                        'highly_related': highlyRelated,
                        'same_meaning': sameMeaning,
                        'direction': direction,
                        'a_role': aRole,
                        'b_role': bRole,
                        'top_evidence': topEvidence,
                        'common_aspects': commonAspects,
                        'common_concepts': commonConcepts,
                        'common_concept_analysis': commonConceptAnalysis,
                        'direct_commonality_score': directCommonalityScore,
                        'abstract_commonality_score': abstractCommonalityScore,
                        'substantial_commonality_score': substantialCommonalityScore,
                        'commonality_level': commonalityLevel,
                        'different_aspects': differentAspects,
                        'difference_axes': differenceAxes,
                        'difference_analysis': differenceAnalysis,
                        'difference_score': differenceScore,
                        'unsupported_inferences': unsupportedInferences,
                        'completely_unrelated': completelyUnrelated,
                        'local_commonality_adjusted': localCommonalityAdjusted,
                        'final_multi_route_score': finalMultiRouteScore,
                        'best_recall_embedding_score': bestRecallScore,
                        'best_recall_embedding_route': bestRecallRoute,
                        'local_concept_prior': localConceptPrior,
                        'concept_hits': conceptHits,
                        'local_rule_hits': localRuleHits,
                        'route_scores': routeScores,
                        'surface_stats': surfaceStats,
                      }),
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ],
            if (vectorA is Map || vectorB is Map) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('查看向量诊断'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
                        'vector_a': vectorA,
                        'vector_b': vectorB,
                        'dot_product': dotProduct,
                        'norm_a': normA,
                        'norm_b': normB,
                        'cosine': result.cosineScore,
                        'endpoint': endpoint,
                        'a_extraction_path': extractionPathA,
                        'b_extraction_path': extractionPathB,
                        'a_cache_hit': cacheHitA,
                        'b_cache_hit': cacheHitB,
                      }),
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ],
            if (result.rawResponse.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('查看原始模型响应'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                    child: SelectableText(_pretty(result.rawResponse), style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _examplesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('快速示例', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('主动/被动等价'),
                  onPressed: () => _fillExample('我打了小明', '小明被我打了', SemanticPrecisionMode.standardJudge),
                ),
                ActionChip(
                  label: const Text('主客体反转'),
                  onPressed: () => _fillExample('我打了小明', '小明打了我', SemanticPrecisionMode.strictFact),
                ),
                ActionChip(
                  label: const Text('否定变化'),
                  onPressed: () => _fillExample('我没有打小明', '我打了小明', SemanticPrecisionMode.strictFact),
                ),
                ActionChip(
                  label: const Text('标题夸大'),
                  onPressed: () => _fillExample('研究显示，该药物在小规模动物实验中可能有效，目前尚未开展人体临床试验。', '新药已被证明能治疗癌症', SemanticPrecisionMode.titleFaithfulness),
                ),
                ActionChip(
                  label: const Text('上下位概念'),
                  onPressed: () => _fillExample('动物', '牛', SemanticPrecisionMode.semanticRelation),
                ),
                ActionChip(
                  label: const Text('同类并列'),
                  onPressed: () => _fillExample('鸟', '鱼', SemanticPrecisionMode.semanticRelation),
                ),
                ActionChip(
                  label: const Text('互斥概念'),
                  onPressed: () => _fillExample('直角三角形', '锐角三角形', SemanticPrecisionMode.semanticRelation),
                ),
                ActionChip(
                  label: const Text('哲学概念'),
                  onPressed: () => _fillExample('必然性', '原因推出果', SemanticPrecisionMode.semanticRelation),
                ),
                ActionChip(
                  label: const Text('概念 vs 口语表现'),
                  onPressed: () => _fillExample('知行不一', '我总是想很多但做不起来', SemanticPrecisionMode.fastEmbedding),
                ),
                ActionChip(
                  label: const Text('短文本同字乱序'),
                  onPressed: () => _fillExample('各行其是', '是其行各', SemanticPrecisionMode.fastEmbedding),
                ),
                ActionChip(
                  label: const Text('词面相似干扰'),
                  onPressed: () => _fillExample('各行其是', '各行其上', SemanticPrecisionMode.fastEmbedding),
                ),
                ActionChip(
                  label: const Text('概念—具体实例'),
                  onPressed: () => _fillExample('目标', '每天按时起床去跑步', SemanticPrecisionMode.semanticRelation),
                ),
                ActionChip(
                  label: const Text('概念—具体表现'),
                  onPressed: () => _fillExample('坚持', '连续三个月每天练习英语', SemanticPrecisionMode.semanticRelation),
                ),
                ActionChip(
                  label: const Text('相关但方向相反'),
                  onPressed: () => _fillExample('成功的故事', '失败的故事', SemanticPrecisionMode.semanticRelation),
                ),
                ActionChip(
                  label: const Text('句子 vs 段落局部命中'),
                  onPressed: () => _fillExample('知行不一', '我总是想很多，也做了很多计划。可是到了真正行动时，我却迟迟开始不了，最后又陷入自责。', SemanticPrecisionMode.semanticRelation),
                ),
                ActionChip(
                  label: const Text('弱共同语境'),
                  onPressed: () => _fillExample('我今天去医院了', '我今天在床上睡了一天', SemanticPrecisionMode.semanticRelation),
                ),
                ActionChip(
                  label: const Text('弱上位抽象共同性'),
                  onPressed: () => _fillExample('赚30w', '和邻居干柴烈火的做爱', SemanticPrecisionMode.semanticRelation),
                ),
                ActionChip(
                  label: const Text('近义词本质差异'),
                  onPressed: () => _fillExample('波澜壮阔', '气势磅礴', SemanticPrecisionMode.semanticRelation),
                ),
                ActionChip(
                  label: const Text('可能前置准备'),
                  onPressed: () => _fillExample('我把全身清洗干净', '和邻居干柴烈火的做爱', SemanticPrecisionMode.semanticRelation),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('最近记录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                TextButton.icon(onPressed: _history.isEmpty ? null : _clearHistory, icon: const Icon(Icons.delete_outline), label: const Text('清空')),
              ],
            ),
            if (_history.isEmpty) const Text('暂无记录', style: TextStyle(color: Colors.grey)),
            for (final item in _history) _historyItem(item),
          ],
        ),
      ),
    );
  }

  Widget _historyItem(SemanticConsistencyResult item) {
    final dt = DateTime.fromMillisecondsSinceEpoch(item.createdAt);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('${item.relationLabel} · ${item.mode == SemanticPrecisionMode.fastEmbedding.id ? (item.isConsistent ? '高相关' : '未达高相关') : (item.mode == SemanticPrecisionMode.semanticRelation.id ? (item.isConsistent ? '同一含义' : '非同一含义') : (item.isConsistent ? '一致' : '不一致'))}'),
      subtitle: Text('${DateFormat('MM-dd HH:mm').format(dt)} · ${_preview(item.textA)} ↔ ${_preview(item.textB)}'),
      onTap: () {
        setState(() {
          _result = item;
          _textACtrl.text = item.textA;
          _textBCtrl.text = item.textB;
          _mode = semanticPrecisionModeFromId(item.mode);
        });
      },
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Map<String, dynamic> _extraMap(String raw) {
    if (raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {}
    return <String, dynamic>{};
  }


  int? _extraInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString());
  }

  double? _extraDouble(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _pretty(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  String _preview(String text, {int maxLength = 42}) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxLength) return compact;
    return '${compact.substring(0, maxLength)}…';
  }
}
