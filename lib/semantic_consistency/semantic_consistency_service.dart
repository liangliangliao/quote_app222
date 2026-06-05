import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../services/global_ai_request_settings.dart';
import '../services/unified_ai_service.dart';
import '../utils/deepseek_logger.dart';
import 'semantic_consistency_dao.dart';
import 'semantic_consistency_models.dart';

class SemanticConsistencyService {
  SemanticConsistencyService({SemanticConsistencyDao? dao, UnifiedAiService? aiService})
      : _dao = dao ?? SemanticConsistencyDao(),
        _aiService = aiService ?? UnifiedAiService();

  final SemanticConsistencyDao _dao;
  final UnifiedAiService _aiService;
  final GlobalAiRequestSettings _requestSettings = GlobalAiRequestSettings();

  Future<SemanticConsistencyResult> check({
    required String textA,
    required String textB,
    SemanticPrecisionMode? mode,
  }) async {
    final settings = await SemanticConsistencySettings.load();
    final effectiveMode = mode ?? settings.defaultMode;
    final a = textA.trim();
    final b = textB.trim();
    if (a.isEmpty || b.isEmpty) {
      return _record(_simpleResult(
        settings: settings,
        mode: effectiveMode,
        textA: a,
        textB: b,
        relation: 'ambiguous',
        isConsistent: false,
        confidence: 0,
        errorType: 'empty_input',
        keyDifference: '文本A或文本B为空',
        reason: '请同时输入需要比较的两个文本。',
      ));
    }

    try {
      switch (effectiveMode) {
        case SemanticPrecisionMode.fastEmbedding:
          return _checkFastEmbedding(a, b, settings);
        case SemanticPrecisionMode.semanticRelation:
          return _checkSemanticRelation(a, b, settings);
        case SemanticPrecisionMode.standardJudge:
          return _checkStandardJudge(a, b, settings);
        case SemanticPrecisionMode.strictFact:
          return _checkStrictFact(a, b, settings);
        case SemanticPrecisionMode.titleFaithfulness:
          return _checkTitleFaithfulness(article: a, title: b, settings: settings);
        case SemanticPrecisionMode.retrievalRerank:
          return _checkRetrievalRerank(query: a, candidatesText: b, settings: settings);
      }
    } catch (e, st) {
      await DeepSeekLogger.logError(
        provider: 'Semantic Consistency',
        module: 'semantic_consistency.check',
        endpoint: 'local://semantic_consistency/check',
        error: e,
        stackTrace: st,
        model: effectiveMode.id,
      );
      return _record(_simpleResult(
        settings: settings,
        mode: effectiveMode,
        textA: a,
        textB: b,
        relation: 'ambiguous',
        isConsistent: false,
        confidence: 0,
        errorType: 'exception',
        keyDifference: '',
        reason: '语义精判失败：$e',
        rawResponse: '$e\n$st',
      ));
    }
  }

  Future<SemanticConsistencyResult> _checkFastEmbedding(
    String textA,
    String textB,
    SemanticConsistencySettings settings,
  ) async {
    // v18：Embedding-only 升级为“多路召回诊断”。
    // 仍然不调用 LLM，但不再让原生 cosine 一票否决；同时展示：
    // 1) 原始 A/B embedding；2) 分句/片段最高命中；3) 概念原型/典型表达命中；
    // 4) 关键词/词序/短文本乱序惩罚。
    final payloadA = await _embeddingWithCacheDetailed(textA, settings);
    final payloadB = await _embeddingWithCacheDetailed(textB, settings);
    final vectorA = payloadA.vector;
    final vectorB = payloadB.vector;

    final dot = _dotProduct(vectorA, vectorB);
    final normA = _l2Norm(vectorA);
    final normB = _l2Norm(vectorB);
    final rawCosine = cosineSimilarity(vectorA, vectorB).clamp(-1.0, 1.0).toDouble();
    final lexicalScore = _lexicalSimilarity(textA, textB);
    final thresholds = _effectiveEmbeddingThresholds(settings);
    final analysis = await _embeddingSemanticAnalysis(
      textA,
      textB,
      settings,
      precomputedPayloadA: payloadA,
      precomputedPayloadB: payloadB,
      precomputedRawScore: rawCosine,
      precomputedLexicalScore: lexicalScore,
    );
    final relation = _relationFromMultiRouteScore(analysis.finalScore, thresholds, analysis);

    final extra = <String, Object?>{
      'diagnostic_version': 'semantic_multi_route_recall_v18',
      'embedding_mode': 'multi_route_recall_diagnostic_no_llm',
      'provider': settings.embeddingProvider,
      'provider_label': settings.embeddingProviderLabel,
      'model': settings.embeddingModel,
      'endpoint': settings.embeddingEndpoint,
      'request_dimensions_sent': _shouldSendEmbeddingDimensions(settings),
      'configured_dimensions': settings.embeddingDimensions,
      'cache_lookup_dimensions': _cacheDimensionsForSettings(settings),
      'text_a_cache_hit': payloadA.cacheHit,
      'text_b_cache_hit': payloadB.cacheHit,
      'text_a_cache_hash': payloadA.cacheHash,
      'text_b_cache_hash': payloadB.cacheHash,
      'text_a_embedding_extraction_path': payloadA.extractionPath,
      'text_b_embedding_extraction_path': payloadB.extractionPath,
      'text_a_response_provider': payloadA.responseProvider,
      'text_b_response_provider': payloadB.responseProvider,
      'text_a_usage': payloadA.usage,
      'text_b_usage': payloadB.usage,
      'vector_a': _vectorDiagnostics(vectorA),
      'vector_b': _vectorDiagnostics(vectorB),
      'vector_a_dims': vectorA.length,
      'vector_b_dims': vectorB.length,
      'dot_product': dot,
      'vector_a_l2_norm': normA,
      'vector_b_l2_norm': normB,
      'raw_native_cosine': rawCosine,
      'cosine_formula': 'cosine = dot(vectorA, vectorB) / (l2Norm(vectorA) * l2Norm(vectorB))',
      'effective_low_threshold': thresholds.low,
      'effective_high_threshold': thresholds.high,
      'lexical_similarity_for_diagnosis_only': lexicalScore,
      'llm_used': false,
      'local_rule_used': analysis.localPriorScore != null,
      'fallback_used': false,
      'embedding_used_as_final_judgement': false,
      'multi_route_used_as_diagnostic': true,
      'full_vector_logged': false,
      'cache_version': 'semantic_embedding_native_v18_multi_route',
      ...analysis.toJson(),
      'important_note': 'Embedding 原生 cosine 只是一条证据；本诊断额外做分句/片段、概念原型、关键词和词序规则召回，避免“低向量分数=语义无关”的误判。该模式仍不等同于严格事实一致，最终等价判断请使用 LLM 精判模式。',
    };

    await _logEmbeddingCosineDiagnostics(
      settings: settings,
      textA: textA,
      textB: textB,
      vectorA: vectorA,
      vectorB: vectorB,
      rawCosine: rawCosine,
      dot: dot,
      normA: normA,
      normB: normB,
      thresholds: thresholds,
      lexicalScore: lexicalScore,
      payloadA: payloadA,
      payloadB: payloadB,
    );

    return _record(_simpleResult(
      settings: settings,
      mode: SemanticPrecisionMode.fastEmbedding,
      textA: textA,
      textB: textB,
      cosineScore: rawCosine,
      relation: relation,
      isConsistent: analysis.finalScore >= thresholds.high && !analysis.suspiciousSurfaceMatch,
      confidence: analysis.finalScore.clamp(0.0, 1.0).toDouble(),
      errorType: analysis.warningCode,
      keyDifference: analysis.keyDifference,
      reason: analysis.explanation,
      extraJson: jsonEncode(extra),
    ));
  }

  Future<SemanticConsistencyResult> _checkSemanticRelation(
    String textA,
    String textB,
    SemanticConsistencySettings settings,
  ) async {
    final embeddingMeta = await _tryBuildEmbeddingDiagnosticInstruction(textA, textB, settings);
    final promptTextA = _compactForMultiGranularityJudge(textA, counterpart: textB, label: 'A');
    final promptTextB = _compactForMultiGranularityJudge(textB, counterpart: textA, label: 'B');
    return _judgeWithLlm(
      settings: settings,
      mode: SemanticPrecisionMode.semanticRelation,
      textA: textA,
      textB: textB,
      promptTextA: promptTextA,
      promptTextB: promptTextB,
      cosineScore: embeddingMeta.cosineScore,
      extraInstruction: _renderPromptTemplate(
        settings.resolvedModeInstruction(SemanticPrecisionMode.semanticRelation),
        {'embeddingInstruction': embeddingMeta.instruction},
      ),
      extraJson: embeddingMeta.extraJson,
    );
  }

  Future<SemanticConsistencyResult> _checkStandardJudge(
    String textA,
    String textB,
    SemanticConsistencySettings settings,
  ) async {
    final embeddingMeta = await _tryBuildEmbeddingDiagnosticInstruction(textA, textB, settings);
    return _judgeWithLlm(
      settings: settings,
      mode: SemanticPrecisionMode.standardJudge,
      textA: textA,
      textB: textB,
      cosineScore: embeddingMeta.cosineScore,
      extraInstruction: _renderPromptTemplate(
        settings.resolvedModeInstruction(SemanticPrecisionMode.standardJudge),
        {'embeddingInstruction': embeddingMeta.instruction},
      ),
      extraJson: embeddingMeta.extraJson,
    );
  }

  Future<_JudgeEmbeddingMeta> _tryBuildEmbeddingDiagnosticInstruction(
    String textA,
    String textB,
    SemanticConsistencySettings settings,
  ) async {
    try {
      final analysis = await _embeddingSemanticAnalysis(textA, textB, settings);
      return _JudgeEmbeddingMeta(
        cosineScore: analysis.rawScore,
        extraJson: jsonEncode(<String, Object?>{
          ...analysis.toJson(),
          'raw_native_cosine': analysis.rawScore,
          'semantic_field_relatedness_reference': analysis.finalScore,
          'llm_used': true,
          'embedding_used_as_final_judgement': false,
          'important_note': '原生 Embedding 余弦只作为“语义场接近度参考”单独显示；它不是同义度、不是等价度、也不是最终判断分。LLM Judge 必须根据关系类型、局部证据、覆盖度和方向性独立判断。',
          'multi_granularity_hint': _multiGranularityHintJson(textA, textB),
        }),
        instruction: '''Embedding / 多路召回诊断仅供参考，不可作为最终结论。
原生 Embedding 余弦=${analysis.rawScore.toStringAsFixed(4)}，仅表示向量空间接近度。
多路召回诊断分=${analysis.finalScore.toStringAsFixed(4)}，仅表示候选召回参考。
${_multiGranularityInstruction(textA, textB)}
诊断 JSON：${jsonEncode(analysis.toJson())}''',
      );
    } catch (e) {
      return _JudgeEmbeddingMeta(
        cosineScore: null,
        extraJson: jsonEncode(<String, Object?>{
          'embedding_diagnostic_failed': true,
          'embedding_error': '$e',
          'llm_used': true,
          'embedding_used_as_final_judgement': false,
          'important_note': 'Embedding 诊断失败，但本模式仍继续调用 LLM Judge。',
        }),
        instruction: 'Embedding 诊断失败：$e。本模式仍必须继续根据文本含义进行语义精判。',
      );
    }
  }


  Map<String, Object?> _multiGranularityHintJson(String textA, String textB) {
    final unitsA = _semanticUnits(textA);
    final unitsB = _semanticUnits(textB);
    return <String, Object?>{
      'text_a_granularity': _textGranularity(textA),
      'text_b_granularity': _textGranularity(textB),
      'text_a_length': textA.trim().length,
      'text_b_length': textB.trim().length,
      'text_a_unit_count': unitsA.length,
      'text_b_unit_count': unitsB.length,
      'text_a_unit_preview': unitsA.take(8).map((e) => _preview(e, 120)).toList(),
      'text_b_unit_preview': unitsB.take(8).map((e) => _preview(e, 120)).toList(),
      'matching_principle': '短文本看关系类型；长文本同时看局部证据、整体主旨和覆盖度。原生 Embedding 只作参考。',
    };
  }

  String _multiGranularityInstruction(String textA, String textB) {
    final hint = _multiGranularityHintJson(textA, textB);
    return """多粒度匹配提示：
- 文本A粒度：${hint['text_a_granularity']}，长度：${hint['text_a_length']}，语义单元数：${hint['text_a_unit_count']}。
- 文本B粒度：${hint['text_b_granularity']}，长度：${hint['text_b_length']}，语义单元数：${hint['text_b_unit_count']}。
- 如果一方是长文，另一方是概念/句子：请先判断长文中是否存在局部证据，再判断该证据是否代表全文主旨。
- 如果双方都是长文：请区分主题相关、核心观点一致、局部证据重合、结论方向相反这几种情况。
- 输出 matchScope 时使用 exact/global/local/partial/topic/opposition/none。""";
  }


  String _compactForMultiGranularityJudge(
    String text, {
    required String counterpart,
    required String label,
  }) {
    final raw = text.trim();
    if (raw.length <= 2600) return raw;
    final units = _semanticUnits(raw);
    units.sort((a, b) => _unitRecallPriority(b, counterpart).compareTo(_unitRecallPriority(a, counterpart)));
    final selected = units.take(10).toList();
    final head = raw.substring(0, min(900, raw.length));
    final tail = raw.substring(max(0, raw.length - 700));
    return """【注意：文本$label 原文较长，以下为供裁判使用的压缩视图；最终判断必须区分局部命中与全文覆盖】
原文长度：${raw.length}
粒度：${_textGranularity(raw)}

【开头片段】
$head

【与另一侧最可能相关的语义单元 Top${selected.length}】
${selected.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

【结尾片段】
$tail""";
  }

  String _textGranularity(String text) {
    final t = text.trim();
    if (t.isEmpty) return 'empty';
    if (t.length <= 12 && !RegExp(r'[。！？!?；;，,\n]').hasMatch(t)) return 'concept_or_short_phrase';
    if (t.length <= 80 && t.split(RegExp(r'[。！？!?；;\n]')).where((e) => e.trim().isNotEmpty).length <= 2) return 'sentence_or_short_text';
    if (t.length <= 800) return 'paragraph';
    return 'article_or_long_text';
  }

