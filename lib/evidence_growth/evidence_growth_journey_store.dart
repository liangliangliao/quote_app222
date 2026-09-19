import 'dart:convert';
import 'dart:math';
import 'package:sqflite_common/sqlite_api.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_models.dart';
import 'evidence_growth_knowledge.dart';
import 'evidence_growth_search.dart';
import 'evidence_growth_cycle.dart';
import 'evidence_growth_journey_models.dart';

/// Aggregate boundaries and gates are deterministic, shared by Android and API.
/// Trial retains its original prediction. Journal and dossiers are append-only.
class EvidenceGrowthJourneyStore {
  EvidenceGrowthJourneyStore(this.dao);
  final EvidenceGrowthDao dao;
  static String newId([String prefix = 'gj']) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32).toRadixString(16)}';
  Future<Database> get db async {
    await dao.ensureTables();
    return dao.knowledgeDatabase();
  }

  static Future<void> install(Database db) async {
    await db.transaction((tx) async {
      await tx.execute(
          'CREATE TABLE IF NOT EXISTS evidence_growth_journeys (id TEXT PRIMARY KEY, status TEXT NOT NULL, version INTEGER NOT NULL, body_json TEXT NOT NULL)');
      await tx.execute(
          'CREATE TABLE IF NOT EXISTS evidence_growth_journal (id TEXT PRIMARY KEY, journey_id TEXT NOT NULL, kind TEXT NOT NULL, created_at_ms INTEGER NOT NULL, body_json TEXT NOT NULL)');
      await tx.execute(
          'CREATE INDEX IF NOT EXISTS eg_journal_parent ON evidence_growth_journal(journey_id, created_at_ms)');
      await tx.execute(
          'CREATE TABLE IF NOT EXISTS evidence_growth_journey_actions (trial_id TEXT PRIMARY KEY, journey_id TEXT NOT NULL, cycle INTEGER NOT NULL, plan_version INTEGER NOT NULL)');
      await tx.execute(
          "CREATE TRIGGER IF NOT EXISTS eg_journal_immutable BEFORE UPDATE ON evidence_growth_journal BEGIN SELECT RAISE(ABORT,'Historical evidence is immutable'); END");
      // One-time migration, deterministic IDs across devices. No synthetic past
      // prediction, criterion or achievement is inferred from an old Trial.
      final done = await tx.query('evidence_growth_settings',
          where: 'setting_key=?', whereArgs: ['journey_migration']);
      if (done.isNotEmpty) return;
      for (final row in await tx.query('evidence_growth_trials',
          orderBy: 'created_at_ms ASC')) {
        final t = RealityTrial.fromRow(row);
        final id = 'legacy_${t.operatorInputs['cycle_root'] ?? t.id}';
        final previous = await read(tx, id);
        final proposal = GrowthProblemProfile.resolve(t.rawInput);
        final j = previous ??
            draft(
                id,
                t.goalState.isEmpty ? '已有现实问题' : t.goalState,
                GrowthProblemProfile(
                    {...proposal.data, 'lifecycle_type': 'FINITE'}));
        final data = {
          ...j.data,
          'legacy': true,
          'trial_id': t.id,
          'cycle': EvidenceGrowthCycle.round(t),
          'status': 'DRAFT',
          'node': t.status == 'RESULT_CAPTURED'
              ? 'OUTCOME'
              : t.status == 'REVIEWED'
                  ? 'CHANGE'
                  : t.isClosed
                      ? 'GOAL_GATE'
                      : 'ACTION',
          'current': t.actualOutcome.isEmpty ? t.currentState : t.actualOutcome
        };
        await put(tx, GrowthJourney(data));
        await tx.insert(
            'evidence_growth_journey_actions',
            {
              'trial_id': t.id,
              'journey_id': id,
              'cycle': EvidenceGrowthCycle.round(t),
              'plan_version': 1
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await tx.insert('evidence_growth_settings',
          {'setting_key': 'journey_migration', 'setting_value': '2.7'});
    });
  }

  static GrowthJourney draft(String id, String raw, GrowthProblemProfile p) =>
      GrowthJourney({
        'id': id,
        'version': 1,
        'title': raw,
        'raw_input': raw,
        'profile': p.data,
        'status': 'DRAFT',
        'node': 'BELIEF',
        'cycle': 1,
        'trial_id': '',
        'current': '',
        'belief': '',
        'readiness': 'UNKNOWN',
        'event_phase': 'PRE_EVENT',
        'mutuality': 'UNKNOWN',
        'contract': {'version': 0, 'confirmed': false},
        'plan': {'version': 0},
        'criteria_evidence': {},
        'candidates': [],
        'participants': [],
        'routes': [],
        'stage': {},
        'change_attempts': [],
        'allocation': {
          'minutes': 0,
          'money': 0,
          'energy': 0,
          'risk': 0,
          'priority': 2
        },
      });
  static Future<GrowthJourney?> read(DatabaseExecutor tx, String id) async {
    final r = await tx
        .query('evidence_growth_journeys', where: 'id=?', whereArgs: [id]);
    return r.isEmpty
        ? null
        : GrowthJourney(growthMap(jsonDecode(r.single['body_json'] as String)));
  }

  static Future<void> put(DatabaseExecutor tx, GrowthJourney j) async =>
      tx.insert(
          'evidence_growth_journeys',
          {
            'id': j.id,
            'status': j.status,
            'version': j.version,
            'body_json': jsonEncode(j.data)
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
  static Future<String> log(DatabaseExecutor tx, GrowthJourney j, String kind,
      GrowthData body) async {
    final id = newId('gr');
    await tx.insert('evidence_growth_journal', {
      'id': id,
      'journey_id': j.id,
      'kind': kind,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      'body_json': jsonEncode({
        'cycle': j.cycle,
        'goal_version': j.contract['version'],
        'plan_version': j.plan['version'],
        'eng_rule': 'ENG-2.7',
        ...body
      })
    });
    return id;
  }

  static List<EvidenceKNode> evidence(String node, String query) {
    final module = GrowthModuleX.parse(node == 'OUTCOME'
        ? 'FAILURE'
        : node == 'BELIEF_CHECKPOINT'
            ? 'BELIEF'
            : node);
    final found = EvidenceGrowthSearch.current
        .search(query, module: module, talOnly: true, limit: 2)
        .map((r) => r.node)
        .toList();
    return found.isNotEmpty
        ? found
        : EvidenceGrowthKnowledge.forModule(module)
            .where((n) => n.isTal)
            .take(1)
            .toList();
  }

  static Future<void> nodeRun(DatabaseExecutor tx, GrowthJourney j, String node,
      GrowthData input, GrowthData output,
      {String mode = 'USER_CONFIRMED'}) async {
    final nodes = evidence(node, '${j.title} ${jsonEncode(input)}');
    if (nodes.isEmpty) throw StateError('KB_EVIDENCE_INSUFFICIENT');
    await log(tx, j, 'NODE_RUN', {
      'node': node,
      'mode': mode,
      'input': input,
      'output': output,
      'kb_version': EvidenceGrowthKnowledge.kbVersion,
      'prompt_version': EvidenceGrowthKnowledge.promptVersion,
      'knowledge_evidence': nodes.map((n) => n.toJson()).toList(),
      'personal_evidence_source': 'USER_ATTESTATION',
      'ai_inference_is_fact': false
    });
  }

  Future<GrowthJourney?> find(String id) async => read(await db, id);
  Future<GrowthJourney?> forTrial(String id) async {
    final tx = await db;
    final rows = await tx.query('evidence_growth_journey_actions',
        where: 'trial_id=?', whereArgs: [id]);
    return rows.isEmpty ? null : read(tx, rows.single['journey_id'] as String);
  }

  Future<List<GrowthJourney>> list() async => (await (await db).query(
          'evidence_growth_journeys',
          where: "id != 'portfolio' AND status != 'DELETED'"))
      .map(
          (r) => GrowthJourney(growthMap(jsonDecode(r['body_json'] as String))))
      .toList();
  Future<List<GrowthData>> history(String id) async =>
      (await (await db).query('evidence_growth_journal',
              where: 'journey_id=?',
              whereArgs: [id],
              orderBy: 'created_at_ms ASC,id ASC'))
          .map((r) => {
                'id': r['id'],
                'kind': r['kind'],
                'at': r['created_at_ms'],
                ...growthMap(jsonDecode(r['body_json'] as String))
              })
          .toList();
  Future<void> recordDraft(GrowthJourney j, String purpose, GrowthData result,
      List<EvidenceKNode> nodes) async {
    await (await db).transaction((tx) async {
      final current = await read(tx, j.id);
      if (current == null || current.version != j.version) return;
      await log(tx, j, 'AI_DRAFT', {
        'purpose': purpose,
        'output': result,
        'user_confirmed': false,
        'knowledge_evidence': nodes.map((n) => n.toJson()).toList(),
        'kb_version': EvidenceGrowthKnowledge.kbVersion,
        'prompt_version': EvidenceGrowthKnowledge.promptVersion
      });
    });
  }

  Future<GrowthJourney> create(String raw,
      {GrowthProblemProfile? profile, String? parentId}) async {
    if (raw.trim().isEmpty || raw.length > 10000)
      throw ArgumentError('请先说一件现实中的事');
    final p = (profile ?? GrowthProblemProfile.resolve(raw)).checked();
    final j = draft(newId(), raw.trim(), p).copy({'parent_id': parentId});
    await (await db).transaction((tx) async {
      if (parentId != null && await read(tx, parentId) == null)
        throw StateError('父目标不存在');
      await put(tx, j);
      await log(tx, j, 'ENTRY', {'raw_input': raw, 'profile': p.data});
      await log(tx, j, 'CYCLE', {'trigger': 'ENTRY'});
    });
    return j;
  }

  Future<GrowthJourney> change(GrowthJourney expected, String operation,
      [GrowthData body = const {}]) async {
    return (await db).transaction((tx) async {
      final j = await read(tx, expected.id);
      if (j == null || j.version != expected.version)
        throw StateError('记录已变化，请刷新后重试');
      if (j.status == 'DELETED') throw StateError('目标已删除');
      if (j.terminal && operation != 'reopen')
        throw StateError('已结束的目标保留原始证据；请先重开再补充新的现实');
      final result = await operate(tx, j, operation, body);
      final updated = result.copy({
        'version': j.version + 1,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch
      });
      await put(tx, updated);
      await log(tx, updated, operation.toUpperCase(), body);
      await cancelIneligible(tx, updated);
      return updated;
    });
  }

  static void requireText(GrowthData b, List<String> keys) {
    for (final k in keys)
      if (b[k] is! String || (b[k] as String).trim().isEmpty)
        throw ArgumentError('缺少 $k');
  }

  static Future<GrowthJourney> operate(
      DatabaseExecutor tx, GrowthJourney j, String op, GrowthData b) async {
    switch (op) {
      case 'profile':
        if (b.keys.any((k) => !const [
              'scope',
              'goal_mode',
              'control_type',
              'ownership_mode',
              'structure_type',
              'lifecycle_type'
            ].contains(k))) throw ArgumentError('这些风险/事实坐标不能由配置操作覆盖');
        if (j.confirmed) throw StateError('目标合同确认后通过合同修订调整方向');
        final p = GrowthProblemProfile(
                {...j.profile.data, ...b, 'provenance': 'USER_CORRECTED'})
            .checked();
        return j.copy({'profile': p.data});
      case 'entry':
        requireText(b, ['text']);
        return j.copy({
          'pending_entry': b['text'],
          'entry_profile': GrowthProblemProfile.resolve(b['text']).data,
          'entry_received_at_ms': DateTime.now().millisecondsSinceEpoch
        });
      case 'entry-consume':
        if ('${j.data['pending_entry'] ?? ''}'.isEmpty)
          throw StateError('没有待处理的新信息');
        requireText(b, ['use']);
        if (b['use'] != 'CONTEXT') throw ArgumentError('请在对应步骤确认事实、学习或改变');
        return j.copy({
          'current':
              '${j.data['current'] ?? ''}\n补充事实：${j.data['pending_entry']}',
          'pending_entry': ''
        });
      case 'campaign':
        if (!j.confirmed ||
            j.node != 'ACTION' ||
            j.trialId.isNotEmpty ||
            growthRows(growthMap(j.data['campaign'])['samples']).isNotEmpty)
          throw StateError('开始采样前设置学习窗口，已有样本不能改写');
        final count = growthInt(b['sample_target'], 1);
        final deadline = growthInt(b['deadline_ms']);
        if (count < 1 ||
            count > 20 ||
            (deadline != 0 &&
                deadline <= DateTime.now().millisecondsSinceEpoch))
          throw ArgumentError('样本数为 1–20；截止时间应在未来');
        return j.copy({
          'campaign': {
            ...campaignFor(j),
            'sample_target': count,
            'deadline_ms': deadline,
            'boundary_reason': '',
            'status': 'COLLECTING'
          }
        });
      case 'campaign-close':
        final c = campaignFor(j),
            samples = growthRows(campaignFor(j)['samples']);
        if (j.node != 'ACTION' || j.trialId.isNotEmpty || samples.isEmpty)
          throw StateError('先记录当前行动的真实结果');
        requireText(b, ['reason']);
        await log(
            tx, j, 'LEARNING_BOUNDARY', {'campaign': c, 'reason': b['reason']});
        return j.copy({
          'node': 'REVIEW',
          'readiness': 'UNKNOWN',
          'trial_id': samples.last['trial_id'] ?? '',
          'campaign': {
            ...c,
            'status': 'READY_FOR_REVIEW',
            'boundary_reason': b['reason']
          }
        });
      case 'contract':
        if (j.confirmed && !j.node.endsWith('_GATE'))
          throw StateError('本轮完成后再修订目标，避免修改正在执行的合同');
        if (j.profile.blocked) throw StateError('请先处理安全或结构缺口');
        requireText(b, ['goal', 'current', 'criterion']);
        final revision = j.confirmed;
        final contract = {
          'version': growthInt(j.contract['version']) + 1,
          'confirmed': true,
          'goal': b['goal'],
          'current': b['current'],
          'criterion': b['criterion'],
          'quality': b['quality'] ?? '',
          'deadline': b['deadline'] ?? '',
          'control_boundary': b['control_boundary'] ?? '',
          'evidence_policy': 'USER_ATTESTATION_ACCEPTED',
          'criteria': [
            for (final line in (b['criterion'] as String)
                .split('\n')
                .where((v) => v.trim().isNotEmpty))
              {'statement': line.trim(), 'required': true}
          ],
          'source': 'USER_CONFIRMED'
        };
        var next = j.copy({
          'title': b['goal'],
          'current': b['current'],
          'belief': b['belief'] ?? j.data['belief'],
          'contract': contract,
          'criteria_evidence': {},
          'status': 'ACTIVE',
          'node': 'ACTION',
          'contract_revision_required': false
        });
        await nodeRun(tx, next, 'BELIEF', {'entry': j.profile.fragments},
            {'belief': next.data['belief'], 'unknown_history_preserved': true},
            mode: 'CHECKPOINT');
        await nodeRun(
            tx, next, 'GOAL', {'belief': next.data['belief']}, contract);
        await log(tx, next, 'GOAL_CONTRACT', contract);
        if (revision) {
          final plan = {
            ...j.plan,
            'plan_id': j.plan['plan_id'] ?? 'plan_${j.id}',
            'version': growthInt(j.plan['version']) + 1,
            'goal_version': contract['version'],
            'campaign_id': newId('campaign')
          };
          await log(tx, next, 'PLAN_REVISION', {
            'before': j.plan,
            'after': plan,
            'diff': {'reason': '用户修订目标合同，重新核对行动适用性'}
          });
          next = await newCycle(tx, next.copy({'plan': plan}));
        }
        if (growthInt(j.plan['version']) == 0) {
          final plan = {
            'version': 1,
            'plan_id': newId('plan'),
            'goal_version': contract['version'],
            'strategy': b['strategy'] ?? '先完成一轮现实采样，再按结果调整',
            'status': 'ACTIVE',
            'campaign_id': newId('campaign')
          };
          next = next.copy({'plan': plan});
          await log(tx, next, 'ACTION_PLAN', plan);
        }
        // Imported old action continues where reality stopped; never redo it.
        if (j.data['legacy'] == true && !revision)
          next = next.copy({'node': j.node});
        return next;
      case 'outcome':
        if (!j.confirmed || !const ['ACTION', 'OUTCOME'].contains(j.node))
          throw StateError('当前不能重复记录结果');
        if (j.trialId.isNotEmpty && j.node == 'ACTION')
          throw StateError('请在已绑定的行动中记录结果');
        requireText(b, ['facts']);
        if (j.trialId.isNotEmpty) {
          final rows = await tx.query('evidence_growth_trials',
              where: 'trial_id=?', whereArgs: [j.trialId]);
          if (rows.isEmpty || rows.single['actual_outcome'] != b['facts'])
            throw StateError('本次结果以行动页保存的原始事实为准');
        }
        final outcome = GrowthProblemProfile.outcome(b['facts'],
            object: b['object'] ?? 'UNKNOWN', explicit: b['explicit'] == true);
        await nodeRun(
            tx,
            j,
            'OUTCOME',
            {
              'actual': b['facts'],
              'prediction':
                  j.trialId.isEmpty ? 'NOT_RECORDED_BEFORE_EVENT' : 'IN_TRIAL'
            },
            outcome);
        var routes = growthRows(j.data['routes']);
        if (outcome['route_effect'] == 'ROUTE_CLOSED' && routes.isNotEmpty) {
          routes = [
            for (final r in routes)
              {...r, if (r['id'] == j.data['active_route']) 'status': 'CLOSED'}
          ];
        }
        final c = campaignFor(j);
        final sample = {
          'trial_id': j.trialId,
          'facts': b['facts'],
          'outcome': outcome,
          'at_ms': DateTime.now().millisecondsSinceEpoch
        };
        final samples = [...growthRows(c['samples']), sample];
        final major = b['significant_event'] == true ||
            outcome['verb'] == 'REJECTION' ||
            const ['ROUTE_CLOSED', 'STAGE_BLOCKED']
                .contains(outcome['route_effect']);
        final due = growthInt(c['deadline_ms']) > 0 &&
            DateTime.now().millisecondsSinceEpoch >=
                growthInt(c['deadline_ms']);
        final boundary =
            major || due || samples.length >= growthInt(c['sample_target'], 1);
        final reason = major
            ? '出现重大事件或边界变化'
            : due
                ? '到达学习窗口截止时间'
                : '达到约定样本数';
        final campaign = {
          ...c,
          'samples': samples,
          'status': boundary ? 'READY_FOR_REVIEW' : 'COLLECTING',
          'boundary_reason': boundary ? reason : ''
        };
        await log(tx, j, 'CAMPAIGN_SAMPLE', {
          ...sample,
          'campaign_id': c['id'],
          'plan_id': c['plan_id'],
          'plan_version': c['plan_version']
        });
        if (boundary)
          await log(tx, j, 'LEARNING_BOUNDARY',
              {'campaign': campaign, 'reason': reason});
        return j.copy({
          'campaign': campaign,
          'trial_id': boundary ? j.trialId : '',
          'outcome': outcome,
          'routes': routes,
          'current': b['facts'],
          'node': boundary ? 'REVIEW' : 'ACTION',
          'event_phase': 'POST_EVENT',
          'pending_entry': '',
          'readiness': j.profile.data['processing_state'] == 'DEFERRED'
              ? 'DEFERRED'
              : 'UNKNOWN',
          'stage': {
            ...growthMap(j.data['stage']),
            if (outcome['route_effect'] == 'STAGE_BLOCKED') 'status': 'BLOCKED'
          }
        });
      case 'readiness':
        if (j.node != 'REVIEW') throw StateError('先核对本次结果');
        final value = b['value'];
        if (!const ['READY_NOW', 'FACTS_ONLY', 'DEFERRED', 'RECOVERY_HOLD']
            .contains(value)) throw ArgumentError('加工准备状态无效');
        final next = j.copy({
          'readiness': value,
          'review_reminder_ms':
              value == 'DEFERRED' ? growthInt(b['remind_at_ms']) : 0
        });
        await scheduleCheck(tx, next, 'journey_review',
            growthInt(next.data['review_reminder_ms']));
        return next;
      case 'review':
        if (j.node != 'REVIEW' || j.data['readiness'] != 'READY_NOW')
          throw StateError('你选择现在复盘时才会进入学习与改变');
        if (j.trialId.isNotEmpty) throw StateError('请继续已绑定行动的复盘');
        requireText(b, ['learning']);
        await nodeRun(tx, j, 'REVIEW', growthMap(j.data['outcome']),
            {'learning': b['learning'], 'source': 'USER_CONFIRMED'});
        return j.copy({'learning': b['learning'], 'node': 'CHANGE'});
      case 'change':
        if (j.node != 'CHANGE' || j.trialId.isNotEmpty)
          throw StateError('请完成本轮复盘后确认改变');
        requireText(b, ['reason']);
        if (!const ['KEEP', 'MODIFY', 'EXIT', 'RECOVER', 'NO_ACTION_YET']
            .contains(b['target'])) throw ArgumentError('改变选项无效');
        await nodeRun(tx, j, 'CHANGE', {'learning': j.data['learning']}, b);
        return checkpoint(
            tx,
            j.copy({
              if (b['target'] == 'EXIT')
                'routes': [
                  for (final r in growthRows(j.data['routes']))
                    {
                      ...r,
                      if (r['id'] == j.data['active_route']) 'status': 'CLOSED'
                    }
                ],
              'change': b,
              'belief': b['belief_after'] ?? j.data['belief']
            }));
      case 'criterion-evidence':
        requireText(b, ['facts']);
        return j.copy({
          'criteria_evidence': {
            'facts': b['facts'],
            'criterion_version': j.contract['version'],
            'met': b['met'] == true,
            'quality_met': b['quality_met'] == true,
            'source': 'USER_ATTESTATION',
            'at_ms': DateTime.now().millisecondsSinceEpoch
          }
        });
      case 'gate':
        if (j.node != j.gate) throw StateError('先完成改变与信念校准，再核验目标');
        final choice = b['choice'];
        if (choice == 'CLOSE' && '${b['reason'] ?? ''}'.trim().isEmpty)
          throw ArgumentError('请记录结束目标的依据');
        if (choice == 'PAUSE' || choice == 'CLOSE')
          return j.copy({'status': choice == 'PAUSE' ? 'PAUSED' : 'CLOSED'});
        if (choice == 'ACHIEVED') {
          final e = growthMap(j.data['criteria_evidence']);
          if (j.profile.lifecycle != 'FINITE' ||
              !j.confirmed ||
              e['criterion_version'] != j.contract['version'] ||
              e['met'] != true ||
              e['quality_met'] != true ||
              '${e['facts'] ?? ''}'.isEmpty) {
            throw StateError('达成需要有限目标、用户标准、真实证据和质量边界全部满足');
          }
          final dossier = await log(tx, j, 'ACHIEVEMENT_DOSSIER', {
            'contract': j.contract,
            'evidence': e,
            'plan': j.plan,
            'achieved_at_ms': DateTime.now().millisecondsSinceEpoch
          });
          return j.copy({'status': 'ACHIEVED', 'dossier_id': dossier});
        }
        if (choice != 'CONTINUE') throw ArgumentError('请选择与生命周期一致的核验结果');
        if (j.data['contract_revision_required'] == true)
          throw StateError('先确认修订后的目标合同');
        final target = growthMap(j.data['change'])['target'];
        if (target == 'RECOVER' || target == 'NO_ACTION_YET')
          return j.copy({'status': 'PAUSED'});
        return newCycle(tx, j);
      case 'plan':
        if (!j.confirmed || !j.node.endsWith('_GATE'))
          throw StateError('在本轮核验时修订计划，旧行动仍绑定原版本');
        requireText(b, ['reason', 'evidence', 'change', 'expected_signal']);
        if (!const ['KEEP', 'REMOVE', 'MODIFY', 'ADD'].contains(b['operation']))
          throw ArgumentError('请选择计划差异');
        final field = b['field'] ?? 'strategy';
        if (!const [
          'strategy',
          'cadence',
          'schedule',
          'resource_limit',
          'stop_rule',
          'selection_rule'
        ].contains(field)) throw ArgumentError('计划字段无效');
        final plan = {
          ...j.plan,
          'version': growthInt(j.plan['version']) + 1,
          'status': 'ACTIVE',
          'campaign_id': newId('campaign'),
          'plan_id': j.plan['plan_id'] ?? 'plan_${j.id}',
          'goal_version': j.contract['version'],
          'expected_signal': b['expected_signal'],
          'source_cycle': j.cycle,
          if (b['operation'] != 'KEEP')
            field: b['operation'] == 'REMOVE' ? '' : b['change']
        };
        await log(tx, j, 'PLAN_REVISION',
            {'before': j.plan, 'after': plan, 'diff': b});
        return j.copy({'plan': plan});
      case 'status':
        if (!const ['PAUSED', 'PARKED', 'ARCHIVED', 'ACTIVE']
            .contains(b['value'])) throw ArgumentError('目标状态无效');
        if (j.terminal) throw StateError('历史达成/归档只能通过重开进入新周期');
        return j.copy({'status': b['value']});
      case 'reopen':
        if (!j.terminal && j.status != 'MAINTAINING')
          throw StateError('只有已结束或保持中的目标需要重开');
        requireText(b, ['reason']);
        await log(tx, j, 'REOPEN', {
          'prior_dossier_id': j.data['dossier_id'],
          'reason': b['reason'],
          'prior_achievement_preserved': true
        });
        return newCycle(
            tx, j.copy({'criteria_evidence': {}, 'status': 'RECOVERY_CYCLE'}));
      case 'maintenance-contract':
        if (!const ['CONTINUOUS', 'RECURRING'].contains(j.profile.lifecycle))
          throw StateError('这是有限或探索目标');
        requireText(
            b, ['acceptable_band', 'ritual', 'drift_signals', 'recovery_rule']);
        final days = growthInt(b['check_days']);
        if (days < 1 || days > 365) throw ArgumentError('检查间隔为 1–365 天');
        return j.copy({
          'maintenance': {...b, 'check_days': days}
        });
      case 'maintenance-gate':
        if (j.gate != 'MAINTENANCE_GATE' ||
            (j.node != j.gate && j.status != 'MAINTAINING'))
          throw StateError('先完成本轮循环');
        if (growthMap(j.data['maintenance']).isEmpty)
          throw StateError('先定义保持区间与恢复规则');
        requireText(b, ['facts']);
        if (b['in_band'] == true) {
          final dossier = await log(tx, j, 'MAINTENANCE_DOSSIER',
              {'contract': j.data['maintenance'], 'evidence': b});
          final at = DateTime.now()
              .add(Duration(
                  days: growthInt(
                      growthMap(j.data['maintenance'])['check_days'], 7)))
              .millisecondsSinceEpoch;
          final next = j.copy({
            'status': 'MAINTAINING',
            'dossier_id': dossier,
            'check_at_ms': at
          });
          await scheduleCheck(tx, next, 'journey_maintenance', at);
          return next;
        }
        await log(tx, j, 'DRIFT_DETECTED',
            {'facts': b['facts'], 'prior_dossier_id': j.data['dossier_id']});
        return newCycle(
            tx, j.copy({'status': 'RECOVERY_CYCLE', 'current': b['facts']}));
      case 'candidate':
        if (j.profile.mode != 'EXPLORE') throw StateError('候选方向属于探索旅程');
        requireText(b, ['statement', 'evidence']);
        final candidates = growthRows(j.data['candidates']);
        candidates.add({
          'id': newId('candidate'),
          'statement': b['statement'],
          'evidence': b['evidence'],
          'positive': b['positive'] ?? '',
          'negative': b['negative'] ?? '',
          'unknowns': b['unknowns'] ?? '',
          'costs': b['costs'] ?? '',
          'source': b['source'] == 'AI_INFERENCE' ? 'AI_INFERENCE' : 'USER',
          'disposition': 'UNDECIDED'
        });
        return j.copy({'candidates': candidates});
      case 'candidate-disposition':
        final candidates = growthRows(j.data['candidates']);
        final index = candidates.indexWhere((c) => c['id'] == b['id']);
        if (index < 0) throw ArgumentError('候选方向不存在');
        if (!const ['TEST_MORE', 'PROMOTE', 'DROP', 'PARKED']
            .contains(b['value'])) throw ArgumentError('候选选择无效');
        final c = candidates[index];
        if (b['value'] == 'PROMOTE') {
          if (j.node != 'DISCOVERY_GATE' || b['confirmed'] != true)
            throw StateError('请完成采样循环并由你明确选择方向');
          if (c['promoted_journey_id'] == null) {
            final p = GrowthProblemProfile.resolve(c['statement']).data;
            var promoted = draft(
                newId(),
                c['statement'],
                GrowthProblemProfile({
                  ...p,
                  'goal_mode': 'SOLVE',
                  'intent_clarity': 'KNOWN_GOAL',
                  'lifecycle_type': 'FINITE'
                })).copy({'exploration_id': j.id, 'candidate_id': c['id']});
            // Direction is explicit; achievement criterion is still user-owned.
            await put(tx, promoted);
            await log(
                tx, promoted, 'PROMOTED_FROM_EXPLORATION', {'candidate': c});
            await log(tx, promoted, 'CYCLE', {'trigger': 'USER_PROMOTION'});
            c['promoted_journey_id'] = promoted.id;
          }
        }
        c['disposition'] = b['value'];
        return j.copy({'candidates': candidates});
      case 'allocation':
        for (final key in ['minutes', 'money', 'energy', 'risk', 'priority']) {
          final value = num.tryParse('${b[key] ?? 0}');
          if (value == null || !value.isFinite || value < 0)
            throw ArgumentError('资源不能是负数或无效数字');
        }
        if (growthInt(b['energy']) > 10 ||
            (b.containsKey('priority') &&
                ![1, 2, 3].contains(num.tryParse('${b['priority']}'))))
          throw ArgumentError('精力为 0–10，优先级为 1、2 或 3');
        return j.copy({'allocation': b});
      case 'mutuality':
        final state = b['value'];
        if (!const ['MUTUAL_READY', 'ACTIVE', 'PAUSED', 'WITHDRAWN', 'ENDED']
            .contains(state)) throw ArgumentError('共同意愿状态无效');
        if (state == 'MUTUAL_READY' &&
            (b['user_attested'] != true || '${b['facts'] ?? ''}'.isEmpty))
          throw StateError('只有实际确认当前双方自愿后才能继续');
        if (state == 'ACTIVE' && j.data['mutuality'] != 'MUTUAL_READY')
          throw StateError('先确认当下共同意愿');
        if (const ['WITHDRAWN', 'ENDED'].contains(j.data['mutuality']) &&
            state != 'MUTUAL_READY') throw StateError('退出后不能自动恢复');
        return j.copy({
          'mutuality': state,
          'event_phase': state == 'ACTIVE'
              ? 'IN_EVENT_QUIET'
              : state == 'ENDED'
                  ? 'POST_EVENT'
                  : j.data['event_phase']
        });
      case 'event':
        if (j.profile.scope != 'EPISODE') throw StateError('此目标不是一次事件');
        if (!const ['IN_EVENT_QUIET', 'POST_EVENT'].contains(b['phase']))
          throw ArgumentError('事件状态无效');
        if (b['phase'] == 'IN_EVENT_QUIET' &&
            j.profile.intimate &&
            j.data['mutuality'] != 'MUTUAL_READY') throw StateError('请先确认共同意愿');
        return j.copy({
          'event_phase': b['phase'],
          'event_end_ms': growthInt(b['end_ms']),
          if (j.profile.intimate)
            'mutuality': b['phase'] == 'IN_EVENT_QUIET' ? 'ACTIVE' : 'ENDED'
        });
      case 'participant':
        requireText(b, ['alias', 'role']);
        if (!const [
          'CO_OWNER',
          'CONTRIBUTOR',
          'APPROVER',
          'OBSERVER',
          'EXTERNAL_ACTOR'
        ].contains(b['role'])) throw ArgumentError('角色无效');
        if (b['task_assignment_allowed'] == true ||
            b['source'] == 'VERIFIED_JOIN')
          throw StateError(
              'CAPABILITY_OR_PERMISSION_GAP：当前没有第三方加入凭据，不能代其确认承诺或分配任务');
        return j.copy({
          'participants': [
            ...growthRows(j.data['participants']),
            {
              'id': newId('actor'),
              'alias': b['alias'],
              'role': b['role'],
              'participation_source': 'USER_REPORTED',
              'task_assignment_allowed': false,
              'status': 'REPORTED',
              'data_scope': 'MINIMAL_ALIAS',
              'can_withdraw': true
            }
          ]
        });
      case 'participant-withdraw':
        return j.copy({
          'participants': [
            for (final p in growthRows(j.data['participants']))
              if (p['id'] == b['id'])
                {
                  ...p,
                  'alias': '已退出参与者',
                  'status': 'WITHDRAWN',
                  'task_assignment_allowed': false
                }
              else
                p
          ],
          'mutuality': 'WITHDRAWN',
          'status': 'PAUSED'
        });
      case 'route':
        requireText(b, ['title']);
        final id = newId('route');
        return j.copy({
          'active_route': id,
          'routes': [
            ...growthRows(j.data['routes']),
            {'id': id, 'title': b['title'], 'status': 'ACTIVE'}
          ]
        });
      case 'close-route':
        requireText(b, ['id', 'reason']);
        return j.copy({
          'routes': [
            for (final r in growthRows(j.data['routes']))
              {...r, if (r['id'] == b['id']) 'status': 'CLOSED'}
          ]
        });
      case 'stage':
        if (growthMap(j.data['stage']).isNotEmpty)
          throw StateError('已有阶段，请凭现实证据推进阶段，保留旧阶段记录');
        requireText(b, ['title', 'entry_condition', 'exit_condition']);
        return j.copy({
          'stage': {...b, 'id': newId('stage'), 'status': 'ACTIVE'}
        });
      case 'stage-transition':
        if (growthMap(j.data['stage']).isEmpty || !j.node.endsWith('_GATE'))
          throw StateError('完成本轮学习后再核对阶段变化');
        requireText(b, ['facts', 'title', 'entry_condition', 'exit_condition']);
        if (b['confirmed'] != true) throw StateError('需要确认现实证据满足原阶段的退出条件');
        final previous = growthMap(j.data['stage']);
        await log(tx, j, 'STAGE_COMPLETED', {
          'stage': previous,
          'evidence': b['facts'],
          'source': 'USER_ATTESTATION',
          'goal_achieved': false
        });
        return j.copy({
          'stage': {
            'id': newId('stage'),
            'title': b['title'],
            'entry_condition': b['entry_condition'],
            'exit_condition': b['exit_condition'],
            'status': 'ACTIVE',
            'previous_stage_id': previous['id']
          }
        });
      case 'change-attempt':
        requireText(b, [
          'observed_pattern',
          'context',
          'impact',
          'desired_pattern',
          'intervention',
          'baseline',
          'signal'
        ]);
        final attempts = growthRows(j.data['change_attempts']);
        attempts.add({
          ...b,
          'id': newId('attempt'),
          'state': 'ATTEMPT',
          'observations': []
        });
        return j.copy({'change_attempts': attempts});
      case 'change-observation':
        requireText(b, ['id', 'facts']);
        final attempts = growthRows(j.data['change_attempts']);
        final at = attempts.indexWhere((a) => a['id'] == b['id']);
        if (at < 0) throw ArgumentError('改变尝试不存在');
        final a = attempts[at];
        final state = b['state'] ?? 'ADJUSTING';
        if (!const ['LAPSE', 'ADJUSTING', 'CONSOLIDATING', 'STABLE']
            .contains(state)) throw ArgumentError('改变状态无效');
        a['state'] = state;
        a['observations'] = [
          ...growthRows(a['observations']),
          {
            'facts': b['facts'],
            'state': state,
            'at_ms': DateTime.now().millisecondsSinceEpoch
          }
        ];
        return j.copy({'change_attempts': attempts});
      case 'metric':
        final m = GrowthProblemProfile.metric(
            j.profile, b['text'] ?? '', b['role'] ?? 'PREFERENCE',
            confirmed: b['confirmed'] == true,
            selfControlled: b['self_controlled'] == true);
        return j.copy({
          'profile': {
            ...j.profile.data,
            'metric_profile': [
              ...growthRows(j.profile.data['metric_profile']),
              m
            ]
          }
        });
      case 'shared-evidence':
        requireText(b, ['facts', 'type']);
        if (!const [
          'SELF_EXPERIENCE',
          'OBSERVED_BEHAVIOR',
          'EXPLICIT_PARTNER_FEEDBACK',
          'SHARED_CONFIRMED_FACT'
        ].contains(b['type'])) throw ArgumentError('证据类型无效');
        if (b['type'] == 'SHARED_CONFIRMED_FACT' &&
            b['mutually_confirmed'] != true) throw StateError('个人感受不能代替共同事实');
        return j.copy({
          'shared_evidence': [
            ...growthRows(j.data['shared_evidence']),
            {...b, 'source': 'USER_REPORTED', 'id': newId('se')}
          ]
        });
      default:
        throw ArgumentError('不支持的旅程操作：$op');
    }
  }

  static Future<GrowthJourney> checkpoint(
      DatabaseExecutor tx, GrowthJourney j) async {
    final campaign = campaignFor(j);
    await log(tx, j, 'CAMPAIGN_REVIEW', {
      'campaign': campaign,
      'learning': j.data['learning'],
      'change': j.data['change'],
      'plan': j.plan,
      'goal_achieved': false
    });
    j = j.copy({
      'campaign': {...campaign, 'status': 'REVIEWED'}
    });
    await nodeRun(
        tx,
        j,
        'BELIEF_CHECKPOINT',
        {'current': j.data['current'], 'change': j.data['change']},
        {'belief': j.data['belief']},
        mode: 'CHECKPOINT');
    final parentId = j.data['parent_id'];
    if (parentId is String) {
      final parent = await read(tx, parentId);
      if (parent != null) {
        final updated = parent.copy({'version': parent.version + 1});
        await put(tx, updated);
        await log(tx, updated, 'EPISODE_EVIDENCE', {
          'child_journey_id': j.id,
          'child_cycle': j.cycle,
          'facts':
              j.profile.sensitive ? '私密事件已完成本轮记录，可在原事件查看' : j.data['current'],
          'child_plan_version': j.plan['version'],
          'goal_achieved': false,
          'requires_parent_gate': true
        });
      }
    }
    return j.copy({'node': j.gate});
  }

  static GrowthData campaignFor(GrowthJourney j) {
    final c = growthMap(j.data['campaign']);
    if (c.isNotEmpty) return c;
    return {
      'id': 'campaign_${j.id}_${j.cycle}_${j.plan['version']}',
      'plan_id': j.plan['plan_id'] ?? 'plan_${j.id}',
      'plan_version': j.plan['version'],
      'goal_version': j.contract['version'],
      'cycle': j.cycle,
      'sample_target': 1,
      'deadline_ms': 0,
      'status': 'COLLECTING',
      'samples': <GrowthData>[]
    };
  }

  static Future<GrowthJourney> newCycle(
      DatabaseExecutor tx, GrowthJourney j) async {
    final next = j.copy({
      'cycle': j.cycle + 1,
      'previous_trial_id': j.trialId,
      'previous_plan_version': j.data['active_trial_plan_version'] ??
          growthMap(j.data['campaign'])['plan_version'] ??
          j.plan['version'],
      'active_trial_plan_version': null,
      'next_change': j.data['change'],
      'last_outcome': j.data['outcome'],
      'campaign': {},
      'trial_id': '',
      'node': 'ACTION',
      'readiness': 'UNKNOWN',
      'event_phase': 'PRE_EVENT',
      'status': j.status == 'RECOVERY_CYCLE' ? 'RECOVERY_CYCLE' : 'ACTIVE',
      'change': {},
      'outcome': {}
    });
    await log(tx, next, 'CYCLE', {'trigger': 'GATE', 'prior_cycle': j.cycle});
    await nodeRun(tx, next, 'BELIEF', {'prior_belief': j.data['belief']},
        {'belief': next.data['belief']},
        mode: 'INHERITED');
    await nodeRun(tx, next, 'GOAL', {'contract_version': j.contract['version']},
        next.contract,
        mode: 'INHERITED');
    return next;
  }

  static Future<void> onTrialEvent(
      DatabaseExecutor tx, String id, String type) async {
    if (type == 'NEXT_TRIAL_LINKED') return;
    final rows = await tx
        .query('evidence_growth_trials', where: 'trial_id=?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final t = RealityTrial.fromRow(rows.single);
    var maps = await tx.query('evidence_growth_journey_actions',
        where: 'trial_id=?', whereArgs: [id]);
    final jid = maps.isEmpty
        ? t.operatorInputs['journey_id']
        : maps.single['journey_id'] as String;
    if (jid == null || jid.isEmpty) return;
    var j = await read(tx, jid);
    if (j == null) throw StateError('父目标不存在');
    if (type == 'CREATED') {
      if (t.goalState.isNotEmpty && t.goalState != j.title)
        throw StateError('行动不能修改父目标；请先修订目标合同');
      if (j.version != int.tryParse(t.operatorInputs['journey_version'] ?? ''))
        throw StateError('目标已变化，请重新确认本轮');
      if (!j.confirmed || j.node != 'ACTION' || j.trialId.isNotEmpty)
        throw StateError('当前目标已有行动或尚未通过目标门');
      await assertExecutable(tx, j, t);
      await tx.insert('evidence_growth_journey_actions', {
        'trial_id': id,
        'journey_id': j.id,
        'cycle': j.cycle,
        'plan_version': growthInt(j.plan['version'])
      });
      await nodeRun(tx, j, 'ACTION', {
        'contract': j.contract,
        'plan': j.plan
      }, {
        'trial_id': id,
        'prediction': t.prediction,
        'schedule': t.operatorInputs['scheduled_start_ms'],
        'action': t.actionInstruction
      });
      final campaign = campaignFor(j);
      final provenance = {
        ...t.operatorInputs,
        'plan_id': '${campaign['plan_id']}',
        'plan_version': '${campaign['plan_version']}',
        'campaign_id': '${campaign['id']}',
        'goal_version': '${j.contract['version']}'
      };
      await tx.update('evidence_growth_trials',
          {'operator_inputs_json': jsonEncode(provenance)},
          where: 'trial_id=?', whereArgs: [id]);
      j = j.copy({
        'trial_id': id,
        'campaign': campaign,
        'active_trial_plan_version': j.plan['version']
      });
    } else {
      if (j.trialId != id) throw StateError('历史行动不能推进当前周期');
      if (type == 'STARTED' || type == 'START_RESCHEDULED') {
        await assertExecutable(tx, j, t);
        if (type == 'STARTED' && j.profile.scope == 'EPISODE')
          j = j.copy({
            'event_phase': 'IN_EVENT_QUIET',
            'event_end_ms': t.reviewAtMs,
            if (j.profile.intimate) 'mutuality': 'ACTIVE'
          });
      }
      if (type == 'RESULT_CAPTURED')
        j = j.copy({
          'node': 'OUTCOME',
          'event_phase': 'POST_EVENT',
          'current': t.actualOutcome,
          'pending_entry': '',
          'feedback_state': 'RECEIVED',
          'outcome': GrowthProblemProfile.outcome(t.actualOutcome)
        });
      if (type == 'REVIEWED') {
        if (j.node != 'REVIEW' || j.data['readiness'] != 'READY_NOW')
          throw StateError('先核对结果并选择现在复盘；暂缓期间不生成学习压力');
        await nodeRun(
            tx,
            j,
            'REVIEW',
            {'trial_id': id, 'facts': t.actualOutcome},
            {'learning_draft': t.learning, 'confirmed': false});
        j = j.copy({'node': 'CHANGE'});
      }
      if (type == 'DECIDED') {
        final confirmed = EvidenceGrowthCycle.confirmed(t);
        final change = {
          'target': t.decision == 'EXIT'
              ? 'EXIT'
              : t.decision == 'OBSERVE'
                  ? 'NO_ACTION_YET'
                  : confirmed['change_target'] == 'recovery'
                      ? 'RECOVER'
                      : t.decision == 'ACT'
                          ? 'KEEP'
                          : 'MODIFY',
          'reason': t.decisionReason,
          'next_action': t.nextAction,
          'trial_id': id
        };
        await nodeRun(tx, j, 'CHANGE', {'trial_id': id}, change);
        j = j.copy({
          'change': change,
          'learning': t.decisionReason,
          'belief': confirmed['belief_after'] ?? j.data['belief'],
          'contract_revision_required':
              (confirmed['next_goal'] ?? '').isNotEmpty &&
                  confirmed['next_goal'] != j.title
        });
        j = await checkpoint(tx, j);
        if (t.decision == 'OBSERVE')
          j = j.copy({'node': 'ACTION', 'readiness': 'UNKNOWN'});
        if (t.decision == 'EXIT') {
          j = j.copy({
            'routes': [
              for (final r in growthRows(j.data['routes']))
                {
                  ...r,
                  if (r['id'] == j.data['active_route']) 'status': 'CLOSED'
                }
            ]
          });
          await log(tx, j, 'ROUTE_CLOSED', {
            'trial_id': id,
            'reason': t.decisionReason,
            'parent_goal_closed': false
          });
        }
      }
    }
    j = j.copy({'version': j.version + 1});
    await put(tx, j);
    await cancelIneligible(tx, j);
  }

  static Future<void> assertExecutable(
      DatabaseExecutor tx, GrowthJourney j, RealityTrial trial) async {
    if (j.profile.blocked ||
        !const ['ACTIVE', 'ACTIVE_BUILD', 'RECOVERY_CYCLE']
            .contains(j.status) ||
        j.node != 'ACTION') throw StateError('父目标暂停、尚有缺口或当前不在行动节点');
    if (j.profile.intimate &&
        !const ['MUTUAL_READY', 'ACTIVE'].contains(j.data['mutuality']))
      throw StateError('必须先确认当前双方意愿；可随时暂停或退出');
    if (const ['PAUSED', 'WITHDRAWN', 'ENDED'].contains(j.data['mutuality']))
      throw StateError('当前事件已经暂停或退出');
    final campaign = campaignFor(j);
    if (growthRows(campaign['samples']).isNotEmpty &&
        growthInt(campaign['deadline_ms']) > 0 &&
        DateTime.now().millisecondsSinceEpoch >=
            growthInt(campaign['deadline_ms']))
      throw StateError('学习窗口已截止，请先汇总已有反馈再进入下一轮');
    final activeRoute = growthRows(j.data['routes'])
        .where((r) => r['id'] == j.data['active_route']);
    if (activeRoute.isNotEmpty && activeRoute.first['status'] == 'CLOSED')
      throw StateError('当前路线已经停止，请选择新的路线再行动');
    final portfolio = await portfolioData(tx);
    final dep = await evaluateDependencies(tx, j.id, portfolio);
    if (growthStrings(dep['blocked_by']).isNotEmpty)
      throw StateError('前置条件尚未满足，先等待或调整依赖');
    final resource = await arbitrate(tx, portfolio);
    if (growthStrings(resource['conflicts']).isNotEmpty)
      throw StateError(
          '资源冲突：${growthStrings(resource['conflicts']).join('；')}');
    final start = growthInt(trial.operatorInputs['scheduled_start_ms'],
        DateTime.now().millisecondsSinceEpoch);
    final duration = growthInt(trial.operatorInputs['duration_minutes'], 15);
    if (duration < 1 || duration > 1440) throw ArgumentError('行动预计时长无效');
    final end = start + duration * 60000;
    for (final slot in [
      ...growthRows(portfolio['protected_recovery']),
      ...growthRows(portfolio['hard_commitments'])
    ]) {
      if (start < growthInt(slot['end']) && end > growthInt(slot['start']))
        throw StateError('该时段已用于恢复或固定承诺，请换一个时间');
    }
    for (final row in await tx.rawQuery(
        "SELECT t.* FROM evidence_growth_trials t JOIN evidence_growth_journey_actions a ON a.trial_id=t.trial_id JOIN evidence_growth_journeys j ON j.id=a.journey_id WHERE t.status IN ('READY','IN_PROGRESS') AND j.status IN ('ACTIVE','ACTIVE_BUILD','RECOVERY_CYCLE') AND t.trial_id != ? AND a.journey_id != ?",
        [trial.id, j.id])) {
      final other = RealityTrial.fromRow(row);
      final os = growthInt(
          other.operatorInputs['scheduled_start_ms'], other.createdAtMs);
      final oe =
          os + growthInt(other.operatorInputs['duration_minutes'], 15) * 60000;
      if (start < oe && end > os) throw StateError('另一目标已占用此时段，请错开行动时间');
    }
  }

  static bool allowsReminder(GrowthJourney? j, {int? now}) {
    if (j == null) return true;
    if (!const ['ACTIVE', 'ACTIVE_BUILD', 'RECOVERY_CYCLE'].contains(j.status))
      return false;
    if (const ['FACTS_ONLY', 'DEFERRED', 'RECOVERY_HOLD']
        .contains(j.data['readiness'])) return false;
    if (const ['PAUSED', 'WITHDRAWN', 'ENDED'].contains(j.data['mutuality']))
      return false;
    if (j.data['event_phase'] == 'IN_EVENT_QUIET' &&
        (growthInt(j.data['event_end_ms']) == 0 ||
            growthInt(j.data['event_end_ms']) >
                (now ?? DateTime.now().millisecondsSinceEpoch))) return false;
    return j.node == 'ACTION';
  }

  static Future<void> cancelIneligible(
      DatabaseExecutor tx, GrowthJourney j) async {
    if (!allowsReminder(j))
      await tx.rawUpdate(
          "UPDATE evidence_growth_reminders SET state='cancelled',last_error='JOURNEY_HOLD' WHERE trial_id IN (SELECT trial_id FROM evidence_growth_journey_actions WHERE journey_id=?) AND state IN ('pending','scheduled','blocked')",
          [j.id]);
    if (j.status != 'MAINTAINING')
      await tx.rawUpdate(
          "UPDATE evidence_growth_reminders SET state='cancelled' WHERE trial_id=? AND kind='journey_maintenance' AND state IN ('pending','scheduled','blocked')",
          ['journey:${j.id}']);
    if (j.data['readiness'] != 'DEFERRED' || j.node != 'REVIEW')
      await tx.rawUpdate(
          "UPDATE evidence_growth_reminders SET state='cancelled' WHERE trial_id=? AND kind='journey_review' AND state IN ('pending','scheduled','blocked')",
          ['journey:${j.id}']);
  }

  static Future<void> scheduleCheck(
      DatabaseExecutor tx, GrowthJourney j, String kind, int at) async {
    final key = '${j.id}:$kind:$at';
    await tx.update('evidence_growth_reminders', {'state': 'cancelled'},
        where:
            "trial_id=? AND kind=? AND event_key!=? AND state IN ('pending','scheduled','blocked')",
        whereArgs: ['journey:${j.id}', kind, key]);
    if (at <= DateTime.now().millisecondsSinceEpoch) return;
    await tx.insert(
        'evidence_growth_reminders',
        {
          'event_key': key,
          'trial_id': 'journey:${j.id}',
          'kind': kind,
          'scheduled_at_ms': at,
          'window_key': '$kind:$at',
          'title': '你保存了一次检查',
          'body': '方便时可以回来看一看，也可以继续暂缓。',
          'source_ids_json': '[]',
          'state': 'pending'
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static GrowthData defaultPortfolio() => {
        'id': 'portfolio',
        'version': 1,
        'budgets': {
          'minutes': 120,
          'money': 0,
          'energy': 6,
          'risk': 0,
          'attention': 3
        },
        'protected_recovery': [],
        'hard_commitments': [],
        'edges': [],
        'external_conditions': {},
        'assets': []
      };
  static Future<GrowthData> portfolioData(DatabaseExecutor tx) async =>
      (await read(tx, 'portfolio'))?.data ?? defaultPortfolio();
  Future<GrowthData> portfolio() async => portfolioData(await db);
  Future<GrowthData> savePortfolio(int expected, GrowthData patch) async =>
      (await db).transaction((tx) async {
        if (patch.keys.any((k) => !const [
              'budgets',
              'protected_recovery',
              'hard_commitments',
              'external_conditions',
              'condition_labels'
            ].contains(k))) throw ArgumentError('关系与证据请通过专用操作修改，不能覆盖组合历史');
        final current = await portfolioData(tx);
        if (growthInt(current['version']) != expected)
          throw StateError('目标组合已变化，请刷新');
        final data = {
          ...current,
          ...patch,
          'id': 'portfolio',
          'version': expected + 1,
          'status': 'PORTFOLIO'
        };
        for (final v in growthMap(data['budgets']).values) {
          final n = num.tryParse('$v');
          if (n == null || !n.isFinite || n < 0)
            throw ArgumentError('预算需要非负有限数字');
        }
        for (final s in [
          ...growthRows(data['protected_recovery']),
          ...growthRows(data['hard_commitments'])
        ]) {
          if (growthInt(s['start']) >= growthInt(s['end']))
            throw ArgumentError('时段结束必须晚于开始');
        }
        await put(tx, GrowthJourney(data));
        await log(tx, GrowthJourney(data), 'PORTFOLIO', patch);
        return data;
      });
  static Future<GrowthData> arbitrate(DatabaseExecutor tx, GrowthData p) async {
    final rows = await tx.query('evidence_growth_journeys',
        where: "status IN ('ACTIVE','ACTIVE_BUILD','RECOVERY_CYCLE')");
    final active = rows
        .map((r) =>
            GrowthJourney(growthMap(jsonDecode(r['body_json'] as String))))
        .toList();
    final totals = <String, num>{
      for (final k in ['minutes', 'money', 'energy', 'risk']) k: 0
    };
    for (final j in active)
      for (final k in totals.keys)
        totals[k] = totals[k]! +
            (num.tryParse('${growthMap(j.data['allocation'])[k] ?? 0}') ?? 0);
    final budgets = growthMap(p['budgets']);
    final conflicts = <String>[];
    const names = {
      'minutes': '时间',
      'money': '资金',
      'energy': '精力',
      'risk': '风险'
    };
    for (final k in totals.keys)
      if (totals[k]! > (num.tryParse('${budgets[k]}') ?? 0))
        conflicts.add('${names[k]}超过组合预算');
    if (active
            .where((j) =>
                growthInt(growthMap(j.data['allocation'])['priority'], 2) == 1)
            .length >
        growthInt(budgets['attention'], 3)) conflicts.add('当前高优先目标过多，请暂存部分目标');
    if (totals['energy']! >= 6 &&
        !growthRows(p['protected_recovery']).any(
            (s) => growthInt(s['end']) > DateTime.now().millisecondsSinceEpoch))
      conflicts.add('高负荷安排需要保留恢复时段');
    for (final edge in growthRows(p['edges'])) {
      if (edge['type'] == 'CONFLICTS_WITH' &&
          active.any((j) => j.id == edge['from']) &&
          active.any((j) => j.id == edge['to']))
        conflicts.add('两个当前目标存在明确冲突，请暂存一个');
    }
    return {
      'decision': conflicts.isEmpty ? 'PARALLEL_OK' : 'REBALANCE',
      'totals': totals,
      'conflicts': conflicts,
      'choices': ['FOCUS', 'DEFER', 'REDUCE_SCOPE', 'PROTECT_RECOVERY'],
      'focus': (active
            ..sort((a, b) => growthInt(
                    growthMap(a.data['allocation'])['priority'], 2)
                .compareTo(
                    growthInt(growthMap(b.data['allocation'])['priority'], 2))))
          .take(3)
          .map((j) => {'id': j.id, 'title': j.safeTitle})
          .toList()
    };
  }

  Future<GrowthData> arbitration() async {
    final tx = await db;
    return arbitrate(tx, await portfolioData(tx));
  }

  Future<void> addDependency(String from, String to, String type,
      {String evidence = ''}) async {
    if (from == to ||
        !const [
          'REQUIRES',
          'BLOCKS',
          'ENABLES',
          'CONFLICTS_WITH',
          'SHARES_RESOURCE_WITH',
          'ALTERNATIVE_TO',
          'CONTRIBUTES_TO'
        ].contains(type)) throw ArgumentError('依赖关系无效');
    await (await db).transaction((tx) async {
      final p = await portfolioData(tx);
      final edges = growthRows(p['edges']);
      if (edges
          .any((e) => e['from'] == from && e['to'] == to && e['type'] == type))
        return;
      final refs = [from, to];
      for (final ref in refs) {
        if (!ref.startsWith('external:') && await read(tx, ref) == null)
          throw StateError('关联目标不存在');
      }
      final candidate = {
        'from': from,
        'to': to,
        'type': type,
        'evidence': evidence
      };
      edges.add(candidate);
      // REQUIRES: from waits for to. BLOCKS: from prevents to. Normalize to wait edges.
      final graph = <String, List<String>>{};
      for (final e in edges
          .where((e) => const ['REQUIRES', 'BLOCKS'].contains(e['type']))) {
        final a = (e['type'] == 'REQUIRES' ? e['from'] : e['to']) as String;
        final b = (e['type'] == 'REQUIRES' ? e['to'] : e['from']) as String;
        (graph[a] ??= []).add(b);
      }
      bool cycle(String node, Set<String> path) {
        if (path.contains(node)) return true;
        return (graph[node] ?? []).any((next) => cycle(next, {...path, node}));
      }

      if (graph.keys.any((n) => cycle(n, {})))
        throw StateError('依赖形成循环，请调整前置关系');
      final updated = GrowthJourney({
        ...p,
        'edges': edges,
        'status': 'PORTFOLIO',
        'version': growthInt(p['version']) + 1
      });
      await put(tx, updated);
      await log(tx, updated, 'DEPENDENCY', candidate);
    });
  }

  Future<void> removeDependency(String from, String to, String type) async {
    await (await db).transaction((tx) async {
      final p = await portfolioData(tx);
      final edges = growthRows(p['edges']);
      final removed = edges
          .where((e) => e['from'] == from && e['to'] == to && e['type'] == type)
          .toList();
      if (removed.isEmpty) throw StateError('关系已变化，请刷新');
      edges.removeWhere(
          (e) => e['from'] == from && e['to'] == to && e['type'] == type);
      final updated = GrowthJourney(
          {...p, 'edges': edges, 'version': growthInt(p['version']) + 1});
      await put(tx, updated);
      await log(tx, updated, 'DEPENDENCY_REMOVED', removed.single);
    });
  }

  static Future<GrowthData> evaluateDependencies(
      DatabaseExecutor tx, String id, GrowthData p) async {
    final blocked = <String>[],
        enabled = <String>[],
        relations = <GrowthData>[];
    Future<bool> satisfied(String ref) async {
      if (ref.startsWith('external:'))
        return growthMap(p['external_conditions'])[ref] == true;
      final j = await read(tx, ref);
      return j != null && const ['ACHIEVED', 'MAINTAINING'].contains(j.status);
    }

    for (final e in growthRows(p['edges'])) {
      if (e['from'] != id && e['to'] != id) continue;
      relations.add(e);
      if (e['type'] == 'REQUIRES' &&
          e['from'] == id &&
          !await satisfied(e['to'])) blocked.add(e['to']);
      if (e['type'] == 'BLOCKS' && e['to'] == id && !await satisfied(e['from']))
        blocked.add(e['from']);
      if (e['type'] == 'ENABLES' && e['to'] == id && await satisfied(e['from']))
        enabled.add(e['from']);
    }
    return {
      'blocked_by': blocked,
      'enabled_by': enabled,
      'relations': relations,
      'status': blocked.isEmpty ? 'ENABLED' : 'BLOCKED'
    };
  }

  Future<GrowthData> dependencies(String id) async {
    final tx = await db;
    return evaluateDependencies(tx, id, await portfolioData(tx));
  }

  Future<void> shareAsset(
      GrowthJourney source, String target, String rule, String evidence,
      {String transferFacts = ''}) async {
    if (rule.trim().isEmpty || evidence.trim().isEmpty)
      throw ArgumentError('需要自己的规则与来源证据');
    await (await db).transaction((tx) async {
      final from = await read(tx, source.id), to = await read(tx, target);
      if (from == null ||
          from.version != source.version ||
          to == null ||
          to.id == from.id) throw StateError('目标已变化或迁移对象无效');
      if (source.profile.sensitive)
        throw StateError('私密目标只在原目标内保留证据，避免跨目标暴露第三方信息');
      final record = {
        'id': newId('asset'),
        'source_id': source.id,
        'target_id': target,
        'rule': rule,
        'source_evidence': evidence,
        'transfer_facts': transferFacts,
        'status': transferFacts.isEmpty ? 'PROPOSED' : 'OBSERVED_IN_TARGET',
        'personal_evidence': transferFacts.isNotEmpty
      };
      await log(tx, from, 'SHARED_ASSET', record);
      await log(tx, to, 'ASSET_TRANSFER', record);
      await put(tx, from.copy({'version': from.version + 1}));
      await put(tx, to.copy({'version': to.version + 1}));
    });
  }

  Future<GrowthData> bundle(String id) async {
    final tx = await db;
    final j = await read(tx, id);
    if (j == null) return {};
    return {
      'journey': j.data,
      'records': await tx.query('evidence_growth_journal',
          where: 'journey_id=?', whereArgs: [id], orderBy: 'created_at_ms,id'),
      'actions': await tx.query('evidence_growth_journey_actions',
          where: 'journey_id=?', whereArgs: [id], orderBy: 'trial_id')
    };
  }

  Future<List<String>> ids() async =>
      (await (await db).query('evidence_growth_journeys', columns: ['id']))
          .map((r) => r['id'] as String)
          .toList();
  Future<String> importBundle(GrowthData bundle,
      {required String baseDigest}) async {
    final data = growthMap(bundle['journey']);
    final id = data['id'];
    if (id is! String || !RegExp(r'^[a-zA-Z0-9_-]{1,180}$').hasMatch(id))
      throw ArgumentError('目标编号无效');
    final local = await this.bundle(id);
    final localDigest =
        local.isEmpty ? '' : EvidenceGrowthDao.bundleDigest(local);
    if (localDigest != baseDigest) throw StateError('旅程同步冲突');
    final records = growthRows(bundle['records']),
        actions = growthRows(bundle['actions']);
    if (records.any((r) => r['journey_id'] != id) ||
        actions.any((a) => a['journey_id'] != id))
      throw ArgumentError('跨目标写入被拒绝');
    if (id != 'portfolio' &&
        GrowthProblemProfile(growthMap(data['profile'])).checked().blocked &&
        data['status'] == 'ACHIEVED') throw StateError('无效达成状态');
    if (data['status'] == 'ACHIEVED') {
      final j = GrowthJourney(data), e = growthMap(data['criteria_evidence']);
      if (j.profile.lifecycle != 'FINITE' ||
          e['met'] != true ||
          e['quality_met'] != true ||
          e['criterion_version'] != j.contract['version'] ||
          !records.any((r) =>
              r['id'] == data['dossier_id'] &&
              r['kind'] == 'ACHIEVEMENT_DOSSIER'))
        throw StateError('同步达成缺少目标门证据');
    }
    return (await db).transaction((tx) async {
      final current = await read(tx, id);
      final currentBundle = current == null
          ? <String, dynamic>{}
          : {
              'journey': current.data,
              'records': await tx.query('evidence_growth_journal',
                  where: 'journey_id=?',
                  whereArgs: [id],
                  orderBy: 'created_at_ms,id'),
              'actions': await tx.query('evidence_growth_journey_actions',
                  where: 'journey_id=?', whereArgs: [id], orderBy: 'trial_id')
            };
      if ((currentBundle.isEmpty
              ? ''
              : EvidenceGrowthDao.bundleDigest(currentBundle)) !=
          baseDigest) throw StateError('记录已变化');
      for (final r in records) {
        final old = await tx.query('evidence_growth_journal',
            where: 'id=?', whereArgs: [r['id']]);
        if (old.isNotEmpty &&
            EvidenceGrowthDao.bundleDigest(growthMap(old.single)) !=
                EvidenceGrowthDao.bundleDigest(r)) throw StateError('禁止改写历史证据');
        if (old.isEmpty) await tx.insert('evidence_growth_journal', r);
      }
      // Omitted immutable history cannot be silently erased by a stale peer.
      final oldIds =
          growthRows(currentBundle['records']).map((r) => r['id']).toSet();
      if (!records.map((r) => r['id']).toSet().containsAll(oldIds))
        throw StateError('同步缺少已有历史，需要比较冲突');
      for (final a in actions) {
        final old = await tx.query('evidence_growth_journey_actions',
            where: 'trial_id=?', whereArgs: [a['trial_id']]);
        if (old.isNotEmpty &&
            EvidenceGrowthDao.bundleDigest(growthMap(old.single)) !=
                EvidenceGrowthDao.bundleDigest(a))
          throw StateError('行动所属目标与计划版本不可改写');
        if (old.isEmpty) await tx.insert('evidence_growth_journey_actions', a);
      }
      await put(tx, GrowthJourney(data));
      await cancelIneligible(tx, GrowthJourney(data));
      if (data['status'] == 'MAINTAINING')
        await scheduleCheck(tx, GrowthJourney(data), 'journey_maintenance',
            growthInt(data['check_at_ms']));
      if (data['readiness'] == 'DEFERRED')
        await scheduleCheck(tx, GrowthJourney(data), 'journey_review',
            growthInt(data['review_reminder_ms']));
      return EvidenceGrowthDao.bundleDigest(bundle);
    });
  }
}
