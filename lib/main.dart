import 'diary/diary_theme.dart';
import './services/native_guard.dart';
import 'services/native_sport_fg.dart';
import 'services/global_ai_settings.dart';
import 'services/unified_ai_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'dart:isolate';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:workmanager/workmanager.dart';

import 'data/db.dart';
import 'data/dao.dart';
import 'data/sport_dao.dart';
import 'services/notification_service.dart';
import 'services/scheduler_service.dart';
import 'services/wm_dispatcher.dart';
import 'health_diet/services/health_diet_daily_scheduler_service.dart';
import 'background_tasks.dart';
import 'pages/home_page.dart';
import 'pages/history_page.dart';
import 'pages/logs_page.dart';
import 'pages/settings_page.dart';
import 'pages/discover_page.dart';
import 'services/native_guard.dart';
import 'utils/debug_logger.dart';
import 'platform/perm_helper.dart';
import 'platform/native_scheduler.dart';
import 'belief_lab/belief_lab_home_page.dart';
import 'failure_module/failure_module_home_page.dart';
import 'goal_module/goal_theme_home_page.dart';
import 'will_module/will_module_home_page.dart';
import 'change_lab/ui/change_lab_shell_page.dart';
import 'conscious_change/conscious_change_home_page.dart';
import 'concept_engine/concept_engine_home_page.dart';
import 'movie_role_lab/movie_role_lab_home_page.dart';
import 'happiness_module/happiness_module_home_page.dart';
import 'yangming_module/yangming_module_home_page.dart';
import 'stress_module/stress_module_home_page.dart';
import 'positive_psych_module/positive_psych_module_home_page.dart';
import 'goal_setting_module/goal_setting_module_home_page.dart';
import 'voice_lab/voice_lab_home_page.dart';
import 'external_data/onenote_pages.dart';
import 'life_note_module/life_note_home_page.dart';
import 'semantic_consistency/semantic_consistency_page.dart';
import 'behavior_tracking/behavior_tracking_home_page.dart';
import 'shame_transform/shame_transform_home_page.dart';
import 'cognitive_consistency/cognitive_consistency_home_page.dart';
import 'realistic_optimism_module/realistic_optimism_home_page.dart';
import 'realistic_optimism_training/realistic_optimism_training_home_page.dart';
import 'sustainable_excellence/sustainable_excellence_home_page.dart';
import 'mi_growth/mi_growth_home_page.dart';
import 'second_thought/second_thought_home_page.dart';
import 'act_compass/act_compass_home_page.dart';
import 'action_mind/action_mind_home_page.dart';
import 'woop_action_engine/woop_action_engine_home_page.dart';
import 'realistic_positivity_os/realistic_positivity_os_home_page.dart';
import 'defense_compass/defense_compass_home_page.dart';
import 'adaptation_compass/adaptation_compass_home_page.dart';
import 'new_tablets/new_tablets_home_page.dart';
import 'self_worth_ai/self_worth_ai_home_page.dart';
import 'boundary_practice/boundary_practice_home_page.dart';
import 'boundary_action_coach/boundary_action_coach_home_page.dart';
import 'self_determination_growth/self_determination_growth_home_page.dart';

Future<void> _navToHomeIfLaunchedFromNotification() async {
  final plugin = FlutterLocalNotificationsPlugin();
  final details = await plugin.getNotificationAppLaunchDetails();
  if (details?.didNotificationLaunchApp ?? false) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try { NativeGuard.ensureRuntimeReceiversRegistered(); } catch (_) {}
      final handled = await NotificationService.handlePendingNotificationNavigation();
      if (!handled) {
        SimpleBus.navHome();
        SimpleBus.pokeHome();
      }
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NativeGuard.ensureNotificationTapHandler();

  await NotificationService.captureInitialLaunchFromNotification();
try {
    const MethodChannel _sys = MethodChannel('com.example.quote_app/sys');
    await _sys.invokeMethod('createNoMediaGuards');
  try { await NativeGuard.ensureRuntimeReceiversRegistered(); } catch (_) {}
  } catch (_) {}

	// Enable edge-to-edge. We still keep default system bar colors white.
	// Diary pages may set bars to transparent to let background images cover them.
	await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
	SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
	  statusBarColor: Colors.transparent,
	  statusBarIconBrightness: Brightness.dark,
	  statusBarBrightness: Brightness.light,
	  systemNavigationBarColor: Colors.transparent,
	  systemNavigationBarDividerColor: Colors.transparent,
	));
  ui.DartPluginRegistrant.ensureInitialized();
  /* moved to post-frame */ AppDatabase.instance(); // warm-up (non-blocking)

  // Sport safety net:
  // - If a sport is still in progress, ensure Android native foreground tracking keeps running.
  //   (iOS cannot keep tracking after user force-quits from app switcher.)
  try {
    final rec = await SportDao().getLatestUnfinishedRecord();
    if (rec != null && (rec['status'] ?? '').toString() == 'in_progress' && (Platform.isAndroid || Platform.isIOS)) {
      final rid = (rec['id'] is num) ? (rec['id'] as num).toInt() : int.tryParse(rec['id']?.toString() ?? '');
      if (rid != null) {
        await NativeSportFg.ensureStarted(
            recordId: rid,
            title: (rec['title'] ?? '运动进行中').toString(),
            targetType: rec['target_type']?.toString(),
            targetValue: (rec['target_value'] is num) ? (rec['target_value'] as num).toDouble() : double.tryParse(rec['target_value']?.toString() ?? ''),
            targetUnit: rec['target_unit']?.toString(),
          );
      }
    }
  } catch (_) {}

  // Schedule a daily midnight renewal alarm (native side will renew plans even if process is killed).
  // This is best-effort; if exact alarm permission is missing, native side may fall back to WM.
  try {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    await NativeScheduler.scheduleExactAt(
      id: 1800000000,
      epochMs: nextMidnight.millisecondsSinceEpoch + 1000,
      payload: const {'type': 'sport_midnight_renew'},
    );
  } catch (_) {}

  // Ensure auxiliary columns exist (scheduled_run_key, next_time).  This should
  // be called once after opening the database to migrate older installations.
  
  // CHECK_NOTIF_AND_NAV_HOME: post-frame ensure notification launch always goes to Home
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final handledNotif = await NotificationService.handlePendingNotificationNavigation();
    if (handledNotif) {
      try {
        await DLog.i('NotifTap', 'main() postFrame: handled notification payload');
      } catch (_) {}
    }
  });
  runApp(const MyApp());
  _navToHomeIfLaunchedFromNotification();

  // Do heavy initializations after first frame to avoid splash卡住
  Future.microtask(() async {
    try { await ensureExtraTaskColumns(); } catch (_) {}
    try { await NotificationService.init(); } catch (_) {}
    try { await SchedulerService.init(); } catch (_) {}
    // 预加载日记背景配置到内存，避免日记页面首次进入时出现背景闪烁
    try { await DiaryTheme.reloadFromDatabase(); } catch (_) {}
    try { await Workmanager().initialize(workmanagerCallbackDispatcher, isInDebugMode: false); } catch (_) {}
    try { await HealthDietDailySchedulerService().tick(); } catch (_) {}
    try { SimpleBus.init(); } catch (_) {}
    try { _registerHomeRefreshPort(); } catch (_) {}
  });

}


class NoOverscrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // 禁用全局overscroll指示
  }
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
		// Keep system navigation bar white by default. Some diary pages with a
		// configured background image may override it to transparent.
		return AnnotatedRegion<SystemUiOverlayStyle>(
			value: const SystemUiOverlayStyle(
				statusBarColor: Colors.transparent,
				statusBarIconBrightness: Brightness.dark,
				statusBarBrightness: Brightness.light,
				systemNavigationBarColor: Colors.transparent,
				systemNavigationBarDividerColor: Colors.transparent,
			),
			child: MaterialApp(
				navigatorKey: SimpleBus.navigatorKey,
				scrollBehavior: NoOverscrollBehavior(),
				title: '',
				theme: ThemeData(
					scaffoldBackgroundColor: Colors.white,
					useMaterial3: true,
					colorSchemeSeed: Colors.indigo,
					// 底部导航组件背景保持白色，避免出现异常底色
					navigationBarTheme: NavigationBarThemeData(
						backgroundColor: Colors.white,
						indicatorColor: Colors.white,
						labelTextStyle: MaterialStateProperty.all(
							const TextStyle(color: Colors.black87),
						),
						iconTheme: MaterialStateProperty.all(
							const IconThemeData(color: Colors.black87),
						),
						elevation: 0,
						surfaceTintColor: Colors.transparent,
						shadowColor: Colors.transparent,
						height: 64,
					),
					dividerColor: Colors.transparent,
					dividerTheme: const DividerThemeData(
						color: Colors.transparent,
						thickness: 0,
						space: 0,
					),
				),
				home: const GateKeeper(),
			),
		);
  }
}

class GateKeeper extends StatefulWidget {
  const GateKeeper({super.key});
  @override
  State<GateKeeper> createState() => _GateKeeperState();
}

