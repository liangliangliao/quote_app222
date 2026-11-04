import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../prp_plugin.dart';
import '../runtime.dart';
import '../validator.dart';
import 'presentation.dart';

const prpTeal = Color(0xff327c78);
const prpIndigo = Color(0xff56568b);
const prpVermilion = Color(0xffb74435);

class PrpSessionCard extends StatefulWidget {
  const PrpSessionCard(
      {super.key, required this.runtime, required this.offer, this.onFinished});
  final PrpRuntime runtime;
  final PrpOffer offer;
  final VoidCallback? onFinished;
  @override
  State<PrpSessionCard> createState() => _PrpSessionCardState();
}

class _PrpSessionCardState extends State<PrpSessionCard>
    with WidgetsBindingObserver {
  final _thought = TextEditingController();
  final _expected = TextEditingController();
  final _worked = TextEditingController();
  final _failed = TextEditingController();
  final _early = TextEditingController();
  final _cue = TextEditingController();
  final _action = TextEditingController();
  late final _pauseWatch = widget.runtime.stopwatchFactory();
  late final _holdWatch = widget.runtime.stopwatchFactory();
  String _font = 'QuoteXingShu';
  late final int _presentationEpoch;
  Timer? _pauseTimer;
  Timer? _holdTimer;
  int _pauseBase = 0;
  int _emotionBefore = 5;
  int _emotionAfter = 5;
  PrpStep _step = PrpStep.pause;
  String _category = '其他';
  String _error = '';
  bool _loading = true;
  bool _busy = false;
  bool _closed = false;
  bool _crisis = false;
  bool _quoteAllowed = false;
  PrpLesson? _initial;
  PrpLesson? _sealed;
  List<PrpEvidence> _evidence = [];
  List<PrpSentence> _sentences = [];
  String _classifiedText = '';
  List<PrpDayMark> _days = [];

  PrpRuntime get r => widget.runtime;
  int get _pauseSeconds => _pauseBase + _pauseWatch.elapsed.inSeconds;
  int get _remaining =>
      (r.preferences.pauseSeconds - _pauseSeconds).clamp(0, 180);
  List<TextEditingController> get _inputs =>
      [_thought, _expected, _worked, _failed, _early, _cue, _action];

  @override
  void initState() {
    super.initState();
    _presentationEpoch = r.sessionShown(widget.offer);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      final state = await r.sessionState(widget.offer);
      final initial = r.initialLessons[widget.offer.sessionId] ??
          (state['lesson_id'] == null
              ? null
              : await r.store.lesson((state['lesson_id'] as num).toInt()));
      final evidence = await r.evidenceFor(widget.offer);
      List<PrpDayMark> days = [];
      try {
        days = await r.host.recentDays(widget.offer.signal.subjectKey);
      } catch (_) {}
      try {
        _font = await r.host.calligraphyFont();
      } catch (_) {}
      if (!mounted || !r.offerActive(widget.offer)) return;
      _initial = initial;
      _expected.text = initial?.triggerText ?? widget.offer.signal.expected;
      _evidence = evidence;
      _days = days;
      _pauseBase = (state['pause_sec'] as num?)?.toInt() ?? 0;
      _emotionBefore = (state['emotion_before'] as num?)?.toInt() ?? 5;
      _category = initial?.category ?? widget.offer.signal.category ?? '其他';
      if (!LessonValidator.categories.contains(_category)) _category = '其他';
      _worked.text = initial?.worked.join('\n') ?? '';
      _failed.text = initial?.failed.join('\n') ?? '';
      _early.text = initial?.earlySignal ?? '';
      _cue.text = initial?.ifCue ?? '';
      _action.text = initial?.thenAction ?? '';
      _sentences = initial?.sentences.toList() ?? [];
      _thought.text = _sentences.map((s) => s.text).join('\n');
      _classifiedText = _thought.text;
      _quoteAllowed = initial?.quoteAllowed ?? false;
      _step = PrpStep.values.firstWhere((s) => s.name == state['step'],
          orElse: () => PrpStep.pause);
      if (state['outcome'] == 'sealed') {
        _sealed = initial;
        _step = PrpStep.zoom;
      }
      _loading = false;
      setState(() {});
      if (_step == PrpStep.pause) _startPause();
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = '会话暂时不可用，可先关闭，原有记录仍在。';
        });
    }
  }

  void _startPause() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    _pauseWatch.start();
    _pauseTimer ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() {});
      if (_remaining == 0) {
        _pauseWatch.stop();
        _pauseTimer?.cancel();
        _pauseTimer = null;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _step == PrpStep.pause &&
        _remaining > 0) {
      _startPause();
    } else if (state != AppLifecycleState.resumed) {
      _pauseWatch.stop();
      _pauseTimer?.cancel();
      _pauseTimer = null;
      _cancelHold();
    }
  }

  List<String> _lines(TextEditingController controller) => controller.text
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  PrpLesson _lesson() => PrpLesson(
        subjectKey: widget.offer.signal.subjectKey,
        source: widget.offer.signal.surface,
        createdMs: _initial?.state == 'draft' ? _initial!.createdMs : r.nowMs,
        category: _category,
        worked: _lines(_worked), failed: _lines(_failed),
        triggerText: _expected.text.trim(),
        earlySignal: _early.text.trim(), ifCue: _cue.text.trim(),
        thenAction: _action.text.trim(),
        evidence: [
          ..._evidence,
          if (_sentences.any((s) => s.kind == PrpSentenceKind.fact))
            PrpEvidence(
                source: 'prp_session',
                id: '${widget.offer.sessionId}',
                label: '用户在本次对账中确认的事实自述',
                kind: 'self_report'),
        ],
        // Self-blame is visible for sorting, but is never evidence or durable text.
        sentences: _sentences
            .where((s) => s.kind != PrpSentenceKind.selfBlame)
            .toList(),
        parentId:
            _initial?.isSealed == true ? _initial!.id : _initial?.parentId,
        quoteAllowed: _quoteAllowed,
      );

  void _guard(String text, {BuildContext? editorContext}) {
    if (_crisis || _closed || !r.offerActive(widget.offer)) return;
    final guard = r.host.guardText(text);
    if (guard.crisis || guard.truce) {
      _pauseWatch.stop();
      _cancelHold();
      setState(() {
        _crisis = true;
        _closed = true;
        _error = '';
      });
      if (editorContext != null && editorContext.mounted)
        Navigator.of(editorContext).pop();
      // The help route outlives the session slot when the safety valve hides it.
      unawaited(showDialog<void>(
          context: context,
          builder: (_) =>
              Dialog(child: SingleChildScrollView(child: _safetyCard()))));
      unawaited(r
          .crisisExit(widget.offer, crisis: guard.crisis)
          .catchError((Object _) {}));
    }
  }

  Future<bool> _save({bool skipped = false}) async {
    final saved = await r.saveDraft(widget.offer, _lesson(),
        step: _step,
        pauseSeconds: _pauseSeconds,
        emotionBefore: _emotionBefore,
        emotionAfter: _emotionAfter,
        skipped: skipped);
    if (saved != null) _initial = saved;
    return saved != null;
  }

  Future<void> _next() async {
    if (_busy || _closed) return;
    if (_step == PrpStep.pause && _remaining > 0) return;
    if (_step == PrpStep.ledger &&
        !LessonValidator(r.host).concrete(_expected.text)) {
      setState(() => _error = '先写下原本希望做到的具体事情，也可以跳过存草稿。');
      return;
    }
    if (_step == PrpStep.columns) {
      final validator = LessonValidator(r.host);
      if (_lines(_worked).isEmpty ||
          !_lines(_worked).every(validator.concrete) ||
          _lines(_failed).isEmpty ||
          !_lines(_failed).every(validator.concrete)) {
        setState(() => _error = '先写一件有效的做法，再写一个具体的无效场景。');
        return;
      }
    }
    if (_step == PrpStep.ledger && _classifiedText != _thought.text) {
      _sentences = LessonValidator(r.host).classify(_thought.text);
      _classifiedText = _thought.text;
    }
    _pauseWatch.stop();
    _pauseTimer?.cancel();
    _pauseTimer = null;
    setState(() {
      _busy = true;
      _error = '';
      _step = PrpStep.values[_step.index + 1];
    });
    await _save();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _skip() async {
    if (_busy || _closed) return;
    setState(() => _busy = true);
    _pauseWatch.stop();
    final close = widget.onFinished;
    final saved = await _save(skipped: true);
    if (saved) close?.call();
    if (!mounted) return;
    if (!saved) {
      setState(() {
        _busy = false;
        _error = '未保存这段内容。请移除对人的评价，只保留具体经历。';
      });
      return;
    }
    setState(() {
      _closed = true;
      _busy = false;
    });
  }

  void _startHold() {
    if (_busy || _closed || _step != PrpStep.seal) return;
    _holdWatch
      ..reset()
      ..start();
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 25), (_) {
      if (!mounted) return;
      setState(() {});
      if (_holdWatch.elapsedMilliseconds >= 3000) {
        _holdTimer?.cancel();
        _holdWatch.stop();
        unawaited(_seal());
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdWatch
      ..stop()
      ..reset();
    if (mounted) setState(() {});
  }

  Future<void> _seal() async {
    if (_busy || _closed) return;
    final lesson = _lesson();
    final validation = LessonValidator(r.host).validate(lesson);
    if (!validation.valid) {
      setState(() => _error = validation.problems.join('\n'));
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final saved = await r.seal(widget.offer, lesson,
        pauseSeconds: _pauseSeconds,
        heldMilliseconds: _holdWatch.elapsedMilliseconds,
        emotionBefore: _emotionBefore);
    if (!mounted) return;
    if (saved == null) {
      setState(() {
        _busy = false;
        _error = '尚未盖印，请检查开关、缓一缓时间和教训内容。';
      });
      return;
    }
    unawaited(HapticFeedback.mediumImpact().catchError((Object _) {}));
    setState(() {
      _sealed = saved;
      _step = PrpStep.zoom;
      _busy = false;
    });
  }

  Future<void> _revise(int index) async {
    var revisionText = _sentences[index].revision;
    final revision = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('划掉解释，保留修改'),
              content: TextFormField(
                  initialValue: revisionText,
                  onChanged: (text) {
                    revisionText = text;
                    _guard(text, editorContext: ctx);
                  },
                  maxLength: 200,
                  decoration: const InputDecoration(hintText: '换成更贴近事实的一句话')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, revisionText.trim()),
                    child: const Text('保留修订'))
              ],
            ));
    if (!mounted ||
        _crisis ||
        revision == null ||
        !r.host.guardText(revision).allowed) return;
    setState(() {
      final old = _sentences[index];
      _sentences[index] = PrpSentence(old.text, old.kind, revision: revision);
    });
  }

  @override
  void dispose() {
    r.sessionHidden(widget.offer, _presentationEpoch);
    WidgetsBinding.instance.removeObserver(this);
    _pauseWatch.stop();
    _pauseTimer?.cancel();
    _holdTimer?.cancel();
    if (!_closed &&
        _sealed == null &&
        !_loading &&
        r.offerActive(widget.offer)) {
      // Leaving at any step saves only a draft; no recall is scheduled.
      final draft = _lesson();
      unawaited(r.saveDraft(widget.offer, draft,
          step: _step,
          pauseSeconds: _pauseSeconds,
          emotionBefore: _emotionBefore,
          skipped: true));
    }
    for (final input in _inputs) {
      input.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_crisis) return _safetyCard();
    if (!r.offerActive(widget.offer)) return const SizedBox.shrink();
    if (_loading)
      return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()));
    if (_closed)
      return const Padding(
          padding: EdgeInsets.all(24), child: Text('已保存为待盖印草稿。它不会被回访。'));
    return Theme(
        data: prpPaperTheme(context,
            seed: _step == PrpStep.pause ? prpTeal : prpIndigo),
        child: Material(
          color: const Color(0xfff7f5f0),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title,
                      style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff30363b))),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: switch (_step) {
                            PrpStep.pause => _pause(),
                            PrpStep.ledger => _ledger(),
                            PrpStep.columns => _columns(),
                            PrpStep.signal => _signals(),
                            PrpStep.seal => _sealPreview(),
                            PrpStep.zoom => _zoom(),
                            PrpStep.done => const Text('这次先到这里。'),
                          })),
                  if (_error.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error,
                            style: const TextStyle(color: prpVermilion))),
                  const SizedBox(height: 14),
                  if (_step != PrpStep.seal &&
                      _step != PrpStep.zoom &&
                      _step != PrpStep.done &&
                      (_step != PrpStep.pause || _remaining == 0))
                    FilledButton(
                        key: const ValueKey('prp_next'),
                        onPressed: _busy ? null : _next,
                        child: Text(_step == PrpStep.pause ? '开始对账' : '下一步')),
                  if (_step != PrpStep.zoom && _step != PrpStep.done)
                    if (_step.index > PrpStep.ledger.index)
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _step = PrpStep.values[_step.index - 1];
                                    _error = '';
                                  }),
                          child: const Text('返回上一步')),
                  if (_step != PrpStep.zoom && _step != PrpStep.done)
                    TextButton(
                        onPressed: _busy ? null : _skip,
                        child: const Text('暂时跳过，存草稿')),
                ],
              )),
        ));
  }

  String get _title => switch (_step) {
        PrpStep.pause => '先缓一缓',
        PrpStep.ledger => '把事实摆出来',
        PrpStep.columns => '先看有效，再看无效',
        PrpStep.signal => '把教训写成下一次的动作',
        PrpStep.seal => '这条教训，你认可吗？',
        PrpStep.zoom => '拉远一点看',
        PrpStep.done => '这次先到这里',
      };

  Widget _field(TextEditingController controller, String label,
          {String? hint, int lines = 2, int? maxLength}) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
            controller: controller,
            onChanged: (text) {
              _guard(text);
              if (controller == _expected && !_crisis) setState(() {});
            },
            minLines: 1,
            maxLines: lines,
            maxLength: maxLength ?? 1000,
            decoration: InputDecoration(labelText: label, hintText: hint)),
      );

  Widget _pause() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.offer.voice == 'enemy'
            ? '这次没做到。先不分析。缓一缓，我在这儿。'
            : '这次没做到。先不分析，给自己一点缓冲的时间。'),
        const SizedBox(height: 18),
        Center(
            child: Text('$_remaining 秒',
                key: const ValueKey('prp_countdown'),
                style: const TextStyle(
                    fontSize: 40,
                    color: prpTeal,
                    fontWeight: FontWeight.w300))),
        Text('现在的难受程度：$_emotionBefore / 10'),
        Slider(
            value: _emotionBefore.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (v) => setState(() => _emotionBefore = v.round())),
        Wrap(
            spacing: 6,
            children: ['我允许自己难受一会儿。', '这件事没做好，不等于我没有价值。', '我可以先停一下，再想办法。']
                .map((text) => ActionChip(
                    label: Text(text),
                    onPressed: () {
                      _thought.text = text;
                    }))
                .toList()),
        _field(_thought, '可以写一句，也可以什么都不写', hint: '先让感受待一会儿'),
        TextButton.icon(
            onPressed: () async {
              try {
                final text = await r.host.dictate();
                if (!mounted || text == null || !r.offerActive(widget.offer))
                  return;
                _guard(text);
                if (!_crisis) _thought.text = text;
              } catch (_) {
                if (mounted) setState(() => _error = '设备听写暂不可用，可以写一句，也可以留空。');
              }
            },
            icon: const Icon(Icons.mic_none),
            label: const Text('说一句')),
      ]);

  Widget _ledger() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.offer.signal.kind == 'manual')
          _field(_expected, '原本希望做到什么？', hint: '写一件具体的事'),
        _ledgerTile('预期', _expected.text.isEmpty ? '还没有写下预期。' : _expected.text),
        _ledgerTile(
            '记录里',
            _evidence.isEmpty
                ? '记录不足，先不下结论。'
                : _evidence
                    .map((e) =>
                        '${e.kind == 'self_report' ? '用户自述' : '记录'}：${e.label}')
                    .join('\n')),
        PrpLedgerReveal(
            index: 2,
            child: _field(_thought, '你的话', hint: '发生了什么？哪些是事实，哪些是解释？')),
        TextButton(
            onPressed: () => setState(() {
                  _sentences = LessonValidator(r.host).classify(_thought.text);
                  _classifiedText = _thought.text;
                }),
            child: const Text('分成事实 / 解释 / 自责')),
        if (r.aiAllowed)
          TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final requested = _thought.text;
                      final sentences =
                          await r.classifyText(widget.offer, requested);
                      if (mounted && r.offerActive(widget.offer))
                        setState(() {
                          if (_thought.text == requested) {
                            _sentences = sentences;
                            _classifiedText = requested;
                          }
                          _busy = false;
                        });
                    },
              child: const Text('用 AI 辅助分类（失败时使用离线结果）')),
        if (_sentences.isNotEmpty)
          Wrap(spacing: 8, children: [
            for (final kind in PrpSentenceKind.values)
              DragTarget<int>(
                onAcceptWithDetails: (details) {
                  if (details.data < 0 || details.data >= _sentences.length)
                    return;
                  setState(() {
                    final old = _sentences[details.data];
                    _sentences[details.data] =
                        PrpSentence(old.text, kind, revision: old.revision);
                  });
                },
                builder: (_, candidates, __) => Chip(
                    backgroundColor:
                        candidates.isEmpty ? null : const Color(0xffd5e6e1),
                    label: Text(switch (kind) {
                      PrpSentenceKind.fact => '拖到这里：事实',
                      PrpSentenceKind.interpretation => '拖到这里：解释',
                      PrpSentenceKind.selfBlame => '拖到这里：自责'
                    })),
              ),
          ]),
        for (var i = 0; i < _sentences.length; i++)
          LongPressDraggable<int>(
              data: i,
              feedback: Material(
                  elevation: 4,
                  child: SizedBox(
                      width: 280,
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(_sentences[i].text,
                              maxLines: 3, overflow: TextOverflow.ellipsis)))),
              childWhenDragging: Opacity(opacity: .35, child: _sentence(i)),
              child: _sentence(i)),
      ]);

  Widget _ledgerTile(String title, String text) => PrpLedgerReveal(
      index: title == '预期' ? 0 : 1,
      child: Card(
          elevation: 0,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: prpIndigo, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(text)
                  ]))));

  Widget _sentence(int i) {
    final s = _sentences[i];
    final blame = s.kind == PrpSentenceKind.selfBlame;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (s.revision.isNotEmpty)
            PrpCrossedOutText(s.text)
          else
            Text(s.text,
                style: TextStyle(
                    color: blame ? Colors.grey : null,
                    decoration: s.revision.isNotEmpty
                        ? TextDecoration.lineThrough
                        : null)),
          if (s.revision.isNotEmpty)
            Text('改为：${s.revision}', style: const TextStyle(color: prpTeal)),
          Row(children: [
            DropdownButton<PrpSentenceKind>(
                value: s.kind,
                items: PrpSentenceKind.values
                    .map((kind) => DropdownMenuItem(
                        value: kind,
                        child: Text(switch (kind) {
                          PrpSentenceKind.fact => '事实（用户自述）',
                          PrpSentenceKind.interpretation => '解释',
                          PrpSentenceKind.selfBlame => '自责 · 不入账',
                        })))
                    .toList(),
                onChanged: (kind) {
                  if (kind != null)
                    setState(() => _sentences[i] =
                        PrpSentence(s.text, kind, revision: s.revision));
                }),
            if (!blame)
              TextButton(
                  onPressed: () => _revise(i), child: const Text('划掉 / 修订'))
          ]),
          if (blame)
            const Text('这是对你的评价，不是证据，不入账。',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]));
  }

  Widget _columns() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('哪怕只是开始了、记下了。先留住那件有效的事。'),
        _field(_worked, '有效：这次有哪件事是对的？', hint: '例如：把书放到了桌上，读了 1 页'),
        _field(_failed, '无效：当时什么没起作用？', hint: '例如：坐下后打开短视频，原定时间被占满'),
        const Text('只谈做法和场景，不谈人格。每行一条。',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]);

  Widget _signals() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: '这次更接近哪类情况？'),
            items: LessonValidator.categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (c) {
              if (c != null) setState(() => _category = c);
            }),
        _field(_early, '最早出现的信号是什么？'),
        Wrap(
            spacing: 6,
            children: (LessonValidator.earlyExamples[_category] ?? [])
                .map((s) => ActionChip(
                    label: Text(s),
                    onPressed: () {
                      _early.text = s;
                      if (_cue.text.isEmpty) _cue.text = s;
                    }))
                .toList()),
        _field(_cue, '如果：一个能认出来的线索', hint: '例如：准备阅读时又打开短视频'),
        _field(_action, '那么：一个可检验的小动作',
            hint: '例如：把手机放进抽屉，打开书读 1 页', maxLength: 40),
        if (r.aiAllowed)
          TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final original = [
                        _worked.text,
                        _failed.text,
                        _early.text,
                        _cue.text,
                        _action.text,
                        _category
                      ];
                      final draft =
                          await r.draftWithAi(widget.offer, _lesson());
                      if (mounted && r.offerActive(widget.offer))
                        setState(() {
                          final current = [
                            _worked.text,
                            _failed.text,
                            _early.text,
                            _cue.text,
                            _action.text,
                            _category
                          ];
                          final unchanged = List.generate(current.length,
                                  (i) => current[i] == original[i])
                              .every((same) => same);
                          if (unchanged) {
                            _worked.text = draft.worked.join('\n');
                            _failed.text = draft.failed.join('\n');
                            _early.text = draft.earlySignal;
                            _cue.text = draft.ifCue;
                            _action.text = draft.thenAction;
                          }
                          _busy = false;
                        });
                    },
              child: const Text('用 AI 整理已有原话（仍需自己盖印）')),
      ]);

  Widget _sealPreview() {
    final validation = LessonValidator(r.host).validate(_lesson());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('成色 ${validation.quality} / 5 · 有证据 / 有效做法 / 只谈行为 / 预警 / 可检验动作'),
      const SizedBox(height: 12),
      Text('有效：${_worked.text}\n无效：${_failed.text}\n预警：${_early.text}'),
      const SizedBox(height: 12),
      Text(_lesson().rule,
          style: TextStyle(
              fontFamily: r.preferences.manuscript ? _font : null,
              fontSize: 23,
              height: 1.6)),
      if (!validation.valid)
        ...validation.problems
            .map((p) => Text(p, style: const TextStyle(color: prpVermilion))),
      if (r.preferences.surfaces[PrpSurface.quoteHome] == true)
        CheckboxListTile(
            value: _quoteAllowed,
            contentPadding: EdgeInsets.zero,
            title: const Text('允许这句话作为“自己的名言”出现'),
            onChanged: (v) => setState(() => _quoteAllowed = v == true)),
      const SizedBox(height: 14),
      Semantics(
          button: true,
          label: '长按三秒盖印',
          child: Listener(
            onPointerDown: (_) => _startHold(),
            onPointerUp: (_) => _cancelHold(),
            onPointerCancel: (_) => _cancelHold(),
            child: Container(
                key: const ValueKey('prp_seal_hold'),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: prpVermilion,
                    borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  const Center(
                      child: Text('长按 3 秒盖印',
                          style: TextStyle(color: Colors.white, fontSize: 18))),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                      value:
                          (_holdWatch.elapsedMilliseconds / 3000).clamp(0, 1),
                      color: Colors.white,
                      backgroundColor: Colors.white24)
                ])),
          )),
      TextButton(
          onPressed: () => setState(() => _step = PrpStep.signal),
          child: const Text('再改一改')),
    ]);
  }

  Widget _zoom() {
    final done = _days.where((d) => d.status == 'done').length;
    final missed = _days.where((d) => d.status == 'missed').length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.5, end: 1),
          duration: const Duration(milliseconds: 450),
          builder: (_, value, child) => Transform.scale(
              scale: value, alignment: Alignment.centerLeft, child: child),
          child: const Text('已盖印',
              style: TextStyle(
                  color: prpVermilion,
                  fontSize: 22,
                  fontWeight: FontWeight.w800))),
      if (_sealed != null)
        Text(_sealed!.rule, style: const TextStyle(fontSize: 18, height: 1.6)),
      const SizedBox(height: 16),
      Wrap(
          spacing: 5,
          runSpacing: 5,
          children: _days
              .map((d) => Tooltip(
                  message:
                      '${DateTime.fromMillisecondsSinceEpoch(d.dateMs).toString().substring(0, 10)} · ${d.status}',
                  child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: d.status == 'done'
                              ? prpTeal
                              : d.status == 'missed'
                                  ? prpVermilion
                                  : Colors.grey.shade300))))
              .toList()),
      Text(done + missed < 3
          ? '数据还不够，先不下结论。'
          : '近 30 天，记录中有 $missed 次未完成、$done 次完成。灰点是未记录，不算失败。'),
      const SizedBox(height: 12),
      Text('现在的难受程度：$_emotionAfter / 10'),
      Slider(
          value: _emotionAfter.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          onChanged: (v) => setState(() => _emotionAfter = v.round())),
      FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  final close = widget.onFinished;
                  await r.finishZoom(widget.offer, _emotionAfter);
                  close?.call();
                  if (mounted)
                    setState(() {
                      _closed = true;
                      _busy = false;
                    });
                },
          child: const Text('这次先到这里')),
    ]);
  }

  Widget _safetyCard() {
    final content = Material(
        color: const Color(0xfff4f6f5),
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('先照顾此刻的安全',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  const Text('这次复盘已经停止，刚才的输入不会进入教训或回访。可以先联系一位信任的人，陪你待一会儿。'),
                  const SizedBox(height: 12),
                  const SelectableText(
                      '中国大陆心理援助：12356\n如有即时危险：120 / 110\n其它地区请联系当地紧急服务。'),
                  TextButton.icon(
                      onPressed: () =>
                          launchUrl(Uri(scheme: 'tel', path: '12356')),
                      icon: const Icon(Icons.phone_outlined),
                      label: const Text('拨打 12356')),
                ])));
    return Theme(data: prpPaperTheme(context), child: content);
  }
}
