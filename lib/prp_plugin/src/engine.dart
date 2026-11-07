import 'dart:math';

import 'governance.dart';
import 'host.dart';
import 'lesson_validator.dart';
import 'models.dart';
import 'settings.dart';
import 'store.dart';

class SealResult {
  const SealResult({required this.ok, required this.check, this.lesson});

  final bool ok;
  final LessonCheck check;
  final PrpLesson? lesson;
}

class _Scored {
  const _Scored(this.lesson, this.score);

  final PrpLesson lesson;
  final double score;
}

/// 插件的核心逻辑：会话、教训、回访、验证、“自己的名言”。
/// 纯 Dart：只依赖 [PrpStore]、[PrpHost]、[PrpSettings]，方便单元测试。
class PrpEngine {
  PrpEngine({
    required this.store,
    required this.host,
    required this.settings,
    PrpGovernor? governor,
    Random? random,
  }) : governor =
           governor ??
           PrpGovernor(store: store, host: host, settings: settings),
       _random = random ?? Random();

  final PrpStore store;
  final PrpHost host;
  final PrpSettings settings;
  final PrpGovernor governor;
  final Random _random;

  late final LessonValidator validator = LessonValidator(host.guardText);

  /// 相似度阈值：低于它不回访。
  static const double matchThreshold = 0.34;
  static const int quoteSpacingMs = 24 * 3600 * 1000;
  static const int maxEvidence = 8;

  // ───────────────────────── 会话 ─────────────────────────

  Future<PrpOffer?> createSession(PrpSignal s) async {
    final int now = host.nowMs();
    if (!await governor.allowOffer(s, now)) return null;
    PrpLesson? prefill;
    if (s.rewriteOf != null) prefill = await store.lesson(s.rewriteOf!);
    final int id = await store.insertSession(
      PrpSession(
        surface: s.surface,
        triggerKind: s.kind,
        triggerRef: s.subjectKey,
        startedMs: now,
      ),
    );
    return PrpOffer(
      sessionId: id,
      surface: s.surface,
      voice: s.surface.voice,
      signal: s,
      prefill: prefill,
    );
  }

  Future<void> setStep(
    int sessionId,
    PrpStep step, {
    int? pauseSec,
    int? emotionBefore,
  }) async {
    final PrpSession? s = await store.session(sessionId);
    if (s == null) return;
    await store.updateSession(
      s.copyWith(step: step, pauseSec: pauseSec, emotionBefore: emotionBefore),
    );
  }

  Future<void> finish(
    int sessionId, {
    int? emotionAfter,
    required String outcome,
  }) async {
    final PrpSession? s = await store.session(sessionId);
    if (s == null) return;
    await store.updateSession(
      s.copyWith(
        step: PrpStep.done,
        emotionAfter: emotionAfter,
        endedMs: host.nowMs(),
        outcome: outcome,
      ),
    );
  }

  Future<void> crisisExit(int sessionId) =>
      finish(sessionId, outcome: 'crisis_exit');

  // ───────────────────────── 教训：草稿与盖印 ─────────────────────────

  List<String> evidenceOf(PrpSignal sig, List<String> userFacts) {
    final List<String> out = <String>[];
    for (final String raw in <String>[...sig.facts, ...userFacts]) {
      String t = raw.trim();
      if (t.isEmpty) continue;
      if (t.length > 80) t = t.substring(0, 80);
      if (!out.contains(t)) out.add(t);
      if (out.length >= maxEvidence) break;
    }
    return out;
  }

  PrpLesson _build({
    required PrpSignal sig,
    required LessonDraft d,
    required PrpLessonState state,
    required int quality,
    required List<String> evidence,
    required int createdMs,
    int? id,
    int? parentId,
    int? sealedMs,
    int verifiedCnt = 0,
    int repeatedCnt = 0,
  }) {
    List<String> clean(List<String> xs) => xs
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
    return PrpLesson(
      id: id,
      subjectKey: sig.subjectKey,
      subjectText: sig.expected.trim(),
      category: d.category.isNotEmpty ? d.category : (sig.category ?? ''),
      source: sig.surface == PrpSurface.enemy ? 'enemy' : sig.surface.key,
      state: state,
      worked: clean(d.worked),
      failed: clean(d.failed),
      triggerText: d.triggerText.trim(),
      earlySignal: d.earlySignal.trim(),
      ifCue: d.ifCue.trim(),
      thenAction: d.thenAction.trim(),
      evidenceRefs: evidence,
      quality: quality,
      createdMs: createdMs,
      sealedMs: sealedMs,
      parentId: parentId,
      verifiedCnt: verifiedCnt,
      repeatedCnt: repeatedCnt,
    );
  }

