part of 'runtime.dart';

extension PrpEnhancements on PrpRuntime {
  Future<int> confirmedOccurrences(PrpLesson lesson, PrpContext context) async {
    final db = await store.openDatabase();
    if (!await store.tableExists(db, 'prp_session'))
      return lesson.repeatedCount + 1;
    final rows = await db.query('prp_session',
        columns: ['subject_key', 'expected'],
        where:
            "trigger_kind IN ('habit_missed','commitment_missed') AND started_ms>=? AND started_ms<=?",
        whereArgs: [nowMs - const Duration(days: 30).inMilliseconds, nowMs]);
    final count = rows
        .where((r) =>
            r['subject_key'] == lesson.subjectKey ||
            (context.subjectKey != null &&
                r['subject_key'] == context.subjectKey) ||
            PrpRuntime.similarity('${r['expected']}', lesson.triggerText) >=
                .26)
        .length;
    return count > lesson.repeatedCount + 1 ? count : lesson.repeatedCount + 1;
  }

  Future<String> convertToCommitment(PrpLesson lesson, DateTime due) async {
    if (!enabledFor(PrpSurface.enemy) || !lesson.isSealed)
      return '请开启敌人调用点，并先盖印教训。';
    if (!due.isAfter(clock()) || due.difference(clock()).inDays > 365)
      return '选择未来一年内的截止时间。';
    final current = await store.lesson(lesson.id);
    if (current == null ||
        !current.isSealed ||
        !host.guardText(current.rule).allowed) return '教训已变更，暂不创建字据。';
    return host.commitmentFromLesson(current, due);
  }

  Future<List<PrpForecast>> forecasts() async {
    final db = await store.openDatabase();
    if (!await store.tableExists(db, 'prp_forecast')) return const [];
    return (await db.query('prp_forecast', orderBy: 'created_ms DESC, id DESC'))
        .map(PrpForecast.fromMap)
        .toList();
  }

  Future<PrpForecast?> predict(
      {required String label,
      required int intensity,
      required double days,
      String subjectKey = 'free'}) async {
    if (!enabled || !preferences.forecasts) return null;
    final text = label.trim();
    final guard = host.guardText(text);
    if (guard.crisis || guard.truce) {
      await crisisExit(null, crisis: guard.crisis);
      return null;
    }
    if (!guard.allowed ||
        LessonValidator(host).identityJudgment(text) ||
        text.length < 3 ||
        text.length > 200 ||
        intensity < 0 ||
        intensity > 10 ||
        !days.isFinite ||
        days < 0 ||
        days > 365) return null;
    final epoch = _epoch;
    return _serial<PrpForecast?>('forecast_predict', null, () async {
      final db = await _db(epoch, null);
      final id = await db.transaction<int>((txn) async {
        _check(epoch, null);
        final id = await txn.insert('prp_forecast', {
          'subject_key': subjectKey,
          'label': text,
          'created_ms': nowMs,
          'pred_intensity': intensity,
          'pred_days': days,
        });
        _check(epoch, null);
        return id;
      });
      _publish();
      return PrpForecast(
          id: id,
          subjectKey: subjectKey,
          label: text,
          createdMs: nowMs,
          predictedIntensity: intensity,
          predictedDays: days);
    });
  }

  Future<bool> closeForecast(int id,
      {required int intensity, required double days}) async {
    if (!enabled ||
        !preferences.forecasts ||
        intensity < 0 ||
        intensity > 10 ||
        !days.isFinite ||
        days < 0 ||
        days > 365) return false;
    final epoch = _epoch;
    return _serial<bool>('forecast_actual', false, () async {
      final db = await _db(epoch, null);
      final changed = await db.transaction<int>((txn) async {
        _check(epoch, null);
        final count = await txn.update(
            'prp_forecast',
            {
              'actual_intensity': intensity,
              'actual_days': days,
              'closed_ms': nowMs,
            },
            where: 'id = ? AND closed_ms IS NULL AND created_ms <= ?',
            whereArgs: [id, nowMs]);
        _check(epoch, null);
        return count;
      });
      if (changed > 0) _publish();
      return changed > 0;
    });
  }

  Future<bool> recallAdopted(int recallId) async {
    final db = await store.openDatabase();
    if (!await store.tableExists(db, 'prp_event')) return false;
    return (await db.query('prp_event',
            columns: ['id'],
            where: "kind = 'recall_adopted' AND recall_id = ?",
            whereArgs: [recallId],
            limit: 1))
        .isNotEmpty;
  }

