import '../copy.dart';
import '../data/enemy_dao.dart';
import '../data/models.dart';
import '../enemy_talker.dart';
import '../persona.dart';
import 'claim_check.dart';
import 'digest_builder.dart';
import 'enemy_engine.dart';
import 'guard.dart';
import 'opposition.dart';

/// 一次对话的结果。
class SayResult {
  const SayResult({
    this.user,
    this.enemy,
    this.crisis = false,
    this.muted = false,
  });

  final EnemyMessage? user;
  final EnemyMessage? enemy;

  /// 用户的话触发了安全阀：敌人已退场、静音。
  final bool crisis;

  /// 敌人当前静音，这句话没有送出去。
  final bool muted;
}

/// 巡查时的现场信息。后台任务没有前台会话，页面内也不算「在别处发呆」。
class PatrolContext {
  const PatrolContext({this.foreground = false, this.sessionStartMs});

  /// App 正在前台。
  final bool foreground;

  /// 这一次连续前台使用的开始时间；不知道就是 null（此时不做发呆检查）。
  final int? sessionStartMs;
}

/// 敌人的「在场」：对话、实时插话、开庭，都落在同一条消息时间线上。
///
/// 判词和事实仍然来自 [EnemyEngine]；这一层只负责让它像一个角色——
/// 会回话，会在你做了或没做某件事的几秒内开口，会在字据快到期时提醒你。
class EnemyPresence {
  EnemyPresence({required this.engine, this.talker});

  final EnemyEngine engine;
  final EnemyTalker? talker;

  EnemyDao get dao => engine.dao;

  /// 两次开口之间的最短间隔。只防刷屏，不能让你做完一件事却等几分钟才有回应。
  static const Duration minGap = Duration(seconds: 20);
  static const Duration dueSoonWindow = Duration(minutes: 10);
  static const int defaultInterjectCap = 30;
  static const int historyTurns = 12;
  static const int maxUserChars = 500;

  /// 人在 App 里待多久、案卷里还没有新记录，就点名。
  static const int stallMinutes = 20;
  static const Duration stallCooldown = Duration(hours: 3);
  static const int defaultPatrolHour = 20;

  /// 反对党质询的默认节奏：两次主动质询至少隔 90 分钟，一天最多 8 次、3 项动议。
  static const int defaultProbeGapMin = 90;
  static const int defaultProbeCap = 8;
  static const int defaultMotionCap = 3;

  /// 事件只有在发生后这么久之内才值得插话，免得刚授权时灌进来的旧账被当成新事。
  /// 字据类事件（到期、兑现）是在被发现的那一刻产生的，不受此限。
  static const Duration freshWindow = Duration(minutes: 30);

  /// 值得敌人开口的事件，数字越大越优先。
  static const Map<String, int> reactable = <String, int>{
    'commitment_unverified': 95,
    'commitment_missed': 100,
    'kindling_aborted': 80,
    'habit_missed': 70,
    'commitment_done': 60,
    'kindling_completed': 50,
    'habit_done': 40,
    'knowledge_converted': 30,
    'module_activity': 20,
  };

  static const Map<String, String> _typeLabels = <String, String>{
    'commitment_unverified': '字据被标记完成，但账上没有对应的记录',
    'commitment_missed': '字据到期没兑现',
    'commitment_done': '字据兑现了',
    'kindling_aborted': '火种中途退出',
    'kindling_completed': '火种十五分钟完成',
    'habit_missed': '习惯没完成',
    'habit_done': '习惯完成了',
    'knowledge_converted': '知识卡转成了行动步骤',
    'module_activity': '其它模块有了新记录',
  };

  bool _reacting = false;

  /// 这一步为什么没开口 / 开了口。写进设置里，自检页读它。
  String _why = '';
  String _lastWhyWritten = '';
  int _lastWhyWrittenMs = 0;

  Future<void> _noteWhy() async {
    final int now = engine.nowMs();
    // 原因没变且不到 15 秒就不写，免得每 3 秒写一次库。
    if (_why == _lastWhyWritten && now - _lastWhyWrittenMs < 15000) return;
    _lastWhyWritten = _why;
    _lastWhyWrittenMs = now;
    await dao.setSetting(EnemySettings.lastStepMs, '$now');
    await dao.setSetting(EnemySettings.lastWhy, _why);
  }

  // ------------------------------------------------------------------ thread

  Future<List<EnemyMessage>> thread({int limit = 80}) => dao.recentMessages(limit: limit);

  /// 时间线是空的就由敌人先开口。
  Future<EnemyMessage?> ensureOpening() async {
    if (await dao.messageCount() > 0) return null;
    final String a = await engine.address();
    return _store(
      role: MessageRole.enemy,
      kind: MessageKind.chat,
      text: PersonaLines.opening(a),
    );
  }

  Future<EnemyMessage> _store({
    required String role,
    required String kind,
    required String text,
    int? refId,
    int tone = 0,
  }) async {
    final int ts = engine.nowMs();
    final int id = await dao.insertMessage(
      ts: ts,
      role: role,
      kind: kind,
      text: text,
      refId: refId,
      tone: tone,
    );
    return EnemyMessage(id: id, ts: ts, role: role, kind: kind, text: text, refId: refId, tone: tone);
  }

  // ------------------------------------------------------------------- court

  /// 开庭：判词作为敌人的一条消息进入时间线。
  Future<EnemyOutcome> openCourt() async {
    final EnemyOutcome outcome = await engine.judge(trigger: 'manual', manual: true);
    final EnemyVerdict? v = outcome.verdict;
    if (outcome.kind == EnemyOutcomeKind.verdict && v != null) {
      await _store(
        role: MessageRole.enemy,
        kind: MessageKind.verdict,
        text: v.charge,
        refId: v.id,
        tone: v.intensity,
      );
    }
    return outcome;
  }

  // -------------------------------------------------------------------- talk

