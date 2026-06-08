import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'behavior_observation_presets.dart';
import 'behavior_tracking_dao.dart';
import 'behavior_tracking_external_sources.dart';
import 'behavior_tracking_models.dart';


/// V21：通知点击去重与直达轻量表单。
///
/// 由于原生侧会同时通过通用通知通道和行为观察专用通道下发点击事件，
/// 某些机型/冷启动场景可能导致同一条通知触发 2-3 次页面弹出。
/// 这里用 payload 指纹做短时间去重，确保用户点击一次只打开一个表单。
class BehaviorObservationNotificationOpenGuard {
  static String? _lastFingerprint;
  static int _lastAtMs = 0;

  static bool shouldOpen(Map<String, dynamic>? payload) {
    if (payload == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    final fingerprint = [
      payload['type']?.toString() ?? '',
      payload['templateKey']?.toString() ?? '',
      payload['entryMode']?.toString() ?? '',
      payload['primaryLayer']?.toString() ?? '',
      payload['title']?.toString() ?? '',
    ].join('|');
    if (_lastFingerprint == fingerprint && now - _lastAtMs < 2500) {
      return false;
    }
    _lastFingerprint = fingerprint;
    _lastAtMs = now;
    return true;
  }
}

/// 通知入口专用轻量页。
///
/// 点击通知栏“选择层面填写”后直接进入这个页面：
/// 1）不先进入行为观察首页；
/// 2）页面内先显示观察层面下拉框；
/// 3）选择层面后只显示该层对应字段表单。
class BehaviorObservationNotificationFormPage extends StatefulWidget {
  final String? initialPrimaryLayer;
  final String? initialTemplateKey;

  const BehaviorObservationNotificationFormPage({
    super.key,
    this.initialPrimaryLayer,
    this.initialTemplateKey,
  });

  @override
  State<BehaviorObservationNotificationFormPage> createState() => _BehaviorObservationNotificationFormPageState();
}

class _BehaviorObservationNotificationFormPageState extends State<BehaviorObservationNotificationFormPage> {
  final BehaviorTrackingDao _dao = BehaviorTrackingDao();
  late Future<List<String>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _dao.categories();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final categories = snapshot.data == null || snapshot.data!.isEmpty ? behaviorCategories : snapshot.data!;
        final layerInfo = _behaviorLayerByNameOrMode(widget.initialPrimaryLayer) ??
            _behaviorLayerByNameOrMode(widget.initialTemplateKey) ??
            behaviorLayerInfos.first;
        final initial = BehaviorTrackingRecord.blank(
          mode: layerInfo.mode,
          templateKey: layerInfo.mode,
          entryMode: 'notification_layer_selector',
          primaryLayer: layerInfo.name,
        ).copyWith(
          title: '通知记录 · ${layerInfo.name.replaceAll('层面', '')}',
          category: categories.contains('其他') ? '其他' : categories.first,
          tags: ['行为观察', '通知提醒', layerInfo.name],
        );
        return _BehaviorRecordEditor(initial: initial, categories: categories);
      },
    );
  }
}

/// V11 纯行为观察简化版：
/// 只保留“观察与记录”闭环，突出行为事实、情境和结果。
class BehaviorTrackingHomePage extends StatefulWidget {
  final int initialTabIndex;
  final String? initialTemplateKey;
  final String? initialPrimaryLayer;
  final bool autoOpenInitialTemplate;

  const BehaviorTrackingHomePage({
    super.key,
    this.initialTabIndex = 0,
    this.initialTemplateKey,
    this.initialPrimaryLayer,
    this.autoOpenInitialTemplate = false,
  });

  @override
  State<BehaviorTrackingHomePage> createState() => _BehaviorTrackingHomePageState();
}

class _BehaviorTrackingHomePageState extends State<BehaviorTrackingHomePage> {
  final BehaviorTrackingDao _dao = BehaviorTrackingDao();
  final BehaviorTrackingExternalDao _externalDao = BehaviorTrackingExternalDao();
  List<BehaviorTrackingRecord> _records = const [];
  List<String> _categories = behaviorCategories;
  int _pendingImportCount = 0;
  bool _loading = true;
  bool _initialOpened = false;

  @override
  void initState() {
    super.initState();
    BehaviorTrackingNativeBridge.installNotificationTapHandler(_handleBehaviorNotificationPayload);
    _load();
    // 如果本页本身就是由通知 payload 创建的，_openInitialTemplateIfNeeded 会处理；
    // 不再额外 consumeLastNotificationPayload，避免同一通知重复弹出编辑页。
    if (!widget.autoOpenInitialTemplate) {
      _consumeInitialBehaviorNotificationPayload();
    }
  }

  Future<void> _consumeInitialBehaviorNotificationPayload() async {
    final envelope = await BehaviorTrackingNativeBridge.consumeLastNotificationPayload();
    final payload = BehaviorTrackingNativeBridge.decodePayloadEnvelope(envelope);
    if (payload != null) await _handleBehaviorNotificationPayload(payload);
  }

  Future<void> _handleBehaviorNotificationPayload(Map<String, dynamic> payload) async {
    if (payload['module']?.toString() != 'behavior_tracking') return;
    if (!BehaviorObservationNotificationOpenGuard.shouldOpen(payload)) return;
    final key = payload['templateKey']?.toString().trim();
    final type = payload['type']?.toString().trim();
    final layer = payload['primaryLayer']?.toString().trim();
    if ((key == null || key.isEmpty) && (type == null || type.isEmpty)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (key == 'data_sources' || key == 'import_queue') {
        DefaultTabController.of(context).animateTo(5);
        return;
      }
      if (key == 'preset_daily_review' || type == 'behavior_preset_daily_review') {
        _openDailyPresetReview();
        return;
      }
      final safeLayer = (layer == null || layer.isEmpty) ? null : layer;
      if (key == 'notification_layer_select' || key == 'layer_selector') {
        _openNotificationLayerSelector(layer: safeLayer);
        return;
      }
      if (key == 'daily_six' || key == 'daily_summary') {
        _openDailySummary();
        return;
      }
      final safeTemplateKey = key;
      if (safeTemplateKey == null || safeTemplateKey.isEmpty) return;
      _openEditor(template: _templateByKey(safeTemplateKey), layer: safeLayer);
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final records = await _dao.recent(limit: 5000);
      final categories = await _dao.categories();
      final pending = await _externalDao.pendingCount();
      if (!mounted) return;
      setState(() {
        _records = records;
        _categories = categories.isEmpty ? behaviorCategories : categories;
        _pendingImportCount = pending;
        _loading = false;
      });
      _openInitialTemplateIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载行为记录失败：$e')));
    }
  }

  void _openInitialTemplateIfNeeded() {
    if (_initialOpened || !widget.autoOpenInitialTemplate) return;
    _initialOpened = true;
    final key = (widget.initialTemplateKey ?? 'quick_capture').trim();
    final payload = <String, dynamic>{
      'module': 'behavior_tracking',
      if (key == 'preset_daily_review') 'type': 'behavior_preset_daily_review',
      'templateKey': key,
      'entryMode': key == 'preset_daily_review' ? 'preset_daily_review' : 'notification_layer_selector',
      if (widget.initialPrimaryLayer != null) 'primaryLayer': widget.initialPrimaryLayer,
    };
    if (!BehaviorObservationNotificationOpenGuard.shouldOpen(payload)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final safeKey = key.isEmpty ? 'quick_capture' : key;
      if (safeKey == 'preset_daily_review') {
        _openDailyPresetReview();
      } else if (safeKey == 'notification_layer_select' || safeKey == 'layer_selector') {
        _openNotificationLayerSelector(layer: widget.initialPrimaryLayer);
      } else if (safeKey == 'daily_six' || safeKey == 'daily_summary') {
        _openDailySummary();
      } else {
        _openEditor(template: _templateByKey(safeKey), layer: widget.initialPrimaryLayer);
      }
    });
  }

  List<BehaviorTrackingRecord> get _todayRecords {
    final now = DateTime.now();
    return _records.where((r) {
      final d = r.recordDate;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();
  }

  int get _todayMinutes => _todayRecords.fold<int>(0, (sum, r) => sum + (r.durationMinutes ?? 0));

  BehaviorTemplateInfo _templateByKey(String key) => _template(key);


  Future<String?> _promptCustomCategory(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增自定义类别'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '类别名称', hintText: '例如：写作、通勤、家务、短视频'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    controller.dispose();
    final clean = name?.trim();
    if (clean == null || clean.isEmpty) return null;
    await _dao.saveCategory(clean);
    if (mounted) {
      setState(() {
        if (!_categories.contains(clean)) _categories = [..._categories, clean];
      });
    }
    return clean;
  }

  Future<void> _quickCapture() async {
    final behavior = TextEditingController();
    final minutes = TextEditingController(text: '25');
    final note = TextEditingController();
    String category = '工作/学习';
    String emotion = '';

    final saved = await showModalBottomSheet<BehaviorTrackingRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Expanded(child: Text('秒记行为', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900))),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ]),
              const Text('只记录事实：我做了什么、多久、属于哪类。其余层面以后再补。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
              const SizedBox(height: 14),
              _Field(controller: behavior, label: '我刚刚做了什么', hint: '例如：刷短视频 / 复习英语 / 做饭 / 午休', maxLines: 2),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _Field(controller: minutes, label: '大概时长（分钟）', hint: '25', keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _Choice(label: '类别（必选）', value: category, options: _categories, onChanged: (v) => setSheetState(() => category = v))),
              ]),
              Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () async { final added = await _promptCustomCategory(ctx); if (added != null) setSheetState(() => category = added); }, icon: const Icon(Icons.add), label: const Text('新增类别'))),
              const SizedBox(height: 10),
              _Choice(label: '当时情绪（可选）', value: emotion, emptyLabel: '先不填', options: behaviorEmotions, onChanged: (v) => setSheetState(() => emotion = v)),
              const SizedBox(height: 10),
              _Field(controller: note, label: '备注（可选）', hint: '例如：在床上刷；通勤时看书', maxLines: 2),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存'),
                  onPressed: () async {
                    if (category.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('请选择或新增一个类别')));
                      return;
                    }
                    final now = TimeOfDay.now();
                    final end = now.hour * 60 + now.minute;
                    final duration = int.tryParse(minutes.text.trim()) ?? 0;
                    final start = duration > 0 ? (end - duration + 24 * 60) % (24 * 60) : null;
                    final r = BehaviorTrackingRecord.blank(
                      mode: 'quick_capture',
                      templateKey: 'quick_capture',
                      entryMode: 'quick_capture',
                      primaryLayer: '行为层面',
                    ).copyWith(
                      title: behavior.text.trim().ifBlank('快捷行为记录'),
                      category: category,
                      behavior: behavior.text.trim(),
                      startMinute: start,
                      endMinute: duration > 0 ? end : null,
                      clearStartMinute: start == null,
                      clearEndMinute: duration <= 0,
                      emotion: emotion,
                      notes: note.text.trim(),
                      tags: [category, if (emotion.isNotEmpty) emotion],
                    );
                    await _dao.save(r);
                    if (ctx.mounted) Navigator.pop(ctx, r);
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );

    behavior.dispose();
    minutes.dispose();
    note.dispose();
    if (saved != null) {
      await _load();
      if (!mounted) return;
      _showAfterSave(saved);
    }
  }

  Future<void> _openNotificationLayerSelector({String? layer}) async {
    final info = _behaviorLayerByNameOrMode(layer) ?? behaviorLayerInfos.first;
    final initial = BehaviorTrackingRecord.blank(
      mode: info.mode,
      templateKey: info.mode,
      entryMode: 'notification_layer_selector',
      primaryLayer: info.name,
    ).copyWith(
      title: '通知记录 · ${info.name.replaceAll('层面', '')}',
      category: '未分类',
      tags: ['行为观察', '通知提醒', info.name],
    );
    final saved = await Navigator.of(context).push<BehaviorTrackingRecord?>(
      MaterialPageRoute(builder: (_) => _BehaviorRecordEditor(initial: initial, categories: _categories)),
    );
    if (saved != null) {
      await _load();
      if (!mounted) return;
      _showAfterSave(saved);
    }
  }

  Future<void> _openDailySummary({DateTime? date}) async {
    final saved = await Navigator.of(context).push<BehaviorTrackingRecord?>(
      MaterialPageRoute(
        builder: (_) => _DailySummaryAutoPage(
          records: _records,
          initialDate: date ?? DateTime.now(),
          onSaveSnapshot: (record) async => _dao.save(record),
        ),
      ),
    );
    if (saved != null) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存今日摘要快照')));
    }
  }


  Future<void> _openDailyPresetReview() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BehaviorPresetDailyReviewPage(categories: _categories, initialDate: DateTime.now())),
    );
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _openEditor({BehaviorTrackingRecord? record, BehaviorTemplateInfo? template, String? layer}) async {
    final info = template ?? _templateByKey(record?.templateKey ?? 'full_observation');
    if (record == null && (info.key == 'daily_six' || info.key == 'daily_summary')) {
      await _openDailySummary();
      return;
    }
    final initial = record ?? BehaviorTrackingRecord.blank(
      mode: info.key,
      templateKey: info.key,
      entryMode: info.entryMode,
      primaryLayer: layer ?? info.primaryLayer,
    );
    final saved = await Navigator.of(context).push<BehaviorTrackingRecord?>(
      MaterialPageRoute(builder: (_) => _BehaviorRecordEditor(initial: initial, categories: _categories)),
    );
    if (saved != null) {
      await _load();
      if (!mounted) return;
      _showAfterSave(saved);
    }
  }

  Future<void> _deleteRecord(BehaviorTrackingRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: Text(record.title.ifBlank(record.oneLineSummary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true && record.id != null) {
      await _dao.delete(record.id!);
      await _load();
    }
  }

  Future<void> _clearAllRecords() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('当前没有可清空的记录')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空全部记录？'),
        content: Text('将删除当前模块中的全部 ${_records.length} 条行为观察记录。\n\n不会删除类别、提醒配置、数据源授权/同步配置。此操作无法撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final deleted = await _dao.deleteAllRecords();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已清空 $deleted 条行为观察记录')));
    }
  }

  void _showAfterSave(BehaviorTrackingRecord r) {
    final missing = _missingLayers(r);
    final next = missing.isEmpty ? '这条记录已经比较完整。你可以回到首页继续观察今天。' : '还可以补充：${missing.take(3).join('、')}。不是必须，现在有空再补。';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('已保存行为记录', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(next, style: const TextStyle(color: Color(0xFF64748B), height: 1.45)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.tonalIcon(onPressed: () { Navigator.pop(ctx); _openEditor(record: r); }, icon: const Icon(Icons.edit_note_outlined), label: const Text('继续补充')),
            FilledButton.icon(onPressed: () { Navigator.pop(ctx); }, icon: const Icon(Icons.check), label: const Text('先这样')),
          ]),
        ]),
      ),
    );
  }

  List<String> _missingLayers(BehaviorTrackingRecord r) {
    final missing = <String>[];
    if (r.timeRangeLabel.isEmpty) missing.add('时间');
    if (r.behavior.trim().isEmpty) missing.add('行为');
    if (r.emotion.trim().isEmpty) missing.add('情绪');
    if (r.automaticThought.trim().isEmpty && r.cognition.trim().isEmpty) missing.add('认知');
    if (r.shortTermResult.trim().isEmpty && r.longTermImpact.trim().isEmpty) missing.add('结果');
    if (r.environment.trim().isEmpty && r.locationType.trim().isEmpty) missing.add('环境');
    if (r.bodyState.trim().isEmpty && r.sleep.trim().isEmpty) missing.add('身体');
    return missing;
  }

  Future<void> _export(String type) async {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    late String content;
    late String ext;
    if (type == 'json') {
      content = await _dao.exportJson();
      ext = 'json';
    } else if (type == 'csv') {
      content = await _dao.exportCsv();
      ext = 'csv';
    } else {
      content = await _dao.exportMarkdown();
      ext = 'md';
    }
    final file = File('${dir.path}/behavior_tracking_$stamp.$ext');
    await file.writeAsString(content);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导出到：${file.path}')));
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialTabIndex.clamp(0, 5).toInt();
    return DefaultTabController(
      length: 6,
      initialIndex: initial,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('行为观察', style: TextStyle(fontWeight: FontWeight.w900)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          actions: [
            PopupMenuButton<String>(
              onSelected: _export,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'markdown', child: Text('导出 Markdown')),
                PopupMenuItem(value: 'csv', child: Text('导出 CSV')),
                PopupMenuItem(value: 'json', child: Text('导出 JSON')),
              ],
            ),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: '刷新'),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.home_outlined), text: '首页'),
              Tab(icon: Icon(Icons.event_available_outlined), text: '预设'),
              Tab(icon: Icon(Icons.layers_outlined), text: '七层'),
              Tab(icon: Icon(Icons.list_alt_outlined), text: '记录'),
              Tab(icon: Icon(Icons.insights_outlined), text: '复盘'),
              Tab(icon: Icon(Icons.sensors_outlined), text: '数据源'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _quickCapture,
          icon: const Icon(Icons.flash_on_outlined),
          label: const Text('秒记'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: TabBarView(children: [
                  _TodayPage(
                    records: _records,
                    todayRecords: _todayRecords,
                    todayMinutes: _todayMinutes,
                    onQuick: _quickCapture,
                    onTemplate: (t) => _openEditor(template: t),
                    onDailySummary: _openDailySummary,
                    onPresets: () => DefaultTabController.of(context).animateTo(1),
                    onEdit: (r) => _openEditor(record: r),
                  ),
                  BehaviorObservationPresetsPage(categories: _categories, onRecordsChanged: () { _load(); }),
                  _LayersPage(onLayer: (layer) => _openEditor(template: _templateByKey(layer.mode), layer: layer.name)),
                  _RecordsPage(records: _records, categories: _categories, onEdit: (r) => _openEditor(record: r), onDelete: _deleteRecord, onClearAll: _clearAllRecords, onQuick: _quickCapture),
                  _StatsPage(records: _records, pendingImportCount: _pendingImportCount, onOpenPending: () => DefaultTabController.of(context).animateTo(4), onExport: _export),
                  BehaviorTrackingDataSourcesPage(onRecordsChanged: _load),
                ]),
              ),
      ),
    );
  }
}

