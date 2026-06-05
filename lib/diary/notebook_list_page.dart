import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'diary_dao.dart';
import 'notebook_page.dart';

class DiaryNotebookListPage extends StatefulWidget {
  const DiaryNotebookListPage({super.key});

  @override
  State<DiaryNotebookListPage> createState() => _DiaryNotebookListPageState();
}

class _DiaryNotebookListPageState extends State<DiaryNotebookListPage> {
  final _dao = DiaryDao();
  bool _loading = true;
  List<Notebook> _items = [];
  String? _error;

  // Precise scroll-to-item support (center alignment) when returning from a
  // notebook page.
  final ItemScrollController _itemScrollController = ItemScrollController();
  int? _highlightNotebookId;
  Timer? _highlightTimer;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _dao.ensureSchema();
      final list = await _dao.listNotebooks();
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _create() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新增日记本'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '输入日记本名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('保存')),
        ],
      ),
    );
    if ((name ?? '').trim().isEmpty) return;
    await _dao.createNotebook(name!.trim());
    await _init();
  }

  void _setHighlightNotebook(int notebookId) {
    _highlightTimer?.cancel();
    if (mounted) {
      setState(() => _highlightNotebookId = notebookId);
    } else {
      _highlightNotebookId = notebookId;
    }
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _highlightNotebookId = null);
    });
  }

  Future<void> _focusNotebook(int notebookId) async {
    // Ensure list is loaded.
    if (_loading) {
      await _init();
    }
    final idx = _items.indexWhere((n) => n.id == notebookId);
    if (idx < 0) return;

    _setHighlightNotebook(notebookId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_itemScrollController.isAttached) {
        _itemScrollController.scrollTo(
          index: idx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _openNotebook(Notebook n) async {
    final returnedNotebookId = await Navigator.push<int?>(
      context,
      MaterialPageRoute(builder: (_) => NotebookPage(notebook: n)),
    );
    // Refresh list in case notebook name/updatedAt changed.
    await _init();
    final focusId = returnedNotebookId ?? n.id;
    await _focusNotebook(focusId);
  }

  @override
  Widget build(BuildContext context) {
    // 用户要求：日记相关页面底部三键区域不出现额外白边/空白。
    // 这里启用 edge-to-edge：systemNavigationBar 设为透明，并让 body extend 到底部。
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: const Text('日记本'),
          // Fix: status bar icons (battery/time) were invisible on some
          // diary pages due to an implicit SystemUiOverlayStyle overriding
          // the global overlay style.
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        floatingActionButton: FloatingActionButton(onPressed: _create, child: const Icon(Icons.add)),
        // User wants no extra blank space above Android system navigation keys.
        body: SafeArea(bottom: false, top: false, child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _init,
                  child: ScrollablePositionedList.builder(
                    itemScrollController: _itemScrollController,
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final n = _items[i];
                      final bool highlighted = n.id == _highlightNotebookId;
                      return Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            color: highlighted
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.18)
                                : Colors.transparent,
                            child: ListTile(
                              title: Text(n.name),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openNotebook(n),
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}