  /// 用户对敌人说话。
  ///
  /// 先过安全阀：危机表达或「停战」时敌人立刻退场，这句话**不会**被存储，
  /// 更不会发给模型。
  Future<SayResult> say(String raw) async {
    final String text = raw.trim();
    if (text.isEmpty) return const SayResult();

    if (SafetyValve.shouldMute(text)) {
      final bool crisis = SafetyValve.isCrisis(text);
      await engine.muteFor24h(crisis: crisis);
      final EnemyMessage exit = await _store(
        role: MessageRole.enemy,
        kind: MessageKind.exit,
        text: crisis ? EnemyCopy.crisisMessage : EnemyCopy.truceAcknowledged,
      );
      return SayResult(enemy: exit, crisis: crisis);
    }
    if (await engine.isMuted()) return const SayResult(muted: true);

    final String clipped =
        text.length > maxUserChars ? text.substring(0, maxUserChars) : text;
    // 他这句话是不是在回答敌人刚才的质询——要在存下他这句话之前判断。
    final EnemyMessage? pending = await _pendingInquiry();
    final EnemyMessage user = await _store(
      role: MessageRole.user,
      kind: MessageKind.chat,
      text: clipped,
    );

    final ({EnemyDigest digest, int intensity, String address}) snap = await _snapshot();

    // 核对他的说法和案卷：账上有就认，账上没有就盘问。
    final ClaimAssessment claim = ClaimCheck.assess(clipped, snap.digest.json);
    final EnemyMessage enemy = await _speak(
      snap: snap,
      situation: '用户在跟你说话。盘问他，别替他找台阶。'
          '${pending == null ? '' : '\n【他在回应你的质询】你刚才质询过他：「${_clipText(pending.text, 60)}」。'
              '判断他是正面回答了，还是在回避：回答了就针对答案追问，回避了就点破。'}'
          '${claim.hint.isEmpty ? '' : '\n【核对结果】${claim.hint}'}',
      userText: clipped,
      kind: MessageKind.chat,
      fallback: () => switch (claim.kind) {
        ClaimKind.doneWithoutRecord => PersonaLines.claimNoRecord(snap.address),
        ClaimKind.doneWithRecord => PersonaLines.claimConfirmed(snap.address, claim.records),
        ClaimKind.busyButOnline => PersonaLines.claimBusy(snap.address, claim.minutes),
        ClaimKind.none => PersonaLines.chat(
            address: snap.address,
            tone: _tone(snap.intensity),
            seed: user.id,
          ),
      },
    );
    return SayResult(user: user, enemy: enemy);
  }

  // ------------------------------------------------------------------- react

  /// 看一眼有没有新的事该插话。定时调用；用户刚做完一个动作时用 [force]。
  ///
  /// 敌人只对**新增**的事件开口（第一次调用只是定下起点）；静音、静默时段、
  /// 每日上限、最小间隔都会拦住它。[force] 只绕过间隔和上限，不绕过静音。
  Future<EnemyMessage?> react({bool force = false}) async {
    if (_reacting) return null;
    _reacting = true;
    _why = '';
    try {
      return await _react(force);
    } finally {
      _reacting = false;
      await _noteWhy();
    }
  }

  /// 敌人的一步：先对新事件做出反应；没有新事，再看有没有该主动开口的事
  /// （晨报、晚间结算、人在 App 里却没有新记录）。定时器每隔几秒调一次，
  /// 不需要任何人去叫醒它。[force] 用于用户刚做完动作时立即接话，不做主动巡查。
  Future<EnemyMessage?> step({bool force = false, PatrolContext ctx = const PatrolContext()}) async {
    if (_reacting) return null;
    _reacting = true;
    _why = '';
    try {
      final EnemyMessage? reacted = await _react(force);
      if (reacted != null || force) return reacted;
      return await _patrol(ctx);
    } finally {
      _reacting = false;
      await _noteWhy();
    }
  }

  Future<EnemyMessage?> _react(bool force) async {
    if (await engine.isMuted()) {
      _why = 'muted';
      return null;
    }
    if (!await dao.boolSetting(EnemySettings.interject, fallback: true)) {
      _why = 'interject_off';
      return null;
    }

    await engine.syncIfChanged();
    await engine.settleOverdue();

    final int now = engine.nowMs();
    final int cursor = await dao.intSetting(EnemySettings.reactCursor, -1);
    final int maxId = await dao.maxEventId();
    if (cursor < 0) {
      // 第一次：只定起点，不翻旧账。
      await dao.setSetting(EnemySettings.reactCursor, '$maxId');
      _why = 'baseline';
      return null;
    }

    final bool quiet = !force && await engine.inQuietHours();
    final bool capped = !force && await _capReached(now);
    final bool tooSoon = !force && await _tooSoon(now);

    final List<EnemyEvent> fresh =
        maxId > cursor ? await dao.eventsAfterId(cursor, limit: 100) : <EnemyEvent>[];

    // 静默时段和上限：这批事件不再触发插话（它们仍是证据）。
    // 间隔太近：不动游标，下一轮再说。
    if (tooSoon && !quiet && !capped) {
      _why = 'too_soon';
      return null;
    }
    if (maxId > cursor) await dao.setSetting(EnemySettings.reactCursor, '$maxId');
    if (quiet) {
      _why = 'quiet';
      return null;
    }
    if (capped) {
      _why = 'capped';
      return null;
    }

    // 只对刚发生的事插话；字据类事件是被发现的那一刻产生的，不看时间。
    final List<EnemyEvent> timely = fresh
        .where((EnemyEvent e) =>
            e.source == 'commitment' || now - e.ts <= freshWindow.inMilliseconds)
        .toList();
    EnemyEvent? pick = _best(timely);
    // 其它模块只是有动静：只有字据还开着时才值得开口（点出「在忙别的」）。
    if (pick != null && pick.type == 'module_activity') {
      final List<EnemyCommitment> open = await dao.commitments(status: CommitmentStatus.open);
      if (open.isEmpty) pick = null;
    }
    if (pick != null) {
      _why = 'spoke';
      return _interject(pick, fresh);
    }
    final EnemyMessage? soon = await _dueSoon(now);
    _why = soon != null ? 'spoke' : 'no_new';
    return soon;
  }

  EnemyEvent? _best(List<EnemyEvent> events) {
    EnemyEvent? best;
    int bestScore = -1;
    for (final EnemyEvent e in events) {
      final int score = reactable[e.type] ?? -1;
      if (score > bestScore || (score == bestScore && best != null && e.ts >= best.ts)) {
        best = e;
        bestScore = score;
      }
    }
    return bestScore < 0 ? null : best;
  }

  Future<bool> _capReached(int now) async {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(now);
    final int startOfDay = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    final int cap = await dao.intSetting(EnemySettings.interjectCap, defaultInterjectCap);
    return await dao.messageCount(kind: MessageKind.interject, sinceMs: startOfDay) >= cap;
  }

  Future<bool> _tooSoon(int now) async {
    final int last = await dao.intSetting(EnemySettings.lastInterjectMs, 0);
    return last > 0 && now - last < minGap.inMilliseconds;
  }

  Future<EnemyMessage?> _interject(EnemyEvent e, List<EnemyEvent> fresh) async {
    String stake = '';
    String label = e.label;
    final Object? cid = e.payload['commitment_id'];
    if (cid is num) {
      final EnemyCommitment? c = await dao.commitment(cid.toInt());
      if (c != null) {
        stake = c.stake;
        if (label.trim().isEmpty) label = c.text;
      }
    }
    final Object? m = e.payload['minutes'];
    final int minutes = m is num ? m.round() : 0;

    final ({EnemyDigest digest, int intensity, String address}) snap = await _snapshot();
    final int others = fresh.where((EnemyEvent x) => x.id != e.id && reactable.containsKey(x.type)).length;
    final String situation = '刚刚发生了一件事，你要立刻开口：${_typeLabels[e.type] ?? e.type}'
        '${label.trim().isEmpty ? '' : '（对象：${label.trim()}）'}'
        '${minutes > 0 ? '，$minutes 分钟' : ''}'
        '${stake.isEmpty ? '' : '。这是一份有赌注的字据，赌注是「$stake」'}'
        '${others > 0 ? '。同一时间还有 $others 件别的事，只抓最重要的这一件' : ''}。';

    String openText = '';
    if (e.type == 'module_activity') {
      final List<EnemyCommitment> open = await dao.commitments(status: CommitmentStatus.open);
      if (open.isNotEmpty) openText = open.first.text;
    }

    final EnemyMessage msg = await _speak(
      snap: snap,
      situation: openText.isEmpty ? situation : '$situation 字据「$openText」还开着：点出他在忙别处，别替他找台阶。',
      userText: '',
      kind: MessageKind.interject,
      refId: e.id,
      fallback: () => e.type == 'module_activity'
          ? PersonaLines.activity(
              label: label,
              address: snap.address,
              openText: openText,
              seed: e.id,
            )
          : PersonaLines.interject(
              type: e.type,
              label: label,
              address: snap.address,
              tone: _tone(snap.intensity),
              minutes: minutes,
              stake: stake,
              seed: e.id,
            ),
    );
    await dao.setSetting(EnemySettings.lastInterjectMs, '${engine.nowMs()}');
    return msg;
  }

  Future<EnemyMessage?> _dueSoon(int now) async {
    final List<EnemyCommitment> open = await dao.commitments(status: CommitmentStatus.open);
    for (final EnemyCommitment c in open) {
      final int? due = c.dueMs;
      if (due == null || due <= now) continue;
      if (due - now > dueSoonWindow.inMilliseconds) continue;
      if (await dao.boolSetting(EnemySettings.warned(c.id))) continue;
      await dao.setBoolSetting(EnemySettings.warned(c.id), true);

      final int minutes = ((due - now) / 60000).ceil();
      final ({EnemyDigest digest, int intensity, String address}) snap = await _snapshot();
      final EnemyMessage msg = await _speak(
        snap: snap,
        situation: '字据「${c.text}」还剩 $minutes 分钟到期，还没兑现。'
            '${c.stake.isEmpty ? '' : '赌注是「${c.stake}」。'}提醒他，别替他做。',
        userText: '',
        kind: MessageKind.interject,
        fallback: () => PersonaLines.dueSoon(
          text: c.text,
          address: snap.address,
          minutes: minutes,
          seed: c.id,
        ),
      );
      await dao.setSetting(EnemySettings.lastInterjectMs, '${engine.nowMs()}');
      return msg;
    }
    return null;
  }

  // ------------------------------------------------------------------ patrol

  static const Set<String> _doneTypes = <String>{
    'habit_done',
    'kindling_completed',
    'commitment_done',
    'knowledge_converted',
  };
  static const Set<String> _missedTypes = <String>{
    'habit_missed',
    'kindling_aborted',
    'commitment_missed',
  };

  /// 主动巡查：没有人叫它，也没有新事件，它自己判断此刻该不该开口。
  ///
  /// 三件事：早上的晨报、晚上的结算、人在 App 里待了很久案卷里却没有新记录。
  /// 同样受静音、静默时段、每日上限、最小间隔约束，「主动巡查」开关可关。
  Future<EnemyMessage?> _patrol(PatrolContext ctx) async {
    if (await engine.isMuted()) {
      _why = 'muted';
      return null;
    }
    if (!await dao.boolSetting(EnemySettings.interject, fallback: true)) {
      _why = 'interject_off';
      return null;
    }
    if (!await dao.boolSetting(EnemySettings.patrol, fallback: true)) {
      _why = 'patrol_off';
      return null;
    }
    if (await engine.inQuietHours()) {
      _why = 'quiet';
      return null;
    }

    // 主动巡查有自己的节奏（一天一次 / 冷却），不占事件插话的每日上限，
    // 否则测试时把上限用光，晚间结算就再也不会开口。
    final int now = engine.nowMs();
    if (await _tooSoon(now)) {
      _why = 'too_soon';
      return null;
    }

    try {
      await engine.syncIfChanged();
      await engine.settleOverdue();
    } catch (_) {
      // 同步失败不拦巡查：用已有的案卷说话。
    }

    final DateTime dt = DateTime.fromMillisecondsSinceEpoch(now);
    final String day = EnemyEngine.dayKey(dt);
    final int quietEnd = await dao.intSetting(EnemySettings.quietEndHour, 7);
    final int quietStart = await dao.intSetting(EnemySettings.quietStartHour, 23);
    final int eveningHour = await dao.intSetting(EnemySettings.patrolHour, defaultPatrolHour);

    // 1) 晨报：安静时段结束后的第一次巡查。
    if (dt.hour >= quietEnd && dt.hour < 12) {
      final String key = EnemySettings.patrolDone('morning', day);
      if (!await dao.boolSetting(key)) {
        await dao.setBoolSetting(key, true);
        final _Facts f = await _facts(now);
        if (f.open > 0 || f.yesterdayDone + f.yesterdayMissed > 0) {
          _why = 'spoke';
          return _morningSay(f, dt);
        }
      }
    }

    // 2) 晚间结算：到了结算的钟点，还有账没平，或者今天一件完成的事都没有。
    if (dt.hour >= eveningHour && dt.hour < quietStart) {
      final String key = EnemySettings.patrolDone('evening', day);
      if (!await dao.boolSetting(key)) {
        final _Facts f = await _facts(now);
        if (f.open > 0 || f.doneToday == 0) {
          await dao.setBoolSetting(key, true);
          _why = 'spoke';
          return _eveningSay(f, dt);
        }
      }
    }

    // 3) 发呆：人在 App 里很久了，案卷里没有任何新记录，而字据还开着。
    final int? start = ctx.sessionStartMs;
    if (ctx.foreground && start != null) {
      final int minutes = ((now - start) / 60000).floor();
      if (minutes >= stallMinutes) {
        final int last = await dao.intSetting(EnemySettings.patrolStallMs, 0);
        if (last == 0 || now - last >= stallCooldown.inMilliseconds) {
          final List<EnemyEvent> since = await dao.eventsBetween(start, now + 1);
          final bool anyAction = since.any(
            (EnemyEvent e) => e.type != 'commitment_created' && reactable.containsKey(e.type),
          );
          final _Facts f = await _facts(now);
          if (!anyAction && f.open > 0 && f.nextText.isNotEmpty) {
            await dao.setSetting(EnemySettings.patrolStallMs, '$now');
            _why = 'spoke';
            return _stallSay(f, minutes, dt);
          }
        }
      }
    }
    // 4) 反对党：他一声不响的时候，敌人不跟着安静。
    final EnemyMessage? probe = await _oppose(now, dt);
    if (probe != null) return probe;

    // 事件那一步已经给出更有信息量的原因（比如「今天开口次数到上限」）就保留它。
    if (_why.isEmpty || _why == 'no_new' || _why == 'baseline') {
      if (_why != 'baseline') _why = 'patrol_idle';
    }
    return null;
  }

  // -------------------------------------------------------------- opposition

  static String _clipText(String t, int n) => t.length > n ? '${t.substring(0, n)}…' : t;

  /// 敌人最近一条还没被回应的质询或动议；没有则 null。
  Future<EnemyMessage?> _pendingInquiry() async {
    final EnemyMessage? last = await dao.latestMessage(
      kinds: <String>[MessageKind.inquiry, MessageKind.motion],
      role: MessageRole.enemy,
    );
    if (last == null) return null;
    if (await dao.userMessagesAfterId(last.id) > 0) return null;
    if (last.kind == MessageKind.motion && last.refId != null) {
      final EnemyMotion? m = await dao.motion(last.refId!);
      if (m != null && !m.isOpen) return null; // 已经接受或驳回，就是回应过了
    }
    return last;
  }

  Future<ProbeFacts> _probeFacts(int now, {required bool forDrill}) async {
    const int hourMs = 3600 * 1000;
    const int dayMs = 24 * hourMs;
    final DateTime dt = DateTime.fromMillisecondsSinceEpoch(now);
    final int startOfDay = DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch;

    final Map<String, bool> consents = await engine.consents();
    final List<EnemyEvent> events = await dao.eventsBetween(now - 14 * dayMs, now + 1);

    int knowledge24 = 0, actions24 = 0, habit7 = 0, lastKindling = 0, lastEventTs = 0;
    final Map<String, List<int>> activity = <String, List<int>>{};
    for (final EnemyEvent e in events) {
      if (e.ts > lastEventTs && e.source != 'commitment') lastEventTs = e.ts;
      final bool in24 = now - e.ts <= dayMs;
      if (e.type == 'knowledge_converted' && in24) knowledge24++;
      if (in24 && (e.type == 'habit_done' || e.type == 'kindling_completed' || e.type == 'commitment_done')) {
        actions24++;
      }
      if (e.source == 'habit' && now - e.ts <= 7 * dayMs) habit7++;
      if (e.type == 'kindling_completed' && e.ts > lastKindling) lastKindling = e.ts;
      if (e.source == 'activity') (activity[e.label] ??= <int>[]).add(e.ts);
    }

    final List<DormantModule> dormant = <DormantModule>[];
    activity.forEach((String label, List<int> stamps) {
      if (stamps.length < 3) return;
      final int last = stamps.reduce((int a, int b) => a > b ? a : b);
      final int days = ((now - last) / dayMs).floor();
      if (days >= Opposition.dormantAfterDays) dormant.add(DormantModule(label, days));
    });
    dormant.sort((DormantModule a, DormantModule b) => b.days.compareTo(a.days));

    final List<EnemyCommitment> all = await dao.commitments(limit: 300);
    final int open = all.where((EnemyCommitment c) => c.status == CommitmentStatus.open).length;
    final int created24 = all.where((EnemyCommitment c) => now - c.createdMs <= dayMs).length;
    final int done7 = all
        .where((EnemyCommitment c) => c.status == CommitmentStatus.done && now - c.createdMs <= 7 * dayMs)
        .length;

    EnemyLesson? repeated;
    for (final EnemyLesson l in await dao.lessons(limit: 20)) {
      if (l.timesRepeated >= 2) {
        repeated = l;
        break;
      }
    }
    EnemyVerdict? ignored;
    for (final EnemyVerdict v in await dao.recentVerdicts(limit: 10)) {
      if (v.userResponse == VerdictResponse.pending &&
          now - v.ts >= Opposition.ignoredVerdictAfterHours * hourMs) {
        ignored = v;
        break;
      }
    }

    final List<EnemyMotion> motions = await dao.motionsSince(now - 7 * dayMs);
    final int rejected7 = motions.where((EnemyMotion m) => m.status == MotionStatus.rejected).length;
    final int accepted7 = motions.where((EnemyMotion m) => m.status == MotionStatus.accepted).length;
    final int motionsToday = motions.where((EnemyMotion m) => m.ts >= startOfDay).length;
    final bool hasOpenMotion = await dao.openMotion() != null;
    final int motionCap = await dao.intSetting(EnemySettings.motionCap, defaultMotionCap);

    // 动议的截止时间：3 小时后，但不晚于静默时段开始前半小时；离得太近就不提动议。
    final int quietStart = await dao.intSetting(EnemySettings.quietStartHour, 23);
    int due = now + 3 * hourMs;
    final int latest = DateTime(dt.year, dt.month, dt.day, quietStart).millisecondsSinceEpoch - 30 * 60 * 1000;
    if (due > latest) due = latest;
    final int motionDue = due - now >= 30 * 60 * 1000 ? due : 0;

    final EnemyMessage? pending = await _pendingInquiry();
    final int follow = pending == null ? 0 : await dao.intSetting(EnemySettings.inquiryFollow(pending.id), 0);

    final Map<String, int> lastProbe = <String, int>{};
    if (!forDrill) {
      for (final String type in Opposition.cooldownHours.keys) {
        lastProbe[type] = await dao.intSetting(EnemySettings.probeLast(type), 0);
      }
    }

    return ProbeFacts(
      nowMs: now,
      consentKindling: consents['kindling'] ?? false,
      consentHabit: consents['habit'] ?? false,
      consentKnowledge: consents['knowledge'] ?? false,
      openCommitments: open,
      createdLast24h: created24,
      lastKindlingCompletedMs: lastKindling,
      knowledge24h: knowledge24,
      actions24h: actions24,
      habitEvents7d: habit7,
      dormant: dormant,
      repeatedLesson: repeated,
      ignoredVerdict: ignored,
      rejected7d: rejected7,
      accepted7d: accepted7,
      done7d: done7,
      unanswered: pending,
      unansweredFollowUps: follow,
      silentHours: lastEventTs == 0 ? 24 : ((now - lastEventTs) / hourMs).floor(),
      motionDueMs: forDrill ? 0 : motionDue,
      motionAllowed: !forDrill && !hasOpenMotion && motionsToday < motionCap,
      lastProbeMs: lastProbe,
    );
  }

  /// 反对党：主动质询、提动议。沉默不是好结果。
  /// 有自己的节奏——两次之间至少隔 [defaultProbeGapMin] 分钟（可调），一天有上限。
  Future<EnemyMessage?> _oppose(int now, DateTime dt) async {
    if (!await dao.boolSetting(EnemySettings.opposition, fallback: true)) {
      _why = 'opposition_off';
      return null;
    }
    final int gapMin = await dao.intSetting(EnemySettings.probeGapMin, defaultProbeGapMin);
    final int lastProbe = await dao.intSetting(EnemySettings.probeGlobalMs, 0);
    if (lastProbe > 0 && now - lastProbe < gapMin * 60 * 1000) {
      _why = 'probe_wait';
      return null;
    }
    final int startOfDay = DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch;
    final int cap = await dao.intSetting(EnemySettings.probeCap, defaultProbeCap);
    final int today = await dao.messageCountOfKinds(
      <String>[MessageKind.inquiry, MessageKind.motion],
      sinceMs: startOfDay,
    );
    if (today >= cap) {
      _why = 'probe_capped';
      return null;
    }

    final ProbeFacts facts = await _probeFacts(now, forDrill: false);
    final ProbePlan? plan = Opposition.choose(facts);
    if (plan == null) {
      _why = 'probe_wait';
      return null;
    }
    _why = 'spoke';
    final EnemyMessage msg = await _probeSay(plan, now, drill: false);
    await dao.setSetting(EnemySettings.probeGlobalMs, '$now');
    await dao.setSetting(EnemySettings.probeLast(plan.type), '$now');
    await dao.setSetting(EnemySettings.lastInterjectMs, '$now');
    if (plan.followUpOf != null) {
      // 追问本身又是一条新的质询：把已追问次数传给它，否则链条永远断不了。
      final int prev = await dao.intSetting(EnemySettings.inquiryFollow(plan.followUpOf!), 0);
      await dao.setSetting(EnemySettings.inquiryFollow(msg.id), '${prev + 1}');
    }
    return msg;
  }

  String _dueText(int dueMs) {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(dueMs);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
  }

  Future<EnemyMessage> _probeSay(ProbePlan plan, int now, {required bool drill}) async {
    final ({EnemyDigest digest, int intensity, String address}) snap = await _snapshot();
    final MotionPlan? mp = drill ? null : plan.motion;
    int? motionId;
    if (mp != null) {
      motionId = await dao.insertMotion(
        ts: now,
        kind: mp.kind,
        text: mp.text,
        dueMs: mp.dueMs,
        needsText: mp.needsText,
        verify: mp.verify,
      );
    }
    final int tone = _tone(snap.intensity);
    return _speak(
      snap: snap,
      situation: plan.situation,
      userText: '',
      kind: drill ? MessageKind.drill : (mp != null ? MessageKind.motion : MessageKind.inquiry),
      refId: motionId,
      prefix: drill ? drillPrefix : '',
      fallback: () => mp != null
          ? '${PersonaLines.probe(
              type: plan.type,
              address: snap.address,
              tone: tone,
              n: plan.n,
              m: plan.m,
              hours: plan.hours,
              days: plan.days,
              label: plan.label,
              text: plan.text,
              category: plan.category,
              seed: now ~/ 60000,
            )}\n${PersonaLines.motion(
              address: snap.address,
              text: mp.text,
              dueText: _dueText(mp.dueMs),
              tone: tone,
              seed: now ~/ 60000,
            )}'
          : PersonaLines.probe(
              type: plan.type,
              address: snap.address,
              tone: tone,
              n: plan.n,
              m: plan.m,
              hours: plan.hours,
              days: plan.days,
              label: plan.label,
              text: plan.text,
              category: plan.category,
              seed: now ~/ 60000,
            ),
    );
  }

  // ----------------------------------------------------------------- motions

  /// 接受动议：立成字据（带你选的赌注）。需要你亲手写具体内容的动议，[text] 必填。
  Future<MotionResult> acceptMotion(int id, {String text = '', String stake = ''}) async {
    final EnemyMotion? m = await dao.motion(id);
    if (m == null || !m.isOpen) return const MotionResult(note: '这项动议已经处理过了。');
    final String content = m.needsText ? text.trim() : m.text;
    if (content.isEmpty) return const MotionResult(note: '这项动议要你写下具体做什么。');
    final ({int? id, bool crisis, String? error}) r = await engine.addCommitment(
      content,
      due: DateTime.fromMillisecondsSinceEpoch(m.dueMs),
      stake: stake,
      origin: 'motion',
      verify: m.verify,
    );
    if (r.crisis) return const MotionResult(crisis: true, note: EnemyCopy.crisisMessage);
    if (r.error != null || r.id == null) return MotionResult(note: r.error ?? '没立成。');
    await dao.setMotionStatus(id, MotionStatus.accepted, commitmentId: r.id);
    final ({EnemyDigest digest, int intensity, String address}) snap = await _snapshot();
    final EnemyMessage msg = await _speak(
      snap: snap,
      situation: '他接受了你的动议，字据已立：「$content」，${_dueText(m.dueMs)}前。'
          '${stake.trim().isEmpty ? '' : '赌注是「${stake.trim()}」。'}一句话认下，提醒你到期会来对账。',
      userText: '',
      kind: MessageKind.chat,
      fallback: () => PersonaLines.motionAccepted(
        address: snap.address,
        text: content,
        dueText: _dueText(m.dueMs),
        stake: stake,
      ),
    );
    return MotionResult(ok: true, enemy: msg);
  }

  /// 驳回动议：必须给理由，敌人当场反驳，动议不撤。
  Future<MotionResult> rejectMotion(int id, String reason) async {
    final EnemyMotion? m = await dao.motion(id);
    if (m == null || !m.isOpen) return const MotionResult(note: '这项动议已经处理过了。');
    final String text = reason.trim();
    if (text.length < 4) return const MotionResult(note: '驳回要给理由，写一句具体的话。');
    if (SafetyValve.shouldMute(text)) {
      final bool crisis = SafetyValve.isCrisis(text);
      await engine.muteFor24h(crisis: crisis);
      final EnemyMessage exit = await _store(
        role: MessageRole.enemy,
        kind: MessageKind.exit,
        text: crisis ? EnemyCopy.crisisMessage : EnemyCopy.truceAcknowledged,
      );
      return MotionResult(crisis: crisis, enemy: exit);
    }
    await dao.setMotionStatus(id, MotionStatus.rejected, responseText: text);
    await _store(role: MessageRole.user, kind: MessageKind.chat, text: _clipText(text, maxUserChars));
    final ({EnemyDigest digest, int intensity, String address}) snap = await _snapshot();
    final EnemyMessage msg = await _speak(
      snap: snap,
      situation: '他驳回了你的动议「${m.text}」，理由是：「${_clipText(text, 80)}」。'
          '反驳他的理由（不是他这个人），动议你保留。一句话。',
      userText: text,
      kind: MessageKind.chat,
      fallback: () => PersonaLines.rebut(address: snap.address, reason: text, seed: id),
    );
    return MotionResult(ok: true, enemy: msg);
  }

  static const String drillPrefix = '【演练】';

  Future<EnemyMessage> _morningSay(
    _Facts f,
    DateTime dt, {
    String prefix = '',
    bool touch = true,
    String kind = MessageKind.interject,
  }) {
    return _patrolSay(
      situation: '早上了，你主动开口做晨报。昨天完成 ${f.yesterdayDone} 件、失败 ${f.yesterdayMissed} 件；'
          '今天开着 ${f.open} 条字据${f.nextText.isEmpty ? '' : '，最近的是「${f.nextText}」'}。'
          '像对手那样开场：报账，不寒暄，不鼓励。',
      fallback: (String a, int tone) => PersonaLines.morningBrief(
        address: a,
        open: f.open,
        nextText: f.nextText,
        yesterdayDone: f.yesterdayDone,
        yesterdayMissed: f.yesterdayMissed,
        seed: dt.day,
      ),
      prefix: prefix,
      touch: touch,
      kind: kind,
    );
  }

  Future<EnemyMessage> _eveningSay(
    _Facts f,
    DateTime dt, {
    String prefix = '',
    bool touch = true,
    String kind = MessageKind.interject,
  }) {
    return _patrolSay(
      situation: '晚间结算，你主动开口。今天完成 ${f.doneToday} 件、失败 ${f.missedToday} 件；'
          '还开着 ${f.open} 条字据${f.nextText.isEmpty ? '' : '，最近的是「${f.nextText}」'}。'
          '盘点，催他，别替他找台阶。',
      fallback: (String a, int tone) => PersonaLines.eveningLedger(
        address: a,
        open: f.open,
        nextText: f.nextText,
        doneToday: f.doneToday,
        seed: dt.day,
      ),
      prefix: prefix,
      touch: touch,
      kind: kind,
    );
  }

  Future<EnemyMessage> _stallSay(
    _Facts f,
    int minutes,
    DateTime dt, {
    String prefix = '',
    bool touch = true,
    String kind = MessageKind.interject,
  }) {
    return _patrolSay(
      situation: '他在 App 里已经待了 $minutes 分钟，这段时间案卷里没有任何新记录，'
          '而字据「${f.nextText}」还开着。指出账上没有，别评价他这个人。',
      fallback: (String a, int tone) => PersonaLines.stall(
        address: a,
        minutes: minutes,
        openText: f.nextText,
        seed: dt.hour,
      ),
      prefix: prefix,
      touch: touch,
      kind: kind,
    );
  }

  /// 演练：不看时段、不看今天做过没有、不占任何计数，把一种主动行为真实地走一遍，
  /// 让你亲眼确认它能工作。消息会进时间线，前面带「【演练】」。
  /// 用的是真实的案卷和字据；静音时不演练。
  Future<DrillResult> drill(String kind) async {
    if (await engine.isMuted()) {
      return const DrillResult(note: '敌人已静音，先在设置里取消静音。');
    }
    final int now = engine.nowMs();
    final DateTime dt = DateTime.fromMillisecondsSinceEpoch(now);
    try {
      await engine.syncIfChanged();
      await engine.settleOverdue();
    } catch (_) {
      // 同步失败也演练：用已有的案卷。
    }
    final _Facts f = await _facts(now);
    switch (kind) {
      case 'morning':
        return DrillResult(message: await _morningSay(f, dt, prefix: drillPrefix, touch: false, kind: MessageKind.drill));
      case 'evening':
        return DrillResult(message: await _eveningSay(f, dt, prefix: drillPrefix, touch: false, kind: MessageKind.drill));
      case 'stall':
        if (f.nextText.isEmpty) {
          return const DrillResult(note: '没有开着的字据，发呆检查没有可以点名的东西。先在「字据」里立一条。');
        }
        return DrillResult(
          message: await _stallSay(
            f,
            stallMinutes + 5,
            dt,
            prefix: drillPrefix,
            touch: false,
            kind: MessageKind.drill,
          ),
        );
      case 'probe':
        {
          // 质询演练：不看间隔和冷却，不提动议（免得留下一项真的待决动议）。
          final ProbeFacts facts = await _probeFacts(now, forDrill: true);
          final ProbePlan? plan = Opposition.choose(facts);
          if (plan == null) return const DrillResult(note: '没有可以质询的事。');
          return DrillResult(message: await _probeSay(plan, now, drill: true));
        }
      default:
        return const DrillResult(note: '不认识的演练。');
    }
  }

  // ------------------------------------------------------------------ status

  /// 自检：它此刻在不在、看得到什么、为什么没说话、各种主动行为的条件满足了几项。
  /// 全部是读，不改任何东西。
  Future<EnemyStatus> status() async {
    final int now = engine.nowMs();
    final DateTime dt = DateTime.fromMillisecondsSinceEpoch(now);
    final String day = EnemyEngine.dayKey(dt);
    final int startOfDay = DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch;
    int age(int ms) => ms <= 0 ? -1 : ((now - ms) / 1000).round();

    final Map<String, bool> consents = await engine.consents();
    final Map<String, int> counts = await dao.eventCountsBySource();
    final List<EnemyEvent> recent = await dao.recentEvents(limit: 400);
    final Map<String, int> lastBySource = <String, int>{};
    for (final EnemyEvent e in recent) {
      lastBySource.putIfAbsent(e.source, () => e.ts);
    }

    final int last = await dao.intSetting(EnemySettings.lastInterjectMs, 0);
    final int gapLeft = last <= 0
        ? 0
        : ((minGap.inMilliseconds - (now - last)) / 1000).ceil().clamp(0, minGap.inSeconds);
    final int stallLast = await dao.intSetting(EnemySettings.patrolStallMs, 0);
    final int stallLeft = stallLast <= 0
        ? 0
        : ((stallCooldown.inMilliseconds - (now - stallLast)) / 1000)
            .ceil()
            .clamp(0, stallCooldown.inSeconds);
    final int mutedUntil = await dao.intSetting(EnemySettings.mutedUntilMs, 0);

    return EnemyStatus(
      nowMs: now,
      muted: mutedUntil > now,
      interject: await dao.boolSetting(EnemySettings.interject, fallback: true),
      everywhere: await dao.boolSetting(EnemySettings.interjectEverywhere, fallback: true),
      patrol: await dao.boolSetting(EnemySettings.patrol, fallback: true),
      quiet: await engine.inQuietHours(),
      quietStart: await dao.intSetting(EnemySettings.quietStartHour, 23),
      quietEnd: await dao.intSetting(EnemySettings.quietEndHour, 7),
      capUsed: await dao.messageCount(kind: MessageKind.interject, sinceMs: startOfDay),
      capMax: await dao.intSetting(EnemySettings.interjectCap, defaultInterjectCap),
      gapRemainingSec: gapLeft,
      heartbeatAgeSec: age(await dao.intSetting(EnemySettings.heartbeatMs, 0)),
      lastStepAgeSec: age(await dao.intSetting(EnemySettings.lastStepMs, 0)),
      lastWhy: await dao.getSetting(EnemySettings.lastWhy) ?? '',
      morningDone: await dao.boolSetting(EnemySettings.patrolDone('morning', day)),
      eveningDone: await dao.boolSetting(EnemySettings.patrolDone('evening', day)),
      patrolHour: await dao.intSetting(EnemySettings.patrolHour, defaultPatrolHour),
      stallCooldownSec: stallLeft,
      usageMinutes: (await dao.usageFor(day)).minutes,
      cursor: await dao.intSetting(EnemySettings.reactCursor, -1),
      maxEventId: await dao.maxEventId(),
      sources: <SourceStatus>[
        for (final s0 in engine.sources)
          SourceStatus(
            id: s0.id,
            label: s0.label,
            consented: consents[s0.id] ?? false,
            events: counts[s0.id] ?? 0,
            lastEventAgeSec: age(lastBySource[s0.id] ?? 0),
          ),
      ],
      opposition: await dao.boolSetting(EnemySettings.opposition, fallback: true),
      probeGapMin: await dao.intSetting(EnemySettings.probeGapMin, defaultProbeGapMin),
      probeAgeSec: age(await dao.intSetting(EnemySettings.probeGlobalMs, 0)),
      probesToday: await dao.messageCountOfKinds(
        <String>[MessageKind.inquiry, MessageKind.motion],
        sinceMs: startOfDay,
      ),
      probeCap: await dao.intSetting(EnemySettings.probeCap, defaultProbeCap),
      openMotion: await dao.openMotion() != null,
      bgScheduledAgeSec: age(await dao.intSetting(EnemySettings.bgScheduledMs, 0)),
      bgScheduleError: await dao.getSetting(EnemySettings.bgScheduleError) ?? '',
      bgLastRunAgeSec: age(await dao.intSetting(EnemySettings.bgLastRunMs, 0)),
      bgLastNote: await dao.getSetting(EnemySettings.bgLastNote) ?? '',
    );
  }

  Future<EnemyMessage> _patrolSay({
    required String situation,
    required String Function(String address, int tone) fallback,
    String prefix = '',
    bool touch = true,
    String kind = MessageKind.interject,
  }) async {
    final ({EnemyDigest digest, int intensity, String address}) snap = await _snapshot();
    final EnemyMessage msg = await _speak(
      snap: snap,
      situation: situation,
      userText: '',
      kind: kind,
      fallback: () => fallback(snap.address, _tone(snap.intensity)),
      prefix: prefix,
    );
    if (touch) await dao.setSetting(EnemySettings.lastInterjectMs, '${engine.nowMs()}');
    return msg;
  }

  Future<_Facts> _facts(int now) async {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(now);
    final int todayStart = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    final int yesterdayStart = todayStart - const Duration(days: 1).inMilliseconds;

    final List<EnemyCommitment> open = await dao.commitments(status: CommitmentStatus.open);
    EnemyCommitment? next;
    for (final EnemyCommitment c in open) {
      if (c.dueMs == null) continue;
      if (next == null || c.dueMs! < next.dueMs!) next = c;
    }

    final List<EnemyEvent> today = await dao.eventsBetween(todayStart, now + 1);
    final List<EnemyEvent> yesterday = await dao.eventsBetween(yesterdayStart, todayStart);
    int count(List<EnemyEvent> es, Set<String> types) =>
        es.where((EnemyEvent e) => types.contains(e.type)).length;

    return _Facts(
      open: open.length,
      nextText: next?.text ?? (open.isEmpty ? '' : open.first.text),
      doneToday: count(today, _doneTypes),
      missedToday: count(today, _missedTypes),
      yesterdayDone: count(yesterday, _doneTypes),
      yesterdayMissed: count(yesterday, _missedTypes),
    );
  }

  // ----------------------------------------------------------------- helpers

  Future<({EnemyDigest digest, int intensity, String address})> _snapshot() async {
    try {
      await engine.syncIfChanged();
      await engine.settleOverdue();
    } catch (_) {
      // 同步失败不该让敌人哑掉：用已有的案卷说话。
    }
    return engine.snapshot();
  }

  /// 用 1..3 档的台词；休战日（0 档）按 1 档的克制口吻。
  int _tone(int intensity) => intensity < 1 ? 1 : (intensity > 3 ? 3 : intensity);

  /// 先让模型说；说不出或不合规（重试一次）就用本地台词。
  Future<EnemyMessage> _speak({
    required ({EnemyDigest digest, int intensity, String address}) snap,
    required String situation,
    required String userText,
    required String kind,
    required String Function() fallback,
    int? refId,
    String prefix = '',
  }) async {
    String? line;
    final EnemyTalker? t = talker;
    if (t != null) {
      final List<EnemyMessage> history = await dao.recentMessages(limit: historyTurns);
      for (int attempt = 0; attempt < 2 && line == null; attempt++) {
        String? raw;
        try {
          raw = await t
              .talk(
                digest: snap.digest.json,
                history: history,
                situation: situation,
                userText: userText,
                intensity: snap.intensity,
                address: snap.address,
                nowMs: engine.nowMs(),
              )
              .timeout(EnemyEngine.oracleTimeout);
        } catch (_) {
          raw = null;
        }
        // 模型没产出（不可用、超时）就不再重试。
        if (raw == null) break;
        final String cleaned = raw.trim();
        if (engine.validator.validateLine(cleaned, maxTone: snap.intensity).isEmpty) {
          line = cleaned;
        }
      }
    }
    line ??= fallback();
    return _store(
      role: MessageRole.enemy,
      kind: kind,
      text: '$prefix$line',
      refId: refId,
      tone: snap.intensity,
    );
  }
}

