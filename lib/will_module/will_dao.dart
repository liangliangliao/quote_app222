import 'package:quote_app/data/db.dart';
import 'package:sqflite/sqflite.dart';

import 'will_models.dart';

class WillDao {
  Future<Database> _db() => AppDatabase.instance();

  Future<void> ensureTables() async {
    final db = await _db();
    await db.execute("""
      CREATE TABLE IF NOT EXISTS will_if_then_plan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_title TEXT NOT NULL,
        if_text TEXT NOT NULL DEFAULT '',
        then_text TEXT NOT NULL DEFAULT '',
        updated_at_ms INTEGER NOT NULL DEFAULT 0,
        UNIQUE(task_title) ON CONFLICT REPLACE
      )
    """);
    await db.execute("""
      CREATE TABLE IF NOT EXISTS will_review_entry (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_title TEXT NOT NULL DEFAULT '',
        source_execution_id INTEGER,
        dominant_idea TEXT NOT NULL DEFAULT '',
        opposing_idea TEXT NOT NULL DEFAULT '',
        effort_point TEXT NOT NULL DEFAULT '',
        action_taken TEXT NOT NULL DEFAULT '',
        next_step TEXT NOT NULL DEFAULT '',
        updated_at_ms INTEGER NOT NULL DEFAULT 0
      )
    """);
    await _safeAddColumn(db, 'will_review_entry', 'task_title', "TEXT NOT NULL DEFAULT ''");
    await _safeAddColumn(db, 'will_review_entry', 'source_execution_id', 'INTEGER');
    await db.execute("""
      CREATE TABLE IF NOT EXISTS will_task_execution (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_title TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        effort_level INTEGER NOT NULL DEFAULT 3,
        completed_at_ms INTEGER NOT NULL DEFAULT 0
      )
    """);
    await db.execute("""
      CREATE TABLE IF NOT EXISTS will_zone_visit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        zone_title TEXT NOT NULL,
        visited_at_ms INTEGER NOT NULL DEFAULT 0
      )
    """);

    await db.execute("""
      CREATE TABLE IF NOT EXISTS will_stage_milestone (
        stage_key TEXT PRIMARY KEY,
        stage_label TEXT NOT NULL DEFAULT '',
        detail TEXT NOT NULL DEFAULT '',
        achieved_at_ms INTEGER NOT NULL DEFAULT 0
      )
    """);
    await db.execute("""
      CREATE TABLE IF NOT EXISTS will_stage_runtime_state (
        singleton_id INTEGER PRIMARY KEY,
        current_stage_key TEXT NOT NULL DEFAULT '',
        previous_stage_key TEXT NOT NULL DEFAULT '',
        changed_at_ms INTEGER NOT NULL DEFAULT 0,
        notified_at_ms INTEGER NOT NULL DEFAULT 0
      )
    """);
    await _safeAddColumn(db, 'will_stage_runtime_state', 'notified_at_ms', 'INTEGER NOT NULL DEFAULT 0');
    await db.execute("""
      CREATE TABLE IF NOT EXISTS will_suggestion_state (
        suggestion_key TEXT PRIMARY KEY,
        last_opened_at_ms INTEGER NOT NULL DEFAULT 0,
        completed_at_ms INTEGER NOT NULL DEFAULT 0,
        action_count INTEGER NOT NULL DEFAULT 0
      )
    """);
  }

