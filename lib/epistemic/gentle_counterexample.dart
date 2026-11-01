import 'package:flutter/material.dart';
import 'cognitive_models.dart';
import 'cognitive_preferences.dart';
import 'cognitive_sheet.dart';
import 'cognitive_hint_budget.dart';
import 'cognitive_scope_hint.dart';
import 'cognitive_usage.dart';

bool hasAbsoluteScope(String text) => findAbsoluteClaim(text) != null;

class GentleCounterexample extends StatefulWidget {
  final String recordId, text;
  const GentleCounterexample(
      {super.key, required this.recordId, required this.text});
  @override
  State<GentleCounterexample> createState() => _GentleCounterexampleState();
}

class _GentleCounterexampleState extends State<GentleCounterexample> {
  bool _visible = false, _checking = false, _dismissed = false;
  @override
  void initState() {
    super.initState();
    CognitivePreferenceStore.instance.addListener(_preferencesChanged);
    _check();
  }

  @override
  void didUpdateWidget(covariant GentleCounterexample oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordId != widget.recordId ||
        oldWidget.text != widget.text) {
      _visible = false;
      _dismissed = false;
      _check();
    }
  }

  Future<void> _check() async {
    if (_checking ||
        _dismissed ||
        !hasAbsoluteScope(widget.text) ||
        !CognitivePreferenceStore.enabledInBuild) return;
    _checking = true;
    final id = widget.recordId;
    final text = widget.text;
    try {
      await CognitivePreferenceStore.instance.load();
      final prefs = CognitivePreferenceStore.instance.value;
      if (!prefs.enabled || !prefs.prompts) return;
      final show = await CognitiveHintBudget().claim();
      if (mounted &&
          widget.recordId == id &&
          widget.text == text &&
          CognitivePreferenceStore.active &&
          CognitivePreferenceStore.instance.value.prompts) {
        setState(() => _visible = show);
        if (show) CognitiveUsageStore.instance.track(CognitiveEvent.hintShown);
      }
    } catch (_) {
      /* Optional hint must never disrupt the conversation. */
    } finally {
      _checking = false;
    }
  }

  void _preferencesChanged() {
    if (!_visible && !_dismissed && CognitivePreferenceStore.active) _check();
  }

  @override
  void dispose() {
    CognitivePreferenceStore.instance.removeListener(_preferencesChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<CognitivePreferences>(
          valueListenable: CognitivePreferenceStore.instance,
          builder: (context, prefs, _) => !_visible ||
                  !prefs.enabled ||
                  !prefs.prompts
              ? const SizedBox.shrink()
              : Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Expanded(
                                  child: Text('是否也存在一次例外？',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                              IconButton(
                                  tooltip: '今天不再提示',
                                  onPressed: () {
                                    setState(() {
                                      _visible = false;
                                      _dismissed = true;
                                    });
                                    CognitiveUsageStore.instance
                                        .track(CognitiveEvent.hintSkipped);
                                  },
                                  icon: const Icon(Icons.close))
                            ]),
                            const Text('感受可以保留；“这一次”是否足以支持“总是”，可以慢慢核查。'),
                            Text(widget.text,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            TextButton(
                                onPressed: () => showCognitiveAnalysis(context,
                                    task: CognitiveTask.calibration,
                                    selection: CognitiveSelection.fromText(
                                        module: 'enemy_message',
                                        recordId: widget.recordId,
                                        title: '我说的这句话',
                                        fullText: widget.text),
                                    currentText: () => widget.text),
                                child: const Text('只分析这句话的范围与反例')),
                          ]))));
}