class _GateKeeperState extends State<GateKeeper> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _checkPerms();
  }

  Future<void> _checkPerms() async {
    // 第一道门卡：系统通知权限
    final hasNoti = await _areNotificationsEnabled();
    if (!hasNoti) {
      // 直接触发系统通知授权弹框，无自定义弹框
      try {
        // /* EARLY-BLOCKED */ // REMOVED: early notification request (only request after Home visible)
/* END */  // removed: request only after Home is visible // 非阻塞，避免按Home后恢复黑屏/卡顿
      } catch (_) {}
      // 再次检查，如果仍未授权，则尝试打开系统设置界面
      final stillNo = !(await _areNotificationsEnabled());
      if (stillNo) {
        try { await _openNotificationSettings(); } catch (_) {}
      }
    }

      /* DEFER_EXACT_TO_HOME_START */
if (false) {
// 第二道门卡：精确闹钟权限（仅 Android，仅首次打开弹框）
  final _first = await _isFirstOpenAndMark();
  if (_first) {
// 第二道门卡：精确闹钟权限（仅 Android）
    final hasExact = await PermHelper.hasExactAlarmPermission();
    if (!hasExact && mounted) {
      final allow = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx)=> AlertDialog(
          title: const Text('闹钟提醒权限授权'),
          content: const Text('为确保定点提醒，请授予“闹钟与提醒(精确闹钟)”权限。'),
          actions: [
            TextButton(onPressed: ()=> Navigator.of(ctx).pop(false), child: const Text('不允许')),
            FilledButton(onPressed: ()=> Navigator.of(ctx).pop(true), child: const Text('允许')),
          ],
        ),
      );
      if (allow == true) {
        await PermHelper.requestExactAlarmPermission();
        // 返回键回到此处后直接进入首页
  } // 非首次：跳过弹框
      } else {
        // 小确认框：是 / 否
        final go = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx)=> AlertDialog(
            content: const Text('你将不启用精准闹钟提醒功能！'),
            actions: [
              TextButton(onPressed: ()=> Navigator.of(ctx).pop(false), child: const Text('否')),
              FilledButton(onPressed: ()=> Navigator.of(ctx).pop(true), child: const Text('是')),
            ],
          ),
        );
        if (go != true) {
          // 停留在当前闹钟提醒框层面（重新弹出第二道门卡）
          _checkPerms();
          return;
        }
      }
    }

    
}
/* DEFER_EXACT_TO_HOME_END */
setState(()=> _ready = true);
  }

  Future<bool> _areNotificationsEnabled() async {
    try {
      const ch = MethodChannel('com.example.quote_app/sys');
      final ok = await ch.invokeMethod<bool>('areNotificationsEnabled');
      return ok ?? true;
    } catch (_) {
      // 如果原生未实现，默认通过（实际发送时也会失败不崩溃）
      return true;
    }
  }

  Future<void> _openNotificationSettings() async {
    try {
      const ch = MethodChannel('com.example.quote_app/sys');
      await ch.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // 加载页面（权限检查）阶段恢复为默认白色背景
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const RootShell();
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _idx = 0;
  int _drawerStyleSeed = DateTime.now().microsecondsSinceEpoch;
  int _drawerRevealSeed = DateTime.now().microsecondsSinceEpoch;
  int _drawerHeaderRequestId = 0;
  String _drawerAiTitle = '成长宇宙';
  String _drawerAiSubtitle = '每个模块都可呈现不同形态、节奏与光影';
  bool _drawerAiLoading = false;
  bool _drawerHeaderAiEnabled = false;
  String _drawerSearchQuery = '';
  final TextEditingController _drawerSearchController = TextEditingController();
  final GlobalAiSettings _drawerAiSettings = GlobalAiSettings();
  final UnifiedAiService _drawerAiService = UnifiedAiService();
  final ScrollController _drawerScrollController = ScrollController();

  void _resetDrawerScrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        if (_drawerScrollController.hasClients) {
          _drawerScrollController.jumpTo(0);
        }
      } catch (_) {}
    });
  }

  double _drawerEntrySlotHeight(_DrawerEntrySpec entry, int index, int seed) {
    final r = math.Random((seed ^ index ^ entry.title.hashCode ^ 0x5F3759DF).abs());
    final styleMode = r.nextInt(16);
    switch (styleMode) {
      case 1: // timeline capsule
      case 4: // magnetic pill
      case 7: // ink line
        return 122;
      case 3: // poster tile
      case 12: // vertical orbit
        return 184;
      case 9: // step stack
      case 13: // magazine note
        return 166;
      case 2: // ticket block
      case 6: // split panel
      case 8: // constellation tile
      case 10: // brutal split
      case 11: // prism shard
      case 14: // neon circuit
        return 150;
      default:
        return 142;
    }
  }

  @override
  void dispose() {
    _drawerScrollController.dispose();
    _drawerSearchController.dispose();
    super.dispose();
  }

  Future<void> _handleSelectTab(int i) async {
    if (!mounted || i < 0 || i >= 5) return;
    setState(() { _idx = i; });
    try { SimpleBus.navIndex.value = i; } catch (_) {}
    if (i == 3) { SimpleBus.pokeLogs(); }
    if (i == 0) { try { SimpleBus.pokeHome(); } catch (_) {} }
  }

  List<_DrawerEntrySpec> _drawerEntries() => [
    _DrawerEntrySpec(
      icon: Icons.psychology_alt_outlined,
      title: '自我决定成长系统 · SDT Growth',
      subtitle: '今日面板 → 三大需要雷达 → 目标审查 → 动机光谱 → 最小行动 → 失败恢复 → 身份整合',
      badgeText: '独立模块：基于 Ryan & Deci 自我决定理论，把自主、胜任、关系转化为 AI 成长闭环',
      sequenceNumber: 40,
      pageBuilder: (_) => const SelfDeterminationGrowthHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.fence_outlined,
      title: '边界行动教练 · Boundary Action Coach',
      subtitle: '识别问题 → 区分责任 → 澄清价值 → 设计边界 → 练习表达 → 承担后果 → 支持复盘',
      badgeText: '独立模块：基于《Boundaries: When to Say Yes, How to Say No》的 AI 边界行动闭环',
      sequenceNumber: 39,
      pageBuilder: (_) => const BoundaryActionCoachHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.health_and_safety_outlined,
      title: '边界练习场 · Boundary Practice',
      subtitle: '边界自测 → 边界雷达 → AI场景教练 → 话术生成 → 行动后果 → 内疚管理 → 复盘成长',
      badgeText: '基于《Set Boundaries, Find Peace》核心思想：把边界从理念转化为清楚表达、行动跟进与稳定身份',
      sequenceNumber: 38,
      pageBuilder: (_) => const BoundaryPracticeHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.workspace_premium_outlined,
      title: '新榜 New Tablets',
      subtitle: '旧榜扫描 → 价值重估 → 谁在命令我 → 今日超克 → 主权承诺 → 坏良心转化 → 为创造而学习',
      badgeText: '尼采式自我超克、价值重估与主权个体训练系统：更能命令自己，更能创造价值',
      pageBuilder: (_) => const NewTabletsHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.change_circle_outlined,
      title: '成熟适应力罗盘 · Adaptation Compass',
      subtitle: '事件输入 → 防御识别 → 现实检查 → 成熟替代 → 关系修复 → 四维平衡 → 成人发展 → 生成性贡献 → 长期复盘',
      badgeText: '基于 George E. Vaillant《Adaptation to Life》：把痛苦、冲突和防御转化为工作、爱、游戏、身体照顾与生成性行动',
      pageBuilder: (_) => const AdaptationCompassHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.explore_outlined,
      title: '自我防御罗盘 · Ego Defense Compass',
      subtitle: '事件记录 → 自我三方地图 → 焦虑来源 → 防御机制 → 保护/代价 → 现实检验 → 小行动 → 月度成长报告',
      badgeText: '基于安娜·弗洛伊德《自我与防御机制》：看见防御，不羞辱自己；理解防御，不被防御控制',
      pageBuilder: (_) => const DefenseCompassHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.emoji_objects_outlined,
      title: '真实积极行动系统 · Realistic Positivity OS',
      subtitle: '真实看见 → 问题重构 → 感恩 → 允许为人 → 痛苦整合 → 价值绑定 → ABC行动 → Stretch Zone → 周整合',
      badgeText: '基于《哈佛积极心理学》Lecture 9–10：把感恩与改变训练成现实行动系统',
      pageBuilder: (_) => const RealisticPositivityOsHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.track_changes_outlined,
      title: 'WOOP 行动引擎 · 愿望转行动',
      subtitle: '愿望识别 → 最佳结果 → 内在障碍 → if–then 计划 → 24小时行动 → 失败复盘 → 继续/调整/放下',
      badgeText: '基于 Rethinking Positive Thinking：梦想与现实相撞，障碍变成行动入口',
      pageBuilder: (_) => const WoopActionEngineHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.psychology_alt_outlined,
      title: 'ActionMind · 行动心理学引擎',
      subtitle: '目标来源 → 目标内容 → 目标层级 → 心理对照 → if–then 执行意图 → 情绪资源 → 环境线索 → 社会互动 → 复盘整合',
      badgeText: '基于 The Psychology of Action：把愿望变成真实行动系统',
      pageBuilder: (_) => const ActionMindHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.self_improvement_outlined,
      title: '行愿 Compass · ACT 心理灵活性',
      subtitle: '心理灵活性雷达 → 每日三问 → AI ACT 教练 → 头脑故事识别 → 接纳训练 → 价值罗盘 → 承诺行动 → 行动复盘',
      badgeText: '带着痛苦，走向价值；看见头脑，不把方向盘交给头脑',
      pageBuilder: (_) => const ActCompassHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.psychology_alt_outlined,
      title: '第二念 · 矛盾心理价值行动引擎',
      subtitle: '四型矛盾 → Go/No 地图 → 内在委员会 → 价值澄清 → 全局画布 → 改变语言 → 行动实验 → 复盘整合',
      badgeText: '基于 On Second Thought：在矛盾中看见价值，在行动中塑造自己',
      pageBuilder: (_) => const SecondThoughtHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.explore_outlined,
      title: '向内生长 · MI 成长向导',
      subtitle: '价值罗盘 → 参与聚焦唤起计划 → 改变语言 → 小步行动 → 温和复盘 → 帮助者训练',
      badgeText: '基于动机式访谈：尊严、自主、伙伴关系、慈悲、赋能',
      pageBuilder: (_) => const MiGrowthHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.all_inclusive,
      title: '可持续卓越实验室',
      subtitle: '目标实验 → 压力恢复 → 失败学习 → 完美主义转卓越 → 过程享受 → 成长证据',
      badgeText: '压力有恢复，失败可学习，卓越不是完美',
      pageBuilder: (_) => const SustainableExcellenceHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.auto_awesome_outlined,
      title: '现实主义乐观训练系统',
      subtitle: '强度分级 → 情绪允许 → 解释雷达 → 双镜头重构 → 5分钟行动 → 失败免疫 → 感恩品味 → 身份沉淀',
      badgeText: 'Lecture 7-9 · 从 Fault Finder 到 Benefit Finder',
      pageBuilder: (_) => const RealisticOptimismTrainingHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.lightbulb_outline,
      title: '现实乐观信念行动系统',
      subtitle: '四分钟墙 → 现实校准 → 期待重构 → 环境启动 → 行动实验 → 失败复盘 → 基线上移',
      badgeText: '信念不是魔法，而是行动发动机',
      pageBuilder: (_) => const RealisticOptimismHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.psychology_alt_outlined,
      title: '足下认知一致性',
      subtitle: '源书工作台 → 不一致雷达 → 自我辩护镜子 → 现实检验 → 承诺行动 → 成长档案',
      badgeText: '在矛盾中看见自己，在行动中重建一致',
      pageBuilder: (_) => const CognitiveConsistencyHomePage(initialTabIndex: 8),
    ),
    _DrawerEntrySpec(
      icon: Icons.psychology_alt_outlined,
      title: '认知失调解决方法中心',
      subtitle: '行为一致化 → 解释重评 → 现实接触 → 反态度实验 → 责任修复 → 人际平衡',
      badgeText: '直接选择方法，把矛盾转成行动证据',
      pageBuilder: (_) => const CognitiveConsistencyHomePage(initialTabIndex: 9),
    ),
    _DrawerEntrySpec(
      icon: Icons.volunteer_activism_outlined,
      title: '足下真实自我',
      subtitle: '羞耻触发 → 责任边界 → 现实行动 → 身份证据',
      badgeText: '从羞耻到有尊严的行动',
      pageBuilder: (_) => const ShameTransformHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.account_balance_outlined,
      title: '中国传统文化与哲学思想',
      subtitle: '经典文本 → 诸子百家 → 修身实践 → 知行任务',
      badgeText: '即将上线 · 开发收尾中',
      pageBuilder: (_) => const _UpcomingModulePage(
        icon: Icons.account_balance_outlined,
        title: '中国传统文化与哲学思想',
        subtitle: '以中国传统文化、诸子百家与修身思想为核心，连接经典阅读、哲学脉络、现实修行与每日知行任务。',
        badgeText: '即将上线 · 开发收尾中',
      ),
    ),
    _DrawerEntrySpec(
      icon: Icons.public_outlined,
      title: '西方文化与哲学思想',
      subtitle: '古希腊 → 近现代思想 → 人文精神 → 现实辨析',
      badgeText: '即将上线 · 开发收尾中',
      pageBuilder: (_) => const _UpcomingModulePage(
        icon: Icons.public_outlined,
        title: '西方文化与哲学思想',
        subtitle: '从古希腊哲学、人文主义、启蒙思想到现代文化议题，帮助用户建立横向比较与现实判断能力。',
        badgeText: '即将上线 · 开发收尾中',
      ),
    ),
    _DrawerEntrySpec(
      icon: Icons.psychology_outlined,
      title: '心理学',
      subtitle: '心理机制 → 自我觉察 → 行为实验 → 日常复盘',
      badgeText: '即将上线 · 开发收尾中',
      pageBuilder: (_) => const _UpcomingModulePage(
        icon: Icons.psychology_outlined,
        title: '心理学',
        subtitle: '围绕认知、情绪、人格、关系与行为改变，提供系统学习、情境练习和可复盘的生活实验。',
        badgeText: '即将上线 · 开发收尾中',
      ),
    ),
    _DrawerEntrySpec(
      icon: Icons.fact_check_outlined,
      title: '行为观察',
      subtitle: '时间日志 → 行为证据 → 情绪触发 → 认知结果 → 定期复盘',
      badgeText: '记录我做了什么、为什么做、产生了什么结果',
      pageBuilder: (_) => const BehaviorTrackingHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.compare_arrows_outlined,
      title: '语义一致性精判',
      subtitle: 'Embedding 粗筛 → 语言模型裁判 → 严格事实/标题忠实性判断',
      badgeText: '全局语义精判引擎',
      pageBuilder: (_) => const SemanticConsistencyPage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.auto_awesome_mosaic_outlined,
      title: '人生注解',
      subtitle: '写下经历 → AI深度解读 → 思想匹配 → 治愈书单',
      badgeText: 'AI经历解读与疗愈阅读',
      pageBuilder: (_) => const LifeNoteHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.psychology_outlined,
      title: '意志实验室',
      subtitle: '知识总览 → 问题诊断 → 现实任务 → 复盘中心 → 镜像城',
      badgeText: '基于威廉詹姆斯创作',
      pageBuilder: (_) => const WillModuleHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.track_changes_outlined,
      title: '目标人生',
      subtitle: '愿景与目标 → 目标主页 → 情境触发 → 专注反思',
      badgeText: '基于泰勒·本沙哈尔老师创作',
      pageBuilder: (_) => const GoalThemeHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.flag,
      title: '目标设定知行课',
      subtitle: '课程母本 → 深度理解 → 问题诊断 → 现实行动 → 复盘成长',
      badgeText: '基于泰勒·本沙哈尔老师创作',
      pageBuilder: (_) => const GoalSettingModuleHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.auto_stories_outlined,
      title: '知行合一幸福课',
      subtitle: '39单元课程 → 知行城 → 现实行动 → 复盘闭环',
      badgeText: '基于泰勒·本沙哈尔老师创作',
      pageBuilder: (_) => const HappinessModuleHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.health_and_safety_outlined,
      title: '压力与恢复知行实验室',
      subtitle: '20单元课程母本 → 分城区知行城 → 周报/月报 → 长期成长剧情',
      badgeText: '基于泰勒·本沙哈尔老师创作',
      pageBuilder: (_) => const StressModuleHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.lightbulb_outline,
      title: '积极心理知行课',
      subtitle: '37段课程 → 深度理解 → 虚拟操练 → 现实行动 → 复盘成长',
      badgeText: '基于泰勒·本沙哈尔老师创作',
      pageBuilder: (_) => const PositivePsychModuleHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.school_outlined,
      title: '知行书院',
      subtitle: '27段课程 → 虚拟世界 → 现实行动 → 反思复盘',
      badgeText: '基于泰勒·本沙哈尔老师创作',
      pageBuilder: (_) => const YangmingModuleHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.psychology_alt_outlined,
      title: '失败与完美主义',
      subtitle: '3P急救 → 概念地图 → 行动模板 → 学习卡',
      badgeText: '基于泰勒·本沙哈尔老师创作',
      pageBuilder: (_) => const FailureModuleHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.auto_awesome,
      title: '信念工坊',
      subtitle: '微实验 → 案例 → 最小行动 → 生活落地',
      badgeText: '基于泰勒·本沙哈尔老师创作',
      pageBuilder: (_) => const BeliefLabHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.self_improvement_outlined,
      title: '有意识的改变',
      subtitle: '学习模块入口 · 导入课程 · 按章按节学习',
      badgeText: '有意识练习，持续改变',
      pageBuilder: (_) => const ConsciousChangeHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.psychology_alt_outlined,
      title: '改变实验室',
      subtitle: '改变总览 → 19张概念卡 → AI教练 → 现实任务 → 镜像世界',
      badgeText: '基于泰勒·本沙哈尔老师创作',
      pageBuilder: (_) => const ChangeLabShellPage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.extension_outlined,
      title: '概念实践引擎',
      subtitle: '概念解析 → 场景生成 → 虚拟挑战 → 结果复盘',
      badgeText: '概念实践引擎',
      pageBuilder: (_) => const ConceptEngineHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.cloud_sync_outlined,
      title: '外部数据同步',
      subtitle: 'Microsoft OneNote + To Do → 统一登录 → 结构化同步与写回',
      badgeText: '外部数据同步',
      pageBuilder: (_) => const ExternalDataSyncHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.record_voice_over_outlined,
      title: '美好的祝福',
      subtitle: 'ElevenLabs 声音克隆 → 文字转语音 → 文件库 → AI 对话',
      badgeText: '美好的祝福',
      pageBuilder: (_) => const VoiceLabHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.movie_creation_outlined,
      title: '电影角色实验室',
      subtitle: '选电影 → 选角色 → 进入场景 → AI对戏 → 导演复盘',
      badgeText: '电影角色实验室',
      pageBuilder: (_) => const MovieRoleLabHomePage(),
    ),
    _DrawerEntrySpec(
      icon: Icons.self_improvement_outlined,
      title: '真实自尊 SelfWorth AI',
      subtitle: '第37模块 · 自尊地图 → 三层自尊 → 真实关系 → 六项实践 → 认可戒断 → 复原力 → 责任目标 → AI场景教练',
      badgeText: '第37模块 · 基于《哈佛幸福课》第21集后半与第22集：从被认可走向被了解，用真实、责任、行动与接纳建立稳定自尊',
      sequenceNumber: 37,
      pageBuilder: (_) => const SelfWorthAiHomePage(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    SchedulerService.scheduleNextForAll();
    // Ensure runtime unlock receivers on first launch (post-frame)
    Future.delayed(const Duration(milliseconds: 80), () { try { NativeGuard.ensureRuntimeReceiversRegistered(); } catch (_) {} });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final launchedViaPlugin = await NotificationService.didLaunchFromNotification();
        final launchedViaFlag   = NotificationService.consumeLaunchFromNotificationFlag();
        final viaNativeChannel  = await NativeGuard.consumeLaunchFromNotificationFlag();
        if (launchedViaPlugin || launchedViaFlag || viaNativeChannel) {
          final handled = await NotificationService.handlePendingNotificationNavigation();
          try {
            await DLog.i(
              'NotifTap',
              'RootShell postFrame: plugin=$launchedViaPlugin flag=$launchedViaFlag native=$viaNativeChannel handled=$handled',
            );
          } catch (_) {}
          if (!handled) {
            SimpleBus.navHome();
          }
        }
      } catch (_) {}
    });
    // Navigate to home if launched from notification (foreground/background/terminated)
    Future.delayed(const Duration(milliseconds: 60), () async {
      try {
        if (await NotificationService.handlePendingNotificationNavigation()) {
          try {
            DLog.i('NotifTap', 'RootShell delayed check: notification handled');
          } catch (_) {}
        }
      } catch (_) {}
    });
    // Listen for navigation requests (e.g., notification taps)
    SimpleBus.navIndex.addListener(() {
      final i = SimpleBus.navIndex.value;
      if (i >= 0 && i < 5 && i != _idx) {
        setState(() { _idx = i; });
        try { SimpleBus.navIndex.value = i; } catch (_) {}
        if (i == 3) { SimpleBus.pokeLogs(); }
        if (i == 0) { try { SimpleBus.pokeHome(); } catch (_) {} }
      }
    });
    // 主动清理可能残留的自检任务（自检已禁用）
    SchedulerService.scheduleSelfCheck();

    try { SimpleBus.navIndex.value = _idx; } catch (_) {}
  }

  bool _isPinnedDrawerEntry(_DrawerEntrySpec entry) {
    // New Tablets is a newly added first-class module.  The drawer intentionally
    // randomizes most module cards on every open, but that can make a new module
    // look as if it disappeared in a long drawer.  Keep high-priority modules at
    // the top and only shuffle the remaining entries.
    return entry.title.startsWith('新榜 New Tablets');
  }

  List<_DrawerEntrySpec> _drawerEntriesInRandomOrder(List<_DrawerEntrySpec> source, int seed) {
    final selfWorthEntry = source.where((e) => e.title == '真实自尊 SelfWorth AI').toList(growable: false);
    final entries = source.where((e) => e.title != '真实自尊 SelfWorth AI').toList(growable: false);
    if (entries.length > 1) {
      final r = math.Random((seed ^ 0x6C8E9CF5).abs());
      for (var i = entries.length - 1; i > 0; i--) {
        final j = r.nextInt(i + 1);
        final tmp = entries[i];
        entries[i] = entries[j];
        entries[j] = tmp;
      }
    }
    return <_DrawerEntrySpec>[...entries, ...selfWorthEntry];
  }

  Widget _buildDrawerEntryCard(_DrawerEntrySpec entry, int index, int totalCount) {
    return _DrawerStaggeredReveal(
      key: ValueKey('reveal_${_drawerRevealSeed}_${entry.title}_$index'),
      index: index,
      totalCount: totalCount,
      seed: _drawerRevealSeed,
      child: _AnimatedDrawerEntryCard(
        key: ValueKey('${_drawerStyleSeed}_${entry.title}_$index'),
        icon: entry.icon,
        title: entry.title,
        subtitle: entry.subtitle,
        badgeText: entry.badgeText,
        index: index,
        displayNumber: entry.sequenceNumber ?? index + 1,
        seed: _drawerStyleSeed,
        onTap: () {
          final navigator = Navigator.of(context);
          navigator.pop();
          navigator.push(MaterialPageRoute(builder: entry.pageBuilder));
        },
      ),
    );
  }

  Future<void> _refreshDrawerHeaderByAi(List<_DrawerEntrySpec> entries) async {
    final requestId = ++_drawerHeaderRequestId;
    final seed = _drawerStyleSeed.toString();
    final localFallback = _localDrawerHeaderFallback(seed);
    final aiEnabled = await _drawerAiSettings.isDrawerHeaderAiEnabled();
    if (!mounted || requestId != _drawerHeaderRequestId) return;
    setState(() {
      _drawerHeaderAiEnabled = aiEnabled;
      _drawerAiLoading = aiEnabled;
      _drawerAiTitle = localFallback.$1;
      _drawerAiSubtitle = localFallback.$2;
    });
    if (!aiEnabled) return;

    try {
      final modulesThemeText = entries
          .map((e) => '${e.title}：${e.subtitle}')
          .join('\n');
      final template = await _drawerAiSettings.getDrawerHeaderPrompt();
      final prompt = _drawerAiSettings.renderTemplate(template, <String, String>{
        'modules_theme_text': modulesThemeText,
        'random_seed': seed,
      });
      final raw = await _drawerAiService.generateText(
        prompt: prompt,
        purpose: 'drawer_header.random_title',
        systemPrompt: '只输出一个JSON对象，不要解释。',
        maxTokens: 120,
        expectJson: true,
        temperature: 0.9,
      );
      final parsed = _parseDrawerHeaderJson(raw);
      if (!mounted || requestId != _drawerHeaderRequestId) return;
      setState(() {
        _drawerAiTitle = parsed.$1;
        _drawerAiSubtitle = parsed.$2;
        _drawerAiLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _drawerHeaderRequestId) return;
      setState(() {
        _drawerAiLoading = false;
      });
    }
  }

  (String, String) _localDrawerHeaderFallback(String seed) {
    final r = math.Random(seed.hashCode);
    const titles = <String>['知行星图', '意志引擎', '成长剧场', '行动宇宙', '精神工坊', '内在航线', '人生试炼场'];
    const subtitles = <String>['把思想化成行动', '让每次打开都有新路', '在练习中改变自己', '从觉察走向实践', '把课程变成生活'];
    return (titles[r.nextInt(titles.length)], subtitles[r.nextInt(subtitles.length)]);
  }

  (String, String) _parseDrawerHeaderJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceAll(RegExp(r'^```json\s*', multiLine: true), '').replaceAll(RegExp(r'^```\s*', multiLine: true), '').replaceAll('```', '').trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) text = text.substring(start, end + 1);
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw const FormatException('drawer header json is not an object');
    final rawTitle = (decoded['title'] ?? '').toString().trim();
    final rawSubtitle = (decoded['subtitle'] ?? '').toString().trim();
    final title = _limitCjkText(rawTitle.isEmpty ? '知行星图' : rawTitle, 10);
    final subtitle = _limitCjkText(rawSubtitle.isEmpty ? '把思想化成行动' : rawSubtitle, 18);
    return (title, subtitle);
  }

  String _limitCjkText(String text, int maxChars) {
    final clean = text.replaceAll(RegExp(r'\s+'), '');
    if (clean.runes.length <= maxChars) return clean;
    return String.fromCharCodes(clean.runes.take(maxChars));
  }


  List<_DrawerEntrySpec> _filterDrawerEntries(List<_DrawerEntrySpec> entries) {
    final q = _drawerSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries.where((e) {
      final haystack = '${e.title}\n${e.subtitle}\n${e.badgeText}'.toLowerCase();
      return haystack.contains(q);
    }).toList(growable: false);
  }

  Widget _buildDrawerSearchBox(int resultCount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _drawerSearchController,
        onChanged: (value) => setState(() => _drawerSearchQuery = value),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: _drawerSearchQuery.trim().isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _drawerSearchController.clear();
                    setState(() => _drawerSearchQuery = '');
                  },
                ),
          hintText: '搜索模块：新榜 / New Tablets / 尼采',
          helperText: _drawerSearchQuery.trim().isEmpty ? '新榜已固定置顶；其余模块仍随机展示' : '找到 $resultCount 个模块',
          filled: true,
          fillColor: Colors.white.withOpacity(0.72),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.white.withOpacity(0.8))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.white.withOpacity(0.8))),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_drawerAiLoading ? 25 : 18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _drawerAiLoading
                        ? const [Color(0xFF7C3AED), Color(0xFF06B6D4)]
                        : const [Color(0xFF111827), Color(0xFF4338CA)],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33111827), blurRadius: 18, offset: Offset(0, 8)),
                  ],
                ),
                child: Icon(_drawerAiLoading ? Icons.auto_awesome_motion : Icons.auto_awesome, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 360),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeInCubic,
                  child: Column(
                    key: ValueKey('${_drawerAiTitle}_${_drawerAiSubtitle}_$_drawerAiLoading'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_drawerAiTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                      const SizedBox(height: 3),
                      Text(_drawerAiSubtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedContainer(
            duration: const Duration(milliseconds: 380),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(_drawerAiLoading ? 0.72 : 0.58),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.9)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_drawerAiLoading ? Icons.bolt_outlined : Icons.motion_photos_on_outlined, size: 16, color: const Color(0xFF4F46E5)),
                const SizedBox(width: 6),
                Text(
                  _drawerAiLoading ? 'AI正在生成本次侧栏主题' : (_drawerHeaderAiEnabled ? 'AI随机标题 · 多形态布局 · 模块差异化' : 'AI侧栏主题已关闭 · 使用本地随机主题'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDrawerModuleStats({required int totalCount, required int visibleCount}) {
    final searching = _drawerSearchQuery.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.64),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.widgets_outlined, size: 17, color: Color(0xFF4F46E5)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              searching ? '当前共 $totalCount 个模块 · 匹配 $visibleCount 个' : '当前共 $totalCount 个模块',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      const HistoryPage(),
      const DiscoverPage(),
      const LogsPage(),
      const SettingsPage(),
    ];
    final baseEntries = _drawerEntries();
    final randomizedEntries = _drawerEntriesInRandomOrder(baseEntries, _drawerStyleSeed);
    final entries = _filterDrawerEntries(randomizedEntries);
    return Scaffold(
      onDrawerChanged: (opened) {
        if (!mounted) return;
        if (opened) {
          // 注意：Drawer 在未展开时也可能已经被 Flutter 预构建。
          // 如果只在子组件 initState 中播放动画，动画会在抽屉不可见时提前跑完，
          // 用户看到的就是“所有模块一起显示”。
          // 因此每次真正打开抽屉时单独刷新 reveal seed，强制所有渐显组件重新从 0 播放；
          // 模块顺序仍使用上一次关闭时预生成的 _drawerStyleSeed，避免打开瞬间洗牌闪跳。
          setState(() { _drawerRevealSeed = DateTime.now().microsecondsSinceEpoch; });
          final entriesForAi = _drawerEntries();
          _resetDrawerScrollToTop();
          _refreshDrawerHeaderByAi(entriesForAi);
        } else {
          // 关闭时准备下一次打开的随机顺序和样式种子。
          final nextSeed = DateTime.now().microsecondsSinceEpoch;
          setState(() {
            _drawerStyleSeed = nextSeed;
            _drawerRevealSeed = nextSeed ^ 0x31AF09;
            _drawerSearchQuery = '';
            _drawerSearchController.clear();
          });
        }
      },
      drawerScrimColor: Colors.black54,
      drawer: Builder(
        builder: (context) {
          final size = MediaQuery.of(context).size;
          final w = math.min(size.width * 0.88, 420.0).toDouble();
          final bgRandom = math.Random(_drawerStyleSeed);
          final bgPalettes = <List<Color>>[
            const [Color(0xFFF7F5FF), Color(0xFFFFFFFF), Color(0xFFEFF6FF)],
            const [Color(0xFFFFF7ED), Color(0xFFFFFFFF), Color(0xFFF5F3FF)],
            const [Color(0xFFECFEFF), Color(0xFFFFFFFF), Color(0xFFFFFBEB)],
            const [Color(0xFFFDF2F8), Color(0xFFFFFFFF), Color(0xFFECFDF5)],
          ];
          final bgPalette = bgPalettes[bgRandom.nextInt(bgPalettes.length)];
          final orbA = [const Color(0xFF818CF8), const Color(0xFFF59E0B), const Color(0xFF10B981), const Color(0xFFEC4899)][bgRandom.nextInt(4)];
          final orbB = [const Color(0xFF38BDF8), const Color(0xFFA78BFA), const Color(0xFFF97316), const Color(0xFF14B8A6)][bgRandom.nextInt(4)];
          return Drawer(
            width: w,
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(34)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: bgPalette,
                  ),
                ),
                child: SafeArea(
                  child: Stack(
                    children: [
                      Positioned(
                        top: -48,
                        right: -28,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: orbA.withOpacity(0.12 + bgRandom.nextDouble() * 0.12),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 90,
                        left: -72,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: orbB.withOpacity(0.08 + bgRandom.nextDouble() * 0.10),
                          ),
                        ),
                      ),
                      // 必须使用 Positioned.fill 给滚动区明确约束，并用
                      // SingleChildScrollView + Column 一次性构建全部模块。
                      // 之前 ListView 在 Stack 中叠加随机动效与多次 setState 时，
                      // 部分设备会出现只构建/只绘制前几个模块，甚至打开时全空。
                      Positioned.fill(
                        child: SingleChildScrollView(
                          controller: _drawerScrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildDrawerHeader(),
                              _buildDrawerModuleStats(totalCount: baseEntries.length, visibleCount: entries.length),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _drawerSearchController,
                                onChanged: (value) => setState(() => _drawerSearchQuery = value),
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: '搜索模块标题 / 简介 / 关键词',
                                  prefixIcon: const Icon(Icons.search, color: Color(0xFF4F46E5)),
                                  suffixIcon: _drawerSearchQuery.trim().isEmpty
                                      ? null
                                      : IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () {
                                            _drawerSearchController.clear();
                                            setState(() => _drawerSearchQuery = '');
                                          },
                                        ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.72),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                                ),
                              ),
                              SizedBox(height: 8 + bgRandom.nextInt(8).toDouble()),
                              _buildDrawerSearchBox(entries.length),
                              if (entries.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.72), borderRadius: BorderRadius.circular(22)),
                                  child: const Text('没有匹配的模块，请换一个关键词。', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                                ),
                              for (var i = 0; i < entries.length; i++)
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: 12 + ((i + _drawerStyleSeed) % 3) * 2.0,
                                    left: ((i + _drawerStyleSeed) % 4 == 0) ? 4 : 0,
                                    right: ((i + _drawerStyleSeed) % 5 == 0) ? 8 : 0,
                                  ),
                                  child: SizedBox(
                                    height: _drawerEntrySlotHeight(entries[i], i, _drawerStyleSeed),
                                    child: ClipRect(
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: _buildDrawerEntryCard(entries[i], i, entries.length),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      backgroundColor: Colors.white,
      // 使用 IndexedStack 保持各页面的状态，避免切换时重新构建导致白屏或闪烁
      body: IndexedStack(index: _idx, children: pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 60, // reduce bottom bar height by another 10 (total -20)
          child: NavigationBar(
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            selectedIndex: _idx,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: '首页'),
              NavigationDestination(icon: Icon(Icons.history), label: '历史'),
              NavigationDestination(icon: Icon(Icons.travel_explore), label: '发现之旅'),
              NavigationDestination(icon: Icon(Icons.list), label: '日志'),
              NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
            ],
            onDestinationSelected: (i) { _handleSelectTab(i); },
          ),
        ),
      ),
    );
  }
}

