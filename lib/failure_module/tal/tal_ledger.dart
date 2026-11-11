import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../beautiful_enemy/src/domain/guard.dart' show SafetyValve;
import '../fp_dao.dart';
import 'tal_models.dart';
import 'tal_catalog.dart';

class TalCrisisException implements Exception {
  const TalCrisisException();
}

class TalReminderBudget {
  const TalReminderBudget(this.used, this.ignoredRecently,
      {this.quotedRecently = false});
  final int used;
  final bool ignoredRecently;
  final bool quotedRecently;
}

/// An adapter over fp_learning_card, not a second history database. Events,
/// revisions, single-intervention trials and their evidence share one row.
class TalLessonLedger {
  TalLessonLedger({FpDao? dao, DateTime Function()? clock, this.canWrite})
      : dao = dao ?? FpDao(),
        clock = clock ?? DateTime.now;
  final FpDao dao;
  final DateTime Function() clock;
  final bool Function()? canWrite;
  int get nowMs => clock().millisecondsSinceEpoch;
  void _requireWriting() {
    if (canWrite != null && !canWrite!()) throw StateError('本次会话已关闭。');
  }

  void _safe(Iterable<String> texts) {
    if (texts.any(SafetyValve.isCrisis)) throw const TalCrisisException();
    if (texts.any((s) => s.length > 10000)) {
      throw const FormatException('单项请控制在 10000 字以内。');
    }
  }

  Future<Database> _ready() async {
    await dao.ensureTables();
    return dao.database();
  }

  TalRecord _read(Map<String, Object?> row) => TalRecord.fromJson(
      jsonDecode(row['tal_data_json'] as String) as Map<String, dynamic>,
      cardId: (row['id'] as num).toInt());

  Future<TalRecord?> get(String eventId) async {
    final db = await _ready();
    final rows = await db.query('fp_learning_card',
        where: 'tal_event_id = ?', whereArgs: [eventId], limit: 1);
    return rows.isEmpty ? null : _read(rows.first);
  }

  Map<String, Object?> _row(TalRecord r) => {
        'ts_ms': r.createdMs,
        'title': r.plan.trim().isEmpty ? '一次经历 · ${r.state.label}' : r.plan,
        'body': '原计划：${r.plan}\n实际：${r.observed}\n'
            '目前的认识：${r.lesson.isEmpty ? '还不清楚' : r.lesson}\n'
            '${r.level} · ${r.state.label}'
            '${r.currentTrial == null ? '' : '\n下次：${r.currentTrial!.action}'}',
        'tags_json': jsonEncode(['失败学习', 'Tal', r.state.code, 'App整合设计']),
        'tal_event_id': r.eventId,
        'tal_subject_key': r.subjectKey,
        'tal_state': r.state.code,
        'tal_data_json': jsonEncode(r.toJson()),
      };

  Future<TalRecord?> captureConfirmedMissed(
      {required String eventId,
      required String subjectKey,
      required String plan,
      required String observed,
      required String status,
      required bool userConfirmed,
      required String source}) async {
    if (!userConfirmed ||
        status != 'missed' ||
        source == 'kindling' ||
        source == 'kindling_aborted') return null;
    return captureManualEvent(
        eventId: eventId,
        subjectKey: subjectKey,
        plan: plan,
        observed: observed,
        source: source,
        confirmed: true);
  }

  Future<TalRecord> captureManualEvent(
      {required String eventId,
      String subjectKey = '',
      String plan = '',
      String observed = '',
      String source = 'manual',
      bool confirmed = false}) async {
    if (eventId.trim().isEmpty || eventId.length > 400) {
      throw const FormatException('事件标识无效。');
    }
    if (source.startsWith('kindling')) {
      throw const FormatException('火种退出不创建失败事件。');
    }
    _safe([plan, observed]);
    final db = await _ready();
    return db.transaction((txn) async {
      _requireWriting();
      final prior = await txn.query('fp_learning_card',
          where: 'tal_event_id = ?', whereArgs: [eventId], limit: 1);
      if (prior.isNotEmpty) return _read(prior.first);
      final r = TalRecord(
          eventId: eventId,
          createdMs: nowMs,
          updatedMs: nowMs,
          source: source,
          subjectKey: subjectKey,
          plan: plan,
          observed: observed,
          confirmed: confirmed);
      final id = await txn.insert('fp_learning_card', _row(r));
      _requireWriting();
      return TalRecord.fromJson(r.toJson(), cardId: id);
    });
  }