class _TodayPage extends StatelessWidget {
  final List<BehaviorTrackingRecord> records;
  final List<BehaviorTrackingRecord> todayRecords;
  final int todayMinutes;
  final VoidCallback onQuick;
  final ValueChanged<BehaviorTemplateInfo> onTemplate;
  final VoidCallback onDailySummary;
  final VoidCallback onPresets;
  final ValueChanged<BehaviorTrackingRecord> onEdit;

  const _TodayPage({required this.records, required this.todayRecords, required this.todayMinutes, required this.onQuick, required this.onTemplate, required this.onDailySummary, required this.onPresets, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final h = todayMinutes ~/ 60;
    final m = todayMinutes % 60;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 96), children: [
      _HeroCard(
        todayCount: todayRecords.length,
        todayTime: todayMinutes == 0 ? '未标记' : '${h}h ${m}m',
        onQuick: onQuick,
        onTime: () => onTemplate(_template('time_block')),
        onDaily: onDailySummary,
      ),
      const SizedBox(height: 12),
      _GuideCard(records: records, today: todayRecords, onQuick: onQuick, onTemplate: onTemplate, onDailySummary: onDailySummary),
      const SizedBox(height: 12),
      _SectionTitle('最常用记录方式', trailing: '只做观察'),
      const SizedBox(height: 8),
      _QuickGrid(items: [
        _QuickAction('秒记', '5–15秒留下行为事实', Icons.flash_on_outlined, onQuick),
        _QuickAction('时间块', '我把时间花在哪里', Icons.schedule_outlined, () => onTemplate(_template('time_block'))),
        _QuickAction('触发-行为-结果', '看清一次行为链条', Icons.account_tree_outlined, () => onTemplate(_template('tbr'))),
        _QuickAction('每日摘要', '自动汇总今天记录', Icons.today_outlined, onDailySummary),
        _QuickAction('预设行为', '每日确认固定行为', Icons.event_available_outlined, onPresets),
        _QuickAction('情绪想法', '情绪强时抓一句想法', Icons.psychology_alt_outlined, () => onTemplate(_template('emotion_thought'))),
        _QuickAction('身体快照', '睡眠精力运动一次记', Icons.bedtime_outlined, () => onTemplate(_template('body_snapshot'))),
      ]),
      const SizedBox(height: 12),
      _InfoCard(title: '模块定位', icon: Icons.visibility_outlined, children: const [
        _Line('这个模块只做一件事：记录“我做了什么、在什么情况下做、产生什么结果”。'),
        _Line('不评价你，不急着下结论。先积累真实证据，再看见自己的行为模式。'),
      ]),
      const SizedBox(height: 12),
      _SectionTitle('今天的记录', trailing: todayRecords.isEmpty ? '暂无' : '${todayRecords.length}条'),
      const SizedBox(height: 8),
      if (todayRecords.isEmpty)
        _EmptyCard(text: '今天还没有记录。点右下角“秒记”，只写一句“我刚刚做了什么”。')
      else
        for (final r in todayRecords.take(6)) _RecordTile(record: r, onTap: () => onEdit(r)),
    ]);
  }
}

class _DailySummaryAutoPage extends StatefulWidget {
  final List<BehaviorTrackingRecord> records;
  final DateTime initialDate;
  final Future<int> Function(BehaviorTrackingRecord record) onSaveSnapshot;

  const _DailySummaryAutoPage({required this.records, required this.initialDate, required this.onSaveSnapshot});

  @override
  State<_DailySummaryAutoPage> createState() => _DailySummaryAutoPageState();
}

