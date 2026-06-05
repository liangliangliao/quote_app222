import '../services/native_guard.dart';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'native_guard.dart';
import '../data/dao.dart';
import '../pages/discover_page.dart';
import '../health_diet/pages/today_meal_plan_page.dart';
import '../health_diet/daily_share/daily_diet_share_page.dart';
import '../health_diet/daily_share/daily_diet_review_page.dart';
import '../health_diet/habit/diet_long_term_report_page.dart';
import '../health_diet/expert/health_diet_expert_dashboard_page.dart';
import 'package:flutter/material.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  // 标记来自通知；导航逻辑在主线程首帧后统一处理
  try { await NotificationService.markLaunchedFromNotification(response.payload); } catch (_) {}
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

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

  static bool consumeLaunchFromNotificationFlag() { final v = _launchFromNotif; _launchFromNotif = false; return v; }

  /// 由 main / RootShell 在首帧后调用：如果通知携带健康饮食 payload，则直接进入对应页面；
  /// 否则保持旧行为回到首页。返回 true 表示已经处理过一次通知导航。
  static Future<bool> handlePendingNotificationNavigation() async {
    final has = _launchFromNotif || (_pendingPayload != null && _pendingPayload!.isNotEmpty);
    if (!has) return false;
    final payload = _pendingPayload;
    _launchFromNotif = false;
    _pendingPayload = null;
    await handleNotificationPayload(payload);
    return true;
  }

  static Future<void> handleNotificationPayload(String? payload) async {
    if (await _tryNavigateHealthDiet(payload)) return;
    SimpleBus.navHome();
    SimpleBus.pokeHome();
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
      final targetMatch = RegExp(r'\"target\"\s*:\s*\"([^\"]+)\"').firstMatch(p);
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
        try { await NotificationService.handlePendingNotificationNavigation(); } catch (_) {}
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
  static void markHomeVisible() { _homeVisible = true; _requestedThisSession = false; }

  /// 初始化通知插件与通道（不在此处申请权限）
  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final String? p = response.payload;
        try { await NotificationService.markLaunchedFromNotification(p); } catch (_) {}
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
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'quote_high', '定时提醒',
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
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return true;
      final enabled = await android.areNotificationsEnabled();
      return enabled ?? true;
    } catch (_) {
      return true;
    }
  }

  /// 发送通知（可选大图/大图标）
  static Future<void> show({int? id, String? title, String? body, String? largeIconPath, String? payload}) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'quote_high', '定时提醒',
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
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;
      // 新 API
      try { await android.requestNotificationsPermission(); return; } catch (_) {}
      // 兼容旧版本插件的 API
      try { await (android as dynamic).requestPermission(); } catch (_) {}
    } catch (_) {}
  }

  /// 冷启动捕获：应用由通知启动时标记一次
  static Future<void> captureInitialLaunchFromNotification() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        await markLaunchedFromNotification(details?.notificationResponse?.payload);
      }
    } catch (_) {}
  }
}