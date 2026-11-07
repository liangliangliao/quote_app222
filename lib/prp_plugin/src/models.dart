import 'dart:convert';

/// 调用方（接入点）。模块通过它告诉插件“我是谁”。
enum PrpSurface { enemy, behavior, failureModule, kindling, quoteHome }

extension PrpSurfaceX on PrpSurface {
  String get key => name;

  String get label {
    switch (this) {
      case PrpSurface.enemy:
        return '美丽的敌人';
      case PrpSurface.behavior:
        return '行为追踪';
      case PrpSurface.failureModule:
        return '失败与完美主义';
      case PrpSurface.kindling:
        return '火种';
      case PrpSurface.quoteHome:
        return '名人名言首页';
    }
  }

  /// 会话口吻：敌人入口用敌人口吻，其他入口用中性温和口吻。
  PrpVoice get voice =>
      this == PrpSurface.enemy ? PrpVoice.enemy : PrpVoice.neutral;

  /// 首次开启插件时各功能的默认值（火种与名言首页默认关闭）。
  bool get defaultOn =>
      this == PrpSurface.enemy ||
      this == PrpSurface.behavior ||
      this == PrpSurface.failureModule;

  /// 本版本是否已经接入。未接入的功能在设置页显示为“待接入”。
  bool get wiredInThisVersion =>
      this == PrpSurface.enemy || this == PrpSurface.quoteHome;

  static PrpSurface? parse(String? s) {
    for (final PrpSurface v in PrpSurface.values) {
      if (v.name == s) return v;
    }
    return null;
  }
}

/// 会话的口吻。敌人里用敌人口吻，其他入口用中性温和口吻。
enum PrpVoice { enemy, neutral }

enum PrpLessonState { draft, sealed, retired }

extension PrpLessonStateX on PrpLessonState {
  static PrpLessonState parse(String? s) {
    for (final PrpLessonState v in PrpLessonState.values) {
      if (v.name == s) return v;
    }
    return PrpLessonState.draft;
  }
}

enum PrpOutcome { pending, helped, repeated, ignored }

extension PrpOutcomeX on PrpOutcome {
  static PrpOutcome parse(String? s) {
    for (final PrpOutcome v in PrpOutcome.values) {
      if (v.name == s) return v;
    }
    return PrpOutcome.pending;
  }
}

/// 会话步骤：缓一缓 → 对账 → 双栏 → 预警与如果—那么 → 盖印 → 拉远 → 结束。
enum PrpStep { pause, ledger, columns, signal, seal, zoom, done }

extension PrpStepX on PrpStep {
  static PrpStep parse(String? s) {
    for (final PrpStep v in PrpStep.values) {
      if (v.name == s) return v;
    }
    return PrpStep.pause;
  }
}

/// 调用方在“没做到”之后发给插件的信号。
class PrpSignal {
  const PrpSignal({
    required this.surface,
    required this.kind,
    required this.subjectKey,
    required this.expected,
    this.facts = const <String>[],
    this.category,
    this.userInitiated = false,
    this.rewriteOf,
    this.tsMs = 0,
  });

  final PrpSurface surface;

  /// commitment_missed | habit_missed | manual
  final String kind;

  /// 例如 commitment:12。用于回访匹配与验证。
  final String subjectKey;

  /// 预期（字据文本 / 习惯目标）。
  final String expected;

  /// 调用方已知的事实（记录里写的）。
  final List<String> facts;

  final String? category;

  /// 用户亲手点的（不受每日提议上限和静默时段限制）。
  final bool userInitiated;

  /// 改写某条已有教训时，填它的 id。
  final int? rewriteOf;

  final int tsMs;
}

/// 插件返回的“可以开始一次会话”的提议。
class PrpOffer {
  const PrpOffer({
    required this.sessionId,
    required this.surface,
    required this.voice,
    required this.signal,
    this.prefill,
  });

  final int sessionId;
  final PrpSurface surface;
  final PrpVoice voice;
  final PrpSignal signal;

  /// 改写时带入的旧教训。
  final PrpLesson? prefill;
}

