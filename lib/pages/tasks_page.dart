import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/dao.dart';
import '../services/native_guard.dart';
import '../services/quote_ai_service.dart';
import '../widgets/task_schedule_status.dart';
import '../widgets/journey_design.dart';

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
  final _taskHeadingKey = GlobalKey();

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
    final inset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: journeyPaper,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: inset + 205,
            child: const JourneyHeaderBackdrop(),
          ),
          RefreshIndicator(
            color: journeyGreen,
            onRefresh: _refresh,
            child: ListView(
              key: const PageStorageKey('tasks-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, inset + 12, 20, 24),
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
                              color: Color(0xff72867c),
                              fontSize: 9,
                              height: 1.3,
                              letterSpacing: 2.5,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            '让好思想，\n成为日常。',
                            style: TextStyle(
                              fontFamily: 'QuoteKaiShu',
                              color: journeyInk,
                              fontSize: 28,
                              height: 1.12,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '为重要的事留一点时间',
                            style: TextStyle(
                              color: Color(0xff7e8b82),
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FilledButton.icon(
                          key: const ValueKey('task-create'),
                          onPressed: () => _edit(),
                          style: FilledButton.styleFrom(
                            backgroundColor: journeyInk,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text(
                            '新建',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 27),
                        const Padding(
                          padding: EdgeInsets.only(right: 3),
                          child: Text(
                            '更好的自己\n从每一个\n微小的坚持开始。',
                            style: TextStyle(
                              fontFamily: 'QuoteKaiShu',
                              color: Color(0xff859181),
                              fontSize: 9,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                JourneySurface(
                  color: const Color(0xdfe7eee6),
                  onTap: () {
                    setState(() => _filter = '全部');
                    final headingContext = _taskHeadingKey.currentContext;
                    if (headingContext != null)
                      Scrollable.ensureVisible(
                        headingContext,
                        duration: const Duration(milliseconds: 250),
                      );
                  },
                  child: Stack(
                    children: [
                      const Positioned(
                        right: 25,
                        bottom: -21,
                        width: 115,
                        height: 95,
                        child: JourneyIllustration(
                          JourneyArt.sprout,
                          opacity: .12,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.spa_outlined,
                              size: 29,
                              color: journeyGreen,
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _loading ? '正在读取你的任务' : '$active 个任务正在陪伴你',
                                    style: const TextStyle(
                                      color: journeyInk,
                                      fontSize: 14,
                                      height: 1.25,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '持续行动，遇见更好的自己。',
                                    style: TextStyle(
                                      color: Color(0xff8a968b),
                                      fontSize: 10.5,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '共 ${_tasks.length} 个',
                              style: const TextStyle(
                                color: Color(0xff748279),
                                fontSize: 10.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Color(0xff627467),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '我的任务',
                  key: _taskHeadingKey,
                  style: const TextStyle(
                    color: journeyInk,
                    fontFamily: 'QuoteKaiShu',
                    fontSize: 20,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in const ['全部', '进行中', '已暂停'])
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: JourneyFilterChip(
                            key: ValueKey('task-filter-$filter'),
                            label: filter,
                            compact: true,
                            selected: _filter == filter,
                            onTap: () => setState(() => _filter = filter),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: journeyGreen,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else if (visible.isEmpty)
                  JourneySurface(
                    onTap: () => _edit(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 32,
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.edit_calendar_outlined,
                            size: 31,
                            color: Color(0xff91a596),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _tasks.isEmpty ? '从一条想珍藏的名言开始' : '这里暂时没有任务',
                            style: const TextStyle(
                              color: journeyInk,
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
                    ),
                  )
                else
                  for (final task in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _taskCard(task),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> task) {
    final type = (task['type'] ?? '').toString();
    final goal = type == 'xiangji_goal' || type == 'vision_focus';
    final auto = type == 'auto';
    final active = _isActive(task);
    return JourneySurface(
      key: ValueKey('task-card-${task['task_uid']}'),
      onTap: () => _edit(task),
      child: Stack(
        children: [
          Positioned(
            right: -4,
            bottom: -6,
            width: 144,
            height: 125,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.transparent, Color(0xffeeeeee)],
                stops: [0, 1],
              ).createShader(bounds),
              child: JourneyIllustration(
                goal
                    ? JourneyArt.stones
                    : auto
                    ? JourneyArt.book
                    : JourneyArt.mountains,
                opacity: .6,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    JourneyIcon(
                      goal
                          ? Icons.track_changes_rounded
                          : auto
                          ? Icons.eco_outlined
                          : Icons.format_quote_rounded,
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (task['name'] ?? '').toString(),
                            style: const TextStyle(
                              color: Color(0xff172d24),
                              fontSize: 14.5,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 9,
                            runSpacing: 3,
                            children: [
                              Text(
                                _typeLabel(task),
                                style: const TextStyle(
                                  color: Color(0xff8c938e),
                                  fontSize: 10.5,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: active
                                          ? const Color(0xff6b996c)
                                          : const Color(0xffb3afa1),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    active ? '进行中' : '已暂停',
                                    style: const TextStyle(
                                      color: Color(0xff8c938e),
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xff466251),
                      size: 20,
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Divider(height: 1, color: Color(0xffeef0e9)),
                ),
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.3,
                    color: Color(0xff7c8778),
                  ),
                  child: RepaintBoundary(
                    child: TaskScheduleStatusView(
                      key: ValueKey('task-schedule-${task['task_uid']}'),
                      task: task,
                      activeColor: journeyGreen,
                      live: widget.active,
                      showIcons: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
