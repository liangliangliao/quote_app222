import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../copy.dart';
import '../data/enemy_dao.dart';
import '../data/models.dart';
import '../domain/enemy_engine.dart';
import '../domain/enemy_presence.dart';
import '../domain/motivation_stimulus.dart';
import '../domain/evidence_source.dart';
import '../enemy_talker.dart';
import 'enemy_tabs.dart';
import 'ui_helpers.dart';

/// 对峙：和敌人在同一条时间线上说话。
///
/// 判词、插话、对话都是它的消息。页面打开期间每 30 秒看一眼有没有新事，
/// 你一做完或没做某件事，它几秒内就会开口。
class ThreadTab extends StatefulWidget {
  const ThreadTab({super.key, required this.presence, required this.voice});

  final EnemyPresence presence;
  final EnemyVoiceOut voice;

  @override
  State<ThreadTab> createState() => _ThreadTabState();
}

class _ThreadTabState extends State<ThreadTab> with WidgetsBindingObserver {
  /// 页面打开期间每 3 秒看一眼。靠来源的变更指纹保持便宜，不是每次都重读数据。
  static const Duration tick = Duration(seconds: 3);

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  List<EnemyMessage> _messages = <EnemyMessage>[];
  final Map<int, EnemyVerdict> _verdicts = <int, EnemyVerdict>{};
  final Map<int, EnemyCommitment> _commitments = <int, EnemyCommitment>{};
  final Map<int, EnemyMotion> _motions = <int, EnemyMotion>{};
  final Map<int, String> _stimulusStyles = <int, String>{};
  final Map<int, String> _stimulusFeedback = <int, String>{};
  int _latestVerdictId = -1;

  Timer? _timer;
  bool _sending = false;
  bool _courtBusy = false;
  bool _stimulating = false;
  bool _muted = false;
  bool _crisisNotice = false;
  bool _noConsent = false;
  List<String> _missingLabels = <String>[];
  String _brief = '';
  String _notice = '';
  String _statusLine = '';

  EnemyPresence get _presence => widget.presence;
  EnemyEngine get _engine => widget.presence.engine;
  EnemyDao get _dao => widget.presence.engine.dao;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    widget.voice.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  Future<void> _boot() async {
    // 先把定时器挂上：后面任何一步慢了或出错，都不能让它「永远不看」。
    _timer = Timer.periodic(tick, (_) => _tick());
    try {
      await _presence.ensureOpening();
      await _load();
    } catch (_) {
      // 加载失败也要让它继续看。
    }
    // 起点：此刻之前的事不翻旧账，之后的事它会立刻接话。
    unawaited(_tick());
  }

  int _ticks = 0;

  Future<void> _tick({bool force = false}) async {
    EnemyMessage? msg;
    try {
      msg = await _presence.step(force: force);
    } catch (_) {
      msg = null;
    }
    if (!mounted) return;
    // 状态行每 ~9 秒刷新一次，不必每次都查。
    if (++_ticks % 3 == 0 || msg != null) _refreshStatusLine();
    if (msg != null) {
      await _load();
      await _announce(msg);
    } else if (force) {
      await _load();
    }
  }

  /// 敌人开口：震一下，开了「出声」就念出来。
  Future<void> _announce(EnemyMessage msg) async {
    HapticFeedback.heavyImpact();
    if (await _dao.boolSetting(EnemySettings.voiceOut)) {
      await widget.voice.speak(msg.text);
    }
  }

