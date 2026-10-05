class AiAssistantContextMode {
  static const String fullHistory = 'full_history';
  static const String edenAiEmbedding = 'edenai_embedding';
  static const String openRouterEmbedding = 'openrouter_embedding'; // legacy value; normalized to Eden AI embedding.

  static const String defaultMode = fullHistory;

  static String normalize(String? value) {
    final v = (value ?? '').trim();
    if (v == edenAiEmbedding || v == openRouterEmbedding) return edenAiEmbedding;
    return fullHistory;
  }

  static String label(String mode) {
    switch (normalize(mode)) {
      case edenAiEmbedding:
        return 'Eden AI 语义上下文检索';
      case fullHistory:
      default:
        return '拼接全部历史';
    }
  }
}

class AiAssistantConversation {
  final int id;
  final String title;
  final String provider;
  final String model;
  final String contextMode;
  final int createdAtMs;
  final int updatedAtMs;
  final int messageCount;
  final String? providerConversationId;
  final String? providerPreviousResponseId;

  const AiAssistantConversation({
    required this.id,
    required this.title,
    required this.provider,
    required this.model,
    required this.contextMode,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.messageCount,
    this.providerConversationId,
    this.providerPreviousResponseId,
  });

  factory AiAssistantConversation.fromMap(Map<String, Object?> map) {
    return AiAssistantConversation(
      id: (map['id'] as num).toInt(),
      title: (map['title'] ?? '新会话').toString(),
      provider: (map['provider'] ?? '').toString(),
      model: (map['model'] ?? '').toString(),
      contextMode: AiAssistantContextMode.normalize(map['context_mode']?.toString()),
      createdAtMs: ((map['created_at_ms'] ?? 0) as num).toInt(),
      updatedAtMs: ((map['updated_at_ms'] ?? 0) as num).toInt(),
      messageCount: ((map['message_count'] ?? 0) as num).toInt(),
      providerConversationId: map['provider_conversation_id']?.toString(),
      providerPreviousResponseId: map['provider_previous_response_id']?.toString(),
    );
  }
}

class AiAssistantMessage {
  final int id;
  final int conversationId;
  final String role;
  final String content;
  final String provider;
  final String model;
  final int createdAtMs;
  final int? latencyMs;
  final String? error;
  final String? embeddingJson;
  final String? embeddingModel;
  final int? embeddingUpdatedAtMs;
  final int feedbackRating;
  final String? feedbackReason;
  final String? feedbackComment;
  final double contextWeight;
  final bool excludeFromContext;

  const AiAssistantMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.provider,
    required this.model,
    required this.createdAtMs,
    this.latencyMs,
    this.error,
    this.embeddingJson,
    this.embeddingModel,
    this.embeddingUpdatedAtMs,
    this.feedbackRating = 0,
    this.feedbackReason,
    this.feedbackComment,
    this.contextWeight = 0,
    this.excludeFromContext = false,
  });

  bool get hasEmbedding => (embeddingJson ?? '').trim().isNotEmpty;

  factory AiAssistantMessage.fromMap(Map<String, Object?> map) {
    return AiAssistantMessage(
      id: (map['id'] as num).toInt(),
      conversationId: (map['conversation_id'] as num).toInt(),
      role: (map['role'] ?? '').toString(),
      content: (map['content'] ?? '').toString(),
      provider: (map['provider'] ?? '').toString(),
      model: (map['model'] ?? '').toString(),
      createdAtMs: ((map['created_at_ms'] ?? 0) as num).toInt(),
      latencyMs: map['latency_ms'] == null ? null : (map['latency_ms'] as num).toInt(),
      error: map['error']?.toString(),
      embeddingJson: map['embedding_json']?.toString(),
      embeddingModel: map['embedding_model']?.toString(),
      embeddingUpdatedAtMs: map['embedding_updated_at_ms'] == null
          ? null
          : (map['embedding_updated_at_ms'] as num).toInt(),
      feedbackRating: ((map['feedback_rating'] ?? 0) as num).toInt(),
      feedbackReason: map['feedback_reason']?.toString(),
      feedbackComment: map['feedback_comment']?.toString(),
      contextWeight: ((map['context_weight'] ?? 0) as num).toDouble(),
      excludeFromContext: ((map['exclude_from_context'] ?? 0) as num).toInt() == 1,
    );
  }
}


class AiAssistantContextChunk {
  final int id;
  final int conversationId;
  final int startMessageId;
  final int endMessageId;
  final String sourceMessageIds;
  final String chunkText;
  final String contentHash;
  final String? embeddingJson;
  final String? embeddingModel;
  final int createdAtMs;
  final int updatedAtMs;
  final String chunkVersion;

  const AiAssistantContextChunk({
    required this.id,
    required this.conversationId,
    required this.startMessageId,
    required this.endMessageId,
    required this.sourceMessageIds,
    required this.chunkText,
    required this.contentHash,
    this.embeddingJson,
    this.embeddingModel,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.chunkVersion,
  });

  bool hasEmbeddingFor(String model) =>
      (embeddingJson ?? '').trim().isNotEmpty &&
      (embeddingModel ?? '').trim() == model;

