import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:flutter/material.dart';
import '../data/dao.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
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
    await _loadMore();
    if (mounted) setState((){});
  }

  final _dao = QuoteDao();
  final _scroll = ScrollController();
  String _q = '';
  List<Map<String,dynamic>> _items = [];
  int _offset = 0;
  bool _loading = false;
  bool _done = false;

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

  Future<void> _loadMore() async {
    _loading = true;
    final rows = await _dao.latest(limit: 100, offset: _offset, q: _q.isEmpty ? null : _q);
    _offset += rows.length;
    _items.addAll(rows);
    _loading = false;
    if (mounted) setState((){});
    if (rows.length < 100) _done = true;
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
                      _items.clear();
                      _offset = 0;
                      _done = false;
                      _loadMore();
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
                          _items.clear(); _offset = 0; _done = false;
                          await _loadMore();
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
                          _items.clear(); _offset = 0; _done = false;
                          await _loadMore();
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
              itemBuilder: (_, i) {
                final e = _items[i];
                return ListTile(
                  title: Text((e['task_name'] ?? '') as String),
                  subtitle: Text((e['content'] ?? '') as String, maxLines: 3, overflow: TextOverflow.ellipsis),
                );
              },
            ),
          ),
        ],
      ),
    ));
  }
}