import '../services/native_guard.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../kindling/kindling.dart';
import '../kindling_host/kindling_host_reminder.dart';

import 'native_guard.dart';
import '../data/dao.dart';
import '../pages/discover_page.dart';
import '../realistic_optimism_training/realistic_optimism_training_home_page.dart';
import '../zhixing_tree/zhixing_tree_home_page.dart';
import '../health_diet/pages/today_meal_plan_page.dart';
import '../health_diet/daily_share/daily_diet_share_page.dart';
import '../health_diet/daily_share/daily_diet_review_page.dart';
import '../health_diet/habit/diet_long_term_report_page.dart';
import '../health_diet/expert/health_diet_expert_dashboard_page.dart';
import '../xiangji_goal_mentor/xiangji_goal_mentor_page.dart';
import '../xiangji_future_strategist/xiangji_home_page.dart';
import '../xiangji_future_strategist/xiangji_database.dart';
import '../xiangji_future_strategist/xiangji_problem_pages.dart';
import '../xiangji_future_strategist/xiangji_repository.dart';
import '../belief_lab/belief_mentor_dao.dart';
import '../belief_lab/belief_mentor_home_page.dart';
import '../belief_lab/belief_mentor_models.dart';

import 'package:flutter/material.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  // 标记来自通知；导航逻辑在主线程首帧后统一处理
  try {
    await NotificationService.markLaunchedFromNotification(response.payload);
  } catch (_) {}
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _launchFromNotif = false;
  static String? _pendingPayload;
  static bool _homeVisible = false;
  static bool _requestedThisSession = false;

  /// 仅供主入口消费使用：是否由通知启动（冷启动）
  static Future<bool> didLaunchFromNotification() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      return details?.didNotificationLaunchApp ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markLaunchedFromNotification([String? payload]) async {
    _launchFromNotif = true;
    if (payload != null && payload.trim().isNotEmpty) {
      _pendingPayload = payload.trim();
    }
  }

  static bool consumeLaunchFromNotificationFlag() {
    final v = _launchFromNotif;
    _launchFromNotif = false;
    return v;
  }

  /// 由 main / RootShell 在首帧后调用：如果通知携带健康饮食 payload，则直接进入对应页面；
  /// 否则保持旧行为回到首页。返回 true 表示已经处理过一次通知导航。
  static Future<bool> handlePendingNotificationNavigation() async {
    final has =
        _launchFromNotif ||
        (_pendingPayload != null && _pendingPayload!.isNotEmpty);
    if (!has) return false;
    final payload = _pendingPayload;
    _launchFromNotif = false;
    _pendingPayload = null;
    await handleNotificationPayload(payload);
    return true;
  }

  static Future<void> handleNotificationPayload(String? payload) async {
    if (await _tryNavigateKindling(payload)) return;
    if (await _tryNavigateBeliefMentor(payload)) return;
    if (await _tryNavigateXiangjiFutureStrategist(payload)) return;
    if (await _tryNavigateXiangjiGoal(payload)) return;
    if (await _tryNavigateZhixingTree(payload)) return;
    if (await _tryNavigateRealisticOptimismTraining(payload)) return;
    if (await _tryNavigateHealthDiet(payload)) return;
    SimpleBus.navHome();
    SimpleBus.pokeHome();
  }

  /// 火种的复问通知：直接开模块首页，不带任何参数。
  static Future<bool> _tryNavigateKindling(String? payload) async {
    if ((payload ?? '').trim() != KindlingHostReminder.notificationPayload) {
      return false;
    }
    final NavigatorState? nav = SimpleBus.navigatorKey.currentState;
    if (nav == null) return false;
    // 不能 await：pushNamed 要等这个页面被关掉才返回，而调用方在启动路径上，
    // 一 await 就把启动挂住了。文件里其它 _tryNavigate* 也都是不等的。
    nav.pushNamed(KindlingEntry.route);
    return true;
  }

  static Future<bool> _tryNavigateBeliefMentor(String? payload) async {
    final value = (payload ?? '').trim();
    if (value.isEmpty) return false;
    var matched = value.startsWith('belief_mentor');
    var reminderId = '';
    var type = '';
    var beliefId = '';
    var experimentId = '';
    var scheduledAtMs = 0;
    if (value.startsWith('{')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map &&
            (decoded['module'] ?? '').toString() == 'belief_mentor') {
          matched = true;
          reminderId = (decoded['reminderId'] ?? '').toString();
          type = (decoded['type'] ?? '').toString();
          beliefId = (decoded['beliefId'] ?? '').toString();
          experimentId = (decoded['experimentId'] ?? '').toString();
          scheduledAtMs =
              int.tryParse((decoded['scheduledAtMs'] ?? '').toString()) ?? 0;
        }
      } catch (_) {}
    }
    if (!matched) return false;
    final nav = SimpleBus.navigatorKey.currentState;
    if (nav == null) {
      _pendingPayload = value;
      _launchFromNotif = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await NotificationService.handlePendingNotificationNavigation();
        } catch (_) {}
      });
      return true;
    }
    if (reminderId.isNotEmpty) {
      try {
        final dao = BeliefMentorDao();
        await dao.updateReminderState(
          reminderId,
          BeliefMentorReminderState.opened,
        );
        await dao.track(
          'reminder_opened',
          beliefId: beliefId,
          experimentId: experimentId,
          properties: <String, Object?>{
            'type': type,
            'latency_seconds': scheduledAtMs <= 0
                ? 0
                : ((DateTime.now().millisecondsSinceEpoch - scheduledAtMs) /
                          1000)
                      .round(),
          },
        );
      } catch (_) {}
    }
    _pendingPayload = null;
    _launchFromNotif = false;
    nav.popUntil((route) => route.isFirst);
    nav.push(
      MaterialPageRoute(
        builder: (_) => BeliefMentorHomePage(
          initialTab: type == BeliefMentorReminderType.evidenceCapture.name
              ? 3
              : _beliefMentorRitualReminder(type)
              ? 4
              : 0,
          initialBeliefId: beliefId,
          initialExperimentId: experimentId,
          initialReminderType: type,
        ),
      ),
    );
    return true;
  }

  static bool _beliefMentorRitualReminder(String type) =>
      type == BeliefMentorReminderType.calendarT7.name ||
      type == BeliefMentorReminderType.calendarT1.name ||
      type == BeliefMentorReminderType.calendarFollowUp.name ||
      type == BeliefMentorReminderType.pastMeMessage.name;

  static Future<bool> _tryNavigateXiangjiFutureStrategist(
    String? payload,
  ) async {
    final value = (payload ?? '').trim();
    if (!value.startsWith('xiangji_future_strategist')) return false;
    final nav = SimpleBus.navigatorKey.currentState;
    if (nav == null) {
      _pendingPayload = value;
      _launchFromNotif = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await NotificationService.handlePendingNotificationNavigation();
        } catch (_) {}
      });
      return true;
    }
    _pendingPayload = null;
    _launchFromNotif = false;
    final separator = value.indexOf(':');
    final problemId = separator < 0 ? '' : value.substring(separator + 1);
    final dao = XiangjiDao();
    final repository = XiangjiRepository(dao: dao);
    final destination = problemId.trim().isEmpty
        ? const XiangjiFutureStrategistHomePage()
        : XiangjiProblemWorkspacePage(
            problemId: problemId.trim(),
            repository: repository,
            dao: dao,
          );
    nav.popUntil((route) => route.isFirst);
    nav.push(MaterialPageRoute(builder: (_) => destination));
    return true;
  }

  static Future<bool> _tryNavigateXiangjiGoal(String? payload) async {
    final value = (payload ?? '').trim();
    if (!value.startsWith('xiangji_goal')) return false;
    final nav = SimpleBus.navigatorKey.currentState;
    if (nav == null) {
      _pendingPayload = value;
      _launchFromNotif = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await NotificationService.handlePendingNotificationNavigation();
        } catch (_) {}
      });
      return true;
    }
    _pendingPayload = null;
    _launchFromNotif = false;
    nav.popUntil((route) => route.isFirst);
    nav.push(MaterialPageRoute(builder: (_) => const XiangjiGoalMentorPage()));
    return true;
  }

  static Future<bool> _tryNavigateZhixingTree(String? payload) async {
    final p = (payload ?? '').trim();
    if (p.isEmpty) return false;
    String scene = '';
    var matched = p.startsWith('zhixing_tree');
    if (matched && p.contains(':')) {
      scene = p.substring(p.indexOf(':') + 1).trim();
    }
    if (p.startsWith('{')) {
      try {
        final decoded = jsonDecode(p);
        if (decoded is Map &&
            (decoded['module'] ?? '').toString() == 'zhixing_tree') {
          matched = true;
          scene = (decoded['scene'] ?? '').toString();
        }
      } catch (_) {}
    }
    if (!matched) return false;
    final nav = SimpleBus.navigatorKey.currentState;
    if (nav == null) {
      _pendingPayload = p;
      _launchFromNotif = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await NotificationService.handlePendingNotificationNavigation();
        } catch (_) {}
      });
      return true;
    }
    nav.popUntil((route) => route.isFirst);
    nav.push(
      MaterialPageRoute(
        builder: (_) => ZhixingTreeHomePage(initialAgentScene: scene),
      ),
    );
    return true;
  }

  static Future<bool> _tryNavigateRealisticOptimismTraining(
    String? payload,
  ) async {
    final p = (payload ?? '').trim();
    if (!p.startsWith('realistic_optimism_training')) return false;
    final scene = p.contains(':')
        ? p.substring(p.indexOf(':') + 1).trim()
        : 'proactive_reminder';
    final nav = SimpleBus.navigatorKey.currentState;
    if (nav == null) {
      _pendingPayload = p;
      _launchFromNotif = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await NotificationService.handlePendingNotificationNavigation();
        } catch (_) {}
      });
      return true;
    }
    nav.popUntil((route) => route.isFirst);
    nav.push(
      MaterialPageRoute(
        builder: (_) => RealisticOptimismTrainingHomePage(
          scene: scene.isEmpty ? 'proactive_reminder' : scene,
          initialInput: scene == 'daily_review' ? '请根据今天的记录做一次晚上复盘。' : '',
        ),
      ),
    );
    return true;
  }

  static Future<bool> _tryNavigateHealthDiet(String? payload) async {
    final p = (payload ?? '').trim();
    if (p.isEmpty) return false;
    String slot = '';
    String target = '';
    if (p.startsWith('health_diet_agent:')) {
      slot = p.substring('health_diet_agent:'.length);
    } else if (p.startsWith('health_diet:')) {
      target = p.substring('health_diet:'.length);
    } else if (p.contains('health_diet_agent')) {
      // 兼容 JSON payload，避免额外引入 json 解析依赖导致旧 payload 失效。
      final slotMatch = RegExp(r'\"slot\"\s*:\s*\"([^\"]+)\"').firstMatch(p);
      final targetMatch = RegExp(r'\"target\"\s*:\s*\"([^\"]+)\"')
          .firstMatch(p);
      slot = slotMatch?.group(1) ?? '';
      target = targetMatch?.group(1) ?? '';
    } else {
      return false;
    }
    target = target.isNotEmpty ? target : _targetForHealthDietSlot(slot);
    final nav = SimpleBus.navigatorKey.currentState;
    if (nav == null) {
      _pendingPayload = p;
      _launchFromNotif = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await NotificationService.handlePendingNotificationNavigation();
        } catch (_) {}
      });
      return true;
    }
    Widget page;
    switch (target) {
      case 'share':
        page = const DailyDietSharePage();
        break;
      case 'review':
        page = const DailyDietReviewPage();
        break;
      case 'weekly':
        page = const DietLongTermReportPage(initialDays: 7);
        break;
      case 'expert':
        page = const HealthDietExpertDashboardPage();
        break;
      case 'today_plan':
      default:
        page = const TodayMealPlanPage();
        break;
    }
    nav.popUntil((route) => route.isFirst);
    nav.push(MaterialPageRoute(builder: (_) => page));
    return true;
  }

  static String _targetForHealthDietSlot(String slot) {
    switch (slot) {
      case 'breakfast_check':
        return 'share';
      case 'evening_review':
        return 'review';
      case 'weekly_report':
        return 'weekly';
      case 'morning_plan':
      case 'lunch_plan':
      case 'snack_check':
      case 'dinner_plan':
        return 'today_plan';
      default:
        return 'expert';
    }
  }

  static void markHomeVisible() {
    _homeVisible = true;
    _requestedThisSession = false;
  }

  /// 初始化通知插件与通道（不在此处申请权限）
  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final String? p = response.payload;
        try {
          await NotificationService.markLaunchedFromNotification(p);
        } catch (_) {}
        if (p != null && p.startsWith('vision_focus')) {
          try {
            final dao = VisionDao();
            final goal = await dao.loadGoal();
            if (goal != null) {
              final nav = SimpleBus.navigatorKey.currentState;
              if (nav != null) {
                nav.push(
                  MaterialPageRoute(
                    builder: (_) => VisionFocusPreparePage(goal: goal),
                  ),
                );
                return;
              }
            }
          } catch (_) {}
          // Fallback to home if something fails
          SimpleBus.navHome();
          SimpleBus.pokeHome();
        } else if (await NotificationService._tryNavigateBeliefMentor(p)) {
          return;
        } else if (await NotificationService._tryNavigateXiangjiFutureStrategist(
          p,
        )) {
          return;
        } else if (await NotificationService._tryNavigateXiangjiGoal(p)) {
          return;
        } else if (await NotificationService._tryNavigateZhixingTree(p)) {
          return;
        } else if (await NotificationService._tryNavigateRealisticOptimismTraining(
          p,
        )) {
          return;
        } else if (await NotificationService._tryNavigateHealthDiet(p)) {
          return;
        } else {
          SimpleBus.navHome();
          SimpleBus.pokeHome();
        }
      },
    );

    // Android 通知通道
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'quote_high',
          '定时提醒',
          description: 'Quote 定时提醒',
          importance: Importance.high,
          playSound: true,
        );
        await android.createNotificationChannel(channel);
      }
    }
  }

  /// 系统层开关（Android 13+ 的 POST_NOTIFICATIONS）
  static Future<bool> areNotificationsEnabled() async {
    try {
      if (!Platform.isAndroid) return true;
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return true;
      final enabled = await android.areNotificationsEnabled();
      return enabled ?? true;
    } catch (_) {
      return true;
    }
  }

  /// 发送通知（可选大图/大图标）
  static Future<void> show({
    int? id,
    String? title,
    String? body,
    String? largeIconPath,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'quote_high',
          '定时提醒',
          channelDescription: 'Quote 定时提醒',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: (largeIconPath != null && largeIconPath.isNotEmpty)
              ? BigPictureStyleInformation(
                  FilePathAndroidBitmap(largeIconPath),
                  largeIcon: FilePathAndroidBitmap(largeIconPath),
                  contentTitle: title,
                  summaryText: body,
                )
              : const DefaultStyleInformation(true, true),
          largeIcon: (largeIconPath != null && largeIconPath.isNotEmpty)
              ? FilePathAndroidBitmap(largeIconPath)
              : null,
        );
    final details = NotificationDetails(android: androidDetails);
    final nid = id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    await _plugin.show(nid, title, body, details, payload: payload);
  }

  /// 仅在首页可见后、且每个进程只弹一次
  static Future<void> request() async {
    if (!_homeVisible || _requestedThisSession) return;
    _requestedThisSession = true;
    try {
      if (!Platform.isAndroid) return;
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return;
      // 新 API
      try {
        await android.requestNotificationsPermission();
        return;
      } catch (_) {}
      // 兼容旧版本插件的 API
      try {
        await (android as dynamic).requestPermission();
      } catch (_) {}
    } catch (_) {}
  }

  /// 冷启动捕获：应用由通知启动时标记一次
  static Future<void> captureInitialLaunchFromNotification() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        await markLaunchedFromNotification(
          details?.notificationResponse?.payload,
        );
      }
    } catch (_) {}
  }
}
