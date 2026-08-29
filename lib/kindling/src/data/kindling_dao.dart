import 'package:sqflite/sqflite.dart';

import 'kindling_schema.dart';
import 'models.dart';

/// 模块全部 SQL。除本文件外，任何地方不得写 SQL。
///
/// DAO 只读写 `k_` 前缀的表，从不接触宿主任何表。
class KindlingDao {
  KindlingDao(this.db);

  final Database db;

  /// 埋点键（本地，仅自用，永不展示）。
  static const String metaRecallSessions = 'recall_sessions';
  static const String metaReleasedCount = 'released_count';
  static const String metaBurnWantMoreRate = 'burn_want_more_rate';

  /// 判别式答「说不准」后的复问间隔。
  static const Duration unsureReaskAfter = Duration(days: 7);

  static int _ms(DateTime t) => t.millisecondsSinceEpoch;

  static int _asInt(Object? v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  Future<void> ensureSchema() => KindlingSchema.createAll(db);

  // ---------------------------------------------------------------- 火种

  /// 新增一条火种，返回新 id。
  Future<int> insertItem({
    required String title,
    String kind = KKind.other,
    String? note,
    DateTime? at,
  }) async {
    final String trimmed = title.trim();
    final int now = _ms(at ?? DateTime.now());
    return db.insert('k_item', <String, Object?>{
      'title': trimmed,
      'kind': KKind.normalize(kind),
      'note': note,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// 批量新增（回溯勾选后使用），逐条带自己的类别，返回新 id 列表。
  Future<List<int>> insertItems(
    List<KCandidate> candidates, {
    DateTime? at,
  }) async {
    final List<int> ids = <int>[];
    final DateTime now = at ?? DateTime.now();
    await db.transaction((Transaction txn) async {
      for (final KCandidate candidate in candidates) {
        final String trimmed = candidate.title.trim();
        if (trimmed.isEmpty) continue;
        final int ms = _ms(now);
        ids.add(await txn.insert('k_item', <String, Object?>{
          'title': trimmed,
          'kind': KKind.normalize(candidate.kind),
          'created_at': ms,
          'updated_at': ms,
        }));
      }
    });
    return ids;
  }

  /// 换个说法：改标题，顺带可以留一句备注。不改任何历史记录。
  Future<void> renameItem(
    int itemId,
    String title, {
    String? note,
    DateTime? at,
  }) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final String? trimmedNote = note?.trim();
    await db.update(
      'k_item',
      <String, Object?>{
        'title': trimmed,
        'note': (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
        'updated_at': _ms(at ?? DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: <Object?>[itemId],
    );
  }

  /// 放掉：不删除，只标记，并记下原因。
  Future<void> releaseItem(
    int itemId, {
    required String reason,
    DateTime? at,
  }) async {
    final int now = _ms(at ?? DateTime.now());
    await db.update(
      'k_item',
      <String, Object?>{
        'released_at': now,
        'release_note': reason,
        'updated_at': now,
      },
      where: 'id = ? AND released_at IS NULL',
      whereArgs: <Object?>[itemId],
    );
    await _bumpCounter(metaReleasedCount);
  }

  /// 拿回来。
  Future<void> restoreItem(int itemId, {DateTime? at}) async {
    await db.update(
      'k_item',
      <String, Object?>{
        'released_at': null,
        'release_note': null,
        'updated_at': _ms(at ?? DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: <Object?>[itemId],
    );
  }

  Future<KItem?> findItem(int itemId) async {
    final List<Map<String, Object?>> rows = await db.query(
      'k_item',
      where: 'id = ?',
      whereArgs: <Object?>[itemId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return KItem.fromRow(rows.first);
  }

  /// 在清单上的火种（未放掉）。
  Future<List<KItem>> liveItems() async {
    final List<Map<String, Object?>> rows = await db.query(
      'k_item',
      where: 'released_at IS NULL',
      orderBy: 'updated_at DESC',
    );
    return rows.map(KItem.fromRow).toList(growable: false);
  }

  /// 放掉的火种，最近放掉的在前。
  Future<List<KItem>> releasedItems() async {
    final List<Map<String, Object?>> rows = await db.query(
      'k_item',
      where: 'released_at IS NOT NULL',
      orderBy: 'released_at DESC',
    );
    return rows.map(KItem.fromRow).toList(growable: false);
  }

  Future<int> releasedCount() async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM k_item WHERE released_at IS NOT NULL',
    );
    return rows.isEmpty ? 0 : _asInt(rows.first['c']);
  }

  /// 清单聚合视图：一次取齐排序所需的全部信号。
  Future<List<KItemView>> liveItemViews() async {
    final List<KItem> items = await liveItems();
    if (items.isEmpty) return const <KItemView>[];

    final Map<int, KItemView> byId = <int, KItemView>{};
    for (final KItem item in items) {
      byId[item.id] = await _viewOf(item);
    }
    return items
        .map((KItem item) => byId[item.id]!)
        .toList(growable: false);
  }

  Future<KItemView> _viewOf(KItem item) async {
    final List<Map<String, Object?>> probeRows = await db.query(
      'k_probe',
      where: 'item_id = ?',
      whereArgs: <Object?>[item.id],
      orderBy: 'recorded_at DESC',
      limit: 1,
    );
    final KProbe? probe =
        probeRows.isEmpty ? null : KProbe.fromRow(probeRows.first);

    final KVerdict? verdict = await latestVerdict(item.id);

    final List<Map<String, Object?>> burnRows = await db.query(
      'k_burn',
      where: 'item_id = ?',
      whereArgs: <Object?>[item.id],
      orderBy: 'started_at DESC',
    );
    final List<KBurn> burns =
        burnRows.map(KBurn.fromRow).toList(growable: false);

    int burnTotal = 0;
    int wantMoreCount = 0;
    DateTime? lastBurnAt;
    for (final KBurn burn in burns) {
      // 最近一次触碰包含中途退出：碰过就是碰过，用于时间衰减。
      lastBurnAt ??= burn.startedAt;
      // 但没作答的（中途退出）不进比例的分母。否则退出一次就等于往
      // 「不想」那边记了一笔，与「中途退出不记为失败」相悖。
      if (burn.wantMore == null) continue;
      burnTotal += 1;
      if (burn.wantMore == true) wantMoreCount += 1;
    }

    int consecutiveNo = 0;
    for (final KBurn burn in burns) {
      if (burn.wantMore == null) continue; // 未答不打断连续性
      if (burn.wantMore == false) {
        consecutiveNo += 1;
      } else {
        break;
      }
    }

    return KItemView(
      item: item,
      latestProbe: probe?.score,
      probeAt: probe?.recordedAt,
      burnTotal: burnTotal,
      wantMoreCount: wantMoreCount,
      lastBurnAt: lastBurnAt,
      verdict: verdict?.answer,
      verdictAt: verdict?.decidedAt,
      consecutiveNoCount: consecutiveNo,
    );
  }

  // ---------------------------------------------------------------- 痒度自评

  Future<void> recordProbe(int itemId, int score, {DateTime? at}) async {
    final int clamped = score < 0 ? 0 : (score > 4 ? 4 : score);
    await db.insert('k_probe', <String, Object?>{
      'item_id': itemId,
      'score': clamped,
      'recorded_at': _ms(at ?? DateTime.now()),
    });
  }

  // ---------------------------------------------------------------- 判别式

  Future<KVerdict?> latestVerdict(int itemId) async {
    final List<Map<String, Object?>> rows = await db.query(
      'k_verdict',
      where: 'item_id = ?',
      whereArgs: <Object?>[itemId],
      orderBy: 'decided_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return KVerdict.fromRow(rows.first);
  }

  /// 记录判别式回答；答「不做」时把火种移入「放掉的」（不删除）。
  Future<void> recordVerdict(
    int itemId,
    String answer, {
    required String releaseReason,
    DateTime? at,
  }) async {
    final DateTime now = at ?? DateTime.now();
    await db.insert('k_verdict', <String, Object?>{
      'item_id': itemId,
      'answer': answer,
      'decided_at': _ms(now),
    });
    if (answer == KVerdictAnswer.no) {
      await releaseItem(itemId, reason: releaseReason, at: now);
    }
  }

  /// 答过「说不准」且已过 7 天、仍在清单上的火种。用于复问一次。
  Future<List<KItem>> itemsDueForReask({DateTime? now}) async {
    final DateTime at = now ?? DateTime.now();
    final int cutoff = _ms(at.subtract(unsureReaskAfter));
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT i.* FROM k_item i
      JOIN k_verdict v ON v.item_id = i.id
      WHERE i.released_at IS NULL
        AND v.decided_at = (
          SELECT MAX(v2.decided_at) FROM k_verdict v2 WHERE v2.item_id = i.id
        )
        AND v.answer = ?
        AND v.decided_at <= ?
      ORDER BY v.decided_at ASC
      ''',
      <Object?>[KVerdictAnswer.unsure, cutoff],
    );
    return rows.map(KItem.fromRow).toList(growable: false);
  }

  // ---------------------------------------------------------------- 十五分钟

  /// 记一次十五分钟。中途退出即 aborted=1，不做任何提示。
  Future<int> insertBurn({
    required int itemId,
    required DateTime startedAt,
    required int seconds,
    bool aborted = false,
    bool? wantMore,
  }) async {
    final int id = await db.insert('k_burn', <String, Object?>{
      'item_id': itemId,
      'started_at': _ms(startedAt),
      'seconds': seconds,
      'want_more': wantMore == null ? null : (wantMore ? 1 : 0),
      'aborted': aborted ? 1 : 0,
    });
    await _refreshWantMoreRate();
    return id;
  }

  Future<void> answerWantMore(int burnId, bool wantMore) async {
    await db.update(
      'k_burn',
      <String, Object?>{'want_more': wantMore ? 1 : 0},
      where: 'id = ?',
      whereArgs: <Object?>[burnId],
    );
    await _refreshWantMoreRate();
  }

  /// 最近连续答「不想」的次数（未答不打断连续性）。
  Future<int> consecutiveNoCount(int itemId) async {
    final List<Map<String, Object?>> rows = await db.query(
      'k_burn',
      where: 'item_id = ?',
      whereArgs: <Object?>[itemId],
      orderBy: 'started_at DESC',
    );
    int count = 0;
    for (final Map<String, Object?> row in rows) {
      final KBurn burn = KBurn.fromRow(row);
      if (burn.wantMore == null) continue;
      if (burn.wantMore == false) {
        count += 1;
      } else {
        break;
      }
    }
    return count;
  }

  // ---------------------------------------------------------------- 回溯

  Future<void> saveRecallAnswers(
    Map<String, String> answers, {
    DateTime? at,
  }) async {
    final int now = _ms(at ?? DateTime.now());
    int written = 0;
    await db.transaction((Transaction txn) async {
      for (final String key in KRecallQuestion.ordered) {
        final String raw = (answers[key] ?? '').trim();
        if (raw.isEmpty) continue;
        await txn.insert('k_recall', <String, Object?>{
          'question_key': key,
          'raw_text': raw,
          'created_at': now,
        });
        written += 1;
      }
    });
    // 三问全部留空不算做过一次回溯，否则这个数会虚高到没法自查。
    if (written == 0) return;
    await _bumpCounter(metaRecallSessions);
  }

  Future<List<KRecallAnswer>> recallHistory() async {
    final List<Map<String, Object?>> rows = await db.query(
      'k_recall',
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(KRecallAnswer.fromRow).toList(growable: false);
  }

  // ---------------------------------------------------------------- 阻抗

  Future<int> insertResistanceStep({
    int? itemId,
    required int step,
    required String question,
    String? answer,
    DateTime? at,
  }) {
    return db.insert('k_resistance', <String, Object?>{
      'item_id': itemId,
      'step': step,
      'question': question,
      'answer': answer,
      'created_at': _ms(at ?? DateTime.now()),
    });
  }

  Future<void> updateResistanceAnswer(int rowId, String? answer) async {
    await db.update(
      'k_resistance',
      <String, Object?>{'answer': answer},
      where: 'id = ?',
      whereArgs: <Object?>[rowId],
    );
  }

  Future<List<KResistanceStep>> resistanceHistory(int? itemId) async {
    final List<Map<String, Object?>> rows = await db.query(
      'k_resistance',
      where: itemId == null ? null : 'item_id = ?',
      whereArgs: itemId == null ? null : <Object?>[itemId],
      orderBy: 'created_at DESC, step ASC',
    );
    return rows.map(KResistanceStep.fromRow).toList(growable: false);
  }

  // ---------------------------------------------------------------- 埋点

  Future<String?> readMeta(String key) async {
    final List<Map<String, Object?>> rows = await db.query(
      'k_meta',
      columns: <String>['v'],
      where: 'k = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return '${rows.first['v']}';
  }

  Future<void> writeMeta(String key, String value) async {
    await db.insert(
      'k_meta',
      <String, Object?>{'k': key, 'v': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> readCounter(String key) async {
    return int.tryParse(await readMeta(key) ?? '0') ?? 0;
  }

  Future<void> _bumpCounter(String key) async {
    await writeMeta(key, (await readCounter(key) + 1).toString());
  }

  /// 十五分钟后答「想」的比例。只写入 k_meta，供自查，不展示。
  Future<double> _refreshWantMoreRate() async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS answered,
        SUM(CASE WHEN want_more = 1 THEN 1 ELSE 0 END) AS yes
      FROM k_burn WHERE want_more IS NOT NULL
      ''',
    );
    final int answered = rows.isEmpty ? 0 : _asInt(rows.first['answered']);
    final int yes = rows.isEmpty ? 0 : _asInt(rows.first['yes']);
    final double rate = answered == 0 ? 0.0 : yes / answered;
    await writeMeta(metaBurnWantMoreRate, rate.toStringAsFixed(4));
    return rate;
  }

  /// 本地自查用的三个数。界面不得调用它来渲染。
  Future<Map<String, num>> localMetrics() async {
    return <String, num>{
      metaRecallSessions: await readCounter(metaRecallSessions),
      metaReleasedCount: await readCounter(metaReleasedCount),
      metaBurnWantMoreRate:
          double.tryParse(await readMeta(metaBurnWantMoreRate) ?? '0') ?? 0.0,
    };
  }
}
