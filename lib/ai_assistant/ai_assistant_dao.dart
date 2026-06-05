import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'ai_assistant_models.dart';

class AiAssistantDao {
  Future<Database> get _db async => AppDatabase.instance();

  Future<void> ensureTables() async {
    final db = await _db;
    await AppDatabase.ensureAiAssistantTables(db);
  }

  Future<int> createConversation({
    String? title,
    String provider = '',
    String model = '',
    String contextMode = AiAssistantContextMode.defaultMode,
  }) async {
    await ensureTables();
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert('ai_assistant_conversations', <String, Object?>{
      'title': (title == null || title.trim().isEmpty) ? '新会话' : title.trim(),
      'provider': provider,
      'model': model,
      'context_mode': AiAssistantContextMode.normalize(contextMode),
      'created_at_ms': now,
      'updated_at_ms': now,
      'message_count': 0,
    });
  }

  Future<void> touchConversation(
    int conversationId, {
    String? provider,
    String? model,
    String? title,
  }) async {
    await ensureTables();
    final db = await _db;
    final values = <String, Object?>{
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
    };
    if (provider != null) values['provider'] = provider;
    if (model != null) values['model'] = model;
    if (title != null && title.trim().isNotEmpty) values['title'] = title.trim();
    await db.update(
      'ai_assistant_conversations',
      values,
      where: 'id = ? AND deleted_at_ms IS NULL',
      whereArgs: <Object?>[conversationId],
    );
  }

