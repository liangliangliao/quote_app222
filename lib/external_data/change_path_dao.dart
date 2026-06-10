import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'change_path_models.dart';
import 'todo_goal_dao.dart';

class ChangePathDao {
  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db);
    return db;
  }

  Future<void> ensureTables([Database? database]) async {
    final db = database ?? await AppDatabase.instance();
    await TodoGoalDao().ensureTables(db);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS change_action_cards (
        card_id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        step_id TEXT,
        source_task_id TEXT,
        source_list_id TEXT,
        change_goal TEXT,
        old_pattern TEXT,
        preserved_value TEXT,
        resistance_type TEXT,
        action_text TEXT NOT NULL,
        difficulty INTEGER DEFAULT 5,
        zone_type TEXT DEFAULT 'stretch',
        completion_standard TEXT,
        failure_plan TEXT,
        action_meaning TEXT,
        review_question TEXT,
        status TEXT DEFAULT 'ready',
        started_at_ms INTEGER DEFAULT 0,
        completed_at_ms INTEGER DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_change_cards_goal ON change_action_cards(goal_id, created_at_ms DESC)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS change_self_evidence (
        evidence_id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        card_id TEXT,
        evidence_date TEXT NOT NULL,
        old_belief TEXT,
        action_text TEXT,
        difficulty INTEGER DEFAULT 5,
        prediction_text TEXT,
        actual_result TEXT,
        hardest_part TEXT,
        new_evidence TEXT,
        new_belief TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_change_evidence_goal ON change_self_evidence(goal_id, created_at_ms DESC)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS change_abc_journals (
        journal_id TEXT PRIMARY KEY,
        goal_id TEXT,
        journal_date TEXT NOT NULL,
        emotion TEXT,
        emotion_intensity INTEGER DEFAULT 5,
        body_signal TEXT,
        action_taken TEXT,
        avoidance TEXT,
        stretch_action TEXT,
        old_interpretation TEXT,
        freedom_check TEXT,
        new_interpretation TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS change_behavior_experiments (
        experiment_id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        old_belief TEXT,
        experiment_action TEXT,
        predicted_result TEXT,
        actual_result TEXT,
        conclusion TEXT,
        new_belief TEXT,
        status TEXT DEFAULT 'planned',
        created_at_ms INTEGER NOT NULL,
        completed_at_ms INTEGER DEFAULT 0
      )
    ''');
  }

  Future<ChangePathActionCard> saveActionCard(ChangePathActionCard card) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = card.cardId.trim().isEmpty ? _id('change_card') : card.cardId;
    await db.insert('change_action_cards', <String, Object?>{
      'card_id': id,
      'goal_id': card.goalId,
      'step_id': card.stepId,
      'source_task_id': card.sourceTaskId,
      'source_list_id': card.sourceListId,
      'change_goal': card.changeGoal,
      'old_pattern': card.oldPattern,
      'preserved_value': card.preservedValue,
      'resistance_type': card.resistanceType,
      'action_text': card.action,
      'difficulty': card.difficulty,
      'zone_type': card.zone,
      'completion_standard': card.completionStandard,
      'failure_plan': card.failurePlan,
      'action_meaning': card.actionMeaning,
      'review_question': card.reviewQuestion,
      'status': card.status,
      'started_at_ms': card.startedAtMs,
      'completed_at_ms': card.completedAtMs,
      'created_at_ms': card.createdAtMs == 0 ? now : card.createdAtMs,
      'updated_at_ms': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final rows = await db.query('change_action_cards', where: 'card_id = ?', whereArgs: [id], limit: 1);
    return ChangePathActionCard.fromMap(rows.first);
  }

  Future<List<ChangePathActionCard>> listActionCards({int limit = 100}) async {
    final db = await _db;
    final rows = await db.query('change_action_cards', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(ChangePathActionCard.fromMap).toList();
  }

  Future<void> startAction(String cardId) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update('change_action_cards', {'status': 'started', 'started_at_ms': now, 'updated_at_ms': now}, where: 'card_id = ?', whereArgs: [cardId]);
  }

  Future<void> completeAction(String cardId) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update('change_action_cards', {'status': 'completed', 'completed_at_ms': now, 'updated_at_ms': now}, where: 'card_id = ?', whereArgs: [cardId]);
  }

  Future<ChangePathEvidence> addEvidence({
    required ChangePathActionCard card,
    required String oldBelief,
    required String prediction,
    required String actualResult,
    required String hardestPart,
    required String evidence,
    required String newBelief,
  }) async {
    final db = await _db;
    final now = DateTime.now();
    final id = _id('change_evidence');
    await db.insert('change_self_evidence', {
      'evidence_id': id,
      'goal_id': card.goalId,
      'card_id': card.cardId,
      'evidence_date': _date(now),
      'old_belief': oldBelief,
      'action_text': card.action,
      'difficulty': card.difficulty,
      'prediction_text': prediction,
      'actual_result': actualResult,
      'hardest_part': hardestPart,
      'new_evidence': evidence,
      'new_belief': newBelief,
      'created_at_ms': now.millisecondsSinceEpoch,
    });
    await completeAction(card.cardId);
    final rows = await db.query('change_self_evidence', where: 'evidence_id = ?', whereArgs: [id], limit: 1);
    return ChangePathEvidence.fromMap(rows.first);
  }

  Future<List<ChangePathEvidence>> listEvidence({int limit = 200}) async {
    final db = await _db;
    final rows = await db.query('change_self_evidence', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(ChangePathEvidence.fromMap).toList();
  }

  Future<void> addJournal({
    required String goalId,
    required String emotion,
    required int intensity,
    required String bodySignal,
    required String actionTaken,
    required String avoidance,
    required String stretchAction,
    required String oldInterpretation,
    required String freedomCheck,
    required String newInterpretation,
  }) async {
    final db = await _db;
    final now = DateTime.now();
    await db.insert('change_abc_journals', {
      'journal_id': _id('change_abc'),
      'goal_id': goalId,
      'journal_date': _date(now),
      'emotion': emotion,
      'emotion_intensity': intensity.clamp(1, 10),
      'body_signal': bodySignal,
      'action_taken': actionTaken,
      'avoidance': avoidance,
      'stretch_action': stretchAction,
      'old_interpretation': oldInterpretation,
      'freedom_check': freedomCheck,
      'new_interpretation': newInterpretation,
      'created_at_ms': now.millisecondsSinceEpoch,
    });
  }

  Future<List<ChangePathAbcJournal>> listJournals({int limit = 100}) async {
    final db = await _db;
    final rows = await db.query('change_abc_journals', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(ChangePathAbcJournal.fromMap).toList();
  }

  Future<void> saveExperiment({required String goalId, required String oldBelief, required String action, required String prediction}) async {
    final db = await _db;
    await db.insert('change_behavior_experiments', {
      'experiment_id': _id('change_experiment'),
      'goal_id': goalId,
      'old_belief': oldBelief,
      'experiment_action': action,
      'predicted_result': prediction,
      'actual_result': '',
      'conclusion': '',
      'new_belief': '',
      'status': 'planned',
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      'completed_at_ms': 0,
    });
  }

  String _id(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  String _date(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