/// 回访请求的上下文。
class PrpContext {
  const PrpContext({
    required this.surface,
    this.subjectKey,
    this.category,
    this.text,
    this.kind = 'new_commitment',
    this.pull = false,
  });

  final PrpSurface surface;
  final String? subjectKey;
  final String? category;
  final String? text;

  /// new_commitment | repeat_detected | quote_home | playbook
  final String kind;

  /// 用户主动查看（不受回访预算限制）。
  final bool pull;
}

class PrpLesson {
  const PrpLesson({
    this.id,
    this.subjectKey = '',
    this.subjectText = '',
    this.category = '',
    this.source = 'enemy',
    this.state = PrpLessonState.draft,
    this.worked = const <String>[],
    this.failed = const <String>[],
    this.triggerText = '',
    this.earlySignal = '',
    this.ifCue = '',
    this.thenAction = '',
    this.evidenceRefs = const <String>[],
    this.quality = 0,
    required this.createdMs,
    this.sealedMs,
    this.parentId,
    this.verifiedCnt = 0,
    this.repeatedCnt = 0,
  });

  final int? id;
  final String subjectKey;

  /// 信号里的“预期”（字据文本），用于相似匹配。
  final String subjectText;
  final String category;
  final String source;
  final PrpLessonState state;
  final List<String> worked;
  final List<String> failed;
  final String triggerText;
  final String earlySignal;
  final String ifCue;
  final String thenAction;

  /// 只存引用或简短事实，不复制大段内容。
  final List<String> evidenceRefs;
  final int quality;
  final int createdMs;
  final int? sealedMs;
  final int? parentId;
  final int verifiedCnt;
  final int repeatedCnt;

  bool get hasIfThen => ifCue.trim().isNotEmpty && thenAction.trim().isNotEmpty;

  /// 一行摘要：有效…；无效…；如果…就…
  String summaryLine() {
    final List<String> parts = <String>[];
    if (worked.isNotEmpty) parts.add('有效：${worked.join('、')}');
    if (failed.isNotEmpty) parts.add('无效：${failed.join('、')}');
    if (hasIfThen) parts.add('如果$ifCue，我就$thenAction');
    return parts.join('；');
  }

  PrpLesson copyWith({
    int? id,
    String? subjectKey,
    String? subjectText,
    String? category,
    String? source,
    PrpLessonState? state,
    List<String>? worked,
    List<String>? failed,
    String? triggerText,
    String? earlySignal,
    String? ifCue,
    String? thenAction,
    List<String>? evidenceRefs,
    int? quality,
    int? createdMs,
    int? sealedMs,
    int? parentId,
    int? verifiedCnt,
    int? repeatedCnt,
  }) {
    return PrpLesson(
      id: id ?? this.id,
      subjectKey: subjectKey ?? this.subjectKey,
      subjectText: subjectText ?? this.subjectText,
      category: category ?? this.category,
      source: source ?? this.source,
      state: state ?? this.state,
      worked: worked ?? this.worked,
      failed: failed ?? this.failed,
      triggerText: triggerText ?? this.triggerText,
      earlySignal: earlySignal ?? this.earlySignal,
      ifCue: ifCue ?? this.ifCue,
      thenAction: thenAction ?? this.thenAction,
      evidenceRefs: evidenceRefs ?? this.evidenceRefs,
      quality: quality ?? this.quality,
      createdMs: createdMs ?? this.createdMs,
      sealedMs: sealedMs ?? this.sealedMs,
      parentId: parentId ?? this.parentId,
      verifiedCnt: verifiedCnt ?? this.verifiedCnt,
      repeatedCnt: repeatedCnt ?? this.repeatedCnt,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'subject_key': subjectKey,
    'subject_text': subjectText,
    'category': category,
    'source': source,
    'state': state.name,
    'worked': jsonEncode(worked),
    'failed': jsonEncode(failed),
    'trigger_text': triggerText,
    'early_signal': earlySignal,
    'if_cue': ifCue,
    'then_action': thenAction,
    'evidence_refs': jsonEncode(evidenceRefs),
    'quality': quality,
    'created_ms': createdMs,
    'sealed_ms': sealedMs,
    'parent_id': parentId,
    'verified_cnt': verifiedCnt,
    'repeated_cnt': repeatedCnt,
  };

  static PrpLesson fromMap(Map<String, Object?> m) => PrpLesson(
    id: m['id'] as int?,
    subjectKey: (m['subject_key'] ?? '') as String,
    subjectText: (m['subject_text'] ?? '') as String,
    category: (m['category'] ?? '') as String,
    source: (m['source'] ?? 'enemy') as String,
    state: PrpLessonStateX.parse(m['state'] as String?),
    worked: decodeList(m['worked']),
    failed: decodeList(m['failed']),
    triggerText: (m['trigger_text'] ?? '') as String,
    earlySignal: (m['early_signal'] ?? '') as String,
    ifCue: (m['if_cue'] ?? '') as String,
    thenAction: (m['then_action'] ?? '') as String,
    evidenceRefs: decodeList(m['evidence_refs']),
    quality: (m['quality'] ?? 0) as int,
    createdMs: (m['created_ms'] ?? 0) as int,
    sealedMs: m['sealed_ms'] as int?,
    parentId: m['parent_id'] as int?,
    verifiedCnt: (m['verified_cnt'] ?? 0) as int,
    repeatedCnt: (m['repeated_cnt'] ?? 0) as int,
  );
}

/// 把 JSON 数组字符串解成字符串列表；坏数据返回空列表。
List<String> decodeList(Object? raw) {
  if (raw is! String || raw.isEmpty) return <String>[];
  try {
    final Object? v = jsonDecode(raw);
    if (v is List) return v.map((Object? e) => '$e').toList();
  } catch (_) {}
  return <String>[];
}

class PrpSession {
  const PrpSession({
    this.id,
    required this.surface,
    required this.triggerKind,
    this.triggerRef = '',
    required this.startedMs,
    this.pauseSec = 0,
    this.emotionBefore,
    this.emotionAfter,
    this.step = PrpStep.pause,
    this.lessonId,
    this.endedMs,
    this.outcome = 'open',
  });

