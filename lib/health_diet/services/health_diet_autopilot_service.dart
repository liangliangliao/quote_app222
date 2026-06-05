import 'dart:convert';

import '../../utils/debug_logger.dart';
import '../models/daily_diet_entry.dart';
import '../models/health_diet_expert_plan.dart';
import '../models/normalized_food_item.dart';
import '../repositories/daily_diet_entry_repository.dart';
import '../repositories/food_item_repository.dart';
import '../repositories/health_connect_summary_repository.dart';
import '../repositories/health_diet_agent_repository.dart';
import '../repositories/health_profile_repository.dart';
import '../repositories/healthy_recipe_repository.dart';
import 'daily_diet_review_service.dart';
import 'health_connect_diet_context_service.dart';
import 'health_diet_external_api_service.dart';
import 'health_diet_expert_service.dart';
import 'health_diet_settings_service.dart';
import 'health_diet_ai_bridge_service.dart';
import 'health_rule_engine.dart';

class HealthDietAutopilotStep {
  const HealthDietAutopilotStep({
    required this.name,
    required this.status,
    required this.message,
    this.data = const <String, Object?>{},
  });

  final String name;
  final String status;
  final String message;
  final Map<String, Object?> data;

  bool get ok => status == 'ok';
  bool get warning => status == 'warning';
  bool get error => status == 'error';

  Map<String, Object?> toJson() => {
        'name': name,
        'status': status,
        'message': message,
        'data': data,
      };
}

class HealthDietAutopilotResult {
  const HealthDietAutopilotResult({
    required this.plan,
    required this.steps,
    required this.startedAt,
    required this.completedAt,
    required this.autonomyLevel,
    required this.autopilotEnabled,
  });

  final HealthDietExpertPlan plan;
  final List<HealthDietAutopilotStep> steps;
  final DateTime startedAt;
  final DateTime completedAt;
  final String autonomyLevel;
  final bool autopilotEnabled;

  bool get hasError => steps.any((e) => e.error);

  int get okCount => steps.where((e) => e.ok).length;
  int get warningCount => steps.where((e) => e.warning).length;
  int get errorCount => steps.where((e) => e.error).length;

  bool get hasCriticalDataGap {
    final text = [
      ...plan.dataGaps,
      plan.recentDietSummary,
      plan.healthConnectSummary,
      ...steps.map((e) => e.message),
    ].join('；');
    return text.contains('今日确认 0') ||
        text.contains('确认食物为 0') ||
        text.contains('没有饮食分享') ||
        text.contains('Health Connect 尚未授权') ||
        text.contains('未获得有效健康数据');
  }

  bool get shouldShowFallback => hasError || errorCount > 0 || warningCount >= 4 || hasCriticalDataGap;

  String get finalVerdictTitle {
    if (shouldShowFallback) return '本轮结果：先进入兜底托管';
    if (warningCount > 0) return '本轮结果：已有可用方案，但仍需补数据';
    return '本轮结果：已生成可执行饮食托管方案';
  }

  String get finalVerdictMessage {
    if (shouldShowFallback) {
      return '本轮巡检没有拿到足够完整的数据，系统不会假装已经精准判断。当前先给出保守安全方案，并优先提醒你补齐饮食记录、Health Connect 或关键 API 数据。';
    }
    return 'Agent 已整合健康档案、身体状态、饮食记录、外部营养/菜谱数据和 AI 分析，生成当前可执行安排。';
  }

  List<String> get immediateActions {
    final actions = <String>[
      if (plan.microActionTitle.trim().isNotEmpty) plan.microActionTitle,
      if (plan.next24hStrategy.trim().isNotEmpty) plan.next24hStrategy,
    ];
    if (hasCriticalDataGap) {
      actions.add('先补一条真实饮食记录，至少填写食物名称和大致份量。');
    }
    if (steps.any((e) => e.message.contains('Health Connect 尚未授权'))) {
      actions.add('进入 Health Connect 页面手动授权一次，让 Agent 能读取步数、睡眠、运动等身体状态。');
    }
    for (final gap in plan.dataGaps.take(2)) {
      actions.add(gap);
    }
    final seen = <String>{};
    return actions.where((e) => seen.add(e)).take(5).toList();
  }

  String get summary {
    return '已完成 $okCount 项，提醒 $warningCount 项，失败 $errorCount 项。';
  }

