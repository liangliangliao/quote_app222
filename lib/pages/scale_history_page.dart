import 'package:flutter/material.dart';

import '../data/scale_dao.dart';
import '../data/dao.dart';

/// 历史测评记录页面
///
/// 展示指定量表的所有历史测评结果列表。
class ScaleHistoryPage extends StatefulWidget {
  final int scaleId;
  final String userId;
  final String scaleName;
  const ScaleHistoryPage({
    super.key,
    required this.scaleId,
    required this.userId,
    required this.scaleName,
  });

  @override
  State<ScaleHistoryPage> createState() => _ScaleHistoryPageState();
}

class _ScaleHistoryPageState extends State<ScaleHistoryPage> {
  final ScaleDao _scaleDao = ScaleDao();
  final LogDao _logDao = LogDao();
  late Future<List<Map<String, dynamic>>> _future;

  /// 将 created_at 字段格式化为 yyyy-MM-dd HH:mm
  String _formatCreatedAt(dynamic v) {
    if (v == null) return '';
    DateTime? dt;
    if (v is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(v);
    } else {
      final s = v.toString();
      dt = DateTime.tryParse(s);
      if (dt == null) {
        final ms = int.tryParse(s);
        if (ms != null) {
          dt = DateTime.fromMillisecondsSinceEpoch(ms);
        }
      }
    }
    if (dt == null) return v.toString();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  void initState() {
    super.initState();
    _logDao.add(taskUid: 'scale_${widget.scaleId}', detail: '查看历史记录');
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    return await _scaleDao.getAssessments(
      scaleId: widget.scaleId,
      userId: widget.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.scaleName} - 历史记录'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }
          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return const Center(child: Text('暂无历史记录'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final r = records[index];
              final double score = (r['total_score'] ?? 0) as double;
              final String level = (r['level'] ?? '').toString();
              final String report = (r['report_text'] ?? '').toString();
              final String createdAt = _formatCreatedAt(r['created_at']);

              return Card(
                color: Colors.white,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 1,
                child: ListTile(
                  title: Text('得分: $score, 等级: $level'),
                  subtitle: Text('时间: $createdAt\n报告: $report'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}