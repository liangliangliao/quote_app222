import '../copy.dart';
import '../data/enemy_dao.dart';
import '../data/models.dart';
import '../enemy_talker.dart';
import '../persona.dart';
import 'digest_builder.dart';
import 'enemy_engine.dart';
import 'guard.dart';

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

/// 敌人的「在场」：对话、实时插话、开庭，都落在同一条消息时间线上。
///
/// 判词和事实仍然来自 [EnemyEngine]；这一层只负责让它像一个角色——
/// 会回话，会在你做了或没做某件事的几秒内开口，会在字据快到期时提醒你。
class EnemyPresence {
  EnemyPresence({required this.engine, this.talker});

  final EnemyEngine engine;
  final EnemyTalker? talker;

  EnemyDao get dao => engine.dao;

  static const Duration minGap = Duration(minutes: 5);
  static const Duration dueSoonWindow = Duration(minutes: 10);
  static const int defaultInterjectCap = 6;
  static const int historyTurns = 12;
  static const int maxUserChars = 500;

  /// 值得敌人开口的事件，数字越大越优先。
  static const Map<String, int> reactable = <String, int>{
    'commitment_missed': 100,
    'kindling_aborted': 80,
    'habit_missed': 70,
    'commitment_done': 60,
    'kindling_completed': 50,
    'habit_done': 40,
    'knowledge_converted': 30,
  };

  static const Map<String, String> _typeLabels = <String, String>{
    'commitment_missed': '字据到期没兑现',
    'commitment_done': '字据兑现了',
    'kindling_aborted': '火种中途退出',
    'kindling_completed': '火种十五分钟完成',
    'habit_missed': '习惯没完成',
    'habit_done': '习惯完成了',
    'knowledge_converted': '知识卡转成了行动步骤',
  };

  bool _reacting = false;

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
    final EnemyMessage user = await _store(
      role: MessageRole.user,
      kind: MessageKind.chat,
      text: clipped,
    );

    final ({EnemyDigest digest, int intensity, String address}) snap = await _snapshot();
    final EnemyMessage enemy = await _speak(
      snap: snap,
      situation: '用户在跟你说话。盘问他，别替他找台阶。',
      userText: clipped,
      kind: MessageKind.chat,
      fallback: () => PersonaLines.chat(
        address: snap.address,
        tone: _tone(snap.intensity),
        seed: user.id,
      ),
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
    try {
      return await _react(force);
    } finally {
      _reacting = false;
    }
  }

  Future<EnemyMessage?> _react(bool force) async {
    if (await engine.isMuted()) return null;
    if (!await dao.boolSetting(EnemySettings.interject, fallback: true)) return null;

    await engine.sync();
    await engine.settleOverdue();

    final int now = engine.nowMs();
    final int cursor = await dao.intSetting(EnemySettings.reactCursor, -1);
    final int maxId = await dao.maxEventId();
    if (cursor < 0) {
      // 第一次：只定起点，不翻旧账。
      await dao.setSetting(EnemySettings.reactCursor, '$maxId');
      return null;
    }

    final bool quiet = !force && await engine.inQuietHours();
    final bool capped = !force && await _capReached(now);
    final bool tooSoon = !force && await _tooSoon(now);

    final List<EnemyEvent> fresh =
        maxId > cursor ? await dao.eventsAfterId(cursor, limit: 100) : <EnemyEvent>[];

    // 静默时段和上限：这批事件不再触发插话（它们仍是证据）。
    // 间隔太近：不动游标，下一轮再说。
    if (tooSoon && !quiet && !capped) return null;
    if (maxId > cursor) await dao.setSetting(EnemySettings.reactCursor, '$maxId');
    if (quiet || capped) return null;

    final EnemyEvent? pick = _best(fresh);
    if (pick != null) return _interject(pick, fresh);
    return _dueSoon(now);
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

    final EnemyMessage msg = await _speak(
      snap: snap,
      situation: situation,
      userText: '',
      kind: MessageKind.interject,
      refId: e.id,
      fallback: () => PersonaLines.interject(
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

  // ----------------------------------------------------------------- helpers

  Future<({EnemyDigest digest, int intensity, String address})> _snapshot() async {
    try {
      await engine.sync();
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
      text: line,
      refId: refId,
      tone: snap.intensity,
    );
  }
}
