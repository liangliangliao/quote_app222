import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'xiangji_models.dart';

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
    await _seedProviderCapabilities(db);
    _ensured = true;
  }

  static const List<String> _schemaStatements = <String>[
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
    'CREATE INDEX IF NOT EXISTS idx_xf_experience_problem ON xf_experience(problem_id, created_at_ms)',
    'CREATE INDEX IF NOT EXISTS idx_xf_claim_problem ON xf_claim(problem_id, epistemic_status)',
    'CREATE INDEX IF NOT EXISTS idx_xf_grounding_claim ON xf_grounding_relation(claim_id)',
    'CREATE INDEX IF NOT EXISTS idx_xf_grounding_ref ON xf_grounding_relation(ground_ref_id)',
    'CREATE INDEX IF NOT EXISTS idx_xf_debt_problem ON xf_epistemic_debt(problem_id, status)',
    'CREATE INDEX IF NOT EXISTS idx_xf_problem_state ON xf_problem(state, updated_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_problem_item ON xf_problem_item(problem_id, kind, sort_order)',
    'CREATE INDEX IF NOT EXISTS idx_xf_campaign_primary ON xf_campaign(is_primary, state)',
    'CREATE INDEX IF NOT EXISTS idx_xf_action_current ON xf_action(state, updated_at_ms DESC)',
    'CREATE INDEX IF NOT EXISTS idx_xf_passage_source ON xf_knowledge_passage(source_id, locator)',
    'CREATE INDEX IF NOT EXISTS idx_xf_node_source ON xf_knowledge_node(source_id, layer)',
    'CREATE INDEX IF NOT EXISTS idx_xf_edge_from ON xf_knowledge_edge(from_id, relation_type)',
    'CREATE INDEX IF NOT EXISTS idx_xf_provider_source ON xf_provider_file(source_id, provider_id)',
    'CREATE INDEX IF NOT EXISTS idx_xf_trace_request ON xf_retrieval_trace(request_id, created_at_ms DESC)',
  ];

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
        'version': 'V6.1-Rev2',
        'status': 'active',
        'content_hash': 'bundled-k0-v6.1-rev2',
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
        'checksum': 'bundled-k0-v6.1-rev2',
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
          'version': 'V6.1-Rev2',
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
      where: includeArchived ? null : 'state != ?',
      whereArgs: includeArchived ? null : <Object?>['ARCHIVED'],
      orderBy: 'updated_at_ms DESC',
    );
    return rows.map(XiangjiProblemRecord.fromMap).toList();
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
        <String, Object?>{'state': state.wire, 'updated_at_ms': now},
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
        'source_refs_json': '[]',
        'created_at_ms': now,
      });
      await txn.update(
        'xf_concept',
        <String, Object?>{
          'name': name,
          'scope': scope,
          'current_version_id': versionId,
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
    return db.query(
      'xf_strategy_option',
      where: 'campaign_id = ?',
      whereArgs: <Object?>[campaignId],
      orderBy: 'selected DESC, created_at_ms ASC',
    );
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
      where.add("state IN ('READY','IN_PROGRESS','BLOCKED')");
    }
    final rows = await db.query(
      'xf_action',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: "CASE state WHEN 'IN_PROGRESS' THEN 0 WHEN 'READY' THEN 1 ELSE 2 END, updated_at_ms DESC",
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
    int limit = 100,
  }) async {
    final db = await _database();
    if (layers.isEmpty) {
      return db.query(
        'xf_knowledge_node',
        where: "status = 'ACTIVE'",
        orderBy: 'layer ASC, name ASC',
        limit: limit,
      );
    }
    final placeholders = List<String>.filled(layers.length, '?').join(',');
    return db.rawQuery('''
      SELECT * FROM xf_knowledge_node
      WHERE status = 'ACTIVE' AND layer IN ($placeholders)
      ORDER BY layer ASC, name ASC LIMIT ?
    ''', <Object?>[...layers.map((layer) => layer.wire), limit]);
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
      'format': 'xiangji-future-strategist-v6.1-rev2',
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
    final actionRows = await db.query(
      'xf_action',
      where: "state IN ('IN_PROGRESS','READY','BLOCKED')",
      orderBy: "CASE state WHEN 'IN_PROGRESS' THEN 0 WHEN 'READY' THEN 1 ELSE 2 END, updated_at_ms DESC",
      limit: 1,
    );
    final alert = await latestOpenAlert();
    final debtCount = Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM xf_epistemic_debt WHERE status = 'open' AND decision_impact IN ('high','critical')",
        )) ??
        0;
    final primary = campaignRows.isEmpty
        ? null
        : XiangjiCampaignRecord.fromMap(campaignRows.first);
    final currentAction = actionRows.isEmpty
        ? null
        : XiangjiActionRecord.fromMap(actionRows.first);
    final gapRows = primary == null
        ? const <Map<String, Object?>>[]
        : await db.query(
            'xf_problem_item',
            where:
                "kind = 'gap' AND status = 'active' AND problem_id IN (SELECT id FROM xf_problem WHERE campaign_id = ?)",
            whereArgs: <Object?>[primary.id],
            orderBy: 'critical DESC, sort_order ASC',
            limit: 1,
          );
    final latestClaimRows = primary == null
        ? const <Map<String, Object?>>[]
        : await db.query(
            'xf_claim',
            where: 'campaign_id = ?',
            whereArgs: <Object?>[primary.id],
            orderBy: 'updated_at_ms DESC',
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
      northStar: primary?.northStar ?? '',
      primaryCampaign: primary,
      currentAction: currentAction,
      alertState:
          alert == null ? XiangjiAlertState.green : parseAlertState(alert['state']),
      alertReason: (alert?['reason'] ?? '').toString(),
      keyGap: gapRows.isEmpty ? '' : (gapRows.first['text'] ?? '').toString(),
      strategistJudgment: latestClaimRows.isEmpty
          ? ''
          : (latestClaimRows.first['text'] ?? '').toString(),
      contingency: contingencyRows.isEmpty
          ? ''
          : '${contingencyRows.first['trigger_expression']} -> ${contingencyRows.first['action_plan']}',
      nextReviewAtMs: primary?.reviewAtMs ?? 0,
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