  Future<bool> adoptRecall(PrpRecall recall) async {
    if (!enabledFor(recall.surface) || !preferences.recalls) return false;
    final epoch = _epoch;
    return _serial<bool>('recall_adopt', false, () async {
      final db = await _db(epoch, recall.surface);
      final saved = await db.transaction<bool>((txn) async {
        _check(epoch, recall.surface);
        final valid = await txn.rawQuery('''SELECT r.id FROM prp_recall r
          JOIN prp_lesson l ON l.id = r.lesson_id
          WHERE r.id = ? AND r.surface = ? AND r.outcome = 'pending' AND l.state = 'sealed' ''',
            [recall.id, recall.surface.key]);
        if (valid.isEmpty) return false;
        await txn.insert(
            'prp_event',
            {
              'kind': 'recall_adopted',
              'recall_id': recall.id,
              'created_ms': nowMs
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
        _check(epoch, recall.surface);
        return true;
      });
      if (saved) _publish();
      return saved;
    });
  }

  Future<PrpObservation> observations() async {
    await _tail;
    final db = await store.openDatabase();
    if (!await store.exists(db)) return const PrpObservation();
    final since = nowMs - const Duration(days: 30).inMilliseconds;
    final sessions = await db.query('prp_session',
        where: "started_ms >= ? AND trigger_kind != 'daily_review_draft'",
        whereArgs: [since]);
    final recalls =
        await db.query('prp_recall', where: 'ts >= ?', whereArgs: [since]);
    final ids = recalls.map((r) => (r['id'] as num).toInt()).toSet();
    final adopted = await store.tableExists(db, 'prp_event')
        ? (await db.query('prp_event', where: "kind = 'recall_adopted'"))
            .map((r) => (r['recall_id'] as num).toInt())
            .where(ids.contains)
            .toSet()
        : <int>{};
    final touched = {
      ...adopted,
      ...recalls
          .where((r) => r['outcome'] != 'pending')
          .map((r) => (r['id'] as num).toInt())
    };
    final emotions = sessions
        .where((s) =>
            s['emotion_before'] != null &&
            s['emotion_after'] != null &&
            s['step'] == 'done' &&
            s['outcome'] == 'sealed')
        .map((s) =>
            (s['emotion_after'] as num).toDouble() -
            (s['emotion_before'] as num).toDouble())
        .toList();
    final allLessons = {for (final l in await store.lessons()) l.id: l};
    int root(int id) {
      final visited = <int>{};
      while (allLessons[id]?.parentId != null && visited.add(id)) {
        id = allLessons[id]!.parentId!;
      }
      return id;
    }

    final groups = <int, List<int>>{};
    for (final row in recalls
        .where((r) => r['outcome'] == 'repeated' && r['outcome_ms'] != null)) {
      groups
          .putIfAbsent(root((row['lesson_id'] as num).toInt()), () => [])
          .add((row['outcome_ms'] as num).toInt());
    }
    final intervals = <double>[];
    final gaps = <int, List<double>>{};
    for (final entry in groups.entries) {
      final times = entry.value;
      times.sort();
      for (var i = 1; i < times.length; i++) {
        if (times[i] > times[i - 1]) {
          final gap = (times[i] - times[i - 1]) /
              const Duration(days: 1).inMilliseconds;
          intervals.add(gap);
          gaps.putIfAbsent(entry.key, () => []).add(gap);
        }
      }
    }
    return PrpObservation(
        sessions: sessions.length,
        completed: sessions
            .where((s) => s['step'] == 'done' && s['outcome'] == 'sealed')
            .length,
        sealed: sessions.where((s) => s['outcome'] == 'sealed').length,
        skipped: sessions.where((s) => s['outcome'] == 'skipped').length,
        pauseSeconds: sessions.fold(
            0, (n, s) => n + ((s['pause_sec'] as num?)?.toInt() ?? 0)),
        recalls: recalls.length,
        clicked: touched.length,
        adopted: adopted.length,
        helped: recalls.where((r) => r['outcome'] == 'helped').length,
        repeated: recalls.where((r) => r['outcome'] == 'repeated').length,
        stepCounts: {
          for (final step in PrpStep.values)
            step.name: sessions.where((s) => s['step'] == step.name).length
        },
        repeatGaps: gaps,
        meanEmotionChange: emotions.isEmpty
            ? null
            : emotions.reduce((a, b) => a + b) / emotions.length,
        meanRepeatDays: intervals.isEmpty
            ? null
            : intervals.reduce((a, b) => a + b) / intervals.length);
  }

  Future<PrpOffer?> reviewDraftQuote(PrpDraftQuote entry) async {
    if (!enabledFor(PrpSurface.failureModule) ||
        !preferences.draftQuotes ||
        !host.guardText(entry.text).allowed) return null;
    final offer = await signal(PrpSignal(
        surface: PrpSurface.failureModule,
        kind: 'manual',
        subjectKey: 'free',
        expected: '',
        tsMs: nowMs,
        reference: 'draft_quote:${entry.id}:$nowMs'));
    if (offer == null || !offerActive(offer)) return null;
    initialLessons[offer.sessionId] = PrpLesson(
        subjectKey: 'free',
        source: PrpSurface.failureModule,
        createdMs: nowMs,
        sentences: [PrpSentence(entry.text, PrpSentenceKind.interpretation)]);
    return offer;
  }
}
