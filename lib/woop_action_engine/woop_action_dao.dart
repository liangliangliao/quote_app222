import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../data/kv_dao.dart';
import 'woop_action_models.dart';

/// WOOP 行动引擎独立 DAO。
///
/// 仅创建 woop_action_* 数据表与 ai_prompt.woop_action_engine.* KV，
/// 不复用其他业务模块表，确保作为单独模块落地。
class WoopActionDao {
  static const String profileKey = 'woop_action_engine.profile.v1';
  final KeyValueDao _kv = KeyValueDao();

  Future<Database> get _db async {
    final database = await AppDatabase.instance();
    await ensureTables(db: database);
    return database;
  }

  Future<void> ensureTables({Database? db}) async {
    final database = db ?? await AppDatabase.instance();
    await database.execute('''
      CREATE TABLE IF NOT EXISTS woop_action_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        source TEXT,
        scene TEXT,
        title TEXT,
        raw_input TEXT,
        current_judgement TEXT,
        wish TEXT,
        outcome TEXT,
        obstacle TEXT,
        obstacle_type TEXT,
        obstacle_tags_json TEXT,
        plan_if TEXT,
        plan_then TEXT,
        first_action TEXT,
        review_question TEXT,
        reminder TEXT,
        feasibility TEXT,
        importance TEXT,
        controllability TEXT,
        cost TEXT,
        belongs_to_user TEXT,
        direction TEXT,
        status TEXT,
        ai_response TEXT,
        provider TEXT,
        model_label TEXT,
        from_fallback INTEGER DEFAULT 0
      )
    ''');

    await database.execute('''
      CREATE TABLE IF NOT EXISTS woop_action_reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_id INTEGER NOT NULL,
        created_at_ms INTEGER NOT NULL,
        result TEXT,
        actual_event TEXT,
        obstacle_appeared TEXT,
        plan_worked TEXT,
        new_obstacle TEXT,
        next_adjustment TEXT,
        note TEXT,
        FOREIGN KEY(card_id) REFERENCES woop_action_cards(id) ON DELETE CASCADE
      )
    ''');

    await database.execute('CREATE INDEX IF NOT EXISTS idx_woop_action_cards_status ON woop_action_cards(status, updated_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_woop_action_cards_scene ON woop_action_cards(scene, updated_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_woop_action_reviews_card ON woop_action_reviews(card_id, created_at_ms DESC)');


    await database.execute('''
      CREATE TABLE IF NOT EXISTS woop_action_plan_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_id INTEGER NOT NULL,
        created_at_ms INTEGER NOT NULL,
        trigger_text TEXT,
        action_text TEXT,
        result TEXT,
        note TEXT,
        FOREIGN KEY(card_id) REFERENCES woop_action_cards(id) ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE TABLE IF NOT EXISTS woop_action_daily_checkins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        date_key TEXT NOT NULL,
        energy TEXT,
        mood TEXT,
        main_wish TEXT,
        selected_card_id INTEGER DEFAULT 0,
        note TEXT
      )
    ''');

    await database.execute('CREATE INDEX IF NOT EXISTS idx_woop_action_plan_logs_card ON woop_action_plan_logs(card_id, created_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_woop_action_daily_checkins_date ON woop_action_daily_checkins(date_key, created_at_ms DESC)');


    await database.execute('''
      CREATE TABLE IF NOT EXISTS woop_action_experiments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_id INTEGER NOT NULL,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        title TEXT,
        hypothesis TEXT,
        trigger_text TEXT,
        action_text TEXT,
        expected_difficulty TEXT,
        scheduled_at_ms INTEGER DEFAULT 0,
        status TEXT,
        result TEXT,
        learning TEXT,
        FOREIGN KEY(card_id) REFERENCES woop_action_cards(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_woop_action_experiments_status ON woop_action_experiments(status, updated_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_woop_action_experiments_card ON woop_action_experiments(card_id, created_at_ms DESC)');

    await database.execute('''
      CREATE TABLE IF NOT EXISTS woop_action_course_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unit_id TEXT NOT NULL UNIQUE,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        completed_at_ms INTEGER DEFAULT 0,
        status TEXT,
        reflection TEXT
      )
    ''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_woop_action_course_progress_status ON woop_action_course_progress(status, updated_at_ms DESC)');
  }