class _DailySummaryAutoPageState extends State<_DailySummaryAutoPage> {
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
  }

  List<BehaviorTrackingRecord> get _dayRecords {
    return widget.records.where((r) {
      final d = DateTime(r.recordDate.year, r.recordDate.month, r.recordDate.day);
      final isSameDay = d.year == _date.year && d.month == _date.month && d.day == _date.day;
      final isSummarySnapshot = r.templateKey == 'daily_six' || r.mode == 'daily_summary' || r.entryMode == 'auto_daily_summary';
      return isSameDay && !isSummarySnapshot;
    }).toList()
      ..sort((a, b) {
        final sa = a.startMinute ?? 24 * 60 + 1;
        final sb = b.startMinute ?? 24 * 60 + 1;
        final byTime = sa.compareTo(sb);
        if (byTime != 0) return byTime;
        return (a.createdAtMs).compareTo(b.createdAtMs);
      });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (picked == null) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _saveSnapshot(_AutoDailySummary summary) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final snapshot = BehaviorTrackingRecord.blank(
        mode: 'daily_summary',
        templateKey: 'daily_six',
        entryMode: 'auto_daily_summary',
        primaryLayer: '每日摘要',
      ).copyWith(
        recordDateMs: _date.millisecondsSinceEpoch,
        title: '每日摘要 · ${DateFormat('yyyy-MM-dd').format(_date)}',
        category: '其他',
        source: 'auto_daily_summary',
        behavior: summary.importantBehaviors.join('；'),
        importantBehaviors: summary.importantBehaviors.join('\n'),
        timeWaste: summary.timeFlowLines.join('\n'),
        mood: summary.emotionLines.join('；'),
        trigger: summary.triggerLines.join('；'),
        notes: summary.summaryText,
        tags: const ['行为观察', '每日摘要', '自动汇总'],
        templateAnswersJson: jsonEncode(summary.toJson()),
      );
      await widget.onSaveSnapshot(snapshot);
      if (!mounted) return;
      Navigator.pop(context, snapshot);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _dayRecords;
    final summary = _AutoDailySummary.fromRecords(_date, records);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('每日摘要', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        actions: [IconButton(onPressed: _pickDate, icon: const Icon(Icons.calendar_month_outlined), tooltip: '选择日期')],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 96), children: [
        _InfoCard(title: '${DateFormat('yyyy-MM-dd').format(_date)} · 自动汇总', icon: Icons.summarize_outlined, children: [
          Text('每日摘要不是让用户再新增一条手写记录，而是自动汇总当天已有行为观察。当前汇总来自 ${records.length} 条当天记录；可切换日期查看。', style: const TextStyle(color: Color(0xFF64748B), height: 1.45)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _TimeMetricTile(label: '当天记录', value: '${records.length}条', helper: records.isEmpty ? '先记录行为事实' : '已参与摘要')),
            const SizedBox(width: 10),
            Expanded(child: _TimeMetricTile(label: '有时长合计', value: summary.totalMinutes > 0 ? _formatDuration(summary.totalMinutes) : '暂无', helper: summary.missingDurationCount > 0 ? '${summary.missingDurationCount} 条无时长' : '时间信息完整')),
          ]),
        ]),
        const SizedBox(height: 12),
        if (records.isEmpty) ...[
          const _EmptyCard(text: '当天还没有行为记录，因此没有可自动汇总的内容。先用“秒记”“时间块”或数据源导入记录当天行为。'),
        ] else ...[
          _InfoCard(title: '时间流向', icon: Icons.access_time_outlined, children: [
            if (summary.timeFlowLines.isEmpty) ...[
              const _Line('当天暂无可计算时长。'),
              const _Line('仍可参考下方“类别比重”和“具体行为”，但真正的时间占比需要时间块、屏幕使用、日历或番茄钟数据。'),
            ] else
              for (final line in summary.timeFlowLines) _Line(line),
          ]),
          const SizedBox(height: 12),
          _InfoCard(title: '行为类别比重', icon: Icons.donut_large_outlined, children: [
            for (final line in summary.categoryLines) _Line(line),
          ]),
          const SizedBox(height: 12),
          _InfoCard(title: '具体做了什么', icon: Icons.format_list_bulleted_outlined, children: [
            for (final line in summary.importantBehaviors) _Line(line),
          ]),
          const SizedBox(height: 12),
          _InfoCard(title: '情绪 / 触发 / 环境 / 身体线索', icon: Icons.hub_outlined, children: [
            if (summary.emotionLines.isNotEmpty) ...[
              const Text('情绪', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              for (final line in summary.emotionLines) _Line(line),
              const SizedBox(height: 8),
            ],
            if (summary.triggerLines.isNotEmpty) ...[
              const Text('触发/情境', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              for (final line in summary.triggerLines) _Line(line),
              const SizedBox(height: 8),
            ],
            if (summary.environmentLines.isNotEmpty) ...[
              const Text('环境', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              for (final line in summary.environmentLines) _Line(line),
              const SizedBox(height: 8),
            ],
            if (summary.bodyLines.isNotEmpty) ...[
              const Text('身体', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              for (final line in summary.bodyLines) _Line(line),
            ],
            if (summary.emotionLines.isEmpty && summary.triggerLines.isEmpty && summary.environmentLines.isEmpty && summary.bodyLines.isEmpty)
              const _Line('当天记录主要是行为事实，暂时没有情绪、触发、环境或身体线索。'),
          ]),
          const SizedBox(height: 12),
          _InfoCard(title: '自动摘要', icon: Icons.auto_awesome_outlined, children: [
            Text(summary.summaryText, style: const TextStyle(color: Color(0xFF334155), height: 1.55, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('这不是行为改变建议，只是把当天记录整理成一段可读摘要。', style: const TextStyle(color: Color(0xFF94A3B8), height: 1.4)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _saving ? null : () => _saveSnapshot(summary),
                icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.archive_outlined),
                label: const Text('保存摘要快照（可选）'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _AutoDailySummary {
  final DateTime date;
  final int recordCount;
  final int totalMinutes;
  final int missingDurationCount;
  final List<String> timeFlowLines;
  final List<String> categoryLines;
  final List<String> importantBehaviors;
  final List<String> emotionLines;
  final List<String> triggerLines;
  final List<String> environmentLines;
  final List<String> bodyLines;
  final String summaryText;

  const _AutoDailySummary({
    required this.date,
    required this.recordCount,
    required this.totalMinutes,
    required this.missingDurationCount,
    required this.timeFlowLines,
    required this.categoryLines,
    required this.importantBehaviors,
    required this.emotionLines,
    required this.triggerLines,
    required this.environmentLines,
    required this.bodyLines,
    required this.summaryText,
  });

  factory _AutoDailySummary.fromRecords(DateTime date, List<BehaviorTrackingRecord> records) {
    final effective = _effectiveTimeRecords(records);
    final buckets = _TimeWhereCard._buildBuckets(effective);
    final totalMinutes = buckets.fold<int>(0, (s, b) => s + b.minutes);
    final timeLines = <String>[];
    for (final b in buckets.take(5)) {
      final ratio = totalMinutes <= 0 ? 0 : (b.minutes * 100 / totalMinutes).round();
      timeLines.add('${b.name}：${_formatDuration(b.minutes)}，约 $ratio%');
    }

    final categoryCount = <String, int>{};
    for (final r in records) {
      final key = _timeReviewCategoryOf(r);
      categoryCount[key] = (categoryCount[key] ?? 0) + 1;
    }
    final categoryLines = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final categoryText = categoryLines.take(6).map((e) {
      final ratio = records.isEmpty ? 0 : (e.value * 100 / records.length).round();
      return '${e.key}：${e.value}条，约 $ratio%';
    }).toList();

    final activityBuckets = _TopBehaviorTimeCard._build(effective);
    final important = <String>[];
    for (final item in activityBuckets.take(5)) {
      important.add('${item.label}：${_formatDuration(item.minutes)}，${item.count}次');
    }
    if (important.length < 5) {
      final seen = important.map((e) => e.split('：').first).toSet();
      for (final r in records.reversed) {
        final label = _activityLabel(r).trim();
        if (label.isEmpty || seen.contains(label)) continue;
        important.add('${r.timeRangeLabel.isEmpty ? '' : '${r.timeRangeLabel} · '}$label');
        seen.add(label);
        if (important.length >= 5) break;
      }
    }

    List<String> topTextValues(Iterable<String> values, {int max = 5}) {
      final map = <String, int>{};
      for (final raw in values) {
        for (final part in raw.split(RegExp(r'[、,，;；\n]'))) {
          final clean = part.trim();
          if (clean.isEmpty) continue;
          map[clean] = (map[clean] ?? 0) + 1;
        }
      }
      final list = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return list.take(max).map((e) => '${e.key}：${e.value}次').toList();
    }

    final emotions = topTextValues(records.map((r) => r.emotion));
    final triggers = topTextValues(records.map((r) => r.trigger.ifBlank(r.reason)), max: 5);
    final envs = topTextValues(records.map((r) => [r.environment, r.locationType, r.peopleContext, ...r.cueTags].where((e) => e.trim().isNotEmpty).join('、')), max: 5);
    final body = <String>[];
    final bodyRecords = records.where((r) => r.bodyState.trim().isNotEmpty || r.sleep.trim().isNotEmpty || r.steps != null || r.exerciseMin != null || r.sleepDurationMin != null).toList();
    for (final r in bodyRecords.take(5)) {
      final parts = <String>[];
      if (r.sleep.trim().isNotEmpty) parts.add('睡眠 ${r.sleep.trim()}');
      if (r.sleepDurationMin != null) parts.add('睡眠 ${_formatDuration(r.sleepDurationMin!)}');
      if (r.steps != null) parts.add('步数 ${r.steps}');
      if (r.exerciseMin != null) parts.add('运动 ${r.exerciseMin}m');
      if (r.bodyState.trim().isNotEmpty) parts.add(r.bodyState.trim());
      if (parts.isNotEmpty) body.add(parts.join(' · '));
    }

    final topCategory = categoryText.isNotEmpty ? categoryText.first.split('：').first : '暂无明显类别';
    final topTime = timeLines.isNotEmpty ? timeLines.first : '暂无可计算时长';
    final summary = records.isEmpty
        ? '当天暂无可汇总记录。'
        : '当天共有 ${records.length} 条行为观察。按记录类别看，最集中的方向是 $topCategory；按可计算时长看，$topTime。${important.isNotEmpty ? '主要行为包括：${important.take(3).join('；')}。' : ''}${emotions.isNotEmpty ? '主要情绪线索：${emotions.take(3).join('；')}。' : ''}${triggers.isNotEmpty ? '常见触发/情境：${triggers.take(3).join('；')}。' : ''}';

    return _AutoDailySummary(
      date: date,
      recordCount: records.length,
      totalMinutes: totalMinutes,
      missingDurationCount: records.where((r) => (r.durationMinutes ?? 0) <= 0).length,
      timeFlowLines: timeLines,
      categoryLines: categoryText.isEmpty ? const ['暂无类别数据。'] : categoryText,
      importantBehaviors: important.isEmpty ? const ['暂无具体行为可汇总。'] : important,
      emotionLines: emotions,
      triggerLines: triggers,
      environmentLines: envs,
      bodyLines: body,
      summaryText: summary,
    );
  }

  Map<String, Object?> toJson() => {
        'date': DateFormat('yyyy-MM-dd').format(date),
        'recordCount': recordCount,
        'totalMinutes': totalMinutes,
        'missingDurationCount': missingDurationCount,
        'timeFlowLines': timeFlowLines,
        'categoryLines': categoryLines,
        'importantBehaviors': importantBehaviors,
        'emotionLines': emotionLines,
        'triggerLines': triggerLines,
        'environmentLines': environmentLines,
        'bodyLines': bodyLines,
        'summaryText': summaryText,
      };
}


class _GuideCard extends StatelessWidget {
  final List<BehaviorTrackingRecord> records;
  final List<BehaviorTrackingRecord> today;
  final VoidCallback onQuick;
  final ValueChanged<BehaviorTemplateInfo> onTemplate;
  final VoidCallback onDailySummary;

  const _GuideCard({required this.records, required this.today, required this.onQuick, required this.onTemplate, required this.onDailySummary});

  @override
  Widget build(BuildContext context) {
    late final String title;
    late final String message;
    late final String actionLabel;
    late final VoidCallback action;
    late final IconData icon;

    if (today.isEmpty) {
      title = '先留下一条行为事实';
      message = '不要从完整表单开始。现在只需要写一句：我刚刚做了什么。';
      actionLabel = '秒记一条';
      action = onQuick;
      icon = Icons.flash_on_outlined;
    } else if (today.any((r) => r.timeRangeLabel.isEmpty)) {
      title = '可以补一个时间块';
      message = '今天已有行为记录。若想看见时间流向，可以补充开始/结束时间。';
      actionLabel = '记录时间块';
      action = () => onTemplate(_template('time_block'));
      icon = Icons.schedule_outlined;
    } else if (today.any((r) => r.emotion.trim().isEmpty && r.trigger.trim().isEmpty)) {
      title = '可以补充发生情境';
      message = '行为已经记录。现在可以选一条明显行为，补充当时情绪或触发点。';
      actionLabel = '记录触发链';
      action = () => onTemplate(_template('tbr'));
      icon = Icons.account_tree_outlined;
    } else {
      title = '今天的证据已经够用';
      message = '如果不想继续填表，到这里就可以。晚上可用每日摘要把一天串起来。';
      actionLabel = '查看每日摘要';
      action = onDailySummary;
      icon = Icons.today_outlined;
    }

    return _InfoCard(title: title, icon: icon, children: [
      Text(message, style: const TextStyle(color: Color(0xFF64748B), height: 1.45)),
      const SizedBox(height: 12),
      Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: action, icon: Icon(icon), label: Text(actionLabel))),
    ]);
  }
}

class _LayersPage extends StatelessWidget {
  final ValueChanged<BehaviorLayerInfo> onLayer;
  const _LayersPage({required this.onLayer});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 96), children: [
      _InfoCard(title: '七层行为观察', icon: Icons.layers_outlined, children: const [
        _Line('每次不必填满七层。最好的方式是：发生什么就记录什么，缺什么以后再补。'),
        _Line('七层之间不是任务清单，而是观察角度：时间、行为、情绪、认知、结果、环境、身体。'),
      ]),
      const SizedBox(height: 12),
      for (final layer in behaviorLayerInfos) ...[
        _LayerCard(layer: layer, onTap: () => onLayer(layer)),
        const SizedBox(height: 10),
      ],
    ]);
  }
}

class _RecordsPage extends StatefulWidget {
  final List<BehaviorTrackingRecord> records;
  final List<String> categories;
  final ValueChanged<BehaviorTrackingRecord> onEdit;
  final ValueChanged<BehaviorTrackingRecord> onDelete;
  final VoidCallback onClearAll;
  final VoidCallback onQuick;
  const _RecordsPage({required this.records, required this.categories, required this.onEdit, required this.onDelete, required this.onClearAll, required this.onQuick});

  @override
  State<_RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<_RecordsPage> {
  String _query = '';
  String _category = '全部';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.records.where((r) {
      final matchesCategory = _category == '全部'
          || (_category == '预设行为' && _isPlannedRecord(r))
          || (_category == '非计划行为' && !_isPlannedRecord(r))
          || r.category == _category
          || r.primaryLayer == _category;
      final q = _query.trim();
      final text = '${r.title} ${r.behavior} ${r.reason} ${r.trigger} ${r.emotion} ${r.environment} ${r.bodyState} ${r.notes}'.toLowerCase();
      final matchesQuery = q.isEmpty || text.contains(q.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();

    return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 96), children: [
      _InfoCard(title: '记录列表', icon: Icons.list_alt_outlined, children: [
        _FieldLite(label: '搜索', hint: '搜索行为、触发、情绪、环境...', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: ['全部', '预设行为', '非计划行为', ...widget.categories].map((c) => ChoiceChip(label: Text(c), selected: _category == c, onSelected: (_) => setState(() => _category = c))).toList()),
        const SizedBox(height: 12),
        if (widget.records.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
              onPressed: widget.onClearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('清空全部记录'),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      if (filtered.isEmpty)
        _EmptyCard(text: widget.records.isEmpty ? '还没有任何行为记录。先点右下角“秒记”。' : '没有匹配记录，可换一个关键词或类别。')
      else
        for (final r in filtered) _RecordTile(record: r, onTap: () => widget.onEdit(r), onDelete: () => widget.onDelete(r)),
    ]);
  }
}

class _StatsPage extends StatefulWidget {
  final List<BehaviorTrackingRecord> records;
  final int pendingImportCount;
  final VoidCallback onOpenPending;
  final ValueChanged<String> onExport;
  const _StatsPage({required this.records, required this.pendingImportCount, required this.onOpenPending, required this.onExport});

  @override
  State<_StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<_StatsPage> {
  String _rangeKey = 'today';
  String _category = '全部';
  String _query = '';
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  Widget build(BuildContext context) {
    final period = _resolvePeriod();
    final periodRecords = _filterByPeriod(widget.records, period.start, period.endExclusive);
    final visible = periodRecords.where((r) {
      final matchesCategory = _category == '全部' || _category == _categoryOf(r);
      final q = _query.trim().toLowerCase();
      final body = '${r.title} ${r.behavior} ${r.projectKey} ${r.category} ${r.primaryLayer} ${r.trigger} ${r.emotion} ${r.environment} ${r.bodyState} ${r.notes}'.toLowerCase();
      return matchesCategory && (q.isEmpty || body.contains(q));
    }).toList()
      ..sort(_recordSort);

    return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 96), children: [
      _InfoCard(title: '复盘：时间花在哪里', icon: Icons.insights_outlined, children: [
        const Text('复盘页不只看“有没有时间块”。先用类别比重看行为主要集中在哪些方面；有时长时再看时间流向；无时长时也能通过次数、来源、层面和情绪分布看出行为结构。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
        const SizedBox(height: 12),
        _RangeSelector(
          selected: _rangeKey,
          periodLabel: period.label,
          onSelected: (key) => setState(() => _rangeKey = key),
          onPickCustom: _pickCustomRange,
        ),
      ]),
      const SizedBox(height: 12),
      if (widget.pendingImportCount > 0) ...[
        _PendingImportCard(count: widget.pendingImportCount, onTap: widget.onOpenPending),
        const SizedBox(height: 12),
      ],
      _BehaviorCategoryWeightCard(records: periodRecords, periodLabel: period.label),
      const SizedBox(height: 12),
      _TimeFirstDashboard(records: periodRecords, periodLabel: period.label),
      const SizedBox(height: 12),
      _TimeWhereCard(records: periodRecords, periodLabel: period.label),
      const SizedBox(height: 12),
      _TopBehaviorTimeCard(records: periodRecords, periodLabel: period.label),
      const SizedBox(height: 12),
      _HourDistributionCard(records: periodRecords, periodLabel: period.label),
      const SizedBox(height: 12),
      _MultiDimensionReviewCard(records: periodRecords, periodLabel: period.label),
      const SizedBox(height: 12),
      _ObservationClarityCard(
        records: periodRecords,
        periodLabel: period.label,
        pendingImportCount: widget.pendingImportCount,
        onOpenPending: widget.onOpenPending,
      ),
      const SizedBox(height: 12),
      _InfoCard(title: '导出本地数据', icon: Icons.file_download_outlined, children: [
        const Text('所有记录默认保存在本地，可导出为 Markdown、CSV 或 JSON。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonalIcon(onPressed: () => widget.onExport('markdown'), icon: const Icon(Icons.description_outlined), label: const Text('Markdown')),
          FilledButton.tonalIcon(onPressed: () => widget.onExport('csv'), icon: const Icon(Icons.table_chart_outlined), label: const Text('CSV')),
          FilledButton.tonalIcon(onPressed: () => widget.onExport('json'), icon: const Icon(Icons.data_object_outlined), label: const Text('JSON')),
        ]),
      ]),
    ]);
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initialStart = _customStart ?? DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final initialEnd = _customEnd ?? DateTime(now.year, now.month, now.day);
    final start = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: initialStart);
    if (start == null) return;
    if (!mounted) return;
    final end = await showDatePicker(context: context, firstDate: start, lastDate: DateTime(2100), initialDate: initialEnd.isBefore(start) ? start : initialEnd);
    if (end == null) return;
    setState(() {
      _customStart = DateTime(start.year, start.month, start.day);
      _customEnd = DateTime(end.year, end.month, end.day);
      _rangeKey = 'custom';
    });
  }

  _ReviewPeriod _resolvePeriod() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime start;
    DateTime end = today.add(const Duration(days: 1));
    String label;
    switch (_rangeKey) {
      case '7':
        start = today.subtract(const Duration(days: 6));
        label = '近7天';
        break;
      case '30':
        start = today.subtract(const Duration(days: 29));
        label = '近30天';
        break;
      case '90':
        start = today.subtract(const Duration(days: 89));
        label = '近90天';
        break;
      case '180':
        start = today.subtract(const Duration(days: 182));
        label = '近半年';
        break;
      case 'custom':
        start = _customStart ?? today;
        final e = _customEnd ?? today;
        end = DateTime(e.year, e.month, e.day).add(const Duration(days: 1));
        label = '${DateFormat('MM/dd').format(start)}–${DateFormat('MM/dd').format(e)}';
        break;
      case 'today':
      default:
        start = today;
        label = '今天';
        break;
    }
    return _ReviewPeriod(label: label, start: start, endExclusive: end);
  }

  static List<BehaviorTrackingRecord> _filterByPeriod(List<BehaviorTrackingRecord> records, DateTime start, DateTime endExclusive) {
    return records.where((r) {
      final d = DateTime(r.recordDate.year, r.recordDate.month, r.recordDate.day);
      return !d.isBefore(start) && d.isBefore(endExclusive);
    }).toList();
  }

  static int _recordSort(BehaviorTrackingRecord a, BehaviorTrackingRecord b) {
    final date = b.recordDateMs.compareTo(a.recordDateMs);
    if (date != 0) return date;
    final sa = a.startMinute ?? 24 * 60 + 1;
    final sb = b.startMinute ?? 24 * 60 + 1;
    final time = sa.compareTo(sb);
    if (time != 0) return time;
    return (b.id ?? 0).compareTo(a.id ?? 0);
  }

  static String _categoryOf(BehaviorTrackingRecord r) => _timeReviewCategoryOf(r);

  static List<String> _categoriesIn(List<BehaviorTrackingRecord> records) {
    final set = records.map(_categoryOf).where((e) => e.trim().isNotEmpty).toSet().toList()..sort();
    return set;
  }

  static List<BehaviorTrackingRecord> _period(List<BehaviorTrackingRecord> records, int days) {
    final start = DateTime.now().subtract(Duration(days: days - 1));
    final startDay = DateTime(start.year, start.month, start.day);
    return records.where((r) => !r.recordDate.isBefore(startDay)).toList();
  }

  static Map<String, int> _countBy(List<BehaviorTrackingRecord> records, String Function(BehaviorTrackingRecord r) keyOf) {
    final map = <String, int>{};
    for (final r in records) {
      final key = keyOf(r).trim().ifBlank('未分类');
      map[key] = (map[key] ?? 0) + 1;
    }
    final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries.take(8));
  }

  static List<Widget> _topLines(Map<String, int> data) {
    if (data.isEmpty) return const [_Line('暂无足够记录。')];
    return data.entries.map((e) => _Line('${e.key}：${e.value} 条')).toList();
  }

  static List<Widget> _coverageLines(List<BehaviorTrackingRecord> records) {
    if (records.isEmpty) return const [_Line('当前范围暂无记录。')];
    int count(bool Function(BehaviorTrackingRecord r) test) => records.where(test).length;
    final total = records.length;
    final items = <String, int>{
      '时间层面': count((r) => r.timeRangeLabel.isNotEmpty),
      '行为层面': count((r) => r.behavior.trim().isNotEmpty),
      '情绪层面': count((r) => r.emotion.trim().isNotEmpty),
      '认知层面': count((r) => r.automaticThought.trim().isNotEmpty || r.cognition.trim().isNotEmpty),
      '结果层面': count((r) => r.shortTermResult.trim().isNotEmpty || r.longTermImpact.trim().isNotEmpty),
      '环境层面': count((r) => r.environment.trim().isNotEmpty || r.locationType.trim().isNotEmpty),
      '身体状态': count((r) => r.bodyState.trim().isNotEmpty || r.sleep.trim().isNotEmpty),
    };
    return items.entries.map((e) => _Line('${e.key}：${e.value}/$total')).toList();
  }
}

class _ReviewPeriod {
  final String label;
  final DateTime start;
  final DateTime endExclusive;
  const _ReviewPeriod({required this.label, required this.start, required this.endExclusive});
}


class _RangeOption {
  final String key;
  final String label;
  const _RangeOption(this.key, this.label);
}

class _RangeSelector extends StatelessWidget {
  final String selected;
  final String periodLabel;
  final ValueChanged<String> onSelected;
  final VoidCallback onPickCustom;
  const _RangeSelector({required this.selected, required this.periodLabel, required this.onSelected, required this.onPickCustom});

  @override
  Widget build(BuildContext context) {
    const ranges = <_RangeOption>[
      _RangeOption('today', '今天'),
      _RangeOption('7', '近7天'),
      _RangeOption('30', '近30天'),
      _RangeOption('90', '近90天'),
      _RangeOption('180', '近半年'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in ranges)
            ChoiceChip(label: Text(item.label), selected: selected == item.key, onSelected: (_) => onSelected(item.key)),
          ChoiceChip(label: Text(selected == 'custom' ? '自定义：$periodLabel' : '自定义'), selected: selected == 'custom', onSelected: (_) => onPickCustom()),
        ],
      ),
    ]);
  }
}


class _TimeFirstDashboard extends StatelessWidget {
  final List<BehaviorTrackingRecord> records;
  final String periodLabel;
  const _TimeFirstDashboard({required this.records, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final effective = _effectiveTimeRecords(records);
    final timed = effective.where((r) => (r.durationMinutes ?? 0) > 0).toList();
    final totalMinutes = timed.fold<int>(0, (s, r) => s + (r.durationMinutes ?? 0));
    final buckets = _TimeWhereCard._buildBuckets(effective);
    final top = buckets.isEmpty ? null : buckets.first;
    final topRatio = top == null || totalMinutes <= 0 ? 0.0 : top.minutes / totalMinutes;
    final missing = records.where((r) => (r.durationMinutes ?? 0) <= 0).length;
    final dataQuality = records.isEmpty ? 0.0 : timed.length / records.length;

    return _InfoCard(title: '$periodLabel · 第一眼看时间去向', icon: Icons.access_time_filled_outlined, children: [
      if (totalMinutes <= 0) ...[
        const Text('当前范围还没有可计算时长，所以暂时无法计算“时间占比”。但上方的“行为类别比重”仍会按记录次数展示各类行为的占比，先帮助你看清行为集中在哪些方面。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
        const SizedBox(height: 10),
        const _Line('想进一步看到真正的时间流向，可记录时间块，或使用屏幕使用、系统日历、番茄钟自动导入。'),
      ] else ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Color(0x22111827), blurRadius: 18, offset: Offset(0, 8))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('你的时间主要流向', style: TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(top?.name ?? '未分类', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('${_formatDuration(top?.minutes ?? 0)}，占已记录时间 ${(topRatio * 100).round()}%', style: const TextStyle(color: Color(0xFFBAE6FD), height: 1.35, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: topRatio.clamp(0.0, 1.0).toDouble(), minHeight: 12, backgroundColor: const Color(0xFF334155))),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _TimeMetricTile(label: '已解释时间', value: _formatDuration(totalMinutes), helper: '有时长的行为合计')),
          const SizedBox(width: 10),
          Expanded(child: _TimeMetricTile(label: '有时长覆盖', value: '${(dataQuality * 100).round()}%', helper: missing > 0 ? '$missing 条暂无时长' : '全部有时长')),
        ]),
        const SizedBox(height: 12),
        if (buckets.length > 1)
          Text('接下来重点看下面的“时间去向地图”和“具体行为排行”，它们比记录数更能回答：我到底把时间花到哪里了。', style: const TextStyle(color: Color(0xFF64748B), height: 1.45)),
      ],
    ]);
  }
}

class _TimeMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  const _TimeMetricTile({required this.label, required this.value, required this.helper});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(helper, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.25)),
        ]),
      );
}