  Future<void> _load() async {
    final List<EnemyMessage> messages = await _presence.thread();
    final Map<int, EnemyVerdict> verdicts = <int, EnemyVerdict>{};
    final Map<int, EnemyCommitment> commitments = <int, EnemyCommitment>{};
    final Map<int, EnemyMotion> motions = <int, EnemyMotion>{};
    int latest = -1;
    final Map<int, String> stimulusStyles = <int, String>{};
    final Map<int, String> stimulusFeedback = <int, String>{};
    for (final EnemyMessage m in messages) {
      final String style = await _presence.stimulusStyleFor(m.id);
      if (style.isNotEmpty) {
        stimulusStyles[m.id] = style;
        final String feedback = await _presence.stimulusFeedbackFor(m.id);
        if (feedback.isNotEmpty) stimulusFeedback[m.id] = feedback;
      }
      if (m.kind == MessageKind.motion && m.refId != null) {
        final EnemyMotion? mo = await _dao.motion(m.refId!);
        if (mo != null) motions[mo.id] = mo;
        continue;
      }
      if (m.kind != MessageKind.verdict || m.refId == null) continue;
      final EnemyVerdict? v = await _dao.verdict(m.refId!);
      if (v == null) continue;
      verdicts[v.id] = v;
      if (v.id > latest) latest = v.id;
      if (v.commitmentId != null) {
        final EnemyCommitment? c = await _dao.commitment(v.commitmentId!);
        if (c != null) commitments[v.id] = c;
      }
    }
    final bool muted = await _engine.isMuted();
    final bool crisis = await _dao.boolSetting(EnemySettings.crisisNoticePending);
    final Map<String, bool> consents = await _engine.consents();
    final String brief = await _engine.briefLine();
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _verdicts
        ..clear()
        ..addAll(verdicts);
      _commitments
        ..clear()
        ..addAll(commitments);
      _motions
        ..clear()
        ..addAll(motions);
      _stimulusStyles
        ..clear()
        ..addAll(stimulusStyles);
      _stimulusFeedback
        ..clear()
        ..addAll(stimulusFeedback);
      _latestVerdictId = latest;
      _muted = muted;
      _crisisNotice = crisis && muted;
      _noConsent = _engine.sources.isNotEmpty && !consents.values.any((bool b) => b);
      _missingLabels = _engine.sources
          .where((EvidenceSource s) => !(consents[s.id] ?? false))
          .map((EvidenceSource s) => s.label)
          .toList();
      _brief = brief;
    });
    _scrollToEnd();
  }

  Future<void> _refreshStatusLine() async {
    try {
      final EnemyStatus s = await _presence.status();
      final String why = EnemyStatus.whyText(s.lastWhy);
      if (!mounted) return;
      setState(() {
        _statusLine = '在线 · 看着 ${s.sources.where((SourceStatus x) => x.consented).length} 处 · '
            '今日开口 ${s.capUsed} 次 · $why';
      });
    } catch (_) {
      // 状态行拿不到就不显示。
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _snack(String text) {
    if (text.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ----------------------------------------------------------------- actions

  Future<void> _send() async {
    final String text = _input.text.trim();
    if (text.isEmpty || _sending || _muted) return;
    _input.clear();
    setState(() {
      _sending = true;
      _notice = '';
    });
    SayResult? r;
    try {
      r = await _presence.say(text);
    } catch (_) {
      _notice = '没送出去，稍后再试。';
    }
    if (!mounted) return;
    setState(() => _sending = false);
    await _load();
    final EnemyMessage? enemy = r?.enemy;
    if (enemy != null && r?.crisis != true) await _announce(enemy);
  }

  Future<void> _openCourt() async {
    setState(() {
      _courtBusy = true;
      _notice = '';
    });
    EnemyOutcome? outcome;
    try {
      outcome = await _presence.openCourt();
    } catch (_) {
      _notice = '开庭失败，稍后再试。';
    }
    if (!mounted) return;
    setState(() {
      _courtBusy = false;
      if (outcome != null && outcome.kind != EnemyOutcomeKind.verdict) {
        _notice = outcome.message;
      }
    });
    await _load();
    final EnemyVerdict? v = outcome?.verdict;
    if (v != null) {
      HapticFeedback.heavyImpact();
      if (await _dao.boolSetting(EnemySettings.voiceOut)) {
        await widget.voice.speak(v.charge);
      }
    }
  }

  /// 主动点火：不等巡查节奏，要求美丽的敌人现在给一次基于真实案卷的刺激。
  Future<void> _stimulate() async {
    if (_stimulating || _muted) return;
    setState(() {
      _stimulating = true;
      _notice = '';
    });
    EnemyMessage? msg;
    try {
      msg = await _presence.stimulateNow();
      if (msg == null) _notice = '现在没有足够的案卷事实可以发起有效刺激。';
    } catch (_) {
      _notice = '刺激失败，稍后再试。';
    }
    if (!mounted) return;
    setState(() => _stimulating = false);
    await _load();
    if (msg != null) await _announce(msg);
  }

  /// 喊停战：和对话里说「停战」走同一条路，敌人会在时间线上留一句退场的话。
  Future<void> _truce() async {
    await _presence.say('停战');
    await _load();
  }

  Future<void> _grantAll() async {
    await _engine.grantAll();
    await _engine.sync();
    await _load();
  }

  Future<void> _complete(EnemyCommitment c) async {
    await _engine.complete(c.id);
    await _tick(force: true);
  }

  Future<void> _failed(EnemyCommitment c) async {
    await attributeFlow(context, _engine, c);
    await _tick(force: true);
  }

  /// 接受动议：需要的话先写下具体做什么，再选一个赌注（可以不选）。
  Future<void> _acceptMotion(EnemyMotion m) async {
    String text = '';
    if (m.needsText) {
      final String? t = await askText(
        context,
        title: '动议：${m.text}',
        hint: '写下具体做什么',
        confirm: '下一步',
        maxLines: 2,
      );
      if (t == null) return;
      text = t;
      if (text.trim().isEmpty) {
        _snack('要写下具体做什么。');
        return;
      }
    }
    if (!mounted) return;
    final String? stake = await askText(
      context,
      title: '赌注（可以不写）',
      hint: '输了，我就去做什么（一个行动，不能伤害自己、羞辱自己、涉及钱）',
      confirm: '立字据',
      maxLines: 2,
    );
    if (stake == null) return;
    final MotionResult r = await _presence.acceptMotion(m.id, text: text, stake: stake);
    if (!r.ok) _snack(r.note);
    await _load();
    final EnemyMessage? enemy = r.enemy;
    if (enemy != null && !r.crisis) await _announce(enemy);
  }

  /// 用户可以自主拒绝，理由选填。
  Future<void> _rejectMotion(EnemyMotion m) async {
    final String? reason = await askText(
      context,
      title: '驳回「${m.text}」',
      hint: '可以说明困难或替代方案（选填）',
      confirm: '驳回',
      maxLines: 3,
    );
    if (reason == null) return;
    final MotionResult r = await _presence.rejectMotion(m.id, reason);
    if (!r.ok && r.enemy == null) _snack(r.note);
    await _load();
    final EnemyMessage? enemy = r.enemy;
    if (enemy != null && !r.crisis) await _announce(enemy);
  }

  Future<void> _appeal(EnemyVerdict v) async {
    final String? text = await askText(
      context,
      title: v.appealPrompt.isEmpty ? EnemyCopy.defaultAppealPrompt : v.appealPrompt,
      hint: '写一件具体的事',
      confirm: '申辩',
    );
    if (text == null) return;
    final ResponseResult r = await _engine.appeal(v.id, text);
    _snack(r.message);
    await _load();
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        if (_crisisNotice) _crisisCard(),
        if (_noConsent && !_crisisNotice) _consentCard(),
        if (!_noConsent && _missingLabels.isNotEmpty && !_crisisNotice) _missingCard(),
        if (_brief.isNotEmpty && !_crisisNotice)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _statusLine.isEmpty ? _brief : '$_brief\n$_statusLine',
                style: const TextStyle(color: kEnemyMuted, fontSize: 12, height: 1.5),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (BuildContext context, int i) {
              if (i >= _messages.length) return _typing();
              return _row(_messages[i]);
            },
          ),
        ),
        if (_muted && !_crisisNotice) _hint(EnemyCopy.mutedNote),
        if (_notice.isNotEmpty) _hint(_notice),
        _quickRow(),
        _inputRow(),
      ],
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text, style: const TextStyle(color: kEnemyMuted, fontSize: 13)),
        ),
      );

  Widget _crisisCard() => Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kEnemyCard, borderRadius: BorderRadius.circular(12)),
        child: const Text(
          EnemyCopy.crisisMessage,
          style: TextStyle(color: kEnemyText, height: 1.6),
        ),
      );

  Widget _consentCard() => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kEnemyCard, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '你还没有让我看任何模块的记录。看不到，我就没法当你的对手。',
              style: TextStyle(color: kEnemyText),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _grantAll, child: const Text('授权全部并同步')),
            const SizedBox(height: 4),
            const Text(
              '每个模块也可以在「设置」里单独开关。数据只存本机。',
              style: TextStyle(color: kEnemyMuted, fontSize: 12),
            ),
          ],
        ),
      );

  /// 已经授权了一部分、还有来源没授权：它看不到的地方就是它的死角。
  Widget _missingCard() => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kEnemyCard, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '还有 ${_missingLabels.length} 处我看不到：${_missingLabels.join('、')}。看不到的地方，就是你的死角。',
                style: const TextStyle(color: kEnemyMuted, fontSize: 12, height: 1.5),
              ),
            ),
            TextButton(onPressed: _grantAll, child: const Text('全部授权')),
          ],
        ),
      );

  Widget _typing() => const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text('……', style: TextStyle(color: kEnemyMuted, fontSize: 18)),
        ),
      );

  Widget _quickRow() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              ActionChip(
                label: Text(_courtBusy ? '开庭中…' : '开庭'),
                onPressed: (_courtBusy || _muted) ? null : _openCourt,
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.bolt_rounded, size: 17),
                label: Text(_stimulating ? '点火中…' : '刺激我'),
                onPressed: (_stimulating || _muted) ? null : _stimulate,
              ),
              const SizedBox(width: 8),
              ActionChip(label: const Text('停战'), onPressed: _muted ? null : _truce),
              const SizedBox(width: 8),
              ActionChip(
                label: const Text('太过了'),
                onPressed: () async {
                  await _engine.markTooMuch();
                  _snack('记下了，接下来几天会降一档。');
                },
              ),
            ],
          ),
        ),
      );

  Widget _inputRow() => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: !_muted,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(color: kEnemyText),
                  decoration: InputDecoration(
                    hintText: _muted ? '敌人已静音' : '说说你的处境、困惑或进展',
                    hintStyle: const TextStyle(color: kEnemyMuted),
                    filled: true,
                    fillColor: kEnemyCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: kEnemyAccent),
                onPressed: (_sending || _muted) ? null : _send,
              ),
            ],
          ),
        ),
      );

  // ---------------------------------------------------------------- bubbles

  Widget _row(EnemyMessage m) {
    if (m.kind == MessageKind.verdict) return _verdictBubble(m);
    if (m.kind == MessageKind.motion) return _motionBubble(m);
    final String stimulus = _stimulusStyles[m.id] ?? '';
    final bool mine = m.role == MessageRole.user;
    final double maxWidth = MediaQuery.of(context).size.width * 0.8;
    final bool drill = m.kind == MessageKind.drill;
    final bool inquiry = m.kind == MessageKind.inquiry;
    final bool interject = m.kind == MessageKind.interject || drill || inquiry;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF3A2C2A) : kEnemyCard,
          borderRadius: BorderRadius.circular(14),
          border: mine
              ? null
              : Border(left: BorderSide(color: interject ? kEnemyAccent : kEnemyMuted, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (stimulus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '动机刺激 · ${StimulusStyle.label(stimulus)}',
                  style: const TextStyle(color: kEnemyAccent, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              )
            else if (interject)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  drill ? '演练' : (inquiry ? '质询' : '敌人插话'),
                  style: const TextStyle(color: kEnemyAccent, fontSize: 11),
                ),
              ),
            Text(m.text, style: const TextStyle(color: kEnemyText, fontSize: 16, height: 1.55)),
            const SizedBox(height: 4),
            Text(fmtTime(m.ts), style: const TextStyle(color: kEnemyMuted, fontSize: 11)),
            if (stimulus.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              _stimulusControls(m),
            ],
          ],
        ),
      ),
    );
  }

  Widget _motionBubble(EnemyMessage m) {
    final EnemyMotion? mo = m.refId == null ? null : _motions[m.refId!];
    final double maxWidth = MediaQuery.of(context).size.width * 0.86;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kEnemyCard,
          borderRadius: BorderRadius.circular(14),
          border: const Border(left: BorderSide(color: kEnemyAccent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              (_stimulusStyles[m.id] ?? '').isEmpty
                  ? '动议'
                  : '动机刺激 · ${StimulusStyle.label(_stimulusStyles[m.id]!)}',
              style: const TextStyle(color: kEnemyAccent, fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(m.text, style: const TextStyle(color: kEnemyText, fontSize: 16, height: 1.55)),
            if (mo != null) ...<Widget>[
              const Divider(height: 20),
              Text('动议：${mo.text}', style: const TextStyle(color: kEnemyText)),
              const SizedBox(height: 2),
              Text(
                '限期 ${fmtTime(mo.dueMs)}',
                style: const TextStyle(color: kEnemyAccent, fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (mo.isOpen)
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    FilledButton(onPressed: () => _acceptMotion(mo), child: const Text('接受')),
                    OutlinedButton(onPressed: () => _rejectMotion(mo), child: const Text('驳回')),
                  ],
                )
              else
                Text(
                  mo.status == MotionStatus.accepted
                      ? '你接受了，已立为字据。'
                      : '你驳回了：${mo.responseText}',
                  style: const TextStyle(color: kEnemyMuted, fontSize: 13),
                ),
            ],
            const SizedBox(height: 4),
            Text(fmtTime(m.ts), style: const TextStyle(color: kEnemyMuted, fontSize: 11)),
            if ((_stimulusStyles[m.id] ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              _stimulusControls(m),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stimulusControls(EnemyMessage m) {
    final String feedback = _stimulusFeedback[m.id] ?? '';
    if (feedback.isNotEmpty) {
      final String label = switch (feedback) {
        StimulusFeedback.fired => '✓ 点着了',
        StimulusFeedback.flat => '没感觉',
        StimulusFeedback.tooMuch => '已降档 · 太过了',
        _ => feedback,
      };
      return Text('你的反馈：$label', style: const TextStyle(color: kEnemyMuted, fontSize: 12));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: <Widget>[
        ActionChip(
          visualDensity: VisualDensity.compact,
          label: const Text('点着了 · 现在做'),
          onPressed: () => _rateStimulus(m, StimulusFeedback.fired),
        ),
        ActionChip(
          visualDensity: VisualDensity.compact,
          label: const Text('没感觉'),
          onPressed: () => _rateStimulus(m, StimulusFeedback.flat),
        ),
        ActionChip(
          visualDensity: VisualDensity.compact,
          label: const Text('太过了'),
          onPressed: () => _rateStimulus(m, StimulusFeedback.tooMuch),
        ),
      ],
    );
  }

  Future<void> _rateStimulus(EnemyMessage m, String feedback) async {
    final bool ok = await _presence.rateStimulus(m.id, feedback);
    if (!mounted) return;
    if (!ok) {
      _snack('这次反馈没有记上。');
      return;
    }
    if (feedback == StimulusFeedback.fired) {
      HapticFeedback.mediumImpact();
      _snack('记下了：这种方式更可能点着你。现在别继续聊，去做第一个动作。');
    } else if (feedback == StimulusFeedback.flat) {
      _snack('记下了：下次降低这种刺激方式的优先级。');
    } else {
      _snack('记下了：这种方式降权，并触发自动降档。');
    }
    await _load();
  }

  Widget _verdictBubble(EnemyMessage m) {
    final EnemyVerdict? v = m.refId == null ? null : _verdicts[m.refId!];
    if (v == null) return _row(EnemyMessage(id: m.id, ts: m.ts, role: m.role, kind: MessageKind.chat, text: m.text));
    final EnemyCommitment? c = _commitments[v.id];
    final bool latest = v.id == _latestVerdictId;
    final int now = _engine.nowMs();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kEnemyCard,
        borderRadius: BorderRadius.circular(14),
        border: const Border(left: BorderSide(color: kEnemyAccent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${fmtTime(v.ts)} · 开庭${v.factOnly ? ' · 只报事实' : ' · ${v.intensity} 档'}',
            style: const TextStyle(color: kEnemyMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(v.charge, style: const TextStyle(color: kEnemyText, fontSize: 17, height: 1.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: <Widget>[
              for (final int id in v.evidenceIds)
                ActionChip(
                  label: Text('证据 #$id'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showEvidenceSheet(context, _engine, <int>[id]),
                ),
            ],
          ),
          const Divider(height: 22),
          Text('行动建议：${v.action}', style: const TextStyle(color: kEnemyText)),
          const SizedBox(height: 2),
          Text(
            '截止 ${fmtTime(v.actionDueMs)} · ${fmtRemaining(v.actionDueMs, now)}',
            style: const TextStyle(color: kEnemyAccent, fontSize: 13),
          ),
          if (v.lessonHint.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text('教训线索：${v.lessonHint}', style: const TextStyle(color: kEnemyMuted)),
          ],
          const SizedBox(height: 10),
          if (latest && c != null && c.status == CommitmentStatus.open)
            Wrap(
              spacing: 8,
              children: <Widget>[
                FilledButton(onPressed: () => _complete(c), child: const Text('我做完了')),
                OutlinedButton(onPressed: () => _failed(c), child: const Text('没做到')),
              ],
            ),
          if (c != null && c.status != CommitmentStatus.open)
            Text(
              '这条字据：${commitmentStatusLabels[c.status] ?? c.status}',
              style: const TextStyle(color: kEnemyMuted),
            ),
          if (latest && v.userResponse == VerdictResponse.pending)
            Wrap(
              spacing: 8,
              children: <Widget>[
                TextButton(
                  onPressed: () async {
                    final result = await _engine.acknowledge(v.id);
                    if (result.message.isNotEmpty) _snack(result.message);
                    await _load();
                  },
                  child: const Text('我选择接受这个行动'),
                ),
                TextButton(onPressed: () async {
                  await _engine.declineSuggestion(v.id);
                  await _load();
                }, child: const Text('暂不接受行动')),
                TextButton(onPressed: () => _appeal(v), child: const Text('补充事实 / 申辩')),
                TextButton(
                  onPressed: () async {
                    await _engine.markTooMuch();
                    _snack('记下了，接下来几天会降一档。');
                    await _load();
                  },
                  child: const Text('太过了'),
                ),
              ],
            )
          else if (v.userResponse != VerdictResponse.pending)
            Text(
              v.userResponse == VerdictResponse.appeal ? '你申辩了：${v.appealText}' : '你接受了这条判词。',
              style: const TextStyle(color: kEnemyMuted, fontSize: 13),
            ),
        ],
      ),
    );
  }
}