  Future<SemanticConsistencyResult> _checkStrictFact(
    String textA,
    String textB,
    SemanticConsistencySettings settings,
  ) async {
    // 严格事实一致不能依赖 Embedding 成败；Embedding 只作为诊断参考。
    final embeddingMeta = await _tryBuildEmbeddingDiagnosticInstruction(textA, textB, settings);
    final eventA = await _extractEventStructure(textA, 'A');
    final eventB = await _extractEventStructure(textB, 'B');
    final extra = <String, Object?>{};
    try {
      final decoded = jsonDecode(embeddingMeta.extraJson);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          extra[entry.key.toString()] = entry.value;
        }
      }
    } catch (_) {}
    extra['event_a'] = _safeJson(eventA);
    extra['event_b'] = _safeJson(eventB);
    extra['strict_fact_uses_embedding_as_final_judgement'] = false;
    return _judgeWithLlm(
      settings: settings,
      mode: SemanticPrecisionMode.strictFact,
      textA: textA,
      textB: textB,
      cosineScore: embeddingMeta.cosineScore,
      extraInstruction: _renderPromptTemplate(
        settings.resolvedModeInstruction(SemanticPrecisionMode.strictFact),
        {
          'embeddingInstruction': embeddingMeta.instruction,
          'eventA': eventA,
          'eventB': eventB,
        },
      ),
      extraJson: jsonEncode(extra),
    );
  }

  Future<SemanticConsistencyResult> _checkTitleFaithfulness({
    required String article,
    required String title,
    required SemanticConsistencySettings settings,
  }) async {
    final chunks = _splitArticle(article, chunkSize: 900, overlap: 120);
    final titleVector = await _embeddingWithCache(title, settings);
    final scored = <_ScoredText>[];
    for (final chunk in chunks) {
      final vector = await _embeddingWithCache(chunk, settings);
      scored.add(_ScoredText(text: chunk, score: cosineSimilarity(titleVector, vector)));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final topK = settings.titleEvidenceTopK.clamp(1, 12).toInt();
    final evidence = scored.take(topK).map((e) => '[相似度 ${e.score.toStringAsFixed(4)}]\n${e.text}').join('\n\n---\n\n');
    final bestScore = scored.isEmpty ? null : scored.first.score;
    return _judgeWithLlm(
      settings: settings,
      mode: SemanticPrecisionMode.titleFaithfulness,
      textA: article,
      textB: title,
      cosineScore: bestScore,
      titleEvidence: evidence,
      extraInstruction: _renderPromptTemplate(
        settings.resolvedModeInstruction(SemanticPrecisionMode.titleFaithfulness),
        const <String, String>{},
      ),
      extraJson: jsonEncode(<String, Object?>{
        'chunk_count': chunks.length,
        'top_k': topK,
        'top_scores': scored.take(topK).map((e) => e.score).toList(),
      }),
    );
  }

  Future<SemanticConsistencyResult> _checkRetrievalRerank({
    required String query,
    required String candidatesText,
    required SemanticConsistencySettings settings,
  }) async {
    final candidates = _splitCandidates(candidatesText);
    if (candidates.length <= 1) {
      return _checkStrictFact(query, candidatesText, settings);
    }
    final queryVector = await _embeddingWithCache(query, settings);
    final scored = <_ScoredText>[];
    final candidateDiagnostics = <Map<String, Object?>>[];
    for (final candidate in candidates) {
      final vector = await _embeddingWithCache(candidate, settings);
      final embeddingScore = cosineSimilarity(queryVector, vector).clamp(-1.0, 1.0).toDouble();
      final surface = _surfaceStats(query, candidate);
      final local = _localSemanticRecallAnalysis(query, candidate, surface);
      var finalScore = max(embeddingScore, local.score).clamp(-1.0, 1.0).toDouble();
      var capApplied = false;
      if (local.scoreCap != null && finalScore > local.scoreCap!) {
        finalScore = local.scoreCap!;
        capApplied = true;
      }
      scored.add(_ScoredText(text: candidate, score: finalScore));
      candidateDiagnostics.add(<String, Object?>{
        'final_score': finalScore,
        'embedding_score': embeddingScore,
        'local_rule_score': local.score,
        'cap_applied': capApplied,
        'surface': surface.toJson(),
        'concept_hits': local.conceptHits,
        'local_rule_hits': local.hits,
        'text_preview': _preview(candidate, 160),
      });
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    var selected = scored.take(min(12, scored.length)).toList();
    var rerankMeta = <String, Object?>{'reranker_used': false};
    if (settings.enableReranker && settings.rerankerApiKey.trim().isNotEmpty) {
      final reranked = await _rerank(query: query, docs: selected.map((e) => e.text).toList(), settings: settings);
      if (reranked.isNotEmpty) {
        selected = reranked;
        rerankMeta = <String, Object?>{
          'reranker_used': true,
          'provider': settings.rerankerProvider,
          'model': settings.rerankerModel,
        };
      }
    }
    final best = selected.first;
    final candidatesForJudge = selected.take(5).map((e) => '[候选相似度/精排分 ${e.score.toStringAsFixed(4)}]\n${e.text}').join('\n\n---\n\n');
    return _judgeWithLlm(
      settings: settings,
      mode: SemanticPrecisionMode.retrievalRerank,
      textA: query,
      textB: best.text,
      cosineScore: best.score,
      extraInstruction: _renderPromptTemplate(
        settings.resolvedModeInstruction(SemanticPrecisionMode.retrievalRerank),
        {'candidatesForJudge': candidatesForJudge},
      ),
      extraJson: jsonEncode(<String, Object?>{
        'candidate_count': candidates.length,
        'ranking_strategy': 'multi_route_recall_score = max(embedding_score, local_rule_score) with surface-order cap',
        'candidate_diagnostics_preview': candidateDiagnostics.take(12).toList(),
        'selected_preview': selected.take(5).map((e) => {'score': e.score, 'text': _preview(e.text, 160)}).toList(),
        ...rerankMeta,
      }),
    );
  }

  Future<_EmbeddingSimilarityAnalysis> _embeddingSemanticAnalysis(
    String textA,
    String textB,
    SemanticConsistencySettings settings, {
    _EmbeddingVectorPayload? precomputedPayloadA,
    _EmbeddingVectorPayload? precomputedPayloadB,
    double? precomputedRawScore,
    double? precomputedLexicalScore,
  }) async {
    final payloadA = precomputedPayloadA ?? await _embeddingWithCacheDetailed(textA, settings);
    final payloadB = precomputedPayloadB ?? await _embeddingWithCacheDetailed(textB, settings);
    final vectorA = payloadA.vector;
    final vectorB = payloadB.vector;
    final rawScore = (precomputedRawScore ?? cosineSimilarity(vectorA, vectorB)).clamp(-1.0, 1.0).toDouble();
    final lexicalScore = precomputedLexicalScore ?? _lexicalSimilarity(textA, textB);
    final surface = _surfaceStats(textA, textB);
    final local = _localSemanticRecallAnalysis(textA, textB, surface);

    final candidatesA = _semanticRecallCandidates(textA, counterpart: textB, role: 'A');
    final candidatesB = _semanticRecallCandidates(textB, counterpart: textA, role: 'B');
    final bestHit = await _bestRecallEmbeddingHit(
      candidatesA: candidatesA,
      candidatesB: candidatesB,
      settings: settings,
      originalTextA: textA,
      originalTextB: textB,
      originalPayloadA: payloadA,
      originalPayloadB: payloadB,
      rawScore: rawScore,
    );

    var finalScore = max(rawScore, max(bestHit.score, local.score)).clamp(-1.0, 1.0).toDouble();
    var warningCode = local.warningCode;
    var keyDifference = local.keyDifference;
    var capApplied = false;
    if (local.scoreCap != null && finalScore > local.scoreCap!) {
      finalScore = local.scoreCap!;
      capApplied = true;
      warningCode = 'surface_order_mismatch_cap_applied';
      keyDifference = local.keyDifference;
    }

    final routeScores = <String, Object?>{
      'raw_embedding_cosine': rawScore,
      'best_recall_embedding_score': bestHit.score,
      'local_rule_score': local.score,
      'lexical_ordered_similarity': lexicalScore,
      'char_set_overlap': surface.charSetJaccard,
      'bigram_dice': surface.bigramDice,
      'trigram_dice': surface.trigramDice,
      'edit_similarity': surface.editSimilarity,
      'final_multi_route_score': finalScore,
      'score_cap_applied': capApplied,
      if (local.scoreCap != null) 'score_cap': local.scoreCap,
    };

    final explanationParts = <String>[
      '原始 A/B Embedding cosine=${rawScore.toStringAsFixed(4)}。',
      '多路召回最高向量命中=${bestHit.score.toStringAsFixed(4)}（${bestHit.routeLabel}）。',
      '本地概念/关键词/词序规则分=${local.score.toStringAsFixed(4)}。',
      '词序敏感词面相似=${lexicalScore.toStringAsFixed(4)}，字符集合重合=${surface.charSetJaccard.toStringAsFixed(4)}，bigram=${surface.bigramDice.toStringAsFixed(4)}。',
    ];
    if (local.hits.isNotEmpty) {
      explanationParts.add('命中规则：${local.hits.take(6).join('；')}。');
    }
    if (local.conceptHits.isNotEmpty) {
      explanationParts.add('命中概念原型：${local.conceptHits.take(6).join('、')}。');
    }
    if (capApplied) {
      explanationParts.add('已触发短文本同字乱序/词序不可靠惩罚，因此最终诊断分数被上限限制。');
    }
    explanationParts.add('最终多路诊断分=${finalScore.toStringAsFixed(4)}。注意：该分数只用于召回诊断，不等同于严格语义等价。');

    return _EmbeddingSimilarityAnalysis(
      rawScore: rawScore,
      semanticScore: bestHit.score,
      lexicalScore: lexicalScore,
      localPriorScore: local.score > 0 ? local.score : null,
      finalScore: finalScore,
      warningCode: warningCode,
      keyDifference: keyDifference,
      explanation: explanationParts.join(''),
      semanticInputA: bestHit.textA,
      semanticInputB: bestHit.textB,
      suspiciousSurfaceMatch: surface.suspiciousShortReorder,
      bestEmbeddingRoute: bestHit.routeLabel,
      bestEmbeddingTextA: bestHit.textA,
      bestEmbeddingTextB: bestHit.textB,
      recallCandidateCountA: candidatesA.length,
      recallCandidateCountB: candidatesB.length,
      localRuleHits: local.hits,
      conceptHits: local.conceptHits,
      routeScores: routeScores,
      surfaceStats: surface.toJson(),
    );
  }

  String _relationFromMultiRouteScore(
    double score,
    _EmbeddingScoreThresholds thresholds,
    _EmbeddingSimilarityAnalysis analysis,
  ) {
    if (analysis.suspiciousSurfaceMatch) return 'surface_order_mismatch';
    if (score >= thresholds.high) return 'high_multi_route_related';
    if (score >= thresholds.low) return 'medium_multi_route_related';
    return 'low_multi_route_related';
  }

  String _embeddingOnlyDiagnosticWarning(String textA, String textB, double rawCosine, double lexicalScore) {
    final a = textA.trim().replaceAll(RegExp(r'\s+'), '');
    final b = textB.trim().replaceAll(RegExp(r'\s+'), '');
    if (a == b) return '';
    if (a.length >= 3 && b.length >= 3 && a.length <= 8 && b.length <= 8 && lexicalScore >= 0.75 && rawCosine >= 0.50) {
      return '注意：两段短文本词面非常接近。Embedding 可能把错别字/近字形/近短语判得较高；该提示不参与最终分数。';
    }
    return '';
  }


  Future<_RecallEmbeddingHit> _bestRecallEmbeddingHit({
    required List<_SemanticRecallCandidate> candidatesA,
    required List<_SemanticRecallCandidate> candidatesB,
    required SemanticConsistencySettings settings,
    required String originalTextA,
    required String originalTextB,
    required _EmbeddingVectorPayload originalPayloadA,
    required _EmbeddingVectorPayload originalPayloadB,
    required double rawScore,
  }) async {
    var best = _RecallEmbeddingHit(
      score: rawScore,
      textA: originalTextA,
      textB: originalTextB,
      channelA: 'original',
      channelB: 'original',
    );
    final vectorCache = <String, List<double>>{
      _normalizeForMatch(originalTextA): originalPayloadA.vector,
      _normalizeForMatch(originalTextB): originalPayloadB.vector,
    };
    final limitedA = _dedupeCandidates(candidatesA).take(10).toList();
    final limitedB = _dedupeCandidates(candidatesB).take(10).toList();

    Future<List<double>> vectorFor(_SemanticRecallCandidate c, String original, _EmbeddingVectorPayload payload) async {
      final key = _normalizeForMatch(c.text);
      final cached = vectorCache[key];
      if (cached != null) return cached;
      if (_normalizeForMatch(original) == key) {
        vectorCache[key] = payload.vector;
        return payload.vector;
      }
      final vector = await _embeddingWithCache(c.text, settings);
      vectorCache[key] = vector;
      return vector;
    }

    for (final a in limitedA) {
      late final List<double> va;
      try {
        va = await vectorFor(a, originalTextA, originalPayloadA);
      } catch (_) {
        continue;
      }
      for (final b in limitedB) {
        late final List<double> vb;
        try {
          vb = await vectorFor(b, originalTextB, originalPayloadB);
        } catch (_) {
          continue;
        }
        final score = cosineSimilarity(va, vb).clamp(-1.0, 1.0).toDouble();
        if (score > best.score) {
          best = _RecallEmbeddingHit(
            score: score,
            textA: a.text,
            textB: b.text,
            channelA: a.channel,
            channelB: b.channel,
          );
        }
      }
    }
    return best;
  }

  List<_SemanticRecallCandidate> _dedupeCandidates(List<_SemanticRecallCandidate> items) {
    final seen = <String>{};
    final out = <_SemanticRecallCandidate>[];
    for (final item in items) {
      final text = item.text.trim();
      if (text.isEmpty) continue;
      final key = _normalizeForMatch(text);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(_SemanticRecallCandidate(text: text, channel: item.channel));
    }
    return out;
  }

  List<_SemanticRecallCandidate> _semanticRecallCandidates(
    String text, {
    required String counterpart,
    required String role,
  }) {
    final out = <_SemanticRecallCandidate>[];
    void add(String value, String channel) {
      final t = value.trim();
      if (t.isEmpty) return;
      if (t.length > 1600) {
        out.add(_SemanticRecallCandidate(text: t.substring(0, 1600), channel: '$channel:truncated'));
      } else {
        out.add(_SemanticRecallCandidate(text: t, channel: channel));
      }
    }

    add(text, '$role:original');

    final units = _semanticUnits(text);
    units.sort((a, b) => _unitRecallPriority(b, counterpart).compareTo(_unitRecallPriority(a, counterpart)));
    for (final unit in units.take(7)) {
      add(unit, '$role:unit');
    }

    final matchedConcepts = <_ConceptPrototype>[];
    for (final concept in _builtInConcepts) {
      final activation = _conceptActivation(text, concept);
      if (activation >= 0.60 || _conceptPhraseRuleHit(text, concept)) {
        matchedConcepts.add(concept);
      }
    }

    for (final concept in matchedConcepts.take(4)) {
      add(concept.name, '$role:concept_name:${concept.name}');
      add(concept.definition, '$role:concept_definition:${concept.name}');
      for (final alias in concept.aliases.take(3)) {
        add(alias, '$role:concept_alias:${concept.name}');
      }
      for (final expr in concept.typicalExpressions.take(4)) {
        add(expr, '$role:concept_expression:${concept.name}');
      }
    }

    return _dedupeCandidates(out);
  }

  double _unitRecallPriority(String unit, String counterpart) {
    final lexical = _lexicalSimilarity(unit, counterpart);
    final keyword = _keywordOverlapScore(unit, counterpart);
    final concept = _sharedConceptScore(unit, counterpart);
    return max(lexical, max(keyword, concept));
  }

  List<String> _semanticUnits(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return <String>[];
    if (cleaned.length > 1600) {
      return _splitArticle(cleaned, chunkSize: 900, overlap: 120).take(16).toList();
    }
    final parts = cleaned
        .split(RegExp(r'(?:\n+|[。！？!?；;，,])'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length <= 1) return parts;
    final merged = <String>[];
    for (final part in parts) {
      if (part.length < 4 && merged.isNotEmpty) {
        merged[merged.length - 1] = '${merged.last}，$part';
      } else {
        merged.add(part);
      }
    }
    return merged;
  }

  _LocalRecallAnalysis _localSemanticRecallAnalysis(String textA, String textB, _SurfaceStats surface) {
    final hits = <String>[];
    final conceptHits = <String>[];
    var score = 0.0;
    String warningCode = 'multi_route_recall_diagnostic';
    String keyDifference = 'Embedding 原始分数不是最终判断；已额外检查概念原型、典型表达、关键词、词序和短文本乱序。';
    double? cap;

    if (surface.suspiciousShortReorder) {
      hits.add('短文本同字重排但 bigram/trigram 低，疑似乱序无效表达');
      warningCode = 'surface_order_mismatch';
      keyDifference = '两段短文本字符高度重合，但词序结构不同，不能仅凭字面或向量相似判语义一致。';
      cap = 0.35;
    }

    final keywordScore = _keywordOverlapScore(textA, textB);
    if (keywordScore >= 0.45) {
      score = max(score, keywordScore);
      hits.add('关键词/短语命中 ${(keywordScore * 100).toStringAsFixed(0)}%');
    }

    final sharedConcept = _sharedConceptScore(textA, textB);
    if (sharedConcept >= 0.55) {
      score = max(score, sharedConcept);
      hits.add('双方命中同一概念原型 ${(sharedConcept * 100).toStringAsFixed(0)}%');
    }

    for (final concept in _builtInConcepts) {
      final a = _conceptActivation(textA, concept);
      final b = _conceptActivation(textB, concept);
      final aRule = _conceptPhraseRuleHit(textA, concept);
      final bRule = _conceptPhraseRuleHit(textB, concept);
      if ((a > 0 && (b > 0 || bRule)) || (b > 0 && aRule) || (aRule && bRule)) {
        final conceptScore = max(max(a, b), (aRule || bRule) ? 0.78 : 0.0);
        score = max(score, conceptScore);
        conceptHits.add(concept.name);
        hits.add('概念“${concept.name}”命中：A=${a.toStringAsFixed(2)}，B=${b.toStringAsFixed(2)}，规则=${aRule || bRule}');
      }
    }

    if (_hasThinkingButNoAction(textA) && _hasThinkingButNoAction(textB)) {
      score = max(score, 0.86);
      conceptHits.add('知行不一/认知和行动脱节');
      hits.add('双方都命中“想很多/知道/计划” + “做不起来/无法开始/无法落实”的结构');
    }

    if (surface.charSetJaccard >= 0.90 && surface.bigramDice < 0.25 && surface.editSimilarity < 0.50 && !surface.sameNormalized) {
      cap ??= 0.40;
      hits.add('字符集合重合很高但连续片段相似低，已降低词面误判风险');
      warningCode = 'surface_order_sensitive_warning';
      keyDifference = '字符重合不等于语义一致；短语/成语必须看字序。';
    }

    return _LocalRecallAnalysis(
      score: score.clamp(0.0, 1.0).toDouble(),
      hits: hits,
      conceptHits: conceptHits.toSet().toList(),
      warningCode: warningCode,
      keyDifference: keyDifference,
      scoreCap: cap,
    );
  }

  bool _conceptPhraseRuleHit(String text, _ConceptPrototype concept) {
    final t = _normalizeForMatch(text);
    if (concept.name == '知行不一' || concept.name == '认知和行动脱节' || concept.name == '行动阻抗' || concept.name == '目标无法转化为行为') {
      return _hasThinkingButNoAction(t);
    }
    if (concept.name == '反刍/精神内耗') {
      return _containsAny(t, const ['反复想', '反复思考', '停不下来', '内耗', '脑子里转', '一直想']) &&
          _containsAny(t, const ['痛苦', '焦虑', '干扰', '烦', '影响']);
    }
    if (concept.name == '情绪干扰') {
      return _containsAny(t, const ['惹火', '被激怒', '生气', '情绪', '干扰']) &&
          _containsAny(t, const ['分心', '行动', '犯错', '影响']);
    }
    if (concept.name == '完美主义导致不开始') {
      return _containsAny(t, const ['完美', '做不好', '不够好']) && _containsAny(t, const ['不开始', '迟迟', '拖着']);
    }
    if (concept.name == '恐惧失败导致不行动') {
      return _containsAny(t, const ['怕失败', '害怕失败', '担心失败', '怕做不好']) && _containsAny(t, const ['不敢', '不行动', '不开始', '拖']);
    }
    return false;
  }

  bool _hasThinkingButNoAction(String text) {
    final t = _normalizeForMatch(text);
    final thinking = _containsAny(t, const ['想很多', '想得很多', '知道', '应该', '计划', '规划', '明白', '懂道理', '脑子', '认知']);
    final noAction = _containsAny(t, const ['做不起来', '做不到', '行动不起来', '开始不了', '无法开始', '迟迟不开始', '无法落实', '落实不了', '执行不了', '卡住', '不动']);
    return thinking && noAction;
  }

  double _sharedConceptScore(String a, String b) {
    var best = 0.0;
    for (final concept in _builtInConcepts) {
      final av = max(_conceptActivation(a, concept), _conceptPhraseRuleHit(a, concept) ? 0.78 : 0.0);
      final bv = max(_conceptActivation(b, concept), _conceptPhraseRuleHit(b, concept) ? 0.78 : 0.0);
      if (av > 0 && bv > 0) {
        best = max(best, min(av, bv));
      }
    }
    return best.clamp(0.0, 1.0).toDouble();
  }

  double _conceptActivation(String text, _ConceptPrototype concept) {
    final t = _normalizeForMatch(text);
    if (t.isEmpty) return 0;
    if (t.contains(_normalizeForMatch(concept.name))) return 0.95;
    for (final alias in concept.aliases) {
      if (alias.trim().isNotEmpty && t.contains(_normalizeForMatch(alias))) return 0.88;
    }
    for (final expr in concept.typicalExpressions) {
      final e = _normalizeForMatch(expr);
      if (e.isNotEmpty && (t.contains(e) || e.contains(t))) return 0.82;
    }
    var keywordHits = 0;
    for (final kw in concept.keywords) {
      final k = _normalizeForMatch(kw);
      if (k.isNotEmpty && t.contains(k)) keywordHits++;
    }
    if (keywordHits >= 3) return 0.76;
    if (keywordHits == 2) return 0.68;
    if (keywordHits == 1) return 0.38;
    return 0;
  }

  double _keywordOverlapScore(String a, String b) {
    final ka = _semanticKeywords(a);
    final kb = _semanticKeywords(b);
    if (ka.isEmpty || kb.isEmpty) return 0;
    final inter = ka.intersection(kb).length;
    final union = ka.union(kb).length;
    if (union == 0) return 0;
    final jaccard = inter / union;
    final containment = inter / min(ka.length, kb.length);
    return max(jaccard, containment * 0.78).clamp(0.0, 1.0).toDouble();
  }

  Set<String> _semanticKeywords(String text) {
    final t = _normalizeForMatch(text);
    final out = <String>{};
    for (final concept in _builtInConcepts) {
      if (t.contains(_normalizeForMatch(concept.name))) out.add(concept.name);
      for (final alias in concept.aliases) {
        if (t.contains(_normalizeForMatch(alias))) out.add(alias);
      }
      for (final kw in concept.keywords) {
        if (t.contains(_normalizeForMatch(kw))) out.add(kw);
      }
    }
    final rough = t.split(RegExp(r'[，。！？；、,.!?;:\s]+')).where((e) => e.length >= 2);
    out.addAll(rough.take(12));
    return out;
  }

  bool _containsAny(String text, List<String> values) {
    final t = _normalizeForMatch(text);
    for (final value in values) {
      if (t.contains(_normalizeForMatch(value))) return true;
    }
    return false;
  }

  String _normalizeForMatch(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\u3000]+'), '')
        .replaceAll(RegExp(r'''[“”"‘’'`·、，。！？；：,.!?;:()（）\[\]【】{}《》<>-]'''), '');
  }

  _SurfaceStats _surfaceStats(String a, String b) {
    final x = _normalizeForMatch(a);
    final y = _normalizeForMatch(b);
    if (x.isEmpty || y.isEmpty) {
      return const _SurfaceStats(
        editSimilarity: 0,
        bigramDice: 0,
        trigramDice: 0,
        charSetJaccard: 0,
        suspiciousShortReorder: false,
        sameNormalized: false,
      );
    }
    final edit = 1.0 - (_levenshtein(x, y) / max(x.length, y.length));
    final bigram = _charBigramDice(x, y);
    final trigram = _charTrigramDice(x, y);
    final charSet = _charSetJaccard(x, y);
    final same = x == y;
    final suspicious = !same && x.length >= 3 && y.length >= 3 && x.length <= 8 && y.length <= 8 && charSet >= 0.90 && bigram < 0.25 && edit < 0.50;
    return _SurfaceStats(
      editSimilarity: edit.clamp(0.0, 1.0).toDouble(),
      bigramDice: bigram,
      trigramDice: trigram,
      charSetJaccard: charSet,
      suspiciousShortReorder: suspicious,
      sameNormalized: same,
    );
  }

  List<_ConceptPrototype> get _builtInConcepts => const <_ConceptPrototype>[
        _ConceptPrototype(
          name: '知行不一',
          definition: '知道、理解或计划了某件事，但实际行动没有跟上。',
          aliases: ['认知和行动脱节', '知道但做不到', '想很多但做不起来', '想法和行动不一致'],
          typicalExpressions: ['我总是想很多但做不起来', '知道应该做但就是行动不起来', '计划很多但无法落实成行为', '脑子里很清楚但身体动不起来'],
          keywords: ['想很多', '做不起来', '知道', '行动不起来', '无法开始', '无法落实', '计划很多', '执行不了'],
        ),
        _ConceptPrototype(
          name: '认知和行动脱节',
          definition: '认知层面已经理解或认可，但行为层面无法启动、执行或持续。',
          aliases: ['知行不一', '目标无法转化为行为', '认知行动断裂', '脑子清楚但行动卡住'],
          typicalExpressions: ['我想得很明白但就是开始不了', '我脑子里计划很清楚但执行时卡住', '道理都懂但做不到'],
          keywords: ['认知', '行动', '脱节', '做不到', '开始不了', '卡住', '执行'],
        ),
        _ConceptPrototype(
          name: '行动阻抗',
          definition: '个体在开始或持续行动时感到明显心理阻力。',
          aliases: ['启动困难', '行动启动阻抗', '开始阻力', '执行阻抗'],
          typicalExpressions: ['我知道要做但启动不了', '一到开始执行就卡住', '迟迟无法迈出第一步'],
          keywords: ['启动不了', '开始不了', '卡住', '阻力', '行动', '执行', '第一步'],
        ),
        _ConceptPrototype(
          name: '目标无法转化为行为',
          definition: '有目标或计划，但不能拆解并落实成具体行动。',
          aliases: ['目标落不了地', '计划无法执行', '目标行动断裂'],
          typicalExpressions: ['目标很多但都没有落实', '计划写得很详细但没有开始做', '我有方向但落不到行动上'],
          keywords: ['目标', '计划', '落实', '执行', '行动', '落地', '转化'],
        ),
        _ConceptPrototype(
          name: '拖延',
          definition: '明知需要行动却不断推迟开始或完成。',
          aliases: ['延宕', '一直拖', '拖到明天'],
          typicalExpressions: ['我总是拖到最后一刻', '明知道该做但一直拖着', '一直推迟不开始'],
          keywords: ['拖延', '拖着', '推迟', '最后一刻', '明天再说', '迟迟'],
        ),
        _ConceptPrototype(
          name: '完美主义导致不开始',
          definition: '因为要求完美或害怕不够好，导致迟迟不开始行动。',
          aliases: ['完美主义拖延', '怕不完美所以不开始', '高标准阻碍行动'],
          typicalExpressions: ['我怕做得不够好所以一直没开始', '总想准备完美才行动', '不完美就不想做'],
          keywords: ['完美', '不够好', '准备好', '高标准', '不开始', '迟迟'],
        ),
        _ConceptPrototype(
          name: '恐惧失败导致不行动',
          definition: '因为害怕失败、出错或被评价而回避行动。',
          aliases: ['失败恐惧', '害怕失败', '怕做不好'],
          typicalExpressions: ['我怕失败所以不敢开始', '担心做不好就一直拖着', '害怕出错导致不行动'],
          keywords: ['失败', '害怕', '怕做不好', '不敢', '出错', '评价', '不行动'],
        ),
        _ConceptPrototype(
          name: '自我效能感低',
          definition: '个体不相信自己有能力完成任务或改变结果。',
          aliases: ['能力感低', '不相信自己能做到', '低自我效能'],
          typicalExpressions: ['我觉得自己肯定做不到', '还没开始就觉得自己不行', '我不相信自己能坚持下来'],
          keywords: ['做不到', '不行', '没能力', '不相信自己', '坚持不了', '效能'],
        ),
        _ConceptPrototype(
          name: '反刍/精神内耗',
          definition: '对同一件事反复思考、回放和纠缠，造成注意力和行动受损。',
          aliases: ['反刍思维', '精神内耗', '反复想', '自动思维'],
          typicalExpressions: ['我会把这件事反复思考停不下来', '脑子里一直回放导致无法行动', '我陷入内耗和反刍'],
          keywords: ['反复想', '反复思考', '内耗', '自动思维', '回放', '停不下来', '纠缠'],
        ),
        _ConceptPrototype(
          name: '情绪干扰',
          definition: '外部刺激引发强烈情绪，导致分心、行动中断或判断失误。',
          aliases: ['被情绪带走', '被惹火后分心', '情绪诱惑分心'],
          typicalExpressions: ['我容易被别人故意惹火后分心', '情绪一上来后续行动就被打乱', '被外界刺激影响导致犯错'],
          keywords: ['惹火', '生气', '情绪', '干扰', '分心', '行动', '犯错', '打乱'],
        ),
        _ConceptPrototype(
          name: '目标模糊/动力不足',
          definition: '缺乏明确目标、意义感或持续动机，导致行动难以坚持。',
          aliases: ['没有明确目标', '缺乏动力', '持之以恒不足', '长期目标失焦'],
          typicalExpressions: ['我总是没有明确目标也缺乏强大动力', '不知道自己真正要追求什么', '很难持续坚持一件事'],
          keywords: ['目标', '动力', '坚持', '持之以恒', '意义', '方向', '模糊'],
        ),
        _ConceptPrototype(
          name: '各行其是',
          definition: '各人按照自己认为对的方式去做，彼此不协调。',
          aliases: ['各自为政', '各干各的'],
          typicalExpressions: ['大家各行其是，没有统一行动', '各自按照自己的想法去做'],
          keywords: ['各行其是', '各自', '各干各的', '不协调'],
        ),
      ];

  _EmbeddingScoreThresholds _effectiveEmbeddingThresholds(SemanticConsistencySettings settings) {
    // v14: fastEmbedding 使用模型原生 cosine 判定“向量相关度”。
    // 旧版本曾保存过 0.40/0.70 或归一化阈值；这些阈值会把“鸟/鱼”这类
    // 仅同属大类的词误标为“高语义相关”。这里对旧值做保护：
    // - 高向量相关阈值低于 0.55 时视为旧配置，提升到默认 0.65；
    // - 中等相关阈值低于 0.30 或高于 0.65 时回到默认 0.45。
    var low = settings.lowThreshold;
    var high = settings.highThreshold;
    if (low < 0.30 || low > 0.65) low = SemanticConsistencySettings.defaultLowThreshold;
    if (high < 0.55 || high > 0.90) high = SemanticConsistencySettings.defaultHighThreshold;
    if (high <= low) high = (low + 0.20).clamp(0.55, 0.90).toDouble();
    return _EmbeddingScoreThresholds(low: low.clamp(-1.0, 1.0).toDouble(), high: high.clamp(-1.0, 1.0).toDouble());
  }

  String _relationFromEmbeddingScore(double score, _EmbeddingScoreThresholds thresholds) {
    // Embedding-only 模式输出的是“语义相似度/语义相关度”，不是严格事实等价关系。
    // 因此这里不用 equivalent/contradiction 这类 LLM Judge 关系标签。
    if (score >= thresholds.high) return 'high_vector_related';
    if (score >= thresholds.low) return 'medium_vector_related';
    return 'low_vector_related';
  }

  double _lexicalSimilarity(String a, String b) {
    final x = _normalizeForMatch(a);
    final y = _normalizeForMatch(b);
    if (x.isEmpty || y.isEmpty) return 0;
    if (x == y) return 1;
    final edit = 1.0 - (_levenshtein(x, y) / max(x.length, y.length));
    final bigram = _charBigramDice(x, y);
    final trigram = _charTrigramDice(x, y);
    final charSet = _charSetJaccard(x, y);
    // 字符集合相似只作为弱证据，不能覆盖字序证据。
    // 例如“各行其是/是其行各”单字集合=1，但 bigram/trigram≈0，不能显示成 1.0。
    final ordered = max(edit, max(bigram, trigram));
    return max(ordered, min(charSet, ordered + 0.18)).clamp(0.0, 1.0).toDouble();
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        cur[j + 1] = min(min(cur[j] + 1, prev[j + 1] + 1), prev[j] + cost);
      }
      prev = cur;
    }
    return prev[b.length];
  }

  double _charBigramDice(String a, String b) {
    final ax = _bigrams(a);
    final bx = _bigrams(b);
    if (ax.isEmpty || bx.isEmpty) return 0;
    var overlap = 0;
    final counts = <String, int>{};
    for (final item in ax) {
      counts[item] = (counts[item] ?? 0) + 1;
    }
    for (final item in bx) {
      final c = counts[item] ?? 0;
      if (c > 0) {
        overlap++;
        counts[item] = c - 1;
      }
    }
    return (2.0 * overlap / (ax.length + bx.length)).clamp(0.0, 1.0).toDouble();
  }

  double _charTrigramDice(String a, String b) {
    final ax = _ngrams(a, 3);
    final bx = _ngrams(b, 3);
    if (ax.isEmpty || bx.isEmpty) return 0;
    var overlap = 0;
    final counts = <String, int>{};
    for (final item in ax) {
      counts[item] = (counts[item] ?? 0) + 1;
    }
    for (final item in bx) {
      final c = counts[item] ?? 0;
      if (c > 0) {
        overlap++;
        counts[item] = c - 1;
      }
    }
    return (2.0 * overlap / (ax.length + bx.length)).clamp(0.0, 1.0).toDouble();
  }

  List<String> _bigrams(String value) {
    if (value.length < 2) return value.isEmpty ? <String>[] : <String>[value];
    return List<String>.generate(value.length - 1, (i) => value.substring(i, i + 2));
  }

  List<String> _ngrams(String value, int n) {
    if (value.length < n) return <String>[];
    return List<String>.generate(value.length - n + 1, (i) => value.substring(i, i + n));
  }

  double _charSetJaccard(String a, String b) {
    final as = a.split('').toSet();
    final bs = b.split('').toSet();
    if (as.isEmpty || bs.isEmpty) return 0;
    final inter = as.intersection(bs).length;
    final union = as.union(bs).length;
    if (union == 0) return 0;
    return (inter / union).clamp(0.0, 1.0).toDouble();
  }

  Future<List<double>> _embeddingWithCache(String text, SemanticConsistencySettings settings) async {
    return (await _embeddingWithCacheDetailed(text, settings)).vector;
  }

  Future<_EmbeddingVectorPayload> _embeddingWithCacheDetailed(
    String text,
    SemanticConsistencySettings settings, {
    bool bypassCache = false,
  }) async {
    final normalized = text.trim();
    final cacheDim = _cacheDimensionsForSettings(settings);
    final hash = _stableHash(
      'semantic_embedding_native_v16\n'
      '${settings.embeddingProvider}\n'
      '${settings.embeddingModel}\n'
      '$cacheDim\n'
      '${settings.embeddingEndpoint}\n'
      '${_shouldSendEmbeddingDimensions(settings)}\n'
      '$normalized',
    );

    if (!bypassCache) {
      final cached = await _dao.findEmbedding(
        textHash: hash,
        provider: settings.embeddingProvider,
        model: settings.embeddingModel,
        dimensions: cacheDim,
      );
      if (cached != null && cached.isNotEmpty) {
        return _EmbeddingVectorPayload(
          vector: cached,
          cacheHit: true,
          cacheHash: hash,
          extractionPath: 'cache.semantic_embedding_cache.vector_json',
          usage: null,
          responseProvider: null,
        );
      }
    }

    final call = await _createEmbeddingDetailed(normalized, settings);
    await _dao.upsertEmbedding(
      textHash: hash,
      textContent: normalized,
      provider: settings.embeddingProvider,
      model: settings.embeddingModel,
      dimensions: cacheDim,
      vector: call.vector,
    );
    return _EmbeddingVectorPayload(
      vector: call.vector,
      cacheHit: false,
      cacheHash: hash,
      extractionPath: call.extractionPath,
      usage: call.usage,
      responseProvider: call.responseProvider,
    );
  }

  int _cacheDimensionsForSettings(SemanticConsistencySettings settings) {
    // 只有当请求真实发送 dimensions 时，缓存键才使用用户配置的维度。
    // 对 Qwen/BGE/Cohere/Gemini/Jina/EdenAI 默认维度模型，不把配置框里的数字当成真实维度，避免旧缓存污染。
    return _shouldSendEmbeddingDimensions(settings) ? settings.embeddingDimensions : 0;
  }

  Future<_EmbeddingCallResult> _createEmbeddingDetailed(String input, SemanticConsistencySettings settings) async {
    final apiKey = await settings.resolveEmbeddingApiKey();
    if (apiKey.trim().isEmpty) {
      throw StateError('未配置 ${settings.embeddingProviderLabel} API Key，无法生成 Embedding。');
    }
    final requestCfg = await _requestSettings.getConfig();
    final endpoint = settings.embeddingEndpoint;
    final providerKey = settings.embeddingProvider.trim().toLowerCase();
    final headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      if (providerKey == 'openrouter') 'X-OpenRouter-Title': 'Quote App',
      if (providerKey == 'edenai') 'Accept': 'application/json',
      if (providerKey == 'edenai') 'Connection': 'close',
    };
    final sendDimensions = _shouldSendEmbeddingDimensions(settings);
    final body = <String, Object?>{
      'model': settings.embeddingModel,
      'input': input,
      'encoding_format': 'float',
      if (sendDimensions) 'dimensions': settings.embeddingDimensions,
    };

    await DeepSeekLogger.logRequest(
      provider: settings.embeddingProviderLabel,
      module: 'semantic_consistency.embedding',
      endpoint: endpoint,
      headers: headers,
      body: <String, Object?>{
        'model': settings.embeddingModel,
        'input_length': input.length,
        'input_preview': _preview(input, 260),
        if (sendDimensions) 'dimensions': settings.embeddingDimensions,
        'dimensions_sent': sendDimensions,
        if (!sendDimensions) 'dimensions_note': '当前模型未确认支持 dimensions 参数，已使用模型默认向量维度，避免请求被上游拒绝。',
      },
      model: settings.embeddingModel,
    );

    final resp = await http
        .post(Uri.parse(endpoint), headers: headers, body: jsonEncode(body))
        .timeout(requestCfg.resolveTimeout(const Duration(seconds: 60)));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      await DeepSeekLogger.logResponse(
        provider: settings.embeddingProviderLabel,
        module: 'semantic_consistency.embedding',
        endpoint: endpoint,
        statusCode: resp.statusCode,
        body: resp.body,
        model: settings.embeddingModel,
      );
      throw Exception('Embedding 请求失败：HTTP ${resp.statusCode} ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);
    final extraction = _extractEmbeddingWithPath(decoded);
    final vector = extraction.vector;
    if (vector.isEmpty) {
      await DeepSeekLogger.logResponse(
        provider: settings.embeddingProviderLabel,
        module: 'semantic_consistency.embedding',
        endpoint: endpoint,
        statusCode: resp.statusCode,
        body: <String, Object?>{
          'model': settings.embeddingModel,
          'input_length': input.length,
          'input_preview': _preview(input, 260),
          'embedding_found': false,
          'response_top_level_keys': decoded is Map ? decoded.keys.map((e) => e.toString()).toList() : null,
          'raw_response_preview': _preview(resp.body, 1600),
        },
        model: settings.embeddingModel,
      );
      throw Exception('Embedding 响应中没有找到真实向量字段。已拒绝 fallback。响应预览：${_preview(resp.body, 900)}');
    }

    final diagnostics = _vectorDiagnostics(vector);
    await DeepSeekLogger.logResponse(
      provider: settings.embeddingProviderLabel,
      module: 'semantic_consistency.embedding',
      endpoint: endpoint,
      statusCode: resp.statusCode,
      body: <String, Object?>{
        'model': settings.embeddingModel,
        'input_length': input.length,
        'input_preview': _preview(input, 260),
        'embedding_found': true,
        'embedding_extraction_path': extraction.path,
        'vector_dims': vector.length,
        'vector_diagnostics': diagnostics,
        'usage': decoded is Map ? decoded['usage'] : null,
        'provider': decoded is Map ? decoded['provider'] : null,
        'response_top_level_keys': decoded is Map ? decoded.keys.map((e) => e.toString()).toList() : null,
        'full_vector_logged': false,
        'full_vector_note': '未在日志中完整写入高维向量，避免日志数据库膨胀；checksum/head/norm 可确认真实向量已返回。',
      },
      model: settings.embeddingModel,
    );

    return _EmbeddingCallResult(
      vector: vector,
      extractionPath: extraction.path,
      usage: decoded is Map ? decoded['usage'] : null,
      responseProvider: decoded is Map ? decoded['provider'] : null,
    );
  }

  bool _shouldSendEmbeddingDimensions(SemanticConsistencySettings settings) {
    if (settings.embeddingDimensions <= 0) return false;
    final model = settings.embeddingModel.trim().toLowerCase();
    // dimensions 不是所有 embedding 模型都支持。Qwen/BGE/Cohere/Jina 等模型通常应使用默认维度。
    // 只对明确支持可变 dimensions 的 OpenAI text-embedding-3 系列发送该参数。
    return model == 'text-embedding-3-small' ||
        model == 'text-embedding-3-large' ||
        model == 'openai/text-embedding-3-small' ||
        model == 'openai/text-embedding-3-large';
  }

  _EmbeddingExtraction _extractEmbeddingWithPath(dynamic decoded) {
    if (decoded is Map) {
      final data = decoded['data'];
      if (data is List && data.isNotEmpty) {
        final first = data.first;
        if (first is Map && _isNumericList(first['embedding'])) {
          return _EmbeddingExtraction(
            vector: (first['embedding'] as List).map((e) => (e as num).toDouble()).toList(),
            path: 'data[0].embedding',
          );
        }
      }
      if (_isNumericList(decoded['embedding'])) {
        return _EmbeddingExtraction(
          vector: (decoded['embedding'] as List).map((e) => (e as num).toDouble()).toList(),
          path: 'embedding',
        );
      }
      if (_isNumericList(decoded['vector'])) {
        return _EmbeddingExtraction(
          vector: (decoded['vector'] as List).map((e) => (e as num).toDouble()).toList(),
          path: 'vector',
        );
      }
      if (decoded['embeddings'] is List) {
        final embeddings = decoded['embeddings'] as List;
        if (embeddings.isNotEmpty && _isNumericList(embeddings.first)) {
          return _EmbeddingExtraction(
            vector: (embeddings.first as List).map((e) => (e as num).toDouble()).toList(),
            path: 'embeddings[0]',
          );
        }
      }
      final recursive = _findEmbeddingRecursively(decoded, 'root', maxDepth: 5);
      if (recursive.vector.isNotEmpty) return recursive;
    }
    return const _EmbeddingExtraction(vector: <double>[], path: 'not_found');
  }

  bool _isNumericList(Object? value) {
    if (value is! List || value.isEmpty) return false;
    if (value.length < 8) return false;
    return value.every((e) => e is num);
  }

  _EmbeddingExtraction _findEmbeddingRecursively(Object? node, String path, {required int maxDepth}) {
    if (maxDepth < 0 || node == null) return const _EmbeddingExtraction(vector: <double>[], path: 'not_found');
    if (_isNumericList(node)) {
      return _EmbeddingExtraction(
        vector: (node as List).map((e) => (e as num).toDouble()).toList(),
        path: path,
      );
    }
    if (node is Map) {
      const priorityKeys = <String>['embedding', 'embeddings', 'vector', 'values'];
      for (final key in priorityKeys) {
        if (node.containsKey(key)) {
          final found = _findEmbeddingRecursively(node[key], '$path.$key', maxDepth: maxDepth - 1);
          if (found.vector.isNotEmpty) return found;
        }
      }
      for (final entry in node.entries) {
        final found = _findEmbeddingRecursively(entry.value, '$path.${entry.key}', maxDepth: maxDepth - 1);
        if (found.vector.isNotEmpty) return found;
      }
    } else if (node is List) {
      for (var i = 0; i < node.length && i < 5; i++) {
        final found = _findEmbeddingRecursively(node[i], '$path[$i]', maxDepth: maxDepth - 1);
        if (found.vector.isNotEmpty) return found;
      }
    }
    return const _EmbeddingExtraction(vector: <double>[], path: 'not_found');
  }

  Future<void> _logEmbeddingCosineDiagnostics({
    required SemanticConsistencySettings settings,
    required String textA,
    required String textB,
    required List<double> vectorA,
    required List<double> vectorB,
    required double rawCosine,
    required double dot,
    required double normA,
    required double normB,
    required _EmbeddingScoreThresholds thresholds,
    required double lexicalScore,
    required _EmbeddingVectorPayload payloadA,
    required _EmbeddingVectorPayload payloadB,
  }) async {
    await DeepSeekLogger.logResponse(
      provider: settings.embeddingProviderLabel,
      module: 'semantic_consistency.embedding_cosine',
      endpoint: 'local://semantic_consistency/embedding_cosine',
      statusCode: 200,
      body: <String, Object?>{
        'calculator': 'app_local_dart_cosine_similarity',
        'formula': 'cosine = dot(vectorA, vectorB) / (l2Norm(vectorA) * l2Norm(vectorB))',
        'model': settings.embeddingModel,
        'provider': settings.embeddingProvider,
        'endpoint': settings.embeddingEndpoint,
        'text_a_preview': _preview(textA, 160),
        'text_b_preview': _preview(textB, 160),
        'vector_a': _vectorDiagnostics(vectorA),
        'vector_b': _vectorDiagnostics(vectorB),
        'text_a_cache_hit': payloadA.cacheHit,
        'text_b_cache_hit': payloadB.cacheHit,
        'text_a_extraction_path': payloadA.extractionPath,
        'text_b_extraction_path': payloadB.extractionPath,
        'dot_product': dot,
        'vector_a_l2_norm': normA,
        'vector_b_l2_norm': normB,
        'cosine': rawCosine,
        'lexical_similarity_for_diagnosis_only': lexicalScore,
        'low_threshold': thresholds.low,
        'high_threshold': thresholds.high,
        'llm_used': false,
        'local_rule_used': false,
        'fallback_used': false,
        'note': 'Embedding API 只返回向量；这个 cosine 分数由 App 本地计算。词面相似度仅诊断，不参与 cosine。',
      },
      model: settings.embeddingModel,
    );
  }

  Map<String, Object?> _vectorDiagnostics(List<double> vector) {
    return <String, Object?>{
      'dims': vector.length,
      'l2_norm': _l2Norm(vector),
      'min': _vectorMin(vector),
      'max': _vectorMax(vector),
      'mean': _vectorMean(vector),
      'abs_mean': _vectorAbsMean(vector),
      'head_12': _vectorHead(vector, 12),
      'checksum_sha256_rounded_8dp': _vectorChecksum(vector),
      'full_vector_logged': false,
    };
  }

  double _dotProduct(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw StateError('Embedding 向量维度不一致，无法计算 dot product：${a.length} vs ${b.length}');
    }
    var dot = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }

  double _l2Norm(List<double> vector) {
    if (vector.isEmpty) return 0;
    var sum = 0.0;
    for (final v in vector) {
      sum += v * v;
    }
    return sqrt(sum);
  }

  double _vectorMin(List<double> vector) {
    if (vector.isEmpty) return 0;
    var value = vector.first;
    for (final v in vector) {
      if (v < value) value = v;
    }
    return value;
  }

  double _vectorMax(List<double> vector) {
    if (vector.isEmpty) return 0;
    var value = vector.first;
    for (final v in vector) {
      if (v > value) value = v;
    }
    return value;
  }

  double _vectorMean(List<double> vector) {
    if (vector.isEmpty) return 0;
    var sum = 0.0;
    for (final v in vector) {
      sum += v;
    }
    return sum / vector.length;
  }

  double _vectorAbsMean(List<double> vector) {
    if (vector.isEmpty) return 0;
    var sum = 0.0;
    for (final v in vector) {
      sum += v.abs();
    }
    return sum / vector.length;
  }

  List<double> _vectorHead(List<double> vector, int count) {
    final n = min(count, vector.length);
    return vector.take(n).map((v) => double.parse(v.toStringAsFixed(8))).toList();
  }

  String _vectorChecksum(List<double> vector) {
    final rounded = vector.map((v) => v.toStringAsFixed(8)).join(',');
    return sha256.convert(utf8.encode(rounded)).toString();
  }

  Future<String> _extractEventStructure(String text, String label) async {
    final prompt = '''请把下面文本抽取成严格事件结构，只输出 JSON，不要输出 markdown。

文本$label：
$text

输出格式：
{
  "events": [
    {
      "action": "动作/关系",
      "agent": "施事者/主体",
      "patient": "受事者/对象",
      "polarity": "affirmative|negative|unclear",
      "tense": "past|present|future|unclear",
      "modality": "factual|possible|hypothetical|counterfactual|almost|unclear",
      "condition": "条件或限制，没有则空字符串",
      "time": "时间，没有则空字符串",
      "location": "地点，没有则空字符串"
    }
  ],
  "notes": "歧义或省略说明"
}''';
    try {
      final raw = await _aiService.generateText(
        prompt: prompt,
        purpose: 'semantic_consistency.extract_event',
        systemPrompt: '你是严谨的信息抽取器。只输出合法 JSON。',
        maxTokens: 900,
        expectJson: true,
        temperature: 0,
      );
      return raw.trim();
    } catch (e) {
      return jsonEncode(<String, Object?>{'events': <Object>[], 'notes': '事件抽取失败：$e'});
    }
  }


  _CommonalityAssessment _buildLocalCommonalityAssessment(String textA, String textB, double? rawEmbeddingCosine) {
    final common = <String>[];
    final different = <String>[];
    final unsupported = <String>[];
    final commonConcepts = <String>[];
    final differenceAxes = <String>[];
    final a = textA.trim();
    final b = textB.trim();
    final catsA = _semanticContextCategories(a);
    final catsB = _semanticContextCategories(b);
    final sharedTimes = _sharedTimeExpressions(a, b);

    if (sharedTimes.isNotEmpty) {
      common.add('都明确提到${sharedTimes.take(3).join('、')}这一时间/时段线索。');
      commonConcepts.add('浅层共同背景：共同时间线索=${sharedTimes.take(3).join('、')}；只能说明发生时间相近，不能单独构成强语义相关。');
    }
    if (_containsFirstPerson(a) && _containsFirstPerson(b)) {
      common.add('都以第一人称描述个人经历、状态或行动。');
      commonConcepts.add('浅层共同背景：第一人称个人叙述；这是表达视角共同，不等于主题或事实共同。');
    }
    if (_looksLikePersonalEvent(a) && _looksLikePersonalEvent(b)) {
      common.add('都像是在描述个人生活事件或当天状态，而不是抽象定义。');
      commonConcepts.add('综合生成的新上位概念：个人生活事件叙述；该共同概念较宽泛，需要结合具体对象/行为判断强弱。');
    }

    final sharedCats = catsA.intersection(catsB).where((e) => e != 'first_person' && e != 'time').toList();
    for (final cat in sharedCats.take(3)) {
      final label = _semanticContextLabel(cat);
      common.add('都涉及“$label”语义场。');
      commonConcepts.add('显性/近显性共同概念：$label；双方文本都出现了可归入该语义场的线索。');
    }

    if (_hasCategoryPair(catsA, catsB, 'health_medical', 'rest_sleep')) {
      common.add('一个涉及就医/医院，另一个涉及卧床/睡眠，二者可能共同落在身体状态、健康或休息语境中。');
      commonConcepts.add('综合生成的新共同概念：身体状态/健康—休息语境；该概念不是双方明说的同一事件，只是可能共同背景。');
    }
    if (_hasCategoryPair(catsA, catsB, 'work', 'fatigue_rest')) {
      common.add('一个涉及工作/任务，另一个涉及疲惫/休息，可能存在生活节奏或精力状态层面的弱关联。');
      commonConcepts.add('综合生成的新共同概念：工作压力—精力恢复语境；需要证据才能上升为因果关系。');
    }
    if (_hasCategoryPair(catsA, catsB, 'emotion', 'rest_sleep')) {
      common.add('一个涉及情绪状态，另一个涉及休息/睡眠，可能共同指向身心状态语境。');
      commonConcepts.add('综合生成的新共同概念：身心状态语境；只能说明可能背景相关，不等于同义或因果。');
    }

    if (_hasCategoryPair(catsA, catsB, 'finance_income', 'intimacy_sexuality')) {
      common.add('一个涉及金钱/收入获得，另一个涉及亲密/性与身体欲望；低层主题不同，但都可以从“人的需求、欲望、奖赏和获得感追求”这一高层目的功能上找到弱上位共同性。');
      commonConcepts.add('综合生成的新上位共同概念：需求/欲望满足；A偏向经济资源与成就奖赏，B偏向亲密/感官/关系奖赏；该共同概念层级很高，只能构成弱抽象共同性。');
      commonConcepts.add('综合生成的新上位共同概念：生活奖赏/获得感追求；二者都可被理解为追求某种满足，但满足类型完全不同。');
    }


    final hasHygieneToIntimacyPreparation = _hasCategoryPair(catsA, catsB, 'hygiene_cleaning', 'intimacy_sexuality');
    if (hasHygieneToIntimacyPreparation) {
      common.add('清洁/洗净身体与亲密/性行为之间可能存在“卫生或身体准备 → 亲密行为”的潜在目的链条。');
      commonConcepts.add('可能关系概念：前置准备/目的关系；清洁身体可能服务于后续亲密行为，但文本没有明说“为了”。');
      commonConcepts.add('综合生成的新共同概念：身体相关私人生活行为；共同性存在，但仍需与卫生行为和亲密行为的差异分开看。');
      unsupported.add('不能确定清洁身体一定是为了亲密行为。');
      unsupported.add('不能确定两句话描述的是同一事件链。');
      unsupported.add('不能把“可能准备关系”说成确定因果或确定目的关系。');
    }

    final abstractA = _abstractCommonalityDimensions(catsA);
    final abstractB = _abstractCommonalityDimensions(catsB);
    final sharedAbstract = abstractA.intersection(abstractB).where((e) => e != 'body_state').toList();
    if (sharedAbstract.isNotEmpty) {
      final labels = sharedAbstract.map(_abstractDimensionLabel).take(3).join('、');
      common.add('从目的、功能、欲望、结果或心理机制上抽象，二者存在弱上位共同维度：“$labels”。');
      commonConcepts.add('综合生成的新上位共同概念：$labels；这是跨领域抽象共同性，需要与直接对象/行为差异分开看，不能直接判为同义或高度相关。');
    }

    final focusA = _roughSemanticFocus(a);
    final focusB = _roughSemanticFocus(b);
    if (focusA.isNotEmpty && focusB.isNotEmpty && focusA != focusB) {
      different.add('文本A的核心表述偏向“$focusA”，文本B的核心表述偏向“$focusB”。');
      differenceAxes.add('核心语义焦点差异：A=$focusA；B=$focusB。');
    } else if (_normalizeForMatch(a) != _normalizeForMatch(b)) {
      different.add('两段文本的具体行为、对象或状态并不相同。');
      differenceAxes.add('表述内容差异：双方没有形成同一行为、同一对象或同一状态。');
    }

    final primaryCatsA = catsA.where((e) => e != 'first_person' && e != 'time' && e != 'personal_event').toSet();
    final primaryCatsB = catsB.where((e) => e != 'first_person' && e != 'time' && e != 'personal_event').toSet();
    final primaryShared = primaryCatsA.intersection(primaryCatsB);
    if (primaryCatsA.isNotEmpty && primaryCatsB.isNotEmpty && primaryShared.isEmpty) {
      final la = primaryCatsA.map(_semanticContextLabel).take(3).join('、');
      final lb = primaryCatsB.map(_semanticContextLabel).take(3).join('、');
      different.add('双方主要语义领域不同：文本A偏向“$la”，文本B偏向“$lb”。');
      differenceAxes.add('语义领域差异：A=$la；B=$lb；没有共享的主要领域概念。');
    }

    if (primaryCatsA.isNotEmpty && primaryCatsB.isNotEmpty) {
      final pa = primaryCatsA.map(_categoryPurposeFunction).take(3).join('；');
      final pb = primaryCatsB.map(_categoryPurposeFunction).take(3).join('；');
      if (pa.isNotEmpty && pb.isNotEmpty && pa != pb) {
        different.add('目的/功能不同：文本A更偏向“$pa”，文本B更偏向“$pb”。');
        differenceAxes.add('目的/功能差异：A=$pa；B=$pb。');
      }
    }

    if (common.isNotEmpty) {
      unsupported.add('不能仅凭当前文本确定二者描述的是同一件事。');
      unsupported.add('不能仅凭当前文本确定二者之间存在因果关系。');
      unsupported.add('不能把潜在共同背景直接当成同义、等价或事实一致。');
    } else {
      different.add('未发现明确的共同主题、共同对象、共同事件链或概念—实例关系。');
      differenceAxes.add('共同概念缺失：没有找到可支撑高度相关的显性共同概念、上位概念或关系链。');
    }

    if (common.isEmpty && rawEmbeddingCosine != null && rawEmbeddingCosine >= 0.42) {
      common.add('原生 Embedding 显示二者在向量空间有中低程度接近，但文本表层没有给出明确同一关系；该项仅作为弱参考。');
      commonConcepts.add('向量空间弱共同语义场：由 Embedding 提示，但缺少文本证据支撑，不能作为强共同概念。');
      unsupported.add('不能仅凭 Embedding 接近就推断二者同义或高度相关。');
    }

    var relatedness = 0.0;
    if (common.isNotEmpty) {
      relatedness = 0.18 + min(0.18, common.length * 0.045);
      if (rawEmbeddingCosine != null && rawEmbeddingCosine > 0.35) {
        relatedness = max(relatedness, min(0.45, rawEmbeddingCosine * 0.70));
      }
      if (_hasCategoryPair(catsA, catsB, 'health_medical', 'rest_sleep')) {
        relatedness = max(relatedness, 0.36);
      }
      if (sharedTimes.isNotEmpty && _containsFirstPerson(a) && _containsFirstPerson(b)) {
        relatedness = max(relatedness, 0.28);
      }
      if (_hasCategoryPair(catsA, catsB, 'hygiene_cleaning', 'intimacy_sexuality')) {
        relatedness = max(relatedness, 0.38);
      }
    }

    final hasExplicitCommonality = sharedCats.isNotEmpty;
    final hasPreparationRelation = commonConcepts.any((e) => e.contains('前置准备') || e.contains('目的关系'));
    final hasAbstractCommonality = sharedAbstract.isNotEmpty ||
        commonConcepts.any((e) => e.contains('新上位共同概念') || e.contains('欲望满足') || e.contains('生活奖赏'));
    final hasOnlyShallowCommonality = common.isNotEmpty && !hasExplicitCommonality && !hasAbstractCommonality && !hasPreparationRelation;
    final relation = common.isEmpty
        ? 'unrelated'
        : (hasPreparationRelation
            ? 'possible_preparation_relation'
            : (hasAbstractCommonality && !hasExplicitCommonality ? 'weak_abstract_commonality' : 'weak_context_related'));
    final keyDifference = different.isEmpty
        ? '未发现可支持高度相关或同义等价的明确证据。'
        : different.first;
    final commonConceptAnalysis = commonConcepts.isEmpty
        ? '未识别到实质共同概念；若存在相同时间、第一人称等，也不足以构成强语义共同性。'
        : '共同性分层：${_dedupeStrings(commonConcepts).join('；')}；共同性强度说明：显性/直接共同性、上位抽象共同性和浅层共同性已分开处理。弱上位抽象共同性不能直接推高到“高度相关”。';
    final differenceAnalysis = differenceAxes.isEmpty
        ? '未形成明确差异轴，需依赖模型进一步判断。'
        : '差异性分轴：${_dedupeStrings(differenceAxes).join('；')}';
    final double directCommonalityScore = (hasExplicitCommonality
            ? min(1.0, 0.35 + sharedCats.length * 0.12)
            : (hasOnlyShallowCommonality ? 0.08 : (hasPreparationRelation ? 0.18 : 0.0)))
        .toDouble();
    final double abstractCommonalityScore = (hasAbstractCommonality
            ? min(0.60, 0.22 + sharedAbstract.length * 0.08)
            : (hasPreparationRelation ? 0.28 : 0.0))
        .toDouble();
    final double substantialCommonalityScore = (hasExplicitCommonality
            ? min(1.0, max(directCommonalityScore * 0.80, 0.30))
            : (hasPreparationRelation ? 0.26 : (hasAbstractCommonality ? min(0.24, abstractCommonalityScore * 0.55) : 0.0)))
        .toDouble();
    final double differenceScore = (differenceAxes.isEmpty ? 0.0 : min(1.0, 0.35 + differenceAxes.length * 0.16)).toDouble();

    return _CommonalityAssessment(
      relation: relation,
      relatednessScore: relatedness.clamp(0.0, 0.49).toDouble(),
      equivalenceScore: common.isEmpty ? 0.0 : 0.05,
      coverageScore: common.isEmpty ? 0.0 : 0.18,
      localBestScore: common.isEmpty ? 0.0 : relatedness.clamp(0.0, 0.49).toDouble(),
      confidence: common.isEmpty ? 0.58 : 0.66,
      commonAspects: _dedupeStrings(common),
      commonConcepts: _dedupeStrings(commonConcepts),
      commonConceptAnalysis: commonConceptAnalysis,
      directCommonalityScore: directCommonalityScore,
      abstractCommonalityScore: abstractCommonalityScore,
      differentAspects: _dedupeStrings(different),
      differenceAxes: _dedupeStrings(differenceAxes),
      differenceAnalysis: differenceAnalysis,
      substantialCommonalityScore: substantialCommonalityScore,
      differenceScore: differenceScore,
      unsupportedInferences: _dedupeStrings(unsupported),
      keyDifference: keyDifference,
      reason: common.isEmpty
          ? '未发现明确共同性；可判为无关或语境不足。'
          : (hasPreparationRelation
              ? '二者不能视为同义或确定因果，但存在可能的前置准备/目的关系；必须把“可能”与“确定”分开显示。'
              : '二者不能视为同义或高度相关，但存在弱共同语境；需要同时保留共同性与差异，避免简单判为绝对无关。'),
    );
  }

  Map<String, dynamic> _applyCommonalityAdjustments(
    Map<String, dynamic> parsed,
    _CommonalityAssessment local,
  ) {
    final out = Map<String, dynamic>.from(parsed);
    final relation = _string(out['relation'], fallback: 'ambiguous');
    final relatedness = _double(out['relatednessScore'], fallback: 0).clamp(0.0, 1.0).toDouble();
    final equivalence = _double(out['equivalenceScore'], fallback: 0).clamp(0.0, 1.0).toDouble();
    final coverage = _double(out['coverageScore'], fallback: 0).clamp(0.0, 1.0).toDouble();
    final confidence = _double(out['confidence'], fallback: 0.5).clamp(0.0, 1.0).toDouble();

    out['commonAspects'] = _mergeStringLists(out['commonAspects'], local.commonAspects);
    out['commonConcepts'] = _mergeStringLists(out['commonConcepts'], local.commonConcepts);
    if (_string(out['commonConceptAnalysis']).isEmpty) out['commonConceptAnalysis'] = local.commonConceptAnalysis;
    out['differentAspects'] = _mergeStringLists(out['differentAspects'], local.differentAspects);
    out['differenceAxes'] = _mergeStringLists(out['differenceAxes'], local.differenceAxes);
    if (_string(out['differenceAnalysis']).isEmpty) out['differenceAnalysis'] = local.differenceAnalysis;
    out['unsupportedInferences'] = _mergeStringLists(out['unsupportedInferences'], local.unsupportedInferences);
    out['directCommonalityScore'] = max(_double(out['directCommonalityScore'], fallback: 0), local.directCommonalityScore).clamp(0.0, 1.0).toDouble();
    out['abstractCommonalityScore'] = max(_double(out['abstractCommonalityScore'], fallback: 0), local.abstractCommonalityScore).clamp(0.0, 1.0).toDouble();
    out['substantialCommonalityScore'] = max(_double(out['substantialCommonalityScore'], fallback: 0), local.substantialCommonalityScore).clamp(0.0, 1.0).toDouble();
    if (_string(out['commonalityLevel']).isEmpty) {
      out['commonalityLevel'] = local.relation == 'weak_abstract_commonality'
          ? 'weak_abstract'
          : (local.relation == 'possible_preparation_relation' || local.relation == 'possible_purpose_relation'
              ? 'possible_functional'
              : (local.directCommonalityScore > 0.25 ? 'explicit' : (local.commonAspects.isNotEmpty ? 'shallow' : 'none')));
    }
    out['differenceScore'] = max(_double(out['differenceScore'], fallback: 0), local.differenceScore).clamp(0.0, 1.0).toDouble();

    final hasWeakCommonality = local.commonAspects.isNotEmpty && local.relatednessScore >= 0.18;
    final relationSaysHardUnrelated = relation == 'unrelated' || relation == 'ambiguous' || relatedness <= 0.01;
    final localSpecificPossibleRelation = local.relation == 'possible_preparation_relation' || local.relation == 'possible_purpose_relation';
    final relationIsWeakOrGeneric = const <String>{
      'weak_context_related',
      'shared_context_only',
      'ambiguous_related',
      'weak_abstract_commonality',
      'topic_related',
      'related_not_equivalent',
      'unrelated',
      'ambiguous',
    }.contains(relation);
    final shouldUpgradeToSpecificPossibleRelation = localSpecificPossibleRelation && relationIsWeakOrGeneric && equivalence <= 0.20 && relatedness < 0.60;

    if (hasWeakCommonality && (relationSaysHardUnrelated || shouldUpgradeToSpecificPossibleRelation)) {
      out['relation'] = (local.relation == 'weak_abstract_commonality' ||
              local.relation == 'possible_preparation_relation' ||
              local.relation == 'possible_purpose_relation')
          ? local.relation
          : 'weak_context_related';
      out['sameMeaning'] = false;
      out['is_semantically_consistent'] = false;
      out['highlyRelated'] = false;
      out['completelyUnrelated'] = false;
      out['relatednessScore'] = max(relatedness, local.relatednessScore).clamp(0.0, 0.49).toDouble();
      out['equivalenceScore'] = equivalence == 0 ? local.equivalenceScore : min(equivalence, 0.15);
      out['coverageScore'] = max(coverage, local.coverageScore).clamp(0.0, 0.35).toDouble();
      out['localBestScore'] = max(_double(out['localBestScore'], fallback: 0), local.localBestScore).clamp(0.0, 0.49).toDouble();
      out['confidence'] = max(confidence, local.confidence).clamp(0.0, 0.75).toDouble();
      out['matchScope'] = (local.relation == 'possible_preparation_relation' || local.relation == 'possible_purpose_relation')
          ? 'possible_purpose'
          : 'weak_context';
      out['direction'] = _string(out['direction'], fallback: 'none');
      out['error_type'] = _string(out['error_type'], fallback: 'ambiguous') == 'none' ? 'ambiguous' : _string(out['error_type'], fallback: 'ambiguous');
      if (_string(out['key_difference']).isEmpty) out['key_difference'] = local.keyDifference;
      final modelReason = _string(out['reason']);
      out['reason'] = modelReason.isEmpty ? local.reason : '$modelReason\n补充校正：${local.reason}';
      out['localCommonalityAdjusted'] = true;
    } else {
      out['completelyUnrelated'] = out.containsKey('completelyUnrelated')
          ? _bool(out['completelyUnrelated'])
          : (!hasWeakCommonality && relatedness < 0.15);
      out['localCommonalityAdjusted'] = false;
      if (_string(out['key_difference']).isEmpty && local.differentAspects.isNotEmpty) {
        out['key_difference'] = local.keyDifference;
      }
    }

    out['localCommonalityAssessment'] = local.toJson();
    return out;
  }

  Set<String> _semanticContextCategories(String text) {
    final t = _normalizeForMatch(text);
    final out = <String>{};
    if (_containsFirstPerson(text)) out.add('first_person');
    if (_timeExpressions(text).isNotEmpty) out.add('time');
    if (_containsAny(t, const ['医院', '就医', '看病', '医生', '护士', '检查', '取药', '吃药', '手术', '病', '不舒服', '发烧', '疼', '痛'])) {
      out.add('health_medical');
    }
    if (_containsAny(t, const ['睡', '睡觉', '床', '卧床', '躺', '休息', '困', '疲惫', '累', '一天没起', '睡了一天'])) {
      out.add('rest_sleep');
    }
    if (_containsAny(t, const ['疲惫', '累', '困', '休息', '睡'])) {
      out.add('fatigue_rest');
    }
    if (_containsAny(t, const ['学习', '复习', '读书', '背单词', '考试', '上课', '做题'])) out.add('study');
    if (_containsAny(t, const ['工作', '上班', '任务', '项目', '面试', '简历', '老板', '同事'])) out.add('work');
    if (_containsAny(t, const ['跑步', '健身', '锻炼', '运动', '训练', '减肥'])) out.add('exercise');
    if (_containsAny(t, const ['焦虑', '害怕', '恐惧', '生气', '愤怒', '难过', '低落', '开心', '情绪', '自卑', '羞耻'])) out.add('emotion');
    if (_containsAny(t, const ['成功', '失败', '赢', '输', '达成', '未达成', '结果'])) out.add('success_failure');
    if (_containsAny(t, const ['目标', '计划', '坚持', '行动', '执行', '开始', '落实'])) out.add('action_goal');
    if (_containsAny(t, const ['钱', '赚钱', '挣钱', '赚', '收入', '工资', '薪水', '财富', '存款', '资产', '30w', '30万', '三十万', '百万', '利润'])) out.add('finance_income');
    if (_containsAny(t, const ['性', '做爱', '性爱', '亲密', '干柴烈火', '欲望', '身体关系', '暧昧', '恋爱', '情人', '伴侣', '邻居'])) out.add('intimacy_sexuality');
    if (_containsAny(t, const ['洗澡', '洗干净', '清洗', '清洁', '全身清洗', '全身清洁', '干净', '卫生', '沐浴', '洗漱', '刷牙', '换衣服', '打扮', '化妆', '整理仪容'])) out.add('hygiene_cleaning');
    if (_containsAny(t, const ['满足', '享受', '快乐', '爽', '刺激', '欲望', '渴望', '获得', '奖赏', '成就感', '安全感', '亲密感'])) out.add('desire_satisfaction');
    if (_containsAny(t, const ['证明', '面子', '尊严', '地位', '成功', '成就', '价值', '认可'])) out.add('status_value');
    if (_containsAny(t, const ['买', '卖', '交换', '交易', '消费', '付出', '得到', '获得'])) out.add('exchange_acquisition');
    if (_looksLikePersonalEvent(text)) out.add('personal_event');
    return out;
  }

  String _semanticContextLabel(String category) {
    switch (category) {
      case 'health_medical':
        return '健康/就医';
      case 'rest_sleep':
      case 'fatigue_rest':
        return '休息/睡眠/精力状态';
      case 'study':
        return '学习';
      case 'work':
        return '工作/任务';
      case 'exercise':
        return '运动/身体训练';
      case 'emotion':
        return '情绪/心理状态';
      case 'success_failure':
        return '成败结果';
      case 'action_goal':
        return '目标/行动/执行';
      case 'finance_income':
        return '金钱/收入/资源获得';
      case 'intimacy_sexuality':
        return '亲密关系/性与身体欲望';
      case 'hygiene_cleaning':
        return '身体清洁/卫生整理';
      case 'desire_satisfaction':
        return '欲望/满足/奖赏';
      case 'status_value':
        return '成就/地位/价值确认';
      case 'exchange_acquisition':
        return '交换/获得结构';
      case 'personal_event':
        return '个人生活事件';
      default:
        return category;
    }
  }


  Set<String> _abstractCommonalityDimensions(Set<String> cats) {
    final out = <String>{};
    void addAll(Iterable<String> values) => out.addAll(values);
    for (final cat in cats) {
      switch (cat) {
        case 'finance_income':
          addAll(const ['need_satisfaction', 'resource_acquisition', 'security_need', 'achievement_reward', 'life_reward']);
          break;
        case 'intimacy_sexuality':
          addAll(const ['need_satisfaction', 'intimacy_need', 'pleasure_reward', 'connection_need', 'life_reward', 'body_state']);
          break;
        case 'hygiene_cleaning':
          addAll(const ['body_state', 'self_care', 'preparation_structure', 'health_pursuit']);
          break;
        case 'desire_satisfaction':
          addAll(const ['need_satisfaction', 'pleasure_reward', 'life_reward']);
          break;
        case 'status_value':
          addAll(const ['need_satisfaction', 'achievement_reward', 'social_value', 'self_worth']);
          break;
        case 'exchange_acquisition':
          addAll(const ['resource_acquisition', 'exchange_structure', 'need_satisfaction']);
          break;
        case 'health_medical':
          addAll(const ['body_state', 'security_need', 'problem_repair']);
          break;
        case 'rest_sleep':
        case 'fatigue_rest':
          addAll(const ['body_state', 'recovery_need', 'problem_repair']);
          break;
        case 'work':
          addAll(const ['resource_acquisition', 'achievement_reward', 'social_value']);
          break;
        case 'study':
          addAll(const ['growth_need', 'achievement_reward', 'self_improvement']);
          break;
        case 'exercise':
          addAll(const ['body_state', 'self_improvement', 'health_pursuit']);
          break;
        case 'emotion':
          addAll(const ['inner_state', 'need_satisfaction', 'psychological_motive']);
          break;
        case 'action_goal':
          addAll(const ['purpose_structure', 'self_regulation', 'achievement_reward']);
          break;
        case 'success_failure':
          addAll(const ['achievement_reward', 'evaluation_result']);
          break;
      }
    }
    return out;
  }

  String _abstractDimensionLabel(String dim) {
    switch (dim) {
      case 'need_satisfaction':
        return '需求/欲望满足';
      case 'resource_acquisition':
        return '资源获得';
      case 'security_need':
        return '安全感/生存保障';
      case 'achievement_reward':
        return '成就/奖赏追求';
      case 'life_reward':
        return '生活奖赏/获得感';
      case 'intimacy_need':
        return '亲密需求';
      case 'pleasure_reward':
        return '感官/愉悦奖赏';
      case 'connection_need':
        return '连接/关系需要';
      case 'social_value':
        return '社会价值/认可';
      case 'self_worth':
        return '自我价值确认';
      case 'exchange_structure':
        return '交换/获得结构';
      case 'body_state':
        return '身体状态';
      case 'problem_repair':
        return '问题修复/恢复';
      case 'recovery_need':
        return '恢复/休息需要';
      case 'growth_need':
        return '成长需要';
      case 'self_improvement':
        return '自我改善';
      case 'health_pursuit':
        return '健康追求';
      case 'inner_state':
        return '内在状态';
      case 'psychological_motive':
        return '心理动机';
      case 'purpose_structure':
        return '目的/行动结构';
      case 'self_regulation':
        return '自我调节';
      case 'self_care':
        return '自我照料/身体整理';
      case 'preparation_structure':
        return '准备/前置行为结构';
      case 'evaluation_result':
        return '评价结果维度';
      default:
        return dim;
    }
  }

  String _categoryPurposeFunction(String category) {
    switch (category) {
      case 'finance_income':
        return '获得金钱、资源、安全感或成就确认';
      case 'intimacy_sexuality':
        return '获得亲密、感官满足、连接感或身体/情感释放';
      case 'hygiene_cleaning':
        return '清洁身体、整理仪容、维持卫生或为后续私人/社交活动做准备';
      case 'health_medical':
        return '处理身体问题、寻求诊断、治疗或安全保障';
      case 'rest_sleep':
      case 'fatigue_rest':
        return '恢复精力、缓解疲惫或进行身体修复';
      case 'work':
        return '完成任务、获得收入、履行责任或取得职业成果';
      case 'study':
        return '获得知识、提升能力或达成学习成果';
      case 'exercise':
        return '改善身体状态、训练能力或追求健康';
      case 'emotion':
        return '表达或处理内在心理状态';
      case 'action_goal':
        return '组织行动、达成目标或进行自我调节';
      default:
        return _semanticContextLabel(category);
    }
  }

  bool _hasCategoryPair(Set<String> a, Set<String> b, String x, String y) {
    return (a.contains(x) && b.contains(y)) || (a.contains(y) && b.contains(x));
  }

  bool _containsFirstPerson(String text) {
    final t = _normalizeForMatch(text);
    return t.contains('我') || t.contains('自己') || t.contains('本人');
  }

  bool _looksLikePersonalEvent(String text) {
    final t = _normalizeForMatch(text);
    return _containsFirstPerson(t) && (t.contains('了') || t.contains('去') || t.contains('在') || t.contains('今天') || t.contains('昨天') || t.contains('明天'));
  }

  List<String> _timeExpressions(String text) {
    final t = _normalizeForMatch(text);
    const values = <String>['今天', '昨天', '明天', '上午', '下午', '晚上', '早上', '中午', '一天', '最近', '刚才', '现在'];
    return values.where((v) => t.contains(v)).toList();
  }

  List<String> _sharedTimeExpressions(String a, String b) {
    final ta = _timeExpressions(a).toSet();
    final tb = _timeExpressions(b).toSet();
    return ta.intersection(tb).toList();
  }

  String _roughSemanticFocus(String text) {
    final t = _normalizeForMatch(text);
    if (_containsAny(t, const ['医院', '就医', '看病', '医生', '检查', '取药'])) return '就医/医院行为';
    if (_containsAny(t, const ['床', '睡', '睡觉', '卧床', '躺', '休息'])) return '卧床/睡眠/休息状态';
    if (_containsAny(t, const ['学习', '复习', '读书', '考试', '做题'])) return '学习行为';
    if (_containsAny(t, const ['工作', '上班', '任务', '项目', '面试'])) return '工作/任务行为';
    if (_containsAny(t, const ['跑步', '健身', '锻炼', '运动'])) return '运动/训练行为';
    if (_containsAny(t, const ['钱', '赚钱', '挣钱', '赚', '收入', '工资', '财富', '30w', '30万', '三十万'])) return '金钱/收入获得';
    if (_containsAny(t, const ['做爱', '性爱', '性', '亲密', '干柴烈火', '邻居', '身体关系', '暧昧'])) return '亲密/性行为或身体欲望';
    if (_containsAny(t, const ['焦虑', '害怕', '生气', '难过', '情绪'])) return '情绪状态';
    if (_containsAny(t, const ['目标', '计划', '坚持', '执行', '行动'])) return '目标/行动表达';
    if (t.length <= 18) return text.trim();
    return _preview(text, 24);
  }

  List<String> _mergeStringLists(Object? first, List<String> second) {
    final out = <String>[];
    if (first is List) {
      for (final item in first) {
        final s = item.toString().trim();
        if (s.isNotEmpty) out.add(s);
      }
    } else if (first is String && first.trim().isNotEmpty) {
      out.add(first.trim());
    }
    out.addAll(second);
    return _dedupeStrings(out).take(8).toList();
  }

  List<String> _dedupeStrings(Iterable<String> values) {
    final seen = <String>{};
    final out = <String>[];
    for (final value in values) {
      final s = value.trim();
      if (s.isEmpty) continue;
      final key = _normalizeForMatch(s);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(s);
    }
    return out;
  }


  String _renderPromptTemplate(String template, Map<String, String> values) {
    var out = template;
    for (final entry in values.entries) {
      out = out.replaceAll('{{${entry.key}}}', entry.value);
    }
    return out;
  }

  Future<SemanticConsistencyResult> _judgeWithLlm({
    required SemanticConsistencySettings settings,
    required SemanticPrecisionMode mode,
    required String textA,
    required String textB,
    double? cosineScore,
    String? extraInstruction,
    String? titleEvidence,
    String? promptTextA,
    String? promptTextB,
    String extraJson = '',
  }) async {
    final systemPrompt = settings.resolvedJudgeSystemPrompt();

    final textAForPrompt = promptTextA ?? textA;
    final textBForPrompt = promptTextB ?? textB;

    final prompt = _renderPromptTemplate(
      settings.resolvedJudgeUserPromptTemplate(),
      {
        'modeLabel': mode.label,
        'modeId': mode.id,
        'embeddingCosine': cosineScore == null ? '未计算' : cosineScore.toStringAsFixed(4),
        'extraInstruction': (extraInstruction ?? '').trim(),
        'titleEvidenceBlock': titleEvidence == null ? '' : '文章相关证据段落：\n$titleEvidence',
        'textA': textAForPrompt,
        'textB': textBForPrompt,
        'jsonSchema': SemanticConsistencyPromptDefaults.jsonSchema,
      },
    );
    String raw = '';
    try {
      raw = await _aiService.generateText(
        prompt: prompt,
        purpose: 'semantic_consistency.judge',
        systemPrompt: systemPrompt,
        maxTokens: 2800,
        expectJson: true,
        temperature: 0,
      );
    } catch (e, st) {
      await DeepSeekLogger.logError(
        provider: 'Semantic Consistency',
        module: 'semantic_consistency.judge',
        endpoint: 'unified_ai.generateText',
        error: e,
        stackTrace: st,
        model: mode.id,
      );
      return _record(_simpleResult(
        settings: settings,
        mode: mode,
        textA: textA,
        textB: textB,
        cosineScore: cosineScore,
        relation: 'ambiguous',
        isConsistent: false,
        confidence: 0,
        errorType: 'judge_exception',
        keyDifference: '',
        reason: '语言模型裁判调用失败：$e',
        rawRequest: prompt,
        rawResponse: '$e\n$st',
        extraJson: extraJson,
      ));
    }

    final parsed = _parseJsonObject(raw);
    final localCommonality = _buildLocalCommonalityAssessment(textA, textB, cosineScore);
    final adjustedParsed = _applyCommonalityAdjustments(parsed, localCommonality);
    final relation = _string(adjustedParsed['relation'], fallback: 'ambiguous');
    final consistent = adjustedParsed.containsKey('sameMeaning')
        ? _bool(adjustedParsed['sameMeaning'])
        : _bool(adjustedParsed['is_semantically_consistent']);
    final confidence = _double(adjustedParsed['confidence'], fallback: raw.trim().isEmpty ? 0 : 0.5).clamp(0.0, 1.0).toDouble();
    final enrichedExtraJson = _mergeJudgeExtraJson(
      baseExtraJson: extraJson,
      parsed: adjustedParsed,
      mode: mode,
      rawEmbeddingCosine: cosineScore,
    );
    final cfg = await _aiService.resolveGlobalConfig();
    final result = SemanticConsistencyResult(
      mode: mode.id,
      textA: textA,
      textB: textB,
      cosineScore: cosineScore,
      relation: relation,
      isConsistent: consistent,
      confidence: confidence,
      errorType: _string(adjustedParsed['error_type'], fallback: raw.trim().isEmpty ? 'empty_judge_response' : 'none'),
      keyDifference: _string(adjustedParsed['key_difference']),
      reason: _cleanDisplayText(_string(adjustedParsed['reason'], fallback: raw.trim().isEmpty ? '模型返回为空。' : '模型返回可读但 JSON 字段不完整，已保留原始响应。'), maxChars: 140),
      provider: cfg.provider,
      model: cfg.model,
      embeddingProvider: settings.embeddingProvider,
      embeddingModel: settings.embeddingModel,
      judgeProvider: cfg.provider,
      judgeModel: cfg.model,
      rawRequest: prompt,
      rawResponse: raw,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      extraJson: enrichedExtraJson,
    );
    return _record(result);
  }


  String _cleanDisplayText(Object? value, {int maxChars = 120}) {
    String raw;
    if (value == null) return '';
    if (value is List) {
      raw = value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).join('；');
    } else {
      raw = value.toString();
    }
    var text = raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('；；', '；')
        .replaceAll('。。', '。')
        .trim();
    if (text.isEmpty) return '';
    // 优先保留第一句或前两个短分句，避免把模型长篇推理直接展示在主界面。
    final end = text.indexOf(RegExp(r'[。！？\n]'));
    if (end > 0 && end + 1 <= maxChars) {
      final first = text.substring(0, end + 1).trim();
      if (first.length >= 10 || text.length > maxChars) return first;
    }
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}…';
  }

  List<String> _cleanDisplayList(Object? value, {int maxItems = 3, int maxChars = 48}) {
    final raw = <String>[];
    if (value is List) {
      raw.addAll(value.map((e) => e.toString()));
    } else if (value is String && value.trim().isNotEmpty) {
      raw.addAll(value.split(RegExp(r'[；;\n]')));
    }
    final seen = <String>{};
    final out = <String>[];
    for (final item in raw) {
      final cleaned = _cleanDisplayText(item, maxChars: maxChars).trim();
      if (cleaned.isEmpty) continue;
      final key = _normalizeForMatch(cleaned);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(cleaned);
      if (out.length >= maxItems) break;
    }
    return out;
  }

  String _firstReadable(Map<String, dynamic> parsed, List<String> keys, {int maxChars = 100}) {
    for (final key in keys) {
      final text = _cleanDisplayText(parsed[key], maxChars: maxChars);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _buildDisplayConclusion(Map<String, dynamic> parsed) {
    final explicit = _firstReadable(parsed, const [
      'oneSentenceConclusion',
      'finalVerdict',
      'summary',
      'conclusion',
    ], maxChars: 72);
    if (explicit.isNotEmpty) return explicit;

    final relation = _string(parsed['relation'], fallback: 'ambiguous');
    final same = parsed.containsKey('sameMeaning') ? _bool(parsed['sameMeaning']) : _bool(parsed['is_semantically_consistent']);
    final highly = _bool(parsed['highlyRelated']);
    final completely = parsed.containsKey('completelyUnrelated') ? _bool(parsed['completelyUnrelated']) : false;
    if (same || relation == 'equivalent' || relation == 'near_equivalent') {
      return '两者可视为同一或近似同一含义。';
    }
    if (relation == 'weak_abstract_commonality') {
      return '两者表层差异很大，但存在较弱的上位抽象共同性。';
    }
    if (relation == 'possible_preparation_relation' || relation == 'possible_purpose_relation') {
      return '两者不是同义，但可能存在前置准备或目的关系；证据不足以确定。';
    }
    if (relation == 'weak_context_related' || relation == 'shared_context_only' || relation == 'ambiguous_related') {
      return '两者不是同义或高度相关，但存在弱共同语境。';
    }
    if (highly) {
      return '两者高度相关，但不一定能互换为同一含义。';
    }
    if (completely || relation == 'unrelated') {
      return '两者未发现足够语义关系，核心含义差异明显。';
    }
    return _cleanDisplayText(parsed['reason'], maxChars: 72);
  }

  String _buildDisplayCommonality(Map<String, dynamic> parsed) {
    // v26：共同性摘要优先使用“本质共同性”，避免只显示“同一语义场/用词相近”这类浅层结论。
    final essential = _firstReadable(parsed, const [
      'essentialCommonality',
      'semanticCore',
      'coreCommonality',
      'commonalitySummary',
      'commonSummary',
      'commonalityConclusion',
    ], maxChars: 110);
    if (essential.isNotEmpty) return essential;
    final aspects = _cleanDisplayList(parsed['commonAspects'], maxItems: 2, maxChars: 46);
    if (aspects.isNotEmpty) return aspects.join('；');
    final concepts = _cleanDisplayList(parsed['commonConcepts'], maxItems: 2, maxChars: 46);
    if (concepts.isNotEmpty) return concepts.join('；');
    return _cleanDisplayText(parsed['commonConceptAnalysis'], maxChars: 100);
  }

  String _buildDisplayDifference(Map<String, dynamic> parsed) {
    // v26：差异摘要优先使用“本质差异”。近义词/成语比较时，最重要的是语义焦点、隐含画面、搭配和互换边界。
    final essential = _firstReadable(parsed, const [
      'essentialDifference',
      'semanticFocusDifference',
      'usageBoundary',
      'differenceSummary',
      'differenceConclusion',
    ], maxChars: 130);
    if (essential.isNotEmpty) return essential;
    final focusA = _cleanDisplayText(parsed['aSemanticFocus'], maxChars: 54);
    final focusB = _cleanDisplayText(parsed['bSemanticFocus'], maxChars: 54);
    if (focusA.isNotEmpty && focusB.isNotEmpty) {
      return 'A偏“$focusA”；B偏“$focusB”。';
    }
    final axes = _cleanDisplayList(parsed['differenceAxes'], maxItems: 2, maxChars: 54);
    if (axes.isNotEmpty) return axes.join('；');
    final aspects = _cleanDisplayList(parsed['differentAspects'], maxItems: 2, maxChars: 46);
    if (aspects.isNotEmpty) return aspects.join('；');
    final key = _cleanDisplayText(parsed['key_difference'], maxChars: 100);
    if (key.isNotEmpty) return key;
    return _cleanDisplayText(parsed['differenceAnalysis'], maxChars: 100);
  }


  String _mergeJudgeExtraJson({
    required String baseExtraJson,
    required Map<String, dynamic> parsed,
    required SemanticPrecisionMode mode,
    required double? rawEmbeddingCosine,
  }) {
    final extra = <String, Object?>{};
    try {
      final decoded = jsonDecode(baseExtraJson);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          extra[entry.key.toString()] = entry.value;
        }
      }
    } catch (_) {}

    double? numberField(String key) {
      final value = parsed[key];
      if (value is num) return value.toDouble().clamp(0.0, 1.0).toDouble();
      final parsedNumber = double.tryParse((value ?? '').toString());
      if (parsedNumber == null) return null;
      return parsedNumber.clamp(0.0, 1.0).toDouble();
    }

    extra.addAll(<String, Object?>{
      'judge_version': 'semantic_relation_multi_granularity_v26_essential_commonality_difference',
      'raw_native_cosine': rawEmbeddingCosine ?? extra['raw_native_cosine'],
      'raw_embedding_note': '原生 Embedding 余弦只表示向量空间/语义场接近度，不代表同义、等价或最终判断。',
      'one_sentence_conclusion': _buildDisplayConclusion(parsed),
      'commonality_summary': _buildDisplayCommonality(parsed),
      'difference_summary': _buildDisplayDifference(parsed),
      'essential_commonality': _cleanDisplayText(parsed['essentialCommonality'], maxChars: 140),
      'essential_difference': _cleanDisplayText(parsed['essentialDifference'], maxChars: 160),
      'a_semantic_focus': _cleanDisplayText(parsed['aSemanticFocus'], maxChars: 100),
      'b_semantic_focus': _cleanDisplayText(parsed['bSemanticFocus'], maxChars: 100),
      'interchangeable_context': _cleanDisplayText(parsed['interchangeableContext'], maxChars: 140),
      'non_interchangeable_context': _cleanDisplayText(parsed['nonInterchangeableContext'], maxChars: 160),
      'display_common_aspects': _cleanDisplayList(parsed['commonAspects'], maxItems: 3, maxChars: 42),
      'display_common_concepts': _cleanDisplayList(parsed['commonConcepts'], maxItems: 3, maxChars: 46),
      'display_difference_axes': _cleanDisplayList(parsed['differenceAxes'], maxItems: 3, maxChars: 52),
      'display_unsupported_inferences': _cleanDisplayList(parsed['unsupportedInferences'], maxItems: 3, maxChars: 46),
      'full_analysis_preserved': true,
      'display_policy': '主界面只显示一句话结论、共同性摘要、差异摘要、最多3条列表；完整模型响应和完整诊断放入展开区。',
      'relation_type': _string(parsed['relation'], fallback: 'ambiguous'),
      'same_meaning': parsed.containsKey('sameMeaning') ? _bool(parsed['sameMeaning']) : _bool(parsed['is_semantically_consistent']),
      'highly_related': _bool(parsed['highlyRelated']),
      'completely_unrelated': parsed.containsKey('completelyUnrelated') ? _bool(parsed['completelyUnrelated']) : null,
      'relatedness_score': numberField('relatednessScore'),
      'equivalence_score': numberField('equivalenceScore'),
      'coverage_score': numberField('coverageScore'),
      'local_best_score': numberField('localBestScore'),
      'match_scope': _string(parsed['matchScope']),
      'direction': _string(parsed['direction']),
      'a_role': _string(parsed['aRole']),
      'b_role': _string(parsed['bRole']),
      'top_evidence': parsed['topEvidence'],
      'common_aspects': parsed['commonAspects'],
      'common_concepts': parsed['commonConcepts'],
      'common_concept_analysis': parsed['commonConceptAnalysis'],
      'direct_commonality_score': numberField('directCommonalityScore'),
      'abstract_commonality_score': numberField('abstractCommonalityScore'),
      'substantial_commonality_score': numberField('substantialCommonalityScore'),
      'commonality_level': _string(parsed['commonalityLevel']),
      'different_aspects': parsed['differentAspects'],
      'difference_axes': parsed['differenceAxes'],
      'difference_analysis': parsed['differenceAnalysis'],
      'difference_score': numberField('differenceScore'),
      'unsupported_inferences': parsed['unsupportedInferences'],
      'local_commonality_adjusted': parsed['localCommonalityAdjusted'],
      'local_commonality_assessment': parsed['localCommonalityAssessment'],
      'mode_role': mode.id,
      'score_interpretation': 'relatednessScore=语义相关度；equivalenceScore=同义/等价度；coverageScore=覆盖度；localBestScore=局部最高证据分。',
      'prompt_customization_enabled': true,
      'prompt_template_source': 'SemanticConsistencySettings.judgeSystemPrompt / judgeUserPromptTemplate / judgeModeInstructions',
    });
    return jsonEncode(extra);
  }

  Future<List<_ScoredText>> _rerank({
    required String query,
    required List<String> docs,
    required SemanticConsistencySettings settings,
  }) async {
    final provider = settings.rerankerProvider.trim().toLowerCase();
    if (provider != 'cohere') return <_ScoredText>[];
    final headers = <String, String>{
      'Authorization': 'Bearer ${settings.rerankerApiKey.trim()}',
      'Content-Type': 'application/json',
    };
    final body = <String, Object?>{
      'model': settings.rerankerModel,
      'query': query,
      'documents': docs,
      'top_n': min(12, docs.length),
    };
    await DeepSeekLogger.logRequest(
      provider: 'Cohere Reranker',
      module: 'semantic_consistency.rerank',
      endpoint: settings.rerankerEndpoint,
      headers: headers,
      body: <String, Object?>{
        'model': settings.rerankerModel,
        'query_preview': _preview(query),
        'documents_count': docs.length,
        'documents_preview': docs.take(5).map((e) => _preview(e, 120)).toList(),
      },
      model: settings.rerankerModel,
    );
    try {
      final requestCfg = await _requestSettings.getConfig();
      final resp = await http
          .post(Uri.parse(settings.rerankerEndpoint), headers: headers, body: jsonEncode(body))
          .timeout(requestCfg.resolveTimeout(const Duration(seconds: 45)));
      await DeepSeekLogger.logResponse(
        provider: 'Cohere Reranker',
        module: 'semantic_consistency.rerank',
        endpoint: settings.rerankerEndpoint,
        statusCode: resp.statusCode,
        body: resp.body,
        model: settings.rerankerModel,
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) return <_ScoredText>[];
      final decoded = jsonDecode(resp.body);
      final results = decoded is Map ? decoded['results'] : null;
      if (results is! List) return <_ScoredText>[];
      final out = <_ScoredText>[];
      for (final item in results) {
        if (item is! Map) continue;
        final index = (item['index'] is num) ? (item['index'] as num).toInt() : null;
        if (index == null || index < 0 || index >= docs.length) continue;
        final score = (item['relevance_score'] is num) ? (item['relevance_score'] as num).toDouble() : 0.0;
        out.add(_ScoredText(text: docs[index], score: score));
      }
      return out;
    } catch (e, st) {
      await DeepSeekLogger.logError(
        provider: 'Cohere Reranker',
        module: 'semantic_consistency.rerank',
        endpoint: settings.rerankerEndpoint,
        error: e,
        stackTrace: st,
        model: settings.rerankerModel,
      );
      return <_ScoredText>[];
    }
  }

  SemanticConsistencyResult _simpleResult({
    required SemanticConsistencySettings settings,
    required SemanticPrecisionMode mode,
    required String textA,
    required String textB,
    double? cosineScore,
    required String relation,
    required bool isConsistent,
    required double confidence,
    required String errorType,
    required String keyDifference,
    required String reason,
    String rawRequest = '',
    String rawResponse = '',
    String extraJson = '',
  }) {
    return SemanticConsistencyResult(
      mode: mode.id,
      textA: textA,
      textB: textB,
      cosineScore: cosineScore,
      relation: relation,
      isConsistent: isConsistent,
      confidence: confidence,
      errorType: errorType,
      keyDifference: keyDifference,
      reason: reason,
      provider: 'local',
      model: mode.id,
      embeddingProvider: settings.embeddingProvider,
      embeddingModel: settings.embeddingModel,
      judgeProvider: '',
      judgeModel: '',
      rawRequest: rawRequest,
      rawResponse: rawResponse,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      extraJson: extraJson,
    );
  }

  Future<SemanticConsistencyResult> _record(SemanticConsistencyResult result) async {
    try {
      final id = await _dao.insertResult(result);
      return SemanticConsistencyResult(
        id: id,
        mode: result.mode,
        textA: result.textA,
        textB: result.textB,
        cosineScore: result.cosineScore,
        relation: result.relation,
        isConsistent: result.isConsistent,
        confidence: result.confidence,
        errorType: result.errorType,
        keyDifference: result.keyDifference,
        reason: result.reason,
        provider: result.provider,
        model: result.model,
        embeddingProvider: result.embeddingProvider,
        embeddingModel: result.embeddingModel,
        judgeProvider: result.judgeProvider,
        judgeModel: result.judgeModel,
        rawRequest: result.rawRequest,
        rawResponse: result.rawResponse,
        createdAt: result.createdAt,
        extraJson: result.extraJson,
      );
    } catch (_) {
      return result;
    }
  }

  List<String> _splitArticle(String text, {required int chunkSize, required int overlap}) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return <String>[];
    final chunks = <String>[];
    var start = 0;
    while (start < cleaned.length) {
      final end = min(start + chunkSize, cleaned.length);
      chunks.add(cleaned.substring(start, end));
      if (end >= cleaned.length) break;
      start = max(0, end - overlap);
    }
    return chunks;
  }

  List<String> _splitCandidates(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return <String>[];
    final byDivider = raw.split(RegExp(r'\n\s*---+\s*\n'));
    final source = byDivider.length > 1 ? byDivider : raw.split(RegExp(r'\n\s*\n+'));
    return source.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Map<String, dynamic> _parseJsonObject(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return <String, dynamic>{};
    final cleaned = text
        .replaceFirst(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceFirst(RegExp(r'^```\s*', multiLine: true), '')
        .replaceFirst(RegExp(r'\s*```\s*$', multiLine: true), '')
        .trim();
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {}
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final decoded = jsonDecode(cleaned.substring(start, end + 1));
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return decoded.map((key, value) => MapEntry(key.toString(), value));
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  dynamic _safeJson(String raw) {
    final parsed = _parseJsonObject(raw);
    return parsed.isEmpty ? raw : parsed;
  }

  static String _string(Object? value, {String fallback = ''}) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static bool _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = (value ?? '').toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes' || text == '是';
  }

  static double _double(Object? value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? fallback;
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty) {
      throw StateError('Embedding 向量为空，不能计算相似度。');
    }
    if (a.length != b.length) {
      throw StateError('Embedding 向量维度不一致：${a.length} vs ${b.length}');
    }
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      dot += x * y;
      normA += x * x;
      normB += y * y;
    }
    if (normA == 0 || normB == 0) {
      throw StateError('Embedding 向量范数为 0，不能计算相似度。');
    }
    return dot / (sqrt(normA) * sqrt(normB));
  }

  static double _scoreConfidence(double score, SemanticConsistencySettings settings) {
    if (score >= settings.strictThreshold) return 0.90;
    if (score >= settings.highThreshold) return 0.78;
    if (score >= settings.lowThreshold) return 0.58;
    return 0.86;
  }

  static String _stableHash(String text) => sha256.convert(utf8.encode(text)).toString();

  static String _preview(String value, [int maxLength = 180]) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxLength) return compact;
    return '${compact.substring(0, maxLength)}…';
  }
}