class _BehaviorCategoryWeightCard extends StatelessWidget {
  final List<BehaviorTrackingRecord> records;
  final String periodLabel;
  const _BehaviorCategoryWeightCard({required this.records, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox.shrink();
    final effectiveTimed = _effectiveTimeRecords(records);
    final timedMinutesByCategory = <String, int>{};
    for (final r in effectiveTimed) {
      final key = _timeReviewCategoryOf(r);
      timedMinutesByCategory[key] = (timedMinutesByCategory[key] ?? 0) + (r.durationMinutes ?? 0);
    }
    final countByCategory = <String, int>{};
    for (final r in records) {
      final key = _timeReviewCategoryOf(r);
      countByCategory[key] = (countByCategory[key] ?? 0) + 1;
    }
    final totalCount = records.length;
    final totalMinutes = timedMinutesByCategory.values.fold<int>(0, (s, v) => s + v);
    final keys = <String>{...countByCategory.keys, ...timedMinutesByCategory.keys}.toList()
      ..sort((a, b) {
        final byMinutes = (timedMinutesByCategory[b] ?? 0).compareTo(timedMinutesByCategory[a] ?? 0);
        if (byMinutes != 0) return byMinutes;
        return (countByCategory[b] ?? 0).compareTo(countByCategory[a] ?? 0);
      });

    final subtitle = totalMinutes > 0
        ? '同时显示“时间占比”和“记录次数占比”。这样既能看清时间实际流向，也不会忽略那些尚未填写时长的行为。'
        : '当前范围没有可计算时长，因此先按记录次数展示行为类别比重；这仍然能告诉你：最近记录最集中在哪些方面。';

    return _InfoCard(title: '$periodLabel · 行为类别比重', icon: Icons.donut_large_outlined, children: [
      Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), height: 1.45)),
      const SizedBox(height: 12),
      for (final key in keys.take(10))
        _CategoryWeightLine(
          category: key,
          count: countByCategory[key] ?? 0,
          totalCount: totalCount,
          minutes: timedMinutesByCategory[key] ?? 0,
          totalMinutes: totalMinutes,
        ),
      if (keys.length > 10)
        Text('还有 ${keys.length - 10} 个类别未显示，可缩短时间范围或到记录页筛选查看。', style: const TextStyle(color: Color(0xFF94A3B8))),
    ]);
  }
}

class _CategoryWeightLine extends StatelessWidget {
  final String category;
  final int count;
  final int totalCount;
  final int minutes;
  final int totalMinutes;
  const _CategoryWeightLine({required this.category, required this.count, required this.totalCount, required this.minutes, required this.totalMinutes});