  final int? id;
  final PrpSurface surface;
  final String triggerKind;
  final String triggerRef;
  final int startedMs;
  final int pauseSec;
  final int? emotionBefore;
  final int? emotionAfter;
  final PrpStep step;
  final int? lessonId;
  final int? endedMs;

  /// open | sealed | skipped | crisis_exit
  final String outcome;

  PrpSession copyWith({
    int? id,
    int? pauseSec,
    int? emotionBefore,
    int? emotionAfter,
    PrpStep? step,
    int? lessonId,
    int? endedMs,
    String? outcome,
  }) {
    return PrpSession(
      id: id ?? this.id,
      surface: surface,
      triggerKind: triggerKind,
      triggerRef: triggerRef,
      startedMs: startedMs,
      pauseSec: pauseSec ?? this.pauseSec,
      emotionBefore: emotionBefore ?? this.emotionBefore,
      emotionAfter: emotionAfter ?? this.emotionAfter,
      step: step ?? this.step,
      lessonId: lessonId ?? this.lessonId,
      endedMs: endedMs ?? this.endedMs,
      outcome: outcome ?? this.outcome,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'surface': surface.key,
    'trigger_kind': triggerKind,
    'trigger_ref': triggerRef,
    'started_ms': startedMs,
    'pause_sec': pauseSec,
    'emotion_before': emotionBefore,
    'emotion_after': emotionAfter,
    'step': step.name,
    'lesson_id': lessonId,
    'ended_ms': endedMs,
    'outcome': outcome,
  };

  static PrpSession fromMap(Map<String, Object?> m) => PrpSession(
    id: m['id'] as int?,
    surface: PrpSurfaceX.parse(m['surface'] as String?) ?? PrpSurface.enemy,
    triggerKind: (m['trigger_kind'] ?? '') as String,
    triggerRef: (m['trigger_ref'] ?? '') as String,
    startedMs: (m['started_ms'] ?? 0) as int,
    pauseSec: (m['pause_sec'] ?? 0) as int,
    emotionBefore: m['emotion_before'] as int?,
    emotionAfter: m['emotion_after'] as int?,
    step: PrpStepX.parse(m['step'] as String?),
    lessonId: m['lesson_id'] as int?,
    endedMs: m['ended_ms'] as int?,
    outcome: (m['outcome'] ?? 'open') as String,
  );
}

class PrpRecall {
  const PrpRecall({
    this.id,
    required this.lessonId,
    required this.ts,
    required this.context,
    this.ref = '',
    this.outcome = PrpOutcome.pending,
  });

