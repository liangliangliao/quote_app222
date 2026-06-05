import 'package:flutter/material.dart';

import '../data/scale_dao.dart';
import '../data/dao.dart';
import 'scale_result_page.dart';

/// 答题页面
///
/// 展示量表的所有题目及选项，收集用户的答题结果并提交评分。
class ScaleAnswerPage extends StatefulWidget {
  final int scaleId;
  final String scaleName;
  final String userId;
  const ScaleAnswerPage({super.key, required this.scaleId, required this.scaleName, required this.userId});

  @override
  State<ScaleAnswerPage> createState() => _ScaleAnswerPageState();
}

class _ScaleAnswerPageState extends State<ScaleAnswerPage> {
  final ScaleDao _scaleDao = ScaleDao();
  final ConfigDao _configDao = ConfigDao();
  final LogDao _logDao = LogDao();

  List<Map<String, dynamic>> _items = [];
  final Map<int, int> _answers = {};
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _logDao.add(taskUid: 'scale_${widget.scaleId}', detail: '开始答题');
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _scaleDao.getItemsWithOptions(widget.scaleId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  void _onSelect(int itemId, int optionId) {
    setState(() {
      _answers[itemId] = optionId;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    // 确保所有题目都有答案
    if (_answers.length < _items.length) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请回答所有题目')), 
        );
      }
      return;
    }
    // 检查自动报告开关
    final autoEnabled = await _configDao.getAutoReportEnabled();
    if (autoEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('调用大模型接口生成自动报告功能暂时未实现，请关闭开关后重试')), 
        );
      }
      return;
    }
    setState(() {
      _submitting = true;
    });
    // 提交前记录日志
    _logDao.add(taskUid: 'scale_${widget.scaleId}', detail: '提交答卷');
    try {
      final result = await _scaleDao.scoreAndSaveAssessment(
        scaleId: widget.scaleId,
        userId: widget.userId,
        answers: _answers,
      );
      // Scoring method returns totalScore, level, report
      final double totalScore = (result['totalScore'] ?? 0) as double;
      final String level = (result['level'] ?? '').toString();
      final String report = (result['report'] ?? '').toString();
      // 评分完成后等待 5 秒以模拟生成报告的等待时间
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      // 跳转到结果页（替换当前页）
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ScaleResultPage(
            scaleId: widget.scaleId,
            userId: widget.userId,
            scaleName: widget.scaleName,
            totalScore: totalScore,
            level: level,
            reportText: report,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('答题 - ${widget.scaleName}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final int itemId = item['id'] as int;
                      final String content = (item['content'] ?? '').toString();
                      // 题号可能是中文或任意字符串，这里统一按字符串展示；若为空则使用顺序号。
                      final String itemNoLabel = (item['item_no'] ?? (index + 1)).toString();
                      final List<dynamic> options = item['options'] as List<dynamic>;
                      final int? selected = _answers[itemId];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$itemNoLabel. $content',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            for (final opt in options) ...[
                              RadioListTile<int>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text((opt['label'] ?? '').toString()),
                                value: opt['id'] as int,
                                groupValue: selected,
                                onChanged: (val) {
                                  if (val != null) {
                                    _onSelect(itemId, val);
                                  }
                                },
                              ),
                            ],
                            const Divider(height: 24),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          child: const Text('提交答卷'),
                        ),
                      ),
                      if (_submitting)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}