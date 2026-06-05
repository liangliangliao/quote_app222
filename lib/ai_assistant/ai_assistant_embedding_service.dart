import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../services/unified_ai_service.dart';
import '../utils/deepseek_logger.dart';
import 'ai_assistant_dao.dart';
import 'ai_assistant_models.dart';

class AiAssistantEmbeddingService {
  AiAssistantEmbeddingService({AiAssistantDao? dao, UnifiedAiService? aiService})
      : _dao = dao ?? AiAssistantDao(),
        _aiService = aiService ?? UnifiedAiService();

  // Eden AI routes this to OpenAI's latest high-quality embedding model.
  // OpenAI documents text-embedding-3-large as its most capable embedding model
  // for English and non-English tasks. It defaults to 3072 dimensions.
  static const String embeddingModel = 'openai/text-embedding-3-large';
  static const int embeddingDimensions = 3072;
  static const String _endpoint = 'https://api.edenai.run/v3/embeddings';

  // Increment this when chunking/querying behavior changes so older cached
  // chunks are ignored instead of mixed with the new retrieval index.
  static const String chunkVersion = 'semantic_fused_context_v7_compact_weighted_dedupe';

  static const int defaultTopK = 3;
  static const int maxBatchSize = 8;

  // The embedding index is built from large, continuous conversation windows,
  // not isolated single messages or tiny snippets. The size is kept below the
  // embedding input budget while preserving as much chat flow as possible.
  static const int maxChunkChars = 2600;
  static const int windowOverlapMessages = 2;

  // Do not use a fixed high threshold such as 0.62. Embedding score ranges vary
  // across corpora and languages. The selector below uses an adaptive threshold:
  // absolute floor + score distribution/outlier test + top score window.
  static const double minAcceptSimilarity = 0.18;
  static const double strongSimilarity = 0.30;
  static const double outlierGap = 0.018;
  static const double maxScoreMargin = 0.10;

  final AiAssistantDao _dao;
  final UnifiedAiService _aiService;

