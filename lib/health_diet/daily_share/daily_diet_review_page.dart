import 'package:flutter/material.dart';

import '../models/daily_diet_entry.dart';
import '../repositories/daily_diet_entry_repository.dart';
import '../repositories/health_profile_repository.dart';
import '../repositories/health_connect_summary_repository.dart';
import '../repositories/food_item_repository.dart';
import '../models/health_connect_daily_summary.dart';
import '../services/daily_diet_review_service.dart';
import '../services/health_rule_engine.dart';
import '../services/health_diet_ai_bridge_service.dart';
import '../models/health_profile.dart';
import '../recipe/healthy_recipe_search_page.dart';
import '../widgets/health_diet_data_source_banner.dart';

class DailyDietReviewPage extends StatefulWidget {
  const DailyDietReviewPage({super.key, this.entryId});

  final int? entryId;

  @override
  State<DailyDietReviewPage> createState() => _DailyDietReviewPageState();
}

class _DailyDietReviewPageState extends State<DailyDietReviewPage> {
  final _entryRepo = DailyDietEntryRepository();
  final _profileRepo = HealthProfileRepository();
  final _healthConnectRepo = HealthConnectSummaryRepository();
  final _reviewService = DailyDietReviewService();
  final _foodRepo = FoodItemRepository();
  final _ruleEngine = HealthRuleEngine();
  final _aiBridge = HealthDietAiBridgeService();

