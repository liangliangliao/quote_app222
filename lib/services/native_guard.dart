import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

// Pages
import '../pages/home_page.dart';
import '../utils/debug_logger.dart';
import '../data/dao.dart';
import '../data/sport_dao.dart';
import '../pages/discover_page.dart';
import '../pages/sport_detail_page.dart';
import '../pages/sport_running_page.dart';
import 'sport_music_service.dart';
import 'package:flutter/material.dart';

/// Native capability guard (kept minimal and backwards-compatible)
class NativeGuard {
  static const _ch = MethodChannel('com.example.quote_app/sys');

static Future<bool> isNativeAM() async {
  // Some pages call this legacy probe; keep it as an alias/fallback.
  try {
    final ok = await _ch.invokeMethod('isNativeAmEnabled');
    return ok == true;
  } catch (_) {
    // Fallback to WM probe if the native side doesn't implement AM.
    try {
      return await isNativeWM();
    } catch (_) {
      return false;
    }
  }
}


  static Future<bool> isNativeWM() async {
    try {
      final ok = await _ch.invokeMethod('isNativeWmEnabled');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static bool _notifHandlerInstalled = false;

  /// 确保原生通知点击事件能推送到 Flutter（事件驱动，避免轮询）
  static void ensureNotificationTapHandler() {
    if (_notifHandlerInstalled) return;
    _notifHandlerInstalled = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onSportMusicAction') {
        final args = call.arguments;
        String action = '';
        if (args is Map && args['action'] != null) {
          action = args['action'].toString();
        }
        try {
          if (action == 'pause') {
            await SportMusicService.instance.pause();
          } else if (action == 'resume') {
            await SportMusicService.instance.startIfNeeded();
          } else if (action == 'stop') {
            await SportMusicService.instance.stop();
          }
        } catch (_) {}
        return null;
      } else if (call.method == 'onNativeNotificationTap') {
        // call.arguments may be null or a map containing type/payload
        final args = call.arguments;
        String? type;
        String? payload;
        if (args is Map) {
          final dynamic t = args['type'];
          final dynamic p = args['payload'];
          if (t is String) type = t;
          if (p is String) payload = p;
        }
        try {
          await DLog.i('NotifTap', 'NativeGuard handler: onNativeNotificationTap type='+ (type ?? 'null'));
        } catch (_) {}
        // Handle vision focus notifications by navigating to VisionFocusPreparePage
        if (type == 'vision_focus') {
          try {
            // Load current vision goal
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
                return null;
              }
            }
          } catch (_) {}
          // Fallback: navigate home
          try {
            SimpleBus.navHome();
            SimpleBus.pokeHome();
          } catch (_) {}
        
} else if (type == 'sport_running') {
  // Sport running notification: navigate to the running page by recordId.
  int? recordId;
  try {
    final obj = json.decode(payload ?? '{}');
    if (obj is Map && obj['recordId'] != null) {
      recordId = int.tryParse(obj['recordId'].toString());
    }
  } catch (_) {}
  // If no recordId provided, fall back to the latest active or queued record.
  if (recordId == null) {
    try {
      // Prefer an active record (not_started/in_progress/paused) if exists.
      final rec = await SportDao().getLatestActiveRecord();
      if (rec != null) {
        recordId = (rec['id'] is num)
            ? (rec['id'] as num).toInt()
            : int.tryParse(rec['id']?.toString() ?? '');
      } else {
        // Fallback: latest unfinished record (may include queued)
        final rec2 = await SportDao().getLatestUnfinishedRecord();
        if (rec2 != null) {
          recordId = (rec2['id'] is num)
              ? (rec2['id'] as num).toInt()
              : int.tryParse(rec2['id']?.toString() ?? '');
        }
      }
    } catch (_) {}
  }
  if (recordId != null) {
    try {
      final dao = SportDao();
      final rec = await dao.getRecord(recordId!);
      Map<String, dynamic>? plan;
      int? planId;
      String mode = 'instant';
      String? status;
      if (rec != null) {
        // Determine plan and mode based on record.
        final pid = rec['plan_id'];
        if (pid is int) planId = pid;
        if (pid is num) planId = pid.toInt();
        mode = (rec['mode'] ?? 'plan').toString();
        status = (rec['status'] ?? '').toString();
        if (planId != null) {
          try {
            plan = await dao.getPlan(planId);
          } catch (_) {
            plan = null;
          }
        }
      }
      // Concurrency rule:
      // - If another active record exists (excluding this one), do NOT jump to
      //   running page. Mark this record as queued and go to sport home.
      try {
        final active = await dao.getLatestActiveRecord(excludeRecordId: recordId!);
        if (active != null) {
          try {
            await dao.markRecordQueued(recordId!);
            if (planId != null) {
              await dao.updatePlanStatus(planId, 'queued');
            }
          } catch (_) {}
          final nav2 = SimpleBus.navigatorKey.currentState;
          if (nav2 != null) {
            nav2.push(MaterialPageRoute(builder: (_) => const SportDetailPage()));
            return null;
          }
        }
      } catch (_) {}

      // No other active session. If this record is queued, promote it to prestart
      // in_progress so SportRunningPage can show countdown and then start.
      if (status == 'queued') {
        try {
          await dao.promoteQueuedToPrestart(recordId!);
          if (planId != null) {
            await dao.updatePlanStatus(planId, 'in_progress');
          }
        } catch (_) {}
        status = 'in_progress';
      }
      // Navigate to the record's running page.
      final nav = SimpleBus.navigatorKey.currentState;
      if (nav != null) {
        nav.push(MaterialPageRoute(builder: (_) => SportRunningPage(recordId: recordId!, plan: plan, mode: mode)));
        return null;
      }
    } catch (_) {}
  }
  // Fallback: navigate to sport detail page
  try {
    final nav = SimpleBus.navigatorKey.currentState;
    if (nav != null) {
      nav.push(MaterialPageRoute(builder: (_) => const SportDetailPage()));
      return null;
    }
  } catch (_) {}
  try { SimpleBus.navHome(); SimpleBus.pokeHome(); } catch (_) {}
} else if (type == 'sport_reminder') {
          // Sport reminder: open sport detail page
          try {
            final nav = SimpleBus.navigatorKey.currentState;
            if (nav != null) {
              nav.push(MaterialPageRoute(builder: (_) => const SportDetailPage()));
              return null;
            }
          } catch (_) {}
          try { SimpleBus.navHome(); SimpleBus.pokeHome(); } catch (_) {}
        } else if (type == 'sport_fullscreen') {
          // Sport full-screen alarm: create (or reuse) a running record and jump into the running page.
          int? planId;
          String? planTimeIso;
          try {
            final obj = json.decode(payload ?? '{}');
            if (obj is Map && obj['planId'] != null) {
              planId = int.tryParse(obj['planId'].toString());
            }
            if (obj is Map && obj['planTime'] != null) {
              planTimeIso = obj['planTime']?.toString();
            }
          } catch (_) {}
          try {
            final nav = SimpleBus.navigatorKey.currentState;
            if (nav == null) throw Exception('no nav');
            Map<String, dynamic>? plan;
            if (planId != null) {
              try { plan = await SportDao().getPlan(planId!); } catch (_) {}
            }
            // Insert (or reuse) a placeholder record so running page always has a recordId.
            // start_time should be written when countdown ends (actual start moment).
            final dao = SportDao();
            final String ptIso = (planTimeIso != null && planTimeIso!.isNotEmpty)
                ? planTimeIso!
                : (plan?['plan_time']?.toString().isNotEmpty == true ? plan!['plan_time'].toString() : DateTime.now().toIso8601String());

            // Concurrency: if there is already an active session, we cannot start a new one.
            // Mark this plan instance as queued and go to sport home.
            try {
              final active = await dao.getLatestActiveRecord();
              if (active != null) {
                int? qrid;
                if (planId != null) {
                  try { qrid = await dao.getRecordIdForPlanInstance(planId!, ptIso); } catch (_) { qrid = null; }
                }
                qrid ??= await dao.insertRecord(<String, dynamic>{
                  'plan_id': planId,
                  'title': (plan?['title'] ?? '').toString(),
                  'sport_type': (plan?['sport_type'] ?? 'walk').toString(),
                  'mode': planId == null ? 'instant' : 'plan',
                  'plan_time': planId == null ? null : ptIso,
                  'status': 'queued',
                  'target_type': plan?['target_type'] ?? 'steps',
                  'target_value': plan?['target_value'] ?? 0,
                  'target_unit': plan?['target_unit'] ?? '步',
                });
                if (qrid != null) {
                  try { await dao.markRecordQueued(qrid); } catch (_) {}
                }
                if (planId != null) {
                  try { await dao.updatePlanStatus(planId!, 'queued'); } catch (_) {}
                }
                nav.push(MaterialPageRoute(builder: (_) => const SportDetailPage()));
                return null;
              }
            } catch (_) {
              // ignore
            }

            int? recordId;
            if (planId != null) {
              try {
                recordId = await dao.getRecordIdForPlanInstance(planId!, ptIso);
              } catch (_) {
                recordId = null;
              }
            }
            recordId ??= await dao.insertRecord(<String, dynamic>{
              'plan_id': planId,
              'title': (plan?['title'] ?? '').toString(),
              'sport_type': (plan?['sport_type'] ?? 'walk').toString(),
              'mode': planId == null ? 'instant' : 'plan',
              'plan_time': planId == null ? null : ptIso,
              'status': 'in_progress',
              'start_time': null,
              'target_type': plan?['target_type'] ?? 'steps',
              'target_value': plan?['target_value'] ?? 0,
              'target_unit': plan?['target_unit'] ?? '步',
            });
            if (recordId == null) {
              nav.push(MaterialPageRoute(builder: (_) => const SportDetailPage()));
              return null;
            }
            final int rid = recordId;
            nav.push(
              MaterialPageRoute(
                builder: (_) => SportRunningPage(
                  recordId: rid,
                  plan: plan,
                  mode: planId == null ? 'instant' : 'plan',
                ),
              ),
            );
            return null;
          } catch (_) {
            try {
              final nav = SimpleBus.navigatorKey.currentState;
              if (nav != null) {
                nav.push(MaterialPageRoute(builder: (_) => const SportDetailPage()));
                return null;
              }
            } catch (_) {}
            try { SimpleBus.navHome(); SimpleBus.pokeHome(); } catch (_) {}
          }
        }

        // Default: go home
        try {
          SimpleBus.navHome();
          SimpleBus.pokeHome();
        } catch (_) {}
      }
      return null;
    });
  }

  /// 由 Dart 主页面查询：是否有一次原生通知点击待消费（冷启动兜底）
  static Future<bool> consumeLaunchFromNotificationFlag() async {
    try {
      final v = await _ch.invokeMethod<bool>('consumeLaunchFromNotificationFlag');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }


  /// Ensure dynamic runtime receivers (e.g., unlock/user-present) are registered on first launch.
  /// We try multiple method names to be compatible with different native builds.
  static Future<void> ensureRuntimeReceiversRegistered() async {
    try {
      // Use the same channel as other system calls.
      // If a method is not implemented on native side, we ignore.
      try { await _ch.invokeMethod('registerRuntimeReceivers'); } catch (_) {}
      try { await _ch.invokeMethod('registerUnlockReceivers'); } catch (_) {}
      try { await _ch.invokeMethod('registerUnlockReceiver'); } catch (_) {}
      try { await _ch.invokeMethod('registerReceivers'); } catch (_) {}
    } catch (_) {}
  }
}

