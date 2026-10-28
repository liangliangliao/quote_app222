import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/dao.dart';
import '../services/native_guard.dart';
import '../services/quote_ai_service.dart';
import '../widgets/task_schedule_status.dart';

/// The task list keeps the existing editor and scheduling implementation in
/// SettingsPage; this page only presents and selects those same records.
class TasksPage extends StatefulWidget {
  const TasksPage({
    super.key,
    required this.openEditor,
    this.loadTasks,
    this.active = true,
  });

  final Future<void> Function(Map<String, dynamic>? task) openEditor;
  final Future<List<Map<String, dynamic>>> Function()? loadTasks;
  final bool active;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with WidgetsBindingObserver {
  final _dao = TaskDao();
  List<Map<String, dynamic>> _tasks = [];
  Timer? _timer;
  bool _loading = true;
  bool _refreshing = false;
  bool _refreshAgain = false;
  String _filter = '全部';

  bool _isActive(Map<String, dynamic> task) =>
      (task['status'] ?? 'on').toString() == 'on' &&
      ((task['type'] ?? '').toString() != 'auto' ||
          QuoteAiTaskConfig.fromTask(task).autoEnabled);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SimpleBus.navIndex.addListener(_onNavigation);
    SimpleBus.settingsTick.addListener(_onSettingsChange);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (SimpleBus.navIndex.value == 3 &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed)) {
        _refresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && SimpleBus.navIndex.value == 3) {
      _refresh();
    }
  }

  void _onNavigation() {
    if (SimpleBus.navIndex.value == 3) _refresh();
  }

  void _onSettingsChange() => _refresh();

  Future<void> _refresh() async {
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      final rows = await (widget.loadTasks?.call() ?? _dao.all());
      if (!mounted) return;
      if (_loading || jsonEncode(rows) != jsonEncode(_tasks)) {
        setState(() {
          _tasks = rows;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && _loading) setState(() => _loading = false);
    } finally {
      _refreshing = false;
      if (_refreshAgain && mounted) {
        _refreshAgain = false;
        unawaited(_refresh());
      }
    }
  }

  Future<void> _edit([Map<String, dynamic>? task]) async {
    await widget.openEditor(task);
    await _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    SimpleBus.navIndex.removeListener(_onNavigation);
    SimpleBus.settingsTick.removeListener(_onSettingsChange);
    super.dispose();
  }

  String _typeLabel(Map<String, dynamic> task) {
    switch ((task['type'] ?? '').toString()) {
      case 'manual':
        return '手动名言';
      case 'auto':
        return 'AI 名言';
      case 'carousel':
        return '名言轮播';
      case '批量导入任务':
        return '批量导入';
      case 'vision_focus':
        return '愿景专注';
      case 'xiangji_goal':
        return '向己目标';
      default:
        return (task['type'] ?? '任务').toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _tasks.where(_isActive).length;
    final visible = _tasks
        .where(
          (task) =>
              _filter == '全部' ||
              (_filter == '进行中' ? _isActive(task) : !_isActive(task)),
        )
        .toList();
    const ink = Color(0xff263d35);
    return Scaffold(
      backgroundColor: const Color(0xfff7f6f1),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: const PageStorageKey('tasks-list'),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR RHYTHM',
                          style: TextStyle(
                            color: Color(0xff788b7d),
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '让好思想，\n成为日常。',
                          style: TextStyle(
                            color: ink,
                            fontSize: 28,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '为重要的事留一点时间',
                          style: TextStyle(
                            color: Color(0xff738078),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('task-create'),
                    onPressed: () => _edit(),
                    style: FilledButton.styleFrom(
                      backgroundColor: ink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 19),
                    label: const Text('新建'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xffe7eee6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.spa_outlined, color: Color(0xff50705b)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$active 个任务正在陪伴你',
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '共 ${_tasks.length} 个',
                      style: const TextStyle(
                        color: Color(0xff667b6c),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '我的任务',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final filter in const ['全部', '进行中', '已暂停'])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          selectedColor: const Color(0xffdce8dd),
                          labelStyle: const TextStyle(fontSize: 12),
                          side: BorderSide.none,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (visible.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 34,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.edit_calendar_outlined,
                        size: 34,
                        color: Color(0xff91a596),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _tasks.isEmpty ? '从一条想珍藏的名言开始' : '这里暂时没有任务',
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_tasks.isEmpty)
                        TextButton(
                          onPressed: () => _edit(),
                          child: const Text('创建第一个任务'),
                        ),
                    ],
                  ),
                )
              else
                for (final task in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        key: ValueKey('task-card-${task['task_uid']}'),
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _edit(task),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xffedf2eb),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.format_quote_rounded,
                                      color: Color(0xff57745f),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (task['name'] ?? '').toString(),
                                          style: const TextStyle(
                                            color: ink,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${_typeLabel(task)}  ·  ${_isActive(task) ? '进行中' : '已暂停'}',
                                          style: const TextStyle(
                                            color: Color(0xff87948a),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xff91a096),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(
                                  height: 1,
                                  color: Color(0xffedf0eb),
                                ),
                              ),
                              DefaultTextStyle.merge(
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Color(0xff68776d),
                                ),
                                child: TaskScheduleStatusView(
                                  key: ValueKey(
                                    'task-schedule-${task['task_uid']}',
                                  ),
                                  task: task,
                                  activeColor: const Color(0xff52745d),
                                  live: widget.active,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