  bool _loading = true;
  List<DailyDietEntry> _entries = const [];
  DailyDietReview? _review;
  HealthConnectDailySummary? _healthSummary;
  HealthProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final today = _entryRepo.todayDate();
    final entries = await _entryRepo.entriesForDate(today);
    final foods = entries.expand((e) => e.foods).toList();
    final normalizedFoods = await _foodRepo.byIds(foods.map((e) => e.normalizedFoodId));
    final profile = await _profileRepo.latestProfile();
    final healthSummary = await _healthConnectRepo.latestForDate(date: today);
    final rule = profile == null ? null : _ruleEngine.evaluateProfile(profile);
    final localReview = _reviewService.buildLocalReview(
      userId: HealthProfileRepository.defaultUserId,
      summaryDate: today,
      foods: foods,
      profile: profile,
      ruleResult: rule,
      entries: entries,
      healthSummary: healthSummary,
      normalizedFoods: normalizedFoods,
    );
    final aiReview = await _aiBridge.reviewDietWithEvidence(
      localReview,
      extraContext: {
        'profile_goal': profile?.mainGoal,
        'health_connect': healthSummary?.compactText(),
        'entry_count': entries.length,
        'food_count': foods.length,
        'normalized_food_count': normalizedFoods.length,
      },
    );
    final review = _reviewService.mergeAiReview(localReview, aiReview);
    await _entryRepo.upsertDailyReview(review);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _review = review;
      _healthSummary = healthSummary;
      _profile = profile;
      _loading = false;
    });
  }

  Future<void> _deleteEntry(DailyDietEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条饮食记录？'),
        content: const Text('删除后，这条记录对应的食物和图片索引也会从本地数据库移除。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true || entry.id == null) return;
    await _entryRepo.deleteEntry(entry.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('今日饮食复盘')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  HealthDietDataSourceBanner(
                    sources: const ['今日确认食物', '营养数据库缓存', 'Health Connect', '本地规则', 'AI 二次审查'],
                    updatedAt: DateTime.now(),
                    note: '复盘会显示可信度、证据链和数据缺口；营养总量为粗估，取决于食物份量和外部数据匹配质量。',
                  ),
                  if (_review != null) _reviewCard(_review!),
                  if (_review != null) ...[
                    const SizedBox(height: 10),
                    _recipeRecommendCard(_review!),
                  ],
                  if (_healthSummary?.hasAnyData == true) ...[
                    const SizedBox(height: 10),
                    _healthConnectCard(_healthSummary!),
                  ],
                  const SizedBox(height: 14),
                  _sectionTitle('今日记录'),
                  if (_entries.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('今天还没有饮食记录。你可以从模块首页进入“每日饮食分享”。'),
                      ),
                    )
                  else
                    ..._entries.map(_entryCard),
                ],
              ),
            ),
    );
  }


  String _recipeQueryFromReview(DailyDietReview review) {
    if (review.recipeNeeds.isNotEmpty) return review.recipeNeeds.first.queryText;
    final text = '${review.nextDayAdvice}\n${review.mainProblems.join('\n')}';
    if (text.contains('甜饮') || text.contains('高糖') || text.contains('少糖') || text.contains('无糖')) return '控糖 无糖 高蛋白 早餐';
    if (text.contains('高盐') || text.contains('重盐') || text.contains('泡面') || text.contains('汤汁') || text.contains('调料')) return '低盐 清淡 蔬菜 蛋白';
    if (text.contains('早餐')) return '高蛋白早餐 清淡';
    if (text.contains('蔬菜') || text.contains('高纤维')) return '高纤维 蔬菜 家常';
    if (text.contains('蛋白')) return '高蛋白 家常 清淡';
    if (text.contains('胃') || text.contains('清淡') || text.contains('蒸煮')) return '养胃粥 清淡 蒸煮';
    return '健康家常菜 清淡';
  }

  Widget _recipeRecommendCard(DailyDietReview review) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.restaurant_menu, color: Colors.deepOrange),
                SizedBox(width: 8),
                Expanded(child: Text('根据今日复盘推荐菜谱', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 8),
            const Text('把“明天只改这一点”落到具体一餐：系统会按你的健康目标、忌口和今日饮食问题推荐可执行菜谱。', style: TextStyle(height: 1.45)),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => HealthyRecipeSearchPage(initialGoal: _profile?.mainGoal, initialQuery: _recipeQueryFromReview(review), title: '根据复盘找菜谱')));
              },
              icon: const Icon(Icons.search),
              label: const Text('查看推荐菜谱'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _healthConnectCard(HealthConnectDailySummary summary) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.monitor_heart_outlined, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text('今日身体状态已参与复盘', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(summary.compactText(), style: const TextStyle(height: 1.45)),
          ],
        ),
      ),
    );
  }

  Widget _reviewCard(DailyDietReview review) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFECFDF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: Color(0xFF059669)),
              const SizedBox(width: 8),
              const Expanded(child: Text('今日基础复盘', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              if (review.recoveryScore != null)
                Chip(label: Text('恢复指数 ${review.recoveryScore!.round()}')),
            ],
          ),
          const SizedBox(height: 10),
          Text(review.overallSummary, style: const TextStyle(height: 1.5)),
          const SizedBox(height: 10),
          _confidenceCard(review),
          if (_hasNutritionTotals(review)) ...[
            const SizedBox(height: 10),
            _nutritionTotalsCard(review),
          ],
          const SizedBox(height: 14),
          _miniScoreRow('蛋白质', review.proteinScore),
          _miniScoreRow('蔬菜纤维', review.vegetableScore),
          _riskScoreRow('高糖风险', review.sugarRiskScore),
          _riskScoreRow('高盐风险', review.sodiumRiskScore),
          _riskScoreRow('加工食品风险', review.ultraProcessedScore),
          _miniScoreRow('膳食纤维', review.fiberScore),
          const SizedBox(height: 14),
          _bulletBlock('今天做得好的地方', review.goodPoints, Icons.thumb_up_alt_outlined, Colors.green),
          const SizedBox(height: 10),
          _bulletBlock('今天最值得注意', review.mainProblems, Icons.warning_amber_outlined, Colors.orange),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.78),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.flag_outlined, color: Color(0xFF059669)),
                    SizedBox(width: 8),
                    Text('明天只改这一点', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(review.nextDayAdvice, style: const TextStyle(height: 1.45)),
              ],
            ),
          ),
          if (review.recipeNeeds.isNotEmpty) ...[
            const SizedBox(height: 10),
            _recipeNeedsBlock(review.recipeNeeds),
          ],
          if (review.evidenceItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            _evidenceBlock(review.evidenceItems),
          ],
          if (review.dataGaps.isNotEmpty) ...[
            const SizedBox(height: 10),
            _dataGapBlock(review.dataGaps),
          ],
        ],
      ),
    );
  }


  bool _hasNutritionTotals(DailyDietReview review) {
    return [
      review.totalCaloriesKcal,
      review.totalProteinG,
      review.totalFatG,
      review.totalCarbsG,
      review.totalFiberG,
      review.totalSugarG,
      review.totalSodiumMg,
    ].any((e) => e != null && e > 0);
  }

  Widget _confidenceCard(DailyDietReview review) {
    final value = review.confidenceScore.clamp(0.0, 1.0).toDouble();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Expanded(child: Text('复盘可信度：${review.confidenceLevel} · ${(value * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: value, minHeight: 8, borderRadius: BorderRadius.circular(8)),
          const SizedBox(height: 6),
          const Text('可信度由用户确认食物、外部营养匹配、份量克数、健康档案和 Health Connect 数据共同决定。', style: TextStyle(fontSize: 12, height: 1.35)),
        ],
      ),
    );
  }

  Widget _nutritionTotalsCard(DailyDietReview review) {
    String item(String label, double? value, String suffix, {int digits = 0}) {
      if (value == null || value <= 0) return '';
      return '$label ${digits == 0 ? value.round() : value.toStringAsFixed(digits)}$suffix';
    }
    final parts = <String>[
      item('热量', review.totalCaloriesKcal, ' kcal'),
      item('蛋白质', review.totalProteinG, 'g', digits: 1),
      item('脂肪', review.totalFatG, 'g', digits: 1),
      item('碳水', review.totalCarbsG, 'g', digits: 1),
      item('纤维', review.totalFiberG, 'g', digits: 1),
      item('糖', review.totalSugarG, 'g', digits: 1),
      item('钠', review.totalSodiumMg, 'mg'),
    ].where((e) => e.isNotEmpty).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.calculate_outlined, size: 18, color: Color(0xFF059669)), SizedBox(width: 6), Text('今日营养总量粗估', style: TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          Text(parts.join(' · '), style: const TextStyle(height: 1.45)),
          const SizedBox(height: 4),
          const Text('仅在食物匹配到营养库且份量可估算时计算；未填克数时不要把它当作精确值。', style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35)),
        ],
      ),
    );
  }

  Widget _recipeNeedsBlock(List<DietRecipeNeed> needs) {
    return _smallPanel(
      icon: Icons.restaurant_outlined,
      color: Colors.deepOrange,
      title: '复盘驱动的菜谱需求',
      children: needs.take(3).map((n) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text('• ${n.mealType} / ${n.goal}：${n.queryText}\n  原因：${n.reason}', style: const TextStyle(height: 1.35)),
      )).toList(),
    );
  }

  Widget _evidenceBlock(List<DietReviewEvidence> evidence) {
    return _smallPanel(
      icon: Icons.fact_check_outlined,
      color: Colors.indigo,
      title: '复盘证据链',
      children: evidence.take(5).map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text('• ${e.title}：${e.detail}\n  来源：${e.source} · 置信 ${(e.confidence * 100).round()}%', style: const TextStyle(height: 1.35)),
      )).toList(),
    );
  }

  Widget _dataGapBlock(List<String> gaps) {
    return _smallPanel(
      icon: Icons.info_outline,
      color: Colors.blueGrey,
      title: '仍需补充的数据',
      children: gaps.take(5).map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('• $e', style: const TextStyle(height: 1.35)),
      )).toList(),
    );
  }

  Widget _smallPanel({required IconData icon, required Color color, required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 6), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _miniScoreRow(String label, double? score) {
    final value = (score ?? 0).clamp(0, 100).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 74, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(child: LinearProgressIndicator(value: value / 100, minHeight: 8, borderRadius: BorderRadius.circular(8))),
          const SizedBox(width: 8),
          Text('${value.round()}', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _riskScoreRow(String label, double? score) {
    final value = (score ?? 0).clamp(0, 100).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 86, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(child: LinearProgressIndicator(value: value / 100, minHeight: 8, borderRadius: BorderRadius.circular(8))),
          const SizedBox(width: 8),
          Text('${value.round()}', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _bulletBlock(String title, List<String> items, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(icon, color: color, size: 19), const SizedBox(width: 6), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 6),
        ...items.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $e', style: const TextStyle(height: 1.42)),
            )),
      ],
    );
  }

  Widget _entryCard(DailyDietEntry entry) {
    final foodText = entry.foods.isEmpty ? '未确认具体食物' : entry.foods.map((e) => '${e.foodName}${e.amountText?.isNotEmpty == true ? '（${e.amountText}）' : ''}').join('、');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_inputIcon(entry.inputType), size: 20)),
        title: Text('${_mealLabel(entry.mealType)} · ${_inputLabel(entry.inputType)}'),
        subtitle: Text(foodText, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteEntry(entry)),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  String _mealLabel(String type) {
    switch (type) {
      case 'breakfast':
        return '早餐';
      case 'lunch':
        return '午餐';
      case 'dinner':
        return '晚餐';
      case 'snack':
        return '加餐/零食';
      case 'drink':
        return '饮品';
      case 'mixed':
        return '多餐混合';
      default:
        return '未知餐次';
    }
  }

  String _inputLabel(String type) {
    switch (type) {
      case 'image':
        return '图片分享';
      case 'voice':
        return '语音转文字';
      case 'barcode':
        return '扫码记录';
      case 'mixed':
        return '混合记录';
      default:
        return '文字记录';
    }
  }

  IconData _inputIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.photo_camera_outlined;
      case 'voice':
        return Icons.mic_none;
      case 'barcode':
        return Icons.qr_code_scanner;
      case 'mixed':
        return Icons.dashboard_customize_outlined;
      default:
        return Icons.edit_note;
    }
  }
}
