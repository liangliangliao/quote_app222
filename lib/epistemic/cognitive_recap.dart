import 'package:flutter/material.dart';
import 'cognitive_models.dart';
import 'cognitive_service.dart';
import 'cognitive_sheet.dart';
import 'cognitive_snapshot_view.dart';
import 'cognitive_mode.dart';
import 'cognitive_preferences.dart';

class CognitiveRecapPage extends StatefulWidget {
  final CognitiveService? service;
  const CognitiveRecapPage({super.key, this.service});
  @override
  State<CognitiveRecapPage> createState() => _CognitiveRecapPageState();
}

class _CognitiveRecapPageState extends State<CognitiveRecapPage> {
  late final _service = widget.service ?? CognitiveService();
  List<CognitiveNote> _notes = [];
  final Set<String> _selected = {};
  bool _busy = true;
  bool _initialized = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    CognitivePreferenceStore.instance.addListener(_modeChanged);
    CognitivePreferenceStore.instance.load().then((_) {
      if (mounted) _modeChanged();
    });
  }

  void _modeChanged() {
    if (CognitivePreferenceStore.active && !_initialized) _load();
  }

  @override
  void dispose() {
    CognitivePreferenceStore.instance.removeListener(_modeChanged);
    super.dispose();
  }

  Future<void> _load() async {
    if (!CognitivePreferenceStore.active) return;
    _initialized = true;
    setState(() {
      _busy = true;
      _error = null;
      _selected.clear();
    });
    try {
      final notes = await _service.store.acceptedForRecap();
      if (mounted)
        setState(() => _notes =
            notes.where((n) => n.task != CognitiveTask.review).toList());
    } catch (_) {
      _initialized = false;
      if (mounted) setState(() => _error = '记录暂未读取，请刷新重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review() async {
    if (!CognitivePreferenceStore.active) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final note = await _service.reviewSelections(
          _notes.where((n) => _selected.contains(n.id)).toList());
      if (mounted)
        await showCognitiveAnalysis(context,
            selection: note.selection,
            task: note.task,
            note: note,
            service: _service);
    } catch (e) {
      if (mounted)
        setState(() => _error = e is StateError || e is ArgumentError
            ? e.toString()
            : '回顾暂未完成，请检查网络与 AI 配置后重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CognitiveModePage(
      title: '认识回顾',
      child: Scaffold(
          backgroundColor: const Color(0xfffaf6ee),
          appBar: AppBar(title: const Text('选取记录，回顾认识的变化'), actions: [
            IconButton(
                tooltip: '刷新可选记录',
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh))
          ]),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('只展示你曾采纳的认识注释。请自行勾选 1–6 条；确认后，仅将下列选中快照发送给全局 AI。',
                style: TextStyle(fontSize: 16, height: 1.6)),
            const SizedBox(height: 8),
            const Text('这是保存时的选文与判断快照，尚未核对原文后续变化。回顾不评价人格或认识水平。'),
            TextButton(
                onPressed: _busy
                    ? null
                    : () => showCognitiveNotes(context,
                        module: 'cognitive_review',
                        recordId: 'saved',
                        store: _service.store),
                child: const Text('查看 / 删除已保存回顾')),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (!_busy && _notes.isEmpty)
              const Text('还没有已采纳的注释。可在日记、名言或念头分析中先选择“采纳这条注释”。'),
            for (final n in _notes)
              Card(
                  child: Column(children: [
                CheckboxListTile(
                    value: _selected.contains(n.id),
                    title: Text(
                        '${n.selection.title} · ${cognitiveModuleLabel(n.selection.module)}'),
                    subtitle: Text(n.selection.text,
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    onChanged: _busy ||
                            (!_selected.contains(n.id) && _selected.length >= 6)
                        ? null
                        : (v) => setState(() {
                              if (v == true) {
                                _selected.add(n.id);
                              } else {
                                _selected.remove(n.id);
                              }
                            })),
                ExpansionTile(
                    expansionAnimationStyle: cognitiveExpansionStyle(context),
                    title: const Text('查看将发送的完整内容'),
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(14),
                          child: CognitiveSnapshotView(
                              snapshot: CognitiveService.reviewSnapshot(n)))
                    ]),
              ])),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: _busy || _selected.isEmpty ? null : _review,
                icon: const Icon(Icons.checklist),
                label: Text('仅分析所选 ${_selected.length} 条记录')),
          ])));
}