/// App-wide simple event bus & navigation utilities.
/// Many pages rely on these static members; keep names unchanged.
class SimpleBus {
  // Global navigator for out-of-context navigation (e.g., from notification callbacks)
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Bottom nav index (if used by the app)
  static final ValueNotifier<int> navIndex = ValueNotifier<int>(0);

  // Page refresh ticks
  static final ValueNotifier<int> homeTick = ValueNotifier<int>(0);
  static final ValueNotifier<int> logsTick = ValueNotifier<int>(0);
  static final ValueNotifier<int> settingsTick = ValueNotifier<int>(0);

  static bool _inited = false;

  static void init() {
    if (_inited) return;
    _inited = true;
  }

  /// Navigate to Home by replacing the whole stack.
  static void navHome() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    // 回到根路由（RootShell），保持底部导航栏不消失
    nav.popUntil((route) => route.isFirst);
    // 切到首页 Tab
    try { navIndex.value = 0; } catch (_) {}
    try { pokeHome(); } catch (_) {}
  }

  /// Notify home to refresh
  static void pokeHome() { homeTick.value = homeTick.value + 1; }

  /// Notify logs page to refresh
  static void pokeLogs() { logsTick.value = logsTick.value + 1; }

  /// Notify settings page to refresh
  static void pokeSettings() { settingsTick.value = settingsTick.value + 1; }

  /// Ensure dynamic runtime receivers (e.g., unlock/user-present) are registered on first launch.
  /// We try multiple method names to be compatible with different native builds.
  static Future<void> ensureRuntimeReceiversRegistered() async {
    try {
      const ch = MethodChannel('com.example.quote_app/sys');
      // Try a few candidates; ignore if not implemented.
      try { await ch.invokeMethod('registerRuntimeReceivers'); } catch (_) {}
      try { await ch.invokeMethod('ensureUnlockRegistered'); } catch (_) {}
      try { await ch.invokeMethod('registerUnlockReceivers'); } catch (_) {}
      try { await ch.invokeMethod('registerUnlockReceiver'); } catch (_) {}
      try { await ch.invokeMethod('registerReceivers'); } catch (_) {}
    } catch (_) {}
  }
}