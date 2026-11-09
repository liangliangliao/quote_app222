import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/epistemic/schopenhauer_circles.dart';
import 'package:quote_app/quote_knowledge/repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late QuoteKnowledgeRepository repository;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
            onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON')));
    await db.execute(
        'CREATE TABLE quotes(id INTEGER PRIMARY KEY AUTOINCREMENT,quote_uid TEXT UNIQUE,content TEXT,theme TEXT,explanation TEXT,avatar TEXT,notified INTEGER)');
    repository = QuoteKnowledgeRepository(
        database: () async => db, clock: () => DateTime.utc(2026, 11, 9));
    await repository.database;
  });
  tearDown(() async => db.close());

  test('category extensions close upward and give the circle relations', () async {
    for (final uid in ['q1', 'q2', 'q3']) {
      await db.insert('quotes',
          {'quote_uid': uid, 'content': '名言$uid', 'theme': '', 'explanation': ''});
    }
    final fruit = await repository.createCategory('水果', '可食用的果实');
    final apple = await repository.createCategory('苹果', '苹果这种水果', parentId: fruit);
    final red = await repository.createCategory('红色', '红色的事物');
    await repository.assignManually('q1', [apple]);
    await repository.assignManually('q2', [fruit, red]);
    await repository.assignManually('q3', [red]);

    final extensions = await repository.categoryExtensions();
    expect(extensions[apple], {'q1'});
    expect(extensions[fruit], {'q1', 'q2'});
    expect(extensions[red], {'q2', 'q3'});
    expect(classifyExtensions(extensions[apple]!, extensions[fruit]!).relation,
        CircleRelation.subset);
    expect(classifyExtensions(extensions[fruit]!, extensions[red]!).relation,
        CircleRelation.overlap);
    expect(classifyExtensions(extensions[apple]!, extensions[red]!).relation,
        CircleRelation.disjoint);
  });
}
