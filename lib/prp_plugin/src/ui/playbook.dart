import 'dart:async';

import 'package:flutter/material.dart';

import '../../prp_plugin.dart';
import '../runtime.dart';
import 'presentation.dart';
import 'feature_pages.dart';

class PrpPlaybook extends StatefulWidget {
  const PrpPlaybook(
      {super.key, required this.runtime, this.management = false});
  final PrpRuntime runtime;
  final bool management;
  @override
  State<PrpPlaybook> createState() => _PrpPlaybookState();
}

class _PrpPlaybookState extends State<PrpPlaybook> {
  List<PrpLesson> _lessons = [];
  String _font = 'QuoteXingShu';
  String _error = '';
  bool _loading = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    PrpPlugin.changes.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    PrpPlugin.changes.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    try {
      final lessons = await widget.runtime.store.lessons();
      final font = await widget.runtime.host.calligraphyFont();
      if (mounted && generation == _generation)
        setState(() {
          _lessons = lessons;
          _font = font;
          _loading = false;
          _error = '';
        });
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() {
          _loading = false;
          _error = '教训手册暂时读不到，请稍后重试。';
        });
    }
  }

  Future<void> _edit(PrpLesson lesson) async {
    final r = widget.runtime;
    final offer = await r.resumeLesson(lesson, rewrite: lesson.isSealed);
    if (!mounted || offer == null) return;
    await r.showOffer(context, offer, fullScreen: true);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: prpPaperTheme(context), child: Builder(builder: _content));
  }

  Widget _content(BuildContext context) {
    final r = widget.runtime;
    if (!widget.management && !r.enabledFor(PrpSurface.enemy))
      return const SizedBox.shrink();
    if (_loading)
      return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()));
    final drafts = _lessons.where((l) => l.state == 'draft').length;
    return Material(
        color: const Color(0xfff7f5f0),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('我的教训手册',
                  style: TextStyle(
                      fontSize: 20,
                      color: Color(0xff30363b),
                      fontWeight: FontWeight.w700)),
              Text('待盖印 $drafts 条 · 教训是假设，下一次是实验。',
                  style: const TextStyle(color: prpIndigo)),
              if (!r.preferences.enabled)
                const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('插件已关闭。数据保留在这里，不会在其它功能中出现。')),
              if (_error.isNotEmpty) Text(_error),
              if (_lessons.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('还没有教训。先从一次具体的经历开始。')),
              for (final lesson in _lessons)
                Card(
                    key: ValueKey('prp_lesson_${lesson.id}'),
                    elevation: 0,
                    child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: Text(
                                        '${lesson.category} · ${lesson.source.label}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600))),
                                Text(
                                    switch (lesson.state) {
                                      'sealed' => '已盖印',
                                      'retired' => '历史版本',
                                      _ => '待盖印'
                                    },
                                    style: TextStyle(
                                        color: lesson.isSealed
                                            ? prpVermilion
                                            : Colors.grey))
                              ]),
                              if (lesson.triggerText.isNotEmpty)
                                Text(lesson.triggerText),
                              const SizedBox(height: 8),
                              Text(
                                  '有效：${lesson.worked.isEmpty ? '待补充' : lesson.worked.join('；')}',
                                  style: const TextStyle(color: prpTeal)),
                              Text(
                                  '无效：${lesson.failed.isEmpty ? '待补充' : lesson.failed.join('；')}'),
                              if (lesson.earlySignal.isNotEmpty)
                                Text('预警：${lesson.earlySignal}'),
                              if (lesson.insight.isNotEmpty)
                                Text('这次看见：${lesson.insight}'),
                              if (lesson.ifCue.isNotEmpty ||
                                  lesson.thenAction.isNotEmpty)
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Text(lesson.rule,
                                        style: TextStyle(
                                            fontFamily: r.preferences.manuscript
                                                ? _font
                                                : null,
                                            fontSize: 23,
                                            height: 1.5,
                                            color: const Color(0xff30363b)))),
                              if (r.preferences.manuscript)
                                for (final sentence in lesson.sentences
                                    .where((s) => s.revision.isNotEmpty)) ...[
                                  PrpCrossedOutText(sentence.text),
                                  Text(sentence.revision,
                                      style: const TextStyle(color: prpTeal)),
                                ],
                              Text(
                                  '成色 ${lesson.quality}/5 · 已验证 ${lesson.verifiedCount} 次 · 再次未完成 ${lesson.repeatedCount} 次',
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xff626675))),
                              if (lesson.parentId != null)
                                Text('改写自第 ${lesson.parentId} 条，历史保留',
                                    style: const TextStyle(fontSize: 12)),
                              if (lesson.isSealed && lesson.repeatedCount >= 2)
                                const Text('这条教训没挡住这次。它可能写得不对，不是你不行。要改一版吗？'),
                              if (lesson.state != 'retired' &&
                                  r.enabledFor(lesson.source)) ...[
                                TextButton.icon(
                                    onPressed: () => _edit(lesson),
                                    icon: Icon(lesson.isSealed
                                        ? Icons.edit_outlined
                                        : Icons.play_arrow),
                                    label: Text(lesson.isSealed
                                        ? '改写为新版本'
                                        : '继续补充并盖印')),
                                if (lesson.isSealed)
                                  SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('允许作为自己的名言',
                                          style: TextStyle(fontSize: 14)),
                                      value: lesson.quoteAllowed,
                                      onChanged: (v) =>
                                          r.setQuoteAllowed(lesson, v)),
                                if (lesson.isSealed && r.preferences.voice)
                                  PrpVoiceControl(runtime: r, lesson: lesson),
                                if (lesson.isSealed &&
                                    r.enabledFor(PrpSurface.enemy))
                                  TextButton.icon(
                                      icon:
                                          const Icon(Icons.assignment_outlined),
                                      label: const Text('确认后转成字据'),
                                      onPressed: () async {
                                        final hours = await showDialog<int>(
                                            context: context,
                                            builder: (ctx) => SimpleDialog(
                                                    title: const Text(
                                                        '把这条教训转成字据？'),
                                                    children: [
                                                      const Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                  16),
                                                          child: Text(
                                                              '不设置赌注；由敌人沿用原有护栏检查。请选择截止时间。')),
                                                      for (final h in [
                                                        2,
                                                        24,
                                                        48
                                                      ])
                                                        SimpleDialogOption(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    ctx, h),
                                                            child:
                                                                Text('$h 小时后'))
                                                    ]));
                                        if (hours == null) return;
                                        final message =
                                            await r.convertToCommitment(
                                                lesson,
                                                r.clock().add(
                                                    Duration(hours: hours)));
                                        if (context.mounted)
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(message)));
                                      }),
                              ],
                            ]))),
            ])));
  }
}

