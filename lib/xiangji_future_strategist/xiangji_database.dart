import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'xiangji_method_catalog.dart';
import 'xiangji_models.dart';
import 'xiangji_practical_product.dart';
import 'xiangji_rev3_models.dart';
import 'xiangji_rev4_models.dart';
import 'xiangji_schopenhauer_core_catalog.dart';

/// SQLite is the authoritative local store for the strategist. Every table is
/// prefixed so the module can coexist with the app's existing goal/Todo data.
/// Todo completion is linked, not copied into a second task system.
class XiangjiDao {
  XiangjiDao({Database? database}) : _injectedDatabase = database;

  final Database? _injectedDatabase;
  bool _ensured = false;

  Future<Database> _database() async {
    final db = _injectedDatabase ?? await AppDatabase.instance();
    if (!_ensured) {
      await ensureSchema(db);
      _ensured = true;
    }
    return db;
  }

  Future<void> ensureSchema([Database? database]) async {
    final db = database ?? _injectedDatabase ?? await AppDatabase.instance();
    final batch = db.batch();
    for (final statement in _schemaStatements) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
    await _ensureRev3Columns(db);
    await _ensureRev4Columns(db);
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS xf_knowledge_passage_fts
        USING fts4(passage_id, title, locator, body)
      ''');
    } catch (_) {
      // Some embedded SQLite builds omit FTS4. Exact LIKE search remains
      // available and the UI exposes the index state truthfully.
    }
    await _seedCoreKnowledge(db);
    await _seedPracticalProductData(db);
    await _ensureRev3SckRules(db);
    await _ensureRev4Rules(db);
    await _ensureRev52Metadata(db);
    await _seedProviderCapabilities(db);
    _ensured = true;
  }

  Future<XiangjiUserPreferenceProfile> userPreferenceProfile() async {
    final db = await _database();
    final rows = await db.query(
      'xf_user_preference',
      where: 'id = ?',
      whereArgs: const <Object?>['default'],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return XiangjiUserPreferenceProfile.fromMap(rows.first);
    }
    const profile = XiangjiUserPreferenceProfile();
    await db.insert(
      'xf_user_preference',
      profile.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return profile;
  }

  Future<void> saveUserPreferenceProfile(
    XiangjiUserPreferenceProfile profile,
  ) async {
    final db = await _database();
    await db.insert(
      'xf_user_preference',
      profile.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<XiangjiGuidedCase>> guidedCases() async {
    final db = await _database();
    final rows = await db.query(
      'xf_guided_case',
      orderBy: 'sort_order ASC, title ASC',
    );
    return rows.map(XiangjiGuidedCase.fromMap).toList(growable: false);
  }

  Future<XiangjiGuidedCase?> guidedCase(String id) async {
    final db = await _database();
    final rows = await db.query(
      'xf_guided_case',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : XiangjiGuidedCase.fromMap(rows.first);
  }

  Future<int> completedRealityRoundCount() async {
    final db = await _database();
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM xf_reality_result'),
        ) ??
        0;
  }

  Future<void> _ensureRev3Columns(Database db) async {
    Future<void> add(
      String table,
      String column,
      String definition,
    ) async {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      final exists = columns.any(
        (row) => (row['name'] ?? '').toString() == column,
      );
      if (!exists) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
      }
    }

    await add(
      'xf_concept_version',
      'support_refs_json',
      "TEXT NOT NULL DEFAULT '[]'",
    );
    await add(
      'xf_concept_version',
      'counterexample_refs_json',
      "TEXT NOT NULL DEFAULT '[]'",
    );
    await add(
      'xf_problem',
      'situation_model_id',
      "TEXT NOT NULL DEFAULT ''",
    );
    await add(
      'xf_information_need',
      'resolution_action_id',
      "TEXT NOT NULL DEFAULT ''",
    );
    await add(
      'xf_decision_draft',
      'agent_run_id',
      "TEXT NOT NULL DEFAULT ''",
    );
    await add(
      'xf_strategy_option',
      'opportunity_cost',
      "TEXT NOT NULL DEFAULT ''",
    );
    await add(
      'xf_reality_result',
      'experience_json',
      "TEXT NOT NULL DEFAULT '[]'",
    );
  }

  Future<void> _ensureRev4Columns(Database db) async {
    Future<void> add(
      String table,
      String column,
      String definition,
    ) async {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      final exists = columns.any(
        (row) => (row['name'] ?? '').toString() == column,
      );
      if (!exists) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
      }
    }

    await add('xf_problem', 'need', "TEXT NOT NULL DEFAULT ''");
    await add('xf_problem', 'root_goal_id', "TEXT NOT NULL DEFAULT ''");
    await add('xf_problem', 'parent_problem_id', "TEXT NOT NULL DEFAULT ''");
    await add(
      'xf_problem',
      'current_state_version_id',
      "TEXT NOT NULL DEFAULT ''",
    );
    await add(
      'xf_problem',
      'canonical_problem_id',
      "TEXT NOT NULL DEFAULT ''",
    );
    await add(
      'xf_problem',
      'problem_status',
      "TEXT NOT NULL DEFAULT 'ACTIVE'",
    );
    await add(
      'xf_concept_version',
      'applicability_boundary',
      "TEXT NOT NULL DEFAULT ''",
    );
    await add(
      'xf_concept_version',
      'unexplained_details_json',
      "TEXT NOT NULL DEFAULT '[]'",
    );
    await add(
      'xf_strategy_option',
      'target_gap',
      "TEXT NOT NULL DEFAULT ''",
    );
    await add(
      'xf_strategy_option',
      'mechanism_for_this_case',
      "TEXT NOT NULL DEFAULT ''",
    );
    await add(
      'xf_strategy_option',
      'key_assumption',
      "TEXT NOT NULL DEFAULT ''",
    );
    await add(
      'xf_strategy_option',
      'why_preferred',
      "TEXT NOT NULL DEFAULT ''",
    );
    await add(
      'xf_strategy_option',
      'why_not_other_options',
      "TEXT NOT NULL DEFAULT ''",
    );
    await add(
      'xf_strategy_option',
      'switch_trigger',
      "TEXT NOT NULL DEFAULT ''",
    );
    await add(
      'xf_strategy_option',
      'user_summary',
      "TEXT NOT NULL DEFAULT ''",
    );
    await add(
      'xf_strategy_option',
      'preferred',
      'INTEGER NOT NULL DEFAULT 0',
    );
  }

  static const List<String> _schemaStatements = <String>[
    '''
      CREATE TABLE IF NOT EXISTS xf_user_preference (
        id TEXT PRIMARY KEY,
        interest_tags_json TEXT NOT NULL DEFAULT '[]',
        value_tags_json TEXT NOT NULL DEFAULT '[]',
        strength_tags_json TEXT NOT NULL DEFAULT '[]',
        energy_level TEXT NOT NULL DEFAULT 'medium',
        support_style TEXT NOT NULL DEFAULT 'direct',
        preferred_minutes INTEGER NOT NULL DEFAULT 10,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_guided_case (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        summary TEXT NOT NULL,
        category TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        source_label TEXT NOT NULL,
        case_json TEXT NOT NULL DEFAULT '{}',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_raw_event (
        id TEXT PRIMARY KEY,
        occurred_at_ms INTEGER NOT NULL,
        context_text TEXT NOT NULL,
        source_type TEXT NOT NULL,
        source_ref TEXT,
        sensitivity TEXT NOT NULL DEFAULT 'sensitive',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_experience (
        id TEXT PRIMARY KEY,
        raw_event_id TEXT NOT NULL,
        problem_id TEXT,
        experience_type TEXT NOT NULL,
        content TEXT NOT NULL,
        is_user_wording INTEGER NOT NULL DEFAULT 1,
        observation_conditions_json TEXT NOT NULL DEFAULT '{}',
        user_confirmed INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_claim (
        id TEXT PRIMARY KEY,
        problem_id TEXT,
        campaign_id TEXT,
        claim_type TEXT NOT NULL,
        text TEXT NOT NULL,
        epistemic_status TEXT NOT NULL,
        importance TEXT NOT NULL DEFAULT 'medium',
        source_kind TEXT NOT NULL,
        source_ref TEXT,
        is_user_wording INTEGER NOT NULL DEFAULT 0,
        user_confirmed INTEGER NOT NULL DEFAULT 0,
        profile_json TEXT NOT NULL DEFAULT '{}',
        systematicity TEXT NOT NULL DEFAULT 'unknown',
        version_no INTEGER NOT NULL DEFAULT 1,
        supersedes_id TEXT,
        valid_from_ms INTEGER,
        valid_to_ms INTEGER,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_evidence (
        id TEXT PRIMARY KEY,
        problem_id TEXT,
        campaign_id TEXT,
        evidence_type TEXT NOT NULL,
        source_ref TEXT,
        content TEXT NOT NULL,
        content_hash TEXT,
        provenance_json TEXT NOT NULL DEFAULT '{}',
        sensitivity TEXT NOT NULL DEFAULT 'sensitive',
        collected_at_ms INTEGER NOT NULL,
        deleted_at_ms INTEGER
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_grounding_relation (
        id TEXT PRIMARY KEY,
        claim_id TEXT NOT NULL,
        ground_type TEXT NOT NULL,
        ground_ref_id TEXT NOT NULL,
        relation_type TEXT NOT NULL,
        directness_level INTEGER NOT NULL DEFAULT 0,
        created_by TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_counterexample (
        id TEXT PRIMARY KEY,
        claim_id TEXT,
        concept_id TEXT,
        event_ref TEXT,
        explanation TEXT NOT NULL,
        strength TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_epistemic_debt (
        id TEXT PRIMARY KEY,
        problem_id TEXT,
        campaign_id TEXT,
        premise_claim_id TEXT,
        description TEXT NOT NULL,
        decision_impact TEXT NOT NULL,
        grounding_gap TEXT NOT NULL,
        urgency TEXT NOT NULL,
        settlement_cost TEXT,
        information_value TEXT,
        settlement_action_id TEXT,
        status TEXT NOT NULL DEFAULT 'open',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_causal_hypothesis (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        effect_claim_id TEXT,
        cause_candidate TEXT NOT NULL,
        differentiating_evidence_needed TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'candidate',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_concept (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        scope TEXT NOT NULL DEFAULT '',
        origin TEXT NOT NULL,
        is_personal INTEGER NOT NULL DEFAULT 1,
        current_version_id TEXT,
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_concept_version (
        id TEXT PRIMARY KEY,
        concept_id TEXT NOT NULL,
        version_no INTEGER NOT NULL,
        definition TEXT NOT NULL,
        observable_criteria_json TEXT NOT NULL DEFAULT '[]',
        change_reason TEXT NOT NULL,
        supersedes_id TEXT,
        source_refs_json TEXT NOT NULL DEFAULT '[]',
        support_refs_json TEXT NOT NULL DEFAULT '[]',
        counterexample_refs_json TEXT NOT NULL DEFAULT '[]',
        applicability_boundary TEXT NOT NULL DEFAULT '',
        unexplained_details_json TEXT NOT NULL DEFAULT '[]',
        created_at_ms INTEGER NOT NULL,
        UNIQUE(concept_id, version_no)
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_concept_cycle (
        id TEXT PRIMARY KEY,
        node_ids_json TEXT NOT NULL,
        has_grounding_path INTEGER NOT NULL DEFAULT 0,
        impact TEXT NOT NULL,
        resolution_status TEXT NOT NULL DEFAULT 'pending',
        detected_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_problem (
        id TEXT PRIMARY KEY,
        raw_event_id TEXT NOT NULL,
        raw_question TEXT NOT NULL,
        reframed_question TEXT NOT NULL DEFAULT '',
        state TEXT NOT NULL,
        campaign_id TEXT,
        situation_model_id TEXT NOT NULL DEFAULT '',
        goal_text TEXT NOT NULL DEFAULT '',
        value_link TEXT NOT NULL DEFAULT '',
        success_criteria TEXT NOT NULL DEFAULT '',
        exit_criteria TEXT NOT NULL DEFAULT '',
        review_at_ms INTEGER NOT NULL DEFAULT 0,
        priority INTEGER NOT NULL DEFAULT 0,
        version_no INTEGER NOT NULL DEFAULT 1,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_problem_item (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        text TEXT NOT NULL,
        source_ref TEXT,
        critical INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        data_json TEXT NOT NULL DEFAULT '{}',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_solver_snapshot (
        problem_id TEXT PRIMARY KEY,
        state_version INTEGER NOT NULL DEFAULT 1,
        need_text TEXT NOT NULL DEFAULT '',
        problem_frame_json TEXT NOT NULL DEFAULT '{}',
        current_state_json TEXT NOT NULL DEFAULT '{}',
        goal_state_json TEXT NOT NULL DEFAULT '{}',
        hypotheses_json TEXT NOT NULL DEFAULT '[]',
        constraints_json TEXT NOT NULL DEFAULT '[]',
        gaps_json TEXT NOT NULL DEFAULT '[]',
        key_gap_json TEXT NOT NULL DEFAULT '{}',
        subgoal_graph_json TEXT NOT NULL DEFAULT '{}',
        active_subgoal_json TEXT NOT NULL DEFAULT '{}',
        candidate_operators_json TEXT NOT NULL DEFAULT '[]',
        active_operator_json TEXT NOT NULL DEFAULT '{}',
        epistemic_profile_json TEXT NOT NULL DEFAULT '{}',
        prediction_ledger_json TEXT NOT NULL DEFAULT '{}',
        last_reality_result_json TEXT NOT NULL DEFAULT '{}',
        backtrack_history_json TEXT NOT NULL DEFAULT '[]',
        prompt_version TEXT NOT NULL DEFAULT 'rev5.2',
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_method_event (
        id TEXT PRIMARY KEY,
        method_id TEXT NOT NULL,
        problem_id TEXT NOT NULL,
        state_version INTEGER NOT NULL,
        trigger_text TEXT NOT NULL,
        source_refs_json TEXT NOT NULL DEFAULT '[]',
        before_state_refs_json TEXT NOT NULL DEFAULT '{}',
        operation_summary TEXT NOT NULL,
        data_mutations_json TEXT NOT NULL DEFAULT '[]',
        after_state_refs_json TEXT NOT NULL DEFAULT '{}',
        decision_effect TEXT NOT NULL,
        user_visible_summary TEXT NOT NULL,
        reality_test TEXT NOT NULL,
        learning_link TEXT NOT NULL DEFAULT '',
        changed_state INTEGER NOT NULL DEFAULT 1,
        retained_state_reason TEXT NOT NULL DEFAULT '',
        user_visible INTEGER NOT NULL DEFAULT 1,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_situation_model (
        id TEXT PRIMARY KEY,
        object_type TEXT NOT NULL,
        object_id TEXT NOT NULL,
        version_no INTEGER NOT NULL,
        state TEXT NOT NULL,
        summary TEXT NOT NULL,
        current_need TEXT NOT NULL,
        model_json TEXT NOT NULL DEFAULT '{}',
        source_refs_json TEXT NOT NULL DEFAULT '[]',
        generated_at_ms INTEGER NOT NULL,
        stale_reason TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL,
        UNIQUE(object_type, object_id, version_no)
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_ai_inference (
        id TEXT PRIMARY KEY,
        situation_model_id TEXT NOT NULL,
        problem_id TEXT,
        text TEXT NOT NULL,
        inference_type TEXT NOT NULL,
        source_refs_json TEXT NOT NULL DEFAULT '[]',
        agent_run_id TEXT,
        epistemic_status TEXT NOT NULL,
        user_confirmed INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_information_need (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        situation_model_id TEXT NOT NULL,
        question TEXT NOT NULL,
        missing_field TEXT NOT NULL,
        missing INTEGER NOT NULL DEFAULT 1,
        decision_impact TEXT NOT NULL,
        can_infer INTEGER NOT NULL DEFAULT 0,
        infer_source_refs_json TEXT NOT NULL DEFAULT '[]',
        scouting_possible INTEGER NOT NULL DEFAULT 0,
        scouting_option TEXT NOT NULL DEFAULT '',
        resolution_action_id TEXT NOT NULL DEFAULT '',
        evsi_rank REAL NOT NULL DEFAULT 0,
        expected_value TEXT NOT NULL DEFAULT '',
        user_burden REAL NOT NULL DEFAULT 1,
        selected_for_question INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'OPEN',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_clarification_question (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        information_need_id TEXT NOT NULL,
        wording TEXT NOT NULL,
        burden_estimate REAL NOT NULL DEFAULT 1,
        asked_at_ms INTEGER NOT NULL,
        answer_ref TEXT NOT NULL DEFAULT '',
        answered_at_ms INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'ASKED'
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_user_correction (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        target_ref TEXT NOT NULL,
        old_value TEXT NOT NULL DEFAULT '',
        corrected_value TEXT NOT NULL,
        reason TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_agent_run (
        id TEXT PRIMARY KEY,
        problem_id TEXT,
        campaign_id TEXT,
        agent_role TEXT NOT NULL,
        orchestration_state TEXT NOT NULL,
        model_run_id TEXT,
        input_refs_json TEXT NOT NULL DEFAULT '[]',
        output_refs_json TEXT NOT NULL DEFAULT '[]',
        output_json TEXT NOT NULL DEFAULT '{}',
        status TEXT NOT NULL,
        started_at_ms INTEGER NOT NULL,
        ended_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_reasoning_artifact (
        id TEXT PRIMARY KEY,
        problem_id TEXT,
        campaign_id TEXT,
        situation_model_id TEXT NOT NULL,
        agent_run_id TEXT,
        kind TEXT NOT NULL,
        json_payload TEXT NOT NULL DEFAULT '{}',
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_judgment (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        situation_model_id TEXT NOT NULL,
        purpose_scope TEXT NOT NULL,
        compared_cases_json TEXT NOT NULL DEFAULT '[]',
        relevant_similarities_json TEXT NOT NULL DEFAULT '[]',
        relevant_differences_json TEXT NOT NULL DEFAULT '[]',
        counterexamples_json TEXT NOT NULL DEFAULT '[]',
        conclusion TEXT NOT NULL,
        agent_run_id TEXT,
        state TEXT NOT NULL DEFAULT 'DRAFT',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_decision_draft (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        campaign_id TEXT,
        action_id TEXT,
        situation_model_id TEXT NOT NULL,
        true_problem TEXT NOT NULL DEFAULT '',
        recommendation TEXT NOT NULL,
        judgment TEXT NOT NULL,
        why_text TEXT NOT NULL,
        current_action TEXT NOT NULL,
        change_signals TEXT NOT NULL,
        epistemic_status TEXT NOT NULL,
        clarification_question TEXT NOT NULL DEFAULT '',
        options_json TEXT NOT NULL DEFAULT '[]',
        uncertainty_json TEXT NOT NULL DEFAULT '{}',
        weakest_premise TEXT NOT NULL DEFAULT '',
        unresolved_items_json TEXT NOT NULL DEFAULT '[]',
        agent_run_id TEXT NOT NULL DEFAULT '',
        user_status TEXT NOT NULL DEFAULT 'PROPOSED',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_campaign (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        state TEXT NOT NULL,
        north_star TEXT NOT NULL DEFAULT '',
        grand_strategy TEXT NOT NULL DEFAULT '',
        theater TEXT NOT NULL DEFAULT '',
        strategic_value TEXT NOT NULL DEFAULT '',
        war_worthiness TEXT NOT NULL DEFAULT '',
        victory_criteria TEXT NOT NULL DEFAULT '',
        exit_criteria TEXT NOT NULL DEFAULT '',
        resource_budget_json TEXT NOT NULL DEFAULT '{}',
        review_at_ms INTEGER NOT NULL DEFAULT 0,
        is_primary INTEGER NOT NULL DEFAULT 0,
        user_confirmed INTEGER NOT NULL DEFAULT 0,
        version_no INTEGER NOT NULL DEFAULT 1,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_strategy_option (
        id TEXT PRIMARY KEY,
        campaign_id TEXT NOT NULL,
        name TEXT NOT NULL,
        strategy_type TEXT NOT NULL,
        benefits_json TEXT NOT NULL DEFAULT '[]',
        costs_json TEXT NOT NULL DEFAULT '[]',
        opportunity_cost TEXT NOT NULL DEFAULT '',
        reversibility TEXT NOT NULL,
        key_assumptions_json TEXT NOT NULL DEFAULT '[]',
        stop_conditions_json TEXT NOT NULL DEFAULT '[]',
        evidence_level TEXT NOT NULL DEFAULT 'hypothesis',
        selected INTEGER NOT NULL DEFAULT 0,
        version_no INTEGER NOT NULL DEFAULT 1,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_campaign_intel (
        id TEXT PRIMARY KEY,
        campaign_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        text TEXT NOT NULL,
        source_ref TEXT,
        source_quality TEXT NOT NULL DEFAULT 'unknown',
        freshness TEXT NOT NULL DEFAULT 'unknown',
        conflict_of_interest TEXT NOT NULL DEFAULT '',
        epistemic_status TEXT NOT NULL DEFAULT 'UNRESOLVED',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_contingency (
        id TEXT PRIMARY KEY,
        campaign_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        trigger_expression TEXT NOT NULL,
        action_plan TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_indicator (
        id TEXT PRIMARY KEY,
        campaign_id TEXT NOT NULL,
        indicator_type TEXT NOT NULL,
        metric TEXT NOT NULL,
        threshold_text TEXT NOT NULL,
        direction TEXT NOT NULL,
        window_text TEXT NOT NULL,
        latest_value TEXT,
        latest_at_ms INTEGER,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_action (
        id TEXT PRIMARY KEY,
        operator_id TEXT,
        campaign_id TEXT,
        problem_id TEXT,
        title TEXT NOT NULL,
        state TEXT NOT NULL,
        why_chain_json TEXT NOT NULL DEFAULT '{}',
        prediction TEXT NOT NULL DEFAULT '',
        expected_minutes INTEGER NOT NULL DEFAULT 0,
        todo_ref TEXT NOT NULL DEFAULT '',
        blocker_type TEXT NOT NULL DEFAULT '',
        started_at_ms INTEGER NOT NULL DEFAULT 0,
        completed_at_ms INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_action_log (
        id TEXT PRIMARY KEY,
        action_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        details_json TEXT NOT NULL DEFAULT '{}',
        occurred_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_prediction (
        id TEXT PRIMARY KEY,
        action_id TEXT NOT NULL,
        statement TEXT NOT NULL,
        expected_range TEXT,
        evaluation_at_ms INTEGER,
        criteria TEXT,
        precommitted_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_reality_result (
        id TEXT PRIMARY KEY,
        action_id TEXT NOT NULL,
        observed_at_ms INTEGER NOT NULL,
        facts_json TEXT NOT NULL,
        experience_json TEXT NOT NULL DEFAULT '[]',
        unexpected_json TEXT NOT NULL DEFAULT '[]',
        source_refs_json TEXT NOT NULL DEFAULT '[]',
        user_interpretation TEXT,
        verdict TEXT NOT NULL DEFAULT 'unreviewed'
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_todo_binding (
        id TEXT PRIMARY KEY,
        action_id TEXT NOT NULL UNIQUE,
        todo_task_id TEXT NOT NULL,
        todo_list_id TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL,
        last_checked_at_ms INTEGER NOT NULL DEFAULT 0
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_alert (
        id TEXT PRIMARY KEY,
        campaign_id TEXT,
        problem_id TEXT,
        state TEXT NOT NULL,
        alert_type TEXT NOT NULL,
        reason TEXT NOT NULL,
        default_action TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'open',
        ignored_count INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        resolved_at_ms INTEGER
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_battle_review (
        id TEXT PRIMARY KEY,
        campaign_id TEXT,
        problem_id TEXT,
        prewar_model_json TEXT NOT NULL DEFAULT '{}',
        strategy_json TEXT NOT NULL DEFAULT '{}',
        predictions_json TEXT NOT NULL DEFAULT '[]',
        turning_points_json TEXT NOT NULL DEFAULT '[]',
        outcome_json TEXT NOT NULL DEFAULT '{}',
        lessons_json TEXT NOT NULL DEFAULT '[]',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_error_episode (
        id TEXT PRIMARY KEY,
        campaign_id TEXT,
        problem_id TEXT,
        error_layer TEXT NOT NULL,
        trigger_context TEXT NOT NULL,
        consequence TEXT NOT NULL,
        earlier_signal TEXT NOT NULL,
        evidence_refs_json TEXT NOT NULL DEFAULT '[]',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_personal_rule (
        id TEXT PRIMARY KEY,
        rule_text TEXT NOT NULL,
        scope TEXT NOT NULL,
        evidence_count INTEGER NOT NULL DEFAULT 0,
        counterexample_count INTEGER NOT NULL DEFAULT 0,
        epistemic_status TEXT NOT NULL,
        version_no INTEGER NOT NULL DEFAULT 1,
        supersedes_id TEXT,
        last_validated_at_ms INTEGER,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_ai_error (
        id TEXT PRIMARY KEY,
        model_run_id TEXT NOT NULL,
        wrong_claim_id TEXT,
        discovered_by TEXT NOT NULL,
        impact TEXT NOT NULL,
        correction TEXT NOT NULL,
        corrected_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_model_run (
        id TEXT PRIMARY KEY,
        agent_id TEXT NOT NULL,
        provider TEXT NOT NULL,
        model TEXT NOT NULL,
        prompt_version TEXT NOT NULL,
        input_refs_json TEXT NOT NULL DEFAULT '[]',
        output_hash TEXT,
        output_json TEXT,
        status TEXT NOT NULL,
        error TEXT,
        latency_ms INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_knowledge_source (
        id TEXT PRIMARY KEY,
        layer TEXT NOT NULL,
        kind TEXT NOT NULL,
        title TEXT NOT NULL,
        version TEXT NOT NULL,
        status TEXT NOT NULL,
        content_hash TEXT NOT NULL DEFAULT '',
        sensitivity TEXT NOT NULL DEFAULT 'normal',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_knowledge_document (
        id TEXT PRIMARY KEY,
        source_id TEXT NOT NULL,
        local_uri TEXT NOT NULL,
        mime TEXT NOT NULL,
        parse_status TEXT NOT NULL,
        index_status TEXT NOT NULL,
        checksum TEXT NOT NULL,
        byte_size INTEGER NOT NULL DEFAULT 0,
        last_error TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_knowledge_passage (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        source_id TEXT NOT NULL,
        chapter TEXT NOT NULL DEFAULT '',
        section TEXT NOT NULL DEFAULT '',
        locator TEXT NOT NULL,
        original_text TEXT NOT NULL DEFAULT '',
        translation TEXT NOT NULL DEFAULT '',
        page_range TEXT NOT NULL DEFAULT '',
        text_kind TEXT NOT NULL DEFAULT 'source_text',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_knowledge_node (
        id TEXT PRIMARY KEY,
        source_id TEXT NOT NULL,
        layer TEXT NOT NULL,
        node_type TEXT NOT NULL,
        name TEXT NOT NULL,
        definition TEXT NOT NULL,
        status TEXT NOT NULL,
        provenance_json TEXT NOT NULL DEFAULT '{}',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_knowledge_edge (
        id TEXT PRIMARY KEY,
        from_id TEXT NOT NULL,
        to_id TEXT NOT NULL,
        relation_type TEXT NOT NULL,
        provenance_json TEXT NOT NULL DEFAULT '{}',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_knowledge_rule (
        id TEXT PRIMARY KEY,
        source_id TEXT NOT NULL,
        rule_code TEXT NOT NULL UNIQUE,
        severity TEXT NOT NULL,
        condition_json TEXT NOT NULL,
        action_json TEXT NOT NULL,
        version TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        protected INTEGER NOT NULL DEFAULT 1,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_rule_source_binding (
        id TEXT PRIMARY KEY,
        rule_id TEXT NOT NULL,
        passage_id TEXT,
        requirement_id TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_provider_capability (
        provider_id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        persistent_file INTEGER NOT NULL,
        store INTEGER NOT NULL,
        supports_delete INTEGER NOT NULL,
        reuse INTEGER NOT NULL,
        citation INTEGER NOT NULL,
        structured_output INTEGER NOT NULL,
        max_file_size INTEGER NOT NULL DEFAULT 0,
        max_total_storage INTEGER NOT NULL DEFAULT 0,
        retention_policy TEXT NOT NULL,
        indexing_mode TEXT NOT NULL,
        verified INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_provider_file (
        id TEXT PRIMARY KEY,
        provider_id TEXT NOT NULL,
        source_id TEXT NOT NULL,
        remote_file_id TEXT NOT NULL DEFAULT '',
        remote_store_id TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        uploaded_at_ms INTEGER NOT NULL DEFAULT 0,
        expires_at_ms INTEGER NOT NULL DEFAULT 0,
        retention_info TEXT NOT NULL DEFAULT '',
        last_error TEXT NOT NULL DEFAULT '',
        updated_at_ms INTEGER NOT NULL,
        UNIQUE(provider_id, source_id)
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_provider_store (
        id TEXT PRIMARY KEY,
        provider_id TEXT NOT NULL,
        remote_store_id TEXT NOT NULL,
        name TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_provider_binding (
        id TEXT PRIMARY KEY,
        provider_file_id TEXT NOT NULL,
        provider_store_id TEXT NOT NULL,
        status TEXT NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_knowledge_sync_job (
        id TEXT PRIMARY KEY,
        provider_id TEXT NOT NULL,
        source_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        state TEXT NOT NULL,
        error TEXT NOT NULL DEFAULT '',
        retry_count INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_retrieval_trace (
        id TEXT PRIMARY KEY,
        request_id TEXT NOT NULL,
        object_refs_json TEXT NOT NULL,
        route_plan_json TEXT NOT NULL,
        sources_used_json TEXT NOT NULL,
        rejected_sources_json TEXT NOT NULL,
        conflicts_json TEXT NOT NULL,
        rule_ids_json TEXT NOT NULL,
        debt_ids_json TEXT NOT NULL,
        state TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_knowledge_use_record (
        id TEXT PRIMARY KEY,
        retrieval_trace_id TEXT NOT NULL,
        model_run_id TEXT,
        rule_ids_json TEXT NOT NULL DEFAULT '[]',
        node_ids_json TEXT NOT NULL DEFAULT '[]',
        passage_ids_json TEXT NOT NULL DEFAULT '[]',
        personal_case_ids_json TEXT NOT NULL DEFAULT '[]',
        provider_file_ids_json TEXT NOT NULL DEFAULT '[]',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_candidate_knowledge (
        id TEXT PRIMARY KEY,
        statement TEXT NOT NULL,
        origin_run_id TEXT,
        supporting_refs_json TEXT NOT NULL DEFAULT '[]',
        counter_refs_json TEXT NOT NULL DEFAULT '[]',
        validation_plan TEXT NOT NULL DEFAULT '',
        scope TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        version_no INTEGER NOT NULL DEFAULT 1,
        last_validated_at_ms INTEGER,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_knowledge_conflict (
        id TEXT PRIMARY KEY,
        left_ref TEXT NOT NULL,
        right_ref TEXT NOT NULL,
        conflict_type TEXT NOT NULL,
        impact TEXT NOT NULL,
        resolution_status TEXT NOT NULL DEFAULT 'unresolved',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_audit_log (
        id TEXT PRIMARY KEY,
        object_type TEXT NOT NULL,
        object_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        actor TEXT NOT NULL,
        before_json TEXT NOT NULL DEFAULT '{}',
        after_json TEXT NOT NULL DEFAULT '{}',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_input_classification (
        id TEXT PRIMARY KEY,
        raw_event_id TEXT NOT NULL,
        input_text TEXT NOT NULL,
        input_type TEXT NOT NULL,
        updates_existing_problem INTEGER NOT NULL DEFAULT 0,
        target_problem_id TEXT NOT NULL DEFAULT '',
        reason TEXT NOT NULL,
        confidence REAL NOT NULL DEFAULT 0,
        classified_by TEXT NOT NULL DEFAULT 'A13_LOCAL_GUARD',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_problem_state_version (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        version_no INTEGER NOT NULL,
        lifecycle_state TEXT NOT NULL,
        facts_json TEXT NOT NULL DEFAULT '[]',
        unknowns_json TEXT NOT NULL DEFAULT '[]',
        assumptions_json TEXT NOT NULL DEFAULT '[]',
        constraints_json TEXT NOT NULL DEFAULT '[]',
        key_gap TEXT NOT NULL DEFAULT '',
        current_hypotheses_json TEXT NOT NULL DEFAULT '[]',
        selected_operator_json TEXT NOT NULL DEFAULT '{}',
        resolved_items_json TEXT NOT NULL DEFAULT '[]',
        current_focus TEXT NOT NULL DEFAULT '',
        current_experiment TEXT NOT NULL DEFAULT '',
        next_verification TEXT NOT NULL DEFAULT '',
        generated_by TEXT NOT NULL,
        source_refs_json TEXT NOT NULL DEFAULT '[]',
        stale_reason TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL,
        UNIQUE(problem_id, version_no)
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_solution_attempt (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        state_version_id TEXT NOT NULL,
        action_id TEXT NOT NULL DEFAULT '',
        operator_id TEXT NOT NULL DEFAULT '',
        rationale TEXT NOT NULL,
        prediction_id TEXT NOT NULL DEFAULT '',
        started_at_ms INTEGER NOT NULL DEFAULT 0,
        ended_at_ms INTEGER NOT NULL DEFAULT 0,
        outcome_ref TEXT NOT NULL DEFAULT '',
        result_class TEXT NOT NULL DEFAULT 'PENDING',
        failure_layer TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'PLANNED',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_hypothesis (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        effect_ref TEXT NOT NULL DEFAULT '',
        statement TEXT NOT NULL,
        mechanism TEXT NOT NULL DEFAULT '',
        support_refs_json TEXT NOT NULL DEFAULT '[]',
        counter_refs_json TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL DEFAULT 'PROPOSED',
        scope TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_hypothesis_test (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        hypothesis_ids_json TEXT NOT NULL DEFAULT '[]',
        discriminating_action_id TEXT NOT NULL DEFAULT '',
        expected_patterns_json TEXT NOT NULL DEFAULT '[]',
        result_ref TEXT NOT NULL DEFAULT '',
        conclusion TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'TEST_DESIGNED',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_case_comparison (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        situation_model_id TEXT NOT NULL,
        purpose TEXT NOT NULL,
        current_case_refs_json TEXT NOT NULL DEFAULT '[]',
        historical_case_refs_json TEXT NOT NULL DEFAULT '[]',
        similarities_json TEXT NOT NULL DEFAULT '[]',
        differences_json TEXT NOT NULL DEFAULT '[]',
        decisive_differences_json TEXT NOT NULL DEFAULT '[]',
        conclusion TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_relevant_difference (
        id TEXT PRIMARY KEY,
        comparison_id TEXT NOT NULL,
        feature TEXT NOT NULL,
        why_it_matters TEXT NOT NULL,
        evidence_refs_json TEXT NOT NULL DEFAULT '[]',
        impact_on_decision TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_concept_reality_conflict (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        concept_version_id TEXT NOT NULL DEFAULT '',
        reality_refs_json TEXT NOT NULL DEFAULT '[]',
        mismatch_pattern TEXT NOT NULL,
        repetitions INTEGER NOT NULL DEFAULT 1,
        impact TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'MISMATCH_DETECTED',
        review_result TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_cognitive_experience (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        situation_model_id TEXT NOT NULL,
        trigger TEXT NOT NULL,
        sck_rule_ids_json TEXT NOT NULL DEFAULT '[]',
        headline TEXT NOT NULL,
        user_message TEXT NOT NULL,
        presentation_type TEXT NOT NULL,
        details_json TEXT NOT NULL DEFAULT '{}',
        method_text TEXT NOT NULL DEFAULT '',
        transfer_prompt TEXT NOT NULL DEFAULT '',
        linked_claims_json TEXT NOT NULL DEFAULT '[]',
        user_viewed INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_method_experience (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        cognitive_experience_id TEXT NOT NULL,
        method_id TEXT NOT NULL,
        context TEXT NOT NULL,
        explanation TEXT NOT NULL,
        user_viewed INTEGER NOT NULL DEFAULT 0,
        user_response TEXT NOT NULL DEFAULT '',
        transfer_prompt TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_learning_moment (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        old_model TEXT NOT NULL,
        new_reality TEXT NOT NULL,
        revised_model TEXT NOT NULL,
        method_learned TEXT NOT NULL,
        evidence_refs_json TEXT NOT NULL DEFAULT '[]',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_backtrack_event (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        attempt_id TEXT NOT NULL DEFAULT '',
        earliest_failed_layer TEXT NOT NULL,
        old_ref TEXT NOT NULL DEFAULT '',
        new_ref TEXT NOT NULL DEFAULT '',
        reason TEXT NOT NULL,
        evidence_refs_json TEXT NOT NULL DEFAULT '[]',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_explanation_card (
        id TEXT PRIMARY KEY,
        problem_id TEXT NOT NULL,
        situation_model_id TEXT NOT NULL,
        target_ref TEXT NOT NULL,
        headline TEXT NOT NULL,
        facts_json TEXT NOT NULL DEFAULT '[]',
        interpretation TEXT NOT NULL,
        counterevidence_json TEXT NOT NULL DEFAULT '[]',
        weakest_premise TEXT NOT NULL DEFAULT '',
        uncertainty TEXT NOT NULL DEFAULT '',
        what_changes_it TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS xf_problem_alias (
        alias_problem_id TEXT PRIMARY KEY,
        canonical_problem_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_xf_experience_problem ON xf_experience(problem_id, created_at_ms)',
    'CREATE INDEX IF NOT EXISTS idx_xf_claim_problem ON xf_claim(problem_id, epistemic_status)',
    'CREATE INDEX IF NOT EXISTS idx_xf_grounding_claim ON xf_grounding_relation(claim_id)',
    'CREATE INDEX IF NOT EXISTS idx_xf_grounding_ref ON xf_grounding_relation(ground_ref_id)',
    'CREATE INDEX IF NOT EXISTS idx_xf_debt_problem ON xf_epistemic_debt(problem_id, status)',
    'CREATE INDEX IF NOT EXISTS idx_xf_problem_state ON xf_problem(state, updated_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_problem_item ON xf_problem_item(problem_id, kind, sort_order)',
    'CREATE INDEX IF NOT EXISTS idx_xf_situation_object ON xf_situation_model(object_type, object_id, version_no DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_inference_problem ON xf_ai_inference(problem_id, status, created_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_info_need_problem ON xf_information_need(problem_id, status, evsi_rank DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_agent_run_problem ON xf_agent_run(problem_id, started_at_ms)',
    'CREATE INDEX IF NOT EXISTS idx_xf_artifact_problem ON xf_reasoning_artifact(problem_id, status, created_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_decision_problem ON xf_decision_draft(problem_id, updated_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_campaign_primary ON xf_campaign(is_primary, state)',
    'CREATE INDEX IF NOT EXISTS idx_xf_action_current ON xf_action(state, updated_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_passage_source ON xf_knowledge_passage(source_id, locator)',
    'CREATE INDEX IF NOT EXISTS idx_xf_node_source ON xf_knowledge_node(source_id, layer)',
    'CREATE INDEX IF NOT EXISTS idx_xf_edge_from ON xf_knowledge_edge(from_id, relation_type)',
    'CREATE INDEX IF NOT EXISTS idx_xf_provider_source ON xf_provider_file(source_id, provider_id)',
    'CREATE INDEX IF NOT EXISTS idx_xf_trace_request ON xf_retrieval_trace(request_id, created_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_input_problem ON xf_input_classification(target_problem_id, created_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_problem_version ON xf_problem_state_version(problem_id, version_no DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_attempt_problem ON xf_solution_attempt(problem_id, created_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_hypothesis_problem ON xf_hypothesis(problem_id, status)',
    'CREATE INDEX IF NOT EXISTS idx_xf_hypothesis_test_problem ON xf_hypothesis_test(problem_id, created_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_case_problem ON xf_case_comparison(problem_id, created_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_conflict_problem ON xf_concept_reality_conflict(problem_id, status)',
    'CREATE INDEX IF NOT EXISTS idx_xf_cel_problem ON xf_cognitive_experience(problem_id, created_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_learning_problem ON xf_learning_moment(problem_id, created_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_backtrack_problem ON xf_backtrack_event(problem_id, created_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_explanation_problem ON xf_explanation_card(problem_id, created_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_method_problem ON xf_method_event(problem_id, created_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_method_capability ON xf_method_event(method_id, created_at_ms DESC)',
  ];

  Future<void> _seedPracticalProductData(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const sourceId = XiangjiPracticalProductContract.knowledgeSourceId;
    await db.update(
      'xf_knowledge_source',
      <String, Object?>{
        'status': 'retired',
        'updated_at_ms': now,
      },
      where: 'kind = ? AND id != ?',
      whereArgs: <Object?>['product_operating_guide', sourceId],
    );
    await db.insert(
      'xf_knowledge_source',
      <String, Object?>{
        'id': sourceId,
        'layer': 'K1',
        'kind': 'product_operating_guide',
        'title': '向己·未来军师 V6.3 叔本华知识到现实成果',
        'version': XiangjiPracticalProductContract.version,
        'status': 'active',
        'content_hash': 'bundled-practical-contract-v6.3',
        'sensitivity': 'normal',
        'created_at_ms': 1,
        'updated_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    for (final guide in XiangjiPracticalProductContract.featureGuides) {
      final nodeId = 'XF-GUIDE-${guide.id}';
      await db.insert(
        'xf_knowledge_node',
        <String, Object?>{
          'id': nodeId,
          'source_id': sourceId,
          'layer': 'K1',
          'node_type': 'product_feature_guide',
          'name': guide.title,
          'definition': '${guide.what}\n${guide.output}',
          'status': 'active',
          'provenance_json': jsonEncode(guide.toPromptMap()),
          'created_at_ms': 1,
          'updated_at_ms': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final conceptId in guide.coreConceptIds) {
        await db.insert(
          'xf_knowledge_edge',
          <String, Object?>{
            'id': '$conceptId-GUIDES-${guide.id}',
            'from_id': conceptId,
            'to_id': nodeId,
            'relation_type': 'L0_GROUNDS_FEATURE',
            'provenance_json': jsonEncode(<String, Object?>{
              'product_contract': XiangjiPracticalProductContract.version,
              'knowledge_source': guide.knowledgeSource,
            }),
            'created_at_ms': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    for (final example in XiangjiPracticalProductContract.guidedCases) {
      await db.insert(
        'xf_guided_case',
        example.toDatabaseMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final caseNodeId = 'XF-CASE-${example.id}';
      await db.insert(
        'xf_knowledge_node',
        <String, Object?>{
          'id': caseNodeId,
          'source_id': sourceId,
          'layer': 'K4',
          'node_type': 'guided_complete_case',
          'name': example.title,
          'definition': '${example.summary}\n${example.revision}',
          'status': 'active',
          'provenance_json': jsonEncode(example.toDatabaseMap()),
          'created_at_ms': 1,
          'updated_at_ms': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final conceptId in example.coreConceptIds) {
        await db.insert(
          'xf_knowledge_edge',
          <String, Object?>{
            'id': '$conceptId-EXPLAINS-${example.id}',
            'from_id': conceptId,
            'to_id': caseNodeId,
            'relation_type': 'L0_EXPLAINS_CASE',
            'provenance_json': jsonEncode(<String, Object?>{
              'source_label': example.sourceLabel,
            }),
            'created_at_ms': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  Future<void> _seedCoreKnowledge(Database db) async {
    final existing = await db.query(
      'xf_knowledge_source',
      columns: <String>['id'],
      where: 'id = ?',
      whereArgs: <Object?>['XF-K0-SCHOPENHAUER'],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.insert('xf_knowledge_source', <String, Object?>{
        'id': 'XF-K0-SCHOPENHAUER',
        'layer': 'K0',
        'kind': 'original_source_framework',
        'title': '叔本华认识论内核 - 《作为意志和表象的世界》第一篇',
        'version': 'V6.1-Rev4',
        'status': 'active',
        'content_hash': 'bundled-k0-v6.1-rev4',
        'sensitivity': 'normal',
        'created_at_ms': now,
        'updated_at_ms': now,
      });
      await txn.insert('xf_knowledge_document', <String, Object?>{
        'id': 'XF-K0-DOC-WWR-I',
        'source_id': 'XF-K0-SCHOPENHAUER',
        'local_uri': 'bundled://k0/schopenhauer/wwr-book-1',
        'mime': 'application/x-structured-knowledge',
        'parse_status': 'READY',
        'index_status': 'READY',
        'checksum': 'bundled-k0-v6.1-rev4',
        'byte_size': 0,
        'last_error': '',
        'created_at_ms': now,
        'updated_at_ms': now,
      });
      final passages = <Map<String, Object?>>[
        <String, Object?>{
          'id': 'XF-K0-PASSAGE-09',
          'chapter': '第一篇',
          'section': '§9',
          'locator': '《作为意志和表象的世界》第一篇 §9',
          'translation': '内容要旨（非逐字引文）：概念是表象的表象，抽象认识必须保留它所依赖的直观或其他表象关系。',
        },
        <String, Object?>{
          'id': 'XF-K0-PASSAGE-14',
          'chapter': '第一篇',
          'section': '§14',
          'locator': '《作为意志和表象的世界》第一篇 §14',
          'translation': '内容要旨（非逐字引文）：科学的特征在于知识的系统联系；系统性本身并不把薄弱根据变成更确定的现实认识。',
        },
        <String, Object?>{
          'id': 'XF-K0-PASSAGE-15',
          'chapter': '第一篇',
          'section': '§15',
          'locator': '《作为意志和表象的世界》第一篇 §15',
          'translation': '内容要旨（非逐字引文）：证明在概念关系中推进；若前提缺乏认识根据，较长的推导不能补救其现实基础。',
        },
        <String, Object?>{
          'id': 'XF-K0-PASSAGE-JUDGMENT',
          'chapter': '第一篇',
          'section': '判断力相关论述',
          'locator': '《作为意志和表象的世界》第一篇 - 判断力连接直观与抽象的论述',
          'translation': '内容要旨（非逐字引文）：判断力把直观中认识到的同异按当前目的准确转移到抽象意识中。',
        },
      ];
      for (final passage in passages) {
        await txn.insert('xf_knowledge_passage', <String, Object?>{
          ...passage,
          'document_id': 'XF-K0-DOC-WWR-I',
          'source_id': 'XF-K0-SCHOPENHAUER',
          'original_text': '',
          'page_range': '',
          'text_kind': 'verified_locator_summary',
          'created_at_ms': now,
        });
      }
      final rules = _coreRuleSeeds;
      for (final rule in rules) {
        final code = rule['code']!;
        final ruleId = 'XF-$code';
        await txn.insert('xf_knowledge_rule', <String, Object?>{
          'id': ruleId,
          'source_id': 'XF-K0-SCHOPENHAUER',
          'rule_code': code,
          'severity': rule['severity'],
          'condition_json': jsonEncode(<String, Object?>{
            'description': rule['condition'],
          }),
          'action_json': jsonEncode(<String, Object?>{
            'description': rule['action'],
          }),
          'version': 'V6.1-Rev4',
          'enabled': 1,
          'protected': 1,
          'created_at_ms': now,
          'updated_at_ms': now,
        });
        final requirementIds = rule['requirements']!.split(',');
        for (final requirement in requirementIds) {
          await txn.insert('xf_rule_source_binding', <String, Object?>{
            'id': '$ruleId-${requirement.trim()}',
            'rule_id': ruleId,
            'passage_id': rule['passage'],
            'requirement_id': requirement.trim(),
            'created_at_ms': now,
          });
        }
      }
    });
    await rebuildPassageIndex(db);
  }

  Future<void> _ensureRev3SckRules(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        'xf_knowledge_source',
        <String, Object?>{
          'version': 'V6.1-Rev3',
          'content_hash': 'bundled-k0-v6.1-rev3',
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>['XF-K0-SCHOPENHAUER'],
      );
      for (final rule in _coreRuleSeeds.where(
        (item) => (item['code'] ?? '').startsWith('SCK-'),
      )) {
        final code = rule['code']!;
        final ruleId = 'XF-$code';
        await txn.insert(
          'xf_knowledge_rule',
          <String, Object?>{
            'id': ruleId,
            'source_id': 'XF-K0-SCHOPENHAUER',
            'rule_code': code,
            'severity': rule['severity'],
            'condition_json': jsonEncode(<String, Object?>{
              'description': rule['condition'],
            }),
            'action_json': jsonEncode(<String, Object?>{
              'description': rule['action'],
            }),
            'version': 'V6.1-Rev3',
            'enabled': 1,
            'protected': 1,
            'created_at_ms': now,
            'updated_at_ms': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        for (final requirement in rule['requirements']!.split(',')) {
          await txn.insert(
            'xf_rule_source_binding',
            <String, Object?>{
              'id': '$ruleId-${requirement.trim()}',
              'rule_id': ruleId,
              'passage_id': rule['passage'],
              'requirement_id': requirement.trim(),
              'created_at_ms': now,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    });
  }

  Future<void> _ensureRev4Rules(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        'xf_knowledge_source',
        <String, Object?>{
          'version': 'V6.1-Rev4',
          'content_hash': 'bundled-k0-v6.1-rev4',
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>['XF-K0-SCHOPENHAUER'],
      );
      await txn.update(
        'xf_knowledge_document',
        <String, Object?>{
          'checksum': 'bundled-k0-v6.1-rev4',
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>['XF-K0-DOC-WWR-I'],
      );
      for (final rule in _rev4RuleSeeds) {
        final code = rule['code']!;
        final ruleId = 'XF-$code';
        await txn.insert(
          'xf_knowledge_rule',
          <String, Object?>{
            'id': ruleId,
            'source_id': 'XF-K0-SCHOPENHAUER',
            'rule_code': code,
            'severity': rule['severity'],
            'condition_json': jsonEncode(<String, Object?>{
              'description': rule['condition'],
            }),
            'action_json': jsonEncode(<String, Object?>{
              'description': rule['action'],
            }),
            'version': 'V6.1-Rev4',
            'enabled': 1,
            'protected': 1,
            'created_at_ms': now,
            'updated_at_ms': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          'xf_rule_source_binding',
          <String, Object?>{
            'id': '$ruleId-${rule['requirement']}',
            'rule_id': ruleId,
            'passage_id': rule['passage'],
            'requirement_id': rule['requirement'],
            'created_at_ms': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  /// Rev.5.2 keeps the protected Rev3/Rev4 rule set and advances its package
  /// identity only after those migrations have completed. This is idempotent
  /// for both fresh installs and databases upgraded in place.
  Future<void> _ensureRev52Metadata(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'xf_knowledge_source',
      <String, Object?>{
        'title': '叔本华 L0 认识论操作系统 - V5.0 核心合同',
        'version': XiangjiSchopenhauerCoreCatalog.version,
        'content_hash': 'bundled-k0-v6.1-rev5.2-schopenhauer-v5-core',
        'updated_at_ms': now,
      },
      where: 'id = ?',
      whereArgs: const <Object?>['XF-K0-SCHOPENHAUER'],
    );
    await db.update(
      'xf_knowledge_document',
      <String, Object?>{
        'checksum': 'bundled-k0-v6.1-rev5.2-schopenhauer-v5-core',
        'updated_at_ms': now,
      },
      where: 'id = ?',
      whereArgs: const <Object?>['XF-K0-DOC-WWR-I'],
    );
    await db.update(
      'xf_knowledge_rule',
      <String, Object?>{
        'version': XiangjiSchopenhauerCoreCatalog.version,
        'updated_at_ms': now,
      },
      where: 'source_id = ?',
      whereArgs: const <Object?>['XF-K0-SCHOPENHAUER'],
    );
    await db.transaction((txn) async {
      for (final concept in XiangjiSchopenhauerCoreCatalog.entries) {
        await txn.insert(
          'xf_knowledge_node',
          <String, Object?>{
            'id': concept.id,
            'source_id': XiangjiSchopenhauerCoreCatalog.sourceId,
            'layer': 'K0',
            'node_type': concept.nodeType,
            'name': concept.displayName,
            'definition': concept.definition,
            'status': 'ACTIVE',
            'provenance_json': jsonEncode(<String, Object?>{
              'version': XiangjiSchopenhauerCoreCatalog.version,
              'product_contract':
                  XiangjiSchopenhauerCoreCatalog.productContract,
              'category': concept.category,
              'concept_kind': concept.conceptKind,
              'original_term': concept.originalTerm,
              'operational_rule': concept.operationalRule,
              'feature_bindings': concept.featureBindings,
              'related_rule_ids': concept.relatedRuleIds,
              'source_locator': concept.sourceLocator,
              'passage_ids': concept.passageIds,
            }),
            'created_at_ms': now,
            'updated_at_ms': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.insert(
        'xf_knowledge_source',
        <String, Object?>{
          'id': XiangjiMethodCatalog.sourceId,
          'layer': 'K1',
          'kind': 'product_method_catalog',
          'title': '未来军师 Rev5.2 运行能力目录（受叔本华 L0 约束）',
          'version': XiangjiMethodCatalog.version,
          'status': 'active',
          'content_hash': 'bundled-method-catalog-v6.1-rev5.2-l0-v5',
          'sensitivity': 'normal',
          'created_at_ms': now,
          'updated_at_ms': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'xf_knowledge_document',
        <String, Object?>{
          'id': XiangjiMethodCatalog.documentId,
          'source_id': XiangjiMethodCatalog.sourceId,
          'local_uri':
              'asset://assets/xiangji_future_strategist/signature_method_capabilities_rev5_2.json',
          'mime': 'application/json',
          'parse_status': 'READY',
          'index_status': 'READY',
          'checksum': 'bundled-method-catalog-v6.1-rev5.2-l0-v5',
          'byte_size': 0,
          'last_error': '',
          'created_at_ms': now,
          'updated_at_ms': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final method in XiangjiMethodCatalog.entries) {
        await txn.insert(
          'xf_knowledge_node',
          <String, Object?>{
            'id': method.id,
            'source_id': XiangjiMethodCatalog.sourceId,
            'layer': method.layer,
            'node_type': method.nodeType,
            'name': method.displayName,
            'definition': method.principle,
            'status': 'ACTIVE',
            'provenance_json': jsonEncode(<String, Object?>{
              'version': XiangjiMethodCatalog.version,
              'english_name': method.englishName,
              'domain': method.domain,
              'source_concept': method.sourceConcept,
              'source_locator': method.sourceLocator,
              'passage_ids': method.passageIds,
              'related_rule_ids': method.relatedRuleIds,
              'core_concept_ids': method.coreConceptIds,
              'core_concept_names': method.coreConceptNames,
              'trigger_summary': method.triggerSummary,
              'state_effect': method.stateEffect,
              'reality_test': method.realityTest,
              'transfer_question': method.transferQuestion,
              'product_contract': XiangjiMethodCatalog.productContract,
            }),
            'created_at_ms': now,
            'updated_at_ms': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (final coreConceptId in method.coreConceptIds) {
          await txn.insert(
            'xf_knowledge_edge',
            <String, Object?>{
              'id': '$coreConceptId-constrains-${method.id}',
              'from_id': coreConceptId,
              'to_id': method.id,
              'relation_type': 'L0_CONSTRAINS_METHOD',
              'provenance_json': jsonEncode(<String, Object?>{
                'product_contract':
                    XiangjiSchopenhauerCoreCatalog.productContract,
                'meaning': '该运行能力必须遵守这一叔本华 L0 认识边界',
              }),
              'created_at_ms': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      final architectureEdges = <Map<String, String>>[
        <String, String>{
          'from': 'SC-K0-001',
          'to': 'SC-K0-005',
          'relation': 'REALITY_REQUIRES_GROUNDING',
        },
        <String, String>{
          'from': 'SC-K0-005',
          'to': 'SC-K0-002',
          'relation': 'GROUNDING_AUTHORISES_ABSTRACTION',
        },
        <String, String>{
          'from': 'SC-K0-002',
          'to': 'MEC-011',
          'relation': 'ABSTRACTION_FRAMES_SOLVABLE_GAP',
        },
        <String, String>{
          'from': 'MEC-011',
          'to': 'MEC-012',
          'relation': 'GAP_DECOMPOSES_TO_ACTION',
        },
        <String, String>{
          'from': 'MEC-012',
          'to': 'MEC-013',
          'relation': 'ACTION_REQUIRES_PREDICTION',
        },
        <String, String>{
          'from': 'MEC-013',
          'to': 'SC-K0-024',
          'relation': 'REALITY_TESTS_ABSTRACTION',
        },
        <String, String>{
          'from': 'SC-K0-024',
          'to': 'SC-K0-001',
          'relation': 'REVISION_RETURNS_TO_EXPERIENCE',
        },
      ];
      for (final edge in architectureEdges) {
        final from = edge['from']!;
        final to = edge['to']!;
        final relation = edge['relation']!;
        await txn.insert(
          'xf_knowledge_edge',
          <String, Object?>{
            'id': 'v5-architecture-$from-$to',
            'from_id': from,
            'to_id': to,
            'relation_type': relation,
            'provenance_json': jsonEncode(<String, Object?>{
              'product_contract':
                  XiangjiSchopenhauerCoreCatalog.productContract,
              'architecture': XiangjiSchopenhauerCoreCatalog.frozenArchitecture,
            }),
            'created_at_ms': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static const List<Map<String, String>> _rev4RuleSeeds =
      <Map<String, String>>[
    <String, String>{
      'code': 'CEL-001',
      'severity': 'P0',
      'condition': '高影响SCK机制已经运行但用户看不到其作用',
      'action': '生成自然语言CognitiveExperience并进入双层交互',
      'requirement': 'CEL-001',
      'passage': 'XF-K0-PASSAGE-09',
    },
    <String, String>{
      'code': 'CEL-002',
      'severity': 'P0',
      'condition': '体验、观察、用户解释或AI判断可能混写',
      'action': '分别展示实际发生、真实体验、用户解释和军师判断',
      'requirement': 'CEL-002',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'CEL-003',
      'severity': 'P0',
      'condition': '形成关于用户或现实的高影响AI判断',
      'action': '明确标为当前可修订理解并显示改变判断的现实',
      'requirement': 'CEL-003',
      'passage': 'XF-K0-PASSAGE-09',
    },
    <String, String>{
      'code': 'CEL-004',
      'severity': 'P0',
      'condition': '重要结果需要归因',
      'action': '展示多个机制不同的候选原因及区分实验',
      'requirement': 'CEL-004',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'CEL-005',
      'severity': 'P0',
      'condition': '准备复用历史案例、旧标签或概念',
      'action': '显示目标相关相同点、关键差异及对下一步的影响',
      'requirement': 'CEL-005',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'CEL-006',
      'severity': 'P0',
      'condition': '用户展开高影响建议的原因',
      'action': '下钻事实、体验、反例、最弱前提、未知和改变信号',
      'requirement': 'CEL-006',
      'passage': 'XF-K0-PASSAGE-15',
    },
    <String, String>{
      'code': 'CEL-007',
      'severity': 'P0',
      'condition': '形成个人标签或抽象概念',
      'action': '同时显示支持例、反例、适用边界和未解释细节',
      'requirement': 'CEL-007',
      'passage': 'XF-K0-PASSAGE-09',
    },
    <String, String>{
      'code': 'CEL-008',
      'severity': 'P1',
      'condition': '用户报告说不清但不对劲的体验',
      'action': '先保存未概念化体验并收集场景，不强迫立即命名',
      'requirement': 'CEL-008',
      'passage': 'XF-K0-PASSAGE-09',
    },
    <String, String>{
      'code': 'CEL-009',
      'severity': 'P0',
      'condition': '概念、规则或预测持续不能解释现实',
      'action': '呈现现实正在挑战旧解释并启动回溯复核',
      'requirement': 'CEL-009',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'CEL-010',
      'severity': 'P0',
      'condition': '模型或报告结构复杂完整',
      'action': '体系完整度与认识根据强度分开显示',
      'requirement': 'CEL-010',
      'passage': 'XF-K0-PASSAGE-14',
    },
    <String, String>{
      'code': 'CEL-011',
      'severity': 'P0',
      'condition': '推理形式成立但关键前提未获现实支持',
      'action': '显示逻辑成立不等于现实已证明及最弱前提',
      'requirement': 'CEL-011',
      'passage': 'XF-K0-PASSAGE-15',
    },
    <String, String>{
      'code': 'CEL-012',
      'severity': 'P0',
      'condition': '推荐关键行动',
      'action': '用用户语言说明行动机制、目标差距和可观察预测',
      'requirement': 'CEL-012',
      'passage': 'XF-K0-PASSAGE-15',
    },
    <String, String>{
      'code': 'CEL-013',
      'severity': 'P1',
      'condition': '用户按需展开为什么或方法',
      'action': '结合当前真实问题解释方法，不展示独立课程墙',
      'requirement': 'CEL-013',
      'passage': 'XF-K0-PASSAGE-14',
    },
    <String, String>{
      'code': 'CEL-014',
      'severity': 'P1',
      'condition': '现实促成重要模型修订',
      'action': '保存旧认识、新现实、修订模型和可迁移方法',
      'requirement': 'CEL-014',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'CEL-015',
      'severity': 'P1',
      'condition': '用户开启方法训练模式',
      'action': '提供与当前问题相关的一步迁移练习并由AI反馈',
      'requirement': 'CEL-015',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'CEL-016',
      'severity': 'P0',
      'condition': '生产前台准备显示内部对象名或JSON',
      'action': '隔离开发者语言，只呈现自然语言认知体验',
      'requirement': 'CEL-016',
      'passage': 'XF-K0-PASSAGE-09',
    },
    <String, String>{
      'code': 'CEL-017',
      'severity': 'P0',
      'condition': '军师形成下一步和解释',
      'action': '第一层直接回答现在怎么办，第二层按需展示原因、证据和方法',
      'requirement': 'CEL-017',
      'passage': 'XF-K0-PASSAGE-14',
    },
    <String, String>{
      'code': 'CEL-018',
      'severity': 'P0',
      'condition': '声明SCK功能已完成',
      'action': '后台执行与用户体验两侧都必须通过验收',
      'requirement': 'CEL-018',
      'passage': 'XF-K0-PASSAGE-14',
    },
    <String, String>{
      'code': 'PS-016',
      'severity': 'P0',
      'condition': '新输入与当前核心问题相关',
      'action': '复用稳定problem_id并写入新状态版本',
      'requirement': 'PS-016',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'PS-017',
      'severity': 'P0',
      'condition': '收到任何自然语言输入',
      'action': '先分类Need、Fact、Experience、Correction、RealityResult或NewProblem',
      'requirement': 'PS-017',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'PS-018',
      'severity': 'P0',
      'condition': '存在会影响决定的关键未知',
      'action': '保存竞争假设和能区分它们的低成本HypothesisTest',
      'requirement': 'PS-018',
      'passage': 'XF-K0-PASSAGE-15',
    },
    <String, String>{
      'code': 'PS-019',
      'severity': 'P0',
      'condition': '相似历史案例准备进入求解',
      'action': '先保存案例比较及决定性差异，满足目标相关相同点后才迁移',
      'requirement': 'PS-019',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'PS-020',
      'severity': 'P0',
      'condition': '用户查看持久问题',
      'action': '展示已解决、当前焦点、关键未知、当前实验和下一次验证',
      'requirement': 'PS-020',
      'passage': 'XF-K0-PASSAGE-14',
    },
    <String, String>{
      'code': 'PS-021',
      'severity': 'P0',
      'condition': '现实不支持方案或预测',
      'action': '定位执行至事实链中最早错误层并向用户解释',
      'requirement': 'PS-021',
      'passage': 'XF-K0-PASSAGE-15',
    },
    <String, String>{
      'code': 'PS-022',
      'severity': 'P1',
      'condition': '出现真正独立的子问题',
      'action': '用parent_problem_id建立分支；普通反馈不生成平行问题',
      'requirement': 'PS-022',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'PS-023',
      'severity': 'P0',
      'condition': '形成或执行一个新方案',
      'action': '追加不可覆盖SolutionAttempt及依据、预测、结果和回溯点',
      'requirement': 'PS-023',
      'passage': 'XF-K0-PASSAGE-15',
    },
    <String, String>{
      'code': 'PS-024',
      'severity': 'P0',
      'condition': '行动完成或准备关闭问题',
      'action': '按阶段性解决判据与重开条件判断，禁止用行动完成冒充问题解决',
      'requirement': 'PS-024',
      'passage': 'XF-K0-PASSAGE-15',
    },
    <String, String>{
      'code': 'PS-025',
      'severity': 'P0',
      'condition': '关键行动产生可观察结果',
      'action': '结果必须更新事实、假设、差距和算子优先级',
      'requirement': 'PS-025',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
  ];

  static const List<Map<String, String>> _coreRuleSeeds =
      <Map<String, String>>[
    <String, String>{
      'code': 'K0-RULE-001',
      'severity': 'P0',
      'condition': '任何 AI 标签试图替代原始经验',
      'action': '保留 RawEvent/Experience；标签只能进入 Claim/Concept',
      'requirements': 'EP-001,KB-002,KB-007',
      'passage': 'XF-K0-PASSAGE-09',
    },
    <String, String>{
      'code': 'K0-RULE-002',
      'severity': 'P0',
      'condition': '用户原话、系统抽象或 AI 推断混写',
      'action': '分字段、分标签保存并可追溯',
      'requirements': 'EP-002',
      'passage': 'XF-K0-PASSAGE-09',
    },
    <String, String>{
      'code': 'K0-RULE-003',
      'severity': 'P0',
      'condition': '身体/主观体验被等同于外部原因',
      'action': '承认体验事实并独立审查外部解释',
      'requirements': 'EP-003,EP-012',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'K0-RULE-004',
      'severity': 'P0',
      'condition': '概念被当作新的外部事实',
      'action': '建立 grounding 关系并保留具体实例和边界',
      'requirements': 'EP-004,EP-009',
      'passage': 'XF-K0-PASSAGE-09',
    },
    <String, String>{
      'code': 'K0-RULE-005',
      'severity': 'P0',
      'condition': '高影响 Claim 无法追溯至 Experience/Evidence',
      'action': '登记认识债务并优先侦察',
      'requirements': 'EP-005,EP-007',
      'passage': 'XF-K0-PASSAGE-09',
    },
    <String, String>{
      'code': 'K0-RULE-006',
      'severity': 'P0',
      'condition': '概念/Claim 支持图形成无经验出口的循环',
      'action': '创建 ConceptCycle，停止把循环当支持',
      'requirements': 'EP-006',
      'passage': 'XF-K0-PASSAGE-09',
    },
    <String, String>{
      'code': 'K0-RULE-011',
      'severity': 'P0',
      'condition': '表面相同或表面不同掩盖目的相关差异/共同点',
      'action': '执行判断力同异与适用边界审查',
      'requirements': 'EP-011',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'K0-RULE-014',
      'severity': 'P0',
      'condition': '因抽象、权威、学术或复杂而提高认识地位',
      'action': '取消抽象加成，按实际根据重新画像',
      'requirements': 'EP-014',
      'passage': 'XF-K0-PASSAGE-14',
    },
    <String, String>{
      'code': 'K0-RULE-015',
      'severity': 'P0',
      'condition': '用系统化程度冒充确定性',
      'action': '系统化程度与认识状态分开存储和展示',
      'requirements': 'EP-015',
      'passage': 'XF-K0-PASSAGE-14',
    },
    <String, String>{
      'code': 'K0-RULE-016',
      'severity': 'P0',
      'condition': '推理链形式成立但关键前提薄弱',
      'action': '分别显示逻辑结构与最弱前提，现实结论保持未决',
      'requirements': 'EP-016',
      'passage': 'XF-K0-PASSAGE-15',
    },
    <String, String>{
      'code': 'K0-RULE-017',
      'severity': 'P0',
      'condition': '直接知觉被当作自动无误',
      'action': '保存观察条件、替代解释和可能误差',
      'requirements': 'EP-017',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'K0-RULE-019',
      'severity': 'P0',
      'condition': '抽象目标没有可观察满足判据',
      'action': '要求操作化，但注明判据不等同概念本身',
      'requirements': 'EP-019,PS-005',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'K0-RULE-021',
      'severity': 'P0',
      'condition': '现实连续反驳旧概念',
      'action': '进入 CONFLICTED 并创建概念修订版本',
      'requirements': 'EP-021,LG-005',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'K0-RULE-REALITY',
      'severity': 'P0',
      'condition': '行动完成但尚无 RealityResult',
      'action': '允许 Action DONE，但禁止 Problem RESOLVED/Campaign WON',
      'requirements': 'PS-010,AC-003',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'K0-RULE-USER',
      'severity': 'P0',
      'condition': '重大策略没有用户确认',
      'action': 'AI 只谋划，不进入执行状态',
      'requirements': 'ST-020',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'K0-RULE-RISK',
      'severity': 'P0',
      'condition': '不可逆高风险且认识债务高',
      'action': '冻结推进型 AI 协助，转补证与专业复核',
      'requirements': 'AC-006',
      'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'K0-RULE-025',
      'severity': 'P0',
      'condition': 'Embedding 相似度被写入 Evidence/GroundingRelation',
      'action': '只作为候选召回，另行核查正式依据',
      'requirements': 'KB-025',
      'passage': 'XF-K0-PASSAGE-09',
    },
    <String, String>{
      'code': 'SCK-001', 'severity': 'P0',
      'condition': 'AI 态势模型被当作客观现实或身份定论',
      'action': '标记为可修订 SituationModel，保留来源和版本',
      'requirements': 'SCK-001', 'passage': 'XF-K0-PASSAGE-09',
    },
    <String, String>{
      'code': 'SCK-002', 'severity': 'P0',
      'condition': '经验、观察、解释、预测或抽象混写',
      'action': 'A01 自动分层并保留用户原话',
      'requirements': 'SCK-002', 'passage': 'XF-K0-PASSAGE-09',
    },
    <String, String>{
      'code': 'SCK-003', 'severity': 'P0',
      'condition': '未理解具体态势就直接套抽象规则',
      'action': '先形成具体因果候选，再进入概念与规则',
      'requirements': 'SCK-003', 'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'SCK-004', 'severity': 'P0',
      'condition': '重要结果只保留单一原因',
      'action': '生成竞争性原因和能区分它们的现实行动',
      'requirements': 'SCK-004', 'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'SCK-005', 'severity': 'P0',
      'condition': '高影响求解前缺少判断力审查',
      'action': '强制 A02 先比较目的相关同异、边界与反例',
      'requirements': 'SCK-005', 'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'SCK-006', 'severity': 'P0',
      'condition': '概念被当作新的外部事实',
      'action': '标记为二阶表示并回到具体实例',
      'requirements': 'SCK-006', 'passage': 'XF-K0-PASSAGE-09',
    },
    <String, String>{
      'code': 'SCK-007', 'severity': 'P0',
      'condition': '重大判断无法递归追溯',
      'action': '追溯到 Experience/Evidence/Claim 或明确悬空',
      'requirements': 'SCK-007', 'passage': 'XF-K0-PASSAGE-09',
    },
    <String, String>{
      'code': 'SCK-008', 'severity': 'P0',
      'condition': '抽象、学术或复杂被用来提高确定性',
      'action': '取消复杂度加成，按现实根据重新画像',
      'requirements': 'SCK-008', 'passage': 'XF-K0-PASSAGE-14',
    },
    <String, String>{
      'code': 'SCK-009', 'severity': 'P0',
      'condition': '系统化程度与认识状态混为一体',
      'action': '分别保存和显示 Systematicity/EpistemicStatus',
      'requirements': 'SCK-009', 'passage': 'XF-K0-PASSAGE-14',
    },
    <String, String>{
      'code': 'SCK-010', 'severity': 'P0',
      'condition': '形式有效被用于掩盖无根据前提',
      'action': '同时显示形式成立和前提未决',
      'requirements': 'SCK-010', 'passage': 'XF-K0-PASSAGE-15',
    },
    <String, String>{
      'code': 'SCK-011', 'severity': 'P0',
      'condition': '直接观察被当作绝对无误',
      'action': '保留观察条件、模糊度与替代解释',
      'requirements': 'SCK-011', 'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'SCK-012', 'severity': 'P1',
      'condition': '身体感觉/情绪被抹平成外部原因',
      'action': '保留非概念经验异质性，外因另行审查',
      'requirements': 'SCK-012', 'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'SCK-013', 'severity': 'P0',
      'condition': '抽象标签无法回到实例与反例',
      'action': '展示原始事件、支持实例、反例和未解释细节',
      'requirements': 'SCK-013', 'passage': 'XF-K0-PASSAGE-09',
    },
    <String, String>{
      'code': 'SCK-014', 'severity': 'P0',
      'condition': '概念/规则持续与现实不一致',
      'action': '触发 UNDER_REVIEW/CONFLICTED 并创建修订版本',
      'requirements': 'SCK-014', 'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'SCK-015', 'severity': 'P0',
      'condition': '关键行动缺少机制、Gap、高层意义或根据',
      'action': '禁止进入 ACTION_READY，先补齐 why-chain',
      'requirements': 'SCK-015', 'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'SCK-016', 'severity': 'P0',
      'condition': '用户给出的路径/证明欲被直接当作目标',
      'action': '先执行 Goal Audit，价值选择保留给用户',
      'requirements': 'SCK-016', 'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'SCK-017', 'severity': 'P1',
      'condition': '信息已足以支持可逆一步仍继续反思',
      'action': '停止分析并压缩为唯一当前行动',
      'requirements': 'SCK-017', 'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
    <String, String>{
      'code': 'SCK-018', 'severity': 'P0',
      'condition': 'RealityResult 与 Prediction 冲突',
      'action': '保留事前预测，标派生模型 STALE，回溯并修订',
      'requirements': 'SCK-018', 'passage': 'XF-K0-PASSAGE-JUDGMENT',
    },
  ];

  Future<void> _seedProviderCapabilities(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final capabilities = <XiangjiProviderCapability>[
      const XiangjiProviderCapability(
        providerId: 'openai',
        label: 'OpenAI Vector Store',
        supportsPersistentFile: true,
        supportsStore: true,
        supportsDelete: true,
        supportsReuse: true,
        supportsCitations: true,
        supportsStructuredOutput: true,
        retentionPolicy: '文件与向量库保留至用户手动删除；以服务商当前条款为准',
        indexingMode: 'vector_store',
        verified: true,
      ),
      const XiangjiProviderCapability(
        providerId: 'azure_openai',
        label: 'Microsoft Azure OpenAI',
        supportsPersistentFile: true,
        supportsStore: true,
        supportsDelete: true,
        supportsReuse: true,
        supportsCitations: true,
        supportsStructuredOutput: true,
        retentionPolicy: '保存在用户 Azure 资源中，直至删除；以资源区域能力为准',
        indexingMode: 'vector_store',
        verified: true,
      ),
      const XiangjiProviderCapability(
        providerId: 'xgrok',
        label: 'xAI Grok Files',
        supportsPersistentFile: true,
        supportsStore: false,
        supportsDelete: true,
        supportsReuse: true,
        supportsCitations: false,
        supportsStructuredOutput: true,
        retentionPolicy: '文件 ID 可复用并可删除；以当前 Files API 为准',
        indexingMode: 'file_id',
        verified: true,
      ),
      const XiangjiProviderCapability(
        providerId: 'gemini',
        label: 'Google Gemini File Search',
        supportsPersistentFile: true,
        supportsStore: true,
        supportsDelete: true,
        supportsReuse: true,
        supportsCitations: true,
        supportsStructuredOutput: true,
        retentionPolicy: '检索索引可保留；原始上传文件遵守 Gemini 单独保留规则',
        indexingMode: 'file_search_store',
        verified: true,
      ),
      const XiangjiProviderCapability(
        providerId: 'claude',
        label: 'Anthropic Claude Files',
        supportsPersistentFile: true,
        supportsStore: false,
        supportsDelete: true,
        supportsReuse: true,
        supportsCitations: true,
        supportsStructuredOutput: true,
        retentionPolicy: '文件保留至删除；Files API 能力可能处于 Beta',
        indexingMode: 'file_id',
        verified: true,
      ),
      const XiangjiProviderCapability(
        providerId: 'openrouter',
        label: 'OpenRouter 工作区文件',
        supportsPersistentFile: true,
        supportsStore: false,
        supportsDelete: true,
        supportsReuse: true,
        supportsCitations: false,
        supportsStructuredOutput: true,
        retentionPolicy: '工作区文件需 Management Key 管理；以账户能力为准',
        indexingMode: 'workspace_file',
        verified: true,
      ),
      const XiangjiProviderCapability(
        providerId: 'edenai',
        label: 'Eden AI 临时文件',
        supportsPersistentFile: false,
        supportsStore: false,
        supportsDelete: false,
        supportsReuse: true,
        supportsCitations: false,
        supportsStructuredOutput: true,
        retentionPolicy: '通常 7 天自动过期；不是永久知识库',
        indexingMode: 'temporary_file_id',
        verified: true,
      ),
      const XiangjiProviderCapability(
        providerId: 'openai_compatible',
        label: '其他兼容服务',
        supportsPersistentFile: false,
        supportsStore: false,
        supportsDelete: false,
        supportsReuse: false,
        supportsCitations: false,
        supportsStructuredOutput: true,
        retentionPolicy: '未实测；不得声称永久保存',
        indexingMode: 'capability_required',
        verified: false,
        notes: '需由适配器实测后逐项启用能力。',
      ),
    ];
    for (final capability in capabilities) {
      await db.insert(
        'xf_provider_capability',
        <String, Object?>{
          ...capability.toMap(),
          'updated_at_ms': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<String> createProblem({
    required String id,
    required String rawEventId,
    required String rawQuestion,
    required String contextText,
    String sensitivity = 'sensitive',
    String parentProblemId = '',
    String rootGoalId = '',
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.insert('xf_raw_event', <String, Object?>{
        'id': rawEventId,
        'occurred_at_ms': now,
        'context_text': contextText,
        'source_type': 'manual',
        'source_ref': '',
        'sensitivity': sensitivity,
        'created_at_ms': now,
      });
      await txn.insert('xf_problem', <String, Object?>{
        'id': id,
        'raw_event_id': rawEventId,
        'raw_question': rawQuestion,
        'reframed_question': '',
        'state': XiangjiProblemState.captured.wire,
        'campaign_id': '',
        'goal_text': '',
        'value_link': '',
        'success_criteria': '',
        'exit_criteria': '',
        'review_at_ms': 0,
        'priority': 0,
        'version_no': 1,
        'need': rawQuestion,
        'root_goal_id': rootGoalId.trim().isEmpty ? id : rootGoalId,
        'parent_problem_id': parentProblemId,
        'current_state_version_id': '',
        'canonical_problem_id': id,
        'problem_status': 'ACTIVE',
        'created_at_ms': now,
        'updated_at_ms': now,
      });
      await txn.insert('xf_experience', <String, Object?>{
        'id': '$rawEventId-user-wording',
        'raw_event_id': rawEventId,
        'problem_id': id,
        'experience_type': 'raw_context',
        'content': contextText,
        'is_user_wording': 1,
        'observation_conditions_json': '{}',
        'user_confirmed': 1,
        'created_at_ms': now,
      });
      await _insertAudit(
        txn,
        id: '$id-create',
        objectType: 'problem',
        objectId: id,
        eventType: 'created',
        actor: 'user',
        after: <String, Object?>{
          'raw_question': rawQuestion,
          'state': XiangjiProblemState.captured.wire,
        },
        now: now,
      );
    });
    return id;
  }

  Future<void> addProblemUtterance({
    required String eventId,
    required String experienceId,
    required String problemId,
    required String text,
    String contextText = '',
    List<String> sourceRefs = const <String>[],
    String sensitivity = 'sensitive',
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.insert('xf_raw_event', <String, Object?>{
        'id': eventId,
        'occurred_at_ms': now,
        'context_text': contextText.trim().isEmpty ? text : contextText.trim(),
        'source_type': 'conversation_followup',
        'source_ref': problemId,
        'sensitivity': sensitivity,
        'created_at_ms': now,
      });
      await txn.insert('xf_experience', <String, Object?>{
        'id': experienceId,
        'raw_event_id': eventId,
        'problem_id': problemId,
        'experience_type': 'user_utterance',
        'content': text,
        'is_user_wording': 1,
        'observation_conditions_json': jsonEncode(<String, Object?>{
          'source': 'conversation_followup',
          'source_refs': sourceRefs,
        }),
        'user_confirmed': 1,
        'created_at_ms': now,
      });
      await _insertAudit(
        txn,
        id: '$eventId-captured',
        objectType: 'problem',
        objectId: problemId,
        eventType: 'user_utterance_added',
        actor: 'user',
        after: <String, Object?>{'raw_event_id': eventId},
        now: now,
      );
    });
  }

  Future<XiangjiProblemRecord?> problem(String id) async {
    final db = await _database();
    final rows = await db.query(
      'xf_problem',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : XiangjiProblemRecord.fromMap(rows.first);
  }

  Future<String> problemRawEventId(String id) async {
    final db = await _database();
    final rows = await db.query(
      'xf_problem',
      columns: const <String>['raw_event_id'],
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? '' : (rows.first['raw_event_id'] ?? '').toString();
  }

  Future<List<XiangjiProblemRecord>> problems({bool includeArchived = false}) async {
    final db = await _database();
    final rows = await db.query(
      'xf_problem',
      where: includeArchived
          ? null
          : "state != ? AND problem_status NOT IN ('ARCHIVED','MERGED')",
      whereArgs: includeArchived ? null : <Object?>['ARCHIVED'],
      orderBy: 'updated_at_ms DESC',
    );
    return rows.map(XiangjiProblemRecord.fromMap).toList();
  }

  Future<XiangjiProblemRecord?> latestActiveProblem() async {
    final db = await _database();
    final rows = await db.query(
      'xf_problem',
      where:
          "state NOT IN ('ARCHIVED','RESOLVED') AND problem_status NOT IN ('ARCHIVED','MERGED','RESOLVED')",
      orderBy: 'updated_at_ms DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : XiangjiProblemRecord.fromMap(rows.first);
  }

  Future<void> saveInputClassification({
    required String id,
    required String rawEventId,
    required String inputText,
    required XiangjiInputClassification classification,
    String classifiedBy = 'A13_LOCAL_GUARD',
  }) async {
    final db = await _database();
    await db.insert(
      'xf_input_classification',
      <String, Object?>{
        'id': id,
        'raw_event_id': rawEventId,
        'input_text': inputText,
        'input_type': classification.type.wire,
        'updates_existing_problem':
            classification.updateExistingProblem ? 1 : 0,
        'target_problem_id': classification.targetProblemId,
        'reason': classification.reason,
        'confidence': classification.confidence,
        'classified_by': classifiedBy,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> nextProblemStateVersion(String problemId) async {
    final db = await _database();
    final value = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT MAX(version_no) FROM xf_problem_state_version WHERE problem_id = ?',
          <Object?>[problemId],
        )) ??
        0;
    return value + 1;
  }

  Future<Map<String, Object?>?> latestProblemStateVersion(
    String problemId,
  ) async {
    final db = await _database();
    final rows = await db.query(
      'xf_problem_state_version',
      where: 'problem_id = ?',
      whereArgs: <Object?>[problemId],
      orderBy: 'version_no DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveProblemStateVersion(Map<String, Object?> values) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = <String, Object?>{
      ...values,
      'created_at_ms': values['created_at_ms'] ?? now,
    };
    await db.transaction((txn) async {
      await txn.insert(
        'xf_problem_state_version',
        row,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await txn.update(
        'xf_problem',
        <String, Object?>{
          'current_state_version_id': row['id'],
          if (row['lifecycle_state'] == 'RESOLVED')
            'problem_status': 'RESOLVED',
          if (row['lifecycle_state'] == 'ARCHIVED')
            'problem_status': 'ARCHIVED',
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[row['problem_id']],
      );
    });
  }

  Future<List<Map<String, Object?>>> problemStateVersions(
    String problemId, {
    int limit = 50,
  }) async {
    final db = await _database();
    return db.query(
      'xf_problem_state_version',
      where: 'problem_id = ?',
      whereArgs: <Object?>[problemId],
      orderBy: 'version_no DESC',
      limit: limit,
    );
  }

  Future<XiangjiProblemProgress?> problemProgress(String problemId) async {
    final latest = await latestProblemStateVersion(problemId);
    if (latest == null) return null;
    final hypotheses = await hypothesesForProblem(problemId);
    final attempts = await solutionAttempts(problemId);
    final backtracks = await backtrackEvents(problemId);
    List<String> strings(Object? raw) {
      try {
        final decoded = raw is String ? jsonDecode(raw) : raw;
        if (decoded is! List) return const <String>[];
        return decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      } catch (_) {
        return const <String>[];
      }
    }

    final wire = (latest['lifecycle_state'] ?? '').toString();
    final state = XiangjiPersistentProblemState.values.firstWhere(
      (value) => value.wire == wire,
      orElse: () => XiangjiPersistentProblemState.captured,
    );
    return XiangjiProblemProgress(
      problemId: problemId,
      state: state,
      version: (latest['version_no'] as num?)?.toInt() ?? 0,
      resolvedItems: strings(latest['resolved_items_json']),
      currentFocus: (latest['current_focus'] ?? '').toString(),
      keyUnknowns: strings(latest['unknowns_json']),
      currentExperiment: (latest['current_experiment'] ?? '').toString(),
      nextVerification: (latest['next_verification'] ?? '').toString(),
      hypotheses: hypotheses,
      attempts: attempts,
      backtracks: backtracks,
    );
  }

  Future<void> saveHypothesis(Map<String, Object?> values) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'xf_hypothesis',
      <String, Object?>{
        ...values,
        'created_at_ms': values['created_at_ms'] ?? now,
        'updated_at_ms': values['updated_at_ms'] ?? now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> hypothesesForProblem(
    String problemId,
  ) async {
    final db = await _database();
    return db.query(
      'xf_hypothesis',
      where: 'problem_id = ?',
      whereArgs: <Object?>[problemId],
      orderBy: 'updated_at_ms DESC',
    );
  }

  Future<void> saveHypothesisTest(Map<String, Object?> values) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'xf_hypothesis_test',
      <String, Object?>{
        ...values,
        'created_at_ms': values['created_at_ms'] ?? now,
        'updated_at_ms': values['updated_at_ms'] ?? now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> hypothesisTests(
    String problemId,
  ) async {
    final db = await _database();
    return db.query(
      'xf_hypothesis_test',
      where: 'problem_id = ?',
      whereArgs: <Object?>[problemId],
      orderBy: 'created_at_ms DESC',
    );
  }

  Future<void> reconcileHypothesisTestsForAction({
    required String actionId,
    required String resultRef,
    required String conclusion,
    required XiangjiHypothesisStatus status,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final tests = await txn.query(
        'xf_hypothesis_test',
        where: 'discriminating_action_id = ?',
        whereArgs: <Object?>[actionId],
      );
      for (final test in tests) {
        await txn.update(
          'xf_hypothesis_test',
          <String, Object?>{
            'result_ref': resultRef,
            'conclusion': conclusion,
            'status': status.wire,
            'updated_at_ms': now,
          },
          where: 'id = ?',
          whereArgs: <Object?>[test['id']],
        );
        try {
          final decoded = jsonDecode(
            (test['hypothesis_ids_json'] ?? '[]').toString(),
          );
          if (decoded is! List) continue;
          for (final hypothesisId in decoded) {
            await txn.update(
              'xf_hypothesis',
              <String, Object?>{
                'status': status.wire,
                'updated_at_ms': now,
              },
              where: 'id = ?',
              whereArgs: <Object?>[hypothesisId.toString()],
            );
          }
        } catch (_) {
          // The test result remains authoritative if a legacy hypothesis list
          // cannot be decoded.
        }
      }
    });
  }

  Future<void> saveSolutionAttempt(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_solution_attempt',
      <String, Object?>{
        ...values,
        'created_at_ms': values['created_at_ms'] ??
            DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSolutionAttemptForAction(
    String actionId,
    Map<String, Object?> values,
  ) async {
    final db = await _database();
    await db.update(
      'xf_solution_attempt',
      values,
      where: 'action_id = ?',
      whereArgs: <Object?>[actionId],
    );
  }

  Future<List<Map<String, Object?>>> solutionAttempts(
    String problemId,
  ) async {
    final db = await _database();
    return db.query(
      'xf_solution_attempt',
      where: 'problem_id = ?',
      whereArgs: <Object?>[problemId],
      orderBy: 'created_at_ms DESC',
    );
  }

  Future<void> saveCaseComparison(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_case_comparison',
      <String, Object?>{
        ...values,
        'created_at_ms': values['created_at_ms'] ??
            DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveRelevantDifference(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_relevant_difference',
      <String, Object?>{
        ...values,
        'created_at_ms': values['created_at_ms'] ??
            DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> caseComparisons(
    String problemId,
  ) async {
    final db = await _database();
    return db.query(
      'xf_case_comparison',
      where: 'problem_id = ?',
      whereArgs: <Object?>[problemId],
      orderBy: 'created_at_ms DESC',
    );
  }

  Future<void> saveCognitiveExperience({
    required String problemId,
    required String situationModelId,
    required XiangjiCognitiveExperienceDraft experience,
  }) async {
    final db = await _database();
    await db.insert(
      'xf_cognitive_experience',
      <String, Object?>{
        ...experience.toMap(),
        'problem_id': problemId,
        'situation_model_id': situationModelId,
        'user_viewed': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<XiangjiCognitiveExperienceDraft>> cognitiveExperiences({
    String problemId = '',
    int limit = 100,
  }) async {
    final db = await _database();
    final rows = await db.query(
      'xf_cognitive_experience',
      where: problemId.isEmpty ? null : 'problem_id = ?',
      whereArgs: problemId.isEmpty ? null : <Object?>[problemId],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(XiangjiCognitiveExperienceDraft.fromMap).toList();
  }

  Future<void> markCognitiveExperienceViewed(String id) async {
    final db = await _database();
    await db.update(
      'xf_cognitive_experience',
      <String, Object?>{'user_viewed': 1},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> saveMethodExperience(Map<String, Object?> values) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'xf_method_experience',
      <String, Object?>{
        ...values,
        'created_at_ms': values['created_at_ms'] ?? now,
        'updated_at_ms': values['updated_at_ms'] ?? now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> methodExperiences({
    String problemId = '',
    int limit = 100,
  }) async {
    final db = await _database();
    return db.query(
      'xf_method_experience',
      where: problemId.isEmpty ? null : 'problem_id = ?',
      whereArgs: problemId.isEmpty ? null : <Object?>[problemId],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
  }

  Future<void> recordMethodExerciseResponse({
    required String cognitiveExperienceId,
    required String response,
  }) async {
    final db = await _database();
    await db.update(
      'xf_method_experience',
      <String, Object?>{
        'user_viewed': 1,
        'user_response': response,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'cognitive_experience_id = ?',
      whereArgs: <Object?>[cognitiveExperienceId],
    );
  }

  Future<void> saveExplanationCard(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_explanation_card',
      <String, Object?>{
        ...values,
        'created_at_ms': values['created_at_ms'] ??
            DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> latestExplanationCard(
    String problemId,
  ) async {
    final db = await _database();
    final rows = await db.query(
      'xf_explanation_card',
      where: 'problem_id = ?',
      whereArgs: <Object?>[problemId],
      orderBy: 'created_at_ms DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> explanationCards({
    String problemId = '',
    int limit = 100,
  }) async {
    final db = await _database();
    return db.query(
      'xf_explanation_card',
      where: problemId.isEmpty ? null : 'problem_id = ?',
      whereArgs: problemId.isEmpty ? null : <Object?>[problemId],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
  }

  Future<void> saveConceptRealityConflict(Map<String, Object?> values) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'xf_concept_reality_conflict',
      <String, Object?>{
        ...values,
        'created_at_ms': values['created_at_ms'] ?? now,
        'updated_at_ms': values['updated_at_ms'] ?? now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> conceptRealityConflicts({
    String problemId = '',
    int limit = 100,
  }) async {
    final db = await _database();
    return db.query(
      'xf_concept_reality_conflict',
      where: problemId.isEmpty ? null : 'problem_id = ?',
      whereArgs: problemId.isEmpty ? null : <Object?>[problemId],
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
  }

  Future<void> saveLearningMoment(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_learning_moment',
      <String, Object?>{
        ...values,
        'created_at_ms': values['created_at_ms'] ??
            DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> learningMoments({
    String problemId = '',
    int limit = 100,
  }) async {
    final db = await _database();
    return db.query(
      'xf_learning_moment',
      where: problemId.isEmpty ? null : 'problem_id = ?',
      whereArgs: problemId.isEmpty ? null : <Object?>[problemId],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
  }

  Future<void> saveBacktrackEvent(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_backtrack_event',
      <String, Object?>{
        ...values,
        'created_at_ms': values['created_at_ms'] ??
            DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> backtrackEvents(
    String problemId,
  ) async {
    final db = await _database();
    return db.query(
      'xf_backtrack_event',
      where: 'problem_id = ?',
      whereArgs: <Object?>[problemId],
      orderBy: 'created_at_ms DESC',
    );
  }

  Future<void> updateProblemState(
    String id,
    XiangjiProblemState state, {
    String actor = 'user',
  }) async {
    final db = await _database();
    final before = await problem(id);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        'xf_problem',
        <String, Object?>{
          'state': state.wire,
          'problem_status': switch (state) {
            XiangjiProblemState.resolved => 'RESOLVED',
            XiangjiProblemState.archived => 'ARCHIVED',
            _ => 'ACTIVE',
          },
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      await _insertAudit(
        txn,
        id: '$id-state-$now',
        objectType: 'problem',
        objectId: id,
        eventType: 'state_changed',
        actor: actor,
        before: <String, Object?>{'state': before?.state.wire},
        after: <String, Object?>{'state': state.wire},
        now: now,
      );
    });
  }

  Future<void> updateProblemDefinition({
    required String id,
    required String reframedQuestion,
    required String goalText,
    required String valueLink,
    required String successCriteria,
    required String exitCriteria,
    required int reviewAtMs,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawUpdate(
      'UPDATE xf_problem SET version_no = version_no + 1 WHERE id = ?',
      <Object?>[id],
    );
    await db.update(
      'xf_problem',
      <String, Object?>{
        'reframed_question': reframedQuestion,
        'goal_text': goalText,
        'value_link': valueLink,
        'success_criteria': successCriteria,
        'exit_criteria': exitCriteria,
        'review_at_ms': reviewAtMs,
        'updated_at_ms': now,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> addProblemItem({
    required String id,
    required String problemId,
    required String kind,
    required String text,
    String sourceRef = '',
    bool critical = false,
    int sortOrder = 0,
    Map<String, Object?> data = const <String, Object?>{},
  }) async {
    final db = await _database();
    await db.insert(
      'xf_problem_item',
      <String, Object?>{
        'id': id,
        'problem_id': problemId,
        'kind': kind,
        'text': text,
        'source_ref': sourceRef,
        'critical': critical ? 1 : 0,
        'sort_order': sortOrder,
        'status': 'active',
        'data_json': jsonEncode(data),
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> problemItems(
    String problemId, {
    String? kind,
  }) async {
    final db = await _database();
    return db.query(
      'xf_problem_item',
      where: kind == null
          ? 'problem_id = ? AND status = ?'
          : 'problem_id = ? AND kind = ? AND status = ?',
      whereArgs: kind == null
          ? <Object?>[problemId, 'active']
          : <Object?>[problemId, kind, 'active'],
      orderBy: 'sort_order ASC, created_at_ms ASC',
    );
  }

  Future<int> problemVersion(String problemId) async {
    final db = await _database();
    final rows = await db.query(
      'xf_problem',
      columns: const <String>['version_no'],
      where: 'id = ?',
      whereArgs: <Object?>[problemId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    final raw = rows.first['version_no'];
    return raw is num ? raw.toInt() : int.tryParse(raw.toString()) ?? 0;
  }

  Future<XiangjiSolverSnapshot?> solverSnapshot(String problemId) async {
    final db = await _database();
    final rows = await db.query(
      'xf_solver_snapshot',
      where: 'problem_id = ?',
      whereArgs: <Object?>[problemId],
      limit: 1,
    );
    return rows.isEmpty ? null : XiangjiSolverSnapshot.fromMap(rows.first);
  }

  Future<List<XiangjiSolverSnapshot>> solverSnapshots({int limit = 100}) async {
    final db = await _database();
    final rows = await db.query(
      'xf_solver_snapshot',
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
    return rows.map(XiangjiSolverSnapshot.fromMap).toList(growable: false);
  }

  Future<void> saveSolverSnapshot(XiangjiSolverSnapshot snapshot) async {
    final db = await _database();
    await db.insert(
      'xf_solver_snapshot',
      snapshot.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Commits the transformed solver state and its audit events atomically.
  Future<void> saveSolverStateAndMethodEvents({
    required XiangjiSolverSnapshot snapshot,
    required List<XiangjiMethodEvent> events,
  }) async {
    final db = await _database();
    for (final event in events) {
      _validateMethodEvent(event, snapshot.problemId);
    }
    await db.transaction((txn) async {
      await txn.insert(
        'xf_solver_snapshot',
        snapshot.toDatabaseMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final event in events) {
        await txn.insert(
          'xf_method_event',
          event.toDatabaseMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> saveMethodEvent(XiangjiMethodEvent event) async {
    _validateMethodEvent(event, event.problemId);
    final db = await _database();
    await db.insert(
      'xf_method_event',
      event.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<XiangjiMethodEvent>> methodEvents({
    String problemId = '',
    String methodId = '',
    bool userVisibleOnly = false,
    int limit = 0,
  }) async {
    final db = await _database();
    final where = <String>[];
    final args = <Object?>[];
    if (problemId.isNotEmpty) {
      where.add('problem_id = ?');
      args.add(problemId);
    }
    if (methodId.isNotEmpty) {
      where.add('method_id = ?');
      args.add(methodId);
    }
    if (userVisibleOnly) where.add('user_visible = 1');
    final rows = await db.query(
      'xf_method_event',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at_ms DESC',
      limit: limit > 0 ? limit : null,
    );
    return rows.map(XiangjiMethodEvent.fromMap).toList();
  }

  /// Returns only the newest router turn, so a turn that intentionally
  /// exposes zero methods never leaks cards from an older turn into the UI.
  Future<List<XiangjiMethodEvent>> latestMethodTurnEvents({
    required String problemId,
    bool userVisibleOnly = true,
    int limit = 3,
  }) async {
    final recent = await methodEvents(problemId: problemId, limit: 100);
    if (recent.isEmpty) return const <XiangjiMethodEvent>[];
    String turnPrefix(String id) => id.replaceFirst(
          RegExp(r'-mec-\d{3}-\d+$'),
          '',
        );

    final prefix = turnPrefix(recent.first.id);
    return recent
        .where(
          (event) =>
              turnPrefix(event.id) == prefix &&
              (!userVisibleOnly || event.userVisible),
        )
        .take(limit.clamp(0, 3).toInt())
        .toList();
  }

  void _validateMethodEvent(XiangjiMethodEvent event, String problemId) {
    if (!XiangjiMethodCatalog.ids.contains(event.methodId)) {
      throw ArgumentError('MethodEvent.method_id 必须是 MEC-001..MEC-014。');
    }
    if (event.problemId.isEmpty || event.problemId != problemId) {
      throw ArgumentError('MethodEvent 必须绑定当前 Problem。');
    }
    if (event.trigger.trim().isEmpty ||
        event.operationSummary.trim().isEmpty ||
        event.decisionEffect.trim().isEmpty ||
        event.realityTest.trim().isEmpty) {
      throw ArgumentError('MethodEvent 缺少 Trigger/Operation/Effect/RealityTest。');
    }
    if (event.dataMutations.isEmpty) {
      throw ArgumentError('MethodEvent 必须记录具体数据变更。');
    }
    if (!event.changedState && event.retainedStateReason.trim().isEmpty) {
      throw ArgumentError('维持原状态的 MethodEvent 必须记录维持理由。');
    }
  }

  Future<int> nextSituationModelVersion({
    required String objectType,
    required String objectId,
  }) async {
    final db = await _database();
    final value = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT MAX(version_no) FROM xf_situation_model WHERE object_type = ? AND object_id = ?',
          <Object?>[objectType, objectId],
        )) ??
        0;
    return value + 1;
  }

  Future<void> saveSituationModel({
    required String id,
    required String objectType,
    required String objectId,
    required int version,
    required XiangjiSituationModelState state,
    required String summary,
    required String currentNeed,
    required Map<String, Object?> model,
    required List<String> sourceRefs,
    String staleReason = '',
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'xf_situation_model',
      <String, Object?>{
        'id': id,
        'object_type': objectType,
        'object_id': objectId,
        'version_no': version,
        'state': state.wire,
        'summary': summary,
        'current_need': currentNeed,
        'model_json': jsonEncode(model),
        'source_refs_json': jsonEncode(sourceRefs),
        'generated_at_ms': now,
        'stale_reason': staleReason,
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (objectType == 'problem') {
      await db.update(
        'xf_problem',
        <String, Object?>{
          'situation_model_id': id,
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[objectId],
      );
    }
  }

  Future<Map<String, Object?>?> latestSituationModel({
    required String objectType,
    required String objectId,
  }) async {
    final db = await _database();
    final rows = await db.query(
      'xf_situation_model',
      where: 'object_type = ? AND object_id = ?',
      whereArgs: <Object?>[objectType, objectId],
      orderBy: 'version_no DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveAiInference(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_ai_inference',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> aiInferences(String problemId) async {
    final db = await _database();
    return db.query(
      'xf_ai_inference',
      where: 'problem_id = ?',
      whereArgs: <Object?>[problemId],
      orderBy: 'created_at_ms DESC',
    );
  }

  Future<void> saveInformationNeed(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_information_need',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> informationNeeds(
    String problemId, {
    bool openOnly = false,
  }) async {
    final db = await _database();
    return db.query(
      'xf_information_need',
      where: openOnly ? 'problem_id = ? AND status = ?' : 'problem_id = ?',
      whereArgs: openOnly
          ? <Object?>[problemId, 'OPEN']
          : <Object?>[problemId],
      orderBy: 'selected_for_question DESC, evsi_rank DESC, created_at_ms DESC',
    );
  }

  Future<void> supersedeOpenInformationNeeds(String problemId) async {
    final db = await _database();
    await db.update(
      'xf_information_need',
      <String, Object?>{
        'status': 'SUPERSEDED',
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'problem_id = ? AND status = ?',
      whereArgs: <Object?>[problemId, 'OPEN'],
    );
  }

  Future<void> linkScoutingInformationNeeds(
    String problemId,
    String actionId,
  ) async {
    final db = await _database();
    await db.update(
      'xf_information_need',
      <String, Object?>{
        'resolution_action_id': actionId,
        'status': 'SCOUTING',
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'problem_id = ? AND status = ? AND scouting_possible = 1',
      whereArgs: <Object?>[problemId, 'OPEN'],
    );
  }

  Future<void> saveClarificationQuestion(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_clarification_question',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> answerOpenClarification({
    required String problemId,
    required String answerRef,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'xf_clarification_question',
      <String, Object?>{
        'answer_ref': answerRef,
        'answered_at_ms': now,
        'status': 'ANSWERED',
      },
      where: 'problem_id = ? AND status = ?',
      whereArgs: <Object?>[problemId, 'ASKED'],
    );
    await db.update(
      'xf_information_need',
      <String, Object?>{'status': 'ANSWERED', 'updated_at_ms': now},
      where: 'problem_id = ? AND selected_for_question = 1 AND status = ?',
      whereArgs: <Object?>[problemId, 'OPEN'],
    );
  }

  Future<void> saveAgentRun(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_agent_run',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> agentRuns(String problemId) async {
    final db = await _database();
    return db.query(
      'xf_agent_run',
      where: 'problem_id = ?',
      whereArgs: <Object?>[problemId],
      orderBy: 'started_at_ms ASC',
    );
  }

  Future<void> saveReasoningArtifact(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_reasoning_artifact',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> reasoningArtifacts({
    String problemId = '',
    String campaignId = '',
  }) async {
    final db = await _database();
    if (problemId.isNotEmpty) {
      return db.query(
        'xf_reasoning_artifact',
        where: 'problem_id = ? AND status = ?',
        whereArgs: <Object?>[problemId, 'ACTIVE'],
        orderBy: 'created_at_ms DESC',
      );
    }
    return db.query(
      'xf_reasoning_artifact',
      where: 'campaign_id = ? AND status = ?',
      whereArgs: <Object?>[campaignId, 'ACTIVE'],
      orderBy: 'created_at_ms DESC',
    );
  }

  Future<void> saveJudgment(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_judgment',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> judgments(String problemId) async {
    final db = await _database();
    return db.query(
      'xf_judgment',
      where: 'problem_id = ?',
      whereArgs: <Object?>[problemId],
      orderBy: 'created_at_ms DESC',
    );
  }

  Future<void> saveDecisionDraft(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_decision_draft',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<XiangjiDecisionDraftRecord?> decisionDraft(String id) async {
    final db = await _database();
    final rows = await db.query(
      'xf_decision_draft',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : XiangjiDecisionDraftRecord.fromMap(rows.first);
  }

  Future<XiangjiDecisionDraftRecord?> latestDecisionDraft({
    String problemId = '',
    String campaignId = '',
  }) async {
    final db = await _database();
    final rows = await db.query(
      'xf_decision_draft',
      where: problemId.isNotEmpty ? 'problem_id = ?' : 'campaign_id = ?',
      whereArgs: <Object?>[problemId.isNotEmpty ? problemId : campaignId],
      orderBy: 'created_at_ms DESC',
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : XiangjiDecisionDraftRecord.fromMap(rows.first);
  }

  Future<List<XiangjiDecisionDraftRecord>> latestDecisionDrafts({
    int limit = 20,
  }) async {
    final db = await _database();
    final rows = await db.query(
      'xf_decision_draft',
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(XiangjiDecisionDraftRecord.fromMap).toList();
  }

  Future<void> updateDecisionDraftStatus(
    String id,
    XiangjiDecisionDraftStatus status, {
    String recommendation = '',
    String currentAction = '',
  }) async {
    final db = await _database();
    await db.update(
      'xf_decision_draft',
      <String, Object?>{
        'user_status': status.wire,
        if (recommendation.trim().isNotEmpty)
          'recommendation': recommendation.trim(),
        if (currentAction.trim().isNotEmpty)
          'current_action': currentAction.trim(),
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> saveUserCorrectionAndInvalidate({
    required String id,
    required String problemId,
    required String targetRef,
    required String oldValue,
    required String correctedValue,
    required String reason,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.insert('xf_user_correction', <String, Object?>{
        'id': id,
        'problem_id': problemId,
        'target_ref': targetRef,
        'old_value': oldValue,
        'corrected_value': correctedValue,
        'reason': reason,
        'created_at_ms': now,
      });
      await txn.update(
        'xf_situation_model',
        <String, Object?>{
          'state': XiangjiSituationModelState.stale.wire,
          'stale_reason': reason,
        },
        where: 'object_type = ? AND object_id = ? AND state != ?',
        whereArgs: <Object?>[
          'problem',
          problemId,
          XiangjiSituationModelState.stale.wire,
        ],
      );
      await txn.update(
        'xf_ai_inference',
        <String, Object?>{'status': 'STALE'},
        where: 'problem_id = ? AND status = ?',
        whereArgs: <Object?>[problemId, 'ACTIVE'],
      );
      await txn.update(
        'xf_reasoning_artifact',
        <String, Object?>{'status': 'STALE'},
        where: 'problem_id = ? AND status = ?',
        whereArgs: <Object?>[problemId, 'ACTIVE'],
      );
      await txn.update(
        'xf_judgment',
        <String, Object?>{
          'state': XiangjiJudgmentState.contested.wire,
          'updated_at_ms': now,
        },
        where: 'problem_id = ? AND state IN (?, ?)',
        whereArgs: <Object?>[
          problemId,
          XiangjiJudgmentState.draft.wire,
          XiangjiJudgmentState.accepted.wire,
        ],
      );
      await txn.update(
        'xf_decision_draft',
        <String, Object?>{
          'user_status': XiangjiDecisionDraftStatus.stale.wire,
          'updated_at_ms': now,
        },
        where: 'problem_id = ? AND user_status != ?',
        whereArgs: <Object?>[
          problemId,
          XiangjiDecisionDraftStatus.stale.wire,
        ],
      );
      await txn.update(
        'xf_claim',
        <String, Object?>{
          'epistemic_status': XiangjiClaimState.unresolved.wire,
          'updated_at_ms': now,
        },
        where: 'problem_id = ? AND source_kind = ?',
        whereArgs: <Object?>[problemId, 'ai_inference'],
      );
      await txn.update(
        'xf_concept',
        <String, Object?>{'status': 'UNDER_REVIEW', 'updated_at_ms': now},
        where: 'scope = ?',
        whereArgs: <Object?>[problemId],
      );
    });
  }

  Future<void> retireGeneratedProblemItems(String problemId) async {
    final db = await _database();
    await db.update(
      'xf_problem_item',
      <String, Object?>{'status': 'stale'},
      where: "problem_id = ? AND status = 'active' AND source_ref LIKE 'situation:%'",
      whereArgs: <Object?>[problemId],
    );
  }

  Future<void> acceptSituationModel(String situationModelId) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        'xf_ai_inference',
        <String, Object?>{'user_confirmed': 1},
        where: 'situation_model_id = ? AND status = ?',
        whereArgs: <Object?>[situationModelId, 'ACTIVE'],
      );
      await txn.update(
        'xf_judgment',
        <String, Object?>{
          'state': XiangjiJudgmentState.accepted.wire,
          'updated_at_ms': now,
        },
        where: 'situation_model_id = ? AND state = ?',
        whereArgs: <Object?>[
          situationModelId,
          XiangjiJudgmentState.draft.wire,
        ],
      );
    });
  }

  Future<void> invalidateReadyActions(String problemId) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final actions = await txn.query(
        'xf_action',
        columns: const <String>['id'],
        where: 'problem_id = ? AND state = ?',
        whereArgs: <Object?>[problemId, XiangjiActionState.ready.wire],
      );
      await txn.update(
        'xf_action',
        <String, Object?>{
          'state': XiangjiActionState.invalidated.wire,
          'updated_at_ms': now,
        },
        where: 'problem_id = ? AND state = ?',
        whereArgs: <Object?>[problemId, XiangjiActionState.ready.wire],
      );
      for (final action in actions) {
        await txn.update(
          'xf_solution_attempt',
          <String, Object?>{
            'status': 'SUPERSEDED',
            'failure_layer': 'new_problem_state_version',
          },
          where: 'action_id = ? AND status = ?',
          whereArgs: <Object?>[action['id'], 'PLANNED'],
        );
      }
    });
  }

  Future<void> linkProblemCampaign(String problemId, String campaignId) async {
    final db = await _database();
    await db.update(
      'xf_problem',
      <String, Object?>{
        'campaign_id': campaignId,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[problemId],
    );
  }

  Future<void> addCausalHypothesis({
    required String id,
    required String problemId,
    required String causeCandidate,
    required String differentiatingEvidenceNeeded,
    String effectClaimId = '',
  }) async {
    final db = await _database();
    await db.insert(
      'xf_causal_hypothesis',
      <String, Object?>{
        'id': id,
        'problem_id': problemId,
        'effect_claim_id': effectClaimId,
        'cause_candidate': causeCandidate,
        'differentiating_evidence_needed': differentiatingEvidenceNeeded,
        'status': 'candidate',
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> causalHypotheses(String problemId) async {
    final db = await _database();
    return db.query(
      'xf_causal_hypothesis',
      where: 'problem_id = ?',
      whereArgs: <Object?>[problemId],
      orderBy: 'created_at_ms ASC',
    );
  }

  Future<void> saveConceptDefinition({
    required String conceptId,
    required String versionId,
    required String name,
    required String definition,
    required String scope,
    required List<String> observableCriteria,
    List<String> supportRefs = const <String>[],
    List<String> counterexampleRefs = const <String>[],
    String applicabilityBoundary = '',
    List<String> unexplainedDetails = const <String>[],
    required String changeReason,
    String origin = 'user_problem_review',
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.insert(
        'xf_concept',
        <String, Object?>{
          'id': conceptId,
          'name': name,
          'scope': scope,
          'origin': origin,
          'is_personal': 1,
          'current_version_id': versionId,
          'status': 'ACTIVE',
          'created_at_ms': now,
          'updated_at_ms': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final existing = await txn.query(
        'xf_concept_version',
        columns: <String>['id', 'version_no'],
        where: 'concept_id = ?',
        whereArgs: <Object?>[conceptId],
        orderBy: 'version_no DESC',
        limit: 1,
      );
      final version = existing.isEmpty
          ? 1
          : ((existing.first['version_no'] as num?)?.toInt() ?? 0) + 1;
      final supersedes =
          existing.isEmpty ? '' : (existing.first['id'] ?? '').toString();
      await txn.insert('xf_concept_version', <String, Object?>{
        'id': versionId,
        'concept_id': conceptId,
        'version_no': version,
        'definition': definition,
        'observable_criteria_json': jsonEncode(observableCriteria),
        'change_reason': changeReason,
        'supersedes_id': supersedes,
        'source_refs_json': jsonEncode(supportRefs),
        'support_refs_json': jsonEncode(supportRefs),
        'counterexample_refs_json': jsonEncode(counterexampleRefs),
        'applicability_boundary': applicabilityBoundary.trim().isEmpty
            ? scope
            : applicabilityBoundary.trim(),
        'unexplained_details_json': jsonEncode(unexplainedDetails),
        'created_at_ms': now,
      });
      await txn.update(
        'xf_concept',
        <String, Object?>{
          'name': name,
          'scope': scope,
          'current_version_id': versionId,
          'status': 'ACTIVE',
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[conceptId],
      );
    });
  }

  Future<void> addExperience({
    required String id,
    required String rawEventId,
    required String problemId,
    required String type,
    required String content,
    required bool isUserWording,
    Map<String, Object?> observationConditions = const <String, Object?>{},
    bool userConfirmed = false,
  }) async {
    final db = await _database();
    await db.insert(
      'xf_experience',
      <String, Object?>{
        'id': id,
        'raw_event_id': rawEventId,
        'problem_id': problemId,
        'experience_type': type,
        'content': content,
        'is_user_wording': isUserWording ? 1 : 0,
        'observation_conditions_json': jsonEncode(observationConditions),
        'user_confirmed': userConfirmed ? 1 : 0,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> experiencesForProblem(String problemId) async {
    final db = await _database();
    return db.query(
      'xf_experience',
      where: 'problem_id = ?',
      whereArgs: <Object?>[problemId],
      orderBy: 'created_at_ms ASC',
    );
  }

  Future<void> addClaim({
    required String id,
    required String text,
    required String claimType,
    required XiangjiClaimState state,
    String problemId = '',
    String campaignId = '',
    String importance = 'medium',
    String sourceKind = 'user',
    String sourceRef = '',
    bool isUserWording = false,
    bool userConfirmed = false,
    XiangjiEpistemicProfile? profile,
    String systematicity = 'unknown',
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('xf_claim', <String, Object?>{
      'id': id,
      'problem_id': problemId,
      'campaign_id': campaignId,
      'claim_type': claimType,
      'text': text,
      'epistemic_status': state.wire,
      'importance': importance,
      'source_kind': sourceKind,
      'source_ref': sourceRef,
      'is_user_wording': isUserWording ? 1 : 0,
      'user_confirmed': userConfirmed ? 1 : 0,
      'profile_json': jsonEncode(profile?.toMap() ?? const <String, Object?>{}),
      'systematicity': systematicity,
      'version_no': 1,
      'supersedes_id': '',
      'valid_from_ms': now,
      'valid_to_ms': null,
      'created_at_ms': now,
      'updated_at_ms': now,
    });
  }

  Future<List<Map<String, Object?>>> claimsForProblem(String problemId) async {
    final db = await _database();
    return db.query(
      'xf_claim',
      where: 'problem_id = ? AND epistemic_status != ?',
      whereArgs: <Object?>[problemId, 'RETIRED'],
      orderBy: 'created_at_ms ASC',
    );
  }

  Future<List<Map<String, Object?>>> evidenceForProblem(String problemId) async {
    final db = await _database();
    return db.query(
      'xf_evidence',
      where: 'problem_id = ? AND deleted_at_ms IS NULL',
      whereArgs: <Object?>[problemId],
      orderBy: 'collected_at_ms DESC',
    );
  }

  Future<void> addGrounding({
    required String id,
    required String claimId,
    required String groundType,
    required String groundRefId,
    String relationType = 'supports',
    int directness = 0,
    String createdBy = 'user',
  }) async {
    final db = await _database();
    if (groundType == 'embedding' || groundType == 'semantic_similarity') {
      throw ArgumentError('Embedding/相似度只能召回候选材料，不能成为正式认识根据。');
    }
    await db.insert('xf_grounding_relation', <String, Object?>{
      'id': id,
      'claim_id': claimId,
      'ground_type': groundType,
      'ground_ref_id': groundRefId,
      'relation_type': relationType,
      'directness_level': directness,
      'created_by': createdBy,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> addEpistemicDebt({
    required String id,
    required String description,
    required String decisionImpact,
    required String groundingGap,
    String problemId = '',
    String campaignId = '',
    String premiseClaimId = '',
    String urgency = 'medium',
    String informationValue = '',
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('xf_epistemic_debt', <String, Object?>{
      'id': id,
      'problem_id': problemId,
      'campaign_id': campaignId,
      'premise_claim_id': premiseClaimId,
      'description': description,
      'decision_impact': decisionImpact,
      'grounding_gap': groundingGap,
      'urgency': urgency,
      'settlement_cost': '',
      'information_value': informationValue,
      'settlement_action_id': '',
      'status': 'open',
      'created_at_ms': now,
      'updated_at_ms': now,
    });
  }

  Future<List<Map<String, Object?>>> debts({
    String problemId = '',
    bool openOnly = true,
  }) async {
    final db = await _database();
    final clauses = <String>[];
    final args = <Object?>[];
    if (problemId.isNotEmpty) {
      clauses.add('problem_id = ?');
      args.add(problemId);
    }
    if (openOnly) {
      clauses.add("status = 'open'");
    }
    return db.query(
      'xf_epistemic_debt',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: "CASE decision_impact WHEN 'critical' THEN 0 WHEN 'high' THEN 1 ELSE 2 END, created_at_ms DESC",
    );
  }

  Future<List<String>> deleteEvidenceAndDowngradeClaims(String evidenceId) async {
    final db = await _database();
    final affected = <String>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final links = await txn.query(
        'xf_grounding_relation',
        columns: <String>['claim_id'],
        where: 'ground_type = ? AND ground_ref_id = ?',
        whereArgs: <Object?>['evidence', evidenceId],
      );
      affected.addAll(links.map((row) => (row['claim_id'] ?? '').toString()));
      await txn.update(
        'xf_evidence',
        <String, Object?>{'deleted_at_ms': now},
        where: 'id = ?',
        whereArgs: <Object?>[evidenceId],
      );
      await txn.delete(
        'xf_grounding_relation',
        where: 'ground_type = ? AND ground_ref_id = ?',
        whereArgs: <Object?>['evidence', evidenceId],
      );
      for (final claimId in affected.toSet()) {
        final remaining = Sqflite.firstIntValue(await txn.rawQuery(
              'SELECT COUNT(*) FROM xf_grounding_relation WHERE claim_id = ?',
              <Object?>[claimId],
            )) ??
            0;
        final claimRows = await txn.query(
          'xf_claim',
          columns: <String>['importance'],
          where: 'id = ?',
          whereArgs: <Object?>[claimId],
          limit: 1,
        );
        final high = claimRows.isNotEmpty &&
            <String>{'high', 'critical'}
                .contains((claimRows.first['importance'] ?? '').toString());
        if (remaining == 0) {
          await txn.update(
            'xf_claim',
            <String, Object?>{
              'epistemic_status': high ? 'EPISTEMIC_DEBT' : 'UNRESOLVED',
              'updated_at_ms': now,
            },
            where: 'id = ?',
            whereArgs: <Object?>[claimId],
          );
        }
      }
    });
    return affected.toSet().toList();
  }

  Future<String> createCampaign({
    required String id,
    required String title,
    required String northStar,
    required String strategicValue,
    bool isPrimary = false,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      if (isPrimary) {
        await txn.update('xf_campaign', <String, Object?>{'is_primary': 0});
      }
      await txn.insert('xf_campaign', <String, Object?>{
        'id': id,
        'title': title,
        'state': XiangjiCampaignState.idea.wire,
        'north_star': northStar,
        'grand_strategy': '',
        'theater': '',
        'strategic_value': strategicValue,
        'war_worthiness': '',
        'victory_criteria': '',
        'exit_criteria': '',
        'resource_budget_json': '{}',
        'review_at_ms': 0,
        'is_primary': isPrimary ? 1 : 0,
        'user_confirmed': 0,
        'version_no': 1,
        'created_at_ms': now,
        'updated_at_ms': now,
      });
    });
    return id;
  }

  Future<XiangjiCampaignRecord?> campaign(String id) async {
    final db = await _database();
    final rows = await db.query(
      'xf_campaign',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : XiangjiCampaignRecord.fromMap(rows.first);
  }

  Future<List<XiangjiCampaignRecord>> campaigns({bool includeClosed = false}) async {
    final db = await _database();
    final rows = await db.query(
      'xf_campaign',
      where: includeClosed ? null : 'state != ?',
      whereArgs: includeClosed ? null : <Object?>['CLOSED'],
      orderBy: 'is_primary DESC, updated_at_ms DESC',
    );
    return rows.map(XiangjiCampaignRecord.fromMap).toList();
  }

  Future<void> updateCampaign(
    String id,
    Map<String, Object?> values, {
    bool createVersion = false,
  }) async {
    final db = await _database();
    final normalized = <String, Object?>{
      ...values,
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
    };
    if (createVersion) {
      await db.rawUpdate(
        'UPDATE xf_campaign SET version_no = version_no + 1, updated_at_ms = ? WHERE id = ?',
        <Object?>[normalized['updated_at_ms'], id],
      );
      normalized.remove('version_no');
    }
    await db.update(
      'xf_campaign',
      normalized,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> addStrategyOption(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert('xf_strategy_option', values);
  }

  Future<List<Map<String, Object?>>> strategyOptions(String campaignId) async {
    final db = await _database();
    return db.rawQuery('''
      SELECT * FROM xf_strategy_option
      WHERE campaign_id = ?
        AND version_no = (
          SELECT MAX(version_no) FROM xf_strategy_option WHERE campaign_id = ?
        )
      ORDER BY selected DESC, created_at_ms ASC
    ''', <Object?>[campaignId, campaignId]);
  }

  Future<void> selectPreferredStrategy(String campaignId) async {
    final db = await _database();
    await db.transaction((txn) async {
      await txn.update(
        'xf_strategy_option',
        <String, Object?>{'selected': 0},
        where: 'campaign_id = ?',
        whereArgs: <Object?>[campaignId],
      );
      await txn.rawUpdate('''
        UPDATE xf_strategy_option
        SET selected = 1
        WHERE campaign_id = ?
          AND preferred = 1
          AND version_no = (
            SELECT MAX(version_no)
            FROM xf_strategy_option
            WHERE campaign_id = ?
          )
      ''', <Object?>[campaignId, campaignId]);
    });
  }

  Future<void> addCampaignIntel(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert('xf_campaign_intel', values);
  }

  Future<List<Map<String, Object?>>> campaignIntel(String campaignId) async {
    final db = await _database();
    return db.query(
      'xf_campaign_intel',
      where: 'campaign_id = ?',
      whereArgs: <Object?>[campaignId],
      orderBy: 'created_at_ms ASC',
    );
  }

  Future<void> saveContingency(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_contingency',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> contingencies(String campaignId) async {
    final db = await _database();
    return db.query(
      'xf_contingency',
      where: 'campaign_id = ? AND active = 1',
      whereArgs: <Object?>[campaignId],
      orderBy: 'created_at_ms ASC',
    );
  }

  Future<void> saveIndicator(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_indicator',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> indicators(String campaignId) async {
    final db = await _database();
    return db.query(
      'xf_indicator',
      where: 'campaign_id = ?',
      whereArgs: <Object?>[campaignId],
      orderBy: 'indicator_type ASC, created_at_ms ASC',
    );
  }

  Future<String> createAction({
    required String id,
    required String title,
    required Map<String, Object?> whyChain,
    required String prediction,
    String problemId = '',
    String campaignId = '',
    int expectedMinutes = 0,
    XiangjiActionState state = XiangjiActionState.ready,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.insert('xf_action', <String, Object?>{
        'id': id,
        'operator_id': '',
        'campaign_id': campaignId,
        'problem_id': problemId,
        'title': title,
        'state': state.wire,
        'why_chain_json': jsonEncode(whyChain),
        'prediction': prediction,
        'expected_minutes': expectedMinutes,
        'todo_ref': '',
        'blocker_type': '',
        'started_at_ms': 0,
        'completed_at_ms': 0,
        'created_at_ms': now,
        'updated_at_ms': now,
      });
      await txn.insert('xf_prediction', <String, Object?>{
        'id': '$id-prediction',
        'action_id': id,
        'statement': prediction,
        'expected_range': '',
        'evaluation_at_ms': 0,
        'criteria': '',
        'precommitted_at_ms': now,
      });
    });
    return id;
  }

  Future<XiangjiActionRecord?> action(String id) async {
    final db = await _database();
    final rows = await db.query(
      'xf_action',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : XiangjiActionRecord.fromMap(rows.first);
  }

  Future<List<XiangjiActionRecord>> actions({
    String problemId = '',
    String campaignId = '',
    bool currentOnly = false,
  }) async {
    final db = await _database();
    final where = <String>[];
    final args = <Object?>[];
    if (problemId.isNotEmpty) {
      where.add('problem_id = ?');
      args.add(problemId);
    }
    if (campaignId.isNotEmpty) {
      where.add('campaign_id = ?');
      args.add(campaignId);
    }
    if (currentOnly) {
      where.add('''(
        state IN ('READY','IN_PROGRESS','BLOCKED')
        OR (
          state = 'DONE'
          AND NOT EXISTS (
            SELECT 1 FROM xf_reality_result rr
            WHERE rr.action_id = xf_action.id
          )
        )
      )''');
    }
    final rows = await db.query(
      'xf_action',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: currentOnly
          ? "CASE state WHEN 'DONE' THEN 0 WHEN 'IN_PROGRESS' THEN 1 WHEN 'READY' THEN 2 ELSE 3 END, updated_at_ms DESC"
          : "CASE state WHEN 'IN_PROGRESS' THEN 0 WHEN 'READY' THEN 1 ELSE 2 END, updated_at_ms DESC",
    );
    return rows.map(XiangjiActionRecord.fromMap).toList();
  }

  Future<void> updateAction(
    String id,
    Map<String, Object?> values, {
    String eventType = 'updated',
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        'xf_action',
        <String, Object?>{...values, 'updated_at_ms': now},
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      await txn.insert('xf_action_log', <String, Object?>{
        'id': '$id-$eventType-$now',
        'action_id': id,
        'event_type': eventType,
        'details_json': jsonEncode(values),
        'occurred_at_ms': now,
      });
    });
  }

  Future<void> recordRealityResult({
    required String id,
    required String actionId,
    required List<String> facts,
    List<String> experiences = const <String>[],
    required List<String> unexpected,
    required List<String> sourceRefs,
    required String userInterpretation,
  }) async {
    if (facts.isEmpty || facts.length > 5) {
      throw ArgumentError('现实回填需包含 1-5 项可观察事实。');
    }
    final db = await _database();
    await db.insert(
      'xf_reality_result',
      <String, Object?>{
        'id': id,
        'action_id': actionId,
        'observed_at_ms': DateTime.now().millisecondsSinceEpoch,
        'facts_json': jsonEncode(facts),
        'experience_json': jsonEncode(experiences),
        'unexpected_json': jsonEncode(unexpected),
        'source_refs_json': jsonEncode(sourceRefs),
        'user_interpretation': userInterpretation,
        'verdict': 'unreviewed',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> realityResult(String actionId) async {
    final db = await _database();
    final rows = await db.query(
      'xf_reality_result',
      where: 'action_id = ?',
      whereArgs: <Object?>[actionId],
      orderBy: 'observed_at_ms DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> setRealityVerdict(String actionId, String verdict) async {
    final db = await _database();
    await db.update(
      'xf_reality_result',
      <String, Object?>{'verdict': verdict},
      where: 'action_id = ?',
      whereArgs: <Object?>[actionId],
    );
  }

  Future<void> saveTodoBinding({
    required String id,
    required String actionId,
    required String todoTaskId,
    required String todoListId,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.insert(
        'xf_todo_binding',
        <String, Object?>{
          'id': id,
          'action_id': actionId,
          'todo_task_id': todoTaskId,
          'todo_list_id': todoListId,
          'created_at_ms': now,
          'last_checked_at_ms': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.update(
        'xf_action',
        <String, Object?>{'todo_ref': todoTaskId, 'updated_at_ms': now},
        where: 'id = ?',
        whereArgs: <Object?>[actionId],
      );
    });
  }

  Future<List<Map<String, Object?>>> todoBindings() async {
    final db = await _database();
    return db.query('xf_todo_binding');
  }

  Future<void> saveAlert({
    required String id,
    required XiangjiAlertState state,
    required String alertType,
    required String reason,
    required String defaultAction,
    String campaignId = '',
    String problemId = '',
  }) async {
    final db = await _database();
    await db.insert(
      'xf_alert',
      <String, Object?>{
        'id': id,
        'campaign_id': campaignId,
        'problem_id': problemId,
        'state': state.wire,
        'alert_type': alertType,
        'reason': reason,
        'default_action': defaultAction,
        'status': 'open',
        'ignored_count': 0,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
        'resolved_at_ms': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> latestOpenAlert() async {
    final db = await _database();
    final rows = await db.query(
      'xf_alert',
      where: 'status = ?',
      whereArgs: <Object?>['open'],
      orderBy: "CASE state WHEN 'RED' THEN 0 WHEN 'ORANGE' THEN 1 WHEN 'BLUE' THEN 2 WHEN 'YELLOW' THEN 3 ELSE 4 END, created_at_ms DESC",
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> blockingRedAlert({
    String problemId = '',
    String campaignId = '',
  }) async {
    final db = await _database();
    final rows = await db.rawQuery('''
      SELECT * FROM xf_alert
      WHERE status = 'open' AND state = 'RED'
        AND (
          (COALESCE(problem_id, '') = '' AND COALESCE(campaign_id, '') = '')
          OR problem_id = ?
          OR campaign_id = ?
          OR (? != '' AND problem_id IN (
            SELECT id FROM xf_problem WHERE campaign_id = ?
          ))
        )
      ORDER BY created_at_ms DESC
      LIMIT 1
    ''', <Object?>[problemId, campaignId, campaignId, campaignId]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> latestOpenAlertForType(String alertType) async {
    final db = await _database();
    final rows = await db.query(
      'xf_alert',
      where: 'status = ? AND alert_type = ?',
      whereArgs: <Object?>['open', alertType],
      orderBy: 'created_at_ms DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> resolveOpenAlertsOfType(
    String alertType, {
    String problemId = '',
  }) async {
    final db = await _database();
    await db.update(
      'xf_alert',
      <String, Object?>{
        'status': 'resolved',
        'resolved_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: problemId.isEmpty
          ? 'status = ? AND alert_type = ?'
          : 'status = ? AND alert_type = ? AND problem_id = ?',
      whereArgs: problemId.isEmpty
          ? <Object?>['open', alertType]
          : <Object?>['open', alertType, problemId],
    );
  }

  Future<Map<String, Object?>> automaticMonitorSignals() async {
    final db = await _database();
    final criticalUnknownCount = Sqflite.firstIntValue(await db.rawQuery('''
          SELECT COUNT(*) FROM xf_information_need
          WHERE status = 'OPEN' AND decision_impact IN ('HIGH','CRITICAL')
        ''')) ??
        0;
    final highDebtCount = Sqflite.firstIntValue(await db.rawQuery('''
          SELECT COUNT(*) FROM xf_epistemic_debt
          WHERE status = 'open' AND decision_impact IN ('high','critical')
        ''')) ??
        0;
    final parallelHighLoadCampaigns =
        Sqflite.firstIntValue(await db.rawQuery('''
          SELECT COUNT(*) FROM xf_campaign
          WHERE state IN ('PREPARE','EXECUTING','ADJUST')
            AND resource_budget_json != '{}'
        ''')) ??
            0;
    final strategyResourceDriftCount =
        Sqflite.firstIntValue(await db.rawQuery('''
          SELECT COUNT(*) FROM xf_campaign
          WHERE is_primary = 0 AND state IN ('PREPARE','EXECUTING','ADJUST')
            AND resource_budget_json != '{}'
        ''')) ??
            0;
    final conceptRealityConflicts =
        Sqflite.firstIntValue(await db.rawQuery('''
          SELECT
            (SELECT COUNT(*) FROM xf_concept
             WHERE status IN ('UNDER_REVIEW','CONFLICTED')) +
            (SELECT COUNT(*) FROM xf_concept_reality_conflict
             WHERE status IN ('MISMATCH_DETECTED','UNDER_REVIEW'))
        ''')) ??
            0;
    final highRiskRows = await db.rawQuery('''
          SELECT object_id FROM xf_situation_model
          WHERE state != 'STALE'
            AND object_type = 'problem'
            AND model_json LIKE '%"high_risk":true%'
            AND model_json LIKE '%"irreversible":true%'
          ORDER BY generated_at_ms DESC
          LIMIT 1
        ''');
    final riskProblemId = highRiskRows.isEmpty
        ? ''
        : (highRiskRows.first['object_id'] ?? '').toString();
    final highRiskIrreversible = riskProblemId.isNotEmpty;
    final riskProblemDebtCount = riskProblemId.isEmpty
        ? 0
        : Sqflite.firstIntValue(await db.rawQuery('''
            SELECT
              (SELECT COUNT(*) FROM xf_epistemic_debt
               WHERE problem_id = ? AND status = 'open'
                 AND decision_impact IN ('high','critical')) +
              (SELECT COUNT(*) FROM xf_information_need
               WHERE problem_id = ? AND status = 'OPEN'
                 AND decision_impact IN ('HIGH','CRITICAL'))
          ''', <Object?>[riskProblemId, riskProblemId])) ??
            0;
    final outcomes = await db.rawQuery('''
      SELECT r.verdict, a.expected_minutes, a.problem_id
      FROM xf_reality_result r
      JOIN xf_action a ON a.id = r.action_id
      WHERE r.verdict != 'unreviewed'
      ORDER BY r.observed_at_ms DESC
      LIMIT 6
    ''');
    var consecutivePredictionMisses = 0;
    for (final row in outcomes) {
      if ((row['verdict'] ?? '').toString() != 'refutes') break;
      consecutivePredictionMisses++;
    }
    var investmentRisingWithoutResultCycles = 0;
    for (var index = 0; index + 1 < outcomes.length; index++) {
      final newest = outcomes[index];
      final older = outcomes[index + 1];
      final newestVerdict = (newest['verdict'] ?? '').toString();
      final olderVerdict = (older['verdict'] ?? '').toString();
      final bothIneffective =
          <String>{'refutes', 'partly_supports'}.contains(newestVerdict) &&
              <String>{'refutes', 'partly_supports'}.contains(olderVerdict);
      final newestEffort = (newest['expected_minutes'] as num?)?.toInt() ?? 0;
      final olderEffort = (older['expected_minutes'] as num?)?.toInt() ?? 0;
      if (!bothIneffective || newestEffort < olderEffort) break;
      investmentRisingWithoutResultCycles++;
    }
    if (investmentRisingWithoutResultCycles > 0) {
      investmentRisingWithoutResultCycles++;
    }

    final indicatorRows = await db.query(
      'xf_indicator',
      where: "latest_value IS NOT NULL AND TRIM(latest_value) != '' AND TRIM(threshold_text) != ''",
    );
    double? number(Object? raw) {
      final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch('$raw');
      return match == null ? null : double.tryParse(match.group(0)!);
    }
    var opportunityConditionTotal = 0;
    var opportunityConditionsMet = 0;
    for (final indicator in indicatorRows) {
      final latest = number(indicator['latest_value']);
      final threshold = number(indicator['threshold_text']);
      if (latest == null || threshold == null) continue;
      opportunityConditionTotal++;
      final direction = (indicator['direction'] ?? '').toString().toLowerCase();
      final met = direction.contains('down') ||
              direction.contains('below') ||
              direction.contains('下降') ||
              direction.contains('低于')
          ? latest <= threshold
          : latest >= threshold;
      if (met) opportunityConditionsMet++;
    }
    var relatedProblemId = riskProblemId;
    if (relatedProblemId.isEmpty &&
        consecutivePredictionMisses > 0 &&
        outcomes.isNotEmpty) {
      relatedProblemId = (outcomes.first['problem_id'] ?? '').toString();
    }
    if (relatedProblemId.isEmpty && conceptRealityConflicts > 0) {
      final rows = await db.rawQuery('''
        SELECT problem_id
        FROM xf_concept_reality_conflict
        WHERE status IN ('MISMATCH_DETECTED','UNDER_REVIEW')
        ORDER BY updated_at_ms DESC
        LIMIT 1
      ''');
      if (rows.isNotEmpty) {
        relatedProblemId = (rows.first['problem_id'] ?? '').toString();
      }
    }
    if (relatedProblemId.isEmpty && opportunityConditionsMet > 0) {
      final rows = await db.rawQuery('''
        SELECT p.id AS problem_id
        FROM xf_indicator i
        JOIN xf_problem p ON p.campaign_id = i.campaign_id
        WHERE p.problem_status = 'ACTIVE'
        ORDER BY COALESCE(i.latest_at_ms, i.created_at_ms) DESC
        LIMIT 1
      ''');
      if (rows.isNotEmpty) {
        relatedProblemId = (rows.first['problem_id'] ?? '').toString();
      }
    }
    if (relatedProblemId.isEmpty) {
      final rows = await db.rawQuery('''
        SELECT id AS problem_id
        FROM xf_problem
        WHERE problem_status = 'ACTIVE'
        ORDER BY updated_at_ms DESC
        LIMIT 1
      ''');
      if (rows.isNotEmpty) {
        relatedProblemId = (rows.first['problem_id'] ?? '').toString();
      }
    }
    return <String, Object?>{
      'critical_unknown_count': criticalUnknownCount,
      'consecutive_prediction_misses': consecutivePredictionMisses,
      'investment_rising_without_result_cycles':
          investmentRisingWithoutResultCycles,
      'parallel_high_load_campaigns': parallelHighLoadCampaigns,
      'high_risk_irreversible': highRiskIrreversible,
      'high_epistemic_debt': riskProblemId.isNotEmpty
          ? riskProblemDebtCount > 0
          : highDebtCount > 0 || criticalUnknownCount > 0,
      'risk_problem_id': riskProblemId,
      'related_problem_id': relatedProblemId,
      'opportunity_conditions_met': opportunityConditionsMet,
      'opportunity_condition_total': opportunityConditionTotal,
      'concept_reality_conflicts': conceptRealityConflicts,
      'strategy_resource_drift_count': strategyResourceDriftCount,
    };
  }

  Future<void> saveBattleReview(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert('xf_battle_review', values);
  }

  Future<List<Map<String, Object?>>> battleReviews() async {
    final db = await _database();
    return db.query('xf_battle_review', orderBy: 'created_at_ms DESC');
  }

  Future<void> saveAiError(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert('xf_ai_error', values);
  }

  Future<List<Map<String, Object?>>> aiErrors() async {
    final db = await _database();
    return db.query('xf_ai_error', orderBy: 'corrected_at_ms DESC');
  }

  Future<void> saveModelRun(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_model_run',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> modelRuns({int limit = 100}) async {
    final db = await _database();
    return db.query(
      'xf_model_run',
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
  }

  Future<List<XiangjiKnowledgeSourceRecord>> knowledgeSources({
    XiangjiKnowledgeLayer? layer,
    bool includeRetired = false,
  }) async {
    final db = await _database();
    final clauses = <String>[];
    final args = <Object?>[];
    if (layer != null) {
      clauses.add('s.layer = ?');
      args.add(layer.wire);
    }
    if (!includeRetired) {
      clauses.add("s.status != 'retired'");
    }
    final rows = await db.rawQuery('''
      SELECT s.*, COALESCE(d.local_uri, '') AS local_uri,
             COALESCE(d.mime, '') AS mime,
             COALESCE(d.parse_status, 'LOCAL_ONLY') AS parse_status,
             COALESCE(d.index_status, 'LOCAL_ONLY') AS index_status
      FROM xf_knowledge_source s
      LEFT JOIN xf_knowledge_document d ON d.source_id = s.id
      ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'}
      ORDER BY s.layer ASC, s.title ASC
    ''', args.isEmpty ? null : args);
    return rows.map(XiangjiKnowledgeSourceRecord.fromMap).toList();
  }

  Future<XiangjiKnowledgeSourceRecord?> knowledgeSource(String id) async {
    final db = await _database();
    final rows = await db.rawQuery('''
      SELECT s.*, COALESCE(d.local_uri, '') AS local_uri,
             COALESCE(d.mime, '') AS mime,
             COALESCE(d.parse_status, 'LOCAL_ONLY') AS parse_status,
             COALESCE(d.index_status, 'LOCAL_ONLY') AS index_status
      FROM xf_knowledge_source s
      LEFT JOIN xf_knowledge_document d ON d.source_id = s.id
      WHERE s.id = ? LIMIT 1
    ''', <Object?>[id]);
    return rows.isEmpty
        ? null
        : XiangjiKnowledgeSourceRecord.fromMap(rows.first);
  }

  Future<List<Map<String, Object?>>> knowledgeNodes({
    List<XiangjiKnowledgeLayer> layers = const <XiangjiKnowledgeLayer>[],
    String sourceId = '',
    int limit = 100,
  }) async {
    final db = await _database();
    final clauses = <String>["status = 'ACTIVE'"];
    final args = <Object?>[];
    if (sourceId.trim().isNotEmpty) {
      clauses.add('source_id = ?');
      args.add(sourceId.trim());
    }
    if (layers.isNotEmpty) {
      final placeholders = List<String>.filled(layers.length, '?').join(',');
      clauses.add('layer IN ($placeholders)');
      args.addAll(layers.map((layer) => layer.wire));
    }
    return db.rawQuery('''
      SELECT * FROM xf_knowledge_node
      WHERE ${clauses.join(' AND ')}
      ORDER BY layer ASC, name ASC LIMIT ?
    ''', <Object?>[...args, limit]);
  }

  Future<List<Map<String, Object?>>> knowledgeRules({
    String sourceId = '',
    bool enabledOnly = true,
  }) async {
    final db = await _database();
    final clauses = <String>[];
    final args = <Object?>[];
    if (sourceId.trim().isNotEmpty) {
      clauses.add('source_id = ?');
      args.add(sourceId.trim());
    }
    if (enabledOnly) clauses.add('enabled = 1');
    return db.query(
      'xf_knowledge_rule',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'rule_code ASC',
    );
  }

  Future<List<Map<String, Object?>>> personalRules({int limit = 30}) async {
    final db = await _database();
    return db.query(
      'xf_personal_rule',
      where: "epistemic_status NOT IN ('RETIRED','SUPERSEDED')",
      orderBy: 'last_validated_at_ms DESC, updated_at_ms DESC',
      limit: limit,
    );
  }

  Future<void> saveKnowledgeSource({
    required XiangjiKnowledgeSourceRecord source,
    required String documentId,
    required int byteSize,
    String lastError = '',
  }) async {
    final db = await _database();
    await db.transaction((txn) async {
      await txn.insert(
        'xf_knowledge_source',
        <String, Object?>{
          'id': source.id,
          'layer': source.layer.wire,
          'kind': source.kind,
          'title': source.title,
          'version': source.version,
          'status': source.status.name,
          'content_hash': source.contentHash,
          'sensitivity': source.sensitivity,
          'created_at_ms': source.createdAtMs,
          'updated_at_ms': source.updatedAtMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'xf_knowledge_document',
        <String, Object?>{
          'id': documentId,
          'source_id': source.id,
          'local_uri': source.localUri,
          'mime': source.mime,
          'parse_status': source.parseStatus,
          'index_status': source.indexStatus,
          'checksum': source.contentHash,
          'byte_size': byteSize,
          'last_error': lastError,
          'created_at_ms': source.createdAtMs,
          'updated_at_ms': source.updatedAtMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> savePassages(List<Map<String, Object?>> passages) async {
    if (passages.isEmpty) return;
    final db = await _database();
    final batch = db.batch();
    for (final passage in passages) {
      batch.insert(
        'xf_knowledge_passage',
        passage,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    await rebuildPassageIndex(db);
  }

  Future<void> rebuildPassageIndex([Database? database]) async {
    final db = database ?? await _database();
    try {
      await db.delete('xf_knowledge_passage_fts');
      await db.rawInsert('''
        INSERT INTO xf_knowledge_passage_fts(passage_id, title, locator, body)
        SELECT p.id, s.title, p.locator,
               trim(COALESCE(p.original_text, '') || ' ' || COALESCE(p.translation, ''))
        FROM xf_knowledge_passage p
        JOIN xf_knowledge_source s ON s.id = p.source_id
      ''');
    } catch (_) {
      // LIKE fallback is used by searchPassages.
    }
  }

  Future<List<Map<String, Object?>>> searchPassages(
    String query, {
    int limit = 50,
  }) async {
    final db = await _database();
    final value = query.trim();
    if (value.isEmpty) {
      return db.rawQuery('''
        SELECT p.*, s.title AS source_title
        FROM xf_knowledge_passage p
        JOIN xf_knowledge_source s ON s.id = p.source_id
        ORDER BY p.created_at_ms DESC LIMIT ?
      ''', <Object?>[limit]);
    }
    try {
      final indexed = await db.rawQuery('''
        SELECT p.*, s.title AS source_title
        FROM xf_knowledge_passage_fts f
        JOIN xf_knowledge_passage p ON p.id = f.passage_id
        JOIN xf_knowledge_source s ON s.id = p.source_id
        WHERE xf_knowledge_passage_fts MATCH ?
        LIMIT ?
      ''', <Object?>[value, limit]);
      if (indexed.isNotEmpty) return indexed;
    } catch (_) {
      // Fall through to exact substring search when FTS is unavailable.
    }
    // FTS4's default tokenizer can legitimately return no rows for CJK
    // substrings even though the authoritative passage contains the query.
    final like = '%$value%';
    return db.rawQuery('''
      SELECT p.*, s.title AS source_title
      FROM xf_knowledge_passage p
      JOIN xf_knowledge_source s ON s.id = p.source_id
      WHERE p.locator LIKE ? OR p.original_text LIKE ? OR p.translation LIKE ? OR s.title LIKE ?
      LIMIT ?
    ''', <Object?>[like, like, like, like, limit]);
  }

  Future<List<Map<String, Object?>>> sourcePassages(String sourceId) async {
    final db = await _database();
    return db.query(
      'xf_knowledge_passage',
      where: 'source_id = ?',
      whereArgs: <Object?>[sourceId],
      orderBy: 'chapter ASC, section ASC, locator ASC',
    );
  }

  Future<List<Map<String, Object?>>> enabledRules() async {
    final db = await _database();
    return db.rawQuery('''
      SELECT r.*, group_concat(b.requirement_id, ',') AS requirement_ids,
             group_concat(COALESCE(b.passage_id, ''), ',') AS passage_ids
      FROM xf_knowledge_rule r
      LEFT JOIN xf_rule_source_binding b ON b.rule_id = r.id
      WHERE r.enabled = 1
      GROUP BY r.id
      ORDER BY r.rule_code ASC
    ''');
  }

  Future<List<XiangjiProviderCapability>> providerCapabilities() async {
    final db = await _database();
    final rows = await db.query(
      'xf_provider_capability',
      orderBy: 'provider_id ASC',
    );
    return rows.map(XiangjiProviderCapability.fromMap).toList();
  }

  Future<XiangjiProviderCapability?> providerCapability(String providerId) async {
    final db = await _database();
    final rows = await db.query(
      'xf_provider_capability',
      where: 'provider_id = ?',
      whereArgs: <Object?>[providerId],
      limit: 1,
    );
    return rows.isEmpty ? null : XiangjiProviderCapability.fromMap(rows.first);
  }

  Future<void> saveProviderFile(XiangjiProviderFileRecord file) async {
    final db = await _database();
    await db.insert(
      'xf_provider_file',
      <String, Object?>{
        'id': file.id,
        'provider_id': file.providerId,
        'source_id': file.sourceId,
        'remote_file_id': file.remoteFileId,
        'remote_store_id': file.remoteStoreId,
        'status': file.state.wire,
        'uploaded_at_ms': file.uploadedAtMs,
        'expires_at_ms': file.expiresAtMs,
        'retention_info': file.retentionInfo,
        'last_error': file.lastError,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<XiangjiProviderFileRecord>> providerFiles({
    String sourceId = '',
  }) async {
    final db = await _database();
    final rows = await db.query(
      'xf_provider_file',
      where: sourceId.isEmpty ? null : 'source_id = ?',
      whereArgs: sourceId.isEmpty ? null : <Object?>[sourceId],
      orderBy: 'updated_at_ms DESC',
    );
    return rows.map(XiangjiProviderFileRecord.fromMap).toList();
  }

  Future<void> saveRetrievalTrace(XiangjiRetrievalTrace trace) async {
    final db = await _database();
    await db.insert(
      'xf_retrieval_trace',
      trace.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<XiangjiRetrievalTrace>> retrievalTraces({int limit = 30}) async {
    final db = await _database();
    final rows = await db.query(
      'xf_retrieval_trace',
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(XiangjiRetrievalTrace.fromMap).toList();
  }

  Future<void> saveKnowledgeUseRecord(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert('xf_knowledge_use_record', values);
  }

  Future<Map<String, Object?>?> knowledgeUseForTrace(String traceId) async {
    final db = await _database();
    final rows = await db.query(
      'xf_knowledge_use_record',
      where: 'retrieval_trace_id = ?',
      whereArgs: <Object?>[traceId],
      orderBy: 'created_at_ms DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveCandidateKnowledge({
    required String id,
    required String statement,
    required String originRunId,
    required List<String> supportingRefs,
    required List<String> counterRefs,
    required String validationPlan,
    required String scope,
    XiangjiKnowledgeItemState state = XiangjiKnowledgeItemState.candidate,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'xf_candidate_knowledge',
      <String, Object?>{
        'id': id,
        'statement': statement,
        'origin_run_id': originRunId,
        'supporting_refs_json': jsonEncode(supportingRefs),
        'counter_refs_json': jsonEncode(counterRefs),
        'validation_plan': validationPlan,
        'scope': scope,
        'status': state.wire,
        'version_no': 1,
        'last_validated_at_ms': null,
        'created_at_ms': now,
        'updated_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> candidateKnowledge() async {
    final db = await _database();
    return db.query(
      'xf_candidate_knowledge',
      orderBy: 'updated_at_ms DESC',
    );
  }

  Future<void> updateCandidateKnowledgeState(
    String id,
    XiangjiKnowledgeItemState state,
  ) async {
    if (state == XiangjiKnowledgeItemState.supported ||
        state == XiangjiKnowledgeItemState.stable) {
      throw StateError('SUPPORTED/STABLE 必须经过真实证据、范围与反例治理流程。');
    }
    final db = await _database();
    await db.update(
      'xf_candidate_knowledge',
      <String, Object?>{
        'status': state.wire,
        'last_validated_at_ms': DateTime.now().millisecondsSinceEpoch,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> applyCandidateValidation({
    required String id,
    required XiangjiKnowledgeItemState state,
    required List<String> supportingRefs,
    required List<String> counterRefs,
    required String validationPlan,
    required String scope,
    required int distinctEventCount,
    required bool userConfirmed,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'xf_candidate_knowledge',
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) throw ArgumentError('候选知识不存在。');
      await txn.update(
        'xf_candidate_knowledge',
        <String, Object?>{
          'supporting_refs_json': jsonEncode(supportingRefs),
          'counter_refs_json': jsonEncode(counterRefs),
          'validation_plan': validationPlan,
          'scope': scope,
          'status': state.wire,
          'version_no': ((rows.first['version_no'] as num?)?.toInt() ?? 0) + 1,
          'last_validated_at_ms': now,
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      if (state == XiangjiKnowledgeItemState.stable) {
        await txn.insert(
          'xf_personal_rule',
          <String, Object?>{
            'id': 'xf_personal_rule_$id',
            'rule_text': (rows.first['statement'] ?? '').toString(),
            'scope': scope,
            'evidence_count': supportingRefs.length,
            'counterexample_count': counterRefs.length,
            'epistemic_status': 'PROVISIONAL',
            'version_no': 1,
            'supersedes_id': '',
            'created_at_ms': now,
            'updated_at_ms': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await _insertAudit(
        txn,
        id: '$id-validation-$now',
        objectType: 'candidate_knowledge',
        objectId: id,
        eventType: 'validated_${state.wire.toLowerCase()}',
        actor: userConfirmed ? 'user' : 'system',
        after: <String, Object?>{
          'state': state.wire,
          'supporting_refs': supportingRefs,
          'counter_refs': counterRefs,
          'scope': scope,
          'distinct_event_count': distinctEventCount,
          'user_confirmed': userConfirmed,
        },
        now: now,
      );
    });
  }

  Future<void> saveKnowledgeConflict(Map<String, Object?> values) async {
    final db = await _database();
    await db.insert(
      'xf_knowledge_conflict',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> knowledgeConflicts() async {
    final db = await _database();
    return db.query(
      'xf_knowledge_conflict',
      orderBy: "CASE resolution_status WHEN 'unresolved' THEN 0 ELSE 1 END, updated_at_ms DESC",
    );
  }

  Future<List<Map<String, Object?>>> allClaims({int limit = 500}) async {
    final db = await _database();
    return db.query(
      'xf_claim',
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, Object?>>> allExperiences({int limit = 500}) async {
    final db = await _database();
    return db.query(
      'xf_experience',
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, Object?>>> conceptVersions({int limit = 300}) async {
    final db = await _database();
    return db.rawQuery('''
      SELECT v.*, c.name, c.scope, c.status
      FROM xf_concept_version v
      JOIN xf_concept c ON c.id = v.concept_id
      ORDER BY v.created_at_ms DESC
      LIMIT ?
    ''', <Object?>[limit]);
  }

  /// Produces a lossless module-level export. Provider credentials are never
  /// stored in xf_ tables and therefore cannot leak through this snapshot.
  Future<Map<String, Object?>> exportSnapshot() async {
    final db = await _database();
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'xf_%' ORDER BY name",
    );
    final tables = <String, Object?>{};
    for (final row in tableRows) {
      final name = (row['name'] ?? '').toString();
      if (name.isEmpty ||
          (name.startsWith('xf_knowledge_passage_fts_') &&
              name != 'xf_knowledge_passage_fts')) {
        continue;
      }
      try {
        tables[name] = await db.query(name);
      } catch (_) {
        // Some SQLite builds expose FTS shadow metadata that cannot be read as
        // a normal table. Authoritative passage rows are still exported.
      }
    }
    return <String, Object?>{
      'format': 'xiangji-future-strategist-v6.1-rev5.2',
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    };
  }

  /// Clears strategist-owned records only, then restores protected K0 rules
  /// and the capability registry. The caller must export first and obtain
  /// explicit user confirmation.
  Future<void> resetUserData() async {
    final db = await _database();
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'xf_%' ORDER BY name DESC",
    );
    await db.transaction((txn) async {
      for (final row in tableRows) {
        final name = (row['name'] ?? '').toString();
        if (name.isEmpty || name.startsWith('xf_knowledge_passage_fts_')) {
          continue;
        }
        try {
          await txn.delete(name);
        } catch (_) {
          // Optional FTS is not authoritative; never broaden deletion outside
          // this module because an index table cannot be cleared.
        }
      }
    });
    await _seedCoreKnowledge(db);
    await _seedPracticalProductData(db);
    await _ensureRev3SckRules(db);
    await _ensureRev4Rules(db);
    await _ensureRev52Metadata(db);
    await _seedProviderCapabilities(db);
    await rebuildPassageIndex(db);
  }

  Future<XiangjiDashboardSnapshot> dashboard() async {
    final db = await _database();
    final campaignRows = await db.query(
      'xf_campaign',
      where: "is_primary = 1 AND state != 'CLOSED'",
      orderBy: 'updated_at_ms DESC',
      limit: 1,
    );
    final actionRows = await db.rawQuery('''
      SELECT a.*
      FROM xf_action a
      WHERE a.state IN ('IN_PROGRESS','READY','BLOCKED')
         OR (
           a.state = 'DONE'
           AND NOT EXISTS (
             SELECT 1 FROM xf_reality_result rr WHERE rr.action_id = a.id
           )
         )
      ORDER BY CASE a.state
        WHEN 'DONE' THEN 0
        WHEN 'IN_PROGRESS' THEN 1
        WHEN 'READY' THEN 2
        ELSE 3
      END, a.updated_at_ms DESC
      LIMIT 1
    ''');
    final alert = await latestOpenAlert();
    final debtCount = Sqflite.firstIntValue(await db.rawQuery('''
          SELECT
            (SELECT COUNT(*) FROM xf_epistemic_debt
             WHERE status = 'open' AND decision_impact IN ('high','critical')) +
            (SELECT COUNT(*) FROM xf_information_need
             WHERE status = 'OPEN' AND decision_impact IN ('HIGH','CRITICAL'))
        ''')) ??
        0;
    final primary = campaignRows.isEmpty
        ? null
        : XiangjiCampaignRecord.fromMap(campaignRows.first);
    final currentAction = actionRows.isEmpty
        ? null
        : XiangjiActionRecord.fromMap(actionRows.first);
    final problemRows = await db.query(
      'xf_problem',
      where: primary == null
          ? "state != 'ARCHIVED' AND problem_status NOT IN ('ARCHIVED','MERGED')"
          : "state != 'ARCHIVED' AND problem_status NOT IN ('ARCHIVED','MERGED') AND campaign_id = ?",
      whereArgs: primary == null ? null : <Object?>[primary.id],
      orderBy: 'updated_at_ms DESC',
      limit: 1,
    );
    final latestProblem = problemRows.isEmpty
        ? null
        : XiangjiProblemRecord.fromMap(problemRows.first);
    final solverRows = latestProblem == null
        ? const <Map<String, Object?>>[]
        : await db.query(
            'xf_solver_snapshot',
            where: 'problem_id = ?',
            whereArgs: <Object?>[latestProblem.id],
            limit: 1,
          );
    final latestSolver = solverRows.isEmpty
        ? null
        : XiangjiSolverSnapshot.fromMap(solverRows.first);
    final decisionRows = await db.query(
      'xf_decision_draft',
      where: "user_status != 'STALE'",
      orderBy: 'updated_at_ms DESC',
      limit: 1,
    );
    final gapRows = await db.query(
            'xf_problem_item',
            where: primary == null
                ? "kind = 'gap' AND status = 'active'"
                : "kind = 'gap' AND status = 'active' AND problem_id IN (SELECT id FROM xf_problem WHERE campaign_id = ?)",
            whereArgs: primary == null ? null : <Object?>[primary.id],
            orderBy: 'critical DESC, sort_order ASC',
            limit: 1,
          );
    final contingencyRows = primary == null
        ? const <Map<String, Object?>>[]
        : await db.query(
            'xf_contingency',
            where: 'campaign_id = ? AND active = 1',
            whereArgs: <Object?>[primary.id],
            orderBy: 'created_at_ms DESC',
            limit: 1,
          );
    return XiangjiDashboardSnapshot(
      northStar: primary?.northStar ??
          latestSolver?.goalSummary ??
          latestProblem?.goalText ??
          '',
      primaryCampaign: primary,
      currentProblem: latestProblem,
      currentAction: currentAction,
      alertState:
          alert == null ? XiangjiAlertState.green : parseAlertState(alert['state']),
      alertReason: (alert?['reason'] ?? '').toString(),
      alertDefaultAction: (alert?['default_action'] ?? '').toString(),
      keyGap: latestSolver?.keyGapSummary.isNotEmpty == true
          ? latestSolver!.keyGapSummary
          : gapRows.isEmpty
              ? ''
              : (gapRows.first['text'] ?? '').toString(),
      strategistJudgment: decisionRows.isEmpty
          ? ''
          : (decisionRows.first['judgment'] ?? '').toString(),
      strategistEpistemicStatus: decisionRows.isEmpty
          ? ''
          : (decisionRows.first['epistemic_status'] ?? '').toString(),
      contingency: contingencyRows.isNotEmpty
          ? '${contingencyRows.first['trigger_expression']} -> ${contingencyRows.first['action_plan']}'
          : decisionRows.isEmpty
              ? ''
              : (decisionRows.first['change_signals'] ?? '').toString(),
      nextReviewAtMs: primary?.reviewAtMs ?? latestProblem?.reviewAtMs ?? 0,
      unresolvedDebtCount: debtCount,
    );
  }

  Future<void> _insertAudit(
    DatabaseExecutor db, {
    required String id,
    required String objectType,
    required String objectId,
    required String eventType,
    required String actor,
    Map<String, Object?> before = const <String, Object?>{},
    Map<String, Object?> after = const <String, Object?>{},
    required int now,
  }) =>
      db.insert('xf_audit_log', <String, Object?>{
        'id': id,
        'object_type': objectType,
        'object_id': objectId,
        'event_type': eventType,
        'actor': actor,
        'before_json': jsonEncode(before),
        'after_json': jsonEncode(after),
        'created_at_ms': now,
      });
}
