import 'dart:convert';

import '../../services/unified_ai_service.dart';
import '../../utils/debug_logger.dart';
import '../models/daily_diet_entry.dart';
import '../models/diet_habit_models.dart';
import '../models/health_connect_daily_summary.dart';
import '../models/health_diet_expert_plan.dart';
import '../models/health_diet_agent_models.dart';
import '../models/health_profile.dart';
import '../models/normalized_food_item.dart';
import '../repositories/daily_diet_entry_repository.dart';
import '../repositories/diet_habit_repository.dart';
import '../repositories/food_item_repository.dart';
import '../repositories/health_connect_summary_repository.dart';
import '../repositories/health_profile_repository.dart';
import '../repositories/health_diet_agent_repository.dart';
import 'diet_food_analysis_service.dart';
import 'diet_long_term_report_service.dart';
import 'health_diet_options.dart';
import 'health_diet_settings_service.dart';
import 'health_rule_engine.dart';

/// Builds the proactive "nutrition expert" view.
///
/// This service is intentionally above the individual feature pages. It reads:
/// 1) health profile, 2) Health Connect state, 3) today's diet share,
/// 4) recent habit patterns, 5) cached/API nutrition details, and then produces
/// a concrete plan instead of waiting for the user to query separate tools.
class HealthDietExpertService {
  HealthDietExpertService({
    HealthProfileRepository? profileRepository,
    HealthConnectSummaryRepository? healthRepository,
    DailyDietEntryRepository? entryRepository,
    FoodItemRepository? foodRepository,
    DietLongTermReportService? longTermReportService,
    DietHabitRepository? habitRepository,
    DietFoodAnalysisService? analysisService,
    HealthRuleEngine? ruleEngine,
    HealthDietSettingsService? settingsService,
    HealthDietAgentRepository? agentRepository,
    UnifiedAiService? aiService,
  })  : _profileRepo = profileRepository ?? HealthProfileRepository(),
        _healthRepo = healthRepository ?? HealthConnectSummaryRepository(),
        _entryRepo = entryRepository ?? DailyDietEntryRepository(),
        _foodRepo = foodRepository ?? FoodItemRepository(),
        _longTerm = longTermReportService ?? DietLongTermReportService(),
        _habitRepo = habitRepository ?? DietHabitRepository(),
        _analysis = analysisService ?? DietFoodAnalysisService(),
        _ruleEngine = ruleEngine ?? HealthRuleEngine(),
        _settings = settingsService ?? HealthDietSettingsService(),
        _agentRepo = agentRepository ?? HealthDietAgentRepository(),
        _ai = aiService ?? UnifiedAiService();

  final HealthProfileRepository _profileRepo;
  final HealthConnectSummaryRepository _healthRepo;
  final DailyDietEntryRepository _entryRepo;
  final FoodItemRepository _foodRepo;
  final DietLongTermReportService _longTerm;
  final DietHabitRepository _habitRepo;
  final DietFoodAnalysisService _analysis;
  final HealthRuleEngine _ruleEngine;
  final HealthDietSettingsService _settings;
  final HealthDietAgentRepository _agentRepo;
  final UnifiedAiService _ai;

  String get today => DateTime.now().toIso8601String().substring(0, 10);