  Future<TalRecord> _change(
      String eventId, TalRecord Function(TalRecord) change) async {
    final db = await _ready();
    return db.transaction((txn) async {
      _requireWriting();
      final rows = await txn.query('fp_learning_card',
          where: 'tal_event_id = ?', whereArgs: [eventId], limit: 1);
      if (rows.isEmpty) throw StateError('记录已删除，请重新开始。');
      final old = _read(rows.first);
      final r = change(old).withJson({'updated_ms': nowMs});
      await txn.update('fp_learning_card', _row(r),
          where: 'id = ?', whereArgs: [r.cardId]);
      _requireWriting();
      return r;
    });
  }

  List<Map<String, dynamic>> _revisions(TalRecord old, String statement) => [
        ...old.revisions,
        if (statement != old.lesson)
          {
            'version': old.revisions.length + 1,
            'statement': statement,
            'previous_statement': old.lesson,
            'created_ms': nowMs,
            'source_provenance': 'product_extension',
            'evidence_ids': old.trials
                .expand((t) => t.evidence)
                .map((e) => e['id'])
                .toList(),
          },
      ];

  Future<TalRecord> saveDraft(String eventId,
      {required String plan,
      required String observed,
      required Map<String, String> reflection,
      required TalChoice choice,
      bool aiConsent = false,
      bool reminderConsent = false}) {
    _safe([plan, observed, ...reflection.values]);
    return _change(eventId, (old) {
      final changedLesson = (reflection['lessons'] ?? '') != old.lesson;
      final state = switch (choice) {
        TalChoice.exit => TalState.goalExited,
        TalChoice.pause => TalState.paused,
        _ => old.trials.isNotEmpty
            ? old.currentTrial!.state
            : (reflection['lessons'] ?? '').trim().isNotEmpty &&
                    !['还不清楚', '没有教训', '暂时没有']
                        .contains(reflection['lessons']!.trim())
                ? TalState.insightCandidate
                : reflection.values.any((s) => s.trim().isNotEmpty)
                    ? TalState.reflectionDraft
                    : TalState.eventRecorded,
      };
      return old.withJson({
        'plan': plan,
        'observed': observed,
        'reflection': reflection,
        'choice': choice.name,
        'state': state.code,
        'revisions': _revisions(old, reflection['lessons'] ?? ''),
        'ai_consent': aiConsent,
        'reminder_consent': reminderConsent &&
            choice != TalChoice.pause &&
            choice != TalChoice.exit,
        if (changedLesson) 'validated_by_user': false,
        if (changedLesson) 'consolidated_by_user': false,
        if (changedLesson) 'quote_consent': false,
      });
    });
  }

  Future<TalRecord> rejectMethod(String eventId, String methodId) => _change(
      eventId,
      (r) => r.withJson({
            'rejected_methods': {...r.rejectedMethods, methodId}.toList(),
          }));

