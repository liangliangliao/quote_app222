import '../copy.dart';
import '../data/enemy_dao.dart';
import '../data/models.dart';
import '../enemy_oracle.dart';
import 'digest_builder.dart';
import 'evidence_source.dart';
import 'guard.dart';

enum EnemyOutcomeKind { verdict, insufficient, skipped }

/// 一次开庭的结果。
class EnemyOutcome {
  const EnemyOutcome._(this.kind, this.message, this.verdict, this.reason);

  factory EnemyOutcome.verdict(EnemyVerdict v) =>
      EnemyOutcome._(EnemyOutcomeKind.verdict, '', v, '');
  factory EnemyOutcome.insufficient() =>
      const EnemyOutcome._(EnemyOutcomeKind.insufficient, EnemyCopy.insufficient, null, 'insufficient');
  factory EnemyOutcome.skipped(String reason, String message) =>
      EnemyOutcome._(EnemyOutcomeKind.skipped, message, null, reason);

  final EnemyOutcomeKind kind;
  final String message;
  final EnemyVerdict? verdict;
  final String reason;
}

enum ResponseKind { acked, appealAccepted, appealQuotaExceeded, needsText, crisis }

class ResponseResult {
  const ResponseResult(this.kind, this.message);
  final ResponseKind kind;
  final String message;
}

/// 每周审判日的指标。全部由本地数据算出，不调模型。
class WeeklyReview {
  const WeeklyReview({
    required this.commitmentsDone,
    required this.commitmentsMissed,
    required this.commitmentsExcused,
    required this.commitmentRate,
    required this.verdictActRate,
    required this.actRateByIntensity,
    required this.topFailures,
    required this.appealCount,
    required this.appealAccepted,
    required this.focus,
  });

  final int commitmentsDone;
  final int commitmentsMissed;
  final int commitmentsExcused;

  /// 承诺履约率（0..100），没有已结算的承诺时为 null。
  final int? commitmentRate;

  /// 判词之后动作被兑现的比例（0..100），没有已结算的判词时为 null。
  final int? verdictActRate;

  /// 档位 → (兑现数, 已结算数)。
  final Map<int, ({int done, int total})> actRateByIntensity;

  /// 失败类别，按次数降序。
  final List<({String category, int count})> topFailures;
  final int appealCount;
  final int appealAccepted;

  /// 下周唯一重点。
  final String focus;
}

class EnemyEngine {
  EnemyEngine({
    required this.dao,
    required this.oracle,
    this.sources = const <EvidenceSource>[],
    DateTime Function()? clock,
    this.validator = const DraftValidator(),
    this.fallback = const LocalFactOracle(),
  }) : _clock = clock;

  final EnemyDao dao;
  final EnemyOracle oracle;
  final List<EvidenceSource> sources;
  final DraftValidator validator;
  final LocalFactOracle fallback;
  final DateTime Function()? _clock;

  static const int windowHours = 24;
  static const int lookbackDays = 30;
  static const int maxRegenerations = 2;
  static const int maxExcusesPerWeek = 2;
  static const int minReasonChars = 6;
  static const Duration oracleTimeout = Duration(seconds: 30);
  static const Duration muteDuration = Duration(hours: 24);
  static const Duration tooMuchWindow = Duration(hours: 72);

  int nowMs() => (_clock?.call() ?? DateTime.now()).millisecondsSinceEpoch;

  DateTime _now() => DateTime.fromMillisecondsSinceEpoch(nowMs());

  // ---------------------------------------------------------------- consents

  Future<Map<String, bool>> consents() async {
    final Map<String, bool> out = <String, bool>{};
    for (final EvidenceSource s in sources) {
      out[s.id] = await dao.boolSetting(EnemySettings.consent(s.id));
    }
    return out;
  }

  Future<void> setConsent(String sourceId, bool granted) =>
      dao.setBoolSetting(EnemySettings.consent(sourceId), granted);

  Future<void> grantAll() async {
    for (final EvidenceSource s in sources) {
      await setConsent(s.id, true);
    }
  }

  // -------------------------------------------------------------------- sync