  Future<void> updateContextMode(int conversationId, String contextMode) async {
    await ensureTables();
    final db = await _db;
    await db.update(
      'ai_assistant_conversations',
      <String, Object?>{
        'context_mode': AiAssistantContextMode.normalize(contextMode),
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND deleted_at_ms IS NULL',
      whereArgs: <Object?>[conversationId],
    );
  }

  Future<List<AiAssistantConversation>> listConversations({int limit = 100}) async {
    await ensureTables();
    final db = await _db;
    final rows = await db.query(
      'ai_assistant_conversations',
      where: 'deleted_at_ms IS NULL',
      orderBy: 'updated_at_ms DESC, id DESC',
      limit: limit,
    );
    return rows.map(AiAssistantConversation.fromMap).toList();
  }

  Future<AiAssistantConversation?> getConversation(int conversationId) async {
    await ensureTables();
    final db = await _db;
    final rows = await db.query(
      'ai_assistant_conversations',
      where: 'id = ? AND deleted_at_ms IS NULL',
      whereArgs: <Object?>[conversationId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AiAssistantConversation.fromMap(rows.first);
  }

  Future<void> deleteConversation(int conversationId) async {
    await ensureTables();
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'ai_assistant_conversations',
      <String, Object?>{'deleted_at_ms': now, 'updated_at_ms': now},
      where: 'id = ?',
      whereArgs: <Object?>[conversationId],
    );
  }

  Future<void> deleteAllConversations() async {
    await ensureTables();
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'ai_assistant_conversations',
      <String, Object?>{'deleted_at_ms': now, 'updated_at_ms': now},
      where: 'deleted_at_ms IS NULL',
    );
  }

  Future<int> insertMessage({
    required int conversationId,
    required String role,
    required String content,
    String provider = '',
    String model = '',
    int? latencyMs,
    String? error,
  }) async {
    await ensureTables();
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('ai_assistant_messages', <String, Object?>{
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'provider': provider,
      'model': model,
      'created_at_ms': now,
      'latency_ms': latencyMs,
      'error': error,
    });
    await db.rawUpdate(
      '''
      UPDATE ai_assistant_conversations
      SET updated_at_ms = ?,
          provider = CASE WHEN ? != '' THEN ? ELSE provider END,
          model = CASE WHEN ? != '' THEN ? ELSE model END,
          message_count = (
            SELECT COUNT(*) FROM ai_assistant_messages WHERE conversation_id = ?
          )
      WHERE id = ? AND deleted_at_ms IS NULL
      ''',
      <Object?>[now, provider, provider, model, model, conversationId, conversationId],
    );
    return id;
  }

  Future<void> updateMessageEmbedding({
    required int messageId,
    required List<double> embedding,
    required String embeddingModel,
  }) async {
    await ensureTables();
    final db = await _db;
    await db.update(
      'ai_assistant_messages',
      <String, Object?>{
        'embedding_json': jsonEncode(embedding),
        'embedding_model': embeddingModel,
        'embedding_updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[messageId],
    );
  }

  Future<List<AiAssistantMessage>> listMessages(int conversationId) async {
    await ensureTables();
    final db = await _db;
    final rows = await db.query(
      'ai_assistant_messages',
      where: 'conversation_id = ?',
      whereArgs: <Object?>[conversationId],
      orderBy: 'created_at_ms ASC, id ASC',
    );
    return rows.map(AiAssistantMessage.fromMap).toList();
  }



  Future<void> insertAttachments({
    required int conversationId,
    required int messageId,
    required List<AiAssistantAttachment> attachments,
  }) async {
    if (attachments.isEmpty) return;
    await ensureTables();
    final db = await _db;
    final batch = db.batch();
    for (final attachment in attachments) {
      batch.insert('ai_assistant_attachments', <String, Object?>{
        'conversation_id': conversationId,
        'message_id': messageId,
        'attachment_type': AiAssistantAttachmentType.normalize(attachment.attachmentType),
        'name': attachment.name,
        'path': attachment.path,
        'mime_type': attachment.mimeType,
        'size_bytes': attachment.sizeBytes,
        'extracted_text': attachment.extractedText,
        'provider': attachment.provider,
        'provider_file_id': attachment.providerFileId,
        'provider_uploaded_at_ms': attachment.providerUploadedAtMs,
        'provider_expires_at': attachment.providerExpiresAt,
        'created_at_ms': attachment.createdAtMs,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<AiAssistantAttachment>> listAttachmentsForConversation(int conversationId) async {
    await ensureTables();
    final db = await _db;
    final rows = await db.query(
      'ai_assistant_attachments',
      where: 'conversation_id = ?',
      whereArgs: <Object?>[conversationId],
      orderBy: 'message_id ASC, id ASC',
    );
    return rows.map(AiAssistantAttachment.fromMap).toList();
  }

  Future<List<AiAssistantAttachment>> listAttachmentsForMessage(int messageId) async {
    await ensureTables();
    final db = await _db;
    final rows = await db.query(
      'ai_assistant_attachments',
      where: 'message_id = ?',
      whereArgs: <Object?>[messageId],
      orderBy: 'id ASC',
    );
    return rows.map(AiAssistantAttachment.fromMap).toList();
  }

  Future<void> updateAttachmentProviderFile({
    required int attachmentId,
    required String provider,
    required String providerFileId,
    String? providerExpiresAt,
  }) async {
    await ensureTables();
    final db = await _db;
    await db.update(
      'ai_assistant_attachments',
      <String, Object?>{
        'provider': provider,
        'provider_file_id': providerFileId,
        'provider_uploaded_at_ms': DateTime.now().millisecondsSinceEpoch,
        'provider_expires_at': providerExpiresAt,
      },
      where: 'id = ?',
      whereArgs: <Object?>[attachmentId],
    );
  }

  Future<void> deleteMessagesFrom(int conversationId, int firstMessageId) async {
    await ensureTables();
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'ai_assistant_attachments',
        where: 'conversation_id = ? AND message_id >= ?',
        whereArgs: <Object?>[conversationId, firstMessageId],
      );
      await txn.delete(
        'ai_assistant_message_feedback_events',
        where: 'conversation_id = ? AND message_id >= ?',
        whereArgs: <Object?>[conversationId, firstMessageId],
      );
      await txn.delete(
        'ai_assistant_messages',
        where: 'conversation_id = ? AND id >= ?',
        whereArgs: <Object?>[conversationId, firstMessageId],
      );
      await txn.delete(
        'ai_assistant_context_chunks',
        where: 'conversation_id = ?',
        whereArgs: <Object?>[conversationId],
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.rawUpdate(
        '''
        UPDATE ai_assistant_conversations
        SET updated_at_ms = ?,
            message_count = (
              SELECT COUNT(*) FROM ai_assistant_messages WHERE conversation_id = ?
            )
        WHERE id = ? AND deleted_at_ms IS NULL
        ''',
        <Object?>[now, conversationId, conversationId],
      );
    });
  }

  Future<void> setMessageFeedback({
    required int conversationId,
    required int messageId,
    required int rating,
    String? reason,
    String? comment,
  }) async {
    await ensureTables();
    final db = await _db;
    final normalizedRating = rating > 0 ? 1 : (rating < 0 ? -1 : 0);
    final cleanReason = (reason ?? '').trim();
    final cleanComment = (comment ?? '').trim();
    final contextWeight = normalizedRating > 0
        ? 1.0
        : normalizedRating < 0
            ? -1.0
            : 0.0;
    final exclude = normalizedRating < 0 &&
            (cleanReason == AiAssistantFeedbackReason.irrelevantHistory ||
                cleanReason == AiAssistantFeedbackReason.inaccurate ||
                cleanReason == AiAssistantFeedbackReason.misunderstoodContext)
        ? 1
        : 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'ai_assistant_messages',
      <String, Object?>{
        'feedback_rating': normalizedRating,
        'feedback_reason': cleanReason.isEmpty ? null : cleanReason,
        'feedback_comment': cleanComment.isEmpty ? null : cleanComment,
        'context_weight': contextWeight,
        'exclude_from_context': exclude,
      },
      where: 'id = ? AND conversation_id = ?',
      whereArgs: <Object?>[messageId, conversationId],
    );
    await db.insert('ai_assistant_message_feedback_events', <String, Object?>{
      'conversation_id': conversationId,
      'message_id': messageId,
      'rating': normalizedRating,
      'reason': cleanReason.isEmpty ? null : cleanReason,
      'comment': cleanComment.isEmpty ? null : cleanComment,
      'created_at_ms': now,
    });
  }

  Future<int> upsertContextChunk({
    required int conversationId,
    required int startMessageId,
    required int endMessageId,
    required String sourceMessageIds,
    required String chunkText,
    required String contentHash,
    required int startCreatedAtMs,
    required int endCreatedAtMs,
    required String chunkVersion,
  }) async {
    await ensureTables();
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query(
      'ai_assistant_context_chunks',
      columns: <String>['id', 'chunk_text'],
      where: 'conversation_id = ? AND chunk_version = ? AND content_hash = ?',
      whereArgs: <Object?>[conversationId, chunkVersion, contentHash],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final id = (existing.first['id'] as num).toInt();
      // Content hash is stable, but keep metadata fresh in case chunking logic changed.
      await db.update(
        'ai_assistant_context_chunks',
        <String, Object?>{
          'start_message_id': startMessageId,
          'end_message_id': endMessageId,
          'source_message_ids': sourceMessageIds,
          'chunk_text': chunkText,
          'start_created_at_ms': startCreatedAtMs,
          'end_created_at_ms': endCreatedAtMs,
          'chunk_version': chunkVersion,
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      return id;
    }
    return db.insert('ai_assistant_context_chunks', <String, Object?>{
      'conversation_id': conversationId,
      'start_message_id': startMessageId,
      'end_message_id': endMessageId,
      'source_message_ids': sourceMessageIds,
      'chunk_text': chunkText,
      'content_hash': contentHash,
      'embedding_json': null,
      'embedding_model': null,
      'created_at_ms': now,
      'updated_at_ms': now,
      'start_created_at_ms': startCreatedAtMs,
      'end_created_at_ms': endCreatedAtMs,
      'chunk_version': chunkVersion,
    });
  }

  Future<void> updateContextChunkEmbedding({
    required int chunkId,
    required List<double> embedding,
    required String embeddingModel,
  }) async {
    await ensureTables();
    final db = await _db;
    await db.update(
      'ai_assistant_context_chunks',
      <String, Object?>{
        'embedding_json': jsonEncode(embedding),
        'embedding_model': embeddingModel,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[chunkId],
    );
  }

  Future<List<AiAssistantContextChunk>> listContextChunks({
    required int conversationId,
    int? beforeMessageId,
    String? chunkVersion,
  }) async {
    await ensureTables();
    final db = await _db;
    final whereParts = <String>['conversation_id = ?'];
    final args = <Object?>[conversationId];
    if (beforeMessageId != null) {
      whereParts.add('end_message_id < ?');
      args.add(beforeMessageId);
    }
    if (chunkVersion != null && chunkVersion.trim().isNotEmpty) {
      whereParts.add('chunk_version = ?');
      args.add(chunkVersion.trim());
    }
    final rows = await db.query(
      'ai_assistant_context_chunks',
      where: whereParts.join(' AND '),
      whereArgs: args,
      orderBy: 'start_created_at_ms ASC, start_message_id ASC, id ASC',
    );
    return rows.map(AiAssistantContextChunk.fromMap).toList();
  }


  Future<void> upsertMemory({
    required int conversationId,
    required String memoryKey,
    required String memoryValue,
  }) async {
    await ensureTables();
    final key = memoryKey.trim();
    final value = memoryValue.trim();
    if (key.isEmpty || value.isEmpty) return;
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'ai_assistant_memories',
      <String, Object?>{
        'conversation_id': conversationId,
        'memory_key': key,
        'memory_value': value,
        'created_at_ms': now,
        'updated_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> listMemories(int conversationId, {int limit = 20}) async {
    await ensureTables();
    final db = await _db;
    return db.query(
      'ai_assistant_memories',
      where: 'conversation_id = ?',
      whereArgs: <Object?>[conversationId],
      orderBy: 'updated_at_ms DESC, id DESC',
      limit: limit,
    );
  }

  Future<Map<String, Object?>?> getLatestSummary(int conversationId) async {
    await ensureTables();
    final db = await _db;
    final rows = await db.query(
      'ai_assistant_summaries',
      where: 'conversation_id = ?',
      whereArgs: <Object?>[conversationId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> upsertSummary({
    required int conversationId,
    required String summary,
    required int coveredMessageIdUntil,
  }) async {
    await ensureTables();
    final value = summary.trim();
    if (value.isEmpty) return;
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'ai_assistant_summaries',
      <String, Object?>{
        'conversation_id': conversationId,
        'summary': value,
        'covered_message_id_until': coveredMessageIdUntil,
        'created_at_ms': now,
        'updated_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateProviderConversationState({
    required int conversationId,
    String? providerConversationId,
    String? providerPreviousResponseId,
  }) async {
    await ensureTables();
    final db = await _db;
    final values = <String, Object?>{
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
    };
    if (providerConversationId != null) values['provider_conversation_id'] = providerConversationId;
    if (providerPreviousResponseId != null) values['provider_previous_response_id'] = providerPreviousResponseId;
    if (values.length <= 1) return;
    await db.update(
      'ai_assistant_conversations',
      values,
      where: 'id = ? AND deleted_at_ms IS NULL',
      whereArgs: <Object?>[conversationId],
    );
  }

  Future<void> renameConversation(int conversationId, String title) async {
    await touchConversation(conversationId, title: title);
  }

  Future<void> maybeSetAutoTitle(int conversationId, String firstUserMessage) async {
    final conversation = await getConversation(conversationId);
    if (conversation == null) return;
    if (conversation.title.trim().isNotEmpty && conversation.title != '新会话') return;
    final compact = firstUserMessage.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) return;
    final title = compact.length > 18 ? '${compact.substring(0, 18)}…' : compact;
    await renameConversation(conversationId, title);
  }

  Future<AiAssistantBubblePosition?> getBubblePosition(String moduleKey) async {
    await ensureTables();
    final db = await _db;
    final rows = await db.query(
      'ai_assistant_ui_state',
      where: 'module_key = ?',
      whereArgs: <Object?>[moduleKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return AiAssistantBubblePosition(
      moduleKey: moduleKey,
      dx: ((row['bubble_dx'] ?? 0) as num).toDouble(),
      dy: ((row['bubble_dy'] ?? 0) as num).toDouble(),
    );
  }

  Future<void> saveBubblePosition(String moduleKey, double dx, double dy) async {
    await ensureTables();
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'ai_assistant_ui_state',
      <String, Object?>{
        'module_key': moduleKey,
        'bubble_dx': dx,
        'bubble_dy': dy,
        'updated_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