  Future<TalRecord> recordTrial(String eventId,
      {required String methodId,
      required String action,
      required String trigger,
      required String check,
      String reason = ''}) {
    _safe([action, trigger, check, reason]);
    if (methodId != 'personal_trial' &&
        !TalCatalog.approvedMethodIds.contains(methodId)) {
      throw const FormatException('请选择库内方法，或记录自己的个人试验。');
    }
    if ([methodId, action, trigger, check].any((s) => s.trim().isEmpty)) {
      throw const FormatException('行动计划需要具体动作、时机和检查方式；也可以只保存草稿。');
    }
    return _change(eventId, (old) {
      if (![TalChoice.continueGoal, TalChoice.adjust].contains(old.choice)) {
        throw StateError('先由你决定继续或调整，也可以暂不行动。');
      }
      // Repeated submission of the same unfinished plan is idempotent.
      final prev = old.currentTrial;
      if (prev != null &&
          prev.evidence.isEmpty &&
          prev.methodId == methodId &&
          prev.action == action &&
          prev.trigger == trigger &&
          prev.check == check) return old;
      final trial = TalTrial(
          id: '${old.eventId}:trial:${old.trials.length + 1}',
          methodId: methodId,
          action: action,
          trigger: trigger,
          check: check,
          reason: reason,
          createdMs: nowMs,
          previousId: prev?.id);
      return old.withJson({
        'trials': [...old.trials.map((t) => t.toJson()), trial.toJson()],
        'state':
            (prev == null ? TalState.actionPlanned : TalState.nextTrial).code,
      });
    });
  }

  Future<TalRecord> appendOutcome(String eventId,
      {required String trialId,
      required String evidenceId,
      required bool? actionDone,
      required String outcome,
      required String observation,
      String context = '',
      List<String> evidenceRefs = const []}) {
    _safe([observation, context, ...evidenceRefs]);
    if (!['helped', 'not_helped', 'unclear', 'pending'].contains(outcome) ||
        evidenceId.isEmpty ||
        (outcome == 'helped' &&
            (actionDone != true || observation.trim().isEmpty))) {
      throw const FormatException('有帮助需要已执行的行动与实际结果；效果未知可以如实记录。');
    }
    return _change(eventId, (old) {
      if (old.trials
          .expand((t) => t.evidence)
          .any((e) => e['id'] == evidenceId)) return old;
      if (!old.trials.any((t) => t.id == trialId)) throw StateError('找不到这次行动。');
      final trials = old.trials
          .map((t) => t.id != trialId
              ? t
              : TalTrial.fromJson({
                  ...t.toJson(),
                  'evidence': [
                    ...t.evidence,
                    {
                      'id': evidenceId,
                      'observed_ms': nowMs,
                      'action_done': actionDone,
                      'outcome': actionDone == true ? outcome : 'unclear',
                      'observed_outcome': observation,
                      'context': context,
                      'evidence_refs': evidenceRefs,
                      'source': 'user_report',
                    },
                  ]
                }))
          .toList();
      final state =
          old.state == TalState.goalExited || old.state == TalState.paused
              ? old.state
              : trials.last.state;
      return old.withJson({
        'trials': trials.map((t) => t.toJson()).toList(),
        'state': state.code
      });
    });
  }

  Future<TalRecord> reviseLesson(String eventId, String statement) {
    _safe([statement]);
    return _change(
        eventId,
        (old) => old.withJson({
              'reflection': {...old.reflection, 'lessons': statement},
              'revisions': _revisions(old, statement),
              'validated_by_user': false,
              'consolidated_by_user': false,
              'quote_consent': false,
              'state': TalState.lessonRevised.code,
            }));
  }

  Future<TalRecord> validateLesson(String eventId,
          {bool consolidated = false}) =>
      _change(eventId, (r) {
        if (!r.hasLesson ||
            !r.trials.expand((t) => t.evidence).any((e) =>
                e['action_done'] == true &&
                e['outcome'] == 'helped' &&
                '${e['observed_outcome']}'.trim().isNotEmpty)) {
          throw StateError('先记录一次相关行动的真实改善证据，才能确认这条认识有效。');
        }
        final next = r.withJson(
            {'validated_by_user': true, 'consolidated_by_user': consolidated});
        if (consolidated && !next.level.startsWith('L5')) {
          throw StateError('巩固需要至少三天、两个情境的改善证据。');
        }
        return next;
      });

  Future<TalRecord> revokeAi(String eventId) =>
      _change(eventId, (r) => r.withJson({'ai_consent': false}));

