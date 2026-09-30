import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/enemy_dao.dart';
import '../data/models.dart';
import '../domain/enemy_engine.dart';
import '../domain/evidence_source.dart';
import '../enemy_reminder.dart';
import 'ui_helpers.dart';

/// 失败归因：先记为失效，再问原因。空话不收。
Future<void> attributeFlow(
  BuildContext context,
  EnemyEngine engine,
  EnemyCommitment c,
) async {
  if (c.status == CommitmentStatus.open) await engine.markMissed(c.id);
  if (!context.mounted) return;

  String category = EnemyCopy.failureCategories.first;
  final TextEditingController controller = TextEditingController();
  final bool? go = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      return StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setLocal) => AlertDialog(
          backgroundColor: kEnemyCard,
          title: const Text('为什么没做到？', style: TextStyle(color: kEnemyText, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(c.text, style: const TextStyle(color: kEnemyMuted)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: <Widget>[
                  for (final String cat in EnemyCopy.failureCategories)
                    ChoiceChip(
                      label: Text(cat),
                      selected: category == cat,
                      onSelected: (_) => setLocal(() => category = cat),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 3,
                minLines: 1,
                style: const TextStyle(color: kEnemyText),
                decoration: const InputDecoration(
                  hintText: '说一件具体发生的事，不要只写「忙」',
                  hintStyle: TextStyle(color: kEnemyMuted),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('记下')),
          ],
        ),
      );
    },
  );
  if (go != true || !context.mounted) return;

  final ({bool ok, String message, EnemyLesson? lesson, bool crisis}) r =
      await engine.attribute(
    commitmentId: c.id,
    category: category,
    reason: controller.text,
  );
  if (!context.mounted) return;
  if (r.crisis) {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: kEnemyCard,
        content: Text(r.message, style: const TextStyle(color: kEnemyText, height: 1.6)),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('好')),
        ],
      ),
    );
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
  if (!r.ok) {
    // 空话不收：让他重新写。
    await attributeFlow(context, engine, c);
  }
}

// ------------------------------------------------------------------ 案卷

class DossierTab extends StatefulWidget {
  const DossierTab({super.key, required this.engine});

  final EnemyEngine engine;

  @override
  State<DossierTab> createState() => _DossierTabState();
}

class _DossierTabState extends State<DossierTab> {
  List<EnemyEvent> _events = <EnemyEvent>[];
  Map<String, int> _counts = <String, int>{};
  bool _busy = false;