class PrpRecallChip extends StatefulWidget {
  const PrpRecallChip(
      {super.key, required this.runtime, required this.contextValue});
  final PrpRuntime runtime;
  final PrpContext contextValue;
  @override
  State<PrpRecallChip> createState() => _PrpRecallChipState();
}

class _PrpRecallChipState extends State<PrpRecallChip> {
  late Future<List<PrpRecall>> _recalls;
  int _dataRevision = PrpPlugin.changes.value;
  bool _dismissed = false;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _recalls = widget.runtime.recallFor(widget.contextValue);
  }

  @override
  void didUpdateWidget(PrpRecallChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final a = oldWidget.contextValue, b = widget.contextValue;
    if (a.subjectKey != b.subjectKey ||
        a.text != b.text ||
        a.category != b.category ||
        a.reference != b.reference ||
        a.location != b.location ||
        _dataRevision != PrpPlugin.changes.value) {
      _dataRevision = PrpPlugin.changes.value;
      _dismissed = false;
      _recalls = widget.runtime.recallFor(b);
    }
  }

  Future<void> _report(PrpRecall recall, PrpOutcome outcome) async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.runtime.reportOutcome(recall.id, outcome);
    if (mounted)
      setState(() {
        _dismissed = true;
        _busy = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: prpPaperTheme(context), child: Builder(builder: _content));
  }

  Widget _content(BuildContext context) {
    if (_dismissed || !widget.runtime.enabledFor(widget.contextValue.surface))
      return const SizedBox.shrink();
    return FutureBuilder<List<PrpRecall>>(
        future: _recalls,
        builder: (ctx, snapshot) {
          final recalls = snapshot.data ?? [];
          if (recalls.isEmpty) return const SizedBox.shrink();
          final recall = recalls.first;
          final lesson = recall.lesson;
          return Card(
              color: const Color(0xfffff3d8),
              elevation: 0,
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('上次盖印的话 · 尚未验证 · 类似情况第 ${recall.similarCount} 次',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text('有效：${lesson.worked.join('；')}',
                            style: const TextStyle(color: prpTeal)),
                        Text('无效：${lesson.failed.join('；')}'),
                        const SizedBox(height: 6),
                        Text('「${lesson.rule}」',
                            style: const TextStyle(fontSize: 17, height: 1.5)),
                        const Text('这次要试一下吗？有结果再记账；没有记录就保持未验证。',
                            style: TextStyle(fontSize: 12)),
                        PrpAdoptionButton(
                            runtime: widget.runtime, recall: recall),
                        Wrap(spacing: 8, children: [
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _report(recall, PrpOutcome.helped),
                              child: const Text('试过，有帮助')),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _report(recall, PrpOutcome.repeated),
                              child: const Text('试过，没挡住')),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _report(recall, PrpOutcome.ignored),
                              child: const Text('这次先不用')),
                        ]),
                        if (lesson.repeatedCount >= 2 &&
                            widget.runtime.enabledFor(lesson.source))
                          TextButton(
                              onPressed: () async {
                                final offer = await widget.runtime
                                    .resumeLesson(lesson, rewrite: true);
                                if (ctx.mounted && offer != null)
                                  await widget.runtime
                                      .showOffer(ctx, offer, fullScreen: true);
                              },
                              child: const Text('改一版教训')),
                        if (widget.runtime.preferences.voice &&
                            lesson.voicePath.isNotEmpty)
                          TextButton.icon(
                              onPressed: () async {
                                if (widget.runtime
                                    .enabledFor(widget.contextValue.surface)) {
                                  try {
                                    await widget.runtime.host
                                        .playRecording(lesson.voicePath);
                                  } catch (_) {}
                                }
                              },
                              icon: const Icon(Icons.volume_up_outlined),
                              label: const Text('听听自己的提醒')),
                      ])));
        });
  }
}

