import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/dao.dart';
import '../services/native_guard.dart';
import '../utils/debug_logger.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});
  @override
  State<LogsPage> createState() => _LogsPageState();
}

enum _LogFilter { all, ai, error }
enum _LogType { all, request, response, exception }

class _ParsedLog {
  final Map<String, dynamic> raw;
  final String detail;
  final String taskName;
  final String timestamp;
  final String module;
  final String provider;
  final String model;
  final String traceId;
  final String sessionId;
  final _LogType type;
  final bool isAi;
  final bool isError;

  const _ParsedLog({
    required this.raw,
    required this.detail,
    required this.taskName,
    required this.timestamp,
    required this.module,
    required this.provider,
    required this.model,
    required this.traceId,
    required this.sessionId,
    required this.type,
    required this.isAi,
    required this.isError,
  });
}

class _LogsPageState extends State<LogsPage> {
  final _dao = LogDao();
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  final List<Map<String, dynamic>> _items = [];
  int _offset = 0;
  bool _done = false;
  bool _loading = false;
  _LogFilter _filter = _LogFilter.all;
  _LogType _type = _LogType.all;
  String _moduleFilter = '全部模块';
  String _providerFilter = '全部提供商';
  String _modelFilter = '全部模型';

  @override
  void initState() {
    super.initState();
    SimpleBus.logsTick.addListener(_onBus);
    _searchCtrl.addListener(_onSearchChanged);
    _loadMore();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 160 && !_loading && !_done) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    SimpleBus.logsTick.removeListener(_onBus);
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() => _reload();

  void _reload() {
    if (!mounted) return;
    setState(() {
      _items.clear();
      _offset = 0;
      _done = false;
    });
    _loadMore();
  }

  void _onBus() => _reload();

  Future<void> _loadMore() async {
    _loading = true;
    final rows = await _dao.latest(
      limit: 50,
      offset: _offset,
      keyword: _searchCtrl.text.trim(),
      deepseekOnly: _filter == _LogFilter.ai,
      errorOnly: _filter == _LogFilter.error,
    );
    _offset += rows.length;
    _items.addAll(rows);
    _loading = false;
    if (mounted) setState(() {});
    if (rows.length < 50) _done = true;
  }

  String _fmt(String? s) {
    if (s == null || s.isEmpty) return '';
    try {
      final match = RegExp(r'\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(?::\d{2})?').firstMatch(s);
      if (match == null) return s;
      final raw = match.group(0)!.replaceFirst('T', ' ');
      final srcPattern = raw.length == 19 ? 'yyyy-MM-dd HH:mm:ss' : 'yyyy-MM-dd HH:mm';
      final dt = DateFormat(srcPattern).parseLoose(raw);
      return DateFormat('MM-dd HH:mm:ss').format(dt);
    } catch (e, _) {
      DLog.e('pages/logs_page.dart', 'catch: $e');
      return s;
    }
  }

  String _preview(String detail) {
    final oneLine = detail.replaceAll('\n', '  ').trim();
    if (oneLine.length <= 110) return oneLine;
    return '${oneLine.substring(0, 110)}...';
  }

  String _extractMeta(String detail, String key) {
    final m = RegExp('^$key:\\s*(.*)\\n?', multiLine: true).firstMatch(detail);
    return (m?.group(1) ?? '').trim();
  }

