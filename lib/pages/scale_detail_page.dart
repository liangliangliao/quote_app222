import 'package:flutter/material.dart';

import '../data/scale_dao.dart';
import '../data/dao.dart';
import 'scale_answer_page.dart';

/// 量表详情页面。
///
/// 展示单个量表的基本信息、题目数量等，并提供开始答题按钮。
class ScaleDetailPage extends StatefulWidget {
  final Map<String, dynamic> scale;
  final String userId;
  const ScaleDetailPage({super.key, required this.scale, required this.userId});

  @override
  State<ScaleDetailPage> createState() => _ScaleDetailPageState();
}

class _ScaleDetailPageState extends State<ScaleDetailPage> {
  final ScaleDao _scaleDao = ScaleDao();
  final LogDao _logDao = LogDao();
  bool _loading = true;
  int _itemCount = 0;

  @override
  void initState() {
    super.initState();
    // 记录查看详情日志
    final scaleId = widget.scale['id'] as int?;
    if (scaleId != null) {
      _logDao.add(taskUid: 'scale_${scaleId.toString()}', detail: '查看量表详情');
    }
    _load();
  }

  Future<void> _load() async {
    final scaleId = widget.scale['id'] as int?;
    if (scaleId == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    try {
      final items = await _scaleDao.getItemsWithOptions(scaleId);
      setState(() {
        _itemCount = items.length;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _itemCount = 0;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final String name = (scale['name'] ?? '').toString();
    final String version = (scale['version'] ?? '').toString();
    final String author = (scale['author'] ?? '').toString();
    final String description = (scale['description'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(name.isNotEmpty ? name : '量表详情'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style:
                        const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (version.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('版本: $version'),
                  ],
                  if (author.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('作者: $author'),
                  ],
                  const SizedBox(height: 12),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: const TextStyle(height: 1.4),
                    ),
                  if (description.isNotEmpty) const SizedBox(height: 12),
                  Text('题目数量: $_itemCount'),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final scaleId = scale['id'] as int?;
                        if (scaleId != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ScaleAnswerPage(
                                scaleId: scaleId,
                                scaleName: name,
                                userId: widget.userId,
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('开始答题'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}