  /// 从已授权的来源拉取证据入库，返回新增条数。
  Future<int> sync() async {
    final int since = nowMs() - const Duration(days: lookbackDays).inMilliseconds;
    int added = 0;
    for (final EvidenceSource s in sources) {
      if (!await dao.boolSetting(EnemySettings.consent(s.id))) continue;
      List<EventDraft> drafts;
      try {
        drafts = await s.collect(dao.db, since);
      } catch (_) {
        continue;
      }
      for (final EventDraft d in drafts) {
        if (await dao.insertEvent(d) != null) added++;
      }
    }
    return added;
  }

  final Map<String, String> _signatures = <String, String>{};

  /// 只在来源的变更指纹变了才重新收集。敌人每隔几秒问一次，靠它保持便宜。
  /// 指纹只存在内存里：新建的引擎（比如后台任务）第一次会完整收集一遍。
  Future<int> syncIfChanged() async {
    final int since = nowMs() - const Duration(days: lookbackDays).inMilliseconds;
    int added = 0;
    for (final EvidenceSource s in sources) {
      if (!await dao.boolSetting(EnemySettings.consent(s.id))) {
        _signatures.remove(s.id);
        continue;
      }
      String? sig;
      try {
        sig = await s.watermark(dao.db);
      } catch (_) {
        sig = null;
      }
      if (sig != null && _signatures[s.id] == sig) continue;
      List<EventDraft> drafts;
      try {
        drafts = await s.collect(dao.db, since);
      } catch (_) {
        continue;
      }
      for (final EventDraft d in drafts) {
        if (await dao.insertEvent(d) != null) added++;
      }
      if (sig != null) _signatures[s.id] = sig;
    }
    return added;
  }

  // ------------------------------------------------------------------- usage

  /// 来源标识：App 前台使用时长。这不是读宿主的表，而是敌人自己计的数。
  static const String usageSourceId = 'usage';

  /// 记一分钟 App 前台时间（需要授权）。静默时段内的算作深夜使用。
  Future<void> recordUsageMinute() async {
    if (!await dao.boolSetting(EnemySettings.consent(usageSourceId))) return;
    final DateTime d = _now();
    await dao.addUsageMinute(
      day: dayKey(d),
      lateNight: await inQuietHours(),
      nowMs: nowMs(),
    );
  }

  Future<Map<String, dynamic>> usageToday() async {
    if (!await dao.boolSetting(EnemySettings.consent(usageSourceId))) {
      return const <String, dynamic>{};
    }
    final DateTime d = _now();
    final ({int minutes, int lateNight, int firstMs}) u = await dao.usageFor(dayKey(d));
    String first = '';
    if (u.firstMs > 0) {
      final DateTime f = DateTime.fromMillisecondsSinceEpoch(u.firstMs);
      String two(int v) => v.toString().padLeft(2, '0');
      first = '${two(f.hour)}:${two(f.minute)}';
    }
    return <String, dynamic>{
      'minutes_today': u.minutes,
      'late_night_minutes_today': u.lateNight,
      'first_open_today': first,
    };
  }

  // -------------------------------------------------------------- commitments

  /// 到期还没兑现的承诺一律记为失效，并写进证据。
  Future<int> settleOverdue() async {
    final int now = nowMs();
    final List<EnemyCommitment> overdue = await dao.overdueOpen(now);
    for (final EnemyCommitment c in overdue) {
      await dao.setCommitmentStatus(c.id, CommitmentStatus.missed);
      await _commitmentEvent(c, 'commitment_missed', c.dueMs ?? now);
      if (c.verdictId != null) {
        await dao.setVerdictOutcome(c.verdictId!, 'missed', now);
      }
    }
    return overdue.length;
  }

  Future<void> _commitmentEvent(EnemyCommitment c, String type, int ts) async {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(ts);
    await dao.insertEvent(EventDraft(
      ts: ts,
      source: 'commitment',
      type: type,
      dedupeKey: 'commitment:${c.id}:$type',
      payload: <String, dynamic>{
        'commitment_id': c.id,
        'subject': 'commitment:${c.id}',
        'label': c.text,
        'day': _dayKey(d),
      },
    ));
  }

