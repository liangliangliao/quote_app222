import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_knowledge_transform_model.dart';
import 'package:quote_app/evidence_growth/evidence_growth_knowledge_transform_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

KnowledgeTransform _transform(String core) => KnowledgeTransform.fromJson({
      'core': core,
      'problem': '问题',
      'examples': ['例1', '例2', '例3'],
      'counter': '反例',
      'analogy': '类比',
      'differs': '不像',
      'explain': '大白话',
      'rules': [
        {'trigger': '当出现X', 'action': '我就做Y'}
      ],
      'experiment': {'action': '做', 'predict': '预期', 'check': '对照'},
    });

Future<KnowledgeTransformEntry> _save(
  EvidenceGrowthKnowledgeTransformStore store,
  String nodeId,
  String core,
) =>
    store.save(
      nodeId: nodeId,
      nodeTitle: '标题-$nodeId',
      transform: _transform(core),
      provider: 'p',
      model: 'm',
      promptVersion: 'eg-transform.1',
      sourceHash: 'h',
    );

void main() {
  setUpAll(sqfliteFfiInit);
  late Database db;
  late EvidenceGrowthKnowledgeTransformStore store;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    store = EvidenceGrowthKnowledgeTransformStore(
        EvidenceGrowthDao(database: () async => db));
  });
  tearDown(() => db.close());

  test('starts empty, then saving returns a saved entry with an id', () async {
    expect(await store.list('KB35-B-AUDIT-02'), isEmpty);
    final entry = await _save(store, 'KB35-B-AUDIT-02', '第一次');
    expect(entry.saved, isTrue);
    expect(entry.timeLabel, matches(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$'));
    expect(await store.list('KB35-B-AUDIT-02'), hasLength(1));
  });

  test('re-converting appends and never overwrites earlier records',
      () async {
    final first = await _save(store, 'N1', '第一次');
    final second = await _save(store, 'N1', '第二次');
    final list = await store.list('N1');
    expect(list.map((e) => e.transform.core), ['第二次', '第一次']);
    expect(list.last.id, first.id);
    expect(list.first.id, second.id);
    expect(list.last.transform.core, '第一次');
  });

  test('history is kept per card', () async {
    await _save(store, 'N1', 'a');
    await _save(store, 'N2', 'b');
    expect((await store.list('N1')).single.transform.core, 'a');
    expect((await store.list('N2')).single.transform.core, 'b');
  });

  test('saved content cannot be rewritten in place', () async {
    final entry = await _save(store, 'N1', '原内容');
    await expectLater(
        db.update(EvidenceGrowthKnowledgeTransformStore.table,
            {'body_json': '{}'},
            where: 'transform_id=?', whereArgs: [entry.id]),
        throwsA(anything));
    expect((await store.list('N1')).single.transform.core, '原内容');
  });

  test('an unreadable row is skipped but never deleted', () async {
    await _save(store, 'N1', '好的');
    await db.insert(EvidenceGrowthKnowledgeTransformStore.table, {
      'node_id': 'N1',
      'node_title': 't',
      'body_json': 'not json',
      'created_at_ms': DateTime.now().millisecondsSinceEpoch + 1000,
    });
    expect(await store.list('N1'), hasLength(1));
    final raw = await db.query(EvidenceGrowthKnowledgeTransformStore.table);
    expect(raw, hasLength(2));
  });

  test('records survive closing and reopening the database file', () async {
    final directory =
        await Directory.systemTemp.createTemp('eg-transform-history-');
    Database? persistent;
    try {
      final path = '${directory.path}/history.sqlite';
      persistent = await databaseFactoryFfi.openDatabase(path);
      var persistentStore = EvidenceGrowthKnowledgeTransformStore(
          EvidenceGrowthDao(database: () async => persistent!));
      await _save(persistentStore, 'N1', '重启前');
      await persistent.close();
      persistent = await databaseFactoryFfi.openDatabase(path);
      persistentStore = EvidenceGrowthKnowledgeTransformStore(
          EvidenceGrowthDao(database: () async => persistent!));
      expect((await persistentStore.list('N1')).single.transform.core, '重启前');
    } finally {
      await persistent?.close();
      await directory.delete(recursive: true);
    }
  });
}
