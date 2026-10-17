import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/zhaojian/zhaojian.dart';
import 'package:quote_app/zhaojian/src/data/models.dart';
import 'package:quote_app/zhaojian/src/data/zhaojian_dao.dart';
import 'package:quote_app/zhaojian/src/domain/controller.dart';
import 'package:quote_app/zhaojian/src/zhaojian_oracle.dart' show buildMotiveLibrary;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await ZhaojianSchema.createAll(db);
  });

  tearDown(() async {
    await db.close();
  });

  ZDecision sample({String pred = 'a'}) {
    return ZDecision(
      question: '他开口借钱',
      optionA: '借',
      optionB: '不借',
      importance: '大',
      motives: <ZMotive>[
        ZMotive(text: '怕被说小气', cat: 1, kind: 'int', side: 'a', weight: 4, rated: true),
        ZMotive(text: '风险', cat: 2, kind: 'abs', side: 'b', weight: 3, rated: true),
      ],
      pred: pred,
      stake: 3,
      feltFreedom: 7,
      condition: '他当面开口',
      jtPred: 1,
      conflictType: 3,
      sealedAt: DateTime(2026, 10, 1),
      notes: <String>['a', 'b', 'c'],
      imageryDepth: 2.5,
      imagerySymmetry: 0.5,
    );
  }

  group('schema', () {
    test('createAll and migrate are idempotent and write the version', () async {
      await ZhaojianSchema.createAll(db);
      await ZhaojianSchema.migrate(db, 35, 36);
      expect(await ZhaojianSchema.storedVersion(db), ZhaojianSchema.schemaVersion);
      for (final String t in ZhaojianSchema.tables) {
        final List<Map<String, Object?>> rows = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
          <Object?>[t],
        );
        expect(rows, isNotEmpty, reason: '缺表 $t');
      }
    });

    test('every table uses the z_ prefix', () {
      expect(ZhaojianSchema.tables.every((String t) => t.startsWith('z_')), isTrue);
    });
  });

  group('dao', () {
    test('a decision round-trips with all fields', () async {
      final ZhaojianDao dao = ZhaojianDao(db);
      final int id = await dao.insertDecision(sample());
      final ZDecision? d = await dao.findDecision(id);
      expect(d, isNotNull);
      expect(d!.question, '他开口借钱');
      expect(d.importance, '大');
      expect(d.motives.length, 2);
      expect(d.motives.first.text, '怕被说小气');
      expect(d.motives.first.side, 'a');
      expect(d.feltFreedom, 7);
      expect(d.condition, '他当面开口');
      expect(d.jtPred, 1);
      expect(d.conflictType, 3);
      expect(d.notes, <String>['a', 'b', 'c']);
      expect(d.imageryDepth, 2.5);
      expect(d.revealed, isFalse);
      expect((await dao.pendingDecisions()).length, 1);
      expect(await dao.revealedDecisions(), isEmpty);
    });

    test('corrupt json columns degrade to empty lists', () async {
      final ZhaojianDao dao = ZhaojianDao(db);
      final int id = await dao.insertDecision(sample());
      await db.update('z_decision', <String, Object?>{'motives_json': '{oops', 'body_json': 'x'},
          where: 'id = ?', whereArgs: <Object?>[id]);
      final ZDecision? d = await dao.findDecision(id);
      expect(d!.motives, isEmpty);
      expect(d.body, isEmpty);
    });
  });

  group('alignment storage and schema v2', () {
    test('an alignment summary round-trips through the dao', () async {
      final ZhaojianDao dao = ZhaojianDao(db);
      final ZDecision d = sample();
      final ZDecision withAlign = ZDecision(
        question: d.question,
        optionA: d.optionA,
        optionB: d.optionB,
        motives: d.motives,
        pred: d.pred,
        stake: d.stake,
        sealedAt: d.sealedAt,
        align: const ZAlignSummary(
          yearA: 70,
          yearB: 35,
          diffA: '难',
          diffB: '易',
          manual: true,
          weakOnly: true,
        ),
      );
      final int id = await dao.insertDecision(withAlign);
      final ZDecision? back = await dao.findDecision(id);
      expect(back!.align, isNotNull);
      expect(back.align!.yearA, 70);
      expect(back.align!.diffA, '难');
      expect(back.align!.manual, isTrue);
      expect(back.align!.yearOf('b'), 35);

      final int plain = await dao.insertDecision(sample());
      expect((await dao.findDecision(plain))!.align, isNull);
    });

    test('migrate adds align_json to a v1 database and keeps old rows', () async {
      final Database old = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(old.close);
      await old.execute('CREATE TABLE z_meta (key TEXT PRIMARY KEY, value TEXT)');
      await old.insert('z_meta', <String, Object?>{'key': 'schema_version', 'value': '1'});
      await old.execute('''
        CREATE TABLE z_decision (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          question TEXT NOT NULL, option_a TEXT NOT NULL, option_b TEXT NOT NULL,
          importance TEXT, motives_json TEXT, pred TEXT NOT NULL, stake INTEGER NOT NULL,
          felt_freedom INTEGER, condition_text TEXT, jt_pred INTEGER, conflict_type INTEGER,
          sealed_at INTEGER NOT NULL, actual TEXT, actual_at INTEGER, reaction TEXT,
          body_json TEXT, jt_actual INTEGER, hyp_id INTEGER, hyp_kind TEXT,
          miss_logged INTEGER NOT NULL DEFAULT 0, notes_json TEXT,
          imagery_depth REAL, imagery_sym REAL
        )
      ''');
      await old.insert('z_decision', <String, Object?>{
        'question': '旧数据',
        'option_a': 'A',
        'option_b': 'B',
        'pred': 'a',
        'stake': 2,
        'sealed_at': 1000,
      });

      await ZhaojianSchema.migrate(old, 36, 37);
      await ZhaojianSchema.migrate(old, 36, 37); // 幂等

      final List<Map<String, Object?>> cols = await old.rawQuery('PRAGMA table_info(z_decision)');
      expect(cols.any((Map<String, Object?> c) => c['name'] == 'align_json'), isTrue);
      expect(await ZhaojianSchema.storedVersion(old), ZhaojianSchema.schemaVersion);
      final List<Map<String, Object?>> tables = await old.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='z_item'");
      expect(tables, isNotEmpty, reason: 'v3 新增的 z_item 表也被补建');
      final ZhaojianDao dao = ZhaojianDao(old);
      final List<ZDecision> all = await dao.allDecisions();
      expect(all.single.question, '旧数据');
      expect(all.single.align, isNull);
      final int id = await dao.insertDecision(ZDecision(
        question: '新数据',
        optionA: 'A',
        optionB: 'B',
        pred: 'b',
        stake: 1,
        sealedAt: DateTime(2026, 10, 2),
        align: const ZAlignSummary(yearA: 55, yearB: 45),
      ));
      expect((await dao.findDecision(id))!.align!.yearA, 55);
    });
  });

  group('generic items and key-value', () {
    test('items round-trip, update and delete through the controller', () async {
      final ZhaojianController c =
          ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await c.load();
      final ZEntry rope = await c.addItem('rope', <String, dynamic>{
        's': '想赌的时候',
        'r': '把卡放家里',
        'bs': <String>['胃沉', '轻松'],
        'n': 3,
        'flag': true,
      });
      expect(c.items('rope').length, 1);
      expect(c.items('plan'), isEmpty);
      rope.data['ok'] = 'y';
      await c.saveItem(rope);

      await c.load();
      final ZEntry back = c.items('rope').single;
      expect(back.s('s'), '想赌的时候');
      expect(back.s('ok'), 'y');
      expect(back.i('n'), 3);
      expect(back.b('flag'), isTrue);
      expect(back.list('bs'), <String>['胃沉', '轻松']);
      expect(back.s('missing', 'dflt'), 'dflt');

      await c.removeItem(back);
      await c.load();
      expect(c.items('rope'), isEmpty);
    });

    test('corrupt item json degrades to empty data', () async {
      final ZhaojianDao dao = ZhaojianDao(db);
      final int id = await dao.insertItem(ZEntry(kind: 'x', data: <String, dynamic>{'a': 1}));
      await db.update('z_item', <String, Object?>{'data_json': '{oops'},
          where: 'id = ?', whereArgs: <Object?>[id]);
      final List<ZEntry> all = await dao.allItems();
      expect(all.single.data, isEmpty);
    });

    test('key-value survives a reload and keeps keys apart from the schema version', () async {
      final ZhaojianController c =
          ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await c.load();
      await c.setKv('ab.s', '耐心');
      await c.setKv('ab.s', '耐心，肯下笨功夫');
      await c.setKv('line.pick', '写作');
      await c.load();
      expect(c.kv('ab.s'), '耐心，肯下笨功夫');
      expect(c.kv('line.pick'), '写作');
      expect(c.kv('nope', 'x'), 'x');
      expect(await ZhaojianSchema.storedVersion(db), ZhaojianSchema.schemaVersion);
    });

    test('tagging an item counts for a hypothesis and can be changed or undone', () async {
      final ZhaojianController c =
          ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await c.load();
      final int h1 = await c.addHypothesis('心软', '');
      final int h2 = await c.addHypothesis('怕被看不起', '');
      final ZEntry e = await c.addItem('arch', <String, dynamic>{'w': '借了钱', 'ph': '高中'});

      await c.tagItem(e, h1, 'sup');
      expect(c.hypotheses.firstWhere((ZHypothesis h) => h.id == h1).sup.length, 1);
      expect(c.actsOfHypothesis(h1), 1);

      await c.tagItem(c.items('arch').single, h1, 'ref');
      final ZHypothesis a = c.hypotheses.firstWhere((ZHypothesis h) => h.id == h1);
      expect(a.sup.length, 0, reason: '改成背离时撤销原来的支持');
      expect(a.ref.length, 1);

      await c.tagItem(c.items('arch').single, h2, 'sup');
      expect(c.hypotheses.firstWhere((ZHypothesis h) => h.id == h1).ref.length, 0);
      expect(c.hypotheses.firstWhere((ZHypothesis h) => h.id == h2).sup.length, 1);

      await c.tagItem(c.items('arch').single, null, 'sup');
      expect(c.hypotheses.firstWhere((ZHypothesis h) => h.id == h2).sup.length, 0);
      expect(c.actsOfHypothesis(h2), 0);
    });

    test('phases of a hypothesis count distinct life stages', () async {
      final ZhaojianController c =
          ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await c.load();
      final int h = await c.addHypothesis('心软', '');
      for (final String ph in <String>['童年', '高中', '高中', '']) {
        final ZEntry e = await c.addItem('arch', <String, dynamic>{'w': 'x', 'ph': ph});
        await c.tagItem(e, h, 'sup');
      }
      expect(c.phasesOfHypothesis(h), 2);
      expect(c.actsOfHypothesis(h), 4);
    });

    test('evidence count adds up the strong sources', () async {
      final ZhaojianController c =
          ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await c.load();
      expect(c.evidenceCount, 0);
      await c.addLog(ZLog(what: 'x', reaction: '松了口气', createdAt: DateTime(2026, 10, 1)));
      await c.addItem('arch', <String, dynamic>{'w': 'x'});
      await c.addItem('obs', <String, dynamic>{'saw': 'x'});
      await c.addItem('rope', <String, dynamic>{'s': 'x'});
      expect(c.evidenceCount, 3, reason: '没有结果的绳子不算证据');
      await c.addItem('rope', <String, dynamic>{'s': 'y', 'ok': 'n'});
      expect(c.evidenceCount, 4);
    });

    test('active threads add up plans, open as-if, undone probes and unfinished forgo', () async {
      final ZhaojianController c =
          ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await c.load();
      expect(c.activeThreads, 0);
      await c.addItem('plan', <String, dynamic>{'st': '进行中'});
      await c.addItem('plan', <String, dynamic>{'st': '做到了'});
      await c.addItem('asif', <String, dynamic>{'r': '自然', 'nb': '', 'al': ''});
      await c.addItem('asif', <String, dynamic>{'r': '自然', 'nb': '没成真', 'al': '更靠近'});
      await c.addItem('probe', <String, dynamic>{'done': false});
      await c.addItem('probe', <String, dynamic>{'done': true});
      await c.addItem('forgo', <String, dynamic>{'days': 3, 'log': <Map<String, dynamic>>[{'v': 4}]});
      await c.addItem('forgo', <String, dynamic>{
        'days': 1,
        'log': <Map<String, dynamic>>[{'v': 4}],
      });
      expect(c.activePlans, 1);
      expect(c.activeAsif, 1);
      expect(c.activeProbes, 1);
      expect(c.activeForgo, 1);
      expect(c.activeThreads, 4);
    });

    test('engine prediction and the picked signature are looked up by decision id', () async {
      final ZhaojianController c =
          ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await c.load();
      final int id = await c.seal(sample());
      expect(c.engineProbA(id), isNull);
      expect(c.signatureOf(id), isNull);
      expect(c.engineProbA(null), isNull);

      final ZEntry sig = await c.addItem('sig', <String, dynamic>{'ifc': '被当面请求', 'then': '先答应', 'conf': true});
      await c.setKv('eng.$id', '0.62');
      await c.setKv('sig.$id', '${sig.id}');
      await c.load();
      expect(c.engineProbA(id), 0.62);
      expect(c.signatureOf(id)!.s('then'), '先答应');

      await c.removeItem(c.items('sig').single);
      expect(c.signatureOf(id), isNull, reason: '签名被删后不再关联');
    });

    test('restore replaces everything with the backup, ids and links intact', () async {
      final ZhaojianController a =
          ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await a.load();
      final int hid = await a.addHypothesis('心软', '先答应');
      final int did = await a.seal(sample());
      await a.reveal(decisionId: did, actual: 'b', reaction: '松了口气', hypId: hid, hypKind: 'sup');
      await a.addItem('rope', <String, dynamic>{'s': '想赌', 'r': '卸载', 'seq': <String>['y', 'n'], 'ok': 'n'});
      await a.addMiss(cat: 1, text: '怕议论', decisionId: did);
      await a.setKv('ab.s', '耐心');
      await a.setKv('eng.$did', '0.4');
      final String backup = a.exportJson();

      // 另一个全新的库：恢复后应当和原来一模一样。
      final Database other = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(other.close);
      await ZhaojianSchema.createAll(other);
      final ZhaojianController b =
          ZhaojianController(db: other, oracle: const LocalZhaojianOracle());
      await b.load();
      await b.addItem('prin', <String, dynamic>{'t': '会被替换掉的旧数据'});
      await b.setKv('stale', 'x');

      expect(await b.restoreJson(backup), isNull);
      expect(b.items('prin'), isEmpty, reason: '恢复是替换，不是合并');
      expect(b.kv('stale'), '');
      expect(b.decisions.length, 1);
      expect(b.revealed.single.id, did);
      expect(b.revealed.single.hypId, hid);
      expect(b.revealed.single.body, a.revealed.single.body);
      expect(b.hypotheses.single.sup.length, 1);
      expect(b.hypotheses.single.id, hid);
      expect(b.items('rope').single.list('seq'), <String>['y', 'n']);
      expect(b.misses.single.decisionId, did);
      expect(b.kv('ab.s'), '耐心');
      expect(b.engineProbA(did), 0.4);
      expect(b.logs.length, a.logs.length);
      Map<String, dynamic> norm(String s) {
        final Map<String, dynamic> m = jsonDecode(s) as Map<String, dynamic>;
        m.remove('exportedAt');
        return m;
      }

      expect(norm(b.exportJson()), equals(norm(backup)), reason: '导出、恢复、再导出，内容不变');
    });

    test('restore rejects bad input and leaves the existing data untouched', () async {
      final ZhaojianController c =
          ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await c.load();
      await c.seal(sample());
      await c.setKv('ab.s', '耐心');

      expect(await c.restoreJson('这不是 JSON'), contains('JSON'));
      expect(await c.restoreJson('{"app":"other"}'), contains('不是照见'));
      expect(await c.restoreJson('{"app":"zhaojian","schemaVersion":99}'), contains('更新'));
      // 一行缺了必填列：整个事务回滚。
      expect(
        await c.restoreJson('{"app":"zhaojian","schemaVersion":3,"decisions":[{"id":7,"question":"q"}]}'),
        contains('没有改动'),
      );
      expect(c.decisions.length, 1);
      expect(c.kv('ab.s'), '耐心');
    });

    test('restore tolerates columns the current schema does not have', () async {
      final ZhaojianController c =
          ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await c.load();
      const String backup = '{"app":"zhaojian","schemaVersion":1,"decisions":[{"id":3,"question":"旧版","option_a":"A","option_b":"B","pred":"a","stake":2,"sealed_at":1000,"future_column":"x"}],"hypotheses":[],"logs":[],"misses":[],"items":{},"kv":{"k":"v"}}';
      expect(await c.restoreJson(backup), isNull);
      expect(c.decisions.single.question, '旧版');
      expect(c.kv('k'), 'v');
    });

    test('export is valid json with every section', () async {
      final ZhaojianController c =
          ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await c.load();
      await c.seal(sample());
      await c.addItem('prin', <String, dynamic>{'t': '先过一夜'});
      await c.setKv('ab.s', '耐心');
      final Map<String, dynamic> j =
          jsonDecode(c.exportJson()) as Map<String, dynamic>;
      expect(j['app'], 'zhaojian');
      expect(j['schemaVersion'], ZhaojianSchema.schemaVersion);
      expect((j['decisions'] as List<dynamic>).length, 1);
      expect((j['items'] as Map<String, dynamic>)['prin'], isNotEmpty);
      expect((j['kv'] as Map<String, dynamic>)['ab.s'], '耐心');
    });
  });

  group('controller', () {
    test('seal, reveal, log and hypothesis counting work together', () async {
      final ZhaojianController c =
          ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await c.load();
      final int hid = await c.addHypothesis('在人情面前心软', '借钱时先答应');
      final int id = await c.seal(sample(pred: 'a'));
      expect(c.pending.length, 1);

      final ZDecision? d = await c.reveal(
        decisionId: id,
        actual: 'b',
        reaction: '松了口气',
        jtActual: 2,
        body: <String>['胃沉'],
        hypId: hid,
        hypKind: 'ref',
      );
      expect(d, isNotNull);
      expect(d!.hit, isFalse);
      expect(c.pending, isEmpty);
      expect(c.revealed.single.reaction, '松了口气');
      expect(c.revealed.single.body, <String>['胃沉']);
      expect(c.logs.length, 1);
      expect(c.logs.single.what, '决定：不借');
      expect(c.hypotheses.single.ref.length, 1);
      expect(c.hypotheses.single.status, 0);
    });

    test('revealing twice does not double count', () async {
      final ZhaojianController c =
          ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await c.load();
      final int hid = await c.addHypothesis('x', '');
      final int id = await c.seal(sample());
      await c.reveal(decisionId: id, actual: 'a', reaction: '疲惫但踏实', hypId: hid);
      await c.reveal(decisionId: id, actual: 'b', reaction: '像在演', hypId: hid);
      expect(c.hypotheses.single.sup.length, 1);
      expect(c.logs.length, 1);
      expect(c.revealed.single.actual, 'a');
    });

    test('three supports flip a hypothesis to supported', () async {
      final ZhaojianController c =
          ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await c.load();
      final int hid = await c.addHypothesis('x', '');
      await c.bumpHypothesis(hid, 'sup');
      await c.bumpHypothesis(hid, 'sup');
      expect(c.hypotheses.single.status, 0);
      await c.addLog(ZLog(
        what: '答应了',
        reaction: '怅然若失',
        hypId: hid,
        hypKind: 'sup',
        createdAt: DateTime(2026, 10, 3),
      ));
      expect(c.hypotheses.single.sup.length, 3);
      expect(c.hypotheses.single.status, 1);
    });

    test('missing motives are stored and surface as frequent categories', () async {
      final ZhaojianController c =
          ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await c.load();
      final int id = await c.seal(sample());
      await c.addMiss(cat: 1, text: '怕被朋友圈议论', decisionId: id);
      await c.addMiss(cat: 1, text: 'x');
      await c.addMiss(cat: 4, text: 'y');
      expect(c.misses.length, 3);
      expect(c.missCats.contains(1), isTrue);
      final ZDecision? d = await c.dao.findDecision(id);
      expect(d!.missLogged, isTrue);
    });

    test('profile text mentions supported hypotheses and missed categories', () async {
      final ZhaojianController c =
          ZhaojianController(db: db, oracle: const LocalZhaojianOracle());
      await c.load();
      final int hid = await c.addHypothesis('想要自由', '');
      for (int i = 0; i < 3; i++) {
        await c.bumpHypothesis(hid, 'sup');
      }
      await c.addMiss(cat: 1, text: 'x');
      final String p = c.profileText(ZCopy.categories);
      expect(p.contains('想要自由'), isTrue);
      expect(p.contains(ZCopy.categories[1]), isTrue);
    });
  });

  group('oracle', () {
    test('local oracle returns the 61-motive library and no scores', () async {
      expect(buildMotiveLibrary().length, 61);
      const LocalZhaojianOracle o = LocalZhaojianOracle();
      expect(await o.completeMotives(question: 'q', optionA: 'a', optionB: 'b', profile: ''), isEmpty);
      expect((await o.scoreMotives(situation: 's', motives: buildMotiveLibrary())).isEmpty, isTrue);
    });
  });
}