  Future<PrpLesson?> _existingFor(int sessionId) async {
    final PrpSession? s = await store.session(sessionId);
    final int? lid = s?.lessonId;
    if (lid == null) return null;
    return store.lesson(lid);
  }

  Future<void> _link(int sessionId, int lessonId) async {
    final PrpSession? s = await store.session(sessionId);
    if (s == null) return;
    await store.updateSession(s.copyWith(lessonId: lessonId));
  }

  /// 保存草稿。含危机或身份判断的文字不落库。
  Future<PrpLesson?> saveDraft(
    int sessionId,
    PrpSignal sig,
    LessonDraft d, {
    List<String> userFacts = const <String>[],
    int? parentId,
  }) async {
    if (d.isEmpty) return null;
    final List<String> evidence = evidenceOf(sig, userFacts);
    final LessonCheck check = validator.check(
      d,
      hasEvidence: evidence.isNotEmpty,
    );
    if (check.hasCrisis || check.problems.contains('identity')) return null;
    final PrpLesson? existing = await _existingFor(sessionId);
    final int now = host.nowMs();
    final PrpLesson built = _build(
      sig: sig,
      d: d,
      state: PrpLessonState.draft,
      quality: check.quality,
      evidence: evidence,
      createdMs: existing?.createdMs ?? now,
      id: existing?.id,
      parentId: parentId ?? existing?.parentId,
    );
    if (existing?.id == null) {
      final int id = await store.insertLesson(built);
      await _link(sessionId, id);
      return built.copyWith(id: id);
    }
    await store.updateLesson(built);
    return built;
  }

  /// 盖印：必须通过校验。成功后把旧版本（改写时）标为 retired，并镜像到宿主。
  Future<SealResult> seal(
    int sessionId,
    PrpSignal sig,
    LessonDraft d, {
    List<String> userFacts = const <String>[],
    int? parentId,
  }) async {
    final List<String> evidence = evidenceOf(sig, userFacts);
    final LessonCheck check = validator.check(
      d,
      hasEvidence: evidence.isNotEmpty,
    );
    if (!check.canSeal) return SealResult(ok: false, check: check);

    final PrpLesson? existing = await _existingFor(sessionId);
    final int now = host.nowMs();
    final PrpLesson built = _build(
      sig: sig,
      d: d,
      state: PrpLessonState.sealed,
      quality: check.quality,
      evidence: evidence,
      createdMs: existing?.createdMs ?? now,
      id: existing?.id,
      parentId: parentId ?? existing?.parentId,
      sealedMs: now,
    );
    PrpLesson saved = built;
    if (existing?.id == null) {
      final int id = await store.insertLesson(built);
      saved = built.copyWith(id: id);
      await _link(sessionId, id);
    } else {
      await store.updateLesson(built);
    }
    final int? pid = saved.parentId;
    if (pid != null) {
      final PrpLesson? parent = await store.lesson(pid);
      if (parent != null && parent.state != PrpLessonState.retired) {
        await store.updateLesson(
          parent.copyWith(state: PrpLessonState.retired),
        );
      }
    }
    try {
      await host.mirrorLesson(saved);
    } catch (_) {
      // 镜像是尽力而为，失败不影响盖印。
    }
    return SealResult(ok: true, check: check, lesson: saved);
  }

  /// 给已有的草稿补盖印（手册里的“盖印”按钮）。
  Future<SealResult> sealExisting(int lessonId) async {
    final PrpLesson? l = await store.lesson(lessonId);
    const LessonCheck none = LessonCheck(
      canSeal: false,
      problems: <String>[],
      missing: <String>['lesson'],
      quality: 0,
    );
    if (l == null || l.state != PrpLessonState.draft) {
      return const SealResult(ok: false, check: none);
    }
    final LessonCheck check = validator.check(
      LessonDraft.fromLesson(l),
      hasEvidence: l.evidenceRefs.isNotEmpty,
    );
    if (!check.canSeal) return SealResult(ok: false, check: check);
    final PrpLesson saved = l.copyWith(
      state: PrpLessonState.sealed,
      quality: check.quality,
      sealedMs: host.nowMs(),
    );
    await store.updateLesson(saved);
    final int? pid = saved.parentId;
    if (pid != null) {
      final PrpLesson? parent = await store.lesson(pid);
      if (parent != null && parent.state != PrpLessonState.retired) {
        await store.updateLesson(
          parent.copyWith(state: PrpLessonState.retired),
        );
      }
    }
    try {
      await host.mirrorLesson(saved);
    } catch (_) {}
    return SealResult(ok: true, check: check, lesson: saved);
  }