class _CommonalityAssessment {
  final String relation;
  final double relatednessScore;
  final double equivalenceScore;
  final double coverageScore;
  final double localBestScore;
  final double confidence;
  final List<String> commonAspects;
  final List<String> commonConcepts;
  final String commonConceptAnalysis;
  final double directCommonalityScore;
  final double abstractCommonalityScore;
  final List<String> differentAspects;
  final List<String> differenceAxes;
  final String differenceAnalysis;
  final double substantialCommonalityScore;
  final double differenceScore;
  final List<String> unsupportedInferences;
  final String keyDifference;
  final String reason;

  const _CommonalityAssessment({
    required this.relation,
    required this.relatednessScore,
    required this.equivalenceScore,
    required this.coverageScore,
    required this.localBestScore,
    required this.confidence,
    required this.commonAspects,
    required this.commonConcepts,
    required this.commonConceptAnalysis,
    required this.directCommonalityScore,
    required this.abstractCommonalityScore,
    required this.differentAspects,
    required this.differenceAxes,
    required this.differenceAnalysis,
    required this.substantialCommonalityScore,
    required this.differenceScore,
    required this.unsupportedInferences,
    required this.keyDifference,
    required this.reason,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'relation': relation,
        'relatedness_score': relatednessScore,
        'equivalence_score': equivalenceScore,
        'coverage_score': coverageScore,
        'local_best_score': localBestScore,
        'confidence': confidence,
        'common_aspects': commonAspects,
        'common_concepts': commonConcepts,
        'common_concept_analysis': commonConceptAnalysis,
        'direct_commonality_score': directCommonalityScore,
        'abstract_commonality_score': abstractCommonalityScore,
        'substantial_commonality_score': substantialCommonalityScore,
        'different_aspects': differentAspects,
        'difference_axes': differenceAxes,
        'difference_analysis': differenceAnalysis,
        'difference_score': differenceScore,
        'unsupported_inferences': unsupportedInferences,
        'key_difference': keyDifference,
        'reason': reason,
      };
}

class _JudgeEmbeddingMeta {
  const _JudgeEmbeddingMeta({
    required this.cosineScore,
    required this.extraJson,
    required this.instruction,
  });

