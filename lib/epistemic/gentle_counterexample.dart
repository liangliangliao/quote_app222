import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'cognitive_models.dart';
import 'cognitive_preferences.dart';
import 'cognitive_sheet.dart';
import 'cognitive_store.dart';

bool hasAbsoluteScope(String text) =>
    RegExp(r'总是|永远|一定|每次都|从来不|必然').hasMatch(text);

class GentleCounterexample extends StatefulWidget {
  final String recordId, text;
  const GentleCounterexample(
      {super.key, required this.recordId, required this.text});
  @override
  State<GentleCounterexample> createState() => _GentleCounterexampleState();
}

class _GentleCounterexampleState extends State<GentleCounterexample> {
  bool _visible = false;
  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(covariant GentleCounterexample oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordId != widget.recordId) {
      _visible = false;
      _check();
    }
  }

  Future<void> _check() async {
    if (!hasAbsoluteScope(widget.text) ||
        !CognitivePreferenceStore.enabledInBuild) return;
    final id = widget.recordId;
    await CognitivePreferenceStore.instance.load();
    final prefs = CognitivePreferenceStore.instance.value;
    if (!prefs.enabled || !prefs.prompts) return;
    try {
      final db = await CognitiveStore().database;
      final day = DateTime.now().toIso8601String().substring(0, 10);
      final show = await db.transaction((txn) async {
        final old = await txn.query('app_kv',
            where: 'key=?', whereArgs: ['cognition.gentle.last_day']);
        if (old.isNotEmpty && old.first['value'] == day) return false;
        await txn.insert(
            'app_kv', {'key': 'cognition.gentle.last_day', 'value': day},
            conflictAlgorithm: ConflictAlgorithm.replace);
        return true;
      });
      if (mounted && widget.recordId == id) setState(() => _visible = show);
    } catch (_) {/* Optional hint must never disrupt the conversation. */}
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
                                  onPressed: () =>
                                      setState(() => _visible = false),
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
