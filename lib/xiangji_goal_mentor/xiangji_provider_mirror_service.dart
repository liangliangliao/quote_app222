import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../services/unified_ai_service.dart';
import 'xiangji_dao.dart';
import 'xiangji_models.dart';

class XiangjiOpenAiConfig {
  const XiangjiOpenAiConfig({
    required this.apiKey,
    required this.model,
    required this.apiBase,
  });

  final String apiKey;
  final String model;
  final String apiBase;
}

typedef XiangjiOpenAiConfigResolver = Future<XiangjiOpenAiConfig> Function();

class XiangjiProviderMirrorService {
  XiangjiProviderMirrorService({
    XiangjiGoalMentorDao? dao,
    http.Client? client,
    XiangjiOpenAiConfigResolver? configResolver,
    Duration pollDelay = const Duration(milliseconds: 800),
    int pollAttempts = 8,
  })  : _dao = dao ?? XiangjiGoalMentorDao(),
        _client = client ?? http.Client(),
        _configResolver = configResolver ?? _resolveOpenAiConfig,
        _pollDelay = pollDelay,
        _pollAttempts = pollAttempts;

  static const String provider = 'openai';
  static const Duration _timeout = Duration(seconds: 45);

  final XiangjiGoalMentorDao _dao;
  final http.Client _client;
  final XiangjiOpenAiConfigResolver _configResolver;
  final Duration _pollDelay;
  final int _pollAttempts;