  @override
  Widget build(BuildContext context) {
    final countRatio = totalCount <= 0 ? 0.0 : count / totalCount;
    final timeRatio = totalMinutes <= 0 ? 0.0 : minutes / totalMinutes;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(category, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 16))),
          Text('$count 条 · ${(countRatio * 100).round()}%', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        _RatioBar(label: '次数', ratio: countRatio, trailing: '$count/$totalCount'),
        if (totalMinutes > 0) ...[
          const SizedBox(height: 6),
          _RatioBar(label: '时长', ratio: timeRatio, trailing: minutes > 0 ? '${_formatDuration(minutes)} · ${(timeRatio * 100).round()}%' : '暂无时长'),
        ],
      ]),
    );
  }
}

class _RatioBar extends StatelessWidget {
  final String label;
  final double ratio;
  final String trailing;
  const _RatioBar({required this.label, required this.ratio, required this.trailing});

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 36, child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w800))),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: ratio.clamp(0.0, 1.0).toDouble(), minHeight: 8, backgroundColor: const Color(0xFFE5E7EB)))),
        const SizedBox(width: 8),
        SizedBox(width: 82, child: Text(trailing, textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w800))),
      ]);
}

class _MultiDimensionReviewCard extends StatelessWidget {
  final List<BehaviorTrackingRecord> records;
  final String periodLabel;
  const _MultiDimensionReviewCard({required this.records, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox.shrink();
    final layerMap = <String, int>{};
    final sourceMap = <String, int>{};
    final emotionMap = <String, int>{};
    final environmentMap = <String, int>{};
    for (final r in records) {
      final layer = r.primaryLayer.trim().ifBlank(_inferLayerLabel(r));
      layerMap[layer] = (layerMap[layer] ?? 0) + 1;
      final source = _sourceLabelOf(r);
      sourceMap[source] = (sourceMap[source] ?? 0) + 1;
      final emotion = r.emotion.trim();
      if (emotion.isNotEmpty) emotionMap[emotion] = (emotionMap[emotion] ?? 0) + 1;
      final env = r.locationType.trim().ifBlank(r.environment.trim());
      if (env.isNotEmpty) environmentMap[env] = (environmentMap[env] ?? 0) + 1;
    }
    return _InfoCard(title: '$periodLabel · 多维观察结构', icon: Icons.hub_outlined, children: [
      const Text('这一块不回答“花了多久”，而回答“我主要在观察什么、数据来自哪里、哪些情绪或环境反复出现”。它是时间统计的补充，不要求每条记录都有时间块。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
      const SizedBox(height: 12),
      _MiniDistribution(title: '观察层面', data: layerMap),
      const SizedBox(height: 10),
      _MiniDistribution(title: '记录来源', data: sourceMap),
      if (emotionMap.isNotEmpty) ...[
        const SizedBox(height: 10),
        _MiniDistribution(title: '情绪出现', data: emotionMap),
      ],
      if (environmentMap.isNotEmpty) ...[
        const SizedBox(height: 10),
        _MiniDistribution(title: '环境线索', data: environmentMap),
      ],
    ]);
  }
}

class _MiniDistribution extends StatelessWidget {
  final String title;
  final Map<String, int> data;
  const _MiniDistribution({required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold<int>(0, (s, v) => s + v);
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (total <= 0 || entries.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final e in entries.take(5)) ...[
          Row(children: [
            Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700))),
            Text('${e.value} 条 · ${((e.value / total) * 100).round()}%', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: (e.value / total).clamp(0.0, 1.0).toDouble(), minHeight: 6, backgroundColor: const Color(0xFFE5E7EB))),
          const SizedBox(height: 7),
        ],
      ]),
    );
  }
}

String _inferLayerLabel(BehaviorTrackingRecord r) {
  if (r.timeRangeLabel.isNotEmpty || (r.durationMinutes ?? 0) > 0) return '时间层面';
  if (r.emotion.trim().isNotEmpty) return '情绪层面';
  if (r.automaticThought.trim().isNotEmpty || r.cognition.trim().isNotEmpty) return '认知层面';
  if (r.shortTermResult.trim().isNotEmpty || r.longTermImpact.trim().isNotEmpty) return '结果层面';
  if (r.environment.trim().isNotEmpty || r.locationType.trim().isNotEmpty) return '环境层面';
  if (r.bodyState.trim().isNotEmpty || r.sleep.trim().isNotEmpty || r.steps != null || r.exerciseMin != null) return '身体状态';
  return '行为层面';
}

class _ObservationClarityCard extends StatelessWidget {
  final List<BehaviorTrackingRecord> records;
  final String periodLabel;
  final int pendingImportCount;
  final VoidCallback onOpenPending;
  const _ObservationClarityCard({required this.records, required this.periodLabel, required this.pendingImportCount, required this.onOpenPending});

  @override
  Widget build(BuildContext context) {
    final effective = _effectiveTimeRecords(records);
    final timed = effective.where((r) => (r.durationMinutes ?? 0) > 0).toList();
    final missing = records.where((r) => (r.durationMinutes ?? 0) <= 0).toList();
    final totalMinutes = timed.fold<int>(0, (s, r) => s + (r.durationMinutes ?? 0));
    final buckets = _TimeWhereCard._buildBuckets(effective);
    final top = buckets.isEmpty ? null : buckets.first;
    final coverage = records.isEmpty ? 0.0 : timed.length / records.length;

    if (records.isEmpty && pendingImportCount <= 0) return const SizedBox.shrink();

    return _InfoCard(title: '$periodLabel · 时间观察是否清楚', icon: Icons.visibility_outlined, children: [
      const Text('这里不再把“情绪条数、层面条数”当成重点。复盘页最重要的是：哪些时间已经被看清，哪些时间还没有进入时间去向统计。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _TimeMetricTile(label: '已看清时间', value: _formatDuration(totalMinutes), helper: top == null ? '暂无主去向' : '最大去向：${top.name}')),
        const SizedBox(width: 10),
        Expanded(child: _TimeMetricTile(label: '计时覆盖', value: '${(coverage * 100).round()}%', helper: missing.isEmpty ? '全部可参与时间占比' : '${missing.length} 条未计时')),
      ]),
      if (pendingImportCount > 0) ...[
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpenPending,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFDE68A))),
            child: Row(children: [
              const Icon(Icons.pending_actions_outlined, color: Color(0xFFB45309)),
              const SizedBox(width: 10),
              Expanded(child: Text('有 $pendingImportCount 条自动导入数据还未确认。它们不会被当作“类别”参与时间去向；点击进入数据源确认明细。', style: const TextStyle(color: Color(0xFF92400E), height: 1.35, fontWeight: FontWeight.w800))),
              const Icon(Icons.chevron_right, color: Color(0xFFB45309)),
            ]),
          ),
        ),
      ],
      if (missing.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Text('未计时记录不会参与“时间花在哪里”的占比。下面只列少量样例，方便你发现哪些记录还缺开始/结束时间。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
        const SizedBox(height: 8),
        for (final r in missing.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text('· ${DateFormat('MM/dd').format(r.recordDate)} ${_activityLabel(r)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF475569), height: 1.35)),
          ),
        if (missing.length > 5) Text('还有 ${missing.length - 5} 条未显示。', style: const TextStyle(color: Color(0xFF94A3B8))),
      ],
    ]);
  }
}

class _TopBehaviorTimeCard extends StatelessWidget {
  final List<BehaviorTrackingRecord> records;
  final String periodLabel;
  const _TopBehaviorTimeCard({required this.records, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final effective = _effectiveTimeRecords(records);
    final items = _build(effective);
    final total = items.fold<int>(0, (s, e) => s + e.minutes);
    if (records.isEmpty || total <= 0) return const SizedBox.shrink();
    return _InfoCard(title: '$periodLabel · 具体行为时间排行', icon: Icons.format_list_numbered_outlined, children: [
      const Text('这里显示具体行为或具体应用，而不是只显示类别。屏幕使用时间虽然统一归类，但在这里仍会显示具体 App，方便你看清手机时间具体被谁占用。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
      const SizedBox(height: 12),
      for (final item in items.take(12)) _BehaviorTimeRankLine(item: item, totalMinutes: total),
      if (items.length > 12) Text('还有 ${items.length - 12} 类具体行为未显示，可用上方搜索或类别筛选查看。', style: const TextStyle(color: Color(0xFF94A3B8))),
    ]);
  }

  static List<_ActivityTimeBucket> _build(List<BehaviorTrackingRecord> records) {
    final map = <String, _ActivityTimeBucket>{};
    for (final r in records) {
      final minutes = r.durationMinutes ?? 0;
      if (minutes <= 0) continue;
      final raw = _activityLabel(r).trim().ifBlank('未命名行为');
      final key = raw.length > 24 ? raw.substring(0, 24) : raw;
      final category = _timeReviewCategoryOf(r);
      final old = map[key];
      if (old == null) {
        map[key] = _ActivityTimeBucket(label: key, category: category, minutes: minutes, count: 1);
      } else {
        map[key] = old.copyWith(minutes: old.minutes + minutes, count: old.count + 1);
      }
    }
    final list = map.values.toList()..sort((a, b) => b.minutes.compareTo(a.minutes));
    return list;
  }
}

class _ActivityTimeBucket {
  final String label;
  final String category;
  final int minutes;
  final int count;
  const _ActivityTimeBucket({required this.label, required this.category, required this.minutes, required this.count});
  _ActivityTimeBucket copyWith({int? minutes, int? count}) => _ActivityTimeBucket(label: label, category: category, minutes: minutes ?? this.minutes, count: count ?? this.count);
}

class _BehaviorTimeRankLine extends StatelessWidget {
  final _ActivityTimeBucket item;
  final int totalMinutes;
  const _BehaviorTimeRankLine({required this.item, required this.totalMinutes});

  @override
  Widget build(BuildContext context) {
    final ratio = totalMinutes <= 0 ? 0.0 : item.minutes / totalMinutes;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A)))),
          Text('${_formatDuration(item.minutes)} · ${(ratio * 100).round()}%', style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: ratio.clamp(0.0, 1.0).toDouble(), minHeight: 8, backgroundColor: const Color(0xFFE5E7EB)))),
          const SizedBox(width: 8),
          Text('${item.category} · ${item.count}次', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

class _HourDistributionCard extends StatelessWidget {
  final List<BehaviorTrackingRecord> records;
  final String periodLabel;
  const _HourDistributionCard({required this.records, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final effective = _effectiveTimeRecords(records);
    final slots = _build(effective);
    final total = slots.fold<int>(0, (s, e) => s + e.minutes);
    if (total <= 0) return const SizedBox.shrink();
    return _InfoCard(title: '$periodLabel · 一天中哪些时段被占用', icon: Icons.view_timeline_outlined, children: [
      const Text('按开始时间粗略分布，帮助你看见上午、下午、晚上和深夜的时间流向。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
      const SizedBox(height: 12),
      for (final slot in slots) _TimeSlotLine(slot: slot, totalMinutes: total),
    ]);
  }

  static List<_TimeSlotBucket> _build(List<BehaviorTrackingRecord> records) {
    final slots = <_TimeSlotBucket>[
      const _TimeSlotBucket(name: '清晨 05–09', minutes: 0, examples: []),
      const _TimeSlotBucket(name: '上午 09–12', minutes: 0, examples: []),
      const _TimeSlotBucket(name: '下午 12–18', minutes: 0, examples: []),
      const _TimeSlotBucket(name: '晚上 18–24', minutes: 0, examples: []),
      const _TimeSlotBucket(name: '深夜 00–05', minutes: 0, examples: []),
    ];
    final mutable = slots.map((e) => _TimeSlotMutable(e.name)).toList();
    for (final r in records) {
      final minutes = r.durationMinutes ?? 0;
      final start = r.startMinute;
      if (minutes <= 0 || start == null) continue;
      final hour = (start ~/ 60) % 24;
      final idx = hour >= 5 && hour < 9 ? 0 : hour >= 9 && hour < 12 ? 1 : hour >= 12 && hour < 18 ? 2 : hour >= 18 && hour < 24 ? 3 : 4;
      mutable[idx].minutes += minutes;
      if (mutable[idx].examples.length < 3) mutable[idx].examples.add(_activityLabel(r));
    }
    return mutable.where((e) => e.minutes > 0).map((e) => _TimeSlotBucket(name: e.name, minutes: e.minutes, examples: e.examples)).toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));
  }
}

class _TimeSlotMutable {
  final String name;
  int minutes = 0;
  final List<String> examples = [];
  _TimeSlotMutable(this.name);
}

class _TimeSlotBucket {
  final String name;
  final int minutes;
  final List<String> examples;
  const _TimeSlotBucket({required this.name, required this.minutes, required this.examples});
}

class _TimeSlotLine extends StatelessWidget {
  final _TimeSlotBucket slot;
  final int totalMinutes;
  const _TimeSlotLine({required this.slot, required this.totalMinutes});

  @override
  Widget build(BuildContext context) {
    final ratio = totalMinutes <= 0 ? 0.0 : slot.minutes / totalMinutes;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(slot.name, style: const TextStyle(fontWeight: FontWeight.w900))),
          Text('${_formatDuration(slot.minutes)} · ${(ratio * 100).round()}%', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: ratio.clamp(0.0, 1.0).toDouble(), minHeight: 8, backgroundColor: const Color(0xFFE5E7EB))),
        if (slot.examples.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text('例：${slot.examples.join('、')}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), height: 1.35)),
        ],
      ]),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final String periodLabel;
  final List<String> categories;
  final String category;
  final String query;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onQuery;
  const _FilterPanel({required this.periodLabel, required this.categories, required this.category, required this.query, required this.onCategory, required this.onQuery});

  @override
  Widget build(BuildContext context) => _InfoCard(title: '$periodLabel · 筛选查看', icon: Icons.filter_alt_outlined, children: [
        _FieldLite(label: '搜索具体行为', hint: '例如：刷视频、通勤、学习、吃饭、番茄钟...', onChanged: onQuery),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((c) => ChoiceChip(label: Text(c), selected: category == c, onSelected: (_) => onCategory(c))).toList(),
        ),
      ]);
}

