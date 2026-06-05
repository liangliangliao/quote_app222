import 'package:flutter/material.dart';

import '../../data/db.dart';
import '../../utils/debug_logger.dart';
import '../models/health_profile.dart';
import '../repositories/health_profile_repository.dart';
import '../services/health_diet_options.dart';
import '../services/health_rule_engine.dart';
import '../services/health_diet_app_agent_service.dart';
import '../services/health_diet_daily_scheduler_service.dart';
import '../models/health_connect_daily_summary.dart';
import '../repositories/health_connect_summary_repository.dart';
import '../daily_share/daily_diet_share_page.dart';
import '../daily_share/daily_diet_review_page.dart';
import '../daily_share/daily_diet_history_page.dart';
import '../habit/diet_habit_report_page.dart';
import '../habit/diet_long_term_report_page.dart';
import '../habit/diet_micro_action_page.dart';
import '../recipe/healthy_recipe_search_page.dart';
import '../recipe/grocery_list_page.dart';
import '../expert/health_diet_expert_dashboard_page.dart';
import '../agent/health_diet_goal_page.dart';
import 'health_diet_settings_page.dart';
import 'health_profile_page.dart';
import 'health_connect_diet_page.dart';
import 'food_benefit_search_page.dart';
import 'today_meal_plan_page.dart';
import '../widgets/health_diet_data_source_banner.dart';

class HealthDietHomePage extends StatefulWidget {
  const HealthDietHomePage({super.key});

  @override
  State<HealthDietHomePage> createState() => _HealthDietHomePageState();
}

