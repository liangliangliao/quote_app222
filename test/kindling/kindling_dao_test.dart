import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/kindling/kindling.dart';
import 'package:quote_app/kindling/src/data/kindling_dao.dart';
import 'package:quote_app/kindling/src/data/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late KindlingDao dao;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await KindlingSchema.createAll(db);
    dao = KindlingDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('verdict "no" keeps the item and moves it to released', () async {
    final int id = await dao.insertItem(title: '把 §9 那段译完');

    await dao.recordVerdict(
      id,
      KVerdictAnswer.no,
      releaseReason: '判别式：不做',
    );

    final KItem? item = await dao.findItem(id);
    expect(item, isNotNull, reason: '答「不做」不得删除火种');
    expect(item!.isReleased, isTrue);
    expect(item.releaseNote, '判别式：不做');
    expect(await dao.liveItems(), isEmpty);
    expect((await dao.releasedItems()).single.id, id);

    await dao.restoreItem(id);
    final KItem restored = (await dao.liveItems()).single;
    expect(restored.id, id);
    expect(restored.releaseNote, isNull);
  });

  test('released_count counter tracks the核心成功指标', () async {
    final int a = await dao.insertItem(title: 'a');
    final int b = await dao.insertItem(title: 'b');
    expect(await dao.readCounter(KindlingDao.metaReleasedCount), 0);

    await dao.releaseItem(a, reason: '手动放掉');
    await dao.recordVerdict(b, KVerdictAnswer.no, releaseReason: '判别式：不做');

    expect(await dao.readCounter(KindlingDao.metaReleasedCount), 2);
    expect(await dao.releasedCount(), 2);
  });

  test('an aborted run never drags the want ratio down', () async {
    final int id = await dao.insertItem(title: 'x');
    final DateTime now = DateTime.now();

    final int answered =
        await dao.insertBurn(itemId: id, startedAt: now, seconds: 900);
    await dao.answerWantMore(answered, true);
    // 中途退出：没作答，不该被算成一次「不想」。
    await dao.insertBurn(
      itemId: id,
      startedAt: now.add(const Duration(hours: 1)),
      seconds: 41,
      aborted: true,
    );

    final KItemView view = (await dao.liveItemViews()).single;
    expect(view.burnTotal, 1, reason: '未作答的不进分母');
    expect(view.wantMoreCount, 1);
    expect(view.lastBurnAt, isNotNull, reason: '碰过就是碰过，衰减照算');
  });

  test('recall candidates keep the kind of the question they came from',
      () async {
    await dao.insertItems(<KCandidate>[
      (title: '译完第九节', kind: kindOfRecallQuestion(KRecallQuestion.itch)),
      (title: '别人做完了', kind: kindOfRecallQuestion(KRecallQuestion.envy)),
      (title: '改渲染管线', kind: kindOfRecallQuestion(KRecallQuestion.lostTrack)),
    ]);

    final Map<String, String> byTitle = <String, String>{
      for (final KItem item in await dao.liveItems()) item.title: item.kind,
    };
    expect(byTitle['译完第九节'], KKind.itch);
    expect(byTitle['别人做完了'], KKind.defiance);
    expect(byTitle['改渲染管线'], KKind.recall);
  });

  test('a fully blank recall is not counted as a session', () async {
    await dao.saveRecallAnswers(<String, String>{
      KRecallQuestion.lostTrack: '   ',
      KRecallQuestion.itch: '',
      KRecallQuestion.envy: '\n',
    });
    expect(await dao.recallHistory(), isEmpty);
    expect(await dao.readCounter(KindlingDao.metaRecallSessions), 0);
  });

  test('换个说法 can also leave a note behind', () async {
    final int id = await dao.insertItem(title: '旧说法');
    await dao.renameItem(id, '新说法', note: '为什么想做这件事');
    KItem? item = await dao.findItem(id);
    expect(item!.title, '新说法');
    expect(item.note, '为什么想做这件事');

    await dao.renameItem(id, '新说法', note: '   ');
    item = await dao.findItem(id);
    expect(item!.note, isNull, reason: '空备注就是没有备注');
  });

  test('recall answers are stored verbatim and bump the session counter',
      () async {
    await dao.saveRecallAnswers(<String, String>{
      KRecallQuestion.lostTrack: '上周改渲染管线，抬头三点了',
      KRecallQuestion.itch: '',
      KRecallQuestion.envy: '别人把东西真的做完了',
    });

    final List<KRecallAnswer> rows = await dao.recallHistory();
    expect(rows.length, 2, reason: '留空的问题不落库');
    expect(
      rows.map((KRecallAnswer r) => r.rawText),
      containsAll(<String>['上周改渲染管线，抬头三点了', '别人把东西真的做完了']),
    );
    expect(await dao.readCounter(KindlingDao.metaRecallSessions), 1);
  });

  test('burn records aborted runs without any failure marker', () async {
    final int id = await dao.insertItem(title: '修 XX 的渲染 bug');
    final DateTime started = DateTime.now();

    final int burnId = await dao.insertBurn(
      itemId: id,
      startedAt: started,
      seconds: 92,
      aborted: true,
    );

    final List<Map<String, Object?>> rows = await db.query('k_burn');
    final KBurn burn = KBurn.fromRow(rows.single);
    expect(burn.id, burnId);
    expect(burn.aborted, isTrue);
    expect(burn.wantMore, isNull, reason: '中途退出不追问，也不记为失败');
  });

  test('want_more rate is kept in k_meta only', () async {
    final int id = await dao.insertItem(title: 'x');
    final DateTime now = DateTime.now();
    final int first = await dao.insertBurn(
      itemId: id,
      startedAt: now,
      seconds: 900,
    );
    final int second = await dao.insertBurn(
      itemId: id,
      startedAt: now.add(const Duration(hours: 1)),
      seconds: 900,
    );
    await dao.answerWantMore(first, true);
    await dao.answerWantMore(second, false);

    final Map<String, num> metrics = await dao.localMetrics();
    expect(metrics[KindlingDao.metaBurnWantMoreRate], closeTo(0.5, 1e-6));
  });

  test('three consecutive "不想" answers pin 放掉 in the long-press menu',
      () async {
    final int id = await dao.insertItem(title: 'x');
    final DateTime now = DateTime.now();
    for (int i = 0; i < 3; i++) {
      final int burnId = await dao.insertBurn(
        itemId: id,
        startedAt: now.add(Duration(hours: i)),
        seconds: 900,
      );
      await dao.answerWantMore(burnId, false);
    }

    expect(await dao.consecutiveNoCount(id), 3);
    final KItemView view = (await dao.liveItemViews()).single;
    expect(view.suggestRelease, isTrue);

    final int latest = await dao.insertBurn(
      itemId: id,
      startedAt: now.add(const Duration(hours: 5)),
      seconds: 900,
    );
    await dao.answerWantMore(latest, true);
    expect(await dao.consecutiveNoCount(id), 0);
  });

  test('"说不准" comes back for one more question after 7 days', () async {
    final int fresh = await dao.insertItem(title: '刚问过的');
    final int stale = await dao.insertItem(title: '七天前问过的');
    final DateTime now = DateTime.now();

    await dao.recordVerdict(
      fresh,
      KVerdictAnswer.unsure,
      releaseReason: '判别式：不做',
      at: now,
    );
    await dao.recordVerdict(
      stale,
      KVerdictAnswer.unsure,
      releaseReason: '判别式：不做',
      at: now.subtract(const Duration(days: 8)),
    );

    final List<KItem> due = await dao.itemsDueForReask(now: now);
    expect(due.map((KItem i) => i.id), <int>[stale]);

    // 再答一次「做」之后不再复问。
    await dao.recordVerdict(
      stale,
      KVerdictAnswer.yes,
      releaseReason: '判别式：不做',
      at: now,
    );
    expect(await dao.itemsDueForReask(now: now), isEmpty);
  });

  test('item views aggregate the signals used for ordering', () async {
    final int id = await dao.insertItem(title: 'x');
    final DateTime now = DateTime.now();
    await dao.recordProbe(id, 4, at: now);
    await dao.recordVerdict(
      id,
      KVerdictAnswer.yes,
      releaseReason: '判别式：不做',
      at: now,
    );
    final int burnId =
        await dao.insertBurn(itemId: id, startedAt: now, seconds: 900);
    await dao.answerWantMore(burnId, true);

    final KItemView view = (await dao.liveItemViews()).single;
    expect(view.latestProbe, 4);
    expect(view.verdict, KVerdictAnswer.yes);
    expect(view.burnTotal, 1);
    expect(view.wantMoreCount, 1);
    expect(view.consecutiveNoCount, 0);
  });

  test('probe scores are clamped into 0..4', () async {
    final int id = await dao.insertItem(title: 'x');
    await dao.recordProbe(id, 42);
    await dao.recordProbe(id, -3);
    final List<Map<String, Object?>> rows =
        await db.query('k_probe', orderBy: 'id ASC');
    expect(rows.map((Map<String, Object?> r) => r['score']), <int>[4, 0]);
  });

  test('resistance steps are recorded and answers may stay empty', () async {
    final int id = await dao.insertItem(title: 'x');
    final int row = await dao.insertResistanceStep(
      itemId: id,
      step: 1,
      question: '不做它，你避免了什么？',
    );
    await dao.updateResistanceAnswer(row, '避免被看见做得烂');

    final List<KResistanceStep> steps = await dao.resistanceHistory(id);
    expect(steps.single.answer, '避免被看见做得烂');
    expect(steps.single.step, 1);
  });
}
