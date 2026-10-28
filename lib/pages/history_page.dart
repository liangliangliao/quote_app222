import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import '../data/dao.dart';
import '../widgets/quote_history_avatar.dart';
import '../utils/quote_change_bus.dart';
import '../utils/simple_bus.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.loadQuotes});
  final Future<List<Map<String, dynamic>>> Function({
    required int limit, required int offset, String? q,
  })? loadQuotes;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with WidgetsBindingObserver {
        
  Future<String?> _saveAvatarTemp(File file) async {
    final docs = await getApplicationDocumentsDirectory();
    final ext = p.extension(file.path);
    final dst = File(p.join(docs.path, 'avatar_${DateTime.now().millisecondsSinceEpoch}${ext}'));
    await dst.writeAsBytes(await file.readAsBytes());
    return dst.path;
  }

  Future<void> _reload() async {
    await _refresh();
  }

  final _dao = QuoteDao();
  final _scroll = ScrollController();
  String _q = '';
  List<Map<String,dynamic>> _items = [];
  int _offset = 0;
  bool _loading = false;
  bool _done = false;
  bool _refreshing = false;
  bool _refreshAgain = false;
  int _generation = 0;
  Timer? _searchTimer;
  Timer? _changeTimer;
  Timer? _pollTimer;

  Future<List<Map<String, dynamic>>> _query(int limit, int offset, String query) {
    final loader = widget.loadQuotes;
    return loader != null
        ? loader(limit: limit, offset: offset, q: query.isEmpty ? null : query)
        : _dao.latest(limit: limit, offset: offset, q: query.isEmpty ? null : query);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    QuoteChangeBus.changes.addListener(_onQuoteChange);
    SimpleBus.navIndex.addListener(_onNavigation);
    _refresh();
    // Native writers cannot signal a Dart isolate. Check only while this tab is
    // visible, and rebuild only when the loaded rows actually changed.
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (SimpleBus.navIndex.value == 1 &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed)) {
        _checkForNewQuotes();
      }
    });
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 100 && !_loading && !_done) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    QuoteChangeBus.changes.removeListener(_onQuoteChange);
    SimpleBus.navIndex.removeListener(_onNavigation);
    _searchTimer?.cancel();
    _changeTimer?.cancel();
    _pollTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && SimpleBus.navIndex.value == 1) {
      _refresh();
    }
  }

  void _onNavigation() {
    if (SimpleBus.navIndex.value == 1) _refresh();
  }

  void _onQuoteChange() {
    _changeTimer?.cancel();
    _changeTimer = Timer(const Duration(milliseconds: 120), _refresh);
  }

  Future<void> _checkForNewQuotes() async {
    if (_refreshing) return;
    final query = _q;
    try {
      final head = await _query(1, 0, query);
      if (!mounted || query != _q) return;
      final latestId = head.isEmpty
          ? null
          : head.first['quote_uid'] ?? head.first['id'];
      final visibleId = _items.isEmpty
          ? null
          : _items.first['quote_uid'] ?? _items.first['id'];
      if (latestId != visibleId) await _refresh();
    } catch (_) {
      // The next visible-tab check can retry if a native write is in progress.
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    final generation = ++_generation;
    final query = _q;
    final limit = _items.length > 100 ? _items.length : 100;
    try {
      final rows = await _query(limit, 0, query);
      if (!mounted || generation != _generation || query != _q) return;
      final changed = rows.length != _items.length ||
          List.generate(rows.length, (i) => i).any((i) => !mapEquals(rows[i], _items[i]));
      _offset = rows.length;
      _done = rows.length < limit;
      if (changed) setState(() => _items = rows);
    } catch (_) {
      // Keep the visible snapshot if the database is temporarily busy.
    } finally {
      _refreshing = false;
      if (_refreshAgain && mounted) {
        _refreshAgain = false;
        unawaited(_refresh());
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _refreshing || _done) return;
    _loading = true;
    final generation = _generation;
    final query = _q;
    try {
      final rows = await _query(100, _offset, query);
      if (!mounted || generation != _generation || query != _q) return;
      _offset += rows.length;
      _done = rows.length < 100;
      if (rows.isNotEmpty) setState(() => _items.addAll(rows));
    } catch (_) {
      // A later scroll or refresh can retry without clearing the list.
    } finally {
      _loading = false;
    }
  }

  ImageProvider? _avatarProvider(String raw) {
    final value = raw.trim();
    if (value.startsWith('data:')) {
      try {
        return MemoryImage(
          base64Decode(value.substring(value.indexOf(',') + 1)),
        );
      } catch (_) {
        return null;
      }
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return NetworkImage(value);
    }
    if (value.startsWith('assets/')) return AssetImage(value);
    if (value.isNotEmpty) {
      try {
        final file = File(value);
        if (file.existsSync()) return FileImage(file);
      } catch (_) {}
    }
    return null;
  }

  Future<void> _showQuoteDetails(Map<String, dynamic> quote) async {
    final content = (quote['content'] ?? '').toString().trim();
    final theme = (quote['theme'] ?? '').toString().trim();
    final author = (quote['author_name'] ?? '').toString().trim();
    final source = (quote['source_from'] ?? '').toString().trim();
    final explanation = (quote['explanation'] ?? '').toString().trim();
    final avatar = _avatarProvider((quote['avatar'] ?? '').toString());
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(theme.isEmpty ? '名人名言' : theme),
        content: SingleChildScrollView(
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (avatar != null)
                  Center(
                    child: QuoteHistoryAvatar(
                      key: const ValueKey('quote-history-detail-avatar'),
                      image: avatar,
                      diameter: 96,
                    ),
                  ),
                if (avatar != null) const SizedBox(height: 16),
                Text(
                  '“$content”',
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (author.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '——$author',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
                if (source.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '出处：$source',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
                if (explanation.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(explanation, style: const TextStyle(height: 1.65)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('关闭')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    // Wrap entire page in SafeArea with top/bottom disabled so that list content touches edges
    return Scaffold(backgroundColor: Colors.white, body: SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          // Header row containing search bar and upload button. Place within safe area padding manually
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(top: topPad, left: 8, right: 8),
            height: topPad + kToolbarHeight,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜索',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (v) {
                      _q = v;
                      _searchTimer?.cancel();
                      _searchTimer = Timer(const Duration(milliseconds: 220), _refresh);
                    },
                  ),
                ),
                
// === Shuffle & Restore buttons (方案B：物理重排) ===
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Material(
                    color: Colors.white,
                    elevation: 6,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: '洗牌（物理重排）',
                      icon: const Icon(Icons.shuffle, color: Colors.black87),
                      onPressed: () async {
                        try {
                          await _dao.shuffleQuotesPhysically();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已完成洗牌')));
                          await _reload();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('洗牌失败: ' + e.toString())));
                        }
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Material(
                    color: Colors.white,
                    elevation: 6,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: '恢复最初顺序',
                      icon: const Icon(Icons.restore, color: Colors.black87),
                      onPressed: () async {
                        try {
                          await _dao.restoreQuotesToOriginalOrder();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已恢复最初顺序')));
                          await _reload();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('恢复失败: ' + e.toString())));
                        }
                      },
                    ),
                  ),
                ),
// === End buttons ===
// Wrap upload button with padding to set uniform margins
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Material(
                    color: Colors.white,
                    elevation: 6,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () async {
                        // 包裹整个导入逻辑，捕获异常以避免闪退
                        try {
                          File? csvFile;
                          File? avatarFile;
                          String? csvError;
                          await showDialog(context: context, builder: (ctx) {
                            return StatefulBuilder(builder: (ctx, setStateDialog) {
                              return AlertDialog(
                                title: const Text('批量导入名言'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('上传文件 (CSV)'),
                                    Row(children: [
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          try {
                                            final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
                                            if (res != null && res.files.isNotEmpty) {
                                              csvFile = File(res.files.single.path!);
                                              setStateDialog(() {
                                                csvError = null;
                                              });
                                            }
                                          } catch (e) {
                                            // 选择文件过程中可能抛出异常
                                            setStateDialog(() {
                                              csvError = '选择文件失败';
                                            });
                                          }
                                        },
                                        icon: const Icon(Icons.upload_file, color: Colors.black87),
                                        label: const Text('选择CSV'),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(child: Text(csvFile != null ? p.basename(csvFile!.path) : '未选择', overflow: TextOverflow.ellipsis)),
                                    ]),
                                    if (csvError != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          csvError!,
                                          style: const TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    const Text('上传头像（可选）'),
                                    Row(children: [
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          try {
                                            final picker = ImagePicker();
                                            final x = await picker.pickImage(source: ImageSource.gallery);
                                            if (x != null) {
                                              avatarFile = File(x.path);
                                              setStateDialog(() {});
                                            }
                                          } catch (e) {
                                            // 选择图片过程中可能抛出异常
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('选择图片失败')));
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.photo),
                                        label: const Text('选择图片'),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(child: Text(avatarFile != null ? p.basename(avatarFile!.path) : '可不上传', overflow: TextOverflow.ellipsis)),
                                    ]),
                                  ],
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                                  ElevatedButton(
                                    onPressed: () async {
                                      // 校验 CSV 文件
                                      if (csvFile == null) {
                                        setStateDialog(() => csvError = 'CSV 文件必传，不能保存');
                                        return;
                                      }
                                      // Validate extension
                                      if (!csvFile!.path.toLowerCase().endsWith('.csv')) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('只能导入CSV格式')));
                                        }
                                        return;
                                      }
                                      try {
                                        // Save avatar to app storage if provided, preserving extension
                                        String? avatarPath;
                                        if (avatarFile != null) {
                                          avatarPath = await _saveAvatarTemp(avatarFile!);
                                        }
                                        final result = await QuoteDao().bulkImportCsv(csvPath: csvFile!.path, avatarPath: avatarPath);
                                        if (result.success) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存成功！')));
                                          }
                                        } else if (result.details.isNotEmpty) {
                                          final msg = result.details.map((d) => '第${d['row']}行 ${d['reason']}').join('；');
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败！' + msg)));
                                          }
                                        } else {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存失败！')));
                                          }
                                        }
                                        if (context.mounted) {
                                          Navigator.pop(ctx);
                                        }
                                        await _reload();
                                      } catch (e) {
                                        // 导入过程中捕获异常并提示
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入失败，发生异常')));
                                        }
                                      }
                                    },
                                    child: const Text('保存'),
                                  ),
                                ],
                              );
                            });
                          });
                        } catch (e) {
                          // 捕获 showDialog 或其他异常，避免应用崩溃
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入过程中发生错误')));
                        }
                      },
                      icon: const Icon(Icons.upload),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // List content with zero top/bottom padding
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.zero,
              itemCount: _items.length,
              findChildIndexCallback: (key) {
                if (key is! ValueKey<String>) return null;
                final index = _items.indexWhere((item) =>
                    'quote-${item['quote_uid'] ?? item['id']}' == key.value);
                return index < 0 ? null : index;
              },
              itemBuilder: (_, i) {
                final e = _items[i];
                final content = (e['content'] ?? '').toString();
                final author = (e['author_name'] ?? '').toString().trim();
                final source = (e['source_from'] ?? '').toString().trim();
                final theme = (e['theme'] ?? '').toString().trim();
                final taskName = (e['task_name'] ?? '').toString().trim();
                final avatar = _avatarProvider((e['avatar'] ?? '').toString());
                final meta = <String>[
                  if (author.isNotEmpty) author,
                  if (source.isNotEmpty) '出处：$source',
                  if (theme.isNotEmpty) theme,
                  if (taskName.isNotEmpty) taskName,
                ].join(' · ');
                return ListTile(
                  key: ValueKey<String>('quote-${e['quote_uid'] ?? e['id']}'),
                  minVerticalPadding: 8,
                  leading: QuoteHistoryAvatar(
                    key: ValueKey('quote-history-list-avatar-${e['quote_uid'] ?? e['id']}'),
                    image: avatar,
                    diameter: 56,
                  ),
                  title: Text(content, maxLines: 3, overflow: TextOverflow.ellipsis),
                  subtitle: meta.isEmpty ? null : Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showQuoteDetails(e),
                );
              },
            ),
          ),
        ],
      ),
    ));
  }
}
