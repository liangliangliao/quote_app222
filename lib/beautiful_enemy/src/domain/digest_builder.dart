import '../data/models.dart';

/// 交给判词生成器的摘要。原始数据不出本机，只有这份聚合后的 JSON 会给模型。
class EnemyDigest {
  const EnemyDigest({
    required this.json,
    required this.evidenceIds,
    required this.sufficient,
  });

  final Map<String, dynamic> json;

  /// 摘要里出现过的全部证据 id。判词只能引用这里面的。
  final Set<int> evidenceIds;

  /// 窗口内有没有足够的证据可以评判。
  final bool sufficient;
}

class DigestBuilder {
  const DigestBuilder._();

  static const int maxEvidenceIds = 40;
  static const int maxItems = 5;

  static EnemyDigest build({
    required int nowMs,
    required int windowMs,
    required int intensity,
    required List<EnemyEvent> events,
    required List<EnemyCommitment> weekCommitments,
    required List<EnemyVerdict> recentVerdicts,
    required List<EnemyLesson> lessons,
  }) {
    final int fromMs = nowMs - windowMs;
    final Set<int> ids = <int>{};

    // ---- 习惯打卡：同一项同一天只认最后一次状态。
    final Map<String, EnemyEvent> latestHabit = <String, EnemyEvent>{};
    for (final EnemyEvent e in events.where((EnemyEvent e) => e.source == 'habit')) {
      final String key = '${e.subject}|${e.day}';
      final EnemyEvent? old = latestHabit[key];
      if (old == null || e.ts >= old.ts) latestHabit[key] = e;
    }
    int habitDone = 0, habitMissed = 0, habitSkipped = 0;
    final List<Map<String, dynamic>> habitItems = <Map<String, dynamic>>[];
    for (final EnemyEvent e in latestHabit.values) {
      String status;
      switch (e.type) {
        case 'habit_done':
          habitDone++;
          status = 'done';
          break;
        case 'habit_missed':
          habitMissed++;
          status = 'missed';
          break;
        default:
          habitSkipped++;
          status = 'skipped';
      }
      ids.add(e.id);
      if (status != 'done' && habitItems.length < maxItems) {
        habitItems.add(<String, dynamic>{
          'name': e.label,
          'status': status,
          'day': e.day,
          'evidence': <int>[e.id],
        });
      }
    }

    // ---- 火种。
    int kCompleted = 0, kAborted = 0, kMinutes = 0;
    final List<int> kEvidence = <int>[];
    for (final EnemyEvent e in events.where((EnemyEvent e) => e.source == 'kindling')) {
      if (e.type == 'kindling_completed') {
        kCompleted++;
        final Object? m = e.payload['minutes'];
        if (m is num) kMinutes += m.round();
      } else if (e.type == 'kindling_aborted') {
        kAborted++;
      } else {
        continue;
      }
      ids.add(e.id);
      if (kEvidence.length < maxItems) kEvidence.add(e.id);
    }

    // ---- 知识卡转换 / 行为记录。
    final List<EnemyEvent> knowledge =
        events.where((EnemyEvent e) => e.source == 'knowledge').toList();
    final List<EnemyEvent> journal =
        events.where((EnemyEvent e) => e.source == 'journal').toList();
    for (final EnemyEvent e in <EnemyEvent>[...knowledge, ...journal]) {
      ids.add(e.id);
    }

    // ---- 承诺：窗口内到期的，和它们对应的事件。
    final List<EnemyEvent> commitmentEvents =
        events.where((EnemyEvent e) => e.source == 'commitment').toList();
    int cDone = 0, cMissed = 0, cExcused = 0, cOpenDue = 0;
    final List<Map<String, dynamic>> cItems = <Map<String, dynamic>>[];
    for (final EnemyCommitment c in weekCommitments) {
      final int? due = c.dueMs;
      if (due == null || due < fromMs || due >= nowMs) continue;
      switch (c.status) {
        case CommitmentStatus.done:
          cDone++;
          break;
        case CommitmentStatus.missed:
          cMissed++;
          break;
        case CommitmentStatus.excused:
          cExcused++;
          break;
        default:
          cOpenDue++;
      }
      final List<int> ev = commitmentEvents
          .where((EnemyEvent e) => e.payload['commitment_id'] == c.id)
          .map((EnemyEvent e) => e.id)
          .toList();
      ids.addAll(ev);
      if (cItems.length < maxItems && c.status != CommitmentStatus.done) {
        cItems.add(<String, dynamic>{
          'id': c.id,
          'text': c.text,
          'status': c.status == CommitmentStatus.open ? 'open' : c.status,
          'evidence': ev,
        });
      }
    }
    final int cDue = cDone + cMissed + cExcused + cOpenDue;

    int weekDone = 0, weekMissed = 0;
    for (final EnemyCommitment c in weekCommitments) {
      if (c.status == CommitmentStatus.done) weekDone++;
      if (c.status == CommitmentStatus.missed) weekMissed++;
    }

    // ---- 历史：连续兑现、上一条教训、最近的申辩。
    int doneStreak = 0;
    for (final EnemyVerdict v in recentVerdicts) {
      if (v.outcome == 'pending') continue;
      if (v.outcome == 'done') {
        doneStreak++;
      } else {
        break;
      }
    }
    final EnemyLesson? lastLesson = lessons.isEmpty ? null : lessons.first;
    final List<Map<String, dynamic>> appeals = recentVerdicts
        .where((EnemyVerdict v) => v.userResponse == VerdictResponse.appeal)
        .take(3)
        .map((EnemyVerdict v) => <String, dynamic>{
              'verdict_id': v.id,
              'accepted': v.outcome == 'excused',
            })
        .toList();
    final List<String> avoid =
        recentVerdicts.take(3).map((EnemyVerdict v) => v.charge).toList();

    final List<int> idList = ids.toList()..sort();
    final List<int> cappedIds =
        idList.length > maxEvidenceIds ? idList.sublist(idList.length - maxEvidenceIds) : idList;

    final Map<String, dynamic> json = <String, dynamic>{
      'window': <String, dynamic>{
        'from': DateTime.fromMillisecondsSinceEpoch(fromMs).toIso8601String(),
        'to': DateTime.fromMillisecondsSinceEpoch(nowMs).toIso8601String(),
      },
      'intensity': intensity,
      'evidence_ids': cappedIds,
      'commitments': <String, dynamic>{
        'due': cDue,
        'done': cDone,
        'missed': cMissed,
        'excused': cExcused,
        'open_overdue': cOpenDue,
        'week_done': weekDone,
        'week_missed': weekMissed,
        'items': cItems,
      },
      'habits': <String, dynamic>{
        'done': habitDone,
        'missed': habitMissed,
        'skipped': habitSkipped,
        'items': habitItems,
      },
      'kindling': <String, dynamic>{
        'completed': kCompleted,
        'aborted': kAborted,
        'minutes': kMinutes,
        'evidence': kEvidence,
      },
      'knowledge': <String, dynamic>{
        'conversions': knowledge.length,
        'evidence': knowledge.take(maxItems).map((EnemyEvent e) => e.id).toList(),
      },
      'journal': <String, dynamic>{
        'entries': journal.length,
        'evidence': journal.take(maxItems).map((EnemyEvent e) => e.id).toList(),
      },
      'history': <String, dynamic>{
        'done_streak': doneStreak,
        'last_failure_category': lastLesson?.category ?? '',
        'same_failure_count_30d': lastLesson?.timesRepeated ?? 0,
        'last_lesson': lastLesson?.lesson ?? '',
      },
      'appeals_recent': appeals,
      'avoid': avoid,
    };

    return EnemyDigest(
      json: json,
      evidenceIds: cappedIds.toSet(),
      sufficient: cappedIds.isNotEmpty,
    );
  }
}