  final int? id;
  final int lessonId;
  final int ts;
  final String context;
  final String ref;
  final PrpOutcome outcome;

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'lesson_id': lessonId,
    'ts': ts,
    'context': context,
    'ref': ref,
    'outcome': outcome.name,
  };

  static PrpRecall fromMap(Map<String, Object?> m) => PrpRecall(
    id: m['id'] as int?,
    lessonId: (m['lesson_id'] ?? 0) as int,
    ts: (m['ts'] ?? 0) as int,
    context: (m['context'] ?? '') as String,
    ref: (m['ref'] ?? '') as String,
    outcome: PrpOutcomeX.parse(m['outcome'] as String?),
  );
}

/// 一次回访命中：哪条教训、第几次遇到类似情况。
class PrpRecallHit {
  const PrpRecallHit({
    required this.lesson,
    required this.score,
    required this.nth,
    this.recallId,
  });

  final PrpLesson lesson;
  final double score;

  /// “这是类似情况的第 N 次”（含这一次）。
  final int nth;
  final int? recallId;

  /// 教训没挡住的次数 ≥ 2，建议改写。
  bool get suggestRewrite => lesson.repeatedCnt >= 2;
}

/// 拉远用的一个点：宿主提供“近 30 天”的真实记录。
class PrpMark {
  const PrpMark({required this.tsMs, required this.status, this.label = ''});

  final int tsMs;

  /// done | missed | other
  final String status;
  final String label;
}

/// 文本护栏的结果。
class GuardResult {
  const GuardResult({
    this.ok = true,
    this.crisis = false,
    this.problems = const <String>[],
    this.message,
  });

  final bool ok;
  final bool crisis;
  final List<String> problems;

  /// 危机时给用户看的话（宿主可以换成自己的）。
  final String? message;

  static const GuardResult pass = GuardResult();
}

class PrpConfig {
  const PrpConfig({
    required this.installed,
    required this.enabled,
    required this.surfaces,
    required this.pauseSec,
    required this.offerCap,
    required this.recallCap,
    required this.aiConsent,
  });

  final bool installed;
  final bool enabled;
  final Map<PrpSurface, bool> surfaces;
  final int pauseSec;
  final int offerCap;
  final int recallCap;
  final bool aiConsent;
}

class PrpDiagnostics {
  const PrpDiagnostics({
    required this.installed,
    required this.enabled,
    required this.tripped,
    required this.failures,
    required this.log,
    required this.sessions,
    required this.sealedLessons,
    required this.draftLessons,
    required this.recalls,
  });

  final bool installed;
  final bool enabled;
  final bool tripped;
  final int failures;
  final List<String> log;
  final int sessions;
  final int sealedLessons;
  final int draftLessons;
  final int recalls;

  static const PrpDiagnostics empty = PrpDiagnostics(
    installed: false,
    enabled: false,
    tripped: false,
    failures: 0,
    log: <String>[],
    sessions: 0,
    sealedLessons: 0,
    draftLessons: 0,
    recalls: 0,
  );
}

/// 一次会话结束时的结果（由会话卡片交给调用方）。
class PrpSessionResult {
  const PrpSessionResult({
    this.sealed = false,
    this.crisis = false,
    this.skipped = false,
  });

  final bool sealed;

  /// 用户在会话里写出了危机内容：调用方应当让自己的“口吻”退场。
  final bool crisis;
  final bool skipped;

  static const PrpSessionResult none = PrpSessionResult();
}

/// 调用方在“没做到”之后请插件处理的结果。
class PrpMissedResult {
  const PrpMissedResult({required this.handled, this.crisis = false});

  /// 插件已经接管（调用方不必再走自己原来的流程）。
  final bool handled;
  final bool crisis;

  static const PrpMissedResult notHandled = PrpMissedResult(handled: false);
}
