import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'diary_dao.dart';
import 'entry_editor_page.dart';
import 'entry_editor_pager.dart';
import 'entry_reader_page.dart';
import 'mood_trend_page.dart';
import '../data/db.dart';
import 'diary_theme.dart';

class NotebookPage extends StatefulWidget {
  final Notebook notebook;
  const NotebookPage({super.key, required this.notebook});

  @override
  State<NotebookPage> createState() => _NotebookPageState();
}

class _NotebookPageState extends State<NotebookPage> {
  String? _bgPath; double _bgOpacity = 0.25;
  final _dao = DiaryDao();
  final _fmt = DateFormat('yyyy-MM-dd HH:mm');
  final _searchCtrl = TextEditingController();

  // Precise scroll-to-item support (center alignment) when returning from
  // editor pages.
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  int? _highlightEntryId;
  Timer? _highlightTimer;

  List<DiaryEntry> _items = [];
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _totalCount = 0;

  String? _keyword;
  int? _tagId;
  String? _tagName;
  DateTime? _day;

  @override
  void initState() {
    super.initState();
    _dao.ensureSchema();
    _bootstrapBg();
    _loadFirst();
    _refreshCount();

    // Lazy-load more items when the user scrolls near the end.
    _itemPositionsListener.itemPositions.addListener(() {
      if (!_hasMore || _loadingMore || _loading) return;
      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isEmpty) return;
      final maxIndex = positions
          .where((p) => p.itemTrailingEdge > 0)
          .map((p) => p.index)
          .fold<int>(0, (a, b) => a > b ? a : b);
      if (maxIndex >= _items.length - 5) {
        _loadMore();
      }
    });
  }

  Future<void> _bootstrapBg() async {
    try {
      await _loadBg();
    } catch (_) {
      // ignore
    }
  }


  @override
  void dispose() {
    _highlightTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _cursor = null;
      _hasMore = true;
      _items = [];
    });
    final res = await _dao.listEntries(
      notebookId: widget.notebook.id,
      limit: 50,
      cursor: null,
      keyword: _keyword,
      day: _day,
      tagId: _tagId,
    );
    setState(() {
      _items = res.items;
      _cursor = res.nextCursor;
      _hasMore = res.nextCursor != null;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    final res = await _dao.listEntries(
      notebookId: widget.notebook.id,
      limit: 50,
      cursor: _cursor,
      keyword: _keyword,
      day: _day,
      tagId: _tagId,
    );
    setState(() {
      _items.addAll(res.items);
      _cursor = res.nextCursor;
      _hasMore = res.nextCursor != null;
      _loadingMore = false;
    });
  }

  void _setHighlightEntry(int entryId) {
    _highlightTimer?.cancel();
    if (mounted) {
      setState(() => _highlightEntryId = entryId);
    } else {
      _highlightEntryId = entryId;
    }
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _highlightEntryId = null);
    });
  }

  /// Reload list data (paging as needed) and precisely scroll the entry to the
  /// center of the viewport, then highlight it.
  Future<void> _reloadAndFocusEntry(int entryId) async {
    await _loadFirst();

    int idx = _items.indexWhere((e) => e.id == entryId);
    int guard = 0;
    while (idx < 0 && _hasMore && guard < 30) {
      guard++;
      await _loadMore();
      idx = _items.indexWhere((e) => e.id == entryId);
    }

    if (idx >= 0) {
      _setHighlightEntry(entryId);
      // Wait one frame to ensure list layout is ready.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: idx,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  
  Future<void> _refreshCount() async {
    final c = await _dao.countEntries(widget.notebook.id);
    if (mounted) setState(() { _totalCount = c; });
  }
  Future<void> _newEntry() async {
    final id = await Navigator.push<int?>(
      context,
      MaterialPageRoute(builder: (_) => EntryEditorPage(notebookId: widget.notebook.id)),
    );
    if (id != null) {
      await _reloadAndFocusEntry(id);
      await _refreshCount();
      return;
    }
    await _refreshCount();
  }

  Future<void> _openEntry(DiaryEntry e) async {
    final id = await Navigator.push<int?>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditorPagerPage(
          notebookId: widget.notebook.id,
          initialEntryId: e.id,
        ),
      ),
    );
    final focusId = id ?? e.id;
    await _reloadAndFocusEntry(focusId);
    await _refreshCount();
  }


  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day ?? now,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(now.year + 1),
    );
    setState(() => _day = picked);
    await _loadFirst();
    
    _refreshCount();
  }

  Future<void> _filterByTag() async {
    final tags = await _dao.listTags();
    final res = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          children: [
            ListTile(
              leading: Icon(_tagId == null ? Icons.check_circle : Icons.circle_outlined),
              title: const Text('全部'),
              onTap: () => Navigator.pop(context, {'id': null, 'name': null}),
            ),
            const Divider(height: 1),
            ...tags.map(
              (t) => ListTile(
                leading: Icon(_tagId == t.id ? Icons.check_circle : Icons.circle_outlined),
                title: Text(t.name),
                onTap: () => Navigator.pop(context, {'id': t.id, 'name': t.name}),
              ),
            ),
          ],
        ),
      ),
    );
    if (res == null) return;
    setState(() {
      _tagId = res['id'] as int?;
      _tagName = res['name'] as String?;
    });
    await _loadFirst();
    
    _refreshCount();
  }

  Future<void> _exportNotebook() async {
    final data = await _dao.exportNotebook(widget.notebook.id);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;

    final safeName = widget.notebook.name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\u4e00-\u9fa5]'), '_');
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('$dir/diary_${safeName}_$stamp.json');
    await file.writeAsString(jsonStr, flush: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导出：${file.path}')));
  }

  Future<void> _importNotebook() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['json']);
    if (res == null || res.files.isEmpty) return;
    final path = res.files.single.path;
    if (path == null) return;

    final txt = await File(path).readAsString();
    final obj = jsonDecode(txt);
    if (obj is! Map<String, dynamic>) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入失败：文件格式不正确')));
      return;
    }

    await _dao.importToNotebook(widget.notebook.id, obj);
    await _dao.touchNotebook(widget.notebook.id);
    await _loadFirst();
    
    _refreshCount();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入完成')));
  }

  void _openMoodTrend() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MoodTrendPage()));
  }

  
  Future<void> _loadBg() async {
    try {
      final cfg = DiaryTheme.current;
      _bgPath = cfg.imagePath;
      _bgOpacity = cfg.opacity;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Widget _bgWrap(Widget child) {
    final bg = _bgPath;
    if (bg == null || bg.isEmpty) return child;
    final f = File(bg);
    if (!f.existsSync()) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        // White base: when the background becomes more "transparent", we
        // should reveal white instead of the default black canvas.
        const ColoredBox(color: Colors.white),
        Opacity(
          opacity: (1.0 - _bgOpacity).clamp(0.0, 1.0),
          child: Image.file(f, fit: BoxFit.cover),
        ),
        child,
      ],
    );
  }

  
  Widget? _leadingForEntry(DiaryEntry e) {
    try {
      final img = RegExp(r'^\[图片\]\s*(.+)$', multiLine: true).firstMatch(e.content);
      if (img != null) {
        final p = img.group(1)!;
        final f = File(p);
        if (f.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(f, width: 56, height: 56, fit: BoxFit.cover),
          );
        }
      }
      final au = RegExp(r'^\[语音\]\s*(.+)$', multiLine: true).firstMatch(e.content);
      if (au != null) {
        // For audio attachments, we intentionally do not show a microphone icon in
        // the notebook list.  Leaving this block empty ensures no icon is
        // returned and the list item simply has no leading widget.
      }
    } catch (_) {}
    return null;
  }