  Future<XiangjiProviderMirror> syncBook(
    XiangjiBookInfo book, {
    required int consentedAtMs,
  }) async {
    if (!book.isLocallySearchable) {
      throw StateError('书籍尚未完成本地解析，不能建立远端镜像。');
    }
    if (consentedAtMs <= 0) throw StateError('需要先确认远端上传授权。');
    final config = await _configResolver();
    final existing = await _dao.providerMirror(book.id, provider: provider);
    if (existing?.isReadyFor(book.contentHash) ?? false) return existing!;
    if (existing != null &&
        existing.syncedHash == book.contentHash &&
        existing.syncStatus == 'processing' &&
        existing.hasRemoteResources) {
      return refreshMirror(book, existing: existing);
    }
    if (existing?.hasRemoteResources ?? false) {
      final deleted = await deleteRemoteCopy(existing!);
      if (deleted.syncStatus != 'deleted') {
        throw StateError('旧远端镜像尚未删除，暂不能重新同步。');
      }
    }

    var fileId = '';
    var indexId = '';
    final now = DateTime.now().millisecondsSinceEpoch;
    var mirror = XiangjiProviderMirror(
      bookId: book.id,
      provider: provider,
      providerFileId: '',
      providerIndexId: '',
      syncedHash: book.contentHash,
      syncStatus: 'uploading',
      indexedStatus: 'pending',
      consentedAtMs: consentedAtMs,
      lastError: '',
      createdAtMs: existing?.createdAtMs ?? now,
      updatedAtMs: now,
    );
    mirror = await _dao.saveProviderMirror(mirror);
    await _dao.recordProviderEvent(
      bookId: book.id,
      provider: provider,
      action: 'sync',
      status: 'started',
      contentHash: book.contentHash,
    );

    Directory? temporaryDirectory;
    try {
      final chunks = await _dao.chunksForBooks(<String>[book.id]);
      if (chunks.isEmpty) throw StateError('本地索引为空，不能建立远端镜像。');
      temporaryDirectory = await Directory.systemTemp.createTemp('xiangji_mirror_');
      final mirrorFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}'
        'xiangji_${book.id}_${_shortHash(book.contentHash)}.txt',
      );
      await mirrorFile.writeAsString(
        _mirrorDocument(book, chunks),
        encoding: utf8,
        flush: true,
      );
      fileId = await _uploadFile(config, mirrorFile);
      indexId = await _createVectorStore(config, book);
      final attachment = await _postJson(
        _uri(
          config,
          '/vector_stores/${Uri.encodeComponent(indexId)}/files',
        ),
        config,
        <String, Object?>{
          'file_id': fileId,
          'attributes': <String, Object?>{
            'module': 'xiangji_goal_mentor',
            'book_id': book.id,
            'content_hash': book.contentHash,
          },
          'chunking_strategy': <String, Object?>{
            'type': 'static',
            'static': <String, Object?>{
              'max_chunk_size_tokens': 1200,
              'chunk_overlap_tokens': 200,
            },
          },
        },
        operation: '关联远端检索索引',
      );
      final attachmentStatus = (attachment['status'] ?? '').toString();
      mirror = await _dao.saveProviderMirror(
        mirror.copyWith(
          providerFileId: fileId,
          providerIndexId: indexId,
          syncStatus:
              attachmentStatus == 'completed' ? 'ready' : 'processing',
          indexedStatus:
              attachmentStatus == 'completed' ? 'ready' : 'processing',
          lastError: '',
        ),
      );
      if (mirror.syncStatus == 'processing') {
        mirror = await _pollUntilSettled(config, mirror);
      }
      await _dao.recordProviderEvent(
        bookId: book.id,
        provider: provider,
        action: 'sync',
        status: mirror.syncStatus,
        contentHash: book.contentHash,
        providerFileId: fileId,
        providerIndexId: indexId,
        errorSummary: mirror.lastError,
      );
      return mirror;
    } catch (error) {
      final failed = await _dao.saveProviderMirror(
        mirror.copyWith(
          providerFileId: fileId,
          providerIndexId: indexId,
          syncStatus: 'failed',
          indexedStatus: 'failed',
          lastError: _safeError(error),
        ),
      );
      await _dao.recordProviderEvent(
        bookId: book.id,
        provider: provider,
        action: 'sync',
        status: 'failed',
        contentHash: book.contentHash,
        providerFileId: fileId,
        providerIndexId: indexId,
        errorSummary: _safeError(error),
      );
      return failed;
    } finally {
      if (temporaryDirectory != null) {
        try {
          await temporaryDirectory.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<XiangjiProviderMirror> refreshMirror(
    XiangjiBookInfo book, {
    XiangjiProviderMirror? existing,
  }) async {
    final mirror = existing ??
        await _dao.providerMirror(book.id, provider: provider);
    if (mirror == null) throw StateError('没有可刷新的远端镜像。');
    if (mirror.isReadyFor(book.contentHash)) return mirror;
    if (mirror.providerFileId.isEmpty || mirror.providerIndexId.isEmpty) {
      return mirror;
    }
    final config = await _configResolver();
    return _pollUntilSettled(config, mirror);
  }

  Future<XiangjiProviderMirror> deleteRemoteCopy(
    XiangjiProviderMirror mirror,
  ) async {
    if (mirror.syncStatus == 'deleted') return mirror;
    final pending = await _dao.saveProviderMirror(
      mirror.copyWith(syncStatus: 'delete_pending', lastError: ''),
    );
    await _dao.recordProviderEvent(
      bookId: mirror.bookId,
      provider: provider,
      action: 'delete',
      status: 'started',
      contentHash: mirror.syncedHash,
      providerFileId: mirror.providerFileId,
      providerIndexId: mirror.providerIndexId,
    );
    try {
      final config = await _configResolver();
      if (pending.providerIndexId.isNotEmpty &&
          pending.providerFileId.isNotEmpty) {
        await _deleteIgnoringNotFound(
          _uri(
            config,
            '/vector_stores/${Uri.encodeComponent(pending.providerIndexId)}'
            '/files/${Uri.encodeComponent(pending.providerFileId)}',
          ),
          config,
        );
      }
      if (pending.providerFileId.isNotEmpty) {
        await _deleteIgnoringNotFound(
          _uri(config, '/files/${Uri.encodeComponent(pending.providerFileId)}'),
          config,
        );
      }
      if (pending.providerIndexId.isNotEmpty) {
        await _deleteIgnoringNotFound(
          _uri(
            config,
            '/vector_stores/${Uri.encodeComponent(pending.providerIndexId)}',
          ),
          config,
        );
      }
      final deleted = await _dao.saveProviderMirror(
        pending.copyWith(
          providerFileId: '',
          providerIndexId: '',
          syncStatus: 'deleted',
          indexedStatus: 'deleted',
          lastError: '',
        ),
      );
      await _dao.recordProviderEvent(
        bookId: mirror.bookId,
        provider: provider,
        action: 'delete',
        status: 'completed',
        contentHash: mirror.syncedHash,
        providerFileId: mirror.providerFileId,
        providerIndexId: mirror.providerIndexId,
      );
      return deleted;
    } catch (error) {
      final failed = await _dao.saveProviderMirror(
        pending.copyWith(
          syncStatus: 'delete_pending',
          lastError: _safeError(error),
        ),
      );
      await _dao.recordProviderEvent(
        bookId: mirror.bookId,
        provider: provider,
        action: 'delete',
        status: 'pending_retry',
        contentHash: mirror.syncedHash,
        providerFileId: mirror.providerFileId,
        providerIndexId: mirror.providerIndexId,
        errorSummary: _safeError(error),
      );
      return failed;
    }
  }

  Future<int> retryPendingDeletions() async {
    final pending = await _dao.pendingProviderDeletions();
    var completed = 0;
    for (final mirror in pending) {
      final result = await deleteRemoteCopy(mirror);
      if (result.syncStatus == 'deleted') completed += 1;
    }
    return completed;
  }

  Future<List<String>> searchSourceIds({
    required XiangjiBookInfo book,
    required String query,
    int limit = 8,
  }) async {
    final mirror = await _dao.providerMirror(book.id, provider: provider);
    if (!(mirror?.isReadyFor(book.contentHash) ?? false)) {
      throw StateError('远端镜像未就绪或内容哈希不一致。');
    }
    final config = await _configResolver();
    try {
      final response = await _postJson(
        _uri(
          config,
          '/vector_stores/${Uri.encodeComponent(mirror!.providerIndexId)}/search',
        ),
        config,
        <String, Object?>{
          'query': query,
          'max_num_results': limit,
        },
        operation: '检索远端书籍镜像',
      );
      final resultTexts = <String>[];
      final data = response['data'];
      if (data is List) {
        for (final result in data) {
          if (result is! Map) continue;
          final content = result['content'];
          if (content is! List) continue;
          for (final block in content) {
            if (block is! Map) continue;
            final text = (block['text'] ?? '').toString();
            if (text.isNotEmpty) resultTexts.add(text);
          }
        }
      }
      final sourceIds = <String>{};
      final marker = RegExp(r'\[\[SOURCE_ID:([^\]]+)\]\]');
      for (final text in resultTexts) {
        for (final match in marker.allMatches(text)) {
          final id = (match.group(1) ?? '').trim();
          if (id.isNotEmpty) sourceIds.add(id);
        }
      }
      final allChunks = await _dao.chunksForBooks(<String>[book.id]);
      final allowedIds = allChunks.map((chunk) => chunk.id).toSet();
      sourceIds.removeWhere((id) => !allowedIds.contains(id));
      if (sourceIds.isEmpty && resultTexts.isNotEmpty) {
        final normalizedResults = _normalize(resultTexts.join('\n'));
        for (final chunk in allChunks) {
          final normalizedChunk = _normalize(chunk.text);
          if (normalizedChunk.length < 48) continue;
          final probe = normalizedChunk.substring(0, 48);
          if (normalizedResults.contains(probe)) sourceIds.add(chunk.id);
          if (sourceIds.length >= limit) break;
        }
      }
      await _dao.recordProviderEvent(
        bookId: book.id,
        provider: provider,
        action: 'search',
        status: sourceIds.isEmpty ? 'coverage_insufficient' : 'completed',
        contentHash: book.contentHash,
        providerFileId: mirror.providerFileId,
        providerIndexId: mirror.providerIndexId,
      );
      return sourceIds.take(limit).toList(growable: false);
    } catch (error) {
      await _dao.recordProviderEvent(
        bookId: book.id,
        provider: provider,
        action: 'search',
        status: 'failed',
        contentHash: book.contentHash,
        providerFileId: mirror!.providerFileId,
        providerIndexId: mirror.providerIndexId,
        errorSummary: _safeError(error),
      );
      rethrow;
    }
  }

  Future<XiangjiProviderMirror> _pollUntilSettled(
    XiangjiOpenAiConfig config,
    XiangjiProviderMirror mirror,
  ) async {
    var current = mirror;
    final attempts = _pollAttempts < 1 ? 1 : _pollAttempts;
    for (var attempt = 0; attempt < attempts; attempt++) {
      final response = await _getJson(
        _uri(
          config,
          '/vector_stores/${Uri.encodeComponent(current.providerIndexId)}'
          '/files/${Uri.encodeComponent(current.providerFileId)}',
        ),
        config,
        operation: '查询远端索引状态',
      );
      final status = (response['status'] ?? '').toString();
      if (status == 'completed') {
        return _dao.saveProviderMirror(
          current.copyWith(
            syncStatus: 'ready',
            indexedStatus: 'ready',
            lastError: '',
          ),
        );
      }
      if (status == 'failed' || status == 'cancelled') {
        final error = response['last_error'];
        return _dao.saveProviderMirror(
          current.copyWith(
            syncStatus: 'failed',
            indexedStatus: 'failed',
            lastError: _safeError(error ?? '远端索引失败。'),
          ),
        );
      }
      current = await _dao.saveProviderMirror(
        current.copyWith(syncStatus: 'processing', indexedStatus: 'processing'),
      );
      if (attempt + 1 < attempts && _pollDelay > Duration.zero) {
        await Future<void>.delayed(_pollDelay);
      }
    }
    return current;
  }

  Future<String> _uploadFile(
    XiangjiOpenAiConfig config,
    File file,
  ) async {
    final request = http.MultipartRequest('POST', _uri(config, '/files'))
      ..headers.addAll(_headers(config))
      ..fields['purpose'] = 'assistants'
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: file.uri.pathSegments.last,
        ),
      );
    final streamed = await _client.send(request).timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    final payload = _jsonObject(response, operation: '上传远端书籍镜像');
    final id = (payload['id'] ?? '').toString();
    if (id.isEmpty) throw const FormatException('OpenAI 没有返回文件ID。');
    return id;
  }

  Future<String> _createVectorStore(
    XiangjiOpenAiConfig config,
    XiangjiBookInfo book,
  ) async {
    final response = await _postJson(
      _uri(config, '/vector_stores'),
      config,
      <String, Object?>{
        'name': 'xiangji_${book.id}_${_shortHash(book.contentHash)}',
        'metadata': <String, String>{
          'module': 'xiangji_goal_mentor',
          'book_id': book.id,
          'content_hash': book.contentHash,
        },
      },
      operation: '创建远端检索索引',
    );
    final id = (response['id'] ?? '').toString();
    if (id.isEmpty) throw const FormatException('OpenAI 没有返回向量库ID。');
    return id;
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    XiangjiOpenAiConfig config,
    Map<String, Object?> body, {
    required String operation,
  }) async {
    final response = await _client
        .post(
          uri,
          headers: <String, String>{
            ..._headers(config),
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _jsonObject(response, operation: operation);
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri,
    XiangjiOpenAiConfig config, {
    required String operation,
  }) async {
    final response = await _client
        .get(uri, headers: _headers(config))
        .timeout(_timeout);
    return _jsonObject(response, operation: operation);
  }

  Future<void> _deleteIgnoringNotFound(
    Uri uri,
    XiangjiOpenAiConfig config,
  ) async {
    final response = await _client
        .delete(uri, headers: _headers(config))
        .timeout(_timeout);
    if (response.statusCode == 404) return;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('删除远端副本失败（HTTP ${response.statusCode}）。');
    }
  }

  static Map<String, dynamic> _jsonObject(
    http.Response response, {
    required String operation,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('$operation失败（HTTP ${response.statusCode}）。');
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    throw FormatException('$operation没有返回有效JSON。');
  }

  static Map<String, String> _headers(XiangjiOpenAiConfig config) =>
      <String, String>{'Authorization': 'Bearer ${config.apiKey.trim()}'};

  static Uri _uri(XiangjiOpenAiConfig config, String suffix) {
    final base = config.apiBase.endsWith('/')
        ? config.apiBase.substring(0, config.apiBase.length - 1)
        : config.apiBase;
    return Uri.parse('$base$suffix');
  }

  static String _mirrorDocument(
    XiangjiBookInfo book,
    List<XiangjiBookChunk> chunks,
  ) {
    final buffer = StringBuffer()
      ..writeln('XIANGJI_CONTROLLED_BOOK_MIRROR_V1')
      ..writeln('BOOK_ID: ${book.id}')
      ..writeln('TITLE: ${book.title}')
      ..writeln('CONTENT_HASH: ${book.contentHash}')
      ..writeln();
    for (final chunk in chunks) {
      buffer
        ..writeln('[[SOURCE_ID:${chunk.id}]]')
        ..writeln('[[BOOK_ID:${chunk.bookId}]]')
        ..writeln('[[LOCATOR:${chunk.locator}]]')
        ..writeln(chunk.text)
        ..writeln('[[END_SOURCE]]')
        ..writeln();
    }
    return buffer.toString();
  }

  static Future<XiangjiOpenAiConfig> _resolveOpenAiConfig() async {
    final resolved = await UnifiedAiService().resolveGlobalConfig(
      forcedProvider: 'openai',
    );
    if (!resolved.available || resolved.apiKey.trim().isEmpty) {
      throw StateError('请先在全局 AI 设置中配置 OpenAI API Key。');
    }
    final endpoint = Uri.tryParse(resolved.endpoint);
    if (endpoint == null || endpoint.host != 'api.openai.com') {
      throw StateError('首发远端书库只允许 OpenAI 官方 API 端点。');
    }
    var path = endpoint.path;
    for (final suffix in const <String>['/responses', '/chat/completions']) {
      if (path.endsWith(suffix)) {
        path = path.substring(0, path.length - suffix.length);
      }
    }
    if (path.isEmpty) path = '/v1';
    final apiBase = Uri(
      scheme: endpoint.scheme,
      host: endpoint.host,
      port: endpoint.hasPort ? endpoint.port : null,
      path: path,
    ).toString();
    return XiangjiOpenAiConfig(
      apiKey: resolved.apiKey,
      model: resolved.model,
      apiBase: apiBase,
    );
  }

  static String _safeError(Object error) {
    final raw = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return raw.length <= 220 ? raw : '${raw.substring(0, 217)}...';
  }

  static String _normalize(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  static String _shortHash(String value) =>
      value.length <= 12 ? value : value.substring(0, 12);
}