  factory AiAssistantContextChunk.fromMap(Map<String, Object?> map) {
    return AiAssistantContextChunk(
      id: (map['id'] as num).toInt(),
      conversationId: (map['conversation_id'] as num).toInt(),
      startMessageId: ((map['start_message_id'] ?? 0) as num).toInt(),
      endMessageId: ((map['end_message_id'] ?? 0) as num).toInt(),
      sourceMessageIds: (map['source_message_ids'] ?? '').toString(),
      chunkText: (map['chunk_text'] ?? '').toString(),
      contentHash: (map['content_hash'] ?? '').toString(),
      embeddingJson: map['embedding_json']?.toString(),
      embeddingModel: map['embedding_model']?.toString(),
      createdAtMs: ((map['created_at_ms'] ?? 0) as num).toInt(),
      updatedAtMs: ((map['updated_at_ms'] ?? 0) as num).toInt(),
      chunkVersion: (map['chunk_version'] ?? '').toString(),
    );
  }
}


class AiAssistantFeedbackReason {
  static const String misunderstoodContext = 'misunderstood_context';
  static const String irrelevantHistory = 'irrelevant_history';
  static const String ignoredRelevantHistory = 'ignored_relevant_history';
  static const String inaccurate = 'inaccurate';
  static const String tooLong = 'too_long';
  static const String tooShort = 'too_short';
  static const String other = 'other';

  static String label(String? value) {
    switch ((value ?? '').trim()) {
      case misunderstoodContext:
        return '没有理解上下文';
      case irrelevantHistory:
        return '使用了无关历史';
      case ignoredRelevantHistory:
        return '忽略了相关历史';
      case inaccurate:
        return '回答不准确';
      case tooLong:
        return '回答太长';
      case tooShort:
        return '回答太短';
      case other:
        return '其他';
      default:
        return '';
    }
  }
}

class AiAssistantContextBlock {
  final String type;
  final String content;
  final List<int> sourceMessageIds;
  final String contentHash;
  final double score;
  final int priority;

  const AiAssistantContextBlock({
    required this.type,
    required this.content,
    required this.sourceMessageIds,
    required this.contentHash,
    required this.score,
    required this.priority,
  });
}


class AiAssistantAttachmentType {
  static const String image = 'image';
  static const String video = 'video';
  static const String file = 'file';

  static String normalize(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    if (v == image) return image;
    if (v == video) return video;
    return file;
  }
}

class AiAssistantAttachment {
  final int id;
  final int conversationId;
  final int messageId;
  final String attachmentType;
  final String name;
  final String path;
  final String? mimeType;
  final int sizeBytes;
  final String? extractedText;
  final String? provider;
  final String? providerFileId;
  final int? providerUploadedAtMs;
  final String? providerExpiresAt;
  final int createdAtMs;

  const AiAssistantAttachment({
    required this.id,
    required this.conversationId,
    required this.messageId,
    required this.attachmentType,
    required this.name,
    required this.path,
    this.mimeType,
    required this.sizeBytes,
    this.extractedText,
    this.provider,
    this.providerFileId,
    this.providerUploadedAtMs,
    this.providerExpiresAt,
    required this.createdAtMs,
  });

  bool get isImage => AiAssistantAttachmentType.normalize(attachmentType) == AiAssistantAttachmentType.image;
  bool get isVideo => AiAssistantAttachmentType.normalize(attachmentType) == AiAssistantAttachmentType.video;

  factory AiAssistantAttachment.fromMap(Map<String, Object?> map) {
    return AiAssistantAttachment(
      id: (map['id'] as num).toInt(),
      conversationId: (map['conversation_id'] as num).toInt(),
      messageId: (map['message_id'] as num).toInt(),
      attachmentType: AiAssistantAttachmentType.normalize(map['attachment_type']?.toString()),
      name: (map['name'] ?? 'attachment').toString(),
      path: (map['path'] ?? '').toString(),
      mimeType: map['mime_type']?.toString(),
      sizeBytes: ((map['size_bytes'] ?? 0) as num).toInt(),
      extractedText: map['extracted_text']?.toString(),
      provider: map['provider']?.toString(),
      providerFileId: map['provider_file_id']?.toString(),
      providerUploadedAtMs: map['provider_uploaded_at_ms'] == null ? null : (map['provider_uploaded_at_ms'] as num).toInt(),
      providerExpiresAt: map['provider_expires_at']?.toString(),
      createdAtMs: ((map['created_at_ms'] ?? 0) as num).toInt(),
    );
  }
}

class AiAssistantPendingAttachment {
  final String attachmentType;
  final String name;
  final String path;
  final String? mimeType;
  final int sizeBytes;

  const AiAssistantPendingAttachment({
    required this.attachmentType,
    required this.name,
    required this.path,
    this.mimeType,
    required this.sizeBytes,
  });

  bool get isImage => AiAssistantAttachmentType.normalize(attachmentType) == AiAssistantAttachmentType.image;
  bool get isVideo => AiAssistantAttachmentType.normalize(attachmentType) == AiAssistantAttachmentType.video;

  factory AiAssistantPendingAttachment.fromAttachment(AiAssistantAttachment attachment) {
    return AiAssistantPendingAttachment(
      attachmentType: attachment.attachmentType,
      name: attachment.name,
      path: attachment.path,
      mimeType: attachment.mimeType,
      sizeBytes: attachment.sizeBytes,
    );
  }
}

class AiAssistantBubblePosition {
  final String moduleKey;
  final double dx;
  final double dy;

  const AiAssistantBubblePosition({
    required this.moduleKey,
    required this.dx,
    required this.dy,
  });
}
