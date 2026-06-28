import 'dart:convert';
import 'dart:io';

import '../services/unified_ai_service.dart';
import '../utils/deepseek_logger.dart';
import 'ai_assistant_dao.dart';
import 'ai_assistant_embedding_service.dart';
import 'ai_assistant_file_text_extractor.dart';
import 'ai_assistant_models.dart';

class AiAssistantSendResult {
  final AiAssistantMessage message;
  final String provider;
  final String model;
  final String label;
  final String contextMode;

  const AiAssistantSendResult({
    required this.message,
    required this.provider,
    required this.model,
    required this.label,
    required this.contextMode,
  });
}

class AiAssistantService {
  AiAssistantService({
    AiAssistantDao? dao,
    UnifiedAiService? aiService,
    AiAssistantEmbeddingService? embeddingService,
  })  : _dao = dao ?? AiAssistantDao(),
        _aiService = aiService ?? UnifiedAiService(),
        _embeddingService = embeddingService ?? AiAssistantEmbeddingService(dao: dao, aiService: aiService);

  // Mode 2 is now a fused mainstream chat-context strategy:
  // remote conversation metadata (when available) + local memories + compressed
  // summary + keyword hits + Eden AI/OpenAI embedding retrieval + recent window.
  static const int recentMessageCount = 8;
  static const int semanticRetrievedChunkCount = 3;
  static const int keywordHitCount = 4;
  static const int maxFusionQueryChars = 3200;
  static const int maxSystemContextChars = 5200;
  static const int maxSummaryChars = 900;
  static const int contextBlockBudgetChars = 4200;
  static const int maxMemoryBlockChars = 700;
  static const int maxKeywordBlockChars = 1100;
  static const int maxSemanticBlockChars = 1700;
  static const int maxRecentAssistantChars = 1800;
  static const double contextOverlapDropRatio = 0.45;

  final AiAssistantDao _dao;
  final UnifiedAiService _aiService;
  final AiAssistantEmbeddingService _embeddingService;
  final AiAssistantFileTextExtractor _fileTextExtractor = AiAssistantFileTextExtractor();