  /// 立一条承诺。文字里出现危机表达时不入库，直接静音。
  Future<({int? id, bool crisis, String? error})> addCommitment(
    String text, {
    DateTime? due,
    String stake = '',
  }) async {
    final String t = text.trim();
    final String s = stake.trim();
    if (t.isEmpty) return (id: null, crisis: false, error: null);
    if (SafetyValve.shouldMute('$t $s')) {
      await _muteForText('$t $s');
      return (id: null, crisis: true, error: null);
    }
    if (!StakeGuard.isAcceptable(s)) {
      return (id: null, crisis: false, error: EnemyCopy.stakeRejected);
    }
    final int now = nowMs();
    final int id = await dao.insertCommitment(
      text: t,
      createdMs: now,
      dueMs: due?.millisecondsSinceEpoch,
      stake: s,
    );
    final EnemyCommitment? c = await dao.commitment(id);
    if (c != null) await _commitmentEvent(c, 'commitment_created', now);
    return (id: id, crisis: false, error: null);
  }

  /// 兑现一条承诺，返回认账的那句话。
  Future<String?> complete(int commitmentId) async {
    final EnemyCommitment? c = await dao.commitment(commitmentId);
    if (c == null || c.status == CommitmentStatus.done) return null;
    final int now = nowMs();
    await dao.setCommitmentStatus(c.id, CommitmentStatus.done);
    await _commitmentEvent(c, 'commitment_done', now);
    if (c.verdictId != null) {
      await dao.setVerdictOutcome(c.verdictId!, 'done', now);
    }
    final List<EnemyVerdict> recent = await dao.recentVerdicts(limit: 10);
    int streak = 0;
    for (final EnemyVerdict v in recent) {
      if (v.outcome == 'pending') continue;
      if (v.outcome == 'done') {
        streak++;
      } else {
        break;
      }
    }
    return EnemyCopy.acknowledgement(c.text, streak);
  }

  /// 用户自己承认没做到：立刻记为失效并写进证据。
  Future<void> markMissed(int commitmentId) async {
    final EnemyCommitment? c = await dao.commitment(commitmentId);
    if (c == null || c.status != CommitmentStatus.open) return;
    final int now = nowMs();
    await dao.setCommitmentStatus(c.id, CommitmentStatus.missed);
    await _commitmentEvent(c, 'commitment_missed', now);
    if (c.verdictId != null) {
      await dao.setVerdictOutcome(c.verdictId!, 'missed', now);
    }
  }

  /// 失败归因。不接受「忙」这类单独的空话。
  Future<({bool ok, String message, EnemyLesson? lesson, bool crisis})> attribute({
    required int commitmentId,
    required String category,
    required String reason,
  }) async {
    final String text = reason.trim();
    if (SafetyValve.shouldMute(text)) {
      final String message = await _muteForText(text);
      return (ok: false, message: message, lesson: null, crisis: true);
    }
    if (text.length < minReasonChars || EnemyCopy.vagueReasons.contains(text)) {
      return (ok: false, message: EnemyCopy.attributionTooVague, lesson: null, crisis: false);
    }
    final EnemyCommitment? c = await dao.commitment(commitmentId);
    final EnemyLesson lesson = await dao.addOrBumpLesson(
      verdictId: c?.verdictId,
      category: category,
      reasonText: text,
      lesson: EnemyCopy.lessonText(category, text),
      nowMs: nowMs(),
    );
    return (ok: true, message: EnemyCopy.attributionSaved, lesson: lesson, crisis: false);
  }

  // ------------------------------------------------------------------- judge

