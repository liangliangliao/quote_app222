import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core.dart';
import '../engine.dart';
import '../lesson_validator.dart';
import '../models.dart';
import '../templates.dart';
import '../text_guard.dart';
import 'seal_stamp.dart';

typedef PrpCloseCallback = void Function(PrpSessionResult result);

/// 以全屏页的形式打开一次会话，结束时返回结果。
Future<PrpSessionResult?> openPrpSessionPage(
  BuildContext context,
  PrpCore core,
  PrpOffer offer,
) {
  return Navigator.of(context).push<PrpSessionResult>(
    MaterialPageRoute<PrpSessionResult>(
      fullscreenDialog: true,
      builder: (BuildContext ctx) => PopScope(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(
            title: Text(PrpCopy(offer.voice).sessionTitle),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: PrpSessionCard(
              core: core,
              offer: offer,
              onClose: (PrpSessionResult r) => Navigator.of(ctx).pop(r),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 一次 PRP 会话：缓一缓 → 对账 → 双栏 → 预警与如果—那么 → 盖印 → 拉远。
class PrpSessionCard extends StatefulWidget {
  const PrpSessionCard({
    super.key,
    required this.core,
    required this.offer,
    this.onClose,
  });

  final PrpCore core;
  final PrpOffer offer;
  final PrpCloseCallback? onClose;

  @override
  State<PrpSessionCard> createState() => _PrpSessionCardState();
}

class _PrpSessionCardState extends State<PrpSessionCard> {
  late final PrpCopy _copy = PrpCopy(widget.offer.voice);
  PrpSignal get _sig => widget.offer.signal;
  int get _sessionId => widget.offer.sessionId;

  PrpStep _step = PrpStep.pause;
  bool _busy = false;
  bool _crisis = false;
  String? _crisisMsg;

  // 缓一缓
  int _pauseTotal = _kDefaultPauseSec;
  int _left = _kDefaultPauseSec;
  Timer? _timer;
  double _emotionBefore = 5;
  final TextEditingController _pauseNote = TextEditingController();

  // 对账
  final TextEditingController _words = TextEditingController();
  List<ClassifiedSentence> _sentences = <ClassifiedSentence>[];
  bool _split = false;

  // 双栏
  final TextEditingController _workedCtl = TextEditingController();
  final TextEditingController _failedCtl = TextEditingController();
  final List<String> _worked = <String>[];
  final List<String> _failed = <String>[];
  String _category = kPrpCategories.first;
  String? _failedWarn;

  // 预警与如果—那么
  final TextEditingController _signalCtl = TextEditingController();
  final TextEditingController _cueCtl = TextEditingController();
  final TextEditingController _actionCtl = TextEditingController();

  // 盖印
  LessonCheck? _check;
  double _hold = 0;
  Timer? _holdTimer;
  bool _sealed = false;
  String? _sealError;

  // 拉远
  List<PrpMark>? _marks;
  double _emotionAfter = 5;

  @override
  void initState() {
    super.initState();
    _category =
        _sig.category ?? widget.offer.prefill?.category ?? kPrpCategories.first;
    if (!kPrpCategories.contains(_category)) _category = kPrpCategories.last;
    final PrpLesson? pre = widget.offer.prefill;
    if (pre != null) {
      _worked.addAll(pre.worked);
      _failed.addAll(pre.failed);
      _signalCtl.text = pre.earlySignal;
      _cueCtl.text = pre.ifCue;
      _actionCtl.text = pre.thenAction;
    }
    _loadPause();
  }

  Future<void> _loadPause() async {
    int sec = _kDefaultPauseSec;
    try {
      sec = await widget.core.settings.pauseSec();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _pauseTotal = sec;
      _left = sec;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_left > 0) setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _holdTimer?.cancel();
    for (final TextEditingController c in <TextEditingController>[
      _pauseNote,
      _words,
      _workedCtl,
      _failedCtl,
      _signalCtl,
      _cueCtl,
      _actionCtl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ───────────────────────── 公共小工具 ─────────────────────────

  String _allText() => <String>[
    _pauseNote.text,
    _words.text,
    _workedCtl.text,
    _failedCtl.text,
    _signalCtl.text,
    _cueCtl.text,
    _actionCtl.text,
    ..._worked,
    ..._failed,
  ].join('\n');

  /// 任何一步离开前都过一遍危机词。命中就退场，并告诉调用方。
  Future<bool> _crisisGate() async {
    final GuardResult g = widget.core.host.guardText(_allText());
    if (!g.crisis) return false;
    await widget.core.crisisExit(_sessionId);
    if (!mounted) return true;
    setState(() {
      _crisis = true;
      _crisisMsg = g.message ?? _copy.crisisFallback;
    });
    return true;
  }

  void _close(PrpSessionResult r) {
    final PrpCloseCallback? cb = widget.onClose;
    if (cb != null) {
      cb(r);
    } else {
      Navigator.of(context).maybePop(r);
    }
  }

  LessonDraft _draft() => LessonDraft(
    category: _category,
    worked: List<String>.of(_worked),
    failed: List<String>.of(_failed),
    earlySignal: _signalCtl.text.trim(),
    ifCue: _cueCtl.text.trim(),
    thenAction: _actionCtl.text.trim(),
  );

  List<String> _userFacts() => SentenceClassifier.factsOf(_sentences);

  Future<void> _saveDraft() => widget.core.saveDraft(
    _sessionId,
    _sig,
    _draft(),
    userFacts: _userFacts(),
    parentId: widget.offer.prefill?.id,
  );

  Future<void> _skip() async {
    if (await _crisisGate()) return;
    await _saveDraft();
    await widget.core.finish(_sessionId, outcome: 'skipped');
    _close(const PrpSessionResult(skipped: true));
  }

  String _problemText(LessonCheck c) {
    final List<String> out = <String>[];
    if (c.missing.contains('worked')) out.add('还没写“有效”的做法');
    if (c.missing.contains('failed')) out.add('“没起作用”要写具体场景');
    if (c.missing.contains('if_then')) out.add('还差“如果—那么”');
    if (c.problems.contains('identity')) out.add('里面有对你自己的评价，请改成做法');
    if (c.problems.contains('action_too_long')) out.add('动作超过 40 字');
    return out.isEmpty ? '还不能盖印' : '还差：${out.join('；')}';
  }

  // ───────────────────────── 步骤切换 ─────────────────────────

  int get _elapsed => _pauseTotal - _left;
  int get _minWait => math.min(30, _pauseTotal);

  Future<void> _toLedger() async {
    if (await _crisisGate()) return;
    _timer?.cancel();
    await widget.core.setStep(
      _sessionId,
      PrpStep.ledger,
      pauseSec: _elapsed,
      emotionBefore: _emotionBefore.round(),
    );
    if (!mounted) return;
    setState(() => _step = PrpStep.ledger);
  }

  void _doSplit() {
    setState(() {
      _sentences = SentenceClassifier.classify(_words.text);
      _split = true;
    });
  }

  Future<void> _toColumns() async {
    if (await _crisisGate()) return;
    await widget.core.setStep(_sessionId, PrpStep.columns);
    if (!mounted) return;
    setState(() => _step = PrpStep.columns);
  }

  Future<void> _toSignal() async {
    if (await _crisisGate()) return;
    await _saveDraft();
    await widget.core.setStep(_sessionId, PrpStep.signal);
    if (!mounted) return;
    setState(() => _step = PrpStep.signal);
  }

  Future<void> _toSeal() async {
    if (await _crisisGate()) return;
    await _saveDraft();
    await widget.core.setStep(_sessionId, PrpStep.seal);
    final LessonCheck check = widget.core.engine.validator.check(
      _draft(),
      hasEvidence: widget.core.engine.evidenceOf(_sig, _userFacts()).isNotEmpty,
    );
    if (!mounted) return;
    setState(() {
      _check = check;
      _sealError = null;
      _step = PrpStep.seal;
    });
  }

  void _startHold() {
    if (_sealed || _busy || !(_check?.canSeal ?? false)) return;
    _holdTimer?.cancel();
    setState(() => _hold = 0);
    _holdTimer = Timer.periodic(const Duration(milliseconds: 50), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _hold = math.min(1.0, _hold + 50 / 3000));
      if (_hold >= 1.0) {
        t.cancel();
        _doSeal();
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    if (!_sealed && mounted) setState(() => _hold = 0);
  }

  Future<void> _doSeal() async {
    if (_busy || _sealed) return;
    _busy = true;
    if (await _crisisGate()) {
      _busy = false;
      return;
    }
    final SealResult? r = await widget.core.seal(
      _sessionId,
      _sig,
      _draft(),
      userFacts: _userFacts(),
      parentId: widget.offer.prefill?.id,
    );
    if (!mounted) return;
    if (r != null && r.ok) {
      HapticFeedback.mediumImpact();
      setState(() {
        _sealed = true;
        _busy = false;
        _hold = 1;
      });
      await widget.core.setStep(_sessionId, PrpStep.zoom);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      await _enterZoom();
    } else {
      setState(() {
        _busy = false;
        _hold = 0;
        _sealError = r == null ? '这次没能保存，稍后再试。' : _problemText(r.check);
      });
    }
  }

  Future<void> _enterZoom() async {
    List<PrpMark> marks = const <PrpMark>[];
    try {
      marks = await widget.core.host.recentMarks(_sig.subjectKey);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _marks = marks;
      _step = PrpStep.zoom;
    });
  }

  Future<void> _saveDraftAndLeave() async {
    if (await _crisisGate()) return;
    await _saveDraft();
    await widget.core.finish(_sessionId, outcome: 'skipped');
    _close(const PrpSessionResult(skipped: true));
  }

  Future<void> _finish() async {
    await widget.core.finish(
      _sessionId,
      emotionAfter: _emotionAfter.round(),
      outcome: _sealed ? 'sealed' : 'skipped',
    );
    _close(PrpSessionResult(sealed: _sealed));
  }

  // ───────────────────────── 构件 ─────────────────────────

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: Theme.of(context).textTheme.titleLarge),
  );

  Widget _body(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: Theme.of(context).textTheme.bodyMedium),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 4),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _label('$label：${value.round()}'),
        Slider(
          value: value,
          min: 0,
          max: 10,
          divisions: 10,
          label: '${value.round()}',
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController c,
    String hint, {
    int lines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: c,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 2,
      maxLength: maxLength,
      decoration: InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _primary(String text, VoidCallback? onPressed) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: SizedBox(
      width: double.infinity,
      child: FilledButton(onPressed: onPressed, child: Text(text)),
    ),
  );

  Widget _skipButton(String text) => Align(
    alignment: Alignment.centerRight,
    child: TextButton(onPressed: _skip, child: Text(text)),
  );

  // ───────────────────────── 各步骤 ─────────────────────────

  List<Widget> _pauseStep() {
    final bool ready = _elapsed >= _minWait;
    final int waitLeft = math.max(0, _minWait - _elapsed);
    return <Widget>[
      _title(_copy.pauseTitle),
      _body(_copy.pauseBody(_pauseTotal)),
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '$_left',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w300),
          ),
        ),
      ),
      _slider(
        _copy.emotionBeforeLabel,
        _emotionBefore,
        (double v) => setState(() => _emotionBefore = v),
      ),
      _label('允许句（点一下可以带进下面的框）'),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: kAllowPhrases
            .map(
              (String p) => ActionChip(
                label: Text(p),
                onPressed: () => setState(() {
                  final String cur = _pauseNote.text;
                  _pauseNote.text = cur.isEmpty ? p : '$cur\n$p';
                }),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 8),
      _field(_pauseNote, _copy.pauseHint, lines: 2),
      _primary(
        ready ? _copy.pauseReady : _copy.pauseWait(waitLeft),
        ready ? _toLedger : null,
      ),
      _skipButton(_copy.pauseSkip),
    ];
  }

  List<Widget> _ledgerStep() {
    final List<Widget> actual = _sig.facts.isEmpty
        ? <Widget>[const Text('（没有更多记录）')]
        : _sig.facts.map((String f) => Text('· $f')).toList();
    return <Widget>[
      _title(_copy.ledgerTitle),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _label(_copy.ledgerExpected),
              Text(_sig.expected.isEmpty ? '（未写明）' : _sig.expected),
              _label(_copy.ledgerActual),
              ...actual,
            ],
          ),
        ),
      ),
      _label(_copy.ledgerYourWords),
      _field(_words, _copy.ledgerHint, lines: 3),
      if (!_split)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _words.text.trim().isEmpty ? null : _doSplit,
            child: Text(_copy.ledgerSplit),
          ),
        ),
      if (_split) ..._sentenceChips(),
      _primary('下一步', _toColumns),
      _skipButton(_copy.pauseSkip),
    ];
  }

  String _kindLabel(SentenceKind k) {
    switch (k) {
      case SentenceKind.fact:
        return _copy.kindFact;
      case SentenceKind.interpretation:
        return _copy.kindInterpretation;
      case SentenceKind.selfBlame:
        return _copy.kindSelfBlame;
    }
  }

  SentenceKind _nextKind(SentenceKind k) {
    switch (k) {
      case SentenceKind.fact:
        return SentenceKind.interpretation;
      case SentenceKind.interpretation:
        return SentenceKind.selfBlame;
      case SentenceKind.selfBlame:
        return SentenceKind.fact;
    }
  }

  List<Widget> _sentenceChips() {
    final bool hasBlame = _sentences.any(
      (ClassifiedSentence s) => s.kind == SentenceKind.selfBlame,
    );
    return <Widget>[
      _label(_copy.ledgerTapToChange),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: <Widget>[
          for (int i = 0; i < _sentences.length; i++)
            ActionChip(
              label: Text(
                '${_kindLabel(_sentences[i].kind)}｜${_sentences[i].text}',
                style: TextStyle(
                  color: _sentences[i].kind == SentenceKind.selfBlame
                      ? Colors.grey
                      : null,
                  decoration: _sentences[i].kind == SentenceKind.selfBlame
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              onPressed: () => setState(() {
                _sentences[i] = _sentences[i].withKind(
                  _nextKind(_sentences[i].kind),
                );
              }),
            ),
        ],
      ),
      if (hasBlame)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _copy.ledgerNotAccounted,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
    ];
  }

  void _addWorked() {
    final String t = _workedCtl.text.trim();
    if (t.length < LessonValidator.minItemChars) return;
    setState(() {
      _worked.add(t);
      _workedCtl.clear();
    });
  }

  void _addFailed() {
    final String t = _failedCtl.text.trim();
    if (t.isEmpty) return;
    if (VagueCheck.isVague(t)) {
      setState(() => _failedWarn = _copy.columnsFailedHint);
      return;
    }
    setState(() {
      _failed.add(t);
      _failedCtl.clear();
      _failedWarn = null;
    });
  }

  Widget _itemList(List<String> items) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: <Widget>[
      for (int i = 0; i < items.length; i++)
        InputChip(
          label: Text(items[i]),
          onDeleted: () => setState(() => items.removeAt(i)),
        ),
    ],
  );

  List<Widget> _columnsStep() {
    final bool canNext = _worked.isNotEmpty && _failed.isNotEmpty;
    return <Widget>[
      _title(_copy.columnsTitle),
      _body(_copy.columnsWorkedHint),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: _field(_workedCtl, '这次做对的一件事')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _addWorked, child: Text(_copy.addItem)),
        ],
      ),
      _itemList(_worked),
      _label(_copy.columnsFailedTitle),
      _body(_copy.columnsFailedHint),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: _field(_failedCtl, '当时在做什么、什么没起作用')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _addFailed, child: Text(_copy.addItem)),
        ],
      ),
      if (_failedWarn != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_failedWarn!, style: const TextStyle(color: kPrpSeal)),
        ),
      _itemList(_failed),
      _label(_copy.categoryLabel),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: kPrpCategories
            .map(
              (String c) => ChoiceChip(
                label: Text(c),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              ),
            )
            .toList(),
      ),
      _primary('下一步', canNext ? _toSignal : null),
      if (!canNext)
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            '“有效”和“没起作用”各至少写一条。',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      _skipButton(_copy.sealLater),
    ];
  }

  List<Widget> _signalStep() {
    final List<String> examples =
        kEarlySignalExamples[_category] ?? const <String>[];
    final int len = _actionCtl.text.trim().length;
    return <Widget>[
      _title(_copy.signalTitle),
      _field(_signalCtl, _copy.signalHint),
      if (examples.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: examples
                .map(
                  (String e) => ActionChip(
                    label: Text(e),
                    onPressed: () => setState(() => _signalCtl.text = e),
                  ),
                )
                .toList(),
          ),
        ),
      _label(_copy.ifThenTitle),
      _field(_cueCtl, _copy.ifHint),
      const SizedBox(height: 8),
      _field(_actionCtl, _copy.thenHint),
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          '$len/${LessonValidator.maxActionChars}',
          style: TextStyle(
            color: len > LessonValidator.maxActionChars
                ? kPrpSeal
                : Colors.grey,
          ),
        ),
      ),
      _primary('下一步', _toSeal),
      _skipButton(_copy.sealLater),
    ];
  }

  String _line(String title, List<String> items) =>
      items.isEmpty ? '' : '$title：${items.join('、')}';

  List<Widget> _sealStep() {
    final PrpLesson preview = PrpLesson(
      worked: _worked,
      failed: _failed,
      ifCue: _cueCtl.text.trim(),
      thenAction: _actionCtl.text.trim(),
      createdMs: 0,
    );
    final LessonCheck? check = _check;
    final bool canSeal = check?.canSeal ?? false;
    return <Widget>[
      _title(_copy.sealTitle),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_worked.isNotEmpty) Text(_line('有效', _worked)),
                    if (_failed.isNotEmpty) Text(_line('没起作用', _failed)),
                    if (_signalCtl.text.trim().isNotEmpty)
                      Text('最早的信号：${_signalCtl.text.trim()}'),
                    if (preview.hasIfThen)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '如果${preview.ifCue}，我就${preview.thenAction}。',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    if (check != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _copy.qualityLine(check.quality),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
              PrpSealStamp(active: _sealed),
            ],
          ),
        ),
      ),
      if (!canSeal && check != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _problemText(check),
            style: const TextStyle(color: kPrpSeal),
          ),
        ),
      if (_sealError != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_sealError!, style: const TextStyle(color: kPrpSeal)),
        ),
      _body(_copy.sealHint),
      GestureDetector(
        onTapDown: (_) => _startHold(),
        onTapUp: (_) => _cancelHold(),
        onTapCancel: _cancelHold,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(
              color: canSeal ? kPrpSeal : Colors.grey,
              width: 1.6,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _hold,
                  child: Container(
                    decoration: BoxDecoration(
                      color: kPrpSeal.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  _sealed ? _copy.sealDone : _copy.sealHold,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: canSeal ? kPrpSeal : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      if (!_sealed) _skipButtonSeal(),
    ];
  }

  Widget _skipButtonSeal() => Align(
    alignment: Alignment.centerRight,
    child: TextButton(
      onPressed: _saveDraftAndLeave,
      child: Text(_copy.sealLater),
    ),
  );

  List<Widget> _zoomStep() {
    final List<PrpMark> marks = _marks ?? const <PrpMark>[];
    final int done = marks.where((PrpMark m) => m.status == 'done').length;
    final int missed = marks.where((PrpMark m) => m.status == 'missed').length;
    final bool enough = marks.length >= 3;
    return <Widget>[
      _title(_copy.zoomTitle),
      if (!enough) _body(_copy.zoomInsufficient),
      if (enough) ...<Widget>[
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: marks.map((PrpMark m) {
            final bool mine = m.label == _sig.subjectKey;
            final Color c = m.status == 'done'
                ? const Color(0xFF2A6F6B)
                : (m.status == 'missed' ? kPrpSeal : Colors.grey);
            return Container(
              width: mine ? 18 : 12,
              height: mine ? 18 : 12,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: mine
                    ? Border.all(color: Colors.black87, width: 2)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        _body(_copy.zoomLine(total: marks.length, done: done, missed: missed)),
      ],
      _slider(
        _copy.emotionAfterLabel,
        _emotionAfter,
        (double v) => setState(() => _emotionAfter = v),
      ),
      _primary(_copy.finish, _finish),
    ];
  }

  Widget _crisisView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _title('先放一放'),
        _body(_crisisMsg ?? _copy.crisisFallback),
        _primary('好', () => _close(const PrpSessionResult(crisis: true))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_crisis) return _crisisView();
    List<Widget> children;
    switch (_step) {
      case PrpStep.pause:
        children = _pauseStep();
        break;
      case PrpStep.ledger:
        children = _ledgerStep();
        break;
      case PrpStep.columns:
        children = _columnsStep();
        break;
      case PrpStep.signal:
        children = _signalStep();
        break;
      case PrpStep.seal:
        children = _sealStep();
        break;
      case PrpStep.zoom:
      case PrpStep.done:
        children = _zoomStep();
        break;
    }
    return ListView(padding: const EdgeInsets.all(16), children: children);
  }
}

/// 缓一缓的默认秒数（设置读取失败时的兜底）。
const int _kDefaultPauseSec = 60;
