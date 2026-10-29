import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/will_mirror/data/store.dart';
import 'package:quote_app/will_mirror/domain/model.dart';

import 'fixtures.dart';
import 'principle_application_test.dart' show principle, application;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
      'T332 T338 T361 T365: review versions and historical uses survive encrypted SQLite reopen',
      () async {
    final directory = await Directory.systemTemp.createTemp('wm_experience_');
    addTearDown(() => directory.delete(recursive: true));
    final cipher = TestCipher();
    final path = '${directory.path}/test.sqlite';
    var store = await SqliteMirrorStore.open(
        factory: databaseFactoryFfi, path: path, cipher: cipher);
    addTearDown(() => store.close());
    var f = prepared();
    final p = principle(f);
    f = commands.append(f, [p]);
    final original = application(f, p);
    f = commands.append(f, [original]);
    await store.save(f, expectedRevision: 0);
    final review = commands.addCounterEvidence(f, p.id, '另一段实际经历不支持原做法，需要复核');
    await store.save(review, expectedRevision: f.revision);
    await store.close();
    store = await SqliteMirrorStore.open(
        factory: databaseFactoryFfi, path: path, cipher: cipher);
    final restored = (await store.load(f.id))!;
    final revised = restored.latest(NodeKind.principle)!;
    expect(revised.text('maturity'), 'needs_review');
    expect(revised.counterIds, review.latest(NodeKind.principle)!.counterIds);
    expect(restored.node(revised.counterIds.single)!.text('text'),
        contains('另一段实际经历'));
    expect(restored.node(original.id)!.text('principleVersion'), p.id);
    expect(canonicalJson(restored.node(p.id)!.toJson()),
        canonicalJson(p.toJson()));
    final history = await store.history(f.id);
    expect(history, hasLength(2));
    expect(history.last.latest(NodeKind.principle)!.id, p.id);
    final rows = await store.db.query('cases');
    expect(rows.single['payload'], startsWith('opaque-'));
    expect(rows.toString(), isNot(contains('另一段实际经历')));
  });
}