  Future<HealthDietExpertPlan> buildTodayPlan({String userId = HealthProfileRepository.defaultUserId}) async {
    final profile = await _profileRepo.latestProfile(userId: userId);
    final health = await _healthRepo.latestForDate(date: today, userId: userId);
    final todayEntries = await _entryRepo.entriesForDate(today, userId: userId);
    final recentEntries = await _entryRepo.recentEntries(userId: userId, limit: 240);
    final normalizedFoods = await _normalizedFoods(todayEntries);
    final activeGoal = await _agentRepo.activeGoal(userId: userId);
    await _agentRepo.ensureDefaultTasks(userId: userId, goalId: activeGoal?.id);
    final agentTasks = await _agentRepo.pendingTasks(userId: userId);
    final agentMemories = await _agentRepo.memories(userId: userId);
    final microActions = await _habitRepo.microActions(userId: userId, limit: 20);
    final todayFoods = todayEntries.expand((e) => e.foods).toList();
    final todaySummary = _analysis.summarize(todayFoods, entries: todayEntries, normalizedFoods: normalizedFoods);
    final report = await _longTerm.buildReport(userId: userId, days: 7);
    final activeAction = report.priorityAction ?? await _habitRepo.latestActiveAction(userId: userId);
    final rule = profile == null ? null : _ruleEngine.evaluateProfile(profile);
    final settings = await _settings.load();

    final riskLevel = rule?.riskLevel ?? 'unknown';
    final goal = activeGoal?.goalType ?? profile?.mainGoal ?? 'balanced';
    final focus = _focus(profile, health, todaySummary, report.patterns);
    final problems = _priorityProblems(profile, health, todaySummary, report.patterns, todayFoods);
    final micro = _microAction(profile, health, todaySummary, report.patterns, activeAction);
    final meals = _mealBlocks(goal, profile, health, todaySummary, problems);
    final recommended = _recommendedFoods(goal, profile, health, todaySummary);
    final limits = _limitFoods(goal, profile, health, todaySummary);
    final dataGaps = _dataGaps(profile, health, todayEntries, normalizedFoods, settings);
    final safety = _safetyNotices(profile, rule);
    final evidence = _evidence(profile, health, todayEntries, recentEntries, normalizedFoods, report.patterns, report.recordedDays);
    final apiDiagnostics = _apiDiagnostics(settings, normalizedFoods);

    final dataCoverage = _coverageLevel(profile, health, todayEntries, normalizedFoods);
    final plan = HealthDietExpertPlan(
      userId: userId,
      planDate: today,
      focusTitle: focus.title,
      focusReason: focus.reason,
      riskLevel: riskLevel,
      dataCoverageLevel: dataCoverage,
      profileSummary: _profileSummary(profile),
      healthConnectSummary: health?.hasAnyData == true ? health!.compactText() : '未读取到今日 Health Connect 数据。',
      recentDietSummary: _recentDietSummary(todayEntries, report.patterns, report.recordedDays),
      next24hStrategy: _strategy(goal, health, todaySummary, problems),
      microActionTitle: micro.title,
      microActionReason: micro.reason,
      recipeGoal: _recipeGoal(goal, problems),
      meals: meals,
      priorityProblems: problems,
      recommendedFoods: recommended,
      limitFoods: limits,
      dataGaps: dataGaps,
      safetyNotices: safety,
      evidence: evidence,
      apiDiagnostics: apiDiagnostics,
    );

    await DLog.i('health_diet.expert_plan.local', jsonEncode(plan.toPromptJson()));

    await _updateAgentMemories(
      userId: userId,
      profile: profile,
      health: health,
      todaySummary: todaySummary,
      patterns: report.patterns,
      todayFoods: todayFoods,
    );

    await _agentRepo.savePlan(
      userId: userId,
      goalId: activeGoal?.id,
      planDate: today,
      source: 'app_local_agent',
      planJson: plan.toPromptJson(),
    );
    await DLog.i('health_diet.expert_plan.app_local_agent', jsonEncode(plan.toPromptJson()));
    return plan;
  }