class _TimeWhereCard extends StatelessWidget {
  final List<BehaviorTrackingRecord> records;
  final String periodLabel;
  const _TimeWhereCard({required this.records, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final effective = _effectiveTimeRecords(records);
    final buckets = _buildBuckets(effective);
    final total = buckets.fold<int>(0, (s, b) => s + b.minutes);
    final missing = records.where((r) => (r.durationMinutes ?? 0) <= 0).length;
    if (records.isEmpty) {
      return const _EmptyCard(text: '当前时间范围内没有记录。可以先用“秒记”或“时间块”记录一条行为。');
    }
    if (total <= 0) {
      return _InfoCard(title: '$periodLabel · 时间去向地图', icon: Icons.pie_chart_outline, children: [
        _Line('当前范围有 ${records.length} 条记录，但都没有开始/结束时间或时长。'),
        const _Line('想看到时间占比，需要记录“时间块”或通过屏幕使用、日历、番茄钟导入时间。'),
      ]);
    }
    return _InfoCard(title: '$periodLabel · 时间去向地图', icon: Icons.pie_chart_outline, children: [
      Text('这里只显示各类别总览，不在主页面堆明细。屏幕使用时间会统一归入“屏幕使用时间”类，不再按娱乐/工作等二次拆分；点击类别可查看全部具体明细。${missing > 0 ? '另有 $missing 条无时长，暂不参与时间占比。' : ''}', style: const TextStyle(color: Color(0xFF64748B), height: 1.45)),
      const SizedBox(height: 12),
      for (final bucket in buckets) ...[
        _TimeBucketView(bucket: bucket, totalMinutes: total),
        const SizedBox(height: 12),
      ],
    ]);
  }

  static List<_TimeBucket> _buildBuckets(List<BehaviorTrackingRecord> records) {
    final map = <String, List<BehaviorTrackingRecord>>{};
    for (final r in records) {
      final minutes = r.durationMinutes ?? 0;
      if (minutes <= 0) continue;
      final key = _timeReviewCategoryOf(r);
      map.putIfAbsent(key, () => []).add(r);
    }
    final buckets = map.entries.map((e) {
      final list = e.value.toList()..sort((a, b) => (b.durationMinutes ?? 0).compareTo(a.durationMinutes ?? 0));
      final minutes = list.fold<int>(0, (s, r) => s + (r.durationMinutes ?? 0));
      return _TimeBucket(name: e.key, minutes: minutes, records: list);
    }).toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));
    return buckets;
  }
}

class _TimeBucket {
  final String name;
  final int minutes;
  final List<BehaviorTrackingRecord> records;
  const _TimeBucket({required this.name, required this.minutes, required this.records});
}

class _TimeBucketView extends StatelessWidget {
  final _TimeBucket bucket;
  final int totalMinutes;
  const _TimeBucketView({required this.bucket, required this.totalMinutes});

  @override
  Widget build(BuildContext context) {
    final ratio = totalMinutes <= 0 ? 0.0 : bucket.minutes / totalMinutes;
    final days = bucket.records.map((r) => DateFormat('yyyy-MM-dd').format(r.recordDate)).toSet().length;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _CategoryTimeDetailPage(bucket: bucket, totalMinutes: totalMinutes),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(bucket.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            Text('${_formatDuration(bucket.minutes)} · ${(ratio * 100).round()}%', style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w900)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: ratio.clamp(0.0, 1.0).toDouble(), minHeight: 11, backgroundColor: const Color(0xFFE5E7EB))),
          const SizedBox(height: 8),
          Text('${bucket.records.length} 条有时长记录 · 覆盖 $days 天 · 点击查看全部明细', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _CategoryTimeDetailPage extends StatefulWidget {
  final _TimeBucket bucket;
  final int totalMinutes;
  const _CategoryTimeDetailPage({required this.bucket, required this.totalMinutes});

  @override
  State<_CategoryTimeDetailPage> createState() => _CategoryTimeDetailPageState();
}

class _CategoryTimeDetailPageState extends State<_CategoryTimeDetailPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final bucket = widget.bucket;
    final ratio = widget.totalMinutes <= 0 ? 0.0 : bucket.minutes / widget.totalMinutes;
    final filtered = bucket.records.where((r) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      final body = '${r.title} ${r.behavior} ${r.projectKey} ${r.notes} ${r.trigger} ${r.environment}'.toLowerCase();
      return body.contains(q);
    }).toList()
      ..sort((a, b) {
        final date = b.recordDateMs.compareTo(a.recordDateMs);
        if (date != 0) return date;
        return (a.startMinute ?? 9999).compareTo(b.startMinute ?? 9999);
      });
    final byDay = <String, List<BehaviorTrackingRecord>>{};
    for (final r in filtered) {
      final day = DateFormat('yyyy-MM-dd').format(r.recordDate);
      byDay.putIfAbsent(day, () => []).add(r);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text('${bucket.name}明细'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: [
        _InfoCard(title: '这个类别占用了多少时间', icon: Icons.access_time_outlined, children: [
          Text('${bucket.name} 共 ${_formatDuration(bucket.minutes)}，占当前范围已记录时间 ${(ratio * 100).round()}%。', style: const TextStyle(color: Color(0xFF475569), height: 1.45, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: ratio.clamp(0.0, 1.0).toDouble(), minHeight: 12, backgroundColor: const Color(0xFFE5E7EB))),
          const SizedBox(height: 12),
          _FieldLite(label: '搜索本类别明细', hint: '例如：Chrome、通勤、学习、聊天...', onChanged: (v) => setState(() => _query = v)),
        ]),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const _EmptyCard(text: '没有匹配的明细。')
        else
          for (final day in days) ...[
            _InfoCard(title: '$day · ${_formatDuration((byDay[day] ?? const []).fold<int>(0, (s, r) => s + (r.durationMinutes ?? 0)))}', icon: Icons.calendar_today_outlined, children: [
              for (final r in byDay[day] ?? const <BehaviorTrackingRecord>[]) _BehaviorFactLine(record: r),
            ]),
            const SizedBox(height: 12),
          ],
      ]),
    );
  }
}

class _BehaviorListCard extends StatelessWidget {
  final List<BehaviorTrackingRecord> records;
  final String periodLabel;
  const _BehaviorListCard({required this.records, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final sorted = records.toList()
      ..sort((a, b) => (b.durationMinutes ?? 0).compareTo(a.durationMinutes ?? 0));
    if (records.isEmpty) return const SizedBox.shrink();
    return _InfoCard(title: '$periodLabel · 具体做了哪些事', icon: Icons.list_alt_outlined, children: [
      const Text('这一项不是看抽象类别，而是直接列出行为事实，方便你清楚看到自己到底做过什么。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
      const SizedBox(height: 10),
      for (final r in sorted.take(20)) _BehaviorFactLine(record: r),
      if (sorted.length > 20) Text('已显示前20条，共 ${sorted.length} 条。可用上方搜索或类别筛选缩小范围。', style: const TextStyle(color: Color(0xFF94A3B8))),
    ]);
  }
}

class _BehaviorFactLine extends StatelessWidget {
  final BehaviorTrackingRecord record;
  const _BehaviorFactLine({required this.record});

  @override
  Widget build(BuildContext context) {
    final duration = record.durationMinutes == null ? '' : ' · ${_formatDuration(record.durationMinutes!)}';
    final category = _timeReviewCategoryOf(record);
    final emotion = record.emotion.trim().isEmpty ? '' : ' · ${record.emotion}${record.emotionIntensity == null ? '' : ' ${record.emotionIntensity}/10'}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_activityLabel(record), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Text('${DateFormat('yyyy-MM-dd').format(record.recordDate)}${record.timeRangeLabel.isEmpty ? '' : ' · ${record.timeRangeLabel}'}$duration · $category$emotion', style: const TextStyle(color: Color(0xFF64748B), height: 1.35)),
        if (record.trigger.trim().isNotEmpty || record.environment.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text([if (record.trigger.trim().isNotEmpty) '触发：${record.trigger}', if (record.environment.trim().isNotEmpty) '环境：${record.environment}'].join('；'), style: const TextStyle(color: Color(0xFF475569), height: 1.35)),
          ),
      ]),
    );
  }
}

class _DailyTimelineCard extends StatelessWidget {
  final List<BehaviorTrackingRecord> records;
  final String periodLabel;
  const _DailyTimelineCard({required this.records, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox.shrink();
    final groups = <String, List<BehaviorTrackingRecord>>{};
    for (final r in records) {
      final key = DateFormat('yyyy-MM-dd').format(r.recordDate);
      groups.putIfAbsent(key, () => []).add(r);
    }
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return _InfoCard(title: '$periodLabel · 按天查看', icon: Icons.calendar_view_day_outlined, children: [
      for (final day in keys.take(31)) ...[
        _DayGroupView(day: day, records: groups[day]!..sort((a, b) => (a.startMinute ?? 9999).compareTo(b.startMinute ?? 9999))),
        const SizedBox(height: 10),
      ],
      if (keys.length > 31) Text('已显示最近31天，共 ${keys.length} 天。可切换到更短时间范围查看完整明细。', style: const TextStyle(color: Color(0xFF94A3B8))),
    ]);
  }
}

class _DayGroupView extends StatelessWidget {
  final String day;
  final List<BehaviorTrackingRecord> records;
  const _DayGroupView({required this.day, required this.records});

  @override
  Widget build(BuildContext context) {
    final minutes = records.fold<int>(0, (s, r) => s + (r.durationMinutes ?? 0));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('$day · ${records.length}条', style: const TextStyle(fontWeight: FontWeight.w900))),
        Text(minutes == 0 ? '无时长' : _formatDuration(minutes), style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      for (final r in records.take(8))
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('· ${r.timeRangeLabel.isEmpty ? '--:--' : r.timeRangeLabel} ${_activityLabel(r)}${r.durationMinutes == null ? '' : '（${_formatDuration(r.durationMinutes!)}）'}', style: const TextStyle(color: Color(0xFF475569), height: 1.35)),
        ),
      if (records.length > 8) Text('还有 ${records.length - 8} 条未显示，可缩短时间范围或搜索查看。', style: const TextStyle(color: Color(0xFF94A3B8))),
    ]);
  }
}

String _activityLabel(BehaviorTrackingRecord r) {
  return r.behavior.trim().ifBlank(r.title.trim().ifBlank(r.projectKey.trim().ifBlank(r.notes.trim().ifBlank(r.templateLabel))));
}

bool _isPlannedRecord(BehaviorTrackingRecord r) {
  final text = '${r.source} ${r.mode} ${r.entryMode} ${r.templateKey} ${r.tags.join(' ')}';
  return text.contains('planned_behavior') || text.contains('preset_confirmation') || text.contains('预设行为') || text.contains('计划行为');
}

bool _isScreenUsageRecord(BehaviorTrackingRecord r) {
  final text = '${r.source} ${r.entryMode} ${r.templateKey} ${r.title} ${r.behavior} ${r.notes} ${r.tags.join(' ')}'.toLowerCase();
  return text.contains('screen_usage') || text.contains('usagestatsmanager') || text.contains('屏幕使用') || text.contains('今日使用 ') || text.contains('使用应用：') || text.contains('使用应用:');
}

bool _isCalendarRecord(BehaviorTrackingRecord r) {
  final text = '${r.source} ${r.entryMode} ${r.templateKey} ${r.title} ${r.behavior} ${r.notes} ${r.tags.join(' ')}'.toLowerCase();
  return text.contains('calendar') || text.contains('系统日历') || text.contains('日历时间块') || text.startsWith('日历：');
}

String _timeReviewCategoryOf(BehaviorTrackingRecord r) {
  if (_isPlannedRecord(r)) return '预设行为';
  if (_isScreenUsageRecord(r)) return '屏幕使用时间';
  if (_isCalendarRecord(r)) return '系统日历时间块';
  final raw = r.category.trim().ifBlank(r.primaryLayer.trim().ifBlank('未分类'));
  if (raw == '待确认') return '待确认导入（需确认）';
  if (raw == '娱乐/社交待确认' || raw == '计划待确认' || raw == '计划时间块待确认') return '待确认导入（需确认）';
  return raw;
}

String _dedupeKeyOf(BehaviorTrackingRecord r) {
  final day = DateFormat('yyyy-MM-dd').format(r.recordDate);
  final label = _activityLabel(r).trim().toLowerCase();
  if (_isScreenUsageRecord(r)) return 'screen:$day:$label';
  if (_isCalendarRecord(r)) return 'calendar:$day:${r.startMinute ?? -1}:${label}';
  return 'record:${r.id ?? r.createdAtMs}:$day:$label';
}

