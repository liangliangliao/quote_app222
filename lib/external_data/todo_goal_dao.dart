import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'todo_dao.dart';
import 'todo_failure_growth_models.dart';
import 'todo_goal_models.dart';
import 'todo_models.dart';

class TodoGoalDao {
  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db);
    return db;
  }

  Future<void> ensureTables([Database? database]) async {
    final db = database ?? await AppDatabase.instance();
    await TodoDao().ensureTables(db);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_profiles (
        goal_id TEXT PRIMARY KEY,
        source_type TEXT NOT NULL,
        source_task_id TEXT,
        source_list_id TEXT,
        goal_title TEXT NOT NULL,
        deep_meaning TEXT,
        desired_identity TEXT,
        goal_category TEXT,
        goal_origin_type TEXT,
        self_concordance_score INTEGER DEFAULT 0,
        process_value TEXT,
        obstacle_summary TEXT,
        result_goal TEXT,
        value_goal TEXT,
        process_goal TEXT,
        core_values TEXT,
        autonomy_score INTEGER DEFAULT 0,
        value_alignment_score INTEGER DEFAULT 0,
        interest_connection_score INTEGER DEFAULT 0,
        passion_score INTEGER DEFAULT 0,
        feasibility_score INTEGER DEFAULT 0,
        external_pressure_score INTEGER DEFAULT 0,
        process_happiness_score INTEGER DEFAULT 0,
        goal_type TEXT,
        current_stage TEXT,
        user_need_interpretation TEXT,
        key_uncertainties TEXT,
        clarifying_questions TEXT,
        possible_directions TEXT,
        reference_cases TEXT,
        recommendation_rationale TEXT,
        user_decision_prompt TEXT,
        ai_provider TEXT,
        ai_model_label TEXT,
        ai_used_fallback INTEGER DEFAULT 0,
        status TEXT DEFAULT 'active',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_action_steps (
        step_id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        source_task_id TEXT,
        parent_step_id TEXT DEFAULT '',
        step_level INTEGER DEFAULT 1,
        sort_order INTEGER DEFAULT 0,
        action_place TEXT,
        start_trigger TEXT,
        completion_question TEXT,
        action_type TEXT DEFAULT 'result',
        experience_intention TEXT,
        title TEXT NOT NULL,
        minimum_standard TEXT,
        simplified_standard TEXT,
        recommended_standard TEXT,
        stretch_standard TEXT,
        difficulty_score INTEGER DEFAULT 5,
        zone_type TEXT,
        planned_date TEXT,
        planned_time TEXT,
        status TEXT DEFAULT 'not_started',
        completed_at_ms INTEGER,
        write_back_to_todo INTEGER DEFAULT 0,
        remote_task_id TEXT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_reflections (
        reflection_id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        step_id TEXT,
        reflection_date TEXT NOT NULL,
        what_done TEXT,
        why_done TEXT,
        process_experience TEXT,
        obstacle TEXT,
        tomorrow_next_step TEXT,
        ai_summary TEXT,
        mood_score INTEGER DEFAULT 0,
        meaning_score INTEGER DEFAULT 0,
        process_score INTEGER DEFAULT 0,
        body_signal TEXT,
        emotion_label TEXT,
        cognition TEXT,
        authentic_truth TEXT,
        feedback_source TEXT,
        feedback_content TEXT,
        feedback_learning TEXT,
        core_pattern TEXT,
        core_value TEXT,
        action_experiment TEXT,
        action_when TEXT,
        action_evidence TEXT,
        follow_up_question TEXT,
        review_mode TEXT DEFAULT 'daily',
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_ai_analysis (
        analysis_id TEXT PRIMARY KEY,
        goal_id TEXT,
        source_task_id TEXT,
        analysis_type TEXT NOT NULL,
        prompt_text TEXT,
        result_json TEXT,
        model_name TEXT,
        token_usage INTEGER DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_sync_links (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id TEXT NOT NULL,
        local_step_id TEXT,
        todo_list_id TEXT,
        todo_task_id TEXT,
        sync_direction TEXT,
        last_sync_at_ms INTEGER,
        local_status TEXT DEFAULT 'synced'
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_solution_plans (
        solution_id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        source_task_id TEXT,
        title TEXT NOT NULL,
        method_name TEXT,
        method_basis TEXT,
        zone_type TEXT DEFAULT 'stretch',
        core_value_focus TEXT,
        summary TEXT,
        risk_notes TEXT,
        problem_definition TEXT,
        known_facts TEXT,
        key_assumptions TEXT,
        root_cause_analysis TEXT,
        option_comparison TEXT,
        evidence_plan TEXT,
        success_metrics TEXT,
        stop_conditions TEXT,
        user_choice_guidance TEXT,
        is_selected INTEGER DEFAULT 0,
        status TEXT DEFAULT 'candidate',
        sort_order INTEGER DEFAULT 0,
        raw_json TEXT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_problem_nodes (
        node_id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        solution_id TEXT NOT NULL,
        parent_node_id TEXT DEFAULT '',
        relation_type TEXT DEFAULT 'tree',
        node_type TEXT DEFAULT 'problem',
        title TEXT NOT NULL,
        description TEXT,
        acceptance_criteria TEXT,
        actionable_step TEXT,
        action_when TEXT,
        action_where TEXT,
        action_object TEXT,
        action_procedure TEXT,
        action_output TEXT,
        zone_type TEXT DEFAULT 'stretch',
        difficulty_score INTEGER DEFAULT 5,
        estimated_minutes INTEGER DEFAULT 5,
        sequence_order INTEGER DEFAULT 0,
        dependencies_json TEXT,
        logic_question TEXT,
        known_facts TEXT,
        assumptions TEXT,
        evidence_needed TEXT,
        decision_rule TEXT,
        status TEXT DEFAULT 'not_started',
        completion_note TEXT,
        ai_review_json TEXT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_step_reviews (
        review_id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        step_id TEXT,
        node_id TEXT,
        user_result TEXT,
        user_text TEXT,
        ai_analysis TEXT,
        restart_guidance TEXT,
        alternative_steps_json TEXT,
        selected_alternative_json TEXT,
        restructured_plan_id TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_rituals (
        ritual_id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        trigger_text TEXT,
        minimum_action TEXT,
        minimum_minutes INTEGER DEFAULT 2,
        reward_or_record TEXT,
        environment_design TEXT,
        friction_plan TEXT,
        stability_score INTEGER DEFAULT 0,
        status TEXT DEFAULT 'active',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_failure_growth_loops (
        loop_id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        linked_step_id TEXT,
        event_text TEXT NOT NULL,
        emotion_text TEXT,
        automatic_thought TEXT,
        feared_outcome TEXT,
        pattern_code TEXT,
        pattern_label TEXT,
        fact_statement TEXT,
        growth_reframe TEXT,
        learning_signal TEXT,
        recovery_plan TEXT,
        experiment_title TEXT,
        minimum_standard TEXT,
        reflection_question TEXT,
        value_statement TEXT,
        result_text TEXT,
        next_revision TEXT,
        status TEXT DEFAULT 'active',
        created_at_ms INTEGER NOT NULL,
        completed_at_ms INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_effort_entries (
        entry_id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        step_id TEXT,
        effort_date TEXT NOT NULL,
        effort_minutes INTEGER DEFAULT 0,
        energy_level TEXT DEFAULT 'medium',
        emotion_state TEXT DEFAULT 'stable',
        available_minutes INTEGER DEFAULT 5,
        zone_type TEXT DEFAULT 'stretch',
        effort_type TEXT DEFAULT 'goal',
        investment_text TEXT,
        obstacle TEXT,
        strategy_used TEXT,
        small_progress TEXT,
        next_minimum_step TEXT,
        time_in_learning TEXT,
        identity_evidence TEXT,
        gratitude_text TEXT,
        joy_score INTEGER DEFAULT 0,
        reflection_depth INTEGER DEFAULT 0,
        strategy_changed INTEGER DEFAULT 0,
        returned_after_break INTEGER DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await _addColumnIfMissing(db, 'goal_action_steps', 'parent_step_id', "TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'goal_action_steps', 'step_level', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'goal_action_steps', 'sort_order', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'goal_action_steps', 'action_place', 'TEXT');
    await _addColumnIfMissing(db, 'goal_action_steps', 'start_trigger', 'TEXT');
    await _addColumnIfMissing(db, 'goal_action_steps', 'completion_question', 'TEXT');
    await _addColumnIfMissing(db, 'goal_action_steps', 'action_type', "TEXT DEFAULT 'result'");
    await _addColumnIfMissing(db, 'goal_action_steps', 'experience_intention', 'TEXT');
    await _addColumnIfMissing(db, 'goal_action_steps', 'simplified_standard', 'TEXT');

    // Positive-psychology goal framework: keep the four-layer goal card and
    // the full self-concordance diagnosis alongside synchronized To Do data.
    await _addColumnIfMissing(db, 'goal_profiles', 'result_goal', 'TEXT');
    await _addColumnIfMissing(db, 'goal_profiles', 'value_goal', 'TEXT');
    await _addColumnIfMissing(db, 'goal_profiles', 'process_goal', 'TEXT');
    await _addColumnIfMissing(db, 'goal_profiles', 'core_values', 'TEXT');
    await _addColumnIfMissing(db, 'goal_profiles', 'autonomy_score', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'goal_profiles', 'value_alignment_score', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'goal_profiles', 'interest_connection_score', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'goal_profiles', 'passion_score', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'goal_profiles', 'feasibility_score', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'goal_profiles', 'external_pressure_score', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'goal_profiles', 'process_happiness_score', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'goal_profiles', 'goal_type', 'TEXT');
    await _addColumnIfMissing(db, 'goal_profiles', 'current_stage', 'TEXT');
    await _addColumnIfMissing(db, 'goal_profiles', 'user_need_interpretation', 'TEXT');
    await _addColumnIfMissing(db, 'goal_profiles', 'key_uncertainties', 'TEXT');
    await _addColumnIfMissing(db, 'goal_profiles', 'clarifying_questions', 'TEXT');
    await _addColumnIfMissing(db, 'goal_profiles', 'possible_directions', 'TEXT');
    await _addColumnIfMissing(db, 'goal_profiles', 'reference_cases', 'TEXT');
    await _addColumnIfMissing(db, 'goal_profiles', 'recommendation_rationale', 'TEXT');
    await _addColumnIfMissing(db, 'goal_profiles', 'user_decision_prompt', 'TEXT');

    // v52: persist whether a goal came from real AI or from local fallback,
    // and repair core id columns that old/broken installs may miss.
    await _addColumnIfMissing(db, 'goal_profiles', 'ai_provider', 'TEXT');
    await _addColumnIfMissing(db, 'goal_profiles', 'ai_model_label', 'TEXT');
    await _addColumnIfMissing(db, 'goal_profiles', 'ai_used_fallback', 'INTEGER DEFAULT 0');

    // Reflective Growth: structured time-in, ABCDE, feedback, authenticity,
    // pattern and action-experiment evidence for old and new installations.
    await _addColumnIfMissing(db, 'goal_reflections', 'body_signal', 'TEXT');
    await _addColumnIfMissing(db, 'goal_reflections', 'emotion_label', 'TEXT');
    await _addColumnIfMissing(db, 'goal_reflections', 'cognition', 'TEXT');
    await _addColumnIfMissing(db, 'goal_reflections', 'authentic_truth', 'TEXT');
    await _addColumnIfMissing(db, 'goal_reflections', 'feedback_source', 'TEXT');
    await _addColumnIfMissing(db, 'goal_reflections', 'feedback_content', 'TEXT');
    await _addColumnIfMissing(db, 'goal_reflections', 'feedback_learning', 'TEXT');
    await _addColumnIfMissing(db, 'goal_reflections', 'core_pattern', 'TEXT');
    await _addColumnIfMissing(db, 'goal_reflections', 'core_value', 'TEXT');
    await _addColumnIfMissing(db, 'goal_reflections', 'action_experiment', 'TEXT');
    await _addColumnIfMissing(db, 'goal_reflections', 'action_when', 'TEXT');
    await _addColumnIfMissing(db, 'goal_reflections', 'action_evidence', 'TEXT');
    await _addColumnIfMissing(db, 'goal_reflections', 'follow_up_question', 'TEXT');
    await _addColumnIfMissing(db, 'goal_reflections', 'review_mode', "TEXT DEFAULT 'daily'");

    await _addColumnIfMissing(db, 'goal_solution_plans', 'solution_id', "TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'goal_solution_plans', 'goal_id', "TEXT DEFAULT ''");

    await _addColumnIfMissing(db, 'goal_problem_nodes', 'node_id', "TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'goal_id', "TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'solution_id', "TEXT DEFAULT ''");

    await _addColumnIfMissing(db, 'goal_step_reviews', 'review_id', "TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'goal_step_reviews', 'goal_id', "TEXT DEFAULT ''");

    // v51: old v50 installs may already have these tables but be missing later
    // columns such as sort_order. CREATE TABLE IF NOT EXISTS will not add
    // columns to an existing table, so every AI goal table must be repaired
    // idempotently on each open before any SELECT/ORDER BY runs.
    await _addColumnIfMissing(db, 'goal_solution_plans', 'title', "TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'goal_solution_plans', 'source_task_id', 'TEXT');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'method_name', 'TEXT');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'method_basis', 'TEXT');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'zone_type', "TEXT DEFAULT 'stretch'");
    await _addColumnIfMissing(db, 'goal_solution_plans', 'core_value_focus', 'TEXT');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'summary', 'TEXT');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'risk_notes', 'TEXT');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'problem_definition', 'TEXT');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'known_facts', 'TEXT');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'key_assumptions', 'TEXT');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'root_cause_analysis', 'TEXT');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'option_comparison', 'TEXT');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'evidence_plan', 'TEXT');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'success_metrics', 'TEXT');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'stop_conditions', 'TEXT');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'user_choice_guidance', 'TEXT');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'is_selected', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'status', "TEXT DEFAULT 'candidate'");
    await _addColumnIfMissing(db, 'goal_solution_plans', 'sort_order', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'raw_json', 'TEXT');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'created_at_ms', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'goal_solution_plans', 'updated_at_ms', 'INTEGER DEFAULT 0');

    await _addColumnIfMissing(db, 'goal_problem_nodes', 'title', "TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'parent_node_id', "TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'relation_type', "TEXT DEFAULT 'tree'");
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'node_type', "TEXT DEFAULT 'problem'");
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'description', 'TEXT');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'acceptance_criteria', 'TEXT');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'actionable_step', 'TEXT');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'action_when', 'TEXT');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'action_where', 'TEXT');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'action_object', 'TEXT');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'action_procedure', 'TEXT');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'action_output', 'TEXT');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'zone_type', "TEXT DEFAULT 'stretch'");
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'difficulty_score', 'INTEGER DEFAULT 5');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'estimated_minutes', 'INTEGER DEFAULT 5');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'sequence_order', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'dependencies_json', 'TEXT');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'logic_question', 'TEXT');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'known_facts', 'TEXT');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'assumptions', 'TEXT');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'evidence_needed', 'TEXT');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'decision_rule', 'TEXT');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'status', "TEXT DEFAULT 'not_started'");
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'completion_note', 'TEXT');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'ai_review_json', 'TEXT');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'created_at_ms', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'goal_problem_nodes', 'updated_at_ms', 'INTEGER DEFAULT 0');

    await _addColumnIfMissing(db, 'goal_step_reviews', 'step_id', 'TEXT');
    await _addColumnIfMissing(db, 'goal_step_reviews', 'node_id', 'TEXT');
    await _addColumnIfMissing(db, 'goal_step_reviews', 'user_result', 'TEXT');
    await _addColumnIfMissing(db, 'goal_step_reviews', 'user_text', 'TEXT');
    await _addColumnIfMissing(db, 'goal_step_reviews', 'ai_analysis', 'TEXT');
    await _addColumnIfMissing(db, 'goal_step_reviews', 'restart_guidance', 'TEXT');
    await _addColumnIfMissing(db, 'goal_step_reviews', 'alternative_steps_json', 'TEXT');
    await _addColumnIfMissing(db, 'goal_step_reviews', 'selected_alternative_json', 'TEXT');
    await _addColumnIfMissing(db, 'goal_step_reviews', 'restructured_plan_id', 'TEXT');
    await _addColumnIfMissing(db, 'goal_step_reviews', 'created_at_ms', 'INTEGER DEFAULT 0');

    await _repairLegacySolutionPlanAliases(db);
    await _repairGoalRuntimeIds(db);
  }

  Future<void> _repairGoalRuntimeIds(Database db) async {
    // These updates are intentionally SQLite-only and idempotent. They keep
    // old user data usable after a previous build created partial tables.
    await db.execute("""
      UPDATE goal_solution_plans
      SET solution_id = 'todo_solution_migrated_' || rowid || '_' || COALESCE(created_at_ms, 0)
      WHERE solution_id IS NULL OR TRIM(solution_id) = ''
    """);
    await db.execute("""
      UPDATE goal_problem_nodes
      SET node_id = 'todo_node_migrated_' || rowid || '_' || COALESCE(created_at_ms, 0)
      WHERE node_id IS NULL OR TRIM(node_id) = ''
    """);
    await db.execute("""
      UPDATE goal_problem_nodes
      SET solution_id = COALESCE((
        SELECT p.solution_id FROM goal_solution_plans p
        WHERE p.goal_id = goal_problem_nodes.goal_id
          AND COALESCE(p.solution_id, '') != ''
        ORDER BY p.is_selected DESC, p.sort_order ASC, p.created_at_ms ASC
        LIMIT 1
      ), '')
      WHERE solution_id IS NULL OR TRIM(solution_id) = ''
    """);
    await db.execute("""
      UPDATE goal_profiles
      SET ai_used_fallback = 1, ai_provider = COALESCE(NULLIF(ai_provider, ''), 'local')
      WHERE ai_used_fallback IS NULL
         OR ai_provider IS NULL
         OR TRIM(ai_provider) = ''
    """);
    await db.execute("""
      UPDATE goal_profiles
      SET ai_used_fallback = 0
      WHERE ai_provider IS NOT NULL
        AND TRIM(ai_provider) != ''
        AND LOWER(TRIM(ai_provider)) NOT IN ('local', 'fallback')
        AND COALESCE(ai_model_label, '') NOT LIKE '%本地%'
    """);
  }

  String newId(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}';


  Future<void> _addColumnIfMissing(Database db, String table, String column, String definition) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => (row['name'] ?? '').toString() == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<List<Map<String, Object?>>> _tableInfo(DatabaseExecutor db, String table) async {
    return db.rawQuery('PRAGMA table_info($table)');
  }

  Set<String> _columnNames(List<Map<String, Object?>> info) {
    return info.map((row) => (row['name'] ?? '').toString()).where((name) => name.isNotEmpty).toSet();
  }

  Object? _requiredColumnFallback(String table, String column, Map<String, Object?> values) {
    final c = column.toLowerCase();
    if (values.containsKey(column)) return values[column];
    if (c.contains('title') || c.contains('name')) {
      return values['title'] ?? values['goal_title'] ?? values['source_task_id'] ?? 'AI问题解决方案';
    }
    if (c == 'plan_title') return values['title'] ?? 'AI问题解决方案';
    if (c.contains('solution') && c.contains('id')) return values['solution_id'] ?? values['goal_id'] ?? newId('todo_solution_legacy');
    if (c.contains('node') && c.contains('id')) return values['node_id'] ?? values['solution_id'] ?? newId('todo_node_legacy');
    if (c.contains('goal') && c.contains('id')) return values['goal_id'] ?? '';
    if (c.contains('task') && c.contains('id')) return values['source_task_id'] ?? '';
    if (c.contains('created') || c.contains('updated') || c.endsWith('_ms')) return values['created_at_ms'] ?? values['updated_at_ms'] ?? DateTime.now().millisecondsSinceEpoch;
    if (c.contains('selected') || c.contains('completed') || c.contains('order') || c.contains('score') || c.contains('count')) return 0;
    if (c.contains('status')) return values['status'] ?? 'candidate';
    if (c.contains('zone')) return values['zone_type'] ?? 'stretch';
    return '';
  }

  Future<Map<String, Object?>> _compatibleInsertValues(
    DatabaseExecutor db,
    String table,
    Map<String, Object?> values, {
    Map<String, String> aliases = const <String, String>{},
  }) async {
    final info = await _tableInfo(db, table);
    final cols = _columnNames(info);
    final out = <String, Object?>{};
    for (final entry in values.entries) {
      if (cols.contains(entry.key)) out[entry.key] = entry.value;
    }
    for (final entry in aliases.entries) {
      final legacyColumn = entry.key;
      final sourceColumn = entry.value;
      if (cols.contains(legacyColumn) && !out.containsKey(legacyColumn)) {
        out[legacyColumn] = values[sourceColumn];
      }
    }
    for (final row in info) {
      final name = (row['name'] ?? '').toString();
      if (name.isEmpty || out.containsKey(name)) continue;
      final notNull = _toLocalInt(row['notnull']) == 1;
      final pk = _toLocalInt(row['pk']) == 1;
      final hasDefault = row['dflt_value'] != null;
      if (notNull && !pk && !hasDefault) {
        out[name] = _requiredColumnFallback(table, name, values);
      }
    }
    return out;
  }

  Future<void> _repairLegacySolutionPlanAliases(Database db) async {
    final info = await _tableInfo(db, 'goal_solution_plans');
    final cols = _columnNames(info);
    if (cols.contains('plan_title') && cols.contains('title')) {
      await db.execute("""
        UPDATE goal_solution_plans
        SET title = COALESCE(NULLIF(title, ''), plan_title, 'AI问题解决方案')
        WHERE title IS NULL OR TRIM(title) = ''
      """);
      await db.execute("""
        UPDATE goal_solution_plans
        SET plan_title = COALESCE(NULLIF(plan_title, ''), title, 'AI问题解决方案')
        WHERE plan_title IS NULL OR TRIM(plan_title) = ''
      """);
    }
    if (cols.contains('plan_id') && cols.contains('solution_id')) {
      await db.execute("""
        UPDATE goal_solution_plans
        SET solution_id = COALESCE(NULLIF(solution_id, ''), plan_id)
        WHERE solution_id IS NULL OR TRIM(solution_id) = ''
      """);
    }
    if (cols.contains('solution_id') && cols.contains('plan_id')) {
      await db.execute("""
        UPDATE goal_solution_plans
        SET plan_id = COALESCE(NULLIF(plan_id, ''), solution_id)
        WHERE plan_id IS NULL OR TRIM(plan_id) = ''
      """);
    }
  }

  int _toLocalInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String todayDate() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  Future<TodoGoalProfile?> getGoal(String goalId) async {
    final db = await _db;
    final rows = await db.query('goal_profiles', where: 'goal_id = ?', whereArgs: [goalId], limit: 1);
    if (rows.isEmpty) return null;
    return TodoGoalProfile.fromMap(rows.first);
  }

  Future<TodoGoalProfile?> getGoalForTask(String taskId) async {
    final db = await _db;
    final rows = await db.query('goal_profiles', where: 'source_task_id = ? AND status != ?', whereArgs: [taskId, 'deleted'], orderBy: 'updated_at_ms DESC', limit: 1);
    if (rows.isEmpty) return null;
    return TodoGoalProfile.fromMap(rows.first);
  }

  Future<TodoGoalActionStep?> getActionStep(String stepId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT s.*, COALESCE(g.goal_title, '') AS goal_title,
             COALESCE(g.deep_meaning, '') AS deep_meaning,
             COALESCE(g.process_value, '') AS process_value,
             COALESCE(g.source_list_id, '') AS source_list_id,
             COALESCE(p.title, '') AS parent_step_title
      FROM goal_action_steps s
      LEFT JOIN goal_profiles g ON g.goal_id = s.goal_id
      LEFT JOIN goal_action_steps p ON p.step_id = s.parent_step_id
      WHERE s.step_id = ?
      LIMIT 1
    ''', [stepId]);
    if (rows.isEmpty) return null;
    return TodoGoalActionStep.fromMap(rows.first);
  }

  Future<String> saveGoalFromAnalysis({
    required TodoTaskRecord task,
    required TodoGoalAnalysisResult analysis,
    String? existingGoalId,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final old = existingGoalId == null || existingGoalId.trim().isEmpty ? await getGoalForTask(task.taskId) : await getGoal(existingGoalId.trim());
    final goalId = old?.goalId ?? newId('todo_goal');
    await db.insert(
      'goal_profiles',
      <String, Object?>{
        'goal_id': goalId,
        'source_type': task.taskId.startsWith('manual_goal_') ? 'manual_input' : 'microsoft_todo',
        'source_task_id': task.taskId,
        'source_list_id': task.listId,
        'goal_title': analysis.goalTitle.trim().isEmpty ? task.title : analysis.goalTitle.trim(),
        'deep_meaning': analysis.deepMeaning,
        'desired_identity': analysis.desiredIdentity,
        'goal_category': analysis.goalCategory,
        'goal_origin_type': analysis.goalOriginType,
        'self_concordance_score': analysis.selfConcordanceScore.clamp(0, 100).toInt(),
        'process_value': analysis.processValue,
        'obstacle_summary': analysis.obstacleSummary,
        'result_goal': analysis.resultGoal.trim().isEmpty ? analysis.goalTitle : analysis.resultGoal,
        'value_goal': analysis.valueGoal.trim().isEmpty ? analysis.deepMeaning : analysis.valueGoal,
        'process_goal': analysis.processGoal.trim().isEmpty ? analysis.processValue : analysis.processGoal,
        'core_values': analysis.coreValues,
        'autonomy_score': analysis.autonomyScore.clamp(0, 100).toInt(),
        'value_alignment_score': analysis.valueAlignmentScore.clamp(0, 100).toInt(),
        'interest_connection_score': analysis.interestConnectionScore.clamp(0, 100).toInt(),
        'passion_score': analysis.passionScore.clamp(0, 100).toInt(),
        'feasibility_score': analysis.feasibilityScore.clamp(0, 100).toInt(),
        'external_pressure_score': analysis.externalPressureScore.clamp(0, 100).toInt(),
        'process_happiness_score': analysis.processHappinessScore.clamp(0, 100).toInt(),
        'goal_type': analysis.goalType,
        'current_stage': analysis.currentStage,
        'user_need_interpretation': analysis.userNeedInterpretation,
        'key_uncertainties': analysis.keyUncertainties,
        'clarifying_questions': analysis.clarifyingQuestions,
        'possible_directions': analysis.possibleDirections,
        'reference_cases': analysis.referenceCases,
        'recommendation_rationale': analysis.recommendationRationale,
        'user_decision_prompt': analysis.userDecisionPrompt,
        'ai_provider': analysis.provider,
        'ai_model_label': analysis.modelLabel,
        'ai_used_fallback': analysis.usedFallback ? 1 : 0,
        'status': old?.status ?? 'active',
        'created_at_ms': old?.createdAtMs ?? now,
        'updated_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final existingSteps = old == null ? <TodoGoalActionStep>[] : await listActionSteps(goalId);
    final actionDrafts = <({String type, String title, String minimum, String simplified, String recommended, int difficulty})>[
      (
        type: 'result',
        title: analysis.todayMinimumAction.trim().isEmpty ? '今天推进“${task.title}”5分钟' : analysis.todayMinimumAction.trim(),
        minimum: analysis.minimumStandard,
        simplified: analysis.simplifiedStandard,
        recommended: analysis.recommendedStandard,
        difficulty: analysis.difficultyScore,
      ),
      (
        type: 'process',
        title: analysis.processAction.trim().isEmpty ? '行动时只观察一次“我正在学习或鼓起勇气”的体验' : analysis.processAction.trim(),
        minimum: '行动2分钟，并记录一个真实的过程感受。',
        simplified: '行动5分钟，记录一个过程感受。',
        recommended: '完成主行动时，刻意关注学习感、投入感或掌控感。',
        difficulty: (analysis.difficultyScore - 1).clamp(1, 10).toInt(),
      ),
      (
        type: 'value',
        title: analysis.valueAction.trim().isEmpty ? '写一句：这一步如何服务于${analysis.coreValues.trim().isEmpty ? '我真正重视的生活' : analysis.coreValues}' : analysis.valueAction.trim(),
        minimum: '写下一句话，把行动与一个核心价值连接起来。',
        simplified: '写两句话：我重视什么、今天如何体现它。',
        recommended: '说明今天的行动如何增加选择、成长、关系、健康或贡献。',
        difficulty: 2,
      ),
    ];
    for (var index = 0; index < actionDrafts.length; index++) {
      final draft = actionDrafts[index];
      final hasOpenStep = existingSteps.any((step) => !step.isCompleted && step.actionType == draft.type && step.title.trim() == draft.title);
      if (hasOpenStep) continue;
      await createActionStep(
        goalId: goalId,
        sourceTaskId: task.taskId,
        title: draft.title,
        minimumStandard: draft.minimum,
        simplifiedStandard: draft.simplified,
        recommendedStandard: draft.recommended,
        stretchStandard: analysis.stretchStandard,
        difficultyScore: draft.difficulty,
        zoneType: draft.type == 'result' ? analysis.zoneType : 'comfort',
        plannedDate: todayDate(),
        actionPlace: analysis.actionPlace,
        startTrigger: index == 0 ? analysis.startTrigger : '完成或开始结果型行动时，立刻进入这一小步。',
        completionQuestion: analysis.completionQuestion,
        actionType: draft.type,
        experienceIntention: analysis.experiencePrompt,
        sortOrder: index,
      );
    }

    await addAiAnalysis(
      goalId: goalId,
      sourceTaskId: task.taskId,
      analysisType: 'task_to_goal_analysis',
      promptText: '',
      resultJson: jsonEncode(analysis.toJson()),
      modelName: analysis.modelLabel,
    );
    return goalId;
  }

  Future<String> createActionStep({
    required String goalId,
    required String sourceTaskId,
    required String title,
    String minimumStandard = '',
    String simplifiedStandard = '',
    String recommendedStandard = '',
    String stretchStandard = '',
    int difficultyScore = 5,
    String zoneType = 'stretch',
    String? plannedDate,
    String plannedTime = '',
    String parentStepId = '',
    int? stepLevel,
    int sortOrder = 0,
    String actionPlace = '',
    String startTrigger = '',
    String completionQuestion = '',
    String actionType = 'result',
    String experienceIntention = '',
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final stepId = newId('todo_step_goal');
    final normalizedParentId = parentStepId.trim();
    int normalizedLevel = stepLevel ?? 1;
    if (normalizedParentId.isNotEmpty) {
      final parentRows = await db.query('goal_action_steps', columns: ['step_level'], where: 'step_id = ?', whereArgs: [normalizedParentId], limit: 1);
      if (parentRows.isNotEmpty) {
        normalizedLevel = (_toLocalInt(parentRows.first['step_level']) == 0 ? 1 : _toLocalInt(parentRows.first['step_level'])) + 1;
      } else {
        normalizedLevel = 2;
      }
    }
    await db.insert('goal_action_steps', <String, Object?>{
      'step_id': stepId,
      'goal_id': goalId,
      'source_task_id': sourceTaskId,
      'parent_step_id': normalizedParentId,
      'step_level': normalizedLevel.clamp(1, 9).toInt(),
      'sort_order': sortOrder,
      'action_place': actionPlace,
      'start_trigger': startTrigger,
      'completion_question': completionQuestion,
      'action_type': const <String>{'result', 'process', 'value'}.contains(actionType) ? actionType : 'result',
      'experience_intention': experienceIntention,
      'title': title.trim().isEmpty ? '今天做一个5分钟最小行动' : title.trim(),
      'minimum_standard': minimumStandard,
      'simplified_standard': simplifiedStandard,
      'recommended_standard': recommendedStandard,
      'stretch_standard': stretchStandard,
      'difficulty_score': difficultyScore.clamp(1, 10).toInt(),
      'zone_type': zoneType.trim().isEmpty ? 'stretch' : zoneType.trim(),
      'planned_date': plannedDate ?? todayDate(),
      'planned_time': plannedTime,
      'status': 'not_started',
      'completed_at_ms': 0,
      'write_back_to_todo': 0,
      'remote_task_id': '',
      'created_at_ms': now,
      'updated_at_ms': now,
    });
    return stepId;
  }

  Future<List<TodoGoalProfile>> listGoals({int limit = 100}) async {
    final db = await _db;
    final rows = await db.query('goal_profiles', where: 'status != ?', whereArgs: ['deleted'], orderBy: 'updated_at_ms DESC', limit: limit);
    return rows.map(TodoGoalProfile.fromMap).toList();
  }

  Future<List<TodoGoalActionStep>> listActionSteps(String goalId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT s.*, COALESCE(g.goal_title, '') AS goal_title,
             COALESCE(g.deep_meaning, '') AS deep_meaning,
             COALESCE(g.process_value, '') AS process_value,
             COALESCE(g.source_list_id, '') AS source_list_id,
             COALESCE(p.title, '') AS parent_step_title
      FROM goal_action_steps s
      LEFT JOIN goal_profiles g ON g.goal_id = s.goal_id
      LEFT JOIN goal_action_steps p ON p.step_id = s.parent_step_id
      WHERE s.goal_id = ?
      ORDER BY COALESCE(s.parent_step_id, '') ASC, COALESCE(s.step_level, 1) ASC, COALESCE(s.sort_order, 0) ASC, s.created_at_ms ASC
    ''', [goalId]);
    return rows.map(TodoGoalActionStep.fromMap).toList();
  }

  Future<List<TodoGoalActionStep>> listTodaySteps({bool includeCompleted = true}) async {
    final db = await _db;
    final today = todayDate();
    final rows = await db.rawQuery('''
      SELECT s.*, g.goal_title, g.deep_meaning, g.process_value, g.source_list_id,
             COALESCE(p.title, '') AS parent_step_title
      FROM goal_action_steps s
      LEFT JOIN goal_profiles g ON g.goal_id = s.goal_id
      LEFT JOIN goal_action_steps p ON p.step_id = s.parent_step_id
      WHERE g.status = 'active'
        AND (s.planned_date = ? OR s.planned_date IS NULL OR s.planned_date = '')
        ${includeCompleted ? '' : "AND s.status != 'completed'"}
      ORDER BY CASE WHEN s.status = 'completed' THEN 1 ELSE 0 END,
               g.updated_at_ms DESC,
               COALESCE(s.step_level, 1) ASC,
               COALESCE(s.sort_order, 0) ASC,
               s.created_at_ms ASC
      LIMIT 100
    ''', [today]);
    return rows.map(TodoGoalActionStep.fromMap).toList();
  }

  Future<List<TodoTaskRecord>> listCandidateTasks({int limit = 80}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT t.*,
             COALESCE(l.display_name, '') AS list_display_name,
             (SELECT COUNT(*) FROM ms_todo_task_children c WHERE c.task_id = t.task_id AND c.child_type = 'checklistItem' AND COALESCE(c.local_deleted, 0) = 0) AS checklist_count,
             (SELECT COUNT(*) FROM ms_todo_task_children c WHERE c.task_id = t.task_id AND c.child_type = 'attachment' AND COALESCE(c.local_deleted, 0) = 0) AS attachment_count,
             (SELECT COUNT(*) FROM ms_todo_task_children c WHERE c.task_id = t.task_id AND c.child_type = 'linkedResource' AND COALESCE(c.local_deleted, 0) = 0) AS linked_resource_count
      FROM ms_todo_tasks t
      LEFT JOIN ms_todo_lists l ON l.list_id = t.list_id
      WHERE COALESCE(t.local_deleted, 0) = 0
        AND t.status != 'completed'
      ORDER BY CASE WHEN t.is_my_day = 1 THEN 0 ELSE 1 END,
               t.due_date_time ASC,
               t.last_modified_date_time DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(TodoTaskRecord.fromMap).toList();
  }


  Future<void> updateGoalStatus(String goalId, String status) async {
    final normalized = const <String>{'active', 'paused', 'archived', 'deleted'}.contains(status) ? status : 'active';
    final db = await _db;
    await db.update(
      'goal_profiles',
      <String, Object?>{'status': normalized, 'updated_at_ms': DateTime.now().millisecondsSinceEpoch},
      where: 'goal_id = ?',
      whereArgs: [goalId],
    );
  }

  Future<void> updateGoalAlignment({
    required String goalId,
    required String goalTitle,
    required String resultGoal,
    required String coreValues,
    required String valueGoal,
    required String processGoal,
  }) async {
    final db = await _db;
    await db.update(
      'goal_profiles',
      <String, Object?>{
        'goal_title': goalTitle.trim(),
        'result_goal': resultGoal.trim(),
        'core_values': coreValues.trim(),
        'value_goal': valueGoal.trim(),
        'process_goal': processGoal.trim(),
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'goal_id = ?',
      whereArgs: [goalId],
    );
  }

  Future<void> updateStepExperienceIntention(String stepId, String intention) async {
    final db = await _db;
    await db.update(
      'goal_action_steps',
      <String, Object?>{
        'experience_intention': intention.trim(),
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'step_id = ?',
      whereArgs: [stepId],
    );
  }

  Future<void> updateStepStatus(String stepId, String status) async {
    final db = await _db;
    final normalized = status.trim().isEmpty ? 'not_started' : status.trim();
    await db.update(
      'goal_action_steps',
      <String, Object?>{
        'status': normalized,
        'completed_at_ms': normalized == 'completed' ? DateTime.now().millisecondsSinceEpoch : 0,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'step_id = ?',
      whereArgs: [stepId],
    );
  }

  Future<void> completeStep(String stepId, {bool completed = true}) async {
    final db = await _db;
    await db.update(
      'goal_action_steps',
      <String, Object?>{
        'status': completed ? 'completed' : 'not_started',
        'completed_at_ms': completed ? DateTime.now().millisecondsSinceEpoch : 0,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'step_id = ?',
      whereArgs: [stepId],
    );
  }

  Future<void> markStepWrittenBack({required String stepId, required String remoteTaskId}) async {
    final db = await _db;
    await db.update(
      'goal_action_steps',
      <String, Object?>{'write_back_to_todo': 1, 'remote_task_id': remoteTaskId, 'updated_at_ms': DateTime.now().millisecondsSinceEpoch},
      where: 'step_id = ?',
      whereArgs: [stepId],
    );
  }

  Future<String> addReflection({
    required String goalId,
    required String stepId,
    required String whatDone,
    required String whyDone,
    required String processExperience,
    required String obstacle,
    required String tomorrowNextStep,
    required String aiSummary,
    int moodScore = 0,
    int meaningScore = 0,
    int processScore = 0,
    String bodySignal = '',
    String emotionLabel = '',
    String cognition = '',
    String authenticTruth = '',
    String feedbackSource = '',
    String feedbackContent = '',
    String feedbackLearning = '',
    String corePattern = '',
    String coreValue = '',
    String actionExperiment = '',
    String actionWhen = '',
    String actionEvidence = '',
    String followUpQuestion = '',
    String reviewMode = 'daily',
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = newId('todo_reflection');
    await db.insert('goal_reflections', <String, Object?>{
      'reflection_id': id,
      'goal_id': goalId,
      'step_id': stepId,
      'reflection_date': todayDate(),
      'what_done': whatDone,
      'why_done': whyDone,
      'process_experience': processExperience,
      'obstacle': obstacle,
      'tomorrow_next_step': tomorrowNextStep,
      'ai_summary': aiSummary,
      'mood_score': moodScore,
      'meaning_score': meaningScore,
      'process_score': processScore,
      'body_signal': bodySignal,
      'emotion_label': emotionLabel,
      'cognition': cognition,
      'authentic_truth': authenticTruth,
      'feedback_source': feedbackSource,
      'feedback_content': feedbackContent,
      'feedback_learning': feedbackLearning,
      'core_pattern': corePattern,
      'core_value': coreValue,
      'action_experiment': actionExperiment,
      'action_when': actionWhen,
      'action_evidence': actionEvidence,
      'follow_up_question': followUpQuestion,
      'review_mode': reviewMode,
      'created_at_ms': now,
    });
    return id;
  }

  Future<List<TodoGoalReflection>> listReflections({int limit = 80}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT r.*, COALESCE(g.goal_title, '') AS goal_title
      FROM goal_reflections r
      LEFT JOIN goal_profiles g ON g.goal_id = r.goal_id
      ORDER BY r.created_at_ms DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(TodoGoalReflection.fromMap).toList();
  }

  Future<void> addAiAnalysis({
    required String goalId,
    required String sourceTaskId,
    required String analysisType,
    required String promptText,
    required String resultJson,
    required String modelName,
    int tokenUsage = 0,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('goal_ai_analysis', <String, Object?>{
      'analysis_id': newId('todo_ai'),
      'goal_id': goalId,
      'source_task_id': sourceTaskId,
      'analysis_type': analysisType,
      'prompt_text': promptText,
      'result_json': resultJson,
      'model_name': modelName,
      'token_usage': tokenUsage,
      'created_at_ms': now,
    });
  }

  Future<void> addSyncLink({
    required String goalId,
    required String localStepId,
    required String todoListId,
    required String todoTaskId,
    String syncDirection = 'goal_to_todo',
  }) async {
    final db = await _db;
    await db.insert('goal_sync_links', <String, Object?>{
      'goal_id': goalId,
      'local_step_id': localStepId,
      'todo_list_id': todoListId,
      'todo_task_id': todoTaskId,
      'sync_direction': syncDirection,
      'last_sync_at_ms': DateTime.now().millisecondsSinceEpoch,
      'local_status': 'synced',
    });
  }


  Future<void> clearSolutionPlans(String goalId) async {
    final db = await _db;
    final rows = await db.query('goal_solution_plans', columns: ['solution_id'], where: 'goal_id = ?', whereArgs: [goalId]);
    final ids = rows.map((row) => (row['solution_id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
    await db.transaction((txn) async {
      if (ids.isNotEmpty) {
        await txn.delete('goal_problem_nodes', where: 'solution_id IN (${List.filled(ids.length, '?').join(',')})', whereArgs: ids);
      }
      await txn.delete('goal_solution_plans', where: 'goal_id = ?', whereArgs: [goalId]);
    });
  }

  Future<List<TodoFailureGrowthLoop>> listFailureGrowthLoops({int limit = 30}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT l.*, COALESCE(g.goal_title, '') AS goal_title
      FROM goal_failure_growth_loops l
      LEFT JOIN goal_profiles g ON g.goal_id = l.goal_id
      ORDER BY CASE WHEN l.status = 'completed' THEN 1 ELSE 0 END, l.created_at_ms DESC
      LIMIT ?
    ''', <Object?>[limit]);
    return rows.map(TodoFailureGrowthLoop.fromMap).toList();
  }

  Future<TodoFailureGrowthMetrics> failureGrowthMetrics() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS attempts,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS reflections,
        SUM(CASE WHEN TRIM(COALESCE(result_text, '')) != '' THEN 1 ELSE 0 END) AS feedback_samples,
        SUM(CASE WHEN TRIM(COALESCE(next_revision, '')) != '' THEN 1 ELSE 0 END) AS revisions,
        SUM(CASE WHEN status = 'completed' AND completed_at_ms - created_at_ms >= 86400000 THEN 1 ELSE 0 END) AS restarts,
        SUM(CASE WHEN status != 'completed' THEN 1 ELSE 0 END) AS active_experiments
      FROM goal_failure_growth_loops
    ''');
    final row = rows.isEmpty ? const <String, Object?>{} : rows.first;
    return TodoFailureGrowthMetrics(
      attempts: _toLocalInt(row['attempts']),
      reflections: _toLocalInt(row['reflections']),
      feedbackSamples: _toLocalInt(row['feedback_samples']),
      revisions: _toLocalInt(row['revisions']),
      restarts: _toLocalInt(row['restarts']),
      activeExperiments: _toLocalInt(row['active_experiments']),
    );
  }

  Future<String> saveFailureGrowthLoop({
    required String goalId,
    required String linkedStepId,
    required String eventText,
    required String emotionText,
    required String automaticThought,
    required String fearedOutcome,
    required TodoFailureGrowthDraft draft,
  }) async {
    final db = await _db;
    final id = newId('failure_growth_loop');
    await db.insert('goal_failure_growth_loops', <String, Object?>{
      'loop_id': id,
      'goal_id': goalId,
      'linked_step_id': linkedStepId,
      'event_text': eventText.trim(),
      'emotion_text': emotionText.trim(),
      'automatic_thought': automaticThought.trim(),
      'feared_outcome': fearedOutcome.trim(),
      'pattern_code': draft.patternCode,
      'pattern_label': draft.patternLabel,
      'fact_statement': draft.factStatement,
      'growth_reframe': draft.growthReframe,
      'learning_signal': draft.learningSignal,
      'recovery_plan': draft.recoveryPlan,
      'experiment_title': draft.experimentTitle,
      'minimum_standard': draft.minimumStandard,
      'reflection_question': draft.reflectionQuestion,
      'value_statement': draft.valueStatement,
      'result_text': '',
      'next_revision': '',
      'status': 'active',
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      'completed_at_ms': 0,
    });
    return id;
  }

  Future<void> completeFailureGrowthLoop({
    required TodoFailureGrowthLoop loop,
    required String resultText,
    required String nextRevision,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        'goal_failure_growth_loops',
        <String, Object?>{
          'result_text': resultText.trim(),
          'next_revision': nextRevision.trim(),
          'status': 'completed',
          'completed_at_ms': now,
        },
        where: 'loop_id = ?',
        whereArgs: <Object?>[loop.loopId],
      );
      if (loop.linkedStepId.trim().isNotEmpty) {
        await txn.update(
          'goal_action_steps',
          <String, Object?>{'status': 'completed', 'completed_at_ms': now, 'updated_at_ms': now},
          where: 'step_id = ?',
          whereArgs: <Object?>[loop.linkedStepId],
        );
      }
      await txn.insert('goal_reflections', <String, Object?>{
        'reflection_id': newId('failure_growth_reflection'),
        'goal_id': loop.goalId,
        'step_id': loop.linkedStepId,
        'reflection_date': todayDate(),
        'what_done': loop.experimentTitle,
        'why_done': loop.valueStatement,
        'process_experience': resultText.trim(),
        'obstacle': loop.patternLabel,
        'tomorrow_next_step': nextRevision.trim(),
        'ai_summary': '失败不是人格结论。本次已获得反馈，并把它转化为下一版行动。',
        'mood_score': 0,
        'meaning_score': 4,
        'process_score': 5,
        'created_at_ms': now,
      });
    });
  }

  Future<void> clearAllGoalModuleData() async {
    final db = await _db;
    await db.transaction((txn) async {
      final existingRows = await txn.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
      final existingTables = existingRows.map((row) => (row['name'] ?? '').toString()).toSet();
      for (final table in const <String>[
        'change_behavior_experiments',
        'change_abc_journals',
        'change_self_evidence',
        'change_action_cards',
        'goal_failure_growth_loops',
        'goal_effort_entries',
        'goal_rituals',
        'goal_step_reviews',
        'goal_problem_nodes',
        'goal_solution_plans',
        'goal_sync_links',
        'goal_ai_analysis',
        'goal_reflections',
        'goal_action_steps',
        'goal_profiles',
      ]) {
        if (existingTables.contains(table)) await txn.delete(table);
      }
    });
  }

  Future<void> saveSolutionPlansFromAnalysis({
    required String goalId,
    required String sourceTaskId,
    required List<TodoGoalSolutionPlan> plans,
  }) async {
    if (plans.isEmpty) return;
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < plans.length; i++) {
      final plan = plans[i];
      final solutionId = newId('todo_solution_${i + 1}');
      final planTitle = plan.title.trim().isEmpty ? 'AI问题解决方案' : plan.title.trim();
      final planValues = <String, Object?>{
        'solution_id': solutionId,
        'goal_id': goalId,
        'source_task_id': sourceTaskId,
        'title': planTitle,
        'method_name': plan.methodName,
        'method_basis': plan.methodBasis,
        'zone_type': _normalizeZone(plan.zoneType),
        'core_value_focus': plan.coreValueFocus,
        'summary': plan.summary,
        'risk_notes': plan.riskNotes,
        'problem_definition': plan.problemDefinition,
        'known_facts': plan.knownFacts,
        'key_assumptions': plan.keyAssumptions,
        'root_cause_analysis': plan.rootCauseAnalysis,
        'option_comparison': plan.optionComparison,
        'evidence_plan': plan.evidencePlan,
        'success_metrics': plan.successMetrics,
        'stop_conditions': plan.stopConditions,
        'user_choice_guidance': plan.userChoiceGuidance,
        'is_selected': 0,
        'status': 'candidate',
        'sort_order': plan.sortOrder == 0 ? i : plan.sortOrder,
        'raw_json': jsonEncode(plan.toJson()),
        'created_at_ms': now,
        'updated_at_ms': now,
      };
      await db.insert(
        'goal_solution_plans',
        await _compatibleInsertValues(
          db,
          'goal_solution_plans',
          planValues,
          aliases: const <String, String>{
            'plan_id': 'solution_id',
            'plan_title': 'title',
            'plan_name': 'title',
            'scientific_method': 'method_name',
            'method': 'method_name',
            'basis': 'method_basis',
            'value_focus': 'core_value_focus',
            'plan_summary': 'summary',
            'order_index': 'sort_order',
            'created_ms': 'created_at_ms',
            'updated_ms': 'updated_at_ms',
          },
        ),
      );
      await _insertProblemNodes(db: db, goalId: goalId, solutionId: solutionId, nodes: plan.nodes, now: now);
    }
  }

  Future<void> replaceSolutionPlanTree({
    required String goalId,
    required String sourceTaskId,
    required String solutionId,
    required TodoGoalSolutionPlan plan,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.delete('goal_problem_nodes', where: 'solution_id = ?', whereArgs: [solutionId]);
      final updated = await txn.update(
        'goal_solution_plans',
        <String, Object?>{
          'source_task_id': sourceTaskId,
          'title': plan.title,
          'method_name': plan.methodName,
          'method_basis': plan.methodBasis,
          'zone_type': _normalizeZone(plan.zoneType),
          'core_value_focus': plan.coreValueFocus,
          'summary': plan.summary,
          'risk_notes': plan.riskNotes,
          'problem_definition': plan.problemDefinition,
          'known_facts': plan.knownFacts,
          'key_assumptions': plan.keyAssumptions,
          'root_cause_analysis': plan.rootCauseAnalysis,
          'option_comparison': plan.optionComparison,
          'evidence_plan': plan.evidencePlan,
          'success_metrics': plan.successMetrics,
          'stop_conditions': plan.stopConditions,
          'user_choice_guidance': plan.userChoiceGuidance,
          'raw_json': jsonEncode(plan.toJson()),
          'updated_at_ms': now,
        },
        where: 'solution_id = ? AND goal_id = ?',
        whereArgs: [solutionId, goalId],
      );
      if (updated != 1) throw StateError('Solution plan not found: $solutionId');
      await _insertProblemNodes(db: txn, goalId: goalId, solutionId: solutionId, nodes: plan.nodes, now: now);
    });
  }

  Future<void> _insertProblemNodes({
    required DatabaseExecutor db,
    required String goalId,
    required String solutionId,
    required List<TodoGoalProblemNode> nodes,
    required int now,
  }) async {
    if (nodes.isEmpty) return;
    final tempToReal = <String, String>{};
    for (var i = 0; i < nodes.length; i++) {
      final tempId = nodes[i].tempNodeId.trim().isEmpty ? 'node_${i + 1}' : nodes[i].tempNodeId.trim();
      tempToReal[tempId] = newId('todo_node_${i + 1}');
    }
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final tempId = n.tempNodeId.trim().isEmpty ? 'node_${i + 1}' : n.tempNodeId.trim();
      final nodeId = tempToReal[tempId]!;
      final parent = n.tempParentNodeId.trim().isEmpty ? '' : (tempToReal[n.tempParentNodeId.trim()] ?? '');
      final dependencies = n.resolvedDependencyNodeIds.map((id) => tempToReal[id] ?? id).where((id) => id.isNotEmpty).toList(growable: false);
      final nodeValues = <String, Object?>{
        'node_id': nodeId,
        'goal_id': goalId,
        'solution_id': solutionId,
        'parent_node_id': parent,
        'relation_type': n.relationType.trim().isEmpty ? 'tree' : n.relationType.trim(),
        'node_type': n.nodeType.trim().isEmpty ? 'problem' : n.nodeType.trim(),
        'title': n.title.trim().isEmpty ? '子问题' : n.title.trim(),
        'description': n.description,
        'acceptance_criteria': n.acceptanceCriteria,
        'actionable_step': n.actionableStep,
        'action_when': n.actionWhen,
        'action_where': n.actionWhere,
        'action_object': n.actionObject,
        'action_procedure': n.actionProcedure,
        'action_output': n.actionOutput,
        'zone_type': _normalizeZone(n.zoneType),
        'difficulty_score': n.difficultyScore.clamp(1, 10).toInt(),
        'estimated_minutes': n.estimatedMinutes <= 0 ? 5 : n.estimatedMinutes,
        'sequence_order': n.sequenceOrder == 0 ? i : n.sequenceOrder,
        'dependencies_json': jsonEncode(dependencies),
        'logic_question': n.logicQuestion,
        'known_facts': n.knownFacts,
        'assumptions': n.assumptions,
        'evidence_needed': n.evidenceNeeded,
        'decision_rule': n.decisionRule,
        'status': 'not_started',
        'completion_note': '',
        'ai_review_json': '',
        'created_at_ms': now,
        'updated_at_ms': now,
      };
      await db.insert(
        'goal_problem_nodes',
        await _compatibleInsertValues(
          db,
          'goal_problem_nodes',
          nodeValues,
          aliases: const <String, String>{
            'problem_node_id': 'node_id',
            'node_title': 'title',
            'parent_id': 'parent_node_id',
            'order_index': 'sequence_order',
            'created_ms': 'created_at_ms',
            'updated_ms': 'updated_at_ms',
          },
        ),
      );
    }
  }

  String _normalizeZone(String value) {
    final v = value.trim().toLowerCase();
    if (v.contains('panic') || v.contains('恐慌')) return 'panic';
    if (v.contains('comfort') || v.contains('舒适')) return 'comfort';
    return 'stretch';
  }

  Future<List<TodoGoalSolutionPlan>> listSolutionPlans({required String goalId, bool includeArchived = true}) async {
    final db = await _db;
    final rows = await db.query(
      'goal_solution_plans',
      where: includeArchived ? 'goal_id = ?' : 'goal_id = ? AND status != ?',
      whereArgs: includeArchived ? [goalId] : [goalId, 'archived'],
      orderBy: 'is_selected DESC, sort_order ASC, created_at_ms ASC',
    );
    return rows.map(TodoGoalSolutionPlan.fromMap).toList();
  }

  Future<TodoGoalSolutionPlan?> getSelectedSolutionPlan(String goalId) async {
    final db = await _db;
    final rows = await db.query('goal_solution_plans', where: 'goal_id = ? AND is_selected = 1 AND status != ?', whereArgs: [goalId, 'archived'], orderBy: 'updated_at_ms DESC', limit: 1);
    if (rows.isEmpty) return null;
    return TodoGoalSolutionPlan.fromMap(rows.first);
  }

  Future<void> selectSolutionPlan({required String goalId, required String solutionId}) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update('goal_solution_plans', <String, Object?>{'is_selected': 0, 'status': 'candidate', 'updated_at_ms': now}, where: 'goal_id = ? AND status != ?', whereArgs: [goalId, 'archived']);
    await db.update('goal_solution_plans', <String, Object?>{'is_selected': 1, 'status': 'selected', 'updated_at_ms': now}, where: 'solution_id = ? AND goal_id = ?', whereArgs: [solutionId, goalId]);
  }

  Future<List<TodoGoalProblemNode>> listProblemNodes({required String solutionId}) async {
    final db = await _db;
    final rows = await db.query(
      'goal_problem_nodes',
      where: 'solution_id = ?',
      whereArgs: [solutionId],
      orderBy: "COALESCE(parent_node_id, '') ASC, sequence_order ASC, created_at_ms ASC",
    );
    return rows.map(TodoGoalProblemNode.fromMap).toList();
  }

  Future<List<TodoGoalProblemNode>> listSelectedProblemNodes(String goalId) async {
    final selected = await getSelectedSolutionPlan(goalId);
    if (selected == null) return <TodoGoalProblemNode>[];
    return listProblemNodes(solutionId: selected.solutionId);
  }

  Future<void> updateProblemNodeStatus(String nodeId, String status, {String completionNote = '', String aiReviewJson = ''}) async {
    final db = await _db;
    final normalized = status.trim().isEmpty ? 'not_started' : status.trim();
    await db.update(
      'goal_problem_nodes',
      <String, Object?>{
        'status': normalized,
        'completion_note': completionNote,
        if (aiReviewJson.trim().isNotEmpty) 'ai_review_json': aiReviewJson,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'node_id = ?',
      whereArgs: [nodeId],
    );
  }

  Future<String> addAlternativeProblemNode({
    required TodoGoalProblemNode original,
    required TodoGoalAlternativeStep alternative,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxRows = await db.rawQuery(
      'SELECT COALESCE(MAX(sequence_order), 0) AS max_order FROM goal_problem_nodes WHERE solution_id = ?',
      <Object?>[original.solutionId],
    );
    final maxOrder = maxRows.isEmpty ? 0 : _toLocalInt(maxRows.first['max_order']);
    final nodeId = newId('todo_node_alternative');
    await db.update(
      'goal_problem_nodes',
      <String, Object?>{'relation_type': 'or', 'updated_at_ms': now},
      where: 'node_id = ?',
      whereArgs: <Object?>[original.nodeId],
    );
    await db.insert('goal_problem_nodes', <String, Object?>{
      'node_id': nodeId,
      'goal_id': original.goalId,
      'solution_id': original.solutionId,
      'parent_node_id': original.nodeId,
      'relation_type': 'or',
      'node_type': 'action',
      'title': alternative.title,
      'description': alternative.rationale,
      'acceptance_criteria': alternative.minimumStandard,
      'actionable_step': alternative.title,
      'action_when': alternative.actionWhen,
      'action_where': alternative.actionWhere,
      'action_object': alternative.actionObject,
      'action_procedure': alternative.actionProcedure,
      'action_output': alternative.actionOutput,
      'zone_type': _normalizeZone(alternative.zoneType),
      'difficulty_score': alternative.difficultyScore.clamp(1, 10).toInt(),
      'estimated_minutes': 5,
      'sequence_order': maxOrder + 1,
      'dependencies_json': original.dependenciesJson,
      'logic_question': '这个替代动作能否在不改变父问题的前提下，绕过刚才的具体阻力？',
      'known_facts': '原步骤未达到验收标准，用户已经记录了具体结果。',
      'assumptions': alternative.rationale,
      'evidence_needed': '是否开始、实际产出、是否绕过原阻力，以及对父问题的推进证据。',
      'decision_rule': '达到最低标准则保留为当前路径；仍失败则尝试其他备用步骤或切换备用方案，暂不重构全方案。',
      'status': 'in_progress',
      'completion_note': '从失败复盘中选出的替代步骤',
      'ai_review_json': '',
      'created_at_ms': now,
      'updated_at_ms': now,
    });
    return nodeId;
  }

  Future<String> createStepFromProblemNode(TodoGoalProblemNode node, {String sourceTaskId = ''}) async {
    return createActionStep(
      goalId: node.goalId,
      sourceTaskId: sourceTaskId,
      title: node.displayAction,
      minimumStandard: node.acceptanceCriteria.trim().isEmpty ? '完成明确产出并可现场核对。' : node.acceptanceCriteria,
      simplifiedStandard: node.actionOutput.trim().isEmpty ? node.acceptanceCriteria : '至少留下：${node.actionOutput}',
      recommendedStandard: node.concreteActionText,
      stretchStandard: '状态允许时再多推进一个相邻子节点，不强行进入恐慌区。',
      difficultyScore: node.difficultyScore,
      zoneType: node.zoneType,
      plannedDate: todayDate(),
      actionPlace: node.actionWhere,
      startTrigger: node.actionWhen,
      completionQuestion: '是否已经得到“${node.actionOutput}”，并达到“${node.acceptanceCriteria}”？',
      sortOrder: node.sequenceOrder,
    );
  }

  Future<String> addStepReview({
    required String goalId,
    required String stepId,
    String nodeId = '',
    required String userResult,
    required String userText,
    required TodoGoalStepRecoveryResult recovery,
    String selectedAlternativeJson = '',
    String restructuredPlanId = '',
  }) async {
    final db = await _db;
    final id = newId('todo_step_review');
    await db.insert('goal_step_reviews', <String, Object?>{
      'review_id': id,
      'goal_id': goalId,
      'step_id': stepId,
      'node_id': nodeId,
      'user_result': userResult,
      'user_text': userText,
      'ai_analysis': recovery.failureDiagnosis,
      'restart_guidance': recovery.restartGuidance,
      'alternative_steps_json': jsonEncode(recovery.alternatives.map((e) => e.toJson()).toList()),
      'selected_alternative_json': selectedAlternativeJson,
      'restructured_plan_id': restructuredPlanId,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  Future<List<TodoGoalRitual>> listRituals({String? goalId}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT r.*, COALESCE(g.goal_title, '') AS goal_title
      FROM goal_rituals r
      LEFT JOIN goal_profiles g ON g.goal_id = r.goal_id
      WHERE r.status != 'archived' ${goalId == null ? '' : 'AND r.goal_id = ?'}
      ORDER BY r.updated_at_ms DESC
    ''', goalId == null ? const <Object?>[] : <Object?>[goalId]);
    return rows.map(TodoGoalRitual.fromMap).toList();
  }

  Future<String> saveRitual({
    required String goalId,
    required String triggerText,
    required String minimumAction,
    required int minimumMinutes,
    required String rewardOrRecord,
    required String environmentDesign,
    required String frictionPlan,
    String? ritualId,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = ritualId?.trim().isNotEmpty == true ? ritualId!.trim() : newId('goal_ritual');
    await db.insert('goal_rituals', <String, Object?>{
      'ritual_id': id,
      'goal_id': goalId,
      'trigger_text': triggerText.trim(),
      'minimum_action': minimumAction.trim(),
      'minimum_minutes': minimumMinutes.clamp(1, 120),
      'reward_or_record': rewardOrRecord.trim(),
      'environment_design': environmentDesign.trim(),
      'friction_plan': frictionPlan.trim(),
      'stability_score': 0,
      'status': 'active',
      'created_at_ms': now,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<String> addEffortEntry({
    required String goalId,
    String stepId = '',
    required int effortMinutes,
    required String energyLevel,
    required String emotionState,
    required int availableMinutes,
    required String zoneType,
    required String effortType,
    required String investmentText,
    required String obstacle,
    required String strategyUsed,
    required String smallProgress,
    required String nextMinimumStep,
    required String timeInLearning,
    required String identityEvidence,
    required String gratitudeText,
    required int joyScore,
    required int reflectionDepth,
    required bool strategyChanged,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final recent = await db.query('goal_effort_entries', columns: ['created_at_ms'], where: 'goal_id = ?', whereArgs: [goalId], orderBy: 'created_at_ms DESC', limit: 1);
    final lastAt = recent.isEmpty ? 0 : _toLocalInt(recent.first['created_at_ms']);
    final returned = lastAt > 0 && now - lastAt >= const Duration(hours: 24).inMilliseconds;
    final id = newId('goal_effort');
    await db.insert('goal_effort_entries', <String, Object?>{
      'entry_id': id,
      'goal_id': goalId,
      'step_id': stepId,
      'effort_date': todayDate(),
      'effort_minutes': effortMinutes.clamp(0, 1440),
      'energy_level': energyLevel,
      'emotion_state': emotionState,
      'available_minutes': availableMinutes.clamp(1, 1440),
      'zone_type': _normalizeZone(zoneType),
      'effort_type': effortType,
      'investment_text': investmentText.trim(),
      'obstacle': obstacle.trim(),
      'strategy_used': strategyUsed.trim(),
      'small_progress': smallProgress.trim(),
      'next_minimum_step': nextMinimumStep.trim(),
      'time_in_learning': timeInLearning.trim(),
      'identity_evidence': identityEvidence.trim(),
      'gratitude_text': gratitudeText.trim(),
      'joy_score': joyScore.clamp(0, 5),
      'reflection_depth': reflectionDepth.clamp(0, 5),
      'strategy_changed': strategyChanged ? 1 : 0,
      'returned_after_break': returned ? 1 : 0,
      'created_at_ms': now,
    });
    return id;
  }

  Future<List<TodoGoalEffortEntry>> listEffortEntries({int days = 7, int limit = 100}) async {
    final db = await _db;
    final since = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final rows = await db.rawQuery('''
      SELECT e.*, COALESCE(g.goal_title, '') AS goal_title
      FROM goal_effort_entries e
      LEFT JOIN goal_profiles g ON g.goal_id = e.goal_id
      WHERE e.created_at_ms >= ?
      ORDER BY e.created_at_ms DESC
      LIMIT ?
    ''', [since, limit]);
    return rows.map(TodoGoalEffortEntry.fromMap).toList();
  }

  Future<TodoGoalEffortSummary> getEffortSummary({int days = 7}) async {
    final entries = await listEffortEntries(days: days, limit: 500);
    final obstacleCounts = <String, int>{};
    for (final entry in entries) {
      final obstacle = entry.obstacle.trim();
      if (obstacle.isNotEmpty) obstacleCounts[obstacle] = (obstacleCounts[obstacle] ?? 0) + 1;
    }
    var commonObstacle = '';
    var maxCount = 0;
    for (final item in obstacleCounts.entries) {
      if (item.value > maxCount) {
        commonObstacle = item.key;
        maxCount = item.value;
      }
    }
    final joyTotal = entries.fold<int>(0, (sum, item) => sum + item.joyScore);
    return TodoGoalEffortSummary(
      meaningfulEfforts: entries.length,
      effortMinutes: entries.fold<int>(0, (sum, item) => sum + item.effortMinutes),
      returnCount: entries.where((item) => item.returnedAfterBreak).length,
      stretchCount: entries.where((item) => item.zoneType == 'stretch').length,
      reflectionCount: entries.where((item) => item.timeInLearning.trim().isNotEmpty).length,
      strategyChangeCount: entries.where((item) => item.strategyChanged).length,
      relationshipInvestmentCount: entries.where((item) => item.effortType == 'relationship').length,
      averageJoy: entries.isEmpty ? 0 : joyTotal / entries.length,
      commonObstacle: commonObstacle,
    );
  }
}
