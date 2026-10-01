import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../beautiful_enemy/beautiful_enemy.dart';
import '../data/db.dart';
import '../services/notification_service.dart';
import 'enemy_ai_talker.dart';
import 'enemy_host_patrol.dart';
import 'enemy_host_reminder.dart';
import 'enemy_sources.dart';
import 'enemy_voice_out.dart';

/// 敌人在 App 里的「常驻」：App 一启动它就开始工作，不需要任何人去叫醒。
///
/// 做三件事：
/// 1. 每 3 秒看一眼（靠来源的变更指纹，没变化几乎不花力气）：你做了什么、没做什么，
///    它立刻接话；没有新事时它自己判断该不该主动开口（晨报、晚间结算、发呆点名）。
/// 2. 每分钟记一分钟 App 前台时间——这是它核对「我没时间」的依据。
/// 3. 登记一个后台巡查任务（见 [EnemyHostPatrol]），App 不在前台时也每隔一段时间巡一次。
///
/// 敌人页面打开时，说话的事让给页面自己；其它页面里，它用通知开口。
/// 开关都在模块设置里：「实时插话」「在其它页面也插话」「主动巡查」。
class EnemyHostPresence with WidgetsBindingObserver {
  EnemyHostPresence._();

  static final EnemyHostPresence instance = EnemyHostPresence._();

  /// 敌人页面是否打开着。页面打开时，全局插话让位（计时照常）。
  static bool pageOpen = false;

  static const Duration fastInterval = Duration(seconds: 3);
  static const Duration minuteInterval = Duration(minutes: 1);
  static const int notificationId = 92001;

  static void start() => instance._start();

  bool _started = false;
  bool _resumed = true;
  bool _busy = false;
  int? _sessionStartMs;
  Timer? _fast;
  Timer? _minute;
  Future<EnemyPresence>? _building;
  final EnemyHostVoiceOut _voice = EnemyHostVoiceOut();

  void _start() {
    if (_started) return;
    _started = true;
    final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
    _resumed = state == null || state == AppLifecycleState.resumed;
    if (_resumed) _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
    WidgetsBinding.instance.addObserver(this);
    _fast = Timer.periodic(fastInterval, (_) => _fastTick());
    _minute = Timer.periodic(minuteInterval, (_) => _minuteTick());
    // 后台也要有人盯着：登记一个周期任务（幂等）。
    EnemyHostPatrol.ensureScheduled();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool nowResumed = state == AppLifecycleState.resumed;
    if (nowResumed && !_resumed) {
      _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
    }
    if (!nowResumed) _sessionStartMs = null;
    _resumed = nowResumed;
    if (_resumed) _fastTick();
  }

  Future<EnemyPresence> _ensure() {
    return _building ??= () async {
      final db = await AppDatabase.instance();
      return EnemyEntry.buildPresence(
        db: db,
        talker: EnemyAiTalker(),
        sources: defaultEnemySources(),
      );
    }();
  }

  Future<void> _minuteTick() async {
    if (!_resumed) return;
    try {
      final EnemyPresence presence = await _ensure();
      await presence.engine.recordUsageMinute();
    } catch (_) {
      // 计时失败不该影响 App。
    }
  }

  Future<void> _fastTick() async {
    if (!_resumed || _busy) return;
    _busy = true;
    try {
      final EnemyPresence presence = await _ensure();
      // 心跳：告诉后台巡查「前台有人在盯着」，免得两边同时开口。
      await presence.dao.setSetting(
        EnemySettings.heartbeatMs,
        '${DateTime.now().millisecondsSinceEpoch}',
      );
      if (pageOpen) return;
      final bool everywhere =
          await presence.dao.boolSetting(EnemySettings.interjectEverywhere, fallback: true);
      if (!everywhere) return;
      final EnemyMessage? msg = await presence.step(
        ctx: PatrolContext(foreground: true, sessionStartMs: _sessionStartMs),
      );
      if (msg == null) return;
      await NotificationService.show(
        id: notificationId,
        title: '美丽的敌人',
        body: msg.text,
        payload: EnemyHostReminder.notificationPayload,
      );
      HapticFeedback.heavyImpact();
      if (await presence.dao.boolSetting(EnemySettings.voiceOut)) {
        await _voice.speak(msg.text);
      }
    } catch (_) {
      // 插话失败不该影响 App 其它部分。
    } finally {
      _busy = false;
    }
  }
}