  Map<String, Object?> toJson() => {
        'started_at': startedAt.toIso8601String(),
        'completed_at': completedAt.toIso8601String(),
        'autonomy_level': autonomyLevel,
        'autopilot_enabled': autopilotEnabled,
        'summary': summary,
        'final_verdict_title': finalVerdictTitle,
        'final_verdict_message': finalVerdictMessage,
        'should_show_fallback': shouldShowFallback,
        'immediate_actions': immediateActions,
        'steps': steps.map((e) => e.toJson()).toList(),
      };
}

/// 健康饮食“自动托管”编排服务。
///
/// 它不是服务器后台进程，而是在 App 打开健康饮食模块/专家页时主动执行一次托管巡检：
/// 1) 自动读取已授权的 Health Connect；
/// 2) 自动补全今日食物营养数据；
/// 3) 自动搜索健康菜谱并写入本地库；
/// 4) 自动生成今日复盘；
/// 5) 自动生成本地专家方案；
/// 6) 在配置允许时自动调用全局 AI 生成专家叙述；
/// 7) 记录 Agent 任务结果、记忆和方案日志。
class HealthDietAutopilotService {
  HealthDietAutopilotService({
    HealthDietSettingsService? settingsService,
    HealthDietExpertService? expertService,
    HealthConnectDietContextService? healthConnectService,
    HealthDietExternalApiService? externalApiService,
    HealthDietAgentRepository? agentRepository,
    HealthProfileRepository? profileRepository,
    HealthConnectSummaryRepository? healthRepository,
    DailyDietEntryRepository? entryRepository,
    FoodItemRepository? foodRepository,
    HealthyRecipeRepository? recipeRepository,
    DailyDietReviewService? reviewService,
    HealthRuleEngine? ruleEngine,
    HealthDietAiBridgeService? aiBridgeService,
  })  : _settings = settingsService ?? HealthDietSettingsService(),
        _expert = expertService ?? HealthDietExpertService(),
        _healthConnect = healthConnectService ?? HealthConnectDietContextService(),
        _externalApi = externalApiService ?? HealthDietExternalApiService(),
        _agentRepo = agentRepository ?? HealthDietAgentRepository(),
        _profileRepo = profileRepository ?? HealthProfileRepository(),
        _healthRepo = healthRepository ?? HealthConnectSummaryRepository(),
        _entryRepo = entryRepository ?? DailyDietEntryRepository(),
        _foodRepo = foodRepository ?? FoodItemRepository(),
        _recipeRepo = recipeRepository ?? HealthyRecipeRepository(),
        _review = reviewService ?? DailyDietReviewService(),
        _ruleEngine = ruleEngine ?? HealthRuleEngine(),
        _aiBridge = aiBridgeService ?? HealthDietAiBridgeService();