  Future<EnemyOutcome> judge({String trigger = 'daily', bool manual = false}) async {
    final int now = nowMs();
    final DateTime nowDt = _now();

    // 静音（安全阀 / 停战）对手动开庭同样生效。
    final int mutedUntil = await dao.intSetting(EnemySettings.mutedUntilMs, 0);
    if (mutedUntil > now) {
      return EnemyOutcome.skipped('muted', EnemyCopy.mutedNote);
    }

    if (!manual) {
      final int qs = await dao.intSetting(EnemySettings.quietStartHour, 23);
      final int qe = await dao.intSetting(EnemySettings.quietEndHour, 7);
      if (_inQuietHours(nowDt.hour, qs, qe)) {
        return EnemyOutcome.skipped('quiet', EnemyCopy.quietHoursNote);
      }
      final int cap = await dao.intSetting(EnemySettings.dailyCap, 3);
      final DateTime startOfDay = DateTime(nowDt.year, nowDt.month, nowDt.day);
      final List<EnemyVerdict> today =
          await dao.verdictsSince(startOfDay.millisecondsSinceEpoch);
      if (today.length >= cap) {
        return EnemyOutcome.skipped('cap', EnemyCopy.dailyCapNote);
      }
    }

    await sync();
    await settleOverdue();

    final ({EnemyDigest digest, int intensity, String address}) snap = await snapshot();
    final EnemyDigest digest = snap.digest;
    final int intensity = snap.intensity;
    if (!digest.sufficient) return EnemyOutcome.insufficient();

    EnemyDraft? chosen;
    if (intensity >= 1) {
      for (int attempt = 0; attempt <= maxRegenerations && chosen == null; attempt++) {
        EnemyDraft? d;
        try {
          d = await oracle
              .judge(digest: digest.json, intensity: intensity, nowMs: now)
              .timeout(oracleTimeout);
        } catch (_) {
          d = null;
        }
        // 模型没产出（不可用、超时、解析失败）就不再重试，直接降级。
        if (d == null) break;
        final List<String> problems = validator.validate(
          d,
          allowedEvidence: digest.evidenceIds,
          maxTone: intensity,
          nowMs: now,
        );
        if (problems.isEmpty) chosen = d;
      }
    }
    // 降级：只陈列事实。事实来自本地摘要，不含模型生成的语气。
    chosen ??= await fallback.judge(digest: digest.json, intensity: 0, nowMs: now);
    if (chosen == null) return EnemyOutcome.insufficient();

    final int verdictId = await dao.insertVerdict(
      ts: now,
      trigger: trigger,
      intensity: chosen.factOnly ? 0 : intensity,
      charge: chosen.charge.trim(),
      evidenceIds: chosen.evidenceIds,
      lessonHint: chosen.lessonHint.trim(),
      action: chosen.action.trim(),
      actionDueMs: chosen.actionDueMs,
      appealPrompt: chosen.appealPrompt.trim().isEmpty
          ? EnemyCopy.defaultAppealPrompt
          : chosen.appealPrompt.trim(),
      factOnly: chosen.factOnly,
    );

    // 动作自动成为一条承诺，到期由 settleOverdue 结算。
    final int commitmentId = await dao.insertCommitment(
      text: chosen.action.trim(),
      createdMs: now,
      dueMs: chosen.actionDueMs,
      origin: 'verdict',
      verdictId: verdictId,
    );
    await dao.linkVerdictCommitment(verdictId, commitmentId);
    final EnemyCommitment? created = await dao.commitment(commitmentId);
    if (created != null) await _commitmentEvent(created, 'commitment_created', now);

    final EnemyVerdict? saved = await dao.verdict(verdictId);
    return EnemyOutcome.verdict(saved!);
  }

  /// 此刻的证据摘要、实际档位和称呼。开庭、对话、插话都从这里取材。
  Future<({EnemyDigest digest, int intensity, String address})> snapshot() async {
    final int now = nowMs();
    final int windowMs = const Duration(hours: windowHours).inMilliseconds;
    final List<EnemyEvent> events = await dao.eventsBetween(now - windowMs, now + 1);
    final List<EnemyCommitment> weekCommitments =
        await dao.commitmentsSince(now - const Duration(days: 7).inMilliseconds);
    final List<EnemyVerdict> recentVerdicts = await dao.recentVerdicts(limit: 30);
    final List<EnemyLesson> lessons = await dao.lessons(limit: 5);
    final int intensity = await effectiveIntensity(recentVerdicts);
    final String addr = await address();
    final Map<String, dynamic> usage = await usageToday();
    final EnemyDigest digest = DigestBuilder.build(
      nowMs: now,
      windowMs: windowMs,
      intensity: intensity,
      events: events,
      weekCommitments: weekCommitments,
      recentVerdicts: recentVerdicts,
      lessons: lessons,
      address: addr,
      usage: usage,
    );
    return (digest: digest, intensity: intensity, address: addr);
  }

  /// 敌人怎么称呼你。
  Future<String> address() async {
    final String? raw = await dao.getSetting(EnemySettings.address);
    final String t = (raw ?? '').trim();
    return t.isEmpty ? EnemyCopy.defaultAddress : t;
  }

