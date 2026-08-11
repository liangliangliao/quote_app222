import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_book_index_service.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database database;
  late XiangjiGoalMentorDao dao;
  late Directory directory;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = XiangjiGoalMentorDao(database: database);
    directory = await Directory.systemTemp.createTemp('xiangji_index_test_');
  });

  tearDown(() async {
    await database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('parses, chunks and retrieves only from the allowed private book',
      () async {
    final file = File('${directory.path}/book.md');
    await file.writeAsString('''
# 自主目标
自主选择不是忽视责任，而是理解自己为什么愿意承担这件事。外部期待可以被听见，但不应直接替代自己的判断。

# 最小行动
当目标过大时，先选择一个今天可以控制的最小动作，并根据真实反馈调整方法。
''');
    final bookId = await dao.saveImportedBook(
      title: '测试书.md',
      localPath: file.path,
      contentHash: 'hash-book-1',
      mimeType: 'text/markdown',
      sizeBytes: await file.length(),
    );
    final index = XiangjiBookIndexService(dao: dao);
    final result = await index.indexFile(
      file: file,
      filename: '测试书.md',
      bookId: bookId,
      bookTitle: '测试书',
    );
    await dao.replaceBookChunks(
      bookId: bookId,
      chunks: result.chunks,
      parsedCharacters: result.parsedCharacters,
      partial: result.partial,
    );

    final matches = await index.retrieve(
      query: '怎样区分自己的选择和外部期待？',
      allowedBookIds: <String>['local_$bookId'],
    );

    expect(result.partial, isFalse);
    expect(result.chunks, isNotEmpty);
    expect(matches, isNotEmpty);
    expect(matches.first.bookId, 'local_$bookId');
    expect(matches.first.locator, contains('自主目标'));
    expect(matches.first.text, contains('外部期待'));
    expect(
      await index.retrieve(
        query: '外部期待',
        allowedBookIds: const <String>['local_999'],
      ),
      isEmpty,
    );

    await dao.markImportedBookDeleted('local_$bookId');
    expect(
      await index.retrieve(
        query: '外部期待',
        allowedBookIds: <String>['local_$bookId'],
      ),
      isEmpty,
    );
  });
}
