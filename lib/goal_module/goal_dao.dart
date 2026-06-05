import 'dart:convert';

import 'package:quote_app/data/db.dart';
import 'package:sqflite/sqflite.dart';

import 'goal_concept_seed.dart';
import 'goal_models.dart';
import 'goal_seed.dart';
import 'goal_world_seed.dart';

class GoalDao {
  Future<Database> _db() => AppDatabase.instance();

  Future<void> _safeAddColumn(Database db, String table, String columnSql) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnSql');
    } catch (_) {
      // ignore if column already exists
    }
  }

  Future<void> ensureTables() async {
    final db = await _db();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_course_segment (
        segment_id TEXT PRIMARY KEY,
        segment_no INTEGER NOT NULL,
        source_course TEXT NOT NULL,
        source_course_name TEXT NOT NULL,
        section_title TEXT NOT NULL,
        segment_text TEXT NOT NULL,
        module_group TEXT NOT NULL,
        tags_json TEXT NOT NULL DEFAULT '[]',
        is_locked INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_segment_review (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        segment_id TEXT NOT NULL,
        reviewed_at_ms INTEGER NOT NULL,
        is_favorited INTEGER NOT NULL DEFAULT 0,
        is_difficult INTEGER NOT NULL DEFAULT 0,
        is_key INTEGER NOT NULL DEFAULT 0,
        UNIQUE(segment_id) ON CONFLICT REPLACE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_workshop_draft (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        identity_statement TEXT NOT NULL DEFAULT '',
        vision TEXT NOT NULL DEFAULT '',
        why_text TEXT NOT NULL DEFAULT '',
        reality_problem TEXT NOT NULL DEFAULT '',
        external_expectation TEXT NOT NULL DEFAULT '',
        competing_goal TEXT NOT NULL DEFAULT '',
        lifeline TEXT NOT NULL DEFAULT '',
        stretch_score REAL NOT NULL DEFAULT 5,
        weekly_goal TEXT NOT NULL DEFAULT '',
        first_step TEXT NOT NULL DEFAULT '',
        if_then_text TEXT NOT NULL DEFAULT '',
        updated_at_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _safeAddColumn(db, 'goal_workshop_draft', "identity_statement TEXT NOT NULL DEFAULT ''");
    await _safeAddColumn(db, 'goal_workshop_draft', "reality_problem TEXT NOT NULL DEFAULT ''");
    await _safeAddColumn(db, 'goal_workshop_draft', "external_expectation TEXT NOT NULL DEFAULT ''");
    await _safeAddColumn(db, 'goal_workshop_draft', "competing_goal TEXT NOT NULL DEFAULT ''");
    await _safeAddColumn(db, 'goal_workshop_draft', "weekly_goal TEXT NOT NULL DEFAULT ''");

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_concept_card (
        concept_id TEXT PRIMARY KEY,
        segment_id TEXT NOT NULL,
        concept_title TEXT NOT NULL,
        one_line_definition TEXT NOT NULL,
        what_is_it TEXT NOT NULL,
        why_it_matters TEXT NOT NULL,
        interaction_type TEXT NOT NULL,
        interaction_description TEXT NOT NULL,
        reflection_json TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_action_template (
        action_id TEXT PRIMARY KEY,
        segment_id TEXT NOT NULL,
        concept_id TEXT NOT NULL,
        action_title TEXT NOT NULL,
        action_level TEXT NOT NULL,
        goal_of_action TEXT NOT NULL,
        steps_json TEXT NOT NULL DEFAULT '[]',
        duration_min INTEGER NOT NULL DEFAULT 15,
        failure_plan TEXT NOT NULL DEFAULT '',
        feedback_json TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_action_record (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_id TEXT NOT NULL,
        concept_id TEXT NOT NULL,
        segment_id TEXT NOT NULL,
        started_at_ms INTEGER NOT NULL,
        completed_at_ms INTEGER NOT NULL,
        completion_rate REAL NOT NULL DEFAULT 0,
        feedback_json TEXT NOT NULL DEFAULT '{}',
        reflection_text TEXT NOT NULL DEFAULT '',
        action_title_snapshot TEXT NOT NULL DEFAULT '',
        concept_title_snapshot TEXT NOT NULL DEFAULT '',
        segment_title_snapshot TEXT NOT NULL DEFAULT '',
        action_level_snapshot TEXT NOT NULL DEFAULT ''
      )
    ''');
    await _safeAddColumn(db, 'goal_action_record', "action_title_snapshot TEXT NOT NULL DEFAULT ''");
    await _safeAddColumn(db, 'goal_action_record', "concept_title_snapshot TEXT NOT NULL DEFAULT ''");
    await _safeAddColumn(db, 'goal_action_record', "segment_title_snapshot TEXT NOT NULL DEFAULT ''");
    await _safeAddColumn(db, 'goal_action_record', "action_level_snapshot TEXT NOT NULL DEFAULT ''");

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_world_scene_progress (
        scene_id TEXT PRIMARY KEY,
        completed_task_ids_json TEXT NOT NULL DEFAULT '[]',
        reality_note TEXT NOT NULL DEFAULT '',
        reward_claimed INTEGER NOT NULL DEFAULT 0,
        active_task_id TEXT NOT NULL DEFAULT '',
        reward_claimed_at_ms INTEGER NOT NULL DEFAULT 0,
        simulation_choice_id TEXT NOT NULL DEFAULT '',
        simulation_reflection TEXT NOT NULL DEFAULT '',
        branch_completed_task_ids_json TEXT NOT NULL DEFAULT '[]',
        active_branch_task_id TEXT NOT NULL DEFAULT '',
        updated_at_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _safeAddColumn(db, 'goal_world_scene_progress', "active_task_id TEXT NOT NULL DEFAULT ''");
    await _safeAddColumn(db, 'goal_world_scene_progress', "reward_claimed_at_ms INTEGER NOT NULL DEFAULT 0");
    await _safeAddColumn(db, 'goal_world_scene_progress', "simulation_choice_id TEXT NOT NULL DEFAULT ''");
    await _safeAddColumn(db, 'goal_world_scene_progress', "simulation_reflection TEXT NOT NULL DEFAULT ''");
    await _safeAddColumn(db, 'goal_world_scene_progress', "branch_completed_task_ids_json TEXT NOT NULL DEFAULT '[]'");
    await _safeAddColumn(db, 'goal_world_scene_progress', "active_branch_task_id TEXT NOT NULL DEFAULT ''");

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_world_profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        role_title TEXT NOT NULL DEFAULT '',
        life_area TEXT NOT NULL DEFAULT '',
        real_event TEXT NOT NULL DEFAULT '',
        current_feeling TEXT NOT NULL DEFAULT '',
        desired_identity TEXT NOT NULL DEFAULT '',
        updated_at_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_action_followup (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_record_id INTEGER NOT NULL,
        decision TEXT NOT NULL DEFAULT '',
        reflection_text TEXT NOT NULL DEFAULT '',
        next_step TEXT NOT NULL DEFAULT '',
        weekly_focus TEXT NOT NULL DEFAULT '',
        updated_at_ms INTEGER NOT NULL DEFAULT 0,
        UNIQUE(action_record_id) ON CONFLICT REPLACE
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_action_draft (
        action_id TEXT PRIMARY KEY,
        concept_id TEXT NOT NULL,
        segment_id TEXT NOT NULL,
        started_at_ms INTEGER NOT NULL DEFAULT 0,
        action_title TEXT NOT NULL DEFAULT '',
        action_level TEXT NOT NULL DEFAULT '',
        goal_of_action TEXT NOT NULL DEFAULT '',
        steps_json TEXT NOT NULL DEFAULT '[]',
        duration_min INTEGER NOT NULL DEFAULT 0,
        failure_plan TEXT NOT NULL DEFAULT '',
        feedback_fields_json TEXT NOT NULL DEFAULT '[]',
        checked_json TEXT NOT NULL DEFAULT '[]',
        feedback_values_json TEXT NOT NULL DEFAULT '{}',
        reflection_text TEXT NOT NULL DEFAULT '',
        concept_title_snapshot TEXT NOT NULL DEFAULT '',
        segment_title_snapshot TEXT NOT NULL DEFAULT '',
        updated_at_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_continue_state (
        state_key TEXT PRIMARY KEY,
        target_id TEXT NOT NULL DEFAULT '',
        scroll_offset REAL NOT NULL DEFAULT 0,
        extra_json TEXT NOT NULL DEFAULT '{}',
        updated_at_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_completion_ritual_state (
        ritual_key TEXT PRIMARY KEY,
        shown_at_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_module_reflection (
        ritual_key TEXT PRIMARY KEY,
        source_course TEXT NOT NULL DEFAULT '',
        module_group TEXT NOT NULL DEFAULT '',
        summary_text TEXT NOT NULL DEFAULT '',
        insight_text TEXT NOT NULL DEFAULT '',
        action_text TEXT NOT NULL DEFAULT '',
        updated_at_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_world_timeline_event (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scene_id TEXT NOT NULL DEFAULT '',
        event_type TEXT NOT NULL DEFAULT '',
        title TEXT NOT NULL DEFAULT '',
        body TEXT NOT NULL DEFAULT '',
        branch_choice_id TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_world_status_snapshot (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_type TEXT NOT NULL DEFAULT '',
        source_id TEXT NOT NULL DEFAULT '',
        clarity INTEGER NOT NULL DEFAULT 0,
        alignment INTEGER NOT NULL DEFAULT 0,
        momentum INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_world_identity_evolution (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        stage_key TEXT NOT NULL DEFAULT '',
        stage_title TEXT NOT NULL DEFAULT '',
        stage_subtitle TEXT NOT NULL DEFAULT '',
        headline TEXT NOT NULL DEFAULT '',
        evidence_json TEXT NOT NULL DEFAULT '[]',
        updated_at_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> seedIfNeeded() async {
    final db = await _db();
    await ensureTables();

    Future<void> ensureSeed(String table, List<Map<String, dynamic>> seed) async {
      final cnt = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(1) FROM $table')) ?? 0;
      if (cnt > 0) return;
      await db.transaction((txn) async {
        for (final m in seed) {
          await txn.insert(table, m, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    }

    await ensureSeed('goal_course_segment', goalCourseSeedSegments);
    await ensureSeed('goal_concept_card', goalConceptSeedCards);
    await ensureSeed('goal_action_template', goalActionSeedTemplates);
  }

  Future<List<GoalCourseSegment>> listSegments({String? sourceCourse, String? moduleGroup}) async {
    final db = await _db();
    await seedIfNeeded();
    final where = <String>[];
    final args = <Object?>[];
    if (sourceCourse != null && sourceCourse.isNotEmpty) {
      where.add('source_course=?');
      args.add(sourceCourse);
    }
    if (moduleGroup != null && moduleGroup.isNotEmpty) {
      where.add('module_group=?');
      args.add(moduleGroup);
    }
    final rows = await db.query(
      'goal_course_segment',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'source_course ASC, segment_no ASC',
    );
    return rows.map(GoalCourseSegment.fromRow).toList();
  }

  Future<List<String>> listModuleGroups() async {
    final db = await _db();
    await seedIfNeeded();
    final rows = await db.rawQuery('SELECT DISTINCT module_group FROM goal_course_segment ORDER BY source_course ASC, segment_no ASC');
    return rows.map((e) => (e['module_group'] ?? '').toString()).where((e) => e.isNotEmpty).toList();
  }

  Future<Map<String, int>> getModuleSegmentCounts() async {
    final db = await _db();
    await seedIfNeeded();
    final rows = await db.rawQuery('''
      SELECT module_group, COUNT(1) AS cnt
      FROM goal_course_segment
      GROUP BY module_group
      ORDER BY MIN(source_course), MIN(segment_no)
    ''');
    return {
      for (final r in rows) (r['module_group'] ?? '').toString(): (r['cnt'] as num?)?.toInt() ?? 0,
    };
  }

  Future<GoalCourseSegment?> getSegment(String segmentId) async {
    final db = await _db();
    await seedIfNeeded();
    final rows = await db.query('goal_course_segment', where: 'segment_id=?', whereArgs: [segmentId], limit: 1);
    if (rows.isEmpty) return null;
    return GoalCourseSegment.fromRow(rows.first);
  }

  Future<GoalSegmentReview> getSegmentReview(String segmentId) async {
    final db = await _db();
    await seedIfNeeded();
    final rows = await db.query('goal_segment_review', where: 'segment_id=?', whereArgs: [segmentId], limit: 1);
    if (rows.isEmpty) return GoalSegmentReview.empty(segmentId);
    return GoalSegmentReview.fromRow(rows.first);
  }

  Future<void> saveSegmentReview({
    required String segmentId,
    required bool isFavorited,
    required bool isDifficult,
    required bool isKey,
  }) async {
    final db = await _db();
    await ensureTables();
    await db.insert(
      'goal_segment_review',
      {
        'segment_id': segmentId,
        'reviewed_at_ms': DateTime.now().millisecondsSinceEpoch,
        'is_favorited': isFavorited ? 1 : 0,
        'is_difficult': isDifficult ? 1 : 0,
        'is_key': isKey ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }


  Future<void> touchSegmentReviewed(String segmentId) async {
    final current = await getSegmentReview(segmentId);
    await saveSegmentReview(
      segmentId: segmentId,
      isFavorited: current.isFavorited,
      isDifficult: current.isDifficult,
      isKey: current.isKey,
    );
  }

  Future<List<GoalReviewedSegment>> listRecentReviewedSegments({int limit = 8}) async {
    final db = await _db();
    await seedIfNeeded();
    final rows = await db.rawQuery('''
      SELECT s.*, r.segment_id AS review_segment_id, r.reviewed_at_ms, r.is_favorited, r.is_difficult, r.is_key
      FROM goal_segment_review r
      JOIN goal_course_segment s ON s.segment_id = r.segment_id
      WHERE r.reviewed_at_ms > 0
      ORDER BY r.reviewed_at_ms DESC
      LIMIT ?
    ''', [limit]);
    return rows.map((r) {
      final segment = GoalCourseSegment.fromRow(r);
      final review = GoalSegmentReview(
        segmentId: (r['review_segment_id'] ?? '').toString(),
        reviewedAtMs: (r['reviewed_at_ms'] as num?)?.toInt() ?? 0,
        isFavorited: ((r['is_favorited'] as num?)?.toInt() ?? 0) == 1,
        isDifficult: ((r['is_difficult'] as num?)?.toInt() ?? 0) == 1,
        isKey: ((r['is_key'] as num?)?.toInt() ?? 0) == 1,
      );
      return GoalReviewedSegment(segment: segment, review: review);
    }).toList();
  }

  Future<List<GoalCourseProgress>> listCourseProgress() async {
    final db = await _db();
    await seedIfNeeded();
    final rows = await db.rawQuery('''
      SELECT s.source_course, s.source_course_name,
             COUNT(1) AS total_count,
             SUM(CASE WHEN r.reviewed_at_ms > 0 THEN 1 ELSE 0 END) AS reviewed_count,
             SUM(CASE WHEN COALESCE(r.is_favorited, 0) = 1 THEN 1 ELSE 0 END) AS favorite_count,
             SUM(CASE WHEN COALESCE(r.is_difficult, 0) = 1 THEN 1 ELSE 0 END) AS difficult_count,
             SUM(CASE WHEN COALESCE(r.is_key, 0) = 1 THEN 1 ELSE 0 END) AS key_count
      FROM goal_course_segment s
      LEFT JOIN goal_segment_review r ON r.segment_id = s.segment_id
      GROUP BY s.source_course, s.source_course_name
      ORDER BY MIN(CASE s.source_course WHEN 'PP12' THEN 1 ELSE 2 END), MIN(s.segment_no)
    ''');
    return rows.map((r) => GoalCourseProgress(
      sourceCourse: (r['source_course'] ?? '').toString(),
      sourceCourseName: (r['source_course_name'] ?? '').toString(),
      totalCount: (r['total_count'] as num?)?.toInt() ?? 0,
      reviewedCount: (r['reviewed_count'] as num?)?.toInt() ?? 0,
      favoriteCount: (r['favorite_count'] as num?)?.toInt() ?? 0,
      difficultCount: (r['difficult_count'] as num?)?.toInt() ?? 0,
      keyCount: (r['key_count'] as num?)?.toInt() ?? 0,
    )).toList();
  }

  Future<List<GoalModuleProgress>> listModuleProgress({String? sourceCourse}) async {
    final db = await _db();
    await seedIfNeeded();
    final where = <String>[];
    final args = <Object?>[];
    if (sourceCourse != null && sourceCourse.isNotEmpty) {
      where.add('s.source_course = ?');
      args.add(sourceCourse);
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ' + where.join(' AND ');
    final rows = await db.rawQuery('''
      SELECT s.module_group, s.source_course,
             COUNT(1) AS total_count,
             SUM(CASE WHEN r.reviewed_at_ms > 0 THEN 1 ELSE 0 END) AS reviewed_count,
             SUM(CASE WHEN COALESCE(r.is_favorited, 0) = 1 THEN 1 ELSE 0 END) AS favorite_count,
             SUM(CASE WHEN COALESCE(r.is_difficult, 0) = 1 THEN 1 ELSE 0 END) AS difficult_count,
             SUM(CASE WHEN COALESCE(r.is_key, 0) = 1 THEN 1 ELSE 0 END) AS key_count,
             MIN(CASE s.source_course WHEN 'PP12' THEN 1 ELSE 2 END) AS source_sort,
             MIN(s.segment_no) AS segment_sort
      FROM goal_course_segment s
      LEFT JOIN goal_segment_review r ON r.segment_id = s.segment_id
      ''' + whereSql + '''
      GROUP BY s.module_group, s.source_course
      ORDER BY source_sort ASC, segment_sort ASC
    ''', args);
    return rows
        .map((r) => GoalModuleProgress(
              moduleGroup: (r['module_group'] ?? '').toString(),
              sourceCourse: (r['source_course'] ?? '').toString(),
              totalCount: (r['total_count'] as num?)?.toInt() ?? 0,
              reviewedCount: (r['reviewed_count'] as num?)?.toInt() ?? 0,
              favoriteCount: (r['favorite_count'] as num?)?.toInt() ?? 0,
              difficultCount: (r['difficult_count'] as num?)?.toInt() ?? 0,
              keyCount: (r['key_count'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  Future<List<GoalReviewedSegment>> listReviewedSegments(String filter) async {
    final db = await _db();
    await seedIfNeeded();
    String whereColumn;
    switch (filter) {
      case 'difficult':
        whereColumn = 'r.is_difficult';
        break;
      case 'key':
        whereColumn = 'r.is_key';
        break;
      default:
        whereColumn = 'r.is_favorited';
        break;
    }
    final rows = await db.rawQuery('''
      SELECT s.*, r.segment_id AS review_segment_id, r.reviewed_at_ms, r.is_favorited, r.is_difficult, r.is_key
      FROM goal_segment_review r
      JOIN goal_course_segment s ON s.segment_id = r.segment_id
      WHERE $whereColumn = 1
      ORDER BY r.reviewed_at_ms DESC
    ''');
    return rows.map((r) {
      final segment = GoalCourseSegment.fromRow(r);
      final review = GoalSegmentReview(
        segmentId: (r['review_segment_id'] ?? '').toString(),
        reviewedAtMs: (r['reviewed_at_ms'] as num?)?.toInt() ?? 0,
        isFavorited: ((r['is_favorited'] as num?)?.toInt() ?? 0) == 1,
        isDifficult: ((r['is_difficult'] as num?)?.toInt() ?? 0) == 1,
        isKey: ((r['is_key'] as num?)?.toInt() ?? 0) == 1,
      );
      return GoalReviewedSegment(segment: segment, review: review);
    }).toList();
  }

  Future<List<GoalConceptCard>> listConceptCards({String? sourceCourse}) async {
    final db = await _db();
    await seedIfNeeded();
    final rows = await db.rawQuery('''
      SELECT c.*
      FROM goal_concept_card c
      JOIN goal_course_segment s ON s.segment_id = c.segment_id
      ${sourceCourse == null || sourceCourse.isEmpty ? '' : 'WHERE s.source_course = ?'}
      ORDER BY s.source_course ASC, s.segment_no ASC
    ''', sourceCourse == null || sourceCourse.isEmpty ? const [] : [sourceCourse]);
    return rows.map(GoalConceptCard.fromRow).toList();
  }

  Future<List<GoalConceptCard>> listConceptCardsForSegment(String segmentId) async {
    final db = await _db();
    await seedIfNeeded();
    final rows = await db.query('goal_concept_card', where: 'segment_id=?', whereArgs: [segmentId], orderBy: 'concept_id ASC');
    return rows.map(GoalConceptCard.fromRow).toList();
  }

  Future<GoalConceptCard?> getConceptCard(String conceptId) async {
    final db = await _db();
    await seedIfNeeded();
    final rows = await db.query('goal_concept_card', where: 'concept_id=?', whereArgs: [conceptId], limit: 1);
    if (rows.isEmpty) return null;
    return GoalConceptCard.fromRow(rows.first);
  }

  Future<List<GoalActionTemplate>> listActionTemplatesForConcept(String conceptId) async {
    final db = await _db();
    await seedIfNeeded();
    final rows = await db.query('goal_action_template', where: 'concept_id=?', whereArgs: [conceptId], orderBy: 'action_id ASC');
    return rows.map(GoalActionTemplate.fromRow).toList();
  }


  Future<List<GoalSceneActionSuggestion>> listRecommendedActionsForScene(String sceneId, {int limit = 3}) async {
    final db = await _db();
    await seedIfNeeded();
    final scene = sceneById(sceneId);
    if (scene.relatedSegmentIds.isEmpty) return const <GoalSceneActionSuggestion>[];
    final placeholders = List.filled(scene.relatedSegmentIds.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT a.*, c.concept_title, s.section_title, s.segment_id
      FROM goal_action_template a
      JOIN goal_concept_card c ON c.concept_id = a.concept_id
      JOIN goal_course_segment s ON s.segment_id = a.segment_id
      WHERE a.segment_id IN ($placeholders)
      ORDER BY s.source_course ASC, s.segment_no ASC, a.action_id ASC
    ''', scene.relatedSegmentIds);

    final sortMap = <String, int>{
      for (int i = 0; i < scene.relatedSegmentIds.length; i++) scene.relatedSegmentIds[i]: i,
    };
    rows.sort((a, b) {
      final aOrder = sortMap[(a['segment_id'] ?? '').toString()] ?? 999;
      final bOrder = sortMap[(b['segment_id'] ?? '').toString()] ?? 999;
      if (aOrder != bOrder) return aOrder.compareTo(bOrder);
      return ((a['action_id'] ?? '').toString()).compareTo((b['action_id'] ?? '').toString());
    });

    final suggestions = <GoalSceneActionSuggestion>[];
    final seenActionIds = <String>{};
    for (final row in rows) {
      final action = GoalActionTemplate.fromRow(row);
      if (!seenActionIds.add(action.actionId)) continue;
      suggestions.add(
        GoalSceneActionSuggestion(
          action: action,
          conceptTitle: (row['concept_title'] ?? '概念实践').toString(),
          segmentTitle: (row['section_title'] ?? '课程正文').toString(),
          sceneReason: _sceneActionReason(sceneId),
        ),
      );
      if (suggestions.length >= limit) break;
    }
    return suggestions;
  }

  String _sceneActionReason(String sceneId) {
    switch (sceneId) {
      case 'fog_plain':
        return '适合把“暂时方向”变成一条小而真实的行动线索。';
      case 'mirror_lake':
        return '适合继续校准“这个目标像不像我”，并把判断转成现实尝试。';
      case 'workshop_city':
        return '适合把本周推进和明天第一步真正执行起来。';
      default:
        return '适合把刚完成的场景收获继续推进到现实中。';
    }
  }


  Future<GoalModuleReflection> getModuleReflection({
    required String ritualKey,
    required String sourceCourse,
    required String moduleGroup,
  }) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'goal_module_reflection',
      where: 'ritual_key=?',
      whereArgs: [ritualKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return GoalModuleReflection.empty(
        ritualKey: ritualKey,
        sourceCourse: sourceCourse,
        moduleGroup: moduleGroup,
      );
    }
    return GoalModuleReflection.fromRow(rows.first);
  }

  Future<void> saveModuleReflection({
    required String ritualKey,
    required String sourceCourse,
    required String moduleGroup,
    required String summaryText,
    required String insightText,
    required String actionText,
  }) async {
    final db = await _db();
    await ensureTables();
    await db.insert(
      'goal_module_reflection',
      GoalModuleReflection(
        ritualKey: ritualKey,
        sourceCourse: sourceCourse,
        moduleGroup: moduleGroup,
        summaryText: summaryText,
        insightText: insightText,
        actionText: actionText,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ).toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<GoalCompletionRitual?> getModuleCompletionRitual({
    required String sourceCourse,
    required String moduleGroup,
  }) async {
    final db = await _db();
    await seedIfNeeded();
    final firstSegmentRows = await db.query(
      'goal_course_segment',
      where: 'source_course=? AND module_group=?',
      whereArgs: [sourceCourse, moduleGroup],
      orderBy: 'segment_no ASC',
      limit: 1,
    );
    if (firstSegmentRows.isEmpty) return null;
    final segment = GoalCourseSegment.fromRow(firstSegmentRows.first);

    final rows = await db.rawQuery('''
      SELECT s.source_course, s.source_course_name, s.module_group,
             COUNT(1) AS total_count,
             SUM(CASE WHEN COALESCE(r.reviewed_at_ms, 0) > 0 THEN 1 ELSE 0 END) AS reviewed_count
      FROM goal_course_segment s
      LEFT JOIN goal_segment_review r ON r.segment_id = s.segment_id
      WHERE s.source_course = ? AND s.module_group = ?
      GROUP BY s.source_course, s.source_course_name, s.module_group
    ''', [sourceCourse, moduleGroup]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final totalCount = (row['total_count'] as num?)?.toInt() ?? 0;
    final reviewedCount = (row['reviewed_count'] as num?)?.toInt() ?? 0;
    if (totalCount == 0 || reviewedCount < totalCount) return null;

    final ritualKey = 'module:${segment.sourceCourse}:${segment.moduleGroup}';

    final orderedModules = await db.rawQuery('''
      SELECT source_course, source_course_name, module_group, MIN(segment_no) AS min_segment_no
      FROM goal_course_segment
      GROUP BY source_course, source_course_name, module_group
      ORDER BY MIN(CASE source_course WHEN 'PP12' THEN 1 ELSE 2 END), MIN(segment_no)
    ''');

    int currentIndex = -1;
    for (var i = 0; i < orderedModules.length; i++) {
      final item = orderedModules[i];
      if ((item['source_course'] ?? '').toString() == segment.sourceCourse &&
          (item['module_group'] ?? '').toString() == segment.moduleGroup) {
        currentIndex = i;
        break;
      }
    }

    String? nextSegmentId;
    String? nextConceptId;
    String nextTitle = '回到学习进度';
    String nextSubtitle = '看看这个主题学完后，你的整体进度和下一个重点是什么。';

    if (currentIndex >= 0 && currentIndex + 1 < orderedModules.length) {
      final nextModule = orderedModules[currentIndex + 1];
      final nextSourceCourse = (nextModule['source_course'] ?? '').toString();
      final nextModuleGroup = (nextModule['module_group'] ?? '').toString();
      nextTitle = '继续下一主题：$nextModuleGroup';
      nextSubtitle = nextSourceCourse == segment.sourceCourse
          ? '你已经走完「${segment.moduleGroup}」，下一步建议进入「$nextModuleGroup」。'
          : '你已经完成当前课程主题，下一步建议进入下一组主题「$nextModuleGroup」。';
      final nextSegments = await db.query(
        'goal_course_segment',
        columns: ['segment_id'],
        where: 'source_course=? AND module_group=?',
        whereArgs: [nextSourceCourse, nextModuleGroup],
        orderBy: 'segment_no ASC',
        limit: 1,
      );
      if (nextSegments.isNotEmpty) {
        nextSegmentId = (nextSegments.first['segment_id'] ?? '').toString();
        final nextConceptRows = await db.query(
          'goal_concept_card',
          columns: ['concept_id'],
          where: 'segment_id=?',
          whereArgs: [nextSegmentId],
          orderBy: 'concept_id ASC',
          limit: 1,
        );
        if (nextConceptRows.isNotEmpty) {
          nextConceptId = (nextConceptRows.first['concept_id'] ?? '').toString();
        }
      }
    } else {
      nextTitle = '把这组学习带回目标工坊';
      nextSubtitle = '现在很适合把刚完成的这一组主题，转成一个更清晰的目标、why 或下一步行动。';
    }

    final summaries = _moduleCompletionSummary(segment.moduleGroup);
    return GoalCompletionRitual(
      ritualKey: ritualKey,
      sourceCourse: segment.sourceCourse,
      sourceCourseName: segment.sourceCourseName,
      moduleGroup: segment.moduleGroup,
      totalCount: totalCount,
      reviewedCount: reviewedCount,
      summaryTitle: summaries[0],
      summaryText: summaries[1],
      nextTitle: nextTitle,
      nextSubtitle: nextSubtitle,
      nextSegmentId: nextSegmentId,
      nextConceptId: nextConceptId,
    );
  }

  Future<bool> hasCompletionRitualShown(String ritualKey) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'goal_completion_ritual_state',
      where: 'ritual_key=?',
      whereArgs: [ritualKey],
      limit: 1,
    );
    return rows.isNotEmpty && ((rows.first['shown_at_ms'] as num?)?.toInt() ?? 0) > 0;
  }

  Future<void> markCompletionRitualShown(String ritualKey) async {
    final db = await _db();
    await ensureTables();
    await db.insert(
      'goal_completion_ritual_state',
      GoalCompletionRitualState(
        ritualKey: ritualKey,
        shownAtMs: DateTime.now().millisecondsSinceEpoch,
      ).toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<GoalCompletionRitual?> getPendingModuleCompletionRitual(String segmentId) async {
    final segment = await getSegment(segmentId);
    if (segment == null) return null;
    final ritual = await getModuleCompletionRitual(
      sourceCourse: segment.sourceCourse,
      moduleGroup: segment.moduleGroup,
    );
    if (ritual == null) return null;
    if (await hasCompletionRitualShown(ritual.ritualKey)) return null;
    return ritual;
  }

  List<String> _moduleCompletionSummary(String moduleGroup) {
    switch (moduleGroup) {
      case '目标为什么有效':
        return ['你已经走完「目标为什么有效」', '这一组内容的核心不是“喊目标”，而是理解目标为何能带来聚焦、资源、承诺与复原力。现在你已经把目标从口号，推进成了一个真正会组织生活的力量。'];
      case '目标与幸福的关系':
        return ['你已经走完「目标与幸福的关系」', '这一组内容帮助你把“达成目标”与“拥有目标、走在路上”区分开来。重点不是把幸福押在终点，而是让目标开始改善当下的旅程。'];
      case '自我一致目标与人生方向':
        return ['你已经走完「自我一致目标与人生方向」', '这一组内容的重点，是把“应该追什么”转成“真正属于我的是什么”。当目标更像真实的你，它才更可能带来能量、意义和持续投入。'];
      case '自我一致性收益':
        return ['你已经走完「自我一致性收益」', '你已经看到：自我一致性不只让人更幸福，也会减轻内耗、带来涓滴效应，并让人更愿意投入与坚持。'];
      case '优势与VIA系统':
        return ['你已经走完「优势与 VIA 系统」', '这一组内容强调：优势不是“知道自己优点”，而是能否把它用进现实、用进问题、用成习惯。现在很适合把一个优势继续带到下周。'];
      case '使命与职业取向':
        return ['你已经走完「使命与职业取向」', '你已经触碰到一个更深的问题：我做的事究竟只是 job、career，还是 calling。接下来最重要的不是追求完美答案，而是继续倾听内在召唤并做小实验。'];
      case '目标设定技术':
        return ['你已经走完「目标设定技术」', '这一组内容把抽象目标变成了可执行结构：写下来、设 lifeline、拆成台阶、配上仪式。现在最适合把其中一个目标真正推进到现实中。'];
      case '压力主题转场':
        return ['你已经走完这一小节', '你已经完成了从目标主题切入压力主题前的过渡内容，可以回到学习进度，也可以把当前收获立即带到目标工坊里。'];
      default:
        return ['你完成了一个主题章节', '你已经把这一组课程内容完整走完。现在最有价值的动作，不是立刻去追更多内容，而是做一次简短回看，并把一个收获带到下一步。'];
    }
  }

  Future<void> saveContinueState({
    required String stateKey,
    required String targetId,
    double scrollOffset = 0,
    Map<String, Object?> extra = const {},
  }) async {
    final db = await _db();
    await ensureTables();
    await db.insert(
      'goal_continue_state',
      GoalContinueState(
        stateKey: stateKey,
        targetId: targetId,
        scrollOffset: scrollOffset,
        extraJson: json.encode(extra),
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ).toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<GoalContinueState> getContinueState(String stateKey) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('goal_continue_state', where: 'state_key=?', whereArgs: [stateKey], limit: 1);
    if (rows.isEmpty) return GoalContinueState.empty(stateKey);
    return GoalContinueState.fromRow(rows.first);
  }

  Future<void> saveActionDraft({
    required String actionId,
    required String conceptId,
    required String segmentId,
    required int startedAtMs,
    required String actionTitle,
    required String actionLevel,
    required String goalOfAction,
    required List<String> steps,
    required int durationMin,
    required String failurePlan,
    required List<String> feedbackFields,
    required List<bool> checks,
    required Map<String, String> feedbackValues,
    required String reflectionText,
    required String conceptTitleSnapshot,
    required String segmentTitleSnapshot,
  }) async {
    final db = await _db();
    await ensureTables();
    await db.insert(
      'goal_action_draft',
      GoalActionDraft(
        actionId: actionId,
        conceptId: conceptId,
        segmentId: segmentId,
        startedAtMs: startedAtMs,
        actionTitle: actionTitle,
        actionLevel: actionLevel,
        goalOfAction: goalOfAction,
        stepsJson: json.encode(steps),
        durationMin: durationMin,
        failurePlan: failurePlan,
        feedbackFieldsJson: json.encode(feedbackFields),
        checkedJson: json.encode(checks),
        feedbackValuesJson: json.encode(feedbackValues),
        reflectionText: reflectionText,
        conceptTitleSnapshot: conceptTitleSnapshot,
        segmentTitleSnapshot: segmentTitleSnapshot,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ).toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<GoalActionDraft?> getActionDraft(String actionId) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('goal_action_draft', where: 'action_id=?', whereArgs: [actionId], limit: 1);
    if (rows.isEmpty) return null;
    return GoalActionDraft.fromRow(rows.first);
  }

  Future<GoalActionDraft?> getLatestActionDraft() async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('goal_action_draft', orderBy: 'updated_at_ms DESC', limit: 1);
    if (rows.isEmpty) return null;
    return GoalActionDraft.fromRow(rows.first);
  }

  Future<void> deleteActionDraft(String actionId) async {
    final db = await _db();
    await ensureTables();
    await db.delete('goal_action_draft', where: 'action_id=?', whereArgs: [actionId]);
  }

  Future<void> saveActionRecord({
    required String actionId,
    required String conceptId,
    required String segmentId,
    required int startedAtMs,
    required double completionRate,
    required Map<String, String> feedbackMap,
    required String reflectionText,
    String actionTitleSnapshot = '',
    String conceptTitleSnapshot = '',
    String segmentTitleSnapshot = '',
    String actionLevelSnapshot = '',
  }) async {
    final db = await _db();
    await ensureTables();
    await db.insert('goal_action_record', {
      'action_id': actionId,
      'concept_id': conceptId,
      'segment_id': segmentId,
      'started_at_ms': startedAtMs,
      'completed_at_ms': DateTime.now().millisecondsSinceEpoch,
      'completion_rate': completionRate,
      'feedback_json': json.encode(feedbackMap),
      'reflection_text': reflectionText,
      'action_title_snapshot': actionTitleSnapshot,
      'concept_title_snapshot': conceptTitleSnapshot,
      'segment_title_snapshot': segmentTitleSnapshot,
      'action_level_snapshot': actionLevelSnapshot,
    });
    await deleteActionDraft(actionId);
  }

  Future<List<GoalActionRecordView>> listActionRecordViews({int limit = 30, String period = 'all'}) async {
    final db = await _db();
    await seedIfNeeded();
    final where = <String>[];
    final args = <Object?>[];
    final now = DateTime.now();
    if (period == 'today') {
      final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      where.add('r.completed_at_ms >= ?');
      args.add(start);
    } else if (period == 'week') {
      final weekdayOffset = now.weekday - DateTime.monday;
      final startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: weekdayOffset));
      where.add('r.completed_at_ms >= ?');
      args.add(startDate.millisecondsSinceEpoch);
    }
    final sql = '''
      SELECT r.*, 
             COALESCE(a.action_title, r.action_title_snapshot, '未命名行动') AS action_title,
             COALESCE(c.concept_title, r.concept_title_snapshot, '概念实践') AS concept_title,
             COALESCE(s.section_title, r.segment_title_snapshot, '课程正文') AS section_title,
             COALESCE(f.decision, '') AS followup_decision,
             COALESCE(f.updated_at_ms, 0) AS followup_updated_at_ms
      FROM goal_action_record r
      LEFT JOIN goal_action_template a ON a.action_id = r.action_id
      LEFT JOIN goal_concept_card c ON c.concept_id = r.concept_id
      LEFT JOIN goal_course_segment s ON s.segment_id = r.segment_id
      LEFT JOIN goal_action_followup f ON f.action_record_id = r.id
      ${where.isEmpty ? '' : 'WHERE ' + where.join(' AND ')}
      ORDER BY r.completed_at_ms DESC
      LIMIT ?
    ''';
    final rows = await db.rawQuery(sql, [...args, limit]);
    return rows.map(_recordViewFromRow).toList();
  }

  GoalActionRecordView _recordViewFromRow(Map<String, Object?> r) => GoalActionRecordView(
        record: GoalActionRecord.fromRow(r),
        actionTitle: (r['action_title'] ?? '未命名行动').toString(),
        conceptTitle: (r['concept_title'] ?? '概念实践').toString(),
        segmentTitle: (r['section_title'] ?? '课程正文').toString(),
        followupDecision: (r['followup_decision'] ?? '').toString(),
        followupUpdatedAtMs: (r['followup_updated_at_ms'] as num?)?.toInt() ?? 0,
      );


  Future<GoalConceptProgressStats> getConceptProgressStats(String conceptId) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.rawQuery('''
      SELECT r.concept_id,
             COUNT(r.id) AS action_count,
             COALESCE(AVG(r.completion_rate), 0) AS avg_completion_rate,
             COALESCE(MAX(r.completed_at_ms), 0) AS last_completed_at_ms,
             SUM(CASE WHEN (COALESCE(f.decision, '') <> '' OR COALESCE(f.reflection_text, '') <> '' OR COALESCE(f.next_step, '') <> '' OR COALESCE(f.weekly_focus, '') <> '') THEN 1 ELSE 0 END) AS followup_count,
             SUM(CASE WHEN COALESCE(f.decision, '') = '继续' THEN 1 ELSE 0 END) AS continue_count,
             SUM(CASE WHEN COALESCE(f.decision, '') = '调整' THEN 1 ELSE 0 END) AS adjust_count,
             SUM(CASE WHEN COALESCE(f.decision, '') = '放弃' THEN 1 ELSE 0 END) AS release_count
      FROM goal_action_record r
      LEFT JOIN goal_action_followup f ON f.action_record_id = r.id
      WHERE r.concept_id = ?
    ''', [conceptId]);
    if (rows.isEmpty) return GoalConceptProgressStats.empty(conceptId);
    final row = rows.first;
    return GoalConceptProgressStats(
      conceptId: conceptId,
      actionCount: (row['action_count'] as num?)?.toInt() ?? 0,
      avgCompletionRate: (row['avg_completion_rate'] as num?)?.toDouble() ?? 0,
      followupCount: (row['followup_count'] as num?)?.toInt() ?? 0,
      continueCount: (row['continue_count'] as num?)?.toInt() ?? 0,
      adjustCount: (row['adjust_count'] as num?)?.toInt() ?? 0,
      releaseCount: (row['release_count'] as num?)?.toInt() ?? 0,
      lastCompletedAtMs: (row['last_completed_at_ms'] as num?)?.toInt() ?? 0,
    );
  }

  Future<GoalActionFollowup> getActionFollowup(int actionRecordId) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('goal_action_followup', where: 'action_record_id=?', whereArgs: [actionRecordId], limit: 1);
    if (rows.isEmpty) return GoalActionFollowup.empty(actionRecordId);
    return GoalActionFollowup.fromRow(rows.first);
  }

  Future<void> saveActionFollowup({
    required int actionRecordId,
    required String decision,
    required String reflectionText,
    required String nextStep,
    required String weeklyFocus,
  }) async {
    final db = await _db();
    await ensureTables();
    await db.insert(
      'goal_action_followup',
      GoalActionFollowup(
        actionRecordId: actionRecordId,
        decision: decision,
        reflectionText: reflectionText,
        nextStep: nextStep,
        weeklyFocus: weeklyFocus,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ).toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }


  Future<GoalModuleReviewActionOverview> getModuleReviewActionOverview() async {
    final db = await _db();
    await seedIfNeeded();

    Future<GoalActionRecordView?> queryOne({required bool pendingOnly}) async {
      final pendingClause = pendingOnly
          ? "AND COALESCE(f.decision, '') = '' AND COALESCE(f.reflection_text, '') = '' AND COALESCE(f.next_step, '') = '' AND COALESCE(f.weekly_focus, '') = ''"
          : '';
      final rows = await db.rawQuery("""
        SELECT r.*, 
               COALESCE(a.action_title, r.action_title_snapshot, '未命名行动') AS action_title,
               COALESCE(c.concept_title, r.concept_title_snapshot, '概念实践') AS concept_title,
               COALESCE(s.section_title, r.segment_title_snapshot, '课程正文') AS section_title,
               COALESCE(f.decision, '') AS followup_decision,
               COALESCE(f.updated_at_ms, 0) AS followup_updated_at_ms
        FROM goal_action_record r
        LEFT JOIN goal_action_template a ON a.action_id = r.action_id
        LEFT JOIN goal_concept_card c ON c.concept_id = r.concept_id
        LEFT JOIN goal_course_segment s ON s.segment_id = r.segment_id
        LEFT JOIN goal_action_followup f ON f.action_record_id = r.id
        WHERE r.action_id LIKE ?
        $pendingClause
        ORDER BY r.completed_at_ms DESC
        LIMIT 1
      """, ['module_review_%']);
      if (rows.isEmpty) return null;
      return _recordViewFromRow(rows.first);
    }

    final latest = await queryOne(pendingOnly: false);
    final pending = await queryOne(pendingOnly: true);
    return GoalModuleReviewActionOverview(latestAction: latest, pendingAction: pending);
  }

  Future<GoalWorkshopActionOverview> getWorkshopActionOverview() async {
    final db = await _db();
    await seedIfNeeded();

    Future<GoalActionRecordView?> queryOne({required bool pendingOnly}) async {
      final pendingClause = pendingOnly
          ? "AND COALESCE(f.decision, '') = '' AND COALESCE(f.reflection_text, '') = '' AND COALESCE(f.next_step, '') = '' AND COALESCE(f.weekly_focus, '') = ''"
          : '';
      final rows = await db.rawQuery("""
        SELECT r.*, 
               COALESCE(a.action_title, r.action_title_snapshot, '未命名行动') AS action_title,
               COALESCE(c.concept_title, r.concept_title_snapshot, '概念实践') AS concept_title,
               COALESCE(s.section_title, r.segment_title_snapshot, '课程正文') AS section_title,
               COALESCE(f.decision, '') AS followup_decision,
               COALESCE(f.updated_at_ms, 0) AS followup_updated_at_ms
        FROM goal_action_record r
        LEFT JOIN goal_action_template a ON a.action_id = r.action_id
        LEFT JOIN goal_concept_card c ON c.concept_id = r.concept_id
        LEFT JOIN goal_course_segment s ON s.segment_id = r.segment_id
        LEFT JOIN goal_action_followup f ON f.action_record_id = r.id
        WHERE r.action_id LIKE ?
        $pendingClause
        ORDER BY r.completed_at_ms DESC
        LIMIT 1
      """, ['workshop_auto_%']);
      if (rows.isEmpty) return null;
      return _recordViewFromRow(rows.first);
    }

    final latest = await queryOne(pendingOnly: false);
    final pending = await queryOne(pendingOnly: true);
    return GoalWorkshopActionOverview(latestAction: latest, pendingAction: pending);
  }

  Future<GoalActionRecordBundle?> getActionRecordBundle(int actionRecordId) async {
    final db = await _db();
    await seedIfNeeded();
    final rows = await db.rawQuery('''
      SELECT r.*, 
             COALESCE(a.action_title, r.action_title_snapshot, '未命名行动') AS action_title,
             COALESCE(c.concept_title, r.concept_title_snapshot, '概念实践') AS concept_title,
             COALESCE(s.section_title, r.segment_title_snapshot, '课程正文') AS section_title,
             COALESCE(f.decision, '') AS followup_decision,
             COALESCE(f.updated_at_ms, 0) AS followup_updated_at_ms
      FROM goal_action_record r
      LEFT JOIN goal_action_template a ON a.action_id = r.action_id
      LEFT JOIN goal_concept_card c ON c.concept_id = r.concept_id
      LEFT JOIN goal_course_segment s ON s.segment_id = r.segment_id
      LEFT JOIN goal_action_followup f ON f.action_record_id = r.id
      WHERE r.id = ?
      LIMIT 1
    ''', [actionRecordId]);
    if (rows.isEmpty) return null;
    final view = _recordViewFromRow(rows.first);
    final followup = await getActionFollowup(actionRecordId);
    return GoalActionRecordBundle(view: view, followup: followup);
  }

  Future<GoalWorkshopDraft> mergeFollowupIntoWorkshop({
    required int actionRecordId,
    required String decision,
    required String reflectionText,
    required String nextStep,
    required String weeklyFocus,
  }) async {
    final current = await getWorkshopDraft();
    final bundle = await getActionRecordBundle(actionRecordId);
    final view = bundle?.view;

    String appendUnique(String base, String line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return base;
      if (base.trim().isEmpty) return trimmed;
      if (base.contains(trimmed)) return base;
      return '${base.trim()}\n$trimmed';
    }

    final sourceLine = [view?.conceptTitle ?? '', view?.actionTitle ?? '']
        .where((e) => e.trim().isNotEmpty)
        .join('｜');

    final merged = GoalWorkshopDraft(
      identityStatement: current.identityStatement,
      vision: current.vision.trim().isNotEmpty
          ? current.vision
          : ((view?.segmentTitle ?? '').trim().isNotEmpty ? view!.segmentTitle : sourceLine),
      whyText: current.whyText.trim().isNotEmpty
          ? current.whyText
          : (view?.record.reflectionText.trim().isNotEmpty == true ? view!.record.reflectionText.trim() : ''),
      realityProblem: decision == '调整'
          ? appendUnique(current.realityProblem, reflectionText.trim().isNotEmpty ? '来自行动闭环：${reflectionText.trim()}' : '来自行动闭环：需要重新调整当前策略')
          : current.realityProblem,
      externalExpectation: current.externalExpectation,
      competingGoal: current.competingGoal,
      lifeline: current.lifeline,
      stretchScore: current.stretchScore,
      weeklyGoal: weeklyFocus.trim().isNotEmpty
          ? weeklyFocus.trim()
          : (decision == '继续' && current.weeklyGoal.trim().isEmpty ? sourceLine : current.weeklyGoal),
      firstStep: nextStep.trim().isNotEmpty ? nextStep.trim() : current.firstStep,
      ifThenText: decision == '调整' && nextStep.trim().isNotEmpty
          ? appendUnique(current.ifThenText, '如果再次遇到这次行动中的阻碍，那么我先：${nextStep.trim()}')
          : current.ifThenText,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    await saveWorkshopDraft(
      identityStatement: merged.identityStatement,
      vision: merged.vision,
      whyText: merged.whyText,
      realityProblem: merged.realityProblem,
      externalExpectation: merged.externalExpectation,
      competingGoal: merged.competingGoal,
      lifeline: merged.lifeline,
      stretchScore: merged.stretchScore,
      weeklyGoal: merged.weeklyGoal,
      firstStep: merged.firstStep,
      ifThenText: merged.ifThenText,
    );
    return merged;
  }

  Future<GoalWorldSceneProgress> getWorldSceneProgress(String sceneId) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('goal_world_scene_progress', where: 'scene_id=?', whereArgs: [sceneId], limit: 1);
    if (rows.isEmpty) return GoalWorldSceneProgress.empty(sceneId);
    return GoalWorldSceneProgress.fromRow(rows.first);
  }

  Future<List<GoalWorldSceneProgress>> listWorldSceneProgress() async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('goal_world_scene_progress', orderBy: 'updated_at_ms DESC');
    return rows.map(GoalWorldSceneProgress.fromRow).toList();
  }

  Future<List<GoalWorldTimelineEvent>> listWorldTimelineEvents({int limit = 12}) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('goal_world_timeline_event', orderBy: 'created_at_ms DESC, id DESC', limit: limit);
    return rows.map(GoalWorldTimelineEvent.fromRow).toList();
  }


  Future<List<GoalWorldStatusSnapshot>> listWorldStatusSnapshots({int limit = 12}) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('goal_world_status_snapshot', orderBy: 'created_at_ms DESC, id DESC', limit: limit);
    return rows.map(GoalWorldStatusSnapshot.fromRow).toList();
  }

  Future<GoalWorldGrowthTrajectory> getWorldGrowthTrajectory({int limit = 6}) async {
    final db = await _db();
    await ensureTables();
    return _getWorldGrowthTrajectoryFromDb(db, limit: limit);
  }

  Future<GoalWorldGrowthTrajectory> _getWorldGrowthTrajectoryFromDb(Database db, {int limit = 6}) async {
    final latestRows = await db.query('goal_world_status_snapshot', orderBy: 'created_at_ms DESC, id DESC', limit: limit);
    final firstRows = await db.query('goal_world_status_snapshot', orderBy: 'created_at_ms ASC, id ASC', limit: 1);
    if (latestRows.isEmpty) return const GoalWorldGrowthTrajectory.empty();
    return GoalWorldGrowthTrajectory(
      firstSnapshot: firstRows.isEmpty ? null : GoalWorldStatusSnapshot.fromRow(firstRows.first),
      latestSnapshot: GoalWorldStatusSnapshot.fromRow(latestRows.first),
      recentSnapshots: latestRows.map(GoalWorldStatusSnapshot.fromRow).toList(),
    );
  }

  Future<GoalWorldIdentityEvolution> getWorldIdentityEvolution() async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('goal_world_identity_evolution', where: 'id=1', limit: 1);
    if (rows.isEmpty) return const GoalWorldIdentityEvolution.empty();
    return GoalWorldIdentityEvolution.fromRow(rows.first);
  }

  String _safeSceneTitle(String sceneId) {
    if (sceneId.trim().isEmpty) return '';
    try {
      return sceneById(sceneId).title;
    } catch (_) {
      return '目标试验场';
    }
  }

  Future<GoalWorldPracticeTimelineSummary> getWorldPracticeTimelineSummary({
    int snapshotLimit = 8,
    int eventLimit = 16,
  }) async {
    final db = await _db();
    await ensureTables();
    final snapshotRows = await db.query(
      'goal_world_status_snapshot',
      orderBy: 'created_at_ms DESC, id DESC',
      limit: snapshotLimit,
    );
    final eventRows = await db.query(
      'goal_world_timeline_event',
      orderBy: 'created_at_ms DESC, id DESC',
      limit: eventLimit,
    );
    final snapshots = snapshotRows.map(GoalWorldStatusSnapshot.fromRow).toList();
    final events = eventRows.map(GoalWorldTimelineEvent.fromRow).toList();
    GoalWorldTimelineEvent? latestIdentityShift;
    for (final item in events) {
      if (item.eventType == 'identity_shift') {
        latestIdentityShift = item;
        break;
      }
    }

    final latestSnapshot = snapshots.isNotEmpty ? snapshots.first : null;
    final previousSnapshot = snapshots.length > 1 ? snapshots[1] : null;

    final sceneScores = <String, int>{};
    final sceneReasons = <String, List<String>>{};

    void addReason(String sceneId, String reason) {
      if (sceneId.trim().isEmpty || reason.trim().isEmpty) return;
      final list = sceneReasons.putIfAbsent(sceneId, () => <String>[]);
      if (!list.contains(reason.trim())) list.add(reason.trim());
    }

    for (var i = 0; i < snapshots.length; i++) {
      final item = snapshots[i];
      if (item.sourceType != 'scene' || item.sourceId.trim().isEmpty) continue;
      final weight = (snapshotLimit - i).clamp(1, snapshotLimit) * 2;
      sceneScores[item.sourceId] = (sceneScores[item.sourceId] ?? 0) + weight;
      addReason(item.sourceId, item.note);
    }

    for (var i = 0; i < events.length; i++) {
      final item = events[i];
      if (item.sceneId.trim().isEmpty) continue;
      final weight = (eventLimit - i).clamp(1, eventLimit);
      sceneScores[item.sceneId] = (sceneScores[item.sceneId] ?? 0) + weight;
      addReason(item.sceneId, item.title);
    }

    String strongestSceneId = '';
    var strongestScore = -1;
    sceneScores.forEach((sceneId, score) {
      if (score > strongestScore) {
        strongestScore = score;
        strongestSceneId = sceneId;
      }
    });

    final strongestSceneTitle = _safeSceneTitle(strongestSceneId);
    final strongestSceneReason = (sceneReasons[strongestSceneId] ?? const <String>[]).take(2).join('；');

    return GoalWorldPracticeTimelineSummary(
      latestIdentityShift: latestIdentityShift,
      previousSnapshot: previousSnapshot,
      latestSnapshot: latestSnapshot,
      strongestSceneId: strongestSceneId,
      strongestSceneTitle: strongestSceneTitle,
      strongestSceneReason: strongestSceneReason,
      recentEvents: events.take(4).toList(),
    );
  }

  Future<GoalWorldRecentIdentityLeapDetail> getRecentIdentityLeapDetail() async {
    final db = await _db();
    await ensureTables();
    final events = await listWorldIdentityShiftEvents(limit: 1);
    final latestShift = events.isNotEmpty ? events.first : null;
    final evolution = await getWorldIdentityEvolution();
    final practice = await getWorldPracticeTimelineSummary();
    GoalWorldStatusSnapshot? beforeSnapshot;
    GoalWorldStatusSnapshot? afterSnapshot;
    if (latestShift != null) {
      final beforeRows = await db.query(
        'goal_world_status_snapshot',
        where: 'created_at_ms <= ?',
        whereArgs: [latestShift.createdAtMs],
        orderBy: 'created_at_ms DESC, id DESC',
        limit: 1,
      );
      final afterRows = await db.query(
        'goal_world_status_snapshot',
        where: 'created_at_ms >= ?',
        whereArgs: [latestShift.createdAtMs],
        orderBy: 'created_at_ms ASC, id ASC',
        limit: 1,
      );
      if (beforeRows.isNotEmpty) beforeSnapshot = GoalWorldStatusSnapshot.fromRow(beforeRows.first);
      if (afterRows.isNotEmpty) afterSnapshot = GoalWorldStatusSnapshot.fromRow(afterRows.first);
      afterSnapshot ??= practice.latestSnapshot;
      beforeSnapshot ??= practice.previousSnapshot;
    } else {
      beforeSnapshot = practice.previousSnapshot;
      afterSnapshot = practice.latestSnapshot;
    }
    final evidence = <String>[];
    if (latestShift != null && latestShift.body.trim().isNotEmpty) evidence.add(latestShift.body.trim());
    for (final item in evolution.evidence.take(3)) {
      if (item.trim().isNotEmpty && !evidence.contains(item.trim())) evidence.add(item.trim());
    }
    final headline = latestShift?.title ?? evolution.headline;
    return GoalWorldRecentIdentityLeapDetail(
      latestShift: latestShift,
      beforeSnapshot: beforeSnapshot,
      afterSnapshot: afterSnapshot,
      strongestSceneId: practice.strongestSceneId,
      strongestSceneTitle: practice.strongestSceneTitle,
      strongestSceneReason: practice.strongestSceneReason,
      headline: headline,
      evidence: evidence,
    );
  }

  String _weekdayCn(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return '周一';
      case DateTime.tuesday:
        return '周二';
      case DateTime.wednesday:
        return '周三';
      case DateTime.thursday:
        return '周四';
      case DateTime.friday:
        return '周五';
      case DateTime.saturday:
        return '周六';
      case DateTime.sunday:
        return '周日';
      default:
        return '';
    }
  }

  Future<List<GoalWorldSevenDayTrendPoint>> getWorldSevenDayTrend() async {
    final db = await _db();
    await ensureTables();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final rows = await db.query(
      'goal_world_status_snapshot',
      where: 'created_at_ms >= ?',
      whereArgs: [start.millisecondsSinceEpoch],
      orderBy: 'created_at_ms ASC, id ASC',
    );
    final byDay = <String, GoalWorldStatusSnapshot>{};
    for (final row in rows) {
      final item = GoalWorldStatusSnapshot.fromRow(row);
      final dt = DateTime.fromMillisecondsSinceEpoch(item.createdAtMs);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      byDay[key] = item; // ordered asc; final assignment becomes latest of the day
    }
    final points = <GoalWorldSevenDayTrendPoint>[];
    for (var i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final item = byDay[key];
      points.add(item == null
          ? GoalWorldSevenDayTrendPoint.empty(dateKey: key, label: _weekdayCn(day.weekday))
          : GoalWorldSevenDayTrendPoint(
              dateKey: key,
              label: _weekdayCn(day.weekday),
              clarity: item.clarity,
              alignment: item.alignment,
              momentum: item.momentum,
              hasData: true,
            ));
    }
    return points;
  }

  Future<List<GoalWorldTimelineEvent>> listWorldIdentityShiftEvents({int limit = 6}) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'goal_world_timeline_event',
      where: 'event_type=?',
      whereArgs: ['identity_shift'],
      orderBy: 'created_at_ms DESC, id DESC',
      limit: limit,
    );
    return rows.map(GoalWorldTimelineEvent.fromRow).toList();
  }

  Future<void> _appendWorldTimelineEvent({
    required Database db,
    required String sceneId,
    required String eventType,
    required String title,
    required String body,
    String branchChoiceId = '',
  }) async {
    await db.insert('goal_world_timeline_event', {
      'scene_id': sceneId,
      'event_type': eventType,
      'title': title,
      'body': body,
      'branch_choice_id': branchChoiceId,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<GoalWorldStatusSnapshot?> _getLatestWorldStatusSnapshot(Database db) async {
    final rows = await db.query('goal_world_status_snapshot', orderBy: 'created_at_ms DESC, id DESC', limit: 1);
    if (rows.isEmpty) return null;
    return GoalWorldStatusSnapshot.fromRow(rows.first);
  }

  Future<void> _captureWorldStatusSnapshot({
    required Database db,
    required GoalWorldProfile profile,
    required List<GoalWorldSceneProgress> progressList,
    required String sourceType,
    required String sourceId,
    required String note,
  }) async {
    final status = computeWorldRoleStatus(profile: profile, progressList: progressList);
    final previous = await _getLatestWorldStatusSnapshot(db);
    final shouldInsert = previous == null ||
        (status.clarity - previous.clarity).abs() >= 4 ||
        (status.alignment - previous.alignment).abs() >= 4 ||
        (status.momentum - previous.momentum).abs() >= 4 ||
        (note.trim().isNotEmpty && note.trim() != previous.note.trim());
    if (!shouldInsert) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.insert('goal_world_status_snapshot', {
      'source_type': sourceType,
      'source_id': sourceId,
      'clarity': status.clarity,
      'alignment': status.alignment,
      'momentum': status.momentum,
      'note': note,
      'created_at_ms': nowMs,
    });
    if (previous != null) {
      final dc = status.clarity - previous.clarity;
      final da = status.alignment - previous.alignment;
      final dm = status.momentum - previous.momentum;
      final total = dc + da + dm;
      if (total.abs() >= 6) {
        final direction = total > 0 ? '上升' : '波动';
        final pieces = <String>[];
        if (dc != 0) pieces.add('清晰度${dc > 0 ? '+' : ''}$dc');
        if (da != 0) pieces.add('一致性${da > 0 ? '+' : ''}$da');
        if (dm != 0) pieces.add('行动势能${dm > 0 ? '+' : ''}$dm');
        await _appendWorldTimelineEvent(
          db: db,
          sceneId: sourceType == 'scene' ? sourceId : '',
          eventType: 'growth_shift',
          title: '角色状态出现一次$direction',
          body: pieces.isEmpty ? note : '${pieces.join('，')}。$note',
        );
      }
    }
  }


  Future<GoalWorldIdentityEvolution> _getWorldIdentityEvolutionFromDb(Database db) async {
    final rows = await db.query('goal_world_identity_evolution', where: 'id=1', limit: 1);
    if (rows.isEmpty) return const GoalWorldIdentityEvolution.empty();
    return GoalWorldIdentityEvolution.fromRow(rows.first);
  }

  Future<void> _syncWorldIdentityEvolution({
    required Database db,
    required GoalWorldProfile profile,
    required List<GoalWorldSceneProgress> progressList,
    required String sourceSceneId,
  }) async {
    final trajectory = await _getWorldGrowthTrajectoryFromDb(db, limit: 6);
    final evolution = computeWorldIdentityEvolution(
      profile: profile,
      progressList: progressList,
      trajectory: trajectory,
    );
    final previous = await _getWorldIdentityEvolutionFromDb(db);
    await db.insert('goal_world_identity_evolution', evolution.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    final changed = previous.stageKey != evolution.stageKey || previous.headline.trim() != evolution.headline.trim();
    if (changed && evolution.hasContent) {
      final body = [evolution.stageSubtitle, ...evolution.evidence.take(2)].where((e) => e.trim().isNotEmpty).join('；');
      await _appendWorldTimelineEvent(
        db: db,
        sceneId: sourceSceneId,
        eventType: 'identity_shift',
        title: '我正在成为：${evolution.stageTitle}',
        body: body,
      );
    }
  }

  Future<List<GoalWorldSceneProgress>> _listWorldSceneProgressFromDb(Database db) async {
    final rows = await db.query('goal_world_scene_progress', orderBy: 'updated_at_ms DESC');
    return rows.map(GoalWorldSceneProgress.fromRow).toList();
  }

  Future<GoalWorldSceneProgress?> getLatestRewardedSceneProgress() async {
    final all = await listWorldSceneProgress();
    for (final item in all) {
      if (item.rewardClaimed) return item;
    }
    return null;
  }


  Future<void> saveWorldSceneProgress({
    required String sceneId,
    required List<String> completedTaskIds,
    required String realityNote,
    required bool rewardClaimed,
    String activeTaskId = '',
    int? rewardClaimedAtMs,
    String simulationChoiceId = '',
    String simulationReflection = '',
    List<String> completedBranchTaskIds = const <String>[],
    String activeBranchTaskId = '',
  }) async {
    final db = await _db();
    await ensureTables();
    final previous = await getWorldSceneProgress(sceneId);
    final profile = await getWorldProfile();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final progress = GoalWorldSceneProgress(
      sceneId: sceneId,
      completedTaskIdsJson: json.encode(completedTaskIds),
      realityNote: realityNote,
      rewardClaimed: rewardClaimed,
      activeTaskId: activeTaskId,
      rewardClaimedAtMs: rewardClaimed
          ? (rewardClaimedAtMs ?? (previous.rewardClaimed ? previous.rewardClaimedAtMs : nowMs))
          : 0,
      simulationChoiceId: simulationChoiceId,
      simulationReflection: simulationReflection,
      branchCompletedTaskIdsJson: json.encode(completedBranchTaskIds),
      activeBranchTaskId: activeBranchTaskId,
      updatedAtMs: nowMs,
    );
    await db.insert('goal_world_scene_progress', progress.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);

    final scene = sceneById(sceneId);
    if (simulationChoiceId.trim().isNotEmpty && simulationChoiceId != previous.simulationChoiceId) {
      final choiceTitle = choiceTitleForSceneChoice(scene: scene, choiceId: simulationChoiceId);
      final shifts = sceneStateShiftsForChoice(sceneId: sceneId, choiceId: simulationChoiceId, profile: profile);
      final shiftBody = shifts.isEmpty ? '你在 ${scene.title} 做出了新的路径选择。' : shifts.map((e) => e.title).join('；');
      await _appendWorldTimelineEvent(
        db: db,
        sceneId: sceneId,
        eventType: 'branch_choice',
        title: '在${scene.title}选择了：$choiceTitle',
        body: shiftBody,
        branchChoiceId: simulationChoiceId,
      );
    }

    final branchTotal = simulationChoiceId.trim().isEmpty ? 0 : branchTasksForSceneChoice(sceneId: sceneId, choiceId: simulationChoiceId).length;
    final prevBranchDone = previous.completedBranchTaskIds.length;
    final nowBranchDone = completedBranchTaskIds.length;
    if (branchTotal > 0 && prevBranchDone < branchTotal && nowBranchDone >= branchTotal) {
      final shifts = sceneStateShiftsForChoice(sceneId: sceneId, choiceId: simulationChoiceId, profile: profile);
      await _appendWorldTimelineEvent(
        db: db,
        sceneId: sceneId,
        eventType: 'branch_path_completed',
        title: '走通了 ${scene.title} 的当前分支',
        body: shifts.isEmpty ? '这一关的分支后续任务已经完成。' : '后续场景状态已改变：${shifts.map((e) => e.title).join('；')}',
        branchChoiceId: simulationChoiceId,
      );
    }

    if (rewardClaimed && !previous.rewardClaimed) {
      final shifts = sceneStateShiftsForChoice(sceneId: sceneId, choiceId: simulationChoiceId, profile: profile);
      final body = shifts.isEmpty
          ? '你领取了 ${scene.rewardTitle}，并把这一关的收获带回现实。'
          : '你领取了 ${scene.rewardTitle}。下一关状态变化：${shifts.map((e) => e.title).join('；')}';
      await _appendWorldTimelineEvent(
        db: db,
        sceneId: sceneId,
        eventType: 'scene_reward',
        title: '领取了 ${scene.rewardTitle}',
        body: body,
        branchChoiceId: simulationChoiceId,
      );
    }

    final trimmedNote = realityNote.trim();
    if (trimmedNote.isNotEmpty && trimmedNote != previous.realityNote.trim() && previous.realityNote.trim().isEmpty) {
      await _appendWorldTimelineEvent(
        db: db,
        sceneId: sceneId,
        eventType: 'reality_note',
        title: '把 ${scene.title} 的收获翻译回现实',
        body: trimmedNote,
        branchChoiceId: simulationChoiceId,
      );
    }

    final mergedProgress = await _listWorldSceneProgressFromDb(db);
    final statusNote = trimmedNote.isNotEmpty
        ? '在 ${scene.title} 完成了一次现实翻译：$trimmedNote'
        : '在 ${scene.title} 推进了一次场景练习。';
    await _captureWorldStatusSnapshot(
      db: db,
      profile: profile,
      progressList: mergedProgress,
      sourceType: 'scene',
      sourceId: sceneId,
      note: statusNote,
    );
    await _syncWorldIdentityEvolution(
      db: db,
      profile: profile,
      progressList: mergedProgress,
      sourceSceneId: sceneId,
    );
  }

  Future<GoalWorkshopDraft> mergeWorldSceneIntoWorkshop({
    required String sceneId,
    required String realityNote,
  }) async {
    final current = await getWorkshopDraft();
    final note = realityNote.trim();

    String appendUnique(String base, String line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return base;
      if (base.trim().isEmpty) return trimmed;
      if (base.contains(trimmed)) return base;
      return '${base.trim()}\n$trimmed';
    }

    var identityStatement = current.identityStatement;
    var vision = current.vision;
    var whyText = current.whyText;
    var realityProblem = current.realityProblem;
    var externalExpectation = current.externalExpectation;
    var competingGoal = current.competingGoal;
    var lifeline = current.lifeline;
    var stretchScore = current.stretchScore;
    var weeklyGoal = current.weeklyGoal;
    var firstStep = current.firstStep;
    var ifThenText = current.ifThenText;

    switch (sceneId) {
      case 'fog_plain':
        if (note.isNotEmpty) {
          vision = vision.trim().isEmpty ? note : appendUnique(vision, note);
          identityStatement = appendUnique(identityStatement, '我现在想优先活出的方向：$note');
        }
        break;
      case 'mirror_lake':
        if (note.isNotEmpty) {
          whyText = appendUnique(whyText, '来自镜湖：$note');
          realityProblem = appendUnique(realityProblem, '需要继续校准这个目标是否真正属于我。');
        }
        break;
      case 'workshop_city':
        if (note.isNotEmpty) {
          weeklyGoal = weeklyGoal.trim().isEmpty ? note : appendUnique(weeklyGoal, note);
          firstStep = firstStep.trim().isEmpty ? note : firstStep;
          ifThenText = appendUnique(ifThenText, '如果今天开始拖延或分心，那么我先完成：$note');
        }
        break;
    }

    final merged = GoalWorkshopDraft(
      identityStatement: identityStatement,
      vision: vision,
      whyText: whyText,
      realityProblem: realityProblem,
      externalExpectation: externalExpectation,
      competingGoal: competingGoal,
      lifeline: lifeline,
      stretchScore: stretchScore,
      weeklyGoal: weeklyGoal,
      firstStep: firstStep,
      ifThenText: ifThenText,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    await saveWorkshopDraft(
      identityStatement: merged.identityStatement,
      vision: merged.vision,
      whyText: merged.whyText,
      realityProblem: merged.realityProblem,
      externalExpectation: merged.externalExpectation,
      competingGoal: merged.competingGoal,
      lifeline: merged.lifeline,
      stretchScore: merged.stretchScore,
      weeklyGoal: merged.weeklyGoal,
      firstStep: merged.firstStep,
      ifThenText: merged.ifThenText,
    );
    return merged;
  }


  Future<GoalWorldProfile> getWorldProfile() async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('goal_world_profile', where: 'id=1', limit: 1);
    if (rows.isEmpty) return GoalWorldProfile.empty();
    return GoalWorldProfile.fromRow(rows.first);
  }

  Future<void> saveWorldProfile({
    required String roleTitle,
    required String lifeArea,
    required String realEvent,
    required String currentFeeling,
    required String desiredIdentity,
  }) async {
    final db = await _db();
    await ensureTables();
    final previous = await getWorldProfile();
    final profile = GoalWorldProfile(
      roleTitle: roleTitle,
      lifeArea: lifeArea,
      realEvent: realEvent,
      currentFeeling: currentFeeling,
      desiredIdentity: desiredIdentity,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await db.insert('goal_world_profile', profile.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    if (profile.hasContent &&
        (profile.roleTitle != previous.roleTitle ||
            profile.lifeArea != previous.lifeArea ||
            profile.realEvent != previous.realEvent ||
            profile.currentFeeling != previous.currentFeeling ||
            profile.desiredIdentity != previous.desiredIdentity)) {
      await _appendWorldTimelineEvent(
        db: db,
        sceneId: '',
        eventType: 'profile_update',
        title: '更新了世界身份',
        body: '${profile.profileTitle}${profile.summaryLine.trim().isEmpty ? '' : ' · ${profile.summaryLine.trim()}'}',
      );
    }
    final progress = await _listWorldSceneProgressFromDb(db);
    await _captureWorldStatusSnapshot(
      db: db,
      profile: profile,
      progressList: progress,
      sourceType: 'profile',
      sourceId: 'world_profile',
      note: profile.hasContent ? '更新了世界身份与现实处境。' : '初始化了世界身份。',
    );
    await _syncWorldIdentityEvolution(
      db: db,
      profile: profile,
      progressList: progress,
      sourceSceneId: '',
    );
  }

  Future<Map<String, int>> getStatsSummary() async {
    final db = await _db();
    await seedIfNeeded();
    Future<int> count(String sql) async => Sqflite.firstIntValue(await db.rawQuery(sql)) ?? 0;
    return {
      'segments': await count('SELECT COUNT(1) FROM goal_course_segment'),
      'concepts': await count('SELECT COUNT(1) FROM goal_concept_card'),
      'reviewed': await count('SELECT COUNT(1) FROM goal_segment_review WHERE reviewed_at_ms > 0'),
      'favorites': await count('SELECT COUNT(1) FROM goal_segment_review WHERE is_favorited = 1'),
      'difficult': await count('SELECT COUNT(1) FROM goal_segment_review WHERE is_difficult = 1'),
      'keys': await count('SELECT COUNT(1) FROM goal_segment_review WHERE is_key = 1'),
      'actions': await count('SELECT COUNT(1) FROM goal_action_record'),
      'followups': await count("SELECT COUNT(1) FROM goal_action_followup WHERE decision <> '' OR reflection_text <> '' OR next_step <> '' OR weekly_focus <> ''"),
      'modules': await count('SELECT COUNT(DISTINCT module_group) FROM goal_course_segment'),
      'worldScenes': await count('SELECT COUNT(1) FROM goal_world_scene_progress'),
      'worldRewards': await count('SELECT COUNT(1) FROM goal_world_scene_progress WHERE reward_claimed = 1'),
      'worldTimeline': await count('SELECT COUNT(1) FROM goal_world_timeline_event'),
      'worldIdentityShifts': await count("SELECT COUNT(1) FROM goal_world_timeline_event WHERE event_type = 'identity_shift'"),
      'moduleReviews': await count("SELECT COUNT(1) FROM goal_module_reflection WHERE summary_text <> '' OR insight_text <> '' OR action_text <> ''"),
      'moduleReviewActions': await count("SELECT COUNT(1) FROM goal_action_record WHERE instr(action_id, 'module_review_') = 1"),
      'moduleReviewFollowups': await count("SELECT COUNT(1) FROM goal_action_followup f JOIN goal_action_record r ON r.id = f.action_record_id WHERE instr(r.action_id, 'module_review_') = 1 AND (f.decision <> '' OR f.reflection_text <> '' OR f.next_step <> '' OR f.weekly_focus <> '')"),
    };
  }

  Future<List<GoalModuleReviewProgress>> listModuleReviewProgress({String? sourceCourse}) async {
    final db = await _db();
    await ensureTables();
    final modules = await db.rawQuery('''
      SELECT source_course, source_course_name, module_group,
             COUNT(1) AS total_count,
             SUM(CASE WHEN COALESCE(r.reviewed_at_ms, 0) > 0 THEN 1 ELSE 0 END) AS reviewed_count
      FROM goal_course_segment s
      LEFT JOIN goal_segment_review r ON r.segment_id = s.segment_id
      ${sourceCourse == null ? '' : 'WHERE s.source_course = ?'}
      GROUP BY source_course, source_course_name, module_group
      ORDER BY MIN(CASE source_course WHEN 'PP12' THEN 1 ELSE 2 END), MIN(segment_no)
    ''', sourceCourse == null ? [] : [sourceCourse]);
    final out = <GoalModuleReviewProgress>[];
    for (final row in modules) {
      final sc = (row['source_course'] ?? '').toString();
      final scn = (row['source_course_name'] ?? '').toString();
      final mg = (row['module_group'] ?? '').toString();
      final ritualKey = 'module:$sc:$mg';
      final reflection = await getModuleReflection(ritualKey: ritualKey, sourceCourse: sc, moduleGroup: mg);
      final actionPrefix = 'module_review_${ritualKey}_';
      final actionCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(1) FROM goal_action_record WHERE instr(action_id, ?) = 1',
            [actionPrefix],
          )) ??
          0;
      final followupCount = Sqflite.firstIntValue(await db.rawQuery(
            '''
            SELECT COUNT(1)
            FROM goal_action_followup f
            JOIN goal_action_record r ON r.id = f.action_record_id
            WHERE instr(r.action_id, ?) = 1
              AND (f.decision <> '' OR f.reflection_text <> '' OR f.next_step <> '' OR f.weekly_focus <> '')
            ''',
            [actionPrefix],
          )) ??
          0;
      out.add(GoalModuleReviewProgress(
        ritualKey: ritualKey,
        sourceCourse: sc,
        sourceCourseName: scn,
        moduleGroup: mg,
        totalSegments: (row['total_count'] as num?)?.toInt() ?? 0,
        reviewedSegments: (row['reviewed_count'] as num?)?.toInt() ?? 0,
        hasReflection: reflection.hasContent,
        hasActionStep: reflection.actionText.trim().isNotEmpty,
        actionCount: actionCount,
        followupCount: followupCount,
        updatedAtMs: reflection.updatedAtMs,
      ));
    }
    return out;
  }

  Future<GoalWorkshopDraft> getWorkshopDraft() async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('goal_workshop_draft', where: 'id=1', limit: 1);
    if (rows.isEmpty) return GoalWorkshopDraft.empty();
    return GoalWorkshopDraft.fromRow(rows.first);
  }

  Future<void> saveWorkshopDraft({
    required String identityStatement,
    required String vision,
    required String whyText,
    required String realityProblem,
    required String externalExpectation,
    required String competingGoal,
    required String lifeline,
    required double stretchScore,
    required String weeklyGoal,
    required String firstStep,
    required String ifThenText,
  }) async {
    final db = await _db();
    await ensureTables();
    final draft = GoalWorkshopDraft(
      identityStatement: identityStatement,
      vision: vision,
      whyText: whyText,
      realityProblem: realityProblem,
      externalExpectation: externalExpectation,
      competingGoal: competingGoal,
      lifeline: lifeline,
      stretchScore: stretchScore,
      weeklyGoal: weeklyGoal,
      firstStep: firstStep,
      ifThenText: ifThenText,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await db.insert('goal_workshop_draft', draft.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