  Future<List<AiAssistantContextChunk>> retrieveRelevantChunks({
    required int conversationId,
    required int currentMessageId,
    int? beforeMessageId,
    required String query,
    int topK = defaultTopK,
  }) async {
    final cfg = await _aiService.resolveGlobalConfig(
      forcedProvider: 'edenai',
      forcedModel: embeddingModel,
    );
    if (!cfg.available) {
      final error = StateError('Eden AI Embedding 语义检索需要先在设置页配置 Eden AI API Key。');
      await DeepSeekLogger.logError(
        provider: 'Eden AI',
        module: 'ai_assistant.embedding',
        endpoint: _endpoint,
        error: error,
        model: embeddingModel,
      );
      throw error;
    }

    final queryEmbedding = await createEmbedding(
      apiKey: cfg.apiKey,
      text: query.trim(),
      model: embeddingModel,
    );

    await _ensureContextChunks(conversationId: conversationId, beforeMessageId: currentMessageId);
    final retrievalBeforeMessageId = beforeMessageId ?? currentMessageId;
    var chunks = await _dao.listContextChunks(
      conversationId: conversationId,
      beforeMessageId: retrievalBeforeMessageId,
      chunkVersion: chunkVersion,
    );
    if (chunks.isEmpty) return <AiAssistantContextChunk>[];

    final missing = chunks.where((c) => !c.hasEmbeddingFor(embeddingModel)).toList();
    for (var i = 0; i < missing.length; i += maxBatchSize) {
      final batch = missing.skip(i).take(maxBatchSize).toList();
      try {
        final embeddings = await createEmbeddings(
          apiKey: cfg.apiKey,
          texts: batch.map((c) => _documentEmbeddingText(c.chunkText)).toList(),
          model: embeddingModel,
        );
        for (var j = 0; j < batch.length && j < embeddings.length; j++) {
          await _dao.updateContextChunkEmbedding(
            chunkId: batch[j].id,
            embedding: embeddings[j],
            embeddingModel: embeddingModel,
          );
        }
      } catch (e, st) {
        await DeepSeekLogger.logError(
          provider: 'Eden AI',
          module: 'ai_assistant.embedding.batch_history',
          endpoint: _endpoint,
          error: e,
          stackTrace: st,
          model: embeddingModel,
        );
      }
    }

    chunks = await _dao.listContextChunks(
      conversationId: conversationId,
      beforeMessageId: retrievalBeforeMessageId,
      chunkVersion: chunkVersion,
    );

    final scored = <_ScoredChunk>[];
    for (final chunk in chunks) {
      final embedding = _decodeEmbedding(chunk.embeddingJson);
      if (embedding == null || embedding.isEmpty) continue;
      final score = cosineSimilarity(queryEmbedding, embedding);
      scored.add(_ScoredChunk(chunk: chunk, score: score));
    }
    if (scored.isEmpty) return <AiAssistantContextChunk>[];

    scored.sort((a, b) => b.score.compareTo(a.score));
    final selected = _selectRelevant(scored, topK: topK);

    await DeepSeekLogger.logResponse(
      provider: 'Eden AI',
      module: 'ai_assistant.embedding.selection',
      endpoint: 'local://ai_assistant/context/vector_select',
      statusCode: 200,
      body: <String, Object?>{
        'selected': selected.length,
        'candidate_chunks': scored.length,
        'chunk_version': chunkVersion,
        'best_score': scored.first.score,
        'p50_score': _percentile(scored.map((e) => e.score).toList(), 0.50),
        'p75_score': _percentile(scored.map((e) => e.score).toList(), 0.75),
        'selection_rule': 'fused_context_query_plus_continuous_window_topk',
        'retrieval_before_message_id': retrievalBeforeMessageId,
        'query_preview': _preview(query, maxLength: 220),
        'top_scores': scored.take(10).map((e) => {
              'chunk_id': e.chunk.id,
              'score': double.parse(e.score.toStringAsFixed(4)),
              'selected': selected.any((c) => c.id == e.chunk.id),
              'preview': _preview(e.chunk.chunkText, maxLength: 110),
            }).toList(),
      },
      model: embeddingModel,
    );

    selected.sort((a, b) {
      final byTime = a.startMessageId.compareTo(b.startMessageId);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });

    return selected;
  }

  List<AiAssistantContextChunk> _selectRelevant(List<_ScoredChunk> scored, {required int topK}) {
    if (scored.isEmpty) return <AiAssistantContextChunk>[];
    final scores = scored.map((e) => e.score).toList();
    final best = scored.first.score;
    final p75 = _percentile(scores, 0.75);

    // Holistic retrieval favors recall but still constrains context by topK
    // and a top-score window. Each candidate is a large continuous conversation
    // window, so selected results preserve local dialogue flow instead of
    // isolated sentences.
    final hasReliableTop = best >= strongSimilarity ||
        (best >= minAcceptSimilarity && (best - p75) >= outlierGap) ||
        (scored.length <= 4 && best >= minAcceptSimilarity);
    if (!hasReliableTop) return <AiAssistantContextChunk>[];

    final dynamicThreshold = max(minAcceptSimilarity, best - maxScoreMargin);
    return scored
        .where((e) => e.score >= dynamicThreshold)
        .take(topK)
        .map((e) => e.chunk)
        .toList();
  }

  Future<List<double>> createEmbedding({
    required String apiKey,
    required String text,
    String model = embeddingModel,
  }) async {
    final results = await createEmbeddings(apiKey: apiKey, texts: <String>[text], model: model);
    return results.isEmpty ? <double>[] : results.first;
  }

  Future<List<List<double>>> createEmbeddings({
    required String apiKey,
    required List<String> texts,
    String model = embeddingModel,
  }) async {
    final cleaned = texts.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (cleaned.isEmpty) return <List<double>>[];

    final headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Connection': 'close',
    };
    final body = <String, Object?>{
      'model': model,
      'input': cleaned.length == 1 ? cleaned.first : cleaned,
      'encoding_format': 'float',
      'dimensions': embeddingDimensions,
      'metadata': <String, Object?>{
        'module': 'ai_assistant',
        'retrieval': chunkVersion,
      },
    };

