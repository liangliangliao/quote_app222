import 'package:flutter/material.dart';

import '../data/scale_dao.dart';
import '../data/dao.dart';
import 'scale_detail_page.dart';
import 'scale_history_page.dart';

/// 心理量表测评中心页面。
///
/// 该页面列出当前数据库中的所有量表，并显示其基本信息以及最近一次测评成绩。
/// 用户可以从这里跳转到具体的量表详情页面进行测评。
class ScaleCenterPage extends StatefulWidget {
  const ScaleCenterPage({super.key});

  @override
  State<ScaleCenterPage> createState() => _ScaleCenterPageState();
}

class _ScaleCenterPageState extends State<ScaleCenterPage> {
  final ScaleDao _scaleDao = ScaleDao();
  final LogDao _logDao = LogDao();
  // 临时用户 ID。真实应用应结合登录体系获取用户身份。
  final String _userId = 'default_user';

  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    // 记录查看测评中心的日志
    _logDao.add(taskUid: 'scale_center', detail: '查看心理量表测评中心');
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    // 获取量表摘要信息，包括最新一次测评（若有）
    return _scaleDao.getScaleSummaries(userId: _userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('心理量表测评中心'),
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
          final scales = snapshot.data ?? [];
          if (scales.isEmpty) {
            return const Center(child: Text('暂无量表，请在设置中导入')); 
          }
          return ListView.builder(
            itemCount: scales.length,
            itemBuilder: (context, index) {
              final s = scales[index];
              final latest = s['latest_assessment'] as Map<String, dynamic>?;
              final bool hasAssessment = latest != null;
              final double score = hasAssessment
                  ? ((latest['total_score'] ?? 0) as num).toDouble()
                  : 0.0;
              final String level = hasAssessment
                  ? (latest['level'] ?? '').toString()
                  : '';
              final String scaleName = (s['name'] ?? '').toString();
              final int scaleId = s['id'] as int;
              final String version = (s['version'] ?? '').toString();
              final String author = (s['author'] ?? '').toString();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$scaleName${version.isNotEmpty ? ' (v$version)' : ''}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      if (author.isNotEmpty) Text('作者: $author'),
                      if (hasAssessment)
                        Text('最近一次得分: $score, 等级: $level'),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ScaleHistoryPage(
                                    scaleId: scaleId,
                                    userId: _userId,
                                    scaleName: scaleName,
                                  ),
                                ),
                              );
                            },
                            child: const Text('查看历史记录'),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () {
                              // 跳转到量表详情页
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ScaleDetailPage(
                                    scale: s,
                                    userId: _userId,
                                  ),
                                ),
                              );
                            },
                            child: Text(hasAssessment ? '重新测评' : '开始测评'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}