List<BehaviorTrackingRecord> _effectiveTimeRecords(List<BehaviorTrackingRecord> records) {
  final map = <String, BehaviorTrackingRecord>{};
  for (final r in records) {
    final minutes = r.durationMinutes ?? 0;
    if (minutes <= 0) continue;
    final key = _dedupeKeyOf(r);
    final old = map[key];
    if (old == null || minutes > (old.durationMinutes ?? 0) || r.updatedAtMs > old.updatedAtMs) {
      map[key] = r;
    }
  }
  final list = map.values.toList()..sort((a, b) => (b.durationMinutes ?? 0).compareTo(a.durationMinutes ?? 0));
  return list;
}

String _sourceLabelOf(BehaviorTrackingRecord r) {
  if (_isPlannedRecord(r)) return '预设行为';
  if (_isScreenUsageRecord(r)) return '屏幕使用时间';
  if (_isCalendarRecord(r)) return '系统日历';
  if (r.source.trim().isNotEmpty) return r.source.trim();
  return '手动记录';
}

String _formatDuration(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

class _BehaviorRecordEditor extends StatefulWidget {
  final BehaviorTrackingRecord initial;
  final List<String> categories;
  const _BehaviorRecordEditor({required this.initial, required this.categories});

  @override
  State<_BehaviorRecordEditor> createState() => _BehaviorRecordEditorState();
}

class _BehaviorRecordEditorState extends State<_BehaviorRecordEditor> {
  final BehaviorTrackingDao _dao = BehaviorTrackingDao();
  final Map<String, TextEditingController> _c = {};
  late BehaviorTrackingRecord _record;
  late DateTime _date;
  bool _saving = false;
  late List<String> _categories;

  @override
  void initState() {
    super.initState();
    _record = widget.initial;
    _categories = widget.categories.isEmpty ? behaviorCategories : List<String>.from(widget.categories);
    _date = _record.recordDate;
    void put(String k, Object? v) => _c[k] = TextEditingController(text: v?.toString() ?? '');
    put('title', _record.title);
    put('category', _record.category);
    put('tags', _record.tags.join('、'));
    put('start', _record.startMinute == null ? '' : BehaviorTrackingRecord.formatMinute(_record.startMinute));
    put('end', _record.endMinute == null ? '' : BehaviorTrackingRecord.formatMinute(_record.endMinute));
    put('project', _record.projectKey);
    put('focus', _record.focusScore);
    put('behavior', _record.behavior);
    put('planned', _record.plannedValue);
    put('actual', _record.actualValue);
    put('unit', _record.unit);
    put('state', _record.completionState);
    put('reason', _record.reason);
    put('trigger', _record.trigger);
    put('emotion', _record.emotion);
    put('emotion2', _record.emotionSecondary);
    put('intensity', _record.emotionIntensity);
    put('control', _record.perceivedControl);
    put('automatic', _record.automaticThought.ifBlank(_record.cognition));
    put('belief', _record.beliefStrength);
    put('reaction', _record.reaction);
    put('short', _record.shortTermResult);
    put('long', _record.longTermImpact);
    put('benefit', _record.benefitScore);
    put('regret', _record.regretScore);
    put('alignment', _record.goalAlignment);
    put('environment', _record.environment);
    put('location', _record.locationType);
    put('people', _record.peopleContext);
    put('phone', _record.phoneDistance);
    put('noise', _record.noiseLevel);
    put('clutter', _record.workspaceClutter);
    put('cues', _record.cueTags.join('、'));
    put('body', _record.bodyState);
    put('sleep', _record.sleep);
    put('sleepDuration', _record.sleepDurationMin);
    put('sleepQuality', _record.sleepQuality);
    put('energyMorning', _record.energyMorning);
    put('steps', _record.steps);
    put('exercise', _record.exerciseMin);
    put('important', _record.importantBehaviors);
    put('waste', _record.timeWaste);
    put('mood', _record.mood);
    put('notes', _record.notes);
  }

  TextEditingController c(String key) => _c[key]!;

  @override
  void dispose() {
    for (final v in _c.values) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _date);
    if (picked != null) setState(() => _date = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickMinute(String key) async {
    final now = TimeOfDay.now();
    final current = _parseMinute(c(key).text) ?? now.hour * 60 + now.minute;
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60));
    if (picked != null) c(key).text = BehaviorTrackingRecord.formatMinute(picked.hour * 60 + picked.minute);
  }

  int? _parseInt(String v) => int.tryParse(v.trim());
  double? _parseDouble(String v) => double.tryParse(v.trim());
  List<String> _split(String raw) => raw.split(RegExp(r'[、,，|\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  int? _parseMinute(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final parts = t.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) return h * 60 + m;
    }
    final asInt = int.tryParse(t);
    if (asInt != null && asInt >= 0 && asInt < 24 * 60) return asInt;
    return null;
  }


  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增自定义类别'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: '类别名称', hintText: '例如：写作、通勤、家务')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    controller.dispose();
    final clean = name?.trim();
    if (clean == null || clean.isEmpty) return;
    await _dao.saveCategory(clean);
    setState(() {
      if (!_categories.contains(clean)) _categories.add(clean);
      c('category').text = clean;
    });
  }

  Future<void> _save() async {
    final chosenCategory = c('category').text.trim();
    if (chosenCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('类别是必选项，请选择或新增一个类别。')));
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = _record.copyWith(
        recordDateMs: DateTime(_date.year, _date.month, _date.day).millisecondsSinceEpoch,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        title: c('title').text.trim(),
        category: chosenCategory,
        tags: _split(c('tags').text),
        startMinute: _parseMinute(c('start').text),
        endMinute: _parseMinute(c('end').text),
        clearStartMinute: _parseMinute(c('start').text) == null,
        clearEndMinute: _parseMinute(c('end').text) == null,
        projectKey: c('project').text.trim(),
        focusScore: _parseInt(c('focus').text),
        clearFocusScore: _parseInt(c('focus').text) == null,
        behavior: c('behavior').text.trim(),
        plannedValue: _parseDouble(c('planned').text),
        actualValue: _parseDouble(c('actual').text),
        clearPlannedValue: _parseDouble(c('planned').text) == null,
        clearActualValue: _parseDouble(c('actual').text) == null,
        unit: c('unit').text.trim(),
        completionState: c('state').text.trim(),
        reason: c('reason').text.trim(),
        trigger: c('trigger').text.trim(),
        emotion: c('emotion').text.trim(),
        emotionSecondary: c('emotion2').text.trim(),
        emotionIntensity: _parseInt(c('intensity').text),
        clearEmotionIntensity: _parseInt(c('intensity').text) == null,
        perceivedControl: _parseInt(c('control').text),
        clearPerceivedControl: _parseInt(c('control').text) == null,
        automaticThought: c('automatic').text.trim(),
        cognition: c('automatic').text.trim(),
        beliefStrength: _parseInt(c('belief').text),
        clearBeliefStrength: _parseInt(c('belief').text) == null,
        reaction: c('reaction').text.trim(),
        shortTermResult: c('short').text.trim(),
        longTermImpact: c('long').text.trim(),
        benefitScore: _parseInt(c('benefit').text),
        regretScore: _parseInt(c('regret').text),
        clearBenefitScore: _parseInt(c('benefit').text) == null,
        clearRegretScore: _parseInt(c('regret').text) == null,
        goalAlignment: c('alignment').text.trim(),
        environment: c('environment').text.trim(),
        locationType: c('location').text.trim(),
        peopleContext: c('people').text.trim(),
        phoneDistance: c('phone').text.trim(),
        noiseLevel: _parseInt(c('noise').text),
        workspaceClutter: _parseInt(c('clutter').text),
        clearNoiseLevel: _parseInt(c('noise').text) == null,
        clearWorkspaceClutter: _parseInt(c('clutter').text) == null,
        cueTags: _split(c('cues').text),
        bodyState: c('body').text.trim(),
        sleep: c('sleep').text.trim(),
        sleepDurationMin: _parseInt(c('sleepDuration').text),
        sleepQuality: _parseInt(c('sleepQuality').text),
        energyMorning: _parseInt(c('energyMorning').text),
        steps: _parseInt(c('steps').text),
        exerciseMin: _parseInt(c('exercise').text),
        clearSleepDurationMin: _parseInt(c('sleepDuration').text) == null,
        clearSleepQuality: _parseInt(c('sleepQuality').text) == null,
        clearEnergyMorning: _parseInt(c('energyMorning').text) == null,
        clearSteps: _parseInt(c('steps').text) == null,
        clearExerciseMin: _parseInt(c('exercise').text) == null,
        importantBehaviors: c('important').text.trim(),
        timeWaste: c('waste').text.trim(),
        mood: c('mood').text.trim(),
        notes: c('notes').text.trim(),
      );
      await _dao.save(saved);
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = _template(_record.templateKey);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(template.name, style: const TextStyle(fontWeight: FontWeight.w900)), backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 110), children: [
        _InfoCard(title: '这条记录', icon: Icons.edit_note_outlined, children: [
          Row(children: [
            Expanded(child: Text(DateFormat('yyyy-MM-dd').format(_date), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            TextButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_month_outlined), label: const Text('改日期')),
          ]),
          const SizedBox(height: 8),
          _Field(controller: c('title'), label: '标题', hint: '例如：晚上刷短视频 / 上午深度学习'),
          const SizedBox(height: 10),
          _Choice(label: '类别（必选）', value: c('category').text, emptyLabel: '选择类别', options: _categories, onChanged: (v) => setState(() => c('category').text = v)),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _addCategory, icon: const Icon(Icons.add), label: const Text('新增类别'))),
          const SizedBox(height: 10),
          _Field(controller: c('tags'), label: '标签', hint: '例如：睡前、通勤、英语、运动'),
        ]),
        if (_record.entryMode == 'notification_layer_selector') ...[_gap(), _notificationLayerSelectorSection()],
        if (_show('time_block') || _record.primaryLayer == '时间层面') ...[_gap(), _timeSection()],
        if (_show('quick_capture') || _show('full_observation') || _record.primaryLayer == '行为层面') ...[_gap(), _behaviorSection()],
        if (_show('tbr')) ...[_gap(), _chainSection()],
        if (_show('emotion_thought') || _show('full_observation') || _record.primaryLayer == '情绪层面' || _record.primaryLayer == '认知层面') ...[_gap(), _emotionCognitionSection()],
        if (_show('full_observation') || _record.primaryLayer == '结果层面') ...[_gap(), _resultSection()],
        if (_show('full_observation') || _record.primaryLayer == '环境层面') ...[_gap(), _environmentSection()],
        if (_show('body_snapshot') || _show('full_observation') || _record.primaryLayer == '身体状态') ...[_gap(), _bodySection()],
        if (_show('daily_six')) ...[_gap(), _dailySummarySection()],
        _gap(),
        _InfoCard(title: '备注', icon: Icons.notes_outlined, children: [
          _Field(controller: c('notes'), label: '补充事实', hint: '任何不想丢掉的观察线索。尽量写事实，不写自我评价。', maxLines: 4),
        ]),
      ]),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
          child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? '保存中...' : '保存记录')),
        ),
      ),
    );
  }

  bool _show(String key) => _record.templateKey == key;
  Widget _gap() => const SizedBox(height: 12);

  Widget _notificationLayerSelectorSection() {
    final current = _behaviorLayerByNameOrMode(_record.primaryLayer) ?? _behaviorLayerByNameOrMode(_record.templateKey) ?? behaviorLayerInfos.first;
    return _InfoCard(title: '选择观察层面', icon: Icons.expand_circle_down_outlined, children: [
      const Text('从通知进入后，先在这里选择一个观察层面。选择后，下方只显示该层对应字段，不再把七层表单一次性全部展开。', style: TextStyle(color: Color(0xFF64748B), height: 1.45)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: current.name,
        decoration: const InputDecoration(labelText: '观察层面', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)))),
        items: behaviorLayerInfos.map((e) => DropdownMenuItem(value: e.name, child: Text(e.name))).toList(),
        onChanged: (value) {
          final next = _behaviorLayerByNameOrMode(value);
          if (next == null) return;
          setState(() {
            _record = _record.copyWith(
              mode: next.mode,
              templateKey: next.mode,
              entryMode: 'notification_layer_selector',
              primaryLayer: next.name,
              methodName: '通知层面选择记录',
              tags: {..._split(c('tags').text), '行为观察', '通知提醒', next.name}.toList(),
            );
            if (c('title').text.trim().isEmpty || c('title').text.startsWith('通知记录 ·')) {
              c('title').text = '通知记录 · ${next.name.replaceAll('层面', '')}';
            }
            c('tags').text = _record.tags.join('、');
          });
        },
      ),
      const SizedBox(height: 10),
      Text('当前显示：${current.name}字段 · ${current.fields.join(' / ')}', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w800, height: 1.45)),
    ]);
  }

  Widget _timeSection() => _InfoCard(title: '时间层面', icon: Icons.schedule_outlined, children: [
        Row(children: [
          Expanded(child: _TimeField(controller: c('start'), label: '开始', onPick: () => _pickMinute('start'))),
          const SizedBox(width: 10),
          Expanded(child: _TimeField(controller: c('end'), label: '结束', onPick: () => _pickMinute('end'))),
        ]),
        const SizedBox(height: 10),
        _Field(controller: c('project'), label: '项目/场景', hint: '例如：英语复习 / 通勤 / 短视频'),
        const SizedBox(height: 10),
        _Field(controller: c('focus'), label: '专注度1-5（可选）', hint: '4', keyboardType: TextInputType.number),
      ]);

  Widget _behaviorSection() => _InfoCard(title: '行为层面', icon: Icons.directions_walk_outlined, children: [
        _Field(controller: c('behavior'), label: '我具体做了什么', hint: '例如：原计划复习1小时，实际刷短视频3小时', maxLines: 3),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Field(controller: c('planned'), label: '计划值', hint: '60', keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _Field(controller: c('actual'), label: '实际值', hint: '180', keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _Field(controller: c('unit'), label: '单位', hint: '分钟')),
        ]),
        const SizedBox(height: 10),
        _Field(controller: c('state'), label: '完成状态/行为状态', hint: '完成 / 部分完成 / 跳过 / 未适用'),
        const SizedBox(height: 10),
        _Field(controller: c('reason'), label: '当时为什么这样做', hint: '例如：任务太难、无聊、疲惫、想奖励自己', maxLines: 2),
      ]);

  Widget _chainSection() => _InfoCard(title: '触发—行为—结果', icon: Icons.account_tree_outlined, children: [
        _Field(controller: c('trigger'), label: '触发/情境', hint: '例如：晚上一个人无聊 / 被批评 / 任务太大', maxLines: 2),
        const SizedBox(height: 10),
        _Field(controller: c('behavior'), label: '行为', hint: '例如：刷短视频 2 小时', maxLines: 2),
        const SizedBox(height: 10),
        _Field(controller: c('short'), label: '短期结果', hint: '例如：当下放松、暂时逃避压力', maxLines: 2),
        const SizedBox(height: 10),
        _Field(controller: c('long'), label: '较长期影响', hint: '例如：第二天疲惫、进度延后、完成后更踏实', maxLines: 2),
      ]);

  Widget _emotionCognitionSection() => _InfoCard(title: '情绪与认知层面', icon: Icons.psychology_alt_outlined, children: [
        _Field(controller: c('trigger'), label: '事件/触发点', hint: '例如：被批评 / 任务太难 / 睡前无聊', maxLines: 2),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Field(controller: c('emotion'), label: '主情绪', hint: '焦虑/委屈/生气')),
          const SizedBox(width: 10),
          Expanded(child: _Field(controller: c('intensity'), label: '强度0-10', hint: '8', keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 10),
        _Field(controller: c('automatic'), label: '当时脑中第一句话', hint: '例如：反正做不完 / 我肯定学不会 / 明天再说', maxLines: 3),
        const SizedBox(height: 10),
        _Field(controller: c('reaction'), label: '后续反应/行为', hint: '例如：回避、刷手机、继续做、求助', maxLines: 2),
      ]);

  Widget _resultSection() => _InfoCard(title: '结果层面', icon: Icons.fact_check_outlined, children: [
        _Field(controller: c('short'), label: '短期结果', hint: '例如：当下放松、完成后满足、暂时逃避压力', maxLines: 2),
        const SizedBox(height: 10),
        _Field(controller: c('long'), label: '较长期影响', hint: '例如：第二天疲惫 / 截止前更焦虑 / 精力更好', maxLines: 2),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Field(controller: c('benefit'), label: '收益-5到5', hint: '2', keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _Field(controller: c('regret'), label: '后悔0-10', hint: '6', keyboardType: TextInputType.number)),
        ]),
      ]);

  Widget _environmentSection() => _InfoCard(title: '环境层面', icon: Icons.place_outlined, children: [
        _Field(controller: c('environment'), label: '环境因素', hint: '例如：手机放手边、房间杂乱、身边人熬夜', maxLines: 3),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Field(controller: c('location'), label: '地点类型', hint: '家/公司/路上')),
          const SizedBox(width: 10),
          Expanded(child: _Field(controller: c('people'), label: '在场人', hint: '独处/同事/家人')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Field(controller: c('phone'), label: '手机距离', hint: '手边/桌上')),
          const SizedBox(width: 10),
          Expanded(child: _Field(controller: c('noise'), label: '噪音1-5', hint: '3', keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _Field(controller: c('clutter'), label: '杂乱1-5', hint: '4', keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 10),
        _Field(controller: c('cues'), label: '环境线索标签', hint: '例如：睡前、床上、手机、安静'),
      ]);

  Widget _bodySection() => _InfoCard(title: '身体状态层面', icon: Icons.bedtime_outlined, children: [
        _Field(controller: c('body'), label: '身体状态', hint: '例如：睡眠不足、头痛、上午精力低', maxLines: 3),
        const SizedBox(height: 10),
        _Field(controller: c('sleep'), label: '睡眠', hint: '例如：1:00–8:00，质量一般'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Field(controller: c('sleepDuration'), label: '睡眠分钟', hint: '420', keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _Field(controller: c('sleepQuality'), label: '睡眠质量1-5', hint: '3', keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Field(controller: c('energyMorning'), label: '精力1-5', hint: '2', keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _Field(controller: c('steps'), label: '步数', hint: '8000', keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _Field(controller: c('exercise'), label: '运动分钟', hint: '20', keyboardType: TextInputType.number)),
        ]),
      ]);

  Widget _dailySummarySection() => _InfoCard(title: '每日六项观察', icon: Icons.today_outlined, children: [
        _Field(controller: c('sleep'), label: '睡眠', hint: '几点睡，几点起，质量如何'),
        const SizedBox(height: 10),
        _Field(controller: c('important'), label: '重要行为1–3件', hint: '今天最重要的行为事实', maxLines: 3),
        const SizedBox(height: 10),
        _Field(controller: c('waste'), label: '明显时间流向', hint: '哪段时间最值得记录？不必评价好坏', maxLines: 2),
        const SizedBox(height: 10),
        _Field(controller: c('mood'), label: '主要情绪', hint: '今天主要情绪是什么'),
        const SizedBox(height: 10),
        _Field(controller: c('trigger'), label: '主要触发点/情境', hint: '什么情境最影响今天的行为？', maxLines: 2),
        const SizedBox(height: 10),
        _Field(controller: c('notes'), label: '今日观察摘要', hint: '今天我观察到的一个模式或事实', maxLines: 3),
      ]);
}

BehaviorLayerInfo? _behaviorLayerByNameOrMode(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  for (final layer in behaviorLayerInfos) {
    if (layer.name == value || layer.mode == value) return layer;
  }
  if (value == '身体状态层面') {
    for (final layer in behaviorLayerInfos) {
      if (layer.name == '身体状态') return layer;
    }
  }
  return null;
}

BehaviorTemplateInfo _template(String key) {
  final matches = behaviorTemplateInfos.where((e) => e.key == key).toList();
  if (matches.isNotEmpty) return matches.first;
  final layer = behaviorLayerInfos.where((e) => e.mode == key).toList();
  if (layer.isNotEmpty) {
    final l = layer.first;
    return BehaviorTemplateInfo(
      key: key,
      name: '${l.name}记录',
      method: '七层观察',
      entryMode: 'layer_capture',
      primaryLayer: l.name,
      description: l.subtitle,
      whenToUse: '只想从“${l.name}”这一角度补充观察时。',
      prompts: l.fields,
    );
  }
  return behaviorTemplateInfos.first;
}

class _HeroCard extends StatelessWidget {
  final int todayCount;
  final String todayTime;
  final VoidCallback onQuick;
  final VoidCallback onTime;
  final VoidCallback onDaily;
  const _HeroCard({required this.todayCount, required this.todayTime, required this.onQuick, required this.onTime, required this.onDaily});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF2563EB), Color(0xFF06B6D4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x22111827), blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('看见自己的行为轨迹', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('只做记录与观察：时间、行为、情绪、认知、结果、环境、身体状态。', style: TextStyle(color: Color(0xFFE0F2FE), height: 1.4)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _HeroMetric(label: '今日记录', value: '$todayCount 条')),
          const SizedBox(width: 10),
          Expanded(child: _HeroMetric(label: '已标记时间', value: todayTime)),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _HeroAction(label: '秒记', icon: Icons.flash_on_outlined, onTap: onQuick),
          _HeroAction(label: '时间块', icon: Icons.schedule_outlined, onTap: onTime),
          _HeroAction(label: '每日摘要', icon: Icons.today_outlined, onTap: onDaily),
        ]),
      ]),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  const _HeroMetric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.16))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Color(0xFFBAE6FD), fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _HeroAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _HeroAction({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: const Color(0xFF2563EB)), const SizedBox(width: 6), Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A)))]),
        ),
      );
}