  // ───────────────────────── 回访 ─────────────────────────

  /// 比较前先去掉数字和“每天、分钟、完成”这类套话，免得“每天跑步 20 分钟”和“每天晨读 20 分钟”被当成同一件事。
  static const List<String> _fillers = <String>[
    '每天',
    '每日',
    '每周',
    '每次',
    '今天',
    '明天',
    '昨天',
    '一下',
    '一个',
    '一次',
    '分钟',
    '小时',
    '完成',
    '开始',
    '继续',
    '坚持',
    '争取',
    '尽量',
    '一定',
    '半',
    '个',
    '次',
    '的',
    '了',
    '在',
    '把',
    '要',
    '去',
    '做',
    '先',
    '再',
    '并',
    '和',
    '与',
    '及',
  ];

  static String _normalize(String s) {
    String t = s.replaceAll(RegExp(r'[0-9０-９]+'), '');
    for (final String f in _fillers) {
      t = t.replaceAll(f, '');
    }
    return t.replaceAll(RegExp(r'[\s，。！？、；：,.!?;:“”"\u0027（）()\[\]【】]+'), '');
  }

  /// 两段文字的相似度：去套话后字二元组的 Jaccard。有效长度不足 2 个字返回 0。
  static double similarity(String a, String b) {
    Set<String> grams(String s) {
      final String t = _normalize(s);
      final Set<String> out = <String>{};
      for (int i = 0; i + 1 < t.length; i++) {
        out.add(t.substring(i, i + 2));
      }
      return out;
    }

    final Set<String> ga = grams(a);
    final Set<String> gb = grams(b);
    if (ga.isEmpty || gb.isEmpty) return 0;
    final int inter = ga.intersection(gb).length;
    final int union = ga.length + gb.length - inter;
    return union == 0 ? 0 : inter / union;
  }

  double scoreOf(PrpLesson l, PrpContext c) {
    double best = 0;
    if (c.subjectKey != null &&
        c.subjectKey!.isNotEmpty &&
        l.subjectKey == c.subjectKey) {
      best = 1;
    }
    if (c.category != null &&
        c.category!.isNotEmpty &&
        l.category == c.category) {
      best = max(best, 0.6);
    }
    final String text = (c.text ?? '').trim();
    if (text.isNotEmpty) {
      if (l.subjectText.isNotEmpty)
        best = max(best, similarity(text, l.subjectText));
      final String hay = <String>[
        l.triggerText,
        l.thenAction,
        ...l.worked,
        ...l.failed,
      ].where((String s) => s.trim().isNotEmpty).join(' ');
      if (hay.isNotEmpty) best = max(best, similarity(text, hay));
    }
    return best;
  }

  /// 只看有没有相关教训，不写任何数据、不受预算限制。
  Future<List<PrpRecallHit>> peekMatches(PrpContext c, {int limit = 1}) async {
    final List<PrpLesson> sealed = await store.lessons(
      state: PrpLessonState.sealed,
    );
    final List<PrpLesson> retired = await store.lessons(
      state: PrpLessonState.retired,
    );
    final List<_Scored> scored =
        sealed
            .map((PrpLesson l) => _Scored(l, scoreOf(l, c)))
            .where((_Scored s) => s.score >= matchThreshold)
            .toList()
          ..sort((_Scored a, _Scored b) => b.score.compareTo(a.score));
    if (scored.isEmpty) return const <PrpRecallHit>[];
    final int similar =
        scored.length +
        retired.where((PrpLesson l) => scoreOf(l, c) >= matchThreshold).length;
    return scored
        .take(limit)
        .map(
          (_Scored s) =>
              PrpRecallHit(lesson: s.lesson, score: s.score, nth: similar + 1),
        )
        .toList();
  }

  /// 受治理限制的提示（用于“新建字据”时显示的小卡片）：不写数据。
  Future<List<PrpRecallHit>> hintFor(PrpContext c, {int limit = 1}) async {
    if (!await governor.allowRecall(c, host.nowMs()))
      return const <PrpRecallHit>[];
    return peekMatches(c, limit: limit);
  }