  _ParsedLog _parseLog(Map<String, dynamic> e) {
    final detail = (e['detail'] ?? '').toString();
    final taskName = (e['task_name'] ?? '').toString();
    final ts = _fmt((e['task_start_time'] ?? '') as String?);
    final titleMatch = RegExp(r'^【([^】]+?)(请求|响应|异常)】\[([^\]]+)\]').firstMatch(detail);
    final provider = titleMatch?.group(1) ??
        _extractMeta(detail, 'Provider').ifEmpty(taskName.contains('OpenRouter') ? 'OpenRouter' : taskName.contains('OpenAI') ? 'OpenAI' : taskName.contains('Eden AI') || taskName.contains('EdenAI') ? 'Eden AI' : taskName.contains('DeepSeek') ? 'DeepSeek' : '系统');
    final module = titleMatch?.group(3) ?? (taskName.isEmpty ? '系统日志' : taskName);
    final model = _extractMeta(detail, 'Model');
    final traceId = _extractMeta(detail, 'TraceId');
    final sessionId = _extractMeta(detail, 'SessionId');
    final isAi = provider == 'OpenAI' || provider == 'DeepSeek' || provider == 'OpenRouter' || provider == 'Eden AI' || provider.endsWith('-Proxy') || taskName.contains('OpenAI') || taskName.contains('DeepSeek') || taskName.contains('OpenRouter') || taskName.contains('Eden AI') || taskName.contains('EdenAI');
    final isError = detail.contains('【错误】') || detail.contains('异常') || detail.contains('Error:');

    _LogType type = _LogType.all;
    final typeLabel = titleMatch?.group(2);
    if (typeLabel == '请求') {
      type = _LogType.request;
    } else if (typeLabel == '响应') {
      type = _LogType.response;
    } else if (typeLabel == '异常') {
      type = _LogType.exception;
    }

    return _ParsedLog(
      raw: e,
      detail: detail,
      taskName: taskName,
      timestamp: ts,
      module: module,
      provider: provider,
      model: model,
      traceId: traceId,
      sessionId: sessionId,
      type: type,
      isAi: isAi,
      isError: isError,
    );
  }

  List<_ParsedLog> get _filteredLogs {
    return _items.map(_parseLog).where((e) {
      if (_type != _LogType.all && e.type != _type) return false;
      if (_moduleFilter != '全部模块' && e.module != _moduleFilter) return false;
      if (_providerFilter != '全部提供商' && e.provider != _providerFilter) return false;
      if (_modelFilter != '全部模型' && e.model != _modelFilter) return false;
      return true;
    }).toList();
  }

  List<String> get _moduleOptions {
    final set = <String>{'全部模块'};
    for (final item in _items.map(_parseLog)) {
      set.add(item.module);
    }
    return set.toList()..sort((a, b) => a.compareTo(b));
  }

  List<String> get _providerOptions {
    final set = <String>{'全部提供商'};
    for (final item in _items.map(_parseLog)) {
      if (item.provider.isNotEmpty) set.add(item.provider);
    }
    return set.toList()..sort((a, b) => a.compareTo(b));
  }

