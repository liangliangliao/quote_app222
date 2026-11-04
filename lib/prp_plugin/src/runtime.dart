import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../prp_plugin.dart';
import 'settings.dart';
import 'store.dart';
import 'validator.dart';
import 'ui.dart';

class _Cancelled implements Exception {}

/// A single serialized writer enforces budgets and idempotent result reporting.
/// Disabling invalidates every in-flight transaction and every mounted slot.
class PrpRuntime extends PrpPlugin {
  PrpRuntime(
      {required this.settings,
      required this.store,
      this.host = const NoopPrpHost(),
      DateTime Function()? clock,
      Stopwatch Function()? stopwatchFactory})
      : clock = clock ?? DateTime.now,
        stopwatchFactory = stopwatchFactory ?? Stopwatch.new;

  final PrpSettings settings;
  final PrpStore store;
  final PrpHost host;
  final DateTime Function() clock;
  final Stopwatch Function() stopwatchFactory;
  PrpPreferences preferences = const PrpPreferences();
  Future<void>? _initializing;
  Future<void> _tail = Future.value();
  int _epoch = 0;
  int consecutiveErrors = 0;
  bool circuitOpen = false;
  int crisisUntilMs = 0;
  final List<Map<String, Object?>> diagnostics = [];
  final Map<int, int> _offers = {};
  final Map<int, int> _presented = {};
  final Map<int, PrpOffer> _offerValues = {};
  final Map<int, List<PrpEvidence>> _evidence = {};
  final Map<int, PrpLesson> initialLessons = {};

  int get nowMs => clock().millisecondsSinceEpoch;
  int get dayStartMs {
    final n = clock();
    return DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
  }

  @override
  bool get enabled =>
      preferences.enabled && !circuitOpen && crisisUntilMs <= nowMs;
  @override
  bool get aiAllowed => enabled && preferences.aiConsent;
  @override
  bool get quoteStreamEnabled =>
      enabledFor(PrpSurface.quoteHome) && preferences.quoteStream;
  @override
  bool get hasActiveSession =>
      enabled && _presented.keys.any((id) => _offers[id] == _epoch);

  int sessionShown(PrpOffer offer) {
    if (!offerActive(offer)) return -1;
    _presented.update(offer.sessionId, (count) => count + 1, ifAbsent: () => 1);
    return _epoch;
  }

  void sessionHidden(PrpOffer offer, int epoch) {
    if (epoch != _epoch) return;
    final count = _presented[offer.sessionId] ?? 0;
    if (count <= 1)
      _presented.remove(offer.sessionId);
    else
      _presented[offer.sessionId] = count - 1;
  }

  @override
  bool enabledFor(PrpSurface surface) =>
      enabled && preferences.surfaces[surface] == true;

  void _note(String event, {String detail = ''}) {
    diagnostics.add({'ts': nowMs, 'event': event, 'detail': detail});
    if (diagnostics.length > 30) diagnostics.removeAt(0);
  }

  void _error(String operation, Object error) {
    consecutiveErrors++;
    _note('internal_error', detail: '$operation: ${error.runtimeType}');
    if (consecutiveErrors >= 3) {
      circuitOpen = true;
      _offers.clear();
      _note('circuit_open', detail: '本次启动静默；下次启动自动恢复');
      unawaited(host.stopAudio().catchError((Object _) {}));
      PrpPlugin.changed();
    }
  }

  Future<void> initialize() => _initializing ??= () async {
        try {
          preferences = await settings.load();
          final raw = await settings.read('prp.crisis_until_ms');
          crisisUntilMs = int.tryParse(raw ?? '') ?? 0;
          _note('registered');
        } catch (e) {
          _error('settings_load', e);
        }
        PrpPlugin.changed();
      }();