  final double? cosineScore;
  final String extraJson;
  final String instruction;
}

class _ScoredText {
  final String text;
  final double score;

  const _ScoredText({required this.text, required this.score});
}

class _EmbeddingScoreThresholds {
  final double low;
  final double high;

  const _EmbeddingScoreThresholds({required this.low, required this.high});
}


class _EmbeddingVectorPayload {
  final List<double> vector;
  final bool cacheHit;
  final String cacheHash;
  final String extractionPath;
  final Object? usage;
  final Object? responseProvider;

  const _EmbeddingVectorPayload({
    required this.vector,
    required this.cacheHit,
    required this.cacheHash,
    required this.extractionPath,
    required this.usage,
    required this.responseProvider,
  });
}

class _EmbeddingCallResult {
  final List<double> vector;
  final String extractionPath;
  final Object? usage;
  final Object? responseProvider;

  const _EmbeddingCallResult({
    required this.vector,
    required this.extractionPath,
    required this.usage,
    required this.responseProvider,
  });
}

class _EmbeddingExtraction {
  final List<double> vector;
  final String path;

  const _EmbeddingExtraction({required this.vector, required this.path});
}

class _SemanticRecallCandidate {
  final String text;
  final String channel;

  const _SemanticRecallCandidate({required this.text, required this.channel});
}

class _RecallEmbeddingHit {
  final double score;
  final String textA;
  final String textB;
  final String channelA;
  final String channelB;