  Future<TalRecord> setPersonalReminder(String eventId, String text,
      {required bool approved}) {
    _safe([text]);
    if (approved && (text.trim().isEmpty || text.runes.length > 120)) {
      throw const FormatException('个人提醒写成一句不超过 120 字的自己的话。');
    }
    return _change(eventId, (r) {
      if (approved && !r.hasLesson) throw StateError('可以先保留一条待验证的认识，再自行改写为提醒。');
      return r.withJson({
        'quote_consent': approved,
        'reflection': {...r.reflection, 'personal_reminder': text.trim()}
      });
    });
  }

  /// The existing home quote stream calls this adapter. Its receipts use the
  /// same global recall budget; no row is inserted into the quotations library.
  Future<TalRecord?> personalReminderForHome(
      {required int dailyCap, required bool Function() allowed}) async {
    if (!allowed()) return null;
    final db = await _ready();
    return db.transaction((txn) async {
      final rows = await txn.query('fp_learning_card',
          where: 'tal_event_id IS NOT NULL', orderBy: 'id DESC');
      TalRecord? chosen;
      for (final row in rows) {
        final r = _read(row);
        if (r.reminders.any((e) =>
            e['kind'] == 'quote_home' &&
            (e['ts'] as num).toInt() > nowMs - 86400000)) return null;
        if (chosen == null &&
            r.quoteConsent &&
            r.hasLesson &&
            (r.reflection['personal_reminder'] ?? '').isNotEmpty) chosen = r;
      }
      if (chosen == null) return null;
      final n = clock();
      final day = DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
      final budget = await reminderBudget(txn, day, nowMs);
      int legacyUsed = 0;
      if (await _hasTable(txn, 'prp_recall')) {
        legacyUsed = Sqflite.firstIntValue(await txn.rawQuery(
                'SELECT COUNT(*) FROM prp_recall WHERE ts >= ?', [day])) ??
            0;
        if ((await txn.query('prp_recall',
                columns: ['id'],
                where:
                    "(context = 'quote_home' OR outcome = 'ignored') AND ts > ?",
                whereArgs: [nowMs - 86400000],
                limit: 1))
            .isNotEmpty) return null;
      }
      if (budget.used + legacyUsed >= dailyCap ||
          budget.ignoredRecently ||
          !allowed()) return null;
      final updated = chosen.withJson({
        'reminders': [
          ...chosen.reminders,
          {
            'ref': 'quote_home:$day',
            'kind': 'quote_home',
            'ts': nowMs,
            'ignored': false
          }
        ]
      });
      await txn.update('fp_learning_card', _row(updated),
          where: 'id = ?', whereArgs: [updated.cardId]);
      if (!allowed()) throw StateError('个人提醒已关闭。');
      return updated;
    });
  }

  Future<TalRecord> cancelReminders(String eventId) =>
      _change(eventId, (r) => r.withJson({'reminder_consent': false}));

  Future<void> delete(String eventId) async {
    final db = await _ready();
    await db.delete('fp_learning_card',
        where: 'tal_event_id = ?', whereArgs: [eventId]);
  }