  /// 改称呼。不能太长，不能是羞辱性的称呼（否则敌人就会这样叫你）。
  Future<bool> setAddress(String raw) async {
    final String t = raw.trim();
    if (t.isEmpty) {
      await dao.setSetting(EnemySettings.address, '');
      return true;
    }
    if (t.length > EnemyCopy.maxAddressChars) return false;
    if (DraftValidator.containsBanned(t) || SafetyValve.shouldMute(t)) return false;
    await dao.setSetting(EnemySettings.address, t);
    return true;
  }

  Future<bool> inQuietHours() async {
    final int qs = await dao.intSetting(EnemySettings.quietStartHour, 23);
    final int qe = await dao.intSetting(EnemySettings.quietEndHour, 7);
    return _inQuietHours(_now().hour, qs, qe);
  }

  /// 实际生效的档位：用户设定为上限，只降不自动升。
  Future<int> effectiveIntensity([List<EnemyVerdict>? recent]) async {
    final int base = await dao.intSetting(EnemySettings.intensity, 2);
    final int truce = await dao.intSetting(EnemySettings.truceWeekday, DateTime.saturday);
    final int now = nowMs();
    final List<EnemyVerdict> verdicts = recent ?? await dao.recentVerdicts(limit: 30);

    int unanswered = 0;
    for (final EnemyVerdict v in verdicts) {
      if (v.userResponse != VerdictResponse.pending) break;
      if (now - v.ts <= const Duration(hours: 24).inMilliseconds) continue;
      unanswered++;
    }
    final int tooMuchAt = await dao.intSetting(EnemySettings.tooMuchAtMs, 0);
    return IntensityGovernor.effective(
      base: base,
      truceDay: truce != 0 && _now().weekday == truce,
      unansweredStreak: unanswered,
      tooMuchRecently: tooMuchAt > 0 && now - tooMuchAt < tooMuchWindow.inMilliseconds,
    );
  }

  // ---------------------------------------------------------------- response

  Future<ResponseResult> acknowledge(int verdictId) async {
    await dao.setVerdictResponse(verdictId, VerdictResponse.ack);
    return const ResponseResult(ResponseKind.acked, '');
  }

  /// 申辩。理由必须写；理由里出现危机表达时按安全阀处理。
  /// 每周最多豁免 [maxExcusesPerWeek] 条，超出的照记。
  Future<ResponseResult> appeal(int verdictId, String reason) async {
    final String text = reason.trim();
    if (text.isEmpty) {
      return const ResponseResult(ResponseKind.needsText, EnemyCopy.appealNeedsText);
    }
    if (SafetyValve.shouldMute(text)) {
      final String message = await _muteForText(text);
      return ResponseResult(ResponseKind.crisis, message);
    }
    final int now = nowMs();
    final List<EnemyVerdict> week =
        await dao.verdictsSince(now - const Duration(days: 7).inMilliseconds);
    final int excused = week.where((EnemyVerdict v) => v.outcome == 'excused').length;
    if (excused >= maxExcusesPerWeek) {
      await dao.setVerdictResponse(verdictId, VerdictResponse.appeal, appealText: text);
      return const ResponseResult(
        ResponseKind.appealQuotaExceeded,
        '本周豁免额度（$maxExcusesPerWeek 次）用完了。你的话记下了，但这条照记。',
      );
    }
    final EnemyVerdict? v = await dao.verdict(verdictId);
    await dao.setVerdictResponse(verdictId, VerdictResponse.appeal, appealText: text);
    await dao.setVerdictOutcome(verdictId, 'excused', now);
    if (v?.commitmentId != null) {
      await dao.setCommitmentStatus(v!.commitmentId!, CommitmentStatus.excused);
      final EnemyCommitment? c = await dao.commitment(v.commitmentId!);
      if (c != null) await _commitmentEvent(c, 'commitment_excused', now);
    }
    return const ResponseResult(ResponseKind.appealAccepted, EnemyCopy.appealAccepted);
  }

  // -------------------------------------------------------------- mute / tone

  /// 静音 24 小时。[crisis] 为 true 时，判词页会显示安全阀的那段话。
  Future<void> muteFor24h({bool crisis = true}) async {
    await dao.setSetting(
      EnemySettings.mutedUntilMs,
      '${nowMs() + muteDuration.inMilliseconds}',
    );
    await dao.setBoolSetting(EnemySettings.crisisNoticePending, crisis);
  }

  /// 用户主动喊「停战」：静音，但不当作危机处理。
  Future<void> truce() => muteFor24h(crisis: false);