@override
  Widget build(BuildContext context) {
    final bool _hasDiaryBgImage = (_bgPath != null && _bgPath!.isNotEmpty);
    // 系统底部三键区域颜色：默认全局白色；若配置了背景图则透明（配合 edge-to-edge 让背景图铺满）。
    // 用户要求：日记相关页面底部三键区域不出现额外白边/空白。
    // 启用 edge-to-edge：systemNavigationBar 设为透明，并让 body extend 到底部。
    final Color _navBarColor = Colors.transparent;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(systemNavigationBarColor: _navBarColor,
            systemNavigationBarDividerColor: _navBarColor,
            systemNavigationBarContrastEnforced: false,
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarIconBrightness: Brightness.dark),
      child: WillPopScope(
        onWillPop: () async {
          Navigator.pop(context, widget.notebook.id);
          return false;
        },
        child: _bgWrap(Scaffold(
      // 日记列表页：
      // - 无背景图：整页纯白
      // - 有背景图：Scaffold 透明，让背景图全屏铺底
      backgroundColor: _hasDiaryBgImage ? Colors.transparent : Colors.white,
      // Edge-to-edge：让内容/背景延伸到系统三键区域，避免底部白边。
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, widget.notebook.id),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // Ensure Android status bar icons (battery/time) are visible.
        // Some diary pages use transparent app bars + extendBodyBehindAppBar,
        // which can cause the framework to choose a light overlay style.
        systemOverlayStyle: const SystemUiOverlayStyle(statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light),
        title: Row(children:[Text(widget.notebook.name), const SizedBox(width:8), Text('(${_totalCount})', style: const TextStyle(fontSize:14))]),
        actions: [
          IconButton(tooltip: '标签筛选', onPressed: _filterByTag, icon: const Icon(Icons.label_outline)),
          IconButton(tooltip: '日期定位', onPressed: _pickDay, icon: const Icon(Icons.calendar_month_outlined)),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'export') await _exportNotebook();
              if (v == 'import') await _importNotebook();
              if (v == 'mood') _openMoodTrend();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('导出（JSON）')),
              PopupMenuItem(value: 'import', child: Text('导入（JSON）')),
              PopupMenuItem(value: 'mood', child: Text('心情趋势')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _newEntry, child: const Icon(Icons.create)),
      // Diary list page: do not reserve extra blank space for Android
      // bottom navigation keys area.
      body: SafeArea(bottom: false, child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索当前日记本',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (v) {
                _keyword = v.trim().isEmpty ? null : v.trim();
                _loadFirst();
    
    _refreshCount();
              },
            ),
          ),
          if (_tagId != null || _day != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_tagId != null)
                    Chip(
                      label: Text('标签: ${_tagName ?? _tagId}'),
                      onDeleted: () async {
                        setState(() {
                          _tagId = null;
                          _tagName = null;
                        });
                        await _loadFirst();
    
    _refreshCount();
                      },
                    ),
                  if (_day != null)
                    Chip(
                      label: Text('日期: ${DateFormat('yyyy-MM-dd').format(_day!)}'),
                      onDeleted: () async {
                        setState(() => _day = null);
                        await _loadFirst();
    
    _refreshCount();
                      },
                    ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadFirst,
                    child: ScrollablePositionedList.builder(
                      itemScrollController: _itemScrollController,
                      itemPositionsListener: _itemPositionsListener,
                      itemCount: _items.length + 1,
                      itemBuilder: (_, i) {
                        if (i == _items.length) {
                          if (_loadingMore) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (!_hasMore) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: Text('已经到底了')),
                            );
                          }
                          return const SizedBox(height: 56);
                        }
                        final e = _items[i];
                        final bool highlighted = e.id == _highlightEntryId;
                        return Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              color: highlighted
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.18)
                                  : Colors.transparent,
                              child: ListTile(
                                leading: _leadingForEntry(e),
                                title: Text(e.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(_fmt.format(DateTime.fromMillisecondsSinceEpoch(e.entryTime))),
                                onTap: () => _openEntry(e),
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      )),
    )),
      ),
    );
  }
}