  Future<void> _safeAddColumn(Database db, String table, String column, String typeDecl) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $typeDecl');
    } catch (_) {
      // Column likely already exists.
    }
  }

  Future<WillSavedPlan?> getPlanByTaskTitle(String taskTitle) async {
    await ensureTables();
    final db = await _db();
    final rows = await db.query(
      'will_if_then_plan',
      where: 'task_title = ?',
      whereArgs: [taskTitle],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return WillSavedPlan(
      id: row['id'] as int?,
      taskTitle: (row['task_title'] ?? '').toString(),
      ifText: (row['if_text'] ?? '').toString(),
      thenText: (row['then_text'] ?? '').toString(),
      updatedAtMs: (row['updated_at_ms'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> savePlan({
    required String taskTitle,
    required String ifText,
    required String thenText,
  }) async {
    await ensureTables();
    final db = await _db();
    await db.insert(
      'will_if_then_plan',
      {
        'task_title': taskTitle,
        'if_text': ifText,
        'then_text': thenText,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveReview({
    required String dominantIdea,
    required String opposingIdea,
    required String effortPoint,
    required String actionTaken,
    required String nextStep,
    String taskTitle = '',
    int? sourceExecutionId,
  }) async {
    await ensureTables();
    final db = await _db();
    await db.insert('will_review_entry', {
      'task_title': taskTitle,
      'source_execution_id': sourceExecutionId,
      'dominant_idea': dominantIdea,
      'opposing_idea': opposingIdea,
      'effort_point': effortPoint,
      'action_taken': actionTaken,
      'next_step': nextStep,
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  WillReviewEntry _mapReview(Map<String, Object?> row) => WillReviewEntry(
        id: row['id'] as int?,
        taskTitle: (row['task_title'] ?? '').toString(),
        sourceExecutionId: (row['source_execution_id'] as num?)?.toInt(),
        dominantIdea: (row['dominant_idea'] ?? '').toString(),
        opposingIdea: (row['opposing_idea'] ?? '').toString(),
        effortPoint: (row['effort_point'] ?? '').toString(),
        actionTaken: (row['action_taken'] ?? '').toString(),
        nextStep: (row['next_step'] ?? '').toString(),
        updatedAtMs: (row['updated_at_ms'] as num?)?.toInt() ?? 0,
      );

  Future<List<WillReviewEntry>> getRecentReviews({int limit = 8}) async {
    await ensureTables();
    final db = await _db();
    final rows = await db.query(
      'will_review_entry',
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
    return rows.map(_mapReview).toList();
  }

  Future<WillReviewEntry?> getLatestReview() async {
    final items = await getRecentReviews(limit: 1);
    return items.isEmpty ? null : items.first;
  }

  Future<List<WillReviewEntry>> getRecentReviewsByTaskTitle(String taskTitle, {int limit = 12}) async {
    await ensureTables();
    final db = await _db();
    final rows = await db.query(
      'will_review_entry',
      where: 'task_title = ?',
      whereArgs: [taskTitle],
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
    return rows.map(_mapReview).toList();
  }

  Future<List<WillReviewEntry>> getRecentReviewsByExecutionId(int executionId, {int limit = 6}) async {
    await ensureTables();
    final db = await _db();
    final rows = await db.query(
      'will_review_entry',
      where: 'source_execution_id = ?',
      whereArgs: [executionId],
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
    return rows.map(_mapReview).toList();
  }

  Future<void> saveTaskExecution({
    required String taskTitle,
    required String note,
    required int effortLevel,
  }) async {
    await ensureTables();
    final db = await _db();
    await db.insert('will_task_execution', {
      'task_title': taskTitle,
      'note': note,
      'effort_level': effortLevel,
      'completed_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  WillTaskExecutionEntry _mapExecution(Map<String, Object?> row) => WillTaskExecutionEntry(
        id: row['id'] as int?,
        taskTitle: (row['task_title'] ?? '').toString(),
        note: (row['note'] ?? '').toString(),
        effortLevel: (row['effort_level'] as num?)?.toInt() ?? 3,
        completedAtMs: (row['completed_at_ms'] as num?)?.toInt() ?? 0,
      );

  Future<List<WillTaskExecutionEntry>> getRecentTaskExecutionsByTaskTitle(
    String taskTitle, {
    int limit = 12,
  }) async {
    await ensureTables();
    final db = await _db();
    final rows = await db.query(
      'will_task_execution',
      where: 'task_title = ?',
      whereArgs: [taskTitle],
      orderBy: 'completed_at_ms DESC',
      limit: limit,
    );
    return rows.map(_mapExecution).toList();
  }

  Future<int> getTaskExecutionCount(String taskTitle) async {
    await ensureTables();
    final db = await _db();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM will_task_execution WHERE task_title = ?',
      [taskTitle],
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<List<WillTaskExecutionEntry>> getRecentTaskExecutions({int limit = 20}) async {
    await ensureTables();
    final db = await _db();
    final rows = await db.query(
      'will_task_execution',
      orderBy: 'completed_at_ms DESC',
      limit: limit,
    );
    return rows.map(_mapExecution).toList();
  }

  Future<WillTaskExecutionEntry?> getLatestTaskExecutionForTask(String taskTitle) async {
    final items = await getRecentTaskExecutionsByTaskTitle(taskTitle, limit: 1);
    return items.isEmpty ? null : items.first;
  }

  Future<void> saveZoneVisit(String zoneTitle) async {
    await ensureTables();
    final db = await _db();
    await db.insert('will_zone_visit', {
      'zone_title': zoneTitle,
      'visited_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  WillZoneVisitEntry _mapZoneVisit(Map<String, Object?> row) => WillZoneVisitEntry(
        id: row['id'] as int?,
        zoneTitle: (row['zone_title'] ?? '').toString(),
        visitedAtMs: (row['visited_at_ms'] as num?)?.toInt() ?? 0,
      );

  Future<List<WillZoneVisitEntry>> getRecentZoneVisits({int limit = 20}) async {
    await ensureTables();
    final db = await _db();
    final rows = await db.query(
      'will_zone_visit',
      orderBy: 'visited_at_ms DESC',
      limit: limit,
    );
    return rows.map(_mapZoneVisit).toList();
  }

  Future<List<WillNamedCount>> getZoneVisitCounts({int limit = 12}) async {
    await ensureTables();
    final db = await _db();
    final rows = await db.rawQuery(
      'SELECT zone_title AS label, COUNT(*) AS c FROM will_zone_visit GROUP BY zone_title ORDER BY c DESC, zone_title COLLATE NOCASE ASC LIMIT ?',
      [limit],
    );
    return rows
        .map((e) => WillNamedCount(label: (e['label'] ?? '').toString(), count: (e['c'] as num?)?.toInt() ?? 0))
        .where((e) => e.label.isNotEmpty)
        .toList();
  }



  WillStageMilestoneEntry _mapStageMilestone(Map<String, Object?> row) => WillStageMilestoneEntry(
        stageKey: (row['stage_key'] ?? '').toString(),
        stageLabel: (row['stage_label'] ?? '').toString(),
        detail: (row['detail'] ?? '').toString(),
        achievedAtMs: (row['achieved_at_ms'] as num?)?.toInt() ?? 0,
      );

  Future<void> ensureStageMilestone({
    required String stageKey,
    required String stageLabel,
    required String detail,
  }) async {
    await ensureTables();
    final db = await _db();
    final rows = await db.query('will_stage_milestone', where: 'stage_key = ?', whereArgs: [stageKey], limit: 1);
    if (rows.isNotEmpty) return;
    await db.insert('will_stage_milestone', {
      'stage_key': stageKey,
      'stage_label': stageLabel,
      'detail': detail,
      'achieved_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<WillStageMilestoneEntry>> getStageMilestones({int limit = 12}) async {
    await ensureTables();
    final db = await _db();
    final rows = await db.query(
      'will_stage_milestone',
      orderBy: 'achieved_at_ms DESC',
      limit: limit,
    );
    return rows.map(_mapStageMilestone).toList();
  }

  WillStageRuntimeState _mapStageRuntimeState(Map<String, Object?> row) => WillStageRuntimeState(
        currentStageKey: (row['current_stage_key'] ?? '').toString(),
        previousStageKey: (row['previous_stage_key'] ?? '').toString(),
        changedAtMs: (row['changed_at_ms'] as num?)?.toInt() ?? 0,
        notifiedAtMs: (row['notified_at_ms'] as num?)?.toInt() ?? 0,
      );

  Future<WillStageRuntimeState?> getStageRuntimeState() async {
    await ensureTables();
    final db = await _db();
    final rows = await db.query('will_stage_runtime_state', where: 'singleton_id = 1', limit: 1);
    if (rows.isEmpty) return null;
    return _mapStageRuntimeState(rows.first);
  }

  Future<WillStageRuntimeState> syncCurrentStage({required String currentStageKey}) async {
    await ensureTables();
    final db = await _db();
    final existing = await getStageRuntimeState();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (existing == null) {
      await db.insert('will_stage_runtime_state', {
        'singleton_id': 1,
        'current_stage_key': currentStageKey,
        'previous_stage_key': '',
        'changed_at_ms': now,
        'notified_at_ms': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return WillStageRuntimeState(currentStageKey: currentStageKey, previousStageKey: '', changedAtMs: now, notifiedAtMs: 0);
    }
    if (existing.currentStageKey == currentStageKey) {
      return existing;
    }
    final updated = WillStageRuntimeState(
      currentStageKey: currentStageKey,
      previousStageKey: existing.currentStageKey,
      changedAtMs: now,
      notifiedAtMs: 0,
    );
    await db.insert('will_stage_runtime_state', {
      'singleton_id': 1,
      'current_stage_key': updated.currentStageKey,
      'previous_stage_key': updated.previousStageKey,
      'changed_at_ms': updated.changedAtMs,
      'notified_at_ms': updated.notifiedAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return updated;
  }

  Future<void> markStageChangeNotified() async {
    await ensureTables();
    final db = await _db();
    final existing = await getStageRuntimeState();
    if (existing == null) return;
    await db.insert('will_stage_runtime_state', {
      'singleton_id': 1,
      'current_stage_key': existing.currentStageKey,
      'previous_stage_key': existing.previousStageKey,
      'changed_at_ms': existing.changedAtMs,
      'notified_at_ms': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> getSavedPlanCount() async {
    await ensureTables();
    final db = await _db();
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM will_if_then_plan');
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<int> getReviewCount() async {
    await ensureTables();
    final db = await _db();
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM will_review_entry');
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<int> getExecutionCount() async {
    await ensureTables();
    final db = await _db();
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM will_task_execution');
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<List<String>> getTrackedTaskTitles() async {
    await ensureTables();
    final db = await _db();
    final rows = await db.rawQuery("SELECT DISTINCT task_title AS title FROM will_if_then_plan WHERE task_title != '' UNION SELECT DISTINCT task_title AS title FROM will_review_entry WHERE task_title != '' UNION SELECT DISTINCT task_title AS title FROM will_task_execution WHERE task_title != '' ORDER BY title COLLATE NOCASE ASC");
    return rows.map((e) => (e['title'] ?? '').toString()).where((e) => e.isNotEmpty).toList();
  }

  Future<WillDashboardSummary> getDashboardSummary() async {
    final planCount = await getSavedPlanCount();
    final reviewCount = await getReviewCount();
    final executionCount = await getExecutionCount();
    final taskCount = (await getTrackedTaskTitles()).length;
    final zoneVisitCount = (await getRecentZoneVisits(limit: 1000000)).length;
    return WillDashboardSummary(
      planCount: planCount,
      reviewCount: reviewCount,
      executionCount: executionCount,
      taskCount: taskCount,
      zoneVisitCount: zoneVisitCount,
    );
  }

  Future<List<WillTaskChainSummary>> getTaskChainSummaries({int limit = 12}) async {
    final titles = await getTrackedTaskTitles();
    final List<WillTaskChainSummary> items = [];
    for (final title in titles) {
      final plan = await getPlanByTaskTitle(title);
      final reviews = await getRecentReviewsByTaskTitle(title, limit: 1000);
      final executions = await getRecentTaskExecutionsByTaskTitle(title, limit: 1000);
      items.add(
        WillTaskChainSummary(
          taskTitle: title,
          planCount: plan == null ? 0 : 1,
          executionCount: executions.length,
          reviewCount: reviews.length,
          latestExecutionAtMs: executions.isEmpty ? 0 : executions.first.completedAtMs,
          latestReviewAtMs: reviews.isEmpty ? 0 : reviews.first.updatedAtMs,
        ),
      );
    }
    items.sort((a, b) {
      final at = a.latestExecutionAtMs > a.latestReviewAtMs ? a.latestExecutionAtMs : a.latestReviewAtMs;
      final bt = b.latestExecutionAtMs > b.latestReviewAtMs ? b.latestExecutionAtMs : b.latestReviewAtMs;
      return bt.compareTo(at);
    });
    if (items.length <= limit) return items;
    return items.sublist(0, limit);
  }



  WillSuggestionState _mapSuggestionState(Map<String, Object?> row) => WillSuggestionState(
        suggestionKey: (row['suggestion_key'] ?? '').toString(),
        lastOpenedAtMs: (row['last_opened_at_ms'] as num?)?.toInt() ?? 0,
        completedAtMs: (row['completed_at_ms'] as num?)?.toInt() ?? 0,
        actionCount: (row['action_count'] as num?)?.toInt() ?? 0,
      );

  Future<List<WillSuggestionState>> getSuggestionStates() async {
    await ensureTables();
    final db = await _db();
    final rows = await db.query('will_suggestion_state');
    return rows.map(_mapSuggestionState).toList();
  }

  Future<void> markSuggestionOpened(String key) async {
    await ensureTables();
    final db = await _db();
    final rows = await db.query('will_suggestion_state', where: 'suggestion_key = ?', whereArgs: [key], limit: 1);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (rows.isEmpty) {
      await db.insert('will_suggestion_state', {
        'suggestion_key': key,
        'last_opened_at_ms': now,
        'completed_at_ms': 0,
        'action_count': 1,
      });
    } else {
      final row = rows.first;
      final count = ((row['action_count'] as num?)?.toInt() ?? 0) + 1;
      await db.update(
        'will_suggestion_state',
        {
          'last_opened_at_ms': now,
          'action_count': count,
        },
        where: 'suggestion_key = ?',
        whereArgs: [key],
      );
    }
  }

  Future<void> markSuggestionCompleted(String key) async {
    await ensureTables();
    final db = await _db();
    final rows = await db.query('will_suggestion_state', where: 'suggestion_key = ?', whereArgs: [key], limit: 1);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (rows.isEmpty) {
      await db.insert('will_suggestion_state', {
        'suggestion_key': key,
        'last_opened_at_ms': 0,
        'completed_at_ms': now,
        'action_count': 0,
      });
    } else {
      await db.update(
        'will_suggestion_state',
        {'completed_at_ms': now},
        where: 'suggestion_key = ?',
        whereArgs: [key],
      );
    }
  }

  Future<void> resetSuggestionCompletion(String key) async {
    await ensureTables();
    final db = await _db();
    await db.update(
      'will_suggestion_state',
      {'completed_at_ms': 0},
      where: 'suggestion_key = ?',
      whereArgs: [key],
    );
  }

}
