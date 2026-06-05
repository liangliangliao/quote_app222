import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quote_app/data/db.dart';
import 'fp_models.dart';

/// Failure & Perfectionism module DAO.
///
/// - Seeds from assets/failure_module/seed_failure_perfection.json
/// - Stores user progress and practice logs in fp_* tables.
class FpDao {
  Future<Database> _db() => AppDatabase.instance();

  Future<void> ensureTables() async {
    final db = await _db();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fp_episode (
        episode_no INTEGER PRIMARY KEY,
        title_zh TEXT NOT NULL,
        title_en TEXT NOT NULL,
        total_big_sections INTEGER NOT NULL DEFAULT 0,
        total_segments INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fp_big_section (
        id TEXT PRIMARY KEY,
        episode_no INTEGER NOT NULL,
        section_index INTEGER NOT NULL,
        title TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fp_segment (
        segment_id TEXT PRIMARY KEY,
        episode_no INTEGER NOT NULL,
        big_section_id TEXT NOT NULL,
        sort_index INTEGER NOT NULL,
        summary_zh TEXT NOT NULL,
        excerpt_en TEXT NOT NULL DEFAULT '',
        primary_node TEXT NOT NULL,
        secondary_nodes_json TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fp_concept_node (
        node_id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        name TEXT NOT NULL,
        definition TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fp_concept_edge (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_node TEXT NOT NULL,
        to_node TEXT NOT NULL,
        relation TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fp_template (
        template_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        schema_json TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fp_task (
        task_id TEXT PRIMARY KEY,
        concept_id TEXT NOT NULL,
        title TEXT NOT NULL,
        difficulty INTEGER NOT NULL DEFAULT 2,
        duration_min INTEGER NOT NULL DEFAULT 10,
        description TEXT NOT NULL,
        template_id TEXT NOT NULL DEFAULT 'T_NOTE',
        steps_json TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fp_progress (
        key TEXT PRIMARY KEY,
        status INTEGER NOT NULL DEFAULT 0,
        updated_at_ms INTEGER NOT NULL DEFAULT 0,
        payload_json TEXT NOT NULL DEFAULT '{}'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fp_practice_run (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id TEXT NOT NULL,
        ts_ms INTEGER NOT NULL,
        result_json TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fp_learning_card (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts_ms INTEGER NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        tags_json TEXT NOT NULL DEFAULT '[]'
      )
    ''');
  }

  Future<void> seedIfNeeded() async {
    final db = await _db();
    await ensureTables();
    final cnt = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(1) FROM fp_segment')) ?? 0;
    if (cnt > 0) return;

    final seedStr = await rootBundle.loadString('assets/failure_module/seed_failure_perfection.json');
    final seed = jsonDecode(seedStr) as Map<String, dynamic>;

    await db.transaction((txn) async {
      // Episodes
      final eps = (seed['episodes'] as List?) ?? const [];
      for (final e in eps) {
        final m = (e as Map).cast<String, dynamic>();
        await txn.insert('fp_episode', {
          'episode_no': (m['episode_no'] as num).toInt(),
          'title_zh': (m['title_zh'] ?? '').toString(),
          'title_en': (m['title_en'] ?? '').toString(),
          'total_big_sections': (m['total_big_sections'] as num?)?.toInt() ?? 0,
          'total_segments': (m['total_segments'] as num?)?.toInt() ?? 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Big sections
      final bss = (seed['big_sections'] as List?) ?? const [];
      for (final e in bss) {
        final m = (e as Map).cast<String, dynamic>();
        await txn.insert('fp_big_section', {
          'id': (m['id'] ?? '').toString(),
          'episode_no': (m['episode_no'] as num).toInt(),
          'section_index': (m['section_index'] as num?)?.toInt() ?? 0,
          'title': (m['title'] ?? '').toString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Segments
      final segs = (seed['segments'] as List?) ?? const [];
      for (final e in segs) {
        final m = (e as Map).cast<String, dynamic>();
        await txn.insert('fp_segment', {
          'segment_id': (m['segment_id'] ?? '').toString(),
          'episode_no': (m['episode_no'] as num).toInt(),
          'big_section_id': (m['big_section_id'] ?? '').toString(),
          'sort_index': (m['sort_index'] as num?)?.toInt() ?? 0,
          'summary_zh': (m['summary_zh'] ?? '').toString(),
          'excerpt_en': (m['excerpt_en'] ?? '').toString(),
          'primary_node': (m['primary_node'] ?? '').toString(),
          'secondary_nodes_json': jsonEncode(m['secondary_nodes'] ?? []),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Concept nodes
      final nodes = (seed['concept_nodes'] as List?) ?? const [];
      final conceptIdSet = <String>{};
      for (final e in nodes) {
        final m = (e as Map).cast<String, dynamic>();
        final nodeId = (m['node_id'] ?? '').toString();
        if (nodeId.isNotEmpty) conceptIdSet.add(nodeId);
        await txn.insert('fp_concept_node', {
          'node_id': nodeId,
          'category': (m['category'] ?? '').toString(),
          'name': (m['name'] ?? '').toString(),
          'definition': (m['definition'] ?? '').toString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Concept edges
      final es = (seed['concept_edges'] as List?) ?? const [];
      for (final e in es) {
        final m = (e as Map).cast<String, dynamic>();
        await txn.insert('fp_concept_edge', {
          'from_node': (m['from_node'] ?? '').toString(),
          'to_node': (m['to_node'] ?? '').toString(),
          'relation': (m['relation'] ?? '').toString(),
        });
      }

      // Templates
      final ts = (seed['templates'] as List?) ?? const [];
      for (final e in ts) {
        final m = (e as Map).cast<String, dynamic>();
        await txn.insert('fp_template', {
          'template_id': (m['template_id'] ?? '').toString(),
          'name': (m['name'] ?? '').toString(),
          'schema_json': (m['schema_json'] ?? '{}').toString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Tasks
      final ks = (seed['tasks'] as List?) ?? const [];
      final taskIdSet = <String>{};
      for (final e in ks) {
        final m = (e as Map).cast<String, dynamic>();
        final tid = (m['task_id'] ?? '').toString();
        if (tid.isNotEmpty) taskIdSet.add(tid);
        await txn.insert('fp_task', {
          'task_id': tid,
          'concept_id': (m['concept_id'] ?? '').toString(),
          'title': (m['title'] ?? '').toString(),
          'difficulty': (m['difficulty'] as num?)?.toInt() ?? 2,
          'duration_min': (m['duration_min'] as num?)?.toInt() ?? 10,
          'description': (m['description'] ?? '').toString(),
          'template_id': (m['template_id'] ?? 'T_NOTE').toString(),
          'steps_json': jsonEncode(m['steps'] ?? []),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Auto-generate per-concept default tasks so every segment has a runnable exercise.
      for (final cid in conceptIdSet) {
        final tid = 'TASK_$cid';
        if (taskIdSet.contains(tid)) continue;
        await txn.insert('fp_task', {
          'task_id': tid,
          'concept_id': cid,
          'title': '概念练习：$cid',
          'difficulty': 2,
          'duration_min': 10,
          'description': '用一句话写下你今天在现实中遇到的“$cid”实例，并给出一个最小行动。',
          'template_id': 'T_NOTE',
          'steps_json': jsonEncode([
            '写下：发生了什么？',
            '写下：我脑中“必须完美/不能失败”的声音是什么？',
            '写下：我愿意做的最小一步是什么（10分钟内可完成）？',
          ]),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  // ------------------------------------------------------------------------
  // Read APIs
  // ------------------------------------------------------------------------

  Future<List<FpEpisode>> listEpisodes() async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('fp_episode', orderBy: 'episode_no ASC');
    return rows.map((r) => FpEpisode.fromMap(r)).toList();
  }

  Future<List<FpBigSection>> listBigSections(int episodeNo) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'fp_big_section',
      where: 'episode_no=?',
      whereArgs: [episodeNo],
      orderBy: 'section_index ASC',
    );
    return rows.map((r) => FpBigSection.fromMap(r)).toList();
  }

  Future<List<FpSegment>> listSegmentsForBigSection(String bigSectionId) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'fp_segment',
      where: 'big_section_id=?',
      whereArgs: [bigSectionId],
      orderBy: 'sort_index ASC',
    );
    return rows.map((r) => FpSegment.fromMap({
          ...r,
          'secondary_nodes': r['secondary_nodes_json'],
        })).toList();
  }

  Future<FpSegment?> getSegment(String segmentId) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('fp_segment', where: 'segment_id=?', whereArgs: [segmentId], limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return FpSegment.fromMap({
      ...r,
      'secondary_nodes': r['secondary_nodes_json'],
    });
  }

  Future<List<FpConceptNode>> listConceptNodes({String? category}) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'fp_concept_node',
      where: category == null ? null : 'category=?',
      whereArgs: category == null ? null : [category],
      orderBy: 'category ASC, node_id ASC',
    );
    return rows.map((r) => FpConceptNode.fromMap(r)).toList();
  }

  Future<FpConceptNode?> getConceptNode(String nodeId) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('fp_concept_node', where: 'node_id=?', whereArgs: [nodeId], limit: 1);
    if (rows.isEmpty) return null;
    return FpConceptNode.fromMap(rows.first);
  }

  Future<List<FpConceptEdge>> listConceptEdges() async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('fp_concept_edge', orderBy: 'id ASC');
    return rows.map((r) => FpConceptEdge.fromMap(r)).toList();
  }

  Future<List<FpSegment>> listSegmentsByConcept(String nodeId) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'fp_segment',
      where: 'primary_node=? OR secondary_nodes_json LIKE ?',
      whereArgs: [nodeId, '%"$nodeId"%'],
      orderBy: 'episode_no ASC, big_section_id ASC, sort_index ASC',
    );
    return rows.map((r) => FpSegment.fromMap({
          ...r,
          'secondary_nodes': r['secondary_nodes_json'],
        })).toList();
  }

  Future<List<FpTask>> listTasks({String? conceptId}) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'fp_task',
      where: conceptId == null ? null : 'concept_id=?',
      whereArgs: conceptId == null ? null : [conceptId],
      orderBy: 'difficulty ASC, duration_min ASC, title ASC',
    );
    return rows.map((r) => FpTask.fromMap(r)).toList();
  }

  Future<FpTask?> getTask(String taskId) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('fp_task', where: 'task_id=?', whereArgs: [taskId], limit: 1);
    if (rows.isEmpty) return null;
    return FpTask.fromMap(rows.first);
  }

  Future<FpTemplate?> getTemplate(String templateId) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('fp_template', where: 'template_id=?', whereArgs: [templateId], limit: 1);
    if (rows.isEmpty) return null;
    return FpTemplate.fromMap(rows.first);
  }

  // ------------------------------------------------------------------------
  // Progress + Logs
  // ------------------------------------------------------------------------

  Future<int> getProgressStatus(String key) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('fp_progress', where: 'key=?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return 0;
    return (rows.first['status'] as num?)?.toInt() ?? 0;
  }

  Future<void> upsertProgress(String key, {required int status, Map<String, dynamic>? payload}) async {
    final db = await _db();
    await ensureTables();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'fp_progress',
      {
        'key': key,
        'status': status,
        'updated_at_ms': now,
        'payload_json': jsonEncode(payload ?? {}),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> addPracticeRun({required String taskId, required Map<String, dynamic> result}) async {
    final db = await _db();
    await ensureTables();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('fp_practice_run', {
      'task_id': taskId,
      'ts_ms': now,
      'result_json': jsonEncode(result),
    });
  }

  Future<List<FpPracticeRun>> listPracticeRuns({String? taskId, int limit = 50}) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'fp_practice_run',
      where: taskId == null ? null : 'task_id=?',
      whereArgs: taskId == null ? null : [taskId],
      orderBy: 'ts_ms DESC',
      limit: limit,
    );
    return rows.map((r) => FpPracticeRun.fromMap(r)).toList();
  }

  Future<int> addLearningCard({required String title, required String body, List<String>? tags}) async {
    final db = await _db();
    await ensureTables();
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.insert('fp_learning_card', {
      'ts_ms': now,
      'title': title,
      'body': body,
      'tags_json': jsonEncode(tags ?? []),
    });
  }

  Future<List<FpLearningCard>> listLearningCards({int limit = 200}) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('fp_learning_card', orderBy: 'ts_ms DESC', limit: limit);
    return rows.map((r) => FpLearningCard.fromMap(r)).toList();
  }

  Future<void> deleteLearningCard(int id) async {
    final db = await _db();
    await ensureTables();
    await db.delete('fp_learning_card', where: 'id=?', whereArgs: [id]);
  }

  Future<void> updateLearningCard({
    required int id,
    required String title,
    required String body,
    List<String>? tags,
  }) async {
    final db = await _db();
    await ensureTables();
    await db.update(
      'fp_learning_card',
      {
        'title': title,
        'body': body,
        'tags_json': jsonEncode(tags ?? []),
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }
}