class _Facts {
  const _Facts({
    required this.open,
    required this.nextText,
    required this.doneToday,
    required this.missedToday,
    required this.yesterdayDone,
    required this.yesterdayMissed,
  });

  final int open;
  final String nextText;
  final int doneToday;
  final int missedToday;
  final int yesterdayDone;
  final int yesterdayMissed;
}

/// 一次演练的结果：要么产生了一条消息，要么说明为什么做不了。
class DrillResult {
  const DrillResult({this.message, this.note = ''});

  final EnemyMessage? message;
  final String note;
}

class SourceStatus {
  const SourceStatus({
    required this.id,
    required this.label,
    required this.consented,
    required this.events,
    required this.lastEventAgeSec,
  });

  final String id;
  final String label;
  final bool consented;
  final int events;

  /// 最近一条证据距今多少秒；没有则为 -1。
  final int lastEventAgeSec;
}

/// 自检的快照。年龄类字段为 -1 表示「从来没有」。
class EnemyStatus {
  const EnemyStatus({
    required this.nowMs,
    required this.muted,
    required this.interject,
    required this.everywhere,
    required this.patrol,
    required this.quiet,
    required this.quietStart,
    required this.quietEnd,
    required this.capUsed,
    required this.capMax,
    required this.gapRemainingSec,
    required this.heartbeatAgeSec,
    required this.lastStepAgeSec,
    required this.lastWhy,
    required this.morningDone,
    required this.eveningDone,
    required this.patrolHour,
    required this.stallCooldownSec,
    required this.usageMinutes,
    required this.cursor,
    required this.maxEventId,
    required this.sources,
    required this.opposition,
    required this.probeGapMin,
    required this.probeAgeSec,
    required this.probesToday,
    required this.probeCap,
    required this.openMotion,
    required this.bgScheduledAgeSec,
    required this.bgScheduleError,
    required this.bgLastRunAgeSec,
    required this.bgLastNote,
  });