  List<String> get _modelOptions {
    final set = <String>{'全部模型'};
    for (final item in _items.map(_parseLog)) {
      if (item.model.isNotEmpty) set.add(item.model);
    }
    return set.toList()..sort((a, b) => a.compareTo(b));
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制完整日志'), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _confirmClearLogs() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空日志'),
        content: const Text('确定要删除所有日志吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('确认')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.clearAll();
      _reload();
    }
  }

  Widget _filterChip<T>(T value, T selected, String label, ValueChanged<T> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected == value,
        label: Text(label),
        onSelected: (_) => onChanged(value),
      ),
    );
  }

  Widget _buildSelector({required String label, required String value, required List<String> options, required ValueChanged<String?> onChanged}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: options.contains(value) ? value : options.first,
                items: options.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(_ParsedLog e) {
    final headColor = e.isError
        ? Colors.red.shade700
        : e.isAi
            ? (e.provider == 'OpenAI' ? Colors.teal.shade700 : e.provider == 'OpenRouter' ? Colors.deepPurple.shade700 : e.provider == 'Eden AI' ? Colors.orange.shade700 : Colors.indigo.shade700)
            : Colors.black87;
    final icon = e.isError
        ? Icons.error_outline
        : e.type == _LogType.request
            ? Icons.upload_outlined
            : e.type == _LogType.response
                ? Icons.download_done_outlined
                : e.isAi
                    ? Icons.smart_toy_outlined
                    : Icons.notes_outlined;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: CircleAvatar(
          backgroundColor: e.isError
              ? Colors.red.shade50
              : e.isAi
                  ? (e.provider == 'OpenAI' ? Colors.teal.shade50 : e.provider == 'OpenRouter' ? Colors.deepPurple.shade50 : e.provider == 'Eden AI' ? Colors.orange.shade50 : Colors.indigo.shade50)
                  : Colors.grey.shade100,
          child: Icon(icon, color: headColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                e.module,
                style: TextStyle(fontWeight: FontWeight.w700, color: headColor),
              ),
            ),
            if (e.isAi)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: e.provider == 'OpenAI' ? const Color(0xFFCCFBF1) : e.provider == 'OpenRouter' ? const Color(0xFFEDE9FE) : e.provider == 'Eden AI' ? const Color(0xFFFFEDD5) : const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  e.provider,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (e.timestamp.isNotEmpty) Text(e.timestamp, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (e.timestamp.isNotEmpty) const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: e.type == _LogType.request
                        ? const Color(0xFFE0F2FE)
                        : e.type == _LogType.response
                            ? const Color(0xFFDCFCE7)
                            : e.type == _LogType.exception
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    e.type == _LogType.request
                        ? '请求'
                        : e.type == _LogType.response
                            ? '响应'
                            : e.type == _LogType.exception
                                ? '异常'
                                : '日志',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                if (e.model.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(e.model, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ),
                ],
              ],
            ),
            if (e.traceId.isNotEmpty || e.sessionId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (e.traceId.isNotEmpty)
                    Text('Trace: ${e.traceId}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                  if (e.sessionId.isNotEmpty)
                    Text('Session: ${e.sessionId}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(_preview(e.detail), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy_all_outlined),
          onPressed: () => _copy(e.detail),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              e.detail,
              style: const TextStyle(fontFamily: 'monospace', height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final logs = _filteredLogs;
    final moduleOptions = _moduleOptions;
    final providerOptions = _providerOptions;
    final modelOptions = _modelOptions;
    if (!moduleOptions.contains(_moduleFilter)) _moduleFilter = '全部模块';
    if (!providerOptions.contains(_providerFilter)) _providerFilter = '全部提供商';
    if (!modelOptions.contains(_modelFilter)) _modelFilter = '全部模型';

    String? currentGroup;
    final displayWidgets = <Widget>[];
    for (final log in logs) {
      if (currentGroup != log.module) {
        currentGroup = log.module;
        displayWidgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Text(currentGroup!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        );
      }
      displayWidgets.add(_buildLogTile(log));
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              SizedBox(height: topInset + 236),
              Expanded(
                child: logs.isEmpty && !_loading
                    ? const Center(child: Text('暂无日志'))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: displayWidgets.length + (_loading ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= displayWidgets.length) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return displayWidgets[i];
                        },
                      ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(12, topInset + 8, 12, 10),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('日志', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(onPressed: _confirmClearLogs, icon: const Icon(Icons.delete)),
                  ],
                ),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: '搜索请求、响应、模块名或关键字',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip(_LogFilter.all, _filter, '全部', (v) { setState(() => _filter = v); _reload(); }),
                      _filterChip(_LogFilter.ai, _filter, '模型调用', (v) { setState(() => _filter = v); _reload(); }),
                      _filterChip(_LogFilter.error, _filter, '错误异常', (v) { setState(() => _filter = v); _reload(); }),
                      const SizedBox(width: 8),
                      _filterChip(_LogType.all, _type, '全部类型', (v) => setState(() => _type = v)),
                      _filterChip(_LogType.request, _type, '仅请求', (v) => setState(() => _type = v)),
                      _filterChip(_LogType.response, _type, '仅响应', (v) => setState(() => _type = v)),
                      _filterChip(_LogType.exception, _type, '仅异常', (v) => setState(() => _type = v)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildSelector(
                      label: '模块',
                      value: _moduleFilter,
                      options: moduleOptions,
                      onChanged: (v) => setState(() => _moduleFilter = v ?? '全部模块'),
                    ),
                    const SizedBox(width: 8),
                    _buildSelector(
                      label: '提供商',
                      value: _providerFilter,
                      options: providerOptions,
                      onChanged: (v) => setState(() => _providerFilter = v ?? '全部提供商'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSelector(
                      label: '模型',
                      value: _modelFilter,
                      options: modelOptions,
                      onChanged: (v) => setState(() => _modelFilter = v ?? '全部模型'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 56,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('当前结果：${logs.length} 条', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