  const _RecallEmbeddingHit({
    required this.score,
    required this.textA,
    required this.textB,
    required this.channelA,
    required this.channelB,
  });

  String get routeLabel => '$channelA ↔ $channelB';

  Map<String, Object?> toJson() => <String, Object?>{
        'score': score,
        'channel_a': channelA,
        'channel_b': channelB,
        'text_a_preview': textA.length > 240 ? '${textA.substring(0, 240)}…' : textA,
        'text_b_preview': textB.length > 240 ? '${textB.substring(0, 240)}…' : textB,
      };
}

class _LocalRecallAnalysis {
  final double score;
  final List<String> hits;
  final List<String> conceptHits;
  final String warningCode;
  final String keyDifference;
  final double? scoreCap;

  const _LocalRecallAnalysis({
    required this.score,
    required this.hits,
    required this.conceptHits,
    required this.warningCode,
    required this.keyDifference,
    this.scoreCap,
  });
}

class _SurfaceStats {
  final double editSimilarity;
  final double bigramDice;
  final double trigramDice;
  final double charSetJaccard;
  final bool suspiciousShortReorder;
  final bool sameNormalized;

  const _SurfaceStats({
    required this.editSimilarity,
    required this.bigramDice,
    required this.trigramDice,
    required this.charSetJaccard,
    required this.suspiciousShortReorder,
    required this.sameNormalized,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'edit_similarity': editSimilarity,
        'bigram_dice': bigramDice,
        'trigram_dice': trigramDice,
        'char_set_jaccard': charSetJaccard,
        'suspicious_short_reorder': suspiciousShortReorder,
        'same_normalized': sameNormalized,
      };
}

class _ConceptPrototype {
  final String name;
  final String definition;
  final List<String> aliases;
  final List<String> typicalExpressions;
  final List<String> keywords;