  Future<T> _serial<T>(String name, T fallback, Future<T> Function() action) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        final value = await action();
        consecutiveErrors = 0;
        result.complete(value);
      } on _Cancelled {
        result.complete(fallback);
      } catch (e) {
        _error(name, e);
        result.complete(fallback);
      }
    });
    return result.future;
  }

  void _check(int epoch, PrpSurface surface) {
    if (epoch != _epoch || !enabledFor(surface)) throw _Cancelled();
  }

  Future<void> updatePreferences(PrpPreferences next) async {
    await initialize();
    final before = preferences;
    preferences = next.copyWith();
    _epoch++;
    _offers.clear();
    _offerValues.clear();
    _evidence.clear();
    _presented.clear();
    PrpPlugin.changed();
    await _tail;
    if (!next.enabled || !next.voice) {
      try {
        await host.stopAudio();
      } catch (e) {
        _error('stop_audio', e);
      }
    }
    try {
      await settings.save(preferences);
      _note('settings_saved', detail: next.enabled ? '开' : '关');
    } catch (e) {
      // Fail closed if disabling could not be persisted; never re-enable a slot.
      if (next.enabled) preferences = before.copyWith(enabled: false);
      _error('settings_save', e);
      PrpPlugin.changed();
      rethrow;
    }
  }

  Future<bool> _allowed(int epoch, PrpSurface surface) async {
    _check(epoch, surface);
    final governance = await host.governance();
    _check(epoch, surface);
    return governance.allows;
  }

  Future<Database> _db(int epoch, PrpSurface surface) async {
    final db = await store.openDatabase();
    _check(epoch, surface);
    if (!await store.exists(db)) {
      _check(epoch, surface);
      await db.transaction((txn) async {
        _check(epoch, surface);
        await PrpSchema.createAll(txn);
        _check(epoch, surface);
      });
    }
    return db;
  }

  @override
  Future<PrpOffer?> signal(PrpSignal signal) async {
    if (!enabledFor(signal.surface) ||
        signal.surface == PrpSurface.kindling ||
        signal.surface == PrpSurface.quoteHome ||
        !['manual', 'commitment_missed', 'habit_missed']
            .contains(signal.kind) ||
        (signal.kind != 'manual' && !signal.confirmed)) return null;
    final epoch = _epoch;
    return _serial<PrpOffer?>('signal', null, () async {
      if (!await _allowed(epoch, signal.surface)) return null;
      final guard =
          host.guardText([signal.expected, ...signal.facts].join('\n'));
      if (guard.crisis || guard.truce) {
        await crisisExit(null, crisis: guard.crisis);
        return null;
      }
      if (!guard.allowed ||
          LessonValidator(host).identityJudgment(signal.expected)) return null;
      final db = await _db(epoch, signal.surface);
      _check(epoch, signal.surface);
      final id = await db.transaction<int?>((txn) async {
        final existing = await txn.query('prp_session',
            where: 'surface = ? AND trigger_kind = ? AND trigger_ref = ?',
            whereArgs: [signal.surface.key, signal.kind, signal.dedupeKey],
            limit: 1);
        _check(epoch, signal.surface);
        if (existing.isNotEmpty) {
          final row = existing.first;
          return row['outcome'] == 'open' ? (row['id'] as num).toInt() : null;
        }
        // Daily caps limit automatic offers. An explicit manual review is a
        // user action, like continuing a draft, and consumes no offer budget.
        final automatic = signal.kind != 'manual';
        final count = Sqflite.firstIntValue(await txn.rawQuery(
                "SELECT COUNT(*) FROM prp_session WHERE started_ms >= ? AND counts_offer = 1",
                [dayStartMs])) ??
            0;
        if (automatic && count >= preferences.offerCap) return null;
        final ignored = await txn.query('prp_session',
            columns: ['ended_ms'],
            where: "outcome = 'skipped' AND counts_offer = 1 AND ended_ms > ?",
            whereArgs: [nowMs - const Duration(hours: 24).inMilliseconds],
            limit: 1);
        if (automatic && ignored.isNotEmpty) return null;
        final id = await txn.insert('prp_session', {
          'surface': signal.surface.key,
          'trigger_kind': signal.kind,
          'trigger_ref': signal.dedupeKey,
          'subject_key': signal.subjectKey,
          'expected': signal.expected,
          'started_ms': nowMs,
          'counts_offer': automatic ? 1 : 0,
          'step': preferences.sessions ? 'pause' : 'ledger',
        });
        _check(epoch, signal.surface);
        return id;
      });
      _note('signal',
          detail:
              '${signal.surface.key}/${signal.kind}: ${id == null ? '受预算限制或已处理' : '提议 $id'}');
      if (id == null) return null;
      _check(epoch, signal.surface);
      final offer = PrpOffer(sessionId: id, signal: signal);
      _offers[id] = epoch;
      _offerValues[id] = offer;
      try {
        await host.sessionStarted();
      } catch (e) {
        _error('session_started', e);
      }
      return offer;
    });
  }

  bool offerActive(PrpOffer offer) =>
      enabledFor(offer.signal.surface) && _offers[offer.sessionId] == _epoch;
  PrpOffer? pendingOffer(PrpSurface surface) => _offerValues.values
      .where((o) => o.signal.surface == surface && offerActive(o))
      .firstOrNull;

  Future<Map<String, Object?>> sessionState(PrpOffer offer) async {
    if (!offerActive(offer)) return const {};
    return _serial<Map<String, Object?>>('session_read', const {}, () async {
      final db = await store.openDatabase();
      final rows = await db.query('prp_session',
          where: 'id = ?', whereArgs: [offer.sessionId], limit: 1);
      return rows.isEmpty ? const {} : rows.first;
    });
  }

  Future<List<PrpEvidence>> evidenceFor(PrpOffer offer) async {
    if (!offerActive(offer)) return const [];
    if (_evidence.containsKey(offer.sessionId))
      return _evidence[offer.sessionId]!;
    return _serial<List<PrpEvidence>>('evidence', const [], () async {
      final epoch = _epoch;
      final extra = await host.evidenceFor(offer.signal);
      _check(epoch, offer.signal.surface);
      final result = <PrpEvidence>[
        for (var i = 0; i < offer.signal.facts.length; i++)
          PrpEvidence(
              source: offer.signal.surface.key,
              id: '${offer.signal.dedupeKey}:$i',
              label: offer.signal.facts[i],
              kind: 'record'),
        ...extra,
      ]
          .where((e) =>
              host.guardText(e.label).allowed &&
              !LessonValidator(host).identityJudgment(e.label))
          .toList();
      _evidence[offer.sessionId] = result;
      return result;
    });
  }

  Future<List<PrpSentence>> classifyText(PrpOffer offer, String text) async {
    final local = LessonValidator(host).classify(text);
    if (!offerActive(offer) || !aiAllowed || !host.guardText(text).allowed)
      return local;
    final epoch = _epoch;
    return _serial<List<PrpSentence>>('ai_classify', local, () async {
      final raw = await host.callAi(
          'classify', {'expected': offer.signal.expected, 'user_text': text});
      _check(epoch, offer.signal.surface);
      if (!aiAllowed || raw == null) return local;
      try {
        final object = jsonDecode(raw);
        if (object is! Map || object['sentences'] is! List) return local;
        final sentences = object['sentences'] as List;
        if (sentences.isEmpty || sentences.length > 30) return local;
        final result = <PrpSentence>[];
        for (final row in sentences) {
          if (row is! Map ||
              row['text'] is! String ||
              !['fact', 'interpretation', 'self_blame'].contains(row['kind']))
            return local;
          final original = row['text'] as String;
          if (original.isEmpty || !text.contains(original)) return local;
          final identity = LessonValidator(host).identityJudgment(original) ||
              !host.guardText(original).allowed;
          result.add(PrpSentence(
              original,
              identity || row['kind'] == 'self_blame'
                  ? PrpSentenceKind.selfBlame
                  : row['kind'] == 'fact'
                      ? PrpSentenceKind.fact
                      : PrpSentenceKind.interpretation));
        }
        return result;
      } catch (_) {
        return local;
      }
    });
  }

  Future<PrpLesson> draftWithAi(PrpOffer offer, PrpLesson input) async {
    if (!offerActive(offer) || !aiAllowed || !_safeLesson(input)) return input;
    final epoch = _epoch;
    return _serial<PrpLesson>('ai_draft', input, () async {
      final allowed = [
        input.triggerText,
        ...input.worked,
        ...input.failed,
        input.earlySignal,
        input.ifCue,
        input.thenAction,
        ...input.sentences
            .where((s) => s.kind != PrpSentenceKind.selfBlame)
            .map((s) => s.revision.isEmpty ? s.text : s.revision)
      ].where((s) => s.isNotEmpty).toList();
      final raw = await host.callAi(
          'draft', {'category': input.category, 'allowed_texts': allowed});
      _check(epoch, offer.signal.surface);
      if (!aiAllowed || raw == null) return input;
      try {
        final object = jsonDecode(raw);
        if (object is! Map ||
            object['worked'] is! List ||
            object['failed'] is! List ||
            object['if_then'] is! Map) return input;
        final worked = (object['worked'] as List).cast<String>();
        final failed = (object['failed'] as List).cast<String>();
        final early = object['early_signal'];
        final cue = object['if_then']['cue'];
        final action = object['if_then']['action'];
        if (early is! String ||
            cue is! String ||
            action is! String ||
            worked.length > 10 ||
            failed.length > 10) return input;
        final proposed = [...worked, ...failed, early, cue, action];
        // Strict extractive grounding. Plausible paraphrases are discarded too.
        if (proposed.any(
            (s) => s.isEmpty || !allowed.any((source) => source.contains(s))))
          return input;
        final draft = PrpLesson(
            subjectKey: input.subjectKey,
            source: input.source,
            createdMs: input.createdMs,
            category: input.category,
            triggerText: input.triggerText,
            worked: worked,
            failed: failed,
            earlySignal: early,
            ifCue: cue,
            thenAction: action,
            evidence: input.evidence,
            sentences: input.sentences,
            parentId: input.parentId,
            quoteAllowed: input.quoteAllowed);
        return LessonValidator(host).validate(draft).valid && _safeLesson(draft)
            ? draft
            : input;
      } catch (_) {
        return input;
      }
    });
  }

  /// Reject guarded text before every persisted draft, including imported data.
  bool _safeLesson(PrpLesson lesson) => [
        lesson.triggerText,
        ...lesson.worked,
        ...lesson.failed,
        lesson.earlySignal,
        lesson.ifCue,
        lesson.thenAction,
        ...lesson.sentences.map((s) => '${s.text}\n${s.revision}')
      ].every((text) =>
          host.guardText(text).allowed &&
          !LessonValidator(host).identityJudgment(text));

  Future<PrpLesson?> saveDraft(
    PrpOffer offer,
    PrpLesson lesson, {
    required PrpStep step,
    required int pauseSeconds,
    int? emotionBefore,
    int? emotionAfter,
    bool skipped = false,
  }) async {
    if (!offerActive(offer)) return null;
    if (_lessonCrisis(lesson)) {
      await crisisExit(offer);
      return null;
    }
    if (!_safeLesson(lesson)) return null;
    final epoch = _epoch;
    return _serial<PrpLesson?>('draft', null, () async {
      _check(epoch, offer.signal.surface);
      final db = await _db(epoch, offer.signal.surface);
      final result = await db.transaction<PrpLesson?>((txn) async {
        final rows = await txn.query('prp_session',
            where: "id = ? AND outcome = 'open'", whereArgs: [offer.sessionId]);
        if (rows.isEmpty) return null;
        final oldId = (rows.first['lesson_id'] as num?)?.toInt();
        var saved = lesson.copyWith(
            id: oldId ?? 0,
            state: 'draft',
            quality: LessonValidator(host).validate(lesson).quality);
        final map = saved.toMap()..remove('id');
        if (oldId == null) {
          saved = saved.copyWith(id: await txn.insert('prp_lesson', map));
        } else {
          await txn.update('prp_lesson', map,
              where: "id = ? AND state = 'draft'", whereArgs: [oldId]);
        }
        await txn.update(
            'prp_session',
            {
              'lesson_id': saved.id,
              'step': step.name,
              'pause_sec': pauseSeconds,
              'expected': saved.triggerText,
              'emotion_before': emotionBefore,
              'emotion_after': emotionAfter,
              if (skipped) ...{
                'pause_skipped': 1,
                'outcome': 'skipped',
                'ended_ms': nowMs
              },
            },
            where: 'id = ?',
            whereArgs: [offer.sessionId]);
        _check(epoch, offer.signal.surface);
        return saved;
      });
      if (skipped) {
        _offers.remove(offer.sessionId);
        _offerValues.remove(offer.sessionId);
      }
      PrpPlugin.changed();
      return result;
    });
  }

  Future<PrpLesson?> seal(
    PrpOffer offer,
    PrpLesson lesson, {
    required int pauseSeconds,
    required int heldMilliseconds,
    int? emotionBefore,
  }) async {
    if (!offerActive(offer)) return null;
    if (_lessonCrisis(lesson)) {
      await crisisExit(offer);
      return null;
    }
    if (heldMilliseconds < 3000 ||
        (preferences.sessions && pauseSeconds < preferences.pauseSeconds))
      return null;
    final validation = LessonValidator(host).validate(lesson);
    if (!validation.valid || !_safeLesson(lesson)) return null;
    final epoch = _epoch;
    return _serial<PrpLesson?>('seal', null, () async {
      _check(epoch, offer.signal.surface);
      final db = await _db(epoch, offer.signal.surface);
      final result = await db.transaction<PrpLesson?>((txn) async {
        final rows = await txn.query('prp_session',
            where: "id = ? AND outcome = 'open' AND pause_skipped = 0",
            whereArgs: [offer.sessionId]);
        if (rows.isEmpty) return null;
        final existingId = (rows.first['lesson_id'] as num?)?.toInt();
        var sealed = lesson.copyWith(
            id: existingId ?? 0,
            state: 'sealed',
            quality: validation.quality,
            sealedMs: nowMs);
        final map = sealed.toMap()..remove('id');
        if (existingId == null) {
          sealed = sealed.copyWith(id: await txn.insert('prp_lesson', map));
        } else {
          await txn.update('prp_lesson', map,
              where: "id = ? AND state = 'draft'", whereArgs: [existingId]);
        }
        if (sealed.parentId != null) {
          await txn.update('prp_lesson', {'state': 'retired'},
              where: "id = ? AND state = 'sealed'",
              whereArgs: [sealed.parentId]);
        }
        await txn.update(
            'prp_session',
            {
              'lesson_id': sealed.id,
              'step': 'zoom',
              'pause_sec': pauseSeconds,
              'emotion_before': emotionBefore,
              'outcome': 'sealed',
              'ended_ms': nowMs
            },
            where: 'id = ?',
            whereArgs: [offer.sessionId]);
        _check(epoch, offer.signal.surface);
        return sealed;
      });
      if (result != null) {
        _note('sealed',
            detail: 'lesson ${result.id} · quality ${result.quality}/5');
        // The host writes both failure-module records in one idempotent transaction.
        _check(epoch, offer.signal.surface);
        try {
          await host.lessonSealed(result, offer.sessionId);
        } catch (e) {
          _error('host_lesson_sealed', e);
        }
        PrpPlugin.changed();
      }
      return result;
    });
  }

  bool _lessonCrisis(PrpLesson lesson) => [
        lesson.triggerText,
        ...lesson.worked,
        ...lesson.failed,
        lesson.earlySignal,
        lesson.ifCue,
        lesson.thenAction,
        ...lesson.sentences.map((s) => '${s.text}\n${s.revision}')
      ].any((text) {
        final guard = host.guardText(text);
        return guard.crisis || guard.truce;
      });

  Future<void> finishZoom(PrpOffer offer, int emotionAfter) async {
    if (!offerActive(offer)) return;
    final epoch = _epoch;
    await _serial<void>('zoom', null, () async {
      final db = await _db(epoch, offer.signal.surface);
      await db.transaction((txn) async {
        _check(epoch, offer.signal.surface);
        await txn.update(
            'prp_session', {'step': 'done', 'emotion_after': emotionAfter},
            where: "id = ? AND outcome = 'sealed'",
            whereArgs: [offer.sessionId]);
        _check(epoch, offer.signal.surface);
      });
      _offers.remove(offer.sessionId);
      _offerValues.remove(offer.sessionId);
      PrpPlugin.changed();
    });
  }

  Future<void> crisisExit(PrpOffer? offer, {bool crisis = true}) async {
    // This method intentionally does not enter _serial: it can be called by a
    // guarded operation already in the writer queue.
    if (!preferences.enabled) return;
    final until = nowMs + const Duration(hours: 24).inMilliseconds;
    crisisUntilMs = until;
    _offers.clear();
    _offerValues.clear();
    _epoch++;
    PrpPlugin.changed();
    try {
      await host.safetyExit(crisis: crisis);
    } catch (e) {
      _error('host_safety_exit', e);
    }
    final db = await store.openDatabase();
    if (!preferences.enabled) return;
    if (offer != null && await store.exists(db)) {
      await db.transaction((txn) async {
        final rows = await txn.query('prp_session',
            where: 'id = ?', whereArgs: [offer.sessionId]);
        if (rows.isNotEmpty) {
          final lessonId = rows.first['lesson_id'];
          if (lessonId != null)
            await txn.delete('prp_lesson',
                where: "id = ? AND state = 'draft'", whereArgs: [lessonId]);
          await txn.update(
              'prp_session',
              {
                'outcome': 'crisis_exit',
                'step': 'done',
                'lesson_id': null,
                'ended_ms': nowMs
              },
              where: 'id = ?',
              whereArgs: [offer.sessionId]);
        }
      });
    }
    if (!preferences.enabled) return;
    await settings.write('prp.crisis_until_ms', '$until');
    try {
      await host.stopAudio();
    } catch (_) {}
    _note('safety_exit', detail: '暂停提议与回访 24 小时；未保存输入文字');
    PrpPlugin.changed();
  }

  static double similarity(String a, String b) {
    Set<String> grams(String s) {
      final chars = s
          .toLowerCase()
          .replaceAll(RegExp(r'[\s\p{P}]', unicode: true), '')
          .runes
          .toList();
      if (chars.length < 2) return {String.fromCharCodes(chars)};
      return {
        for (var i = 0; i < chars.length - 1; i++)
          String.fromCharCodes(chars.sublist(i, i + 2))
      };
    }

    if (a.trim().isEmpty || b.trim().isEmpty) return 0;
    final x = grams(a), y = grams(b);
    return x.intersection(y).length / x.union(y).length;
  }

  int _match(PrpLesson lesson, PrpContext context) {
    if (context.subjectKey != null &&
        context.subjectKey!.isNotEmpty &&
        lesson.subjectKey == context.subjectKey) return 100;
    if (context.category != null &&
        context.category != '其他' &&
        lesson.category == context.category) return 60;
    final sim =
        similarity('${lesson.triggerText}${lesson.ifCue}', context.text);
    return sim >= .26 ? (sim * 50).round() : 0;
  }

  @override
  Future<List<PrpRecall>> recallFor(PrpContext context) async {
    if (!enabledFor(context.surface) ||
        !preferences.recalls ||
        context.surface == PrpSurface.kindling) return const [];
    final epoch = _epoch;
    return _serial<List<PrpRecall>>('recall', const [], () async {
      if (!await _allowed(epoch, context.surface)) return const [];
      final candidates = (await store.lessons(sealedOnly: true))
          .where((l) => _match(l, context) > 0)
          .toList()
        ..sort((a, b) {
          final score = _match(b, context).compareTo(_match(a, context));
          return score == 0
              ? (b.sealedMs ?? 0).compareTo(a.sealedMs ?? 0)
              : score;
        });
      _check(epoch, context.surface);
      if (candidates.isEmpty) return const [];
      final lesson = candidates.first;
      final db = await _db(epoch, context.surface);
      final ref = context.reference ??
          '${context.subjectKey ?? context.text}:${context.location}:$dayStartMs';
      final id = await db.transaction<int?>((txn) async {
        final same = await txn.query('prp_recall',
            where:
                'lesson_id = ? AND surface = ? AND context = ? AND ref = ? AND ts >= ?',
            whereArgs: [
              lesson.id,
              context.surface.key,
              context.location,
              ref,
              dayStartMs
            ],
            limit: 1);
        if (same.isNotEmpty)
          return same.first['outcome'] == 'pending'
              ? (same.first['id'] as num).toInt()
              : null;
        final count = Sqflite.firstIntValue(await txn.rawQuery(
                'SELECT COUNT(*) FROM prp_recall WHERE ts >= ?',
                [dayStartMs])) ??
            0;
        if (count >= preferences.recallCap) return null;
        final ignored = await txn.query('prp_recall',
            columns: ['id'],
            where: "outcome = 'ignored' AND ts > ?",
            whereArgs: [nowMs - const Duration(hours: 24).inMilliseconds],
            limit: 1);
        if (ignored.isNotEmpty) return null;
        final id = await txn.insert('prp_recall', {
          'lesson_id': lesson.id,
          'ts': nowMs,
          'surface': context.surface.key,
          'subject_key': context.subjectKey,
          'context': context.location,
          'ref': ref
        });
        _check(epoch, context.surface);
        return id;
      });
      if (id == null) return const [];
      _check(epoch, context.surface);
      _note('recall', detail: '${context.surface.key}: lesson ${lesson.id}');
      return [PrpRecall(id: id, lesson: lesson, surface: context.surface)];
    });
  }

  Future<void> _outcome(DatabaseExecutor txn, Map<String, Object?> row,
      PrpOutcome outcome, int epoch) async {
    final surface = PrpSurface.parse('${row['surface']}');
    _check(epoch, surface);
    if (row['outcome'] != 'pending' || outcome == PrpOutcome.pending) return;
    final changed = await txn.update(
        'prp_recall', {'outcome': outcome.name, 'outcome_ms': nowMs},
        where: "id = ? AND outcome = 'pending'", whereArgs: [row['id']]);
    if (changed == 1 &&
        [PrpOutcome.helped, PrpOutcome.repeated].contains(outcome)) {
      final column =
          outcome == PrpOutcome.helped ? 'verified_cnt' : 'repeated_cnt';
      await txn.rawUpdate(
          'UPDATE prp_lesson SET $column = $column + 1 WHERE id = ?',
          [row['lesson_id']]);
    }
    _check(epoch, surface);
  }

  @override
  Future<void> reportOutcome(int recallId, PrpOutcome outcome) async {
    if (!enabled || !preferences.recalls || outcome == PrpOutcome.pending)
      return;
    final epoch = _epoch;
    await _serial<void>('outcome', null, () async {
      final db = await store.openDatabase();
      if (!enabled || !await store.exists(db)) return;
      await db.transaction((txn) async {
        final rows = await txn
            .query('prp_recall', where: 'id = ?', whereArgs: [recallId]);
        if (rows.isNotEmpty &&
            enabledFor(PrpSurface.parse('${rows.first['surface']}')))
          await _outcome(txn, rows.first, outcome, epoch);
      });
      PrpPlugin.changed();
    });
  }

  @override
  Future<void> reportSubjectOutcome(
      PrpContext context, PrpOutcome outcome) async {
    if (!enabledFor(context.surface) ||
        !preferences.recalls ||
        context.subjectKey == null ||
        ![PrpOutcome.helped, PrpOutcome.repeated].contains(outcome)) return;
    final epoch = _epoch;
    await _serial<void>('subject_outcome', null, () async {
      final db = await store.openDatabase();
      if (!await store.exists(db)) return;
      await db.transaction((txn) async {
        final rows = await txn.query('prp_recall',
            where:
                "surface = ? AND subject_key = ? AND outcome = 'pending' AND context != 'quote_home' AND ts <= ?",
            whereArgs: [
              context.surface.key,
              context.subjectKey,
              context.occurredMs ?? nowMs
            ],
            orderBy: 'ts DESC, id DESC',
            limit: 1);
        if (rows.isNotEmpty) await _outcome(txn, rows.first, outcome, epoch);
      });
      PrpPlugin.changed();
    });
  }

  @override
  Future<void> linkAttempt(PrpContext context) async {
    if (!enabledFor(context.surface) ||
        context.subjectKey == null ||
        context.text.isEmpty) return;
    final epoch = _epoch;
    await _serial<void>('link_attempt', null, () async {
      final db = await store.openDatabase();
      if (!await store.exists(db)) return;
      await db.transaction((txn) async {
        final rows = await txn.rawQuery(
            "SELECT r.id, l.trigger_text, l.if_cue FROM prp_recall r JOIN prp_lesson l ON l.id = r.lesson_id "
            "WHERE r.surface = ? AND r.context = 'new_commitment' AND r.subject_key IS NULL "
            "AND r.outcome = 'pending' AND r.ts >= ? AND r.ts <= ? ORDER BY r.ts DESC, r.id DESC",
            [context.surface.key, dayStartMs, nowMs]);
        for (final row in rows) {
          final score = similarity('${row['trigger_text']}', context.text);
          final cueScore = similarity('${row['if_cue']}', context.text);
          if (score < .26 && cueScore < .26) continue;
          _check(epoch, context.surface);
          await txn.update('prp_recall', {'subject_key': context.subjectKey},
              where: 'id = ?', whereArgs: [row['id']]);
          break;
        }
        _check(epoch, context.surface);
      });
    });
  }

  Future<PrpOffer?> resumeLesson(PrpLesson lesson,
      {bool rewrite = false}) async {
    if (!enabledFor(lesson.source) || (lesson.state != 'draft' && !rewrite))
      return null;
    final epoch = _epoch;
    return _serial<PrpOffer?>('resume', null, () async {
      if (!await _allowed(epoch, lesson.source)) return null;
      final db = await _db(epoch, lesson.source);
      final id = await db.transaction<int>((txn) async {
        final id = await txn.insert('prp_session', {
          'surface': lesson.source.key, 'trigger_kind': 'manual',
          'trigger_ref': 'edit:${lesson.id}:$nowMs',
          'subject_key': lesson.subjectKey,
          'expected': lesson.triggerText, 'started_ms': nowMs,
          'counts_offer': 0,
          // Continuing an unsealed draft may skip the pause, but cannot seal it
          // until a new full pause has actually been completed.
          'step': preferences.sessions ? 'pause' : 'ledger',
          if (!rewrite) 'lesson_id': lesson.id,
        });
        _check(epoch, lesson.source);
        return id;
      });
      final offer = PrpOffer(
          sessionId: id,
          signal: PrpSignal(
              surface: lesson.source,
              kind: 'manual',
              subjectKey: lesson.subjectKey,
              expected: lesson.triggerText,
              tsMs: nowMs,
              reference: 'edit:${lesson.id}:$nowMs',
              category: lesson.category));
      _offers[id] = epoch;
      _offerValues[id] = offer;
      _evidence[id] = lesson.evidence;
      initialLessons[id] = lesson;
      try {
        await host.sessionStarted();
      } catch (e) {
        _error('session_started', e);
      }
      return offer;
    });
  }

  @override
  Future<List<String>> workedItems() async {
    if (!enabledFor(PrpSurface.kindling)) return const [];
    return _serial<List<String>>('worked_items', const [], () async {
      final epoch = _epoch;
      final items = (await store.lessons(sealedOnly: true))
          .expand((l) => l.worked)
          .toSet()
          .take(8)
          .toList();
      _check(epoch, PrpSurface.kindling);
      return items;
    });
  }

  @override
  Future<List<PrpQuote>> quotesForStream() async {
    if (!enabledFor(PrpSurface.quoteHome) ||
        !preferences.quoteStream ||
        !preferences.recalls) return const [];
    final epoch = _epoch;
    return _serial<List<PrpQuote>>('quote_stream', const [], () async {
      if (!await _allowed(epoch, PrpSurface.quoteHome)) return const [];
      final lessons = (await store.lessons(sealedOnly: true))
          .where((l) => l.quoteAllowed)
          .toList();
      if (lessons.isEmpty) return const [];
      final author = await host.authorName();
      _check(epoch, PrpSurface.quoteHome);
      final db = await _db(epoch, PrpSurface.quoteHome);
      final lesson = lessons.first;
      final allowed = await db.transaction<bool>((txn) async {
        final count = Sqflite.firstIntValue(await txn.rawQuery(
                'SELECT COUNT(*) FROM prp_recall WHERE ts >= ?',
                [dayStartMs])) ??
            0;
        final recent = await txn.query('prp_recall',
            columns: ['id'],
            where: "context = 'quote_home' AND ts > ?",
            whereArgs: [nowMs - const Duration(hours: 24).inMilliseconds],
            limit: 1);
        final ignored = await txn.query('prp_recall',
            columns: ['id'],
            where: "outcome = 'ignored' AND ts > ?",
            whereArgs: [nowMs - const Duration(hours: 24).inMilliseconds],
            limit: 1);
        if (count >= preferences.recallCap ||
            recent.isNotEmpty ||
            ignored.isNotEmpty) return false;
        await txn.insert('prp_recall', {
          'lesson_id': lesson.id,
          'ts': nowMs,
          'surface': PrpSurface.quoteHome.key,
          'subject_key': lesson.subjectKey,
          'context': 'quote_home',
          'ref': '$dayStartMs'
        });
        _check(epoch, PrpSurface.quoteHome);
        return true;
      });
      return allowed
          ? [PrpQuote(lessonId: lesson.id, text: lesson.rule, author: author)]
          : const [];
    });
  }

  @override
  Future<List<Map<String, dynamic>>> evidenceRows(int sinceMs) async {
    if (!enabledFor(PrpSurface.enemy)) return const [];
    return _serial<List<Map<String, dynamic>>>('evidence_rows', const [],
        () async {
      final lessons = await store.lessons(sealedOnly: true);
      if (!enabledFor(PrpSurface.enemy)) return const [];
      return lessons
          .where((l) =>
              (l.sealedMs ?? 0) >= sinceMs ||
              l.verifiedCount + l.repeatedCount > 0)
          .map((l) => <String, dynamic>{
                'id': l.id,
                'ts': l.sealedMs ?? l.createdMs,
                // Enemy evidence can be cached and sent to its own AI. Keep
                // reflection text inside PRP's separately consented flow.
                'label': '完成了一次 PRP 盖印',
                'verified': l.verifiedCount,
                'repeated': l.repeatedCount,
              })
          .toList();
    });
  }

  @override
  Future<void> importReviewDrafts(List<Map<String, dynamic>> details,
      {required int reviewMs}) async {
    if (!enabledFor(PrpSurface.behavior)) return;
    final epoch = _epoch;
    await _serial<void>('review_drafts', null, () async {
      if (!await _allowed(epoch, PrpSurface.behavior)) return;
      final db = await _db(epoch, PrpSurface.behavior);
      await db.transaction((txn) async {
        for (final detail in details) {
          if (detail['status'] != 'missed' || detail['presetId'] == null)
            continue;
          final reason = '${detail['missedReason'] ?? ''}'.trim();
          final expected = '${detail['presetName'] ?? ''}'.trim();
          final guard = host.guardText('$expected\n$reason');
          if (!guard.allowed ||
              reason.isEmpty ||
              LessonValidator(host).identityJudgment(reason)) continue;
          final ref = 'review:${detail['presetId']}:$reviewMs';
          final exists = await txn.query('prp_session',
              columns: ['id', 'lesson_id'],
              where: "trigger_kind = 'daily_review_draft' AND trigger_ref = ?",
              whereArgs: [ref],
              limit: 1);
          final subject = 'habit:preset:${detail['presetId']}';
          var lesson = PrpLesson(
              subjectKey: subject,
              source: PrpSurface.behavior,
              createdMs: nowMs,
              triggerText: expected,
              failed: [
                reason
              ],
              evidence: [
                PrpEvidence(
                    source: 'behavior',
                    id: 'preset:${detail['presetId']}:$reviewMs',
                    label: '用户在每日复盘中明确标记未完成',
                    kind: 'self_report'),
              ]);
          lesson = _reviewCandidate(detail, lesson);
          if (!_safeLesson(lesson)) continue;
          if (exists.isNotEmpty) {
            final oldRows = await txn.query('prp_lesson',
                where: "id = ? AND state = 'draft'",
                whereArgs: [exists.first['lesson_id']]);
            if (oldRows.isNotEmpty &&
                aiAllowed &&
                detail['prp_candidate'] is Map) {
              final old = PrpLesson.fromMap(oldRows.first);
              if (old.worked.isEmpty &&
                  old.earlySignal.isEmpty &&
                  old.ifCue.isEmpty &&
                  old.thenAction.isEmpty &&
                  old.failed.length == 1 &&
                  old.failed.single == reason) {
                final values = lesson.toMap()..remove('id');
                await txn.update('prp_lesson', values,
                    where: 'id = ?', whereArgs: [old.id]);
              }
            }
            continue;
          }
          final id = await txn.insert('prp_lesson', lesson.toMap());
          await txn.insert('prp_session', {
            'surface': 'behavior',
            'trigger_kind': 'daily_review_draft',
            'trigger_ref': ref,
            'subject_key': subject,
            'expected': expected,
            'started_ms': nowMs,
            'step': 'columns',
            'lesson_id': id,
            'ended_ms': nowMs,
            'outcome': 'skipped',
            'counts_offer': 0
          });
        }
        _check(epoch, PrpSurface.behavior);
      });
      PrpPlugin.changed();
    });
  }

  PrpLesson _reviewCandidate(Map<String, dynamic> detail, PrpLesson original) {
    final candidate = detail['prp_candidate'];
    if (!aiAllowed || candidate is! Map) return original;
    try {
      final worked = (candidate['worked'] as List? ?? []).cast<String>();
      final failed =
          (candidate['failed'] as List? ?? original.failed).cast<String>();
      final early = (candidate['early_signal'] ?? '') as String;
      final cue = (candidate['if_cue'] ?? '') as String;
      final action = (candidate['then_action'] ?? '') as String;
      if (worked.length > 10 || failed.length > 10 || action.runes.length > 40)
        return original;
      final allowed = [
        original.triggerText,
        '${detail['missedReason'] ?? ''}',
        '${detail['notes'] ?? ''}'
      ];
      if ([...worked, ...failed, early, cue, action]
          .where((s) => s.isNotEmpty)
          .any((s) => !allowed.any((source) => source.contains(s))))
        return original;
      final lesson = PrpLesson(
          subjectKey: original.subjectKey,
          source: original.source,
          createdMs: original.createdMs,
          category: LessonValidator.categories.contains(candidate['category'])
              ? candidate['category'] as String
              : '其他',
          triggerText: original.triggerText,
          worked: worked,
          failed: failed,
          earlySignal: early,
          ifCue: cue,
          thenAction: action,
          evidence: original.evidence);
      return _safeLesson(lesson)
          ? lesson.copyWith(
              quality: LessonValidator(host).validate(lesson).quality)
          : original;
    } catch (_) {
      return original;
    }
  }

  Future<void> setQuoteAllowed(PrpLesson lesson, bool allowed) async {
    if (!enabledFor(lesson.source)) return;
    final epoch = _epoch;
    await _serial<void>('quote_consent', null, () async {
      final db = await _db(epoch, lesson.source);
      await db.transaction((txn) async {
        _check(epoch, lesson.source);
        await txn.update('prp_lesson', {'quote_allowed': allowed ? 1 : 0},
            where: "id = ? AND state = 'sealed'", whereArgs: [lesson.id]);
        _check(epoch, lesson.source);
      });
      PrpPlugin.changed();
    });
  }

  Future<bool> saveVoicePath(PrpLesson lesson, String path) async {
    if (!enabledFor(lesson.source) || !preferences.voice) return false;
    final epoch = _epoch;
    return _serial<bool>('voice_path', false, () async {
      final db = await _db(epoch, lesson.source);
      final saved = await db.transaction<bool>((txn) async {
        _check(epoch, lesson.source);
        final changed = await txn.update('prp_lesson', {'voice_path': path},
            where: "id = ? AND state = 'sealed'", whereArgs: [lesson.id]);
        _check(epoch, lesson.source);
        return changed == 1;
      });
      if (saved && lesson.voicePath.isNotEmpty && lesson.voicePath != path) {
        try {
          await host.deleteRecordings([lesson.voicePath]);
        } catch (_) {
          _note('audio_cleanup_pending');
        }
      }
      PrpPlugin.changed();
      return saved;
    });
  }

  Future<String> exportData() async {
    await initialize();
    await _tail;
    final db = await store.openDatabase();
    final tables = <String, dynamic>{};
    if (await store.exists(db)) {
      for (final name in ['prp_lesson', 'prp_session', 'prp_recall']) {
        tables[name] = await db.query(name);
      }
    }
    return const JsonEncoder.withIndent('  ').convert({
      'schema': 'prp_plugin_v1',
      'exported_ms': nowMs,
      'preferences': preferences.toJson(),
      'tables': tables
    });
  }

  Future<void> clearData() async {
    await initialize();
    _epoch++;
    _offers.clear();
    _presented.clear();
    _offerValues.clear();
    _evidence.clear();
    initialLessons.clear();
    await _tail;
    await host.stopAudio();
    final db = await store.openDatabase();
    if (!await store.exists(db)) return;
    final paths = (await db.query('prp_lesson', columns: ['voice_path']))
        .map((r) => '${r['voice_path'] ?? ''}')
        .where((p) => p.isNotEmpty)
        .toList();
    await db.transaction((txn) async {
      for (final name in ['prp_recall', 'prp_session', 'prp_lesson']) {
        await txn.delete(name);
      }
    });
    await host.deleteRecordings(paths, all: true);
    _note('data_cleared');
    PrpPlugin.changed();
  }

  Widget _slot(PrpSurface surface, Widget Function() build) {
    if (!enabledFor(surface)) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
        valueListenable: PrpPlugin.changes,
        builder: (_, __, ___) =>
            enabledFor(surface) ? build() : const SizedBox.shrink());
  }

  @override
  Widget sessionCard(PrpOffer offer, {VoidCallback? onFinished}) => _slot(
      offer.signal.surface,
      () => offerActive(offer)
          ? PrpSessionCard(
              key: ValueKey('prp_session_${offer.sessionId}_$_epoch'),
              runtime: this,
              onFinished: onFinished,
              offer: offer)
          : const SizedBox.shrink());
  @override
  Widget recallChip(PrpContext context) => _slot(
      context.surface,
      () => preferences.recalls
          ? PrpRecallChip(runtime: this, contextValue: context)
          : const SizedBox.shrink());
  @override
  Widget playbook({bool management = false}) => management
      ? PrpPlaybook(runtime: this, management: true)
      : _slot(PrpSurface.enemy, () => PrpPlaybook(runtime: this));
  @override
  Widget settingsPage() => PrpSettingsPage(runtime: this);
}