  final HealthDietSettingsService _settings;
  final HealthDietExpertService _expert;
  final HealthConnectDietContextService _healthConnect;
  final HealthDietExternalApiService _externalApi;
  final HealthDietAgentRepository _agentRepo;
  final HealthProfileRepository _profileRepo;
  final HealthConnectSummaryRepository _healthRepo;
  final DailyDietEntryRepository _entryRepo;
  final FoodItemRepository _foodRepo;
  final HealthyRecipeRepository _recipeRepo;
  final DailyDietReviewService _review;
  final HealthRuleEngine _ruleEngine;
  final HealthDietAiBridgeService _aiBridge;

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  Future<HealthDietAutopilotResult> run({
    String userId = HealthProfileRepository.defaultUserId,
    bool force = false,
    bool interactive = false,
  }) async {
    final startedAt = DateTime.now();
    final steps = <HealthDietAutopilotStep>[];
    final settings = await _settings.load();
    final autonomyLevel = settings[HealthDietSettingsService.agentAutonomyLevel] ?? 'L4';
    final autonomy = _autonomyValue(autonomyLevel);
    final autopilotEnabled = _settings.isEnabledValue(settings[HealthDietSettingsService.agentAutopilotEnabled]);
    final autoHealth = _settings.isEnabledValue(settings[HealthDietSettingsService.agentAutoHealthSyncEnabled]);
    final autoApi = _settings.isEnabledValue(settings[HealthDietSettingsService.agentAutoApiEnabled]);
    final autoAi = _settings.isEnabledValue(settings[HealthDietSettingsService.agentAutoAiEnabled]);
    final aiEnabled = _settings.isEnabledValue(settings[HealthDietSettingsService.aiAdviceEnabled]);

    if (!autopilotEnabled && !force) {
      final plan = await _expert.buildTodayPlan(userId: userId);
      steps.add(const HealthDietAutopilotStep(
        name: '自动托管',
        status: 'warning',
        message: '自动托管开关未开启：本次只生成本地专家方案，没有自动同步、自动 API、自动 AI。',
      ));
      return HealthDietAutopilotResult(
        plan: plan,
        steps: steps,
        startedAt: startedAt,
        completedAt: DateTime.now(),
        autonomyLevel: autonomyLevel,
        autopilotEnabled: autopilotEnabled,
      );
    }

    steps.add(HealthDietAutopilotStep(
      name: '启动托管巡检',
      status: 'ok',
      message: interactive ? 'Agent 已进入前台托管模式：优先刷新今日方案，同时保留 AI 专家分析；菜谱批量抓取等慢任务会降级，避免页面长时间转圈。' : 'Agent 已按 $autonomyLevel 自动托管策略开始巡检。',
    ));

    await _agentRepo.ensureDefaultTasks(userId: userId, goalId: (await _agentRepo.activeGoal(userId: userId))?.id);

    if (autoHealth && autonomy >= 2 && _settings.isEnabledValue(settings[HealthDietSettingsService.healthConnectEnabled])) {
      steps.add(await _syncHealthConnect(userId));
    } else {
      steps.add(const HealthDietAutopilotStep(
        name: 'Health Connect 自动同步',
        status: 'warning',
        message: '未执行自动同步：请检查 Health Connect 联动开关、自动同步开关或 Agent 等级。',
      ));
    }

    var plan = await _expert.buildTodayPlan(userId: userId);
    steps.add(const HealthDietAutopilotStep(
      name: '本地专家方案',
      status: 'ok',
      message: '已基于健康档案、饮食记录、Health Connect、本地规则和历史模式生成基础方案。',
    ));

    if (autoApi && autonomy >= 3) {
      steps.add(await _autoEnrichNutrition(plan, userId).timeout(
        const Duration(seconds: 45),
        onTimeout: () => const HealthDietAutopilotStep(
          name: '健康平台 API 自动调用',
          status: 'warning',
          message: '营养平台查询超过 45 秒，已先返回可用方案；稍后可在专家页执行完整托管。',
        ),
      ));
      if (interactive) {
        steps.add(const HealthDietAutopilotStep(
          name: '菜谱平台 API 自动调用',
          status: 'warning',
          message: '前台托管模式暂不批量抓取 Spoonacular / Edamam；点击“按今日调理找菜谱”时再按需查询并显示图片，避免无效长等待。',
        ));
      } else {
        steps.add(await _autoFetchRecipes(plan).timeout(
          const Duration(seconds: 60),
          onTimeout: () => const HealthDietAutopilotStep(
            name: '菜谱平台 API 自动调用',
            status: 'warning',
            message: '菜谱平台查询超过 60 秒，已跳过本轮保存，不影响今日饮食安排。',
          ),
        ));
      }
    } else {
      steps.add(const HealthDietAutopilotStep(
        name: '健康平台 API 自动调用',
        status: 'warning',
        message: '未执行自动 API 调用：请检查自动 API 开关或 Agent 等级。',
      ));
    }

    if (autonomy >= 3) {
      steps.add(await _buildAndSaveDailyReview(
        userId,
        runAiReview: autoAi && aiEnabled && autonomy >= 3,
        fetchRecipes: !interactive && autoApi,
      ).timeout(
        const Duration(seconds: 90),
        onTimeout: () => const HealthDietAutopilotStep(
          name: '今日饮食复盘自动生成',
          status: 'warning',
          message: '复盘生成超过 90 秒，已先返回今日安排；完整复盘可稍后进入复盘页查看。',
        ),
      ));
    }

    // API / Health Connect / Review 后重新生成一次，让最终方案吸收最新数据。
    plan = await _expert.buildTodayPlan(userId: userId);

    if (autoAi && aiEnabled && autonomy >= 3) {
      final timeoutSeconds = interactive ? 120 : 180;
      final aiText = await _expert.generateAiCoachNarrative(plan).timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () => 'AI 专家叙述超过 ${timeoutSeconds} 秒，本轮先返回本地兜底方案；建议稍后在网络稳定时重新生成。',
      );
      plan = plan.copyWith(aiCoachText: aiText);
      final timedOut = aiText.contains('超过 ${timeoutSeconds} 秒');
      steps.add(HealthDietAutopilotStep(
        name: 'AI 专家自动分析',
        status: aiText.trim().isEmpty || aiText.contains('失败') || aiText.contains('没有返回有效文本') || timedOut ? 'warning' : 'ok',
        message: timedOut
            ? 'AI 分析超过 ${timeoutSeconds} 秒，已保留本地专家方案并进入兜底显示；不会让页面一直等待。'
            : (aiText.trim().isEmpty ? 'AI 未返回有效内容。' : '已自动调用全局 AI Provider，让 AI 作为膳食专家大脑参与本轮分析、判断和计划。'),
        data: {'preview': aiText.length > 220 ? '${aiText.substring(0, 220)}...' : aiText, 'timeout_seconds': timeoutSeconds},
      ));
    } else {
      steps.add(const HealthDietAutopilotStep(
        name: 'AI 专家自动分析',
        status: 'warning',
        message: '未自动调用 AI：请检查 AI 饮食建议开关、Agent 自动 AI 开关或主动等级。',
      ));
    }

