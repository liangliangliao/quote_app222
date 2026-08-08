import 'package:flutter/material.dart';

import 'xiangji_dao.dart';
import 'xiangji_knowledge_repository.dart';

class XiangjiOperationsPage extends StatefulWidget {
  const XiangjiOperationsPage({
    super.key,
    required this.dao,
    required this.catalog,
  });

  final XiangjiGoalMentorDao dao;
  final XiangjiKnowledgeCatalog catalog;

  @override
  State<XiangjiOperationsPage> createState() => _XiangjiOperationsPageState();
}

class _XiangjiOperationsPageState extends State<XiangjiOperationsPage> {
  bool _loading = true;
  String _error = '';
  Map<String, Object?> _identity = const <String, Object?>{};
  Map<String, int> _events = const <String, int>{};
  List<Map<String, Object?>> _flags = const <Map<String, Object?>>[];
  int _pendingDeletions = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final values = await Future.wait<Object>(<Future<Object>>[
        widget.dao.localIdentity(),
        widget.dao.analyticsSnapshot(),
        widget.dao.featureFlags(),
        widget.dao.pendingProviderDeletions(),
      ]);
      if (!mounted) return;
      setState(() {
        _identity = values[0] as Map<String, Object?>;
        _events = values[1] as Map<String, int>;
        _flags = values[2] as List<Map<String, Object?>>;
        _pendingDeletions =
            (values[3] as List).length;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        title: const Text('本机发布诊断'),
        backgroundColor: const Color(0xFFF7F5EF),
        actions: <Widget>[
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                  children: <Widget>[
                    _card(
                      title: '账户与权限边界',
                      children: <Widget>[
                        _row('账户模式', _identity['account_mode']),
                        _row('所有者范围', _identity['owner_scope']),
                        const Text(
                          '首发采用个人本机模式：设备系统解锁是身份边界；目标与私人书籍不建立团队共享命名空间。',
                          style: TextStyle(height: 1.45, color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _card(
                      title: '知识发布门槛',
                      children: <Widget>[
                        _row('默认层', widget.catalog.defaultLayer),
                        _row('导师', widget.catalog.systems.length),
                        _row('L1 / L2', '${widget.catalog.primaryThemeCount} / '
                            '${widget.catalog.secondaryThemeCount}'),
                        _row('可回定位依据', widget.catalog.evidenceCount),
                        _row(
                          '辅助短画像默认隐藏',
                          widget.catalog.conciseProfiles
                                  .every((item) => item.defaultHidden)
                              ? '通过'
                              : '未通过',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _card(
                      title: '灰度功能开关（只读）',
                      children: _flags
                          .map(
                            (flag) => _row(
                              (flag['flag_key'] ?? '').toString(),
                              '${(flag['enabled'] as int? ?? 0) == 1 ? '开启' : '关闭'} · '
                                  '${flag['rollout_percent'] ?? 0}%',
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      title: '隐私安全的聚合事件',
                      children: <Widget>[
                        const Text(
                          '事件只记录枚举、ID、计数和不可逆状态；记录器会丢弃 text、input、prompt、content、excerpt、answer 字段。',
                          style: TextStyle(height: 1.45, color: Colors.black54),
                        ),
                        const SizedBox(height: 10),
                        if (_events.isEmpty)
                          const Text('尚无事件。')
                        else
                          ..._events.entries.map(
                            (entry) => _row(entry.key, entry.value),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _card(
                      title: '韧性与删除传播',
                      children: <Widget>[
                        _row('远端删除待重试', _pendingDeletions),
                        _row('每日提醒幂等', '按 goal + local_day 唯一键'),
                        _row('知识资产故障策略', '完整性校验失败即停止加载'),
                        _row('生成故障策略', '不覆盖目标与行动记录'),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _card({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, Object? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              (value ?? '').toString(),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
