import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quote_app/xiangji_goal_mentor/xiangji_book_service.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('clear-all removes registered books, orphan files and prior exports',
      () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(database.close);
    final root = await Directory.systemTemp.createTemp('xiangji_delete_test_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final privateDirectory = Directory(
      p.join(root.path, 'xiangji_private_books'),
    );
    await privateDirectory.create();
    final registered = File(p.join(privateDirectory.path, 'registered.pdf'));
    final orphan = File(p.join(privateDirectory.path, 'orphan.epub'));
    await registered.writeAsString('registered');
    await orphan.writeAsString('orphan');
    final oldExport = File(p.join(root.path, 'xiangji_export_1.json'));
    final newerExport = File(p.join(root.path, 'xiangji_export_2.json'));
    final unrelated = File(p.join(root.path, 'keep.json'));
    await oldExport.writeAsString('{}');
    await newerExport.writeAsString('{}');
    await unrelated.writeAsString('{}');

    final dao = XiangjiGoalMentorDao(database: database);
    await dao.saveImportedBook(
      title: 'registered.pdf',
      localPath: registered.path,
      contentHash: 'hash',
    );
    final service = XiangjiBookService(
      dao: dao,
      documentsDirectory: () async => root,
    );

    await service.deleteAllPrivateBooks();
    final deletedExports = await service.deleteGeneratedExports();

    expect(await privateDirectory.exists(), isFalse);
    expect(await dao.importedBooks(), isEmpty);
    expect(deletedExports, 2);
    expect(await oldExport.exists(), isFalse);
    expect(await newerExport.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
  });
}