class _DrawerEntrySpec {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeText;
  final int? sequenceNumber;
  final WidgetBuilder pageBuilder;

  const _DrawerEntrySpec({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    this.sequenceNumber,
    required this.pageBuilder,
  });
}

class _UpcomingModulePage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeText;

  const _UpcomingModulePage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 24,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(icon, size: 34, color: const Color(0xFF4F46E5)),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFC2410C),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.7,
                        color: Color(0xFF4B5563),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 18),
                    const Text(
                      '模块正在完成开发和上线准备。当前版本已先在首页左侧菜单开放入口，正式内容上线后将从这里直接进入。',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.65,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerStaggeredReveal extends StatefulWidget {
  final Widget child;
  final int index;
  final int totalCount;
  final int seed;

  const _DrawerStaggeredReveal({
    super.key,
    required this.child,
    required this.index,
    required this.totalCount,
    required this.seed,
  });

  @override
  State<_DrawerStaggeredReveal> createState() => _DrawerStaggeredRevealState();
}

class _DrawerStaggeredRevealState extends State<_DrawerStaggeredReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _delayMs;
  int _revealRunId = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
      value: 0.0,
    );
    _restartReveal();
  }

  @override
  void didUpdateWidget(covariant _DrawerStaggeredReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed ||
        oldWidget.index != widget.index ||
        oldWidget.totalCount != widget.totalCount) {
      _restartReveal();
    }
  }

  void _restartReveal() {
    final runId = ++_revealRunId;
    final r = math.Random((widget.seed ^ widget.index ^ widget.totalCount ^ 0x51EAD9).abs());
    // 5 秒内全部显示，但把阶梯间隔拉大到肉眼明显可见。
    // 以 15 个模块为例：相邻模块大约间隔 280ms；最后一个模块约 4.0s 开始、4.8s 内完成。
    // 这样既能明显看出“随机先后顺序 + 逐个渐显”，又不会让用户等待超过 5 秒。
    const maxStartMs = 3920;
    const firstStartMs = 120;
    final safeTotal = math.max(1, widget.totalCount);
    final gapMs = safeTotal <= 1 ? 0 : (maxStartMs / (safeTotal - 1)).floor();
    final rawDelay = firstStartMs + widget.index * gapMs + r.nextInt(90);
    _delayMs = math.min(maxStartMs, rawDelay).toInt();
    _controller.stop();
    _controller.value = 0.0;
    Future.delayed(Duration(milliseconds: _delayMs), () {
      if (!mounted || runId != _revealRunId) return;
      _controller.forward(from: 0.0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value).clamp(0.0, 1.0).toDouble();
        final direction = widget.index.isEven ? -1.0 : 1.0;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 56 * (1 - t)),
            child: Transform.rotate(
              angle: direction * 0.035 * (1 - t),
              child: Transform.scale(
                alignment: Alignment.topCenter,
                scale: 0.88 + 0.12 * t,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedDrawerEntryCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeText;
  final int index;
  final int displayNumber;
  final int seed;
  final VoidCallback onTap;

  const _AnimatedDrawerEntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.index,
    required this.displayNumber,
    required this.seed,
    required this.onTap,
  });

  @override
  State<_AnimatedDrawerEntryCard> createState() => _AnimatedDrawerEntryCardState();
}

class _AnimatedDrawerEntryCardState extends State<_AnimatedDrawerEntryCard> with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _breathController;
  late final int _styleMode;
  late final int _motionMode;
  late final double _widthFactor;
  late final double _startDx;
  late final double _startDy;
  late final double _restDx;
  late final double _angle;
  late final double _floatX;
  late final double _floatY;
  late final Alignment _alignment;
  late final List<Color> _palette;
  late final String _badgeText;

  @override
  void initState() {
    super.initState();
    final r = math.Random((widget.seed ^ widget.index ^ widget.title.hashCode ^ 0x5F3759DF).abs());
    _styleMode = r.nextInt(16);
    _motionMode = r.nextInt(14);
    _widthFactor = (0.88 + r.nextDouble() * 0.12).clamp(0.88, 1.0).toDouble();
    _startDx = -80 + r.nextDouble() * 160;
    _startDy = 24 + r.nextDouble() * 52;
    _restDx = -6 + r.nextDouble() * 12;
    _angle = -0.025 + r.nextDouble() * 0.05;
    _floatX = 0.9 + r.nextDouble() * 2.4;
    _floatY = 1.2 + r.nextDouble() * 3.6;
    _alignment = r.nextBool() ? Alignment.centerLeft : Alignment.centerRight;
    _palette = _palettes[r.nextInt(_palettes.length)];
    _badgeText = widget.badgeText;

    // 内部复杂形变保持终态，只保留微浮动呼吸效果；
    // 抽屉打开时的随机渐显统一交给外层 _DrawerStaggeredReveal 控制。
    // 这样既有先后渐显，又不会因为远距离位移/透明叠加导致模块少显示或全空。
    _entryController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 260 + r.nextInt(220)),
      value: 1.0,
    );
    _breathController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1900 + r.nextInt(2800)),
    )..repeat(reverse: true);

    // 保留 breathing/微浮动随机动效；内部卡片本身始终完成布局，确保每次打开数量稳定。
    _entryController.value = 1.0;
  }

  static const List<List<Color>> _palettes = [
    [Color(0xFF4F46E5), Color(0xFFEEF2FF), Color(0xFFFFFFFF), Color(0xFF111827)],
    [Color(0xFFD97706), Color(0xFFFFF7ED), Color(0xFFFFFFFF), Color(0xFF1F2937)],
    [Color(0xFF059669), Color(0xFFECFDF5), Color(0xFFFFFFFF), Color(0xFF064E3B)],
    [Color(0xFFDB2777), Color(0xFFFDF2F8), Color(0xFFFFFFFF), Color(0xFF831843)],
    [Color(0xFF7C3AED), Color(0xFFF5F3FF), Color(0xFFFFFFFF), Color(0xFF2E1065)],
    [Color(0xFF0284C7), Color(0xFFE0F2FE), Color(0xFFFFFFFF), Color(0xFF0C4A6E)],
    [Color(0xFFEA580C), Color(0xFFFFFBEB), Color(0xFFFFFFFF), Color(0xFF7C2D12)],
    [Color(0xFF0891B2), Color(0xFFECFEFF), Color(0xFFFFFFFF), Color(0xFF164E63)],
    [Color(0xFFBE123C), Color(0xFFFFF1F2), Color(0xFFFFFFFF), Color(0xFF881337)],
    [Color(0xFF4338CA), Color(0xFFEFF6FF), Color(0xFFFFFFFF), Color(0xFF172554)],
  ];

  @override
  void dispose() {
    _entryController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _palette[0];
    final soft = _palette[1];
    final textDark = _palette[3];
    final subtitleParts = widget.subtitle
        .split('→')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(_styleMode == 9 ? 4 : (_styleMode == 4 ? 3 : 5))
        .toList();

    return AnimatedBuilder(
      animation: Listenable.merge([_entryController, _breathController]),
      builder: (context, child) {
        final raw = math.max(_entryController.value, 0.72).clamp(0.0, 1.0).toDouble();
        final entry = Curves.easeOutBack.transform(raw).clamp(0.0, 1.0).toDouble();
        final fade = math.max(0.78, Curves.easeOutCubic.transform(raw)).clamp(0.0, 1.0).toDouble();
        final breath = Curves.easeInOut.transform(_breathController.value);
        final wave = math.sin(breath * math.pi * 2 + widget.index * .73);
        final pulse = (wave + 1.0) / 2.0;
        final body = _buildPresentation(
          styleMode: _styleMode,
          accent: accent,
          soft: soft,
          textDark: textDark,
          subtitleParts: subtitleParts,
          pulse: pulse,
        );

        return Opacity(
          opacity: fade,
          child: FractionallySizedBox(
            widthFactor: _widthFactor,
            alignment: _alignment,
            child: Transform(
              alignment: Alignment.center,
              transform: _motionTransform(entry, wave),
              child: Transform.translate(
                offset: Offset(_restDx + wave * _floatX, wave * _floatY),
                child: _TapShell(
                  onTap: widget.onTap,
                  radius: _tapRadiusForStyle(_styleMode),
                  child: body,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Matrix4 _motionTransform(double entry, double wave) {
    final m = Matrix4.identity();
    switch (_motionMode) {
      case 0: // bottom mist rising
        m.translate(_startDx * 0.16 * (1 - entry), _startDy * (1 - entry));
        m.scale(0.84 + entry * 0.16);
        m.rotateZ(_angle * entry + wave * 0.002);
        break;
      case 1: // side slide
        m.translate(_startDx * (1 - entry), 0.0);
        m.scale(0.92 + entry * 0.08);
        break;
      case 2: // pop zoom
        m.scale(0.72 + 0.28 * entry + wave.abs() * 0.004);
        m.rotateZ(_angle * (1 - entry));
        break;
      case 3: // soft card flip
        m.setEntry(3, 2, 0.001);
        m.rotateY((1 - entry) * (_startDx >= 0 ? -0.72 : 0.72));
        m.translate(0.0, 16 * (1 - entry));
        break;
      case 4: // diagonal drift
        m.translate(_startDx * 0.52 * (1 - entry), -22 * (1 - entry));
        m.rotateZ(_angle * (1.2 - entry) + wave * 0.003);
        break;
      case 5: // orbit-like entrance
        final swirl = (1 - entry) * math.pi * 1.4;
        m.translate(math.cos(swirl) * 42 * (1 - entry), math.sin(swirl) * 34 * (1 - entry));
        m.scale(0.80 + entry * 0.20);
        break;
      case 6: // drop down
        m.translate(0.0, -52 * (1 - entry));
        m.scale(1.06 - 0.06 * entry, 0.90 + 0.10 * entry);
        break;
      case 7: // slight shake settle
        m.translate((_startDx * 0.30 + math.sin(entry * math.pi * 5) * 12) * (1 - entry), _startDy * .45 * (1 - entry));
        m.rotateZ(_angle * math.sin(entry * math.pi));
        break;
      case 8: // hinge open
        m.setEntry(3, 2, 0.001);
        m.rotateZ(_angle * (1 - entry));
        m.rotateX((1 - entry) * 0.42);
        m.translate(0.0, 24 * (1 - entry));
        break;
      case 9: // magnetic snap
        m.translate(math.sin(entry * math.pi * 3) * 18 * (1 - entry), math.cos(entry * math.pi * 2) * 20 * (1 - entry));
        m.scale(0.68 + entry * .32);
        break;
      case 10: // parallax float-in
        m.translate(_startDx * .22 * (1 - entry), _startDy * .70 * (1 - entry));
        m.rotateZ(_angle * (1 - entry) + wave * .004);
        m.scale(0.78 + entry * .22, 0.94 + entry * .06);
        break;
      case 11: // stage curtain
        m.setEntry(3, 2, 0.001);
        m.translate(0.0, -18 * (1 - entry));
        m.scale(0.58 + .42 * entry, 1.0);
        break;
      case 12: // comet streak
        m.translate((_startDx > 0 ? 130 : -130) * (1 - entry), -28 * (1 - entry));
        m.rotateZ((_startDx > 0 ? .09 : -.09) * (1 - entry));
        m.scale(0.76 + .24 * entry);
        break;
      case 13: // depth rise
        m.setEntry(3, 2, 0.0012);
        m.translate(0.0, 48 * (1 - entry));
        m.rotateY((_startDx >= 0 ? .38 : -.38) * (1 - entry));
        m.scale(0.70 + .30 * entry);
        break;
      default: // fade + grow from the module's own center
        m.translate(0.0, 18 * (1 - entry));
        m.scale(0.86 + 0.14 * entry, 0.70 + 0.30 * entry);
        break;
    }
    return m;
  }

  double _tapRadiusForStyle(int mode) {
    switch (mode) {
      case 1:
      case 4:
        return 999;
      case 3:
      case 8:
        return 32;
      case 7:
        return 12;
      default:
        return 24;
    }
  }

  Widget _buildPresentation({
    required int styleMode,
    required Color accent,
    required Color soft,
    required Color textDark,
    required List<String> subtitleParts,
    required double pulse,
  }) {
    switch (styleMode) {
      case 0:
        return _glassIsland(accent, soft, textDark, subtitleParts, pulse);
      case 1:
        return _timelineCapsule(accent, soft, textDark, subtitleParts, pulse);
      case 2:
        return _ticketBlock(accent, soft, textDark, subtitleParts, pulse);
      case 3:
        return _posterTile(accent, soft, textDark, subtitleParts, pulse);
      case 4:
        return _magneticPill(accent, soft, textDark, subtitleParts, pulse);
      case 5:
        return _ribbonBanner(accent, soft, textDark, subtitleParts, pulse);
      case 6:
        return _splitPanel(accent, soft, textDark, subtitleParts, pulse);
      case 7:
        return _inkLine(accent, soft, textDark, subtitleParts, pulse);
      case 8:
        return _constellationTile(accent, soft, textDark, subtitleParts, pulse);
      case 9:
        return _stepStack(accent, soft, textDark, subtitleParts, pulse);
      case 10:
        return _brutalSplit(accent, soft, textDark, subtitleParts, pulse);
      case 11:
        return _prismShard(accent, soft, textDark, subtitleParts, pulse);
      case 12:
        return _verticalOrbit(accent, soft, textDark, subtitleParts, pulse);
      case 13:
        return _magazineNote(accent, soft, textDark, subtitleParts, pulse);
      case 14:
        return _neonCircuit(accent, soft, textDark, subtitleParts, pulse);
      default:
        return _seedTile(accent, soft, textDark, subtitleParts, pulse);
    }
  }

  Widget _glassIsland(Color accent, Color soft, Color textDark, List<String> parts, double pulse) {
    return Container(
      constraints: const BoxConstraints(minHeight: 108),
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18 + (widget.index % 5) * 4),
          topRight: Radius.circular(34 - (widget.index % 4) * 3),
          bottomLeft: const Radius.circular(30),
          bottomRight: Radius.circular(18 + (widget.index % 6) * 3),
        ),
        gradient: LinearGradient(colors: [soft.withOpacity(.98), Colors.white.withOpacity(.86), accent.withOpacity(.13)]),
        border: Border.all(color: Colors.white.withOpacity(.75 + pulse * .2)),
        boxShadow: [BoxShadow(color: accent.withOpacity(.10 + pulse * .08), blurRadius: 22 + pulse * 14, offset: Offset(0, 8 + pulse * 8))],
      ),
      child: Stack(children: [
        Positioned(right: -22, top: -30, child: _orb(accent, 86, .07 + pulse * .04)),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _iconBox(accent, mode: 0),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [Expanded(child: _title(textDark, maxLines: 1)), const SizedBox(width: 8), _badge(accent, _badgeText)]),
            const SizedBox(height: 9),
            Wrap(spacing: 6, runSpacing: 6, children: parts.map((e) => _chip(e, accent)).toList()),
          ])),
          const SizedBox(width: 6),
          _arrow(accent),
        ]),
      ]),
    );
  }

  Widget _timelineCapsule(Color accent, Color soft, Color textDark, List<String> parts, double pulse) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
          width: 54,
          child: Column(children: [
            Container(width: 4, height: 15, decoration: BoxDecoration(color: accent.withOpacity(.20), borderRadius: BorderRadius.circular(99))),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withOpacity(.92), boxShadow: [BoxShadow(color: accent.withOpacity(.25 + pulse * .12), blurRadius: 18, offset: const Offset(0, 6))]),
              child: Icon(widget.icon, color: Colors.white, size: 23),
            ),
            Container(width: 4, height: 15, decoration: BoxDecoration(color: accent.withOpacity(.20), borderRadius: BorderRadius.circular(99))),
          ]),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.64),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: accent.withOpacity(.16)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.045), blurRadius: 14, offset: const Offset(0, 7))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [Expanded(child: _title(textDark)), _badge(accent, _badgeText)]),
              const SizedBox(height: 7),
              Text(parts.join(' / '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.2, height: 1.35, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        _arrow(accent),
      ]),
    );
  }

  Widget _ticketBlock(Color accent, Color soft, Color textDark, List<String> parts, double pulse) {
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.82),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withOpacity(.18)),
          boxShadow: [BoxShadow(color: accent.withOpacity(.10 + pulse * .06), blurRadius: 19, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Container(
            width: 58,
            height: 76,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accent, accent.withOpacity(.55)])),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(widget.icon, color: Colors.white, size: 24),
              const SizedBox(height: 7),
              Text('${widget.displayNumber}'.padLeft(2, '0'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [Expanded(child: _title(textDark, maxLines: 2)), _badge(accent, _badgeText)]),
            const SizedBox(height: 7),
            Text(parts.join(' → '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.4, height: 1.35, color: Color(0xFF4B5563), fontWeight: FontWeight.w700)),
          ])),
          const SizedBox(width: 10),
          _arrow(accent),
        ]),
      ),
      Positioned(left: -10, top: 46, child: _cutout()),
      Positioned(right: -10, top: 46, child: _cutout()),
      Positioned(left: 86, top: 12, bottom: 12, child: _dashLine(accent)),
    ]);
  }

  Widget _posterTile(Color accent, Color soft, Color textDark, List<String> parts, double pulse) {
    return Container(
      constraints: const BoxConstraints(minHeight: 154),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accent.withOpacity(.96), accent.withOpacity(.72), textDark.withOpacity(.92)]),
        boxShadow: [BoxShadow(color: accent.withOpacity(.24 + pulse * .10), blurRadius: 25, offset: Offset(0, 12 + pulse * 5))],
      ),
      child: Stack(children: [
        Positioned(right: -14, top: -18, child: Text('${widget.displayNumber}', style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(.09), height: 1))),
        Positioned(right: 4, bottom: 4, child: Icon(widget.icon, size: 74, color: Colors.white.withOpacity(.08))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.18), border: Border.all(color: Colors.white.withOpacity(.28))), child: Icon(widget.icon, color: Colors.white, size: 22)), const Spacer(), _badge(Colors.white, _badgeText, dark: false)]),
          const SizedBox(height: 24),
          _title(Colors.white, maxLines: 2, fontSize: 19),
          const SizedBox(height: 8),
          Text(parts.take(3).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.3, height: 1.35, color: Colors.white.withOpacity(.78), fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _magneticPill(Color accent, Color soft, Color textDark, List<String> parts, double pulse) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(colors: [Colors.white.withOpacity(.92), soft.withOpacity(.92)]),
        border: Border.all(color: accent.withOpacity(.14 + pulse * .16), width: 1.2),
        boxShadow: [BoxShadow(color: accent.withOpacity(.09 + pulse * .06), blurRadius: 22, offset: const Offset(0, 7))],
      ),
      child: Row(children: [
        Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withOpacity(.12), border: Border.all(color: Colors.white, width: 2)), child: Icon(widget.icon, color: accent, size: 25)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Expanded(child: _title(textDark, fontSize: 16.5)), _badge(accent, _badgeText)]),
          const SizedBox(height: 5),
          Text(parts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w800)),
        ])),
        const SizedBox(width: 8),
        _arrow(accent),
      ]),
    );
  }

  Widget _ribbonBanner(Color accent, Color soft, Color textDark, List<String> parts, double pulse) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: Transform.rotate(
            angle: -0.018,
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: accent.withOpacity(.14 + pulse * .04)),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 10, right: 6, top: 4, bottom: 4),
          padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(30), bottomLeft: Radius.circular(30), bottomRight: Radius.circular(14)),
            gradient: LinearGradient(colors: [soft.withOpacity(.92), Colors.white.withOpacity(.88)]),
            border: Border.all(color: Colors.white.withOpacity(.82)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.045), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            _iconBox(accent, mode: 5),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [Expanded(child: _title(textDark)), _badge(accent, _badgeText)]),
              const SizedBox(height: 8),
              Text(parts.join(' → '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.2, height: 1.35, color: Color(0xFF4B5563), fontWeight: FontWeight.w700)),
            ])),
            const SizedBox(width: 8),
            _arrow(accent),
          ]),
        ),
        Positioned(left: 0, top: 16, bottom: 16, child: Container(width: 7, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(99)))),
      ]),
    );
  }

  Widget _splitPanel(Color accent, Color soft, Color textDark, List<String> parts, double pulse) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), boxShadow: [BoxShadow(color: accent.withOpacity(.11 + pulse * .06), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Row(children: [
        Container(
          width: 74,
          constraints: const BoxConstraints(minHeight: 116),
          decoration: BoxDecoration(color: textDark, borderRadius: const BorderRadius.only(topLeft: Radius.circular(26), bottomLeft: Radius.circular(26))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(widget.icon, color: Colors.white, size: 27),
            const SizedBox(height: 10),
            Text('${widget.displayNumber}', style: TextStyle(color: Colors.white.withOpacity(.58), fontWeight: FontWeight.w900)),
          ]),
        ),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 116),
            padding: const EdgeInsets.fromLTRB(15, 13, 12, 13),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withOpacity(.90), soft.withOpacity(.78)]), borderRadius: const BorderRadius.only(topRight: Radius.circular(26), bottomRight: Radius.circular(26))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(children: [Expanded(child: _title(textDark, maxLines: 2)), const SizedBox(width: 8), _arrow(accent)]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: parts.take(4).map((e) => _chip(e, accent)).toList()),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _inkLine(Color accent, Color soft, Color textDark, List<String> parts, double pulse) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 5, height: 70, decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [accent, accent.withOpacity(.16)]))),
        const SizedBox(width: 12),
        Container(width: 45, height: 45, decoration: BoxDecoration(color: accent.withOpacity(.12), borderRadius: BorderRadius.circular(16)), child: Icon(widget.icon, color: accent, size: 23)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Expanded(child: _title(textDark)), const SizedBox(width: 8), _badge(accent, _badgeText)]),
          const SizedBox(height: 6),
          Text(parts.join(' / '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.2, height: 1.32, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
        ])),
        const SizedBox(width: 8),
        _arrow(accent),
      ]),
    );
  }

  Widget _constellationTile(Color accent, Color soft, Color textDark, List<String> parts, double pulse) {
    return Container(
      constraints: const BoxConstraints(minHeight: 122),
      padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [textDark, accent.withOpacity(.86)]),
        boxShadow: [BoxShadow(color: textDark.withOpacity(.22 + pulse * .10), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Stack(children: [
        Positioned(right: 24, top: 10, child: _starDot(5, Colors.white.withOpacity(.52 + pulse * .22))),
        Positioned(right: 62, top: 36, child: _starDot(3, Colors.white.withOpacity(.35))),
        Positioned(right: 18, bottom: 18, child: _starDot(4, Colors.white.withOpacity(.40))),
        Positioned(right: 34, top: 14, child: Container(width: 45, height: 1, color: Colors.white.withOpacity(.16))),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.14), border: Border.all(color: Colors.white.withOpacity(.24))), child: Icon(widget.icon, color: Colors.white, size: 25)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [Expanded(child: _title(Colors.white, maxLines: 2)), _badge(Colors.white, _badgeText, dark: false)]),
            const SizedBox(height: 8),
            Text(parts.take(4).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.1, height: 1.35, color: Colors.white.withOpacity(.75), fontWeight: FontWeight.w700)),
          ])),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded, color: Colors.white.withOpacity(.82), size: 23),
        ]),
      ]),
    );
  }

  Widget _stepStack(Color accent, Color soft, Color textDark, List<String> parts, double pulse) {
    final steps = parts.isEmpty ? <String>[widget.subtitle] : parts;
    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(.72),
        border: Border.all(color: accent.withOpacity(.14)),
        boxShadow: [BoxShadow(color: accent.withOpacity(.08 + pulse * .05), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          _iconBox(accent, mode: 9),
          const SizedBox(height: 8),
          for (var i = 0; i < math.min(3, steps.length); i++) ...[
            Container(width: 23, height: 23, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: i == 0 ? accent : accent.withOpacity(.13)), child: Text('${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: i == 0 ? Colors.white : accent))),
            if (i != math.min(3, steps.length) - 1) Container(width: 2, height: 11, color: accent.withOpacity(.16)),
          ],
        ]),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Expanded(child: _title(textDark, maxLines: 2)), _badge(accent, _badgeText)]),
          const SizedBox(height: 8),
          for (var i = 0; i < math.min(4, steps.length); i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('· ${steps[i]}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.1, color: Color(0xFF4B5563), fontWeight: FontWeight.w700)),
            ),
        ])),
        const SizedBox(width: 6),
        _arrow(accent),
      ]),
    );
  }


  Widget _brutalSplit(Color accent, Color soft, Color textDark, List<String> parts, double pulse) {
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(left: 22, right: 0, top: 10, bottom: 0, child: Transform.rotate(angle: 0.018, child: Container(decoration: BoxDecoration(color: accent.withOpacity(.16 + pulse * .04), borderRadius: BorderRadius.circular(8))))),
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.86),
            border: Border(left: BorderSide(color: accent, width: 7), top: BorderSide(color: accent.withOpacity(.16))),
            boxShadow: [BoxShadow(color: accent.withOpacity(.11 + pulse * .07), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            Transform.rotate(angle: -0.08, child: _iconBox(accent, mode: 7)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [Expanded(child: _title(textDark, maxLines: 2)), _badge(accent, _badgeText)]),
              const SizedBox(height: 8),
              Text(parts.take(4).join(' × '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF4B5563), fontWeight: FontWeight.w800)),
            ])),
            _arrow(accent),
          ]),
        ),
      ]),
    );
  }

  Widget _prismShard(Color accent, Color soft, Color textDark, List<String> parts, double pulse) {
    return Container(
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(42), topRight: Radius.circular(12), bottomLeft: Radius.circular(14), bottomRight: Radius.circular(38)),
        gradient: SweepGradient(colors: [Colors.white.withOpacity(.92), soft.withOpacity(.86), accent.withOpacity(.18), Colors.white.withOpacity(.92)]),
        border: Border.all(color: Colors.white.withOpacity(.85)),
        boxShadow: [BoxShadow(color: accent.withOpacity(.12 + pulse * .08), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Stack(children: [
        Positioned(right: -26, top: -18, child: Transform.rotate(angle: .6, child: Container(width: 76, height: 76, decoration: BoxDecoration(color: accent.withOpacity(.10), borderRadius: BorderRadius.circular(18))))),
        Row(children: [
          Container(width: 52, height: 76, decoration: BoxDecoration(borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(8), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(28)), color: accent.withOpacity(.92)), child: Icon(widget.icon, color: Colors.white)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [Expanded(child: _title(textDark, maxLines: 2, fontSize: 18)), _badge(accent, _badgeText)]),
            const SizedBox(height: 8),
            Wrap(spacing: 5, runSpacing: 5, children: parts.take(3).map((e) => _chip(e, accent)).toList()),
          ])),
        ]),
      ]),
    );
  }

  Widget _verticalOrbit(Color accent, Color soft, Color textDark, List<String> parts, double pulse) {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.62), borderRadius: BorderRadius.circular(36), border: Border.all(color: accent.withOpacity(.14))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 62, child: Stack(alignment: Alignment.center, children: [
          Container(width: 2, color: accent.withOpacity(.18)),
          Positioned(top: 5, child: _starDot(7, accent.withOpacity(.72))),
          Positioned(bottom: 6, child: _starDot(5, accent.withOpacity(.35))),
          Container(width: 54, height: 54, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [accent, accent.withOpacity(.52)]), boxShadow: [BoxShadow(color: accent.withOpacity(.24 + pulse * .11), blurRadius: 20)]), child: Icon(widget.icon, color: Colors.white)),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          _badge(accent, _badgeText),
          const SizedBox(height: 9),
          _title(textDark, maxLines: 2, fontSize: 19),
          const SizedBox(height: 8),
          for (final part in parts.take(3))
            Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('— $part', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.2, color: Color(0xFF4B5563), fontWeight: FontWeight.w800))),
        ])),
        _arrow(accent),
      ]),
    );
  }

  Widget _magazineNote(Color accent, Color soft, Color textDark, List<String> parts, double pulse) {
    return Container(
      constraints: const BoxConstraints(minHeight: 138),
      padding: const EdgeInsets.fromLTRB(17, 15, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: const Color(0xFFFFFEF8).withOpacity(.94),
        border: Border.all(color: accent.withOpacity(.18)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Stack(children: [
        Positioned(top: 0, right: 0, child: Text('${widget.displayNumber}'.padLeft(2, '0'), style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: accent.withOpacity(.18), height: 1))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Icon(widget.icon, color: accent, size: 22), const SizedBox(width: 7), _badge(accent, _badgeText)]),
          const SizedBox(height: 14),
          _title(textDark, maxLines: 2, fontSize: 20),
          const SizedBox(height: 8),
          Text(parts.take(4).join('  /  '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.2, color: Color(0xFF6B7280), height: 1.36, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _neonCircuit(Color accent, Color soft, Color textDark, List<String> parts, double pulse) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF0F172A).withOpacity(.96),
        boxShadow: [BoxShadow(color: accent.withOpacity(.22 + pulse * .12), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Stack(children: [
        Positioned(left: 8, right: 45, top: 23, child: Container(height: 1, color: Colors.white.withOpacity(.10))),
        Positioned(right: 38, top: 18, child: _starDot(8, accent.withOpacity(.75))),
        Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: accent.withOpacity(.64)), color: accent.withOpacity(.13)), child: Icon(widget.icon, color: Colors.white)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [Expanded(child: _title(Colors.white, maxLines: 2)), _badge(Colors.white, _badgeText, dark: false)]),
            const SizedBox(height: 8),
            Text(parts.take(3).join(' ⇢ '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.1, color: Colors.white.withOpacity(.70), height: 1.34, fontWeight: FontWeight.w700)),
          ])),
          Icon(Icons.arrow_outward_rounded, color: Colors.white.withOpacity(.82), size: 22),
        ]),
      ]),
    );
  }

  Widget _seedTile(Color accent, Color soft, Color textDark, List<String> parts, double pulse) {
    return Container(
      constraints: const BoxConstraints(minHeight: 110),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(topLeft: const Radius.circular(14), topRight: Radius.circular(42 + (widget.index % 3) * 6), bottomLeft: Radius.circular(42 - (widget.index % 3) * 5), bottomRight: const Radius.circular(14)),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withOpacity(.86), soft.withOpacity(.72)]),
        border: Border.all(color: accent.withOpacity(.14)),
      ),
      child: Row(children: [
        Container(width: 58, height: 58, decoration: BoxDecoration(shape: BoxShape.circle, color: soft, border: Border.all(color: accent.withOpacity(.25), width: 1.4)), child: Icon(widget.icon, color: accent)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Expanded(child: _title(textDark, maxLines: 2)), _badge(accent, _badgeText)]),
          const SizedBox(height: 8),
          Text(parts.take(4).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.2, color: Color(0xFF4B5563), height: 1.34, fontWeight: FontWeight.w700)),
        ])),
        _arrow(accent),
      ]),
    );
  }

  Widget _title(Color color, {int maxLines = 2, double fontSize = 17.0}) {
    final effectiveMaxLines = math.max(maxLines, 2);
    final titleLength = widget.title.runes.length;
    final effectiveFontSize = (titleLength >= 9 ? math.min(fontSize, 17.5) : fontSize).toDouble();
    return Text(
      widget.title,
      maxLines: effectiveMaxLines,
      overflow: TextOverflow.ellipsis,
      softWrap: true,
      style: TextStyle(
        fontSize: effectiveFontSize,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: -0.35,
        height: 1.18,
      ),
    );
  }

  Widget _iconBox(Color accent, {int mode = 0}) {
    final circular = mode == 9 || mode == 0;
    return Container(
      width: mode == 9 ? 44 : 48,
      height: mode == 9 ? 44 : 48,
      decoration: BoxDecoration(
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(16),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(.92), accent.withOpacity(.16)]),
        border: Border.all(color: Colors.white.withOpacity(.85)),
      ),
      child: Icon(widget.icon, color: accent, size: mode == 9 ? 21 : 23),
    );
  }

  Widget _badge(Color accent, String badge, {bool dark = true}) {
    final bg = dark ? const Color(0xFF111827).withOpacity(.92) : Colors.white.withOpacity(.18);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 96),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: dark ? null : Border.all(color: Colors.white.withOpacity(.22)),
          boxShadow: [BoxShadow(color: accent.withOpacity(.16), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Text(
          badge,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          softWrap: true,
          style: const TextStyle(color: Colors.white, fontSize: 8.0, fontWeight: FontWeight.w900, letterSpacing: .05, height: 1.05),
        ),
      ),
    );
  }

  Widget _chip(String text, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.56),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(.08)),
      ),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563), fontWeight: FontWeight.w800)),
    );
  }

  Widget _arrow(Color accent) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.62), border: Border.all(color: Colors.white.withOpacity(.72))),
      child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: accent),
    );
  }

  Widget _orb(Color color, double size, double opacity) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(opacity)));
  }

  Widget _cutout() {
    return Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.98)));
  }

  Widget _dashLine(Color accent) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (_) => Container(width: 2, height: 7, decoration: BoxDecoration(color: accent.withOpacity(.16), borderRadius: BorderRadius.circular(99)))),
    );
  }

  Widget _starDot(double size, Color color) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }
}

class _TapShell extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double radius;

  const _TapShell({required this.child, required this.onTap, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: child,
      ),
    );
  }
}


void _registerHomeRefreshPort() {
  const name = 'HOME_REFRESH_PORT';
  try { ui.IsolateNameServer.removePortNameMapping(name); } catch (_) {}
  final port = ReceivePort();
  ui.IsolateNameServer.registerPortWithName(port.sendPort, name);
  port.listen((_) {
    try { SimpleBus.pokeHome(); } catch (_) {}
  });
}

Future<bool> _isFirstOpenAndMark() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final f = File(p.join(dir.path, '.first_open_done'));
    if (await f.exists()) return false;
    await f.writeAsString(DateTime.now().toIso8601String());
    return true;
  } catch (_) { return false; }
}
