import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/enemy_dao.dart';
import '../data/models.dart';
import '../domain/enemy_engine.dart';
import '../enemy_reminder.dart';
import 'enemy_tabs.dart';
import 'ui_helpers.dart';

class EnemyHomePage extends StatelessWidget {
  const EnemyHomePage({super.key, required this.engine, required this.reminder});

  final EnemyEngine engine;
  final EnemyReminder reminder;

  @override
  Widget build(BuildContext context) {
    final ThemeData base = ThemeData.dark();
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: kEnemyBg,
        colorScheme: base.colorScheme.copyWith(primary: kEnemyAccent),
      ),
      child: DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: kEnemyBg,
            foregroundColor: kEnemyText,
            title: const Text(EnemyCopy.title),
            bottom: const TabBar(
              isScrollable: true,
              indicatorColor: kEnemyAccent,
              tabs: <Tab>[
                Tab(text: '判词'),
                Tab(text: '案卷'),
                Tab(text: '承诺'),
                Tab(text: '教训'),
                Tab(text: '设置'),
              ],
            ),
          ),
          body: TabBarView(
            children: <Widget>[
              VerdictTab(engine: engine),
              DossierTab(engine: engine),
              CommitmentsTab(engine: engine),
              LessonsTab(engine: engine),
              SettingsTab(engine: engine, reminder: reminder),
            ],
          ),
        ),
      ),
    );
  }
}

class VerdictTab extends StatefulWidget {
  const VerdictTab({super.key, required this.engine});

  final EnemyEngine engine;

  @override
  State<VerdictTab> createState() => _VerdictTabState();
}

class _VerdictTabState extends State<VerdictTab> {
  EnemyVerdict? _verdict;
  EnemyCommitment? _commitment;
  bool _muted = false;
  bool _crisisNotice = false;
  bool _noConsent = false;
  bool _busy = false;
  String _message = '';

  EnemyEngine get _engine => widget.engine;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final EnemyVerdict? v = await _engine.dao.latestVerdict();
    EnemyCommitment? c;
    if (v?.commitmentId != null) c = await _engine.dao.commitment(v!.commitmentId!);
    final bool muted = await _engine.isMuted();
    final bool crisis = await _engine.dao.boolSetting(EnemySettings.crisisNoticePending);
    final Map<String, bool> consents = await _engine.consents();
    if (!mounted) return;
    setState(() {
      _verdict = v;
      _commitment = c;
      _muted = muted;
      _crisisNotice = crisis && muted;
      _noConsent = _engine.sources.isNotEmpty && !consents.values.any((bool b) => b);
    });
  }

  void _snack(String text) {
    if (text.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _judge() async {
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final EnemyOutcome outcome = await _engine.judge(trigger: 'manual', manual: true);
      if (outcome.kind != EnemyOutcomeKind.verdict) _message = outcome.message;
    } catch (_) {
      _message = '开庭失败，稍后再试。';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  Future<void> _grantAll() async {
    await _engine.grantAll();
    await _engine.sync();
    await _load();
  }

  Future<void> _truce() async {
    await _engine.truce();
    _snack(EnemyCopy.truceAcknowledged);
    await _load();
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

  Future<void> _complete(EnemyCommitment c) async {
    final String? msg = await _engine.complete(c.id);
    _snack(msg ?? '');
    await _load();
  }

  Future<void> _failed(EnemyCommitment c) async {
    await attributeFlow(context, _engine, c);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];

    if (_crisisNotice) {
      children.add(_card(
        child: const Text(
          EnemyCopy.crisisMessage,
          style: TextStyle(color: kEnemyText, height: 1.6),
        ),
      ));
    } else {
      children.add(Text(
        EnemyCopy.tagline,
        style: const TextStyle(color: kEnemyMuted, fontSize: 13),
      ));
      children.add(const SizedBox(height: 12));

      if (_noConsent) {
        children.add(_card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '还没有授权任何模块，敌人什么都看不到。',
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
        ));
        children.add(const SizedBox(height: 12));
      }

      children.add(Row(
        children: <Widget>[
          Expanded(
            child: FilledButton(
              onPressed: (_busy || _muted) ? null : _judge,
              child: Text(_busy ? '开庭中…' : '开庭'),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _muted ? null : _truce,
            child: const Text('停战'),
          ),
        ],
      ));
      children.add(const SizedBox(height: 12));

      if (_muted) children.add(_note(EnemyCopy.mutedNote));
      if (_message.isNotEmpty) children.add(_note(_message));

      final EnemyVerdict? v = _verdict;
      if (v == null) {
        children.add(_note('还没有判词。点「开庭」，敌人只会依据案卷里的证据发言。'));
      } else {
        children.add(_verdictCard(v));
      }
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: children),
    );
  }

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text, style: const TextStyle(color: kEnemyMuted)),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kEnemyCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );

  Widget _verdictCard(EnemyVerdict v) {
    final int now = _engine.nowMs();
    final EnemyCommitment? c = _commitment;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${fmtTime(v.ts)} · ${v.factOnly ? '事实播报' : '${v.intensity} 档'}',
            style: const TextStyle(color: kEnemyMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            v.charge,
            style: const TextStyle(color: kEnemyText, fontSize: 17, height: 1.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 0,
            children: <Widget>[
              for (final int id in v.evidenceIds)
                ActionChip(
                  label: Text('证据 #$id'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showEvidenceSheet(context, _engine, <int>[id]),
                ),
            ],
          ),
          const Divider(height: 24),
          Text('动作：${v.action}', style: const TextStyle(color: kEnemyText)),
          const SizedBox(height: 2),
          Text(
            '截止 ${fmtTime(v.actionDueMs)} · ${fmtRemaining(v.actionDueMs, now)}',
            style: const TextStyle(color: kEnemyAccent, fontSize: 13),
          ),
          if (v.lessonHint.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text('教训线索：${v.lessonHint}', style: const TextStyle(color: kEnemyMuted)),
          ],
          const SizedBox(height: 12),
          if (c != null && c.status == CommitmentStatus.open)
            Wrap(
              spacing: 8,
              children: <Widget>[
                FilledButton(onPressed: () => _complete(c), child: const Text('我做完了')),
                OutlinedButton(onPressed: () => _failed(c), child: const Text('没做到')),
              ],
            ),
          if (c != null && c.status != CommitmentStatus.open)
            Text(
              '这条承诺：${commitmentStatusLabels[c.status] ?? c.status}',
              style: const TextStyle(color: kEnemyMuted),
            ),
          const SizedBox(height: 8),
          if (v.userResponse == VerdictResponse.pending)
            Wrap(
              spacing: 8,
              children: <Widget>[
                TextButton(
                  onPressed: () async {
                    await _engine.acknowledge(v.id);
                    await _load();
                  },
                  child: const Text('接受'),
                ),
                TextButton(onPressed: () => _appeal(v), child: const Text('申辩')),
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
          else
            Text(
              v.userResponse == VerdictResponse.appeal
                  ? '你申辩了：${v.appealText}'
                  : '你接受了这条判词。',
              style: const TextStyle(color: kEnemyMuted, fontSize: 13),
            ),
        ],
      ),
    );
  }
}