  Future<int> upsertCard(WoopActionCard card) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = card.copyWith(
      createdAtMs: card.createdAtMs == 0 ? now : card.createdAtMs,
      updatedAtMs: now,
    ).toDbMap();
    if (card.id > 0) {
      await database.update('woop_action_cards', data, where: 'id = ?', whereArgs: <Object?>[card.id]);
      return card.id;
    }
    return database.insert('woop_action_cards', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateStatus(int id, String status) async {
    final database = await _db;
    await database.update(
      'woop_action_cards',
      <String, Object?>{'status': status, 'updated_at_ms': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<List<WoopActionCard>> listCards({int limit = 80, String? status}) async {
    final database = await _db;
    final rows = await database.query(
      'woop_action_cards',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : <Object?>[status],
      orderBy: 'updated_at_ms DESC, id DESC',
      limit: limit,
    );
    return rows.map(WoopActionCard.fromDb).toList(growable: false);
  }

  Future<WoopActionCard?> getCard(int id) async {
    final database = await _db;
    final rows = await database.query('woop_action_cards', where: 'id = ?', whereArgs: <Object?>[id], limit: 1);
    if (rows.isEmpty) return null;
    return WoopActionCard.fromDb(rows.first);
  }

  Future<int> addReview(WoopActionReview review) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await database.insert(
      'woop_action_reviews',
      WoopActionReview(
        cardId: review.cardId,
        createdAtMs: review.createdAtMs == 0 ? now : review.createdAtMs,
        result: review.result,
        actualEvent: review.actualEvent,
        obstacleAppeared: review.obstacleAppeared,
        planWorked: review.planWorked,
        newObstacle: review.newObstacle,
        nextAdjustment: review.nextAdjustment,
        note: review.note,
      ).toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await database.update(
      'woop_action_cards',
      <String, Object?>{'updated_at_ms': now, if (review.result == 'done') 'status': 'done'},
      where: 'id = ?',
      whereArgs: <Object?>[review.cardId],
    );
    return id;
  }

  Future<List<WoopActionReview>> listReviews(int cardId, {int limit = 30}) async {
    final database = await _db;
    final rows = await database.query(
      'woop_action_reviews',
      where: 'card_id = ?',
      whereArgs: <Object?>[cardId],
      orderBy: 'created_at_ms DESC, id DESC',
      limit: limit,
    );
    return rows.map(WoopActionReview.fromDb).toList(growable: false);
  }

  Future<Map<String, int>> counts() async {
    final database = await _db;
    Future<int> countWhere(String where, List<Object?> args) async {
      final rows = await database.rawQuery('SELECT COUNT(*) AS c FROM woop_action_cards WHERE $where', args);
      final raw = rows.isEmpty ? 0 : rows.first['c'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse((raw ?? '0').toString()) ?? 0;
    }

    final totalRows = await database.rawQuery('SELECT COUNT(*) AS c FROM woop_action_cards');
    final reviewRows = await database.rawQuery('SELECT COUNT(*) AS c FROM woop_action_reviews');
    final planLogRows = await database.rawQuery('SELECT COUNT(*) AS c FROM woop_action_plan_logs');
    final checkinRows = await database.rawQuery('SELECT COUNT(*) AS c FROM woop_action_daily_checkins');
    final experimentRows = await database.rawQuery('SELECT COUNT(*) AS c FROM woop_action_experiments');
    final courseRows = await database.rawQuery('SELECT COUNT(*) AS c FROM woop_action_course_progress');
    int rawCount(List<Map<String, Object?>> rows) {
      final raw = rows.isEmpty ? 0 : rows.first['c'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse((raw ?? '0').toString()) ?? 0;
    }

    return <String, int>{
      'total': rawCount(totalRows),
      'active': await countWhere('status = ?', <Object?>['active']),
      'done': await countWhere('status = ?', <Object?>['done']),
      'paused': await countWhere('status IN (?, ?)', <Object?>['paused', 'archived']),
      'dropped': await countWhere('status = ?', <Object?>['dropped']),
      'reviews': rawCount(reviewRows),
      'planLogs': rawCount(planLogRows),
      'plan_logs': rawCount(planLogRows),
      'checkins': rawCount(checkinRows),
      'daily_checkins': rawCount(checkinRows),
      'experiments': rawCount(experimentRows),
      'courseProgress': rawCount(courseRows),
      'course_progress': rawCount(courseRows),
    };
  }

  Future<Map<String, int>> obstacleTagCounts({int limit = 200}) async {
    final cards = await listCards(limit: limit);
    final counts = <String, int>{};
    for (final card in cards) {
      for (final tag in card.obstacleTags) {
        final t = tag.trim();
        if (t.isEmpty) continue;
        counts[t] = (counts[t] ?? 0) + 1;
      }
      final type = card.obstacleType.trim();
      if (type.isNotEmpty) counts[type] = (counts[type] ?? 0) + 1;
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map<String, int>.fromEntries(entries.take(12));
  }


  Future<List<WoopActionCard>> listCardsByStatuses(List<String> statuses, {int limit = 200}) async {
    if (statuses.isEmpty) return listCards(limit: limit);
    final database = await _db;
    final marks = List<String>.filled(statuses.length, '?').join(',');
    final rows = await database.query(
      'woop_action_cards',
      where: 'status IN ($marks)',
      whereArgs: statuses,
      orderBy: 'updated_at_ms DESC, id DESC',
      limit: limit,
    );
    return rows.map(WoopActionCard.fromDb).toList(growable: false);
  }

  Future<List<WoopActionCard>> listCardsByDirection(String direction, {int limit = 100}) async {
    final database = await _db;
    final rows = await database.query(
      'woop_action_cards',
      where: 'direction = ?',
      whereArgs: <Object?>[direction],
      orderBy: 'updated_at_ms DESC, id DESC',
      limit: limit,
    );
    return rows.map(WoopActionCard.fromDb).toList(growable: false);
  }

  Future<List<WoopActionReview>> listRecentReviews({int limit = 80}) async {
    final database = await _db;
    final rows = await database.query(
      'woop_action_reviews',
      orderBy: 'created_at_ms DESC, id DESC',
      limit: limit,
    );
    return rows.map(WoopActionReview.fromDb).toList(growable: false);
  }

  Future<void> deleteCard(int id) async {
    final database = await _db;
    await database.delete('woop_action_experiments', where: 'card_id = ?', whereArgs: <Object?>[id]);
    await database.delete('woop_action_plan_logs', where: 'card_id = ?', whereArgs: <Object?>[id]);
    await database.delete('woop_action_reviews', where: 'card_id = ?', whereArgs: <Object?>[id]);
    await database.delete('woop_action_cards', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<String> historySummaryJson({int limit = 120}) async {
    final cards = await listCards(limit: limit);
    final reviews = await listRecentReviews(limit: limit);
    final tags = await obstacleTagCounts(limit: limit);
    final payload = <String, Object?>{
      'cards_total': cards.length,
      'status_counts': await counts(),
      'top_obstacle_tags': tags,
      'cards': cards.take(40).map((c) => <String, Object?>{
        'id': c.id,
        'scene': c.scene,
        'status': c.status,
        'direction': c.direction,
        'wish': c.wish,
        'outcome': c.outcome,
        'obstacle': c.obstacle,
        'obstacle_type': c.obstacleType,
        'obstacle_tags': c.obstacleTags,
        'plan_if': c.planIf,
        'plan_then': c.planThen,
        'first_action': c.firstAction,
        'importance': c.importance,
        'feasibility': c.feasibility,
        'controllability': c.controllability,
        'cost': c.cost,
        'belongs_to_user': c.belongsToUser,
      }).toList(growable: false),
      'recent_reviews': reviews.take(40).map((r) => <String, Object?>{
        'card_id': r.cardId,
        'result': r.result,
        'actual_event': r.actualEvent,
        'obstacle_appeared': r.obstacleAppeared,
        'plan_worked': r.planWorked,
        'new_obstacle': r.newObstacle,
        'next_adjustment': r.nextAdjustment,
        'note': r.note,
      }).toList(growable: false),
    };
    return jsonEncode(payload);
  }

  Future<int> addPlanLog(WoopActionPlanLog log) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.insert(
      'woop_action_plan_logs',
      WoopActionPlanLog(
        id: log.id,
        cardId: log.cardId,
        createdAtMs: log.createdAtMs == 0 ? now : log.createdAtMs,
        triggerText: log.triggerText,
        actionText: log.actionText,
        result: log.result,
        note: log.note,
      ).toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WoopActionPlanLog>> listPlanLogs({int? cardId, int limit = 100}) async {
    final database = await _db;
    final rows = await database.query(
      'woop_action_plan_logs',
      where: cardId == null ? null : 'card_id = ?',
      whereArgs: cardId == null ? null : <Object?>[cardId],
      orderBy: 'created_at_ms DESC, id DESC',
      limit: limit,
    );
    return rows.map(WoopActionPlanLog.fromDb).toList(growable: false);
  }

  Future<int> addDailyCheckIn(WoopActionDailyCheckIn checkIn) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.insert(
      'woop_action_daily_checkins',
      WoopActionDailyCheckIn(
        id: checkIn.id,
        createdAtMs: checkIn.createdAtMs == 0 ? now : checkIn.createdAtMs,
        dateKey: checkIn.dateKey,
        energy: checkIn.energy,
        mood: checkIn.mood,
        mainWish: checkIn.mainWish,
        selectedCardId: checkIn.selectedCardId,
        note: checkIn.note,
      ).toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WoopActionDailyCheckIn>> listDailyCheckIns({String? dateKey, int limit = 60}) async {
    final database = await _db;
    final rows = await database.query(
      'woop_action_daily_checkins',
      where: dateKey == null ? null : 'date_key = ?',
      whereArgs: dateKey == null ? null : <Object?>[dateKey],
      orderBy: 'created_at_ms DESC, id DESC',
      limit: limit,
    );
    return rows.map(WoopActionDailyCheckIn.fromDb).toList(growable: false);
  }

  Future<String> dailyCockpitJson({int limit = 80}) async {
    final cards = await listCardsByStatuses(<String>['active'], limit: limit);
    final logs = await listPlanLogs(limit: limit);
    final checkins = await listDailyCheckIns(limit: limit);
    return jsonEncode(<String, Object?>{
      'active_cards': cards.map((c) => <String, Object?>{
        'id': c.id,
        'wish': c.wish,
        'obstacle': c.obstacle,
        'plan_if': c.planIf,
        'plan_then': c.planThen,
        'first_action': c.firstAction,
        'direction': c.direction,
      }).toList(growable: false),
      'recent_plan_logs': logs.take(30).map((l) => <String, Object?>{
        'card_id': l.cardId,
        'result': l.result,
        'trigger_text': l.triggerText,
        'action_text': l.actionText,
        'note': l.note,
      }).toList(growable: false),
      'recent_checkins': checkins.take(20).map((c) => <String, Object?>{
        'date_key': c.dateKey,
        'energy': c.energy,
        'mood': c.mood,
        'main_wish': c.mainWish,
        'selected_card_id': c.selectedCardId,
        'note': c.note,
      }).toList(growable: false),
    });
  }


  Future<WoopActionProfile> getProfile() async {
    final raw = await _kv.getString(profileKey);
    return WoopActionProfile.fromRaw(raw);
  }

  Future<void> saveProfile(WoopActionProfile profile) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = WoopActionProfile(
      updatedAtMs: now,
      userValues: profile.userValues,
      lifeDomains: profile.lifeDomains,
      commonObstacles: profile.commonObstacles,
      preferredActionWindow: profile.preferredActionWindow,
      supportBoundary: profile.supportBoundary,
      professionalHelpReminder: profile.professionalHelpReminder,
    );
    await _kv.setString(profileKey, jsonEncode(next.toJson()));
  }

  Future<String> profileContextJson() async {
    final profile = await getProfile();
    if (profile.isEmpty) return '';
    return jsonEncode(<String, Object?>{
      'woop_action_profile': profile.toJson(),
      'profile_context_text': profile.toContextText(),
    });
  }


  Future<int> addExperiment(WoopActionExperiment experiment) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.insert(
      'woop_action_experiments',
      WoopActionExperiment(
        id: experiment.id,
        cardId: experiment.cardId,
        createdAtMs: experiment.createdAtMs == 0 ? now : experiment.createdAtMs,
        updatedAtMs: experiment.updatedAtMs == 0 ? now : experiment.updatedAtMs,
        title: experiment.title,
        hypothesis: experiment.hypothesis,
        triggerText: experiment.triggerText,
        actionText: experiment.actionText,
        expectedDifficulty: experiment.expectedDifficulty,
        scheduledAtMs: experiment.scheduledAtMs,
        status: experiment.status,
        result: experiment.result,
        learning: experiment.learning,
      ).toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WoopActionExperiment>> listExperiments({int? cardId, String? status, int limit = 120}) async {
    final database = await _db;
    final whereParts = <String>[];
    final args = <Object?>[];
    if (cardId != null) {
      whereParts.add('card_id = ?');
      args.add(cardId);
    }
    if (status != null) {
      whereParts.add('status = ?');
      args.add(status);
    }
    final rows = await database.query(
      'woop_action_experiments',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'updated_at_ms DESC, id DESC',
      limit: limit,
    );
    return rows.map(WoopActionExperiment.fromDb).toList(growable: false);
  }

  Future<void> updateExperimentStatus(
    int id, {
    required String status,
    String? result,
    String? learning,
  }) async {
    final database = await _db;
    await database.update(
      'woop_action_experiments',
      <String, Object?>{
        'status': status,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
        if (result != null) 'result': result,
        if (learning != null) 'learning': learning,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }


  Future<int> upsertCourseProgress(WoopActionCourseProgress progress) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = WoopActionCourseProgress(
      id: progress.id,
      unitId: progress.unitId,
      createdAtMs: progress.createdAtMs == 0 ? now : progress.createdAtMs,
      updatedAtMs: now,
      completedAtMs: progress.completedAtMs,
      status: progress.status,
      reflection: progress.reflection,
    ).toDbMap();
    if (progress.id > 0) {
      await database.update('woop_action_course_progress', data, where: 'id = ?', whereArgs: <Object?>[progress.id]);
      return progress.id;
    }
    final existing = await database.query('woop_action_course_progress', where: 'unit_id = ?', whereArgs: <Object?>[progress.unitId], limit: 1);
    if (existing.isNotEmpty) {
      final id = (existing.first['id'] as int?) ?? 0;
      await database.update('woop_action_course_progress', data, where: 'id = ?', whereArgs: <Object?>[id]);
      return id;
    }
    return database.insert('woop_action_course_progress', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markCourseUnitDone(String unitId, {String reflection = ''}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await upsertCourseProgress(WoopActionCourseProgress(
      unitId: unitId,
      createdAtMs: now,
      updatedAtMs: now,
      completedAtMs: now,
      status: 'done',
      reflection: reflection,
    ));
  }

  Future<List<WoopActionCourseProgress>> listCourseProgress({int limit = 120}) async {
    final database = await _db;
    final rows = await database.query(
      'woop_action_course_progress',
      orderBy: 'updated_at_ms DESC, id DESC',
      limit: limit,
    );
    return rows.map(WoopActionCourseProgress.fromDb).toList(growable: false);
  }

  Future<Map<String, WoopActionCourseProgress>> courseProgressMap() async {
    final rows = await listCourseProgress(limit: 200);
    return <String, WoopActionCourseProgress>{for (final r in rows) r.unitId: r};
  }

  Future<String> fullExportJson({int limit = 500}) async {
    final cards = await listCards(limit: limit);
    final reviews = await listRecentReviews(limit: limit);
    final logs = await listPlanLogs(limit: limit);
    final checkins = await listDailyCheckIns(limit: limit);
    final experiments = await listExperiments(limit: limit);
    final profile = await getProfile();
    final courseProgress = await listCourseProgress(limit: limit);
    final payload = <String, Object?>{
      'module': 'woop_action_engine',
      'schema_version': 7,
      'exported_at_ms': DateTime.now().millisecondsSinceEpoch,
      'profile': profile.toJson(),
      'counts': await counts(),
      'obstacle_tag_counts': await obstacleTagCounts(limit: limit),
      'cards': cards.map((c) => c.toJson()).toList(growable: false),
      'reviews': reviews.map((r) => <String, Object?>{
        'id': r.id,
        'card_id': r.cardId,
        'created_at_ms': r.createdAtMs,
        'result': r.result,
        'actual_event': r.actualEvent,
        'obstacle_appeared': r.obstacleAppeared,
        'plan_worked': r.planWorked,
        'new_obstacle': r.newObstacle,
        'next_adjustment': r.nextAdjustment,
        'note': r.note,
      }).toList(growable: false),
      'plan_logs': logs.map((l) => <String, Object?>{
        'id': l.id,
        'card_id': l.cardId,
        'created_at_ms': l.createdAtMs,
        'trigger_text': l.triggerText,
        'action_text': l.actionText,
        'result': l.result,
        'note': l.note,
      }).toList(growable: false),
      'daily_checkins': checkins.map((c) => <String, Object?>{
        'id': c.id,
        'created_at_ms': c.createdAtMs,
        'date_key': c.dateKey,
        'energy': c.energy,
        'mood': c.mood,
        'main_wish': c.mainWish,
        'selected_card_id': c.selectedCardId,
        'note': c.note,
      }).toList(growable: false),
      'experiments': experiments.map((e) => e.toJson()).toList(growable: false),
      'course_progress': courseProgress.map((p) => p.toJson()).toList(growable: false),
    };
    return jsonEncode(payload);
  }

  Future<void> clearAll() async {
    final database = await _db;
    await database.delete('woop_action_course_progress');
    await database.delete('woop_action_experiments');
    await database.delete('woop_action_plan_logs');
    await database.delete('woop_action_daily_checkins');
    await database.delete('woop_action_reviews');
    await database.delete('woop_action_cards');
  }

  Future<String?> getPromptOverride(String id) => _kv.getString('ai_prompt.woop_action_engine.$id');
  Future<void> setPromptOverride(String id, String value) => _kv.setString('ai_prompt.woop_action_engine.$id', value);
}