  const _ConceptPrototype({
    required this.name,
    required this.definition,
    required this.aliases,
    required this.typicalExpressions,
    required this.keywords,
  });
}

class _EmbeddingSimilarityAnalysis {
  final double rawScore;
  final double semanticScore;
  final double lexicalScore;
  final double? localPriorScore;
  final double finalScore;
  final String warningCode;
  final String keyDifference;
  final String explanation;
  final String semanticInputA;
  final String semanticInputB;
  final bool suspiciousSurfaceMatch;
  final String bestEmbeddingRoute;
  final String bestEmbeddingTextA;
  final String bestEmbeddingTextB;
  final int recallCandidateCountA;
  final int recallCandidateCountB;
  final List<String> localRuleHits;
  final List<String> conceptHits;
  final Map<String, Object?> routeScores;
  final Map<String, Object?> surfaceStats;

  const _EmbeddingSimilarityAnalysis({
    required this.rawScore,
    required this.semanticScore,
    required this.lexicalScore,
    required this.localPriorScore,
    required this.finalScore,
    required this.warningCode,
    required this.keyDifference,
    required this.explanation,
    required this.semanticInputA,
    required this.semanticInputB,
    required this.suspiciousSurfaceMatch,
    required this.bestEmbeddingRoute,
    required this.bestEmbeddingTextA,
    required this.bestEmbeddingTextB,
    required this.recallCandidateCountA,
    required this.recallCandidateCountB,
    required this.localRuleHits,
    required this.conceptHits,
    required this.routeScores,
    required this.surfaceStats,
  });

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'raw_vector_cosine': rawScore,
      'semantic_prompt_vector_cosine': semanticScore,
      'best_recall_embedding_score': semanticScore,
      'best_recall_embedding_route': bestEmbeddingRoute,
      'best_recall_embedding_text_a_preview': bestEmbeddingTextA.length > 240 ? '${bestEmbeddingTextA.substring(0, 240)}…' : bestEmbeddingTextA,
      'best_recall_embedding_text_b_preview': bestEmbeddingTextB.length > 240 ? '${bestEmbeddingTextB.substring(0, 240)}…' : bestEmbeddingTextB,
      'lexical_surface_similarity': lexicalScore,
      'local_concept_prior': localPriorScore,
      'final_embedding_semantic_score': finalScore,
      'final_multi_route_score': finalScore,
      'warning_code': warningCode,
      'key_difference': keyDifference,
      'suspicious_surface_match': suspiciousSurfaceMatch,
      'semantic_input_a_preview': semanticInputA.length > 240 ? '${semanticInputA.substring(0, 240)}…' : semanticInputA,
      'semantic_input_b_preview': semanticInputB.length > 240 ? '${semanticInputB.substring(0, 240)}…' : semanticInputB,
      'recall_candidate_count_a': recallCandidateCountA,
      'recall_candidate_count_b': recallCandidateCountB,
      'local_rule_hits': localRuleHits,
      'concept_hits': conceptHits,
      'route_scores': routeScores,
      'surface_stats': surfaceStats,
    };
  }
}

