import 'package:flutter/material.dart';
import '../fp_dao.dart';
import '../fp_models.dart';
import 'fp_practice_runner_page.dart';

class FpPracticePage extends StatefulWidget {
  final String? openTaskId;
  final bool openQuick3P;
  const FpPracticePage({
    super.key,
    this.openTaskId,
    this.openQuick3P = false,
  });

  @override
  State<FpPracticePage> createState() => _FpPracticePageState();
}

class _FpPracticePageState extends State<FpPracticePage> {
  final _dao = FpDao();
  bool _loading = true;
  String? _err;
  List<FpTask> _tasks = const [];
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = widget.openQuick3P ? 'TASK_QUICK_3P' : widget.openTaskId;
      if (id != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FpPracticeRunnerPage(taskId: id)),
        );
      }
    });
  }

  Future<void> _load() async {
    try {
      final ts = await _dao.listTasks();
      if (!mounted) return;
      setState(() {
        _tasks = ts;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_err != null) return Center(child: Text(_err!));

    final q = _q.trim().toLowerCase();
    final xs = q.isEmpty
        ? _tasks
        : _tasks.where((t) => t.taskId.toLowerCase().contains(q) || t.title.toLowerCase().contains(q) || t.description.toLowerCase().contains(q)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '搜索行动（如 AAR / 3P / 够好 / 粗稿 / 暴露阶梯）',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
            itemCount: xs.length,
            itemBuilder: (context, i) {
              final t = xs[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.black.withOpacity(0.08)),
                ),
                child: ListTile(
                  title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${t.taskId.replaceFirst('TASK_', '')} · 难度${t.difficulty} · ${t.durationMin}分钟'),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FpPracticeRunnerPage(taskId: t.taskId)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