class PrpVoiceControl extends StatefulWidget {
  const PrpVoiceControl(
      {super.key, required this.runtime, required this.lesson});
  final PrpRuntime runtime;
  final PrpLesson lesson;
  @override
  State<PrpVoiceControl> createState() => _PrpVoiceControlState();
}

class _PrpVoiceControlState extends State<PrpVoiceControl>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _recording = false;
  bool _busy = false;
  String? _path;
  String _error = '';
  int _seconds = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _recording && !_busy)
      unawaited(_stop());
  }

  Future<void> _start() async {
    if (_busy || _recording || !widget.runtime.enabledFor(widget.lesson.source))
      return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final path = await widget.runtime.host.startRecording(widget.lesson.id);
      if (!mounted ||
          !widget.runtime.enabledFor(widget.lesson.source) ||
          !widget.runtime.preferences.voice) {
        await widget.runtime.host.stopAudio();
        if (path != null) await widget.runtime.host.deleteRecordings([path]);
        return;
      }
      if (path == null) {
        setState(() {
          _busy = false;
          _error = '未获得录音权限，或设备不支持。';
        });
        return;
      }
      _path = path;
      setState(() {
        _recording = true;
        _busy = false;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= 15) unawaited(_stop());
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = '录音暂不可用。';
        });
    }
  }

  Future<void> _stop() async {
    if (_busy || !_recording) return;
    _timer?.cancel();
    setState(() => _busy = true);
    try {
      await widget.runtime.host.stopRecording();
      final path = _path;
      if (path != null &&
          widget.runtime.enabledFor(widget.lesson.source) &&
          widget.runtime.preferences.voice) {
        final saved = await widget.runtime.saveVoicePath(widget.lesson, path);
        if (!saved) await widget.runtime.host.deleteRecordings([path]);
        _path = null;
      }
      if (mounted)
        setState(() {
          _recording = false;
          _busy = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _recording = false;
          _busy = false;
          _error = '录音保存失败。';
        });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (_recording)
      unawaited(widget.runtime.host.stopAudio().catchError((Object _) {}));
    if (_path != null)
      unawaited(widget.runtime.host
          .deleteRecordings([_path!]).catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('录一句 15 秒以内的提醒，用自己的称呼开头，例如“小林，先打开书读 1 页”。录音只保存在本机。',
            style: TextStyle(fontSize: 12)),
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : _recording
                      ? _stop
                      : _start,
              icon: Icon(_recording ? Icons.stop : Icons.mic_none),
              label: Text(_recording ? '结束录音 $_seconds / 15 秒' : '录下自己的提醒')),
          if (widget.lesson.voicePath.isNotEmpty)
            TextButton.icon(
                onPressed: () async {
                  try {
                    await widget.runtime.host
                        .playRecording(widget.lesson.voicePath);
                  } catch (_) {}
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('播放')),
        ]),
        if (_error.isNotEmpty) Text(_error),
      ]);
}
