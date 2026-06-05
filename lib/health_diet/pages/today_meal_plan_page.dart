import 'dart:async';

import 'package:flutter/material.dart';

import '../expert/health_diet_expert_dashboard_page.dart';
import '../models/health_diet_expert_plan.dart';
import '../recipe/healthy_recipe_search_page.dart';
import '../services/health_diet_app_agent_service.dart';
import '../services/health_diet_autopilot_service.dart';
import '../services/health_diet_daily_scheduler_service.dart';
import '../services/health_diet_realtime_state_service.dart';
import '../widgets/health_diet_data_source_banner.dart';

class TodayMealPlanPage extends StatefulWidget {
  const TodayMealPlanPage({super.key});

  @override
  State<TodayMealPlanPage> createState() => _TodayMealPlanPageState();
}

class _TodayMealPlanPageState extends State<TodayMealPlanPage> {
  final _service = HealthDietAppAgentService();
  final _scheduler = HealthDietDailySchedulerService();
  final _stateService = HealthDietRealtimeStateService();
  HealthDietExpertPlan? _plan;
  HealthDietRealtimeState? _state;
  HealthDietScheduleTickReport? _scheduleReport;
  HealthDietAutopilotResult? _autopilotResult;
  bool _loading = true;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // 页面加载只维护/注册定时任务，不再直接补跑重型 Agent。否则打开页面会立即触发
      // USDA/Open Food Facts/Spoonacular/Edamam/AI 翻译/AI 复盘等一长串调用，导致日志页不断刷新和本页转圈。
      final report = await _scheduler.tick(runDue: false);
      final state = await _stateService.build();
      final plan = await _service.buildTodayPlan();
      if (!mounted) return;
      setState(() {
        _scheduleReport = report;
        _state = state;
        _plan = plan;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载今日饮食调理失败：$e')));
    }
  }

