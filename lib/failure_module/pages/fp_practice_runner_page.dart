import 'dart:convert';
import 'package:flutter/material.dart';
import '../fp_dao.dart';
import '../fp_models.dart';
import '../widgets/fp_template_form.dart';

class FpPracticeRunnerPage extends StatefulWidget {
  final String taskId;
  final String? relatedSegmentId;
  const FpPracticeRunnerPage({
    super.key,
    required this.taskId,
    this.relatedSegmentId,
  });

  @override
  State<FpPracticeRunnerPage> createState() => _FpPracticeRunnerPageState();
}

class _FpPracticeRunnerPageState extends State<FpPracticeRunnerPage> {
  final _dao = FpDao();
  bool _loading = true;
  String? _err;
  FpTask? _task;
  FpTemplate? _tpl;
  List<FpPracticeRun> _recent = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await _dao.getTask(widget.taskId);
      if (t == null) throw Exception('练习不存在：${widget.taskId}');
      final tp = await _dao.getTemplate(t.templateId);
      final recent = await _dao.listPracticeRuns(taskId: t.taskId, limit: 5);
      if (!mounted) return;
      setState(() {
        _task = t;
        _tpl = tp;
        _recent = recent;
        _loading = false;
        _err = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString();
      });
    }
  }

  String _prettyResult(Map<String, dynamic> r) {
    final buf = StringBuffer();
    for (final k in r.keys) {
      final v = r[k];
      if (v == null) continue;
      if (v is List) {
        if (v.isEmpty) continue;
        buf.writeln('• $k:');
        for (final it in v) {
          final s = (it ?? '').toString().trim();
          if (s.isNotEmpty) buf.writeln('  - $s');
        }
      } else {
        final s = v.toString().trim();
        if (s.isEmpty) continue;
        buf.writeln('• $k: $s');
      }
    }
    return buf.toString().trim();
  }

  Future<void> _submit(Map<String, dynamic> result) async {
    final t = _task;
    if (t == null) return;

    final payload = {
      'task_id': t.taskId,
      'concept_id': t.conceptId,
      'related_segment_id': widget.relatedSegmentId,
      'result': result,
    };

    await _dao.addPracticeRun(taskId: t.taskId, result: payload);

    // Update concept progress: +1 completion count
    final key = 'concept:${t.conceptId}';
    final old = await _dao.getProgressStatus(key);
    await _dao.upsertProgress(key, status: old + 1, payload: {'last_task': t.taskId});

    // Auto create a learning card
    final body = _prettyResult(result);
    await _dao.addLearningCard(
      title: '【${t.conceptId}】${t.title}',
      body: body.isEmpty ? jsonEncode(result) : body,
      tags: [t.conceptId, 'failure_perfectionism'],
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存：练习记录 + 学习卡')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_err != null) {
      return Scaffold(appBar: AppBar(title: const Text('行动练习')), body: Center(child: Text(_err!)));
    }
    final t = _task;
    if (t == null) {
      return const Scaffold(body: Center(child: Text('练习不存在')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text('${t.taskId} · 概念 ${t.conceptId}', style: TextStyle(color: Colors.black.withOpacity(0.6), fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(t.description, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (t.steps.isNotEmpty) ...[
            Text('步骤', style: TextStyle(color: Colors.black.withOpacity(0.7), fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (int i = 0; i < t.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}. ', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Expanded(child: Text(t.steps[i])),
                  ],
                ),
              ),
            const SizedBox(height: 10),
          ],
          if (_recent.isNotEmpty) ...[
            Text('最近记录', style: TextStyle(color: Colors.black.withOpacity(0.7), fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final r in _recent) _RunPreview(run: r),
            const SizedBox(height: 14),
          ],
          Text('填写练习', style: TextStyle(color: Colors.black.withOpacity(0.7), fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          FpTemplateForm(
            schemaJson: _tpl?.schemaJson ?? '{"fields":[{"id":"note","label":"记录","type":"textarea"}]}',
            onSubmit: _submit,
            submitText: '保存练习',
          ),
        ],
      ),
    );
  }
}

class _RunPreview extends StatelessWidget {
  final FpPracticeRun run;
  const _RunPreview({required this.run});

  String _fmt(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      child: ListTile(
        dense: true,
        title: Text(_fmt(run.tsMs), style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(run.resultJson, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
