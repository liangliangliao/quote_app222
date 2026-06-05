import 'package:flutter/material.dart';

import '../data/dao.dart';
import '../utils/simple_bus.dart';
import 'scale_history_page.dart';

/// 测评结果页。
///
/// 显示测评完成后的成绩、等级以及报告文本，并提供查看历史记录和返回主页的按钮。
class ScaleResultPage extends StatefulWidget {
  final int scaleId;
  final String userId;
  final String scaleName;
  final double totalScore;
  final String level;
  final String reportText;
  const ScaleResultPage({super.key, required this.scaleId, required this.userId, required this.scaleName, required this.totalScore, required this.level, required this.reportText});

  @override
  State<ScaleResultPage> createState() => _ScaleResultPageState();
}

class _ScaleResultPageState extends State<ScaleResultPage> {
  final LogDao _logDao = LogDao();

  @override
  void initState() {
    super.initState();
    // 记录查看结果页
    _logDao.add(taskUid: 'scale_${widget.scaleId}', detail: '查看测评结果: 分数=${widget.totalScore} 等级=${widget.level}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('测评结果 - ${widget.scaleName}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '用户ID: ${widget.userId}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '总分: ${widget.totalScore}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (widget.level.isNotEmpty)
              Text(
                '等级: ${widget.level}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 12),
            const Text(
              '报告详情:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  widget.reportText,
                  style: const TextStyle(height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // 查看历史记录
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ScaleHistoryPage(
                          scaleId: widget.scaleId,
                          userId: widget.userId,
                          scaleName: widget.scaleName,
                        ),
                      ),
                    );
                  },
                  child: const Text('查看历史记录'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // 返回首页：直接跳转到底部导航的"发现之旅" Tab (index=2)
                    SimpleBus.navIndex.value = 2;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('返回首页'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}