    await DeepSeekLogger.logRequest(
      provider: 'Eden AI',
      module: 'ai_assistant.embedding',
      endpoint: _endpoint,
      headers: headers,
      body: <String, Object?>{
        'model': model,
        'input_count': cleaned.length,
        'input_total_length': cleaned.fold<int>(0, (sum, item) => sum + item.length),
        'input_previews': cleaned.take(5).map((e) => _preview(e)).toList(),
        'encoding_format': 'float',
        'dimensions': embeddingDimensions,
      },
      model: model,
    );

    try {
      final resp = await http
          .post(
            Uri.parse(_endpoint),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        final error = Exception('Eden AI Embedding 调用失败：HTTP ${resp.statusCode} ${resp.body}');
        await DeepSeekLogger.logResponse(
          provider: 'Eden AI',
          module: 'ai_assistant.embedding',
          endpoint: _endpoint,
          statusCode: resp.statusCode,
          body: resp.body,
          model: model,
        );
        await DeepSeekLogger.logError(
          provider: 'Eden AI',
          module: 'ai_assistant.embedding',
          endpoint: _endpoint,
          error: error,
          model: model,
        );
        throw error;
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Eden AI Embedding 返回格式异常。');
      }
      final data = decoded['data'];
      if (data is! List || data.isEmpty) {
        throw Exception('Eden AI Embedding 没有返回向量。');
      }
      final indexed = <int, List<double>>{};
      for (var i = 0; i < data.length; i++) {
        final item = data[i];
        if (item is! Map || item['embedding'] is! List) continue;
        final indexValue = item['index'];
        final index = indexValue is num ? indexValue.toInt() : i;
        indexed[index] = (item['embedding'] as List).map((v) => (v as num).toDouble()).toList();
      }
      final embeddings = <List<double>>[];
      for (var i = 0; i < cleaned.length; i++) {
        final embedding = indexed[i];
        if (embedding != null) embeddings.add(embedding);
      }
      if (embeddings.isEmpty) {
        throw Exception('Eden AI Embedding 返回中缺少 embedding 字段。');
      }

      await DeepSeekLogger.logResponse(
        provider: 'Eden AI',
        module: 'ai_assistant.embedding',
        endpoint: _endpoint,
        statusCode: resp.statusCode,
        body: <String, Object?>{
          'model': decoded['model']?.toString() ?? model,
          'provider': decoded['provider']?.toString(),
          'input_count': cleaned.length,
          'vector_count': embeddings.length,
          'vector_dims': embeddings.map((e) => e.length).toSet().toList(),
          'usage': decoded['usage'],
          'cost': decoded['cost'],
        },
        model: model,
      );

      return embeddings;
    } catch (e, st) {
      await DeepSeekLogger.logError(
        provider: 'Eden AI',
        module: 'ai_assistant.embedding',
        endpoint: _endpoint,
        error: e,
        stackTrace: st,
        model: model,
      );
      rethrow;
    }
  }

  Future<void> _ensureContextChunks({required int conversationId, required int beforeMessageId}) async {
    final messages = await _dao.listMessages(conversationId);
    final history = messages
        .where((m) =>
            m.id < beforeMessageId &&
            (m.role == 'user' || m.role == 'assistant') &&
            _isUsableIndexMessage(m))
        .toList();
    if (history.isEmpty) return;

    for (final chunk in _continuousConversationWindows(history)) {
      await _dao.upsertContextChunk(
        conversationId: conversationId,
        startMessageId: chunk.startMessageId,
        endMessageId: chunk.endMessageId,
        sourceMessageIds: jsonEncode(chunk.sourceMessageIds),
        chunkText: chunk.text,
        contentHash: _stableHash('$chunkVersion\n${chunk.text}'),
        startCreatedAtMs: chunk.startCreatedAtMs,
        endCreatedAtMs: chunk.endCreatedAtMs,
        chunkVersion: chunkVersion,
      );
    }
  }

  List<_ChunkDraft> _continuousConversationWindows(List<AiAssistantMessage> history) {
    // Build large continuous windows over the real chat transcript. This is
    // intentionally not single-message indexing. Each embedding represents a
    // coherent section of the conversation flow so the semantic search can
    // understand pronouns, follow-ups, corrections, and earlier commitments in
    // context.
    if (history.isEmpty) return <_ChunkDraft>[];
    final chunks = <_ChunkDraft>[];
    var start = 0;

    while (start < history.length) {
      var end = start;
      final windowMessages = <AiAssistantMessage>[];
      final buffer = StringBuffer()
        ..writeln('以下是连续聊天窗口上下文，保持原始顺序：');

      while (end < history.length) {
        final candidate = history[end];
        final candidateLine = _messageLine(candidate);
        final nextLength = buffer.length + candidateLine.length + 1;
        if (windowMessages.isNotEmpty && nextLength > maxChunkChars) break;
        windowMessages.add(candidate);
        buffer.writeln(candidateLine);
        end++;
      }

      if (windowMessages.isEmpty) {
        final single = history[start];
        windowMessages.add(single);
        buffer.writeln(_messageLine(single));
        end = start + 1;
      }

      chunks.add(_draftFromMessages(windowMessages, buffer.toString().trim()));

      if (end >= history.length) break;
      start = max(start + 1, end - windowOverlapMessages);
    }

    return chunks;
  }

  _ChunkDraft _draftFromMessages(List<AiAssistantMessage> messages, String text) {
    final startMessageId = messages.map((m) => m.id).reduce(min);
    final endMessageId = messages.map((m) => m.id).reduce(max);
    final startCreatedAtMs = messages.map((m) => m.createdAtMs).reduce(min);
    final endCreatedAtMs = messages.map((m) => m.createdAtMs).reduce(max);
    return _ChunkDraft(
      text: text,
      startMessageId: startMessageId,
      endMessageId: endMessageId,
      sourceMessageIds: messages.map((m) => m.id).toList(),
      startCreatedAtMs: startCreatedAtMs,
      endCreatedAtMs: endCreatedAtMs,
    );
  }

  static String _messageLine(AiAssistantMessage message) {
    final role = message.role == 'assistant' ? '助手' : '用户';
    final content = message.role == 'assistant'
        ? _preview(message.content, maxLength: 900)
        : _preview(message.content, maxLength: 700);
    return '$role：$content';
  }

  static String _documentEmbeddingText(String chunkText) {
    // Embed the same compact continuous conversation window that may be sent to the chat model.
    return chunkText.trim();
  }

  static bool _isUsableIndexMessage(AiAssistantMessage message) {
    final content = message.content.trim();
    if (content.isEmpty) return false;
    if (message.error != null && message.error!.trim().isNotEmpty) return false;
    if (content.startsWith('AI 调用失败')) return false;
    if (message.excludeFromContext) return false;
    return true;
  }

  static String _preview(String value, {int maxLength = 160}) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxLength) return compact;
    return '${compact.substring(0, maxLength)}…';
  }

  static double _percentile(List<double> values, double p) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final idx = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1).toInt();
    return sorted[idx];
  }

  static List<double>? _decodeEmbedding(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return null;
      return decoded.map((v) => (v as num).toDouble()).toList();
    } catch (_) {
      return null;
    }
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0;
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA <= 0 || normB <= 0) return 0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  static String _stableHash(String text) {
    const int fnvOffset = 0xcbf29ce484222325;
    const int fnvPrime = 0x100000001b3;
    var hash = fnvOffset;
    for (final codeUnit in text.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xFFFFFFFFFFFFFFFF;
    }
    return '${text.length}_${hash.toRadixString(16)}';
  }
}


class _ChunkDraft {
  final String text;
  final int startMessageId;
  final int endMessageId;
  final List<int> sourceMessageIds;
  final int startCreatedAtMs;
  final int endCreatedAtMs;

  const _ChunkDraft({
    required this.text,
    required this.startMessageId,
    required this.endMessageId,
    required this.sourceMessageIds,
    required this.startCreatedAtMs,
    required this.endCreatedAtMs,
  });
}

class _ScoredChunk {
  final AiAssistantContextChunk chunk;
  final double score;

  const _ScoredChunk({required this.chunk, required this.score});
}
