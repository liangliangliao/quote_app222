import 'package:flutter/material.dart';

import '../domain/enemy_presence.dart';
import '../enemy_host_tools.dart';
import 'ui_helpers.dart';

/// 自检：它此刻在不在、看得到什么、为什么没说话，以及一组「演练」按钮。
///
/// 敌人的很多主动行为有条件（时段、授权、冷却、一天一次），短时间测试看不到并不代表坏了；
/// 这一页把每个条件摆出来，并且让你不用等条件满足就能亲眼看它跑一遍。
class StatusTab extends StatefulWidget {
  const StatusTab({super.key, required this.presence, required this.tools});

  final EnemyPresence presence;
  final EnemyHostTools tools;

  @override
  State<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<StatusTab> {
  EnemyStatus? _s;
  bool _busy = false;
  String _note = '';

  EnemyPresence get _p => widget.presence;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final EnemyStatus s = await _p.status();
    if (!mounted) return;
    setState(() => _s = s);
  }

  Future<void> _run(String label, Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _note = '';
    });
    String result;
    try {
      result = await action();
    } catch (e) {
      result = '失败：$e';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _note = result.isEmpty ? '$label：已完成。' : '$label：$result';
    });
    await _load();
  }

  Future<void> _drill(String kind, String label) => _run(label, () async {
        final DrillResult r = await _p.drill(kind);
        return r.message != null ? '' : r.note;
      });

  String _age(int sec) {
    if (sec < 0) return '从未';
    if (sec < 60) return '$sec 秒前';
    if (sec < 3600) return '${sec ~/ 60} 分钟前';
    if (sec < 86400) return '${sec ~/ 3600} 小时前';
    return '${sec ~/ 86400} 天前';
  }

  Widget _row(bool? ok, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 22,
              child: Text(
                ok == null ? '·' : (ok ? '✓' : '✗'),
                style: TextStyle(
                  color: ok == null ? kEnemyMuted : (ok ? const Color(0xFF7FC97F) : kEnemyAccent),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: 118, child: Text(k, style: const TextStyle(color: kEnemyMuted))),
            Expanded(child: Text(v, style: const TextStyle(color: kEnemyText, height: 1.4))),
          ],
        ),
      );

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(t, style: const TextStyle(color: kEnemyText, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    final EnemyStatus? s = _s;
    if (s == null) return const Center(child: CircularProgressIndicator());

    final bool online = s.heartbeatAgeSec >= 0 && s.heartbeatAgeSec <= 15;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            '这一页回答两个问题：它现在在不在、为什么没说话。往下拉刷新。',
            style: TextStyle(color: kEnemyMuted, fontSize: 13),
          ),
          _title('在线状态'),
          _row(online, '前台', online ? '在线（心跳 ${_age(s.heartbeatAgeSec)}）' : '心跳 ${_age(s.heartbeatAgeSec)}——前台没有在跑，或者 App 刚启动'),
          _row(s.lastStepAgeSec >= 0 && s.lastStepAgeSec <= 60, '上一次看',
              '${_age(s.lastStepAgeSec)} · ${EnemyStatus.whyText(s.lastWhy)}'),
          _row(!s.muted, '静音', s.muted ? '已静音（取消静音在「设置」里）' : '没有'),
          _row(s.interject, '实时插话', s.interject ? '开' : '关'),
          _row(s.patrol, '主动巡查', s.patrol ? '开' : '关'),
          _row(!s.quiet, '静默时段',
              '${s.quietStart.toString().padLeft(2, '0')}:00–${s.quietEnd.toString().padLeft(2, '0')}:00'
              '${s.quiet ? '（现在就在里面，所以它不开口）' : '（现在不在里面）'}'),
          _row(s.capUsed < s.capMax, '今日开口', '${s.capUsed} / ${s.capMax}'),
          _row(s.gapRemainingSec == 0, '开口间隔',
              s.gapRemainingSec == 0 ? '可以开口' : '还要等 ${s.gapRemainingSec} 秒'),
          _title('它看得到什么'),
          for (final SourceStatus src in s.sources)
            _row(
              src.consented,
              src.label.length > 8 ? src.label.substring(0, 8) : src.label,
              src.consented
                  ? '已授权 · 案卷 ${src.events} 条 · 最近 ${_age(src.lastEventAgeSec)}'
                  : '未授权——这里就是你的死角',
            ),
          _row(null, '事件游标', '已看到第 ${s.cursor} 条 / 案卷最新第 ${s.maxEventId} 条'),
          if (s.sources.any((SourceStatus x) => !x.consented))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run('授权全部', () async {
                          await _p.engine.grantAll();
                          await _p.engine.sync();
                          return '';
                        }),
                child: const Text('把全部来源授权并同步'),
              ),
            ),
          _title('主动行为的条件'),
          _row(s.morningDone ? null : true, '晨报',
              '${s.quietEnd}:00–12:00 内第一次巡查 · 今天${s.morningDone ? '已经说过' : '还没说'}'),
          _row(s.eveningDone ? null : true, '晚间结算',
              '${s.patrolHour}:00 之后 · 今天${s.eveningDone ? '已经说过' : '还没说'}'),
          _row(
            s.stallCooldownSec == 0,
            '发呆点名',
            '人在别的页面待满 20 分钟、案卷没有新记录、字据还开着 · '
                '${s.stallCooldownSec == 0 ? '没有冷却' : '冷却还剩 ${(s.stallCooldownSec / 60).ceil()} 分钟'}',
          ),
          _row(s.usageMinutes > 0, '今日使用时长',
              s.usageMinutes > 0 ? '${s.usageMinutes} 分钟' : '0（没授权「使用时长」，或 App 刚启动）'),
          _row(
            s.opposition,
            '反对党质询',
            !s.opposition
                ? '关'
                : '开 · 今日 ${s.probesToday} / ${s.probeCap} · 上一次 ${_age(s.probeAgeSec)} · '
                    '间隔 ${s.probeGapMin} 分钟${s.openMotion ? ' · 有一项动议等你处理' : ''}',
          ),
          _title('后台巡查'),
          _row(
            s.bgScheduledAgeSec >= 0 && s.bgScheduleError.isEmpty,
            '任务登记',
            s.bgScheduleError.isNotEmpty
                ? '失败：${s.bgScheduleError}'
                : (s.bgScheduledAgeSec >= 0 ? '已登记（${_age(s.bgScheduledAgeSec)}）' : '从未登记'),
          ),
          _row(
            s.bgLastRunAgeSec >= 0,
            '最近一次运行',
            s.bgLastRunAgeSec >= 0
                ? '${_age(s.bgLastRunAgeSec)} · ${s.bgLastNote}'
                : '从未运行。系统最短 15 分钟一次，省电策略可能推迟；用下面的按钮可以立刻验证通路',
          ),
          _title('演练（不等条件，现在就让它做一遍）'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              OutlinedButton(
                onPressed: _busy ? null : () => _drill('morning', '晨报演练'),
                child: const Text('晨报'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _drill('evening', '结算演练'),
                child: const Text('晚间结算'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _drill('stall', '发呆演练'),
                child: const Text('发呆点名'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _drill('probe', '质询演练'),
                child: const Text('质询'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run('测试通知', () => widget.tools.testNotification('这是一条测试通知。看到它，说明通知通路是通的。')),
                child: const Text('测试通知'),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '演练的消息会出现在「对峙」里，前面带【演练】；不占今天的次数，也不会让它今天不再说同类的话。',
              style: TextStyle(color: kEnemyMuted, fontSize: 12, height: 1.5),
            ),
          ),
          _title('验证后台通路'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run('登记后台任务', widget.tools.scheduleBackgroundPatrol),
                child: const Text('重新登记后台任务'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run('后台巡查', widget.tools.runBackgroundPatrolOnce),
                child: const Text('10 秒后在后台跑一次'),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '点「10 秒后在后台跑一次」后立刻回到桌面，等十几秒再回来刷新：'
              '「最近一次运行」有时间，说明后台通路是通的；一直是「从未」，说明被系统拦了。',
              style: TextStyle(color: kEnemyMuted, fontSize: 12, height: 1.5),
            ),
          ),
          if (_note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_note, style: const TextStyle(color: kEnemyAccent, height: 1.5)),
            ),
        ],
      ),
    );
  }
}