  /// 回访并记录。记录的 ref 用于之后验证（做到了 / 又没做到）。
  Future<List<PrpRecallHit>> recallFor(PrpContext c, {int limit = 1}) async {
    final int now = host.nowMs();
    if (!await governor.allowRecall(c, now)) return const <PrpRecallHit>[];
    final List<PrpRecallHit> hits = await peekMatches(c, limit: limit);
    if (hits.isEmpty) return hits;
    final bool informational =
        c.kind == 'repeat_detected' || c.kind == 'playbook';
    final List<PrpRecallHit> out = <PrpRecallHit>[];
    for (final PrpRecallHit h in hits) {
      final int rid = await store.insertRecall(
        PrpRecall(
          lessonId: h.lesson.id!,
          ts: now,
          context: c.kind,
          ref: informational ? '' : (c.subjectKey ?? ''),
          outcome: informational ? PrpOutcome.ignored : PrpOutcome.pending,
        ),
      );
      out.add(
        PrpRecallHit(
          lesson: h.lesson,
          score: h.score,
          nth: h.nth,
          recallId: rid,
        ),
      );
    }
    return out;
  }

  /// 把仍在等待结果的回访，按宿主给出的结果记账。没有结果的保持“未验证”。
  Future<int> reconcile() async {
    final List<PrpRecall> pending = await store.recalls(
      outcome: PrpOutcome.pending,
    );
    int changed = 0;
    for (final PrpRecall r in pending) {
      final int? id = r.id;
      if (id == null || r.ref.isEmpty) continue;
      final String? st = await host.resolveRef(r.ref);
      if (st == 'done') {
        await store.updateRecallOutcome(id, PrpOutcome.helped);
        await store.bumpLessonCounters(r.lessonId, verified: 1);
        changed++;
      } else if (st == 'missed') {
        await store.updateRecallOutcome(id, PrpOutcome.repeated);
        await store.bumpLessonCounters(r.lessonId, repeated: 1);
        changed++;
      }
    }
    return changed;
  }

  /// 手动记账（例如用户在回访卡上点“没用上”）。
  Future<void> reportOutcome(int recallId, PrpOutcome outcome) async {
    final PrpRecall? r = await store.recall(recallId);
    if (r == null || r.outcome == outcome) return;
    await store.updateRecallOutcome(recallId, outcome);
    if (r.outcome == PrpOutcome.pending) {
      if (outcome == PrpOutcome.helped) {
        await store.bumpLessonCounters(r.lessonId, verified: 1);
      } else if (outcome == PrpOutcome.repeated) {
        await store.bumpLessonCounters(r.lessonId, repeated: 1);
      }
    }
  }

  // ───────────────────────── 自己的名言 ─────────────────────────

  static String quoteContentOf(PrpLesson l) =>
      '如果${l.ifCue.trim()}，我就${l.thenAction.trim()}。';

  /// 运行时给首页一条“自己的名言”：至少隔 24 小时，随机挑一条已盖印且有“如果—那么”的教训。
  /// 不写入 quotes 表。
  Future<Map<String, dynamic>?> ownQuoteRow({String? excludeContent}) async {
    final int now = host.nowMs();
    final int last = await settings.quoteLastMs();
    if (now - last < quoteSpacingMs) return null;
    final List<PrpLesson> sealed = await store.lessons(
      state: PrpLessonState.sealed,
      limit: 100,
    );
    final String skip = (excludeContent ?? '').trim();
    final List<PrpLesson> candidates = sealed
        .where((PrpLesson l) => l.hasIfThen && quoteContentOf(l) != skip)
        .toList();
    if (candidates.isEmpty) return null;
    final PrpLesson l = candidates[_random.nextInt(candidates.length)];
    await settings.setQuoteLastMs(now);
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(
      l.sealedMs ?? l.createdMs,
    );
    String two(int v) => v.toString().padLeft(2, '0');
    return <String, dynamic>{
      'content': quoteContentOf(l),
      'theme': '我的教训',
      'author': '',
      'author_name': '',
      'source_from': '我自己 · 盖印于 ${d.year}-${two(d.month)}-${two(d.day)}',
      'explanation': l.summaryLine(),
      'quote_uid': 'prp_lesson_${l.id}',
    };
  }

  // ───────────────────────── 统计 ─────────────────────────

  Future<({int sessions, int sealed, int drafts, int recalls})> stats() async {
    return (
      sessions: await store.sessionCount(),
      sealed: await store.lessonCount(PrpLessonState.sealed),
      drafts: await store.lessonCount(PrpLessonState.draft),
      recalls: await store.recallCount(),
    );
  }
}
