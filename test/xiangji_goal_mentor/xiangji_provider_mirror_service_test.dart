import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_dao.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_models.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_provider_mirror_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database database;
  late XiangjiGoalMentorDao dao;
  late XiangjiBookInfo book;
  late String chunkId;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = XiangjiGoalMentorDao(database: database);
    final id = await dao.saveImportedBook(
      title: '远端镜像测试书',
      localPath: '/private/remote.txt',
      contentHash: '1234567890abcdef',
      mimeType: 'text/plain',
      sizeBytes: 100,
    );
    chunkId = 'xj_${id}_00000';
    await dao.replaceBookChunks(
      bookId: id,
      parsedCharacters: 100,
      partial: false,
      chunks: <XiangjiBookChunk>[
        XiangjiBookChunk(
          id: chunkId,
          bookId: 'local_$id',
          bookTitle: '远端镜像测试书',
          chunkIndex: 0,
          sectionTitle: '第一章',
          locator: '第一章 · 字符 1–100',
          text: '远端检索只能返回当前书籍范围内的来源标识和片段。',
          contentHash: 'chunk-remote-hash',
        ),
      ],
    );
    book = (await dao.importedBookById('local_$id'))!;
  });

  tearDown(() => database.close());

  test('sync is hash-idempotent, remote search is scoped, and delete propagates',
      () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.method == 'POST' && request.url.path == '/v1/files') {
        return http.Response('{"id":"file_test"}', 200);
      }
      if (request.method == 'POST' &&
          request.url.path == '/v1/vector_stores') {
        return http.Response('{"id":"vs_test"}', 200);
      }
      if (request.method == 'POST' &&
          request.url.path == '/v1/vector_stores/vs_test/files') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['file_id'], 'file_test');
        expect(
          (body['attributes'] as Map<String, dynamic>)['content_hash'],
          book.contentHash,
        );
        return http.Response('{"status":"completed"}', 200);
      }
      if (request.method == 'POST' &&
          request.url.path == '/v1/vector_stores/vs_test/search') {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode(<String, Object?>{
              'data': <Object?>[
                <String, Object?>{
                  'content': <Object?>[
                    <String, Object?>{
                      'type': 'text',
                      'text':
                          '[[SOURCE_ID:$chunkId]]\n远端检索只能返回当前书籍范围内的来源标识和片段。',
                    },
                  ],
                },
              ],
            }),
          ),
          200,
          headers: const <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }
      if (request.method == 'DELETE') return http.Response('{}', 200);
      return http.Response('{}', 404);
    });
    final service = XiangjiProviderMirrorService(
      dao: dao,
      client: client,
      configResolver: _config,
      pollDelay: Duration.zero,
      pollAttempts: 1,
    );

    final first = await service.syncBook(book, consentedAtMs: 1234);
    final second = await service.syncBook(book, consentedAtMs: 5678);

    expect(first.syncStatus, 'ready');
    expect(first.syncedHash, book.contentHash);
    expect(second.providerFileId, 'file_test');
    expect(calls.where((call) => call == 'POST /v1/files'), hasLength(1));

    final sourceIds = await service.searchSourceIds(
      book: (await dao.importedBookById(book.id))!,
      query: '当前书籍范围',
    );
    expect(sourceIds, <String>[chunkId]);

    final deleted = await service.deleteRemoteCopy(second);
    expect(deleted.syncStatus, 'deleted');
    expect(deleted.providerFileId, isEmpty);
    expect(deleted.providerIndexId, isEmpty);
    expect(calls, containsAll(<String>[
      'DELETE /v1/vector_stores/vs_test/files/file_test',
      'DELETE /v1/files/file_test',
      'DELETE /v1/vector_stores/vs_test',
    ]));
    expect(await dao.pendingProviderDeletions(), isEmpty);
  });

  test('failed provider deletion remains pending and auditable', () async {
    final mirror = await dao.saveProviderMirror(
      XiangjiProviderMirror(
        bookId: book.id,
        provider: 'openai',
        providerFileId: 'file_pending',
        providerIndexId: 'vs_pending',
        syncedHash: book.contentHash,
        syncStatus: 'ready',
        indexedStatus: 'ready',
        consentedAtMs: 1234,
        lastError: '',
        createdAtMs: 1234,
        updatedAtMs: 1234,
      ),
    );
    final service = XiangjiProviderMirrorService(
      dao: dao,
      configResolver: _config,
      client: MockClient((request) async => http.Response('{}', 500)),
      pollDelay: Duration.zero,
      pollAttempts: 1,
    );

    final result = await service.deleteRemoteCopy(mirror);

    expect(result.syncStatus, 'delete_pending');
    expect(result.lastError, contains('HTTP 500'));
    expect(await dao.pendingProviderDeletions(), hasLength(1));
    final events = await database.query(
      'xiangji_provider_events',
      where: "action = 'delete'",
      orderBy: 'id',
    );
    expect(events.map((row) => row['status']), <Object?>['started', 'pending_retry']);
    expect(events.last['error_summary'], isNotEmpty);
  });
}

Future<XiangjiOpenAiConfig> _config() async => const XiangjiOpenAiConfig(
      apiKey: 'test-key',
      model: 'gpt-test',
      apiBase: 'https://api.openai.com/v1',
    );
