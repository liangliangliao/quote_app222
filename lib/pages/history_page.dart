import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:flutter/material.dart';
import '../data/dao.dart';
import '../models/quote_insight.dart';
import '../services/quote_comparison_service.dart';
import '../services/quote_insight_settings.dart';
import '../widgets/quote_comparison_sheet.dart';
import '../widgets/quote_history_avatar.dart';
import '../widgets/quote_reading_insights.dart';

class HistoryPage extends StatefulWidget {
  final QuoteDao? dao;
  final QuoteComparisonService? comparisonService;
  const HistoryPage({super.key, this.dao, this.comparisonService});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
        
  Future<String?> _saveAvatarTemp(File file) async {
    final docs = await getApplicationDocumentsDirectory();
    final ext = p.extension(file.path);
    final dst = File(p.join(docs.path, 'avatar_${DateTime.now().millisecondsSinceEpoch}${ext}'));
    await dst.writeAsBytes(await file.readAsBytes());
    return dst.path;
  }

  Future<void> _reload() async {
    _items.clear();
    _offset = 0;
    _done = false;
    _loadGeneration++;
    _loading = false;
    await _loadMore();
    if (mounted) setState((){});
  }

  late final _dao = widget.dao ?? QuoteDao();
  final _scroll = ScrollController();
  String _q = '';
  List<Map<String,dynamic>> _items = [];
  int _offset = 0;
  bool _loading = false;
  bool _done = false;
  int _loadGeneration = 0;
  bool _selecting = false;
  final Map<String, QuoteReference> _selected = {};

  void _toggleQuote(QuoteReference quote) {
    if (quote.content.trim().isEmpty) return;
    final key = quote.contentKey;
    if (!_selected.containsKey(key) && _selected.length == 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('一次比较两条名言，请先取消一条')));
      return;
    }
    setState(() {
      _selecting = true;
      if (_selected.containsKey(key)) { _selected.remove(key); }
      else { _selected[key] = quote; }
    });
  }

  Future<void> _compareSelected() async {
    if (_selected.length != 2) return;
    final pair = _selected.values.toList();
    await showQuoteComparison(context, pair[0], pair[1], service: widget.comparisonService);
  }

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 100 && !_loading && !_done) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || _done) return;
    final generation = _loadGeneration;
    _loading = true;
    try {
      final rows = await _dao.latest(limit: 100, offset: _offset, q: _q.isEmpty ? null : _q);
      if (!mounted || generation != _loadGeneration) return;
      _offset += rows.length;
      _items.addAll(rows);
      _done = rows.length < 100;
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('名言列表暂未加载，请重新搜索后重试')));
      }
    } finally {
      if (mounted && generation == _loadGeneration) setState(() => _loading = false);
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
                  const Text('解读 · 一种理解', style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Text(explanation, style: const TextStyle(height: 1.65)),
                ],
                QuoteReadingInsights(quote: QuoteReference.fromRow(quote)),
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
                      _reload();
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
          if (QuoteInsightSettings.comparisonEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  TextButton.icon(
                    key: const ValueKey('quote-select-comparison'),
                    icon: Icon(_selecting ? Icons.close : Icons.compare_arrows),
                    label: Text(_selecting ? '退出选择（${_selected.length}/2）' : '选择比较'),
                    onPressed: () => setState(() {
                      _selecting = !_selecting;
                      _selected.clear();
                    }),
                  ),
                  if (_selecting)
                    FilledButton(
                      key: const ValueKey('quote-start-comparison'),
                      onPressed: _selected.length == 2 ? _compareSelected : null,
                      child: const Text('开始比较'),
                    ),
                ]),
                if (_selecting && _selected.isEmpty)
                  const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('选择两条名言；可以搜索后继续选择。')),
                if (_selected.isNotEmpty)
                  Wrap(spacing: 8, children: _selected.values.indexed.map((entry) => InputChip(
                    label: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220),
                      child: Text('${entry.$1 == 0 ? 'A' : 'B'} · ${entry.$2.content}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    onDeleted: () => _toggleQuote(entry.$2),
                  )).toList()),
              ]),
            ),
          // List content with zero top/bottom padding
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.zero,
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final e = _items[i];
                final reference = QuoteReference.fromRow(e);
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
                  key: ValueKey('quote-history-row-${reference.id.isEmpty ? reference.contentKey : reference.id}'),
                  minVerticalPadding: 8,
                  leading: QuoteHistoryAvatar(
                    key: ValueKey('quote-history-list-avatar-$i'),
                    image: avatar,
                    diameter: 56,
                  ),
                  title: Text(content, maxLines: 3, overflow: TextOverflow.ellipsis),
                  subtitle: meta.isEmpty ? null : Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: _selecting
                      ? Checkbox(
                          value: _selected.containsKey(reference.contentKey),
                          semanticLabel: '选择名言：$content',
                          onChanged: (_) => _toggleQuote(reference),
                        )
                      : const Icon(Icons.chevron_right),
                  selected: _selected.containsKey(reference.contentKey),
                  onTap: () => _selecting ? _toggleQuote(reference) : _showQuoteDetails(e),
                  onLongPress: QuoteInsightSettings.comparisonEnabled ? () => _toggleQuote(reference) : null,
                );
              },
            ),
          ),
        ],
      ),
    ));
  }
}