  EnemyEngine get _engine => widget.engine;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<EnemyEvent> events = await _engine.dao.recentEvents(limit: 150);
    final Map<String, int> counts = await _engine.dao.eventCountsBySource();
    if (!mounted) return;
    setState(() {
      _events = events;
      _counts = counts;
    });
  }

  String _sourceLabel(String id) {
    for (final EvidenceSource s in _engine.sources) {
      if (s.id == id) return s.label;
    }
    return id == 'commitment' ? '承诺' : id;
  }

  Future<void> _sync() async {
    setState(() => _busy = true);
    final int added = await _engine.sync();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('新增 $added 条证据')));
    await _load();
  }

  Future<void> _deleteSource(String id) async {
    final bool ok = await confirmDialog(
      context,
      title: '删除「${_sourceLabel(id)}」的全部证据？',
      body: '删除后敌人就看不到这部分记录了。这个操作不能撤销。',
      confirm: '删除',
    );
    if (!ok) return;
    await _engine.dao.deleteEventsBySource(id);
    await _load();
  }

  Future<void> _clear() async {
    final bool ok = await confirmDialog(
      context,
      title: '清空案卷？',
      body: '所有证据都会删除。判词、承诺和教训保留。这个操作不能撤销。',
      confirm: '清空',
    );
    if (!ok) return;
    await _engine.dao.clearEvidence();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> ids = _counts.keys.toList()..sort();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            '这是敌人能看到的全部证据。数据只存本机，每条判词都能追到这里。',
            style: TextStyle(color: kEnemyMuted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              FilledButton(
                onPressed: _busy ? null : _sync,
                child: Text(_busy ? '同步中…' : '立即同步'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _clear, child: const Text('清空案卷')),
            ],
          ),
          const SizedBox(height: 8),
          for (final String id in ids)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(_sourceLabel(id), style: const TextStyle(color: kEnemyText)),
              subtitle: Text('${_counts[id]} 条', style: const TextStyle(color: kEnemyMuted)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: kEnemyMuted),
                onPressed: () => _deleteSource(id),
              ),
            ),
          const Divider(),
          if (_events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('案卷是空的。', style: TextStyle(color: kEnemyMuted)),
            ),
          for (final EnemyEvent e in _events)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(eventLine(e), style: const TextStyle(color: kEnemyText)),
              subtitle: Text(
                '#${e.id} · ${fmtTime(e.ts)} · ${_sourceLabel(e.source)}',
                style: const TextStyle(color: kEnemyMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 承诺

class CommitmentsTab extends StatefulWidget {
  const CommitmentsTab({super.key, required this.engine});

  final EnemyEngine engine;

  @override
  State<CommitmentsTab> createState() => _CommitmentsTabState();
}

typedef _DueOption = ({String label, DateTime Function(DateTime now) at});

class _CommitmentsTabState extends State<CommitmentsTab> {
  static final List<_DueOption> _dueOptions = <_DueOption>[
    (label: '2 小时内', at: (DateTime n) => n.add(const Duration(hours: 2))),
    (
      label: '今晚 22:00',
      at: (DateTime n) {
        final DateTime t = DateTime(n.year, n.month, n.day, 22);
        return t.isAfter(n) ? t : t.add(const Duration(days: 1));
      }
    ),
    (label: '明天此时', at: (DateTime n) => n.add(const Duration(days: 1))),
    (label: '三天内', at: (DateTime n) => n.add(const Duration(days: 3))),
  ];

  final TextEditingController _controller = TextEditingController();
  List<EnemyCommitment> _items = <EnemyCommitment>[];
  int _dueIndex = 1;

  EnemyEngine get _engine => widget.engine;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _engine.settleOverdue();
    final List<EnemyCommitment> items = await _engine.dao.commitments(limit: 100);
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _add() async {
    final String text = _controller.text.trim();
    if (text.isEmpty) return;
    final DateTime due = _dueOptions[_dueIndex].at(DateTime.fromMillisecondsSinceEpoch(_engine.nowMs()));
    final ({int? id, bool crisis}) r = await _engine.addCommitment(text, due: due);
    if (!mounted) return;
    if (r.crisis) {
      _controller.clear();
      await showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          backgroundColor: kEnemyCard,
          content: Text(EnemyCopy.crisisMessage, style: const TextStyle(color: kEnemyText, height: 1.6)),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('好')),
          ],
        ),
      );
      return;
    }
    _controller.clear();
    await _load();
  }

  Future<void> _complete(EnemyCommitment c) async {
    final String? msg = await _engine.complete(c.id);
    if (mounted && msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final int now = _engine.nowMs();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _controller,
            style: const TextStyle(color: kEnemyText),
            decoration: const InputDecoration(
              hintText: '我承诺：做什么',
              hintStyle: TextStyle(color: kEnemyMuted),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: <Widget>[
              for (int i = 0; i < _dueOptions.length; i++)
                ChoiceChip(
                  label: Text(_dueOptions[i].label),
                  selected: _dueIndex == i,
                  onSelected: (_) => setState(() => _dueIndex = i),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _add, child: const Text('立下承诺')),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            const Text(EnemyCopy.noCommitments, style: TextStyle(color: kEnemyMuted)),
          for (final EnemyCommitment c in _items)
            Card(
              color: kEnemyCard,
              child: ListTile(
                title: Text(c.text, style: const TextStyle(color: kEnemyText)),
                subtitle: Text(
                  [
                    if (c.dueMs != null) '截止 ${fmtTime(c.dueMs!)}',
                    if (c.status == CommitmentStatus.open && c.dueMs != null)
                      fmtRemaining(c.dueMs!, now),
                    commitmentStatusLabels[c.status] ?? c.status,
                    if (c.origin == 'verdict') '来自判词',
                  ].join(' · '),
                  style: const TextStyle(color: kEnemyMuted, fontSize: 12),
                ),
                trailing: c.status == CommitmentStatus.open
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            tooltip: '兑现',
                            onPressed: () => _complete(c),
                          ),
                          IconButton(
                            icon: const Icon(Icons.highlight_off),
                            tooltip: '没做到',
                            onPressed: () async {
                              await attributeFlow(context, _engine, c);
                              await _load();
                            },
                          ),
                        ],
                      )
                    : c.status == CommitmentStatus.missed
                        ? TextButton(
                            onPressed: () async {
                              await attributeFlow(context, _engine, c);
                              await _load();
                            },
                            child: const Text('归因'),
                          )
                        : null,
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 教训

class LessonsTab extends StatefulWidget {
  const LessonsTab({super.key, required this.engine});

  final EnemyEngine engine;

  @override
  State<LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends State<LessonsTab> {
  WeeklyReview? _review;
  List<EnemyLesson> _lessons = <EnemyLesson>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.engine.settleOverdue();
    final WeeklyReview review = await widget.engine.weeklyReview();
    final List<EnemyLesson> lessons = await widget.engine.dao.lessons();
    if (!mounted) return;
    setState(() {
      _review = review;
      _lessons = lessons;
    });
  }

  String _pct(int? v) => v == null ? '—' : '$v%';

  @override
  Widget build(BuildContext context) {
    final WeeklyReview? r = _review;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (r != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kEnemyCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('本周审判', style: TextStyle(color: kEnemyText, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _line('承诺', '兑现 ${r.commitmentsDone} · 失效 ${r.commitmentsMissed} · 豁免 ${r.commitmentsExcused}'),
                  _line('履约率', _pct(r.commitmentRate)),
                  _line('判词之后的行动率', _pct(r.verdictActRate)),
                  for (final MapEntry<int, ({int done, int total})> e
                      in (r.actRateByIntensity.entries.toList()
                        ..sort((a, b) => a.key.compareTo(b.key))))
                    _line(e.key == 0 ? '事实播报' : '${e.key} 档',
                        '${e.value.done}/${e.value.total}'),
                  _line('申辩', '${r.appealCount} 次，成立 ${r.appealAccepted} 次'),
                  if (r.topFailures.isNotEmpty)
                    _line('失败类别', r.topFailures.map((f) => '${f.category}×${f.count}').join('、')),
                  const SizedBox(height: 8),
                  Text(r.focus, style: const TextStyle(color: kEnemyAccent, height: 1.5)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Text('教训库', style: TextStyle(color: kEnemyText, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (_lessons.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('还没有教训。承诺没做到时，先归因，教训才会入库。', style: TextStyle(color: kEnemyMuted)),
            ),
          for (final EnemyLesson l in _lessons)
            Card(
              color: kEnemyCard,
              child: ListTile(
                title: Text(l.lesson, style: const TextStyle(color: kEnemyText)),
                subtitle: Text(
                  '${fmtTime(l.createdMs)} · 「${l.category}」第 ${l.timesRepeated} 次',
                  style: const TextStyle(color: kEnemyMuted, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(width: 110, child: Text(k, style: const TextStyle(color: kEnemyMuted))),
            Expanded(child: Text(v, style: const TextStyle(color: kEnemyText))),
          ],
        ),
      );
}

// ------------------------------------------------------------------ 设置

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key, required this.engine, required this.reminder});

  final EnemyEngine engine;
  final EnemyReminder reminder;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  static const List<String> _weekdays = <String>['无', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  static const List<String> _intensityHelp = <String>[
    '',
    '1 档：冷静挑刺，只陈述差距。',
    '2 档：直接强硬，点名拖延，允许讽刺。',
    '3 档：火力全开，允许粗口作语气词——但只冲着行为和借口，不冲着你这个人。',
  ];

  bool _loaded = false;
  int _intensity = 2;
  int _quietStart = 23;
  int _quietEnd = 7;
  int _cap = 3;
  int _truce = DateTime.saturday;
  bool _notify = false;
  int _notifyHour = 21;
  bool _muted = false;
  Map<String, bool> _consents = <String, bool>{};

  EnemyEngine get _engine => widget.engine;
  EnemyDao get _dao => widget.engine.dao;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final int intensity = await _dao.intSetting(EnemySettings.intensity, 2);
    final int qs = await _dao.intSetting(EnemySettings.quietStartHour, 23);
    final int qe = await _dao.intSetting(EnemySettings.quietEndHour, 7);
    final int cap = await _dao.intSetting(EnemySettings.dailyCap, 3);
    final int truce = await _dao.intSetting(EnemySettings.truceWeekday, DateTime.saturday);
    final bool notify = await _dao.boolSetting(EnemySettings.dailyNotify);
    final int notifyHour = await _dao.intSetting(EnemySettings.dailyNotifyHour, 21);
    final bool muted = await _engine.isMuted();
    final Map<String, bool> consents = await _engine.consents();
    if (!mounted) return;
    setState(() {
      _intensity = intensity.clamp(1, 3);
      _quietStart = qs;
      _quietEnd = qe;
      _cap = cap.clamp(1, 5);
      _truce = truce.clamp(0, 7);
      _notify = notify;
      _notifyHour = notifyHour;
      _muted = muted;
      _consents = consents;
      _loaded = true;
    });
  }

  Future<void> _set(String key, int value) => _dao.setSetting(key, '$value');

  Widget _hourDropdown(int value, ValueChanged<int> onChanged) {
    return DropdownButton<int>(
      value: value,
      dropdownColor: kEnemyCard,
      items: <DropdownMenuItem<int>>[
        for (int h = 0; h < 24; h++)
          DropdownMenuItem<int>(value: h, child: Text('${h.toString().padLeft(2, '0')}:00')),
      ],
      onChanged: (int? v) {
        if (v != null) onChanged(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (_muted)
          Card(
            color: kEnemyCard,
            child: ListTile(
              title: const Text('敌人已静音', style: TextStyle(color: kEnemyText)),
              subtitle: const Text('24 小时内不开庭。', style: TextStyle(color: kEnemyMuted)),
              trailing: TextButton(
                onPressed: () async {
                  await _engine.unmute();
                  await _load();
                },
                child: const Text('取消静音'),
              ),
            ),
          ),
        const Text('强度上限', style: TextStyle(color: kEnemyText, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: const <ButtonSegment<int>>[
            ButtonSegment<int>(value: 1, label: Text('1')),
            ButtonSegment<int>(value: 2, label: Text('2')),
            ButtonSegment<int>(value: 3, label: Text('3')),
          ],
          selected: <int>{_intensity},
          onSelectionChanged: (Set<int> s) async {
            setState(() => _intensity = s.first);
            await _set(EnemySettings.intensity, s.first);
          },
        ),
        const SizedBox(height: 6),
        Text(_intensityHelp[_intensity], style: const TextStyle(color: kEnemyMuted, fontSize: 13)),
        const Text(
          '实际档位可能更低：连续多天没回应、你点了「太过了」、或休战日，都会自动降档。只降不升。',
          style: TextStyle(color: kEnemyMuted, fontSize: 12),
        ),
        const Divider(height: 28),
        const Text('允许采集的模块', style: TextStyle(color: kEnemyText, fontWeight: FontWeight.w700)),
        if (_engine.sources.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('没有接入任何证据来源。', style: TextStyle(color: kEnemyMuted)),
          ),
        for (final EvidenceSource s in _engine.sources)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.label, style: const TextStyle(color: kEnemyText)),
            value: _consents[s.id] ?? false,
            onChanged: (bool v) async {
              await _engine.setConsent(s.id, v);
              await _load();
            },
          ),
        const Divider(height: 28),
        const Text('节奏', style: TextStyle(color: kEnemyText, fontWeight: FontWeight.w700)),
        Row(
          children: <Widget>[
            const Text('静默时段', style: TextStyle(color: kEnemyMuted)),
            const SizedBox(width: 12),
            _hourDropdown(_quietStart, (int v) async {
              setState(() => _quietStart = v);
              await _set(EnemySettings.quietStartHour, v);
            }),
            const Text(' 至 ', style: TextStyle(color: kEnemyMuted)),
            _hourDropdown(_quietEnd, (int v) async {
              setState(() => _quietEnd = v);
              await _set(EnemySettings.quietEndHour, v);
            }),
          ],
        ),
        Row(
          children: <Widget>[
            const Text('每天最多判词', style: TextStyle(color: kEnemyMuted)),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: _cap,
              dropdownColor: kEnemyCard,
              items: <DropdownMenuItem<int>>[
                for (int n = 1; n <= 5; n++) DropdownMenuItem<int>(value: n, child: Text('$n 条')),
              ],
              onChanged: (int? v) async {
                if (v == null) return;
                setState(() => _cap = v);
                await _set(EnemySettings.dailyCap, v);
              },
            ),
          ],
        ),
        Row(
          children: <Widget>[
            const Text('休战日', style: TextStyle(color: kEnemyMuted)),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: _truce,
              dropdownColor: kEnemyCard,
              items: <DropdownMenuItem<int>>[
                for (int d = 0; d <= 7; d++)
                  DropdownMenuItem<int>(value: d, child: Text(_weekdays[d])),
              ],
              onChanged: (int? v) async {
                if (v == null) return;
                setState(() => _truce = v);
                await _set(EnemySettings.truceWeekday, v);
              },
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('当天只报事实，不带语气', style: TextStyle(color: kEnemyMuted, fontSize: 12)),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('每日报到通知', style: TextStyle(color: kEnemyText)),
          subtitle: const Text('默认关。通知正文只报数字。', style: TextStyle(color: kEnemyMuted)),
          value: _notify,
          onChanged: (bool v) async {
            setState(() => _notify = v);
            await _dao.setBoolSetting(EnemySettings.dailyNotify, v);
            await widget.reminder.onDailyNotifyChanged(enabled: v, hour: _notifyHour);
          },
        ),
        if (_notify)
          Row(
            children: <Widget>[
              const Text('报到时间', style: TextStyle(color: kEnemyMuted)),
              const SizedBox(width: 12),
              _hourDropdown(_notifyHour, (int v) async {
                setState(() => _notifyHour = v);
                await _set(EnemySettings.dailyNotifyHour, v);
                await widget.reminder.onDailyNotifyChanged(enabled: true, hour: v);
              }),
            ],
          ),
        const Divider(height: 28),
        const Text('数据', style: TextStyle(color: kEnemyText, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: <Widget>[
            OutlinedButton(
              onPressed: () async {
                final bool ok = await confirmDialog(
                  context,
                  title: '清空案卷？',
                  body: '所有证据都会删除。判词、承诺和教训保留。',
                  confirm: '清空',
                );
                if (ok) await _dao.clearEvidence();
              },
              child: const Text('清空案卷'),
            ),
            OutlinedButton(
              onPressed: () async {
                final bool ok = await confirmDialog(
                  context,
                  title: '清空全部？',
                  body: '证据、判词、承诺、教训全部删除，设置保留。不能撤销。',
                  confirm: '全部清空',
                );
                if (ok) await _dao.wipeEverything();
              },
              child: const Text('清空全部'),
            ),
          ],
        ),
      ],
    );
  }
}
