import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'goal_action_record_detail_page.dart';
import 'goal_dao.dart';
import 'goal_models.dart';

class GoalActionHistoryPage extends StatefulWidget {
  const GoalActionHistoryPage({super.key});

  @override
  State<GoalActionHistoryPage> createState() => _GoalActionHistoryPageState();
}

class _GoalActionHistoryPageState extends State<GoalActionHistoryPage> {
  final _dao = GoalDao();
  String _period = 'today';
  late Future<List<GoalActionRecordView>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<GoalActionRecordView>> _load() {
    final limit = _period == 'all' ? 100 : 50;
    return _dao.listActionRecordViews(limit: limit, period: _period);
  }

  void _reload(String period) {
    setState(() {
      _period = period;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('行动闭环')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<List<GoalActionRecordView>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(child: Text(snap.error?.toString() ?? '加载失败'));
          }
          final records = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _hero(),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('今天', 'today'),
                    const SizedBox(width: 8),
                    _chip('本周', 'week'),
                    const SizedBox(width: 8),
                    _chip('全部', 'all'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: _period == 'today' ? '今日行动' : (_period == 'week' ? '本周行动' : '全部行动'),
                child: records.isEmpty
                    ? const Text('这里还没有记录。可以从概念实践卡里的“立即执行并记录”开始。')
                    : Column(
                        children: [
                          for (final item in records)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      CupertinoPageRoute(
                                        builder: (_) => GoalActionRecordDetailPage(recordId: item.record.id),
                                      ),
                                    );
                                    if (mounted) _reload(_period);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${(item.record.completionRate * 100).round()}%',
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item.actionTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                                              const SizedBox(height: 4),
                                              Text(item.conceptTitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                              const SizedBox(height: 4),
                                              Text(item.segmentTitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                              const SizedBox(height: 6),
                                              Text(
                                                _fmt(item.record.completedAtMs),
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            if (item.hasFollowup)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF111827),
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  item.followupDecision,
                                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                                ),
                                              )
                                            else
                                              const Text('待复盘', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 8),
                                            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _hero() => _card(
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('行动不是一次提交，而是一个闭环', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text(
              '这里集中看你今天、本周或全部行动记录，并进入二次复盘：继续、调整、放弃。',
              style: TextStyle(height: 1.6, color: Color(0xFF4B5563)),
            ),
          ],
        ),
      );

  Widget _card({String? title, required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      );

  Widget _chip(String label, String value) {
    final selected = _period == value;
    return GestureDetector(
      onTap: () => _reload(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected ? null : const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF374151), fontWeight: FontWeight.w700)),
      ),
    );
  }

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