  Future<void> _runNow() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final result = await _service.runAutopilot(force: true, interactive: true).timeout(const Duration(seconds: 240));
      await _scheduler.ensureScheduled();
      final state = await _stateService.build();
      if (!mounted) return;
      setState(() {
        _plan = result.plan;
        _state = state;
        _autopilotResult = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.finalVerdictTitle}：${result.summary}')),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agent 前台托管超过 240 秒，已停止本次等待。当前页面仍保留最近可用方案；请检查网络、模型响应或稍后重试。')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Agent 自动安排失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(title: const Text('今日饮食调理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : plan == null
              ? const Center(child: Text('暂无方案'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      HealthDietDataSourceBanner(
                        sources: const ['Health Connect', '今日饮食记录', '本地营养缓存', '全局 AI Provider', '定时托管 Agent'],
                        updatedAt: DateTime.now(),
                        note: '本页会区分动态依据和静态模板；如果确认食物为 0，方案属于安全兜底，不是精准营养处方。',
                      ),
                      _scheduleCard(),
                      const SizedBox(height: 12),
                      if (_state != null) ...[
                        _realtimeStateCard(_state!),
                        const SizedBox(height: 12),
                      ],
                      _agentFinalCard(plan),
                      if (_shouldShowFallback(plan)) ...[
                        const SizedBox(height: 12),
                        _fallbackCard(plan),
                      ],
                      const SizedBox(height: 12),
                      _intro(plan),
                      const SizedBox(height: 12),
                      ...plan.meals.map(_mealCard),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => HealthyRecipeSearchPage(
                            initialGoal: _state?.profile?.mainGoal ?? 'balanced',
                            initialQuery: plan.recipeGoal,
                            title: '按今日调理找菜谱',
                          ),
                        )),
                        icon: const Icon(Icons.restaurant_menu),
                        label: Text('按“${plan.recipeGoal}”找可执行菜谱'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _running ? null : _runNow,
                        icon: _running ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                        label: const Text('立即让 Agent 重新安排今天饮食'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthDietExpertDashboardPage())),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('查看完整专家方案'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _scheduleCard() {
    final report = _scheduleReport;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.schedule, color: Colors.green),
          SizedBox(width: 8),
          Expanded(child: Text('每日定时膳食 Agent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ]),
        const SizedBox(height: 6),
        Text(report?.summary ?? '已启用每日定时托管：早晨计划、早餐检查、午餐安排、下午加餐检查、晚餐安排、晚间复盘。', style: const TextStyle(height: 1.4)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: HealthDietDailySchedulerService.defaultSlots.take(6).map((e) => Chip(label: Text('${e.timeText} ${e.label}'))).toList(),
        ),
      ]),
    );
  }

  Widget _realtimeStateCard(HealthDietRealtimeState state) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.monitor_heart_outlined, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(child: Text('实时饮食状态：${state.currentPhase}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ]),
        const SizedBox(height: 6),
        Text('可信度：${state.confidenceText} · 今日记录 ${state.entryCount} 餐 · 确认 ${state.confirmedFoodCount} 个食物 · 营养匹配 ${state.nutritionMatchedCount} 个', style: const TextStyle(height: 1.4)),
        const SizedBox(height: 8),
        Text('下一餐：${state.nextMealType}；下一步：${state.nextBestAction}', style: const TextStyle(height: 1.45, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        ...state.budgets.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${b.label}：${b.display}', style: const TextStyle(height: 1.35)),
                Text(b.advice, style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.3)),
              ]),
            )),
        if (state.riskFlags.isNotEmpty) ...[
          const Divider(),
          const Text('今日风险/冲突提醒', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...state.riskFlags.take(3).map((e) => Text('• $e', style: const TextStyle(height: 1.35, color: Colors.deepOrange))),
        ],
        if (state.dataGaps.isNotEmpty) ...[
          const Divider(),
          const Text('仍需补充的数据', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...state.dataGaps.take(3).map((e) => Text('• $e', style: const TextStyle(height: 1.35, color: Colors.black54))),
        ],
      ]),
    );
  }

  Widget _agentFinalCard(HealthDietExpertPlan plan) {
    final result = _autopilotResult;
    final state = _state;
    final warning = _shouldShowFallback(plan);
    final title = result?.finalVerdictTitle ?? '当前最终安排：先按保守方案执行';
    final message = result?.finalVerdictMessage ?? '当前方案主要来自健康档案、身体状态和本地规则。点击“立即让 Agent 重新安排今天饮食”后，会重新整合 API 与 AI 分析。';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFFFF7ED) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: warning ? const Color(0xFFFED7AA) : const Color(0xFFC7D2FE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(warning ? Icons.warning_amber_rounded : Icons.task_alt_rounded, color: warning ? Colors.deepOrange : Colors.indigo),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ]),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(height: 1.45)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _metricPill('可信度', state?.confidenceText ?? plan.dataCoverageLevel, warning ? Colors.orange : Colors.green),
          _metricPill('确认食物', '${state?.confirmedFoodCount ?? 0}', (state?.confirmedFoodCount ?? 0) == 0 ? Colors.deepOrange : Colors.green),
          _metricPill('营养匹配', '${state?.nutritionMatchedCount ?? 0}', (state?.nutritionMatchedCount ?? 0) == 0 ? Colors.orange : Colors.indigo),
          _metricPill('风险', _riskLabel(plan.riskLevel), plan.riskLevel == 'high' ? Colors.redAccent : Colors.blueGrey),
        ]),
        const SizedBox(height: 10),
        const Text('下一步重点', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(state?.nextBestAction ?? plan.microActionTitle, style: TextStyle(height: 1.4, color: warning ? Colors.deepOrange.shade700 : Colors.black87, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  bool _shouldShowFallback(HealthDietExpertPlan plan) {
    return (_autopilotResult?.shouldShowFallback ?? false) ||
        (_state?.confirmedFoodCount ?? 0) == 0 ||
        plan.dataGaps.length >= 2 ||
        plan.recentDietSummary.contains('今日确认 0');
  }

  Widget _fallbackCard(HealthDietExpertPlan plan) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.health_and_safety_outlined, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(child: Text('兜底托管：数据不足时先保护健康目标', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ]),
        const SizedBox(height: 8),
        const Text('如果饮食记录、身体状态或 API/AI 没有完整返回，系统会先给出低风险通用安排，同时提示你补齐关键数据。这样比“无数据却假装精准”更安全。', style: TextStyle(height: 1.45)),
        const SizedBox(height: 10),
        ...<String>[
          if ((_state?.confirmedFoodCount ?? 0) == 0) '先记录一餐真实饮食，至少包括食物名称和大致份量。',
          if ((_state?.nutritionMatchedCount ?? 0) == 0) '记录饮食后让 Agent 自动补全 USDA / Open Food Facts 营养数据。',
          ...plan.dataGaps.take(2),
        ].map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('• $e', style: const TextStyle(height: 1.35, color: Colors.deepOrange)),
            )),
      ]),
    );
  }

  Widget _metricPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.35))),
      child: RichText(
        text: TextSpan(style: const TextStyle(fontSize: 13, color: Colors.black87), children: [
          TextSpan(text: '$label：', style: const TextStyle(color: Colors.black54)),
          TextSpan(text: value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  String _riskLabel(String risk) {
    switch (risk) {
      case 'high':
        return '高';
      case 'medium':
        return '中';
      case 'unknown':
        return '未知';
      default:
        return '低';
    }
  }

  Widget _intro(HealthDietExpertPlan plan) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFBFDBFE))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(plan.focusTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        Text(plan.focusReason, style: const TextStyle(height: 1.45)),
        const SizedBox(height: 8),
        Text('依据：${plan.profileSummary}\n身体状态：${plan.healthConnectSummary}\n饮食历史：${plan.recentDietSummary}', style: const TextStyle(height: 1.45, color: Colors.black54)),
      ]),
    );
  }

  Widget _mealCard(ExpertMealBlock meal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.restaurant, color: Colors.teal), const SizedBox(width: 8), Expanded(child: Text(meal.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))]),
          const SizedBox(height: 8),
          Text('目的：${meal.purpose}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          ...meal.suggestions.map((e) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $e', style: const TextStyle(height: 1.35)))),
          const SizedBox(height: 6),
          Text('为什么这样安排：${meal.reason}', style: const TextStyle(height: 1.4)),
          if (meal.avoid.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('今天少选：${meal.avoid.join('、')}', style: const TextStyle(color: Colors.deepOrange, height: 1.4)),
          ],
        ]),
      ),
    );
  }
}
