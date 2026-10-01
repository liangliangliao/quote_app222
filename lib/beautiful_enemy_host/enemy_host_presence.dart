import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../beautiful_enemy/beautiful_enemy.dart';
import '../data/db.dart';
import '../services/notification_service.dart';
import 'enemy_ai_talker.dart';
import 'enemy_host_reminder.dart';
import 'enemy_sources.dart';
import 'enemy_voice_out.dart';

/// App 开着、但不在「美丽的敌人」页面时，敌人也能插话（用通知）。
///
/// 只在前台、只在你没打开敌人页面时跑；打开敌人页面后由页面自己接管，
/// 两边不会同时说话。App 退到后台，Android 不允许它随时开口，这里也不假装能。
/// 开关在模块设置里：「实时插话」「在其它页面也插话」。
class EnemyHostPresence with WidgetsBindingObserver {
  EnemyHostPresence._();

  static final EnemyHostPresence instance = EnemyHostPresence._();

  /// 敌人页面是否打开着。页面打开时，全局插话让位。
  static bool pageOpen = false;

  static const Duration interval = Duration(seconds: 60);
  static const int notificationId = 92001;

  static void start() => instance._start();

  bool _started = false;
  bool _resumed = true;
  bool _busy = false;
  Timer? _timer;
  Future<EnemyPresence>? _building;
  final EnemyHostVoiceOut _voice = EnemyHostVoiceOut();

  void _start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) _tick();
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

  Future<void> _tick() async {
    if (!_resumed || pageOpen || _busy) return;
    _busy = true;
    try {
      final EnemyPresence presence = await _ensure();
      final bool everywhere =
          await presence.dao.boolSetting(EnemySettings.interjectEverywhere, fallback: true);
      if (!everywhere) return;
      final EnemyMessage? msg = await presence.react();
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