  Future<String> generateAiCoachNarrative(HealthDietExpertPlan plan) async {
    final settings = await _settings.load();
    if (!_settings.isEnabledValue(settings[HealthDietSettingsService.aiAdviceEnabled])) {
      return '健康饮食配置中未启用 AI 饮食建议。当前页面已使用本地规则引擎生成主动方案。';
    }
    final prompt = '''
你是本功能模块的“营养专家、膳食专家、健康调理与恢复教练、Agent 总调度大脑”。请只基于下面的数据包，主动完成：分析、判断、决策、计划、提醒和兜底。

重要边界：
1. 不诊断疾病，不声称治疗疾病，不替代医生或注册营养师。涉及肾脏、贫血、脂肪肝、血糖、血压等风险时，必须使用“谨慎、一般饮食参考、建议专业确认”的表达。
2. 必须说明建议依据来自哪些数据：健康档案、Health Connect、饮食分享、历史模式、外部营养数据、数据缺口。
3. 如果数据不足，必须明确指出缺口，不要假装已经了解用户全部情况；此时要给出“保守兜底方案”。
4. 不要只给泛泛建议，必须围绕用户当前目标给出今天/下一餐/明天的具体安排。
5. 必须输出中文，结构固定为：
   - 最终判断
   - 依据与可信度
   - 今天最优先做的 1 件事
   - 下一餐安排
   - 今天少选/避免
   - 数据不足时的兜底方案
   - 需要用户补充的数据
   - 谨慎事项
6. 语气温和，不羞辱用户，不制造焦虑。

数据包：
${jsonEncode(plan.toPromptJson())}
''';
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'health_diet.ai.expert_plan',
        expectJson: false,
        maxTokens: 2400,
        temperature: 0.25,
      );
      await DLog.i('health_diet.ai.expert_plan', raw);
      if (raw.trim().isEmpty) return 'AI 没有返回有效文本。请检查全局 AI Provider、模型和 API Key 配置。';
      return raw.trim();
    } catch (e, st) {
      await DLog.e('health_diet.ai.expert_plan', 'AI expert plan failed: $e\n$st');
      return 'AI 专家分析生成失败：$e。你仍可先使用上方本地规则方案。';
    }
  }


  Future<void> _updateAgentMemories({
    required String userId,
    required HealthProfile? profile,
    required HealthConnectDailySummary? health,
    required DietFoodSummary todaySummary,
    required List<DietHabitPatternRecord> patterns,
    required List<DetectedDietFood> todayFoods,
  }) async {
    if (profile != null) {
      if (profile.preferences.isNotEmpty) {
        await _agentRepo.upsertMemory(
          userId: userId,
          memoryType: 'preference',
          memoryKey: 'diet_preferences',
          memoryValue: HealthDietOptions.labelsOf(HealthDietOptions.preferences, profile.preferences).join('、'),
          confidence: 0.85,
          evidence: {'source': 'health_profile', 'preferences': profile.preferences},
        );
      }
      if (profile.conditions.isNotEmpty) {
        await _agentRepo.upsertMemory(
          userId: userId,
          memoryType: 'safety',
          memoryKey: 'health_conditions',
          memoryValue: HealthDietOptions.labelsOf(HealthDietOptions.conditions, profile.conditions).join('、'),
          confidence: 0.9,
          evidence: {'source': 'health_profile', 'conditions': profile.conditions},
        );
      }
    }
    for (final pattern in patterns.take(3)) {
      await _agentRepo.upsertMemory(
        userId: userId,
        memoryType: 'habit_pattern',
        memoryKey: pattern.patternType,
        memoryValue: '${pattern.patternName}，最近出现 ${pattern.frequencyCount} 次',
        confidence: 0.72,
        evidence: pattern.evidence,
      );
    }
    if (health?.sleepLow == true && todaySummary.hasSugar) {
      await _agentRepo.upsertMemory(
        userId: userId,
        memoryType: 'risk_loop',
        memoryKey: 'sleep_low_plus_sugar',
        memoryValue: '睡眠偏少时出现甜饮/高糖食物，需要优先切断疲劳—甜饮循环。',
        confidence: 0.75,
        evidence: {'health': health?.compactText(), 'foods': todayFoods.map((e) => e.foodName).toList()},
      );
    }
  }

  Future<List<NormalizedFoodItem>> _normalizedFoods(List<DailyDietEntry> entries) async {
    final ids = entries.expand((e) => e.foods).map((f) => f.normalizedFoodId).whereType<int>().toSet();
    return _foodRepo.byIds(ids);
  }

  _Focus _focus(HealthProfile? profile, HealthConnectDailySummary? health, DietFoodSummary summary, List<DietHabitPatternRecord> patterns) {
    final goal = profile?.mainGoal ?? 'balanced';
    if (profile == null) {
      return const _Focus('先建立健康档案', '当前缺少健康档案，系统无法判断你的饮食目标、忌口和风险边界。');
    }
    if (health?.sleepLow == true && summary.hasSugar) {
      return const _Focus('先切断“疲劳—甜饮”循环', '今日睡眠偏少且出现甜饮/高糖食物，优先稳定早餐和饮品选择。');
    }
    if (patterns.isNotEmpty) {
      return _Focus('优先处理：${patterns.first.patternName}', '最近 7 天该模式最突出，先改一个最小动作比同时改很多问题更容易坚持。');
    }
    switch (goal) {
      case 'restore_energy':
        return const _Focus('恢复体力：规律进食 + 优质蛋白', '目标不是猛补，而是让每餐有稳定能量和恢复材料。');
      case 'stomach_care':
        return const _Focus('调理肠胃：少刺激、易消化、规律', '优先选择粥、汤、蒸煮类，减少辣、冰、油炸和过饱。');
      case 'blood_sugar_friendly':
        return const _Focus('控糖友好：减少甜饮和精制碳水冲击', '用蛋白质、蔬菜和适量主食稳定餐后波动。');
      case 'low_sodium':
        return const _Focus('低盐护血压：先控制汤汁、调料和加工肉', '外卖汤汁、泡面调料、火腿肠和腌制品是优先处理对象。');
      case 'muscle_gain':
        return const _Focus('增肌恢复：蛋白质 + 主食 + 训练后补充', '只吃蛋白不够，运动后也需要适量碳水和水分。');
      case 'teen_growth':
        return const _Focus('成长支持：正餐质量优先于零食饮料', '关注蛋白质、钙、铁、蔬菜水果和睡眠运动，不承诺“长高”。');
      default:
        return const _Focus('均衡饮食：先补齐餐盘结构', '从每餐有蛋白、有蔬菜、少甜饮、少重盐开始。');
    }
  }

  List<String> _priorityProblems(HealthProfile? profile, HealthConnectDailySummary? health, DietFoodSummary summary, List<DietHabitPatternRecord> patterns, List<DetectedDietFood> foods) {
    final out = <String>[];
    if (profile == null) out.add('缺少健康档案，无法判断推荐边界。');
    if (foods.isEmpty) out.add('今天还没有确认过的饮食分享，系统只能给通用方向。');
    if (health?.sleepLow == true && summary.hasSugar) out.add('睡眠偏少同时出现甜饮/高糖食物，容易形成疲劳时靠糖硬撑的循环。');
    if (summary.hasSodium) out.add('今日存在高盐/重口味风险，优先减少外卖汤汁、泡面调料、火腿肠或腌制品。');
    if (summary.hasUltraProcessed) out.add('加工食品出现，饮食质量不能只看热量，还要看钠、糖、脂肪和营养密度。');
    if (!summary.hasProtein && foods.isNotEmpty) out.add('今日优质蛋白来源不明显，恢复体力、增肌或饱腹感都可能受影响。');
    if (!summary.hasVegetable && foods.isNotEmpty) out.add('今日蔬菜水果和膳食纤维偏少，建议先补一份青菜/菌菇/番茄/水果。');
    for (final pattern in patterns.take(2)) {
      final message = '近期模式：${pattern.patternName}（${pattern.frequencyCount} 次）。';
      if (!out.contains(message)) out.add(message);
    }
    return out.take(5).toList();
  }

  _Micro _microAction(HealthProfile? profile, HealthConnectDailySummary? health, DietFoodSummary summary, List<DietHabitPatternRecord> patterns, DietMicroAction? activeAction) {
    if (activeAction != null) return _Micro(activeAction.actionTitle, activeAction.actionReason);
    if (profile == null) return const _Micro('先填写健康档案', '没有档案时，系统无法围绕你的目标和限制主动安排饮食。');
    if (health?.sleepLow == true && summary.hasSugar) return const _Micro('下一杯奶茶改成小杯少糖', '先不完全戒甜饮，只切断“睡不够就靠糖撑”的一小步。');
    if (summary.hasSodium) return const _Micro('下一次外卖少喝汤汁或调料减半', '这是最容易执行的低盐改变。');
    if (!summary.hasProtein) return const _Micro('明天早餐加一个鸡蛋或无糖豆浆', '先补一个稳定蛋白质来源。');
    if (!summary.hasVegetable) return const _Micro('明天任意一餐加一份青菜或菌菇', '先补一份纤维，不追求完美。');
    if (patterns.isNotEmpty) return _Micro(patterns.first.patternName, patterns.first.evidence.isNotEmpty ? '证据：${patterns.first.evidence.first}' : patterns.first.patternName);
    return const _Micro('明天继续完成一次饮食分享', '持续记录是个性化调理的基础。');
  }

  List<ExpertMealBlock> _mealBlocks(String goal, HealthProfile? profile, HealthConnectDailySummary? health, DietFoodSummary summary, List<String> problems) {
    final stomach = profile?.conditions.contains('stomach_sensitive') == true || goal == 'stomach_care';
    final lowSodium = profile?.conditions.contains('hypertension') == true || goal == 'low_sodium';
    final sugar = profile?.conditions.contains('diabetes_or_high_glucose') == true || goal == 'blood_sugar_friendly';
    final restore = goal == 'restore_energy' || profile?.conditions.contains('fatigue') == true;
    return [
      ExpertMealBlock(
        mealType: 'breakfast',
        title: '早餐：先稳定上午能量',
        purpose: health?.sleepLow == true || restore ? '睡眠/疲劳恢复' : '建立餐次规律',
        suggestions: sugar
            ? const ['鸡蛋或无糖豆浆', '燕麦/全麦/杂粮小份', '加一份蔬菜或低糖水果']
            : const ['鸡蛋 + 无糖豆浆/牛奶', '燕麦/小米粥/全麦面包任选', '时间紧也至少保留一个蛋白质来源'],
        reason: health?.sleepLow == true ? '睡眠偏少时更容易想喝甜饮，早餐先补蛋白和稳定主食。' : '早餐是最容易改变后续甜饮和夜宵冲动的一餐。',
        avoid: const ['空腹只喝咖啡', '甜面包 + 奶茶', '完全不吃早餐'],
        recipeQuery: '高蛋白早餐 清淡',
      ),
      ExpertMealBlock(
        mealType: 'lunch',
        title: '午餐：餐盘结构优先',
        purpose: '保证正餐质量',
        suggestions: lowSodium
            ? const ['清蒸鱼/鸡胸/豆腐/瘦肉任选', '主食小到中份', '两份蔬菜，酱料分开放']
            : const ['一份蛋白质主菜', '一份米饭/土豆/杂粮', '至少一份青菜或菌菇'],
        reason: '午餐不必复杂，但要避免只剩主食和重口味酱汁。',
        avoid: const ['外卖汤汁全部喝掉', '炸物 + 甜饮叠加', '只有主食没有蛋白质'],
        recipeQuery: lowSodium ? '低盐 午餐 清蒸' : '健康午餐 蛋白 蔬菜',
      ),
      ExpertMealBlock(
        mealType: 'dinner',
        title: '晚餐：帮助身体恢复，不增加负担',
        purpose: stomach || health?.stepsLow == true ? '清淡恢复' : '避免夜间高油高盐',
        suggestions: stomach
            ? const ['小米南瓜粥或山药鸡肉粥', '番茄鸡蛋豆腐汤', '蒸蛋/清蒸鱼 + 熟软蔬菜']
            : const ['豆腐菌菇汤/番茄鸡蛋汤', '鱼肉/鸡肉/豆腐 + 蔬菜', '主食适量，不用极端不吃'],
        reason: stomach ? '胃肠敏感时，软烂、清淡、少辣比追求高蛋白更优先。' : '晚餐更适合低油低盐，减少第二天疲劳和水肿感。',
        avoid: const ['泡面 + 火腿肠', '烧烤/炸鸡做常规晚餐', '过辣过油过饱'],
        recipeQuery: stomach ? '养胃粥 清淡 晚餐' : '清淡晚餐 豆腐 蔬菜',
      ),
      ExpertMealBlock(
        mealType: 'snack',
        title: '加餐/饮品：用替代方案降低阻力',
        purpose: '减少高糖饮料和夜宵补偿',
        suggestions: const ['无糖酸奶/无糖豆浆', '水果小份 + 鸡蛋', '坚果小把或茶水'],
        reason: '不要求立刻戒掉所有喜欢的东西，先把最常出现的一项改小、改少糖。',
        avoid: const ['大杯奶茶 + 小料', '甜饮替代休息', '夜宵泡面常态化'],
        recipeQuery: '健康加餐 无糖 高蛋白',
      ),
    ];
  }

  List<String> _recommendedFoods(String goal, HealthProfile? profile, HealthConnectDailySummary? health, DietFoodSummary summary) {
    final set = <String>{'鸡蛋', '无糖豆浆', '豆腐', '鱼肉', '绿叶菜', '菌菇', '燕麦'};
    if (goal == 'stomach_care' || profile?.conditions.contains('stomach_sensitive') == true) set.addAll(['小米粥', '南瓜', '山药', '蒸蛋']);
    if (goal == 'muscle_gain') set.addAll(['鸡胸肉', '牛奶/酸奶', '土豆/米饭', '牛肉']);
    if (goal == 'blood_sugar_friendly') set.addAll(['杂粮饭小份', '西兰花', '黄瓜', '瘦肉']);
    if (goal == 'low_sodium') set.addAll(['清蒸鱼', '低脂奶', '豆类', '水果']);
    if (health?.sleepLow == true) set.addAll(['早餐蛋白质', '温水', '低糖水果']);
    return set.take(12).toList();
  }

  List<String> _limitFoods(String goal, HealthProfile? profile, HealthConnectDailySummary? health, DietFoodSummary summary) {
    final set = <String>{'甜饮料/奶茶', '方便面调料包', '火腿肠/加工肉', '外卖浓汤汁', '油炸食品'};
    if (goal == 'stomach_care' || profile?.conditions.contains('stomach_sensitive') == true) set.addAll(['辣椒刺激', '冰饮', '烧烤']);
    if (goal == 'blood_sugar_friendly') set.addAll(['甜点', '大份精制主食', '含糖咖啡']);
    if (goal == 'low_sodium' || profile?.conditions.contains('hypertension') == true) set.addAll(['咸菜', '腌制品', '重口味蘸料']);
    return set.take(12).toList();
  }

  List<String> _dataGaps(HealthProfile? profile, HealthConnectDailySummary? health, List<DailyDietEntry> entries, List<NormalizedFoodItem> foods, Map<String, String> settings) {
    final out = <String>[];
    if (profile == null) out.add('缺少健康档案：无法围绕目标、忌口和风险边界主动安排。');
    if (health?.hasAnyData != true) out.add('Health Connect 今日数据不足：睡眠、步数、体重或运动数据未进入判断。');
    if (entries.isEmpty) out.add('今日没有饮食分享：无法判断今天实际吃了什么。');
    if (foods.isEmpty && entries.isNotEmpty) out.add('今日饮食未绑定可靠营养数据：可通过条码、USDA 或更明确食物名称提高准确性。');
    if ((settings[HealthDietSettingsService.usdaApiKey] ?? '').trim().isEmpty) out.add('USDA API Key 未配置：基础食材营养补全能力受限。');
    if ((settings[HealthDietSettingsService.spoonacularApiKey] ?? '').trim().isEmpty && (settings[HealthDietSettingsService.edamamAppKey] ?? '').trim().isEmpty) out.add('菜谱 API 未配置或不可用：在线健康菜谱推荐会回退到本地保底菜谱。');
    return out.take(6).toList();
  }

  List<String> _safetyNotices(HealthProfile? profile, HealthRuleResult? rule) {
    final out = <String>[];
    if (rule?.warnings.isNotEmpty == true) out.addAll(rule!.warnings.take(2));
    if (profile?.conditions.any((c) => const {'kidney_problem', 'pregnancy_or_lactation', 'post_surgery_recovery', 'diabetes_or_high_glucose'}.contains(c)) == true) {
      out.add('你的情况可能涉及医学营养治疗，本功能只能提供一般健康饮食参考，请优先遵循医生或注册营养师建议。');
    }
    return out.toSet().toList();
  }

  List<HealthDietEvidence> _evidence(HealthProfile? profile, HealthConnectDailySummary? health, List<DailyDietEntry> todayEntries, List<DailyDietEntry> recentEntries, List<NormalizedFoodItem> foods, List<DietHabitPatternRecord> patterns, int recordedDays) {
    final out = <HealthDietEvidence>[];
    out.add(HealthDietEvidence(label: '健康目标', value: profile == null ? '未填写' : HealthDietOptions.labelOf(HealthDietOptions.goals, profile.mainGoal), source: '健康档案', strength: profile == null ? 'low' : 'high'));
    out.add(HealthDietEvidence(label: '健康状况', value: profile == null || profile.conditions.isEmpty ? '未填写' : HealthDietOptions.labelsOf(HealthDietOptions.conditions, profile.conditions).join('、'), source: '健康档案', strength: profile == null ? 'low' : 'high'));
    out.add(HealthDietEvidence(label: '今日身体状态', value: health?.hasAnyData == true ? health!.compactText() : '暂无 Health Connect 今日数据', source: 'Health Connect', strength: health?.hasAnyData == true ? 'medium' : 'low'));
    out.add(HealthDietEvidence(label: '今日饮食分享', value: '${todayEntries.length} 条记录，${todayEntries.expand((e) => e.foods).length} 个确认食物', source: '每日饮食分享', strength: todayEntries.isEmpty ? 'low' : 'high'));
    out.add(HealthDietEvidence(label: '近期记录', value: '最近记录 ${recentEntries.length} 条，本周有效记录 $recordedDays 天', source: '饮食历史', strength: recentEntries.isEmpty ? 'low' : 'medium'));
    out.add(HealthDietEvidence(label: '外部营养数据', value: foods.isEmpty ? '今日未匹配到缓存/API 营养数据' : '今日匹配 ${foods.length} 个营养数据项', source: 'USDA/Open Food Facts/缓存', strength: foods.isEmpty ? 'low' : 'medium'));
    if (patterns.isNotEmpty) out.add(HealthDietEvidence(label: '主要饮食模式', value: patterns.map((e) => e.patternName).take(3).join('、'), source: '7天习惯分析', strength: 'medium'));
    return out;
  }

  List<ApiDiagnosticItem> _apiDiagnostics(Map<String, String> settings, List<NormalizedFoodItem> foods) {
    String status(String key) => (settings[key] ?? '').trim().isEmpty ? '未配置' : '已配置';
    return [
      ApiDiagnosticItem(name: 'USDA FoodData Central', status: status(HealthDietSettingsService.usdaApiKey), message: foods.any((f) => f.source.toLowerCase().contains('usda')) ? '今日已有 USDA 食材数据参与判断。' : '未看到今日 USDA 数据命中；可能是未配置、关键词不匹配或接口返回为空。'),
      ApiDiagnosticItem(name: 'Open Food Facts', status: '无需密钥', message: foods.any((f) => f.source.toLowerCase().contains('open')) ? '今日已有包装食品/条码数据参与判断。' : '未看到今日条码/包装食品数据命中。'),
      ApiDiagnosticItem(name: 'Spoonacular', status: status(HealthDietSettingsService.spoonacularApiKey), message: '用于在线健康菜谱搜索；若额度不足或返回为空，会回退本地菜谱。'),
      ApiDiagnosticItem(name: 'Edamam', status: (settings[HealthDietSettingsService.edamamAppId] ?? '').isNotEmpty && (settings[HealthDietSettingsService.edamamAppKey] ?? '').isNotEmpty ? '已配置' : '未配置', message: '用于健康标签与在线菜谱搜索；返回为空时不应影响本地专家方案。'),
      ApiDiagnosticItem(name: '薄荷健康', status: status(HealthDietSettingsService.booheeApiKey), message: '保留配置位；需平台正式接口文档后才能作为主数据源。'),
    ];
  }

  String _coverageLevel(HealthProfile? profile, HealthConnectDailySummary? health, List<DailyDietEntry> entries, List<NormalizedFoodItem> foods) {
    var score = 0;
    if (profile != null) score++;
    if (health?.hasAnyData == true) score++;
    if (entries.isNotEmpty) score++;
    if (foods.isNotEmpty) score++;
    if (score >= 4) return '较完整';
    if (score >= 2) return '部分可用';
    return '数据不足';
  }

  String _profileSummary(HealthProfile? profile) {
    if (profile == null) return '尚未填写健康档案。';
    final parts = <String>[];
    parts.add('目标：${HealthDietOptions.labelOf(HealthDietOptions.goals, profile.mainGoal)}');
    if (profile.conditions.isNotEmpty) parts.add('状况：${HealthDietOptions.labelsOf(HealthDietOptions.conditions, profile.conditions).join('、')}');
    if (profile.restrictions.isNotEmpty) parts.add('限制：${HealthDietOptions.labelsOf(HealthDietOptions.restrictions, profile.restrictions).join('、')}');
    if (profile.preferences.isNotEmpty) parts.add('偏好：${HealthDietOptions.labelsOf(HealthDietOptions.preferences, profile.preferences).join('、')}');
    return parts.join('；');
  }

  String _recentDietSummary(List<DailyDietEntry> todayEntries, List<DietHabitPatternRecord> patterns, int recordedDays) {
    final todayFoodCount = todayEntries.expand((e) => e.foods).length;
    if (patterns.isEmpty) return '本周已记录 $recordedDays 天；今日确认 $todayFoodCount 个食物。暂未形成稳定问题模式。';
    return '本周已记录 $recordedDays 天；今日确认 $todayFoodCount 个食物。突出模式：${patterns.map((e) => '${e.patternName}${e.frequencyCount}次').take(3).join('、')}。';
  }

  String _strategy(String goal, HealthConnectDailySummary? health, DietFoodSummary summary, List<String> problems) {
    if (health?.sleepLow == true) return '今天优先稳住早餐和饮品，避免用甜饮硬撑疲劳；晚餐清淡不过饱。';
    if (summary.hasSodium) return '今天优先降低钠负担：外卖少汤汁、泡面调料减半、加工肉减少，并补一份蔬菜。';
    if (goal == 'stomach_care') return '今天以温和、软烂、少刺激为主，先避免辣、冰、油炸和过饱。';
    if (goal == 'muscle_gain') return '今天保证蛋白质和适量主食，运动后补水、蛋白质和碳水。';
    if (goal == 'blood_sugar_friendly') return '今天减少甜饮和甜点，主食保留小份，搭配蛋白质和蔬菜。';
    return '今天先做到：每餐有蛋白、有蔬菜，甜饮和重盐少一点。';
  }

  String _recipeGoal(String goal, List<String> problems) {
    if (problems.any((p) => p.contains('高盐'))) return '低盐 清淡 蔬菜 蛋白';
    if (problems.any((p) => p.contains('蛋白'))) return '高蛋白 家常 清淡';
    if (problems.any((p) => p.contains('蔬菜'))) return '高纤维 蔬菜 家常';
    switch (goal) {
      case 'stomach_care':
        return '养胃粥 清淡 蒸煮';
      case 'blood_sugar_friendly':
        return '控糖 高纤维 高蛋白';
      case 'low_sodium':
        return '低盐 清蒸 家常';
      case 'muscle_gain':
        return '高蛋白 增肌 家常';
      default:
        return '健康家常菜 清淡';
    }
  }
}

class _Focus {
  const _Focus(this.title, this.reason);
  final String title;
  final String reason;
}

class _Micro {
  const _Micro(this.title, this.reason);
  final String title;
  final String reason;
}