class _HealthDietHomePageState extends State<HealthDietHomePage> {
  final _repository = HealthProfileRepository();
  final _ruleEngine = HealthRuleEngine();
  final _healthConnectRepo = HealthConnectSummaryRepository();
  final _appAgent = HealthDietAppAgentService();
  final _dailyScheduler = HealthDietDailySchedulerService();
  HealthProfile? _profile;
  HealthRuleResult? _ruleResult;
  HealthConnectDailySummary? _healthSummary;
  String _agentStatusMessage = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await AppDatabase.ensureHealthDietTables();
    await DLog.i('health_diet.home', '健康饮食调理模块已打开，已确保第四阶段数据表存在');
    try { await _dailyScheduler.tick(); } catch (e) { await DLog.w('health_diet.scheduler.tick', e.toString()); }
    final profile = await _repository.latestProfile();
    final healthSummary = await _healthConnectRepo.latestForDate();
    final agentStatus = await _appAgent.status();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _healthSummary = healthSummary;
      _agentStatusMessage = agentStatus.message;
      _ruleResult = profile == null ? null : _ruleEngine.evaluateProfile(profile);
      _loading = false;
    });
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthProfilePage()));
    await _bootstrap();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthDietSettingsPage()));
    await _bootstrap();
  }

  Future<void> _openGoalPage() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthDietGoalPage()));
    await _bootstrap();
  }

  Future<void> _openExpertDashboard() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthDietExpertDashboardPage()));
    await _bootstrap();
  }

  Future<void> _openDailyShare() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DailyDietSharePage()));
    await _bootstrap();
  }

  Future<void> _openDailyReview() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DailyDietReviewPage()));
    await _bootstrap();
  }

  Future<void> _openDietHistory() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DailyDietHistoryPage()));
    await _bootstrap();
  }

  Future<void> _openHabitReport() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DietHabitReportPage()));
    await _bootstrap();
  }

  Future<void> _openLongTermReport({int days = 7}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DietLongTermReportPage(initialDays: days)));
    await _bootstrap();
  }

  Future<void> _openMicroActions() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DietMicroActionPage()));
    await _bootstrap();
  }

  Future<void> _openHealthConnect() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthConnectDietPage()));
    await _bootstrap();
  }

  Future<void> _openRecipeSearch() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => HealthyRecipeSearchPage(initialGoal: _profile?.mainGoal)));
    await _bootstrap();
  }

  Future<void> _openGroceryList() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroceryListPage()));
    await _bootstrap();
  }

  Future<void> _openTodayMealPlan() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TodayMealPlanPage()));
    await _bootstrap();
  }

  Future<void> _openFoodBenefitSearch() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FoodBenefitSearchPage()));
    await _bootstrap();
  }

  void _showStageNotice(String title) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              '当前已升级为每日定时托管专家方案：系统会把健康档案、Health Connect、每日饮食分享、7天饮食模式、外部营养数据和 AI 解释放在同一个闭环里，并在早餐、午餐、晚餐、晚间复盘等关键时间点自动巡检。',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('饮食'),
        actions: [
          IconButton(
            tooltip: '健康饮食配置',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _bootstrap,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  HealthDietDataSourceBanner(
                    sources: const ['本地健康档案', 'Health Connect', '饮食记录', '外部 API', '全局 AI Provider'],
                    updatedAt: DateTime.now(),
                    note: '首页展示模块状态；真正的饮食判断来自各子页面的动态数据和获取时间。',
                  ),
                  _heroCard(),
                  const SizedBox(height: 10),
                  _localAgentStatusCard(),
                  const SizedBox(height: 14),
                  if (_healthSummary != null) ...[
                    _healthConnectMiniCard(_healthSummary!),
                    const SizedBox(height: 14),
                  ],
                  _profileCard(),
                  const SizedBox(height: 14),
                  _sectionTitle('主动营养专家'),
                  _entryCard(
                    icon: Icons.flag_outlined,
                    color: Colors.orange,
                    title: '我的健康饮食目标',
                    subtitle: '先告诉 Agent 要帮你实现什么目标：恢复体力、调理肠胃、控糖、低盐、增肌或改善饮食习惯',
                    onTap: _openGoalPage,
                  ),
                  _entryCard(
                    icon: Icons.auto_awesome,
                    color: Colors.green,
                    title: 'AI 营养膳食专家',
                    subtitle: '围绕当前目标，整合健康档案、Health Connect、今日饮食、7天模式、Agent记忆、外部API和AI模型，主动生成今日/明日安排，并承接每日定时托管结果',
                    onTap: _openExpertDashboard,
                  ),
                  const SizedBox(height: 14),
                  _sectionTitle('核心记录与复盘'),
                  _entryCard(
                    icon: Icons.add_a_photo_outlined,
                    color: Colors.green,
                    title: '每日饮食分享',
                    subtitle: '支持文字、语音、图片 AI 识别和 Open Food Facts 条形码查询，确认后保存饮食记录',
                    onTap: _openDailyShare,
                  ),
                  _entryCard(
                    icon: Icons.insights_outlined,
                    color: Colors.teal,
                    title: '今日饮食复盘',
                    subtitle: '基于已确认食物、API 营养数据和 Health Connect 状态生成恢复指数与明日最小改变',
                    onTap: _openDailyReview,
                  ),
                  _entryCard(
                    icon: Icons.history,
                    color: Colors.blueGrey,
                    title: '饮食记录历史',
                    subtitle: '查看最近保存的文字、图片、语音和条码饮食记录',
                    onTap: _openDietHistory,
                  ),
                  _entryCard(
                    icon: Icons.auto_graph_outlined,
                    color: Colors.deepPurple,
                    title: '饮食习惯报告',
                    subtitle: '统计最近记录中的高糖、高盐、低蛋白、低蔬菜和早餐缺失等模式',
                    onTap: _openHabitReport,
                  ),
                  _entryCard(
                    icon: Icons.timeline,
                    color: Colors.pink,
                    title: '本周饮食报告 / 30天趋势',
                    subtitle: '查看记录连续性、恢复指数、营养结构趋势，并生成优先微行动',
                    onTap: () => _openLongTermReport(days: 7),
                  ),
                  _entryCard(
                    icon: Icons.flag_outlined,
                    color: Colors.amber,
                    title: '饮食微行动',
                    subtitle: '每天只改一个最小动作，支持完成、恢复、删除和自定义新增',
                    onTap: _openMicroActions,
                  ),
                  _entryCard(
                    icon: Icons.monitor_heart_outlined,
                    color: Colors.indigo,
                    title: 'Health Connect 身体状态',
                    subtitle: '同步睡眠、步数、运动、活动消耗和体重，让饮食复盘结合身体恢复状态',
                    onTap: _openHealthConnect,
                  ),
                  _entryCard(
                    icon: Icons.restaurant_menu,
                    color: Colors.deepOrange,
                    title: '健康菜谱制作',
                    subtitle: '按健康目标推荐菜谱；优先尝试 Spoonacular / Edamam，失败时回退本地菜谱',
                    onTap: _openRecipeSearch,
                  ),
                  _entryCard(
                    icon: Icons.shopping_cart_outlined,
                    color: Colors.brown,
                    title: '购物清单',
                    subtitle: '从菜谱一键生成食材清单，支持勾选、复制和本地保存',
                    onTap: _openGroceryList,
                  ),
                  const SizedBox(height: 14),
                  _sectionTitle('基础配置'),
                  _entryCard(
                    icon: Icons.person_outline,
                    color: Colors.teal,
                    title: '我的健康档案',
                    subtitle: '身体状况、饮食目标、忌口、过敏、烹饪偏好',
                    onTap: _openProfile,
                  ),
                  _entryCard(
                    icon: Icons.settings_outlined,
                    color: Colors.blueGrey,
                    title: '健康饮食配置',
                    subtitle: 'USDA、Open Food Facts、Edamam、Spoonacular 等 API Key 已接入核心流程',
                    onTap: _openSettings,
                  ),
                  const SizedBox(height: 14),
                  _sectionTitle('继续扩展'),
                  _entryCard(
                    icon: Icons.today_outlined,
                    color: Colors.green,
                    title: '今日饮食调理',
                    subtitle: '显示实时饮食状态、已吃/还缺/已超、下一餐动态安排；每日定时 Agent 会自动刷新它',
                    onTap: _openTodayMealPlan,
                  ),
                  _entryCard(
                    icon: Icons.search,
                    color: Colors.orange,
                    title: '食物利弊查询',
                    subtitle: '调用 USDA / Open Food Facts 查询营养数据，并结合档案解释利弊',
                    onTap: _openFoodBenefitSearch,
                  ),
                  _entryCard(
                    icon: Icons.qr_code_scanner,
                    color: Colors.indigo,
                    title: '扫码识别食品',
                    subtitle: '条码查询已并入“每日饮食分享”；这里后续可改为摄像头扫码入口',
                    onTap: () => _showStageNotice('扫码识别食品'),
                  ),
                  _entryCard(
                    icon: Icons.menu_book_outlined,
                    color: Colors.purple,
                    title: '健康饮食知识库',
                    subtitle: '让用户了解不同健康饮食方式与食物调理方向',
                    onTap: () => _showStageNotice('健康饮食知识库'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFEFF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text('营养膳食调理', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 10),
          Text(
            '系统会像每日膳食托管 Agent 一样，在关键时间点自动巡检：早晨生成计划、餐前动态安排、餐后检查记录、晚间生成复盘；同时读取健康档案、Health Connect、今日饮食分享、7天模式和 API 营养数据。',
            style: TextStyle(height: 1.55),
          ),
        ],
      ),
    );
  }


  Widget _healthConnectMiniCard(HealthConnectDailySummary summary) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _openHealthConnect,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: Row(
          children: [
            const Icon(Icons.monitor_heart_outlined, color: Colors.deepPurple),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('今日身体状态', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(summary.compactText(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, height: 1.35)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }


  Widget _localAgentStatusCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.smart_toy_outlined, size: 20, color: Colors.green),
        const SizedBox(width: 8),
        Expanded(child: Text(_agentStatusMessage.isEmpty ? 'App 内置 Agent 已启用：不需要服务器地址；API Key 和模型选择仍由手机端配置。' : _agentStatusMessage, style: const TextStyle(height: 1.35, fontSize: 13))),
      ]),
    );
  }

  Widget _profileCard() {
    final profile = _profile;
    if (profile == null) {
      return _warningCard(
        title: '还没有健康档案',
        message: '建议先填写健康档案。后续所有饮食建议都会根据你的目标、健康状况、忌口和偏好来生成。',
        actionText: '去填写',
        onTap: _openProfile,
      );
    }
    final goal = HealthDietOptions.labelOf(HealthDietOptions.goals, profile.mainGoal);
    final conditions = HealthDietOptions.labelsOf(HealthDietOptions.conditions, profile.conditions).join('、');
    final restrictions = HealthDietOptions.labelsOf(HealthDietOptions.restrictions, profile.restrictions).join('、');
    final rule = _ruleResult;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.green.shade100),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: Colors.green),
              const SizedBox(width: 8),
              const Expanded(child: Text('已读取你的健康档案', style: TextStyle(fontWeight: FontWeight.bold))),
              TextButton(onPressed: _openProfile, child: const Text('修改')),
            ],
          ),
          const SizedBox(height: 8),
          Text('当前目标：$goal'),
          if (conditions.isNotEmpty) Text('健康状况：$conditions'),
          if (restrictions.isNotEmpty) Text('饮食限制：$restrictions'),
          if (rule != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('风险等级：${_riskLabel(rule.riskLevel)}')),
                ...rule.recommendDirections.take(4).map((v) => Chip(label: Text(v))),
              ],
            ),
            if (rule.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(rule.warnings.first, style: const TextStyle(fontSize: 12, color: Colors.deepOrange, height: 1.4)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _warningCard({required String title, required String message, required String actionText, required VoidCallback onTap}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: onTap, icon: const Icon(Icons.edit), label: Text(actionText)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _entryCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _riskLabel(String risk) {
    switch (risk) {
      case 'high':
        return '高，需要专业建议';
      case 'medium':
        return '中，需谨慎';
      default:
        return '低';
    }
  }
}