  final int nowMs;
  final bool muted;
  final bool interject;
  final bool everywhere;
  final bool patrol;
  final bool quiet;
  final int quietStart;
  final int quietEnd;
  final int capUsed;
  final int capMax;
  final int gapRemainingSec;

  /// 前台心跳距今多少秒：说明 App 前台的敌人还在不在跑。
  final int heartbeatAgeSec;
  final int lastStepAgeSec;

  /// 最近一步的结论代码，见 [whyText]。
  final String lastWhy;
  final bool morningDone;
  final bool eveningDone;
  final int patrolHour;
  final int stallCooldownSec;
  final int usageMinutes;
  final int cursor;
  final int maxEventId;
  final List<SourceStatus> sources;
  final bool opposition;
  final int probeGapMin;

  /// 上一次主动质询距今多少秒；从没有为 -1。
  final int probeAgeSec;
  final int probesToday;
  final int probeCap;

  /// 有没有一项还没被接受或驳回的动议。
  final bool openMotion;
  final int bgScheduledAgeSec;
  final String bgScheduleError;
  final int bgLastRunAgeSec;
  final String bgLastNote;

  /// 把结论代码翻成人话。
  static String whyText(String code) {
    switch (code) {
      case 'spoke':
        return '刚刚开过口';
      case 'no_new':
        return '看过了，没有新动静';
      case 'baseline':
        return '刚上线，先记下起点，之后的新动静才会接话';
      case 'muted':
        return '已静音';
      case 'interject_off':
        return '「实时插话」是关着的';
      case 'patrol_off':
        return '「主动巡查」是关着的';
      case 'quiet':
        return '静默时段，不开口';
      case 'capped':
        return '今天开口次数到上限了';
      case 'too_soon':
        return '刚说过话，间隔没到';
      case 'patrol_idle':
        return '没有该主动说的事（晨报、结算、发呆的条件都没满足）';
      case 'opposition_off':
        return '「反对党质询」是关着的';
      case 'probe_wait':
        return '质询的间隔没到（两次主动质询之间要隔一段时间）';
      case 'probe_capped':
        return '今天的主动质询次数到上限了';
      case '':
        return '还没有记录';
      default:
        return code;
    }
  }
}

/// 动议的处理结果。
class MotionResult {
  const MotionResult({this.ok = false, this.note = '', this.enemy, this.crisis = false});

  final bool ok;

  /// 没处理成时的说明。
  final String note;

  /// 敌人接话的那条消息。
  final EnemyMessage? enemy;

  /// 你写的理由触发了安全阀：敌人已退场、静音。
  final bool crisis;
}