  Future<AiAssistantSendResult> sendMessage({
    required int conversationId,
    required String content,
    required String contextMode,
    List<AiAssistantPendingAttachment> attachments = const <AiAssistantPendingAttachment>[],
  }) async {
    final text = content.trim();
    if (text.isEmpty && attachments.isEmpty) {
      throw ArgumentError('消息不能为空');
    }

    final normalizedContextMode = AiAssistantContextMode.normalize(contextMode);
    await _dao.updateContextMode(conversationId, normalizedContextMode);

    final cfg = await _aiService.resolveGlobalConfig();
    if (!cfg.available) {
      final error = StateError('当前 AI 配置不可用，请先在设置页配置 ${cfg.label} 的 API Key。');
      await DeepSeekLogger.logError(
        provider: cfg.label,
        module: 'ai_assistant.chat.config',
        endpoint: cfg.endpoint,
        error: error,
        model: cfg.model,
      );
      throw error;
    }

    final displayText = text.isEmpty ? '（已上传附件）' : text;
    final userMessageId = await _dao.insertMessage(
      conversationId: conversationId,
      role: 'user',
      content: displayText,
      provider: cfg.provider,
      model: cfg.model,
    );
    final persistedAttachments = await _persistPendingAttachments(
      conversationId: conversationId,
      messageId: userMessageId,
      attachments: attachments,
    );
    await _dao.maybeSetAutoTitle(conversationId, displayText);

    final requestMessages = await _buildRequestMessages(
      conversationId: conversationId,
      currentMessageId: userMessageId,
      currentUserText: displayText,
      currentAttachments: persistedAttachments,
      contextMode: normalizedContextMode,
      provider: cfg.provider,
      apiKey: cfg.apiKey,
      model: cfg.model,
      endpoint: cfg.endpoint,
    );

    final start = DateTime.now().millisecondsSinceEpoch;
    try {
      final answer = await _aiService.generateChatMessages(
        messages: requestMessages,
        purpose: 'ai_assistant.chat.${normalizedContextMode}',
      );
      final latency = DateTime.now().millisecondsSinceEpoch - start;
      final assistantId = await _dao.insertMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: answer.trim().isEmpty ? '（模型没有返回内容）' : answer.trim(),
        provider: cfg.provider,
        model: cfg.model,
        latencyMs: latency,
      );
      final messages = await _dao.listMessages(conversationId);
      final message = messages.firstWhere((m) => m.id == assistantId, orElse: () => messages.last);
      return AiAssistantSendResult(
        message: message,
        provider: cfg.provider,
        model: cfg.model,
        label: cfg.label,
        contextMode: normalizedContextMode,
      );
    } catch (e, st) {
      final latency = DateTime.now().millisecondsSinceEpoch - start;
      await DeepSeekLogger.logError(
        provider: cfg.label,
        module: 'ai_assistant.chat',
        endpoint: cfg.endpoint,
        error: e,
        stackTrace: st,
        model: cfg.model,
      );
      final err = 'AI 调用失败：$e';
      final assistantId = await _dao.insertMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: err,
        provider: cfg.provider,
        model: cfg.model,
        latencyMs: latency,
        error: e.toString(),
      );
      final messages = await _dao.listMessages(conversationId);
      final message = messages.firstWhere((m) => m.id == assistantId, orElse: () => messages.last);
      return AiAssistantSendResult(
        message: message,
        provider: cfg.provider,
        model: cfg.model,
        label: cfg.label,
        contextMode: normalizedContextMode,
      );
    }
  }

  Future<List<UnifiedAiChatMessage>> _buildRequestMessages({
    required int conversationId,
    required int currentMessageId,
    required String currentUserText,
    required List<AiAssistantAttachment> currentAttachments,
    required String contextMode,
    required String provider,
    required String apiKey,
    required String model,
    required String endpoint,
  }) async {
    if (contextMode == AiAssistantContextMode.edenAiEmbedding) {
      return _buildFusedSemanticMessages(
        conversationId: conversationId,
        currentMessageId: currentMessageId,
        currentUserText: currentUserText,
        currentAttachments: currentAttachments,
        provider: provider,
        apiKey: apiKey,
        model: model,
        endpoint: endpoint,
      );
    }
    return _buildFullHistoryMessages(
      conversationId: conversationId,
      provider: provider,
      apiKey: apiKey,
      model: model,
      endpoint: endpoint,
    );
  }

  Future<List<UnifiedAiChatMessage>> _buildFusedSemanticMessages({
    required int conversationId,
    required int currentMessageId,
    required String currentUserText,
    required List<AiAssistantAttachment> currentAttachments,
    required String provider,
    required String apiKey,
    required String model,
    required String endpoint,
  }) async {
    final conversation = await _dao.getConversation(conversationId);
    final history = await _dao.listMessages(conversationId);
    final attachmentsByMessageId = _groupAttachments(await _dao.listAttachmentsForConversation(conversationId));
    final currentUserTextWithAttachments = _contentWithAttachments(currentUserText, currentAttachments, forRequest: true);
    final previousMessages = history
        .where((m) =>
            m.id < currentMessageId &&
            (m.role == 'user' || m.role == 'assistant') &&
            _isUsableContextMessage(m))
        .toList();

    final recentMessages = _takeLast(previousMessages, recentMessageCount);
    final recentIds = recentMessages.map((m) => m.id).toSet();
    final olderMessages = previousMessages.where((m) => !recentIds.contains(m.id)).toList();

    final memories = await _loadAndBackfillMemories(
      conversationId: conversationId,
      previousMessages: previousMessages,
      currentUserText: currentUserTextWithAttachments,
    );
    final summary = await _buildOrUpdateCompressedSummary(
      conversationId: conversationId,
      olderMessages: olderMessages,
    );
    final keywordHits = _keywordSearch(
      messages: olderMessages,
      currentUserText: currentUserText,
      excludeIds: recentIds,
      limit: keywordHitCount,
    );

    final retrievalQuery = _buildFusedRetrievalQuery(
      currentUserText: currentUserTextWithAttachments,
      recentMessages: recentMessages,
      memories: memories,
      compressedSummary: summary,
      keywordHits: keywordHits,
    );

    var retrievedChunks = <AiAssistantContextChunk>[];
    try {
      final rawChunks = await _embeddingService.retrieveRelevantChunks(
        conversationId: conversationId,
        currentMessageId: currentMessageId,
        beforeMessageId: currentMessageId,
        query: retrievalQuery,
        topK: semanticRetrievedChunkCount + 2,
      );
      retrievedChunks = rawChunks.where((chunk) => !_chunkOverlapsIds(chunk, recentIds)).take(semanticRetrievedChunkCount).toList();
    } catch (e, st) {
      await DeepSeekLogger.logError(
        provider: 'AI Assistant',
        module: 'ai_assistant.context_builder.fused_semantic',
        endpoint: 'local://ai_assistant/context/fused_edenai_embedding',
        error: e,
        stackTrace: st,
        model: AiAssistantEmbeddingService.embeddingModel,
      );
      retrievedChunks = <AiAssistantContextChunk>[];
    }

    final previousById = <int, AiAssistantMessage>{
      for (final message in previousMessages) message.id: message,
    };
    final contextBlocks = _buildContextBlocks(
      conversation: conversation,
      memories: memories,
      compressedSummary: summary,
      keywordHits: keywordHits,
      retrievedChunks: retrievedChunks,
      recentIds: recentIds,
      previousById: previousById,
    );
    final selectedBlocks = _dedupeAndBudgetContextBlocks(
      contextBlocks,
      initiallyUsedMessageIds: recentIds,
      maxChars: contextBlockBudgetChars,
    );
    final contextMessage = _blocksAsSystemContext(conversation: conversation, blocks: selectedBlocks);

    final messages = <UnifiedAiChatMessage>[];
    if (contextMessage.trim().isNotEmpty) {
      messages.add(UnifiedAiChatMessage(role: 'system', content: _limitText(contextMessage, maxSystemContextChars)));
    }
    for (final message in recentMessages) {
      final attachments = attachmentsByMessageId[message.id] ?? const <AiAssistantAttachment>[];
      messages.add(UnifiedAiChatMessage(
        role: message.role,
        content: _messageContentForRequest(message, attachments),
        parts: message.role == 'user'
            ? await _providerPartsForAttachments(
                attachments: attachments,
                provider: provider,
                apiKey: apiKey,
                model: model,
                endpoint: endpoint,
              )
            : const <UnifiedAiContentPart>[],
      ));
    }
    messages.add(await _currentUserMessageForRequest(
      currentUserText,
      currentAttachments,
      provider: provider,
      apiKey: apiKey,
      model: model,
      endpoint: endpoint,
    ));

    await DeepSeekLogger.logResponse(
      provider: 'AI Assistant',
      module: 'ai_assistant.context_builder.fused_semantic.selection',
      endpoint: 'local://ai_assistant/context/fused_selection',
      statusCode: 200,
      body: <String, Object?>{
        'mode': AiAssistantContextMode.edenAiEmbedding,
        'recent_message_count': recentMessages.length,
        'memory_count': memories.length,
        'keyword_hit_count': keywordHits.length,
        'retrieved_chunk_count': retrievedChunks.length,
        'candidate_context_block_count': contextBlocks.length,
        'selected_context_block_count': selectedBlocks.length,
        'selected_context_blocks': selectedBlocks.map((b) => {
              'type': b.type,
              'priority': b.priority,
              'score': double.parse(b.score.toStringAsFixed(3)),
              'source_message_count': b.sourceMessageIds.length,
              'preview': _compact(b.content, maxLength: 90),
            }).toList(),
        'has_summary': summary.trim().isNotEmpty,
        'provider_conversation_id_present': (conversation?.providerConversationId ?? '').trim().isNotEmpty,
        'provider_previous_response_id_present': (conversation?.providerPreviousResponseId ?? '').trim().isNotEmpty,
      },
      model: AiAssistantEmbeddingService.embeddingModel,
    );

    return _deduplicateMessages(messages);
  }

  Future<List<UnifiedAiChatMessage>> _buildFullHistoryMessages({
    required int conversationId,
    required String provider,
    required String apiKey,
    required String model,
    required String endpoint,
  }) async {
    final history = await _dao.listMessages(conversationId);
    final attachmentsByMessageId = _groupAttachments(await _dao.listAttachmentsForConversation(conversationId));
    final result = <UnifiedAiChatMessage>[];
    for (final message in history.where((m) => (m.role == 'user' || m.role == 'assistant') && _isUsableContextMessage(m))) {
      final attachments = attachmentsByMessageId[message.id] ?? const <AiAssistantAttachment>[];
      result.add(UnifiedAiChatMessage(
        role: message.role,
        content: _messageContentForRequest(message, attachments),
        parts: message.role == 'user'
            ? await _providerPartsForAttachments(
                attachments: attachments,
                provider: provider,
                apiKey: apiKey,
                model: model,
                endpoint: endpoint,
              )
            : const <UnifiedAiContentPart>[],
      ));
    }
    return result;
  }

  Future<List<String>> _loadAndBackfillMemories({
    required int conversationId,
    required List<AiAssistantMessage> previousMessages,
    required String currentUserText,
  }) async {
    final extracted = <String, String>{};
    for (final message in previousMessages.where((m) => m.role == 'user')) {
      extracted.addAll(_extractMemoryCandidates(message.content));
    }
    extracted.addAll(_extractMemoryCandidates(currentUserText));

    for (final entry in extracted.entries) {
      await _dao.upsertMemory(
        conversationId: conversationId,
        memoryKey: entry.key,
        memoryValue: entry.value,
      );
    }

    final stored = await _dao.listMemories(conversationId, limit: 12);
    return stored
        .where((m) {
          final key = (m['memory_key'] ?? '').toString();
          final value = (m['memory_value'] ?? '').toString();
          if (key == '用户称呼' && !_isValidMemoryName(value)) return false;
          return value.trim().isNotEmpty;
        })
        .map((m) => '- ${m['memory_key']}: ${m['memory_value']}')
        .where((e) => e.trim().length > 3)
        .toList();
  }

  Map<String, String> _extractMemoryCandidates(String text) {
    final value = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final result = <String, String>{};
    if (value.isEmpty) return result;

    final namePatterns = <RegExp>[
      RegExp(r'(?:我叫|请叫我)([^，。,.!！?？\s]{1,16})'),
      RegExp(r'以后(?:叫我|称呼我)([^，。,.!！?？\s]{1,16})'),
      RegExp(r'我是([^，。,.!！?？\s]{1,16})(?:$|[，。,.!！])'),
    ];
    for (final pattern in namePatterns) {
      final match = pattern.firstMatch(value);
      if (match != null && !_looksLikeQuestion(value)) {
        final name = _cleanMemoryValue(match.group(1) ?? '');
        if (_isValidMemoryName(name)) result['用户称呼'] = name;
      }
    }

    final goal = RegExp(r'(?:我的目标是|目标是|我想要|我希望|我打算)([^。.!！?？]{2,80})').firstMatch(value);
    if (goal != null) {
      final goalText = (goal.group(1) ?? '').trim();
      if (goalText.isNotEmpty) result['用户目标'] = goalText;
    }

    final like = RegExp(r'(?:我喜欢|偏好|我更喜欢)([^。.!！?？]{2,60})').firstMatch(value);
    if (like != null) {
      final likeText = (like.group(1) ?? '').trim();
      if (likeText.isNotEmpty) result['用户偏好'] = likeText;
    }

    final dislike = RegExp(r'(?:我不喜欢|不要|避免)([^。.!！?？]{2,60})').firstMatch(value);
    if (dislike != null) {
      final dislikeText = (dislike.group(1) ?? '').trim();
      if (dislikeText.isNotEmpty) result['用户避免项'] = dislikeText;
    }
    return result;
  }

  Future<String> _buildOrUpdateCompressedSummary({
    required int conversationId,
    required List<AiAssistantMessage> olderMessages,
  }) async {
    if (olderMessages.isEmpty) return '';
    final coveredUntil = olderMessages.last.id;
    final cached = await _dao.getLatestSummary(conversationId);
    final cachedCovered = (cached?['covered_message_id_until'] as num?)?.toInt() ?? 0;
    final cachedSummary = (cached?['summary'] ?? '').toString().trim();
    if (cachedSummary.isNotEmpty && cachedCovered >= coveredUntil) return cachedSummary;

    final lines = <String>[];
    final important = olderMessages
        .where((m) => _isUsableContextMessage(m) && (m.role == 'user' || _messageImportance(m.content) > 0))
        .toList();
    final source = important.isNotEmpty ? important : olderMessages.where(_isUsableContextMessage).toList();
    final tail = source.length > 18 ? source.sublist(source.length - 18) : source;
    for (final message in tail) {
      final role = message.role == 'assistant' ? '助手' : '用户';
      lines.add('- $role：${_messageSummaryLine(message)}');
      if (lines.join('\n').length > maxSummaryChars) break;
    }
    final summary = lines.join('\n').trim();
    if (summary.isNotEmpty) {
      await _dao.upsertSummary(
        conversationId: conversationId,
        summary: summary,
        coveredMessageIdUntil: coveredUntil,
      );
    }
    return summary;
  }

  List<AiAssistantMessage> _keywordSearch({
    required List<AiAssistantMessage> messages,
    required String currentUserText,
    required Set<int> excludeIds,
    required int limit,
  }) {
    final keywords = _extractKeywords(currentUserText);
    if (keywords.isEmpty) return <AiAssistantMessage>[];

    final scored = <_ScoredMessage>[];
    for (final message in messages) {
      if (excludeIds.contains(message.id) || message.excludeFromContext) continue;
      final content = message.content.toLowerCase();
      var score = 0;
      for (final kw in keywords) {
        if (kw.length <= 1) continue;
        if (content.contains(kw.toLowerCase())) score += kw.length >= 4 ? 3 : 2;
      }
      score += _messageImportance(message.content);
      score += (message.contextWeight * 3).round();
      if (score > 0) scored.add(_ScoredMessage(message, score));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.message.id.compareTo(a.message.id);
    });
    return scored.take(limit).map((e) => e.message).toList();
  }

  List<String> _extractKeywords(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'[，。！？、,.!?;；:：\[\]（）(){}<>"“”‘’]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    final tokens = <String>{};
    for (final part in cleaned.split(' ')) {
      if (part.trim().length >= 2) tokens.add(part.trim());
    }
    final chineseTerms = RegExp(r'[\u4e00-\u9fa5]{2,8}').allMatches(cleaned).map((m) => m.group(0) ?? '');
    for (final term in chineseTerms) {
      if (term.length >= 2 && !_isStopTerm(term)) tokens.add(term);
    }
    return tokens.take(24).toList();
  }

  bool _isStopTerm(String value) {
    const stops = <String>{'什么', '怎么', '如何', '今天', '现在', '这个', '那个', '一下', '可以', '帮我', '请问'};
    return stops.contains(value);
  }

  int _messageImportance(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    var score = 0;
    const markers = <String>['我叫', '我是', '叫我', '目标', '计划', '工作', '喜欢', '不喜欢', '希望', '打算', '需要', '之前', '以后', '记住'];
    for (final marker in markers) {
      if (compact.contains(marker)) score += 2;
    }
    if (compact.length > 120) score += 1;
    return score;
  }

  String _buildFusedRetrievalQuery({
    required String currentUserText,
    required List<AiAssistantMessage> recentMessages,
    required List<String> memories,
    required String compressedSummary,
    required List<AiAssistantMessage> keywordHits,
  }) {
    // The retrieval query should be contextual, but not polluted by every
    // already-selected context source. Use the recent real dialogue plus the
    // current request, so short follow-ups like “继续” or “这个目标” can be
    // interpreted correctly without dragging unrelated old summaries into the
    // vector query.
    final buffer = StringBuffer();
    if (recentMessages.isNotEmpty) {
      buffer
        ..writeln('最近真实对话：')
        ..writeln(_messagesAsTranscript(recentMessages, compact: true, maxContentLength: 360))
        ..writeln();
    }
    buffer
      ..writeln('当前用户请求：')
      ..writeln(currentUserText.trim());
    return _limitText(buffer.toString().trim(), maxFusionQueryChars);
  }


  List<AiAssistantContextBlock> _buildContextBlocks({
    AiAssistantConversation? conversation,
    required List<String> memories,
    required String compressedSummary,
    required List<AiAssistantMessage> keywordHits,
    required List<AiAssistantContextChunk> retrievedChunks,
    required Set<int> recentIds,
    required Map<int, AiAssistantMessage> previousById,
  }) {
    final blocks = <AiAssistantContextBlock>[];
    final remoteId = (conversation?.providerConversationId ?? '').trim();
    final previousId = (conversation?.providerPreviousResponseId ?? '').trim();
    if (remoteId.isNotEmpty || previousId.isNotEmpty) {
      final lines = <String>[];
      if (remoteId.isNotEmpty) lines.add('- provider_conversation_id: $remoteId');
      if (previousId.isNotEmpty) lines.add('- provider_previous_response_id: $previousId');
      blocks.add(_contextBlock(
        type: 'remote_state',
        content: '【远端会话状态】\n${lines.join('\n')}',
        priority: 100,
        score: 1.0,
      ));
    }

    if (memories.isNotEmpty) {
      blocks.add(_contextBlock(
        type: 'memory',
        content: _limitText('【本地记忆】\n${memories.join('\n')}', maxMemoryBlockChars),
        priority: 90,
        score: 1.0,
      ));
    }

    for (final chunk in retrievedChunks) {
      final ids = _decodeSourceMessageIds(chunk.sourceMessageIds);
      final feedbackScore = _feedbackScoreForIds(ids, previousById);
      if (_hasExcludedAssistant(ids, previousById)) continue;
      blocks.add(_contextBlock(
        type: 'semantic',
        content: _limitText('【语义检索命中的连续上下文】\n${chunk.chunkText.trim()}', maxSemanticBlockChars),
        sourceMessageIds: ids,
        priority: 74 + (feedbackScore > 0 ? 8 : 0),
        score: 0.75 + feedbackScore,
      ));
    }

    if (keywordHits.isNotEmpty) {
      final cleanHits = keywordHits.where((m) => !m.excludeFromContext).toList();
      if (cleanHits.isNotEmpty) {
        final feedbackScore = cleanHits.fold<double>(0, (sum, m) => sum + m.contextWeight);
        blocks.add(_contextBlock(
          type: 'keyword',
          content: _limitText('【关键词检索命中的历史】\n${_messagesAsTranscript(cleanHits, compact: true, maxContentLength: 220)}', maxKeywordBlockChars),
          sourceMessageIds: cleanHits.map((m) => m.id).toList(),
          priority: 62 + (feedbackScore > 0 ? 6 : 0),
          score: 0.55 + feedbackScore * 0.2,
        ));
      }
    }

    if (compressedSummary.trim().isNotEmpty) {
      blocks.add(_contextBlock(
        type: 'summary',
        content: _limitText('【早期对话压缩摘要】\n${compressedSummary.trim()}', maxSummaryChars),
        priority: 35,
        score: 0.35,
      ));
    }

    return blocks;
  }

  AiAssistantContextBlock _contextBlock({
    required String type,
    required String content,
    List<int> sourceMessageIds = const <int>[],
    required int priority,
    required double score,
  }) {
    final normalized = _normalizeForHash(content);
    return AiAssistantContextBlock(
      type: type,
      content: content.trim(),
      sourceMessageIds: sourceMessageIds,
      contentHash: _stableHash(normalized),
      priority: priority,
      score: score,
    );
  }

  List<AiAssistantContextBlock> _dedupeAndBudgetContextBlocks(
    List<AiAssistantContextBlock> blocks, {
    required Set<int> initiallyUsedMessageIds,
    required int maxChars,
  }) {
    final sorted = [...blocks]
      ..sort((a, b) {
        final byPriority = b.priority.compareTo(a.priority);
        if (byPriority != 0) return byPriority;
        return b.score.compareTo(a.score);
      });
    final usedHashes = <String>{};
    final usedMessageIds = <int>{...initiallyUsedMessageIds};
    final result = <AiAssistantContextBlock>[];
    var usedChars = 0;

    for (final block in sorted) {
      final content = block.content.trim();
      if (content.isEmpty || usedHashes.contains(block.contentHash)) continue;
      if (block.score < -0.20 && block.type != 'memory' && block.type != 'remote_state') continue;

      final ids = block.sourceMessageIds;
      if (ids.isNotEmpty) {
        final overlapCount = ids.where(usedMessageIds.contains).length;
        final overlapRatio = overlapCount / ids.length;
        if (overlapRatio >= contextOverlapDropRatio) continue;
      }

      if (usedChars + content.length > maxChars) {
        if (result.isNotEmpty) continue;
        final clipped = _limitText(content, maxChars);
        result.add(AiAssistantContextBlock(
          type: block.type,
          content: clipped,
          sourceMessageIds: block.sourceMessageIds,
          contentHash: _stableHash(_normalizeForHash(clipped)),
          score: block.score,
          priority: block.priority,
        ));
        break;
      }

      result.add(block);
      usedChars += content.length;
      usedHashes.add(block.contentHash);
      usedMessageIds.addAll(ids);
    }

    result.sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      if (priority != 0) return priority;
      return a.type.compareTo(b.type);
    });
    return result;
  }

  String _blocksAsSystemContext({
    AiAssistantConversation? conversation,
    required List<AiAssistantContextBlock> blocks,
  }) {
    if (blocks.isEmpty) return '';
    final buffer = StringBuffer()
      ..writeln('以下是 AI 助手为理解当前请求自动筛选后的上下文。')
      ..writeln('这些上下文已经做过反馈加权、重复内容去重和长度预算控制；如果某部分明显无关，可以忽略。')
      ..writeln();
    for (final block in blocks) {
      buffer
        ..writeln(block.content.trim())
        ..writeln();
    }
    return buffer.toString().trim();
  }

  List<int> _decodeSourceMessageIds(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((v) => v is num ? v.toInt() : int.tryParse(v.toString()))
            .whereType<int>()
            .toList();
      }
    } catch (_) {}
    return <int>[];
  }

  double _feedbackScoreForIds(List<int> ids, Map<int, AiAssistantMessage> byId) {
    if (ids.isEmpty) return 0;
    var score = 0.0;
    for (final id in ids) {
      final message = byId[id];
      if (message == null) continue;
      score += message.contextWeight * 0.25;
      if (message.feedbackRating > 0) score += 0.08;
      if (message.feedbackRating < 0) score -= 0.18;
      if (message.feedbackReason == AiAssistantFeedbackReason.irrelevantHistory) score -= 0.25;
      if (message.feedbackReason == AiAssistantFeedbackReason.ignoredRelevantHistory) score += 0.12;
    }
    return score.clamp(-1.0, 1.0).toDouble();
  }

  bool _hasExcludedAssistant(List<int> ids, Map<int, AiAssistantMessage> byId) {
    for (final id in ids) {
      final message = byId[id];
      if (message != null && message.role == 'assistant' && message.excludeFromContext) return true;
    }
    return false;
  }


  bool _isUsableContextMessage(AiAssistantMessage message) {
    final content = message.content.trim();
    if (content.isEmpty) return false;
    if (message.error != null && message.error!.trim().isNotEmpty) return false;
    if (content.startsWith('AI 调用失败')) return false;
    if (message.excludeFromContext) return false;
    return true;
  }

  bool _looksLikeQuestion(String value) {
    return value.contains('?') ||
        value.contains('？') ||
        value.contains('谁') ||
        value.contains('什么') ||
        value.contains('哪里') ||
        value.contains('哪儿') ||
        value.contains('吗');
  }

  String _cleanMemoryValue(String raw) {
    return raw.replaceAll(RegExp(r'^[：:，,。.!！?？\s]+|[：:，,。.!！?？\s]+$'), '').trim();
  }

  bool _isValidMemoryName(String value) {
    if (value.isEmpty || value.length > 16) return false;
    const invalid = <String>{'谁', '什么', '哪里', '哪儿', '吗', '你', '我', '他', '她', '它'};
    if (invalid.contains(value)) return false;
    if (value.contains('谁') || value.contains('什么') || value.contains('哪里')) return false;
    return true;
  }

  String _messageSummaryLine(AiAssistantMessage message) {
    final content = message.content.trim();
    if (message.role == 'assistant') {
      final firstParagraph = content.split(RegExp(r'\n\s*\n')).first.trim();
      return _compact(firstParagraph, maxLength: 96);
    }
    return _compact(content, maxLength: 110);
  }


  Future<List<AiAssistantAttachment>> _persistPendingAttachments({
    required int conversationId,
    required int messageId,
    required List<AiAssistantPendingAttachment> attachments,
  }) async {
    if (attachments.isEmpty) return const <AiAssistantAttachment>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    final persisted = <AiAssistantAttachment>[];
    for (final attachment in attachments) {
      final extractedText = await _extractTextFromPendingAttachment(attachment);
      persisted.add(AiAssistantAttachment(
        id: 0,
        conversationId: conversationId,
        messageId: messageId,
        attachmentType: AiAssistantAttachmentType.normalize(attachment.attachmentType),
        name: attachment.name,
        path: attachment.path,
        mimeType: attachment.mimeType ?? _guessMimeType(attachment.name),
        sizeBytes: attachment.sizeBytes,
        extractedText: extractedText,
        createdAtMs: now,
      ));
    }
    await _dao.insertAttachments(
      conversationId: conversationId,
      messageId: messageId,
      attachments: persisted,
    );
    return _dao.listAttachmentsForMessage(messageId);
  }

  Future<String?> _extractTextFromPendingAttachment(AiAssistantPendingAttachment attachment) async {
    if (attachment.isImage) return null;
    try {
      final file = File(attachment.path);
      if (!await file.exists()) return null;
      final text = await _fileTextExtractor.extract(
        file,
        attachment.name,
        mimeType: attachment.mimeType ?? _guessMimeType(attachment.name),
        sizeBytes: attachment.sizeBytes,
      );
      if ((text ?? '').trim().isNotEmpty) return _limitText(text!.trim(), 60000);
      return null;
    } catch (e, st) {
      await DeepSeekLogger.logError(
        provider: 'AI Assistant',
        module: 'ai_assistant.attachment.extract_text',
        endpoint: 'local://ai_assistant/attachment/extract_text',
        error: e,
        stackTrace: st,
        model: attachment.name,
      );
      return null;
    }
  }

  Map<int, List<AiAssistantAttachment>> _groupAttachments(List<AiAssistantAttachment> attachments) {
    final result = <int, List<AiAssistantAttachment>>{};
    for (final attachment in attachments) {
      result.putIfAbsent(attachment.messageId, () => <AiAssistantAttachment>[]).add(attachment);
    }
    return result;
  }

  String _contentWithAttachments(
    String content,
    List<AiAssistantAttachment> attachments, {
    bool forRequest = false,
  }) {
    final buffer = StringBuffer(content.trim());
    if (attachments.isEmpty) return buffer.toString().trim();
    if (buffer.isNotEmpty) buffer.writeln();
    buffer.writeln();
    buffer.writeln(forRequest ? '【用户上传的附件】' : '【附件】');
    for (final attachment in attachments) {
      final typeLabel = attachment.isImage ? '图片' : '文件';
      final sizeLabel = _formatBytes(attachment.sizeBytes);
      buffer.writeln('- $typeLabel：${attachment.name}（$sizeLabel）');
      final extracted = (attachment.extractedText ?? '').trim();
      if (extracted.isNotEmpty) {
        buffer.writeln('  内容摘录：');
        buffer.writeln(_limitText(extracted, forRequest ? 12000 : 1200));
      } else if (!attachment.isImage && forRequest) {
        buffer.writeln('  文件已作为附件发送；若当前模型/平台不支持原生文件解析，则只能看到文件名和本地可提取内容。');
      }
    }
    return buffer.toString().trim();
  }

  Future<UnifiedAiChatMessage> _currentUserMessageForRequest(
    String currentUserText,
    List<AiAssistantAttachment> attachments, {
    required String provider,
    required String apiKey,
    required String model,
    required String endpoint,
  }) async {
    return UnifiedAiChatMessage(
      role: 'user',
      content: _contentWithAttachments(currentUserText, attachments, forRequest: true),
      parts: await _providerPartsForAttachments(
        attachments: attachments,
        provider: provider,
        apiKey: apiKey,
        model: model,
        endpoint: endpoint,
      ),
    );
  }

  Future<List<UnifiedAiContentPart>> _providerPartsForAttachments({
    required List<AiAssistantAttachment> attachments,
    required String provider,
    required String apiKey,
    required String model,
    required String endpoint,
  }) async {
    final parts = <UnifiedAiContentPart>[];
    final normalizedProvider = provider.trim().toLowerCase();
    for (final attachment in attachments) {
      final file = File(attachment.path);
      if (!file.existsSync()) continue;
      final mime = (attachment.mimeType ?? _guessMimeType(attachment.name) ?? 'application/octet-stream').trim();
      final lower = attachment.name.toLowerCase();
      final length = file.lengthSync();
      if (length <= 0) continue;

      if (attachment.isImage) {
        if (_providerCanReceiveImages(normalizedProvider, model) && length <= 8 * 1024 * 1024) {
          final encoded = base64Encode(file.readAsBytesSync());
          parts.add(UnifiedAiContentPart.imageUrl('data:$mime;base64,$encoded'));
        }
        continue;
      }

      if (normalizedProvider == 'edenai' && _providerCanReceiveFiles(normalizedProvider, model)) {
        final existingProvider = (attachment.provider ?? '').trim().toLowerCase();
        final existingFileId = (attachment.providerFileId ?? '').trim();
        if (existingProvider == 'edenai' && existingFileId.isNotEmpty) {
          parts.add(UnifiedAiContentPart.fileId(fileId: existingFileId, filename: attachment.name, mimeType: mime));
          continue;
        }
        final fileId = await _aiService.uploadEdenAiAssistantFile(
          apiKey: apiKey,
          file: file,
          filename: attachment.name,
          purpose: 'assistants',
        );
        if ((fileId ?? '').trim().isNotEmpty) {
          await _dao.updateAttachmentProviderFile(
            attachmentId: attachment.id,
            provider: 'edenai',
            providerFileId: fileId!.trim(),
          );
          parts.add(UnifiedAiContentPart.fileId(fileId: fileId.trim(), filename: attachment.name, mimeType: mime));
          continue;
        }
      }

      final shouldInlineFile = _providerCanReceiveFiles(normalizedProvider, model) &&
          length <= 18 * 1024 * 1024 &&
          (normalizedProvider == 'openai' ||
              (normalizedProvider == 'openrouter' && lower.endsWith('.pdf')));
      if (shouldInlineFile) {
        try {
          final encoded = base64Encode(file.readAsBytesSync());
          parts.add(UnifiedAiContentPart.fileData(
            filename: attachment.name,
            dataUrl: 'data:$mime;base64,$encoded',
            mimeType: mime,
          ));
        } catch (e, st) {
          await DeepSeekLogger.logError(
            provider: 'AI Assistant',
            module: 'ai_assistant.attachment.inline_file',
            endpoint: 'local://ai_assistant/attachment/inline_file',
            error: e,
            stackTrace: st,
            model: attachment.name,
          );
        }
      }
    }
    return parts;
  }

  bool _providerCanReceiveImages(String provider, String model) {
    return _modelSupportsImageInput(provider, model);
  }

  bool _providerCanReceiveFiles(String provider, String model) {
    return _modelSupportsFileInput(provider, model);
  }

  bool _modelSupportsImageInput(String provider, String model) {
    final p = provider.trim().toLowerCase();
    final m = model.trim().toLowerCase();

    // DeepSeek Chat Completions currently expects text-only message content in
    // this app. deepseek-v4-pro returns `unknown variant image_url`, so never
    // send OpenAI-style image parts to DeepSeek.
    if (p == 'deepseek') return false;

    if (p == 'openai') {
      return _looksLikeVisionModel(m);
    }

    if (p == 'openrouter') {
      // OpenRouter routes many text-only models. If we send image_url to a
      // text-only route, OpenRouter returns: "No endpoints found that support
      // image input". Only send image parts for models that are known/likely
      // multimodal. Unknown models fall back to text attachment descriptions.
      return _looksLikeVisionModel(m);
    }

    if (p == 'edenai') {
      // Eden AI's OpenAI-compatible chat path can handle image parts for
      // multimodal models. Keep this enabled, but the file/text fallback in the
      // message body still protects text-only selections.
      return _looksLikeVisionModel(m) || m.contains('openai/') || m.contains('gpt-');
    }

    if (p == 'gemini') {
      return _looksLikeVisionModel(m) || m.contains('gemini');
    }

    if (p == 'xgrok') {
      return m.contains('vision') || m.contains('grok-4') || m.contains('grok-3');
    }

    return false;
  }

  bool _modelSupportsFileInput(String provider, String model) {
    final p = provider.trim().toLowerCase();
    final m = model.trim().toLowerCase();
    if (p == 'deepseek') return false;
    if (p == 'openai') return true;
    if (p == 'edenai') return true;
    if (p == 'gemini') return false;
    if (p == 'xgrok') return false;
    if (p == 'openrouter') {
      // In this app OpenRouter file parts are only used for PDF parser support.
      // Leave it enabled for models that can at least accept file-parser input;
      // non-PDF files still fall back to local text extraction.
      return true;
    }
    return false;
  }

  bool _looksLikeVisionModel(String model) {
    final m = model.trim().toLowerCase();
    if (m.isEmpty) return false;

    final positiveSignals = <String>[
      'vision',
      '-vl',
      '/vl',
      'vl-',
      'qwen-vl',
      'qwen2-vl',
      'qwen2.5-vl',
      'qwen3-vl',
      'gpt-4o',
      'gpt-4.1',
      'gpt-5',
      'o4-mini',
      'gemini',
      'claude',
      'pixtral',
      'llava',
      'llama-3.2-11b-vision',
      'llama-3.2-90b-vision',
      'mistral-small-3.2',
      'grok-vision',
      'gemma-3',
      'molmo',
      'internvl',
      'kimi-vl',
      'reka',
      'omni',
      'multimodal',
    ];

    final negativeSignals = <String>[
      'embedding',
      'rerank',
      'text-embedding',
    ];

    if (negativeSignals.any(m.contains)) return false;
    return positiveSignals.any(m.contains);
  }

  String? _guessMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) return 'text/markdown';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.xml')) return 'application/xml';
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'text/html';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.pptx')) return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (lower.endsWith('.rtf')) return 'application/rtf';
    return null;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String _messageContentForRequest(AiAssistantMessage message, List<AiAssistantAttachment> attachments) {
    final base = message.role == 'assistant'
        ? _limitText(message.content, maxRecentAssistantChars)
        : _limitText(message.content, 1400);
    return _contentWithAttachments(base, attachments, forRequest: true);
  }

  String _normalizeForHash(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[，。,.!！?？;；:：]'), '').trim().toLowerCase();
  }

  String _stableHash(String text) {
    const int fnvOffset = 0xcbf29ce484222325;
    const int fnvPrime = 0x100000001b3;
    var hash = fnvOffset;
    for (final codeUnit in text.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xFFFFFFFFFFFFFFFF;
    }
    return '${text.length}_${hash.toRadixString(16)}';
  }

  String _buildFusedSystemContext({
    AiAssistantConversation? conversation,
    required List<String> memories,
    required String compressedSummary,
    required List<AiAssistantMessage> keywordHits,
    required List<AiAssistantContextChunk> retrievedChunks,
  }) {
    final buffer = StringBuffer()
      ..writeln('以下是 AI 助手为理解当前请求自动融合的聊天上下文。')
      ..writeln('请结合这些上下文和后续最近真实对话回答；如果某部分明显无关，可以忽略。')
      ..writeln();

    final remoteId = (conversation?.providerConversationId ?? '').trim();
    final previousId = (conversation?.providerPreviousResponseId ?? '').trim();
    if (remoteId.isNotEmpty || previousId.isNotEmpty) {
      buffer..writeln('【远端会话状态】');
      if (remoteId.isNotEmpty) buffer.writeln('- provider_conversation_id: $remoteId');
      if (previousId.isNotEmpty) buffer.writeln('- provider_previous_response_id: $previousId');
      buffer.writeln();
    }

    if (memories.isNotEmpty) {
      buffer..writeln('【本地记忆】')..writeln(memories.join('\n'))..writeln();
    }
    if (compressedSummary.trim().isNotEmpty) {
      buffer..writeln('【早期对话压缩摘要】')..writeln(compressedSummary.trim())..writeln();
    }
    if (keywordHits.isNotEmpty) {
      buffer..writeln('【关键词检索命中的历史】')..writeln(_messagesAsTranscript(keywordHits))..writeln();
    }
    if (retrievedChunks.isNotEmpty) {
      buffer.writeln('【Eden AI + OpenAI ${AiAssistantEmbeddingService.embeddingModel} 语义检索命中的连续上下文】');
      for (var i = 0; i < retrievedChunks.length; i++) {
        buffer
          ..writeln('--- 语义上下文 ${i + 1} ---')
          ..writeln(retrievedChunks[i].chunkText.trim())
          ..writeln();
      }
    }
    return buffer.toString().trim();
  }

  String _messagesAsTranscript(
    List<AiAssistantMessage> messages, {
    bool compact = false,
    int maxContentLength = 420,
  }) {
    final buffer = StringBuffer();
    for (final message in messages.where(_isUsableContextMessage)) {
      final role = message.role == 'assistant' ? '助手' : '用户';
      final content = compact ? _compact(message.content, maxLength: maxContentLength) : message.content.trim();
      buffer.writeln('$role：$content');
    }
    return buffer.toString().trim();
  }

  bool _chunkOverlapsIds(AiAssistantContextChunk chunk, Set<int> ids) {
    if (ids.isEmpty) return false;
    try {
      final decoded = jsonDecode(chunk.sourceMessageIds);
      if (decoded is List) {
        for (final value in decoded) {
          final id = value is num ? value.toInt() : int.tryParse(value.toString());
          if (id != null && ids.contains(id)) return true;
        }
      }
    } catch (_) {}
    return false;
  }

  List<AiAssistantMessage> _takeLast(List<AiAssistantMessage> messages, int count) {
    if (messages.length <= count) return List<AiAssistantMessage>.from(messages);
    return messages.sublist(messages.length - count);
  }

  String _limitText(String value, int maxLength) {
    final text = value.trim();
    if (text.length <= maxLength) return text;
    if (maxLength <= 80) return text.substring(0, maxLength);
    const marker = '\n…（中间已省略）…\n';
    final headLength = ((maxLength - marker.length) * 0.55).floor().clamp(40, maxLength).toInt();
    final tailLength = (maxLength - marker.length - headLength).clamp(0, maxLength).toInt();
    final head = text.substring(0, headLength);
    final tail = tailLength <= 0 ? '' : text.substring(text.length - tailLength);
    return '$head$marker$tail';
  }

  String _compact(String value, {int maxLength = 420}) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxLength) return compact;
    return '${compact.substring(0, maxLength)}…';
  }

  List<UnifiedAiChatMessage> _deduplicateMessages(List<UnifiedAiChatMessage> messages) {
    final result = <UnifiedAiChatMessage>[];
    for (final message in messages) {
      final role = message.role.trim();
      final content = message.content.trim();
      final hasParts = message.parts.isNotEmpty;
      if (role.isEmpty || (content.isEmpty && !hasParts)) continue;
      String partSignatureOf(UnifiedAiContentPart part) =>
          '${part.type}:${part.imageUrl ?? part.text ?? part.fileId ?? part.fileData ?? part.fileName ?? ''}';
      final partSignature = message.parts.map(partSignatureOf).join('|');
      if (result.isNotEmpty &&
          result.last.role == role &&
          result.last.content == content &&
          result.last.parts.map(partSignatureOf).join('|') == partSignature) {
        continue;
      }
      result.add(UnifiedAiChatMessage(role: role, content: content, parts: message.parts));
    }
    return result;
  }
}

class _ScoredMessage {
  final AiAssistantMessage message;
  final int score;
  const _ScoredMessage(this.message, this.score);
}