  static Future<bool> _hasTable(DatabaseExecutor db, String name) async =>
      (await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
              [name]))
          .isNotEmpty;

  /// Called by both PRP and this adapter inside their existing SQLite transaction.
  /// Avoid JSON1: Android 8 installations may not provide it.
  static Future<TalReminderBudget> reminderBudget(
      DatabaseExecutor db, int dayStartMs, int nowMs) async {
    if (!await _hasTable(db, 'fp_learning_card'))
      return const TalReminderBudget(0, false);
    final columns = await db.rawQuery('PRAGMA table_info(fp_learning_card)');
    if (!columns.any((c) => c['name'] == 'tal_data_json')) {
      return const TalReminderBudget(0, false);
    }
    final rows = await db.query('fp_learning_card',
        columns: ['tal_data_json'], where: 'tal_event_id IS NOT NULL');
    int count = 0;
    bool ignored = false;
    bool quoted = false;
    for (final row in rows) {
      try {
        final data = jsonDecode(row['tal_data_json'] as String) as Map;
        for (final r in data['reminders'] as List? ?? []) {
          final ts = (r['ts'] as num).toInt();
          if (ts >= dayStartMs) count++;
          if (r['kind'] == 'quote_home' && ts > nowMs - 86400000) quoted = true;
          if (r['ignored'] == true &&
              (r['ignored_ms'] as num? ?? ts).toInt() > nowMs - 86400000)
            ignored = true;
        }
      } on FormatException {/* Preserve damaged rows without rewriting them. */}
    }
    return TalReminderBudget(count, ignored, quotedRecently: quoted);
  }

  Future<TalRecord?> nextRelevantAction(
      {required String subjectKey,
      required String reference,
      required int dailyCap,
      required bool Function() allowed,
      bool Function(TalRecord)? matches}) async {
    if ((subjectKey.isEmpty && matches == null) || !allowed()) return null;
    final db = await _ready();
    return db.transaction((txn) async {
      final rows = await txn.query('fp_learning_card',
          where: matches == null
              ? 'tal_subject_key = ?'
              : 'tal_event_id IS NOT NULL',
          whereArgs: matches == null ? [subjectKey] : null,
          orderBy: 'id DESC');
      final records = rows.map(_read).toList()
        ..sort((a, b) {
          final aExact = subjectKey.isNotEmpty && a.subjectKey == subjectKey;
          final bExact = subjectKey.isNotEmpty && b.subjectKey == subjectKey;
          if (aExact != bExact) return aExact ? -1 : 1;
          return b.cardId!.compareTo(a.cardId!);
        });
      TalRecord? candidate;
      for (final r in records) {
        if (!(subjectKey.isNotEmpty && r.subjectKey == subjectKey) &&
            matches?.call(r) != true) continue;
        if (r.reminderConsent &&
            r.currentTrial != null &&
            r.currentTrial!.evidence.isEmpty &&
            r.state != TalState.paused &&
            r.state != TalState.goalExited &&
            r.reminders.where((r) => r['ignored'] == true).length < 3) {
          candidate = r;
          break;
        }
      }
      if (candidate == null) return null;
      final n = clock();
      final day = DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
      // A render/rebuild never creates a second exposure for the same event/ref.
      if (candidate.reminders.any((r) => r['ref'] == reference)) return null;
      final budget = await reminderBudget(txn, day, nowMs);
      int legacyUsed = 0;
      bool legacyIgnored = false;
      if (await _hasTable(txn, 'prp_recall')) {
        legacyUsed = Sqflite.firstIntValue(await txn.rawQuery(
                'SELECT COUNT(*) FROM prp_recall WHERE ts >= ?', [day])) ??
            0;
        legacyIgnored = (await txn.query('prp_recall',
                columns: ['id'],
                where: "outcome = 'ignored' AND ts > ?",
                whereArgs: [nowMs - 86400000],
                limit: 1))
            .isNotEmpty;
      }
      if (budget.used + legacyUsed >= dailyCap ||
          budget.ignoredRecently ||
          legacyIgnored ||
          !allowed()) return null;
      final updated = candidate.withJson({
        'reminders': [
          ...candidate.reminders,
          {
            'ref': reference,
            'ts': nowMs,
            'ignored': false,
            'trial_id': candidate.currentTrial!.id
          }
        ]
      });
      await txn.update('fp_learning_card', _row(updated),
          where: 'id = ?', whereArgs: [updated.cardId]);
      // Toggling off during an async check rolls back the exposure as well.
      if (!allowed()) throw StateError('提醒已关闭。');
      return updated;
    });
  }

  Future<TalRecord> ignoreReminder(String eventId, String reference) =>
      _change(eventId, (r) {
        final reminders = r.reminders
            .map((e) => e['ref'] == reference
                ? {...e, 'ignored': true, 'ignored_ms': nowMs}
                : e)
            .toList();
        return r.withJson({
          'reminders': reminders,
          'reminder_consent': r.reminderConsent &&
              reminders.where((e) => e['ignored'] == true).length < 3
        });
      });
}
