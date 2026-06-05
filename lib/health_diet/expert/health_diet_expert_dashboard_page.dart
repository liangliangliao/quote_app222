import 'dart:async';

import 'package:flutter/material.dart';

import '../daily_share/daily_diet_share_page.dart';
import '../agent/health_diet_goal_page.dart';
import '../models/health_diet_expert_plan.dart';
import '../pages/health_connect_diet_page.dart';
import '../pages/health_profile_page.dart';
import '../recipe/healthy_recipe_search_page.dart';
import '../services/health_diet_app_agent_service.dart';
import '../services/health_diet_autopilot_service.dart';
import '../widgets/health_diet_data_source_banner.dart';

class HealthDietExpertDashboardPage extends StatefulWidget {
  const HealthDietExpertDashboardPage({super.key});

  @override
  State<HealthDietExpertDashboardPage> createState() => _HealthDietExpertDashboardPageState();
}

class _HealthDietExpertDashboardPageState extends State<HealthDietExpertDashboardPage> {
  final _service = HealthDietAppAgentService();
  HealthDietExpertPlan? _plan;
  HealthDietAutopilotResult? _autopilotResult;
  bool _loading = true;
  bool _aiLoading = false;
  bool _autopilotLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _autopilotLoading = true;
    });
    try {
      // 先快速显示本地兜底方案，再让 Agent 在页面可见状态下继续完成 API/AI 巡检。
      final localPlan = await _service.buildTodayPlan();
      if (!mounted) return;
      setState(() {
        _plan = localPlan;
        _loading = false;
      });
      final result = await _service.runAutopilot().timeout(const Duration(seconds: 300));
      if (!mounted) return;
      setState(() {
        _plan = result.plan;
        _autopilotResult = result;
        _autopilotLoading = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _autopilotLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('完整巡检超过 300 秒，已保留本地兜底方案；请稍后重试或检查 API/模型响应。')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _autopilotLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载专家方案失败：$e')));
    }
  }

  Future<void> _runAutopilotNow() async {
    setState(() => _autopilotLoading = true);
    try {
      final result = await _service.runAutopilot(force: true).timeout(const Duration(seconds: 300));
      if (!mounted) return;
      setState(() {
        _plan = result.plan;
        _autopilotResult = result;
        _autopilotLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result.finalVerdictTitle}：${result.summary}')));
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _autopilotLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('完整巡检超过 300 秒，已停止等待并保留最近可用方案。')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _autopilotLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('自动托管巡检失败：$e')));
    }
  }

  Future<void> _generateAi() async {
    final plan = _plan;
    if (plan == null) return;
    setState(() => _aiLoading = true);
    final text = await _service.generateAiCoachNarrative(plan).timeout(
      const Duration(seconds: 240),
      onTimeout: () => 'AI 专家分析超过 240 秒，已停止本次等待。当前仍可使用本地兜底方案；请稍后重试或切换更快模型。',
    );
    if (!mounted) return;
    setState(() {
      _plan = plan.copyWith(aiCoachText: text);
      _aiLoading = false;
    });
  }

  Future<void> _openAndRefresh(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 营养膳食专家')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _plan == null ? const Center(child: Text('暂无方案')) : _body(_plan!),
            ),
    );
  }

  Widget _body(HealthDietExpertPlan plan) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        HealthDietDataSourceBanner(
          sources: const ['健康档案', 'Health Connect', '饮食分享', 'USDA/Open Food Facts', 'Spoonacular/Edamam', '全局 AI Provider'],
          updatedAt: DateTime.now(),
          note: '本页是 Agent 汇总视图：动态数据会进入最终判断；数据不足时显示兜底托管，而不是伪装成精准方案。',
        ),
        _focusCard(plan),
        const SizedBox(height: 12),
        _finalResultCard(plan),
        if (_autopilotResult?.shouldShowFallback ?? false) ...[
          const SizedBox(height: 12),
          _fallbackCard(plan),
        ],
        const SizedBox(height: 12),
        _autopilotCard(),
        const SizedBox(height: 12),
        _quickActions(plan),
        const SizedBox(height: 12),
        _sectionTitle('系统实际依据'),
        _evidenceCard(plan),
        const SizedBox(height: 12),
        _sectionTitle('优先问题'),
        _listCard(plan.priorityProblems.isEmpty ? const ['暂未发现明确问题；请先完善档案、同步身体数据并分享今日饮食。'] : plan.priorityProblems, icon: Icons.warning_amber_outlined, color: Colors.deepOrange),
        const SizedBox(height: 12),
        _sectionTitle('今日 / 明日主动安排'),
        _strategyCard(plan),
        const SizedBox(height: 12),
        _sectionTitle('分餐建议'),
        ...plan.meals.map(_mealCard),
        const SizedBox(height: 12),
        _sectionTitle('推荐与限制'),
        _foodsCard(plan),
        const SizedBox(height: 12),
        _sectionTitle('数据缺口与 API 状态'),
        _dataQualityCard(plan),
        const SizedBox(height: 12),
        if (plan.safetyNotices.isNotEmpty) ...[
          _sectionTitle('谨慎事项'),
          _listCard(plan.safetyNotices, icon: Icons.health_and_safety_outlined, color: Colors.redAccent),
          const SizedBox(height: 12),
        ],
        _aiCoachCard(plan),
      ],
    );
  }

  Widget _focusCard(HealthDietExpertPlan plan) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFFECFDF5), Color(0xFFFFFBEB)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF059669)),
          const SizedBox(width: 8),
          Expanded(child: Text(plan.focusTitle, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 10),
        Text(plan.focusReason, style: const TextStyle(height: 1.5)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(label: Text('数据完整度：${plan.dataCoverageLevel}')),
          Chip(label: Text('风险等级：${_riskLabel(plan.riskLevel)}')),
          Chip(label: Text('日期：${plan.planDate}')),
        ]),
      ]),
    );
  }


  Widget _autopilotCard() {
    final result = _autopilotResult;
    final steps = result?.steps ?? const <HealthDietAutopilotStep>[];
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.bolt_outlined, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Agent 自动托管巡检', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  result == null ? '正在准备自动托管...' : '${result.summary} 等级：${result.autonomyLevel}；完成时间：${_timeText(result.completedAt)}',
                  style: const TextStyle(height: 1.35, color: Colors.black54),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _autopilotLoading ? null : _runAutopilotNow,
              icon: _autopilotLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync),
              label: Text(_autopilotLoading ? '托管中' : '立即巡检'),
            ),
          ]),
          if (steps.isNotEmpty) ...[
            const Divider(height: 22),
            ...steps.map((step) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(_autopilotIcon(step), color: _autopilotColor(step), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(step.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(step.message, style: TextStyle(height: 1.35, color: step.warning ? Colors.deepOrange.shade700 : step.error ? Colors.redAccent : Colors.black54, fontWeight: step.warning || step.error ? FontWeight.w600 : FontWeight.normal)),
                      ]),
                    ),
                  ]),
                )),
          ],
        ]),
      ),
    );
  }

  Widget _finalResultCard(HealthDietExpertPlan plan) {
    final result = _autopilotResult;
    final title = result?.finalVerdictTitle ?? '当前结果：本地专家方案已生成';
    final message = result?.finalVerdictMessage ?? '当前页面已基于本地规则生成方案；点击“立即巡检”后会自动同步、调用 API，并让 AI 参与分析。';
    final actions = result?.immediateActions ?? [plan.next24hStrategy, plan.microActionTitle];
    final warning = result?.shouldShowFallback ?? plan.dataGaps.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: warning ? const Color(0xFFFFF7ED) : const Color(0xFFEEF2FF),
        border: Border.all(color: warning ? const Color(0xFFFED7AA) : const Color(0xFFC7D2FE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(warning ? Icons.priority_high_rounded : Icons.task_alt_rounded, color: warning ? Colors.deepOrange : Colors.indigo),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(height: 1.45)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _metricPill('完成', '${result?.okCount ?? 0}', Colors.green),
          _metricPill('提醒', '${result?.warningCount ?? 0}', Colors.orange),
          _metricPill('失败', '${result?.errorCount ?? 0}', Colors.redAccent),
          _metricPill('风险', _riskLabel(plan.riskLevel), plan.riskLevel == 'high' ? Colors.redAccent : Colors.blueGrey),
          _metricPill('数据', plan.dataCoverageLevel, Colors.indigo),
        ]),
        const SizedBox(height: 12),
        const Text('现在最该关注', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...actions.take(4).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(e, style: TextStyle(height: 1.35, color: warning ? Colors.deepOrange.shade700 : Colors.black87, fontWeight: FontWeight.w600))),
              ]),
            )),
      ]),
    );
  }

  Widget _fallbackCard(HealthDietExpertPlan plan) {
    final result = _autopilotResult;
    final gaps = <String>[
      ...plan.dataGaps,
      if (result?.steps.any((e) => e.message.contains('Health Connect 尚未授权')) ?? false) 'Health Connect 尚未授权，身体状态无法自动进入判断。',
      if (plan.recentDietSummary.contains('今日确认 0') || (result?.hasCriticalDataGap ?? false)) '今日没有确认食物，Agent 只能给保守方案，不能精准计算“已吃/还缺/已超”。',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.health_and_safety_outlined, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(child: Text('兜底托管页面：先安全，再精准', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ]),
        const SizedBox(height: 8),
        const Text('本轮关键数据不足或部分 API/AI 未完整返回。系统不会强行假装精准，而是先展示安全保守方案，并把补数据入口直接给你。', style: TextStyle(height: 1.45)),
        if (gaps.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('需要补齐', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...gaps.take(4).map((e) => Text('• $e', style: const TextStyle(height: 1.35, color: Colors.deepOrange))),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: () => _openAndRefresh(const DailyDietSharePage()), icon: const Icon(Icons.add_a_photo_outlined), label: const Text('补饮食')),
          OutlinedButton.icon(onPressed: () => _openAndRefresh(const HealthConnectDietPage()), icon: const Icon(Icons.monitor_heart_outlined), label: const Text('授权身体数据')),
          OutlinedButton.icon(onPressed: _aiLoading ? null : _generateAi, icon: const Icon(Icons.psychology_alt_outlined), label: const Text('AI 再判断')),
        ]),
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

  Widget _quickActions(HealthDietExpertPlan plan) {
    return Row(children: [
      Expanded(child: OutlinedButton.icon(onPressed: () => _openAndRefresh(const HealthDietGoalPage()), icon: const Icon(Icons.flag_outlined), label: const Text('目标'))),
      const SizedBox(width: 8),
      Expanded(child: OutlinedButton.icon(onPressed: () => _openAndRefresh(const HealthProfilePage()), icon: const Icon(Icons.person_outline), label: const Text('档案'))),
      const SizedBox(width: 8),
      Expanded(child: OutlinedButton.icon(onPressed: () => _openAndRefresh(const DailyDietSharePage()), icon: const Icon(Icons.add_a_photo_outlined), label: const Text('饮食'))),
    ]);
  }

  Widget _evidenceCard(HealthDietExpertPlan plan) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(plan.profileSummary, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 6),
          Text('Health Connect：${plan.healthConnectSummary}', style: const TextStyle(height: 1.45)),
          const SizedBox(height: 6),
          Text('饮食历史：${plan.recentDietSummary}', style: const TextStyle(height: 1.45)),
          const Divider(height: 22),
          ...plan.evidence.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(_strengthIcon(e.strength), size: 18, color: _strengthColor(e.strength)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${e.label}：${e.value}（${e.source}）', style: const TextStyle(height: 1.35))),
                ]),
              )),
        ]),
      ),
    );
  }

  Widget _strategyCard(HealthDietExpertPlan plan) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('24小时策略', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(plan.next24hStrategy, style: const TextStyle(height: 1.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('明天只改这一点', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(plan.microActionTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(plan.microActionReason, style: const TextStyle(height: 1.4, color: Colors.black54)),
            ]),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HealthyRecipeSearchPage(initialGoal: 'balanced', initialQuery: plan.recipeGoal, title: '围绕方案找菜谱'))),
            icon: const Icon(Icons.restaurant_menu),
            label: Text('按“${plan.recipeGoal}”找菜谱'),
          ),
        ]),
      ),
    );
  }

  Widget _mealCard(ExpertMealBlock meal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.restaurant, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(child: Text(meal.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 8),
          Text('目的：${meal.purpose}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          ...meal.suggestions.map((e) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $e'))),
          const SizedBox(height: 6),
          Text('理由：${meal.reason}', style: const TextStyle(height: 1.4)),
          if (meal.avoid.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('少选：${meal.avoid.join('、')}', style: const TextStyle(color: Colors.deepOrange, height: 1.4)),
          ],
        ]),
      ),
    );
  }

  Widget _foodsCard(HealthDietExpertPlan plan) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('优先选择', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: plan.recommendedFoods.map((e) => Chip(label: Text(e), backgroundColor: const Color(0xFFECFDF5))).toList()),
          const SizedBox(height: 12),
          const Text('今天少选/谨慎', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: plan.limitFoods.map((e) => Chip(label: Text(e), backgroundColor: const Color(0xFFFFF7ED))).toList()),
        ]),
      ),
    );
  }

  Widget _dataQualityCard(HealthDietExpertPlan plan) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (plan.dataGaps.isEmpty)
            const Text('当前核心数据链路较完整。')
          else
            ...plan.dataGaps.map((e) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $e', style: const TextStyle(height: 1.35)))),
          const Divider(height: 22),
          ...plan.apiDiagnostics.map((api) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(api.status == '已配置' || api.status == '无需密钥' ? Icons.check_circle_outline : Icons.info_outline, color: api.status == '未配置' ? Colors.orange : Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${api.name}：${api.status}。${api.message}', style: const TextStyle(height: 1.35))),
                ]),
              )),
        ]),
      ),
    );
  }

  Widget _aiCoachCard(HealthDietExpertPlan plan) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [Icon(Icons.psychology_alt_outlined, color: Colors.deepPurple), SizedBox(width: 8), Text('AI 专家深度分析', style: TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          const Text('AI 不再单独“瞎猜”，而是基于本页数据包：健康档案、Health Connect、饮食分享、历史模式和外部营养数据生成解释。', style: TextStyle(height: 1.45)),
          const SizedBox(height: 10),
          if (plan.aiCoachText != null) _aiTextWithImages(plan.aiCoachText!),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: (_aiLoading || _autopilotLoading) ? null : _generateAi,
            icon: _aiLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
            label: Text(_aiLoading ? '生成中...' : '生成 AI 专家分析'),
          ),
        ]),
      ),
    );
  }


  Widget _aiTextWithImages(String text) {
    final images = _extractImageUrls(text).take(6).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty) ...[
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    images[index],
                    width: 148,
                    height: 118,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 148,
                      height: 118,
                      alignment: Alignment.center,
                      color: const Color(0xFFEDE9FE),
                      child: const Icon(Icons.broken_image_outlined, color: Colors.deepPurple),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(text, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }

  List<String> _extractImageUrls(String text) {
    final urls = <String>[];
    final patterns = <RegExp>[
      RegExp(r'!\[[^\]]*\]\((https?://[^\s)]+)\)', caseSensitive: false),
      RegExp(r'(https?://[^\s)]+?\.(?:png|jpe?g|webp|gif)(?:\?[^\s)]*)?)', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(text)) {
        final url = match.group(1)?.trim();
        if (url != null && url.isNotEmpty && !urls.contains(url)) urls.add(url);
      }
    }
    return urls;
  }

  Widget _listCard(List<String> items, {required IconData icon, required Color color}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: items.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 18), const SizedBox(width: 8), Expanded(child: Text(e, style: const TextStyle(height: 1.35)))]),
        )).toList()),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );


  IconData _autopilotIcon(HealthDietAutopilotStep step) {
    if (step.error) return Icons.error_outline;
    if (step.warning) return Icons.info_outline;
    return Icons.check_circle_outline;
  }

  Color _autopilotColor(HealthDietAutopilotStep step) {
    if (step.error) return Colors.redAccent;
    if (step.warning) return Colors.orange;
    return Colors.green;
  }

  String _timeText(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}';
  }

  String _riskLabel(String risk) {
    switch (risk) {
      case 'high':
        return '高，需要专业建议';
      case 'medium':
        return '中，需要谨慎';
      case 'unknown':
        return '未知';
      default:
        return '低';
    }
  }

  IconData _strengthIcon(String strength) => strength == 'high' ? Icons.verified_outlined : strength == 'low' ? Icons.error_outline : Icons.info_outline;
  Color _strengthColor(String strength) => strength == 'high' ? Colors.green : strength == 'low' ? Colors.orange : Colors.blueGrey;
}