  /// 用户写的文字触发了安全阀：危机走危机流程，只是「停战」则按停战处理。
  Future<String> _muteForText(String text) async {
    final bool crisis = SafetyValve.isCrisis(text);
    await muteFor24h(crisis: crisis);
    return crisis ? EnemyCopy.crisisMessage : EnemyCopy.truceAcknowledged;
  }

  Future<void> unmute() async {
    await dao.setSetting(EnemySettings.mutedUntilMs, '0');
    await dao.setBoolSetting(EnemySettings.crisisNoticePending, false);
  }

  Future<bool> isMuted() async =>
      await dao.intSetting(EnemySettings.mutedUntilMs, 0) > nowMs();

  Future<void> markTooMuch() =>
      dao.setSetting(EnemySettings.tooMuchAtMs, '${nowMs()}');

  // ------------------------------------------------------------------ review

  Future<WeeklyReview> weeklyReview() async {
    final int now = nowMs();
    final int since = now - const Duration(days: 7).inMilliseconds;
    final List<EnemyCommitment> commitments = await dao.commitmentsSince(since);
    final List<EnemyVerdict> verdicts = await dao.verdictsSince(since);
    final List<EnemyLesson> lessons = await dao.lessons(limit: 200);

    int done = 0, missed = 0, excused = 0;
    for (final EnemyCommitment c in commitments) {
      switch (c.status) {
        case CommitmentStatus.done:
          done++;
          break;
        case CommitmentStatus.missed:
          missed++;
          break;
        case CommitmentStatus.excused:
          excused++;
          break;
        default:
          break;
      }
    }
    final int settled = done + missed;

    int vDone = 0, vSettled = 0;
    final Map<int, ({int done, int total})> byIntensity = <int, ({int done, int total})>{};
    for (final EnemyVerdict v in verdicts) {
      if (v.outcome != 'done' && v.outcome != 'missed') continue;
      vSettled++;
      final bool ok = v.outcome == 'done';
      if (ok) vDone++;
      final ({int done, int total}) old = byIntensity[v.intensity] ?? (done: 0, total: 0);
      byIntensity[v.intensity] = (done: old.done + (ok ? 1 : 0), total: old.total + 1);
    }

    final Map<String, int> cats = <String, int>{};
    for (final EnemyLesson l in lessons.where((EnemyLesson l) => l.createdMs >= since)) {
      cats[l.category] = (cats[l.category] ?? 0) + l.timesRepeated;
    }
    final List<({String category, int count})> top = cats.entries
        .map((MapEntry<String, int> e) => (category: e.key, count: e.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final int appeals = verdicts
        .where((EnemyVerdict v) => v.userResponse == VerdictResponse.appeal)
        .length;
    final int accepted = verdicts.where((EnemyVerdict v) => v.outcome == 'excused').length;

    final String focus = top.isEmpty
        ? '下周唯一重点：每条承诺都写清楚做什么、几点前。'
        : '下周唯一重点：「${top.first.category}」。每条承诺拆到 15 分钟以内，到点先做最小的一步。';

    return WeeklyReview(
      commitmentsDone: done,
      commitmentsMissed: missed,
      commitmentsExcused: excused,
      commitmentRate: settled == 0 ? null : (done * 100 / settled).round(),
      verdictActRate: vSettled == 0 ? null : (vDone * 100 / vSettled).round(),
      actRateByIntensity: byIntensity,
      topFailures: top,
      appealCount: appeals,
      appealAccepted: accepted,
      focus: focus,
    );
  }

  /// 通知正文：只报数字。
  Future<String> briefLine() async {
    final int now = nowMs();
    final List<EnemyCommitment> open = await dao.commitments(status: CommitmentStatus.open);
    final int overdue = open.where((EnemyCommitment c) => c.isOverdue(now)).length;
    final int pending = open.length - overdue;
    if (open.isEmpty) return '今天的账该算了。';
    return '未兑现 $overdue 条，还在等 $pending 条。';
  }

  // ----------------------------------------------------------------- helpers

  static bool _inQuietHours(int hour, int start, int end) {
    if (start == end) return false;
    if (start > end) return hour >= start || hour < end;
    return hour >= start && hour < end;
  }

  static String dayKey(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  static String _dayKey(DateTime d) => dayKey(d);
}
