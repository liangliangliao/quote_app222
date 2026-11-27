import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WakeupHistoryPage extends StatefulWidget {
  const WakeupHistoryPage({
    super.key,
    required this.channel,
    this.chooseReplayDate = false,
    this.initialDate,
  });

  final MethodChannel channel;
  final bool chooseReplayDate;
  final String? initialDate;

  @override
  State<WakeupHistoryPage> createState() => _WakeupHistoryPageState();
}

class _WakeupHistoryPageState extends State<WakeupHistoryPage> {
  List<String> _dates = [];
  String? _date;
  Future<List<Map<Object?, Object?>>>? _items;
  bool _loading = true;
  bool _syncing = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadDates(preferred: widget.initialDate);
  }

  String _dateKey(DateTime date) => date.toIso8601String().substring(0, 10);

  Future<void> _loadDates({String? preferred}) async {
    try {
      final records = await widget.channel.invokeListMethod<String>(
            'getAiWakeupHistoryDates',
          ) ??
          [];
      final dates = records
          .where((value) {
            final date = DateTime.tryParse(value);
            return date != null && _dateKey(date) == value;
          })
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = false;
        _dates = dates;
        if (dates.isEmpty) {
          _date = null;
          _items = null;
        } else {
          _select(
            dates.contains(preferred)
                ? preferred!
                : dates.contains(_date)
                    ? _date!
                    : dates.first,
          );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _syncToday() async {
    setState(() => _syncing = true);
    try {
      final result = await widget.channel.invokeMapMethod<String, dynamic>(
        'refreshAiWakeupHistory',
      );
      await _loadDates(preferred: result?['date'] as String?);
      final tasks = result?['tasks'] as int? ?? 0;
      final saved = result?['saved'] as int? ?? 0;
      final message = tasks > 0
          ? '今天已同步 $tasks 条任务'
          : saved > 0
              ? '今天的备用提醒已保存'
              : '今天暂无已同步的任务';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is PlatformException ? error.message ?? '同步未完成' : '同步未完成',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _select(String date) {
    _date = date;
    _items = widget.channel
        .invokeListMethod<Map<Object?, Object?>>('getAiWakeupHistory', {
      'date': date,
    }).then((items) => items ?? []);
  }

  Future<void> _pickDate() async {
    final current = _date;
    if (current == null) return;
    final available = _dates.toSet();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(current),
      firstDate: DateTime.parse(_dates.last),
      lastDate: DateTime.parse(_dates.first),
      currentDate: DateTime.now().toUtc().add(const Duration(hours: 8)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      selectableDayPredicate: (day) => available.contains(_dateKey(day)),
      helpText: '选取有同步记录的日期（北京时间）',
      cancelText: '取消',
      confirmText: '查看',
    );
    if (!mounted || date == null) return;
    final selected = _dateKey(date);
    if (selected != _date && _dates.contains(selected)) {
      setState(() => _select(selected));
    }
  }

  Widget _dateNavigation(String date) {
    final index = _dates.indexOf(date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: '较早的记录',
            icon: const Icon(Icons.chevron_left),
            onPressed: index + 1 < _dates.length
                ? () => setState(() => _select(_dates[index + 1]))
                : null,
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('$date（北京时间）'),
            ),
          ),
          IconButton(
            tooltip: '较新的记录',
            icon: const Icon(Icons.chevron_right),
            onPressed: index > 0
                ? () => setState(() => _select(_dates[index - 1]))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _recordCard(Map<Object?, Object?> item) {
    final title = [
      item['scheduledTime'],
      item['title'],
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
    final fetched = item['fetchedAt'];
    final timestamp = fetched is num
        ? DateTime.fromMillisecondsSinceEpoch(fetched.toInt(), isUtc: true)
            .add(const Duration(hours: 8))
            .toIso8601String()
            .replaceFirst('T', ' ')
            .substring(0, 16)
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (timestamp != null) Text('获取于 $timestamp（北京时间）'),
            const SizedBox(height: 12),
            SelectableText((item['text'] ?? '').toString()),
          ],
        ),
      ),
    );
  }

  Widget _history(String date) => Column(
        children: [
          _dateNavigation(date),
          Expanded(
            child: FutureBuilder<List<Map<Object?, Object?>>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: () => setState(() => _select(date)),
                      child: const Text('无法读取这一天的记录，点击重试'),
                    ),
                  );
                }
                final records = snapshot.data ?? [];
                final items = widget.chooseReplayDate
                    ? records
                        .where((item) => item['replayTask'] == true)
                        .toList()
                    : records;
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      widget.chooseReplayDate ? '这一天没有可播报的定时任务' : '这一天没有本机记录',
                    ),
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        key: ValueKey(date),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: items.length,
                        itemBuilder: (_, index) => _recordCard(items[index]),
                      ),
                    ),
                    if (widget.chooseReplayDate)
                      SafeArea(
                        top: false,
                        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(date),
                            child: Text('使用这一天的 ${items.length} 项任务'),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final date = _date;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chooseReplayDate ? '选择闹钟播报日期' : '本机任务同步记录'),
        actions: [
          TextButton(
            onPressed: _loading || _syncing ? null : _syncToday,
            child: Text(_syncing ? '同步中…' : '同步今天'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
              ? Center(
                  child: TextButton(
                    onPressed: _loadDates,
                    child: const Text('无法读取本机同步记录，点击重试'),
                  ),
                )
              : date == null
                  ? const Center(child: Text('本机暂无记录，可点右上角「同步今天」'))
                  : _history(date),
    );
  }
}
