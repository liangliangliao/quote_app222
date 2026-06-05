import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'meditation_ai_service.dart';
import 'meditation_dao.dart';
import 'meditation_models.dart';
import 'meditation_settings_service.dart';

class MeditationRecordPage extends StatefulWidget {
  const MeditationRecordPage({super.key});

  @override
  State<MeditationRecordPage> createState() => _MeditationRecordPageState();
}

class _MeditationRecordPageState extends State<MeditationRecordPage> {
  final _dao = MeditationDao();
  final _aiService = MeditationAiService();
  final _settingsService = MeditationSettingsService();
  MeditationStats? _stats;
  MeditationWeeklySummary? _weeklySummary;
  List<MeditationRecord> _records = [];
  bool _loading = true;
  bool _generatingSummary = false;
  String? _summaryError;
  MeditationFeatureSettings _featureSettings = MeditationFeatureSettings.defaults();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await _dao.loadStats();
    final records = await _dao.recentRecords(limit: 50);
    final featureSettings = await _settingsService.load();
    final weeklySummary = featureSettings.showWeeklyAiSummary ? await _dao.latestWeeklySummary() : null;
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _featureSettings = featureSettings;
      _weeklySummary = weeklySummary;
      _records = records;
      _loading = false;
    });
  }

  Future<void> _generateWeeklySummary() async {
    final stats = _stats;
    if (stats == null || !_featureSettings.showWeeklyAiSummary) return;
    setState(() {
      _generatingSummary = true;
      _summaryError = null;
    });
    try {
      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final records = await _dao.recordsSince(weekStart.millisecondsSinceEpoch, limit: 80);
      if (records.isEmpty) {
        if (mounted) setState(() => _summaryError = '最近7天还没有可总结的冥想记录。');
        return;
      }
      final text = await _aiService.generateWeeklySummary(records: records, stats: stats);
      if (!mounted) return;
      if (text.trim().isEmpty) {
        setState(() => _summaryError = 'AI 周总结暂时不可用，可能是未配置 API Key、网络异常或模型返回为空。');
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _summaryError = 'AI 周总结生成失败：$e');
    } finally {
      if (mounted) setState(() => _generatingSummary = false);
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空静心记录？'),
        content: const Text('这会删除所有冥想练习记录和统计数据，无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('清空')),
        ],
      ),
    );
    if (ok == true) {
      await _dao.clearAllRecords();
      await _load();
    }
  }

  String _minutes(int seconds) {
    if (seconds <= 0) return '0分钟';
    return '${(seconds / 60).round()}分钟';
  }

  String _time(int ms) {
    if (ms <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('MM-dd HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(
        title: const Text('静心轨迹'),
        actions: [
          IconButton(onPressed: _records.isEmpty ? null : _clear, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statsCard(stats),
            const SizedBox(height: 12),
            if (_featureSettings.showWeeklyAiSummary) ...[
              _weeklySummaryCard(),
              const SizedBox(height: 18),
            ],
            const Text('最近练习', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_records.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(0.06))),
                child: const Center(child: Text('还没有练习记录。先完成一次 3 分钟冥想。')),
              )
            else
              for (final rec in _records) _recordTile(rec),
          ],
        ),
      ),
    );
  }

  Widget _weeklySummaryCard() {
    final summary = _weeklySummary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Expanded(child: Text('本周 AI 静心总结', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              OutlinedButton(
                onPressed: _records.isEmpty || _generatingSummary ? null : _generateWeeklySummary,
                child: Text(_generatingSummary ? '生成中' : '生成'),
              ),
            ],
          ),
          if ((_summaryError ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_summaryError!, style: const TextStyle(color: Colors.deepOrange, height: 1.45)),
          ],
          const SizedBox(height: 8),
          if (summary == null)
            const Text('完成几次练习后，可以让 AI 根据最近7天记录生成简短总结。', style: TextStyle(color: Colors.black54, height: 1.5))
          else ...[
            Text('${summary.weekStart} 至 ${summary.weekEnd}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 8),
            Text(summary.summaryText, style: const TextStyle(height: 1.55)),
          ],
        ],
      ),
    );
  }

  Widget _statsCard(MeditationStats? stats) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFEFF6FF), Color(0xFFF8F0FF)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('你正在建立一种回到自己的能力', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _metric('连续', stats == null ? '--' : '${stats.streakDays}天')),
              Expanded(child: _metric('本周', stats == null ? '--' : '${stats.weekCompletedCount}/7')),
              Expanded(child: _metric('总时长', stats == null ? '--' : _minutes(stats.totalSeconds))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            stats?.mostUsedType == null ? '完成一次练习后，这里会显示你的常用练习类型。' : '最近最常练习：${stats!.mostUsedType}',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  Widget _recordTile(MeditationRecord rec) {
    final moodText = rec.beforeMood != null && rec.afterMood != null ? '状态 ${rec.beforeMood} → ${rec.afterMood}' : '未记录状态';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.black.withOpacity(0.06))),
      child: ExpansionTile(
        leading: const Icon(Icons.self_improvement, color: Colors.blue),
        title: Text(rec.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${_time(rec.startedAt)} · ${_minutes(rec.durationSeconds)} · $moodText'),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        children: [
          if ((rec.currentState ?? '').isNotEmpty) Align(alignment: Alignment.centerLeft, child: Text('练习前状态：${rec.currentState}')),
          if ((rec.aiFeedback ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: Text('反馈：${rec.aiFeedback}', style: const TextStyle(height: 1.5))),
          ],
          if ((rec.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: Text('觉察：${rec.note}', style: const TextStyle(height: 1.5))),
          ],
        ],
      ),
    );
  }
}
