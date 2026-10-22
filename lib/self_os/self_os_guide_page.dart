import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'self_os_action_focus.dart';
import 'self_os_ai_service.dart';
import 'self_os_case_page.dart';
import 'self_os_guidance.dart';
import 'self_os_learning.dart';
import 'self_os_progress.dart';
import 'self_os_models.dart';
import 'self_os_repository.dart';
import 'self_os_widgets.dart';
import 'self_os_strength_learning.dart';
import 'self_os_strength_feedback.dart';

part 'self_os_guide_learning_panel.dart';

class SelfOsGuidePage extends StatefulWidget {
  const SelfOsGuidePage(
      {super.key,
      required this.value,
      required this.repository,
      required this.ai,
      required this.history,
      required this.profile});
  final SelfOsCase value;
  final SelfOsRepository repository;
  final SelfOsAiService ai;
  final List<SelfOsCase> history;
  final SelfOsProfile profile;
  @override
  State<SelfOsGuidePage> createState() => _SelfOsGuidePageState();
}

class _SelfOsGuidePageState extends State<SelfOsGuidePage>
    with WidgetsBindingObserver {
  late SelfOsCase _c = widget.value.copy();
  late SelfOsProfile _profile = widget.profile;
  late List<SelfOsCase> _history = widget.history;
  late final _answer = TextEditingController(text: _c.guide.compose);
  final _scroll = ScrollController();
  Future<void> _writes = Future.value();
  Timer? _draftTimer;
  bool _busy = false, _saving = false, _allowPop = false, _correcting = false;
  bool _needsReload = false, _inDetails = false;
  String? _detailBefore;
  DateTime? _detailCommit;
  int _ticket = 0;
  String? _error, _influence;
  String _progress = '';
  OsGuideState get g => _c.guide;
  bool get _locked => _busy || _saving || _needsReload;
  OsGuideFrame? get _frame =>
      g.frame == null ? null : OsGuideFrame.saved(g.frame!);

  void _redraw(VoidCallback change) {
    if (mounted) setState(change);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _correcting = g.draft['correcting'] == true;
    if (_c.reviewed) {
      g.phase = 'learn';
    } else if (_c.retrospective) {
      g.phase = 'review';
    } else if (_c.v37.flag('requiresReconsideration') ||
        (_c.text('newInformation').isNotEmpty &&
            !_c.v37.flag('newInformationReviewed'))) {
      g
        ..phase = 'explore'
        ..frame = null
        ..confirmedRevision = null;
      g.draft['correcting'] = true;
      _correcting = true;
    } else if (_c.committedAt != null && g.turns.isEmpty) {
      g.phase = 'act';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !_correcting &&
          g.compose.isEmpty &&
          g.phase == 'explore' &&
          g.frame == null) _runAi();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _draftTimer?.cancel();
      if (!_locked && !_inDetails) _persist(_c);
    }
  }

  @override
  void dispose() {
    _ticket++;
    _draftTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _answer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<bool> _persist(SelfOsCase c, {SelfOsProfile? profile}) async {
    if (_needsReload || _inDetails) return false;
    final copy = c.copy();
    final profileCopy =
        profile == null ? null : SelfOsProfile.fromJson(profile.toJson());
    // Serialize autosaves, transitions and back navigation, so an old draft can
    // never land after a newly confirmed protocol.
    final write = _writes.catchError((Object _) {}).then((_) =>
        profileCopy == null
            ? widget.repository.saveCase(copy)
            : widget.repository.saveCaseAndProfile(copy, profileCopy));
    _writes = write;
    try {
      await write;
      return true;
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，当前输入仍在。请重试保存后再离开。');
      return false;
    }
  }

  void _draftChanged() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 650), () => _persist(_c));
  }

  Future<bool> _transition(void Function(SelfOsCase) change) async {
    if (_locked) return false;
    _draftTimer?.cancel();
    final draft = _c.copy();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      change(draft);
      if (!await _persist(draft) || !mounted) return false;
      setState(() => _c = draft);
      return true;
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    if (_saving) return;
    if (_needsReload) {
      await _reloadDetails();
      if (!mounted || _needsReload) return;
    }
    _ticket++;
    _draftTimer?.cancel();
    setState(() {
      _busy = false;
      _saving = true;
    });
    final saved = await _persist(_c);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _allowPop = saved;
    });
    if (saved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _top() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _runAi() async {
    if (_locked || g.phase != 'explore') return;
    _draftTimer?.cancel();
    final ticket = ++_ticket;
    setState(() {
      _busy = true;
      _error = null;
      _progress = '正在理解你想改变和保护的东西…';
    });
    try {
      if (!await _persist(_c) || !mounted || ticket != _ticket) return;
      if (_c.desires.isEmpty) {
        final desires = await widget.ai.discover(_c.copy(), _history);
        if (!mounted || ticket != _ticket) return;
        final draft = _c.copy()..desires.addAll(desires);
        setState(() => _saving = true);
        if (!await _persist(draft) || !mounted || ticket != _ticket) return;
        setState(() {
          _c = draft;
          _saving = false;
        });
      }
      setState(() => _progress = '正在找出这一步最值得澄清的问题…');
      final revision = g.revision;
      final response = await widget.ai.guide(
          _c.copy(), [..._history.where((c) => c.id != _c.id), _c], _profile);
      if (!mounted || ticket != _ticket) return;
      final draft = _c.copy();
      SelfOsGuidance.receive(draft, response, revision);
      draft.guide.draft.remove('correcting');
      setState(() => _saving = true);
      if (!await _persist(draft) || !mounted || ticket != _ticket) return;
      setState(() {
        _c = draft;
        _correcting = false;
        _influence = null;
      });
      _top();
    } catch (e) {
      if (mounted && ticket == _ticket)
        setState(() => _error = e is FormatException
            ? e.message
            : 'AI 暂时不可用。你的话已保存在本机，可以先补充记录，稍后重试；也可以在「分析与记录」中自行梳理。');
    } finally {
      if (mounted && ticket == _ticket)
        setState(() {
          _busy = false;
          _saving = false;
        });
    }
  }

  Future<void> _send() async {
    final text = _answer.text;
    if (await _transition(
        (c) => SelfOsGuidance.answer(c, text, correction: _correcting))) {
      _answer.clear();
      _top();
      await _runAi();
    }
  }

  Future<void> _details([int? target, String? initialAiTask]) async {
    if (_locked) return;
    final selection = target ??
        await showModalBottomSheet<int>(
            context: context,
            isScrollControlled: true,
            builder: (ctx) => SafeArea(
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                  const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('分析与记录',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700))),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text('按需要展开。返回后，继续眼前这一步。')),
                  for (final e in const {
                    0: '选择与未来路径',
                    1: '认识、证据与因果',
                    2: '冲突与注意',
                    3: '未来认识准备',
                    4: '本性与力量',
                    5: '欲求假设与 Why Tree',
                    6: '完整动机空间',
                    7: '认识纠错',
                    8: '完整行动协议',
                    9: '详细复盘'
                  }.entries)
                    ListTile(
                        title: Text(e.value),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(ctx, e.key)),
                ]))));
    if (selection == null || !mounted) return;
    _draftTimer?.cancel();
    if (!await _persist(_c) || !mounted) return;
    _detailBefore = jsonEncode(_c.evidenceSnapshot());
    _detailCommit = _c.committedAt;
    _inDetails = true;
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => SelfOsCasePage(
                value: _c,
                repository: widget.repository,
                ai: widget.ai,
                history: _history,
                profile: _profile,
                initialAiTask: initialAiTask,
                initialWorkspace: selection < 5 ? selection : null,
                initialEngine: selection >= 5
                    ? SelfOsEngine.values[selection - 5]
                    : null)));
    _inDetails = false;
    if (!mounted) return;
    await _reloadDetails();
  }

  Future<void> _reloadDetails() async {
    try {
      final cases = await widget.repository.loadCases();
      final profile = await widget.repository.loadProfile();
      if (!mounted) return;
      final c = cases.firstWhere((c) => c.id == _c.id);
      final changed = jsonEncode(c.evidenceSnapshot()) != _detailBefore;
      if (c.reviewed) {
        c.guide.phase = 'learn';
      } else if (c.v37.flag('requiresReconsideration') ||
          (c.text('newInformation').isNotEmpty &&
              !c.v37.flag('newInformationReviewed'))) {
        c.guide
          ..phase = 'explore'
          ..frame = null
          ..confirmedRevision = null;
        c.guide.draft['correcting'] = true;
      } else if (c.committedAt != null &&
          (c.committedAt != _detailCommit || c.guide.phase == 'act')) {
        c.guide.phase = 'act';
      } else if (changed) {
        c.guide
          ..frame = null
          ..confirmedRevision = null
          ..phase = 'explore';
        c.v37.settings['understandingReviewed'] = false;
      }
      setState(() {
        _c = c;
        _history = cases;
        _profile = profile;
        _needsReload = false;
        _error = null;
        _correcting = g.draft['correcting'] == true;
        _answer.text = g.compose;
      });
      _top();
    } catch (_) {
      if (mounted)
        setState(() {
          _needsReload = true;
          _error = '暂时无法读取详细分析中的更新。请重试读取后继续，新的记录会保留。';
        });
    }
  }

  Future<void> _focus() async {
    final snapshot = _c.commitment;
    if (snapshot == null || _locked) return;
    final blocker = SelfOsProgress.actionBlocker(_c);
    if (blocker != null) {
      setState(() => _error = blocker);
      return;
    }
    final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
            builder: (_) => SelfOsActionFocus(snapshot: osClone(snapshot))));
    if (!mounted || result == null) return;
    await _transition((c) {
      c.v37.settings['holdResult'] = osClone(result);
      if (result['result'] == 'review') c.guide.phase = 'review';
      if (result['result'] == 'reconsider') {
        c.guide
          ..phase = 'explore'
          ..confirmedRevision = null
          ..frame = null;
        c.guide.draft['correcting'] = true;
        c.fields['newInformation'] = '现场出现重要新信息，待补充与重审';
        c.v37.settings['newInformationReviewed'] = false;
        c.v37.settings['requiresReconsideration'] = true;
        c.v37.settings['understandingReviewed'] = false;
      }
    });
    if (result['result'] == 'reconsider' && mounted) {
      setState(() => _correcting = true);
    }
    _top();
  }

  Future<void> _moment() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now,
        lastDate: now.add(const Duration(days: 730)));
    if (date == null || !mounted) return;
    final time =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null || !mounted) return;
    setState(() => g.draft['moment'] =
        DateTime(date.year, date.month, date.day, time.hour, time.minute)
            .toIso8601String());
    _draftChanged();
  }

  Widget _input(String key, String label, Map<String, dynamic> data,
          {int lines = 2, String? hint}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
              key: ValueKey('guide_${g.revision}_${g.phase}_$key'),
              initialValue: osText(data[key]),
              minLines: lines,
              maxLines: lines + 3,
              maxLength: 4000,
              enabled: !_locked,
              decoration: InputDecoration(
                  labelText: label, hintText: hint, counterText: ''),
              onChanged: (v) {
                setState(() {
                  data[key] = v;
                  if (g.phase == 'plan' &&
                      ['action', 'boundary', 'stopWhen'].contains(key)) {
                    data['costAccepted'] = false;
                    data['reversible'] = false;
                  }
                });
                _draftChanged();
              }));

  Widget _line(String label, String content) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: osGold, fontSize: 12)),
        const SizedBox(height: 5),
        Text(content, style: const TextStyle(height: 1.65)),
      ]));

  Widget _primary(String label, VoidCallback action, {String? key}) => SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
          key: key == null ? null : ValueKey(key),
          style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 18)),
          onPressed: _locked ? null : action,
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: Text(label, textAlign: TextAlign.center)));

  List<Widget> _explore() {
    final f = _frame;
    final hasQuestion = f?.question.isNotEmpty == true;
    return [
      if (f != null) ...[
        OsSection(title: '我先这样理解，你可以修正', children: [
          Text(f.text('understanding'),
              style: const TextStyle(fontSize: 18, height: 1.7)),
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('这份理解从哪里来', style: TextStyle(fontSize: 13)),
              children: [
                _line('你可能想接近', f.text('toward')),
                _line('也想好好保护', f.text('protect')),
                for (final b in osMaps(f.data['basis']))
                  _line('你说', '“${b['quote']}”')
              ]),
        ]),
        if (f.insight.isNotEmpty && !hasQuestion && !_correcting)
          OsSection(title: '一个值得验证的新角度', children: [
            _line('原先的理解', osText(f.insight['before'])),
            _line('也许更接近的解释', osText(f.insight['after'])),
            _line('为什么这样想', osText(f.insight['reason'])),
            if (f.routes.isNotEmpty)
              ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('可以比较的 ${f.routes.length} 条路径'),
                  children: [
                    for (final route in f.routes)
                      OsSection(title: osText(route['title']), children: [
                        if (osText(route['mechanismDetail']).isNotEmpty)
                          _line(
                              '这条路怎样实现想要的变化', osText(route['mechanismDetail'])),
                        _line('可能得到', osText(route['benefit'])),
                        _line('可能付出', osText(route['cost'])),
                        _line('还不知道', osText(route['unknown'])),
                      ])
                  ]),
            const SizedBox(height: 12),
            const Text('这份理解，让你有什么变化？'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final e in SelfOsGuidance.influences.entries)
                ChoiceChip(
                    label: Text(e.value),
                    selected: _influence == e.key,
                    onSelected: _locked
                        ? null
                        : (_) => setState(() => _influence = e.key)),
            ]),
            const SizedBox(height: 16),
            _primary('这符合我，看看怎么验证', () async {
              if (await _transition(
                  (c) => SelfOsGuidance.confirm(c, _influence ?? ''))) _top();
            }, key: 'guide_confirm'),
          ]),
        if (!_correcting)
          TextButton.icon(
              onPressed: _locked
                  ? null
                  : () {
                      setState(() => _correcting = true);
                      g.draft['correcting'] = true;
                      _draftChanged();
                      _top();
                    },
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('理解有偏差，我来修正')),
      ],
      if (hasQuestion || f == null || _correcting)
        OsSection(
            title: _correcting
                ? '哪一处需要重新理解？'
                : hasQuestion
                    ? osText(f!.question['text'])
                    : '最近哪件具体的事，让你开始这样想？',
            subtitle: _correcting
                ? '不贴合的解释可以放下。把你的具体情况告诉我。'
                : hasQuestion
                    ? osText(f!.question['why'])
                    : '说一点眼前的经历即可，也可以先记下还不确定的部分。',
            children: [
              if (hasQuestion && !_correcting)
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final option in osStrings(f!.question['options']))
                    ActionChip(
                        label: Text(option),
                        onPressed: _locked
                            ? null
                            : () {
                                _answer.text = option;
                                g.compose = option;
                                _draftChanged();
                              })
                ]),
              const SizedBox(height: 12),
              TextField(
                  key: const ValueKey('guide_answer'),
                  controller: _answer,
                  enabled: !_locked,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 6000,
                  decoration: const InputDecoration(
                      hintText: '按你的真实情况说，不用整理成完整答案。', counterText: ''),
                  onChanged: (v) {
                    g.compose = v;
                    _draftChanged();
                  }),
              const SizedBox(height: 14),
              _primary('带着这点继续', _send, key: 'guide_send'),
            ]),
      if (g.frame == null && !_busy)
        TextButton.icon(
            onPressed: _locked ? null : _runAi,
            icon: const Icon(Icons.refresh),
            label: const Text('重新理解已保存的内容')),
    ];
  }

  List<Widget> _plan() {
    final d = g.draft;
    return [
      const Text('先试一小步',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('带着一个问题回到现实。你可以调整下面的建议。', style: TextStyle(height: 1.6)),
      const SizedBox(height: 20),
      OsSection(title: '这一步要弄清什么', children: [
        _line('待验证', osText(d['question'])),
        _line('准备做的第一步', osText(d['action'])),
        _line('暂时的预期', osText(d['prediction'])),
        _line('留意这些实际变化', osText(d['observe'])),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('调整动作、预期与观察方式'),
            children: [
              _input('action', '准备做的第一步', d),
              _input('question', '想验证的问题', d),
              _input('prediction', '我预期会发生什么', d),
              _input('observe', '怎样观察，什么结果会改变判断', d),
              DropdownButtonFormField<String>(
                key: ValueKey('guide_${_c.round}_experiment_route'),
                initialValue: _c.v37.routes.any((r) => r.id == d['routeId'])
                    ? osText(d['routeId'])
                    : '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: '这一步在检验哪条路径？'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('跨路径了解，暂不关联')),
                  for (final r in _c.v37.routes)
                    DropdownMenuItem(
                        value: r.id,
                        child: Text(r.title, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: _locked
                    ? null
                    : (v) {
                        setState(() => d['routeId'] = v ?? '');
                        _draftChanged();
                      },
              ),
            ]),
      ]),
      OsSection(title: '让它小到可以开始', children: [
        _input('trigger', '什么时候、在哪里开始？', d, hint: '例如：明晚到家后，坐到书桌前'),
        _line('时间、费用和承诺的上限', osText(d['boundary'])),
        _line('出现这些情况就停下或重审', osText(d['stopWhen'])),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('调整行动边界'),
            children: [
              _input('boundary', '时间、费用和承诺的上限', d),
              _input('stopWhen', '出现什么情况就停下或重审？', d),
            ]),
        CheckboxListTile(
            key: const ValueKey('guide_cost'),
            contentPadding: EdgeInsets.zero,
            value: d['costAccepted'] == true,
            onChanged: _locked
                ? null
                : (v) {
                    setState(() => d['costAccepted'] = v);
                    _draftChanged();
                  },
            title: const Text('这些成本在我能承受的范围内')),
        CheckboxListTile(
            key: const ValueKey('guide_reversible'),
            contentPadding: EdgeInsets.zero,
            value: d['reversible'] == true,
            onChanged: _locked
                ? null
                : (v) {
                    setState(() => d['reversible'] = v);
                    _draftChanged();
                  },
            title: const Text('这一步可以撤回，不会直接作出重大承诺')),
        TextButton.icon(
            onPressed: _locked ? null : _moment,
            icon: const Icon(Icons.event_outlined),
            label: Text(osText(d['moment']).isEmpty
                ? '可选：约定一个具体时刻'
                : '约定：${osText(d['moment']).replaceFirst('T', ' ').substring(0, 16)}')),
        if (osText(d['moment']).isNotEmpty) ...[
          const Text('时间记录在本案例中；在这个时刻带回实际观察。', style: TextStyle(fontSize: 12)),
          TextButton(
              onPressed: _locked
                  ? null
                  : () {
                      setState(() => d.remove('moment'));
                      _draftChanged();
                    },
              child: const Text('清除约定时间')),
        ],
      ]),
      if (osText(d['cue']).isNotEmpty)
        OsSection(title: '到现场时，可以带上这一句', children: [
          Text('“${d['cue']}”',
              style: const TextStyle(fontSize: 20, height: 1.6)),
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: d['cueAccepted'] == true,
              title: const Text('我相信这句话，愿意在行动前停留 15 秒'),
              onChanged: _locked
                  ? null
                  : (v) {
                      setState(() => d['cueAccepted'] = v);
                      _draftChanged();
                    }),
        ]),
      ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('可选：估计现在与到现场时的行动可能性'),
          subtitle: const Text('不知道可以留空，真实反馈会帮助校准。'),
          children: [
            for (final e in const {
              'planProbability': '现在计划时，我有多可能去做？',
              'actionProbability': '到了现场，我估计有多可能去做？'
            }.entries)
              OsScore(
                  label: e.value,
                  value: osNumber(d[e.key]),
                  onChanged: (v) {
                    setState(() => d[e.key] = v);
                    _draftChanged();
                  }),
          ]),
      const SizedBox(height: 16),
      _primary('把这一步定下来', () async {
        if (await _transition(SelfOsGuidance.commitExperiment)) _top();
      }, key: 'guide_commit'),
      TextButton(
          onPressed: _locked
              ? null
              : () async {
                  if (await _transition((c) {
                    c.guide.phase = 'explore';
                    c.guide.confirmedRevision = null;
                    c.guide.draft['correcting'] = true;
                  })) {
                    setState(() => _correcting = true);
                    _top();
                  }
                },
          child: const Text('还不贴合，先回到问题')),
    ];
  }

  List<Widget> _act() {
    final snapshot = _c.commitment ?? _c.evidenceSnapshot();
    final fields = osMap(snapshot['fields']);
    final experiment = osMap(snapshot['experiment']);
    final blocker = SelfOsProgress.actionBlocker(_c);
    return [
      Text(blocker == null ? '这一刻，只走这一步。' : '先核对变化，再行动。',
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
      const SizedBox(height: 20),
      if (SelfOsProgress.next(_c).kind != 'act') _nextStepCard(),
      OsSection(
          title: osText(fields['firstAction']).isEmpty
              ? '你的行动约定'
              : osText(fields['firstAction']),
          children: [
            _line('开始的时机', osText(fields['trigger'])),
            if (experiment.isNotEmpty) ...[
              _line('带着这个问题', osText(experiment['question'])),
              _line('回来时看看', osText(experiment['observe'])),
              _line('做到这里就够了', osText(experiment['boundary'])),
            ],
            if (blocker == null) _primary('进入行动现场', _focus, key: 'guide_focus'),
            const SizedBox(height: 10),
            OutlinedButton(
                onPressed: _locked
                    ? null
                    : () async {
                        if (await _transition((c) => c.guide.phase = 'review'))
                          _top();
                      },
                child: const Text('记录实际发生的事（也可以是没做）')),
            TextButton(
                onPressed: _locked
                    ? null
                    : () async {
                        if (await _transition((c) {
                          c.guide
                            ..phase = 'explore'
                            ..confirmedRevision = null
                            ..frame = null;
                          c.guide.draft['correcting'] = true;
                          c.fields['newInformation'] = '出现新情况，待补充与重审';
                          c.v37.settings['newInformationReviewed'] = false;
                          c.v37.settings['requiresReconsideration'] = true;
                          c.v37.settings['understandingReviewed'] = false;
                        })) {
                          setState(() => _correcting = true);
                          _top();
                        }
                      },
                child: const Text('情况变了，先重新理解')),
          ]),
    ];
  }

  List<Widget> _review() {
    final d = g.draft.putIfAbsent('reviewDraft', () => <String, dynamic>{})
        as Map<String, dynamic>;
    final plan = osMap(_c.commitment?['experiment']);
    return [
      const Text('现实给了什么回答？',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('做了、只做了一点、没有做，都可以带来新信息。', style: TextStyle(height: 1.6)),
      const SizedBox(height: 20),
      if (plan.isNotEmpty)
        OsSection(title: '回到当时的问题', children: [
          _line('想验证', osText(plan['question'])),
          _line('当时的预期', osText(plan['prediction'])),
          _line('约定观察', osText(plan['observe'])),
        ]),
      OsSection(title: '只记录实际发生的', children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in const {
            'done': '做了',
            'partial': '做了一部分',
            'notDone': '没有做'
          }.entries)
            ChoiceChip(
                label: Text(e.value),
                selected: d['outcome'] == e.key,
                onSelected: _locked
                    ? null
                    : (_) {
                        setState(() => d['outcome'] = e.key);
                        _draftChanged();
                      }),
        ]),
        const SizedBox(height: 18),
        _input('result', '实际发生了什么？', d, hint: '记录看到的变化；没有做时，记录卡在哪一步。'),
        _input('context', '当时是什么情境？', d, hint: '例如：下班后独处，已经有些疲惫'),
        _input('learning', '与原先想的相比，现在多知道了什么？', d, hint: '可以是修正、反证，或仍然无法确定。'),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('补充这次真实付出的代价'),
            children: [_input('actualCost', '实际花了什么，又让位了什么？', d)]),
        const SizedBox(height: 16),
        _primary('留下这次发现', () async {
          if (await _transition((c) => SelfOsGuidance.review(c,
              outcome: osText(d['outcome']),
              result: osText(d['result']),
              learning: osText(d['learning']),
              context: osText(d['context']),
              actualCost: osText(d['actualCost'])))) _top();
        }, key: 'guide_review'),
      ]),
    ];
  }

  List<Widget> _learn() {
    final r = _c.reviews.where((r) => r.round == _c.round).firstOrNull;
    if (r == null) return _review();
    final plan = osMap(r.snapshot['experiment']);
    final before = osText(plan['prediction']).isNotEmpty
        ? osText(plan['prediction'])
        : osText(osMap(r.snapshot['fields'])['k2']);
    return [
      const Text('这次，带走一条认识。',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
      const SizedBox(height: 20),
      OsSection(
          title: r.learning,
          subtitle: '${r.context} · 第 ${r.round} 次现实反馈',
          children: [
            if (before.isNotEmpty) _line('当时以为', before),
            _line('实际看到', r.result),
            if (r.notes['actualCost']?.isNotEmpty == true)
              _line('真实付出的代价', r.notes['actualCost']!),
            const OsNote('这是一条具体情境下的证据。先保留它，也保留其他解释；更多经历会让你看得更清楚。',
                icon: Icons.spa_outlined),
          ]),
      if (plan.isNotEmpty) _calibrationCard(r),
      SelfOsStrengthFeedback(
          key: ValueKey('guide_strength_${r.id}'),
          review: r,
          profile: _profile,
          onSave: (notes) => _saveStrengthFeedback(r.id, notes)),
      _nextStepCard(),
      _primary('带着这个发现再试一轮', () async {
        if (await _transition((c) {
          SelfOsGuidance.nextRound(c);
          SelfOsGuidance.answer(c,
              '上一次实际观察：${r.result}\n当时情境：${r.context}\n我的新认识：${r.notes['calibrationConclusion'] ?? r.learning}\n适用范围：${r.notes['calibrationScope'] ?? r.context}');
        })) {
          _top();
          await _runAi();
        }
      }, key: 'guide_next_round'),
      TextButton(
          onPressed: _locked ? null : _leave,
          child: const Text('先到这里，让认识留一会儿')),
    ];
  }

  @override
  Widget build(BuildContext context) => SelfOsTheme(
      child: PopScope(
          canPop: _allowPop,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _leave();
          },
          child: Scaffold(
            appBar: AppBar(
                title: const Text('一起理清这件事',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                leading: IconButton(
                    tooltip: '保存并返回',
                    onPressed: _saving ? null : _leave,
                    icon: const Icon(Icons.arrow_back)),
                actions: [
                  IconButton(
                      tooltip: '分析与记录',
                      onPressed: _locked ? null : _details,
                      icon: const Icon(Icons.tune_outlined))
                ]),
            body: SafeArea(
                child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Column(children: [
                          if (_busy)
                            Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 8, 20, 8),
                                child: Column(children: [
                                  const LinearProgressIndicator(),
                                  Row(children: [
                                    Expanded(
                                        child: Text(_progress,
                                            style:
                                                const TextStyle(fontSize: 12))),
                                    TextButton(
                                        onPressed: _saving
                                            ? null
                                            : () {
                                                if (_saving) return;
                                                setState(() {
                                                  _ticket++;
                                                  _busy = false;
                                                  _error =
                                                      '已停止等待。已保存的输入会在下次继续时使用。';
                                                });
                                              },
                                        child: const Text('停止等待'))
                                  ])
                                ])),
                          if (_error != null)
                            Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 8, 20, 0),
                                child: Column(children: [
                                  OsNote(_error!, icon: Icons.info_outline),
                                  if (_needsReload)
                                    TextButton(
                                        onPressed: _reloadDetails,
                                        child: const Text('重试读取最新记录')),
                                  if (_error!.startsWith('保存失败'))
                                    TextButton(
                                        onPressed: _locked
                                            ? null
                                            : () async {
                                                if (await _persist(_c) &&
                                                    mounted)
                                                  setState(() => _error = null);
                                              },
                                        child: const Text('重试保存'))
                                ])),
                          Expanded(
                              child: ListView(
                                  key: const ValueKey('self_os_guide'),
                                  controller: _scroll,
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 12, 20, 28),
                                  children: [
                                Text(
                                    switch (g.phase) {
                                      'plan' || 'act' => '理清问题  →  试一小步',
                                      'review' || 'learn' => '试一小步  →  带回发现',
                                      _ => '从你的处境开始',
                                    },
                                    style: const TextStyle(
                                        fontSize: 12, color: osGold)),
                                const SizedBox(height: 10),
                                Text(_c.problem,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        height: 1.5,
                                        color: Color(0xFF68786E))),
                                const SizedBox(height: 22),
                                ...switch (g.phase) {
                                  'plan' => _plan(),
                                  'act' => _act(),
                                  'review' => _review(),
                                  'learn' => _learn(),
                                  _ => _explore(),
                                },
                                if (g.phase == 'explore') _nextStepCard(),
                                const SizedBox(height: 20),
                                if (g.turns.isNotEmpty)
                                  ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      title: const Text('回看我们怎样走到这里',
                                          style: TextStyle(fontSize: 13)),
                                      children: [
                                        for (final t in g.turns)
                                          Align(
                                              alignment: Alignment.centerLeft,
                                              child: _line(
                                                  t['role'] == 'user'
                                                      ? '你'
                                                      : '当时的理解',
                                                  '${t['text']}${osText(t['question']).isEmpty ? '' : '\n${t['question']}'}'))
                                      ]),
                                TextButton.icon(
                                    onPressed: _locked ? null : _details,
                                    icon: const Icon(Icons.hub_outlined,
                                        size: 16),
                                    label: const Text('按需要展开分析与记录')),
                              ])),
                        ])))),
          )));
}