    await _finishAgentTasks(userId, steps);
    await _saveAutopilotPlan(userId, plan, steps, startedAt, autonomyLevel, autopilotEnabled);
    await _rememberAutopilotRun(userId, steps, plan);

    final result = HealthDietAutopilotResult(
      plan: plan,
      steps: steps,
      startedAt: startedAt,
      completedAt: DateTime.now(),
      autonomyLevel: autonomyLevel,
      autopilotEnabled: autopilotEnabled,
    );
    await DLog.i('health_diet.autopilot', jsonEncode(result.toJson()));
    return result;
  }

  Future<HealthDietAutopilotStep> _syncHealthConnect(String userId) async {
    try {
      final status = await _healthConnect.status();
      if (!status.available) {
        return HealthDietAutopilotStep(
          name: 'Health Connect 自动同步',
          status: 'warning',
          message: status.message ?? 'Health Connect 当前不可用。',
          data: status.raw,
        );
      }
      if (!status.granted) {
        return HealthDietAutopilotStep(
          name: 'Health Connect 自动同步',
          status: 'warning',
          message: 'Health Connect 尚未授权。为了避免后台弹权限框，Agent 不会自动请求权限；请先进入 Health Connect 页面手动授权一次。',
          data: status.raw,
        );
      }
      final summary = await _healthConnect.readAndSaveToday(userId: userId);
      return HealthDietAutopilotStep(
        name: 'Health Connect 自动同步',
        status: summary.hasAnyData ? 'ok' : 'warning',
        message: summary.hasAnyData ? '已自动读取并保存今日身体状态：${summary.compactText()}' : (summary.message ?? '已执行读取，但未获得有效健康数据。'),
        data: {'status': summary.status, 'date': summary.summaryDate},
      );
    } catch (e, st) {
      await DLog.e('health_diet.autopilot.health_connect', '$e\n$st');
      return HealthDietAutopilotStep(name: 'Health Connect 自动同步', status: 'error', message: '同步失败：$e');
    }
  }

  Future<HealthDietAutopilotStep> _autoEnrichNutrition(HealthDietExpertPlan plan, String userId) async {
    try {
      final entries = await _entryRepo.entriesForDate(_today, userId: userId);
      final foods = entries.expand((e) => e.foods).where((f) => f.foodName.trim().isNotEmpty).toList();
      var linkedCount = 0;
      var cachedCount = 0;
      if (foods.isEmpty) {
        return const HealthDietAutopilotStep(
          name: '健康平台 API 自动调用',
          status: 'warning',
          message: '今日确认食物为 0，已跳过 USDA / Open Food Facts 批量补全，避免用通用推荐词触发大量无效 API 和 AI 翻译。请先记录一餐后再让 Agent 自动补全营养数据。',
        );
      }

      final queryTerms = <String>[];
      for (final food in foods) {
        queryTerms.add(food.foodName.trim());
      }
      final uniqueTerms = _unique(queryTerms).take(6).toList();

      for (final food in foods) {
        if (food.normalizedFoodId != null || food.id == null) continue;
        final found = await _externalApi.searchFood(food.foodName, limit: 3);
        if (found.isEmpty) continue;
        final best = found.first;
        final id = await _foodRepo.upsertFood(best);
        await _entryRepo.updateDetectedFoodNormalizedId(food.id!, id);
        linkedCount++;
        cachedCount += found.length;
        for (final extra in found.skip(1)) {
          await _foodRepo.upsertFood(extra);
        }
      }

      for (final term in uniqueTerms) {
        final found = await _externalApi.searchFood(term, limit: 2);
        cachedCount += found.length;
        for (final item in found) {
          await _foodRepo.upsertFood(item);
        }
      }

      return HealthDietAutopilotStep(
        name: '健康平台 API 自动调用',
        status: cachedCount > 0 || linkedCount > 0 ? 'ok' : 'warning',
        message: cachedCount > 0 || linkedCount > 0
            ? '已自动调用 USDA / Open Food Facts 补全营养数据：缓存 $cachedCount 条，关联今日食物 $linkedCount 个。'
            : '已尝试调用食物营养平台，但没有命中新数据。请检查 API Key、食物名称或网络状态。',
        data: {'cached_foods': cachedCount, 'linked_today_foods': linkedCount, 'queries': uniqueTerms},
      );
    } catch (e, st) {
      await DLog.e('health_diet.autopilot.nutrition_api', '$e\n$st');
      return HealthDietAutopilotStep(name: '健康平台 API 自动调用', status: 'error', message: '营养 API 自动调用失败：$e');
    }
  }

  Future<HealthDietAutopilotStep> _autoFetchRecipes(HealthDietExpertPlan plan) async {
    try {
      final queries = _unique(<String>[
        plan.recipeGoal,
        ...plan.meals.map((e) => e.recipeQuery),
      ]).where((e) => e.trim().isNotEmpty).take(2).toList();
      var saved = 0;
      for (final query in queries) {
        final recipes = await _externalApi.searchRecipes(query, limit: 3);
        for (final recipe in recipes) {
          await _recipeRepo.upsertRecipe(recipe);
          saved++;
        }
      }
      return HealthDietAutopilotStep(
        name: '菜谱平台 API 自动调用',
        status: saved > 0 ? 'ok' : 'warning',
        message: saved > 0 ? '已自动调用 Spoonacular / Edamam 搜索并保存 $saved 个候选菜谱。' : '已尝试搜索在线健康菜谱，但未返回可保存结果；页面仍会使用本地保底菜谱。',
        data: {'saved_recipes': saved, 'queries': queries},
      );
    } catch (e, st) {
      await DLog.e('health_diet.autopilot.recipe_api', '$e\n$st');
      return HealthDietAutopilotStep(name: '菜谱平台 API 自动调用', status: 'error', message: '菜谱 API 自动调用失败：$e');
    }
  }

  Future<HealthDietAutopilotStep> _buildAndSaveDailyReview(String userId, {bool runAiReview = false, bool fetchRecipes = false}) async {
    try {
      final profile = await _profileRepo.latestProfile(userId: userId);
      final health = await _healthRepo.latestForDate(userId: userId, date: _today);
      final entries = await _entryRepo.entriesForDate(_today, userId: userId);
      final foods = entries.expand((e) => e.foods).toList();
      final normalizedFoods = await _normalizedFoods(entries);
      final rule = profile == null ? null : _ruleEngine.evaluateProfile(profile);
      final localReview = _review.buildLocalReview(
        userId: userId,
        summaryDate: _today,
        foods: foods,
        profile: profile,
        ruleResult: rule,
        entries: entries,
        healthSummary: health,
        normalizedFoods: normalizedFoods,
      );
      final aiReview = runAiReview
          ? await _aiBridge.reviewDietWithEvidence(
              localReview,
              extraContext: {
                'profile_goal': profile?.mainGoal,
                'health_connect': health?.compactText(),
                'entry_count': entries.length,
                'food_count': foods.length,
                'normalized_food_count': normalizedFoods.length,
                'trigger': 'autopilot',
              },
            )
          : null;
      final review = _review.mergeAiReview(localReview, aiReview);
      await _entryRepo.upsertDailyReview(review);
      var savedReviewRecipes = 0;
      if (fetchRecipes) {
        for (final need in review.recipeNeeds.take(3)) {
          final recipes = await _externalApi.searchRecipes(need.queryText, healthTags: [need.goal], limit: 3);
          for (final recipe in recipes) {
            await _recipeRepo.upsertRecipe(recipe);
            savedReviewRecipes++;
          }
        }
      }
      return HealthDietAutopilotStep(
        name: '今日饮食复盘自动生成',
        status: 'ok',
        message: savedReviewRecipes > 0
            ? '已自动生成复盘${aiReview == null ? '' : '、AI 二次审查'}，并按复盘需求保存 $savedReviewRecipes 个候选菜谱。'
            : '已自动生成并保存今日饮食复盘：${review.overallSummary}',
        data: {
          'foods': foods.length,
          'normalized_foods': normalizedFoods.length,
          'recovery_score': review.recoveryScore,
          'confidence_score': review.confidenceScore,
          'confidence_level': review.confidenceLevel,
          'ai_review': review.aiReviewJson != null,
          'recipe_needs': review.recipeNeeds.map((e) => e.toJson()).toList(),
          'saved_review_recipes': savedReviewRecipes,
        },
      );
    } catch (e, st) {
      await DLog.e('health_diet.autopilot.daily_review', '$e\n$st');
      return HealthDietAutopilotStep(name: '今日饮食复盘自动生成', status: 'error', message: '今日复盘生成失败：$e');
    }
  }

  Future<List<NormalizedFoodItem>> _normalizedFoods(List<DailyDietEntry> entries) {
    return _foodRepo.byIds(entries.expand((e) => e.foods).map((f) => f.normalizedFoodId));
  }

  Future<void> _finishAgentTasks(String userId, List<HealthDietAutopilotStep> steps) async {
    final evidence = steps.map((e) => e.toJson()).toList();
    await _agentRepo.completePendingTaskType(
      userId: userId,
      taskType: 'morning_plan',
      evidence: evidence,
      result: {'message': '已自动生成今日/明日饮食方案'},
    );
    await _agentRepo.completePendingTaskType(
      userId: userId,
      taskType: 'diet_review',
      evidence: evidence,
      result: {'message': '已自动生成或刷新今日饮食复盘'},
    );
    await _agentRepo.completePendingTaskType(
      userId: userId,
      taskType: 'meal_reminder',
      evidence: evidence,
      result: {'message': '已评估今日饮食记录状态；真实通知可后续接入本地通知插件'},
    );
    if (DateTime.now().weekday == DateTime.sunday) {
      await _agentRepo.completePendingTaskType(
        userId: userId,
        taskType: 'weekly_report',
        evidence: evidence,
        result: {'message': '周日已刷新长期饮食模式和优先微行动'},
      );
    }
  }

  Future<void> _saveAutopilotPlan(
    String userId,
    HealthDietExpertPlan plan,
    List<HealthDietAutopilotStep> steps,
    DateTime startedAt,
    String autonomyLevel,
    bool enabled,
  ) async {
    final goal = await _agentRepo.activeGoal(userId: userId);
    await _agentRepo.savePlan(
      userId: userId,
      goalId: goal?.id,
      planDate: _today,
      source: 'app_autopilot_agent',
      planJson: {
        ...plan.toPromptJson(),
        'ai_coach_text': plan.aiCoachText,
        'autopilot': {
          'started_at': startedAt.toIso8601String(),
          'completed_at': DateTime.now().toIso8601String(),
          'autonomy_level': autonomyLevel,
          'enabled': enabled,
          'steps': steps.map((e) => e.toJson()).toList(),
        },
      },
    );
  }

  Future<void> _rememberAutopilotRun(String userId, List<HealthDietAutopilotStep> steps, HealthDietExpertPlan plan) async {
    await _agentRepo.upsertMemory(
      userId: userId,
      memoryType: 'system',
      memoryKey: 'last_autopilot_run',
      memoryValue: '最近一次自动托管：${steps.where((e) => e.ok).length}项成功，${steps.where((e) => e.warning).length}项提醒，${steps.where((e) => e.error).length}项失败；焦点：${plan.focusTitle}',
      confidence: 0.9,
      evidence: steps.map((e) => e.toJson()).toList(),
    );
  }

  int _autonomyValue(String value) {
    final match = RegExp(r'L(\d)').firstMatch(value.toUpperCase());
    if (match == null) return 4;
    return int.tryParse(match.group(1) ?? '4') ?? 4;
  }

  List<String> _unique(Iterable<String> values) {
    final seen = <String>{};
    final out = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) out.add(trimmed);
    }
    return out;
  }
}
