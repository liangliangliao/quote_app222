import 'dart:convert';

import 'models.dart';

/// 插件自有的表（全部以 prp_ 为前缀，不改任何既有表）。
/// 与方案附录 A 相比多了一列 subject_text（保存信号里的“预期”，用于相似匹配）。
class PrpSchema {
  const PrpSchema._();

  static const List<String> createStatements = <String>[
    '''
    CREATE TABLE IF NOT EXISTS prp_lesson (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      subject_key   TEXT NOT NULL DEFAULT '',
      subject_text  TEXT NOT NULL DEFAULT '',
      category      TEXT NOT NULL DEFAULT '',
      source        TEXT NOT NULL DEFAULT 'enemy',
      state         TEXT NOT NULL DEFAULT 'draft',
      worked        TEXT NOT NULL DEFAULT '[]',
      failed        TEXT NOT NULL DEFAULT '[]',
      trigger_text  TEXT NOT NULL DEFAULT '',
      early_signal  TEXT NOT NULL DEFAULT '',
      if_cue        TEXT NOT NULL DEFAULT '',
      then_action   TEXT NOT NULL DEFAULT '',
      evidence_refs TEXT NOT NULL DEFAULT '[]',
      quality       INTEGER NOT NULL DEFAULT 0,
      created_ms    INTEGER NOT NULL,
      sealed_ms     INTEGER,
      parent_id     INTEGER,
      verified_cnt  INTEGER NOT NULL DEFAULT 0,
      repeated_cnt  INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS prp_session (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      surface        TEXT NOT NULL,
      trigger_kind   TEXT NOT NULL,
      trigger_ref    TEXT NOT NULL DEFAULT '',
      started_ms     INTEGER NOT NULL,
      pause_sec      INTEGER NOT NULL DEFAULT 0,
      emotion_before INTEGER,
      emotion_after  INTEGER,
      step           TEXT NOT NULL DEFAULT 'pause',
      lesson_id      INTEGER,
      ended_ms       INTEGER,
      outcome        TEXT NOT NULL DEFAULT 'open'
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS prp_recall (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      lesson_id INTEGER NOT NULL,
      ts        INTEGER NOT NULL,
      context   TEXT NOT NULL,
      ref       TEXT NOT NULL DEFAULT '',
      outcome   TEXT NOT NULL DEFAULT 'pending'
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_prp_lesson_state ON prp_lesson(state, sealed_ms)',
    'CREATE INDEX IF NOT EXISTS idx_prp_lesson_subj ON prp_lesson(subject_key, state)',
    'CREATE INDEX IF NOT EXISTS idx_prp_recall_lesson ON prp_recall(lesson_id, ts)',
    'CREATE INDEX IF NOT EXISTS idx_prp_recall_outcome ON prp_recall(outcome, ts)',
  ];

  static const List<String> tables = <String>[
    'prp_lesson',
    'prp_session',
    'prp_recall',
  ];
}

/// 存储抽象：核心逻辑只认它。生产用 SqflitePrpStore，测试用 [MemoryPrpStore]。
abstract class PrpStore {
  Future<int> insertSession(PrpSession s);
  Future<void> updateSession(PrpSession s);
  Future<PrpSession?> session(int id);
  Future<int> countSessionsSince(int sinceMs);
  Future<int> sessionCount();

  Future<int> insertLesson(PrpLesson l);
  Future<void> updateLesson(PrpLesson l);
  Future<PrpLesson?> lesson(int id);
  Future<List<PrpLesson>> lessons({PrpLessonState? state, int limit = 200});
  Future<int> lessonCount(PrpLessonState state);
  Future<void> bumpLessonCounters(
    int lessonId, {
    int verified = 0,
    int repeated = 0,
  });

  Future<int> insertRecall(PrpRecall r);
  Future<PrpRecall?> recall(int id);
  Future<void> updateRecallOutcome(int id, PrpOutcome outcome);
  Future<List<PrpRecall>> recalls({PrpOutcome? outcome, int limit = 200});
  Future<int> countRecallsSince(int sinceMs, {required Set<String> contexts});
  Future<int> recallCount();

  Future<String> exportJson();
  Future<void> clearAll();
}

/// 内存实现：给单元测试和“插件未接入”的场景用。
class MemoryPrpStore implements PrpStore {
  final Map<int, PrpSession> _sessions = <int, PrpSession>{};
  final Map<int, PrpLesson> _lessons = <int, PrpLesson>{};
  final Map<int, PrpRecall> _recalls = <int, PrpRecall>{};
  int _sid = 0;
  int _lid = 0;
  int _rid = 0;

  /// 测试用：读写次数，用来断言“关闭零痕迹”。
  int writeCount = 0;
  int readCount = 0;

  @override
  Future<int> insertSession(PrpSession s) async {
    writeCount++;
    final int id = ++_sid;
    _sessions[id] = s.copyWith(id: id);
    return id;
  }

  @override
  Future<void> updateSession(PrpSession s) async {
    writeCount++;
    if (s.id != null) _sessions[s.id!] = s;
  }

  @override
  Future<PrpSession?> session(int id) async {
    readCount++;
    return _sessions[id];
  }

  @override
  Future<int> countSessionsSince(int sinceMs) async {
    readCount++;
    return _sessions.values
        .where((PrpSession s) => s.startedMs >= sinceMs)
        .length;
  }

  @override
  Future<int> sessionCount() async {
    readCount++;
    return _sessions.length;
  }

  @override
  Future<int> insertLesson(PrpLesson l) async {
    writeCount++;
    final int id = ++_lid;
    _lessons[id] = l.copyWith(id: id);
    return id;
  }

  @override
  Future<void> updateLesson(PrpLesson l) async {
    writeCount++;
    if (l.id != null) _lessons[l.id!] = l;
  }

  @override
  Future<PrpLesson?> lesson(int id) async {
    readCount++;
    return _lessons[id];
  }

  @override
  Future<List<PrpLesson>> lessons({
    PrpLessonState? state,
    int limit = 200,
  }) async {
    readCount++;
    final List<PrpLesson> out =
        _lessons.values
            .where((PrpLesson l) => state == null || l.state == state)
            .toList()
          ..sort(
            (PrpLesson a, PrpLesson b) => (b.sealedMs ?? b.createdMs).compareTo(
              a.sealedMs ?? a.createdMs,
            ),
          );
    return out.take(limit).toList();
  }

  @override
  Future<int> lessonCount(PrpLessonState state) async {
    readCount++;
    return _lessons.values.where((PrpLesson l) => l.state == state).length;
  }

  @override
  Future<void> bumpLessonCounters(
    int lessonId, {
    int verified = 0,
    int repeated = 0,
  }) async {
    writeCount++;
    final PrpLesson? l = _lessons[lessonId];
    if (l == null) return;
    _lessons[lessonId] = l.copyWith(
      verifiedCnt: l.verifiedCnt + verified,
      repeatedCnt: l.repeatedCnt + repeated,
    );
  }

  @override
  Future<int> insertRecall(PrpRecall r) async {
    writeCount++;
    final int id = ++_rid;
    _recalls[id] = PrpRecall(
      id: id,
      lessonId: r.lessonId,
      ts: r.ts,
      context: r.context,
      ref: r.ref,
      outcome: r.outcome,
    );
    return id;
  }

  @override
  Future<PrpRecall?> recall(int id) async {
    readCount++;
    return _recalls[id];
  }

  @override
  Future<void> updateRecallOutcome(int id, PrpOutcome outcome) async {
    writeCount++;
    final PrpRecall? r = _recalls[id];
    if (r == null) return;
    _recalls[id] = PrpRecall(
      id: id,
      lessonId: r.lessonId,
      ts: r.ts,
      context: r.context,
      ref: r.ref,
      outcome: outcome,
    );
  }

  @override
  Future<List<PrpRecall>> recalls({
    PrpOutcome? outcome,
    int limit = 200,
  }) async {
    readCount++;
    final List<PrpRecall> out =
        _recalls.values
            .where((PrpRecall r) => outcome == null || r.outcome == outcome)
            .toList()
          ..sort((PrpRecall a, PrpRecall b) => b.ts.compareTo(a.ts));
    return out.take(limit).toList();
  }

  @override
  Future<int> countRecallsSince(
    int sinceMs, {
    required Set<String> contexts,
  }) async {
    readCount++;
    return _recalls.values
        .where((PrpRecall r) => r.ts >= sinceMs && contexts.contains(r.context))
        .length;
  }

  @override
  Future<int> recallCount() async {
    readCount++;
    return _recalls.length;
  }

  @override
  Future<String> exportJson() async {
    readCount++;
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'version': 1,
      'lessons': _lessons.values.map((PrpLesson l) => l.toMap()).toList(),
      'sessions': _sessions.values.map((PrpSession s) => s.toMap()).toList(),
      'recalls': _recalls.values.map((PrpRecall r) => r.toMap()).toList(),
    });
  }

  @override
  Future<void> clearAll() async {
    writeCount++;
    _sessions.clear();
    _lessons.clear();
    _recalls.clear();
  }
}