class _QuickAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickAction(this.title, this.subtitle, this.icon, this.onTap);
}

class _QuickGrid extends StatelessWidget {
  final List<_QuickAction> items;
  const _QuickGrid({required this.items});
  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.55),
        itemBuilder: (_, i) {
          final item = items[i];
          return InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(item.icon, color: const Color(0xFF2563EB)),
                const Spacer(),
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(item.subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.25)),
              ]),
            ),
          );
        },
      );
}

class _LayerCard extends StatelessWidget {
  final BehaviorLayerInfo layer;
  final VoidCallback onTap;
  const _LayerCard({required this.layer, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.lens_blur_outlined, color: Color(0xFF2563EB))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(layer.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), Text(layer.subtitle, style: const TextStyle(color: Color(0xFF64748B)))])),
              const Icon(Icons.chevron_right),
            ]),
            const SizedBox(height: 10),
            Text(layer.humanFit, style: const TextStyle(color: Color(0xFF475569), height: 1.45)),
            const SizedBox(height: 8),
            Text('示例：${layer.example}', style: const TextStyle(color: Color(0xFF0F766E), height: 1.45, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}


class _PendingImportCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _PendingImportCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFFDE68A))),
          child: Row(children: [
            const Icon(Icons.fact_check_outlined, color: Color(0xFFD97706)),
            const SizedBox(width: 10),
            Expanded(child: Text('有 $count 条自动导入数据需要你确认。这里的“待确认”不是一种行为类别，而是屏幕使用/日历等外部数据还没经过你确认。点击查看明细，可确认写入或忽略。', style: const TextStyle(color: Color(0xFF92400E), height: 1.4, fontWeight: FontWeight.w700))),
            const Icon(Icons.chevron_right, color: Color(0xFFD97706)),
          ]),
        ),
      );
}

class _SummaryGrid extends StatelessWidget {
  final List<BehaviorTrackingRecord> records;
  final List<BehaviorTrackingRecord> recent7;
  final List<BehaviorTrackingRecord> recent30;
  const _SummaryGrid({required this.records, required this.recent7, required this.recent30});

  @override
  Widget build(BuildContext context) {
    final minutes7 = recent7.fold<int>(0, (s, r) => s + (r.durationMinutes ?? 0));
    final days30 = recent30.map((r) => DateFormat('yyyy-MM-dd').format(r.recordDate)).toSet().length;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.75,
      children: [
        _StatBox(label: '总记录', value: '${records.length}条'),
        _StatBox(label: '近7天', value: '${recent7.length}条'),
        _StatBox(label: '近7天时间', value: '${minutes7 ~/ 60}h${minutes7 % 60}m'),
        _StatBox(label: '近30天有记录', value: '$days30天'),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF0F172A))),
        ]),
      );
}

class _RecordTile extends StatelessWidget {
  final BehaviorTrackingRecord record;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  const _RecordTile({required this.record, required this.onTap, this.onDelete});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE2E8F0))),
        child: ListTile(
          onTap: onTap,
          title: Text(record.title.ifBlank(record.templateLabel), style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text('${DateFormat('MM/dd').format(record.recordDate)}  ${record.category.ifBlank(record.primaryLayer)}${record.timeRangeLabel.isEmpty ? '' : '  ${record.timeRangeLabel}'}\n${record.oneLineSummary}', maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
          isThreeLine: true,
          trailing: onDelete == null ? const Icon(Icons.chevron_right) : IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.icon, required this.children});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: const Color(0xFF2563EB)), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 12),
          ...children,
        ]),
      );
}

class _Line extends StatelessWidget {
  final String text;
  const _Line(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• ', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w900)),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF475569), height: 1.45))),
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String trailing;
  const _SectionTitle(this.title, {required this.trailing});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)))),
        Text(trailing, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
      ]);
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Text(text, style: const TextStyle(color: Color(0xFF64748B), height: 1.45)),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  const _Field({required this.controller, required this.label, required this.hint, this.maxLines = 1, this.keyboardType});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        ),
      );
}

class _FieldLite extends StatelessWidget {
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  const _FieldLite({required this.label, required this.hint, required this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        ),
      );
}

class _TimeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback onPick;
  const _TimeField({required this.controller, required this.label, required this.onPick});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        readOnly: true,
        onTap: onPick,
        decoration: InputDecoration(
          labelText: label,
          hintText: '选择时间',
          suffixIcon: IconButton(icon: const Icon(Icons.access_time), onPressed: onPick),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        ),
      );
}

class _Choice extends StatelessWidget {
  final String label;
  final String value;
  final String emptyLabel;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _Choice({required this.label, required this.value, this.emptyLabel = '请选择', required this.options, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final current = options.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      value: current,
      items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: emptyLabel,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      ),
    );
  }
}

extension _BehaviorStringExt on String {
  String ifBlank(String fallback) => trim().isEmpty ? fallback : trim();
}
