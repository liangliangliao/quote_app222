import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'cognitive_consistency_models.dart';

class CognitiveConsistencyDao {
  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db);
    return db;
  }


  Future<String?> getString(String key) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('notify_config', where: 'key = ?', whereArgs: <Object?>[key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value']?.toString();
  }

  Future<void> setString(String key, String value) async {
    final db = await AppDatabase.instance();
    await db.insert(
      'notify_config',
      <String, Object?>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, String>>> keyValuesWithPrefix(String prefix) async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'notify_config',
      where: 'key LIKE ?',
      whereArgs: <Object?>['$prefix%'],
      orderBy: 'key DESC',
    );
    return rows.map((r) => <String, String>{
      'key': (r['key'] ?? '').toString(),
      'value': (r['value'] ?? '').toString(),
    }).toList(growable: false);
  }

  Future<void> ensureTables([Database? database]) async {
    final db = database ?? await AppDatabase.instance();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_sessions (
        session_id TEXT PRIMARY KEY,
        scene_type TEXT NOT NULL,
        user_goal TEXT,
        user_context TEXT,
        user_values TEXT,
        result_json TEXT,
        provider TEXT,
        model_label TEXT,
        status TEXT DEFAULT 'draft',
        source_type TEXT,
        source_id TEXT,
        reward_source TEXT,
        origin_scene TEXT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_evidence_records (
        evidence_id TEXT PRIMARY KEY,
        session_id TEXT,
        user_goal TEXT,
        planned_action TEXT,
        completed_action TEXT,
        user_reflection TEXT,
        evidence_label TEXT,
        value_link TEXT,
        old_story TEXT,
        new_story TEXT,
        evidence_category TEXT DEFAULT 'start',
        identity_direction TEXT,
        reward_source TEXT,
        source_type TEXT,
        source_id TEXT,
        effort_minutes INTEGER DEFAULT 0,
        difficulty_score INTEGER DEFAULT 0,
        started_at_ms INTEGER DEFAULT 0,
        ended_at_ms INTEGER DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_value_profiles (
        value_id TEXT PRIMARY KEY,
        value_label TEXT NOT NULL,
        why TEXT,
        identity_direction TEXT,
        example_action TEXT,
        priority INTEGER DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_reports (
        report_id TEXT PRIMARY KEY,
        period_label TEXT,
        user_values TEXT,
        report_text TEXT,
        suggested_action TEXT,
        adopted_evidence_id TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_evidence_value_links (
        evidence_id TEXT NOT NULL,
        value_id TEXT NOT NULL,
        value_label TEXT,
        relation_type TEXT DEFAULT 'selected',
        created_at_ms INTEGER NOT NULL,
        PRIMARY KEY (evidence_id, value_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_source_value_links (
        source_type TEXT NOT NULL,
        source_id TEXT NOT NULL,
        value_id TEXT NOT NULL,
        value_label TEXT,
        relation_type TEXT DEFAULT 'selected',
        created_at_ms INTEGER NOT NULL,
        PRIMARY KEY (source_type, source_id, value_id)
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_report_action_links (
        link_id TEXT PRIMARY KEY,
        report_id TEXT NOT NULL,
        session_id TEXT,
        todo_step_id TEXT,
        evidence_id TEXT,
        status TEXT DEFAULT 'suggested',
        suggested_action TEXT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_value_relation_insights (
        insight_id TEXT PRIMARY KEY,
        selected_value_ids TEXT,
        selected_value_labels TEXT,
        user_goal TEXT,
        user_context TEXT,
        insight_text TEXT,
        linked_session_id TEXT,
        linked_evidence_id TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_effective_patterns (
        pattern_id TEXT PRIMARY KEY,
        evidence_id TEXT NOT NULL,
        value_labels TEXT,
        old_story TEXT,
        new_story TEXT,
        action_template TEXT,
        success_reason TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_action_trace_links (
        link_id TEXT PRIMARY KEY,
        from_type TEXT NOT NULL,
        from_id TEXT NOT NULL,
        to_type TEXT NOT NULL,
        to_id TEXT NOT NULL,
        relation_type TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_trigger_suggestions (
        suggestion_id TEXT PRIMARY KEY,
        source_type TEXT NOT NULL,
        source_id TEXT NOT NULL,
        trigger_type TEXT,
        message TEXT,
        recommended_tab TEXT,
        severity INTEGER DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_dissonance_resolution_method_usages (
        usage_id TEXT PRIMARY KEY,
        method_id TEXT NOT NULL,
        method_title TEXT,
        session_id TEXT,
        case_id TEXT,
        source_type TEXT,
        source_id TEXT,
        selected_reason TEXT,
        entered_scene_key TEXT,
        todo_step_id TEXT,
        evidence_id TEXT,
        contract_id TEXT,
        method_workflow_id TEXT,
        dissonance_type TEXT,
        sourcebook_support_level TEXT,
        status TEXT DEFAULT 'selected',
        review_text TEXT,
        effect_score INTEGER DEFAULT 0,
        reduced_dissonance INTEGER DEFAULT 0,
        produced_evidence INTEGER DEFAULT 0,
        risk_note TEXT,
        next_use_suggestion TEXT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_dissonance_events (
        session_id TEXT PRIMARY KEY,
        event_summary TEXT,
        believed_value TEXT,
        actual_behavior TEXT,
        self_explanation TEXT,
        dissonance_point TEXT,
        core_conflict TEXT,
        source_type TEXT,
        source_id TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_trigger_conditions (
        session_id TEXT PRIMARY KEY,
        freedom_of_choice TEXT,
        negative_consequence TEXT,
        foreseeability TEXT,
        responsibility_feeling TEXT,
        repairability TEXT,
        not_user_responsibility TEXT,
        user_responsibility TEXT,
        over_blame_risk TEXT,
        avoidance_risk TEXT,
        repairable_part TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_self_standards (
        session_id TEXT PRIMARY KEY,
        personal_standard TEXT,
        normative_standard TEXT,
        family_or_group_standard TEXT,
        ideal_self_standard TEXT,
        adjusted_standard TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_rationalization_flags (
        session_id TEXT PRIMARY KEY,
        rationalization_types TEXT,
        protective_function TEXT,
        long_term_cost TEXT,
        honest_reframe TEXT,
        protective_explanation TEXT,
        avoidance_explanation TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_true_self_links (
        link_id TEXT PRIMARY KEY,
        cc_session_id TEXT,
        cc_evidence_id TEXT,
        shame_event_id TEXT,
        shame_evidence_id TEXT,
        link_type TEXT,
        true_pride_sentence TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_special_scene_details (
        session_id TEXT PRIMARY KEY,
        scene_type TEXT,
        choice_paths TEXT,
        sunk_cost_check TEXT,
        hypocrisy_induction TEXT,
        group_conflict TEXT,
        vicarious_dissonance TEXT,
        todo_write_back_insight TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_special_scene_items (
        item_id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        scene_type TEXT,
        section_name TEXT NOT NULL,
        item_key TEXT,
        item_value TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_rationalization_flag_items (
        flag_id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        flag_type TEXT NOT NULL,
        evidence_sentence TEXT,
        protective_function TEXT,
        long_term_cost TEXT,
        repair_action TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_self_standard_items (
        item_id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        standard_type TEXT NOT NULL,
        standard_source TEXT,
        standard_text TEXT,
        is_rigid INTEGER DEFAULT 0,
        adjusted_standard TEXT,
        linked_action TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_verification_tasks (
        task_id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        scene_type TEXT,
        question TEXT,
        success_signal TEXT,
        due_at_ms INTEGER DEFAULT 0,
        status TEXT DEFAULT 'open',
        result_note TEXT,
        created_at_ms INTEGER NOT NULL,
        verified_at_ms INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_dissonance_type_items (
        item_id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        type_key TEXT,
        type_label TEXT,
        confidence REAL DEFAULT 0,
        evidence_sentence TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_dissonance_intensity_scores (
        session_id TEXT PRIMARY KEY,
        freedom_score INTEGER DEFAULT 0,
        consequence_score INTEGER DEFAULT 0,
        value_score INTEGER DEFAULT 0,
        self_image_score INTEGER DEFAULT 0,
        public_commitment_score INTEGER DEFAULT 0,
        investment_score INTEGER DEFAULT 0,
        information_avoidance_score INTEGER DEFAULT 0,
        emotion_score INTEGER DEFAULT 0,
        total_score INTEGER DEFAULT 0,
        level TEXT,
        main_sources TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_consistency_reframe_items (
        session_id TEXT PRIMARY KEY,
        defensive_explanation TEXT,
        short_term_protection TEXT,
        long_term_cost TEXT,
        growth_explanation TEXT,
        responsible_part TEXT,
        next_repair_action TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_self_integrity_cards (
        session_id TEXT PRIMARY KEY,
        acknowledge_sentence TEXT,
        not_equal_sentence TEXT,
        still_value_sentence TEXT,
        next_proof_action TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_dissonance_temperature_logs (
        log_id TEXT PRIMARY KEY,
        session_id TEXT,
        evidence_id TEXT,
        phase TEXT,
        discomfort_score INTEGER DEFAULT 0,
        guilt_score INTEGER DEFAULT 0,
        anxiety_score INTEGER DEFAULT 0,
        shame_score INTEGER DEFAULT 0,
        defensiveness_score INTEGER DEFAULT 0,
        avoidance_urge_score INTEGER DEFAULT 0,
        clarity_score INTEGER DEFAULT 0,
        responsibility_score INTEGER DEFAULT 0,
        action_willingness_score INTEGER DEFAULT 0,
        note TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_daily_consistency_reviews (
        review_id TEXT PRIMARY KEY,
        date_label TEXT,
        closest_value_action TEXT,
        main_dissonance TEXT,
        rationalization_used TEXT,
        growth_reframe TEXT,
        repair_action_done TEXT,
        tomorrow_action TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_temperature_review_items (
        review_id TEXT PRIMARY KEY,
        session_id TEXT,
        evidence_id TEXT,
        review_text TEXT,
        repair_mode TEXT,
        next_cooling_action TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_information_contact_results (
        result_id TEXT PRIMARY KEY,
        session_id TEXT,
        evidence_id TEXT,
        avoided_information TEXT,
        feared_result TEXT,
        actual_result TEXT,
        result_type TEXT,
        catastrophizing_check TEXT,
        repair_action TEXT,
        source_type TEXT,
        source_id TEXT,
        origin_scene TEXT,
        discomfort_before INTEGER DEFAULT 0,
        discomfort_after INTEGER DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_identity_transition_records (
        transition_id TEXT PRIMARY KEY,
        session_id TEXT,
        evidence_id TEXT,
        old_identity TEXT,
        new_identity TEXT,
        old_protection TEXT,
        fear_of_loss TEXT,
        new_identity_action TEXT,
        post_action_identity_sentence TEXT,
        next_identity_action TEXT,
        source_type TEXT,
        source_id TEXT,
        origin_scene TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_protected_self_images (
        image_id TEXT PRIMARY KEY,
        session_id TEXT,
        case_id TEXT,
        image TEXT,
        evidence TEXT,
        confidence TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_defense_pattern_records (
        pattern_id TEXT PRIMARY KEY,
        session_id TEXT,
        case_id TEXT,
        pattern_type TEXT,
        description TEXT,
        possible_cost TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_sourcebook_cases (
        case_id TEXT PRIMARY KEY,
        session_id TEXT UNIQUE,
        scene_type TEXT,
        event_summary TEXT,
        current_stage TEXT,
        user_confirmation TEXT,
        integrated_self_statement TEXT,
        source_type TEXT,
        source_id TEXT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_cognition_nodes (
        node_id TEXT PRIMARY KEY,
        case_id TEXT,
        session_id TEXT,
        node_type TEXT,
        label TEXT,
        content TEXT,
        importance TEXT,
        confidence REAL DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_conflict_edges (
        edge_id TEXT PRIMARY KEY,
        case_id TEXT,
        session_id TEXT,
        from_label TEXT,
        to_label TEXT,
        relation_type TEXT,
        description TEXT,
        strength REAL DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_user_confirmations (
        confirmation_id TEXT PRIMARY KEY,
        session_id TEXT,
        case_id TEXT,
        confirmation_level TEXT,
        note TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_value_layer_records (
        record_id TEXT PRIMARY KEY,
        session_id TEXT,
        case_id TEXT,
        core_values TEXT,
        identity_beliefs TEXT,
        peripheral_explanations TEXT,
        keep_items TEXT,
        loosen_items TEXT,
        test_items TEXT,
        integrated_statement TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_user_choice_records (
        choice_id TEXT PRIMARY KEY,
        session_id TEXT,
        case_id TEXT,
        label TEXT,
        description TEXT,
        next_action TEXT,
        selected INTEGER DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_interpersonal_balance_records (
        record_id TEXT PRIMARY KEY,
        session_id TEXT,
        case_id TEXT,
        my_attitude_to_person TEXT,
        object_or_issue TEXT,
        my_attitude_to_object TEXT,
        other_attitude_to_object TEXT,
        imbalance_point TEXT,
        possible_balance_paths TEXT,
        boundary_action TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_counter_attitudinal_experiments (
        experiment_id TEXT PRIMARY KEY,
        session_id TEXT,
        case_id TEXT,
        old_belief TEXT,
        protective_function TEXT,
        limitation TEXT,
        experiment_action TEXT,
        duration_minutes INTEGER DEFAULT 0,
        completion_standard TEXT,
        observation_question TEXT,
        updated_belief TEXT,
        completed_result TEXT,
        belief_shift_score INTEGER DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cc_commitment_action_contracts (
        contract_id TEXT PRIMARY KEY,
        session_id TEXT,
        case_id TEXT,
        core_value TEXT,
        current_inconsistent_behavior TEXT,
        minimal_repair_action TEXT,
        action_time TEXT,
        action_place TEXT,
        duration_minutes INTEGER DEFAULT 0,
        completion_standard TEXT,
        obstacle TEXT,
        fallback_plan TEXT,
        reflection_questions TEXT,
        status TEXT DEFAULT 'draft',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');

    await _ensureColumn(db, 'cc_evidence_records', 'evidence_category', "TEXT DEFAULT 'start'");
    await _ensureColumn(db, 'cc_evidence_records', 'identity_direction', 'TEXT');
    await _ensureColumn(db, 'cc_evidence_records', 'reward_source', 'TEXT');
    await _ensureColumn(db, 'cc_evidence_records', 'source_type', 'TEXT');
    await _ensureColumn(db, 'cc_evidence_records', 'source_id', 'TEXT');
    await _ensureColumn(db, 'cc_evidence_records', 'started_at_ms', 'INTEGER DEFAULT 0');
    await _ensureColumn(db, 'cc_evidence_records', 'ended_at_ms', 'INTEGER DEFAULT 0');
    await _ensureColumn(db, 'cc_sessions', 'source_type', 'TEXT');
    await _ensureColumn(db, 'cc_sessions', 'source_id', 'TEXT');
    await _ensureColumn(db, 'cc_sessions', 'reward_source', 'TEXT');
    await _ensureColumn(db, 'cc_sessions', 'origin_scene', 'TEXT');
    await _ensureColumn(db, 'cc_information_contact_results', 'source_type', 'TEXT');
    await _ensureColumn(db, 'cc_information_contact_results', 'source_id', 'TEXT');
    await _ensureColumn(db, 'cc_information_contact_results', 'origin_scene', 'TEXT');
    await _ensureColumn(db, 'cc_identity_transition_records', 'source_type', 'TEXT');
    await _ensureColumn(db, 'cc_identity_transition_records', 'source_id', 'TEXT');
    await _ensureColumn(db, 'cc_identity_transition_records', 'origin_scene', 'TEXT');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_temp_review_evidence ON cc_temperature_review_items(evidence_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_temp_review_created ON cc_temperature_review_items(created_at_ms)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_info_result_evidence ON cc_information_contact_results(evidence_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_info_result_session ON cc_information_contact_results(session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_info_result_created ON cc_information_contact_results(created_at_ms)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_identity_transition_evidence ON cc_identity_transition_records(evidence_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_identity_transition_session ON cc_identity_transition_records(session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_identity_transition_created ON cc_identity_transition_records(created_at_ms)');
    await _ensureColumn(db, 'cc_cognition_nodes', 'sort_order', 'INTEGER DEFAULT 0');
    await _ensureColumn(db, 'cc_conflict_edges', 'sort_order', 'INTEGER DEFAULT 0');
    await _ensureColumn(db, 'cc_trigger_suggestions', 'status', "TEXT DEFAULT 'active'");
    await _ensureColumn(db, 'cc_trigger_suggestions', 'updated_at_ms', 'INTEGER DEFAULT 0');
    await _ensureColumn(db, 'cc_dissonance_resolution_method_usages', 'status', "TEXT DEFAULT 'selected'");
    await _ensureColumn(db, 'cc_dissonance_resolution_method_usages', 'todo_step_id', 'TEXT');
    await _ensureColumn(db, 'cc_dissonance_resolution_method_usages', 'evidence_id', 'TEXT');
    await _ensureColumn(db, 'cc_dissonance_resolution_method_usages', 'contract_id', 'TEXT');
    await _ensureColumn(db, 'cc_dissonance_resolution_method_usages', 'method_workflow_id', 'TEXT');
    await _ensureColumn(db, 'cc_dissonance_resolution_method_usages', 'dissonance_type', 'TEXT');
    await _ensureColumn(db, 'cc_dissonance_resolution_method_usages', 'sourcebook_support_level', 'TEXT');
    await _ensureColumn(db, 'cc_dissonance_resolution_method_usages', 'review_text', 'TEXT');
    await _ensureColumn(db, 'cc_dissonance_resolution_method_usages', 'effect_score', 'INTEGER DEFAULT 0');
    await _ensureColumn(db, 'cc_dissonance_resolution_method_usages', 'reduced_dissonance', 'INTEGER DEFAULT 0');
    await _ensureColumn(db, 'cc_dissonance_resolution_method_usages', 'produced_evidence', 'INTEGER DEFAULT 0');
    await _ensureColumn(db, 'cc_dissonance_resolution_method_usages', 'risk_note', 'TEXT');
    await _ensureColumn(db, 'cc_dissonance_resolution_method_usages', 'next_use_suggestion', 'TEXT');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_resolution_usage_method ON cc_dissonance_resolution_method_usages(method_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_resolution_usage_session ON cc_dissonance_resolution_method_usages(session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_resolution_usage_status ON cc_dissonance_resolution_method_usages(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_resolution_usage_workflow ON cc_dissonance_resolution_method_usages(method_workflow_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_resolution_usage_contract ON cc_dissonance_resolution_method_usages(contract_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_resolution_usage_dissonance ON cc_dissonance_resolution_method_usages(dissonance_type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_protected_self_session ON cc_protected_self_images(session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_defense_patterns_session ON cc_defense_pattern_records(session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_sourcebook_case_session ON cc_sourcebook_cases(session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_nodes_session ON cc_cognition_nodes(session_id)');
    await _ensureColumn(db, 'cc_conflict_edges', 'from_node_id', 'TEXT');
    await _ensureColumn(db, 'cc_conflict_edges', 'to_node_id', 'TEXT');
    await _ensureColumn(db, 'cc_cognition_nodes', 'user_status', "TEXT DEFAULT 'ai_generated'");
    await _ensureColumn(db, 'cc_cognition_nodes', 'user_note', 'TEXT');
    await _ensureColumn(db, 'cc_conflict_edges', 'user_status', "TEXT DEFAULT 'ai_generated'");
    await _ensureColumn(db, 'cc_conflict_edges', 'user_note', 'TEXT');
    await _ensureColumn(db, 'cc_user_choice_records', 'selected_at_ms', 'INTEGER DEFAULT 0');
    await _ensureColumn(db, 'cc_interpersonal_balance_records', 'action_status', "TEXT DEFAULT 'suggested'");
    await _ensureColumn(db, 'cc_interpersonal_balance_records', 'action_result', 'TEXT');
    await _ensureColumn(db, 'cc_interpersonal_balance_records', 'updated_at_ms', 'INTEGER DEFAULT 0');
    await _ensureColumn(db, 'cc_counter_attitudinal_experiments', 'updated_at_ms', 'INTEGER DEFAULT 0');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_edges_session ON cc_conflict_edges(session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_edges_from_node ON cc_conflict_edges(from_node_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_edges_to_node ON cc_conflict_edges(to_node_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_value_layers_session ON cc_value_layer_records(session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_choices_session ON cc_user_choice_records(session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_daily_review_date ON cc_daily_consistency_reviews(date_label)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_temp_logs_evidence_phase ON cc_dissonance_temperature_logs(evidence_id, phase)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_temp_logs_session_pending ON cc_dissonance_temperature_logs(session_id, phase, evidence_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cc_verification_session_status ON cc_verification_tasks(session_id, status)');
    await _ensureColumn(db, 'cc_reports', 'suggested_action', 'TEXT');
    await _ensureColumn(db, 'cc_reports', 'adopted_evidence_id', 'TEXT');
    await _ensureColumn(db, 'cc_report_action_links', 'suggested_action', 'TEXT');
    await _ensureColumn(db, 'cc_report_action_links', 'session_id', 'TEXT');
    await _ensureColumn(db, 'cc_report_action_links', 'todo_step_id', 'TEXT');
    await _ensureColumn(db, 'cc_report_action_links', 'evidence_id', 'TEXT');
    await _ensureColumn(db, 'cc_report_action_links', 'status', "TEXT DEFAULT 'suggested'");
    await _ensureColumn(db, 'cc_special_scene_details', 'scene_type', 'TEXT');
    await _ensureColumn(db, 'cc_special_scene_details', 'choice_paths', 'TEXT');
    await _ensureColumn(db, 'cc_special_scene_details', 'sunk_cost_check', 'TEXT');
    await _ensureColumn(db, 'cc_special_scene_details', 'hypocrisy_induction', 'TEXT');
    await _ensureColumn(db, 'cc_special_scene_details', 'group_conflict', 'TEXT');
    await _ensureColumn(db, 'cc_special_scene_details', 'vicarious_dissonance', 'TEXT');
    await _ensureColumn(db, 'cc_special_scene_details', 'todo_write_back_insight', 'TEXT');
    await _ensureColumn(db, 'cc_special_scene_details', 'verification_question', 'TEXT');
    await _ensureColumn(db, 'cc_special_scene_details', 'verification_success_signal', 'TEXT');
    await _ensureColumn(db, 'cc_special_scene_details', 'verification_due_days', 'INTEGER DEFAULT 3');
    await _ensureColumn(db, 'cc_dissonance_events', 'dissonance_reduction_mode', 'TEXT');
    await _ensureColumn(db, 'cc_evidence_records', 'dissonance_reduction_mode', "TEXT DEFAULT 'explanation_only'");
    await _ensureColumn(db, 'cc_dissonance_temperature_logs', 'note', 'TEXT');
  }

  Future<void> _ensureColumn(Database db, String table, String column, String typeSql) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      final cols = info.map((e) => (e['name'] ?? '').toString()).toSet();
      if (!cols.contains(column)) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $typeSql');
      }
    } catch (_) {
      // Avoid breaking app startup on old or partially migrated local schemas.
    }
  }

  Future<String> saveSession({
    required String sceneType,
    required String userGoal,
    required String userContext,
    required String userValues,
    required CcPlanResult result,
    String sourceType = '',
    String sourceId = '',
    String rewardSource = '',
    String originScene = '',
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final sessionId = result.sessionId.trim().isNotEmpty ? result.sessionId.trim() : 'cc_${now}_${sceneType.hashCode.abs()}_${userGoal.hashCode.abs()}';
    final storedResult = result.copyWith(sessionId: sessionId);
    await db.insert(
      'cc_sessions',
      <String, Object?>{
        'session_id': sessionId,
        'scene_type': sceneType,
        'user_goal': userGoal,
        'user_context': userContext,
        'user_values': userValues,
        'result_json': jsonEncode(storedResult.toJson()),
        'provider': storedResult.provider,
        'model_label': storedResult.modelLabel,
        'status': 'generated',
        'source_type': sourceType,
        'source_id': sourceId,
        'reward_source': rewardSource,
        'origin_scene': originScene.trim().isEmpty ? sceneType : originScene,
        'created_at_ms': now,
        'updated_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _saveModernDissonanceDetails(
      db: db,
      sessionId: sessionId,
      result: storedResult,
      sourceType: sourceType,
      sourceId: sourceId,
      createdAtMs: now,
      sceneType: sceneType,
    );
    return sessionId;
  }

  Future<void> _saveModernDissonanceDetails({
    required Database db,
    required String sessionId,
    required CcPlanResult result,
    required String sourceType,
    required String sourceId,
    required int createdAtMs,
    String sceneType = '',
  }) async {
    await db.insert(
      'cc_dissonance_events',
      <String, Object?>{
        'session_id': sessionId,
        'event_summary': result.eventSummary,
        'believed_value': result.believedValue,
        'actual_behavior': result.actualBehavior,
        'self_explanation': result.selfExplanation,
        'dissonance_point': result.dissonancePoint,
        'core_conflict': result.coreConflict,
        'source_type': sourceType,
        'source_id': sourceId,
        'dissonance_reduction_mode': result.dissonanceReductionMode,
        'created_at_ms': createdAtMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'cc_trigger_conditions',
      <String, Object?>{
        'session_id': sessionId,
        'freedom_of_choice': result.freedomOfChoice,
        'negative_consequence': result.negativeConsequence,
        'foreseeability': result.foreseeability,
        'responsibility_feeling': result.responsibilityFeeling,
        'repairability': result.repairability,
        'not_user_responsibility': result.notUserResponsibility,
        'user_responsibility': result.userResponsibility,
        'over_blame_risk': result.overBlameRisk,
        'avoidance_risk': result.avoidanceRisk,
        'repairable_part': result.repairablePart,
        'created_at_ms': createdAtMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'cc_self_standards',
      <String, Object?>{
        'session_id': sessionId,
        'personal_standard': result.personalStandard,
        'normative_standard': result.normativeStandard,
        'family_or_group_standard': result.familyOrGroupStandard,
        'ideal_self_standard': result.idealSelfStandard,
        'adjusted_standard': result.adjustedStandard,
        'created_at_ms': createdAtMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'cc_rationalization_flags',
      <String, Object?>{
        'session_id': sessionId,
        'rationalization_types': result.rationalizationTypes,
        'protective_function': result.protectiveFunction,
        'long_term_cost': result.longTermCost,
        'honest_reframe': result.honestReframe,
        'protective_explanation': result.protectiveExplanation,
        'avoidance_explanation': result.avoidanceExplanation,
        'created_at_ms': createdAtMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'cc_special_scene_details',
      <String, Object?>{
        'session_id': sessionId,
        'scene_type': sceneType,
        'choice_paths': result.choicePaths,
        'sunk_cost_check': result.sunkCostCheck,
        'hypocrisy_induction': result.hypocrisyInduction,
        'group_conflict': result.groupConflict,
        'vicarious_dissonance': result.vicariousDissonance,
        'todo_write_back_insight': result.todoWriteBackInsight,
        'verification_question': result.verificationQuestion,
        'verification_success_signal': result.verificationSuccessSignal,
        'verification_due_days': result.verificationDueDays,
        'created_at_ms': createdAtMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final parsed = _parsedResultJson(result);
    await _saveRationalizationItems(db, sessionId, result, parsed, createdAtMs);
    await _saveSelfStandardItems(db, sessionId, result, parsed, createdAtMs);
    await _saveSpecialSceneItems(db, sessionId, sceneType, result, parsed, createdAtMs);
    await _saveV18GrowthConsistencyDetails(db, sessionId, result, parsed, createdAtMs);
    await _saveSourcebookStructuredDetails(db, sessionId, sceneType, result, parsed, sourceType, sourceId, createdAtMs);
    await _createVerificationTaskIfNeeded(db, sessionId, sceneType, result, createdAtMs);
  }


  Map<String, dynamic> _parsedResultJson(CcPlanResult result) {
    final raw = result.rawResponse.trim();
    if (raw.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final decoded = jsonDecode(raw.substring(start, end + 1));
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _mapFrom(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  List<dynamic> _listFrom(dynamic value) {
    if (value is List) return value;
    return const <dynamic>[];
  }

  String _str(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is List) return value.map(_str).where((e) => e.isNotEmpty).join('、');
    if (value is Map) {
      return value.entries
          .map((e) => '${e.key}：${_str(e.value)}')
          .where((e) => !e.endsWith('：'))
          .join('\n');
    }
    return value.toString().trim();
  }

  List<String> _splitItems(String text) {
    final set = <String>{};
    for (final raw in text.split(RegExp(r'[、，,;；|/\n]+'))) {
      final item = raw.trim();
      if (item.isEmpty || item.length > 40) continue;
      if (item.contains('：') || item.contains(':')) continue;
      set.add(item);
    }
    return set.toList(growable: false);
  }


  int _asDimensionScore(dynamic value) {
    if (value is num) return value.round().clamp(0, 3).toInt();
    return int.tryParse((value ?? '0').toString().trim())?.clamp(0, 3).toInt() ?? 0;
  }

  int _asTotalScore(dynamic value) {
    if (value is num) return value.round().clamp(0, 24).toInt();
    return int.tryParse((value ?? '0').toString().trim())?.clamp(0, 24).toInt() ?? 0;
  }

  int _asPercent(dynamic value) {
    if (value is num) return value.round().clamp(0, 100).toInt();
    return int.tryParse((value ?? '0').toString().trim())?.clamp(0, 100).toInt() ?? 0;
  }

  String _normalizeIntensityLevel(String raw, int total) {
    final text = raw.trim();
    if (text.contains('深层') || text.contains('身份')) return '深层身份型';
    if (text.contains('高')) return '高';
    if (text.contains('中')) return '中';
    if (text.contains('低')) return '低';
    if (total >= 18) return '深层身份型';
    if (total >= 12) return '高';
    if (total >= 6) return '中';
    return total > 0 ? '低' : '';
  }

  double _asConfidence(dynamic value) {
    if (value is num) {
      final v = value.toDouble();
      return v > 1 ? (v / 100).clamp(0.0, 1.0) : v.clamp(0.0, 1.0);
    }
    final parsed = double.tryParse((value ?? '').toString().trim());
    if (parsed == null) return 0.6;
    return parsed > 1 ? (parsed / 100).clamp(0.0, 1.0) : parsed.clamp(0.0, 1.0);
  }

  int _asScore(dynamic value) => _asTotalScore(value);

  Map<String, dynamic> _sourcebookMap(Map<String, dynamic> parsed) {
    final sourcebook = _mapFrom(parsed['sourcebookAnalysis']);
    return sourcebook.isEmpty ? parsed : sourcebook;
  }


  Future<void> _saveSourcebookProtectedSelfAndDefense(Database db, String sessionId, String caseId, Map<String, dynamic> sourcebook, int createdAtMs) async {
    await db.delete('cc_protected_self_images', where: 'session_id = ?', whereArgs: <Object?>[sessionId]);
    await db.delete('cc_defense_pattern_records', where: 'session_id = ?', whereArgs: <Object?>[sessionId]);

    final protectedItems = _listFrom(sourcebook['protectedSelfImage']).toList();
    if (protectedItems.isEmpty) {
      final imageText = _str(sourcebook['protectedSelfImage']);
      if (imageText.isNotEmpty) protectedItems.add(<String, Object?>{'image': imageText, 'evidence': '', 'confidence': 'medium'});
    }
    var imageIndex = 0;
    for (final raw in protectedItems) {
      final m = _mapFrom(raw);
      final image = _str(m.isEmpty ? raw : (m['image'] ?? m['label'] ?? m['selfImage']));
      if (image.isEmpty) continue;
      await db.insert('cc_protected_self_images', <String, Object?>{
        'image_id': 'psi_${sessionId}_${imageIndex}_${image.hashCode.abs()}',
        'session_id': sessionId,
        'case_id': caseId,
        'image': image,
        'evidence': _str(m['evidence'] ?? m['reason']),
        'confidence': _str(m['confidence']).isNotEmpty ? _str(m['confidence']) : 'medium',
        'created_at_ms': createdAtMs,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      imageIndex++;
    }

    final defenseItems = _listFrom(sourcebook['defensePatterns']).toList();
    if (defenseItems.isEmpty) {
      final function = _mapFrom(sourcebook['psychologicalFunction']);
      final desc = _str(function['shortTermBenefit'] ?? function['pastFunction'] ?? function['protectedNeed']);
      final cost = _str(function['currentCost'] ?? function['limitation']);
      if (desc.isNotEmpty || cost.isNotEmpty) {
        defenseItems.add(<String, Object?>{'type': 'psychological_function', 'description': desc, 'possibleCost': cost});
      }
    }
    var patternIndex = 0;
    for (final raw in defenseItems) {
      final m = _mapFrom(raw);
      final type = _str(m.isEmpty ? '' : (m['type'] ?? m['patternType'] ?? m['pattern_type']));
      final desc = _str(m.isEmpty ? raw : (m['description'] ?? m['pattern'] ?? m['evidence']));
      final cost = _str(m['possibleCost'] ?? m['cost'] ?? m['longTermCost']);
      if (type.isEmpty && desc.isEmpty && cost.isEmpty) continue;
      final sig = '${type}|${desc}|${cost}';
      await db.insert('cc_defense_pattern_records', <String, Object?>{
        'pattern_id': 'dpr_${sessionId}_${patternIndex}_${sig.hashCode.abs()}',
        'session_id': sessionId,
        'case_id': caseId,
        'pattern_type': type.isEmpty ? 'defense_pattern' : type,
        'description': desc,
        'possible_cost': cost,
        'created_at_ms': createdAtMs,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      patternIndex++;
    }
  }

  Future<void> _saveSourcebookStructuredDetails(
    Database db,
    String sessionId,
    String sceneType,
    CcPlanResult result,
    Map<String, dynamic> parsed,
    String sourceType,
    String sourceId,
    int createdAtMs,
  ) async {
    final sourcebook = _sourcebookMap(parsed);
    final caseId = 'case_$sessionId';
    final currentStage = _str(sourcebook['currentStage']).isNotEmpty ? _str(sourcebook['currentStage']) : 'structure_map';
    final integrated = _str(sourcebook['integratedSelfStatement']).isNotEmpty
        ? _str(sourcebook['integratedSelfStatement'])
        : _str(_mapFrom(sourcebook['valueLayers'])['integratedStatement']);
    await db.insert(
      'cc_sourcebook_cases',
      <String, Object?>{
        'case_id': caseId,
        'session_id': sessionId,
        'scene_type': sceneType,
        'event_summary': result.eventSummary.trim().isNotEmpty ? result.eventSummary : result.coreConflict,
        'current_stage': currentStage,
        'user_confirmation': 'pending',
        'integrated_self_statement': integrated,
        'source_type': sourceType,
        'source_id': sourceId,
        'created_at_ms': createdAtMs,
        'updated_at_ms': createdAtMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _saveSourcebookProtectedSelfAndDefense(db, sessionId, caseId, sourcebook, createdAtMs);
    await _saveSourcebookNodesAndEdges(db, sessionId, caseId, result, sourcebook, parsed, createdAtMs);
    await _saveSourcebookValueLayers(db, sessionId, caseId, sourcebook, createdAtMs);
    await _saveSourcebookChoices(db, sessionId, caseId, sourcebook, createdAtMs);
    await _saveSourcebookInterpersonalBalance(db, sessionId, caseId, sourcebook, createdAtMs);
    await _saveSourcebookCounterExperiment(db, sessionId, caseId, sourcebook, createdAtMs);
    await _saveSourcebookCommitmentAction(db, sessionId, caseId, result, sourcebook, createdAtMs);
  }

  Future<void> _saveSourcebookNodesAndEdges(Database db, String sessionId, String caseId, CcPlanResult result, Map<String, dynamic> sourcebook, Map<String, dynamic> parsed, int createdAtMs) async {
    await db.delete('cc_cognition_nodes', where: 'session_id = ?', whereArgs: <Object?>[sessionId]);
    await db.delete('cc_conflict_edges', where: 'session_id = ?', whereArgs: <Object?>[sessionId]);
    final map = _mapFrom(sourcebook['cognitiveStructureMap']).isNotEmpty ? _mapFrom(sourcebook['cognitiveStructureMap']) : _mapFrom(parsed['cognitiveStructureMap']);
    final nodes = _listFrom(map['nodes']).toList();
    if (nodes.isEmpty) {
      nodes.addAll(<Map<String, Object?>>[
        if (result.believedValue.trim().isNotEmpty) <String, Object?>{'nodeType': 'value', 'label': '我相信/重视', 'content': result.believedValue, 'importance': 'high', 'confidence': 0.6},
        if (result.actualBehavior.trim().isNotEmpty) <String, Object?>{'nodeType': 'behavior', 'label': '实际行为', 'content': result.actualBehavior, 'importance': 'high', 'confidence': 0.6},
        if (result.selfExplanation.trim().isNotEmpty) <String, Object?>{'nodeType': 'belief', 'label': '自我解释', 'content': result.selfExplanation, 'importance': 'medium', 'confidence': 0.6},
        if (result.dissonancePoint.trim().isNotEmpty) <String, Object?>{'nodeType': 'evidence', 'label': '不一致点', 'content': result.dissonancePoint, 'importance': 'high', 'confidence': 0.6},
      ]);
    }
    var index = 0;
    final nodeIdByLabel = <String, String>{};
    for (final raw in nodes) {
      final node = _mapFrom(raw);
      if (node.isEmpty) continue;
      final label = _str(node['label']).isNotEmpty ? _str(node['label']) : '节点${index + 1}';
      final content = _str(node['content']).isNotEmpty ? _str(node['content']) : _str(raw);
      if (content.isEmpty && label.trim().isEmpty) continue;
      final nodeId = 'node_${sessionId}_${index}_${label.hashCode.abs()}';
      nodeIdByLabel[label] = nodeId;
      await db.insert('cc_cognition_nodes', <String, Object?>{
        'node_id': nodeId,
        'case_id': caseId,
        'session_id': sessionId,
        'node_type': _str(node['nodeType']).isNotEmpty ? _str(node['nodeType']) : 'belief',
        'label': label,
        'content': content,
        'importance': _str(node['importance']).isNotEmpty ? _str(node['importance']) : 'medium',
        'confidence': _asConfidence(node['confidence']),
        'user_status': 'ai_generated',
        'user_note': '',
        'sort_order': index,
        'created_at_ms': createdAtMs,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      index++;
    }
    final edges = _listFrom(map['edges']).toList();
    if (edges.isEmpty && result.believedValue.trim().isNotEmpty && result.actualBehavior.trim().isNotEmpty) {
      edges.add(<String, Object?>{'from': '我相信/重视', 'to': '实际行为', 'relationType': 'inconsistent', 'description': result.dissonancePoint, 'strength': 0.7});
    }
    var edgeIndex = 0;
    for (final raw in edges) {
      final edge = _mapFrom(raw);
      if (edge.isEmpty) continue;
      final from = _str(edge['from']);
      final to = _str(edge['to']);
      final desc = _str(edge['description']);
      if (from.isEmpty && to.isEmpty && desc.isEmpty) continue;
      await db.insert('cc_conflict_edges', <String, Object?>{
        'edge_id': 'edge_${sessionId}_${edgeIndex}_${('$from|$to').hashCode.abs()}',
        'case_id': caseId,
        'session_id': sessionId,
        'from_node_id': nodeIdByLabel[from] ?? '',
        'to_node_id': nodeIdByLabel[to] ?? '',
        'from_label': from,
        'to_label': to,
        'relation_type': _str(edge['relationType']).isNotEmpty ? _str(edge['relationType']) : 'uncertain',
        'description': desc,
        'strength': _asConfidence(edge['strength']),
        'user_status': 'ai_generated',
        'user_note': '',
        'sort_order': edgeIndex,
        'created_at_ms': createdAtMs,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      edgeIndex++;
    }
  }

  Future<void> _saveSourcebookValueLayers(Database db, String sessionId, String caseId, Map<String, dynamic> sourcebook, int createdAtMs) async {
    await db.delete('cc_value_layer_records', where: 'session_id = ?', whereArgs: <Object?>[sessionId]);
    final v = _mapFrom(sourcebook['valueLayers']);
    if (v.isEmpty) return;
    await db.insert('cc_value_layer_records', <String, Object?>{
      'record_id': 'vl_$sessionId', 'session_id': sessionId, 'case_id': caseId,
      'core_values': _str(v['coreValues']), 'identity_beliefs': _str(v['identityBeliefs']), 'peripheral_explanations': _str(v['peripheralExplanations']),
      'keep_items': _str(v['keepItems']), 'loosen_items': _str(v['loosenItems']), 'test_items': _str(v['testItems']),
      'integrated_statement': _str(v['integratedStatement']).isNotEmpty ? _str(v['integratedStatement']) : _str(sourcebook['integratedSelfStatement']),
      'created_at_ms': createdAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _saveSourcebookChoices(Database db, String sessionId, String caseId, Map<String, dynamic> sourcebook, int createdAtMs) async {
    await db.delete('cc_user_choice_records', where: 'session_id = ?', whereArgs: <Object?>[sessionId]);
    final options = _listFrom(sourcebook['userChoiceOptions']);
    var index = 0;
    for (final raw in options) {
      final m = _mapFrom(raw);
      if (m.isEmpty) continue;
      await db.insert('cc_user_choice_records', <String, Object?>{
        'choice_id': 'choice_${sessionId}_$index', 'session_id': sessionId, 'case_id': caseId,
        'label': _str(m['label']), 'description': _str(m['description']), 'next_action': _str(m['nextAction']), 'selected': 0, 'created_at_ms': createdAtMs,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      index++;
    }
  }

  Future<void> _saveSourcebookInterpersonalBalance(Database db, String sessionId, String caseId, Map<String, dynamic> sourcebook, int createdAtMs) async {
    await db.delete('cc_interpersonal_balance_records', where: 'session_id = ?', whereArgs: <Object?>[sessionId]);
    final b = _mapFrom(sourcebook['interpersonalBalance']);
    if (b.isEmpty) return;
    await db.insert('cc_interpersonal_balance_records', <String, Object?>{
      'record_id': 'ib_$sessionId', 'session_id': sessionId, 'case_id': caseId,
      'my_attitude_to_person': _str(b['myAttitudeToPerson']), 'object_or_issue': _str(b['objectOrIssue']),
      'my_attitude_to_object': _str(b['myAttitudeToObject']), 'other_attitude_to_object': _str(b['otherAttitudeToObject']),
      'imbalance_point': _str(b['imbalancePoint']), 'possible_balance_paths': _str(b['possibleBalancePaths']), 'boundary_action': _str(b['boundaryAction']),
      'created_at_ms': createdAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _saveSourcebookCounterExperiment(Database db, String sessionId, String caseId, Map<String, dynamic> sourcebook, int createdAtMs) async {
    await db.delete('cc_counter_attitudinal_experiments', where: 'session_id = ?', whereArgs: <Object?>[sessionId]);
    final e = _mapFrom(sourcebook['counterAttitudinalExperiment']);
    if (e.isEmpty) return;
    await db.insert('cc_counter_attitudinal_experiments', <String, Object?>{
      'experiment_id': 'cae_$sessionId', 'session_id': sessionId, 'case_id': caseId,
      'old_belief': _str(e['oldBelief']), 'protective_function': _str(e['protectiveFunction']), 'limitation': _str(e['limitation']),
      'experiment_action': _str(e['experimentAction']), 'duration_minutes': _asTotalScore(e['durationMinutes']).clamp(0, 120).toInt(),
      'completion_standard': _str(e['completionStandard']), 'observation_question': _str(e['observationQuestion']), 'updated_belief': _str(e['updatedBelief']),
      'completed_result': '', 'belief_shift_score': 0, 'created_at_ms': createdAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _saveSourcebookCommitmentAction(Database db, String sessionId, String caseId, CcPlanResult result, Map<String, dynamic> sourcebook, int createdAtMs) async {
    await db.delete('cc_commitment_action_contracts', where: 'session_id = ?', whereArgs: <Object?>[sessionId]);
    final a = _mapFrom(sourcebook['commitmentAction']);
    final hasContract = a.isNotEmpty || result.oneDollarAction.trim().isNotEmpty || result.minimumAction.trim().isNotEmpty;
    if (!hasContract) return;
    await db.insert('cc_commitment_action_contracts', <String, Object?>{
      'contract_id': 'contract_$sessionId', 'session_id': sessionId, 'case_id': caseId,
      'core_value': _str(a['coreValue']).isNotEmpty ? _str(a['coreValue']) : result.valueLink,
      'current_inconsistent_behavior': _str(a['currentInconsistentBehavior']).isNotEmpty ? _str(a['currentInconsistentBehavior']) : result.actualBehavior,
      'minimal_repair_action': _str(a['minimalRepairAction']).isNotEmpty ? _str(a['minimalRepairAction']) : (result.minimumAction.trim().isNotEmpty ? result.minimumAction : result.oneDollarAction),
      'action_time': _str(a['time']), 'action_place': _str(a['place']), 'duration_minutes': _asTotalScore(a['durationMinutes']).clamp(0, 120).toInt(),
      'completion_standard': _str(a['completionStandard']).isNotEmpty ? _str(a['completionStandard']) : result.minimumActionVariant.completionCriteria,
      'obstacle': _str(a['obstacle']), 'fallback_plan': _str(a['fallbackPlan']),
      'reflection_questions': _str(a['reflectionQuestions']).isNotEmpty ? _str(a['reflectionQuestions']) : _str(sourcebook['reflectionQuestions']),
      'status': 'draft', 'created_at_ms': createdAtMs, 'updated_at_ms': createdAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> saveSourcebookConfirmation({required String sessionId, required String confirmationLevel, String note = ''}) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final caseId = 'case_${sessionId.trim()}';
    final id = 'confirm_${sessionId}_$now';
    await db.insert('cc_user_confirmations', <String, Object?>{
      'confirmation_id': id, 'session_id': sessionId.trim(), 'case_id': caseId,
      'confirmation_level': confirmationLevel.trim().isEmpty ? 'confirmed' : confirmationLevel.trim(),
      'note': note.trim(), 'created_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.update('cc_sourcebook_cases', <String, Object?>{
      'user_confirmation': confirmationLevel.trim().isEmpty ? 'confirmed' : confirmationLevel.trim(), 'updated_at_ms': now,
    }, where: 'session_id = ?', whereArgs: <Object?>[sessionId.trim()]);
    return id;
  }


  Future<Map<String, dynamic>> sourcebookCaseDetail(String sessionId) async {
    final sid = sessionId.trim();
    if (sid.isEmpty) return <String, dynamic>{};
    final db = await _db;
    final caseRows = await db.query('cc_sourcebook_cases', where: 'session_id = ?', whereArgs: <Object?>[sid], limit: 1);
    final caseMap = caseRows.isEmpty ? <String, Object?>{} : caseRows.first;
    final nodes = await db.query('cc_cognition_nodes', where: 'session_id = ?', whereArgs: <Object?>[sid], orderBy: 'sort_order ASC, created_at_ms ASC');
    final edges = await db.query('cc_conflict_edges', where: 'session_id = ?', whereArgs: <Object?>[sid], orderBy: 'sort_order ASC, created_at_ms ASC');
    final valueRows = await db.query('cc_value_layer_records', where: 'session_id = ?', whereArgs: <Object?>[sid], limit: 1);
    final choiceRows = await db.query('cc_user_choice_records', where: 'session_id = ?', whereArgs: <Object?>[sid], orderBy: 'created_at_ms ASC');
    final interpersonalRows = await db.query('cc_interpersonal_balance_records', where: 'session_id = ?', whereArgs: <Object?>[sid], limit: 1);
    final experimentRows = await db.query('cc_counter_attitudinal_experiments', where: 'session_id = ?', whereArgs: <Object?>[sid], limit: 1);
    final contractRows = await db.query('cc_commitment_action_contracts', where: 'session_id = ?', whereArgs: <Object?>[sid], limit: 1);
    final confirmations = await db.query('cc_user_confirmations', where: 'session_id = ?', whereArgs: <Object?>[sid], orderBy: 'created_at_ms DESC', limit: 20);
    final protectedSelf = await db.query('cc_protected_self_images', where: 'session_id = ?', whereArgs: <Object?>[sid], orderBy: 'created_at_ms ASC');
    final defensePatterns = await db.query('cc_defense_pattern_records', where: 'session_id = ?', whereArgs: <Object?>[sid], orderBy: 'created_at_ms ASC');
    final evidence = await db.query('cc_evidence_records', where: 'session_id = ?', whereArgs: <Object?>[sid], orderBy: 'created_at_ms DESC', limit: 20);
    final verification = await db.query('cc_verification_tasks', where: 'session_id = ?', whereArgs: <Object?>[sid], orderBy: 'created_at_ms DESC', limit: 20);
    final methodUsages = await db.query('cc_dissonance_resolution_method_usages', where: 'session_id = ? OR case_id = ?', whereArgs: <Object?>[sid, 'case_$sid'], orderBy: 'updated_at_ms DESC, created_at_ms DESC', limit: 20);
    return <String, dynamic>{
      'case': Map<String, dynamic>.from(caseMap),
      'nodes': nodes.map((e) => Map<String, dynamic>.from(e)).toList(growable: false),
      'edges': edges.map((e) => Map<String, dynamic>.from(e)).toList(growable: false),
      'valueLayers': valueRows.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(valueRows.first),
      'choices': choiceRows.map((e) => Map<String, dynamic>.from(e)).toList(growable: false),
      'interpersonalBalance': interpersonalRows.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(interpersonalRows.first),
      'counterExperiment': experimentRows.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(experimentRows.first),
      'commitmentContract': contractRows.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(contractRows.first),
      'confirmations': confirmations.map((e) => Map<String, dynamic>.from(e)).toList(growable: false),
      'protectedSelfImage': protectedSelf.map((e) => Map<String, dynamic>.from(e)).toList(growable: false),
      'defensePatterns': defensePatterns.map((e) => Map<String, dynamic>.from(e)).toList(growable: false),
      'evidence': evidence.map((e) => Map<String, dynamic>.from(e)).toList(growable: false),
      'verificationTasks': verification.map((e) => Map<String, dynamic>.from(e)).toList(growable: false),
      'resolutionMethodUsages': methodUsages.map((e) => Map<String, dynamic>.from(e)).toList(growable: false),
    };
  }

  Future<Map<String, Map<String, dynamic>>> sourcebookCaseDetailsForSessionIds(Iterable<String> sessionIds) async {
    final result = <String, Map<String, dynamic>>{};
    for (final sid in sessionIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet()) {
      final detail = await sourcebookCaseDetail(sid);
      if (detail.isNotEmpty && ((detail['case'] is Map && (detail['case'] as Map).isNotEmpty) || (detail['nodes'] is List && (detail['nodes'] as List).isNotEmpty))) {
        result[sid] = detail;
      }
    }
    return result;
  }

  Future<void> updateSourcebookNodeUserStatus({required String nodeId, required String status, String note = '', String label = '', String content = '', String nodeType = ''}) async {
    final id = nodeId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    await db.update('cc_cognition_nodes', <String, Object?>{
      'user_status': status.trim().isEmpty ? 'confirmed' : status.trim(),
      'user_note': note.trim(),
      if (label.trim().isNotEmpty) 'label': label.trim(),
      if (content.trim().isNotEmpty) 'content': content.trim(),
      if (nodeType.trim().isNotEmpty) 'node_type': nodeType.trim(),
    }, where: 'node_id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> updateSourcebookEdgeUserStatus({required String edgeId, required String status, String note = '', String description = '', String relationType = ''}) async {
    final id = edgeId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    await db.update('cc_conflict_edges', <String, Object?>{
      'user_status': status.trim().isEmpty ? 'confirmed' : status.trim(),
      'user_note': note.trim(),
      if (description.trim().isNotEmpty) 'description': description.trim(),
      if (relationType.trim().isNotEmpty) 'relation_type': relationType.trim(),
    }, where: 'edge_id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> selectSourcebookChoice(String choiceId) async {
    final id = choiceId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query('cc_user_choice_records', where: 'choice_id = ?', whereArgs: <Object?>[id], limit: 1);
    if (rows.isEmpty) return;
    final sid = (rows.first['session_id'] ?? '').toString();
    await db.update('cc_user_choice_records', <String, Object?>{'selected': 0}, where: 'session_id = ?', whereArgs: <Object?>[sid]);
    await db.update('cc_user_choice_records', <String, Object?>{'selected': 1, 'selected_at_ms': now}, where: 'choice_id = ?', whereArgs: <Object?>[id]);
    final nextAction = (rows.first['next_action'] ?? '').toString().trim();
    if (nextAction.isNotEmpty) {
      final existing = await db.query('cc_commitment_action_contracts', where: 'session_id = ?', whereArgs: <Object?>[sid], limit: 1);
      final contract = <String, Object?>{
        'session_id': sid,
        'case_id': (rows.first['case_id'] ?? 'case_$sid').toString(),
        'minimal_repair_action': nextAction,
        'status': 'selected',
        'updated_at_ms': now,
      };
      if (existing.isEmpty) {
        await db.insert('cc_commitment_action_contracts', <String, Object?>{
          'contract_id': 'contract_$sid',
          ...contract,
          'core_value': (rows.first['label'] ?? '').toString(),
          'current_inconsistent_behavior': (rows.first['description'] ?? '').toString(),
          'action_time': '',
          'action_place': '',
          'duration_minutes': 10,
          'completion_standard': '完成这个最小下一步，并记录实际体验。',
          'obstacle': '',
          'fallback_plan': '如果阻力太大，就降级为 2 分钟版本。',
          'reflection_questions': '它是否让价值与行为更接近？',
          'created_at_ms': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await db.update('cc_commitment_action_contracts', contract, where: 'session_id = ?', whereArgs: <Object?>[sid]);
      }
    }
    await db.update('cc_sourcebook_cases', <String, Object?>{'current_stage': 'action_contract', 'updated_at_ms': now}, where: 'session_id = ?', whereArgs: <Object?>[sid]);
  }

  Future<void> updateSourcebookContractStatus({required String contractId, required String status}) async {
    final id = contractId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    await db.update('cc_commitment_action_contracts', <String, Object?>{
      'status': status.trim().isEmpty ? 'draft' : status.trim(),
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
    }, where: 'contract_id = ?', whereArgs: <Object?>[id]);
  }


  Future<void> markSourcebookContractIncomplete({required String contractId, required String status, String reflection = '', String fallbackPlan = ''}) async {
    final id = contractId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query('cc_commitment_action_contracts', where: 'contract_id = ?', whereArgs: <Object?>[id], limit: 1);
    if (rows.isEmpty) return;
    final c = rows.first;
    final sid = (c['session_id'] ?? '').toString();
    await db.update('cc_commitment_action_contracts', <String, Object?>{
      'status': status.trim().isEmpty ? 'failed' : status.trim(),
      if (fallbackPlan.trim().isNotEmpty) 'fallback_plan': fallbackPlan.trim(),
      'updated_at_ms': now,
    }, where: 'contract_id = ?', whereArgs: <Object?>[id]);
    await db.insert('cc_evidence_records', <String, Object?>{
      'evidence_id': 'ev_contract_review_${now}_${id.hashCode.abs()}',
      'session_id': sid,
      'user_goal': '源书行动契约复盘',
      'planned_action': (c['minimal_repair_action'] ?? '').toString(),
      'completed_action': status == 'adjusted' ? '调整/降级行动契约' : '未完成行动契约并完成复盘',
      'user_reflection': reflection.trim(),
      'evidence_label': status == 'adjusted' ? '调整源书行动契约' : '复盘未完成源书行动契约',
      'value_link': (c['core_value'] ?? '').toString(),
      'old_story': (c['current_inconsistent_behavior'] ?? '').toString(),
      'new_story': '失败或阻力也提供现实信息，可用来调整下一步行动。',
      'evidence_category': 'learning',
      'identity_direction': '能从失调和失败中修正行动的人',
      'reward_source': 'sourcebook_contract_review',
      'source_type': 'cc_sourcebook_contract',
      'source_id': id,
      'created_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.update('cc_sourcebook_cases', <String, Object?>{'current_stage': 'review_integration', 'updated_at_ms': now}, where: 'session_id = ?', whereArgs: <Object?>[sid]);
  }

  Future<String> completeSourcebookContractAsEvidence({
    required String contractId,
    required String completedAction,
    String reflection = '',
    int effortMinutes = 0,
    int difficultyScore = 2,
  }) async {
    final id = contractId.trim();
    if (id.isEmpty) return '';
    final db = await _db;
    final rows = await db.query('cc_commitment_action_contracts', where: 'contract_id = ?', whereArgs: <Object?>[id], limit: 1);
    if (rows.isEmpty) return '';
    final c = rows.first;
    final now = DateTime.now().millisecondsSinceEpoch;
    final sid = (c['session_id'] ?? '').toString();
    final action = completedAction.trim().isNotEmpty ? completedAction.trim() : (c['minimal_repair_action'] ?? '').toString();
    final evidenceId = 'ev_contract_${now}_${id.hashCode.abs()}';
    await db.insert('cc_evidence_records', <String, Object?>{
      'evidence_id': evidenceId,
      'session_id': sid,
      'user_goal': '源书一致性行动契约',
      'planned_action': (c['minimal_repair_action'] ?? '').toString(),
      'completed_action': action,
      'user_reflection': reflection.trim(),
      'evidence_label': '完成源书行动契约',
      'value_link': (c['core_value'] ?? '').toString(),
      'old_story': (c['current_inconsistent_behavior'] ?? '').toString(),
      'new_story': '我用一个具体行动把核心价值与现实行为重新连接。',
      'evidence_category': 'responsibility',
      'identity_direction': '用行动重建一致的人',
      'reward_source': 'sourcebook_contract',
      'source_type': 'cc_sourcebook_contract',
      'source_id': id,
      'effort_minutes': effortMinutes,
      'difficulty_score': difficultyScore,
      'started_at_ms': now,
      'ended_at_ms': now,
      'created_at_ms': now,
      'dissonance_reduction_mode': 'action_repair',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.update('cc_commitment_action_contracts', <String, Object?>{'status': 'completed', 'updated_at_ms': now}, where: 'contract_id = ?', whereArgs: <Object?>[id]);
    await db.update('cc_sourcebook_cases', <String, Object?>{'current_stage': 'review_integration', 'updated_at_ms': now}, where: 'session_id = ?', whereArgs: <Object?>[sid]);
    return evidenceId;
  }

  Future<void> updateCounterAttitudinalExperimentReview({required String experimentId, required String result, required int beliefShiftScore, String updatedBelief = ''}) async {
    final id = experimentId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    await db.update('cc_counter_attitudinal_experiments', <String, Object?>{
      'completed_result': result.trim(),
      'belief_shift_score': beliefShiftScore.clamp(0, 10).toInt(),
      if (updatedBelief.trim().isNotEmpty) 'updated_belief': updatedBelief.trim(),
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
    }, where: 'experiment_id = ?', whereArgs: <Object?>[id]);
    final rows = await db.query('cc_counter_attitudinal_experiments', where: 'experiment_id = ?', whereArgs: <Object?>[id], limit: 1);
    if (rows.isNotEmpty && result.trim().isNotEmpty) {
      final e = rows.first;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('cc_evidence_records', <String, Object?>{
        'evidence_id': 'ev_counter_${now}_${id.hashCode.abs()}',
        'session_id': (e['session_id'] ?? '').toString(),
        'user_goal': '反态度行为实验',
        'planned_action': (e['experiment_action'] ?? '').toString(),
        'completed_action': result.trim(),
        'user_reflection': '旧信念松动程度：${beliefShiftScore.clamp(0, 10).toInt()}/10；新信念：${updatedBelief.trim().isEmpty ? (e['updated_belief'] ?? '') : updatedBelief.trim()}',
        'evidence_label': '完成反态度行为实验',
        'value_link': '',
        'old_story': (e['old_belief'] ?? '').toString(),
        'new_story': updatedBelief.trim().isEmpty ? (e['updated_belief'] ?? '').toString() : updatedBelief.trim(),
        'evidence_category': 'identity',
        'identity_direction': '能用小行动松动旧信念的人',
        'reward_source': 'counter_attitudinal_experiment',
        'source_type': 'cc_counter_attitudinal_experiment',
        'source_id': id,
        'created_at_ms': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final sidRows = await db.query('cc_counter_attitudinal_experiments', where: 'experiment_id = ?', whereArgs: <Object?>[id], limit: 1);
    if (sidRows.isNotEmpty) {
      await db.update('cc_sourcebook_cases', <String, Object?>{'current_stage': 'review_integration', 'updated_at_ms': DateTime.now().millisecondsSinceEpoch}, where: 'session_id = ?', whereArgs: <Object?>[(sidRows.first['session_id'] ?? '').toString()]);
    }
  }

  Future<void> updateInterpersonalBalanceAction({required String recordId, required String status, String result = ''}) async {
    final id = recordId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    await db.update('cc_interpersonal_balance_records', <String, Object?>{
      'action_status': status.trim().isEmpty ? 'suggested' : status.trim(),
      'action_result': result.trim(),
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
    }, where: 'record_id = ?', whereArgs: <Object?>[id]);
    final rows = await db.query('cc_interpersonal_balance_records', where: 'record_id = ?', whereArgs: <Object?>[id], limit: 1);
    if (rows.isNotEmpty && result.trim().isNotEmpty) {
      final r = rows.first;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('cc_evidence_records', <String, Object?>{
        'evidence_id': 'ev_interpersonal_${now}_${id.hashCode.abs()}',
        'session_id': (r['session_id'] ?? '').toString(),
        'user_goal': '人际平衡/边界行动',
        'planned_action': (r['boundary_action'] ?? '').toString(),
        'completed_action': result.trim(),
        'user_reflection': '我尝试把人、观点、边界区分开，并记录真实关系反馈。',
        'evidence_label': '完成人际平衡行动',
        'value_link': '',
        'old_story': (r['imbalance_point'] ?? '').toString(),
        'new_story': '我可以在保留关系的同时表达边界与真实态度。',
        'evidence_category': 'relationship',
        'identity_direction': '能在人际关系中保持真实与边界的人',
        'reward_source': 'interpersonal_balance',
        'source_type': 'cc_interpersonal_balance',
        'source_id': id,
        'created_at_ms': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _saveV18GrowthConsistencyDetails(
    Database db,
    String sessionId,
    CcPlanResult result,
    Map<String, dynamic> parsed,
    int createdAtMs,
  ) async {
    await _saveDissonanceTypeItems(db, sessionId, result, parsed, createdAtMs);
    await _saveDissonanceIntensity(db, sessionId, result, parsed, createdAtMs);
    await _saveConsistencyReframe(db, sessionId, result, parsed, createdAtMs);
    await _saveSelfIntegrityCard(db, sessionId, result, parsed, createdAtMs);
  }

  Future<void> _saveDissonanceTypeItems(
    Database db,
    String sessionId,
    CcPlanResult result,
    Map<String, dynamic> parsed,
    int createdAtMs,
  ) async {
    await db.delete('cc_dissonance_type_items', where: 'session_id = ?', whereArgs: <Object?>[sessionId]);
    final raw = parsed['dissonanceTypes'];
    final items = <Map<String, String>>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final key = _str(map['typeKey']).isNotEmpty ? _str(map['typeKey']) : _str(map['type']);
          final label = _str(map['typeLabel']).isNotEmpty ? _str(map['typeLabel']) : _str(map['label']);
          final evidence = _str(map['evidence']);
          final confidence = _asConfidence(map['confidence']).toStringAsFixed(2);
          if (key.isNotEmpty || label.isNotEmpty) items.add(<String, String>{'key': key, 'label': label, 'evidence': evidence, 'confidence': confidence});
        } else {
          final label = _str(item);
          if (label.isNotEmpty) items.add(<String, String>{'key': label, 'label': label, 'evidence': result.dissonancePoint});
        }
      }
    }
    for (final label in _splitItems(result.dissonanceTypes)) {
      items.add(<String, String>{'key': label, 'label': label, 'evidence': result.dissonancePoint});
    }
    var index = 0;
    final seen = <String>{};
    for (final item in items) {
      final key = (item['key'] ?? '').trim();
      final label = (item['label'] ?? '').trim();
      final sig = '$key|$label';
      if ((key.isEmpty && label.isEmpty) || !seen.add(sig)) continue;
      await db.insert(
        'cc_dissonance_type_items',
        <String, Object?>{
          'item_id': 'dt_${sessionId}_${index++}_${sig.hashCode.abs()}',
          'session_id': sessionId,
          'type_key': key,
          'type_label': label.isEmpty ? key : label,
          'confidence': double.tryParse(item['confidence'] ?? '') ?? 0.6,
          'evidence_sentence': item['evidence'] ?? '',
          'created_at_ms': createdAtMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _saveDissonanceIntensity(
    Database db,
    String sessionId,
    CcPlanResult result,
    Map<String, dynamic> parsed,
    int createdAtMs,
  ) async {
    final intensity = _mapFrom(parsed['dissonanceIntensity']);
    final freedom = _asDimensionScore(intensity['freedomScore']);
    final consequence = _asDimensionScore(intensity['consequenceScore']);
    final value = _asDimensionScore(intensity['valueScore']);
    final selfImage = _asDimensionScore(intensity['selfImageScore']);
    final publicCommitment = _asDimensionScore(intensity['publicCommitmentScore']);
    final investment = _asDimensionScore(intensity['investmentScore']);
    final informationAvoidance = _asDimensionScore(intensity['informationAvoidanceScore']);
    final emotion = _asDimensionScore(intensity['emotionScore']);
    final explicitTotal = _asTotalScore(intensity['totalScore'] ?? result.dissonanceIntensityScore);
    final summedTotal = freedom + consequence + value + selfImage + publicCommitment + investment + informationAvoidance + emotion;
    final total = explicitTotal > 0 ? explicitTotal : summedTotal.clamp(0, 24).toInt();
    final level = _normalizeIntensityLevel(_str(intensity['level']).isNotEmpty ? _str(intensity['level']) : result.dissonanceIntensityLevel, total);
    await db.insert(
      'cc_dissonance_intensity_scores',
      <String, Object?>{
        'session_id': sessionId,
        'freedom_score': freedom,
        'consequence_score': consequence,
        'value_score': value,
        'self_image_score': selfImage,
        'public_commitment_score': publicCommitment,
        'investment_score': investment,
        'information_avoidance_score': informationAvoidance,
        'emotion_score': emotion,
        'total_score': total,
        'level': level,
        'main_sources': _str(intensity['mainSources']).isNotEmpty ? _str(intensity['mainSources']) : result.dissonanceIntensityMainSources,
        'created_at_ms': createdAtMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _saveConsistencyReframe(
    Database db,
    String sessionId,
    CcPlanResult result,
    Map<String, dynamic> parsed,
    int createdAtMs,
  ) async {
    final reframe = _mapFrom(parsed['defensiveVsGrowthConsistency']);
    await db.insert(
      'cc_consistency_reframe_items',
      <String, Object?>{
        'session_id': sessionId,
        'defensive_explanation': _str(reframe['defensiveExplanation']).isNotEmpty ? _str(reframe['defensiveExplanation']) : result.defensiveExplanation,
        'short_term_protection': _str(reframe['shortTermProtection']).isNotEmpty ? _str(reframe['shortTermProtection']) : result.shortTermProtection,
        'long_term_cost': _str(reframe['longTermCost']).isNotEmpty ? _str(reframe['longTermCost']) : result.longTermCost,
        'growth_explanation': _str(reframe['growthExplanation']).isNotEmpty ? _str(reframe['growthExplanation']) : result.growthExplanation,
        'responsible_part': _str(reframe['responsiblePart']).isNotEmpty ? _str(reframe['responsiblePart']) : result.userResponsibility,
        'next_repair_action': _str(reframe['nextRepairAction']).isNotEmpty ? _str(reframe['nextRepairAction']) : result.repairAction,
        'created_at_ms': createdAtMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _saveSelfIntegrityCard(
    Database db,
    String sessionId,
    CcPlanResult result,
    Map<String, dynamic> parsed,
    int createdAtMs,
  ) async {
    final card = _mapFrom(parsed['selfIntegrityCard']);
    await db.insert(
      'cc_self_integrity_cards',
      <String, Object?>{
        'session_id': sessionId,
        'acknowledge_sentence': _str(card['acknowledge']).isNotEmpty ? _str(card['acknowledge']) : result.selfIntegrityCard,
        'not_equal_sentence': _str(card['notEqual']),
        'still_value_sentence': _str(card['stillValue']),
        'next_proof_action': _str(card['nextProof']).isNotEmpty ? _str(card['nextProof']) : result.oneDollarAction,
        'created_at_ms': createdAtMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _saveRationalizationItems(
    Database db,
    String sessionId,
    CcPlanResult result,
    Map<String, dynamic> parsed,
    int createdAtMs,
  ) async {
    await db.delete('cc_rationalization_flag_items', where: 'session_id = ?', whereArgs: <Object?>[sessionId]);
    final rationalization = _mapFrom(parsed['rationalization']);
    final rawTypes = rationalization['possibleTypes'];
    final types = <String>{};
    if (rawTypes is List) {
      types.addAll(rawTypes.map(_str).where((e) => e.isNotEmpty));
    }
    types.addAll(_splitItems(result.rationalizationTypes));
    if (types.isEmpty && result.avoidanceExplanation.trim().isNotEmpty) types.add('未分类合理化');
    var index = 0;
    for (final type in types) {
      await db.insert(
        'cc_rationalization_flag_items',
        <String, Object?>{
          'flag_id': 'rat_${sessionId}_${index++}_${type.hashCode.abs()}',
          'session_id': sessionId,
          'flag_type': type,
          'evidence_sentence': result.avoidanceExplanation,
          'protective_function': result.protectiveFunction,
          'long_term_cost': result.longTermCost,
          'repair_action': result.repairAction.trim().isEmpty ? result.oneDollarAction : result.repairAction,
          'created_at_ms': createdAtMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _saveSelfStandardItems(
    Database db,
    String sessionId,
    CcPlanResult result,
    Map<String, dynamic> parsed,
    int createdAtMs,
  ) async {
    await db.delete('cc_self_standard_items', where: 'session_id = ?', whereArgs: <Object?>[sessionId]);
    final standards = _mapFrom(parsed['selfStandards']);
    final items = <String, String>{
      'personal': _str(standards['personalStandard']).isNotEmpty ? _str(standards['personalStandard']) : result.personalStandard,
      'normative': _str(standards['normativeStandard']).isNotEmpty ? _str(standards['normativeStandard']) : result.normativeStandard,
      'family_group': _str(standards['familyOrGroupStandard']).isNotEmpty ? _str(standards['familyOrGroupStandard']) : result.familyOrGroupStandard,
      'ideal_self': _str(standards['idealSelfStandard']).isNotEmpty ? _str(standards['idealSelfStandard']) : result.idealSelfStandard,
      'adjusted': _str(standards['adjustedStandard']).isNotEmpty ? _str(standards['adjustedStandard']) : result.adjustedStandard,
    };
    var index = 0;
    for (final entry in items.entries) {
      if (entry.value.trim().isEmpty) continue;
      await db.insert(
        'cc_self_standard_items',
        <String, Object?>{
          'item_id': 'std_${sessionId}_${entry.key}_${index++}',
          'session_id': sessionId,
          'standard_type': entry.key,
          'standard_source': entry.key == 'adjusted' ? 'ai_adjusted' : 'ai_detected',
          'standard_text': entry.value,
          'is_rigid': entry.key == 'adjusted' ? 0 : (entry.value.contains('必须') || entry.value.contains('失败') || entry.value.contains('应该') ? 1 : 0),
          'adjusted_standard': result.adjustedStandard,
          'linked_action': result.oneDollarAction,
          'created_at_ms': createdAtMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _saveSpecialSceneItems(
    Database db,
    String sessionId,
    String sceneType,
    CcPlanResult result,
    Map<String, dynamic> parsed,
    int createdAtMs,
  ) async {
    await db.delete('cc_special_scene_items', where: 'session_id = ?', whereArgs: <Object?>[sessionId]);
    final sourcebook = _sourcebookMap(parsed);
    final sections = <String, dynamic>{
      'choicePaths': parsed['choicePaths'],
      'sunkCostCheck': parsed['sunkCostCheck'],
      'hypocrisyInduction': parsed['hypocrisyInduction'],
      'groupConflict': parsed['groupConflict'],
      'vicariousDissonance': parsed['vicariousDissonance'],
      'informationAvoidance': parsed['informationAvoidance'],
      'identityConflict': parsed['identityConflict'],
      'cognitiveStructureMap': sourcebook['cognitiveStructureMap'],
      'conflictTypeRouting': sourcebook['conflictTypeRouting'],
      'psychologicalFunction': sourcebook['psychologicalFunction'],
      'valueLayers': sourcebook['valueLayers'],
      'alternativeInterpretations': sourcebook['alternativeInterpretations'],
      'interpersonalBalance': sourcebook['interpersonalBalance'],
      'counterAttitudinalExperiment': sourcebook['counterAttitudinalExperiment'],
      'commitmentAction': sourcebook['commitmentAction'],
    };
    final fallbackSections = <String, String>{
      'choicePaths': result.choicePaths,
      'sunkCostCheck': result.sunkCostCheck,
      'hypocrisyInduction': result.hypocrisyInduction,
      'groupConflict': result.groupConflict,
      'vicariousDissonance': result.vicariousDissonance,
      'informationAvoidance': result.informationAvoidance,
      'identityConflict': result.identityConflict,
      'cognitiveStructureMap': result.dissonancePoint,
      'conflictTypeRouting': result.dissonanceTypes,
      'psychologicalFunction': result.protectiveFunction,
      'valueLayers': result.valueLink,
      'alternativeInterpretations': result.honestReframe,
      'interpersonalBalance': result.groupConflict,
      'counterAttitudinalExperiment': result.identityConflict,
      'commitmentAction': result.minimumAction.trim().isNotEmpty ? result.minimumAction : result.oneDollarAction,
    };
    var index = 0;
    for (final entry in sections.entries) {
      final map = _mapFrom(entry.value);
      if (map.isNotEmpty) {
        for (final item in map.entries) {
          final value = _str(item.value);
          if (value.isEmpty) continue;
          await db.insert(
            'cc_special_scene_items',
            <String, Object?>{
              'item_id': 'sp_${sessionId}_${entry.key}_${index++}',
              'session_id': sessionId,
              'scene_type': sceneType,
              'section_name': entry.key,
              'item_key': item.key.toString(),
              'item_value': value,
              'created_at_ms': createdAtMs,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } else {
        final fallbackText = (fallbackSections[entry.key] ?? '').trim();
        if (fallbackText.isEmpty) continue;
        await db.insert(
          'cc_special_scene_items',
          <String, Object?>{
            'item_id': 'sp_${sessionId}_${entry.key}_${index++}',
            'session_id': sessionId,
            'scene_type': sceneType,
            'section_name': entry.key,
            'item_key': 'summary',
            'item_value': fallbackText,
            'created_at_ms': createdAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  bool _isSpecialScene(String sceneType) => const <String>{
        'choice_recheck',
        'sunk_cost',
        'hypocrisy_change',
        'group_culture',
        'vicarious_dissonance',
        'responsibility_radar',
        'self_standard_map',
        'information_avoidance',
        'identity_conflict',
        'cognitive_structure_map',
        'conflict_type_router',
        'psychological_function',
        'value_layering',
        'interpersonal_balance',
        'counter_attitudinal_experiment',
      }.contains(sceneType);

  Future<void> _createVerificationTaskIfNeeded(
    Database db,
    String sessionId,
    String sceneType,
    CcPlanResult result,
    int createdAtMs,
  ) async {
    if (!_isSpecialScene(sceneType) && result.verificationQuestion.trim().isEmpty) return;
    final question = result.verificationQuestion.trim().isNotEmpty
        ? result.verificationQuestion.trim()
        : '现实验证：这次分析后的最小行动是否改变了结果、关系、责任边界或自我解释？';
    final dueDays = result.verificationDueDays <= 0 ? 3 : result.verificationDueDays.clamp(1, 30).toInt();
    await db.insert(
      'cc_verification_tasks',
      <String, Object?>{
        'task_id': 'vf_${sessionId}_${createdAtMs.hashCode.abs()}',
        'session_id': sessionId,
        'scene_type': sceneType,
        'question': question,
        'success_signal': result.verificationSuccessSignal,
        'due_at_ms': createdAtMs + dueDays * 24 * 60 * 60 * 1000,
        'status': 'open',
        'result_note': '',
        'created_at_ms': createdAtMs,
        'verified_at_ms': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CcSession>> recentSessions({int limit = 20}) async {
    final db = await _db;
    final rows = await db.query('cc_sessions', orderBy: 'updated_at_ms DESC', limit: limit);
    return rows.map(_sessionFromRow).toList(growable: false);
  }


  Future<void> updateSessionStatus(String sessionId, String status) async {
    if (sessionId.trim().isEmpty) return;
    final db = await _db;
    await db.update(
      'cc_sessions',
      <String, Object?>{
        'status': status,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'session_id = ?',
      whereArgs: <Object?>[sessionId.trim()],
    );
  }

  Future<String> saveEvidence({
    required String sessionId,
    required String userGoal,
    required String plannedAction,
    required String completedAction,
    required String userReflection,
    required String evidenceLabel,
    required String valueLink,
    required String oldStory,
    required String newStory,
    String evidenceCategory = 'start',
    String identityDirection = '',
    String rewardSource = '',
    String sourceType = '',
    String sourceId = '',
    String dissonanceReductionMode = 'explanation_only',
    required int effortMinutes,
    required int difficultyScore,
    int startedAtMs = 0,
    int endedAtMs = 0,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final evidenceId = 'ev_${now}_${completedAction.hashCode.abs()}';
    await db.insert(
      'cc_evidence_records',
      <String, Object?>{
        'evidence_id': evidenceId,
        'session_id': sessionId,
        'user_goal': userGoal,
        'planned_action': plannedAction,
        'completed_action': completedAction,
        'user_reflection': userReflection,
        'evidence_label': evidenceLabel,
        'value_link': valueLink,
        'old_story': oldStory,
        'new_story': newStory,
        'evidence_category': evidenceCategory,
        'identity_direction': identityDirection,
        'reward_source': rewardSource,
        'source_type': sourceType,
        'source_id': sourceId,
        'dissonance_reduction_mode': dissonanceReductionMode,
        'effort_minutes': effortMinutes,
        'difficulty_score': difficultyScore,
        'started_at_ms': startedAtMs,
        'ended_at_ms': endedAtMs,
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return evidenceId;
  }


  Future<String> saveDissonanceTemperatureLog({
    required String sessionId,
    String evidenceId = '',
    required String phase,
    int discomfortScore = 0,
    int guiltScore = 0,
    int anxietyScore = 0,
    int shameScore = 0,
    int defensivenessScore = 0,
    int avoidanceUrgeScore = 0,
    int clarityScore = 0,
    int responsibilityScore = 0,
    int actionWillingnessScore = 0,
    String note = '',
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'tmp_${now}_${sessionId.hashCode.abs()}_${phase.hashCode.abs()}';
    await db.insert(
      'cc_dissonance_temperature_logs',
      <String, Object?>{
        'log_id': id,
        'session_id': sessionId.trim(),
        'evidence_id': evidenceId.trim(),
        'phase': phase.trim().isEmpty ? 'after' : phase.trim(),
        'discomfort_score': discomfortScore.clamp(0, 10).toInt(),
        'guilt_score': guiltScore.clamp(0, 10).toInt(),
        'anxiety_score': anxietyScore.clamp(0, 10).toInt(),
        'shame_score': shameScore.clamp(0, 10).toInt(),
        'defensiveness_score': defensivenessScore.clamp(0, 10).toInt(),
        'avoidance_urge_score': avoidanceUrgeScore.clamp(0, 10).toInt(),
        'clarity_score': clarityScore.clamp(0, 10).toInt(),
        'responsibility_score': responsibilityScore.clamp(0, 10).toInt(),
        'action_willingness_score': actionWillingnessScore.clamp(0, 10).toInt(),
        'note': note.trim(),
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }


  Future<int> bindLatestPendingBeforeTemperature({
    required String sessionId,
    required String evidenceId,
  }) async {
    final sid = sessionId.trim();
    final eid = evidenceId.trim();
    if (sid.isEmpty || eid.isEmpty) return 0;
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final earliest = now - const Duration(hours: 24).inMilliseconds;
    final rows = await db.query(
      'cc_dissonance_temperature_logs',
      columns: const <String>['log_id'],
      where: "session_id = ? AND phase = 'before' AND created_at_ms >= ? AND (evidence_id IS NULL OR TRIM(evidence_id) = '')",
      whereArgs: <Object?>[sid, earliest],
      orderBy: 'created_at_ms DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      await db.update(
        'cc_dissonance_temperature_logs',
        <String, Object?>{'note': '行动前 pending 温度已过期：超过24小时未绑定证据'},
        where: "session_id = ? AND phase = 'before' AND created_at_ms < ? AND (evidence_id IS NULL OR TRIM(evidence_id) = '')",
        whereArgs: <Object?>[sid, earliest],
      );
      return 0;
    }
    final targetId = (rows.first['log_id'] ?? '').toString();
    final updated = await db.update(
      'cc_dissonance_temperature_logs',
      <String, Object?>{'evidence_id': eid, 'note': '行动前 pending 温度已绑定到证据'},
      where: 'log_id = ?',
      whereArgs: <Object?>[targetId],
    );
    await db.update(
      'cc_dissonance_temperature_logs',
      <String, Object?>{'note': '旧行动前 pending 温度已失效：同一 session 已绑定更新记录'},
      where: "session_id = ? AND phase = 'before' AND log_id <> ? AND (evidence_id IS NULL OR TRIM(evidence_id) = '')",
      whereArgs: <Object?>[sid, targetId],
    );
    return updated;
  }

  Future<List<CcEvidenceRecord>> recentEvidence({
    int limit = 50,
    String? category,
    int? sinceAtMs,
    int? untilAtMs,
    String? sourceType,
    String? sourceId,
  }) async {
    final db = await _db;
    final whereParts = <String>[];
    final args = <Object?>[];
    if (category != null && category.trim().isNotEmpty) {
      whereParts.add('evidence_category = ?');
      args.add(category.trim());
    }
    if (sinceAtMs != null && sinceAtMs > 0) {
      whereParts.add('created_at_ms >= ?');
      args.add(sinceAtMs);
    }
    if (untilAtMs != null && untilAtMs > 0) {
      whereParts.add('created_at_ms < ?');
      args.add(untilAtMs);
    }
    if (sourceType != null && sourceType.trim().isNotEmpty) {
      whereParts.add('source_type = ?');
      args.add(sourceType.trim());
    }
    if (sourceId != null && sourceId.trim().isNotEmpty) {
      whereParts.add('source_id = ?');
      args.add(sourceId.trim());
    }
    final rows = await db.query(
      'cc_evidence_records',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(_evidenceFromRow).toList(growable: false);
  }

  Future<String> saveValueProfile({
    String valueId = '',
    required String valueLabel,
    required String why,
    required String identityDirection,
    required String exampleAction,
    required int priority,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = valueId.trim().isNotEmpty ? valueId.trim() : 'val_${now}_${valueLabel.hashCode.abs()}';
    await db.insert(
      'cc_value_profiles',
      <String, Object?>{
        'value_id': id,
        'value_label': valueLabel,
        'why': why,
        'identity_direction': identityDirection,
        'example_action': exampleAction,
        'priority': priority,
        'created_at_ms': now,
        'updated_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<List<CcValueProfile>> listValueProfiles() async {
    final db = await _db;
    final rows = await db.query('cc_value_profiles', orderBy: 'priority DESC, updated_at_ms DESC');
    return rows.map(_valueFromRow).toList(growable: false);
  }

  Future<void> deleteValueProfile(String valueId) async {
    final db = await _db;
    await db.delete('cc_value_profiles', where: 'value_id = ?', whereArgs: <Object?>[valueId]);
    await db.delete('cc_evidence_value_links', where: 'value_id = ?', whereArgs: <Object?>[valueId]);
    await db.delete('cc_source_value_links', where: 'value_id = ?', whereArgs: <Object?>[valueId]);
  }

  Future<List<CcValueProfile>> ensureValueProfilesForLabels(
    List<String> labels, {
    int priorityBase = 100,
  }) async {
    final cleaned = labels
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (cleaned.isEmpty) return const <CcValueProfile>[];
    var existing = await listValueProfiles();
    final byLabel = <String, CcValueProfile>{
      for (final v in existing) v.valueLabel.trim(): v,
    };
    var created = false;
    for (var i = 0; i < cleaned.length; i++) {
      final label = cleaned[i];
      if (byLabel.containsKey(label)) continue;
      await saveValueProfile(
        valueLabel: label,
        why: '来自 Todo / 问题树上下文的价值线索，系统自动加入，方便建立价值—证据强关联。',
        identityDirection: '成为一个在“$label”上留下真实行动证据的人',
        exampleAction: '',
        priority: priorityBase - i,
      );
      created = true;
    }
    if (created) existing = await listValueProfiles();
    final target = cleaned.toSet();
    return existing.where((v) => target.contains(v.valueLabel.trim())).toList(growable: false);
  }

  Future<void> replaceEvidenceValueLinks({
    required String evidenceId,
    required List<CcValueProfile> values,
    String relationType = 'selected',
  }) async {
    final id = evidenceId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.delete('cc_evidence_value_links', where: 'evidence_id = ?', whereArgs: <Object?>[id]);
      final seen = <String>{};
      for (final value in values) {
        final valueId = value.valueId.trim();
        if (valueId.isEmpty || !seen.add(valueId)) continue;
        await txn.insert(
          'cc_evidence_value_links',
          <String, Object?>{
            'evidence_id': id,
            'value_id': valueId,
            'value_label': value.valueLabel,
            'relation_type': relationType,
            'created_at_ms': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> replaceSourceValueLinks({
    required String sourceType,
    required String sourceId,
    required List<CcValueProfile> values,
    String relationType = 'selected',
  }) async {
    final type = sourceType.trim();
    final id = sourceId.trim();
    if (type.isEmpty || id.isEmpty || values.isEmpty) return;
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.delete(
        'cc_source_value_links',
        where: 'source_type = ? AND source_id = ?',
        whereArgs: <Object?>[type, id],
      );
      final seen = <String>{};
      for (final value in values) {
        final valueId = value.valueId.trim();
        if (valueId.isEmpty || !seen.add(valueId)) continue;
        await txn.insert(
          'cc_source_value_links',
          <String, Object?>{
            'source_type': type,
            'source_id': id,
            'value_id': valueId,
            'value_label': value.valueLabel,
            'relation_type': relationType,
            'created_at_ms': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }


  Future<void> mergeSourceValueLinks({
    required String sourceType,
    required String sourceId,
    required List<CcValueProfile> values,
    String relationType = 'selected',
  }) async {
    final type = sourceType.trim();
    final id = sourceId.trim();
    if (type.isEmpty || id.isEmpty || values.isEmpty) return;
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final seen = <String>{};
    for (final value in values) {
      final valueId = value.valueId.trim();
      if (valueId.isEmpty || !seen.add(valueId)) continue;
      await db.insert(
        'cc_source_value_links',
        <String, Object?>{
          'source_type': type,
          'source_id': id,
          'value_id': valueId,
          'value_label': value.valueLabel,
          'relation_type': relationType,
          'created_at_ms': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<String>> sourceValueLabels({
    required String sourceType,
    required String sourceId,
  }) async {
    final type = sourceType.trim();
    final id = sourceId.trim();
    if (type.isEmpty || id.isEmpty) return const <String>[];
    final db = await _db;
    final rows = await db.query(
      'cc_source_value_links',
      columns: const <String>['value_label'],
      where: 'source_type = ? AND source_id = ?',
      whereArgs: <Object?>[type, id],
      orderBy: 'created_at_ms DESC',
      limit: 20,
    );
    final labels = rows
        .map((row) => (row['value_label'] ?? '').toString().trim())
        .where((label) => label.isNotEmpty)
        .toSet();
    if (labels.isEmpty) {
      final evidenceRows = await db.query(
        'cc_evidence_records',
        columns: const <String>['value_link'],
        where: "source_type = ? AND source_id = ? AND value_link IS NOT NULL AND TRIM(value_link) != ''",
        whereArgs: <Object?>[type, id],
        orderBy: 'created_at_ms DESC',
        limit: 10,
      );
      for (final row in evidenceRows) {
        for (final token in (row['value_link'] ?? '').toString().split(RegExp(r'[、，,;；|\n]+'))) {
          final cleaned = token.trim();
          if (cleaned.isEmpty || cleaned.length > 16) continue;
          if (cleaned.contains('：') || cleaned.contains(':')) continue;
          labels.add(cleaned);
        }
      }
    }
    return labels.toList(growable: false);
  }

  Future<int> countEvidenceForSource({
    required String sourceType,
    required String sourceId,
  }) async {
    final type = sourceType.trim();
    final id = sourceId.trim();
    if (type.isEmpty || id.isEmpty) return 0;
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM cc_evidence_records WHERE source_type = ? AND source_id = ?',
      <Object?>[type, id],
    );
    if (rows.isEmpty) return 0;
    return _asInt(rows.first['c']);
  }

  Future<List<CcEvidenceValueLink>> listEvidenceValueLinks({int limit = 3000}) async {
    final db = await _db;
    final rows = await db.query('cc_evidence_value_links', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(_valueLinkFromRow).toList(growable: false);
  }

  Future<Map<String, int>> valueEvidenceCountsFromLinks() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT value_id, COUNT(DISTINCT evidence_id) AS c
      FROM cc_evidence_value_links
      GROUP BY value_id
    ''');
    return <String, int>{
      for (final row in rows) (row['value_id'] ?? '').toString(): _asInt(row['c']),
    }..removeWhere((key, value) => key.trim().isEmpty);
  }

  Future<String> saveReport({
    required String periodLabel,
    required String userValues,
    required String reportText,
    String suggestedAction = '',
    String adoptedEvidenceId = '',
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'rpt_${now}_${periodLabel.hashCode.abs()}';
    await db.insert(
      'cc_reports',
      <String, Object?>{
        'report_id': id,
        'period_label': periodLabel,
        'user_values': userValues,
        'report_text': reportText,
        'suggested_action': suggestedAction,
        'adopted_evidence_id': adoptedEvidenceId,
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<void> updateReportAdoption({
    required String reportId,
    String suggestedAction = '',
    String adoptedEvidenceId = '',
  }) async {
    final id = reportId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    await db.update(
      'cc_reports',
      <String, Object?>{
        if (suggestedAction.trim().isNotEmpty) 'suggested_action': suggestedAction.trim(),
        if (adoptedEvidenceId.trim().isNotEmpty) 'adopted_evidence_id': adoptedEvidenceId.trim(),
      },
      where: 'report_id = ?',
      whereArgs: <Object?>[id],
    );
  }



  Future<String> saveReportActionLink({
    required String reportId,
    String sessionId = '',
    String todoStepId = '',
    String evidenceId = '',
    String status = 'suggested',
    String suggestedAction = '',
  }) async {
    final rid = reportId.trim();
    if (rid.isEmpty) return '';
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final linkId = 'ral_${now}_${rid.hashCode.abs()}_${(sessionId + todoStepId + evidenceId + suggestedAction).hashCode.abs()}';
    await db.insert(
      'cc_report_action_links',
      <String, Object?>{
        'link_id': linkId,
        'report_id': rid,
        'session_id': sessionId.trim(),
        'todo_step_id': todoStepId.trim(),
        'evidence_id': evidenceId.trim(),
        'status': status.trim().isEmpty ? 'suggested' : status.trim(),
        'suggested_action': suggestedAction.trim(),
        'created_at_ms': now,
        'updated_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (sessionId.trim().isNotEmpty) {
      await saveActionTraceLink(fromType: 'cc_report', fromId: rid, toType: 'cc_session', toId: sessionId.trim(), relationType: 'report_generated_session');
    }
    if (todoStepId.trim().isNotEmpty) {
      await saveActionTraceLink(fromType: 'cc_report', fromId: rid, toType: 'todo_goal_step', toId: todoStepId.trim(), relationType: 'report_written_to_todo');
    }
    if (evidenceId.trim().isNotEmpty) {
      await saveActionTraceLink(fromType: 'cc_report', fromId: rid, toType: 'evidence', toId: evidenceId.trim(), relationType: 'report_adopted_evidence');
    }
    return linkId;
  }

  Future<void> updateReportActionLink({
    required String reportId,
    String sessionId = '',
    String todoStepId = '',
    String evidenceId = '',
    String contractId = '',
    String methodWorkflowId = '',
    String dissonanceType = '',
    String sourcebookSupportLevel = '',
    String status = '',
    String suggestedAction = '',
  }) async {
    final rid = reportId.trim();
    if (rid.isEmpty) return;
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final whereParts = <String>['report_id = ?'];
    final args = <Object?>[rid];
    if (sessionId.trim().isNotEmpty) {
      whereParts.add('session_id = ?');
      args.add(sessionId.trim());
    }
    final rows = await db.query(
      'cc_report_action_links',
      where: whereParts.join(' AND '),
      whereArgs: args,
      orderBy: 'updated_at_ms DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      await saveReportActionLink(
        reportId: rid,
        sessionId: sessionId,
        todoStepId: todoStepId,
        evidenceId: evidenceId,
        status: status.trim().isEmpty ? 'updated' : status,
        suggestedAction: suggestedAction,
      );
      return;
    }
    final linkId = (rows.first['link_id'] ?? '').toString();
    await db.update(
      'cc_report_action_links',
      <String, Object?>{
        if (sessionId.trim().isNotEmpty) 'session_id': sessionId.trim(),
        if (todoStepId.trim().isNotEmpty) 'todo_step_id': todoStepId.trim(),
        if (evidenceId.trim().isNotEmpty) 'evidence_id': evidenceId.trim(),
        if (status.trim().isNotEmpty) 'status': status.trim(),
        if (suggestedAction.trim().isNotEmpty) 'suggested_action': suggestedAction.trim(),
        'updated_at_ms': now,
      },
      where: 'link_id = ?',
      whereArgs: <Object?>[linkId],
    );
    if (sessionId.trim().isNotEmpty) {
      await saveActionTraceLink(fromType: 'cc_report', fromId: rid, toType: 'cc_session', toId: sessionId.trim(), relationType: 'report_generated_session');
    }
    if (todoStepId.trim().isNotEmpty) {
      await saveActionTraceLink(fromType: 'cc_report', fromId: rid, toType: 'todo_goal_step', toId: todoStepId.trim(), relationType: 'report_written_to_todo');
    }
    if (evidenceId.trim().isNotEmpty) {
      await saveActionTraceLink(fromType: 'cc_report', fromId: rid, toType: 'evidence', toId: evidenceId.trim(), relationType: 'report_adopted_evidence');
    }
  }

  Future<String> saveValueRelationInsight({
    required List<CcValueProfile> selectedValues,
    required String userGoal,
    required String userContext,
    required String insightText,
    String linkedSessionId = '',
    String linkedEvidenceId = '',
  }) async {
    if (selectedValues.isEmpty || insightText.trim().isEmpty) return '';
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ids = selectedValues.map((v) => v.valueId.trim()).where((v) => v.isNotEmpty).join('|');
    final labels = selectedValues.map((v) => v.valueLabel.trim()).where((v) => v.isNotEmpty).join('、');
    final insightId = 'vri_${now}_${ids.hashCode.abs()}';
    await db.insert(
      'cc_value_relation_insights',
      <String, Object?>{
        'insight_id': insightId,
        'selected_value_ids': ids,
        'selected_value_labels': labels,
        'user_goal': userGoal.trim(),
        'user_context': userContext.trim(),
        'insight_text': insightText.trim(),
        'linked_session_id': linkedSessionId.trim(),
        'linked_evidence_id': linkedEvidenceId.trim(),
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return insightId;
  }

  Future<List<CcValueRelationInsightRecord>> recentValueRelationInsights({int limit = 12}) async {
    final db = await _db;
    final rows = await db.query('cc_value_relation_insights', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(_valueRelationInsightFromRow).toList(growable: false);
  }

  Future<CcSession?> sessionById(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) return null;
    final db = await _db;
    final rows = await db.query('cc_sessions', where: 'session_id = ?', whereArgs: <Object?>[id], limit: 1);
    if (rows.isEmpty) return null;
    return _sessionFromRow(rows.first);
  }

  Future<List<CcReportRecord>> recentReports({int limit = 8}) async {
    final db = await _db;
    final rows = await db.query('cc_reports', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(_reportFromRow).toList(growable: false);
  }

  Future<Map<String, CcSourceEvidenceSummary>> evidenceStatusForSources(
    List<({String sourceType, String sourceId})> sources,
  ) async {
    final cleaned = <({String sourceType, String sourceId})>[];
    final keys = <String>{};
    for (final s in sources) {
      final type = s.sourceType.trim();
      final id = s.sourceId.trim();
      if (type.isEmpty || id.isEmpty) continue;
      final key = '$type|$id';
      if (keys.add(key)) cleaned.add((sourceType: type, sourceId: id));
    }
    if (cleaned.isEmpty) return const <String, CcSourceEvidenceSummary>{};
    final db = await _db;
    final where = cleaned.map((_) => '(source_type = ? AND source_id = ?)').join(' OR ');
    final args = <Object?>[];
    for (final s in cleaned) {
      args..add(s.sourceType)..add(s.sourceId);
    }
    final evidenceRows = await db.query(
      'cc_evidence_records',
      columns: const <String>['source_type', 'source_id', 'completed_action', 'created_at_ms', 'value_link'],
      where: where,
      whereArgs: args,
      orderBy: 'created_at_ms DESC',
    );
    final valueRows = await db.query(
      'cc_source_value_links',
      columns: const <String>['source_type', 'source_id', 'value_label', 'created_at_ms'],
      where: where,
      whereArgs: args,
      orderBy: 'created_at_ms DESC',
    );
    final counts = <String, int>{};
    final latestAction = <String, String>{};
    final latestAt = <String, int>{};
    final valueLabels = <String, Set<String>>{};
    for (final row in valueRows) {
      final key = '${row['source_type'] ?? ''}|${row['source_id'] ?? ''}';
      final label = (row['value_label'] ?? '').toString().trim();
      if (label.isNotEmpty) valueLabels.putIfAbsent(key, () => <String>{}).add(label);
    }
    for (final row in evidenceRows) {
      final key = '${row['source_type'] ?? ''}|${row['source_id'] ?? ''}';
      counts[key] = (counts[key] ?? 0) + 1;
      final created = _asInt(row['created_at_ms']);
      if (!latestAt.containsKey(key) || created > (latestAt[key] ?? 0)) {
        latestAt[key] = created;
        latestAction[key] = (row['completed_action'] ?? '').toString();
      }
      if ((valueLabels[key] ?? <String>{}).isEmpty) {
        for (final token in (row['value_link'] ?? '').toString().split(RegExp(r'[、，,;；|\n]+'))) {
          final cleaned = token.trim();
          if (cleaned.isEmpty || cleaned.length > 16) continue;
          if (cleaned.contains('：') || cleaned.contains(':')) continue;
          valueLabels.putIfAbsent(key, () => <String>{}).add(cleaned);
        }
      }
    }
    return <String, CcSourceEvidenceSummary>{
      for (final s in cleaned)
        '${s.sourceType}|${s.sourceId}': CcSourceEvidenceSummary(
          sourceType: s.sourceType,
          sourceId: s.sourceId,
          count: counts['${s.sourceType}|${s.sourceId}'] ?? 0,
          latestAction: latestAction['${s.sourceType}|${s.sourceId}'] ?? '',
          latestAtMs: latestAt['${s.sourceType}|${s.sourceId}'] ?? 0,
          values: (valueLabels['${s.sourceType}|${s.sourceId}'] ?? <String>{}).toList(growable: false),
        ),
    };
  }


  Future<List<CcReportActionLink>> reportActionLinks(String reportId, {int limit = 20}) async {
    final rid = reportId.trim();
    if (rid.isEmpty) return const <CcReportActionLink>[];
    final db = await _db;
    final rows = await db.query(
      'cc_report_action_links',
      where: 'report_id = ?',
      whereArgs: <Object?>[rid],
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
    return rows.map(_reportActionLinkFromRow).toList(growable: false);
  }

  Future<String> saveEffectivePattern({
    required CcEvidenceRecord evidence,
    String successReason = '',
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'pat_${now}_${evidence.evidenceId.hashCode.abs()}';
    await db.insert(
      'cc_effective_patterns',
      <String, Object?>{
        'pattern_id': id,
        'evidence_id': evidence.evidenceId,
        'value_labels': evidence.valueLink,
        'old_story': evidence.oldStory,
        'new_story': evidence.newStory,
        'action_template': evidence.completedAction.trim().isEmpty ? evidence.plannedAction : evidence.completedAction,
        'success_reason': successReason.trim().isEmpty ? evidence.userReflection : successReason.trim(),
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await saveActionTraceLink(
      fromType: 'evidence',
      fromId: evidence.evidenceId,
      toType: 'effective_pattern',
      toId: id,
      relationType: 'marked_effective',
    );
    return id;
  }

  Future<List<CcEffectivePatternRecord>> recentEffectivePatterns({int limit = 20}) async {
    final db = await _db;
    final rows = await db.query('cc_effective_patterns', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(_effectivePatternFromRow).toList(growable: false);
  }

  Future<String> saveActionTraceLink({
    required String fromType,
    required String fromId,
    required String toType,
    required String toId,
    String relationType = '',
  }) async {
    final ft = fromType.trim();
    final fid = fromId.trim();
    final tt = toType.trim();
    final tid = toId.trim();
    if (ft.isEmpty || fid.isEmpty || tt.isEmpty || tid.isEmpty) return '';
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'atl_${now}_${(ft + fid + tt + tid + relationType).hashCode.abs()}';
    await db.insert(
      'cc_action_trace_links',
      <String, Object?>{
        'link_id': id,
        'from_type': ft,
        'from_id': fid,
        'to_type': tt,
        'to_id': tid,
        'relation_type': relationType.trim(),
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<List<CcActionTraceLink>> traceLinksFor({
    required String type,
    required String id,
    int limit = 40,
  }) async {
    final t = type.trim();
    final v = id.trim();
    if (t.isEmpty || v.isEmpty) return const <CcActionTraceLink>[];
    final db = await _db;
    final rows = await db.query(
      'cc_action_trace_links',
      where: '(from_type = ? AND from_id = ?) OR (to_type = ? AND to_id = ?)',
      whereArgs: <Object?>[t, v, t, v],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(_actionTraceLinkFromRow).toList(growable: false);
  }

  Future<void> updateValueRelationInsightLink({
    required String insightId,
    String linkedSessionId = '',
    String linkedEvidenceId = '',
  }) async {
    final id = insightId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    await db.update(
      'cc_value_relation_insights',
      <String, Object?>{
        if (linkedSessionId.trim().isNotEmpty) 'linked_session_id': linkedSessionId.trim(),
        if (linkedEvidenceId.trim().isNotEmpty) 'linked_evidence_id': linkedEvidenceId.trim(),
      },
      where: 'insight_id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<String> saveTriggerSuggestion({
    required String sourceType,
    required String sourceId,
    required String triggerType,
    required String message,
    String recommendedTab = '',
    int severity = 0,
  }) async {
    final type = sourceType.trim();
    final id = sourceId.trim();
    final trigger = triggerType.trim().isEmpty ? 'sourcebook_hint' : triggerType.trim();
    if (type.isEmpty || id.isEmpty || message.trim().isEmpty) return '';
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query(
      'cc_trigger_suggestions',
      where: 'source_type = ? AND source_id = ? AND trigger_type = ? AND status = ?',
      whereArgs: <Object?>[type, id, trigger, 'active'],
      orderBy: 'updated_at_ms DESC, created_at_ms DESC',
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final existingId = (existing.first['suggestion_id'] ?? '').toString();
      await db.update('cc_trigger_suggestions', <String, Object?>{
        'message': message.trim(),
        'recommended_tab': recommendedTab.trim(),
        'severity': severity,
        'updated_at_ms': now,
      }, where: 'suggestion_id = ?', whereArgs: <Object?>[existingId]);
      return existingId;
    }
    final suggestionId = 'trg_${now}_${(type + id + trigger).hashCode.abs()}';
    await db.insert(
      'cc_trigger_suggestions',
      <String, Object?>{
        'suggestion_id': suggestionId,
        'source_type': type,
        'source_id': id,
        'trigger_type': trigger,
        'message': message.trim(),
        'recommended_tab': recommendedTab.trim(),
        'severity': severity,
        'status': 'active',
        'created_at_ms': now,
        'updated_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return suggestionId;
  }

  Future<void> updateTriggerSuggestionStatus({required String suggestionId, required String status}) async {
    final id = suggestionId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    await db.update('cc_trigger_suggestions', <String, Object?>{
      'status': status.trim().isEmpty ? 'resolved' : status.trim(),
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
    }, where: 'suggestion_id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<Map<String, dynamic>>> allSourcebookCaseDetails({int limit = 200, String stage = ''}) async {
    final db = await _db;
    final rows = await db.query(
      'cc_sourcebook_cases',
      where: stage.trim().isEmpty ? null : 'current_stage = ?',
      whereArgs: stage.trim().isEmpty ? null : <Object?>[stage.trim()],
      orderBy: 'updated_at_ms DESC, created_at_ms DESC',
      limit: limit,
    );
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final sid = (row['session_id'] ?? '').toString();
      if (sid.trim().isEmpty) continue;
      final detail = await sourcebookCaseDetail(sid);
      if (detail.isNotEmpty) result.add(detail);
    }
    return result;
  }


  Future<String> saveResolutionMethodUsage({
    required String methodId,
    String methodTitle = '',
    String sessionId = '',
    String caseId = '',
    String sourceType = '',
    String sourceId = '',
    String selectedReason = '',
    String enteredSceneKey = '',
    String todoStepId = '',
    String evidenceId = '',
    String contractId = '',
    String methodWorkflowId = '',
    String dissonanceType = '',
    String sourcebookSupportLevel = '',
    String status = 'selected',
  }) async {
    final mid = methodId.trim();
    if (mid.isEmpty) return '';
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final workflowId = methodWorkflowId.trim().isEmpty ? 'mw_${now}_${(mid + sessionId + sourceType + sourceId + enteredSceneKey).hashCode.abs()}' : methodWorkflowId.trim();
    final usageId = 'musage_${now}_${(mid + sessionId + sourceType + sourceId + enteredSceneKey + workflowId).hashCode.abs()}';
    await db.insert('cc_dissonance_resolution_method_usages', <String, Object?>{
      'usage_id': usageId,
      'method_id': mid,
      'method_title': methodTitle.trim(),
      'session_id': sessionId.trim(),
      'case_id': caseId.trim(),
      'source_type': sourceType.trim(),
      'source_id': sourceId.trim(),
      'selected_reason': selectedReason.trim(),
      'entered_scene_key': enteredSceneKey.trim(),
      'todo_step_id': todoStepId.trim(),
      'evidence_id': evidenceId.trim(),
      'contract_id': contractId.trim(),
      'method_workflow_id': workflowId,
      'dissonance_type': dissonanceType.trim(),
      'sourcebook_support_level': sourcebookSupportLevel.trim(),
      'status': status.trim().isEmpty ? 'selected' : status.trim(),
      'created_at_ms': now,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await saveActionTraceLink(fromType: 'cc_resolution_method', fromId: mid, toType: 'cc_resolution_method_usage', toId: usageId, relationType: 'method_usage_created');
    if (sessionId.trim().isNotEmpty) {
      await saveActionTraceLink(fromType: 'cc_resolution_method_usage', fromId: usageId, toType: 'cc_session', toId: sessionId.trim(), relationType: 'method_used_for_session');
    }
    if (todoStepId.trim().isNotEmpty) {
      await saveActionTraceLink(fromType: 'cc_resolution_method_usage', fromId: usageId, toType: 'todo_goal_step', toId: todoStepId.trim(), relationType: 'method_written_to_todo');
    }
    if (evidenceId.trim().isNotEmpty) {
      await saveActionTraceLink(fromType: 'cc_resolution_method_usage', fromId: usageId, toType: 'evidence', toId: evidenceId.trim(), relationType: 'method_generated_evidence');
    }
    return usageId;
  }

  Future<void> updateResolutionMethodUsage({
    required String usageId,
    String sessionId = '',
    String caseId = '',
    String todoStepId = '',
    String evidenceId = '',
    String contractId = '',
    String methodWorkflowId = '',
    String dissonanceType = '',
    String sourcebookSupportLevel = '',
    String status = '',
    String reviewText = '',
    int? effectScore,
    bool? reducedDissonance,
    bool? producedEvidence,
    String riskNote = '',
    String nextUseSuggestion = '',
  }) async {
    final id = usageId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    final values = <String, Object?>{
      if (sessionId.trim().isNotEmpty) 'session_id': sessionId.trim(),
      if (caseId.trim().isNotEmpty) 'case_id': caseId.trim(),
      if (todoStepId.trim().isNotEmpty) 'todo_step_id': todoStepId.trim(),
      if (evidenceId.trim().isNotEmpty) 'evidence_id': evidenceId.trim(),
      if (contractId.trim().isNotEmpty) 'contract_id': contractId.trim(),
      if (methodWorkflowId.trim().isNotEmpty) 'method_workflow_id': methodWorkflowId.trim(),
      if (dissonanceType.trim().isNotEmpty) 'dissonance_type': dissonanceType.trim(),
      if (sourcebookSupportLevel.trim().isNotEmpty) 'sourcebook_support_level': sourcebookSupportLevel.trim(),
      if (status.trim().isNotEmpty) 'status': status.trim(),
      if (reviewText.trim().isNotEmpty) 'review_text': reviewText.trim(),
      if (effectScore != null) 'effect_score': effectScore.clamp(0, 10),
      if (reducedDissonance != null) 'reduced_dissonance': reducedDissonance ? 1 : 0,
      if (producedEvidence != null) 'produced_evidence': producedEvidence ? 1 : 0,
      if (riskNote.trim().isNotEmpty) 'risk_note': riskNote.trim(),
      if (nextUseSuggestion.trim().isNotEmpty) 'next_use_suggestion': nextUseSuggestion.trim(),
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
    };
    if (values.length <= 1) return;
    await db.update('cc_dissonance_resolution_method_usages', values, where: 'usage_id = ?', whereArgs: <Object?>[id]);
    if (todoStepId.trim().isNotEmpty) {
      await saveActionTraceLink(fromType: 'cc_resolution_method_usage', fromId: id, toType: 'todo_goal_step', toId: todoStepId.trim(), relationType: 'method_written_to_todo');
    }
    if (evidenceId.trim().isNotEmpty) {
      await saveActionTraceLink(fromType: 'cc_resolution_method_usage', fromId: id, toType: 'evidence', toId: evidenceId.trim(), relationType: 'method_generated_evidence');
    }
    if (contractId.trim().isNotEmpty) {
      await saveActionTraceLink(fromType: 'cc_resolution_method_usage', fromId: id, toType: 'cc_commitment_action_contract', toId: contractId.trim(), relationType: 'method_created_contract');
    }
  }

  Future<List<Map<String, dynamic>>> recentResolutionMethodUsages({int limit = 30, String methodId = '', String status = ''}) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (methodId.trim().isNotEmpty) {
      where.add('method_id = ?');
      args.add(methodId.trim());
    }
    if (status.trim().isNotEmpty) {
      where.add('status = ?');
      args.add(status.trim());
    }
    final rows = await db.query(
      'cc_dissonance_resolution_method_usages',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'updated_at_ms DESC, created_at_ms DESC',
      limit: limit,
    );
    return rows.map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  Future<void> createSourcebookContractFromMethod({
    required String methodId,
    required String methodTitle,
    required String minimalAction,
    String sessionId = '',
    String caseId = '',
    String coreValue = '',
    String currentBehavior = '',
    String completionStandard = '',
    String fallbackPlan = '',
    String reflectionQuestions = '',
    String usageId = '',
  }) async {
    final action = minimalAction.trim();
    if (action.isEmpty) return;
    final sid = sessionId.trim().isEmpty ? 'method_${DateTime.now().millisecondsSinceEpoch}_${methodId.trim().hashCode.abs()}' : sessionId.trim();
    final cid = caseId.trim().isEmpty ? 'case_$sid' : caseId.trim();
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('cc_sourcebook_cases', <String, Object?>{
      'case_id': cid,
      'session_id': sid,
      'event_summary': methodTitle.trim(),
      'current_stage': 'action_contract',
      'user_confirmation': 'method_selected',
      'created_at_ms': now,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final contractId = 'contract_$sid';
    await db.insert('cc_commitment_action_contracts', <String, Object?>{
      'contract_id': contractId,
      'session_id': sid,
      'case_id': cid,
      'core_value': coreValue.trim(),
      'current_inconsistent_behavior': currentBehavior.trim(),
      'minimal_repair_action': action,
      'action_time': '',
      'action_place': '',
      'duration_minutes': 10,
      'completion_standard': completionStandard.trim().isEmpty ? '完成这个最小行动，并记录现实反馈。' : completionStandard.trim(),
      'obstacle': '',
      'fallback_plan': fallbackPlan.trim().isEmpty ? '如果阻力太大，就降级为 2 分钟版本。' : fallbackPlan.trim(),
      'reflection_questions': reflectionQuestions.trim().isEmpty ? '这个方法是否让价值、事实与行动更接近？它是否产生了现实证据？' : reflectionQuestions.trim(),
      'status': 'method_selected',
      'created_at_ms': now,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (usageId.trim().isNotEmpty) {
      await updateResolutionMethodUsage(usageId: usageId.trim(), sessionId: sid, caseId: cid, contractId: contractId, status: 'contract_created');
      await saveActionTraceLink(fromType: 'cc_resolution_method_usage', fromId: usageId.trim(), toType: 'cc_sourcebook_case', toId: cid, relationType: 'method_created_case_contract');
    }
    await saveActionTraceLink(fromType: 'cc_resolution_method', fromId: methodId.trim(), toType: 'cc_sourcebook_case', toId: cid, relationType: 'method_created_case_contract');
  }


  Future<String> createSourcebookCaseDraft({
    String eventSummary = '',
    String sourceType = '',
    String sourceId = '',
    String initialStage = 'input',
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final seed = '${eventSummary.trim()}_${sourceType.trim()}_${sourceId.trim()}_$now';
    final sid = 'sourcebook_draft_${now}_${seed.hashCode.abs()}';
    final cid = 'case_$sid';
    await db.insert('cc_sessions', <String, Object?>{
      'session_id': sid,
      'scene_type': 'sourcebook_case_draft',
      'user_goal': eventSummary.trim(),
      'user_context': eventSummary.trim(),
      'user_values': '',
      'result_json': '{}',
      'provider': 'local',
      'model_label': 'sourcebook_case_draft',
      'status': 'draft',
      'source_type': sourceType.trim(),
      'source_id': sourceId.trim(),
      'reward_source': '',
      'origin_scene': 'sourcebook_case_wizard',
      'created_at_ms': now,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('cc_sourcebook_cases', <String, Object?>{
      'case_id': cid,
      'session_id': sid,
      'event_summary': eventSummary.trim().isEmpty ? '未命名认知失调案例' : eventSummary.trim(),
      'current_stage': initialStage.trim().isEmpty ? 'input' : initialStage.trim(),
      'user_confirmation': 'draft',
      'created_at_ms': now,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await saveActionTraceLink(fromType: 'cc_sourcebook_case', fromId: cid, toType: 'cc_session', toId: sid, relationType: 'case_draft_created');
    return sid;
  }

  Future<String> saveTrueSelfLink({
    String ccSessionId = '',
    String ccEvidenceId = '',
    String shameEventId = '',
    String shameEvidenceId = '',
    String linkType = '',
    String truePrideSentence = '',
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'tsl_${now}_${(ccSessionId + ccEvidenceId + shameEventId + shameEvidenceId + linkType).hashCode.abs()}';
    await db.insert(
      'cc_true_self_links',
      <String, Object?>{
        'link_id': id,
        'cc_session_id': ccSessionId.trim(),
        'cc_evidence_id': ccEvidenceId.trim(),
        'shame_event_id': shameEventId.trim(),
        'shame_evidence_id': shameEvidenceId.trim(),
        'link_type': linkType.trim(),
        'true_pride_sentence': truePrideSentence.trim(),
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (ccEvidenceId.trim().isNotEmpty && shameEvidenceId.trim().isNotEmpty) {
      await saveActionTraceLink(
        fromType: 'evidence',
        fromId: ccEvidenceId.trim(),
        toType: 'shame_evidence',
        toId: shameEvidenceId.trim(),
        relationType: linkType.trim().isEmpty ? 'true_self_bridge' : linkType.trim(),
      );
    }
    return id;
  }

  Future<List<CcVerificationTask>> recentVerificationTasks({int limit = 20, String status = ''}) async {
    final db = await _db;
    final rows = await db.query(
      'cc_verification_tasks',
      where: status.trim().isEmpty ? null : 'status = ?',
      whereArgs: status.trim().isEmpty ? null : <Object?>[status.trim()],
      orderBy: 'due_at_ms ASC, created_at_ms DESC',
      limit: limit,
    );
    return rows.map(_verificationTaskFromRow).toList(growable: false);
  }

  Future<void> completeVerificationTask({
    required String taskId,
    required String resultNote,
    String status = 'verified',
  }) async {
    final id = taskId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    final cleanStatus = status.trim().isEmpty ? 'verified' : status.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'cc_verification_tasks',
      <String, Object?>{
        'status': cleanStatus,
        'result_note': resultNote.trim(),
        'verified_at_ms': now,
      },
      where: 'task_id = ?',
      whereArgs: <Object?>[id],
    );
    final taskRows = await db.query('cc_verification_tasks', where: 'task_id = ?', whereArgs: <Object?>[id], limit: 1);
    if (taskRows.isNotEmpty) {
      final sid = (taskRows.first['session_id'] ?? '').toString().trim();
      if (sid.isNotEmpty) {
        await db.update(
          'cc_sessions',
          <String, Object?>{'status': cleanStatus == 'verified' ? 'verification_verified' : 'verification_$cleanStatus'},
          where: 'session_id = ?',
          whereArgs: <Object?>[sid],
        );
        await db.insert(
          'cc_action_trace_links',
          <String, Object?>{
            'link_id': 'trace_${now}_${id.hashCode.abs()}',
            'from_type': 'verification_task',
            'from_id': id,
            'to_type': 'cc_session',
            'to_id': sid,
            'relation_type': cleanStatus == 'verified' ? 'verification_confirmed_session' : 'verification_updated_session',
            'created_at_ms': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  String _reductionModeLabel(String mode) {
    switch (mode.trim()) {
      case 'action_repair':
        return '行动型修复';
      case 'responsibility_repair':
        return '责任修复';
      case 'relationship_repair':
        return '关系修复';
      case 'value_alignment':
        return '价值对齐';
      case 'avoidance_risk':
        return '仍有逃避风险';
      case 'explanation_only':
      default:
        return '解释型缓解';
    }
  }

  Future<Map<String, dynamic>> modernPatternProfile({int limit = 300}) async {
    final db = await _db;
    Future<int> count(String table) async {
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM ' + table);
      return rows.isEmpty ? 0 : _asInt(rows.first['c']);
    }

    final sessions = await count('cc_sessions');
    final events = await count('cc_dissonance_events');
    final evidence = await count('cc_evidence_records');
    final trueSelfLinks = await count('cc_true_self_links');

    final sceneRows = await db.rawQuery('SELECT scene_type, COUNT(*) AS c FROM cc_sessions GROUP BY scene_type ORDER BY c DESC LIMIT 12');
    final sceneCounts = <String, int>{
      for (final row in sceneRows) (row['scene_type'] ?? '').toString(): _asInt(row['c']),
    }..removeWhere((key, value) => key.trim().isEmpty);

    final ratRows = await db.query('cc_rationalization_flags', columns: const <String>['rationalization_types'], limit: limit, orderBy: 'created_at_ms DESC');
    final rationalizationCounts = <String, int>{};
    for (final row in ratRows) {
      for (final raw in (row['rationalization_types'] ?? '').toString().split(RegExp(r'[、，,;；|/\n]+'))) {
        final item = raw.trim();
        if (item.isEmpty || item.length > 30) continue;
        rationalizationCounts[item] = (rationalizationCounts[item] ?? 0) + 1;
      }
    }

    final standardsRows = await db.query('cc_self_standards', limit: limit, orderBy: 'created_at_ms DESC');
    final standardCounts = <String, int>{
      '个人标准': 0,
      '规范/道德标准': 0,
      '家庭/群体/文化标准': 0,
      '理想自我标准': 0,
      '已调整标准': 0,
    };
    for (final row in standardsRows) {
      if ((row['personal_standard'] ?? '').toString().trim().isNotEmpty) standardCounts['个人标准'] = standardCounts['个人标准']! + 1;
      if ((row['normative_standard'] ?? '').toString().trim().isNotEmpty) standardCounts['规范/道德标准'] = standardCounts['规范/道德标准']! + 1;
      if ((row['family_or_group_standard'] ?? '').toString().trim().isNotEmpty) standardCounts['家庭/群体/文化标准'] = standardCounts['家庭/群体/文化标准']! + 1;
      if ((row['ideal_self_standard'] ?? '').toString().trim().isNotEmpty) standardCounts['理想自我标准'] = standardCounts['理想自我标准']! + 1;
      if ((row['adjusted_standard'] ?? '').toString().trim().isNotEmpty) standardCounts['已调整标准'] = standardCounts['已调整标准']! + 1;
    }
    standardCounts.removeWhere((key, value) => value <= 0);

    final triggerRows = await db.query('cc_trigger_conditions', limit: limit, orderBy: 'created_at_ms DESC');
    var overBlame = 0;
    var avoidance = 0;
    var responsibility = 0;
    var repairable = 0;
    for (final row in triggerRows) {
      if ((row['over_blame_risk'] ?? '').toString().trim().isNotEmpty) overBlame++;
      if ((row['avoidance_risk'] ?? '').toString().trim().isNotEmpty) avoidance++;
      if ((row['responsibility_feeling'] ?? '').toString().trim().isNotEmpty || (row['user_responsibility'] ?? '').toString().trim().isNotEmpty) responsibility++;
      if ((row['repairability'] ?? '').toString().trim().isNotEmpty || (row['repairable_part'] ?? '').toString().trim().isNotEmpty) repairable++;
    }

    final repairedRows = await db.rawQuery("""
      SELECT COUNT(DISTINCT session_id) AS c
      FROM cc_evidence_records
      WHERE session_id IS NOT NULL AND TRIM(session_id) != ''
    """);
    final repairedSessions = repairedRows.isEmpty ? 0 : _asInt(repairedRows.first['c']);
    final actionRepairRatio = sessions <= 0 ? 0 : ((repairedSessions / sessions) * 100).round().clamp(0, 100).toInt();

    Future<Map<String, int>> windowStats(int days) async {
      final start = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
      final sessionRows = await db.rawQuery('SELECT COUNT(*) AS c FROM cc_sessions WHERE created_at_ms >= ?', <Object?>[start]);
      final evidenceRows = await db.rawQuery('SELECT COUNT(*) AS c FROM cc_evidence_records WHERE created_at_ms >= ?', <Object?>[start]);
      final repairedRows = await db.rawQuery(
        "SELECT COUNT(DISTINCT session_id) AS c FROM cc_evidence_records WHERE created_at_ms >= ? AND session_id IS NOT NULL AND TRIM(session_id) != ''",
        <Object?>[start],
      );
      final tsRows = await db.rawQuery('SELECT COUNT(*) AS c FROM cc_true_self_links WHERE created_at_ms >= ?', <Object?>[start]);
      final s = sessionRows.isEmpty ? 0 : _asInt(sessionRows.first['c']);
      final r = repairedRows.isEmpty ? 0 : _asInt(repairedRows.first['c']);
      return <String, int>{
        'sessions': s,
        'evidence': evidenceRows.isEmpty ? 0 : _asInt(evidenceRows.first['c']),
        'repairedSessions': r,
        'actionRepairRatio': s <= 0 ? 0 : ((r / s) * 100).round().clamp(0, 100).toInt(),
        'trueSelfLinks': tsRows.isEmpty ? 0 : _asInt(tsRows.first['c']),
      };
    }

    final last7 = await windowStats(7);
    final last30 = await windowStats(30);

    final reductionModeRows = await db.rawQuery(
      """
      SELECT dissonance_reduction_mode, COUNT(*) AS c
      FROM cc_evidence_records
      WHERE dissonance_reduction_mode IS NOT NULL
        AND TRIM(dissonance_reduction_mode) != ''
      GROUP BY dissonance_reduction_mode
      ORDER BY c DESC
      LIMIT 12
      """,
    );
    final reductionModeCounts = <String, int>{
      for (final row in reductionModeRows)
        (row['dissonance_reduction_mode'] ?? '').toString(): _asInt(row['c']),
    }..removeWhere((key, value) => key.trim().isEmpty || value <= 0);
    if (reductionModeCounts.isEmpty) {
      final fallbackReductionRows = await db.rawQuery(
        """
        SELECT dissonance_reduction_mode, COUNT(*) AS c
        FROM cc_dissonance_events
        WHERE dissonance_reduction_mode IS NOT NULL
          AND TRIM(dissonance_reduction_mode) != ''
        GROUP BY dissonance_reduction_mode
        ORDER BY c DESC
        LIMIT 12
        """,
      );
      for (final row in fallbackReductionRows) {
        final key = (row['dissonance_reduction_mode'] ?? '').toString().trim();
        if (key.isNotEmpty) reductionModeCounts[key] = _asInt(row['c']);
      }
    }

    final verificationRows = await db.rawQuery(
      """
      SELECT status, COUNT(*) AS c
      FROM cc_verification_tasks
      GROUP BY status
      ORDER BY c DESC
      LIMIT 12
      """,
    );
    final verificationCounts = <String, int>{
      for (final row in verificationRows)
        ((row['status'] ?? '').toString().trim().isEmpty ? 'open' : (row['status'] ?? '').toString().trim()): _asInt(row['c']),
    }..removeWhere((key, value) => value <= 0);
    final overdueRows = await db.rawQuery(
      """
      SELECT COUNT(*) AS c
      FROM cc_verification_tasks
      WHERE status = 'open'
        AND due_at_ms > 0
        AND due_at_ms < ?
      """,
      <Object?>[DateTime.now().millisecondsSinceEpoch],
    );
    final overdueCount = overdueRows.isEmpty ? 0 : _asInt(overdueRows.first['c']);
    if (overdueCount > 0) verificationCounts['overdue'] = overdueCount;

    final dissonanceTypeRows = await db.rawQuery(
      """
      SELECT type_label, COUNT(*) AS c
      FROM cc_dissonance_type_items
      WHERE type_label IS NOT NULL AND TRIM(type_label) != ''
      GROUP BY type_label
      ORDER BY c DESC
      LIMIT 12
      """,
    );
    final dissonanceTypeCounts = <String, int>{
      for (final row in dissonanceTypeRows)
        (row['type_label'] ?? '').toString(): _asInt(row['c']),
    }..removeWhere((key, value) => key.trim().isEmpty || value <= 0);

    final intensityRows = await db.rawQuery(
      """
      SELECT level, COUNT(*) AS c
      FROM cc_dissonance_intensity_scores
      WHERE level IS NOT NULL AND TRIM(level) != ''
      GROUP BY level
      ORDER BY c DESC
      LIMIT 8
      """,
    );
    final intensityLevelCounts = <String, int>{
      for (final row in intensityRows)
        (row['level'] ?? '').toString(): _asInt(row['c']),
    }..removeWhere((key, value) => key.trim().isEmpty || value <= 0);

    final tempRows = await db.rawQuery(
      """
      SELECT phase, COUNT(*) AS c, AVG(discomfort_score) AS avg_discomfort, AVG(avoidance_urge_score) AS avg_avoidance, AVG(clarity_score) AS avg_clarity
      FROM cc_dissonance_temperature_logs
      GROUP BY phase
      """,
    );
    final temperatureCounts = <String, int>{
      for (final row in tempRows)
        (row['phase'] ?? '').toString(): _asInt(row['c']),
    }..removeWhere((key, value) => key.trim().isEmpty || value <= 0);

    final tempDeltaRows = await db.rawQuery(
      """
      SELECT b.evidence_id,
             b.discomfort_score AS before_discomfort,
             a.discomfort_score AS after_discomfort,
             b.avoidance_urge_score AS before_avoidance,
             a.avoidance_urge_score AS after_avoidance,
             b.action_willingness_score AS before_willing,
             a.action_willingness_score AS after_willing
      FROM cc_dissonance_temperature_logs b
      JOIN cc_dissonance_temperature_logs a ON a.evidence_id = b.evidence_id
      WHERE b.phase = 'before' AND a.phase = 'after' AND TRIM(b.evidence_id) != ''
      ORDER BY a.created_at_ms DESC
      LIMIT 300
      """,
    );
    var discomfortDrop = 0;
    var avoidanceDrop = 0;
    var willingnessRise = 0;
    for (final row in tempDeltaRows) {
      discomfortDrop += _asInt(row['before_discomfort']) - _asInt(row['after_discomfort']);
      avoidanceDrop += _asInt(row['before_avoidance']) - _asInt(row['after_avoidance']);
      willingnessRise += _asInt(row['after_willing']) - _asInt(row['before_willing']);
    }
    final tempPairs = tempDeltaRows.length;
    final temperatureDelta = <String, int>{
      if (tempPairs > 0) '平均不适下降': (discomfortDrop / tempPairs).round(),
      if (tempPairs > 0) '平均逃避下降': (avoidanceDrop / tempPairs).round(),
      if (tempPairs > 0) '平均意愿上升': (willingnessRise / tempPairs).round(),
    };

    Future<Map<String, int>> groupedCount(String table, String column, {int maxItems = 8}) async {
      final rows = await db.rawQuery('''
        SELECT $column AS k, COUNT(*) AS c
        FROM $table
        WHERE $column IS NOT NULL AND TRIM($column) != ''
        GROUP BY $column
        ORDER BY c DESC
        LIMIT $maxItems
      ''');
      final result = <String, int>{
        for (final row in rows) (row['k'] ?? '').toString(): _asInt(row['c']),
      }..removeWhere((key, value) => key.trim().isEmpty || value <= 0);
      return result;
    }

    final informationResultCounts = await groupedCount('cc_information_contact_results', 'result_type');
    final temperatureRepairModeCounts = await groupedCount('cc_temperature_review_items', 'repair_mode');
    final topOldIdentityCounts = await groupedCount('cc_identity_transition_records', 'old_identity');
    final topNewIdentityCounts = await groupedCount('cc_identity_transition_records', 'new_identity');
    final identityTransitionCount = await count('cc_identity_transition_records');
    final informationRepairActionRows = await db.rawQuery("SELECT COUNT(*) AS c FROM cc_information_contact_results WHERE repair_action IS NOT NULL AND TRIM(repair_action) != ''");
    final informationRepairActionCount = informationRepairActionRows.isEmpty ? 0 : _asInt(informationRepairActionRows.first['c']);

    final selfIntegrityCount = await count('cc_self_integrity_cards');
    final reframeCount = await count('cc_consistency_reframe_items');
    final dailyReviewCount = await count('cc_daily_consistency_reviews');

    Map<String, int> splitCountRows(List<Map<String, Object?>> rows, String column, {int maxItems = 10}) {
      final counts = <String, int>{};
      for (final row in rows) {
        for (final raw in (row[column] ?? '').toString().split(RegExp(r'[、，,;；|/\n]+'))) {
          final item = raw.trim();
          if (item.isEmpty || item.length > 42) continue;
          counts[item] = (counts[item] ?? 0) + 1;
        }
      }
      final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return <String, int>{for (final e in entries.take(maxItems)) e.key: e.value};
    }
    final sourcebookCaseCount = await count('cc_sourcebook_cases');
    final valueLayerRows = await db.query('cc_value_layer_records', limit: limit, orderBy: 'created_at_ms DESC');
    final sourcebookCoreValueCounts = splitCountRows(valueLayerRows, 'core_values');
    final sourcebookIdentityBeliefCounts = splitCountRows(valueLayerRows, 'identity_beliefs');
    final sourcebookPeripheralExplanationCounts = splitCountRows(valueLayerRows, 'peripheral_explanations');
    final sourcebookChoiceCounts = await groupedCount('cc_user_choice_records', 'label', maxItems: 8);
    final sourcebookChoiceSelectedRows = await db.rawQuery("""
      SELECT label AS k, COUNT(*) AS c
      FROM cc_user_choice_records
      WHERE selected = 1 AND label IS NOT NULL AND TRIM(label) != ''
      GROUP BY label
      ORDER BY c DESC
      LIMIT 8
    """);
    final sourcebookSelectedChoiceCounts = <String, int>{
      for (final row in sourcebookChoiceSelectedRows) (row['k'] ?? '').toString(): _asInt(row['c']),
    }..removeWhere((key, value) => key.trim().isEmpty || value <= 0);
    final sourcebookContractStatusCounts = await groupedCount('cc_commitment_action_contracts', 'status', maxItems: 8);
    final sourcebookCounterOldBeliefCounts = await groupedCount('cc_counter_attitudinal_experiments', 'old_belief', maxItems: 8);
    final sourcebookInterpersonalImbalanceCounts = await groupedCount('cc_interpersonal_balance_records', 'imbalance_point', maxItems: 8);
    final sourcebookProtectedSelfCounts = await groupedCount('cc_protected_self_images', 'image', maxItems: 8);
    final sourcebookDefensePatternCounts = await groupedCount('cc_defense_pattern_records', 'pattern_type', maxItems: 8);
    final sourcebookTriggerStatusCounts = await groupedCount('cc_trigger_suggestions', 'status', maxItems: 8);
    final resolutionMethodCounts = await groupedCount('cc_dissonance_resolution_method_usages', 'method_title', maxItems: 10);
    final resolutionMethodStatusCounts = await groupedCount('cc_dissonance_resolution_method_usages', 'status', maxItems: 8);
    final resolutionMethodTodoRows = await db.rawQuery("SELECT COUNT(*) AS c FROM cc_dissonance_resolution_method_usages WHERE todo_step_id IS NOT NULL AND TRIM(todo_step_id) != ''");
    final resolutionMethodEvidenceRows = await db.rawQuery("SELECT COUNT(*) AS c FROM cc_dissonance_resolution_method_usages WHERE evidence_id IS NOT NULL AND TRIM(evidence_id) != ''");
    final resolutionMethodEffectRows = await db.rawQuery("SELECT AVG(effect_score) AS avg_score FROM cc_dissonance_resolution_method_usages WHERE effect_score > 0");
    final resolutionMethodContractRows = await db.rawQuery("SELECT COUNT(*) AS c FROM cc_dissonance_resolution_method_usages WHERE contract_id IS NOT NULL AND TRIM(contract_id) != ''");
    final resolutionMethodDissonanceCounts = await groupedCount('cc_dissonance_resolution_method_usages', 'dissonance_type', maxItems: 8);
    final resolutionMethodSupportCounts = await groupedCount('cc_dissonance_resolution_method_usages', 'sourcebook_support_level', maxItems: 8);
    final resolutionMethodTodoCount = resolutionMethodTodoRows.isEmpty ? 0 : _asInt(resolutionMethodTodoRows.first['c']);
    final resolutionMethodEvidenceCount = resolutionMethodEvidenceRows.isEmpty ? 0 : _asInt(resolutionMethodEvidenceRows.first['c']);
    final resolutionMethodContractCount = resolutionMethodContractRows.isEmpty ? 0 : _asInt(resolutionMethodContractRows.first['c']);
    final resolutionMethodAverageEffect = resolutionMethodEffectRows.isEmpty ? 0 : (((resolutionMethodEffectRows.first['avg_score'] as num?) ?? 0).toDouble() * 10).round() / 10;

    return <String, dynamic>{
      'sessions': sessions,
      'events': events,
      'evidence': evidence,
      'trueSelfLinks': trueSelfLinks,
      'repairedSessions': repairedSessions,
      'actionRepairRatio': actionRepairRatio,
      'last7': last7,
      'last30': last30,
      'sceneCounts': sceneCounts,
      'rationalizationCounts': rationalizationCounts,
      'standardCounts': standardCounts,
      'reductionModeCounts': reductionModeCounts,
      'verificationCounts': verificationCounts,
      'dissonanceTypeCounts': dissonanceTypeCounts,
      'intensityLevelCounts': intensityLevelCounts,
      'temperatureCounts': temperatureCounts,
      'temperatureDelta': temperatureDelta,
      'selfIntegrityCount': selfIntegrityCount,
      'growthReframeCount': reframeCount,
      'dailyReviewCount': dailyReviewCount,
      'informationResultCounts': informationResultCounts,
      'identityTransitionCount': identityTransitionCount,
      'temperatureRepairModeCounts': temperatureRepairModeCounts,
      'topOldIdentityCounts': topOldIdentityCounts,
      'topNewIdentityCounts': topNewIdentityCounts,
      'informationRepairActionCount': informationRepairActionCount,
      'sourcebookCaseCount': sourcebookCaseCount,
      'sourcebookCoreValueCounts': sourcebookCoreValueCounts,
      'sourcebookIdentityBeliefCounts': sourcebookIdentityBeliefCounts,
      'sourcebookPeripheralExplanationCounts': sourcebookPeripheralExplanationCounts,
      'sourcebookChoiceCounts': sourcebookChoiceCounts,
      'sourcebookSelectedChoiceCounts': sourcebookSelectedChoiceCounts,
      'sourcebookContractStatusCounts': sourcebookContractStatusCounts,
      'sourcebookCounterOldBeliefCounts': sourcebookCounterOldBeliefCounts,
      'sourcebookInterpersonalImbalanceCounts': sourcebookInterpersonalImbalanceCounts,
      'sourcebookProtectedSelfCounts': sourcebookProtectedSelfCounts,
      'sourcebookDefensePatternCounts': sourcebookDefensePatternCounts,
      'sourcebookTriggerStatusCounts': sourcebookTriggerStatusCounts,
      'resolutionMethodCounts': resolutionMethodCounts,
      'resolutionMethodStatusCounts': resolutionMethodStatusCounts,
      'resolutionMethodTodoCount': resolutionMethodTodoCount,
      'resolutionMethodEvidenceCount': resolutionMethodEvidenceCount,
      'resolutionMethodContractCount': resolutionMethodContractCount,
      'resolutionMethodDissonanceCounts': resolutionMethodDissonanceCounts,
      'resolutionMethodSupportCounts': resolutionMethodSupportCounts,
      'resolutionMethodAverageEffect': resolutionMethodAverageEffect,
      'triggerCounts': <String, int>{
        '责任感/责任边界': responsibility,
        '可修复部分': repairable,
        '过度自责风险': overBlame,
        '逃避责任风险': avoidance,
      }..removeWhere((key, value) => value <= 0),
    };
  }


  Future<String> saveDailyConsistencyReview({
    String reviewId = '',
    required String dateLabel,
    String closestValueAction = '',
    String mainDissonance = '',
    String rationalizationUsed = '',
    String growthReframe = '',
    String repairActionDone = '',
    String tomorrowAction = '',
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = reviewId.trim().isNotEmpty ? reviewId.trim() : 'dr_${dateLabel.trim().hashCode.abs()}';
    await db.insert(
      'cc_daily_consistency_reviews',
      <String, Object?>{
        'review_id': id,
        'date_label': dateLabel.trim(),
        'closest_value_action': closestValueAction.trim(),
        'main_dissonance': mainDissonance.trim(),
        'rationalization_used': rationalizationUsed.trim(),
        'growth_reframe': growthReframe.trim(),
        'repair_action_done': repairActionDone.trim(),
        'tomorrow_action': tomorrowAction.trim(),
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<List<CcDailyConsistencyReview>> recentDailyConsistencyReviews({int limit = 14}) async {
    final db = await _db;
    final rows = await db.query('cc_daily_consistency_reviews', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(_dailyReviewFromRow).toList(growable: false);
  }


  Future<void> deleteDailyConsistencyReview(String reviewId) async {
    final id = reviewId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    await db.delete('cc_daily_consistency_reviews', where: 'review_id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<CcDissonanceTemperatureLog>> listDissonanceTemperatureLogs({
    int limit = 300,
    String evidenceId = '',
    String sessionId = '',
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (evidenceId.trim().isNotEmpty) {
      where.add('evidence_id = ?');
      args.add(evidenceId.trim());
    }
    if (sessionId.trim().isNotEmpty) {
      where.add('session_id = ?');
      args.add(sessionId.trim());
    }
    final rows = await db.query(
      'cc_dissonance_temperature_logs',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(_temperatureLogFromRow).toList(growable: false);
  }

  Future<Map<String, List<CcDissonanceTemperatureLog>>> temperatureLogsForEvidenceIds(Iterable<String> evidenceIds) async {
    final ids = evidenceIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return <String, List<CcDissonanceTemperatureLog>>{};
    final db = await _db;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT * FROM cc_dissonance_temperature_logs WHERE evidence_id IN ($placeholders) ORDER BY created_at_ms DESC',
      ids,
    );
    final result = <String, List<CcDissonanceTemperatureLog>>{};
    for (final row in rows) {
      final log = _temperatureLogFromRow(row);
      result.putIfAbsent(log.evidenceId, () => <CcDissonanceTemperatureLog>[]).add(log);
    }
    return result;
  }

  Future<Map<String, CcV18SessionDetails>> v18DetailsForSessionIds(Iterable<String> sessionIds) async {
    final ids = sessionIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return <String, CcV18SessionDetails>{};
    final db = await _db;
    final placeholders = List.filled(ids.length, '?').join(',');
    final typeRows = await db.rawQuery(
      'SELECT session_id, type_label FROM cc_dissonance_type_items WHERE session_id IN ($placeholders) ORDER BY created_at_ms DESC',
      ids,
    );
    final typeMap = <String, List<String>>{};
    for (final row in typeRows) {
      final sid = (row['session_id'] ?? '').toString();
      final label = (row['type_label'] ?? '').toString().trim();
      if (sid.isNotEmpty && label.isNotEmpty) typeMap.putIfAbsent(sid, () => <String>[]).add(label);
    }
    final intensityRows = await db.rawQuery(
      'SELECT * FROM cc_dissonance_intensity_scores WHERE session_id IN ($placeholders)',
      ids,
    );
    final intensityMap = <String, Map<String, Object?>>{};
    for (final row in intensityRows) {
      intensityMap[(row['session_id'] ?? '').toString()] = row;
    }
    final reframeRows = await db.rawQuery(
      'SELECT * FROM cc_consistency_reframe_items WHERE session_id IN ($placeholders)',
      ids,
    );
    final reframeMap = <String, Map<String, Object?>>{};
    for (final row in reframeRows) {
      reframeMap[(row['session_id'] ?? '').toString()] = row;
    }
    final integrityRows = await db.rawQuery(
      'SELECT * FROM cc_self_integrity_cards WHERE session_id IN ($placeholders)',
      ids,
    );
    final integrityMap = <String, Map<String, Object?>>{};
    for (final row in integrityRows) {
      integrityMap[(row['session_id'] ?? '').toString()] = row;
    }
    return <String, CcV18SessionDetails>{
      for (final sid in ids)
        sid: CcV18SessionDetails(
          sessionId: sid,
          dissonanceTypes: (typeMap[sid] ?? const <String>[]).toSet().toList(),
          intensityScore: _asInt(intensityMap[sid]?['total_score']),
          intensityLevel: (intensityMap[sid]?['level'] ?? '').toString(),
          intensitySources: (intensityMap[sid]?['main_sources'] ?? '').toString(),
          defensiveExplanation: (reframeMap[sid]?['defensive_explanation'] ?? '').toString(),
          shortTermProtection: (reframeMap[sid]?['short_term_protection'] ?? '').toString(),
          longTermCost: (reframeMap[sid]?['long_term_cost'] ?? '').toString(),
          growthExplanation: (reframeMap[sid]?['growth_explanation'] ?? '').toString(),
          responsiblePart: (reframeMap[sid]?['responsible_part'] ?? '').toString(),
          nextRepairAction: (reframeMap[sid]?['next_repair_action'] ?? '').toString(),
          selfAcknowledge: (integrityMap[sid]?['acknowledge_sentence'] ?? '').toString(),
          selfNotEqual: (integrityMap[sid]?['not_equal_sentence'] ?? '').toString(),
          selfStillValue: (integrityMap[sid]?['still_value_sentence'] ?? '').toString(),
          selfNextProof: (integrityMap[sid]?['next_proof_action'] ?? '').toString(),
        ),
    };
  }

  Future<List<CcValueConsistencySnapshot>> buildValueConsistencySnapshots({int limit = 1000}) async {
    final values = await listValueProfiles();
    if (values.isEmpty) return const <CcValueConsistencySnapshot>[];
    final db = await _db;
    final evidenceLinks = await listEvidenceValueLinks(limit: limit);
    final allEvidence = await recentEvidence(limit: limit);
    final evidenceById = <String, CcEvidenceRecord>{for (final e in allEvidence) e.evidenceId: e};
    final temps = await temperatureLogsForEvidenceIds(allEvidence.map((e) => e.evidenceId));
    final details = await v18DetailsForSessionIds(allEvidence.map((e) => e.sessionId));
    final verificationRowsForSnapshots = await db.query(
      'cc_verification_tasks',
      columns: const <String>['session_id', 'status'],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    final verificationBySession = <String, String>{};
    for (final row in verificationRowsForSnapshots) {
      final sid = (row['session_id'] ?? '').toString().trim();
      if (sid.isNotEmpty) verificationBySession.putIfAbsent(sid, () => (row['status'] ?? '').toString().trim());
    }
    final unrepairedRows = await db.rawQuery("""
      SELECT s.session_id, s.user_goal, s.user_context, s.created_at_ms, sv.value_id, sv.value_label
      FROM cc_sessions s
      JOIN cc_source_value_links sv ON sv.source_type = 'cc_session' AND sv.source_id = s.session_id
      LEFT JOIN cc_evidence_records e ON e.session_id = s.session_id
      WHERE e.evidence_id IS NULL
      ORDER BY s.created_at_ms DESC
      LIMIT ?
    """, <Object?>[limit]);
    final unrepairedByValue = <String, List<Map<String, Object?>>>{};
    for (final row in unrepairedRows) {
      final key = (row['value_id'] ?? '').toString();
      if (key.trim().isEmpty) continue;
      unrepairedByValue.putIfAbsent(key, () => <Map<String, Object?>>[]).add(row);
    }
    final unrepairedDetails = await v18DetailsForSessionIds(unrepairedRows.map((e) => (e['session_id'] ?? '').toString()));
    final snapshots = <CcValueConsistencySnapshot>[];
    for (final value in values) {
      final label = value.valueLabel.trim();
      if (label.isEmpty) continue;
      final linkedEvidenceIds = evidenceLinks.where((l) => l.valueId == value.valueId || l.valueLabel == label).map((l) => l.evidenceId).toSet();
      final matchedEvidence = <CcEvidenceRecord>[];
      for (final e in allEvidence) {
        final direct = linkedEvidenceIds.contains(e.evidenceId);
        final text = '${e.valueLink}\n${e.userGoal}\n${e.completedAction}\n${e.userReflection}\n${e.newStory}';
        final fuzzy = label.length >= 2 && text.contains(label);
        if (direct || fuzzy) matchedEvidence.add(e);
      }
      final sessionIds = matchedEvidence.map((e) => e.sessionId).where((sid) => sid.trim().isNotEmpty).toSet();
      var dissonanceCount = 0;
      var totalIntensity = 0;
      var intensityN = 0;
      final rationalizationCounts = <String, int>{};
      var latestDissonance = '';
      var latestRepair = '';
      var dropTotal = 0;
      var dropN = 0;
      final unrepairedSessionsForValue = unrepairedByValue[value.valueId] ?? const <Map<String, Object?>>[];
      for (final row in unrepairedSessionsForValue) {
        final sid = (row['session_id'] ?? '').toString();
        final detail = unrepairedDetails[sid];
        dissonanceCount++;
        latestDissonance = latestDissonance.isEmpty
            ? (detail != null && detail.dissonanceTypes.isNotEmpty ? detail.dissonanceTypes.join('、') : "未修复失调：${(row['user_goal'] ?? '').toString()}")
            : latestDissonance;
        if (detail != null && detail.intensityScore > 0) {
          totalIntensity += detail.intensityScore;
          intensityN++;
        }
        if (detail != null && detail.defensiveExplanation.trim().isNotEmpty) {
          final k = detail.defensiveExplanation.trim();
          rationalizationCounts[k] = (rationalizationCounts[k] ?? 0) + 1;
        }
      }
      for (final e in matchedEvidence) {
        final detail = details[e.sessionId];
        if (detail != null && (detail.dissonanceTypes.isNotEmpty || detail.intensityScore > 0 || detail.defensiveExplanation.isNotEmpty)) {
          dissonanceCount++;
          latestDissonance = latestDissonance.isEmpty ? (detail.dissonanceTypes.isNotEmpty ? detail.dissonanceTypes.join('、') : detail.defensiveExplanation) : latestDissonance;
          if (detail.intensityScore > 0) {
            totalIntensity += detail.intensityScore;
            intensityN++;
          }
          if (detail.defensiveExplanation.trim().isNotEmpty) {
            final k = detail.defensiveExplanation.trim();
            rationalizationCounts[k] = (rationalizationCounts[k] ?? 0) + 1;
          }
        }
        final logs = temps[e.evidenceId] ?? const <CcDissonanceTemperatureLog>[];
        final before = logs.where((l) => l.phase == 'before').toList();
        final after = logs.where((l) => l.phase == 'after').toList();
        if (before.isNotEmpty && after.isNotEmpty) {
          final drop = before.first.discomfortScore - after.first.discomfortScore;
          dropTotal += drop;
          dropN++;
        }
        if (e.evidenceCategory == 'recovery' || e.evidenceCategory == 'responsibility' || e.evidenceCategory == 'review' || e.evidenceCategory == 'information' || e.evidenceCategory == 'identity' || e.newStory.contains('修复') || e.newStory.contains('回来') || e.newStory.contains('接触现实')) {
          latestRepair = latestRepair.isEmpty ? e.completedAction : latestRepair;
        }
      }
      final evidenceCount = matchedEvidence.length;
      final repairCount = matchedEvidence.where((e) => e.evidenceCategory == 'recovery' || e.evidenceCategory == 'responsibility' || e.evidenceCategory == 'review' || e.evidenceCategory == 'information' || e.evidenceCategory == 'identity' || e.newStory.contains('修复') || e.newStory.contains('回来')).length;
      final allSessionIdsForValue = <String>{
        ...sessionIds,
        ...unrepairedSessionsForValue.map((row) => (row['session_id'] ?? '').toString()).where((sid) => sid.trim().isNotEmpty),
      };
      final verificationStatuses = allSessionIdsForValue.map((sid) => verificationBySession[sid] ?? '').where((s) => s.trim().isNotEmpty).toList(growable: false);
      var verifiedCount = 0;
      var partialCount = 0;
      var invalidCount = 0;
      var adjustCount = 0;
      var exitCount = 0;
      var needInfoCount = 0;
      for (final st in verificationStatuses) {
        if (st == 'verified') verifiedCount++;
        if (st == 'partial') partialCount++;
        if (st == 'invalid') invalidCount++;
        if (st == 'adjust') adjustCount++;
        if (st == 'exit') exitCount++;
        if (st == 'need_info') needInfoCount++;
      }
      final avgIntensity = intensityN == 0 ? 0 : (totalIntensity / intensityN).round();
      final avgDrop = dropN == 0 ? 0 : (dropTotal / dropN).round();
      final topRat = rationalizationCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final trend = evidenceCount == 0 && dissonanceCount == 0
          ? '证据不足'
          : exitCount > 0
              ? '需要退出/停止投入'
              : invalidCount > 0
                  ? '验证无效，需重做策略'
                  : needInfoCount > 0
                      ? '现实信息不足'
                      : adjustCount > 0
                          ? '需要调整'
                          : verifiedCount > 0
                              ? '验证有效，改善'
                              : partialCount > 0
                                  ? '部分改善'
                                  : repairCount >= dissonanceCount && repairCount > 0
                                      ? '改善'
                                      : avgDrop > 0
                                          ? '温度下降'
                                          : dissonanceCount > evidenceCount
                                              ? '失调偏高'
                                              : '摇摆';
      snapshots.add(CcValueConsistencySnapshot(
        valueId: value.valueId,
        valueLabel: label,
        beliefStrength: (value.priority <= 0 ? 50 : (100 - value.priority).clamp(20, 100)).toInt(),
        evidenceCount: evidenceCount,
        dissonanceCount: dissonanceCount,
        repairCount: repairCount,
        averageIntensity: avgIntensity,
        averageDiscomfortDrop: avgDrop,
        latestDissonance: latestDissonance,
        latestRepair: latestRepair,
        topRationalization: topRat.isEmpty ? '' : topRat.first.key,
        trend: trend,
      ));
    }
    snapshots.sort((a, b) => (b.dissonanceCount + b.evidenceCount).compareTo(a.dissonanceCount + a.evidenceCount));
    return snapshots;
  }

  Future<String> saveTemperatureReviewItem({
    required String sessionId,
    required String evidenceId,
    required String reviewText,
    String repairMode = '',
    String nextCoolingAction = '',
  }) async {
    final clean = reviewText.trim();
    if (clean.isEmpty) return '';
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'tmp_review_${now}_${evidenceId.hashCode.abs()}';
    await db.insert(
      'cc_temperature_review_items',
      <String, Object?>{
        'review_id': id,
        'session_id': sessionId.trim(),
        'evidence_id': evidenceId.trim(),
        'review_text': clean,
        'repair_mode': repairMode.trim(),
        'next_cooling_action': nextCoolingAction.trim(),
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<Map<String, CcTemperatureReviewItem>> temperatureReviewsForEvidenceIds(Iterable<String> evidenceIds) async {
    final ids = evidenceIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList(growable: false);
    if (ids.isEmpty) return <String, CcTemperatureReviewItem>{};
    final db = await _db;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT * FROM cc_temperature_review_items
      WHERE evidence_id IN ($placeholders)
      ORDER BY created_at_ms DESC
    ''', ids);
    final map = <String, CcTemperatureReviewItem>{};
    for (final row in rows) {
      final item = _temperatureReviewFromRow(row);
      map.putIfAbsent(item.evidenceId, () => item);
    }
    return map;
  }


  Future<List<CcTemperatureReviewItem>> recentTemperatureReviews({int limit = 40}) async {
    final db = await _db;
    final rows = await db.query('cc_temperature_review_items', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(_temperatureReviewFromRow).toList(growable: false);
  }

  Future<List<CcDissonanceTemperatureLog>> temperatureLogsForEvidence(String evidenceId) async {
    final eid = evidenceId.trim();
    if (eid.isEmpty) return const <CcDissonanceTemperatureLog>[];
    final db = await _db;
    final rows = await db.query(
      'cc_dissonance_temperature_logs',
      where: 'evidence_id = ?',
      whereArgs: <Object?>[eid],
      orderBy: 'created_at_ms DESC',
    );
    return rows.map(_temperatureLogFromRow).toList(growable: false);
  }

  Future<Map<String, CcInformationContactResult>> informationContactResultsForEvidenceIds(Iterable<String> evidenceIds) async {
    final ids = evidenceIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList(growable: false);
    if (ids.isEmpty) return <String, CcInformationContactResult>{};
    final db = await _db;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT * FROM cc_information_contact_results
      WHERE evidence_id IN ($placeholders)
      ORDER BY created_at_ms DESC
    ''', ids);
    final map = <String, CcInformationContactResult>{};
    for (final row in rows) {
      final item = _informationContactFromRow(row);
      map.putIfAbsent(item.evidenceId, () => item);
    }
    return map;
  }

  Future<Map<String, CcIdentityTransitionRecord>> identityTransitionsForEvidenceIds(Iterable<String> evidenceIds) async {
    final ids = evidenceIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList(growable: false);
    if (ids.isEmpty) return <String, CcIdentityTransitionRecord>{};
    final db = await _db;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT * FROM cc_identity_transition_records
      WHERE evidence_id IN ($placeholders)
      ORDER BY created_at_ms DESC
    ''', ids);
    final map = <String, CcIdentityTransitionRecord>{};
    for (final row in rows) {
      final item = _identityTransitionFromRow(row);
      map.putIfAbsent(item.evidenceId, () => item);
    }
    return map;
  }

  Future<String> saveInformationContactResult({
    required String sessionId,
    required String evidenceId,
    String avoidedInformation = '',
    String fearedResult = '',
    String actualResult = '',
    String resultType = '',
    String catastrophizingCheck = '',
    String repairAction = '',
    String sourceType = '',
    String sourceId = '',
    String originScene = '',
    int discomfortBefore = 0,
    int discomfortAfter = 0,
  }) async {
    if ([avoidedInformation, fearedResult, actualResult, catastrophizingCheck, repairAction].every((e) => e.trim().isEmpty) && resultType.trim().isEmpty) return '';
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'info_${now}_${evidenceId.hashCode.abs()}';
    await db.insert(
      'cc_information_contact_results',
      <String, Object?>{
        'result_id': id,
        'session_id': sessionId.trim(),
        'evidence_id': evidenceId.trim(),
        'avoided_information': avoidedInformation.trim(),
        'feared_result': fearedResult.trim(),
        'actual_result': actualResult.trim(),
        'result_type': resultType.trim(),
        'catastrophizing_check': catastrophizingCheck.trim(),
        'repair_action': repairAction.trim(),
        'source_type': sourceType.trim(),
        'source_id': sourceId.trim(),
        'origin_scene': originScene.trim(),
        'discomfort_before': discomfortBefore.clamp(0, 10).toInt(),
        'discomfort_after': discomfortAfter.clamp(0, 10).toInt(),
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<List<CcInformationContactResult>> recentInformationContactResults({int limit = 30}) async {
    final db = await _db;
    final rows = await db.query('cc_information_contact_results', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(_informationContactFromRow).toList(growable: false);
  }


  Future<void> deleteInformationContactResult(String resultId) async {
    final id = resultId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    await db.delete('cc_information_contact_results', where: 'result_id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> deleteIdentityTransitionRecord(String transitionId) async {
    final id = transitionId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    await db.delete('cc_identity_transition_records', where: 'transition_id = ?', whereArgs: <Object?>[id]);
  }


  Future<void> updateInformationContactResult(CcInformationContactResult item) async {
    final id = item.resultId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    await db.update(
      'cc_information_contact_results',
      <String, Object?>{
        'avoided_information': item.avoidedInformation.trim(),
        'feared_result': item.fearedResult.trim(),
        'actual_result': item.actualResult.trim(),
        'result_type': item.resultType.trim(),
        'catastrophizing_check': item.catastrophizingCheck.trim(),
        'repair_action': item.repairAction.trim(),
        'source_type': item.sourceType.trim(),
        'source_id': item.sourceId.trim(),
        'origin_scene': item.originScene.trim(),
        'discomfort_before': item.discomfortBefore.clamp(0, 10).toInt(),
        'discomfort_after': item.discomfortAfter.clamp(0, 10).toInt(),
      },
      where: 'result_id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> updateIdentityTransitionRecord(CcIdentityTransitionRecord item) async {
    final id = item.transitionId.trim();
    if (id.isEmpty) return;
    final db = await _db;
    await db.update(
      'cc_identity_transition_records',
      <String, Object?>{
        'old_identity': item.oldIdentity.trim(),
        'new_identity': item.newIdentity.trim(),
        'old_protection': item.oldProtection.trim(),
        'fear_of_loss': item.fearOfLoss.trim(),
        'new_identity_action': item.newIdentityAction.trim(),
        'post_action_identity_sentence': item.postActionIdentitySentence.trim(),
        'next_identity_action': item.nextIdentityAction.trim(),
        'source_type': item.sourceType.trim(),
        'source_id': item.sourceId.trim(),
        'origin_scene': item.originScene.trim(),
      },
      where: 'transition_id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<String> saveIdentityTransitionRecord({
    required String sessionId,
    required String evidenceId,
    String oldIdentity = '',
    String newIdentity = '',
    String oldProtection = '',
    String fearOfLoss = '',
    String newIdentityAction = '',
    String postActionIdentitySentence = '',
    String nextIdentityAction = '',
    String sourceType = '',
    String sourceId = '',
    String originScene = '',
  }) async {
    if ([oldIdentity, newIdentity, oldProtection, fearOfLoss, newIdentityAction, postActionIdentitySentence, nextIdentityAction].every((e) => e.trim().isEmpty)) return '';
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'identity_${now}_${evidenceId.hashCode.abs()}';
    await db.insert(
      'cc_identity_transition_records',
      <String, Object?>{
        'transition_id': id,
        'session_id': sessionId.trim(),
        'evidence_id': evidenceId.trim(),
        'old_identity': oldIdentity.trim(),
        'new_identity': newIdentity.trim(),
        'old_protection': oldProtection.trim(),
        'fear_of_loss': fearOfLoss.trim(),
        'new_identity_action': newIdentityAction.trim(),
        'post_action_identity_sentence': postActionIdentitySentence.trim(),
        'next_identity_action': nextIdentityAction.trim(),
        'source_type': sourceType.trim(),
        'source_id': sourceId.trim(),
        'origin_scene': originScene.trim(),
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<List<CcIdentityTransitionRecord>> recentIdentityTransitions({int limit = 30}) async {
    final db = await _db;
    final rows = await db.query('cc_identity_transition_records', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(_identityTransitionFromRow).toList(growable: false);
  }

  Future<Map<String, int>> selfIntegrityStats() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS c,
        SUM(CASE WHEN TRIM(not_equal_sentence) <> '' THEN 1 ELSE 0 END) AS not_equal_count,
        SUM(CASE WHEN TRIM(next_proof_action) <> '' THEN 1 ELSE 0 END) AS next_proof_count
      FROM cc_self_integrity_cards
    ''');
    final row = rows.isEmpty ? <String, Object?>{} : rows.first;
    return <String, int>{
      'cards': _asInt(row['c']),
      'notEqual': _asInt(row['not_equal_count']),
      'nextProof': _asInt(row['next_proof_count']),
    };
  }

  Future<void> clearAllCognitiveConsistencyData() async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final table in <String>[
        'cc_dissonance_resolution_method_usages',
        'cc_commitment_action_contracts',
        'cc_counter_attitudinal_experiments',
        'cc_interpersonal_balance_records',
        'cc_user_choice_records',
        'cc_value_layer_records',
        'cc_user_confirmations',
        'cc_conflict_edges',
        'cc_cognition_nodes',
        'cc_defense_pattern_records',
        'cc_protected_self_images',
        'cc_sourcebook_cases',
        'cc_identity_transition_records',
        'cc_information_contact_results',
        'cc_temperature_review_items',
        'cc_daily_consistency_reviews',
        'cc_dissonance_temperature_logs',
        'cc_self_integrity_cards',
        'cc_consistency_reframe_items',
        'cc_dissonance_intensity_scores',
        'cc_dissonance_type_items',
        'cc_verification_tasks',
        'cc_special_scene_items',
        'cc_rationalization_flag_items',
        'cc_self_standard_items',
        'cc_special_scene_details',
        'cc_true_self_links',
        'cc_rationalization_flags',
        'cc_self_standards',
        'cc_trigger_conditions',
        'cc_dissonance_events',
        'cc_action_trace_links',
        'cc_trigger_suggestions',
        'cc_effective_patterns',
        'cc_value_relation_insights',
        'cc_report_action_links',
        'cc_evidence_value_links',
        'cc_source_value_links',
        'cc_reports',
        'cc_evidence_records',
        'cc_sessions',
        'cc_value_profiles',
      ]) {
        await txn.delete(table);
      }
    });
  }



  CcTemperatureReviewItem _temperatureReviewFromRow(Map<String, Object?> row) => CcTemperatureReviewItem(
        reviewId: (row['review_id'] ?? '').toString(),
        sessionId: (row['session_id'] ?? '').toString(),
        evidenceId: (row['evidence_id'] ?? '').toString(),
        reviewText: (row['review_text'] ?? '').toString(),
        repairMode: (row['repair_mode'] ?? '').toString(),
        nextCoolingAction: (row['next_cooling_action'] ?? '').toString(),
        createdAtMs: _asInt(row['created_at_ms']),
      );

  CcInformationContactResult _informationContactFromRow(Map<String, Object?> row) => CcInformationContactResult(
        resultId: (row['result_id'] ?? '').toString(),
        sessionId: (row['session_id'] ?? '').toString(),
        evidenceId: (row['evidence_id'] ?? '').toString(),
        avoidedInformation: (row['avoided_information'] ?? '').toString(),
        fearedResult: (row['feared_result'] ?? '').toString(),
        actualResult: (row['actual_result'] ?? '').toString(),
        resultType: (row['result_type'] ?? '').toString(),
        catastrophizingCheck: (row['catastrophizing_check'] ?? '').toString(),
        repairAction: (row['repair_action'] ?? '').toString(),
        sourceType: (row['source_type'] ?? '').toString(),
        sourceId: (row['source_id'] ?? '').toString(),
        originScene: (row['origin_scene'] ?? '').toString(),
        discomfortBefore: _asInt(row['discomfort_before']),
        discomfortAfter: _asInt(row['discomfort_after']),
        createdAtMs: _asInt(row['created_at_ms']),
      );

  CcIdentityTransitionRecord _identityTransitionFromRow(Map<String, Object?> row) => CcIdentityTransitionRecord(
        transitionId: (row['transition_id'] ?? '').toString(),
        sessionId: (row['session_id'] ?? '').toString(),
        evidenceId: (row['evidence_id'] ?? '').toString(),
        oldIdentity: (row['old_identity'] ?? '').toString(),
        newIdentity: (row['new_identity'] ?? '').toString(),
        oldProtection: (row['old_protection'] ?? '').toString(),
        fearOfLoss: (row['fear_of_loss'] ?? '').toString(),
        newIdentityAction: (row['new_identity_action'] ?? '').toString(),
        postActionIdentitySentence: (row['post_action_identity_sentence'] ?? '').toString(),
        nextIdentityAction: (row['next_identity_action'] ?? '').toString(),
        sourceType: (row['source_type'] ?? '').toString(),
        sourceId: (row['source_id'] ?? '').toString(),
        originScene: (row['origin_scene'] ?? '').toString(),
        createdAtMs: _asInt(row['created_at_ms']),
      );

  CcDailyConsistencyReview _dailyReviewFromRow(Map<String, Object?> row) => CcDailyConsistencyReview(
        reviewId: (row['review_id'] ?? '').toString(),
        dateLabel: (row['date_label'] ?? '').toString(),
        closestValueAction: (row['closest_value_action'] ?? '').toString(),
        mainDissonance: (row['main_dissonance'] ?? '').toString(),
        rationalizationUsed: (row['rationalization_used'] ?? '').toString(),
        growthReframe: (row['growth_reframe'] ?? '').toString(),
        repairActionDone: (row['repair_action_done'] ?? '').toString(),
        tomorrowAction: (row['tomorrow_action'] ?? '').toString(),
        createdAtMs: _asInt(row['created_at_ms']),
      );

  CcDissonanceTemperatureLog _temperatureLogFromRow(Map<String, Object?> row) => CcDissonanceTemperatureLog(
        logId: (row['log_id'] ?? '').toString(),
        sessionId: (row['session_id'] ?? '').toString(),
        evidenceId: (row['evidence_id'] ?? '').toString(),
        phase: (row['phase'] ?? '').toString(),
        discomfortScore: _asInt(row['discomfort_score']),
        guiltScore: _asInt(row['guilt_score']),
        anxietyScore: _asInt(row['anxiety_score']),
        shameScore: _asInt(row['shame_score']),
        defensivenessScore: _asInt(row['defensiveness_score']),
        avoidanceUrgeScore: _asInt(row['avoidance_urge_score']),
        clarityScore: _asInt(row['clarity_score']),
        responsibilityScore: _asInt(row['responsibility_score']),
        actionWillingnessScore: _asInt(row['action_willingness_score']),
        note: (row['note'] ?? '').toString(),
        createdAtMs: _asInt(row['created_at_ms']),
      );

  CcSession _sessionFromRow(Map<String, Object?> row) {
    Map<String, dynamic> decoded = <String, dynamic>{};
    try {
      final raw = (row['result_json'] ?? '').toString();
      if (raw.trim().isNotEmpty) decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {}
    final sessionId = (row['session_id'] ?? '').toString();
    return CcSession(
      sessionId: sessionId,
      sceneType: (row['scene_type'] ?? '').toString(),
      userGoal: (row['user_goal'] ?? '').toString(),
      userContext: (row['user_context'] ?? '').toString(),
      userValues: (row['user_values'] ?? '').toString(),
      result: CcPlanResult.fromJson(decoded).copyWith(sessionId: sessionId),
      status: (row['status'] ?? '').toString(),
      sourceType: (row['source_type'] ?? '').toString(),
      sourceId: (row['source_id'] ?? '').toString(),
      rewardSource: (row['reward_source'] ?? '').toString(),
      originScene: (row['origin_scene'] ?? '').toString(),
      createdAtMs: _asInt(row['created_at_ms']),
      updatedAtMs: _asInt(row['updated_at_ms']),
    );
  }

  CcEvidenceRecord _evidenceFromRow(Map<String, Object?> row) => CcEvidenceRecord(
        evidenceId: (row['evidence_id'] ?? '').toString(),
        sessionId: (row['session_id'] ?? '').toString(),
        userGoal: (row['user_goal'] ?? '').toString(),
        plannedAction: (row['planned_action'] ?? '').toString(),
        completedAction: (row['completed_action'] ?? '').toString(),
        userReflection: (row['user_reflection'] ?? '').toString(),
        evidenceLabel: (row['evidence_label'] ?? '').toString(),
        valueLink: (row['value_link'] ?? '').toString(),
        oldStory: (row['old_story'] ?? '').toString(),
        newStory: (row['new_story'] ?? '').toString(),
        evidenceCategory: (row['evidence_category'] ?? 'start').toString(),
        identityDirection: (row['identity_direction'] ?? '').toString(),
        rewardSource: (row['reward_source'] ?? '').toString(),
        sourceType: (row['source_type'] ?? '').toString(),
        sourceId: (row['source_id'] ?? '').toString(),
        effortMinutes: _asInt(row['effort_minutes']),
        difficultyScore: _asInt(row['difficulty_score']),
        startedAtMs: _asInt(row['started_at_ms']),
        endedAtMs: _asInt(row['ended_at_ms']),
        createdAtMs: _asInt(row['created_at_ms']),
      );

  CcValueProfile _valueFromRow(Map<String, Object?> row) => CcValueProfile(
        valueId: (row['value_id'] ?? '').toString(),
        valueLabel: (row['value_label'] ?? '').toString(),
        why: (row['why'] ?? '').toString(),
        identityDirection: (row['identity_direction'] ?? '').toString(),
        exampleAction: (row['example_action'] ?? '').toString(),
        priority: _asInt(row['priority']),
        createdAtMs: _asInt(row['created_at_ms']),
        updatedAtMs: _asInt(row['updated_at_ms']),
      );


  CcEvidenceValueLink _valueLinkFromRow(Map<String, Object?> row) => CcEvidenceValueLink(
        evidenceId: (row['evidence_id'] ?? '').toString(),
        valueId: (row['value_id'] ?? '').toString(),
        valueLabel: (row['value_label'] ?? '').toString(),
        relationType: (row['relation_type'] ?? 'selected').toString(),
        createdAtMs: _asInt(row['created_at_ms']),
      );

  CcReportRecord _reportFromRow(Map<String, Object?> row) => CcReportRecord(
        reportId: (row['report_id'] ?? '').toString(),
        periodLabel: (row['period_label'] ?? '').toString(),
        userValues: (row['user_values'] ?? '').toString(),
        reportText: (row['report_text'] ?? '').toString(),
        suggestedAction: (row['suggested_action'] ?? '').toString(),
        adoptedEvidenceId: (row['adopted_evidence_id'] ?? '').toString(),
        createdAtMs: _asInt(row['created_at_ms']),
      );


  CcValueRelationInsightRecord _valueRelationInsightFromRow(Map<String, Object?> row) => CcValueRelationInsightRecord(
        insightId: (row['insight_id'] ?? '').toString(),
        selectedValueIds: (row['selected_value_ids'] ?? '').toString(),
        selectedValueLabels: (row['selected_value_labels'] ?? '').toString(),
        userGoal: (row['user_goal'] ?? '').toString(),
        userContext: (row['user_context'] ?? '').toString(),
        insightText: (row['insight_text'] ?? '').toString(),
        linkedSessionId: (row['linked_session_id'] ?? '').toString(),
        linkedEvidenceId: (row['linked_evidence_id'] ?? '').toString(),
        createdAtMs: _asInt(row['created_at_ms']),
      );


  CcReportActionLink _reportActionLinkFromRow(Map<String, Object?> row) => CcReportActionLink(
        linkId: (row['link_id'] ?? '').toString(),
        reportId: (row['report_id'] ?? '').toString(),
        sessionId: (row['session_id'] ?? '').toString(),
        todoStepId: (row['todo_step_id'] ?? '').toString(),
        evidenceId: (row['evidence_id'] ?? '').toString(),
        status: (row['status'] ?? 'suggested').toString(),
        suggestedAction: (row['suggested_action'] ?? '').toString(),
        createdAtMs: _asInt(row['created_at_ms']),
        updatedAtMs: _asInt(row['updated_at_ms']),
      );

  CcEffectivePatternRecord _effectivePatternFromRow(Map<String, Object?> row) => CcEffectivePatternRecord(
        patternId: (row['pattern_id'] ?? '').toString(),
        evidenceId: (row['evidence_id'] ?? '').toString(),
        valueLabels: (row['value_labels'] ?? '').toString(),
        oldStory: (row['old_story'] ?? '').toString(),
        newStory: (row['new_story'] ?? '').toString(),
        actionTemplate: (row['action_template'] ?? '').toString(),
        successReason: (row['success_reason'] ?? '').toString(),
        createdAtMs: _asInt(row['created_at_ms']),
      );

  CcActionTraceLink _actionTraceLinkFromRow(Map<String, Object?> row) => CcActionTraceLink(
        linkId: (row['link_id'] ?? '').toString(),
        fromType: (row['from_type'] ?? '').toString(),
        fromId: (row['from_id'] ?? '').toString(),
        toType: (row['to_type'] ?? '').toString(),
        toId: (row['to_id'] ?? '').toString(),
        relationType: (row['relation_type'] ?? '').toString(),
        createdAtMs: _asInt(row['created_at_ms']),
      );

  CcVerificationTask _verificationTaskFromRow(Map<String, Object?> row) => CcVerificationTask(
        taskId: (row['task_id'] ?? '').toString(),
        sessionId: (row['session_id'] ?? '').toString(),
        sceneType: (row['scene_type'] ?? '').toString(),
        question: (row['question'] ?? '').toString(),
        successSignal: (row['success_signal'] ?? '').toString(),
        dueAtMs: _asInt(row['due_at_ms']),
        status: (row['status'] ?? 'open').toString(),
        resultNote: (row['result_note'] ?? '').toString(),
        createdAtMs: _asInt(row['created_at_ms']),
        verifiedAtMs: _asInt(row['verified_at_ms']),
      );

  int _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
