import 'engine.dart';
import 'governance.dart';
import 'host.dart';
import 'lesson_validator.dart';
import 'models.dart';
import 'settings.dart';
import 'store.dart';

class PrpPlaybookData {
  const PrpPlaybookData({required this.sealed, required this.drafts});

  final List<PrpLesson> sealed;
  final List<PrpLesson> drafts;

  static const PrpPlaybookData empty = PrpPlaybookData(
    sealed: <PrpLesson>[],
    drafts: <PrpLesson>[],
  );
}

/// 门控层：总开关、分功能开关、熔断、诊断日志。
/// 关闭（或熔断）时：不碰存储、不写任何数据、对外返回 null / 空。
class PrpCore {
  PrpCore({
    required this.store,
    required this.host,
    required this.settings,
    PrpBreaker? breaker,
    PrpEngine? engine,
  }) : breaker = breaker ?? PrpBreaker(),
       engine =
           engine ?? PrpEngine(store: store, host: host, settings: settings);

  final PrpStore store;
  final PrpHost host;
  final PrpSettings settings;
  final PrpBreaker breaker;
  final PrpEngine engine;

  // ───────────────────────── 开关 ─────────────────────────

  Future<bool> isEnabled() async {
    if (breaker.tripped) return false;
    try {
      return await settings.enabled();
    } catch (e) {
      breaker.failure('settings', e);
      return false;
    }
  }

  Future<bool> enabledFor(PrpSurface s) async {
    if (!await isEnabled()) return false;
    try {
      return await settings.surfaceEnabled(s);
    } catch (e) {
      breaker.failure('settings', e);
      return false;
    }
  }

  Future<T?> _run<T>(String name, Future<T?> Function() body) async {
    if (breaker.tripped) return null;
    try {
      final T? r = await body();
      breaker.success();
      return r;
    } catch (e) {
      breaker.failure(name, e);
      return null;
    }
  }

  // ───────────────────────── 模块 → 插件 ─────────────────────────

  Future<PrpOffer?> signal(PrpSignal s) => _run<PrpOffer>('signal', () async {
    if (!await enabledFor(s.surface)) return null;
    final PrpOffer? o = await engine.createSession(s);
    breaker.note(
      '信号 ${s.kind} ${s.subjectKey} → ${o == null ? '未提议' : '会话 #${o.sessionId}'}',
    );
    return o;
  });

  /// 回访：记录并返回命中的教训（受每日预算限制，用户主动查看除外）。
  Future<List<PrpRecallHit>> recallFor(PrpContext c) async {
    final List<PrpRecallHit>? r = await _run<List<PrpRecallHit>>(
      'recall',
      () async {
        if (!await enabledFor(c.surface)) return null;
        await engine.reconcile();
        return engine.recallFor(c);
      },
    );
    return r ?? const <PrpRecallHit>[];
  }

  /// 只提示、不记录（用于输入框旁的小卡片）。
  Future<List<PrpRecallHit>> hintFor(PrpContext c) async {
    final List<PrpRecallHit>? r = await _run<List<PrpRecallHit>>(
      'hint',
      () async {
        if (!await enabledFor(c.surface)) return null;
        return engine.hintFor(c);
      },
    );
    return r ?? const <PrpRecallHit>[];
  }

  Future<void> reportOutcome(int recallId, PrpOutcome o) async {
    await _run<bool>('outcome', () async {
      await engine.reportOutcome(recallId, o);
      return true;
    });
  }

  Future<Map<String, dynamic>?> ownQuoteRow({String? excludeContent}) =>
      _run<Map<String, dynamic>>('quote', () async {
        if (!await enabledFor(PrpSurface.quoteHome)) return null;
        return engine.ownQuoteRow(excludeContent: excludeContent);
      });

  // ───────────────────────── 会话进行中的操作 ─────────────────────────
  // 会话一旦开始，即使中途关闭插件也允许用户走完这一次；熔断后不再写入。

  Future<void> setStep(
    int sessionId,
    PrpStep step, {
    int? pauseSec,
    int? emotionBefore,
  }) async {
    await _run<bool>('step', () async {
      await engine.setStep(
        sessionId,
        step,
        pauseSec: pauseSec,
        emotionBefore: emotionBefore,
      );
      return true;
    });
  }

  Future<PrpLesson?> saveDraft(
    int sessionId,
    PrpSignal sig,
    LessonDraft d, {
    List<String> userFacts = const <String>[],
    int? parentId,
  }) => _run<PrpLesson>(
    'draft',
    () => engine.saveDraft(
      sessionId,
      sig,
      d,
      userFacts: userFacts,
      parentId: parentId,
    ),
  );

  Future<SealResult?> seal(
    int sessionId,
    PrpSignal sig,
    LessonDraft d, {
    List<String> userFacts = const <String>[],
    int? parentId,
  }) => _run<SealResult>(
    'seal',
    () => engine.seal(
      sessionId,
      sig,
      d,
      userFacts: userFacts,
      parentId: parentId,
    ),
  );

  Future<SealResult?> sealExisting(int lessonId) =>
      _run<SealResult>('seal_existing', () => engine.sealExisting(lessonId));

  Future<void> finish(
    int sessionId, {
    int? emotionAfter,
    required String outcome,
  }) async {
    await _run<bool>('finish', () async {
      await engine.finish(
        sessionId,
        emotionAfter: emotionAfter,
        outcome: outcome,
      );
      return true;
    });
  }

  Future<void> crisisExit(int sessionId) async {
    await _run<bool>('crisis', () async {
      await engine.crisisExit(sessionId);
      return true;
    });
  }

  // ───────────────────────── 教训手册 / 设置页 ─────────────────────────

  /// [viewAlways] 为 true 时即使插件关闭也读取（设置页里的“我的教训手册”）。
  Future<PrpPlaybookData> playbookData({bool viewAlways = false}) async {
    final PrpPlaybookData? r = await _run<PrpPlaybookData>(
      'playbook',
      () async {
        if (!viewAlways && !await isEnabled()) return null;
        await engine.reconcile();
        final List<PrpLesson> sealed = await store.lessons(
          state: PrpLessonState.sealed,
        );
        final List<PrpLesson> drafts = await store.lessons(
          state: PrpLessonState.draft,
        );
        return PrpPlaybookData(sealed: sealed, drafts: drafts);
      },
    );
    return r ?? PrpPlaybookData.empty;
  }

  Future<PrpConfig> config({bool installed = true}) =>
      settings.snapshot(installed: installed);

  Future<PrpDiagnostics> diagnostics() async {
    final bool enabled = await isEnabled();
    int sessions = 0;
    int sealed = 0;
    int drafts = 0;
    int recalls = 0;
    try {
      final s = await engine.stats();
      sessions = s.sessions;
      sealed = s.sealed;
      drafts = s.drafts;
      recalls = s.recalls;
    } catch (e) {
      breaker.note('读取统计失败：$e');
    }
    return PrpDiagnostics(
      installed: true,
      enabled: enabled,
      tripped: breaker.tripped,
      failures: breaker.failures,
      log: breaker.log,
      sessions: sessions,
      sealedLessons: sealed,
      draftLessons: drafts,
      recalls: recalls,
    );
  }

  Future<String> exportJson() => store.exportJson();

  Future<void> clearAll() async {
    await store.clearAll();
    breaker.note('已清除全部教训数据');
  }
}
